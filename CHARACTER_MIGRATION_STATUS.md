# CharacterKey migration status

Дата: 2026-07-22  
Ветка: `arena/019f89cf-drstrasse`

## Готово

- Character Identity API и lifecycle выбора персонажа;
- блокировка спавна до выбора/создания персонажа;
- 3 слота персонажей и миграция старого состояния в `char1`;
- inventory и предметные данные;
- factions, лидерство, роли, отделы, приглашения;
- currency, bank, budgets-facing APIs;
- medical cards и medical full;
- wanted/warrant и доступ к wanted;
- RP descriptions;
- mobile data, SMS/contacts/notes и mobile lines;
- RadioNet frequencies and logs;
- stationary phone access;
- doors, FFD ownership, keypad/scanner;
- CCTV, alarm, RoomTap access;
- vehicle access, dealer ownership, vehicle keys;
- trunk persistence;
- jobs, achievements, handcuffs;
- hunger/food state;
- vendor, printer and search checks;
- spawn points;
- context menu and admin hub character lookups;
- rebuilt distribution archives.

## Scope rules

### CharacterKey

Используется для RP-состояния: фракции, деньги, инвентарь, медкарты, wanted, телефоны, RadioNet, jobs, транспорт, доступы и прогресс.

### AccountKey

Остаётся для технических задач: Steam authentication, root/admin bypass, ULX/EasyChat account features, audit actor and legacy lookup.

## Валидация

- GLua syntax: **293 файлов, 0 ошибок**;
- `sim_factions_live`: 30/30;
- `sim_ffdtools`: 144/144;
- `sim_security`: 50/50;
- `sim_foodkitchen`: 78/78;
- `sim_invphone`: 41/41;
- `sim_jobs`: зелёный;
- `sim_medical`: 75/75;
- `sim_mobile`: 121/121;
- `sim_radionet`: 183/183;
- `sim_trunk`: зелёный;
- `sim_money`: зелёный;
- roundtrip fines: зелёный.

## Намеренные остаточные SteamID-вызовы

1. EasyChat — это account/chat-уровень, не RP-character storage.
2. Root/admin/ULX — права аккаунта, не персонажа.
3. SteamID в админских списках — отображение/аудит.
4. Поиск игрока по старому SteamID — compatibility resolver.
5. Legacy loading/migration — чтение старых файлов.
6. Внутренние debug/log строки — технический аудит.

## Известный protocol audit

`tools/proto_audit.py` сообщает 5 старых протоколов:

- `GRM_FPerm_Set` / `GRM_FPerm_Open` — отдельный faction-perms UI-контур;
- `VD_AdminSpawnVehicle` / `VD_RequestVehicleList` / `VD_VehicleList` — legacy/admin vehicle bridge.

Они не связаны с CharacterKey migration и требуют отдельного решения: реализовать полноценные server receivers либо официально добавить в whitelist как external/legacy protocol.
