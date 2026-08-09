# GRM — Garry's Mod RP-сборка (DrStrasse)

> **ВАЖНО:** `origin/master` — это старый снэпшот (коммит `05b4698 PhonesGTAIV`,
> 48 модулей). Вся актуальная сборка живёт в ветке
> `arena/019fe696-drstrasse`.
> История разработки и находки — в `ANALYSIS.md`, передача дел — в `HANDOVER.md`.

Полная Lua-сборка RP-аддона для Garry's Mod: фракции, экономика, валюта,
инвентарь, завод, логистика, телефония, **система ограблений+инкассация**,
сигнализация, CCTV, двери, кпд, радио, мобильники, вендоры, профессии,
медицина, еда, наркотики, аугментации, руда, квесты, багажник, транспорт,
наручники, арест, розыск, новости, законы, F4/Q/Tab-меню, рутгард, админ-хаб.

Пространства имён: глобальный `GRM` + `Factions`. Весь код на чистом LuaJIT,
без сторонних фреймворков (DarkRP и т.п. не требуются).

## Установка

Выберите подходящий zip из `dist/` и распакуйте в `garrysmod/addons/`:

| Zip | Содержимое | Размер |
|-----|-----------|--------|
| `grm_full_code.zip` | ВСЕ lua + materials + models (полная сборка, корень — `lua/`, `materials/`, `models/`), включая EasyChat | 4.9 МБ |
| `grm_single_addon.zip` | То же, но завёрнуто в папку `grm/` (для установки в один клик в `addons/grm/`) | 4.9 МБ |
| `grm_economy.zip` | Только экономика/валюта/банк/пермы энтити/ограбление+банк-вольт/инкассация + иконки | 144 КБ |
| `grm_fix_hud_tab_currency.zip` | Хотфикс HUD v10.2 + Tab v1.9 + Currency v2.0.3 + Economy v3.0.4 | 68 КБ |

Требуемые контент-аддоны сервера (не входят в репо — это контент HL2/CS:S и
отдельно идущие пушки/транспорт):

- **HL2 + CS:S** (стандартный контент, для моделей `models/props/cs_assault/*.mdl` и звуков `music/hl2_song*.mp3`)
- **ArcCW + базы оружия ArcCW** (для завода; без него завод не крафтит пушки, но не крашит)
- **simfphys / LVS / Glide** (для транспорта и матовозок логистики)
- **ULX/ULib** (опционально, для интеграции админ-хаба; без него работает на ванильных ban/kick)

## Статистика сборки (ветка arena/019fe696-drstrasse)

- **406** lua-модулей (143 autorun + 50 EasyChat + 63 entity-package + 8 SWEP + 18 тулов + 50 sim-testov)
- **63** entity-класса (61 папка с shared/init/cl_init + 2 одиночных файла руды)
- **9** SWEP'ов (наручники, таран, отмычка, ключи от ТС, мегафон, электродубинка, обыск, наручники-визуал, кейпад-крякер)
- **18** тулган-инструментов (двери/кейпады/банк/сеть/миникарта/профессии/вендоры и т.п.)
- **~116 000 строк Lua** (из них 52 юнит-теста/симулятора в `tools/luatest/`)
- **2018** проверок в симуляторах — **0 падений**
- **456 / 456** lua-файлов проходят синтаксический контроль LuaJIT 2.1
- Модели телефонов GTA IV: `models/ivancorn/gtaiv/electrical/phones/*.mdl` (31 модель)
- Иконки всех энтити для Q-меню: `materials/entities/grm_*.png` (33 иконки)
- **Чат-аддон EasyChat 50 lua** (встроен в сборку, работает из коробки без отдельной установки)

## Ядро системы

| Файл | Название/версия | Назначение |
|------|----------------|-----------|
| `sh_grm_currency.lua` | **GRM Currency v2.0.3 (Код 42)** | Наличные деньги: `GiveMoney/TakeMoney/HasMoney/GetBalance/SetBalance/Format/Notify`. Детерминированный сериализатор, read-back валидация, regex-спасение из битых JSON, всеядный загрузчик. **ВАЖНО:** все чтения JSON идут через обёртку `jsonT(txt) = util.JSONToTable(txt, false, true)` (ignoreConversions=true) — голый `util.JSONToTable` калечит SteamID64-ключи (находка 65, корень саги потерь). Зеркала по нику, автосейв 8 с, форензик-лог. |
| `sh_grm_economy.lua` | **GRM Unified Economy v3.0.4 (Код 43)** | Бюджеты фракций, налоги (только с ЗП), ЗП по рангам/отделам, штрафы, гос.бюджет, банковские счета, Double-синхронизация (для счетов >4.29 млрд), зеркало `grm_bank_nicks.json`, `VaultCapacity=500 000`, `RegisterVault/UnregisterVault/StateBudgetGet/StateBudgetAdd/CanManageEconomy/SpawnCashAt` (API для **банк-вольта/инкассации**), автосейв, импорты легаси, рентген счетов при загрузке. |
| `sh_factions.lua` | **Фракции v3.1.1 (Код 108)** | Ранги/отделы/приглашения/рация `/fr`, волна `/dep` `/depb`, меню `/factions`, HUD-таблички, RP-имена. |
| `sh_faction_fixes.lua` | **Фракции-добавки v3.1.1** | Комендантский час, модели/bodygroups, оружие по рангам, маскировка V2, GNews. |
| `sh_grm_character.lua` | **Identity Core v1.1.0 (Код 72)** | Персонажи, RP-имена, CharacterKey, FactionMember (зависимость ограбления). |
| `sh_grm_identity.lua` | **Identity Layer v1.0.0** | Слой-обёртка над Character (для дверей, розыска, ареста). |
| `sh_grm_customization.lua` | **Customization v1.0.0** | Лут-сумки/аксессуары: `HasFunction/LootBagAdd/LootBagGet/LootBagMax` (зависимость ограбления). |
| `sh_grm_minimap.lua` | **GPS/Minimap v0.2** | `AddTempPoint/RemoveTempPoint` — GPS-маркер «РЕЙХСБАНК» при ограблении. |
| `sh_grm_rp_chat.lua` | **RP-Chat v1.2.0 (Код 62)** | LOOC/шёпот/крик, EasyChat-хуки (`/bag_unload`, `/me`, `/do`). |
| `sh_grm_admin_hub.lua` | **Admin Hub v1.0.0 (Код 79)** | Единая админ-панель, поглотил старый `sh_grm_admin_menu.lua`. |
| `sh_grm_rootguard.lua` | **Root Guard v1.0.0 (Код 84)** | Защита от «идиота-суперадмина», байпасс-барьер. |
| `sh_grm_prop_protect.lua` | **Prop Protect v1.0.0** | Защита пропов/друзья/фракции. |
| `sh_00_grm_ui.lua` | **UI Theme** | Общие элементы стиля HUD/админки. |

## Финансы и ограбление (ядро задачи)

| Файл | Название | Назначение |
|------|----------|-----------|
| `lua/entities/grm_money_launderer/` | **Отмывщик денег (ивент «Ограбление»)** | NPC-отмывщик, 1450 строк. Ивент на 20–30 мин КД, приём заявок от фракций, глобальная музыка broadcast на всю карту (HL2 `hl2_song20_submix0.mp3`), GPS-маркер «РЕЙХСБАНК» (`GRM.Minimap.AddTempPoint`), 50-минутный таймер, сумма ограбления = сумма денег в вольте, награды госам/криминалу по исходу, список RP-имён участников (`GRM.Identity.CharacterKey`), поддержка `loot_bag` (GRM.Customization), `/bag_unload` выгрузка. Полностью покрыт sim_heist.lua (172 проверки). |
| `lua/entities/grm_bank_vault/` | **Банк-вольт (инкассация)** | Хранилище казны фракции/гос-бюджета, E → «Загрузить/Выгрузить», `LoadRadius=250`, `RegisterVault/UnregisterVault`, интеграция с `GRM.Economy.StateBudgetAdd`. Покрыт sim_bank_vault.lua (87 проверок). |
| `lua/entities/grm_vault_cash/` | **Паллета денег** | `models/props/cs_assault/moneypalleta.mdl` с фолбэком на `money.mdl`, NetworkVar "Amount", подбор в кошелёк или в loot_bag. |
| `lua/entities/grm_money_drop/` | **Пачка наличных на земле** | Падение денег на пол при смерти/выбросе/из сумки. |
| `lua/entities/grm_money_printer/` | **Денежный принтер** | Криминальный «принтер» денег, апгрейды. |
| `lua/entities/grm_money_press/` + terminal | **Печатный станок** | Промышленный станок с терминалом (наркоэкономика). |
| `lua/autorun/client/cl_grm_heist.lua` | **Баннер ивента** | Клиентский UI: «НАЧАТ ИВЕНТ: ОГРАБЛЕНИЕ», таймер 50 мин, список участников слева вверху. |
| `lua/entities/grm_bank_terminal/` | **Банкомат** | 3 вкладки: счёт / перевод / фракция, E→открытие. С каждого депозита 5% оседает в инкасс-ячейку терминала (комиссия) и забирается рейсом инкассации. |
| `sh_grm_incassation.lua` | **Инкассация v1.0.0 (Код 126)** | Система инкассации банкоматов: настройка фракций/ролей/ТС через вкладку «Инкассация» в `/factions`, чат-команды `/incass` (старт рейса за рулём служебной машины) и `/incass_delivery` (сдача в вольт), E на банкомате → меню «забрать N», E на инкасс-машине у вольта → меню «выгрузить», блокировка терминала для обычных игроков на время рейса, ограничение входа посторонним в гружёную машину, сдача денег в HeldCash вольта и гос.бюджет, аварийное завершение при дисконнекте/удалении машины. |

## Инфраструктура персистентности

| Файл | Название | Назначение |
|------|----------|-----------|
| `sh_grm_perm_entities.lua` | **Perm Entities v1.2.0 (Код 50/89)** | Перманентные энтити на карте: `/permadd` `/permremove` `/permlist` `/permload`, база-массив (НЕ карта с числовыми ключами — урок находки 65), дедуп 6 юнитов, лимит 256/карту, поддержка 17 классов (банкомат/телефоны/кейпад/сигнализация/CCTV/коммутатор/рудник/дилер). |
| `sv_grm_persistence_hub.lua` + `cl_grm_persistence_hub.lua` | **Persistence Hub** | `GRM.PermData.Extract/Apply/Upsert/UpdateEntry` — единая таблица персиста по классам, дебаунс 1 с, автосейв. |
| `sh_grm_faction_perms.lua` + `cl_grm_faction_perms_ui.lua` | **Faction Perms v2.0 (Код 122)** | Вкладка «Экономика» в `/factions`: права по ролям (state_budget_view/add/remove, faction_budget_view/edit, tax_view/edit, fine_*, kom_hour, laws и т.д.). |
| `sh_grm_faction_economy.lua` | **Faction Economy Integration (Код 124)** | Мост между фракциями и экономикой. |
| `sh_grm_factions_bridge.lua` | **Factions Bridge v1.1.0 (Код 76)** | Интеграция доски набора/биржи/радио с фракциями. |
| `sh_grm_feco_admin.lua` | **Feco Admin (Код 113)** | Админ-меню фракционной экономики. |

## Сигнализация и безопасность

| Файл | Название |
|------|----------|
| `sh_grm_alarm_config.lua` + `sh_grm_alarm_access.lua` + `sv_grm_alarm.lua` + `cl_grm_alarm.lua` + `cl_grm_alarm_notify.lua` + `sh_grm_alarm_integration.lua` | **Alarm System v1.2.0 (Код 63)** — хабы, датчики, динамики-сирены, терминалы, клавиатуры быстрого набора полиции, интеграция с ограблением/дверями/розыском, 48 проверок в симуляторах. |
| `sh_grm_cctv_config.lua` + `sh_grm_cctv_access.lua` + `sv_grm_cctv.lua` + `cl_grm_cctv.lua` | **CCTV v1.3.2 (Код 60)** — камеры/мониторы/серверы, доступ по ролям, 18 проверок. |
| `sh_grm_wanted_config.lua` + `sh_grm_wanted_access.lua` + `sv_grm_wanted.lua` + `cl_grm_wanted.lua` | **Wanted v2.0 (Код 61)** — розыск, гибкие статьи, база дел. |
| `sh_grm_arrest.lua` + `sv_grm_handcuffs.lua` + `cl_grm_handcuffs.lua` + `sh_grm_handcuffs_config.lua` + `grm_arrest_camera/` + `weapons/grm_handcuffs/` + `weapons/grm_cuffed/` + `weapons/weapon_grm_search/` + `weapons/ds_battering_ram/` + `weapons/ds_lockpick/` + `weapons/ds_key_swep/` | **Arrest v1.1.0** — наручники, конвой, арест, обыск, таран, отмычка, камера задержания, 43 проверки. |

## Двери, доступ, стройка

| Файл | Название |
|------|----------|
| `sh_grm_doors.lua` + `sh_grm_doors_access.lua` | **Doors v2.0.6/v2.2.0 (Код 64)** — своя дверная система, кейпады, купленные двери, доступ по ролям/фракциям, fading doors (FFD), 27+144 проверок. |
| `lua/entities/grm_keypad/` + `lua/weapons/gmod_tool/stools/keypad.lua` + `ffd_*` | Кейпады + fading door инструментарий. |
| `sh_grm_sliding_door.lua` + `stools/grm_sliding_door.lua` + `grm_door_admin.lua` | Раздвижные двери + админ-инструмент. |
| `sh_grm_qmenu.lua` | **Q-меню v3.3.1 (Код 96) — «GRM Стройка+»** — спавн пропов/энтити, инструменты, лимиты. |

## Телефония, радио, сеть

| Файл | Название |
|------|----------|
| `sh_grm_phone_config.lua` + `sh_grm_phone_access.lua` + `sh_grm_phone_shop.lua` + `sv_grm_phone.lua` + `cl_grm_phone.lua` + 6 entity (`grm_payphone/pbx_station/phone/phone_terminal/phone_wiretap/mobile_line`) + модели GTA IV | **Телефония v2 (Код 88)** — звонки, АТС, прослушки, терминалы, магазин, мобильники, 41+ проверка. |
| `sh_grm_mobile.lua` + `cl_grm_electronics.lua` + `sv_grm_electronics`-фрагменты | **Mobile UI v3.0 / protocol v1.2.2** — мобильный телефон в руке, меню (контакты/звонки/сообщения/радара нет), 182 проверки. |
| `sh_grm_radionet.lua` + `grm_radio/` + `grm_radio_station/` + `grm_antenna/` + `grm_broadcast_mic/` + `sh_grm_broadcast.lua` + `grm_loudspeaker/` | **RadioNet v1.0.0 (Код 85)** — радиостойки/антенны, вещание, рупоры, громкоговорители, 183 проверки. |
| `sh_grm_electronics.lua` + `cl_grm_electronics.lua` + серверная часть + 9 сетевых энтити (`grm_net_*`, `grm_router`, `grm_server_rack`, `grm_scanner`, `grm_chip_terminal`, `grm_roomtap_*`) | **Electronics & Network v1.5.0** — сетевые устройства, розетки, кабельные трассы, коммутатор-подслушка, серверные стойки, 60 проверок. |

## Профессии, квесты, доски, магазин

| Файл | Название |
|------|----------|
| `sh_grm_jobs.lua` + `grm_jobcenter/` | **Jobs Exchange v1.1.0 (Код 77)** — биржа труда, вакансии. |
| `sh_grm_quests.lua` + `cl_grm_quests.lua` + `grm_quest_npc/` | **Quest Ecosystem v1.0.0** — квесты, NPC, трекер, катсцены, 67 проверок. |
| `sh_grm_board.lua` + `grm_board/` | **Recruit Board v1.0.0 (Код 76)** — доска набора во фракции. |
| `sh_grm_vendor.lua` + `cl_grm_vendor_ui.lua` + `cl_grm_vending_gui.lua` + `grm_vendor/` | **Vendor Framework v1.5.1 (Код 111)** — вендоры/магазины, 28 проверок. |
| `sh_grm_vehicle_dealer.lua` + `sent_vehicle_dealer/` + `sh_grm_vehicle_access.lua` + `sh_grm_shop_integration.lua` + `sh_vehicle_keys.lua` + `sv_vehicle_keys.lua` + `vehicle_dealer.lua` + `stools/vehicle_dealer_tool.lua` + `weapons/vehicle_keys_swep.lua` | **Vehicle Dealer v3.0.0** — автосалон, гараж, ключи, доступ по рангам, багажник (Код 80), C-меню (Код 82), антизастревание, 27 проверок. |
| `sh_grm_trunk.lua` | **Vehicle Trunk v1.0.0 (Код 80)** — багажник любого транспорта. |
| `sh_grm_ctx.lua` | **C-меню (Код 82)** — информация о ТС в прицеле, замок, передача денег. |

## Полиция/медицина/законы/новости

| Файл | Название |
|------|----------|
| `sh_grm_laws.lua` | **Laws v1.2.0** — окно законодательства. |
| `sh_grm_news.lua` | **GNews v2** — новостная лента. |
| `sh_grm_broadcast.lua` | **Broadcast v1.2.0 (Код 75)** — массовые оповещения. |
| `sh_grm_medical.lua` + `sh_grm_medical_full.lua` + `grm_med_lab/` | **Medical Cards v1.0.0 (Код 86)** — мед. карты, лечение, препараты, лаборатория. |
| `grm_arrest_camera/` + `weapons/weapon_grm_electro_baton.lua` + `weapons/weapon_grm_megaphone/` | Камера задержания, электродубинка, мегафон. |

## Завод/логистика/инвентарь/руда

| Файл | Название |
|------|----------|
| `sh_grm_inventory.lua` + `cl_grm_inventory_ui.lua` + `grm_item_drop/` | **Inventory v1.5.0 (Код 109)** — 24 слота, drag&drop, выброс, патч интеграции с едой (zz_grm_food_inventory_patch, 629 строк). |
| `sh_grm_factory_fullcycle_config.lua` + `sh_grm_factory_fullcycle_entities.lua` + `sv_grm_factory_fullcycle.lua` + `cl_grm_factory_fullcycle.lua` | **Завод полного цикла (Коды 3-5, 41)** — лом→комплектующие→GPU/оружие ArcCW, QTE, скупщик. |
| `sh_grm_logistics_config.lua` + `sh_grm_logistics_entities.lua` + `sv_grm_logistics.lua` + `cl_grm_faction_logistics.lua` + `grm_depot/` | **Логистика v1.2.1 (Коды 1-2, 24, 40, 90, 112)** — матовозки, склады, оружейные шкафы, грузовые ящики, автосейв дебаунсом 1 с. |
| `sh_grm_ore_defs.lua` + `sh_grm_mining.lua` + `sh_grm_ore_admin.lua` + `sh_grm_ore_processing.lua` + `sv_grm_ore_spawner.lua` + `sv_grm_mining_saver.lua` + `grm_ore_node.lua` + `grm_ore_chunk.lua` + `grm_ore_buyer/` | **Mining (Код 118)** — руда, переработка в химикаты, скупщик, автоспавн. |

## Еда, наркотики, аугментации, гардероб

| Файл | Название |
|------|----------|
| `sh_grm_food_config.lua` + `sh_grm_food_kitchen.lua` + `cl_grm_food_hud.lua` + `cl_grm_food_kitchen.lua` + `sv_grm_food.lua` + `grm_food_fridge/` + `grm_food_planter/` + `grm_food_stove/` + `zz_grm_food_hunger_balance_patch.lua` + `zz_grm_food_inventory_patch.lua` | **GrandEats v2 (Код 110)** — еда, холодильники, плиты, грядки, голод, баланс, интеграция с инвентарём, 78 проверок. |
| `sh_grm_narcotics.lua` + `sv_grm_narcotics_craft.lua` + `cl_grm_narcotics_craft.lua` + `grm_narc_lab/` | **Narcotics v2.0.0** — наркотики, зависимость, эффекты, лабораторный крафт. |
| `sh_grm_augmentations.lua` + `sh_grm_augmentation_access.lua` + `sh_grm_augmentation_chips.lua` + `sh_grm_augmentation_integrations.lua` + `cl_grm_augmentation_*.lua` + `grm_augmentation_chip/` + `grm_augmentation_pod/` + `grm_augmentation_station/` + `grm_chip_terminal/` + `stools/grm_augmentation.lua` + `sh_grm_chip_control.lua` | **Augmentations v2.0** — чипы-аугментации, станция установки, под-интерфейс, контроль чипов, 181 проверка. |
| `grm_wardrobe/` + `sv_grm_wardrobe_spawn.lua` | **Wardrobe (Код 73)** — гардеробы/примерочные, смена одежды. |
| `sh_grm_encumbrance_config.lua` + `sv_grm_encumbrance.lua` + `cl_grm_encumbrance.lua` | **Encumbrance** — вес/перегруз. |
| `sh_grm_movement.lua` | **Movement v1.3** — стамина/дыхание. |

## UI и меню

| Файл | Название |
|------|----------|
| `cl_grm_hud.lua` | **HUD v10.2 (Код 48)** — HP/броня/деньги/счёт/патроны/кастомный селектор оружия/уведомления/шрифты. |
| `sh_grm_tab_menu.lua` | **Tab v1.9 (Код 72)** — скорборд, поиск, админ-действия, RP-имена. |
| `sh_grm_f4menu.lua` | **F4-меню v1.4.0 (Код 74)** — категории, профессии, магазин. |
| `sh_grm_admin_menu.lua` | **Admin Menu v1.1** — суперадмин-меню экономики (совместимость; основной — admin_hub). |
| `cl_grm_ui_theme.lua` + `sh_00_grm_ui.lua` | Цветовая схема и шрифты. |
| `cl_grm_search_result.lua` | **Search Result UI (Код 121)** — результаты обыска. |
| `cl_vehicle_hud.lua` | Vehicle HUD (спидометр/ТС). |
| `cl_grm_persistence_hub.lua` | UI персиста (визуализация на клиенте). |

## Игровая сессия

| Файл | Название |
|------|----------|
| `sh_grm_rpdesc.lua` | **RPDesc v2.1.0 (Код 71)** — описания персонажа, 3D2D над головой. |
| `sh_spawn_points.lua` | **Spawn Points** — точки спавна фракций/глобальные (per-map JSON), `/spawnmenu`. |
| `sh_grm_tickets.lua` | **Tickets** — тикеты/поддержка. |
| `sh_grm_achievements.lua` | **Achievements v1.0.0 (Код 78)** — ачивки, F4-вкладка. |
| `sh_grm_ffdlink.lua` | **FFD Link v1.1.0 (Код 108→109)** — заказы владельца на FFD/двери. |
| `zz_grm_vehicle_antistuck.lua` | Антизастревание в ТС, NoCollide при выходе. |
| `zz_grm_handcuffs_access_patch.lua` | Патч прав доступа к наручникам. |
| `zz_easychat_grm_fix.lua` | Мост к EasyChat. |
| `easychat_init.lua` | Инициализация EasyChat-интеграции. |

## Чат (EasyChat)

| Файл | Назначение |
|------|-----------|
| `lua/easychat/` (50 lua) | **EasyChat** — полная замена ванильного чата (emoji/twemoji/steam-emoji, упоминания, вкладки DM/Global/Local/Admin, макросы, история, голосовые сообщения, интеграция с DarkRP/TTT/Murder). Встроен в сборку, работает из коробки. Мосты GRM: `zz_easychat_grm_fix.lua` (хуки для RP-чата / `/me` `/do` `/bag_unload`) и `easychat_init.lua` (инициализация). |

## Citadel/CCTV server/Дата-центр

| Файл | Название |
|------|----------|
| `grm_citadel_core/` + `grm_citadel_core_terminal/` + `stools/grm_citadel_core.lua` | «Ядро Цитадели» — эндгейм-энтити. |
| `grm_server_rack/` | Серверные стойки (поддержка сети/CCTV). |
| `grm_citadel_core`-терминал | Терминал управления Цитаделью. |

## SWEP'ы

| Папка | Назначение |
|-------|-----------|
| `ds_battering_ram/` | Таран (вылом дверей) |
| `ds_lockpick/` | Отмычка |
| `ds_key_swep/` | Ключи (отмычка по ключу) |
| `grm_handcuffs/` + `grm_cuffed/` | Наручники + визуал "сцепленных рук" |
| `vehicle_keys_swep.lua` | Ключи от ТС |
| `weapon_grm_electro_baton.lua` | Электродубинка |
| `weapon_grm_megaphone/` | Мегафон |
| `weapon_grm_search/` | Обыск |
| `keypad.lua` (weapons) | Кейпад-крэкер (отмычка для кейпадов) |

## Тулган-инструменты

Fading Door / Keypad / FFD Link/Scanner, Arrest Zone, Augmentation, Bank Tool,
Citadel Core, Door Admin, Lab Tool, Minimap, Network Tool, Quest Tool, Sliding
Door, Vendor Tool, Vehicle Dealer.

## Файлы данных (garrysmod/data)

Сохраняются автоматически при работе сервера:

```
factions.json, factions_extended.json, invites.json
default_models.json, default_weapons.json, fw_faction_extras.json
grm_inventories.json
grm_currency.json            ← кошельки (через jsonT с ignoreConversions!)
grm_economy.json             ← экономика, казна, банковские счета
grm_bank_nicks.json          ← зеркало счетов по нику
grm_admin_log.json, grm_player_taxes.json, grm_log.txt
spawn_points_global_<map>.json, spawn_points_factions_<map>.json
grm_perm_entities.json       ← перманентные энтити (МАССИВ!)
grm_vaults.json              ← банк-вольты
grm_heist_*.json             ← кд/состояние ивента ограбления
gnews_log.txt
grm_logistics/{access.json, inventory_crates.json, maps/<map>.json}
grm_factory_fullcycle/{weapon_lockers.json, weapon_market.json, weapon_buyers.json, maps/<map>.json}
grm_vehicle_purchases.json, grm_vehicle_prices.json, grm_faction_vehicle_access.json, vd_spawn_log.txt
grm_phone/{access.json, shop_catalog.json, shop_purchases.json, player_equipment.json, <map>.json}
grm_phone_records/<YYYY-MM-DD>.txt
grm_persistence/<class>.json ← таблицы персиста новых энтити (GRM.PermData)
grm_doors.json, grm_keypad_*.json
grm_wanted.json, grm_arrest_log.txt
grm_radio/<map>.json, grm_antennas.json
grm_net/<map>.json
grm_vendors/<map>.json
grm_alarm/<map>.json, grm_cctv/<map>.json
grm_jobs.json, grm_quests.json
grm_medical/*.json
grm_food/<map>.json
grm_augmentations.json, grm_chips.json
grm_wardrobes/<map>.json
grm_narcotics/*.json
grm_mining/<map>.json, grm_ore_nodes.json
```

## Основные команды

**Игрок:** `/inv`, `/store`, `/fjoin`, `/fleave`, `/fr`, `/dep`, `/depb`, `/mask`,
`/model`, `/gnews`, `/kom_hour`, `/me`, `/do`, `/looc`, `/bag_unload`,
`/logistics_start`, `/logistics_crates`, `/laws`, `/news`, `/jobs`,
`!fbudget`, `!fpay`, `!fwithdraw`, `!fpayall`, `!fsettax`, `/mysalary`,
`/fine`, `/vlist`, `/myvehicles`, `/vshop`, `/phoneshop`, `/teleshop`,
`/phone_remove`, `/m` (мобильный), `/radio`, `/cuff`, `/resist`,
`/incass`, `/incass_delivery` (инкассация)

**Лидер/полиция/медик:** `/vaccess`, `/wanted`, `/unwanted`, `/arrest`, `/cuff`,
`/search`, `/medcard`, `/broadcast`, `/lawadd`/`/lawremove`

**Админ:** `/factions`, `/salary_admin`, `/grmmenu`/`!econadmin`, `/scanvehicles`,
`/spawnmenu`, `/vshop_admin`, `/phoneshop_admin`, `/phone_access`,
`/permadd`, `/permremove`, `/permlist`, `/permload`, `/rguard`,
`/door_admin`, `/vtool`, коноль: `grm_*` семейство, `grm_money give/take/set/info/save`

## Юнит-тесты и валидация

В `tools/luatest/` — 50+ автономных симуляторов (mock GMod API + LuaJIT):

```bash
# Сборка LuaJIT (один раз):
mkdir -p .luabuild && cd .luabuild && \
  curl -fsSL -o lj.tar.gz https://codeload.github.com/LuaJIT/LuaJIT/tar.gz/refs/heads/v2.1 && \
  tar xzf lj.tar.gz && mv LuaJIT-2.1 lj && cd lj && make -s -j4
cd ../..

# Все 13 фаз roundtrip-теста (ядро валюты/экономики):
for p in save load sidkey_trap bank_reconcile_attack bank_boot_pick_fresh \
         bank_nick_mirror perm corrupt corrupt_all treasury_corrupt \
         fmt_array_sid fmt_array_nick fmt_mapnum; do
  ./.luabuild/lj/src/luajit tools/luatest/roundtrip_test.lua $p
done

# Все симуляторы (включая heist=172, bank_vault=87, radionet=183, ffdtools=144):
for s in tools/luatest/sim_*.lua; do ./.luabuild/lj/src/luajit $s; done
```

Текущий статус: **52 симулятора, 2018 проверок, 0 падений**.

## Важные правила кода (из находок)

1. **НИКОГДА** не читай JSON голым `util.JSONToTable(txt)` — всегда через обёртку
   `jsonT(txt, false, true)` (третий аргумент `ignoreConversions=true`), иначе
   SteamID64-ключи конвертируются в числа и дублируются/калечатся (находка 65).
2. Храни списки записей **МАССИВАМИ** (целочисленные ключи 1..N), а не картами
   с числовыми ключами-строками — они не калечатся при сериализации.
3. Каждая запись на диск должна иметь печать `SAVE ok: <файл> [<причина>]`, а
   `file.Write` в GMod **не возвращает статус** — делай read-back валидацию.
4. `Player:SetPos()` возвращает `nil` в GMod — не чейнид вызовы.
5. `DFrame:Clear()` сносит также служебные кнопки — чистить только свои дети.
6. Все shared.lua энтити должны грузиться без ошибок и на клиенте и на сервере.
7. При тулган-инструментах оставляй совместимость со старыми именами классов
   (например, `keypad` и `grm_keypad` — это одно и то же).

## Следующий свободный код модуля: **127**

(в коде уже заняты до 126 включительно; 103, 114-117, 119, 123 — пропуски).

Подробный разбор архитектуры, хронология восстановления и все находки — в
`ANALYSIS.md`; история передачи между сессиями — в `HANDOVER.md`.
