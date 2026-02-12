`timescale 1ns/1ns
// `define VIVADO_SIM
`define DEBUG_DECOMPOSE_L1
`ifndef VIVADO_SIM
    `include "../../scr/fp32_mult.v"
    `include "../../scr/fp32_add_sub.v"
`endif

module decompose_L5#(
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
    input [31:0] a4_0,
    output reg dout_valid,
    output reg a5_0
);

reg [7:0] has_data;
always@(posedge clk_78_125 or negedge rstn) begin
    if(!rstn)
        has_data<=0;
    else 
        has_data<={has_data[6:0],din_valid};
end 

reg [31:0] x_hist_temp[0:6];

always@(posedge clk_78_125 or negedge rstn) begin
  if(!rstn) begin
    x_hist_temp[0]<=0;x_hist_temp[1]<=0;x_hist_temp[2]<=0;
    x_hist_temp[3]<=0;x_hist_temp[4]<=0;x_hist_temp[5]<=0;
    x_hist_temp[6]<=0;
  end else if(din_valid) begin
    x_hist_temp[0]<=a3_1;
    x_hist_temp[1]<=a3_0;
    x_hist_temp[2]<=x_hist_temp[0];
    x_hist_temp[3]<=x_hist_temp[1];
    x_hist_temp[4]<=x_hist_temp[2];
    x_hist_temp[5]<=x_hist_temp[3];
    x_hist_temp[6]<=x_hist_temp[4];
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

//cnt=3->0的时�? 上升�?
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

wire valid_next=(cnt==3);


endmodule