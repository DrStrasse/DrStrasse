# Технический анализ кодовой базы GRM (кусок 1: 12 файлов)

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

## 4. Совместимость с GLua

Используются GLua-расширения: `continue` (ломает стандартный luac—
учтено в проверке), `SIMPLE_USE`, `SetNW*` устаревшие алиасы (работают).
Код в консистентном стиле: компактные one-liner функции в серверных
модулях, развёрнутый VGUI-код на клиенте.

## 5. Быстрый чек-лист запуска

1. Доложить `sh_grm_logistics_config.lua` (иначе логистика не стартует).
2. Доложить клиенты UI: `cl_grm_faction_logistics.lua`,
   `cl_grm_factory_fullcycle.lua`, GUI инвентаря, `grm_item_drop`,
   ядро валюты `GRM.GiveMoney/...`.
3. Выбрать одну экономику (см. пункт 1 раздела 3).
4. Положить `sound/kom_hour.wav` для комендантского часа.
5. Проверить классы транспорта в `L.Access.vehicles` под simfphys/LVS.
