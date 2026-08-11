--[[--------------------------------------------------------------------
    grm_doc_computer — cl_init.lua (Клиентская часть и UI терминала)
----------------------------------------------------------------------]]
include("shared.lua")

local CC = {
    bg      = Color(20, 24, 32, 250),
    panel   = Color(28, 34, 46, 245),
    header  = Color(34, 42, 58, 255),
    accent  = Color(80, 160, 255),
    success = Color(60, 190, 100),
    danger  = Color(220, 70, 70),
    text    = Color(230, 235, 245),
    dim     = Color(150, 160, 175),
    gold    = Color(245, 200, 70),
}

function ENT:Draw()
    self:DrawModel()

    local pos = self:GetPos() + self:GetUp() * 24 + self:GetForward() * 2
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    cam.Start3D2D(pos, ang, 0.08)
        draw.RoundedBox(6, -140, -50, 280, 100, Color(15, 18, 24, 240))
        draw.SimpleText("ОТДЕЛ КАДРОВ, ПАСПОРТОВ И ВОЕНКОМАТ", "DermaDefaultBold", 0, -25, Color(80, 160, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Служебный Компьютер", "DermaDefault", 0, -5, Color(220, 225, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Нажмите [E] для входа в систему", "DermaDefault", 0, 20, Color(160, 170, 185), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

net.Receive("GRM_DocComp_Open", function()
    local ent          = net.ReadEntity()
    local onlineList   = net.ReadTable() or {}
    local tpls         = net.ReadTable() or {}
    local registry     = net.ReadTable() or { passports = {}, badges = {}, coverBadges = {}, military = {} }
    local myFaction    = net.ReadString()
    local isSuperAdmin = net.ReadBool()
    local isLeader     = net.ReadBool()
    local hasCover     = net.ReadBool()
    local hasPassport  = net.ReadBool()
    local hasMilitary  = net.ReadBool()

    local frame = vgui.Create("DFrame")
    frame:SetSize(940, 680)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:ShowCloseButton(false)

    frame.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, CC.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 40, CC.header, true, true, false, false)
        draw.SimpleText("СЛУЖЕБНЫЙ ТЕРМИНАЛ ОФОРМЛЕНИЯ ДОКУМЕНТОВ", "DermaDefaultBold", 16, 20, CC.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local btnClose = vgui.Create("DButton", frame)
    btnClose:SetSize(28, 24)
    btnClose:SetPos(frame:GetWide() - 36, 8)
    btnClose:SetText("✕")
    btnClose:SetTextColor(CC.dim)
    btnClose.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and CC.danger or Color(45, 50, 65))
        if s:IsHovered() then s:SetTextColor(color_white) else s:SetTextColor(CC.dim) end
    end
    btnClose.DoClick = function() frame:Close() end

    local tabs = vgui.Create("DPropertySheet", frame)
    tabs:Dock(FILL)
    tabs:DockMargin(4, 38, 4, 4)

    -- ══════════════════════════════════════════════════════════════
    -- ВКЛАДКА 1: ПАСПОРТНЫЙ СТОЛ
    -- ══════════════════════════════════════════════════════════════
    local passPnl = vgui.Create("DPanel", tabs)
    passPnl:DockPadding(16, 16, 16, 16)
    passPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, CC.panel) end

    local lblState = vgui.Create("DLabel", passPnl)
    lblState:SetPos(16, 12) lblState:SetText("Название государства:") lblState:SetTextColor(CC.gold) lblState:SetFont("DermaDefaultBold") lblState:SizeToContents()
    local entStateTitle = vgui.Create("DTextEntry", passPnl)
    entStateTitle:SetPos(16, 32) entStateTitle:SetSize(360, 26)
    entStateTitle:SetText(tpls.passport and tpls.passport.stateTitle or "РЕСПУБЛИКА ГРАНД")
    entStateTitle:SetEnabled(isSuperAdmin)

    local lblP1 = vgui.Create("DLabel", passPnl)
    lblP1:SetPos(16, 68) lblP1:SetText("Выберите гражданина:") lblP1:SetFont("DermaDefaultBold") lblP1:SetTextColor(CC.accent) lblP1:SizeToContents()

    local comboPassTarget = vgui.Create("DComboBox", passPnl)
    comboPassTarget:SetPos(16, 88) comboPassTarget:SetSize(420, 28)
    comboPassTarget:AddChoice("— Выберите гражданина онлайн —", "")

    for _, pData in ipairs(onlineList) do
        local label = string.format("%s  [%s]  (%s)", pData.rpName or "?", pData.nick or "?", pData.key or "")
        comboPassTarget:AddChoice(label, pData)
    end

    local lblP2 = vgui.Create("DLabel", passPnl)
    lblP2:SetPos(16, 124) lblP2:SetText("ФИО гражданина (ручное редактирование):") lblP2:SetTextColor(CC.text) lblP2:SizeToContents()
    local entPassName = vgui.Create("DTextEntry", passPnl)
    entPassName:SetPos(16, 144) entPassName:SetSize(350, 26)

    local lblP3 = vgui.Create("DLabel", passPnl)
    lblP3:SetPos(380, 124) lblP3:SetText("Пол:") lblP3:SetTextColor(CC.text) lblP3:SizeToContents()
    local comboGender = vgui.Create("DComboBox", passPnl)
    comboGender:SetPos(380, 144) comboGender:SetSize(150, 26)
    comboGender:AddChoice("Мужской") comboGender:AddChoice("Женский")
    comboGender:SetValue("Мужской")

    local lblP4 = vgui.Create("DLabel", passPnl)
    lblP4:SetPos(16, 178) lblP4:SetText("Дата рождения / Возраст:") lblP4:SetTextColor(CC.text) lblP4:SizeToContents()
    local entPassBirth = vgui.Create("DTextEntry", passPnl)
    entPassBirth:SetPos(16, 198) entPassBirth:SetSize(180, 26) entPassBirth:SetText("12.04.1988")

    local lblP5 = vgui.Create("DLabel", passPnl)
    lblP5:SetPos(220, 178) lblP5:SetText("Серия паспорта:") lblP5:SetTextColor(CC.text) lblP5:SizeToContents()
    local entPassSeries = vgui.Create("DTextEntry", passPnl)
    entPassSeries:SetPos(220, 198) entPassSeries:SetSize(140, 26) entPassSeries:SetText(tpls.passport and tpls.passport.defaultSeries or "GRM")

    local lblP6 = vgui.Create("DLabel", passPnl)
    lblP6:SetPos(380, 178) lblP6:SetText("Номер паспорта:") lblP6:SetTextColor(CC.text) lblP6:SizeToContents()
    local entPassNumber = vgui.Create("DTextEntry", passPnl)
    entPassNumber:SetPos(380, 198) entPassNumber:SetSize(180, 26) entPassNumber:SetText("428901")

    local lblP7 = vgui.Create("DLabel", passPnl)
    lblP7:SetPos(16, 232) lblP7:SetText("Кем выдан (орган выдачи):") lblP7:SetTextColor(CC.text) lblP7:SizeToContents()
    local entPassIssuer = vgui.Create("DTextEntry", passPnl)
    entPassIssuer:SetPos(16, 252) entPassIssuer:SetSize(400, 26) entPassIssuer:SetText("Паспортный стол Центрального района")

    local selectedCharKey = ""
    local selectedSid64 = "0"

    comboPassTarget.OnSelect = function(_, _, _, pData)
        if istable(pData) then
            selectedCharKey = pData.key or ""
            selectedSid64 = pData.steamID64 or "0"
            entPassName:SetText(pData.rpName or "")

            local short = selectedSid64:sub(-5)
            local slotNum = (selectedCharKey:match(":char([1-3])$") or "1")
            entPassNumber:SetText(short .. "-" .. slotNum)

            if registry.passports and registry.passports[selectedCharKey] then
                local ex = registry.passports[selectedCharKey]
                entPassName:SetText(ex.fullName or pData.rpName or "")
                entPassBirth:SetText(ex.birthDate or "12.04.1988")
                entPassSeries:SetText(ex.series or "GRM")
                entPassNumber:SetText(ex.number or short)
                entPassIssuer:SetText(ex.issuedBy or "Паспортный стол")
                comboGender:SetValue(ex.gender or "Мужской")
            end
        end
    end

    local btnIssuePass = vgui.Create("DButton", passPnl)
    btnIssuePass:SetPos(16, 300)
    btnIssuePass:SetSize(300, 36)
    btnIssuePass:SetText("✔ Оформить и выдать паспорт")
    btnIssuePass:SetFont("DermaDefaultBold")
    btnIssuePass:SetTextColor(color_white)
    btnIssuePass.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and CC.success or Color(35, 140, 75))
    end
    btnIssuePass.DoClick = function()
        if not hasPassport then
            notification.AddLegacy("У вашей фракции нет допуска к оформлению паспортов!", NOTIFY_ERROR, 3)
            return
        end
        if selectedCharKey == "" then
            notification.AddLegacy("Выберите гражданина из списка!", NOTIFY_ERROR, 3)
            return
        end

        if isSuperAdmin and entStateTitle:GetText() ~= "" then
            tpls.passport = tpls.passport or {}
            tpls.passport.stateTitle = entStateTitle:GetText()
            net.Start("GRM_Doc_AdminSave")
                net.WriteTable(tpls)
            net.SendToServer()
        end

        local pack = {
            fullName    = entPassName:GetText(),
            gender      = comboGender:GetValue(),
            birthDate   = entPassBirth:GetText(),
            series      = entPassSeries:GetText(),
            number      = entPassNumber:GetText(),
            issuedBy    = entPassIssuer:GetText(),
            issueDate   = os.date("%d.%m.%Y"),
            status      = "Действителен",
            steamID64   = selectedSid64,
        }
        net.Start("GRM_Doc_ComputerIssue")
            net.WriteString("passport")
            net.WriteString(selectedCharKey)
            net.WriteTable(pack)
        net.SendToServer()
        frame:Close()
    end

    tabs:AddSheet("Паспортный стол", passPnl, "icon16/vcard.png")

    -- ══════════════════════════════════════════════════════════════
    -- ВКЛАДКА 2: СЛУЖЕБНЫЕ УДОСТОВЕРЕНИЯ (Отдел кадров)
    -- ══════════════════════════════════════════════════════════════
    local badgePnl = vgui.Create("DPanel", tabs)
    badgePnl:DockPadding(16, 16, 16, 16)
    badgePnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, CC.panel) end

    local lblB1 = vgui.Create("DLabel", badgePnl)
    lblB1:SetPos(16, 16) lblB1:SetText("Выберите сотрудника ведомства:") lblB1:SetFont("DermaDefaultBold") lblB1:SetTextColor(CC.accent) lblB1:SizeToContents()

    local comboBadgeTarget = vgui.Create("DComboBox", badgePnl)
    comboBadgeTarget:SetPos(16, 36) comboBadgeTarget:SetSize(420, 28)
    comboBadgeTarget:AddChoice("— Выберите сотрудника —", "")

    for _, pData in ipairs(onlineList) do
        if pData.faction and pData.faction ~= "" and (isSuperAdmin or pData.faction == myFaction) then
            local label = string.format("%s  [%s]  •  %s  (%s)", pData.rpName or "?", pData.role or "?", pData.faction, pData.key or "")
            comboBadgeTarget:AddChoice(label, pData)
        end
    end

    local lblB2 = vgui.Create("DLabel", badgePnl)
    lblB2:SetPos(16, 75) lblB2:SetText("ФИО сотрудника (ручное редактирование):") lblB2:SetTextColor(CC.text) lblB2:SizeToContents()
    local entBadgeName = vgui.Create("DTextEntry", badgePnl)
    entBadgeName:SetPos(16, 95) entBadgeName:SetSize(300, 26)

    local lblB3 = vgui.Create("DLabel", badgePnl)
    lblB3:SetPos(330, 75) lblB3:SetText("Организация / Ведомство:") lblB3:SetTextColor(CC.text) lblB3:SizeToContents()
    local entBadgeFac = vgui.Create("DTextEntry", badgePnl)
    entBadgeFac:SetPos(330, 95) entBadgeFac:SetSize(300, 26)

    local lblB4 = vgui.Create("DLabel", badgePnl)
    lblB4:SetPos(16, 130) lblB4:SetText("Должность / Звание (ручное):") lblB4:SetTextColor(CC.text) lblB4:SizeToContents()
    local entBadgeRole = vgui.Create("DTextEntry", badgePnl)
    entBadgeRole:SetPos(16, 150) entBadgeRole:SetSize(250, 26)

    local lblB5 = vgui.Create("DLabel", badgePnl)
    lblB5:SetPos(280, 130) lblB5:SetText("Подразделение / Отдел (ручное):") lblB5:SetTextColor(CC.text) lblB5:SizeToContents()
    local entBadgeDept = vgui.Create("DTextEntry", badgePnl)
    entBadgeDept:SetPos(280, 150) entBadgeDept:SetSize(250, 26)

    local lblB6 = vgui.Create("DLabel", badgePnl)
    lblB6:SetPos(545, 130) lblB6:SetText("Номер жетона (с префиксом):") lblB6:SetTextColor(CC.text) lblB6:SizeToContents()
    local entBadgeNum = vgui.Create("DTextEntry", badgePnl)
    entBadgeNum:SetPos(545, 150) entBadgeNum:SetSize(160, 26)

    local lblPerms = vgui.Create("DLabel", badgePnl)
    lblPerms:SetPos(16, 190) lblPerms:SetText("Специальные служебные допуски:") lblPerms:SetFont("DermaDefaultBold") lblPerms:SetTextColor(CC.gold) lblPerms:SizeToContents()

    local chkBoxes = {}
    local yPos = 215
    local xPos = 16

    for i, pDef in ipairs(GRM.Documents.PermissionsList or {}) do
        local chk = vgui.Create("DCheckBoxLabel", badgePnl)
        chk:SetPos(xPos, yPos)
        chk:SetText(pDef.title)
        chk:SetTextColor(CC.text)
        chk:SetValue(true)
        chk:SizeToContents()
        chkBoxes[pDef.id] = chk

        if i % 2 == 1 then
            xPos = 380
        else
            xPos = 16
            yPos = yPos + 24
        end
    end

    local selectedBadgeKey = ""
    local selectedBadgeSid64 = "0"

    comboBadgeTarget.OnSelect = function(_, _, _, pData)
        if istable(pData) then
            selectedBadgeKey = pData.key or ""
            selectedBadgeSid64 = pData.steamID64 or "0"
            entBadgeName:SetText(pData.rpName or "")
            entBadgeFac:SetText(pData.faction or myFaction or "")
            entBadgeRole:SetText(pData.role or "Сотрудник")

            local facTpl = (tpls.factions and tpls.factions[pData.faction]) or {}
            local pfx = facTpl.prefix or (pData.faction and (pData.faction:sub(1, 3):upper() .. "-") or "ОРД-")
            entBadgeNum:SetText(pfx .. selectedBadgeSid64:sub(-4))

            local currentDept = pData.department
            if currentDept == "Основной" or currentDept == "—" or not currentDept then currentDept = "" end

            if registry.badges and registry.badges[selectedBadgeKey] then
                local ex = registry.badges[selectedBadgeKey]
                entBadgeName:SetText(ex.fullName or pData.rpName or "")
                entBadgeFac:SetText(ex.faction or pData.faction or "")
                entBadgeRole:SetText(ex.role or pData.role or "")
                if ex.department and ex.department ~= "" and ex.department ~= "Основной" and ex.department ~= "—" then
                    currentDept = ex.department
                end
                entBadgeNum:SetText(ex.number or (pfx .. selectedBadgeSid64:sub(-4)))
                if istable(ex.permissions) then
                    for pId, cb in pairs(chkBoxes) do
                        cb:SetValue(ex.permissions[pId] == true)
                    end
                end
            end

            if currentDept == "" then currentDept = "Главное Управление" end
            entBadgeDept:SetText(currentDept)
        end
    end

    local btnIssueBadge = vgui.Create("DButton", badgePnl)
    btnIssueBadge:SetPos(16, yPos + 36)
    btnIssueBadge:SetSize(320, 36)
    btnIssueBadge:SetText("✔ Выдать служебное удостоверение")
    btnIssueBadge:SetFont("DermaDefaultBold")
    btnIssueBadge:SetTextColor(color_white)
    btnIssueBadge.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and CC.success or Color(35, 140, 75))
    end
    btnIssueBadge.DoClick = function()
        if selectedBadgeKey == "" then
            notification.AddLegacy("Выберите сотрудника из списка!", NOTIFY_ERROR, 3)
            return
        end

        local curPerms = {}
        for pId, cb in pairs(chkBoxes) do
            curPerms[pId] = cb:GetChecked()
        end

        local chosenDept = string.Trim(entBadgeDept:GetText())
        if chosenDept == "" or chosenDept == "Основной" or chosenDept == "—" then
            chosenDept = "Главное Управление"
        end

        local pack = {
            fullName    = entBadgeName:GetText(),
            faction     = entBadgeFac:GetText(),
            role        = entBadgeRole:GetText(),
            department  = chosenDept,
            number      = entBadgeNum:GetText(),
            permissions = curPerms,
            issuedBy    = "Руководство ведомства " .. entBadgeFac:GetText(),
            issueDate   = os.date("%d.%m.%Y"),
            validUntil  = "Бессрочно",
            status      = "Действителен",
            steamID64   = selectedBadgeSid64,
            isCover     = false,
        }

        net.Start("GRM_Doc_ComputerIssue")
            net.WriteString("badge")
            net.WriteString(selectedBadgeKey)
            net.WriteTable(pack)
        net.SendToServer()
        frame:Close()
    end

    tabs:AddSheet("Отдел кадров / Удостоверения", badgePnl, "icon16/shield.png")

    -- ══════════════════════════════════════════════════════════════
    -- ВКЛАДКА 3: ВОЕНКОМАТ / ВОЕННЫЙ БИЛЕТ
    -- ══════════════════════════════════════════════════════════════
    local milPnl = vgui.Create("DPanel", tabs)
    milPnl:DockPadding(16, 16, 16, 16)
    milPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, CC.panel) end

    local lblMilTarget = vgui.Create("DLabel", milPnl)
    lblMilTarget:SetPos(16, 16) lblMilTarget:SetText("Выберите военнообязанного гражданина:") lblMilTarget:SetFont("DermaDefaultBold") lblMilTarget:SetTextColor(Color(120, 220, 140)) lblMilTarget:SizeToContents()

    local comboMilTarget = vgui.Create("DComboBox", milPnl)
    comboMilTarget:SetPos(16, 36) comboMilTarget:SetSize(420, 28)
    comboMilTarget:AddChoice("— Выберите гражданина онлайн —", "")

    for _, pData in ipairs(onlineList) do
        local label = string.format("%s  [%s]  (%s)", pData.rpName or "?", pData.nick or "?", pData.key or "")
        comboMilTarget:AddChoice(label, pData)
    end

    local lblMName = vgui.Create("DLabel", milPnl)
    lblMName:SetPos(16, 75) lblMName:SetText("ФИО военнослужащего (ручное):") lblMName:SetTextColor(CC.text) lblMName:SizeToContents()
    local entMilName = vgui.Create("DTextEntry", milPnl)
    entMilName:SetPos(16, 95) entMilName:SetSize(280, 26)

    local lblMRank = vgui.Create("DLabel", milPnl)
    lblMRank:SetPos(310, 75) lblMRank:SetText("Воинское звание (выбор / ручной ввод):") lblMRank:SetTextColor(CC.text) lblMRank:SizeToContents()
    local comboMilRank = vgui.Create("DComboBox", milPnl)
    comboMilRank:SetPos(310, 95) comboMilRank:SetSize(220, 26)
    for _, r in ipairs(GRM.Documents.MilitaryRanks or {}) do comboMilRank:AddChoice(r) end
    comboMilRank:SetValue("Рядовой")

    local entMilRankCustom = vgui.Create("DTextEntry", milPnl)
    entMilRankCustom:SetPos(540, 95) entMilRankCustom:SetSize(180, 26) entMilRankCustom:SetPlaceholderText("или своё звание")

    local lblMVUS = vgui.Create("DLabel", milPnl)
    lblMVUS:SetPos(16, 130) lblMVUS:SetText("Военно-учётная специальность (ВУС):") lblMVUS:SetTextColor(CC.text) lblMVUS:SizeToContents()
    local comboMilVUS = vgui.Create("DComboBox", milPnl)
    comboMilVUS:SetPos(16, 150) comboMilVUS:SetSize(320, 26)
    for _, vus in ipairs(GRM.Documents.MilitaryVUS or {}) do comboMilVUS:AddChoice(vus) end
    comboMilVUS:SetValue("ВУС-100 (Стрелковая подготовка)")

    local entMilVUSCustom = vgui.Create("DTextEntry", milPnl)
    entMilVUSCustom:SetPos(345, 150) entMilVUSCustom:SetSize(200, 26) entMilVUSCustom:SetPlaceholderText("или свой ВУС")

    local lblMFac = vgui.Create("DLabel", milPnl)
    lblMFac:SetPos(16, 185) lblMFac:SetText("Воинское формирование / Часть (выбор / ввод):") lblMFac:SetTextColor(CC.text) lblMFac:SizeToContents()
    local comboMilFac = vgui.Create("DComboBox", milPnl)
    comboMilFac:SetPos(16, 205) comboMilFac:SetSize(260, 26)
    for fname in pairs(Factions or FactionsData or {}) do if isstring(fname) then comboMilFac:AddChoice(fname) end end
    comboMilFac:SetValue("Вооружённые силы")

    local entMilFacCustom = vgui.Create("DTextEntry", milPnl)
    entMilFacCustom:SetPos(285, 205) entMilFacCustom:SetSize(240, 26) entMilFacCustom:SetText("Войсковая часть №4289")

    local lblMDept = vgui.Create("DLabel", milPnl)
    lblMDept:SetPos(16, 240) lblMDept:SetText("Подразделение / Отдел (выбор / ввод):") lblMDept:SetTextColor(CC.text) lblMDept:SizeToContents()
    local entMilDept = vgui.Create("DTextEntry", milPnl)
    entMilDept:SetPos(16, 260) entMilDept:SetSize(260, 26) entMilDept:SetText("Штаб")

    local lblMPos = vgui.Create("DLabel", milPnl)
    lblMPos:SetPos(285, 240) lblMPos:SetText("Занимаемая должность (ручной ввод):") lblMPos:SetTextColor(CC.text) lblMPos:SizeToContents()
    local entMilPos = vgui.Create("DTextEntry", milPnl)
    entMilPos:SetPos(285, 260) entMilPos:SetSize(240, 26) entMilPos:SetText("Старший стрелок")

    local lblMNum = vgui.Create("DLabel", milPnl)
    lblMNum:SetPos(540, 185) lblMNum:SetText("Военный билет №:") lblMNum:SetTextColor(CC.text) lblMNum:SizeToContents()
    local entMilNum = vgui.Create("DTextEntry", milPnl)
    entMilNum:SetPos(540, 205) entMilNum:SetSize(180, 26) entMilNum:SetText("ВБ-428901")

    local lblMFit = vgui.Create("DLabel", milPnl)
    lblMFit:SetPos(540, 240) lblMFit:SetText("Категория годности:") lblMFit:SetTextColor(CC.text) lblMFit:SizeToContents()
    local comboMilFit = vgui.Create("DComboBox", milPnl)
    comboMilFit:SetPos(540, 260) comboMilFit:SetSize(200, 26)
    if GRM.Medical and GRM.Medical.FitnessCategories then
        for _, fit in ipairs(GRM.Medical.FitnessCategories) do comboMilFit:AddChoice(fit) end
    else
        comboMilFit:AddChoice("А — Годен к военной службе")
        comboMilFit:AddChoice("Б — Годен с ограничениями")
        comboMilFit:AddChoice("В — Ограниченно годен")
        comboMilFit:AddChoice("Д — Не годен к службе")
    end
    comboMilFit:SetValue("А — Годен к военной службе")

    local selMilKey = ""
    local selMilSid64 = "0"
    comboMilTarget.OnSelect = function(_, _, _, pData)
        if istable(pData) then
            selMilKey = pData.key or ""
            selMilSid64 = pData.steamID64 or "0"
            entMilName:SetText(pData.rpName or "")

            local pfx = (tpls.military and tpls.military.defaultPrefix) or "ВБ-"
            entMilNum:SetText(pfx .. selMilSid64:sub(-5))

            if registry.military and registry.military[selMilKey] then
                local ex = registry.military[selMilKey]
                entMilName:SetText(ex.fullName or pData.rpName or "")
                entMilNum:SetText(ex.number or (pfx .. selMilSid64:sub(-5)))
                entMilRankCustom:SetText(ex.rank or "Рядовой")
                entMilVUSCustom:SetText(ex.vus or "ВУС-100")
                entMilFacCustom:SetText(ex.formation or "Вооружённые силы")
                entMilDept:SetText(ex.department or "Штаб")
                entMilPos:SetText(ex.position or "Стрелок")
                comboMilFit:SetValue(ex.fitness or "А — Годен к службе")
            end
        end
    end

    local btnIssueMil = vgui.Create("DButton", milPnl)
    btnIssueMil:SetPos(16, 320)
    btnIssueMil:SetSize(340, 36)
    btnIssueMil:SetText("✔ Оформить и выдать военный билет")
    btnIssueMil:SetFont("DermaDefaultBold")
    btnIssueMil:SetTextColor(color_white)
    btnIssueMil.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(40, 160, 80) or Color(35, 130, 65))
    end
    btnIssueMil.DoClick = function()
        if not hasMilitary then
            notification.AddLegacy("У вашей фракции нет допуска к выдаче военных билетов!", NOTIFY_ERROR, 3)
            return
        end
        if selMilKey == "" then
            notification.AddLegacy("Выберите военнообязанного из списка!", NOTIFY_ERROR, 3)
            return
        end

        local rankChosen = entMilRankCustom:GetText() ~= "" and entMilRankCustom:GetText() or comboMilRank:GetValue()
        local vusChosen  = entMilVUSCustom:GetText() ~= "" and entMilVUSCustom:GetText() or comboMilVUS:GetValue()
        local facChosen  = entMilFacCustom:GetText() ~= "" and entMilFacCustom:GetText() or comboMilFac:GetValue()

        local pack = {
            fullName    = entMilName:GetText(),
            rank        = rankChosen,
            vus         = vusChosen,
            formation   = facChosen,
            department  = entMilDept:GetText() ~= "" and entMilDept:GetText() or "Штаб",
            position    = entMilPos:GetText() ~= "" and entMilPos:GetText() or "Военнослужащий",
            number      = entMilNum:GetText(),
            fitness     = comboMilFit:GetValue(),
            issuedBy    = (tpls.military and tpls.military.defaultIssuer) or "Военный комиссариат",
            issueDate   = os.date("%d.%m.%Y"),
            status      = "Действителен",
            steamID64   = selMilSid64,
        }

        net.Start("GRM_Doc_ComputerIssue")
            net.WriteString("military")
            net.WriteString(selMilKey)
            net.WriteTable(pack)
        net.SendToServer()
        frame:Close()
    end

    tabs:AddSheet("Военкомат / Военный билет", milPnl, "icon16/book_open.png")

    -- ══════════════════════════════════════════════════════════════
    -- ВКЛАДКА 4: ДОКУМЕНТЫ ПРИКРЫТИЯ (Спецслужбы)
    -- ══════════════════════════════════════════════════════════════
    if hasCover or isSuperAdmin then
        local coverPnl = vgui.Create("DPanel", tabs)
        coverPnl:DockPadding(16, 16, 16, 16)
        coverPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, CC.panel) end

        local lblCInfo = vgui.Create("DLabel", coverPnl)
        lblCInfo:SetPos(16, 10)
        lblCInfo:SetText("ОПЕРАТИВНОЕ ЛЕГЕНДИРОВАНИЕ: Фабрикация удостоверений любых ведомств")
        lblCInfo:SetFont("DermaDefaultBold")
        lblCInfo:SetTextColor(Color(240, 140, 60))
        lblCInfo:SizeToContents()

        local lblCTarget = vgui.Create("DLabel", coverPnl)
        lblCTarget:SetPos(16, 36) lblCTarget:SetText("Оперативный сотрудник (агент):") lblCTarget:SetTextColor(CC.text) lblCTarget:SizeToContents()
        local comboCoverTarget = vgui.Create("DComboBox", coverPnl)
        comboCoverTarget:SetPos(16, 56) comboCoverTarget:SetSize(380, 26)

        for _, pData in ipairs(onlineList) do
            local label = string.format("%s  [%s]  (%s)", pData.rpName or "?", pData.nick or "?", pData.key or "")
            comboCoverTarget:AddChoice(label, pData)
        end

        local lblCFac = vgui.Create("DLabel", coverPnl)
        lblCFac:SetPos(410, 36) lblCFac:SetText("Организация прикрытия:") lblCFac:SetTextColor(CC.text) lblCFac:SizeToContents()
        local comboCoverFac = vgui.Create("DComboBox", coverPnl)
        comboCoverFac:SetPos(410, 56) comboCoverFac:SetSize(340, 26)

        for fname in pairs(Factions or FactionsData or {}) do
            if isstring(fname) then comboCoverFac:AddChoice(fname) end
        end

        local lblCName = vgui.Create("DLabel", coverPnl)
        lblCName:SetPos(16, 90) lblCName:SetText("Легендированное ФИО (ручное):") lblCName:SetTextColor(CC.text) lblCName:SizeToContents()
        local entCoverName = vgui.Create("DTextEntry", coverPnl)
        entCoverName:SetPos(16, 110) entCoverName:SetSize(280, 26)

        local lblCRole = vgui.Create("DLabel", coverPnl)
        lblCRole:SetPos(310, 90) lblCRole:SetText("Должность / Звание:") lblCRole:SetTextColor(CC.text) lblCRole:SizeToContents()
        local entCoverRole = vgui.Create("DTextEntry", coverPnl)
        entCoverRole:SetPos(310, 110) entCoverRole:SetSize(220, 26) entCoverRole:SetText("Специальный инспектор")

        local lblCDept = vgui.Create("DLabel", coverPnl)
        lblCDept:SetPos(545, 90) lblCDept:SetText("Подразделение / Отдел:") lblCDept:SetTextColor(CC.text) lblCDept:SizeToContents()
        local entCoverDept = vgui.Create("DTextEntry", coverPnl)
        entCoverDept:SetPos(545, 110) entCoverDept:SetSize(200, 26) entCoverDept:SetText("Главное Управление")

        local lblCNum = vgui.Create("DLabel", coverPnl)
        lblCNum:SetPos(16, 144) lblCNum:SetText("Номер жетона (с префиксом):") lblCNum:SetTextColor(CC.text) lblCNum:SizeToContents()
        local entCoverNum = vgui.Create("DTextEntry", coverPnl)
        entCoverNum:SetPos(16, 164) entCoverNum:SetSize(180, 26) entCoverNum:SetText("ОРД-7701")

        local lblCIssuer = vgui.Create("DLabel", coverPnl)
        lblCIssuer:SetPos(210, 144) lblCIssuer:SetText("Кем выдано / подпись:") lblCIssuer:SetTextColor(CC.text) lblCIssuer:SizeToContents()
        local entCoverIssuer = vgui.Create("DTextEntry", coverPnl)
        entCoverIssuer:SetPos(210, 164) entCoverIssuer:SetSize(320, 26) entCoverIssuer:SetText("Руководство ведомства")

        local lblCValid = vgui.Create("DLabel", coverPnl)
        lblCValid:SetPos(545, 144) lblCValid:SetText("Срок действия:") lblCValid:SetTextColor(CC.text) lblCValid:SizeToContents()
        local entCoverValid = vgui.Create("DTextEntry", coverPnl)
        entCoverValid:SetPos(545, 164) entCoverValid:SetSize(200, 26) entCoverValid:SetText("Бессрочно")

        local lblCPerms = vgui.Create("DLabel", coverPnl)
        lblCPerms:SetPos(16, 200) lblCPerms:SetText("Специальные допуски в легендированной ксиве:") lblCPerms:SetFont("DermaDefaultBold") lblCPerms:SetTextColor(CC.gold) lblCPerms:SizeToContents()

        local chkCoverBoxes = {}
        local yCover = 222
        local xCover = 16

        for i, pDef in ipairs(GRM.Documents.PermissionsList or {}) do
            local chk = vgui.Create("DCheckBoxLabel", coverPnl)
            chk:SetPos(xCover, yCover)
            chk:SetText(pDef.title)
            chk:SetTextColor(CC.text)
            chk:SetValue(true)
            chk:SizeToContents()
            chkCoverBoxes[pDef.id] = chk

            if i % 2 == 1 then
                xCover = 380
            else
                xCover = 16
                yCover = yCover + 24
            end
        end

        local selCovKey = ""
        local selCovSid64 = "0"
        comboCoverTarget.OnSelect = function(_, _, _, pData)
            if istable(pData) then
                selCovKey = pData.key or ""
                selCovSid64 = pData.steamID64 or "0"
                entCoverName:SetText(pData.rpName or "")
            end
        end

        comboCoverFac.OnSelect = function(_, _, fname)
            local facTpl = (tpls.factions and tpls.factions[fname]) or {}
            local pfx = facTpl.prefix or (fname:sub(1, 3):upper() .. "-")
            entCoverNum:SetText(pfx .. "00" .. math.random(10, 99))
            entCoverIssuer:SetText("Руководство ведомства " .. fname)
        end

        local btnIssueCover = vgui.Create("DButton", coverPnl)
        btnIssueCover:SetPos(16, yCover + 28)
        btnIssueCover:SetSize(380, 36)
        btnIssueCover:SetText("🎭 Оформить и выдать удостоверение прикрытия")
        btnIssueCover:SetFont("DermaDefaultBold")
        btnIssueCover:SetTextColor(color_white)
        btnIssueCover.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(210, 120, 40) or Color(180, 90, 30))
        end
        btnIssueCover.DoClick = function()
            if selCovKey == "" then
                notification.AddLegacy("Выберите сотрудника!", NOTIFY_ERROR, 3)
                return
            end
            local chosenFac = comboCoverFac:GetValue()
            if not chosenFac or chosenFac == "" then
                notification.AddLegacy("Выберите организацию прикрытия!", NOTIFY_ERROR, 3)
                return
            end

            local curPerms = {}
            for pId, cb in pairs(chkCoverBoxes) do
                curPerms[pId] = cb:GetChecked()
            end

            local pack = {
                fullName    = entCoverName:GetText(),
                faction     = chosenFac,
                role        = entCoverRole:GetText(),
                department  = entCoverDept:GetText() ~= "" and entCoverDept:GetText() or "Главное Управление",
                number      = entCoverNum:GetText(),
                permissions = curPerms,
                issuedBy    = entCoverIssuer:GetText(),
                issueDate   = os.date("%d.%m.%Y"),
                validUntil  = entCoverValid:GetText(),
                status      = "Действителен",
                steamID64   = selCovSid64,
                isCover     = true,
            }

            net.Start("GRM_Doc_ComputerIssue")
                net.WriteString("badge")
                net.WriteString(selCovKey)
                net.WriteTable(pack)
            net.SendToServer()
            frame:Close()
        end

        tabs:AddSheet("Документы прикрытия", coverPnl, "icon16/user_suit.png")
    end

    -- ══════════════════════════════════════════════════════════════
    -- ВКЛАДКА 5: РЕЕСТР ВЫДАННЫХ ДОКУМЕНТОВ
    -- ══════════════════════════════════════════════════════════════
    local regPnl = vgui.Create("DPanel", tabs)
    regPnl:DockPadding(10, 10, 10, 10)
    regPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, CC.panel) end

    local listDocs = vgui.Create("DListView", regPnl)
    listDocs:Dock(FILL)
    listDocs:SetMultiSelect(false)
    listDocs:AddColumn("Тип"):SetFixedWidth(100)
    listDocs:AddColumn("ФИО гражданина / сотрудника"):SetFixedWidth(200)
    listDocs:AddColumn("Номер / Серия"):SetFixedWidth(120)
    listDocs:AddColumn("Организация / Формирование"):SetFixedWidth(180)
    listDocs:AddColumn("Статус"):SetFixedWidth(110)
    listDocs:AddColumn("CharacterKey")

    local function populateRegistry()
        listDocs:Clear()
        for k, p in pairs(registry.passports or {}) do
            if istable(p) then
                local line = listDocs:AddLine("Паспорт", p.fullName or "?", (p.series or "GRM") .. " №" .. (p.number or "?"), "Гражданский", p.status or "Действителен", k)
                line._docType = "passport"
                line._docKey = k
            end
        end
        for k, b in pairs(registry.badges or {}) do
            if istable(b) then
                local line = listDocs:AddLine("Удостоверение", b.fullName or "?", b.number or "?", b.faction or "—", b.status or "Действителен", k)
                line._docType = "badge"
                line._docKey = k
            end
        end
        for k, m in pairs(registry.military or {}) do
            if istable(m) then
                local line = listDocs:AddLine("Военный билет", m.fullName or "?", m.number or "?", m.formation or "ВС", m.status or "Действителен", k)
                line._docType = "military"
                line._docKey = k
            end
        end
        for k, c in pairs(registry.coverBadges or {}) do
            if istable(c) then
                local line = listDocs:AddLine("Прикрытие", c.fullName or "?", c.number or "?", c.faction or "—", c.status or "Действителен", k)
                line._docType = "cover"
                line._docKey = k
            end
        end
    end
    populateRegistry()

    local btnRevoke = vgui.Create("DButton", regPnl)
    btnRevoke:Dock(BOTTOM)
    btnRevoke:DockMargin(0, 8, 0, 0)
    btnRevoke:SetTall(32)
    btnRevoke:SetText("✕ Аннулировать / Изъять выбранный документ")
    btnRevoke:SetFont("DermaDefaultBold")
    btnRevoke:SetTextColor(color_white)
    btnRevoke.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and CC.danger or Color(160, 45, 45))
    end
    btnRevoke.DoClick = function()
        local line = listDocs:GetSelectedLine()
        if not line then
            notification.AddLegacy("Выберите документ из таблицы!", NOTIFY_ERROR, 3)
            return
        end
        local row = listDocs:GetLine(line)
        if row and row._docType and row._docKey then
            net.Start("GRM_Doc_ComputerRevoke")
                net.WriteString(row._docType)
                net.WriteString(row._docKey)
            net.SendToServer()
            row:SetColumnText(5, "Аннулирован")
        end
    end

    tabs:AddSheet("Реестр и архив", regPnl, "icon16/folder_table.png")

    -- ══════════════════════════════════════════════════════════════
    -- ВКЛАДКА 6: НАСТРОЙКА КОРОЧКИ ВЕДОМСТВА (Лидер / Админ)
    -- ══════════════════════════════════════════════════════════════
    if isLeader or isSuperAdmin then
        local customPnl = vgui.Create("DPanel", tabs)
        customPnl:DockPadding(16, 16, 16, 16)
        customPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, CC.panel) end

        local targetFactionName = myFaction ~= "" and myFaction or "OrdnungPolizei"

        local lblC1 = vgui.Create("DLabel", customPnl)
        lblC1:SetPos(16, 16) lblC1:SetText("Настройка служебного удостоверения ведомства: " .. targetFactionName) lblC1:SetFont("DermaDefaultBold") lblC1:SetTextColor(CC.accent) lblC1:SizeToContents()

        local entCoverTitle = vgui.Create("DTextEntry", customPnl)
        entCoverTitle:SetPos(16, 60) entCoverTitle:SetSize(350, 26)

        local lblC2 = vgui.Create("DLabel", customPnl)
        lblC2:SetPos(16, 40) lblC2:SetText("Название ведомства на обложке (тиснение):") lblC2:SetTextColor(CC.text) lblC2:SizeToContents()

        local lblC3 = vgui.Create("DLabel", customPnl)
        lblC3:SetPos(16, 100) lblC3:SetText("Служебный префикс жетона (задаётся лидером):") lblC3:SetTextColor(CC.text) lblC3:SizeToContents()

        local entPfxCustom = vgui.Create("DTextEntry", customPnl)
        entPfxCustom:SetPos(16, 120) entPfxCustom:SetSize(160, 26)

        local lblC4 = vgui.Create("DLabel", customPnl)
        lblC4:SetPos(16, 160) lblC4:SetText("Цвет кожаной корочки:") lblC4:SetTextColor(CC.text) lblC4:SizeToContents()
        local comboCoverCol = vgui.Create("DComboBox", customPnl)
        comboCoverCol:SetPos(16, 180) comboCoverCol:SetSize(250, 26)
        for _, cDef in ipairs(GRM.Documents.CoverColors or {}) do comboCoverCol:AddChoice(cDef.name, cDef) end

        local lblC5 = vgui.Create("DLabel", customPnl)
        lblC5:SetPos(16, 220) lblC5:SetText("Стиль тиснения надписи:") lblC5:SetTextColor(CC.text) lblC5:SizeToContents()
        local comboFoilStyle = vgui.Create("DComboBox", customPnl)
        comboFoilStyle:SetPos(16, 240) comboFoilStyle:SetSize(250, 26)
        for fId, fDef in pairs(GRM.Documents.FoilStyles or {}) do comboFoilStyle:AddChoice(fDef.name, fId) end

        local lblC6 = vgui.Create("DLabel", customPnl)
        lblC6:SetPos(16, 280) lblC6:SetText("Значок металлического жетона:") lblC6:SetTextColor(CC.text) lblC6:SizeToContents()
        local comboBadgeIcon = vgui.Create("DComboBox", customPnl)
        comboBadgeIcon:SetPos(16, 300) comboBadgeIcon:SetSize(250, 26)
        for icId, icName in pairs(GRM.Documents.BadgeIcons or {}) do comboBadgeIcon:AddChoice(icName, icId) end

        local curCfg = (tpls.factions and tpls.factions[targetFactionName]) or {}
        entCoverTitle:SetText(curCfg.coverTitle or targetFactionName)
        entPfxCustom:SetText(curCfg.prefix or (targetFactionName:sub(1, 3):upper() .. "-"))
        comboCoverCol:SetValue("Выбрать цвет")
        comboFoilStyle:SetValue(GRM.Documents.FoilStyles[curCfg.foilStyle or "gold"] and GRM.Documents.FoilStyles[curCfg.foilStyle or "gold"].name or "Золотое тиснение")
        comboBadgeIcon:SetValue(GRM.Documents.BadgeIcons[curCfg.badgeIcon or "star"] or "★ Звезда")

        local btnSaveCustom = vgui.Create("DButton", customPnl)
        btnSaveCustom:SetPos(16, 350)
        btnSaveCustom:SetSize(320, 36)
        btnSaveCustom:SetText("✔ Сохранить настройки корочки")
        btnSaveCustom:SetFont("DermaDefaultBold")
        btnSaveCustom:SetTextColor(color_white)
        btnSaveCustom.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and CC.accent or Color(40, 100, 180))
        end
        btnSaveCustom.DoClick = function()
            tpls.factions = tpls.factions or {}
            local fCfg = tpls.factions[targetFactionName] or {}
            fCfg.coverTitle = entCoverTitle:GetText()
            fCfg.prefix = entPfxCustom:GetText()

            local _, colData = comboCoverCol:GetSelected()
            if istable(colData) and colData.col then
                fCfg.coverColor = { r = colData.col.r, g = colData.col.g, b = colData.col.b }
            end

            local _, foilId = comboFoilStyle:GetSelected()
            if isstring(foilId) then fCfg.foilStyle = foilId end

            local _, iconId = comboBadgeIcon:GetSelected()
            if isstring(iconId) then fCfg.badgeIcon = iconId end

            tpls.factions[targetFactionName] = fCfg

            net.Start("GRM_Doc_AdminSave")
                net.WriteTable(tpls)
            net.SendToServer()
            frame:Close()
        end

        tabs:AddSheet("Оформление корочки", customPnl, "icon16/palette.png")
    end
end)
