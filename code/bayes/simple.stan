// bayes_eventstudy_rw.stan
data {
  int<lower=1> N;                     // 观测数
  int<lower=1> I;                     // 省份数
  int<lower=1> T;                     // 年份数
  int<lower=0> K;                     // 事件时间列数（已去掉一个基期列）
  int<lower=0> P;                     // 控制变量个数

  int<lower=1, upper=I> prov[N];      // 每条观测所属省份（1-based）
  int<lower=1, upper=T> year[N];      // 每条观测所属年份（1-based）

  matrix[N, K] D;                     // 事件时间设计矩阵（不含基期列）
  matrix[N, P] X;                     // 控制变量矩阵
  vector[N] y;                        // 因变量（可已标准化）
}

parameters {
  // 事件时间效应（相对基期）
  vector[K] beta;

  // 控制变量系数
  vector[P] gamma;

  // 省份随机效应 & 年份效应（年份用 RW1）
  vector[I] a_prov;
  vector[T] a_year;

  // 方差与层级尺度
  real<lower=0> sigma;                // 观测噪声
  real<lower=0> tau_prov;             // 省份效应尺度
  real<lower=0> tau_rw;               // 年份 RW1 创新项尺度
}

model {
  // --------- 先验（弱信息，稳健） ---------
  beta   ~ normal(0, 1);              // 事件时间效应
  gamma  ~ normal(0, 1);              // 控制变量

  a_prov ~ normal(0, tau_prov);       // 省份层级效应

  // 年份效应：一阶随机游走（RW1）
  a_year[1] ~ normal(0, 5);
  for (t in 2:T) {
    a_year[t] ~ normal(a_year[t-1], tau_rw);
  }

  // 尺度先验
  tau_prov ~ normal(0, 1) T[0, ];
  tau_rw   ~ normal(0, 1) T[0, ];
  sigma    ~ normal(0, 1) T[0, ];

  // --------- 似然 ---------
  y ~ normal(D * beta + X * gamma + a_prov[prov] + a_year[year], sigma);
}

generated quantities {
  // 便于事后检查与作图的拟合值和残差
  vector[N] mu_hat;
  vector[N] resid;
  mu_hat = D * beta + X * gamma + a_prov[prov] + a_year[year];
  resid  = y - mu_hat;
}