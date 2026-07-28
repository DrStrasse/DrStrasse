include("shared.lua")

function ENT:Draw()
    self:DrawModel()
    if not IsValid(LocalPlayer()) or LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 500 * 500 then return end
    local ang = Angle(0, LocalPlayer():EyeAngles().y - 90, 90)
    local pos = self:GetPos() + self:GetUp() * 58
    cam.Start3D2D(pos, ang, 0.1)
        draw.RoundedBox(6, -150, -30, 300, 60, Color(12, 16, 22, 220))
        surface.SetDrawColor(220, 90, 70, 220)
        surface.DrawOutlinedRect(-150, -30, 300, 60, 2)
        draw.SimpleText("КАМЕРА АРЕСТА", "DermaDefaultBold", 0, -10, Color(255, 180, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(self:GetCameraName(), "DermaDefault", 0, 12, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
