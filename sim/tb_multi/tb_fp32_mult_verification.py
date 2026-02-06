#!/usr/bin/env python3
import struct
import os
import math

def ieee754_bin_to_float(bin_str):
    """将32位二进制字符串转换为Python float"""
    bin_str = bin_str.strip()
    if len(bin_str) < 32: return 0.0
    ieee754_int = int(bin_str, 2)
    return struct.unpack('!f', struct.pack('!I', ieee754_int))[0]

def ieee754_hex_to_float(hex_str):
    """将32位十六进制字符串转换为Python float"""
    try:
        hex_clean = hex_str.strip().replace('0x', '')
        ieee754_int = int(hex_clean, 16)
        return struct.unpack('!f', struct.pack('!I', ieee754_int))[0]
    except Exception as e:
        return float('nan')

def float_to_ieee754_hex(f):
    """将float转换为8位十六进制字符串，处理溢出和特殊值"""
    if math.isnan(f): 
        return "7fc00000"
    try:
        # 使用单精度打包以模拟硬件溢出
        return format(struct.unpack('!I', struct.pack('!f', f))[0], '08x')
    except OverflowError:
        return "7f800000" if f > 0 else "ff800000"

def compare_results(py_val, hw_hex):
    """验证逻辑：优先二进制匹配，其次容差匹配"""
    hw_hex_clean = hw_hex.lower().strip().replace('0x', '').zfill(8)
    hw_val = ieee754_hex_to_float(hw_hex_clean)
    
    # 1. 优先二进制完全匹配 (处理 Inf, NaN, 以及硬件舍入一致的情况)
    py_hex = float_to_ieee754_hex(py_val)
    if py_hex == hw_hex_clean:
        return True, "Exact binary match"

    # 2. 处理特殊值不匹配的情况
    if math.isnan(py_val) or math.isnan(hw_val):
        if math.isnan(py_val) and math.isnan(hw_val): return True, "Both NaN"
        return False, "NaN mismatch"
    
    if math.isinf(py_val) or math.isinf(hw_val):
        if math.isinf(py_val) and math.isinf(hw_val):
            return (py_val > 0) == (hw_val > 0), "Inf sign mismatch"
        return False, "Inf mismatch"

    # 3. 数值误差匹配 (由于硬件可能采用了不同的舍入策略，如 Round to Zero vs Nearest)
    abs_diff = abs(py_val - hw_val)
    if py_val != 0:
        rel_error = abs_diff / abs(py_val)
        if rel_error < 1e-6: # FP32 允许约 1ppm 的相对误差
            return True, f"Match (RelErr: {rel_error:.2e})"
    elif abs_diff < 1e-9:
        return True, "Zero match"

    return False, f"Mismatch: Py={py_val:.7e} ({py_hex}), HW={hw_val:.7e} ({hw_hex_clean})"

def main():
    # --- 路径配置 ---
    script_dir = os.path.dirname(os.path.abspath(__file__))
    input_file = os.path.join(script_dir, 'tb_fp32_data_input.txt')
    output_file = os.path.join(script_dir, 'tb_fp32_mult_result_output.txt')
    report_file = os.path.join(script_dir, 'tb_fp32_mult_verification_report.txt')

    if not os.path.exists(input_file) or not os.path.exists(output_file):
        print(f"[ERROR] 找不到文件！\n输入: {input_file}\n输出: {output_file}")
        return

    # 1. 读取输入 (两行为一组)
    with open(input_file, 'r') as f:
        raw_lines = [line.strip() for line in f if len(line.strip()) >= 32]
    
    input_pairs = []
    for i in range(0, len(raw_lines) - 1, 2):
        input_pairs.append((raw_lines[i], raw_lines[i+1]))

    # 2. 读取硬件结果
    with open(output_file, 'r') as f:
        hw_results = [line.strip() for line in f if line.strip() and not line.startswith('//')]

    print(f"[INFO] 待处理输入对数: {len(input_pairs)}")
    print(f"[INFO] 硬件输出行数: {len(hw_results)}")

    # 3. 开始对比
    passed_count = 0
    total_tests = min(len(input_pairs), len(hw_results))
    
    with open(report_file, 'w') as report:
        report.write("FP32 Multiplier Verification Report\n")
        report.write("="*60 + "\n")
        report.write(f"Total test cases: {total_tests}\n\n")

        for i in range(total_tests):
            bin_a, bin_b = input_pairs[i]
            hw_hex = hw_results[i]
            
            # Python 参考计算
            val_a = ieee754_bin_to_float(bin_a)
            val_b = ieee754_bin_to_float(bin_b)
            py_res = val_a * val_b
            
            is_ok, msg = compare_results(py_res, hw_hex)
            
            if is_ok:
                passed_count += 1
                res_tag = "[PASS]"
            else:
                res_tag = "[FAIL]"

            report.write(f"{res_tag} Case {i+1:05d}: {msg}\n")
            if not is_ok:
                report.write(f"      A: {bin_a} ({val_a:.7e})\n")
                report.write(f"      B: {bin_b} ({val_b:.7e})\n")
                report.write(f"      Expected Hex: {float_to_ieee754_hex(py_res)}\n")
                report.write(f"      Hardware Hex: {hw_hex}\n")

    # 4. 结果统计
    if total_tests > 0:
        pass_rate = (passed_count / total_tests) * 100
        print(f"\n[SUMMARY]")
        print(f"Tests Run:    {total_tests}")
        print(f"Passed:       {passed_count}")
        print(f"Failed:       {total_tests - passed_count}")
        print(f"Pass Rate:    {pass_rate:.2f}%")
        print(f"Detailed report saved to: {report_file}")
    else:
        print("[WARNING] No data was processed. Check your input/output files.")

if __name__ == "__main__":
    main()