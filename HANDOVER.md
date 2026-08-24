# HANDOVER — инструкция для следующей сессии

Читай первым. Затем `ARCHITECTURE.md` и `CHANGELOG.md`.

## Ветки

- Сессия Arena: **`arena/01a02d53-drstrasse`**. Не переключаться и не пушить другие ветки сессии.
- Чистая выкладка владельца: **`release/GRMRP`**. Обновлять через PR с рабочей ветки, не merge master.
- **Master не трогать.**

## Правила владельца

1. Русский, коротко. Код в чат не слать.
2. После Lua: синтаксис → `python3 tools/build_dist.py` → README/CHANGELOG → commit+push сразу.
3. `lua.zip` не распаковывать поверх `lua/`. `.luabuild/` не коммитить.
4. JSON: `util.JSONToTable(txt, false, true)`. CharacterKey = `SteamID64:charN`.
5. `until` в Lua занято → гости дверей: **`untilAt`**.
6. F4 соц.анимаций: только DBinder. C-меню без кнопок анимаций.
7. Атлас/мини не возвращать без запроса. Консоль ПК (TempleOS) не делать.
8. PAC3 / Z-City / LVS HP / Prone / Typography не копировать в `lua/`.
9. Грязные zip `grm_economy` / `grm_fix_hud_tab_currency` / `grm_textscreens` не коммитить.

## Сейчас в сборке (август 2026)

Топливо 1.2.3 (удаление колонки из json+перм), бак 100, зажигание R.
Прочность ТС = simfphys MaxHealth/CurHealth. Ключ `weapon_grm_wrench`.
Соц.анимации + студия с категориями. Квадратное меню. Биндер шаг АНИМ.

Архив: `dist/grm_single_addon.zip` на рабочей ветке. Ставить **целиком**.

## Открытые нитки

- Живой сервер со старым `sh_grm_navmap.lua` падает parse — только полный zip.
- Позы «руки вверх» править в студии под конкретную модель.
- Автопилот LVS не подтверждён.
- 303 двери без GRM-записей — не чистить без запроса.
