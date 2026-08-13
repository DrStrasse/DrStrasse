ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "GRM Точка очага"
ENT.Author = "GRM"
ENT.Category = "GRM Fire"
ENT.Spawnable = true
ENT.AdminOnly = true
ENT.RenderGroup = RENDERGROUP_TRANSLUCENT

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "Weight")
    self:NetworkVar("Int", 1, "LastIgnite")
    self:NetworkVar("String", 0, "SpotLabel")
end
