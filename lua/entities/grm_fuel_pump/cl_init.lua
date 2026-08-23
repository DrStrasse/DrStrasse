include("shared.lua")
function ENT:Draw()
    self:DrawModel()
    local d = LocalPlayer():GetPos():DistToSqr(self:GetPos())
    if d > 250000 then return end
    local ang = self:LocalToWorldAngles(Angle(0, 90, 90))
    cam.Start3D2D(self:LocalToWorld(Vector(10, 0, 48)), ang, 0.08)
        draw.RoundedBox(4, -90, -24, 180, 48, Color(20, 22, 28, 220))
        local kind = (GRM.Fuel and GRM.Fuel.Types and GRM.Fuel.Types[self:GetFuelKind()]) or self:GetFuelKind()
        draw.SimpleText(kind or "Бензин", "DermaLarge", 0, -8, Color(250, 190, 60), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(self:GetBusy() and "Идёт заправка" or "E — заправить", "DermaDefault", 0, 14, Color(220, 220, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
