--[[ Живой прогон лимита одинаковых машин у дилера и «узнаваемости»
     купленного транспорта.
     Запуск: ./.luabuild/lj/src/luajit tools/luatest/sim_vehicle_class_limit.lua ]]
SERVER, CLIENT = true, false
function AddCSLuaFile() end
NULL = { _valid = false }

function CurTime() return 100 end
function IsValid(v) return type(v) == "table" and v._valid ~= false end
function istable(v) return type(v) == "table" end
function isstring(v) return type(v) == "string" end
function isfunction(v) return type(v) == "function" end
function math.Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function table.Count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end
bit = { bor = function(a) return a end }
FCVAR_ARCHIVE = 1

local convars = {}
function CreateConVar(name, def)
    local cv = { value = def }
    function cv:GetInt() return math.floor(tonumber(self.value) or 0) end
    function cv:GetBool() return tostring(self.value) == "1" end
    convars[name] = cv
    return cv
end

-- Минимальный слой дилера: берём ровно те функции, которые отвечают за лимит.
GRM = { Format = function(n) return tostring(n) .. " GRM" end }
local VD = { Active = {}, Garages = {}, MaxActive = 3 }
GRM.VehicleDealer = VD
VD.ClassLimitCvar = CreateConVar("grm_vd_class_limit", "2", 1, "")

function VD.GarageRecords(ply) VD.Garages[ply] = VD.Garages[ply] or {} return VD.Garages[ply] end
function VD.ClassLimit() return math.max(0, VD.ClassLimitCvar:GetInt()) end
function VD.CountClass(ply, class)
    class = tostring(class or "") if class == "" then return 0 end
    local n, counted = 0, {}
    for id, rec in pairs(VD.GarageRecords(ply) or {}) do
        if istable(rec) and tostring(rec.class or "") == class then n = n + 1 counted[id] = true end
    end
    for id, ent in pairs(VD.Active) do
        if not counted[id] and IsValid(ent) and ent.GRMGarageOwner == ply and tostring(ent.VD_Class or "") == class then n = n + 1 end
    end
    return n
end
function VD.CanOwnMore(ply, class)
    local limit = VD.ClassLimit()
    if limit <= 0 then return true end
    local have = VD.CountClass(ply, class)
    if have < limit then return true, have, limit end
    return false, have, limit
end
function VD.TagVehicle(ent, ply, class, kind, record)
    if not IsValid(ent) then return end
    ent.VD_Class = class ent.VD_Owner = ply ent.GRMVehicleKind = kind
    ent.nw = ent.nw or {}
    ent.nw.GRM_VehicleClass = tostring(class or "")
    ent.nw.GRM_VehicleKind = tostring(kind or "personal")
    ent.nw.GRM_VehicleName = tostring(istable(record) and record.name or class or "")
    if IsValid(ply) then ent.nw.GRM_VehicleOwner = ply.name end
    if istable(record) and record.id then ent.nw.GRM_VehicleRecord = tostring(record.id) end
end
function VD.IsDealerVehicle(ent)
    return IsValid(ent) and (ent.GRMGarageID ~= nil or tostring((ent.nw or {}).GRM_VehicleClass or "") ~= "")
end

local fails, total = 0, 0
local function ok(cond, name, extra)
    total = total + 1
    if cond then print("  ok   " .. name)
    else fails = fails + 1 print("  FAIL " .. name .. "  " .. tostring(extra or "")) end
end

local ply = { _valid = true, name = "Buyer" }
local other = { _valid = true, name = "Other" }
local BOBCAT = "simfphys_gta_sa_bobcat"

local function buy(owner, class, id, service)
    local allowed, have, limit = VD.CanOwnMore(owner, class)
    if not allowed then return false, ("У вас уже %d шт. — предел %d"):format(have, limit) end
    local rec = { id = id, class = class, name = "Bobcat", service = service == true }
    if not service then VD.GarageRecords(owner)[id] = rec end
    local ent = { _valid = true, GRMGarageID = id, GRMGarageOwner = owner }
    VD.TagVehicle(ent, owner, class, service and "government" or "personal", rec)
    VD.Active[id] = ent
    return true, ent
end

print("\n=== 1. ЛИМИТ НА КЛАСС ===")
ok(VD.ClassLimit() == 2, "лимит по умолчанию — 2 машины одного класса")
ok(select(1, buy(ply, BOBCAT, "v1")) == true, "первая машина покупается")
ok(select(1, buy(ply, BOBCAT, "v2")) == true, "вторая машина покупается")
local third, msg = buy(ply, BOBCAT, "v3")
ok(third == false and tostring(msg):find("предел"), "третья того же класса — отказ", msg)
ok(VD.CountClass(ply, BOBCAT) == 2, "счётчик класса показывает 2", VD.CountClass(ply, BOBCAT))

print("\n=== 2. ГРАНИЦЫ ЛИМИТА ===")
ok(select(1, buy(ply, "simfphys_gta_sa_infernus", "v4")) == true, "другой класс лимитом не тронут")
ok(select(1, buy(other, BOBCAT, "v5")) == true, "лимит считается на игрока, а не на сервер")

-- Машина, стоящая в гараже, всё равно занимает слот класса.
VD.Active["v1"] = nil
ok(VD.CountClass(ply, BOBCAT) == 2, "машина в гараже тоже считается")
ok(select(1, buy(ply, BOBCAT, "v6")) == false, "пока одна в гараже — третью не купить")

-- Продали одну: слот освободился.
VD.GarageRecords(ply)["v1"] = nil
ok(VD.CountClass(ply, BOBCAT) == 1, "после продажи остался один")
ok(select(1, buy(ply, BOBCAT, "v7")) == true, "освободившийся слот снова доступен")

print("\n=== 3. СЛУЖЕБНЫЕ И НАСТРОЙКА ===")
VD.Active = {} VD.Garages = {}
ok(select(1, buy(ply, BOBCAT, "s1", true)) == true and select(1, buy(ply, BOBCAT, "s2", true)) == true,
    "служебные без записи гаража тоже считаются по карте")
ok(select(1, buy(ply, BOBCAT, "s3", true)) == false, "третья служебная того же класса не выдаётся")

convars["grm_vd_class_limit"].value = "0"
ok(VD.CanOwnMore(ply, BOBCAT) == true, "лимит 0 = без ограничений")
convars["grm_vd_class_limit"].value = "1"
VD.Active = {} VD.Garages = {}
buy(ply, BOBCAT, "l1")
ok(select(1, buy(ply, BOBCAT, "l2")) == false, "лимит настраивается конваром (1)")
convars["grm_vd_class_limit"].value = "2"

print("\n=== 4. УЗНАВАЕМОСТЬ КУПЛЕННОГО ===")
VD.Active = {} VD.Garages = {}
local okBuy, ent = buy(ply, BOBCAT, "r1")
ok(okBuy and VD.IsDealerVehicle(ent) == true, "машина дилера опознаётся")
ok(ent.nw.GRM_VehicleClass == BOBCAT, "на машине записан класс")
ok(ent.nw.GRM_VehicleKind == "personal", "записан тип владения")
ok(ent.nw.GRM_VehicleOwner == "Buyer", "записан владелец")
ok(ent.nw.GRM_VehicleRecord == "r1", "записан id гаражной записи")
ok(VD.IsDealerVehicle({ _valid = true }) == false, "чужая машина за дилерскую не считается")

print("\n=== 5. ЭТО ЖЕ ВКЛЮЧЕНО В САМОМ ДИЛЕРЕ ===")
local function read(path) local f = assert(io.open(path, "rb")) local src = f:read("*a") f:close() return src end
local core = read("lua/autorun/sh_grm_vehicle_dealer.lua")
local cl = read("lua/entities/sent_vehicle_dealer/cl_init.lua")
local function has(src, n) return src:find(n, 1, true) ~= nil end

ok(has(core, 'VD.Version="3.7.0"'), "версия дилера поднята")
ok(has(core, 'CreateConVar("grm_vd_class_limit", "2"'), "лимит задан конваром со значением 2")
ok(has(core, "function VD.CountClass") and has(core, "function VD.CanOwnMore"), "счётчик и проверка лимита в дилере")
ok(has(core, "local allowed,have,limit=VD.CanOwnMore(ply,class)"), "покупка спрашивает лимит")
ok(has(core, "это предел (%d на класс)"), "отказ объясняет, сколько уже есть и какой предел")
ok(has(core, "function VD.TagVehicle") and has(core, "VD.TagVehicle(ent,ply,class,kind,record)"),
    "купленная машина помечается едиными метками")
ok(has(core, 'VD.TagVehicle(ent,ply,r.class,tostring(r.ownershipType or"personal"),r)'),
    "выдача из гаража ставит те же метки")
ok(has(core, "function VD.IsDealerVehicle"), "есть публичная проверка «машина от дилера»")
ok(has(core, "owned=VD.CountClass(ply,e.class),classLimit=VD.ClassLimit()"), "каталог знает про счётчик и лимит")
ok(has(cl, "У вас: %d из %d"), "в карточке видно, сколько таких машин уже есть")
ok(has(cl, 'capped and "ЛИМИТ"') and has(cl, "b:SetEnabled(not capped)"), "кнопка блокируется на пределе")

print("\n=== 6. РЕЖИМ ВЫДАЧИ У ДИЛЕРА ===")
local tool = read("lua/weapons/gmod_tool/stools/vehicle_dealer_tool.lua")
ok(has(core, "VD.DeliveryModes = {") and has(core, 'dealer = "Выдавать у дилера"')
    and has(core, 'garage = "Отправлять в гараж"') and has(core, 'both   = "На выбор игрока"'),
    "три режима выдачи покупок")
ok(has(core, "function VD.DeliveryMode") and has(core, "function VD.ShowRetrieve"),
    "режим и показ кнопки «ВЫДАТЬ» читаются из настроек дилера")
ok(has(core, "delivery=VD.DeliveryMode(ent),showRetrieve=VD.ShowRetrieve(ent)"),
    "настройки сохраняются в записи дилера (переживают рестарт)")
ok(has(core, 'ent.VD_Delivery=VD.DeliveryModes[tostring(r.delivery or"")]'), "и читаются при загрузке карты")
ok(has(core, 'local toGarage=(mode=="garage")or(mode=="both"and wantWay=="garage")'),
    "покупка уходит в гараж по настройке или по выбору игрока")
ok(has(core, 'if toGarage and kind~="personal" then toGarage=false end'),
    "служебный транспорт всегда выдаётся на месте")
ok(has(core, "record.stored=true;saveGarage()"), "покупка «в гараж» не спавнится на площадке, а сразу на хранении")
ok(has(core, 'if not VD.ShowRetrieve(dealer)then result(ply,false,"Этот дилер не выдаёт транспорт'),
    "при выключенной кнопке сервер тоже не выдаёт (не только UI)")
ok(has(core, "net.WriteString(VD.DeliveryMode(dealer))net.WriteBool(VD.ShowRetrieve(dealer))"),
    "режим уходит в окно игрока")
ok(has(cl, 'buyButton("КУПИТЬ В ГАРАЖ"') and has(cl, 'buyButton("КУПИТЬ И ВЫДАТЬ"'),
    "кнопки покупки зависят от режима")
ok(has(cl, "ЗАБРАТЬ В ГАРАЖЕ"), "кнопка выдачи из гаража подписана честно, когда дилер не выдаёт")
ok(has(cl, "Выдача покупок:") and has(cl, "Показывать кнопку «ВЫДАТЬ» из гаража"),
    "настройки есть в админке дилера")
ok(has(cl, "delivery = deliveryMode, showRetrieve = showRetrieve"), "админка сохраняет настройки")
ok(has(tool, "delivery = GRM.VehicleDealer.DeliveryMode(ent)"), "тул отдаёт текущие настройки в админку")

print(("\nVEHICLE CLASS LIMIT: %d/%d, провалов: %d"):format(total - fails, total, fails))
if fails > 0 then os.exit(1) end
