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

local frame, slotsPanel, detailPanel, weightPanel, equipmentPanel
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

local DOCUMENT_ITEMS = {passport=true,badge=true,military_ticket=true,driver_license=true,military_license=true,weapon_license=true,business_license=true,medcard=true}
local function documentMeta(slot)
    if not (slot and DOCUMENT_ITEMS[slot.id]) then return nil end
    local d=istable(slot.data) and slot.data or {}
    local lp=LocalPlayer(); local myKey=""
    if IsValid(lp) then myKey=(GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(lp)) or lp:GetNWString("GRM_CharacterKey","") end
    local owner=tostring(d.ownerKey or d.sid64 or "")
    if owner=="" then owner=myKey end -- легаси-бланк считается своим
    return {ownerKey=owner,ownerName=tostring(d.ownerName or ""),number=tostring(d.number or ""),mine=(owner~="" and owner==myKey)}
end
local function itemName(slot)
    local def=itemDef(slot)
    local base=def and def.name or (slot and slot.id) or "Пустой слот"
    local meta=documentMeta(slot)
    if meta then
        local mark=meta.mine and "СВОЙ" or "ЧУЖОЙ"
        local who=(not meta.mine and meta.ownerName~="") and (" — "..meta.ownerName) or ""
        return mark.." • "..base..who
    end
    return base
end

local function accessoryModel(slot)
    local def = itemDef(slot)
    if not def or not def.accessoryID then return nil end
    local model = tostring(def.model or "")
    return model ~= "" and util.IsValidModel(model) and model or nil
end

local function setupAccessoryPreview(panel, model, spinSpeed)
    panel:SetModel(model)
    panel:SetMouseInputEnabled(false)
    panel:SetKeyboardInputEnabled(false)
    panel:SetAnimated(false)
    panel:SetAmbientLight(Color(115, 125, 140))
    panel:SetDirectionalLight(BOX_TOP, Color(255, 255, 255))
    panel:SetDirectionalLight(BOX_FRONT, Color(185, 200, 225))

    local ent = panel:GetEntity()
    if not IsValid(ent) then return end
    ent:SetSkin(0)
    ent:SetMaterial("")
    ent:SetColor(color_white)

    -- Центруем геометрию вокруг нуля, а не вращаем её вокруг model origin.
    -- У длинных/смещённых моделей (трубки, респираторы, рюкзаки) origin
    -- часто находится на краю — без компенсации предмет «выезжал» из ячейки.
    local mins, maxs = ent:GetRenderBounds()
    local localCenter = (mins + maxs) * 0.5
    local radius = math.max((maxs - mins):Length() * 0.5, 4)
    local fov = 31
    local distance = math.Clamp((radius / math.tan(math.rad(fov * 0.5))) * 1.28, 12, 12000)
    local cameraDirection = Vector(1, 1, 0.62):GetNormalized()
    panel:SetFOV(fov)
    panel:SetLookAt(vector_origin)
    panel:SetCamPos(cameraDirection * distance)

    panel.LayoutEntity = function(_, entity)
        local rotation = Angle(0, (RealTime() * (spinSpeed or 14)) % 360, 0)
        local rotatedCenter = Vector(localCenter.x, localCenter.y, localCenter.z)
        rotatedCenter:Rotate(rotation)
        entity:SetAngles(rotation)
        entity:SetPos(-rotatedCenter)
    end
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
    local model = accessoryModel(slot)
    if model then
        local preview = vgui.Create("DModelPanel", detailPanel)
        preview:SetPos(8, 7); preview:SetSize(60, 60)
        setupAccessoryPreview(preview, model, 10)
    else
        local icon = vgui.Create("DImage", detailPanel)
        icon:SetPos(14, 14); icon:SetSize(48, 48); icon:SetImage(def.icon or "icon16/package.png")
    end
    local title = vgui.Create("DLabel", detailPanel)
    -- Код 109: модулятор рации показывает своё состояние прямо в заголовке —
    -- владелец сразу видит, что «Использовать» реально переключает ВКЛ/ВЫКЛ
    local displayName = itemName(slot)
    if slot.id == "radio_modulator" then
        displayName = displayName .. ((slot.data and slot.data.on == true) and "  [ВКЛ]" or "  [ВЫКЛ]")
    end
    title:SetPos(74, 14); title:SetSize(260, 24); title:SetText(displayName); title:SetFont("GRMInv2_Normal"); title:SetTextColor(C.text)
    local count = vgui.Create("DLabel", detailPanel)
    count:SetPos(74, 38); count:SetSize(260, 20); count:SetText(string.format("Количество: %d   |   Вес: %.2f кг", tonumber(slot.count) or 1, itemWeight(slot))); count:SetFont("GRMInv2_Small"); count:SetTextColor(C.yellow)
    local desc = vgui.Create("DLabel", detailPanel)
    desc:SetPos(14, 76); desc:SetSize(330, 45); desc:SetWrap(true)
    local description=def.desc or "Описание отсутствует"
    local docMeta=documentMeta(slot)
    if docMeta then description=description.."\nВладелец: "..(docMeta.ownerName~="" and docMeta.ownerName or docMeta.ownerKey)..(docMeta.number~="" and (" • №"..docMeta.number) or "") end
    desc:SetText(description); desc:SetFont("GRMInv2_Small"); desc:SetTextColor(docMeta and (docMeta.mine and C.green or C.red) or C.dim)

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

local function findEquipmentSlotUnderMouse()
    if not IsValid(equipmentPanel) or not IsValid(frame) then return nil end
    local mx, my = gui.MousePos()
    local fx, fy = frame:GetPos()
    local px, py = equipmentPanel:GetPos()
    local relX, relY = mx - fx - px, my - fy - py
    if relX < 7 or relX > 133 then return nil end
    local order = GRM.Customization and GRM.Customization.SlotOrder or {}
    for i, slotID in ipairs(order) do
        local y = 30 + (i - 1) * 43
        if relY >= y and relY <= y + 37 then return slotID end
    end
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
            if not accessoryModel(slot) then
                local def = (INV.ItemDefs and INV.ItemDefs[slot.id]) or nil
                local mat = Material((def and def.icon) or (string.StartWith(slot.id, "weapon:") and "icon16/gun.png" or "icon16/package.png"))
                surface.SetMaterial(mat)
                surface.SetDrawColor(255, 255, 255, 200)
                surface.DrawTexturedRect(12, 10, w - 24, w - 24)
                if slot.count and slot.count > 1 then draw.SimpleText(tostring(slot.count), "GRMInv2_Count", w - 7, h - 7, color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM) end
            end
        end
        local dragModel = accessoryModel(slot)
        if dragModel then
            local preview = vgui.Create("DModelPanel", dragImage)
            preview:SetPos(5, 5); preview:SetSize(64, 64); preview:SetAlpha(210)
            setupAccessoryPreview(preview, dragModel, 12)
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
            local equipmentSlot = findEquipmentSlotUnderMouse()
            local targetIdx = findSlotUnderMouse()
            if equipmentSlot and GRM.Customization and GRM.Customization.EquipInventorySlot then
                GRM.Customization.EquipInventorySlot(dragData.slotIdx, equipmentSlot)
                INV.SelectedSlot = nil
            elseif targetIdx and targetIdx ~= dragData.slotIdx then
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

    local initialSlot = currentSlots()[index]
    local initialModel = accessoryModel(initialSlot)
    if initialModel then
        local preview = vgui.Create("DModelPanel", slotBtn)
        preview:SetPos(5, 5)
        preview:SetSize(size - 10, size - 10)
        preview:SetZPos(1)
        setupAccessoryPreview(preview, initialModel, 12)
        preview.Think = function(self)
            self:SetAlpha((dragData and dragData.slotIdx == index) and 70 or 255)
        end
        preview.PaintOver = function(_, w, h)
            local selected = INV.SelectedSlot == index
            surface.SetDrawColor(selected and C.selected or Color(0, 0, 0, 0))
            if selected then surface.DrawOutlinedRect(0, 0, w, h, 2) end
            draw.SimpleText(tostring(index), "GRMInv2_Small", 2, 0, Color(215, 225, 238), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        slotBtn._accessoryPreview = preview
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
        if not accessoryModel(slot) then
            local def = itemDef(slot) or {}
            local mat = Material(def.icon or "icon16/package.png")
            surface.SetMaterial(mat)
            surface.SetDrawColor(255, 255, 255, a)
            surface.DrawTexturedRect(12, 10, w - 24, w - 24)
            draw.SimpleText(tostring(slot.count or 1), "GRMInv2_Count", w - 7, h - 7, Color(255, 255, 255, a), TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM)
            draw.SimpleText(tostring(index), "GRMInv2_Small", 7, 5, Color(185, 196, 212, a), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
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

local function rebuildEquipment()
    if not IsValid(equipmentPanel) then return end
    equipmentPanel:Clear()
    local custom = GRM.Customization
    local title = vgui.Create("DLabel", equipmentPanel)
    title:SetPos(8, 7); title:SetSize(122, 20); title:SetText("ЭКИПИРОВКА"); title:SetFont("GRMInv2_Small"); title:SetTextColor(C.text)
    local order = custom and custom.SlotOrder or { "head", "face", "torso", "legs", "left_hand", "right_hand" }
    for i, slotID in ipairs(order) do
        local slotDef = custom and custom.Slots and custom.Slots[slotID] or { name = slotID, icon = "icon16/user_suit.png" }
        local b = vgui.Create("DButton", equipmentPanel)
        b:SetPos(7, 30 + (i - 1) * 43); b:SetSize(126, 37); b:SetText("")
        b.Paint = function(self, w, h)
            local equipped = custom and custom.GetClientEquipped and custom.GetClientEquipped(LocalPlayer(), slotID)
            local item = custom and custom.GetClientItem and custom.GetClientItem(equipped)
            draw.RoundedBox(5, 0, 0, w, h, self:IsHovered() and C.slotHover or C.slot)
            surface.SetDrawColor(equipped and C.green or C.border); surface.DrawOutlinedRect(0, 0, w, h, equipped and 2 or 1)
            local mat = Material(slotDef.icon or "icon16/user_suit.png")
            surface.SetMaterial(mat); surface.SetDrawColor(255,255,255,220); surface.DrawTexturedRect(7,10,16,16)
            draw.SimpleText(slotDef.name or slotID, "GRMInv2_Small", 29, 8, C.text)
            draw.SimpleText(item and item.name or "пусто", "GRMInv2_Small", 29, 22, item and C.green or C.dim)
        end
        b.DoClick = function()
            if not custom then return end
            local selectedIndex = INV.SelectedSlot
            local selectedSlot = selectedIndex and currentSlots()[selectedIndex] or nil
            local accessory = selectedSlot and custom.GetItemByInventoryID and custom.GetItemByInventoryID(selectedSlot.id) or nil
            if accessory and custom.EquipInventorySlot then
                custom.EquipInventorySlot(selectedIndex, slotID)
                INV.SelectedSlot = nil
                rebuildDetail()
            elseif custom.RequestEditor then
                custom.RequestEditor()
            end
        end
        b.DoRightClick = function()
            if not (custom and custom.GetClientEquipped and custom.UnequipInventorySlot) then return end
            local equipped = custom.GetClientEquipped(LocalPlayer(), slotID)
            if not equipped then return end
            local item = custom.GetClientItem and custom.GetClientItem(equipped) or nil
            local menu = DermaMenu()
            local option = menu:AddOption("Снять" .. (item and (" — " .. tostring(item.name or "аксессуар")) or ""), function()
                custom.UnequipInventorySlot(slotID)
            end)
            if option and option.SetIcon then option:SetIcon("icon16/arrow_undo.png") end
            menu:Open()
        end
    end
    local open = btn(equipmentPanel, "Кастомизация", C.accent, 126, 31)
    open:SetPos(7, 30 + #order * 43 + 8); open.DoClick = function() if custom and custom.RequestEditor then custom.RequestEditor() end end

    -- Биоконтроль: окно аугментаций/чипов (GRM.AugmentationUI.Open)
    local augUI = GRM.AugmentationUI
    if augUI and isfunction(augUI.Open) then
        local bio = btn(equipmentPanel, "Биоконтроль", C.green, 126, 31)
        bio:SetPos(7, 30 + #order * 43 + 43)
        bio.DoClick = function() augUI.Open() end
    end
end

-----------------------------------------------------------------------
-- ОКНО ИНВЕНТАРЯ (переделано 31.08 по заказу владельца).
--
-- Было: одно окно 1020x620 появлялось мгновенно, целиком, посреди
-- экрана. Слева в нём — узкая колонка экипировки, справа — слоты.
--
-- Стало (по образцу, который показал владелец): две половины
-- РАЗЪЕЗЖАЮТСЯ из центра. Левая — карточка персонажа: 3D-модель,
-- имя, фракция и полосы состояния. Правая — сетка предметов с
-- деталями. Обе выезжают со своей стороны и гаснут обратно при
-- закрытии.
--
-- Почему две отдельные панели, а не одна с анимацией ширины: половины
-- едут НАВСТРЕЧУ друг другу из-за краёв экрана, у каждой своя
-- траектория. Одной панелью такое движение не получить, а тянуть
-- содержимое resize'ом каждый кадр — дорого и дёргано.
-----------------------------------------------------------------------
INV.Anim = INV.Anim or {}
local A = INV.Anim
A.Time = 0.28           -- длительность выезда, секунды
A.Gap = 14              -- зазор между половинами
A.LeftW = 330
A.RightW = 690
A.Height = 620

--[[ Плавность. Обычная линейная подача выглядит механически: панель
     едет с одинаковой скоростью и резко встаёт. Здесь замедление к
     концу (ease-out) — движение «догоняет» место и мягко
     останавливается. ]]
function A.Ease(t)
    t = math.Clamp(t, 0, 1)
    local inv = 1 - t
    return 1 - inv * inv * inv
end

--[[ Положение половины окна на момент времени.

     progress 0 — панель за краем экрана, 1 — на месте. Возвращает X.
     Вынесено отдельной функцией, чтобы стенд мог проверить траекторию
     без запуска VGUI: именно здесь легко ошибиться со знаком и
     отправить панель не в ту сторону. ]]
function A.SlideX(progress, targetX, fromLeft, panelW, screenW)
    local e = A.Ease(progress)
    local off = fromLeft and -(panelW + 40) or (screenW + 40)
    return math.floor(off + (targetX - off) * e)
end

local charPanel, invPanel, animStart, animClosing

local function layoutMetrics()
    local sw, sh = ScrW(), ScrH()
    local total = A.LeftW + A.Gap + A.RightW
    local x0 = math.floor((sw - total) * 0.5)
    local y = math.floor((sh - A.Height) * 0.5)
    return sw, sh, x0, y
end

--[[ Карточка персонажа. Модель, имя, фракция и полосы состояния —
     те же, что в HUD: берём их из общего реестра GRM.HUD.BarList,
     а не переписываем расчёты заново. Если модуль добавит новую
     полосу (жажда, дыхание), она появится и здесь сама. ]]
local function buildCharPanel(parent)
    local lp = LocalPlayer()

    local mdl = vgui.Create("DModelPanel", parent)
    mdl:SetPos(0, 44)
    mdl:SetSize(A.LeftW, 360)
    mdl:SetFOV(34)
    mdl:SetModel(IsValid(lp) and lp:GetModel() or "models/player/kleiner.mdl")
    mdl:SetAnimated(true)
    local ent = mdl:GetEntity()
    if IsValid(ent) and IsValid(lp) then
        -- Скин и bodygroups: без них форма превращается в базовую модель.
        ent:SetSkin(lp:GetSkin() or 0)
        for i = 0, (lp:GetNumBodyGroups() or 1) - 1 do
            ent:SetBodygroup(i, lp:GetBodygroup(i) or 0)
        end
        local seq = ent:LookupSequence("idle_all_01")
        if not seq or seq < 0 then seq = ent:LookupSequence("idle_subtle") end
        if seq and seq >= 0 then ent:ResetSequence(seq) end
    end
    mdl:SetCamPos(Vector(58, 0, 40))
    mdl:SetLookAt(Vector(0, 0, 38))
    mdl:SetAmbientLight(Color(140, 148, 162))
    mdl:SetDirectionalLight(BOX_TOP, Color(255, 255, 255))
    mdl:SetDirectionalLight(BOX_FRONT, Color(190, 205, 230))
    mdl.LayoutEntity = function(_, e)
        if not IsValid(e) then return end
        e:SetAngles(Angle(0, 32, 0))
        e:FrameAdvance(FrameTime())
    end

    --[[ Полосы состояния. Рисуем в Paint, а не панелями: значения
         меняются каждый кадр, плодить и обновлять VGUI-элементы ради
         этого незачем. ]]
    local bars = vgui.Create("DPanel", parent)
    bars:SetPos(16, 414)
    bars:SetSize(A.LeftW - 32, A.Height - 414 - 16)
    bars:SetPaintBackground(false)
    bars.Paint = function(_, w, h)
        local list = (GRM.HUD and GRM.HUD.BarList) and GRM.HUD.BarList() or {}
        local y = 0
        for _, def in ipairs(list) do
            if y + 34 > h then break end
            local okCall, cur, maxv, text, col = pcall(def.Get)
            if okCall and tonumber(cur) and tonumber(maxv) then
                local frac = math.Clamp(cur / math.max(1, maxv), 0, 1)
                draw.SimpleText(def.label or def.id, "GRMInv2_Small", 0, y, C.dim,
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                if text then
                    draw.SimpleText(tostring(text), "GRMInv2_Small", w, y,
                        col or C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                end
                draw.RoundedBox(3, 0, y + 16, w, 8, Color(24, 30, 40, 230))
                draw.RoundedBox(3, 0, y + 16, math.floor(w * frac), 8, col or C.green)
                y = y + 34
            end
        end
        if y == 0 then
            draw.SimpleText("Полосы состояния не загружены", "GRMInv2_Small", 0, 0,
                C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end
end

function INV.OpenGUI()
    -- Уже открыто — просто обновляем содержимое, не перезапуская выезд.
    if IsValid(invPanel) and not animClosing then
        invPanel:MakePopup()
        rebuildSlots() rebuildDetail() rebuildEquipment()
        return
    end
    if IsValid(charPanel) then charPanel:Remove() end
    if IsValid(invPanel) then invPanel:Remove() end

    local sw, sh, x0, y = layoutMetrics()
    animStart = SysTime()
    animClosing = false

    ------------------------------------------------------------------
    -- ЛЕВАЯ ПОЛОВИНА: персонаж.
    ------------------------------------------------------------------
    local cp = vgui.Create("DPanel")
    charPanel = cp
    GRM.UI.Track("inventory_char", cp)
    cp:SetSize(A.LeftW, A.Height)
    cp:SetPos(-A.LeftW - 40, y)
    cp.Paint = function(_, w, h)
        draw.RoundedBox(9, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(9, 0, 0, w, 40, C.header, true, true, false, false)
        local lp = LocalPlayer()
        local nm = IsValid(lp) and lp:GetNWString("GRM_RPName", "") or ""
        if nm == "" and IsValid(lp) then nm = lp:Nick() end
        draw.SimpleText(GRM.Utf8Ellipsis(nm, 26), "GRMInv2_Title", 15, 20, C.text,
            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local fac = IsValid(lp) and lp:GetNWString("GRM_FactionDisplay", "") or ""
        if fac == "" and IsValid(lp) then fac = lp:GetNWString("GRM_Faction", "") end
        local role = IsValid(lp) and lp:GetNWString("GRM_Role", "") or ""
        local sub = fac
        if role ~= "" then sub = (fac ~= "" and (fac .. " · ") or "") .. role end
        if sub ~= "" then
            draw.SimpleText(GRM.Utf8Ellipsis(sub, 40), "GRMInv2_Small", 16, 50, C.dim,
                TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end
    buildCharPanel(cp)

    ------------------------------------------------------------------
    -- ПРАВАЯ ПОЛОВИНА: предметы.
    ------------------------------------------------------------------
    local f = vgui.Create("DFrame")
    invPanel = f
    frame = f
    GRM.UI.Track("inventory", f)
    f:SetTitle("") f:SetSize(A.RightW, A.Height)
    f:SetPos(sw + 40, y)
    f:MakePopup()
    f:ShowCloseButton(false)
    --[[ Escape закрывает С АНИМАЦИЕЙ. DFrame по Escape зовёт Close(),
         который просто прячет окно: половины остались бы висеть за
         краями экрана, а левая панель — на виду. Перенаправляем на
         свой обратный выезд. ]]
    f.Close = function() INV.CloseGUI() end
    f.OnRemove = function()
        frame = nil
        INV.SelectedSlot = nil
        dragData = nil
        if IsValid(dragImage) then dragImage:Remove() dragImage = nil end
        -- Левая половина живёт вместе с правой: закрыли одну — уходит и вторая.
        if IsValid(charPanel) then charPanel:Remove() end
        charPanel = nil
        invPanel = nil
    end
    f.Paint = function(_, w, h)
        draw.RoundedBox(9, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(9, 0, 0, w, 40, C.header, true, true, false, false)
        draw.SimpleText("ИНВЕНТАРЬ", "GRMInv2_Title", 15, 20, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("ЛКМ + перетащить — переместить  |  ПКМ — использовать", "GRMInv2_Small",
            w - 44, 20, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local x = btn(f, "✕", C.red, 26, 26)
    x:SetPos(A.RightW - 34, 7)
    x.DoClick = function() INV.CloseGUI() end

    weightPanel = vgui.Create("DLabel", f)
    weightPanel:SetPos(16, 48) weightPanel:SetSize(A.RightW - 32, 23)
    weightPanel:SetFont("GRMInv2_Small")
    drawWeight()

    equipmentPanel = vgui.Create("DPanel", f)
    equipmentPanel:SetPos(16, 78) equipmentPanel:SetSize(140, 430)
    equipmentPanel.Paint = function(_, w, h) draw.RoundedBox(7, 0, 0, w, h, C.panel) end

    slotsPanel = vgui.Create("DPanel", f)
    slotsPanel:SetPos(164, 78) slotsPanel:SetSize(510, 332)
    slotsPanel.Paint = function(_, w, h) draw.RoundedBox(7, 0, 0, w, h, C.panel) end

    detailPanel = vgui.Create("DPanel", f)
    detailPanel:SetPos(164, 418) detailPanel:SetSize(330, 90)
    detailPanel.Paint = function(_, w, h) draw.RoundedBox(7, 0, 0, w, h, C.panel) end

    local actions = vgui.Create("DPanel", f)
    actions:SetPos(502, 418) actions:SetSize(172, 90)
    actions.Paint = function(_, w, h) draw.RoundedBox(7, 0, 0, w, h, C.panel) end
    local store = btn(actions, "Убрать оружие", C.accent, 148, 32)
    store:SetPos(12, 10)
    store.DoClick = function() if INV.StoreWeapon then INV.StoreWeapon() end end
    local dropWep = btn(actions, "Выбросить оружие", C.red, 148, 32)
    dropWep:SetPos(12, 48)
    dropWep.DoClick = function() if INV.DropWeapon then INV.DropWeapon() end end

    local footer = vgui.Create("DLabel", f)
    footer:SetPos(16, 516) footer:SetSize(A.RightW - 32, 90) footer:SetWrap(true)
    footer:SetFont("GRMInv2_Small") footer:SetTextColor(C.dim)
    footer:SetText("Перегруз: после 50 кг бег не ускоряет игрока. После 62.5 кг нельзя поднимать новые предметы. Вес учитывает содержимое инвентаря, оружие и боеприпасы.\n/drop — выбросить оружие  |  /store — убрать в инвентарь  |  /inv — открыть инвентарь")

    ------------------------------------------------------------------
    -- Сам выезд. Think, а не таймер: движение должно идти в такт
    -- кадрам, иначе видны рывки.
    ------------------------------------------------------------------
    f.Think = function()
        local t = (SysTime() - (animStart or 0)) / A.Time
        if animClosing then t = 1 - t end
        t = math.Clamp(t, 0, 1)
        local _, _, lx, ly = layoutMetrics()
        if IsValid(charPanel) then
            charPanel:SetPos(A.SlideX(t, lx, true, A.LeftW, ScrW()), ly)
        end
        f:SetPos(A.SlideX(t, lx + A.LeftW + A.Gap, false, A.RightW, ScrW()), ly)
        if animClosing and t <= 0 then
            f:Remove()
        end
    end

    rebuildSlots()
    rebuildDetail()
    rebuildEquipment()
    if surface and surface.PlaySound then surface.PlaySound("ui/buttonclickrelease.wav") end
end

--[[ Открыт ли инвентарь. Нужен биндом клавиши: повторное нажатие
     закрывает окно. Окно, которое уже уезжает, считаем закрытым —
     иначе нажатие во время выезда ничего бы не делало. ]]
function INV.IsOpen()
    return IsValid(invPanel) and not animClosing
end

--[[ Закрытие с обратным выездом. Панели не удаляем сразу: сначала
     доводим анимацию до нуля, и только потом Remove (см. f.Think). ]]
function INV.CloseGUI()
    if not IsValid(invPanel) then return end
    if animClosing then return end
    animClosing = true
    animStart = SysTime()
    -- Курсор отпускаем сразу: держать его во время выезда незачем.
    if IsValid(invPanel) then invPanel:SetMouseInputEnabled(false) end
end

local ModernOpenGUI = INV.OpenGUI
timer.Create("GRMInv2_KeepOpenGUI", 1, 0, function()
    if INV.OpenGUI ~= ModernOpenGUI then INV.OpenGUI = ModernOpenGUI end
end)

-- ── АДМИН: просмотр чужого инвентаря (находка 170) ──
-- Суперадмин открывает инвентарь игрока (C-меню → «Инвентарь игрока: Имя»):
-- видит его слоты и изымает предметы кнопками.
local adminFrame
local function openAdminView()
    local AV = INV.AdminView
    if not AV or not AV.open then return end
    if IsValid(adminFrame) then adminFrame:Remove() end
    adminFrame = vgui.Create("DFrame")
    adminFrame:SetTitle("")
    adminFrame:SetSize(520, 540)
    adminFrame:Center()
    adminFrame:MakePopup()
    adminFrame:ShowCloseButton(false)
    adminFrame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 42, C.header, true, true, false, false)
        draw.SimpleText("ПРОСМОТР ИНВЕНТАРЯ ИГРОКА", "GRMInv2_Normal", 14, 21, C.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("суперадмин • изъятие предметов", "GRMInv2_Small", w - 14, 21, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    local close = btn(adminFrame, "×", C.red, 30, 26)
    close:SetPos(adminFrame:GetWide() - 38, 8)
    close.DoClick = function() adminFrame:Close() if INV.CloseAdminView then INV.CloseAdminView() end end

    local scroll = vgui.Create("DScrollPanel", adminFrame)
    scroll:SetPos(12, 52); scroll:SetSize(496, 440)

    local slots = AV.slots or {}
    local found = 0
    for i = 1, (INV.Config and INV.Config.MaxSlots) or 24 do
        local slot = slots[i]
        if slot and slot.id then
            found = found + 1
            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP); row:SetTall(44); row:DockMargin(0, 0, 0, 6)
            row.Paint = function(_, w, h)
                draw.RoundedBox(6, 0, 0, w, h, Color(33, 42, 56, 245))
                local def = INV.ItemDefs and INV.ItemDefs[slot.id] or nil
                draw.SimpleText((def and def.name) or slot.id, "GRMInv2_Normal", 10, 10, C.text)
                draw.SimpleText("x" .. tostring(slot.count or 1), "GRMInv2_Small", 10, 30, C.dim)
            end
            local takeAll = btn(row, "Изъять все", C.red, 100, 26)
            takeAll:Dock(RIGHT); takeAll:DockMargin(4, 9, 6, 9)
            takeAll.DoClick = function() if INV.AdminTake then INV.AdminTake(i, true) end end
            local take1 = btn(row, "Изъять 1", C.yellow, 84, 26)
            take1:Dock(RIGHT); take1:DockMargin(4, 9, 4, 9)
            take1.DoClick = function() if INV.AdminTake then INV.AdminTake(i, false) end end
            local dup1 = btn(row, "+1", C.green, 52, 26)
            dup1:Dock(RIGHT); dup1:DockMargin(4, 9, 4, 9)
            dup1.DoClick = function() if INV.AdminDup then INV.AdminDup(i, 1) end end
            local dupN = btn(row, "+N", C.accent, 52, 26)
            dupN:Dock(RIGHT); dupN:DockMargin(4, 9, 4, 9)
            dupN.DoClick = function()
                Derma_StringRequest("Дублировать предмет", "Сколько добавить игроку?", "1", function(v)
                    local c = tonumber(v) or 1
                    if c > 0 and INV.AdminDup then INV.AdminDup(i, math.floor(c)) end
                end)
            end
        end
    end
    if found == 0 then
        local l = vgui.Create("DLabel", scroll)
        l:Dock(TOP); l:SetTall(40); l:SetFont("GRMInv2_Normal"); l:SetTextColor(C.dim); l:SetText("Инвентарь игрока пуст.")
    end
end

hook.Add("GRM_InventoryUpdated", "GRMInv2_AdminView", function()
    local AV = INV.AdminView
    if AV and AV.open and not IsValid(adminFrame) then
        openAdminView()
    elseif AV and AV.open and IsValid(adminFrame) then
        -- обновить содержимое (слоты могли измениться после изъятия)
        openAdminView()
    end
end)

-- Хук на открытие чужого инвентаря: ресивер ставит AV.open и шлёт уведомление
hook.Add("GRM_AdminViewRequested", "GRMInv2_AdminViewOpen", function()
    openAdminView()
end)

hook.Add("GRM_InventoryUpdated", "GRMInv2_Refresh", function()
    if IsValid(frame) then rebuildSlots(); rebuildDetail() end
end)

hook.Add("GRM_InventoryWeightUpdated", "GRMInv2_WeightRefresh", function()
    if IsValid(weightPanel) then drawWeight() end
end)

hook.Add("GRM_CustomizationUpdated", "GRMInv2_EquipmentRefresh", function()
    if IsValid(equipmentPanel) then rebuildEquipment() end
end)

print("[GRM] Inventory UI v2.1 loaded")
