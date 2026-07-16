# GRM — Garry's Mod RP-сборка (DrStrasse)

Набор Lua-модулей для Garry's Mod: фракции, экономика, инвентарь, логистика,
завод полного цикла, стамина, конфиг чата. Все модули общаются через
глобальный namespace `GRM` и глобальную таблицу `Factions`.

## Установка

Скопировать содержимое `lua/` в `garrysmod/addons/grm/lua/`
(или прямо в `garrysmod/lua/`). Файлы в `lua/autorun/` загружаются
автоматически на сервере и клиенте.

## Файлы (куски 1–5 — 41 модуль)

| # | Файл | Назначение |
|---|------|-----------|
| 1 | `lua/autorun/sh_grm_logistics_entities.lua` | Регистрация entity логистики: точка погрузки, склад фракции, оружейный шкаф, грузовой ящик |
| 2 | `lua/autorun/server/sv_grm_logistics.lua` | Сервер логистики: рейсы матовозок, ящики (2 пистолета + 5 автоматов), склады, шкафы, сохранение на карту |
| 3 | `lua/autorun/sh_grm_factory_fullcycle_config.lua` | Конфиг завода: рецепты GPU/компонентов/оружия ArcCW, переплавка брака, рынок, QTE |
| 4 | `lua/autorun/sh_grm_factory_fullcycle_entities.lua` | Регистрация entity завода: станки, мусорка, терминал, склад, скупщик, шкаф |
| 5 | `lua/autorun/server/sv_grm_factory_fullcycle.lua` | Сервер завода: крафт, QTE-сессии, лом, продажа GPU, скупщик/шкаф оружия, сохранение |
| 6 | `lua/autorun/sh_grm_inventory.lua` | Инвентарь: 24 слота, стаки, оружие/патроны/предметы, выброс `grm_item_drop`, JSON-персистентность |
| 7 | `lua/autorun/sh_grm_movement.lua` | Стамина: бег/прыжки, звук дыхания (CreateSound), HUD-полоса выносливости |
| 8 | `lua/autorun/sh_grm_chat_config.lua` | Конфиг чата: радиусы local/whisper/yell/LOOC, цвета, настройки контекстного меню |
| 9 | `lua/autorun/sh_grm_faction_economy_plus.lua` | Экономика Plus: бюджеты, налоги, зарплаты по рангам/отделам, история, панель `/salary_admin` |
| 10 | `lua/autorun/sh_factions.lua` | Ядро фракций: ранги, отделы, приглашения, рация `/fr`, волна `/dep` `/depb`, меню `/factions`, HUD-таблички |
| 11 | `lua/autorun/sh_faction_fixes.lua` | Расширение фракций: комендантский час `/kom_hour`, модели+bodygroups, оружие по рангам, маскировка V2, `/gnews` |
| 12 | `lua/autorun/sh_grm_faction_economy.lua` | Базовая экономика фракций: бюджет, налог, `!fbudget` `!fpay` `!fwithdraw` `!fpayall` `!fsettax` |
| 13 | `lua/autorun/sh_grm_admin_menu.lua` | Суперадмин-меню экономики v1.1: балансы, персональные налоги, переводы, журнал действий — `!grmmenu` |
| 14 | `lua/autorun/sh_grm_shop_integration.lua` | Интеграция магазина/дилера: сканер транспорта (GMod/SimFPhys/LVS/Glide), вкладка «Транспорт» в меню лидера, `/scanvehicles` `/vlist` |
| 15 | `lua/autorun/sh_spawn_points.lua` | Точки спавна фракций/глобальные (per-map JSON), админ-меню `/spawnmenu`, случайный спавн по точкам |
| 16 | `lua/autorun/sh_grm_vehicle_access.lua` | Доступ к транспорту: персональные покупки, доступ по фракции/рангу/отделу, магазин `/vshop`, админ цен `/vshop_admin` |
| 17 | `lua/autorun/vehicle_dealer.lua` | Патч дилера v3: проверка доступа перед спавном, фильтр списка, блок Q-меню, кулдаун 2с, лог спавнов |
| 18 | `lua/autorun/zz_grm_vehicle_antistuck.lua` | Анти-застревание при выходе из машины (NoCollide + поиск безопасной точки, simfphys/LVS), `zz_` грузится последним |
| 19 | `lua/autorun/sh_grm_phone_config.lua` | Конфиг телефонии: радиусы, номера 1000–9999, модели телефонов/АТС, звуки, доступ спецслужб |
| 20 | `lua/autorun/sh_grm_phone_access.lua` | Менеджер доступа к оборудованию связи (`/phone_access`), переопределяет `GRM.Phone.HasEquipmentAccess`, вкладка «Телефония» в админ-меню фракций |
| 21 | `lua/autorun/sh_grm_phone_shop.lua` | Магазин телефонии v2: каталог (телефон/таксофон/АТС/прослушка/терминал), покупка доступа, спавн, лимиты, `/phoneshop` |
| 22 | `lua/autorun/server/sv_grm_phone.lua` | Сервер телефонии: звонки, АТС-линии, прослушка (голос+текст), мониторинг, per-map сохранение, интеграция войса |
| 23 | `lua/autorun/client/cl_grm_phone.lua` | Клиент телефонии: UI телефона/АТС/прослушки/терминала связи |
| 24 | `lua/autorun/sh_grm_logistics_config.lua` | **Конфиг логистики** (закрывает жёсткую зависимость Кода 2): дистанции, ящики 2 пист. + 5 авт., награды, матовозка `simfphys_gta_sa_barracks` |
| 25–27 | `lua/entities/grm_payphone/{shared,init,cl_init}.lua` | Entity таксофона: NetworkVars линии, Use() → меню телефона, 3D2D-табличка |
| 28–30 | `lua/entities/grm_pbx_station/{shared,init,cl_init}.lua` | Entity АТС: ExchangeID/Active/MaxLines, Use() → меню АТС, табличка статуса |
| 31–33 | `lua/entities/grm_phone/{shared,init,cl_init}.lua` | Entity стационарного телефона: авто-номер при спавне, Use() → меню, табличка номера |
| 34–36 | `lua/entities/grm_phone_terminal/{shared,init,cl_init}.lua` | Entity терминала мониторинга связи: TerminalName, Use() → терминал |
| 37–39 | `lua/entities/grm_phone_wiretap/{shared,init,cl_init}.lua` | Entity прослушки: TargetNumber/ExchangeID/Active, Use() → меню прослушки, 3D2D-индикатор ON/OFF — **последний кусок телефонии** |
| 40 | `lua/autorun/client/cl_grm_faction_logistics.lua` | Клиент логистики: меню рейса/погрузки/ящика/склада/арсенала, админ-доступ, HUD-подписи и маршрут, анимация переноски ящика |
| 41 | `lua/autorun/client/cl_grm_factory_fullcycle.lua` | Клиент завода: крафт-меню (3D-превью оружия), склад, мусорка, терминал продажи GPU, скупщик/шкаф, QTE на стрелках, HUD прогресса |

## Зависимости, которых пока НЕТ в репозитории

Эти модули упоминаются в коде, но ещё не присланы (ожидаются следующими кусками):

- Ядро валюты: `GRM.GiveMoney / TakeMoney / HasMoney / GetBalance / SetBalance / Format / Notify` + конфиг `GRM.StartBalance` + клиентская переменная `GRM.LocalBalance`
- **Entity дилера** (`entities/sent_vehicle_dealer/…`) — `vehicle_dealer.lua` это патч поверх неё
- Радио-модуль с глобальной таблицей `RadioFrequencies` (для телефонной интеграции рации)
- `GRM.Encumbrance` — система веса/перегруза
- GUI инвентаря: `GRM.Inventory.OpenGUI()` + entity `grm_item_drop`
- `GRM.Chat` — основная реализация чата (здесь только конфиг); вероятно, она же даёт хук `PlayerSayTransform`
- Шрифты `GRM_HUD_Label`, `GRM_HUD_Value` — из HUD-ядра
- Внешние: ArcCW (оружие), simfphys/LVS (матовозки/транспорт), ULX/ULib (опционально)
- Ресурс `sound/kom_hour.wav` — положить в `addons/grm/sound/`

## Файлы данных (garrysmod/data)

`factions.json`, `invites.json`, `factions_extended.json`, `fw_faction_extras.json`,
`default_models.json`, `default_weapons.json`, `grm_inventories.json`,
`grm_faction_budgets.json`, `grm_faction_economy_plus.json`, `gnews_log.txt`,
`grm_logistics/{access.json, inventory_crates.json, maps/<map>.json}`,
`grm_factory_fullcycle/{weapon_lockers.json, weapon_market.json, weapon_buyers.json, maps/<map>.json}`,
`grm_admin_log.json`, `grm_player_taxes.json`,
`spawn_points_global_<map>.json`, `spawn_points_factions_<map>.json`,
`grm_vehicle_purchases.json`, `grm_vehicle_prices.json`, `grm_faction_vehicle_access.json`, `vd_spawn_log.txt`,
`grm_phone/{access.json, shop_catalog.json, shop_purchases.json, player_equipment.json, <map>.json}`,
`grm_phone_records/<YYYY-MM-DD>.txt`

## Основные команды

**Игрок:** `/inv`, `/store`, `/fjoin`, `/fleave`, `/fr`, `/dep`, `/depb`, `/mask`,
`/model`, `/gnews`, `/kom_hour`, `/logistics_start`, `/logistics_crates`,
`!fbudget`, `!fpay`, `!fwithdraw`, `!fpayall`, `!fsettax`, `/vlist`, `/myvehicles`,
`/vshop`, `/phoneshop` (`/teleshop`), `/phone_remove`

**Лидер фракции:** `/vaccess` (доступ транспорта для рангов/отделов)

**Админ:** `/factions`, `/salary_admin`, `/logistics_admin`, `/models_admin`,
`/weapons_admin`, `/mask_admin`, `!grmmenu`/`!grmadmin`, `/scanvehicles`,
`/spawnmenu`, `/vshop_admin`, `/phoneshop_admin`, `/phone_access`,
`/phone_admin_remove`, консоль: `grm_logistics_place_*`, `grm_logistics_save/load`,
`grm_logistics_admin_menu`, `grm_logistics_crates`,
`grm_fc_save/load`, `grm_weapon_buyer_admin`, `grm_adminmenu`, `grm_antistuck_vehicle`,
`grm_phone_save/load`, `grm_phone_remove_look`, `grm_phone_admin_remove`,
`grm_phone_shop_admin`, `grm_phone_shop_add_look`, `grm_phone_shop_reload`,
`grm_phone_access_reload`, `grm_phone_access_debug`

Подробный разбор архитектуры и замеченных проблем — в `ANALYSIS.md`.
