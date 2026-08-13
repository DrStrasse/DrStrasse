AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    local A = GRM and GRM.FireAddon
    self:SetModel(A and A.SafeModel(A.Models.coil) or "models/props_c17/GasPipes006a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    if self:GetTankMax() <= 0 then self:SetTankMax(2000) end
    if self:GetTank() <= 0 then self:SetTank(self:GetTankMax()) end
    if self:GetMaxHose() <= 0 then self:SetMaxHose(1536) end
    self:SetPumpOn(false)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() phys:EnableMotion(false) end
end

function ENT:AttachToVehicle(veh, localPos, localAng)
    if not IsValid(veh) then return false end
    self:SetHostVehicle(veh)
    self:SetParent(veh)
    if localPos then self:SetLocalPos(localPos) end
    if localAng then self:SetLocalAngles(localAng) end
    return true
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if hook.Run("GRM_FireAddon_PumpUse", ply, self) == false then return end
    -- E: вкл/выкл. Если включили — выдать рукав.
    self:SetPumpOn(not self:GetPumpOn())
    self:EmitSound(self:GetPumpOn() and "ambient/machines/floodgate_stop1.wav" or "buttons/lever4.wav", 70, 95)
    if self:GetPumpOn() and self:GetTank() > 0 then
        local A = GRM and GRM.FireAddon
        if A and A.GiveHose then A.GiveHose(ply) end
    end
end

function ENT:Consume(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then return true end
    if self:GetTank() < amount then
        self:SetTank(0)
        self:SetPumpOn(false)
        return false
    end
    self:SetTank(self:GetTank() - amount)
    return true
end

function ENT:Fill(amount)
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    self:SetTank(math.min(self:GetTankMax(), self:GetTank() + amount))
    return self:GetTank()
end
