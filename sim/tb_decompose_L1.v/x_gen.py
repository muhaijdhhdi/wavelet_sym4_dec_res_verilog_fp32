import struct
import numpy as np
import os

def float_to_ieee754_binary(f):
    """将Python float转换为IEEE 754 32位二进制字符串"""
    packed = struct.pack('>f', f)  # Big-endian
    ieee754_int = struct.unpack('>I', packed)[0]
    return format(ieee754_int, '032b')

def x_gen(seed=11232, num_test_cycles=1000, amplitude=10000):
    total_samples = num_test_cycles * 16
    n = np.arange(total_samples)

    np.random.seed(seed)
    data = np.random.uniform(-2, 2, total_samples) + amplitude * np.sin(2 * np.pi * n / 128) + 1000
    input_data = data.astype(np.int16)

    # 建议使用相对路径，方便多设备同步
    base_dir = "E:/project/pulse-processing/verilog_wavelet/fp32_prj/project_1/wavelet_sym4_dec_res_verilog_fp32/sim/tb_decompose_L1.v"
    if not os.path.exists(base_dir):
        os.makedirs(base_dir)

    file_path = os.path.join(base_dir, "x_input_16bit.txt")
    file_path_1 = os.path.join(base_dir, "x_input_ieee754.txt")

      # 1. 写入 IEEE 754 文件 (每16个数据一行，逗号分隔)
    with open(file_path_1, "w") as f:
        for i in range(num_test_cycles):
            chunk = input_data[i*16 : (i+1)*16]
            # 将 16 个数据转换成二进制字符串列表
            ieee_list = [float_to_ieee754_binary(float(x)) for x in chunk]
            # 用逗号连接并换行
            f.write(",".join(ieee_list) + "\n")
    #注意，写到文件ieee754以int16的形式（补码写入）
    # 写到16bit时，以uint16的格式写入        
    input_data=input_data.astype(np.int16)
    # 2. 写入 16-bit Hex 文件
    with open(file_path, "w") as f:
        for i in range(num_test_cycles):
            chunk = input_data[i*16 : (i+1)*16]
            hex_str = ",".join([f"{x & 0xFFFF:04x}" for x in chunk])
            f.write(hex_str + "\n")


if __name__ == "__main__":
    x_gen()