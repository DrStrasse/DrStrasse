include("shared.lua")

function ENT:Draw()
    self:DrawModel()
    local wep = self:GetNWEntity("NozzleWep")
    if IsValid(wep) then
        local ply = wep:GetOwner()
        local dest
        if wep:GetNWBool("Inserted") then
            local veh = wep:GetNWEntity("GRM_Veh")
            dest = (IsValid(veh) and GRM.Fuel and GRM.Fuel.TankWorld) and GRM.Fuel.TankWorld(veh) or (IsValid(veh) and veh:WorldSpaceCenter())
        elseif IsValid(ply) then
            dest = ply:GetShootPos() + ply:GetRight() * 8 - ply:GetUp() * 12
        end
        if dest then
            render.SetColorMaterial()
            render.DrawBeam(self:LocalToWorld(Vector(8, 0, 40)), dest, 2.2, 0, 1, Color(30, 28, 24, 240))
        end
    end
    local d = LocalPlayer():GetPos():DistToSqr(self:GetPos())
    if d > 250000 then return end
    local ang = self:LocalToWorldAngles(Angle(0, 90, 90))
    cam.Start3D2D(self:LocalToWorld(Vector(10, 0, 48)), ang, 0.08)
        draw.RoundedBox(4, -100, -28, 200, 56, Color(20, 22, 28, 220))
        local kind = (GRM.Fuel and GRM.Fuel.Types and GRM.Fuel.Types[self:GetFuelKind()]) or self:GetFuelKind()
        draw.SimpleText(kind or "Бензин", "DermaLarge", 0, -10, Color(250, 190, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        local hint = IsValid(wep) and "Шланг снят" or "E — взять пистолет"
        draw.SimpleText(hint, "DermaDefault", 0, 16, Color(220, 220, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
