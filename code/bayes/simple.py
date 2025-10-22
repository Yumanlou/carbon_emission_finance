# 文件位置：data/bayes/simple.py
import pandas as pd
import numpy as np
from pathlib import Path
from cmdstanpy import CmdStanModel

# ============== 0) 路径设置（基于你当前目录结构） =================
BAYES_DIR = Path(__file__).resolve().parent           # code/bayes
PROJECT_DIR = BAYES_DIR.parent.parent                 # carbon_emission_finance
DATA_DIR = PROJECT_DIR / "data"                       # carbon_emission_finance/data

# 你可以把候选文件替换成唯一的那个；这里先做“就近存在优先”
DATA_CANDIDATES = [
    #"final_data.csv",
    "data_bayes.csv",
    #"final_data.1.3.4_did-Desktop.csv",
    #"final_data.1.3.3.csv",
    #"final_data.1.3.2_did.csv",
    #"final_data.1.3.csv",
    #"final_master_dataset.csv",
    #"final_data_with_secondary_industry.csv",
]
data_file = None
for name in DATA_CANDIDATES:
    f = (DATA_DIR / name)
    if f.exists():
        data_file = f
        break
if data_file is None:
    raise FileNotFoundError(f"在 {DATA_DIR} 下未找到候选数据文件：{DATA_CANDIDATES}")

# Stan 文件：优先 bayes_eventstudy_rw.stan，其次 bayes_eventstudy_rw.stan
STAN_CANDIDATES = ["bayes_eventstudy_rw.stan", "bayes_eventstudy_rw.stan"]
stan_file = None
for s in STAN_CANDIDATES:
    f = (BAYES_DIR / s)
    if f.exists():
        stan_file = f
        break
if stan_file is None:
    raise FileNotFoundError(f"在 {BAYES_DIR} 下未找到 Stan 文件：{STAN_CANDIDATES}")

print(f"▶ 使用数据文件: {data_file.name}")
print(f"▶ 使用 Stan 文件: {stan_file.name}")

# ============== 1) 读数据 =================
df = pd.read_csv(data_file)

# 你当前列名中 province 用的是 province_id（已按你的注释改）
if "province_id" not in df.columns:
    raise KeyError("数据缺少列 'province_id'（你之前将 province 改成了 province_id）")
for col in ["year", "ln_so2"]:
    if col not in df.columns:
        raise KeyError(f"数据缺少列 '{col}'")

# ============== 2) 构造 1-based 连续索引（Stan 要求） =================
df["prov_idx"] = df["province_id"].astype("category").cat.codes + 1
df["year_idx"] = df["year"].astype("category").cat.codes + 1

# ============== 3) 因变量标准化（可选） =================
df["y_z"] = (df["ln_so2"] - df["ln_so2"].mean()) / df["ln_so2"].std()

# ============== 4) 事件时间设计矩阵 D（去掉基期 -1） =================
# 需要一列 event_time（若没有，你需要自建：event_time = year - treat_year）
if "event_time" not in df.columns:
    raise KeyError("数据缺少列 'event_time'，若没有请先构造：event_time = year - treat_year")

k_list = [-3, -2, 0, 1, 2, 3]  # 不含 -1（基期）
D = pd.concat([(df["event_time"] == k).astype(int).rename(f"k{k}") for k in k_list], axis=1)

# ============== 5) 控制变量矩阵 X =================
ctrl_cols = [
    "ln_gdp", "sec_pctg", "coal_share_pctg", "population",
    "urbanization_rate", "env_exp_share", "green_finance_pilot",
    "market_index",
]
missing = [c for c in ctrl_cols if c not in df.columns]
if missing:
    raise KeyError(f"控制变量缺失：{missing}\n请在 data/ 预处理或改用实际列名。")

X = df[ctrl_cols].copy().fillna(0.0)

# ============== 6) 转 numpy，并做一致性检查 =================
N = len(df)
prov = df["prov_idx"].astype(np.int32).values
year = df["year_idx"].astype(np.int32).values
y = df["y_z"].astype(np.float64).values
D_np = D.to_numpy(dtype=np.float64)
X_np = X.to_numpy(dtype=np.float64)

assert prov.min() == 1 and year.min() == 1, "prov_idx / year_idx 必须 1 开始"
assert N == D_np.shape[0] == X_np.shape[0] == y.shape[0], "行数不一致"
I, T = int(prov.max()), int(year.max())
K, P = D_np.shape[1], X_np.shape[1]

stan_data = {
    "N": N, "I": I, "T": T,
    "K": K, "P": P,
    "prov": prov, "year": year,
    "D": D_np, "X": X_np, "y": y,
}

# ============== 7) 编译 & 采样 =================
model = CmdStanModel(stan_file=str(stan_file))
fit = model.sample(
    data=stan_data,
    seed=42,
    chains=4,
    parallel_chains=4,
    iter_warmup=2000,
    iter_sampling=2000,
    adapt_delta=0.9,
)

print(fit.summary(["beta", "sigma"]))