--[[ Живой прогон привязки значка объекта к двери (заказ владельца 28.08).

     «Красивее будет смотреться, если значок жилья будет крепиться лучше
      всего к дверям после создания зоны.»
     «И информация, допустим, Квартира №2 стоимость 85.000 GRM, тоже к
      двери чтобы крепилось.»

     ЧТО БЫЛО НЕ ТАК. Значок и подпись висели в геометрическом ЦЕНТРЕ
     зоны. Зону обводят вокруг всего дома, поэтому центр — это середина
     комнаты или стена: эмблема торчала в воздухе внутри помещения, а
     цену было видно только изнутри. Плюс свежесозданная зона вообще не
     имела дверей — их притягивало только в момент покупки.

     Стенд СНАЧАЛА воспроизводит старое поведение (значок далеко от
     двери, у новой зоны дверей нет), потом проверяет новое.

     Запуск: luajit tools/luatest/sim_estate_door_marker.lua ]]

local pass, fail = 0, 0
local function ok(v, n, extra)
    if v then pass = pass + 1 print("  ok   " .. n)
    else fail = fail + 1 print("  FAIL " .. n .. "  " .. tostring(extra or "")) end
end

-----------------------------------------------------------------------
-- ОКРУЖЕНИЕ GARRY'S MOD
-----------------------------------------------------------------------
SERVER, CLIENT = true, false
function AddCSLuaFile() end
function istable(v) return type(v) == "table" end
function isstring(v) return type(v) == "string" end
function isnumber(v) return type(v) == "number" end
function isfunction(v) return type(v) == "function" end
function IsValid(v) return istable(v) and v._valid ~= false end
function string.Trim(s) return (string.gsub(tostring(s or ""), "^%s*(.-)%s*$", "%1")) end
function math.Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function table.Count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
function Color(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end

local VecMT = {}
VecMT.__index = VecMT
function VecMT:DistToSqr(o)
    local dx, dy, dz = self.x - o.x, self.y - o.y, self.z - o.z
    return dx * dx + dy * dy + dz * dz
end
function VecMT.__add(a, b) return Vector(a.x + b.x, a.y + b.y, a.z + b.z) end
function VecMT.__sub(a, b) return Vector(a.x - b.x, a.y - b.y, a.z - b.z) end
function Vector(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, VecMT) end

function CurTime() return 100 end
function ErrorNoHalt() end
function ConVarExists() return true end
function CreateConVar() end
function GetConVar() return { GetInt = function() return 3 end } end
bit = { bor = function(a) return a end }
FCVAR_ARCHIVE, FCVAR_REPLICATED = 1, 2

hook = { _t = {} }
function hook.Add(e, i, f) hook._t[e] = hook._t[e] or {}; hook._t[e][i] = f end
function hook.Run(e, ...)
    for _, f in pairs(hook._t[e] or {}) do local r = f(...) if r ~= nil then return r end end
end

timer = { Simple = function(_, f) f() end, Create = function() end }
concommand = { Add = function() end }
util = { AddNetworkString = function() end, TableToJSON = function() return "{}" end,
    Compress = function(x) return x end }
net = setmetatable({}, { __index = function() return function() return "" end end })
ents = { FindByClass = function() return {} end, GetAll = function() return {} end }

GRM = {}

assert(loadfile("lua/autorun/sh_grm_estate.lua"))()
local ES = GRM.Estate

-----------------------------------------------------------------------
-- МИР: КВАРТИРА С ДВЕРЬЮ
-----------------------------------------------------------------------
--[[ Зона квартиры обведена вокруг помещения: 0..400 по X, 0..300 по Y,
     пол на z=0, потолок z=200. Центр — Vector(200,150,100), то есть
     ровно посреди комнаты, на уровне пояса. Именно туда раньше и
     цеплялся значок. ]]
local ZONE = { mins = { x = 0, y = 0, z = 0 }, maxs = { x = 400, y = 300, z = 200 } }

local DOORS = {}
local function mkDoor(id, pos, halfW, height)
    halfW = halfW or 24
    height = height or 82
    local d = {
        _valid = true, _id = id, _pos = pos,
        GetPos = function(s) return s._pos end,
        WorldSpaceCenter = function(s) return Vector(s._pos.x, s._pos.y, s._pos.z + height * 0.5) end,
        WorldSpaceAABB = function(s)
            return Vector(s._pos.x - halfW, s._pos.y - halfW, s._pos.z),
                   Vector(s._pos.x + halfW, s._pos.y + halfW, s._pos.z + height)
        end,
    }
    DOORS[#DOORS + 1] = d
    return d
end

-- Входная дверь стоит в стене y=0 (южная), внутренняя — в глубине комнаты.
local frontDoor = mkDoor("map_m11", Vector(200, 0, 0))
local backDoor  = mkDoor("map_m12", Vector(200, 260, 0))

GRM.Doors = {
    AllDoors = function() return DOORS end,
    GetDoorID = function(e) return e._id end,
    IsDoor = function(e) return istable(e) and e._id ~= nil end,
}

local flat = {
    id = "flat2", name = "Квартира №2", type = "apartment",
    estateKind = "estate",
    ownerType = "none", ownerKey = "", ownerName = "",
    purchasePrice = 85000, utilityRate = 300, utilityDebt = 0,
    doors = { "map_m11", "map_m12" },
    zone = ZONE,
}
GRM.Property = { Records = { flat2 = flat }, Save = function() end, Reindex = function() end }

-----------------------------------------------------------------------
print("\n=== 1. БАГ ВОСПРОИЗВЕДЁН: СТАРЫЙ ЗНАЧОК ВИСЕЛ В ЦЕНТРЕ КОМНАТЫ ===")
-----------------------------------------------------------------------
local center = ES.ZoneCenter(flat)
local oldPos = Vector(center.x, center.y, center.z + ES.MarkerHeight)
local doorPos = frontDoor:GetPos()

local oldFlat = math.sqrt((oldPos.x - doorPos.x) ^ 2 + (oldPos.y - doorPos.y) ^ 2)
ok(oldFlat > 100,
   "БАГ: старая точка значка была в 100+ юнитах от входной двери",
   ("%.0f юнитов"):format(oldFlat))
ok(oldPos.z < 120 and oldPos.z > 80,
   "БАГ: и болталась на середине высоты комнаты, а не над входом", oldPos.z)

-----------------------------------------------------------------------
print("\n=== 2. ГЛАВНАЯ ДВЕРЬ ВЫБИРАЕТСЯ ОСМЫСЛЕННО И СТАБИЛЬНО ===")
-----------------------------------------------------------------------
--[[ ВАЖНО. Первая версия правки выбирала «дверь, ближайшую к ЦЕНТРУ
     зоны» — и этот стенд сразу её завалил: ближе всего к центру стоит
     внутренняя дверь комнаты (y=260 при центре y=150), а вход врезан в
     наружную стену y=0, то есть максимально далеко от центра. Правильный
     признак входа — близость к ГРАНИЦЕ зоны. ]]
local main = ES.MainDoor(flat)
ok(main == frontDoor,
   "ИСПРАВЛЕНО: выбрана дверь у наружной стены (вход), а не внутренняя",
   main and main._id)
ok(main ~= backDoor,
   "внутренняя дверь в глубине помещения главной не считается")

--[[ Прямая проверка признака: у входной двери запас до стены нулевой,
     у внутренней — большой. ]]
local mFront = ES.ZoneEdge(flat, frontDoor:GetPos())
local mBack  = ES.ZoneEdge(flat, backDoor:GetPos())
ok(mFront < mBack, "запас до границы зоны у входа меньше, чем у внутренней двери",
   ("вход %.0f, внутренняя %.0f"):format(mFront, mBack))

--[[ Порядок дверей в записи не должен влиять на результат: список
     rec.doors собирается обходом мира, его порядок не гарантирован. ]]
flat.doors = { "map_m12", "map_m11" }
ok(ES.MainDoor(flat) == frontDoor, "порядок в rec.doors на выбор не влияет")
flat.doors = { "map_m11", "map_m12" }

--[[ Ничья по расстоянию: две двери симметрично от центра. Без разрыва
     ничьей значок прыгал бы между ними от пересчёта к пересчёту. ]]
local tieRec = { id = "tie", estateKind = "estate", doors = { "tieB", "tieA" }, zone = ZONE }
local tA = mkDoor("tieA", Vector(200, 0, 0))
local tB = mkDoor("tieB", Vector(200, 300, 0))
local first = ES.MainDoor(tieRec)
tieRec.doors = { "tieA", "tieB" }
local second = ES.MainDoor(tieRec)
ok(first == second, "при равном расстоянии выбор детерминирован — значок не прыгает",
   (first and first._id or "?") .. " / " .. (second and second._id or "?"))
ok(first == tA, "ничья разрешается по идентификатору двери", first and first._id)
tA._valid, tB._valid = false, false

ok(ES.MainDoor({ id = "x", doors = {} }) == nil, "объект без дверей главной двери не имеет")
ok(ES.MainDoor(nil) == nil, "nil не роняет расчёт")

--[[ Дверь числится за объектом, но на карте её нет (снесли, сменили
     карту): не должно быть ни ошибки, ни выбора «мёртвой» двери. ]]
local ghost = { id = "gh", estateKind = "estate", doors = { "no_such_door" }, zone = ZONE }
ok(ES.MainDoor(ghost) == nil, "исчезнувшая дверь не выбирается и не роняет расчёт")

-----------------------------------------------------------------------
print("\n=== 3. ЗНАЧОК КРЕПИТСЯ К ДВЕРИ ===")
-----------------------------------------------------------------------
local anchor, onDoor = ES.MarkerAnchor(flat)
ok(anchor ~= nil, "точка значка посчитана")
ok(onDoor == true, "и помечена как «на двери» — клиент об этом знает")

local newFlat = math.sqrt((anchor.x - doorPos.x) ^ 2 + (anchor.y - doorPos.y) ^ 2)
ok(newFlat < oldFlat / 3,
   "ИСПРАВЛЕНО: значок переехал к двери — стало в разы ближе",
   ("было %.0f, стало %.0f юнитов"):format(oldFlat, newFlat))
ok(newFlat <= ES.DoorOffset + 1,
   "и стоит ровно на заданном выносе от полотна", ("%.1f"):format(newFlat))

--[[ Выносим НАРУЖУ, прочь от центра зоны: дом разглядывают с улицы,
     а не изнутри квартиры. Дверь на y=0, центр на y=150 — значит
     значок обязан уйти в минус по Y. ]]
ok(anchor.y < doorPos.y,
   "значок вынесен НАРУЖУ от центра зоны, а не внутрь комнаты",
   ("дверь y=%.0f, значок y=%.0f, центр y=%.0f"):format(doorPos.y, anchor.y, center.y))

local _, top = frontDoor:WorldSpaceAABB()
ok(anchor.z > top.z, "значок поднят НАД верхним краем двери, как вывеска",
   ("верх двери %.0f, значок %.0f"):format(top.z, anchor.z))
ok(anchor.z <= top.z + ES.DoorLift + 0.01, "но не улетел под потолок", anchor.z)
ok(anchor.z > doorPos.z, "и точно не утоплен в пол")

--[[ Дверь в УГЛУ зоны. Направление «прочь от центра» увело бы значок по
     диагонали прямо в стену; правильное — перпендикулярно ближайшей
     грани. Ставим дверь у западной стены рядом с южным углом. ]]
local cornerDoor = mkDoor("corner_m1", Vector(4, 20, 0))
local corner = { id = "cr", name = "Угловая", estateKind = "estate",
    ownerType = "none", doors = { "corner_m1" }, zone = ZONE, purchasePrice = 1000 }
local cPos, cOnDoor = ES.MarkerAnchor(corner)
ok(cOnDoor == true, "угловая дверь тоже становится якорем")
ok(cPos.x < 4, "значок ушёл строго на запад — к ближайшей стене",
   ("x=%.1f"):format(cPos.x))
ok(math.abs(cPos.y - 20) < 0.01,
   "и не поехал по диагонали вдоль стены", ("y=%.1f"):format(cPos.y))
cornerDoor._valid = false

-----------------------------------------------------------------------
print("\n=== 4. ОБЪЕКТ БЕЗ ДВЕРЕЙ НЕ ТЕРЯЕТ ЗНАЧОК ===")
-----------------------------------------------------------------------
--[[ Старые зоны, к которым двери так и не привязали, обязаны рисоваться
     по-прежнему — иначе правка «спрячет» половину карты. ]]
local noDoors = { id = "nd", name = "Склад", estateKind = "business",
    ownerType = "none", doors = {}, zone = ZONE, purchasePrice = 10000 }
local ndPos, ndOnDoor = ES.MarkerAnchor(noDoors)
ok(ndPos ~= nil, "значок всё равно есть")
ok(ndOnDoor == false, "но помечен как «не на двери»")
ok(math.abs(ndPos.x - center.x) < 0.01 and math.abs(ndPos.y - center.y) < 0.01,
   "запасной вариант — прежний центр зоны")
ok(math.abs(ndPos.z - (center.z + ES.MarkerHeight)) < 0.01,
   "с прежней высотой MarkerHeight", ndPos.z)

local noZone = ES.MarkerAnchor({ id = "nz", doors = {} })
ok(noZone == nil, "объект вообще без зоны точки не даёт — в снимок не попадёт")

-----------------------------------------------------------------------
print("\n=== 5. СНИМОК ДЛЯ КЛИЕНТА НЕСЁТ ТОЧКУ ДВЕРИ ===")
-----------------------------------------------------------------------
ES.InvalidateScan()
local snap = ES.BuildSnapshot()
local row
for _, r in ipairs(snap) do if r.id == "flat2" then row = r end end
ok(row ~= nil, "квартира попала в снимок")
ok(row and row.onDoor == true, "в снимке есть признак «значок на двери»")
ok(row and math.abs(row.pos.x - anchor.x) < 0.01
       and math.abs(row.pos.y - anchor.y) < 0.01
       and math.abs(row.pos.z - anchor.z) < 0.01,
   "координаты в снимке = точка у двери, а не центр зоны",
   row and ("%.0f %.0f %.0f"):format(row.pos.x, row.pos.y, row.pos.z))
ok(row and row.price == 85000, "цена в снимке та, что назначил админ", row and row.price)

--[[ Точку считает СЕРВЕР: только он знает положение дверей. Проверяем,
     что клиент не пытается искать двери сам. ]]
local src = (function()
    local fh = assert(io.open("lua/autorun/sh_grm_estate.lua", "rb"))
    local t = fh:read("*a") fh:close() return t
end)()
local clientBlock = src:match("if CLIENT then.*$") or ""
ok(clientBlock ~= "", "клиентская часть найдена")
ok(clientBlock:find("MainDoor", 1, true) == nil,
   "клиент не ищет двери сам — берёт готовые координаты из снимка")

-----------------------------------------------------------------------
print("\n=== 6. ПОДПИСЬ ТОЖЕ У ДВЕРИ И ЧИТАЕМА ===")
-----------------------------------------------------------------------
--[[ Подпись рисуется от той же точки, что и значок, значит переехала
     вместе с ним. Проверяем сдвиг: на двери эмблема стоит над полотном,
     и текст надо увести выше, иначе он ляжет на неё. ]]
ok(clientBlock:find("zone.onDoor and 30 or 18", 1, true) ~= nil,
   "ИСПРАВЛЕНО: у двери подпись поднимается выше, чем над центром зоны")
ok(clientBlock:find("zone.pos.x, zone.pos.y, zone.pos.z", 1, true) ~= nil,
   "подпись и значок берут ОДНУ И ТУ ЖЕ точку — не разъедутся")

-- Воспроизводим расчёт подъёма: на двери должно быть строго выше.
local function lift(onDoorFlag) return onDoorFlag and 30 or 18 end
ok(lift(true) > lift(false), "на двери зазор больше, чем при центре зоны")
ok(anchor.z + lift(true) > top.z, "строка названия оказывается выше полотна двери")

print("\n--- цена в подписи ---")
ok(ES.Money(85000) == "85 000 GRM",
   "ИСПРАВЛЕНО: цена разбита по разрядам, как её пишет владелец («85.000»)",
   ES.Money(85000))
ok(ES.Money(0) == "0 GRM", "ноль форматируется без мусора", ES.Money(0))
ok(ES.Money(500) == "500 GRM", "короткие суммы не ломаются", ES.Money(500))
ok(ES.Money(1234567) == "1 234 567 GRM", "миллионы читаются", ES.Money(1234567))
ok(clientBlock:find("ES.Money(zone.price)", 1, true) ~= nil,
   "подпись рисует цену через форматирование, а не слитным числом")

--[[ Если модуль валюты загружен — берём его формат, чтобы табличка у
     двери и HUD показывали суммы одинаково. ]]
local savedFormat = GRM.Format
GRM.Format = function(n) return "≈" .. tostring(n) end
ok(ES.Money(85000) == "≈85000", "при живом модуле валюты используется общий формат",
   ES.Money(85000))
GRM.Format = savedFormat
ok(ES.Money(85000) == "85 000 GRM", "без него — собственный, значок не зависит от порядка загрузки")

-----------------------------------------------------------------------
print("\n=== 7. ДВЕРИ ПРИВЯЗЫВАЮТСЯ СРАЗУ ПРИ СОЗДАНИИ ЗОНЫ ===")
-----------------------------------------------------------------------
--[[ Главная причина, по которой значок «не крепился к дверям»: у
     свежесозданной зоны список дверей пустой, привязка случалась только
     при покупке. Значит до первой продажи эмблема висела в центре. ]]
local ATTACH_CALLS = {}
GRM.EstateDeal = {
    -- Упрощённая, но честная привязка: двери рядом с зоной и ничьи.
    AttachDoors = function(rec)
        ATTACH_CALLS[#ATTACH_CALLS + 1] = rec.id
        rec.doors = istable(rec.doors) and rec.doors or {}
        local have = {}
        for _, id in ipairs(rec.doors) do have[tostring(id)] = true end
        local added = 0
        for _, d in ipairs(DOORS) do
            if IsValid(d) then
                local p = d:GetPos()
                local a, b = rec.zone.mins, rec.zone.maxs
                local r = 96
                local inside = p.x >= a.x - r and p.y >= a.y - r and p.z >= a.z - r
                           and p.x <= b.x + r and p.y <= b.y + r and p.z <= b.z + r
                if inside and not have[d._id] and not GRM.Property.Records.flat2 then
                    rec.doors[#rec.doors + 1] = d._id
                    have[d._id] = true
                    added = added + 1
                end
            end
        end
        return added
    end,
}

-- Убираем прежнюю запись, чтобы двери считались ничьими.
GRM.Property.Records.flat2 = nil
GRM.Property.Normalize = function(r)
    r.doors = istable(r.doors) and r.doors or {}
    r.ownerType = r.ownerType or "none"
    r.utilityDebt = r.utilityDebt or 0
    return r
end

local admin = { _valid = true, IsSuperAdmin = function() return true end,
    SteamID64 = function() return "7" end }

local created, msg, rec = ES.CreateZone(admin,
    Vector(0, 0, 0), Vector(400, 300, 10), "Квартира №2", "estate", 85000)

ok(created == true, "зона создана", msg)
ok(#ATTACH_CALLS == 1, "ИСПРАВЛЕНО: привязка дверей вызвана прямо при создании зоны",
   #ATTACH_CALLS)
ok(rec and #rec.doors >= 1, "у свежей зоны СРАЗУ есть двери",
   rec and #rec.doors)
ok(tostring(msg):find("дверей:", 1, true) ~= nil,
   "админ видит в ответе, сколько дверей подтянулось", msg)

--[[ И главное: значок свежей зоны уже крепится к двери, ещё до того,
     как объект кто-то купил. Раньше здесь был бы центр комнаты. ]]
local freshPos, freshOnDoor = ES.MarkerAnchor(rec)
ok(freshOnDoor == true, "ИСПРАВЛЕНО: значок новой зоны сразу на двери")
local freshFlat = math.sqrt((freshPos.x - doorPos.x) ^ 2 + (freshPos.y - doorPos.y) ^ 2)
ok(freshFlat < oldFlat / 3, "и он рядом с дверью, а не посреди комнаты",
   ("%.0f юнитов"):format(freshFlat))
ok(rec.ownerType == "none", "при этом объект остался СВОБОДНЫМ — привязка не продаёт его")

-- Привязка не должна падать, если модуль сделок ещё не загружен.
GRM.EstateDeal = nil
local ok2, msg2, rec2 = ES.CreateZone(admin,
    Vector(1000, 0, 0), Vector(1400, 300, 10), "Склад", "business", 20000)
ok(ok2 == true, "без модуля сделок зона всё равно создаётся", msg2)
ok(rec2 and #rec2.doors == 0, "просто без дверей — падения нет")

-----------------------------------------------------------------------
print("\n=== 8. НАСТРОЙКИ ВЫНОСА ЗДРАВЫЕ ===")
-----------------------------------------------------------------------
ok(ES.DoorOffset > 0 and ES.DoorOffset <= 64,
   "вынос от полотна задан и не превращается в «значок в соседнем доме»", ES.DoorOffset)
ok(ES.DoorLift >= 0 and ES.DoorLift <= 48,
   "подъём над дверью небольшой — табличка, а не флюгер", ES.DoorLift)

-----------------------------------------------------------------------
print(("\n== ИТОГ: %d ok, %d FAIL =="):format(pass, fail))
if fail > 0 then os.exit(1) end
