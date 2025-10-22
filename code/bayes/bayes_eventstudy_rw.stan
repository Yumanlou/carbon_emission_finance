// bayes_eventstudy_rw.stan
data {
  int<lower=1> N;                     // 观测数
  int<lower=1> I;                     // 省份数
  int<lower=1> T;                     // 年份数
  int<lower=0> K;                     // 事件时间列数（已去掉一个基期列）
  int<lower=0> P;                     // 控制变量个数

  array[N] int<lower=1, upper=I> prov;  // ✅ 新语法
  array[N] int<lower=1, upper=T> year;

  matrix[N, K] D;                     // 事件时间设计矩阵（不含基期列）
  matrix[N, P] X;                     // 控制变量矩阵
  vector[N] y;                        // 因变量（可已标准化）
}

// ---- parameters ----
parameters {
  vector[K] beta;
  vector[P] gamma;

  // 非中心化省份效应
  vector[I] z_prov;
  real<lower=1e-6> tau_prov;

  // RW1 的创新参数化
  real a_year1;
  vector[T-1] z_rw;             // 创新项 ~ N(0,1)
  real<lower=1e-6> tau_rw;

  real<lower=1e-6> sigma;       // 观测噪声
}

// ---- transformed parameters ----
transformed parameters {
  vector[I] a_prov = tau_prov * z_prov;

  vector[T] a_year;
  a_year[1] = a_year1;
  for (t in 2:T)
    a_year[t] = a_year[t-1] + tau_rw * z_rw[t-1];
}

// ---- model ----
model {
  // 先验
  beta ~ normal(0, 1);
  gamma ~ normal(0, 1);
  z_prov ~ normal(0, 1);
  a_year1 ~ normal(0, 5);
  z_rw ~ normal(0, 1);
  tau_prov ~ normal(0, 1) T[0, ];
  tau_rw   ~ normal(0, 1) T[0, ];
  sigma    ~ normal(0, 1) T[0, ];

  // 似然
  y ~ normal(D * beta + X * gamma + a_prov[prov] + a_year[year], sigma);
}
generated quantities {
  // 便于事后检查与作图的拟合值和残差
  vector[N] mu_hat;
  vector[N] resid;
  mu_hat = D * beta + X * gamma + a_prov[prov] + a_year[year];
  resid  = y - mu_hat;
}