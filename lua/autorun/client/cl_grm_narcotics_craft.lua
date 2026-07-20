--[[--------------------------------------------------------------------
    GRM Narcotics Craft UI - Client v1.0 (Код 120)
----------------------------------------------------------------------]]

if SERVER then return end

GRM = GRM or {}
GRM.NarcCraft = GRM.NarcCraft or {}
local CRAFT = GRM.NarcCraft

surface.CreateFont("GRM_Craft_Title", {font = "Roboto", size = 18, weight = 700, extended = true})
surface.CreateFont("GRM_Craft_Normal", {font = "Roboto", size = 14, weight = 500, extended = true})
surface.CreateFont("GRM_Craft_Small", {font = "Roboto", size = 12, weight = 400, extended = true})

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

-- ============================================================
-- ОТКРЫТИЕ МЕНЮ
-- ============================================================
net.Receive("GRM_NarcCraft_Open", function()
    local labType = net.ReadString()
    local recipeCount = net.ReadUInt(8)
    
    local recipes = {}
    for i = 1, recipeCount do
        local id = net.ReadString()
        local name = net.ReadString()
        local time = net.ReadUInt(16)
        local yield = net.ReadUInt(8)
        local ingCount = net.ReadUInt(8)
        local ingredients = {}
        for j = 1, ingCount do
            local ingID = net.ReadString()
            local ingCount = net.ReadUInt(8)
            ingredients[ingID] = ingCount
        end
        recipes[id] = {name = name, time = time, yield = yield, ingredients = ingredients}
    end
    
    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(600, 500)
    frame:Center()
    frame:MakePopup()
    frame:ShowCloseButton(true)
    
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, CUI.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 36, Color(27, 35, 48), true, true, false, false)
        local title = (labType == "narc" and "Лаборатория наркотиков" or "Медицинская лаборатория")
        draw.SimpleText(title, "GRM_Craft_Title", 12, 18, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(8, 44, 8, 8)
    
    for id, recipe in pairs(recipes) do
        local row = vgui.Create("DPanel", scroll)
        row:Dock(TOP)
        row:SetTall(80)
        row:DockMargin(0, 0, 0, 5)
        
        row.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, CUI.panel)
            draw.SimpleText(recipe.name, "GRM_Craft_Normal", 10, 8, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(string.format("Время: %d сек | Выход: %d шт", recipe.time, recipe.yield), "GRM_Craft_Small", 10, 30, CUI.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            
            -- Ингредиенты
            local ingText = "Ингредиенты: "
            for ing, count in pairs(recipe.ingredients) do
                ingText = ingText .. ing .. "×" .. count .. " "
            end
            draw.SimpleText(ingText, "GRM_Craft_Small", 10, 50, CUI.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        
        local btn = vgui.Create("DButton", row)
        btn:Dock(RIGHT)
        btn:SetWide(100)
        btn:DockMargin(0, 20, 10, 20)
        btn:SetText("Варить")
        btn:SetFont("GRM_Craft_Normal")
        btn.Paint = function(self, w, h)
            local col = self:IsHovered() and Color(75, 205, 125) or CUI.green
            draw.RoundedBox(5, 0, 0, w, h, col)
            draw.SimpleText("Варить", "GRM_Craft_Normal", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            net.Start("GRM_NarcCraft_Start")
                net.WriteString(labType)
                net.WriteString(id)
            net.SendToServer()
            frame:Close()
        end
    end
end)

-- ============================================================
-- ПРОГРЕСС
-- ============================================================
net.Receive("GRM_NarcCraft_Progress", function()
    local name = net.ReadString()
    local time = net.ReadUInt(16)
    
    notification.AddLegacy("Варка " .. name .. " (" .. time .. " сек)...", NOTIFY_GENERIC, time)
end)

-- ============================================================
-- ЗАВЕРШЕНИЕ
-- ============================================================
net.Receive("GRM_NarcCraft_Done", function()
    local name = net.ReadString()
    notification.AddLegacy(name .. " готово!", NOTIFY_GENERIC, 5)
end)

print("[GRM] Narcotics Craft UI Client loaded")
