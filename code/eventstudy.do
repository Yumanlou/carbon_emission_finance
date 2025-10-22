* // =================================================================== //
* //          生成动态DID的事件研究图 (Event Study Plot)
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

* --- 安装绘图必要的外部命令 (如果尚未安装) ---
cap ssc install coefplot, replace

* --- 准备变量 (与之前相同) ---
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
local controls_full "factor_1 factor_2 factor_3 ln_gdp sec_pctg coal_share_pctg population urbanization_rate env_exp_share green_finance_pilot market_index"

* --- 准备异质性趋势控制变量 (与表4一致) ---
gen sec_pctg_2019_final = .
gen market_index_2019_final = .
bysort province_id (year): replace sec_pctg_2019_final = sec_pctg[1] if year==2019
bysort province_id (year): replace market_index_2019_final = market_index[1] if year==2019
bysort province_id (year): egen sec_pctg_2019_mean = mean(sec_pctg_2019_final)
bysort province_id (year): egen market_index_2019_mean = mean(market_index_2019_final)
drop sec_pctg_2019_final market_index_2019_final
rename sec_pctg_2019_mean sec_pctg_2019_final
rename market_index_2019_mean market_index_2019_final
local trends_control "c.sec_pctg_2019_final#c.year c.market_index_2019_final#c.year"


* ======================= 图1：GTFP（修正模型） =======================

xtreg gtfp_level did_pre2 did_post0 did_post1 did_post2 ///
      `controls_full' `trends_control' i.year, fe vce(cluster province_id)

preserve
clear
set obs 4
gen event = .          // 横轴：-2, 0, 1, 2
gen b     = .          // 系数
gen se    = .          // 标准误

local coefs did_pre2 did_post0 did_post1 did_post2
local xvals -2 0 1 2
local i = 1
foreach c of local coefs {
    local x : word `i' of `xvals'
    replace event = `x' in `i'
    replace b     = _b[`c'] in `i'
    replace se    = _se[`c'] in `i'
    local ++i
}

gen tcrit = invttail(e(df_r), 0.025)   // 95%CI 的 t 分位
gen cil = b - tcrit*se
gen cih = b + tcrit*se

twoway  (rcap cil cih event, lwidth(medthick)) ///
        (scatter b event, msymbol(D) mcolor(navy)) , ///
        yline(0, lcolor(black*0.8) lwidth(thin)) ///
        xline(-1, lcolor(gs8) lpattern(shortdash)) ///
        xlabel(-2 "政策前2年" -1 "政策前1年(基准)" 0 "政策当年" 1 "政策后1年" 2 "政策后2年", labsize(small)) ///
        xtitle("相对于政策实施的年份", size(small)) ///
        ytitle("政策效应估计系数", size(small)) ///
        title("转型金融政策对GTFP的动态影响 (修正模型)", size(medium)) ///
        graphregion(color(white)) plotregion(margin(zero))

graph export "Event_Study_GTFP_Final.png", replace width(2000)
restore


* ======================= 图2：SO2（修正模型） =======================

xtreg ln_so2 did_pre2 did_post0 did_post1 did_post2 ///
      `controls_full' `trends_control' i.year, fe vce(cluster province_id)

preserve
clear
set obs 4
gen event = .
gen b     = .
gen se    = .

local coefs did_pre2 did_post0 did_post1 did_post2
local xvals -2 0 1 2
local i = 1
foreach c of local coefs {
    local x : word `i' of `xvals'
    replace event = `x' in `i'
    replace b     = _b[`c'] in `i'
    replace se    = _se[`c'] in `i'
    local ++i
}

gen tcrit = invttail(e(df_r), 0.025)
gen cil = b - tcrit*se
gen cih = b + tcrit*se

twoway  (rcap cil cih event, lwidth(medthick)) ///
        (scatter b event, msymbol(D) mcolor(navy)) , ///
        yline(0, lcolor(black*0.8) lwidth(thin)) ///
        xline(-1, lcolor(gs8) lpattern(shortdash)) ///
        xlabel(-2 "政策前2年" -1 "政策前1年(基准)" 0 "政策当年" 1 "政策后1年" 2 "政策后2年", labsize(small)) ///
        xtitle("相对于政策实施的年份", size(small)) ///
        ytitle("政策效应估计系数", size(small)) ///
        title("转型金融政策对工业SO2排放的动态影响 (修正模型)", size(medium)) ///
        graphregion(color(white)) plotregion(margin(zero))

graph export "Event_Study_SO2_Final.png", replace width(2000)
restore


di ""
di "------------------------------------------------------------"
di "           专业格式的事件研究图已生成！"
di "------------------------------------------------------------"
