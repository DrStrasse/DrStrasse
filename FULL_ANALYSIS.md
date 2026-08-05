# ПОЛНЫЙ АНАЛИЗ РЕПОЗИТОРИЯ DrStrasse/DrStrasse (GRM — RP-сборка Garry's Mod)

**Дата анализа:** 2026-08-05
**Метод:** `git ls-remote` / `git fetch` всех веток, PR и тегов; чтение всех MD-файлов; просмотр всех LUA-файлов всех веток (статистика, заголовки, ключевые модули целиком); сравнение деревьев веток; разбор архивов; `gh pr view`.

---

## 1. Резюме (TL;DR)

- Репозиторий — **RP-сборка для Garry's Mod** на GLua: фракции, экономика, инвентарь, телефония, транспорт, логистика, завод, двери, CCTV, сигнализации, радио, мобильные телефоны и многое другое. Всё крутится вокруг глобального namespace `GRM` и глобальной таблицы `Factions`.
- На GitHub **8 веток + 2 PR + 1 тег**. Ветки — это «сессии агентов» Arena: каждая сессия создавала свою ветку `arena/xxxx-...`, и код перетекал между ними вручную. **Единой «святой» ветки нет** — самая свежая и развитая по коду: **`arena/019f89cf-drstrasse`** (398 коммитов, 332 LUA-файла, ~96 000 строк, последний коммит 2026-08-04).
- `master` — **оборванный снапшот** (1 коммит «PhonesGTAIV», создан 2026-07-18): это телефонная эпоха проекта + ядро GRM. История master была перезаписана force-push'ем (PR #1 был смерджен 2026-07-16, но затем master пересоздан с нуля). Наша рабочая ветка `arena/019fcf9e-drstrasse` ответвлена от него.
- Документация рассогласована: разные `HANDOVER.md` указывают на разные «актуальные» ветки (019f69c8 → 019f71e9 → 019f89cf). Самая полная история разработки — `ANALYSIS.md` (находки 1–67 в master, 1–125+ в ветке 019f89cf).
- Главный технический урок проекта (находка 65): **голый `util.JSONToTable` калечит строковые ключи SteamID64** — все чтения JSON должны идти через `JSONToTable(txt, false, true)`.
- Главные риски сейчас: (1) рассинхрон веток и потерянные/дублирующиеся модули (mobile, дилер), (2) легаси-дубли экономики на части веток, (3) 5 незакрытых net-асимметрий из `proto_audit.py`, (4) `continue/goto` в 9 файлах, (5) дублирование `jsonT()` в 10+ модулях.

---

## 2. Карта репозитория

### 2.1 Удалённые ветки

| Ветка | Коммитов | Файлов | LUA | Дата HEAD | Суть |
|---|---|---|---|---|---|
| `master` | 1 (root) | 62 | 49 | 2026-07-18 | «PhonesGTAIV» — снапшот телефонной эпохи + ядро GRM (49 LUA, 22 000 строк) |
| `arena/019f69c8-drstrasse` | 62 | 211 | 185 | 2026-07-16 | «Актуальная база» по старым HANDOVER: коды 51–65 (CCTV, сигнализации, розыск, RP-чат, двери v1, /drop), экономика v3.0.3, EasyChat |
| `arena/019f6cb8-drstrasse` | 58 | 209 | 195 | 2026-07-17 | 019f69c8 + **двери v2.0.0**: FFD Fading Door, FFD Keypad (3D2D), SWEP `ds_key_swep`/`ds_battering_ram`/`ds_lockpick` (QTE), фиксы логистики |
| `arena/019f71e9-drstrasse` | 228 | 552 | 318 | 2026-07-22 | «Last Working SBORKA» — большая сборка (PR #2, открыт): +модели GTA IV (183 файла), 40 подсистем, PR-описание «194 LUA-файла, ~59 400 строк» |
| `arena/019f7da7-drstrasse` | 59 | 215 | 201 | 2026-07-20 | 019f6cb8 + **Код 71: GRM Vendor Framework v1.0** (`grm_vendor`, toolgun) |
| `arena/019f89cf-drstrasse` | 398 | 568 | 332 | 2026-08-04 | **Самая развитая ветка**: CharacterKey-миграция, Q-меню v3.3.1, RadioNet v1.4, mobile v1.2.2, кейпад/сканер, Root Guard, биржа труда, законы, тикеты, аресты, багажники, money printer и т.д. |
| `arena/019fb265-drstrasse` | 235 | 637 | 400 | 2026-08-01 | 019f71e9 + 7 коммитов: **новости, аугментации (чипы/станция), квесты, электроника, кастомизация**, 36 sim-тестов |
| `arena/019fbd57-drstrasse` | 5 | 393 | 380 | 2026-08-04 | master + большой импорт кодовой базы (75 700 строк, коммит `6f34dcb`) + **единый доступ аугментаций по фракциям** (3 коммита поверх) |
| `arena/019fcf9e-drstrasse` | 1 | 62 | 49 | — | **наша рабочая ветка** (ответвлена от master, локальная) |

### 2.2 PR и теги

| Ссылка | Статус | Содержимое |
|---|---|---|
| `refs/pull/1/head` (cc0fbbb) → master | **MERGED** (merge e05fba8, 2026-07-16) | «Финансовая стабилизация»: валюта v2.0.2, экономика v3.0.2, пермы v1.1.0, HANDOVER.md. **Внимание:** merge был, но master потом пересоздан заново (см. §3) |
| `refs/pull/2/head` (d5f8b42) → master | **OPEN** | «Полная RP-сборка» из ветки 019f71e9: FFD двери/кейпад, двери v2.0.3, таран/отмычка/ключи, 40 подсистем |
| `refs/pull/2/merge` (a41911e) | — | merge-коммит PR #2 (в master не влит) |
| тег `grm-full-2026-07-16` (91ed460) | — | «Полный архив кода»: dist/grm_full_code.zip — 47 модулей + README + ANALYSIS (эпоха до кодов 47–50) |

---

## 3. История и происхождение веток (граф)

```
2026-07-16  PR#1 merged → master (e05fba8)
2026-07-18  master пересоздан force-push'ом: root-коммит 05b4698 «PhonesGTAIV»
            (62 файла: ядро GRM + телефонные модули + zip'ы GTA IV phones / DoorAddons)
            └─ наша рабочая ветка arena/019fcf9e-drstrasse ← от этого коммита
2026-07-16  arena/019f69c8 (62 коммита, коды 51–65) ──┐
2026-07-17  arena/019f6cb8 = 019f69c8 + двери v2 ──────┤
2026-07-20  arena/019f7da7 = 019f6cb8 + Vendor v1.0 ───┤
2026-07-22  arena/019f71e9 «Last Working SBORKA» (228) ─┤ (PR#2 open)
2026-08-01  arena/019fb265 = 019f71e9 + новости/аугментации/квесты/электроника (235)
2026-07-22…  arena/019f89cf (398) — собственная корневая история
2026-08-04  arena/019fbd57 = master-эпоха + импорт 75 700 строк + unified augmentation access
```

Ключевой факт: **истории веток переплетаются не через merge, а через повторные импорты файлов**. Поэтому одинаковые модули на разных ветках существуют в разных версиях (например, `sh_grm_economy.lua` — v3.0.2 на master/019f69c8, v3.0.3 на 019f71e9/019f89cf/019fb265; `sh_grm_mobile.lua` — вообще не существует в master, есть упрощённый v2.0.0 на 019f71e9, полноценный v1.2.2 на 019f89cf).

---

## 4. Что внутри каждой ветки (LUA-состав)

### 4.1 `master` — рабочее дерево (то, что лежит у нас сейчас)
49 LUA-файлов, 21 983 строки:

**Ядро:** `sh_factions.lua` (2279 стр.) — фракции/ранги/отделы/приглашения/меню; `sh_faction_fixes.lua` (2580) — комендантский час, модели/оружие по рангам, маскировка V2, `/gnews`.
**Экономика:** `sh_grm_currency.lua` v2.0.2 (806) — валюта с нуля, всеядный загрузчик, jsonT; `sh_grm_economy.lua` v3.0.2 (2149) — единая экономика, банк, зеркало `grm_bank_nicks.json`; `sh_grm_admin_menu.lua` (1269) — суперадмин-панель; `lua/entities/grm_bank_terminal/` — банкомат.
**Инвентарь/UI:** `sh_grm_inventory.lua` (810), `cl_grm_inventory_ui.lua` (317), `cl_grm_hud.lua` v10.2 (446), `sh_grm_tab_menu.lua` v1.8 (1029), `sh_grm_movement.lua` (271).
**Телефония (фишка master):** `sh_grm_phone_config/access/shop`, `sv_grm_phone` (899), `cl_grm_phone` (254), 5 entity (`grm_payphone`, `grm_pbx_station`, `grm_phone`, `grm_phone_terminal`, `grm_phone_wiretap`) + `sh_grm_perm_entities.lua` v1.1.0 (283) для пермов банкомата/телефонии.
**Логистика и завод:** `sh_grm_logistics_config/entities` + `sv_grm_logistics` (806) + `cl_grm_faction_logistics` (285); `sh_grm_factory_fullcycle_config/entities` + `sv_grm_factory_fullcycle` (1127) + `cl_grm_factory_fullcycle` (667).
**Транспорт:** `sh_grm_vehicle_access` (1301), `vehicle_dealer.lua` (176), `zz_grm_vehicle_antistuck` (474), `sh_grm_shop_integration` (272).
**Прочее:** `sh_spawn_points` (625), `sh_grm_chat_config` (79), `tools/luatest/roundtrip_test.lua` (534, 13 фаз).
**Архивы в дереве master:** `GTA IV all phones.zip` (модели телефонов ivancorn), `DoorAddons.zip` (внешняя дверная система: `door_system_addon` + `factions_fading_doors`), `dop.addons.7z` (доп-аддоны: `grm_ctx` + `grm_easychat_edit` — EasyChat 179 файлов), `grm_single_addon (4).zip` (сборка эпохи 019f69c8), `dist/*.zip` (4 дистрибутива: full_code 61 файл, single_addon 63, economy 33, fix_hud_tab_currency 9), `SaveCode` (пустой файл-маркер).

### 4.2 `arena/019f69c8` (62 коммита) — «актуальная база» по старому HANDOVER
Всё из master + новые подсистемы (коды 51–65):
- **CCTV** (`sh_grm_cctv_config/access`, `sv/cl_grm_cctv`) — камеры, мониторы, серверы, HUD камеры;
- **Сигнализации** (`sh_grm_alarm_config/access`, `sv/cl_grm_alarm`) — датчик, хаб, терминал, логи, доступ, игнор «своих»;
- **Розыск** (`sv_grm_wanted`, `cl_grm_wanted`, `sh_grm_wanted_config/access`, Код 61) — уровни, статьи, история, `/wanted_access`, вкладка в `/factions`;
- **RP-чат** (`sh_grm_rp_chat`, `zz_easychat_grm_fix`, EasyChat) — `/me /do /it /try /roll /w /y /looc /ooc`, локальный чат (Код 62);
- **Двери v1** (`sh_grm_doors`, `sh_grm_doors_access`, Код 64) — владение/аренда/категории/ордера `/warrant`, категории, `/drop` (Код 65);
- **grm_item_drop**, encumbrance (вес), еда/голод, наручники, прослушка помещений (roomtap), ключи транспорта (`sv_vehicle_keys`), шахта/руда (`sv_grm_mining_saver`, `sv_grm_ore_spawner`), `sh_grm_ctx` (C-меню);
- Экономика здесь уже **v3.0.3** (фикс «снятие со счёта не размножает банк»), HUD/Tab/CCTV фиксы, пермы v1.1.0.
- Документация ветки: `README.md` (48 модулей), `ANALYSIS.md` (99 780 байт, находки 1–67), `HANDOVER.md`, `docs/dop/*` (README по encumbrance/food/handcuffs/roomtap/vehicle_keys).

### 4.3 `arena/019f6cb8` (58 коммитов) — двери v2.0.0 + FFD
Всё из 019f69c8 + **переработанная дверная система v2.0.0**:
- `sh_grm_doors.lua` — FFD Fading Door + FFD Keypad с интерактивным 3D2D-дисплеем, платный проход (toll), фракционный доступ, QTE-взлом;
- SWEP'ы: `ds_key_swep` (ключи), `ds_battering_ram` (полицейский таран по ордеру), `ds_lockpick` (QTE-взломщик, модель C4);
- перехват F1–F4 гейммода, фиксы замков (CLOSED vs OPEN), персистентность оружейных шкафов, гибкие права ордеров по фракциям/рангам/отделам;
- `lua/weapons/gmod_tool/stools/ffd_fading_door.lua`, `ffd_keypad.lua`, `keypad.lua`, `fading_door.lua`.

### 4.4 `arena/019f71e9` (228 коммитов) — «Last Working SBORKA»
Самая полная по ассетам ветка: 552 файла, 318 LUA, **183 модельных файла GTA IV (модели/материалы ivancorn — телефоны)**. Содержит всё вышеперечисленное +:
- персонажи (character slots foundation, `Use character key for inventory`),
- money printer (переписан, продаётся у редкого вендора),
- медицинские нарко-лаборатории (rewrite),
- FFD-инструменты, Wardrobe (гардероб), `sv_grm_wardrobe_spawn`, `sv_grm_perms_test`;
- по `PROJECT_MEMORY.md` (2026-07-22): 301 LUA-файл ~82 000 строк, крупнейшие модули: easychat.lua (3197), sh_faction_fixes.lua (2949), sh_factions.lua (2444), sh_grm_economy.lua (2352), sh_grm_radionet.lua (1652), sh_grm_doors.lua (1547), sh_grm_jobs.lua (1450), sent_vehicle_dealer/init.lua (1307).
- **Найденный рассинхрон (2026-07-22):** `sh_grm_mobile.lua` в этой ветке — упрощённый v2.0.0 (142 строки), тогда как дока/тесты описывали полноценный mobile v1.2.x (UI с приложениями, SMS, контактами). Позже на 019f89cf mobile восстановлен до v1.2.2.

### 4.5 `arena/019f7da7` (59 коммитов) — Vendor Framework v1.0
019f6cb8 + **Код 71: `sh_grm_vendor.lua`** — единый фреймворк торгашей (один класс `grm_vendor`, тип задаётся в data), `cl_grm_vendor_ui.lua` (киоск), `lua/weapons/gmod_tool/stools/grm_vendor_tool.lua`. На 019fbd57/019f89cf этот же фреймворк развит до **v2.0 / v2.1 (Код 111)** с синхронизацией каталогов с Mining/Food/OreDefs.

### 4.6 `arena/019f89cf` (398 коммитов) — самая развитая ветка
332 LUA (~96 000 строк), инструменты: `glua_check.py`, `proto_audit.py`, `build_dist.py`, 19 luatest-стендов (roundtrip + 18 sim_*). Уникальные системы:
- **CharacterKey-архитектура** (`sh_grm_character.lua`, `CHARACTER_ARCHITECTURE.md`, `CHARACTER_MIGRATION_STATUS.md`) — персонажи (3 слота), миграция всех RP-данных с SteamID на `SteamID64:charN`: фракции, деньги, инвентарь, медкарты, wanted, телефоны, RadioNet, двери, транспорт, jobs, ачивки;
- **Q-меню «GRM Стройка+» v3.3.1** (коды 91–96) — замена ванильного Q, каталог пропов, лимиты, куратор, защита от remover;
- **RadioNet v1.4.0** (`sh_grm_radionet.lua`, коды 85/87/98/99) — стойки/антенны/передатчики, покрытие, частоты `/freq` `/r`, мегафон, пеленг, журнал;
- **Mobile v1.2.2** (коды 88–100) — 7 тиров телефонов GTA IV, приложения, SMS, форум, анти-скачок выбора;
- **Кейпад/сканер/FFD** (коды 104–108) — строгий PIN, 3D2D-базис из формулы, перм с данными экземпляра, ручная связка FFD Link;
- **Root Guard v1.0.0** (Код 84) — подтверждение владельцем сервера деструктивных действий суперадмина;
- Биржа труда v1.1.0 (Код 77, вакансии фракций с эскроу), законы v1.2.0, тикеты (F2), аресты/камеры/электрошокер, багажники `/trunk`, физический дроп денег `/dropmoney`, деньги-принтер, доска набора, ачивки с ежедневным бонусом, медкарты v1.1.0 (Код 101), единая админ-панель `/grm_admin` (Код 79), F4-меню, prop protect, minimap/GPS, полиция: электрошокер с моделью, конвой наручников;
- `ANALYSIS.md` — **384 КБ, находки 1–125+** (полная история разработки).

### 4.7 `arena/019fb265` (235 коммитов) — ответвление 019f71e9 + контентные системы
Уникально относительно 019f89cf:
- **Аугментации** (`sh_grm_augmentations.lua`, чипы, станция `grm_augmentation_station`, под `grm_augmentation_pod`), HUD аугментаций, админка;
- **Новости** (`sh_grm_news.lua`, публикация статей);
- **Квесты** (`sh_grm_quests.lua` v1.4.0 + `grm_quest_npc`);
- **Электроника/сеть** (`sh_grm_electronics`, `grm_net_computer/device/document/plug/printer/router/socket`);
- **Кастомизация** (`sh_grm_customization`), `sh_grm_vehicle_dealer.lua` (новая реализация дилера);
- 400 LUA-файлов, 36 luatest-стендов (включая sim_augmentations, sim_arrest, sim_cctv_view).

### 4.8 `arena/019fbd57` (5 коммитов) — unified augmentation access
master + импорт (коммит `6f34dcb` «Fix Citadel core tool ComboBox syntax» влил 75 700 строк — фактически вся кодовая база эпохи 019fb265: аугментации, новости, квесты, электроника, Citadel Core) + 3 коммита:
- `6f30ec4` Persist unified augmentation faction access configuration;
- `6d2e6f4` Add unified augmentation faction access editor;
- `be172e0` Route legacy augmentation access through unified faction permissions.
Итого 380 LUA, 393 файла. **Особенность:** содержит и `sh_grm_economy.lua`, и легаси `sh_grm_faction_economy.lua` — риск двойной экономики (см. §7).

### 4.9 `arena/019fcf9e` (наша ветка)
= master + 0 коммитов (создана от 05b4698). Весь её контент описан в §4.1.

---

## 5. Все MD-файлы (что прочитано)

| Файл | Где | Содержимое |
|---|---|---|
| `README.md` | master (17,6 КБ) | Таблица 48 модулей, установка, команды, зависимости, файлы данных |
| `README.md` | 019f89cf (107,5 КБ) | Реестр файлов и модулей + «текущий статус фиксов» с 26 разделами по mobile/медицине/персонажам |
| `HANDOVER.md` | master (5,5 КБ) | Памятка сессии: правила (русский язык, код не в чат, luaparser + линт + стенд + пересборка 4 zip + commit), грабли среды (LuaJIT сборка, /tmp стирается), уроки (jsonT, массивы, read-back), открытые нитки (чужой писатель grm_wallet.json, sent_vehicle_dealer, RadioFrequencies, SteamID64 владельца) |
| `HANDOVER.md` | 019f89cf (38,5 КБ) | Расширенная версия: коды 51–111 с деталями, «следующий Код 112, находка 129», ловушки песочницы, чек-листы кейпадов, mobile |
| `ANALYSIS.md` | master (90 КБ, 387 стр.) | Технический анализ кусков 1–4: архитектура, потоки данных, 38 проблем + находки 39–67 (финансовая сага: 5с-флаш, сверка, антисвайп, SQL sv.db → отказ, всеядный загрузчик, корень-находка 65 — JSONToTable, пермы 66–67) |
| `ANALYSIS.md` | 019f69c8 (99,8 КБ) | находки 1–67 + экономика v3.0.3 |
| `ANALYSIS.md` | 019f89cf (384 КБ) | находки 1–125+: Q-меню (109–113), мобильные (114, 117), рации (115–116), медкарты (118), кейпад (119–125) |
| `PROJECT_MEMORY.md` | 019f89cf/019fb265 | Рабочая память агента 2026-07-22: объём (301 LUA / 82 198 строк), прогоны (GLua 292/0, roundtrip, proto_audit 5 замечаний, sim-тесты 14 зелёных / 3 падающих: sim_dealer, sim_mobile, sim_mobile_ui), главный рассинхрон (mobile), план работ |
| `ANALYSIS_MODULES.md` | 019f89cf/019fb265 | Анализ 281 LUA (~66 000 строк): 11 систем, проблемы (continue/goto в 9 файлах, дубли jsonT, мёртвые sh_grm_shop_integration/vehicle_dealer.lua, net-каналы ~80, производительность) |
| `ANALYSIS_ALL_LUA.md` | 019f89cf/019fb265 | Полный аудит всех 302 LUA (84 854 строки): модули по категориям |
| `CHARACTER_ARCHITECTURE.md` | 019f89cf/019fb265 | План CharacterKey-миграции: AccountKey/CharacterKey/ActorKey, API, 6 этапов, инвентаризация SteamID-зависимостей, правило безопасности |
| `CHARACTER_MIGRATION_STATUS.md` | 019f89cf/019fb265 | Статус: готово всё (factions, currency, medical, wanted, mobile, doors, vehicle, jobs...), валидация (GLua 293/0, симы зелёные), намеренные остаточные SteamID-вызовы, 5 protocol-замечаний |
| `docs/dop/*/README*` | 019f69c8 | README доп-модулей: encumbrance, food, handcuffs, roomtap, vehicle_keys |
| `README.md` (в DoorAddons.zip) | master | документация внешней дверной системы |

---

## 6. Анализ LUA-кода (по существу)

### 6.1 Архитектура
- Единая точка интеграции — глобальный `GRM = GRM or {}` и глобальная `Factions` (создаётся на сервере в `sh_factions.lua`; клиент получает копию `FactionsData` через `net Factions_SyncAll` — **важно**: на клиенте `Factions` = nil, находка 123).
- Кросс-модульные вызовы защищены nil-проверками (`if GRM.Encumbrance and GRM.Encumbrance.Refresh`), модули ставятся по одному; жёсткие зависимости: логистика → конфиг, завод → конфиг+entities, экономика → Factions (с retry).
- Порядок загрузки autorun по алфавиту: `sh_faction_fixes.lua` грузится раньше `sh_factions.lua` → паттерн `loadExtrasWithRetry()` (0.5с) — корректно, не ломать.
- Клиентские UI связаны через **глобальные функции намеренно** (`OpenAdminMenu`, `refreshAllUI`, `updateLeaderRanks`, `OpenLeaderMenu`) — хрупкий, но рабочий контракт; не локализовать при рефакторинге.
- Каналы данных: экономика → валюта (все 15 точек через `GRM.GiveMoney/TakeMoney/SetBalance` с reason); HUD/Tab через `grm_balance`/`GRM_Currency_Sync`/`GRM_Bank_Sync` (Double, находка 55); `grm_notify` — единственный приёмник HUD.

### 6.2 Ядро персистентности (самое больное место проекта)
- `sh_grm_currency.lua` v2.0.2: кошелёк `grm_wallet.json`; всеядный загрузчик (map / plain sid→число / array+sid / array по нику); детерминированный сериализатор (balance первым полем); антисвайп; карантин битых; read-back; сверка 15с; зеркала; `GRM.MaxBalance` 2·10⁹.
- `sh_grm_economy.lua` v3.0.2: `grm_treasury.json` + зеркала, семена по убыванию доверия, «память главнее» в сверке, мгновенная запись банковских операций с печатью `SAVE ok [причина]`, зеркало счетов `grm_bank_nicks.json` (поле `electro_balance`), `GRM.GetElectroBalance`.
- **Урок находки 65 применяется везде**: `jsonT(txt) = JSONToTable(txt, false, true)` + `fixArr`. Однако `jsonT` **продублирован в 10+ модулях** (currency, economy, inventory, mobile, medical, perm_entities, phone_shop, sv_grm_cctv, sv_grm_logistics, sv_grm_roomtap) — ANALYSIS_MODULES рекомендует вынести в `sh_grm_json.lua`.

### 6.3 Состояние тестов (ветка 019f89cf — эталонная)
- `glua_check.py`: **293 файла, 0 ошибок**;
- roundtrip: 14 фаз зелёные (save/load/sidkey_trap/bank_nick_mirror/bank_reconcile_attack/bank_boot_pick_fresh/perm/corrupt/corrupt_all/treasury_corrupt/fmt_array_sid/nick/mapnum/fines);
- sim-стенды 18 шт., все зелёные (sim_ffdtools 144, sim_radionet 183, sim_mobile 121, sim_medical 75, sim_security 50...);
- `proto_audit.py`: **5 замечаний** остаются — `GRM_FPerm_Set`/`GRM_FPerm_Open` (faction-perms UI) и `VD_AdminSpawnVehicle`/`VD_RequestVehicleList`/`VD_VehicleList` (legacy дилер) — net.Start без приёмника или наоборот; требуют решения (реализовать ресиверы или whitelist).

### 6.4 Крупнейшие модули (по ветке 019f89cf)
| Модуль | Строк | Роль |
|---|---|---|
| `lua/easychat/easychat.lua` | 3197 | чат (внешний компонент, встроен в сборку) |
| `sh_faction_fixes.lua` | ~2950 | расширение фракций |
| `sh_factions.lua` | ~2440 | ядро фракций |
| `sh_grm_economy.lua` | ~2350 | экономика/банк |
| `sh_grm_mobile.lua` | ~1940 | мобильные телефоны |
| `sh_grm_radionet.lua` | ~1650 | радиосеть |
| `sh_grm_doors.lua` | ~1550 | двери/замки |
| `sh_grm_jobs.lua` | ~1450 | биржа труда |
| `sent_vehicle_dealer/init.lua` | ~1310 | дилер транспорта |
| `sh_grm_vehicle_access.lua` | 1301 | доступ к транспорту |

---

## 7. Замеченные проблемы и риски (кросс-веточные)

### 7.1 Высокие
1. **Нет единой актуальной ветки.** `HANDOVER.md` master указывает на 019f69c8, HANDOVER 019f69c8 — на неё же, HANDOVER 019f89cf — на 019f71e9, а PROJECT_MEMORY фиксирует расхождение. Реальный лидер по коду — 019f89cf (2026-08-04), но PR в master от него нет. **Рекомендация: выбрать 019f89cf (или 019fbd57) как основу, смержить остальное, master сделать актуальным.**
2. **История master уничтожена.** PR #1 был смерджен (e05fba8), но master пересоздан root-коммитом 05b4698 — потеряна связь с историей. Восстановить ссылку можно через merge e05fba8.
3. **Двойная экономика на части веток.** `019fbd57` (и `019f89cf`) содержат `sh_grm_faction_economy.lua` (легаси, находка 1: двойной налог 300с, две базы) рядом с `sh_grm_economy.lua`. На 019fbd57 легаси-файл НЕ помечен как удалённый — при установке сборки с этой ветки оба модуля загрузятся. **Проверить и удалить легаси-файл из всех веток** (в master его уже нет — он удалён в эпоху Кода 43).
4. **5 незакрытых net-асимметрий** (FPerm/VD) — мёртвые кнопки или незащищённые протоколы; нужен whitelist или ресиверы.
5. **Рассинхрон mobile-модуля** (зафиксирован 2026-07-22): на 019f71e9 лежал упрощённый `sh_grm_mobile.lua` (142 строки), документы и тесты описывали v1.2.x; на 019f89cf восстановлен v1.2.2 — но на 019fb265/019fbd57 версии надо перепроверить.

### 7.2 Средние
6. **`continue`/`goto` в 9 файлах** (cl_grm_handcuffs, sv_grm_food, sh_faction_fixes, sh_grm_character, sh_grm_jobs, sh_grm_rpdesc, zz_grm_vehicle_antistuck, grm_ore_buyer/cl_init, sent_vehicle_dealer/init) — ломают ванильный luac; GLua-чекер их пропускает (LuaJIT), но находка 125 предписывает if-оборачивание. В 019f89cf уже избавлены (sim_dealer падал из-за устаревшего ожидания).
7. **Дублирование кода**: `jsonT` в 10 модулях; `sh_grm_shop_integration.lua` и `vehicle_dealer.lua` — легаси-патчи при наличии `sent_vehicle_dealer` (на 019fb265 появился `sh_grm_vehicle_dealer.lua` — третья реализация).
8. **Производительность**: CCTV ViewGuard и Mobile NavTick — каждый кадр; `GRM_StaminaTick` 0.1с; `Factions_SyncAll` может быть тяжёлым; `buildData()` админки — O(n²).
9. **Документация отстаёт от кода**: PROJECT_MEMORY (22.07) vs фактические изменения 019f89cf (04.08) — разделы mobile/laws устарели; часть замечаний ANALYSIS_MODULES уже исправлена.
10. **Безопасность**: часть команд на `IsAdmin()` вместо `IsSuperAdmin()`; `GRM_CCTV_View` без лимита зрителей; на 019f69c8 `vehicle_dealer` fallback «показать всё при пустом списке» (осознанная совместимость, но злоупотребляема).

### 7.3 Открытые нитки из HANDOVER
- Внешний «писатель» в `grm_wallet.json` (формат массива name/balance) так и не идентифицирован — ныне безвреден (всеядный загрузчик + доминирование памяти);
- Не сделано (по старым хотелкам): `sent_vehicle_dealer` (сделан позже на 019f71e9+), `RadioFrequencies` (закрыт RadioNet), SteamID64 владельца для белого списка econadmin (не предоставлен);
- `tools/luatest/roundtrip_test.lua` в master — 13 фаз; в 019f89cf — 14 фаз.

---

## 8. Рекомендации (приоритетно)

1. **Свести ветки в одну**: за основу взять `arena/019f89cf-drstrasse` (максимум фиксов, CharacterKey, полный тест-стенд), перенести недостающее из `019fb265` (новости, аугментации, квесты, электроника) и `019fbd57` (unified augmentation access), смержить в master через PR; обновить HANDOVER/README.
2. **Удалить легаси-экономику** `sh_grm_faction_economy.lua` из веток, где она осталась; добавить страж-синглтон как в ядре.
3. **Закрыть 5 protocol-замечаний** proto_audit (ресиверы или whitelist) и добавить прогон в регресс.
4. **Вынести `jsonT` в общий модуль** (`sh_grm_json.lua`), убрать дубли; заменить `continue/goto` на if-оборачивание.
5. **Унифицировать дилерскую ветку**: решить судьбу `vehicle_dealer.lua` / `sh_grm_shop_integration.lua` / `sh_grm_vehicle_dealer.lua` / `sent_vehicle_dealer`.
6. **Разобрать рассинхрон mobile** на 019fb265/019fbd57 (сверить с v1.2.2 из 019f89cf).
7. **Настроить пайплайн на 019f89cf**: glua_check → roundtrip → sim_* → proto_audit → build_dist.py → commit+push (по правилам HANDOVER).
8. Зафиксировать владельца SteamID64 для Root Guard / белого списка econadmin.

---

## 9. Приложение: статистика

- Всего в репозитории (все ветки): **~3400+ уникальных LUA-файлов** суммарно по деревьям; самая большая ветка 019fb265 — 400 LUA.
- Самая маленькая — master: 49 LUA / 21 983 строки.
- Тест-инфраструктура: `tools/luatest/` — roundtrip + 18 sim-стендов (019f89cf), `tools/glua_check.py`, `tools/proto_audit.py`, `tools/build_dist.py`.
- Сетевых каналов (net): ~80+ (по ANALYSIS_MODULES).
- Файлов данных: ~30 JSON/лог-файлов в `garrysmod/data/` (wallet, treasury, bank_nicks, factions, inventories, economy, phone/*, cctv/*, grm_doors/*, grm_wanted/*, perm_entities, trunks, jobs, medcards, tickets, news, quests и др.).
