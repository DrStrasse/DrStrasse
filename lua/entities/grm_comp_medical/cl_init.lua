--[[--------------------------------------------------------------------
    grm_comp_medical — cl_init.lua (Интерфейс Медицинской службы)
----------------------------------------------------------------------]]
include("shared.lua")

local CC = {
    bg      = Color(18, 28, 24, 250),
    panel   = Color(24, 38, 32, 245),
    header  = Color(30, 52, 42, 255),
    accent  = Color(90, 220, 150),
    success = Color(60, 190, 100),
    danger  = Color(220, 70, 70),
    text    = Color(235, 248, 240),
    dim     = Color(155, 185, 170),
    gold    = Color(245, 205, 80),
}

function ENT:Draw()
    self:DrawModel()

    local pos = self:GetPos() + self:GetUp() * 24 + self:GetForward() * 2
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Up(), 90)
    ang:RotateAroundAxis(ang:Forward(), 90)

    cam.Start3D2D(pos, ang, 0.08)
        draw.RoundedBox(6, -150, -50, 300, 100, Color(12, 20, 16, 240))
        draw.SimpleText("МЕДИЦИНСКАЯ СЛУЖБА", "DermaDefaultBold", 0, -25, Color(90, 220, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Госпиталь и Военно-врачебная комиссия", "DermaDefault", 0, -5, Color(225, 245, 235), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Нажмите [E] для входа в систему", "DermaDefault", 0, 20, Color(150, 190, 170), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

net.Receive("GRM_CompMedical_Open", function()
    local ent          = net.ReadEntity()
    local onlineList   = net.ReadTable() or {}
    local medCards     = net.ReadTable() or {}
    local myFaction    = net.ReadString()
    local isSuperAdmin = net.ReadBool()

    local frame = vgui.Create("DFrame")
    frame:SetSize(960, 700)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:ShowCloseButton(false)

    frame.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, CC.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 40, CC.header, true, true, false, false)
        draw.SimpleText("МЕДИЦИНСКАЯ СЛУЖБА • ЭЛЕКТРОННЫЙ ГОСПИТАЛЬ И ВВК", "DermaDefaultBold", 16, 20, CC.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local btnClose = vgui.Create("DButton", frame)
    btnClose:SetSize(28, 24)
    btnClose:SetPos(frame:GetWide() - 36, 8)
    btnClose:SetText("✕")
    btnClose:SetTextColor(CC.dim)
    btnClose.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and CC.danger or Color(45, 60, 50))
        if s:IsHovered() then s:SetTextColor(color_white) else s:SetTextColor(CC.dim) end
    end
    btnClose.DoClick = function() frame:Close() end

    local tabs = vgui.Create("DPropertySheet", frame)
    tabs:Dock(FILL)
    tabs:DockMargin(4, 38, 4, 4)

    -- ══════════════════════════════════════════════════════════════
    -- ВКЛАДКА 1: КАРТОТЕКА ПАЦИЕНТОВ И ЭЛЕКТРОННЫЕ МЕДКАРТЫ
    -- ══════════════════════════════════════════════════════════════
    local medPnl = vgui.Create("DPanel", tabs)
    medPnl:DockPadding(16, 16, 16, 16)
    medPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, CC.panel) end

    local lblTarget = vgui.Create("DLabel", medPnl)
    lblTarget:SetPos(16, 14) lblTarget:SetText("Выберите пациента для ведения медицинской карты:") lblTarget:SetFont("DermaDefaultBold") lblTarget:SetTextColor(CC.accent) lblTarget:SizeToContents()

    local comboTarget = vgui.Create("DComboBox", medPnl)
    comboTarget:SetPos(16, 34) comboTarget:SetSize(420, 28)
    comboTarget:AddChoice("— Выберите пациента онлайн —", "")
    for _, pData in ipairs(onlineList) do
        comboTarget:AddChoice(string.format("%s  [%s]", pData.rpName or "?", pData.nick or "?"), pData)
    end

    local entName = vgui.Create("DTextEntry", medPnl) entName:SetPos(16, 95) entName:SetSize(280, 26)
    local comboBlood = vgui.Create("DComboBox", medPnl) comboBlood:SetPos(310, 95) comboBlood:SetSize(160, 26)
    comboBlood:AddChoice("I (0) Rh+") comboBlood:AddChoice("I (0) Rh-")
    comboBlood:AddChoice("II (A) Rh+") comboBlood:AddChoice("II (A) Rh-")
    comboBlood:AddChoice("III (B) Rh+") comboBlood:AddChoice("III (B) Rh-")
    comboBlood:AddChoice("IV (AB) Rh+") comboBlood:AddChoice("IV (AB) Rh-")
    comboBlood:SetValue("I (0) Rh+")

    local comboFit = vgui.Create("DComboBox", medPnl) comboFit:SetPos(485, 95) comboFit:SetSize(320, 26)
    comboFit:AddChoice("А — Годен к военной службе и работе без ограничений")
    comboFit:AddChoice("Б — Годен к военной службе с незначительными ограничениями")
    comboFit:AddChoice("В — Ограниченно годен к службе (запас)")
    comboFit:AddChoice("Г — Временно не годен (отсрочка на лечение)")
    comboFit:AddChoice("Д — Не годен к военной службе (освобождён)")
    comboFit:SetValue("А — Годен к военной службе и работе без ограничений")

    local entAllergies = vgui.Create("DTextEntry", medPnl) entAllergies:SetPos(16, 155) entAllergies:SetSize(380, 26) entAllergies:SetText("Не выявлено")
    local entChronic = vgui.Create("DTextEntry", medPnl) entChronic:SetPos(410, 155) entChronic:SetSize(395, 26) entChronic:SetText("Отсутствуют")

    local entNewEntry = vgui.Create("DTextEntry", medPnl) entNewEntry:SetPos(16, 215) entNewEntry:SetSize(620, 26) entNewEntry:SetPlaceholderText("Текст новой записи осмотра / диагноз / назначение врача...")
    local comboEntryKind = vgui.Create("DComboBox", medPnl) comboEntryKind:SetPos(645, 215) comboEntryKind:SetSize(160, 26)
    comboEntryKind:AddChoice("Осмотр терапевта") comboEntryKind:AddChoice("Хирургическая перевязка")
    comboEntryKind:AddChoice("Вакцинация") comboEntryKind:AddChoice("Заключение ВВК") comboEntryKind:AddChoice("Выписка")
    comboEntryKind:SetValue("Осмотр терапевта")

    local listEntries = vgui.Create("DListView", medPnl)
    listEntries:SetPos(16, 255)
    listEntries:SetSize(910, 310)
    listEntries:AddColumn("Дата и время"):SetFixedWidth(140)
    listEntries:AddColumn("Тип записи"):SetFixedWidth(180)
    listEntries:AddColumn("Заключение врача и назначения"):SetFixedWidth(420)
    listEntries:AddColumn("Врач"):SetFixedWidth(150)

    local currentEntries = {}
    local selKey = ""
    local selSid64 = "0"

    comboTarget.OnSelect = function(_, _, _, pData)
        if istable(pData) then
            selKey = pData.key or ""
            selSid64 = pData.steamID64 or "0"
            entName:SetText(pData.rpName or "")
            listEntries:Clear()
            currentEntries = {}

            local card = medCards[selKey] or medCards[selSid64]
            if istable(card) then
                entName:SetText(card.name or pData.rpName or "")
                comboBlood:SetValue(card.blood or "I (0) Rh+")
                comboFit:SetValue(card.fitnessCategory or "А — Годен к военной службе и работе без ограничений")
                entAllergies:SetText(card.allergies or "Не выявлено")
                entChronic:SetText(card.chronic or "Отсутствуют")

                currentEntries = card.entries or {}
                for _, e in ipairs(currentEntries) do
                    local dStr = os.date("%d.%m.%Y %H:%M", e.ts or os.time())
                    listEntries:AddLine(dStr, e.kind or "Осмотр", e.text or "—", e.doctor or "Врач")
                end
            end
        end
    end

    local btnAddEntry = vgui.Create("DButton", medPnl)
    btnAddEntry:SetPos(815, 215) btnAddEntry:SetSize(110, 26)
    btnAddEntry:SetText("+ Запись")
    btnAddEntry:SetFont("DermaDefaultBold")
    btnAddEntry:SetTextColor(color_white)
    btnAddEntry.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(40, 160, 100) or Color(30, 130, 80)) end
    btnAddEntry.DoClick = function()
        if string.Trim(entNewEntry:GetText()) == "" then notification.AddLegacy("Введите текст записи!", NOTIFY_ERROR, 3) return end
        local newE = {
            ts     = os.time(),
            kind   = comboEntryKind:GetValue(),
            text   = entNewEntry:GetText(),
            doctor = LocalPlayer():GetNWString("GRM_RPName", LocalPlayer():Nick()),
        }
        currentEntries[#currentEntries + 1] = newE
        local dStr = os.date("%d.%m.%Y %H:%M", newE.ts)
        listEntries:AddLine(dStr, newE.kind, newE.text, newE.doctor)
        entNewEntry:SetText("")
        notification.AddLegacy("Запись добавлена в карточку.", NOTIFY_GENERIC, 3)
    end

    local btnSaveCard = vgui.Create("DButton", medPnl)
    btnSaveCard:SetPos(16, 580) btnSaveCard:SetSize(360, 36)
    btnSaveCard:SetText("✔ Сохранить медицинскую карту пациента")
    btnSaveCard:SetFont("DermaDefaultBold")
    btnSaveCard:SetTextColor(color_white)
    btnSaveCard.Paint = function(s, w, h) draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and CC.success or Color(30, 140, 80)) end
    btnSaveCard.DoClick = function()
        if selKey == "" then notification.AddLegacy("Выберите пациента!", NOTIFY_ERROR, 3) return end
        local pack = {
            name            = entName:GetText(),
            blood           = comboBlood:GetValue(),
            fitnessCategory = comboFit:GetValue(),
            allergies       = entAllergies:GetText(),
            chronic         = entChronic:GetText(),
            entries         = currentEntries,
            updated         = os.time(),
        }
        net.Start("GRM_CompMedical_SaveCard")
            net.WriteString(selKey)
            net.WriteTable(pack)
        net.SendToServer()
        frame:Close()
    end

    tabs:AddSheet("Картотека пациентов", medPnl, "icon16/heart.png")
end)
