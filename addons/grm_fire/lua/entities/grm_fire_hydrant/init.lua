AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    local A = GRM and GRM.FireAddon
    self:SetModel(A and A.SafeModel(A.Models.hydrant) or "models/props_pipes/valvewheel001.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    if self:GetMaxHose() <= 0 then self:SetMaxHose(1024) end
    self:SetOpen(false)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() phys:EnableMotion(false) end
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    -- Права (фракция / FightPro) наложит серверный скрипт GRM через хук.
    local allow = hook.Run("GRM_FireAddon_HydrantUse", ply, self, not self:GetOpen())
    if allow == false then return end
    self:SetOpen(not self:GetOpen())
    self:EmitSound(self:GetOpen() and "ambient/machines/floodgate_stop1.wav" or "buttons/lever4.wav", 70, 100)
    if self:GetOpen() and GRM and GRM.FireAddon and GRM.FireAddon.GiveHose then
        GRM.FireAddon.GiveHose(ply)
    end
end
