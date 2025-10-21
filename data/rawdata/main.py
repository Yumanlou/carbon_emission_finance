# -*- coding: utf-8 -*-
import pandas as pd
import re
import os

print("--- 开始处理面板数据 ---")

# --- 1. 定义文件名 ---
# 将您的文件名放在这里。代码会尝试直接使用这些名称。
# 如果找不到，它会智能地在文件夹中搜索包含关键字的文件。
file_paths = {
    'gf': '2000-2023年31省绿色金融（附原始数据）_副本.xlsx - 2000-2023年31省绿色金融原始数据.csv',
    'co2': '1970～2023年中国各省市CO2总排放量(v2024_GHG).xlsx - Sheet1.csv',
    'did': '2010-2023年中国地级市绿色金融试点DID数据.xls - Sheet1.csv'
}

# --- 2. 智能加载数据 ---
# 即使文件名与上面定义的略有不同，此函数也能找到正确的文件
def find_and_load_csv(key, default_path):
    """
    Tries to load a CSV from the default path. If not found, searches the
    current directory for a file containing a keyword from the path.
    """
    try:
        # 优先尝试直接加载
        print(f"正在加载 {key} 数据，路径: '{default_path}'")
        return pd.read_csv(default_path)
    except FileNotFoundError:
        print(f"警告: 文件 '{default_path}' 未找到。正在尝试智能搜索...")
        # 定义每个文件的核心关键字
        keywords = {
            'gf': '绿色金融原始数据',
            'co2': 'CO2总排放量',
            'did': '地级市绿色金融试点DID数据'
        }
        keyword = keywords.get(key)
        
        current_directory_files = os.listdir('.')
        for filename in current_directory_files:
            if keyword in filename and filename.endswith('.csv'):
                print(f"智能搜索成功: 找到匹配文件 '{filename}'")
                return pd.read_csv(filename)
        
        # 如果智能搜索也失败，则抛出错误
        raise FileNotFoundError(f"无法在当前目录中找到包含关键字 '{keyword}' 的CSV文件。请检查文件名是否正确。")


try:
    df_gf = find_and_load_csv('gf', file_paths['gf'])
    df_co2 = find_and_load_csv('co2', file_paths['co2'])
    df_did = find_and_load_csv('did', file_paths['did'])
    print("\n所有数据文件加载成功！")
except Exception as e:
    print(f"\n错误: {e}")
    print("程序已终止。请确保所有必需的CSV文件都与此脚本位于同一文件夹中。")
    exit()


# --- 3. 数据清洗与准备 ---
print("\n--- 步骤1: 清洗与标准化数据 ---")

def standardize_province(name):
    """标准化省份名称，去除后缀以便合并。"""
    if isinstance(name, str):
        # 去除常见的省、市、自治区等后缀
        return re.sub(r'省|市|自治区|维吾尔|壮族|回族', '', name)
    return name

# (A) 处理绿色金融数据
print("正在处理绿色金融数据...")
df_gf.rename(columns={'city': 'province', 'year': 'year'}, inplace=True)
df_gf['province'] = df_gf['province'].apply(standardize_province)

# (B) 处理碳排放数据
print("正在处理碳排放数据...")
df_co2.rename(columns={'省': 'province', '年份': 'year', 'CO2排放量_吨': 'co2_emissions'}, inplace=True)
df_co2['province'] = df_co2['province'].apply(standardize_province)
df_co2 = df_co2[['province', 'year', 'co2_emissions']]

# (C) 处理并聚合DID数据至省级
print("正在处理DID数据并聚合到省级...")
df_did.rename(columns={'所属省份': 'province', '年份': 'year', '绿色金融改革创新试验区': 'green_finance_pilot'}, inplace=True)
df_did['province'] = df_did['province'].apply(standardize_province)
# 将年份转换为整数，以防万一
df_did['year'] = df_did['year'].astype(int)

# 核心逻辑：按省份和年份分组，只要组内有一个试点(1)，该省份-年份就标记为试点
df_did_prov = df_did.groupby(['province', 'year'])['green_finance_pilot'].max().reset_index()

print("数据清洗与聚合完成。")


# --- 4. 合并数据表 ---
print("\n--- 步骤2: 合并数据表 ---")

# 首先，合并绿色金融和碳排放数据，只保留二者共有的省份-年份
merged_df = pd.merge(df_gf, df_co2, on=['province', 'year'], how='inner')
print(f"合并绿色金融与碳排放数据后，得到 {len(merged_df)} 条记录。")

# 然后，将合并后的主表与省级DID数据进行左合并
final_df = pd.merge(merged_df, df_did_prov, on=['province', 'year'], how='left')

# 对于没有匹配到DID数据的行（例如非试点省份或2010年前的数据），将其值填充为0
final_df['green_finance_pilot'] = final_df['green_finance_pilot'].fillna(0).astype(int)
print(f"合并DID数据后，总计 {len(final_df)} 条记录。")


# --- 5. 生成ID并整理 ---
print("\n--- 步骤3: 生成ID并最终整理 ---")

# 按省份和年份排序，这是面板数据的标准做法
final_df.sort_values(by=['province', 'year'], inplace=True)

# 创建一个从1开始的省份数字ID (用于 Stata 的 xtset 命令)
final_df['province_id'] = pd.factorize(final_df['province'])[0] + 1

# 为每一行创建一个唯一的UID
final_df.insert(0, 'uid', range(1, len(final_df) + 1))

# 调整列顺序，使其更清晰
# 选择您需要保留的绿色金融变量
green_finance_vars = [
    '绿色信贷', '绿色债券', '绿色投资', '绿色保险',
    '绿色权益', '绿色基金', '碳金融', '绿色金融指数'
]
# 确保所有期望的列都存在
existing_gf_vars = [col for col in green_finance_vars if col in final_df.columns]

cols_order = ['uid', 'province_id', 'province', 'year', 'co2_emissions'] + \
             existing_gf_vars + ['green_finance_pilot']
final_df = final_df[cols_order]
print("ID生成完毕，列顺序已调整。")

# --- 6. 保存结果 ---
output_filename = 'province_panel_data.csv'
final_df.to_csv(output_filename, index=False, encoding='utf-8-sig')

print("\n--- ✨ 处理完成！ ---")
print(f"最终的面板数据已保存为：{output_filename}")
print(f"数据总览：共 {len(final_df)} 行，覆盖 {final_df['province'].nunique()} 个省份。")
print("\n最终数据表的前5行预览：")
print(final_df.head())