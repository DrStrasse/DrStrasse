-- Симуляция сервера GMod для Диллера 2.0 + C-меню транспорта (Код 82)
-- Загружает НАСТОЯЩИЕ sh_grm_currency.lua, sent_vehicle_dealer/init.lua,
-- sh_grm_ctx.lua и прогоняет: покупку с оплатой, фракционный бесплатный,
-- отказ при нехватке, удаление с возвратом 50%, «Мои Т/С», C-меню (замок/
-- багажник/убрать). VK подменён минимальным стабом.
string.Trim = function(s) s = tostring(s or ""); return (s:gsub("^%s*(.-)%s*$", "%1")) end
string.lower = string.lower
local H = { hooks = {}, netrecv = {}, concommands = {}, timers = {} }
local realPrint = print
local function P(...) realPrint("[SIM]", ...) end

_G._SIM = H
SERVER = true
CLIENT = false
function AddCSLuaFile() end
function include(f) if f == "shared.lua" then return end dofile(f) end
FCVAR_ARCHIVE = 128
local cvars = {}
function CreateConVar(name, def) cvars[name] = { def = def } return cvars[name] end
function GetConVar(name)
    local c = cvars[name] or { def = "0" }
    return { GetBool = function() return c.def == "1" or c.def == "true" end,
             GetInt = function() return tonumber(c.def) or 0 end,
             GetString = function() return tostring(c.def) end,
             GetFloat = function() return tonumber(c.def) or 0 end }
end
function istable(x) return type(x) == "table" end
function isstring(x) return type(x) == "string" end
function isfunction(x) return type(x) == "function" end
function isnumber(x) return type(x) == "number" end
function IsValid(o) return o ~= nil and o ~= false and o.removed ~= true end
table.Count = function(t) local n = 0 for k in pairs(t or {}) do n = n + 1 end return n end
table.Copy = function(t) local r = {} for k, v in pairs(t or {}) do r[k] = istable(v) and table.Copy(v) or v end return r end

local VMT = {}
VMT.__index = function(self, k)
    if k == "DistToSqr" then return function(s, o) local dx, dy, dz = s.x - o.x, s.y - o.y, s.z - o.z return dx * dx + dy * dy + dz * dz end end
    if k == "Distance" then return function(s, o) local dx, dy, dz = s.x - o.x, s.y - o.y, s.z - o.z return math.sqrt(dx * dx + dy * dy + dz * dz) end end
    if k == "Length" then return function(s) return math.sqrt(s.x * s.x + s.y * s.y + s.z * s.z) end end
    return nil
end
VMT.__add = function(a, b) return Vector(a.x + b.x, a.y + b.y, a.z + b.z) end
VMT.__sub = function(a, b) return Vector(a.x - b.x, a.y - b.y, a.z - b.z) end
VMT.__mul = function(a, b)
    if isnumber(a) then return Vector(a * b.x, a * b.y, a * b.z) end
    return Vector(a.x * b, a.y * b, a.z * b)
end
VMT.__unm = function(a) return Vector(-a.x, -a.y, -a.z) end
function Vector(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, VMT) end
function Angle(p, y, r) return { p = p or 0, y = y or 0, r = r or 0 } end
function math.Clamp(v, mn, mx) v = tonumber(v) or 0 if v < mn then return mn end if v > mx then return mx end return v end

-- JSON-диск: TableToJSON → snapshot, JSONToTable → копия (как jsonT 65)
local snaps = {}
util = { AddNetworkString = function() end, IsValidModel = function() return true end }
util.TableToJSON = function(t) snaps["__last"] = table.Copy(t) return "json" end
util.JSONToTable = function(txt, a, b)
    if txt == nil or txt == "" then return nil end
    return table.Copy(snaps["__last"] or {})
end
local written = {}
file = { Read = function(n) return written[n] end,
         Write = function(n, txt) written[n] = txt end,
         Exists = function(n) return written[n] ~= nil end,
         IsDir = function() return true end, CreateDir = function() end,
         Find = function() return {} end, Delete = function(n) written[n] = nil end,
         Append = function() end }
hook = { Add = function(name, id, fn) H.hooks[name] = H.hooks[name] or {} H.hooks[name][id] = fn end,
         Run = function(name, ...) local fns = H.hooks[name] or {} for id, fn in pairs(fns) do local r = fn(...) if r ~= nil then return r end end end }
timer = { Create = function() end, Simple = function(d, fn) if type(d) == "function" then d() elseif fn then fn() end end, Remove = function() end, Exists = function() return false end }
util.TraceLine = function(t) return { Hit = true, HitPos = t.endpos or Vector(0, 0, 0), Entity = nil } end

-- net с журналом (для проверки VD_MyList / результатов)
local netsent = {}
local curFrame = nil
net = { Start = function(m) curFrame = { msg = m, tableV = nil } end,
        WriteString = function() end, WriteBool = function() end, WriteUInt = function() end,
        WriteInt = function() end, WriteFloat = function() end, WriteVector = function() end, WriteBit = function() end,
        WriteEntity = function() end, WriteTable = function(t) if curFrame then curFrame.tableV = t end end,
        Send = function() netsent[#netsent + 1] = curFrame curFrame = nil end,
        Broadcast = function() curFrame = nil end, SendToServer = function() end,
        Receive = function(m, fn) H.netrecv[m] = fn end }
concommand = { Add = function(n, fn) H.concommands[n] = fn end }
player = { GetAll = function() return H.players or {} end, GetBySteamID64 = function() return nil end, GetBySteamID = function() return nil end }
game = { GetMap = function() return "gm_test" end }
HUD_PRINTTALK = 3
HUD_PRINTCENTER = 4
MASK_ALL = 1
function CurTime() return 1000 end
function SysTime() return 1000 end

-- ── игроки ───────────────────────────────────────────────────
local PMT = {}
PMT.__index = function(t, k)
    if k:match("^SetNW") or k:match("^GetNW") then
        return function(s, key, val)
            if k:match("^Set") then s.nw = s.nw or {} s.nw[key] = val return end
            local v = s.nw and s.nw[key]
            if v == nil then if k:match("Int$") or k:match("Float$") then return 0 elseif k:match("Bool$") then return false end return "" end
            return v
        end
    end
    if k == "SteamID" then return function(s) return s.sid end
    elseif k == "SteamID64" then return function(s) return s.s64 end
    elseif k == "IsPlayer" then return function() return true end
    elseif k == "IsBot" then return function() return false end
    elseif k == "IsSuperAdmin" then return function(s) return s.super == true end
    elseif k == "Nick" then return function(s) return s.nick end
    elseif k == "GetPos" then return function(s) return s.pos end
    elseif k == "EyePos" then return function(s) return s.pos end
    elseif k == "GetAimVector" then return function(s) return s.aim or Vector(1, 0, 0) end
    elseif k == "GetForward" then return function(s) return s.aim or Vector(1, 0, 0) end
    elseif k == "ChatPrint" then return function(s, t) P(("CHAT[%s]: %s"):format(s.nick, tostring(t))) end
    elseif k == "PrintMessage" then return function(s, c, t) P(("MSG[%s]: %s"):format(s.nick, tostring(t))) end
    end
    return nil
end
local function mkPly(nick, s64, super)
    local p = setmetatable({ nick = nick, s64 = s64, sid = "STEAM_0:1:" .. s64:sub(-3), super = super, pos = Vector(0, 0, 0) }, PMT)
    return p
end
local Pete = mkPly("Пётр", "76561198000000011", false)
local Boss = mkPly("Шеф", "76561198000000012", true)

-- ── транспорт / дилер: фабрика энтити-стабов ─────────────────
local entSeq = 100
local EMT = {}
EMT.__index = function(t, k)
    if k:match("^SetNW") or k:match("^GetNW") then
        return function(s, key, val)
            if k:match("^Set") then s.nw[key] = val return end
            local v = s.nw[key]
            if v == nil then if k:match("Int$") then return 0 elseif k:match("Bool$") then return false elseif k:match("Vector$") then return Vector(0,0,0) elseif k:match("Angle$") then return Angle(0,0,0) end return "" end
            return v
        end
    end
    if k == "EntIndex" then return function(s) return s.idx end
    elseif k == "GetClass" then return function(s) return s.class end
    elseif k == "SetPos" then return function(s, v) s.pos = v end
    elseif k == "GetPos" then return function(s) return s.pos end
    elseif k == "SetAngles" then return function(s, a) s.ang = a end
    elseif k == "GetAngles" then return function(s) return s.ang end
    elseif k == "SetModel" then return function(s, m) s.model = m end
    elseif k == "SetKeyValue" then return function() end
    elseif k == "Spawn" then return function(s) s.spawned = true end
    elseif k == "Activate" then return function() end
    elseif k == "Remove" then return function(s) s.removed = true end
    elseif k == "EmitSound" then return function() end
    elseif k == "GetForward" then return function() return Vector(1, 0, 0) end
    elseif k == "SetDealerID" then return function(s, v) s.nw.DealerID = v end
    elseif k == "GetDealerID" then return function(s) return s.nw.DealerID or "" end
    elseif k == "SetDealerName" then return function(s, v) s.nw.DealerName = v end
    elseif k == "GetDealerName" then return function(s) return s.nw.DealerName or "" end
    elseif k == "GetHasCustomSpawn" then return function() return false end
    end
    return nil
end
local function mkEnt(class)
    entSeq = entSeq + 1
    return setmetatable({ class = class, idx = entSeq, nw = {}, pos = Vector(0, 0, 0), ang = Angle(0, 0, 0) }, EMT)
end
ents = { Create = function(c) return mkEnt(c) end, FindByClass = function() return {} end, FindInSphere = function() return {} end }
function Entity(i) return nil end

-- списки транспорта GMod-стиля
list = { Get = function(what)
    if what == "Vehicles" then
        return { jalopy = { Name = "Джалопи", Class = "prop_vehicle_jeep", Model = "models/vehicle.mdl", KeyValues = { vehiclescript = "scripts/vehicles/jalopy.txt" } } }
    end
    return {}
end }

-- стаб VK (ключи): владение + синк + прицел
VK = {
    OWNER_TYPE = { PLAYER = "player", FACTION = "faction" },
    IsVehicle = function(ent) return IsValid(ent) and ent.class == "prop_vehicle_jeep" end,
    GetAimedVehicle = function(ply) return ply.aimEnt end,
    CanInteract = function(veh, ply, ownerLevel)
        if ply:IsSuperAdmin() then return true end
        if ownerLevel then return veh.VK_OwnerSteam == ply:SteamID() end
        return veh.VK_OwnerSteam == ply:SteamID()
    end,
    SyncVehicle = function(veh) veh._synced = (veh._synced or 0) + 1 end,
    GetVehicleDisplayName = function(veh) return "Джалопи" end,
    SetPlayerOwner = function(veh, ply)
        veh.VK_OwnerType = "player" veh.VK_OwnerSteam = ply:SteamID() veh.VK_Locked = true VK.SyncVehicle(veh)
        return true
    end,
    SetFactionOwner = function(veh, fac)
        veh.VK_OwnerType = "faction" veh.VK_FactionName = fac veh.VK_Locked = true VK.SyncVehicle(veh)
        return true
    end,
}

-- багажник-стаб: считаем делегированные вызовы
local trunkCalls = 0
GRM_TrunkStubCalls = function() return trunkCalls end

Factions = {
    ["ОПГ"] = { Leader = Boss:SteamID(), Members = { [Boss:SteamID()] = true } },
}
H.players = { Pete, Boss }

-- ── деньги (реальный модуль) ─────────────────────────────────
dofile("lua/autorun/sh_grm_currency.lua")
assert(GRM and GRM.GetBalance, "currency dead")
for _, p in ipairs(H.players) do
    local f = (H.hooks["PlayerInitialSpawn"] or {})["GRM_Currency_Init"]
    if f then f(p) end
    local t = H.timers["GRM_Currency_FirstSync_" .. p:SteamID64()]
    if t then t() end
end

GRM.Trunk = { RequestToggle = function(ply) trunkCalls = trunkCalls + 1 end }

-- ── дилер (реальный init.lua) ────────────────────────────────
-- В файле ровно один GLua-токен `continue` (LuaJIT его не знает):
-- трансформируем в goto/label — семантика 1:1.
ENT = {}
do
    local fh = assert(io.open("lua/entities/sent_vehicle_dealer/init.lua", "r"))
    local src = fh:read("*a") fh:close()
    local n1; src, n1 = src:gsub("\n%s-continue\n", "\n            goto vd_skip\n")
    assert(n1 == 1, "ожидался ровно один continue в init.lua диллера (было " .. n1 .. ")")
    local n2; src, n2 = src:gsub("(\n    end\nend%)\n\nhook%.Add%(\"ShutDown\")", "\n    ::vd_skip::\nend\nend)\n\nhook.Add(\"ShutDown\"")
    assert(n2 == 1, "якорь цикла восстановления дилеров не найден")
    assert(load(src, "dealer_init"))()
end

local dealer = mkEnt("sent_vehicle_dealer")
dealer.nw.DealerID = "d1"
dealer.nw.DealerName = "Центральный дилер"
dealer.VD_ID = "d1"
dealer.VD_Name = "Центральный дилер"
dealer.VD_Vehicles = {
    __global = { { class = "jalopy", name = "Джалопи", price = 400 } },
    ["ОПГ"]  = { { class = "jalopy", name = "Джалопи служеб.", price = 0 } },
}
dealer.pos = Vector(10, 0, 0)
VehicleDealers["d1"] = dealer

-- ── ctx (реальный sh_grm_ctx.lua) ────────────────────────────
dofile("lua/autorun/sh_grm_ctx.lua")

local fails = 0
local function ok(cond, label)
    if cond then P("[OK] " .. label)
    else fails = fails + 1 P("[FAIL] " .. label) end
end

local function lastNet(msg)
    for i = #netsent, 1, -1 do if netsent[i].msg == msg then return netsent[i] end end
    return nil
end
local function frameFor(recv, ...)
    local r = H.netrecv[recv]
    if r then r(0, ...) end
end

-- эмуляция net-кадров C→S (Read-последовательности)
local seqVals = {}
net.ReadString = function() local v = table.remove(seqVals, 1) return tostring(v or "") end
net.ReadEntity = function() local v = table.remove(seqVals, 1) return v end

-- ── 1) покупка: цена списывается, машина в собственность ─────
local bal0 = GRM.GetBalance(Pete)
seqVals = { "d1", "jalopy" }
if H.netrecv["VD_SpawnRequest"] then H.netrecv["VD_SpawnRequest"](0, Pete) end

local vd = nil
for id, e in pairs(VD_AllVehicles) do if IsValid(e) then vd = e end end
ok(vd ~= nil, "машина заспавнена и зарегистрирована в VD_AllVehicles")
ok(GRM.GetBalance(Pete) == bal0 - 400, "списано 400: баланс " .. GRM.GetBalance(Pete))
ok(vd ~= nil and vd.VD_Price == 400, "VD_Price записан (400) — база возврата")
ok(vd ~= nil and vd.VD_Owner == Pete, "VD_Owner = Пётр")
ok(vd ~= nil and vd.VK_OwnerSteam == Pete:SteamID(), "VK-владение выдано (ключи)")
ok(vd ~= nil and vd.VK_Locked == true, "машина закрыта по умолчанию (VK)")
local mylist = lastNet("VD_MyList")
ok(mylist ~= nil and istable(mylist.tableV) and #mylist.tableV == 1, "«Мои Т/С»: 1 строка ушла владельцу")
ok(mylist ~= nil and mylist.tableV[1].refund == 200, "возврат посчитан 50%: " .. tostring(mylist and mylist.tableV[1].refund))

-- ── 2) удаление через запрос: возврат 50% ────────────────────
seqVals = { vd }
if H.netrecv["VD_RemoveRequest"] then H.netrecv["VD_RemoveRequest"](0, Pete) end
ok(vd.removed == true, "машина удалена")
ok(GRM.GetBalance(Pete) == bal0 - 200, "возвращено 50% (200): баланс " .. GRM.GetBalance(Pete))
ok(table.Count(VD_AllVehicles) == 0, "VD_AllVehicles очищен")

-- ── 3) фракционный транспорт (Шеф в ОПГ) — бесплатно ─────────
local balB0 = GRM.GetBalance(Boss)
seqVals = { "d1", "jalopy" }
if H.netrecv["VD_SpawnRequest"] then H.netrecv["VD_SpawnRequest"](0, Boss) end
local vd2 = nil
for id, e in pairs(VD_AllVehicles) do if IsValid(e) and e.VD_Owner == Boss then vd2 = e end end
ok(vd2 ~= nil, "фракционная машина Шефа заспавнена")
ok(GRM.GetBalance(Boss) == balB0, "фракционный — без списания (служебный)")
ok(vd2 and vd2.VD_Price == 0, "VD_Price = 0 у служебной")
ok(vd2 and vd2.VK_OwnerType == "faction" and vd2.VK_FactionName == "ОПГ", "VK-владение = фракция ОПГ")
-- Шеф убирает служебную себе через /vd_remove (бесплатную → возврата нет)
local chatSay0 = (H.hooks["PlayerSay"] or {})["VD_ChatCommands"]
if chatSay0 then chatSay0(Boss, "/vd_remove") end
ok(vd2.removed == true, "/vd_remove: служебная Шефа убрана")

-- ── 4) отказ: Пётр при 100 наличных (цена 400) ───────────────
GRM.SetBalance(Pete, 100)
seqVals = { "d1", "jalopy" }
if H.netrecv["VD_SpawnRequest"] then H.netrecv["VD_SpawnRequest"](0, Pete) end
ok(GRM.GetBalance(Pete) == 100, "при нехватке денег баланс не тронут")
local peteCars = 0
for id, e in pairs(VD_AllVehicles) do if IsValid(e) and e.VD_Owner == Pete then peteCars = peteCars + 1 end end
ok(peteCars == 0, "при нехватке денег машина НЕ создана")

-- ── 5) /vd_remove с возвратом 50% (Пётр купил за 400) ────────
GRM.SetBalance(Pete, 1000)
seqVals = { "d1", "jalopy" }
if H.netrecv["VD_SpawnRequest"] then H.netrecv["VD_SpawnRequest"](0, Pete) end
ok(GRM.GetBalance(Pete) == 600, "Пётр купил за 400 → 600")
local chatSay = (H.hooks["PlayerSay"] or {})["VD_ChatCommands"]
ok(chatSay ~= nil, "чат-хук диллера на месте")
if chatSay then chatSay(Pete, "/vd_remove") end
ok(GRM.GetBalance(Pete) == 800, "/vd_remove: возвращено 50% → 800")
ok(table.Count(VD_AllVehicles) == 0, "/vd_remove убрал машины Петра")

-- ═══ C-МЕНЮ ТРАНСПОРТА (Код 82, sh_grm_ctx) ═══
GRM.SetBalance(Pete, 1000)
seqVals = { "d1", "jalopy" }
if H.netrecv["VD_SpawnRequest"] then H.netrecv["VD_SpawnRequest"](0, Pete) end
local vd3 = nil
for id, e in pairs(VD_AllVehicles) do if IsValid(e) and e.VD_Owner == Pete then vd3 = e end end
ok(vd3 ~= nil, "машина для C-меню заспавнена")

-- 6) инфо-пакет: смотрим на свою машину
Pete.aimEnt = vd3
net.ReadEntity = function() return nil end
local ctxRecv = H.netrecv["GRM_Ctx_Check"]
ok(ctxRecv ~= nil, "GRM_Ctx_Check receiver жив")
if ctxRecv then ctxRecv(0, Pete) end
local ctxRes = lastNet("GRM_Ctx_Result")
ok(ctxRes ~= nil and istable(ctxRes.tableV) and istable(ctxRes.tableV.veh), "ctx: veh-блок пришёл")
ok(ctxRes ~= nil and ctxRes.tableV.veh.canManage == true, "ctx: canManage=true (владелец)")
ok(ctxRes ~= nil and ctxRes.tableV.veh.canRemove == true, "ctx: canRemove=true (моё дилерское)")
ok(ctxRes ~= nil and ctxRes.tableV.veh.locked == true, "ctx: locked=true")

-- 7) C: замок toggle
seqVals = { "lock" }
if H.netrecv["GRM_Ctx_VehAct"] then H.netrecv["GRM_Ctx_VehAct"](0, Pete) end
ok(vd3.VK_Locked == false, "C-меню «Замок»: машина открыта")
seqVals = { "lock" }
if H.netrecv["GRM_Ctx_VehAct"] then H.netrecv["GRM_Ctx_VehAct"](0, Pete) end
ok(vd3.VK_Locked == true, "C-меню «Замок»: машина закрыта обратно")

-- 8) C: багажник делегирован
local t0 = trunkCalls
seqVals = { "trunk" }
if H.netrecv["GRM_Ctx_VehAct"] then H.netrecv["GRM_Ctx_VehAct"](0, Pete) end
ok(trunkCalls == t0 + 1, "C-меню «Багажник» → GRM.Trunk.RequestToggle")

-- 9) C: убрать чужую машину ПЁТРУ нельзя (он не владелец). Шеф получает свою (фракционную).
seqVals = { "d1", "jalopy" }
if H.netrecv["VD_SpawnRequest"] then H.netrecv["VD_SpawnRequest"](0, Boss) end
local vdBoss = nil
for id, e in pairs(VD_AllVehicles) do if IsValid(e) and e.VD_Owner == Boss then vdBoss = e end end
-- Пётр смотрит на машину Шефа и жмёт «Убрать» → отказ (не владелец, не админ)
Pete.aimEnt = vdBoss
seqVals = { "remove" }
if H.netrecv["GRM_Ctx_VehAct"] then H.netrecv["GRM_Ctx_VehAct"](0, Pete) end
ok(vdBoss ~= nil and vdBoss.removed ~= true, "C-меню: чужую машину Пётр убрать НЕ может")
-- Шеф (суперадмин) убирает машину Петра — можно; возврат владельцу НЕ идёт (админ-действие)
Boss.aimEnt = vd3
seqVals = { "remove" }
if H.netrecv["GRM_Ctx_VehAct"] then H.netrecv["GRM_Ctx_VehAct"](0, Boss) end
ok(vd3.removed == true, "C-меню: суперадмин убрал чужую дилерскую машину")
ok(GRM.GetBalance(Pete) == 600, "при админском удалении возврата владельцу нет (600 как было)")

if fails == 0 then
    P("=== ИТОГ: ВСЕ ПРОВЕРКИ ПРОШЛИ ===")
else
    P("=== ИТОГ: ПРОВАЛОВ: " .. tostring(fails) .. " ===")
    os.exit(1)
end
