--[[--------------------------------------------------------------------
    GRM Factions Unified UI v2.0.0 (Код 112 / Structure v5.0)
    Единый интерактивный интерфейс управления фракциями и кадрами:
      • Полноценный Singleton VGUI в едином темном XUI стиле;
      • Левая навигационная панель (Обзор, Сотрудники, Структура и штат, Кадровые дела);
      • Полный набор интерактивных кнопок и модальных окон управления:
          - Приглашение сотрудников с выбором роли, отдела и подотдела;
          - Изменение должностей, перевод в отделы и подотделы, увольнение;
          - Создание, переименование, удаление и перемещение должностей (Roles);
          - Создание, переименование, удаление отделов (Departments);
          - Создание, редактирование, квоты, теги и удаление подотделов (Subdepartments);
          - Управление кадровыми делами, взысканиями, благодарностями, архивом;
          - Селектор организаций для администратора и создание новых фракций;
      • Полная поддержка двойных имён (DisplayName + SystemKey).
----------------------------------------------------------------------]]

if not CLIENT then return end

GRM = GRM or {}
GRM.Factions = GRM.Factions or {}
GRM.Factions.UnifiedUI = GRM.Factions.UnifiedUI or {}
local UI = GRM.Factions.UnifiedUI
UI.Version = "2.0.0"

surface.CreateFont("GRMFac_Title",   { font = "Roboto", size = 20, weight = 800, extended = true })
surface.CreateFont("GRMFac_Sub",     { font = "Roboto", size = 15, weight = 700, extended = true })
surface.CreateFont("GRMFac_Normal",  { font = "Roboto", size = 13, weight = 500, extended = true })
surface.CreateFont("GRMFac_Small",   { font = "Roboto", size = 11, weight = 400, extended = true })
surface.CreateFont("GRMFac_Btn",     { font = "Roboto", size = 13, weight = 600, extended = true })

local C = {
    bg         = Color(18, 22, 30, 252),
    sidebar    = Color(14, 17, 24, 255),
    card       = Color(25, 31, 42, 240),
    cardHover  = Color(33, 41, 56, 240),
    cardDark   = Color(20, 25, 34, 240),
    border     = Color(42, 52, 70, 200),
    accent     = Color(70, 150, 240),
    accentDark = Color(45, 110, 190),
    accentHover= Color(95, 170, 255),
    gold       = Color(245, 200, 70),
    green      = Color(60, 190, 115),
    greenHover = Color(75, 215, 130),
    teal       = Color(80, 200, 175),
    red        = Color(230, 75, 75),
    redHover   = Color(250, 95, 95),
    text       = Color(240, 245, 250),
    dim        = Color(160, 175, 195),
}

local currentFrame = nil

local function sendAction(action, args, cb)
    net.Start("Factions_AdminAction")
        net.WriteString(action)
        net.WriteTable(args or {})
    net.SendToServer()
    if cb then timer.Simple(0.3, cb) end
end

local function mkBtn(parent, text, col, hoverCol, doClick)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b:SetFont("GRMFac_Btn")
    b.Paint = function(s, w, h)
        local isHov = s:IsHovered()
        local isDis = not s:IsEnabled()
        local bgCol = isDis and Color(40, 46, 60) or (isHov and (hoverCol or C.accentHover) or (col or C.accent))
        draw.RoundedBox(6, 0, 0, w, h, bgCol)
        surface.SetDrawColor(255, 255, 255, isDis and 10 or 30)
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText(text, "GRMFac_Btn", w / 2, h / 2, isDis and C.dim or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        if doClick then doClick() end
    end
    return b
end

local function promptInput(title, defaultVal, cb)
    local modal = vgui.Create("DFrame")
    modal:SetTitle("")
    modal:SetSize(360, 150)
    modal:Center()
    modal:MakePopup()
    modal:ShowCloseButton(false)
    modal.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, C.bg)
        draw.RoundedBox(8, 0, 0, w, 36, C.sidebar)
        surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText(title, "GRMFac_Sub", 14, 18, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local te = vgui.Create("DTextEntry", modal)
    te:SetPos(16, 52)
    te:SetSize(328, 30)
    te:SetFont("GRMFac_Normal")
    te:SetText(tostring(defaultVal or ""))
    te:RequestFocus()

    local btnCancel = mkBtn(modal, "Отмена", C.card, C.cardHover, function() modal:Close() end)
    btnCancel:SetPos(16, 98) btnCancel:SetSize(155, 34)

    local btnOk = mkBtn(modal, "Подтвердить", C.accent, C.accentHover, function()
        local val = string.Trim(te:GetText())
        if val ~= "" and cb then cb(val) end
        modal:Close()
    end)
    btnOk:SetPos(189, 98) btnOk:SetSize(155, 34)
    te.OnEnter = function() btnOk:DoClick() end
end

local function getLeaderFactionName(data)
    local lp = LocalPlayer()
    if not IsValid(lp) then return nil end
    local charKey = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(lp)) or ""
    local sid = lp:SteamID()
    local sid64 = lp:SteamID64()
    for name, f in pairs(data or {}) do
        if istable(f) then
            local ldr = tostring(f.Leader or "")
            if ldr ~= "" and (ldr == charKey or ldr == sid or ldr == sid64) then return name, f end
            if istable(f.Members) then
                local m = f.Members[charKey] or f.Members[sid] or f.Members[sid64]
                if istable(m) and (m.Role == f.LeaderRoleName or m.Role == "Лидер") then return name, f end
            end
        end
    end
    return nil
end

local function getPlayerFactionName(data)
    local lp = LocalPlayer()
    if not IsValid(lp) then return nil end
    local charKey = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(lp)) or ""
    local sid = lp:SteamID()
    local sid64 = lp:SteamID64()
    for name, f in pairs(data or {}) do
        if istable(f) and istable(f.Members) then
            if f.Members[charKey] or f.Members[sid] or f.Members[sid64] then return name, f end
        end
    end
    return nil
end

function UI.Open(requestedFaction)
    if IsValid(currentFrame) then
        currentFrame:Remove()
        currentFrame = nil
    end

    local data = FactionsData or {}
    local lp = LocalPlayer()
    local isSA = IsValid(lp) and lp.IsSuperAdmin and lp:IsSuperAdmin()

    local targetFac = requestedFaction or getLeaderFactionName(data) or getPlayerFactionName(data)
    if not targetFac and not isSA then
        if GRM.Notify then
            GRM.Notify(lp, "Вы не состоите ни в одной государственной или частной организации.", 255, 160, 80)
        else
            chat.AddText(Color(255, 160, 80), "[Фракции] Вы не состоите ни в одной организации.")
        end
        return
    end

    if not targetFac and isSA then
        targetFac = next(data)
    end

    local f = vgui.Create("DFrame")
    currentFrame = f
    if GRM.UI and GRM.UI.Track then GRM.UI.Track("grm_factions_unified", f) end

    f:SetSize(math.Clamp(ScrW() * 0.88, 1020, 1440), math.Clamp(ScrH() * 0.86, 680, 960))
    f:Center()
    f:SetTitle("")
    f:SetDraggable(true)
    f:SetSizable(true)
    f:ShowCloseButton(false)
    f:MakePopup()

    f.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, C.bg)
        draw.RoundedBox(8, 0, 0, w, 44, C.sidebar)
        surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
        surface.DrawOutlinedRect(0, 0, w, h)

        local dispName = targetFac and GRM.Factions.DisplayName(targetFac) or "Панель организаций"
        draw.SimpleText("★ " .. dispName, "GRMFac_Title", 16, 22, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        if targetFac and targetFac ~= dispName then
            draw.SimpleText("[" .. targetFac .. "]", "GRMFac_Small", 24 + surface.GetTextSize("★ " .. dispName) + 12, 22, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    -- Селектор фракций для SuperAdmin в шапке
    if isSA and table.Count(data) > 0 then
        local comboFac = vgui.Create("DComboBox", f)
        comboFac:SetPos(f:GetWide() - 400, 8)
        comboFac:SetSize(240, 28)
        comboFac:SetFont("GRMFac_Normal")
        for fname, _ in pairs(data) do
            local disp = GRM.Factions.DisplayName(fname)
            comboFac:AddChoice(disp .. " [" .. fname .. "]", fname, fname == targetFac)
        end
        comboFac.OnSelect = function(_, _, _, val)
            if val and val ~= targetFac then
                f:Remove()
                UI.Open(val)
            end
        end
    end

    local btnClose = vgui.Create("DButton", f)
    btnClose:SetSize(32, 28)
    btnClose:SetPos(f:GetWide() - 42, 8)
    btnClose:SetText("✕")
    btnClose:SetFont("GRMFac_Btn")
    btnClose:SetTextColor(C.dim)
    btnClose.Paint = function(self, w, h)
        if self:IsHovered() then draw.RoundedBox(4, 0, 0, w, h, C.red) end
    end
    btnClose.DoClick = function() f:Remove() end

    local body = vgui.Create("DPanel", f)
    body:Dock(FILL)
    body:DockMargin(0, 44, 0, 0)
    body:SetPaintBackground(false)

    local sidebar = vgui.Create("DPanel", body)
    sidebar:Dock(LEFT)
    sidebar:SetWide(210)
    sidebar.Paint = function(self, w, h)
        draw.RoundedBoxEx(0, 0, 0, w, h, C.sidebar, false, false, true, false)
        surface.SetDrawColor(C.border.r, C.border.g, C.border.b, 80)
        surface.DrawLine(w - 1, 0, w - 1, h)
    end

    local content = vgui.Create("DPanel", body)
    content:Dock(FILL)
    content:DockMargin(12, 10, 12, 10)
    content:SetPaintBackground(false)

    local activeTab = nil
    local tabButtons = {}

    local function refreshView()
        if activeTab and tabButtons[activeTab] and tabButtons[activeTab].builder then
            content:Clear()
            tabButtons[activeTab].builder(content, targetFac, FactionsData or {})
        end
    end

    local function selectTab(tabKey, builderFn)
        activeTab = tabKey
        for k, btn in pairs(tabButtons) do
            btn.isActive = (k == tabKey)
        end
        content:Clear()
        if builderFn then builderFn(content, targetFac, FactionsData or {}) end
    end

    local function addTabBtn(tabKey, label, icon, builderFn)
        local btn = vgui.Create("DButton", sidebar)
        btn:Dock(TOP)
        btn:SetTall(38)
        btn:DockMargin(6, 4, 6, 0)
        btn:SetText("")
        btn.isActive = false
        btn.builder = builderFn

        btn.Paint = function(self, w, h)
            local isHov = self:IsHovered()
            local isAct = self.isActive
            if isAct then
                draw.RoundedBox(6, 0, 0, w, h, C.accent)
            elseif isHov then
                draw.RoundedBox(6, 0, 0, w, h, C.cardHover)
            end
            local col = isAct and color_white or (isHov and C.text or C.dim)
            draw.SimpleText(label, "GRMFac_Btn", 16, h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        btn.DoClick = function() selectTab(tabKey, builderFn) end
        tabButtons[tabKey] = btn
    end

    -- ════════════ ВКЛАДКА 1: ОБЗОР ════════════
    local function buildOverviewTab(pnl, facName, facData)
        local fac = facData and facData[facName] or {}
        local dispName = GRM.Factions.DisplayName(facName)
        local ldrKey = tostring(fac.Leader or "Не назначен")
        local memCount = fac.Members and table.Count(fac.Members) or 0
        local deptCount = fac.Departments and #fac.Departments or 0
        local subCount = fac.Subdepartments and table.Count(fac.Subdepartments) or 0
        local roleCount = fac.Roles and #fac.Roles or 0
        local budget = fac.Budget or 0

        local grid = vgui.Create("DGrid", pnl)
        grid:Dock(TOP)
        grid:SetTall(110)
        grid:SetCols(4)
        grid:SetColWide((pnl:GetWide() - 40) / 4)
        grid:SetRowHeight(105)

        local function addStatCard(title, val, color)
            local card = vgui.Create("DPanel")
            card:SetSize((pnl:GetWide() - 48) / 4, 95)
            card.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, C.card)
                surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
                surface.DrawOutlinedRect(0, 0, w, h)
                draw.SimpleText(title, "GRMFac_Small", 14, 14, C.dim, TEXT_ALIGN_LEFT)
                draw.SimpleText(tostring(val), "GRMFac_Title", 14, 42, color or C.text, TEXT_ALIGN_LEFT)
            end
            grid:AddItem(card)
        end

        addStatCard("СОТРУДНИКОВ", memCount, C.accent)
        addStatCard("ОТДЕЛОВ / ПОДОТДЕЛОВ", tostring(deptCount) .. " / " .. tostring(subCount), C.green)
        addStatCard("ДОЛЖНОСТЕЙ", roleCount, C.gold)
        addStatCard("КАЗНА / БЮДЖЕТ", tostring(budget) .. " руб.", C.gold)

        local infoPanel = vgui.Create("DPanel", pnl)
        infoPanel:Dock(FILL)
        infoPanel:DockMargin(0, 14, 0, 0)
        infoPanel.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
            surface.DrawOutlinedRect(0, 0, w, h)
            draw.SimpleText("Информация об организации", "GRMFac_Sub", 16, 18, C.text)
            draw.SimpleText("Публичное название: " .. dispName, "GRMFac_Normal", 16, 48, C.text)
            draw.SimpleText("Системный идентификатор: " .. facName, "GRMFac_Normal", 16, 72, C.dim)
            draw.SimpleText("Руководитель: " .. ldrKey, "GRMFac_Normal", 16, 96, C.dim)
            draw.SimpleText("Тэг волны: " .. (fac.Tag and fac.Tag ~= "" and fac.Tag or "—"), "GRMFac_Normal", 16, 120, C.dim)
        end

        -- Кнопки действий на Обзоре
        local bBar = vgui.Create("DPanel", infoPanel)
        bBar:Dock(BOTTOM)
        bBar:SetTall(42)
        bBar:DockMargin(12, 0, 12, 12)
        bBar:SetPaintBackground(false)

        mkBtn(bBar, "✎ Изменить публичное название", C.accent, C.accentHover, function()
            promptInput("Новое публичное название", dispName, function(val)
                sendAction("setDisplayName", { facName, val }, refreshView)
            end)
        end):Dock(LEFT); bBar:GetChildren()[1]:SetWide(230)

        mkBtn(bBar, "🏷 Тэг волны", C.cardDark, C.cardHover, function()
            promptInput("Тэг волны фракции", fac.Tag or "", function(val)
                sendAction("setTag", { facName, val }, refreshView)
            end)
        end):Dock(LEFT); bBar:GetChildren()[2]:DockMargin(8, 0, 0, 0); bBar:GetChildren()[2]:SetWide(140)

        if isSA then
            mkBtn(bBar, "🗑 Удалить фракцию", C.red, C.redHover, function()
                Derma_Query("Удалить фракцию «" .. dispName .. "»?", "Подтверждение", "Удалить", function()
                    sendAction("deleteFaction", { facName }, function()
                        f:Remove()
                        UI.Open()
                    end)
                end, "Отмена")
            end):Dock(RIGHT); bBar:GetChildren()[3]:SetWide(160)
        end
    end

    -- ════════════ ВКЛАДКА 2: СОТРУДНИКИ ════════════
    local function buildMembersTab(pnl, facName, facData)
        local fac = facData and facData[facName] or {}
        local selectedMemberKey = nil

        local list = vgui.Create("DListView", pnl)
        list:Dock(FILL)
        list:SetMultiSelect(false)
        list:AddColumn("Имя / Идентификатор"):SetFixedWidth(240)
        list:AddColumn("Должность"):SetFixedWidth(180)
        list:AddColumn("Отдел / Подотдел"):SetFixedWidth(260)
        list:AddColumn("Статус службы"):SetFixedWidth(120)

        for key, rec in pairs(fac.Members or {}) do
            local roleDisplay = GRM.Factions.RoleDisplayName(fac, rec.Role)
            local deptDisplay = GRM.Factions.DepartmentDisplayName(fac, rec.Department)
            local subDisplay = GRM.Factions.SubdepartmentDisplayName(fac, rec.Subdepartment)
            local branchText = deptDisplay
            if subDisplay ~= "" and subDisplay ~= deptDisplay then
                branchText = deptDisplay .. " [" .. subDisplay .. "]"
            end
            local onDuty = GRM.FactionDuty and GRM.FactionDuty.State and GRM.FactionDuty.State[key]
            local dutyText = onDuty and "НА СЛУЖБЕ" or "ВНЕ СЛУЖБЫ"
            local rp = rec._rpName or tostring(key)
            local ln = list:AddLine(rp, roleDisplay, branchText, dutyText)
            ln.memberKey = key
        end

        local bBar = vgui.Create("DPanel", pnl)
        bBar:Dock(BOTTOM)
        bBar:SetTall(42)
        bBar:DockMargin(0, 8, 0, 0)
        bBar:SetPaintBackground(false)

        local btnInvite = mkBtn(bBar, "➕ Пригласить сотрудника", C.green, C.greenHover, function()
            local invModal = vgui.Create("DFrame")
            invModal:SetTitle("")
            invModal:SetSize(420, 260)
            invModal:Center()
            invModal:MakePopup()
            invModal.Paint = function(_, w, h)
                draw.RoundedBox(8, 0, 0, w, h, C.bg)
                draw.RoundedBox(8, 0, 0, w, 36, C.sidebar)
                surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
                surface.DrawOutlinedRect(0, 0, w, h)
                draw.SimpleText("Приглашение во фракцию", "GRMFac_Sub", 14, 18, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            local comboPly = vgui.Create("DComboBox", invModal)
            comboPly:SetPos(16, 50); comboPly:SetSize(388, 28); comboPly:SetFont("GRMFac_Normal")
            comboPly:AddChoice("— Выберите игрока онлайн —", "")
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p ~= LocalPlayer() then
                    local n = p:GetNWString("GRM_RPName", "")
                    comboPly:AddChoice(string.format("%s [%s]", n ~= "" and n or p:Nick(), p:Nick()), p:SteamID())
                end
            end

            local comboRole = vgui.Create("DComboBox", invModal)
            comboRole:SetPos(16, 88); comboRole:SetSize(388, 28); comboRole:SetFont("GRMFac_Normal")
            for _, rKey in ipairs(fac.Roles or {}) do
                comboRole:AddChoice(GRM.Factions.RoleDisplayName(fac, rKey) .. " [" .. rKey .. "]", rKey)
            end

            local comboDept = vgui.Create("DComboBox", invModal)
            comboDept:SetPos(16, 126); comboDept:SetSize(388, 28); comboDept:SetFont("GRMFac_Normal")
            for _, dKey in ipairs(fac.Departments or {}) do
                comboDept:AddChoice(GRM.Factions.DepartmentDisplayName(fac, dKey) .. " [" .. dKey .. "]", dKey)
            end

            local btnSend = mkBtn(invModal, "Отправить приглашение (5 мин)", C.accent, C.accentHover, function()
                local _, targetSid = comboPly:GetSelected()
                local _, roleKey = comboRole:GetSelected()
                local _, deptKey = comboDept:GetSelected()
                if not targetSid or targetSid == "" then notification.AddLegacy("Выберите игрока!", NOTIFY_ERROR, 3) return end
                sendAction("inviteMember", { isSA and facName or targetSid, isSA and targetSid or roleKey, isSA and roleKey or deptKey, isSA and deptKey or nil }, refreshView)
                invModal:Close()
                notification.AddLegacy("Приглашение отправлено", NOTIFY_GENERIC, 3)
            end)
            btnSend:SetPos(16, 180); btnSend:SetSize(388, 36)
        end)
        btnInvite:Dock(LEFT); btnInvite:SetWide(200)

        local btnRole = mkBtn(bBar, "✎ Должность", C.cardDark, C.cardHover, function()
            local l = list:GetSelectedLine()
            if not l then notification.AddLegacy("Выберите сотрудника в списке!", NOTIFY_ERROR, 3) return end
            local memKey = list:GetLine(l).memberKey
            local rMenu = DermaMenu()
            for _, rKey in ipairs(fac.Roles or {}) do
                local rDisp = GRM.Factions.RoleDisplayName(fac, rKey)
                rMenu:AddOption(rDisp .. " [" .. rKey .. "]", function()
                    sendAction("setRole", { isSA and facName or memKey, isSA and memKey or rKey, isSA and rKey or nil }, refreshView)
                end)
            end
            rMenu:Open()
        end)
        btnRole:Dock(LEFT); btnRole:DockMargin(8, 0, 0, 0); btnRole:SetWide(130)

        local btnDept = mkBtn(bBar, "🏢 Отдел / Подотдел", C.cardDark, C.cardHover, function()
            local l = list:GetSelectedLine()
            if not l then notification.AddLegacy("Выберите сотрудника в списке!", NOTIFY_ERROR, 3) return end
            local memKey = list:GetLine(l).memberKey
            local dMenu = DermaMenu()
            for _, dKey in ipairs(fac.Departments or {}) do
                local dDisp = GRM.Factions.DepartmentDisplayName(fac, dKey)
                local subMenu, subMenuBtn = dMenu:AddSubMenu(dDisp)
                subMenu:AddOption("Прямой член отдела (без подотдела)", function()
                    sendAction("setDepartment", { isSA and facName or memKey, isSA and memKey or dKey, isSA and dKey or nil }, function()
                        sendAction("setSubdepartment", { isSA and facName or memKey, isSA and memKey or "", isSA and "" or nil }, refreshView)
                    end)
                end)
                for _, sub in ipairs(GRM.Factions.GetSubdepartments(fac, dKey)) do
                    subMenu:AddOption("🔹 " .. sub.name .. " [" .. sub.id .. "]", function()
                        sendAction("setSubdepartment", { isSA and facName or memKey, isSA and memKey or sub.id, isSA and sub.id or nil }, refreshView)
                    end)
                end
            end
            dMenu:Open()
        end)
        btnDept:Dock(LEFT); btnDept:DockMargin(8, 0, 0, 0); btnDept:SetWide(170)

        local btnKick = mkBtn(bBar, "✕ Уволить", C.red, C.redHover, function()
            local l = list:GetSelectedLine()
            if not l then notification.AddLegacy("Выберите сотрудника в списке!", NOTIFY_ERROR, 3) return end
            local memKey = list:GetLine(l).memberKey
            Derma_Query("Уволить сотрудника " .. memKey .. " из организации?", "Подтверждение", "Уволить", function()
                sendAction("removeMember", { isSA and facName or memKey, isSA and memKey or nil }, refreshView)
            end, "Отмена")
        end)
        btnKick:Dock(RIGHT); btnKick:SetWide(120)
    end

    -- ════════════ ВКЛАДКА 3: СТРУКТУРА И ШТАТ ════════════
    local function buildStructureTab(pnl, facName, facData)
        local fac = facData and facData[facName] or {}

        local split = vgui.Create("DPanel", pnl)
        split:Dock(FILL)
        split:SetPaintBackground(false)

        -- Левая колонка: ДОЛЖНОСТИ (ROLES)
        local left = vgui.Create("DPanel", split)
        left:Dock(LEFT)
        left:SetWide((pnl:GetWide() - 40) * 0.42)
        left.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            draw.SimpleText("Должности (Roles)", "GRMFac_Sub", 14, 14, C.gold)
        end

        local rList = vgui.Create("DListView", left)
        rList:Dock(FILL)
        rList:DockMargin(10, 40, 10, 50)
        rList:AddColumn("Ключ"):SetFixedWidth(110)
        rList:AddColumn("Публичное название (RU)")

        for _, rKey in ipairs(fac.Roles or {}) do
            local rDisp = GRM.Factions.RoleDisplayName(fac, rKey)
            local line = rList:AddLine(rKey, rDisp)
            line.roleKey = rKey
        end

        local rBar = vgui.Create("DPanel", left)
        rBar:Dock(BOTTOM)
        rBar:SetTall(36)
        rBar:DockMargin(10, 0, 10, 10)
        rBar:SetPaintBackground(false)

        mkBtn(rBar, "➕ Добавить", C.accent, C.accentHover, function()
            promptInput("Системный ключ новой должности (eng)", "officer", function(kVal)
                promptInput("Публичное название должности (RU)", "Офицер", function(dVal)
                    sendAction("addRole", { isSA and facName or kVal, isSA and kVal or nil }, function()
                        sendAction("renameRole", { isSA and facName or kVal, isSA and kVal or dVal, isSA and dVal or nil }, refreshView)
                    end)
                end)
            end)
        end):Dock(LEFT); rBar:GetChildren()[1]:SetWide(110)

        mkBtn(rBar, "✎ Переименовать", C.cardDark, C.cardHover, function()
            local l = rList:GetSelectedLine()
            if not l then notification.AddLegacy("Выберите должность в списке!", NOTIFY_ERROR, 3) return end
            local rKey = rList:GetLine(l).roleKey
            local curDisp = GRM.Factions.RoleDisplayName(fac, rKey)
            promptInput("Новое публичное название должности", curDisp, function(val)
                sendAction("renameRole", { isSA and facName or rKey, isSA and rKey or val, isSA and val or nil }, refreshView)
            end)
        end):Dock(LEFT); rBar:GetChildren()[2]:DockMargin(6, 0, 0, 0); rBar:GetChildren()[2]:SetWide(130)

        mkBtn(rBar, "✕", C.red, C.redHover, function()
            local l = rList:GetSelectedLine()
            if not l then return end
            local rKey = rList:GetLine(l).roleKey
            sendAction("removeRole", { isSA and facName or rKey, isSA and rKey or nil }, refreshView)
        end):Dock(RIGHT); rBar:GetChildren()[3]:SetWide(36)

        -- Правая колонка: ОТДЕЛЫ И ПОДОТДЕЛЫ (DEPARTMENTS & SUBDEPARTMENTS)
        local right = vgui.Create("DPanel", split)
        right:Dock(RIGHT)
        right:SetWide((pnl:GetWide() - 40) * 0.56)
        right.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            draw.SimpleText("Иерархия отделов и подотделов", "GRMFac_Sub", 14, 14, C.green)
        end

        local deptScroll = vgui.Create("DScrollPanel", right)
        deptScroll:Dock(FILL)
        deptScroll:DockMargin(10, 40, 10, 50)

        for _, dKey in ipairs(fac.Departments or {}) do
            local dDisp = GRM.Factions.DepartmentDisplayName(fac, dKey)
            local subList = GRM.Factions.GetSubdepartments(fac, dKey)

            local dCard = vgui.Create("DPanel", deptScroll)
            dCard:Dock(TOP)
            dCard:DockMargin(0, 0, 0, 8)
            dCard:SetTall(42 + #subList * 34)
            dCard.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, Color(30, 38, 52, 220))
                surface.SetDrawColor(C.border.r, C.border.g, C.border.b, 80)
                surface.DrawOutlinedRect(0, 0, w, h)
                draw.SimpleText("🏛 " .. dDisp, "GRMFac_Sub", 12, 14, C.text)
                draw.SimpleText("[" .. dKey .. "]", "GRMFac_Small", 14 + surface.GetTextSize("🏛 " .. dDisp) + 12, 16, C.dim)
            end

            -- Кнопки на шапке отдела: [+ Подотдел], [✎ Имя], [✕ Удалить]
            local dBtnAddSub = mkBtn(dCard, "+ Подотдел", C.teal, C.accentHover, function()
                promptInput("Ключ подотдела (eng)", "sub_1", function(subKey)
                    promptInput("Название подотдела (RU)", "1-й Взвод", function(subName)
                        promptInput("Тактический тег в рацию (например [ППС-1])", "[ППС-1]", function(subTag)
                            sendAction("addSubdepartment", { isSA and facName or dKey, isSA and dKey or subKey, isSA and subKey or subName, isSA and subName or subTag, isSA and subTag or 0, isSA and 0 or nil }, refreshView)
                        end)
                    end)
                end)
            end); dBtnAddSub:SetSize(90, 24); dBtnAddSub:SetPos(dCard:GetWide() - 170, 8)

            local dBtnRename = mkBtn(dCard, "✎", C.cardDark, C.cardHover, function()
                promptInput("Новое название отдела", dDisp, function(val)
                    sendAction("renameDepartment", { isSA and facName or dKey, isSA and dKey or val, isSA and val or nil }, refreshView)
                end)
            end); dBtnRename:SetSize(28, 24); dBtnRename:SetPos(dCard:GetWide() - 74, 8)

            local dBtnDel = mkBtn(dCard, "✕", C.red, C.redHover, function()
                Derma_Query("Удалить отдел «" .. dDisp .. "»?", "Подтверждение", "Удалить", function()
                    sendAction("removeDepartment", { isSA and facName or dKey, isSA and dKey or nil }, refreshView)
                end, "Отмена")
            end); dBtnDel:SetSize(28, 24); dBtnDel:SetPos(dCard:GetWide() - 40, 8)

            local subContainer = vgui.Create("DPanel", dCard)
            subContainer:Dock(FILL)
            subContainer:DockMargin(16, 38, 8, 4)
            subContainer:SetPaintBackground(false)

            for _, sub in ipairs(subList) do
                local subRow = vgui.Create("DPanel", subContainer)
                subRow:Dock(TOP)
                subRow:SetTall(30)
                subRow:DockMargin(0, 2, 0, 0)
                subRow.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, Color(22, 28, 38, 200))
                    local tag = sub.tag ~= "" and (" " .. sub.tag) or ""
                    draw.SimpleText("🔹 " .. sub.name .. tag, "GRMFac_Normal", 10, h / 2, C.teal, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    local quotaText = sub.quota > 0 and ("лимит: " .. tostring(sub.quota)) or "без лимита"
                    draw.SimpleText("[" .. sub.id .. " • " .. quotaText .. "]", "GRMFac_Small", w - 70, h / 2, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end

                local sBtnRename = mkBtn(subRow, "✎", C.cardDark, C.cardHover, function()
                    promptInput("Новое название подотдела", sub.name, function(val)
                        sendAction("renameSubdepartment", { isSA and facName or sub.id, isSA and sub.id or val, isSA and val or nil }, refreshView)
                    end)
                end); sBtnRename:SetSize(24, 22); sBtnRename:SetPos(subRow:GetWide() - 60, 4)

                local sBtnDel = mkBtn(subRow, "✕", C.red, C.redHover, function()
                    Derma_Query("Удалить подотдел «" .. sub.name .. "»?", "Подтверждение", "Удалить", function()
                        sendAction("removeSubdepartment", { isSA and facName or sub.id, isSA and sub.id or nil }, refreshView)
                    end, "Отмена")
                end); sBtnDel:SetSize(24, 22); sBtnDel:SetPos(subRow:GetWide() - 32, 4)
            end
        end

        local dBar = vgui.Create("DPanel", right)
        dBar:Dock(BOTTOM)
        dBar:SetTall(36)
        dBar:DockMargin(10, 0, 10, 10)
        dBar:SetPaintBackground(false)

        mkBtn(dBar, "➕ Создать отдел", C.green, C.greenHover, function()
            promptInput("Системный ключ отдела (eng)", "patrol", function(kVal)
                promptInput("Публичное название отдела (RU)", "Патрульная служба", function(dVal)
                    sendAction("addDepartment", { isSA and facName or kVal, isSA and kVal or nil }, function()
                        sendAction("renameDepartment", { isSA and facName or kVal, isSA and kVal or dVal, isSA and dVal or nil }, refreshView)
                    end)
                end)
            end)
        end):Dock(LEFT); dBar:GetChildren()[1]:SetWide(180)
    end

    -- ════════════ ВКЛАДКА 4: КАДРОВЫЕ ДЕЛА ════════════
    local function buildPersonnelTab(pnl, facName, facData)
        if GRM.FactionPersonnel and GRM.FactionPersonnel.OpenTab then
            GRM.FactionPersonnel.OpenTab(pnl, facName)
        else
            local lbl = vgui.Create("DLabel", pnl)
            lbl:Dock(TOP)
            lbl:SetText("Кадровый модуль GRM.FactionPersonnel активен.")
            lbl:SetFont("GRMFac_Normal")
            lbl:SetTextColor(C.dim)
        end
    end

    addTabBtn("overview", "Обзор", "icon16/application_home.png", buildOverviewTab)
    addTabBtn("members", "Сотрудники", "icon16/group.png", buildMembersTab)
    addTabBtn("structure", "Структура и штат", "icon16/chart_organisation.png", buildStructureTab)
    addTabBtn("personnel", "Кадровые дела", "icon16/book.png", buildPersonnelTab)

    selectTab("overview", buildOverviewTab)
end

function OpenUnifiedFactionsMenu(fname)
    UI.Open(fname)
end

concommand.Add("grm_factions_menu", function() UI.Open() end)
concommand.Add("grm_faction", function() UI.Open() end)

hook.Add("PlayerSayTransform", "GRM_FactionUnified_ChatCommand", function(ply, datapack)
    if not istable(datapack) then return end
    local text = datapack[1]
    if not isstring(text) then return end
    local lower = string.lower(string.Trim(text))
    if lower == "/fmenu" or lower == "/фракция" or lower == "/состав" or lower == "/factions" then
        if CLIENT then UI.Open() end
    end
end)

print("[GRM Factions Unified UI] v" .. UI.Version .. " loaded with full interactive controls")
