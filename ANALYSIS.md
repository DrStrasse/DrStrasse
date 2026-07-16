# Технический анализ кодовой базы GRM (куски 1–3: 23 файла)

Дата анализа: 2026-07-16. Все файлы восстановлены из web-вставки
(HTML-сущности, markdown-ссылки, `_`→`*`) и проходят синтаксический
контроль через luaparser.

## 1. Архитектура

Единая точка интеграции — глобальный `GRM = GRM or {}` и глобальная
таблица `Factions` (создаётся в `sh_factions.lua`). Модули изолированы
подложками: `GRM.Inventory`, `GRM.Movement`, `GRM.Logistics`,
`GRM.FactoryCycle`, `GRM.FactionEconomyPlus`, `GRM.FactionsExt`, `GRM.Chat`.

Кросс-модульные вызовы защищены проверками на nil
(`if GRM.Encumbrance and GRM.Encumbrance.Refresh then ...`), поэтому
модули можно ставить по одному. Жёсткие зависимости:
- `sv_grm_logistics.lua` → `sh_grm_logistics_config.lua` (include, **обязателен**), `GRM.Inventory`, `Factions`
- `sv_grm_factory_fullcycle.lua` → конфиг+entities полного цикла, `GRM.Inventory`, опционально `GRM.Encumbrance`
- экономика/расширение → `Factions` (опционально, с retry-паттерном)
- инвентарь → entity `grm_item_drop` и `GRM.Inventory.OpenGUI()` (оба пока не присланы)

Порядок загрузки: `sh_faction_fixes.lua` по алфавиту идёт РАНЬШЕ
`sh_factions.lua`, поэтому расширение использует `loadExtrasWithRetry()`
с повторами по 0.5 сек — это корректное решение, сохранить его поведение.

Клиентские интерфейсы связаны через **глобальные функции намеренно**:
`OpenAdminMenu`, `refreshAllUI`, `updateLeaderRanks` и пр. объявлены без
`local` в `sh_factions.lua`, а `sh_faction_fixes.lua` переопределяет
`OpenAdminMenu`, добавляя вкладку «Расширенные настройки». Это хрупкий,
но рабочий контракт — при рефакторинге не локализовать эти функции.
Тот же контракт использует кусок 2: `sh_grm_shop_integration.lua`
патчит глобальный `OpenLeaderMenu` (объявлен в `sh_factions.lua:2000`)
через самоликвидирующийся Think-хук и добавляет вкладку «Транспорт»
в DPropertySheet меню лидера.

Кусок 2 дополнительно вводит:
- `sh_grm_admin_menu.lua` — суперадмин-панель экономики (5 вкладок:
  обзор/игроки/фракции/переводы/журнал). Сервер держит кольцевой журнал
  50 записей (`grm_admin_log.json`) и персональные налоги
  (`grm_player_taxes.json`, 0–50%, переопределяют фракционный).
- `sh_grm_shop_integration.lua` — сканер транспорта с кешем 30 с
  (`list.Get("Vehicles")`, `simfphys_vehicles`, `LVS_Vehicles`, scripted
  ents с префиксом `glide_`/базой vehicle) и вкладка «Транспорт».

Кусок 3 добавляет подсистемы:
- **Спавн-поинты** (`sh_spawn_points.lua`): глобальные и фракционные
  точки per-map, PlayerSpawn → случайная точка, админ-меню `/spawnmenu`.
  Новые глобалы: `GlobalSpawnPoints`, `AddGlobalSpawnPoint`,
  `AddSpawnPointForFaction`, `GetSpawnPointForPlayer` и др.
- **Транспорт** (`sh_grm_vehicle_access.lua` + `vehicle_dealer.lua` +
  `zz_grm_vehicle_antistuck.lua`): покупки доступа, доступ
  фракция>отдел>ранг, магазин `/vshop`, патч дилера (хуки
  `VD_PreSpawnCheck`/`VD_FilterVehicleList`/`VD_OnVehicleSpawned`,
  блок Q-меню `PlayerSpawnVehicle`), анти-застревание.
  Новые глобалы: `GRM_HasVehicleAccess`, `GRM_GetAccessibleVehicles`,
  `GRM_GetAllVehicleClasses`, `GRM.VehicleAntiStuck`.
- **Телефония** (`sh_grm_phone_config.lua`, `sh_grm_phone_access.lua`,
  `sh_grm_phone_shop.lua`, `server/sv_grm_phone.lua`,
  `client/cl_grm_phone.lua`): namespace `GRM.Phone` + `.AccessManager` +
  `.Shop`; звонки через АТС с лимитом линий, прослушка (голос И текст
  через перехват PlayerSay), терминал мониторинга, per-map
  персистентность, единый войс-хук (локальный+рация+телефон).

## 2. Потоки данных

- **Логистика:** маршрут `to_loading → loading → to_destination → deliver`.
  Ящик оружия нормируется (2 пистолета/5 автоматов, паттерны классов из
  конфига). Груз попадает в `L.Warehouses[id].stock`, дальше в шкафы через
  `armory_request` с приоритетом явной связи `warehouseID`.
- **Завод:** `scrap_metal → components_box → gpu_* / weapons`; провал QTE
  даёт физический брак + 25% возврата, брак переплавляется обратно в лом.
- **Экономика:** налоги каждые 300 с с баланса игрока → бюджет фракции;
  зарплаты каждые 10 с проверкой индивидуального `NextSalary`.
- **Персистентность** везде JSON в `data/`, карты — по `maps/<map>.json`.

## 3. Замеченные проблемы (не критично для сохранения, но учесть)

1. **Двойная реализация экономики** — `sh_grm_faction_economy.lua` и
   `sh_grm_faction_economy_plus.lua` одновременно определяют
   `GRM.FactionBudgetGet/Add/TaxGet/TaxSet` и обе запускают налоговый
   таймер (300 с). Если загружены обе, налог спишется дважды, а бюджеты
   будут жить в двух разных файлах. **Нужно оставить одну** (Plus,
   она новее и с admin UI) или отключить таймер в старой.
2. `sv_grm_factory_fullcycle.lua`, `FC.OnEntityRemoved`: обращение к
   `qteTimerName` до объявления local — читается как global (nil), поэтому
   срабатывает fallback-конкатенация. Работает, но хрупко: лучше вынести
   `local qteTimerName` выше по файлу.
3. `addStock` (логистика): проверка вместимости считает сумму по подтаблице
   (`weapons`/`items`), а не по категории — лимиты `ammo/medical/materials/
   repair` фактически делят общий пул items. Семантика возможно задумана,
   но стоит проверить.
4. Глобальные имена без префикса (`GetModelsForPlayer`, `ApplyWeaponsToPlayer`,
   `Factions`, `Invites`, `DefaultModels`, `ui`, `FactionsData`) могут
   конфликтовать с другими аддонами.
5. `net.Receive(NET_MASK_ADMIN_DATA)` в клиенте `sh_faction_fixes.lua`
   зарегистрирован дважды — второй обработчик перекрывает первый
   (оба одинаковые, безвредно, но дубль стоит убрать).
6. `hook.Add("KeyPress","GRML_LoadCarriedCrateUse")` возвращает `true` на
   IN_USE при переноске ящика — блокирует прочие Use-действия в этот момент
   (осознанное поведение).
7. `sh_grm_inventory.lua`: `GRM.Inventory.OpenGUI` вызывается на клиенте,
   но реализации GUI в этом пакете нет — будет runtime-ошибка при `/inv`,
   пока не пришлют клиент инвентаря.
8. `sv_grm_logistics.lua`: `L.SaveMap(nil)` вызывается в net-обработчиках
   до текстового объявления функции — корректно (lookup в момент вызова),
   но путает при чтении.
9. Некоторые net-action'ы (`admin_*`, `warehouse_link`, `armory_link`)
   валидируют права через `p:IsSuperAdmin()` — ок; `place()` тоже.
   `startRoute` доверяет entity из нета, но сверяет `resolveTruck(p)==truck`.
10. Move-хук стамины применяется ко всем игрокам; при bhop в воздухе
    maxSpeed = WalkSpeed*1.2 и не тратит стамину — задумано.
11. `sh_grm_admin_menu.lua` по алфавиту грузится РАНЬШЕ обеих экономик и
    создаёт fallback-заглушки `GRM.FactionBudgetGet/Add/TaxGet/TaxSet`
    (`= GRM.X or function...`). Настоящие реализации из экономики их
    перезаписывают — порядок корректный. Но если экономику отключить,
    админка молча покажет нулевые бюджеты: учитывать при диагностике.
12. `GRM.GetPlayerTaxRate` теперь определяется admin-меню (сервер,
    `grm_player_taxes.json`), а `sh_grm_faction_economy.lua:161` зовёт
    его с nil-guard — персональные налоги свяжутся автоматически.
    ВНИМАНИЕ: `sh_grm_faction_economy_plus.lua` персональный налог НЕ
    использует — ещё один аргумент в пользу «оставить одну экономику»
    (см. пункт 1) либо допилить Plus.
13. Admin-меню добавляет требования к ядру валюты: `GRM.SetBalance(ply,n)`
    и `GRM.StartBalance` (было только Give/Take/Has/GetBalance/Format).
    `GRM.Notify(ply, msg, r, g, b)` — подтверждённая сигнатура (5 арг.).
14. Безопасность admin-меню нормальная: все серверные net-обработчики
    (`grm_admin_request`, `grm_admin_action`) защищены `hasAdminAccess`
    (superadmin / whitelist SteamID64); клиентская конкоманда слабее
    (IsAdmin), но сервер всё равно ответит «Нет прав». Минус: `buildData()`
    при запросе делает вложенные проходы игроки×фракции×игроки —
    O(n²) при большом онлайне; для админ-панели терпимо.
15. Shop integration: безопасность `/scanvehicles` — IsAdmin, `/vlist`
    безопасен. Кнопки вкладки «Транспорт» шлют `GRM_VAccess_Open` и
    `GRM_VShop_Open` — серверные получатели ещё НЕ присланы
    (`sh_grm_vehicle_access.lua`, `vehicle_dealer.lua`); при получении
    проверить, что они сами валидируют права (лидер фракции/админ).
    До тех пор net-сообщения просто игнорируются сервером — без вреда.
    (Код 16 закрыл эти получатели: `GRM_VAccess_Open`/`GRM_VShop_Open`
    теперь обрабатываются сервером, права проверяются — лидер/суперадмин.)
16. `PlayerSayTransform` — НЕ ванильный GMod-хук (ваниль: `PlayerSay` /
    `OnPlayerChat`), но используется повсеместно в проекте (Код 10:2163,
    Код 11 ×2, теперь Код 15, 20, 21). Предположительно его вызывает
    недостающая реализация `GRM.Chat` или базовый gamemode. До её появления
    клиентские команды через этот хук (`/spawnmenu`, `/phone_access`,
    клиентский `/phoneshop_admin`) работать не будут.
17. Хук `FactionCreated` (слушает `sh_spawn_points.lua`) нигде не вызывается
    (`hook.Run` в `sh_factions.lua` отсутствует) → `SpawnPoints_InitNew`
    не сработает. Не критично: `ensureFactionSpawnPoints` вызывается лениво
    во всех API точек. Замечание на будущее: поле `f.SpawnPoints` живёт
    внутри объекта фракции — если `sh_factions.lua` сериализует фракции
    целиком, точки попадут и в `factions.json` (дубль с
    `spawn_points_factions_<map>.json`, безвредный).
18. `RadioFrequencies` (глобал для радио-войса телефонии) нигде в пакете
    не создаётся → `radioVoice()` всегда false, с nil-guard. Телефония
    и рация свяжутся сами, когда появится радио-модуль с этой таблицей.
19. Телефон-оверрайд через таймеры корректен: `sh_grm_phone_access.lua`
    грузится в `lua/autorun/`, а `server/sv_grm_phone.lua` — ПОЗЖЕ
    (subdir), и переопределяет `P.HasEquipmentAccess`. Поэтому
    AccessManager переустанавливает override на 0/1/3/6 с — победит
    AccessManager (данные из `grm_phone/access.json`), fallback на
    конфиг сохранён внутри проверки. Задумано верно.
20. `vehicle_dealer.lua`: fallback в `VD_FilterVehicleList` — «если после
    фильтрации 0, показываем всё» — ослабляет защиту при ненастроенном
    магазине (осознанная обратная совместимость, но злоупотребляемо:
    игрок без прав может видеть полный список дилера). Комбинация с
    `PlayerSpawnVehicle`-блоком всё равно не даёт заспавнить.
21. `zz_`-префикс антистастка — верное решение: `lua/autorun/` грузится
    по алфавиту, `zz_` ставит `ShouldCollide`-хук позже остальных.
    Аккуратная тонкая логика (OnlyAfterVehicleExit + малый
    InsideOBBExpand) — редкий случай зрелого тюнинга после плохого UX.
22. Двойная персистентность телефонии НЕ дублирует entity:
    `P.SaveMapEntities` пропускает `ent.GRMPhoneShopOwned` (их хранит
    магазин в `player_equipment.json`). `AdminRemoveEntity` корректно
    чистит обе базы (`removeFromShopStorage` + немедленный
    `SaveMapEntities`).
23. Магазин транспорта (Код 16) на клиенте показывает баланс через
    `GRM.LocalBalance` — клиентской переменной в пакете НЕТ (ждём ядро
    валюты); без неё UI покажет «Баланс: ???» — остальное работает.
24. Мёртвый код (безвредно): в `sv_grm_phone.lua` локали `allWiretaps`/
    `allTerminals` объявлены, но не используются (мониторинг идёт через
    `P.Monitoring`).

## 4. Совместимость с GLua

Используются GLua-расширения: `continue` (ломает стандартный luac—
учтено в проверке), `SIMPLE_USE`, `SetNW*` устаревшие алиасы (работают).
Код в консистентном стиле: компактные one-liner функции в серверных
модулях, развёрнутый VGUI-код на клиенте.

## 5. Быстрый чек-лист запуска

1. Доложить `sh_grm_logistics_config.lua` (иначе логистика не стартует).
2. Доложить клиенты UI: `cl_grm_faction_logistics.lua`,
   `cl_grm_factory_fullcycle.lua`, GUI инвентаря, `grm_item_drop`,
   ядро валюты `GRM.GiveMoney/TakeMoney/HasMoney/GetBalance/SetBalance/
   Format/Notify` + `GRM.StartBalance`.
3. Выбрать одну экономику (см. пункт 1 раздела 3).
4. Положить `sound/kom_hour.wav` для комендантского часа.
5. Проверить классы транспорта в `L.Access.vehicles` под simfphys/LVS.
6. Для вкладки «Транспорт» (Код 14): `sh_grm_vehicle_access.lua` +
   `vehicle_dealer.lua` уже на месте (Код 16–17); осталась entity
   `sent_vehicle_dealer`.
7. Доложить 5 entity телефонии (`entities/grm_phone|grm_payphone|
   grm_pbx_station|grm_phone_wiretap|grm_phone_terminal`) — без них
   `ents.Create` вернёт NULL и магазин/сохранение не заработают.
