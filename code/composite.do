

* // ======================= 0. 准备工作 ======================= //

clear all
version 17.0
global output_path "/Users/yumanlou/Library/CloudStorage/OneDrive-email.cufe.edu.cn/2025/第五学期/论文/ESG/carbon_emission_finance/"
use "/Users/yumanlou/Library/CloudStorage/OneDrive-email.cufe.edu.cn/2025/第五学期/论文/ESG/carbon_emission_finance/data/final_data.1.3.4_did.dta", clear

* --- 数据预处理和变量生成 ---
* 设定面板数据格式
xtset province_id year

* 生成一些变量的对数形式
gen ln_so2 = ln(industrial_so2 + 1)
gen ln_wastewater = ln(industrial_wastewater + 1)
gen ln_solidwaste = ln(industrial_solid_waste + 1)
* (对污染物取对数是标准做法，可以减小异方差和右偏问题)

* 再次确认DID相关变量已存在 (以2021年为政策元年)
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

* 定义不同层级的控制变量列表，方便后续调用
local controls_base "ln_gdp"
local controls_econ "sec_pctg coal_share_pctg"
local controls_social "population urbanization_rate"
local controls_gov "env_exp_share green_finance_pilot"

* 确保outreg2命令已安装
cap ssc install outreg2, replace

* 删除可能存在的旧结果文件，以便重新开始
cap erase "${output_path}Final_Regression_Results.xls"


* // =================================================================== //
* // 第一部分：初步分析 (使用9个原始指标，证明PCA的必要性)
* // =================================================================== //
di " "
di "正在运行：第一部分 - 使用原始指标的初步分析..."
di " "

local raw_indicators "green_invention_patents green_utility_patents credit bond investment insurance equity fund carbon_finance"

* --- 以GTFP为被解释变量 ---
* 模型(1-1): 原始指标 + 基本控制
xtreg gtfp_level `raw_indicators' `controls_base', fe vce(cluster province_id)
outreg2 using "${output_path}Final_Regression_Results.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) replace ctitle("GTFP_Raw_Base")

* 模型(1-2): 原始指标 + 全套控制变量
xtreg gtfp_level `raw_indicators' `controls_base' `controls_econ' `controls_social' `controls_gov', fe vce(cluster province_id)
outreg2 using "${output_path}Final_Regression_Results.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle("GTFP_Raw_Full")


* // =================================================================== //
* // 第二部分：基准回归 (使用PCA因子，不含DID)
* // =================================================================== //
di " "
di "正在运行：第二部分 - 使用PCA因子的基准回归..."
di " "

* --- 逐个添加控制变量，以GTFP为被解释变量 ---
* 模型(2-1): 仅PCA因子 + 基本控制
xtreg gtfp_level factor_1 factor_2 factor_3 `controls_base', fe vce(cluster province_id)
outreg2 using "${output_path}Final_Regression_Results.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle("GTFP_PCA_Base")

* 模型(2-2): 添加经济与能源控制变量
xtreg gtfp_level factor_1 factor_2 factor_3 `controls_base' `controls_econ', fe vce(cluster province_id)
outreg2 using "${output_path}Final_Regression_Results.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle("GTFP_PCA_Econ")

* 模型(2-3): 添加所有控制变量
xtreg gtfp_level factor_1 factor_2 factor_3 `controls_base' `controls_econ' `controls_social' `controls_gov', fe vce(cluster province_id)
outreg2 using "${output_path}Final_Regression_Results.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle("GTFP_PCA_Full")


* // =================================================================== //
* // 第三部分：核心分析 (DID模型，检验政策净效应)
* // =================================================================== //
di " "
di "正在运行：第三部分 - 核心DID模型分析..."
di " "

local did_vars "did_pre2 did_post0 did_post1 did_post2"

* --- 逐个更换被解释变量，并使用最完整的模型 ---

* (3-1) 被解释变量: gtfp_level (工业绿色全要素生产率)
xtreg gtfp_level `did_vars' factor_1 factor_2 factor_3 `controls_base' `controls_econ' `controls_social' `controls_gov', fe vce(cluster province_id)
outreg2 using "${output_path}Final_Regression_Results.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle("DID_GTFP_Full")

* (3-2) 被解释变量: ln_co2 (总碳排放)
xtreg ln_co2 `did_vars' factor_1 factor_2 factor_3 `controls_base' `controls_econ' `controls_social' `controls_gov', fe vce(cluster province_id)
outreg2 using "${output_path}Final_Regression_Results.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle("DID_lnCO2_Full")

* (3-3) 被解释变量: coal_share_pctg (煤炭消费占比)
* 注意：被解释变量不能同时作为控制变量，所以要从控制变量列表中去掉它
local controls_for_coal "ln_gdp sec_pctg population urbanization_rate env_exp_share green_finance_pilot"
xtreg coal_share_pctg `did_vars' factor_1 factor_2 factor_3 `controls_for_coal', fe vce(cluster province_id)
outreg2 using "${output_path}Final_Regression_Results.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle("DID_CoalShare_Full")

* (3-4) 被解释变量: ln_so2 (工业二氧化硫)
xtreg ln_so2 `did_vars' factor_1 factor_2 factor_3 `controls_base' `controls_econ' `controls_social' `controls_gov', fe vce(cluster province_id)
outreg2 using "${output_path}Final_Regression_Results.xls", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle("DID_lnSO2_Full")


* // ======================== 分析结束 ======================== //
di ""
di "------------------------------------------------------------"
di "所有回归已运行完毕！"
di "请到您的输出文件夹中查找 'Final_Regression_Results.xls' 文件。"
di "路径: ${output_path}"
di "------------------------------------------------------------"
di ""
