# Полный аудит Lua-кода GRM

Дата: 2026-07-22  
Ветка: `arena/019f89cf-drstrasse`

## 1. Объём

Аудит охватывает **все 302 Lua-файла** под `lua/`:

| Область | Файлов | Строк |
|---|---:|---:|
| `autorun/` | 106 | 56 444 |
| `entities/` | 125 | 8 289 |
| `weapons/` | 20 | 3 164 |
| `easychat/` | 50 | 16 361 |
| **Итого** | **302** | **84 854** |

`vgui/` в репозитории отсутствует. По структуре: 41 entity-директория, 20 weapon/tool-файлов и 50 файлов EasyChat.

## 2. Архитектурные модули

### Фракции, идентичность и RP

- `sh_factions.lua` — ядро фракций, ранги, отделы, приглашения, синхронизация и базовые меню.
- `sh_faction_fixes.lua` — расширение фракций: модели, оружие, маскировка, комендантский час, новости, админские вкладки.
- `sh_grm_faction_perms.lua` + `client/cl_grm_faction_perms_ui.lua` — права фракций.
- `sh_grm_factions_bridge.lua` — мост фракционных прав для вещания/оповещений/доски/биржи.
- `sh_grm_character.lua` — персонажи, RP-имя, 3 слота, `CharacterID/CharacterKey`, миграция старого персонажа.
- `sh_grm_rpdesc.lua` — RP-имя и описание над головой.
- `sh_grm_rp_chat.lua`, `zz_easychat_grm_fix.lua` — RP-команды и патчи чата.
- `sh_grm_chat_config.lua` — радиусы и цвета RP-чата.
- `sh_grm_laws.lua` — законы и права редактирования.
- `sh_grm_f4menu.lua` — F4-меню профиля, команд, настроек, графики и расширяемых вкладок.
- `sh_grm_tab_menu.lua` — Tab/scoreboard, RP-имена, фракции, балансы, голос.
- `sh_grm_achievements.lua` — ачивки, прогресс, ежедневный бонус.
- `sh_grm_board.lua` + `entities/grm_board/*` — доска набора во фракцию и автозачисление.
- `sh_grm_jobs.lua` + `entities/grm_jobcenter/*`, `grm_depot/*` — биржа труда, заказы, вакансии и смены.
- `sh_spawn_points.lua` — фракционные/глобальные точки спавна.

### Экономика, деньги и инвентарь

- `sh_grm_currency.lua` — наличные, баланс, сохранение, синхронизация HUD.
- `sh_grm_economy.lua` — банк, бюджеты, зарплаты, штрафы, налоги, госбюджет.
- `sh_grm_faction_economy.lua` — легаси-экономический файл; требует контроля, чтобы не активировать вторую реализацию экономики.
- `sh_grm_feco_admin.lua` — старая/совместимая админка экономики.
- `sh_grm_admin_hub.lua` — единая админ-панель сервера.
- `entities/grm_bank_terminal/*` — банкомат/терминал личных и фракционных счетов.
- `sh_grm_inventory.lua` — инвентарь, предметы, стаки, use-handler API, персистентность по CharacterKey.
- `client/cl_grm_inventory_ui.lua` — UI инвентаря.
- `entities/grm_item_drop/*` — выброшенные предметы.
- `entities/grm_money_drop/*` — физический дроп денег.
- `sh_grm_encumbrance_config.lua`, `client/cl_grm_encumbrance.lua`, `server/sv_grm_encumbrance.lua` — вес/переносимый груз.
- `client/cl_grm_hud.lua` — HUD здоровья, брони, наличных, счёта, патронов.
- `sh_grm_trunk.lua` — багажники транспорта, перенос предметов и сохранение.

### Телефония и связь

- `sh_grm_phone_config.lua` — конфигурация телефонии.
- `sh_grm_phone_access.lua` — права доступа к телефонным объектам.
- `sh_grm_phone_shop.lua` — магазин стационарной и мобильной телефонии.
- `server/sv_grm_phone.lua`, `client/cl_grm_phone.lua` — серверные звонки, линии, текст, прослушка и клиентские окна.
- `sh_grm_mobile.lua` — мобильные телефоны, 7 тиров, приложения, линии, SMS, контакты, форум, UI и управление.
- `entities/grm_mobile_line/*` — мобильная линия.
- `entities/grm_payphone/*`, `grm_pbx_station/*`, `grm_phone/*`, `grm_phone_terminal/*`, `grm_phone_wiretap/*` — телефонные объекты.
- `sh_grm_radionet.lua` — радиосеть, покрытие, частоты `/freq`, эфир `/r`, устройства, группы, журнал и пеленг.
- `sh_grm_broadcast.lua` — микрофоны, радио, оповещения и громкоговорители.
- `entities/grm_server_rack/*`, `grm_antenna/*`, `grm_radio_station/*`, `grm_radio/*`, `grm_broadcast_mic/*`, `grm_loudspeaker/*`, `grm_net_console/*` — устройства RadioNet/Broadcast.
- `weapon_grm_megaphone/shared.lua` — мегафон.

### Безопасность и двери

- `sh_grm_doors.lua` — двери, замки, парные створки, HUD, персистентность и реконсилер.
- `sh_grm_doors_access.lua` — ACL дверей, категории фракций, роли и ордера.
- `sh_grm_wanted_config.lua`, `sh_grm_wanted_access.lua`, `server/sv_grm_wanted.lua`, `client/cl_grm_wanted.lua` — wanted/warrant.
- `sh_grm_alarm_config.lua`, `sh_grm_alarm_access.lua`, `server/sv_grm_alarm.lua`, `client/cl_grm_alarm.lua` — сигнализации.
- `entities/grm_alarm_sensor/*`, `grm_alarm_hub/*`, `grm_alarm_terminal/*`, `grm_alarm_speaker/*` — датчики, хабы, терминалы и сиренные динамики.
- `sh_grm_cctv_config.lua`, `sh_grm_cctv_access.lua`, `server/sv_grm_cctv.lua`, `client/cl_grm_cctv.lua` — CCTV.
- `entities/grm_cctv_camera/*`, `grm_cctv_monitor/*`, `grm_cctv_server/*` — CCTV-энтити.
- `sh_grm_roomtap_config.lua`, `server/sv_grm_roomtap.lua`, `client/cl_grm_roomtap.lua` — прослушка помещений.
- `entities/grm_roomtap_chip/*`, `grm_roomtap_server/*`, `grm_roomtap_terminal/*` — прослушивающие устройства.
- `sh_grm_perm_entities.lua`, `server/sv_grm_perms_test.lua` — универсальная перманентность сущностей и тестовый контур.
- `sh_grm_rootguard.lua` — защита критических действий владельцем сервера.
- `sh_grm_ffdlink.lua` — ручные связи FFD-контроллеров с дверями.
- `entities/grm_keypad/*`, `grm_scanner/*` — PIN-кейпад и фракционный сканер.
- `weapons/ds_key_swep/shared.lua` — дверные ключи.
- `weapons/ds_battering_ram/shared.lua` — полицейский таран.
- `weapons/ds_lockpick/shared.lua` — QTE-отмычка.
- `weapons/keypad.lua` — классический keypad SWEP.
- `weapons/gmod_tool/stools/ffd_fading_door.lua`, `fading_door.lua` — FFD-двери.
- `weapons/gmod_tool/stools/ffd_keypad.lua`, `keypad.lua` — инструмент кейпада.
- `weapons/gmod_tool/stools/ffd_scanner.lua` — инструмент сканера.
- `weapons/gmod_tool/stools/ffd_link.lua` — инструмент связи.

### Производство, торговля и предметы

- `sh_grm_factory_fullcycle_config.lua`, `sh_grm_factory_fullcycle_entities.lua`, `server/sv_grm_factory_fullcycle.lua`, `client/cl_grm_factory_fullcycle.lua` — полный цикл завода, QTE, лом, GPU и оружие.
- `sh_grm_logistics_config.lua`, `sh_grm_logistics_entities.lua`, `server/sv_grm_logistics.lua`, `client/cl_grm_faction_logistics.lua` — логистика, склады, ящики и оружейные шкафы.
- `sh_grm_mining.lua`, `server/sv_grm_mining_saver.lua`, `server/sv_grm_mining_saver_delete_patch.lua`, `server/sv_grm_ore_spawner.lua` — добыча руды и сохранение узлов.
- `sh_grm_ore_defs.lua`, `sh_grm_ore_processing.lua`, `sh_grm_ore_admin.lua`, `entities/grm_ore_node.lua`, `grm_ore_chunk.lua`, `grm_ore_buyer/*` — определения руды, обработка, покупатель и куски руды.
- `sh_grm_vendor.lua`, `client/cl_grm_vendor_ui.lua`, `entities/grm_vendor/*`, `weapons/gmod_tool/stools/grm_vendor_tool.lua` — единый фреймворк торговцев.
- `sh_grm_food_config.lua`, `sh_grm_food_kitchen.lua`, `server/sv_grm_food.lua`, `client/cl_grm_food_kitchen.lua`, `client/cl_grm_food_hud.lua` — еда, кухня, порча и HUD.
- `entities/grm_food_stove/*`, `grm_food_fridge/*`, `grm_food_planter/*` — плита, холодильник и горшок.
- `sh_grm_narcotics.lua`, `sh_grm_medical_full.lua`, `server/sv_grm_narcotics_craft.lua`, `client/cl_grm_narcotics_craft.lua`, `entities/grm_narc_lab/*`, `grm_med_lab/*` — наркотики, препараты и лаборатории.
- `sh_grm_medical.lua` — медицинские карты и выдача карты на руки.
- `sh_grm_vendor.lua` также продаёт редкий денежный принтер.
- `entities/grm_money_printer/*` — накопление денег, перегрев, ремонт и улучшения.
- `sh_grm_shop_integration.lua`, `sh_grm_vehicle_access.lua`, `vehicle_dealer.lua`, `weapons/gmod_tool/stools/vehicle_dealer_tool.lua` — доступ к транспорту и старый дилерский контур.
- `entities/sent_vehicle_dealer/*` — основной дилер.
- `sh_vehicle_keys.lua`, `server/sv_vehicle_keys.lua`, `weapons/vehicle_keys_swep.lua` — ключи транспорта.
- `server/sv_grm_vehicle_dealer_anim_fix.lua`, `zz_grm_vehicle_antistuck.lua`, `client/cl_vehicle_hud.lua` — патчи дилера, антизастревание и подсказки транспорта.

### Q-меню, наручники и дополнительные патчи

- `sh_grm_qmenu.lua` — GRM Стройка+, ограничения Q, каталог, инструменты, лимиты и админ-настройки.
- `sh_grm_handcuffs_config.lua`, `server/sv_grm_handcuffs.lua`, `client/cl_grm_handcuffs.lua`, `weapons/grm_handcuffs/shared.lua`, `weapons/grm_cuffed/shared.lua` — наручники.
- `zz_grm_food_hunger_balance_patch.lua` — патч баланса голода.
- `zz_grm_food_inventory_patch.lua` — use-handler интеграция еды.
- `zz_grm_handcuffs_access_patch.lua` — патч доступа к наручникам.
- `sh_grm_movement.lua` — стамина и движение.
- `sh_grm_ctx.lua` — C-меню и контекстные команды.
- `sh_grm_f4menu.lua` — пользовательская точка входа в меню.

## 3. EasyChat — отдельный встроенный пакет

### Ядро и загрузка

- `easychat.lua` — главный чатовый движок.
- `autoloader.lua` — загрузчик.
- `networking.lua` — сетевой слой.
- `server_config.lua` — серверная конфигурация.
- `engine_chat_hack.lua` — интеграция с движковым чатом.
- `markup.lua` — разметка сообщений.
- `migrations.lua`, `migrations/1583595318_history_directory_change.lua` — миграции.
- `unicode_transliterator.lua` — транслитерация.
- `chathud.lua` — HUD чата.

### Клиентская основа и VGUI

- `client/settings.lua`, `client/cef_detection.lua`, `client/blur_panel.lua`, `client/font_extensions.lua`, `client/macro_processor.lua`, `client/translator.lua`.
- `client/vgui/chat_tab.lua`, `chatbox_panel.lua`, `chathud_font_editor_panel.lua`, `color_picker.lua`, `emote_picker.lua`, `richtext_legacy.lua`, `richtextx.lua`, `settings_menu.lua`, `textentry_legacy.lua`, `textentryx.lua`.

### EasyChat-модули

- `modules/admin_tab.lua` — админская вкладка.
- `modules/client/big_text_messages.lua` — крупные сообщения.
- `modules/client/bttv_emojis.lua`, `ffz_emojis.lua`, `steam_emojis.lua`, `twemojis.lua` — эмодзи.
- `modules/client/darkrp.lua`, `terrortown.lua`, `starfall_compat.lua` — интеграции.
- `modules/client/global_msg_history.lua` — глобальная история.
- `modules/client/greentext.lua` — greentext.
- `modules/client/local_ui.lua` — локальный UI.
- `modules/client/macros_tab.lua` — макросы.
- `modules/client/mentions.lua` — упоминания.
- `modules/client/silk_icons.lua` — иконки.
- `modules/client/voice_hud.lua` — голосовой HUD.
- `modules/client/word_delete_shortcut.lua` — удаление слов.
- `modules/client/cmds_auto_completion.lua` — автодополнение команд.
- `modules/client/dm_tab.lua` — личные сообщения.
- `modules/client/extra_tags.lua` — дополнительные теги.
- `modules/client/indications.lua` — индикаторы.
- `modules/client/join_leave.lua` — сообщения входа/выхода.
- `modules/server/murder.lua` — интеграция Murder.

## 4. Перечень всех файлов

Ниже приведён полный inventory; файл считается проанализированным по принадлежности к модулю, стороне исполнения и размеру.

### `autorun/client`

`cl_grm_alarm.lua`, `cl_grm_cctv.lua`, `cl_grm_encumbrance.lua`, `cl_grm_faction_logistics.lua`, `cl_grm_faction_perms_ui.lua`, `cl_grm_factory_fullcycle.lua`, `cl_grm_food_hud.lua`, `cl_grm_food_kitchen.lua`, `cl_grm_handcuffs.lua`, `cl_grm_hud.lua`, `cl_grm_inventory_ui.lua`, `cl_grm_narcotics_craft.lua`, `cl_grm_phone.lua`, `cl_grm_roomtap.lua`, `cl_grm_search_result.lua`, `cl_grm_vending_gui.lua`, `cl_grm_vendor_ui.lua`, `cl_grm_wanted.lua`, `cl_vehicle_hud.lua`.

### `autorun/server`

`sv_grm_alarm.lua`, `sv_grm_cctv.lua`, `sv_grm_encumbrance.lua`, `sv_grm_factory_fullcycle.lua`, `sv_grm_food.lua`, `sv_grm_handcuffs.lua`, `sv_grm_logistics.lua`, `sv_grm_mining_saver.lua`, `sv_grm_mining_saver_delete_patch.lua`, `sv_grm_narcotics_craft.lua`, `sv_grm_ore_spawner.lua`, `sv_grm_perms_test.lua`, `sv_grm_phone.lua`, `sv_grm_roomtap.lua`, `sv_grm_vehicle_dealer_anim_fix.lua`, `sv_grm_wanted.lua`, `sv_grm_wardrobe_spawn.lua`, `sv_vehicle_keys.lua`.

### `autorun` shared/root

`easychat_init.lua`, `sh_faction_fixes.lua`, `sh_factions.lua`, `sh_grm_achievements.lua`, `sh_grm_admin_hub.lua`, `sh_grm_alarm_access.lua`, `sh_grm_alarm_config.lua`, `sh_grm_board.lua`, `sh_grm_broadcast.lua`, `sh_grm_cctv_access.lua`, `sh_grm_cctv_config.lua`, `sh_grm_character.lua`, `sh_grm_chat_config.lua`, `sh_grm_ctx.lua`, `sh_grm_currency.lua`, `sh_grm_doors.lua`, `sh_grm_doors_access.lua`, `sh_grm_economy.lua`, `sh_grm_encumbrance_config.lua`, `sh_grm_f4menu.lua`, `sh_grm_faction_economy.lua`, `sh_grm_faction_perms.lua`, `sh_grm_factions_bridge.lua`, `sh_grm_factory_fullcycle_config.lua`, `sh_grm_factory_fullcycle_entities.lua`, `sh_grm_feco_admin.lua`, `sh_grm_ffdlink.lua`, `sh_grm_food_config.lua`, `sh_grm_food_kitchen.lua`, `sh_grm_handcuffs_config.lua`, `sh_grm_inventory.lua`, `sh_grm_jobs.lua`, `sh_grm_laws.lua`, `sh_grm_logistics_config.lua`, `sh_grm_logistics_entities.lua`, `sh_grm_medical.lua`, `sh_grm_medical_full.lua`, `sh_grm_mining.lua`, `sh_grm_mobile.lua`, `sh_grm_movement.lua`, `sh_grm_narcotics.lua`, `sh_grm_ore_admin.lua`, `sh_grm_ore_defs.lua`, `sh_grm_ore_processing.lua`, `sh_grm_perm_entities.lua`, `sh_grm_phone_access.lua`, `sh_grm_phone_config.lua`, `sh_grm_phone_shop.lua`, `sh_grm_qmenu.lua`, `sh_grm_radionet.lua`, `sh_grm_roomtap_config.lua`, `sh_grm_rootguard.lua`, `sh_grm_rp_chat.lua`, `sh_grm_rpdesc.lua`, `sh_grm_shop_integration.lua`, `sh_grm_tab_menu.lua`, `sh_grm_trunk.lua`, `sh_grm_vehicle_access.lua`, `sh_grm_vendor.lua`, `sh_grm_wanted_access.lua`, `sh_grm_wanted_config.lua`, `sh_spawn_points.lua`, `sh_vehicle_keys.lua`, `vehicle_dealer.lua`, `zz_easychat_grm_fix.lua`, `zz_grm_food_hunger_balance_patch.lua`, `zz_grm_food_inventory_patch.lua`, `zz_grm_handcuffs_access_patch.lua`, `zz_grm_vehicle_antistuck.lua`.

### `entities`

Все entity-файлы сгруппированы по классам: `grm_alarm_hub`, `grm_alarm_sensor`, `grm_alarm_speaker`, `grm_alarm_terminal`, `grm_antenna`, `grm_bank_terminal`, `grm_board`, `grm_broadcast_mic`, `grm_cctv_camera`, `grm_cctv_monitor`, `grm_cctv_server`, `grm_depot`, `grm_food_fridge`, `grm_food_planter`, `grm_food_stove`, `grm_item_drop`, `grm_jobcenter`, `grm_keypad`, `grm_loudspeaker`, `grm_med_lab`, `grm_mobile_line`, `grm_money_drop`, `grm_money_printer`, `grm_narc_lab`, `grm_net_console`, `grm_ore_buyer`, `grm_ore_chunk`, `grm_ore_node`, `grm_payphone`, `grm_pbx_station`, `grm_phone`, `grm_phone_terminal`, `grm_phone_wiretap`, `grm_radio`, `grm_radio_station`, `grm_roomtap_chip`, `grm_roomtap_server`, `grm_roomtap_terminal`, `grm_scanner`, `grm_server_rack`, `grm_vendor`, `grm_wardrobe`, `sent_vehicle_dealer`.

Для классов с папками обычно присутствуют `shared.lua`, `init.lua`, `cl_init.lua`; `grm_ore_chunk.lua` и `grm_ore_node.lua` являются одиночными entity-файлами.

### `weapons`

`ds_battering_ram/shared.lua`, `ds_key_swep/shared.lua`, `ds_lockpick/shared.lua`, `gmod_tool/stools/fading_door.lua`, `gmod_tool/stools/ffd_fading_door.lua`, `gmod_tool/stools/ffd_keypad.lua`, `gmod_tool/stools/ffd_link.lua`, `gmod_tool/stools/ffd_scanner.lua`, `gmod_tool/stools/grm_lab_tool.lua`, `gmod_tool/stools/grm_vendor_tool.lua`, `gmod_tool/stools/keypad.lua`, `gmod_tool/stools/vehicle_dealer_tool.lua`, `grm_cuffed/shared.lua`, `grm_handcuffs/shared.lua`, `keypad.lua`, `vehicle_keys_swep.lua`, `weapon_grm_megaphone/shared.lua`, `weapon_grm_search/cl_init.lua`, `weapon_grm_search/init.lua`, `weapon_grm_search/shared.lua`.

## 5. Статические результаты аудита

- `net.Start`: 455 вызовов в 86 файлах.
- `net.Receive`: 361 вызов в 86 файлах.
- `timer.Create`: 104 вызова в 55 файлах.
- `Think`-хуки: 18 вхождений в 14 файлах.
- `JSONToTable`: 77 вхождений в 52 файлах; критично вручную проверять каждое место с ключами SteamID64/CharacterKey.
- `TODO/FIXME/XXX`: 10 вхождений в 5 файлах.
- `continue`: 10 вхождений в 3 файлах (`sh_factions.lua`, EasyChat settings/autocomplete).
- `goto`: 11 вхождений в `sh_grm_jobs.lua`.

## 6. Текущие проблемы и риски

### Подтверждено инструментами

1. `tools/glua_check.py` не запустился: отсутствует `.luabuild/lj/src/luajit`. Это проблема окружения, а не доказанная ошибка Lua.
2. `tools/proto_audit.py` сообщает 5 асимметрий:
   - faction permissions: `GRM_FPerm_Set`, `GRM_FPerm_Open`;
   - vehicle dealer: `VD_AdminSpawnVehicle`, `VD_RequestVehicleList`, `VD_VehicleList`.
   Их следует либо подтвердить как серверные/внешние протоколы и добавить whitelist, либо исправить.
3. `sh_grm_faction_economy.lua` существует рядом с `sh_grm_economy.lua`; нужно подтвердить, что legacy-файл не запускает параллельные налоги/бюджеты.

### Архитектурные риски

1. Большое количество глобальных API (`GRM`, `Factions`, глобальные UI-функции) и патчей `zz_` создаёт зависимость от порядка загрузки.
2. 455 `net.Start`-вызовов требуют регрессионного протокольного аудита после каждой правки UI.
3. 104 таймера и 18 Think-вхождений создают нагрузку; наиболее подозрительные зоны — CCTV, mobile, RadioNet, EasyChat и экономика.
4. 77 вызовов JSON-парсера требуют единого правила `JSONToTable(raw, false, true)` для ключей SteamID64/CharacterKey и нормализации числовых ключей слотов.
5. `continue/goto` нужно оценивать в контексте именно GLua, а не ванильного LuaJIT; внешний syntax-checker может давать ложные ошибки.
6. EasyChat — большой самостоятельный пакет на 16 тыс. строк; его не следует массово рефакторить вместе с GRM без отдельных тестов.
7. `sent_vehicle_dealer/init.lua` и старые `vehicle_dealer.lua`/`sh_grm_shop_integration.lua` образуют потенциальный legacy-контур; необходим тест фактического порядка загрузки и единственного авторитетного спавна транспорта.

## 7. Итог

Кодовая база состоит из четырёх крупных слоёв:

1. ядро GRM и RP-системы;
2. экономика/инвентарь/предметы;
3. безопасность/связь/производство/торговля;
4. встроенный EasyChat.

Функционально проект очень широкий и уже имеет персистентность, серверную авторизацию и тестовые стенды. Главные задачи для дальнейшей стабилизации — не добавление новых функций, а проверка загрузочного порядка, устранение протокольных асимметрий, единообразный JSON-парсинг, подтверждение отсутствия двойной экономики и запуск полного тестового набора в среде с LuaJIT.
