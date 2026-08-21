--[[ Живой прогон защиты пропов (заказ владельца 21.08):
     спам пропами закрывает спавн на минуту, а новый проп появляется
     призраком и становится твёрдым только после заморозки физганом.
     Грузится РЕАЛЬНЫЙ lua/autorun/sh_grm_prop_guard.lua (SERVER=true).
     Запуск: ./.luabuild/lj/src/luajit tools/luatest/sim_prop_guard.lua ]]
local pass, fail = 0, 0
local function ok(v, n, extra)
    if v then pass = pass + 1 print("  ok   " .. n)
    else fail = fail + 1 print("  FAIL " .. n .. "  " .. tostring(extra or "")) end
end

SERVER, CLIENT = true, false
function AddCSLuaFile() end
local NOW = 100
function CurTime() return NOW end
function IsValid(v) return type(v) == "table" and v._valid ~= false end
function istable(v) return type(v) == "table" end
function isstring(v) return type(v) == "string" end
function isnumber(v) return type(v) == "number" end
function isfunction(v) return type(v) == "function" end
function math.Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function table.Count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
function Color(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
function Vector(x, y, z) return { x = x or 0, y = y or 0, z = z or 0 } end
FCVAR_ARCHIVE = 1
COLLISION_GROUP_NONE, COLLISION_GROUP_WORLD = 0, 8
RENDERMODE_NORMAL, RENDERMODE_TRANSALPHA = 0, 4

local HOOKS = {}
hook = {
    Add = function(e, n, fn) HOOKS[e] = HOOKS[e] or {} HOOKS[e][n] = fn end,
    Remove = function() end,
    Run = function(e, ...) for _, fn in pairs(HOOKS[e] or {}) do local r = fn(...) if r ~= nil then return r end end end,
}
timer = { Simple = function(_, fn) if fn then fn() end end, Create = function() end, Remove = function() end }
local CMDS = {}
concommand = { Add = function(n, fn) CMDS[n] = fn end }
util = { AddNetworkString = function() end }
net = { Receive = function() end, Start = function() end, Send = function() end }
local CONVARS = {}
function CreateConVar(name, def)
    local cv = { value = def }
    function cv:GetInt() return math.floor(tonumber(self.value) or 0) end
    function cv:GetBool() return tostring(self.value) ~= "0" end
    function cv:SetValue(v) self.value = v end
    CONVARS[name] = cv
    return cv
end
local PLAYERS = {}
player = { GetAll = function() return PLAYERS end }
ents = { FindByClass = function() return {} end, Create = function() return { _valid = false } end }

local NOTIFY = {}
GRM = {
    Notify = function(ply, text) NOTIFY[#NOTIFY + 1] = tostring(text) end,
    Audit = { Write = function() end },
    Perf = { Players = function() return PLAYERS end },
}

assert(loadfile("lua/autorun/sh_grm_prop_guard.lua"))()
local PG = GRM.PropGuard

local function mkPly(nick, super)
    local p = { _valid = true, chat = "" }
    function p:IsPlayer() return true end
    function p:IsSuperAdmin() return super == true end
    function p:Nick() return nick end
    function p:SteamID64() return nick end
    function p:ChatPrint(t) self.chat = self.chat .. t .. "\n" end
    PLAYERS[#PLAYERS + 1] = p
    return p
end

local function mkProp()
    local e = { _valid = true, _group = COLLISION_GROUP_NONE, _render = RENDERMODE_NORMAL,
                _color = Color(255, 255, 255, 255), _nw = {}, _moveable = true }
    function e:GetClass() return "prop_physics" end
    function e:SetCollisionGroup(g) self._group = g end
    function e:GetCollisionGroup() return self._group end
    function e:SetRenderMode(m) self._render = m end
    function e:GetRenderMode() return self._render end
    function e:SetColor(c) self._color = c end
    function e:GetColor() return self._color end
    function e:SetNWBool(k, v) self._nw[k] = v end
    function e:GetNWBool(k, d) local v = self._nw[k] if v == nil then return d end return v end
    function e:GetPos() return Vector(0, 0, 0) end
    function e:GetPhysicsObject()
        self._phys = self._phys or {
            _valid = true, _move = true,
            IsValid = function() return true end,
            EnableMotion = function(s, on) s._move = on == true end,
            IsMoveable = function(s) return s._move end,
            Wake = function() end,
        }
        return self._phys
    end
    return e
end

local builder = mkPly("Строитель")
local admin = mkPly("Admin", true)

print("\n=== 1. ЧИСТЫЙ УЧЁТ ОКНА ===")
ok(isfunction(PG.Register) and isfunction(PG.Trim), "функции окна объявлены")
local times = {}
local hit
for i = 1, 4 do times, hit = PG.Register(times, 100 + i * 0.1, 8, 5) end
ok(hit == false and #times == 4, "четыре пропа за секунду — ещё не спам", #times)
times, hit = PG.Register(times, 100.5, 8, 5)
ok(hit == true, "пятый в окне — уже спам")
local old = PG.Trim({ 10, 20, 95, 99 }, 100, 8)
ok(#old == 2, "старые записи выпадают из окна", #old)
ok(PG.BlockLeft(160, 100) == 60 and PG.BlockLeft(90, 100) == 0, "остаток блокировки считается честно")

print("\n=== 2. СПАМ ЗАКРЫВАЕТ СПАВН ===")
CONVARS["grm_prop_spam_count"]:SetValue("5")
CONVARS["grm_prop_spam_window"]:SetValue("8")
CONVARS["grm_prop_spam_block"]:SetValue("60")
local guard = HOOKS["PlayerSpawnProp"]["GRM_PropGuard_Limit"]
ok(isfunction(guard), "хук спавна пропа зарегистрирован")

local denied = nil
for i = 1, 4 do denied = guard(builder) end
ok(denied == nil, "первые четыре пропа проходят")
denied = guard(builder)
ok(denied == false, "пятый упирается в лимит и отклоняется")
ok(select(1, PG.IsBlocked(builder)) == true, "игроку закрыт спавн")
ok(select(2, PG.IsBlocked(builder)) == 60, "закрыт ровно на минуту", select(2, PG.IsBlocked(builder)))
NOTIFY = {}
ok(guard(builder) == false, "и дальше спавн не пускает")
ok(table.concat(NOTIFY, " "):find("Спавн закрыт", 1, true) ~= nil, "игроку сказали, почему", NOTIFY[1])

NOW = NOW + 61
ok(select(1, PG.IsBlocked(builder)) == false, "через минуту блокировка спадает")
ok(guard(builder) == nil, "спавн снова работает")

print("\n=== 3. РАГДОЛЛЫ И SENT ПОД ТЕМ ЖЕ ПРАВИЛОМ ===")
ok(isfunction(HOOKS["PlayerSpawnRagdoll"]["GRM_PropGuard_LimitRagdoll"]), "рагдоллы считаются")
ok(isfunction(HOOKS["PlayerSpawnSENT"]["GRM_PropGuard_LimitSENT"]), "SENT считаются")

print("\n=== 4. СУПЕРАДМИН ===")
for i = 1, 10 do guard(admin) end
ok(select(1, PG.IsBlocked(admin)) == false, "по умолчанию суперадмина правило не трогает")
CONVARS["grm_prop_spam_admins"]:SetValue("1")
PG.Unblock(admin)
local blockedAdmin = nil
for i = 1, 6 do blockedAdmin = guard(admin) end
ok(blockedAdmin == false, "с включённым конваром правило действует и на него")
CONVARS["grm_prop_spam_admins"]:SetValue("0")
PG.Unblock(admin)

print("\n=== 5. ПРОП ПОЯВЛЯЕТСЯ ПРИЗРАКОМ ===")
local prop = mkProp()
HOOKS["PlayerSpawnedProp"]["GRM_PropGuard_Ghost"](builder, "models/props/x.mdl", prop)
ok(prop.GRMGhost == true, "проп помечен призраком")
ok(prop:GetCollisionGroup() == COLLISION_GROUP_WORLD, "коллизия с игроками и пропами снята")
ok(prop:GetRenderMode() == RENDERMODE_TRANSALPHA and prop:GetColor().a < 255, "проп полупрозрачный",
   prop:GetColor().a)
ok(prop:GetPhysicsObject():IsMoveable() == false, "физика заморожена — проп не улетает")
ok(prop:GetNWBool("GRM_PropGhost", false) == true, "клиент видит признак призрака")

print("\n=== 6. ЗАМОРОЗКА ДЕЛАЕТ ПРОП НАСТОЯЩИМ ===")
HOOKS["PhysgunFreeze"]["GRM_PropGuard_Freeze"](nil, prop:GetPhysicsObject(), prop, builder)
ok(prop.GRMGhost == nil, "призрак снят")
ok(prop:GetCollisionGroup() == COLLISION_GROUP_NONE, "коллизия вернулась")
ok(prop:GetRenderMode() == RENDERMODE_NORMAL and prop:GetColor().a == 255, "прозрачность убрана")
ok(prop:GetNWBool("GRM_PropGhost", true) == false, "клиенту сообщили, что проп твёрдый")

print("\n=== 7. СНЯЛ С ЗАМОРОЗКИ — СНОВА ПРИЗРАК ===")
HOOKS["PhysgunPickup"]["GRM_PropGuard_Pickup"](builder, prop)
ok(prop.GRMGhost == true, "взял физганом — проп опять призрак, можно двигать сквозь всё")
HOOKS["PhysgunFreeze"]["GRM_PropGuard_Freeze"](nil, prop:GetPhysicsObject(), prop, builder)
ok(prop.GRMGhost == nil, "заморозил — снова твёрдый")

print("\n=== 8. ПРИЗРАК МОЖНО ВЫКЛЮЧИТЬ ===")
CONVARS["grm_prop_ghost"]:SetValue("0")
local plain = mkProp()
HOOKS["PlayerSpawnedProp"]["GRM_PropGuard_Ghost"](builder, "models/props/x.mdl", plain)
ok(plain.GRMGhost == nil, "с выключенным конваром проп появляется обычным")
CONVARS["grm_prop_ghost"]:SetValue("1")

print("\n=== 9. КОМАНДЫ ===")
ok(isfunction(CMDS["grm_prop_unblock"]) and isfunction(CMDS["grm_prop_status"]), "команды объявлены")
PG.Block(builder, 60)
CMDS["grm_prop_unblock"](admin, nil, { "Строитель" })
ok(select(1, PG.IsBlocked(builder)) == false, "суперадмин снимает блокировку")
builder.chat = ""
CMDS["grm_prop_status"](admin)
ok(admin.chat:find("лимит", 1, true) ~= nil, "статус печатает настройки", admin.chat)
local stranger = mkPly("Чужой")
PG.Block(builder, 60)
CMDS["grm_prop_unblock"](stranger, nil, { "Строитель" })
ok(select(1, PG.IsBlocked(builder)) == true, "обычный игрок блокировку не снимает")

print(("\nPROP GUARD: %d/%d, провалов: %d"):format(pass, pass + fail, fail))
if fail > 0 then os.exit(1) end
