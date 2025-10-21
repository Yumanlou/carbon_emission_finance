clear all
version 17.0

* --- 【请务必修改!】 ---
* 设定您的工作目录 (所有结果都将默认保存到这个文件夹)
cd "/Users/yumanlou/Library/CloudStorage/OneDrive-email.cufe.edu.cn/2025/第五学期/论文/ESG/carbon_emission_finance/"

* --- 【请务必修改!】 ---
* 读取您的数据文件
use "./data/final_data.1.3.4_did.dta", clear 

* --- 定义输出路径的全局宏 (方便管理) ---
global output_path "./charts/main reg/time_effect"

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
local did_vars "did_pre2 did_post0 did_post1"
local depvars "gtfp_level ln_so2 coal_share_pctg ln_co2"

*cap ssc install outreg2, replace

* // =================================================================== //
* //          第一部分：生成 表1 - 核心回归结果
* // =================================================================== //
di ""
di "****************** 正在生成: 表1 - 核心回归结果 ******************"
di ""
local outfile1 "${output_path}Table_1_Main_Results.xls"
cap erase "`outfile1'"

local first_run = 1 

foreach y of local depvars {
    local controls_full "`controls_base' `controls_econ' `controls_social' `controls_gov'"
    local current_controls: list controls_full - y
    
    * --- 运行基准PCA模型 (已加入 i.year) ---
    xtreg `y' `pca_factors' `current_controls' i.year, fe vce(cluster province_id)
    if `first_run' == 1 {
        outreg2 using "`outfile1'", excel replace ctitle("(`y') PCA") drop(*.year)
        local first_run = 0 
    }
    else {
        outreg2 using "`outfile1'", excel append ctitle("(`y') PCA") drop(*.year)
    }

    * --- 运行核心DID模型 (已加入 i.year) ---
    xtreg `y' `did_vars' `pca_factors' `current_controls' i.year, fe vce(cluster province_id)
    outreg2 using "`outfile1'", excel append ctitle("(`y') DID") drop(*.year)
}


* // =================================================================== //
* //          第二部分：生成 表2 - 稳健性检验 I (逐级控制)
* // =================================================================== //
di ""
di "****************** 正在生成: 表2 - 稳健性检验 (逐级控制) ******************"
di ""
local outfile2 "${output_path}Table_2_Robustness_Controls.xls"
cap erase "`outfile2'"

* // --- Panel A: 被解释变量 = gtfp_level ---
local y "gtfp_level"
di "--- Running Robustness Checks for: `y' ---"

* 【核心修正】: 我们为 gtfp_level 手动定义每一组控制变量
local panelA_c1 "ln_gdp"
local panelA_c2 "sec_pctg coal_share_pctg"
local panelA_c3 "population urbanization_rate"
local panelA_c4 "env_exp_share green_finance_pilot market_index"

* 模型(1): +Base Controls
xtreg `y' `did_vars' `pca_factors' `panelA_c1' i.year, fe vce(cluster province_id)
outreg2 using "`outfile2'", excel replace ctitle("(`y') +Base") drop(*.year)

* 模型(2): +Econ Controls
xtreg `y' `did_vars' `pca_factors' `panelA_c1' `panelA_c2' i.year, fe vce(cluster province_id)
outreg2 using "`outfile2'", excel append ctitle("(`y') +Econ") drop(*.year)

* 模型(3): +Social Controls
xtreg `y' `did_vars' `pca_factors' `panelA_c1' `panelA_c2' `panelA_c3' i.year, fe vce(cluster province_id)
outreg2 using "`outfile2'", excel append ctitle("(`y') +Social") drop(*.year)

* 模型(4): +Full Controls
xtreg `y' `did_vars' `pca_factors' `panelA_c1' `panelA_c2' `panelA_c3' `panelA_c4' i.year, fe vce(cluster province_id)
outreg2 using "`outfile2'", excel append ctitle("(`y') +Full") drop(*.year)


* // --- Panel B: 被解释变量 = ln_so2 ---
local y "ln_so2"
di "--- Running Robustness Checks for: `y' ---"

* 【核心修正】: 同样地，我们为 ln_so2 手动定义每一组控制变量
local panelB_c1 "ln_gdp"
local panelB_c2 "sec_pctg coal_share_pctg"
local panelB_c3 "population urbanization_rate"
local panelB_c4 "env_exp_share green_finance_pilot market_index"

* 模型(5): +Base Controls
xtreg `y' `did_vars' `pca_factors' `panelB_c1' i.year, fe vce(cluster province_id)
outreg2 using "`outfile2'", excel append ctitle("(`y') +Base") drop(*.year)

* 模型(6): +Econ Controls
xtreg `y' `did_vars' `pca_factors' `panelB_c1' `panelB_c2' i.year, fe vce(cluster province_id)
outreg2 using "`outfile2'", excel append ctitle("(`y') +Econ") drop(*.year)

* 模型(7): +Social Controls
xtreg `y' `did_vars' `pca_factors' `panelB_c1' `panelB_c2' `panelB_c3' i.year, fe vce(cluster province_id)
outreg2 using "`outfile2'", excel append ctitle("(`y') +Social") drop(*.year)

* 模型(8): +Full Controls
xtreg `y' `did_vars' `pca_factors' `panelB_c1' `panelB_c2' `panelB_c3' `panelB_c4' i.year, fe vce(cluster province_id)
outreg2 using "`outfile2'", excel append ctitle("(`y') +Full") drop(*.year)


* // =================================================================== //
* //          第三部分：生成 表3 - 稳健性检验 II (变量对比)
* // =================================================================== //
di ""
di "****************** 正在生成: 表3 - 稳健性检验 (变量对比) ******************"
di ""
local outfile3 "${output_path}Table_3_Robustness_Variables.xls"
cap erase "`outfile3'"

local y_for_robust "gtfp_level" 
local controls_full "`controls_base' `controls_econ' `controls_social' `controls_gov'"
local current_controls: list controls_full - `y_for_robust'

* --- 基准模型对比 ---
xtreg `y_for_robust' `raw_indicators' `current_controls' i.year, fe vce(cluster province_id)
outreg2 using "`outfile3'", excel replace ctitle("(1) Raw Indicators") drop(*.year)

xtreg `y_for_robust' `std_indicators' `current_controls' i.year, fe vce(cluster province_id)
outreg2 using "`outfile3'", excel append ctitle("(2) Std Indicators") drop(*.year)

xtreg `y_for_robust' `pca_factors' `current_controls' i.year, fe vce(cluster province_id)
outreg2 using "`outfile3'", excel append ctitle("(3) PCA Factors") drop(*.year)

* --- DID模型对比 ---
xtreg `y_for_robust' `did_vars' `raw_indicators' `current_controls' i.year, fe vce(cluster province_id)
outreg2 using "`outfile3'", excel append ctitle("(4) DID + Raw") drop(*.year)

xtreg `y_for_robust' `did_vars' `std_indicators' `current_controls' i.year, fe vce(cluster province_id)
outreg2 using "`outfile3'", excel append ctitle("(5) DID + Std") drop(*.year)

xtreg `y_for_robust' `did_vars' `pca_factors' `current_controls' i.year, fe vce(cluster province_id)
outreg2 using "`outfile3'", excel append ctitle("(6) DID + PCA") drop(*.year)

