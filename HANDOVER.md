# HANDOVER — актуальная передача проекта GRM

**Дата:** 2026-08-15
**Рабочая ветка:** `arena/01a0041b-drstrasse`
**База этой ветки:** `b44d5d1` + комплексная доработка Код 61 / Fire 1.5 / Documents 2.1 / Perm 1.6.

Master — старый неполный снапшот. В новых Arena-сессиях всегда работать только
на закреплённой системой ветке, не копировать старые команды переключения веток
из истории `CHECKPOINT.md`.

## Что изменено последним пакетом

0. **Код 62 — Persistence Guard**
   - `sh_01_grm_persistence_guard.lua` делает ранний снимок DATA до загрузчиков;
   - primary остаётся главным, boot/backup используется при пустом/битом primary;
   - при ошибке загрузки autosave блокируется, живые entity/память не удаляются;
   - `grm_persistence_audit` печатает boot-файлы, байты, valid и score;
   - Hub `perm` теперь вызывает `GRM.Perm`, а не saver рудных узлов.
1. **Код 61 — собственные инструменты GRM**
   - `sh_grm_build_tools.lua`;
   - `grm_camera`, `grm_light`, `grm_lamp`, `grm_material`, `grm_colour`;
   - stock `camera/light/lamp/material/colour/color` закрыты жёстко, включая SuperAdmin;
   - QMenu v4.2.0 показывает только GRM-варианты и их ручные схемы.
2. **Пожары v1.5.0 / addon 0.6.1**
   - струя без живого vFire не создаёт инцидент;
   - быстрый очаг даёт только «потушен»; локализованный — строго до потушенного;
   - одно уведомление на получателя, без двойного Notify+ChatPrint;
   - гидрант и пожарное оборудование fireproof;
   - линия гидрант↔насос сматывается при расстоянии > MaxLength+96 в течение 0.75с.
3. **Документы v2.1.0 / лицензии**
   - expiry/points/status задаёт сервер, миграция сохраняется сразу;
   - истёкшая приостановка восстанавливает права и сбрасывает баллы;
   - выдача/отзыв только у реально открытого терминала в радиусе 260;
   - реестры в служебные ПК идут online-срезом;
   - компьютер документов больше не пускает любую фракцию.
4. **Perm v1.6.0**
   - `/permadd` и тул работают через один `GRM.Perm` API;
   - сохраняются material/color/render/skin/bodygroups и модульные данные;
   - UID выдерживает сдвиг объекта; `/permload` привязывает уже стоящий объект;
   - `gmod_light`, `gmod_lamp`, `gmod_cameraprop` поддерживаются;
   - временный `grm_logistics_crate` запрещён.
5. `tools/build_dist.py` собирает пять архивов, включая fire overlay поверх `vFire PACK.zip`.

## Обязательные проверки после Lua-правок

```text
GLua syntax: все lua/ + addons/grm_fire/lua
все tools/luatest/sim_*.lua
roundtrip_test.lua: 16 фаз
python3 tools/build_dist.py
unzip -t dist/*.zip
```

Контрольная цифра на этой точке: **491/491 syntax, 77/77 sim, 16/16 roundtrip**.

## Архитектурные законы

- RP-состояние хранить по `GRM.Identity.CharacterKey` (`SteamID64:charN`).
  Чистый SteamID64 допустим только для аккаунтных прав и аудита.
- JSON с ключами SteamID64 читать только через
  `util.JSONToTable(text, false, true)`; предпочтительнее массивы записей.
- `file.Write` в GMod не возвращает success — проверка только read-back.
- Порядок `autorun` значим: `sh_00_*` раньше, `zz_*` позже.
- Глобальные UI-точки расширения фракций не локализовать без аудита зависимостей.
- Не добавлять в общий Perm классы с собственным сохранением (CCTV, vendor,
  vehicle dealer, автоперсистентная радио/сетевая инфраструктура).
- Бортовой пожарный насос/лестница — не perm; hose/hose_node — временные.
- Не вызывать `SweepOrphanGear` при удалении одной машины.

## Доставка

- `dist/grm_single_addon.zip` — основной аддон с префиксом `grm/`;
- `dist/grm_full_code.zip` — основной аддон без префикса;
- `dist/grm_economy.zip` — финансово-документный срез;
- `dist/grm_fix_hud_tab_currency.zip` — точечный финансовый фикс;
- `dist/grm_fire_addon.zip` — vFire + GRM fire overlay.

Для пожарной системы нужны одновременно `grm_single_addon.zip` и
`grm_fire_addon.zip`, затем полный рестарт сервера.
