# Expression 2 — справочник на русском

Конспект официальной документации Wiremod (github.com/wiremod/wire/wiki +
E2Helper) и лучших практик сообщества. Полный автогенерируемый справочник
функций лежит рядом в `reference/e2-docs-*.md`.

---

## 1. Что такое Expression 2

Expression 2 (E2) — встроенный в Wiremod скриптовый язык. «Чип» — это энтити
`gmod_wire_expression2`, которую спавнят тулом **Wire → Expression 2**. Код
хранится в `garrysmod/data/expression2/*.txt` и редактируется внутриигровым
редактором (табуляция, подсветка, встроенный поиск функций — «E2Helper»).

Конвейер тот же, что у гейтов Wire: **входы (`@inputs`) → обработка → выходы
(`@outputs`)**, только вся логика — кодом, а не проводами между гейтов.

Устройство выполнения: одно «выполнение» (execution) — прогон кода сверху
вниз. Выполнение случается при изменении входов, по таймерам/интервалам или
по событиям (`event`). За один проход нельзя «заснуть» — только таймеры.

Консольные команды:

| Команда | Назначение |
|---|---|
| `wire_expression2_reload` | Перезагрузить расширения E2 (после enable/disable) |
| `wire_expression2_extension_enable/disable <имя>` | Вкл/выкл расширение (propcore и др.) |
| `wire_expression2_unlimited 0/1` | Отключить лимиты производительности (админ) |
| `wire_expression2_model <mdl>` | Модель чипа вручную |

---

## 2. Директивы (шапка чипа)

```golo
@name Мой чип                    # имя, видно при наведении
@inputs Button Target:entity [X Y]:number   # входы: тип после двоеточия
@outputs Open Light:string                   # выходы — те же правила
@persist Counter State:table                 # живут между выполнениями
@trigger none                    # none = входы НЕ запускают выполнение
@model models/props_lab/huladoll.mdl         # модель чипа
@strict                          # строгий режим — СТАВИТЬ ВСЕГДА
@autoupdate                      # паста дюпа подтянет свежую версию из файлов
```

- `@inputs/@outputs/@persist` — тип без указания = `number`. Группы:
  `[A B C]:entity`.
- `@trigger` — какие входы триггерят выполнение: без аргументов/`all` = все,
  `none` = никакие, либо список имён. В современном стиле с `event`
  используют `@trigger none`.
- `@strict` — строгая семантика + runtime-ошибки вместо тихих фейлов
  (невалидный entity и т.п.) + новые фичи компилятора. Официально
  рекомендован всегда.
- `@autoupdate` работает только на сохранённых (есть файл) чипах.

Комментарии и препроцессор:

```golo
# однострочный
#[ много-
   строчный ]#

#ifdef propSpawn(svan)     # компайл-тайм проверка наличия функции
    print("propcore есть")
#else
    #error Включи propcore!   # компайл-тайм ошибка/варнинг: #error / #warning
#endif
```

---

## 3. Типы данных

E2 — **статически типизированный**: переменной нельзя присвоить значение
другого типа. Любая переменная начинается **с заглавной буквы** (иначе —
ошибка компиляции).

| Тип | Описание | Короткая сигнатура |
|---|---|---|
| `number` | число + «истинность» (0 = ложь, не-0 = истина) | `n` |
| `string` | строка в кавычках, может быть многострочной | `s` |
| `array` | список с числовыми индексами (без вложенных array/table) | `r` |
| `table` | типизированный словарь: строковые/числовые ключи | `t` |
| `function` | пользовательская функция/лямбда | `f` |
| `vector` | 3D-вектор `vec(x,y,z)` | `v` |
| `vector2`/`vector4` | `vec2`, `vec4` | `xv2`/`xv4` |
| `angle` | угол `ang(pitch,yaw,roll)` | `a` |
| `entity` | любая энтити (проп, игрок, NPC…) | `e` |
| `bone` | кость энтити | `b` |
| `wirelink` | «удалённый пульт» к wire-устройству | `xwl` |
| `ranger` | результат рейкаста (трейса) | `rd` |
| `matrix2`/`matrix4` | матрицы | `xm2`/`xm4` |
| `quaternion` | кватернион | `q` |
| `complex` | комплексное число | `c` |
| `gtable` | глобальная таблица между чипами | `gt` |
| `damage` | данные урона (событие entityDamage) | — |
| `movedata`/`usercmd`/`collision` | служебные типы событий | — |

Литералы: `0b1010` (бинарные), `0xFF` (hex), в строках `\x41` и `\u{2615}`
(юникод ☕).

Локальные и константные:

```golo
let X = 5          # видна только в текущем блоке { } (раньше — local)
const Pi2 = 6.283  # перезаписать нельзя
```

Truthiness: «ложные» значения — это нулевые значения типа: `0`, `""`,
пустой array/table, невалидный entity (`noentity()`), `vec(0,0,0)` и т.д.

---

## 4. Переменные и специальные префиксы

```golo
@inputs Button
@persist Count

if (~Button) { Count++ }   # ~Input   = 1, если ЭТОТ вход вызвал выполнение
Delta = $Count             # $Var     = изменение Var с прошлого обращения к $Var
if (->Button) { ... }      # ->Port   = 1, если порт реально подключён проводом
```

- `~` — триггер-префикс входа (работает и в выражениях: `~Button & Button`).
- `$` — дельта значения («на сколько изменилось»), работает и с persist.
- `->` — подключён ли провод (критично для wirelink-входов: `->EGP`).

Области видимости: глобальный скоуп (там живут `@inputs/@outputs/@persist`),
блоки `{ }` — локальные `let`. Переменная цикла `for` доступна и после цикла.

---

## 5. Операторы (по убыванию приоритета)

`Var++ Var--` → литералы, `~in`, `$var`, `->port` → `( )`, `f(x)` →
`obj:method()`, `Tab[key,type]` → `+x -x !x` → `A^B` → `* / %` → `+ -` →
`<< >>` → `< > <= >=` → `== !=` → `^^` (бинарный XOR) → `&&` (бинарный AND) →
`||` (бинарный OR) → `&` (логич. AND) → `|` (логич. OR) →
`A ? B : C` и `A ?: B` → присваивание `=`.

⚠️ Инверсия «классике»: `&` / `|` — **логические**, `&&` / `||` — **битовые**.

Прочее: `A+=1 A-=1 A*=1 A/=1`, конкатенация строк `+` (но лучше
`concat`/`format`), векторная математика покомпонентно.

---

## 6. Условия, циклы, switch

```golo
if (A) { ... } elseif (B) { ... } else { ... }

switch (Var) {           # есть fallthrough! не забывать break
    case 2, print("два")  break
    case 3,
    case 4, print("3 или 4")  break
    default, print("другое")
}

for (I = 1, 10, 2) { print(I) }          # start, end, step(=1)
while (perf()) { ... }                   # perf() = защита от квоты
do { ... } while (A)                     # проверка в конце
foreach (K, V:entity = Table) { ... }    # обход table/array по типу
# continue / break — как обычно
```

`foreach` по table идёт только по строковым ключам; по array — по всем
элементам. Элементы, добавленные во время обхода, в текущем проходе не
попадут.

---

## 7. Пользовательские функции и лямбды

```golo
function number clampMin(V, Min) {        # тип возврата перед именем
    return V < Min ? Min : V
}

function vector lerpVec(A:vector, B:vector, T:number) {
    return A + (B - A) * T
}

let Twice = function(X) { return X * 2 }  # лямбда в переменной
print(Twice(21))

# лямбды видят глобальные переменные (включая @persist) — «апвелью»
@persist Total
timer(1, function() { Total++ })          # ок
```

Объявление методов пользовательских функций в стиле `A:myFunc()` возможно
(`function number entity:healthFrac() { return This:health()/This:maxHealth() }`).

---

## 8. События (`event`) — современная система

Замена старым `runOn*`/`xxxClk()`. Регистрируются компилятором один раз,
**внутри `if` не вкладывать**; при срабатывании выполняется только тело
события. В редакторе достаточно начать печатать `event …` — автокомплит
соберёт сигнатуру.

Основные (полный список: `reference/Expression-2-Events.md`):

```golo
event tick()                                  # каждый тик сервера
event chat(Ply:entity, Msg:string, Team:number)
event keyPressed(Ply:entity, Key:string, Down:number, Bind:string)
event chipUsed(Ply:entity)                    # по чипу нажали E
event playerUse(Ply:entity, Ent:entity)
event playerSpawn / playerDeath / playerConnected / playerDisconnected
event playerEnteredVehicle / playerLeftVehicle
event entityCreated(Ent:entity)
event entityDamage(Victim:entity, Dmg:damage)
event entityCollision(Ent:entity, Hit:entity, Data:collision)  # + trackCollision(e)
event input(Name:string)                      # любой вход изменился
event removed(Resetting:number)               # последний прогон перед удалением
event httpLoaded(Body:string, Size:number, Url:string) / httpErrored(...)
event fileLoaded(File:string, Data:string) / fileErrored / fileWritten / fileList
event remote(Sender:entity, Ply:entity, Payload:table)  # E2↔E2 (см. §13)
event readCell(Addr:number) / writeCell(Addr:number, Val:number)  # hi-speed
```

Пример — чат-команды:

```golo
@strict
@persist Owner:entity
Owner = owner()

event chat(Ply:entity, Msg:string, _:number) {
    if (Ply != Owner | Msg[1] != "!") { exit() }   # в event — exit() (return тут запрещён!)
    let Args = Msg:sub(2):explode(" ")
    switch (Args[1, string]) {
        case "ping", print("pong")  break
        default, print("Не знаю команду: " + Args[1, string])
    }
}
```

Старые триггеры (легаси, встречается в чужих чипах): `first()` (первый
прогон), `duped()`/`dupefinished()`, `interval(ms)`, `runOnTick(1)` +
`tickClk()`, `runOnChat(1)` + `chatClk()` + `lastSaid()`/`lastSpoke()`,
`runOnKeys(ply,1,фильтр)` + `keyClk`, `timer("name", ms)` + `clk("name")`,
`last()` (= `event removed`). Для новых чипов — `event` + лямбда-таймеры.

---

## 9. Таймеры

Лямбда-таймеры (**задержка в СЕКУНДАХ**, старый `timer(name,ms)` — в
миллисекундах, не путать!):

```golo
timer(0.5, function() { print("разово через 0.5с") })
timer("blink", 1, 0, function() {        # имя, период, повторы (0 = бесконечно)
    Light = !Light
})
stoptimer("blink")
```

Таймер именем перезаписывает одноимённый. Точность — до тика (`0.015с` на
66-тик сервере; два таймера с разницей < тика сработают одновременно).
Константа `_TICKINTERVAL` = длительность тика.

Старый стиль: `interval(50)` — весь чип каждые 50 мс. Совместимо с events,
но хуже читается.

---

## 10. Производительность: ops и квоты

Каждая операция стоит N «ops». Квоты по умолчанию:

| Квота | Значение | Смысл |
|---|---|---|
| soft | 10 000 | свыше — накапливается «долг» |
| hard | 100 000 | верх потолка долга |
| tick | 25 000 | максимум за один тик |

Превышение = чип останавливается с ошибкой (в `@strict` ловится try/catch).
`perf()` — 1, если долга нет; `perf(80)` — 1, пока использовано <80%.

Правила экономии: `interval` не ниже ~50 мс для некритичного; find-запросы
не чаще лимита (20/с, burst 10/тик — иначе вернут пусто); тяжёлые обходы
массивов дробить по тикам через `perf()`; `switch` — дорого, предпочитать
`if/elseif` или lookup-таблицы; `changed()` НЕ означает «изменился с прошлого
выполнения» — используйте `~Input` или события.

Исключения (только `@strict`):

```golo
try {
    Risky = T["x", vector]
} catch (Err:string) {
    print("Поймали: " + Err)
}
```

---

## 11. Расширения (extensions)

Часть функционала живёт в расширениях. Включение на сервере:
`wire_expression2_extension_enable propcore` → `wire_expression2_reload`.
Большинство включено по умолчанию; **выключены по умолчанию**: `propcore`,
`constraintcore`, `effects`, `remoteupload`, `wiring`.

| Расширение | Даёт | e2-docs |
|---|---|---|
| core, debug, number, string, timer, selfaware | база | `e2-docs-core.md` и т.д. |
| entity, bone, constraint, npc | работа с энтити | `e2-docs-entity.md` |
| find | поиск энтити | `e2-docs-find.md` |
| ranger | рейкасты | `e2-docs-ranger.md` |
| hologram | голограммы | `e2-docs-hologram.md` |
| egp | 2D-графика на экранах | `e2-docs-egpfunctions.md`, `egpobjects` |
| wirelink | доступ к любым портам wire | `e2-docs-wirelink.md` |
| sound | звуки | `e2-docs-sound.md` |
| http | HTTP-запросы (часто выключено хостами!) | `e2-docs-http.md` |
| files | файлы в data/e2files | `e2-docs-files.md` |
| player, chat, console, weapon | игроки | `e2-docs-player.md` |
| array, table, globalvars, serialization | данные | `e2-docs-table.md` |
| vector, angle, matrix, quaternion, complex, bitwise, color | математика | соотв. |
| gametick, serverinfo, steamidconv, unitconv | инфо | соотв. |
| propcore ⚙️ | спавн/настройка пропов | `e2-docs-custom-prop.md` |
| effects, constraintcore, remoteupload, wiring ⚙️ | выкл. по умолчанию | `e2-docs-custom-*.md` |

---

## 12. Хиты функций по категориям

Точные сигнатуры — в `reference/e2-docs-*.md` и в E2Helper в игре.

**Ядро:** `print(...)`, `printTable(t)`, `error(s)`, `owner()`, `entity()`
(сам чип), `reset()`, `selfDestruct()`, `exit()`, `curtime()`, `time("sec"/
"min"/"hour")`, `tickInterval()`, константы `_PI`, `_TICKINTERVAL` и др.

**Математика:** `abs ceil floor round sqrt exp ln sin cos tan asin acos atan
atan2 rad deg min max clamp rand() randint(a,b) sign modf int frac` …

**Строки:** `S:length() S:upper() S:lower() S:sub(a,b) S:left(n) S:right(n)
S:find(re) S:match(re) S:replace(a,b) S:explode(sep) S:toNumber()
S:index(n) S:byte() S:char()`, `concat(arr, sep)`, `format("x=%.2f", X)`,
`s:toString()` у любых типов.

**Векторы/углы:** `vec(x,y,z) V:x() V:length() V:length2() V:normalized()
V:distance(W) V:dot(W) V:cross(W) V:toAngle() V:rotate(A)`, `ang(p,y,r)
A:forward() A:right() A:up() A:pitch() A:yaw() A:roll()`.

**Entity (выборка):** `E:pos() E:angles() E:vel() E:velL() E:angVel()
E:angVelVector() E:mass() E:health() E:maxHealth() E:isPlayer() E:isNPC()
E:isValid() E:id() E:model() E:owner() E:forward() E:bearing(V) E:elevation(V)
E:toLocal(V) E:toWorld(V) E:toLocalAxis(V) E:boxCenter() E:inertia()
E:isWeldedTo() E:isConstrained()`. Физика: `E:applyForce(V)
E:applyOffsetForce(V,Pos) E:applyTorque(V) E:applyAngForce(A)
E:applyAngForce(ang)` (+`-E:vel()*mass` гашение). Игрок: `P:name()
P:steamID() P:steamID64() P:eye() P:shootPos() P:aimEntity() P:keyPressed("w")
P:keyAttack1() P:inVehicle()`, `hideChat(1)` — скрыть команду из чата.

**find:** один запрос за раз → фильтры → клип → выборка:
```golo
findExcludeEntity(entity())              # чёрный список: себя
findIncludePlayerProps(owner())          # белый: мои пропы
findInSphere(entity():pos(), 500)        # запрос (вернёт КОЛИЧЕСТВО)
findClipToSphere(C, R)  findSortByDistance(Pos)
let R = findToArray()                    # результаты → array
```
Лимит: 20 запросов/с (burst 10/тик); `findCanQuery()`, `findCount()`.
Быстрые шорткаты вне квоты: `findPlayerByName(s) entity(N) players()`.

**ranger (трейс):**
```golo
R = rangerOffset(длина, старт, направление)   # или ranger(dist) от чипа
if (R:hit()) { R:position() R:entity() R:distance() R:hitNormal() R:fraction() }
rangerFilter(array(E1, E2))   # игнор-лист; rdPersist(1) — ranger «живой»
```

**hologram:** `holoCreate(idx) holoModel(idx,"hqcube") holoPos(idx,vec)
holoAng(idx,ang) holoColor(idx,vec4[,alpha]) holoScale(idx,vec)
holoParent(idx,ent) holoDelete(idx) holoCanCreate() holoMaxAmount()`
(индексы ≥ 1; поквотно! создавать в `if(first())`, потом только менять).

**wirelink** — прямой доступ к портам устройства без проводов:
```golo
@inputs P:wirelink
W     = P["W", number]          # прочитать вход устройства
P["AimPosition", vector] = V   # записать в его вход
->P ? ... : print("не подключён")
P:outputs() P:inputType("On")  # интроспекция
```

**EGP (через wirelink к экрану/HUD/эмиттеру):**
`WL:egpBox(id,pos2,size2) egpText(id,"txt",pos2) egpCircle egpLine
egpColor(id,vec4) egpAlpha egpMaterial egpAlign(h,v) egpClear()`
Координаты 0..512 (не читается! хранить в переменных), id 1..512;
HUD: `egpHudToggle()`; событие `egpHudConnect`.

**sound:** `soundPlay(idx, длительность, "path.wav") soundPitch(idx,pitch[,dur])
soundStop(idx) soundVolume(idx,vol[,dur]) soundDuration("path")`.

**files:** (разрешение игроку дать в настройках E2) `fileLoad("name.txt")`
→ `event fileLoaded`, `fileRead()`, `fileWrite("name", data)`,
`fileCanLoad()/fileCanWrite()`, директория — `data/e2files`.

**http:** `httpGet("url")` → `event httpLoaded/httpErrored`;
`httpRequest(url, body, method, headers)`. Часто запрещено на хостингах.

**gtable (глобальные таблицы):** `G = gTable("group", shared)` — общие данные
между чипами; deprecated в пользу remote-событий.

---

## 13. E2 ↔ E2: remote-события и datasignal

Современный способ (замена datasignal/gtable):

```golo
# чип-отправитель:
broadcastRemoteEvent(table("cmd"="open", "power"=5))      # всем чипам владельца
Target:sendRemoteEvent(Payload:table)                      # конкретному чипу

# чип-получатель:
event remote(Sender:entity, Ply:entity, T:table) {
    if (T["cmd", string] == "open") { ... }
}
```

Легаси: `signal("имя", значение)` / `event signal`/ `dsSignal(...)`,
gtable — встречается в старых чипах.

---

## 14. Рецепты (паттерны)

**Ховер/тащить проп к точке** (каждый тик; гашение скорости + антигравитация):
```golo
event tick() {
    let Diff = Target - E:pos()
    E:applyForce((Diff*Mul/_TICKINTERVAL - E:vel()
        - propGravity()*_TICKINTERVAL) * E:mass())
}
```
Mul≈0.03–0.067 (99% пути за 1–2 сек); для «висеть на месте» Taгet=E:pos()
спавна. Полные формулы вращения (кватернионы/applyAngForce) — в
`reference/E2:-Physics.md`.

**Турель по ranger:** `rangerOffset(dist, shootPos, направление)` → `R:entity()`
→ `E:bearing(R:position())`/`E:elevation(...)` → крутить applyAngForce к
цели. Добавить `rangerFilter(массив_друзей)`.

**Белый список по SteamID (не подделать, переживает реконнект):**
```golo
@persist WL:table
WL = table(owner():steamID() = 1, "STEAM_0:0:11111" = 2)   # 2 = «админ»
if (WL[Ply:steamID(), number] >= 1) { ... }
```

**Lookup-таблица вместо кучи if:**
```golo
const Models = table("box" = "models/hunter/blocks/cube025x025x025.mdl")
propSpawn(Models[Key, string] ?: Key, Pos, Ang, 1)
```

**Задержка/импульс:** `timer("off", Duration, 1, fn)`; антидребезг —
перезаписывать таймер тем же именем.

**Чат-команда с текстом с пробелами:** `Words:concat(" ", 2)`.

**Инициализация после дюпа:** события компилируются сами; при легаси-стиле
`if (first() | duped())`. Очистка при удалении — `event removed(n)`.

---

## 15. Отладка и редактор

- `print(...)` — в консоль сервера/чат (в зависимости от настроек);
  `printTable(T)` — красивый дамп; `error(S)` — стоп с сообщением;
  `hint("txt", dur)` — подсказка владельцу.
- Редактор: Ctrl+Space — автокомплит; встроенный E2Helper (поиск функций)
  с сигнатурами; подсветка табуляцией; `Ctrl+S`/кнопка — сгенерировать
  шапку из директив.
- Ошибки компиляции пишутся внизу редактора; runtime-ошибки — в чат
  владельцу. `@strict` + `try/catch` для диагностики «молчаливых» багов.

---

## 16. Безопасность и этикет сервера

- Чип выполняется от имени владельца; доступ к чужому коду у игроков нет,
  но `@persist`-данные видны админам.
- `http`, `sound`, `npc`, `propcore` помечены unsafe — на многих серверах
  ограничены; проектируйте чип с `#ifdef`-проверками.
- Не «фармите» find каждый тик, не спамьте `holoCreate` в цикле, глушите
  лишние выполнения через `@trigger none` + события.

## 17. Ссылки

- Офиц. wiki: github.com/wiremod/wire/wiki (копия: `reference/`)
- E2Helper в игре — самый актуальный список функций под вашу сборку.
- Дискорд Wiremod, r/wiremod.
