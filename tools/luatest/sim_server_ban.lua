--[[ Живой прогон системы банов: бан НА СЕРВЕРЕ (скелет, белый материал,
     красная подсветка, изъятое оружие, зона отбывания, блокировка меню и
     команд) и ГЛОБАЛЬНЫЙ бан, а также снятие обоих.
     Запуск: ./.luabuild/lj/src/luajit tools/luatest/sim_server_ban.lua ]]
SERVER, CLIENT = true, false
function AddCSLuaFile() end

local NOW = 100
function CurTime() return NOW end
function SysTime() return NOW end
local CLOCK = 1700000000
os.time = function() return CLOCK end
function IsValid(v) return type(v) == "table" and v._valid ~= false end
function istable(v) return type(v) == "table" end
function isstring(v) return type(v) == "string" end
function isfunction(v) return type(v) == "function" end
function isnumber(v) return type(v) == "number" end
function isvector(v) return type(v) == "table" and v._vector == true end
function math.Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function string.Trim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
function string.Explode(sep, str)
    local out = {}
    for part in tostring(str):gmatch("[^" .. sep .. "]+") do out[#out + 1] = part end
    return out
end
function table.Count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
function ErrorNoHalt() end
RENDERMODE_TRANSCOLOR, RENDERMODE_NORMAL, HUD_PRINTCONSOLE = 5, 0, 2
NULL = { _valid = false }

function Vector(x, y, z)
    local v = { x = x or 0, y = y or 0, z = z or 0, _vector = true }
    return setmetatable(v, {
        __add = function(a, b) return Vector(a.x + b.x, a.y + b.y, a.z + b.z) end,
        __sub = function(a, b) return Vector(a.x - b.x, a.y - b.y, a.z - b.z) end,
        __unm = function(a) return Vector(-a.x, -a.y, -a.z) end,
        __tostring = function(a) return ("%d %d %d"):format(a.x, a.y, a.z) end,
        __index = { DistToSqr = function(self, o) return (self.x - o.x) ^ 2 + (self.y - o.y) ^ 2 + (self.z - o.z) ^ 2 end } })
end
function Color(r, g, b, a) return { r = r, g = g, b = b, a = a } end

local hooks = {}
hook = {
    Add = function(n, id, fn) hooks[n] = hooks[n] or {} hooks[n][id] = fn end,
    Remove = function(n, id) if hooks[n] then hooks[n][id] = nil end end,
    Run = function(n, ...)
        for _, fn in pairs(hooks[n] or {}) do local r = fn(...) if r ~= nil then return r end end
    end,
    GetTable = function() return hooks end,
}
local timers = {}
timer = { Create = function(id, _, _, fn) timers[id] = fn end, Simple = function(_, fn) fn() end,
          Remove = function(id) timers[id] = nil end, Exists = function() return false end,
          Adjust = function() return true end }
concommand = { Add = function(name, fn) concommand[name] = fn end }
local FS = {}
file = { IsDir = function() return true end, CreateDir = function() end,
         Write = function(p, s) FS[p] = s end, Read = function(p) return FS[p] end,
         Exists = function(p) return FS[p] ~= nil end }
util = { AddNetworkString = function() end, TableToJSON = function() return "{}" end,
         JSONToTable = function() return {} end, SteamIDFrom64 = function(s) return "STEAM:" .. s end }
net = { Receive = function() end, Start = function() end, WriteString = function() end,
        WriteTable = function() end, Send = function() end, Broadcast = function() end }
game = { GetMap = function() return "rp_test" end, ConsoleCommand = function() end }
CreateConVar = function() return { GetBool = function() return false end, GetInt = function() return 0 end } end
GetConVar = CreateConVar
bit = { bor = function() return 0 end }
FCVAR_ARCHIVE = 1

local ALL = {}
player = { GetAll = function() return ALL end }
ents = { FindByClass = function() return {} end }

GRM = { Identity = {}, Perf = {}, Audit = { Write = function() end } }
GRM.Perf.Players = function() return ALL end
local NOTIFY = {}
GRM.Notify = function(p, text) NOTIFY[#NOTIFY + 1] = tostring(text) end
local ANNOUNCED = {}
GRM.Admin = { Announce = function(text) ANNOUNCED[#ANNOUNCED + 1] = tostring(text) end }

local function mkPlayer(nick, sid, x)
    local p = { _valid = true, nick = nick, sid = sid, nw = {}, chat = {}, pos = Vector(x or 0, 0, 0),
        model = "models/player/group01/male_02.mdl", material = "", weapons = { {} } }
    function p:IsPlayer() return true end
    function p:Nick() return self.nick end
    function p:SteamID64() return self.sid end
    function p:SteamID() return "STEAM_" .. self.sid end
    function p:IsSuperAdmin() return self._super == true end
    function p:GetNWString(k, d) local v = self.nw[k] if v == nil then return d end return v end
    function p:SetNWString(k, v) self.nw[k] = v end
    function p:GetNWBool(k, d) local v = self.nw[k] if v == nil then return d end return v end
    function p:SetNWBool(k, v) self.nw[k] = v end
    function p:GetNWInt(k, d) local v = self.nw[k] if v == nil then return d end return v end
    function p:SetNWInt(k, v) self.nw[k] = v end
    function p:GetModel() return self.model end
    function p:SetModel(v) self.model = v end
    function p:GetMaterial() return self.material end
    function p:SetMaterial(v) self.material = v end
    function p:SetColor(v) self.color = v end
    function p:SetRenderMode(v) self.rendermode = v end
    function p:GetPos() return self.pos end
    function p:SetPos(v) self.pos = v end
    function p:GetVelocity() return Vector(0, 0, 0) end
    function p:SetVelocity() end
    function p:GetWeapons() return self.weapons end
    function p:GetActiveWeapon() return self.weapons[1] or NULL end
    function p:StripWeapons() self.weapons = {} end
    function p:StripAmmo() end
    function p:Spawn() self.spawned = true end
    function p:ChatPrint(m) self.chat[#self.chat + 1] = m end
    ALL[#ALL + 1] = p
    return p
end

assert(loadfile("lua/autorun/sh_grm_ban.lua"))()
local SB = GRM.ServerBan

local fails, total = 0, 0
local function ok(cond, name, extra)
    total = total + 1
    if cond then print("  ok   " .. name)
    else fails = fails + 1 print("  FAIL " .. name .. "  " .. tostring(extra or "")) end
end

local admin = mkPlayer("Шеф", "76561190000000001", 0)
admin._super = true
admin.nw.GRM_RPName = "Александр Фон Грённер"
local target = mkPlayer("Нарушитель", "76561190000000002", 500)

print("\n=== 1. ЗОНА ОТБЫВАНИЯ ===")
ok(SB.CurrentZone() == nil, "по умолчанию точка не задана")
admin.pos = Vector(1000, 1000, 0)
ok(select(1, SB.SetZone(admin, admin:GetPos(), 400)) == true, "суперадмин ставит точку по своей позиции")
local zone = SB.CurrentZone()
ok(zone ~= nil and zone.radius == 400, "радиус сохранён", zone and zone.radius)
SB.SetZone(admin, admin:GetPos(), 99999)
ok(SB.CurrentZone().radius <= 8000, "радиус зажат сверху", SB.CurrentZone().radius)
SB.SetZone(admin, Vector(1000, 1000, 0), 400)

print("\n=== 2. БАН НА СЕРВЕРЕ ===")
NOTIFY, ANNOUNCED = {}, {}
local okBan, msg = SB.Ban(admin, target, 30, "Читы")
ok(okBan == true, "бан выдан", tostring(msg))
ok(SB.IsBanned(target) == true, "игрок числится забаненным")
ok(target.model == "models/player/skeleton.mdl", "модель заменена на скелет", target.model)
ok(target.material == "debugwhite", "материал debugwhite", target.material)
ok(istable(target.color) and target.color.r == 255 and target.color.g == 60, "красная подсветка")
ok(#target.weapons == 0, "оружие изъято", #target.weapons)
ok(target.nw.GRM_ServerBanned == true, "флаг для плашки «ЗАБАНЕН» выставлен")
ok(target.nw.GRM_ServerBanReason == "Читы", "причина висит на игроке")
ok(target.pos:DistToSqr(Vector(1000, 1000, 0)) < 100, "игрок телепортирован в зону отбывания")
ok(#ANNOUNCED > 0 and ANNOUNCED[1]:find("бан на сервере", 1, true) ~= nil,
    "о бане объявлено всем", ANNOUNCED[1])
ok(target.nw.GRM_PreBanModel == "models/player/group01/male_02.mdl",
    "прежняя модель запомнена для возврата")

print("\n=== 3. ОГРАНИЧЕНИЯ ===")
ok(hook.Run("CanPlayerSuicide", target) == false, "самоубийство запрещено")
ok(hook.Run("PlayerCanPickupWeapon", target) == false, "оружие не поднять")
ok(hook.Run("CanPlayerEnterVehicle", target) == false, "в транспорт не сесть")
ok(hook.Run("PlayerNoClip", target) == false, "ноклип запрещён")
ok(hook.Run("PhysgunPickup", target) == false, "физган не работает")
ok(hook.Run("CanTool", target) == false, "тулган не работает")
ok(hook.Run("PlayerUse", target) == false, "использовать предметы нельзя")
ok(hook.Run("ShowSpare2", target) == true, "меню F4 заблокировано")
ok(hook.Run("ShowHelp", target) == true, "меню F1 заблокировано")
ok(hook.Run("EntityTakeDamage", target, { GetAttacker = function() return admin end }) == true,
    "урон по наказанному не проходит")
ok(hook.Run("PlayerSay", target, "/f4") == "", "команды в чате блокируются")
ok(hook.Run("PlayerSay", target, "простое сообщение") == nil, "обычный чат остаётся")
ok(hook.Run("CanPlayerSuicide", admin) == nil, "на свободного игрока ограничения не действуют")

print("\n=== 3б. ЭФИР И ВОЛНЫ (заказ 21.08) ===")
local blocked, text = SB.SpeechBlocked(target, "государственная волна")
ok(blocked == true, "наказанному эфир закрыт")
ok(text:find("административное наказание", 1, true) ~= nil and text:find("деморган", 1, true) ~= nil,
    "текст объясняет причину", text)
ok(text:find("Осталось", 1, true) ~= nil, "и показывает остаток срока", text)
ok(SB.SpeechBlocked(admin, "рация") == false, "свободному игроку эфир открыт")

NOTIFY = {}
ok(SB.DenySpeech(target, "рация фракции") == true, "помощник для модулей отвечает true")
ok(#NOTIFY == 1 and NOTIFY[1]:find("рация фракции", 1, true) ~= nil,
    "и сам пишет игроку, что именно недоступно", NOTIFY[1])
ok(SB.DenySpeech(admin, "рация фракции") == false, "свободного не трогает")

target.chat = {}
NOTIFY = {}
ok(hook.Run("PlayerSay", target, "/dep всем привет") == "", "команда волны перехвачена")
ok(#NOTIFY == 1 and NOTIFY[1]:find("государственная волна", 1, true) ~= nil,
    "в ответе названа именно волна", NOTIFY[1])
NOTIFY = {}
hook.Run("PlayerSay", target, "/fr доклад")
ok(NOTIFY[1]:find("рация фракции", 1, true) ~= nil, "для /fr — рация фракции", NOTIFY[1])
NOTIFY = {}
hook.Run("PlayerSay", target, "/inv")
ok(NOTIFY[1]:find("команды", 1, true) ~= nil, "для прочих команд — общий текст", NOTIFY[1])

print("\n=== 4. ЗОНА ДЕРЖИТ ===")
local watch = timers["GRM_ServerBan_Watch"]
ok(isfunction(watch), "сторож один на всех")
target.pos = Vector(5000, 5000, 0)
watch()
ok(target.pos:DistToSqr(Vector(1000, 1000, 0)) < 100, "вышедшего возвращают в зону")
target.pos = Vector(1100, 1000, 0)
watch()
ok(target.pos.x == 1100, "внутри радиуса ходить можно")

print("\n=== 5. ВИД ДОЖИМАЕТСЯ ===")
target.model = "models/player/group01/male_02.mdl"
target.material = ""
watch()
ok(target.model == "models/player/skeleton.mdl", "чужой модуль вернул модель — сторож вернул скелет")
ok(target.material == "debugwhite", "материал тоже восстановлен")

print("\n=== 6. СРОК ===")
local rec = SB.Bans[target:SteamID64()]
ok(SB.Left(rec) > 0 and SB.Left(rec) <= 30 * 60, "срок посчитан", SB.Left(rec))
CLOCK = CLOCK + 31 * 60
ok(SB.IsBanned(target) == false, "по истечении срока бан снимается")
watch()
ok(target.nw.GRM_ServerBanned == false, "визуал снят автоматически")
ok(target.material == "", "материал очищен")

print("\n=== 7. РУЧНОЕ СНЯТИЕ ===")
SB.Ban(admin, target, 0, "Бессрочно")
ok(SB.Left(SB.Bans[target:SteamID64()]) == math.huge, "бессрочный бан не истекает")
NOTIFY, ANNOUNCED = {}, {}
ok(select(1, SB.Unban(admin, target:SteamID64())) == true, "бан снят вручную")
ok(SB.IsBanned(target) == false, "запись удалена")
ok(target.nw.GRM_ServerBanned == false, "флаг снят")
ok(#ANNOUNCED > 0 and ANNOUNCED[1]:find("снял бан", 1, true) ~= nil, "о снятии объявлено", ANNOUNCED[1])
ok(select(1, SB.Unban(admin, target:SteamID64())) == false, "повторное снятие отвечает честно")

print("\n=== 7б. ПРИЧИНА БАНА ===")
NOTIFY, ANNOUNCED = {}, {}
SB.Ban(admin, target, 15, "  Оскорбление администрации  ")
ok(SB.Bans[target:SteamID64()].reason == "Оскорбление администрации",
    "причина сохраняется как есть, без автозамены", SB.Bans[target:SteamID64()].reason)
ok(target.nw.GRM_ServerBanReason == "Оскорбление администрации", "причина уходит игроку")
ok(ANNOUNCED[1]:find("Оскорбление администрации", 1, true) ~= nil,
    "и попадает в объявление", ANNOUNCED[1])
ok(#NOTIFY > 0 and NOTIFY[1]:find("Оскорбление администрации", 1, true) ~= nil,
    "наказанный видит причину", NOTIFY[1])
local long = string.rep("а", 300)
SB.Unban(admin, target:SteamID64())
SB.Ban(admin, target, 15, long)
ok(#SB.Bans[target:SteamID64()].reason <= 120, "слишком длинная причина обрезается",
    #SB.Bans[target:SteamID64()].reason)
SB.Unban(admin, target:SteamID64())

print("\n=== 7в. СПИСОК И ИСТОРИЯ ===")
SB.Ban(admin, target, 20, "Проверка списка")
local rows = SB.List()
ok(#rows == 1, "в списке один отбывающий", #rows)
ok(rows[1].sid == target:SteamID64(), "в строке SteamID")
ok(rows[1].reason == "Проверка списка", "в строке причина", rows[1].reason)
ok(rows[1].by ~= "", "видно, кто выдал", rows[1].by)
ok(rows[1].left > 0 and rows[1].left <= 20 * 60, "и сколько осталось в секундах", rows[1].left)
ok(rows[1].online == true, "видно, что игрок в сети")
ok(#SB.History >= 1 and SB.History[#SB.History].kind == "ban", "запись попала в историю")
SB.Unban(admin, target:SteamID64())
ok(SB.History[#SB.History].kind == "unban", "снятие тоже пишется в историю")
SB.Ban(admin, target, 0, "Бессрочный")
ok(SB.List()[1].left == -1, "у бессрочного бана в списке -1")
SB.Unban(admin, target:SteamID64())

print("\n=== 8. ХРАНЕНИЕ ===")
SB.Ban(admin, target, 45, "Проверка сохранения")
FS["grm_admin/serverbans.json"] = nil
ok(SB.Bans[target:SteamID64()] ~= nil, "бан в памяти")
SB.Load()
ok(table.Count(SB.Bans) == 0, "битый/пустой файл не роняет модуль")
ok(istable(SB.History), "история переживает перезагрузку структурой")

print(("\nSERVER BAN: %d/%d, провалов: %d"):format(total - fails, total, fails))
if fails > 0 then os.exit(1) end
