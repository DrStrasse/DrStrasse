-- sim_bank_vault.lua — функциональная проверка банковской системы (находка 178):
--   • хранилище: регистрация, Capacity=500000, синк госбюджета (StateBudget);
--   • станок: печать 5000 GRM / 10 сек в гос.бюджет, паллеты в хранилище,
--     прокачка скорости (+50% за уровень), перегрев → остановка, охлаждение;
--   • вместимость хранилища 500.000 — паллеты не спавнятся сверх лимита;
--   • процент со штрафа (statePercent): доля штрафа идёт в гос.бюджет;
--   • save_entry: не-суперадмин может менять statePercent, но не систему;
--   • кнопка «Установить» в гос.бюджете — только суперадмин (статически);
--   • тул grm_bank_tool + Q-меню + PERM_CLASSES.
local pass, fail = 0, 0
local function ok(v, n) if v then pass = pass + 1 print("  ok  " .. n) else fail = fail + 1 print("  FAIL " .. n) end end

SERVER, CLIENT = true, false
function AddCSLuaFile() end
include = function(p)
  if p == "shared.lua" then return end -- shared загружается вручную (ENT-мок)
  dofile("lua/" .. p)
end
function isstring(v) return type(v) == "string" end
function istable(v) return type(v) == "table" end
function isfunction(v) return type(v) == "function" end
function isnumber(v) return type(v) == "number" end
function IsValid(v) return v ~= nil and (type(v) == "table" and v.__valid ~= false or type(v) == "userdata") end
function CurTime() return _G.__now or 1000 end
function print(...) local a = {} for i = 1, select("#", ...) do a[i] = tostring(select(i, ...)) end io.write(table.concat(a, " "), "\n") end
function Color(r, g, b) return { r = r or 0, g = g or 0, b = b or 0 } end
function string.Trim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
function math.Clamp(v, a, b) return math.max(a, math.min(b, v)) end
function table.Count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
function table.Copy(t) local o = {} for k, v in pairs(t or {}) do o[k] = type(v) == "table" and table.Copy(v) or v end return o end

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

-- ── мок окружения ──
local H = { hooks = {}, timers = {}, netrecv = {}, cmds = {} }
hook = { Add = function(n, id, fn) H.hooks[n] = H.hooks[n] or {} H.hooks[n][id] = fn end, Run = function() end }
timer = { Create = function(n, _, _, fn) H.timers[n] = fn end, Simple = function() end }
concommand = { Add = function(n, fn) H.cmds[n] = fn end }
util = { AddNetworkString = function() end, TableToJSON = function() return "{}" end, JSONToTable = function() return nil end, IsValidModel = function() return true end }
file = { IsDir = function() return true end, CreateDir = function() end, Exists = function() return false end, Read = function() return nil end, Write = function() end, Find = function() return {} end }
os = { time = function() return 1700000000 end, date = function() return "2026-08-05" end }
game = { GetMap = function() return "rp_test" end }
ents = { Create = function(cls) local e = mkEnt(cls) return e end, FindInSphere = function() return {} end }
player = { GetAll = function() return _G.__players or {} end }
net = {
  Start = function() end, WriteEntity = function() end, WriteString = function() end, WriteBool = function() end,
  WriteUInt = function() end, WriteTable = function() end, Send = function() end, Broadcast = function() end,
  Receive = function(n, fn) H.netrecv[n] = fn end, ReadEntity = function() return nil end, ReadString = function() return "" end,
  ReadBool = function() return false end, ReadTable = function() return {} end, ReadUInt = function() return 0 end,
}
numpad = { Register = function() end, OnDown = function() end, OnUp = function() end, Remove = function() end, Activate = function() end, Deactivate = function() end }
duplicator = { StoreEntityModifier = function() end, RegisterEntityModifier = function() end }
_F = {}
Entity = function(idx) return _F[idx] end
GRM = {
  Notify = function() end,
  Format = function(n) return tostring(math.floor(tonumber(n) or 0)) .. " GRM" end,
  GiveMoney = function() end, TakeMoney = function() return true end, HasMoney = function() return true end,
  GetAllBalances = function() return {} end,
  Identity = { CharacterKey = function(ply) return ply.sid64 .. ":char1" end },
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
  elseif k == "SetSkin" then return function() end
  elseif k == "SetMaterial" then return function() end
  elseif k == "SetColor" then return function() end
  elseif k == "SetRenderMode" then return function() end
  elseif k == "SetLOD" then return function() end
  elseif k == "DrawShadow" then return function() end
  elseif k == "PhysicsInit" then return function() end
  elseif k == "SetMoveType" then return function() end
  elseif k == "SetSolid" then return function() end
  elseif k == "SetUseType" then return function() end
  elseif k == "SetCollisionGroup" then return function() end
  elseif k == "SetCreator" then return function() end
  elseif k == "SetOwner" then return function() end
  elseif k == "GetPhysicsObject" then return function() return { EnableMotion = function() end, Wake = function() end } end
  elseif k == "Spawn" then return function() end
  elseif k == "Activate" then return function() end
  elseif k == "Remove" then return function(s) if s.__valid ~= false and s.OnRemove then s:OnRemove() end s.__valid = false end
  elseif k == "EmitSound" then return function() end
  elseif k == "IsPlayer" then return function() return false end
  elseif k == "IsNPC" then return function() return false end
  elseif k == "IsWorld" then return function() return false end
  elseif k == "IsValid" then return function(s) return s.__valid ~= false end
  elseif k == "NextThink" then return function() end
  elseif k == "GetModel" then return function() return "models/x.mdl" end
  elseif k == "GetOwnerSID64" then return function(s) return s.ownerSID or "" end
  elseif k == "SetOwnerSID64" then return function(s, v) s.ownerSID = v end
  end
  return nil
end
local nextIdx = 1
local function mkEnt(cls)
  local e = setmetatable({ __cls = cls, __entClass = cls, __valid = true, __idx = nextIdx, nw = {} }, EMT)
  nextIdx = nextIdx + 1
  _F[e.__idx] = e
  -- NetworkVar-помощники
  local vars = {}
  function e:SetNWVar(k, v) vars[k] = v end
  function e:GetNWVar(k) return vars[k] end
  -- DataTables-подобные сеттеры/геттеры (создаются в SetupDataTables)
  return e
end

-- ── мок игрока ──
local PMT = {}
PMT.__index = function(t, k)
  if k == "IsSuperAdmin" then return function(s) return s.super == true end
  elseif k == "IsPlayer" then return function() return true end
  elseif k == "Alive" then return function() return true end
  elseif k == "Nick" then return function(s) return s.nick or "Игрок" end
  elseif k == "SteamID64" then return function(s) return s.sid64 end
  elseif k == "SteamID" then return function() return "STEAM_0:1:1" end
  elseif k == "GetPos" then return function(s) return s.pos or Vector(0, 0, 0) end
  end
  return nil
end
local function mkPly(super, nick)
  return setmetatable({ __valid = true, super = super == true, nick = nick or "Игрок", sid64 = super and "76561198000000001" or "76561198000000002", pos = Vector(0, 0, 0) }, PMT)
end

-- ══════════════ ЗАГРУЗКА ══════════════
dofile("lua/autorun/sh_grm_economy.lua")
local E = GRM.Economy
ok(E ~= nil and E.RegisterVault ~= nil and E.SpawnVaultCash ~= nil and E.DropCashToVault ~= nil, "economy: реестр хранилищ + дроп")

-- ══════════════ 1. ХРАНИЛИЩЕ ══════════════
ENT = {}
dofile("lua/entities/grm_bank_vault/shared.lua")
dofile("lua/entities/grm_bank_vault/init.lua")
entClasses["grm_bank_vault"] = {}
for k, v in pairs(ENT) do entClasses["grm_bank_vault"][k] = v end
local vault = mkEnt("grm_bank_vault")
vault:SetPos(Vector(0, 0, 0))
-- эмуляция DataTables-методов (нет реального SetupDataTables в моке)
vault.GetCapacity = function() return vault.__cap or 500000 end
vault.SetCapacity = function(_, v) vault.__cap = v end
vault.GetHeldCash = function() return vault.__held or 0 end
vault.SetHeldCash = function(_, v) vault.__held = v end
vault.GetStateBudget = function() return vault.__sb or 0 end
vault.SetStateBudget = function(_, v) vault.__sb = v end
vault:Initialize()

ok(E.Vaults[vault:EntIndex()] == vault, "хранилище зарегистрировано в реестре")
ok(vault:GetCapacity() == 500000, "вместимость хранилища 500.000")

-- синк госбюджета
E.StateBudgetSet(1234567, "тест")
ok(vault:GetStateBudget() == 1234567, "дисплей хранилища обновился после StateBudgetSet (реальное время)")
E.StateBudgetAdd(5000, "печать")
ok(vault:GetStateBudget() == 1239567, "дисплей обновился после StateBudgetAdd")

-- ══════════════ 2. ПАЛЛЕТЫ + ВМЕСТИМОСТЬ ══════════════
-- мок grm_vault_cash
ENT = {}
dofile("lua/entities/grm_vault_cash/shared.lua")
dofile("lua/entities/grm_vault_cash/init.lua")
entClasses["grm_vault_cash"] = {}
for k, v in pairs(ENT) do entClasses["grm_vault_cash"][k] = v end
local function mkCashEnt()
  local e = mkEnt("grm_vault_cash")
  e.GetAmount = function() return e.__amt or 0 end
  e.SetAmount = function(_, v) e.__amt = v end
  e:Initialize()
  return e
end
-- переопределим ents.Create для паллет
local origCreate = ents.Create
ents.Create = function(cls)
  if cls == "grm_vault_cash" then return mkCashEnt() end
  return origCreate(cls)
end

local spawned = E.SpawnVaultCash(vault, 200000)
ok(spawned == 200000, "паллета на 200.000 заспавнена в хранилище")
ok(vault:GetHeldCash() == 200000, "HeldCash хранилища = 200.000")
spawned = E.SpawnVaultCash(vault, 500000)
ok(spawned == 300000, "вместимость 500.000: сверх лимита не лезет (заспавнено 300.000)")
ok(vault:GetHeldCash() == 500000, "HeldCash упёрся в 500.000")
spawned = E.SpawnVaultCash(vault, 1000)
ok(spawned == 0, "хранилище заполнено — паллеты не спавнятся")

-- подбор паллеты освобождает место
local cash = mkCashEnt()
cash:SetAmount(250000)
cash.Vault = vault
cash._picked = true -- имитация подбора
cash:Remove() -- OnRemove с _picked=true НЕ уменьшает (уже уменьшено при подборе)
ok(vault:GetHeldCash() == 500000, "подобранная паллета не уменьшает дважды")
-- обычное удаление (паллета исчезла/уничтожена) — уменьшает
local cash2 = mkCashEnt()
cash2:SetAmount(100000)
cash2.Vault = vault
cash2:Remove()
ok(vault:GetHeldCash() == 400000, "уничтоженная паллета вернула место в хранилище")

-- ══════════════ 3. ДРОП ИЗ ПАНЕЛИ (пополнить/изъять) ══════════════
local ply = mkPly(false, "Банкир")
ply.pos = Vector(10, 10, 10)
vault:SetHeldCash(0)
local before = E.StateBudgetGet()
-- state_give через NET_ADMIN_ACT
local recvAct = H.netrecv["GRM_Eco_AdminAction"]
ok(recvAct ~= nil, "обработчик NET_ADMIN_ACT есть")
local gave = 0
ents.Create = function(cls)
  if cls == "grm_vault_cash" then gave = gave + 1 return mkCashEnt() end
  return origCreate(cls)
end
_G.__players = { ply }
-- эмулируем net-чтение: проще вызвать напрямую внутреннюю логику — дроп
local dropped = E.DropCashToVault(ply, 50000)
ok(dropped == 50000, "DropCashToVault: 50.000 дропнуты в хранилище (пополнение)")
ok(vault:GetHeldCash() == 50000, "HeldCash после дропа = 50.000")

-- ══════════════ 4. ПЕЧАТНЫЙ СТАНОК ══════════════
ENT = {}
dofile("lua/entities/grm_money_press/shared.lua")
dofile("lua/entities/grm_money_press/init.lua")
entClasses["grm_money_press"] = {}
for k, v in pairs(ENT) do entClasses["grm_money_press"][k] = v end
local press = mkEnt("grm_money_press")
press:SetPos(Vector(50, 50, 0))
press.GetActive = function() return press.__active end
press.SetActive = function(_, v) press.__active = v end
press.GetBroken = function() return press.__broken end
press.SetBroken = function(_, v) press.__broken = v end
press.GetSpeedLevel = function() return press.__lvl or 0 end
press.SetSpeedLevel = function(_, v) press.__lvl = v end
press.GetHeat = function() return press.__heat or 0 end
press.SetHeat = function(_, v) press.__heat = v end
press.GetPrintInterval = function() return press.__pi or 10 end
press.SetPrintInterval = function(_, v) press.__pi = v end
press.GetPrintAmount = function() return press.__pa or 5000 end
press.SetPrintAmount = function(_, v) press.__pa = v end
press.GetTotalPrinted = function() return press.__tp or 0 end
press.SetTotalPrinted = function(_, v) press.__tp = v end
press.OwnerPlayer = function() return nil end
press:Initialize()
press:SetActive(true) press:SetBroken(false) press:SetSpeedLevel(0) press:SetHeat(0)
press:SetPrintInterval(10) press:SetPrintAmount(5000) press:SetTotalPrinted(0)
press:SetOwnerSID64("")

ok(GRM.MoneyPress[press:EntIndex()] == press, "станок в реестре")
ok(press:AmountPerCycle() == 5000, "базовая печать 5000 GRM за цикл")
ok(press:GetPrintInterval() == 10, "цикл 10 секунд")

-- печать: бюджет +5000, паллета в хранилище
vault:SetHeldCash(0)
local beforePrint = E.StateBudgetGet()
local palletsBefore = 0
-- посчитаем спавн паллет через DropCashToVault-путь (SpawnVaultCash)
press:PrintMoney()
ok(E.StateBudgetGet() == beforePrint + 5000, "печать добавила 5000 в гос.бюджет")
ok(vault:GetHeldCash() >= 5000, "паллета на 5000 дропнута в хранилище")
ok(press:GetTotalPrinted() == 5000, "TotalPrinted = 5000")
ok(press:GetHeat() == 6, "нагрев +6 за цикл")

-- прокачка скорости: уровень 1 → 7500 (действия станка — суперадмин/доступ)
local admin = mkPly(true, "Владелец")
press:PressUpgrade(admin)
ok(press:GetSpeedLevel() == 1 and press:GetPrintAmount() == 7500, "прокачка: ур.1 = 7500 GRM/цикл")

-- перегрев: heat до 100 → остановка
press:SetHeat(100)
press:Think()
ok(press:GetActive() == false, "перегрев → станок остановлен")

-- охлаждение
press:PressCool(admin)
ok(press:GetHeat() == 0, "охлаждение сбросило нагрев")
press:SetActive(true)
ok(press:GetActive() == true, "после охлаждения можно запустить")

-- ══════════════ 5. ПРОЦЕНТ СО ШТРАФА ══════════════
-- ставим finePerms.statePercent = 20 для фракции "Polizei"
Factions = { Polizei = { Members = { ["STEAM_0:1:1"] = { Role = "Officer" } }, Leader = "STEAM_0:1:1", Roles = { "Officer" }, Departments = {} } }
local e = E._dev_entry and E._dev_entry("Polizei") or nil
ok(e ~= nil, "entry('Polizei') доступен")
e.finePerms.statePercent = 20
e.finePerms.enabled = true
e.finePerms.ownFaction = true

local target = mkPly(false, "Штрафуемый")
target.pos = Vector(0, 0, 0)
local issuer = mkPly(false, "Полицейский")
issuer.pos = Vector(0, 0, 0)
GRM.GetBalance = function() return 10000 end
local taken = 0
GRM.TakeMoney = function(_, amt) taken = amt return true end
local facAdded = 0
GRM.FactionBudgetAdd = function(_, amt) facAdded = amt end
local beforeFine = E.StateBudgetGet()
-- E.Fine(issuer, target, amount, reason)
local okFine, issued = E.Fine(issuer, target, 1000, "нарушение")
ok(okFine == true and issued == 1000, "штраф 1000 выписан")
ok(facAdded == 800, "80% штрафа (800) ушло в бюджет фракции")
ok(E.StateBudgetGet() == beforeFine + 200, "20% штрафа (200) ушло в гос.бюджет (процент)")

-- ══════════════ 6. save_entry: не-суперадмин может менять statePercent ══════════════
-- (статическая проверка: сервер принимает statePercent от всех)
local econCode = assert(io.open("lua/autorun/sh_grm_economy.lua", "rb")):read("*a")
ok(econCode:find('fp.statePercent = math.Clamp(math.floor(tonumber(a.fine.statePercent) or (fp.statePercent or 0)), 0, 100)', 1, true) ~= nil, "сервер: statePercent сохраняется от всех с доступом")
ok(econCode:find('if ply:IsSuperAdmin() then', 1, true) ~= nil, "сервер: система штрафов — суперадмин")

-- ══════════════ 7. Кнопка «Установить» — только суперадмин ══════════════
ok(econCode:find('«Установить» гос.бюджет — только суперадмин', 1, true) ~= nil, "клиент: комментарий-ограничение «Установить»")
ok(econCode:find('if isSuper then', 1, true) ~= nil, "клиент: isSuper ветка для «Установить»")

-- ══════════════ 8. ТУЛ + Q-МЕНЮ + PERM ══════════════
local tool = assert(io.open("lua/weapons/gmod_tool/stools/grm_bank_tool.lua", "rb")):read("*a")
ok(tool:find('TOOL.Name = "#tool.grm_bank_tool.name"', 1, true) ~= nil, "тул grm_bank_tool существует")
ok(tool:find('grm_bank_vault', 1, true) ~= nil and tool:find('grm_money_press', 1, true) ~= nil and tool:find('grm_money_press_terminal', 1, true) ~= nil, "тул: все три типа")
ok(tool:find('CanManageEconomy', 1, true) ~= nil, "тул: права CanManageEconomy")
local q = assert(io.open("lua/autorun/sh_grm_qmenu.lua", "rb")):read("*a")
ok(q:find('grm_bank_tool', 1, true) ~= nil, "Q-меню: банковский тул")
local perm = assert(io.open("lua/autorun/sh_grm_perm_entities.lua", "rb")):read("*a")
ok(perm:find('grm_bank_vault', 1, true) ~= nil and perm:find('grm_money_press', 1, true) ~= nil and perm:find('grm_money_press_terminal', 1, true) ~= nil, "PERM_CLASSES: все три класса")

-- ══════════════ 9. Модели ══════════════
local vsh = assert(io.open("lua/entities/grm_bank_vault/shared.lua", "rb")):read("*a")
ok(vsh:find('ground_locker_small.mdl', 1, true) ~= nil, "хранилище: модель ground_locker_small.mdl")
local psh = assert(io.open("lua/entities/grm_money_press/shared.lua", "rb")):read("*a")
ok(psh:find('hatch_frame.mdl', 1, true) ~= nil, "станок: модель hatch_frame.mdl")
ok(psh:find('BaseAmount    = 5000', 1, true) ~= nil and psh:find('BaseInterval  = 10', 1, true) ~= nil, "станок: 5000 GRM / 10 сек")
local tsh = assert(io.open("lua/entities/grm_money_press_terminal/shared.lua", "rb")):read("*a")
ok(tsh:find('holo_wall_unit.mdl', 1, true) ~= nil, "терминал: модель holo_wall_unit.mdl")
local csh = assert(io.open("lua/entities/grm_vault_cash/shared.lua", "rb")):read("*a")
ok(csh:find('moneypalleta.mdl', 1, true) ~= nil, "паллета: модель moneypalleta.mdl")

print(string.format("sim_bank_vault: %d ok, %d fail", pass, fail))
if fail > 0 then os.exit(1) end
