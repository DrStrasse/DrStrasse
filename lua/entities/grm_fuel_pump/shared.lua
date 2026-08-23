ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Заправка"
ENT.Category = "GRM Vehicles"
ENT.Spawnable = true
ENT.AdminSpawnable = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "FuelKind")
    self:NetworkVar("Entity", 0, "User")
    self:NetworkVar("Bool", 0, "Busy")
end
