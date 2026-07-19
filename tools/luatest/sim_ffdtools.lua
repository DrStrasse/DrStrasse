-- Симуляция для кодов 102/103 (находки 119/120) БЕЗ GMod:
--  119: stools/ffd_keypad.lua BuildCPanel падал на combo:SetDock (метода нет).
--       Стенд ДОКАЗЫВАЕТ, что панель строится стандартным panel:ComboBox
--       и vgui.Create-ветки с SetDock больше нет (vgui нарочно НЕ создан —
--       любая регрессия тут же упадёт здесь).
--  120: lua/weapons/keypad.lua — «классический» кейпад-SWEP: спавн/снятие
--       с фидбеком (звук+notify), анти-спам кап 24 своих кейпада, ПКМ-гейты
--       владельца/суперадмана, и SWEP:ViewModelDrawn устойчив к двум стилям
--       вызова хука (method и «dot» с одним аргументом — у FFD-модов владельца
--       второй стиль = nil-call краш).
----------------------------------------------------------------------

string.Trim = string.Trim or function(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
function istable(x) return type(x) == "table" end
function isstring(x) return type(x) == "string" end
function isnumber(x) return type(x) == "number" end
function IsValid(o) return o ~= nil and o ~= false and not (istable(o) and o.__removed) end
function AddCSLuaFile() end

local H = { notifies = {}, sounds = {}, undo = {}, addons = {}, combos = {} }
local checks, failed = 0, 0
local function ok(cond, label)
  checks = checks + 1
  if cond then print("  ok " .. checks .. ". " .. label)
  else failed = failed + 1 print("  FAIL " .. checks .. ". " .. label) end
end

-- ── минимальный вектор с арифметикой (для Trace/Spawn) ──────────────
local mkVec -- форвард (урок 97/116: замыканию нужна декларация заранее)
local VMT = {}
VMT.__index = VMT
VMT.__add = function(a, b) return setmetatable({ x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }, VMT) end
VMT.__mul = function(a, k) return setmetatable({ x = a.x * k, y = a.y * k, z = a.z * k }, VMT) end
function VMT:Angle()
  return {
    Right = function() return mkVec(0, 1, 0) end,
    Up = function() return mkVec(0, 0, 1) end,
    RotateAroundAxis = function() end,
  }
end
mkVec = function(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, VMT) end

-- ── мир энтити ──────────────────────────────────────────────────────
local world, entCounter = {}, 0
ents = {
  Create = function(class)
    entCounter = entCounter + 1
    local e = { __class = class, __idx = entCounter }
    function e:SetPos(p) self.pos = p end
    function e:SetAngles(a) self.ang = a end
    function e:Spawn() self.spawned = true end
    function e:Activate() self.activated = true end
    function e:GetClass() return self.__class end
    function e:SetPassword(p) self.password = p end
    function e:GetPhysicsObject()
      self.__phys = self.__phys or { EnableMotion = function(_, m) e.frozen = (m == false) end }
      return self.__phys
    end
    function e:Remove() self.__removed = true world[self] = nil end
    world[e] = true
    return e
  end,
  FindByClass = function(class)
    local out = {}
    for e in pairs(world) do if not e.__removed and e.__class == class then out[#out + 1] = e end end
    return out
  end,
}

local mkPly
util = {
  TraceLine = function() return H.hit end,
}
undo = {
  Create = function(name) H.undo.name = name end,
  AddEntity = function(e) H.undo.ent = e end,
  SetPlayer = function(p) H.undo.ply = p end,
  Finish = function() H.undo.done = true end,
}
CurTime = function() return 0 end
GRM = { Notify = function(p, txt) H.notifies[#H.notifies + 1] = tostring(txt) end }

mkPly = function(nick, sa)
  local p = { __nick = nick, __sa = sa and true or false }
  function p:GetShootPos() return mkVec(0, 0, 0) end
  function p:GetAimVector() return mkVec(1, 0, 0) end
  function p:IsSuperAdmin() return self.__sa end
  function p:GetInfo() return "1234" end
  function p:GetInfoNum(_, d) return d end
  return p
end

local function lastNotify(pat)
  for i = #H.notifies, 1, -1 do if H.notifies[i]:find(pat) then return H.notifies[i] end end
  return nil
end

-- ══════════════════════ ЧАСТЬ 1: Код 102 / находка 119 ═══════════════
print("== stools/ffd_keypad.lua: BuildCPanel без SetDock-крэша ==")
TOOL = { ClientConVar = {} }
SERVER, CLIENT = false, false
-- vgui НАМЕРЕННО не создаём: старая реализация звала vgui.Create + SetDock
dofile("lua/weapons/gmod_tool/stools/ffd_keypad.lua")
ok(type(TOOL.BuildCPanel) == "function", "TOOL.BuildCPanel объявлен")

local panel = {}
function panel:AddControl(kind, data) H.addons[#H.addons + 1] = kind end
function panel:AddItem() end
function panel:ComboBox(label, convar)
  H.combos[#H.combos + 1] = { label = label, convar = convar, choices = {} }
  local c = H.combos[#H.combos]
  function c:AddChoice(text, data) self.choices[#self.choices + 1] = { text = text, data = data } end
  return c
end

local buildOK, buildErr = pcall(TOOL.BuildCPanel, panel)
ok(buildOK, "BuildCPanel(post-fix) строится без ошибок: " .. tostring(buildErr or ""))
ok(#H.combos == 1 and H.combos[1].convar == "ffd_keypad_mode",
   "режим — стандартный panel:ComboBox с привязкой к ffd_keypad_mode")
ok(#H.combos == 1 and #H.combos[1].choices == 3
   and H.combos[1].choices[1].data == 0 and H.combos[1].choices[2].data == 1
   and H.combos[1].choices[3].data == 2, "три режима кейпада: 0 PIN / 1 Faction / 2 Toll")
ok(#H.addons == 6, "AddControl: Header + PIN + 2×Numpad + 2×Slider (" .. #H.addons .. " шт)")

-- ══════════════════════ ЧАСТЬ 2: Код 103 / находка 120 ═══════════════
print("== lua/weapons/keypad.lua: классический кейпад-SWEP ==")
-- лоадер оружия GMod сам создаёт заготовку SWEP с Primary/Secondary —
-- стенд эмулирует это точно, иначе стандартные присваивания упадут за зря
SWEP = { Primary = {}, Secondary = {} }
dofile("lua/weapons/keypad.lua")
ok(SWEP.ClassName == "keypad" and SWEP.MaxOwnKeypads == 24 and SWEP.Spawnable == true,
   "SWEP зарегистрирован: class=keypad, кап 24, виден в Q-оружии")

local ply = mkPly("Владелец", false)
local admin = mkPly("Админ", true)
local function mkSwep(owner)
  -- в живом GMod self оружия несёт ВСЕ методы SWEP — наследуем их через __index
  return setmetatable({
    GetOwner = function() return owner end,
    SetNextPrimaryFire = function() end,
    SetNextSecondaryFire = function() end,
    EmitSound = function(_, snd) H.sounds[#H.sounds + 1] = snd end,
  }, { __index = SWEP })
end
local swp = mkSwep(ply)

H.hit = { Hit = true, HitPos = mkVec(5, 0, 0), HitNormal = mkVec(0, 0, 1), Entity = nil }
ok(SWEP.PrimaryAttack(swp) == true, "ЛКМ: кейпад поставлен")
local kat = ents.FindByClass("grm_keypad")[1]
ok(kat ~= nil and kat.spawned and kat.activated and kat.frozen == true and kat.password == "1234"
   and kat.KeypadOwner == ply, "энтити grm_keypad: спавн+активация+фриз+PIN 1234+владелец")
ok(H.undo.name == "GRM Keypad" and H.undo.done == true, "undo-запись оформлена")
ok(H.sounds[#H.sounds] == "buttons/button15.wav", "ЛКМ даёт звук-фидбек (у стула его не было)")
ok(lastNotify("установлен") ~= nil, "ЛКМ даёт notify-фидбек")

H.hit = { Hit = false }
ok(SWEP.PrimaryAttack(swp) == false and #ents.FindByClass("grm_keypad") == 1,
   "ЛКМ в пустоту — ничего не ставится")

-- кап 24 своих
for i = 1, 23 do
  local extra = ents.Create("grm_keypad")
  extra.KeypadOwner = ply
end
ok(SWEP.CountOwnKeypads(swp, ply) == 24, "засеяно 24 своих кейпада (предел)")
H.hit = { Hit = true, HitPos = mkVec(9, 0, 0), HitNormal = mkVec(0, 0, 1), Entity = nil }
ok(SWEP.PrimaryAttack(swp) == false and #ents.FindByClass("grm_keypad") == 24,
   "кап: 25-й кейпад этим инструментом не ставится")
ok(lastNotify("Лимит") ~= nil, "кап: вежливый отказ с объяснением")

-- ПКМ: снятие своего / чужого / суперадмином
local own = ents.FindByClass("grm_keypad")[1]
H.hit = { Hit = true, HitPos = mkVec(6, 0, 0), HitNormal = mkVec(0, 0, 1), Entity = own }
ok(SWEP.SecondaryAttack(swp) == true and not IsValid(own), "ПКМ: свой кейпад снят")
ok(H.sounds[#H.sounds] == "buttons/button6.wav", "ПКМ даёт звук-фидбек")

local alien = ents.Create("grm_keypad")
alien.KeypadOwner = mkPly("Чужой", false)
H.hit = { Hit = true, HitPos = mkVec(7, 0, 0), HitNormal = mkVec(0, 0, 1), Entity = alien }
ok(SWEP.SecondaryAttack(swp) == false and IsValid(alien), "ПКМ: чужой кейпад защищён")
ok(lastNotify("Чужой") ~= nil, "ПКМ: уведомление о чужом кейпаде")
ok(SWEP.SecondaryAttack(mkSwep(admin)) == true and not IsValid(alien),
   "ПКМ: суперадмин снимает любой кейпад")

-- находка 120: два стиля вызова ViewModelDrawn
local vmStub = { GetModel = function() return "models/weapons/c_toolgun.mdl" end }
local okStyle1 = pcall(SWEP.ViewModelDrawn, swp, vmStub)          -- method: (self, vm)
local okStyle2 = pcall(SWEP.ViewModelDrawn, vmStub)              -- dot: (vm) — ломал FFD
local okStyle3 = pcall(SWEP.ViewModelDrawn, swp, nil)            -- method с nil vm
ok(okStyle1 and okStyle2 and okStyle3, "ViewModelDrawn: оба стиля вызова без краша (FFA-совместимо)")

print("")
print(("РЕЗУЛЬТАТ: %d/%d проверок, провалов: %d"):format(checks - failed, checks, failed))
if failed > 0 then os.exit(1) end
print("SIM FFDTOOLS: OK")
