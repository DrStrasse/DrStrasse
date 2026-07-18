AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    local mdl = self.Model
    if not util.IsValidModel(mdl) then
        mdl = self.ModelFallback
        print("[GRM Money] ВНИМАНИЕ: модель денег не найдена, фолбэк '" .. tostring(mdl) .. "'")
    end
    self:SetModel(mdl)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    if self:GetAmount() <= 0 then self:SetAmount(1) end
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
    -- авто-удаление через 10 минут (деньги пропадают)
    timer.Simple(600, function()
        if IsValid(self) then self:Remove() end
    end)
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if (self._grmUseT or 0) > CurTime() then return end -- антиспам E 0.4 с
    self._grmUseT = CurTime() + 0.4
    local amt = math.max(0, math.floor(tonumber(self:GetAmount()) or 0))
    if amt <= 0 then self:Remove() return end
    if not (GRM and GRM.GiveMoney) then return end
    GRM.GiveMoney(ply, amt, "Подобраны деньги с земли")
    if GRM.Notify then
        GRM.Notify(ply, "Подобрано: " .. (GRM.Format and GRM.Format(amt) or tostring(amt)), 100, 220, 100)
    end
    hook.Run("GRM_Money_Picked", ply, amt)
    self:Remove()
end
