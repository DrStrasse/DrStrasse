ENT.Type = "anim"
ENT.Base = "base_anim"
ENT.PrintName = "GRM Рукав"
ENT.Author = "GRM"
ENT.Category = "GRM Fire"
ENT.Spawnable = false
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_OTHER

function ENT:SetupDataTables()
    self:NetworkVar("Entity", 0, "StartEnt")
    self:NetworkVar("Entity", 1, "Holder")
    self:NetworkVar("Entity", 2, "EndNode")
    self:NetworkVar("Int", 0, "LaidLen")
    self:NetworkVar("Int", 1, "MaxLen")
    self:NetworkVar("Bool", 0, "Pressurized")
    self:NetworkVar("Bool", 1, "Docked")
end
