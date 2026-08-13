include("shared.lua")

function ENT:Draw()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local wep = ply:GetActiveWeapon()
    local show = ply:IsSuperAdmin() or (IsValid(wep) and wep:GetClass() == "gmod_tool")
    if not show then return end
    self:DrawModel()
    local pos = self:WorldSpaceCenter() + Vector(0, 0, 18)
    local ang = EyeAngles()
    ang:RotateAroundAxis(ang:Right(), 90)
    ang:RotateAroundAxis(ang:Up(), -90)
    cam.Start3D2D(pos, ang, 0.08)
        draw.SimpleText("ОЧАГ ×" .. tostring(self:GetWeight() or 1), "DermaDefaultBold", 0, 0, Color(255, 160, 70), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
