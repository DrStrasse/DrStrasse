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
        draw.SimpleText("ОТДЕЛ КАДРОВ И ДОКУМЕНТОВ", "DermaDefaultBold", 0, -25, Color(80, 160, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Служебный Компьютер", "DermaDefault", 0, -5, Color(220, 225, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Нажмите [E] для входа в систему", "DermaDefault", 0, 20, Color(160, 170, 185), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

net.Receive("GRM_DocComp_Open", function()
    local ent          = net.ReadEntity()
    local onlineList   = net.ReadTable() or {}
    local tpls         = net.ReadTable() or {}
    local registry     = net.ReadTable() or { passports = {}, badges = {}, coverBadges = {}, military = {}, licenses = {}, milLicenses = {} }
    local myFaction    = net.ReadString()
    local isSuperAdmin = net.ReadBool()
    local isLeader     = net.ReadBool()
    local hasCover     = net.ReadBool()
    local hasPassport  = net.ReadBool()
    local hasMilitary  = net.ReadBool()
    local hasLicense   = net.ReadBool()
    local hasMilLicense= net.ReadBool()

    local frame = vgui.Create("DFrame")
    frame:SetSize(960, 700)
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

    local lblPName = vgui.Create("DLabel", passPnl)
    lblPName:SetPos(16, 125) lblPName:SetText("1. ФИО гражданина (ручной ввод):") lblPName:SetTextColor(CC.text) lblPName:SizeToContents()
    local entPassName = vgui.Create("DTextEntry", passPnl)
    entPassName:SetPos(16, 145) entPassName:SetSize(320, 26)

    local lblPGender = vgui.Create("DLabel", passPnl)
    lblPGender:SetPos(350, 125) lblPGender:SetText("2. Пол:") lblPGender:SetTextColor(CC.text) lblPGender:SizeToContents()
    local comboPassGender = vgui.Create("DComboBox", passPnl)
    comboPassGender:SetPos(350, 145) comboPassGender:SetSize(120, 26)
    comboPassGender:AddChoice("Мужской")
    comboPassGender:AddChoice("Женский")
    comboPassGender:SetValue("Мужской")

    local lblPBirth = vgui.Create("DLabel", passPnl)
    lblPBirth:SetPos(485, 125) lblPBirth:SetText("3. Дата рождения:") lblPBirth:SetTextColor(CC.text) lblPBirth:SizeToContents()
    local entPassBirth = vgui.Create("DTextEntry", passPnl)
    entPassBirth:SetPos(485, 145) entPassBirth:SetSize(140, 26) entPassBirth:SetText("12.04.1988")

    local lblPNat = vgui.Create("DLabel", passPnl)
    lblPNat:SetPos(16, 185) lblPNat:SetText("4. Гражданство (выбор / ручной ввод):") lblPNat:SetTextColor(CC.text) lblPNat:SizeToContents()
    local comboPassNat = vgui.Create("DComboBox", passPnl)
    comboPassNat:SetPos(16, 205) comboPassNat:SetSize(220, 26)
    comboPassNat:AddChoice("Гражданин Республики")
    comboPassNat:AddChoice("Иностранный гражданин")
    comboPassNat:AddChoice("Лицо без гражданства")
    comboPassNat:AddChoice("Подданный Королевства")
    comboPassNat:SetValue("Гражданин Республики")

    local entPassNat = vgui.Create("DTextEntry", passPnl)
    entPassNat:SetPos(245, 205) entPassNat:SetSize(225, 26)
    entPassNat:SetText("Гражданин Республики")

    comboPassNat.OnSelect = function(_, _, v)
        if v and v ~= "" then entPassNat:SetText(v) end
    end

    local lblPBPlace = vgui.Create("DLabel", passPnl)
    lblPBPlace:SetPos(485, 185) lblPBPlace:SetText("5. Место рождения (город / регион):") lblPBPlace:SetTextColor(CC.text) lblPBPlace:SizeToContents()
    local entPassBPlace = vgui.Create("DTextEntry", passPnl)
    entPassBPlace:SetPos(485, 205) entPassBPlace:SetSize(430, 26)
    entPassBPlace:SetText("г. Приморск, Республика Гранд")

    local lblPSeries = vgui.Create("DLabel", passPnl)
    lblPSeries:SetPos(16, 245) lblPSeries:SetText("6. Серия паспорта:") lblPSeries:SetTextColor(CC.text) lblPSeries:SizeToContents()
    local entPassSeries = vgui.Create("DTextEntry", passPnl)
    entPassSeries:SetPos(16, 265) entPassSeries:SetSize(120, 26) entPassSeries:SetText(tpls.passport and tpls.passport.defaultSeries or "GRM")

    local lblPNum = vgui.Create("DLabel", passPnl)
    lblPNum:SetPos(150, 245) lblPNum:SetText("7. Номер паспорта:") lblPNum:SetTextColor(CC.text) lblPNum:SizeToContents()
    local entPassNum = vgui.Create("DTextEntry", passPnl)
    entPassNum:SetPos(150, 265) entPassNum:SetSize(180, 26) entPassNum:SetText("01428901")

    local lblPIssuer = vgui.Create("DLabel", passPnl)
    lblPIssuer:SetPos(350, 245) lblPIssuer:SetText("8. Орган выдачи:") lblPIssuer:SetTextColor(CC.text) lblPIssuer:SizeToContents()
    local entPassIssuer = vgui.Create("DTextEntry", passPnl)
    entPassIssuer:SetPos(350, 265) entPassIssuer:SetSize(565, 26) entPassIssuer:SetText("Паспортный стол Центрального округа")

    local selectedPassKey = ""
    local selectedPassSid64 = "0"
    comboPassTarget.OnSelect = function(_, _, _, pData)
        if istable(pData) then
            selectedPassKey = pData.key or ""
            selectedPassSid64 = pData.steamID64 or "0"
            entPassName:SetText(pData.rpName or "")

            local shortSid = selectedPassSid64:sub(-6)
            entPassNum:SetText("01" .. shortSid)

            if registry.passports and registry.passports[selectedPassKey] then
                local ex = registry.passports[selectedPassKey]
                entPassName:SetText(ex.fullName or pData.rpName or "")
                entPassBirth:SetText(ex.birthDate or "12.04.1988")
                comboPassGender:SetValue(ex.gender or "Мужской")
                entPassNat:SetText(ex.nationality or "Гражданин Республики")
                entPassBPlace:SetText(ex.birthPlace or "г. Приморск, Республика Гранд")
                entPassSeries:SetText(ex.series or (tpls.passport and tpls.passport.defaultSeries) or "GRM")
                entPassNum:SetText(ex.number or ("01" .. shortSid))
                entPassIssuer:SetText(ex.issuedBy or "Паспортный стол Центрального округа")
            end
        end
    end

    local btnIssuePass = vgui.Create("DButton", passPnl)
    btnIssuePass:SetPos(16, 315)
    btnIssuePass:SetSize(360, 36)
    btnIssuePass:SetText("✔ Оформить и выдать паспорт")
    btnIssuePass:SetFont("DermaDefaultBold")
    btnIssuePass:SetTextColor(color_white)
    btnIssuePass.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and CC.success or Color(35, 140, 75))
    end
    btnIssuePass.DoClick = function()
        if not hasPassport then
            notification.AddLegacy("У вашей фракции нет допуска к выдаче паспортов!", NOTIFY_ERROR, 3)
            return
        end
        if selectedPassKey == "" then
            notification.AddLegacy("Выберите гражданина из списка!", NOTIFY_ERROR, 3)
            return
        end

        local pack = {
            fullName    = entPassName:GetText(),
            gender      = comboPassGender:GetValue(),
            birthDate   = entPassBirth:GetText(),
            nationality = entPassNat:GetText(),
            birthPlace  = entPassBPlace:GetText(),
            series      = entPassSeries:GetText(),
            number      = entPassNum:GetText(),
            issuedBy    = entPassIssuer:GetText(),
            issueDate   = os.date("%d.%m.%Y"),
            validUntil  = "Бессрочно",
            status      = "Действителен",
            steamID64   = selectedPassSid64,
        }

        net.Start("GRM_Doc_ComputerIssue")
            net.WriteString("passport")
            net.WriteString(selectedPassKey)
            net.WriteTable(pack)
        net.SendToServer()
        frame:Close()
    end

    tabs:AddSheet("Паспортный стол", passPnl, "icon16/book.png")

    -- ══════════════════════════════════════════════════════════════
    -- ВКЛАДКА 2: ОТДЕЛ КАДРОВ / СЛУЖЕБНЫЕ УДОСТОВЕРЕНИЯ
    -- ══════════════════════════════════════════════════════════════
    local badgePnl = vgui.Create("DPanel", tabs)
    badgePnl:DockPadding(16, 16, 16, 16)
    badgePnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, CC.panel) end

    local lblBTarget = vgui.Create("DLabel", badgePnl)
    lblBTarget:SetPos(16, 16) lblBTarget:SetText("Выберите сотрудника для оформления удостоверения:") lblBTarget:SetFont("DermaDefaultBold") lblBTarget:SetTextColor(CC.accent) lblBTarget:SizeToContents()

    local comboBadgeTarget = vgui.Create("DComboBox", badgePnl)
    comboBadgeTarget:SetPos(16, 36) comboBadgeTarget:SetSize(420, 28)
    comboBadgeTarget:AddChoice("— Выберите сотрудника онлайн —", "")

    for _, pData in ipairs(onlineList) do
        local label = string.format("%s  [%s]  (%s)  — %s", pData.rpName or "?", pData.nick or "?", pData.key or "", pData.faction or "Без фракции")
        comboBadgeTarget:AddChoice(label, pData)
    end

    local lblBName = vgui.Create("DLabel", badgePnl)
    lblBName:SetPos(16, 75) lblBName:SetText("ФИО сотрудника (ручное):") lblBName:SetTextColor(CC.text) lblBName:SizeToContents()
    local entBadgeName = vgui.Create("DTextEntry", badgePnl)
    entBadgeName:SetPos(16, 95) entBadgeName:SetSize(280, 26)

    local lblBFac = vgui.Create("DLabel", badgePnl)
    lblBFac:SetPos(310, 75) lblBFac:SetText("Организация / Ведомство:") lblBFac:SetTextColor(CC.text) lblBFac:SizeToContents()
    local entBadgeFac = vgui.Create("DTextEntry", badgePnl)
    entBadgeFac:SetPos(310, 95) entBadgeFac:SetSize(200, 26) entBadgeFac:SetText(myFaction)
    entBadgeFac:SetEnabled(isSuperAdmin)

    local lblBRole = vgui.Create("DLabel", badgePnl)
    lblBRole:SetPos(525, 75) lblBRole:SetText("Служебное звание / Должность:") lblBRole:SetTextColor(CC.text) lblBRole:SizeToContents()
    local entBadgeRole = vgui.Create("DTextEntry", badgePnl)
    entBadgeRole:SetPos(525, 95) entBadgeRole:SetSize(180, 26)

    local lblBDept = vgui.Create("DLabel", badgePnl)
    lblBDept:SetPos(16, 135) lblBDept:SetText("Подразделение / Отдел (выбор / ручной ввод):") lblBDept:SetTextColor(CC.text) lblBDept:SizeToContents()

    local comboBadgeDept = vgui.Create("DComboBox", badgePnl)
    comboBadgeDept:SetPos(16, 155) comboBadgeDept:SetSize(240, 26)

    local entBadgeDept = vgui.Create("DTextEntry", badgePnl)
    entBadgeDept:SetPos(265, 155) entBadgeDept:SetSize(245, 26)
    entBadgeDept:SetText("Главное Управление")

    comboBadgeDept.OnSelect = function(_, _, val)
        if val and val ~= "" and val ~= "— Другой отдел (ручной ввод) —" then
            entBadgeDept:SetText(val)
        end
    end

    local lblBNum = vgui.Create("DLabel", badgePnl)
    lblBNum:SetPos(525, 135) lblBNum:SetText("Номер удостоверения / жетона:") lblBNum:SetTextColor(CC.text) lblBNum:SizeToContents()
    local entBadgeNum = vgui.Create("DTextEntry", badgePnl)
    entBadgeNum:SetPos(525, 155) entBadgeNum:SetSize(180, 26) entBadgeNum:SetText("POL-0001")

    local lblBPerms = vgui.Create("DLabel", badgePnl)
    lblBPerms:SetPos(16, 195) lblBPerms:SetText("Служебные допуски и права (чекбоксы):") lblBPerms:SetFont("DermaDefaultBold") lblBPerms:SetTextColor(CC.gold) lblBPerms:SizeToContents()

    local chkBoxes = {}
    local yPos = 218
    local xPos = 16
    for i, pDef in ipairs(GRM.Documents.PermissionsList or {}) do
        local chk = vgui.Create("DCheckBoxLabel", badgePnl)
        chk:SetPos(xPos, yPos)
        chk:SetText(pDef.title .. " (" .. pDef.desc .. ")")
        chk:SetTextColor(CC.text)
        chk:SetValue(true)
        chk:SizeToContents()
        chkBoxes[pDef.id] = chk

        if i % 2 == 1 then
            xPos = 420
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
            entBadgeFac:SetText(pData.faction or myFaction)
            entBadgeRole:SetText(pData.role or "Служащий")

            comboBadgeDept:Clear()
            comboBadgeDept:AddChoice("Главное Управление")
            comboBadgeDept:AddChoice("Штаб и Командование")
            comboBadgeDept:AddChoice("Патрульно-постовая служба")
            comboBadgeDept:AddChoice("Следственный отдел")
            comboBadgeDept:AddChoice("Отдел специального назначения")
            comboBadgeDept:AddChoice("Служба безопасности и надзора")
            comboBadgeDept:AddChoice("— Другой отдел (ручной ввод) —")

            local currentDept = pData.department or ""
            if currentDept == "" or currentDept == "Основной" or currentDept == "—" then
                currentDept = "Главное Управление"
            end

            local shortSid = selectedBadgeSid64:sub(-4)
            local tplFac = (tpls.factions and tpls.factions[pData.faction or myFaction]) or {}
            local pfx = tplFac.prefix or ((pData.faction or myFaction):sub(1, 3):upper() .. "-")
            entBadgeNum:SetText(pfx .. shortSid)

            if registry.badges and registry.badges[selectedBadgeKey] then
                local ex = registry.badges[selectedBadgeKey]
                entBadgeName:SetText(ex.fullName or pData.rpName or "")
                entBadgeRole:SetText(ex.role or pData.role or "")
                if ex.department and ex.department ~= "" and ex.department ~= "Основной" and ex.department ~= "—" then
                    currentDept = ex.department
                end
                entBadgeNum:SetText(ex.number or (pfx .. shortSid))
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
    btnIssueBadge:SetPos(16, yPos + 175)
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
    -- ВКЛАДКА 3: ВОДИТЕЛЬСКИЕ ПРАВА (Автошкола ГАИ и ВАИ)
    -- ══════════════════════════════════════════════════════════════
    local licPnl = vgui.Create("DPanel", tabs)
    licPnl:DockPadding(12, 12, 12, 12)
    licPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, CC.panel) end

    -- Переключатель режима: Гражданские права (ГАИ) / Военные права (ВАИ)
    local isMilLicMode = false

    local btnCivMode = vgui.Create("DButton", licPnl)
    btnCivMode:SetPos(16, 12)
    btnCivMode:SetSize(340, 32)
    btnCivMode:SetText("Дорожная Инспекция ПП (Гражданские права)")
    btnCivMode:SetFont("DermaDefaultBold")
    btnCivMode:SetIcon("icon16/car.png")

    local btnMilMode = vgui.Create("DButton", licPnl)
    btnMilMode:SetPos(366, 12)
    btnMilMode:SetSize(340, 32)
    btnMilMode:SetText("Военная Автоинспекция (ВАИ Полевой Жандармерии)")
    btnMilMode:SetFont("DermaDefaultBold")
    btnMilMode:SetIcon("icon16/shield.png")

    local formContainer = vgui.Create("DPanel", licPnl)
    formContainer:SetPos(16, 52)
    formContainer:SetSize(900, 570)
    formContainer:SetPaintBackground(false)

    local function refreshLicModeButtons()
        btnCivMode.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, not isMilLicMode and Color(35, 110, 190) or Color(45, 52, 65))
            if not isMilLicMode then
                surface.SetDrawColor(100, 180, 255)
                surface.DrawOutlinedRect(0, 0, w, h)
            end
        end
        btnCivMode:SetTextColor(not isMilLicMode and color_white or CC.dim)

        btnMilMode.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, isMilLicMode and Color(45, 120, 55) or Color(45, 52, 65))
            if isMilLicMode then
                surface.SetDrawColor(120, 220, 130)
                surface.DrawOutlinedRect(0, 0, w, h)
            end
        end
        btnMilMode:SetTextColor(isMilLicMode and color_white or CC.dim)
    end

    local function buildCivForm()
        formContainer:Clear()

        local lblTarget = vgui.Create("DLabel", formContainer)
        lblTarget:SetPos(0, 4) lblTarget:SetText("Выберите гражданина для выдачи гражданских прав (ГАИ):") lblTarget:SetFont("DermaDefaultBold") lblTarget:SetTextColor(Color(80, 190, 240)) lblTarget:SizeToContents()

        local comboTarget = vgui.Create("DComboBox", formContainer)
        comboTarget:SetPos(0, 24) comboTarget:SetSize(460, 28)
        comboTarget:AddChoice("— Выберите гражданина онлайн —", "")
        for _, pData in ipairs(onlineList) do
            comboTarget:AddChoice(string.format("%s  [%s]  (%s)", pData.rpName or "?", pData.nick or "?", pData.key or ""), pData)
        end

        -- Быстрые пресеты категорий
        local lblPre = vgui.Create("DLabel", formContainer)
        lblPre:SetPos(480, 4) lblPre:SetText("Быстрые пресеты категорий:") lblPre:SetTextColor(CC.gold) lblPre:SetFont("DermaDefaultBold") lblPre:SizeToContents()

        local pfx = (tpls.license and tpls.license.defaultPrefix) or "ВУ-"
        local selKey = ""
        local selSid64 = "0"

        local lblName = vgui.Create("DLabel", formContainer)
        lblName:SetPos(0, 60) lblName:SetText("ФИО водителя:") lblName:SetTextColor(CC.text) lblName:SizeToContents()
        local entName = vgui.Create("DTextEntry", formContainer)
        entName:SetPos(0, 80) entName:SetSize(320, 26)

        local lblBirth = vgui.Create("DLabel", formContainer)
        lblBirth:SetPos(335, 60) lblBirth:SetText("Дата рождения:") lblBirth:SetTextColor(CC.text) lblBirth:SizeToContents()
        local entBirth = vgui.Create("DTextEntry", formContainer)
        entBirth:SetPos(335, 80) entBirth:SetSize(140, 26) entBirth:SetText("12.04.1988")

        local lblNum = vgui.Create("DLabel", formContainer)
        lblNum:SetPos(490, 60) lblNum:SetText("Номер бланка ВУ:") lblNum:SetTextColor(CC.text) lblNum:SizeToContents()
        local entNum = vgui.Create("DTextEntry", formContainer)
        entNum:SetPos(490, 80) entNum:SetSize(180, 26) entNum:SetText(pfx .. "000000")

        local lblOrg = vgui.Create("DLabel", formContainer)
        lblOrg:SetPos(0, 116) lblOrg:SetText("Орган выдачи прав (выбор / ручной ввод):") lblOrg:SetTextColor(CC.text) lblOrg:SizeToContents()

        local comboOrg = vgui.Create("DComboBox", formContainer)
        comboOrg:SetPos(0, 136) comboOrg:SetSize(280, 26)
        comboOrg:AddChoice("Отдел дорожной полиции и экзаменации")
        comboOrg:AddChoice("Госавтоинспекция (ГАИ / МРЭО)")
        comboOrg:AddChoice("Экзаменационный отдел Автошколы")
        comboOrg:SetValue("Отдел дорожной полиции и экзаменации")

        local entIssuer = vgui.Create("DTextEntry", formContainer)
        entIssuer:SetPos(290, 136) entIssuer:SetSize(380, 26)
        entIssuer:SetText((tpls.license and tpls.license.defaultIssuer) or "Отдел дорожной полиции и экзаменации")

        comboOrg.OnSelect = function(_, _, v) if v and v ~= "" then entIssuer:SetText(v) end end

        local lblCats = vgui.Create("DLabel", formContainer)
        lblCats:SetPos(0, 175) lblCats:SetText("Разрешённые категории транспортных средств:") lblCats:SetFont("DermaDefaultBold") lblCats:SetTextColor(CC.gold) lblCats:SizeToContents()

        local chkCats = {}
        local yCat = 198
        local xCat = 0
        for i, cat in ipairs(GRM.Documents.DriveCategories or {}) do
            local chk = vgui.Create("DCheckBoxLabel", formContainer)
            chk:SetPos(xCat, yCat)
            chk:SetText(cat.icon .. " " .. cat.name .. " (" .. cat.desc .. ")")
            chk:SetTextColor(CC.text)
            chk:SetValue(cat.id == "B")
            chk:SizeToContents()
            chkCats[cat.id] = chk

            if i % 2 == 1 then xCat = 440 else xCat = 0 yCat = yCat + 24 end
        end

        local btnP1 = vgui.Create("DButton", formContainer)
        btnP1:SetPos(480, 24) btnP1:SetSize(110, 28) btnP1:SetText("Кат. B (Легк.)")
        btnP1.DoClick = function() for id, cb in pairs(chkCats) do cb:SetValue(id == "B") end end

        local btnP2 = vgui.Create("DButton", formContainer)
        btnP2:SetPos(596, 24) btnP2:SetSize(120, 28) btnP2:SetText("Кат. B + C (Груз.)")
        btnP2.DoClick = function() for id, cb in pairs(chkCats) do cb:SetValue(id == "B" or id == "C") end end

        local btnP3 = vgui.Create("DButton", formContainer)
        btnP3:SetPos(722, 24) btnP3:SetSize(150, 28) btnP3:SetText("Все категории (A-E+Спец)")
        btnP3.DoClick = function() for _, cb in pairs(chkCats) do cb:SetValue(true) end end

        local lblRestr = vgui.Create("DLabel", formContainer)
        lblRestr:SetPos(0, yCat + 10) lblRestr:SetText("12. Особые отметки / ограничения / стаж:") lblRestr:SetTextColor(CC.text) lblRestr:SizeToContents()
        local entRestr = vgui.Create("DTextEntry", formContainer)
        entRestr:SetPos(0, yCat + 30) entRestr:SetSize(520, 26) entRestr:SetText("Стаж вождения подтверждён")

        comboTarget.OnSelect = function(_, _, _, pData)
            if istable(pData) then
                selKey = pData.key or ""
                selSid64 = pData.steamID64 or "0"
                entName:SetText(pData.rpName or "")
                entNum:SetText(pfx .. selSid64:sub(-5))

                if registry.licenses and registry.licenses[selKey] then
                    local ex = registry.licenses[selKey]
                    entName:SetText(ex.fullName or pData.rpName or "")
                    entBirth:SetText(ex.birthDate or "12.04.1988")
                    entNum:SetText(ex.number or (pfx .. selSid64:sub(-5)))
                    entRestr:SetText(ex.restrictions or "Стаж вождения подтверждён")
                    entIssuer:SetText(ex.issuedBy or ((tpls.license and tpls.license.defaultIssuer) or "Отдел дорожной полиции и экзаменации"))
                    if istable(ex.categories) then
                        for cId, cb in pairs(chkCats) do cb:SetValue(ex.categories[cId] == true) end
                    end
                end
            end
        end

        local btnIssue = vgui.Create("DButton", formContainer)
        btnIssue:SetPos(0, yCat + 75)
        btnIssue:SetSize(360, 36)
        btnIssue:SetText("✔ Оформить и выдать гражданское ВУ (ГАИ)")
        btnIssue:SetFont("DermaDefaultBold")
        btnIssue:SetTextColor(color_white)
        btnIssue.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(35, 150, 180) or Color(25, 120, 150)) end
        btnIssue.DoClick = function()
            if not hasLicense then
                notification.AddLegacy("У вашей фракции нет допуска к выдаче водительских прав!", NOTIFY_ERROR, 3)
                return
            end
            if selKey == "" then
                notification.AddLegacy("Выберите гражданина из списка!", NOTIFY_ERROR, 3)
                return
            end

            local curCats = {}
            local catStrList = {}
            for cId, cb in pairs(chkCats) do
                curCats[cId] = cb:GetChecked()
                if cb:GetChecked() then catStrList[#catStrList + 1] = cId end
            end

            local pack = {
                fullName      = entName:GetText(),
                birthDate     = entBirth:GetText(),
                number        = entNum:GetText(),
                categories    = curCats,
                categoriesStr = table.concat(catStrList, " "),
                restrictions  = entRestr:GetText(),
                issuedBy      = entIssuer:GetText(),
                issueDate     = os.date("%d.%m.%Y"),
                validUntil    = "10 лет",
                status        = "Действительно",
                steamID64     = selSid64,
            }

            net.Start("GRM_Doc_ComputerIssue")
                net.WriteString("license")
                net.WriteString(selKey)
                net.WriteTable(pack)
            net.SendToServer()
            frame:Close()
        end
    end

    local function buildMilForm()
        formContainer:Clear()

        local lblTarget = vgui.Create("DLabel", formContainer)
        lblTarget:SetPos(0, 4) lblTarget:SetText("Выберите военнослужащего для выдачи удостоверения водителя ВАИ:") lblTarget:SetFont("DermaDefaultBold") lblTarget:SetTextColor(Color(120, 220, 140)) lblTarget:SizeToContents()

        local comboTarget = vgui.Create("DComboBox", formContainer)
        comboTarget:SetPos(0, 24) comboTarget:SetSize(460, 28)
        comboTarget:AddChoice("— Выберите военнослужащего онлайн —", "")
        for _, pData in ipairs(onlineList) do
            comboTarget:AddChoice(string.format("%s  [%s]  (%s)  — %s", pData.rpName or "?", pData.nick or "?", pData.key or "", pData.faction or "ВС"), pData)
        end

        -- Быстрые военные пресеты
        local lblPre = vgui.Create("DLabel", formContainer)
        lblPre:SetPos(480, 4) lblPre:SetText("Военные допуски и пресеты:") lblPre:SetTextColor(CC.gold) lblPre:SetFont("DermaDefaultBold") lblPre:SizeToContents()

        local pfx = (tpls.militaryLicense and tpls.militaryLicense.defaultPrefix) or "ВАИ-"
        local selKey = ""
        local selSid64 = "0"

        local lblName = vgui.Create("DLabel", formContainer)
        lblName:SetPos(0, 60) lblName:SetText("ФИО водителя:") lblName:SetTextColor(CC.text) lblName:SizeToContents()
        local entName = vgui.Create("DTextEntry", formContainer)
        entName:SetPos(0, 80) entName:SetSize(250, 26)

        local lblRank = vgui.Create("DLabel", formContainer)
        lblRank:SetPos(260, 60) lblRank:SetText("Воинское звание:") lblRank:SetTextColor(CC.text) lblRank:SizeToContents()
        local comboRank = vgui.Create("DComboBox", formContainer)
        comboRank:SetPos(260, 80) comboRank:SetSize(160, 26)
        for _, r in ipairs(GRM.Documents.MilitaryRanks or {}) do comboRank:AddChoice(r) end
        comboRank:SetValue("Рядовой")

        local lblUnit = vgui.Create("DLabel", formContainer)
        lblUnit:SetPos(430, 60) lblUnit:SetText("Воинская часть / Подразделение:") lblUnit:SetTextColor(CC.text) lblUnit:SizeToContents()
        local entUnit = vgui.Create("DTextEntry", formContainer)
        entUnit:SetPos(430, 80) entUnit:SetSize(190, 26) entUnit:SetText("В/Ч 00000 (Автобат)")

        local lblNum = vgui.Create("DLabel", formContainer)
        lblNum:SetPos(630, 60) lblNum:SetText("Номер бланка ВАИ:") lblNum:SetTextColor(CC.text) lblNum:SizeToContents()
        local entNum = vgui.Create("DTextEntry", formContainer)
        entNum:SetPos(630, 80) entNum:SetSize(150, 26) entNum:SetText(pfx .. "000000")

        local lblVus = vgui.Create("DLabel", formContainer)
        lblVus:SetPos(0, 116) lblVus:SetText("ВУС военного водителя:") lblVus:SetTextColor(CC.text) lblVus:SizeToContents()
        local comboVus = vgui.Create("DComboBox", formContainer)
        comboVus:SetPos(0, 136) comboVus:SetSize(340, 26)
        for _, v in ipairs(GRM.Documents.MilitaryDriverVUS or {}) do comboVus:AddChoice(v) end
        comboVus:SetValue("ВУС-837 (Водитель транспортных средств категории C)")

        local entVusCustom = vgui.Create("DTextEntry", formContainer)
        entVusCustom:SetPos(350, 136) entVusCustom:SetSize(170, 26)
        entVusCustom:SetPlaceholderText("или свой ВУС")

        comboVus.OnSelect = function(_, _, v) if v and v ~= "" then entVusCustom:SetText(v) end end

        local lblOrg = vgui.Create("DLabel", formContainer)
        lblOrg:SetPos(530, 116) lblOrg:SetText("Орган выдачи ВАИ:") lblOrg:SetTextColor(CC.text) lblOrg:SizeToContents()
        local entIssuer = vgui.Create("DTextEntry", formContainer)
        entIssuer:SetPos(530, 136) entIssuer:SetSize(320, 26)
        entIssuer:SetText((tpls.militaryLicense and tpls.militaryLicense.defaultIssuer) or "101-я Военная автомобильная инспекция (ВАИ)")

        local lblCats = vgui.Create("DLabel", formContainer)
        lblCats:SetPos(0, 172) lblCats:SetText("Военные категории транспортных средств (ВАИ):") lblCats:SetFont("DermaDefaultBold") lblCats:SetTextColor(Color(120, 220, 140)) lblCats:SizeToContents()

        local chkCats = {}
        local yCat = 192
        local xCat = 0
        for i, cat in ipairs(GRM.Documents.MilDriveCategories or {}) do
            local chk = vgui.Create("DCheckBoxLabel", formContainer)
            chk:SetPos(xCat, yCat)
            chk:SetText(cat.icon .. " " .. cat.name .. " (" .. cat.desc .. ")")
            chk:SetTextColor(CC.text)
            chk:SetValue(cat.id == "B-В" or cat.id == "C-В")
            chk:SizeToContents()
            chkCats[cat.id] = chk

            if i % 2 == 1 then xCat = 440 else xCat = 0 yCat = yCat + 22 end
        end

        local lblEnd = vgui.Create("DLabel", formContainer)
        lblEnd:SetPos(0, yCat + 8) lblEnd:SetText("Специальные войсковые допуски водителя (Endorsements):") lblEnd:SetFont("DermaDefaultBold") lblEnd:SetTextColor(CC.gold) lblEnd:SizeToContents()

        local chkEnds = {}
        local yEnd = yCat + 28
        local xEnd = 0
        for i, endDef in ipairs(GRM.Documents.MilEndorsements or {}) do
            local chk = vgui.Create("DCheckBoxLabel", formContainer)
            chk:SetPos(xEnd, yEnd)
            chk:SetText(endDef.icon .. " " .. endDef.title .. " (" .. endDef.desc .. ")")
            chk:SetTextColor(CC.text)
            chk:SetValue(endDef.id == "convoy" or endDef.id == "march")
            chk:SizeToContents()
            chkEnds[endDef.id] = chk

            if i % 2 == 1 then xEnd = 440 else xEnd = 0 yEnd = yEnd + 22 end
        end

        local btnP1 = vgui.Create("DButton", formContainer)
        btnP1:SetPos(480, 24) btnP1:SetSize(120, 28) btnP1:SetText("Штабной (B-В)")
        btnP1.DoClick = function()
            for id, cb in pairs(chkCats) do cb:SetValue(id == "B-В") end
            for id, cb in pairs(chkEnds) do cb:SetValue(id == "sirens" or id == "convoy") end
        end

        local btnP2 = vgui.Create("DButton", formContainer)
        btnP2:SetPos(606, 24) btnP2:SetSize(130, 28) btnP2:SetText("Автобат (C-В + Марш)")
        btnP2.DoClick = function()
            for id, cb in pairs(chkCats) do cb:SetValue(id == "B-В" or id == "C-В") end
            for id, cb in pairs(chkEnds) do cb:SetValue(id == "convoy" or id == "march" or id == "passengers") end
        end

        local btnP3 = vgui.Create("DButton", formContainer)
        btnP3:SetPos(742, 24) btnP3:SetSize(140, 28) btnP3:SetText("Полный допуск ВС")
        btnP3.DoClick = function()
            for _, cb in pairs(chkCats) do cb:SetValue(true) end
            for _, cb in pairs(chkEnds) do cb:SetValue(true) end
        end

        local lblRestr = vgui.Create("DLabel", formContainer)
        lblRestr:SetPos(0, yEnd + 8) lblRestr:SetText("12. Особые отметки военной автоинспекции:") lblRestr:SetTextColor(CC.text) lblRestr:SizeToContents()
        local entRestr = vgui.Create("DTextEntry", formContainer)
        entRestr:SetPos(0, yEnd + 26) entRestr:SetSize(520, 26) entRestr:SetText("Норматив вождения сдан. Стажировка пройдена.")

        comboTarget.OnSelect = function(_, _, _, pData)
            if istable(pData) then
                selKey = pData.key or ""
                selSid64 = pData.steamID64 or "0"
                entName:SetText(pData.rpName or "")
                entNum:SetText(pfx .. selSid64:sub(-5))
                entUnit:SetText(pData.faction or "В/Ч 00000 (Автобат)")

                if registry.milLicenses and registry.milLicenses[selKey] then
                    local ex = registry.milLicenses[selKey]
                    entName:SetText(ex.fullName or pData.rpName or "")
                    comboRank:SetValue(ex.rank or "Рядовой")
                    entUnit:SetText(ex.formation or pData.faction or "В/Ч 00000 (Автобат)")
                    entNum:SetText(ex.number or (pfx .. selSid64:sub(-5)))
                    entVusCustom:SetText(ex.vus or "ВУС-837 (Водитель спецтранспорта)")
                    entRestr:SetText(ex.restrictions or ex.specialNotes or "Норматив вождения сдан. Стажировка пройдена.")
                    entIssuer:SetText(ex.issuedBy or ((tpls.militaryLicense and tpls.militaryLicense.defaultIssuer) or "101-я Военная автомобильная инспекция (ВАИ)"))
                    if istable(ex.categories) then
                        for cId, cb in pairs(chkCats) do cb:SetValue(ex.categories[cId] == true) end
                    end
                    if istable(ex.endorsements) then
                        for eId, cb in pairs(chkEnds) do cb:SetValue(ex.endorsements[eId] == true) end
                    end
                end
            end
        end

        local btnIssue = vgui.Create("DButton", formContainer)
        btnIssue:SetPos(0, yEnd + 60)
        btnIssue:SetSize(380, 36)
        btnIssue:SetText("✔ Оформить и выдать удостоверение водителя ВАИ")
        btnIssue:SetFont("DermaDefaultBold")
        btnIssue:SetTextColor(color_white)
        btnIssue.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(45, 145, 65) or Color(35, 115, 50)) end
        btnIssue.DoClick = function()
            if not hasMilLicense then
                notification.AddLegacy("У вашей фракции нет допуска к выдаче военных водительских прав (ВАИ)!", NOTIFY_ERROR, 3)
                return
            end
            if selKey == "" then
                notification.AddLegacy("Выберите военнослужащего из списка!", NOTIFY_ERROR, 3)
                return
            end

            local curCats = {}
            local catStrList = {}
            for cId, cb in pairs(chkCats) do
                curCats[cId] = cb:GetChecked()
                if cb:GetChecked() then catStrList[#catStrList + 1] = cId end
            end

            local curEnds = {}
            for eId, cb in pairs(chkEnds) do
                curEnds[eId] = cb:GetChecked()
            end

            local chosenVus = string.Trim(entVusCustom:GetText())
            if chosenVus == "" then chosenVus = comboVus:GetValue() end

            local pack = {
                fullName      = entName:GetText(),
                rank          = comboRank:GetValue(),
                formation     = entUnit:GetText(),
                vus           = chosenVus,
                number        = entNum:GetText(),
                categories    = curCats,
                categoriesStr = table.concat(catStrList, " "),
                endorsements  = curEnds,
                specialNotes  = entRestr:GetText(),
                restrictions  = entRestr:GetText(),
                issuedBy      = entIssuer:GetText(),
                issueDate     = os.date("%d.%m.%Y"),
                validUntil    = "На срок военной службы",
                status        = "Действительно (на службе)",
                steamID64     = selSid64,
            }

            net.Start("GRM_Doc_ComputerIssue")
                net.WriteString("milLicense")
                net.WriteString(selKey)
                net.WriteTable(pack)
            net.SendToServer()
            frame:Close()
        end
    end

    btnCivMode.DoClick = function()
        isMilLicMode = false
        refreshLicModeButtons()
        buildCivForm()
    end

    btnMilMode.DoClick = function()
        isMilLicMode = true
        refreshLicModeButtons()
        buildMilForm()
    end

    refreshLicModeButtons()
    buildCivForm()

    tabs:AddSheet("Автошкола и ВАИ / Права", licPnl, "icon16/car.png")

    -- ══════════════════════════════════════════════════════════════
    -- ВКЛАДКА 4: ВОЕНКОМАТ / ВОЕННЫЙ БИЛЕТ
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
    lblMVUS:SetPos(16, 135) lblMVUS:SetText("Военно-учётная специальность (ВУС):") lblMVUS:SetTextColor(CC.text) lblMVUS:SizeToContents()
    local comboMilVUS = vgui.Create("DComboBox", milPnl)
    comboMilVUS:SetPos(16, 155) comboMilVUS:SetSize(340, 26)
    for _, v in ipairs(GRM.Documents.MilitaryVUS or {}) do comboMilVUS:AddChoice(v) end
    comboMilVUS:SetValue("ВУС-100 (Стрелковая подготовка)")

    local entMilVUSCustom = vgui.Create("DTextEntry", milPnl)
    entMilVUSCustom:SetPos(365, 155) entMilVUSCustom:SetSize(220, 26) entMilVUSCustom:SetPlaceholderText("или свой ВУС")

    comboMilVUS.OnSelect = function(_, _, v) if v and v ~= "" then entMilVUSCustom:SetText(v) end end

    local lblMForm = vgui.Create("DLabel", milPnl)
    lblMForm:SetPos(600, 135) lblMForm:SetText("Воинское формирование:") lblMForm:SetTextColor(CC.text) lblMForm:SizeToContents()
    local entMilForm = vgui.Create("DTextEntry", milPnl)
    entMilForm:SetPos(600, 155) entMilForm:SetSize(190, 26) entMilForm:SetText("Вооружённые Силы")

    local lblMDept = vgui.Create("DLabel", milPnl)
    lblMDept:SetPos(16, 195) lblMDept:SetText("Подразделение / Рота:") lblMDept:SetTextColor(CC.text) lblMDept:SizeToContents()
    local entMilDept = vgui.Create("DTextEntry", milPnl)
    entMilDept:SetPos(16, 215) entMilDept:SetSize(240, 26) entMilDept:SetText("Штабная рота")

    local lblMPos = vgui.Create("DLabel", milPnl)
    lblMPos:SetPos(270, 195) lblMPos:SetText("Должность:") lblMPos:SetTextColor(CC.text) lblMPos:SizeToContents()
    local entMilPos = vgui.Create("DTextEntry", milPnl)
    entMilPos:SetPos(270, 215) entMilPos:SetSize(240, 26) entMilPos:SetText("Стрелок")

    local lblMFit = vgui.Create("DLabel", milPnl)
    lblMFit:SetPos(525, 195) lblMFit:SetText("Категория годности:") lblMFit:SetTextColor(CC.text) lblMFit:SizeToContents()
    local comboMilFit = vgui.Create("DComboBox", milPnl)
    comboMilFit:SetPos(525, 215) comboMilFit:SetSize(265, 26)
    comboMilFit:AddChoice("А — Годен к военной службе без ограничений")
    comboMilFit:AddChoice("Б — Годен к военной службе с незначительными ограничениями")
    comboMilFit:AddChoice("В — Ограниченно годен к военной службе (запас)")
    comboMilFit:AddChoice("Г — Временно не годен к военной службе (отсрочка)")
    comboMilFit:AddChoice("Д — Не годен к военной службе (освобождён)")
    comboMilFit:SetValue("А — Годен к военной службе без ограничений")

    local lblMNum = vgui.Create("DLabel", milPnl)
    lblMNum:SetPos(16, 255) lblMNum:SetText("Номер военного билета:") lblMNum:SetTextColor(CC.text) lblMNum:SizeToContents()
    local entMilNum = vgui.Create("DTextEntry", milPnl)
    entMilNum:SetPos(16, 275) entMilNum:SetSize(180, 26) entMilNum:SetText("ВБ-014289")

    local lblMIssuer = vgui.Create("DLabel", milPnl)
    lblMIssuer:SetPos(210, 255) lblMIssuer:SetText("Орган выдачи (Военкомат):") lblMIssuer:SetTextColor(CC.text) lblMIssuer:SizeToContents()
    local entMilIssuer = vgui.Create("DTextEntry", milPnl)
    entMilIssuer:SetPos(210, 275) entMilIssuer:SetSize(380, 26) entMilIssuer:SetText((tpls.military and tpls.military.defaultIssuer) or "Военный комиссариат Центрального округа")

    local selectedMilKey = ""
    local selectedMilSid64 = "0"
    comboMilTarget.OnSelect = function(_, _, _, pData)
        if istable(pData) then
            selectedMilKey = pData.key or ""
            selectedMilSid64 = pData.steamID64 or "0"
            entMilName:SetText(pData.rpName or "")

            local shortSid = selectedMilSid64:sub(-5)
            local pfxM = (tpls.military and tpls.military.defaultPrefix) or "ВБ-"
            entMilNum:SetText(pfxM .. shortSid)

            if registry.military and registry.military[selectedMilKey] then
                local ex = registry.military[selectedMilKey]
                entMilName:SetText(ex.fullName or pData.rpName or "")
                comboMilRank:SetValue(ex.rank or "Рядовой")
                entMilVUSCustom:SetText(ex.vus or "ВУС-100 (Стрелковая подготовка)")
                entMilForm:SetText(ex.formation or "Вооружённые Силы")
                entMilDept:SetText(ex.department or "Штабная рота")
                entMilPos:SetText(ex.position or "Стрелок")
                comboMilFit:SetValue(ex.fitness or "А — Годен к военной службе без ограничений")
                entMilNum:SetText(ex.number or (pfxM .. shortSid))
                entMilIssuer:SetText(ex.issuedBy or "Военный комиссариат Центрального округа")
            end
        end
    end

    local btnIssueMil = vgui.Create("DButton", milPnl)
    btnIssueMil:SetPos(16, 325)
    btnIssueMil:SetSize(320, 36)
    btnIssueMil:SetText("✔ Оформить и выдать военный билет")
    btnIssueMil:SetFont("DermaDefaultBold")
    btnIssueMil:SetTextColor(color_white)
    btnIssueMil.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and CC.success or Color(35, 140, 75))
    end
    btnIssueMil.DoClick = function()
        if not hasMilitary then
            notification.AddLegacy("У вашей фракции нет допуска к оформлению военных билетов!", NOTIFY_ERROR, 3)
            return
        end
        if selectedMilKey == "" then
            notification.AddLegacy("Выберите военнообязанного из списка!", NOTIFY_ERROR, 3)
            return
        end

        local chosenRank = string.Trim(entMilRankCustom:GetText())
        if chosenRank == "" then chosenRank = comboMilRank:GetValue() end

        local chosenVus = string.Trim(entMilVUSCustom:GetText())
        if chosenVus == "" then chosenVus = comboMilVUS:GetValue() end

        local pack = {
            fullName    = entMilName:GetText(),
            rank        = chosenRank,
            vus         = chosenVus,
            formation   = entMilForm:GetText(),
            department  = entMilDept:GetText(),
            position    = entMilPos:GetText(),
            fitness     = comboMilFit:GetValue(),
            number      = entMilNum:GetText(),
            issuedBy    = entMilIssuer:GetText(),
            issueDate   = os.date("%d.%m.%Y"),
            validUntil  = "Бессрочно",
            status      = "Действителен (в запасе)",
            steamID64   = selectedMilSid64,
        }

        net.Start("GRM_Doc_ComputerIssue")
            net.WriteString("military")
            net.WriteString(selectedMilKey)
            net.WriteTable(pack)
        net.SendToServer()
        frame:Close()
    end

    tabs:AddSheet("Военкомат / Военный билет", milPnl, "icon16/book_open.png")

    -- ══════════════════════════════════════════════════════════════
    -- ВКЛАДКА 5: ДОКУМЕНТЫ ПРИКРЫТИЯ (Для спецслужб)
    -- ══════════════════════════════════════════════════════════════
    if hasCover then
        local coverPnl = vgui.Create("DPanel", tabs)
        coverPnl:DockPadding(16, 16, 16, 16)
        coverPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, CC.panel) end

        local lblCTarget = vgui.Create("DLabel", coverPnl)
        lblCTarget:SetPos(16, 16) lblCTarget:SetText("Выберите оперативного сотрудника под прикрытием:") lblCTarget:SetFont("DermaDefaultBold") lblCTarget:SetTextColor(CC.accent) lblCTarget:SizeToContents()

        local comboCoverTarget = vgui.Create("DComboBox", coverPnl)
        comboCoverTarget:SetPos(16, 36) comboCoverTarget:SetSize(420, 28)
        comboCoverTarget:AddChoice("— Выберите агента онлайн —", "")

        for _, pData in ipairs(onlineList) do
            local label = string.format("%s  [%s]  (%s)", pData.rpName or "?", pData.nick or "?", pData.key or "")
            comboCoverTarget:AddChoice(label, pData)
        end

        local lblCFac = vgui.Create("DLabel", coverPnl)
        lblCFac:SetPos(16, 75) lblCFac:SetText("Легендированная организация / Ведомство прикрытия:") lblCFac:SetTextColor(CC.text) lblCFac:SizeToContents()

        local comboCoverFac = vgui.Create("DComboBox", coverPnl)
        comboCoverFac:SetPos(16, 95) comboCoverFac:SetSize(280, 26)

        local entCoverFacManual = vgui.Create("DTextEntry", coverPnl)
        entCoverFacManual:SetPos(310, 95) entCoverFacManual:SetSize(240, 26)
        entCoverFacManual:SetPlaceholderText("или ручное название ведомства")

        local fNames = {}
        for fn in pairs(Factions or FactionsData or {}) do if isstring(fn) then fNames[#fNames+1] = fn end end
        table.sort(fNames)
        for _, fn in ipairs(fNames) do comboCoverFac:AddChoice(fn) end

        local lblCName = vgui.Create("DLabel", coverPnl)
        lblCName:SetPos(16, 135) lblCName:SetText("ФИО по легенде:") lblCName:SetTextColor(CC.text) lblCName:SizeToContents()
        local entCoverName = vgui.Create("DTextEntry", coverPnl)
        entCoverName:SetPos(16, 155) entCoverName:SetSize(280, 26)

        local lblCRole = vgui.Create("DLabel", coverPnl)
        lblCRole:SetPos(310, 135) lblCRole:SetText("Легендированная должность:") lblCRole:SetTextColor(CC.text) lblCRole:SizeToContents()
        local entCoverRole = vgui.Create("DTextEntry", coverPnl)
        entCoverRole:SetPos(310, 155) entCoverRole:SetSize(240, 26) entCoverRole:SetText("Инспектор")

        local lblCDept = vgui.Create("DLabel", coverPnl)
        lblCDept:SetPos(16, 195) lblCDept:SetText("Подразделение прикрытия:") lblCDept:SetTextColor(CC.text) lblCDept:SizeToContents()
        local entCoverDept = vgui.Create("DTextEntry", coverPnl)
        entCoverDept:SetPos(16, 215) entCoverDept:SetSize(280, 26) entCoverDept:SetText("Оперативный отдел")

        local lblCNum = vgui.Create("DLabel", coverPnl)
        lblCNum:SetPos(310, 195) lblCNum:SetText("Номер служебного жетона прикрытия:") lblCNum:SetTextColor(CC.text) lblCNum:SizeToContents()
        local entCoverNum = vgui.Create("DTextEntry", coverPnl)
        entCoverNum:SetPos(310, 215) entCoverNum:SetSize(240, 26) entCoverNum:SetText("SEC-0042")

        local lblCPerms = vgui.Create("DLabel", coverPnl)
        lblCPerms:SetPos(16, 255) lblCPerms:SetText("Служебные допуски в фальшивом удостоверении:") lblCPerms:SetFont("DermaDefaultBold") lblCPerms:SetTextColor(CC.gold) lblCPerms:SizeToContents()

        local chkCoverBoxes = {}
        local yCPos = 278
        local xCPos = 16
        for i, pDef in ipairs(GRM.Documents.PermissionsList or {}) do
            local chk = vgui.Create("DCheckBoxLabel", coverPnl)
            chk:SetPos(xCPos, yCPos)
            chk:SetText(pDef.title .. " (" .. pDef.desc .. ")")
            chk:SetTextColor(CC.text)
            chk:SetValue(true)
            chk:SizeToContents()
            chkCoverBoxes[pDef.id] = chk

            if i % 2 == 1 then xCPos = 420 else xCPos = 16 yCPos = yCPos + 24 end
        end

        local selectedCoverKey = ""
        local selectedCoverSid64 = "0"
        comboCoverTarget.OnSelect = function(_, _, _, pData)
            if istable(pData) then
                selectedCoverKey = pData.key or ""
                selectedCoverSid64 = pData.steamID64 or "0"
                entCoverName:SetText(pData.rpName or "")

                if registry.coverBadges and registry.coverBadges[selectedCoverKey] then
                    local ex = registry.coverBadges[selectedCoverKey]
                    entCoverName:SetText(ex.fullName or pData.rpName or "")
                    entCoverRole:SetText(ex.role or "Инспектор")
                    entCoverDept:SetText(ex.department or "Оперативный отдел")
                    entCoverNum:SetText(ex.number or "SEC-0042")
                    entCoverFacManual:SetText(ex.faction or "")
                    comboCoverFac:SetValue(ex.faction or "")
                    if istable(ex.permissions) then
                        for pId, cb in pairs(chkCoverBoxes) do
                            cb:SetValue(ex.permissions[pId] == true)
                        end
                    end
                end
            end
        end

        local btnIssueCover = vgui.Create("DButton", coverPnl)
        btnIssueCover:SetPos(16, yCPos + 20)
        btnIssueCover:SetSize(360, 36)
        btnIssueCover:SetText("✔ Сфабриковать удостоверение прикрытия")
        btnIssueCover:SetFont("DermaDefaultBold")
        btnIssueCover:SetTextColor(color_white)
        btnIssueCover.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(200, 90, 40) or Color(160, 70, 30))
        end
        btnIssueCover.DoClick = function()
            if selectedCoverKey == "" then
                notification.AddLegacy("Выберите сотрудника из списка!", NOTIFY_ERROR, 3)
                return
            end

            local chosenFac = string.Trim(entCoverFacManual:GetText())
            if chosenFac == "" then chosenFac = comboCoverFac:GetValue() end
            if chosenFac == "" then chosenFac = "Служба Государственной Безопасности" end

            local curPerms = {}
            for pId, cb in pairs(chkCoverBoxes) do
                curPerms[pId] = cb:GetChecked()
            end

            local pack = {
                fullName    = entCoverName:GetText(),
                faction     = chosenFac,
                role        = entCoverRole:GetText(),
                department  = entCoverDept:GetText(),
                number      = entCoverNum:GetText(),
                permissions = curPerms,
                issuedBy    = "Руководство ведомства " .. chosenFac,
                issueDate   = os.date("%d.%m.%Y"),
                validUntil  = "Бессрочно",
                status      = "Действителен",
                steamID64   = selectedCoverSid64,
                isCover     = true,
            }

            net.Start("GRM_Doc_ComputerIssue")
                net.WriteString("badge")
                net.WriteString(selectedCoverKey)
                net.WriteTable(pack)
            net.SendToServer()
            frame:Close()
        end

        tabs:AddSheet("Документы прикрытия", coverPnl, "icon16/mask.png")
    end

    -- ══════════════════════════════════════════════════════════════
    -- ВКЛАДКА 6: РЕЕСТР И АРХИВ ВЫДАННЫХ ДОКУМЕНТОВ
    -- ══════════════════════════════════════════════════════════════
    local regPnl = vgui.Create("DPanel", tabs)
    regPnl:DockPadding(10, 10, 10, 10)
    regPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, CC.panel) end

    local listDocs = vgui.Create("DListView", regPnl)
    listDocs:Dock(FILL)
    listDocs:SetMultiSelect(false)
    listDocs:AddColumn("Тип"):SetFixedWidth(110)
    listDocs:AddColumn("Владелец (ФИО)"):SetFixedWidth(200)
    listDocs:AddColumn("Номер бланка"):SetFixedWidth(130)
    listDocs:AddColumn("Орган / Фракция / Категории"):SetFixedWidth(260)
    listDocs:AddColumn("Статус"):SetFixedWidth(140)
    listDocs:AddColumn("Ключ персонажа")

    local function populateRegistry()
        listDocs:Clear()
        for k, p in pairs(registry.passports or {}) do
            if istable(p) then
                local line = listDocs:AddLine("Паспорт", p.fullName or "?", (p.series or "") .. " " .. (p.number or "?"), p.issuedBy or "МВД", p.status or "Действителен", k)
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
        for k, l in pairs(registry.licenses or {}) do
            if istable(l) then
                local line = listDocs:AddLine("Права (ГАИ)", l.fullName or "?", l.number or "?", "Кат: " .. (l.categoriesStr or "B"), l.status or "Действительно", k)
                line._docType = "license"
                line._docKey = k
            end
        end
        for k, ml in pairs(registry.milLicenses or {}) do
            if istable(ml) then
                local line = listDocs:AddLine("Права (ВАИ)", ml.fullName or "?", ml.number or "?", "ВУС: " .. (ml.vus or "837") .. " (Кат: " .. (ml.categoriesStr or "B-В") .. ")", ml.status or "Действительно", k)
                line._docType = "milLicense"
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
    btnRevoke:SetText("✕ Аннулировать / Изъять / Лишить прав выбранный документ")
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
end)
