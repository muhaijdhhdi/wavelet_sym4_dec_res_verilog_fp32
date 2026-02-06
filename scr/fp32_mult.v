module fp32_mult(
    input clk,
    input rstn,
    input [31:0] dina,
    input [31:0] dinb,
    input valid_din,
    output [31:0] result,
    output valid_out
);

    // ==================== Stage 1: Extraction ====================
    reg [31:0] dina_r1, dinb_r1;
    reg valid_r1;
    reg sign_a1, sign_b1;
    reg [7:0] exp_a1, exp_b1;
    reg [23:0] man_a1, man_b1;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            valid_r1 <= 1'b0;
        end else begin
            valid_r1 <= valid_din;
            dina_r1 <= dina; dinb_r1 <= dinb;
            sign_a1 <= dina[31]; sign_b1 <= dinb[31];
            exp_a1  <= dina[30:23]; exp_b1  <= dinb[30:23];
            // 隐含位处理：全0为非规约数（简化处理为0），否则加1
            man_a1  <= (dina[30:23] == 8'h0) ? 24'h0 : {1'b1, dina[22:0]};
            man_b1  <= (dinb[30:23] == 8'h0) ? 24'h0 : {1'b1, dinb[22:0]};
        end
    end

    // ==================== Stage 2: Multiply & Exp Add ====================
    reg valid_r2;
    reg sign_r2;
    reg [8:0] exp_sum2;
    reg [47:0] man_prod2;
    reg [31:0] dina_r2, dinb_r2;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) valid_r2 <= 1'b0;
        else begin
            valid_r2  <= valid_r1;
            sign_r2   <= sign_a1 ^ sign_b1;
            exp_sum2  <= exp_a1 + exp_b1 - 8'd127;
            man_prod2 <= man_a1 * man_b1;
            dina_r2   <= dina_r1; dinb_r2 <= dinb_r1;
        end
    end

    // ==================== Stage 3: Normalize & GRS Extract ====================
    reg valid_r3;
    reg sign_r3;
    reg [8:0] exp_norm3;
    reg [23:0] man_norm3; // 24-bit including leading 1
    reg sticky3;
    reg round3;
    reg guard3;
    reg [31:0] dina_r3, dinb_r3;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) valid_r3 <= 1'b0;
        else begin
            valid_r3 <= valid_r2;
            sign_r3  <= sign_r2;
            dina_r3  <= dina_r2; dinb_r3 <= dinb_r2;
            
            if (man_prod2[47]) begin
                // 情况A: 结果在 [2.0, 4.0)，需要右移1位
                exp_norm3 <= exp_sum2 + 1'b1;
                man_norm3 <= man_prod2[47:24];
                guard3    <= man_prod2[23];
                round3    <= man_prod2[22];
                sticky3   <= |man_prod2[21:0];
            end else begin
                // 情况B: 结果在 [1.0, 2.0)，不需要位移
                exp_norm3 <= exp_sum2;
                man_norm3 <= man_prod2[46:23];
                guard3    <= man_prod2[22];
                round3    <= man_prod2[21];
                sticky3   <= |man_prod2[20:0];
            end
        end
    end

    // ==================== Stage 4: Rounding ====================
    reg valid_r4;
    reg [31:0] result_pre4;
    reg [8:0] exp_final4;
    reg sign_r4;
    reg [31:0] dina_r4, dinb_r4;

    wire round_en = guard3 && (round3 || sticky3 || man_norm3[0]); // Round-to-nearest-even

    always @(posedge clk or negedge rstn) begin
        if (!rstn) valid_r4 <= 1'b0;
        else begin
            valid_r4 <= valid_r3;
            sign_r4  <= sign_r3;
            dina_r4  <= dina_r3; dinb_r4 <= dinb_r3;

            if (round_en) begin
                if (man_norm3 == 24'hFFFFFF) begin // 舍入进位导致再次溢出
                    result_pre4[22:0] <= 23'h0;
                    exp_final4 <= exp_norm3 + 1'b1;
                end else begin
                    result_pre4[22:0] <= man_norm3[22:0] + 1'b1;
                    exp_final4 <= exp_norm3;
                end
            end else begin
                result_pre4[22:0] <= man_norm3[22:0];
                exp_final4 <= exp_norm3;
            end
        end
    end

    // ==================== Stage 5: Pack & Special Cases ====================
    reg [31:0] final_result;
    reg final_valid;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            final_result <= 32'h0;
            final_valid  <= 1'b0;
        end else begin
            final_valid <= valid_r4;
            
            // 溢出判定：exp_final4 >= 255 (注意它是带符号的 9-bit)
            if (exp_final4[8] || (dina_r4[30:0]==0) || (dinb_r4[30:0]==0)) begin
                final_result <= {sign_r4, 31'h0}; // Underflow or Zero
            end else if (exp_final4 >= 9'd255) begin
                final_result <= {sign_r4, 8'hFF, 23'h0}; // Overflow to Inf
            end else begin
                final_result <= {sign_r4, exp_final4[7:0], result_pre4[22:0]};
            end
        end
    end

    assign result = final_result;
    assign valid_out = final_valid;

endmodule