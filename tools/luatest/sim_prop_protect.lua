-- sim_prop_protect.lua — функциональная проверка проп-протектора (находка 179):
--   • IsManaged: prop_physics + ЛЮБАЯ серверная GRM-сущность (MarkServerEntity);
--   • обычный игрок НЕ может физганом/гравиганом/тулом трогать серверное;
--   • суперадмин — может;
--   • обычный чужой проп (prop_physics) — по-прежнему защищён (не сломали).
local pass, fail = 0, 0
local function ok(v, n) if v then pass = pass + 1 print("  ok  " .. n) else fail = fail + 1 print("  FAIL " .. n) end end

SERVER, CLIENT = true, false
function AddCSLuaFile() end
function isstring(v) return type(v) == "string" end
function istable(v) return type(v) == "table" end
function isfunction(v) return type(v) == "function" end
function IsValid(v) return v ~= nil and (type(v) == "table" and v.__valid ~= false or type(v) == "userdata") end
function print(...) local a = {} for i = 1, select("#", ...) do a[i] = tostring(select(i, ...)) end io.write(table.concat(a, " "), "\n") end
function Color(r, g, b) return { r = r or 0, g = g or 0, b = b or 0 } end
function CurTime() return 1000 end

local H = { hooks = {} }
hook = { Add = function(n, id, fn) H.hooks[n] = H.hooks[n] or {} H.hooks[n][id] = fn end, Run = function() end }
util = { AddNetworkString = function() end }
net = { Start = function() end, WriteTable = function() end, Send = function() end, Receive = function() end, ReadTable = function() return {} end }
file = { IsDir = function() return true end, CreateDir = function() end, Exists = function() return false end, Read = function() return nil end, Write = function() end, Find = function() return {} end }
game = { GetMap = function() return "rp_test" end }
concommand = { Add = function() end }

-- ── мок энтити ──
local EMT = {}
EMT.__index = function(t, k)
  if k == "GetClass" then return function(s) return s.__cls end
  elseif k == "GetNWString" then return function(s, key, d) local v = s.nw and s.nw[key]; if v == nil then return d or "" end return v end
  elseif k == "SetNWString" then return function(s, key, v) s.nw = s.nw or {} s.nw[key] = v end
  elseif k == "GetNWBool" then return function(s, key, d) local v = s.nw and s.nw[key]; if v == nil then return d == true end return v == true end
  elseif k == "SetNWBool" then return function(s, key, v) s.nw = s.nw or {} s.nw[key] = v == true end
  elseif k == "GetPhysicsObject" then return function() return { __valid = true, SetMaterial = function() end, SetFriction = function() end, SetDamping = function() end } end
  elseif k == "IsPlayer" then return function() return false end
  elseif k == "IsWorld" then return function() return false end
  elseif k == "CreatedByMap" then return function() return false end
  end
  return nil
end
local function mkEnt(cls)
  return setmetatable({ __cls = cls, __valid = true, nw = {} }, EMT)
end

-- ── мок игрока ──
local PMT = {}
PMT.__index = function(t, k)
  if k == "IsSuperAdmin" then return function(s) return s.super == true end
  elseif k == "IsPlayer" then return function() return true end
  elseif k == "SteamID64" then return function(s) return s.sid64 end
  elseif k == "SteamID" then return function() return "STEAM_0:1:1" end
  end
  return nil
end
local function mkPly(super)
  return setmetatable({ __valid = true, super = super == true, sid64 = super and "76561198000000001" or "76561198000000002" }, PMT)
end

GRM = {
  Identity = { CharacterKey = function(ply) return ply.sid64 .. ":char1" end },
  Notify = function() end,
}

-- ══════════════ ЗАГРУЗКА ══════════════
dofile("lua/autorun/sh_grm_prop_protect.lua")
local PP = GRM.PropProtect
ok(PP ~= nil and PP.IsServerEntity ~= nil and PP.IsOwnedEntity ~= nil and PP.CanInteract ~= nil, "проп-протектор v2 загружен")

-- ══════════════ 1. Классификация v2 ══════════════
local prop = mkEnt("prop_physics")
ok(PP.IsOwnedEntity(prop) == false, "непомеченный prop_physics не имеет владельца")
local vault = mkEnt("grm_bank_vault")
ok(PP.IsServerEntity(vault) == true, "известное банковское оборудование серверное без ручной метки")
PP.MarkServerEntity(vault)
ok(vault:GetNWString("GRM_EntityOwnerType", "") == "server", "MarkServerEntity пометил сущность")
ok(PP.IsOwnedEntity(vault) == true, "серверное оборудование считается управляемым контуром")
local press = mkEnt("grm_money_press")
PP.MarkServerEntity(press)
ok(PP.IsServerEntity(press) == true, "grm_money_press с меткой server: под защитой")
local alarm = mkEnt("grm_alarm_hub")
PP.MarkServerEntity(alarm)
ok(PP.IsServerEntity(alarm) == true, "grm_alarm_hub с меткой server: под защитой")

-- ══════════════ 2. CanInteract ══════════════
local player = mkPly(false)
local admin = mkPly(true)
ok(PP.CanInteract(player, vault, "physgun") == false, "игрок: НЕ может физганить серверное (находка 179)")
ok(PP.CanInteract(player, vault, "tool") == false, "игрок: НЕ может тулить серверное")
ok(PP.CanInteract(player, vault, "remove") == false, "игрок: НЕ может удалять серверное")
ok(PP.CanInteract(admin, vault, "physgun") == true, "суперадмин: может физганить серверное")
ok(PP.CanInteract(admin, vault, "tool") == true, "суперадмин: может тулить серверное")
ok(PP.CanInteract(admin, vault, "remove") == true, "суперадмин: может удалять серверное")


-- ══════════════ 3. Механизированные двери ══════════════
local ffd = mkEnt("prop_physics")
ffd.isFadingDoor, ffd.FFD_IsFaded, ffd.FFD_IsActive = true, true, true
ok(PP.IsMechanizedDoor(ffd) == true and PP.IsDoorBusy(ffd) == true,
   "FFD: исчезнувшая дверь распознана как busy")
ok(PP.CanInteract(admin, ffd, "physgun") == false, "FFD busy: даже суперадмину запрещён физган")
ok(PP.CanInteract(admin, ffd, "tool") == false, "FFD busy: даже суперадмину запрещён tool")
ok(PP.CanInteract(admin, ffd, "remove") == false, "FFD busy: даже суперадмину запрещено удаление")
ok(PP.CanInteract(admin, ffd, "use") == true, "FFD busy: управляющее использование не блокируется")
ok(PP.CanInteract(admin, ffd, "door_control") == true, "FFD busy: сигнал контроллера не блокируется")
ffd.FFD_IsFaded, ffd.FFD_IsActive = false, false
ok(PP.IsDoorBusy(ffd) == false and PP.CanInteract(admin, ffd, "tool") == true,
   "FFD closed: стабильная дверь снова доступна суперадмину")
ffd.FFD_Reversed, ffd.FFD_IsActive = true, true
ok(PP.IsDoorBusy(ffd) == false, "FFD reversed: видимое active-состояние не принято за исчезновение")

local sliding = mkEnt("prop_physics")
sliding.isSlidingDoor, sliding.Sliding_Open, sliding.Sliding_Progress = true, true, 1
ok(PP.IsDoorBusy(sliding) == true and PP.CanInteract(admin, sliding, "physgun") == false
   and PP.CanInteract(admin, sliding, "tool") == false,
   "Sliding open/moving: физган и tool запрещены даже суперадмину")
sliding.Sliding_Open, sliding.Sliding_Progress = false, 0
ok(PP.IsDoorBusy(sliding) == false and PP.CanInteract(admin, sliding, "physgun") == true,
   "Sliding closed: стабильная дверь снова доступна")

local ppSource = assert(io.open("lua/autorun/sh_grm_prop_protect.lua", "rb")):read("*a")
ok(ppSource:find("if PP.IsMechanizedDoor(ent) then return end", 1, true) ~= nil,
   "stablePhysics не меняет физику механизированных дверей")

-- ══════════════ 4. Хуки ══════════════
local physHook = H.hooks["PhysgunPickup"]["GRM_PropProtect_Physgun"]
local gravHook = H.hooks["GravgunPickup"]["GRM_PropProtect_Gravgun"]
local gravPunt = H.hooks["GravgunPunt"]["GRM_PropProtect_GravgunPunt"]
ok(physHook ~= nil, "хук PhysgunPickup зарегистрирован")
ok(gravHook ~= nil, "хук GravgunPickup зарегистрирован (находка 179)")
ok(gravPunt ~= nil, "хук GravgunPunt зарегистрирован (находка 179)")

ok(physHook(player, vault) == false, "PhysgunPickup: игроку запрещено (server)")
ok(physHook(admin, vault) == true, "PhysgunPickup: суперадмину разрешено (server)")
ok(physHook(player, prop) == false, "PhysgunPickup: чужой проп игроку запрещено (прежнее)")
ok(gravHook(player, vault) == false, "GravgunPickup: игроку запрещено (server)")
ok(gravHook(admin, vault) == true, "GravgunPickup: суперадмину разрешено (server)")
ok(gravPunt(player, vault) == false, "GravgunPunt: игроку запрещено (server)")
ok(gravPunt(admin, vault) == nil or gravPunt(admin, vault) == true, "GravgunPunt: суперадмин не блокируется")

print(string.format("sim_prop_protect: %d ok, %d fail", pass, fail))
if fail > 0 then os.exit(1) end
