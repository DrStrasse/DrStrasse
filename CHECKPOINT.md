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

## Ход 21.08 (3) — уровни «Юстиция» и «Пожарная служба» в госбазе

* `PB.Levels` дополнен: `justice` (Юстиция, ранг 3, метка ЮСТ) и `fire`
  (Пожарная служба, ранг 1, метка ПОЖ); оба появились в списке выбора
  редактора «Госбаза».
* Юстиция видит: личность, приметы, розыск и статьи, штрафы, удостоверения,
  воинский учёт, место службы, транспорт, недвижимость, образование, журнал
  пробитий. Медкарта и легенды — только галочкой.
* Пожарная служба видит: личность, приметы, недвижимость (владелец объекта),
  медкарта. Розыск, штрафы, воинский учёт, транспорт — закрыты.
* Скрытый запрос по-прежнему только у спецслужб и администрации.
* Стенды: `sim_pcboard_runtime` (120), `sim_pcboard_ui` (62).

## Ход 21.08 (4) — две плашки над головой и клетка в админ-меню

* Жалоба по скриншоту: над головой рисуются ДВЕ подписи сразу (старая
  плашка описания + старая шапка организации поверх новой).
  Реальная причина: `hook.Remove` не помогает — `sh_grm_rpdesc.lua`
  грузится ПОСЛЕ модуля шапки (алфавит autorun) и вешает свой `HUDPaint`
  заново. Теперь старые отрисовки гасятся В ИСТОЧНИКЕ: обе проверяют флаг
  `GRM.Nameplate.Active` и молчат, пока новая шапка включена. Выключил
  `grm_cl_nameplate 0` — старые вернулись (`cvars.AddChangeCallback`).
* Плашка в транспорте считается от габаритов машины, а не от костей игрока
  (раньше уезжала в кузов).
* Диагностика `grm_nameplate_debug`: режим, радиус, число знакомых и список
  старых отрисовок в `HUDPaint`.
* Клетка (`A.jail`) переписана. Что было не так: стенки ставились на
  фиксированные 48 юнитов при другой ширине модели (щели в углах — человек
  выходил боком), клетка строилась без выравнивания по земле, ничто не
  держало внутри (ноклип, физган, тулган), на каждого заводился свой
  `timer.Simple`. Теперь: расстояние из габаритов модели (OBB), центр по
  трейсу вниз, игрок ставится в центр, «поводок» возвращает вышедшего,
  ноклип/физган/тулган/урон по решёткам запрещены, сроки ведёт ОДИН общий
  таймер 0.5 c, прежняя позиция возвращается при освобождении.
* Стенды: `sim_admin_jail` (28 живых прогонов), `sim_nameplate_ui` (50).

## Ход 21.08 (5) — объявления администрации и живые ранги в TAB

* Новый общий слой `GRM.Admin.Announce(text, kind)`: красная строка ВСЕМ
  игрокам (`[АДМИНИСТРАЦИЯ]` для групп, `[МОДЕРАЦИЯ]` для наказаний) со
  звуком. Один канал на всё, без копий по модулям.
* Смена группы (`AD.ApplyGroup`) объявляется: «кто, кому, из какой группы в
  какую» — названиями групп, а не их id.
* Наказания: формулировки собраны ОДНОЙ таблицей `PUNISH` рядом с
  действиями, объявление уходит из общего приёмника после успешного
  действия. Различается «посадил / выпустил», «закрыл чат / вернул чат» —
  состояние читается ДО выполнения (кнопка одна и та же). В тексте срок
  (клетка, бан) и причина (кик, бан, предупреждение).
* Кнопки наказаний в самом TAB (заглушить, кик, бан, ULX-мут) — отдельный
  путь, их тоже подключили к тому же слою.
* TAB: ранг берётся из `GRM.Admin.GroupOf` (раньше смотрел только в ULib и
  флаги движка — назначение через админ-панель не отражалось вообще),
  группа висит на игроке NW-строкой `GRM_AdminGroup`, в список уходят
  название и цвет группы (свои группы больше не показываются обрубком из
  трёх букв), а по хуку `GRM_AdminGroupChanged` таблица обновляется сразу,
  а не через 5 секунд автообновления.
* Стенды: `sim_admin_announce` (29 живых прогонов), `sim_admin_core` (127).

## Ход 21.08 (6) — пожар: спам «потушен» и лишние вызовы во время тушения

* Реальная причина обоих багов одна: `RefreshIncidents(pos)` вызывался на
  КАЖДУЮ погашенную ячейку vFire и внутри звал `OpenIncident`. Инцидент
  рядом уже был помечен `out` (findInc его не видит) — открывался НОВЫЙ
  инцидент с peak=1 и cells=0, который тут же признавался потушенным
  («Пожар потушен» ещё раз) и по пути дёргал `GRM_FireIncidentOpened`,
  из-за чего диспетчер создавал новый вызов прямо во время тушения.
* Правки: обновление больше НЕ открывает инциденты; `OpenIncident`
  отказывается создавать очаг там, где нет живого огня (кроме
  принудительного скана карты, и у такого «призрака» peak = 0, он молчит);
  вспышка на месте только что потушенного очага (45 с) оживляет ТОТ ЖЕ
  инцидент без нового вызова; `MarkExtinguished` молчит при peak < 1.
* Диспетчер: минуту после закрытия вызова новый вызов рядом (600 юн.) не
  создаётся — `D.RecallGuard`.
* Сообщения: убран безусловный дубль тоста строкой в чат — теперь по
  конвару `grm_fire_chat_dupe` (по умолчанию 0, чат остаётся фолбэком, если
  модуль уведомлений не загружен).
* Журнал пожаров писался «прочитать файл целиком + записать обратно» на
  каждое событие — переведён на очередь `GRM.Save` (память + запись раз в
  10 с).
* Стенд: `sim_fire_incidents` (20 живых прогонов).

## Ход 21.08 (7) — живой пинг в TAB

* Жалоба: пинг меняется только при повторном открытии TAB.
  Причина: строка рисовала значение из СНИМКА сервера, который приходил при
  открытии и раз в 5 секунд; сам пинг доступен на клиенте бесплатно.
* Теперь строка списка берёт `Player:Ping()` у живой entity каждый кадр
  (список игроков кэшируется на секунду, `player.GetAll()` в отрисовке не
  зовётся), а в карточке игрока подпись обновляет себя два раза в секунду.
* Снимок с сервера больше не пересобирает список целиком: при неизменном
  составе поля обновляются на месте (пропали мигание и сброс прокрутки),
  пересборка — только когда кто-то зашёл или вышел. Интервал снимка 5 → 2 с,
  поэтому баланс, фракция и группа тоже свежие.
* Стенд: `sim_tab_menu` (33).

## Ход 21.08 (8) — помощь пострадавшему: вернулась реанимация

* Жалоба: у игрока в окне помощи одна кнопка «Стабилизировать».
  Причина: клиент рисовал «Реанимировать» только при флаге medic, а сервер
  считал его цепочкой, которая ОБРЫВАЛАСЬ на первом источнике —
  `GRM.MedicalFull.IsMedic` (там жёстко зашита фракция «Медики», которой на
  сервере нет) возвращал false, и ни медицинский допуск фракции, ни аптечка
  дальше не проверялись.
* `EM.IsMedic` переписан цепочкой ИЛИ: суперадмин, `MedicalFull.IsMedic`,
  `Medical.CanTreat`, уровень госбазы «Медицинский» или «Пожарная служба»,
  предмет из `EM.ReviveItems` (адреналин, аптечка, дефибриллятор, бинт).
  Возвращает ещё и ПРИЧИНУ отказа.
* Окно пострадавшего переписано: видны все действия — «Стабилизировать»,
  «Реанимировать» (заблокирована с причиной, если нет допуска), «Осмотреть»
  (доступно всем, печатает состояние и даёт РП-действие рядом), «Вызвать
  медицинскую службу (911)». Внизу подсказка, что делать дальше.
* В пакет карточки добавлены кровопотеря, боль и причина отказа.
* Стенд: `sim_911_aid` (23 живых прогона).

## Ход 21.08 (9) — «восстановлено 0 бланков»: причина теперь видна

* Жалоба: C-меню показывает «Восстановить бланки (4)», а восстанавливается 0.
* Реальная причина молчания: команда `/docrestore all` собирала ошибки в
  таблицу и ВЫБРАСЫВАЛА её — игрок видел только счётчик. Сама же выдача чаще
  всего падала на общей блокировке записи: если инвентарь (или реестр
  документов) загрузился из повреждённого файла, любое сохранение
  запрещается на всю сессию, бланк выдаётся и тут же откатывается.
* Теперь: `DOC.StorageBlockedReason()` проверяется ДО выдачи и объясняет
  человеку, что именно заблокировано; `/docrestore all` печатает причины
  (сгруппированные) и счётчик «N из M»; появилась диагностика
  `/docrestore диаг` — состояние хранилища, занятость инвентаря и построчно
  по каждому типу (есть ли запись, копии, статус, кулдаун).
* Инвентарь: добавлены `grm_inv_health` и `grm_inv_unblock confirm`
  (суперадмин) — раньше выйти из блокировки записи было нечем, кроме
  рестарта с ручной правкой файла; при старте в консоль печатается
  громкое предупреждение.
* Стенд: `sim_doc_restore` (17 живых прогонов).

## Ход 21.08 (10) — два вида бана: на сервере и глобальный

* Новый модуль `GRM.ServerBan` v1.0.0 (`sh_grm_ban.lua`).
* **Бан на сервере**: модель `models/player/skeleton.mdl`, материал
  `debugwhite`, красная подсветка, плашка «ЗАБАНЕН» над головой (через общий
  слой шапки, хук `GRM_NameplateOverride`), памятка на экране самому
  наказанному. Оружие изымается, самоубийство, меню F1-F4, физган, тулган,
  транспорт, подбор предметов, спавн и команды в чате закрыты; обычный чат
  оставлен, чтобы человек мог объясниться. Урон по нему и от него не идёт.
* **Зона отбывания**: суперадмин ставит точку по своей позиции
  (`grm_ban_point [радиус]` или кнопка в админ-меню), точка своя на каждую
  карту, хранится в `data/grm_admin/serverban_zone.json`. Сторож 0.5 с
  возвращает вышедшего за радиус и дожимает вид (другие модули любят вернуть
  модель), он же снимает истёкшие баны.
* **Глобальный бан** остался прежним (ULib/ULX, иначе `banid`), рядом
  появилось снятие — действие `unban` по SteamID64 или номеру ИГ-####.
* Админ-меню: «Бан на сервере 60 мин» / «Снять бан сервера», «Глобальный бан
  60 мин», «Глобальный бан навсегда», «РАЗБАНИТЬ» в блоке по ID, блок «Бан на
  сервере · зона отбывания» (радиус, «поставить здесь», «где точка»,
  «кто отбывает»). В карточке игрока появился флаг «БАН НА СЕРВЕРЕ».
* Всё объявляется в чат красной строкой общим слоем `GRM.Admin.Announce`.
* Стенды: `sim_server_ban` (45 живых прогонов), `sim_admin_core` (148).

## Ход 21.08 (11) — бан на сервере: причина, эфир и голод

* В админ-меню отдельный блок «Бан на сервере (деморган)»: поле срока, поле
  ПРИЧИНЫ (без причины кнопка не сработает) и две кнопки — «ЗАБАНИТЬ НА
  СЕРВЕРЕ» и «РАЗБАНИТЬ НА СЕРВЕРЕ». Причина уходит игроку, в объявление и
  в запись бана; автоподстановки «Нарушение правил» больше нет.
* Эфир: единый запрет `SB.SpeechBlocked` / `SB.DenySpeech` с текстом «Вы
  отбываете административное наказание (деморган), поэтому <волна>
  недоступна. Осталось: N мин.». Волны организаций (`/fr`, `/frb`, `/dep`,
  `/d`, `/depb`, `/db`) закрыты В ПРИЁМНИКАХ net, а не только в чате —
  команды туда уходят с клиента пакетом, чат-блокировка их не ловила.
  Радиоэфир (`GRM.RadioNet.VoiceRoute`) наказанного тоже не слышен.
* Чат-команды дают конкретный текст: для волн — про волну и рацию, для
  остальных — общий; обычный чат остался.
* Голод: отбывающие наказание всегда сыты — смерть от голода в деморгане
  это баг, а не наказание.
* Стенды: `sim_server_ban` (61 живой прогон), `sim_admin_core` (160).

## Ход 21.08 (12) — бан: живой таймер, блокировка окон, список и память

* Таймер в памятке наказанного идёт вживую (как пинг в TAB): значение
  считается в самой отрисовке — «Осталось: 12:47», меньше минуты подсвечено
  жёлтым, бессрочный так и подписан.
* Инвентарь закрыт: одна проверка на все действия (открытие, использование,
  выброс, перенос, разделение, уборка оружия) с текстом про наказание.
* «Ничего не открывать»: C-меню и спавн-меню закрыты хуками, а окна, которые
  успел открыть сторонний модуль, закрывает сторож (раз в 0.5 с, не в кадре).
* Список забаненных: `SB.List()` + окно «БАНЫ НА СЕРВЕРЕ» (кнопка «СПИСОК
  ЗАБАНЕННЫХ» в админ-меню, консоль `grm_serverban_menu`): кто, за что, кем
  выдан, сколько осталось, в сети ли, и кнопка «РАЗБАНИТЬ» на каждой строке.
* Память: сами баны и ИСТОРИЯ (последние 200 записей: выдача и снятие с
  причиной и автором) лежат в `data/grm_admin/serverbans.json` и переживают
  перезапуск; при входе бан применяется автоматически.
* Стенды: `sim_server_ban` (71 живой прогон), `sim_admin_core` (174).

## Ход 21.08 (13) — забаненные «звучат»: зомби-стоны

* От отбывающего наказание идут звуки зомби
  (`npc/zombie/zombie_voice_idle1..6.wav`): один стон сразу при бане, дальше
  с паузой 4–9 с. У каждого свой момент следующего звука — толпа скелетов не
  воет в унисон.
* Звук идёт из ОБЩЕГО сторожа банов (без таймера на каждого игрока), по
  каналу `CHAN_VOICE`, со случайной высотой тона.
* Прекэш — через общий звуковой слой `sh_07_grm_sound.lua` (реестр + фолбэк
  на отсутствующий файл), своей копии логики в модуле банов нет.
* Конвары: `grm_ban_zombie_sound` (0 — тишина), `grm_ban_zombie_min`,
  `grm_ban_zombie_max` — пауза между звуками.
* Стенды: `sim_server_ban` (81), `sim_admin_core` (181), `sim_sound_time` (27).

## Ход 21.08 (14) — точка отбывания бана больше не слетает

* Причина: точка хранилась как `Vector`, а `Vector` — это userdata, и
  `util.TableToJSON` пишет его пустышкой. На диск уходило `pos: {}`, после
  рестарта координаты читались нулями и зона считалась незаданной.
* Точка теперь хранится числами `{x, y, z}`, Vector собирается при
  использовании (`SB.ZonePos`). Нулевые координаты из битого файла точкой
  не считаются.
* Запись идёт сразу (`GRM.Save.Flush`), не дожидаясь очереди: точку ставят
  редко, а теряют обидно.
* При загрузке модуль печатает в консоль, есть ли точка на этой карте и
  какой радиус.
* Стенды: `sim_server_ban` (89 живых прогонов, в том числе «рестарт» с
  чтением только с диска), `sim_admin_core` (187). В стенде заменил заглушку
  JSON на настоящий кодировщик — с «{}» эта ошибка была бы не видна.

## Ход 21.08 (15) — фикс: после разбана человек «ничего не мог»

* Две настоящие причины, обе мои:
  1. клиентский сторож окон делал `panel:Remove()` — вместе с чужими окнами
     сносил панель чата (EasyChat). После удаления она уже не создавалась
     заново, поэтому и чат, и меню оставались мёртвыми даже после разбана.
     Теперь сторож только ЗАКРЫВАЕТ окна (`Close`/`SetVisible(false)`), а чат
     и HUD не трогает вовсе (проверка по классу и имени панели);
  2. `SB.Clear` вызывал `ply:Spawn()` — принудительный респавн ломал РП-поток
     модуля персонажей. Теперь снятие возвращает вид и подвижность на месте
     (`Freeze(false)`, `MOVETYPE_WALK`), а снаряжение выдаётся штатным хуком
     `PlayerLoadout`.
* Дополнительно: повторный бан больше не затирает запомненную модель
  скелетом (иначе после разбана человек оставался скелетом); сторож сам
  снимает следы наказания с уже свободного игрока; появилась аварийная
  команда `grm_serverban_fix [SteamID64|me|all]`.
* Стенды: `sim_server_ban` (101 живой прогон), `sim_admin_core` (195).

## Ход 21.08 (16) — фикс: unpooled message name у списка банов

* `grm_serverban_menu` падал с «Calling net.Start with unpooled message
  name»: в модуле банов регистрировался только канал SYNC, а каналы списка
  (LIST_REQ / LIST) добавили позже и строку сети для них — нет.
* Теперь имена регистрируются проходом по таблице `SB.Net` — добавил канал,
  он сразу в пуле.
* В аудит добавлена проверка `net_unpooled`: если в таблице `X.Net` каналов
  больше, чем вызовов `util.AddNetworkString`, и нет прохода по таблице —
  находка попадает в ворота (`--gate` вернёт ошибку). Проверено на
  синтетическом файле: ловится.
* Стенды: `sim_perf_order` (41), `sim_server_ban` (101).

## Ход 21.08 (17) — возврат на исходное место после разбана

* При бане запоминается точка, откуда игрока забрали (числами, в записи
  бана — поэтому переживает рестарт сервера).
* Снятие наказания — ручное, по истечении срока и через аварийную команду —
  возвращает человека ровно туда, откуда он «улетел в бан», и пишет ему
  «Вы возвращены на прежнее место».
* Если игрок перезашёл или сервер перезапускался, точка подхватывается из
  записи при применении бана (`ply.GRM_BanReturn`).
* Стенды: `sim_server_ban` (106 живых прогонов), `sim_admin_core` (200).

## Ход 21.08 (18) — законы: доступы, обновление и рекурсия CAMI

* **`[ULib] stack overflow`**: `AD.Can` спрашивал CAMI → CAMI звал наш хук
  `CAMI.PlayerHasAccess` → хук снова звал `AD.Can` → бесконечный круг.
  Любое действие, где проверялось право (публикация закона в том числе),
  обрывалось на середине — отсюда и «законы не обновляются».
  Разделено: `AD.CanLocal` (наши группы и права, без CAMI) и `AD.Can`
  (локальная проверка + один запрос к CAMI со сторожем глубины). Ответчик
  CAMI отвечает `CanLocal`.
* **Доступы к кодексу**: право `laws.edit` было `minAccess = "admin"` — его
  автоматически получал любой админ/модератор. Теперь `superadmin`, то есть
  только явная выдача (группой или должностью `law_publish`). Удаление —
  отдельное право `laws.remove` / `law_remove`: публикация больше не даёт
  права сносить статьи.
* **Интерфейс кодекса**: у зрителя больше нет ни полей, ни кнопок —
  показывается текст статьи и подпись «правка доступна только уполномоченным
  должностям»; в шапке честный статус «Режим просмотра · правка недоступна».
* **Раздел настроек законов в /factions**: без права управления показывает
  только текущее состояние ролей, галочек нет; сервер при попытке без права
  отвечает сообщением и пересинхронизирует состояние (раньше молчал).
* **Обновление у игроков**: помимо адресной рассылки «зрителям» уходит
  крошечный сигнал `GRM_Laws_Changed` всем — у кого окно открыто, тот сам
  запрашивает свежий список. Расхождение списка зрителей с реальностью
  больше не оставляет людей со старым кодексом.
* Стенды: `sim_laws_access` (35 живых прогонов, включая воспроизведение
  рекурсии CAMI), `sim_admin_core` (200).

## Ход 21.08 (19) — инструмент «GRM Сканер фракций» переработан

* Причина «списка нет»: панель строила чекбоксы из клиентского кэша
  `FactionsData`, которого в момент открытия инструмента может не быть
  (публичный синк приходит позже). Теперь список запрашивается У СЕРВЕРА
  (`GRM_ScannerTool_ListReq` / `GRM_ScannerTool_List`, с `GRM.Net.Guard`).
* В списке человеческие названия, тег организации и число сотрудников,
  сортировка по названию; есть строка поиска, счётчик «показано/выбрано»,
  кнопки «Все», «Снять», «Обновить список»; пока список не пришёл — поле
  ручного ввода, как раньше.
* Отметки складываются в конвар списком через запятую (сканер это и ждёт),
  добавление и снятие не затирают остальной выбор.
* Сообщение сканера об отказе показывает названия организаций, а не
  внутренние ключи.
* Ловушка, найденная стендом Q-меню: у `TOOL` метатаблица-заглушка, поэтому
  `TOOL.FactionRows or {}` возвращал ФУНКЦИЮ и `ipairs` падал. Список теперь
  в локальной переменной файла.
* Стенды: `sim_scanner_tool` (17 живых прогонов), `sim_qmenu_toolpanel` (37).

## Ход 21.08 (20) — приглашение во фракцию не приходило

* Главная причина: меню организаций НЕ слушало канал ответа
  `Factions_ActionResult`. Сервер честно отвечал «Недостаточно прав»,
  «Недопустимая стартовая должность», «Персонаж уже состоит во фракции»,
  «У персонажа уже есть активное приглашение», а меню само рисовало
  «Приглашение отправлено» — лидер был уверен, что отправил, а приглашения
  не существовало. Теперь ответ сервера показывается уведомлением и строкой
  в чат.
* Вторая причина: приглашение сохранялось даже когда персонажа нет в сети
  (или человек играет другим персонажем) — окно доставить некому. Теперь
  такой случай — честный отказ с объяснением, а выдача пишется в консоль.
* Окно приглашения: должность и отдел выбраны заранее, должность лидера в
  список не попадает (сервер её всё равно отклоняет).
* Приглашение возвращается не только при входе и смене персонажа, но и
  после респавна.
* Диагностика `grm_faction_invites`: кому, от кого, из какой организации,
  в сети ли персонаж и сколько осталось.
* Стенд: `sim_faction_invite` (21 проверка).

## Ход 21.08 (21) — антистак транспорта: без столкновений и выход сбоку

* Настоящая причина, почему «сталкивало корпусом»: в распознавании
  транспорта стояла строка «sim_fphys», а классы simfphys называются
  `simfphys_*` (например `simfphys_btr80`). Ни одна машина simfphys под
  проверку не попадала — ни no-collide, ни поиск базы под сиденьем не
  работали. Теперь список подсказок расширен (simfphys, lvs, glide,
  prop_vehicle, gmod_sent_vehicle) и дополнен признаками самих аддонов
  (`IsSimfphysCar`, `LVS`).
* Постоянное отсутствие столкновения «игрок ↔ транспорт»: отдельный хук
  `ShouldCollide` с быстрым выходом (сначала дешёвый IsPlayer). Временный
  no-collide на 1.25 с остался как был — он про другое.
* Выход сбоку от КОРПУСА: точка считается по габаритам базовой машины,
  сторона выбирается та, где игрок, отступ — полшины корпуса плюс
  `SideExitOffset` (10 юнитов). Занят борт — пробуем другой, потом корму и
  нос; свободного места нет — не двигаем вовсе.
* Настройки: `AlwaysNoCollideWithVehicles`, `SideExitOnLeave`,
  `SideExitOffset`.
* Стенд: `sim_vehicle_exit` (20 живых прогонов).

## Ход 21.08 (22) — В/У больше не проверяются при посадке в транспорт

* Убрана автоматическая инспекция водительских прав на хуке
  `PlayerEnteredVehicle` (`sh_grm_documents.lua`). Сообщений вида
  «ВАИ проверено (Категория С)», «В/У проверено», «Нет В/У категории…»,
  «ВУ просрочено» при посадке в машину или на кресло больше нет.
* Проверка не удалена совсем, а переведена в ручной режим: конвар
  `grm_doc_vehicle_check` (по умолчанию 0). Значение 1 возвращает старое
  поведение целиком, если оно когда-нибудь понадобится.
* Проверка документов по требованию (ГАИ/ВАИ, `/pcboard`, досмотр) работает
  как раньше — трогали только автоспам при посадке.
* Стенд: `sim_vehicle_license_notice` (11 живых проверок: тишина по
  умолчанию, грузовик, водитель без прав, кресло, пассажир, включение
  конвара и обратно).

## Ход 21.08 (23) — меню точек спавна переделано: отделы, подотделы, стиль GRM

* Меню `/spawnmenu` больше не «вкладка на каждую организацию с тремя
  подвкладками». Слева — дерево: «Глобальные точки», затем организации,
  внутри — «Точки организации», ОТДЕЛЫ (с вложенными ПОДОТДЕЛАМИ),
  ДОЛЖНОСТИ. У каждого узла счётчик точек, у организации — сумма по всем
  уровням. Есть поиск по организациям, отделам, подотделам и должностям
  (кириллица ищется без учёта регистра), раскрытие/сворачивание узлов.
* Добавлены ТОЧКИ ПОДОТДЕЛОВ — раньше их не было вовсе, хотя подотделы в
  структуре организаций есть. Хранение `subdepartments` в том же файле
  карты, валидация ключа по `f.Subdepartments`.
* Приоритет выдачи точки игроку: подотдел → должность → отдел →
  организация → глобальные (совпадает с логикой выдачи экипировки).
* Справа — карточки точек: номер, координаты, поворот, расстояние до вас,
  кнопки «Телепорт» и «Удалить». Панель действий: «Поставить здесь»,
  «Куда смотрю» (точка по прицелу), «Обновить», «Экспорт», «Очистить узел»
  (с подтверждением). Пустой узел показывает подсказку, а не пустоту.
* Стиль приведён к общему GRM: палитра и шрифты как в едином центре
  организаций, иконки icon16 (мир, здание, папка, подпапка, пользователь,
  стрелки раскрытия, корзина, обновление), скруглённые карточки, свои
  скроллбары, окно масштабируется под разрешение.
* Команда работает и через ванильный чат (`PlayerSay` на сервере), и через
  EasyChat, плюс алиасы `/точкиспавна` и консольная `grm_spawnmenu`.
* Точки узлов, которых уже нет в структуре (удалённый отдел/должность),
  показываются с пометкой «вне структуры» — иначе их нельзя было удалить.
* Стенд: `sim_spawn_menu` (48 проверок), старый `sim_spawn_points` (25) —
  зелёный.

## Ход 21.08 (24) — двери: перестали запираться сами, ключи проверены

* НАСТОЯЩАЯ ПРИЧИНА «дверь сама заперлась через несколько секунд»:
  двустворчатая дверь — это ДВА полотна с ДВУМЯ записями. `LockDoor` писала
  новое состояние только в запись того полотна, по которому кликнули, а
  сторож замков (каждые 2 с) приводил каждую запись к её собственному
  значению — вторая створка возвращала замок и дёргала общий сетевой флаг.
* Теперь у физической двери одно состояние: `D.DoorGroup` собирает полотно,
  его дубли, вторую створку и её дубли; `LockDoor` пишет состояние во ВСЕ
  записи группы и ставит метку времени `lock_at`. Сторож сверяет группу
  целиком (`D.ResolveGroupLock` — побеждает самая свежая запись) и лечит
  старый рассинхрон вместо того, чтобы воевать сам с собой.
* Автоблокировка стала ЯВНОЙ и по умолчанию выключена: конвар
  `grm_door_autolock` (0 — никогда, например 8 — дверь сама запирается через
  8 секунд после отпирания). Выбитые тараном и вскрытые отмычкой двери под
  автоблокировку не попадают.
* Ключи (`ds_key_swep`): раньше проверяли только «есть ли доступ» — замком
  щёлкал любой, у кого есть проход, даже на общественных дверях и там, где
  замок оставлен администрации. Теперь общая проверка `D.CanToggleLock`
  (право на замок + профиль категории), отказ с внятной причиной, «дверь и
  так заперта/открыта» вместо холостого срабатывания, а режим «дверь всегда
  заперта» больше не рапортует «разблокировано» — честно говорит, что дверь
  не отпирается.
* Запись реестра дверей переведена на очередь `GRM.Save` (`grm_doors`,
  задержка 3 с): замок дёргается часто, а каждый щелчок писал JSON на диск.
  Немедленная запись осталась отдельной функцией `D.SaveDoorsNow`.
* Стенд: `sim_door_lock_sync` (33 живые проверки), обновлён `sim_door_menu_ui`.

## Ход 21.08 (25) — категории дверей не прыгают вверх, покупка ≠ выдача

* Список в категориях дверей улетал вверх после КАЖДОЙ галочки, потому что
  на ответ сервера окно двери создавалось ЗАНОВО, а восстановление
  прокрутки не поспевало за раскладкой. Теперь окно живёт дальше: приходит
  свежий снимок той же двери — оно обновляется на месте (`GRMPatch`).
  Если поменялись только галочки (подпись данных `D.MenuSignature` та же) —
  правится состояние чекбоксов, вкладка не пересобирается вообще, прокрутка
  не двигается. Если состав категорий или структура организаций изменились —
  пересобирается только вкладка, а прокрутка запоминается ДО очистки.
  Программная установка галочки не шлёт действие на сервер (не зацикливается).
* Дилер транспорта: «КУПИТЬ» больше НЕ равно «ВЫДАТЬ». Покупка личного
  транспорта только оформляет его в собственность — машина встаёт на
  хранение (и приписывается к выбранному гаражу). На карту она выходит
  отдельной кнопкой «ВЫДАТЬ» во вкладке «Мой транспорт», где игрок выбирает:
  выдать здесь у дилера или подать в гараж (список гаражей с числом мест).
  Служебный транспорт покупкой не является — выдаётся сразу («ПОЛУЧИТЬ»).
* Новое в модуле гаражей: `GRM.Garage.IssueRemote` — подача машины на
  свободное место выбранного гаража издалека (с платой за подачу, проверкой
  доступа и мест).
* Режим дилера теперь ограничивает только выдачу НА МЕСТЕ («Отправлять в
  гараж» = этот дилер машины не отдаёт); подача в гараж доступна всегда,
  пока есть доступный гараж.
* Стенды: `sim_dealer_buy_issue` (20 живых проверок покупки и выдачи),
  дополнены `sim_door_menu_ui` (62), `sim_door_lock_sync` (38),
  обновлены `sim_garage_module`, `sim_vehicle_class_limit`.

## Ход 21.08 (26) — регистрационные номерные знаки

* Новый модуль `GRM.Plates` (`sh_grm_plates.lua`) + сущность `grm_plate`.
* Жизненный цикл знака: регистрация в Полиции / Дорожной инспекции / ВАИ →
  получение физического бланка → установка руками на машину → проверка по
  базе → аннулирование или заявление об утере.
* Физический знак: модель `models/hunter/plates/plate025x075.mdl`, материал
  `models/debug/debugwhite`, номер печатается поверх (3D2D по габаритам
  модели, поэтому надпись не вылезает за края даже при смене модели).
  Ставится физганом куда нужно и крепится нажатием [E] — можно повесить
  и спереди, и сзади. Повторное [E] снимает; сотрудник может изъять.
* Реестр `data/grm_plates/registry.json` через очередь `GRM.Save`: номер,
  тип, владелец, организация, транспорт, статус, кто и когда выдал, история.
* Шесть типов серий со своими шаблонами и цветом знака: гражданский
  (А000ВС), коммерческий, государственный, полицейский, военный,
  транзитный. Буквы — только «читаемые» (АВЕКМНОРСТУХ), латиница при вводе
  автоматически приводится к кириллице.
* Выдача: вкладка «Номерные знаки» в терминалах Полиции, Военной полиции и
  Автоинспекции, окно `/номера`. Проверка: `/номер А123ВС` и та же вкладка.
  Номер видно над машиной и над самим знаком (HUD, трассировка раз в 0.2 с).
* В госбазе (`/pcboard`) появился блок «Транспорт и номерные знаки».
* Знаки помнят своё место: раскладка пишется в запись гаража, после выдачи
  машины из гаража знаки возвращаются на бампера сами.
* Конвары: `grm_plates_limit` (сколько номеров на персонажа, по умолчанию 6),
  `grm_plates_blanks` (сколько физических бланков одного номера, по умолчанию 2).
* Стенд: `sim_plates` (58 живых проверок).

## Ход 21.08 (27) — номера: надпись встала на место, знак крепится

* НАДПИСЬ НЕ БЫЛО ВИДНО и номер стоял поперёк, потому что плоскость 3D2D
  строилась вручную поворотами углов «на глазок». Теперь геометрия лица
  считается чистой функцией `PL.FaceGeometry`: самая тонкая ось габаритов —
  толщина знака (её направление = нормаль), из двух оставшихся ДЛИННАЯ
  всегда идёт вдоль строки номера, короткая — вверх. Угол собирается через
  `Vector:AngleEx`, надпись подгоняется по ширине поля. Номер печатается с
  ОБЕИХ сторон — как знак ни поверни, он читается.
* ЗНАК НЕ КРЕПИЛСЯ: поиск транспорта мерил расстояние до ЦЕНТРА машины и
  требовал 90 юнитов, а у «Москвича» от бампера до центра больше сотни —
  система машину «не видела» и молчала. Теперь меряем до ПОВЕРХНОСТИ
  (`NearestPoint`), ищем в радиусе 400 и дополнительно простреливаем в шесть
  сторон от знака. Если машины действительно нет — игрок получает внятную
  подсказку, а не тишину.
* Добавлен самый естественный жест: держите знак физганом и нажмите [E] по
  бамперу — знак закрепится, а в салон вас не посадит.
* Запасные пути на случай, если [E] перехватывает что-то ещё: команды
  `/прикрепить` и `/снятьномер` (плюс консольные `grm_plate_attach` и
  `grm_plate_detach`) — берут ближайший ваш знак.
* Вся обработка [E] сведена в одну функцию `PL.HandlePlateUse` — один слой
  логики на все три пути (знак, машина в руках физгана, команда).
* Стенд `sim_plates` дополнен: 75 проверок (ориентация надписи для трёх
  разных габаритов, крепление при далёком центре машины, снятие, чужой знак,
  отсутствие транспорта рядом, [E] со знаком в руках).

## Ход 21.08 (28) — номер стало видно, привязка к конкретной машине, F4

* НАСТОЯЩАЯ ПРИЧИНА пустого знака: масштаб надписи делался через
  `cam.PushModelMatrix(m)` — а он БЕЗ второго аргумента ЗАМЕНЯЕТ матрицу
  3D2D, а не домножает её. Номер уезжал в мировые координаты, на знаке
  оставалась только заливка. Матрицы убраны: поле знака рисуется одним
  проходом, номер — вторым 3D2D с уменьшенным масштабом. Печать с обеих
  сторон сохранена.
* Знак теперь привязан к КОНКРЕТНОЙ машине: в реестр пишется
  `mount.vehicleID` (запись гаража — она переживает удаление машины и
  рестарт), название машины и точное место установки на кузове.
  Удалили машину — физический знак исчез вместе с ней, но привязка цела:
  при следующей выдаче ЭТОЙ машины знак сам встаёт на своё место.
  Восстановление идёт из двух источников (раскладка в записи гаража и сам
  реестр по vehicleID), дубли исключаются по номеру. У служебных и
  карт-машин записи нет — там знак живёт, пока живёт машина.
* В F4 добавлен раздел «Номерные знаки»: `/номера`, выдача через терминал,
  [E] по знаку, [E] по машине со знаком в руках, `/прикрепить`,
  `/снятьномер`, `/номер А123ВС`, куда ставить и как работает возврат.
* Стенд `sim_plates` — 85 проверок (добавлено 10 на привязку к машине:
  идентификатор, место установки, удаление машины, возврат после выдачи,
  отсутствие дублей, чужая машина знак не получает).

## Ход 21.08 (29) — автопарк организаций и единый тул транспорта

* Новый модуль `GRM.Fleet` (`sh_grm_fleet.lua`): техника больше не берётся
  «из воздуха» по факту принадлежности к организации, а ЗАКУПАЕТСЯ.
  Путь машины: рынок (суперадмин) → закупка руководством за счёт бюджета
  организации → приписка к гаражу → выдача сотруднику по месту стоянки →
  возврат → списание с возвратом части стоимости.
* РЫНОК. Суперадмин собирает каталог закупок: класс, название, цена,
  уровень допуска (гражданская / государственная / полицейская / военная /
  спецтехника), поимённый список организаций (сильнее уровня) и лимит
  единиц одного класса на организацию. Вкладка «Рынок» в том же окне.
* ДОСТУП. Закупает лидер организации, роль с правом «Закупка транспорта»
  (`fleet_buy`) или суперадмин; приписывать к гаражу и списывать может роль
  с правом «Распоряжение автопарком» (`fleet_manage`); брать машину —
  любой сотрудник организации. Права добавлены в общий список доступов
  фракций, поэтому настраиваются в уже существующем интерфейсе.
* ДЕНЬГИ. Стоимость списывается с бюджета организации, доля уходит в
  государственную казну (`grm_fleet_state_share`, по умолчанию 100%).
  Списание возвращает `grm_fleet_scrap` процентов (по умолчанию 60%).
* ГАРАЖ И ВЫДАЧА — ОДИН ЭКРАН. Служебная техника, приписанная к гаражу,
  видна в его окне отдельным блоком «Служебный автопарк организации»,
  выдаётся и возвращается там же и встаёт НА СВОБОДНЫЕ МЕСТА стоянки
  (то самое, что нравится: машины разъезжаются по разным точкам).
* ЕДИНЫЙ ТУЛ «GRM: транспорт» вместо двух разрозненных: зона гаража →
  места выдачи → стойка вызова → ворота → дилер → связать дилера с гаражом.
  Один порядок работы и одна панель настроек; старые тулы остались
  рабочими, чтобы не ломать привычку.
* Вкладка «Автопарк» добавлена в терминалы мэрии, полиции, военной полиции,
  армии, медицины и охраны; команда `/автопарк` (`/fleet`, `/закупка`).
* Стенд: `sim_fleet` (64 живые проверки на настоящих модулях парка и гаража).

## Ход 21.08 (30) — единый слой транспорта, техника по должностям, старые тулы

* Появился ДИСПЕТЧЕР `GRM.Vehicles` (`sh_grm_vehicles.lua`): один слой между
  интерфейсами и двумя хранилищами (личные записи гаража и автопарк
  организации). `V.Rows / V.Issue / V.Store / V.SetHome` — одинаковые
  правила и сообщения для любой машины. Окно гаража и его операции
  переведены на него: копий логики больше нет.
* ТЕХНИКА ПО ДОЛЖНОСТЯМ. Единицу автопарка можно закрепить за должностями
  и/или отделами (кнопка «ДОСТУП» в окне автопарка, выбор из структуры
  организации — руками ключи не набираются). Пустой список = доступна всем
  сотрудникам. В гараже посторонний видит машину, но кнопка подписана
  «НЕ ПОЛОЖЕНА», а выдача отклоняется и на сервере.
* Проверка закрепления — чистая функция `FL.UnitAllowedFor(unit, actor)`,
  поэтому гоняется в стенде на всех сочетаниях должность/отдел/подотдел.
* Старые тулы («GRM: гаражи», «Точка выдачи транспорта») помечены как
  устаревшие прямо в названии и панели — работать продолжают, но вся
  разметка теперь одним «GRM: транспорт». Подсказка в окне гаража тоже
  указывает на новый тул.
* Стенд `sim_fleet` — 89 проверок (добавлено 25: закрепление за должностью и
  отделом, отказ выдачи, суперадмин, смена закрепления, диспетчер —
  нормализация источника, общий список, выдача/возврат/приписка, честный
  отказ по несуществующей записи).

## Ход 21.08 (31) — окна терминалов шире, вкладки везде, поля подписаны

* ОКНА. Терминалы стояли на фиксированных 960×700 (мэрия — 780×620), из-за
  чего верхний ряд вкладок уезжал за край со стрелкой «ещё». Все девять
  терминалов теперь тянутся под экран: `ScrW()*0.86` (не меньше 1180 и не
  больше 1720) на `ScrH()*0.88` (760…1080). Пожарный пульт — своё, поменьше.
* ВКЛАДКИ ВЕЗДЕ. «Автопарк» и «Номерные знаки» добавлены во ВСЕ терминалы,
  где есть госбаза: мэрия, суд, медицина, армия, военная полиция, полиция,
  охрана, автоинспекция, документный ПК (было — в половине).
* ПОДПИСИ ПОЛЕЙ. Со своим `Paint` движок НЕ рисует подсказку `DTextEntry` —
  поэтому в окне рынка стояли четыре безымянных прямоугольника. Теперь
  подсказка рисуется вручную, а у формы рынка и панели закупки над каждым
  полем стоит заголовок: КЛАСС ТРАНСПОРТА, НАЗВАНИЕ В КАТАЛОГЕ, ЦЕНА ЗА
  ЕДИНИЦУ, ЛИМИТ НА ОРГАНИЗАЦИЮ, УРОВЕНЬ ДОПУСКА, КОМУ ПРОДАЁМ, ГАРАЖ
  ПРИПИСКИ, СКОЛЬКО ЕДИНИЦ.
* Стенд: `sim_terminal_layout` (54 проверки: размеры окон всех терминалов,
  наличие обеих вкладок рядом с госбазой, названия и иконки вкладок,
  ручная отрисовка подсказок, заголовки полей).

## Ход 21.08 (32) — тул транспорта переписан, старые файлы удалены

* УДАЛЕНЫ файлы старых тулов `stools/grm_garage.lua` и
  `stools/vehicle_dealer_tool.lua`. Всё их полезное перенесено в единый
  «GRM: транспорт»: превью разметки, привязка ворот, привязка гаража к
  объекту недвижимости (ПКМ по двери дома), удаление стойки по самой стойке
  («Стойка без записи удалена с карты»), личная точка выдачи дилера с
  направлением и высотой. Q-меню и админ-хаб больше не предлагают удалённые
  тулы, стенды переведены на новый файл.
* ПОНЯТНАЯ РАЗМЕТКА ЗОНЫ. Первый угол подсвечивается шаром, будущая зона
  рисуется прямо по курсору с размерами и предупреждением «МАЛО: нужна
  сторона от 200» — видно, что получится, ДО второго клика. R отменяет
  начатую разметку.
* ПОДПИСИ ВЕЗДЕ. В мире: гаражи (название, тип, счётчики), места выдачи
  («свободно / занято», стрелка направления), стойки, дилеры (и линия к
  гаражу, куда идут их покупки), точка выдачи дилера с высотой. На экране —
  панель «ЛКМ / ПКМ / R» под текущий режим. В панели тула настройки разбиты
  на блоки ГАРАЖ / МЕСТО ВЫДАЧИ / ДИЛЕР.
* Режимы: зона, место выдачи, стойка, ворота, дилер, связать дилера с
  гаражом, точка выдачи у дилера. Направление машины — по взгляду, по
  сторонам света и относительно дилера (вперёд/назад/влево/вправо).
* Стенд: `sim_transport_tool` (35 проверок), обновлены `sim_garage_module`,
  `sim_vehicle_dealer_v3`, `sim_vehicle_class_limit`, `sim_dealer_phone_boot`.

## Ход 21.08 (33) — места выдачи наконец работают

* НАСТОЯЩАЯ ПРИЧИНА «транспорт спавнится перед дилером»: выдача у дилера
  ВООБЩЕ не смотрела на гаражи — место бралось только из точки/площадки
  самого дилера, а размеченные места использовались лишь в окне гаража.
  Появился единый выбор места `VD.ResolveDeliveryPlace`: 1) явное место,
  2) свободное МЕСТО ГАРАЖА, связанного с этим дилером, 3) место домашнего
  гаража машины, если он рядом с дилером, 4) собственная точка дилера,
  5) перед дилером. В ответе игроку теперь пишется, куда именно подали
  («Транспорт выдан: место «Бокс 2» гаража «Автобаза»»).
* ВТОРАЯ ПРИЧИНА: `G.FreeSlot` отбраковывал место одним жёстким хуллом
  размером с машину — в тесном боксе (потолок, стены, колонна) заняты были
  ВСЕ места, и система молча уезжала к дилеру. Проверка стала ступенчатой:
  полный габарит → уменьшенный → «есть земля и рядом нет машины»
  (место отдаётся с пометкой «тесно»). Свободные места всегда идут раньше
  тесных.
* ДИАГНОСТИКА: `grm_garage_slots` (суперадмин) печатает по гаражу, где вы
  стоите: сколько мест, сколько связанных дилеров, по каждому месту —
  свободно / занято (и кем) / тесно, и куда пойдёт следующая машина.
* Стенды: `sim_fleet` — 93 проверки (добавлен тесный бокс и диагностика),
  `sim_dealer_buy_issue` — 25 (выдача у дилера уходит на место связанного
  гаража; без гаражей остаётся площадка дилера).

## Ход 21.08 (34) — места выдачи работают без привязок и объясняют отказ

* «Ноль реакции» объяснился охватом правила: место искалось только у гаража,
  СВЯЗАННОГО с дилером, или у домашнего гаража машины. Если админ просто
  разметил зону и места (а привязку дилера не делал) — правило не срабатывало
  ни разу. Теперь первым делом берётся гараж, В КОТОРОМ СТОИТ ИГРОК, затем
  гараж дилера и ближайший в пределах 1200 юнитов, и только потом связанный
  и домашний. Разметил места — машины на них появляются, без настроек.
* Служебный транспорт («ПОЛУЧИТЬ» у дилера) и админский спавн из ТАБ теперь
  идут через то же правило: раньше они спавнились строго у дилера мимо всех
  мест.
* Отказ больше не молчит: система собирает ПРИЧИНЫ по каждому кандидату
  («не размечено ни одного места», «нет доступа», «все места заняты»),
  показывает их суперадмину в чате после выдачи и печатает в консоль при
  `grm_vd_slot_debug 1`. Плюс уже есть `grm_garage_slots`.
* Стенд `sim_dealer_buy_issue` — 27 проверок (места без привязки дилера,
  дилер в чистом поле, объяснение отказа).

## Ход 21.08 (35) — надпись на знаке настраивается прямо в игре

* Гадать по габаритам модели оказалось ненадёжно: у plate025x075 «тонкая»
  ось OBB не совпала с видимой плоскостью, и поле знака рисовалось поперёк.
  Теперь раскладка НЕ угадывается, а настраивается и хранится на сервере
  (`data/grm_plates/render.json`), рассылается всем игрокам:
    - `/номер_поворот` — повернуть надпись на 90° (0/90/180/270);
    - `/номер_ось` — какая ось модели смотрит наружу (auto → x → y → z);
    - `/номер_зеркало` — отзеркалить (если читается с изнанки);
    - `/номер_масштаб 1.2` — размер поля относительно габаритов модели.
  Консольные аналоги: `grm_plate_yaw/axis/flip/scale`. Только суперадмин.
  Изменения видны сразу: у живых знаков сбрасывается кэш геометрии.
* По умолчанию поворот 90° — под текущую модель. Если модель заменят,
  подгонка занимает пару команд, а не правку кода.
* HUD с номером переделан: не «текст в воздухе», а маленькая табличка со
  цветным полем и полосой, как настоящий знак; под ней — статус, если номер
  аннулирован или заявлен утерянным.
* Стенд `sim_plates` — 99 проверок (повороты, оси, зеркало, масштаб, права
  на настройку, сохранение файла). Попутно `sim_forward_locals` поймал
  обращение к local-функции до объявления — исправлено форвард-декларацией.
