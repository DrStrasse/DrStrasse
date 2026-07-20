--[[--------------------------------------------------------------------
    GRM Faction Permissions v1.0 (Код 122)
    
    Гибкая система доступов для фракций к экономическим функциям.
    Суперадмин через /factions → вкладка "Экономика" выдаёт доступы:
    - Гос.бюджет (просмотр, пополнение, снятие)
    - Бюджеты фракций (просмотр, редактирование)
    - Налоги (просмотр, редактирование ставки)
    - Штрафы (выдача, настройка)
    - Ком.час (установка/снятие)
    - Законы (публикация)
    
    Лидер фракции видит в /factions только те вкладки, к которым есть доступ.
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

-- Проверка доступа
function PERMS.HasPermission(factionName, permission)
    if not PERMS.Data then PERMS.Load() end
    if not factionName or not permission then return false end
    
    local factionPerms = PERMS.Data[factionName] or {}
    return factionPerms[permission] == true
end

-- Выдача доступа
function PERMS.Grant(factionName, permission)
    if not PERMS.Data then PERMS.Load() end
    if not PERMS.Data[factionName] then PERMS.Data[factionName] = {} end
    PERMS.Data[factionName][permission] = true
    PERMS.Save()
end

-- Отзыв доступа
function PERMS.Revoke(factionName, permission)
    if not PERMS.Data then PERMS.Load() end
    if PERMS.Data[factionName] then
        PERMS.Data[factionName][permission] = nil
        PERMS.Save()
    end
end

-- Получить все доступы фракции
function PERMS.GetFactionPerms(factionName)
    if not PERMS.Data then PERMS.Load() end
    return PERMS.Data[factionName] or {}
end

-- Проверка доступа игрока (через фракцию)
function PERMS.PlayerHasPermission(ply, permission)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end -- Суперадмин имеет все доступы
    
    -- Найти фракцию игрока
    local factionName = nil
    if Factions then
        local sid = ply:SteamID()
        local sid64 = ply:SteamID64()
        for name, f in pairs(Factions) do
            if istable(f.Members) and (f.Members[sid] or f.Members[sid64]) then
                factionName = name
                break
            end
        end
    end
    
    if not factionName then return false end
    return PERMS.HasPermission(factionName, permission)
end

-- Инициализация
if SERVER then
    PERMS.Load()
    print("[GRM] Faction Permissions loaded (Код 122)")
end
