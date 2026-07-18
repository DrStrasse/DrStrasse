# GRM — Garry's Mod RP-сборка (DrStrasse)

> Передача дел новой сессии агента: читать **`HANDOVER.md`** (ветка
> `arena/019f6cb8-drstrasse` — актуальный код; master — старый пустой снапшот).

Набор Lua-модулей для Garry's Mod: фракции, экономика, инвентарь, логистика,
завод полного цикла, видеонаблюдение (CCTV), сигнализации, система розыска, двери,
дверные ключи `ds_key_swep`, FFD Fading Door, FFD Keypad с 3D2D экраном, полицейский таран `ds_battering_ram`, QTE-отмычка `ds_lockpick`,
телефонная связь, стамина, RP-чат и персистентность. Все модули общаются через
глобальный namespace `GRM` и глобальную таблицу `Factions`.

## Установка

Скопировать содержимое `lua/` в `garrysmod/addons/grm/lua/`
(или прямо в `garrysmod/lua/`). Файлы в `lua/autorun/` загружаются
автоматически на сервере и клиенте.

## Файлы (основные модули)

| # | Файл | Назначение |
|---|------|-----------|
| 1 | `lua/autorun/sh_grm_logistics_entities.lua` | Регистрация entity логистики: точка погрузки, склад фракции, оружейный шкаф, грузовой ящик |
| 2 | `lua/autorun/server/sv_grm_logistics.lua` | Сервер логистики: рейсы матовозок, ящики (2 пистолета + 5 автоматов), склады, шкафы, сохранение на карту |
| 3 | `lua/autorun/sh_grm_factory_fullcycle_config.lua` | Конфиг завода: рецепты GPU/компонентов/оружия ArcCW, переплавка брака, рынок, QTE |
| 4 | `lua/autorun/sh_grm_factory_fullcycle_entities.lua` | Регистрация entity завода: станки, мусорка, терминал, склад, скупщик, шкаф |
| 5 | `lua/autorun/server/sv_grm_factory_fullcycle.lua` | Сервер завода: крафт, QTE-сессии, лом, продажа GPU, скупщик/шкаф оружия, сохранение |
| 6 | `lua/autorun/sh_grm_inventory.lua` | Инвентарь: 24 слота, стаки, оружие/патроны/предметы, выброс `grm_item_drop` (с `/drop`), JSON-персистентность |
| 7 | `lua/autorun/sh_grm_movement.lua` | Стамина: бег/прыжки, звук дыхания (CreateSound), HUD-полоса выносливости |
| 8 | `lua/autorun/sh_grm_chat_config.lua` | Конфиг чата: радиусы local/whisper/yell/LOOC, цвета, настройки контекстного меню |
| 10 | `lua/autorun/sh_factions.lua` | Ядро фракций: ранги, отделы, приглашения, рация `/fr`, волна `/dep` `/depb`, меню `/factions`, HUD-таблички |
| 11 | `lua/autorun/sh_faction_fixes.lua` | Расширение фракций: комендантский час `/kom_hour`, модели+bodygroups, оружие по рангам, маскировка V2, `/gnews` |
| 13 | `lua/autorun/sh_grm_admin_menu.lua` | Суперадмин-меню экономики v1.1: балансы, персональные налоги, переводы, журнал действий — `!grmmenu` |
| 14 | `lua/autorun/sh_grm_shop_integration.lua` | Интеграция магазина/дилера: сканер транспорта (GMod/SimFPhys/LVS/Glide), вкладка «Транспорт» в меню лидера, `/scanvehicles` `/vlist` |
| 15 | `lua/autorun/sh_spawn_points.lua` | Точки спавна фракций/глобальные (per-map JSON), админ-меню `/spawnmenu`, случайный спавн по точкам |
| 16 | `lua/autorun/sh_grm_vehicle_access.lua` | Доступ к транспорту: персональные покупки, доступ по фракции/рангу/отделу, магазин `/vshop`, админ цен `/vshop_admin` |
| 17 | `lua/autorun/vehicle_dealer.lua` | Патч дилера v3: проверка доступа перед спавном, фильтр списка, блок Q-меню, кулдаун 2с, лог спавнов |
| 18 | `lua/autorun/zz_grm_vehicle_antistuck.lua` | Анти-застревание при выходе из машины (NoCollide + поиск безопасной точки, simfphys/LVS), `zz_` грузится последним |
| 19–23 | `lua/autorun/sh_grm_phone_*.lua` | Полная система телефонии: конфиги, доступы, магазин, сервер и клиент связи |
| 24 | `lua/autorun/sh_grm_logistics_config.lua` | Конфиг логистики: дистанции, ящики, награды, матовозка `simfphys_gta_sa_barracks` |
| 25–39 | `lua/entities/grm_*` | Сущности таксофона, АТС, стационарного телефона, терминалов и прослушки |
| 40–41 | `lua/autorun/client/cl_grm_*.lua` | Клиентские части логистики и завода полного цикла |
| 42 | `lua/autorun/sh_grm_currency.lua` | **Ядро валюты v2.0.2:** `GiveMoney/TakeMoney/HasMoney/GetBalance/SetBalance/Format/Notify`, JSON-персистентность |
| 43 | `lua/autorun/sh_grm_economy.lua` | **Единая экономика v3.0.3:** бюджеты, налоги, зарплаты, штрафы `/fine`, банк-терминалы, зеркало по никам, склеивание ключей |
| 44–46 | `lua/entities/grm_bank_terminal/` | **Банкомат** (`models/starless/atm.mdl`): личные счета, переводы, управление бюджетом фракций |
| 47 | `lua/autorun/sh_grm_tab_menu.lua` | Tab-меню v1.9 (scoreboard): RP-имя вместо Steam-ника (стим мелкой строкой в карточке), список игроков, фильтры, балансы, глушение голоса |
| 48 | `lua/autorun/client/cl_grm_hud.lua` | HUD v10.2: Здоровье/Броня, Наличные, Банк, Патроны, Селектор оружия, Уведомления |
| 49 | `lua/autorun/client/cl_grm_inventory_ui.lua` | GUI инвентаря v2.1: сетка 6×4, Drag&Drop, детали предметов |
| 50 | `lua/autorun/sh_grm_perm_entities.lua` | **Пермы энтити v1.1.0:** Закрепление банкоматов, телефонов, АТС, CCTV и сигнализаций на карте |
| 51–54 | `lua/autorun/sh_grm_cctv_*.lua` | **CCTV Видеонаблюдение:** конфиг, доступы, сервер, клиент и сущности `grm_cctv_camera`, `grm_cctv_monitor`, `grm_cctv_server` |
| 55–58 | `lua/autorun/sh_grm_alarm_*.lua` | **Система Сигнализаций:** конфиг, доступы, сервер, клиент и сущности `grm_alarm_sensor`, `grm_alarm_hub`, `grm_alarm_terminal` |
| 59–60 | `lua/autorun/sh_grm_wanted_*.lua` | **Система Розыска:** статусы wanted/warrant, причины, серверная обработка, клиентский HUD и списки |
| 61–62 | `lua/autorun/sh_grm_doors*.lua` | **Система Дверей v2.0.5 & Access v2.2.0:** авторитетный реконсилер замков, 3D2D HUD, подавление сторонних оверлеев, меню сохраняет вкладку/прокрутку, кастомные категории фракций (создание/объединение в `/factions` → «Двери и Ордера»), категории в ACL дверей |
| 63–64 | `lua/autorun/sh_grm_rp_chat.lua` | **RP Чат и EasyChat патчи:** команды `/me`, `/do`, `/it`, `/try`, `/roll`, `/w`, `/y`, `/looc`, `/ooc` |
| 65 | `lua/entities/grm_item_drop/` | **Выброшенный предмет/оружие:** сущность 3D-модели предмета при выбросе из инвентаря/рук (`/drop`) |
| 66 | `lua/weapons/ds_key_swep/` | **Дверные ключи `ds_key_swep`:** оружие для блокировки (ЛКМ), разблокировки (ПКМ) и вызова меню двери (R) |
| 67 | `lua/weapons/ds_battering_ram/` | **Полицейский таран `ds_battering_ram`:** вскрытие дверей по ордеру на обыск `/warrant` или праву ForceDoor |
| 68 | `lua/weapons/ds_lockpick/` | **QTE-Отмычка `ds_lockpick`:** интерактивный взлом запертых дверей и кейпадов с подбором пинов |
| 69 | `lua/weapons/gmod_tool/stools/ffd_fading_door.lua` | **FFD Fading Door:** тулган создания исчезающих дверей с нумпадом, инверсией и авто-закрытием |
| 70 | `lua/entities/grm_keypad/` | **FFD Keypad (`grm_keypad` & `ffd_keypad.lua`):** интерактивный кодовый замок с 3D2D экраном, PIN, фракционным доступом и платным проходом |
| 71 | `lua/autorun/sh_grm_rpdesc.lua` | **RPDesc v2.1.0:** RP-имя + описание над головой ВСЕМ (включая себя, 1-е/3-е лицо), редактор `/rpdesc`, конвары grm_cl_rpdesc(+_dist), лимит 420 симв., анти-флуд |
| 72 | `lua/autorun/sh_grm_character.lua` | **Ядро персонажей GRM Identity v1.1.0:** меню при КАЖДОМ входе (ширина ×2), RP-имя (`/name`, NWString GRM_RPName), провайдер-патчи `RegisterProvider` (гражданский+фракционный гардероб), синхрон с фракционным спавном, `/char` |
| 73 | `lua/entities/grm_wardrobe/` + `server/sv_grm_wardrobe_spawn.lua` | **Гардероб:** шкаф `props_interiors/Furniture_CabinetDrawer01a` (фолбэк на локер при отсутствии модели), E → меню внешности (фильтры + особые/скрытые модели, суперадмин E→⚙), `/wardrobe_add` `/wardrobe_remove`, перм-класс grm_wardrobe, конфиг в data/grm_wardrobe/<map>.json (выживает рестарт) |
| 74 | `lua/autorun/sh_grm_f4menu.lua` | **F4-меню v1.3.0:** вкладки Профиль / Команды / Настройки (HUD-выключатели) / **Графика** (пресеты FPS+/Красота, 10 тоглов, слайдеры дальности/качества). Шпаргалка команд: +радио/оповещение/доска/доступы. F4 ловится биндом и прямым опросом (toggle), уступает дверям; `/menu` `/f4` |
| 75 | `lua/autorun/sh_grm_broadcast.lua` + `lua/entities/grm_radio/`, `grm_broadcast_mic/`, `grm_loudspeaker/` + мост `sh_grm_factions_bridge.lua` | **Радиовещание + массовое оповещение v1.1.0:** микрофон (Black Ops p_int_microphone; `/bcast_allow`) — голос+текст в эфире до приёмников; радио citizenradio (E — станция); громкоговорители → `/alert` `/alertall` (команды идут через PlayerSayTransform — не проглатываются чат-системой); доступы и из `/factions` → «Доступы»; спавн `/radiomic_add` `/radio_add` `/speaker_add` — АВТОперсистентность без /permadd (grm_bcents/<map>.json) |
| 76 | `lua/autorun/sh_grm_board.lua` + `lua/entities/grm_board/` | **Доска объявлений/набор во фракции** (модель corkboardverticle01): доступ фракциям: `/factions` → «Доступы», суперадмин E→⚙ у доски, `/board_allow`, лидер открывает/закрывает набор, игрок E→«Вступить» попадает во фракцию автоматически (FactionsAPI), лидеру — сведения (ник, RP-имя, SteamID, время) + журнал 20 записей; `/board_add` |
| 77 | `lua/autorun/sh_grm_jobs.lua` + `lua/entities/grm_jobcenter/`, `grm_depot/` | **Биржа труда v1.0.0:** терминал (E → вакансии: курьер/патруль/грузчик/инспектор, ротация 5 мин, награда по дистанции, жёсткий дедлайн по настенным часам, 3D-маркер цели, вкладка «Работа» в F4) + точки доставки `/jobdepot_add`; **заказы фракций** — лидер с доступом «БИРЖА» (`/factions` → «Доступы», `/job_allow`) публикует задания с ЭСКРОУ награды из бюджета фракции (выполнил — исполнителю, отозвал/просрочил — возврат, до 3 шт., 24 ч); `/jobs` `/jobcancel`; автоперсистентность (`grm_jobs_ents/<map>.json`, активные задачи массивом в `grm_jobs_active.json` — переживают рестарт); хуки GRM_Jobs_Started/Completed/Failed для ачивок |
| 78 | `lua/autorun/sh_grm_achievements.lua` | **Ачивки и вознаграждения v1.0.0:** 21 достижение (экономика, биржа, радио/оповещение, доска/фракции, часы в городе, пешие километры, стрик входа) с денежными наградами — начисление автоматически при разблокировке (тост «★» + звук + чат), вкладка «Ачивки» в F4 с прогресс-барами, `/ach`; **ежедневный бонус** за вход с растущим стриком (500+250/день, потолок 2000); прогресс из хуков сборки (деньги/задачи/эфир/оповещения/вступление) + тик-поллинг (время, пешком с анти-телепорт-капой); хранение массивом `grm_achievements.json`; `/ach_reset ник` (суперадмин) |
| — | `materials/entities/*.png` | **Иконки Q-меню:** 33 иконки в едином стиле для всех энтити и оружия GRM (автоподхват по имени класса) |

**Освежение v2 (в составе Кода 11):** `/models_admin` и `/weapons_admin` — живое превью модели (DAdjustableModelPanel, клик по строке), SpawnIcon в строках, каталог оружия с поиском и категориями (выбор кликом из всех SWEP'ов сервера), инфо-панель скина/бодигрупп.

## Основные команды

**Игрок:** `/inv`, `/drop`, `/store`, `/fjoin`, `/fleave`, `/fr`, `/dep`, `/depb`, `/mask`,
`/model`, `/gnews`, `/kom_hour`, `/me`, `/do`, `/it`, `/try`, `/roll`, `/w`, `/y`, `/looc`,
`/logistics_start`, `/logistics_crates`, `!fbudget`, `!fpay`, `!fwithdraw`, `!fpayall`, `!fsettax`, `/mysalary`, `/fine <сумма> [причина]`, `/vlist`, `/myvehicles`,
`/vshop`, `/phoneshop`, `/phone_remove`, `/alert <текст>`, `/alertall <текст>` (по доступу), `/name`, `/char`, `/rpdesc`, `/menu`,
`/jobs`, `/jobcancel`, `/ach`; E по терминалу «Биржа труда» — вакансии и заказы фракций; F4 → «Работа»/«Ачивки»; ежедневный бонус — автоматически при входе

**Админ / Руководство:** `/factions`, `/salary_admin`, `/logistics_admin`, `/models_admin`,
`/weapons_admin`, `/mask_admin`, `!grmmenu`/`!grmadmin`/`!econadmin`, `/scanvehicles`,
`/spawnmenu`, `/vshop_admin`, `/phoneshop_admin`, `/phone_access`, `/door_access`, `/warrant`, `/unwarrant`, `/warrants`,
`/permadd`, `/permremove`, `/permlist`, `/permload`, `/radiomic_add`, `/radio_add`, `/speaker_add`, `/board_add`, `/board_allow <фракция>`, `/bcast_allow <фракция>`, `/alert_allow <фракция>`,
`/jobcenter_add`, `/jobcenter_remove`, `/jobdepot_add`, `/jobdepot_remove`, `/job_allow <фракция>`, `/job_deny <фракция>`, `/job_list`, `/ach_reset <ник>`, вкладка «Доступы» в `/factions` (доска/эфир/оповещение/**биржа**)

Подробный разбор архитектуры и замеченных проблем — в `ANALYSIS.md`.
