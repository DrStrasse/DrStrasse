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

    -- Структура точек спавна:
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

    -- ----------------------------------------------------------------
    -- 1. Глобальные точки (загрузка/сохранение для текущей карты)
    -- ----------------------------------------------------------------

    local function loadGlobalSpawnPoints()
        local filePath = getGlobalSpawnFile()
        if not file.Exists(filePath, "DATA") then return {} end
        local data = file.Read(filePath, "DATA")
        local ok, tbl = pcall(util.JSONToTable, data)
        if ok and istable(tbl) then return tbl end
        return {}
    end

    local function saveGlobalSpawnPoints(tbl)
        file.Write(getGlobalSpawnFile(), util.TableToJSON(tbl, true))
    end

    GlobalSpawnPoints = GlobalSpawnPoints or {}

    -- ----------------------------------------------------------------
    -- 2. Точки фракций (загрузка/сохранение для текущей карты)
    -- ----------------------------------------------------------------

    local function loadFactionSpawnPoints()
        local filePath = getFactionSpawnFile()
        if not file.Exists(filePath, "DATA") then return {} end
        local data = file.Read(filePath, "DATA")
        local ok, tbl = pcall(util.JSONToTable, data)
        if ok and istable(tbl) then return tbl end
        return {}
    end

    local function saveFactionSpawnPoints(tbl)
        file.Write(getFactionSpawnFile(), util.TableToJSON(tbl, true))
    end

    --- Убедиться, что у фракции есть таблица SpawnPoints
    local function ensureFactionSpawnPoints(f)
        if not istable(f.SpawnPoints) then f.SpawnPoints = {} end
    end

    -- ----------------------------------------------------------------
    -- 3. Перезагрузка всех точек для текущей карты
    -- ----------------------------------------------------------------

    local function reloadSpawnPoints()
        -- Загружаем глобальные
        GlobalSpawnPoints = loadGlobalSpawnPoints()

        -- Загружаем фракционные
        local loadedData = loadFactionSpawnPoints()

        -- Применяем к существующим фракциям
        if Factions then
            for factionName, f in pairs(Factions) do
                if loadedData[factionName] then
                    f.SpawnPoints = loadedData[factionName]
                else
                    f.SpawnPoints = {}
                end
            end
        end
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
                data.factions[name] = {
                    points = f.SpawnPoints or {},
                    roles = f.RoleSpawnPoints or {},
                    departments = f.DepartmentSpawnPoints or {}
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

        -- Сохраняем все точки всех фракций
        local allData = {}
        for name, f in pairs(Factions) do
            if f.SpawnPoints and #f.SpawnPoints > 0 then
                allData[name] = f.SpawnPoints
            end
        end
        saveFactionSpawnPoints(allData)
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

        local allData = {}
        for name, f in pairs(Factions) do
            if f.SpawnPoints and #f.SpawnPoints > 0 then
                allData[name] = f.SpawnPoints
            end
        end
        saveFactionSpawnPoints(allData)
        return true
    end

    function GetSpawnPointsForFaction(factionName)
        if not Factions or not Factions[factionName] then return {} end
        ensureFactionSpawnPoints(Factions[factionName])
        return Factions[factionName].SpawnPoints
    end

    -- === ТОЧКИ ДЛЯ РОЛЕЙ ===
    function AddSpawnPointForRole(factionName, roleName, pos, ang)
        if not Factions or not Factions[factionName] then return false end
        local f = Factions[factionName]
        if not f.RoleSpawnPoints then f.RoleSpawnPoints = {} end
        if not f.RoleSpawnPoints[roleName] then f.RoleSpawnPoints[roleName] = {} end
        table.insert(f.RoleSpawnPoints[roleName], { pos = vecToTable(pos), ang = angToTable(ang) })
        saveFactionSpawnPoints(buildSpawnData().factions)
        return true
    end

    function RemoveSpawnPointFromRole(factionName, roleName, index)
        if not Factions or not Factions[factionName] then return false end
        local f = Factions[factionName]
        if not f.RoleSpawnPoints or not f.RoleSpawnPoints[roleName] then return false end
        table.remove(f.RoleSpawnPoints[roleName], index)
        if #f.RoleSpawnPoints[roleName] == 0 then f.RoleSpawnPoints[roleName] = nil end
        saveFactionSpawnPoints(buildSpawnData().factions)
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
        if not Factions or not Factions[factionName] then return false end
        local f = Factions[factionName]
        if not f.DepartmentSpawnPoints then f.DepartmentSpawnPoints = {} end
        if not f.DepartmentSpawnPoints[deptName] then f.DepartmentSpawnPoints[deptName] = {} end
        table.insert(f.DepartmentSpawnPoints[deptName], { pos = vecToTable(pos), ang = angToTable(ang) })
        saveFactionSpawnPoints(buildSpawnData().factions)
        return true
    end

    function RemoveSpawnPointFromDepartment(factionName, deptName, index)
        if not Factions or not Factions[factionName] then return false end
        local f = Factions[factionName]
        if not f.DepartmentSpawnPoints or not f.DepartmentSpawnPoints[deptName] then return false end
        table.remove(f.DepartmentSpawnPoints[deptName], index)
        if #f.DepartmentSpawnPoints[deptName] == 0 then f.DepartmentSpawnPoints[deptName] = nil end
        saveFactionSpawnPoints(buildSpawnData().factions)
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
        AddSpawnPointForRole(factionName, roleName, pos, ang)
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
        AddSpawnPointForDepartment(factionName, deptName, pos, ang)
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
    -- Построение вкладки для РОЛЕЙ
    -- ----------------------------------------------------------------

    local function buildRoleTab(panel, factionName, rolesData)
        -- Список ролей с их точками
        local scroll = vgui.Create("DScrollPanel", panel)
        scroll:Dock(FILL)
        scroll:DockMargin(5, 5, 5, 5)
        scroll.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, CUI.panel) end

        local canvas = scroll:GetCanvas()

        for roleName, rolePoints in pairs(rolesData) do
            -- Заголовок роли
            local header = vgui.Create("DPanel", canvas)
            header:Dock(TOP)
            header:SetTall(30)
            header:DockMargin(4, 4, 4, 2)
            header.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(40, 50, 65, 245))
                draw.SimpleText("Роль: " .. roleName .. " (" .. #rolePoints .. " точек)", "GRML_Normal", 8, 15, CUI.text)
            end

            -- Точки роли
            for i, point in ipairs(rolePoints) do
                local card = vgui.Create("DPanel", canvas)
                card:Dock(TOP)
                card:SetTall(40)
                card:DockMargin(8, 2, 4, 2)
                card.Paint = function(self, w, h)
                    local bg = self:IsHovered() and Color(40, 50, 65, 245) or Color(30, 38, 52, 240)
                    draw.RoundedBox(4, 0, 0, w, h, bg)
                    local px, py, pz = fmtPos(point.pos)
                    draw.SimpleText(string.format("#%d X:%s Y:%s Z:%s", i, px, py, pz), "GRML_Small", 8, 20, CUI.text)
                end

                -- Кнопка удаления
                local btnDel = vgui.Create("DButton", card)
                btnDel:Dock(RIGHT)
                btnDel:SetWide(80)
                btnDel:SetText("")
                btnDel.Paint = function(self, w, h)
                    local col = self:IsHovered() and Color(225, 90, 85) or CUI.red
                    draw.RoundedBox(4, 0, 0, w, h, col)
                    draw.SimpleText("Удалить", "GRML_Small", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                btnDel.DoClick = function()
                    net.Start("SpawnAdmin_RemoveRolePoint")
                    net.WriteString(factionName)
                    net.WriteString(roleName)
                    net.WriteInt(i, 32)
                    net.SendToServer()
                end
            end
        end

        -- Кнопка добавления точки для роли
        local addBar = vgui.Create("DPanel", panel)
        addBar:Dock(BOTTOM)
        addBar:SetTall(44)
        addBar:DockMargin(5, 5, 5, 5)
        addBar.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, CUI.panel) end

        local roleEntry = vgui.Create("DTextEntry", addBar)
        roleEntry:Dock(LEFT)
        roleEntry:SetWide(200)
        roleEntry:DockMargin(5, 6, 5, 6)
        roleEntry:SetPlaceholderText("Название роли...")
        roleEntry.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(25, 30, 40, 240))
            self:DrawTextEntryText(Color(220, 225, 235), CUI.accent, CUI.text)
        end

        local btnAdd = vgui.Create("DButton", addBar)
        btnAdd:Dock(LEFT)
        btnAdd:SetWide(150)
        btnAdd:DockMargin(5, 6, 5, 6)
        btnAdd:SetText("")
        btnAdd.Paint = function(self, w, h)
            local col = self:IsHovered() and Color(75, 205, 125) or CUI.green
            draw.RoundedBox(5, 0, 0, w, h, col)
            draw.SimpleText("Добавить точку", "GRML_Normal", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btnAdd.DoClick = function()
            local roleName = roleEntry:GetValue()
            if roleName == "" then
                notification.AddLegacy("Введите название роли", NOTIFY_ERROR, 3)
                return
            end
            net.Start("SpawnAdmin_AddRolePoint")
            net.WriteString(factionName)
            net.WriteString(roleName)
            net.WriteVector(LocalPlayer():GetPos())
            net.WriteAngle(LocalPlayer():GetAngles())
            net.SendToServer()
            roleEntry:SetValue("")
        end
    end

    -- ----------------------------------------------------------------
    -- Построение вкладки для ОТДЕЛОВ
    -- ----------------------------------------------------------------

    local function buildDepartmentTab(panel, factionName, deptsData)
        -- Список отделов с их точками
        local scroll = vgui.Create("DScrollPanel", panel)
        scroll:Dock(FILL)
        scroll:DockMargin(5, 5, 5, 5)
        scroll.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, CUI.panel) end

        local canvas = scroll:GetCanvas()

        for deptName, deptPoints in pairs(deptsData) do
            -- Заголовок отдела
            local header = vgui.Create("DPanel", canvas)
            header:Dock(TOP)
            header:SetTall(30)
            header:DockMargin(4, 4, 4, 2)
            header.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(40, 50, 65, 245))
                draw.SimpleText("Отдел: " .. deptName .. " (" .. #deptPoints .. " точек)", "GRML_Normal", 8, 15, CUI.text)
            end

            -- Точки отдела
            for i, point in ipairs(deptPoints) do
                local card = vgui.Create("DPanel", canvas)
                card:Dock(TOP)
                card:SetTall(40)
                card:DockMargin(8, 2, 4, 2)
                card.Paint = function(self, w, h)
                    local bg = self:IsHovered() and Color(40, 50, 65, 245) or Color(30, 38, 52, 240)
                    draw.RoundedBox(4, 0, 0, w, h, bg)
                    local px, py, pz = fmtPos(point.pos)
                    draw.SimpleText(string.format("#%d X:%s Y:%s Z:%s", i, px, py, pz), "GRML_Small", 8, 20, CUI.text)
                end

                -- Кнопка удаления
                local btnDel = vgui.Create("DButton", card)
                btnDel:Dock(RIGHT)
                btnDel:SetWide(80)
                btnDel:SetText("")
                btnDel.Paint = function(self, w, h)
                    local col = self:IsHovered() and Color(225, 90, 85) or CUI.red
                    draw.RoundedBox(4, 0, 0, w, h, col)
                    draw.SimpleText("Удалить", "GRML_Small", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                btnDel.DoClick = function()
                    net.Start("SpawnAdmin_RemoveDeptPoint")
                    net.WriteString(factionName)
                    net.WriteString(deptName)
                    net.WriteInt(i, 32)
                    net.SendToServer()
                end
            end
        end

        -- Кнопка добавления точки для отдела
        local addBar = vgui.Create("DPanel", panel)
        addBar:Dock(BOTTOM)
        addBar:SetTall(44)
        addBar:DockMargin(5, 5, 5, 5)
        addBar.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, CUI.panel) end

        local deptEntry = vgui.Create("DTextEntry", addBar)
        deptEntry:Dock(LEFT)
        deptEntry:SetWide(200)
        deptEntry:DockMargin(5, 6, 5, 6)
        deptEntry:SetPlaceholderText("Название отдела...")
        deptEntry.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(25, 30, 40, 240))
            self:DrawTextEntryText(Color(220, 225, 235), CUI.accent, CUI.text)
        end

        local btnAdd = vgui.Create("DButton", addBar)
        btnAdd:Dock(LEFT)
        btnAdd:SetWide(150)
        btnAdd:DockMargin(5, 6, 5, 6)
        btnAdd:SetText("")
        btnAdd.Paint = function(self, w, h)
            local col = self:IsHovered() and Color(75, 205, 125) or CUI.green
            draw.RoundedBox(5, 0, 0, w, h, col)
            draw.SimpleText("Добавить точку", "GRML_Normal", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btnAdd.DoClick = function()
            local deptName = deptEntry:GetValue()
            if deptName == "" then
                notification.AddLegacy("Введите название отдела", NOTIFY_ERROR, 3)
                return
            end
            net.Start("SpawnAdmin_AddDeptPoint")
            net.WriteString(factionName)
            net.WriteString(deptName)
            net.WriteVector(LocalPlayer():GetPos())
            net.WriteAngle(LocalPlayer():GetAngles())
            net.SendToServer()
            deptEntry:SetValue("")
        end
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
                    local coords = string.format("%.0f %.0f %.0f", point.pos.x, point.pos.y, point.pos.z)
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

        local function actionBtn(parent, text, color, callback)
            local btn = vgui.Create("DButton", parent)
            btn:SetText("")
            btn:SetFont("GRML_Normal")
            btn.Paint = function(self, w, h)
                local col = self:IsHovered() and Color(math.min(color.r+20,255), math.min(color.g+20,255), math.min(color.b+20,255)) or color
                draw.RoundedBox(5, 0, 0, w, h, col)
                draw.SimpleText(text, "GRML_Normal", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            btn.DoClick = callback
            return btn
        end

        local btnAdd = actionBtn(btnBar, "Добавить (здесь)", CUI.green, function()
            net.Start("SpawnAdmin_AddPoint")
            net.WriteString(factionKey)
            net.WriteVector(LocalPlayer():GetPos())
            net.WriteAngle(LocalPlayer():GetAngles())
            net.SendToServer()
            notification.AddLegacy("Запрос отправлен...", NOTIFY_GENERIC, 2)
        end)
        btnAdd:Dock(LEFT)
        btnAdd:SetWide(180)
        btnAdd:DockMargin(5, 6, 5, 6)

        local btnTeleport = actionBtn(btnBar, "Телепорт", CUI.accent, function()
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
        end)
        btnTeleport:Dock(LEFT)
        btnTeleport:SetWide(120)
        btnTeleport:DockMargin(5, 6, 5, 6)

        local btnRemove = actionBtn(btnBar, "Удалить", CUI.red, function()
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
        end)
        btnRemove:Dock(LEFT)
        btnRemove:SetWide(100)
        btnRemove:DockMargin(5, 6, 5, 6)

        -- Экспорт/Импорт (справа)
        local btnExport = actionBtn(btnBar, "Экспорт", CUI.yellow, function()
            local data = util.TableToJSON(points, true)
            SetClipboardText(data)
            notification.AddLegacy("Точки скопированы в буфер обмена", NOTIFY_GENERIC, 3)
        end)
        btnExport:Dock(RIGHT)
        btnExport:SetWide(100)
        btnExport:DockMargin(5, 6, 5, 6)

        return refreshList
    end

    -- ----------------------------------------------------------------
    -- Открытие / перестройка меню
    -- ----------------------------------------------------------------

    local function buildMenu(data)
        menuState.globalPoints = data.global   or {}
        menuState.factions     = data.factions or {}
        menuState.refreshGlobal = nil
        menuState.refreshFac    = {}

        if IsValid(menuState.frame) then menuState.frame:Remove() end

        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:SetSize(900, 650)
        frame:Center()
        frame:MakePopup()
        frame:ShowCloseButton(true)
        menuState.frame = frame

        -- Кастомная отрисовка фрейма (тёмная тема)
        frame.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, CUI.bg)
            draw.RoundedBoxEx(8, 0, 0, w, 36, Color(27, 35, 48), true, true, false, false)
            draw.SimpleText("Точки спавна", "GRML_Title", 12, 18, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            -- Счётчик точек
            local total = #menuState.globalPoints
            for _, facData in pairs(menuState.factions) do
                local pts = facData.points or facData
                if istable(pts) then total = total + #pts end
            end
            draw.SimpleText("Всего: " .. total, "GRML_Small", w - 12, 18, CUI.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        local tabs = vgui.Create("DPropertySheet", frame)
        tabs:Dock(FILL)
        tabs:DockMargin(4, 40, 4, 4)

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
            -- Поддержка старого формата (просто массив) и нового (таблица)
            local points = facData.points or facData

            local factionPanel = vgui.Create("DPropertySheet", tabs)

            -- Подвкладка: Фракция (общие точки)
            local facPointsPanel = vgui.Create("DPanel", factionPanel)
            facPointsPanel:SetPaintBackground(false)
            menuState.refreshFac[factionName] = buildPointTab(facPointsPanel, points, factionName)
            factionPanel:AddSheet("Фракция", facPointsPanel, "icon16/group.png")

            -- Подвкладка: Роли
            local rolesPanel = vgui.Create("DPanel", factionPanel)
            rolesPanel:SetPaintBackground(false)
            buildRoleTab(rolesPanel, factionName, facData.roles or {})
            factionPanel:AddSheet("Роли", rolesPanel, "icon16/user.png")

            -- Подвкладка: Отделы
            local deptsPanel = vgui.Create("DPanel", factionPanel)
            deptsPanel:SetPaintBackground(false)
            buildDepartmentTab(deptsPanel, factionName, facData.departments or {})
            factionPanel:AddSheet("Отделы", deptsPanel, "icon16/users.png")

            tabs:AddSheet(factionName, factionPanel, "icon16/group.png")
        end

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

    print("[SpawnPoints] Клиентская часть загружена")

end
