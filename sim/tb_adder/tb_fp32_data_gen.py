"""
IEEE 754 单精度浮点数数据生成脚本
生成指定数量的随机浮点数，并包含特殊测试用例
输出为32位二进制形式，每行一个数据
"""

import struct
import random
import math

def float_to_ieee754_binary(f):
    """将Python float转换为IEEE 754 32位二进制字符串"""
    # 使用struct打包为32位浮点数，然后转换为32位无符号整数
    packed = struct.pack('>f', f)  # Big-endian
    ieee754_int = struct.unpack('>I', packed)[0]
    # 转换为32位二进制字符串
    return format(ieee754_int, '032b')

def generate_random_float():
    """
    生成一个随机的单精度浮点数
    覆盖不同的范围和精度
    """
    range_type = random.randint(0, 4)
    
    if range_type == 0:
        # 很小的数字（接近零，非规范化范围）
        return random.uniform(-1e-35, 1e-35)
    elif range_type == 1:
        # 正常的小范围数字
        return random.uniform(-100, 100)
    elif range_type == 2:
        # 中等范围数字
        return random.uniform(-1e6, 1e6)
    elif range_type == 3:
        # 很大的数字
        return random.uniform(-1e30, 1e30)
    else:
        # 非常大的数字（接近单精度限制）
        return random.uniform(-3e38, 3e38)

def generate_test_data(num_data, output_file, seed=42):
    """
    生成指定数量的测试数据
    
    参数:
        num_data: 生成的数据总数
        output_file: 输出文件路径
        seed: 随机种子，用于重现性测试
    """
    test_cases = []
    
    # 固定随机种子以保证可重复
    random.seed(seed)
    
    # 1. 特殊测试用例（固定）
    special_cases = [
        # 零
        0.0,
        -0.0,
        1.231323,
        -21322334,
        # 接近零（非规范化数）
        1e-38,
        -1e-38,
        1e-39,
        -1e-39,
        1e-20,
        -1.01e-20,
        float('nan'),
        float('inf'),

        float('inf'),
        12,

        # 1附近的数字
        1.0,
        -1.0,
        1.0 + 1e-6,
        1.0 - 1e-6,
        # 2的幂次
        2.0,
        -2.0,
        0.5,
        -0.5,
        4.0,
        -4.0,
        # 其他特殊值
        3.5,
        -3.5,
        10.0,
        -10.0,
        100.0,
        -100.0,
        1e6,
        -1e6,
        # 接近最大值
        3.4e38,
        -3.4e38,
        # 无穷大
        float('inf'),
        float('inf'),
    ]
    
    # 添加特殊用例
    test_cases.extend(special_cases)
    
    # 2. 填充随机数据到目标数量
    num_random = num_data - len(test_cases)
    
    if num_random > 0:
        print(f"生成 {len(special_cases)} 个特殊测试用例")
        print(f"生成 {num_random} 个随机测试数据")
        
        for _ in range(num_random):
            random_value = generate_random_float()
            test_cases.append(random_value)
    else:
        print(f"生成 {len(test_cases)} 个特殊测试用例（超出目标数量，只保留前 {num_data} 个）")
        test_cases = test_cases[:num_data]
    
    # 写入文件
    with open(output_file, 'w') as f:
        for value in test_cases:
            binary = float_to_ieee754_binary(value)
            f.write(binary + '\n')
    
    print(f"已生成 {len(test_cases)} 个测试数据，写入到 {output_file}")
    
    # 打印前20个数据以供验证
    print("\n前20个数据:")
    for i, value in enumerate(test_cases[:20]):
        binary = float_to_ieee754_binary(value)
        print(f"{i+1:3d}. {value:15.6e} -> {binary}")

if __name__ == '__main__':
    import os
    import sys
    
    # 获取脚本所在目录
    script_dir = os.path.dirname(os.path.abspath(__file__))
    output_file = os.path.join(script_dir, 'tb_fp32_data_input.txt')
    
    # 从命令行参数获取数据个数，默认为200
    if len(sys.argv) > 1:
        try:
            num_data = int(sys.argv[1])
        except ValueError:
            print(f"[ERROR] 输入参数必须为整数，收到: {sys.argv[1]}")
            sys.exit(1)
    else:
        num_data = 10000
    
    print(f"[INFO] 目标数据个数: {num_data}")
    generate_test_data(num_data, output_file)

