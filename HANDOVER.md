# HANDOVER — памятка для следующей сессии агента (и для владельца)

Если ты — новая сессия Arena-агента в этом репозитории: **не работай от master** —
он почти пустой (снапшот пра-истории). Вся актуальная база в ветке:

```
git fetch origin arena/019f6cb8-drstrasse
git reset --hard FETCH_HEAD   # в своей рабочей ветке сессии
```

После этого прочитай `README.md` (реестр файлов и модулей) и `ANALYSIS.md`
(находки 1–77 — там вся история разработки и уроки, НЕ повторяй старые ошибки).

## Где что лежит
- `lua/` — весь код (основные модули ядра + `grm_single_addon (4)` + двери v2.0.3 + FFD Fading Door + FFD Keypad).
- Ключевые:
  - Код 42 `lua/autorun/sh_grm_currency.lua` (валюта **v2.0.2**),
  - Код 43 `lua/autorun/sh_grm_economy.lua` (экономика **v3.0.3**, банк, зеркало `grm_bank_nicks.json`),
  - Код 50 `lua/autorun/sh_grm_perm_entities.lua` (пермы энтити **v1.1.0** с поддержкой CCTV и АТС/сигнализаций),
  - Коды 51–54 (CCTV видеонаблюдение),
  - Коды 55–58 (Сигнализации),
  - Коды 59–60 (Система розыска Wanted),
  - Коды 61–62 (`sh_grm_doors.lua` v2.0.3 и `sh_grm_doors_access.lua` v2.1.0),
  - Коды 63–64 (RP Чат & EasyChat),
  - Код 65 (`grm_item_drop` и команда `/drop`),
  - Код 66 (`ds_key_swep` — дверные ключи),
  - Код 67 (`ds_battering_ram` — полицейский таран),
  - Код 68 (`ds_lockpick` — QTE-отмычка),
  - Код 69 (`ffd_fading_door` — исчезающие двери с нумпадом и таймером),
  - Код 70 (`grm_keypad` & `ffd_keypad` — кодовый замок с 3D2D дисплеем, PIN, фракционным и платным доступом).
- `dist/` — готовые zip для владельца (`grm_single_addon.zip`, `grm_economy.zip`, `grm_fix_hud_tab_currency.zip`, `grm_full_code.zip`).
  Владелец качает по raw-линкам на ветке — **ветку не удалять**.
- `tools/luatest/roundtrip_test.lua` — мок GMod API + 13 фаз юнит-теста персистентности. Обязателен к прогону после любой правки ядра.
- `tools/glua_check.py` — синтаксический чекер GLua.
- `tools/build_dist.py` — автосборка всех 4 архивов дистрибутива.

## Правила работы (стоящие приказы владельца)
- Язык общения — русский; владелец требователен — отвечать строго по делу.
- **Код не слать в чат** — только коммиты/архивы/ссылки + проза.
- После любой правки lua: `python3 tools/glua_check.py` + прогон `roundtrip_test.lua` + пересборка ВСЕХ 4 zip (`python3 tools/build_dist.py`) + обновить `README.md` + `ANALYSIS.md` + **commit+push сразу же**.
- Следующий свободный номер модуля: **Код 71**.

## Грабли среды (выстрадано)
- `/tmp` стирается между ходами; `/home/user` вне репо откатывается.
- LuaJIT для стенда собирается в `.luabuild`:
  `mkdir -p .luabuild && cd .luabuild && curl -fsSL -o lj.tar.gz https://codeload.github.com/LuaJIT/LuaJIT/tar.gz/refs/heads/v2.1 && tar xzf lj.tar.gz && mv LuaJIT-2.1 lj && cd lj && make -s`
  → бинарь `.luabuild/lj/src/luajit` (удалить `.luabuild` перед коммитом или держать в `.gitignore`).
- Запуск тестов: `rm -rf tools/luatest/data && ./.luabuild/lj/src/luajit tools/luatest/roundtrip_test.lua save` и далее все фазы.

## Уроки кода (главные)
- **Никогда не парсить JSON для ключей-SteamID64 голым `util.JSONToTable`** — третий аргумент обязателен `(txt, false, true)`; иначе ключи калечатся (находка 65).
- Там, где можно — хранить МАССИВАМИ записей, а не картами с числовыми ключами.
- Каждая запись на диск печатается с причиной (`SAVE ok ... [причина]`).
- В GMod `file.Write` возвращает nil: контроль записи — только read-back.

## Текущее состояние
- Полностью переработаны FFD Fading Door и FFD Keypad (3D2D интерактивный экран, платный проход, фракционный доступ, QTE-взлом).
- Исправлено наслоение HUD дверей (подавление старых рамок гейммода) и точечный спавн оружия в `/weapons_admin`.
- Тесты пройдены 13/13 (100% OK), синтаксис всех 475 Lua-файлов репозитория 100% валиден.
