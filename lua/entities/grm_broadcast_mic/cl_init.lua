include("shared.lua")

surface.CreateFont("GRMMic_T", { font = "Roboto", size = 18, weight = 800, extended = true })
surface.CreateFont("GRMMic_S", { font = "Roboto", size = 13, weight = 500, extended = true })

function ENT:Draw()
    self:DrawModel()
    local lp = LocalPlayer()
    if not IsValid(lp) or lp:GetPos():DistToSqr(self:GetPos()) > 350 * 350 then return end

    local station = self:GetNWString("GRM_BC_Station", "ГРМ-Радио")
    local live = self:GetNWBool("GRM_BC_Live", false)
    local speaker = self:GetNWString("GRM_BC_Speaker", "")

    local ang = self:GetAngles()
    local maxs = self:OBBMaxs()
    local pos = self:GetPos() + ang:Up() * ((maxs and maxs.z or 40) + 14)
    local blink = live and ((math.sin(CurTime() * 6) + 1) * 0.5) or 0
    cam.Start3D2D(pos, Angle(0, lp:EyeAngles().y - 90, 90), 0.07)
        draw.RoundedBox(6, -150, -48, 300, 96, Color(14, 18, 26, 225))
        surface.SetDrawColor(live and 255 or 70, live and 60 or 150, live and 55 or 240, 150 + blink * 105)
        surface.DrawOutlinedRect(-150, -48, 300, 96, 2)
        draw.SimpleText(station, "GRMMic_T", 0, -42, Color(240, 245, 250), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        if live then
            draw.SimpleText("● В ЭФИРЕ — " .. speaker, "GRMMic_S", 0, -14, Color(255, 120 + blink * 120, 110), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        else
            draw.SimpleText("микрофон молчит", "GRMMic_S", 0, -14, Color(160, 170, 185), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
        draw.SimpleText("[E] Пульт эфира (СМИ)", "GRMMic_S", 0, 10, Color(140, 150, 165), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    cam.End3D2D()
end
