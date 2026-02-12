import numpy as np
import struct
import os

# 定义系数 h (这是乘数 B)
h_dec = np.array([
    -0.07576571478927333, -0.02963552764599851, 0.49761866763201545, 0.80373875180591614,
    0.29785779560527736, -0.09921954357684722, -0.012603967262037833, 0.032223100604042759
])


#    ideal_data_input = np.array(read_data, dtype=np.int16)

def hex16_to_signed_int(hex_str):
    """将16位十六进制字符串转换为有符号整数 (补码)"""
    try:
        val = int(hex_str, 16)
        if val >32768: # 如果符号位为1
            return val - 65536
        return val
    except:
        return 0

def hex32_ieee_to_float(hex_str):
    """将32位IEEE 754十六进制字符串转换为浮点数"""
    try:
        clean_hex = hex_str.strip().replace('0x', '')
        if not clean_hex: return 0.0
        return struct.unpack('!f', bytes.fromhex(clean_hex))[0]
    except Exception as e:
        return 0.0

def float_to_ieee_hex(val):
    """【新增】将 Python 浮点数转换为 32位 IEEE 754 Hex 字符串"""
    try:
        # !f: 大端单精度浮点
        return struct.pack('!f', val).hex()
    except:
        return "00000000"
    
import struct

def float_to_ieee_bin(val):
    """
    将 Python 浮点数转换为 32位 IEEE 754 二进制字符串
    输入: 1.0
    输出: '00111111100000000000000000000000'
    """
    try:
        # 1. struct.pack('!f', val): 将浮点数打包成 4 字节的大端字节流 (IEEE 754 单精度)
        # 2. struct.unpack('!I', ...)[0]: 将这 4 个字节重新解释为无符号整数
        #    这样做是因为 Python 的 bin() 函数只能处理整数
        int_val = struct.unpack('!I', struct.pack('!f', val))[0]
        
        # 3. f"{int_val:032b}": 将整数格式化为 32 位宽度的二进制字符串，不足补 0
        return f"{int_val:032b}"
    except Exception as e:
        # 出错时返回全 0 或打印错误
        return "0" * 32

# ================= 测试代码 =================

def bin32_ieee_to_float(bin_str):
    """将32位IEEE 754二进制字符串转换为Python float"""
    try:
        clean_bin = bin_str.strip().replace(' ', '')
        if not clean_bin: return 0.0
        n = int(clean_bin, 2)
        return struct.unpack('!f', struct.pack('!I', n))[0]
    except:
        return 0.0

def mult_verify():
    # ================= 1. 文件路径配置 =================
    # 请根据你的实际路径修改
    input_file_path = r"E:/project/pulse-processing/verilog_wavelet/fp32_prj/project_1/wavelet_sym4_dec_res_verilog_fp32/sim/tb_decompose_L1.v/x_input_16bit.txt"
    verilog_out_path = r"E:/project/pulse-processing/verilog_wavelet/fp32_prj/project_1/wavelet_sym4_dec_res_verilog_fp32/sim/tb_decompose_L1.v/mult_out.txt"

    if not os.path.exists(input_file_path):
        print(f"错误: 找不到输入文件 {input_file_path}")
        return
    if not os.path.exists(verilog_out_path):
        print(f"错误: 找不到 Verilog 输出文件 {verilog_out_path}")
        return

    # ================= 2. 读取并解析输入数据 (x_input) =================
    print("正在读取输入数据...")
    raw_data_flat = []
    with open(input_file_path, 'r') as f:
        for line in f:
            parts = line.strip().split(",") 
            if not line.strip(): continue
            for p in parts:
                if p.strip():
                    # 这里先转回 int 再转 float，模拟 FPGA 中 signed 16bit -> float 32bit 的过程
                    raw_data_flat.append(float(hex16_to_signed_int(p.strip())))
    
    data = np.array(raw_data_flat)
   

    # ================= 3. Python 黄金模型计算 =================
    print("正在执行 Python 黄金模型计算...")
    block_size = 16
    num_cycles = len(data) // block_size
    
    expected_results = []   
    all_ops_data = []       # 存储乘数 A (输入数据)
    all_ops_h = []          # 存储乘数 B (系数 h)
    
    if num_cycles < 2:
        print("数据量不足")
        return

    x_hist = data[9:16] 
    
    for i in range(1, num_cycles):
        din = data[i*block_size : (i+1)*block_size]
        combined = np.concatenate((x_hist, din))
        
        block_res_64 = []
        block_ops_data_64 = [] 
        block_ops_h_64 = []    
        
        for k in range(8):
            start_idx = k * 2
            window = combined[start_idx : start_idx + len(h_dec)]
            
            # 翻转卷积
            current_data_window = window[::-1]
            
            # 乘法
            products = current_data_window * h_dec
            
            block_res_64.extend(products)
            block_ops_data_64.extend(current_data_window)
            block_ops_h_64.extend(h_dec)
            
        expected_results.append(block_res_64)
        all_ops_data.append(block_ops_data_64)
        all_ops_h.append(block_ops_h_64)
        
        x_hist = din[9:16]

    expected_array = np.array(expected_results) 
    ops_data_array = np.array(all_ops_data)     
    ops_h_array = np.array(all_ops_h)           

    # ================= 4. 读取 Verilog 输出并对比 =================
    print("正在读取 Verilog 输出并进行对比...")
    
    verilog_results = []
    with open(verilog_out_path, 'r') as f:
        for line in f:
            parts = line.strip().split()
            if len(parts) == 0: continue
            row_vals = [hex32_ieee_to_float(x) for x in parts]
            verilog_results.append(row_vals)
            
    verilog_array = np.array(verilog_results)

    # ================= 5. 误差分析 =================
    min_len = min(len(expected_array), len(verilog_array))
    
    print(f"\n对比行数: {min_len}")
    if min_len == 0:
        print("没有可对比的数据行。")
        return

    py_slice = expected_array[:min_len]
    v_slice = verilog_array[:min_len]
    ops_data_slice = ops_data_array[:min_len]
    ops_h_slice = ops_h_array[:min_len]
    
    abs_diff = np.abs(py_slice - v_slice)
    max_error = np.max(abs_diff)
    avg_error = np.mean(abs_diff)
    
    print("-" * 30)
    print(f"最大绝对误差 (Max Error): {max_error:.2e}")
    print(f"平均绝对误差 (Avg Error): {avg_error:.2e}")
    print("-" * 30)
    
    # 阈值
    threshold = 1e-4 
    
    if max_error < threshold:
        print("✅ 验证通过！结果高度一致。")
    else:
        print(f"❌ 验证存在差异 (阈值: {threshold})\n")
        
        # 打印表头，增加了 Hex 列
        header = (
            f"{'Pos(R,C)':<10} | "
            f"{'Op A (Hex)':<10} | {'Op A (Dec)':<12} | "
            f"{'Op B (Hex)':<10} | {'Op B (Dec)':<12} | "
            f"{'Exp (Dec)':<12} | {'Act (Dec)':<12} | {'Diff'}"
        )
        print(header)
        print("-" * len(header))
        
        error_indices = np.where(abs_diff > threshold)
        
        count = 0
        limit = 20
        
        for r, c in zip(error_indices[0], error_indices[1]):
            if count >= limit:
                print(f"... 剩余错误省略 ...")
                break
            
            # 获取数值
            val_op_a = ops_data_slice[r, c]
            val_op_b = ops_h_slice[r, c]
            val_py = py_slice[r, c]
            val_v = v_slice[r, c]
            val_diff = abs_diff[r, c]
            
            # 转为 Hex
            hex_op_a = float_to_ieee_hex(val_op_a)
            hex_op_b = float_to_ieee_hex(val_op_b)
            
            print(
                f"({r},{c:<3})   | "
                f"{hex_op_a:<10} | {val_op_a:<12.5f} | "
                f"{hex_op_b:<10} | {val_op_b:<12.5f} | "
                f"{val_py:<12.5f} | {val_v:<12.5f} | {val_diff:.2e}"
            )
            count += 1
            
        print("\n调试提示：")
        print("1. 'Op A (Hex)' 是数据输入的 IEEE754 形式，请在 ModelSim/Vivado 波形中搜索此值。")
        print("2. 'Op B (Hex)' 是系数 h 的 IEEE754 形式，请检查 ROM 或常量定义是否一致。")

if __name__ == "__main__":
    mult_verify()