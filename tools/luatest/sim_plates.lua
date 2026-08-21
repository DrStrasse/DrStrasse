--[[ Живой прогон системы регистрационных номерных знаков (заказ 21.08):
     выдача в Полиции, реестр, физический знак, ручная установка на машину
     спереди и сзади, проверка номера, аннулирование.
     Грузится РЕАЛЬНЫЙ lua/autorun/sh_grm_plates.lua (SERVER=true).
     Запуск: ./.luabuild/lj/src/luajit tools/luatest/sim_plates.lua ]]
local pass, fail = 0, 0
local function ok(v, n, extra)
    if v then pass = pass + 1 print("  ok   " .. n)
    else fail = fail + 1 print("  FAIL " .. n .. "  " .. tostring(extra or "")) end
end

SERVER, CLIENT = true, false
function AddCSLuaFile() end
function istable(v) return type(v) == "table" end
function isstring(v) return type(v) == "string" end
function isnumber(v) return type(v) == "number" end
function isfunction(v) return type(v) == "function" end
function IsValid(v) return type(v) == "table" and v._valid ~= false end
function CurTime() return 100 end
function SysTime() return 100 end
function ErrorNoHalt() end
function math.Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function table.Count(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
function table.Copy(t) if type(t) ~= "table" then return t end local o = {} for k, v in pairs(t) do o[k] = table.Copy(v) end return o end
function string.Trim(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
FCVAR_ARCHIVE = 1
SOLID_VPHYSICS, SOLID_NONE, MOVETYPE_VPHYSICS, MOVETYPE_NONE = 6, 0, 6, 0
COLLISION_GROUP_NONE, COLLISION_GROUP_WORLD = 0, 1
HUD_PRINTTALK = 3

local VMT = {}
VMT.__index = VMT
function VMT:DistToSqr(o) local a, b, c = self.x - o.x, self.y - o.y, self.z - o.z return a * a + b * b + c * c end
function VMT:Distance(o) return math.sqrt(self:DistToSqr(o)) end
VMT.__add = function(a, b) return Vector(a.x + b.x, a.y + b.y, a.z + b.z) end
VMT.__sub = function(a, b) return Vector(a.x - b.x, a.y - b.y, a.z - b.z) end
VMT.__mul = function(a, b)
    if type(b) == "number" then return Vector(a.x * b, a.y * b, a.z * b) end
    if type(a) == "number" then return Vector(b.x * a, b.y * a, b.z * a) end
    return Vector(a.x * b.x, a.y * b.y, a.z * b.z)
end
function Vector(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, VMT) end
function Angle(p, y, r) return { p = p or 0, y = y or 0, r = r or 0 } end

local HOOKS = {}
hook = {
    Add = function(e, n, fn) HOOKS[e] = HOOKS[e] or {} HOOKS[e][n] = fn end,
    Remove = function() end,
    Run = function(e, ...) for _, fn in pairs(HOOKS[e] or {}) do local r = fn(...) if r ~= nil then return r end end end,
}
timer = { Simple = function(_, fn) if fn then fn() end end, Create = function() end, Remove = function() end,
          Exists = function() return false end }
concommand = { Add = function() end }
util = { AddNetworkString = function() end }
local NETSENT = {}
net = { Receive = function(m, fn) NETSENT[m] = fn end, Start = function() end, Send = function() end,
        Broadcast = function() end,
        WriteString = function() end, WriteTable = function() end, WriteBool = function() end,
        WriteUInt = function() end, WriteFloat = function() end, WriteInt = function() end,
        ReadString = function() return "" end, ReadTable = function() return {} end }
local CONVARS = {}
function CreateConVar(name, def)
    local cv = { value = def }
    function cv:GetInt() return math.floor(tonumber(self.value) or 0) end
    function cv:GetBool() return tostring(self.value) == "1" end
    function cv:SetValue(v) self.value = v end
    CONVARS[name] = cv
    return cv
end
game = { GetMap = function() return "sim_map" end }
player = { GetAll = function() return {} end }
local WORLD = {}
ents = {
    GetAll = function() return WORLD end,
    FindByClass = function(cls)
        local out = {}
        for _, e in ipairs(WORLD) do if e:GetClass() == cls then out[#out + 1] = e end end
        return out
    end,
    FindInSphere = function(pos, r)
        local out = {}
        for _, e in ipairs(WORLD) do if e:GetPos():Distance(pos) <= r then out[#out + 1] = e end end
        return out
    end,
    Create = function(cls)
        local e = { _valid = true, _class = cls, _pos = Vector(0, 0, 0), _ang = Angle(0, 0, 0), _nw = {}, _children = {} }
        function e:GetClass() return self._class end
        function e:SetPos(v) self._pos = v end
        function e:GetPos() return self._pos end
        function e:SetAngles(a) self._ang = a end
        function e:GetAngles() return self._ang end
        function e:Spawn() end
        function e:Activate() end
        function e:SetModel() end
        function e:SetMaterial() end
        function e:PhysicsInit() end
        function e:SetMoveType() end
        function e:SetSolid() end
        function e:SetUseType() end
        function e:SetCollisionGroup() end
        function e:GetPhysicsObject()
            return { IsValid = function() return true end, EnableMotion = function() end,
                     Wake = function() end, SetMass = function() end }
        end
        function e:SetNWString(k, v) self._nw[k] = v end
        function e:GetNWString(k, d) local v = self._nw[k] if v == nil then return d end return v end
        function e:SetNWBool(k, v) self._nw[k] = v end
        function e:GetNWBool(k, d) local v = self._nw[k] if v == nil then return d end return v end
        function e:SetParent(p)
            if IsValid(self._parent) then
                for i, c in ipairs(self._parent._children) do if c == self then table.remove(self._parent._children, i) break end end
            end
            self._parent = p
            if IsValid(p) then p._children[#p._children + 1] = self end
        end
        function e:GetParent() return self._parent end
        function e:GetChildren() return self._children end
        function e:IsVehicle() return self._class == "sim_car" end
        function e:WorldToLocal(v) return Vector(v.x - self._pos.x, v.y - self._pos.y, v.z - self._pos.z) end
        function e:LocalToWorld(v) return Vector(v.x + self._pos.x, v.y + self._pos.y, v.z + self._pos.z) end
        function e:WorldToLocalAngles(a) return Angle(a.p, a.y, a.r) end
        function e:LocalToWorldAngles(a) return Angle(a.p, a.y, a.r) end
        function e:EmitSound() end
        function e:Remove() self._valid = false end
        function e:SetupPlate(rec)
            self:SetNWString("GRM_Plate", tostring(rec.number or ""))
            self:SetNWString("GRM_PlateType", tostring(rec.type or "civil"))
            self:SetNWString("GRM_PlateStatus", tostring(rec.status or "active"))
            self.GRMPlateOwnerKey = tostring(rec.ownerKey or "")
        end
        WORLD[#WORLD + 1] = e
        return e
    end,
}
-- ── мок файлов: data/<path> → содержимое ──
local files = {}
file = {
  Exists = function(p) return files[p] ~= nil end,
  Read = function(p) return files[p] end,
  Write = function(p, s) files[p] = s end,
}
-- честный JSON (достаточно для наших структур)
local function encode(v, indent)
  indent = indent or 0
  local pad = string.rep("\t", indent)
  local t = type(v)
  if t == "number" then return string.format("%g", v)
  elseif t == "string" then return string.format("%q", v)
  elseif t == "boolean" then return tostring(v)
  elseif t == "table" then
    local isArr = true
    for k in pairs(v) do if type(k) ~= "number" or k < 1 or k > #v then isArr = false break end end
    local parts = {}
    if isArr and #v > 0 then
      for i = 1, #v do parts[#parts + 1] = encode(v[i], indent + 1) end
      return "[\n" .. string.rep("\t", indent + 1) .. table.concat(parts, ",\n" .. string.rep("\t", indent + 1)) .. "\n" .. pad .. "]"
    end
    for k, val in pairs(v) do parts[#parts + 1] = string.format("%q: %s", tostring(k), encode(val, indent + 1)) end
    return "{\n" .. string.rep("\t", indent + 1) .. table.concat(parts, ",\n" .. string.rep("\t", indent + 1)) .. "\n" .. pad .. "}"
  end
  return "null"
end
util.TableToJSON = function(t) return encode(t) end
-- Полноценный мини-разбор JSON: вложенные объекты и массивы, экранирование.
local function jsonDecode(str)
    local pos = 1
    local parseValue
    local function skip()
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == " " or c == "\t" or c == "\n" or c == "\r" then pos = pos + 1 else break end
        end
    end
    local function parseString()
        pos = pos + 1
        local out = {}
        while pos <= #str do
            local c = str:sub(pos, pos)
            if c == "\\" then
                local n = str:sub(pos + 1, pos + 1)
                if n == "n" then out[#out + 1] = "\n"
                elseif n == "t" then out[#out + 1] = "\t"
                elseif n == "u" then
                    out[#out + 1] = ""
                    pos = pos + 4
                else out[#out + 1] = n end
                pos = pos + 2
            elseif c == '"' then
                pos = pos + 1
                return table.concat(out)
            else
                out[#out + 1] = c
                pos = pos + 1
            end
        end
        return table.concat(out)
    end
    parseValue = function()
        skip()
        local c = str:sub(pos, pos)
        if c == "{" then
            local t = {}
            pos = pos + 1
            skip()
            if str:sub(pos, pos) == "}" then pos = pos + 1 return t end
            while pos <= #str do
                skip()
                local key = parseString()
                skip()
                pos = pos + 1 -- ':'
                t[key] = parseValue()
                skip()
                local ch = str:sub(pos, pos)
                pos = pos + 1
                if ch == "}" then break end
            end
            return t
        elseif c == "[" then
            local t = {}
            pos = pos + 1
            skip()
            if str:sub(pos, pos) == "]" then pos = pos + 1 return t end
            while pos <= #str do
                t[#t + 1] = parseValue()
                skip()
                local ch = str:sub(pos, pos)
                pos = pos + 1
                if ch == "]" then break end
            end
            return t
        elseif c == '"' then
            return parseString()
        elseif str:sub(pos, pos + 3) == "true" then pos = pos + 4 return true
        elseif str:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
        elseif str:sub(pos, pos + 3) == "null" then pos = pos + 4 return nil
        else
            local num = str:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", pos)
            if num then pos = pos + #num return tonumber(num) end
            pos = pos + 1
            return nil
        end
    end
    local okParse, value = pcall(parseValue)
    return okParse and value or nil
end
util.JSONToTable = function(s) return jsonDecode(tostring(s or "")) end


-- data/-файлы (mock из json-заготовки выше) уже подключены как `files`
file.IsDir = function() return true end
file.CreateDir = function() end

GRM = GRM or {}
GRM.Identity = { CharacterKey = function(p) return p:SteamID64() .. ":char1" end }
GRM.Notify = function(_, msg) LASTNOTIFY = tostring(msg) end
GRM.Perf = { Entities = function(cls) return ents.FindByClass(cls) end, Players = function() return PLAYERS or {} end }
GRM.Audit = { Write = function() end }

assert(loadfile("lua/autorun/sh_grm_plates.lua"))()
local PL = GRM.Plates

local function mkPly(nick, faction, super, sid)
    local p = { _valid = true, nw = { GRM_Faction = faction or "" } }
    function p:IsPlayer() return true end
    function p:IsSuperAdmin() return super == true end
    function p:Nick() return nick end
    function p:SteamID64() return sid or nick end
    function p:GetNWString(k, d) local v = self.nw[k] if v == nil then return d end return v end
    function p:GetPos() return Vector(0, 0, 0) end
    function p:EyeAngles() return Angle(0, 0, 0) end
    function p:GetAimVector() return Vector(1, 0, 0) end
    function p:GetEyeTrace() return { HitPos = Vector(30, 0, 0) } end
    function p:ChatPrint(t) self.chat = (self.chat or "") .. t .. "\n" end
    return p
end

local cop  = mkPly("Копп", "Ordnungspolizei")
local civ  = mkPly("Ганс", "")
local root = mkPly("Root", "", true)
PLAYERS = { cop, civ, root }
player.GetAll = function() return PLAYERS end

print("\n=== 1. НОМЕР: ЧТЕНИЕ, ПРОВЕРКА, ВИД ===")
ok(PL.NormalizeNumber(" а 123 вс ") == "А123ВС", "пробелы и регистр приводятся к канону", PL.NormalizeNumber(" а 123 вс "))
ok(PL.NormalizeNumber("A123BC") == "А123ВС", "латиница читается как кириллица — раскладка не мешает", PL.NormalizeNumber("A123BC"))
ok(PL.NormalizeNumber("A-123_BC") == "А123ВС", "дефисы и подчёркивания игнорируются")
ok(select(1, PL.ValidNumber("А123ВС", "civil")) == true, "гражданский номер A000AA проходит проверку")
ok(select(1, PL.ValidNumber("А12ВС", "civil")) == false, "короткий номер отклонён")
ok(select(1, PL.ValidNumber("Ж123ВС", "civil")) == false, "буква не из набора отклонена")
ok(select(1, PL.ValidNumber("А1В3ВС", "civil")) == false, "цифра на месте буквы отклонена")
ok(PL.FormatNumber("А123ВС", "civil") == "А 123 ВС", "номер показывается группами", PL.FormatNumber("А123ВС", "civil"))
ok(PL.FormatNumber("А1234", "police") == "А 1234", "у полицейской серии своя разбивка", PL.FormatNumber("А1234", "police"))

print("\n=== 2. ГЕНЕРАЦИЯ ===")
local seen, dup = {}, false
for i = 1, 60 do
    local n = PL.GenerateNumber("civil", function(x) return seen[x] end)
    if not n or seen[n] then dup = true end
    seen[n] = true
    if i == 1 then ok(select(1, PL.ValidNumber(n, "civil")) == true, "сгенерированный номер соответствует шаблону", n) end
end
ok(not dup, "генератор не выдаёт занятые номера")
ok(PL.GenerateNumber("police", function() return true end) == nil, "если всё занято — честный nil, а не битый номер")

print("\n=== 3. ДОСТУП ===")
ok(PL.CanIssue(cop) == true, "полицейский может выдавать номера")
ok(PL.CanIssue(civ) == false, "гражданский — нет")
ok(PL.CanIssue(root) == true, "суперадмин может")
ok(PL.CanCheck(civ) == false, "гражданский не пробивает базу")
ok(PL.CanCheck(cop) == true, "служба пробивает")

print("\n=== 4. ВЫДАЧА ===")
local rec, err = PL.Issue({ type = "civil", ownerKey = "civ:char1", ownerName = "Ганс Мюллер",
    by = "cop:char1", byName = "Копп", vehicle = "Opel" })
ok(rec ~= nil, "номер выдан", err)
ok(rec and rec.status == "active", "статус — действителен")
ok(PL.Get(rec.number) == rec, "номер находится в реестре")
ok(#PL.ListFor("civ:char1") == 1, "номер числится за владельцем")
local dup2, errDup = PL.Issue({ type = "civil", number = rec.number, ownerKey = "civ:char1" })
ok(dup2 == nil and tostring(errDup):find("уже выдан", 1, true) ~= nil, "повторная выдача того же номера отклонена", errDup)
local bad, errBad = PL.Issue({ type = "spaceship", ownerKey = "civ:char1" })
ok(bad == nil and isstring(errBad), "неизвестный тип отклонён")
local noOwner = select(2, PL.Issue({ type = "civil" }))
ok(isstring(noOwner), "без владельца номер не выдаётся")

CONVARS["grm_plates_limit"]:SetValue("1")
local overflow, errLimit = PL.Issue({ type = "civil", ownerKey = "civ:char1" })
ok(overflow == nil and tostring(errLimit):find("предел", 1, true) ~= nil, "лимит знаков на персонажа работает", errLimit)
CONVARS["grm_plates_limit"]:SetValue("6")

print("\n=== 5. СТАТУСЫ ===")
ok(select(1, PL.Revoke(rec.number, "Копп")) == true, "номер аннулируется")
ok(PL.Get(rec.number).status == "revoked", "статус записан")
ok(#(PL.Get(rec.number).history or {}) >= 2, "история ведётся")
PL.SetStatus(rec.number, "active", "Копп")
ok(PL.Get(rec.number).status == "active", "и восстанавливается")
ok(select(1, PL.SetStatus(rec.number, "чтототакое", "Копп")) == false, "неизвестный статус отклонён")
ok(select(1, PL.SetStatus("НЕТ000ТТ", "revoked", "Копп")) == false, "несуществующий номер отклонён")

print("\n=== 6. ФИЗИЧЕСКИЙ ЗНАК И РУЧНАЯ УСТАНОВКА ===")
local plate = PL.SpawnPlate(rec.number, Vector(0, 0, 0), Angle(0, 0, 0), civ)
ok(IsValid(plate), "бланк знака создан")
ok(plate:GetNWString("GRM_Plate", "") == rec.number, "на знаке напечатан номер")
ok(select(1, PL.SpawnPlate("АА999ХХ")) == nil, "незарегистрированный номер бланком не выдаётся")

local car = ents.Create("sim_car")
car:SetPos(Vector(0, 0, 0))
car.VD_Class = "simfphys_opel"
-- «Москвич»: от бампера до центра больше сотни юнитов
car.NearestPoint = function(self, pos) return Vector(math.max(-110, math.min(110, pos.x)), 0, 0) end
ok(select(1, PL.Attach(plate, car, civ)) == true, "знак закреплён на машине")
ok(plate:GetParent() == car, "знак стал частью машины")
ok(car:GetNWString("GRM_PlateNumber", "") == rec.number, "номер машины виден для проверки")
ok(#PL.VehiclePlates(car) == 1, "машина знает свои знаки")

-- второй знак: перед и зад
local plate2 = PL.SpawnPlate(rec.number, Vector(0, 0, 0), Angle(0, 0, 0), civ)
PL.Attach(plate2, car, civ)
ok(#PL.VehiclePlates(car) == 2, "на машине можно повесить и передний, и задний знак")

ok(select(1, PL.Detach(plate2, civ)) == true, "знак снимается")
ok(plate2:GetParent() == nil, "снятый знак больше не часть машины")
ok(#PL.VehiclePlates(car) == 1, "второй остался на месте")

print("\n=== 7. КТО МОЖЕТ ТРОГАТЬ ЗНАК ===")
local owner = mkPly("Ганс", "", false, "civ")
ok(PL.CanHandle(owner, plate) == true, "владелец может снять свой знак")
local stranger = mkPly("Чужой", "", false, "other")
ok(PL.CanHandle(stranger, plate) == false, "посторонний — нет")
ok(PL.CanHandle(cop, plate) == true, "сотрудник может изъять знак")

print("\n=== 8. ЗНАКИ ВОЗВРАЩАЮТСЯ ПОСЛЕ ГАРАЖА ===")
-- эмулируем личный транспорт с записью гаража
local garageRec = { id = "veh1", class = "simfphys_opel" }
GRM.VehicleDealer = {
    FindRecord = function(_, id) return id == "veh1" and garageRec or nil end,
    SaveGarages = function() end,
}
car.GRMGarageOwner, car.GRMGarageID = owner, "veh1"
PL.RememberLayout(car)
ok(istable(garageRec.plates) and #garageRec.plates == 1, "раскладка знаков записана в гараж",
   garageRec.plates and #garageRec.plates)
ok(istable(garageRec.plates[1].pos) and isnumber(garageRec.plates[1].pos.x),
   "координаты записаны числами (Vector в JSON не пишется)")

-- машина «убрана и выдана заново»
plate:Remove()
car:Remove()
local car2 = ents.Create("sim_car")
car2:SetPos(Vector(100, 0, 0))
hook.Run("GRM_VehicleIssued", owner, car2, garageRec)
ok(#PL.VehiclePlates(car2) == 1, "после выдачи из гаража знак вернулся на машину", #PL.VehiclePlates(car2))
ok(car2:GetNWString("GRM_PlateNumber", "") == rec.number, "номер снова виден на машине")

print("\n=== 9. ХРАНЕНИЕ РЕЕСТРА ===")
ok(PL.SaveNow() == true, "реестр записан на диск")
local raw = files["grm_plates/registry.json"]
ok(raw ~= nil and raw:find(rec.number, 1, true) ~= nil, "номер попал в файл")
PL.Data.plates = {}
ok(PL.Load() == true and PL.Get(rec.number) ~= nil, "реестр читается обратно")
ok(PL.Get(rec.number).ownerName == "Ганс Мюллер", "владелец пережил перезагрузку")

print("\n=== 10. КОМАНДЫ И СЕТЬ ===")
ok(HOOKS["PlayerSay"] and HOOKS["PlayerSay"]["GRM_Plates_Chat"] ~= nil, "чат-команда зарегистрирована")
local said = HOOKS["PlayerSay"]["GRM_Plates_Chat"]
cop.chat = ""
ok(said(cop, "/номер " .. rec.number) == "", "команда проверки съедается")
ok(tostring(cop.chat):find("Владелец", 1, true) ~= nil, "сотруднику печатается карточка номера", cop.chat)
civ.chat = ""
LASTNOTIFY = nil
said(civ, "/номер " .. rec.number)
ok(tostring(civ.chat) == "" and tostring(LASTNOTIFY):find("служба", 1, true) ~= nil,
   "гражданскому база не открывается", tostring(LASTNOTIFY))
ok(NETSENT[PL.Net.ACT] ~= nil, "приём действий окна зарегистрирован")

print("\n=== 11. ОРИЕНТАЦИЯ НАДПИСИ НА ЗНАКЕ ===")
-- раскладка настраивается: ось, поворот, зеркало, масштаб
ok(istable(PL.Render), "настройка раскладки объявлена")
local base = PL.FaceGeometry(Vector(-12, -36, -0.5), Vector(12, 36, 0.5), { axis = "auto", yaw = 0, scale = 1 })
ok(base.rightAxis == "y" and base.upAxis == "x", "поворот 0°: строка вдоль длинной стороны")
local turned = PL.FaceGeometry(Vector(-12, -36, -0.5), Vector(12, 36, 0.5), { axis = "auto", yaw = 90, scale = 1 })
ok(turned.rightAxis == "x" and turned.upAxis == "y", "поворот 90° меняет оси местами")
ok(turned.w == base.h and turned.h == base.w, "и размеры поля меняются вместе с ними")
local flipped = PL.FaceGeometry(Vector(-12, -36, -0.5), Vector(12, 36, 0.5), { axis = "auto", yaw = 0, flip = true, scale = 1 })
ok(flipped.right.y == -base.right.y, "зеркало разворачивает строку")
local forced = PL.FaceGeometry(Vector(-12, -36, -0.5), Vector(12, 36, 0.5), { axis = "y", yaw = 0, scale = 1 })
ok(forced.thin == "y", "ось лица можно задать вручную, если модель нестандартная")
local scaled = PL.FaceGeometry(Vector(-12, -36, -0.5), Vector(12, 36, 0.5), { axis = "auto", yaw = 0, scale = 0.5 })
ok(math.abs(scaled.w - base.w * 0.5) < 0.01, "масштаб поля учитывается", scaled.w)

-- габариты hunter-плашки: тонкая по Z, длинная сторона — вдоль Y
local face = PL.FaceGeometry(Vector(-12, -36, -0.5), Vector(12, 36, 0.5), { axis = "auto", yaw = 0, scale = 1 })
ok(face.thin == "z", "тонкая ось распознана как толщина знака", face.thin)
ok(face.rightAxis == "y" and face.upAxis == "x",
   "строка номера идёт вдоль ДЛИННОЙ стороны (номер не боком)", face.rightAxis .. "/" .. face.upAxis)
ok(face.w > face.h, "поле знака шире, чем выше", face.w .. "x" .. face.h)
ok(math.abs(face.half - 0.5) < 0.001, "половина толщины посчитана", face.half)
-- знак, повёрнутый в модели иначе: длинная сторона по X
local face2 = PL.FaceGeometry(Vector(-36, -12, -0.5), Vector(36, 12, 0.5), { axis = "auto", yaw = 0, scale = 1 })
ok(face2.rightAxis == "x" and face2.upAxis == "y", "для другой модели строка тоже идёт по длинной стороне")
-- вертикальная плашка (тонкая по Y)
local face3 = PL.FaceGeometry(Vector(-36, -0.5, -12), Vector(36, 0.5, 12), { axis = "auto", yaw = 0, scale = 1 })
ok(face3.thin == "y" and face3.rightAxis == "x", "нормаль и строка считаются и для вертикальной плашки")

print("\n=== 12. КРЕПЛЕНИЕ: ДАЛЁКИЙ ЦЕНТР МАШИНЫ НЕ МЕШАЕТ ===")
local plate3 = PL.SpawnPlate(rec.number, Vector(112, 0, 0), Angle(0, 0, 0), owner)
local farCar = ents.Create("sim_car")
farCar:SetPos(Vector(0, 0, 0))
farCar.NearestPoint = function(self, pos) return Vector(math.max(-110, math.min(110, pos.x)), 0, 0) end
ok(isfunction(PL.HandlePlateUse), "единая обработка [E] по знаку объявлена")
ok(isfunction(PL.LooksLikeVehicle) and PL.LooksLikeVehicle(farCar) == true, "машина распознаётся")
ok(PL.VehicleBase(farCar) == farCar, "база машины — она сама")
local attached = PL.HandlePlateUse(owner, plate3, farCar)
ok(attached == true, "знак у бампера крепится, хотя центр машины в сотне юнитов")
ok(plate3:GetParent() == farCar, "знак стал частью машины")
LASTNOTIFY = nil
PL.HandlePlateUse(owner, plate3)
ok(plate3:GetParent() == nil and tostring(LASTNOTIFY):find("снят", 1, true) ~= nil,
   "повторное [E] снимает знак и сообщает об этом", tostring(LASTNOTIFY))
LASTNOTIFY = nil
PL.HandlePlateUse(stranger, plate3)
ok(tostring(LASTNOTIFY):find("чужой", 1, true) ~= nil, "чужому отвечают отказом, а не молчанием", tostring(LASTNOTIFY))
LASTNOTIFY = nil
local lonely = PL.SpawnPlate(rec.number, Vector(9000, 9000, 0), Angle(0, 0, 0), owner)
PL.HandlePlateUse(owner, lonely)
ok(tostring(LASTNOTIFY):find("Рядом нет транспорта", 1, true) ~= nil,
   "если машины рядом нет — понятная подсказка", tostring(LASTNOTIFY))

print("\n=== 13. ЗНАК В РУКАХ ФИЗГАНА ===")
local held = PL.SpawnPlate(rec.number, Vector(112, 0, 0), Angle(0, 0, 0), owner)
HOOKS["PhysgunPickup"]["GRM_Plates_Held"](owner, held)
ok(owner.GRMHeldPlate == held, "система помнит знак в руках")
owner.GetActiveWeapon = function() return { GetClass = function() return "weapon_physgun" end, _valid = true } end
local blocked = HOOKS["PlayerUse"]["GRM_Plates_UseVehicle"](owner, farCar)
ok(blocked == false, "[E] по машине со знаком в руках не сажает в салон")
ok(held:GetParent() == farCar, "и сразу крепит знак")

print("\n=== 14. НОМЕР ПОМНИТ КОНКРЕТНУЮ МАШИНУ ===")
-- машина с записью гаража: удаляем её вместе со знаком и выдаём заново
local recCar = { id = "veh_2", class = "simfphys_moskvich", name = "Москвич" }
GRM.VehicleDealer = {
    FindRecord = function(_, id) return id == "veh_2" and recCar or nil end,
    SaveGarages = function() end,
}
local myCar = ents.Create("sim_car")
myCar:SetPos(Vector(0, 0, 0))
myCar.GRMGarageOwner, myCar.GRMGarageID = owner, "veh_2"
myCar.NearestPoint = function(self, pos) return Vector(math.max(-110, math.min(110, pos.x)), 0, 0) end

local number2 = select(1, PL.Issue({ type = "civil", ownerKey = "civ:char1", ownerName = "Ганс Мюллер",
    by = "cop:char1", byName = "Копп" })).number
local myPlate = PL.SpawnPlate(number2, Vector(112, 0, 0), Angle(0, 0, 0), owner)
ok(select(1, PL.Attach(myPlate, myCar, owner)) == true, "знак закреплён на личной машине")
local mount = PL.Get(number2).mount
ok(istable(mount) and mount.vehicleID == "veh_2", "в реестре записан ИДЕНТИФИКАТОР конкретной машины", mount and mount.vehicleID)
ok(istable(mount.pos) and isnumber(mount.pos.x) and istable(mount.ang),
   "запомнено и место установки на кузове")
ok(tostring(mount.vehicle) == "Москвич", "название машины записано для картотеки", mount.vehicle)

-- «машину удалили»: знак уходит вместе с ней, запись остаётся
myPlate:Remove()
myCar:Remove()
ok(#PL.EntitiesOf(number2) == 0, "физического знака больше нет")
ok(PL.Get(number2).mount ~= nil, "но привязка к машине в реестре сохранилась")

-- машина выдана заново (та же запись гаража)
local sameCar = ents.Create("sim_car")
sameCar:SetPos(Vector(500, 0, 0))
sameCar.GRMGarageOwner, sameCar.GRMGarageID = owner, "veh_2"
recCar.plates = nil    -- даже если раскладка в гараже потерялась
local restored = PL.RestoreForVehicle(owner, sameCar, recCar)
ok(restored == 1, "знак вернулся на ту же машину по идентификатору из реестра", restored)
ok(sameCar:GetNWString("GRM_PlateNumber", "") == number2, "номер снова читается на машине")
ok(#PL.VehiclePlates(sameCar) == 1, "дублей знака не появилось")

-- чужая машина знак не получает
local otherCar = ents.Create("sim_car")
otherCar:SetPos(Vector(900, 0, 0))
local otherRec = { id = "veh_3", plates = nil }
ok(PL.RestoreForVehicle(owner, otherCar, otherRec) == 0, "на другую машину чужой знак не встаёт")

print("\n=== 15а. БАЗА НОМЕРОВ НЕ ЗАТИРАЕТСЯ ПУСТОТОЙ ===")
-- пока файл не прочитан, запись запрещена: иначе очередь сохранит пустую
-- таблицу поверх выданных номеров
local keepPlates, keepLoaded = PL.Data.plates, PL._loaded
PL._loaded = false
PL.Data.plates = {}
local savedWhileUnloaded = PL.SaveNow()
ok(savedWhileUnloaded == false, "до загрузки реестр на диск не пишется")
ok(files["grm_plates/registry.json"]:find(rec.number, 1, true) ~= nil,
   "файл с номерами остался целым")
PL._loaded, PL.Data.plates = keepLoaded, keepPlates
ok(PL.SaveNow() == true, "после загрузки запись снова разрешена")

print("\n=== 15. ПОДГОНКА ЗНАКА В ИГРЕ ===")
ok(isfunction(PL.RenderCommand), "команды подгонки объявлены")
local before = PL.Render.yaw
PL.RenderCommand(root, "yaw", 90)
ok(PL.Render.yaw == (before + 90) % 360, "поворот крутится по 90°", PL.Render.yaw)
PL.RenderCommand(root, "axis")
ok(PL.Render.axis ~= "auto", "ось переключается", PL.Render.axis)
PL.RenderCommand(root, "flip")
ok(PL.Render.flip == true, "зеркало переключается")
PL.RenderCommand(root, "scale", 1.5)
ok(math.abs(PL.Render.scale - 1.5) < 0.001, "масштаб задаётся числом")
PL.RenderCommand(root, "offset", 3)
ok(math.abs(PL.Render.offset - 3) < 0.001, "вынос надписи от поверхности настраивается", PL.Render.offset)
local faceOff = PL.FaceGeometry(Vector(-12, -36, -0.5), Vector(12, 36, 0.5),
    { axis = "auto", yaw = 0, scale = 1, offset = 3 })
ok(math.abs(faceOff.offset - 3) < 0.001, "и попадает в геометрию грани — надпись не тонет в пропе")

-- вынос считается по нормали ПЛОСКОСТИ надписи, а не по выбранной оси
local cl = (function()
    local f = io.open("lua/entities/grm_plate/cl_init.lua", "rb")
    local t = f:read("*a") f:close() return t
end)()
ok(cl:find("rgt:Cross(up)", 1, true) ~= nil,
   "нормаль берётся как векторное произведение осей надписи (вынос всегда «вперёд от текста»)")
ok(cl:find("nrm:Dot(eye - center) < 0", 1, true) ~= nil,
   "сторона выбирается по игроку — нет зеркальной изнанки")
ok(cl:find("center + nrm * (face.half + (face.offset or 1.5))", 1, true) ~= nil,
   "надпись выносится от поверхности, а не от центра модели")

-- плашка на экране показывается только при взгляде НА ЗНАК
local core = (function()
    local f = io.open("lua/autorun/sh_grm_plates.lua", "rb")
    local t = f:read("*a") f:close() return t
end)()
ok(core:find('lookPlate = (IsValid(ent) and ent:GetClass() == "grm_plate") and ent or nil', 1, true) ~= nil,
   "плашка ловит только сам знак")
ok(core:find('hook.Add("PostDrawTranslucentRenderables", "GRM_Plates_WorldLabel"', 1, true) ~= nil,
   "номер рисуется 3D2D в мире, а не поверх экрана")
ok(core:find('hook.Add("HUDPaint", "GRM_Plates_HUD"', 1, true) == nil,
   "экранной плашки посреди монитора больше нет")
ok(core:find("CurTime() - lookAt > 0.2", 1, true) ~= nil, "трассировка троттлится, покадровых трейсов нет")
PL.RenderCommand(civ, "yaw", 90)
ok(PL.Render.yaw ~= (before + 180) % 360, "обычный игрок настройку не крутит")
ok(PL.SaveRender() == true and files["grm_plates/render.json"] ~= nil, "раскладка сохраняется на диск")

print("\n=== 16. ПОЛНАЯ ПОДГОНКА ЗНАКА ===")
ok(istable(PL.RenderKeys) and #PL.RenderKeys == 10, "набор настроек раскладки объявлен", #PL.RenderKeys)
local norm = PL.NormalizeRender({ axis = "чтото", yaw = 137, scale = 99, offset = -5,
    tiltP = 400, moveX = 100, flip = 1 })
ok(norm.axis == "auto", "неизвестная ось падает в auto")
ok(norm.yaw % 90 == 0, "поворот кратен 90°", norm.yaw)
ok(norm.scale <= 3 and norm.offset >= 0, "масштаб и вынос зажаты в пределах")
ok(norm.tiltP <= 180 and norm.moveX <= 24, "наклон и сдвиг зажаты в пределах")
ok(norm.flip == false, "флаг зеркала — строго логический")

PL.RenderCommand(root, "reset")
ok(PL.Render.tiltP == 0 and PL.Render.moveX == 0, "сброс возвращает раскладку к базовой")
PL.RenderCommand(root, "tiltP", 15)
PL.RenderCommand(root, "tiltY", -30)
PL.RenderCommand(root, "tiltR", 45)
ok(PL.Render.tiltP == 15 and PL.Render.tiltY == -30 and PL.Render.tiltR == 45,
   "наклон крутится по трём осям", PL.Render.tiltP .. "/" .. PL.Render.tiltY .. "/" .. PL.Render.tiltR)
PL.RenderCommand(root, "moveX", 2)
PL.RenderCommand(root, "moveX", 2)
PL.RenderCommand(root, "moveY", -1.5)
ok(PL.Render.moveX == 4 and PL.Render.moveY == -1.5, "сдвиг накапливается по осям знака",
   PL.Render.moveX .. "/" .. PL.Render.moveY)
local faceFull = PL.FaceGeometry(Vector(-12, -36, -0.5), Vector(12, 36, 0.5), PL.Render)
ok(faceFull.tiltR == 45 and faceFull.moveX == 4, "доводка доходит до геометрии грани")
ok(cl:find("ang:RotateAroundAxis(ang:Forward(), face.tiltR)", 1, true) ~= nil
   and cl:find("ang:RotateAroundAxis(ang:Right(), face.tiltP)", 1, true) ~= nil
   and cl:find("ang:RotateAroundAxis(ang:Up(), face.tiltY)", 1, true) ~= nil,
   "все три оси поворота применяются при отрисовке")
ok(cl:find("rgt * (face.moveX or 0) + up * (face.moveY or 0)", 1, true) ~= nil,
   "сдвиг считается вдоль осей самой надписи")

print("\n=== 17. СНИМОК ОКНА ПОРЦИЯМИ ===")
ok(core:find("GRM.Net.Stream(PL.Net.SYNC", 1, true) ~= nil,
   "снимок реестра уходит потоком, а не одним пакетом")
ok(isfunction(PL.PushSoon), "серия действий схлопывается в одну отправку")

print(("\nPLATES: %d/%d, провалов: %d"):format(pass, pass + fail, fail))
if fail > 0 then os.exit(1) end
