`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// apb_slave.sv - слейв шины AMBA APB с четырьмя 32-разрядными регистрами.
// ЛР2 по дисциплине "САПР", Нерсисян Э.Г., группа М3О-407Б-23, вариант 8.
//
// Карта регистров (смещение = paddr[7:0]):
//   0x0  register_with_some_name - при записи pwdata[0]=0 хранит 32'hAAAA_AAAA,
//                                  при записи pwdata[0]=1 хранит 32'h5555_5555
//   0x4  reg_date    - дата в формате дд.мм.гггг (8 hex-цифр)
//   0x8  reg_surname - первые 4 буквы фамилии (ASCII)
//   0xC  reg_name    - первые 4 буквы имени (ASCII)
// Обращение по любому другому смещению завершается с pslverr = 1.
// -----------------------------------------------------------------------------
module apb_slave
(
  input  logic        pclk,     // синхросигнал
  input  logic        presetn,  // синхронный сброс, активный уровень 0
  input  logic [31:0] paddr,    // адрес обращения
  input  logic [31:0] pwdata,   // данные для записи
  input  logic        psel,     // признак выбора устройства
  input  logic        penable,  // признак фазы ACCESS
  input  logic        pwrite,   // 1 - запись, 0 - чтение
  output logic        pready,   // готовность слейва (завершение обмена)
  output logic        pslverr,  // ошибка обращения (неверный адрес)
  output logic [31:0] prdata    // прочитанные данные
);

  localparam [31:0] PATTERN_0 = 32'hAAAA_AAAA; // бит 0 записи = 0
  localparam [31:0] PATTERN_1 = 32'h5555_5555; // бит 0 записи = 1

  logic [31:0] register_with_some_name; // смещение 0x0
  logic [31:0] reg_date;     // смещение 0x4
  logic [31:0] reg_surname;  // смещение 0x8
  logic [31:0] reg_name;     // смещение 0xC

  // Состояния конечного автомата протокола APB
  typedef enum logic [1:0] {
    APB_SETUP    = 2'b00,    // ожидание фазы SETUP (psel=1, penable=0)
    APB_W_ENABLE = 2'b01,    // фаза ACCESS записи
    APB_R_ENABLE = 2'b10     // фаза ACCESS чтения
  } apb_state_t;

  apb_state_t apb_st;

  always_ff @(posedge pclk)
    if (!presetn)
    begin
      prdata      <= 32'h0;
      pslverr     <= 1'b0;
      pready      <= 1'b0;
      register_with_some_name <= 32'h0;
      reg_date    <= 32'h0;
      reg_surname <= 32'h0;
      reg_name    <= 32'h0;
      apb_st      <= APB_SETUP;
    end
    else
    begin
      case (apb_st)
        // ------------------------------------------------------------------
        APB_SETUP:
        begin: apb_setup_st
          prdata  <= 32'h0;     // данные чтения действительны только с pready
          pready  <= 1'b0;
          pslverr <= 1'b0;   // ошибка прошлой транзакции сбрасывается
          if (psel && !penable)            // мастер начал фазу SETUP
          begin
            if (pwrite) apb_st <= APB_W_ENABLE;
            else        apb_st <= APB_R_ENABLE;
          end
        end: apb_setup_st
        // ------------------------------------------------------------------
        APB_W_ENABLE:
        begin: apb_w_en_st
          if (psel && penable && pwrite)   // фаза ACCESS записи
          begin
            pready <= 1'b1;
            case (paddr[7:0])
              8'h00: begin
                if (pwdata[0] == 1'b0) register_with_some_name <= PATTERN_0;
                else                   register_with_some_name <= PATTERN_1;
                // synthesis translate_off
                $display("[%0d ns] APB SLAVE: WRITE 0x0 data=0x%h -> register_with_some_name=0x%h",
                         $time, pwdata, pwdata[0] ? PATTERN_1 : PATTERN_0);
                // synthesis translate_on
              end
              8'h04: begin
                reg_date <= pwdata;
                // synthesis translate_off
                $display("[%0d ns] APB SLAVE: WRITE 0x4 data=0x%h (date %h.%h.%h)",
                         $time, pwdata, pwdata[31:24], pwdata[23:16], pwdata[15:0]);
                // synthesis translate_on
              end
              8'h08: begin
                reg_surname <= pwdata;
                // synthesis translate_off
                $display("[%0d ns] APB SLAVE: WRITE 0x8 data=0x%h (surname)",
                         $time, pwdata);
                // synthesis translate_on
              end
              8'h0C: begin
                reg_name <= pwdata;
                // synthesis translate_off
                $display("[%0d ns] APB SLAVE: WRITE 0xC data=0x%h (name)",
                         $time, pwdata);
                // synthesis translate_on
              end
              default: begin
                pslverr <= 1'b1;             // несуществующий регистр
                // synthesis translate_off
                $display("[%0d ns] APB SLAVE: WRITE ERROR, bad offset 0x%h",
                         $time, paddr[7:0]);
                // synthesis translate_on
              end
            endcase
            apb_st <= APB_SETUP;
          end
          else if (!psel)                  // мастер прервал обмен
          begin
            // synthesis translate_off
            $display("[%0d ns] APB SLAVE: write aborted by master", $time);
            // synthesis translate_on
            apb_st <= APB_SETUP;
          end
        end: apb_w_en_st
        // ------------------------------------------------------------------
        APB_R_ENABLE:
        begin: apb_r_en_st
          if (psel && penable && !pwrite)  // фаза ACCESS чтения
          begin
            pready <= 1'b1;
            case (paddr[7:0])
              8'h00: prdata <= register_with_some_name;
              8'h04: prdata <= reg_date;
              8'h08: prdata <= reg_surname;
              8'h0C: prdata <= reg_name;
              default: pslverr <= 1'b1;    // несуществующий регистр
            endcase
            // synthesis translate_off
            case (paddr[7:0])
              8'h00, 8'h04, 8'h08, 8'h0C:
                $display("[%0d ns] APB SLAVE: READ  0x%h data=0x%h", $time, paddr[7:0],
                         paddr[3:2] == 2'd0 ? register_with_some_name :
                         paddr[3:2] == 2'd1 ? reg_date :
                         paddr[3:2] == 2'd2 ? reg_surname : reg_name);
              default:
                $display("[%0d ns] APB SLAVE: READ ERROR, bad offset 0x%h",
                         $time, paddr[7:0]);
            endcase
            // synthesis translate_on
            apb_st <= APB_SETUP;
          end
          else if (!psel)                  // мастер прервал обмен
          begin
            // synthesis translate_off
            $display("[%0d ns] APB SLAVE: read aborted by master", $time);
            // synthesis translate_on
            apb_st <= APB_SETUP;
          end
        end: apb_r_en_st
        // ------------------------------------------------------------------
        // Код 2'b11 не используется; автомат из него возвращается в SETUP.
        // coverage off
        /* verilator coverage_off */
        default:
        begin
          pslverr <= 1'b1;
          apb_st  <= APB_SETUP;
        end
        /* verilator coverage_on */
        // coverage on
      endcase
    end

endmodule
