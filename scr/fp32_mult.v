// `timescale 1ns / 1ps

// module fp32_mult(
//     input wire clk,
//     input wire rst_n,
//     input wire [31:0] a,
//     input wire [31:0] b,
//     input wire valid_in,
//     output reg [31:0] result,
//     output reg valid_out
// );

//     // =========================================================================
//     // Stage 1: Unpack, Special Check, Pre-calc Exponent
//     // =========================================================================
//     reg s1_valid;
//     reg s1_sign_res;
//     reg [9:0] s1_exp_sum; // ea + eb (no bias sub yet)
//     reg [23:0] s1_mant_a;
//     reg [23:0] s1_mant_b;
    
//     // Special case flags passing through pipeline
//     reg s1_is_nan, s1_is_inf, s1_is_zero;
    
//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             s1_valid <= 0;
//             s1_sign_res <= 0;
//             s1_exp_sum <= 0;
//             s1_mant_a <= 0;
//             s1_mant_b <= 0;
//             s1_is_nan <= 0;
//             s1_is_inf <= 0;
//             s1_is_zero <= 0;
//         end else begin
//             s1_valid <= valid_in;
//             if (valid_in) begin
//                 // 1. Unpack
//                 s1_sign_res <= a[31] ^ b[31];
                
//                 // 2. Special Case Detection Logic
//                 //一个操作数为nan,结果为nan
//                 //一个操作数为inf,另一个为0,结果为nan
//                 s1_is_nan <= (&a[30:23] && |a[22:0]) || (&b[30:23] && |b[22:0]); 
//                 s1_is_inf <= (&a[30:23] && ~|a[22:0]) || (&b[30:23] && ~|b[22:0]);
//                 s1_is_zero <= (~|a[30:23] && ~|a[22:0]) || (~|b[30:23] && ~|b[22:0]);

//                 // 3. Exponent Addition (Logic only, no bias sub yet to avoid negative)
//                 s1_exp_sum <= {2'b0, a[30:23]} + {2'b0, b[30:23]};

//                 // 4. Prepare Mantissas (Add hidden bit 1)
//                 // If exponent is 0 (denormal), we treat it as 0 for simplification here
//                 s1_mant_a <= (a[30:23] == 0) ? 24'd0 : {1'b1, a[22:0]};
//                 s1_mant_b <= (b[30:23] == 0) ? 24'd0 : {1'b1, b[22:0]};
//             end
//         end
//     end

//     // =========================================================================
//     // Stage 2: Mantissa Multiplication (Part 1 / DSP Input) & Exponent Bias
//     // =========================================================================
//     // FPGA synthesizers usually map "reg * reg" to DSP blocks automatically.
//     // We register the inputs to the multiplier effectively in Stage 1, 
//     // and let the multiplier logic span Stage 2 and 3.
    
//     reg s2_valid;
//     reg s2_sign_res;
//     reg [9:0] s2_exp_unbiased;
//     reg s2_is_nan, s2_is_inf, s2_is_zero;
    
//     // We perform multiplication here. 
//     // For high freq, this might need to be split, but 24x24 fits in modern DSPs.
//     reg [47:0] s2_prod_mant; 

//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             s2_valid <= 0;
//             s2_prod_mant <= 0;
//             s2_exp_unbiased <= 0;
//             s2_sign_res <= 0;
//             s2_is_nan <= 0; s2_is_inf <= 0; s2_is_zero <= 0;
//         end else begin
//             s2_valid <= s1_valid;
//             s2_sign_res <= s1_sign_res;
//             s2_is_nan <= s1_is_nan; 
//             s2_is_inf <= s1_is_inf; 
//             s2_is_zero <= s1_is_zero;
            
//             // Exponent calculation: sum - 127
//             s2_exp_unbiased <= s1_exp_sum - 10'd127;
            
//             // Multiplication
//             s2_prod_mant <= s1_mant_a * s1_mant_b;
//             end
//         end

//     // =========================================================================
//     // Stage 3: Normalization Check & Shift Preparation
//     // =========================================================================
//     reg s3_valid;
//     reg s3_sign_res;
//     reg [9:0] s3_exp_norm;
//     reg [47:0] s3_prod_mant_shifted;
//     reg s3_is_nan, s3_is_inf, s3_is_zero;
//     reg shift_right; // Indicates if we need to shift right (if MSB is 1)

//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             s3_valid <= 0;
//             s3_sign_res <= 0;
//             s3_exp_norm <= 0;
//             s3_prod_mant_shifted <= 0;
//             s3_is_nan <= 0; s3_is_inf <= 0; s3_is_zero <= 0;
//             shift_right <= 0;
//         end else begin
//             s3_valid <= s2_valid;
//             s3_sign_res <= s2_sign_res;
//             s3_is_nan <= s2_is_nan; s3_is_inf <= s2_is_inf; s3_is_zero <= s2_is_zero;
            
//                 // Normalization Logic:
//                 // If MSB (bit 47) is 1, we need to shift right logic (essentially no shift relative to exp+1)
//                 // If MSB is 0, we treat bit 46 as leading 1.
                
//                 if (s2_prod_mant[47]) begin
//                     s3_prod_mant_shifted <= s2_prod_mant; // Normalized aligned to 47
//                     s3_exp_norm <= s2_exp_unbiased + 1;
//                     shift_right <= 1;
//                 end else begin
//                     s3_prod_mant_shifted <= s2_prod_mant << 1; // Align 46 to 47
//                     s3_exp_norm <= s2_exp_unbiased;
//                     shift_right <= 0;
//                 end
//             end
//         end

//     // =========================================================================
//     // Stage 4: Rounding Bit Calculation & Rounding Adder
//     // =========================================================================
//     reg s4_valid;
//     reg s4_sign_res;
//     reg [9:0] s4_exp;
//     reg [23:0] s4_mant_rounded; // 24 bits (1.xxxx) + overflow space
//     reg s4_is_nan, s4_is_inf, s4_is_zero;
//     reg s4_mant_overflow;

//     wire round_bit;
//     wire sticky_bit;
//     wire round_up;

//     //round_bit是截取的位数的下一位，如果=1说明，需要进行进位
//     //sticky_bit为round_bits以后的位
//     //如果round_bits=1且sticky_bits=1说明截取的超过了0.5，需要进位
//     wire [23:0] mant_norm_candidate =shift_right? s3_prod_mant_shifted[47:24]:s3_prod_mant_shifted[46:23];
//     assign round_bit = (shift_right)? s3_prod_mant_shifted[23]: s3_prod_mant_shifted[22];
//     assign sticky_bit = (shift_right)? |s3_prod_mant_shifted[22:0]: |s3_prod_mant_shifted[21:0];
//     assign round_up = round_bit && sticky_bit ; 

//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             s4_valid <= 0;
//             s4_sign_res <= 0;
//             s4_exp <= 0;
//             s4_mant_rounded <= 0;
//             s4_mant_overflow <= 0;
//             s4_is_nan <= 0; s4_is_inf <= 0; s4_is_zero <= 0;
//         end else begin
//             s4_valid <= s3_valid;
//             s4_sign_res <= s3_sign_res;
//             s4_is_nan <= s3_is_nan; s4_is_inf <= s3_is_inf; s4_is_zero <= s3_is_zero;
//             s4_exp <= s3_exp_norm;

//             // Perform Rounding Addition
//             // Extract top 24 bits: [47:24]
//             // Note: We deliberately use 25 bits to catch overflow (1.11... + 1 -> 10.00...)
//             {s4_mant_overflow, s4_mant_rounded} <= {1'b0, mant_norm_candidate} + round_up;
//             end
//         end


//     // =========================================================================
//     // Stage 5: Final Output Construction (Pack & Exception Handling)
//     // =========================================================================
//     reg [31:0] s5_final_result;
    
//     // Logic on S4 outputs
//     wire [22:0] final_mant;
//     wire [9:0] final_exp_pre;
//     wire [7:0] final_exp;
//     wire result_overflow;
//     wire result_underflow;

//     // Handle rounding overflow (e.g. 1.111 + 1 = 10.000)
//     // If overflow, mantissa becomes 0 (hidden 1 moves up), exp increments
//     assign final_exp_pre = s4_mant_overflow ? (s4_exp + 1) : s4_exp;
//     assign final_mant = s4_mant_overflow ? s4_mant_rounded[23:1] : s4_mant_rounded[22:0]; // Drop hidden bit

//     // Overflow/Underflow Detection
//     // Note: Signed check on exponent logic
//     assign result_overflow = ($signed(final_exp_pre) >= 255);
//     assign result_underflow = ($signed(final_exp_pre) <= 0);
    
//     // Clamp Exponent for standard output
//     assign final_exp = result_overflow ? 8'hFF : (result_underflow ? 8'h00 : final_exp_pre[7:0]);

//     always @(posedge clk or negedge rst_n) begin
//         if (!rst_n) begin
//             valid_out <= 0;
//             result <= 0;
//         end else begin
//             valid_out <= s4_valid;
            
//             if (s4_valid) begin
//                 if (s4_is_nan) begin
//                     // NaN
//                     result <= {1'b0, 8'hFF, 1'b1, 22'd1}; 
//                 end else if (s4_is_inf) begin
//                     // Infinity (Check if 0 * Inf -> NaN, else Inf)
//                     if (s4_is_zero) // Means one was Inf and other was Zero
//                         result <= {1'b1, 8'hFF, 1'b1, 22'd1}; // NaN
//                     else
//                         result <= {s4_sign_res, 8'hFF, 23'd0}; // Inf
//                 end else if (s4_is_zero || result_underflow) begin
//                     // Zero or Underflow
//                     result <= {s4_sign_res, 8'd0, 23'd0};
//                 end else if (result_overflow) begin
//                     // Overflow -> Inf
//                     result <= {s4_sign_res, 8'hFF, 23'd0};
//                 end else begin
//                     // Normal Result
//                     result <= {s4_sign_res, final_exp, final_mant};
//                 end
//             end
//         end
//     end

// endmodule

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
    reg signed [8:0] exp_a1, exp_b1;
    reg [23:0] man_a1, man_b1;

    always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            valid_r1 <= 1'b0;
        end else begin
            valid_r1 <= valid_din;
            dina_r1 <= dina; dinb_r1 <= dinb;
            sign_a1 <= dina[31]; sign_b1 <= dinb[31];
            exp_a1  <= {1'b0,dina[30:23]}; exp_b1  <= {1'b0,dinb[30:23]};
            // 隐含位处理：全0为非规约数（简化处理为0.m），否则加1
            man_a1  <= (dina[30:23] == 8'h0) ? {1'b0,dina[22:0]} : {1'b1, dina[22:0]};
            man_b1  <= (dinb[30:23] == 8'h0) ? {1'b0,dinb[22:0]} : {1'b1, dinb[22:0]};
        end
    end

    // ==================== Stage 2: Multiply & Exp Add ====================
    reg valid_r2;
    reg sign_r2;
    reg signed [9:0] exp_sum2;
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
    reg signed[9:0] exp_norm3;
    reg [23:0] man_norm3; // 24-bit including leading 1
    reg sticky3;
    reg round3;
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
                round3    <= man_prod2[23];
                sticky3   <= |man_prod2[22:0];
            end else begin
                // 情况B: 结果在 [1.0, 2.0)，不需要位移
                exp_norm3 <= exp_sum2;
                man_norm3 <= man_prod2[46:23];
                round3    <= man_prod2[22];
                sticky3   <= |man_prod2[21:0];
            end
        end
    end

    // ==================== Stage 4: Rounding ====================
    reg valid_r4;
    reg [31:0] result_pre4;
    reg signed [9:0] exp_final4;
    reg sign_r4;
    reg [31:0] dina_r4, dinb_r4;

    wire round_en = sticky3 && (round3); // Round-to-nearest-even


    always @(posedge clk or negedge rstn) begin
        if (!rstn) valid_r4 <= 1'b0;
        else begin
            valid_r4 <= valid_r3;
            sign_r4  <= sign_r3;
            dina_r4  <= dina_r3; dinb_r4 <= dinb_r3;

            if (round_en) begin
                if (man_norm3 == 24'hFFFFFF) begin // 舍入进位导致再次溢出
                    result_pre4[22:0] <= 23'h0;//此处已经将1去掉
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
    wire is_zero=(~|dina_r4[30:0]) || (~|dinb_r4[30:0]);
    wire is_inf=(&dina_r4[30:23] && ~|dina_r4[22:0]) || (&dinb_r4[30:23] && ~|dinb_r4[22:0]);
    wire is_nan=(&dina_r4[30:23] && |dina_r4[22:0]) || (&dinb_r4[30:23] && |dinb_r4[22:0]);
    
    always @(posedge clk or negedge rstn) 
        if (!rstn) begin
            final_result <= 32'h0;
            final_valid  <= 1'b0;
        end else begin
            final_valid <= valid_r4;
            if(is_nan) begin
                final_result <= 32'h7fc00000; // NaN
            end else if(is_inf) begin
                if(is_zero) // 0*inf=nan
                    final_result <= 32'h7fc00000; // NaN
                else
                    final_result <= {sign_r4, 8'hff, 23'h0}; // Inf
            end
            else if(is_zero) begin
                final_result <= {sign_r4, 31'h0}; // Zero
            end
            else if (exp_final4>= 255) begin
                final_result <= {sign_r4, 8'hFF, 23'h0}; // Overflow to Inf
            end else if(exp_final4 <= 0) begin
                final_result <= {sign_r4, 31'h0}; // Underflow to Zero
            end else
            begin
                final_result <= {sign_r4, exp_final4[7:0], result_pre4[22:0]};
            end
        end
    

    assign result = final_result;
    assign valid_out = final_valid;

endmodule