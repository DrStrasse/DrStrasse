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
                data.factions[name] = f.SpawnPoints
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

    -- ----------------------------------------------------------------
    -- 6. Основная логика спавна
    -- ----------------------------------------------------------------

    function GetSpawnPointForPlayer(ply)
        if not IsValid(ply) then return nil end
        local factionName = nil

        if Factions then
            local steamID = ply:SteamID()
            for name, f in pairs(Factions) do
                if f.Members and f.Members[steamID] then
                    factionName = name
                    break
                end
            end
        end

        local points = {}
        if factionName then
            points = GetSpawnPointsForFaction(factionName)
        end

        if #points == 0 then
            points = GetGlobalSpawnPoints()
        end

        if #points == 0 then return nil end

        local point = points[math.random(1, #points)]
        return tableToVec(point.pos), tableToAng(point.ang)
    end

    hook.Add("PlayerSpawn", "SpawnAtFactionPoint", function(ply)
        local pos, ang = GetSpawnPointForPlayer(ply)
        if pos then
            ply:SetPos(pos)
            if ang then ply:SetAngles(ang) end
        end
    end)

    -- ----------------------------------------------------------------
    -- 7. NET-обработчики для админ-меню
    -- ----------------------------------------------------------------

    util.AddNetworkString("SpawnAdmin_OpenMenu")
    util.AddNetworkString("SpawnAdmin_SendData")
    util.AddNetworkString("SpawnAdmin_AddPoint")
    util.AddNetworkString("SpawnAdmin_RemovePoint")
    util.AddNetworkString("SpawnAdmin_TeleportToPoint")

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

    print("[SpawnPoints] Серверная часть загружена (карта: " .. game.GetMap() .. ")")

end

-- ================================================================
-- КЛИЕНТСКАЯ ЧАСТЬ (без изменений)
-- ================================================================

if CLIENT then

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
    -- Построение вкладки списка точек
    -- ----------------------------------------------------------------

    local function buildPointTab(panel, points, factionKey)
        local list = vgui.Create("DListView", panel)
        list:Dock(FILL)
        list:DockMargin(5, 5, 5, 5)
        list:AddColumn("X")
        list:AddColumn("Y")
        list:AddColumn("Z")
        list:AddColumn("Pitch")
        list:AddColumn("Yaw")
        list:AddColumn("Roll")

        local function refreshList()
            list:Clear()
            for i, point in ipairs(points) do
                local px, py, pz = fmtPos(point.pos)
                local pp, pyw, pr = fmtAng(point.ang)
                local linePanel = list:AddLine(px, py, pz, pp, pyw, pr)
                linePanel._dataIndex = i
            end
        end

        refreshList()

        --- Получить индекс данных выбранной строки (nil если ничего не выбрано)
        local function getSelectedIndex()
            local line = list:GetSelectedLine()
            if type(line) == "number" then
                return line > 0 and line or nil
            end
            if IsValid(line) and line._dataIndex then
                return line._dataIndex
            end
            return nil
        end

        -- Добавить точку (текущая позиция)
        local btnAdd = vgui.Create("DButton", panel)
        btnAdd:SetText("Добавить точку (текущая позиция)")
        btnAdd:Dock(BOTTOM)
        btnAdd:SetTall(30)
        btnAdd.DoClick = function()
            net.Start("SpawnAdmin_AddPoint")
            net.WriteString(factionKey)
            net.WriteVector(LocalPlayer():GetPos())
            net.WriteAngle(LocalPlayer():GetAngles())
            net.SendToServer()
            notification.AddLegacy("Запрос отправлен...", NOTIFY_GENERIC, 2)
        end

        -- Телепортироваться к выбранной
        local btnTeleport = vgui.Create("DButton", panel)
        btnTeleport:SetText("Телепортироваться к выбранной")
        btnTeleport:Dock(BOTTOM)
        btnTeleport:SetTall(30)
        btnTeleport.DoClick = function()
            local idx = getSelectedIndex()
            if not idx then
                notification.AddLegacy("Выберите точку", NOTIFY_ERROR, 3)
                return
            end
            local point = points[idx]
            if point then
                net.Start("SpawnAdmin_TeleportToPoint")
                net.WriteVector(pointToVec(point.pos))
                net.WriteAngle(pointToAng(point.ang))
                net.SendToServer()
                if IsValid(menuState.frame) then menuState.frame:Close() end
            end
        end

        -- Удалить выбранную
        local btnRemove = vgui.Create("DButton", panel)
        btnRemove:SetText("Удалить выбранную")
        btnRemove:Dock(BOTTOM)
        btnRemove:SetTall(30)
        btnRemove.DoClick = function()
            local idx = getSelectedIndex()
            if not idx then
                notification.AddLegacy("Выберите точку", NOTIFY_ERROR, 3)
                return
            end
            net.Start("SpawnAdmin_RemovePoint")
            net.WriteString(factionKey)
            net.WriteInt(idx, 32)
            net.SendToServer()
            notification.AddLegacy("Запрос отправлен...", NOTIFY_GENERIC, 2)
        end

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
        frame:SetTitle("Управление точками спавна (SuperAdmin)")
        frame:SetSize(800, 600)
        frame:Center()
        frame:MakePopup()
        menuState.frame = frame

        local tabs = vgui.Create("DPropertySheet", frame)
        tabs:Dock(FILL)

        -- Вкладка «Глобальные»
        local globalPanel = vgui.Create("DPanel")
        globalPanel:SetPaintBackground(false)
        menuState.refreshGlobal = buildPointTab(globalPanel, menuState.globalPoints, "__global")
        tabs:AddSheet("Глобальные", globalPanel, "icon16/world.png")

        -- Вкладка для каждой фракции
        local sortedFactions = {}
        for name in pairs(menuState.factions) do table.insert(sortedFactions, name) end
        table.sort(sortedFactions)

        for _, factionName in ipairs(sortedFactions) do
            local points = menuState.factions[factionName]
            local panel = vgui.Create("DPanel")
            panel:SetPaintBackground(false)
            menuState.refreshFac[factionName] = buildPointTab(panel, points, factionName)
            tabs:AddSheet(factionName, panel, "icon16/group.png")
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
