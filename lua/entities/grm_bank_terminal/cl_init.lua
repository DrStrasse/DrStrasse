include("entities/grm_bank_terminal/shared.lua")

function ENT:Draw()
    self:DrawModel()
    local pos = self:GetPos() + Vector(0, 0, 55)
    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    cam.Start3D2D(pos, Angle(0, ang.y, 90), 0.09)
        draw.SimpleTextOutlined("БАНК GRM", "DermaLarge", 0, 0, Color(100, 220, 120),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
        draw.SimpleTextOutlined("[E] Операции со счетами", "DermaDefaultBold", 0, 30,
            Color(220, 220, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
    cam.End3D2D()
end
