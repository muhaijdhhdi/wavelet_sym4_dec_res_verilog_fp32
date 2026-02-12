#读取verilog的decompose_L1输出的FP32的数据格式，进行python的FP32解码，和python计算的结果进行对比验证
import struct
import numpy as np
import matplotlib.pyplot as plt

# ==========================================
# 1. 核心转换函数
# ==========================================

def str2num(hex_str):
    """
    将 16 位十六进制补码字符串 (如 'FFFF') 转换为数据(16位整数,-1)
    """
    try:
        # 去除可能的前缀或空白
        clean_hex = hex_str.strip().replace('0x', '')
        if not clean_hex: return 0.0
        
        # 1. 转为无符号整数 (0 - 65535)
        val_int = int(clean_hex, 16)
        
        # 2. 处理补码 (Two's Complement)
        # 如果最高位是 1 (即大于等于 0x8000/32768)，则是负数
        if val_int & 0x8000:
            val_int -= 0x10000
            
        return val_int
    except Exception as e:
        print(f"Error converting input hex {hex_str}: {e}")
        return 0.0

def bin32_ieee_to_float(bin_str):
    """
    将 32 位 IEEE 754 二进制字符串 (如 '00111111100000000000000000000000') 
    转换为浮点数 (1.0)
    """
    try:
        # 去除空格并确保长度为 32 位
        clean_bin = bin_str.strip().replace(' ', '')
        
        if not clean_bin:
            return 0.0
        
        # 1. 将二进制字符串转换为无符号整数
        # 2. '!I' 代表大端模式的 4 字节无符号整数
        # 3. '!f' 代表大端模式的单精度浮点数
        n = int(clean_bin, 2)
        return struct.unpack('!f', struct.pack('!I', n))[0]
        
    except (ValueError, struct.error, Exception):
        # 如果输入不是有效的二进制串或长度不对，返回 0.0 或抛出错误
        return 0.0

# ==========================================
# 2. 配置参数与路径
# ==========================================

# 滤波器系数 (直接使用你提供的值)
h_dec = np.array([
    -0.07576571478927333, -0.02963552764599851, 0.49761866763201545, 0.80373875180591614,
    0.29785779560527736, -0.09921954357684722, -0.012603967262037833, 0.032223100604042759
])

# 文件路径 (使用 raw string r'' 处理 Windows 路径)
base_path = r"E:/project/pulse-processing/verilog_wavelet/fp32_prj/project_1/wavelet_sym4_dec_res_verilog_fp32/sim/tb_decompose_L1.v"
file_input_16bit = base_path + r"/x_input_16bit.txt"
file_output_ieee = base_path + r"/x_output_ieee754.txt"

# ==========================================
# 3. 你的 Python 模型 (完全保持原样)
# ==========================================
def dec_L1(data, h):
    block_size = 16
    num_cycles = len(data) // block_size
    res = []
    
    # 初始化历史：取第0块的最后7个点
    x_hist = data[9:16] 
    
    # 从第1块开始计算
    for i in range(1, num_cycles):
        din = data[i*block_size : (i+1)*block_size]
        combined = np.concatenate((x_hist, din))
        for k in range(8):
            start_idx = k * 2
            window = combined[start_idx : start_idx + len(h)]
            y = np.sum(window[::-1] * h)
            res.append(y)
        x_hist = din[9:16]
    return np.array(res)

# ==========================================
# 4. 主处理流程
# ==========================================
if "__main__" == __name__:
    print("--- 开始处理 ---")

    # --- A. 读取输入文件 (16位补码) ---
    input_data_list = []
    try:
        with open(file_input_16bit, 'r') as f:
            # 读取整个文件，假设数据以空格、换行或逗号分隔
            content = f.read().replace(',', ' ').split()
            input_data_list = [str2num(x) for x in content]
        print(f"Input data loaded from {file_input_16bit}")
        print(f"Input sample count: {len(input_data_list)}")
        # print(f"First 5 inputs: {input_data_list[:5]}") # 调试用
    except FileNotFoundError:
        print(f"Error: 找不到输入文件 {file_input_16bit}")
        exit()

    # --- B. 运行 Python 模型 ---
    input_np = np.array(input_data_list)
    # 运行模型生成预期结果 (Golden Reference)
    a1_fp_python = dec_L1(input_np, h_dec)
    print(f"Python model executed. Output length: {len(a1_fp_python)}")

    # --- C. 读取 Verilog 输出文件 (32位 IEEE 754) ---
    verilog_data_list = []
    try:
        with open(file_output_ieee, 'r') as f:
            for line in f:
                # 你的 Verilog 输出是用逗号分隔的
                parts = line.strip().split(',')
                vals = [bin32_ieee_to_float(x) for x in parts if x.strip()]
                verilog_data_list.extend(vals)
        print(f"Verilog output loaded from {file_output_ieee}")
        print(f"Verilog output count: {len(verilog_data_list)}")
    except FileNotFoundError:
        print(f"Error: 找不到输出文件 {file_output_ieee}")
        exit()

    a1_fp_verilog = np.array(verilog_data_list)

    # ==========================================
    # 5. 对比与绘图
    # ==========================================

    # 对齐数据长度 (取交集长度)
    min_len = min(len(a1_fp_python), len(a1_fp_verilog))

    if min_len == 0:
        print("Error: 有一个数据源为空，无法对比。")
        exit()

    py_trunc = a1_fp_python[:min_len]
    vl_trunc = a1_fp_verilog[:min_len]

    # 计算误差
    diff = np.abs(py_trunc - vl_trunc)
    max_err = np.max(diff)
    mse_err = np.mean(diff**2)

    print("-" * 40)
    print("打印一些结果样本对比 (Python vs Verilog):")
    for i in range(min(100, min_len)):
        print(f"Sample {i}: Python={py_trunc[i]:.6f}, Verilog={vl_trunc[i]:.6f}, Abs Error={diff[i]:.6e},Add ={vl_trunc[i]+py_trunc[i]:.6f}")
    print("-" * 40)
    print(f"Validation Results:")
    print(f"Compared Samples: {min_len}")
    print(f"Max Absolute Error: {max_err:.8f}")
    print(f"Mean Squared Error: {mse_err:.10f}")
    print("-" * 40)

    # 判断结论
    if max_err < 1e-4:
        print("✅ SUCCESS: 结果匹配 (误差极小)")
    else:
        print("⚠️ WARNING: 存在较大误差，请检查时序对齐或舍入方式")

    # 绘图
    plt.figure(figsize=(14, 8))

    # 子图 1: 波形对比
    plt.subplot(2, 1, 1)
    plt.plot(vl_trunc, label='Verilog Output (FP32)', color='blue', linewidth=1.5, alpha=0.8)
    plt.plot(py_trunc, label='Python Model (Ref)', color='red', linestyle='--', linewidth=1.5, alpha=0.8)
    plt.title('Wavelet Decomposition Result: Verilog vs Python')
    plt.ylabel('Amplitude')
    plt.legend()
    plt.grid(True)

    # 子图 2: 误差曲线
    plt.subplot(2, 1, 2)
    plt.plot(diff, label='Absolute Error', color='green')
    plt.title('Error Analysis (Python - Verilog)')
    plt.xlabel('Sample Index')
    plt.ylabel('Abs Error')
    plt.legend()
    plt.grid(True)

    plt.tight_layout()
    plt.show()
