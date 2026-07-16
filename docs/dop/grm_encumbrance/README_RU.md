# GRM Encumbrance — вес, инвентарь и движение

Система подключается поверх существующих GRM Movement, GRM Inventory и GRM HUD, не заменяя их целиком.

## Установка

Скопируйте папку `grm_encumbrance` в:

```text
garrysmod/addons/grm_encumbrance/
```

После рестарта сервер сам найдёт `GRM.Inventory` и подключит контроль веса к `AddItem` и `AddWeapon`.

## Механика по умолчанию

- Нормальный максимум: **50 кг**.
- С 25 кг начинается плавное замедление.
- На 50 кг бег больше не ускоряет игрока.
- На 62.5 кг нельзя поднять новые предметы и оружие.
- Учитываются:
  - все предметы и оружие, лежащие в GRM Inventory;
  - всё экипированное оружие;
  - реальные боеприпасы игрока после использования ammo-предметов.

Вес предмета берётся из `ItemDefs[itemID].weight`. Если он не задан, используется таблица `ItemWeights`.

## HUD и инвентарь

- В HUD появляется полоса веса над статусом движения/выносливостью.
- При `/inv` открывается отдельная компактная панель с разбивкой:
  - инвентарь;
  - оружие;
  - боеприпасы;
  - процент скорости.
- Панель также открывается командой:

```text
grm_weight
```

## Настройка

Все лимиты, веса ресурсов, боеприпасов, оружия и class-rule находятся в:

```text
lua/autorun/sh_grm_encumbrance_config.lua
```

## Дополнительная интеграция со стаминой

Скорость и запрет подбора уже работают без изменения старого Movement System.

Чтобы вес также сильнее расходовал и медленнее восстанавливал стамину, в старом файле движения замените строки:

```lua
data.stamina = math.max(0, data.stamina - GRM.Movement.Config.StaminaDrain * 0.1)
```

на:

```lua
local drainMul = GRM.Encumbrance and GRM.Encumbrance.GetStaminaDrainMultiplier
    and GRM.Encumbrance.GetStaminaDrainMultiplier(ply) or 1

data.stamina = math.max(0, data.stamina - GRM.Movement.Config.StaminaDrain * drainMul * 0.1)
```

И строку:

```lua
data.stamina = math.min(GRM.Movement.Config.StaminaMax, data.stamina + GRM.Movement.Config.StaminaRegen * 0.1)
```

на:

```lua
local regenMul = GRM.Encumbrance and GRM.Encumbrance.GetStaminaRegenMultiplier
    and GRM.Encumbrance.GetStaminaRegenMultiplier(ply) or 1

data.stamina = math.min(GRM.Movement.Config.StaminaMax, data.stamina + GRM.Movement.Config.StaminaRegen * regenMul * 0.1)
```
