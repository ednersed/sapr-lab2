`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// apb_master.sv - мастер шины AMBA APB (синтезируемый конечный автомат).
// ЛР2 по дисциплине "САПР", Нерсисян Э.Г., группа М3О-407Б-23, вариант 8.
//
// Пользовательская сторона (командный интерфейс):
//   cmd_valid=1 в состоянии IDLE запускает одну транзакцию с параметрами
//   cmd_write / cmd_addr / cmd_wdata. По завершении на один такт
//   выставляется cmd_done, вместе с ним действительны cmd_rdata и cmd_err.
// Сторона шины APB: SETUP (psel=1, penable=0) -> ACCESS (penable=1) ->
//   ожидание pready -> IDLE.
// -----------------------------------------------------------------------------
module apb_master
(
  input  logic        pclk,       // синхросигнал
  input  logic        presetn,    // синхронный сброс, активный уровень 0
  // командный интерфейс
  input  logic        cmd_valid,  // запрос на транзакцию
  input  logic        cmd_write,  // 1 - запись, 0 - чтение
  input  logic [31:0] cmd_addr,   // адрес
  input  logic [31:0] cmd_wdata,  // данные для записи
  output logic        cmd_ready,  // мастер свободен и примет команду
  output logic        cmd_done,   // транзакция завершена (импульс 1 такт)
  output logic [31:0] cmd_rdata,  // прочитанные данные
  output logic        cmd_err,    // слейв ответил pslverr=1
  // шина APB
  output logic        psel,
  output logic        penable,
  output logic        pwrite,
  output logic [31:0] paddr,
  output logic [31:0] pwdata,
  input  logic        pready,
  input  logic        pslverr,
  input  logic [31:0] prdata
);

  typedef enum logic [1:0] {
    M_IDLE   = 2'b00,   // шина свободна
    M_SETUP  = 2'b01,   // фаза SETUP: psel=1, penable=0
    M_ACCESS = 2'b10    // фаза ACCESS: psel=1, penable=1, ждём pready
  } m_state_t;

  m_state_t m_st;

  assign cmd_ready = (m_st == M_IDLE);

  always_ff @(posedge pclk)
    if (!presetn)
    begin
      psel      <= 1'b0;
      penable   <= 1'b0;
      pwrite    <= 1'b0;
      paddr     <= 32'h0;
      pwdata    <= 32'h0;
      cmd_done  <= 1'b0;
      cmd_rdata <= 32'h0;
      cmd_err   <= 1'b0;
      m_st      <= M_IDLE;
    end
    else
    begin
      cmd_done <= 1'b0;                 // по умолчанию импульса нет
      case (m_st)
        M_IDLE:
          if (cmd_valid)                // принять команду и начать SETUP
          begin
            psel   <= 1'b1;
            pwrite <= cmd_write;
            paddr  <= cmd_addr;
            pwdata <= cmd_write ? cmd_wdata : 32'h0;
            m_st   <= M_SETUP;
          end
        M_SETUP:
        begin
          penable <= 1'b1;              // через такт после psel - фаза ACCESS
          m_st    <= M_ACCESS;
        end
        M_ACCESS:
          if (pready)                   // слейв завершил обмен
          begin
            psel      <= 1'b0;
            penable   <= 1'b0;
            pwrite    <= 1'b0;
            cmd_done  <= 1'b1;
            cmd_err   <= pslverr;
            cmd_rdata <= pwrite ? 32'h0 : prdata;
            // synthesis translate_off
            $display("[%0d ns] APB MASTER: %s addr=0x%h data=0x%h pslverr=%b",
                     $time, pwrite ? "write" : "read ", paddr,
                     pwrite ? pwdata : prdata, pslverr);
            // synthesis translate_on
            m_st <= M_IDLE;
          end
        // coverage off
        /* verilator coverage_off */
        default:                        // неиспользуемый код 2'b11
        begin
          psel    <= 1'b0;
          penable <= 1'b0;
          m_st    <= M_IDLE;
        end
        /* verilator coverage_on */
        // coverage on
      endcase
    end

endmodule
