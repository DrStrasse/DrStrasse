# GRM Food & Hunger System

Версия без папок `lua/entities`: сущности регистрируются через `scripted_ents.Register`.

## Исправления в этой версии

- Исправлена выдача еды из автомата: теперь у хлеба/воды/газировки ставится именно модель из `FoodItems`, а не дефолтная модель яблока/апельсина.
- Исправлен двойной HUD сытости: новый HUD удаляет старый хук `GRM_Food_HUDPaint` из предыдущего архива.
- Добавлено перманентное сохранение торговых автоматов на карте для `superadmin` / ULX / ULib.

## Установка

1. Распакуйте архив.
2. Папку `grm_food` положите в:

```text
garrysmod/addons/
```

3. Перезапустите сервер или карту.

## Структура

```text
grm_food/
├── addon.txt
└── lua/
    └── autorun/
        ├── sh_grm_food_config.lua
        ├── client/
        │   ├── cl_grm_food_hud.lua
        │   └── cl_grm_vending_gui.lua
        └── server/
            └── sv_grm_food.lua
```

## Если HUD всё равно двоится

Проверьте, что в `garrysmod/addons/` не лежит старая папка первого архива:

```text
grm_food_system
```

Нужна только новая папка:

```text
grm_food
```

В этой версии старый HUD-хук автоматически удаляется, но лучше не держать одновременно две версии аддона.

## Спавн автомата

В игре:

```text
Q -> Entities -> GRM Food -> Торговый автомат
```

## Перманентное сохранение автоматов

Порядок работы:

1. Зайдите за `superadmin`.
2. Поставьте автоматы через Spawn Menu.
3. Расставьте их на карте.
4. Выполните команду сохранения.
5. После рестарта карты/сервера автоматы появятся автоматически.

### Чат-команды для superadmin

```text
!grmsavevending
!grmloadvending
!grmclearvending
```

Альтернативные варианты:

```text
!grm_vending_save
!grm_vending_load
!grm_vending_clear
```

### Консольные команды

```text
grm_vending_save
grm_vending_load
grm_vending_clear
```

### ULX-команды

Если установлен ULX/ULib, команды регистрируются в категории `GRM Food`:

```text
ulx grm_vending_save
ulx grm_vending_load
ulx grm_vending_clear
```

Доступ по умолчанию: `superadmin`.

## Где хранятся автоматы

Для каждой карты отдельный файл:

```text
garrysmod/data/grm_food/vending_<название_карты>.json
```

Например:

```text
garrysmod/data/grm_food/vending_rp_downtown_v4c_v2.json
```

## Экономика

Если на сервере есть функции:

```lua
GRM.HasMoney(ply, amount)
GRM.TakeMoney(ply, amount)
```

то автомат будет проверять и списывать деньги. Если их нет — товары будут бесплатными.

## Тестовая команда голода

Админ или серверная консоль:

```text
grm_food_set <ник/SteamID64> <значение>
```

Пример:

```text
grm_food_set Player 100
```
