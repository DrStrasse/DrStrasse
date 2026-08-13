AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_junk/PopCan01a.mdl")
    self:SetSolid(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)
    self:SetUseType(SIMPLE_USE)
    self:DrawShadow(false)
    self:SetNoDraw(true)
    self:SetNotSolid(true)
    if self:GetWeight() <= 0 then self:SetWeight(1) end
    if self:GetSpotLabel() == "" then self:SetSpotLabel("очаг") end
end

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
