`timescale 1ns/1ns
 `define VIVADO_SIM
`define DEBUG_DECOMPOSE_L1
`ifndef VIVADO_SIM
    `include "../../scr/fp32_mult.v"
    `include "../../scr/fp32_add_sub.v"
`endif 
//din_valid-has_data->mult_valid_in->mult_valid_out->add_valid_in_0->add_valid_out_0->add_valid_in_1->add_valid_out_1->add_valid_in_2->add_valid_out_2->dout_valid
//0        1*t_slow  +1*t_slow        +5tfast       +1tfast         +4tfast          +1tfast         +4tfast          +1tfast         +4tfast          +1tfast             
//            cnt=3 
//                   mult_valid_in=0
//                   curr_din  

//din_valid ->dout_valid 2tslow+21tfast

module decompose_L1#(
    parameter [31:0]  DEC_H0 = 0,
    parameter [31:0]  DEC_H1 = 0,
    parameter [31:0]  DEC_H2 = 0,
    parameter [31:0]  DEC_H3 = 0,
    parameter [31:0]  DEC_H4 = 0,
    parameter [31:0]  DEC_H5 = 0,
    parameter [31:0]  DEC_H6 = 0,
    parameter  [31:0] DEC_H7 = 0
)(
    input wire clk_78_125,
    input wire clk_312_5,
    input wire rstn,
    input wire din_valid,

    input wire [31:0] din_0,
    input wire [31:0] din_1,
    input wire [31:0] din_2,
    input wire [31:0] din_3,
    input wire [31:0] din_4,
    input wire [31:0] din_5,
    input wire [31:0] din_6,
    input wire [31:0] din_7,
    input wire [31:0] din_8,
    input wire [31:0] din_9,
    input wire [31:0] din_10,
    input wire [31:0] din_11,
    input wire [31:0] din_12,
    input wire [31:0] din_13,
    input wire [31:0] din_14,
    input wire [31:0] din_15,
    
    output reg dout_valid,
    output reg [31:0] a1_0,
    output reg [31:0] a1_1,
    output reg [31:0] a1_2,
    output reg [31:0] a1_3,
    output reg [31:0] a1_4,
    output reg [31:0] a1_5,
    output reg [31:0] a1_6,
    output reg [31:0] a1_7
);

//has_data 即前面已经足够的缓存数据，缓存填满了，对于DEC_L1级，只需要一个x的缓存即�?
reg has_data;

always @(posedge clk_78_125 or negedge rstn) begin
    if (!rstn) begin
        has_data<=0;
    end else 
        has_data<=din_valid;
end
reg [31:0] x_hist_temp[0:6];

always @(posedge clk_78_125 or negedge rstn) begin//has_data和x_hist同步
    if (!rstn) begin
            x_hist_temp[0] <= 0;
            x_hist_temp[1] <= 0;
            x_hist_temp[2] <= 0;
            x_hist_temp[3] <= 0;
            x_hist_temp[4] <= 0;
            x_hist_temp[5] <= 0;
            x_hist_temp[6] <= 0;
        end else if (din_valid) begin
            x_hist_temp[0] <= din_15;
            x_hist_temp[1] <= din_14;
            x_hist_temp[2] <= din_13;
            x_hist_temp[3] <= din_12;
            x_hist_temp[4] <= din_11;
            x_hist_temp[5] <= din_10;
            x_hist_temp[6] <= din_9;
        end
end

//直到收到has_data=1，表明此时已经有�?个x的历史数据了，可以进行计算了.
//此时使用�?个更高频的时钟去采样(4�?)
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

wire valid_next=(cnt==3);//指示下一个即将有效，传�?�给mult_valid_in.

reg mult_valid_in;
reg [31:0]curr_din[0:15];
reg [31:0]x_hist[0:6];

always @(posedge clk_312_5) begin//在当前周期（78.125mhz）的0~3.2ns对齐当前的数�?
    mult_valid_in<=(valid_next&(has_data));//cnt=3且has_data=1时，mult_valid_in=1，表示当前的curr_din和x_hist已经准备好了，可以进行乘法计算了。
    curr_din[0]<=din_0;         x_hist[0]<=x_hist_temp[0];//为了对齐x_hist和curr_din.
    curr_din[1]<=din_1;         x_hist[1]<=x_hist_temp[1];//为了对齐x_hist和curr_din.
    curr_din[2]<=din_2;         x_hist[2]<=x_hist_temp[2];//为了对齐x_hist和curr_din.
    curr_din[3]<=din_3;         x_hist[3]<=x_hist_temp[3];//为了对齐x_hist和curr_din.
    curr_din[4]<=din_4;         x_hist[4]<=x_hist_temp[4];//为了对齐x_hist和curr_din.
    curr_din[5]<=din_5;         x_hist[5]<=x_hist_temp[5];//为了对齐x_hist和curr_din.
    curr_din[6]<=din_6;         x_hist[6]<=x_hist_temp[6];//为了对齐x_hist和curr_din.
    curr_din[7]<=din_7;         
    curr_din[8]<=din_8;         
    curr_din[9]<=din_9;         
    curr_din[10]<=din_10;           
    curr_din[11]<=din_11;           
    curr_din[12]<=din_12;           
    curr_din[13]<=din_13;           
    curr_din[14]<=din_14;           
    curr_din[15]<=din_15;           
end

//调用fp32的模�?

wire [31:0] product [0:7][0:7];

fp32_mult fp32_mult_0_0 (clk_312_5,rstn,curr_din[0],    DEC_H0,mult_valid_in,product[0][0],mult_valid_out);
fp32_mult fp32_mult_0_1 (clk_312_5,rstn,x_hist[0],      DEC_H1,mult_valid_in,product[0][1],              );
fp32_mult fp32_mult_0_2 (clk_312_5,rstn,x_hist[1],      DEC_H2,mult_valid_in,product[0][2],              );
fp32_mult fp32_mult_0_3 (clk_312_5,rstn,x_hist[2],      DEC_H3,mult_valid_in,product[0][3],              );
fp32_mult fp32_mult_0_4 (clk_312_5,rstn,x_hist[3],      DEC_H4,mult_valid_in,product[0][4],              );
fp32_mult fp32_mult_0_5 (clk_312_5,rstn,x_hist[4],      DEC_H5,mult_valid_in,product[0][5],              );
fp32_mult fp32_mult_0_6 (clk_312_5,rstn,x_hist[5],      DEC_H6,mult_valid_in,product[0][6],              );
fp32_mult fp32_mult_0_7 (clk_312_5,rstn,x_hist[6],      DEC_H7,mult_valid_in,product[0][7],              );

fp32_mult fp32_mult_1_0 (clk_312_5,rstn,curr_din[2],    DEC_H0,mult_valid_in,product[1][0],              );                       
fp32_mult fp32_mult_1_1 (clk_312_5,rstn,curr_din[1],    DEC_H1,mult_valid_in,product[1][1],              );                            
fp32_mult fp32_mult_1_2 (clk_312_5,rstn,curr_din[0],    DEC_H2,mult_valid_in,product[1][2],              );                          
fp32_mult fp32_mult_1_3 (clk_312_5,rstn,x_hist[0],      DEC_H3,mult_valid_in,product[1][3],              );                        
fp32_mult fp32_mult_1_4 (clk_312_5,rstn,x_hist[1],      DEC_H4,mult_valid_in,product[1][4],              );                               
fp32_mult fp32_mult_1_5 (clk_312_5,rstn,x_hist[2],      DEC_H5,mult_valid_in,product[1][5],              );                          
fp32_mult fp32_mult_1_6 (clk_312_5,rstn,x_hist[3],      DEC_H6,mult_valid_in,product[1][6],              );                             
fp32_mult fp32_mult_1_7 (clk_312_5,rstn,x_hist[4],      DEC_H7,mult_valid_in,product[1][7],              );

fp32_mult fp32_mult_2_0 (clk_312_5,rstn,curr_din[4],    DEC_H0,mult_valid_in,product[2][0],              );
fp32_mult fp32_mult_2_1 (clk_312_5,rstn,curr_din[3],    DEC_H1,mult_valid_in,product[2][1],              );
fp32_mult fp32_mult_2_2 (clk_312_5,rstn,curr_din[2],    DEC_H2,mult_valid_in,product[2][2],              );
fp32_mult fp32_mult_2_3 (clk_312_5,rstn,curr_din[1],    DEC_H3,mult_valid_in,product[2][3],              );
fp32_mult fp32_mult_2_4 (clk_312_5,rstn,curr_din[0],    DEC_H4,mult_valid_in,product[2][4],              );
fp32_mult fp32_mult_2_5 (clk_312_5,rstn,x_hist[0],      DEC_H5,mult_valid_in,product[2][5],              );
fp32_mult fp32_mult_2_6 (clk_312_5,rstn,x_hist[1],      DEC_H6,mult_valid_in,product[2][6],              );
fp32_mult fp32_mult_2_7 (clk_312_5,rstn,x_hist[2],      DEC_H7,mult_valid_in,product[2][7],              );

fp32_mult fp32_mult_3_0 (clk_312_5,rstn,curr_din[6],    DEC_H0,mult_valid_in,product[3][0],              );                                                                                                        
fp32_mult fp32_mult_3_1 (clk_312_5,rstn,curr_din[5],    DEC_H1,mult_valid_in,product[3][1],              );                                                                                                        
fp32_mult fp32_mult_3_2 (clk_312_5,rstn,curr_din[4],    DEC_H2,mult_valid_in,product[3][2],              );                                                                                                        
fp32_mult fp32_mult_3_3 (clk_312_5,rstn,curr_din[3],    DEC_H3,mult_valid_in,product[3][3],              );                                                                                                        
fp32_mult fp32_mult_3_4 (clk_312_5,rstn,curr_din[2],    DEC_H4,mult_valid_in,product[3][4],              );                                                                                                        
fp32_mult fp32_mult_3_5 (clk_312_5,rstn,curr_din[1],    DEC_H5,mult_valid_in,product[3][5],              );                                                                                                        
fp32_mult fp32_mult_3_6 (clk_312_5,rstn,curr_din[0],    DEC_H6,mult_valid_in,product[3][6],              );                                                                                                        
fp32_mult fp32_mult_3_7 (clk_312_5,rstn,x_hist[0],      DEC_H7,mult_valid_in,product[3][7],              );

fp32_mult fp32_mult_4_0 (clk_312_5,rstn,curr_din[8],    DEC_H0,mult_valid_in,product[4][0],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_4_1 (clk_312_5,rstn,curr_din[7],    DEC_H1,mult_valid_in,product[4][1],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_4_2 (clk_312_5,rstn,curr_din[6],    DEC_H2,mult_valid_in,product[4][2],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_4_3 (clk_312_5,rstn,curr_din[5],    DEC_H3,mult_valid_in,product[4][3],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_4_4 (clk_312_5,rstn,curr_din[4],    DEC_H4,mult_valid_in,product[4][4],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_4_5 (clk_312_5,rstn,curr_din[3],    DEC_H5,mult_valid_in,product[4][5],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_4_6 (clk_312_5,rstn,curr_din[2],    DEC_H6,mult_valid_in,product[4][6],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_4_7 (clk_312_5,rstn,curr_din[1],    DEC_H7,mult_valid_in,product[4][7],              );   

fp32_mult fp32_mult_5_0 (clk_312_5,rstn,curr_din[10],   DEC_H0,mult_valid_in,product[5][0],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_5_1 (clk_312_5,rstn,curr_din[9],    DEC_H1,mult_valid_in,product[5][1],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_5_2 (clk_312_5,rstn,curr_din[8],    DEC_H2,mult_valid_in,product[5][2],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_5_3 (clk_312_5,rstn,curr_din[7],    DEC_H3,mult_valid_in,product[5][3],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_5_4 (clk_312_5,rstn,curr_din[6],    DEC_H4,mult_valid_in,product[5][4],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_5_5 (clk_312_5,rstn,curr_din[5],    DEC_H5,mult_valid_in,product[5][5],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_5_6 (clk_312_5,rstn,curr_din[4],    DEC_H6,mult_valid_in,product[5][6],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_5_7 (clk_312_5,rstn,curr_din[3],    DEC_H7,mult_valid_in,product[5][7],              );                                                                                                                                                                                                                 

fp32_mult fp32_mult_6_0 (clk_312_5,rstn,curr_din[12],   DEC_H0,mult_valid_in,product[6][0],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_6_1 (clk_312_5,rstn,curr_din[11],   DEC_H1,mult_valid_in,product[6][1],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_6_2 (clk_312_5,rstn,curr_din[10],   DEC_H2,mult_valid_in,product[6][2],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_6_3 (clk_312_5,rstn,curr_din[9],    DEC_H3,mult_valid_in,product[6][3],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_6_4 (clk_312_5,rstn,curr_din[8],    DEC_H4,mult_valid_in,product[6][4],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_6_5 (clk_312_5,rstn,curr_din[7],    DEC_H5,mult_valid_in,product[6][5],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_6_6 (clk_312_5,rstn,curr_din[6],    DEC_H6,mult_valid_in,product[6][6],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_6_7 (clk_312_5,rstn,curr_din[5],    DEC_H7,mult_valid_in,product[6][7],              );       

fp32_mult fp32_mult_7_0 (clk_312_5,rstn,curr_din[14],   DEC_H0,mult_valid_in,product[7][0],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_7_1 (clk_312_5,rstn,curr_din[13],   DEC_H1,mult_valid_in,product[7][1],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_7_2 (clk_312_5,rstn,curr_din[12],   DEC_H2,mult_valid_in,product[7][2],              );                                                                                                                                                                                                                 
fp32_mult fp32_mult_7_3 (clk_312_5,rstn,curr_din[11],   DEC_H3,mult_valid_in,product[7][3],              );                                                                                                       
fp32_mult fp32_mult_7_4 (clk_312_5,rstn,curr_din[10],   DEC_H4,mult_valid_in,product[7][4],              );                                                                                                       
fp32_mult fp32_mult_7_5 (clk_312_5,rstn,curr_din[9],    DEC_H5,mult_valid_in,product[7][5],              );                                                                                                       
fp32_mult fp32_mult_7_6 (clk_312_5,rstn,curr_din[8],    DEC_H6,mult_valid_in,product[7][6],              );                                                                                                       
fp32_mult fp32_mult_7_7 (clk_312_5,rstn,curr_din[7],    DEC_H7,mult_valid_in,product[7][7],              );  

`ifdef DEBUG_DECOMPOSE_L1
    integer file_mult;
    initial begin
        file_mult=$fopen("E:/project/pulse-processing/verilog_wavelet/fp32_prj/project_1/wavelet_sym4_dec_res_verilog_fp32/sim/tb_decompose_L1.v/mult_out.txt","w");
        if(!file_mult) begin
            $display("Error: Failed to open file for writing.");
            $finish;
        end
    end

    always@(posedge clk_312_5) begin
      if(rstn&mult_valid_out)
        begin
            for(integer i=0;i<8;i=i+1) begin
            for(integer j=0;j<8;j=j+1) begin
                $fwrite(file_mult,"%h ",product[i][j]);
            end
             end
             $fwrite(file_mult,"\n");
        end
    end

`endif 
//打一拍,数据和控制信号同步打拍
reg mult_valid_out_d1;
reg [31:0]product_d1[0:7][0:7];
integer i,j;

always @(posedge clk_312_5) begin
    mult_valid_out_d1<=mult_valid_out;
    for(i=0;i<8;i=i+1) begin
        for(j=0;j<8;j=j+1) begin
            product_d1[i][j]<=product[i][j];
        end
    end
end

wire add_valid_in_0=mult_valid_out_d1;
wire  add_valid_out_0;

//加法 三级加法
//adder_0 product[0-1][2-3][4-5][6-7][0:7]
wire [31:0] sum0[0:7][0:3];

fp32_adder_sub fp32_adder_sub_0_0_0(clk_312_5,rstn,product_d1[0][0],product_d1[0][1],1'b0,add_valid_in_0,sum0[0][0],add_valid_out_0);
fp32_adder_sub fp32_adder_sub_0_1_0(clk_312_5,rstn,product_d1[1][0],product_d1[1][1],1'b0,add_valid_in_0,sum0[1][0],               );
fp32_adder_sub fp32_adder_sub_0_2_0(clk_312_5,rstn,product_d1[2][0],product_d1[2][1],1'b0,add_valid_in_0,sum0[2][0],               );
fp32_adder_sub fp32_adder_sub_0_3_0(clk_312_5,rstn,product_d1[3][0],product_d1[3][1],1'b0,add_valid_in_0,sum0[3][0],               );
fp32_adder_sub fp32_adder_sub_0_4_0(clk_312_5,rstn,product_d1[4][0],product_d1[4][1],1'b0,add_valid_in_0,sum0[4][0],               );
fp32_adder_sub fp32_adder_sub_0_5_0(clk_312_5,rstn,product_d1[5][0],product_d1[5][1],1'b0,add_valid_in_0,sum0[5][0],               );
fp32_adder_sub fp32_adder_sub_0_6_0(clk_312_5,rstn,product_d1[6][0],product_d1[6][1],1'b0,add_valid_in_0,sum0[6][0],               );
fp32_adder_sub fp32_adder_sub_0_7_0(clk_312_5,rstn,product_d1[7][0],product_d1[7][1],1'b0,add_valid_in_0,sum0[7][0],               );

fp32_adder_sub fp32_adder_sub_0_0_1(clk_312_5,rstn,product_d1[0][2],product_d1[0][3],1'b0,add_valid_in_0,sum0[0][1],               );
fp32_adder_sub fp32_adder_sub_0_1_1(clk_312_5,rstn,product_d1[1][2],product_d1[1][3],1'b0,add_valid_in_0,sum0[1][1],               );
fp32_adder_sub fp32_adder_sub_0_2_1(clk_312_5,rstn,product_d1[2][2],product_d1[2][3],1'b0,add_valid_in_0,sum0[2][1],               );
fp32_adder_sub fp32_adder_sub_0_3_1(clk_312_5,rstn,product_d1[3][2],product_d1[3][3],1'b0,add_valid_in_0,sum0[3][1],               );
fp32_adder_sub fp32_adder_sub_0_4_1(clk_312_5,rstn,product_d1[4][2],product_d1[4][3],1'b0,add_valid_in_0,sum0[4][1],               );
fp32_adder_sub fp32_adder_sub_0_5_1(clk_312_5,rstn,product_d1[5][2],product_d1[5][3],1'b0,add_valid_in_0,sum0[5][1],               );
fp32_adder_sub fp32_adder_sub_0_6_1(clk_312_5,rstn,product_d1[6][2],product_d1[6][3],1'b0,add_valid_in_0,sum0[6][1],               );
fp32_adder_sub fp32_adder_sub_0_7_1(clk_312_5,rstn,product_d1[7][2],product_d1[7][3],1'b0,add_valid_in_0,sum0[7][1],               );

fp32_adder_sub fp32_adder_sub_0_0_2(clk_312_5,rstn,product_d1[0][4],product_d1[0][5],1'b0,add_valid_in_0,sum0[0][2],               );
fp32_adder_sub fp32_adder_sub_0_1_2(clk_312_5,rstn,product_d1[1][4],product_d1[1][5],1'b0,add_valid_in_0,sum0[1][2],               );
fp32_adder_sub fp32_adder_sub_0_2_2(clk_312_5,rstn,product_d1[2][4],product_d1[2][5],1'b0,add_valid_in_0,sum0[2][2],               );
fp32_adder_sub fp32_adder_sub_0_3_2(clk_312_5,rstn,product_d1[3][4],product_d1[3][5],1'b0,add_valid_in_0,sum0[3][2],               );
fp32_adder_sub fp32_adder_sub_0_4_2(clk_312_5,rstn,product_d1[4][4],product_d1[4][5],1'b0,add_valid_in_0,sum0[4][2],               );
fp32_adder_sub fp32_adder_sub_0_5_2(clk_312_5,rstn,product_d1[5][4],product_d1[5][5],1'b0,add_valid_in_0,sum0[5][2],               );
fp32_adder_sub fp32_adder_sub_0_6_2(clk_312_5,rstn,product_d1[6][4],product_d1[6][5],1'b0,add_valid_in_0,sum0[6][2],               );
fp32_adder_sub fp32_adder_sub_0_7_2(clk_312_5,rstn,product_d1[7][4],product_d1[7][5],1'b0,add_valid_in_0,sum0[7][2],               );

fp32_adder_sub fp32_adder_sub_0_0_3(clk_312_5,rstn,product_d1[0][6],product_d1[0][7],1'b0,add_valid_in_0,sum0[0][3],               );
fp32_adder_sub fp32_adder_sub_0_1_3(clk_312_5,rstn,product_d1[1][6],product_d1[1][7],1'b0,add_valid_in_0,sum0[1][3],               );
fp32_adder_sub fp32_adder_sub_0_2_3(clk_312_5,rstn,product_d1[2][6],product_d1[2][7],1'b0,add_valid_in_0,sum0[2][3],               );
fp32_adder_sub fp32_adder_sub_0_3_3(clk_312_5,rstn,product_d1[3][6],product_d1[3][7],1'b0,add_valid_in_0,sum0[3][3],               );
fp32_adder_sub fp32_adder_sub_0_4_3(clk_312_5,rstn,product_d1[4][6],product_d1[4][7],1'b0,add_valid_in_0,sum0[4][3],               );
fp32_adder_sub fp32_adder_sub_0_5_3(clk_312_5,rstn,product_d1[5][6],product_d1[5][7],1'b0,add_valid_in_0,sum0[5][3],               );
fp32_adder_sub fp32_adder_sub_0_6_3(clk_312_5,rstn,product_d1[6][6],product_d1[6][7],1'b0,add_valid_in_0,sum0[6][3],               );
fp32_adder_sub fp32_adder_sub_0_7_3(clk_312_5,rstn,product_d1[7][6],product_d1[7][7],1'b0,add_valid_in_0,sum0[7][3],               );

reg add_valid_out_0_d1;
reg [31:0]sum0_d1[0:7][0:3];

always @(posedge clk_312_5) begin
    add_valid_out_0_d1<=add_valid_out_0;
    for(i=0;i<8;i=i+1) begin
        for(j=0;j<4;j=j+1) begin
            sum0_d1[i][j]<=sum0[i][j];
        end
    end
end
//add1
wire add_valid_in_1=add_valid_out_0_d1;
wire add_valid_out_1;

wire [31:0] sum1[0:7][0:1];//0-1是只有两个结�?

fp32_adder_sub fp32_adder_sub_1_0_0(clk_312_5,rstn,sum0_d1[0][0],sum0_d1[0][1],1'b0,add_valid_in_1,sum1[0][0],add_valid_out_1);
fp32_adder_sub fp32_adder_sub_1_1_0(clk_312_5,rstn,sum0_d1[1][0],sum0_d1[1][1],1'b0,add_valid_in_1,sum1[1][0],               );
fp32_adder_sub fp32_adder_sub_1_2_0(clk_312_5,rstn,sum0_d1[2][0],sum0_d1[2][1],1'b0,add_valid_in_1,sum1[2][0],               );
fp32_adder_sub fp32_adder_sub_1_3_0(clk_312_5,rstn,sum0_d1[3][0],sum0_d1[3][1],1'b0,add_valid_in_1,sum1[3][0],               );
fp32_adder_sub fp32_adder_sub_1_4_0(clk_312_5,rstn,sum0_d1[4][0],sum0_d1[4][1],1'b0,add_valid_in_1,sum1[4][0],               );
fp32_adder_sub fp32_adder_sub_1_5_0(clk_312_5,rstn,sum0_d1[5][0],sum0_d1[5][1],1'b0,add_valid_in_1,sum1[5][0],               );
fp32_adder_sub fp32_adder_sub_1_6_0(clk_312_5,rstn,sum0_d1[6][0],sum0_d1[6][1],1'b0,add_valid_in_1,sum1[6][0],               );
fp32_adder_sub fp32_adder_sub_1_7_0(clk_312_5,rstn,sum0_d1[7][0],sum0_d1[7][1],1'b0,add_valid_in_1,sum1[7][0],               );

fp32_adder_sub fp32_adder_sub_1_0_1(clk_312_5,rstn,sum0_d1[0][2],sum0_d1[0][3],1'b0,add_valid_in_1,sum1[0][1],               );
fp32_adder_sub fp32_adder_sub_1_1_1(clk_312_5,rstn,sum0_d1[1][2],sum0_d1[1][3],1'b0,add_valid_in_1,sum1[1][1],               );
fp32_adder_sub fp32_adder_sub_1_2_1(clk_312_5,rstn,sum0_d1[2][2],sum0_d1[2][3],1'b0,add_valid_in_1,sum1[2][1],               );
fp32_adder_sub fp32_adder_sub_1_3_1(clk_312_5,rstn,sum0_d1[3][2],sum0_d1[3][3],1'b0,add_valid_in_1,sum1[3][1],               );
fp32_adder_sub fp32_adder_sub_1_4_1(clk_312_5,rstn,sum0_d1[4][2],sum0_d1[4][3],1'b0,add_valid_in_1,sum1[4][1],               );
fp32_adder_sub fp32_adder_sub_1_5_1(clk_312_5,rstn,sum0_d1[5][2],sum0_d1[5][3],1'b0,add_valid_in_1,sum1[5][1],               );
fp32_adder_sub fp32_adder_sub_1_6_1(clk_312_5,rstn,sum0_d1[6][2],sum0_d1[6][3],1'b0,add_valid_in_1,sum1[6][1],               );
fp32_adder_sub fp32_adder_sub_1_7_1(clk_312_5,rstn,sum0_d1[7][2],sum0_d1[7][3],1'b0,add_valid_in_1,sum1[7][1],               );

reg add_valid_out_1_d1;
reg [31:0]sum1_d1[0:7][0:1];

always @(posedge clk_312_5) begin
    add_valid_out_1_d1<=add_valid_out_1;
    for(i=0;i<8;i=i+1) begin
        for(j=0;j<2;j=j+1) begin
            sum1_d1[i][j]<=sum1[i][j];
        end
    end
end

//add2
wire add_valid_in_2=add_valid_out_1_d1;
wire add_valid_out_2;


wire [31:0] sum2[0:7][0:0];//0是只有两个结�?

fp32_adder_sub fp32_adder_sub_2_0_0(clk_312_5,rstn,sum1_d1[0][0],sum1_d1[0][1],1'b0,add_valid_in_2,sum2[0][0],add_valid_out_2);
fp32_adder_sub fp32_adder_sub_2_1_0(clk_312_5,rstn,sum1_d1[1][0],sum1_d1[1][1],1'b0,add_valid_in_2,sum2[1][0],               );
fp32_adder_sub fp32_adder_sub_2_2_0(clk_312_5,rstn,sum1_d1[2][0],sum1_d1[2][1],1'b0,add_valid_in_2,sum2[2][0],               );
fp32_adder_sub fp32_adder_sub_2_3_0(clk_312_5,rstn,sum1_d1[3][0],sum1_d1[3][1],1'b0,add_valid_in_2,sum2[3][0],               );
fp32_adder_sub fp32_adder_sub_2_4_0(clk_312_5,rstn,sum1_d1[4][0],sum1_d1[4][1],1'b0,add_valid_in_2,sum2[4][0],               );
fp32_adder_sub fp32_adder_sub_2_5_0(clk_312_5,rstn,sum1_d1[5][0],sum1_d1[5][1],1'b0,add_valid_in_2,sum2[5][0],               );
fp32_adder_sub fp32_adder_sub_2_6_0(clk_312_5,rstn,sum1_d1[6][0],sum1_d1[6][1],1'b0,add_valid_in_2,sum2[6][0],               );
fp32_adder_sub fp32_adder_sub_2_7_0(clk_312_5,rstn,sum1_d1[7][0],sum1_d1[7][1],1'b0,add_valid_in_2,sum2[7][0],               );

always@(posedge clk_312_5)
begin
  dout_valid<=add_valid_out_2;
  a1_0<=sum2[0][0];
  a1_1<=sum2[1][0];
  a1_2<=sum2[2][0];  
  a1_3<=sum2[3][0];
  a1_4<=sum2[4][0];
  a1_5<=sum2[5][0];
  a1_6<=sum2[6][0];  
  a1_7<=sum2[7][0];  
end    
endmodule
