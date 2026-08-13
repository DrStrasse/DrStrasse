AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    local A = GRM and GRM.FireAddon
    self:SetModel(A and A.SafeModel(A.Models.spot) or "models/hunter/blocks/cube025x025x025.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)
    self:SetUseType(SIMPLE_USE)
    self:DrawShadow(false)
    if self:GetWeight() <= 0 then self:SetWeight(1) end
    if self:GetSpotLabel() == "" then self:SetSpotLabel("очаг") end
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() phys:EnableMotion(false) end
end

-- E на точке: только подсказка. Поджог — тул / серверный скрипт (CreateVFire).
function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    hook.Run("GRM_FireAddon_SpotUse", ply, self)
end

function ENT:IgniteSpot(feed, starter)
    feed = tonumber(feed) or 200
    self:SetLastIgnite(os.time())
    hook.Run("GRM_FireAddon_SpotIgnite", self, feed, starter)
    if vFireInstalled and CreateVFire then
        local pos = self:GetPos()
        local tr = util.TraceLine({
            start = pos + Vector(0, 0, 8),
            endpos = pos - Vector(0, 0, 48),
            filter = self,
        })
        local hit = tr.Hit and tr.HitPos or pos
        local nrm = tr.Hit and tr.HitNormal or Vector(0, 0, 1)
        local parent = (tr.Hit and IsValid(tr.Entity) and tr.Entity) or game.GetWorld()
        return CreateVFire(parent, hit, nrm, feed, starter)
    end
    return nil
end
