module fp32_adder_sub_comb(
    input clk,
    input rstn,
    input [31:0] dina,
    input [31:0] dinb,
    input op,
    input valid_in,
    output [31:0] result,
    output valid_out
);

//--1.
wire sign_a=dina[31];
wire sign_b=dinb[31]^op;
wire[7:0] exp_a=dina[30:23];
wire[7:0] exp_b=dinb[30:23];
wire[23:0] man_a=(dina[30:23]!=0)? {1'b1,dina[22:0]}:{1'b0,dina[22:0]};
wire[23:0] man_b=(dinb[30:23]!=0)? {1'b1,dinb[22:0]}:{1'b0,dinb[22:0]};

//--2
wire [7:0] exp_aligned=(exp_a>=exp_b)?exp_a:exp_b;
wire [47:0] man_aligned_a=(exp_a>=exp_b)?{man_a,24'h0}:{man_a,24'h0}>>(exp_b-exp_a);
wire [47:0] man_aligned_b=(exp_a>=exp_b)?{man_b,24'h0}>>(exp_a-exp_b):{man_b,24'h0};

//--3
wire [48:0]man_result=(sign_a==sign_b)? ({1'b0,man_aligned_a}+{1'b0,man_aligned_b}):
                      (man_aligned_a>=man_aligned_b)? ({1'b0,man_aligned_a}-{1'b0,man_aligned_b}):
                        ({1'b0,man_aligned_b}-{1'b0,man_aligned_a});

wire [7:0] exp_result=exp_aligned;
wire sign_result=(sign_a==sign_b)?sign_a:
                 (man_aligned_a>=man_aligned_b)? sign_a:sign_b;


wire [5:0] clz;  // 0-48, 表示 [48] 到最高 1 的距离
    
    assign clz = (man_result[48]) ? 6'd0  :
        (man_result[47]) ? 6'd1  :
        (man_result[46]) ? 6'd2  :
        (man_result[45]) ? 6'd3  :
        (man_result[44]) ? 6'd4  :
        (man_result[43]) ? 6'd5  :
        (man_result[42]) ? 6'd6  :
        (man_result[41]) ? 6'd7  :
        (man_result[40]) ? 6'd8  :
        (man_result[39]) ? 6'd9  :
        (man_result[38]) ? 6'd10 :
        (man_result[37]) ? 6'd11 :
        (man_result[36]) ? 6'd12 :
        (man_result[35]) ? 6'd13 :
        (man_result[34]) ? 6'd14 :
        (man_result[33]) ? 6'd15 :
        (man_result[32]) ? 6'd16 :
        (man_result[31]) ? 6'd17 :
        (man_result[30]) ? 6'd18 :
        (man_result[29]) ? 6'd19 :
        (man_result[28]) ? 6'd20 :
        (man_result[27]) ? 6'd21 :
        (man_result[26]) ? 6'd22 :
        (man_result[25]) ? 6'd23 :
        (man_result[24]) ? 6'd24 :
        (man_result[23]) ? 6'd25 :
        (man_result[22]) ? 6'd26 :
        (man_result[21]) ? 6'd27 :
        (man_result[20]) ? 6'd28 :
        (man_result[19]) ? 6'd29 :
        (man_result[18]) ? 6'd30 :
        (man_result[17]) ? 6'd31 :
        (man_result[16]) ? 6'd32 :
        (man_result[15]) ? 6'd33 :
        (man_result[14]) ? 6'd34 :
        (man_result[13]) ? 6'd35 :
        (man_result[12]) ? 6'd36 :
        (man_result[11]) ? 6'd37 :
        (man_result[10]) ? 6'd38 :
        (man_result[9])  ? 6'd39 :
        (man_result[8])  ? 6'd40 :
        (man_result[7])  ? 6'd41 :
        (man_result[6])  ? 6'd42 :
        (man_result[5])  ? 6'd43 :
        (man_result[4])  ? 6'd44 :
        (man_result[3])  ? 6'd45 :
        (man_result[2])  ? 6'd46 :
        (man_result[1])  ? 6'd47 :
        (man_result[0])  ? 6'd48 :
        6'd49;  // 全0

        wire [7:0] shift_amount;
        wire signed [8:0] exp_adjusted ;
        wire [23:0] mantissa_normalized;

        assign shift_amount = (clz == 6'd0) ? 6'd0 : (clz - 6'd1);
        
        assign exp_adjusted=(clz==0)?(exp_result+1):(exp_result-{{2{shift_amount[5]}},shift_amount[5:0]});

         assign mantissa_normalized =
        (clz == 6'd0)  ? man_result[47:25] :   // right shift 1: take [47:25]
        (clz == 6'd1)  ? man_result[46:24] :   // no shift: take [46:24]
        (clz == 6'd2)  ? man_result[45:23] :   // left shift 1: take [45:23]
        (clz == 6'd3)  ? man_result[44:22] :   // left shift 2: take [44:22]
        (clz == 6'd4)  ? man_result[43:21] :   // left shift 3: take [43:21]
        (clz == 6'd5)  ? man_result[42:20] :   // left shift 4: take [42:20]
        (clz == 6'd6)  ? man_result[41:19] :   // left shift 5: take [41:19]
        (clz == 6'd7)  ? man_result[40:18] :
        (clz == 6'd8)  ? man_result[39:17] :
        (clz == 6'd9)  ? man_result[38:16] :
        (clz == 6'd10) ? man_result[37:15] :
        (clz == 6'd11) ? man_result[36:14] :
        (clz == 6'd12) ? man_result[35:13] :
        (clz == 6'd13) ? man_result[34:12] :
        (clz == 6'd14) ? man_result[33:11] :
        (clz == 6'd15) ? man_result[32:10] :
        (clz == 6'd16) ? man_result[31:9]  :
        (clz == 6'd17) ? man_result[30:8]  :
        (clz == 6'd18) ? man_result[29:7]  :
        (clz == 6'd19) ? man_result[28:6]  :
        (clz == 6'd20) ? man_result[27:5]  :
        (clz == 6'd21) ? man_result[26:4]  :
        (clz == 6'd22) ? man_result[25:3]  :
        (clz == 6'd23) ? man_result[24:2]  :
        (clz == 6'd24) ? man_result[23:1]  :
        24'h0;  // clz >= 25 时，尾数太小，无法规范化

        reg[31:0] result_r;
        reg valid_r;
        
        always @(posedge clk or negedge rstn) begin
        if (!rstn) begin
            result_r <= 32'h0;
            valid_r <= 1'b0;
        end else begin
            valid_r <= valid_in;
            
            if (man_result == 49'h0 || clz > 6'd24) begin
                // 结果为零或尾数太小无法规范化
                result_r <= 32'h0;
            end else if (exp_adjusted <= 8'd0) begin
                // 指数下溢，结果为零（不处理subnormal数）
                result_r <= 32'h0;
            end else if (exp_adjusted >= 9'd255) begin
                // 指数溢出，结果为无穷大
                result_r <= {sign_result, 8'hFF, 23'h0};
            end else begin
                // 正常输出：{符号位, 8位指数, 23位尾数}
                result_r <= {sign_result, exp_adjusted[7:0], mantissa_normalized[22:0]};
            end
        end
    end

    assign result = result_r;
    assign valid_out = valid_r;


endmodule