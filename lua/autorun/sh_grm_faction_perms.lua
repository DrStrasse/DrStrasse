--[[--------------------------------------------------------------------
    GRM Faction Permissions v2.0 (Код 122)
    
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
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.FactionPerms = GRM.FactionPerms or {}
local PERMS = GRM.FactionPerms

-- Файл хранения доступов
PERMS.ConfigFile = "grm_faction_perms.json"

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
}

-- Загрузка доступов
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

-- Сохранение доступов
function PERMS.Save()
    local ok, data = pcall(util.TableToJSON, PERMS.Data or {}, true)
    if ok then
        file.Write(PERMS.ConfigFile, data)
    end
end

-- Выдать доступ роли во фракции
function PERMS.GrantToRole(factionName, roleName, permission)
    if not PERMS.Data then PERMS.Load() end
    if not PERMS.Data[factionName] then PERMS.Data[factionName] = { roles = {} } end
    if not PERMS.Data[factionName].roles then PERMS.Data[factionName].roles = {} end
    if not PERMS.Data[factionName].roles[roleName] then PERMS.Data[factionName].roles[roleName] = {} end
    
    PERMS.Data[factionName].roles[roleName][permission] = true
    PERMS.Save()
end

-- Отозвать доступ у роли
function PERMS.RevokeFromRole(factionName, roleName, permission)
    if not PERMS.Data then PERMS.Load() end
    if PERMS.Data[factionName] and PERMS.Data[factionName].roles and PERMS.Data[factionName].roles[roleName] then
        PERMS.Data[factionName].roles[roleName][permission] = nil
        PERMS.Save()
    end
end

-- Проверить доступ роли
function PERMS.RoleHasPermission(factionName, roleName, permission)
    if not PERMS.Data then PERMS.Load() end
    if not factionName or not roleName or not permission then return false end
    
    local factionData = PERMS.Data[factionName] or {}
    local roleData = factionData.roles or {}
    return roleData[roleName] and roleData[roleName][permission] == true
end

-- Получить все доступы роли
function PERMS.GetRolePerms(factionName, roleName)
    if not PERMS.Data then PERMS.Load() end
    local factionData = PERMS.Data[factionName] or {}
    local roleData = factionData.roles or {}
    return roleData[roleName] or {}
end

-- Получить все роли с доступами для фракции
function PERMS.GetFactionRoles(factionName)
    if not PERMS.Data then PERMS.Load() end
    local factionData = PERMS.Data[factionName] or {}
    return factionData.roles or {}
end

-- Проверка доступа игрока (через фракцию и роль)
function PERMS.PlayerHasPermission(ply, permission)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end -- Суперадмин имеет все доступы
    
    -- Найти фракцию и роль игрока
    if Factions then
        local sid = ply:SteamID()
        local sid64 = ply:SteamID64()
        for factionName, f in pairs(Factions) do
            if istable(f.Members) then
                local member = f.Members[sid] or f.Members[sid64]
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

-- Инициализация
if SERVER then
    PERMS.Load()
    print("[GRM] Faction Permissions v2.0 loaded (Код 122)")
end
