--[[--------------------------------------------------------------------
    sent_vehicle_dealer — cl_init.lua (CLIENT)
    Отрисовка дилера (3D2D подпись) и меню выбора транспорта.
--------------------------------------------------------------------]]

include("shared.lua")

-- ════════════════════════════════════════════════════════
-- Шрифты
-- ════════════════════════════════════════════════════════
surface.CreateFont("VD_Title", {
    font = "Verdana", size = 24, weight = 700, antialias = true
})
surface.CreateFont("VD_Subtitle", {
    font = "Verdana", size = 16, weight = 500, antialias = true
})
surface.CreateFont("VD_Hint", {
    font = "Verdana", size = 13, weight = 400, antialias = true
})
surface.CreateFont("VD_MenuTitle", {
    font = "Verdana", size = 20, weight = 700, antialias = true
})
surface.CreateFont("VD_MenuItem", {
    font = "Verdana", size = 15, weight = 500, antialias = true
})
surface.CreateFont("VD_MenuSmall", {
    font = "Verdana", size = 12, weight = 400, antialias = true
})

local matGlow = Material("sprites/light_glow02_add")
local matRing = Material("models/effects/vol_light001")

-- ════════════════════════════════════════════════════════
-- Отрисовка маркера точки спавна
-- ════════════════════════════════════════════════════════
local function DrawSpawnMarker(spawnPos, spawnAngle, alpha)
    if not spawnPos then return end

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local dist = lp:GetPos():Distance(spawnPos)
    if dist > 600 then return end

    local markerAlpha = math.Clamp((600 - dist) / 150, 0, 1) * alpha
    local pulse = math.abs(math.sin(CurTime() * 2.5)) * 0.4 + 0.6

    -- Пульсирующее кольцо на земле
    local ringPos = spawnPos + Vector(0, 0, 2)
    local ringAng = Angle(0, CurTime() * 30, 0)

    cam.Start3D2D(ringPos, ringAng, 0.15)
        -- Внешнее кольцо
        surface.SetDrawColor(40, 220, 100, math.floor(180 * markerAlpha * pulse))
        surface.DrawOutlinedRect(-60, -60, 120, 120, 3)

        -- Внутреннее кольцо
        surface.SetDrawColor(40, 220, 100, math.floor(120 * markerAlpha * pulse))
        surface.DrawOutlinedRect(-40, -40, 80, 80, 2)

        -- Центральная точка
        surface.SetDrawColor(80, 255, 140, math.floor(200 * markerAlpha * pulse))
        surface.DrawRect(-4, -4, 8, 8)

        -- Стрелка направления
        if spawnAngle then
            local fwd = spawnAngle:Forward()
            local arrowX = fwd.x * 50
            local arrowY = fwd.y * 50
            surface.SetDrawColor(40, 220, 100, math.floor(160 * markerAlpha * pulse))
            surface.DrawLine(0, 0, arrowX, arrowY)
        end

        -- Текст "SPAWN"
        draw.SimpleText(
            "SPAWN",
            "VD_MenuSmall",
            0, 70,
            Color(80, 255, 140, math.floor(200 * markerAlpha * pulse)),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    cam.End3D2D()

    -- Спрайт свечения над точкой
    render.SetMaterial(matGlow)
    render.DrawSprite(
        spawnPos + Vector(0, 0, 30),
        20 * pulse, 20 * pulse,
        Color(40, 220, 100, math.floor(100 * markerAlpha * pulse))
    )
end

-- ════════════════════════════════════════════════════════
-- 3D2D Отрисовка над дилером
-- ════════════════════════════════════════════════════════
function ENT:Draw()
    self:DrawModel()

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local dist = lp:GetPos():Distance(self:GetPos())
    if dist > 400 then return end

    local alpha = math.Clamp((400 - dist) / 120, 0, 1)
    local name  = self:GetDealerName()
    if name == "" then name = "Дилер транспорта" end

    local pos = self:GetPos() + Vector(0, 0, 85)
    local ang = lp:EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    cam.Start3D2D(pos, ang, 0.08)

        -- Фон
        surface.SetDrawColor(10, 20, 40, math.floor(210 * alpha))
        surface.DrawRect(-120, -28, 240, 56)

        -- Синяя рамка
        surface.SetDrawColor(60, 140, 220, math.floor(210 * alpha))
        surface.DrawOutlinedRect(-120, -28, 240, 56, 2)

        -- Имя дилера
        draw.SimpleText(
            name,
            "VD_Title",
            0, -10,
            Color(100, 200, 255, math.floor(255 * alpha)),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )

        -- Подсказка
        draw.SimpleText(
            "[E] Открыть каталог",
            "VD_Subtitle",
            0, 14,
            Color(180, 220, 255, math.floor(200 * alpha)),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )

    cam.End3D2D()

    -- Мягкое свечение
    if dist < 250 then
        local pulse = math.abs(math.sin(CurTime() * 2)) * 0.3 + 0.7
        local sz = 16 + pulse * 6
        render.SetMaterial(matGlow)
        render.DrawSprite(
            self:GetPos() + Vector(0, 0, 80),
            sz, sz,
            Color(60, 160, 255, math.floor(120 * alpha * pulse))
        )
    end

    -- ═══ Отрисовка маркера точки спавна ═══
    local hasCustom = false
    pcall(function() hasCustom = self:GetHasCustomSpawn() end)

    if hasCustom then
        local spawnPos, spawnAngle
        pcall(function()
            spawnPos = self:GetSpawnPos()
            spawnAngle = self:GetSpawnAngle()
        end)
        if spawnPos then
            DrawSpawnMarker(spawnPos, spawnAngle, alpha)
        end
    end
end

-- ════════════════════════════════════════════════════════
-- Меню выбора транспорта
-- ════════════════════════════════════════════════════════
local function OpenVehicleMenu(dealerID, dealerName, vlist)
    if not vlist or #vlist == 0 then
        chat.AddText(Color(255, 100, 100), "[VD] ", Color(200, 200, 200), "У вас нет доступа к транспорту у этого дилера")
        return
    end

    local frame = vgui.Create("DFrame")
    frame:SetTitle(dealerName or "Дилер транспорта")
    frame:SetSize(560, 480)
    frame:Center()
    frame:MakePopup()
    frame:SetSkin("Default")

    local oldPaint = frame.Paint
    frame.Paint = function(self, w, h)
        surface.SetDrawColor(15, 25, 45, 245)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(60, 140, 220, 200)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        -- Заголовок
        surface.SetDrawColor(20, 40, 70, 250)
        surface.DrawRect(0, 0, w, 28)
        draw.SimpleText(self:GetTitle(), "VD_MenuTitle", w / 2, 14, Color(100, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Список транспорта
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(8, 32, 8, 8)

    local sbar = scroll:GetVBar()
    sbar:SetWide(6)
    sbar.Paint = function(self, w, h)
        surface.SetDrawColor(30, 50, 80, 200)
        surface.DrawRect(0, 0, w, h)
    end
    sbar.btnUp.Paint = function() end
    sbar.btnDown.Paint = function() end
    sbar.btnGrip.Paint = function(self, w, h)
        surface.SetDrawColor(60, 140, 220, 180)
        surface.DrawRect(0, 0, w, h)
    end

    for i, veh in ipairs(vlist) do
        local row = scroll:Add("DPanel")
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 4)
        row:SetTall(56)

        -- Определяем цвет по источнику доступа
        local sourceColor = Color(120, 150, 180)
        local sourceText = ""
        if veh.source == "faction" then
            sourceColor = Color(80, 180, 255)
            sourceText = "Фракция"
        elseif veh.source == "role" then
            sourceColor = Color(180, 120, 255)
            sourceText = "Ранг"
        elseif veh.source == "department" then
            sourceColor = Color(255, 180, 60)
            sourceText = "Отдел"
        elseif veh.source == "personal" then
            sourceColor = Color(100, 220, 100)
            sourceText = "Лично"
        end

        row.Paint = function(self, w, h)
            -- Фон строки
            surface.SetDrawColor(25, 40, 65, 220)
            surface.DrawRect(0, 0, w, h)
            -- Рамка
            surface.SetDrawColor(50, 100, 160, 120)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            -- Название
            local displayName = veh.name or veh.class or "Неизвестно"
            draw.SimpleText(displayName, "VD_MenuItem", 12, 12, Color(220, 235, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- Класс
            draw.SimpleText(veh.class or "", "VD_MenuSmall", 12, 32, Color(120, 150, 180), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            -- Источник доступа
            if sourceText ~= "" then
                draw.SimpleText(sourceText, "VD_MenuSmall", 12, 46, sourceColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            -- Цена
            if veh.price and veh.price > 0 then
                local priceText = GRM and GRM.Format and GRM.Format(veh.price) or tostring(veh.price) .. "$"
                draw.SimpleText(priceText, "VD_MenuItem", w - 90, 16, Color(100, 220, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end

        -- Кнопка "Спавн"
        local btn = vgui.Create("DButton", row)
        btn:Dock(RIGHT)
        btn:DockMargin(4, 10, 8, 10)
        btn:SetWide(70)
        btn:SetText("")
        btn.Paint = function(self, w, h)
            local col = self:IsHovered() and Color(80, 200, 120, 240) or Color(50, 150, 90, 200)
            surface.SetDrawColor(col)
            surface.DrawRect(0, 0, w, h)
            draw.SimpleText("Спавн", "VD_MenuSmall", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            net.Start("VD_SpawnRequest")
                net.WriteString(dealerID)
                net.WriteString(veh.class or "")
            net.SendToServer()
            frame:Close()
        end
    end

    -- Подсказка внизу
    local hint = vgui.Create("DLabel", frame)
    hint:Dock(BOTTOM)
    hint:DockMargin(8, 0, 8, 4)
    hint:SetText("Транспорт по вашему доступу  |  /vd_remove — удалить свой транспорт  |  /vshop — купить доступ")
    hint:SetFont("VD_MenuSmall")
    hint:SetTextColor(Color(140, 160, 180))
    hint:SetContentAlignment(5)
end

-- ════════════════════════════════════════════════════════
-- Меню конфигурации (суперадмин) — с вкладками фракций
-- ════════════════════════════════════════════════════════
local function OpenConfigMenu(dealerID, dealerName, dealerModel, vehicles, serverVehicleList)
    vehicles = vehicles or {}
    serverVehicleList = serverVehicleList or {}

    local frame = vgui.Create("DFrame")
    frame:SetTitle("Конфигурация дилера: " .. (dealerName or ""))
    frame:SetSize(900, 700)
    frame:Center()
    frame:MakePopup()

    frame.Paint = function(self, w, h)
        surface.SetDrawColor(15, 25, 45, 245)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(220, 140, 40, 200)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        surface.SetDrawColor(40, 30, 10, 250)
        surface.DrawRect(0, 0, w, 28)
        draw.SimpleText(self:GetTitle(), "VD_MenuTitle", w / 2, 14, Color(255, 200, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- ═══ Верхняя панель: имя + модель ═══
    local topPanel = vgui.Create("DPanel", frame)
    topPanel:Dock(TOP)
    topPanel:SetTall(90)
    topPanel:DockMargin(10, 34, 10, 4)
    topPanel:SetPaintBackground(false)

    local nameLabel = vgui.Create("DLabel", topPanel)
    nameLabel:SetPos(0, 4) nameLabel:SetSize(100, 20)
    nameLabel:SetText("Имя дилера:") nameLabel:SetFont("VD_MenuSmall")
    nameLabel:SetTextColor(Color(200, 200, 200))

    local nameEntry = vgui.Create("DTextEntry", topPanel)
    nameEntry:SetPos(110, 2) nameEntry:SetSize(300, 22)
    nameEntry:SetText(dealerName or "") nameEntry:SetFont("VD_MenuSmall")

    local modelLabel = vgui.Create("DLabel", topPanel)
    modelLabel:SetPos(0, 34) modelLabel:SetSize(100, 20)
    modelLabel:SetText("Модель .mdl:") modelLabel:SetFont("VD_MenuSmall")
    modelLabel:SetTextColor(Color(200, 200, 200))

    local modelEntry = vgui.Create("DTextEntry", topPanel)
    modelEntry:SetPos(110, 32) modelEntry:SetSize(500, 22)
    modelEntry:SetText(dealerModel or "") modelEntry:SetFont("VD_MenuSmall")
    modelEntry:SetPlaceholderText("models/Humans/Group01/Male_02.mdl")

    local infoLabel = vgui.Create("DLabel", topPanel)
    infoLabel:SetPos(0, 62) infoLabel:SetSize(860, 20)
    infoLabel:SetText("Настройте транспорт: Глобальный (все), Без фракции (только вне фракций), по фракциям (только члены).")
    infoLabel:SetFont("VD_MenuSmall")
    infoLabel:SetTextColor(Color(160, 180, 200))

    -- ═══ Информация о количестве транспорта на сервере ═══
    local vehCountLabel = vgui.Create("DLabel", frame)
    vehCountLabel:Dock(TOP)
    vehCountLabel:SetTall(18)
    vehCountLabel:DockMargin(16, 0, 10, 2)
    vehCountLabel:SetText("Транспорт на сервере: " .. #serverVehicleList .. " ед. (GMod + SimFPhys + LVS)")
    vehCountLabel:SetFont("VD_MenuSmall")
    vehCountLabel:SetTextColor(Color(100, 200, 100))

    -- ═══ Вкладки фракций ═══
    local tabs = vgui.Create("DPropertySheet", frame)
    tabs:Dock(FILL)
    tabs:DockMargin(6, 4, 6, 44)

    function tabs:Paint(w, h)
        surface.SetDrawColor(20, 30, 50, 240)
        surface.DrawRect(0, 0, w, h)
    end

    -- Рабочая копия vehicles для редактирования
    local editVehicles = table.Copy(vehicles)

    -- Получаем все фракции из глобальных данных
    local factionNames = {}
    if FactionsData then
        for name, _ in pairs(FactionsData) do
            table.insert(factionNames, name)
        end
    end
    table.sort(factionNames)

    -- Используем список транспорта с сервера
    local allVehicles = serverVehicleList

    -- ═══ Функция создания панели с чекбоксами транспорта ═══
    local function CreateVehicleCheckboxPanel(parentTabs, tabTitle, tabIcon, infoText, infoColor, storageKey)
        local panel = vgui.Create("DPanel")
        panel:SetPaintBackground(false)
        panel:DockPadding(4, 4, 4, 4)

        local info = vgui.Create("DLabel", panel)
        info:Dock(TOP) info:SetTall(24) info:DockMargin(4, 0, 4, 4)
        info:SetText(infoText)
        info:SetFont("VD_MenuSmall") info:SetTextColor(infoColor)

        -- Поиск/фильтр
        local searchPanel = vgui.Create("DPanel", panel)
        searchPanel:Dock(TOP) searchPanel:SetTall(26) searchPanel:DockMargin(4, 0, 4, 4)
        searchPanel:SetPaintBackground(false)

        local searchLabel = vgui.Create("DLabel", searchPanel)
        searchLabel:SetPos(0, 3) searchLabel:SetSize(50, 20)
        searchLabel:SetText("Поиск:") searchLabel:SetFont("VD_MenuSmall")
        searchLabel:SetTextColor(Color(180, 180, 200))

        local searchEntry = vgui.Create("DTextEntry", searchPanel)
        searchEntry:SetPos(55, 0) searchEntry:SetSize(300, 24)
        searchEntry:SetFont("VD_MenuSmall")
        searchEntry:SetPlaceholderText("Введите название или класс...")

        -- Счётчик выбранных
        local countLabel = vgui.Create("DLabel", searchPanel)
        countLabel:SetPos(370, 3) countLabel:SetSize(200, 20)
        countLabel:SetFont("VD_MenuSmall")
        countLabel:SetTextColor(Color(100, 220, 100))

        local scroll = vgui.Create("DScrollPanel", panel)
        scroll:Dock(FILL)

        -- Инициализируем набор
        if not editVehicles[storageKey] then editVehicles[storageKey] = {} end
        local checkSet = {}
        for _, v in ipairs(editVehicles[storageKey]) do
            checkSet[v.class] = true
        end

        -- Обновляем счётчик
        local function updateCount()
            local count = 0
            for _, _ in pairs(checkSet) do count = count + 1 end
            if IsValid(countLabel) then
                countLabel:SetText("Выбрано: " .. count .. " / " .. #allVehicles)
            end
        end
        updateCount()

        -- Строки чекбоксов
        local rows = {}

        for _, veh in ipairs(allVehicles) do
            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP) row:SetTall(26) row:DockMargin(0, 1, 0, 1)

            local isChecked = checkSet[veh.class] or false

            row.Paint = function(self, w, h)
                if checkSet[veh.class] then
                    surface.SetDrawColor(30, 50, 35, 180)
                else
                    surface.SetDrawColor(25, 30, 40, 120)
                end
                surface.DrawRect(0, 0, w, h)
            end

            local chk = vgui.Create("DCheckBoxLabel", row)
            chk:SetPos(6, 3) chk:SetSize(550, 20)
            chk:SetText(veh.name .. "  [" .. veh.class .. "]")
            chk:SetFont("VD_MenuSmall") chk:SetTextColor(Color(220, 220, 230))
            chk:SetValue(isChecked)
            chk.OnChange = function(_, val)
                if val then
                    checkSet[veh.class] = true
                else
                    checkSet[veh.class] = nil
                end
                updateCount()
            end

            -- Категория/аддон справа
            local catLabel = vgui.Create("DLabel", row)
            catLabel:SetPos(570, 3) catLabel:SetSize(200, 20)
            local catText = (veh.category or "")
            if veh.addon and veh.addon ~= "gmod" then
                catText = catText .. " (" .. veh.addon .. ")"
            end
            catLabel:SetText(catText)
            catLabel:SetFont("VD_MenuSmall") catLabel:SetTextColor(Color(120, 140, 160))

            row._veh = veh
            row._chk = chk
            table.insert(rows, row)
        end

        -- Фильтрация по поиску
        searchEntry.OnChange = function()
            local query = string.lower(searchEntry:GetText() or "")
            for _, row in ipairs(rows) do
                if IsValid(row) and row._veh then
                    local match = query == ""
                        or string.find(string.lower(row._veh.name or ""), query, 1, true)
                        or string.find(string.lower(row._veh.class or ""), query, 1, true)
                        or string.find(string.lower(row._veh.category or ""), query, 1, true)
                    row:SetVisible(match)
                end
            end
            scroll:InvalidateLayout()
        end

        -- Кнопки "Выбрать все" / "Снять все"
        local btnPanel = vgui.Create("DPanel", panel)
        btnPanel:Dock(BOTTOM) btnPanel:SetTall(28) btnPanel:DockMargin(4, 4, 4, 0)
        btnPanel:SetPaintBackground(false)

        local btnAll = vgui.Create("DButton", btnPanel)
        btnAll:SetPos(0, 0) btnAll:SetSize(120, 26) btnAll:SetText("Выбрать все")
        btnAll:SetFont("VD_MenuSmall")
        btnAll.Paint = function(self, w, h)
            surface.SetDrawColor(self:IsHovered() and Color(60, 140, 80, 200) or Color(40, 100, 60, 180))
            surface.DrawRect(0, 0, w, h)
            draw.SimpleText("✓ Выбрать все", "VD_MenuSmall", w/2, h/2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btnAll.DoClick = function()
            for _, row in ipairs(rows) do
                if IsValid(row) and row._veh and row:IsVisible() then
                    checkSet[row._veh.class] = true
                    if IsValid(row._chk) then row._chk:SetValue(true) end
                end
            end
            updateCount()
        end

        local btnNone = vgui.Create("DButton", btnPanel)
        btnNone:SetPos(130, 0) btnNone:SetSize(120, 26) btnNone:SetText("Снять все")
        btnNone:SetFont("VD_MenuSmall")
        btnNone.Paint = function(self, w, h)
            surface.SetDrawColor(self:IsHovered() and Color(140, 60, 60, 200) or Color(100, 40, 40, 180))
            surface.DrawRect(0, 0, w, h)
            draw.SimpleText("✕ Снять все", "VD_MenuSmall", w/2, h/2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btnNone.DoClick = function()
            for _, row in ipairs(rows) do
                if IsValid(row) and row._veh and row:IsVisible() then
                    checkSet[row._veh.class] = nil
                    if IsValid(row._chk) then row._chk:SetValue(false) end
                end
            end
            updateCount()
        end

        panel._checkSet = checkSet
        panel._storageKey = storageKey

        parentTabs:AddSheet(tabTitle, panel, tabIcon)
        return panel
    end

    -- ═══ Вкладка: Глобальный транспорт (для ВСЕХ) ═══
    local globalPanel = CreateVehicleCheckboxPanel(
        tabs,
        "🌐 Глобальный",
        "icon16/world.png",
        "Глобальный транспорт — доступен ВСЕМ игрокам, независимо от фракции",
        Color(200, 200, 100),
        "__global"
    )

    -- ═══ Вкладка: Без фракции (для игроков вне фракций) ═══
    local nofactionPanel = CreateVehicleCheckboxPanel(
        tabs,
        "👤 Без фракции",
        "icon16/user.png",
        "Транспорт для игроков БЕЗ фракции — видят только те, кто не состоит ни в одной фракции",
        Color(180, 180, 255),
        "__nofaction"
    )

    -- ═══ Вкладки фракций ═══
    for _, factionName in ipairs(factionNames) do
        local fData = FactionsData[factionName]
        local fColor = (fData and fData.Color) and Color(fData.Color.r or 255, fData.Color.g or 200, fData.Color.b or 50) or Color(255, 200, 50)

        CreateVehicleCheckboxPanel(
            tabs,
            "🎖 " .. factionName,
            "icon16/group.png",
            "Транспорт для фракции: " .. factionName .. " — видят только члены этой фракции",
            fColor,
            factionName
        )
    end

    -- ═══ Кнопка сохранения ═══
    local saveBtn = vgui.Create("DButton", frame)
    saveBtn:Dock(BOTTOM)
    saveBtn:DockMargin(10, 4, 10, 8)
    saveBtn:SetTall(32)
    saveBtn:SetText("")
    saveBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and Color(220, 160, 40, 240) or Color(180, 120, 20, 200)
        surface.SetDrawColor(col)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText("💾 Сохранить конфигурацию", "VD_MenuItem", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    saveBtn.DoClick = function()
        local newName  = nameEntry:GetText()
        local newModel = modelEntry:GetText()

        -- Собираем все списки из вкладок
        local newVehicles = {}

        for _, sheet in ipairs(tabs.Items) do
            if IsValid(sheet.Panel) and sheet.Panel._checkSet and sheet.Panel._storageKey then
                local key = sheet.Panel._storageKey
                local cSet = sheet.Panel._checkSet
                newVehicles[key] = {}
                for class, _ in pairs(cSet) do
                    table.insert(newVehicles[key], {
                        class = class,
                        name = class,
                        price = 0,
                    })
                end
            end
        end

        net.Start("VD_ConfigSave")
            net.WriteString(dealerID)
            net.WriteString(newName)
            net.WriteString(newModel)
            net.WriteTable(newVehicles)
        net.SendToServer()

        chat.AddText(Color(100, 220, 100), "[VD] Конфигурация сохранена")
        frame:Close()
    end
end

-- ════════════════════════════════════════════════════════
-- Сетевые обработчики (клиент)
-- ════════════════════════════════════════════════════════

-- Открытие меню выбора транспорта
net.Receive("VD_OpenMenu", function()
    local dealerID   = net.ReadString()
    local dealerName = net.ReadString()
    local vlist      = net.ReadTable()
    OpenVehicleMenu(dealerID, dealerName, vlist)
end)

-- Результат спавна
net.Receive("VD_SpawnResult", function()
    local ok  = net.ReadBool()
    local msg = net.ReadString()
    if ok then
        chat.AddText(Color(100, 220, 100), "[VD] ", Color(200, 255, 200), msg)
    else
        chat.AddText(Color(255, 100, 100), "[VD] ", Color(255, 200, 200), msg)
    end
end)

-- Открытие конфигурации (админ)
net.Receive("VD_ConfigData", function()
    local dealerID         = net.ReadString()
    local dealerName       = net.ReadString()
    local dealerModel      = net.ReadString()
    local vehicles         = net.ReadTable()
    local serverVehicleList = net.ReadTable()
    OpenConfigMenu(dealerID, dealerName, dealerModel, vehicles, serverVehicleList)
end)

print("[VD] Клиентская часть sent_vehicle_dealer загружена")
