AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    local mdl = self:GetNWString("GRM_DutyModel", "")
    if mdl == "" or not util.IsValidModel(mdl) then mdl = "models/Humans/Group01/Male_07.mdl" end
    self:SetModel(mdl)
    self:SetHullType(HULL_HUMAN)
    self:SetHullSizeNormal()
    self:SetNPCState(NPC_STATE_SCRIPT)
    self:SetSolid(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetUseType(SIMPLE_USE)
    self:SetMaxHealth(100000)
    self:SetHealth(100000)
    self:CapabilitiesAdd(CAP_ANIMATEDFACE + CAP_TURN_HEAD)
    self:DropToFloor()
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if (self._grmUseAt or 0) > CurTime() then return end
    self._grmUseAt = CurTime() + 0.7
    if GRM and GRM.FactionDuty and GRM.FactionDuty.Open then GRM.FactionDuty.Open(activator, self) end
end

function ENT:OnTakeDamage(dmg)
    if dmg and dmg.SetDamage then dmg:SetDamage(0) end
    self:SetHealth(100000)
    return 0
end
