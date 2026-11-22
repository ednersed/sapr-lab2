# -----------------------------------------------------------------------------
# Моделирование ЛР2 в ModelSim-Altera 10.1d (Quartus II 13.0sp1).
# В ModelSim: File -> Change Directory -> C:/fpga/lab2, затем в окне Transcript:
#   do scripts/modelsim_run.do            - базовый тест (13 проверок)
#   set EXT 1; do scripts/modelsim_run.do - расширенный тест (49 проверок)
# -----------------------------------------------------------------------------
if {[info exists EXT] && $EXT} {set PLUS "+EXTENDED"} else {set PLUS ""}

quit -sim
if {[file exists work]} {vdel -lib work -all}
vlib work
vmap work work

vlog -sv -work work rtl/apb_master.sv rtl/apb_slave.sv rtl/apb_top.sv
vlog -sv -work work tb/tb_apb.sv

# -onfinish stop: по $finish симулятор останавливается, а не закрывается
eval vsim -t 1ps -onfinish stop -voptargs=+acc work.tb_apb $PLUS

# ---- окно Wave ----
add wave -noupdate -divider "Такт и сброс"
add wave -noupdate /tb_apb/pclk /tb_apb/presetn
add wave -noupdate -divider "Командный интерфейс мастера"
add wave -noupdate /tb_apb/cmd_valid /tb_apb/cmd_ready /tb_apb/cmd_write
add wave -noupdate -radix hexadecimal /tb_apb/cmd_addr /tb_apb/cmd_wdata
add wave -noupdate /tb_apb/cmd_done /tb_apb/cmd_err
add wave -noupdate -radix hexadecimal /tb_apb/cmd_rdata
add wave -noupdate -divider "Шина APB"
add wave -noupdate /tb_apb/dut/u_master/m_st
add wave -noupdate /tb_apb/dut/psel /tb_apb/dut/penable /tb_apb/dut/pwrite
add wave -noupdate -radix hexadecimal /tb_apb/dut/paddr /tb_apb/dut/pwdata
add wave -noupdate /tb_apb/dut/u_slave/apb_st
add wave -noupdate /tb_apb/dut/pready /tb_apb/dut/pslverr
add wave -noupdate -radix hexadecimal /tb_apb/dut/prdata
add wave -noupdate -divider "Регистры слейва"
add wave -noupdate -radix hexadecimal /tb_apb/dut/u_slave/register_with_some_name
add wave -noupdate -radix hexadecimal /tb_apb/dut/u_slave/reg_date
add wave -noupdate -radix hexadecimal /tb_apb/dut/u_slave/reg_surname
add wave -noupdate -radix hexadecimal /tb_apb/dut/u_slave/reg_name
if {$PLUS ne ""} {
  add wave -noupdate -divider "Блочный тест слейва (EXT 5)"
  add wave -noupdate /tb_apb/ut_psel /tb_apb/ut_penable /tb_apb/ut_pwrite
  add wave -noupdate -radix hexadecimal /tb_apb/ut_paddr /tb_apb/ut_pwdata
  add wave -noupdate /tb_apb/u_slave_ut/apb_st /tb_apb/ut_pready
  add wave -noupdate -radix hexadecimal /tb_apb/ut_prdata /tb_apb/u_slave_ut/reg_date
}
configure wave -signalnamewidth 1
configure wave -timelineunits ns

run -all
wave zoom full
