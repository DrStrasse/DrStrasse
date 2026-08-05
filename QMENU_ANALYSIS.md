# GRM Стройка (Q-меню) — полная карта

Дата: 2026-08-05 · Ветка: arena/019fcf9e-drstrasse (база 019fb265)

---

## 1. Главный модуль

**`lua/autorun/sh_grm_qmenu.lua`** — 1380 строк, «GRM Q-меню и инструменты v3.3.1 (Код 96) — GRM Стройка+». Shared-файл (сервер+клиент в одном).

### Что это
Кастомное Q-меню вместо ванильного spawnmenu:
- `playersQ=true` → игроки живут с ванильным Q (серверные гейты спавна/toolgun по флагам действуют всегда);
- `playersQ=false` → бинд `+menu` у игроков глушится универсально (ваниль и ЛЮБОЕ кастомное меню) и вместо него открывается **GRM Стройка+**.

### Модель работы (v3.0.0+, находки 108–113)
- Окно «как ванильное Q»: слева вкладки + контент, **справа — сворачиваемые категории инструментов** (клик = тул в руку, активный подсвечен, меню НЕ закрывается);
- плитки каталога — карточки с иконкой и именем модели; шапка «группа · фракция (ранг)»; счётчик «Мои пропы N/cap»; тосты отказов в футере;
- размер 80%×88% экрана (1200–1560 × 720–980);
- HOLD-Q как ванильное: `pressed=true` → открыть, `pressed=false` → закрыть (PlayerBindPress, хук `GRM_QMenu_BindBlock`);
- `/qm` (`/build`) — открыть (суперадмин/по правам), `/qm_diag` — дамп чужих обработчиков Q (поиск «ЧУЖОЙ» в консоли клиента), `/qm_seed` — мебельный набор в каталог.

### Конфиг по умолчанию (`defaultCfg`)
```
playersQ=true (ванильное Q игрокам) · allowProps=true · allowRagdolls=true
allowEffects=false · allowNPCs=false · allowSENTs=false · allowSWEPs=false
allowVehiclesQ=false · whitelistMode=false
toolDeny={dynamite,turret,igniter,spawner,duplicator,advdupe2,emitter}
grmBuildMenu=true · propsFree=false · propList={} · menuPropCap=24
protectFurniture=true · adminsToo=false (суперадмину тоже Стройка вместо Q)
```
Хранится в **`data/grm_qmenu.json`** (jsonT с ignoreConversions, находка 65).

### Серверная часть
- **API:** `QM.PushSync(ply)` (живой синк конфига на входе и после правок), `QM.Load/Save/Reload`, `QM.CanOpenQ(ply)`, `QM.CanSpawn(ply, what)`, `QM.CanUseTool(ply, tool)`, `QM.CanSpawnMenuProp(ply, model)`, `QM.SpawnMenuProp(ply, model)`, `QM.HandleChat(ply, text)`;
- **гейты:** PlayerSpawnProp/Ragdoll/Effect/NPC/SENT/SWEP/Vehicle → запрет по флагам (с сообщениями);
- **CanTool:** запрет инструментов по чёрному/белому списку + **защита мебели/перм-энтити GRM** от чужого remover (`grmFurniture`: `_grmPerm`, `grm_*` классы; свои пропы — `GRM_MenuOwner`/`_grmQMenuOwner`);
- **куратор каталога:** `NET_CURATE` — `/qm_prop_add` (прицелом), `/qm_prop_addmodel <модель>`, `/qm_prop_del`, `/qm_prop_list`; `NET_SEED` — `/qm_seed`; лимит/свободный режим `propsFree`;
- **сеть:** 12 каналов `GRM_QMenu_*` (Sync, SpawnProp, RemoveOne, ClearProps, Toolgun, SetTool, Curate, Seed, SetOpt, Feedback, Open, Diag);
- **чат:** `PlayerSayTransform` + `PlayerSay` (команды `/qm /build /qm_diag /qm_seed /qm_prop_* /qm_clearprops`), не проглатываются чатом.

### Клиентская часть
- **вкладки:** Каталог (сетка пропов), Куратор (админ: добавить/удалить модели, seed), Настройки (чекбоксы флагов + лимит пропов, `NET_SETOPT`);
- **правая колонка:** `QM.ToolCatalog` — 40+ инструментов по категориям (Соединения/Механика/Свет/Интерфейс/Оформление/Точность/Опасное), включая GRM-тулы: `grm_minimap`, `grm_vendor_tool`, `vehicle_dealer_tool`, `grm_quest_tool`, `grm_network_tool`, `grm_door_admin`;
- **`QM.ToolCategories`** — порядок категорий; **`QM.SeedProps`** — 18 базовых HL2-моделей мебели;
- **рендер:** кастомный тёмный UI (QC-цвета), шапка с идентичностью, футер со счётчиком/тостами, `QM.OpenMenu/CloseMenu/_switchTab/_rebuild`;
- **живой конфиг:** `net.Receive("GRM_QMenu_Sync")` → пересборка меню при правках из хаба;
- **диагностика чужих аддонов:** авто-сенсус + `grm_qmenu_diag` (находка 110: чужой «GRM Restricted Q Menu» глушил Q раньше нашего хука).

---

## 2. Интеграции

### Единый админ-хаб — `lua/autorun/sh_grm_admin_hub.lua`
- вкладка **«Инструменты»** (`buildTools`): все флаги Q-меню чекбоксами (`qToggle`) + чёрный/белый список инструментов из `ToolCatalog` (`qTool`), сохранение сразу;
- вкладка «Сервер»: версия Q-меню в списке.

### Q-меню ← другие модули (тулы в ToolCatalog)
- `grm_minimap` (районы/точки) · `grm_vendor_tool` (торговцы) · `vehicle_dealer_tool` (дилер+площадка) · `grm_quest_tool` (конструктор квестов) · `grm_network_tool` (электроника/сеть) · `grm_door_admin` (двери) — все 6 GRM-тулов зарегистрированы в каталоге.

### Защита имущества
- `CanTool` + `grmFurniture` (в sh_grm_qmenu.lua): режет remover по чужим пропам/перм-энтити GRM (`_grmPerm`, `_grmRNKey`, `_grmBCKey`, классы `grm_*`).

### Сторонние модули, которые опираются на QMenu
- `sh_grm_admin_hub.lua` (вкладка Инструменты);
- `tools/luatest/sim_qmenu.lua` (тест) + `sim_rootboard.lua` (клиент-пасс);
- тулганы и entity добавляются в каталог через правку `QM.ToolCatalog`.

### Файлы данных
- `data/grm_qmenu.json` (единственный; конфиг с флагами, списками инструментов, propList, cap).

---

## 3. Тесты
- **`tools/luatest/sim_qmenu.lua`** (381 строка, 69 проверок): дефолты, Save/Load (в т.ч. дополнение новых полей), CanSpawn/CanUseTool/CanOpenQ, белый/чёрный списки, CanSpawnMenuProp (каталог/propsFree/путь с `..`), SpawnMenuProp (владелец, лимит, лишний спавн), гейты PlayerSpawn*, CanTool+remover, /qm-команды, диагностика;
- `sim_rootboard.lua` — клиентский проход Q-меню (F4-блоки и т.п.).

---

## 4. История версий (из шапки модуля и ANALYSIS)
- **v3.0.0 (Код 91, н108):** урезанное spawnmenu настраивается суперадмином как продукт; «GRM Стройка» вместо ванильного Q при playersQ=false; гейты SpawnMenuOpen/ContextMenuOpen + PlayerSpawn*/CanTool; API CanUseTool/CanSpawn/CanOpenQ; персист grm_qmenu.json;
- **v3.1.0 (Код 92, н109):** полная переработка визуала «как ванильное Q» — справа категории инструментов, плитки каталога, шапка «группа · фракция (ранг)», счётчик «Мои пропы», тосты;
- **v3.2.0 (Код 93, н110):** авто-сенсус чужих обработчиков Q + `/qm_diag` + `adminsToo`;
- **v3.2.1 (Код 94, н111):** окно крупнее/шире, футер в два ряда, без наслоения;
- **v3.3.0 (Код 95, н112):** фикс наслоения инструментов (Dock(TOP) в scrollAdd), HOLD-Q как ванильное;
- **v3.3.1 (Код 96, н113):** окно ещё крупнее (80%×88%, 1200–1560×720–980).

---

## 5. Быстрые команды
| Команда | Кто | Действие |
|---|---|---|
| Зажать **Q** | игрок (playersQ=false) | открыть/закрыть GRM Стройку |
| `/qm`, `/build` | любой по правам | открыть меню |
| `/qm_diag` | суперадмин | дамп чужих обработчиков Q (консоль клиента) |
| `/qm_seed` | суперадмин | добавить базовую мебель HL2 в каталог |
| `/qm_prop_add` | суперадмин | добавить модель под прицелом в каталог |
| `/qm_prop_addmodel <модель>` | суперадмин | добавить модель вручную |
| `/qm_prop_del <модель>` / `/qm_prop_list` | суперадмин | удалить / список каталога |
| `/qm_clearprops` | игрок | убрать свои меню-пропы |
| `/grm_admin` → «Инструменты» | суперадмин | флаги + чёрный/белый списки тулов |
| консоль: `grm_qmenu_diag` | суперадмин | то же, что /qm_diag |

---

## 6. Замечания/риски
- **Зависимость от FactionsData** в шапке (клиентский кэш фракций) — при его отсутствии просто не показывается фракция, не ломается;
- **`grm_quest_tool` в ToolCatalog** — если тулган квестов не установлен (у нас в ветке есть), клик выдаст дефолтный toolgun-режим — проверить наличие стоула при желании;
- **ToolCatalog** расширяется вручную; при добавлении новых GRM-тулов не забывать сюда;
- конфиг живёт на сервере, клиент получает копию — правки только через сервер (хаб/команды).
