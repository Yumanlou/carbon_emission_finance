* // =================================================================== //
* //          PSM-DID：处理平行趋势假设不满足的问题 (核匹配版)
* // =================================================================== //

* // ======================= 0. 准备工作 ======================= //

clear all
version 17.0

* --- 【请务必修改!】 ---
* 设定您的工作目录
cd "/Users/yumanlou/Library/CloudStorage/OneDrive-email.cufe.edu.cn/2025/第五学期/论文/ESG/carbon_emission_finance/"

* --- 【请务必修改!】 ---
* 读取您的数据文件
use "./data/final_data.1.3.4_did.dta", clear 

* --- 安装PSM-DID必要的外部命令 ---
cap ssc install psmatch2, replace

* --- 准备变量 ---
xtset province_id year
gen ln_so2 = ln(industrial_so2 + 1)
cap drop treat
gen treat = (province == "Shanxi" | province == "Neimenggu")


* // =================================================================== //
* //          第一步：倾向得分匹配 (PSM) - 核匹配
* // =================================================================== //

* --- 1.1 提取政策前一年(2020年)的截面数据 ---
preserve
keep if year == 2020

* --- 1.2 定义精简后的匹配协变量 ---
local match_vars "ln_gdp population urbanization_rate market_index"

* --- 1.3 【核心修改】运行PSM，使用核匹配 (kernel matching) ---
psmatch2 treat `match_vars', outcome(gtfp_level) logit kernel

* --- 1.4 检查匹配质量：平衡性检验 ---
pstest `match_vars', both graph

di ""
di "*****************************************************"
di "请检查上方pstest的平衡性检验结果！"
di "核匹配通常能极大地改善平衡性，请关注匹配后(After Matching)的 %bias 是否显著下降。"
di "*****************************************************"
di ""

* --- 1.5 生成匹配后的样本标识 ---
* 核匹配会为所有控制组样本赋予一个权重(_weight)，不再是0/1
* 我们保留所有参与了匹配的样本
gen matched_sample = (_weight != .)
keep province_id _weight

* --- 1.6 将匹配权重合并回原始面板数据 ---
tempfile matched_provinces
save `matched_provinces', replace
restore 
merge m:1 province_id using `matched_provinces'
drop _merge

* // =================================================================== //
* //          第二步：在匹配后的样本上进行加权DID分析
* // =================================================================== //

* --- 2.1 重新生成DID变量 ---
cap drop event_time pre_* post_* did_*
gen event_time = year - 2021
gen pre_2 = (event_time == -2)
gen post_0 = (event_time == 0)
gen post_1 = (event_time == 1)
gen did_pre2 = treat * pre_2
gen did_post0 = treat * post_0
gen did_post1 = treat * post_1

* --- 2.2 定义回归中使用的变量 ---
local did_vars "did_pre2 did_post0 did_post1"
local pca_factors "factor_1 factor_2 factor_3"
local controls_full "ln_gdp sec_pctg coal_share_pctg population urbanization_rate env_exp_share market_index"
local output_path "./charts/corr/"
*cap ssc install outreg2, replace
local outfile_psmdid "${output_path}Table_Kernel_PSM_DID_Results.xls"
cap erase "`outfile_psmdid'"

* --- 2.3 【核心修改】运行加权的PSM-DID回归 ---
* 我们使用分析权重 [aw=_weight] 来进行加权最小二乘回归
di ""
di "****************** 正在运行加权PSM-DID回归 ******************"
di ""

* --- 以gtfp_level为例 ---
local y "gtfp_level"
xtreg `y' `did_vars' `pca_factors' `controls_full' i.year [aw=_weight], fe vce(cluster province_id)
outreg2 using "`outfile_psmdid'", excel replace ctitle("(`y') Kernel PSM-DID") drop(*.year)

* --- 以ln_so2为例 ---
local y "ln_so2"
xtreg `y' `did_vars' `pca_factors' `controls_full' i.year [aw=_weight], fe vce(cluster province_id)
outreg2 using "`outfile_psmdid'", excel append ctitle("(`y') Kernel PSM-DID") drop(*.year)

* // ======================== 分析结束 ======================== //
di ""
di "------------------------------------------------------------"
di "            Kernel PSM-DID分析已运行完毕！"
di "------------------------------------------------------------"
di "请到您的输出文件夹中查找名为 'Table_Kernel_PSM_DID_Results.xls' 的Excel文件。"
di "这应该是您目前最稳健的回归结果。"
di "------------------------------------------------------------"
di ""
