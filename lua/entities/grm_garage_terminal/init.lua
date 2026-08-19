AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

ENT.Model = "models/props_lab/servers.mdl"

function ENT:Initialize()
    self:SetModel(self.Model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) phys:Sleep() end
    if self:GetGarageName() == "" then self:SetGarageName("Гараж") end
end

function ENT:Use(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    if (self._grmNext or 0) > CurTime() then return end
    self._grmNext = CurTime() + 0.4
    local G = GRM and GRM.Garage
    if not (G and G.OpenFor) then return end
    local rec = G.Get(self:GetGarageID())
    if not rec then
        if GRM.Notify then GRM.Notify(ply, "Стойка не привязана к гаражу.", 255, 150, 110) end
        return
    end
    local can, why = G.CanUse(ply, rec)
    if not can then
        if GRM.Notify then GRM.Notify(ply, why or "Нет доступа к этому гаражу", 255, 140, 110) end
        return
    end
    G.Push(ply, rec)
end

-- Стойку нельзя утащить физганом/удалить случайно: она часть карты гаража.
function ENT:CanTool() return false end
function ENT:PhysgunPickup() return false end
