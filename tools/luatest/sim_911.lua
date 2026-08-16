-- Симуляция GRM 911 v1.0.0: Downed/кровопотеря, оживление медиком,
-- тело + расследование, вызов /911, права медик/полиция.
string.Trim = function(s) s = tostring(s or ""); return (s:gsub("^%s*(.-)%s*$", "%1")) end
local H = { hooks = {}, netrecv = {}, timers = {} }
local realPrint = print
local function P(...) realPrint("[SIM]", ...) end

function istable(x) return type(x) == "table" end
function isstring(x) return type(x) == "string" end
function isfunction(x) return type(x) == "function" end
function isnumber(x) return type(x) == "number" end
function IsValid(o) return o ~= nil and o ~= false end
table.Count = function(t) local n = 0 for k in pairs(t or {}) do n = n + 1 end return n end

local VMT = {}
VMT.__index = function(self, k)
    if k == "Distance" then return function(s, o) local dx, dy, dz = s.x - o.x, s.y - o.y, s.z - o.z return math.sqrt(dx * dx + dy * dy + dz * dz) end end
    if k == "DistToSqr" then return function(s, o) local dx, dy, dz = s.x - o.x, s.y - o.y, s.z - o.z return dx * dx + dy * dy + dz * dz end end
    return nil
end
function Vector(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, VMT) end
function Angle(p, y, r) return { p = p or 0, y = y or 0, r = r or 0 } end

util = { AddNetworkString = function() end, JSONToTable = function() return nil end, TableToJSON = function() return "{}" end, IsValidModel = function(m) return m ~= "" end }
file = { Read = function() return nil end, Write = function() end, Exists = function() return false end, IsDir = function() return true end, CreateDir = function() end }
hook = { Add = function(name, id, fn) H.hooks[name] = H.hooks[name] or {} H.hooks[name][id] = fn end,
         Run = function(name, ...) local fns = H.hooks[name] or {} for id, fn in pairs(fns) do local r = fn(...) if r ~= nil then return r end end end }
timer = { Create = function(name, d, r, fn) if type(name) == "function" then fn = name end if fn then H.timers[tostring(name)] = fn end end,
          Simple = function(d, fn) if type(d) == "function" then d() elseif fn then fn() end end,
          Remove = function(name) H.timers[tostring(name)] = nil end }
player = { GetAll = function() return H.players or {} end, GetBySteamID = function() return nil end, GetBySteamID64 = function() return nil end }
game = { GetMap = function() return "gm_test" end }
function CurTime() return 1000 end
HUD_PRINTTALK = 3

local corpses = {}
ents = { FindByClass = function(c) if c == "grm_corpse" then return corpses end return {} end,
         Create = function(c)
            if c == "grm_corpse" then
                local ent = { _data = {}, _removed = false, _pos = Vector(0, 0, 0) }
                ent.GetClass = function() return "grm_corpse" end
                ent.GetPos = function() return ent._pos end
                ent.GetAngles = function() return Angle(0, 0, 0) end
                ent.SetPos = function(self, p) self._pos = p end
                ent.SetAngles = function() end
                ent.Spawn = function() end
                ent.Activate = function() end
                ent.Setup = function(self, d) self._data = d end
                ent.GetData = function(self) return self._data end
                ent.SetNWString = function() end ent.SetNWInt = function() end
                ent.GetPhysicsObject = function() return nil end
                ent.Remove = function(self) self._removed = true end
                corpses[#corpses + 1] = ent
                return ent
            end
            return nil
         end }

local netlog = {}
net = { Start = function(m) netlog.cur = { msg = m } end,
        WriteString = function() end, WriteUInt = function() end, WriteInt = function() end,
        WriteBool = function() end, WriteTable = function() end, WriteVector = function() end,
        Send = function(tg) netlog.sent = netlog.sent or {} table.insert(netlog.sent, { msg = netlog.cur and netlog.cur.msg }) netlog.cur = nil end,
        Broadcast = function() end, SendToServer = function() end,
        Receive = function(m, fn) H.netrecv[m] = fn end }
concommand = { Add = function() end }
AddCSLuaFile = function() end

GRM = GRM or {}
GRM.Format = function(n) return tostring(n) .. " GRM" end
GRM.Notify = function(ply, msg, r, g, b) P("NOTIFY[" .. (ply and ply:Nick() or "?") .. "]: " .. tostring(msg)) end

GRM.Identity = {
    CharacterKey = function(ply) return ply:SteamID64() .. ":char1" end,
    FactionMember = function(f, ply) return istable(f) and istable(f.Members) and f.Members[ply:SteamID64()] ~= nil end,
}
GRM.MedicalFull = { IsMedic = function(ply) return GRM.Identity.FactionMember(Factions["Медики"], ply) == true end }
GRM.Medical = { CanTreat = function(ply) return GRM.MedicalFull.IsMedic(ply) end }

Factions = {
    ["Медики"] = { Members = {} },
    ["Полиция Порядка"] = { Members = {} },
    ["Гражданские"] = { Members = {} },
}

local function mkPly(nick, sid, s64, super)
    local p = {
        _hp = 100, _nw = {}, _killed = false,
        SteamID = function() return sid end,
        SteamID64 = function() return s64 end,
        Nick = function() return nick end,
        IsSuperAdmin = function() return super end,
        IsAdmin = function() return super end,
        IsPlayer = function() return true end,
        Alive = function(self) return not self._killed end,
        Health = function(self) return self._hp end,
        SetHealth = function(self, v) self._hp = v end,
        SetRagdolled = function(self, v) self._rag = v end,
        UnRagdoll = function(self) self._rag = false end,
        Freeze = function(self, v) self._frozen = v end,
        Kill = function(self) self._killed = true hook.Run("PlayerDeath", self, nil, nil) end,
        GetPos = function(self) return self._pos or Vector(0, 0, 0) end,
        GetAngles = function() return Angle(0, 0, 0) end,
        GetModel = function() return "models/player/group01/male_01.mdl" end,
        SetNWBool = function(self, k, v) self._nw[k] = v end,
        SetNWString = function(self, k, v) self._nw[k] = v end,
        SetNWInt = function(self, k, v) self._nw[k] = v end,
        GetNWString = function(self, k, d) return self._nw[k] or d or "" end,
        GetNWInt = function(self, k, d) return self._nw[k] or d or 0 end,
        GetNWBool = function(self, k, d) return self._nw[k] or d or false end,
        GetEyeTrace = function() return { Entity = nil } end,
        PrintMessage = function(_, ch, txt) P("CHAT[" .. nick .. "]: " .. tostring(txt)) end,
    }
    return p
end

local victim = mkPly("Жертва", "STEAM_0:2:111", "76000000000000111", false)
local medic = mkPly("Медик", "STEAM_0:2:222", "76000000000000222", false)
local cop = mkPly("Полицейский", "STEAM_0:2:333", "76000000000000333", false)
local civilian = mkPly("Прохожий", "STEAM_0:2:444", "76000000000000444", false)
local admin = mkPly("Админ", "STEAM_0:2:555", "76000000000000555", true)
Factions["Медики"].Members = { [medic:SteamID64()] = true }
Factions["Полиция Порядка"].Members = { [cop:SteamID64()] = true }
Factions["Гражданские"].Members = { [civilian:SteamID64()] = true }
H.players = { victim, medic, cop, civilian, admin }

SERVER = true
CLIENT = false

dofile("lua/autorun/sh_grm_911.lua")
local E = GRM.E911
assert(E, "модуль не поднялся")

local fails = 0
local function CHECK(name, cond)
    if cond then P("OK: " .. name) else fails = fails + 1 P("FAIL: " .. name) end
end

local NOW = 1000000
local vkey = victim:SteamID64() .. ":char1"

-- 1) права
CHECK("медик распознан", E.IsMedic(medic) == true)
CHECK("полицейский распознан", E.IsPolice(cop) == true)
CHECK("полицейский не медик", E.IsMedic(cop) == false)
CHECK("гражданский не медик и не полиция", (not E.IsMedic(civilian)) and (not E.IsPolice(civilian)))
CHECK("суперадмин — медик и полиция", E.IsMedic(admin) and E.IsPolice(admin))

-- 2) Down: падение, HP=1, флаг, отсчёт
local ok = E.Down(victim, cop, nil, 2, NOW)
CHECK("Down сработал", ok == true)
CHECK("Downed: игрок в списке", E.IsDowned(victim) == true)
CHECK("Downed: HP = 1", victim:Health() == 1)
CHECK("Downed: NW-флаг", victim:GetNWBool("GRM_Downed") == true)
CHECK("Downed: bleedoutAt = now + bleedout", E.Downed[vkey].bleedoutAt == NOW + E.Config.bleedout)
CHECK("Downed: причина/рана зафиксированы", E.Downed[vkey].cause ~= nil and E.Downed[vkey].hitgroup == 2)
CHECK("Downed: повторный Down не срабатывает", E.Down(victim, cop, nil, 3, NOW + 1) == false)

-- 3) ScalePlayerDamage: летальный урон → срез до 1 HP
local fresh = mkPly("Свежий", "STEAM_0:2:999", "76000000000000999", false)
fresh._pos = Vector(0, 0, 0)
H.players[#H.players + 1] = fresh
local dmgInfo = {
    GetDamage = function() return 150 end,
    GetAttacker = function() return cop end,
    GetInflictor = function() return { GetClass = function() return "weapon_pistol" end } end,
}
fresh._hp = 100
local scale = hook.Run("ScalePlayerDamage", fresh, 2, dmgInfo)
CHECK("летальный урон срезается (scale<1)", scale ~= nil and scale < 1)
CHECK("летальный урон → Downed", E.IsDowned(fresh) == true)
CHECK("после среза HP остаётся 1", fresh:Health() == 1)
-- нелетальный урон проходит
local fresh2 = mkPly("Целый", "STEAM_0:2:998", "76000000000000998", false)
H.players[#H.players + 1] = fresh2
local dmg2 = { GetDamage = function() return 40 end, GetAttacker = function() return cop end, GetInflictor = function() return nil end }
fresh2._hp = 100
CHECK("нелетальный урон не валит в Downed", hook.Run("ScalePlayerDamage", fresh2, 2, dmg2) == nil and (not E.IsDowned(fresh2)))
-- добить в Downed нельзя
local dmg3 = { GetDamage = function() return 999 end, GetAttacker = function() return cop end, GetInflictor = function() return nil end }
CHECK("в Downed добить нельзя (scale=0)", hook.Run("ScalePlayerDamage", victim, 2, dmg3) == 0)

-- 4) оживление
CHECK("гражданский не может оживлять", E.StartRevive(civilian, victim, NOW) == false)
CHECK("медик начал оживление", E.StartRevive(medic, victim, NOW) == true)
CHECK("оживление: reviver зафиксирован", E.Downed[vkey].reviver == medic)
E.TickRevive(NOW + E.Config.revive)
CHECK("оживление завершено", (not E.IsDowned(victim)))
CHECK("оживление: HP = reviveHp", victim:Health() == E.Config.reviveHp)
CHECK("оживление: NW-флаг снят", victim:GetNWBool("GRM_Downed") == false)

-- 5) кровопотеря до смерти → тело + журнал
local corpsesBefore = #corpses
local incBefore = #E.Incidents
E.Down(victim, cop, { GetClass = function() return "weapon_knife" end }, 2, NOW)
CHECK("Downed снова", E.IsDowned(victim) == true)
E.TickDowned(NOW + E.Config.bleedout)
CHECK("после кровопотери игрок убит", victim._killed == true and (not E.IsDowned(victim)))
CHECK("тело заспавнено", #corpses == corpsesBefore + 1)
CHECK("журнал пополнен", #E.Incidents > incBefore)

-- 6) осмотр тела
local corpse = corpses[#corpses]
corpse._data = { victimName = "Жертва", at = NOW, byName = "Полицейский", cause = "weapon_knife", hitgroup = 2 }
local report = nil
net.Receive("GRM_E911_Examine", function() end) -- клиентский приёмник не нужен
-- ловим отправку: перехватим net.Send
local sentReports = {}
net.Send = function() sentReports[#sentReports + 1] = true end
local oldWriteTable = net.WriteTable
net.WriteTable = function(t) report = t end
E.Examine(cop, corpse)
CHECK("осмотр отдал отчёт", report ~= nil and report.victim == "Жертва")
CHECK("осмотр: полиция может расследовать", report.canInvestigate == true)
CHECK("осмотр зафиксирован в журнале", #E.Incidents > incBefore)

-- 7) /911 вызов
local medNotified = 0
GRM.Notify = function(ply, msg, r, g, b)
    if ply == medic or ply == cop then medNotified = medNotified + 1 end
end
E.Call911(victim)
CHECK("вызов 911 дошёл до экстренных служб", medNotified >= 2)
GRM.Notify = function() end

-- 8) чат-команды
CHECK("chat: /911", E.HandleChat(victim, "/911") == true)
CHECK("chat: /revive медиком", E.HandleChat(medic, "/revive") == true)
CHECK("chat: /examine", E.HandleChat(cop, "/examine") == true)
CHECK("chat: /911cfg суперадмином", E.HandleChat(admin, "/911cfg") == true)
CHECK("chat: /911_set bleedout 180", E.HandleChat(admin, "/911_set bleedout 180") == true)
CHECK("chat: конфиг применён", E.Config.bleedout == 180)
CHECK("chat: чужое не глотается", E.HandleChat(civilian, "/привет") == false)

P("=== ИТОГ: " .. (fails == 0 and "ВСЕ ПРОВЕРКИ ПРОШЛИ" or ("ПРОВАЛОВ: " .. tostring(fails))) .. " ===")
os.exit(fails == 0 and 0 or 1)
