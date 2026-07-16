--[[--------------------------------------------------------------------
    GRM Inventory UI v2.1 — Modern grid interface with drag & drop
    (Код 49; сохранено агентом: снят ГМЛ-манглинг веб-вставки — восстановлены < > _ и ссылки-обёртки)
----------------------------------------------------------------------]]
if not CLIENT then return end

GRM = GRM or {}
GRM.Inventory = GRM.Inventory or {}
local INV = GRM.Inventory
INV.UsesIntegratedWeightUI = true

surface.CreateFont("GRMInv2_Title", { font = "Roboto", size = 23, weight = 800, extended = true })
surface.CreateFont("GRMInv2_Normal", { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("GRMInv2_Small", { font = "Roboto", size = 12, weight = 400, extended = true })
surface.CreateFont("GRMInv2_Count", { font = "Roboto", size = 14, weight = 800, extended = true })

local C = {
    bg = Color(18, 23, 31, 250), header = Color(27, 35, 47, 250), panel = Color(31, 40, 53, 248),
    slot = Color(37, 48, 63, 250), slotHover = Color(51, 67, 88, 250), selected = Color(63, 145, 240, 255),
    border = Color(70, 86, 110, 190), text = Color(240, 244, 250), dim = Color(165, 176, 191),
    green = Color(54, 186, 105), red = Color(205, 70, 65), yellow = Color(235, 178, 60), accent = Color(67, 155, 255),
}

local frame, slotsPanel, detailPanel, weightPanel
local dragData, dragImage

local FACTORY_DEFS = {
    scrap_metal = { name = "Металлолом", desc = "Собран в мусорках.", icon = "icon16/wrench.png" },
    components_box = { name = "Ящик комплектующих", desc = "Материал для сборки.", icon = "icon16/box.png" },
    gpu_basic = { name = "Базовая GPU", desc = "Произведено на заводе.", icon = "icon16/computer.png" },
    gpu_mid = { name = "Средняя GPU", desc = "Произведено на заводе.", icon = "icon16/computer.png" },
    gpu_premium = { name = "Премиум GPU", desc = "Произведено на заводе.", icon = "icon16/computer.png" },
    defective_components = { name = "Бракованные комплектующие", desc = "Можно переплавить.", icon = "icon16/error.png" },
    defective_weapon_parts = { name = "Бракованные оружейные детали", desc = "Можно переплавить.", icon = "icon16/error.png" },
    defective_gpu = { name = "Бракованная видеокарта", desc = "Можно переплавить.", icon = "icon16/error.png" },
    logistics_crate = { name = "Грузовой ящик", desc = "Выбросьте из инвентаря, чтобы поставить ящик.", icon = "icon16/box.png" },
}

local function itemDef(slot)
    if not slot or not slot.id then return nil end
    if string.StartWith(slot.id, "weapon:") then
        return { type = "weapon", name = (slot.data and slot.data.class) or string.sub(slot.id, 8), desc = "Оружие в инвентаре. Используйте, чтобы экипировать.", icon = "icon16/gun.png" }
    end
    return (INV.GetItemDef and INV.GetItemDef(slot.id)) or FACTORY_DEFS[slot.id]
end

local function itemName(slot)
    local def = itemDef(slot)
    return def and def.name or (slot and slot.id) or "Пустой слот"
end

local function itemWeight(slot)
    if not slot or not slot.id then return 0 end
    local count = tonumber(slot.count) or 1
    if string.StartWith(slot.id, "weapon:") then
        local class = slot.data and slot.data.class or string.sub(slot.id, 8)
        local ec = GRM.Encumbrance and GRM.Encumbrance.Config
        return (ec and ec.WeaponWeights and ec.WeaponWeights[class] or 2.5) * count
    end
    local def = itemDef(slot)
    if def and tonumber(def.weight) then return tonumber(def.weight) * count end
    local ec = GRM.Encumbrance and GRM.Encumbrance.Config
    return (ec and ec.ItemWeights and ec.ItemWeights[slot.id] or 0.5) * count
end

local function btn(parent, text, color, w, h)
    local b = vgui.Create("DButton", parent)
    b:SetText(text)
    b:SetFont("GRMInv2_Normal")
    b:SetTextColor(color_white)
    if w then b:SetWide(w) end
    if h then b:SetTall(h) end
    b.Paint = function(self, pw, ph)
        local col = color
        if not self:IsEnabled() then col = Color(75, 80, 90)
        elseif self:IsHovered() then col = Color(math.min(color.r + 20, 255), math.min(color.g + 20, 255), math.min(color.b + 20, 255)) end
        draw.RoundedBox(5, 0, 0, pw, ph, col)
    end
    return b
end

local function currentSlots() return INV.LocalSlots or {} end

local function drawWeight()
    if not IsValid(weightPanel) then return end
    local state = GRM.Encumbrance and GRM.Encumbrance.ClientState or nil
    if not state then weightPanel:SetText("Вес: система не загружена"); return end
    local color = state.blocked and C.red or (state.overloaded and C.yellow or C.green)
    weightPanel:SetText(string.format("Вес: %.1f / %.0f кг  •  Оружие %.1f  •  Патроны %.1f", state.weight, state.capacity, state.weapons, state.ammo))
    weightPanel:SetTextColor(color)
end

local function rebuildDetail()
    if not IsValid(detailPanel) then return end
    detailPanel:Clear()
    local slot = currentSlots()[INV.SelectedSlot]
    if not slot then
        local label = vgui.Create("DLabel", detailPanel)
        label:Dock(FILL)
        label:SetContentAlignment(5)
        label:SetText("Выберите предмет в сетке\n\nЛКМ + перетащить: переместить\nПКМ: использовать")
        label:SetFont("GRMInv2_Normal")
        label:SetTextColor(C.dim)
        return
    end
    local def = itemDef(slot) or {}
    local icon = vgui.Create("DImage", detailPanel)
    icon:SetPos(14, 14); icon:SetSize(48, 48); icon:SetImage(def.icon or "icon16/package.png")
    local title = vgui.Create("DLabel", detailPanel)
    title:SetPos(74, 14); title:SetSize(260, 24); title:SetText(itemName(slot)); title:SetFont("GRMInv2_Normal"); title:SetTextColor(C.text)
    local count = vgui.Create("DLabel", detailPanel)
    count:SetPos(74, 38); count:SetSize(260, 20); count:SetText(string.format("Количество: %d   |   Вес: %.2f кг", tonumber(slot.count) or 1, itemWeight(slot))); count:SetFont("GRMInv2_Small"); count:SetTextColor(C.yellow)
    local desc = vgui.Create("DLabel", detailPanel)
    desc:SetPos(14, 76); desc:SetSize(330, 45); desc:SetWrap(true); desc:SetText(def.desc or "Описание отсутствует"); desc:SetFont("GRMInv2_Small"); desc:SetTextColor(C.dim)

    local use = btn(detailPanel, def.type == "weapon" and "Экипировать" or "Использовать", C.green, 155, 32)
    use:SetPos(14, 132)
    use.DoClick = function() if INV.UseSlot then INV.UseSlot(INV.SelectedSlot) end end

    local drop = btn(detailPanel, "Выбросить 1", C.red, 155, 32)
    drop:SetPos(179, 132)
    drop.DoClick = function() if INV.DropSlot then INV.DropSlot(INV.SelectedSlot, 1) end end

    local slotCount = tonumber(slot.count) or 1
    if slotCount > 1 then
        local split = btn(detailPanel, "Разделить стак", C.accent, 155, 30)
        split:SetPos(14, 170)
        split.DoClick = function() if INV.SplitSlot then INV.SplitSlot(INV.SelectedSlot, math.floor(slotCount / 2)) end end
        local dropAll = btn(detailPanel, "Выбросить всё", C.red, 155, 30)
        dropAll:SetPos(179, 170)
        dropAll.DoClick = function() if INV.DropSlot then INV.DropSlot(INV.SelectedSlot, slotCount) end end
    end
end

local function findSlotUnderMouse()
    if not IsValid(slotsPanel) or not IsValid(frame) then return nil end
    local mx, my = gui.MousePos()
    local columns, size, gap = 6, 74, 8
    local maxSlots = INV.Config and INV.Config.MaxSlots or 24
    local fx, fy = frame:GetPos()
    local sx, sy = slotsPanel:GetPos()
    local absX, absY = fx + sx, fy + sy
    local relX, relY = mx - absX, my - absY
    for index = 1, maxSlots do
        local col = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        local sx, sy = col * (size + gap), row * (size + gap)
        if relX >= sx and relX <= sx + size and relY >= sy and relY <= sy + size then return index end
    end
    return nil
end

local function createSlot(parent, index, size)
    local slotBtn = vgui.Create("DButton", parent)
    slotBtn:SetSize(size, size)
    slotBtn:SetText("")
    slotBtn.m_dragging = false
    slotBtn.DoClick = function()
        if slotBtn.m_dragging then return end
        local slot = currentSlots()[index]
        if not slot or not slot.id then
            if INV.SelectedSlot then
                if INV.MoveSlot then INV.MoveSlot(INV.SelectedSlot, index) end
                INV.SelectedSlot = nil
            end
            rebuildDetail()
            return
        end
        INV.SelectedSlot = (INV.SelectedSlot == index) and nil or index
        rebuildDetail()
    end
    slotBtn.DoRightClick = function()
        local slot = currentSlots()[index]
        if slot and slot.id and INV.UseSlot then INV.UseSlot(index) end
    end
    slotBtn.OnMousePressed = function(self, key)
        if key ~= MOUSE_LEFT then return end
        local slot = currentSlots()[index]
        if not slot or not slot.id then return end
        self.m_dragging = true
        self:MouseCapture(true)
        dragImage = vgui.Create("DPanel")
        dragImage:SetSize(74, 74)
        dragImage:SetAlpha(200)
        dragImage.Paint = function(_, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(63, 145, 240, 160))
            surface.SetDrawColor(Color(80, 160, 255, 200))
            surface.DrawOutlinedRect(0, 0, w, h, 2)
            local def = (INV.ItemDefs and INV.ItemDefs[slot.id]) or nil
            local mat = Material((def and def.icon) or (string.StartWith(slot.id, "weapon:") and "icon16/gun.png" or "icon16/package.png"))
            surface.SetMaterial(mat)
            surface.SetDrawColor(255, 255, 255, 200)
            surface.DrawTexturedRect(12, 10, w - 24, w - 24)
            if slot.count and slot.count > 1 then draw.SimpleText(tostring(slot.count), "GRMInv2_Count", w - 7, h - 7, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM) end
        end
        dragImage:SetPos(gui.MousePos())
        dragImage:SetZPos(9999)
        dragImage:SetParent(frame:GetParent() or frame)
        dragData = { slotIdx = index, panel = self }
    end
    slotBtn.OnMouseReleased = function(self, key)
        if key ~= MOUSE_LEFT then return end
        self:MouseCapture(false)
        self.m_dragging = false
        if dragData then
            local targetIdx = findSlotUnderMouse()
            if targetIdx and targetIdx ~= dragData.slotIdx then
                if INV.MoveSlot then INV.MoveSlot(dragData.slotIdx, targetIdx) end
                INV.SelectedSlot = targetIdx
            else INV.SelectedSlot = dragData.slotIdx end
            rebuildDetail()
        end
        if IsValid(dragImage) then dragImage:Remove(); dragImage = nil end
        dragData = nil
    end
    slotBtn.OnCursorMoved = function()
        if not dragData or not IsValid(dragImage) then return end
        local mx, my = gui.MousePos()
        dragImage:SetPos(mx - 37, my - 37)
    end
    slotBtn.Paint = function(self, w, h)
        local slot = currentSlots()[index]
        local selected = INV.SelectedSlot == index
        local isDrag = dragData and dragData.slotIdx == index
        local bg = selected and C.selected or (self:IsHovered() and not self.m_dragging and C.slotHover or C.slot)
        if isDrag then bg = Color(63, 100, 180, 200) end
        draw.RoundedBox(6, 0, 0, w, h, bg)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h, selected and 2 or 1)
        if not slot or not slot.id then
            draw.SimpleText(tostring(index), "GRMInv2_Small", 7, 6, Color(120, 132, 150), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            return
        end
        local a = isDrag and 80 or 235
        local def = itemDef(slot) or {}
        local mat = Material(def.icon or "icon16/package.png")
        surface.SetMaterial(mat)
        surface.SetDrawColor(255, 255, 255, a)
        surface.DrawTexturedRect(12, 10, w - 24, w - 24)
        draw.SimpleText(tostring(slot.count or 1), "GRMInv2_Count", w - 7, h - 7, Color(255, 255, 255, a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
        draw.SimpleText(tostring(index), "GRMInv2_Small", 7, 5, Color(185, 196, 212, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        if self:IsHovered() and not isDrag then self:SetTooltip(itemName(slot) .. "\nВес: " .. string.format("%.2f кг", itemWeight(slot))) end
    end
    return slotBtn
end

local function rebuildSlots()
    if not IsValid(slotsPanel) then return end
    slotsPanel:Clear()
    local maxSlots = INV.Config and INV.Config.MaxSlots or 24
    local columns, size, gap = 6, 74, 8
    for index = 1, maxSlots do
        local slot = createSlot(slotsPanel, index, size)
        local col = (index - 1) % columns
        local row = math.floor((index - 1) / columns)
        slot:SetPos(col * (size + gap), row * (size + gap))
    end
end

function INV.OpenGUI()
    if IsValid(frame) then frame:MakePopup(); rebuildSlots(); rebuildDetail(); return end
    local f = vgui.Create("DFrame")
    f:SetTitle(""); f:SetSize(875, 570); f:Center(); f:MakePopup()
    frame = f
    f.OnRemove = function() frame = nil; INV.SelectedSlot = nil; dragData = nil; if IsValid(dragImage) then dragImage:Remove(); dragImage = nil end end
    f.Paint = function(_, w, h)
        draw.RoundedBox(9, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(9, 0, 0, w, 40, C.header, true, true, false, false)
        draw.SimpleText("ИНВЕНТАРЬ", "GRMInv2_Title", 15, 20, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("ЛКМ + перетащить — переместить  |  ПКМ — использовать", "GRMInv2_Small", w - 14, 20, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    weightPanel = vgui.Create("DLabel", f)
    weightPanel:SetPos(16, 48); weightPanel:SetSize(510, 23); weightPanel:SetFont("GRMInv2_Small")
    drawWeight()

    slotsPanel = vgui.Create("DPanel", f)
    slotsPanel:SetPos(16, 78); slotsPanel:SetSize(492, 332)
    slotsPanel.Paint = function(_, w, h) draw.RoundedBox(7, 0, 0, w, h, C.panel) end

    detailPanel = vgui.Create("DPanel", f)
    detailPanel:SetPos(525, 78); detailPanel:SetSize(334, 218)
    detailPanel.Paint = function(_, w, h) draw.RoundedBox(7, 0, 0, w, h, C.panel) end

    local actions = vgui.Create("DPanel", f)
    actions:SetPos(525, 312); actions:SetSize(334, 98)
    actions.Paint = function(_, w, h) draw.RoundedBox(7, 0, 0, w, h, C.panel) end
    local store = btn(actions, "Убрать активное оружие", C.accent, 300, 32)
    store:SetPos(17, 12)
    store.DoClick = function() if INV.StoreWeapon then INV.StoreWeapon() end end
    local dropWep = btn(actions, "Выбросить активное оружие", C.red, 300, 32)
    dropWep:SetPos(17, 54)
    dropWep.DoClick = function() if INV.DropWeapon then INV.DropWeapon() end end

    local footer = vgui.Create("DLabel", f)
    footer:SetPos(16, 432); footer:SetSize(843, 70); footer:SetWrap(true)
    footer:SetFont("GRMInv2_Small"); footer:SetTextColor(C.dim)
    footer:SetText("Перегруз: после 50 кг бег не ускоряет игрока. После 62.5 кг нельзя поднимать новые предметы. Вес учитывает содержимое инвентаря, оружие и боеприпасы.\n/drop — выбросить оружие из рук  |  /store — убрать в инвентарь  |  /inv — открыть инвентарь")

    rebuildSlots()
    rebuildDetail()
end

local ModernOpenGUI = INV.OpenGUI
timer.Create("GRMInv2_KeepOpenGUI", 1, 0, function()
    if INV.OpenGUI ~= ModernOpenGUI then INV.OpenGUI = ModernOpenGUI end
end)

hook.Add("GRM_InventoryUpdated", "GRMInv2_Refresh", function()
    if IsValid(frame) then rebuildSlots(); rebuildDetail() end
end)

hook.Add("GRM_InventoryWeightUpdated", "GRMInv2_WeightRefresh", function()
    if IsValid(weightPanel) then drawWeight() end
end)

print("[GRM] Inventory UI v2.1 loaded")
