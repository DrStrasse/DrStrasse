--[[--------------------------------------------------------------------
    grm_money_launderer — клиент: 3D2D + E-меню (находка 179e)
----------------------------------------------------------------------]]
include("shared.lua")

surface.CreateFont("GRMLaunder_Title", { font = "Roboto", size = 15, weight = 900, extended = true })
surface.CreateFont("GRMLaunder_Normal", { font = "Roboto", size = 12, weight = 600, extended = true })
surface.CreateFont("GRMLaunder_Small", { font = "Roboto", size = 10, weight = 500, extended = true })

local function money(n)
    return GRM and GRM.Format and GRM.Format(tonumber(n) or 0) or (tostring(math.floor(tonumber(n) or 0)) .. " GRM")
end

function ENT:Draw()
    self:DrawModel()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > 700 * 700 then return end

    local pos = self:GetPos() + self:GetUp() * 78
    local ang = Angle(0, EyeAngles().y - 90, 90)
    cam.Start3D2D(pos, ang, 0.07)
        local w, h = 320, 112
        draw.RoundedBox(8, -w/2, -h/2, w, h, Color(8, 12, 18, 225))
        draw.RoundedBox(6, -w/2 + 5, -h/2 + 5, w - 10, h - 10, Color(16, 24, 34, 235))
        draw.SimpleText("ОТМЫВЩИК ДЕНЕГ", "GRMLaunder_Title", 0, -46, Color(120, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        local active = self:GetEventActive()
        local col = active and Color(255, 120, 90) or Color(120, 230, 150)
        draw.SimpleText(active and ("ИВЕНТ: ОГРАБЛЕНИЕ  •  " .. tostring(math.max(0, math.floor((self:GetEventEndsAt() or 0) - CurTime()))) .. " сек")
            or ("Набор участников: " .. tostring(self:GetParticipantCount() or 0) .. " / " .. tostring(self:GetMinParticipants() or 2)),
            "GRMLaunder_Title", 0, -24, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Сдано: " .. money(self:GetMoneyHeld() or 0) .. " / " .. money(self:GetGoalMoney() or 0), "GRMLaunder_Normal", 0, 4, Color(255, 220, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("E — взять задание / сдать деньги / настройка", "GRMLaunder_Small", 0, 30, Color(140, 155, 175), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        local allowed = tostring(self:GetAllowedFactions() or "")
        draw.SimpleText(allowed ~= "" and ("Фракции: " .. allowed) or "Фракции: любые", "GRMLaunder_Small", 0, 46, Color(110, 130, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

-- ── E-меню ──
local C = {
    bg = Color(15, 20, 30, 248), panel = Color(30, 40, 56, 245), blue = Color(75, 155, 255),
    green = Color(80, 220, 130), red = Color(230, 85, 75), yellow = Color(245, 195, 70),
    text = Color(245, 248, 255), dim = Color(160, 172, 190),
}
local menuFrame = nil

local function act(ent, action, a, b, c)
    if not IsValid(ent) then return end
    net.Start("GRM_Heist_Action")
        net.WriteEntity(ent)
        net.WriteString(action)
        if action == "config" then
            net.WriteUInt(math.max(1, math.floor(tonumber(a) or 2)), 8)
            net.WriteUInt(math.max(1000, math.floor(tonumber(b) or 500000)), 32)
            net.WriteString(tostring(c or ""))
        elseif action == "config_full" then
            net.WriteUInt(math.max(1, math.floor(tonumber(a) or 2)), 16)
            net.WriteUInt(math.max(1000, math.floor(tonumber(b) or 500000)), 32)
            net.WriteTable(istable(c) and c or {})
        end
    net.SendToServer()
end

net.Receive("GRM_Heist_Open", function()
    local ent = net.ReadEntity()
    local d = net.ReadTable() or {}
    if not IsValid(ent) then return end

    if IsValid(menuFrame) then menuFrame:Remove() end
    menuFrame = vgui.Create("DFrame")
    menuFrame:SetTitle("")
    menuFrame:SetSize(600, 760)
    menuFrame:Center()
    menuFrame:MakePopup()
    menuFrame.Paint = function(_, w, h)
        draw.RoundedBox(9, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(9, 0, 0, w, 52, Color(26, 36, 52, 250), true, true, false, false)
        draw.SimpleText("ОТМЫВЩИК ДЕНЕГ — ОГРАБЛЕНИЕ", "GRMLaunder_Title", 16, 26, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local body = vgui.Create("DPanel", menuFrame)
    body:Dock(FILL)
    body:DockMargin(12, 62, 12, 12)
    body:SetPaintBackground(false)

    local info = vgui.Create("DPanel", body)
    info:Dock(TOP)
    info:SetTall(140)
    info:DockMargin(0, 0, 0, 10)
    info.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, C.panel)
        local active = d.eventActive
        local col = active and C.red or C.green
        draw.SimpleText(active and "ИВЕНТ ИДЁТ: ОГРАБЛЕНИЕ" or "НАБОР УЧАСТНИКОВ", "GRMLaunder_Title", 14, 18, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Участники: " .. tostring(d.participantCount or 0) .. " / минимум " .. tostring(d.minParticipants or 2), "GRMLaunder_Normal", 14, 46, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Сдано отмывщику: " .. money(d.moneyHeld or 0) .. " / " .. money(d.goalMoney or 0), "GRMLaunder_Normal", 14, 70, C.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Ваша фракция: " .. tostring(d.myFaction or "—") .. (d.factionAllowed and "  (доступна)" or "  (НЕ доступна)"), "GRMLaunder_Small", 14, 96, d.factionAllowed and C.green or C.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        -- находка 179f: цель ивента
        local tp = d.targetPos
        local tTxt = tp and ("Цель: Рейхсбанк (" .. ("%.0f %.0f"):format(tp.x, tp.y) .. ")") or "Цель: авто (ближайшее хранилище)"
        draw.SimpleText(tTxt, "GRMLaunder_Small", 14, 116, d.hasTarget and Color(255, 200, 120) or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local function addBtn(text, col, fn, tall)
        local b = vgui.Create("DButton", body)
        b:Dock(TOP)
        b:SetTall(tall or 40)
        b:DockMargin(0, 0, 0, 8)
        b:SetText("")
        b.Paint = function(self, w, h)
            local c = self:IsHovered() and Color(math.min(col.r + 25, 255), math.min(col.g + 25, 255), math.min(col.b + 25, 255)) or col
            draw.RoundedBox(7, 0, 0, w, h, c)
            draw.SimpleText(text, "GRMLaunder_Normal", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = fn
        return b
    end

    -- Взять задание / отменить участие (находка 179m)
    if not d.eventActive then
        if d.isParticipant then
            addBtn("✓ ВЫ В СПИСКЕ УЧАСТНИКОВ", Color(90, 100, 120), function() end)
            addBtn("✕ ОТМЕНИТЬ УЧАСТИЕ", C.red, function()
                act(ent, "leave")
            end)
        else
            addBtn("ВЗЯТЬ ЗАДАНИЕ НА ОГРАБЛЕНИЕ", C.green, function()
                act(ent, "job")
            end)
        end
    elseif d.eventActive and d.isParticipant then
        -- Находка 179p: во время ивента отмена ЗАПРЕЩЕНА — кнопка
        -- заблокирована (серая), с понятной подписью
        addBtn("✕ ОТМЕНА УЧАСТИЯ В МОМЕНТ ИВЕНТА ЗАПРЕЩЕНА", Color(80, 80, 90), function() end, 40)
    end
    -- Сдать деньги (во время ивента)
    if d.eventActive then
        addBtn("СДАТЬ ДЕНЬГИ (сумка + паллеты рядом)", C.yellow, function()
            act(ent, "deposit")
        end)
    end

    -- Настройка (суперадмин) — находка 179g: полноценное меню с чекбоксами
    if d.canManage then
        addBtn("⚑ ЦЕЛЬ: хранилище под прицелом", C.yellow, function()
            act(ent, "set_target")
        end)
        addBtn("✕ Сбросить цель (авто: хранилище)", Color(120, 110, 130), function()
            act(ent, "clear_target")
        end)

        -- заголовок настройки
        local cfgTitle = vgui.Create("DLabel", body)
        cfgTitle:Dock(TOP)
        cfgTitle:SetTall(24)
        cfgTitle:SetFont("GRMLaunder_Title")
        cfgTitle:SetTextColor(C.text)
        cfgTitle:SetText("НАСТРОЙКА (суперадмин)")

        -- минимум участников
        local minRow = vgui.Create("DPanel", body)
        minRow:Dock(TOP)
        minRow:SetTall(30)
        minRow:SetPaintBackground(false)
        local minLbl = vgui.Create("DLabel", minRow)
        minLbl:SetPos(4, 6) minLbl:SetSize(180, 20) minLbl:SetFont("GRMLaunder_Small")
        minLbl:SetTextColor(C.text) minLbl:SetText("Минимум участников:")
        -- Находка 179k: DNumberWang коммитит ввод только по Enter/потере
        -- фокуса — GetValue() мог вернуть старое (2). Читаем из ТЕКСТА
        -- и храним через OnValueChanged.
        local minVal = d.minParticipants or 2
        local minWang = vgui.Create("DNumberWang", minRow)
        minWang:SetPos(190, 2) minWang:SetSize(90, 24)
        minWang:SetMin(1) minWang:SetMax(32) minWang:SetDecimals(0)
        minWang:SetValue(minVal)
        minWang.OnValueChanged = function(_, v) minVal = tonumber(v) or minVal end

        -- цель (сумма)
        local goalRow = vgui.Create("DPanel", body)
        goalRow:Dock(TOP)
        goalRow:SetTall(30)
        goalRow:SetPaintBackground(false)
        local goalLbl = vgui.Create("DLabel", goalRow)
        goalLbl:SetPos(4, 6) goalLbl:SetSize(180, 20) goalLbl:SetFont("GRMLaunder_Small")
        goalLbl:SetTextColor(C.text) goalLbl:SetText("Цель (сумма):")
        local goalVal = d.goalMoney or 500000
        local goalWang = vgui.Create("DNumberWang", goalRow)
        goalWang:SetPos(190, 2) goalWang:SetSize(140, 24)
        goalWang:SetMin(1000) goalWang:SetMax(100000000) goalWang:SetDecimals(0)
        goalWang:SetValue(goalVal)
        goalWang.OnValueChanged = function(_, v) goalVal = tonumber(v) or goalVal end

        -- фракции: чекбоксы в скролле (список существующих)
        local facLbl = vgui.Create("DLabel", body)
        facLbl:Dock(TOP)
        facLbl:SetTall(20)
        facLbl:SetFont("GRMLaunder_Small")
        facLbl:SetTextColor(C.text)
        facLbl:SetText("Фракции, которым можно брать задание (пусто = любые):")

        local facScroll = vgui.Create("DScrollPanel", body)
        facScroll:Dock(TOP)
        facScroll:SetTall(280)
        facScroll:DockMargin(0, 0, 0, 4)
        facScroll.Paint = function(_, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.panel)
        end

        local allowedSet = {}
        if istable(d.allowedFactions) then
            for _, f in ipairs(d.allowedFactions) do allowedSet[f] = true end
        elseif isstring(d.allowedFactions) then
            for f in string.gmatch(d.allowedFactions or "", "([^,]+)") do
                allowedSet[string.Trim(f)] = true
            end
        end
        local facChecks = {}
        local facList = istable(d.factionsList) and d.factionsList or {}
        if #facList == 0 then
            local l = vgui.Create("DLabel", facScroll)
            l:Dock(TOP) l:SetTall(24) l:SetFont("GRMLaunder_Small") l:SetTextColor(C.dim)
            l:SetText("Фракций пока нет — создайте их в /factions.")
        end
        for _, fname in ipairs(facList) do
            local c = vgui.Create("DCheckBoxLabel", facScroll)
            c:Dock(TOP)
            c:SetTall(24)
            c:DockMargin(6, 1, 4, 1)
            c:SetText(fname)
            c:SetFont("GRMLaunder_Small")
            c:SetTextColor(C.text)
            c:SetValue(allowedSet[fname] and 1 or 0)
            facChecks[fname] = c
        end

        -- сохранить
        -- Находка 179l: крупная заметная кнопка сохранения (суперадмин)
        addBtn("💾 СОХРАНИТЬ НАСТРОЙКИ", C.green, function()
            local selected = {}
            for fname, c in pairs(facChecks) do
                if c:GetChecked() then selected[#selected + 1] = fname end
            end
            table.sort(selected)
            -- находка 179k: берём из OnValueChanged-переменных (надёжно)
            local mv = tonumber(minVal) or 2
            local gv = tonumber(goalVal) or 500000
            act(ent, "config_full", mv, gv, selected)
        end, 54)
    end

    local hint = vgui.Create("DLabel", body)
    hint:Dock(BOTTOM)
    hint:SetTall(56)
    hint:SetFont("GRMLaunder_Small")
    hint:SetTextColor(C.dim)
    hint:SetWrap(true)
    hint:SetText("Когда участников станет достаточно — автоматически начнётся ивент «ОГРАБЛЕНИЕ» (50 минут, баннер на весь сервер, музыка). Деньги сдаются отмывщику: сумка ограбления / паллеты рядом / /bag_unload рядом с ним.")
end)
