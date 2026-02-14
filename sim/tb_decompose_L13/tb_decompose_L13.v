 `define VIVADO_SIM

`ifndef VIVADO_SIM
    `include"../../scr/decompose_L1.v"
    `include"../../scr/decompose_L2.v"
    `include"../../scr/decompose_L3.v"
`endif

`timescale 1ns/1ns

module tb_decompose_L13;
    reg clk_slow=1;reg clk_fast=1;reg rstn;
    reg [31:0] din[0:15];
    reg din_valid=0;
    wire dout_valid_L1_dec;
    wire dout_valid_L2_dec;
    wire dout_valid_L3_dec;
    wire [31:0] a1[7:0];
    wire [31:0] a2[3:0];
    wire [31:0] a3[1:0];
    wire dout_valid;

    parameter T_slow=40;
    parameter T_fast=10;

    parameter DEC_H0 = 32'hbd9b2b0e; // Float: -0.07576571
    parameter DEC_H1 = 32'hbcf2c635; // Float: -0.02963553
    parameter DEC_H2 = 32'h3efec7e0; // Float: 0.49761867
    parameter DEC_H3 = 32'h3f4dc1d3; // Float: 0.80373875
    parameter DEC_H4 = 32'h3e9880d1; // Float: 0.29785780
    parameter DEC_H5 = 32'hbdcb339e; // Float: -0.09921954
    parameter DEC_H6 = 32'hbc4e80df; // Float: -0.01260397
    parameter DEC_H7 = 32'h3d03fc5f; // Float: 0.03222310


    // Reconstruction Logic (Reference to DEC)
    parameter REC_H0 = DEC_H7;
    parameter REC_H1 = DEC_H6;
    parameter REC_H2 = DEC_H5;
    parameter REC_H3 = DEC_H4;
    parameter REC_H4 = DEC_H3;
    parameter REC_H5 = DEC_H2;
    parameter REC_H6 = DEC_H1;
    parameter REC_H7 = DEC_H0;

    always#(T_slow/2) clk_slow=~clk_slow;
    always#(T_fast/2) clk_fast=~clk_fast;

    decompose_L1 #(
        
        .DEC_H0( DEC_H0), 
        .DEC_H1( DEC_H1),
        .DEC_H2( DEC_H2),
        .DEC_H3( DEC_H3),
        .DEC_H4( DEC_H4),
        .DEC_H5( DEC_H5),
        .DEC_H6( DEC_H6),
        .DEC_H7( DEC_H7)
    ) u_dut_L1 (
        .clk_78_125(clk_slow),
        .clk_312_5(clk_fast),
        .rstn(rstn),
        .din_valid(din_valid),
       
        .din_0(din[0]),   .din_1(din[1]),   .din_2(din[2]),   .din_3(din[3]),
        .din_4(din[4]),   .din_5(din[5]),   .din_6(din[6]),   .din_7(din[7]),
        .din_8(din[8]),   .din_9(din[9]),   .din_10(din[10]), .din_11(din[11]),
        .din_12(din[12]), .din_13(din[13]), .din_14(din[14]), .din_15(din[15]),
        
        .dout_valid(dout_valid_L1_dec),
        .a1_0(a1[0]), .a1_1(a1[1]), .a1_2(a1[2]), .a1_3(a1[3]),
        .a1_4(a1[4]), .a1_5(a1[5]), .a1_6(a1[6]), .a1_7(a1[7])
    );

    decompose_L2 #(
        .DEC_H0( DEC_H0), 
        .DEC_H1( DEC_H1),
        .DEC_H2( DEC_H2),
        .DEC_H3( DEC_H3),
        .DEC_H4( DEC_H4),
        .DEC_H5( DEC_H5),
        .DEC_H6( DEC_H6),
        .DEC_H7( DEC_H7)
    ) u_dut_L2 (
        .clk_78_125(clk_slow),
        .clk_312_5(clk_fast),
        .rstn(rstn),
        .din_valid(dout_valid_L1_dec),
       
        .a1_0(a1[0]),   .a1_1(a1[1]),   .a1_2(a1[2]),   .a1_3(a1[3]),
        .a1_4(a1[4]),   .a1_5(a1[5]),   .a1_6(a1[6]),   .a1_7(a1[7]),

        .a2_0(a2[0]), .a2_1(a2[1]), .a2_2(a2[2]), .a2_3(a2[3]),
        .dout_valid(dout_valid_L2_dec)
    );

    decompose_L3 #(
        .DEC_H0( DEC_H0), 
        .DEC_H1( DEC_H1),
        .DEC_H2( DEC_H2),
        .DEC_H3( DEC_H3),
        .DEC_H4( DEC_H4),
        .DEC_H5( DEC_H5),
        .DEC_H6( DEC_H6),
        .DEC_H7( DEC_H7)
    ) u_dut_L3 (
        .clk_78_125(clk_slow),
        .clk_312_5(clk_fast),
        .rstn(rstn),
        .din_valid(dout_valid_L2_dec),
       
        .a2_0(a2[0]), .a2_1(a2[1]), .a2_2(a2[2]), .a2_3(a2[3]),
        .a3_0(a3[0]), .a3_1(a3[1]),
        .dout_valid(dout_valid_L3_dec)
    );

    integer i;
    integer scan_ret;
    integer file_handle;
    initial begin
        $display("Start simulation");
        //clk_slow=0;clk_fast=0;
        rstn=0;din_valid=0;
        for (i=0;i<16;i=i+1)  
            din[i]=0;

        file_handle=$fopen("E:/project/pulse-processing/verilog_wavelet/fp32_prj/project_1/wavelet_sym4_dec_res_verilog_fp32/sim/tb_decompose_L1.v/x_input_ieee754.txt","r");
        if (file_handle==0) begin
            $display("Failed to open file");
            $finish;
        end

        #(T_slow+1);
        rstn=1;
        #(T_slow*2-1);

        while(!$feof(file_handle)) begin
            @(posedge clk_slow);
            #0;
            scan_ret=$fscanf(file_handle,"%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b,%b\n",
            din[0],din[1],din[2],din[3],din[4],din[5],din[6],din[7],
            din[8],din[9],din[10],din[11],din[12],din[13],din[14],din[15]);

            if(scan_ret==16) begin
              din_valid=1;
            end

            else begin
              $display("Error:fscanf failed to read 16 value");
               din_valid=0;
               #(10*T_slow);
                $finish;
            end
            #1;
        end
        @(posedge clk_slow);
        din_valid=0;
        #(10*T_slow);
        $fclose(file_handle);
        $finish;
    end

    integer out_file_l1_dec;
    integer out_file_l2_dec;
    integer out_file_l3_dec;
    initial begin
        out_file_l1_dec=$fopen("E:/project/pulse-processing/verilog_wavelet/fp32_prj/project_1/wavelet_sym4_dec_res_verilog_fp32/sim/tb_decompose_L13/a1_out_ieee754.txt");
        out_file_l2_dec=$fopen("E:/project/pulse-processing/verilog_wavelet/fp32_prj/project_1/wavelet_sym4_dec_res_verilog_fp32/sim/tb_decompose_L13/a2_out_ieee754.txt");
        out_file_l3_dec=$fopen("E:/project/pulse-processing/verilog_wavelet/fp32_prj/project_1/wavelet_sym4_dec_res_verilog_fp32/sim/tb_decompose_L13/a3_out_ieee754.txt");

        if ((out_file_l1_dec==0)||(out_file_l2_dec==0)||(out_file_l3_dec==0) )begin
            $display("Failed to open output file.");
            $finish;
        end
    end

    // always@(posedge clk_slow)begin
    //   if(dout_valid_L1_dec) begin
    //     $fdisplay(out_file_l1_dec,"%b,%b,%b,%b,%b,%b,%b,%b",
    //     a1[0],a1[1],a1[2],a1[3],a1[4],a1[5],a1[6],a1[7]);
    //   end
    // end

    // always@(posedge clk_slow)begin
    //   if(dout_valid_L2_dec) begin
    //     $fdisplay(out_file_l2_dec,"%b,%b,%b,%b",
    //     a2[0],a2[1],a2[2],a2[3]);
    //   end
    // end

    always@(posedge clk_slow)begin
      if(dout_valid_L3_dec) begin
        $fdisplay(out_file_l3_dec,"%b,%b",
        a3[0],a3[1]);
      end
    end

assign dout_valid=dout_valid_L3_dec;

`ifndef VIVADO_SIM
    initial begin
        $dumpfile("waveform/tb_decompose_L13.vcd");
        $dumpvars(0, tb_decompose_L13); 
    end
`endif
endmodule