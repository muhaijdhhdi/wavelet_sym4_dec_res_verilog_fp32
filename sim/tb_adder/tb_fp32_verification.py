import struct
import os
import math

def ieee754_bin_to_float(bin_str):
    """将32位二进制字符串转换为Python float"""
    if len(bin_str.strip()) < 32: return 0.0
    ieee754_int = int(bin_str.strip(), 2)
    return struct.unpack('!f', struct.pack('!I', ieee754_int))[0]

def ieee754_hex_to_float(hex_str):
    """将32位十六进制字符串转换为Python float (修复点)"""
    try:
        # 去掉可能存在的 0x 前缀
        hex_clean = hex_str.strip().replace('0x', '')
        ieee754_int = int(hex_clean, 16)
        # '!I' 表示大端序无符号整数，'!f' 表示大端序浮点数
        return struct.unpack('!f', struct.pack('!I', ieee754_int))[0]
    except Exception as e:
        print(f"Error parsing hex {hex_str}: {e}")
        return float('nan')

def float_to_ieee754_hex(f):
    """将float转换为8位十六进制字符串，处理溢出和特殊值"""
    if math.isnan(f): 
        return "7fc00000"
    
    try:
        # 尝试按照单精度打包
        return format(struct.unpack('!I', struct.pack('!f', f))[0], '08x')
    except OverflowError:
        # 如果 Python 的 float 太大，说明对应硬件中的 Infinity
        if f > 0:
            return "7f800000" # 正无穷
        else:
            return "ff800000" # 负无穷

def compare_results(py_val, hw_hex):
    """比较 Python 结果与硬件十六进制结果"""
    hw_hex_clean = hw_hex.lower().strip().replace('0x', '').zfill(8)
    hw_val = ieee754_hex_to_float(hw_hex_clean)
    
    # --- 新增：优先进行二进制匹配 ---
    # 如果十六进制完全一样，直接判定为通过，不管它是数值、Inf 还是 NaN
    py_hex = float_to_ieee754_hex(py_val)
    if py_hex == hw_hex_clean:
        return True, "Exact binary match (including special values)"

    # --- 以下是针对不完全一致的情况进行的深度分析 ---
    
    # 1. 处理 NaN
    if math.isnan(py_val) or math.isnan(hw_val):
        if math.isnan(py_val) and math.isnan(hw_val):
            return True, "Both NaN"
        return False, f"NaN mismatch: py={py_val}, hw={hw_val}"
    
    # 2. 处理 Inf
    if math.isinf(py_val) or math.isinf(hw_val):
        # 此时如果 py_hex 还没变成 inf 码，但 py_val 已经极大导致二进制转换成了 inf 码，
        # 这种情况已经在上面的二进制匹配中处理了。
        # 如果走到这里，说明一个是有限数而另一个是无穷大。
        if math.isinf(py_val) and math.isinf(hw_val):
            return (py_val > 0) == (hw_val > 0), "Inf sign mismatch"
        return False, "Inf mismatch"

    # 3. 容差范围内的匹配 (处理普通数值的微小舍入误差)
    abs_diff = abs(py_val - hw_val)
    if py_val != 0:
        rel_error = abs_diff / abs(py_val)
        if rel_error < 1e-6: 
            return True, f"Match (RelErr: {rel_error:.2e})"
    elif abs_diff < 1e-9:
        return True, "Zero match"

    return False, f"Value mismatch: Py={py_val:.7e}, HW={hw_val:.7e}"

def main():
    # 路径配置
    script_dir = os.path.dirname(os.path.abspath(__file__))
    input_file = os.path.join(script_dir, 'tb_fp32_data_input.txt')
    output_file = os.path.join(script_dir, 'tb_fp32_add_sub_result_output.txt')
    report_file = os.path.join(script_dir, 'tb_fp32_verification_report.txt')

    if not os.path.exists(input_file) or not os.path.exists(output_file):
        print(f"[ERROR] 找不到文件: \n输入: {input_file}\n输出: {output_file}")
        return

    # 1. 读取输入数据
    with open(input_file, 'r') as f:
        raw_inputs = [line.strip() for line in f if len(line.strip()) >= 32]
    
    input_pairs = []
    for i in range(0, len(raw_inputs)-1, 2):
        input_pairs.append((raw_inputs[i], raw_inputs[i+1]))

    # 2. 读取硬件仿真结果
    with open(output_file, 'r') as f:
        hw_results = [line.strip() for line in f if line.strip() and not line.startswith('//')]

    print(f"[INFO] 载入输入对: {len(input_pairs)}")
    print(f"[INFO] 载入硬件输出: {len(hw_results)}")

    # 3. 验证逻辑
    passed_count = 0
    total_tests = 0
    
    with open(report_file, 'w') as report:
        report.write("FP32 Add/Sub Verification Report\n" + "="*50 + "\n")

        for idx, (bin_a, bin_b) in enumerate(input_pairs):
            a_f = ieee754_bin_to_float(bin_a)
            b_f = ieee754_bin_to_float(bin_b)

            # Testbench 逻辑: 每个对依次输出 ADD 和 SUB 的结果
            for op_type in ["ADD", "SUB"]:
                hw_idx = idx * 2 + (0 if op_type == "ADD" else 1)
                
                if hw_idx >= len(hw_results): break
                
                total_tests += 1
                hw_hex = hw_results[hw_idx]
                py_val = (a_f + b_f) if op_type == "ADD" else (a_f - b_f)
                
                is_ok, msg = compare_results(py_val, hw_hex)
                if is_ok: passed_count += 1
                
                res_tag = "[PASS]" if is_ok else "[FAIL]"
                report.write(f"{res_tag} Test {total_tests:05d}: {op_type} | {msg}\n")
                
                if not is_ok:
                    report.write(f"      Input A: {bin_a} ({a_f:.7e})\n")
                    report.write(f"      Input B: {bin_b} ({b_f:.7e})\n")
                    report.write(f"      Expected: {float_to_ieee754_hex(py_val)}\n")
                    report.write(f"      Hardware: {hw_hex}\n")

    # 4. 打印统计
    if total_tests > 0:
        accuracy = (passed_count / total_tests) * 100
        print(f"\n[RESULT] 通过率: {passed_count}/{total_tests} ({accuracy:.2f}%)")
        print(f"[INFO] 详细报告见: {report_file}")
    else:
        print("[WARNING] 未进行任何有效测试，请检查输入输出文件内容。")

if __name__ == "__main__":
    main()