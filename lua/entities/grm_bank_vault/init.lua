--[[--------------------------------------------------------------------
    grm_bank_vault — init (находка 178/178b)
    E → мини-меню хранилища: состояние + «Загрузить» / «Выгрузить».
      Загрузить: все паллеты (grm_vault_cash) и деньги-пропы
                 (grm_money_drop) рядом (радиус 250) грузятся в HeldCash;
                 обычные деньги-пропы — ещё и в гос.бюджет (взнос в казну).
      Выгрузить: с указанием суммы; ≥ 50.000 → паллеты (по 100.000),
                 < 50.000 → пачка money.mdl. Право: CanManageEconomy/суперадмин.
----------------------------------------------------------------------]]
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("GRM_VaultMenu_Open")
util.AddNetworkString("GRM_VaultMenu_Action")

ENT.LoadRadius = 250   -- радиус поиска паллет/денег для загрузки

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

function ENT:CanManage(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    return GRM.Economy and GRM.Economy.CanManageEconomy and GRM.Economy.CanManageEconomy(ply) == true
end

-- ── Загрузить: паллеты и деньги-пропы рядом → в хранилище ──
function ENT:LoadNearCash(ply)
    if not IsValid(ply) then return 0 end
    local held = math.floor(self:GetHeldCash() or 0)
    local cap = math.max(1, math.floor(self:GetCapacity() or 500000))
    local free = math.max(0, cap - held)
    if free <= 0 then
        if GRM.Notify then GRM.Notify(ply, "Хранилище заполнено (вместимость 500.000).", 255, 190, 90) end
        return 0
    end
    local r = math.max(64, tonumber(self.LoadRadius) or 250)
    local found = ents.FindInSphere(self:GetPos(), r)
    local loaded = 0
    for _, ent in ipairs(found) do
        if free <= 0 then break end
        if IsValid(ent) and not ent:IsPlayer() and not ent:IsNPC() and not ent:IsWorld() then
            local cls = ent:GetClass()
            if cls == "grm_vault_cash" or cls == "grm_money_drop" then
                local amt = math.max(0, math.floor(tonumber(ent:GetAmount() or 0)))
                if amt > 0 then
                    local take = math.min(amt, free)
                    -- паллета от станка/панели уже учтена в гос.бюджете;
                    -- обычные деньги-пропы — взнос в казну (бюджет +)
                    if cls == "grm_money_drop" and GRM.Economy and GRM.Economy.StateBudgetAdd then
                        GRM.Economy.StateBudgetAdd(take, "Взнос в казну: " .. ply:Nick())
                    end
                    held = held + take
                    free = free - take
                    loaded = loaded + take
                    ent:Remove()
                    self:SetHeldCash(held)
                end
            end
        end
    end
    if loaded > 0 then
        self:EmitSound("physics/wood/wood_crate_impact_hard2.wav", 60, 100)
        if GRM.Notify then
            GRM.Notify(ply, "Загружено в хранилище: " .. (GRM.Format and GRM.Format(loaded) or tostring(loaded)), 100, 220, 130)
        end
    elseif GRM.Notify then
        GRM.Notify(ply, "Рядом нет паллет или денег для загрузки (радиус " .. r .. ").", 255, 190, 90)
    end
    return loaded
end

-- ── Выгрузить: указанная сумма → паллеты (≥50к) / пачка money.mdl (<50к) ──
function ENT:UnloadCash(ply, amount)
    if not self:CanManage(ply) then
        if GRM.Notify then GRM.Notify(ply, "Выгрузка из хранилища — только сотрудники с доступом к экономике.", 255, 120, 100) end
        return false
    end
    amount = math.floor(tonumber(amount) or 0)
    if amount <= 0 then return false end
    local held = math.floor(self:GetHeldCash() or 0)
    if amount > held then
        amount = held
    end
    if amount <= 0 then
        if GRM.Notify then GRM.Notify(ply, "В хранилище нет денег для выгрузки.", 255, 190, 90) end
        return false
    end
    self:SetHeldCash(held - amount)
    -- выгрузка из хранилища = изъятие из казны
    if GRM.Economy and GRM.Economy.StateBudgetAdd then
        GRM.Economy.StateBudgetAdd(-amount, "Выгрузка из хранилища: " .. ply:Nick())
    end
    local pos = self:GetPos() + self:GetForward() * 70 + Vector(0, 0, 12)
    if GRM.Economy and GRM.Economy.SpawnCashAt then
        GRM.Economy.SpawnCashAt(pos, amount, self)
    end
    self:EmitSound("physics/wood/wood_crate_impact_hard1.wav", 60, 100)
    if GRM.Notify then
        GRM.Notify(ply, "Выгружено из хранилища: " .. (GRM.Format and GRM.Format(amount) or tostring(amount)), 120, 220, 255)
    end
    return true
end

function ENT:SendMenu(ply)
    if not IsValid(ply) then return end
    net.Start("GRM_VaultMenu_Open")
        net.WriteEntity(self)
        net.WriteTable({
            stateBudget = math.floor(self:GetStateBudget() or 0),
            held = math.floor(self:GetHeldCash() or 0),
            capacity = math.floor(self:GetCapacity() or 500000),
            canManage = self:CanManage(ply),
        })
    net.Send(ply)
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if (self._grmUseT or 0) > CurTime() then return end
    self._grmUseT = CurTime() + 0.4
    self:SendMenu(ply)
end

net.Receive("GRM_VaultMenu_Action", function(_, ply)
    if not IsValid(ply) then return end
    local vault = net.ReadEntity()
    local action = net.ReadString()
    if not IsValid(vault) or vault:GetClass() ~= "grm_bank_vault" then return end
    if ply:GetPos():DistToSqr(vault:GetPos()) > 250 * 250 then return end

    if action == "load" then
        vault:LoadNearCash(ply)
    elseif action == "unload" then
        local amount = net.ReadUInt(32)
        vault:UnloadCash(ply, amount)
    end
    vault:SendMenu(ply)
end)

print("[GRM] Bank Vault entity loaded (находка 178/178b)")
