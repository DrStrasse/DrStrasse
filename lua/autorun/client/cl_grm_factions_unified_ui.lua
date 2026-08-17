--[[--------------------------------------------------------------------
    GRM Factions Unified UI v3.0.0 (Код 112 / Structure v5.0)
    Единый полнофункциональный центр управления организациями:
      • Широкий адаптивный Singleton XUI (без сломанных emoji);
      • Левая навигация со всеми 10 разделами:
          1. «Обзор» — сводка, параметры, лидер, цвет, тэг, удаление;
          2. «Сотрудники» — интерактивный состав, поиск, приглашение v2,
             смена должности, перевод в отдел/подотдел, увольнение;
          3. «Структура» — должности (ключи/display), дерево отделов и подотделов
             с квотами, тегами и полным управлением;
          4. «Кадровые дела» — личные досье, журнал, взыскания, благодарности,
             испытательный срок, архив уволенных;
          5. «Доступы и связь» — волна департамента, госновости, доска,
             эфир, оповещения, биржа, госуслуги, счета, дипломы;
          6. «Вооружение и форма» — арсенал и гардероб по ролям/отделам;
          7. «Маскировка» — маскировка по отделам, легенды прикрытия;
          8. «Комендантский час» — запуск, отмена, роли с допуском, таймер;
          9. «Казна и финансы» — бюджет, налоги, инкассация;
          10. «Создать организацию» — создание новой фракции v2;
      • Полная поддержка двойных имён (DisplayName + SystemKey).
----------------------------------------------------------------------]]

if not CLIENT then return end

GRM = GRM or {}
GRM.Factions = GRM.Factions or {}
GRM.Factions.UnifiedUI = GRM.Factions.UnifiedUI or {}
local UI = GRM.Factions.UnifiedUI
UI.Version = "3.0.0"

surface.CreateFont("GRMFac_Title",   { font = "Roboto", size = 20, weight = 800, extended = true })
surface.CreateFont("GRMFac_Sub",     { font = "Roboto", size = 15, weight = 700, extended = true })
surface.CreateFont("GRMFac_Normal",  { font = "Roboto", size = 13, weight = 500, extended = true })
surface.CreateFont("GRMFac_Small",   { font = "Roboto", size = 11, weight = 400, extended = true })
surface.CreateFont("GRMFac_Btn",     { font = "Roboto", size = 13, weight = 600, extended = true })
surface.CreateFont("GRMFac_StatVal", { font = "Roboto", size = 22, weight = 800, extended = true })

local C = {
    bg         = Color(16, 20, 28, 252),
    sidebar    = Color(12, 15, 22, 255),
    card       = Color(22, 28, 38, 240),
    cardLight  = Color(28, 36, 48, 240),
    cardHover  = Color(36, 46, 62, 240),
    border     = Color(38, 48, 66, 200),
    borderLight= Color(55, 68, 92, 200),
    accent     = Color(65, 145, 235),
    accentDark = Color(40, 100, 180),
    accentHover= Color(85, 165, 255),
    gold       = Color(245, 195, 65),
    green      = Color(55, 185, 110),
    greenHover = Color(70, 210, 125),
    teal       = Color(75, 195, 170),
    red        = Color(225, 70, 70),
    redHover   = Color(245, 90, 90),
    text       = Color(240, 244, 250),
    dim        = Color(155, 170, 190),
}

local currentFrame = nil

local function sendAction(action, args, cb)
    net.Start("Factions_AdminAction")
        net.WriteString(action)
        net.WriteTable(args or {})
    net.SendToServer()
    if cb then timer.Simple(0.25, cb) end
end

local function sendExtAction(action, args, cb)
    net.Start("FactionsExt_Action")
        net.WriteString(action)
        net.WriteTable(args or {})
    net.SendToServer()
    if cb then timer.Simple(0.25, cb) end
end

local function sendBridgeAction(kind, fname, allow, cb)
    net.Start("GRM_FAcc_Set")
        net.WriteString(kind)
        net.WriteString(fname)
        net.WriteBool(allow == true)
    net.SendToServer()
    if cb then timer.Simple(0.25, cb) end
end

local function mkBtn(parent, text, col, hoverCol, doClick)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b:SetFont("GRMFac_Btn")
    b.Paint = function(s, w, h)
        local isHov = s:IsHovered()
        local isDis = not s:IsEnabled()
        local bgCol = isDis and Color(34, 40, 52) or (isHov and (hoverCol or C.accentHover) or (col or C.accent))
        draw.RoundedBox(5, 0, 0, w, h, bgCol)
        surface.SetDrawColor(255, 255, 255, isDis and 10 or 25)
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText(text, "GRMFac_Btn", w / 2, h / 2, isDis and C.dim or color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        if doClick then doClick() end
    end
    return b
end

local function skinListView(lv)
    if not IsValid(lv) then return end
    lv:SetPaintBackground(false)
    lv.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, C.card)
        surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
    if lv.Columns then
        for _, col in ipairs(lv.Columns) do
            if col.Header then
                col.Header:SetTall(28)
                col.Header:SetFont("GRMFac_Btn")
                col.Header:SetTextColor(C.gold)
                col.Header.Paint = function(s, w, h)
                    draw.RoundedBox(0, 0, 0, w, h, Color(28, 35, 48))
                    surface.SetDrawColor(C.border.r, C.border.g, C.border.b, 80)
                    surface.DrawLine(0, h - 1, w, h - 1)
                    surface.DrawLine(w - 1, 0, w - 1, h)
                end
            end
        end
    end
end

local function promptInput(title, defaultVal, cb)
    local modal = vgui.Create("DFrame")
    modal:SetTitle("")
    modal:SetSize(380, 160)
    modal:Center()
    modal:MakePopup()
    modal:ShowCloseButton(false)
    modal.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, C.bg)
        draw.RoundedBox(8, 0, 0, w, 38, C.sidebar)
        surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText(title, "GRMFac_Sub", 16, 19, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local te = vgui.Create("DTextEntry", modal)
    te:SetPos(16, 56)
    te:SetSize(348, 32)
    te:SetFont("GRMFac_Normal")
    te:SetText(tostring(defaultVal or ""))
    te:RequestFocus()

    local btnCancel = mkBtn(modal, "Отмена", C.cardLight, C.cardHover, function() modal:Close() end)
    btnCancel:SetPos(16, 106) btnCancel:SetSize(165, 36)

    local btnOk = mkBtn(modal, "Подтвердить", C.accent, C.accentHover, function()
        local val = string.Trim(te:GetText())
        if val ~= "" and cb then cb(val) end
        modal:Close()
    end)
    btnOk:SetPos(199, 106) btnOk:SetSize(165, 36)
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

    f:SetSize(math.Clamp(ScrW() * 0.92, 1100, 1560), math.Clamp(ScrH() * 0.88, 720, 980))
    f:Center()
    f:SetTitle("")
    f:SetDraggable(true)
    f:SetSizable(true)
    f:ShowCloseButton(false)
    f:MakePopup()

    f.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, C.bg)
        draw.RoundedBox(8, 0, 0, w, 46, C.sidebar)
        surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
        surface.DrawOutlinedRect(0, 0, w, h)

        local dispName = targetFac and GRM.Factions.DisplayName(targetFac) or "Центр управления организациями"
        draw.SimpleText(dispName, "GRMFac_Title", 18, 23, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        if targetFac and targetFac ~= dispName then
            draw.SimpleText("[" .. targetFac .. "]", "GRMFac_Small", 26 + surface.GetTextSize(dispName) + 12, 23, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    -- Селектор организаций для SuperAdmin в шапке
    if isSA and table.Count(data) > 0 then
        local comboFac = vgui.Create("DComboBox", f)
        comboFac:SetPos(f:GetWide() - 430, 9)
        comboFac:SetSize(260, 28)
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
    btnClose:SetSize(34, 30)
    btnClose:SetPos(f:GetWide() - 44, 8)
    btnClose:SetText("✕")
    btnClose:SetFont("GRMFac_Btn")
    btnClose:SetTextColor(C.dim)
    btnClose.Paint = function(self, w, h)
        if self:IsHovered() then draw.RoundedBox(4, 0, 0, w, h, C.red) end
    end
    btnClose.DoClick = function() f:Remove() end

    local body = vgui.Create("DPanel", f)
    body:Dock(FILL)
    body:DockMargin(0, 46, 0, 0)
    body:SetPaintBackground(false)

    local sidebar = vgui.Create("DPanel", body)
    sidebar:Dock(LEFT)
    sidebar:SetWide(220)
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

    local function addTabBtn(tabKey, label, iconPath, builderFn)
        local btn = vgui.Create("DButton", sidebar)
        btn:Dock(TOP)
        btn:SetTall(38)
        btn:DockMargin(6, 4, 6, 0)
        btn:SetText("")
        btn.isActive = false
        btn.builder = builderFn

        local iconMat = iconPath and Material(iconPath, "smooth") or nil

        btn.Paint = function(self, w, h)
            local isHov = self:IsHovered()
            local isAct = self.isActive
            if isAct then
                draw.RoundedBox(6, 0, 0, w, h, C.accent)
            elseif isHov then
                draw.RoundedBox(6, 0, 0, w, h, C.cardHover)
            end
            if iconMat then
                surface.SetMaterial(iconMat)
                surface.SetDrawColor(isAct and color_white or (isHov and C.text or C.dim))
                surface.DrawTexturedRect(12, h / 2 - 8, 16, 16)
            end
            local col = isAct and color_white or (isHov and C.text or C.dim)
            draw.SimpleText(label, "GRMFac_Btn", iconMat and 36 or 16, h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        btn.DoClick = function() selectTab(tabKey, builderFn) end
        tabButtons[tabKey] = btn
    end

    -- ════════════ 1. ОБЗОР ════════════
    local function buildOverviewTab(pnl, facName, facData)
        local fac = facData and facData[facName] or {}
        local dispName = GRM.Factions.DisplayName(facName)
        local ldrKey = tostring(fac.Leader or "Не назначен")
        local memCount = fac.Members and table.Count(fac.Members) or 0
        local deptCount = fac.Departments and #fac.Departments or 0
        local subCount = fac.Subdepartments and table.Count(fac.Subdepartments) or 0
        local roleCount = fac.Roles and #fac.Roles or 0
        local budget = fac.Budget or 0

        local topCard = vgui.Create("DPanel", pnl)
        topCard:Dock(TOP)
        topCard:SetTall(105)
        topCard:SetPaintBackground(false)

        local function addStat(idx, title, val, color)
            local card = vgui.Create("DPanel", topCard)
            card:SetPos((idx - 1) * ((pnl:GetWide() - 40) / 4) + (idx > 1 and 8 or 0), 0)
            card:SetSize(((pnl:GetWide() - 40) / 4) - 8, 100)
            card.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, C.card)
                surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
                surface.DrawOutlinedRect(0, 0, w, h)
                draw.SimpleText(title, "GRMFac_Small", 14, 16, C.dim, TEXT_ALIGN_LEFT)
                draw.SimpleText(tostring(val), "GRMFac_StatVal", 14, 44, color or C.text, TEXT_ALIGN_LEFT)
            end
        end

        addStat(1, "СОТРУДНИКОВ В ШТАТЕ", memCount, C.accent)
        addStat(2, "ОТДЕЛОВ / ПОДОТДЕЛОВ", tostring(deptCount) .. " / " .. tostring(subCount), C.green)
        addStat(3, "ДОЛЖНОСТЕЙ", roleCount, C.gold)
        addStat(4, "КАЗНА И БЮДЖЕТ", tostring(budget) .. " руб.", C.gold)

        local infoPanel = vgui.Create("DPanel", pnl)
        infoPanel:Dock(FILL)
        infoPanel:DockMargin(0, 16, 0, 0)
        infoPanel.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
            surface.DrawOutlinedRect(0, 0, w, h)
            draw.SimpleText("Информация об организации", "GRMFac_Sub", 18, 18, C.text)
            draw.SimpleText("Публичное название: " .. dispName, "GRMFac_Normal", 18, 50, C.text)
            draw.SimpleText("Системный идентификатор: " .. facName, "GRMFac_Normal", 18, 76, C.dim)
            draw.SimpleText("Руководитель: " .. ldrKey, "GRMFac_Normal", 18, 102, C.dim)
            draw.SimpleText("Тэг волны: " .. (fac.Tag and fac.Tag ~= "" and fac.Tag or "—"), "GRMFac_Normal", 18, 128, C.dim)
        end

        local bBar = vgui.Create("DPanel", infoPanel)
        bBar:Dock(BOTTOM)
        bBar:SetTall(46)
        bBar:DockMargin(16, 0, 16, 16)
        bBar:SetPaintBackground(false)

        mkBtn(bBar, "Изменить название", C.accent, C.accentHover, function()
            promptInput("Новое публичное название", dispName, function(val)
                sendAction("setDisplayName", { facName, val }, refreshView)
            end)
        end):Dock(LEFT); bBar:GetChildren()[1]:SetWide(180)

        mkBtn(bBar, "Тэг волны", C.cardLight, C.cardHover, function()
            promptInput("Тэг волны фракции", fac.Tag or "", function(val)
                sendAction("setTag", { facName, val }, refreshView)
            end)
        end):Dock(LEFT); bBar:GetChildren()[2]:DockMargin(10, 0, 0, 0); bBar:GetChildren()[2]:SetWide(130)

        mkBtn(bBar, "Цвет фракции", C.cardLight, C.cardHover, function()
            local cModal = vgui.Create("DFrame")
            cModal:SetTitle(""); cModal:SetSize(320, 280); cModal:Center(); cModal:MakePopup()
            cModal.Paint = function(_, w, h)
                draw.RoundedBox(8, 0, 0, w, h, C.bg)
                draw.RoundedBox(8, 0, 0, w, 36, C.sidebar)
                draw.SimpleText("Выбор цвета", "GRMFac_Sub", 14, 18, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            local mixer = vgui.Create("DColorMixer", cModal)
            mixer:SetPos(16, 48); mixer:SetSize(288, 170)
            local curCol = fac.Color or { r=255, g=200, b=50 }
            mixer:SetColor(Color(curCol.r or 255, curCol.g or 200, curCol.b or 50))
            local btnSaveCol = mkBtn(cModal, "Сохранить цвет", C.accent, C.accentHover, function()
                local c = mixer:GetColor()
                sendAction("setColor", { facName, c.r, c.g, c.b }, refreshView)
                cModal:Close()
            end)
            btnSaveCol:SetPos(16, 230); btnSaveCol:SetSize(288, 36)
        end):Dock(LEFT); bBar:GetChildren()[3]:DockMargin(10, 0, 0, 0); bBar:GetChildren()[3]:SetWide(130)

        if isSA then
            mkBtn(bBar, "Удалить фракцию", C.red, C.redHover, function()
                Derma_Query("Удалить фракцию «" .. dispName .. "»?", "Подтверждение удаления", "Удалить", function()
                    sendAction("deleteFaction", { facName }, function()
                        f:Remove()
                        UI.Open()
                    end)
                end, "Отмена")
            end):Dock(RIGHT); bBar:GetChildren()[4]:SetWide(160)
        end
    end

    -- ════════════ 2. СОТРУДНИКИ ════════════
    local function buildMembersTab(pnl, facName, facData)
        local fac = facData and facData[facName] or {}

        local topBar = vgui.Create("DPanel", pnl)
        topBar:Dock(TOP)
        topBar:SetTall(34)
        topBar:DockMargin(0, 0, 0, 8)
        topBar:SetPaintBackground(false)

        local searchBox = vgui.Create("DTextEntry", topBar)
        searchBox:Dock(LEFT)
        searchBox:SetWide(300)
        searchBox:SetPlaceholderText("Поиск по имени или SteamID...")
        searchBox:SetFont("GRMFac_Normal")

        local list = vgui.Create("DListView", pnl)
        list:Dock(FILL)
        list:SetMultiSelect(false)
        list:AddColumn("Имя / Идентификатор"):SetFixedWidth(250)
        list:AddColumn("Должность"):SetFixedWidth(180)
        list:AddColumn("Отдел / Подотдел"):SetFixedWidth(280)
        list:AddColumn("Статус службы"):SetFixedWidth(130)
        list:AddColumn("Локация"):SetFixedWidth(140)
        skinListView(list)

        local function populateMembers(filter)
            list:Clear()
            filter = filter and string.Trim(filter):lower() or ""
            for key, rec in pairs(fac.Members or {}) do
                local rp = rec._rpName or tostring(key)
                if filter == "" or rp:lower():find(filter, 1, true) or tostring(key):lower():find(filter, 1, true) then
                    local roleDisplay = GRM.Factions.RoleDisplayName(fac, rec.Role)
                    local deptDisplay = GRM.Factions.DepartmentDisplayName(fac, rec.Department)
                    local subDisplay = GRM.Factions.SubdepartmentDisplayName(fac, rec.Subdepartment)
                    local branchText = deptDisplay
                    if subDisplay ~= "" and subDisplay ~= deptDisplay then
                        branchText = deptDisplay .. " [" .. subDisplay .. "]"
                    end
                    local onDuty = GRM.FactionDuty and GRM.FactionDuty.State and GRM.FactionDuty.State[key]
                    local dutyText = onDuty and "НА СЛУЖБЕ" or "ВНЕ СЛУЖБЫ"
                    local loc = rec._location or "—"
                    local ln = list:AddLine(rp, roleDisplay, branchText, dutyText, loc)
                    ln.memberKey = key
                end
            end
        end

        searchBox.OnChange = function(s) populateMembers(s:GetText()) end
        populateMembers("")

        local bBar = vgui.Create("DPanel", pnl)
        bBar:Dock(BOTTOM)
        bBar:SetTall(44)
        bBar:DockMargin(0, 8, 0, 0)
        bBar:SetPaintBackground(false)

        mkBtn(bBar, "+ Пригласить игрока", C.green, C.greenHover, function()
            local invModal = vgui.Create("DFrame")
            invModal:SetTitle(""); invModal:SetSize(420, 270); invModal:Center(); invModal:MakePopup()
            invModal.Paint = function(_, w, h)
                draw.RoundedBox(8, 0, 0, w, h, C.bg)
                draw.RoundedBox(8, 0, 0, w, 38, C.sidebar)
                draw.SimpleText("Приглашение во фракцию", "GRMFac_Sub", 14, 19, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            local comboPly = vgui.Create("DComboBox", invModal)
            comboPly:SetPos(16, 52); comboPly:SetSize(388, 28); comboPly:SetFont("GRMFac_Normal")
            comboPly:AddChoice("— Выберите игрока онлайн —", "")
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p ~= LocalPlayer() then
                    local n = p:GetNWString("GRM_RPName", "")
                    comboPly:AddChoice(string.format("%s [%s]", n ~= "" and n or p:Nick(), p:Nick()), p:SteamID())
                end
            end

            local comboRole = vgui.Create("DComboBox", invModal)
            comboRole:SetPos(16, 90); comboRole:SetSize(388, 28); comboRole:SetFont("GRMFac_Normal")
            for _, rKey in ipairs(fac.Roles or {}) do
                comboRole:AddChoice(GRM.Factions.RoleDisplayName(fac, rKey) .. " [" .. rKey .. "]", rKey)
            end

            local comboDept = vgui.Create("DComboBox", invModal)
            comboDept:SetPos(16, 128); comboDept:SetSize(388, 28); comboDept:SetFont("GRMFac_Normal")
            for _, dKey in ipairs(fac.Departments or {}) do
                comboDept:AddChoice(GRM.Factions.DepartmentDisplayName(fac, dKey) .. " [" .. dKey .. "]", dKey)
            end

            local btnSend = mkBtn(invModal, "Отправить приглашение", C.accent, C.accentHover, function()
                local _, targetSid = comboPly:GetSelected()
                local _, roleKey = comboRole:GetSelected()
                local _, deptKey = comboDept:GetSelected()
                if not targetSid or targetSid == "" then notification.AddLegacy("Выберите игрока!", NOTIFY_ERROR, 3) return end
                sendAction("inviteMember", { isSA and facName or targetSid, isSA and targetSid or roleKey, isSA and roleKey or deptKey, isSA and deptKey or nil }, refreshView)
                invModal:Close()
                notification.AddLegacy("Приглашение отправлено", NOTIFY_GENERIC, 3)
            end)
            btnSend:SetPos(16, 190); btnSend:SetSize(388, 38)
        end):Dock(LEFT); bBar:GetChildren()[1]:SetWide(190)

        mkBtn(bBar, "Изменить должность", C.cardLight, C.cardHover, function()
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
        end):Dock(LEFT); bBar:GetChildren()[2]:DockMargin(8, 0, 0, 0); bBar:GetChildren()[2]:SetWide(160)

        mkBtn(bBar, "Перевести в отдел / подотдел", C.cardLight, C.cardHover, function()
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
                    subMenu:AddOption(sub.name .. " [" .. sub.id .. "]", function()
                        sendAction("setSubdepartment", { isSA and facName or memKey, isSA and memKey or sub.id, isSA and sub.id or nil }, refreshView)
                    end)
                end
            end
            dMenu:Open()
        end):Dock(LEFT); bBar:GetChildren()[3]:DockMargin(8, 0, 0, 0); bBar:GetChildren()[3]:SetWide(220)

        if isSA then
            mkBtn(bBar, "Назначить лидером", C.gold, C.cardHover, function()
                local l = list:GetSelectedLine()
                if not l then return end
                local memKey = list:GetLine(l).memberKey
                Derma_Query("Сделать " .. memKey .. " лидером организации?", "Смена лидера", "Назначить", function()
                    sendAction("changeLeader", { facName, memKey }, refreshView)
                end, "Отмена")
            end):Dock(LEFT); bBar:GetChildren()[4]:DockMargin(8, 0, 0, 0); bBar:GetChildren()[4]:SetWide(160)
        end

        mkBtn(bBar, "Уволить", C.red, C.redHover, function()
            local l = list:GetSelectedLine()
            if not l then notification.AddLegacy("Выберите сотрудника в списке!", NOTIFY_ERROR, 3) return end
            local memKey = list:GetLine(l).memberKey
            Derma_Query("Уволить сотрудника " .. memKey .. " из организации?", "Подтверждение", "Уволить", function()
                sendAction("removeMember", { isSA and facName or memKey, isSA and memKey or nil }, refreshView)
            end, "Отмена")
        end):Dock(RIGHT); bBar:GetChildren()[isSA and 5 or 4]:SetWide(130)
    end

    -- ════════════ 3. СТРУКТУРА И ШТАТ ════════════
    local function buildStructureTab(pnl, facName, facData)
        local fac = facData and facData[facName] or {}

        local split = vgui.Create("DPanel", pnl)
        split:Dock(FILL)
        split:SetPaintBackground(false)

        -- Левая колонка: ДОЛЖНОСТИ (ROLES)
        local left = vgui.Create("DPanel", split)
        left:Dock(LEFT)
        left:SetWide((pnl:GetWide() - 30) * 0.40)
        left.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            draw.SimpleText("Должности и ранги (Roles)", "GRMFac_Sub", 14, 16, C.gold)
        end

        local rList = vgui.Create("DListView", left)
        rList:Dock(FILL)
        rList:DockMargin(10, 42, 10, 50)
        rList:AddColumn("Системный ключ"):SetFixedWidth(120)
        rList:AddColumn("Публичное название (RU)")
        skinListView(rList)

        for _, rKey in ipairs(fac.Roles or {}) do
            local rDisp = GRM.Factions.RoleDisplayName(fac, rKey)
            local line = rList:AddLine(rKey, rDisp)
            line.roleKey = rKey
        end

        local rBar = vgui.Create("DPanel", left)
        rBar:Dock(BOTTOM)
        rBar:SetTall(36)
        rBar:DockMargin(10, 0, 10, 8)
        rBar:SetPaintBackground(false)

        mkBtn(rBar, "+ Добавить", C.accent, C.accentHover, function()
            promptInput("Системный ключ новой должности (eng)", "officer", function(kVal)
                promptInput("Публичное название должности (RU)", "Офицер", function(dVal)
                    sendAction("addRole", { isSA and facName or kVal, isSA and kVal or nil }, function()
                        sendAction("renameRole", { isSA and facName or kVal, isSA and kVal or dVal, isSA and dVal or nil }, refreshView)
                    end)
                end)
            end)
        end):Dock(LEFT); rBar:GetChildren()[1]:SetWide(105)

        mkBtn(rBar, "Переименовать", C.cardLight, C.cardHover, function()
            local l = rList:GetSelectedLine()
            if not l then notification.AddLegacy("Выберите должность в списке!", NOTIFY_ERROR, 3) return end
            local rKey = rList:GetLine(l).roleKey
            local curDisp = GRM.Factions.RoleDisplayName(fac, rKey)
            promptInput("Новое публичное название должности", curDisp, function(val)
                sendAction("renameRole", { isSA and facName or rKey, isSA and rKey or val, isSA and val or nil }, refreshView)
            end)
        end):Dock(LEFT); rBar:GetChildren()[2]:DockMargin(6, 0, 0, 0); rBar:GetChildren()[2]:SetWide(125)

        mkBtn(rBar, "▲", C.cardLight, C.cardHover, function()
            local l = rList:GetSelectedLine()
            if not l then return end
            local rKey = rList:GetLine(l).roleKey
            sendAction("moveRole", { isSA and facName or rKey, isSA and rKey or "up", isSA and "up" or nil }, refreshView)
        end):Dock(LEFT); rBar:GetChildren()[3]:DockMargin(6, 0, 0, 0); rBar:GetChildren()[3]:SetWide(30)

        mkBtn(rBar, "▼", C.cardLight, C.cardHover, function()
            local l = rList:GetSelectedLine()
            if not l then return end
            local rKey = rList:GetLine(l).roleKey
            sendAction("moveRole", { isSA and facName or rKey, isSA and rKey or "down", isSA and "down" or nil }, refreshView)
        end):Dock(LEFT); rBar:GetChildren()[4]:DockMargin(4, 0, 0, 0); rBar:GetChildren()[4]:SetWide(30)

        mkBtn(rBar, "Удалить", C.red, C.redHover, function()
            local l = rList:GetSelectedLine()
            if not l then return end
            local rKey = rList:GetLine(l).roleKey
            sendAction("removeRole", { isSA and facName or rKey, isSA and rKey or nil }, refreshView)
        end):Dock(RIGHT); rBar:GetChildren()[5]:SetWide(75)

        -- Правая колонка: ИЕРАРХИЯ ОТДЕЛОВ И ПОДОТДЕЛОВ
        local right = vgui.Create("DPanel", split)
        right:Dock(RIGHT)
        right:SetWide((pnl:GetWide() - 30) * 0.58)
        right.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            draw.SimpleText("Иерархия отделов и подотделов", "GRMFac_Sub", 14, 16, C.green)
        end

        local deptScroll = vgui.Create("DScrollPanel", right)
        deptScroll:Dock(FILL)
        deptScroll:DockMargin(10, 42, 10, 50)

        for _, dKey in ipairs(fac.Departments or {}) do
            local dDisp = GRM.Factions.DepartmentDisplayName(fac, dKey)
            local subList = GRM.Factions.GetSubdepartments(fac, dKey)

            local dCard = vgui.Create("DPanel", deptScroll)
            dCard:Dock(TOP)
            dCard:DockMargin(0, 0, 0, 8)
            dCard:SetTall(46 + #subList * 34)
            dCard.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, Color(30, 38, 52, 230))
                surface.SetDrawColor(C.borderLight.r, C.borderLight.g, C.borderLight.b, 100)
                surface.DrawOutlinedRect(0, 0, w, h)
                draw.SimpleText(dDisp, "GRMFac_Sub", 14, 18, C.text)
                draw.SimpleText("[" .. dKey .. "]", "GRMFac_Small", 18 + surface.GetTextSize(dDisp) + 8, 19, C.dim)
            end

            local dBtnAddSub = mkBtn(dCard, "+ Подотдел", C.teal, C.accentHover, function()
                promptInput("Системный ключ подотдела (eng)", "sub_1", function(subKey)
                    promptInput("Публичное название подотдела (RU)", "1-й Взвод", function(subName)
                        promptInput("Тактический тег в рацию (например [ППС-1])", "[ППС-1]", function(subTag)
                            sendAction("addSubdepartment", { isSA and facName or dKey, isSA and dKey or subKey, isSA and subKey or subName, isSA and subName or subTag, isSA and subTag or 0, isSA and 0 or nil }, refreshView)
                        end)
                    end)
                end)
            end); dBtnAddSub:SetSize(96, 26); dBtnAddSub:SetPos(right:GetWide() - 250, 10)

            local dBtnRename = mkBtn(dCard, "Переименовать", C.cardLight, C.cardHover, function()
                promptInput("Новое название отдела", dDisp, function(val)
                    sendAction("renameDepartment", { isSA and facName or dKey, isSA and dKey or val, isSA and val or nil }, refreshView)
                end)
            end); dBtnRename:SetSize(110, 26); dBtnRename:SetPos(right:GetWide() - 148, 10)

            local dBtnDel = mkBtn(dCard, "✕", C.red, C.redHover, function()
                Derma_Query("Удалить отдел «" .. dDisp .. "»?", "Подтверждение", "Удалить", function()
                    sendAction("removeDepartment", { isSA and facName or dKey, isSA and dKey or nil }, refreshView)
                end, "Отмена")
            end); dBtnDel:SetSize(28, 26); dBtnDel:SetPos(right:GetWide() - 34, 10)

            local subContainer = vgui.Create("DPanel", dCard)
            subContainer:Dock(FILL)
            subContainer:DockMargin(16, 42, 8, 4)
            subContainer:SetPaintBackground(false)

            for _, sub in ipairs(subList) do
                local subRow = vgui.Create("DPanel", subContainer)
                subRow:Dock(TOP)
                subRow:SetTall(30)
                subRow:DockMargin(0, 2, 0, 0)
                subRow.Paint = function(self, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, Color(22, 28, 38, 220))
                    local tag = sub.tag ~= "" and (" " .. sub.tag) or ""
                    draw.SimpleText(sub.name .. tag, "GRMFac_Normal", 10, h / 2, C.teal, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    local quotaText = sub.quota > 0 and ("лимит: " .. tostring(sub.quota)) or "без лимита"
                    draw.SimpleText("[" .. sub.id .. " • " .. quotaText .. "]", "GRMFac_Small", w - 150, h / 2, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end

                local sBtnRename = mkBtn(subRow, "Имя", C.cardLight, C.cardHover, function()
                    promptInput("Новое название подотдела", sub.name, function(val)
                        sendAction("renameSubdepartment", { isSA and facName or sub.id, isSA and sub.id or val, isSA and val or nil }, refreshView)
                    end)
                end); sBtnRename:SetSize(46, 22); sBtnRename:SetPos(right:GetWide() - 140, 4)

                local sBtnDel = mkBtn(subRow, "✕", C.red, C.redHover, function()
                    Derma_Query("Удалить подотдел «" .. sub.name .. "»?", "Подтверждение", "Удалить", function()
                        sendAction("removeSubdepartment", { isSA and facName or sub.id, isSA and sub.id or nil }, refreshView)
                    end, "Отмена")
                end); sBtnDel:SetSize(24, 22); sBtnDel:SetPos(right:GetWide() - 88, 4)
            end
        end

        local dBar = vgui.Create("DPanel", right)
        dBar:Dock(BOTTOM)
        dBar:SetTall(36)
        dBar:DockMargin(10, 0, 10, 8)
        dBar:SetPaintBackground(false)

        mkBtn(dBar, "+ Создать новый отдел", C.green, C.greenHover, function()
            promptInput("Системный ключ отдела (eng)", "patrol", function(kVal)
                promptInput("Публичное название отдела (RU)", "Патрульная служба", function(dVal)
                    sendAction("addDepartment", { isSA and facName or kVal, isSA and kVal or nil }, function()
                        sendAction("renameDepartment", { isSA and facName or kVal, isSA and kVal or dVal, isSA and dVal or nil }, refreshView)
                    end)
                end)
            end)
        end):Dock(LEFT); dBar:GetChildren()[1]:SetWide(190)
    end

    -- ════════════ 4. КАДРОВЫЕ ДЕЛА ════════════
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

    -- ════════════ 5. ДОСТУПЫ И СВЯЗЬ ════════════
    local function buildAccessTab(pnl, facName, facData)
        local fac = facData and facData[facName] or {}
        local scroll = vgui.Create("DScrollPanel", pnl)
        scroll:Dock(FILL)

        local function addAccessToggle(title, desc, getVal, onToggle)
            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP)
            row:SetTall(52)
            row:DockMargin(0, 0, 0, 6)
            row.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, C.card)
                draw.SimpleText(title, "GRMFac_Sub", 14, 14, C.text)
                draw.SimpleText(desc, "GRMFac_Small", 14, 32, C.dim)
            end

            local chk = vgui.Create("DCheckBoxLabel", row)
            chk:SetPos(pnl:GetWide() - 150, 14)
            chk:SetSize(120, 24)
            local cur = getVal()
            chk:SetText(cur and "РАЗРЕШЕНО" or "ЗАПРЕЩЕНО")
            chk:SetFont("GRMFac_Btn")
            chk:SetTextColor(cur and C.green or C.dim)
            chk:SetValue(cur and 1 or 0)
            chk.OnChange = function(_, v)
                onToggle(v == true)
                chk:SetText(v and "РАЗРЕШЕНО" or "ЗАПРЕЩЕНО")
                chk:SetTextColor(v and C.green or C.dim)
            end
        end

        addAccessToggle("Волна департамента (/dep, /depb)", "Право служебной радиосвязи между всеми ведомствами",
            function() return fac.DepAccess == true end,
            function(v) sendAction("setDepAccess", { facName, v }, refreshView) end)

        addAccessToggle("Государственные новости (/gnews)", "Право трансляции официальных новостей лидером",
            function() return fac.GNewsAccess == true end,
            function(v) sendExtAction("setGNewsAccess", { facName, v }, refreshView) end)

        addAccessToggle("Доска объявлений (/board)", "Право публикации объявлений о наборе сотрудников",
            function() return (GRM.Board and GRM.Board.Cfg and GRM.Board.Cfg.allow and GRM.Board.Cfg.allow[facName]) == true end,
            function(v) sendBridgeAction("board", facName, v, refreshView) end)

        addAccessToggle("Радиовещание у микрофонов (/bcast)", "Право проведения городских радиоэфиров",
            function() return (GRM.Broadcast and GRM.Broadcast.Cfg and GRM.Broadcast.Cfg.journalists and GRM.Broadcast.Cfg.journalists[facName]) == true end,
            function(v) sendBridgeAction("journ", facName, v, refreshView) end)

        addAccessToggle("Оповещения тревоги (/alert, /alertall)", "Право запуска тревожных сирен и оповещений",
            function() return (GRM.Broadcast and GRM.Broadcast.Cfg and GRM.Broadcast.Cfg.alerters and GRM.Broadcast.Cfg.alerters[facName]) == true end,
            function(v) sendBridgeAction("alert", facName, v, refreshView) end)

        addAccessToggle("Биржа труда (/jobs)", "Публикация оплачиваемых государственных заказов",
            function() return (GRM.Jobs and GRM.Jobs.Cfg and GRM.Jobs.Cfg.allow and GRM.Jobs.Cfg.allow[facName]) == true end,
            function(v) sendBridgeAction("jobs", facName, v, refreshView) end)

        addAccessToggle("Государственные услуги (каталог)", "Оказание платных услуг населению",
            function() return fac.ServiceAccess == true end,
            function(v) sendAction("setServiceAccess", { facName, "service", v }, refreshView) end)

        addAccessToggle("Выписка счетов и квитанций", "Формирование счетов на оплату в банкоматах",
            function() return fac.InvoiceAccess == true end,
            function(v) sendAction("setServiceAccess", { facName, "invoice", v }, refreshView) end)

        addAccessToggle("Государственный реестр дипломов", "Выдача официальных дипломов об образовании",
            function() return fac.DiplomaAccess == true end,
            function(v) sendAction("setServiceAccess", { facName, "diploma", v }, refreshView) end)
    end

    -- ════════════ 6. ВООРУЖЕНИЕ И ФОРМА ════════════
    local function buildWeaponsModelsTab(pnl, facName, facData)
        local fac = facData and facData[facName] or {}
        local split = vgui.Create("DPanel", pnl)
        split:Dock(FILL); split:SetPaintBackground(false)

        local left = vgui.Create("DPanel", split)
        left:Dock(LEFT); left:SetWide((pnl:GetWide() - 30) * 0.49)
        left.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            draw.SimpleText("Табельное вооружение организации", "GRMFac_Sub", 16, 16, C.gold)
            draw.SimpleText("Оружие настраивается по фракции, ролям и отделам.", "GRMFac_Small", 16, 40, C.dim)
        end

        local right = vgui.Create("DPanel", split)
        right:Dock(RIGHT); right:SetWide((pnl:GetWide() - 30) * 0.49)
        right.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            draw.SimpleText("Служебная форма и гардероб", "GRMFac_Sub", 16, 16, C.green)
            draw.SimpleText("Модели и бодигруппы назначаются по должностям и отделам.", "GRMFac_Small", 16, 40, C.dim)
        end

        mkBtn(left, "Открыть редактор арсенала (/weapons_admin)", C.accent, C.accentHover, function()
            RunConsoleCommand("weapons_admin")
        end):Dock(BOTTOM); left:GetChildren()[1]:DockMargin(16, 0, 16, 16); left:GetChildren()[1]:SetTall(40)

        mkBtn(right, "Открыть редактор гардероба (/models_admin)", C.green, C.greenHover, function()
            RunConsoleCommand("models_admin")
        end):Dock(BOTTOM); right:GetChildren()[1]:DockMargin(16, 0, 16, 16); right:GetChildren()[1]:SetTall(40)
    end

    -- ════════════ 7. МАСКИРОВКА И СПЕЦНАСТРОЙКИ ════════════
    local function buildMaskTab(pnl, facName, facData)
        local fac = facData and facData[facName] or {}
        local panel = vgui.Create("DPanel", pnl)
        panel:Dock(FILL)
        panel.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            draw.SimpleText("Маскировка и работа под прикрытием", "GRMFac_Sub", 16, 16, C.teal)
            draw.SimpleText("Назначение отделов разведки, выбор поддельной формы и документов прикрытия.", "GRMFac_Normal", 16, 44, C.dim)
        end

        mkBtn(panel, "Открыть панель маскировки (/grm_mask_admin)", C.teal, C.accentHover, function()
            RunConsoleCommand("grm_mask_admin")
        end):Dock(BOTTOM); panel:GetChildren()[1]:DockMargin(16, 0, 16, 16); panel:GetChildren()[1]:SetTall(42)
    end

    -- ════════════ 8. КОМЕНДАНТСКИЙ ЧАС ════════════
    local function buildCurfewTab(pnl, facName, facData)
        local fac = facData and facData[facName] or {}
        local cState = CurfewState or { active = false, endTime = 0, faction = "" }
        local p = vgui.Create("DPanel", pnl)
        p:Dock(FILL)
        p.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            draw.SimpleText("Комендантский час", "GRMFac_Sub", 16, 16, C.red)
            local rem = math.max(0, (cState.endTime or 0) - CurTime())
            local stText = cState.active and ("АКТИВЕН — осталось: " .. string.format("%02d:%02d", math.floor(rem / 60), math.floor(rem % 60))) or "НЕ АКТИВЕН"
            draw.SimpleText("Текущий статус: " .. stText, "GRMFac_Normal", 16, 46, cState.active and C.red or C.green)
        end

        local bBar = vgui.Create("DPanel", p)
        bBar:Dock(BOTTOM); bBar:SetTall(42); bBar:DockMargin(16, 0, 16, 16); bBar:SetPaintBackground(false)

        mkBtn(bBar, "Объявить на 10 мин", C.red, C.redHover, function()
            sendExtAction("startCurfew", { 10 }, refreshView)
        end):Dock(LEFT); bBar:GetChildren()[1]:SetWide(180)

        mkBtn(bBar, "Объявить на 20 мин", C.red, C.redHover, function()
            sendExtAction("startCurfew", { 20 }, refreshView)
        end):Dock(LEFT); bBar:GetChildren()[2]:DockMargin(8, 0, 0, 0); bBar:GetChildren()[2]:SetWide(180)

        mkBtn(bBar, "Отменить комендантский час", C.green, C.greenHover, function()
            sendExtAction("stopCurfew", {}, refreshView)
        end):Dock(RIGHT); bBar:GetChildren()[3]:SetWide(220)
    end

    -- ════════════ 9. КАЗНА И ЭКОНОМИКА ════════════
    local function buildFinanceTab(pnl, facName, facData)
        local fac = facData and facData[facName] or {}
        local p = vgui.Create("DPanel", pnl)
        p:Dock(FILL)
        p.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            draw.SimpleText("Казна и финансы организации", "GRMFac_Sub", 16, 16, C.gold)
            draw.SimpleText("Текущий баланс бюджета: " .. tostring(fac.Budget or 0) .. " руб.", "GRMFac_StatVal", 16, 50, C.gold)
            draw.SimpleText("Налоговая ставка: " .. tostring(math.floor((fac.TaxRate or 0.05) * 100)) .. "%", "GRMFac_Normal", 16, 90, C.dim)
        end
    end

    -- ════════════ 10. СОЗДАТЬ ОРГАНИЗАЦИЮ (SUPERADMIN) ════════════
    local function buildCreateTab(pnl, facName, facData)
        local form = vgui.Create("DPanel", pnl)
        form:Dock(FILL)
        form.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            draw.SimpleText("Регистрация новой государственной или частной организации", "GRMFac_Sub", 16, 16, C.gold)
        end

        local lbl1 = vgui.Create("DLabel", form)
        lbl1:SetPos(20, 50); lbl1:SetText("Регистрационный системный ключ (eng):"); lbl1:SetFont("GRMFac_Normal"); lbl1:SetTextColor(C.dim); lbl1:SizeToContents()
        local entKey = vgui.Create("DTextEntry", form)
        entKey:SetPos(20, 72); entKey:SetSize(400, 28); entKey:SetFont("GRMFac_Normal"); entKey:SetPlaceholderText("police_department")

        local lbl2 = vgui.Create("DLabel", form)
        lbl2:SetPos(20, 110); lbl2:SetText("Публичное название организации (RU):"); lbl2:SetFont("GRMFac_Normal"); lbl2:SetTextColor(C.dim); lbl2:SizeToContents()
        local entDisp = vgui.Create("DTextEntry", form)
        entDisp:SetPos(20, 132); entDisp:SetSize(400, 28); entDisp:SetFont("GRMFac_Normal"); entDisp:SetPlaceholderText("Полицейский Департамент")

        local lbl3 = vgui.Create("DLabel", form)
        lbl3:SetPos(20, 170); lbl3:SetText("Тэг радиоволны:"); lbl3:SetFont("GRMFac_Normal"); lbl3:SetTextColor(C.dim); lbl3:SizeToContents()
        local entTag = vgui.Create("DTextEntry", form)
        entTag:SetPos(20, 192); entTag:SetSize(400, 28); entTag:SetFont("GRMFac_Normal"); entTag:SetPlaceholderText("PD")

        local btnCreate = mkBtn(form, "+ Создать организацию", C.green, C.greenHover, function()
            local kVal = string.Trim(entKey:GetText())
            local dVal = string.Trim(entDisp:GetText())
            local tVal = string.Trim(entTag:GetText())
            if kVal == "" or dVal == "" then notification.AddLegacy("Заполните ключ и название!", NOTIFY_ERROR, 3) return end
            sendAction("createFactionV2", { kVal, dVal, "", tVal, 255, 200, 50 }, function()
                f:Remove()
                UI.Open(kVal)
                notification.AddLegacy("Организация создана!", NOTIFY_GENERIC, 3)
            end)
        end)
        btnCreate:SetPos(20, 250); btnCreate:SetSize(400, 38)
    end

    -- Добавление вкладок в боковое меню
    addTabBtn("overview", "Обзор", "icon16/application_home.png", buildOverviewTab)
    addTabBtn("members", "Личный состав", "icon16/group.png", buildMembersTab)
    addTabBtn("structure", "Структура и штат", "icon16/chart_organisation.png", buildStructureTab)
    addTabBtn("personnel", "Кадровые дела", "icon16/book.png", buildPersonnelTab)
    addTabBtn("access", "Доступы и связь", "icon16/key.png", buildAccessTab)
    addTabBtn("gear", "Вооружение и форма", "icon16/shield.png", buildWeaponsModelsTab)
    addTabBtn("mask", "Маскировка", "icon16/user_suit.png", buildMaskTab)
    addTabBtn("curfew", "Комендантский час", "icon16/clock.png", buildCurfewTab)
    addTabBtn("finance", "Казна и финансы", "icon16/money.png", buildFinanceTab)
    if isSA then
        addTabBtn("create", "Создать организацию", "icon16/add.png", buildCreateTab)
    end

    selectTab("overview", buildOverviewTab)
    net.Start("Factions_GetData")
    net.SendToServer()
end

function OpenUnifiedFactionsMenu(fname)
    UI.Open(fname)
end

concommand.Add("grm_factions_menu", function() UI.Open() end)
concommand.Add("grm_faction", function() UI.Open() end)
concommand.Add("factions_unified", function() UI.Open() end)

hook.Add("GRM_FactionUIRefreshed", "GRM_FactionUnified_AutoRefresh", function(data)
    if IsValid(currentFrame) then
        local activeFac = getLeaderFactionName(data) or getPlayerFactionName(data)
        if LocalPlayer():IsSuperAdmin() and not activeFac then activeFac = next(data or {}) end
        if activeFac then
            currentFrame:Remove()
            UI.Open(activeFac)
        end
    end
end)

hook.Add("PlayerSayTransform", "GRM_FactionUnified_ChatCommand", function(ply, datapack)
    if not istable(datapack) then return end
    local text = datapack[1]
    if not isstring(text) then return end
    local lower = string.lower(string.Trim(text))
    if lower == "/fmenu" or lower == "/фракция" or lower == "/состав" or lower == "/factions" then
        if CLIENT then UI.Open() end
    end
end)

print("[GRM Factions Unified UI] v" .. UI.Version .. " fully initialized with all 10 management domains")
