include("shared.lua")

-- Создаём шрифт для надписи
surface.CreateFont("OreBuyerLabel", {
    font = "Arial",
    size = 22,
    weight = 700,
    antialias = true,
})

-- ============================================================
-- ОТРИСОВКА НАДПИСИ НАД СКУПЩИКОМ
-- ============================================================
hook.Add("HUDPaint", "GRM_OreBuyerLabel", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local pos = ply:GetPos()
    local maxDist = 300

    for _, ent in ipairs(ents.FindByClass("grm_ore_buyer")) do
        if IsValid(ent) then
            local dist = pos:Distance(ent:GetPos())
            if dist <= maxDist then
                local offset = Vector(0, 0, 50)
                local screenPos = (ent:GetPos() + offset):ToScreen()
                if screenPos.visible then
                    local x, y = screenPos.x, screenPos.y
                    local alpha = math.Clamp(255 - (dist / maxDist) * 200, 55, 255)

                    local text = "Скупщик руды"
                    surface.SetFont("OreBuyerLabel")
        local tw, th = surface.GetTextSize(text)

        local padding = 8
        local bgW = tw + padding * 2
        local bgH = th + padding * 2
        local bgX = x - padding
        local bgY = y - padding

        surface.SetDrawColor(0, 0, 0, alpha * 0.6)
        surface.DrawRect(bgX, bgY, bgW, bgH)

        surface.SetTextColor(0, 0, 0, alpha * 0.8)
        surface.SetFont("OreBuyerLabel")
        surface.SetTextPos(x + 2, y + 2)
        surface.DrawText(text)

                    surface.SetTextColor(255, 220, 80, alpha)
                    surface.SetFont("OreBuyerLabel")
                    surface.SetTextPos(x, y)
                    surface.DrawText(text)
                end
            end
        end
    end
end)

-- ============================================================
-- GUI ПРОДАЖИ + ВЫДАЧА/СДАЧА БУРА
-- ============================================================
local function OpenBuyerGUI(prices)
    if not prices or table.Count(prices) == 0 then
        notification.AddLegacy("Цены на руду не установлены (админ: !setoreprice)", NOTIFY_ERROR, 4)
        return
    end

    local frame = vgui.Create("DFrame")
    frame:SetTitle("Скупщик руды")
    frame:SetSize(500, 420)
    frame:Center()
    frame:MakePopup()

    local list = vgui.Create("DListView", frame)
    list:Dock(FILL)
    list:DockMargin(4, 4, 4, 4)
    list:AddColumn("Тип руды")
    list:AddColumn("Цена за шт.")
    list:AddColumn("У вас")
    list:AddColumn("Продать всё")

    local slots = GRM.Inventory.LocalSlots or {}
    local oreCounts = {}
    for _, slot in pairs(slots) do
        if slot.id and slot.id:match("^ore_") then
            local oreType = slot.id:match("ore_(.+)")
            oreCounts[oreType] = (oreCounts[oreType] or 0) + (slot.count or 1)
        end
    end

    local hasItems = false
    for oreType, price in pairs(prices) do
        if price > 0 then
            local count = oreCounts[oreType] or 0
            local line = list:AddLine(
                oreType:sub(1,1):upper() .. oreType:sub(2),
                GRM.Format(price),
                tostring(count),
                count > 0 and "Продать" or "—"
            )
            line._oreType = oreType
            line._price = price
            line._count = count
            if count > 0 then hasItems = true end
        end
    end

    if not hasItems then
        local lbl = vgui.Create("DLabel", list)
        lbl:SetText("У вас нет руды для продажи.")
        lbl:SetFont("DermaDefaultBold")
        lbl:SetPos(10, 10)
        lbl:SizeToContents()
    end

    function list:OnRowSelected(rowIndex, line)
        if not line then return end
        if line._count <= 0 then
            notification.AddLegacy("У вас нет этой руды", NOTIFY_ERROR, 3)
            return
        end
        net.Start("grm_ore_sell")
            net.WriteString(line._oreType)
        net.SendToServer()
        frame:Close()
    end

    -- ============================================================
    -- КНОПКА "ПОЛУЧИТЬ БУР"
    -- ============================================================
    local btnJackhammer = vgui.Create("DButton", frame)
    btnJackhammer:SetText("Получить бур")
    btnJackhammer:Dock(BOTTOM)
    btnJackhammer:SetTall(32)
    btnJackhammer:SetFont("DermaDefaultBold")
    btnJackhammer:SetTextColor(Color(255, 255, 255))
    btnJackhammer.Paint = function(s, w, h)
        local col = s:IsHovered() and Color(60, 140, 60) or Color(40, 100, 40)
        draw.RoundedBox(6, 0, 0, w, h, col)
    end
    btnJackhammer.DoClick = function()
        surface.PlaySound("items/ammo_pickup.wav")   -- звук выдачи
        net.Start("grm_ore_buyer_give_jackhammer")
        net.SendToServer()
        frame:Close()
    end

    -- ============================================================
    -- КНОПКА "СДАТЬ БУР"
    -- ============================================================
    local btnReturn = vgui.Create("DButton", frame)
    btnReturn:SetText("Сдать бур")
    btnReturn:Dock(BOTTOM)
    btnReturn:SetTall(32)
    btnReturn:SetFont("DermaDefaultBold")
    btnReturn:SetTextColor(Color(255, 255, 255))
    btnReturn.Paint = function(s, w, h)
        local col = s:IsHovered() and Color(140, 60, 60) or Color(100, 40, 40)
        draw.RoundedBox(6, 0, 0, w, h, col)
    end
    btnReturn.DoClick = function()
        surface.PlaySound("items/weapon_drop.wav")   -- звук сдачи
        net.Start("grm_ore_buyer_return_jackhammer")
        net.SendToServer()
        frame:Close()
    end

    -- ============================================================
    -- КНОПКА "ЗАКРЫТЬ"
    -- ============================================================
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetText("Закрыть")
    closeBtn:Dock(BOTTOM)
    closeBtn:SetTall(30)
    closeBtn.DoClick = function() frame:Close() end
end

net.Receive("grm_ore_buyer_open", function()
    local prices = net.ReadTable() or {}
    OpenBuyerGUI(prices)
end)

print("[GRM Ore Buyer] Клиент загружен (с звуками на кнопки)")
