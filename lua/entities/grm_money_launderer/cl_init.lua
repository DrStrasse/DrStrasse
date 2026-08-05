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
    menuFrame:SetSize(480, 430)
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
    info:SetTall(120)
    info:DockMargin(0, 0, 0, 10)
    info.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, C.panel)
        local active = d.eventActive
        local col = active and C.red or C.green
        draw.SimpleText(active and "ИВЕНТ ИДЁТ: ОГРАБЛЕНИЕ" or "НАБОР УЧАСТНИКОВ", "GRMLaunder_Title", 14, 18, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Участники: " .. tostring(d.participantCount or 0) .. " / минимум " .. tostring(d.minParticipants or 2), "GRMLaunder_Normal", 14, 46, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Сдано отмывщику: " .. money(d.moneyHeld or 0) .. " / " .. money(d.goalMoney or 0), "GRMLaunder_Normal", 14, 70, C.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Ваша фракция: " .. tostring(d.myFaction or "—") .. (d.factionAllowed and "  (доступна)" or "  (НЕ доступна)"), "GRMLaunder_Small", 14, 96, d.factionAllowed and C.green or C.red, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local function addBtn(text, col, fn)
        local b = vgui.Create("DButton", body)
        b:Dock(TOP)
        b:SetTall(40)
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

    -- Взять задание
    if not d.eventActive then
        local jobTxt = d.isParticipant and "✓ ВЫ В СПИСКЕ УЧАСТНИКОВ" or "ВЗЯТЬ ЗАДАНИЕ НА ОГРАБЛЕНИЕ"
        addBtn(jobTxt, d.isParticipant and Color(90, 100, 120) or C.green, function()
            if not d.isParticipant then act(ent, "job") end
        end)
    end
    -- Сдать деньги (во время ивента)
    if d.eventActive then
        addBtn("СДАТЬ ДЕНЬГИ (сумка + паллеты рядом)", C.yellow, function()
            act(ent, "deposit")
        end)
    end

    -- Настройка (суперадмин)
    if d.canManage then
        addBtn("⚙ НАСТРОЙКА (суперадмин)", C.blue, function()
            Derma_StringRequest("Отмывщик — минимум участников", "Минимальное число участников:", tostring(d.minParticipants or 2), function(val)
                local minP = math.floor(tonumber(val) or 2)
                Derma_StringRequest("Отмывщик — цель", "Цель (сумма денег для победы):", tostring(d.goalMoney or 500000), function(goal)
                    Derma_StringRequest("Отмывщик — фракции", "Фракции, которым можно брать задание (через запятую; пусто = любые):", tostring(d.allowedFactions or ""), function(allowed)
                        act(ent, "config", minP, math.floor(tonumber(goal) or 500000), allowed)
                    end)
                end)
            end)
        end)
    end

    local hint = vgui.Create("DLabel", body)
    hint:Dock(BOTTOM)
    hint:SetTall(56)
    hint:SetFont("GRMLaunder_Small")
    hint:SetTextColor(C.dim)
    hint:SetWrap(true)
    hint:SetText("Когда участников станет достаточно — автоматически начнётся ивент «ОГРАБЛЕНИЕ» (50 минут, баннер на весь сервер, музыка). Деньги сдаются отмывщику: сумка ограбления / паллеты рядом / /bag_unload рядом с ним.")
end)
