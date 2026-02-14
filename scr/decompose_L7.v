`timescale 1ns/1ns
 `define VIVADO_SIM
`ifndef VIVADO_SIM
    `include "../../scr/fp32_mult.v"
    `include "../../scr/fp32_add_sub.v"
`endif

module decompose_L7 #(
parameter [31:0]DEC_H0 = 32'hbd9b2b0e, // Float: -0.07576571
parameter [31:0]DEC_H1 = 32'hbcf2c635, // Float: -0.02963553
parameter [31:0]DEC_H2 = 32'h3efec7e0, // Float: 0.49761867
parameter [31:0]DEC_H3 = 32'h3f4dc1d3, // Float: 0.80373875
parameter [31:0]DEC_H4 = 32'h3e9880d1, // Float: 0.29785780
parameter [31:0]DEC_H5 = 32'hbdcb339e, // Float: -0.09921954
parameter [31:0]DEC_H6 = 32'hbc4e80df, // Float: -0.01260397
parameter [31:0]DEC_H7 = 32'h3d03fc5f  // Float: 0.03222310  
)(
    input clk_78_125,
    input clk_312_5,
    input rstn,
    input din_valid,
    input [31:0] a6_0,
    output reg dout_valid,
    output reg [31:0]a7_0
); 

reg [27:0] has_data;
always@(posedge clk_78_125 or negedge rstn) begin
    if(!rstn)
        has_data<=0;
    else 
        has_data<={has_data[26:0],din_valid};
end

reg [31:0] x_hist_temp[0:6];
always@(posedge clk_78_125 or negedge rstn) begin
  if(!rstn) begin
    x_hist_temp[0]<=0;x_hist_temp[1]<=0;x_hist_temp[2]<=0;
    x_hist_temp[3]<=0;x_hist_temp[4]<=0;x_hist_temp[5]<=0;
    x_hist_temp[6]<=0;
  end else if(din_valid) begin
    x_hist_temp[0]<=a6_0;
    x_hist_temp[1]<=x_hist_temp[0];
    x_hist_temp[2]<=x_hist_temp[1];
    x_hist_temp[3]<=x_hist_temp[2];
    x_hist_temp[4]<=x_hist_temp[3];
    x_hist_temp[5]<=x_hist_temp[4];
    x_hist_temp[6]<=x_hist_temp[5];
  end
end

reg [2:0] cnt;
wire pos_clk_slow;
reg clk_slow_d1;
wire clk_slow=clk_78_125;

always @(posedge clk_312_5) begin
    clk_slow_d1<=clk_78_125;
end

assign pos_clk_slow=clk_slow&(~clk_slow_d1);

//cnt=3->0的时�?? 上升�??
always @(posedge clk_312_5 or negedge rstn) begin
    if(!rstn) begin
        cnt<=0;
    end else if(pos_clk_slow)//cnt_78_125上升沿对齐cnt=0
            cnt<=1;
        else if(cnt==3)
            cnt<=0;
        else 
            cnt<=cnt+1;
end

reg phase_cnt;

always@(posedge clk_312_5 or negedge rstn) begin
    if(!rstn)
        phase_cnt<=0;
    else if(pos_clk_slow&has_data[27])//此时刚好准备�?1个curr数据�?7个历史的数据,phase_cnt 0->1
        phase_cnt<=~phase_cnt;//由于has_data[27]为valid_din的延迟，因此，has_data[27]�?4个周期才1
        //phase_cnt�?8个周期才�?1
end

wire valid_next=(cnt==3&phase_cnt);//�?8个周期有效一�?
reg mult_valid_in;
reg [31:0] curr_din[0:0];
reg [31:0] x_hist[0:6];

always@(posedge clk_312_5) begin
  mult_valid_in<=(valid_next)&(has_data[27]);
  curr_din[0]<=a6_0;
  x_hist[0]<=x_hist_temp[0];x_hist[4]<=x_hist_temp[4];
  x_hist[1]<=x_hist_temp[1];x_hist[5]<=x_hist_temp[5];
  x_hist[2]<=x_hist_temp[2];x_hist[6]<=x_hist_temp[6];
  x_hist[3]<=x_hist_temp[3];
end

wire [31:0] product[0:0][0:7];
wire mult_valid_out;
fp32_mult fp32_mult_l7_dec_0_0(clk_312_5,rstn,curr_din[0],DEC_H0,mult_valid_in,product[0][0],mult_valid_out);              
fp32_mult fp32_mult_l7_dec_0_1(clk_312_5,rstn,x_hist[0],  DEC_H1,mult_valid_in,product[0][1],              );
fp32_mult fp32_mult_l7_dec_0_2(clk_312_5,rstn,x_hist[1],  DEC_H2,mult_valid_in,product[0][2],              );
fp32_mult fp32_mult_l7_dec_0_3(clk_312_5,rstn,x_hist[2],  DEC_H3,mult_valid_in,product[0][3],              );
fp32_mult fp32_mult_l7_dec_0_4(clk_312_5,rstn,x_hist[3],  DEC_H4,mult_valid_in,product[0][4],              );
fp32_mult fp32_mult_l7_dec_0_5(clk_312_5,rstn,x_hist[4],  DEC_H5,mult_valid_in,product[0][5],              );
fp32_mult fp32_mult_l7_dec_0_6(clk_312_5,rstn,x_hist[5],  DEC_H6,mult_valid_in,product[0][6],              );
fp32_mult fp32_mult_l7_dec_0_7(clk_312_5,rstn,x_hist[6],  DEC_H7,mult_valid_in,product[0][7],              );

reg mult_valid_out_d1;
reg [31:0] product_d1[0:0][0:7];
integer i,j;

always@(posedge clk_312_5)begin
  mult_valid_out_d1<=mult_valid_out;
    for(i=0;i<1;i=i+1)
        for(j=0;j<8;j=j+1)
        product_d1[i][j]<=product[i][j];
end


wire add_valid_in_0=mult_valid_out_d1;
wire add_valid_out_0;
wire [31:0] sum0[0:0][0:3];
fp32_add_sub fp32_adder_sub_l7_dec_0_0_0(clk_312_5,rstn,product_d1[0][0],product_d1[0][1],1'b0,add_valid_in_0,sum0[0][0],add_valid_out_0);
fp32_add_sub fp32_adder_sub_l7_dec_0_0_1(clk_312_5,rstn,product_d1[0][2],product_d1[0][3],1'b0,add_valid_in_0,sum0[0][1],              );
fp32_add_sub fp32_adder_sub_l7_dec_0_0_2(clk_312_5,rstn,product_d1[0][4],product_d1[0][5],1'b0,add_valid_in_0,sum0[0][2],              );
fp32_add_sub fp32_adder_sub_l7_dec_0_0_3(clk_312_5,rstn,product_d1[0][6],product_d1[0][7],1'b0,add_valid_in_0,sum0[0][3],              );

reg add_valid_out_0_d1;
reg [31:0] sum0_d1[0:0][0:3];
always@(posedge clk_312_5) begin
    add_valid_out_0_d1<=add_valid_out_0;
        for(i=0;i<1;i=i+1)
            for(j=0;j<4;j=j+1)
            sum0_d1[i][j]<=sum0[i][j];
end

wire add_valid_in_1=add_valid_out_0_d1;
wire add_valid_out_1;
wire [31:0] sum1[0:0][0:1];
fp32_add_sub fp32_adder_sub_l7_dec_1_0_0(clk_312_5,rstn,sum0_d1[0][0],sum0_d1[0][1],1'b0,add_valid_in_1,sum1[0][0],add_valid_out_1);
fp32_add_sub fp32_adder_sub_l7_dec_1_0_1(clk_312_5,rstn,sum0_d1[0][2],sum0_d1[0][3],1'b0,add_valid_in_1,sum1[0][1],              ); 

reg add_valid_out_1_d1;
reg [31:0] sum1_d1[0:0][0:1];
always@(posedge clk_312_5) begin
    add_valid_out_1_d1<=add_valid_out_1;
        for(i=0;i<1;i=i+1)
            for(j=0;j<2;j=j+1)
            sum1_d1[i][j]<=sum1[i][j];
end

wire add_valid_in_2=add_valid_out_1_d1;
wire add_valid_out_2;
wire [31:0] sum2[0:0][0:0];
fp32_add_sub fp32_adder_sub_l7_dec_2_0_0(clk_312_5,rstn,sum1_d1[0][0],sum1_d1[0][1],1'b0,add_valid_in_2,sum2[0][0],add_valid_out_2);

always @(posedge clk_312_5) begin
    dout_valid<=add_valid_out_2;
    a7_0<=sum2[0][0];
end

endmodule