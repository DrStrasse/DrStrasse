--[[--------------------------------------------------------------------
    GRM Faction Permissions UI - Client (Код 122)
    Вкладка "Экономика" в /factions для настройки доступов
----------------------------------------------------------------------]]

if SERVER then return end

surface.CreateFont("GRMFPerm_Title", {font = "Roboto", size = 18, weight = 700, extended = true})
surface.CreateFont("GRMFPerm_Normal", {font = "Roboto", size = 14, weight = 500, extended = true})
surface.CreateFont("GRMFPerm_Small", {font = "Roboto", size = 12, weight = 400, extended = true})

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

net.Receive("GRM_FPerm_Open", function()
    local factions = net.ReadTable() or {}
    local perms = net.ReadTable() or {}
    
    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(800, 600)
    frame:Center()
    frame:MakePopup()
    frame:ShowCloseButton(true)
    
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, CUI.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 36, Color(27, 35, 48), true, true, false, false)
        draw.SimpleText("Доступы фракций к экономике", "GRMFPerm_Title", 12, 18, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    
    -- Список фракций слева
    local factionList = vgui.Create("DListView", frame)
    factionList:Dock(LEFT)
    factionList:SetWide(250)
    factionList:DockMargin(8, 44, 4, 8)
    factionList:AddColumn("Фракция")
    factionList:SetMultiSelect(false)
    
    for name, data in pairs(factions) do
        local line = factionList:AddLine(name)
        line.FactionName = name
    end
    
    -- Панель доступов справа
    local permsPanel = vgui.Create("DPanel", frame)
    permsPanel:Dock(FILL)
    permsPanel:DockMargin(4, 44, 8, 8)
    permsPanel:SetPaintBackground(false)
    
    local scroll = vgui.Create("DScrollPanel", permsPanel)
    scroll:Dock(FILL)
    
    local currentFaction = nil
    
    -- Функция обновления панели доступов
    local function updatePermsPanel()
        scroll:Clear()
        
        if not currentFaction then
            local label = vgui.Create("DLabel", scroll)
            label:Dock(TOP)
            label:SetTall(30)
            label:SetText("Выберите фракцию слева")
            label:SetTextColor(CUI.dim)
            label:SetFont("GRMFPerm_Normal")
            return
        end
        
        local factionPerms = perms[currentFaction] or {}
        
        -- Заголовок
        local header = vgui.Create("DLabel", scroll)
        header:Dock(TOP)
        header:SetTall(30)
        header:SetText("Доступы: " .. currentFaction)
        header:SetTextColor(CUI.text)
        header:SetFont("GRMFPerm_Title")
        header:DockMargin(0, 0, 0, 10)
        
        -- Категории
        local categories = {
            state_budget = "Гос.бюджет",
            faction_budget = "Бюджеты фракций",
            tax = "Налоги",
            fine = "Штрафы",
            kom_hour = "Комендантский час",
            law = "Законы",
        }
        
        for catID, catName in pairs(categories) do
            -- Заголовок категории
            local catLabel = vgui.Create("DLabel", scroll)
            catLabel:Dock(TOP)
            catLabel:SetTall(25)
            catLabel:SetText(catName)
            catLabel:SetTextColor(CUI.accent)
            catLabel:SetFont("GRMFPerm_Normal")
            catLabel:DockMargin(0, 10, 0, 5)
            
            -- Доступы в категории
            for permID, permName in pairs(GRM.FactionPerms.Permissions) do
                if string.StartWith(permID, catID .. "_") then
                    local row = vgui.Create("DPanel", scroll)
                    row:Dock(TOP)
                    row:SetTall(35)
                    row:DockMargin(0, 0, 0, 2)
                    
                    row.Paint = function(self, w, h)
                        draw.RoundedBox(4, 0, 0, w, h, CUI.panel)
                    end
                    
                    local checkbox = vgui.Create("DCheckBoxLabel", row)
                    checkbox:Dock(LEFT)
                    checkbox:DockMargin(8, 0, 0, 0)
                    checkbox:SetText(permName)
                    checkbox:SetTextColor(CUI.text)
                    checkbox:SetFont("GRMFPerm_Small")
                    checkbox:SetValue(factionPerms[permID] or false)
                    
                    checkbox.OnChange = function(self, val)
                        net.Start("GRM_FPerm_Set")
                            net.WriteString(currentFaction)
                            net.WriteString(permID)
                            net.WriteBool(val)
                        net.SendToServer()
                    end
                end
            end
        end
    end
    
    -- Обработчик выбора фракции
    factionList.OnRowSelected = function(_, lineID, line)
        currentFaction = line.FactionName
        updatePermsPanel()
    end
    
    updatePermsPanel()
end)
