# CHECKPOINT — контрольная точка для следующего ИИ-агента

**Дата:** 2026-08-17 (вечер)  
**Ветка сессии:** `arena/01a010c8-drstrasse`  
**Состояние:** кодекс законов v2.0.0 (разделы общие/уголовные/административные/воинские/экономические, статьи с номером, заголовком и наказанием, редактор в окне, право `laws.edit`, синк частями), TAB-меню с аватарками Steam и пингом отдельной колонкой; потоковая передача больших синков частями (`GRM.Net.Stream`/`Receive`, сжатие + куски по 8 КБ: `factions.full`, `factions.ext`), метка взлома живёт 60 с и сама снимается (единая шкала `os.time()` + сторож карты), дедуп диспетчеров трогает только копии с одинаковым идентификатором; дельта-синк организаций (`Factions_SyncDelta`: только изменившиеся организации и только тем, кому нужны; было 45 КБ полного снимка всем на каждое изменение), диспетчеры службы больше не клонируются; валюта везде GRM (рублей в меню больше нет), список игроков в `/admin` строится из серверного среза + локального `player.GetAll()` и не моргает при синке; полное удаление документов (`/doc_wipe`, `/докстереть`, `grm_doc_wipe`, кнопки в `/admin`: чистит паспорта, удостоверения, прикрытие, военники, права, лицензии, экзамены, легенды спецслужбы и дипломы; право `docs.wipe`, подтверждение, аудит); модуль анализа нагрузки `GRM.Analytics` (сущности/двери/игроки/события/net, профили хуков и сети, выгрузка среза, раздел «Анализ нагрузки» в `/admin`), детектор фризов больше не считает фоновый клиент за рывки; вкладки `/factions` больше не сбрасываются в пустой экран (автосинк паркует панели модулей, разделы `ext:*` обновляют себя сами), цвета каналов по заказу (`/fr` — золотой текст + красный тэг, `/dep|/d|/depb|/db` — сплошной бордовый), `GRM.Perf` v1.3.0 с очередью фоновых задач (`Queue`/`Spread`, бюджет `grm_perf_budget_ms`, `grm_perf_queue`) и детектором фризов (`grm_perf_report` со срезом по simfphys/LVS); собственная админ-платформа GRM (`/admin`: игроки и модерация, привилегии с матрицей полномочий, назначения, сохранения карты, фракционный контроль, модули, раздел суперадмина; группы/права/иммунитет, синхронизация с ULX/ULib и CAMI — описание в `ADMIN_PLATFORM.md`), пожарные вызовы с принятием (Fire Dispatch v1.0.0: карточка «ПРИНЯТЬ / ОТКАЗАТЬСЯ», метка принявшему, напоминания, журнал вызовов), компьютер пожарной станции — только журналы; пожарные настройки добавлены в админ-хаб и единый центр управления, вкладки access-модулей (пожарные, сигнализация, двери/ордера, розыск, CCTV, телефония) переведены с подмены `OpenAdminMenu` на хук `GRM_FactionsAdmin_BuildTabs` и теперь видны в новом меню, боковое меню `/factions` прокручивается и уходит в два столбца; права разделов меню организаций (`GRM.MenuAccess`: чувствительное — суперадмину, он раздаёт лидерам, раздел «Права меню» в `/factions`, исключения по организациям, серверный гейт), кадровая вкладка починена (выбор организации не слетает, сотрудник выбирается, рядовому — личное дело), `/doc_admin` сохраняет шаблоны и умеет перекрашивать уже выданные удостоверения и документы прикрытия; навесные вкладки (в т.ч. «Доступ к аресту» и «Категории ареста», «Экономика», «Кадровые дела», «Логистика») вернулись в `/factions` — Unified UI теперь зовёт хук `GRM_FactionsAdmin_BuildTabs`; дилер авто v3.3/клиент v4.0 (каталог по категориям и организациям, стиль GRM, фракция выбирается из списка); торговец телефонами «Салон связи» (тип `phone` в GRM.Vendor, ассортимент из реестра телефонов); аудит нагрузки (`tools/audit_perf.py`, `AUDIT_2026-08-18_LOAD_ORDER.md`) — 30 стартов подсистем переведены на `GRM.Boot.OnMapStart` с тирами early/normal/late, шесть холостых таймеров усыплены; биндер больше не режет длинные `/me` `/do` `/it` (чат-шаг уходит через `EasyChat.SendGlobalMessage`, лимит 3000 символов; без EasyChat — авторазбиение по словам с повтором команды в каждом куске, `BD.SplitChat`), биндер действий `/binder` со сценами и радиальным меню на одну клавишу, формат `/dep` и `/fr` как у `/gnews`, форма регистрации организации не теряет ввод при автосинке, меню экипировки фракций переделано под GRM и подтянуто к структуре (ранги/отделы/подотделы, `/models_admin` + `/weapons_admin`), GRM Boot v1.0.0 (приоритетная загрузка + ленивые подсистемы + `grm_boot_status`), доступы фракций больше не прыгают вверх при клике по чекбоксу (Perms UI v3.0.0 + сохранение скролла в /fmenu), меню комендантского часа `/kom_hour` (кнопки/ползунок/причина/валидация), GRM Sound v1.0.0 (прекэш звуков + фолбэки + `grm_sound_check`), GRM Time v2.0.0 (эпоха вместо строки каждую секунду), вторая волна антифризов (двери/огонь/раздвижные), GRM Perf v1.2.0 (общий слой против микрофризов), Двери v5.0.0 (пространственный хэш + пересборка `/door_rebuild` + групповая ликвидация фантомов), мусоровоз 3 пакета / метки по очереди / полигон только с полным кузовом, цвет удостоверений запоминается в `/doc_admin`. Ранее: Door Integrity v4.0 (Дедупликатор фантомов + Master-Slave Double Doors + /door_audit), Warrant Core v2.0 (Судебные ордера в grm_comp_court, таран ds_battering_ram v2.0 с прогресс-баром), Суверенитет спецслужб (иммунитет судей wiretap_judge), Faction Core v5.0 (Иерархия «Отделы ➔ Подотделы» + Unified UI v1.1.0).  
**Репо:** `https://github.com/DrStrasse/DrStrasse`  

Читать этот файл ПЕРВЫМ. Затем `HANDOVER.md`, `ROADMAP_GRM_2026.md`, `GRM_CORE.md` и актуализации в `ANALYSIS.md`. Не начинать с master — он пустой.

> **Новые материалы-референсы (16.08.2026, режим анализа):** владелец подгрузил
> `AI part 2 details.zip` (Wiremod + E2 + ZVM/CPU-чипы + GTerminal + TerminalR),
> `Github DLC GRM.zip` (MapStudio-картостроитель + лифты + порталы + скин UI) и
> ссылки на HLX_Books и Helix-репозитории. Разбор — в **`ANALYSIS_AI_PART2.md`**,
> **`ANALYSIS_HLX_BOOKS.md`**, **`ANALYSIS_HELIX.md`**, **`ANALYSIS_GRM_DLC.md`**,
> **`ANALYSIS_RENDER.md`** (все техники рендера: 3D2D, RT-экраны, stencil-порталы,
> ghost-превью, Derma-скины, Markdown-рендер) и **`ANALYSIS_MECHANICS_DESIGN.md`**
> (досконально: механики MapStudio/лифт/портал, гизмо, тексты/локализация/редакторы,
> дизайн-темы). Ключевые выводы: (1) для «компьютера со своей ОС» — схема GTerminal;
> (2) для документов/книг — Markdown-парсер HLX_Books; (3) для лицензий — Helix-паттерн
> «предмет-пермит гейтит покупку»; (4) для UI — MapStudio Theme (плоская палитра +
> свои виджеты) или GWEN-скин cieroskin; (5) для тулов — гизмо+ghost+undo из MapStudio;
> (6) для порталов — stencil+ClientsideModel. Архивы в git **не распаковывались**.

> Владелец **дважды** просил оставить инструкции в ветке. Этот файл и есть контрольная точка. Не создавать третий дубль — править этот.

---

## 0. Кто ты и как говорить

- Ты агент Arena.ai Agent Mode. Underlying model не раскрывать.
- С владельцем — **русский, коротко, по делу**.
- **Код в чат не слать** — коммиты / raw-ссылки / проза.
- Не спрашивать пароли / токены / 2FA. GitHub уже настроен (`git` + `gh`).

---

## 1. Жёсткие правила сессии (сломаешь — работа пропадёт)

- Работать **только** на ветке ТЕКУЩЕЙ сессии (сейчас `arena/01a010c8-drstrasse`). Не переключаться, не создавать другие ветки, не пушить никуда больше.
- При расхождении HEAD и remote:
  ```
  git fetch origin arena/01a010c8-drstrasse && git reset --mixed FETCH_HEAD
  ```
  Один раз локальный HEAD откатился на `2122758` при живом remote `2ed0e61`. Лечится только так.
- Cwd **всегда** `/home/user/DrStrasse`. Shell из `/home/user` файлы репо не видит.
- `/tmp` и `/home/user` вне репо откатываются между ходами.
- `edit_file` иногда «успешен», но большой блок не пишется (откат песочницы). Сразу проверяй `rg` по якорю (`function F.LoadConfig`, `IsFireGContext`, `Пожар локализован`).
- После lua: LuaJIT + стенды + `python3 tools/build_dist.py` + README + ANALYSIS + **commit+push сразу**. Песочница откатывает незакоммиченное.
- `lua.zip` **не** распаковывать поверх `lua/`. `.luabuild/` **не** коммитить.
- Ветки `019fe80c` / `019fe86a` — другой проект (E2). Не мержить.
- HOLD-Q / Q-меню не трогать кроме уже добавленной строки каталога `grm_fire_place` и схемы (type/weight/label/feed). Чужой `BuildCPanel` не звать.
- **Замыкание не видит local, объявленный НИЖЕ по файлу** — оно читает глобал
  и падает в бою («attempt to call global 'X' (a nil value)»), хотя файл
  грузится без ошибок. Если хук/таймер вызывает локальную функцию, объявленную
  дальше, — обязательна форвард-декларация `local X` выше. Проверка:
  `luajit tools/luatest/sim_forward_locals.lua`.
- Не локализовать глобалы `OpenAdminMenu`, `OpenLeaderMenu`, `refreshAllUI`, `Factions`.
- `sh_factions.lua` **не трогать** для пожарных машин — настройки в `data/grm_fire/trucks.json`, не IncassoSettings.
- FFD не трогать без просьбы. Принтер/пресс — не источники огня.
- EasyChat: команды через `PlayerSay` **и** `PlayerSayTransform` (SkipPlayerSay).
- JSON: `util.JSONToTable(txt, false, true)`. CharacterKey = `SteamID64:charN`.
- `SweepOrphanGear` на удаление **одной** ТС **не звать** — он сносит ВСЕ рукава карты. Только `ClearOrphanHoses` / `ClearHosesOn` / `DropTruckGear`.
- `grm_fire_addon.zip` патчить **точечно** (в дереве нет всего vFire-пака). Не zip'ить только `addons/grm_fire/` — потеряется пак.
- luaparser паковых `weapon_extinguisher.lua` / `weapon_firehose.lua` ругается на GMod `!` / `continue` — не чинить парсером.
- `dist/grm_economy.zip` после build часто modified только из‑за timestamp — не коммитить специально, если контент не менялся.
- LuaJIT `-bl` в этой сборке нет — синтаксис через `loadstring`.
- Бинарь LuaJIT: `.luabuild/lj/src/luajit`. Иногда пропадает — `make -s -C .luabuild/lj`. Сборка с нуля:
  ```
  mkdir -p .luabuild && cd .luabuild && curl -fsSL -o lj.tar.gz \
    https://codeload.github.com/LuaJIT/LuaJIT/tar.gz/refs/heads/v2.1 && \
    tar xzf lj.tar.gz && mv LuaJIT-2.1 lj && cd lj && make -s
  ```
- `pip install -q --break-system-packages luaparser` каждый ход (исчезает).
- `lua.org` заблокирован; github / pypi / codeload работают.

### Dist raw (владелец качает отсюда)

- https://github.com/DrStrasse/DrStrasse/raw/arena/01a010c8-drstrasse/dist/grm_single_addon.zip
- https://github.com/DrStrasse/DrStrasse/raw/arena/01a010c8-drstrasse/dist/grm_full_code.zip
- https://github.com/DrStrasse/DrStrasse/raw/arena/01a010c8-drstrasse/dist/grm_economy.zip
- https://github.com/DrStrasse/DrStrasse/raw/arena/01a010c8-drstrasse/dist/grm_fix_hud_tab_currency.zip
- https://github.com/DrStrasse/DrStrasse/raw/arena/01a010c8-drstrasse/dist/grm_fire_addon.zip

Для пожаров на сервере нужны **оба**: `grm_single_addon.zip` (ядро) + `grm_fire_addon.zip` (vFire + сущности) + рестарт.

---

## 2. Где остановились

Владелец **трижды** прислал `+учёт тушения пожара, уведомление - Пожар локализован/потушен.`

- v1.4.0 (`3430a00`) — первый вариант, условия строгие.
- **v1.4.1 (эта сессия, `arena/019ffd5c-drstrasse`) — усиленный:** мягче локализован (2.5с, peak≥1), peak=min 1 если видели vfire, скан на boot, оба события при тушении после ствола, toast+ChatPrint, получатели SuperAdmin+Dispatch+FightPro+notify-фракции+бойцы+рядом 1500, журнал `/fire_log` + UI.

### Что уже есть (`sh_grm_fire_status.lua` v1.4.1)

- Кластер vFire **480** юн. = один инцидент, peak минимум 1.
- `F.BuildFromExisting()` скан на `InitPostEntity` 1-2с + первый Think + PostCleanupMap.
- Ствол/огнетушитель пишет бойца `NoteFight`, `fought` флаг.
- Сжатие ≤50% пика + 2.5с без роста, peak≥1 → **«Пожар локализован»**.
- 0 клеток при peak≥1 → **«Пожар потушен»**, если до этого не было локализован и `fought` — шлёт оба.
- Получатели: фракции из `/grm_fire_notify` + SuperAdmin + `CanDispatch` + `CanFightPro` + бойцы (по CharacterKey) + рядом 1500, дедуп + чат-дубль.
- Журнал массив `data/grm_fire/log.json` (кап 80) + сеть `GRM_FireLog_Req/Data` + команда `/fire_log` `/журнал_пожаров` `/firelog` + конвар `grm_fire_log`, клиент `GRM.Fire.OpenLogPanel` DListView, кнопка во вкладке «Пожарные».
- Хуки `GRM_FireLocalized` / `GRM_FireExtinguished`.
- Think 0.8 с + `vFireCreated` / `vFireRemoved` (recount через timer.Simple(0)).

### Что закрыто в v1.4.1

1. peak=0 на remove → теперь `max(peak,1)` и `peak=1` при создании.
2. Скан живых vfire на boot — `BuildFromExisting`.
3. UI журнала + команда — сделано.
4. Тост+чат + расширенные получатели — сделано.
5. Крошечный очаг 1-2 клетки — теперь всегда потушен, а при fought — сначала локализован.
6. Стенды: `sim_fire.lua` + `sim_fire_rewind.lua` — 0 fails (версия 1.4.1, новые якоря).

### Следующий заказ владельца (после пожаров)

> «Доделываем пожарку, затем делаем систему лицензий, документы соответственно и нужно будет переработать компьютеры, электронику. Там был полноценный компьютерный модуль с полноценной операционной системой, но я всё никак не мог сделать там фоторобот + печать фоторобота + печать любых фоток и т.д.»

То есть Код 59+ — лицензии/документы + компьютерный модуль v2.0 + фоторобот и печать.

Стенды на HEAD: `sim_fire.lua` + `sim_fire_rewind.lua` — 0 fails, single/full zip пересобраны.

---

## 3. Карта пожаров (Код 58) — что уже сделано

Готовой системы пожаров в GRM lua не было. Контент — `addons/grm_fire/` на базе `vFire PACK.zip` (коммит владельца `23dd53c`).

### Версии

| Что | Версия | Файл |
|---|---|---|
| Ядро | **v1.4.1** | `lua/autorun/sh_grm_fire.lua` |
| Доступ / notify | v1.4.1 + журнал | `sh_grm_fire_access.lua` |
| Машина | — | `sh_grm_fire_truck.lua` |
| G-меню насоса | — | `sh_grm_fire_pump_ui.lua` |
| Точки очага | — | `sh_grm_fire_spots.lua` |
| Учёт тушения | **v1.4.1** | `sh_grm_fire_status.lua` — мягче, скан, оба события, toast+chat, 1500, /fire_log |
| Аддон | **0.5.0** | `addons/grm_fire/lua/autorun/sh_grm_fire_addon.lua` |
| Инкассация | **v2.2.2** | `lua/autorun/sh_grm_incassation.lua` |
| HUD | **v10.3** | `lua/autorun/client/cl_grm_hud.lua` |

### vFire API (не ломать)

`CreateVFire` / `CreateVFireBall`; `ent:Ignite()` / `Extinguish()` / `IsOnFire()` перехвачены; `SoftExtinguish` / `ChangeLife` / `GetFireState`; хуки `vFireCreated` / `vFireRemoved` / `vFireEntityStartedBurning` / `vFireEntityStoppedBurning`; флаги `vFireInstalled`, `vFireVersion=1`, `GRM_FireAddon`, `GRM.FireAddon.Version`.  
Workshop `1525218777` и `104607228` сняты.  
`hook.Run("vFireRemoved", self, parent)` — сущность ещё часто валидна; recount через `timer.Simple(0)`.

### Модели оружия `_grm`

`models/weapons/c_firehose_grm.mdl`, `w_firehose_grm.mdl`, `c_fire_extinguisher_grm.mdl`, `w_fire_extinguisher_grm.mdl`.

### CSS/HL2 фолбэки

| Что | Модель | Заметка |
|---|---|---|
| Гидрант | `cs_assault/FireHydrant` / `valvewheel001` | — |
| Шкаф | `cs_office/fire_extinguisher` / `canister01a` | — |
| Насос | `models/props_lab/tpplugholder_single.mdl` | голограмма, SOLID_BBOX, COLLISION_GROUP_WEAPON, без phys |
| Лестница | `models/props/de_train/ladderaluminium.mdl` / `metalladder002` | — |
| Точка очага | `models/props_junk/PopCan01a.mdl` | маркер рисует тул, не модель |

### Кто пожарный / какая ТС

- Spawn-name в `/fire_trucks` у включённой фракции; или висит `grm_fire_pump`; или SuperAdmin `/firetruck`.
- Доступ: SuperAdmin всегда; иначе `F.CanFightPro` (галочка Control в `/fire_access`) + фракция enabled + роль если список не пуст.
- `F.AttachPump` offset `Vector(0,-46,16)` ang `Angle(0,90,0)`, 4 рукава, бак вода **4000** / пена **500** / порошок **250**.
- NW: `GRM_FireTruck`, `GRM_FireFaction`, `GRM_FireSpawnName`, `GRM_FireHoses`, `GRM_FireTank`/`Foam`/`Powder` + Max, `GRM_FireAgent`, игрок `GRM_FireMyTruck`.
- Команды: `/firetruck` `!firetruck` `/feuer` `/пожарка` `/пм`; стоп `/firetruck_off` `/пожарка_стоп` `/feuer_off`; админ `/fire_trucks`; рукав `/рукав` `/hose` `/ствол`.

### Бак / напор

Автозаливки нет (Think насоса больше не льёт +25/с). Рукав от насоса списывает агент: вода **8** / пена **4** / порошок **2** за тик 0.09 с. Прямая подача с гидранта — тумблер в G-меню. Закачка только кнопкой при связанном гидранте (вода/пена) или шкафе (порошок). Связь: открытый гидрант в **380** юн. или кнопка «Связать» → `A.LaySupplyLine` до 2200.

### G-меню насоса

После `/firetruck` или посадки KEY_G у машины/насоса. XUI-стиль. Полосы с NetworkVar насоса, **не** net-спам Think. G тогглит. ShowCloseButton(false). Антидребезг 0.2 с сервер / 0.35 с G.  
Кнопки: **ВЗЯТЬ РУКАВ / СТВОЛ С МАШИНЫ**, Смотать, Связать с гидрантом, вода/пена/порошок, насос вкл/выкл, закачка, прямая подача, слить.  
G насоса **только** в `F.IsFireGContext`, не «везде на дежурстве».

### Рукав (визуал + физика укладки)

- Сервер шлёт ломаную `GRM_FireHose_Path` (векторы узлов).
- Клиент: толстая красная лента `render.SetColorMaterial` + `DrawBox` + `DrawLine` (`GRM_FireHose_Vis`). **DrawBeam не основа** (UnlitGeneric в Source не рисует пикселей).
- Узлы и менеджер `TRANSMIT_ALWAYS`.
- `NetworkVar Vector SrcPos/TailPos` + `SyncAnchors` каждый Think — лента едет с машиной без PVS насоса.
- При выдаче сразу LAY на земле (`GroundSnap`). Машина уехала — `PayoutFromSource` / `InsertLayAt(2)` досевает колышки у катушки, готовый путь не двигает.
- Клиент: насос → `dropGround` → колышки → ноги → рука. Плоская лента `HoseBeamHalfW=1.35` / `HoseBeamHalfH=0.28`.
- MaxLength 2200, LayStep 40.
- Смотка: `TryRewind` / `IsWalkingBack` / `ReelIn` (ALT) / `A.HoseMoveHint` (проекция t≤0.93, S/`IN_BACK`). Всё на **сервере** в `grm_fire_hose/init.lua`.
- E на свой насос / кнопка «Смотать» = `A.RewindAtSource` / `A.ReturnHose`.

### Удаление ТС

`EntityRemoved` **без** `IsValid`-барьера (движок уже помечает ТС невалидным). `looksLikeTruck` (NW `GRM_FireTruck` + IsVehicle + simfphys_/lvs_/glide_/gmod_sent_vehicle/prop_vehicle_/`vehicle` в классе). `A.ClearHosesOn` / `A.HoseTouches` / `A.ClearOrphanHoses` на том же и следующем тике. Насос `OnRemove`. Рукав без `StartEnt` в Think → `Rewind`. Клиент `DrawAllHoses` выкидывает путь если `Entity(id)` мёртв.

### Лестница

Entity `grm_fire_ladder` + SWEP `weapon_grm_ladder`. E взять, ЛКМ поставить, ПКМ по машине закрепить, E на борту выдвинуть, Shift+E снять, W/прыжок лезть (`SetupMove`).

### Тул `grm_fire_place`

`TOOL.Category = "GRM"` + строка в `QM.ToolCatalog` / Schema. Типы: hydrant/pump/cabinet/spot/ladder. Cvars: `grm_fire_place_type`, `grm_fire_place_weight`, `grm_fire_place_label`, `grm_fire_place_feed`.

### Перм-классы

`grm_fire_hydrant`, `grm_fire_pump`, `grm_fire_cabinet`, `grm_fire_spot`, `grm_fire_ladder`. Hose / hose_node **не** пермятся. Бортовое железо `_grmTruckGear` / NW `GRM_TruckGear` AutoPerm не берёт.

### Точки очага

SOLID_BBOX / COLLISION_GROUP_WEAPON / TRANSMIT_ALWAYS, без NoDraw. Клиент `GRM_FireSpot_Vis` рисует столб+метку **только SuperAdmin с `gmod_tool` mode=`grm_fire_place`**. ЛКМ поставить/обновить; ПКМ `IgniteSpot`; R удалить (сфера 80 юн.). NetworkVar: Weight, LastIgnite, CoolSec, Feed, SpotOn, SpotLabel.  
`/fire_spots` `/очаги` `/пожары_очаги`. Конфиг `data/grm_fire/config.json` (version=1, random/stove/min_sec/max_sec/cooldown/max_incidents/ttl; jsonT false/true, карантин, read-back). Дефолт: RandomEnabled, RandomMinSec=480, RandomMaxSec=900, SpotCooldownSec=2700, MaxIncidents=8, PersistTTL=1800. Выключенная точка в рандом не берётся.

### Данные

`data/grm_fire/trucks.json`, `access.json`, `notify.json`, `active_<map>.json`, `config.json`, `log.json`.

---

## 4. Журнал ошибок и граблей (пожары + среда)

Каждая строка = реальный репорт владельца. Не повторять фикс, который уже откатили/усиливали.

| # | Симптом | Корень | Фикс / коммит | Не делать снова |
|---|---|---|---|---|
| 105 | `weapon_extinguisher.lua:286: 'end' expected` | `if ( SERVER ) then` без end после снятия AddWorkshop | убрать строку целиком `b400829` | не комментировать `if SERVER` |
| 106 | фиолетовые ERROR-столбы; насос толкает ТС; длина 850; тул не в GRM | hunter cube нет на сервере; SOLID_VPHYSICS на борту | без модели на узлах; насос BBOX/tpplugholder; 2200; Category=GRM | не ставить hunter cube |
| 107 | бак 19645 / не падает | Think +25/с + SupplyPump nil + SprayCost=1 | нет автозаливки; Consume всегда; 8/4/2 | не возвращать Fill(25) |
| 108 | G-меню рябит, кнопки через раз, окна множатся | NET_DATA каждый раз Remove+Create + Think 2/с | одно окно, NetworkVar, антидребезг `370e166` | не звать openUI на каждый пакет |
| 109 | краш `getMyIncassCarClient` nil на G по гидранту | local функция ниже хука G | поднять выше; skip `grm_fire_*` `56bb854` | local ниже hook.Add |
| 110 | колесо физгана роняет проп | HUD selectorTimeout=3 → SelectWeapon | `IsPropToolBusy` `2ed0e61` | не путать с HOLD-Q |
| 111–112 | рукав только с гидранта; нет кнопки; кабель не виден | насос NotSolid; кнопок не рисовали; alpha=0; redcable нет | EnsureTruckPump; кнопки; свой материал `a70f6a2` | — |
| 113 | кабель всё равно не виден | DrawBeam+UnlitGeneric = 0 пикселей; узлы вне PVS | Path-net + ColorMaterial+DrawBox `e498cef` | не возвращать DrawBeam как основу |
| 114 | насосы в воздухе после рестарта | AutoPerm писал бортовой насос по миру | TruckGear; SweepOrphanGear boot `5ab55b2` | AttachPump не шлёт Placed |
| 115–116 | назад не сматывает | лимит 87 юн. + условие «ближе к prev» | HoseMoveHint + ReelIn ALT `de2aac3` | не возвращать LayStep*1.25 |
| 117–118 | машина уехала — лента на месте | снимок пути; StartEnt вне PVS | SrcPos NetworkVar `f18bd5e` | не брать конец с GetStartEnt на клиенте |
| 119 | прямая балка по воздуху | FollowHost тащил все колышки + pts[1]=насос | PayoutFromSource, dropGround `7271d32` | не DragNode held-рукава в FollowHost |
| 120–121 | удалили ТС — рукава остались | EntityRemoved + IsValid-барьер | без IsValid + ClearOrphanHoses `4321922` | **не** SweepOrphanGear на одну ТС |
| 122–123 | G у пожарки орёт инкассацией | хук смотрел только `grm_fire_*`; без рейса term_use орёт | IsFireGContext; без рейса G no-op `063d76d` | не подвязывать G насоса к инкассу |
| 124 | точка очага невидима, R/ПКМ мимо | SetNoDraw+SetNotSolid | BBOX + Vis только с тулом `a75e032` | не возвращать NoDraw на spot |
| 125 | нет «локализован/потушен» | vFireRemoved только снимал маркер | status.lua `3430a00` | см. §2 — условия ещё слишком строгие |

### Прочие грабли среды

- HEAD локально откатился на старый коммит при живом remote — `fetch` + `reset --mixed`.
- `edit_file` врёт об успехе на больших блоках — проверяй `rg`.
- LuaJIT бинарь пропадает из `.luabuild/lj/src/` — `make -s -C .luabuild/lj`.
- `19645` литров в коде не воспроизводится (баки 4000/500/250, clamp max 20000). Скорее мусор NW до фикса Initialize.
- `/incass_off` без рейса по-прежнему орёт — это чат, не G. Не чинить без просьбы.

---

## 5. Заказы владельца по пожарам (порядок)

1. «Пиши серверную часть… подсмотреть incassation» + модели `_grm`.
2. Синтаксис extinguisher (`end` expected).
3. Квадраты/точки невидимы; насос не коллизионный; рукав 2000+; смотка; лестница; тул в GRM. Скрин: фиолетовые ERROR = missing hunter cube.
4. Меню насоса на G: баки, закачка, связь с гидрантом; расход должен падать; лестница aluminium.
5. Кнопки насоса «не функциональны» / рябит / наслоение.
6. Краш `getMyIncassCarClient` + G по гидранту = инкассация + невидимый рукав + кнопка ствола.
7. Скролл / бар выбора оружия vs физган.
8. Рукав только с гидранта; нет кнопки с машины; цвет кабеля.
9. Визуал кабеля на земле (дважды).
10. После рестарта насосы в воздухе.
11. Назад не сматывает (серверная сторона?).
12. Машина уехала — линии на месте; шланг огромный (дважды).
13. Прямая балка по воздуху, скрин `20260814011930_1.jpg` (дважды).
14. Удалили машину — рукава/насос сразу (дважды).
15. G меню опять к инкассации (трижды, злой тон).
16. Точки очага: воспламенение, таймеры, видимость с тулом (дважды).
17. Учёт тушения — локализован/потушен (**повторил после `3430a00`** — см. §2).

Скрин (13): игрок «Александр Фон Грённер» (Полевая Жандармерия) у красной FD-машины; оранжевая прямая балка торс→насос; HUD `НАПОР вода 3996/4000  0 / 2200 юн`. laid=0 был **до** `7271d32`.

---

## 6. Диагностика, если владелец снова орёт

| Жалоба | Что спросить / проверить |
|---|---|
| Ствол не выдаётся | Тост: «нет доступа» = нет FightPro в `/fire_access`; «нет свободных рукавов» = 4 слота; «аддон рукава не загружен» = нет `grm_fire_addon.zip` |
| Кабель не виден / опять балка | Оба zip + рестарт; после шага HUD laid > 0; доходит ли `GRM_FireHose_Path` |
| Удалил машину — рукава остались | Класс ТС (looksLikeTruck) + оба zip + рестарт. Не звать SweepOrphanGear |
| Точка не видна | Суперадмин? В руках именно `gmod_tool` mode `grm_fire_place`? Оба zip |
| G → «нет рейса инкассации» | `grm_single_addon.zip` + рестарт (инкассация в нём, не в fire-аддоне) |
| Нет «локализован/потушен» | Рестарт single zip; `/grm_fire_notify` (фракции); тушили ли стволом; см. §2 — условия строгие |
| Насос в воздухе после рестарта | Должно быть закрыто `5ab55b2`. Если нет — перм-JSON, класс, mounted |

---

## 7. Файлы, которые трогать / не трогать

### Трогать при работе над пожарами

```
lua/autorun/sh_grm_fire.lua
lua/autorun/sh_grm_fire_access.lua
lua/autorun/sh_grm_fire_truck.lua
lua/autorun/sh_grm_fire_pump_ui.lua
lua/autorun/sh_grm_fire_spots.lua
lua/autorun/sh_grm_fire_status.lua
lua/autorun/sh_grm_incassation.lua          # только G-контекст, не логику рейса
addons/grm_fire/lua/autorun/sh_grm_fire_addon.lua
addons/grm_fire/lua/autorun/sh_grm_fire_hose.lua
addons/grm_fire/lua/entities/grm_fire_*
addons/grm_fire/lua/weapons/weapon_grm_hose.lua
addons/grm_fire/lua/weapons/weapon_grm_ladder.lua
addons/grm_fire/lua/weapons/gmod_tool/stools/grm_fire_place.lua
tools/luatest/sim_fire.lua
tools/luatest/sim_fire_rewind.lua
README.md  (строка модуля 58)
ANALYSIS.md (новая находка 126+)
HANDOVER.md / этот CHECKPOINT.md
```

Q-меню: **только** каталог/схема `grm_fire_place`, не логика HOLD-Q.

### Не трогать без прямой просьбы

- `sh_factions.lua`
- `sh_grm_qmenu.lua` логика HOLD-Q
- FFD / keypad
- двери v3
- принтер / пресс
- валюта / экономика / банк (кроме если сам сломал)
- ветки E2

---

## 8. Чеклист хода после любой правки lua

1. Правка + сразу `rg` что текст на месте.
2. Синтаксис: LuaJIT `loadstring` (не `-bl`).
3. Стенды: как минимум `sim_fire.lua` и `sim_fire_rewind.lua`. Если ядро валюты/пермов — ещё `roundtrip_test.lua`.
4. `python3 tools/build_dist.py` (все zip).
5. README строка модуля + ANALYSIS новая находка + HANDOVER/CHECKPOINT.
6. `git add` нужное (не `.luabuild/`, не случайный economy.zip если только timestamp).
7. `git commit` + `git push origin arena/019ffaa2-drstrasse`.
8. Владельцу — проза + raw-ссылки на zip. Код в чат не слать.

---

## 9. Что делать сразу после прочтения (обновлено 2026-08-14)

1. `git fetch origin arena/019ffd5c-drstrasse && git reset --mixed FETCH_HEAD` (ветка этой сессии) + `git log -1`. HEAD теперь **v1.4.1**.
2. Пожары **закрыты v1.4.1** — стенды 0 fails, zip пересобраны. Если владелец подтвердит — переходить к Коду 59.
3. Если новый репорт по пожарам — таблица §6, потом код.
4. Код 59 — лицензии/документы + компьютеры/электроника v2.0 + фоторобот (см. §11). Не начинать без концепта.

---

## 10. Старые открытые нитки (не пожары)

- Финансовая сага закрыта (наличка и счёт переживают рестарт). Корень был `JSONToTable` без `ignoreConversions` (находка 65).
- Не сделано из старых хотелок: entity `sent_vehicle_dealer`, `grm_item_drop`, радио (RadioFrequencies global).
- SteamID64 владельца для белого списка econadmin так и не предоставлен.
- Название внешнего «писателя» `grm_wallet.json` (массив name/balance) не вскрыто — ныне безвреден, всеядный загрузчик его жрёт.

---

## 11. Следующий этап — Код 59/60: лицензии и документы (ОС/фоторобот УДАЛЕНЫ)

> **АКТУАЛЬНО (2026-08-15):** компьютер со своей ОС (GRM NET OS), сетевые устройства,
> принтер и фоторобот **снесены из сборки** по требованию владельца («сделаем проще»,
> находка 133). Ведомственные компьютеры (`grm_doc_computer`, `grm_comp_*`) остались.
> Фокус — лицензии: водительские v2 (сроки/баллы, находка 128) + **лицензия на оружие**
> и **лицензия на ведение бизнеса** (находка 134). Остаток: госпошлина через
> `GRM.Services.Charge`, экзамены на права, интеграция проверок оружия/бизнеса.
> Подробно — `CONCEPT_LICENSES_V2.md` §9–11.

## 11a. (историческое) Код 59: лицензии, документы, компьютеры, электроника, фоторобот

**Заказ владельца (после пожаров):**
> Доделываем пожарку, затем делаем систему лицензий, документы соответственно и нужно будет переработать компьютеры, электронику. Там был полноценный компьютерный модуль с полноценной операционной системой, но я всё никак не мог сделать там фоторобот + печать фоторобота + печать любых фоток и т.д.

### Что есть сейчас

- **Документы v1.4.1** (`sh_grm_documents.lua`): паспорт, ксива, военник, водительские (ГАИ гражданские A-E+СПЕЦ, ВАИ военные A-В…СПЕЦ-В + 6 допусков), прикрытие, двухфазный рендер, C-меню, `/show*`, проверка при посадке, `grm_doc_computer` 6 вкладок.
- **Компьютеры:** 6 ведомственных `grm_comp_*` (police/military_police/security/military/traffic/medical) + `grm_doc_computer` + `grm_bank_computer` + **GRM NET OS v1.5.1** (`sh_grm_electronics.lua` + cl): роутеры, компы `grm_net_computer`, принтеры `grm_net_printer`, файлы per-device `data/grm_electronics/`, почта, аккаунты, модули (faction/arrest/fines/cctv/roomtap/services), `grm_net_document` entity для печати.
- **Фоторобот:** в `cl_grm_electronics.lua` есть `photoPage()` + `photoEditor()` — база частей лица (face/hair/eyes/brows/nose/mouth/chin/extras), цвета кожи/волос/глаз, эффекты (bw/sepia/vintage/grain/highcontrast), `render.Capture` JPEG, сохранение в `data/grm_photos/*.jpg`, галерея `photoGallery()`, кнопки Сохранить/Печать/Рассылка. Но печать через `image_save` категорию `photo_print`, а не через `print` op принтера; `print` op ждёт `fileID + printerID` и создаёт `grm_net_document` с DHTML `file://` (ломается), нет превью, нет печати любых фоток (только composite).

### Что делать — концепт Кода 59 v2.0

**59.1. Лицензии v2.0:** 
- Переработать категории под реальные: добавить подкатегории BE/CE/DE, стаж, очки, мед.ограничения, срок действия прав, приостановка/лишение через терминал ГИБДД/ВАИ.
- Связка с банком: госпошлина через `GRM.Services.Charge` (уже есть).
- Экзамен: теория (тест в компе) + практика (чекпоинт на маршруте).

**59.2. Документы v2.0:**
- Фото из фоторобота как аватар в паспорте/ксиве (сейчас `AvatarImage` Steam).
- Watermark/QR на документах для проверки подлинности через терминал.
- Реестр утерь/краж.

**59.3. Компьютеры / Электроника v2.0 — главный блок:**
- **OS:** оставить GRM NET OS, добавить оконный менеджер (drag, minimize), файл-менеджер с разделением по категориям photo/doc.
- **Фоторобот 2.0:** сохранить текущий редактор, починить `render.Capture` (делать в `PostRender` или `RT` + `GetTexture`), сохранять как `data/grm_computer/images/*.jpg`, добавить `imagePath` в `E.Files` + бинд к `grm_net_document:SetDocumentImage(path)`, печать через существующий `print` op: `fileID + printerID + paperSize + copies`. Добавить импорт фото игрока (из `data/` или URL) — «любая фотка».
- **Печать:** универсальная: любой файл категории photo/doc/drawing может печататься. Принтер entity `grm_net_printer` спавнит `grm_net_document` с `SetModel("models/props_lab/clipboard.mdl")` + `SetDocumentImage` для фото + `DocumentContent` для текста. Preview в OS уже есть (`preview` panel в printPanel), починить превью альбом/книжная.
- **Фото-архив полиции:** комп `grm_comp_police` вкладка «Фотороботы» — список сохранённых из OS, поиск по приметам, привязка к делу розыска (`GRM.Wanted.AddCustomCharge` с фото).
- **Интеграция:** `grm_net_computer` OS Type `lawenforcement` получает доступ к `photorobot` + `CCTV` + `fines`. Тип `civilian` — без фоторобота.
- **Сеть:** уже есть `GRM_Net_PrintJob`, `GRM_Net_Document`, `image_save` — оставить, добавить rate-limit и проверку дистанции (UseRange 200 уже есть).

**Тех-долг перед Кодом 59:**
- Убрать дубли фото-логики: `cl_grm_electronics.lua` имеет два пути сохранения (photo и photo_print) — унифицировать.
- Проверка `file.Exists` + `../data/` для DImage — заменить на `Material("data/...")` или `DHTML` с base64.
- Добавить `PERM_CLASSES` для `grm_net_printer` и `grm_net_computer` если нет.

**Тесты для 59:**
- `sim_photorobot.lua`: creation, save JPEG non-empty, file registered in `E.Files`, print spawns `grm_net_document` with imagePath, access by OS type.
- `sim_documents_v2.lua`: license expiry, photo from photorobot linked.

Начать с CONCEPT_59.md потом код. Следующий номер после — Код 60.

Конец чекпоинта. Следующий агент стартует отсюда.

---

## Ход 19.08 (теги отделов, окно /factions, мусоровоз, уборка ТС у дилера)

* `/factions`: окно 0.95×0.92 экрана (до 1920×1120), кнопки структуры докнуты.
* Теги отделов (`DepartmentTags`) и подотделов редактируются в «Структуре» и
  печатаются в `/fr`, `/frb`, `/dep`, `/d`, `/depb`, `/db` и над игроком через
  `GRM.Factions.ChannelTag`.
* На игроке: `GRM_Subdepartment`, `GRM_DepartmentTag`, `GRM_SubdepartmentTag`,
  `GRM_ChannelTag` (+ display-варианты).
* Мусоровоз: маршрут по точкам, мусорка опциональна, сверка не переписывает
  рейс, сбор на точке клавишей G, `JB.BinForPoint`, `JB.CollectAtPoint`.
* Дилер v3.4.0: раздел «На карте (убрать)», операция `remove`.
* Не проверено вживую: теги в эфире на полном сервере, сбор без контейнера,
  уборка служебного ТС из меню дилера.

## Ход 19.08 (2) — модуль гаражей

* `GRM.Garage` v1.0.0 (`sh_grm_garage.lua`): зоны, места, стойки, типы,
  плата, привязка дилеров, `data/grm_garage/<карта>.json`.
* Тул «GRM: гаражи», энтити `grm_garage_terminal`, окно `cl_grm_garage_ui`.
* Дилер v3.5.0: общий слой `VD.IssueRecord / VD.StoreRecord`,
  `VD.Spawn(class, dealer, ply, place)`; конвар `grm_garage_strict`.
* Документ: `CONCEPT_GARAGE.md`. Стенды: `sim_garage_runtime`, `sim_garage_module`.
* Не проверено вживую: разметка тулом на карте, поведение стоек после
  PostCleanupMap, выдача крупных simfphys/LVS машин в тесных боксах.

## Ход 19.08 (3)

* Гараж ↔ двери: `G.LinkDoor`, `G.ByDoor`, `GRM_DoorAccessOverride`,
  `G.ApplyDoorState`, `G.ToggleDoors`; режим тула «Ворота гаража».
* Гараж ↔ дом: `G.LinkProperty`, `G.SyncWithProperty`, `baseKind`; в
  недвижимости появился хук `GRM_PropertyOwnerChanged` (5 точек).
* Фракции: `setRoleKey` + действие + кнопка «Ключ»; хук
  `GRM_FactionRoleKeyRenamed`; подписчики в perms, doors_access, doors.
* Стенды: `sim_role_key_runtime` (25), `sim_garage_runtime` (58),
  `sim_garage_module` (60), `sim_dept_tags` (45).
* Не проверено вживую: привязка ворот на реальной карте, продажа дома с
  гаражом на живом сервере, смена ключа ранга при большом составе.

## Ход 19.08 (4) — категории дверей

* Категории дверей v4: `factions/departments/subdepartments/roles` + флаги
  `everyone/noFaction/canLock/lockAdminOnly/keepLocked/allowBuy`.
* `D.CategoryMatch`, `D.CategoryCanLock`, `D.CategoryOfDoor`, `D.FactionTree`,
  `D.NormalizeCategory`; действия `cat_create/rename/delete/flag/member`,
  `clear_owner`.
* Окно двери → `lua/autorun/client/cl_grm_doors_menu.lua` v2.0.0 (стиль GRM,
  боковое меню, редактор категорий, ширина до 1480).
* Стенды: `sim_door_categories` (30), `sim_door_menu_ui` (39); обновлены
  `sim_doors_admin`, `sim_doors_v3`.
* Не проверено вживую: миграция старого categories.json на живом сервере,
  поведение keepLocked с парными дверями.

## Ход 19.08 (5) — шахта и торгаши

* `GRM.Mining` v2.0.0: цены в `data/grm_mining/prices.json`, `M.Sell`,
  `M.CountOres`, `M.GiveTool/ReturnTool` (залог `grm_mining_deposit`),
  `M.ToolClass`, `M.PushProgress`.
* Окно скупщика и вывески торгашей/скупщика — стиль GRM, 3D2D.
* Убран дубль `net.Receive("grm_ore_sell")` (две регистрации затирали друг друга).
* Стенды: `sim_mining_runtime` (23), `sim_mining_ui` (44).
* Не проверено вживую: наличие аддона бура на сервере, залог на живой
  экономике, подбор кучки руды при полном инвентаре.

## Ход 19.08 (6) — лимит машин по классу

* Дилер v3.6.0: `grm_vd_class_limit` (2), `VD.CountClass`, `VD.CanOwnMore`,
  `VD.TagVehicle`, `VD.IsDealerVehicle`; каталог отдаёт `owned`/`classLimit`.
* Клиент дилера v4.2.0: «У вас: N из 2», кнопка «ЛИМИТ» на пределе.
* Стенд: `sim_vehicle_class_limit` (32).
* Не проверено вживую: поведение с машинами, выданными до обновления (у них
  метки появятся при следующей выдаче из гаража).

## Ход 19.08 (7) — выдача покупок и выкуп государством

* Дилер v3.7.0: настройки `delivery` (dealer/garage/both) и `showRetrieve`
  в админке дилера, проверки на сервере.
* Дилер v3.8.0: `grm_vd_state_buyback` (93%), `VD.StateBuybackPrice`,
  кнопка «ПРОДАТЬ ГОСУДАРСТВУ · сумма», списание из казны, аудит.
* Клиент дилера v4.5.0.
* Не проверено вживую: списание из казны при пустом бюджете (сейчас уходит
  в минус по модулю экономики — при необходимости добавим отказ).

## Ход 19.08 (8) — концепция ID / шапки / pcboard

* Написан `CONCEPT_PCBOARD_IDENTITY.md`: реестр PID/CID, объединение двух
  HUD над головой, ID в чате и фракциях, планшет `/pcboard` с уровнями
  допуска и провайдерами данных, вкладка «Госбаза» в /factions, антиабьюз.
* Код НЕ писался — ждём ответов владельца на 6 вопросов из раздела 7.

## Ход 19.08 (9) — реестр ID

* `GRM.Registry` v1.0.0: ГР-#### (персонаж) и ИГ-#### (игрок),
  `data/grm_identity/registry.json`, `Resolve`, `R.Lower`, `/id`.
* Номера: служебные каналы, колонка ID в составе, админ-панель.
* Новое действие админки `ban_id` (офлайн-бан по номеру) и `id_lookup`.
* Стенды: `sim_registry_runtime` (31), `sim_registry_ui` (29).
* Дальше по концепции: шапка над головой v3 («Неизвестный» до документа),
  затем /pcboard с уровнями допуска и вкладка «Госбаза» в /factions.

## Ход 20.08 (1) — планшет госслужб /pcboard

* `GRM.PCBoard` v1.0.0 (`sh_grm_pcboard.lua`): уровни допуска
  (правоохранительный / комендатура / медицинский / спецслужбы /
  администрация) по цепочке организация → отдел → подотдел → должность,
  поверх — галочки блоков в трёх состояниях.
* 13 провайдеров данных из существующих модулей: личность (паспорт + номер
  ГР), розыск, штрафы, удостоверения и лицензии, воинский учёт, место службы,
  транспорт (гараж дилера), недвижимость, образование, медкарта, легенды,
  «кто пробивал раньше», служебные данные аккаунта (только администрации).
* Антиабьюз: два РП-действия через систему, справка только запросившему,
  кулдаун (8 с), лимит (3/мин), журнал `data/grm_pcboard/log.json` +
  `GRM.Audit`, право `pcboard.audit`, скрытый запрос только спецслужбам и
  всё равно в журнал.
* Команды: `/pcboard` (по прицелу), `/pcboard ГР-1042`, `/pcboard <имя>`,
  `/pcboard авто <номер>`, `/pcboard я`, `/pcboard журнал`,
  `/pcboard скрытно …`, псевдоним `/пробить`, консоль `grm_pcboard`,
  `grm_pcboard_log`, `grm_pcboard_access`, `grm_pcboard_window`.
* Вкладка «Госбаза» в `/factions` (`cl_grm_pcboard_ui.lua`): дерево узлов
  организации, уровень узла, галочки блоков, лимиты и переключатели.
  Хранение `data/grm_pcboard/access.json`.
* Стенды: `sim_pcboard_runtime` (89), `sim_pcboard_ui` (48).
* Ловушка Lua, найденная прогоном: `overrides[key] or nil` съедает `false` —
  «принудительно выключенный блок» переставал выключаться.
* Не проверено вживую: реальные поля военного билета и медкарты на сервере
  владельца (в справку выводятся те, что есть в реестрах модулей).
* Дальше по концепции: шапка над головой v3 («Неизвестный» до предъявления
  документа) и кнопки /pcboard в служебных компьютерах.

## Ход 20.08 (2) — шапка над головой v3 и кнопки /pcboard в терминалах

* `GRM.Nameplate` v1.0.0 (`sh_grm_nameplate.lua`): ОДИН `HUDPaint` вместо
  двух (`Factions_HUD` + `GRM_RPDesc` снимаются после загрузки), одна
  плашка «имя · номер / тег и должность / описание», общий радиус
  `grm_cl_nameplate_dist`, кэш переноса строк.
* Имя незнакомым скрыто: «Неизвестный (муж.)» — пол берётся из паспорта.
  Знакомство: `/представиться` (все в радиусе), `/паспорт` (цель в прицеле),
  успешное `/pcboard` (сотрудник запомнил лицо). Знакомства односторонние,
  живут в `data/grm_identity/acquaintance.json`, есть `/знакомые`.
* Под легендой (маскировка) показывается прикрытие и знакомство НЕ пишется.
* Тег организации и должность — только на службе; номер ГР по настройке
  `grm_nameplate_cid` (never / gov / all); режим имени `grm_nameplate_mode`
  (open / acquainted / docs, по умолчанию docs).
* Особые приметы: `/приметы` (редактор), хранение
  `data/grm_identity/marks.json`, показ — только в справке `/pcboard`
  (новый блок «Внешность и особые приметы»).
* Вкладка «Госбаза» добавлена в 9 служебных компьютеров: поле запроса,
  «Пробить», «Моя карточка», «Журнал», живая карточка справки.
* Стенды: `sim_nameplate_runtime` (57), `sim_nameplate_ui` (44).
* Ловушка, пойманная стендом состава: помощник `mkButton` объявлялся НИЖЕ
  функции, которая его вызывает — перенесён выше (правило форвард-локалов).
* Не проверено вживую: снятие старых HUD на живом сервере (если чей-то
  аддон вешает свой `HUDPaint` с другим именем — пришлите скрин).

## Ход 21.08 (1) — окно «Госбаза» крупнее и читаемее

* Заказ владельца по скриншоту: «меню настроек побольше бы в размере».
* Окно доступов теперь тянется под экран (86% ширины / 88% высоты, но не
  меньше 1020×700) и меняется мышью (`SetSizable`); окно справки — 42%/78%.
* Левая колонка шире (30% окна, до 460 px), строки узлов выше (34 px),
  длинные названия отделов обрезаются с многоточием по фактической ширине
  и по границам UTF-8 — раньше «Подотдел: Управление Начальника ВАИ
  Гарнизона» налезал на метку уровня.
* Нижняя панель: подпись поля рисуется НАД вводом (раньше «Кулдаун, с»
  уезжал под сам DNumberWang), галочки получили явную ширину и видимый
  текст (у DCheckBoxLabel в Dock ширина от текста не считается), появилась
  подсказка «изменения применяются после Сохранить».
* Стенд `sim_pcboard_ui` дополнен разделом про размер и читаемость (56).

## Ход 21.08 (2) — микрофризы: очередь записи, пачки синхронизаций, ворота аудита

* Заказ: «синхронизация, разбитие на части и порядок выполнения кода,
  проверка всех модулей, чтобы ничего не вызывало микрофризы; код должен
  выполняться по степени важности, порционно».
* Новый слой `GRM.Save` v1.0.0 (`sh_05_grm_save.lua`): модуль регистрирует
  файл и сборщик, в горячем пути зовёт `Mark` (флаг), писатель пишет не
  более ОДНОГО файла за тик, дорогой реестр сам получает большую задержку,
  сброс при `ShutDown`/`PreCleanupMap`, `grm_save_status`/`grm_save_flush`.
* На очередь переведены: реестр номеров ГР/ИГ, знакомства и приметы шапки,
  журнал и доступы `/pcboard`.
* Синхронизации сведены в пачки через `GRM.Perf.Coalesce`: список персонажей
  (факции, 0.5 c), снимок прав администрации (0.5 c), настройки Q-меню
  (0.5 c), данные карты (0.25 c). Протокол не менялся.
* Стамина: тик 0.1 c → 0.25 c с расчётом по реальной дельте (поведение то же,
  работы вдвое меньше). Второй таймер наручников получил ранний выход.
* `tools/audit_perf.py`: три новые проверки (диск в горячем пути, крупные
  синхронизации, тяжёлый вход игрока), исправлены две ошибки самого аудита
  (обрезка тела хука по отступу; тяжёлый вызов за ранним выходом), добавлен
  режим ворот `--gate` — ненулевой код возврата на критичных находках.
* Полный отчёт: `AUDIT_2026-08-21_MICROFREEZE.md` (там же памятка, как писать
  последующий код: Boot-тиры, Spread, Coalesce, Save, Stream, Guard).
* Стенды: `sim_save_queue` (23 живых), `sim_perf_order` (37).
* Ворота аудита сейчас проходятся; находки, что остались, — осознанные
  (короткие таймеры с ранним выходом, разовые снимки терминалов).
