--[[--------------------------------------------------------------------
    GRM Search Result UI - Client (Код 121)
----------------------------------------------------------------------]]

if SERVER then return end

net.Receive("GRM_Search_Result", function()
    local searcher = net.ReadEntity()
    local target = net.ReadEntity()
    local foundCount = net.ReadUInt(8)
    
    local found = {}
    for i = 1, foundCount do
        local type = net.ReadString()
        local id = net.ReadString()
        local count = net.ReadUInt(8)
        found[#found + 1] = {type = type, id = id, count = count}
    end
    
    local confiscatedCount = net.ReadUInt(8)
    local confiscated = {}
    for i = 1, confiscatedCount do
        confiscated[#confiscated + 1] = net.ReadString()
    end
    
    -- Показываем результат
    local frame = vgui.Create("DFrame")
    frame:SetTitle("Результат обыска: " .. target:Nick())
    frame:SetSize(400, 300)
    frame:Center()
    frame:MakePopup()
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(8, 30, 8, 8)
    
    if #found == 0 then
        local label = vgui.Create("DLabel", scroll)
        label:Dock(TOP)
        label:SetTall(30)
        label:SetText("Ничего не найдено")
        label:SetTextColor(Color(100, 220, 100))
        label:SetFont("DermaDefault")
    else
        local label = vgui.Create("DLabel", scroll)
        label:Dock(TOP)
        label:SetTall(30)
        label:SetText("Найдено запрещённых предметов:")
        label:SetTextColor(Color(255, 100, 100))
        label:SetFont("DermaDefaultBold")
        
        for _, item in ipairs(found) do
            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP)
            row:SetTall(40)
            row:DockMargin(0, 2, 0, 2)
            
            row.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
            end
            
            local icon = item.type == "weapon" and "" or "📦"
            local text = string.format("%s %s × %d", icon, item.id, item.count)
            
            local label = vgui.Create("DLabel", row)
            label:Dock(FILL)
            label:DockMargin(8, 0, 0, 0)
            label:SetText(text)
            label:SetTextColor(Color(255, 200, 100))
            label:SetFont("DermaDefault")
        end
    end
    
    if #confiscated > 0 then
        local label = vgui.Create("DLabel", scroll)
        label:Dock(TOP)
        label:SetTall(30)
        label:DockMargin(0, 10, 0, 0)
        label:SetText("Изъято: " .. #confiscated .. " предметов")
        label:SetTextColor(Color(255, 150, 100))
        label:SetFont("DermaDefaultBold")
    end
end)
