# ЛР2 «САПР»: мастер и слейв шины AMBA APB

Нерсисян Э.Г., группа М3О-407Б-23, вариант 8.

## Файлы

| Файл | Назначение |
|------|-----------|
| `rtl/apb_master.sv` | мастер APB (автомат IDLE → SETUP → ACCESS) |
| `rtl/apb_slave.sv`  | слейв APB с четырьмя 32-разрядными регистрами |
| `rtl/apb_top.sv`    | модуль верхнего уровня: мастер + слейв |
| `tb/tb_apb.sv`      | тестбенч с автоматической проверкой |
| `quartus/apb_top.sdc` | временные ограничения: pclk 50 МГц |
| `scripts/modelsim_run.do` | запуск моделирования в ModelSim |

## Карта регистров слейва

| Смещение | Регистр | Значение |
|---|---|---|
| 0x0 | `register_with_some_name` | бит 0 = 0 → `AAAA_AAAA`, бит 0 = 1 → `5555_5555` |
| 0x4 | `reg_date`    | `0x22112026` (22.11.2026) |
| 0x8 | `reg_surname` | `"Ners"` = `0x4E657273` |
| 0xC | `reg_name`    | `"Edga"` = `0x45646761` |

Другое смещение → `pslverr = 1`.

## Запуск

Quartus II 13.0sp1: проект с top-level `apb_top`, ПЛИС EP4CE115F29C7, файлы из `rtl/` и `quartus/apb_top.sdc`.

ModelSim (из корня репозитория):

```
do scripts/modelsim_run.do              # базовый тест
set EXT 1; do scripts/modelsim_run.do   # расширенный тест
```

Результат: `TEST PASSED`.
