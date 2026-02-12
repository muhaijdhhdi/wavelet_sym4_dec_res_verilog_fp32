import struct
import random
import os

def float_to_bin32(f):
    """将 Python float 转换为 32 位二进制字符串"""
    # '!f' 表示大端序单精度浮点数
    return format(struct.unpack('!I', struct.pack('!f', f))[0], '032b')

def generate_fp32_data(num_pairs, filename='E:/project/pulse-processing/verilog_wavelet/fp32_prj/project_1/wavelet_sym4_dec_res_verilog_fp32/sim/tb_multi/tb_fp32_data_input.txt'):
    """
    产生指定对数的 FP32 数据
    每对数据占用两行，总行数为 2 * num_pairs
    """
    
    # 定义一些特殊的测试点，确保覆盖边界逻辑
    special_values = [
      2962.0,0.80374,
      2777.0,0.80374,
      -1007,0.29786,
      -246.0,-0.0126
    ]

    count = 0
    with open(filename, 'w') as f:
        # 1. 首先写入特殊值组合（覆盖边界）
        for i in range(len(special_values)):
            for j in range(i, len(special_values)):
                if count >= num_pairs: break
                f.write(float_to_bin32(special_values[i]) + '\n')
                f.write(float_to_bin32(special_values[j]) + '\n')
                count += 1

        # 2. 剩余部分产生随机数据
        while count < num_pairs:
            # 随机产生不同数量级的数
            # 这样可以同时测试对阶（加法）和指数累加（乘法）
            exp_a = random.uniform(-18, 18)
            exp_b = random.uniform(-18, 18)
            val_a = random.uniform(-1, 1) * (10**exp_a)
            val_b = random.uniform(-1, 1) * (10**exp_b)

            f.write(float_to_bin32(val_a) + '\n')
            f.write(float_to_bin32(val_b) + '\n')
            count += 1

    print(f"[SUCCESS] 已生成 {num_pairs} 对测试数据 (共 {count*2} 行)")
    print(f"[INFO] 文件路径: {os.path.abspath(filename)}")

if __name__ == "__main__":
    # 设置你想要产生的数据对数
    NUM_DATA_PAIRS = 1000 
    generate_fp32_data(NUM_DATA_PAIRS)