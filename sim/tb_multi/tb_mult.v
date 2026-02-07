`timescale 1ns/1ps

`ifndef VIVADO_SIM
    // 假设你的源文件名为 fp32_mult.v
    `include "../../scr/fp32_mult.v"
   // `include "../../scr/float_mult_comb.v"
`endif 

module tb_fp32_mult ();

    // 参数定义
    parameter CLK_PERIOD = 10; // 10ns = 100MHz

    // 信号定义
    reg clk;
    reg rstn;
    
    // DUT 输入
    reg [31:0] dina;
    reg [31:0] dinb;
    reg valid_din;
    
    // DUT 输出
    wire [31:0] result;
    wire valid_out;
    
    // 文件句柄与变量
    integer fp_in, fp_out;
    integer scan_status_a, scan_status_b;
    reg [31:0] data_a, data_b;
    
    // 循环控制变量
    integer loop_active;
    
    // 实例化被测模块 (DUT)
    fp32_mult dut (
        .clk(clk),
        .rstn(rstn),
        .dina(dina),
        .dinb(dinb),
        .valid_din(valid_din),
        .result(result),
        .valid_out(valid_out)
    );
    // float_mult_comb dut(
    //     .clk(clk),
    //     .rst_n(rstn),
    //     .a(dina),
    //     .b(dinb),
    //     .valid_din(valid_din),
    //     .result(result),
    //     .valid_out(valid_out)
    // );
    
    // 1. 时钟生成
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // 2. 波形转储 (用于非 Vivado 环境，如 Icarus Verilog)
    `ifndef VIVADO_SIM
        initial begin
            $dumpfile("waveform/tb_fp32_mult.vcd");
            $dumpvars(0, tb_fp32_mult);
        end
    `endif

    // 3. 主测试逻辑
    initial begin
        // --- 初始化信号 ---
        rstn = 1'b0;
        dina = 32'h0;
        dinb = 32'h0;
        valid_din = 1'b0;
        loop_active = 1; 
        
        // --- 打开文件 ---
        // 输入：包含32位二进制字符串的文件
        // 输出：保存硬件计算出的十六进制结果
        fp_in  = $fopen("tb_fp32_data_input.txt", "r");
        fp_out = $fopen("tb_fp32_mult_result_output.txt", "w");

        if (fp_in == 0) begin
            $display("Error: Could not open input file 'tb_fp32_mult_data_input.txt'!");
            $finish;
        end

        // --- 复位序列 ---
        #100;
        rstn = 1'b1;
        #20;

        // --- 循环读取文件数据并进行测试 ---
        while (loop_active && !$feof(fp_in)) begin
            
            // 尝试读取操作数 A (二进制格式)
            scan_status_a = $fscanf(fp_in, "%b", data_a);
            
            if (scan_status_a != 1) begin
                loop_active = 0; // 读取结束或失败
            end else begin
                // 尝试读取操作数 B (二进制格式)
                scan_status_b = $fscanf(fp_in, "%b", data_b);
                
                if (scan_status_b != 1) begin
                    $display("Warning: Data mismatch, Input A has no matching Input B. Skipping...");
                    loop_active = 0;
                end else begin
                    // --- 调用任务：驱动输入 ---
                    // 这个任务会确保 valid_din 只拉高一个周期
                    drive_input(data_a, data_b); 

                    // --- 调用任务：等待并保存结果 ---
                    wait_and_save_result(); 
                end
            end
        end

        // --- 结束仿真 ---
        #100;
        $display("Simulation: All data processed. Cleaning up...");
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
        begin
            @(posedge clk);     // 等待时钟上升沿对齐
            dina <= a;
            dinb <= b;
            valid_din <= 1'b1;  // 拉高 valid
            
            @(posedge clk);
            valid_din <= 1'b0;  // 持续一个周期后立即拉低
            // 清除数据线（可选，方便观察波形）
            dina <= 32'h0;
            dinb <= 32'h0;
        end
    endtask

    // ============================================================
    // 任务：等待 valid_out 并保存结果
    // ============================================================
    task wait_and_save_result;
        begin
            // 阻塞等待硬件输出有效信号
            wait (valid_out == 1'b1);
            @(posedge clk); // 采样输出结果
            
            // 将结果以 8 位十六进制格式写入文件
            $fwrite(fp_out, "%h\n", result);
            // $display("Captured result: %h", result);
            
            // 等待 valid_out 变低，确保不会重复捕获同一数据
            // (适用于流水线间隔较大的情况)
            while (valid_out == 1'b1) @(posedge clk);
        end
    endtask

endmodule