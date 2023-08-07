********************************************************************************
** 	TITLE: BLP_dataprep.do
**
**	PURPOSE: Preparation of data for demand estimation based on Berry et al. (1996) a.k.a BLP
**				
**	AUTHORS: Matias Borhi
**			 Paula Armas
**			 Ronny M. Condor
**
**	CREATED: 
********************************************************************************

clear all			//Clear memory
cap log close		//Closes any open log files
set maxvar 10000	//Set max number of variables
set more off		//Running long code is not interrupted with ---more---
set mem 100m		//Assing additional memory if needed
set seed 170421		//Set a seed for doing anything random

*Ejercicio 3

clear all 
set more off
global main "/Users/matiasborhi/Documents/Maestria /Metodos Econometricos/TP 3"
cd "$main"
import excel DATA_UDESA, firstrow

set matsize 10000

order semana marca tienda
gsort semana marca tienda

bysort semana tienda: egen tot_ventas0=sum(ventas)

gen tot_ventas_true = tot_ventas0/0.64  

gen market_share = ventas/tot_ventas_true
drop tot_ventas*

g delta=.
replace delta= log(market_share)-log(0.36) 

*Ejercicio 3: Modelos Logit

*1
reg delta precio descuento, nocons
scalar alphahat1 = _b[precio]
outreg2 using "Tabla_Punto_3.tex", dec(3) 

*2
reg delta precio descuento i.marca, nocons
scalar alphahat2 = _b[precio]
outreg2 using "Tabla_Punto_3.tex", dec(3) drop(i.marca)

*3
reg delta precio descuento i.marca#i.tienda, nocons 
scalar alphahat3 = _b[precio]
outreg2 using "Tabla_Punto_3.tex", dec(3) drop(i.marca#i.tienda)

*4
ivregress 2sls delta descuento (precio=costo), first nocons
outreg2 using "Tabla_Punto_3.tex", dec(3) 

ivregress 2sls delta descuento i.marca  (precio=costo), first nocons
outreg2 using "Tabla_Punto_3.tex", dec(3) drop(i.marca)

ivregress 2sls delta descuento i.marca#i.tienda (precio=costo), first nocons
outreg2 using "Tabla_Punto_3.tex", dec(3) drop(i.marca#i.tienda)

*5
gen iv_hi=.
gen obs= _n
set more off
qui forvalues i = 1/`=_N' {
		summarize precio if (marca != marca[`i'] & tienda  != tienda[`i'] & semana == semana[`i'])
		local mediatemporal = r(mean)
		replace iv_hi = `mediatemporal' if obs==`i'
}
label var iv_hi "Hausman instrument (IV2)

ivregress 2sls delta descuento (precio=iv_hi), first nocons
outreg2 using "Tabla_Punto_3.tex", dec(3) 

ivregress 2sls delta descuento i.marca  (precio=iv_hi), first nocons
outreg2 using "Tabla_Punto_3.tex", dec(3) drop(i.marca)

ivregress 2sls delta descuento i.marca#i.tienda (precio=iv_hi), first nocons
outreg2 using "Tabla_Punto_3.tex", dec(3) drop(i.marca#i.tienda)

*6
gen precio_mshare = precio*(1-market_share)
gen elasticidad1 = precio_mshare*alphahat1
gen elasticidad2 = precio_mshare*alphahat2
gen elasticidad3 = precio_mshare*alphahat3

latabstat elasticidad1 elasticidad2 elasticidad3, stat(mean) by(marca) 


*Ejercicio 5: Fusion


mergersim init, marca (1 2 3) 
mergersim simulate if semana == 10 & tienda == 9, marca(1) marca(2) marca(3) detail

*Ejercicio 5: Fusion

*Fijamos Panel Data
egen semanatienda=group( semana tienda ), label 
xtset marca semanatienda

*Creamos variable para definir la fusion entre 1,2,3
gen newfirm=marca
replace newfirm=1 if marca==2
replace newfirm=1 if marca==3

gen newfirm2=marca
replace newfirm2=1 if marca==2
replace newfirm2=1 if marca==3
replace newfirm2=1 if marca==4
replace newfirm2=1 if marca==5
replace newfirm2=1 if marca==6
replace newfirm2=1 if marca==7
replace newfirm2=1 if marca==8
replace newfirm2=1 if marca==9

*Simulaciones
set more off
mergersim init, nests(marca) price(precio) quantity(ventas) marketsize(cantidad) firm(marca)
xtreg M_ls precio M_lsjg descuento semana tienda  market_share, fe 
mergersim market if semana == 10
mergersim simulate if semana == 10 & tienda == 9, newfirm(newfirm) detail

*SimulacionesII
set more off
mergersim init, nests(marca) price(precio) quantity(ventas) marketsize(cantidad) firm(marca)
xtreg M_ls precio M_lsjg descuento semana tienda  market_share, fe 
mergersim market if semana == 10
mergersim simulate if semana == 10 & tienda == 9, newfirm(newfirm2) detail
