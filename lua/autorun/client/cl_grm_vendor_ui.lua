if not CLIENT then return end

GRM = GRM or {}
GRM.Vendor = GRM.Vendor or {}
GRM.Vendor.UI = GRM.Vendor.UI or {}

local CUI = {
    bg       = Color(19, 24, 33, 248),
    panel    = Color(33, 42, 56, 245),
    accent   = Color(70, 155, 255),
    green    = Color(55, 185, 105),
    red      = Color(205, 70, 65),
    yellow   = Color(235, 180, 60),
    text     = Color(240, 244, 250),
    dim      = Color(166, 176, 191),
    slotBg   = Color(20, 22, 30, 220),
    slotBorder = Color(60, 65, 80, 200),
}

surface.CreateFont("GRM_Vendor_Title",  { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("GRM_Vendor_Item",   { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("GRM_Vendor_Small",  { font = "Roboto", size = 12, weight = 400, extended = true })
surface.CreateFont("GRM_Vendor_Price",  { font = "Roboto", size = 14, weight = 700, extended = true })

local function money(n) return GRM.Format and GRM.Format(n) or (tostring(n).." GRM") end

local vendorEnt = nil
local vendorType = nil
local catalog = {}

net.Receive("GRM_Vendor_Open", function()
    vendorEnt = net.ReadEntity()
    vendorType = net.ReadString()
    catalog = net.ReadTable() or {}

    if IsValid(GRM.Vendor.UI.Frame) then GRM.Vendor.UI.Frame:Close() end

    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(720, 560)
    frame:Center()
    frame:MakePopup()
    frame:ShowCloseButton(false)
    GRM.Vendor.UI.Frame = frame

    local titles = { weapon = "Арсенал", ore = "Скупка руды", food = "Ларек еды", rare = "Редкости" }

    frame.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, CUI.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 44, Color(27, 35, 48), true, true, false, false)
        draw.SimpleText(titles[vendorType] or "Торгаш", "GRM_Vendor_Title", 16, 22, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local bal = GRM.PlayerBalance or 0
        draw.SimpleText("Наличные: "..money(bal), "GRM_Vendor_Price", w - 16, 22, CUI.green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", frame)
    close:SetText("") close:SetPos(frame:GetWide() - 38, 8) close:SetSize(24, 24)
    close.DoClick = function() frame:Close() end
    close.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(196, 62, 62) or Color(46, 56, 74))
        surface.SetDrawColor(240, 242, 246)
        surface.DrawLine(7, 7, w-7, h-7)
        surface.DrawLine(7, h-7, w-7, 7)
    end

    local cats = {}
    for id, item in pairs(catalog) do
        local cat = item.category or "Прочее"
        cats[cat] = cats[cat] or {}
        cats[cat][id] = item
    end

    local sheet = vgui.Create("DPropertySheet", frame)
    sheet:Dock(FILL)
    sheet:DockMargin(8, 52, 8, 8)

    for catName, items in pairs(cats) do
        local panel = vgui.Create("DScrollPanel", sheet)
        panel:SetPaintBackground(false)
        panel.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, CUI.panel) end
        local sh = sheet:AddSheet(catName, panel, "icon16/box.png")
        sh.Tab:SetFont("GRM_Vendor_Item")

        local y = 6
        for id, item in pairs(items) do
            local row = vgui.Create("DPanel", panel)
            row:SetPos(6, y)
            row:SetSize(panel:GetWide() - 20, 72)
            y = y + 78

            row.Paint = function(_, w, h)
                draw.RoundedBox(6, 0, 0, w, h, CUI.slotBg)
                surface.SetDrawColor(CUI.slotBorder)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText(item.name, "GRM_Vendor_Item", 84, 10, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(item.desc or "", "GRM_Vendor_Small", 84, 30, CUI.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("Цена: "..money(item.price), "GRM_Vendor_Price", w - 12, 10, CUI.yellow, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                if item.hunger then draw.SimpleText("Сытость: +"..item.hunger.."  HP: +"..(item.health or 0), "GRM_Vendor_Small", 84, 50, CUI.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end
                if item.maxStack then draw.SimpleText("Макс. стак: "..item.maxStack, "GRM_Vendor_Small", 84, 50, CUI.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP) end
            end

            if item.model and item.model ~= "" then
                local mdl = vgui.Create("DModelPanel", row)
                mdl:SetPos(6, 4)
                mdl:SetSize(70, 64)
                mdl:SetModel(item.model)
                mdl:SetCamPos(Vector(25, 25, 15))
                mdl:SetLookAt(Vector(0, 0, 0))
                mdl:SetFOV(30)
                function mdl:LayoutEntity() end
            end

            local buy = vgui.Create("DButton", row)
            buy:SetPos(row:GetWide() - 110, 20)
            buy:SetSize(96, 30)
            buy:SetText("Купить")
            buy:SetFont("GRM_Vendor_Item")
            buy:SetTextColor(color_white)
            buy.Paint = function(s, w, h)
                local can = GRM.HasMoney and GRM.HasMoney(LocalPlayer(), item.price) or true
                local col = not can and Color(70,75,84) or (s:IsHovered() and Color(75,170,95) or CUI.green)
                draw.RoundedBox(5, 0, 0, w, h, col)
            end
            buy.DoClick = function()
                net.Start("GRM_Vendor_Buy")
                    net.WriteEntity(vendorEnt)
                    net.WriteString(id)
                net.SendToServer()
            end

            local sellPrice = GRM.Vendor and GRM.Vendor.GetSellPrice and GRM.Vendor.GetSellPrice(LocalPlayer(), vendorType, id) or 0
            if sellPrice > 0 then
                local sell = vgui.Create("DButton", row)
                sell:SetPos(row:GetWide() - 110, 54)
                sell:SetSize(96, 24)
                sell:SetText("Продать ("..money(sellPrice)..")")
                sell:SetFont("GRM_Vendor_Small")
                sell:SetTextColor(color_white)
                sell.Paint = function(s, w, h)
                    local col = s:IsHovered() and Color(180, 90, 80) or CUI.red
                    draw.RoundedBox(5, 0, 0, w, h, col)
                end
                sell.DoClick = function()
                    Derma_StringRequest("Сколько продать?", "Введите количество:", "1", function(val)
                        local c = math.max(1, math.floor(tonumber(val) or 1))
                        net.Start("GRM_Vendor_Sell")
                            net.WriteEntity(vendorEnt)
                            net.WriteString(id)
                            net.WriteUInt(c, 16)
                        net.SendToServer()
                    end)
                end
            end
        end
    end
end)

print("[GRM Vendor] Client UI loaded")