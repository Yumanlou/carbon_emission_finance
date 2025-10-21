clear all
version 17.0

* --- 【请务必修改!】 ---
* 请将下方路径修改为您希望存放结果Excel文件的【文件夹路径】
cd "/Users/yumanlou/Library/CloudStorage/OneDrive-email.cufe.edu.cn/2025/第五学期/论文/ESG/carbon_emission_finance/"
global output_path "/Users/yumanlou/Library/CloudStorage/OneDrive-email.cufe.edu.cn/2025/第五学期/论文/ESG/carbon_emission_finance/charts/corr/" 

* --- 【请务必修改!】 ---
* 请将下方路径修改为您存放最终数据文件的【文件夹路径+文件名】
use "/Users/yumanlou/Library/CloudStorage/OneDrive-email.cufe.edu.cn/2025/第五学期/论文/ESG/carbon_emission_finance/data/final_data.1.3.4_did.dta", clear 

local financial_indicators "credit bond investment insurance equity fund carbon_finance green_invention_patents green_utility_patents"
pwcorr `financial_indicators', star(.1)
asdoc correlate `financial_indicators', save("corr") replace dec(3) star


* // ======================== 分析结束 ======================== //
di ""
di "------------------------------------------------------------"
di "               相关系数矩阵已生成！"
di "------------------------------------------------------------"
di "请到您的工作目录中查找名为 'corr_matrix.xls' 的Excel文件。"
di "工作目录路径: /Users/yumanlou/Desktop/" 
di "------------------------------------------------------------"
di ""
