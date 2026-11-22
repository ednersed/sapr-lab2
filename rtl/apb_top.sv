`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// apb_top.sv - модуль верхнего уровня: мастер APB + слейв APB.
// ЛР2 по дисциплине "САПР", Нерсисян Э.Г., группа М3О-407Б-23, вариант 8.
// Наружу выведен только командный интерфейс мастера; шина APB внутренняя.
// Модуль синтезируется в Quartus (top-level entity = apb_top).
// -----------------------------------------------------------------------------
module apb_top
(
  input  logic        pclk,
  input  logic        presetn,
  input  logic        cmd_valid,
  input  logic        cmd_write,
  input  logic [31:0] cmd_addr,
  input  logic [31:0] cmd_wdata,
  output logic        cmd_ready,
  output logic        cmd_done,
  output logic [31:0] cmd_rdata,
  output logic        cmd_err
);

  // внутренняя шина APB
  logic        psel, penable, pwrite, pready, pslverr;
  logic [31:0] paddr, pwdata, prdata;

  apb_master u_master
  (
    .pclk(pclk), .presetn(presetn),
    .cmd_valid(cmd_valid), .cmd_write(cmd_write), .cmd_addr(cmd_addr), .cmd_wdata(cmd_wdata),
    .cmd_ready(cmd_ready), .cmd_done(cmd_done), .cmd_rdata(cmd_rdata), .cmd_err(cmd_err),
    .psel(psel), .penable(penable), .pwrite(pwrite), .paddr(paddr), .pwdata(pwdata),
    .pready(pready), .pslverr(pslverr), .prdata(prdata)
  );

  apb_slave u_slave
  (
    .pclk(pclk), .presetn(presetn),
    .paddr(paddr), .pwdata(pwdata), .psel(psel), .penable(penable), .pwrite(pwrite),
    .pready(pready), .pslverr(pslverr), .prdata(prdata)
  );

endmodule
