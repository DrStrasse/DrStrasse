AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local IDLE_NAMES={"idle_all_01","idle_all","pose_standing_02","idle_subtle","idle_angry"}
local function usableSequence(ent,name)
    local seq=ent:LookupSequence(name)
    if not seq or seq<0 then return nil end
    local duration=ent:SequenceDuration(seq)
    if not duration or duration<=0 then return nil end
    return seq
end
function ENT:RefreshIdle(force)
    local model=string.lower(tostring(self:GetModel()or""));local current=string.lower(tostring(self:GetSequenceName(self:GetSequence())or""))
    if not force and self._grmIdleModel==model and current~=""and current~="reference"and current~="ragdoll"then return true end
    local seq
    for _,name in ipairs(IDLE_NAMES)do seq=usableSequence(self,name);if seq then break end end
    if not seq then local candidate=self:SelectWeightedSequence(ACT_IDLE);if candidate and candidate>=0 and self:SequenceDuration(candidate)>0 and string.lower(tostring(self:GetSequenceName(candidate)or""))~="reference"then seq=candidate end end
    if not seq then return false end
    self:ResetSequence(seq);self:ResetSequenceInfo();self:SetCycle(0);self:SetPlaybackRate(1);self._grmIdleModel=model;self._grmIdleSequence=seq
    return true
end
function ENT:Initialize()
    local mdl=self:GetNWString("GRM_DutyModel","");if mdl==""or not util.IsValidModel(mdl)then mdl="models/Humans/Group01/Male_07.mdl"end
    self:SetModel(mdl);self:SetHullType(HULL_HUMAN);self:SetHullSizeNormal();self:SetNPCState(NPC_STATE_IDLE);self:SetSolid(SOLID_BBOX);self:SetMoveType(MOVETYPE_NONE);self:SetUseType(SIMPLE_USE);self:SetMaxHealth(100000);self:SetHealth(100000);self:CapabilitiesAdd(CAP_ANIMATEDFACE+CAP_TURN_HEAD);self:DropToFloor();self:RefreshIdle(true)
end
function ENT:Think()
    local model=string.lower(tostring(self:GetModel()or""));local sequence=string.lower(tostring(self:GetSequenceName(self:GetSequence())or""))
    if model~=self._grmIdleModel or sequence==""or sequence=="reference"or sequence=="ragdoll"then self:RefreshIdle(true)end
    self:NextThink(CurTime()+.5);return true
end
function ENT:Use(activator)
    if not IsValid(activator)or not activator:IsPlayer()then return end;if(self._grmUseAt or 0)>CurTime()then return end;self._grmUseAt=CurTime()+.7
    if GRM and GRM.FactionDuty and GRM.FactionDuty.Open then GRM.FactionDuty.Open(activator,self)end
end
function ENT:OnTakeDamage(dmg)if dmg and dmg.SetDamage then dmg:SetDamage(0)end;self:SetHealth(100000);return 0 end
