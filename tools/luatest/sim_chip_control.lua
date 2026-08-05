-- sim_chip_control.lua — проверка системы контроля чипов (находка 169):
--   • реестр носителей (ListCarriers: онлайн + офлайн);
--   • HasExperimental (только имплантированные experimental);
--   • PlayerDeath: уведомление членам фракций с ChipDeathAlert (звук+текст
--     через net), temp GPS-маркер minimap, журнал событий;
--   • во вкладке «Расширенные настройки» /factions есть action
--     setChipDeathAlert и чекбокс.
local pass, fail = 0, 0
local function ok(v, n) if v then pass = pass + 1 print("  ok  " .. n) else fail = fail + 1 print("  FAIL " .. n) end end

SERVER, CLIENT = true, false
function AddCSLuaFile() end
function isstring(v) return type(v) == "string" end
function istable(v) return type(v) == "table" end
function IsValid(v) return v ~= nil and (type(v) == "table" and v.__valid ~= false or type(v) == "userdata") end
function CurTime() return 1000 end
function SysTime() return 1000 end
function os.time() return 1700000000 end
function math.random() return 1 end
function table.Count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
function table.HasValue(t, v) for _, x in pairs(t or {}) do if x == v then return true end end return false end
math.Clamp = math.Clamp or function(v, a, b) return math.max(a, math.min(b, v)) end
function print(...) local a = {} for i = 1, select("#", ...) do a[i] = tostring(select(i, ...)) end io.write(table.concat(a, " "), "\n") end
string.Trim = string.Trim or function(s) return tostring(s or ""):match("^%s*(.-)%s*$") end

local H = { hooks = {}, netrecv = {}, netlog = {}, seq = {} }
hook = { Add = function(n, id, fn) H.hooks[n] = H.hooks[n] or {} H.hooks[n][id] = fn end, Run = function() end }
timer = { Create = function() end, Simple = function(_, fn) if fn then fn() end end, Remove = function() end }
concommand = { Add = function() end }
util = {
  AddNetworkString = function() end, CRC = function(s) return tostring(#s) end,
  TableToJSON = function() return "{}" end, JSONToTable = function() return nil end,
  IsValidModel = function() return true end, SteamIDTo64 = function(s) return "7656" .. tostring(#s) end,
}
net = {
  Start = function(m) H.netlog.cur = { msg = m, f = {} } end,
  WriteString = function(v) table.insert(H.netlog.cur.f, tostring(v or "")) end,
  WriteTable = function(v) table.insert(H.netlog.cur.f, v or {}) end,
  WriteVector = function(v) table.insert(H.netlog.cur.f, v or {}) end,
  WriteEntity = function() end, WriteUInt = function() end, WriteBool = function() end,
  Send = function() H.netlog[#H.netlog + 1] = H.netlog.cur H.netlog.cur = nil end,
  Broadcast = function() H.netlog[#H.netlog + 1] = H.netlog.cur H.netlog.cur = nil end,
  Receive = function(m, fn) H.netrecv[m] = fn end,
  ReadString = function() return tostring(table.remove(H.seq, 1) or "") end,
  ReadTable = function() return table.remove(H.seq, 1) or {} end,
  ReadVector = function() return table.remove(H.seq, 1) or { x = 0, y = 0, z = 0 } end,
  ReadUInt = function() return tonumber(table.remove(H.seq, 1) or 0) end,
}
local function netCount(msg)
  local n = 0 for _, e in ipairs(H.netlog) do if e.msg == msg then n = n + 1 end end return n
end
game = { GetMap = function() return "gm_test" end }
ents = { GetAll = function() return {} end }

local __files = {}
file = {
  CreateDir = function() end, Exists = function(p) return __files[p] ~= nil end,
  Read = function(p) return __files[p] end, Write = function(p, s) __files[p] = s end, Find = function() return {} end,
}

-- ── игрок ──
local PMT = {}
PMT.__index = function(t, k)
  if k == "SteamID" then return function(s) return s.sid end
  elseif k == "SteamID64" then return function(s) return s.s64 end
  elseif k == "Nick" then return function(s) return s.nick end
  elseif k == "IsPlayer" then return function() return true end
  elseif k == "IsSuperAdmin" then return function() return false end
  elseif k == "GetPos" then return function(s) return s.pos or { x = 0, y = 0, z = 0 } end
  elseif k == "EmitSound" then return function() end
  elseif k == "ChatPrint" then return function() end
  elseif k == "PrintMessage" then return function() end
  elseif k == "IsValid" then return function() return true end
  elseif k == "Alive" then return function() return true end
  elseif k == "IsDormant" then return function() return false end
  end
  return nil
end
local function mkPly(nick, sid, s64) return setmetatable({ nick = nick, sid = sid, s64 = s64, pos = { x = 0, y = 0, z = 0 } }, PMT) end

-- ── фракции ──
local CopSid = "STEAM_0:1:10"
local CopS64 = "76561198000000010"
Factions = {
  ["Полиция"] = {
    Leader = CopSid, Members = { [CopSid] = { Role = "Офицер" } },
  },
  ["Мэрия"] = {
    Leader = "STEAM_0:1:20", Members = {},
  },
}
FactionsExt = {
  ["Полиция"] = { CurfewRoles = {}, MaskDepartments = {}, GNewsAccess = false, ChipDeathAlert = true },
  ["Мэрия"] = { CurfewRoles = {}, MaskDepartments = {}, GNewsAccess = false, ChipDeathAlert = false },
}
GRM = GRM or {}
GRM.Identity = { CharacterKey = function(p) return p.s64 .. ":char1" end }
GRM.AugChips = {
  PlayerChips = {},
  GetPlayerChips = function(ply)
    local k = ply.s64 .. ":char1"
    GRM.AugChips.PlayerChips[k] = GRM.AugChips.PlayerChips[k] or {}
    return GRM.AugChips.PlayerChips[k]
  end,
}
GRM.Minimap = {
  AddTempPoint = function(name, pos, dur) GRM.Minimap._temp = { name = name, pos = pos, dur = dur } return "temp_1" end,
  SendTo = function() GRM.Minimap._sentTo = (GRM.Minimap._sentTo or 0) + 1 end,
}

-- игроки
local cop = mkPly("Офицер", CopSid, CopS64)                 -- член Полиции (ChipDeathAlert=ВКЛ)
local mayor = mkPly("Мэр", "STEAM_0:1:20", "76561198000000020") -- член Мэрии (ВЫКЛ)
local carrier = mkPly("Носитель", "STEAM_0:1:30", "76561198000000030")
local civ = mkPly("Гражданин", "STEAM_0:1:40", "76561198000000040")
player = { GetAll = function() return { cop, mayor, carrier, civ } end }

-- ══════════════ ЗАГРУЗКА ══════════════
dofile("lua/autorun/sh_grm_chip_control.lua")
ok(GRM.ChipControl ~= nil, "модуль ChipControl загружен")
ok(H.hooks["PlayerDeath"] and H.hooks["PlayerDeath"]["GRM_ChipControl_Death"], "PlayerDeath-хук зарегистрирован")

-- ══════════════ 1. HasExperimental / ListCarriers ══════════════
ok(GRM.ChipControl.HasExperimental(carrier) == false, "без чипов — не спец-юнит")
local carrierChips = GRM.AugChips.GetPlayerChips(carrier)
carrierChips[1] = { id = "c1", name = "Ускорение", category = "civilian", implanted = true, active = true }
ok(GRM.ChipControl.HasExperimental(carrier) == false, "гражданский чип — не спец-юнит")
carrierChips[2] = { id = "c2", name = "Взломщик", category = "experimental", implanted = true, active = true }
ok(GRM.ChipControl.HasExperimental(carrier) == true, "experimental имплантирован — спец-юнит")

local carriers = GRM.ChipControl.ListCarriers()
local foundCarrier = false
for _, c in ipairs(carriers) do
  if c.key == "76561198000000030:char1" then
    foundCarrier = true
    ok(c.special == true, "носитель помечен special")
    ok(c.online == true and c.faction == "", "носитель онлайн, без фракции")
    ok(#c.chips == 2, "в реестре 2 чипа")
  end
end
ok(foundCarrier, "носитель найден в реестре ListCarriers")

-- офлайн-носитель в хранилище чипов
GRM.AugChips.PlayerChips["76561198000000099:char1"] = {
  { id = "c9", name = "Эксперимент", category = "experimental", implanted = true, active = true },
}
local carriers2 = GRM.ChipControl.ListCarriers()
local foundOffline = false
for _, c in ipairs(carriers2) do
  if c.key == "76561198000000099:char1" then foundOffline = true; ok(c.special == true and c.online == false, "офлайн-носитель в реестре, special") end
end
ok(foundOffline, "офлайн-носитель найден")

-- ══════════════ 2. AlertEnabledFor ══════════════
ok(GRM.ChipControl.AlertEnabledFor("Полиция") == true, "Полиция: уведомление ВКЛ")
ok(GRM.ChipControl.AlertEnabledFor("Мэрия") == false, "Мэрия: уведомление ВЫКЛ")
ok(GRM.ChipControl.AlertEnabledFor("") == false, "пустая фракция — false")

-- ══════════════ 3. СМЕРТЬ НОСИТЕЛЯ ══════════════
H.netlog = {}
local deathHook = H.hooks["PlayerDeath"]["GRM_ChipControl_Death"]
deathHook(carrier, nil, civ)
-- журнал
ok(#GRM.ChipControl.Events == 1 and GRM.ChipControl.Events[1].type == "death", "смерть записана в журнал")
ok(GRM.ChipControl.Events[1].name == "Носитель", "в журнале имя носителя")
-- уведомление: только член Полиции (ChipDeathAlert=ВКЛ)
ok(netCount("GRM_ChipDeath_Alert") == 1, "уведомление отправлено ровно одному члену (Полиция)")
-- GPS-маркер создан
ok(GRM.Minimap._temp ~= nil and GRM.Minimap._temp.name:find("убит/умер специальный юнит", 1, true) ~= nil, "temp GPS-маркер создан с подписью")
ok(GRM.Minimap._sentTo == 1, "синк minimap отправлен уведомлённому")

-- повторная смерть гражданского без чипа — ничего
GRM.ChipControl.Events = {}
deathHook(civ, nil, nil)
ok(#GRM.ChipControl.Events == 0, "смерть без чипа не фиксируется")

-- ══════════════ 4. Терминал: net-контракт ══════════════
ok(H.netrecv["GRM_ChipControl_Open"] ~= nil, "net.Receive GRM_ChipControl_Open зарегистрирован")
H.netlog = {}
H.netrecv["GRM_ChipControl_Open"](0, cop)
ok(netCount("GRM_ChipControl_Data") == 1, "по запросу терминала сервер шлёт GRM_ChipControl_Data")

-- ══════════════ 5. Интеграция во вкладку фракций ══════════════
local ff = assert(io.open("lua/autorun/sh_faction_fixes.lua", "rb"))
local ffSrc = ff:read("*a") ff:close()
ok(ffSrc:find('action == "setChipDeathAlert"', 1, true) ~= nil, "серверный action setChipDeathAlert в sh_faction_fixes.lua")
ok(ffSrc:find("ChipDeathAlert", 1, true) ~= nil, "ChipDeathAlert в конфиге фракций")
ok(ffSrc:find("Уведомлять о смерти носителей экспериментальных чипов", 1, true) ~= nil, "чекбокс во вкладке «Расширенные настройки»")

-- ══════════════ 6. Звук смерти комбайна ══════════════
ok(GRM.ChipControl.DeathSound == "npc/metropolice/die2.wav", "звук смерти = npc/metropolice/die2.wav")
local cc = assert(io.open("lua/autorun/sh_grm_chip_control.lua", "rb"))
local ccSrc = cc:read("*a") cc:close()
ok(ccSrc:find("surface.PlaySound", 1, true) ~= nil, "клиент проигрывает звук (surface.PlaySound)")

print(("CHIP CONTROL: %d/%d failures=%d"):format(pass, pass + fail, fail))
if fail > 0 then os.exit(1) end
