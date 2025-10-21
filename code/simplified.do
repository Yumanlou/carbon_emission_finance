clear all
version 17.0

global output_path "/Users/yumanlou/Library/CloudStorage/OneDrive-email.cufe.edu.cn/2025/第五学期/论文/ESG/carbon_emission_finance/" 

use "/Users/yumanlou/Library/CloudStorage/OneDrive-email.cufe.edu.cn/2025/第五学期/论文/ESG/carbon_emission_finance/data/final_data.1.3.4_did.dta", clear 

* --- 数据预处理和变量生成 ---
xtset province_id year
gen ln_so2 = ln(industrial_so2 + 1)
cap drop treat event_time pre_* post_* did_*
gen treat = (province == "Shanxi" | province == "Neimenggu")
gen event_time = year - 2021
gen pre_2 = (event_time == -2)
gen post_0 = (event_time == 0)
gen post_1 = (event_time == 1)
gen post_2 = (event_time == 2)
gen did_pre2 = treat * pre_2
gen did_post0 = treat * post_0
gen did_post1 = treat * post_1
gen did_post2 = treat * post_2

* --- 定义变量列表 ---
local controls_base "ln_gdp"
local controls_econ "sec_pctg coal_share_pctg"
local controls_social "population urbanization_rate"
local controls_gov "env_exp_share green_finance_pilot market_index"
local raw_indicators "green_invention_patents green_utility_patents credit bond investment insurance equity fund carbon_finance"
local std_indicators "z_green_invention_patents z_green_utility_patents z_credit z_bond z_investment z_insurance z_equity z_fund z_carbon_finance"
local pca_factors "factor_1 factor_2 factor_3"
local did_vars "did_pre2 did_post0 did_post1 did_post2"
local depvars "gtfp_level ln_so2 coal_share_pctg ln_co2"

cap ssc install outreg2, replace

* // =================================================================== //
* //          第一部分：生成 表1 - 核心回归结果
* // =================================================================== //
di ""
di "****************** 正在生成: 表1 - 核心回归结果 ******************"
di ""
local outfile1 "${output_path}Table_1_Main_Results.xls"
cap erase "`outfile1'"

foreach y of local depvars {
    * 动态定义全套控制变量
    local controls_full "`controls_base' `controls_econ' `controls_social' `controls_gov'"
    local current_controls: list controls_full - y
    
    * 运行基准PCA模型
    xtreg `y' `pca_factors' `current_controls', fe vce(cluster province_id)
    outreg2 using "`outfile1'", excel append ctitle("(`y') PCA")

    * 运行核心DID模型
    xtreg `y' `did_vars' `pca_factors' `current_controls', fe vce(cluster province_id)
    outreg2 using "`outfile1'", excel append ctitle("(`y') DID")
}


* // =================================================================== //
* //          第二部分：生成 表2 - 稳健性检验 I (逐级控制)
* // =================================================================== //
di ""
di "****************** 正在生成: 表2 - 稳健性检验 (逐级控制) ******************"
di ""
local outfile2 "${output_path}Table_2_Robustness_Controls.xls"
cap erase "`outfile2'"

local robust_depvars "gtfp_level ln_so2" // 选取两个最重要的被解释变量
foreach y of local robust_depvars {
    * 动态定义控制变量
    local c1: list controls_base - y
    local c2: list controls_econ - y
    local c3: list controls_social - y
    local c4: list controls_gov - y

    xtreg `y' `did_vars' `pca_factors' `c1', fe vce(cluster province_id)
    outreg2 using "`outfile2'", excel append ctitle("(`y') +Base")
    xtreg `y' `did_vars' `pca_factors' `c1' `c2', fe vce(cluster province_id)
    outreg2 using "`outfile2'", excel append ctitle("(`y') +Econ")
    xtreg `y' `did_vars' `pca_factors' `c1' `c2' `c3', fe vce(cluster province_id)
    outreg2 using "`outfile2'", excel append ctitle("(`y') +Social")
    xtreg `y' `did_vars' `pca_factors' `c1' `c2' `c3' `c4', fe vce(cluster province_id)
    outreg2 using "`outfile2'", excel append ctitle("(`y') +Full")
}


* // =================================================================== //
* //          第三部分：生成 表3 - 稳健性检验 II (变量对比)
* // =================================================================== //
di ""
di "****************** 正在生成: 表3 - 稳健性检验 (变量对比) ******************"
di ""
local outfile3 "${output_path}Table_3_Robustness_Variables.xls"
cap erase "`outfile3'"

local y_for_robust "gtfp_level" // 选取一个最典型的被解释变量
local controls_full "`controls_base' `controls_econ' `controls_social' `controls_gov'"
local current_controls: list controls_full - `y_for_robust'

* 模型(1): 原始指标
xtreg `y_for_robust' `raw_indicators' `current_controls', fe vce(cluster province_id)
outreg2 using "`outfile3'", excel append ctitle("Raw Indicators")

* 模型(2): 标准化指标
xtreg `y_for_robust' `std_indicators' `current_controls', fe vce(cluster province_id)
outreg2 using "`outfile3'", excel append ctitle("Std Indicators")

* 模型(3): PCA因子
xtreg `y_for_robust' `pca_factors' `current_controls', fe vce(cluster province_id)
outreg2 using "`outfile3'", excel append ctitle("PCA Factors")
