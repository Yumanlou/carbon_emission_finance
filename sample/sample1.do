clear all
cap log c
set more off 

global datadir "C:\CUFE\Courses\2021 Spring\Financial Econometrics"
global code "C:\CUFE\Courses\2021 Spring\Financial Econometrics\Code"

cd "C:\CUFE\Courses\2021 Spring\Financial Econometrics\Code"
set memory 15g
set more off

** Table IA.1 Cross section correlations of lottery preference
**************************************************************************
use "$datadir3\Data\19482018\asymanomsort4818pla1_3m.dta", clear
keep if date>=tm(1962m1)
tsset permno date
keep if date<tm(1967m1)
** date, 1962m1 to 1966m12, but with gaps

keep permno date mktrf smb hml umd rexcess lme idiovol vol lidiovol beta_capm coskew cokurt ret_exadj six_month laghc lsz lbm lturn lmax lmin lmaxmin skew_3m iskew_capmroll3m
saveold "C:\CUFE\Courses\2021 Spring\Financial Econometrics\data6266sample.dta", replace

use "$datadir\data6266sample.dta", clear
corr lsz lbm lturn lmax lmin
** gen lvol = L.vol
/*
(obs=73,415)

             |      lsz      lbm    lturn     lmax     lmin
-------------+---------------------------------------------
         lsz |   1.0000
         lbm |  -0.4049   1.0000
       lturn |  -0.2903   0.0636   1.0000
        lmax |  -0.3226   0.0250   0.4550   1.0000
        lmin |   0.3428  -0.0606  -0.3606  -0.5928   1.0000
*/
spearman lsz lbm lturn lmax lmin
/*
(obs=73415)

             |      lsz      lbm    lturn     lmax     lmin
-------------+---------------------------------------------
         lsz |   1.0000 
         lbm |  -0.4215   1.0000 
       lturn |  -0.2948   0.1271   1.0000 
        lmax |  -0.3356   0.0539   0.5157   1.0000 
        lmin |   0.3695  -0.0873  -0.4013  -0.5864   1.0000 
*/
* ssc install egenmore
xtfmb rexcess lsz lbm six_month lturn laghc beta_capm lmax lidiovol if date>=tm(1963m8), lag(3)
outreg2 using "$code\fm6367prc5", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(R)


********* Use lmax  *************************************************
use "$datadir\data6266sample.dta", clear

keep if date>=tm(1962m1)
drop if rexcess==.
bysort date: drop if _N<100
tsset  permno date

drop if lmax==.
egen lmax_port = xtile(lmax), by(date) n(5)
 
 
* Keep only return and factors
collapse (mean) rexcess mktrf smb hml umd, by(date lmax_port)
ren rexcess exret_mean
 
replace mktrf=mktrf*100
replace smb=smb*100
replace hml=hml*100
replace umd=umd*100
 
bysort date: egen mktrf_mean=mean(mktrf)
bysort date: egen smb_mean=mean(smb)
bysort date: egen hml_mean=mean(hml)
bysort date: egen umd_mean=mean(umd)
drop mktrf smb hml umd

* 4 factor alpha
*bys lmax_port: reg exret_mean mktrf_mean smb_mean hml_mean umd_mean

reshape wide exret_mean, i(date) j(lmax_port)
 
sum exret_mean1-exret_mean5

forvalues i = 1/5 {
reg exret_mean`i'
outreg2 using  "$code\lmaxssort_6267pla1", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(uni `i')
reg exret_mean`i' mktrf_mean 
outreg2 using  "$code\lmaxssort_6267pla1", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(CAPM alpha)
reg exret_mean`i' mktrf_mean smb_mean hml_mean 
outreg2 using  "$code\lmaxssort_6267pla1", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(FF alpha)
}

gen dexret_mean = exret_mean5-exret_mean1
* raw return difference btw portfolio5 and portfolio1
reg dexret_mean
outreg2 using  "$code\lmaxssort_6267pla1", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3)  append ctitle(unih-l)
reg dexret_mean mktrf_mean 
outreg2 using  "$code\lmaxssort_6267pla1", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3)  append ctitle(CAPM alpha)
reg dexret_mean mktrf_mean smb_mean hml_mean 
outreg2 using  "$code\lmaxssort_6267pla1", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3)  append ctitle(FF alpha)

*************************** value weighted
*** about 
********* Use lmax  *************************************************
****** 5*5 portfolios 
*****first by lsz, then by lmax.
set more off
use "$datadir\data6266sample.dta", clear

keep if date>=tm(2010m1)
keep if date<=tm(2022m10)

drop if rexcess==.
tsset  permno date

drop if lsz ==.| lmax ==.
 
count
bysort date: drop if  _N<100  // make sure that each portfolio (5*5) has at least 4 stocks on avg.

tsset permno date
egen port_etp = xtile(lsz), by(date)  n(5)
 
drop if port_etp == .
egen port_var = xtile(lmax), by(date port_etp)  n(5)
 
 
* Keep only return and factors
collapse (mean) rexcess mktrf smb hml umd, by(date port_etp port_var)
ren rexcess exret_mean

 
replace mktrf=mktrf*100
replace smb=smb*100
replace hml=hml*100
replace umd=umd*100
 
bysort date: egen mktrf_mean=mean(mktrf)
bysort date: egen smb_mean=mean(smb)
bysort date: egen hml_mean=mean(hml)
bysort date: egen umd_mean=mean(umd)
drop mktrf smb hml umd

 
* Create 5*5 EW portfolio returns
reshape wide exret_mean, i(date port_var) j(port_etp)
rename exret_mean1 exret_mean1t
rename exret_mean2 exret_mean2t
rename exret_mean3 exret_mean3t
rename exret_mean4 exret_mean4t 
rename exret_mean5 exret_mean5t
reshape wide exret_mean1t exret_mean2t exret_mean3t exret_mean4t exret_mean5t, i(date) j(port_var)
 
// Create 5*5 EW portfolio returns
gen m_1a = exret_mean1t5 - exret_mean1t1
gen m_2a = exret_mean2t5 - exret_mean2t1
gen m_3a = exret_mean3t5 - exret_mean3t1
gen m_4a = exret_mean4t5 - exret_mean4t1
gen m_5a = exret_mean5t5 - exret_mean5t1

egen m_1m = rowmean(exret_mean1t1 exret_mean2t1 exret_mean3t1 exret_mean4t1 exret_mean5t1)
egen m_2m = rowmean(exret_mean1t2 exret_mean2t2 exret_mean3t2 exret_mean4t2 exret_mean5t2)
egen m_3m = rowmean(exret_mean1t3 exret_mean2t3 exret_mean3t3 exret_mean4t3 exret_mean5t3)
egen m_4m = rowmean(exret_mean1t4 exret_mean2t4 exret_mean3t4 exret_mean4t4 exret_mean5t4)
egen m_5m = rowmean(exret_mean1t5 exret_mean2t5 exret_mean3t5 exret_mean4t5 exret_mean5t5)

gen mmdid = m_5m-m_1m

sum
tsset date
 
************************************************************
forvalues i = 1/5 {
forvalues j = 1(2)5 {
reg exret_mean`i't`j'
outreg2 using  "$code\lszlmaxdsort_6267pla1", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(dou sue`i'lmax`j')
}
reg m_`i'a
outreg2 using  "$code\lszlmaxdsort_6267pla1", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(dou sue`i')
forvalues j = 1(2)5 {
reg exret_mean`i't`j' mktrf_mean smb_mean hml_mean
outreg2 using  "$code\lszlmaxdsort_6267pla1", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(dou sue`i'lmax`j' FFCPS5 alpha)
}
reg m_`i'a mktrf_mean mktrf_mean smb_mean hml_mean
outreg2 using  "$code\lszlmaxdsort_6267pla1", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(dou sue`i' FFCPS5 alpha)
}

forvalues i = 1(2)5 {
reg m_`i'm
outreg2 using "$code\lszlmaxdsort_6267pla1", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(dou lmax`i')
}
reg mmdid
outreg2 using "$code\lszlmaxdsort_6267pla1", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(dou lmax5-1)

forvalues i = 1(2)5 {
reg m_`i'm mktrf_mean smb_mean hml_mean
outreg2 using "$code\lszlmaxdsort_6267pla1", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(dou lmax`i' FFCPS5 alpha)
}
reg mmdid mktrf_mean smb_mean hml_mean
outreg2 using "$code\lszlmaxdsort_6267pla1", excel stats(coef tstat) alpha(0.01, 0.05, 0.1) symbol(***, **, *) nonotes tdec(2) rdec(3) bdec(3) append ctitle(dou lmax 5-1 FFCPS5 alpha)



/************************************************* Traditional Quantile Regression ***************************************************************/
/*
Quantile (including median) regression with                    (STB-9: sg11.1)
               bootstrapped standard errors
-------------------------------------------
*/
keep if date==tm(1966m12)
bsqreg rexcess lsz lbm six_month lturn laghc beta_capm lmax lidiovol, quantile(0.1) reps(99)
bsqreg rexcess lsz lbm six_month lturn laghc beta_capm lmax lidiovol, quantile(0.5) reps(99)
bsqreg rexcess lsz lbm six_month lturn laghc beta_capm lmax lidiovol, quantile(0.9) reps(99)
