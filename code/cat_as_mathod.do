clear all
version 17.0

global output_path "/Users/yumanlou/Library/CloudStorage/OneDrive-email.cufe.edu.cn/2025/第五学期/论文/ESG/carbon_emission_finance/" 

use "/Users/yumanlou/Library/CloudStorage/OneDrive-email.cufe.edu.cn/2025/第五学期/论文/ESG/carbon_emission_finance/data/final_data.1.3.4_did.dta", clear 

* --- Data Prep & Variable Generation ---
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

* --- Define Variable Groups ---
local controls_base "ln_gdp"
local controls_econ "sec_pctg coal_share_pctg"
local controls_social "population urbanization_rate"
local controls_gov "env_exp_share green_finance_pilot market_index"
local raw_indicators "green_invention_patents green_utility_patents credit bond investment insurance equity fund carbon_finance"
local std_indicators "z_green_invention_patents z_green_utility_patents z_credit z_bond z_investment z_insurance z_equity z_fund z_carbon_finance"
local pca_factors "factor_1 factor_2 factor_3"
local did_vars "did_pre2 did_post0 did_post1 did_post2"
local depvars "gtfp_level ln_co2 ln_so2 coal_share_pctg"

* --- Prepare Output Environment ---
cap ssc install outreg2, replace


* // =================================================================== //
* //          Part 1: Generate Table 1 - Raw Indicator Regressions
* // =================================================================== //
di ""
di "****************** Generating: Table 1 - Raw Indicators (Stepwise) ******************"
di ""
local outfile1 "${output_path}Table_1_Raw_Indicators_Stepwise.xls"
cap erase "`outfile1'"

* --- Step 1: Base Controls ---
foreach y of local depvars {
    local c1: list controls_base - y
    xtreg `y' `raw_indicators' `c1', fe vce(cluster province_id)
    outreg2 using "`outfile1'", excel append ctitle("(`y') Base")
}
* --- Step 2: + Economic Controls ---
foreach y of local depvars {
    local c1: list controls_base - y
    local c2: list controls_econ - y
    xtreg `y' `raw_indicators' `c1' `c2', fe vce(cluster province_id)
    outreg2 using "`outfile1'", excel append ctitle("(`y') +Econ")
}
* --- Step 3: + Social Controls ---
foreach y of local depvars {
    local c1: list controls_base - y
    local c2: list controls_econ - y
    local c3: list controls_social - y
    xtreg `y' `raw_indicators' `c1' `c2' `c3', fe vce(cluster province_id)
    outreg2 using "`outfile1'", excel append ctitle("(`y') +Social")
}
* --- Step 4: + Full Controls ---
foreach y of local depvars {
    local c1: list controls_base - y
    local c2: list controls_econ - y
    local c3: list controls_social - y
    local c4: list controls_gov - y
    xtreg `y' `raw_indicators' `c1' `c2' `c3' `c4', fe vce(cluster province_id)
    outreg2 using "`outfile1'", excel append ctitle("(`y') +Full")
}


* // =================================================================== //
* //       Part 2: Generate Table 2 - Standardized Indicator Regressions
* // =================================================================== //
di ""
di "****************** Generating: Table 2 - Standardized Indicators (Stepwise) ******************"
di ""
local outfile2 "${output_path}Table_2_Std_Indicators_Stepwise.xls"
cap erase "`outfile2'"
* --- Step 1: Base Controls ---
foreach y of local depvars {
    local c1: list controls_base - y
    xtreg `y' `std_indicators' `c1', fe vce(cluster province_id)
    outreg2 using "`outfile2'", excel append ctitle("(`y') Base")
}
* --- Step 2: + Economic Controls ---
foreach y of local depvars {
    local c1: list controls_base - y
    local c2: list controls_econ - y
    xtreg `y' `std_indicators' `c1' `c2', fe vce(cluster province_id)
    outreg2 using "`outfile2'", excel append ctitle("(`y') +Econ")
}
* --- Step 3: + Social Controls ---
foreach y of local depvars {
    local c1: list controls_base - y
    local c2: list controls_econ - y
    local c3: list controls_social - y
    xtreg `y' `std_indicators' `c1' `c2' `c3', fe vce(cluster province_id)
    outreg2 using "`outfile2'", excel append ctitle("(`y') +Social")
}
* --- Step 4: + Full Controls ---
foreach y of local depvars {
    local c1: list controls_base - y
    local c2: list controls_econ - y
    local c3: list controls_social - y
    local c4: list controls_gov - y
    xtreg `y' `std_indicators' `c1' `c2' `c3' `c4', fe vce(cluster province_id)
    outreg2 using "`outfile2'", excel append ctitle("(`y') +Full")
}


* // =================================================================== //
* //          Part 3: Generate Table 3 - PCA Factor Regressions
* // =================================================================== //
di ""
di "****************** Generating: Table 3 - PCA Factors (Stepwise) ******************"
di ""
local outfile3 "${output_path}Table_3_PCA_Factors_Stepwise.xls"
cap erase "`outfile3'"
* --- Step 1: Base Controls ---
foreach y of local depvars {
    local c1: list controls_base - y
    xtreg `y' `pca_factors' `c1', fe vce(cluster province_id)
    outreg2 using "`outfile3'", excel append ctitle("(`y') Base")
}
* --- Step 2: + Economic Controls ---
foreach y of local depvars {
    local c1: list controls_base - y
    local c2: list controls_econ - y
    xtreg `y' `pca_factors' `c1' `c2', fe vce(cluster province_id)
    outreg2 using "`outfile3'", excel append ctitle("(`y') +Econ")
}
* --- Step 3: + Social Controls ---
foreach y of local depvars {
    local c1: list controls_base - y
    local c2: list controls_econ - y
    local c3: list controls_social - y
    xtreg `y' `pca_factors' `c1' `c2' `c3', fe vce(cluster province_id)
    outreg2 using "`outfile3'", excel append ctitle("(`y') +Social")
}
* --- Step 4: + Full Controls ---
foreach y of local depvars {
    local c1: list controls_base - y
    local c2: list controls_econ - y
    local c3: list controls_social - y
    local c4: list controls_gov - y
    xtreg `y' `pca_factors' `c1' `c2' `c3' `c4', fe vce(cluster province_id)
    outreg2 using "`outfile3'", excel append ctitle("(`y') +Full")
}


* // =================================================================== //
* //          Part 4: Generate Table 4 - DID Model Regressions
* // =================================================================== //
di ""
di "****************** Generating: Table 4 - DID Analysis (Stepwise) ******************"
di ""
local outfile4 "${output_path}Table_4_DID_Analysis_Stepwise.xls"
cap erase "`outfile4'"
* --- Step 1: Base Controls ---
foreach y of local depvars {
    local c1: list controls_base - y
    xtreg `y' `did_vars' `pca_factors' `c1', fe vce(cluster province_id)
    outreg2 using "`outfile4'", excel append ctitle("(`y') Base")
}
* --- Step 2: + Economic Controls ---
foreach y of local depvars {
    local c1: list controls_base - y
    local c2: list controls_econ - y
    xtreg `y' `did_vars' `pca_factors' `c1' `c2', fe vce(cluster province_id)
    outreg2 using "`outfile4'", excel append ctitle("(`y') +Econ")
}
* --- Step 3: + Social Controls ---
foreach y of local depvars {
    local c1: list controls_base - y
    local c2: list controls_econ - y
    local c3: list controls_social - y
    xtreg `y' `did_vars' `pca_factors' `c1' `c2' `c3', fe vce(cluster province_id)
    outreg2 using "`outfile4'", excel append ctitle("(`y') +Social")
}
* --- Step 4: + Full Controls ---
foreach y of local depvars {
    local c1: list controls_base - y
    local c2: list controls_econ - y
    local c3: list controls_social - y
    local c4: list controls_gov - y
    xtreg `y' `did_vars' `pca_factors' `c1' `c2' `c3' `c4', fe vce(cluster province_id)
    outreg2 using "`outfile4'", excel append ctitle("(`y') +Full")
}
* Note: A small manual step is needed for the very first column of each excel file.
* Change its 'append' to 'replace' or simply ignore the first empty column.
* To make this fully automatic, the first 'append' in each section has been kept.
* You can just delete the empty column A in each resulting Excel file.


* // ======================== Analysis Complete ======================== //
di ""
di "------------------------------------------------------------"
di "               All regressions have been completed!"
di "------------------------------------------------------------"
di "Please check your output folder for the following 4 Excel files:"
di "1. Table_1_Raw_Indicators_Stepwise.xls"
di "2. Table_2_Std_Indicators_Stepwise.xls"
di "3. Table_3_PCA_Factors_Stepwise.xls"
di "4. Table_4_DID_Analysis_Stepwise.xls"
di "Each file contains 16 columns, showing results for 4 dependent variables x 4 control variable sets."
di "Path: ${output_path}"
di "------------------------------------------------------------"
di ""
