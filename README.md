# GRM — Garry's Mod RP-сборка (DrStrasse)

Набор Lua-модулей для Garry's Mod: фракции, экономика, инвентарь, логистика,
завод полного цикла, стамина, конфиг чата. Все модули общаются через
глобальный namespace `GRM` и глобальную таблицу `Factions`.

## Установка

Скопировать содержимое `lua/` в `garrysmod/addons/grm/lua/`
(или прямо в `garrysmod/lua/`). Файлы в `lua/autorun/` загружаются
автоматически на сервере и клиенте.

## Файлы (кусок 1 — 12 модулей)

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

## Зависимости, которых пока НЕТ в репозитории

Эти модули упоминаются в коде, но ещё не присланы (ожидаются следующими кусками):

- `lua/autorun/sh_grm_logistics_config.lua` — **обязателен** для `sv_grm_logistics.lua`
- `lua/autorun/client/cl_grm_faction_logistics.lua` — клиент логистики (UI)
- `lua/autorun/client/cl_grm_factory_fullcycle.lua` — клиент завода (UI крафта и QTE)
- Ядро валюты: `GRM.GiveMoney / TakeMoney / HasMoney / GetBalance / Format / Notify`
- `GRM.Encumbrance` — система веса/перегруза
- GUI инвентаря: `GRM.Inventory.OpenGUI()` + entity `grm_item_drop`
- `GRM.Chat` — основная реализация чата (здесь только конфиг)
- `GRM.Phone` — телефония (кнопка в настройках расширения фракций)
- Шрифты `GRM_HUD_Label`, `GRM_HUD_Value` — из HUD-ядра
- Внешние: ArcCW (оружие), simfphys/LVS (матовозки), ULX/ULib (опционально)
- Ресурс `sound/kom_hour.wav` — положить в `addons/grm/sound/`

## Файлы данных (garrysmod/data)

`factions.json`, `invites.json`, `factions_extended.json`, `fw_faction_extras.json`,
`default_models.json`, `default_weapons.json`, `grm_inventories.json`,
`grm_faction_budgets.json`, `grm_faction_economy_plus.json`, `gnews_log.txt`,
`grm_logistics/{access.json, inventory_crates.json, maps/<map>.json}`,
`grm_factory_fullcycle/{weapon_lockers.json, weapon_market.json, weapon_buyers.json, maps/<map>.json}`

## Основные команды

**Игрок:** `/inv`, `/store`, `/fjoin`, `/fleave`, `/fr`, `/dep`, `/depb`, `/mask`,
`/model`, `/gnews`, `/kom_hour`, `/logistics_start`, `/logistics_crates`,
`!fbudget`, `!fpay`, `!fwithdraw`, `!fpayall`, `!fsettax`

**Админ:** `/factions`, `/salary_admin`, `/logistics_admin`, `/models_admin`,
`/weapons_admin`, `/mask_admin`, консоль: `grm_logistics_place_*`,
`grm_logistics_save/load`, `grm_fc_save/load`, `grm_weapon_buyer_admin`

Подробный разбор архитектуры и замеченных проблем — в `ANALYSIS.md`.
