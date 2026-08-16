-- Симуляция v2.2.0: настройка работ — типизированные точки/маршруты + такси
-- (такса, список ТС суперадмина, комиссия в гос.бюджет, пассажирская поездка).
string.Trim = function(s) s = tostring(s or ""); return (s:gsub("^%s*(.-)%s*$", "%1")) end
local H = { hooks = {}, netrecv = {}, concommands = {}, timers = {} }
local realPrint = print
local function P(...) realPrint("[SIM]", ...) end

function istable(x) return type(x) == "table" end
function isstring(x) return type(x) == "string" end
function isfunction(x) return type(x) == "function" end
function isnumber(x) return type(x) == "number" end
function IsValid(o) return o ~= nil and o ~= false end
table.Count = function(t) local n = 0 for k in pairs(t or {}) do n = n + 1 end return n end
table.concat = function(t, sep) local out = "" for i, v in ipairs(t or {}) do if i > 1 then out = out .. sep end out = out .. tostring(v) end return out end

local VMT = {}
VMT.__index = function(self, k)
    if k == "Distance" then return function(s, o) local dx, dy, dz = s.x - o.x, s.y - o.y, s.z - o.z return math.sqrt(dx * dx + dy * dy + dz * dz) end end
    if k == "DistToSqr" then return function(s, o) local dx, dy, dz = s.x - o.x, s.y - o.y, s.z - o.z return dx * dx + dy * dy + dz * dz end end
    return nil
end
function Vector(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, VMT) end
function Angle(p, y, r) return { p = p or 0, y = y or 0, r = r or 0 } end

local stateBudget = 0
util = {
    AddNetworkString = function() end,
    JSONToTable = function() return nil end,
    TableToJSON = function() return "{}" end,
}
file = { Read = function() return nil end, Write = function() end, Exists = function() return false end,
         IsDir = function() return true end, CreateDir = function() end }
hook = { Add = function(name, id, fn) H.hooks[name] = H.hooks[name] or {} H.hooks[name][id] = fn end,
         Run = function(name, ...) local fns = H.hooks[name] or {} for id, fn in pairs(fns) do local r = fn(...) if r ~= nil then return r end end end }
timer = { Create = function(name, d, r, fn) if type(name) == "function" then fn = name end if fn then H.timers[tostring(name)] = fn end end,
          Simple = function(d, fn) if type(d) == "function" then d() elseif fn then fn() end end,
          Remove = function(name) H.timers[tostring(name)] = nil end }
ents = { FindByClass = function(c) return H.entsByClass and H.entsByClass[c] or {} end, Create = function() return nil end }
player = { GetAll = function() return H.players or {} end, GetBySteamID = function() return nil end, GetBySteamID64 = function() return nil end }
game = { GetMap = function() return "gm_test" end }
function CurTime() return 1000 end
HUD_PRINTTALK = 3

local netlog = {}
net = { Start = function(m) netlog.cur = { msg = m } end,
        WriteString = function() end, WriteUInt = function() end, WriteInt = function() end,
        WriteBool = function() end, WriteTable = function() end, WriteVector = function() end,
        Send = function(tg) netlog.sent = netlog.sent or {} table.insert(netlog.sent, { msg = netlog.cur and netlog.cur.msg, to = "P" }) netlog.cur = nil end,
        Broadcast = function() end, SendToServer = function() end,
        Receive = function(m, fn) H.netrecv[m] = fn end }
concommand = { Add = function() end }
AddCSLuaFile = function() end

local function netInject(msg, fields)
    local i = 0
    net.ReadString = function() i = i + 1 return fields[i] end
    net.ReadUInt = function() i = i + 1 return fields[i] end
    net.ReadInt = function() i = i + 1 return fields[i] end
    net.ReadBool = function() i = i + 1 return fields[i] end
    net.ReadTable = function() i = i + 1 return fields[i] end
    local fn = H.netrecv[msg]
    assert(fn, "нет receiver для " .. tostring(msg))
    fn(0, H._curPly)
    return i
end

GRM = GRM or {}
GRM.Format = function(n) return tostring(n) .. " GRM" end
GRM.Notify = function(ply, msg, r, g, b) P("NOTIFY[" .. (ply and ply:Nick() or "?") .. "]: " .. tostring(msg)) end
GRM.GiveMoney = function(ply, amount, reason) ply._bal = (ply._bal or 0) + amount return true end
GRM.TakeMoney = function(ply, amount, reason) if (ply._bal or 0) < amount then return false end ply._bal = ply._bal - amount return true end
GRM.Services = { Charge = function(ply, amount, source, reason)
    if (ply._bal or 0) < amount then return false, "нет средств" end
    ply._bal = ply._bal - amount
    return true
end }
GRM.Economy = { StateAdd = function(delta, reason) stateBudget = stateBudget + delta return stateBudget end }
GRM.Identity = { CharacterKey = function(ply) return ply:SteamID64() .. ":char1" end }

Factions = {}

local taxiVeh
local function mkPly(nick, sid, s64, super)
    local p = {
        _pos = Vector(0, 0, 0), _bal = 1000, _inVeh = false, _veh = nil,
        SteamID = function() return sid end,
        SteamID64 = function() return s64 end,
        Nick = function() return nick end,
        IsSuperAdmin = function() return super end,
        IsAdmin = function() return super end,
        IsPlayer = function() return true end,
        Alive = function() return true end,
        InVehicle = function(self) return self._inVeh == true end,
        GetVehicle = function(self) return self._inVeh and self._veh or nil end,
        ExitVehicle = function(self) self._inVeh = false end,
        GetPos = function(self) return self._pos end,
        GetNWString = function() return "" end,
        PrintMessage = function(_, ch, txt) P("CHAT[" .. nick .. "]: " .. tostring(txt)) end,
        GetEyeTrace = function() return {} end,
    }
    return p
end

local driver = mkPly("Водила", "STEAM_0:2:222", "76000000000000222", false)
local passenger = mkPly("Клиент", "STEAM_0:2:333", "76000000000000333", false)
local admin = mkPly("Админ", "STEAM_0:2:444", "76000000000000444", true)
H.players = { driver, passenger, admin }
taxiVeh = { GetModel = function() return "models/taxi.mdl" end, GetClass = function() return "prop_vehicle_jeep" end, GetDriver = function() return driver end }

local center = { GetPos = function() return Vector(0, 0, 0) end, EntIndex = function() return 7 end, GetClass = function() return "grm_jobcenter" end }
local function depot(x, y, z, jtype, jname)
    return {
        _type = jtype or "generic", _name = jname or "",
        GetPos = function() return Vector(x, y, z) end,
        GetClass = function() return "grm_depot" end,
        GetNWString = function(self, k, d) if k == "GRM_JobType" then return self._type end if k == "GRM_JobName" then return self._name end return d or "" end,
        SetNWString = function(self, k, v) if k == "GRM_JobType" then self._type = v elseif k == "GRM_JobName" then self._name = v end end,
    }
end
H.entsByClass = {
    grm_jobcenter = { center },
    grm_depot = {
        depot(2000, 0, 0, "garbage", "Мусорный контейнер 1"),
        depot(-1500, 500, 0, "garbage", "Мусорный контейнер 2"),
        depot(500, 2000, 0, "dump", "Городская свалка"),
        depot(-800, -1200, 0, "taxi_pickup", "Вокзал"),
        depot(3000, 1500, 0, "taxi_dest", "Аэропорт"),
        depot(100, 100, 0, "courier", "Почтамт"),
    },
}

SERVER = true
CLIENT = false

dofile("lua/autorun/sh_grm_jobs.lua")
local JB = GRM.Jobs
assert(JB, "модуль не поднялся")

local fails = 0
local function CHECK(name, cond)
    if cond then P("OK: " .. name) else fails = fails + 1 P("FAIL: " .. name) end
end

-- 1) типизированные точки → маршруты
JB.OpenMenu(driver, center)
local offers = JB._lastOffers[driver:SteamID64() .. ":char1"].list
local byTpl = {}
for _, o in ipairs(offers) do byTpl[o.tplId] = o end
CHECK("мусоровоз: контейнеры берутся из типа garbage", byTpl.garbage and tostring(byTpl.garbage.pointNames[1]):find("Мусорный") ~= nil)
CHECK("мусоровоз: финальная точка — свалка", byTpl.garbage and byTpl.garbage.pointNames[#byTpl.garbage.points] == "Городская свалка")
CHECK("мусоровоз: 3 точки (2 контейнера + свалка)", byTpl.garbage and #byTpl.garbage.points == 3)
CHECK("такси: посадка = Вокзал, назначение = Аэропорт", byTpl.taxi and byTpl.taxi.target.x == -800 and byTpl.taxi.center.x == 3000)
CHECK("курьер: цель — точка courier (Почтамт)", byTpl.courier and byTpl.courier.target.x == 100)

-- 2) конфиг такси: дефолты
local cfg = JB.TaxiCfg()
CHECK("taxi: allowAny по умолчанию true", cfg.allowAny == true)
CHECK("taxi: границы таксы по умолчанию 100/3000", cfg.fareMin == 100 and cfg.fareMax == 3000)
CHECK("taxi: комиссия по умолчанию 10%", cfg.commission == 10)

-- 3) IsTaxiVehicle
local anyVeh = { GetModel = function() return "models/any.mdl" end, GetClass = function() return "prop_vehicle_jeep" end }
CHECK("taxi: при allowAny любое ТС годится", JB.IsTaxiVehicle(anyVeh) == true)
JB.TaxiCfg().allowAny = false
JB.TaxiCfg().vehicles = { "models/taxi.mdl", "airboat" }
CHECK("taxi: точное совпадение модели", JB.IsTaxiVehicle(taxiVeh) == true)
CHECK("taxi: подстрока класса", JB.IsTaxiVehicle({ GetModel = function() return "models/x.mdl" end, GetClass = function() return "prop_vehicle_airboat" end }) == true)
CHECK("taxi: нет в списке → false", JB.IsTaxiVehicle(anyVeh) == false)
JB.TaxiCfg().allowAny = true
JB.TaxiCfg().vehicles = {}

-- 4) такса: клампинг в границы
driver._inVeh = true driver._veh = taxiVeh
JB.TaxiSetFare(driver, 99999)
local ds = JB.TaxiDriverState(driver:SteamID64() .. ":char1")
CHECK("taxi: такса клампится к максимуму", ds.fare == 3000)
JB.TaxiSetFare(driver, 5)
CHECK("taxi: такса клампится к минимуму", ds.fare == 100)
JB.TaxiSetFare(driver, 500)
CHECK("taxi: такса в границах сохраняется", ds.fare == 500)

-- 5) поездка: посадка пассажира → старт → оплата с комиссией в бюджет
passenger._inVeh = true passenger._veh = taxiVeh
hook.Run("PlayerEnteredVehicle", passenger, taxiVeh, 1)
JB.TaxiStartTrip(driver)
local dstate = JB.TaxiDriverState(driver:SteamID64() .. ":char1")
CHECK("taxi: поездка активна", istable(dstate.trip))
passenger._bal = 1000
driver._bal = 0
local beforeBudget = stateBudget
JB.TaxiCharge(driver, passenger)
local commission = math.floor(500 * 10 / 100) -- 50
CHECK("taxi: пассажир заплатил 500", passenger._bal == 500)
CHECK("taxi: водитель получил 450 (500 − 10%)", driver._bal == 450)
CHECK("taxi: комиссия 50 ушла в гос.бюджет", stateBudget == beforeBudget + commission)
CHECK("taxi: поездка закрыта", dstate.trip == nil)

-- 6) отказ пассажира — без оплаты
JB.TaxiSetFare(driver, 500)
passenger._inVeh = true passenger._veh = taxiVeh
hook.Run("PlayerEnteredVehicle", passenger, taxiVeh, 1)
JB.TaxiStartTrip(driver)
local balBefore = passenger._bal
JB.TaxiRefuse(passenger)
CHECK("taxi: отказ — поездка снята", dstate.trip == nil)
CHECK("taxi: отказ — деньги не списаны", passenger._bal == balBefore)

-- 7) неоплата: поездка закрывается, водитель без денег
passenger._inVeh = true passenger._veh = taxiVeh
hook.Run("PlayerEnteredVehicle", passenger, taxiVeh, 1)
JB.TaxiStartTrip(driver)
passenger._bal = 0
driver._bal = 0
local budgetBefore = stateBudget
JB.TaxiCharge(driver, passenger)
CHECK("taxi: при неоплате водитель не получает", driver._bal == 0)
CHECK("taxi: при неоплате бюджет не пополняется", stateBudget == budgetBefore)
CHECK("taxi: поездка закрыта после неоплаты", dstate.trip == nil)

-- 8) конфиг такси через сеть (суперадмин): клампинг и сохранение
H._curPly = admin
netInject("GRM_Taxi_Cfg", { { allowAny = false, fareMin = 5000, fareMax = 100, commission = 250, vehicles = { "models/a.mdl", " models/b.mdl " } } })
local c2 = JB.TaxiCfg()
CHECK("taxi: cfg allowAny=false применён", c2.allowAny == false)
CHECK("taxi: cfg min>max меняются местами", c2.fareMin == 100 and c2.fareMax == 5000)
CHECK("taxi: cfg комиссия клампится к 100", c2.commission == 100)
CHECK("taxi: cfg список ТС очищен от пустых", #c2.vehicles == 2 and c2.vehicles[2] == "models/b.mdl")
JB.TaxiCfg().allowAny = true

-- 9) чат-команды такси
CHECK("chat: /taxi открывает меню", JB.HandleChat(driver, "/taxi") == true)
CHECK("chat: /taxifare 800 валиден", JB.HandleChat(driver, "/taxifare 800") == true and ds.fare == 800)
CHECK("chat: /taxifare без числа не падает", JB.HandleChat(driver, "/taxifare") == false or true)
CHECK("chat: /taxistart обрабатывается", JB.HandleChat(driver, "/taxistart") == true)
CHECK("chat: /taxistop обрабатывается", JB.HandleChat(driver, "/taxistop") == true)
CHECK("chat: /taxirefuse обрабатывается", JB.HandleChat(driver, "/taxirefuse") == true)
CHECK("chat: /jobdepot_type валиден", JB.HandleChat(admin, "/jobdepot_type garbage") == true)

P("=== ИТОГ: " .. (fails == 0 and "ВСЕ ПРОВЕРКИ ПРОШЛИ" or ("ПРОВАЛОВ: " .. tostring(fails))) .. " ===")
os.exit(fails == 0 and 0 or 1)
