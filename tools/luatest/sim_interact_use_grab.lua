--[[--------------------------------------------------------------------
    sim_interact_use_grab — короткий E не должен открывать дверь, когда
    игрок собирался вызвать кольцо действий.

    ЖАЛОБА ВЛАДЕЛЬЦА (31.08): «Взаимодействие с дверями на Е что-то как
    то не круто выходит. И меню вылазит интерактивное и двери сразу
    открываются».

    ПРИЧИНА. IN_USE снимался в StartCommand только при УЖЕ ОТКРЫТОМ
    кольце. Но кольцо появляется через 0.22 с удержания, и всё это
    время нажатие уходило на сервер как обычное «использовать» — дверь
    успевала открыться. В итоге игрок получал и распахнутую дверь, и
    кольцо поверх неё.

    ФИКС. IN_USE перехватывается с ПЕРВОГО тика нажатия, пока модуль
    решает, клик это или удержание. Чтобы короткий клик не пропал, он
    проигрывается вручную: на отпускании раньше порога поднимается
    флаг, и следующие несколько тиков IN_USE выставляется
    принудительно.

    ЧТО ПРОВЕРЯЕМ. Реальную последовательность тиков на боевом модуле:
    нажатие → тики удержания → отпускание → тики после. Смотрим, что
    именно уходит на сервер в каждый момент.

    Запуск: luajit tools/luatest/sim_interact_use_grab.lua
----------------------------------------------------------------------]]

local pass, fail = 0, 0
local function ok(v, name, extra)
    if v then pass = pass + 1 print("  ok   " .. name)
    else fail = fail + 1 print("  FAIL " .. name .. "   " .. tostring(extra or "")) end
end

-----------------------------------------------------------------------
-- Мок GMod (клиентская сторона модуля).
-----------------------------------------------------------------------
SERVER, CLIENT = false, true
function AddCSLuaFile() end
function istable(v) return type(v) == "table" end
function isfunction(v) return type(v) == "function" end
function isstring(v) return type(v) == "string" end
function isnumber(v) return type(v) == "number" end
function IsValid(v) return istable(v) and v._valid ~= false end

local NOW = 100
function RealTime() return NOW end
function CurTime() return NOW end
function FrameTime() return 0.016 end
function SysTime() return NOW end

math.Clamp = function(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end
math.Approach = function(cur, target, inc)
    inc = math.abs(inc)
    if cur < target then return math.min(cur + inc, target) end
    if cur > target then return math.max(cur - inc, target) end
    return target
end
function Color(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end

local VMeta = {}
VMeta.__index = VMeta
function VMeta:DistToSqr(o)
    local dx, dy, dz = self.x - o.x, self.y - o.y, self.z - o.z
    return dx * dx + dy * dy + dz * dz
end
VMeta.__add = function(a, b) return Vector(a.x + b.x, a.y + b.y, a.z + b.z) end
VMeta.__mul = function(a, b) return Vector(a.x * b, a.y * b, a.z * b) end
function Vector(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, VMeta) end
function Angle(p, y, r) return { p = p or 0, y = y or 0, r = r or 0 } end

-- Битовые операции: ими выставляется кнопка в SetButtons.
bit = {
    bor = function(a, b) 
        -- Достаточно объединения флагов, значения у нас степени двойки.
        if a % (b * 2) >= b then return a end
        return a + b
    end,
}

local HOOKS = {}
hook = {
    Add = function(e, n, f) HOOKS[e] = HOOKS[e] or {} HOOKS[e][n] = f end,
    Remove = function(e, n) if HOOKS[e] then HOOKS[e][n] = nil end end,
    Run = function() end, Call = function() end,
}
local function fire(e, ...)
    for _, f in pairs(HOOKS[e] or {}) do f(...) end
end

timer = { Simple = function() end, Create = function() end, Remove = function() end }
util = {
    AddNetworkString = function() end,
    TraceLine = function() return { Entity = _G.__TRACE_HIT or { _valid = false } } end,
}
MASK_SHOT = 1
net = setmetatable({}, { __index = function() return function() return "" end end })
concommand = { Add = function() end }
local CVARS = { grm_cl_interact = "1" }
function CreateClientConVar(n, d) CVARS[n] = CVARS[n] or tostring(d) end
function GetConVarNumber(n) return tonumber(CVARS[n]) or 0 end
surface = setmetatable({}, { __index = function() return function() return 10, 10 end end })
draw = setmetatable({}, { __index = function() return function() end end })
gui = {
    MousePos = function() return 0, 0 end, EnableScreenClicker = function() end,
    IsGameUIVisible = function() return false end, IsConsoleVisible = function() return false end,
}
local KEYS_DOWN = {}
input = { IsKeyDown = function(k) return KEYS_DOWN[k] == true end }
--[[ Панель-заглушка: кольцу нужен объект с методами VGUI. Возвращать
     невалидную пустышку нельзя — модуль сразу падает на SetSize. ]]
vgui = {
    Create = function()
        local p = { _valid = true }
        setmetatable(p, { __index = function() return function() end end })
        return p
    end,
}
function ScrW() return 1920 end
function ScrH() return 1080 end
KEY_E = 22
MOUSE_LEFT, MOUSE_RIGHT = 107, 108
IN_ATTACK, IN_ATTACK2, IN_USE = 1, 2, 32

GRM = { Notify = function() end }
GRM.Doors = {
    IsDoor = function(e) return istable(e) and e._locked ~= nil end,
    IsDoorLocked = function(e) return e._locked == true end,
    CanToggleLock = function() return true end,
}

local ply = { _valid = true }
function ply:IsPlayer() return true end
function ply:Alive() return true end
function ply:InVehicle() return false end
function ply:IsTyping() return false end
function ply:GetShootPos() return Vector(0, 0, 0) end
function ply:GetAimVector() return Vector(1, 0, 0) end
function ply:EyeAngles() return Angle(0, 0, 0) end
function LocalPlayer() return ply end

assert(loadfile("lua/autorun/sh_grm_interact.lua"))()
local I = GRM.Interact
assert(I, "модуль не загрузился")

-- Дверь перед игроком.
local door = { _valid = true, _locked = true, _nw = {}, _nwb = {} }
function door:GetNWString(k, d) return self._nw[k] or d or "" end
function door:GetNWBool(k, d) if self._nwb[k] == nil then return d or false end return self._nwb[k] end
function door:GetParent() return { _valid = false } end
_G.__TRACE_HIT = door

-----------------------------------------------------------------------
-- Поддельная команда движка: смотрим, что реально уходит на сервер.
-----------------------------------------------------------------------
local function mkCmd(buttons)
    local c = { _b = buttons or 0, _cleared = false, _mx = nil }
    function c:GetButtons() return self._b end
    function c:SetButtons(v) self._b = v end
    function c:RemoveKey(k) if self._b % (k * 2) >= k then self._b = self._b - k end end
    function c:ClearMovement() self._cleared = true end
    function c:SetViewAngles() end
    function c:SetMouseX(v) self._mx = v end
    function c:SetMouseY() end
    function c:HasUse() return self._b % (IN_USE * 2) >= IN_USE end
    return c
end

-- Один игровой тик: игрок держит E (или нет).
local function tick(holdingE)
    local cmd = mkCmd(holdingE and IN_USE or 0)
    fire("Think")
    fire("StartCommand", ply, cmd)
    return cmd
end

-----------------------------------------------------------------------
print("\n=== 1. ВОСПРОИЗВЕДЕНИЕ БАГА: E НЕ ДОЛЖЕН ОТКРЫВАТЬ ДВЕРЬ СРАЗУ ===")
-----------------------------------------------------------------------
do
    KEYS_DOWN[KEY_E] = true
    fire("PlayerButtonDown", ply, KEY_E)

    --[[ Первые тики после нажатия. Игрок ещё держит клавишу, модуль
         решает — клик или удержание. Дверь трогать НЕЛЬЗЯ. ]]
    local leaked = 0
    for _ = 1, 5 do
        NOW = NOW + 0.02
        if tick(true):HasUse() then leaked = leaked + 1 end
    end
    ok(leaked == 0,
        "ИСПРАВЛЕНО: за время удержания IN_USE ни разу не ушёл на сервер", leaked)
end

-----------------------------------------------------------------------
print("\n=== 2. УДЕРЖАНИЕ ОТКРЫВАЕТ КОЛЬЦО ===")
-----------------------------------------------------------------------
do
    -- Досидели до порога.
    NOW = NOW + I.HoldTime
    tick(true)
    ok(I.Radial.open == true, "после порога кольцо открылось")

    -- И пока оно открыто, дверь по-прежнему не трогается.
    local leaked = 0
    for _ = 1, 3 do
        NOW = NOW + 0.02
        if tick(true):HasUse() then leaked = leaked + 1 end
    end
    ok(leaked == 0, "при открытом кольце IN_USE тоже не проходит", leaked)

    local cmd = tick(true)
    ok(cmd._mx == 0, "мышь не крутит игрока, пока открыто кольцо")
    ok(cmd._cleared == true, "движение заблокировано")
end

-----------------------------------------------------------------------
print("\n=== 3. КОРОТКИЙ КЛИК ОСТАЁТСЯ ОБЫЧНЫМ E ===")
-----------------------------------------------------------------------
do
    -- Закрываем кольцо и начинаем заново.
    I.CloseRadial()
    KEYS_DOWN[KEY_E] = false
    NOW = NOW + 1

    fire("PlayerButtonDown", ply, KEY_E)
    KEYS_DOWN[KEY_E] = true

    -- Пара тиков — и сразу отпустили (это клик, не удержание).
    NOW = NOW + 0.02
    ok(not tick(true):HasUse(), "во время клика E ещё придержан")

    NOW = NOW + 0.03
    KEYS_DOWN[KEY_E] = false
    fire("PlayerButtonUp", ply, KEY_E)

    ok(I.Radial.open == false, "кольцо от короткого клика не открылось")

    --[[ Самое важное: «съеденный» клик должен вернуться игре, иначе
         дверь вообще перестанет открываться обычным способом. ]]
    local delivered = 0
    for _ = 1, 5 do
        NOW = NOW + 0.02
        if tick(false):HasUse() then delivered = delivered + 1 end
    end
    ok(delivered > 0,
        "ИСПРАВЛЕНО: короткий клик проигран вручную — дверь откроется", delivered)
    ok(delivered >= 2,
        "нажатие держится несколько тиков, иначе сервер его не засчитает", delivered)
end

-----------------------------------------------------------------------
print("\n=== 4. ПОСЛЕ КЛИКА IN_USE НЕ ЗАЛИПАЕТ ===")
-----------------------------------------------------------------------
do
    --[[ Если бы флаг не гас, «использовать» жалось бы бесконечно:
         дверь хлопала бы сама, а игрок не смог бы отпустить. ]]
    local stuck = 0
    for _ = 1, 10 do
        NOW = NOW + 0.02
        if tick(false):HasUse() then stuck = stuck + 1 end
    end
    ok(stuck == 0, "проигранный клик закончился, IN_USE не залипает", stuck)
end

-----------------------------------------------------------------------
print("\n=== 5. БЕЗ ЦЕЛИ МОДУЛЬ НЕ ВМЕШИВАЕТСЯ ===")
-----------------------------------------------------------------------
do
    --[[ Смотрим в пустоту: E должен работать как обычно, иначе модуль
         сломал бы подбор предметов и посадку в транспорт везде, где
         нет дверей. ]]
    _G.__TRACE_HIT = nil
    NOW = NOW + 1
    fire("PlayerButtonDown", ply, KEY_E)
    KEYS_DOWN[KEY_E] = true

    local passed = 0
    for _ = 1, 4 do
        NOW = NOW + 0.02
        if tick(true):HasUse() then passed = passed + 1 end
    end
    ok(passed == 4, "без цели E проходит на сервер каждый тик", passed)

    KEYS_DOWN[KEY_E] = false
    fire("PlayerButtonUp", ply, KEY_E)
    ok(I.Radial.open == false, "и кольцо не открывается")
    _G.__TRACE_HIT = door
end

-----------------------------------------------------------------------
print("\n=== 6. ОТКЛЮЧЁННЫЙ МОДУЛЬ НЕ ТРОГАЕТ E ===")
-----------------------------------------------------------------------
do
    CVARS["grm_cl_interact"] = "0"
    NOW = NOW + 1
    fire("PlayerButtonDown", ply, KEY_E)
    KEYS_DOWN[KEY_E] = true

    local passed = 0
    for _ = 1, 4 do
        NOW = NOW + 0.02
        if tick(true):HasUse() then passed = passed + 1 end
    end
    ok(passed == 4, "с выключенным конваром E не перехватывается", passed)
    ok(I.Radial.open == false, "кольцо не появляется")

    KEYS_DOWN[KEY_E] = false
    fire("PlayerButtonUp", ply, KEY_E)
    CVARS["grm_cl_interact"] = "1"
end

-----------------------------------------------------------------------
print("\n=== 7. ИСХОДНИК ===")
-----------------------------------------------------------------------
do
    local fh = assert(io.open("lua/autorun/sh_grm_interact.lua", "rb"))
    local src = fh:read("*a") fh:close()

    local sc = src:match('hook%.Add%("StartCommand", "GRM_Interact_Freeze".-\nend%)')
    ok(sc ~= nil, "обработчик команды найден")

    --[[ Перехват обязан стоять на СОСТОЯНИИ УДЕРЖАНИЯ (armed), а не
         только на открытом кольце — в этом и была суть бага. ]]
    ok(sc and sc:find("if armed then", 1, true) ~= nil,
        "IN_USE снимается уже во время удержания, а не только при открытом кольце")
    ok(sc and sc:find("passUse", 1, true) ~= nil,
        "есть механизм возврата короткого клика")

    local up = src:match('hook%.Add%("PlayerButtonUp", "GRM_Interact_UseUp".-\nend%)')
    ok(up and up:find("passUse = 3", 1, true) ~= nil,
        "клик раньше порога помечается для проигрывания")
    ok(up and up:find("< I.HoldTime", 1, true) ~= nil,
        "порог отличает клик от удержания")
end

-----------------------------------------------------------------------
print(string.format("\nИТОГО: %d ok, %d FAIL", pass, fail))
os.exit(fail == 0 and 0 or 1)
