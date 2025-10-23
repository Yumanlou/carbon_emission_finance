functions {
  real partial_llk(
      array[] int sub_slice,     // reduce_sum 传进来的“分片”
      int start, int end,
      vector y, matrix D, matrix X,
      vector a_prov, vector a_year,
      vector beta, vector gamma, real sigma,
      array[] int prov, array[] int year
  ) {
    int m = size(sub_slice);
    vector[m] mu;
    for (i in 1:m) {
      int n = sub_slice[i];      // ✅ 注意：直接用分片索引，不要再加 start
      real linpred = 0;
      if (cols(D) > 0) linpred += dot_product(to_row_vector(D[n]), beta);
      if (cols(X) > 0) linpred += dot_product(to_row_vector(X[n]), gamma);
      linpred += a_prov[prov[n]] + a_year[year[n]];
      mu[i] = linpred;
    }
    return normal_lpdf(y[sub_slice] | mu, sigma);   // ✅ 同样用 sub_slice
  }
}

data {
  int<lower=1> N;
  int<lower=1> I;
  int<lower=1> T;
  int<lower=0> K;
  int<lower=0> P;

  array[N] int<lower=1, upper=I> prov;
  array[N] int<lower=1, upper=T> year;

  matrix[N, K] D;
  matrix[N, P] X;
  vector[N] y;
  int<lower=1> grainsize;            // reduce_sum 分块大小
}

transformed data {
  // reduce_sum 需要“数组”作为被切片对象，1..N 显式展开
  array[N] int n_idx;
  for (n in 1:N) n_idx[n] = n;
}

parameters {
  vector[K] beta;
  vector[P] gamma;

  // 省份层级（非中心化）
  vector[I] z_prov;
  real<lower=1e-6> tau_prov;

  // 年份随机游走 RW1（创新参数化）
  real a_year1;
  vector[T - 1] z_rw;
  real<lower=1e-6> tau_rw;

  real<lower=1e-6> sigma;            // 观测噪声
}

transformed parameters {
  vector[I] a_prov = tau_prov * z_prov;

  vector[T] a_year;
  a_year[1] = a_year1;
  for (t in 2:T)
    a_year[t] = a_year[t - 1] + tau_rw * z_rw[t - 1];
}

model {
  // 先验
  beta     ~ normal(0, 1);
  gamma    ~ normal(0, 1);
  z_prov   ~ normal(0, 1);
  tau_prov ~ normal(0, 1) T[0, ];
  a_year1  ~ normal(0, 5);
  z_rw     ~ normal(0, 1);
  tau_rw   ~ normal(0, 1) T[0, ];
  sigma    ~ normal(0, 1) T[0, ];

  // 似然（链内并行）
  target += reduce_sum(
              partial_llk,
              n_idx, grainsize,
              y, D, X, a_prov, a_year, beta, gamma, sigma, prov, year
            );
}

generated quantities {
  vector[N] mu_hat;
  for (n in 1:N) {
    real linpred = 0;
    if (K > 0) linpred += dot_product(to_row_vector(D[n]), beta);
    if (P > 0) linpred += dot_product(to_row_vector(X[n]), gamma);
    linpred += a_prov[prov[n]] + a_year[year[n]];
    mu_hat[n] = linpred;
  }
}