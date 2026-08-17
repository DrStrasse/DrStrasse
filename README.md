# GRM — Garry's Mod RP-сборка (DrStrasse)

Полнофункциональный набор Lua-модулей для roleplay-серверов Garry's Mod:
фракции, экономика, инвентарь, документы, служебные компьютеры, розыск и штрафы,
транспорт, логистика, маскировка, комендантский час, CCTV, прослушка, пожарная
служба, биржа труда, телефон и многое другое.

> **Передача дел:** сначала `HANDOVER.md`, потом `ARCHITECTURE.md`.
> История правок — `CHANGELOG.md`.

## Состав репозитория

| Путь | Что это |
|---|---|
| `lua/` | Весь код (авторан, энтити, оружие, тулзы, easychat) |
| `materials/` | Материалы (интерфейс, оверлеи, текстуры) |
| `models/` | Модели |
| `addons/grm_fire/` | Отдельный пожарный аддон (vFire, рукава, гидранты, насосы) |
| `tools/` | Скрипты сборки (`build_dist.py`), аудит производительности, luatest-моки |
| `dist/` | Готовые архивы для установки |

## Установка

Основной аддон кладётся в `garrysmod/addons/grm/` (архив `dist/grm_single_addon.zip`
уже содержит префикс `grm/`), пожарный — в `garrysmod/addons/grm_fire/`
(`dist/grm_fire_addon.zip`).

> **Важно при обновлении:** удалите старую папку `addons/grm` целиком и только
> потом распакуйте новую сборку. Простое копирование поверх не удалит старые файлы.

Сборка архивов:
```bash
python3 tools/build_dist.py
```

## GRM Core — общий фундамент

Все модули общаются через глобальный namespace `GRM` и глобальную таблицу
`Factions`. Общий фундамент:

| Namespace | Назначение | Файл |
|---|---|---|
| `GRM.Core` | версии и обязательные инженерные правила | `sh_01_grm_core.lua` |
| `GRM.Lang` | локализация по стабильным ключам (ru/en) | `sh_01_grm_core.lua` |
| `GRM.Persistence` | безопасный JSON и реестр persistence-backend | `sh_02_grm_persistence.lua` |
| `GRM.Access` | capability registry и единые назначения прав | `sh_03_grm_access.lua` |
| `GRM.Net` | rate limit, размер пакета, дистанция, capability | `sh_04_grm_net.lua` |
| `GRM.Audit` | единый append-only JSONL-журнал | `sh_05_grm_audit.lua` |
| `GRM.UI` | singleton lifecycle окон | `sh_00_grm_ui.lua` |
| `GRM.Identity` | AccountKey/CharacterKey | `sh_grm_identity.lua` |
| `GRM.Perf` | event-реестры entity, throttle, change-only NW | `sh_06_grm_performance.lua` |

Неподвижные правила (полностью — в `ARCHITECTURE.md`):
- RP-состояние принадлежит **персонажу** (`SteamID64:charN`), а не аккаунту.
- Клиент отправляет намерение, а не результат — сервер повторно проверяет.
- Каждый C→S receiver получает `GRM.Net.Guard`.
- JSON имеет версию; SID-ключи читаются через `util.JSONToTable(raw, false, true)`.
- Повреждённый JSON не перезаписывается (карантин).
- Деньги меняются только через Economy/Ledger API.

## Модули (сводная таблица)

Полная таблица с «Код N» номерами — в `ARCHITECTURE.md`. Ключевые системы:

- **Фракции** (`sh_factions.lua`, `sh_faction_fixes.lua`) — создание организаций,
  должности, отделы/подотделы, казна, доступы по ролям, единый центр управления
  (Unified Factions UI, `/fmenu` `/фракция`), комендантский час `/kom_hour`,
  маскировка V2, `/gnews`.
- **Экономика** (`sh_grm_economy.lua`, `sh_grm_currency.lua`) — банки, банкоматы,
  терминалы, бюджеты/налоги/зарплаты фракций, инкассация, документы.
- **Розыск и штрафы** (`sh_grm_wanted_*.lua`) — каталог статей, вменение нарушений,
  ориентировки, обмен сведениями.
- **Службы** — логистика, биржа труда (`sh_grm_jobs*.lua`), телефон, служебные компьютеры.
- **Спецслужбы** — маскировка, прослушка (RoomTap), CCTV, комендантский час.
- **Пожарная служба** (`sh_grm_fire*.lua` + `addons/grm_fire/`) — очаги, тушение, рукава, насосы.
- **911** (`sh_grm_911.lua`) — ранения, реанимация, морг, вызовы.
- **Двери/недвижимость** (`sh_grm_doors.lua`, `sh_grm_property.lua`) — Master-Slave
  связка, ордера, аренда/покупка.

## Основные команды

**Игрок:** `/inv`, `/store`, `/fjoin`, `/fleave`, `/fr`, `/dep`, `/depb`, `/mask`,
`/model`, `/gnews`, `/kom_hour`, `/logistics_start`, `/logistics_crates`,
`!fbudget`, `!fpay`, `!fwithdraw`, `!fpayall`, `!fsettax`, `/mysalary`,
`/fine <сумма> [причина]`, `/vlist`, `/myvehicles`, `/vshop`, `/phoneshop`, `/duty`.

**Лидер фракции:** `/vaccess`.

**Админ:** `/factions`, `/fmenu`, `/door_access`, `/door`, `/warrant`, `/salary_admin`,
`/logistics_admin`, `/models_admin`, `/weapons_admin`, `/mask_admin`,
`!grmmenu`/`!grmadmin`/`!econadmin`, `/grm_access` `/доступы`, `/faction_perms`.

Полный список — `ARCHITECTURE.md` § «Команды».

## Файлы данных (garrysmod/data)

`factions.json`, `invites.json`, `factions_extended.json`, `fw_faction_extras.json`,
`default_models.json`, `default_weapons.json`, `grm_inventories.json`,
`grm_economy.json`, `gnews_log.txt`, `grm_logistics/…`, `grm_factory_fullcycle/…`,
`grm_admin_log.json`, `grm_currency.json`, `spawn_points_*.json`,
`grm_vehicle_purchases.json`, `grm_phone/…`, `grm_faction_perms.json`,
`grm_faction_duty.json`, `grm_fire/log.json` и др.

Полный список — `ARCHITECTURE.md` § «Файлы данных».

## Внешние зависимости

- **ArcCW** — оружие.
- **simfphys / LVS** — матовозки и транспорт.
- **ULX/ULib** — опционально.
- **vFire** — пожарная механика (файлы уже внутри `addons/grm_fire/`).
