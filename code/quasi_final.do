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
local depvars "gtfp_level ln_co2 ln_so2 coal_share_pctg"

* --- 准备输出环境 ---
cap ssc install outreg2, replace

* // =================================================================== //
* //          开始对所有被解释变量进行循环回归分析
* // =================================================================== //

foreach y of local depvars {
    
    di ""
    di "************************************************************"
    di "           正在为被解释变量 `y' 生成结果表             "
    di "************************************************************"
    di ""
	
	* --- 定义独立的输出文件名，并删除旧文件 ---
	local outfile "${output_path}Table_Matrix_for_`y'.xls"
	cap erase "`outfile'"

    * --- 动态设定控制变量列表 ---
    local c1: list controls_base - y
    local c2: list controls_econ - y
    local c3: list controls_social - y
    local c4: list controls_gov - y
	local step1 "`c1'"
	local step2 "`c1' `c2'"
	local step3 "`c1' `c2' `c3'"
	local step4 "`c1' `c2' `c3' `c4'"

    * // --- Part 1: 【原始数据】指标回归 (4列) ---
    xtreg `y' `raw_indicators' `step1', fe vce(cluster province_id)
    outreg2 using "`outfile'", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) replace ctitle("(1) Raw+Base")
    xtreg `y' `raw_indicators' `step2', fe vce(cluster province_id)
    outreg2 using "`outfile'", excel append ctitle("(2) Raw+Econ")
    xtreg `y' `raw_indicators' `step3', fe vce(cluster province_id)
    outreg2 using "`outfile'", excel append ctitle("(3) Raw+Social")
    xtreg `y' `raw_indicators' `step4', fe vce(cluster province_id)
    outreg2 using "`outfile'", excel append ctitle("(4) Raw+Full")

    * // --- Part 2: 【标准化数据】指标回归 (4列) ---
    xtreg `y' `std_indicators' `step1', fe vce(cluster province_id)
    outreg2 using "`outfile'", excel append ctitle("(5) Std+Base")
    xtreg `y' `std_indicators' `step2', fe vce(cluster province_id)
    outreg2 using "`outfile'", excel append ctitle("(6) Std+Econ")
    xtreg `y' `std_indicators' `step3', fe vce(cluster province_id)
    outreg2 using "`outfile'", excel append ctitle("(7) Std+Social")
    xtreg `y' `std_indicators' `step4', fe vce(cluster province_id)
    outreg2 using "`outfile'", excel append ctitle("(8) Std+Full")

    * // --- Part 3: 【PCA数据】因子回归 (4列) ---
    xtreg `y' `pca_factors' `step1', fe vce(cluster province_id)
    outreg2 using "`outfile'", excel append ctitle("(9) PCA+Base")
    xtreg `y' `pca_factors' `step2', fe vce(cluster province_id)
    outreg2 using "`outfile'", excel append ctitle("(10) PCA+Econ")
    xtreg `y' `pca_factors' `step3', fe vce(cluster province_id)
    outreg2 using "`outfile'", excel append ctitle("(11) PCA+Social")
    xtreg `y' `pca_factors' `step4', fe vce(cluster province_id)
    outreg2 using "`outfile'", excel append ctitle("(12) PCA+Full")

    * // --- Part 4: 【DID数据】回归 (4列) ---
    xtreg `y' `did_vars' `pca_factors' `step1', fe vce(cluster province_id)
    outreg2 using "`outfile'", excel append ctitle("(13) DID+Base")
    xtreg `y' `did_vars' `pca_factors' `step2', fe vce(cluster province_id)
    outreg2 using "`outfile'", excel append ctitle("(14) DID+Econ")
    xtreg `y' `did_vars' `pca_factors' `step3', fe vce(cluster province_id)
    outreg2 using "`outfile'", excel append ctitle("(15) DID+Social")
    xtreg `y' `did_vars' `pca_factors' `step4', fe vce(cluster province_id)
    outreg2 using "`outfile'", excel append ctitle("(16) DID+Full")
}


* // ======================== 分析结束 ======================== //
di ""
di "------------------------------------------------------------"
di "               所有回归已运行完毕！"
di "------------------------------------------------------------"
di "请到您的输出文件夹中查找以下按照【被解释变量】分类的4个Excel文件:"
di "1. Table_Matrix_for_gtfp_level.xls"
di "2. Table_Matrix_for_ln_co2.xls"
di "3. Table_Matrix_for_ln_so2.xls"
di "4. Table_Matrix_for_coal_share_pctg.xls"
di "每个文件中都包含了完整的16列回归结果，展示了4x4的分析矩阵。"
di "路径: ${output_path}"
di "------------------------------------------------------------"
di ""
