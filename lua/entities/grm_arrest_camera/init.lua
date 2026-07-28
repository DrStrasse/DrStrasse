AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_wasteland/prison_bed001b.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) phys:Sleep() end
end

function ENT:Use(ply)
    if IsValid(ply) and ply:IsSuperAdmin() then
        if GRM and GRM.Arrest and GRM.Arrest.OpenAdmin then GRM.Arrest.OpenAdmin(ply) end
    end
end
