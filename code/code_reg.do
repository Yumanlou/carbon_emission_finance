clear all
cap log c
set more off 

global datadir "/Users/yumanlou/Library/CloudStorage/OneDrive-email.cufe.edu.cn/2025/第五学期/论文/ESG/carbon_emission_finance/data"
global code "/Users/yumanlou/Library/CloudStorage/OneDrive-email.cufe.edu.cn/2025/第五学期/论文/ESG/carbon_emission_finance/code"

cd "/Users/yumanlou/Library/CloudStorage/OneDrive-email.cufe.edu.cn/2025/第五学期/论文/ESG/carbon_emission_finance/data"

** Table 2. Cross section regression of ln(co2) and 3 factors
**********************************************************************************
use "$datadir/data1.2.dta"
*gen ln_gdp = ln(gdp)
*gen ln_co2 = ln(co2_emissions)
xtset province_id year
corr ln_gdp green_invention_patents green_utility_patents credit bond investment insurance equity fund carbon_finance gf_index

/*
(obs=738)

             |   ln_gdp g~inve~s g~util~s   credit     bond invest~t insura~e   equity     fund carbon~e gf_index
-------------+---------------------------------------------------------------------------------------------------
      ln_gdp |   1.0000
green_inve~s |   0.5934   1.0000
green_util~s |   0.6139   0.8984   1.0000
      credit |   0.5927   0.4479   0.4532   1.0000
        bond |   0.6193   0.4444   0.4619   0.9646   1.0000
  investment |  -0.7272  -0.2298  -0.2331  -0.1637  -0.1887   1.0000
   insurance |   0.7253   0.7171   0.7355   0.5448   0.5627  -0.3630   1.0000
      equity |   0.6178   0.4469   0.4615   0.9594   0.9834  -0.1891   0.5694   1.0000
        fund |   0.6078   0.4405   0.4502   0.9521   0.9796  -0.1829   0.5460   0.9712   1.0000
carbon_fin~e |  -0.7319  -0.2616  -0.2745  -0.4130  -0.4325   0.7086  -0.4258  -0.4372  -0.4217   1.0000
    gf_index |  -0.3720  -0.0449  -0.0571   0.1497   0.0956   0.5943  -0.0774   0.1200   0.1153   0.2771   1.0000
*/

spearman ln_gdp green_invention_patents green_utility_patents credit bond investment insurance equity fund carbon_finance gf_index

/*
Number of observations = 738

             |   ln_gdp g~inve~s g~util~s   credit     bond invest~t insura~e   equity     fund carbon~e gf_index
-------------+---------------------------------------------------------------------------------------------------
      ln_gdp |   1.0000 
green_inve~s |   0.9350   1.0000 
green_util~s |   0.9489   0.9799   1.0000 
      credit |   0.6193   0.7069   0.7214   1.0000 
        bond |   0.6418   0.7320   0.7452   0.9675   1.0000 
  investment |  -0.9189  -0.7975  -0.8121  -0.3241  -0.3432   1.0000 
   insurance |   0.8185   0.7864   0.8024   0.6399   0.6535  -0.6873   1.0000 
      equity |   0.6422   0.7322   0.7447   0.9612   0.9834  -0.3461   0.6616   1.0000 
        fund |   0.6311   0.7208   0.7301   0.9550   0.9803  -0.3339   0.6433   0.9724   1.0000 
carbon_fin~e |  -0.8770  -0.7659  -0.8019  -0.5639  -0.5831   0.8128  -0.7756  -0.5877  -0.5743   1.0000 
    gf_index |  -0.2588  -0.2156  -0.2105   0.1411   0.0982   0.3394  -0.1093   0.1186   0.1176   0.2101   1.0000 
*/

xtreg ln_co2 ln_gdp green_invention_patents green_utility_patents credit bond investment insurance equity fund carbon_finance
vif, uncentered
/*

    Variable |       VIF       1/VIF  
-------------+----------------------
        bond |   1115.17    0.000897
      equity |    736.83    0.001357
        fund |    577.22    0.001732
      credit |    326.53    0.003063
      ln_gdp |     45.21    0.022119
green_util~s |      7.16    0.139725
   insurance |      6.97    0.143534
green_inve~s |      6.81    0.146870
  investment |      3.53    0.283166
carbon_fin~e |      3.53    0.283493
-------------+----------------------
    Mean VIF |    282.90

解释变量的相关性较高，考虑使用PCA后再进行回归
*/

*对部分数据进行pca，转换为因子以去除多重共线性
********************************************************
local fa_vars "green_invention_patents green_utility_patents credit bond investment insurance equity fund carbon_finance"

* 缺失值填充
foreach var of varlist `fa_vars' {
    qui summarize `var', detail
    replace `var' = r(p50) if missing(`var')
}

* Z-Score 标准化
foreach var of varlist `fa_vars' {
    egen z_`var' = std(`var')
}
local z_fa_vars "z_green_invention_patents z_green_utility_patents z_credit z_bond z_investment z_insurance z_equity z_fund z_carbon_finance"

*运行因子分析并获取载荷矩阵
factor `z_fa_vars', pcf factors(3)
rotate, varimax
matrix L_original = e(L_rotated)
matrix list L_original


*使用 Mata 对矩阵取绝对值
mata:
    L = st_matrix("e(L_rotated)")
    L_abs = abs(L)
    
    st_matrix("L_absolute", L_abs)
end

di "" // 空一行，方便查看
di "--- 取绝对值后的因子载荷 (Absolute Factor Loadings) ---"
matrix list L_absolute
*针对生成的因子进行xtreg,fe
