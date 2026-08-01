AddCSLuaFile("shared.lua");AddCSLuaFile("cl_init.lua");include("shared.lua")
function ENT:Initialize()self:SetModel("models/props_c17/paper01.mdl");self:PhysicsInit(SOLID_VPHYSICS);self:SetMoveType(MOVETYPE_VPHYSICS);self:SetSolid(SOLID_VPHYSICS);self:SetUseType(SIMPLE_USE);local p=self:GetPhysicsObject();if IsValid(p)then p:Wake()end end
function ENT:Use(ply)
 net.Start("GRM_Net_Document")
 net.WriteEntity(self)
 net.WriteString(self:GetDocumentTitle())
 net.WriteString(self.DocumentContentServer or self:GetDocumentContent())
 net.WriteString(self:GetDocumentOwner())
 net.WriteString(self:GetDocumentImage())
 net.WriteString(self:GetDocumentCategory())
 net.Send(ply)
end
