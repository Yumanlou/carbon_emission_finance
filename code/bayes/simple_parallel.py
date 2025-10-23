# -*- coding: utf-8 -*-
import os
from pathlib import Path
import numpy as np
import pandas as pd
from cmdstanpy import CmdStanModel

# ── 路径 ──────────────────────────────────────────────────────────────────────
BAYES_DIR   = Path(__file__).resolve().parent
PROJECT_DIR = BAYES_DIR.parent.parent
DATA_DIR    = PROJECT_DIR / "data"
OUT_DIR     = PROJECT_DIR / "output"
OUT_DIR.mkdir(parents=True, exist_ok=True)

STAN_FILE = BAYES_DIR / "bayes_eventstudy_rw_parallel.stan"
DATA_FILE = DATA_DIR / "data_bayes.csv"
assert STAN_FILE.exists(), f"Stan 文件不存在：{STAN_FILE}"
assert DATA_FILE.exists(), f"数据不存在：{DATA_FILE}"

# ── 读数与清洗（一次性） ─────────────────────────────────────────────────────
df = pd.read_csv(DATA_FILE)

need = ["province_id", "year", "event_time"]
miss = [c for c in need if c not in df.columns]
if miss:
    raise KeyError(f"缺少必要列：{miss}")

if "ln_so2" not in df.columns:
    if "industrial_so2" not in df.columns:
        raise KeyError("既无 ln_so2 也无 industrial_so2")
    df["ln_so2"] = np.log(np.asarray(df["industrial_so2"], float).clip(min=1e-9))

# 关键列统一清洗（NaN / Inf）
key_cols = need + ["ln_so2"]
mask = np.isfinite(df[key_cols].to_numpy(float)).all(axis=1)
df = df.loc[mask].copy()

# ── 索引与 y（基于清洗后的 df） ───────────────────────────────────────────────
df["prov_idx"] = df["province_id"].astype("category").cat.codes + 1
df["year_idx"] = df["year"].astype("category").cat.codes + 1

mu, sd = df["ln_so2"].mean(), df["ln_so2"].std(ddof=0)
if not np.isfinite(sd) or sd <= 0:
    raise ValueError(f"ln_so2 标准差异常：{sd}")
df["y_z"] = (df["ln_so2"] - mu) / sd

# ── 设计矩阵（与 df 行完全对齐） ─────────────────────────────────────────────
k_list = [-3, -2, 0, 1, 2, 3]   # 事件时间窗口（去掉 -1 作为基期）
D = pd.concat([(df["event_time"] == k).astype(int).rename(f"k{k}") for k in k_list], axis=1)

ctrl_cols = [c for c in [
    "ln_gdp","sec_pctg","coal_share_pctg","population",
    "urbanization_rate","env_exp_share","green_finance_pilot","market_index"
] if c in df.columns]
X = (df[ctrl_cols].copy() if ctrl_cols else pd.DataFrame(index=df.index)).fillna(0.0)

# ── 在清洗和生成 y_z、prov_idx、year_idx、D、X 之后 ─────────────────────────
# 关键：用 df 的最终长度 N 去裁剪所有矩阵，保证行数一致

# 重置索引，确保连续（防止老索引残留）
df = df.reset_index(drop=True)

# 确保 D、X 和 df 完全对齐
if D.shape[0] != len(df):
    D = D.iloc[:len(df), :].copy()
if X.shape[0] != len(df):
    X = X.iloc[:len(df), :].copy()

# 重新计算 N，并直接从 df 取所有字段
N = len(df)
prov = df["prov_idx"].to_numpy(np.int32)
year = df["year_idx"].to_numpy(np.int32)
y = df["y_z"].to_numpy(np.float64)

D_np = D.to_numpy(np.float64)
X_np = X.to_numpy(np.float64) if X.shape[1] > 0 else np.empty((N, 0), dtype=np.float64)

# 省份和年份的维度
I, T = int(prov.max()), int(year.max())
K, P = D_np.shape[1], X_np.shape[1]

print(f"✅ 数据长度已统一: N={N}, D={D_np.shape}, X={X_np.shape}, y={len(y)}")

# —— 一致性自检（防 91/90 越界）——
print(">> sanity check before Stan")
print("N =", N, "| D:", D_np.shape, "| X:", X_np.shape,
      "| y:", len(y), "| prov:", len(prov), "| year:", len(year))
assert D_np.shape[0] == N and X_np.shape[0] == N, "D/X 行数必须等于 N"
assert len(y) == N and len(prov) == N and len(year) == N, "y/prov/year 长度必须等于 N"
assert prov.min() >= 1 and prov.max() <= I, "prov 索引越界"
assert year.min() >= 1 and year.max() <= T, "year 索引越界"

print("\n========== DEBUG ARRAY LENGTHS ==========")
print("N =", N)
print("len(y):", len(y))
print("len(prov):", len(prov))
print("len(year):", len(year))
print("D.shape:", D_np.shape)
print("X.shape:", X_np.shape)
print("prov range:", prov.min(), "-", prov.max())
print("year range:", year.min(), "-", year.max())
print("I =", I, "T =", T)
print("========================================\n")


stan_data = {
    "N": N, "I": I, "T": T, "K": K, "P": P,
    "prov": prov, "year": year,
    "D": D_np, "X": X_np, "y": y,
    "grainsize": 128,
}

# ── 编译（启用线程） ──────────────────────────────────────────────────────────
os.environ.setdefault("STAN_NUM_THREADS", "3")  # 每链 3 线程（与 threads_per_chain 对齐）

# 删除旧机器编译的可执行，避免误用
exe_path = BAYES_DIR / "bayes_eventstudy_rw_parallel"
if exe_path.exists():
    exe_path.unlink()

model = CmdStanModel(
    stan_file=str(STAN_FILE),
    cpp_options={"STAN_THREADS": True}
)
model.compile(force=True)

# ── 采样 ─────────────────────────────────────────────────────────────────────
fit = model.sample(
    data=stan_data,
    seed=42,
    chains=4,
    parallel_chains=4,
    threads_per_chain=3,
    iter_warmup=2000,
    iter_sampling=2000,
    adapt_delta=0.98,
    max_treedepth=15,
    show_console=True
)

# ── 输出 ─────────────────────────────────────────────────────────────────────
fit.save_csvfiles(OUT_DIR.as_posix())
print("✅ sampling ok. CSV saved to:", OUT_DIR)
print(fit.summary(vars=["beta", "sigma", "tau_rw", "tau_prov"]))