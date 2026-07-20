--[[--------------------------------------------------------------------
    GRM Feco Admin — вкладка "Экономика" в /factions для суперадмина
    
    Даёт доступ к:
    - Гос.бюджет (просмотр, пополнение, снятие)
    - Фракционные бюджеты (просмотр, изменение)
    - Налоги (просмотр, изменение ставки)
    - Штрафы (настройка)
    
    Открывается через /factions → вкладка "Экономика" (только суперадмин)
    Или через !grmmenu / grm_adminmenu
----------------------------------------------------------------------]]

if SERVER then
    AddCSLuaFile()
end

GRM = GRM or {}
GRM.FecoAdmin = GRM.FecoAdmin or {}

-- ================================================================
-- СЕРВЕРНАЯ ЧАСТЬ
-- ================================================================

if SERVER then
    local NET_OPEN = "GRM_FecoAdmin_Open"
    local NET_DATA = "GRM_FecoAdmin_Data"
    local NET_ACTION = "GRM_FecoAdmin_Action"
    
    util.AddNetworkString(NET_OPEN)
    util.AddNetworkString(NET_DATA)
    util.AddNetworkString(NET_ACTION)
    
    -- Обработчик открытия меню
    net.Receive(NET_OPEN, function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        
        local data = {}
        
        -- Гос.бюджет
        if GRM.Economy and GRM.Economy.Data and GRM.Economy.Data.state then
            data.stateBudget = GRM.Economy.Data.state.budget or 0
        else
            data.stateBudget = 0
        end
        
        -- Фракции
        data.factions = {}
        if GRM.Economy and GRM.Economy.Data and GRM.Economy.Data.factions then
            for name, eco in pairs(GRM.Economy.Data.factions) do
                data.factions[name] = {
                    budget = eco.budget or 0,
                    taxRate = eco.taxRate or 0.05,
                    baseSalary = eco.baseSalary or 0,
                }
            end
        end
        
        -- Игроки онлайн с балансами
        data.players = {}
        if GRM.GetAllBalances then
            local balances = GRM.GetAllBalances()
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) then
                    local sid64 = p:SteamID64()
                    data.players[#data.players + 1] = {
                        name = p:Nick(),
                        sid64 = sid64,
                        balance = balances and balances[sid64] and balances[sid64].balance or 0,
                    }
                end
            end
        end
        
        net.Start(NET_DATA)
            net.WriteTable(data)
        net.Send(ply)
    end)
    
    -- Обработчик действий
    net.Receive(NET_ACTION, function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        
        local action = net.ReadString()
        local target = net.ReadString()
        local amount = net.ReadUInt(32)
        local rate = net.ReadFloat()
        
        if action == "state_add" then
            -- Пополнить гос.бюджет
            if GRM.Economy and GRM.Economy.Data and GRM.Economy.Data.state then
                GRM.Economy.Data.state.budget = (GRM.Economy.Data.state.budget or 0) + amount
                GRM.Economy.Dirty = true
                GRM.Economy.Save(true, "admin: state_add " .. amount)
                ply:ChatPrint("[GRM Feco] Гос.бюджет пополнен на " .. (GRM.Format and GRM.Format(amount) or amount))
            end
            
        elseif action == "state_remove" then
            -- Снять с гос.бюджета
            if GRM.Economy and GRM.Economy.Data and GRM.Economy.Data.state then
                GRM.Economy.Data.state.budget = math.max(0, (GRM.Economy.Data.state.budget or 0) - amount)
                GRM.Economy.Dirty = true
                GRM.Economy.Save(true, "admin: state_remove " .. amount)
                ply:ChatPrint("[GRM Feco] С гос.бюджета снято " .. (GRM.Format and GRM.Format(amount) or amount))
            end
            
        elseif action == "faction_budget" then
            -- Установить бюджет фракции
            if GRM.Economy and GRM.Economy.Data and GRM.Economy.Data.factions and GRM.Economy.Data.factions[target] then
                GRM.Economy.Data.factions[target].budget = amount
                GRM.Economy.Dirty = true
                GRM.Economy.Save(true, "admin: faction_budget " .. target .. " = " .. amount)
                ply:ChatPrint("[GRM Feco] Бюджет фракции " .. target .. " установлен: " .. (GRM.Format and GRM.Format(amount) or amount))
            end
            
        elseif action == "faction_tax" then
            -- Установить налог фракции
            if GRM.Economy and GRM.Economy.Data and GRM.Economy.Data.factions and GRM.Economy.Data.factions[target] then
                GRM.Economy.Data.factions[target].taxRate = math.Clamp(rate, 0, 0.5)
                GRM.Economy.Dirty = true
                GRM.Economy.Save(true, "admin: faction_tax " .. target .. " = " .. rate)
                ply:ChatPrint("[GRM Feco] Налог фракции " .. target .. " установлен: " .. math.floor(rate * 100) .. "%")
            end
            
        elseif action == "player_balance" then
            -- Установить баланс игрока
            if GRM and GRM.SetBalance then
                GRM.SetBalance(target, amount)
                ply:ChatPrint("[GRM Feco] Баланс игрока " .. target .. " установлен: " .. (GRM.Format and GRM.Format(amount) or amount))
            end
        end
    end)
end

-- ================================================================
-- КЛИЕНТСКАЯ ЧАСТЬ
-- ================================================================

if CLIENT then
    surface.CreateFont("GRMFeco_Title", {font = "Roboto", size = 18, weight = 700, extended = true})
    surface.CreateFont("GRMFeco_Normal", {font = "Roboto", size = 14, weight = 500, extended = true})
    surface.CreateFont("GRMFeco_Small", {font = "Roboto", size = 12, weight = 400, extended = true})
    
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
    
    local function openFecoAdmin()
        net.Start("GRM_FecoAdmin_Open")
        net.SendToServer()
    end
    
    net.Receive("GRM_FecoAdmin_Data", function()
        local data = net.ReadTable() or {}
        
        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:SetSize(900, 650)
        frame:Center()
        frame:MakePopup()
        frame:ShowCloseButton(true)
        
        frame.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, CUI.bg)
            draw.RoundedBoxEx(8, 0, 0, w, 36, Color(27, 35, 48), true, true, false, false)
            draw.SimpleText("Экономика (Суперадмин)", "GRMFeco_Title", 12, 18, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        
        local tabs = vgui.Create("DPropertySheet", frame)
        tabs:Dock(FILL)
        tabs:DockMargin(4, 40, 4, 4)
        
        -- Вкладка 1: Гос.бюджет
        local statePanel = vgui.Create("DPanel", tabs)
        statePanel:DockPadding(10, 10, 10, 10)
        
        local stateLabel = vgui.Create("DLabel", statePanel)
        stateLabel:Dock(TOP)
        stateLabel:SetTall(30)
        stateLabel:SetFont("GRMFeco_Title")
        stateLabel:SetTextColor(CUI.text)
        stateLabel:SetText("Государственный бюджет: " .. (GRM.Format and GRM.Format(data.stateBudget or 0) or (data.stateBudget or 0) .. " GRM"))
        stateLabel:DockMargin(0, 0, 0, 10)
        
        local stateAdd = vgui.Create("DButton", statePanel)
        stateAdd:Dock(TOP)
        stateAdd:SetTall(30)
        stateAdd:SetText("Пополнить гос.бюджет")
        stateAdd:SetFont("GRMFeco_Normal")
        stateAdd:DockMargin(0, 0, 0, 5)
        stateAdd.DoClick = function()
            Derma_StringRequest("Пополнить гос.бюджет", "Сумма:", "", function(val)
                local amount = math.floor(tonumber(val) or 0)
                if amount > 0 then
                    net.Start("GRM_FecoAdmin_Action")
                        net.WriteString("state_add")
                        net.WriteString("")
                        net.WriteUInt(amount, 32)
                        net.WriteFloat(0)
                    net.SendToServer()
                    frame:Close()
                    openFecoAdmin()
                end
            end)
        end
        
        local stateRemove = vgui.Create("DButton", statePanel)
        stateRemove:Dock(TOP)
        stateRemove:SetTall(30)
        stateRemove:SetText("Снять с гос.бюджета")
        stateRemove:SetFont("GRMFeco_Normal")
        stateRemove:DockMargin(0, 0, 0, 5)
        stateRemove.DoClick = function()
            Derma_StringRequest("Снять с гос.бюджета", "Сумма:", "", function(val)
                local amount = math.floor(tonumber(val) or 0)
                if amount > 0 then
                    net.Start("GRM_FecoAdmin_Action")
                        net.WriteString("state_remove")
                        net.WriteString("")
                        net.WriteUInt(amount, 32)
                        net.WriteFloat(0)
                    net.SendToServer()
                    frame:Close()
                    openFecoAdmin()
                end
            end)
        end
        
        tabs:AddSheet("Гос.бюджет", statePanel, "icon16/money_dollar.png")
        
        -- Вкладка 2: Фракции
        local factionsPanel = vgui.Create("DPanel", tabs)
        factionsPanel:DockPadding(10, 10, 10, 10)
        
        local factionsScroll = vgui.Create("DScrollPanel", factionsPanel)
        factionsScroll:Dock(FILL)
        
        for name, eco in pairs(data.factions or {}) do
            local row = vgui.Create("DPanel", factionsScroll)
            row:Dock(TOP)
            row:SetTall(80)
            row:DockMargin(0, 0, 0, 5)
            row.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, CUI.panel)
            end
            
            local nameLabel = vgui.Create("DLabel", row)
            nameLabel:SetPos(10, 5)
            nameLabel:SetSize(200, 20)
            nameLabel:SetFont("GRMFeco_Normal")
            nameLabel:SetTextColor(CUI.text)
            nameLabel:SetText("Фракция: " .. name)
            
            local budgetLabel = vgui.Create("DLabel", row)
            budgetLabel:SetPos(10, 30)
            budgetLabel:SetSize(200, 20)
            budgetLabel:SetFont("GRMFeco_Small")
            budgetLabel:SetTextColor(CUI.dim)
            budgetLabel:SetText("Бюджет: " .. (GRM.Format and GRM.Format(eco.budget or 0) or (eco.budget or 0) .. " GRM"))
            
            local taxLabel = vgui.Create("DLabel", row)
            taxLabel:SetPos(10, 55)
            taxLabel:SetSize(200, 20)
            taxLabel:SetFont("GRMFeco_Small")
            taxLabel:SetTextColor(CUI.dim)
            taxLabel:SetText("Налог: " .. math.floor((eco.taxRate or 0.05) * 100) .. "%")
            
            local btnBudget = vgui.Create("DButton", row)
            btnBudget:SetPos(600, 10)
            btnBudget:SetSize(120, 25)
            btnBudget:SetText("Изменить бюджет")
            btnBudget:SetFont("GRMFeco_Small")
            btnBudget.DoClick = function()
                Derma_StringRequest("Бюджет фракции " .. name, "Сумма:", tostring(eco.budget or 0), function(val)
                    local amount = math.floor(tonumber(val) or 0)
                    if amount >= 0 then
                        net.Start("GRM_FecoAdmin_Action")
                            net.WriteString("faction_budget")
                            net.WriteString(name)
                            net.WriteUInt(amount, 32)
                            net.WriteFloat(0)
                        net.SendToServer()
                        frame:Close()
                        openFecoAdmin()
                    end
                end)
            end
            
            local btnTax = vgui.Create("DButton", row)
            btnTax:SetPos(600, 45)
            btnTax:SetSize(120, 25)
            btnTax:SetText("Изменить налог")
            btnTax:SetFont("GRMFeco_Small")
            btnTax.DoClick = function()
                Derma_StringRequest("Налог фракции " .. name, "Ставка (0-50):", tostring(math.floor((eco.taxRate or 0.05) * 100)), function(val)
                    local rate = math.Clamp(tonumber(val) or 5, 0, 50) / 100
                    net.Start("GRM_FecoAdmin_Action")
                        net.WriteString("faction_tax")
                        net.WriteString(name)
                        net.WriteUInt(0, 32)
                        net.WriteFloat(rate)
                    net.SendToServer()
                    frame:Close()
                    openFecoAdmin()
                end)
            end
        end
        
        tabs:AddSheet("Фракции", factionsPanel, "icon16/group.png")
        
        -- Вкладка 3: Игроки
        local playersPanel = vgui.Create("DPanel", tabs)
        playersPanel:DockPadding(10, 10, 10, 10)
        
        local playersScroll = vgui.Create("DScrollPanel", playersPanel)
        playersScroll:Dock(FILL)
        
        for _, p in ipairs(data.players or {}) do
            local row = vgui.Create("DPanel", playersScroll)
            row:Dock(TOP)
            row:SetTall(40)
            row:DockMargin(0, 0, 0, 2)
            row.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, CUI.panel)
            end
            
            local nameLabel = vgui.Create("DLabel", row)
            nameLabel:SetPos(10, 5)
            nameLabel:SetSize(300, 30)
            nameLabel:SetFont("GRMFeco_Normal")
            nameLabel:SetTextColor(CUI.text)
            nameLabel:SetText(p.name .. " (" .. p.sid64 .. ")")
            
            local balanceLabel = vgui.Create("DLabel", row)
            balanceLabel:SetPos(320, 5)
            balanceLabel:SetSize(200, 30)
            balanceLabel:SetFont("GRMFeco_Normal")
            balanceLabel:SetTextColor(CUI.green)
            balanceLabel:SetText("Баланс: " .. (GRM.Format and GRM.Format(p.balance or 0) or (p.balance or 0) .. " GRM"))
            
            local btnSet = vgui.Create("DButton", row)
            btnSet:SetPos(600, 5)
            btnSet:SetSize(120, 30)
            btnSet:SetText("Установить")
            btnSet:SetFont("GRMFeco_Small")
            btnSet.DoClick = function()
                Derma_StringRequest("Баланс игрока " .. p.name, "Сумма:", tostring(p.balance or 0), function(val)
                    local amount = math.floor(tonumber(val) or 0)
                    if amount >= 0 then
                        net.Start("GRM_FecoAdmin_Action")
                            net.WriteString("player_balance")
                            net.WriteString(p.sid64)
                            net.WriteUInt(amount, 32)
                            net.WriteFloat(0)
                        net.SendToServer()
                        frame:Close()
                        openFecoAdmin()
                    end
                end)
            end
        end
        
        tabs:AddSheet("Игроки", playersPanel, "icon16/user.png")
    end)
    
    -- Хук для добавления вкладки в /factions
    hook.Add("GRM_FactionsAdmin_BuildTabs", "GRM_FecoAdmin_Tab", function(tabs)
        if not IsValid(tabs) then return end
        if not LocalPlayer():IsSuperAdmin() then return end
        
        local panel = vgui.Create("DPanel")
        panel:SetPaintBackground(false)
        panel:DockPadding(10, 10, 10, 10)
        
        local info = vgui.Create("DLabel", panel)
        info:Dock(TOP)
        info:SetTall(60)
        info:SetFont("GRMFeco_Normal")
        info:SetTextColor(CUI.text)
        info:SetText("Управление экономикой сервера:\n• Гос.бюджет (пополнение/снятие)\n• Бюджеты фракций\n• Налоги\n• Балансы игроков")
        info:SetWrap(true)
        info:DockMargin(0, 0, 0, 10)
        
        local btnOpen = vgui.Create("DButton", panel)
        btnOpen:Dock(TOP)
        btnOpen:SetTall(40)
        btnOpen:SetText("Открыть панель экономики")
        btnOpen:SetFont("GRMFeco_Title")
        btnOpen:DockMargin(0, 0, 0, 5)
        btnOpen.DoClick = function()
            openFecoAdmin()
        end
        
        local btnMenu = vgui.Create("DButton", panel)
        btnMenu:Dock(TOP)
        btnMenu:SetTall(30)
        btnMenu:SetText("Открыть старое меню (!grmmenu)")
        btnMenu:SetFont("GRMFeco_Normal")
        btnMenu:DockMargin(0, 0, 0, 5)
        btnMenu.DoClick = function()
            RunConsoleCommand("say", "!grmmenu")
        end
        
        tabs:AddSheet("Экономика", panel, "icon16/money_dollar.png")
    end)
    
    -- Консольная команда
    concommand.Add("grm_feco", function()
        if LocalPlayer():IsSuperAdmin() then
            openFecoAdmin()
        else
            notification.AddLegacy("Только суперадмин", NOTIFY_ERROR, 3)
        end
    end)
end

print("[GRM Feco Admin] Модуль загружен (Код 113)")
