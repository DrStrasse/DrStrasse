# CMB-OS — единая операционная система Альянса

`combine_os.txt` — **единственный E2-чип** этой системы. В папке нет
mainframe-, terminal- или signal-node-чипов.

У файла намеренно **нет `@model`**: E2 не превращается в Combine-терминал,
не спавнит монитор и не создаёт датчики. В Garry’s Mod у E2 всё равно остаётся
стандартная физическая сущность — полностью «без тела» E2 движок создать не
может, — но CMB-OS не назначает ей никакой пользовательской модели.

Вместо этого ОС сама периодически находит уже поставленные prop по моделям:

| Роль | Модель |
|---|---|
| Терминал | `models/props_combine/combine_interface001.mdl` |
| Монитор | `models/props_combine/combine_intmonitor001.mdl` |
| Датчик пути | `models/hunter/blocks/cube025x025x025.mdl` |

Один чип даёт административную консоль, аккаунты/PIN, заметки, базовую
информацию об игроках, калькулятор, почтовые сообщения для 10 логических
терминалов, обнаружение внешних prop и управление сигналами/стрелками.

## Главное отличие: как «подключается» prop

Обычный prop не имеет Wire-портов, поэтому его нельзя подключить проводом к E2
как лампу или Text Entry. CMB-OS делает привязку командой `LINK`:

1. игрок смотрит на нужный внешний prop;
2. вводит команду через Text Entry;
3. ОС проверяет точную модель, запоминает позицию и связывает prop со слотом
   от 1 до 10;
4. после этого команды `SKIN` меняют skin prop между `0` и `1`.

Сканер моделей работает и без привязки: команды `SCAN` показывают обнаруженные
prop. Привязка нужна для устойчивого номера, управления skin, сообщений и
датчиков пути.

## Требования

Нужны E2-расширения:

- **EGP** — графический экран ОС;
- **Files** + **Serialization** — постоянные учётные записи, заметки,
  привязки и сообщения;
- **Find** — поиск существующих prop по модели;
- **Ranger** — контроль занятности над кубом-датчиком;
- стандартный Entity API Wiremod — `setSkin` / `getSkin`.

**PropCore и Remote не нужны:** ОС ничего не спавнит и не использует сеть из
нескольких E2.

## Установка и проводное подключение

Скопируй файл в:

```text
GarrysMod/garrysmod/data/expression2/combine_os/combine_os.txt
```

Поставь один E2 с этим файлом. Рядом отдельно расставь через обычный Prop Tool
модели Combine-терминала, Combine-монитора и кубы-датчики.

Подключи к единственному E2:

| Устройство | Вход CMB-OS |
|---|---|
| EGP Screen / Emitter wirelink | `Screen` |
| Wire Text Entry: `Text` | `Text` |
| Wire Text Entry: `User` | `TextUser` |
| Wire Text Entry: `Entered` | `Entered` |

EGP Screen можно физически поставить перед обычным prop-монитором
`combine_intmonitor001.mdl`. Сам E2 не становится этим монитором.

Игрок использует **E на Wire Text Entry**. Так `TextUser` передаёт сущность
именно того игрока, который ввёл команду.

### Первый запуск

Владелец E2 вводит:

```text
BOOTSTRAP <новый-PIN>
LOGIN root <PIN>
```

После этого можно заводить роли `ROOT`, `TECH`, `DISPATCH`, `GUEST`.

## Поиск, привязка и skin 0/1

Сначала можно проверить автоматическое обнаружение:

```text
SCAN TERM
SCAN MONITOR
SCAN SENSOR
SCAN LINKS
```

Затем смотри на конкретный prop и вводи, например:

```text
LINK TERM 1
LINK MONITOR 1
LINK SENSOR 1
```

Управление skin:

```text
SKIN TERM 1 1
SKIN TERM 1 0
SKIN TERM 1 TOGGLE

SKIN MONITOR 1 1
SKIN SENSOR 1 0
UNLINK TERM 1
```

`TECH` может связывать/отвязывать prop; `DISPATCH` управляет skin терминалов и
мониторов. Найденный prop автоматически повторно связывается после перезапуска
CMB-OS по сохранённой позиции, если он находится в пределах 72 units от старой
позиции.

> `prop_static` на карте может быть обнаружен Ranger как world geometry, но
> статичная геометрия карты обычно не является изменяемой сущностью. Skin 0/1
> можно менять только у валидного prop/entity, например поставленного игроком
> `prop_physics` или `prop_dynamic`. Кроме того, Entity API Wiremod разрешает
> `setSkin` только prop, принадлежащий владельцу CMB-OS (или доступный ему по
> правилам сервера/CPPI).

## Внешние датчики и железная дорога

Кубы `cube025x025x025.mdl` ставятся игроком заранее, затем связываются как
`LINK SENSOR <1..10>`. CMB-OS не создаёт их.

Для каждого связанного куба ОС запускает вертикальный hull-trace. Если над
датчиком находится prop, поезд, игрок, NPC или статичная геометрия карты,
участок считается занятым. Стандартная зона: 84 units вверх и 13 units по
сторонам; параметры есть в шапке чипа:

```golo
const SensorHeight = 84
const SensorHalfWidth = 13
```

Сигнальные выходы одного E2 статические, поэтому доступны десять каналов:

| Датчик | Лампы / свет | Стрелка |
|---|---|---|
| `LINK SENSOR 1` | `Red1`, `Yellow1`, `Green1` | `Switch1` |
| … | … | … |
| `LINK SENSOR 10` | `Red10`, `Yellow10`, `Green10` | `Switch10` |

Подключай `RedN` / `YellowN` / `GreenN` к соответствующим Wire Lamp или Wire
Light, а `SwitchN` — к своей схеме привода стрелки.

Автоматический режим: свой занятый блок — красный, следующий занятый блок —
жёлтый, иначе зелёный.

```text
SENSOR LIST
SIGNAL 1 AUTO
SIGNAL 1 RED
SIGNAL 1 YELLOW
SIGNAL 1 GREEN
SWITCH 1 LEFT
SWITCH 1 RIGHT
SWITCH 1 TOGGLE
```

## Команды ОС

### Сессия

```text
LOGIN <account> <PIN>
LOGOUT
WHOAMI
HELP
```

### Все вошедшие роли

```text
WHO
CALC <A> <+|-|*|/|%|^> <B>
NOTE LIST
NOTE READ <N>
MSG <slot|ALL> <text>
MAIL <slot>
```

`MSG` сохраняет сообщение в логическом слоте и ставит skin `1` у связанного
терминала/монитора как индикатор непрочитанного. `MAIL <slot>` показывает
сообщение и возвращает skin в `0`.

### DISPATCH и выше

```text
PLAYER <name>
NOTE ADD <text>
SKIN TERM|MONITOR|SENSOR <id> 0|1|TOGGLE
SIGNAL <id> AUTO|RED|YELLOW|GREEN
SWITCH <id> LEFT|RIGHT|TOGGLE
```

### TECH и выше

```text
NOTE DEL <N>
SCAN TERM|MONITOR|SENSOR|LINKS
LINK TERM|MONITOR|SENSOR <1..10>
UNLINK TERM|MONITOR|SENSOR <1..10>
SENSOR LIST
```

### Только ROOT

```text
USER LIST
USER ADD <login> <root|tech|dispatch|guest> <PIN>
USER DEL <login>
USER PASS <login> <new-PIN>
```

## Хранение и ограничения

- PIN хранится как SHA-256, а не открытым текстом; экран не выводит команду
  логина целиком. Это ролевая система, не защита от враждебного Lua/E2-кода.
- Files extension хранит базу `caos_unified_a01.json` в локальной
  data-директории владельца E2. Для восстановления после рестарта владелец
  должен быть подключён; это ограничение Wiremod Files.
- Одна CMB-OS = один интерактивный Text Entry и один EGP-интерфейс. Она может
  **контролировать до 10 внешних terminal/monitor prop**, но для десяти
  независимых интерактивных рабочих мест потребовались бы дополнительные
  Text Entry/Screen входы или отдельные клиентские E2 — это намеренно не
  создаётся в этом ТЗ.
- Для EGP надёжнее использовать латиницу в заметках и сообщениях: не каждый
  EGP-шрифт содержит кириллицу.
