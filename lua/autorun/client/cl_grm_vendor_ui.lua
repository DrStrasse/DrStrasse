--[[--------------------------------------------------------------------
    GRM Vendor Client UI v1.1 (Код 111)
    Исправления:
    - Dock вместо SetPos (кнопки не съезжают)
    - Правильный DModelPanel с LayoutEntity
    - Проверка GRM.HasMoney/Format перед использованием
    - Нормальная сетка товаров
----------------------------------------------------------------------]]

if not CLIENT then return end

GRM = GRM or {}
GRM.Vendor = GRM.Vendor or {}
GRM.Vendor.UI = GRM.Vendor.UI or {}

-- ========== ЦВЕТОВАЯ СХЕМА (в стиле HUD v10.2) ==========
local CUI = {
    bg         = Color(19, 24, 33, 248),
    panel      = Color(33, 42, 56, 245),
    accent     = Color(70, 155, 255),
    green      = Color(55, 185, 105),
    red        = Color(205, 70, 65),
    yellow     = Color(235, 180, 60),
    text       = Color(240, 244, 250),
    dim        = Color(166, 176, 191),
    slotBg     = Color(20, 22, 30, 220),
    slotBorder = Color(60, 65, 80, 200),
    header     = Color(27, 35, 48),
}

-- ========== ШРИФТЫ ==========
surface.CreateFont("GRM_Vendor_Title", {
    font = "Roboto", size = 22, weight = 800, extended = true,
})
surface.CreateFont("GRM_Vendor_Item", {
    font = "Roboto", size = 14, weight = 500, extended = true,
})
surface.CreateFont("GRM_Vendor_Small", {
    font = "Roboto", size = 12, weight = 400, extended = true,
})
surface.CreateFont("GRM_Vendor_Price", {
    font = "Roboto", size = 14, weight = 700, extended = true,
})
surface.CreateFont("GRM_Vendor_Button", {
    font = "Roboto", size = 13, weight = 600, extended = true,
})

-- ========== ХЕЛПЕРЫ ==========
local function money(n)
    return GRM.Format and GRM.Format(n) or (tostring(n) .. " GRM")
end

local function hasMoney(amount)
    return GRM.HasMoney and GRM.HasMoney(LocalPlayer(), amount) or true
end

local TITLES = {
    weapon = "🔫 Арсенал",
    ore    = "⛏️ Скупка руды",
    food   = " Ларёк еды",
    rare   = "💎 Редкости",
}

-- ========== ПЕРЕМЕННЫЕ СОСТОЯНИЯ ==========
local vendorEnt  = nil
local vendorType = nil
local catalog    = {}

-- ========== ОТКРЫТИЕ ОКНА ==========
net.Receive("GRM_Vendor_Open", function()
    vendorEnt  = net.ReadEntity()
    vendorType = net.ReadString()
    catalog    = net.ReadTable() or {}

    -- Закрыть предыдущее окно
    if IsValid(GRM.Vendor.UI.Frame) then
        GRM.Vendor.UI.Frame:Close()
    end

    -- Главный фрейм
    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(780, 580)
    frame:Center()
    frame:MakePopup()
    frame:ShowCloseButton(false)
    GRM.Vendor.UI.Frame = frame

    -- Рисование фона
    frame.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, CUI.bg)
        -- Шапка
        draw.RoundedBoxEx(8, 0, 0, w, 44, CUI.header, true, true, false, false)
        -- Заголовок
        draw.SimpleText(
            TITLES[vendorType] or "🏪 Торгаш",
            "GRM_Vendor_Title", 16, 22, CUI.text,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER
        )
        -- Баланс
        local bal = GRM.PlayerBalance or 0
        draw.SimpleText(
            "Наличные: " .. money(bal),
            "GRM_Vendor_Price", w - 16, 22, CUI.green,
            TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER
        )
    end

    -- Кнопка закрытия
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(frame:GetWide() - 38, 8)
    closeBtn:SetSize(24, 24)
    closeBtn:SetText("")
    closeBtn.DoClick = function() frame:Close() end
    closeBtn.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(196, 62, 62) or Color(46, 56, 74))
        surface.SetDrawColor(240, 242, 246)
        surface.DrawLine(7, 7, w - 7, h - 7)
        surface.DrawLine(7, h - 7, w - 7, 7)
    end

    -- Группировка товаров по категориям
    local cats = {}
    for id, item in pairs(catalog) do
        local cat = item.category or "Прочее"
        cats[cat] = cats[cat] or {}
        cats[cat][id] = item
    end

    -- PropertySheet с вкладками категорий
    local sheet = vgui.Create("DPropertySheet", frame)
    sheet:Dock(FILL)
    sheet:DockMargin(8, 52, 8, 8)
    sheet.tabHeight = 28

    -- Создаём вкладки
    for catName, items in pairs(cats) do
        local panel = vgui.Create("DScrollPanel", sheet)
        panel:Dock(FILL)
        panel:DockMargin(4, 4, 4, 4)
        panel.Paint = function(_, w, h)
            draw.RoundedBox(4, 0, 0, w, h, CUI.panel)
        end

        local canvas = panel:GetCanvas()
        local yOffset = 6

        -- Создаём строки товаров
        for id, item in pairs(items) do
            local row = CreateVendorRow(canvas, panel, id, item, vendorType, vendorEnt, yOffset)
            yOffset = yOffset + row:GetTall() + 4
        end

        -- Обновление при ресайзе
        panel.OnSizeChanged = function(_, w)
            for _, row in ipairs(canvas:GetChildren()) do
                if row._isVendorRow then
                    row:SetWide(w - 16)
                    -- Перераспределяем кнопки через Dock
                end
            end
        end

        -- Добавляем вкладку
        local tabIcon = "icon16/box.png"
        if vendorType == "weapon" then tabIcon = "icon16/bomb.png"
        elseif vendorType == "ore" then tabIcon = "icon16/database.png"
        elseif vendorType == "food" then tabIcon = "icon16/heart.png"
        elseif vendorType == "rare" then tabIcon = "icon16/star.png"
        end

        local sh = sheet:AddSheet(catName, panel, tabIcon)
        if sh and sh.Tab then
            sh.Tab:SetFont("GRM_Vendor_Item")
        end
    end
end)

-- ========== СОЗДАНИЕ СТРОКИ ТОВАРА ==========
function CreateVendorRow(parent, scrollPanel, id, item, vType, ent, yPos)
    local row = vgui.Create("DPanel", parent)
    row:SetTall(76)
    row:SetWide(parent:GetWide() - 16)
    row:Dock(TOP)
    row:DockMargin(4, 2, 4, 2)
    row._isVendorRow = true

    row.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, CUI.slotBg)
        surface.SetDrawColor(CUI.slotBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        -- Название товара
        draw.SimpleText(item.name, "GRM_Vendor_Item", 82, 8, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        -- Описание
        draw.SimpleText(item.desc or "", "GRM_Vendor_Small", 82, 28, CUI.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        -- Цена
        draw.SimpleText("Цена: " .. money(item.price), "GRM_Vendor_Price", w - 120, 8, CUI.yellow, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

        -- Доп. информация
        local infoY = 48
        if item.hunger then
            draw.SimpleText("Сытость: +" .. item.hunger .. "  HP: +" .. (item.health or 0), "GRM_Vendor_Small", 82, infoY, CUI.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        if item.maxStack then
            draw.SimpleText("Макс. стак: " .. item.maxStack, "GRM_Vendor_Small", 82, infoY, CUI.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        if item.license and item.license ~= "gun" then
            local licText = item.license == "police" and " Только полиция" or "🔒 Только админ"
            draw.SimpleText(licText, "GRM_Vendor_Small", 82, infoY + (item.hunger and 14 or 0), Color(255, 160, 60), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end

    -- DModelPanel с правильной моделью
    if item.model and item.model ~= "" and util.IsValidModel(item.model) then
        local mdl = vgui.Create("DModelPanel", row)
        mdl:SetPos(4, 4)
        mdl:SetSize(70, 68)
        mdl:SetModel(item.model)
        mdl:SetCamPos(Vector(25, 25, 15))
        mdl:SetLookAt(Vector(0, 0, 0))
        mdl:SetFOV(30)
        -- ВАЖНО: LayoutEntity должен быть пустым для статичной модели
        function mdl:LayoutEntity(ent) end
        mdl.Entity:SetAngles(Angle(0, CurTime() * 30 % 360, 0)) -- медленное вращение
    else
        -- Фолбэк: иконка предмета (если есть)
        local icon = vgui.Create("SpawnIcon", row)
        icon:SetPos(4, 4)
        icon:SetSize(70, 68)
        icon:SetModel(item.model or "models/props_junk/garbage_metalcan001a.mdl")
    end

    -- Правая панель с кнопками (Dock)
    local rightPanel = vgui.Create("DPanel", row)
    rightPanel:Dock(RIGHT)
    rightPanel:SetWide(110)
    rightPanel:DockMargin(4, 4, 8, 4)
    rightPanel:SetPaintBackground(false)

    -- Кнопка КУПИТЬ
    local buyBtn = vgui.Create("DButton", rightPanel)
    buyBtn:Dock(TOP)
    buyBtn:SetTall(30)
    buyBtn:DockMargin(0, 4, 0, 0)
    buyBtn:SetText("")
    buyBtn.DoClick = function()
        if not hasMoney(item.price) then
            GRM.Notify(LocalPlayer(), "Недостаточно средств!", 255, 100, 100)
            return
        end
        net.Start("GRM_Vendor_Buy")
            net.WriteEntity(ent)
            net.WriteString(id)
        net.SendToServer()
    end
    buyBtn.Paint = function(s, w, h)
        local can = hasMoney(item.price)
        local col = not can and Color(70, 75, 84) or (s:IsHovered() and Color(75, 170, 95) or CUI.green)
        draw.RoundedBox(5, 0, 0, w, h, col)
        draw.SimpleText("Купить", "GRM_Vendor_Button", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- Кнопка ПРОДАТЬ (если есть скупочная цена)
    local sellPrice = GRM.Vendor and GRM.Vendor.GetSellPrice and GRM.Vendor.GetSellPrice(LocalPlayer(), vType, id) or 0
    if sellPrice > 0 then
        local sellBtn = vgui.Create("DButton", rightPanel)
        sellBtn:Dock(TOP)
        sellBtn:SetTall(24)
        sellBtn:DockMargin(0, 4, 0, 0)
        sellBtn:SetText("")
        sellBtn.DoClick = function()
            Derma_StringRequest("Сколько продать?", "Введите количество:", "1", function(val)
                local c = math.max(1, math.floor(tonumber(val) or 1))
                net.Start("GRM_Vendor_Sell")
                    net.WriteEntity(ent)
                    net.WriteString(id)
                    net.WriteUInt(c, 16)
                net.SendToServer()
            end)
        end
        sellBtn.Paint = function(s, w, h)
            local col = s:IsHovered() and Color(180, 90, 80) or CUI.red
            draw.RoundedBox(5, 0, 0, w, h, col)
            draw.SimpleText("Продать", "GRM_Vendor_Small", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Цена скупки под кнопкой
        local priceLabel = vgui.Create("DLabel", rightPanel)
        priceLabel:Dock(TOP)
        priceLabel:DockMargin(0, 2, 0, 0)
        priceLabel:SetText("Скупка: " .. money(sellPrice))
        priceLabel:SetFont("GRM_Vendor_Small")
        priceLabel:SetTextColor(CUI.dim)
        priceLabel:SetContentAlignment(5)
    end

    return row
end

print("[GRM Vendor] Client UI v1.1 loaded (Code 111)")
