--[[--------------------------------------------------------------------
    GRM Factory Full Cycle — client UI (Код 41)
----------------------------------------------------------------------]]
if not CLIENT then return end

include("autorun/sh_grm_factory_fullcycle_config.lua")
include("autorun/sh_grm_factory_fullcycle_entities.lua")

GRM = GRM or {}
GRM.FactoryCycle = GRM.FactoryCycle or {}
local FC = GRM.FactoryCycle

local NET_OPEN_CRAFT = "GRM_FC_OpenCraft"
local NET_OPEN_STORAGE = "GRM_FC_OpenStorage"
local NET_OPEN_SCRAP = "GRM_FC_OpenScrap"
local NET_OPEN_TERMINAL = "GRM_FC_OpenTerminal"
local NET_ACTION = "GRM_FC_Action"
local NET_RESULT = "GRM_FC_Result"
local NET_QTE_START = "GRM_FC_QTE_Start"
local NET_QTE_STATE = "GRM_FC_QTE_State"
local NET_QTE_FINISH = "GRM_FC_QTE_Finish"
local NET_QTE_INPUT = "GRM_FC_QTE_Input"
local NET_QTE_ABORT = "GRM_FC_QTE_Abort"
local NET_OPEN_WEAPON_BUYER = "GRM_FC_OpenWeaponBuyer"
local NET_OPEN_WEAPON_LOCKER = "GRM_FC_OpenWeaponLocker"
local NET_OPEN_WEAPON_ADMIN = "GRM_FC_OpenWeaponAdmin"

surface.CreateFont("GRMFC_Title", { font = "Roboto", size = 21, weight = 800, extended = true })
surface.CreateFont("GRMFC_Normal", { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("GRMFC_Small", { font = "Roboto", size = 12, weight = 400, extended = true })
surface.CreateFont("GRMFC_ScrapLabel", { font = "Roboto", size = 18, weight = 800, extended = true })
surface.CreateFont("GRMFC_QTEArrow", { font = "Roboto", size = 76, weight = 1000, extended = true, antialias = true })

local C = {
    bg = Color(18, 23, 31, 248), panel = Color(32, 41, 54, 245), hover = Color(47, 60, 78, 245),
    accent = Color(67, 155, 255), green = Color(54, 186, 105), red = Color(205, 70, 65),
    yellow = Color(235, 178, 60), text = Color(240, 244, 250), dim = Color(166, 176, 191),
}

local function notify(message, success)
    notification.AddLegacy(tostring(message or ""), success and NOTIFY_GENERIC or NOTIFY_ERROR, 4)
    surface.PlaySound(success and "buttons/button17.wav" or "buttons/button10.wav")
end

local function itemName(id)
    if GRM and GRM.Inventory and GRM.Inventory.GetItemDef then
        local d = GRM.Inventory.GetItemDef(id)
        if d and d.name then return d.name end
    end
    local names = { scrap_metal = "Металлолом", components_box = "Ящик комплектующих", gpu_basic = "Базовая GPU", gpu_mid = "Средняя GPU", gpu_premium = "Премиум GPU" }
    return names[id] or tostring(id)
end

local function money(amount)
    return GRM and GRM.Format and GRM.Format(amount) or (tostring(amount) .. " GRM")
end

local function frame(title, w, h)
    local f = vgui.Create("DFrame")
    f:SetTitle("")
    f:SetSize(w, h)
    f:Center()
    f:MakePopup()
    f.Paint = function(_, pw, ph)
        draw.RoundedBox(8, 0, 0, pw, ph, C.bg)
        draw.RoundedBoxEx(8, 0, 0, pw, 36, Color(26, 34, 46), true, true, false, false)
        draw.SimpleText(title, "GRMFC_Title", 13, 18, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return f
end

local function button(parent, text, color, w, h)
    local b = vgui.Create("DButton", parent)
    b:SetText(text); b:SetFont("GRMFC_Normal"); b:SetTextColor(color_white)
    if w then b:SetWide(w) end
    if h then b:SetTall(h) end
    b.Paint = function(self, pw, ph)
        local col = color
        if not self:IsEnabled() then col = Color(70, 75, 84)
        elseif self:IsHovered() then col = Color(math.min(color.r + 20, 255), math.min(color.g + 20, 255), math.min(color.b + 20, 255)) end
        draw.RoundedBox(5, 0, 0, pw, ph, col)
    end
    return b
end

local function action(name, ent, writer)
    if not IsValid(ent) then return end
    net.Start(NET_ACTION)
        net.WriteString(name)
        net.WriteEntity(ent)
        if writer then writer() end
    net.SendToServer()
end

local function inputText(input)
    local parts = {}
    for id, amount in pairs(input or {}) do parts[#parts + 1] = amount .. "x " .. itemName(id) end
    table.sort(parts)
    return table.concat(parts, ", ")
end

local function openCraft(ent, data)
    if not IsValid(ent) then return end
    local titles = { gpu_station = "Станок сборки видеокарт", components_station = "Станок комплектующих", weapon_station = "Кустарный оружейный верстак", furnace = "Печь переплавки брака" }
    local actions = { gpu_station = "gpu_start", components_station = "components_start", weapon_station = "weapon_start", furnace = "furnace_start" }

    local f = frame("GRM Factory — " .. (titles[data.kind] or "Производство"), 750, 560)

    local state = vgui.Create("DPanel", f)
    state:Dock(TOP); state:DockMargin(10, 46, 10, 7); state:SetTall(66)
    state.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, C.panel)
        if data.working then
            local progress = math.Clamp((CurTime() - (data.start or 0)) / math.max(1, data.duration or 1), 0, 1)
            draw.SimpleText("Производство: " .. tostring(data.recipeID), "GRMFC_Normal", 12, 16, C.yellow)
            draw.RoundedBox(4, 12, 40, w - 24, 15, Color(20, 27, 36))
            draw.RoundedBox(4, 12, 40, (w - 24) * progress, 15, C.green)
        else
            draw.SimpleText("Выберите рецепт. Материалы спишутся из вашего инвентаря.", "GRMFC_Small", 12, 26, C.dim)
        end
    end

    local scroll = vgui.Create("DScrollPanel", f)
    scroll:Dock(FILL); scroll:DockMargin(10, 0, 10, 54)

    for _, recipe in ipairs(data.recipes or {}) do
        local weaponData = data.kind == "weapon_station" and weapons.Get(recipe.output or "") or nil
        local weaponModel = weaponData and (weaponData.WorldModel or weaponData.ViewModel) or nil
        local hasPreview = isstring(weaponModel) and weaponModel ~= ""
        local textX = hasPreview and 112 or 15

        local row = vgui.Create("DPanel", scroll)
        row:Dock(TOP); row:SetTall(100); row:DockMargin(0, 0, 0, 7)
        row.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, self:IsHovered() and C.hover or C.panel)
            draw.SimpleText(recipe.name or recipe.id, "GRMFC_Normal", textX, 18, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Материалы: " .. inputText(recipe.input), "GRMFC_Small", textX, 48, C.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Время: " .. tostring(recipe.duration or 0) .. " сек.", "GRMFC_Small", textX, 72, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        -- Реальное 3D-превью оружия: берёт WorldModel из ArcCW SWEP.
        if hasPreview then
            local preview = vgui.Create("DModelPanel", row)
            preview:SetPos(8, 7)
            preview:SetSize(92, 86)
            preview:SetModel(weaponModel)
            preview:SetFOV(28)
            preview:SetCamPos(Vector(70, 0, 42))
            preview:SetLookAt(Vector(0, 0, 0))
            preview.LayoutEntity = function() end
        end

        local start = button(row, data.working and "Занято" or "Собрать", C.accent, 125, 36)
        start:SetPos(605, 32); start:SetEnabled(not data.working)
        start.DoClick = function()
            action(actions[data.kind], ent, function() net.WriteString(recipe.id) end)
            f:Close()
        end
    end

    local refresh = button(f, "↻ Обновить", C.accent, 150, 34)
    refresh:SetPos(10, 516)
    refresh.DoClick = function() action("refresh", ent); f:Close() end
end

local function localCount(itemID)
    local total = 0
    for _, slot in pairs((GRM and GRM.Inventory and GRM.Inventory.LocalSlots) or {}) do
        if slot and slot.id == itemID then total = total + (slot.count or 1) end
    end
    return total
end

local function openStorage(ent, data)
    if not IsValid(ent) then return end
    local f = frame("GRM Factory — склад продукции", 700, 520)

    local list = vgui.Create("DListView", f)
    list:Dock(FILL); list:DockMargin(10, 46, 10, 90); list:SetMultiSelect(false)
    list:AddColumn("Предмет"); list:AddColumn("Количество"); list:AddColumn("ID")
    for id, amount in pairs(data.items or {}) do
        if amount > 0 then
            local line = list:AddLine(itemName(id), tostring(amount), id)
            line.ItemID, line.Amount = id, amount
        end
    end

    local function selected()
        local i = list:GetSelectedLine()
        return i and list:GetLine(i) or nil
    end

    local takeOne = button(f, "Взять 1", C.green, 110, 32)
    takeOne:SetPos(10, 438)
    takeOne.DoClick = function()
        local line = selected(); if not IsValid(line) then notify("Выберите предмет", false) return end
        action("storage_take", ent, function() net.WriteString(line.ItemID); net.WriteUInt(1, 12) end); f:Close()
    end

    local takeAll = button(f, "Взять всё", C.green, 125, 32)
    takeAll:SetPos(128, 438)
    takeAll.DoClick = function()
        local line = selected(); if not IsValid(line) then notify("Выберите предмет", false) return end
        action("storage_take", ent, function() net.WriteString(line.ItemID); net.WriteUInt(math.min(line.Amount, 4095), 12) end); f:Close()
    end

    local depositPanel = vgui.Create("DPanel", f)
    depositPanel:SetPos(10, 476); depositPanel:SetSize(530, 34); depositPanel.Paint = nil
    local depositItems = { "scrap_metal", "components_box", "gpu_basic", "gpu_mid", "gpu_premium" }
    for _, id in ipairs(depositItems) do
        local b = button(depositPanel, "+ " .. itemName(id), C.yellow, nil, 30)
        b:Dock(LEFT); b:DockMargin(0, 0, 4, 0)
        b:SetWide(100)
        b:SetTooltip("Положить на склад 1 шт. В инвентаре: " .. localCount(id))
        b.DoClick = function()
            action("storage_deposit", ent, function() net.WriteString(id); net.WriteUInt(1, 12) end)
            f:Close()
        end
    end

    local refresh = button(f, "↻", C.accent, 40, 32)
    refresh:SetPos(650, 438); refresh.DoClick = function() action("refresh", ent); f:Close() end
end

local function openScrap(ent, data)
    if not IsValid(ent) then return end
    local f = frame("GRM Factory — мусорка металлолома", 450, 285)

    local panel = vgui.Create("DPanel", f)
    panel:SetPos(14, 50); panel:SetSize(422, 76)
    panel.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, C.panel)
        draw.SimpleText("Доступно металлолома: " .. tostring(data.stock or 0) .. " / " .. tostring(data.max or 0), "GRMFC_Normal", 14, 20, C.text)
        local progress = math.Clamp((data.stock or 0) / math.max(1, data.max or 1), 0, 1)
        draw.RoundedBox(4, 14, 48, w - 28, 14, Color(20, 27, 36))
        draw.RoundedBox(4, 14, 48, (w - 28) * progress, 14, C.yellow)
    end

    local one = button(f, "Собрать 1", C.green, 130, 40); one:SetPos(14, 150)
    one.DoClick = function() action("scrap_take", ent, function() net.WriteUInt(1, 4) end); f:Close() end
    local five = button(f, "Собрать 5", C.green, 130, 40); five:SetPos(160, 150)
    five.DoClick = function() action("scrap_take", ent, function() net.WriteUInt(5, 4) end); f:Close() end

    local refresh = button(f, "↻ Обновить", C.accent, 140, 34); refresh:SetPos(296, 231)
    refresh.DoClick = function() action("refresh", ent); f:Close() end
end

local function storageValue(storage, prices)
    local total = 0
    for id, price in pairs(prices or {}) do total = total + (storage.items and storage.items[id] or 0) * price end
    return total
end

local function openTerminal(ent, data)
    if not IsValid(ent) then return end
    local f = frame("GRM Factory — терминал продажи GPU", 700, 490)

    local list = vgui.Create("DListView", f)
    list:Dock(FILL); list:DockMargin(10, 46, 10, 54); list:SetMultiSelect(false)
    list:AddColumn("Склад"); list:AddColumn("Basic"); list:AddColumn("Mid"); list:AddColumn("Premium"); list:AddColumn("Стоимость")
    for _, storage in ipairs(data.storages or {}) do
        local items = storage.items or {}
        local line = list:AddLine(storage.id, tostring(items.gpu_basic or 0), tostring(items.gpu_mid or 0), tostring(items.gpu_premium or 0), money(storageValue(storage, data.prices)))
        line.StorageID = storage.id
    end

    local sell = button(f, "Продать GPU выбранного склада", C.green, 270, 34); sell:SetPos(10, 446)
    sell.DoClick = function()
        local i = list:GetSelectedLine(); local line = i and list:GetLine(i)
        if not IsValid(line) then notify("Выберите склад", false) return end
        Derma_Query("Продать все GPU выбранного склада?", "Продажа", "Продать", function()
            action("terminal_sell", ent, function() net.WriteString(line.StorageID) end); f:Close()
        end, "Отмена")
    end

    local refresh = button(f, "↻ Обновить", C.accent, 150, 34); refresh:SetPos(540, 446)
    refresh.DoClick = function() action("refresh", ent); f:Close() end
end

-- ============================================================
-- WEAPON BUYER / SHARED LOCKER
-- ============================================================
local function openWeaponBuyer(ent, data)
    if not IsValid(ent) then return end
    local f = frame("Скупщик оружия", 760, 530)
    local tabs = vgui.Create("DPropertySheet", f)
    tabs:Dock(FILL); tabs:DockMargin(8, 44, 8, 8)

    local buyPanel = vgui.Create("DPanel", tabs); buyPanel:SetPaintBackground(false)
    local buyList = vgui.Create("DListView", buyPanel)
    buyList:Dock(FILL); buyList:DockMargin(4, 4, 4, 44); buyList:SetMultiSelect(false)
    buyList:AddColumn("Оружие"); buyList:AddColumn("Остаток"); buyList:AddColumn("Цена")
    for _, weapon in ipairs(data.stock or {}) do
        local line = buyList:AddLine(weapon.name or weapon.class, tostring(weapon.stock or 0), money(weapon.price or 0))
        line.WeaponClass = weapon.class
        if (weapon.stock or 0) <= 0 then
            for _, col in pairs(line.Columns or {}) do if IsValid(col) then col:SetTextColor(C.dim) end end
        end
    end

    local buy = button(buyPanel, "Купить выбранное", C.green, 190, 34); buy:SetPos(4, 450)
    buy.DoClick = function()
        local i = buyList:GetSelectedLine(); local line = i and buyList:GetLine(i)
        if not IsValid(line) then notify("Выберите оружие", false) return end
        action("weapon_buyer_buy", ent, function() net.WriteString(line.WeaponClass) end); f:Close()
    end

    local refreshBuy = button(buyPanel, "↻", C.accent, 40, 34); refreshBuy:SetPos(700, 450)
    refreshBuy.DoClick = function() action("refresh", ent); f:Close() end
    tabs:AddSheet("Купить", buyPanel, "icon16/cart.png")

    local sellPanel = vgui.Create("DPanel", tabs); sellPanel:SetPaintBackground(false)
    local sellList = vgui.Create("DListView", sellPanel)
    sellList:Dock(FILL); sellList:DockMargin(4, 4, 4, 44); sellList:SetMultiSelect(false)
    sellList:AddColumn("Ваше оружие"); sellList:AddColumn("Цена продажи")
    for _, weapon in ipairs(data.sellWeapons or {}) do
        local line = sellList:AddLine(weapon.name or weapon.class, money(math.floor((weapon.price or 0) * (data.sellPercent or 0.45))))
        line.WeaponClass = weapon.class
    end

    local sell = button(sellPanel, "Продать выбранное", C.yellow, 190, 34); sell:SetPos(4, 450)
    sell.DoClick = function()
        local i = sellList:GetSelectedLine(); local line = i and sellList:GetLine(i)
        if not IsValid(line) then notify("Выберите оружие", false) return end
        action("weapon_buyer_sell", ent, function() net.WriteString(line.WeaponClass) end); f:Close()
    end
    tabs:AddSheet("Продать", sellPanel, "icon16/money.png")
end

local function openWeaponLocker(ent, data)
    if not IsValid(ent) then return end
    local f = frame("Общий оружейный шкаф", 760, 530)
    local tabs = vgui.Create("DPropertySheet", f)
    tabs:Dock(FILL)
    tabs:DockMargin(8, 44, 8, 8)

    -- Вкладка «В шкафу»: выбранное оружие можно достать.
    local lockerPanel = vgui.Create("DPanel", tabs)
    lockerPanel:SetPaintBackground(false)
    local takeBar = vgui.Create("DPanel", lockerPanel)
    takeBar:Dock(BOTTOM)
    takeBar:SetTall(42)
    takeBar:DockMargin(4, 2, 4, 4)
    takeBar.Paint = function(_, w, h) draw.RoundedBox(5, 0, 0, w, h, C.panel) end
    local take = button(takeBar, "Достать выбранное оружие", C.green, 240, 32)
    take:SetPos(5, 5)

    local stored = vgui.Create("DListView", lockerPanel)
    stored:Dock(FILL)
    stored:DockMargin(4, 4, 4, 0)
    stored:SetMultiSelect(false)
    stored:AddColumn("Оружие")
    stored:AddColumn("Кем положено")
    stored:AddColumn("Патроны")
    for index, weapon in ipairs(data.weapons or {}) do
        local line = stored:AddLine(weapon.class or "?", weapon.storedBy or "?", tostring(weapon.clip1 or 0))
        line.LockerIndex = index
    end

    take.DoClick = function()
        local i = stored:GetSelectedLine()
        local line = i and stored:GetLine(i)
        if not IsValid(line) then
            notify("Выберите оружие в шкафу", false)
            return
        end
        action("weapon_locker_take", ent, function()
            net.WriteUInt(line.LockerIndex, 12)
        end)
        f:Close()
    end
    tabs:AddSheet("В шкафу", lockerPanel, "icon16/briefcase.png")

    -- Вкладка «Положить»: игрок выбирает конкретное оружие и кладёт его.
    local playerPanel = vgui.Create("DPanel", tabs)
    playerPanel:SetPaintBackground(false)
    local storeBar = vgui.Create("DPanel", playerPanel)
    storeBar:Dock(BOTTOM)
    storeBar:SetTall(42)
    storeBar:DockMargin(4, 2, 4, 4)
    storeBar.Paint = function(_, w, h) draw.RoundedBox(5, 0, 0, w, h, C.panel) end
    local store = button(storeBar, "Положить выбранное оружие", C.accent, 250, 32)
    store:SetPos(5, 5)

    local carried = vgui.Create("DListView", playerPanel)
    carried:Dock(FILL)
    carried:DockMargin(4, 4, 4, 0)
    carried:SetMultiSelect(false)
    carried:AddColumn("Ваше оружие")
    carried:AddColumn("Патроны в магазине")
    for _, weapon in ipairs(data.playerWeapons or {}) do
        local line = carried:AddLine(weapon.name or weapon.class, tostring(weapon.clip1 or 0))
        line.WeaponClass = weapon.class
    end

    store.DoClick = function()
        local i = carried:GetSelectedLine()
        local line = i and carried:GetLine(i)
        if not IsValid(line) then
            notify("Выберите оружие, которое хотите положить", false)
            return
        end
        action("weapon_locker_store", ent, function()
            net.WriteString(line.WeaponClass)
        end)
        f:Close()
    end
    tabs:AddSheet("Положить", playerPanel, "icon16/box.png")
end

local function openWeaponAdmin(ent, data)
    if not IsValid(ent) then return end
    local f = frame("Админ: оружейный рынок", 760, 530)
    local scroll = vgui.Create("DScrollPanel", f)
    scroll:Dock(FILL); scroll:DockMargin(10, 46, 10, 8)

    local keys = {}
    for class in pairs(data.market or {}) do keys[#keys + 1] = class end
    table.sort(keys)

    for _, class in ipairs(keys) do
        local market = data.market[class]
        local row = vgui.Create("DPanel", scroll)
        row:Dock(TOP); row:SetTall(58); row:DockMargin(0, 0, 0, 6)
        row.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, C.panel) end

        local label = vgui.Create("DLabel", row); label:SetPos(10, 8); label:SetSize(205, 42)
        label:SetText((market.name or class) .. "\n" .. class); label:SetFont("GRMFC_Small"); label:SetTextColor(C.text)

        local price = vgui.Create("DNumberWang", row); price:SetPos(230, 15); price:SetSize(120, 28); price:SetMin(0); price:SetMax(200000); price:SetValue(market.price or 0)
        local stock = vgui.Create("DNumberWang", row); stock:SetPos(365, 15); stock:SetSize(90, 28); stock:SetMin(0); stock:SetMax(999); stock:SetValue((data.stock or {})[class] or 0)

        local save = button(row, "Сохранить", C.green, 120, 30); save:SetPos(610, 14)
        save.DoClick = function()
            action("weapon_admin_set", ent, function()
                net.WriteString(class)
                net.WriteUInt(math.max(0, math.floor(tonumber(price:GetValue()) or 0)), 32)
                net.WriteUInt(math.max(0, math.floor(tonumber(stock:GetValue()) or 0)), 12)
            end)
        end

        local p = vgui.Create("DLabel", row); p:SetPos(230, 2); p:SetText("Цена"); p:SetFont("GRMFC_Small"); p:SetTextColor(C.dim)
        local s = vgui.Create("DLabel", row); s:SetPos(365, 2); s:SetText("Запас"); s:SetFont("GRMFC_Small"); s:SetTextColor(C.dim)
    end
end

-- ============================================================
-- ARROW QTE: components and weapon stations
-- ============================================================
local qteFrame
local qte = nil

local ARROW_SYMBOLS = {
    UP = "↑",
    RIGHT = "→",
    DOWN = "↓",
    LEFT = "←",
}

local KEY_TO_ARROW = {
    [KEY_UP] = "UP",
    [KEY_RIGHT] = "RIGHT",
    [KEY_DOWN] = "DOWN",
    [KEY_LEFT] = "LEFT",
}

local function closeQTE(abort)
    if not IsValid(qteFrame) then qte = nil return end
    qte.closing = true
    local ent = qte.ent
    qteFrame:Close()
    qteFrame = nil
    if abort and IsValid(ent) then
        net.Start(NET_QTE_ABORT)
            net.WriteEntity(ent)
        net.SendToServer()
    end
    qte = nil
end

local function openQTE(ent, kind, sequence, stepTime, successPercent)
    if IsValid(qteFrame) then closeQTE(true) end
    qte = {
        ent = ent,
        kind = kind,
        sequence = sequence or {},
        stepTime = stepTime or 1,
        successPercent = successPercent or 0.7,
        index = 1,
        correct = 0,
        mistakes = 0,
        deadline = CurTime() + (stepTime or 1),
        sentIndex = 0,
        closing = false,
    }

    local title = kind == "weapon_station" and "Кустарная сборка оружия" or "Сборка комплектующих"
    local f = frame("GRM Factory — " .. title, 560, 360)
    qteFrame = f
    f:SetKeyboardInputEnabled(true)

    f.OnKeyCodePressed = function(_, key)
        if not qte or not IsValid(qte.ent) then return end
        local arrow = KEY_TO_ARROW[key]
        if not arrow or qte.sentIndex == qte.index then return end
        qte.sentIndex = qte.index
        net.Start(NET_QTE_INPUT)
            net.WriteEntity(qte.ent)
            net.WriteString(arrow)
        net.SendToServer()
    end

    f.OnClose = function()
        if qte and not qte.closing and IsValid(qte.ent) then
            net.Start(NET_QTE_ABORT)
                net.WriteEntity(qte.ent)
            net.SendToServer()
        end
    end

    local hint = vgui.Create("DLabel", f)
    hint:SetPos(16, 50); hint:SetSize(528, 34); hint:SetWrap(true)
    hint:SetText("Нажимайте стрелки клавиатуры в правильном порядке. Ошибки и время влияют на качество результата.")
    hint:SetFont("GRMFC_Small"); hint:SetTextColor(C.dim)

    local qtePanel = vgui.Create("DPanel", f)
    qtePanel:SetPos(16, 96); qtePanel:SetSize(528, 184)
    qtePanel.Paint = function(_, w, h)
        draw.RoundedBox(7, 0, 0, w, h, C.panel)
        if not qte then return end
        local expected = qte.sequence[qte.index]
        local symbol = ARROW_SYMBOLS[expected] or "?"
        local timeLeft = math.max(0, (qte.deadline or CurTime()) - CurTime())
        local frac = math.Clamp(timeLeft / math.max(0.1, qte.stepTime), 0, 1)
        local required = math.ceil(#qte.sequence * qte.successPercent)

        draw.SimpleText("СТРЕЛКА " .. tostring(qte.index) .. " / " .. #qte.sequence, "GRMFC_Small", 14, 16, C.dim)
        -- Крупная жирная стрелка — её должно быть видно с первого взгляда.
        draw.SimpleTextOutlined(symbol, "GRMFC_QTEArrow", w / 2, 83, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(5, 8, 12, 240))
        draw.SimpleText("Используйте клавиши ← ↑ ↓ →", "GRMFC_Small", w / 2, 125, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        draw.RoundedBox(4, 14, h - 30, w - 28, 14, Color(20, 27, 36))
        draw.RoundedBox(4, 14, h - 30, (w - 28) * frac, 14, timeLeft < qte.stepTime * 0.3 and C.red or C.accent)
        draw.SimpleText("Верно: " .. qte.correct .. " | Ошибок: " .. qte.mistakes .. " | Нужно минимум: " .. required, "GRMFC_Small", w / 2, h - 51, C.yellow, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local cancel = button(f, "Прервать сборку", C.red, 180, 34)
    cancel:SetPos(364, 308)
    cancel.DoClick = function() closeQTE(true) end
end

net.Receive(NET_OPEN_WEAPON_BUYER, function()
    openWeaponBuyer(net.ReadEntity(), net.ReadTable() or {})
end)

net.Receive(NET_OPEN_WEAPON_LOCKER, function()
    openWeaponLocker(net.ReadEntity(), net.ReadTable() or {})
end)

net.Receive(NET_OPEN_WEAPON_ADMIN, function()
    openWeaponAdmin(net.ReadEntity(), net.ReadTable() or {})
end)

net.Receive(NET_QTE_START, function()
    openQTE(net.ReadEntity(), net.ReadString(), net.ReadTable() or {}, net.ReadFloat(), net.ReadFloat())
end)

net.Receive(NET_QTE_STATE, function()
    local ent = net.ReadEntity()
    local index = net.ReadUInt(8)
    local correct = net.ReadUInt(8)
    local mistakes = net.ReadUInt(8)
    local deadline = net.ReadFloat()
    local lastCorrect = net.ReadBool()
    if not qte or qte.ent ~= ent then return end
    qte.index = index
    qte.correct = correct
    qte.mistakes = mistakes
    qte.deadline = deadline
    qte.sentIndex = 0
    if index > 1 then surface.PlaySound(lastCorrect and "buttons/button17.wav" or "buttons/button10.wav") end
end)

net.Receive(NET_QTE_FINISH, function()
    local ent = net.ReadEntity()
    local success = net.ReadBool()
    local correct = net.ReadUInt(8)
    local total = net.ReadUInt(8)
    if qte and qte.ent == ent then
        qte.closing = true
        if IsValid(qteFrame) then qteFrame:Close() end
        qteFrame = nil
        qte = nil
    end
    notify(success and ("Мини-игра пройдена: " .. correct .. "/" .. total) or ("Мини-игра провалена: " .. correct .. "/" .. total .. ". Получен брак."), success)
end)

net.Receive(NET_RESULT, function()
    local success = net.ReadBool(); local message = net.ReadString(); notify(message, success)
end)

net.Receive(NET_OPEN_CRAFT, function() openCraft(net.ReadEntity(), net.ReadTable() or {}) end)
net.Receive(NET_OPEN_STORAGE, function() openStorage(net.ReadEntity(), net.ReadTable() or {}) end)
net.Receive(NET_OPEN_SCRAP, function() openScrap(net.ReadEntity(), net.ReadTable() or {}) end)
net.Receive(NET_OPEN_TERMINAL, function() openTerminal(net.ReadEntity(), net.ReadTable() or {}) end)

local nextScan, activeMachines = 0, {}

hook.Add("HUDPaint", "GRM_FC_Progress", function()
    if CurTime() >= nextScan then
        nextScan = CurTime() + 1; activeMachines = {}
        for _, class in ipairs({ "grm_fc_gpu_station", "grm_fc_components_station", "grm_fc_weapon_station", "grm_fc_furnace" }) do
            for _, ent in ipairs(ents.FindByClass(class)) do if ent:GetIsWorking() then activeMachines[#activeMachines + 1] = ent end end
        end
    end
    local ply = LocalPlayer(); if not IsValid(ply) then return end
    for _, ent in ipairs(activeMachines) do
        if IsValid(ent) and ply:GetPos():DistToSqr(ent:GetPos()) <= 900 * 900 then
            local screen = (ent:GetPos() + Vector(0, 0, 65)):ToScreen()
            if screen.visible then
                local progress = math.Clamp((CurTime() - ent:GetCraftStart()) / math.max(1, ent:GetCraftDuration()), 0, 1)
                draw.RoundedBox(4, screen.x - 90, screen.y, 180, 16, Color(20, 27, 36, 230))
                draw.RoundedBox(4, screen.x - 90, screen.y, 180 * progress, 16, C.green)
                draw.SimpleText("ПРОИЗВОДСТВО " .. math.floor(progress * 100) .. "%", "GRMFC_Small", screen.x, screen.y - 4, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
            end
        end
    end
end)

-- Надпись прикреплена к верхней точке модели мусорки + 8 юнитов.
-- Таким образом она остаётся ровно в 5–10 юнитах над мусоркой независимо
-- от её модели и масштаба.
hook.Add("HUDPaint", "GRM_FC_ScrapBinLabel", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local maxDistance = 600
    local playerPos = ply:GetPos()
    for _, bin in ipairs(ents.FindByClass("grm_fc_scrap_bin")) do
        if IsValid(bin) then
            local distance = playerPos:Distance(bin:GetPos())
            if distance <= maxDistance then
                local topOffset = bin:OBBMaxs().z + 8 -- ровно 8 units над верхом модели
                local screen = bin:LocalToWorld(Vector(0, 0, topOffset)):ToScreen()
                if screen.visible then
                    local alpha = math.Clamp(255 - (distance / maxDistance) * 190, 60, 255)
                    local text = "Металлолом (мусорка)"
                    surface.SetFont("GRMFC_ScrapLabel")
                    local textWidth, textHeight = surface.GetTextSize(text)
                    local padding = 7
                    draw.RoundedBox(4,
                        screen.x - textWidth / 2 - padding,
                        screen.y - textHeight / 2 - padding,
                        textWidth + padding * 2,
                        textHeight + padding * 2,
                        Color(10, 14, 20, alpha * 0.78)
                    )
                    draw.SimpleText(text, "GRMFC_ScrapLabel", screen.x + 1, screen.y + 1,
                        Color(0, 0, 0, alpha * 0.8), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText(text, "GRMFC_ScrapLabel", screen.x, screen.y,
                        Color(235, 178, 60, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end
    end
end)

print("[GRM Factory Full Cycle] Client loaded")
