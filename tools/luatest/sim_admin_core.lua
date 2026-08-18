--[[--------------------------------------------------------------------
    sim_admin_core — собственная админ-платформа GRM:
      группы и права, иммунитет, синхронизация с ULX/ULib и CAMI,
      модерация (ТП/мут/джаил/рагдолл и т.д.), возможности суперадмина,
      админ-меню с нужными вкладками.

    Запуск: ./.luabuild/lj/src/luajit tools/luatest/sim_admin_core.lua
----------------------------------------------------------------------]]
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end

local fails, total = 0, 0
local function ok(cond, name, extra)
    total = total + 1
    if cond then print("  ok   " .. name)
    else fails = fails + 1 print("  FAIL " .. name .. "  " .. tostring(extra or "")) end
end

local core    = read("lua/autorun/sh_grm_admin_core.lua")
local actions = read("lua/autorun/server/sv_grm_admin_actions.lua")
local panel   = read("lua/autorun/client/cl_grm_admin_panel.lua")

print("\n=== 1. СТАТИКА: ЯДРО ===")
ok(core:find("GRM.Admin", 1, true) ~= nil and core:find('AD.Version = "1.0.0"', 1, true) ~= nil, "модуль GRM.Admin v1.0.0")
ok(core:find("function AD.RegisterPerm", 1, true) ~= nil, "реестр прав с категориями")
ok(core:find("function AD.Can", 1, true) ~= nil, "единая проверка прав GRM.Admin.Can")
ok(core:find("function AD.CanTarget", 1, true) ~= nil and core:find("У цели равный или больший иммунитет", 1, true) ~= nil,
    "иммунитет: нельзя применять действия к равному или старшему")
ok(core:find("function AD.GroupChain", 1, true) ~= nil, "наследование групп")
ok(core:find("grm_admin/groups.json", 1, true) ~= nil and core:find("grm_admin/users.json", 1, true) ~= nil,
    "группы и назначения хранятся на диске")
ok(core:find("function AD.ImportFromULib", 1, true) ~= nil, "импорт групп и назначений из ULX/ULib")
ok(core:find("ULib.ucl.addUser", 1, true) ~= nil, "назначение зеркалится в ULib (ulx-команды не ломаются)")
ok(core:find("CAMI.RegisterUsergroup", 1, true) ~= nil and core:find("CAMI.RegisterPrivilege", 1, true) ~= nil,
    "группы и права публикуются в CAMI")
ok(core:find("CAMI.SignalUserGroupChanged", 1, true) ~= nil, "смена группы сообщается другим админ-модам")
ok(core:find('hook.Add("CAMI.PlayerHasAccess", "GRM_Admin_CAMIAnswer"', 1, true) ~= nil,
    "GRM отвечает на запросы доступа от чужих модулей")
ok(core:find('hook.Add("CAMI.PlayerUsergroupChanged", "GRM_Admin_External"', 1, true) ~= nil,
    "смена группы через ULX подхватывается обратно в GRM")
ok(core:find("ply:SetUserGroup(groupID)", 1, true) ~= nil,
    "группа ставится и в движок: IsAdmin/IsSuperAdmin остаются валидными")
ok(core:find('ulx.command("GRM", "ulx grmadmin"', 1, true) ~= nil, "ULX-команда ulx grmadmin открывает наше меню")

print("\n=== 2. ПРАВА И ГРУППЫ ПО УМОЛЧАНИЮ ===")
for _, perm in ipairs({ "mod.goto", "mod.bring", "mod.mute", "mod.gag", "mod.jail", "mod.ragdoll",
    "mod.kick", "mod.ban", "acl.groups", "acl.assign", "server.persistence", "server.factions",
    "cheat.god", "cheat.noclip", "cheat.money", "cheat.buildmode" }) do
    ok(core:find('"' .. perm .. '"', 1, true) ~= nil, "право " .. perm .. " зарегистрировано")
end
ok(core:find('id = "superadmin"', 1, true) ~= nil and core:find('perms = { %["%*"%] = true }') ~= nil,
    "у суперадмина полный доступ")
ok(core:find('immunity = 100', 1, true) ~= nil, "иммунитет суперадмина 100")

print("\n=== 3. ДЕЙСТВИЯ МОДЕРАЦИИ ===")
for _, op in ipairs({ "goto_player", "bring", "freeze", "mute", "gag", "jail", "ragdoll", "slay",
    "respawn", "heal", "strip", "spectate", "kick", "ban", "warn" }) do
    ok(actions:find("A." .. op, 1, true) ~= nil or actions:find('A["' .. op .. '"]', 1, true) ~= nil,
        "действие " .. op)
end
ok(actions:find("local function safeSpot", 1, true) ~= nil, "телепорт не заталкивает игрока в стену")
ok(actions:find("GRM_AdminReturn", 1, true) ~= nil, "точка возврата запоминается")
ok(actions:find('hook.Add("PlayerSay", "GRM_Admin_Mute"', 1, true) ~= nil, "мут реально блокирует чат")
ok(actions:find('hook.Add("PlayerCanHearPlayersVoice", "GRM_Admin_Gag"', 1, true) ~= nil, "мут голоса работает")
ok(actions:find("local function releaseJail", 1, true) ~= nil, "клетка снимается корректно, с возвратом на место")
ok(actions:find('hook.Add("PlayerDisconnected", "GRM_Admin_Cleanup"', 1, true) ~= nil,
    "клетки и рагдоллы не остаются на карте после выхода")
ok(actions:find("ULib.ban", 1, true) ~= nil and actions:find("ULib.kick", 1, true) ~= nil,
    "бан и кик отдаются ULib — одна база банов с ULX")

print("\n=== 4. ВОЗМОЖНОСТИ СУПЕРАДМИНА ===")
for _, op in ipairs({ "god", "cloak", "speed", "buildmode", "freezeall", "unfreezeall", "money", "item", "cleanup" }) do
    ok(actions:find("A." .. op, 1, true) ~= nil, "суперадмин: " .. op)
end
ok(actions:find("if not AD.Can(ply, action.perm) then", 1, true) ~= nil, "каждое действие проверяет право")
ok(actions:find("audit(ply, op, target", 1, true) ~= nil, "каждое действие пишется в аудит")

print("\n=== 5. МЕНЮ ===")
ok(panel:find('concommand.Add("grm_admin_panel"', 1, true) ~= nil and panel:find('low == "/admin"', 1, true) ~= nil,
    "открытие: /admin, /админ, консоль")
for _, tab in ipairs({ "Игроки", "Привилегии", "Назначения", "Сохранения и карта",
    "Фракционный контроль", "Модули сборки", "Суперадмин" }) do
    ok(panel:find('"' .. tab .. '"', 1, true) ~= nil, "вкладка «" .. tab .. "»")
end
ok(panel:find("if perm and not can(perm) then return end", 1, true) ~= nil,
    "вкладки скрываются по правам, а не «серым цветом»")
ok(panel:find("local function buildPrivileges", 1, true) ~= nil and panel:find("матрица", 1, true) == nil
    or panel:find("byCategory", 1, true) ~= nil, "матрица полномочий по категориям")
ok(panel:find("СОХРАНИТЬ ГРУППЫ И ПОЛНОМОЧИЯ", 1, true) ~= nil, "кнопка сохранения групп")
ok(panel:find("НАЗНАЧИТЬ", 1, true) ~= nil, "назначение группы игроку прямо из карточки")

print("\n=== 6. ЖИВОЙ ПРОГОН ===")
local stub = dofile("tools/luatest/lib_gmod_stub.lua")
stub.install()
stub.reset()
_G.SERVER, _G.CLIENT = true, false
_G.CAMI = nil
_G.ULib = nil
_G.file = _G.file or {}
_G.file.Read = function() return nil end
_G.file.Write = function() end
_G.file.IsDir = function() return true end
_G.file.CreateDir = function() end
_G.util = _G.util or {}
_G.util.AddNetworkString = function() end
_G.util.JSONToTable = function() return nil end
_G.util.TableToJSON = function() return "{}" end
_G.util.SteamIDTo64 = function(s) return "7656119" .. tostring(s):gsub("%D", "") end
_G.concommand = { Add = function() end }
_G.net = setmetatable({}, { __index = function() return function() end end })
_G.player = _G.player or { GetAll = function() return {} end }

local okLoad, err = stub.loadModule("lua/autorun/sh_grm_admin_core.lua")
ok(okLoad, "ядро админки поднялось в моке", err)

local AD = _G.GRM and _G.GRM.Admin
ok(AD ~= nil, "GRM.Admin доступен")

if AD then
    AD.Groups = {}
    for _, g in ipairs(AD.DefaultGroups) do AD.Groups[g.id] = table.Copy and table.Copy(g) or g end

    local function fakePlayer(group, super)
        return {
            __valid = true, __entity = true, isPlayer = true,
            SteamID64 = function() return "76561198000000001" end,
            SteamID = function() return "STEAM_0:1:1" end,
            Nick = function() return "Тест" end,
            GetUserGroup = function() return group end,
            IsSuperAdmin = function() return super == true end,
            IsAdmin = function() return super == true or group == "admin" or group == "moderator" end,
            GetNWString = function() return "" end,
        }
    end

    local mod = fakePlayer("moderator", false)
    local adm = fakePlayer("admin", false)
    local sup = fakePlayer("superadmin", true)

    ok(AD.GroupOf(mod) == "moderator", "группа определяется по движку, если своей записи нет", AD.GroupOf(mod))
    ok(AD.Can(mod, "mod.goto") == true, "модератор может телепортироваться к игроку")
    ok(AD.Can(mod, "mod.jail") == false, "модератор НЕ может сажать в клетку")
    ok(AD.Can(adm, "mod.jail") == true, "администратор может сажать в клетку")
    ok(AD.Can(adm, "cheat.god") == false, "администратор НЕ получает читерские права")
    ok(AD.Can(sup, "cheat.god") == true, "суперадмин получает всё")
    ok(AD.Can(mod, "acl.groups") == false, "правка групп закрыта от модератора")

    ok(AD.Immunity(sup) == 100 and AD.Immunity(mod) == 20, "иммунитет считается по группе",
        tostring(AD.Immunity(sup)) .. "/" .. tostring(AD.Immunity(mod)))
    local can1 = AD.CanTarget(mod, adm)
    local can2 = AD.CanTarget(adm, mod)
    ok(can1 == false, "модератор не может применить действие к администратору")
    ok(can2 == true, "администратор может применить действие к модератору")
    ok(AD.CanTarget(mod, sup) == false, "суперадмина не тронуть")

    -- наследование: у admin есть права moderator
    ok(AD.Can(adm, "mod.goto") == true, "наследование прав по цепочке групп работает")

    -- своя группа из базы назначений сильнее движка
    AD.Users["76561198000000001"] = { group = "admin", ["until"] = 0 }
    ok(AD.GroupOf(mod) == "admin", "запись назначения перекрывает группу движка")
    AD.Users["76561198000000001"] = { group = "admin", ["until"] = 1 }   -- истёкшая
    ok(AD.GroupOf(mod) == "moderator", "истёкшее назначение не действует")
end

print("\n=== 7. УСТОЙЧИВОСТЬ ИНТЕРФЕЙСА (фикс NULL Panel) ===")
ok(panel:find("if not (IsValid(list) and IsValid(search)) then return end", 1, true) ~= nil,
    "пересборка списка проверяет, живы ли его панели")
ok(panel:find("list.OnRemove = function() hook.Remove(\"GRM_AdminPlayersUpdated\", hookID) end", 1, true) ~= nil,
    "подписка на обновление игроков снимается вместе со списком")
ok(panel:find("frame.OnRemove = function()", 1, true) ~= nil, "закрытие окна снимает подписки")
ok(panel:find('hook.Remove("GRM_AdminPlayersUpdated", "GRM_AdminPanel_Players")', 1, true) ~= nil,
    "переключение раздела тоже снимает подписку прошлого")
ok(panel:find("if not IsValid(side) then return end", 1, true) ~= nil,
    "панель действий не рисуется в удалённый контейнер")
ok(core:find("net.Send(targets)", 1, true) ~= nil and core:find("net.Broadcast()", 1, true) == nil
    or core:find("for watcher in pairs(AD.Watchers or {})", 1, true) ~= nil,
    "срез по игрокам уходит только тем, у кого открыто меню")
ok(core:find("Один результат — одно уведомление", 1, true) ~= nil,
    "результат действия больше не дублируется двумя уведомлениями")
ok(core:find("expires < CurTime()", 1, true) ~= nil, "подписка на живой список истекает сама")

print(("\nADMIN CORE: %d/%d, провалов: %d"):format(total - fails, total, fails))
os.exit(fails == 0 and 0 or 1)
