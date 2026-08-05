--[[--------------------------------------------------------------------
    grm_money_press — клиент: 3D2D-статус станка
----------------------------------------------------------------------]]
include("shared.lua")

surface.CreateFont("GRMPress_Title", { font = "Roboto", size = 15, weight = 900, extended = true })
surface.CreateFont("GRMPress_Normal", { font = "Roboto", size = 11, weight = 600, extended = true })

local function money(n)
    return GRM and GRM.Format and GRM.Format(tonumber(n) or 0) or (tostring(math.floor(tonumber(n) or 0)) .. " GRM")
end

function ENT:Draw()
    self:DrawModel()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > 700 * 700 then return end

    local pos = self:GetPos() + self:GetUp() * 55
    local ang = Angle(0, EyeAngles().y - 90, 90)
    cam.Start3D2D(pos, ang, 0.07)
        local w, h = 300, 104
        draw.RoundedBox(8, -w/2, -h/2, w, h, Color(8, 12, 18, 225))
        draw.RoundedBox(6, -w/2 + 5, -h/2 + 5, w - 10, h - 10, Color(16, 24, 34, 235))
        draw.SimpleText("ПЕЧАТНЫЙ СТАНОК БАНКА", "GRMPress_Title", 0, -42, Color(120, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local active = self:GetActive()
        local heat = self:GetHeat() or 0
        local stateCol = heat >= 100 and Color(255, 90, 80) or (active and Color(100, 230, 140) or Color(240, 190, 80))
        local stateTxt = heat >= 100 and "ПЕРЕГРЕТ" or (active and "ПЕЧАТАЕТ" or "ОСТАНОВЛЕН")
        draw.SimpleText(stateTxt, "GRMPress_Title", 0, -18, stateCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        draw.SimpleText(money(self:GetPrintAmount() or 0) .. " GRM / " .. tostring(self:GetPrintInterval() or 10) .. " сек  •  ур. скорости " .. tostring(self:GetSpeedLevel() or 0), "GRMPress_Normal", 0, 6, Color(200, 220, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Нагрев: " .. tostring(math.floor(heat)) .. "%  •  напечатано: " .. money(self:GetTotalPrinted() or 0), "GRMPress_Normal", 0, 26, heat >= 80 and Color(255, 140, 100) or Color(140, 155, 175), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Управление — терминал рядом (E)", "GRMPress_Normal", 0, 44, Color(110, 130, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
