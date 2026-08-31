--[[--------------------------------------------------------------------
    sim_interact_use_grab — короткий E не должен открывать дверь, когда
    игрок вызывает кольцо действий.

    ЖАЛОБА ВЛАДЕЛЬЦА (31.08): «И меню вылазит интерактивное и двери
    сразу открываются». После первой попытки починки — «Всё ещё не
    исправлено».

    ПОЧЕМУ ПЕРВАЯ ПОПЫТКА НЕ СРАБОТАЛА, И ПОЧЕМУ СТЕНД ЭТОГО НЕ ПОЙМАЛ.

    Модуль ловил нажатие в PlayerButtonDown и оттуда поднимал флаг, а
    IN_USE снимал уже в StartCommand. Но PlayerButtonDown вызывается
    ПОСЛЕ того, как команда для сервера сформирована и отправлена: к
    моменту, когда флаг поднят, первый тик с зажатым «использовать» уже
    ушёл. Серверу одного тика достаточно, чтобы открыть дверь.

    А прошлая версия ЭТОГО СТЕНДА вызывала PlayerButtonDown ПЕРЕД
    тиком — то есть моделировала порядок, которого в движке не бывает.
    Стенд был зелёным при живом баге. Классическая ловушка: проверка
    описывала не игру, а то, как я себе её представлял.

    ЗДЕСЬ ПОРЯДОК ЧЕСТНЫЙ: сначала StartCommand (команда уходит на
    сервер), и только потом PlayerButtonDown/Up. Именно так работает
    движок, и именно поэтому логика E должна жить в StartCommand.

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

bit = {
    bor = function(a, b)
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
--[[ Панель-заглушка с любыми методами: кольцу нужен живой объект VGUI,
     невалидная пустышка роняет модуль на первом же SetSize. ]]
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

local door = { _valid = true, _locked = true, _nw = {}, _nwb = {} }
function door:GetNWString(k, d) return self._nw[k] or d or "" end
function door:GetNWBool(k, d) if self._nwb[k] == nil then return d or false end return self._nwb[k] end
function door:GetParent() return { _valid = false } end
_G.__TRACE_HIT = door

-----------------------------------------------------------------------
-- Поддельная команда движка.
-----------------------------------------------------------------------
local function mkCmd(buttons)
    local c = { _b = buttons or 0, _cleared = false, _mx = nil }
    function c:GetButtons() return self._b end
    function c:SetButtons(v) self._b = v end
    function c:KeyDown(k) return self._b % (k * 2) >= k end
    function c:RemoveKey(k) if self:KeyDown(k) then self._b = self._b - k end end
    function c:ClearMovement() self._cleared = true end
    function c:SetViewAngles() end
    function c:SetMouseX(v) self._mx = v end
    function c:SetMouseY() end
    function c:HasUse() return self:KeyDown(IN_USE) end
    return c
end

--[[ ОДИН ИГРОВОЙ ТИК В ПРАВИЛЬНОМ ПОРЯДКЕ.

     Движок сначала строит команду и отдаёт её в StartCommand (после
     чего она уходит на сервер), и только ЗАТЕМ, обнаружив изменение
     состояния кнопок, зовёт PlayerButtonDown / PlayerButtonUp.

     Прошлая версия стенда делала наоборот — и потому не видела бага. ]]
local prevDown = false
local function tick(holdingE)
    KEYS_DOWN[KEY_E] = holdingE and true or false

    fire("Think")
    local cmd = mkCmd(holdingE and IN_USE or 0)
    fire("StartCommand", ply, cmd)      -- команда уходит на сервер ЗДЕСЬ

    -- И только теперь движок сообщает о смене состояния клавиши.
    if holdingE and not prevDown then fire("PlayerButtonDown", ply, KEY_E) end
    if not holdingE and prevDown then fire("PlayerButtonUp", ply, KEY_E) end
    prevDown = holdingE and true or false

    return cmd
end

local function reset()
    -- Отпускаем клавишу и даём модулю прийти в исходное состояние.
    for _ = 1, 6 do NOW = NOW + 0.02 tick(false) end
    if I.Radial and I.Radial.open then I.CloseRadial() end
end

-----------------------------------------------------------------------
print("\n=== 1. ВОСПРОИЗВЕДЕНИЕ БАГА: ПЕРВЫЙ ЖЕ ТИК ===")
-----------------------------------------------------------------------
do
    reset()
    --[[ Самый первый тик с зажатым E. Именно он раньше уходил на
         сервер и открывал дверь: PlayerButtonDown к этому моменту ещё
         не вызывался, флага не было, и снимать было нечего. ]]
    NOW = NOW + 0.02
    local first = tick(true)
    ok(not first:HasUse(),
        "ИСПРАВЛЕНО: ПЕРВЫЙ тик нажатия не уходит на сервер — дверь не открывается")
end

do
    -- И последующие тики удержания тоже.
    local leaked = 0
    for _ = 1, 5 do
        NOW = NOW + 0.02
        if tick(true):HasUse() then leaked = leaked + 1 end
    end
    ok(leaked == 0, "за всё удержание IN_USE ни разу не прошёл", leaked)
end

-----------------------------------------------------------------------
print("\n=== 2. УДЕРЖАНИЕ ОТКРЫВАЕТ КОЛЬЦО ===")
-----------------------------------------------------------------------
do
    NOW = NOW + I.HoldTime
    tick(true)
    ok(I.Radial.open == true, "после порога кольцо открылось")

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
    I.CloseRadial()
    reset()

    NOW = NOW + 0.02
    ok(not tick(true):HasUse(), "нажатие придержано")
    NOW = NOW + 0.03
    tick(true)

    -- Отпустили заметно раньше порога — это клик.
    NOW = NOW + 0.02
    tick(false)

    ok(I.Radial.open == false, "кольцо от короткого клика не открылось")

    --[[ Самое важное: «съеденный» клик обязан вернуться игре, иначе
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
    reset()
    _G.__TRACE_HIT = nil

    local passed = 0
    for _ = 1, 4 do
        NOW = NOW + 0.02
        if tick(true):HasUse() then passed = passed + 1 end
    end
    ok(passed == 4, "без цели E проходит на сервер каждый тик", passed)
    ok(I.Radial.open == false, "и кольцо не открывается")

    _G.__TRACE_HIT = door
    reset()
end

-----------------------------------------------------------------------
print("\n=== 6. ОТКЛЮЧЁННЫЙ МОДУЛЬ НЕ ТРОГАЕТ E ===")
-----------------------------------------------------------------------
do
    CVARS["grm_cl_interact"] = "0"
    reset()

    local passed = 0
    for _ = 1, 4 do
        NOW = NOW + 0.02
        if tick(true):HasUse() then passed = passed + 1 end
    end
    ok(passed == 4, "с выключенным конваром E не перехватывается", passed)
    ok(I.Radial.open == false, "кольцо не появляется")

    CVARS["grm_cl_interact"] = "1"
    reset()
end

-----------------------------------------------------------------------
print("\n=== 7. В ТРАНСПОРТЕ И МЁРТВЫМ НЕ ПЕРЕХВАТЫВАЕМ ===")
-----------------------------------------------------------------------
do
    reset()
    ply.InVehicle = function() return true end
    local passed = 0
    for _ = 1, 3 do
        NOW = NOW + 0.02
        if tick(true):HasUse() then passed = passed + 1 end
    end
    ok(passed == 3, "сидя в машине E не перехватывается", passed)
    ply.InVehicle = function() return false end
    reset()

    ply.Alive = function() return false end
    local passed2 = 0
    for _ = 1, 3 do
        NOW = NOW + 0.02
        if tick(true):HasUse() then passed2 = passed2 + 1 end
    end
    ok(passed2 == 3, "мёртвым тоже", passed2)
    ply.Alive = function() return true end
    reset()
end

-----------------------------------------------------------------------
print("\n=== 8. ИСХОДНИК: ЛОГИКА ЖИВЁТ В StartCommand ===")
-----------------------------------------------------------------------
do
    local fh = assert(io.open("lua/autorun/sh_grm_interact.lua", "rb"))
    local src = fh:read("*a") fh:close()

    --[[ Ключевое требование: решение о перехвате принимается ТАМ ЖЕ,
         где формируется команда. PlayerButtonDown для этого не годится —
         он опаздывает на кадр относительно потока команд. ]]
    local sc = src:match('hook%.Add%("StartCommand", "GRM_Interact_Use".-\nend%)')
    ok(sc ~= nil, "обработчик команды найден")
    ok(sc and sc:find("I.FindTarget", 1, true) ~= nil,
        "цель ищется прямо в StartCommand, в тот же тик")
    ok(sc and sc:find("cmd:RemoveKey(IN_USE)", 1, true) ~= nil,
        "и там же снимается IN_USE")
    ok(sc and sc:find("passUse", 1, true) ~= nil,
        "есть механизм возврата короткого клика")

    --[[ Старая (неверная) схема: нажатие ловилось в PlayerButtonDown.
         Если она вернётся, баг вернётся вместе с ней. ]]
    ok(src:find('hook.Add("PlayerButtonDown", "GRM_Interact_Use"', 1, true) == nil,
        "нажатие больше НЕ ловится через PlayerButtonDown")

    -- Отпускание при открытом кольце — там хук уместен, гонки уже нет.
    local up = src:match('hook%.Add%("PlayerButtonUp", "GRM_Interact_UseUp".-\nend%)')
    ok(up and up:find("I.Apply()", 1, true) ~= nil,
        "отпускание применяет выбор при открытом кольце")
end

-----------------------------------------------------------------------
print(string.format("\nИТОГО: %d ok, %d FAIL", pass, fail))
os.exit(fail == 0 and 0 or 1)
