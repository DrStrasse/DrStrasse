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

local H = { notifies = {}, sounds = {}, undo = {}, addons = {}, combos = {},
            hooks = {}, npad = {}, netmsg = nil, convars = { ["ffd_keypad_faction"] = "" } }
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
VMT.__sub = function(a, b) return setmetatable({ x = a.x - b.x, y = a.y - b.y, z = a.z - b.z }, VMT) end
VMT.__mul = function(a, k) return setmetatable({ x = a.x * k, y = a.y * k, z = a.z * k }, VMT) end
VMT.__unm = function(a) return setmetatable({ x = -a.x, y = -a.y, z = -a.z }, VMT) end
function VMT:Dot(b) return self.x * b.x + self.y * b.y + self.z * b.z end
function VMT:DistToSqr(b) local dx, dy, dz = self.x - b.x, self.y - b.y, self.z - b.z return dx * dx + dy * dy + dz * dz end
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
  FindInSphere = function() return {} end,
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

-- шимы для Кода 104: панель фракций (DForm+vgui), конвары, энтити-мир
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
timer = { Create = function() end, Simple = function() end }
numpad = {
  Activate = function(p, k) H.npad[#H.npad + 1] = k end,
  Deactivate = function() end,
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
ok(#H.addons == 7, "AddControl: Header + PIN + Фракция(фолбэк) + 2×Numpad + 2×Slider (" .. #H.addons .. " шт)")

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

-- ══════════════════ ЧАСТЬ 3: Код 104 — панель фракций ═══════════════
print("== BuildCPanel: чекбоксы фракций (замечание №1 владельца) ==")
Factions = {
  ["Полиция"] = {}, ["Медики"] = {}, ["Бандиты"] = {},
}
H.addons, H.combos, H.vguis = {}, {}, {}
local panel3 = {}
function panel3:AddControl(kind, data) H.addons[#H.addons + 1] = kind end
function panel3:AddItem() end
function panel3:Help(t) H.helps = (H.helps or 0) + 1 end
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
ok(#H.addons == 6, "в фракционной ветке текстового фолбэка нет (" .. #H.addons .. " AddControl)")
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
function panel4:ComboBox() return { AddChoice = function() end } end
pcall(TOOL.BuildCPanel, panel4)
local initChecked = 0
for _, c in ipairs(H.vguis or {}) do if c._cls == "DCheckBoxLabel" and c.checked then initChecked = initChecked + 1 end end
ok(initChecked == 1, "при переоткрытии панель читает конвар (Бандиты отмечены: " .. initChecked .. ")")

-- ══════════════ ЧАСТЬ 4: Код 104 — геометрия экрана + прицел + фракции ═
print("== grm_keypad entity: кнопки по прицелу, список фракций ==")
IN_USE = IN_USE or 5
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
  function e:GetAngles()
    return { Right = function() return mkVec(0, -1, 0) end,
             Up = function() return mkVec(0, 0, 1) end,
             RotateAroundAxis = function() end }
  end
  function e:EntIndex() return 42 end
  function e:GetClass() return "grm_keypad" end
  return e
end

local kp = mkKeypadEnt()

-- хит-тест пикселя кнопки «5» (x=54,y=114,w36,h28 → центр 72,128)
local O = kp:KeypadScreenOrigin()
local s5 = O + mkVec(0, 1, 0) * (72 * 0.035) + mkVec(0, 0, -1) * (128 * 0.035)
local idx5, b5 = kp:KeypadButtonAt(s5)
ok(idx5 ~= nil and b5.text == "5", "KeypadButtonAt: точка центра кнопки «5» -> «5» (ось не зеркальна)")
local mX = O + mkVec(0, 1, 0) * (72 * 0.035) + mkVec(0, 0, -1) * (46 * 0.035) -- поле ввода, не кнопка
ok(kp:KeypadButtonAt(mX) == nil, "KeypadButtonAt: мимо кнопок -> nil")

local function mkEplayer(sid, sa)
  local p = { __sa = sa and true or false, __sid = sid }
  function p:SteamID() return self.__sid end
  function p:SteamID64() return "765611980000009" .. tostring(tonumber(select(3, self.__sid:find("(%d+)$")) or 0)) end
  function p:IsSuperAdmin() return self.__sa end
  function p:GetShootPos() return mkVec(2, 0, 0) end
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
local S = 0.035
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

print("")
print(("РЕЗУЛЬТАТ: %d/%d проверок, провалов: %d"):format(checks - failed, checks, failed))
if failed > 0 then os.exit(1) end
print("SIM FFDTOOLS: OK")
