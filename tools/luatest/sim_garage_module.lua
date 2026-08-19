--[[--------------------------------------------------------------------
    sim_garage_module — заказ владельца 19.08: полноценный модуль гаражей и
    его стыковка с дилером (инструмент зон, места спавна, стойка вызова,
    выдача из гаража, приписка купленного транспорта).

    Проверяет состав модуля и порядок загрузки; живая механика проверяется
    отдельно в sim_garage_runtime.lua.

    Запуск: ./.luabuild/lj/src/luajit tools/luatest/sim_garage_module.lua
----------------------------------------------------------------------]]
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end
local function maybe(p) local f = io.open(p, "rb") if not f then return "" end local s = f:read("*a") f:close() return s end

local fails, total = 0, 0
local function ok(cond, name, extra)
    total = total + 1
    if cond then print("  ok   " .. name)
    else fails = fails + 1 print("  FAIL " .. name .. "  " .. tostring(extra or "")) end
end
local function has(s, n) return s:find(n, 1, true) ~= nil end

local core = read("lua/autorun/sh_grm_garage.lua")
local ui   = read("lua/autorun/client/cl_grm_garage_ui.lua")
local tool = read("lua/weapons/gmod_tool/stools/grm_garage.lua")
local entS = read("lua/entities/grm_garage_terminal/shared.lua")
local entI = read("lua/entities/grm_garage_terminal/init.lua")
local entC = read("lua/entities/grm_garage_terminal/cl_init.lua")
local vd   = read("lua/autorun/sh_grm_vehicle_dealer.lua")
local vdcl = read("lua/entities/sent_vehicle_dealer/cl_init.lua")
local qm   = read("lua/autorun/sh_grm_qmenu.lua")
local hubS = read("lua/autorun/server/sv_grm_persistence_hub.lua")
local hubC = read("lua/autorun/client/cl_grm_persistence_hub.lua")
local f4   = maybe("lua/autorun/sh_grm_f4menu.lua")

print("\n=== 1. СОСТАВ МОДУЛЯ ===")
ok(has(core, 'G.Version = "1.0.0"'), "ядро гаражей есть и версионировано")
ok(has(core, "G.Kinds = {") and has(core, "public") and has(core, "faction") and has(core, "private"),
    "три типа гаража: городской, ведомственный, личный")
ok(has(tool, "TOOL.Category = \"GRM\""), "тул разметки существует")
ok(has(entS, "grm_garage_terminal") or has(entS, "Стойка гаража GRM"), "энтити стойки существует")
ok(has(ui, "function G.OpenWindow"), "клиентское окно гаража существует")

print("\n=== 2. ЗОНЫ И МЕСТА ===")
ok(has(core, "function G.Create"), "создание зоны гаража")
ok(has(core, "G.MinZone"), "минимальный размер зоны задан")
ok(has(core, "function G.AddSlot") and has(core, "function G.RemoveNearestSlot"), "места стоянки добавляются и удаляются")
ok(has(core, "if not G.PosInZone(rec, pos) then return false, \"Место должно быть внутри зоны гаража\""),
    "место обязано быть внутри зоны")
ok(has(core, "function G.FreeSlot"), "поиск свободного места с проверкой габаритов")
ok(has(core, "function G.SlotState"), "занятость мест считается для интерфейса")
ok(has(tool, 'mode:AddChoice("Зона гаража (2 клика)", "zone")') and has(tool, '"Место стоянки", "slot"')
    and has(tool, '"Стойка вызова меню", "terminal"'), "у тула три режима: зона, место, стойка")
ok(has(tool, 'dir:AddChoice("По взгляду при установке", "look")'), "направление выдачи выбирается")

print("\n=== 3. СТОЙКА И ВЫЗОВ МЕНЮ ===")
ok(has(core, "function G.AddTerminal") and has(core, "function G.SpawnTerminals"), "стойки хранятся в записи гаража и поднимаются сами")
ok(has(entI, "G.Push(ply, rec)"), "E на стойке открывает меню гаража")
ok(has(entI, "function ENT:PhysgunPickup() return false end"), "стойку нельзя утащить физганом")
ok(has(core, 'hook.Add("PlayerSay", "GRM_Garage_Chat"') and has(core, 'hook.Add("PlayerSayTransform", "GRM_Garage_ChatEC"'),
    "/garage зарегистрирован и в PlayerSay, и в EasyChat")
ok(has(core, "if not G.GarageAt(ply) then return false end"),
    "вне гаража команда отдаётся дилеру — конфликта /garage нет")
ok(has(core, "function G.GarageAt"), "гараж определяется по зоне или по стойке рядом")

print("\n=== 4. ВЫДАЧА, УБОРКА, ДОСТУП ===")
ok(has(core, "function G.Retrieve") and has(core, "function G.Store") and has(core, "function G.SetHome"),
    "выдача, уборка и приписка транспорта")
ok(has(core, "function G.CanUse"), "правила доступа к гаражу")
ok(has(core, "if fee > 0 and GRM.TakeMoney"), "плата за выезд списывается")
ok(has(core, 'if home ~= "" and home ~= garage.id then'), "чужой гараж не выдаёт машину")
ok(has(ui, 'G.SendAction(v.onMap and "store" or "retrieve", v.id)'), "кнопка меняет смысл: выдать / убрать")
ok(has(ui, "МЕСТА СТОЯНКИ"), "в окне видно состояние мест")

print("\n=== 5. СТЫКОВКА С ДИЛЕРОМ ===")
ok(has(vd, "function VD.IssueRecord") and has(vd, "function VD.StoreRecord"),
    "выдача/уборка живут в одном слое дилера — гараж их переиспользует")
ok(has(vd, "function VD.Spawn(class,dealer,ply,place)"), "спавн умеет работать по готовому месту гаража")
ok(has(vd, 'elseif op=="store"then local id=net.ReadString();local ok,msg=VD.StoreRecord'),
    "операции дилера переведены на общий слой (без копипасты)")
ok(has(core, 'hook.Add("GRM_VehicleDealerSpawned", "GRM_Garage_AssignHome"'),
    "покупка приписывается к гаражу хуком — дилер про гаражи не знает")
ok(has(core, "function G.HomeGarageFor"), "выбор домашнего гаража: привязанный дилер → личный → ближайший")
ok(has(core, "function G.LinkDealer") and has(tool, "g.LinkDealer(rec.id"), "дилер привязывается к гаражу тулом")
ok(has(core, 'CreateConVar("grm_garage_strict"'), "строгий режим выдачи только в гараже — конваром")
ok(has(vd, "GRM.Garage.DealerIssueBlocked"), "дилер спрашивает гараж, можно ли выдавать здесь")
ok(has(vdcl, 'Гараж: '), "в меню дилера видно, к какому гаражу приписана машина")

print("\n=== 6. ПОРЯДОК ЗАГРУЗКИ И ХРАНЕНИЕ ===")
ok(has(core, 'GRM.Boot.OnMapStart("GRM_Garage_Load", "normal"'), "данные грузятся через планировщик (tier normal)")
ok(has(core, 'GRM.Boot.OnMapStart("GRM_Garage_Terminals", "late"'), "стойки поднимаются отдельной задачей (tier late)")
ok(has(core, 'hook.Add("PostCleanupMap", "GRM_Garage_Cleanup"'), "после очистки карты стойки возвращаются")
ok(has(core, "grm_garage/") and has(core, "string.lower(game.GetMap()"), "файл гаражей — по карте")
ok(has(core, 'print("[GRM Garage] SAVE read-back ПУСТ'), "запись проверяется чтением обратно (стандарт GRM)")
ok(has(core, "GRM.Net.Guard(ply, \"garage.action\""), "приём действий под сетевым guard")
ok(has(core, "GRM.Net.Guard(ply, \"garage.admin\""), "админ-канал тоже под guard")
ok(has(hubS, "garages = { save = function()") and has(hubS, '"garages", "quests"'), "гаражи в хабе сохранений")
ok(has(hubC, '{ id = "garages", name = "Гаражи карты"'), "раздел гаражей виден в /grm_persistence")
ok(has(qm, '{ id = "grm_garage",'), "тул зарегистрирован в Q-меню")
ok(f4 == "" or has(f4, "Гараж (/garage"), "подсказка по гаражу есть в F4")

print(("\nGARAGE MODULE: %d/%d, провалов: %d"):format(total - fails, total, fails))
if fails > 0 then os.exit(1) end
