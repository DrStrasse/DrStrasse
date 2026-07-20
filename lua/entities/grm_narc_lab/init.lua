AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_wasteland/laundry_washer003.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    
    -- Устанавливаем тип если не установлен (по умолчанию narc)
    if not self.LabType then
        self.LabType = "narc"
    end
    
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    
    -- Открываем UI крафта
    net.Start("GRM_NarcCraft_Open")
        net.WriteString(self.LabType or "narc")
    net.Send(ply)
end
