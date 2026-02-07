`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2026/02/07 17:30:17
// Design Name: 
// Module Name: float_mult_comb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module float_mult_comb(
    input wire clk,
    input wire rst_n,
    input wire [31:0] a,
    input wire [31:0] b,
    input wire valid_in,
    output reg [31:0] result,
    output reg valid_out
    );
    //----1.unpacking
    wire sign_a=a[31];
    wire [7:0] exp_a=a[30:23];
    wire [22:0]mant_a=a[22:0];
    
    wire sign_b=b[31];
    wire [7:0] exp_b=b[30:23];
    wire [22:0] mant_b=b[22:0];
    
    //----2,special case detection---
    wire a_is_zero=(exp_a==0)&&(mant_a==0);
    wire b_is_zero=(exp_b==0)&&(mant_b==0);
    wire a_is_inf=(exp_a==8'hff)&&(mant_a==0);
    wire b_is_inf=(exp_b==8'hff)&&(mant_b==0);
    wire a_is_nan=(exp_a==8'hff)&&(mant_a!=0);
    wire b_is_nan=(exp_b==8'hff)&&(mant_b!=0);
    
    // ---3.sign calculation--
    wire sign_res=sign_a^sign_b;
    
    //4.---exponent calculation--
    //bias is 127.result exp=ea+eb-127
    wire [9:0] exp_temp={2'b00,exp_a}+{2'b00,exp_b}-10'd127;
    
    //5.---mantissa multiplicstion
    //implicit 1 unless input is 0 or denormal
    //we treat denormal(exp=0) as 0
    wire [23:0] ma_op=(exp_a==0)?24'd0:{1'b0,mant_a};
    wire [23:0] mb_op=(exp_b==0)?24'd0:{1'b0,mant_b};
    
    wire [47:0] prod_mant=ma_op*mb_op;
    //--6 normalization & rounding logic
    //1.x*1.x is[1,4),if the msb is 1(prof_mant[0]==1),then,it excced 2
    
    wire norm_shift=prod_mant[47];
    
    //24bits high+round bit+sticky
    //if normal_shift=1,then 24 bits higher is prod_mant[47:24].round bit is [23],sticky bits is |[22:0]
    //if normal_shift=0,then 24 bits higher is prod_mant[46:23],round bit is [22],sticky bits is |[21:0]
    
    wire [23:0] mant_norm_candidate =norm_shift? prod_mant[47:24]:prod_mant[46:23];
    wire round_bit=norm_shift? prod_mant[23]:prod_mant[22];
    wire sticky_bit=norm_shift? |prod_mant[22:0]:prod_mant[21:0];
    
    wire [9:0]exp_norm_candidate=norm_shift? (exp_temp+1):exp_temp;
    
    //rounding
    //icrease if (round&(sticky|lsb))
    wire round_up=round_bit&(sticky_bit|mant_norm_candidate[0]);
    
    wire [24:0] mant_rounded={1'b0,mant_norm_candidate}+round_up;
    //check if rounding cased overflow
    wire round_overflow=mant_rounded[24];
    //final mantissa
    wire [22:0] final_mant= round_overflow? mant_rounded[23:1]:mant_rounded[22:0];//Here we has delete the hidden 1;
    wire [9:0] final_exp=round_overflow? (exp_norm_candidate+1):exp_norm_candidate;
    
    //--7.exception & output logic
    
    //logic to detect result underflow /overflow
    //overflow:exp>255;
    //underflow:exp<=0;
    
    wire overflow=($signed(final_exp)>=255);
    wire underflow=($signed(final_exp)<=0);
    
    //construct result
    reg [31:0] next_result;
    
    always@(*)
        if(a_is_nan||b_is_nan) begin
            //nan return nan
                next_result={1'b0,8'hff,1'b1,22'd01};//nan exp=255 and mant is not zeros
            end
        else if(a_is_inf||b_is_inf) begin
                 if((a_is_inf&&b_is_zero)||(a_is_zero&&b_is_inf)) //0*inf=nan
                    next_result={1'b1,8'hff,1'b1,22'd01};//nan
                else
                //inf*x=inf(sign xor)
                     next_result={sign_res,8'hff,23'd0};
           end
          else if(overflow) 
            next_result={sign_res,8'hff,23'd0};
           else if(underflow)
                next_result={sign_res,8'd0,23'd0};
           else begin
                next_result={sign_res,final_exp[7:0],final_mant};
            end
        
        // --- 8. Output Register (Single Cycle Latency) ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            valid_out <= 0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                result <= next_result;
            end
        end
    end
        
        
    
endmodule
