--[[--------------------------------------------------------------------
    Единая система фракций + волна департамента + админ-меню
    ВЕРСИЯ v3 — Обновлённый UI, маскировка удалена (FIXED)
    + Чат-команда /factions для суперадмина/лидера
--------------------------------------------------------------------]]

if SERVER then
    AddCSLuaFile()
end

local NET_GET_DATA            = "Factions_GetData"
local NET_SEND_DATA           = "Factions_SendData"
local NET_SYNC_ALL            = "Factions_SyncAll"
local NET_ACTION              = "Factions_Action"
local NET_ACTION_RESULT       = "Factions_ActionResult"
local NET_JOIN                = "Factions_Join"
local NET_DECLINE             = "Factions_Decline"
local NET_LEAVE               = "Factions_Leave"
local NET_RADIO               = "Factions_Radio"
local NET_RADIO_MSG           = "Factions_RadioMessage"
local NET_OPEN_ADMIN          = "Factions_OpenAdminMenu"
local NET_OPEN_LEADER         = "Factions_OpenLeaderMenu"
local NET_DEP                 = "Factions_Dep"
local NET_DEPB                = "Factions_Depb"
local NET_DEP_MSG             = "Factions_DepMsg"
local NET_DEPB_MSG            = "Factions_DepbMsg"

-- ============================================================
-- SERVER
-- ============================================================
if SERVER then
    util.AddNetworkString(NET_GET_DATA)
    util.AddNetworkString(NET_SEND_DATA)
    util.AddNetworkString(NET_SYNC_ALL)
    util.AddNetworkString(NET_ACTION)
    util.AddNetworkString(NET_ACTION_RESULT)
    util.AddNetworkString(NET_JOIN)
    util.AddNetworkString(NET_DECLINE)
    util.AddNetworkString(NET_LEAVE)
    util.AddNetworkString(NET_RADIO)
    util.AddNetworkString(NET_RADIO_MSG)
    util.AddNetworkString(NET_OPEN_ADMIN)
    util.AddNetworkString(NET_OPEN_LEADER)
    util.AddNetworkString(NET_DEP)
    util.AddNetworkString(NET_DEPB)
    util.AddNetworkString(NET_DEP_MSG)
    util.AddNetworkString(NET_DEPB_MSG)

    local FACTIONS_FILE = "factions.json"
    local INVITES_FILE  = "invites.json"
    Factions      = nil
    Invites       = nil

    local function safeJSONToTable(data)
        local ok, tbl = pcall(util.JSONToTable, data or "")
        if ok and istable(tbl) then return tbl end
        return {}
    end

    local function loadFactions()
        if not file.Exists(FACTIONS_FILE, "DATA") then return {} end
        local data = file.Read(FACTIONS_FILE, "DATA")
        if not data or data == "" then return {} end
        return safeJSONToTable(data)
    end

    local function saveFactions(tbl)
        file.Write(FACTIONS_FILE, util.TableToJSON(tbl, true))
    end

    local function loadInvites()
        if not file.Exists(INVITES_FILE, "DATA") then return {} end
        local data = file.Read(INVITES_FILE, "DATA")
        if not data or data == "" then return {} end
        return safeJSONToTable(data)
    end

    local function saveInvites(tbl)
        file.Write(INVITES_FILE, util.TableToJSON(tbl, true))
    end

    local function ensureDefaults(f)
        if not f or type(f) ~= "table" then return end

        f.Members     = istable(f.Members)     and f.Members     or {}
        f.Roles       = istable(f.Roles)       and f.Roles       or {}
        f.Departments = istable(f.Departments) and f.Departments or {}

        if type(f.LeaderRoleName) ~= "string" or f.LeaderRoleName == "" then
            f.LeaderRoleName = "Лидер"
        end
        local leaderRoleName = f.LeaderRoleName
        if not table.HasValue(f.Roles, leaderRoleName) then
            table.insert(f.Roles, 1, leaderRoleName)
        end

        -- Убрано: автоматическое добавление "Участник" при каждом ensureDefaults
        -- вызывало баг — при переименовании ранга создавался дубликат.
        -- Роль по умолчанию теперь определяется через getDefaultMemberRole()
        if not table.HasValue(f.Departments, "Основной") then
            table.insert(f.Departments, 1, "Основной")
        end

        if type(f.Tag) ~= "string" then f.Tag = "" end
        if not istable(f.Color) then f.Color = { r = 255, g = 200, b = 50 } end
        f.Color.r = tonumber(f.Color.r) or 255
        f.Color.g = tonumber(f.Color.g) or 200
        f.Color.b = tonumber(f.Color.b) or 50
        if f.DepAccess == nil then f.DepAccess = false end

        if f.Leader and not f.Members[f.Leader] then
            f.Leader = nil
        end
        if f.Leader and f.Members[f.Leader] then
            f.Members[f.Leader].Role = f.LeaderRoleName
        end
    end

    -- Возвращает роль по умолчанию для новых участников:
    -- последний ранг в списке (не лидерский), либо "Участник" если ролей нет
    local function getDefaultMemberRole(f)
        ensureDefaults(f)
        local roles = f.Roles or {}
        local leaderRole = f.LeaderRoleName or "Лидер"
        -- Ищем последний не-лидерский ранг
        for i = #roles, 1, -1 do
            if roles[i] ~= leaderRole then
                return roles[i]
            end
        end
        -- Если все роли — лидерские (маловероятно), добавляем "Участник"
        table.insert(roles, "Участник")
        saveFactions(Factions)
        return "Участник"
    end

    local function ensureAllDefaults()
        for _, f in pairs(Factions) do
            if type(f) == "table" then ensureDefaults(f) end
        end
    end

    Factions = loadFactions()
    Invites  = loadInvites()
    ensureAllDefaults()

    local function buildSyncData()
        local data = {}
        for name, f in pairs(Factions) do
            if type(f) == "table" then
                ensureDefaults(f)
                data[name] = {
                    Leader         = f.Leader,
                    Roles          = f.Roles,
                    Departments    = f.Departments,
                    Members        = f.Members,
                    Tag            = f.Tag,
                    Color          = f.Color,
                    DepAccess      = f.DepAccess,
                    LeaderRoleName = f.LeaderRoleName
                }
            end
        end
        return data
    end

    function broadcastFactionData()
        net.Start(NET_SYNC_ALL)
        net.WriteTable(buildSyncData())
        net.Broadcast()
    end

    local function getFactionOfPlayer(steamID)
        for name, f in pairs(Factions) do
            if type(f) == "table" then
                ensureDefaults(f)
                if f.Members[steamID] then return name end
            end
        end
        return nil
    end

    local function createFaction(name, leaderSteamID)
        if not name or name == "" then return false, "Не указано название" end
        if Factions[name] then return false, "Фракция с таким именем уже существует" end

        local defaultLeaderRole = "Лидер"
        local members = {}
        local leader  = nil
        if leaderSteamID and leaderSteamID ~= "" then
            leader = leaderSteamID
            members[leaderSteamID] = { Role = defaultLeaderRole, Department = "Основной" }
        end

        Factions[name] = {
            Leader         = leader,
            Roles          = { defaultLeaderRole, "Участник" },
            LeaderRoleName = defaultLeaderRole,
            Departments    = { "Основной" },
            Members        = members,
            Tag            = "",
            Color          = { r = 255, g = 200, b = 50 },
            DepAccess      = false
        }
        saveFactions(Factions)
        return true
    end

    local function deleteFaction(name)
        if not Factions[name] then return false, "Фракция не найдена" end
        Factions[name] = nil
        saveFactions(Factions)
        return true
    end

    local function renameFaction(oldName, newName)
        if not oldName or oldName == "" then return false, "Не указано старое название" end
        if not newName or newName == "" then return false, "Не указано новое название" end
        if oldName == newName then return false, "Названия совпадают" end
        if not Factions[oldName] then return false, "Фракция не найдена" end
        if Factions[newName] then return false, "Фракция с таким именем уже существует" end

        Factions[newName] = Factions[oldName]
        Factions[oldName] = nil
        saveFactions(Factions)
        return true
    end

    local function setFactionTag(factionName, tag)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        if type(tag) ~= "string" then return false, "Тег должен быть строкой" end
        tag = string.sub(tag, 1, 5)
        f.Tag = tag
        saveFactions(Factions)
        return true
    end

    local function setFactionColor(factionName, r, g, b)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        r = math.Clamp(math.floor(tonumber(r) or 255), 0, 255)
        g = math.Clamp(math.floor(tonumber(g) or 200), 0, 255)
        b = math.Clamp(math.floor(tonumber(b) or 50),  0, 255)
        f.Color = { r = r, g = g, b = b }
        saveFactions(Factions)
        return true
    end

    local function setFactionDepAccess(factionName, enabled)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        f.DepAccess = enabled and true or false
        saveFactions(Factions)
        return true
    end

    local function addRole(factionName, roleName)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        if not roleName or roleName == "" then return false, "Не указана роль" end
        if roleName == f.LeaderRoleName then return false, "Нельзя добавить роль с именем лидера" end
        if table.HasValue(f.Roles, roleName) then return false, "Такой ранг уже существует" end
        table.insert(f.Roles, roleName)
        saveFactions(Factions)
        return true
    end

    local function removeRole(factionName, roleName)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        if roleName == f.LeaderRoleName then return false, "Нельзя удалить роль лидера" end
        for i, r in ipairs(f.Roles) do
            if r == roleName then
                table.remove(f.Roles, i)
                local fallback = getDefaultMemberRole(f)
                for _, info in pairs(f.Members) do
                    if info.Role == roleName then info.Role = fallback end
                end
                saveFactions(Factions)
                return true
            end
        end
        return false, "Ранг не найден"
    end

    local function renameRole(factionName, oldRoleName, newRoleName)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        if not table.HasValue(f.Roles, oldRoleName) then return false, "Роль не найдена" end
        if table.HasValue(f.Roles, newRoleName) then return false, "Роль с таким именем уже существует" end
        if oldRoleName == f.LeaderRoleName then
            f.LeaderRoleName = newRoleName
        end
        for i, r in ipairs(f.Roles) do
            if r == oldRoleName then f.Roles[i] = newRoleName break end
        end
        for _, info in pairs(f.Members) do
            if info.Role == oldRoleName then info.Role = newRoleName end
        end
        saveFactions(Factions)
        return true
    end

    local function moveRole(factionName, roleName, direction)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        if roleName == f.LeaderRoleName then return false, "Нельзя перемещать роль лидера" end
        for i, r in ipairs(f.Roles) do
            if r == roleName then
                local newIndex = (direction == "up") and (i - 1) or (i + 1)
                if newIndex < 1 or newIndex > #f.Roles then return false, "Крайняя позиция" end
                f.Roles[i], f.Roles[newIndex] = f.Roles[newIndex], f.Roles[i]
                saveFactions(Factions)
                return true
            end
        end
        return false, "Роль не найдена"
    end

    local function addDepartment(factionName, deptName)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        if not deptName or deptName == "" then return false, "Не указан отдел" end
        if table.HasValue(f.Departments, deptName) then return false, "Такой отдел уже существует" end
        table.insert(f.Departments, deptName)
        saveFactions(Factions)
        return true
    end

    local function removeDepartment(factionName, deptName)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        if #f.Departments <= 1 then return false, "Нельзя удалить последний отдел" end
        for i, d in ipairs(f.Departments) do
            if d == deptName then
                table.remove(f.Departments, i)
                local firstDept = f.Departments[1] or "Основной"
                for _, info in pairs(f.Members) do
                    if info.Department == deptName then info.Department = firstDept end
                end
                saveFactions(Factions)
                return true
            end
        end
        return false, "Отдел не найден"
    end

    local function renameDepartment(factionName, oldDeptName, newDeptName)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        if not table.HasValue(f.Departments, oldDeptName) then return false, "Отдел не найден" end
        if table.HasValue(f.Departments, newDeptName) then return false, "Отдел с таким именем уже существует" end
        for i, d in ipairs(f.Departments) do
            if d == oldDeptName then f.Departments[i] = newDeptName break end
        end
        for _, info in pairs(f.Members) do
            if info.Department == oldDeptName then info.Department = newDeptName end
        end
        saveFactions(Factions)
        return true
    end

    local function moveDepartment(factionName, deptName, direction)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        for i, d in ipairs(f.Departments) do
            if d == deptName then
                local newIndex = (direction == "up") and (i - 1) or (i + 1)
                if newIndex < 1 or newIndex > #f.Departments then return false, "Крайняя позиция" end
                f.Departments[i], f.Departments[newIndex] = f.Departments[newIndex], f.Departments[i]
                saveFactions(Factions)
                return true
            end
        end
        return false, "Отдел не найден"
    end

    local function addMember(factionName, steamID, role, dept)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        if f.Members[steamID] then return false, "Игрок уже во фракции" end
        local existing = getFactionOfPlayer(steamID)
        if existing then return false, "Игрок уже состоит во фракции " .. existing end
        if role == f.LeaderRoleName then return false, "Лидер назначается только отдельно" end
        if role and not table.HasValue(f.Roles, role) then return false, "Такого ранга нет" end
        if dept and not table.HasValue(f.Departments, dept) then return false, "Такого отдела нет" end
        f.Members[steamID] = { Role = role or getDefaultMemberRole(f), Department = dept or "Основной" }
        saveFactions(Factions)
        return true
    end

    local function removeMember(factionName, steamID)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        if not f.Members[steamID] then return false, "Игрок не состоит во фракции" end
        if steamID == f.Leader then
            f.Members[steamID] = nil
            f.Leader = nil
            saveFactions(Factions)
            return true, "Лидер удалён, фракция сохранена без лидера"
        end
        f.Members[steamID] = nil
        saveFactions(Factions)
        return true, "Участник удалён"
    end

    local function setMemberRole(factionName, steamID, newRole)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        if not f.Members[steamID] then return false, "Игрок не состоит во фракции" end
        if not table.HasValue(f.Roles, newRole) then return false, "Такого ранга нет" end
        if newRole == f.LeaderRoleName and steamID ~= f.Leader then
            return false, "Лидер назначается только через смену лидера"
        end
        if steamID == f.Leader and newRole ~= f.LeaderRoleName then
            return false, "Нельзя изменить роль текущего лидера отдельно"
        end
        f.Members[steamID].Role = newRole
        saveFactions(Factions)
        return true
    end

    local function setMemberDepartment(factionName, steamID, newDept)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        if not f.Members[steamID] then return false, "Игрок не состоит во фракции" end
        if not table.HasValue(f.Departments, newDept) then return false, "Такого отдела нет" end
        f.Members[steamID].Department = newDept
        saveFactions(Factions)
        return true
    end

    local function changeLeader(factionName, newLeaderSteamID)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        if not f.Members[newLeaderSteamID] then
            local existing = getFactionOfPlayer(newLeaderSteamID)
            if existing then return false, "Игрок уже состоит во фракции " .. existing end
            f.Members[newLeaderSteamID] = { Role = getDefaultMemberRole(f), Department = "Основной" }
        end
        if f.Leader and f.Members[f.Leader] then
            f.Members[f.Leader].Role = getDefaultMemberRole(f)
        end
        f.Leader = newLeaderSteamID
        f.Members[newLeaderSteamID].Role = f.LeaderRoleName
        saveFactions(Factions)
        return true
    end

    -- --------------------
    -- ПРИГЛАШЕНИЯ
    -- --------------------
    local function sendInvite(fromSteam, toSteam, factionName)
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)

        local fromPlayer   = player.GetBySteamID(fromSteam)
        local isSuperAdmin = IsValid(fromPlayer) and fromPlayer:IsSuperAdmin()
        local isLeader     = (f.Leader == fromSteam)
        if not isSuperAdmin and not isLeader then return false, "Недостаточно прав" end
        if getFactionOfPlayer(toSteam) then return false, "Игрок уже состоит во фракции" end

        Invites[toSteam] = { faction = factionName, from = fromSteam, time = os.time() }
        saveInvites(Invites)

        local target = player.GetBySteamID(toSteam)
        if IsValid(target) then
            target:PrintMessage(HUD_PRINTTALK, "Вы приглашены во фракцию " .. factionName .. "! Для принятия напишите /fjoin " .. factionName)
        end
        return true
    end

    local function acceptInvite(steamID, factionName)
        local inv = Invites[steamID]
        if not inv then return false, "У вас нет активных приглашений" end
        if factionName ~= "" and inv.faction:lower() ~= factionName:lower() then
            return false, "У вас нет приглашения в эту фракцию. Ваше приглашение: /fjoin " .. inv.faction
        end
        factionName = inv.faction
        if getFactionOfPlayer(steamID) then return false, "Вы уже состоите во фракции" end
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        f.Members[steamID] = { Role = getDefaultMemberRole(f), Department = "Основной" }
        saveFactions(Factions)
        Invites[steamID] = nil
        saveInvites(Invites)
        local ply = player.GetBySteamID(steamID)
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTTALK, "Вы вступили во фракцию " .. factionName) end
        return true
    end

    local function declineInvite(steamID, factionName)
        local inv = Invites[steamID]
        if not inv then return false, "У вас нет активных приглашений" end
        if inv.faction ~= factionName then return false, "У вас нет приглашения в эту фракцию" end
        Invites[steamID] = nil
        saveInvites(Invites)
        return true
    end

    local function leaveFaction(steamID)
        local factionName = getFactionOfPlayer(steamID)
        if not factionName then return false, "Вы не состоите ни в одной фракции" end
        local f = Factions[factionName]
        if not f then return false, "Фракция не найдена" end
        ensureDefaults(f)
        if f.Leader == steamID then return false, "Лидер не может покинуть фракцию, используйте увольнение" end
        f.Members[steamID] = nil
        saveFactions(Factions)
        return true
    end

    local function respondTo(ply, success, msg)
        net.Start(NET_ACTION_RESULT)
        net.WriteBool(success and true or false)
        net.WriteString(msg or "")
        net.Send(ply)
    end

    local function sendFactionDataTo(ply)
        net.Start(NET_SEND_DATA)
        net.WriteTable(buildSyncData())
        net.Send(ply)
    end

    local function getFactionInfoForPlayer(steamID)
        for name, f in pairs(Factions) do
            if type(f) == "table" then
                ensureDefaults(f)
                if f.Members[steamID] then
                    return name, f.Members[steamID].Role, f.Tag or "", f.Color or {r=255,g=200,b=50}, f.DepAccess
                end
            end
        end
        return nil, nil, "", {r=255,g=200,b=50}, false
    end

    -- --------------------
    -- СЕТЕВЫЕ ОБРАБОТЧИКИ
    -- --------------------
    net.Receive(NET_GET_DATA, function(_, ply) sendFactionDataTo(ply) end)

    net.Receive(NET_ACTION, function(_, ply)
        local action       = net.ReadString()
        local args         = net.ReadTable() or {}
        local steam        = ply:SteamID()
        local isSuperAdmin = ply:IsSuperAdmin()

        local leaderFaction = nil
        for name, f in pairs(Factions) do
            if type(f) == "table" then
                ensureDefaults(f)
                if f.Leader == steam then leaderFaction = name break end
            end
        end
        local isLeader = leaderFaction ~= nil

        local function done(success, msg)
            respondTo(ply, success, msg)
            if success then broadcastFactionData() end
        end

        local function getFactionAndShift()
            if isSuperAdmin then
                local faction = args[1]
                if not faction then done(false, "Не указана фракция") return nil, nil end
                if not Factions[faction] then done(false, "Фракция не существует") return nil, nil end
                return faction, 1
            end
            if not isLeader then done(false, "Недостаточно прав") return nil, nil end
            return leaderFaction, 0
        end

        if action == "createFaction" then
            if not isSuperAdmin then done(false, "Только суперадмин") return end
            local ok, err = createFaction(args[1], args[2])
            done(ok, err)
        elseif action == "renameFaction" then
            if not isSuperAdmin then done(false, "Только суперадмин") return end
            if not args[1] or not args[2] then done(false, "Не указаны параметры") return end
            local ok, err = renameFaction(args[1], args[2])
            done(ok, err)
        elseif action == "deleteFaction" then
            if not isSuperAdmin then done(false, "Только суперадмин") return end
            local ok, err = deleteFaction(args[1])
            done(ok, err)
        elseif action == "changeLeader" then
            if not isSuperAdmin then done(false, "Только суперадмин") return end
            if not args[1] or not args[2] then done(false, "Не указаны параметры") return end
            local ok, err = changeLeader(args[1], args[2])
            done(ok, err)
        elseif action == "setTag" then
            if not isSuperAdmin then done(false, "Только суперадмин") return end
            if not args[1] or not args[2] then done(false, "Не указаны параметры") return end
            local ok, err = setFactionTag(args[1], args[2])
            done(ok, err)
        elseif action == "setColor" then
            if not isSuperAdmin then done(false, "Только суперадмин") return end
            if not args[1] then done(false, "Не указана фракция") return end
            local ok, err = setFactionColor(args[1], args[2], args[3], args[4])
            done(ok, err)
        elseif action == "setDepAccess" then
            if not isSuperAdmin then done(false, "Только суперадмин") return end
            if not args[1] then done(false, "Не указана фракция") return end
            local ok, err = setFactionDepAccess(args[1], args[2])
            done(ok, err)
        elseif action == "addRole" then
            local faction, shift = getFactionAndShift()
            if not faction then return end
            local ok, err = addRole(faction, args[1 + shift])
            done(ok, err)
        elseif action == "removeRole" then
            local faction, shift = getFactionAndShift()
            if not faction then return end
            local ok, err = removeRole(faction, args[1 + shift])
            done(ok, err)
        elseif action == "renameRole" then
            local faction, shift = getFactionAndShift()
            if not faction then return end
            local ok, err = renameRole(faction, args[1 + shift], args[2 + shift])
            done(ok, err)
        elseif action == "moveRole" then
            local faction, shift = getFactionAndShift()
            if not faction then return end
            local ok, err = moveRole(faction, args[1 + shift], args[2 + shift])
            done(ok, err)
        elseif action == "addDepartment" then
            local faction, shift = getFactionAndShift()
            if not faction then return end
            local ok, err = addDepartment(faction, args[1 + shift])
            done(ok, err)
        elseif action == "removeDepartment" then
            local faction, shift = getFactionAndShift()
            if not faction then return end
            local ok, err = removeDepartment(faction, args[1 + shift])
            done(ok, err)
        elseif action == "renameDepartment" then
            local faction, shift = getFactionAndShift()
            if not faction then return end
            local ok, err = renameDepartment(faction, args[1 + shift], args[2 + shift])
            done(ok, err)
        elseif action == "moveDepartment" then
            local faction, shift = getFactionAndShift()
            if not faction then return end
            local ok, err = moveDepartment(faction, args[1 + shift], args[2 + shift])
            done(ok, err)
        elseif action == "inviteMember" then
            local faction, shift = getFactionAndShift()
            if not faction then return end
            local ok, err = sendInvite(steam, args[1 + shift], faction)
            done(ok, err)
        elseif action == "removeMember" then
            local faction, shift = getFactionAndShift()
            if not faction then return end
            local ok, err = removeMember(faction, args[1 + shift])
            done(ok, err)
        elseif action == "setRole" then
            local faction, shift = getFactionAndShift()
            if not faction then return end
            local ok, err = setMemberRole(faction, args[1 + shift], args[2 + shift])
            done(ok, err)
        elseif action == "setDepartment" then
            local faction, shift = getFactionAndShift()
            if not faction then return end
            local ok, err = setMemberDepartment(faction, args[1 + shift], args[2 + shift])
            done(ok, err)
        else
            done(false, "Неизвестное действие")
        end
    end)

    net.Receive(NET_JOIN, function(_, ply)
        local factionName = net.ReadString()
        local ok, err = acceptInvite(ply:SteamID(), factionName)
        if ok then
            ply:PrintMessage(HUD_PRINTTALK, "Вы вступили во фракцию " .. factionName)
            broadcastFactionData()
        else
            ply:PrintMessage(HUD_PRINTTALK, "Ошибка: " .. err)
        end
    end)

    net.Receive(NET_DECLINE, function(_, ply)
        local factionName = net.ReadString()
        local ok, err = declineInvite(ply:SteamID(), factionName)
        if ok then ply:PrintMessage(HUD_PRINTTALK, "Вы отклонили приглашение во фракцию " .. factionName)
        else ply:PrintMessage(HUD_PRINTTALK, "Ошибка: " .. err) end
    end)

    net.Receive(NET_LEAVE, function(_, ply)
        local ok, err = leaveFaction(ply:SteamID())
        if ok then ply:PrintMessage(HUD_PRINTTALK, "Вы покинули фракцию") broadcastFactionData()
        else ply:PrintMessage(HUD_PRINTTALK, "Ошибка: " .. err) end
    end)

    net.Receive(NET_RADIO, function(_, ply)
        local text = net.ReadString()
        if not text or text == "" then return end
        local steam = ply:SteamID()

        local factionName, role = nil, nil
        for name, f in pairs(Factions) do
            if type(f) == "table" then
                ensureDefaults(f)
                if f.Members[steam] then factionName = name role = f.Members[steam].Role break end
            end
        end

        if not factionName then ply:PrintMessage(HUD_PRINTTALK, "Вы не состоите ни в одной фракции.") return end
        local f = Factions[factionName]
        local tag = (f and f.Tag and f.Tag ~= "") and f.Tag or factionName
        local msg = string.format("[%s] %s (%s): %s", tag, ply:Nick(), role or "Участник", text)

        local recipients = {}
        for memberSteam, _ in pairs(Factions[factionName].Members) do
            local target = player.GetBySteamID(memberSteam)
            if IsValid(target) then recipients[#recipients + 1] = target end
        end
        if #recipients > 0 then
            net.Start(NET_RADIO_MSG) net.WriteString(msg) net.Send(recipients)
        end
    end)

    net.Receive(NET_DEP, function(_, ply)
        local text = net.ReadString()
        if not text or text == "" then return end
        local steam = ply:SteamID()
        local factionName, role, tag, color, depAccess = getFactionInfoForPlayer(steam)
        if not factionName then ply:PrintMessage(HUD_PRINTTALK, "[Волна] Вы не состоите ни в одной фракции.") return end
        if not depAccess then ply:PrintMessage(HUD_PRINTTALK, "[Волна] Ваша фракция не имеет доступа к волне департамента.") return end
        local displayTag = (tag and tag ~= "") and tag or factionName
        local msgText = string.format("[%s] %s (%s): - %s", displayTag, ply:Nick(), role or "Участник", text)

        net.Start(NET_DEP_MSG)
        net.WriteUInt(color.r, 8) net.WriteUInt(color.g, 8) net.WriteUInt(color.b, 8)
        net.WriteString(msgText)
        net.Broadcast()
    end)

    net.Receive(NET_DEPB, function(_, ply)
        local text = net.ReadString()
        if not text or text == "" then return end
        local steam = ply:SteamID()
        local factionName, role, tag, color, depAccess = getFactionInfoForPlayer(steam)
        if not factionName then ply:PrintMessage(HUD_PRINTTALK, "[Волна] Вы не состоите ни в одной фракции.") return end
        if not depAccess then ply:PrintMessage(HUD_PRINTTALK, "[Волна] Ваша фракция не имеет доступа к волне департамента.") return end
        local displayTag = (tag and tag ~= "") and tag or factionName
        local msgText = string.format("[%s] %s (%s): (( - %s ))", displayTag, ply:Nick(), role or "Участник", text)

        net.Start(NET_DEPB_MSG)
        net.WriteUInt(color.r, 8) net.WriteUInt(color.g, 8) net.WriteUInt(color.b, 8)
        net.WriteString(msgText)
        net.Broadcast()
    end)

    hook.Add("PlayerInitialSpawn", "Factions_SyncOnJoin", function(ply)
        timer.Simple(1, function() if IsValid(ply) then broadcastFactionData() end end)
    end)

    -- ============================================================
    -- ЧАТ-КОМАНДА /factions (для суперадмина и лидера)
    -- ============================================================
    hook.Add("PlayerSay", "Factions_ChatCommand", function(ply, text)
        local lower = string.lower(string.Trim(text))
        if lower == "/factions" then
            if ply:IsSuperAdmin() then
                net.Start(NET_OPEN_ADMIN)
                net.Send(ply)
            else
                -- Проверяем, является ли игрок лидером
                local steam = ply:SteamID()
                local isLeader = false
                for _, f in pairs(Factions) do
                    if type(f) == "table" and f.Leader == steam then
                        isLeader = true
                        break
                    end
                end
                if isLeader then
                    net.Start(NET_OPEN_LEADER)
                    net.Send(ply)
                else
                    ply:PrintMessage(HUD_PRINTTALK, "[Фракции] У вас нет прав для использования этой команды.")
                end
            end
            return ""  -- Скрываем команду из чата
        end
    end)

    -- ============================================================
    -- ULX КОМАНДЫ (если ULX установлен)
    -- ============================================================
    if not ULib or not ulx then
        print("[Factions] ULX не найден, ULX-команды не зарегистрированы")
    else
        local cmdFactions = ulx.command("Utility", "ulx factions", function(ply)
            if not ply:IsSuperAdmin() then ply:PrintMessage(HUD_PRINTTALK, "У вас нет прав.") return end
            net.Start(NET_OPEN_ADMIN) net.Send(ply)
        end, "factions")
        cmdFactions:defaultAccess(ULib.ACCESS_SUPERADMIN)

        local cmdLeader = ulx.command("Utility", "ulx factions_leader", function(ply)
            local steam = ply:SteamID()
            local isLeader = false
            for _, f in pairs(Factions) do
                if type(f) == "table" and f.Leader == steam then isLeader = true break end
            end
            if not isLeader then ply:PrintMessage(HUD_PRINTTALK, "Вы не являетесь лидером.") return end
            net.Start(NET_OPEN_LEADER) net.Send(ply)
        end, "factions_leader")
        cmdLeader:defaultAccess(ULib.ACCESS_ALL)
    end

    print("[Factions] Серверная часть загружена (v3 fixed + чат-команда /factions)")
end

-- ============================================================
-- CLIENT
-- ============================================================
if CLIENT then
    ui           = ui           or {}
    FactionsData = FactionsData or {}
    local pendingActionCallback = nil
    local pendingDataCallback   = nil
    local nameCache             = nameCache or {}

    -- Цвета UI
    local THEME = {
        bg          = Color(25, 25, 30, 245),
        bgLight     = Color(35, 35, 42, 240),
        bgHover     = Color(50, 50, 60, 250),
        accent      = Color(80, 160, 255),
        accentDark  = Color(50, 120, 200),
        text        = Color(220, 220, 230),
        textDim     = Color(150, 150, 165),
        success     = Color(60, 200, 100),
        danger      = Color(220, 60, 60),
        dangerHover = Color(180, 40, 40),
        border      = Color(60, 60, 75),
        separator   = Color(55, 55, 70),
    }

    surface.CreateFont("Factions_Title", { font = "Roboto", size = 20, weight = 700, antialias = true })
    surface.CreateFont("Factions_Normal", { font = "Roboto", size = 14, weight = 500, antialias = true })
    surface.CreateFont("Factions_Small",  { font = "Roboto", size = 12, weight = 400, antialias = true })
    surface.CreateFont("Factions_HUD",    { font = "Roboto", size = 16, weight = 700, antialias = true })

    net.Receive(NET_SYNC_ALL, function()
        FactionsData = net.ReadTable() or {}
        refreshAllUI(FactionsData)
    end)

    net.Receive(NET_RADIO_MSG, function()
        local msg = net.ReadString()
        chat.AddText(Color(255, 200, 0), "[Рация] ", Color(255, 255, 255), msg)
    end)

    net.Receive(NET_DEP_MSG, function()
        local r, g, b = net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8)
        local msg = net.ReadString()
        chat.AddText(Color(r, g, b), "[Волна] ", Color(255, 255, 255), msg)
    end)

    net.Receive(NET_DEPB_MSG, function()
        local r, g, b = net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8)
        local msg = net.ReadString()
        chat.AddText(Color(r, g, b), "[Волна OOC] ", Color(180, 180, 180), msg)
    end)

    net.Receive(NET_ACTION_RESULT, function()
        local success = net.ReadBool()
        local msg     = net.ReadString()
        if pendingActionCallback then
            local cb = pendingActionCallback
            pendingActionCallback = nil
            cb(success, msg)
        end
    end)

    net.Receive(NET_SEND_DATA, function()
        local data = net.ReadTable() or {}
        FactionsData = data
        if pendingDataCallback then
            local cb = pendingDataCallback
            pendingDataCallback = nil
            cb(data)
        end
    end)

    local function sendAction(action, args, callback)
        local safeArgs = {}
        for i, v in ipairs(args or {}) do
            local t = type(v)
            if t == "string" or t == "number" or t == "boolean" or t == "table" then
                safeArgs[i] = v
            elseif t ~= "nil" then
                safeArgs[i] = tostring(v)
            end
        end
        net.Start(NET_ACTION)
        net.WriteString(action)
        net.WriteTable(safeArgs)
        net.SendToServer()
        if callback then pendingActionCallback = callback end
    end

    local function requestData(callback)
        net.Start(NET_GET_DATA)
        net.SendToServer()
        if callback then pendingDataCallback = callback end
    end

    local function getData(callback)
        requestData(callback)
    end

    local function getPlayerName(steamID, callback)
        if not steamID or steamID == "" then callback("Нет") return end
        if nameCache[steamID] then callback(nameCache[steamID]) return end
        local steam64 = util.SteamIDTo64(steamID)
        if not steam64 or steam64 == "0" then
            nameCache[steamID] = steamID
            callback(steamID)
            return
        end
        steamworks.RequestPlayerInfo(steam64, function(name)
            nameCache[steamID] = name or steamID
            callback(nameCache[steamID])
        end)
    end

    -- Стилизованная кнопка
    local function styledButton(parent, text, color, hoverColor, textColor)
        local btn = vgui.Create("DButton", parent)
        btn:SetText(text)
        btn:SetFont("Factions_Normal")
        btn:SetTextColor(textColor or Color(255, 255, 255))
        function btn:Paint(w, h)
            local c = self:IsHovered() and (hoverColor or THEME.accentDark) or (color or THEME.accent)
            draw.RoundedBox(4, 0, 0, w, h, c)
        end
        return btn
    end

    -- Стилизованная панель-секция
    local function sectionPanel(parent, title)
        local panel = vgui.Create("DPanel", parent)
        panel:Dock(TOP) panel:SetTall(30) panel:DockMargin(0, 8, 0, 4) panel:SetPaintBackground(true)
        function panel:Paint(w, h)
            surface.SetDrawColor(THEME.separator)
            surface.DrawRect(0, h - 1, w, 1)
            draw.SimpleText(title, "Factions_Normal", 4, h / 2, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        return panel
    end

    local function rebuildFactionCombos(data)
        local combos = {
            ui.factionCombo,
            ui.factionCombo3,
            ui.factionComboList,
            ui.factionComboRanks,
            ui.factionComboDepts,
            ui.factionComboDepWave
        }
        for _, combo in ipairs(combos) do
            if IsValid(combo) then
                local selected = combo:GetValue()
                combo:Clear()
                for name, _ in pairs(data or {}) do combo:AddChoice(name) end
                if selected and data and data[selected] then combo:SetValue(selected) end
                combo:InvalidateLayout(true)
            end
        end
    end

    -- ============================================================
    -- refreshAllUI — FIX: запрашивает данные с сервера если пусто
    -- ============================================================
    function refreshAllUI(data)
        -- Если данные не переданы и локальный кеш пуст — запросить с сервера
        if not data and (not FactionsData or table.Count(FactionsData) == 0) then
            getData(function(freshData)
                FactionsData = freshData or {}
                refreshAllUI(FactionsData)
            end)
            return
        end

        data = data or FactionsData
        FactionsData = data

        rebuildFactionCombos(data)

        if IsValid(ui.listView) then
            ui.listView:Clear()
            for name, f in pairs(data) do
                local leaderStr = f.Leader or "Нет"
                local count = table.Count(f.Members or {})
                local tagStr = (f.Tag and f.Tag ~= "") and ("[" .. f.Tag .. "] ") or ""
                ui.listView:AddLine(tagStr .. name, leaderStr, count)
            end
        end

        updateLeaderRanks(data)
        updateLeaderDepartments(data)
        updateLeaderMemberList(data)
        updateDepWavePanel(data)
    end

    -- ============================================================
    -- ЛИДЕР: РАНГИ
    -- ============================================================
    function updateLeaderRanks(data)
        if not IsValid(ui.ranksScrollLeader) then return end
        local scroll = ui.ranksScrollLeader
        scroll:Clear()

        local mySteam = LocalPlayer():SteamID()
        local factionName, f = nil, nil
        for name, fdata in pairs(data or {}) do
            if fdata.Leader == mySteam then factionName = name f = fdata break end
        end
        if not factionName then return end

        local roles = f.Roles or {}
        for _, roleName in ipairs(roles) do
            local row = vgui.Create("DPanel", scroll)
            row:SetTall(36) row:Dock(TOP) row:DockMargin(0, 2, 0, 2) row:SetPaintBackground(false)

            local edit = vgui.Create("DTextEntry", row)
            edit:SetPos(70, 5) edit:SetSize(160, 26) edit:SetText(roleName)
            edit:SetFont("Factions_Normal")

            local leaderRoleName = (f and f.LeaderRoleName) or "Лидер"
            local isLeader = (roleName == leaderRoleName)

            if not isLeader then
                local btnUp = styledButton(row, "▲", THEME.bgLight, THEME.bgHover, THEME.text)
                btnUp:SetPos(5, 5) btnUp:SetSize(28, 26)
                btnUp.DoClick = function()
                    sendAction("moveRole", { roleName, "up" }, function(ok, msg)
                        if ok then notification.AddLegacy("Роль перемещена", NOTIFY_GENERIC, 3) refreshAllUI()
                        else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
                    end)
                end

                local btnDown = styledButton(row, "▼", THEME.bgLight, THEME.bgHover, THEME.text)
                btnDown:SetPos(37, 5) btnDown:SetSize(28, 26)
                btnDown.DoClick = function()
                    sendAction("moveRole", { roleName, "down" }, function(ok, msg)
                        if ok then notification.AddLegacy("Роль перемещена", NOTIFY_GENERIC, 3) refreshAllUI()
                        else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
                    end)
                end
            end

            local btnRename = styledButton(row, "✎", THEME.accent, THEME.accentDark)
            btnRename:SetPos(240, 5) btnRename:SetSize(36, 26)
            btnRename.DoClick = function()
                local newName = edit:GetText()
                if newName == "" or newName == roleName then return end
                sendAction("renameRole", { roleName, newName }, function(ok, msg)
                    if ok then notification.AddLegacy("Роль переименована", NOTIFY_GENERIC, 3) refreshAllUI()
                    else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) edit:SetText(roleName) end
                end)
            end
            edit.OnEnter = function() if IsValid(btnRename) then btnRename:DoClick() end end

            if not isLeader then
                local btnRemove = styledButton(row, "✕", THEME.danger, THEME.dangerHover)
                btnRemove:SetPos(282, 5) btnRemove:SetSize(36, 26)
                btnRemove.DoClick = function()
                    sendAction("removeRole", { roleName }, function(ok, msg)
                        if ok then notification.AddLegacy("Роль удалена", NOTIFY_GENERIC, 3) refreshAllUI()
                        else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
                    end)
                end
            else
                local lblLeader = vgui.Create("DLabel", row)
                lblLeader:SetPos(282, 8) lblLeader:SetSize(60, 20)
                lblLeader:SetText("★ Лидер") lblLeader:SetFont("Factions_Small")
                lblLeader:SetTextColor(Color(255, 220, 80))
            end
        end

        local addPanel = vgui.Create("DPanel", scroll)
        addPanel:SetTall(40) addPanel:Dock(TOP) addPanel:DockMargin(0, 6, 0, 4) addPanel:SetPaintBackground(false)

        local lbl = vgui.Create("DLabel", addPanel)
        lbl:SetText("Новая роль:") lbl:SetPos(10, 10) lbl:SetSize(80, 20) lbl:SetFont("Factions_Normal")
        lbl:SetTextColor(THEME.text)

        local newEntry = vgui.Create("DTextEntry", addPanel)
        newEntry:SetPos(100, 7) newEntry:SetSize(160, 26) newEntry:SetPlaceholderText("Введите название")
        newEntry:SetFont("Factions_Normal")

        local btnAdd = styledButton(addPanel, "+ Добавить", THEME.success, Color(40, 160, 80))
        btnAdd:SetPos(270, 7) btnAdd:SetSize(100, 26)
        btnAdd.DoClick = function()
            local newRole = newEntry:GetText()
            if newRole == "" then return end
            sendAction("addRole", { newRole }, function(ok, msg)
                if ok then notification.AddLegacy("Роль добавлена", NOTIFY_GENERIC, 3) refreshAllUI() newEntry:SetText("")
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end
        newEntry.OnEnter = function() if IsValid(btnAdd) then btnAdd:DoClick() end end
    end

    -- ============================================================
    -- ЛИДЕР: ОТДЕЛЫ
    -- ============================================================
    function updateLeaderDepartments(data)
        if not IsValid(ui.deptsScrollLeader) then return end
        local scroll = ui.deptsScrollLeader
        scroll:Clear()

        local mySteam = LocalPlayer():SteamID()
        local factionName, f = nil, nil
        for name, fdata in pairs(data or {}) do
            if fdata.Leader == mySteam then factionName = name f = fdata break end
        end
        if not factionName then return end

        local departments = f.Departments or {}
        for _, deptName in ipairs(departments) do
            local row = vgui.Create("DPanel", scroll)
            row:SetTall(36) row:Dock(TOP) row:DockMargin(0, 2, 0, 2) row:SetPaintBackground(false)

            local btnUp = styledButton(row, "▲", THEME.bgLight, THEME.bgHover, THEME.text)
            btnUp:SetPos(5, 5) btnUp:SetSize(28, 26)
            btnUp.DoClick = function()
                sendAction("moveDepartment", { deptName, "up" }, function(ok, msg)
                    if ok then notification.AddLegacy("Отдел перемещён", NOTIFY_GENERIC, 3) refreshAllUI()
                    else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
                end)
            end

            local btnDown = styledButton(row, "▼", THEME.bgLight, THEME.bgHover, THEME.text)
            btnDown:SetPos(37, 5) btnDown:SetSize(28, 26)
            btnDown.DoClick = function()
                sendAction("moveDepartment", { deptName, "down" }, function(ok, msg)
                    if ok then notification.AddLegacy("Отдел перемещён", NOTIFY_GENERIC, 3) refreshAllUI()
                    else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
                end)
            end

            local edit = vgui.Create("DTextEntry", row)
            edit:SetPos(70, 5) edit:SetSize(160, 26) edit:SetText(deptName)
            edit:SetFont("Factions_Normal")

            local btnRename = styledButton(row, "✎", THEME.accent, THEME.accentDark)
            btnRename:SetPos(240, 5) btnRename:SetSize(36, 26)
            btnRename.DoClick = function()
                local newName = edit:GetText()
                if newName == "" or newName == deptName then return end
                sendAction("renameDepartment", { deptName, newName }, function(ok, msg)
                    if ok then notification.AddLegacy("Отдел переименован", NOTIFY_GENERIC, 3) refreshAllUI()
                    else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) edit:SetText(deptName) end
                end)
            end

            if #departments > 1 then
                local btnRemove = styledButton(row, "✕", THEME.danger, THEME.dangerHover)
                btnRemove:SetPos(282, 5) btnRemove:SetSize(36, 26)
                btnRemove.DoClick = function()
                    sendAction("removeDepartment", { deptName }, function(ok, msg)
                        if ok then notification.AddLegacy("Отдел удалён", NOTIFY_GENERIC, 3) refreshAllUI()
                        else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
                    end)
                end
            else
                local lblLast = vgui.Create("DLabel", row)
                lblLast:SetPos(282, 8) lblLast:SetSize(100, 20)
                lblLast:SetText("(последний)") lblLast:SetFont("Factions_Small")
                lblLast:SetTextColor(THEME.textDim)
            end
        end

        local addPanel = vgui.Create("DPanel", scroll)
        addPanel:SetTall(40) addPanel:Dock(TOP) addPanel:DockMargin(0, 5, 0, 0) addPanel:SetPaintBackground(false)

        local lbl = vgui.Create("DLabel", addPanel)
        lbl:SetText("Новый отдел:") lbl:SetPos(10, 10) lbl:SetSize(80, 20) lbl:SetFont("Factions_Normal")
        lbl:SetTextColor(THEME.text)

        local newEntry = vgui.Create("DTextEntry", addPanel)
        newEntry:SetPos(100, 7) newEntry:SetSize(160, 26) newEntry:SetFont("Factions_Normal")

        local btnAdd = styledButton(addPanel, "+ Добавить", THEME.success, Color(40, 160, 80))
        btnAdd:SetPos(270, 7) btnAdd:SetSize(100, 26)
        btnAdd.DoClick = function()
            local newDept = newEntry:GetText()
            if newDept == "" then return end
            sendAction("addDepartment", { newDept }, function(ok, msg)
                if ok then notification.AddLegacy("Отдел добавлен", NOTIFY_GENERIC, 3) refreshAllUI() newEntry:SetText("")
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end
    end

    -- ============================================================
    -- ЛИДЕР: СПИСОК УЧАСТНИКОВ
    -- ============================================================
    function updateLeaderMemberList(data)
        if not IsValid(ui.memberScrollLeader) then return end
        local scroll = ui.memberScrollLeader
        scroll:Clear()

        local mySteam = LocalPlayer():SteamID()
        local factionName, f = nil, nil
        for name, fdata in pairs(data or {}) do
            if fdata.Leader == mySteam then factionName = name f = fdata break end
        end
        if not f then
            if IsValid(ui.leaderTitleLabel) then ui.leaderTitleLabel:SetText("Вы не лидер") end
            return
        end
        if IsValid(ui.leaderTitleLabel) then
            ui.leaderTitleLabel:SetText("Фракция: " .. factionName)
        end

        local members     = f.Members     or {}
        local roles       = f.Roles       or {}
        local sorted = {}
        for steam, info in pairs(members) do sorted[#sorted + 1] = { steam = steam, info = info } end
        table.sort(sorted, function(a, b)
            if a.steam == f.Leader then return true end
            if b.steam == f.Leader then return false end
            local idxA, idxB = 0, 0
            for i, r in ipairs(roles) do
                if r == a.info.Role then idxA = i end
                if r == b.info.Role then idxB = i end
            end
            return idxA > idxB
        end)

        for _, item in ipairs(sorted) do
            local steam = item.steam
            local info  = item.info
            local isLeaderMember = (steam == f.Leader)

            local row = vgui.Create("DPanel", scroll)
            row:SetTall(32) row:Dock(TOP) row:DockMargin(0, 1, 0, 1)
            function row:Paint(w, h)
                if isLeaderMember then
                    surface.SetDrawColor(255, 220, 80, 20)
                    surface.DrawRect(0, 0, w, h)
                end
            end

            local lblSteam = vgui.Create("DLabel", row)
            lblSteam:SetPos(8, 6) lblSteam:SetSize(200, 20) lblSteam:SetText(steam)
            lblSteam:SetFont("Factions_Normal")
            if isLeaderMember then lblSteam:SetTextColor(Color(255, 220, 80)) end

            local lblRole = vgui.Create("DLabel", row)
            lblRole:SetPos(220, 6) lblRole:SetSize(130, 20) lblRole:SetText(info.Role or "Участник")
            lblRole:SetFont("Factions_Normal") lblRole:SetTextColor(THEME.accent)

            local lblDept = vgui.Create("DLabel", row)
            lblDept:SetPos(360, 6) lblDept:SetSize(130, 20) lblDept:SetText(info.Department or "Основной")
            lblDept:SetFont("Factions_Normal") lblDept:SetTextColor(THEME.textDim)

            getPlayerName(steam, function(name)
                if IsValid(lblSteam) then lblSteam:SetText(name .. " (" .. steam .. ")") end
            end)
        end
    end

    -- ============================================================
    -- АДМИНКА: РАНГИ
    -- ============================================================
    function updateRanksList(factionName, data)
        if not IsValid(ui.ranksScroll) then return end
        local scroll = ui.ranksScroll
        scroll:Clear()
        if not factionName or not data or not data[factionName] then return end

        local f = data[factionName]
        local roles = f.Roles or {}

        for _, roleName in ipairs(roles) do
            local row = vgui.Create("DPanel", scroll)
            row:SetTall(36) row:Dock(TOP) row:DockMargin(0, 2, 0, 2) row:SetPaintBackground(false)

            local leaderRoleName = f.LeaderRoleName or "Лидер"
            local isLeader = (roleName == leaderRoleName)

            if not isLeader then
                local btnUp = styledButton(row, "▲", THEME.bgLight, THEME.bgHover, THEME.text)
                btnUp:SetPos(5, 5) btnUp:SetSize(28, 26)
                btnUp.DoClick = function()
                    sendAction("moveRole", { factionName, roleName, "up" }, function(ok, msg)
                        if ok then notification.AddLegacy("Роль перемещена", NOTIFY_GENERIC, 3) refreshAllUI()
                        else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
                    end)
                end

                local btnDown = styledButton(row, "▼", THEME.bgLight, THEME.bgHover, THEME.text)
                btnDown:SetPos(37, 5) btnDown:SetSize(28, 26)
                btnDown.DoClick = function()
                    sendAction("moveRole", { factionName, roleName, "down" }, function(ok, msg)
                        if ok then notification.AddLegacy("Роль перемещена", NOTIFY_GENERIC, 3) refreshAllUI()
                        else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
                    end)
                end
            end

            local edit = vgui.Create("DTextEntry", row)
            edit:SetPos(70, 5) edit:SetSize(160, 26) edit:SetText(roleName)
            edit:SetFont("Factions_Normal")

            local btnRename = styledButton(row, "✎", THEME.accent, THEME.accentDark)
            btnRename:SetPos(240, 5) btnRename:SetSize(36, 26)
            btnRename.DoClick = function()
                local newName = edit:GetText()
                if newName == "" or newName == roleName then return end
                sendAction("renameRole", { factionName, roleName, newName }, function(ok, msg)
                    if ok then notification.AddLegacy("Роль переименована", NOTIFY_GENERIC, 3) refreshAllUI()
                    else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) edit:SetText(roleName) end
                end)
            end

            if not isLeader then
                local btnRemove = styledButton(row, "✕", THEME.danger, THEME.dangerHover)
                btnRemove:SetPos(282, 5) btnRemove:SetSize(36, 26)
                btnRemove.DoClick = function()
                    sendAction("removeRole", { factionName, roleName }, function(ok, msg)
                        if ok then notification.AddLegacy("Роль удалена", NOTIFY_GENERIC, 3) refreshAllUI()
                        else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
                    end)
                end
            else
                local lblLeader = vgui.Create("DLabel", row)
                lblLeader:SetPos(282, 8) lblLeader:SetSize(60, 20)
                lblLeader:SetText("★ Лидер") lblLeader:SetFont("Factions_Small")
                lblLeader:SetTextColor(Color(255, 220, 80))
            end
        end

        local addPanel = vgui.Create("DPanel", scroll)
        addPanel:SetTall(40) addPanel:Dock(TOP) addPanel:DockMargin(0, 5, 0, 0) addPanel:SetPaintBackground(false)

        local lbl = vgui.Create("DLabel", addPanel)
        lbl:SetText("Новая роль:") lbl:SetPos(10, 10) lbl:SetSize(80, 20) lbl:SetFont("Factions_Normal")
        lbl:SetTextColor(THEME.text)

        local newEntry = vgui.Create("DTextEntry", addPanel)
        newEntry:SetPos(100, 7) newEntry:SetSize(160, 26) newEntry:SetFont("Factions_Normal")

        local btnAdd = styledButton(addPanel, "+ Добавить", THEME.success, Color(40, 160, 80))
        btnAdd:SetPos(270, 7) btnAdd:SetSize(100, 26)
        btnAdd.DoClick = function()
            local newRole = newEntry:GetText()
            if newRole == "" then return end
            sendAction("addRole", { factionName, newRole }, function(ok, msg)
                if ok then notification.AddLegacy("Роль добавлена", NOTIFY_GENERIC, 3) refreshAllUI() newEntry:SetText("")
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end
    end

    -- ============================================================
    -- АДМИНКА: ОТДЕЛЫ
    -- ============================================================
    function updateDepartmentsList(factionName, data)
        if not IsValid(ui.deptsScroll) then return end
        local scroll = ui.deptsScroll
        scroll:Clear()
        if not factionName or not data or not data[factionName] then return end

        local f = data[factionName]
        local departments = f.Departments or {}

        for _, deptName in ipairs(departments) do
            local row = vgui.Create("DPanel", scroll)
            row:SetTall(36) row:Dock(TOP) row:DockMargin(0, 2, 0, 2) row:SetPaintBackground(false)

            local btnUp = styledButton(row, "▲", THEME.bgLight, THEME.bgHover, THEME.text)
            btnUp:SetPos(5, 5) btnUp:SetSize(28, 26)
            btnUp.DoClick = function()
                sendAction("moveDepartment", { factionName, deptName, "up" }, function(ok, msg)
                    if ok then notification.AddLegacy("Отдел перемещён", NOTIFY_GENERIC, 3) refreshAllUI()
                    else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
                end)
            end

            local btnDown = styledButton(row, "▼", THEME.bgLight, THEME.bgHover, THEME.text)
            btnDown:SetPos(37, 5) btnDown:SetSize(28, 26)
            btnDown.DoClick = function()
                sendAction("moveDepartment", { factionName, deptName, "down" }, function(ok, msg)
                    if ok then notification.AddLegacy("Отдел перемещён", NOTIFY_GENERIC, 3) refreshAllUI()
                    else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
                end)
            end

            local edit = vgui.Create("DTextEntry", row)
            edit:SetPos(70, 5) edit:SetSize(160, 26) edit:SetText(deptName)
            edit:SetFont("Factions_Normal")

            local btnRename = styledButton(row, "✎", THEME.accent, THEME.accentDark)
            btnRename:SetPos(240, 5) btnRename:SetSize(36, 26)
            btnRename.DoClick = function()
                local newName = edit:GetText()
                if newName == "" or newName == deptName then return end
                sendAction("renameDepartment", { factionName, deptName, newName }, function(ok, msg)
                    if ok then notification.AddLegacy("Отдел переименован", NOTIFY_GENERIC, 3) refreshAllUI()
                    else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) edit:SetText(deptName) end
                end)
            end

            if #departments > 1 then
                local btnRemove = styledButton(row, "✕", THEME.danger, THEME.dangerHover)
                btnRemove:SetPos(282, 5) btnRemove:SetSize(36, 26)
                btnRemove.DoClick = function()
                    sendAction("removeDepartment", { factionName, deptName }, function(ok, msg)
                        if ok then notification.AddLegacy("Отдел удалён", NOTIFY_GENERIC, 3) refreshAllUI()
                        else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
                    end)
                end
            end
        end

        local addPanel = vgui.Create("DPanel", scroll)
        addPanel:SetTall(40) addPanel:Dock(TOP) addPanel:DockMargin(0, 5, 0, 0) addPanel:SetPaintBackground(false)

        local lbl = vgui.Create("DLabel", addPanel)
        lbl:SetText("Новый отдел:") lbl:SetPos(10, 10) lbl:SetSize(80, 20) lbl:SetFont("Factions_Normal")
        lbl:SetTextColor(THEME.text)

        local newEntry = vgui.Create("DTextEntry", addPanel)
        newEntry:SetPos(100, 7) newEntry:SetSize(160, 26) newEntry:SetFont("Factions_Normal")

        local btnAdd = styledButton(addPanel, "+ Добавить", THEME.success, Color(40, 160, 80))
        btnAdd:SetPos(270, 7) btnAdd:SetSize(100, 26)
        btnAdd.DoClick = function()
            local newDept = newEntry:GetText()
            if newDept == "" then return end
            sendAction("addDepartment", { factionName, newDept }, function(ok, msg)
                if ok then notification.AddLegacy("Отдел добавлен", NOTIFY_GENERIC, 3) refreshAllUI() newEntry:SetText("")
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end
    end

    -- ============================================================
    -- АДМИНКА: СПИСОК УЧАСТНИКОВ ФРАКЦИИ (FIX: lblDept:SetSize)
    -- ============================================================
    function updateMemberListForFaction(factionName, data)
        if not IsValid(ui.memberScroll) then return end
        local scroll = ui.memberScroll
        scroll:Clear()
        if not factionName or not data or not data[factionName] then return end

        local f = data[factionName]
        local members = f.Members or {}
        local roles = f.Roles or {}
        local sorted = {}
        for steam, info in pairs(members) do sorted[#sorted + 1] = { steam = steam, info = info } end
        table.sort(sorted, function(a, b)
            if a.steam == f.Leader then return true end
            if b.steam == f.Leader then return false end
            return (a.info.Role or "") < (b.info.Role or "")
        end)

        for _, item in ipairs(sorted) do
            local steam = item.steam
            local info  = item.info

            local row = vgui.Create("DPanel", scroll)
            row:SetTall(32) row:Dock(TOP) row:DockMargin(0, 1, 0, 1)
            function row:Paint(w, h)
                if steam == f.Leader then
                    surface.SetDrawColor(255, 220, 80, 20)
                    surface.DrawRect(0, 0, w, h)
                end
            end

            local lblSteam = vgui.Create("DLabel", row)
            lblSteam:SetPos(8, 6) lblSteam:SetSize(220, 20) lblSteam:SetText(steam)
            lblSteam:SetFont("Factions_Normal")
            if steam == f.Leader then lblSteam:SetTextColor(Color(255, 220, 80)) end

            local lblRole = vgui.Create("DLabel", row)
            lblRole:SetPos(240, 6) lblRole:SetSize(130, 20) lblRole:SetText(info.Role or "Участник")
            lblRole:SetFont("Factions_Normal") lblRole:SetTextColor(THEME.accent)

            -- FIX: было lblRole:SetSize вместо lblDept:SetSize
            local lblDept = vgui.Create("DLabel", row)
            lblDept:SetPos(380, 6) lblDept:SetSize(130, 20) lblDept:SetText(info.Department or "Основной")
            lblDept:SetFont("Factions_Normal") lblDept:SetTextColor(THEME.textDim)

            getPlayerName(steam, function(name)
                if IsValid(lblSteam) then lblSteam:SetText(name .. " (" .. steam .. ")") end
            end)
        end
    end

    -- ============================================================
    -- ВОЛНА ДЕПАРТАМЕНТА: ПАНЕЛЬ АДМИНКИ
    -- ============================================================
    function updateDepWavePanel(data)
        if not IsValid(ui.depWaveScroll) then return end
        local scroll = ui.depWaveScroll
        scroll:Clear()

        data = data or FactionsData

        local hdr = vgui.Create("DPanel", scroll)
        hdr:Dock(TOP) hdr:SetTall(50) hdr:SetPaintBackground(false)

        local infoLbl = vgui.Create("DLabel", hdr)
        infoLbl:Dock(FILL) infoLbl:DockMargin(5, 5, 5, 5) infoLbl:SetWrap(true)
        infoLbl:SetText("Отметьте фракции, которым разрешено использовать команды:\n/dep — РП чат | /depb (/db) — OOC чат")
        infoLbl:SetFont("Factions_Normal")
        infoLbl:SetTextColor(THEME.text)

        local sortedNames = {}
        for name, _ in pairs(data or {}) do sortedNames[#sortedNames + 1] = name end
        table.sort(sortedNames)

        for _, factionName in ipairs(sortedNames) do
            local f = data[factionName]
            if not f then continue end

            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP) row:SetTall(44) row:DockMargin(0, 2, 0, 2)

            local fCol = f.Color or { r = 60, g = 60, b = 60 }
            function row:Paint(w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(fCol.r * 0.15, fCol.g * 0.15, fCol.b * 0.15, 200))
                surface.SetDrawColor(fCol.r, fCol.g, fCol.b, 180)
                surface.DrawRect(0, 0, 4, h)
            end

            local tagStr = (f.Tag and f.Tag ~= "") and ("[" .. f.Tag .. "] ") or ""
            local nameLbl = vgui.Create("DLabel", row)
            nameLbl:SetPos(14, 12) nameLbl:SetSize(300, 20)
            nameLbl:SetText(tagStr .. factionName)
            nameLbl:SetTextColor(Color(fCol.r, fCol.g, fCol.b))
            nameLbl:SetFont("Factions_Normal")

            local chkDep = vgui.Create("DCheckBoxLabel", row)
            chkDep:SetPos(360, 12) chkDep:SetSize(250, 20)
            chkDep:SetText("Доступ к волне (/dep, /depb)")
            chkDep:SetFont("Factions_Normal")
            chkDep:SetValue(f.DepAccess and true or false)
            chkDep.OnChange = function(_, val)
                sendAction("setDepAccess", { factionName, tobool(val) }, function(ok, msg)
                    if ok then notification.AddLegacy("Настройка обновлена", NOTIFY_GENERIC, 3) refreshAllUI()
                    else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) chkDep:SetValue(not tobool(val)) end
                end)
            end
        end
    end

    -- ============================================================
    -- ОСНОВНОЕ МЕНЮ АДМИНА (FIX: запрос данных при открытии)
    -- ============================================================
    function OpenAdminMenu()
        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:SetSize(1280, 860) frame:Center() frame:MakePopup()
        ui.currentFrame = frame

        function frame:Paint(w, h)
            draw.RoundedBox(6, 0, 0, w, h, THEME.bg)
            draw.RoundedBoxEx(6, 0, 0, w, 32, Color(35, 35, 45), true, true, false, false)
            draw.SimpleText("Управление фракциями", "Factions_Title", 12, 16, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local tabs = vgui.Create("DPropertySheet", frame)
        tabs:Dock(FILL) tabs:DockMargin(4, 36, 4, 4)
        function tabs:Paint(w, h)
            surface.SetDrawColor(THEME.bgLight)
            surface.DrawRect(0, 0, w, h)
        end

        -- Фракции
        local factionList = vgui.Create("DPanel")
        factionList:SetPaintBackground(false)
        local listView = vgui.Create("DListView", factionList)
        listView:Dock(FILL)
        listView:AddColumn("Название") listView:AddColumn("Лидер") listView:AddColumn("Участников")
        ui.listView = listView

        local btnRefresh = styledButton(factionList, "↻ Обновить", THEME.accent, THEME.accentDark)
        btnRefresh:Dock(BOTTOM) btnRefresh:SetTall(32)
        btnRefresh.DoClick = function()
            getData(function(data)
                FactionsData = data or {}
                refreshAllUI(FactionsData)
            end)
        end
        tabs:AddSheet("Фракции", factionList, "icon16/group.png")

        -- Создание
        local createPanel = vgui.Create("DPanel")
        createPanel:SetPaintBackground(false) createPanel:DockPadding(15, 15, 15, 15)

        sectionPanel(createPanel, "Создание новой фракции")

        local lblName = vgui.Create("DLabel", createPanel)
        lblName:SetText("Название фракции:") lblName:SetPos(15, 55) lblName:SetSize(160, 20)
        lblName:SetFont("Factions_Normal") lblName:SetTextColor(THEME.text)

        local nameEntry = vgui.Create("DTextEntry", createPanel)
        nameEntry:SetPos(185, 52) nameEntry:SetSize(240, 26) nameEntry:SetFont("Factions_Normal")

        local lblLeader = vgui.Create("DLabel", createPanel)
        lblLeader:SetText("SteamID лидера (опционально):") lblLeader:SetPos(15, 90) lblLeader:SetSize(220, 20)
        lblLeader:SetFont("Factions_Normal") lblLeader:SetTextColor(THEME.text)

        local leaderEntry = vgui.Create("DTextEntry", createPanel)
        leaderEntry:SetPos(245, 87) leaderEntry:SetSize(260, 26) leaderEntry:SetFont("Factions_Normal")

        local btnCreate = styledButton(createPanel, "+ Создать фракцию", THEME.success, Color(40, 160, 80))
        btnCreate:SetPos(15, 130) btnCreate:SetSize(180, 32)
        btnCreate.DoClick = function()
            local name = nameEntry:GetText()
            if name == "" then notification.AddLegacy("Введите название", NOTIFY_ERROR, 3) return end
            local leader = leaderEntry:GetText()
            if leader == "" then leader = nil end
            sendAction("createFaction", { name, leader }, function(ok, msg)
                if ok then notification.AddLegacy("Фракция создана", NOTIFY_GENERIC, 3) refreshAllUI() nameEntry:SetText("") leaderEntry:SetText("")
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end
        tabs:AddSheet("Создать", createPanel, "icon16/add.png")

        -- Редактирование
        local editPanel = vgui.Create("DPanel")
        editPanel:SetPaintBackground(false) editPanel:DockPadding(15, 15, 15, 15)
        local Y = 15

        -- Выбор фракции
        local lblFaction = vgui.Create("DLabel", editPanel)
        lblFaction:SetText("Фракция:") lblFaction:SetPos(15, Y + 3) lblFaction:SetSize(80, 20)
        lblFaction:SetFont("Factions_Normal") lblFaction:SetTextColor(THEME.text)

        local factionCombo = vgui.Create("DComboBox", editPanel)
        factionCombo:SetPos(100, Y) factionCombo:SetSize(260, 26)
        ui.factionCombo = factionCombo
        Y = Y + 40

        -- Кнопки: Удалить, Сменить лидера
        local btnDelete = styledButton(editPanel, "✕ Удалить фракцию", THEME.danger, THEME.dangerHover)
        btnDelete:SetPos(15, Y) btnDelete:SetSize(160, 30)
        btnDelete.DoClick = function()
            local faction = factionCombo:GetValue()
            if not faction or faction == "" then return end
            sendAction("deleteFaction", { faction }, function(ok, msg)
                if ok then notification.AddLegacy("Фракция удалена", NOTIFY_GENERIC, 3) refreshAllUI()
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end

        local btnChangeLeader = styledButton(editPanel, "★ Сменить лидера", THEME.accent, THEME.accentDark)
        btnChangeLeader:SetPos(190, Y) btnChangeLeader:SetSize(160, 30)
        btnChangeLeader.DoClick = function()
            local faction = factionCombo:GetValue()
            if not faction or faction == "" then return end
            Derma_StringRequest("Смена лидера", "SteamID нового лидера:", "", function(steam)
                if steam and steam ~= "" then
                    sendAction("changeLeader", { faction, steam }, function(ok, msg)
                        if ok then notification.AddLegacy("Лидер изменён", NOTIFY_GENERIC, 3) refreshAllUI()
                        else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
                    end)
                end
            end)
        end
        Y = Y + 50

        -- Переименование фракции
        local lblRename = vgui.Create("DLabel", editPanel)
        lblRename:SetText("Новое название:") lblRename:SetPos(15, Y + 3) lblRename:SetSize(110, 20)
        lblRename:SetFont("Factions_Normal") lblRename:SetTextColor(THEME.text)

        local renameEntry = vgui.Create("DTextEntry", editPanel)
        renameEntry:SetPos(130, Y) renameEntry:SetSize(200, 26) renameEntry:SetFont("Factions_Normal")
        renameEntry:SetPlaceholderText("Новое название")

        local btnRename = styledButton(editPanel, "✎ Переименовать", THEME.accent, THEME.accentDark)
        btnRename:SetPos(340, Y) btnRename:SetSize(140, 26)
        btnRename.DoClick = function()
            local faction = factionCombo:GetValue()
            local newName = renameEntry:GetText()
            if not faction or faction == "" or newName == "" then return end
            sendAction("renameFaction", { faction, newName }, function(ok, msg)
                if ok then notification.AddLegacy("Фракция переименована", NOTIFY_GENERIC, 3) refreshAllUI() renameEntry:SetText("")
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end
        Y = Y + 50

        -- Тег фракции
        local lblTagSection = vgui.Create("DLabel", editPanel)
        lblTagSection:SetText("Тег фракции (до 5 символов):") lblTagSection:SetPos(15, Y) lblTagSection:SetSize(200, 20)
        lblTagSection:SetFont("Factions_Normal") lblTagSection:SetTextColor(THEME.textDim)
        Y = Y + 28

        local tagEntry = vgui.Create("DTextEntry", editPanel)
        tagEntry:SetPos(15, Y) tagEntry:SetSize(100, 26) tagEntry:SetPlaceholderText("до 5")
        tagEntry:SetFont("Factions_Normal")
        ui.editTagEntry = tagEntry
        tagEntry.OnChange = function()
            local t = tagEntry:GetText()
            if #t > 5 then tagEntry:SetText(string.sub(t, 1, 5)) tagEntry:SetCaretPos(5) end
        end

        local btnSaveTag = styledButton(editPanel, "Сохранить тег", THEME.accent, THEME.accentDark)
        btnSaveTag:SetPos(125, Y) btnSaveTag:SetSize(120, 26)
        btnSaveTag.DoClick = function()
            local faction = factionCombo:GetValue()
            if not faction or faction == "" then return end
            sendAction("setTag", { faction, tagEntry:GetText() }, function(ok, msg)
                if ok then notification.AddLegacy("Тег сохранён", NOTIFY_GENERIC, 3) refreshAllUI()
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end
        Y = Y + 50

        -- Цвет фракции
        local lblColorSection = vgui.Create("DLabel", editPanel)
        lblColorSection:SetText("Цвет фракции:") lblColorSection:SetPos(15, Y) lblColorSection:SetSize(200, 20)
        lblColorSection:SetFont("Factions_Normal") lblColorSection:SetTextColor(THEME.textDim)
        Y = Y + 28

        ui._editColorR = 255
        ui._editColorG = 200
        ui._editColorB = 50

        local colorPreview = vgui.Create("DPanel", editPanel)
        colorPreview:SetPos(380, Y) colorPreview:SetSize(100, 80)
        function colorPreview:Paint(w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(ui._editColorR or 255, ui._editColorG or 200, ui._editColorB or 50, 255))
            surface.SetDrawColor(THEME.border)
            surface.DrawOutlinedRect(0, 0, w, h)
        end
        ui.editColorPreview = colorPreview

        local function createColorSlider(parent, label, posY, initVal, onChangeFunc)
            local lbl = vgui.Create("DLabel", parent)
            lbl:SetPos(15, posY + 3) lbl:SetSize(20, 20) lbl:SetText(label)
            lbl:SetFont("Factions_Normal") lbl:SetTextColor(THEME.text)
            local slider = vgui.Create("DNumSlider", parent)
            slider:SetPos(40, posY) slider:SetSize(300, 25)
            slider:SetMin(0) slider:SetMax(255) slider:SetDecimals(0) slider:SetValue(initVal)
            slider.OnValueChanged = function(_, val) onChangeFunc(math.floor(val)) end
            return slider
        end

        local sliderR = createColorSlider(editPanel, "R", Y, 255, function(v) ui._editColorR = v end)
        local sliderG = createColorSlider(editPanel, "G", Y + 28, 200, function(v) ui._editColorG = v end)
        local sliderB = createColorSlider(editPanel, "B", Y + 56, 50, function(v) ui._editColorB = v end)
        Y = Y + 90

        local btnSaveColor = styledButton(editPanel, "Сохранить цвет", THEME.accent, THEME.accentDark)
        btnSaveColor:SetPos(15, Y) btnSaveColor:SetSize(150, 30)
        btnSaveColor.DoClick = function()
            local faction = factionCombo:GetValue()
            if not faction or faction == "" then return end
            sendAction("setColor", { faction, ui._editColorR, ui._editColorG, ui._editColorB }, function(ok, msg)
                if ok then notification.AddLegacy("Цвет сохранён", NOTIFY_GENERIC, 3) refreshAllUI()
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end

        factionCombo.OnSelect = function(_, _, faction)
            getData(function(data)
                if not data or not data[faction] then return end
                local f = data[faction]
                if IsValid(tagEntry) then tagEntry:SetText(f.Tag or "") end
                if IsValid(renameEntry) then renameEntry:SetText("") end
                local col = f.Color or { r = 255, g = 200, b = 50 }
                ui._editColorR = col.r ui._editColorG = col.g ui._editColorB = col.b
                if IsValid(sliderR) then sliderR:SetValue(col.r) end
                if IsValid(sliderG) then sliderG:SetValue(col.g) end
                if IsValid(sliderB) then sliderB:SetValue(col.b) end
            end)
        end
        tabs:AddSheet("Редактировать", editPanel, "icon16/pencil.png")

        -- Ранги
        local ranksPanel = vgui.Create("DPanel")
        ranksPanel:SetPaintBackground(false) ranksPanel:DockPadding(10, 10, 10, 10)

        local lblR = vgui.Create("DLabel", ranksPanel)
        lblR:SetText("Фракция:") lblR:SetPos(10, 10) lblR:SetSize(80, 20)
        lblR:SetFont("Factions_Normal") lblR:SetTextColor(THEME.text)

        local factionComboRanks = vgui.Create("DComboBox", ranksPanel)
        factionComboRanks:SetPos(100, 7) factionComboRanks:SetSize(240, 26)
        ui.factionComboRanks = factionComboRanks

        local ranksScroll = vgui.Create("DScrollPanel", ranksPanel)
        ranksScroll:SetPos(10, 42) ranksScroll:SetSize(1230, 720)
        ui.ranksScroll = ranksScroll

        factionComboRanks.OnSelect = function(_, _, factionName)
            getData(function(data) updateRanksList(factionName, data) end)
        end
        tabs:AddSheet("Ранги", ranksPanel, "icon16/user.png")

        -- Отделы
        local deptsPanel = vgui.Create("DPanel")
        deptsPanel:SetPaintBackground(false) deptsPanel:DockPadding(10, 10, 10, 10)

        local lblD = vgui.Create("DLabel", deptsPanel)
        lblD:SetText("Фракция:") lblD:SetPos(10, 10) lblD:SetSize(80, 20)
        lblD:SetFont("Factions_Normal") lblD:SetTextColor(THEME.text)

        local factionComboDepts = vgui.Create("DComboBox", deptsPanel)
        factionComboDepts:SetPos(100, 7) factionComboDepts:SetSize(240, 26)
        ui.factionComboDepts = factionComboDepts

        local deptsScroll = vgui.Create("DScrollPanel", deptsPanel)
        deptsScroll:SetPos(10, 42) deptsScroll:SetSize(1230, 720)
        ui.deptsScroll = deptsScroll

        factionComboDepts.OnSelect = function(_, _, factionName)
            getData(function(data) updateDepartmentsList(factionName, data) end)
        end
        tabs:AddSheet("Отделы", deptsPanel, "icon16/brick.png")

        -- Участники (быстро)
        local memberPanel = vgui.Create("DPanel")
        memberPanel:SetPaintBackground(false) memberPanel:DockPadding(15, 10, 15, 10)
        local Y = 10

        local lblF3 = vgui.Create("DLabel", memberPanel)
        lblF3:SetText("Фракция:") lblF3:SetPos(15, Y + 3) lblF3:SetSize(80, 20)
        lblF3:SetFont("Factions_Normal") lblF3:SetTextColor(THEME.text)

        local factionCombo3 = vgui.Create("DComboBox", memberPanel)
        factionCombo3:SetPos(100, Y) factionCombo3:SetSize(240, 26)
        ui.factionCombo3 = factionCombo3
        Y = Y + 40

        local lblTarget = vgui.Create("DLabel", memberPanel)
        lblTarget:SetText("SteamID:") lblTarget:SetPos(15, Y + 3) lblTarget:SetSize(80, 20)
        lblTarget:SetFont("Factions_Normal") lblTarget:SetTextColor(THEME.text)

        local targetEntry = vgui.Create("DTextEntry", memberPanel)
        targetEntry:SetPos(100, Y) targetEntry:SetSize(260, 26) targetEntry:SetFont("Factions_Normal")
        Y = Y + 40

        local lblRoleM = vgui.Create("DLabel", memberPanel)
        lblRoleM:SetText("Роль:") lblRoleM:SetPos(15, Y + 3) lblRoleM:SetSize(80, 20)
        lblRoleM:SetFont("Factions_Normal") lblRoleM:SetTextColor(THEME.text)

        local roleCombo = vgui.Create("DComboBox", memberPanel)
        roleCombo:SetPos(100, Y) roleCombo:SetSize(200, 26)
        Y = Y + 40

        local lblDeptM = vgui.Create("DLabel", memberPanel)
        lblDeptM:SetText("Отдел:") lblDeptM:SetPos(15, Y + 3) lblDeptM:SetSize(80, 20)
        lblDeptM:SetFont("Factions_Normal") lblDeptM:SetTextColor(THEME.text)

        local deptCombo = vgui.Create("DComboBox", memberPanel)
        deptCombo:SetPos(100, Y) deptCombo:SetSize(200, 26)
        Y = Y + 45

        factionCombo3.OnSelect = function(_, _, value)
            getData(function(data)
                local f = data[value]
                if f then
                    roleCombo:Clear() deptCombo:Clear()
                    for _, role in ipairs(f.Roles or {}) do roleCombo:AddChoice(role) end
                    for _, dept in ipairs(f.Departments or {}) do deptCombo:AddChoice(dept) end
                end
            end)
        end

        local btnInvite = styledButton(memberPanel, "✉ Пригласить", THEME.accent, THEME.accentDark)
        btnInvite:SetPos(15, Y) btnInvite:SetSize(130, 30)
        btnInvite.DoClick = function()
            local faction = factionCombo3:GetValue()
            local steam   = targetEntry:GetText()
            if not faction or faction == "" or steam == "" then return end
            sendAction("inviteMember", { faction, steam }, function(ok, msg)
                if ok then notification.AddLegacy("Приглашение отправлено", NOTIFY_GENERIC, 3)
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end

        local btnRemoveMember = styledButton(memberPanel, "✕ Удалить", THEME.danger, THEME.dangerHover)
        btnRemoveMember:SetPos(155, Y) btnRemoveMember:SetSize(110, 30)
        btnRemoveMember.DoClick = function()
            local faction = factionCombo3:GetValue()
            local steam   = targetEntry:GetText()
            if not faction or faction == "" or steam == "" then return end
            sendAction("removeMember", { faction, steam }, function(ok, msg)
                if ok then notification.AddLegacy("Удалён", NOTIFY_GENERIC, 3) refreshAllUI()
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end
        Y = Y + 40

        local btnSetRole = styledButton(memberPanel, "★ Назначить роль", THEME.accent, THEME.accentDark)
        btnSetRole:SetPos(15, Y) btnSetRole:SetSize(150, 30)
        btnSetRole.DoClick = function()
            local faction = factionCombo3:GetValue()
            local steam   = targetEntry:GetText()
            local role    = roleCombo:GetValue()
            if not faction or faction == "" or steam == "" or not role then return end
            sendAction("setRole", { faction, steam, role }, function(ok, msg)
                if ok then notification.AddLegacy("Роль назначена", NOTIFY_GENERIC, 3) refreshAllUI()
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end

        local btnSetDept = styledButton(memberPanel, "⬚ Назначить отдел", THEME.accent, THEME.accentDark)
        btnSetDept:SetPos(175, Y) btnSetDept:SetSize(160, 30)
        btnSetDept.DoClick = function()
            local faction = factionCombo3:GetValue()
            local steam   = targetEntry:GetText()
            local dept    = deptCombo:GetValue()
            if not faction or faction == "" or steam == "" or not dept then return end
            sendAction("setDepartment", { faction, steam, dept }, function(ok, msg)
                if ok then notification.AddLegacy("Отдел назначен", NOTIFY_GENERIC, 3) refreshAllUI()
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end
        tabs:AddSheet("Участники", memberPanel, "icon16/user_edit.png")

        -- Список участников
        local memberListPanel = vgui.Create("DPanel")
        memberListPanel:SetPaintBackground(false) memberListPanel:DockPadding(10, 10, 10, 10)

        local lblFL = vgui.Create("DLabel", memberListPanel)
        lblFL:SetText("Фракция:") lblFL:SetPos(10, 10) lblFL:SetSize(80, 20)
        lblFL:SetFont("Factions_Normal") lblFL:SetTextColor(THEME.text)

        local factionComboList = vgui.Create("DComboBox", memberListPanel)
        factionComboList:SetPos(100, 7) factionComboList:SetSize(240, 26)
        ui.factionComboList = factionComboList

        local scrollPanel = vgui.Create("DScrollPanel", memberListPanel)
        scrollPanel:SetPos(10, 42) scrollPanel:SetSize(1230, 720)
        ui.memberScroll = scrollPanel

        factionComboList.OnSelect = function(_, _, factionName)
            getData(function(data) updateMemberListForFaction(factionName, data) end)
        end
        tabs:AddSheet("Список", memberListPanel, "icon16/user_go.png")

        -- Волна департамента
        local depWavePanel = vgui.Create("DPanel")
        depWavePanel:SetPaintBackground(false) depWavePanel:DockPadding(10, 10, 10, 10)
        local depWaveScroll = vgui.Create("DScrollPanel", depWavePanel)
        depWaveScroll:Dock(FILL)
        ui.depWaveScroll = depWaveScroll
        tabs:AddSheet("Волна департамента", depWavePanel, "icon16/transmit.png")

        -- FIX: При открытии меню запрашиваем данные с сервера (factions.json)
        timer.Simple(0.4, function()
            if IsValid(frame) then
                getData(function(data)
                    FactionsData = data or {}
                    refreshAllUI(FactionsData)
                end)
            end
        end)

        frame.OnClose = function()
            ui.currentFrame = nil
            ui.depWaveScroll = nil
            ui.editTagEntry = nil
            ui.editColorPreview = nil
        end

        frame:Show()
    end

    -- ============================================================
    -- МЕНЮ ЛИДЕРА (FIX: запрос данных при открытии)
    -- ============================================================
    function OpenLeaderMenu()
        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:SetSize(1280, 860) frame:Center() frame:MakePopup()
        ui.leaderMenuOpen = true
        ui.currentFrame   = frame

        function frame:Paint(w, h)
            draw.RoundedBox(6, 0, 0, w, h, THEME.bg)
            draw.RoundedBoxEx(6, 0, 0, w, 32, Color(35, 35, 45), true, true, false, false)
            draw.SimpleText("Управление фракцией", "Factions_Title", 12, 16, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local tabs = vgui.Create("DPropertySheet", frame)
        tabs:Dock(FILL) tabs:DockMargin(4, 36, 4, 4)
        function tabs:Paint(w, h)
            surface.SetDrawColor(THEME.bgLight)
            surface.DrawRect(0, 0, w, h)
        end

        -- Ранги
        local ranksPanel = vgui.Create("DPanel")
        ranksPanel:SetPaintBackground(false) ranksPanel:DockPadding(10, 10, 10, 10)
        local ranksScroll = vgui.Create("DScrollPanel", ranksPanel)
        ranksScroll:SetPos(10, 10) ranksScroll:SetSize(1230, 750)
        ui.ranksScrollLeader = ranksScroll
        tabs:AddSheet("Ранги", ranksPanel, "icon16/user.png")

        -- Отделы
        local deptsPanel = vgui.Create("DPanel")
        deptsPanel:SetPaintBackground(false) deptsPanel:DockPadding(10, 10, 10, 10)
        local deptsScroll = vgui.Create("DScrollPanel", deptsPanel)
        deptsScroll:SetPos(10, 10) deptsScroll:SetSize(1230, 750)
        ui.deptsScrollLeader = deptsScroll
        tabs:AddSheet("Отделы", deptsPanel, "icon16/brick.png")

        -- Участники
        local memberPanel = vgui.Create("DPanel")
        memberPanel:SetPaintBackground(false) memberPanel:DockPadding(15, 10, 15, 10)
        local Y = 10

        local lblTarget = vgui.Create("DLabel", memberPanel)
        lblTarget:SetText("SteamID:") lblTarget:SetPos(15, Y + 3) lblTarget:SetSize(80, 20)
        lblTarget:SetFont("Factions_Normal") lblTarget:SetTextColor(THEME.text)

        local targetEntry = vgui.Create("DTextEntry", memberPanel)
        targetEntry:SetPos(100, Y) targetEntry:SetSize(260, 26) targetEntry:SetFont("Factions_Normal")
        Y = Y + 40

        local lblRoleL = vgui.Create("DLabel", memberPanel)
        lblRoleL:SetText("Роль:") lblRoleL:SetPos(15, Y + 3) lblRoleL:SetSize(80, 20)
        lblRoleL:SetFont("Factions_Normal") lblRoleL:SetTextColor(THEME.text)

        local roleCombo = vgui.Create("DComboBox", memberPanel)
        roleCombo:SetPos(100, Y) roleCombo:SetSize(200, 26)
        Y = Y + 40

        local lblDeptL = vgui.Create("DLabel", memberPanel)
        lblDeptL:SetText("Отдел:") lblDeptL:SetPos(15, Y + 3) lblDeptL:SetSize(80, 20)
        lblDeptL:SetFont("Factions_Normal") lblDeptL:SetTextColor(THEME.text)

        local deptCombo = vgui.Create("DComboBox", memberPanel)
        deptCombo:SetPos(100, Y) deptCombo:SetSize(200, 26)
        Y = Y + 45

        getData(function(data)
            local mySteam = LocalPlayer():SteamID()
            for _, f in pairs(data) do
                if f.Leader == mySteam then
                    for _, role in ipairs(f.Roles or {}) do roleCombo:AddChoice(role) end
                    for _, dept in ipairs(f.Departments or {}) do deptCombo:AddChoice(dept) end
                    break
                end
            end
        end)

        local btnInvite = styledButton(memberPanel, "✉ Пригласить", THEME.accent, THEME.accentDark)
        btnInvite:SetPos(15, Y) btnInvite:SetSize(130, 30)
        btnInvite.DoClick = function()
            local steam = targetEntry:GetText()
            if steam == "" then return end
            sendAction("inviteMember", { steam }, function(ok, msg)
                if ok then notification.AddLegacy("Приглашение отправлено", NOTIFY_GENERIC, 3)
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end

        local btnRemoveMember = styledButton(memberPanel, "✕ Уволить", THEME.danger, THEME.dangerHover)
        btnRemoveMember:SetPos(155, Y) btnRemoveMember:SetSize(110, 30)
        btnRemoveMember.DoClick = function()
            local steam = targetEntry:GetText()
            if steam == "" then return end
            sendAction("removeMember", { steam }, function(ok, msg)
                if ok then notification.AddLegacy("Уволен", NOTIFY_GENERIC, 3) refreshAllUI()
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end
        Y = Y + 40

        local btnSetRole = styledButton(memberPanel, "★ Назначить роль", THEME.accent, THEME.accentDark)
        btnSetRole:SetPos(15, Y) btnSetRole:SetSize(150, 30)
        btnSetRole.DoClick = function()
            local steam = targetEntry:GetText()
            local role  = roleCombo:GetValue()
            if steam == "" or not role then return end
            sendAction("setRole", { steam, role }, function(ok, msg)
                if ok then notification.AddLegacy("Роль назначена", NOTIFY_GENERIC, 3) refreshAllUI()
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end

        local btnSetDept = styledButton(memberPanel, "⬚ Назначить отдел", THEME.accent, THEME.accentDark)
        btnSetDept:SetPos(175, Y) btnSetDept:SetSize(160, 30)
        btnSetDept.DoClick = function()
            local steam = targetEntry:GetText()
            local dept  = deptCombo:GetValue()
            if steam == "" or not dept then return end
            sendAction("setDepartment", { steam, dept }, function(ok, msg)
                if ok then notification.AddLegacy("Отдел назначен", NOTIFY_GENERIC, 3) refreshAllUI()
                else notification.AddLegacy("Ошибка: " .. msg, NOTIFY_ERROR, 3) end
            end)
        end
        tabs:AddSheet("Участники", memberPanel, "icon16/user_edit.png")

        -- Список участников
        local memberListPanel = vgui.Create("DPanel")
        memberListPanel:SetPaintBackground(false) memberListPanel:DockPadding(10, 10, 10, 10)

        local titleLabel = vgui.Create("DLabel", memberListPanel)
        titleLabel:SetPos(10, 10) titleLabel:SetSize(400, 20)
        titleLabel:SetFont("Factions_Title") titleLabel:SetTextColor(THEME.accent)
        ui.leaderTitleLabel = titleLabel

        local scrollPanel = vgui.Create("DScrollPanel", memberListPanel)
        scrollPanel:SetPos(10, 40) scrollPanel:SetSize(1230, 720)
        ui.memberScrollLeader = scrollPanel
        tabs:AddSheet("Список участников", memberListPanel, "icon16/user_go.png")

        -- FIX: При открытии меню лидера запрашиваем данные с сервера (factions.json)
        timer.Simple(0.4, function()
            if IsValid(frame) then
                getData(function(data)
                    FactionsData = data or {}
                    refreshAllUI(FactionsData)
                end)
            end
        end)

        frame.OnClose = function()
            ui.leaderMenuOpen = false
            ui.currentFrame = nil
            ui.ranksScrollLeader = nil
            ui.deptsScrollLeader = nil
            ui.memberScrollLeader = nil
            ui.leaderTitleLabel = nil
        end

        frame:Show()
    end

    -- ============================================================
    -- КОМАНДЫ ЧАТА (клиентские)
    -- ============================================================
    hook.Add("PlayerSayTransform", "Factions_PlayerCommands", function(ply, datapack, is_team, is_local)
        if ply ~= LocalPlayer() then return end
        local msg = datapack[1]
        if not msg then return end
        local lower = msg:lower()

        if lower:find("^/fjoin") == 1 then
            local factionName = msg:sub(7):Trim()
            net.Start(NET_JOIN) net.WriteString(factionName) net.SendToServer()
            datapack[1] = "" return
        end
        if lower:find("^/fdecline%s+") == 1 then
            local factionName = msg:sub(10):Trim()
            if factionName == "" then datapack[1] = "" return end
            net.Start(NET_DECLINE) net.WriteString(factionName) net.SendToServer()
            datapack[1] = "" return
        end
        if lower:find("^/fleave%s*") == 1 then
            net.Start(NET_LEAVE) net.SendToServer()
            datapack[1] = "" return
        end
        if lower:find("^/fr%s+") == 1 then
            local text = msg:sub(4)
            if text == "" then datapack[1] = "" return end
            net.Start(NET_RADIO) net.WriteString(text) net.SendToServer()
            datapack[1] = "" return
        end
        if lower:find("^/dep%s+") == 1 or lower:find("^/d%s+") == 1 then
            local offset = (lower:find("^/dep%s+") == 1) and 6 or 3
            local text = msg:sub(offset):Trim()
            if text == "" then datapack[1] = "" return end
            net.Start(NET_DEP) net.WriteString(text) net.SendToServer()
            datapack[1] = "" return
        end
        if lower:find("^/depb%s+") == 1 then
            local text = msg:sub(7):Trim()
            if text == "" then datapack[1] = "" return end
            net.Start(NET_DEPB) net.WriteString(text) net.SendToServer()
            datapack[1] = "" return
        end
        if lower:find("^/db%s+") == 1 then
            local text = msg:sub(4):Trim()
            if text == "" then datapack[1] = "" return end
            net.Start(NET_DEPB) net.WriteString(text) net.SendToServer()
            datapack[1] = "" return
        end
    end)

    -- ============================================================
    -- КОНСОЛЬНЫЕ КОМАНДЫ
    -- ============================================================
    concommand.Add("factions", function()
        if LocalPlayer():IsSuperAdmin() then OpenAdminMenu() return end

        getData(function(data)
            local mySteam = LocalPlayer():SteamID()
            for _, f in pairs(data or {}) do
                if f.Leader == mySteam then OpenLeaderMenu() return end
            end
            notification.AddLegacy("У вас нет прав", NOTIFY_ERROR, 3)
        end)
    end)

    -- ============================================================
    -- HUD — НАДПИСИ НАД ИГРОКАМИ
    -- ============================================================
    hook.Add("HUDPaint", "Factions_HUD", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        local radius = GetConVarNumber("rpdesc_radius") or 5000

        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) or not ply:Alive() or ply == lp then continue end
            if lp:GetPos():Distance(ply:GetPos()) > radius then continue end

            local steam = ply:SteamID()
            local faction, role = nil, nil
            local fColor = Color(255, 200, 50)
            local fTag = ""

            for fname, fdata in pairs(FactionsData or {}) do
                if fdata.Members and fdata.Members[steam] then
                    faction = fname
                    role = fdata.Members[steam].Role
                    if fdata.Color then fColor = Color(fdata.Color.r or 255, fdata.Color.g or 200, fdata.Color.b or 50) end
                    fTag = (fdata.Tag and fdata.Tag ~= "") and fdata.Tag or ""
                    break
                end
            end
            if not faction then continue end

            local pos = ply:GetPos() + Vector(0, 0, 100)
            local screenPos = pos:ToScreen()
            if not screenPos.visible then continue end
            local x, y = screenPos.x, screenPos.y

            local displayFaction = (fTag ~= "") and ("[" .. fTag .. "] " .. faction) or faction
            local text = displayFaction .. (role and (" [" .. role .. "]") or "")

            surface.SetFont("Factions_HUD")
            local tw, th = surface.GetTextSize(text)
            local padding = 8
            local w = tw + padding * 2
            local h = th + padding * 2

            draw.RoundedBox(4, x - w / 2, y - h / 2, w, h, Color(15, 15, 20, 180))
            surface.SetDrawColor(fColor.r, fColor.g, fColor.b, 220)
            surface.DrawRect(x - w / 2, y + h / 2 - 3, w, 3)
            draw.SimpleText(text, "Factions_HUD", x, y, fColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end)

    net.Receive(NET_OPEN_ADMIN, function() OpenAdminMenu() end)
    net.Receive(NET_OPEN_LEADER, function() OpenLeaderMenu() end)

    print("[Factions] Клиентская часть загружена (v3 fixed + чат-команда /factions)")
end
