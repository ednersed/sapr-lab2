`timescale 1ns/1ps
// -----------------------------------------------------------------------------
// tb_apb.sv - тестбенч ЛР2 (Нерсисян Э.Г., М3О-407Б-23, вариант 8).
//
// Режимы запуска:
//   без аргументов  - базовый тест (задание 1 + задание 2, 13 транзакций);
//   +EXTENDED       - базовый тест + дополнительные тесты для полного
//                     кодового покрытия (раздел «Кодовое покрытие» отчёта).
//
// Части тестбенча:
//   dut        - модуль верхнего уровня apb_top (мастер + слейв), системный тест;
//   u_slave_ut - отдельный экземпляр слейва, которым напрямую управляет
//                BFM-задачами тестбенч (для проверки прерванных транзакций).
// -----------------------------------------------------------------------------
module tb_apb;

  // ---------------- параметры варианта ----------------
  localparam logic [31:0] BASE      = 32'h7000_0000; // базовый адрес слейва
  localparam logic [31:0] GROUP_NUM = 32'd8;         // номер в списке группы
  localparam logic [31:0] DATE      = 32'h2211_2026; // 22.11.2026
  localparam logic [31:0] SURNAME4  = "Ners";        // 0x4E657273
  localparam logic [31:0] NAME4     = "Edga";        // 0x45646761
  localparam logic [31:0] PAT0      = 32'hAAAA_AAAA;
  localparam logic [31:0] PAT1      = 32'h5555_5555;

  // ---------------- такт и сброс ----------------
  logic pclk    = 1'b0;
  logic presetn = 1'b0;                              // сброс активен с момента 0
  always #10 pclk = ~pclk;                           // период 20 нс (50 МГц)

  // ---------------- системный тест: apb_top ----------------
  logic        cmd_valid = 1'b0, cmd_write = 1'b0;
  logic [31:0] cmd_addr  = '0,   cmd_wdata = '0;
  logic        cmd_ready, cmd_done, cmd_err;
  logic [31:0] cmd_rdata;

  apb_top dut
  (
    .pclk(pclk), .presetn(presetn),
    .cmd_valid(cmd_valid), .cmd_write(cmd_write), .cmd_addr(cmd_addr), .cmd_wdata(cmd_wdata),
    .cmd_ready(cmd_ready), .cmd_done(cmd_done), .cmd_rdata(cmd_rdata), .cmd_err(cmd_err)
  );

  // ---------------- блочный тест слейва ----------------
  logic        ut_psel = 1'b0, ut_penable = 1'b0, ut_pwrite = 1'b0;
  logic [31:0] ut_paddr = '0, ut_pwdata = '0;
  logic        ut_pready, ut_pslverr;
  logic [31:0] ut_prdata;

  apb_slave u_slave_ut
  (
    .pclk(pclk), .presetn(presetn),
    .paddr(ut_paddr), .pwdata(ut_pwdata), .psel(ut_psel),
    .penable(ut_penable), .pwrite(ut_pwrite),
    .pready(ut_pready), .pslverr(ut_pslverr), .prdata(ut_prdata)
  );

  // ---------------- счётчики и модель ----------------
  int          errors = 0;
  int          checks = 0;
  logic [31:0] rd;
  logic        err;

  // Эталонная модель регистров слейва (для самопроверки)
  logic [31:0] model [0:3];

  function automatic logic [31:0] model_after_write(logic [7:0] off, logic [31:0] d,
                                                    logic [31:0] old);
    if (off == 8'h00) return d[0] ? PAT1 : PAT0;
    return d;
  endfunction

  // Все воздействия тестбенча выставляются и все выходы DUT опрашиваются
  // по СПАДУ pclk, а DUT работает по фронту - так исключаются гонки
  // между тестбенчем и проектом (результат не зависит от симулятора).

  // ---------------- задачи системного теста ----------------
  // Одна транзакция через командный интерфейс мастера
  task automatic do_cmd(input logic wr, input logic [31:0] addr, input logic [31:0] wdata,
                        output logic [31:0] rdata, output logic error);
    while (!cmd_ready) @(negedge pclk);
    cmd_valid <= 1'b1;
    cmd_write <= wr;
    cmd_addr  <= addr;
    cmd_wdata <= wdata;
    @(negedge pclk);
    cmd_valid <= 1'b0;
    do @(negedge pclk); while (!cmd_done);
    rdata = cmd_rdata;
    error = cmd_err;
  endtask

  task automatic apb_write(input logic [31:0] addr, input logic [31:0] data,
                           input logic exp_err = 1'b0);
    logic [31:0] dummy;
    do_cmd(1'b1, addr, data, dummy, err);
    checks++;
    if (err !== exp_err) begin
      errors++;
      $display("CHECK FAIL write addr=0x%h pslverr=%b expected %b", addr, err, exp_err);
    end else if (exp_err)
      $display("CHECK OK   write addr=0x%h -> PSLVERR=1 (as expected)", addr);
    if (!exp_err) begin
      logic [7:0] off = addr[7:0];
      model[off[3:2]] = model_after_write(off, data, model[off[3:2]]);
    end
  endtask

  task automatic apb_read_check(input logic [31:0] addr, input logic [31:0] expected,
                                input logic exp_err = 1'b0);
    do_cmd(1'b0, addr, '0, rd, err);
    checks++;
    if (rd === expected && err === exp_err)
      $display("CHECK OK   read  addr=0x%h data=0x%h pslverr=%b", addr, rd, err);
    else begin
      errors++;
      $display("CHECK FAIL read  addr=0x%h data=0x%h (exp 0x%h) pslverr=%b (exp %b)",
               addr, rd, expected, err, exp_err);
    end
  endtask

  task automatic do_reset(input int cycles);
    presetn <= 1'b0;
    repeat (cycles) @(negedge pclk);
    presetn <= 1'b1;
    @(negedge pclk);
    model[0] = '0; model[1] = '0; model[2] = '0; model[3] = '0;
  endtask

  // ---------------- задачи блочного теста слейва (BFM) ----------------
  // Транзакция, которую мастер прерывает: после SETUP снимается psel
  task automatic ut_aborted(input logic wr, input logic [31:0] addr);
    @(negedge pclk);
    ut_psel <= 1'b1; ut_pwrite <= wr; ut_paddr <= addr; ut_pwdata <= 32'hDEAD_BEEF;
    @(negedge pclk);                       // SETUP: слейв перешёл в *_ENABLE
    ut_psel <= 1'b0; ut_pwrite <= 1'b0;    // мастер отказался от обмена
    @(negedge pclk);
    @(negedge pclk);
    checks++;
    if (u_slave_ut.apb_st !== 2'b00 /* APB_SETUP */ || ut_pready !== 1'b0) begin
      errors++;
      $display("CHECK FAIL slave did not return to SETUP after abort");
    end else
      $display("CHECK OK   slave returned to SETUP after aborted %s", wr ? "write" : "read ");
  endtask

  // Транзакция с удлинённой фазой SETUP (penable поднимается на такт позже):
  // слейв должен дождаться penable и выполнить обмен.
  // wr=1 - запись data по адресу addr, wr=0 - чтение и сравнение с data.
  task automatic ut_slow(input logic wr, input logic [31:0] addr, input logic [31:0] data);
    logic [31:0] got;
    @(negedge pclk);
    ut_psel <= 1'b1; ut_pwrite <= wr; ut_paddr <= addr; ut_pwdata <= wr ? data : '0;
    @(negedge pclk);
    @(negedge pclk);                       // лишний такт без penable
    ut_penable <= 1'b1;
    do @(negedge pclk); while (!ut_pready);
    got = ut_prdata;
    ut_psel <= 1'b0; ut_penable <= 1'b0; ut_pwrite <= 1'b0;
    @(negedge pclk);
    if (wr) got = u_slave_ut.reg_date;
    checks++;
    if (got !== data) begin
      errors++;
      $display("CHECK FAIL slow %s: data=0x%h expected 0x%h", wr ? "write" : "read ", got, data);
    end else
      $display("CHECK OK   slow %s accepted, data=0x%h", wr ? "write" : "read ", got);
  endtask

  // ---------------- основной сценарий ----------------
  initial begin
    $dumpfile("tb_apb.vcd");
    $dumpvars(0, tb_apb);

    repeat (3) @(negedge pclk);
    do_reset(5);
    repeat (3) @(negedge pclk);

    $display("==== BASE TEST: task 2 (variant 8) ====");
    apb_write(BASE + 32'h0, GROUP_NUM);
    apb_write(BASE + 32'h4, DATE);
    apb_write(BASE + 32'h8, SURNAME4);
    apb_write(BASE + 32'hC, NAME4);
    apb_read_check(BASE + 32'h0, PAT0);          // 8 - чётное, бит 0 = 0
    apb_read_check(BASE + 32'h4, DATE);
    apb_read_check(BASE + 32'h8, SURNAME4);
    apb_read_check(BASE + 32'hC, NAME4);
    $display("ASCII: surname=\"%s\" name=\"%s\"", SURNAME4, NAME4);

    $display("==== BASE TEST: task 1 (bit 0 rule of register 0x0) ====");
    apb_write(BASE + 32'h0, 32'h1234_5678);      // бит 0 = 0
    apb_read_check(BASE + 32'h0, PAT0);
    apb_write(BASE + 32'h0, 32'h0000_0001);      // бит 0 = 1
    apb_read_check(BASE + 32'h0, PAT1);
    apb_write(BASE + 32'h10, 32'h0, 1'b1);       // неверный адрес

    if ($test$plusargs("EXTENDED")) begin
      $display("==== EXT 1: read from bad offsets ====");
      apb_read_check(BASE + 32'h10, 32'h0, 1'b1);
      apb_read_check(BASE + 32'hFC, 32'h0, 1'b1);
      apb_read_check(BASE + 32'h1,  32'h0, 1'b1);  // невыровненный адрес
      apb_write     (BASE + 32'h6,  32'h1, 1'b1);

      $display("==== EXT 2: all-ones / all-zeros patterns (toggle) ====");
      foreach (model[i]) begin
        apb_write     (32'hFFFF_FF00 + 4*i, 32'hFFFF_FFFF);   // старшие биты адреса = 1
        apb_read_check(32'hFFFF_FF00 + 4*i, model[i]);
        apb_write     (32'h0000_0000 + 4*i, 32'h0000_0000);   // старшие биты адреса = 0
        apb_read_check(32'h0000_0000 + 4*i, model[i]);
      end

      $display("==== EXT 3: reset during transaction ====");
      apb_write(BASE + 32'h4, DATE);
      fork
        begin
          while (!cmd_ready) @(negedge pclk);
          cmd_valid <= 1'b1; cmd_write <= 1'b1;
          cmd_addr  <= BASE + 32'h8; cmd_wdata <= SURNAME4;
          @(negedge pclk); cmd_valid <= 1'b0;
        end
        begin
          repeat (2) @(negedge pclk);           // мастер в фазе ACCESS
          do_reset(2);
        end
      join
      checks++;
      if (dut.u_master.psel !== 1'b0 || dut.u_slave.reg_date !== 32'h0 || cmd_ready !== 1'b1) begin
        errors++; $display("CHECK FAIL reset during transaction");
      end else
        $display("CHECK OK   reset during transaction: bus idle, registers cleared");
      apb_read_check(BASE + 32'h4, 32'h0);
      apb_read_check(BASE + 32'h8, 32'h0);

      $display("==== EXT 4: back-to-back transactions after reset ====");
      apb_write(BASE + 32'h0, GROUP_NUM);
      apb_write(BASE + 32'h4, DATE);
      apb_write(BASE + 32'h8, SURNAME4);
      apb_write(BASE + 32'hC, NAME4);
      apb_read_check(BASE + 32'h0, PAT0);
      apb_read_check(BASE + 32'h4, DATE);
      apb_read_check(BASE + 32'h8, SURNAME4);
      apb_read_check(BASE + 32'hC, NAME4);

      $display("==== EXT 5: slave unit test (aborted and slow transfers) ====");
      ut_aborted(1'b1, 32'h4);
      ut_aborted(1'b0, 32'h4);
      ut_slow(1'b1, 32'h4, DATE);
      ut_slow(1'b0, 32'h4, DATE);
    end

    repeat (5) @(negedge pclk);
    $display("==== SUMMARY: %0d checks, %0d errors ====", checks, errors);
    if (errors == 0) $display("TEST PASSED");
    else             $display("TEST FAILED");
    $finish;
  end

  // Защита от зависания
  initial begin
    #200us;
    $display("TIMEOUT");
    $finish;
  end

endmodule
