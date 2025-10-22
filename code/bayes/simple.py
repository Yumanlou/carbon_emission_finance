import pandas as pd
import numpy as np
from cmdstanpy import CmdStanModel

# 1) 读入你的面板数据（至少要有 province, year, y 以及若干控制变量）
df = pd.read_csv('./data/final_data.csv')   # 或 pd.read_stata(...) / pd.read_excel(...)

# 2) 构造 1-based 连续索引（Stan 要求）
df['prov_idx'] = df['province_id'].astype('category').cat.codes + 1 #province改成province_id,后续还需要对应处理
df['year_idx'] = df['year'].astype('category').cat.codes + 1

# 3) 因变量（可标准化，非必须）
df['y_z'] = (df['y'] - df['y'].mean()) / df['y'].std()

# 4) 事件时间设计矩阵 D（举例：相对事件期 k=-3..+3，去掉基期列 k=-1）
# 假设 df 里已有 event_time 列（你也可以自己算：year - treat_year）
k_list = [-3,-2,0,1,2,3]   # 注意：**不含 -1** 作为基期
D_cols = []
for k in k_list:
    col = (df['event_time'] == k).astype(int)
    D_cols.append(col.rename(f'k{k}'))
D = pd.concat(D_cols, axis=0 if False else 1)  # (N, K)

# 5) 控制变量矩阵 X（举例）
X = df[['ln_gdp','sec_pctg','coal_chare_pctg','population','urbanization_rate','env_exp_share','green_finance_pilot','market_index']].copy()  # 自己替换成你的列 10.22 添加了所有的控制变量
X = X.fillna(0.0)

# 6) 转 numpy，并做一致性检查
N = len(df)
prov = df['prov_idx'].astype(np.int32).values
year = df['year_idx'].astype(np.int32).values
y = df['y_z'].astype(np.float64).values
D_np = D.to_numpy(dtype=np.float64)
X_np = X.to_numpy(dtype=np.float64)

assert prov.min()==1 and year.min()==1
assert N == D_np.shape[0] == X_np.shape[0] == y.shape[0], "行数不一致"
I, T = int(prov.max()), int(year.max())
K, P = D_np.shape[1], X_np.shape[1]

stan_data = {
  'N': N, 'I': I, 'T': T,
  'K': K, 'P': P,
  'prov': prov, 'year': year,
  'D': D_np, 'X': X_np, 'y': y,
}

mod = CmdStanModel(stan_file='bayes_eventstudy_rw.stan')
fit = mod.sample(data=stan_data, seed=42, chains=4, parallel_chains=4,
                 iter_warmup=2000, iter_sampling=2000, adapt_delta=0.9)

print(fit.summary(['beta','sigma']))  # 参数名按你的 .stan 为准