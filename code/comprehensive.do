* // =================================================================== //
* //          最终实证分析：综合三张表呈现方案 (最终修正版)
* // =================================================================== //

* // ======================= 0. 准备工作 ======================= //

clear all
version 17.0

* --- 【请务必修改!】 ---
* 设定您的工作目录 (所有结果都将默认保存到这个文件夹)
cd "/Users/yumanlou/Library/CloudStorage/OneDrive-email.cufe.edu.cn/2025/第五学期/论文/ESG/carbon_emission_finance/"

* --- 【请务必修改!】 ---
* 读取您的数据文件
use "./data/final_data.1.3.4_did.dta", clear 

* --- 定义输出路径的全局宏 (方便管理) ---
global output_path "./charts/main reg/reg4.2/"

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

drop if province == "Xizang"

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

*cap ssc install outreg2, replace

* // =================================================================== //
* //          第一部分：生成 表1 - 核心回归结果
* // =================================================================== //
di ""
di "****************** 正在生成: 表1 - 核心回归结果 ******************"
di ""
local outfile1 "${output_path}Table_1_Main_Results.xls"
cap erase "`outfile1'"

* --- 使用一个标志位来确保第一次写入时用 replace ---
local first_run = 1 

foreach y of local depvars {
    local controls_full "`controls_base' `controls_econ' `controls_social' `controls_gov'"
    local current_controls: list controls_full - y
    
    * --- 运行基准PCA模型 ---
    xtreg `y' `pca_factors' `current_controls' i.year, fe vce(cluster province_id)
    if `first_run' == 1 {
        outreg2 using "`outfile1'", excel replace ctitle("(`y') PCA")
        local first_run = 0 
    }
    else {
        outreg2 using "`outfile1'", excel append ctitle("(`y') PCA")
    }

    * --- 运行核心DID模型 ---
    xtreg `y' `did_vars' `pca_factors' `current_controls' i.year, fe vce(cluster province_id)
    outreg2 using "`outfile1'", excel append ctitle("(`y') DID")
}


* // = "=================================================================" 
* //          第二部分：生成 表2 - 稳健性检验 I (逐级控制)
* // =================================================================== //
di ""
di "****************** 正在生成: 表2 - 稳健性检验 (逐级控制) ******************"
di ""
local outfile2 "${output_path}Table_2_Robustness_Controls_group1.xls"
cap erase "`outfile2'"

* --- 定义控制变量层级 ---
local controls_full "`controls_base' `controls_econ' `controls_social' `controls_gov'"
local robust_depvars "gtfp_level ln_so2" 

* // --- Panel A: 被解释变量 = gtfp_level ---
local y "gtfp_level"
di "--- Running Robustness Checks for: `y' ---"

* 定义该变量适用的控制变量
local c1: list controls_base - `y'
local c2: list controls_econ - `y'
local c3: list controls_social - `y'
local c4: list controls_gov - `y'

* 模型(1): +Base Controls
xtreg `y' `did_vars' `pca_factors' `c1' i.year, fe vce(cluster province_id)
outreg2 using "`outfile2'", excel replace ctitle("(`y') +Base")  // <-- 使用 REPLACE 创建文件

* 模型(2): +Econ Controls
xtreg `y' `did_vars' `pca_factors' `c1' `c2' i.year, fe vce(cluster province_id)
outreg2 using "`outfile2'", excel append ctitle("(`y') +Econ")

* 模型(3): +Social Controls
xtreg `y' `did_vars' `pca_factors' `c1' `c2' `c3' i.year, fe vce(cluster province_id)
outreg2 using "`outfile2'", excel append ctitle("(`y') +Social")

* 模型(4): +Full Controls
xtreg `y' `did_vars' `pca_factors' `c1' `c2' `c3' `c4' i.year, fe vce(cluster province_id)
outreg2 using "`outfile2'", excel append ctitle("(`y') +Full")


* // --- Panel B: 被解释变量 = ln_so2 ---
local y "ln_so2"
di "--- Running Robustness Checks for: `y' ---"

* 定义该变量适用的控制变量
local c1: list controls_base - `y'
local c2: list controls_econ - `y'
local c3: list controls_social - `y'
local c4: list controls_gov - `y'

* 模型(5): +Base Controls
xtreg `y' `did_vars' `pca_factors' `c1' i.year, fe vce(cluster province_id)
outreg2 using "`outfile2'", excel append ctitle("(`y') +Base")  // <-- 从这里开始，全部使用 APPEND

* 模型(6): +Econ Controls
xtreg `y' `did_vars' `pca_factors' `c1' sec_pctg i.year, fe vce(cluster province_id)
outreg2 using "`outfile2'", excel append ctitle("(`y') +Econ")

* 模型(7): +Social Controls
xtreg `y' `did_vars' `pca_factors' `c1' `c2' `c3' i.year, fe vce(cluster province_id)
outreg2 using "`outfile2'", excel append ctitle("(`y') +Social")

* 模型(8): +Full Controls
xtreg `y' `did_vars' `pca_factors' `c1' `c2' `c3' `c4' i.year, fe vce(cluster province_id)
outreg2 using "`outfile2'", excel append ctitle("(`y') +Full")



* // --- Panel C: 被解释变量 =  coal_share_pctg---
local y "coal_share_pctg"
di "--- Running Robustness Checks for: `y' ---"
local outfile3 "${output_path}Table_2_Robustness_Controls_group2.xls"

* 定义该变量适用的控制变量
local c1: list controls_base - `y'
local c2: list controls_econ - `y'
local c3: list controls_social - `y'
local c4: list controls_gov - `y'

* 模型(5): +Base Controls
xtreg `y' `did_vars' `pca_factors' `c1' i.year, fe vce(cluster province_id)
outreg2 using "`outfile3'", excel replace ctitle("(`y') +Base")  // <-- 从这里开始，全部使用 APPEND

* 模型(6): +Econ Controls
xtreg `y' `did_vars' `pca_factors' `c1' sec_pctg i.year, fe vce(cluster province_id)
outreg2 using "`outfile3'", excel append ctitle("(`y') +Econ")

* 模型(7): +Social Controls
xtreg `y' `did_vars' `pca_factors' `c1' sec_pctg `c3' i.year, fe vce(cluster province_id)
outreg2 using "`outfile3'", excel append ctitle("(`y') +Social")

* 模型(8): +Full Controls
xtreg `y' `did_vars' `pca_factors' `c1' sec_pctg `c3' `c4' i.year, fe vce(cluster province_id)
outreg2 using "`outfile3'", excel append ctitle("(`y') +Full")


* // --- Panel D: 被解释变量 =  coal_share_pctg---
local y "ln_co2"
di "--- Running Robustness Checks for: `y' ---"

* 定义该变量适用的控制变量
local c1: list controls_base - `y'
local c2: list controls_econ - `y'
local c3: list controls_social - `y'
local c4: list controls_gov - `y'

* 模型(5): +Base Controls
xtreg `y' `did_vars' `pca_factors' `c1' i.year, fe vce(cluster province_id)
outreg2 using "`outfile3'", excel append ctitle("(`y') +Base")

* 模型(6): +Econ Controls
xtreg `y' `did_vars' `pca_factors' `c1' `c2' i.year, fe vce(cluster province_id)
outreg2 using "`outfile3'", excel append ctitle("(`y') +Econ")

* 模型(7): +Social Controls
xtreg `y' `did_vars' `pca_factors' `c1' `c2' `c3' i.year, fe vce(cluster province_id)
outreg2 using "`outfile3'", excel append ctitle("(`y') +Social")

* 模型(8): +Full Controls
xtreg `y' `did_vars' `pca_factors' `c1' `c2' `c3' `c4' i.year, fe vce(cluster province_id)
outreg2 using "`outfile3'", excel append ctitle("(`y') +Full")



* // =================================================================== //
* //          第三部分：生成 表3 - 稳健性检验 II (变量对比)
* // =================================================================== //
di ""
di "****************** 正在生成: 表3 - 稳健性检验 (变量对比) ******************"
di ""
local outfile4 "${output_path}Table_3_Robustness_Variables.xls"
cap erase "`outfile3'"

local y_for_robust "gtfp_level" 
local controls_full "`controls_base' `controls_econ' `controls_social' `controls_gov'"
local current_controls: list controls_full - `y_for_robust'

* --- 基准模型对比 ---
xtreg `y_for_robust' `raw_indicators' `current_controls' i.year, fe vce(cluster province_id)
outreg2 using "`outfile4'", excel replace ctitle("(1) Raw Indicators")

xtreg `y_for_robust' `pca_factors' `current_controls' i.year, fe vce(cluster province_id)
outreg2 using "`outfile4'", excel append ctitle("(3) PCA Factors")

* --- DID模型对比 ---
xtreg `y_for_robust' `did_vars' `raw_indicators' `current_controls' i.year, fe vce(cluster province_id)
outreg2 using "`outfile4'", excel append ctitle("(4) DID + Raw")

xtreg `y_for_robust' `did_vars' `pca_factors' `current_controls' i.year, fe vce(cluster province_id)
outreg2 using "`outfile4'", excel append ctitle("(6) DID + PCA")


* 我们选取2019年的"第二产业占比"和"市场化指数"作为初始禀赋
bys province_id: egen sec_pctg_2019 = mean(sec_pctg) if year == 2019
bys province_id: egen market_index_2019 = mean(market_index) if year == 2019

* --- 2. 用该省份的平均值填充所有年份，使其成为一个不随时间变化的省份特征 ---
bys province_id: egen sec_pctg_2019_final = mean(sec_pctg_2019)
bys province_id: egen market_index_2019_final = mean(market_index_2019)

* --- 3. 定义包含"异质性趋势"的控制变量 ---
local controls_trends "c.sec_pctg_2019_final##c.year c.market_index_2019_final##c.year"

* --- 4. 运行加入了"异质性趋势"的最终DID模型 ---
* 我们以gtfp_level和ln_so2这两个平行趋势不满足的变量为例

local output_path "./charts/corr/"
local outfile_trends "${output_path}Table_Robust_Trends_2019_Results.xls"
cap erase "`outfile_trends'"

local controls_full "`controls_base' `controls_econ' `controls_social' `controls_gov'"

* --- 以gtfp_level为例 ---
local y "gtfp_level"
xtreg `y' `did_vars' `pca_factors' `controls_full' `controls_trends' i.year, fe vce(cluster province_id)
outreg2 using "`outfile_trends'", excel replace ctitle("(`y') DID with 2019 Trends") drop(*.year *.sec_pctg_2019_final *.market_index_2019_final)

* --- 以ln_so2为例 ---
local y "ln_so2"
xtreg `y' `did_vars' `pca_factors' `controls_full' `controls_trends' i.year, fe vce(cluster province_id)
outreg2 using "`outfile_trends'", excel append ctitle("(`y') DID with 2019 Trends") drop(*.year *.sec_pctg_2019_final *.market_index_2019_final)
