# GRM — Garry's Mod RP-сборка (DrStrasse)

> Передача дел новой сессии агента: читать **`HANDOVER.md`** (ветка
> `arena/019f69c8-drstrasse` — актуальный код; master — старый пустой снапшот).

Набор Lua-модулей для Garry's Mod: фракции, экономика, инвентарь, логистика,
завод полного цикла, стамина, конфиг чата. Все модули общаются через
глобальный namespace `GRM` и глобальную таблицу `Factions`.

## Установка

Скопировать содержимое `lua/` в `garrysmod/addons/grm/lua/`
(или прямо в `garrysmod/lua/`). Файлы в `lua/autorun/` загружаются
автоматически на сервере и клиенте.

## Файлы (куски 1–5 + собственные наработки + dop.addons — **147 lua-файлов**)

> **Экономика переписана с нуля (Код 43):** старые модули Код 9
> (`sh_grm_faction_economy_plus.lua`) и Код 12 (`sh_grm_faction_economy.lua`)
> **удалены и заменены** единым аддоном `sh_grm_economy.lua`. Данные старых
> файлов (`grm_faction_budgets.json`, `grm_faction_economy_plus.json`)
> одноразово импортируются при первом запуске.

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
| ~~9~~ | ~~`sh_grm_faction_economy_plus.lua`~~ | **УДАЛЁН** — заменён Кодом 43 |
| 10 | `lua/autorun/sh_factions.lua` | Ядро фракций: ранги, отделы, приглашения, рация `/fr`, волна `/dep` `/depb`, меню `/factions`, HUD-таблички |
| 11 | `lua/autorun/sh_faction_fixes.lua` | Расширение фракций: комендантский час `/kom_hour`, модели+bodygroups, оружие по рангам, маскировка V2, `/gnews` |
| ~~12~~ | ~~`sh_grm_faction_economy.lua`~~ | **УДАЛЁН** — заменён Кодом 43 |
| 43 | `lua/autorun/sh_grm_economy.lua` | **Единая экономика v3.0.2 — ПЕРЕПИСАНО С НУЛЯ (+ «банк помнит» и «electro_balance по нику»):** бюджеты/налоги (только с ЗП!) фракций, зарплаты по ролям/отделам, штрафы `/fine`, история, импорт легаси-данных, админ-панель `/salary_admin` (обновляется без переоткрытия), банк-терминал; команды `!fbudget !fpay !fwithdraw !fpayall !fsettax /mysalary`; канал банка `GRM_Bank_Sync` в Double (без переполнения >4.29 млрд); автосохранение ≤8с, сверка с базой 15с + `/dbcheck`, страж-синглтон. **v3.0.2:** всё чтение JSON через jsonT(…, ignoreConversions=true) — голый util.JSONToTable калечил sid-ключи счетов (корень «на счету 0», находка 65); сверка по политике «память главнее» с мгновенным самолечением; банковские операции пишутся на диск СРАЗУ с печатью `SAVE ok: … [причина]`; загрузчик выбирает самый полный источник; рентген счетов при загрузке; зеркало счетов `grm_bank_nicks.json` по сиду/нику с полем `electro_balance` (счёт воскресает даже при вайпе treasury, записи без сида — по нику при входе); жёсткие рамки счёта [0..MaxBalance]; `GRM.GetElectroBalance` |
| 44–46 | `lua/entities/grm_bank_terminal/{shared,init,cl_init}.lua` | **Банкомат** (замена «недоделанного терминала», модель `models/starless/atm.mdl`): E → вкладки «Мой счёт» (личный банковский счёт для ВСЕХ игроков), «Перевод» (счёт→счёт), «Фракция» (бюджет/ЗП/история), 3D2D-табличка |
| 47 | `lua/autorun/sh_grm_tab_menu.lua` | Tab-меню v1.8 (scoreboard): список игроков с рангом/фракцией/балансом/пингом, поиск, сортировки, детальная панель (гаг/кик/бан/ULX-мут/спавн транспорта), личная заглушка голоса; команда `grm_tabmenu` |
| 48 | `lua/autorun/client/cl_grm_hud.lua` | HUD v10.2: HP/броня бары, строки НАЛИЧКА/НА СЧЁТУ (`GRM.PlayerBank`, канал `GRM_Bank_Sync`), деньги (`GRM.PlayerBalance`, вывод через `GRM.Format`), патроны, кастомный селектор оружия (колёсико/1-6/ЛКМ), стек уведомлений, шрифты `GRM_HUD_*`, скрытие ванильных элементов |
| 49 | `lua/autorun/client/cl_grm_inventory_ui.lua` | GUI инвентаря v2.1: сетка 6×4 со слотами, drag&drop перемещение, детальная панель предмета (использовать/выбросить/разделить), дефолтные иконки завода, учёт веса `GRM.Encumbrance` (если есть), защита переопределения `INV.OpenGUI` |
| 50 | `lua/autorun/sh_grm_perm_entities.lua` | **Пермы разворачиваемых энтити v1.1.0 (Код 50):** банкомат (`grm_bank_terminal`), таксофон, АТС, терминал/proслушка, телефон теперь закрепляются на карте: прицел + `/permadd` `/permremove` `/permlist` в чат или `grm_perm_add/remove/list` в консоль (только суперадмин); переживают рестарт и cleanup (`InitPostEntity`/`PostCleanupMap`), заморожены; **`/permload` (`grm_perm_load`) — немедленная загрузка из базы без рестарта, с антидублем (не ставит второй энтити того же класса на занятое место)**; база-массив `data/grm_perm_entities.json` (без числовых ключей — урок находки 65), дедуп 6 юнитов, лимит 64/карту, карантин при битом файле |

| 51 | `lua/autorun/sh_grm_ctx.lua` | **Контекстное меню (C)** — единое меню: фракция/лидер/маска, проверки прав через net `GRM_Ctx_*` |
| 52 | `lua/autorun/sh_grm_encumbrance_config.lua` + `server/sv_grm_encumbrance.lua` + `client/cl_grm_encumbrance.lua` | **Вес / перегруз v1** (`GRM.Encumbrance`): лимиты кг, замедление, обёртки `AddItem`/`AddWeapon`, HUD-полоса, панель `grm_weight`; **не** заменяет inventory/HUD — хукается поверх Кодов 6/7/48/49 |
| 53 | `lua/autorun/sh_grm_food_config.lua` + `server/sv_grm_food.lua` + `client/cl_grm_food_hud.lua` + `client/cl_grm_vending_gui.lua` + `zz_grm_food_*` | **Еда / голод**: сытость, торговый автомат (`grm_vending_machine`/`grm_food_item` через `scripted_ents.Register`), пермы автоматов на карту, патчи инвентаря и баланса голода |
| 54 | `lua/autorun/sh_grm_handcuffs_config.lua` + `server/sv_grm_handcuffs.lua` + `client/cl_grm_handcuffs.lua` + `zz_grm_handcuffs_access_patch.lua` + SWEP `grm_handcuffs`/`grm_cuffed` | **Наручники**: ЛКМ надеть/снять, ПКМ ведение, R кляп, ALT+R повязка, посадка в транспорт; доступ из фракций/`/weapons_admin` |
| 55 | `lua/autorun/sh_grm_mining.lua` + `sh_grm_ore_defs.lua` + `sh_grm_ore_admin.lua` + `server/sv_grm_ore_spawner.lua` + `server/sv_grm_mining_saver*.lua` + entities `grm_ore_*` | **Добыча руды**: ноды (jackhammer), чанки, скупщик, спавнер точек, ручной сейвер `!saveentities` / `grm_saveentities` |
| 56 | `lua/autorun/sh_grm_roomtap_config.lua` + `server/sv_grm_roomtap.lua` + `client/cl_grm_roomtap.lua` + entities `grm_roomtap_{chip,server,terminal}` | **Прослушка помещений**: чипы (текст/presence), серверные стойки по каналу, терминал мониторинга, JSONL-журнал |
| 57 | `lua/entities/sent_vehicle_dealer/{shared,init,cl_init}.lua` + `weapons/gmod_tool/stools/vehicle_dealer_tool.lua` + `server/sv_grm_vehicle_dealer_anim_fix.lua` | **Entity дилера транспорта** (закрыта дыра README) + tool + anim-fix; патч доступа остаётся Код 17 |
| 58 | `lua/autorun/sh_vehicle_keys.lua` + `server/sv_vehicle_keys.lua` + `client/cl_vehicle_hud.lua` + `weapons/vehicle_keys_swep.lua` | **Ключи транспорта (fixed)**: замок/двери, выдача/отзыв ключей, фракционный доступ, SWEP |
| 59 | `lua/autorun/easychat_init.lua` + `lua/easychat/**` (50 файлов) | **EasyChat (правка GRM)** — основной чат/ChatHUD/эмодзи/DM/теги; работает рядом с конфигом Кода 8 |
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
| 42 | `lua/autorun/sh_grm_currency.lua` | **Ядро валюты v2.0.2 — ПЕРЕПИСАНО С НУЛЯ (чистый контур память→JSON→загрузка, детерминированный сериализатор, regex-спасение из битых файлов, всеядный загрузчик любых форматов кошелька, v2.0.2: всё чтение JSON через jsonT(…, ignoreConversions=true) — голый util.JSONToTable калечил ключи SteamID64, КОРНЕВАЯ причина всей саги потерь (находка 65); доказано юнит-тестом tools/luatest 12/12)** (сторож файла от чужих писателей + захват слотов + форензик-лог (v1.5.7)) (старый файл утерян): `GiveMoney/TakeMoney/HasMoney/GetBalance/SetBalance/Format/Notify` (+ опциональный `reason`), `GetAllBalances`, JSON-персистентность, офлайн-игроки, хуки `GRM_MoneyChanged`/`GRM_LocalMoneyChanged`, консоль `grm_money`, легаси-мост `grm_balance`/`grm_request_bal`/`grm_notify` + зеркало `GRM.PlayerBalance` для Tab/HUD; мгновенный пуш при вызове API по SteamID64-строке онлайн-игроку (v1.3, маркер `GRM._currencyReqBalRcv`) |

## Зависимости, которых пока НЕТ в репозитории

- ~~Ядро валюты~~ — **ВОССТАНОВЛЕНО** (Код 42)
- ~~Entity дилера~~ — **ПОЛУЧЕН** из dop.addons (Код 57 `sent_vehicle_dealer`)
- ~~`GRM.Encumbrance`~~ — **ПОЛУЧЕН** (Код 52)
- ~~GUI инвентаря~~ — **ПОЛУЧЕН** (Код 49). Осталась entity **`grm_item_drop`**
- ~~Основной чат~~ — **ПОЛУЧЕН** EasyChat (Код 59); конфиг радиусов — Код 8
- ~~Шрифты HUD~~ — **ПОЛУЧЕНЫ** (Код 48)
- **Радио** с глобальной таблицей `RadioFrequencies` (для телефонной интеграции рации) — **ещё нет**
- Внешние: ArcCW (оружие), simfphys/LVS (матовозки/транспорт), ULX/ULib (опционально), jackhammer-оружие для майнинга
- Ресурс `sound/kom_hour.wav` — положить в `addons/grm/sound/`

## Интеграция dop.addons (находка 68)

Архив `dop.addons.7z` (залит владельцем в `master`) влит в **единый** `lua/`:

| Аддон-источник | Решение |
|---|---|
| grm_ctx | → Код 51 `sh_grm_ctx.lua` |
| grm_encumbrance | → Код 52 (только ядро веса; **не** затирали inventory/movement/hud/ui) |
| grm_food | → Код 53 |
| grm_handcuffs | → Код 54 |
| grm_mining_system | → Код 55 (сейвер → `sv_grm_mining_saver*.lua`) |
| grm_roomtap | → Код 56 |
| grm_vehicle_dealer | → Код 57 entity+tool+animfix; **дубли** access/dealer-patch/antistuck **не** трогали (наши 16–18 новее/равнозначны) |
| grm_vehicle_keys_fixed | → Код 58 |
| grm_easychat_edit | → Код 59 `lua/easychat/` |
| grm_spawnpoints | **пропущен** — дубль Кода 15 (`sh_spawn_points.lua`, у нас полнее) |

Исходные README аддонов: `docs/dop/`. Архив: `docs/dop/dop.addons.7z`.

## Файлы данных (garrysmod/data)

`factions.json`, `invites.json`, `factions_extended.json`, `fw_faction_extras.json`,
`default_models.json`, `default_weapons.json`, `grm_inventories.json`,
`grm_economy.json` (+ legacy `grm_faction_budgets.json`, `grm_faction_economy_plus.json` — импортируются один раз), `gnews_log.txt`,
`grm_logistics/{access.json, inventory_crates.json, maps/<map>.json}`,
`grm_factory_fullcycle/{weapon_lockers.json, weapon_market.json, weapon_buyers.json, maps/<map>.json}`,
`grm_admin_log.json`, `grm_player_taxes.json`, `grm_currency.json`,
`spawn_points_global_<map>.json`, `spawn_points_factions_<map>.json`,
`grm_vehicle_purchases.json`, `grm_vehicle_prices.json`, `grm_faction_vehicle_access.json`, `vd_spawn_log.txt`,
`grm_phone/{access.json, shop_catalog.json, shop_purchases.json, player_equipment.json, <map>.json}`,
`grm_phone_records/<YYYY-MM-DD>.txt`,
`grm_roomtap/{access.json,temporary_equipment.json,records/...}`,
`grm_saves/<map>.json`, `grm_saves/grm_orespawns_<map>.json`,
`grm_food_vending_<map>.json` (автоматы)

## Основные команды

**Игрок:** `/inv`, `/store`, `/fjoin`, `/fleave`, `/fr`, `/dep`, `/depb`, `/mask`,
`/model`, `/gnews`, `/kom_hour`, `/logistics_start`, `/logistics_crates`,
`!fbudget`, `!fpay`, `!fwithdraw`, `!fpayall`, `!fsettax`, `/mysalary`, `/fine <сумма> [причина]`, `/vlist`, `/myvehicles`,
`/vshop`, `/phoneshop` (`/teleshop`), `/phone_remove`

**Лидер фракции:** `/vaccess` (доступ транспорта для рангов/отделов)

**Админ:** `/factions`, `/salary_admin`, `/logistics_admin`, `/models_admin`,
`/weapons_admin`, `/mask_admin`, `!grmmenu`/`!grmadmin`/`!econadmin`, `/scanvehicles`,
`/spawnmenu`, `/vshop_admin`, `/phoneshop_admin`, `/phone_access`,
`/phone_admin_remove`, консоль: `grm_logistics_place_*`, `grm_logistics_save/load`,
`grm_logistics_admin_menu`, `grm_logistics_crates`,
`grm_fc_save/load`, `grm_weapon_buyer_admin`, `grm_adminmenu`, `econadmin`, `grm_antistuck_vehicle`,
`grm_phone_save/load`, `grm_phone_remove_look`, `grm_phone_admin_remove`,
`grm_phone_shop_admin`, `grm_phone_shop_add_look`, `grm_phone_shop_reload`,
`grm_phone_access_reload`, `grm_phone_access_debug`,
`grm_money <give|take|set|info|list|save>`, `grm_balance`, `grm_economy <save|list>`,
`grm_cuffs_give`, `grm_saveentities` / `!saveentities`, `vk_givekey`/`vk_revokekey`/`vk_setowner`

Подробный разбор архитектуры и замеченных проблем — в `ANALYSIS.md`.
