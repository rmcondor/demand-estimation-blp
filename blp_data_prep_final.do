********************************************************************************
** 	TITLE: BLP_dataprep.do
**
**	PURPOSE: Preparation of data for demand estimation based on Berry et al. (1996) a.k.a BLP
**				
**	AUTHORS: Ronny M. Condor
**			 Paula Armas
**			 Matias Borhi
**
**	CREATED: 
********************************************************************************

clear all			//Clear memory
cap log close		//Closes any open log files
set maxvar 10000	//Set max number of variables
set more off		//Running long code is not interrupted with ---more---
set mem 100m		//Assing additional memory if needed
set seed 170421		//Set a seed for doing anything random

*Set working directory
*global cwd  	= "M:\Mi unidad\Master Program\Cursos\Elective Courses\Econometrics Methods IO\TPs\TP3"

if "`c(username)'" == "Paula"{

 global cwd  =  "C:\Users\Paula\Mi unidad\GoodNotes\Econometría Estructural"

}

*Globals
global raw 		= "$cwd/Data/raw"
global clean 	= "$cwd/Data/clean"
global outputs	= "$cwd/Outputs"
global codes	= "$cwd/Codes"


*-------------------------------------------------------------------------------
**# 							MARKET DATA (PRODUCT)
*-------------------------------------------------------------------------------

import excel "$raw\DATA_UDESA.xlsx", sheet("DATA de Medicamentos") firstrow case(lower) clear

* Create Hausman Instrument
gen iv_hi=.
gen obs= _n
qui forvalues i = 1/`=_N' {
		summarize precio if (marca != marca[`i'] & tienda  != tienda[`i'] & semana == semana[`i'])
		local mediatemporal = r(mean)
		replace iv_hi = `mediatemporal' if obs==`i'
}
label var iv_hi "Hausman instrument (IV2)"
drop obs

*Save dataset with instruments 
save "$clean/mktdata_tienda.dta", replace
 

*Create shares variable
use "$clean/mktdata_tienda.dta", clear

bysort semana tienda: egen tot_ventas0=sum(ventas)

gen tot_ventas_true = tot_ventas0/0.64 //Calculamos manualmente el market share del bien externo

gen shares = ventas/tot_ventas_true
drop tot_ventas*



	
* Database format to pyBLP
*gen market_ids = semana, b(semana) //Cada semana es un mercado
*drop semana

rename marca product_ids //Cada marca es un producto

rename precio prices

* Create a new ID variable
sort tienda semana 
*egen market_ids = group(tienda semana)
tostring semana tienda, replace
gen market_ids = "S"+ semana+ "T" + tienda
destring semana tienda, replace

order market_ids product_ids
sort market_ids
* Create many IV variables

*Queremos tres clases de IV (además de las variables exógenas): costo, precio promedio en otros mercados de la misma semana, y precios en otros 30 mercados (que podrían ser o no de la misma semana)
*Nota: por falta de tiempo usaremos semana pero debería ser a nivel tienda-semana.
forvalues i = 1/30{
	
	gen demand_instruments`i' = .
	forvalues week = 1/48 {
	
		qui sum prices if semana != `week'
		local pmax = `r(max)'
		local pmin   = `r(min)'
		
		qui replace demand_instruments`i' = runiform(`pmin', `pmax') if semana == `week'
	}	
}
	
*	qui sum market_ids
*	local n=r(N)
*	forvalues mkt = 1/`n' {
	
*		qui sum prices if market_ids != `mkt'
*		local pmax = `r(max)'
*		local pmin   = `r(min)'
		
*		replace demand_instruments`i' = runiform(`pmin', `pmax') if market_ids == `mkt'
		
*}

	
*}

rename (costo iv_hi) (demand_instruments0 demand_instruments31)
order demand_instruments*, a(shares)
order demand_instruments31, a(demand_instruments30)

*Gen brand-ids
gen brand_ids = ., a(product_ids)
replace brand_ids = 1 if inrange(product_ids, 1, 3)
replace brand_ids = 2 if inrange(product_ids, 4, 6)
replace brand_ids = 3 if inrange(product_ids, 7, 9)
replace brand_ids = 4 if inrange(product_ids, 10, 11)

tab brand_ids, gen(d_brand)

save "$clean/mktdata.dta", replace
export delimited "$clean/mktdata.csv", replace datafmt
export delimited "$codes/mktdata.csv", replace datafmt


*-------------------------------------------------------------------------------
**# 							DEMOGRAPHIC DATA
*-------------------------------------------------------------------------------

import excel "$raw\DATA_UDESA.xlsx", sheet("Variables demograficas") firstrow case(lower) clear

keep tienda  ingreso
codebook tienda //74 unique values


merge 1:m tienda using "$clean/mktdata.dta", keep(3) keepusing(semana product_ids  market_ids) nogen //recover market id variable (only 73 markets match)

order market_ids tienda product_ids 
gsort tienda market_ids product_ids

* Collapse because the data is at market-tienda-product level y la queremos al nivel tienda-semana.

collapse (mean)  ingreso , by(market_ids) //es como tener 73 réplicas de la base inicial de demografía (con un ID por cada mercado)

expand 20 //vamos a generar 20 personas por mercado (puede ser como una muestra del total de personas)

bysort market_ids: gen person_ids = _n, a(market_ids)

*Weight of each consumer
gen weights = 0.05 //For all markets (1/20 = 0.05)

* Nodes (Warning: Not sure if it is ok!)
forvalues i = 0/4 {
	
	gen nodes`i' = rnormal(0,0.001)
	
}
* v_i, which affects preferences for brand
gen v_person=rnormal(0,1)

* Income (based on previous summary description)
gen income = runiform(9.87, 11.2)

*gen income_person=. 
*	qui sum market_ids
*	local n=r(N)
*	forvalues mkt = 1/`n' {
	
*		qui sum ingreso if market_ids == `mkt'
*		local inc_mean = `r(mean)'	
*		replace income_person=rnormal(`inc_mean', 1) if market_ids==`mkt'		
*}



gsort market_ids person_ids


save "$clean/demodata.dta", replace
export delimited "$clean/demodata.csv", replace datafmt
export delimited "$codes/demodata.csv", replace datafmt

