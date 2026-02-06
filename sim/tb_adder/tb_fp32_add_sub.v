`timescale 1ns/1ps

`ifndef VIVADO_SIM
    `include "../../scr/fp32_add_sub.v"
`endif 

module tb_fp32_add_sub ();

    //Params
    parameter CLK_PERIOD = 10; // 10ns = 100MHz

    // 信号定义
    reg clk;
    reg rstn;
    
    // DUT 输入
    reg [31:0] dina;
    reg [31:0] dinb;
    reg op;          // 0: Add, 1: Sub
    reg valid_in;
    
    // DUT 输出
    wire [31:0] result;
    wire valid_out;
    
    // 文件句柄与变量
    integer fp_in, fp_out;
    integer scan_status_a, scan_status_b;
    reg [31:0] data_a, data_b;
    
    // 循环控制变量 (替代 break)
    integer loop_active;
    
    // 实例化被测模块 (Device Under Test)
    fp32_adder_sub dut (
        .clk(clk),
        .rstn(rstn),
        .dina(dina),
        .dinb(dinb),
        .op(op),
        .valid_in(valid_in),
        .result(result),
        .valid_out(valid_out)
    );
    
    // 1. 时钟生成
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // 2. 波形转储
    `ifndef VIVADO_SIM
        initial begin
            $dumpfile("waveform/tb_fp32_add_sub.vcd");
            $dumpvars(0, tb_fp32_add_sub);
        end
    `endif

    // 3. 主测试逻辑
    initial begin
        // --- 初始化信号 ---
        rstn = 1'b0;
        dina = 32'h0;
        dinb = 32'h0;
        op   = 1'b0;
        valid_in = 1'b0;
        loop_active = 1; // 初始化循环标志
        
        // --- 打开文件 ---
        fp_in  = $fopen("tb_fp32_data_input.txt", "r");
        fp_out = $fopen("tb_fp32_add_sub_result_output.txt", "w");

        if (fp_in == 0) begin
            $display("Error: Could not open input file!");
            $finish;
        end

        // --- 复位序列 ---
        #100;
        rstn = 1'b1;
        #20;

        // --- 循环读取文件 (修改点：移除 break) ---
        // 只要 loop_active 为 1 且文件没结束，就继续
        while (loop_active && !$feof(fp_in)) begin
            
            // 读取第一个数
            scan_status_a = $fscanf(fp_in, "%b", data_a);
            
            // 检查是否读取成功 (如果失败，设置标志位退出)
            if (scan_status_a != 1) begin
                loop_active = 0;
            end else begin
                // 读取第二个数
                scan_status_b = $fscanf(fp_in, "%b", data_b);
                
                if (scan_status_b != 1) begin
                    $display("Error: Data mismatch, missing pair for data_b");
                    loop_active = 0;
                end else begin
                    // 只有读数成功才执行测试
                    
                    // =========== 执行加法 (OP = 0) ===========
                    drive_input(data_a, data_b, 1'b0); 
                    wait_and_save_result();            

                    // =========== 执行减法 (OP = 1) ===========
                    drive_input(data_a, data_b, 1'b1); 
                    wait_and_save_result();            
                end
            end
        end

        // --- 结束仿真 ---
        $display("Testbench completed successfully.");
        $fclose(fp_in);
        $fclose(fp_out);
        #100;
        $finish;
    end

    // ============================================================
    // 任务：驱动输入信号
    // ============================================================
    task drive_input;
        input [31:0] a;
        input [31:0] b;
        input opcode;
        begin
            @(posedge clk);     
            dina <= a;
            dinb <= b;
            op   <= opcode;
            valid_in <= 1'b1;   
            
            @(posedge clk);
            valid_in <= 1'b0;   
        end
    endtask

    // ============================================================
    // 任务：等待 valid_out 并保存结果
    // ============================================================
    task wait_and_save_result;
        begin
            wait (valid_out == 1'b1);
            @(posedge clk); 
            
            $fwrite(fp_out, "%h\n", result);
            
            while (valid_out == 1'b1) @(posedge clk);
        end
    endtask

endmodule