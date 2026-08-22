--[[ Живой прогон общего реестра модулей и единой точки права
     (заказ владельца 22.08: «все модули должны знать друг друга»).
     Грузятся РЕАЛЬНЫЕ lua/autorun/sh_03b_grm_modules.lua и sh_03_grm_access.lua.
     Запуск: ./.luabuild/lj/src/luajit tools/luatest/sim_modules.lua ]]
local pass, fail = 0, 0
local function ok(v, n, extra)
    if v then pass = pass + 1 print("  ok   " .. n)
    else fail = fail + 1 print("  FAIL " .. n .. "  " .. tostring(extra or "")) end
end

SERVER, CLIENT = true, false
function AddCSLuaFile() end
function IsValid(v) return type(v) == "table" and v._valid ~= false end
function istable(v) return type(v) == "table" end
function isstring(v) return type(v) == "string" end
function isnumber(v) return type(v) == "number" end
function isfunction(v) return type(v) == "function" end
function ErrorNoHalt() end
function string.Trim(s) return (string.gsub(tostring(s or ""), "^%s*(.-)%s*$", "%1")) end
HUD_PRINTCONSOLE = 2

local HOOKS = {}
hook = {
    Add = function(e, n, fn) HOOKS[e] = HOOKS[e] or {} HOOKS[e][n] = fn end,
    Run = function(e, ...) for _, fn in pairs(HOOKS[e] or {}) do fn(...) end end,
    Remove = function() end,
}
local CMDS = {}
concommand = { Add = function(n, fn) CMDS[n] = fn end }
player = { GetAll = function() return {} end }
local SPREADS = {}
GRM = {
    Perf = {
        Spread = function(id, list, fn) SPREADS[id] = true for _, v in ipairs(list) do fn(v) end return true end,
        Coalesce = function(_, fn) fn() end,
        Players = function() return {} end,
    },
}

assert(loadfile("lua/autorun/sh_03b_grm_modules.lua"))()
local M = GRM.Modules

print("\n=== 1. МОДУЛИ ПРЕДСТАВЛЯЮТСЯ ДРУГ ДРУГУ ===")
ok(isfunction(M.Register) and isfunction(M.Get) and isfunction(M.Has), "реестр объявлен")
local refreshed = {}
M.Register("access", { label = "Доступ", version = "1.1.0" })
M.Register("plates", {
    label = "Номерные знаки", version = "1.2.0", Depends = { "access" },
    Refresh = function(ply, reason) refreshed[#refreshed + 1] = "plates:" .. tostring(reason) end,
    Status = function() return "номеров: 7" end,
})
M.Register("fleet", {
    label = "Автопарк", version = "1.0.0", Depends = { "access", "vehicles" },
    Refresh = function() refreshed[#refreshed + 1] = "fleet" end,
})
ok(M.Has("plates") and M.Get("plates").label == "Номерные знаки", "модуль виден другим по имени")
ok(M.Has("нетакого") == false, "чужого модуля в реестре нет")

print("\n=== 2. ЗАВИСИМОСТИ ВИДНЫ ===")
ok(#M.MissingDeps("plates") == 0, "у знаков зависимость «access» на месте")
local miss = M.MissingDeps("fleet")
ok(#miss == 1 and miss[1] == "vehicles", "автопарк честно сообщает о недостающем слое", table.concat(miss, ","))
M.Register("vehicles", { label = "Транспорт", version = "1.0.0" })
ok(#M.MissingDeps("fleet") == 0, "слой появился — претензий нет")

print("\n=== 3. ОДНО СОБЫТИЕ ОБНОВЛЯЕТ ВСЕХ ===")
refreshed = {}
hook.Run("GRM_AccessChanged", "faction_perms")
ok(#refreshed == 2, "по смене прав обновились оба модуля со снимками", #refreshed)
ok(SPREADS["modules.refresh"] == true, "обход реестра идёт порционно через GRM.Perf.Spread")
refreshed = {}
hook.Run("GRM_FactionRoleChanged")
ok(#refreshed == 2, "смена должности тоже поднимает шину")
refreshed = {}
M.Changed("manual")
ok(#refreshed == 2, "любой модуль может поднять шину сам")

print("\n=== 4. ОТЧЁТ И КОМАНДЫ ===")
local rows = M.Report()
ok(#rows == 4, "в отчёте все зарегистрированные модули", #rows)
local platesRow
for _, r in ipairs(rows) do if r.id == "plates" then platesRow = r end end
ok(platesRow and platesRow.status == "номеров: 7", "статус модуля попадает в отчёт", platesRow and platesRow.status)
ok(platesRow and platesRow.refresh == true, "видно, кто умеет обновляться")
ok(isfunction(CMDS["grm_modules"]) and isfunction(CMDS["grm_modules_refresh"]),
   "команды реестра объявлены")

print("\n=== 5. ЕДИНАЯ ТОЧКА ПРАВА ===")
local ACC = (function()
    local f = io.open("lua/autorun/sh_03_grm_access.lua", "rb")
    local t = f:read("*a") f:close() return t
end)()
local function has(n) return ACC:find(n, 1, true) ~= nil end
ok(has("function A.FactionPermName(capability)"),
   "capability знает своё имя в доступах организации (точки → подчёркивания)")
ok(has('A.RegisterProvider("grm_faction_perms", 40'),
   "право организации спрашивается автоматически")
ok(has('A.RegisterProvider("grm_pcboard_level", 30'),
   "уровень госбазы спрашивается автоматически")
ok(has("function A.Why(ply, capability)") and has('concommand.Add("grm_access_check"'),
   "есть команда «почему нет права»")

local plates = (function()
    local f = io.open("lua/autorun/sh_grm_plates.lua", "rb")
    local t = f:read("*a") f:close() return t
end)()
ok(plates:find('factionPerm = "plates_issue"', 1, true) ~= nil
   and plates:find("levels = { police = true, military = true, admin = true }", 1, true) ~= nil,
   "знаки объявили источники права прямо в capability")
ok(plates:find('GRM.Modules.Register("plates"', 1, true) ~= nil, "знаки представились реестру")

for _, file in ipairs({
    { "lua/autorun/sh_grm_fleet.lua", 'GRM.Modules.Register("fleet"' },
    { "lua/autorun/sh_grm_garage.lua", 'GRM.Modules.Register("garage"' },
    { "lua/autorun/sh_grm_vehicles.lua", 'GRM.Modules.Register("vehicles"' },
    { "lua/autorun/server/sv_grm_alarm.lua", 'GRM.Modules.Register("alarm"' },
    { "lua/autorun/sh_grm_doors.lua", 'GRM.Modules.Register("doors"' },
}) do
    local src = (function()
        local f = io.open(file[1], "rb")
        local t = f:read("*a") f:close() return t
    end)()
    ok(src:find(file[2], 1, true) ~= nil, "в реестре: " .. file[1]:match("([^/]+)$"))
end

print(("\nMODULES: %d/%d, провалов: %d"):format(pass, pass + fail, fail))
if fail > 0 then os.exit(1) end
