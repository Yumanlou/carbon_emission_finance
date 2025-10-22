// 位置：carbon_emission_finance/carbon_emission_finance/code/bayes/bayes_eventstudy_rw.stan
functions {
  // 对数似然的分块计算：把观测索引 sub 收到的区间 [start, end] 并行求和
  real partial_normal_lpdf(int[] sub, int start, int end,
                           vector y, matrix D, matrix X,
                           vector a_prov, vector a_year,
                           vector beta, vector gamma, real sigma,
                           array[] int prov, array[] int year) {
    int m = end - start + 1;
    vector[m] mu;
    for (i in 1:m) {
      int n = sub[start + i - 1];
      real linpred = 0;
      if (cols(D) > 0) linpred += dot_product(to_row_vector(D[n]) , beta);
      if (cols(X) > 0) linpred += dot_product(to_row_vector(X[n]) , gamma);
      linpred += a_prov[prov[n]] + a_year[year[n]];
      mu[i] = linpred;
    }
    return normal_lpdf(y[sub[start:end]] | mu, sigma);
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

  int<lower=1> grainsize;  // reduce_sum 并行的分块大小
}

parameters {
  vector[K] beta;
  vector[P] gamma;

  // 非中心化：省份层级
  vector[I] z_prov;
  real<lower=1e-6> tau_prov;

  // 年份：RW1（创新参数化）
  real a_year1;
  vector[T - 1] z_rw;
  real<lower=1e-6> tau_rw;

  real<lower=1e-6> sigma;  // 观测噪声
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

  // 似然（并行）
  target += reduce_sum(
              partial_normal_lpdf,
              1:N, grainsize,
              y, D, X, a_prov, a_year, beta, gamma, sigma, prov, year
            );
}

generated quantities {
  vector[N] mu_hat;
  for (n in 1:N) {
    real linpred = 0;
    if (K > 0) linpred += dot_product(to_row_vector(D[n]) , beta);
    if (P > 0) linpred += dot_product(to_row_vector(X[n]) , gamma);
    linpred += a_prov[prov[n]] + a_year[year[n]];
    mu_hat[n] = linpred;
  }
}