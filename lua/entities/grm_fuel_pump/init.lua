AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_wasteland/gaspump001a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    if self:GetFuelKind() == "" then self:SetFuelKind("petrol") end
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
end

function ENT:Use(ply)
    if not IsValid(ply) then return end
    if not GRM.Fuel then return end
    local wep = self:GetNWEntity("NozzleWep")
    if IsValid(wep) and wep:GetOwner() == ply then
        GRM.Fuel.ReturnNozzle(wep, self, ply)
        return
    end
    if IsValid(wep) and IsValid(wep:GetOwner()) and wep:GetOwner() ~= ply then
        if GRM.Notify then GRM.Notify(ply, "Колонка занята.", 255, 180, 80) end
        return
    end
    GRM.Fuel.GiveNozzle(self, ply)
end
