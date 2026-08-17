--[[--------------------------------------------------------------------
    GRM Faction Permissions v2.1.0 (Код 122)
    
    Гибкая система доступов для фракций к экономическим функциям.
    Доступы выдаются по ролям (рангам) внутри фракции.
    
    Структура данных:
    {
        ["Фракция"] = {
            roles = {
                ["Роль"] = { permission1 = true, permission2 = true, ... }
            }
        }
    }

    v2.1.0 — добавлена сетевая синхронизация: раньше клиентские вызовы
    GrantToRole/RevokeFromRole/GetFactionRoles писали в ЛОКАЛЬНЫЙ data/ клиента
    и ничего не меняли на сервере (доступы «по ролям» молча не работали).
    Теперь:
      • на сервере Grant/Revoke пишут файл и рассылают обновление клиентам;
      • на клиенте Grant/Revoke отправляют net-сообщение, а чтение идёт из
        синхронизированного PERMS.Data;
      • добавлен псевдоним HasPermission = PlayerHasPermission (его ждёт
        grm_bank_computer).
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.FactionPerms = GRM.FactionPerms or {}
local PERMS = GRM.FactionPerms

-- Файл хранения доступов
PERMS.ConfigFile = "grm_faction_perms.json"

local NET_GET  = "GRM_FPerm_Get"
local NET_DATA = "GRM_FPerm_Data"
local NET_SET  = "GRM_FPerm_Set"

-- Все доступные разрешения
PERMS.Permissions = {
    -- Гос.бюджет
    state_budget_view = "Просмотр гос.бюджета",
    state_budget_add = "Пополнение гос.бюджета",
    state_budget_remove = "Снятие с гос.бюджета",

    -- Бюджеты фракций
    faction_budget_view = "Просмотр бюджетов фракций",
    faction_budget_edit = "Редактирование бюджетов фракций",

    -- Налоги
    tax_view = "Просмотр налогов",
    tax_edit = "Редактирование налоговых ставок",

    -- Штрафы
    fine_issue = "Выдача штрафов",
    fine_configure = "Настройка штрафов",

    -- Ком.час
    kom_hour_set = "Установка комендантского часа",
    kom_hour_remove = "Снятие комендантского часа",

    -- Законы
    law_publish = "Публикация законов",
    law_remove = "Удаление законов",

    -- Инкассация (Код 126)
    incasso_start = "Активация рейса инкассации (/incass)",
    incasso_deliver = "Сдача денег в хранилище (/incass_delivery)",

    -- Закрепление объектов на карте (Задача 9)
    perm_manage = "Закрепление объектов на карте (перм-инструмент)",
}

-- Загрузка доступов (сервер читает файл; на клиенте — сброс пустой).
function PERMS.Load()
    if not file.Exists(PERMS.ConfigFile, "DATA") then
        PERMS.Data = {}
        return
    end
    local data = file.Read(PERMS.ConfigFile, "DATA")
    local ok, tbl = pcall(util.JSONToTable, data)
    if ok and istable(tbl) then
        PERMS.Data = tbl
    else
        PERMS.Data = {}
    end
end

-- Сохранение доступов (только сервер).
function PERMS.Save()
    local ok, data = pcall(util.TableToJSON, PERMS.Data or {}, true)
    if ok then
        file.Write(PERMS.ConfigFile, data)
    end
end

-- Проверить доступ роли
function PERMS.RoleHasPermission(factionName, roleName, permission)
    if not factionName or not roleName or not permission then return false end
    local factionData = PERMS.Data and PERMS.Data[factionName] or {}
    local roleData = factionData.roles or {}
    return roleData[roleName] and roleData[roleName][permission] == true
end

-- Получить все доступы роли
function PERMS.GetRolePerms(factionName, roleName)
    local factionData = PERMS.Data and PERMS.Data[factionName] or {}
    local roleData = factionData.roles or {}
    return roleData[roleName] or {}
end

-- Получить все роли с доступами для фракции
function PERMS.GetFactionRoles(factionName)
    local factionData = PERMS.Data and PERMS.Data[factionName] or {}
    return factionData.roles or {}
end

-- Проверка доступа игрока (через фракцию и роль)
function PERMS.PlayerHasPermission(ply, permission)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end -- Суперадмин имеет все доступы
    if Factions then
        for factionName, f in pairs(Factions) do
            if istable(f) and istable(f.Members) then
                local member = GRM.Identity and GRM.Identity.FactionMember and GRM.Identity.FactionMember(f, ply)
                if member then
                    local roleName = member.Role or "Участник"
                    if PERMS.RoleHasPermission(factionName, roleName, permission) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

-- Псевдоним: grm_bank_computer и др. ждут именно HasPermission.
PERMS.HasPermission = PERMS.PlayerHasPermission

if SERVER then
    util.AddNetworkString(NET_GET)
    util.AddNetworkString(NET_DATA)
    util.AddNetworkString(NET_SET)

    PERMS.Load()

    -- Выдать доступ роли во фракции (сервер: пишем файл + рассылаем).
    function PERMS.GrantToRole(factionName, roleName, permission)
        PERMS.Data = PERMS.Data or {}
        PERMS.Data[factionName] = PERMS.Data[factionName] or { roles = {} }
        PERMS.Data[factionName].roles = PERMS.Data[factionName].roles or {}
        PERMS.Data[factionName].roles[roleName] = PERMS.Data[factionName].roles[roleName] or {}
        PERMS.Data[factionName].roles[roleName][permission] = true
        PERMS.Save()
        PERMS.Broadcast()
    end

    -- Отозвать доступ у роли
    function PERMS.RevokeFromRole(factionName, roleName, permission)
        PERMS.Data = PERMS.Data or {}
        local fd = PERMS.Data[factionName]
        if fd and fd.roles and fd.roles[roleName] then
            fd.roles[roleName][permission] = nil
            PERMS.Save()
            PERMS.Broadcast()
        end
    end

    -- Отправить актуальные доступы одному игроку.
    function PERMS.SendTo(ply)
        if not IsValid(ply) then return end
        net.Start(NET_DATA)
            net.WriteTable(PERMS.Data or {})
        net.Send(ply)
    end

    -- Рассылка всем суперадминам (и лидерам — они видят доступы своей фракции).
    function PERMS.Broadcast()
        for _, p in ipairs((GRM.Perf and GRM.Perf.Players) and GRM.Perf.Players() or player.GetAll()) do
            if IsValid(p) and p:IsSuperAdmin() then
                PERMS.SendTo(p)
            end
        end
    end

    -- Локальная проверка лидерства (без зависимости от FactionsAPI).
    local function isLeaderOfFaction(ply, factionName)
        if not IsValid(ply) or not istable(Factions) or not Factions[factionName] then return false end
        local f = Factions[factionName]
        local ck = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(ply)) or ply:SteamID64()
        local ldr = tostring(f.Leader or "")
        if ldr ~= "" and (ldr == ck or ldr == ply:SteamID() or ldr == ply:SteamID64()) then return true end
        local member = istable(f.Members) and (GRM.Identity.FactionMember(f, ply) or f.Members[ck] or f.Members[ply:SteamID()] or f.Members[ply:SteamID64()]) or nil
        if istable(member) then
            local leaderRole = f.LeaderRoleName or "Лидер"
            if member.Role == leaderRole or member.Role == "Лидер" then return true end
        end
        return false
    end

    net.Receive(NET_GET, function(_, ply)
        if not IsValid(ply) then return end
        if not ply:IsSuperAdmin() then return end
        PERMS.SendTo(ply)
    end)

    net.Receive(NET_SET, function(_, ply)
        if not IsValid(ply) then return end
        local faction = net.ReadString()
        local role = net.ReadString()
        local perm = net.ReadString()
        local val = net.ReadBool()
        if faction == "" or role == "" or perm == "" then return end
        if not PERMS.Permissions[perm] then return end
        -- Право менять доступы: суперадмин или лидер этой фракции.
        if not ply:IsSuperAdmin() and not isLeaderOfFaction(ply, faction) then return end
        if val then
            PERMS.GrantToRole(faction, role, perm)
        else
            PERMS.RevokeFromRole(faction, role, perm)
        end
        PERMS.SendTo(ply)
    end)

    hook.Add("PlayerInitialSpawn", "GRM_FPerm_SyncOnJoin", function(ply)
        timer.Simple(2, function()
            if IsValid(ply) and ply:IsSuperAdmin() then
                PERMS.SendTo(ply)
            end
        end)
    end)

    print("[GRM] Faction Permissions v2.1.0 loaded (Код 122, сетевая синхронизация)")
else
    -- КЛИЕНТ: локальный кеш, пополняемый сервером.
    PERMS.Data = PERMS.Data or {}

    net.Receive(NET_DATA, function()
        PERMS.Data = net.ReadTable() or {}
        hook.Run("GRM_FPermDataUpdated")
    end)

    -- Запросить актуальные доступы у сервера.
    function PERMS.Request()
        net.Start(NET_GET)
        net.SendToServer()
    end

    -- На клиенте Grant/Revoke отправляют net-сообщение (а не пишут локальный файл).
    function PERMS.GrantToRole(factionName, roleName, permission)
        net.Start(NET_SET)
            net.WriteString(tostring(factionName or ""))
            net.WriteString(tostring(roleName or ""))
            net.WriteString(tostring(permission or ""))
            net.WriteBool(true)
        net.SendToServer()
    end

    function PERMS.RevokeFromRole(factionName, roleName, permission)
        net.Start(NET_SET)
            net.WriteString(tostring(factionName or ""))
            net.WriteString(tostring(roleName or ""))
            net.WriteString(tostring(permission or ""))
            net.WriteBool(false)
        net.SendToServer()
    end
end
