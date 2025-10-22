# -*- coding: utf-8 -*-
# 位置：carbon_emission_finance/carbon_emission_finance/code/bayes/simple_parallel.py

import os
from pathlib import Path
import numpy as np
import pandas as pd
from cmdstanpy import CmdStanModel

# ── 1) 路径 & 数据 ─────────────────────────────────────────────────────────────
BAYES_DIR   = Path(__file__).resolve().parent                      # .../code/bayes
PROJECT_DIR = BAYES_DIR.parent.parent                              # .../carbon_emission_finance
DATA_DIR    = PROJECT_DIR / "data"

# 你真正要用的数据文件（按需替换）
DATA_FILE = DATA_DIR / "data_bayes.csv"
if not DATA_FILE.exists():
    raise FileNotFoundError(f"未找到数据文件：{DATA_FILE}")

STAN_FILE = BAYES_DIR / "bayes_eventstudy_rw_parallel.stan"
if not STAN_FILE.exists():
    raise FileNotFoundError(f"未找到 Stan 文件：{STAN_FILE}")

df = pd.read_csv(DATA_FILE)

# ── 2) 构造因变量 y、索引、设计矩阵 ─────────────────────────────────────────────
# 必要列
need = ["province_id", "year", "event_time"]
miss = [c for c in need if c not in df.columns]
if miss:
    raise KeyError(f"数据缺少列：{miss}")

# 因变量：优先 ln_so2；否则由 industrial_so2 构造
if "ln_so2" not in df.columns:
    if "industrial_so2" not in df.columns:
        raise KeyError("既无 ln_so2 也无 industrial_so2，无法构造因变量")
    df["ln_so2"] = np.log(np.asarray(df["industrial_so2"], float).clip(min=1e-9))

# 清理关键列的 NaN/Inf
key_cols = ["province_id", "year", "event_time", "ln_so2"]
mask_bad = ~np.isfinite(df[key_cols].to_numpy(float)).all(axis=1)
if mask_bad.any():
    df = df.loc[~mask_bad].copy()

# 1-based 索引
df["prov_idx"] = df["province_id"].astype("category").cat.codes + 1
df["year_idx"] = df["year"].astype("category").cat.codes + 1

# y 标准化
mu, sd = df["ln_so2"].mean(), df["ln_so2"].std(ddof=0)
if not np.isfinite(sd) or sd <= 0:
    raise ValueError(f"ln_so2 标准差异常：{sd}")
df["y_z"] = (df["ln_so2"] - mu) / sd

# 事件时间虚拟变量（去掉基期 -1）
k_list = [-3, -2, 0, 1, 2, 3]
D = pd.concat([(df["event_time"] == k).astype(int).rename(f"k{k}") for k in k_list], axis=1)

# 控制变量（如果没有，就给空矩阵）
ctrl_cols = [c for c in [
    "ln_gdp", "sec_pctg", "coal_share_pctg", "population",
    "urbanization_rate", "env_exp_share", "green_finance_pilot", "market_index"
] if c in df.columns]
X = df[ctrl_cols].copy() if ctrl_cols else pd.DataFrame(index=df.index)
X = X.fillna(0.0)

# ── 3) 打包 Stan data ──────────────────────────────────────────────────────────
N = len(df)
prov = df["prov_idx"].to_numpy(np.int32)
year = df["year_idx"].to_numpy(np.int32)
y = df["y_z"].to_numpy(np.float64)
D_np = D.to_numpy(np.float64)
X_np = X.to_numpy(np.float64) if X.shape[1] > 0 else np.empty((N, 0), dtype=np.float64)

I, T = int(prov.max()), int(year.max())
K, P = D_np.shape[1], X_np.shape[1]

stan_data = {
    "N": N, "I": I, "T": T,
    "K": K, "P": P,
    "prov": prov, "year": year,
    "D": D_np, "X": X_np, "y": y,
    "grainsize": 128,          # ← reduce_sum 的粒度；64/128/256 试甜点
}

# 喂给 Stan 之前的“全量有限性检查”
def ensure_finite(name, arr):
    if not np.isfinite(np.asarray(arr)).all():
        raise ValueError(f"{name} 含 NaN/Inf")
for name, arr in [("y", y), ("prov", prov), ("year", year), ("D", D_np), ("X", X_np)]:
    ensure_finite(name, arr)

# ── 4) 编译（开启线程）& 采样 ─────────────────────────────────────────────────
# 让链内线程数真正生效（也可以写在 ~/.bashrc）
os.environ.setdefault("STAN_NUM_THREADS", "3")

model = CmdStanModel(
    stan_file=str(STAN_FILE),
    cpp_options={"STAN_THREADS": True}
)
model.compile(force=True)  # 避免误用仓库里旧二进制

fit = model.sample(
    data=stan_data,
    seed=42,
    chains=4,
    parallel_chains=4,
    threads_per_chain=3,       # ← 结合 STAN_NUM_THREADS 使用
    iter_warmup=2000,
    iter_sampling=2000,
    adapt_delta=0.98,
    max_treedepth=15,
    show_console=True
)

# ── 5) 输出 ────────────────────────────────────────────────────────────────────
out_dir = PROJECT_DIR / "output"
out_dir.mkdir(parents=True, exist_ok=True)
fit.save_csvfiles(out_dir.as_posix())

print("✅ sampling ok")
print(fit.summary(vars=["beta", "sigma", "tau_rw", "tau_prov"]))