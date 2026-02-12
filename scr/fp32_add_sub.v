module fp32_adder_sub (
    input clk,
    input rstn,
    input [31:0]dina,
    input [31:0]dinb,
    input op,         // op=0: 加法, op=1: 减法
    input valid_in,
    output [31:0]result,
    output valid_out
);

    // ==================== Pipeline Stage 1: Extract components ====================
    reg [31:0] dina_r1, dinb_r1;
    reg op_r1, valid_r1;
    reg sign_a1, sign_b1;
    reg [7:0] exp_a1, exp_b1;
    reg [23:0] man_a1, man_b1;  // 包含隐含的1
    
    reg is_zero_a1, is_zero_b1;
    reg is_inf_a1, is_inf_b1;
    reg is_nan_a1, is_nan_b1;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            is_zero_a1 <= 1'b0;
            is_zero_b1 <= 1'b0;
            is_inf_a1 <= 1'b0;
            is_inf_b1 <= 1'b0;
            is_nan_a1 <= 1'b0;
            is_nan_b1 <= 1'b0;
            dina_r1 <= 32'h0;
            dinb_r1 <= 32'h0;
            op_r1 <= 1'b0;
            valid_r1 <= 1'b0;
            sign_a1 <= 1'b0;
            exp_a1 <= 8'h0;
            man_a1 <= 24'h0;
            sign_b1 <= 1'b0;
            exp_b1 <= 8'h0;
            man_b1 <= 24'h0;
        end else begin
            dina_r1 <= dina;
            dinb_r1 <= dinb;
            op_r1 <= op;
            valid_r1 <= valid_in;
            
            // Extract sign, exponent, mantissa
            sign_a1 <= dina[31];
            exp_a1 <= dina[30:23];
            man_a1 <= {(dina[30:23] != 8'h0), dina[22:0]};  // 隐含1，如果全是0则加上隐含的0
            
            sign_b1 <= dinb[31];
            exp_b1 <= dinb[30:23];
            man_b1 <= {(dinb[30:23] != 8'h0), dinb[22:0]};  // 隐含1

            is_zero_a1 <= (dina[30:0] == 31'h0);
            is_zero_b1 <= (dinb[30:0] == 31'h0);
            is_inf_a1 <= (dina[30:23] == 8'hFF) && (dina[22:0] == 23'h0);
            is_inf_b1 <= (dinb[30:23] == 8'hFF) && (dinb[22:0] == 23'h0);
            is_nan_a1 <= (dina[30:23] == 8'hFF) && (dina[22:0] != 23'h0);
            is_nan_b1 <= (dinb[30:23] == 8'hFF) && (dinb[22:0] != 23'h0);
        end
    end

    // ==================== Pipeline Stage 2: Prepare for addition ====================
    reg [7:0] exp_aligned2;
    reg [47:0] man_a2, man_b2;
    reg sign_a2, sign_b2_adj;
    reg [31:0] dina_r2, dinb_r2;
    reg valid_r2;
    reg is_zero_a2, is_zero_b2;
    reg is_inf_a2, is_inf_b2;
    reg is_nan_a2,is_nan_b2;
    
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            exp_aligned2 <= 8'h0;
            man_a2 <= 48'h0;
            man_b2 <= 48'h0;
            sign_a2 <= 1'b0;
            sign_b2_adj <= 1'b0;
            dina_r2 <= 32'h0;
            dinb_r2 <= 32'h0;
            valid_r2 <= 1'b0;
            is_zero_a2 <= 1'b0;
            is_zero_b2 <= 1'b0;
            is_inf_a2 <= 1'b0;
            is_inf_b2 <= 1'b0;
            is_nan_a2 <= 1'b0;
            is_nan_b2 <= 1'b0;

        end else begin
            is_zero_a2 <= is_zero_a1;
            is_zero_b2 <= is_zero_b1;
            is_inf_a2 <= is_inf_a1;
            is_inf_b2 <= is_inf_b1;
            is_nan_a2 <= is_nan_a1;
            is_nan_b2 <= is_nan_b1;

            dina_r2 <= dina_r1;
            dinb_r2 <= dinb_r1;
            valid_r2 <= valid_r1;
            
            // Adjust sign for subtraction
            sign_b2_adj <= (op_r1) ? ~sign_b1 : sign_b1;
            sign_a2 <= sign_a1;
            
            // Align exponents - shift the smaller mantissa
            if (exp_a1 >= exp_b1) begin
                exp_aligned2 <= exp_a1;
                man_a2 <= {man_a1, 24'h0};
                man_b2 <= {man_b1, 24'h0} >> (exp_a1 - exp_b1);
            end else begin
                exp_aligned2 <= exp_b1;
                man_b2 <= {man_b1, 24'h0};
                man_a2 <= {man_a1, 24'h0} >> (exp_b1 - exp_a1);
            end
        end
    end

    // ==================== Pipeline Stage 3: Add/Subtract mantissas ====================
    reg [48:0] man_result3;
    reg [7:0] exp_result3;
    reg sign_result3;
    reg valid_r3;

    reg sign_a3, sign_b3_adj;
    
    reg is_zero_a3, is_zero_b3;
    reg is_inf_a3, is_inf_b3;
    reg is_nan_a3, is_nan_b3;
        always @(posedge clk or negedge rstn) begin
            if (!rstn) begin
                is_zero_a3 <= 1'b0;
                is_zero_b3 <= 1'b0;
                is_inf_a3 <= 1'b0;
                is_inf_b3 <= 1'b0;
                is_nan_a3 <= 1'b0;
                is_nan_b3 <= 1'b0;
                sign_a3 <= 1'b0;
                sign_b3_adj <= 1'b0;
            end else begin
                is_zero_a3 <= is_zero_a2;
                is_zero_b3 <= is_zero_b2;
                is_inf_a3 <= is_inf_a2;
                is_inf_b3 <= is_inf_b2;
                is_nan_a3 <= is_nan_a2;
                is_nan_b3 <= is_nan_b2;
                sign_a3 <= sign_a2;
                sign_b3_adj <= sign_b2_adj;
            end
        end
    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            man_result3 <= 49'h0;
            exp_result3 <= 8'h0;
            sign_result3 <= 1'b0;
            valid_r3 <= 1'b0;
        end else begin
            exp_result3 <= exp_aligned2;
            valid_r3 <= valid_r2;
            
            if (sign_a2 == sign_b2_adj) begin
                // Same sign: add mantissas
                man_result3 <= {1'b0, man_a2} + {1'b0, man_b2};
                sign_result3 <= sign_a2;
            end else begin
                // Different signs: subtract mantissas
                if (man_a2 >= man_b2) begin
                    man_result3 <= {1'b0, man_a2} - {1'b0, man_b2};
                    sign_result3 <= sign_a2;
                end else begin
                    man_result3 <= {1'b0, man_b2} - {1'b0, man_a2};
                    sign_result3 <= sign_b2_adj;
                end
            end
        end
    end

    // ==================== Pipeline Stage 4: Normalize ====================
    // 使用优先编码器找到最高有效位的位置 (Count Leading Zeros)
    wire [5:0] clz;  // 0-48, 表示 [48] 到最高 1 的距离
    
    assign clz = 
        (man_result3[48]) ? 6'd0  :
        (man_result3[47]) ? 6'd1  :
        (man_result3[46]) ? 6'd2  :
        (man_result3[45]) ? 6'd3  :
        (man_result3[44]) ? 6'd4  :
        (man_result3[43]) ? 6'd5  :
        (man_result3[42]) ? 6'd6  :
        (man_result3[41]) ? 6'd7  :
        (man_result3[40]) ? 6'd8  :
        (man_result3[39]) ? 6'd9  :
        (man_result3[38]) ? 6'd10 :
        (man_result3[37]) ? 6'd11 :
        (man_result3[36]) ? 6'd12 :
        (man_result3[35]) ? 6'd13 :
        (man_result3[34]) ? 6'd14 :
        (man_result3[33]) ? 6'd15 :
        (man_result3[32]) ? 6'd16 :
        (man_result3[31]) ? 6'd17 :
        (man_result3[30]) ? 6'd18 :
        (man_result3[29]) ? 6'd19 :
        (man_result3[28]) ? 6'd20 :
        (man_result3[27]) ? 6'd21 :
        (man_result3[26]) ? 6'd22 :
        (man_result3[25]) ? 6'd23 :
        (man_result3[24]) ? 6'd24 :
        (man_result3[23]) ? 6'd25 :
        (man_result3[22]) ? 6'd26 :
        (man_result3[21]) ? 6'd27 :
        (man_result3[20]) ? 6'd28 :
        (man_result3[19]) ? 6'd29 :
        (man_result3[18]) ? 6'd30 :
        (man_result3[17]) ? 6'd31 :
        (man_result3[16]) ? 6'd32 :
        (man_result3[15]) ? 6'd33 :
        (man_result3[14]) ? 6'd34 :
        (man_result3[13]) ? 6'd35 :
        (man_result3[12]) ? 6'd36 :
        (man_result3[11]) ? 6'd37 :
        (man_result3[10]) ? 6'd38 :
        (man_result3[9])  ? 6'd39 :
        (man_result3[8])  ? 6'd40 :
        (man_result3[7])  ? 6'd41 :
        (man_result3[6])  ? 6'd42 :
        (man_result3[5])  ? 6'd43 :
        (man_result3[4])  ? 6'd44 :
        (man_result3[3])  ? 6'd45 :
        (man_result3[2])  ? 6'd46 :
        (man_result3[1])  ? 6'd47 :
        (man_result3[0])  ? 6'd48 :
        6'd49;  // 全0
    
    // 根据 clz 计算指数调整和尾数选择
    wire [7:0] shift_amount;
    wire signed [8:0] exp_adjusted;
    wire [23:0] mantissa_normalized;
    
    // shift_amount = clz - 1 (当 clz > 0 时)
    // 例如: clz=1(最高1在bit[47]) -> shift_amount=0 (不需要左移)
    //      clz=2(最高1在bit[46]) -> shift_amount=1 (左移1位)
    assign shift_amount = (clz == 6'd0) ? 6'd0 : (clz - 6'd1);
    
    // 指数调整: 如果右移(clz=0) 则 +1, 否则 -(clz-1)
    assign exp_adjusted = (clz == 6'd0) ? (exp_result3 + 8'd1) : (exp_result3 - {{2{shift_amount[5]}},shift_amount[5:0]});
    
    // 根据 clz 值选择提取的尾数部分 [25:2] (24位)
    // wire [23:0]manissa_temporary=(man_result3<<(shift_amount-1));
    // assign mantissa_normalized =manissa_temporary;  // 左移 clz 位后，取最高的 24 位作为尾数
    assign mantissa_normalized =
        (clz == 6'd0)  ? man_result3[47:25] :   // right shift 1: take [47:25]
        (clz == 6'd1)  ? man_result3[46:24] :   // no shift: take [46:24]
        (clz == 6'd2)  ? man_result3[45:23] :   // left shift 1: take [45:23]
        (clz == 6'd3)  ? man_result3[44:22] :   // left shift 2: take [44:22]
        (clz == 6'd4)  ? man_result3[43:21] :   // left shift 3: take [43:21]
        (clz == 6'd5)  ? man_result3[42:20] :   // left shift 4: take [42:20]
        (clz == 6'd6)  ? man_result3[41:19] :   // left shift 5: take [41:19]
        (clz == 6'd7)  ? man_result3[40:18] :
        (clz == 6'd8)  ? man_result3[39:17] :
        (clz == 6'd9)  ? man_result3[38:16] :
        (clz == 6'd10) ? man_result3[37:15] :
        (clz == 6'd11) ? man_result3[36:14] :
        (clz == 6'd12) ? man_result3[35:13] :
        (clz == 6'd13) ? man_result3[34:12] :
        (clz == 6'd14) ? man_result3[33:11] :
        (clz == 6'd15) ? man_result3[32:10] :
        (clz == 6'd16) ? man_result3[31:9]  :
        (clz == 6'd17) ? man_result3[30:8]  :
        (clz == 6'd18) ? man_result3[29:7]  :
        (clz == 6'd19) ? man_result3[28:6]  :
        (clz == 6'd20) ? man_result3[27:5]  :
        (clz == 6'd21) ? man_result3[26:4]  :
        (clz == 6'd22) ? man_result3[25:3]  :
        (clz == 6'd23) ? man_result3[24:2]  :
        (clz == 6'd24) ? man_result3[23:1]  :
        24'h0;  // clz >= 25 时，尾数太小，无法规范化
    
    reg [31:0] result_r4;
    reg valid_r4;
    
always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            result_r4 <= 32'h0;
            valid_r4 <= 1'b0;
        end else begin
            valid_r4 <= valid_r3;
            
            // 优先级 Check 1: NaN (最高优先级)
            if(is_nan_a3 || is_nan_b3) begin
                result_r4 <= 32'h7FC00000;
            end 
            // 优先级 Check 2: Inf (处理 Inf+Inf 和 Inf-Inf)
            else if (is_inf_a3 || is_inf_b3) begin
                if (is_inf_a3 && is_inf_b3) begin
                    // 如果符号相同 -> Inf, 符号不同 -> NaN
                    result_r4 <= (sign_a3 == sign_b3_adj) ? {sign_a3, 8'hFF, 23'h0} : 32'h7FC00000;
                end else if (is_inf_a3) begin
                    result_r4 <= {sign_a3, 8'hFF, 23'h0};
                end else begin
                    result_r4 <= {sign_b3_adj, 8'hFF, 23'h0};
                end
            end
            // 优先级 Check 3: Zero (处理 0+0)
            else if (is_zero_a3 && is_zero_b3) begin
                result_r4 <= (op_r1) ? {sign_a3 & sign_b3_adj, 31'h0} : {sign_a3 | sign_b3_adj, 31'h0};
            end 
            // 优先级 Check 4: 正常数值计算 (包括计算结果下溢变成0的情况)
            else begin
                if (man_result3 == 49'h0 || clz > 6'd24) begin
                    result_r4 <= 32'h0; // 结果确实为0 (例如 5.0 - 5.0)
                end else if (exp_adjusted <= 8'd0) begin
                    result_r4 <= 32'h0; // 下溢
                end else if (exp_adjusted >= 9'd255) begin
                    result_r4 <= {sign_result3, 8'hFF, 23'h0}; // 溢出变 Inf
                end else begin
                    result_r4 <= {sign_result3, exp_adjusted[7:0], mantissa_normalized[22:0]};
                end
            end
        end
    end
    assign result = result_r4;
    assign valid_out = valid_r4;

endmodule