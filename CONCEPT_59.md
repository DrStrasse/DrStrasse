# CONCEPT_59 — сводный концепт оставшихся работ заказа «лицензии / документы / компьютеры / фоторобот»

**Дата:** 2026-08-15 · **Код 59/60** · **Статус:** концепт (сводка сделанного + план остатка)
**База:** ветка `arena/01a00565-drstrasse`, HEAD `b44d5d1` («licenses: v2 сроки, баллы, приостановка…» = Код 60 часть 1, находка 128)

> Этот файл — единая карта того, что уже сделано и что осталось. Он НЕ дублирует
> `CONCEPT_OS_V2.md` и `CONCEPT_LICENSES_V2.md`, а сверяет их с фактическим кодом
> (находки 127/128 уже реализованы) и фиксирует незакрытые хвосты.

---

## 0. Итог одним абзацем

Ядро заказа выполнено: **OS 2.0** (RT-фоторобот + универсальная печать + импорт фото)
и **лицензии v2** (сроки, баллы 0–12, приостановка, проверка при посадке, команды) —
это находки **127** и **128** (код уже в ветке). Остались три блока: **A) лицензии v2
хвост** (госпошлина + экзамены + начисление баллов из нарушений), **B) документы v2
хвост** (пикер фото из фоторобота, watermark/QR, реестр утерь/краж), **C) OS хвост**
(оконный/файл-менеджер, фоторобот-вкладка в `grm_comp_security`, thumbnails).

---

## 1. Что уже сделано (сверено с кодом, не трогать без причины)

| Блок | Что сделано | Где |
|---|---|---|
| OS 2.0 (Код 59) | RT-захват фоторобота (`render.PushRenderTarget` → JPEG 80% 400×520 ≤150Кб), универсальная печать через `print` op (дедуп, copies clamp 1..5, дистанция 350), импорт из `data/grm_import/*.jpg|png`, галерея v2 (категории photo/photo_print/drawing/import, принтер-комбо + бумага + ориентация + копии), просмотр `Material("data/...")` вместо DHTML `file://` | `lua/autorun/sh_grm_electronics.lua` v2.0.0, `lua/autorun/client/cl_grm_electronics.lua` v2.0.0, находка 127 |
| **Фоторобот v2.0.0 — переписан в отдельный модуль** | Полная переработка (находка 129): модуль `GRM.Photorobot` (`cl_grm_photorobot.lua`) — свои правила отрисовки (слои-примитивы + роли палитры, детерминированный шум), свой формат `GRMFACE/1` (текстовый, контрольная сумма FNV-1a) → переоткрытие/доредактирование/перепечатка 1:1, захват RT до PopRenderTarget; серверный op `photorobot_save` + `grm`/`desc`/`imagePath` в file_open/filesFor | `cl_grm_photorobot.lua`, `sh_grm_electronics.lua` v2.1.0, `cl_grm_electronics.lua` v2.1.0 |
| Лицензии v2 (Код 60 ч.1) | expiry (10л civ / 5л mil), points 0..12 / maxPoints, статусы Действителен/Истёк/Приостановлен/Лишён/Аннулирован, `PlayerEnteredVehicle` проверяет категорию+статус+expiry+suspendedUntil+points, `DOC.AddLicensePoints`, `GetLicensePoints`, `IsLicenseExpired`, команды `/license_points` `/points` `/баллы` `/моибаллы`, `/license_check` `/check_license` `/проверить_права` | `lua/autorun/sh_grm_documents.lua` v2.0.0, находка 128 |
| Документы: фото | поле `photoPath` в данных документа, рендер фото (с фолбэком на Steam `AvatarImage`), ручной ввод пути фото при оформлении в паспорте/ксиве | `sh_grm_documents.lua` (строки ~1655/1814/1958), `lua/entities/grm_doc_computer/cl_init.lua` (~185/223/408) |
| Полиция + фото | вкладка/поле «Фоторобот (путь data/)» + `attach_photo` в `grm_comp_police` и `grm_comp_military_police`; серверный обработчик `attach_photo` | `lua/entities/grm_comp_police/cl_init.lua` (~181), `grm_comp_military_police/cl_init.lua` (~175), `lua/autorun/server/sv_grm_comp_terminal.lua:516` |

**Вывод:** повторно делать 127/128 не нужно. Работаем только с незакрытыми хвостами ниже.

---

## 2. Блок A — Лицензии v2, хвост

По `CONCEPT_LICENSES_V2.md` §2 (цели 4–5) не реализованы:

1. **Госпошлина.** Выдача/перевыпуск через `GRM.Services.Charge` (банк/счёт/наличные, 80% в бюджет фракции-автошколы, 20% в казну). Сейчас выдача бесплатна.
2. **Экзамен — теория.** В `grm_comp_traffic` и `grm_doc_computer` вкладка «Экзамен»: 10 вопросов из пула (json), проход ≥80%. Хранение `data/grm_driving_exams.json = { [charKey] = { theory={passed,date,score}, practice={passed} } }`.
3. **Экзамен — практика.** Чекпоинты 3–5 точек на карте, лимит времени, без ДТП; команда `/drive_exam`. Можно начать с заглушки (SuperAdmin-отметка), потом реальные чекпоинты.
4. **Начисление баллов из нарушений.** `DOC.AddLicensePoints` есть, но нет точки входа из штрафов/ДТП: хук `GRM_LicenseAddPoints(ply, points, reason)` из `/fine` (категория ПДД) и из ДТП. Сейчас баллы можно добавить только вручную.
5. **Гейт выдачи.** `DOC.CanIssueLicenses` должен дополнительно требовать `examPassed[charKey]` (кроме SuperAdmin-bypass).

**Файлы:** `lua/autorun/sh_grm_documents.lua`, `lua/entities/grm_comp_traffic/`, `lua/entities/grm_doc_computer/`, `lua/autorun/sh_grm_services.lua` (Charge — только вызов), `lua/autorun/sh_grm_wanted_fines.lua` (точка входа баллов из штрафа — аккуратно, не ломать саму логику штрафов).

---

## 3. Блок B — Документы v2, хвост

По `CHECKPOINT.md` §59.2 и `CONCEPT_OS_V2.md` §5:

1. **Пикер фото из фоторобота.** Сейчас в `grm_doc_computer` фото задаётся ручным путём. Нужен выбор из галереи OS (категория photo) вместо ручного ввода: при оформлении паспорта/ксивы `doc_issue` принимает `photoFileID`/`imagePath`, сервер копирует путь в `doc.data.photoPath`. Валидация: только владелец файла может использовать своё фото.
2. **Watermark/QR для проверки подлинности.** На документ — водяной знак государства + QR/код (например, `number + fullName + issuedBy`), проверка через терминал (сканирование → сверка с реестром).
3. **Реестр утерь/краж.** Таблица `data/grm_documents/lost.json` (массив записей), пометка документа «Утерян/Похищен», при проверке документа терминалом — флаг в досье, перевыпуск с аннулированием старого номера.

**Файлы:** `lua/entities/grm_doc_computer/`, `sh_grm_documents.lua`, `cl_grm_electronics.lua` (только переиспользование галереи/путей), новый `sim_documents_v2.lua`.

---

## 4. Блок C — Компьютеры / Электроника v2.0, хвост

По `CHECKPOINT.md` §59.3 и `CONCEPT_OS_V2.md` §5–8:

1. **Оконный менеджер (минимальный).** drag + minimize в трей + restore. Сейчас окна фиксированные. Объём ~80–120 строк клиента, без ломки существующих приложений.
2. **Файл-менеджер с превью.** DListView (иконка по категории) + превью: photo → thumb/DImage 200×200 + инфо (owner/date/size/source), doc → превью первых ~500 символов. Thumbnails (`thumbPath` 128×128) — опционально, можно начать с полного DImage.
3. **Фоторобот-вкладка в `grm_comp_security`.** В police/military_police уже есть; в security — нет. Скопировать тот же блок (поле пути + `attach_photo`), не дублируя логику — вынести общий код.
4. **Интеграция OS-типов** — в основном уже есть (`lawenforcement` видит фоторобот+модули, `civilian` нет). Проверить только фильтр и, при необходимости, доуточнить.

**Файлы:** `lua/autorun/client/cl_grm_electronics.lua`, `lua/entities/grm_comp_security/cl_init.lua` (+ при желании общий модуль для фото-блока), `sv_grm_comp_terminal.lua` (attach_photo уже есть — не дублировать).

---

## 5. Тех-долг перед/во время работ (из CHECKPOINT §11)

- Убрать дубль фото-логики в `cl_grm_electronics.lua` (два пути сохранения photo / photo_print) — унифицировать на единый `image_save` + категория.
- `file.Exists` + `../data/` для DImage — где можно, заменить на `Material("data/...")` (уже частично сделано в 127).
- Проверить наличие `PERM_CLASSES` для `grm_net_printer` / `grm_net_computer` (не добавлять, если уже есть).

---

## 6. Форматы данных и API (не ломать)

- `DOC.Registry.licenses[charKey]` / `milLicenses[charKey]` — формат v2 из `CONCEPT_LICENSES_V2.md` §3 (expiry/points/status/suspendedUntil/photoPath). Миграция старых записей уже реализована.
- `E.Files[deviceID][fileID] = {id,name,owner,content,imagePath,category,...}` — версия 2, категории doc/note/photo/photo_print/drawing/import.
- `GRM_Net_Action` op=`image_save` / `print` — rate-limit, размер ≤200Кб, header-проверка jpg/png, copies 1..5 (уже есть в 127).
- `GRM.Services.Charge` — вызываем, не переписываем.
- JSON: `util.JSONToTable(txt, false, true)` (SteamID64-ключи), массивы вместо карт с числовыми ключами, карантин + read-back при записи (урок находки 65).

---

## 7. Тесты

- `tools/luatest/sim_licenses_v2.lua`: expiry<now → expired; +баллы до 12 → Приостановлен; категория B не проходит ТС категории C; госпошлина списывается при выдаче; экзамен гейтит выдачу.
- `tools/luatest/sim_documents_v2.lua`: photoPath сохраняется и рендерится; пикер привязывает файл владельца; потерянный документ помечается в реестре.
- `tools/luatest/sim_os_photorobot.lua`: file record (category photo, imagePath есть), print спавнит `grm_net_document` с imagePath, фильтр OS Type (civilian не видит фоторобот), импорт из `grm_import/*.jpg`, rate-limit <0.5с отклоняется.
- После любой правки lua — прогон `roundtrip_test.lua` (если затронуто ядро персистентности) + пересборка `python3 tools/build_dist.py` + README + ANALYSIS + commit+push.

---

## 8. Рекомендуемый порядок

1. **A (лицензии хвост)** — самый самодостаточный блок, закрывает пользовательский заказ «экзамен/пошлина».
2. **B (документы хвост)** — опирается на готовый photoPath и OS-галерею.
3. **C (OS хвост)** — UI-работа, наименее критичная для геймплея, можно частями.

Каждый блок — отдельным коммитом (концепт-правка → код → стенды → zip → README/ANALYSIS → push).

---

## 9. Ограничения этой сессии

- Работаем на `arena/01a00565-drstrasse` от `b44d5d1`. **Не** переключаться и **не** пушить в другие ветки.
- Стабильная копия `arena/01a0041b-drstrasse` (`stable/2a351e6-most-stable/`, коммиты `2a351e6`/`dcb3f8c`/`811859f`) — **неприкосновенна**; 13 коммитов persistence-фиксов из неё в эту ветку не переносим (осознанный выбор владельца).
- Не трогать без прямой просьбы: `sh_factions.lua`, логика HOLD-Q в `sh_grm_qmenu.lua`, FFD/keypad, двери v3, принтер/пресс, валюта/экономика/банк, ветки E2.
