-- sim_admin_hub.lua — проверка ЕДИНОЙ АДМИН-ПАНЕЛИ (/grm_admin) и
-- ЕДИНОГО МЕНЮ СОХРАНЕНИЙ (/grm_persistence) на серверной стороне.
-- Грузит РЕАЛЬНЫЕ sh_grm_admin_hub.lua и sv_grm_persistence_hub.lua с моками
-- GMod API, дёргает net-контракты напрямую (как sim_rootboard/sim_qmenu).
local pass, fail = 0, 0
local function ok(v, n) if v then pass = pass + 1 print("  ok  " .. n) else fail = fail + 1 print("  FAIL " .. n) end end

SERVER, CLIENT = true, false
function AddCSLuaFile() end
function isstring(v) return type(v) == "string" end
function istable(v) return type(v) == "table" end
function isfunction(v) return type(v) == "function" end
function IsValid(v) return v ~= nil and (type(v) == "table" and v.__valid ~= false or type(v) == "userdata") end
function CurTime() return 1000 end
function SysTime() return 1000 end
function print(...) local a = {} for i = 1, select("#", ...) do a[i] = tostring(select(i, ...)) end io.write(table.concat(a, " "), "\n") end
table.Count = table.Count or function(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
math.Clamp = math.Clamp or function(v, a, b) return math.max(a, math.min(b, v)) end
string.Trim = string.Trim or function(s) return tostring(s or ""):match("^%s*(.-)%s*$") end

local H = { hooks = {}, netlog = {}, netrecv = {}, concommands = {}, seq = {} }
hook = { Add = function(n, id, fn) H.hooks[n] = H.hooks[n] or {} H.hooks[n][id] = fn end }
timer = { Create = function() end, Simple = function(_, fn) if fn then fn() end end }
concommand = { Add = function(n, fn) H.concommands[n] = fn end }
util = { AddNetworkString = function() end }
net = {
  Start = function(m) H.netlog.cur = { msg = m, f = {} } end,
  WriteBool = function(v) table.insert(H.netlog.cur.f, v and "T" or "F") end,
  WriteString = function(v) table.insert(H.netlog.cur.f, tostring(v or "")) end,
  WriteTable = function(v) table.insert(H.netlog.cur.f, v or {}) end,
  Send = function() if H.netlog.cur then H.netlog.cur.to = "ply" H.netlog[#H.netlog + 1] = H.netlog.cur H.netlog.cur = nil end end,
  Broadcast = function() if H.netlog.cur then H.netlog.cur.to = "all" H.netlog[#H.netlog + 1] = H.netlog.cur H.netlog.cur = nil end end,
  Receive = function(m, fn) H.netrecv[m] = fn end,
  ReadString = function() return tostring(table.remove(H.seq, 1) or "") end,
  ReadBool = function() local v = table.remove(H.seq, 1) return v == true or v == "T" end,
  ReadTable = function() return table.remove(H.seq, 1) or {} end,
}
local function lastNet(msg)
  for i = #H.netlog, 1, -1 do if H.netlog[i].msg == msg then return H.netlog[i] end end
end
local function netCount(msg)
  local n = 0 for _, e in ipairs(H.netlog) do if e.msg == msg then n = n + 1 end end return n
end

game = { GetMap = function() return "gm_test" end }
player = { GetAll = function() return H.players or {} end }

-- ── игроки ──
local PMT = {}
PMT.__index = function(t, k)
  if k == "IsSuperAdmin" then return function(s) return s.super == true end
  elseif k == "Nick" then return function(s) return s.nick end
  elseif k == "SteamID" then return function(s) return s.sid end
  elseif k == "SteamID64" then return function(s) return s.s64 end
  elseif k == "PrintMessage" then return function() end
  elseif k == "GetNWString" then return function() return "" end
  elseif k == "GetPos" then return function() return { x = 0, y = 0, z = 0 } end
  end
  return nil
end
local function mkPly(nick, sid, s64, super) return setmetatable({ nick = nick, sid = sid, s64 = s64, super = super }, PMT) end
local Admin = mkPly("Админ", "STEAM_0:1:1", "76561198000000001", true)
local User = mkPly("Игрок", "STEAM_0:1:2", "76561198000000002", false)
H.players = { Admin, User }

-- ── фракции и модули (моки) ──
Factions = { ["Полиция"] = { Leader = "STEAM_0:1:1", Members = { ["STEAM_0:1:1"] = { Role = "Лидер" } } } }
GRM = GRM or {}
GRM.Identity = { CharacterKey = function() return "76561198000000001:char1" end }
GRM.GetBalance = function() return 1000 end
GRM.Jobs = { Version = "1.1.0", Active = {}, Cfg = { allow = {}, posts = {} }, SaveCfg = function() GRM.Jobs._saved = true end, Fail = function() end }
GRM.Ach = { Version = "1.0.1", Order = {}, Records = {}, AdminReset = function() GRM.Ach._reset = true end }
GRM.Trunk = { Version = "1.0.0", Store = {} }
GRM.QMenu = { Version = "3.3.1", Cfg = { toolDeny = {}, toolAllow = {} }, Save = function() GRM.QMenu._saved = true end, ToolCatalog = { { id = "weld", label = "Сварка" }, { id = "grm_network_tool", label = "GRM: электроника и сеть" } } }
GRM.Broadcast = { Version = "1.2.1", Cfg = { journalists = {}, alerters = {} }, SaveCfg = function() end }
GRM.Board = { Version = "1.1.0", Cfg = { allow = {}, open = {}, journal = {}, assign = {} }, SaveCfg = function() end }
GRM.Economy = {
  Version = "3.0.4", FactionInfo = function() return { budget = 5000, taxRate = 0.05, baseSalary = 100, salaryInterval = 300, payFromBudget = true } end,
  StateBudgetGet = function() return 999 end, StateBudgetAdd = function(v) GRM.Economy._stateAdd = (GRM.Economy._stateAdd or 0) + v end,
  StateBudgetSet = function(v) GRM.Economy._stateSet = v end,
}
GRM.FactionBudgetGet = function() return 5000 end
GRM.FactionBudgetAdd = function(_, v) GRM.FactionBudgetAdd._last = v end
GRM.GiveMoney = function() end
GRM.TakeMoney = function() end
GRM.SetBalance = function() end

-- ══════════════ 1. ЕДИНАЯ АДМИН-ПАНЕЛЬ ══════════════
dofile("lua/autorun/sh_grm_admin_hub.lua")
ok(GRM.AdminHub ~= nil and GRM.AdminHub.Version ~= nil, "Admin Hub загружен (v" .. tostring(GRM.AdminHub.Version) .. ")")
ok(H.concommands["grm_admin"] ~= nil, "консольная команда grm_admin зарегистрирована")

-- открытие: суперадмин получает NET_OPEN, игрок — нет
H.netlog = {}
H.concommands["grm_admin"](Admin)
ok(lastNet("GRM_HUB_Open") ~= nil, "суперадмину отправлен GRM_HUB_Open")
H.netlog = {}
H.concommands["grm_admin"](User)
ok(lastNet("GRM_HUB_Open") == nil, "не-админу GRM_HUB_Open НЕ отправлен")

-- вкладка «Сервер»: payload уходит без ошибок и содержит счётчики
H.netlog = {}
H.seq = { "server" }
local serverOk = pcall(H.netrecv["GRM_HUB_Get"], 0, Admin)
local payload = nil
for i = #H.netlog, 1, -1 do if H.netlog[i].msg == "GRM_HUB_Data" then payload = H.netlog[i].f[2] break end end
ok(serverOk, "GRM_HUB_Get(server) выполнился без ошибок")
ok(payload ~= nil and payload.online == 2 and payload.map == "gm_test", "payload сервера: онлайн и карта")
ok(payload ~= nil and istable(payload.counters) and #payload.counters >= 6, "счётчики сервера (включая устройства сети)")
local hasVer = false
for _, v in ipairs(payload and payload.versions or {}) do if tostring(v.name):find("Электроника") then hasVer = true end end
ok(hasVer, "в списке версий есть Электроника/сеть")

-- остальные вкладки не падают
for _, tab in ipairs({ "access", "jobs", "players", "econ", "tools" }) do
  H.seq = { tab }
  local okp = pcall(H.netrecv["GRM_HUB_Get"], 0, Admin)
  ok(okp, "GRM_HUB_Get(" .. tab .. ") без ошибок")
end

-- действия: qToggle, accSet, econState
H.netrecv["GRM_HUB_Act"](0, Admin)
H.seq = { "qToggle", { key = "playersQ", val = true } }
H.netrecv["GRM_HUB_Act"](0, Admin)
ok(GRM.QMenu.Cfg.playersQ == true and GRM.QMenu._saved == true, "qToggle: playersQ=true сохранён")

H.seq = { "accSet", { kind = "board", fac = "Полиция", allow = true } }
H.netrecv["GRM_HUB_Act"](0, Admin)
ok(GRM.Board.Cfg.allow["Полиция"] == true, "accSet: доступ к доске «Полиция» выдан")

H.seq = { "econState", { op = "give", amount = 500 } }
H.netrecv["GRM_HUB_Act"](0, Admin)
ok(GRM.Economy._stateAdd == 500, "econState: гос.бюджет +500")

-- не-админ не может дёргать действия
H.netlog = {}
H.seq = { "qToggle", { key = "playersQ", val = false } }
H.netrecv["GRM_HUB_Act"](0, User)
ok(GRM.QMenu.Cfg.playersQ == true, "не-админ НЕ меняет настройки Q-меню")
H.seq = { "server" }
H.netrecv["GRM_HUB_Get"](0, User)
ok(netCount("GRM_HUB_Data") == 0, "не-админ НЕ получает данные вкладок")

-- чат-команда /grm_admin (PlayerSayTransform)
local sayHooks = H.hooks["PlayerSayTransform"]
local processed = false
for _, fn in pairs(sayHooks or {}) do
  local pack = { "/grm_admin" }
  local r = fn(Admin, pack)
  if r == true or pack.SkipPlayerSay == true then processed = true end
end
ok(processed, "чат-команда /grm_admin обрабатывается (PlayerSayTransform)")

-- ══════════════ 2. ЕДИНОЕ МЕНЮ СОХРАНЕНИЙ ══════════════
-- мок модулей с флагами вызова (имена методов — как их зовёт хаб)
local calls = {}
local function mkMod(name, saveNames, loadNames)
  local m = {}
  for _, n in ipairs(saveNames or { "Save" }) do
    m[n] = function() calls[name .. "_save"] = (calls[name .. "_save"] or 0) + 1 return true end
  end
  for _, n in ipairs(loadNames or { "Load" }) do
    m[n] = function() calls[name .. "_load"] = (calls[name .. "_load"] or 0) + 1 return true end
  end
  return m
end
GRM.Phone = mkMod("phone", { "SaveAll", "SaveMapEntities" }, { "LoadAll", "LoadMapEntities" })
GRM.CCTV = mkMod("cctv", { "SaveAll", "SavePermanent" }, { "LoadAll", "LoadPermanent" })
GRM.Alarm = mkMod("alarm", { "SaveAll", "SavePermanent" }, { "LoadAll", "LoadPermanent" })
GRM.FactoryCycle = mkMod("factory", { "SaveAll", "SaveMap" }, { "LoadAll", "LoadMap" })
GRM.Logistics = mkMod("logistics", { "SaveAll", "SaveMap" }, { "LoadAll", "LoadMap" })
GRM.Food = mkMod("food", { "SaveAll", "SaveVendingMachines" }, { "LoadAll", "LoadVendingMachines" })
GRM.RoomTap = mkMod("roomtap", { "SaveAll", "SaveMapEquipment" }, { "LoadAll", "LoadMapEquipment" })
GRM.Wanted = mkMod("wanted", { "Save" }, { "Load" })
GRM.Doors = mkMod("doors")
GRM.Doors.SaveDoors = function() calls["doors_save"] = (calls["doors_save"] or 0) + 1 return true end
GRM.Doors.SaveCategories = function() return true end
GRM.Doors.SaveWarrants = function() return true end
GRM.Doors.LoadDoors = function() calls["doors_load"] = (calls["doors_load"] or 0) + 1 return true end
GRM.Doors.LoadCategories = function() return true end
GRM.Doors.LoadWarrants = function() return true end
GRM.Arrest = mkMod("arrest", { "SaveConfig" }, { "LoadConfig" })
GRM.Electronics = mkMod("electronics", { "SaveAll" }, { "LoadAll" })
GRM.VehicleDealer = mkMod("vehicle_dealers", { "SaveAll" }, { "LoadAll" })
GRM.Customization = mkMod("customization", { "SaveData" }, { "LoadData" })
GRM.Vendor = mkMod("vendors", { "SaveMapVendors" }, { "LoadMapVendors" })
GRM.Quests = mkMod("quests", { "SaveAll" }, { "LoadAll" })
GRM.Perm = mkMod("perm", { "SaveAll" }, { "LoadAll" })
GRM.MiningPersistence = mkMod("mining", { "SaveAll" }, { "LoadAll" })
function _G.GRM_SaveEntities() calls["mining_legacy_save"] = (calls["mining_legacy_save"] or 0) + 1 return 1 end
function _G.GRM_LoadEntities() calls["mining_legacy_load"] = (calls["mining_legacy_load"] or 0) + 1 return 1 end

H.netlog = {}
dofile("lua/autorun/server/sv_grm_persistence_hub.lua")
ok(H.concommands["grm_persistence_admin"] ~= nil, "команда grm_persistence_admin зарегистрирована")

H.netlog = {}
H.concommands["grm_persistence_admin"](Admin)
ok(lastNet("GRM_Persistence_Open") ~= nil, "суперадмину отправлено GRM_Persistence_Open")

-- all_save: все модули сохранены, включая electronics
calls = {}
H.seq = { "all_save" }
H.netrecv["GRM_Persistence_Action"](0, Admin)
ok(calls["electronics_save"] == 1, "all_save: электроника сохранена (SaveAll вызван)")
ok(calls["vehicle_dealers_save"] == 1, "all_save: дилеры и гаражи сохранены (SaveAll вызван)")
ok(calls["phone_save"] == 1 and calls["factory_save"] == 1 and calls["food_save"] == 1,
   "all_save: телефония, полный завод и еда вызваны через SaveAll")
ok(calls["doors_save"] == 1 and calls["arrest_save"] == 1, "all_save: остальные модули сохранены")
ok(calls["logistics_save"] == 1 and calls["mining_save"] == 1 and calls["roomtap_save"] == 1,
   "all_save: логистика, шахта и RoomTap используют полные SaveAll")
ok(calls["mining_legacy_save"] == nil, "all_save: шахта не использует слабый legacy saver")
local allOk = false
for i = #H.netlog, 1, -1 do
  if H.netlog[i].msg == "GRM_Persistence_Result" then allOk = (H.netlog[i].f[1] == "T") break end
end
ok(allOk, "all_save: результат OK")

-- all_load
calls = {}
H.seq = { "all_load" }
H.netrecv["GRM_Persistence_Action"](0, Admin)
ok(calls["electronics_load"] == 1, "all_load: электроника загружена (LoadAll вызван)")
ok(calls["vehicle_dealers_load"] == 1, "all_load: дилеры загружены (LoadAll вызван)")
ok(calls["phone_load"] == 1 and calls["factory_load"] == 1 and calls["food_load"] == 1,
   "all_load: телефония, полный завод и еда вызваны через LoadAll")
ok(calls["logistics_load"] == 1 and calls["mining_load"] == 1 and calls["roomtap_load"] == 1,
   "all_load: логистика, шахта и RoomTap используют полные LoadAll")

-- точечная операция electronics_save
calls = {}
H.seq = { "electronics_save" }
H.netrecv["GRM_Persistence_Action"](0, Admin)
ok(calls["electronics_save"] == 1 and calls["phone_save"] == nil, "electronics_save: точечно, без побочных вызовов")


-- Старый id vending остаётся совместимым, но ведёт в полный Food.SaveAll.
calls = {}
H.seq = { "vending_save" }
H.netrecv["GRM_Persistence_Action"](0, Admin)
ok(calls["food_save"] == 1, "legacy vending_save перенаправлен на полный food SaveAll")

-- Отсутствующий модуль больше не выдаёт ложный зелёный SUCCESS.
local keepPhone = GRM.Phone
GRM.Phone = nil
H.netlog = {}
H.seq = { "phone_save" }
H.netrecv["GRM_Persistence_Action"](0, Admin)
local missingResult = lastNet("GRM_Persistence_Result")
ok(missingResult and missingResult.f[1] == "F" and tostring(missingResult.f[2]):find("не загружен", 1, true),
   "хаб fail-closed: отсутствующий модуль возвращает ошибку")
GRM.Phone = keepPhone

-- Регресс-стражи конкретных систем из запроса владельца.
local function source(path) local f=assert(io.open(path,"rb"));local t=f:read("*a");f:close();return t end
local hubSrc = source("lua/autorun/server/sv_grm_persistence_hub.lua")
local phoneSrc = source("lua/autorun/server/sv_grm_phone.lua")
local foodSrc = source("lua/autorun/server/sv_grm_food.lua")
local factorySrc = source("lua/autorun/server/sv_grm_factory_fullcycle.lua")
local logisticsSrc = source("lua/autorun/server/sv_grm_logistics.lua")
local miningSrc = source("lua/autorun/server/sv_grm_mining_saver.lua")
local oreSpawnerSrc = source("lua/autorun/server/sv_grm_ore_spawner.lua")
local roomtapSrc = source("lua/autorun/server/sv_grm_roomtap.lua")
local alarmSrc = source("lua/autorun/server/sv_grm_alarm.lua")
local cctvSrc = source("lua/autorun/server/sv_grm_cctv.lua")
local electronicsSrc = source("lua/autorun/sh_grm_electronics.lua")
local clientSrc = source("lua/autorun/client/cl_grm_persistence_hub.lua")
ok(hubSrc:find('invoke("Phone", "SaveAll"',1,true) and hubSrc:find('invoke("Food", "SaveAll"',1,true)
   and hubSrc:find('invoke("FactoryCycle", "SaveAll"',1,true),
   "хаб использует полные контракты Phone/Food/Factory SaveAll")
ok(phoneSrc:find("not ent.GRMPhoneShopOwned",1,true) and phoneSrc:find("function P.SaveAll",1,true)
   and phoneSrc:find("MAP_ENTITY_ALLOWED",1,true) and phoneSrc:find("P.MapLoadBlocked",1,true),
   "телефония: купленные телефоны не удаляются, JSON-классы валидируются")
ok(foodSrc:find("function GRM.Food.SaveAll",1,true) and foodSrc:find("GRM.PermData.Upsert",1,true)
   and foodSrc:find("GRM.Perm.LoadClasses",1,true) and foodSrc:find("VendingLoadBlocked",1,true)
   and clientSrc:find('{ id = "food"',1,true),
   "еда: единая строка сохраняет автоматы и полное состояние кухни")
ok(factorySrc:find("function FC.SaveAll",1,true) and factorySrc:find("saveLockers()",1,true)
   and factorySrc:find("saveBuyers()",1,true) and factorySrc:find("saveMarket()",1,true)
   and factorySrc:find("validateMapRecords",1,true) and factorySrc:find("FC.DataLoadBlocked",1,true),
   "завод: единая операция включает карту, шкафы, скупщиков и рынок")
ok(logisticsSrc:find("function L.SaveAll",1,true) and logisticsSrc:find("function L.LoadAll",1,true)
   and logisticsSrc:find("validateMapRecords",1,true) and logisticsSrc:find("CRATEFILE",1,true),
   "логистика: карта, доступ и переносимые ящики входят в полный контракт")
ok(miningSrc:find("GRM.MiningPersistence",1,true) and miningSrc:find("function MP.SaveAll",1,true)
   and miningSrc:find("function MP.LoadAll",1,true) and miningSrc:find("_grmMiningUID",1,true)
   and oreSpawnerSrc:find("GRMOreSpawned",1,true) and oreSpawnerSrc:find("OS.SavePoints",1,true),
   "шахта: ручное оборудование отделено от точек автореспавна и имеет UID")
ok(roomtapSrc:find("function RT.SaveAll",1,true) and roomtapSrc:find("function RT.LoadAll",1,true)
   and roomtapSrc:find("temporary equipment",1,true) and roomtapSrc:find("GRMRoomTapShopID",1,true)
   and roomtapSrc:find("claimed[ent]",1,true),
   "RoomTap: постоянные/временные устройства и доступ входят в SaveAll без дублей")
ok(alarmSrc:find("function A.SaveAll",1,true) and alarmSrc:find("validatePermanentRecords",1,true)
   and cctvSrc:find("function CCTV.SaveAll",1,true) and cctvSrc:find("validatePermanentRecords",1,true),
   "Alarm/CCTV: единый bool-контракт и semantic validation до восстановления")
ok(electronicsSrc:find("local mapOK=E.SaveMap();local dbOK=E.SaveDB()",1,true)
   and electronicsSrc:find("if not dbOK then return false",1,true),
   "электроника: SaveAll пишет оба контура, LoadAll fail-closed по DB")

-- не-админ не может сохранять
calls = {}
H.seq = { "all_save" }
H.netrecv["GRM_Persistence_Action"](0, User)
ok(calls["electronics_save"] == nil and calls["phone_save"] == nil, "не-админ НЕ сохраняет")

print(("ADMIN HUB + PERSISTENCE: %d/%d failures=%d"):format(pass, pass + fail, fail))
if fail > 0 then os.exit(1) end
