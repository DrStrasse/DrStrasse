# HANDOVER — памятка для следующей сессии агента (и для владельца)

Если ты — новая сессия Arena-агента в этом репозитории: **не работай от master** —
он почти пустой (снапшот пра-истории). Вся актуальная база в ветке:

```
git fetch origin arena/019f69c8-drstrasse
git reset --hard FETCH_HEAD   # в своей рабочей ветке сессии
```

После этого прочитай `README.md` (147 lua / Коды 1–59 (см. README), таблица) и `ANALYSIS.md`
(находки 1–67 — там вся история боли и уроки, НЕ повторяй старые ошибки).

## Где что лежит
- `lua/` — весь код (147 lua / Коды 1–59 (см. README); см. таблицу в README).
- Ключевые: Код 42 `lua/autorun/sh_grm_currency.lua` (валюта **v2.0.2**),
  Код 43 `lua/autorun/sh_grm_economy.lua` (экономика **v3.0.2**, банк,
  зеркало `grm_bank_nicks.json` с полем `electro_balance`),
  Код 50 `lua/autorun/sh_grm_perm_entities.lua` (пермы энтити **v1.1.0**).
- Из dop.addons (16.07.2026): Коды **51–59** — ctx, encumbrance, food, handcuffs,
  mining, roomtap, sent_vehicle_dealer, vehicle keys, EasyChat. Дубли ядра
  (spawn/access/antistuck/inventory forks) **не** вливались. См. находку 68.
- Код **60** CCTV
- Код **61** Wanted:
- Код **62** RP-чат: `sh_grm_rp_chat.lua` (/me /do /it /try /roll…) `/wanted`, `/wanted_access`, data/grm_wanted/ (+ access `/cctv_access`): `sh_grm_cctv_config` / `sv_grm_cctv` / `cl_grm_cctv` +
  `grm_cctv_{camera,monitor,server}` (находка 69).
- `dist/` — готовые zip для владельца (grm_single_addon.zip = один аддон;
  grm_economy.zip; grm_fix_hud_tab_currency.zip; grm_full_code.zip).
  Владелец качает по raw-линкам на ветке — **ветку не удалять**.
- `tools/luatest/roundtrip_test.lua` — мок GMod API + 13 фаз юнит-теста
  персистентности (сохранение данные/денег/пермов). Обязателен к прогону
  после любой правки ядра.

## Правила работы (стоящие приказы владельца)
- Язык общения — русский; владелец тёрсьм — по делу.
- **Код не слать в чат** — только коммиты/архивы/ссылки + проза.
- После любой правки lua: luaparser-валидация + порядковый линт
  локальных функций + прогон стенда + пересборка ВСЕХ 4 zip +
  обновить README (строка модуля) + ANALYSIS (новая находка) +
  **commit+push сразу же** (песочница откатывает файлы прямо посреди хода!).
- Следующий свободный номер модуля: **Код 63**.

## Грабли среды (выстрадано)
- `/tmp` стирается между ходами; `/home/user` вне репо откатывается;
  не существующий cwd в shell затыкает вызов молча.
- `lua.org` заблокирован; `codeload.github.com`, pypi, github работают.
- LuaJIT для стенда собирается с нуля:
  `mkdir -p .luabuild && cd .luabuild && curl -fsSL -o lj.tar.gz
  https://codeload.github.com/LuaJIT/LuaJIT/tar.gz/refs/heads/v2.1 &&
  tar xzf lj.tar.gz && mv LuaJIT-2.1 lj && cd lj && make -s`
  → бинарь `.luabuild/lj/src/luajit` (удалить `.luabuild` перед коммитом).
  Запуск фаз из КОРНЯ репо: `./.luabuild/lj/src/luajit
  tools/luatest/roundtrip_test.lua save` (далее load, sidkey_trap,
  bank_nick_mirror, bank_reconcile_attack, bank_boot_pick_fresh, perm,
  corrupt, corrupt_all, treasury_corrupt, fmt_array_sid/nick/mapnum).
- `pip install -q --break-system-packages luaparser` каждый ход (исчезает).
- При расхождении истории после отката: `git fetch origin <ветка> &&
  git reset --mixed FETCH_HEAD` — рабочее дерево сохраняется.

## Уроки кода (главные)
- **Никогда не парсить JSON для ключей-SteamID64 голым `util.JSONToTable`** —
  третий аргумент обязателен `(txt, false, true)`; иначе ключи калечатся
  (офиц. wiki; находка 65 — корневая причина многонедельной саги потерь).
- Там, где можно — хранить МАССИВАМИ записей, а не картами с числовыми ключами.
- Каждая запись на диск печатается с причиной (`SAVE ok ... [взнос на счёт]`),
  при загрузке — рентген содержимого (кто и сколько поднялся).
- В GMod `file.Write` возвращает nil: контроль записи — только read-back.

## Открытые нитки
- Финансовая сага ЗАКРЫТА владельцем (наличка и счёт переживают рестарт).
- Название внешнего «писателя» в `grm_wallet.json` (формат массива
  name/balance) так и не вскрыто — ныне безвреден (всеядный загрузчик +
  доминирование памяти). Если вдруг: искать RP/character-money аддоны и
  вопрос «второй сервер/синк data/ на хостинге».
- Из старых хотелок не сделано: энтити sent_vehicle_dealer, grm_item_drop,
  радио; SteamID64 владельца для белого списка econadmin так и не предоставлен.
