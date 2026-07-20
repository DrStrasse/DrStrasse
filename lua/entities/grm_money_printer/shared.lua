ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Денежный принтер"
ENT.Author = "GRM"
ENT.Category = "GRM — RP"
ENT.Spawnable = true
ENT.AdminSpawnable = true
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "Printed")
    self:NetworkVar("Int", 1, "MaxMoney")
    self:NetworkVar("Bool", 0, "Active")
end
