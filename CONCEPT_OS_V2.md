# GRM OS 2.0 — компьютеры, электроника, фоторобот и печать

**Дата:** 2026-08-14 · **Код 59** · **Статус:** концепт, код пока v1.5.1  
**Связь:** `sh_grm_electronics.lua` + `cl_grm_electronics.lua` + `grm_net_*` entities + `sh_grm_documents.lua` + `sv_grm_comp_terminal.lua`

## 1. Что есть (v1.5.1)

- OS `GRM NET OS` — DFrame 1060×720, боковое меню, приложения: Интернет, Соцсети, Чаты, Почта, Файлы, Калькулятор, Заметки, Редактор, Графика, Фоторобот, Модули, Wi-Fi, Печать. OS Type: civilian/service/personal/business/lawenforcement (фильтр приложений).
- Файловое хранилище per-device: `data/grm_electronics/database.json` версия 2, `E.Files[deviceID][fileID] = {id,name,owner,content,imagePath,category}`. Категории: doc/note/photo/photo_print/drawing. Автосейв dirty 5с.
- Печать: `GRM_Net_Action op=print id=fileID printerID paperSize orientation copies quality` → сервер ищет `imgFile = content:match("%[ИЗОБРАЖЕНИЕ: (.-)%]")` → спавнит `grm_net_document` x копии с `SetDocumentImage(imgFile)`, звук принтера.
- Фоторобот:
  - `photoGallery()` — DListView фото из `current.files` категории photo/photo_print.
  - `photoEditor()` — canvas 400×520 procedurally рисует части лица (faceParts 6/8/6/5/5/6/4/8), цвета кожи/волос/глаз, эффекты bw/sepia/vintage/grain/highcontrast, vignette, подпись. Контролы справа: циклы частей, цвет, эффект, описание.
  - Сохранение: `render.Capture {format="jpeg", quality=95, x,y,w,h}` из `canvas:LocalToScreen()` → `file.Write("grm_photos/photorobot_*.jpg")` + net `image_save name/photo bytes`. Принт — то же но категория photo_print.
  - Просмотр: `GRM_Net_Document` viewer — DImage `../data/` + DHTML `file://`.
  - Проблемы: захват VGUI через screen region ненадёжен (перекрытие окон, HDR, net лимит 64Кб, JPEG 95% тяжёлый), печать фоторобота делает ещё один `image_save` вместо `print`, DHTML `file://` не работает на многих клиентах, нет импорта любых фото, нет связи с документами/розыском.

## 2. Цели OS 2.0

1. **Стабильный захват фоторобота** — RT-рендер без зависимости от экрана, JPEG 80%, ≤150Кб, гарантированный `imagePath`.
2. **Универсальная печать** — любой файл категории photo/drawing/doc может печататься на `grm_net_printer` через единый flow: `file_save → fileID → print`. Принтер доступен только online.
3. **Любые фотки** — (a) загрузка из `data/` (игрок кидает jpg в `garrysmod/data/grm_import/`), (b) графический редактор уже есть, (c) скриншот игрока (F12) через `jpeg` capture всей сцены (без UI) по кнопке.
4. **Связь с доками и розыском:**
   - Фото из галереи можно вставить в паспорт/ксиву как аватар (замена Steam Avatar).
   - Фото можно прикрепить к делу розыска в терминале полиции/жандармерии — новая вкладка «Фотороботы».
5. **UI:** оконный менеджер минимальный (drag, close, minimize в трей), файловый менеджер с превью, фильтр по категории, контекстное меню ПКМ → Печать/Удалить/Поделиться/Открыть.
6. **Безопасность:** rate-limit 0.5с на `image_save`/`print`, max 200Кб на картинку, проверка `IsOnline(printer)`, `UseRange 200`, OS Type фильтр.

## 3. Формат данных (не ломаем старый)

Оставляем `E.Files[deviceID]` массив. Новое поле:
```lua
{
  id="file_...",
  name="Фоторобот_...",
  owner="login",
  category="photo", -- photo | photo_print | drawing | doc | note
  content="[ИЗОБРАЖЕНИЕ: grm_computer/images/xxx.jpg]",
  imagePath="grm_computer/images/xxx.jpg",
  imageBytes=12345,
  thumbPath="grm_computer/thumbs/xxx.jpg", -- новое, 128x128
  source="photorobot", -- photorobot | import | drawing | screenshot
  created, updated
}
```
`grm_computer/images/` и `grm_computer/thumbs/` в `data/`. `grm_photos/` оставляем legacy, новый путь единый.

## 4. Фоторобот 2.0 — детали реализации

### Canvas рендер через RT (надёжно)

Вместо `render.Capture` экрана делаем off-screen RT:

```
local w,h = canvas:GetSize()
local rtName = "GRM_PhotoRT_" .. SysTime()
local rt = GetRenderTarget(rtName, w, h)
render.PushRenderTarget(rt)
  render.Clear(0,0,0,0)
  cam.Start2D()
    -- рисуем тот же Paint код canvas вручную через функцию DrawPhotorobot(cx,cy,s,state,colors)
  cam.End2D()
render.PopRenderTarget()
local data = render.Capture({format="jpeg", quality=80, x=0,y=0,w=w,h=h})
```

Так захват не зависит от перекрытия окон и HDR.

### Сохранение

1. Клиент: RT → JPEG bytes → `net.Start("GRM_Net_Action") op=image_save name="Фоторобот_..." category="photo" bytes`.
2. Сервер уже есть: пишет `data/grm_computer/images/` + создаёт File record + `SaveDB()` + ответ с `files`.
3. Клиент: `net.Receive GRM_Net_Result` с `payload.files` → обновляет `photoGallery()`.

### Импорт любых фоток

- Кнопка «ИМПОРТ» в галерее: `file.Find("grm_import/*.jpg", "DATA")` список, DComboBox, превью DImage `data/grm_import/...`, кнопка «ИМПОРТИРОВАТЬ» → читает файл `file.Read(path, "DATA")` → `image_save` категория `photo` source=`import`.
- Графический редактор уже есть — его сохранение уже в `drawing`, теперь его Print тоже через универсальный flow.

### Печать

- В галерее и файл-менеджере: список принтеров online `E.Topology.devices kind=printer online`. DComboBox выбор принтера + paper A4/A5 + copies.
- Кнопка «ПЕЧАТЬ» → `send(ent,"print", func() WriteString fileID, printerID, paper, orient, copies, quality end)`. Сервер спавнит `grm_net_document` как раньше, но теперь `SetDocumentImage` гарантировано есть.
- Принтер entity `grm_net_printer` уже с моделью и `Use` → `OpenDevice`.

## 5. Документы + фоторобот

- В `grm_doc_computer` добавить чекбокс «Использовать фото из фоторобота» — при оформлении паспорта/ксивы `doc_issue` принимает `photoFileID` вместо Steam avatar. Сервер копирует `imagePath` в `doc.data.photoPath`.
- Рендер документов: вместо `AvatarImage:SetSteamID` если есть `photoPath` → `DImage` с `Material("data/" .. photoPath)`.
- Валидация: только владелец файла может использовать своё фото.

## 6. Полиция + фоторобот

- В `grm_comp_police` / `military_police` / `security` добавить вкладку «Фотороботы» (клиент): список файлов категории photo с фильтром, кнопка «Прикрепить к делу» → `GRM_CompTerminal_Send("attach_photo", targetKey, "", 0, fileID)` — новый action.
- Сервер: `sh_grm_special_service.lua` / `sv_grm_comp_terminal.lua` хранит `record.photo = fileID` в `Wanted.Records[charKey].photo` или в `Special.json` case.

## 7. Сеть и безопасность

- `GRM_Net_Action` уже rate-limit 0.15с, добавим 0.5с для `image_save`/`print`.
- `image_save`: max 200KB, только jpg/png header check (`0xFF 0xD8` или `0x89 PNG`), имя sanitize 96 символов.
- `print`: проверка `IsOnline(printer)`, `printer:GetDeviceKind()=="printer"`, дистанция 300, копии clamp 1..5, UseRange.
- OS Type: `civilian` — нет фоторобота, `lawenforcement` — фоторобот + модули, `personal/service` — фоторобот есть. Фильтр в `homePage()` уже реализован через `allowedApps`.

## 8. UI/UX OS 2.0

- Окно 1120×700, левая навигация 190 + контент 900, как раньше, но добавить трей внизу для минимизированных окон (пока заглушка).
- Файловый менеджер: слева DListView с иконка по категории (ICONS.Photo/Files/Note), справа превью: если photo → DImage thumb 200×200 + инфо (owner/date/size/source), если doc → DTextEntry preview 500 символов.
- Контекстное меню ПКМ по файлу: Открыть / Печать… / Поделиться / Удалить / Копировать путь.
- Галерея фоторобота: сверху фильтры Все / Мои / Печати / Импорт, снизу DIconLayout с thumb (если есть) или иконка, клик — выбор.
- Принтер-панель: визуальный preview бумаги (A4 книжная/альбом), как уже есть, но добавить ориентация иконкой.

## 9. Тесты

- `sim_os_photorobot.lua` (LuaJIT):
  - file record creation: category photo, imagePath exists, thumbPath generation (если реализуем).
  - print: printer online check, doc entity spawns, imagePath copied.
  - OS Type filter: civilian не видит фоторобот, lawenforcement видит.
  - import: file.Find("grm_import/*.jpg") → image_save → file exists.
  - rate-limit: вторая загрузка <0.5с отклоняется.

## 10. Этапы

1. CONCEPT_OS_V2.md (этот файл) — готово.
2. Клиент: RT-рендер фоторобота, унификация Save/Print, галерея + импорт.
3. Сервер: лимит 200KB, thumb (опц.), новый action attach_photo.
4. Документы: photoPath в документах, рендер DImage вместо AvatarImage.
5. Компьютеры полиции: вкладка Фотороботы.
6. Тесты + `build_dist.py` + README + ANALYSIS.

Объём: ~400 строк клиент + ~100 сервер, без ломки API.
