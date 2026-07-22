# PROJECT_MEMORY — рабочая память агента по GRM/DrStrasse

Дата фиксации: 2026-07-22  
Рабочая директория: `/home/user/DrStrasse`  
Репозиторий: `https://github.com/DrStrasse/DrStrasse.git`  
Текущая локальная ветка для анализа: `analysis-latest` от `origin/arena/019f71e9-drstrasse`  
Текущий анализируемый коммит: `05ba324` — `dist: пересборка архивов`

> Важно по безопасности: GitHub PAT был передан пользователем в чат. Токен не сохранялся в `remote.origin.url` и не должен записываться в файлы. Пользователю рекомендовано отозвать/перевыпустить PAT.

---

## 1. Какая ветка актуальная

Удалённые ветки, найденные 2026-07-22:

- `master` → `05b4698 PhonesGTAIV`; содержит часть проекта, но отстаёт от arena-веток.
- `arena/019f69c8-drstrasse` → коды 64–65, много новых модулей относительно master.
- `arena/019f6cb8-drstrasse` → FFD Fading Door/Keypad, инструменты сборки.
- `arena/019f7da7-drstrasse` → Код 71 Vendor Framework.
- `arena/019f71e9-drstrasse` → `05ba324 dist: пересборка архивов`; самая поздняя по дате коммита и самая полная по файлам/ассетам. Для анализа взята она.

Документы `README.md`/`HANDOVER.md` местами говорят про старые arena-ветки, но фактически в репозитории самая свежая на момент анализа — `origin/arena/019f71e9-drstrasse`.

---

## 2. Общий смысл проекта

GRM — крупная RP-сборка для Garry's Mod на GLua/Lua:

- фракции, ранги, отделы, приглашения, админ-меню;
- единая валюта и экономика: наличка, банк, бюджеты фракций, зарплаты, штрафы, банк-терминалы;
- инвентарь, вес, предметы, деньги в мире, еда, холодильники/кухня/огороды;
- транспорт: доступы, дилер, ключи, багажники, анти-застревание;
- логистика, завод полного цикла, добыча/руда;
- телефония, мобильные, радиосеть, радиовещание, громкоговорители;
- безопасность: двери, кейпады, FFD, замки, таран, отмычка, CCTV, сигнализация, прослушка;
- RP-инструменты: RP-имя/описание, чат, F4, C/Q меню, доска набора, биржа труда, законы, розыск;
- админ-хаб, root guard, перманентные сущности.

Архитектурная основа: глобальный namespace `GRM = GRM or {}` и глобальная таблица `Factions`. Модули часто связаны через глобальные функции/хуки/net-каналы; рефакторинг нужно делать осторожно, не ломая эти контракты.

---

## 3. Размер и структура на ветке `analysis-latest`

Подсчёт 2026-07-22:

- Lua-файлов всего: 301.
- Строк Lua всего: ~82 198.
- `lua/autorun`: 106 файлов, ~54 843 строк.
- `lua/autorun/client`: 19 файлов, ~6 958 строк.
- `lua/autorun/server`: 18 файлов, ~10 246 строк.
- `lua/entities`: 125 файлов, 41 entity-директория, ~7 900 строк.
- `lua/weapons`: 20 файлов, ~3 144 строки.
- `lua/easychat`: 50 файлов, ~16 311 строк.
- Папки ассетов: `models/ivancorn/`, `materials/models/ivancorn/` — модели/материалы телефонов GTA IV.
- Готовые архивы: `dist/grm_single_addon.zip`, `dist/grm_full_code.zip`, `dist/grm_economy.zip`, `dist/grm_fix_hud_tab_currency.zip`.

Крупнейшие модули:

- `lua/easychat/easychat.lua` — 3197 строк.
- `lua/autorun/sh_faction_fixes.lua` — 2949.
- `lua/autorun/sh_factions.lua` — 2444.
- `lua/autorun/sh_grm_economy.lua` — 2352.
- `lua/autorun/sh_grm_radionet.lua` — 1652.
- `lua/autorun/sh_grm_doors.lua` — 1547.
- `lua/autorun/sh_grm_jobs.lua` — 1450.
- `lua/entities/sent_vehicle_dealer/init.lua` — 1307.
- `lua/autorun/sh_grm_vehicle_access.lua` — 1301.

---

## 4. Критичные правила дальнейшей работы

Из `HANDOVER.md` и анализа:

1. Общаться с владельцем по-русски, коротко и по делу.
2. Не слать большие куски кода в чат; лучше коммиты/архивы/сводка.
3. После Lua-правок желательно:
   - GLua syntax check;
   - `tools/proto_audit.py`;
   - roundtrip-тесты;
   - все релевантные `tools/luatest/sim_*.lua`;
   - пересборка 4 zip через `tools/build_dist.py`;
   - обновление README/ANALYSIS при изменении поведения;
   - commit/push, если владелец просит.
4. Для JSON с ключами SteamID64 нельзя использовать голый `util.JSONToTable`; нужен вариант с `ignoreConversions=true`, обычно `util.JSONToTable(txt, false, true)`. Это ключевой урок проекта.
5. Там, где можно, хранить массивы записей вместо map с числовыми/SteamID64 ключами.
6. `file.Write` в GMod не даёт надёжный success — контроль через read-back.
7. Порядок загрузки autorun по алфавиту важен; многие модули используют retry/отложенную регистрацию.
8. Глобальные функции UI/фракций нельзя бездумно локализовать — на них завязаны патчи вкладок.

---

## 5. Проверки, прогнанные 2026-07-22

### GLua syntax

Собран локальный LuaJIT в `.luabuild/lj/src/luajit` по инструкции из `HANDOVER.md`.

Команда:

```bash
python3 tools/glua_check.py
```

Результат:

```text
GLua Syntax check complete: 292 files checked, 0 syntax errors.
```

### Roundtrip

Прогнаны фазы:

`save load sidkey_trap bank_nick_mirror bank_reconcile_attack bank_boot_pick_fresh perm corrupt corrupt_all treasury_corrupt fmt_array_sid fmt_array_nick fmt_mapnum fines`

Результат: все перечисленные фазы OK.

Покрывает: валюта, банк, зеркала/самолечение JSON, ловушка SteamID64, перманентные entity, импорт чужих форматов кошелька, штрафы.

### Protocol audit

Команда:

```bash
python3 tools/proto_audit.py
```

Результат: 5 замечаний.

```text
[net.Start без net.Receive] GRM_FPerm_Set  (lua/autorun/client/cl_grm_faction_perms_ui.lua)
[net.Start без net.Receive] VD_AdminSpawnVehicle  (lua/autorun/sh_grm_tab_menu.lua)
[net.Start без net.Receive] VD_RequestVehicleList  (lua/autorun/sh_grm_tab_menu.lua)
[net.Receive без отправителя (внешний аддон?)] GRM_FPerm_Open  (lua/autorun/client/cl_grm_faction_perms_ui.lua)
[net.Receive без отправителя (внешний аддон?)] VD_VehicleList  (lua/autorun/sh_grm_tab_menu.lua)
```

Нужно проверить: это реальные мёртвые кнопки или протоколы внешних/legacy модулей. В `proto_audit.py` whitelist ещё не включает эти имена.

### Sim-тесты

Прогнаны все `tools/luatest/sim_*.lua`.

Зелёные:

- `sim_broadcast.lua`
- `sim_factions_live.lua`
- `sim_ffdtools.lua`
- `sim_foodkitchen.lua`
- `sim_invphone.lua`
- `sim_jobs.lua`
- `sim_medical.lua`
- `sim_money.lua`
- `sim_qmenu.lua`
- `sim_radionet.lua`
- `sim_rootboard.lua`
- `sim_security.lua`
- `sim_trunk.lua`

Падают 3:

1. `sim_dealer.lua`
   - Падение: тест ожидает ровно один токен `continue` в `lua/entities/sent_vehicle_dealer/init.lua`, но там теперь 0.
   - Вероятно, устарел сам тест: код уже избавлен от `continue`, а тест всё ещё пытается трансформировать его в `goto`.

2. `sim_mobile.lua`
   - Падение: `lua/autorun/sh_grm_mobile.lua:76: attempt to call field 'RegisterUseHandler' (a nil value)`.
   - В тестовом стабе `GRM.Inventory` нет `RegisterUseHandler`, а текущий `sh_grm_mobile.lua` вызывает его без проверки.
   - Может быть реальный баг порядка загрузки/защитной проверки: если mobile грузится раньше полного inventory API, будет ошибка.

3. `sim_mobile_ui.lua`
   - Падения/несовпадение ожиданий: тест ждёт `версия 1.2.2 (Код 100: анти-скачок выбора)`, а текущий `sh_grm_mobile.lua` — `GRM Mobile v2.0.0 — упрощённая версия`, всего 142 строки.
   - Это сильный рассинхрон документации/тестов и текущего модуля mobile.

---

## 6. Главный обнаруженный рассинхрон

`sh_grm_mobile.lua` в ветке `origin/arena/019f71e9-drstrasse` — упрощённый файл:

- заголовок: `GRM Mobile v2.0.0 — мобильные телефоны (упрощённая версия)`;
- размер: 142 строки;
- регистрирует 4 tier-предмета и простое окно `/mobile`;
- вызывает `GRM.Inventory.RegisterUseHandler(...)` без проверки существования метода.

Но `ANALYSIS.md`, `README.md` и тесты описывают намного более функциональную mobile-систему:

- UI с приложениями, звонками, SMS, контактами, заметками;
- антидребезг клавиш, навигация, keepalive/ping;
- проверки `sim_mobile`/`sim_mobile_ui` на десятки/сотню сценариев;
- версии около `v1.2.x`, коды 88–100.

В архивах `dist/grm_single_addon.zip` и `dist/grm_full_code.zip` тоже лежит этот же упрощённый `sh_grm_mobile.lua` на 142 строки.

Вывод: последняя ветка/архивы содержат либо намеренный упрощённый replacement, либо случайный регресс/перезапись полноценного mobile-модуля. Это приоритет №1 для уточнения/починки, если мобильные важны.

---

## 7. Другие замечания/риски

1. `README.md`/`HANDOVER.md` местами указывают не на самую позднюю arena-ветку. Перед работой всегда проверять `git ls-remote --heads origin`.
2. `ANALYSIS_MODULES.md` упоминает `continue/goto` как проблему, но `tools/glua_check.py` уже даёт 0 синтаксических ошибок; часть этих замечаний может быть устаревшей.
3. Есть потенциальные legacy-дубли:
   - `lua/autorun/sh_grm_shop_integration.lua`
   - `lua/autorun/vehicle_dealer.lua`
   - при наличии полноценного `entities/sent_vehicle_dealer` нужно проверить, что старые патчи не конфликтуют.
4. `tools/proto_audit.py` выявил net-асимметрии по faction perms UI и vehicle dealer tab. Нужно ручное подтверждение.
5. Есть `EasyChat` внутри `lua/easychat`; это внешний/встроенный чатовый компонент, его лучше не ломать массовыми рефакторами.
6. Временные директории `.luabuild/` и `tools/luatest/data/` игнорируются `.gitignore`; не коммитить.

---

## 8. Рекомендуемый порядок дальнейших работ

Если владелец скажет “чинить”:

1. Сначала решить вопрос `sh_grm_mobile.lua`:
   - либо восстановить полноценный mobile-модуль из истории/предыдущей сессии, если он потерян;
   - либо обновить тесты/доки под новую упрощённую v2.0.0;
   - минимум: защитить вызов `GRM.Inventory.RegisterUseHandler` проверкой, чтобы порядок загрузки не ронял сервер.
2. Обновить `sim_dealer.lua`, чтобы он не ожидал обязательный `continue` в уже исправленном коде.
3. Разобрать 5 замечаний `proto_audit.py`.
4. Синхронизировать `README.md`, `HANDOVER.md`, `ANALYSIS_MODULES.md` с фактической веткой и статусом тестов.
5. После любых правок: GLua check → roundtrip → sim-тесты → proto_audit → build_dist.py.

---

## 9. Быстрые команды

```bash
cd /home/user/DrStrasse

# статус
git status --short --branch

# актуальная ветка анализа
git checkout analysis-latest

# синтаксис
python3 tools/glua_check.py

# аудит net-протоколов
python3 tools/proto_audit.py

# roundtrip пример
./.luabuild/lj/src/luajit tools/luatest/roundtrip_test.lua save
./.luabuild/lj/src/luajit tools/luatest/roundtrip_test.lua load

# все sim-тесты
for f in tools/luatest/sim_*.lua; do echo "=== $f ==="; ./.luabuild/lj/src/luajit "$f" || break; done

# пересборка архивов
python3 tools/build_dist.py
```


---

## 10. Правки 2026-07-22: laws + mobile

- `sh_grm_laws.lua` обновлён до v1.2.0: исправлен краш `DFrame` (`Tried to use a NULL Panel`) — больше не вызывается `lawsFrame:Clear()`, чистится только body-панель. Протокол `/laws` разделён на open/list/refresh, все list-пакеты содержат флаги прав.
- `sh_grm_mobile.lua` обновлён до v2.0.1 stabilization: серверный контракт старого Mobile восстановлен частично/практически по стенду — `sim_mobile 121/121 OK`, `sim_invphone 41/41 OK`. Клиентский UI пока упрощённый; `sim_mobile_ui` всё ещё ожидает старый v1.2.2 и падает.
- Новые mobile net-каналы `GRM_Mob_State`/`GRM_Mob_Data` имеют клиентские ресиверы; `proto_audit` снова показывает только старые 5 замечаний по FPerm/VD.


---

## 11. Rewrite mobile + phoneshop 2026-07-22

- `sh_grm_mobile.lua`: восстановлен полноценный клиентский UI/протокол v1.2.2 (`GRM_Mob_Act`, стрелки, SMS/контакты/заметки/jobs/faction/forum/calc, keepalive, freeze, колесо, анти-скачок выбора). Серверный контур сохранён зелёным.
- `sh_grm_phone_shop.lua`: мобильные 7 моделей ivancorn стали авторитетными товарами; каталог сам лечит старые mobile ids и модели; UI магазина разделён на вкладки «Мобильные» и «Оборудование».
- Проверки: GLua 292/0, sim_mobile 121/121, sim_mobile_ui 44/44, sim_invphone 41/41.
