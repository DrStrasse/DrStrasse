--[[--------------------------------------------------------------------
    grm_bank_vault — init (находка 178)
----------------------------------------------------------------------]]
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    local cfg = GRM and GRM.Economy or {}
    local mdl = self.Model
    if not util.IsValidModel(mdl) then
        mdl = self.ModelFallback
        print("[GRM Bank Vault] ВНИМАНИЕ: модель не найдена, фолбэк '" .. tostring(mdl) .. "'")
    end
    self:SetModel(mdl)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    self:SetCapacity(math.max(1, math.floor(tonumber(GRM.Economy and GRM.Economy.VaultCapacity) or 500000)))
    self:SetHeldCash(0)
    self:SetStateBudget(0)
    if GRM.Economy and GRM.Economy.StateBudgetGet then
        self:SetStateBudget(GRM.Economy.StateBudgetGet())
    end

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() phys:EnableMotion(false) end

    if GRM.Economy and GRM.Economy.RegisterVault then GRM.Economy.RegisterVault(self) end
end

function ENT:OnRemove()
    if GRM.Economy and GRM.Economy.UnregisterVault then GRM.Economy.UnregisterVault(self) end
end

function ENT:Use(ply)
    if not IsValid(ply) then return end
    local can = (GRM.Economy and GRM.Economy.CanManageEconomy and GRM.Economy.CanManageEconomy(ply)) or (IsValid(ply) and ply:IsSuperAdmin())
    if not can then
        if GRM.Notify then GRM.Notify(ply, "Хранилище банка. Доступ: сотрудники с правом экономики.", 200, 200, 120) end
        return
    end
    if GRM.Notify then
        local money = GRM.Format and GRM.Format(math.floor(self:GetStateBudget() or 0)) or tostring(self:GetStateBudget() or 0)
        local held = GRM.Format and GRM.Format(math.floor(self:GetHeldCash() or 0)) or tostring(self:GetHeldCash() or 0)
        local cap = GRM.Format and GRM.Format(math.floor(self:GetCapacity() or 0)) or tostring(self:GetCapacity() or 0)
        GRM.Notify(ply, "В ГОСБЮДЖЕТЕ СЕЙЧАС: " .. money .. "  |  В хранилище: " .. held .. " / " .. cap, 120, 220, 255)
    end
end

print("[GRM] Bank Vault entity loaded (находка 178)")
