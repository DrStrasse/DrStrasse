# CMB-OS — инфраструктура Альянса и железной дороги

Новая самостоятельная система для Wiremod Expression 2. Она **не использует**
старый `rail_core` и не меняет его файлы.

CMB-OS состоит из трёх чипов:

| Файл | Роль | Модель E2 |
|---|---|---|
| `combine_mainframe.txt` | главный административный компьютер: учётные записи, заметки, игроки, терминалы, датчики, светофоры и стрелки | `models/props_combine/combine_interface001.mdl` |
| `combine_terminal.txt` | удалённый пользовательский терминал, до 10 ID в одной сети | `models/props_combine/combine_intmonitor001.mdl` |
| `combine_signal_node.txt` | безопасный локальный исполнитель одного светофора и одной стрелки | `models/props_combine/combine_interface001.mdl` |

Модели Combine дают устройствам внешний вид. **Сам по себе prop-монитор не
рисует интерфейс:** для экрана нужен подключённый **EGP Screen/Emitter**.
Его можно поставить/смонтировать перед `combine_intmonitor001.mdl`.

## Что умеет

- логин с аккаунтами `ROOT`, `TECH`, `DISPATCH`, `GUEST` и PIN;
- постоянные заметки, учётные записи, ручные аспекты и позиции датчиков;
- список базовой информации об онлайн-игроках: ник, команда, здоровье,
  броня, ping;
- калькулятор;
- переписка `MSG` между терминалами;
- heartbeat, список и блокировка до **10** терминалов;
- создание кубов-датчиков `models/hunter/blocks/cube025x025x025.mdl`;
- вертикальная проверка занятности каждого датчика;
- трёхзначные аспекты `RED / YELLOW / GREEN`, ручной override;
- управление стрелкой и fail-safe: при потере mainframe локальный узел даёт
  красный свет и сбрасывает стрелку в `LEFT`.

## Обязательные расширения

Нужны стандартные E2-модули **EGP**, **Remote**, **Ranger**, **Files**,
**Serialization** и включённый **PropCore**. Mainframe делает компайл-тайм
проверку и честно покажет ошибку, если чего-то нет.

Для PropCore серверу обычно требуется:

```text
wire_expression2_extension_enable propcore
wire_expression2_reload
```

Также сервер должен разрешать E2-файлы и `propSpawn`; лимиты
`sbox_E2_maxProps` / `sbox_E2_maxPropsPerSecond` должны позволять нужное
количество датчиков.

## Важное правило сети

Все три файла содержат в шапке:

```golo
const SystemID = "CAOS-A01"
```

Для одной сети строка должна быть одинаковой. Если нужно несколько независимых
сетей, поменяй `SystemID` **во всех трёх файлах** и у mainframe также поменяй
`StoreFile`, иначе несколько главных компьютеров будут делить одну базу заметок.

Все CMB-OS E2 одной сети следует ставить **одним владельцем**: remote-протокол
отфильтровывает чипы другого владельца.

## Установка

Скопируй файлы в:

```text
GarrysMod/garrysmod/data/expression2/combine_os/
```

### 1. Mainframe

Поставь `combine_mainframe.txt`. Рядом можно поставить визуальный
`combine_intmonitor001.mdl`; сам E2 выглядит как терминал
`combine_interface001.mdl`.

Подключи к mainframe:

| Источник / устройство | Вход mainframe |
|---|---|
| EGP Screen / Emitter wirelink | `Screen` |
| Wire Text Entry: `Text` | `Text` |
| Wire Text Entry: `User` | `TextUser` |
| Wire Text Entry: `Entered` | `Entered` |

Игрок вводит команды через **E на Wire Text Entry**, а не через E на E2.
Text Entry передаёт сущность этого игрока, поэтому сессия логина привязана к
реальному пользователю терминала.

При первом запуске владельцу нужно ввести:

```text
BOOTSTRAP <новый-PIN>
```

Это создаёт единственную исходную учётную запись `root`. Далее:

```text
LOGIN root <PIN>
```

База сохраняется в `caos_mainframe_a01.json` средствами Files extension.

### 2. Remote Terminal

Поставь `combine_terminal.txt` для каждой удалённой консоли.

| Источник / устройство | Вход / выход terminal |
|---|---|
| Wire Constant `1`…`10` | `TerminalID` |
| EGP Screen / Emitter wirelink | `Screen` |
| Wire Text Entry: `Text` | `Text` |
| Wire Text Entry: `User` | `TextUser` |
| Wire Text Entry: `Entered` | `Entered` |
| `BlockInput` | Wire Text Entry: `Block Input` (опционально) |

ID терминалов должны быть уникальны. Mainframe показывает, какие из десяти
терминалов живы. Команды `TERM LOCK` и `TERM UNLOCK` управляют входом Text
Entry удалённого терминала.

### 3. Signal Node

На каждый светофор/стрелку поставь `combine_signal_node.txt`.

| Подключение | Назначение |
|---|---|
| Wire Constant с номером пути | `SignalID` |
| `Red`, `Yellow`, `Green` | к Wire Lamp / Wire Light соответствующего цвета |
| `Switch` | один управляющий вход привода стрелки |
| `SwitchLeft`, `SwitchRight` | раздельные направления привода, если нужны |

Номер `SignalID` совпадает с номером датчика, созданного командой
`SENSOR ADD N`.

## Датчики пути

Залогиненный `TECH` или `ROOT` направляет взгляд на полотно и вводит:

```text
SENSOR ADD 1
```

Mainframe спавнит куб `cube025x025x025.mdl` в точке прицела, делает его
замороженным и несолидным, после чего регулярно сканирует вертикальный объём
над ним. Внутри зоны учитывается любое попадание Ranger: обычный prop,
`prop_dynamic`, игрок, NPC и статичная геометрия / `prop_static` как hit world.
Это соответствует модели «на датчике или сверху что-то есть».

По умолчанию зона — 84 units вверх и 13 units в стороны. Если над путём низкий
потолок, мост или декорация, они тоже будут считаться занятостью. В этом случае
настрой `SensorHeight` и `SensorHalfWidth` в шапке mainframe.

Команды:

```text
SENSOR LIST
SENSOR ADD <1..32>
SENSOR DEL <1..32>
```

Датчики, их координаты и ручные режимы переживают перезапуск mainframe: после
загрузки базы кубы создаются снова постепенно, с учётом PropCore-квоты.

## Команды ОС

Сначала войди:

```text
LOGIN <account> <PIN>
LOGOUT
WHOAMI
HELP
```

### Для всех ролей

```text
WHO
CALC <A> <+|-|*|/|%|^> <B>
NOTE LIST
NOTE READ <N>
MSG <terminal|ALL> <text>
TERM LIST
```

### DISPATCH и выше

```text
PLAYER <name>
NOTE ADD <text>
TERM PAGE <id> <text>
SIGNAL <id> AUTO|RED|YELLOW|GREEN
SWITCH <id> LEFT|RIGHT|TOGGLE
```

В automatic-режиме аспекты работают по последовательности номеров датчиков:
свой блок занят — `RED`; следующий занят — `YELLOW`; иначе — `GREEN`.

### TECH и выше

```text
NOTE DEL <N>
SENSOR LIST|ADD <id>|DEL <id>
TERM LOCK <id>
TERM UNLOCK <id>
```

### Только ROOT

```text
USER LIST
USER ADD <login> <root|tech|dispatch|guest> <PIN>
USER DEL <login>
USER PASS <login> <new-PIN>
```

## Безопасность и ограничения

- PIN сохраняется как `SHA-256`, а не открытым текстом; terminal также не
  выводит PIN в EGP-историю. Это **ролевая**, а не криптографически защищённая
  система: E2 remote-сеть не предназначена для защиты от враждебных чипов
  того же владельца.
- Files extension хранит базу в **локальной data-директории владельца E2** и
  передаёт её mainframe при загрузке. Для восстановления после рестарта
  владелец должен быть подключён к серверу; это ограничение самого Wiremod.
- Связь с mainframe требует одного владельца E2. Это намеренное ограничение,
  чтобы чужой игрок не мог подделать команду светофору.
- `Wire Text Entry` открывается игроком через E на нём. Не используй только
  вход `Prompt`: без прямого пользователя он может открыть окно владельцу, а
  не оператору терминала.
- Для надёжного отображения в стандартном EGP используй латиницу в заметках и
  сообщениях: не все EGP-шрифты содержат кириллицу.
- Signal Node безопасно закрывает сигнал при потере связи. Привод стрелки
  подключай с учётом собственной механики/дверей/сервопривода.
