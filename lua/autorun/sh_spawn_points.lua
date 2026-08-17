--[[
    СИСТЕМА ТОЧЕК СПАВНА ДЛЯ ФРАКЦИЙ И ГЛОБАЛЬНЫХ

    - Хранение точек для каждой фракции (отдельно для каждой карты)
    - Глобальные точки (отдельно для каждой карты)
    - Админ-меню для управления (добавление, удаление, телепорт)
    - При спавне игрока выбор случайной точки из списка его фракции или глобальной

    ИСПРАВЛЕНИЯ/ДОРАБОТКИ:
    - pos/ang сохраняются как plain-таблицы {x,y,z} / {p,y,r} — переживают JSON-сериализацию
    - SpawnPoints инициализируется автоматически для любых (в т.ч. новых) фракций
    - После добавления/удаления точки сервер сразу присылает свежие данные клиенту
    - Меню обновляется без закрытия и повторного открытия
    - net.Receive("SpawnAdmin_SendData") зарегистрирован на уровне модуля, а не внутри функции
    - Точки сохраняются отдельно для каждой карты (в имени файла добавляется game.GetMap())
--]]

-- ================================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (shared)
-- ================================================================

--- Конвертировать Vector или plain-таблицу в {x, y, z}
local function vecToTable(v)
    if type(v) == "table" then
        return {
            x = tonumber(v.x or v[1]) or 0,
            y = tonumber(v.y or v[2]) or 0,
            z = tonumber(v.z or v[3]) or 0,
        }
    elseif isvector and isvector(v) then
        return { x = v.x, y = v.y, z = v.z }
    end
    return { x = 0, y = 0, z = 0 }
end

--- Конвертировать Angle или plain-таблицу в {p, y, r}
local function angToTable(a)
    if type(a) == "table" then
        return {
            p = tonumber(a.p or a[1]) or 0,
            y = tonumber(a.y or a[2]) or 0,
            r = tonumber(a.r or a[3]) or 0,
        }
    elseif isangle and isangle(a) then
        return { p = a.p, y = a.y, r = a.r }
    end
    return { p = 0, y = 0, r = 0 }
end

--- Восстановить Vector из plain-таблицы
local function tableToVec(t)
    if type(t) ~= "table" then return Vector(0, 0, 0) end
    return Vector(
        tonumber(t.x or t[1]) or 0,
        tonumber(t.y or t[2]) or 0,
        tonumber(t.z or t[3]) or 0
    )
end

--- Восстановить Angle из plain-таблицы
local function tableToAng(t)
    if type(t) ~= "table" then return Angle(0, 0, 0) end
    return Angle(
        tonumber(t.p or t[1]) or 0,
        tonumber(t.y or t[2]) or 0,
        tonumber(t.r or t[3]) or 0
    )
end

if SERVER then

    -- ================================================================
    -- СЕРВЕРНАЯ ЧАСТЬ
    -- ================================================================

    -- Функции получения имён файлов с учётом карты
    local function getGlobalSpawnFile()
        return "spawn_points_global_" .. game.GetMap() .. ".json"
    end

    local function getFactionSpawnFile()
        return "spawn_points_factions_" .. game.GetMap() .. ".json"
    end

    -- Структура точек спавна (ЕДИНЫЙ формат хранения, находка 157):
    -- data.factions = {
    --   [factionName] = {
    --     points = {...},           -- точки фракции (общие)
    --     roles = {
    --       [roleName] = {...},     -- точки конкретной роли
    --     },
    --     departments = {
    --       [deptName] = {...},     -- точки конкретного отдела
    --     }
    --   }
    -- }
    -- Раньше формат был НЕПОСЛЕДОВАТЕЛЬНЫМ: AddSpawnPointForFaction писал
    -- голый массив точек, а role/dept-функции — объект {points,roles,departments}.
    -- Загрузчик при этом присваивал полученное в f.SpawnPoints и НЕ восстанавливал
    -- RoleSpawnPoints/DepartmentSpawnPoints — после рестарта все роли/отделы и
    -- половина точек «пропадали» (класс потери конфигурации).

    -- Чтение JSON только с ignoreConversions=true (находка 65)
    local function jsonT(txt)
        local ok, t = pcall(util.JSONToTable, txt, false, true)
        return (ok and istable(t)) and t or nil
    end

    -- Запись JSON с pcall + read-back (правило проекта: file.Write ничего не
    -- возвращает, контроль — только чтением обратно)
    local function saveJson(path, tbl)
        local ok, raw = pcall(util.TableToJSON, tbl, true)
        if not ok or not isstring(raw) or raw == "" then
            print("[SpawnPoints] ОШИБКА сериализации: " .. path .. " — " .. tostring(raw))
            return false
        end
        file.Write(path, raw)
        local back = file.Exists(path, "DATA") and file.Read(path, "DATA") or ""
        if back ~= raw then
            print("[SpawnPoints] read-back не совпал: " .. path)
            return false
        end
        return true
    end

    --- Убедиться, что у фракции есть таблицы точек (общие/роли/отделы)
    local function ensureFactionSpawnPoints(f)
        if not istable(f.SpawnPoints) then f.SpawnPoints = {} end
        if not istable(f.RoleSpawnPoints) then f.RoleSpawnPoints = {} end
        if not istable(f.DepartmentSpawnPoints) then f.DepartmentSpawnPoints = {} end
    end

    -- Полный bundle фракции: points + roles + departments (единый формат)
    local function factionBundle(f)
        ensureFactionSpawnPoints(f)
        return {
            points = f.SpawnPoints or {},
            roles = f.RoleSpawnPoints or {},
            departments = f.DepartmentSpawnPoints or {},
        }
    end

    -- Сохранить ВСЕ фракционные точки единым форматом
    local function saveAllFactionSpawnPoints()
        local allData = {}
        if Factions then
            for name, f in pairs(Factions) do
                allData[name] = factionBundle(f)
            end
        end
        saveJson(getFactionSpawnFile(), allData)
    end

    -- ----------------------------------------------------------------
    -- 1. Глобальные точки (загрузка/сохранение для текущей карты)
    -- ----------------------------------------------------------------

    local function loadGlobalSpawnPoints()
        local filePath = getGlobalSpawnFile()
        if not file.Exists(filePath, "DATA") then return {} end
        return jsonT(file.Read(filePath, "DATA")) or {}
    end

    local function saveGlobalSpawnPoints(tbl)
        saveJson(getGlobalSpawnFile(), tbl)
    end

    GlobalSpawnPoints = GlobalSpawnPoints or {}

    -- ----------------------------------------------------------------
    -- 2. Точки фракций (загрузка/сохранение для текущей карты)
    -- ----------------------------------------------------------------

    local function loadFactionSpawnPoints()
        local filePath = getFactionSpawnFile()
        if not file.Exists(filePath, "DATA") then return {} end
        return jsonT(file.Read(filePath, "DATA")) or {}
    end

    local function saveFactionSpawnPoints(tbl)
        saveJson(getFactionSpawnFile(), tbl)
    end

    -- ----------------------------------------------------------------
    -- 3. Перезагрузка всех точек для текущей карты
    -- ----------------------------------------------------------------

    local function reloadSpawnPoints()
        -- Загружаем глобальные
        GlobalSpawnPoints = loadGlobalSpawnPoints()
        if not istable(GlobalSpawnPoints) then GlobalSpawnPoints = {} end

        -- Загружаем фракционные (единый формат) и применяем к фракциям
        local loadedData = loadFactionSpawnPoints()
        local needResave = false
        if Factions then
            for factionName, f in pairs(Factions) do
                ensureFactionSpawnPoints(f)
                local entry = loadedData[factionName]
                if istable(entry) then
                    -- МИГРАЦИЯ старого формата: entry — голый массив точек
                    -- (так писал AddSpawnPointForFaction до находки 157).
                    if entry.points == nil and entry.roles == nil and entry.departments == nil then
                        f.SpawnPoints = entry
                        f.RoleSpawnPoints = {}
                        f.DepartmentSpawnPoints = {}
                        needResave = true
                    else
                        f.SpawnPoints = istable(entry.points) and entry.points or {}
                        f.RoleSpawnPoints = istable(entry.roles) and entry.roles or {}
                        f.DepartmentSpawnPoints = istable(entry.departments) and entry.departments or {}
                    end
                else
                    f.SpawnPoints = {}
                    f.RoleSpawnPoints = {}
                    f.DepartmentSpawnPoints = {}
                end
            end
        end
        -- Одноразовая миграция легаси-файла в единый формат
        if needResave then saveAllFactionSpawnPoints() end
    end

    -- ----------------------------------------------------------------
    -- 4. Инициализация при старте и при смене карты
    -- ----------------------------------------------------------------

    -- Вызываем при загрузке модуля
    reloadSpawnPoints()

    -- При смене карты перезагружаем точки (после полной инициализации карты и фракций)
    hook.Add("InitPostEntity", "SpawnPoints_ReloadOnMap", function()
        -- Если Factions ещё не определена, ждём короткое время
        if not Factions then
            timer.Simple(0.1, function()
                if Factions then
                    reloadSpawnPoints()
                end
            end)
        else
            reloadSpawnPoints()
        end
    end)

    hook.Add("PostCleanupMap", "SpawnPoints_ReloadCleanup", function()
        timer.Simple(0.5, function()
            reloadSpawnPoints()
        end)
    end)

    -- При создании новой фракции инициализируем пустые точки
    hook.Add("FactionCreated", "SpawnPoints_InitNew", function(factionName)
        if Factions and Factions[factionName] then
            ensureFactionSpawnPoints(Factions[factionName])
        end
    end)

    -- ----------------------------------------------------------------
    -- 5. Функции работы с точками (используют загруженные данные)
    -- ----------------------------------------------------------------

    --- Собрать данные для отправки клиенту
    local function buildSpawnData()
        local data = { factions = {}, global = GlobalSpawnPoints }
        if Factions then
            for name, f in pairs(Factions) do
                ensureFactionSpawnPoints(f)
                -- meta — реальные роли/отделы/лидер из factions.json (Factions),
                -- чтобы клиент строил выбор из списков, а не ручной ввод
                local roles = {}
                if istable(f.Roles) then
                    for _, r in ipairs(f.Roles) do
                        if r ~= f.LeaderRoleName then roles[#roles + 1] = tostring(r) end
                    end
                end
                local depts = {}
                if istable(f.Departments) then
                    for _, d in ipairs(f.Departments) do depts[#depts + 1] = tostring(d) end
                end
                data.factions[name] = {
                    points = f.SpawnPoints or {},
                    roles = f.RoleSpawnPoints or {},
                    departments = f.DepartmentSpawnPoints or {},
                    rolesList = roles,
                    departmentsList = depts,
                    leaderRole = tostring(f.LeaderRoleName or ""),
                    leader = tostring(f.Leader or "—"),
                    memberCount = istable(f.Members) and table.Count(f.Members) or 0,
                }
            end
        end
        return data
    end

    -- Глобальные
    function AddGlobalSpawnPoint(pos, ang)
        table.insert(GlobalSpawnPoints, { pos = vecToTable(pos), ang = angToTable(ang) })
        saveGlobalSpawnPoints(GlobalSpawnPoints)
        return true
    end

    function RemoveGlobalSpawnPoint(index)
        if not GlobalSpawnPoints or index < 1 or index > #GlobalSpawnPoints then
            return false, "Неверный индекс"
        end
        table.remove(GlobalSpawnPoints, index)
        saveGlobalSpawnPoints(GlobalSpawnPoints)
        return true
    end

    function GetGlobalSpawnPoints()
        return GlobalSpawnPoints
    end

    -- Фракционные
    function AddSpawnPointForFaction(factionName, pos, ang)
        if not Factions or not Factions[factionName] then
            return false, "Фракция не найдена"
        end

        ensureFactionSpawnPoints(Factions[factionName])
        table.insert(Factions[factionName].SpawnPoints, { pos = vecToTable(pos), ang = angToTable(ang) })

        -- Сохраняем ВСЕ точки всех фракций единым форматом (points+roles+departments)
        saveAllFactionSpawnPoints()
        return true
    end

    function RemoveSpawnPointFromFaction(factionName, index)
        if not Factions or not Factions[factionName] then
            return false, "Фракция не найдена"
        end

        ensureFactionSpawnPoints(Factions[factionName])
        local pts = Factions[factionName].SpawnPoints
        if index < 1 or index > #pts then return false, "Неверный индекс" end
        table.remove(pts, index)

        saveAllFactionSpawnPoints()
        return true
    end

    function GetSpawnPointsForFaction(factionName)
        if not Factions or not Factions[factionName] then return {} end
        ensureFactionSpawnPoints(Factions[factionName])
        return Factions[factionName].SpawnPoints
    end

    -- === ТОЧКИ ДЛЯ РОЛЕЙ ===
    -- Валидация роли по реальному списку из factions.json (Factions.Roles).
    -- Если у фракции роли не заданы — разрешаем (легаси-точки), иначе строго.
    local function isValidRole(f, roleName)
        if not istable(f.Roles) or #f.Roles == 0 then return true end
        if roleName == f.LeaderRoleName then return true end
        for _, r in ipairs(f.Roles) do
            if tostring(r) == tostring(roleName) then return true end
        end
        return false
    end

    local function isValidDepartment(f, deptName)
        if not istable(f.Departments) or #f.Departments == 0 then return true end
        for _, d in ipairs(f.Departments) do
            if tostring(d) == tostring(deptName) then return true end
        end
        return false
    end

    function AddSpawnPointForRole(factionName, roleName, pos, ang)
        if not Factions or not Factions[factionName] then return false, "Фракция не найдена" end
        local f = Factions[factionName]
        if not isValidRole(f, roleName) then
            return false, "Роль «" .. tostring(roleName) .. "» не существует во фракции «" .. factionName .. "»"
        end
        ensureFactionSpawnPoints(f)
        if not f.RoleSpawnPoints[roleName] then f.RoleSpawnPoints[roleName] = {} end
        table.insert(f.RoleSpawnPoints[roleName], { pos = vecToTable(pos), ang = angToTable(ang) })
        saveAllFactionSpawnPoints()
        return true
    end

    function RemoveSpawnPointFromRole(factionName, roleName, index)
        if not Factions or not Factions[factionName] then return false end
        local f = Factions[factionName]
        if not f.RoleSpawnPoints or not f.RoleSpawnPoints[roleName] then return false end
        table.remove(f.RoleSpawnPoints[roleName], index)
        if #f.RoleSpawnPoints[roleName] == 0 then f.RoleSpawnPoints[roleName] = nil end
        saveAllFactionSpawnPoints()
        return true
    end

    function GetSpawnPointsForRole(factionName, roleName)
        if not Factions or not Factions[factionName] then return {} end
        local f = Factions[factionName]
        if not f.RoleSpawnPoints or not f.RoleSpawnPoints[roleName] then return {} end
        return f.RoleSpawnPoints[roleName]
    end

    -- === ТОЧКИ ДЛЯ ОТДЕЛОВ ===
    function AddSpawnPointForDepartment(factionName, deptName, pos, ang)
        if not Factions or not Factions[factionName] then return false, "Фракция не найдена" end
        local f = Factions[factionName]
        if not isValidDepartment(f, deptName) then
            return false, "Отдел «" .. tostring(deptName) .. "» не существует во фракции «" .. factionName .. "»"
        end
        ensureFactionSpawnPoints(f)
        if not f.DepartmentSpawnPoints[deptName] then f.DepartmentSpawnPoints[deptName] = {} end
        table.insert(f.DepartmentSpawnPoints[deptName], { pos = vecToTable(pos), ang = angToTable(ang) })
        saveAllFactionSpawnPoints()
        return true
    end

    function RemoveSpawnPointFromDepartment(factionName, deptName, index)
        if not Factions or not Factions[factionName] then return false end
        local f = Factions[factionName]
        if not f.DepartmentSpawnPoints or not f.DepartmentSpawnPoints[deptName] then return false end
        table.remove(f.DepartmentSpawnPoints[deptName], index)
        if #f.DepartmentSpawnPoints[deptName] == 0 then f.DepartmentSpawnPoints[deptName] = nil end
        saveAllFactionSpawnPoints()
        return true
    end

    function GetSpawnPointsForDepartment(factionName, deptName)
        if not Factions or not Factions[factionName] then return {} end
        local f = Factions[factionName]
        if not f.DepartmentSpawnPoints or not f.DepartmentSpawnPoints[deptName] then return {} end
        return f.DepartmentSpawnPoints[deptName]
    end

    -- ----------------------------------------------------------------
    -- 6. Основная логика спавна
    -- ----------------------------------------------------------------

    function GetSpawnPointForPlayer(ply)
        if not IsValid(ply) then return nil end
        local factionName = nil
        local memberData = nil

        if Factions then
            local steamID = ply:SteamID()
            for name, f in pairs(Factions) do
                local member
                if GRM.Identity and GRM.Identity.FactionMember then
                    member = GRM.Identity.FactionMember(f, ply)
                elseif f.Members then
                    member = f.Members[steamID] or f.Members[ply:SteamID64()]
                end
                if member then
                    factionName = name
                    memberData = member
                    break
                end
            end
        end

        if not factionName then
            -- Нет фракции → глобальные точки
            local globalPoints = GetGlobalSpawnPoints()
            if #globalPoints > 0 then
                local point = globalPoints[math.random(1, #globalPoints)]
                return tableToVec(point.pos), tableToAng(point.ang)
            end
            return nil
        end

        -- ПРИОРИТЕТ 1: Точки роли (наивысший)
        if memberData and memberData.Role then
            local rolePoints = GetSpawnPointsForRole(factionName, memberData.Role)
            if #rolePoints > 0 then
                local point = rolePoints[math.random(1, #rolePoints)]
                return tableToVec(point.pos), tableToAng(point.ang)
            end
        end

        -- ПРИОРИТЕТ 2: Точки отдела
        if memberData and memberData.Department then
            local deptPoints = GetSpawnPointsForDepartment(factionName, memberData.Department)
            if #deptPoints > 0 then
                local point = deptPoints[math.random(1, #deptPoints)]
                return tableToVec(point.pos), tableToAng(point.ang)
            end
        end

        -- ПРИОРИТЕТ 3: Точки фракции
        local factionPoints = GetSpawnPointsForFaction(factionName)
        if #factionPoints > 0 then
            local point = factionPoints[math.random(1, #factionPoints)]
            return tableToVec(point.pos), tableToAng(point.ang)
        end

        -- Фолбэк: глобальные точки
        local globalPoints = GetGlobalSpawnPoints()
        if #globalPoints > 0 then
            local point = globalPoints[math.random(1, #globalPoints)]
            return tableToVec(point.pos), tableToAng(point.ang)
        end

        return nil
    end

    function GRM_MovePlayerToSpawnPoint(ply)
        if not IsValid(ply) then return false end
        local pos, ang = GetSpawnPointForPlayer(ply)
        if not pos then return false end
        ply:SetPos(pos)
        if ang then
            ply:SetAngles(ang)
            if ply.SetEyeAngles then ply:SetEyeAngles(ang) end
        end
        return true, pos, ang
    end

    hook.Add("PlayerSpawn", "SpawnAtFactionPoint", function(ply)
        GRM_MovePlayerToSpawnPoint(ply)
    end)

    -- ----------------------------------------------------------------
    -- 7. NET-обработчики для админ-меню
    -- ----------------------------------------------------------------

    util.AddNetworkString("SpawnAdmin_OpenMenu")
    util.AddNetworkString("SpawnAdmin_SendData")
    util.AddNetworkString("SpawnAdmin_AddPoint")
    util.AddNetworkString("SpawnAdmin_RemovePoint")
    util.AddNetworkString("SpawnAdmin_TeleportToPoint")
    util.AddNetworkString("SpawnAdmin_AddRolePoint")
    util.AddNetworkString("SpawnAdmin_RemoveRolePoint")
    util.AddNetworkString("SpawnAdmin_AddDeptPoint")
    util.AddNetworkString("SpawnAdmin_RemoveDeptPoint")

    local function sendSpawnDataToPlayer(ply)
        net.Start("SpawnAdmin_SendData")
        net.WriteTable(buildSpawnData())
        net.Send(ply)
    end

    net.Receive("SpawnAdmin_OpenMenu", function(_, ply)
        if not ply:IsSuperAdmin() then return end
        sendSpawnDataToPlayer(ply)
    end)

    net.Receive("SpawnAdmin_AddPoint", function(_, ply)
        if not ply:IsSuperAdmin() then return end

        local faction = net.ReadString()
        local pos     = net.ReadVector()
        local ang     = net.ReadAngle()

        local ok, err
        if faction == "__global" then
            ok, err = AddGlobalSpawnPoint(pos, ang)
        else
            ok, err = AddSpawnPointForFaction(faction, pos, ang)
        end

        if ok then
            sendSpawnDataToPlayer(ply)
        else
            ply:PrintMessage(HUD_PRINTTALK, "[SpawnPoints] Ошибка: " .. tostring(err))
            sendSpawnDataToPlayer(ply)
        end
    end)

    net.Receive("SpawnAdmin_RemovePoint", function(_, ply)
        if not ply:IsSuperAdmin() then return end

        local faction = net.ReadString()
        local index   = net.ReadInt(32)

        local ok, err
        if faction == "__global" then
            ok, err = RemoveGlobalSpawnPoint(index)
        else
            ok, err = RemoveSpawnPointFromFaction(faction, index)
        end

        if not ok then
            ply:PrintMessage(HUD_PRINTTALK, "[SpawnPoints] Ошибка: " .. tostring(err))
        end

        sendSpawnDataToPlayer(ply)
    end)

    net.Receive("SpawnAdmin_TeleportToPoint", function(_, ply)
        if not ply:IsSuperAdmin() then return end

        local pos = net.ReadVector()
        local ang = net.ReadAngle()

        ply:SetPos(pos)
        ply:SetAngles(ang)
    end)

    -- === ТОЧКИ ДЛЯ РОЛЕЙ ===
    net.Receive("SpawnAdmin_AddRolePoint", function(_, ply)
        if not ply:IsSuperAdmin() then return end
        local factionName = net.ReadString()
        local roleName = net.ReadString()
        local pos = net.ReadVector()
        local ang = net.ReadAngle()
        local ok, err = AddSpawnPointForRole(factionName, roleName, pos, ang)
        if not ok and err then
            ply:PrintMessage(HUD_PRINTTALK, "[SpawnPoints] " .. tostring(err))
        end
        sendSpawnDataToPlayer(ply)
    end)

    net.Receive("SpawnAdmin_RemoveRolePoint", function(_, ply)
        if not ply:IsSuperAdmin() then return end
        local factionName = net.ReadString()
        local roleName = net.ReadString()
        local index = net.ReadInt(32)
        RemoveSpawnPointFromRole(factionName, roleName, index)
        sendSpawnDataToPlayer(ply)
    end)

    -- === ТОЧКИ ДЛЯ ОТДЕЛОВ ===
    net.Receive("SpawnAdmin_AddDeptPoint", function(_, ply)
        if not ply:IsSuperAdmin() then return end
        local factionName = net.ReadString()
        local deptName = net.ReadString()
        local pos = net.ReadVector()
        local ang = net.ReadAngle()
        local ok, err = AddSpawnPointForDepartment(factionName, deptName, pos, ang)
        if not ok and err then
            ply:PrintMessage(HUD_PRINTTALK, "[SpawnPoints] " .. tostring(err))
        end
        sendSpawnDataToPlayer(ply)
    end)

    net.Receive("SpawnAdmin_RemoveDeptPoint", function(_, ply)
        if not ply:IsSuperAdmin() then return end
        local factionName = net.ReadString()
        local deptName = net.ReadString()
        local index = net.ReadInt(32)
        RemoveSpawnPointFromDepartment(factionName, deptName, index)
        sendSpawnDataToPlayer(ply)
    end)

    print("[SpawnPoints] Серверная часть загружена (карта: " .. game.GetMap() .. ")")

end

-- ================================================================
-- КЛИЕНТСКАЯ ЧАСТЬ (без изменений)
-- ================================================================

if CLIENT then

    -- Цветовая схема HUD v10.2
    local CUI = {
        bg = Color(19, 24, 33, 248),
        panel = Color(33, 42, 56, 245),
        accent = Color(70, 155, 255),
        green = Color(55, 185, 105),
        red = Color(205, 70, 65),
        yellow = Color(235, 180, 60),
        text = Color(240, 244, 250),
        dim = Color(166, 176, 191),
    }

    surface.CreateFont("GRML_Title", {font="Roboto", size=20, weight=800, extended=true})
    surface.CreateFont("GRML_Normal", {font="Roboto", size=14, weight=500, extended=true})
    surface.CreateFont("GRML_Small", {font="Roboto", size=12, weight=400, extended=true})

    -- Состояние открытого меню (обновляем в-месте при получении свежих данных)
    local menuState = {
        frame         = nil,
        activeTab     = nil,
        refreshGlobal = nil,
        refreshFac    = {},
        globalPoints  = {},
        factions      = {},
    }

    -- ----------------------------------------------------------------
    -- Вспомогательные функции отображения
    -- ----------------------------------------------------------------

    --- Безопасно получить числовое поле (Vector.x или table[1] или table.x)
    local function safeCoord(t, key1, key2)
        if type(t) == "table" then
            return tonumber(t[key1] or t[key2]) or 0
        elseif isvector and isvector(t) or isangle and isangle(t) then
            return tonumber(t[key1]) or 0
        end
        return 0
    end

    local function fmtPos(pos)
        return
            string.format("%.1f", safeCoord(pos, "x", 1)),
            string.format("%.1f", safeCoord(pos, "y", 2)),
            string.format("%.1f", safeCoord(pos, "z", 3))
    end

    local function fmtAng(ang)
        return
            string.format("%.1f", safeCoord(ang, "p", 1)),
            string.format("%.1f", safeCoord(ang, "y", 2)),
            string.format("%.1f", safeCoord(ang, "r", 3))
    end

    --- Конвертировать plain-таблицу в Vector для net.WriteVector
    local function pointToVec(pos)
        if isvector and isvector(pos) then return pos end
        return Vector(
            tonumber(pos.x or pos[1]) or 0,
            tonumber(pos.y or pos[2]) or 0,
            tonumber(pos.z or pos[3]) or 0
        )
    end

    local function pointToAng(ang)
        if isangle and isangle(ang) then return ang end
        return Angle(
            tonumber(ang.p or ang[1]) or 0,
            tonumber(ang.y or ang[2]) or 0,
            tonumber(ang.r or ang[3]) or 0
        )
    end

    -- ----------------------------------------------------------------
    -- ----------------------------------------------------------------
    -- Общие элементы GRM-дизайна (стиль HUD v10.2 / админ-хаба)
    -- ----------------------------------------------------------------

    local function gBtn(parent, text, color, wide, tall)
        local b = vgui.Create("DButton", parent)
        b:SetText("")
        b:SetFont("GRML_Normal")
        if wide then b:SetWide(wide) end
        if tall then b:SetTall(tall) end
        b.Paint = function(self, w, h)
            local col = color
            if self:IsHovered() then col = Color(math.min(color.r + 22, 255), math.min(color.g + 22, 255), math.min(color.b + 22, 255)) end
            draw.RoundedBox(5, 0, 0, w, h, col)
            draw.SimpleText(text, "GRML_Normal", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        return b
    end

    -- Тёмный комбобокс (выбор роли/отдела из factions.json)
    local function gCombo(parent)
        local c = vgui.Create("DComboBox", parent)
        c:SetFont("GRML_Normal")
        c.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(25, 30, 40, 240))
            surface.SetDrawColor(Color(60, 70, 85, 200))
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            self:DrawTextEntryText(Color(220, 225, 235), CUI.accent, CUI.text)
        end
        return c
    end

    -- Заголовок секции
    local function gHeader(parent, text, tall)
        local h = vgui.Create("DPanel", parent)
        h:Dock(TOP)
        h:SetTall(tall or 30)
        h:DockMargin(4, 4, 4, 2)
        h.Paint = function(_, w, hh)
            draw.RoundedBox(4, 0, 0, w, hh, Color(40, 50, 65, 245))
            draw.SimpleText(text, "GRML_Normal", 8, hh / 2, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        return h
    end

    -- Карточка точки с кнопкой удаления
    local function gPointCard(parent, index, point, onRemove)
        local card = vgui.Create("DPanel", parent)
        card:Dock(TOP)
        card:SetTall(42)
        card:DockMargin(8, 2, 4, 2)
        card.Paint = function(self, w, h)
            local bg = self:IsHovered() and Color(40, 50, 65, 245) or Color(30, 38, 52, 240)
            draw.RoundedBox(4, 0, 0, w, h, bg)
            local px, py, pz = fmtPos(point.pos)
            local pp, yy, rr = fmtAng(point.ang)
            draw.SimpleText(string.format("#%d   X:%s  Y:%s  Z:%s", index, px, py, pz), "GRML_Normal", 10, 9, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(string.format("Угол: P:%s  Y:%s  R:%s", pp, yy, rr), "GRML_Small", 10, 26, CUI.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        local del = gBtn(card, "Удалить", CUI.red, 84, 26)
        del:Dock(RIGHT)
        del:DockMargin(4, 8, 8, 8)
        del.DoClick = onRemove
        return card
    end

    -- ----------------------------------------------------------------
    -- Построение вкладки для РОЛЕЙ (выбор из factions.json, не ручной ввод)
    -- ----------------------------------------------------------------

    local function buildRoleTab(panel, factionName, rolesData, rolesList)
        local scroll = vgui.Create("DScrollPanel", panel)
        scroll:Dock(FILL)
        scroll:DockMargin(5, 5, 5, 5)
        scroll.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, CUI.panel) end
        local canvas = scroll:GetCanvas()

        -- Панель добавления: комбобокс выбора роли + кнопка
        local addBar = vgui.Create("DPanel", panel)
        addBar:Dock(BOTTOM)
        addBar:SetTall(52)
        addBar:DockMargin(5, 5, 5, 5)
        addBar.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, CUI.panel) end

        local hint = vgui.Create("DLabel", addBar)
        hint:Dock(TOP)
        hint:SetTall(16)
        hint:DockMargin(8, 2, 8, 0)
        hint:SetFont("GRML_Small")
        hint:SetTextColor(CUI.dim)
        hint:SetText("Роль выбирается из списка фракции (factions.json). Точка ставится на вашей позиции.")

        local row = vgui.Create("DPanel", addBar)
        row:Dock(FILL)
        row:DockMargin(6, 0, 6, 4)
        row:SetPaintBackground(false)

        local roleCombo = gCombo(row)
        roleCombo:Dock(LEFT)
        roleCombo:SetWide(280)
        roleCombo:DockMargin(0, 4, 6, 4)

        -- Заполняем список ролей (без роли лидера — у лидера свои приоритеты)
        local hasRoles = false
        if istable(rolesList) then
            for _, r in ipairs(rolesList) do
                roleCombo:AddChoice(tostring(r), tostring(r))
                hasRoles = true
            end
        end
        -- Легаси-роли, у которых уже есть точки, но которых нет в списке — тоже показываем
        if istable(rolesData) then
            for r in pairs(rolesData) do
                local found = false
                for _, x in ipairs(rolesList or {}) do if tostring(x) == tostring(r) then found = true break end end
                if not found then roleCombo:AddChoice(tostring(r), tostring(r)) hasRoles = true end
            end
        end
        if not hasRoles then
            roleCombo:AddChoice("(роли не заданы)", "")
        end

        local btnAdd = gBtn(row, "Добавить точку", CUI.green, 180, 30)
        btnAdd:Dock(LEFT)
        btnAdd:DockMargin(0, 4, 6, 4)

        btnAdd.DoClick = function()
            local roleName = roleCombo:GetSelected()
            if not roleName or roleName == "" then
                notification.AddLegacy("Выберите роль из списка", NOTIFY_ERROR, 3)
                return
            end
            net.Start("SpawnAdmin_AddRolePoint")
            net.WriteString(factionName)
            net.WriteString(roleName)
            net.WriteVector(LocalPlayer():GetPos())
            net.WriteAngle(LocalPlayer():GetAngles())
            net.SendToServer()
            notification.AddLegacy("Точка для роли «" .. roleName .. "» добавлена", NOTIFY_GENERIC, 2)
        end

        -- Список точек выбранной роли
        local function refreshRoleList()
            for _, ch in ipairs(canvas:GetChildren()) do ch:Remove() end
            local roleName = roleCombo:GetSelected()
            if not roleName or roleName == "" then return end
            local pts = istable(rolesData) and rolesData[roleName] or nil
            if not istable(pts) or #pts == 0 then
                gHeader(canvas, "Роль «" .. roleName .. "» — точек пока нет. Встаньте в нужное место и нажмите «Добавить точку».", 30)
                return
            end
            gHeader(canvas, "Роль «" .. roleName .. "» — " .. #pts .. " точек", 30)
            for i, point in ipairs(pts) do
                gPointCard(canvas, i, point, function()
                    net.Start("SpawnAdmin_RemoveRolePoint")
                    net.WriteString(factionName)
                    net.WriteString(roleName)
                    net.WriteInt(i, 32)
                    net.SendToServer()
                end)
            end
        end

        roleCombo.OnSelect = function() refreshRoleList() end
        refreshRoleList()
    end

    -- ----------------------------------------------------------------
    -- Построение вкладки для ОТДЕЛОВ (выбор из factions.json, не ручной ввод)
    -- ----------------------------------------------------------------

    local function buildDepartmentTab(panel, factionName, deptsData, deptsList)
        local scroll = vgui.Create("DScrollPanel", panel)
        scroll:Dock(FILL)
        scroll:DockMargin(5, 5, 5, 5)
        scroll.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, CUI.panel) end
        local canvas = scroll:GetCanvas()

        local addBar = vgui.Create("DPanel", panel)
        addBar:Dock(BOTTOM)
        addBar:SetTall(52)
        addBar:DockMargin(5, 5, 5, 5)
        addBar.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, CUI.panel) end

        local hint = vgui.Create("DLabel", addBar)
        hint:Dock(TOP)
        hint:SetTall(16)
        hint:DockMargin(8, 2, 8, 0)
        hint:SetFont("GRML_Small")
        hint:SetTextColor(CUI.dim)
        hint:SetText("Отдел выбирается из списка фракции (factions.json). Точка ставится на вашей позиции.")

        local row = vgui.Create("DPanel", addBar)
        row:Dock(FILL)
        row:DockMargin(6, 0, 6, 4)
        row:SetPaintBackground(false)

        local deptCombo = gCombo(row)
        deptCombo:Dock(LEFT)
        deptCombo:SetWide(280)
        deptCombo:DockMargin(0, 4, 6, 4)

        local hasDepts = false
        if istable(deptsList) then
            for _, d in ipairs(deptsList) do
                deptCombo:AddChoice(tostring(d), tostring(d))
                hasDepts = true
            end
        end
        if istable(deptsData) then
            for d in pairs(deptsData) do
                local found = false
                for _, x in ipairs(deptsList or {}) do if tostring(x) == tostring(d) then found = true break end end
                if not found then deptCombo:AddChoice(tostring(d), tostring(d)) hasDepts = true end
            end
        end
        if not hasDepts then
            deptCombo:AddChoice("(отделы не заданы)", "")
        end

        local btnAdd = gBtn(row, "Добавить точку", CUI.green, 180, 30)
        btnAdd:Dock(LEFT)
        btnAdd:DockMargin(0, 4, 6, 4)

        btnAdd.DoClick = function()
            local deptName = deptCombo:GetSelected()
            if not deptName or deptName == "" then
                notification.AddLegacy("Выберите отдел из списка", NOTIFY_ERROR, 3)
                return
            end
            net.Start("SpawnAdmin_AddDeptPoint")
            net.WriteString(factionName)
            net.WriteString(deptName)
            net.WriteVector(LocalPlayer():GetPos())
            net.WriteAngle(LocalPlayer():GetAngles())
            net.SendToServer()
            notification.AddLegacy("Точка для отдела «" .. deptName .. "» добавлена", NOTIFY_GENERIC, 2)
        end

        local function refreshDeptList()
            for _, ch in ipairs(canvas:GetChildren()) do ch:Remove() end
            local deptName = deptCombo:GetSelected()
            if not deptName or deptName == "" then return end
            local pts = istable(deptsData) and deptsData[deptName] or nil
            if not istable(pts) or #pts == 0 then
                gHeader(canvas, "Отдел «" .. deptName .. "» — точек пока нет. Встаньте в нужное место и нажмите «Добавить точку».", 30)
                return
            end
            gHeader(canvas, "Отдел «" .. deptName .. "» — " .. #pts .. " точек", 30)
            for i, point in ipairs(pts) do
                gPointCard(canvas, i, point, function()
                    net.Start("SpawnAdmin_RemoveDeptPoint")
                    net.WriteString(factionName)
                    net.WriteString(deptName)
                    net.WriteInt(i, 32)
                    net.SendToServer()
                end)
            end
        end

        deptCombo.OnSelect = function() refreshDeptList() end
        refreshDeptList()
    end

    -- ----------------------------------------------------------------
    -- Построение вкладки списка точек (тёмная тема HUD v10.2)
    -- ----------------------------------------------------------------

    local function buildPointTab(panel, points, factionKey)
        -- Поиск/фильтр
        local searchBar = vgui.Create("DPanel", panel)
        searchBar:Dock(TOP)
        searchBar:SetTall(36)
        searchBar:DockMargin(5, 5, 5, 5)
        searchBar.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, CUI.panel) end

        local searchEntry = vgui.Create("DTextEntry", searchBar)
        searchEntry:Dock(FILL)
        searchEntry:DockMargin(5, 6, 5, 6)
        searchEntry:SetPlaceholderText("Поиск по координатам...")
        searchEntry.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(25, 30, 40, 240))
            surface.SetDrawColor(Color(60, 70, 85, 200))
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            self:DrawTextEntryText(Color(220, 225, 235), CUI.accent, CUI.text)
        end

        -- Список точек (карточки вместо строк)
        local scroll = vgui.Create("DScrollPanel", panel)
        scroll:Dock(FILL)
        scroll:DockMargin(5, 0, 5, 5)
        scroll.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, CUI.panel) end

        local function refreshList()
            -- Очищаем старые карточки
            for _, child in ipairs(scroll:GetCanvas():GetChildren()) do
                child:Remove()
            end

            local filter = string.lower(searchEntry:GetValue() or "")

            for i, point in ipairs(points) do
                -- Фильтрация
                local showCard = true
                if filter ~= "" then
                    local coords = string.format("%.0f %.0f %.0f", safeCoord(point.pos, "x", 1), safeCoord(point.pos, "y", 2), safeCoord(point.pos, "z", 3))
                    if not string.find(string.lower(coords), filter, 1, true) then
                        showCard = false
                    end
                end

                if showCard then
                -- Карточка точки
                local card = vgui.Create("DPanel", scroll:GetCanvas())
                card:Dock(TOP)
                card:SetTall(50)
                card:DockMargin(4, 2, 4, 2)
                card._dataIndex = i
                card.Paint = function(self, w, h)
                    local bg = self:IsHovered() and Color(40, 50, 65, 245) or Color(30, 38, 52, 240)
                    if self:IsSelected() then bg = Color(50, 80, 140, 200) end
                    draw.RoundedBox(4, 0, 0, w, h, bg)
                    -- Координаты
                    local px, py, pz = fmtPos(point.pos)
                    draw.SimpleText(string.format("X:%s Y:%s Z:%s", px, py, pz), "GRML_Normal", 8, 8, CUI.text)
                    draw.SimpleText(string.format("P:%s Y:%s R:%s", fmtAng(point.ang)), "GRML_Small", 8, 26, CUI.dim)
                    -- Номер
                    draw.SimpleText("#" .. i, "GRML_Small", w - 12, 8, CUI.dim, TEXT_ALIGN_RIGHT)
                end
                card.OnMousePressed = function(self)
                    for _, c in ipairs(scroll:GetCanvas():GetChildren()) do c:SetSelected(false) end
                    self:SetSelected(true)
                end
                card.IsSelected = function(self) return self._selected or false end
                card.SetSelected = function(self, v) self._selected = v end
                end -- if showCard
            end -- for
        end

        searchEntry.OnValueChange = function() refreshList() end
        refreshList()

        -- Получить выбранную карточку
        local function getSelectedCard()
            for _, child in ipairs(scroll:GetCanvas():GetChildren()) do
                if child:IsSelected() then return child end
            end
            return nil
        end

        -- Кнопки действий
        local btnBar = vgui.Create("DPanel", panel)
        btnBar:Dock(BOTTOM)
        btnBar:SetTall(44)
        btnBar:DockMargin(5, 5, 5, 5)
        btnBar.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, CUI.panel) end

        local btnAdd = gBtn(btnBar, "Добавить (здесь)", CUI.green, 180, 32)
        btnAdd:Dock(LEFT)
        btnAdd:DockMargin(5, 6, 5, 6)
        btnAdd.DoClick = function()
            net.Start("SpawnAdmin_AddPoint")
            net.WriteString(factionKey)
            net.WriteVector(LocalPlayer():GetPos())
            net.WriteAngle(LocalPlayer():GetAngles())
            net.SendToServer()
            notification.AddLegacy("Запрос отправлен...", NOTIFY_GENERIC, 2)
        end

        local btnTeleport = gBtn(btnBar, "Телепорт", CUI.accent, 120, 32)
        btnTeleport:Dock(LEFT)
        btnTeleport:DockMargin(5, 6, 5, 6)
        btnTeleport.DoClick = function()
            local card = getSelectedCard()
            if not card then
                notification.AddLegacy("Выберите точку", NOTIFY_ERROR, 3)
                return
            end
            local point = points[card._dataIndex]
            if point then
                net.Start("SpawnAdmin_TeleportToPoint")
                net.WriteVector(pointToVec(point.pos))
                net.WriteAngle(pointToAng(point.ang))
                net.SendToServer()
                if IsValid(menuState.frame) then menuState.frame:Close() end
            end
        end

        local btnRemove = gBtn(btnBar, "Удалить", CUI.red, 100, 32)
        btnRemove:Dock(LEFT)
        btnRemove:DockMargin(5, 6, 5, 6)
        btnRemove.DoClick = function()
            local card = getSelectedCard()
            if not card then
                notification.AddLegacy("Выберите точку", NOTIFY_ERROR, 3)
                return
            end
            net.Start("SpawnAdmin_RemovePoint")
            net.WriteString(factionKey)
            net.WriteInt(card._dataIndex, 32)
            net.SendToServer()
            notification.AddLegacy("Запрос отправлен...", NOTIFY_GENERIC, 2)
        end

        -- Экспорт/Импорт (справа)
        local btnExport = gBtn(btnBar, "Экспорт", CUI.yellow, 100, 32)
        btnExport:Dock(RIGHT)
        btnExport:DockMargin(5, 6, 5, 6)
        btnExport.DoClick = function()
            local data = util.TableToJSON(points, true)
            SetClipboardText(data)
            notification.AddLegacy("Точки скопированы в буфер обмена", NOTIFY_GENERIC, 3)
        end

        return refreshList
    end

    -- ----------------------------------------------------------------
    -- Открытие / перестройка меню (редизайн в стиле GRM)
    -- ----------------------------------------------------------------

    local function buildMenu(data)
        menuState.globalPoints = data.global   or {}
        menuState.factions     = data.factions or {}
        menuState.refreshGlobal = nil
        menuState.refreshFac    = {}

        if IsValid(menuState.frame) then menuState.frame:Remove() end

        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:SetSize(980, 700)
        frame:Center()
        frame:MakePopup()
        frame:ShowCloseButton(false)
        menuState.frame = frame

        -- Шапка в стиле GRM
        frame.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, CUI.bg)
            draw.RoundedBoxEx(8, 0, 0, w, 46, Color(27, 35, 48), true, true, false, false)
            draw.SimpleText("Точки спавна", "GRML_Title", 14, 23, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("/spawnmenu  •  суперадмин", "GRML_Small", 14, 40, CUI.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local total = #menuState.globalPoints
            for _, facData in pairs(menuState.factions) do
                local pts = istable(facData) and facData.points or nil
                if istable(pts) then total = total + #pts end
                if istable(facData) and istable(facData.roles) then
                    for _, rp in pairs(facData.roles) do if istable(rp) then total = total + #rp end end
                end
                if istable(facData) and istable(facData.departments) then
                    for _, dp in pairs(facData.departments) do if istable(dp) then total = total + #dp end end
                end
            end
            draw.SimpleText("Всего точек: " .. total, "GRML_Normal", w - 14, 23, CUI.green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        -- Кастомный крестик
        local closeBtn = vgui.Create("DButton", frame)
        closeBtn:SetPos(frame:GetWide() - 38, 8)
        closeBtn:SetSize(30, 30)
        closeBtn:SetText("")
        closeBtn.DoClick = function() frame:Close() end
        closeBtn.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and CUI.red or Color(46, 56, 74))
            surface.SetDrawColor(240, 242, 246)
            surface.DrawLine(8, 8, w - 8, h - 8)
            surface.DrawLine(8, h - 8, w - 8, 8)
        end

        local tabs = vgui.Create("DPropertySheet", frame)
        tabs:Dock(FILL)
        tabs:DockMargin(6, 52, 6, 6)
        tabs.Paint = function(_, w, h) draw.RoundedBox(7, 0, 0, w, h, Color(27, 35, 48)) end

        -- Тёмный стиль вкладок (как в админ-хабе)
        local function styleTabs(sheet)
            for _, item in ipairs(sheet.Items or {}) do
                local tab = item.Tab
                if IsValid(tab) then
                    tab:SetFont("GRML_Normal")
                    tab:SetTextColor(CUI.dim)
                    tab.Paint = function(self, w, h)
                        local active = self:IsActive()
                        draw.RoundedBoxEx(5, 0, 0, w, h, active and CUI.panel or CUI.panel, true, true, false, false)
                        if active then draw.RoundedBox(0, 0, h - 3, w, 3, CUI.accent) end
                    end
                end
            end
        end

        -- Вкладка «Глобальные»
        local globalPanel = vgui.Create("DPanel")
        globalPanel:SetPaintBackground(false)
        menuState.refreshGlobal = buildPointTab(globalPanel, menuState.globalPoints, "__global")
        tabs:AddSheet("Глобальные", globalPanel, "icon16/world.png")

        -- Вкладка для каждой фракции (с подвкладками)
        local sortedFactions = {}
        for name in pairs(menuState.factions) do table.insert(sortedFactions, name) end
        table.sort(sortedFactions)

        for _, factionName in ipairs(sortedFactions) do
            local facData = menuState.factions[factionName]
            if not istable(facData) then facData = { points = facData } end
            local points = istable(facData.points) and facData.points or (istable(facData) and facData or {})

            local factionPanel = vgui.Create("DPropertySheet", tabs)
            factionPanel.Paint = function(_, w, h) draw.RoundedBox(7, 0, 0, w, h, Color(24, 30, 41)) end

            -- Подвкладка: Фракция (общие точки)
            local facPointsPanel = vgui.Create("DPanel", factionPanel)
            facPointsPanel:SetPaintBackground(false)
            menuState.refreshFac[factionName] = buildPointTab(facPointsPanel, points, factionName)
            factionPanel:AddSheet("Точки фракции", facPointsPanel, "icon16/group.png")

            -- Подвкладка: Роли (выбор из factions.json)
            local rolesPanel = vgui.Create("DPanel", factionPanel)
            rolesPanel:SetPaintBackground(false)
            buildRoleTab(rolesPanel, factionName, facData.roles or {}, facData.rolesList or {})
            factionPanel:AddSheet("Роли", rolesPanel, "icon16/user.png")

            -- Подвкладка: Отделы (выбор из factions.json)
            local deptsPanel = vgui.Create("DPanel", factionPanel)
            deptsPanel:SetPaintBackground(false)
            buildDepartmentTab(deptsPanel, factionName, facData.departments or {}, facData.departmentsList or {})
            factionPanel:AddSheet("Отделы", deptsPanel, "icon16/users.png")

            -- Информация о фракции из factions.json (лидер, роли, отделы)
            local metaLine = vgui.Create("DPanel", factionPanel)
            metaLine:Dock(BOTTOM)
            metaLine:SetTall(26)
            metaLine:DockMargin(5, 0, 5, 5)
            metaLine.Paint = function(_, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(33, 42, 56, 245))
                local info = string.format(
                    "Лидер: %s   •   Ролей: %d   •   Отделов: %d   •   Состав: %d",
                    tostring(facData.leader or "—"),
                    #(facData.rolesList or {}),
                    #(facData.departmentsList or {}),
                    tonumber(facData.memberCount) or 0
                )
                draw.SimpleText(info, "GRML_Small", 10, h / 2, CUI.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            styleTabs(factionPanel)
            tabs:AddSheet(factionName, factionPanel, "icon16/group.png")
        end

        styleTabs(tabs)
        frame:Show()
    end

    -- ----------------------------------------------------------------
    -- NET: получение данных от сервера (зарегистрировано на уровне модуля)
    -- ----------------------------------------------------------------

    net.Receive("SpawnAdmin_SendData", function()
        local data = net.ReadTable() or {}

        if IsValid(menuState.frame) then
            menuState.globalPoints = data.global   or {}
            menuState.factions     = data.factions or {}
            buildMenu(data)
            notification.AddLegacy("Список точек обновлён", NOTIFY_GENERIC, 2)
        else
            buildMenu(data)
        end
    end)

    -- ----------------------------------------------------------------
    -- Открытие меню (запрашивает данные с сервера)
    -- ----------------------------------------------------------------

    local function openSpawnAdminMenu()
        net.Start("SpawnAdmin_OpenMenu")
        net.SendToServer()
    end

    -- ----------------------------------------------------------------
    -- Команда /spawnmenu
    -- ----------------------------------------------------------------

    hook.Add("PlayerSayTransform", "SpawnAdminCommand", function(ply, datapack, is_team, is_local)
        if ply ~= LocalPlayer() then return end
        local msg = datapack[1]
        if not msg then return end
        if msg:lower():find("^/spawnmenu%s*") == 1 then
            if LocalPlayer():IsSuperAdmin() then
                openSpawnAdminMenu()
            else
                notification.AddLegacy("Нет прав", NOTIFY_ERROR, 3)
            end
            datapack[1] = ""
        end
    end)

    print("[SpawnPoints] Клиентская часть загружена (редизайн, выбор ролей/отделов из factions.json)")

end