--[[--------------------------------------------------------------------
    GRM Vehicle Dealer — anim entity safety patch

    Put this alongside the corrected tool. It fixes dealers created by
    auto-load, chat commands or other addons as well as tool-created ones.
----------------------------------------------------------------------]]

if CLIENT then return end

local CLASS = "sent_vehicle_dealer"

local function applyDealerAnimState(ent)
    if not IsValid(ent) or ent:GetClass() ~= CLASS then return end

    -- Removes any incorrectly created physics object. Dealer remains an
    -- anim/base_gmodentity NPC-like entity, never a ragdoll.
    ent:PhysicsDestroy()
    ent:SetSolid(SOLID_BBOX)
    ent:SetMoveType(MOVETYPE_NONE)
    ent:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))
    ent:SetCollisionGroup(COLLISION_GROUP_NPC)
    ent:SetUseType(SIMPLE_USE)
    ent:SetAutomaticFrameAdvance(true)

    local candidates = { "idle_all_01", "idle_all", "idle_subtle", "idle", "idle01", "pose_standing_01" }
    for _, sequenceName in ipairs(candidates) do
        local sequence = ent:LookupSequence(sequenceName)
        if sequence and sequence >= 0 then
            ent:ResetSequence(sequence)
            ent:SetPlaybackRate(1)
            ent:SetCycle(0)
            return
        end
    end

    local sequence = ent:SelectWeightedSequence(ACT_IDLE)
    if sequence and sequence >= 0 then
        ent:ResetSequence(sequence)
        ent:SetPlaybackRate(1)
        ent:SetCycle(0)
    end
end

hook.Add("OnEntityCreated", "GRM_VehicleDealer_NoRagdoll", function(ent)
    timer.Simple(0.1, function()
        applyDealerAnimState(ent)
    end)
end)

hook.Add("InitPostEntity", "GRM_VehicleDealer_FixExisting", function()
    timer.Simple(1, function()
        for _, ent in ipairs(ents.FindByClass(CLASS)) do
            applyDealerAnimState(ent)
        end
    end)
end)

print("[VD Fix] Dealer anim/no-ragdoll patch loaded")
