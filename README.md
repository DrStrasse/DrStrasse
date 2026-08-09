# Wiremod E2 чипы (DrStrasse)

Чистая ветка для разработки чипов на **Expression 2** (Garry's Mod, Wiremod).
GRM-сборки здесь нет — она осталась в `master`.

## Структура

- `expression2/` — сами чипы (`.txt`). Установка в игру: скопировать файлы
  в `garrysmod/data/expression2/` — дальше они открываются прямо из
  E2-редактора в игре (Spawnlist → Wire → Expression 2).
- `docs/e2/E2_HANDBOOK_RU.md` — конспект по языку E2 на русском:
  директивы, типы, операторы, события, таймеры, ops-квоты, find/ranger/
  hologram/wirelink, рецепты и бест-практисы.
- `docs/e2/reference/` — официальная документация Wiremod (копия wiki
  github.com/wiremod/wire, включая автогенерируемый справочник функций
  `e2-docs-*.md`). Доступна офлайн, править руками не нужно.

## Соглашения

- Один чип = один файл `<имя>.txt` в `expression2/` (вложенные папки =
  папки в E2-редакторе).
- В каждом чипе: `@strict`, осмысленное `@name`, комментарии на русском.
- Современный стиль: `event` вместо `runOn*`, лямбда-таймеры `timer(sec, fn)`,
  `let/const` для локалок.
- Офлайн-справочник функций всегда сверять с `docs/e2/reference/e2-docs-*.md`.

## Окружение в игре

- Нужен аддон **Wiremod** (Workshop). Для propcore/effects/constraintcore —
  включить расширения: `wire_expression2_extension_enable propcore`,
  затем `wire_expression2_reload`.
- Полезные консольные команды: `wire_expression2_reload`,
  `wire_expression2_unlimited 0/1`, `wire_expression2_model <mdl>`.
