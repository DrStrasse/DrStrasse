--[[--------------------------------------------------------------------
    sim_fire — контракт Кода 58
    ./.luabuild/lj/src/luajit tools/luatest/sim_fire.lua
----------------------------------------------------------------------]]
local function read(p)
    local f = assert(io.open(p, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

local fails = 0
local function check(name, cond, extra)
    if cond then print("  OK   " .. name)
    else fails = fails + 1 print("  FAIL " .. name .. "   " .. tostring(extra or "")) end
end
local function has(src, n) return src:find(n, 1, true) ~= nil end

local core = read("lua/autorun/sh_grm_fire.lua")
local acc = read("lua/autorun/sh_grm_fire_access.lua")
local hose = read("addons/grm_fire/lua/weapons/weapon_grm_hose.lua")
local ext = read("addons/grm_fire/lua/weapons/weapon_extinguisher.lua")
local packHose = read("addons/grm_fire/lua/weapons/weapon_firehose.lua")

print("\n=== МОДЕЛИ _grm ===")
check("ствол GRM c_firehose_grm", has(hose, "c_firehose_grm.mdl"))
check("ствол GRM w_firehose_grm", has(hose, "w_firehose_grm.mdl"))
check("нет старого c_firehose.mdl в GRM SWEP", not hose:find("c_firehose.mdl", 1, true))
check("огнетушитель c_fire_extinguisher_grm", has(ext, "c_fire_extinguisher_grm.mdl"))
check("огнетушитель w_fire_extinguisher_grm", has(ext, "w_fire_extinguisher_grm.mdl"))
check("огнетушитель без оборванного if SERVER", not ext:find("if ( SERVER ) then --", 1, true))
check("огнетушитель без AddWorkshop", not has(ext, "AddWorkshop"))
check("пак-шланг c_firehose_grm", has(packHose, "c_firehose_grm.mdl"))
check("пак-шланг w_firehose_grm", has(packHose, "w_firehose_grm.mdl"))

print("\n=== СЕРВЕР Код 58 ===")
check("версия 1.3.1", has(core, 'F.Version = "1.3.1"'))
check("jsonT false,true", has(core, "util.JSONToTable, txt, false, true"))
check("карантин", has(core, ".corrupt."))
check("read-back", has(core, "SAVE read-back fail") or has(core, "chk ~= txt"))
check("массив incidents", has(core, "incidents"))
check("CreateVFire", has(core, "CreateVFire"))
check("рандом точек", has(core, "grm_fire_spot"))
check("плита", has(core, "grm_food_stove"))
check("CanFightPro", has(core, "function F.CanFightPro"))
check("хук CanHose", has(core, "GRM_FireAddon_CanHose"))
check("перм RegisterClass", has(core, "RegisterClass"))
check("нет принтера", not has(core, "grm_money_printer"))
check("нет пресса", not has(core, "grm_money_press"))

print("\n=== ACCESS ===")
check("jsonT access", has(acc, "util.JSONToTable, txt, false, true"))
check("/fire_access", has(acc, "/fire_access"))
check("/grm_fire_notify", has(acc, "/grm_fire_notify"))
check("OpenAdminMenu обёртка", has(acc, "OpenAdminMenu = function"))
check("глобал не локализован как local OpenAdminMenu", not acc:find("local OpenAdminMenu", 1, true))
check("вкладка Пожарные", has(acc, "Пожарные"))
check("notify массив", has(acc, "factions = arr"))

local truck = read("lua/autorun/sh_grm_fire_truck.lua")
print("\n=== МАШИНА ===")
check("CommissionTruck", has(truck, "function F.CommissionTruck"))
check("DecommissionTruck", has(truck, "function F.DecommissionTruck"))
check("CanUseFireTruck", has(truck, "function F.CanUseFireTruck"))
check("IsListedFireTruck", has(truck, "function F.IsListedFireTruck"))
check("AttachPump", has(truck, "function F.AttachPump"))
check("/firetruck", has(truck, "/firetruck"))
check("/fire_trucks", has(truck, "/fire_trucks"))
check("PlayerSayTransform", has(truck, "PlayerSayTransform"))
check("trucks.json массив", has(truck, "trucks.json"))
check("jsonT trucks", has(truck, "util.JSONToTable, txt, false, true"))
check("карантин trucks", has(truck, ".corrupt."))
check("кнопка машин во вкладке", has(acc, "Пожарные машины"))

local addon = read("addons/grm_fire/lua/autorun/sh_grm_fire_addon.lua")
local hoseLua = read("addons/grm_fire/lua/autorun/sh_grm_fire_hose.lua")
local node = read("addons/grm_fire/lua/entities/grm_fire_hose_node/init.lua")
local pump = read("addons/grm_fire/lua/entities/grm_fire_pump/init.lua")
local tool = read("addons/grm_fire/lua/weapons/gmod_tool/stools/grm_fire_place.lua")
local qmenu = read("lua/autorun/sh_grm_qmenu.lua")
print("\n=== АДДОН 0.3 ===")
check("длина 2200", has(hoseLua, "MaxLength   = 2200") or has(hoseLua, "MaxLength = 2200"))
check("RewindAtSource", has(hoseLua, "function A.RewindAtSource"))
check("узлы без hunter cube", not has(node, "cube025x025x025"))
check("насос tpplugholder", has(pump, "tpplugholder_single"))
check("насос без SOLID_VPHYSICS", not has(pump, "SOLID_VPHYSICS"))
check("тул категория GRM", has(tool, 'TOOL.Category = "GRM"'))
check("тул не GRM Fire", not has(tool, 'TOOL.Category = "GRM Fire"'))
check("лестница в туле", has(tool, "grm_fire_ladder"))
check("лестница в каталоге Q", has(qmenu, "grm_fire_place"))
check("файл лестницы", (function()
    local f = io.open("addons/grm_fire/lua/entities/grm_fire_ladder/init.lua", "rb")
    if f then f:close() return true end
    return false
end)())

local pui = read("lua/autorun/sh_grm_fire_pump_ui.lua")
local ladW = read("addons/grm_fire/lua/weapons/weapon_grm_ladder.lua")
print("\n=== НАСОС G / ЛЕСТНИЦА ===")
check("панель OpenPumpPanel", has(pui, "function F.OpenPumpPanel"))
check("G KEY_G", has(pui, "KEY_G"))
check("баки foam powder", has(pui, "foam") and has(pui, "powder"))
check("закачка fill", has(pui, '"fill"'))
check("кнопка взять ствол", has(pui, '"take"'))
check("кнопка ВЗЯТЬ РУКАВ в меню", has(pui, "ВЗЯТЬ РУКАВ"))
check("кнопка Связать с гидрантом", has(pui, "Связать машину с гидрантом"))
check("act link", has(pui, 'act == "link"'))
check("LaySupplyLine", has(hoseLua, "function A.LaySupplyLine"))
check("клиент рисует кабели", has(hoseLua, "GRM_FireHose_Beams"))
check("узлы без альфы 0", not node:find("Color(255, 255, 255, 0)", 1, true))
check("инкассация G не по гидранту", (function()
    local inc = read("lua/autorun/sh_grm_incassation.lua")
    local a = inc:find("function getMyIncassCarClient", 1, true) or 0
    local b = inc:find("GRM_Incass_GKey", 1, true) or 0
    return a > 0 and b > 0 and a < b and inc:find("grm_fire_", 1, true) ~= nil
end)())
check("укладка без SetNoDraw", not node:find("SetNoDraw(true)", 1, true))
check("лестница aluminium", has(ladW, "ladderaluminium.mdl"))
check("лестница ПКМ на машину", has(ladW, "AttachToVehicle"))
check("насос Consume agent", has(pump, "function ENT:Consume"))
check("нет автозаливки +25", not has(pump, "self:Fill(25)"))

print("")
if fails == 0 then print("ВСЕ ТЕСТЫ ПРОЙДЕНЫ (fire)")
else print("ПРОВАЛОВ: " .. fails) end
print(("FIRE failures=%d"):format(fails))
os.exit(fails == 0 and 0 or 1)
