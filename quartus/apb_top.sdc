# Временные ограничения ЛР2: тактовый сигнал pclk 50 МГц (период 20 нс)
create_clock -name pclk -period 20.000 [get_ports {pclk}]
derive_clock_uncertainty
