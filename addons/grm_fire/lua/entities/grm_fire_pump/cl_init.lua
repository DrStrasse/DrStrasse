include("shared.lua")

function ENT:Draw()
    self:DrawModel()
    local ply = LocalPlayer()
    if not IsValid(ply) or ply:GetPos():DistToSqr(self:GetPos()) > 200 * 200 then return end
    local pos = self:WorldSpaceCenter() + Vector(0, 0, 16)
    local ang = EyeAngles()
    ang:RotateAroundAxis(ang:Right(), 90)
    ang:RotateAroundAxis(ang:Up(), -90)
    local on = self:GetPumpOn()
    local slots = tostring(self:GetHosesOut() or 0) .. "/" .. tostring(self:GetHosesMax() or 4)
    local txt = (on and "НАСОС ВКЛ  " or "насос выкл  ") .. tostring(self:GetTank() or 0) .. "/" .. tostring(self:GetTankMax() or 0) .. "  рукава " .. slots
    cam.Start3D2D(pos, ang, 0.07)
        draw.SimpleText(txt, "DermaDefaultBold", 0, 0, on and Color(80, 200, 255) or Color(180, 190, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
