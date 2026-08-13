AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    local A = GRM and GRM.FireAddon
    self:SetModel(A and A.SafeModel(A.Models.pump) or "models/props_lab/tpplugholder_single.mdl")
    self:SetSolid(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)
    self:SetUseType(SIMPLE_USE)
    self:DrawShadow(false)
    self:SetNotSolid(true)
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetColor(Color(70, 190, 255, 140))
    if self:GetTankMax() <= 0 then self:SetTankMax(2000) end
    if self:GetTank() <= 0 then self:SetTank(self:GetTankMax()) end
    if self:GetMaxHose() <= 0 then self:SetMaxHose((A and A.HoseCfg and A.HoseCfg.MaxLength) or 2200) end
    if self:GetHosesMax() <= 0 then self:SetHosesMax((A and A.HoseCfg and A.HoseCfg.TruckSlots) or 4) end
    self:SetHosesOut(0)
    self:SetPumpOn(false)
end

function ENT:AttachToVehicle(veh, localPos, localAng)
    if not IsValid(veh) then return false end
    self:SetHostVehicle(veh)
    self:SetParent(veh)
    self:SetLocalPos(localPos or Vector(0, -46, 16))
    self:SetLocalAngles(localAng or Angle(0, 90, 0))
    self:SetSolid(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_WORLD)
    self:SetNotSolid(true)
    self:DrawShadow(false)
    return true
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if hook.Run("GRM_FireAddon_PumpUse", ply, self) == false then return end
    local A = GRM and GRM.FireAddon
    local hose = ply.GRM_FireHose

    if IsValid(hose) then
        if hose:GetStartEnt() == self then
            if A and A.ReturnHose then A.ReturnHose(ply, hose) end
            if ply.ChatPrint then ply:ChatPrint("[Рукав] Смотан на катушку.") end
            return
        end
        local ok, err = hose:DockTo(self, ply)
        if not ok and ply.ChatPrint then ply:ChatPrint("[Рукав] " .. tostring(err or "стык не вышел")) end
        return
    end

    if A and A.RewindAtSource then
        local n = A.RewindAtSource(self, ply)
        if n > 0 then
            if ply.ChatPrint then ply:ChatPrint("[Рукав] Смотано рукавов: " .. tostring(n)) end
            return
        end
    end

    if A and A.TakeHose then
        local h, err = A.TakeHose(ply, self)
        if h then
            self:SetHosesOut(A.HoseCountOn(self))
            return
        end
        if err == "нет свободных рукавов" then
            self:SetPumpOn(not self:GetPumpOn())
            self:EmitSound(self:GetPumpOn() and "ambient/machines/floodgate_stop1.wav" or "buttons/lever4.wav", 70, 95)
            return
        end
        if ply.ChatPrint then ply:ChatPrint("[Рукав] " .. tostring(err)) end
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

function ENT:Think()
    if self:GetTank() < self:GetTankMax() then
        local near
        for _, h in ipairs(ents.FindInSphere(self:GetPos(), 220)) do
            if IsValid(h) and h:GetClass() == "grm_fire_hydrant" and h.GetOpen and h:GetOpen() then
                near = h
                break
            end
        end
        if near then self:Fill(25) end
    end
    if GRM and GRM.FireAddon and GRM.FireAddon.HoseCountOn then
        self:SetHosesOut(GRM.FireAddon.HoseCountOn(self))
    end
    self:NextThink(CurTime() + 1)
    return true
end
