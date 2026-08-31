--[[ Живой прогон горловины бака, шланга и синхронизации баков
     (заказ владельца 31.08: «нормальное крепление шлангов к баку»).

     ЧТО БЫЛО НЕ ТАК.

     1) ГОРЛОВИНА УГАДЫВАЛАСЬ ПО ГАБАРИТУ. Формула
        Vector(mn.x + 12, mx.y - 8, 35% высоты) — и в ядре, и копией
        в пистолете. simfphys отдаёт настоящую точку: ent:GetFuelPos().
        У реальных машин FuelFillPos разбросана по всем трём осям,
        включая знак Y, поэтому догадкой в неё не попасть.

     2) ШЛАНГА НЕ СУЩЕСТВОВАЛО. F.AttachHose и F.HoseToTank были
        заглушками, которые только удаляли веревку. Весь «шланг с
        провисом» — клиентский render.DrawBeam.

     3) ОБЪЁМ БАКА БЫЛ КОНСТАНТОЙ 100 Л, тип топлива угадывался
        по подстрокам в имени класса.

     4) ДВА НЕЗАВИСИМЫХ БАКА. GRM хранил литры в JSON, simfphys
        расходовал свои. Залив менял только запись GRM.

     Грузится РЕАЛЬНЫЙ lua/autorun/sh_grm_fuel.lua (SERVER=true).
     Запуск: luajit tools/luatest/sim_fuel_port.lua ]]

local pass, fail = 0, 0
local function ok(v, n, extra)
    if v then pass = pass + 1 print("  ok   " .. n)
    else fail = fail + 1 print("  FAIL " .. n .. "  " .. tostring(extra or "")) end
end

-----------------------------------------------------------------------
-- ОКРУЖЕНИЕ
-----------------------------------------------------------------------
SERVER, CLIENT = true, false
function AddCSLuaFile() end
function istable(v) return type(v) == "table" end
function isstring(v) return type(v) == "string" end
function isnumber(v) return type(v) == "number" end
function isfunction(v) return type(v) == "function" end
function isvector(v) return istable(v) and v.x ~= nil and v.y ~= nil and v.z ~= nil end
function IsValid(v) return istable(v) and v._valid ~= false end
function math.Clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end
function Color(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end

local VecMT = {}
VecMT.__index = VecMT
function VecMT:DistToSqr(o)
    local dx, dy, dz = self.x - o.x, self.y - o.y, self.z - o.z
    return dx * dx + dy * dy + dz * dz
end
function VecMT:Distance(o) return math.sqrt(self:DistToSqr(o)) end
function VecMT:Length() return math.sqrt(self.x^2 + self.y^2 + self.z^2) end
function VecMT:Dot(o) return self.x * o.x + self.y * o.y + self.z * o.z end
function VecMT:Normalize()
    local l = self:Length()
    if l > 0 then self.x, self.y, self.z = self.x / l, self.y / l, self.z / l end
    return self
end
VecMT.__add = function(a, b) return Vector(a.x + b.x, a.y + b.y, a.z + b.z) end
VecMT.__sub = function(a, b) return Vector(a.x - b.x, a.y - b.y, a.z - b.z) end
VecMT.__mul = function(a, b)
    if isnumber(b) then return Vector(a.x * b, a.y * b, a.z * b) end
    if isnumber(a) then return Vector(b.x * a, b.y * a, b.z * a) end
    return Vector(a.x * b.x, a.y * b.y, a.z * b.z)
end
VecMT.__eq = function(a, b)
    return math.abs(a.x - b.x) < 1e-6 and math.abs(a.y - b.y) < 1e-6 and math.abs(a.z - b.z) < 1e-6
end
function Vector(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, VecMT) end
function Angle(p, y, r) return { p = p or 0, y = y or 0, r = r or 0 } end
vector_origin = Vector(0, 0, 0)

function CurTime() return 100 end
function ErrorNoHalt() end
function CreateConVar() end
function GetConVar() return { GetInt = function() return 3 end } end
function SafeRemoveEntity(e) if istable(e) then e._valid = false end end
bit = { bor = function(a) return a end }
FCVAR_ARCHIVE, FCVAR_REPLICATED = 1, 2
os.time = function() return 1700000000 end

hook = { _t = {} }
function hook.Add(e, i, f) hook._t[e] = hook._t[e] or {}; hook._t[e][i] = f end
function hook.Run(e, ...) end
timer = { Simple = function(_, f) f() end, Create = function() end, Remove = function() end, Exists = function() return false end }
concommand = { Add = function() end }
util = { AddNetworkString = function() end, TableToJSON = function() return "[]" end,
    JSONToTable = function() return {} end }
file = { Exists = function() return false end, Read = function() return "" end,
    Write = function() end, CreateDir = function() end }
net = setmetatable({}, { __index = function() return function() return "" end end })
game = { GetMap = function() return "rp_city" end }
ents = { FindByClass = function() return {} end, FindInSphere = function() return {} end,
    GetAll = function() return {} end, Create = function() return { _valid = false } end }

-- веревки: считаем, сколько раз шланг реально натянули
local ROPES, LASTROPE = 0, nil
constraint = {
    Rope = function(...) ROPES = ROPES + 1; LASTROPE = { ... }; return true end,
    RemoveConstraints = function() end,
}

GRM = { Perf = {} }
GRM.Notify = function() end
GRM.Vehicles = {
    EnsureUID = function() end,
    UID = function(e) return istable(e) and e._uid or "" end,
}

-----------------------------------------------------------------------
-- МАШИНА
-----------------------------------------------------------------------
--[[ Настоящая семантика simfphys: база при спавне кладёт FuelFillPos,
     FuelTankSize и FuelType на сущность и поднимает их в сеть
     (spawn.lua:149-155). Отдаём их теми же именами, что и база. ]]
local function mkCar(opts)
    opts = opts or {}
    local c = {
        _valid = true, _uid = opts.uid or "car:1",
        _pos = opts.pos or Vector(0, 0, 0),
        _nw = {}, _mins = Vector(-110, -40, 0), _maxs = Vector(110, 40, 60),
        IsSimfphysCar = true,
    }
    c.GetClass = function() return "gmod_sent_vehicle_fphysics_base" end
    -- Старый путь угадывания типа читает и модель: без неё мок падает,
    -- и проверка отката становится пустой.
    c.GetModel = function() return "models/vehicle.mdl" end
    c.EntIndex = function() return 7 end
    c.GetPos = function(s) return s._pos end
    c.OBBMins = function(s) return s._mins end
    c.OBBMaxs = function(s) return s._maxs end
    c.LocalToWorld = function(s, v) return Vector(s._pos.x + v.x, s._pos.y + v.y, s._pos.z + v.z) end
    c.WorldToLocal = function(s, v) return Vector(v.x - s._pos.x, v.y - s._pos.y, v.z - s._pos.z) end
    c.GetForward = function() return Vector(1, 0, 0) end
    c.SetNWFloat = function(s, k, v) s._nw[k] = v end
    c.GetNWFloat = function(s, k, d) local v = s._nw[k] if v == nil then return d end return v end
    c.SetNWString = function(s, k, v) s._nw[k] = v end
    c.GetNWString = function(s, k, d) local v = s._nw[k] if v == nil then return d end return v end
    c.SetNWBool = function(s, k, v) s._nw[k] = v end
    c.GetNWBool = function(s, k, d) local v = s._nw[k] if v == nil then return d end return v end
    --[[ GetFuelPos в simfphys отдаёт МИРОВУЮ точку:
         LocalToWorld(GetFuelPortPosition()). Мок обязан повторять это
         один в один, иначе проверка горловины меряет локальное
         смещение как мировое и считает её вне габарита. ]]
    if opts.fuelPos then
        c.GetFuelPortPosition = function() return opts.fuelPos end
        c.GetFuelPos = function(s) return s:LocalToWorld(opts.fuelPos) end
    end
    if opts.maxFuel then
        c._maxFuel = opts.maxFuel
        c._fuel = opts.fuel or 0
        c.GetMaxFuel = function(s) return s._maxFuel end
        c.SetMaxFuel = function(s, v) s._maxFuel = tonumber(v) or s._maxFuel end
        c.GetFuel = function(s) return s._fuel end
        c.SetFuel = function(s, v) s._fuel = math.Clamp(tonumber(v) or 0, 0, s._maxFuel or 100) end
    end
    if opts.fuelType then c.GetFuelType = function() return opts.fuelType end end
    return c
end

local function mkPumpAt(pos)
    local p = {
        _valid = true, _pos = pos, _nw = {},
        GetClass = function() return "grm_fuel_pump" end,
        GetPos = function(s) return s._pos end,
        LocalToWorld = function(s, v) return Vector(s._pos.x + v.x, s._pos.y + v.y, s._pos.z + v.z) end,
        WorldToLocal = function(s, v) return Vector(v.x - s._pos.x, v.y - s._pos.y, v.z - s._pos.z) end,
        GetFuelKind = function() return "petrol" end,
    }
    return p
end

assert(loadfile("lua/autorun/sh_grm_fuel.lua"))()
local F = GRM.Fuel

-----------------------------------------------------------------------
print("=== 1. ГОРЛОВИНА БЕРЁТСЯ У МАШИНЫ, А НЕ УГАДЫВАЕТСЯ ===")
-----------------------------------------------------------------------
do
    --[[ Горловина у этой машины СЛЕВА: y = -35, а старая формула
         брала mx.y - 8, то есть ВСЕГДА правый борт. По x совпасть
         ещё могло, по y — никогда. ]]
    local car = mkCar({ uid = "car:port", fuelPos = Vector(-95, -35, 30), maxFuel = 80 })
    local pos, normal, known = F.FillPort(car)
    ok(known == true, "машина отдала настоящую горловину", tostring(known))
    ok(pos == car:LocalToWorld(Vector(-95, -35, 30)),
        "ГОРЛОВИНА НА МЕСТЕ, КОТОРОЕ ЗАДАЛА МАШИНА", tostring(pos and pos.x))
    ok(normal ~= nil and normal:Length() > 0.9, "нормаль посчитана",
        normal and tostring(normal:Length()))

    -- Старая формула давала совсем другую точку — это и есть суть жалобы.
    local mn, mx = car:OBBMins(), car:OBBMaxs()
    local old = car:LocalToWorld(Vector(mn.x + 12, mx.y - 8, (mn.z + mx.z) * 0.35))
    ok(old:Distance(pos) > 30, "старая догадка уезжала от горловины далеко",
        ("%.1f юнитов"):format(old:Distance(pos)))
end

do
    -- База ставит Vector(0,0,0), если в конверсии нет FuelFillPos.
    -- Такую точку надо отбросить, а не тащить шланг в origin машины.
    local car = mkCar({ uid = "car:hollow", fuelPos = Vector(0, 0, 0), maxFuel = 65 })
    local pos, _, known = F.FillPort(car)
    ok(known == false, "пустая горловина (origin) отброшена", tostring(known))
    ok(isvector(pos), "фолбэк всё равно даёт точку")
end

do
    local car = mkCar({ uid = "car:van" })   -- вообще без данных о баке
    local pos, _, known = F.FillPort(car)
    ok(known == false, "без данных о горловине считаем по габариту", tostring(known))
    local mn, mx = car:OBBMins(), car:OBBMaxs()
    ok(pos == car:LocalToWorld(Vector(mn.x + 12, mx.y - 8, (mn.z + mx.z) * 0.35)),
        "фолбэк совпадает с прежним расчётом")
end

-----------------------------------------------------------------------
print("\n=== 2. ОБЪЁМ И ТИП БЕРУТСЯ У МАШИНЫ ===")
-----------------------------------------------------------------------
do
    local car = mkCar({ uid = "car:size", maxFuel = 80, fuelType = 2 })
    ok(F.TankSize(car) == 80, "ОБЪЁМ БАКА ИЗ МАШИНЫ, А НЕ КОНСТАНТА 100",
        tostring(F.TankSize(car)))
    ok(F.TankSize() == 100, "без машины остаётся фолбэк 100", tostring(F.TankSize()))
    ok(F.GuessType(car) == "diesel", "тип из машины: дизель", tostring(F.GuessType(car)))

    local elec = mkCar({ uid = "car:elec", maxFuel = 60, fuelType = 3 })
    ok(F.GuessType(elec) == "electric", "тип из машины: электричество", tostring(F.GuessType(elec)))
    local pet = mkCar({ uid = "car:pet", maxFuel = 65, fuelType = 1 })
    ok(F.GuessType(pet) == "petrol", "тип из машины: бензин", tostring(F.GuessType(pet)))
end

-----------------------------------------------------------------------
print("\n=== 3. ШЛАНГ СТАЛ НАСТОЯЩИМ ===")
-----------------------------------------------------------------------
do
    local pump = mkPumpAt(Vector(0, 0, 0))
    local car = mkCar({ uid = "car:hose", pos = Vector(200, 0, 0),
        fuelPos = Vector(-40, 45, 25), maxFuel = 80 })
    ROPES = 0
    local done = F.HoseToTank(pump, car)
    ok(done == true, "шланг дотянулся до машины", tostring(done))
    ok(ROPES == 1, "ВЕРЕВКА СОЗДАНА — ШЛАНГ ПРИВЯЗАН", tostring(ROPES))
    ok(pump.GRMHoseTarget == car, "шланг помнит, к чему привязан")
    if LASTROPE then
        local lpos = LASTROPE[6]
        ok(isvector(lpos) and lpos == car:WorldToLocal(car:GetFuelPos()),
            "КОНЕЦ ШЛАНГА — НА ГОРЛОВИНЕ, А НЕ НА ДОГАДКЕ",
            lpos and ("%.1f/%.1f/%.1f"):format(lpos.x, lpos.y, lpos.z) or "nil")
    end

    -- Далеко: шланг физически не дотягивается.
    local far = mkCar({ uid = "car:far", pos = Vector(2000, 0, 0), fuelPos = Vector(-40, 45, 25) })
    ROPES = 0
    ok(F.HoseToTank(pump, far) == false, "далеко — шланг не дотягивается")
    ok(ROPES == 0, "веревка на таком расстоянии не создаётся", tostring(ROPES))
    ok(F.HoseLength ~= nil and F.HoseLength > 0, "длина шланга задана свойством",
        tostring(F.HoseLength))
end

-----------------------------------------------------------------------
print("\n=== 4. БАК ОДИН: ЗАЛИТОЕ ПОПАДАЕТ В МАШИНУ ===")
-----------------------------------------------------------------------
do
    local car = mkCar({ uid = "car:sync", maxFuel = 80, fuelPos = Vector(-40, 45, 25) })
    local rec = F.Get("car:sync")
    rec.liters = 50
    rec.typ = "petrol"
    car:SetFuel(50)

    local added = select(1, F.AddLiters(car, 10, "petrol"))
    ok(added ~= nil and added > 0, "залив принят", tostring(added))
    ok(car:GetFuel() > 50, "ЗАЛИТОЕ ПОПАЛО И В БАК САМОЙ МАШИНЫ",
        tostring(car:GetFuel()))
    ok(math.abs(car:GetFuel() - rec.liters) < 0.01,
        "запись и бак совпадают", ("бак %.1f / запись %.1f"):format(car:GetFuel(), rec.liters))

    -- Объём бака уважаем: больше 80 не льём.
    rec.liters = 78
    car:SetFuel(78)
    F.AddLiters(car, 30, "petrol")
    ok(rec.liters <= 80.01, "сверх объёма бака не льём", tostring(rec.liters))
end

-----------------------------------------------------------------------
print("\n=== 5. РАСХОД НА ХОДУ ПОПАДАЕТ В УЧЁТ ===")
-----------------------------------------------------------------------
do
    local car = mkCar({ uid = "car:burn", maxFuel = 80, fuelPos = Vector(-40, 45, 25) })
    local rec = F.Get("car:burn")
    rec.liters = 60
    rec.typ = "petrol"

    F.ApplyNW(car)
    ok(math.abs(car:GetFuel() - 60) < 0.01,
        "при первом обращении сохранённое отдаётся машине", tostring(car:GetFuel()))

    -- Едем: simfphys тратит своё. Учёт должен это увидеть.
    car:SetFuel(23)
    F.ApplyNW(car)
    ok(math.abs(rec.liters - 23) < 0.01,
        "РАСХОД МАШИНЫ ЗЕРКАЛИТСЯ В УЧЁТ", ("учёт %.1f / бак %.1f"):format(rec.liters, car:GetFuel()))
end

print(("\n\nFUEL PORT: %d/%d, провалов: %d"):format(pass, pass + fail, fail))
if fail > 0 then os.exit(1) end
