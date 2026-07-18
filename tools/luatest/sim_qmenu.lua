-- Симуляция сервера GMod для sh_grm_qmenu.lua (Код 83)
-- Гейты Q/toolgun/спавна, суперадмин-байпас, персист roundtrip,
-- санитизация списков инструментов (карта/массив/мусор).
string.Trim = function(s) s = tostring(s or ""); return (s:gsub("^%s*(.-)%s*$", "%1")) end
local H = { hooks = {}, netrecv = {}, concommands = {}, timers = {} }
local realPrint = print
local function P(...) realPrint("[SIM]", ...) end

_G._SIM = H
SERVER = true
CLIENT = false
function AddCSLuaFile() end
function istable(x) return type(x) == "table" end
function isstring(x) return type(x) == "string" end
function isfunction(x) return type(x) == "function" end
function isnumber(x) return type(x) == "number" end
function IsValid(o) return o ~= nil and o ~= false end
table.Count = function(t) local n = 0 for k in pairs(t or {}) do n = n + 1 end return n end
table.Copy = function(t) local r = {} for k, v in pairs(t or {}) do r[k] = istable(v) and table.Copy(v) or v end return r end

util = { AddNetworkString = function() end }
local savedSnap = nil
util.TableToJSON = function(t) savedSnap = table.Copy(t) return "{}" end
util.JSONToTable = function(txt) if txt == "" then return nil end return table.Copy(savedSnap or {}) end
local written = {}
file = { Read = function(n) return written[n] end,
         Write = function(n, txt) written[n] = txt end,
         Exists = function(n) return written[n] ~= nil end,
         IsDir = function() return true end, CreateDir = function() end }
hook = { Add = function(name, id, fn) H.hooks[name] = H.hooks[name] or {} H.hooks[name][id] = fn end,
         Run = function(name, ...) local fns = H.hooks[name] or {} for id, fn in pairs(fns) do local r = fn(...) if r ~= nil then return r end end end }
timer = { Create = function() end, Simple = function(d, fn) if type(d) == "function" then d() elseif fn then fn() end end, Remove = function() end, Exists = function() return false end }
net = { Start = function() end, WriteString = function() end, WriteTable = function() end, WriteBool = function() end,
        WriteUInt = function() end, Send = function() end, Broadcast = function() end, SendToServer = function() end,
        Receive = function(m, fn) H.netrecv[m] = fn end }
concommand = { Add = function(n, fn) H.concommands[n] = fn end }
player = { GetAll = function() return H.players or {} end }
game = { GetMap = function() return "gm_test" end }
HUD_PRINTCENTER = 4
HUD_PRINTTALK = 3
function CurTime() return 1000 end

GRM = nil
dofile("lua/autorun/sh_grm_qmenu.lua")

local fails = 0
local function ok(cond, label)
    if cond then P("[OK] " .. label)
    else fails = fails + 1 P("[FAIL] " .. label) end
end

local QM = GRM and GRM.QMenu
ok(QM ~= nil and QM.Cfg ~= nil, "модуль Q-меню поднялся")
local cat = QM and QM.ToolCatalog or {}
ok(#cat >= 25, "каталог инструментов наполнен: " .. #cat)

local A = { IsSuperAdmin = function() return true end,  PrintMessage = function(s, c, t) P("SA-MSG: " .. tostring(t)) end }
local B = { IsSuperAdmin = function() return false end, PrintMessage = function(s, c, t) P("PL-MSG: " .. tostring(t)) end }

-- ── 1) дефолты RP-профиля ────────────────────────────────────
ok(QM.Cfg.playersQ == true, "Q по дефолту открыто игрокам")
ok(QM.CanOpenQ(B) == true, "игрок может открыть Q")
ok(QM.CanSpawn(B, "prop") == true, "пропы разрешены игрокам")
ok(QM.CanSpawn(B, "npc") == false, "NPC запрещены игрокам")
ok(QM.CanSpawn(B, "vehicle") == false, "транспорт из Q запрещён")
ok(QM.CanSpawn(B, "swep") == false, "оружие из Q запрещено игрокам")
ok(QM.CanSpawn(A, "npc") == true, "суперадмин: NPC разрешены (байпас)")

-- ── 2) инструменты ───────────────────────────────────────────
local okD, whyD = QM.CanUseTool(B, "dynamite")
ok(okD == false and isstring(whyD), "динамит запрещён игроку: " .. tostring(whyD))
ok(QM.CanUseTool(A, "dynamite") == true, "суперадмин: динамит можно (байпас)")
ok(QM.CanUseTool(B, "weld") == true, "сварка разрешена игроку")
ok(QM.CanUseTool(B, "duplicator") == false, "дубликатор запрещён игроку (дефолт-список)")

-- ── 3) белый режим ───────────────────────────────────────────
QM.Cfg.whitelistMode = true
QM.Cfg.toolAllow = { weld = true }
ok(QM.CanUseTool(B, "weld") == true, "белый режим: сварка (в списке) — можно")
local okP = QM.CanUseTool(B, "paint")
ok(okP == false, "белый режим: краска (вне списка) — нельзя")
ok(QM.CanUseTool(A, "paint") == true, "белый режим: суперадмин вне списка")
QM.Cfg.whitelistMode = false

-- ── 4) переключатели спавна ──────────────────────────────────
QM.Cfg.allowNPCs = true
ok(QM.CanSpawn(B, "npc") == true, "после переключателя NPC разрешены")
QM.Cfg.playersQ = false
ok(QM.CanOpenQ(B) == false, "Q закрыто игрокам")
ok(QM.CanOpenQ(A) == true, "Q открыто суперадмину")
QM.Cfg.playersQ = true
QM.Cfg.allowNPCs = false

-- ── 5) персист roundtrip (jsonT корректен для bool-карт) ─────
QM.Cfg.toolDeny.my_tool = true
ok(QM.Save("сим-тест") == true, "конфиг сохранён")
local savedCount = table.Count(QM.Cfg.toolDeny)
written["grm_qmenu.json"] = util.TableToJSON(QM.Cfg)
QM.Cfg = nil -- «рестарт»
dofile("lua/autorun/sh_grm_qmenu.lua")
QM = GRM.QMenu
ok(QM.Cfg.toolDeny.my_tool == true, "после рестарта my_tool всё ещё запрещён")
ok(table.Count(QM.Cfg.toolDeny) == savedCount, "число запретов совпало: " .. savedCount)
ok(QM.Cfg.playersQ == true, "флаги пережили рестарт")

-- ── 6) хуки движка отвечают ──────────────────────────────────
local canTool = (H.hooks["CanTool"] or {})["GRM_QMenu_CanTool"]
ok(canTool ~= nil, "хук CanTool зарегистрирован")
if canTool then
    ok(canTool(B, nil, "dynamite") == false, "CanTool: динамит → false")
    ok(canTool(B, nil, "weld") == nil, "CanTool: сварка → nil (разрешено движком)")
end
local spawnQ = (H.hooks["PlayerSpawnVehicle"] or {})["GRM_QMenu_Vehicle"]
ok(spawnQ ~= nil and spawnQ(B) == false, "PlayerSpawnVehicle: игроку запрещено")

if fails == 0 then
    P("=== ИТОГ: ВСЕ ПРОВЕРКИ ПРОШЛИ ===")
else
    P("=== ИТОГ: ПРОВАЛОВ: " .. tostring(fails) .. " ===")
    os.exit(1)
end
