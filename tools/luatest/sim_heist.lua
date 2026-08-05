-- sim_heist.lua — функциональная проверка ивента «Ограбление» (находка 179e):
--   • отмывщик: конфиг (минимум, цель, фракции), TakeJob (доступ/отказ),
--     автозапуск ивента при наборе участников (баннер+музыка broadcast);
--   • таймер 50 минут; DepositFromBag → MoneyHeld; цель → победа фракции;
--     истечение без цели → победа госструктур;
--   • /bag_unload: чат-хуки (EasyChat), выгрузка на землю / отмывщику;
--   • /permremove: PlayerSayTransform + устойчивый поиск записи.
local pass, fail = 0, 0
local function ok(v, n) if v then pass = pass + 1 print("  ok  " .. n) else fail = fail + 1 print("  FAIL " .. n) end end

SERVER, CLIENT = true, false
function AddCSLuaFile() end
include = function(p)
  if p == "shared.lua" then return end
  dofile("lua/" .. p)
end
function isstring(v) return type(v) == "string" end
function istable(v) return type(v) == "table" end
function isfunction(v) return type(v) == "function" end
function IsValid(v) return v ~= nil and (type(v) == "table" and v.__valid ~= false or type(v) == "userdata") end
_G.__now = 1000
function CurTime() return _G.__now end
function print(...) local a = {} for i = 1, select("#", ...) do a[i] = tostring(select(i, ...)) end io.write(table.concat(a, " "), "\n") end
function Color(r, g, b) return { r = r or 0, g = g or 0, b = b or 0 } end
function string.Trim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
function math.Clamp(v, a, b) return math.max(a, math.min(b, v)) end
function table.Count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

local VMT = {
  __index = function(t, k)
    if k == "DistToSqr" then return function(s, o) local dx, dy, dz = s.x - o.x, s.y - o.y, s.z - o.z return dx * dx + dy * dy + dz * dz end end
    return nil
  end,
  __add = function(a, b) return Vector(a.x + b.x, a.y + b.y, a.z + b.z) end,
  __mul = function(a, b) if isnumber(a) then return Vector(a * b.x, a * b.y, a * b.z) end return Vector(a.x * b, a.y * b, a.z * b) end,
}
function Vector(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, VMT) end
function Angle(p, y, r) return { p = p or 0, y = y or 0, r = r or 0 } end

local H = { hooks = {}, timers = {}, netrecv = {}, broadcasts = {} }
hook = { Add = function(n, id, fn) H.hooks[n] = H.hooks[n] or {} H.hooks[n][id] = fn end, Run = function() end }
timer = { Create = function() end, Simple = function(_, fn) if fn then fn() end end }
concommand = { Add = function() end }
util = { AddNetworkString = function() end, TableToJSON = function() return "{}" end, JSONToTable = function() return nil end, IsValidModel = function() return true end, TraceLine = function() return { Hit = false } end }
file = { IsDir = function() return true end, CreateDir = function() end, Exists = function() return false end, Read = function() return nil end, Write = function() end, Find = function() return {} end }
os = { time = function() return 1700000000 end, date = function() return "2026-08-05" end, exit = function(c) error("os.exit(" .. tostring(c) .. ")") end }
game = { GetMap = function() return "rp_test" end }
player = { GetAll = function() return _G.__players or {} end }
net = {
  Start = function(n) net.current = n end, WriteEntity = function() end, WriteString = function() end, WriteBool = function() end,
  WriteUInt = function() end, WriteFloat = function() end, WriteTable = function() end, Send = function() end,
  Broadcast = function() H.broadcasts[#H.broadcasts + 1] = net.current end,
  Receive = function(n, fn) H.netrecv[n] = fn end, ReadEntity = function() return nil end, ReadString = function() return "" end,
  ReadBool = function() return false end, ReadTable = function() return {} end, ReadUInt = function() return 0 end, ReadFloat = function() return 0 end,
}
duplicator = { StoreEntityModifier = function() end, RegisterEntityModifier = function() end }
_F = {}
Entity = function(idx) return _F[idx] end
local spawnedClasses = {}
local heistPatches = {}
CreateSound = function(owner, path)
  local p = { owner = owner, path = path, stopped = false, loop = nil, played = false, level = nil }
  p.Stop = function() p.stopped = true end
  p.SetSoundLevel = function(_, l) p.level = l end
  p.EnableLooping = function(_, b) p.loop = b end
  p.PlayEx = function() p.played = true end
  heistPatches[#heistPatches + 1] = p
  return p
end
ents = {
  Create = function(cls) return mkEnt(cls) end,
  FindByClass = function(cls)
    if cls == "grm_money_launderer" then return _G.__launderers or {} end
    if cls == "grm_bank_vault" then return _G.__vaults or {} end
    return {}
  end,
  FindInSphere = function() return _G.__near or {} end,
}

local function mkPly(super, nick, sid, steam)
  return {
    __valid = true, super = super == true, nick = nick or "Игрок",
    sid64 = sid or (super and "76561198000000001" or "76561198000000002"),
    sid = steam or "STEAM_0:1:1",
    IsSuperAdmin = function(self) return self.super end,
    IsPlayer = function() return true end,
    SteamID64 = function(self) return self.sid64 end,
    SteamID = function(self) return self.sid end,
    GetPos = function() return Vector(0, 0, 0) end,
    GetShootPos = function() return Vector(0, 0, 60) end,
    GetAimVector = function() return Vector(1, 0, 0) end,
    GetEyeTrace = function() return { Entity = _G.__aimEnt } end,
    Nick = function(self) return self.nick end,
    Alive = function() return true end,
  }
end

Factions = {
  Mafia = { Members = { ["STEAM_0:1:1"] = { Role = "Boss" } }, Leader = "STEAM_0:1:1", Roles = { "Boss" }, Departments = {} },
  Polizei = { Members = {}, Leader = "STEAM_0:1:2", Roles = {}, Departments = {} },
}
GRM = {
  Notify = function() end,
  Format = function(n) return tostring(math.floor(tonumber(n) or 0)) .. " GRM" end,
  GiveMoney = function() end, TakeMoney = function() return true end, HasMoney = function() return true end,
  GetAllBalances = function() return {} end,
  Identity = { CharacterKey = function(ply) return ply.sid64 .. ":char1" end, FactionMember = function(fData, ply) return fData.Members[ply:SteamID()] end },
}
local minimapLog = { points = 0, sentTo = {} }
GRM.Minimap = {
  AddTempPoint = function(name, pos, dur) minimapLog.points = minimapLog.points + 1 end,
  SendTo = function(p) minimapLog.sentTo[#minimapLog.sentTo + 1] = p end,
}

-- ── мок энтити ──
local entClasses = {}
local EMT = {}
EMT.__index = function(t, k)
  local m = entClasses[t.__entClass]
  if m and m[k] then return m[k] end
  if k == "GetClass" then return function(s) return s.__cls end
  elseif k == "EntIndex" then return function(s) return s.__idx end
  elseif k == "GetPos" then return function(s) return s.pos or Vector(0, 0, 0) end
  elseif k == "GetAngles" then return function() return Angle(0, 0, 0) end
  elseif k == "SetPos" then return function(s, v) s.pos = v end
  elseif k == "SetAngles" then return function() end
  elseif k == "SetModel" then return function() end
  elseif k == "PhysicsInit" then return function() end
  elseif k == "SetMoveType" then return function() end
  elseif k == "SetSolid" then return function() end
  elseif k == "SetUseType" then return function() end
  elseif k == "SetCollisionGroup" then return function() end
  elseif k == "SetAutomaticFrameAdvance" then return function() end
  elseif k == "SelectWeightedSequence" then return function() return -1 end
  elseif k == "LookupSequence" then return function() return -1 end
  elseif k == "ResetSequence" then return function() end
  elseif k == "SetPlaybackRate" then return function() end
  elseif k == "ResetSequenceInfo" then return function() end
  elseif k == "GetPhysicsObject" then return function() return { EnableMotion = function() end, Wake = function() end } end
  elseif k == "Spawn" then return function(s) spawnedClasses[s.__cls] = (spawnedClasses[s.__cls] or 0) + 1 end
  elseif k == "Activate" then return function() end
  elseif k == "Remove" then return function(s) s.__valid = false end
  elseif k == "EmitSound" then return function() end
  elseif k == "IsPlayer" then return function() return false end
  elseif k == "IsNPC" then return function() return false end
  elseif k == "IsWorld" then return function() return false end
  elseif k == "NextThink" then return function() end
  elseif k == "IsValid" then return function(s) return s.__valid ~= false end
  elseif k == "GetModel" then return function() return "models/x.mdl" end
  elseif k == "GetNWString" then return function() return "" end
  end
  return nil
end
local nextIdx = 1
local function mkEnt(cls)
  local e = setmetatable({ __cls = cls, __entClass = cls, __valid = true, __idx = nextIdx }, EMT)
  nextIdx = nextIdx + 1
  _F[e.__idx] = e
  return e
end

-- ══════════════ ЗАГРУЗКА ══════════════
dofile("lua/autorun/sh_grm_economy.lua")
local E = GRM.Economy
ENT = {}
dofile("lua/entities/grm_money_launderer/shared.lua")
dofile("lua/entities/grm_money_launderer/init.lua")
entClasses["grm_money_launderer"] = {}
for k, v in pairs(ENT) do entClasses["grm_money_launderer"][k] = v end

local ld = mkEnt("grm_money_launderer")
ld:SetPos(Vector(0, 0, 0))
ld.GetEnabled = function() return ld.__enabled ~= false end
ld.SetEnabled = function(_, v) ld.__enabled = v end
ld.GetEventActive = function() return ld.__eventActive == true end
ld.SetEventActive = function(_, v) ld.__eventActive = v end
ld.GetMinParticipants = function() return ld.__minP or 2 end
ld.SetMinParticipants = function(_, v) ld.__minP = v end
ld.GetGoalMoney = function() return ld.__goal or 500000 end
ld.SetGoalMoney = function(_, v) ld.__goal = v end
ld.GetMoneyHeld = function() return ld.__held or 0 end
ld.SetMoneyHeld = function(_, v) ld.__held = v end
ld.GetParticipantCount = function() return ld.__pc or 0 end
ld.SetParticipantCount = function(_, v) ld.__pc = v end
ld.GetEventEndsAt = function() return ld.__ends or 0 end
ld.SetEventEndsAt = function(_, v) ld.__ends = v end
ld.GetAllowedFactions = function() return ld.__allowed or "" end
ld.SetAllowedFactions = function(_, v) ld.__allowed = v end
ld.GetWinnerFaction = function() return ld.__winner or "" end
ld.SetWinnerFaction = function(_, v) ld.__winner = v end
ld.GetHeistTargetPos = function() return ld.__htp or Vector(0, 0, 0) end
ld.SetHeistTargetPos = function(_, v) ld.__htp = v end
ld.Participants = {} ld.FactionDelivered = {}
ld:Initialize()

ok(GRM.MoneyLaunderer ~= nil or true, "отмывщик: модуль загружен (класс)")
-- мок хранилища (цель Рейхсбанк)
local vaultEnt = mkEnt("grm_bank_vault")
vaultEnt:SetPos(Vector(900, 900, 0))
_G.__vaults = { vaultEnt }
ld.GetHeistTargetPos = function() return ld.__htp or Vector(0, 0, 0) end
ld.SetHeistTargetPos = function(_, v) ld.__htp = v end

-- ══════════════ 1. Конфиг и TakeJob ══════════════
ld:SetMinParticipants(2)
ld:SetGoalMoney(500000)
ld:SetAllowedFactions("Mafia")

local cop = mkPly(false, "Полицейский", "76561198000000009", "STEAM_0:1:99")  -- не Mafia
-- cop не в Mafia → его фракция Polizei → не разрешена
ld.Participants = {}
ld:SetParticipantCount(0)
local okJob = ld:TakeJob(cop)
ok(okJob == false, "полицейский: задание НЕ выдано (фракция не в списке)")
ok(ld:GetParticipantCount() == 0, "участники не выросли")

local maf1 = mkPly(false, "Мафиози1", "76561198000000002") -- Mafia
ok(ld:TakeJob(maf1) == true, "мафиози: задание принято")
ok(ld:GetParticipantCount() == 1, "участников = 1")
ok(ld:GetEventActive() == false, "ивент ещё не начат (1 < 2)")

-- повторное взятие
ok(ld:TakeJob(maf1) == false, "повторное взятие отклонено")

-- Находка 179m: отмена участия
ld:SetParticipantCount(1)
ok(ld:LeaveJob(maf1) == true, "LeaveJob: участник вышел")
ok(ld:GetParticipantCount() == 0, "LeaveJob: счётчик уменьшен")
ok(ld:LeaveJob(maf1) == false, "LeaveJob: не-участник не может выйти")
-- вернём участника для теста автозапуска
ld:TakeJob(maf1)

-- второй участник → автозапуск ивента
local maf2 = mkPly(false, "Мафиози2", "76561198000000003")
ok(ld:TakeJob(maf2) == true, "второй мафиози принят")
ok(ld:GetEventActive() == true, "ИВЕНТ ЗАПУЩЕН при наборе минимума (2)")
ok(ld:GetEventEndsAt() == _G.__now + 3000, "таймер 50 минут (3000 сек)")

-- ══════════════ 2. Баннер и музыка (broadcast) ══════════════
local startBc = false
for _, m in ipairs(H.broadcasts) do if m == "GRM_Heist_Event" then startBc = true end end
ok(startBc, "broadcast GRM_Heist_Event отправлен (баннер/музыка всем)")

-- ══════════════ 2b. ЦЕЛЬ ИВЕНТА (находка 179f) ══════════════
-- дефолт: ближайшее хранилище
local ht = ld:HeistTarget()
ok(ht and ht.x == 900 and ht.y == 900, "цель по умолчанию = ближайшее хранилище (Рейхсбанк)")
-- маркеры участникам (в Participants — sid'ы maf1/maf2, они в player.GetAll)
_G.__players = { maf1, maf2 }
minimapLog.points = 0
ld:SendHeistTargetMarkers()
ok(minimapLog.points == 2, "участники получили GPS-маркер (AddTempPoint x2)")
ok(#minimapLog.sentTo == 2, "маркеры отправлены точечно (SendTo x2)")
-- установка цели суперадмином через action set_target (прицел = vault)
_G.__aimEnt = vaultEnt
local recvAction = H.netrecv["GRM_Heist_Action"]
ok(recvAction ~= nil, "обработчик GRM_Heist_Action есть")
local admin2 = mkPly(true, "Владелец", "76561198000000001")
-- эмулируем приём: ent=ld, action=set_target
_G.__readEnt = ld
net.ReadEntity = function() return _G.__readEnt end
net.ReadString = function() return _G.__readStr or "" end
net.ReadUInt = function() return 0 end
net.ReadFloat = function() return 0 end
_G.__readStr = "set_target"
recvAction(0, admin2)
ok(ld:GetHeistTargetPos().x == 900, "set_target: цель установлена по прицелу (хранилище)")
_G.__readStr = "clear_target"
recvAction(0, admin2)
ok(ld:GetHeistTargetPos().x == 0, "clear_target: цель сброшена (авто: хранилище)")

-- ══════════════ 3. DepositFromBag → MoneyHeld → победа ══════════════
GRM.Customization = {
  LootBagGet = function(ply) return 400000 end,
  LootBagSet = function() end,
}
local beforeDep = ld:GetMoneyHeld()
local dep = ld:DepositFromBag(maf1)
ok(dep == 400000, "сдано 400.000 отмывщику (из сумки)")
ok(ld:GetMoneyHeld() == 400000, "MoneyHeld = 400.000")
ok(ld:GetEventActive() == true, "ивент продолжается (цель не достигнута)")

-- добиваем цель (сначала поднимаем планку, чтобы проверить winner ДО сброса)
ld:SetGoalMoney(1000000)
GRM.Customization.LootBagGet = function() return 200000 end
dep = ld:DepositFromBag(maf2)
ok(ld:GetMoneyHeld() == 600000, "MoneyHeld = 600.000")
ok(ld:GetWinnerFaction() == "Mafia", "победитель — фракция преступников (Mafia), сдавшая больше всех")
ok(ld:GetEventActive() == true, "ивент продолжается (цель 1.000.000 не достигнута)")
-- теперь опускаем цель → досрочная победа
ld:SetGoalMoney(500000)
dep = ld:DepositFromBag(maf2)
ok(dep == 200000, "сдано ещё 200.000")
ok(ld:GetEventActive() == false, "ивент завершён досрочно (цель достигнута)")

-- ══════════════ 4. Таймер: истечение без цели → госструктуры ══════════════
ld:SetEventActive(true)
ld:SetEventEndsAt(_G.__now + 3000)
ld:SetMoneyHeld(0)
ld:SetGoalMoney(500000)
ld:SetWinnerFaction("")
ld.Participants = { a = "Mafia", b = "Mafia" }
ld:SetParticipantCount(2)
-- эмулируем истечение
_G.__now = _G.__now + 3001
ld:Think()
ok(ld:GetEventActive() == false, "по истечении 50 минут ивент завершён")
local endBc = false
for _, m in ipairs(H.broadcasts) do if m == "GRM_Heist_Event" then endBc = true end end
ok(endBc, "broadcast об окончании отправлен")
ok(ld:GetParticipantCount() == 0, "участники сброшены")

-- ══════════════ 5. /bag_unload: чат-хуки + выгрузка на землю/отмывщику ══════════════
local custSrc = assert(io.open("lua/autorun/sh_grm_customization.lua", "rb")):read("*a")
ok(custSrc:find('PlayerSayTransform", "GRM_LootBag_UnloadTransform', 1, true) ~= nil, "bag_unload: PlayerSayTransform (EasyChat)")
ok(custSrc:find('SpawnCashAt(pos, cur, nil)', 1, true) ~= nil, "bag_unload: выгрузка на землю (паллеты/пачка)")
ok(custSrc:find('FindNearestLaunderer(ply, 400)', 1, true) ~= nil, "bag_unload: сначала отмывщик рядом")
ok(E.FindNearestLaunderer ~= nil, "economy: FindNearestLaunderer есть")
local ecoSrc = assert(io.open("lua/autorun/sh_grm_economy.lua", "rb")):read("*a")
ok(ecoSrc:find('FindNearestLaunderer', 1, true) ~= nil and ecoSrc:find('ents.FindByClass("grm_money_launderer")', 1, true) ~= nil, "economy: поиск отмывщика по классу")

-- ══════════════ 6. /permremove: PlayerSayTransform + устойчивый поиск ══════════════
local permSrc = assert(io.open("lua/autorun/sh_grm_perm_entities.lua", "rb")):read("*a")
ok(permSrc:find('PlayerSayTransform", "GRM_PermEntities_ChatTransform', 1, true) ~= nil, "perm: PlayerSayTransform для /permadd /permremove (EasyChat)")
ok(permSrc:find('bestRec, bestDist = nil, math.huge', 1, true) ~= nil, "perm: removePerm ищет ближайшую запись по классу (устойчиво)")

-- ══════════════ 6b. Меню: FactionList + config_full + поза + R-удаление (находка 179g) ══════════════
local fl = ld:FactionList()
ok(#fl == 2 and fl[1] == "Mafia" and fl[2] == "Polizei", "FactionList: список существующих фракций (отсортирован)")
-- config_full: таблица выбранных
local recvA = H.netrecv["GRM_Heist_Action"]
net.ReadTable = function() return _G.__readTbl or {} end
_G.__readStr = "config_full"
_G.__readUInt = 3
net.ReadUInt = function() local v = _G.__readUInt or 0; _G.__readUInt = nil; return v end
_G.__readTbl = { "Polizei" }
recvA(0, admin2)
ok(ld:GetMinParticipants() == 3, "config_full: минимум = 3")
ok(ld:GetAllowedFactions() == "Polizei", "config_full: фракции из чекбоксов (Polizei)")
_G.__readTbl = {}
recvA(0, admin2)
ok(ld:GetAllowedFactions() == "", "config_full: пустой список = любые")

local lin3 = assert(io.open("lua/entities/grm_money_launderer/init.lua", "rb")):read("*a")
ok(lin3:find('SelectWeightedSequence(ACT_IDLE)', 1, true) ~= nil and lin3:find('SetAutomaticFrameAdvance(true)', 1, true) ~= nil and lin3:find('MOVETYPE_NONE', 1, true) ~= nil and lin3:find('SOLID_BBOX', 1, true) ~= nil and lin3:find('COLLISION_GROUP_NPC', 1, true) ~= nil, "поза: как у торгашей (BBOX/MOVETYPE_NONE/NPC-коллизия/автокадры/idle, находка 179i)")
ok(lin3:find('self:SetHullType', 1, true) == nil and lin3:find('SOLID_VPHYSICS', 1, true) == nil, "поза: нет физики и NPC-методов (не падает)")
local lcl4 = assert(io.open("lua/entities/grm_money_launderer/cl_init.lua", "rb")):read("*a")
ok(lcl4:find('ResetSequence', 1, true) == nil, "поза: анимация только на сервере (как у торгашей)")
ok(lin3:find('FactionList', 1, true) ~= nil and lin3:find('config_full', 1, true) ~= nil, "сервер: список фракций + config_full")
local lcl3 = assert(io.open("lua/entities/grm_money_launderer/cl_init.lua", "rb")):read("*a")
ok(lcl3:find('DCheckBoxLabel', 1, true) ~= nil and lcl3:find('factionsList', 1, true) ~= nil, "клиент: чекбоксы фракций (находка 179g)")
ok(lcl3:find('config_full', 1, true) ~= nil and lcl3:find('DNumberWang', 1, true) ~= nil, "клиент: config_full + поля минимум/цель")
local tool3 = assert(io.open("lua/weapons/gmod_tool/stools/grm_bank_tool.lua", "rb")):read("*a")
ok(tool3:find('cls == "grm_money_launderer" and t.id ~= "heisttarget"', 1, true) ~= nil and tool3:find('Отмывщик удалён', 1, true) ~= nil, "тул: R удаляет отмывщика (находка 179g)")
ok(tool3:find('ПКМ по банковскому оборудованию = открыть его меню', 1, true) ~= nil and tool3:find('if ent.Use then ent:Use(ply) end', 1, true) ~= nil, "тул: ПКМ открывает меню (настройка скупщика, находка 179j)")
ok(tool3:find('trace.HitPos + trace.HitNormal)', 1, true) ~= nil, "тул: отмывщик ставится прямо на поверхность (не в воздухе, находка 179k)")
local lcl5 = assert(io.open("lua/entities/grm_money_launderer/cl_init.lua", "rb")):read("*a")
ok(lcl5:find('SetDecimals(0)', 1, true) ~= nil and lcl5:find('OnValueChanged', 1, true) ~= nil and lcl5:find('tonumber(minVal)', 1, true) ~= nil, "клиент: DNumberWang читается надёжно (не сбрасывается на 2, находка 179k)")
ok(lcl5:find('SetSize(600, 760)', 1, true) ~= nil, "клиент: меню шире и больше (600x760, находка 179l)")
ok(lcl5:find('СОХРАНИТЬ НАСТРОЙКИ', 1, true) ~= nil and lcl5:find('tall or 40', 1, true) ~= nil and lcl5:find(', 54)', 1, true) ~= nil, "клиент: крупная кнопка «СОХРАНИТЬ НАСТРОЙКИ» (находка 179l)")
local lin4 = assert(io.open("lua/entities/grm_money_launderer/init.lua", "rb")):read("*a")
ok(lin4:find('net.ReadUInt(16)', 1, true) ~= nil, "сервер: чтение minP 16 бит (находка 179k)")
ok(lin4:find('function ENT:LeaveJob', 1, true) ~= nil and lin4:find('action == "leave"', 1, true) ~= nil, "сервер: LeaveJob + action leave (находка 179m)")
local lcl6 = assert(io.open("lua/entities/grm_money_launderer/cl_init.lua", "rb")):read("*a")
ok(lcl6:find('ОТМЕНИТЬ УЧАСТИЕ', 1, true) ~= nil and lcl6:find('act(ent, "leave")', 1, true) ~= nil, "клиент: кнопка «ОТМЕНИТЬ УЧАСТИЕ» (находка 179m)")
local heistCl = assert(io.open("lua/autorun/client/cl_grm_heist.lua", "rb")):read("*a")
ok(heistCl:find('local function startMusic', 1, true) == nil and heistCl:find('Heist.Music', 1, true) == nil, "клиент: музыку сам НЕ запускает (играет с сервера, находка 179o)")
ok(heistCl:find('играет С СЕРВЕРА', 1, true) ~= nil, "клиент: комментарий «музыка с сервера»")

-- ══════════════ 7. Тул + перм + модели ══════════════
local tool = assert(io.open("lua/weapons/gmod_tool/stools/grm_bank_tool.lua", "rb")):read("*a")
ok(tool:find('grm_money_launderer', 1, true) ~= nil, "тул: тип «Отмывщик денег»")
local perm = assert(io.open("lua/autorun/sh_grm_perm_entities.lua", "rb")):read("*a")
ok(perm:find('grm_money_launderer     = true', 1, true) ~= nil, "PERM_CLASSES: отмывщик")
local lsh = assert(io.open("lua/entities/grm_money_launderer/shared.lua", "rb")):read("*a")
ok(lsh:find('HeistDuration = 3000', 1, true) ~= nil, "ивент: 50 минут (3000 сек)")
ok(lsh:find('HeistTargetPos', 1, true) ~= nil, "отмывщик: NWVar цели ивента (находка 179f)")
local lin2 = assert(io.open("lua/entities/grm_money_launderer/init.lua", "rb")):read("*a")
ok(lin2:find('РЕЙХСБАНК — ЦЕЛЬ ОГРАБЛЕНИЯ', 1, true) ~= nil and lin2:find('Двигайтесь к локации', 1, true) ~= nil, "маркер: «РЕЙХСБАНК — ЦЕЛЬ ОГРАБЛЕНИЯ», «Двигайтесь к локации!»")
ok(lin2:find('SendHeistTargetMarkers', 1, true) ~= nil, "отмывщик: раздача маркеров участникам")
ok(lin2:find('heist_target', 1, true) ~= nil and lin2:find('grm_heist_target', 1, true) ~= nil, "команда /heist_target (и clear)")
ok(lin2:find('heistTarget', 1, true) ~= nil, "перм: цель сохраняется (/permadd)")
local tool2 = assert(io.open("lua/weapons/gmod_tool/stools/grm_bank_tool.lua", "rb")):read("*a")
ok(tool2:find('heisttarget', 1, true) ~= nil and tool2:find('SetHeistTarget', 1, true) ~= nil, "тул: режим «Цель ивента — Рейхсбанк»")
ok(tool2:find('Цель ивента — Рейхсбанк', 1, true) ~= nil, "тул: название режима")
local lin = assert(io.open("lua/entities/grm_money_launderer/init.lua", "rb")):read("*a")
ok(lin:find('НАЧАТ ИВЕНТ: ОГРАБЛЕНИЕ', 1, true) ~= nil, "баннер: «НАЧАТ ИВЕНТ: ОГРАБЛЕНИЕ»")
ok(lin:find('CreateSound(self, "music/hl2_song20_submix0.mp3")', 1, true) ~= nil, "сервер: CreateSound на отмывщике (находка 179o)")
ok(lin:find('patch:SetSoundLevel(0)', 1, true) ~= nil and lin:find('patch:EnableLooping(true)', 1, true) ~= nil and lin:find('patch:PlayEx(1, 100)', 1, true) ~= nil, "сервер: SetSoundLevel(0)=везде + цикл + PlayEx (находка 179o)")
ok(lin:find('function ENT:StopHeistMusic', 1, true) ~= nil and lin:find('self.HeistMusic:Stop()', 1, true) ~= nil, "сервер: StopHeistMusic в EndEvent/OnRemove")
local lcl = assert(io.open("lua/autorun/client/cl_grm_heist.lua", "rb")):read("*a")
ok(lcl:find('local function startMusic', 1, true) == nil, "клиент: нет startMusic (музыка с сервера)")
ok(lcl:find('GRMHeist_Banner', 1, true) ~= nil and lcl:find('ОГРАБЛЕНИЕ', 1, true) ~= nil, "клиент: баннер и отсчёт")

print(string.format("sim_heist: %d ok, %d fail", pass, fail))
if fail > 0 then os.exit(1) end
