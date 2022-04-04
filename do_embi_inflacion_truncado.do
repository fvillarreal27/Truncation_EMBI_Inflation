*** EMBI e Inflacion truncada

// Directorio
* -----------------------------------------------------------------------------*
if  c(username) == "kamilaaguirresoria" {
	global dir "/Users/kamilaaguirresoria/Dropbox/BCE/Tasas de interes/Tasa Equilibrio"
	cd "$dir"
}
							
else {
	global dir "C:/Users/fvill/Dropbox/BCE/Tasas de interes/Tasa Equilibrio"
	cd "$dir"
} 
* -----------------------------------------------------------------------------*

// Coloeres
global c1 "68 114 196" 		// azul
global c2 "237 125 49" 		// naranja
global c3 "165 165 165" 	// gris
global c4 "255 192 0" 		// amarillo
global c5 "91 155 213" 		// celeste
global c6 "112 173 71" 		// verde
global c7 "68 84 106" 		// azul-gris
global c8 "249 192 202" 	// rose
global c9 "199 194 186" 	// light grey



// Datos EMBI
import excel "$dir/Datos/BCE/Riesgo_País.xlsx", sheet("Indicador") firstrow clear

* Tratamiento
keep E F

drop if E == ""

nrow 1

gen fecha = date(Fecha, "DMY")
format fecha %td

rename F embi
destring embi, replace
format embi %20.0f

keep embi fecha
sort fecha

gen mes = mofd(fecha)
format mes %tm
order mes fecha 

* EMBI promedio por mes
gcollapse (mean) embi, by(mes)
tsset mes

drop if mes < tm(2005m1)

sum mes
global pmin = r(min)
global pmax = r(max)

gen year=year(dofm(mes))

// Truncar datos

* Truncar dos deciles superiores desde enero 2005. El techo se actualiza cada mes
sum mes
global mes_min = r(min)
global mes_max = r(max)

forvalues i = $mes_min/$mes_max {
	egen p80_`i' = pctile(embi) if inrange(mes, ${mes_min}, `i'), p(80) // percentil 80 mes a mes
		replace p80_`i' = p80_`i'[_n-1] if p80_`i' == .
	sum p80_`i'
	global rp80_`i' = r(mean)
}

* Estimar la Prima de Riesgo (EMBI hasta el percentil 80)
capture drop prima_riesgo
gen double prima_riesgo = embi

forvalues i = $mes_min/$mes_max {
	replace prima_riesgo = ${rp80_`i'} if prima_riesgo > ${rp80_`i'} & mes == `i' // Truncar
}

gen double prima_riesgo_pb = prima_riesgo
replace prima_riesgo = prima_riesgo / 10000 // No en porcentaje

// Grafico EMBI 
format embi prima_riesgo_pb %20.0fc

* Percentil 80 consolidado
gen double embi_rp80 = .

forvalues i = $mes_min/$mes_max {
	replace embi_rp80 = p80_`i' if mes == `i'
}

twoway tsline embi, lcolor("${c1}%40") /// 	
	|| tsline embi_rp80, lcolor("${c2}") lpattern(shortdash) /// 
	|| tsline prima_riesgo_pb, lcolor("${c1}") /// 
	name("embi_80", replace) /// 
	graphregion(fcolor(white) color(white)) /// 
	legend(order(1 2 3) label(1 "EMBI") label(2 "Percentil 80 EMBI") label(3 "Prima de Riesgo") region(lcolor(white)) rows(1) size(vsmall)) /// 
	yscale(lcolor(white)) xscale(lcolor(white)) /// 
	ytitle("Puntos base", size(vsmall) height(6)) /// 
	ylabel(, nogrid tlcolor(gs8) angle(horizontal) labsize(vsmall)) /// 
	xtitle("") /// 
	xlabel(${pmin}(10)${pmax}, tlcolor(gs8) labsize(vsmall) angle(90))
graph export "$dir/Graficos/graph_embi_80.png", name("embi_80") as(png) width(960) height(576) replace	

keep mes embi embi_rp80 prima_riesgo_pb prima_riesgo
order mes embi embi_rp80 prima_riesgo_pb prima_riesgo

* Base	
tempfile prima_riesgo
save `prima_riesgo', replace



// Datos Inflacion
import delimited "$dir/Datos/INEC/1. ÍNDICE.csv", clear 

* Tratamiento
drop in 1/3

nrow 1

drop if Enero == ""

quietly describe, varlist
local varlist=r(varlist)
foreach var in `varlist' {
	destring `var', replace
}

rename  (MESES Enero Febrero Marzo Abril Mayo Junio Julio Agosto Septiembre Octubre Noviembre Diciembre) /// 
		(year ipc1 ipc2 ipc3 ipc4 ipc5 ipc6 ipc7 ipc8 ipc9 ipc10 ipc11 ipc12)

greshape long ipc, i(year) j(month)

gen mes = ym(year, month)
format mes %tm

drop year month
order mes

drop if ipc == .

* Inflacion interanual
tsset mes, monthly
gen double infl = (ipc - L12.ipc) / L12.ipc

drop if mes < tm(2005m1)

// Truncar datos

* Truncar dos deciles superiores desde enero 2005. El techo se actualiza cada mes
sum mes
global mes_min = r(min)
global mes_max = r(max)

forvalues i = $mes_min/$mes_max {
	egen p80_`i' = pctile(infl) if inrange(mes, ${mes_min}, `i'), p(80) // percentil 80 mes a mes
		replace p80_`i' = p80_`i'[_n-1] if p80_`i' == .
	sum p80_`i'
	global rp80_`i' = r(mean)
}

* Estimar la Inflacion truncada (Inflacion hasta el percentil 80)
capture drop infl_trunc
gen double infl_trunc = infl

forvalues i = $mes_min/$mes_max {
	replace infl_trunc = ${rp80_`i'} if infl_trunc > ${rp80_`i'} & mes == `i' // Truncar
}

// Inflacion interanual t-1
gen double infl_lag1 = L.infl_trunc
gen double infl_l1 = L.infl

// Grafico

* Percentil 80 consolidado
gen double infl_rp80 = .

forvalues i = $mes_min/$mes_max {
	replace infl_rp80 = p80_`i' if mes _== `i'
}

twoway tsline infl, lcolor("${c1}%40") /// 	
	|| tsline infl_rp80, lcolor("${c2}") lpattern(shortdash) /// 
	|| tsline infl_trunc, lcolor("${c1}") /// 
	name("infl_p80", replace) /// 
	graphregion(fcolor(white) color(white)) /// 
	legend(order(1 2 3) label(1 "Inflación") label(2 "Percentil 80 Inflación") label(3 "Inflación truncada") region(lcolor(white)) rows(1) size(vsmall)) /// 
	yscale(lcolor(white)) xscale(lcolor(white)) /// 
	ytitle("", size(vsmall)) /// 
	ylabel(, nogrid tlcolor(gs8) angle(horizontal) labsize(vsmall) format(%9.2f)) /// 
	xtitle("") /// 
	xlabel(${pmin}(10)${pmax}, tlcolor(gs8) labsize(vsmall) angle(90)) /// 
	yline(0, lcolor(red) lpattern(shortdash))
graph export "$dir/Graficos/graph_infl_p80.png", name("infl_p80") as(png) width(960) height(576) replace	

keep mes infl infl_l1 infl_rp80 infl_trunc infl_lag1
order mes infl infl_l1 infl_rp80 infl_trunc infl_lag1

* Base	
tempfile inflacion
save `inflacion', replace



// Union bases: Prima de Riesgo e Inflacion
use `prima_riesgo', clear

merge 1:1 mes using `inflacion'
drop _merge

// Componente de Costo de Capital: Prima de riesgo + Inflacion interanual t-1
gen double priesgo_inf = prima_riesgo + infl_lag1

* Exportar datos
preserve

	rename infl_lag1 infl_trunc_l1
	keep mes embi prima_riesgo infl_l1 infl_trunc_l1 priesgo_inf
	export excel "$dir/Datos/Procesados/datos_prima_riesgo.xlsx", firstrow(variables) sheet("EMBI_Inflacion", modify) keepcellfmt

restore

keep mes priesgo_inf

save "$dir/Datos/Procesados/datos_prima_riesgo.dta", replace
