-- Симуляция для кодов 102/103/104/105 (находки 119/120/122) БЕЗ GMod:
--  119: stools/ffd_keypad.lua BuildCPanel падал на combo:SetDock (метода нет).
--       Стенд ДОКАЗЫВАЕТ, что панель строится стандартным panel:ComboBox
--       и vgui.Create+SetDock-ветки больше нет.
--  120: lua/weapons/keypad.lua — «классический» кейпад-SWEP: спавн/снятие
--       с фидбеком, кап 24 своих кейпада, ПКМ-гейты владельца/суперадмина,
--       SWEP:ViewModelDrawn устойчив к двум стилям вызова хука.
--  122: (Код 105, три замечания владельца)
--       а) поля «задать PIN» не было: AddControl("TextEntry") — несуществующее
--          имя контрола молча пропускалось. Теперь DForm-хелпер
--          panel:TextEntry(label, convar) с фолбэком AddControl("TextBox").
--       б) 3D2D-панель была повёрнута на 180° и съехала: угол теперь строится
--          напрямую из базиса модели через Vector:AngleEx (без пар
--          RotateAroundAxis), масштаб — по морде модели (OBBMins/OBBMaxs).
--       в) админский перм: sh_grm_perm_entities v1.3.0 + GRM.PermData —
--          /permadd по кейпаду/FFD-двери пишет rec.data (PIN, режим,
--          фракции, конфиг двери), /permload восстанавливает после рестарта.
----------------------------------------------------------------------

string.Trim = string.Trim or function(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
function istable(x) return type(x) == "table" end
function isstring(x) return type(x) == "string" end
function isnumber(x) return type(x) == "number" end
function IsValid(o) return o ~= nil and o ~= false and not (istable(o) and o.__removed) end
function AddCSLuaFile() end
math.Clamp = math.Clamp or function(v, a, b) if v < a then return a end if v > b then return b end return v end
HUD_PRINTTALK = HUD_PRINTTALK or 3

local H = { notifies = {}, sounds = {}, undo = {}, addons = {}, combos = {},
            hooks = {}, npad = {}, netmsg = nil, convars = { ["ffd_keypad_faction"] = "" },
            textentries = {} }
local checks, failed = 0, 0
local function ok(cond, label)
  checks = checks + 1
  if cond then print("  ok " .. checks .. ". " .. label)
  else failed = failed + 1 print("  FAIL " .. checks .. ". " .. label) end
end

-- ── минимальный вектор с арифметикой (для Trace/Spawn/экрана) ────────
local mkVec -- форвард (урок 97/116: замыканию нужна декларация заранее)
local VMT = {}
VMT.__index = VMT
VMT.__add = function(a, b) return setmetatable({ x = a.x + b.x, y = a.y + b.y, z = a.z + b.z }, VMT) end
VMT.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, VMT) end
VMT.__mul = function(a, k) return setmetatable({ x = a.x * k, y = a.y * k, z = a.z * k }, VMT) end
VMT.__unm = function(a) return setmetatable({ x = -a.x, y = -a.y, z = -a.z }, VMT) end
function VMT:Dot(b) return self.x * b.x + self.y * b.y + self.z * b.z end
function VMT:DistToSqr(b) local dx, dy, dz = self.x - b.x, self.y - b.y, self.z - b.z return dx * dx + dy * dy + dz * dz end
function VMT:GetNormalized()
  local l = math.sqrt(self.x * self.x + self.y * self.y + self.z * self.z)
  if l == 0 then return mkVec(0, 0, 0) end
  return mkVec(self.x / l, self.y / l, self.z / l)
end
function VMT:Cross(b)
  return mkVec(self.y * b.z - self.z * b.y, self.z * b.x - self.x * b.z, self.x * b.y - self.y * b.x)
end
-- Vector:AngleEx(up) — GMod API: Forward=v, Up=up, Right=F×U (находка 122)
function VMT:AngleEx(up)
  local f = self:GetNormalized()
  local r = f:Cross(up):GetNormalized()
  local u = up:GetNormalized()
  return { p = 0, y = 0, r = 0,
    Forward = function() return f end,
    Right = function() return r end,
    Up = function() return u end,
    RotateAroundAxis = function() end }
end
function VMT:Angle()
  return { p = 0, y = 0, r = 0,
    Right = function() return mkVec(0, 1, 0) end,
    Up = function() return mkVec(0, 0, 1) end,
    RotateAroundAxis = function() end,
  }
end
mkVec = function(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, VMT) end
Vector = function(x, y, z) return mkVec(x, y, z) end
Angle = function(p, y, r) return { p = p or 0, y = y or 0, r = r or 0 } end

-- ── мир энтити ──────────────────────────────────────────────────────
local world, entCounter = {}, 0
ents = {
  Create = function(class)
    entCounter = entCounter + 1
    local e
    -- Код 105 часть 5: для кейпада — полноценный стаб фабрики
    if class == "grm_keypad" and rawget(_G, "__mkKeypadEnt") then
      e = __mkKeypadEnt()
    else
      e = { __class = class }
    end
    e.__idx = entCounter
    e.__class = e.__class or class
    if not e.SetPos then function e:SetPos(p) self.pos = p end end
    if not e.GetPos then function e:GetPos() return self.pos or mkVec(0, 0, 0) end end
    if not e.SetAngles then function e:SetAngles(a) self.ang = a end end
    if not e.GetAngles then function e:GetAngles() return self.ang or { p = 0, y = 0, r = 0 } end end
    if not e.Spawn then function e:Spawn() self.spawned = true end end
    if not e.Activate then function e:Activate() self.activated = true end end
    if not e.GetClass then function e:GetClass() return self.__class end end
    if not e.SetPassword then function e:SetPassword(p) self.password = p end end
    if not e.SetModel then function e:SetModel(m) self.model = m end end
    if not e.GetModel then function e:GetModel() return self.model or "" end end
    if not e.SetNotSolid then function e:SetNotSolid(v) self.notsolid = v end end
    if not e.SetRenderMode then function e:SetRenderMode(v) self.rendermode = v end end
    if not e.SetColor then function e:SetColor(v) self.color = v end end
    if not e.DrawShadow then function e:DrawShadow(v) self.shadow = v end end
    if not e.SetNWBool then function e:SetNWBool(k, v) self.__nwb = self.__nwb or {} self.__nwb[k] = v end end
    if not e.EmitSound then function e:EmitSound() end end
    if not e.EntIndex then function e:EntIndex() return self.__idx end end
    if not e.GetPhysicsObject then
      function e:GetPhysicsObject()
        self.__phys = self.__phys or {
          EnableMotion = function(_, m) e.frozen = (m == false) end,
          EnableCollisions = function(_, c) e.collisions = c end,
          Wake = function() end,
        }
        return self.__phys
      end
    end
    if not e.Remove then function e:Remove() self.__removed = true world[self] = nil end end
    world[e] = true
    return e
  end,
  FindByClass = function(class)
    local out = {}
    for e in pairs(world) do if not e.__removed and e.__class == class then out[#out + 1] = e end end
    return out
  end,
  FindInSphere = function(c, r)
    local out = {}
    for e in pairs(world) do
      if not e.__removed then
        local okp, p = pcall(function() return e:GetPos() end)
        if okp and p and p.DistToSqr and p:DistToSqr(c) <= r * r then out[#out + 1] = e end
      end
    end
    return out
  end,
}

local mkPly
util = {
  TraceLine = function() return H.hit end,
  AddNetworkString = function() end,
}
undo = {
  Create = function(name) H.undo.name = name end,
  AddEntity = function(e) H.undo.ent = e end,
  SetPlayer = function(p) H.undo.ply = p end,
  Finish = function() H.undo.done = true end,
}
CurTime = function() return H.t or 0 end
GRM = { Notify = function(p, txt) H.notifies[#H.notifies + 1] = tostring(txt) end }
IN_USE = IN_USE or 5

-- шимы для Кода 104/105: панель (DForm+vgui), конвары, файл/JSON, numpad
GetConVar = function(n) return { GetString = function() return (H.convars or {})[n] or "" end } end
RunConsoleCommand = function(n, v) RC_Last = { name = n, val = v } end
vgui = { Create = function(cls)
  local c = { _cls = cls, __children = true }
  function c:SetTall(v) self.tall = v end
  function c:Dock() end
  function c:DockMargin() end
  function c:SetText(t) self.text = t end
  function c:SetChecked(v) self.checked = v end
  function c:SetPaintBackground() end
  H.vguis = H.vguis or {}
  H.vguis[#H.vguis + 1] = c
  return c
end }
hook = { Add = function(name, id, fn) H.hooks[name .. "/" .. id] = fn end, Run = function() end }
timer = { Create = function() end, Simple = function() end, Remove = function() end }
numpad = {
  Activate = function(p, k) H.npad[#H.npad + 1] = k end,
  Deactivate = function() end,
  OnDown = function() H.npadDown = (H.npadDown or 0) + 1 return "nd" end,
  OnUp = function() H.npadUp = (H.npadUp or 0) + 1 return "nu" end,
  Remove = function() end,
  Register = function(name, fn) H.npadReg = H.npadReg or {} H.npadReg[name] = fn end,
}
net = {
  Start = function(m) H.netmsg = m H.netf = {} end,
  WriteEntity = function(v) if H.netf then H.netf[#H.netf + 1] = v end end,
  WriteUInt = function(v) if H.netf then H.netf[#H.netf + 1] = v end end,
  WriteString = function(v) if H.netf then H.netf[#H.netf + 1] = v end end,
  Broadcast = function() H.bcasts = H.bcasts or {} H.bcasts[#H.bcasts + 1] = H.netmsg H.netmsg = nil end,
  Send = function() H.netmsg = nil end,
  Receive = function(m, fn) H.netrecv = H.netrecv or {} H.netrecv[m] = fn end,
}
duplicator = {
  RegisterEntityModifier = function(n, fn) H.dupeMods = H.dupeMods or {} H.dupeMods[n] = fn end,
  StoreEntityModifier = function() end,
  ClearEntityModifier = function() end,
}
player = { GetAll = function() return H.allPlayers or {} end }
Color = function(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
RENDERMODE_NORMAL, RENDERMODE_TRANSCOLOR = 0, 4
concommand = { Add = function() end }
game = { GetMap = function() return H.map or "gm_perm" end }

mkPly = function(nick, sa)
  local p = { __nick = nick, __sa = sa and true or false }
  function p:GetShootPos() return mkVec(0, 0, 0) end
  function p:GetAimVector() return mkVec(1, 0, 0) end
  function p:IsSuperAdmin() return self.__sa end
  function p:IsPlayer() return true end
  function p:Nick() return self.__nick end
  function p:GetInfo() return "1234" end
  function p:GetInfoNum(_, d) return d end
  return p
end

local function lastNotify(pat)
  for i = #H.notifies, 1, -1 do if H.notifies[i]:find(pat) then return H.notifies[i] end end
  return nil
end

-- ══════════════════════ ЧАСТЬ 1: Код 102/105 / находки 119/122 ══════
print("== stools/ffd_keypad.lua: BuildCPanel (SetDock-краш + поле PIN) ==")
TOOL = { ClientConVar = {} }
SERVER, CLIENT = false, false
dofile("lua/weapons/gmod_tool/stools/ffd_keypad.lua")
ok(type(TOOL.BuildCPanel) == "function", "TOOL.BuildCPanel объявлен")

local panel = {}
function panel:AddControl(kind, data) H.addons[#H.addons + 1] = kind end
function panel:AddItem() end
function panel:Help() end
function panel:TextEntry(label, convar) H.textentries[#H.textentries + 1] = { label = label, convar = convar } end
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
ok(#H.addons == 5, "AddControl: Header + 2×Numpad + 2×Slider (" .. #H.addons .. " шт)")
-- находка 122: поле PIN раньше молча пропадало (AddControl "TextEntry" —
-- такого имени контрола нет). Теперь — живой DForm-хелпер panel:TextEntry.
ok(#H.textentries == 2 and H.textentries[1].convar == "ffd_keypad_password",
   "поле «Пароль (PIN-код)» — живой TextEntry в конвар ffd_keypad_password")
ok(H.textentries[2] ~= nil and H.textentries[2].convar == "ffd_keypad_faction",
   "фолбэк-поле «Фракция с доступом» — TextEntry в ffd_keypad_faction")

-- ══════════════════════ ЧАСТЬ 2: Код 103 / находка 120 ═══════════════
print("== lua/weapons/keypad.lua: классический кейпад-SWEP ==")
SWEP = { Primary = {}, Secondary = {} }
dofile("lua/weapons/keypad.lua")
ok(SWEP.ClassName == "keypad" and SWEP.MaxOwnKeypads == 24 and SWEP.Spawnable == true,
   "SWEP зарегистрирован: class=keypad, кап 24, виден в Q-оружии")

local ply = mkPly("Владелец", false)
local admin = mkPly("Админ", true)
local function mkSwep(owner)
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

-- ══════════════════ ЧАСТЬ 3: Код 104 — панель фракций ═══════════════
print("== BuildCPanel: чекбоксы фракций (замечание №1 прошлого раза) ==")
Factions = {
  ["Полиция"] = {}, ["Медики"] = {}, ["Бандиты"] = {},
}
H.addons, H.combos, H.vguis, H.textentries = {}, {}, {}, {}
local panel3 = {}
function panel3:AddControl(kind, data) H.addons[#H.addons + 1] = kind end
function panel3:AddItem() end
function panel3:Help(t) H.helps = (H.helps or 0) + 1 end
function panel3:TextEntry(label, convar) H.textentries[#H.textentries + 1] = { label = label, convar = convar } end
function panel3:ComboBox(label, convar)
  H.combos[#H.combos + 1] = { label = label, convar = convar, choices = {} }
  local c = H.combos[#H.combos]
  function c:AddChoice() end
  return c
end
local okFac, errFac = pcall(TOOL.BuildCPanel, panel3)
ok(okFac, "BuildCPanel с глобалом Factions строится: " .. tostring(errFac or ""))
local dpanel, cbs = nil, {}
for _, c in ipairs(H.vguis or {}) do
  if c._cls == "DPanel" then dpanel = c end
  if c._cls == "DCheckBoxLabel" then cbs[#cbs + 1] = c end
end
ok(dpanel ~= nil, "окошко фракций (DPanel-обёртка) создано")
ok(#cbs == 3, "чекбокс на КАЖДУЮ фракцию (" .. #cbs .. " шт)")
ok(#H.addons == 5, "в фракционной ветке текстового фолбэка нет (" .. #H.addons .. " AddControl)")
ok(#H.textentries == 1 and H.textentries[1].convar == "ffd_keypad_password",
   "в фракционной ветке PIN-поле на месте (TextEntry), фракция — чекбоксами")
-- отметить две фракции → конвар через запятую в отсортированном порядке
local function cbByText(t)
  for _, c in ipairs(cbs) do if c.text == t then return c end end
end
cbByText("Медики").OnChange(cbByText("Медики"), true)
cbByText("Полиция").OnChange(cbByText("Полиция"), true)
ok(RC_Last ~= nil and RC_Last.name == "ffd_keypad_faction" and RC_Last.val == "Медики,Полиция",
   "чекбоксы пишут список фракций в конвар: " .. tostring(RC_Last and RC_Last.val))
-- начальное состояние из конвара
H.convars["ffd_keypad_faction"] = "Бандиты"
H.vguis = {}
local panel4 = {}
function panel4:AddControl() end function panel4:AddItem() end function panel4:Help() end
function panel4:TextEntry() end
function panel4:ComboBox() return { AddChoice = function() end } end
pcall(TOOL.BuildCPanel, panel4)
local initChecked = 0
for _, c in ipairs(H.vguis or {}) do if c._cls == "DCheckBoxLabel" and c.checked then initChecked = initChecked + 1 end end
ok(initChecked == 1, "при переоткрытии панель читает конвар (Бандиты отмечены: " .. initChecked .. ")")

-- ══════════════ ЧАСТЬ 4: Код 104/105 — экран, прицел, фракции ═══════
print("== grm_keypad entity: кнопки по прицелу, экран по базису, фракции ==")
SERVER, CLIENT = true, false -- серверный путь энтити (IsKeypadLocked/IsFactionAllowed)
include = function(f) dofile("lua/entities/grm_keypad/" .. f) end
ENT = {}
dofile("lua/entities/grm_keypad/init.lua")
ok(type(ENT.PressButton) == "function" and type(ENT.KeypadButtonAt) == "function"
   and istable(ENT.Buttons) and #ENT.Buttons == 12,
   "shared-хелперы на месте (12 кнопок, KeypadButtonAt)")

local function mkKeypadEnt()
  local e = { __class = "grm_keypad", __nw = {} }
  function e:NetworkVar(_, _, name)
    e["Get" .. name] = function(s) return s.__nw[name] end
    e["Set" .. name] = function(s, v) s.__nw[name] = v end
  end
  setmetatable(e, { __index = ENT })
  e:SetupDataTables()
  e:SetStatus(0) e:SetCost(0) e:SetMode(0) e:SetFaction("") e:SetPassword("1234") e:SetDisplayText("")
  e.CurrentInput = "" e.KeyGranted, e.KeyDenied, e.HoldTime = 1, 2, 5
  function e:EmitSound() end
  function e:GetPos() return mkVec(0, 0, 0) end
  function e:GetForward() return mkVec(1, 0, 0) end
  function e:GetRight() return mkVec(0, -1, 0) end
  function e:GetUp() return mkVec(0, 0, 1) end
  -- Код 105: морда модели по OBB (масштаб 3D2D больше не константой)
  function e:OBBMins() return mkVec(-1.2, -2.4, -3.85) end
  function e:OBBMaxs() return mkVec(1.2, 2.4, 3.85) end
  function e:SetAngles(a) self.__setang = a end
  function e:GetAngles()
    return self.__setang or { p = 0, y = 0, r = 0,
      Right = function() return mkVec(0, -1, 0) end,
      Up = function() return mkVec(0, 0, 1) end,
      RotateAroundAxis = function() end }
  end
  function e:EntIndex() return 42 end
  function e:GetClass() return "grm_keypad" end
  return e
end

local kp = mkKeypadEnt()

-- Код 105 (находка 122): масштаб экрана считается по морде модели (OBB)
local S = kp:KeypadScreenScale()
ok(math.abs(S - (4.8 / 144)) < 1e-9,
   "Код 105: scale экрана по OBB-морде (min(4.8/144, 7.7/220) = " .. string.format("%.5f", S) .. ")")
-- Код 105 (находка 122): угол 3D2D из базиса одним AngleEx — без ролла 180°
local ang105 = kp:KeypadScreenAngles()
local function vEq(a, x, y, z)
  return a ~= nil and math.abs(a.x - x) < 1e-6 and math.abs(a.y - y) < 1e-6 and math.abs(a.z - z) < 1e-6
end
ok(vEq(ang105:Forward(), 0, 1, 0) and vEq(ang105:Right(), 0, 0, -1) and vEq(ang105:Up(), 1, 0, 0),
   "Код 105: базис 3D2D F=-E:R / R=-E:U / U=+E:F (ролл 180° ушёл)")

-- хит-тест пикселя кнопки «5» (x=54,y=114,w36,h28 → центр 72,128)
local O = kp:KeypadScreenOrigin()
local s5 = O + mkVec(0, 1, 0) * (72 * S) + mkVec(0, 0, -1) * (128 * S)
local idx5, b5 = kp:KeypadButtonAt(s5)
ok(idx5 ~= nil and b5.text == "5", "KeypadButtonAt: точка центра кнопки «5» -> «5» (ось не зеркальна)")
local mX = O + mkVec(0, 1, 0) * (72 * S) + mkVec(0, 0, -1) * (46 * S) -- поле ввода, не кнопка
ok(kp:KeypadButtonAt(mX) == nil, "KeypadButtonAt: мимо кнопок -> nil")

local function mkEplayer(sid, sa)
  local p = { __sa = sa and true or false, __sid = sid }
  function p:SteamID() return self.__sid end
  function p:SteamID64() return "765611980000009" .. tostring(tonumber(select(3, self.__sid:find("(%d+)$")) or 0)) end
  function p:IsSuperAdmin() return self.__sa end
  function p:IsPlayer() return true end
  function p:Nick() return "Игрок " .. tostring(self.__sid) end
  function p:GetShootPos() return mkVec(2, 0, 0) end
  function p:GetAimVector() return mkVec(1, 0, 0) end
  function p:GetEyeTrace() return H.eyeTrace end
  return p
end

-- E на кнопке «5»: сервер считает цель по GetEyeTrace и жмёт её
local aimFn = H.hooks["KeyPress/GRM_Keypad_AimPress"]
ok(type(aimFn) == "function", "хук прицельного нажатия зарегистрирован")
local plyA = mkEplayer("STEAM_0:1:8", false)
kp.KeypadOwner = plyA
H.eyeTrace = { Entity = kp, HitPos = s5 }
H.bcasts = {}
aimFn(plyA, IN_USE)
ok(kp.CurrentInput == "5", "прицел на «5» + E -> в поле ввела цифра 5")
ok(#H.bcasts == 1 and H.bcasts[1] == "GRM_KeypadPress", "нажатие транслируется вспышкой всем клиентам")
plyA.__grmKeypadNextPress = 0
H.eyeTrace = { Entity = kp, HitPos = mX }
aimFn(plyA, IN_USE)
ok(kp.CurrentInput == "5", "E мимо кнопок -> ничего не нажалось")

-- ввод правильного PIN через прицел: 1,2,3,4 + OK
local function pressAt(hitpos)
  plyA.__grmKeypadNextPress = 0
  H.eyeTrace = { Entity = kp, HitPos = hitpos }
  aimFn(plyA, IN_USE)
end
local function centerOf(btn)
  return O + mkVec(0, 1, 0) * ((btn.x + btn.w / 2) * S) + mkVec(0, 0, -1) * ((btn.y + btn.h / 2) * S)
end
kp.CurrentInput = "" kp:SetStatus(0)
pressAt(centerOf(ENT.Buttons[1]))  -- 1
pressAt(centerOf(ENT.Buttons[2]))  -- 2
pressAt(centerOf(ENT.Buttons[3]))  -- 3
pressAt(centerOf(ENT.Buttons[10])) -- 4
H.npad = {}
pressAt(centerOf(ENT.Buttons[12])) -- OK
ok(#H.npad == 1 and H.npad[1] == 1, "PIN 1234 по кнопкам взглядом -> grant (numpad.Activate Granted)")
kp:SetStatus(0) kp.IsGrantActive = false kp.CurrentInput = ""

-- список фракций через запятую (режим 1)
Factions = {
  ["Медики"] = { Members = { ["STEAM_0:1:7"] = { Role = "Врач" } } },
  ["Полиция"] = { Members = {} },
}
local medic = mkEplayer("STEAM_0:1:7", false)
local rando = mkEplayer("STEAM_0:1:9", false)
kp:SetMode(1) kp:SetFaction("Медики,Полиция")
H.npad = {}
kp:PressButton("OK", medic)
ok(H.npad[1] == 1, "фракция из списка (Медики,Полиция) -> grant")
kp:SetStatus(0) kp.IsGrantActive = false
H.npad = {}
kp:PressButton("OK", rando)
ok(H.npad[1] == 2, "чужак вне списка фракций -> deny")
kp:SetStatus(0) kp.IsGrantActive = false
kp:SetFaction("Полиция")
H.npad = {}
kp:PressButton("OK", medic)
ok(H.npad[1] == 2, "фракция не из списка -> deny (список не подменяет одиночную)")
kp:SetStatus(0) kp.IsGrantActive = false
H.npad = {}
kp:PressButton("OK", kp.KeypadOwner)
ok(H.npad[1] == 1, "владельца кейпада пускает всегда")
kp:SetStatus(0) kp.IsGrantActive = false

-- регресс-страж находки 121: код спавна кейпада не должен поворачивать модель
for _, path in ipairs({ "lua/weapons/gmod_tool/stools/ffd_keypad.lua", "lua/weapons/keypad.lua" }) do
  local f = io.open(path, "r")
  local src = f and f:read("*a") or ""
  if f then f:close() end
  ok(src:find("RotateAroundAxis(", 1, true) == nil, path .. ": спавн без RotateAroundAxis (модель лицом в +X)")
end

-- ══════════════ ЧАСТЬ 5: Код 105 — ПЕРМ кейпада и FFD-двери ════════
print("== Код 105: /permadd с данными кейпада и двери (замечание №3) ==")
-- файлово-JSON хранилище в памяти (логика модуля реальная, шим носителя)
H.jsonhold = {}
local function deepCopy(t)
  if type(t) ~= "table" then return t end
  local out = {}
  for k, v in pairs(t) do out[k] = deepCopy(v) end
  return out
end
util.TableToJSON = function(t) H.jsonhold[#H.jsonhold + 1] = t return "#SIMJSON" .. #H.jsonhold end
util.JSONToTable = function(txt)
  local i = tonumber(tostring(txt):match("#SIMJSON(%d+)"))
  return i and deepCopy(H.jsonhold[i]) or nil
end
local FILES = {}
file = {
  Write = function(n, c) FILES[n] = c end,
  Read = function(n) return FILES[n] end,
  Exists = function(n) return FILES[n] ~= nil end,
}

dofile("lua/autorun/sh_grm_perm_entities.lua")
ok(GRM._permEntitiesVer == "1.3.0", "perm-модуль v1.3.0 загружен (rec.data-хуки)")
ok(type(GRM.PermData.Extract["grm_keypad"]) == "function"
   and type(GRM.PermData.Apply["grm_keypad"]) == "function",
   "кейпад: Extract/Apply данных зарегистрированы (init.lua)")

TOOL = { ClientConVar = {} }
dofile("lua/weapons/gmod_tool/stools/ffd_fading_door.lua")
ok(type(GRM.FFD_MakeFadingDoor) == "function"
   and type(GRM.PermData.Extract["prop_physics"]) == "function"
   and type(GRM.PermData.Apply["prop_physics"]) == "function"
   and type(H.dupeMods["FFD_FadingDoor"]) == "function",
   "FFD-дверь: core-фабрика, Extract/Apply prop_physics, duplicator-модификатор")

local admin5 = mkEplayer("STEAM_0:1:1", true)
H.allPlayers = { admin5, plyA, medic }
local chatFn = H.hooks["PlayerSay/GRM_PermEntities_Chat"]
ok(type(chatFn) == "function", "чат-команды /perm* зарегистрированы")

-- кейпад с «боевой» конфигурацией
kp:SetPassword("4321") kp:SetMode(1) kp:SetFaction("Медики,Полиция")
kp.KeyGranted, kp.KeyDenied, kp.HoldTime = 5, 6, 9
kp.KeypadOwner = plyA
H.notifies = {}
H.hit = { Entity = kp }
chatFn(admin5, "/permadd")
ok(FILES["grm_perm_entities.json"] ~= nil, "/permadd по кейпаду: база записана")
local base1 = util.JSONToTable(FILES["grm_perm_entities.json"])
ok(#base1 == 1 and base1[1].class == "grm_keypad" and istable(base1[1].data)
   and base1[1].data.password == "4321" and base1[1].data.mode == 1
   and base1[1].data.faction == "Медики,Полиция"
   and base1[1].data.granted == 5 and base1[1].data.denied == 6
   and base1[1].data.hold == 9 and base1[1].data.owner == plyA:SteamID64(),
   "запись кейпада несёт rec.data (PIN/режим/фракции/кнопки/задержку/владельца)")

-- FFD-дверь: обычный prop_physics + конфиг двери
local prop = ents.Create("prop_physics")
prop:SetPos(mkVec(10, 0, 0))
H.npadDown, H.npadUp = 0, 0
ok(GRM.FFD_MakeFadingDoor(plyA, prop, 3, true, false, true, 7) == true
   and prop.isFadingDoor == true and prop.FFD_Key == 3 and prop.FFD_Reversed == true
   and prop.FFD_Toggle == false and prop.FFD_AutoClose == true and prop.FFD_CloseTime == 7,
   "FFD_MakeFadingDoor: проп стал fading door (key3 / reversed / autoclose 7с)")
ok(H.npadDown == 1 and H.npadUp == 1, "нумпад-связка двери создана (владелец онлайн)")
-- регресс-страж: офлайн-владелец (перм-восстановление) не роняет numpad
local propAlone = ents.Create("prop_physics")
ok(GRM.FFD_MakeFadingDoor(nil, propAlone, 2, false, true, false, 5) == true
   and propAlone.isFadingDoor == true,
   "FFD без живого владельца — без краша numpad, дверь рабочая")
propAlone:Remove()
H.hit = { Entity = prop }
chatFn(admin5, "/permadd")
local base2 = util.JSONToTable(FILES["grm_perm_entities.json"])
ok(#base2 == 2 and base2[2].class == "prop_physics" and istable(base2[2].data)
   and istable(base2[2].data.ffd) and base2[2].data.ffd.key == 3
   and base2[2].data.ffd.reversed == true and base2[2].data.ffd.autoclose == true
   and base2[2].data.ffd.time == 7 and base2[2].data.ffd.owner == plyA:SteamID64(),
   "запись FFD-двери несёт rec.data.ffd (ключ/инверсия/автозакрытие/время/владельца)")

-- «рестарт карты»: мир пуст, база на диске
world = {}
_G.__mkKeypadEnt = mkKeypadEnt
H.notifies = {}
chatFn(admin5, "/permload")
ok(lastNotify("восстановлено 2") ~= nil, "/permload: оба перма воскрешены за раз")
local newKp, newProp
for e in pairs(world) do
  if not e.__removed then
    if e:GetClass() == "grm_keypad" then newKp = e end
    if e:GetClass() == "prop_physics" then newProp = e end
  end
end
ok(newKp ~= nil and newKp.spawned and newKp.activated and newKp.frozen == true and newKp._grmPerm == true,
   "перм-кейпад: спавн+активация+фриз+пометка")
ok(newKp ~= nil and newKp:GetPassword() == "4321" and newKp:GetMode() == 1
   and newKp:GetFaction() == "Медики,Полиция"
   and newKp.KeyGranted == 5 and newKp.KeyDenied == 6 and newKp.HoldTime == 9,
   "перм-кейпад: PIN/режим/фракции/кнопки/задержка восстановлены (не пустышка 1234)")
ok(newKp ~= nil and newKp.KeypadOwner == plyA and newKp:IsKeypadOwner(plyA) == true
   and newKp:IsKeypadOwner(rando) == false,
   "перм-кейпад: владелец найден по sid64, IsKeypadOwner работает после рестарта")
ok(newProp ~= nil and newProp.isFadingDoor == true and newProp.FFD_Key == 3
   and newProp.FFD_Reversed == true and newProp.FFD_Toggle == false
   and newProp.FFD_AutoClose == true and newProp.FFD_CloseTime == 7
   and newProp.frozen == true,
   "перм-дверь: после рестарта сразу рабочая fading door (фриз)")
ok(newProp ~= nil and newProp.FFD_OwnerSID64 == plyA:SteamID64(),
   "перм-дверь: владелец sid64 восстановлен")
-- воскрешённый кейпад реально работает: владельца пускает, чужака — нет
H.npad = {}
newKp:PressButton("OK", plyA)
ok(H.npad[1] == 5, "перм-кейпад: владельца пускает в фракционном режиме (grant той кнопкой)")
newKp:SetStatus(0) newKp.IsGrantActive = false
H.npad = {}
newKp:PressButton("OK", rando)
ok(H.npad[1] == 6, "перм-кейпад: чужака не пускает (deny восстановленной кнопкой)")
-- антидубль: повторный /permload на живой карте — ничего не клонирует
H.notifies = {}
chatFn(admin5, "/permload")
ok(lastNotify("уже на месте 2") ~= nil, "антидубль: повторная загрузка только отмечает «уже на месте»")
-- /permremove снимает и с карты, и из базы
H.hit = { Entity = newKp }
chatFn(admin5, "/permremove")
local base3 = util.JSONToTable(FILES["grm_perm_entities.json"])
ok(#base3 == 1 and base3[1].class == "prop_physics" and not IsValid(newKp),
   "/permremove: кейпад снят из базы и с карты, дверь осталась")

print("")
print(("РЕЗУЛЬТАТ: %d/%d проверок, провалов: %d"):format(checks - failed, checks, failed))
if failed > 0 then os.exit(1) end
print("SIM FFDTOOLS: OK")
