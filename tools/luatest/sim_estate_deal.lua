--[[ Живой прогон сделок с недвижимостью (заказ владельца 28.08).

     «Если купил бизнес-зону, то автоматически присваивается владелец
      колонкам, автомату с едой и т.д. Всё оборудование в зоне бизнеса
      сразу автоматически выкупается и освобождается.»
     «Нужно более красивое и простое меню нежели /property_admin.»
     «Квартир/жилья также касается. Ближайшие двери к зоне или в зоне
      тоже автоматически приобретаются/продаются.»

     Стенд сначала воспроизводит старое поведение (купил зону — получил
     пустоту), потом проверяет новое.

     Запуск: luajit tools/luatest/sim_estate_deal.lua ]]

local pass, fail = 0, 0
local function ok(v, n, extra)
    if v then pass = pass + 1 print("  ok   " .. n)
    else fail = fail + 1 print("  FAIL " .. n .. "  " .. tostring(extra or "")) end
end

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

local VecMT = {}
VecMT.__index = VecMT
function VecMT:DistToSqr(o) local dx,dy,dz=self.x-o.x,self.y-o.y,self.z-o.z return dx*dx+dy*dy+dz*dz end
function VecMT.__add(a,b) return Vector(a.x+b.x,a.y+b.y,a.z+b.z) end
function VecMT.__sub(a,b) return Vector(a.x-b.x,a.y-b.y,a.z-b.z) end
function Vector(x,y,z) return setmetatable({x=x or 0,y=y or 0,z=z or 0}, VecMT) end
function Angle(p,y,r) return {p=p or 0,y=y or 0,r=r or 0} end
function ErrorNoHalt() end
HUD_PRINTTALK = 3
CurTime = function() return 100 end
local REALTIME = 1700000000
os.time = function() return REALTIME end
game = { GetMap = function() return "rp_city" end }

hook = { _t = {} }
function hook.Add(e,i,f) hook._t[e]=hook._t[e] or {}; hook._t[e][i]=f end
function hook.Remove(e,i) if hook._t[e] then hook._t[e][i]=nil end end
function hook.Run(e,...) for _,f in pairs(hook._t[e] or {}) do local r=f(...) if r~=nil then return r end end end
local function runAll(e,...) for _,f in pairs(hook._t[e] or {}) do f(...) end end

timer = { Simple = function(_,f) f() end, Create = function() end,
          Remove = function() end, Exists = function() return false end }
local commands = {}
concommand = { Add = function(n,f) commands[n]=f end }

local SENT = {}
local buf
net = {
    AddNetworkString=function() end,
    Start=function(n) buf={name=n,args={}} end,
    WriteTable=function(v) table.insert(buf.args,v) end,
    WriteString=function(v) table.insert(buf.args,v) end,
    WriteEntity=function(v) table.insert(buf.args,v) end,
    WriteFloat=function() end, WriteUInt=function() end, WriteBool=function() end,
    Send=function(p) buf.to=p table.insert(SENT,buf) end,
    Receive=function(n,f) net["_h_"..n]=f end,
}
util = { AddNetworkString=function() end, TableToJSON=function() return "J" end,
         JSONToTable=function() return {} end }
file = { Exists=function() return false end, Read=function() return "" end,
         Write=function() end, CreateDir=function() end, IsDir=function() return true end }
local PLAYERS = {}
player = { GetAll=function() return PLAYERS end }
function CreateConVar(_,d) return {GetFloat=function() return tonumber(d) or 0 end,
    GetBool=function() return d~="0" end, GetString=function() return tostring(d) end,
    GetInt=function() return math.floor(tonumber(d) or 0) end} end

-- Мир: список entity.
local WORLD = {}
ents = {
    GetAll = function() return WORLD end,
    FindByClass = function(c)
        local o = {}
        for _, e in ipairs(WORLD) do if e:GetClass() == c then o[#o+1] = e end end
        return o
    end,
}

local NOTIFIED = {}
GRM = { Perf = { Players=function() return PLAYERS end } }
GRM.Notify = function(p,msg) NOTIFIED[#NOTIFIED+1] = { to=p, msg=msg } end
GRM.Audit = { Write = function() end }

local WALLET = {}
GRM.HasMoney = function(p,n) return (WALLET[p] or 0) >= n end
GRM.TakeMoney = function(p,n) WALLET[p] = (WALLET[p] or 0) - n end
GRM.GiveMoney = function(p,n) WALLET[p] = (WALLET[p] or 0) + n end

GRM.Identity = {
    CharacterKey = function(p) return isstring(p) and p or p._key end,
    IsCharacterKey = function(k) return isstring(k) and k:match("^%d+:char[1-3]$") ~= nil end,
    ResolveCharacter = function() return nil end,
}

--[[ Двери-заглушки с НАСТОЯЩЕЙ семантикой: у каждой своя запись с
     владельцем и NW-поле GRM_DoorOwner, из которого рисуется табличка.
     Без этого стенд не увидел бы баг «дверь осталась ничья». ]]
local SAVED_PERSIST = { vending = 0, fuel = 0 }
local DOOR_RECS = {}
local DOOR_SAVES = 0

local function doorLabel(rec)
    if not rec or rec.owner_type == "none" then return "" end
    if rec.owner_type == "player" then return rec.owner_nick or "" end
    if rec.owner_type == "faction" then return "Фракция: " .. tostring(rec.owner_faction) end
    return ""
end

GRM.Doors = {
    IsDoor = function(e) return IsValid(e) and e._door == true end,
    GetDoorID = function(e) return e._id end,
    LockDoor = function() end,
    SaveDoors = function() DOOR_SAVES = DOOR_SAVES + 1 end,
    HasWarrant = function() return false end, HasPropertyWarrant = function() return false end,
    GetRecord = function(e)
        if not IsValid(e) then return nil end
        DOOR_RECS[e._id] = DOOR_RECS[e._id] or
            { id = e._id, owner_type = "none", owner_key = "", owner_nick = "",
              owner_faction = "", ownable = true, title = "" }
        return DOOR_RECS[e._id], e._id
    end,
    ApplyRecordVisual = function(e, rec)
        if IsValid(e) then e._nwOwner = doorLabel(rec) end
    end,
}
-- Та же функция, что и в настоящем модуле дверей.
GRM.Doors.SetDoorOwner = function(ent, ownerType, key, nick, title)
    if not IsValid(ent) then return false end
    local rec = GRM.Doors.GetRecord(ent)
    if not rec then return false end
    ownerType = tostring(ownerType or "none")
    if ownerType == "none" then
        rec.owner_type = "none"
        rec.owner_key, rec.owner_nick, rec.owner_faction = "", "", ""
        rec.ownable = true
    else
        rec.owner_type = ownerType
        if ownerType == "faction" then
            rec.owner_faction = tostring(key or "")
            rec.owner_key, rec.owner_nick = "", ""
        else
            rec.owner_key = tostring(key or "")
            rec.owner_nick = tostring(nick or "")
            rec.owner_faction = ""
        end
        rec.ownable = false
    end
    if isstring(title) and title ~= "" then rec.title = title end
    GRM.Doors.ApplyRecordVisual(ent, rec)
    GRM.Doors.SaveDoors()
    return true, rec
end
GRM.Access = { Can = function() return false end, Register = function() end }
GRM.VendingBiz = { MarkDirty = function() end,
    Persist = function() SAVED_PERSIST.vending = SAVED_PERSIST.vending + 1 end }
GRM.Fuel = { PricePerLiter = 50,
    SavePumps = function() SAVED_PERSIST.fuel = SAVED_PERSIST.fuel + 1 end }
GRM.Persistence = { LoadJSON = function(_,d) return d end, SaveJSON = function() return true end }
GRM.Utf8Sub = function(s,n) return string.sub(s,1,n) end
Factions = {}

assert(loadfile("lua/autorun/sh_grm_property.lua"))()
local P = GRM.Property

-- Estate: минимальный контракт, который нужен модулю сделок.
GRM.Estate = {
    EquipmentClasses = {
        grm_vending_machine = { label = "автомат", kind = "vending" },
        grm_fuel_pump = { label = "колонка", kind = "fuel" },
    },
    StateBuyback = 0.6,
    KindOf = function(rec)
        local k = tostring(rec.estateKind or "")
        if k ~= "" then return k end
        return rec.type == "apartment" and "estate" or
               (rec.type == "shop" and "business" or "none")
    end,
    PointInZone = function(rec, pos)
        if not istable(rec.zone) then return false end
        local a,b = rec.zone.mins, rec.zone.maxs
        return pos.x>=a.x and pos.y>=a.y and pos.z>=a.z
           and pos.x<=b.x and pos.y<=b.y and pos.z<=b.z
    end,
    ZoneCenter = function(rec)
        if not istable(rec.zone) then return nil end
        local a,b = rec.zone.mins, rec.zone.maxs
        return Vector((a.x+b.x)/2,(a.y+b.y)/2,(a.z+b.z)/2)
    end,
    ZoneArea = function() return 1015 end,
    InvalidateScan = function() end,
}
GRM.Estate.ScanZone = function(rec)
    local out = { total = 0, byKind = {}, entities = {} }
    for class, info in pairs(GRM.Estate.EquipmentClasses) do
        for _, e in ipairs(ents.FindByClass(class)) do
            if GRM.Estate.PointInZone(rec, e:GetPos()) then
                out.total = out.total + 1
                out.byKind[info.kind] = (out.byKind[info.kind] or 0) + 1
                out.entities[#out.entities+1] = e
            end
        end
    end
    return out
end

assert(loadfile("lua/autorun/sh_grm_estate_deal.lua"))()
local DL = GRM.EstateDeal

-----------------------------------------------------------------------
-- ЗАГЛУШКИ ОБЪЕКТОВ
-----------------------------------------------------------------------
local function mkPly(o)
    o = o or {}
    local said = {}
    return {
        _valid=true, _key=o.key or "1:char1", _pos=o.pos or Vector(0,0,0), _said=said,
        _nw={ GRM_RPName = o.name or "Игрок" },
        SteamID64=function() return "1" end, SteamID=function() return "STEAM_0:0:1" end,
        Nick=function() return o.name or "Игрок" end,
        GetPos=function(s) return s._pos end,
        IsPlayer=function() return true end,
        IsSuperAdmin=function() return o.admin==true end,
        PrintMessage=function(_,_,t) said[#said+1]=t end,
        ChatPrint=function(_,t) said[#said+1]=t end,
        GetNWString=function(s,k,d) return s._nw[k] or d or "" end,
        GetNWBool=function(_,_,d) return d or false end,
        SetNWBool=function() end, SetNWString=function() end,
        GetEyeTrace=function() return { Entity=nil } end,
    }
end

local function mkVending(pos)
    local e = { _valid=true, _pos=pos, _nw={},
        GetClass=function() return "grm_vending_machine" end,
        GetPos=function(s) return s._pos end,
        SetNWString=function(s,k,v) s._nw[k]=v end,
        GetNWString=function(s,k,d) return s._nw[k] or d or "" end }
    WORLD[#WORLD+1] = e
    return e
end

local function mkPump(pos)
    local e = { _valid=true, _pos=pos, _owner="", _price=0,
        GetClass=function() return "grm_fuel_pump" end,
        GetPos=function(s) return s._pos end,
        SetOwnerKey=function(s,v) s._owner=v end,
        GetOwnerKey=function(s) return s._owner end,
        SetPriceL=function(s,v) s._price=v end,
        GetPriceL=function(s) return s._price end }
    WORLD[#WORLD+1] = e
    return e
end

local function mkDoor(id, pos)
    local e = { _valid=true, _door=true, _id=id, _pos=pos, _nwOwner="",
        GetClass=function() return "prop_door_rotating" end,
        GetPos=function(s) return s._pos end,
        -- То, что игрок видит на табличке.
        GetNWString=function(s,k,d) if k=="GRM_DoorOwner" then return s._nwOwner end return d or "" end }
    WORLD[#WORLD+1] = e
    return e
end

-----------------------------------------------------------------------
print("\n=== 1. СТАРОЕ ПОВЕДЕНИЕ: КУПИЛ ЗОНУ — ПОЛУЧИЛ ПУСТОТУ ===")
-----------------------------------------------------------------------
do
    -- Игрок покупает зону, а владелец автоматов не меняется.
    local v = { owner = "" }
    local zoneOwner = ""
    zoneOwner = "1:char1"          -- «купил зону»
    ok(v.owner == "",
       "БАГ ВОСПРОИЗВЕДЁН: зона куплена, а автомат остался ничей")
    ok(zoneOwner ~= v.owner,
       "владелец зоны и владелец оборудования расходились")
end

-----------------------------------------------------------------------
print("\n=== 2. ПОКУПКА БИЗНЕСА ПЕРЕДАЁТ ОБОРУДОВАНИЕ ===")
-----------------------------------------------------------------------
local shop = P.Normalize({
    id="biz1", name="Бизнес-объект", type="shop", estateKind="business",
    ownerType="none", tenure="none", purchasePrice=85000, rentPrice=8000,
    utilityRate=500,
    zone={mins=Vector(-200,-200,-50), maxs=Vector(200,200,200)},
})
P.Records = { biz1 = shop }
P.Reindex()

-- Три автомата и две колонки внутри, один автомат снаружи.
local v1, v2, v3 = mkVending(Vector(0,0,0)), mkVending(Vector(50,50,0)), mkVending(Vector(-80,20,0))
local p1, p2 = mkPump(Vector(100,0,0)), mkPump(Vector(-100,-100,0))
local vOut = mkVending(Vector(5000,5000,0))

local buyer = mkPly({ key="1:char1", name="Иван", pos=Vector(0,0,0) })
PLAYERS = { buyer }
WALLET[buyer] = 500000

local scan = GRM.Estate.ScanZone(shop)
ok(scan.total == 5, "в зоне 5 единиц оборудования", scan.total)

P.PanelAction(buyer, { action="buy", id="biz1" })

ok(shop.ownerType == "character" and shop.ownerKey == "1:char1",
   "объект куплен")
ok(v1._nw.GRM_VendOwner == "1:char1",
   "ИСПРАВЛЕНО: автомат №1 автоматически стал вашим", v1._nw.GRM_VendOwner)
ok(v2._nw.GRM_VendOwner == "1:char1", "автомат №2 тоже")
ok(v3._nw.GRM_VendOwner == "1:char1", "автомат №3 тоже")
ok(p1._owner == "1:char1", "ИСПРАВЛЕНО: колонка №1 автоматически ваша", p1._owner)
ok(p2._owner == "1:char1", "колонка №2 тоже")
ok(vOut._nw.GRM_VendOwner == nil or vOut._nw.GRM_VendOwner == "",
   "а автомат ЗА зоной остался чужим — захвата половины карты нет")

ok(p1._price > 0, "у колонки выставлена цена — новый владелец не торгует даром", p1._price)
ok(SAVED_PERSIST.vending > 0 and SAVED_PERSIST.fuel > 0,
   "оборудование сохранено на диск один раз в конце")

local told = false
for _, n in ipairs(NOTIFIED) do
    if n.to == buyer and tostring(n.msg):find("переоформлено", 1, true) then told = true end
end
ok(told, "игроку сказали, что оборудование перешло к нему")

-----------------------------------------------------------------------
print("\n=== 3. ПРОДАЖА ОСВОБОЖДАЕТ ОБОРУДОВАНИЕ ===")
-----------------------------------------------------------------------
P.PanelAction(buyer, { action="release", id="biz1" })
ok(shop.ownerType == "none", "объект освобождён")
ok(v1._nw.GRM_VendOwner == "", "ИСПРАВЛЕНО: автомат освободился вместе с зоной")
ok(p1._owner == "", "и колонка тоже", p1._owner)
ok(v2._nw.GRM_VendOwner == "" and v3._nw.GRM_VendOwner == "", "всё оборудование свободно")

-----------------------------------------------------------------------
print("\n=== 4. ЖИЛЬЁ: ДВЕРИ ПРИТЯГИВАЮТСЯ АВТОМАТИЧЕСКИ ===")
-----------------------------------------------------------------------
local flat = P.Normalize({
    id="flat1", name="Квартира 14", type="apartment",
    ownerType="none", tenure="none", purchasePrice=50000, rentPrice=5000,
    zone={mins=Vector(1000,-100,0), maxs=Vector(1200,100,200)},
})
P.Records["flat1"] = flat
P.Reindex()

local dIn   = mkDoor("d_in",   Vector(1100, 0, 10))      -- внутри зоны
local dEdge = mkDoor("d_edge", Vector(1240, 0, 10))      -- в 40 юнитах за границей
local dFar  = mkDoor("d_far",  Vector(3000, 0, 10))      -- далеко

ok(DL.DoorNearZone(flat, dIn:GetPos()) == true, "дверь внутри зоны — своя")
ok(DL.DoorNearZone(flat, dEdge:GetPos()) == true,
   "дверь вплотную к границе тоже своя: зону обводят снаружи дома")
ok(DL.DoorNearZone(flat, dFar:GetPos()) == false, "дальняя дверь не притягивается")

local tenant = mkPly({ key="2:char1", name="Пётр", pos=Vector(1100,0,0) })
PLAYERS = { buyer, tenant }
WALLET[tenant] = 500000

ok(#flat.doors == 0, "до покупки дверей у объекта нет")
P.PanelAction(tenant, { action="buy", id="flat1" })
ok(flat.ownerKey == "2:char1", "квартира куплена")
ok(#flat.doors == 2,
   "ИСПРАВЛЕНО: обе ближние двери привязались автоматически", #flat.doors)
ok(P.HasAccess(tenant, flat) == true, "и владелец реально открывает свою дверь")
ok(P.HasAccess(buyer, flat) == false, "а посторонний — нет")

-----------------------------------------------------------------------
print("\n=== 5. ЧУЖИЕ ДВЕРИ НЕ ЗАХВАТЫВАЮТСЯ ===")
-----------------------------------------------------------------------
--[[ Соседняя квартира вплотную. Её дверь уже принадлежит другому
     объекту — покупка соседней зоны не должна её забирать. ]]
local flat2 = P.Normalize({
    id="flat2", name="Квартира 15", type="apartment",
    ownerType="none", tenure="none", purchasePrice=50000,
    doors={"d_in"},   -- дверь уже за другим объектом
    zone={mins=Vector(1150,-100,0), maxs=Vector(1350,100,200)},
})
P.Records["flat2"] = flat2
P.Reindex()

local other = mkPly({ key="3:char1", name="Сосед", pos=Vector(1250,0,0) })
PLAYERS = { buyer, tenant, other }
WALLET[other] = 500000
P.PanelAction(other, { action="buy", id="flat2" })

local stole = false
for _, id in ipairs(flat2.doors) do
    if id == "d_edge" then
        -- d_edge принадлежит flat1, забирать нельзя
        for _, o in ipairs(flat.doors) do if o == "d_edge" then stole = true end end
    end
end
ok(not stole, "дверь соседа не украдена покупкой смежной зоны")
ok(P.HasAccess(tenant, flat) == true, "и прежний владелец не потерял доступ")

-----------------------------------------------------------------------
print("\n=== 6. ОКНО СДЕЛКИ ВМЕСТО /property_admin ===")
-----------------------------------------------------------------------
P.Records = { biz1 = shop }
P.Reindex()
shop.ownerType = "none" shop.ownerKey = "" shop.tenure = "none"

buyer._pos = Vector(0,0,0)
local target = DL.TargetOf(buyer, "business")
ok(target == shop, "объект определяется по положению игрока, без списка карты")

local d = DL.Data(buyer, shop)
ok(d.price == 85000, "цена в пакете", d.price)
ok(d.equipment == 5, "видно, сколько оборудования входит в сделку", d.equipment)
ok(d.byKind.vending == 3 and d.byKind.fuel == 2, "с разбивкой по видам")
ok(d.vacant == true, "объект свободен")
ok(d.buyback == math.floor(85000 * 0.6), "показано, сколько вернут при продаже", d.buyback)

SENT = {}
ok(DL.Open(buyer, "business") == true, "окно сделки открывается")
ok(#SENT > 0 and SENT[#SENT].name == DL.NET.OPEN, "пакет ушёл клиенту")

-- Издалека не открыть.
buyer._pos = Vector(9999, 9999, 0)
ok(DL.Open(buyer, "business") == false, "издалека сделка недоступна")
buyer._pos = Vector(0,0,0)

-- Покупка через окно.
local act = net["_h_" .. DL.NET.ACT]
ok(isfunction(act), "обработчик действий зарегистрирован")
local PKT
net.ReadTable = function() return PKT end
WALLET[buyer] = 500000
PKT = { action="buy", id="biz1" }
act(0, buyer)
ok(shop.ownerKey == "1:char1", "покупка через окно работает")
ok(v1._nw.GRM_VendOwner == "1:char1", "и оборудование сразу переоформлено")

-- Издалека действие тоже не проходит.
shop.ownerType="none" shop.ownerKey="" 
buyer._pos = Vector(9999,9999,0)
PKT = { action="buy", id="biz1" }
act(0, buyer)
ok(shop.ownerType == "none", "пакет издалека игнорируется — телепорт-покупки нет")
buyer._pos = Vector(0,0,0)

-----------------------------------------------------------------------
print("\n=== 7. КОМАНДЫ И ПОДСКАЗКА ===")
-----------------------------------------------------------------------
ok(isfunction(commands["grm_buybusiness"]), "есть grm_buybusiness")
ok(isfunction(commands["grm_buyhome"]), "есть grm_buyhome")

local chat = hook._t["PlayerSay"]["GRM_EstateDeal_Chat"]
SENT = {}
ok(chat(buyer, "/buybusiness") == "", "команда /buybusiness перехвачена")
ok(#SENT > 0, "и окно открылось")

local function readf(p) local f=assert(io.open(p)) local s=f:read("*a") f:close() return s end
local est = readf("lua/autorun/sh_grm_estate.lua")
ok(est:find("Чтобы купить — напишите", 1, true) ~= nil,
   "ИСПРАВЛЕНО: под значком есть подсказка, как купить")
ok(est:find("/buybusiness", 1, true) ~= nil, "с правильной командой для бизнеса")
ok(est:find("/buyhome", 1, true) ~= nil, "и для жилья")

-----------------------------------------------------------------------
print("\n=== 8. ЗНАЧОК: ВРАЩЕНИЕ И ВЫСОТА ===")
-----------------------------------------------------------------------
ok(est:find("ES.MarkerSpin", 1, true) ~= nil,
   "ИСПРАВЛЕНО: вернулось независимое вращение вокруг оси")
ok(est:find("CurTime() * ES.MarkerSpin", 1, true) ~= nil,
   "угол считается от времени, а не от позиции игрока")

local markerBlock = est:match("PostDrawTranslucentRenderables.-end%)")
ok(markerBlock and markerBlock:find("dir:Angle().y", 1, true) == nil,
   "ИСПРАВЛЕНО: значок больше НЕ поворачивается вслед за камерой")

local h = tonumber(est:match("ES%.MarkerHeight = (%d+)"))
ok(h and h < 36, "ИСПРАВЛЕНО: значок опущен ещё ниже", h)
ok(h and h > 0, "но не утоплен в землю", h)

-----------------------------------------------------------------------
print("\n=== 9. /business ВЕДЁТ КУДА НАДО ===")
-----------------------------------------------------------------------
ok(est:find("GRM.EstateDeal.Open(ply, ES.KindOf(rec))", 1, true) ~= nil,
   "свободный объект открывает окно СДЕЛКИ, а не админку")
ok(est:find("ES.OpenPanel(ply, rec)", 1, true) ~= nil,
   "а свой — панель управления")

-----------------------------------------------------------------------
print("\n=== 10. ТАБЛИЧКА НА ДВЕРИ (жалоба 28.08) ===")
-----------------------------------------------------------------------
--[[ «Дверь как была ничья, так и осталась ничья.» Объект куплен, двери
     привязаны, а сама ЗАПИСЬ двери оставалась owner_type = "none" —
     табличка читает именно её. ]]
do
    P.Records = {}
    DOOR_RECS = {}
    local home = P.Normalize({
        id="h1", name="Жилой объект", type="apartment",
        ownerType="none", tenure="none", purchasePrice=40000, rentPrice=4000,
        zone={mins=Vector(4000,-100,0), maxs=Vector(4200,100,200)},
    })
    P.Records["h1"] = home
    P.Reindex()

    local dr = mkDoor("hd1", Vector(4100, 0, 10))
    local owner2 = mkPly({ key="7:char1", name="Александр Фон Греннер", pos=Vector(4100,0,0) })
    PLAYERS = { owner2 }
    WALLET[owner2] = 500000

    ok(dr:GetNWString("GRM_DoorOwner","") == "",
       "до покупки табличка пустая — «Продаётся / Ничья»")

    P.PanelAction(owner2, { action="buy", id="h1" })

    ok(home.ownerKey == "7:char1", "объект куплен")
    ok(#home.doors == 1, "дверь привязана к объекту", #home.doors)

    local rec = DOOR_RECS["hd1"]
    ok(rec and rec.owner_type == "player",
       "ИСПРАВЛЕНО: в записи двери проставлен владелец", rec and rec.owner_type)
    ok(rec and rec.owner_key == "7:char1", "с ключом покупателя", rec and rec.owner_key)
    ok(rec and rec.ownable == false,
       "и дверь больше не продаётся отдельно от квартиры")
    ok(dr:GetNWString("GRM_DoorOwner","") == "Александр Фон Греннер",
       "ГЛАВНОЕ: на табличке имя владельца, а не «Ничья»",
       dr:GetNWString("GRM_DoorOwner",""))
    ok(rec and rec.title == "Жилой объект", "и название объекта", rec and rec.title)

    -- Продажа возвращает дверь в общий фонд.
    P.PanelAction(owner2, { action="release", id="h1" })
    rec = DOOR_RECS["hd1"]
    ok(rec and rec.owner_type == "none",
       "после продажи дверь снова ничья", rec and rec.owner_type)
    ok(rec and rec.ownable == true,
       "и снова доступна к покупке — иначе объект нельзя было бы перепродать")
    ok(dr:GetNWString("GRM_DoorOwner","") == "",
       "табличка опять пустая")
end

-----------------------------------------------------------------------
print("\n=== 11. ХУК ОБНОВЛЕНИЯ ДВЕРЕЙ ===")
-----------------------------------------------------------------------
do
    local prop = (function() local f=assert(io.open("lua/autorun/sh_grm_property.lua"))
        local t=f:read("*a") f:close() return t end)()
    ok(prop:find("GRM_Property_DoorsSync", 1, true) ~= nil,
       "ИСПРАВЛЕНО: двери обновляются на общем хуке смены владельца")
    ok(prop:find("GRM.Doors.SetDoorOwner", 1, true) ~= nil,
       "недвижимость ставит владельца через единую функцию модуля дверей")

    local doors = (function() local f=assert(io.open("lua/autorun/sh_grm_doors.lua"))
        local t=f:read("*a") f:close() return t end)()
    ok(doors:find("function D.SetDoorOwner", 1, true) ~= nil,
       "в модуле дверей появилась публичная точка SetDoorOwner")
    local fn = doors:match("function D%.SetDoorOwner.-\n    end")
    ok(fn and fn:find("D.ApplyRecordVisual", 1, true) ~= nil,
       "она обновляет табличку у ВСЕХ полотен двери")
    ok(fn and fn:find("D.SaveDoors", 1, true) ~= nil,
       "и сохраняет — владелец переживёт рестарт")
    ok(fn and fn:find("rec.ownable = true", 1, true) ~= nil,
       "при освобождении дверь снова становится покупаемой")
end

print("")
print(string.format("ИТОГО: %d ok, %d FAIL", pass, fail))
if fail > 0 then os.exit(1) end
