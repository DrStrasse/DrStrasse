ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "GRM Насос (машина)"
ENT.Author = "GRM"
ENT.Category = "GRM Fire"
ENT.Spawnable = true
ENT.AdminOnly = true

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "PumpOn")
    self:NetworkVar("Int", 0, "Tank")
    self:NetworkVar("Int", 1, "TankMax")
    self:NetworkVar("Int", 2, "MaxHose")
    self:NetworkVar("Entity", 0, "HostVehicle")
end
