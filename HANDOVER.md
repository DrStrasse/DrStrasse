# HANDOVER — передача дел следующей сессии агента

## Текущее состояние (09.08.2026)

**Ветка:** `arena/019fe696-drstrasse` (обязательная ветка сессии). Все пушить в
неё (и при желании в именованную).

**База восстановлена ПОЛНОСТЬЮ** из `origin/arena/019fcf9e` (тег
`grm-full-2026-07-16`). Состояние:

- 406 lua-файлов, **0 синтаксических ошибок** (LuaJIT 2.1 -bl)
- **52 симулятора, 2014 проверок, 0 падений** (tools/luatest/sim_*.lua)
- roundtrip_test.lua — 13/13 фаз PASS
- 142 autorun-модуля (81 shared / 20 server / 34 client / 5 zz_ / 2 моста)
- 63 entity-класса
- 8 SWEP'ов, 18 тулов
- ~100 000 строк lua
- 216 файлов ассетов (31 модель GTA IV телефонов + иконки entities)
- 4 dist-zip пересобраны (full 4.8М, single_addon 4.8М, economy 140К,
  fix_hud_tab_currency 68К)
- README.md переписан под новую базу, в ANALYSIS.md добавлены находки 68–71.

## Что сделано в этой сессии

1. Слияние ВСЕХ lua/autorun, lua/entities, lua/weapons, tools/luatest,
   materials/ и models/ из `origin/arena/019fcf9e` в
   `arena/019fe696-drstrasse` (плюс слит предыдущий коммит `718fcbd` с
   ограблением — фаст-форвард).
2. Ручной патч `sh_grm_economy.lua` (90 строк Vault API) заменён
   канонической версией из 019fcf9e (v3.0.4, Vault API уже встроен).
3. `sh_grm_currency.lua` обновился с v2.0.2 до v2.0.3.
4. `sh_grm_perm_entities.lua` обновился с v1.1.0 до v1.2.0 (17 классов,
   лимит 256, GRM.PermData integration).
5. Добавлено ~340 lua-файлов новых модулей: сигнализация (Код 63), CCTV
   (60), розыск (61), RP-чат (62), двери (64), квесты, ачивки (78),
   админ-хаб (79), багажник (80), Identity (72), RPDesc (71), кастомизация/
   лут-сумки, миникарта, радиосеть (85), медкарты (86), телефонный магазин
   (88), перм-хаб, фракционные пермы (122), вендоры (111), еда (110),
   руда (118), аугментации, наркотики, F4/Q-меню, проппротект, рутгард,
   наручники/арест/обыск, радиовещание (75), доска набора (76), биржа труда
   (77), ключи ТС, антизастревание и т.д.
6. Пересобраны все 4 dist-zip'а.
7. Обновлены README.md и ANALYSIS.md.

## Зависимости и ключевые находки

1. **ГЛАВНОЕ (находка 65):** никогда не используй
   `util.JSONToTable(txt)` без третьего аргумента `true`. ВСЕГДА
   `util.JSONToTable(txt, false, true)` (ignoreConversions=true). Иначе
   SteamID64-ключи конвертируются в double и калечатся (потеря точности).
   Вся сборка это уже соблюдает.
2. Храни списки МАССИВАМИ записей, не картами с числовыми ключами-строками.
3. `file.Write` в GMod не возвращает статус — нужен read-back и печать
   `SAVE ok: <файл> [<причина>]`.
4. `Player:SetPos()` возвращает nil — не чейнить вызовы.
5. `DFrame:Clear()` сносит служебные кнопки — чистить только свои дети.
6. Модели паллет `moneypalleta.mdl`, `pallet_with_money.mdl` — нужен CS:S
   (есть fallback на `money.mdl`).
7. Музыка ограбления `sound/music/hl2_song20_submix0.mp3` — это HL2 контент.
8. /tmp и pip пакеты (luaparser) стираются между ходами — ставить заново
   (`pip install -q --break-system-packages luaparser`).
9. LuaJIT собирается каждый ход:
   ```bash
   mkdir -p .luabuild && cd .luabuild && curl -fsSL -o lj.tar.gz \
     https://codeload.github.com/LuaJIT/LuaJIT/tar.gz/refs/heads/v2.1 && \
     tar xzf lj.tar.gz && mv LuaJIT-2.1 lj && cd lj && make -s -j4
   cd ../..
   ```
   `.luabuild/` в .gitignore.

## Проверки ПЕРЕД каждым коммитом

1. Синтаксис всех lua:
   ```bash
   err=0; for f in $(find lua tools/luatest -name '*.lua' | sort); do
     ./.luabuild/lj/src/luajit -e "assert(loadfile('$f'))" || { echo FAIL: $f; err=$((err+1)); }
   done; echo "ERR=$err"
   ```
2. Симуляторы:
   ```bash
   ./.luabuild/lj/src/luajit tools/luatest/roundtrip_test.lua <phase>  # 13 фаз
   for s in tools/luatest/sim_*.lua; do ./.luabuild/lj/src/luajit $s || echo FAIL $s; done
   ```
3. Пересобрать dist-zip (скрипт через `zip -r`).
4. При добавлении нового модуля — описать в README.md, при находке — в ANALYSIS.md.
5. **Сразу коммит+пуш** в `arena/019fe696-drstrasse` (песочница откатывает
   файлы посреди хода!).

## Следующий свободный код модуля: **126**

(Занятые коды: до 125 включительно; 103, 114, 116, 117, 119, 123 — пропуски).

## Что осталось на усмотрение (не сделано)

1. `lua/easychat/*` — сторонний EasyChat-аддон; не подтянут, интеграция
   через `zz_easychat_grm_fix.lua` и `easychat_init.lua` в сборке есть
   (сработает если EasyChat установлен отдельно).
2. Звуки `sound/kom_hour.wav`, `music/hl2_song*.mp3` и другие кастомные
   звуки в репо не лежат (ожидаются HL2/CS:S-контентом).
3. Модель банкомата `models/starless/atm.mdl` — из отдельного контент-пака;
   код умеет работать и на дефолтной модели.
4. Не вытягивались SWEP из старых DS-папок, которые отсутствуют в 019fcf9e
   (все что там было — уже в сборке).
5. В корне 019fcf9e лежат архивы-бекапы `*.zip/*.7z/SaveCode` — не подтянуты,
   они мусорные.

## Как мерджить следующую порцию

Если появится новая ветка с доработками — сливать так:
```bash
git fetch origin
git checkout origin/arena/019fcf9e -- <список_файлов>
# проверить синтаксис и симы, затем коммит+пуш
```

Мастер 05b4698 «PhonesGTAIV» — это пустой стартовый снэпшот, не мерджить в
него и не ориентироваться на него как на актуальную базу.
