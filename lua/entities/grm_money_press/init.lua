--[[--------------------------------------------------------------------
    grm_money_press — init (находка 178)
----------------------------------------------------------------------]]
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

GRM = GRM or {}
GRM.MoneyPress = GRM.MoneyPress or {} -- реестр станков: [entIndex] = ent

local function notify(ply, msg, r, g, b)
    if IsValid(ply) and GRM and GRM.Notify then
        GRM.Notify(ply, msg, r or 200, g or 200, b or 200)
    end
end

function ENT:Initialize()
    local mdl = self.Model
    if not util.IsValidModel(mdl) then
        mdl = self.ModelFallback
        print("[GRM Money Press] ВНИМАНИЕ: модель не найдена, фолбэк '" .. tostring(mdl) .. "'")
    end
    self:SetModel(mdl)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    self:SetActive(true)
    self:SetBroken(false)
    self:SetSpeedLevel(0)
    self:SetHeat(0)
    self:SetPrintInterval(self.BaseInterval)
    self:SetPrintAmount(self.BaseAmount)
    self:SetTotalPrinted(0)
    self:SetBuffer(0)
    self.NextPrint = CurTime() + self:GetPrintInterval()
    self.NextCool = CurTime() + 1

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() phys:EnableMotion(false) end

    GRM.MoneyPress[self:EntIndex()] = self
end

function ENT:OnRemove()
    GRM.MoneyPress[self:EntIndex()] = nil
end

function ENT:CanManage(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    return GRM.Economy and GRM.Economy.CanManageEconomy and GRM.Economy.CanManageEconomy(ply) == true
end

function ENT:AmountPerCycle()
    local lvl = math.floor(self:GetSpeedLevel() or 0)
    return math.floor(self.BaseAmount * (1 + lvl * 0.5)) -- 5000, 7500, 10000, ...
end

function ENT:Think()
    local now = CurTime()

    -- охлаждение
    if self:GetHeat() > 0 and (self.NextCool or 0) <= now then
        self.NextCool = now + 1
        local rate = self:GetActive() and self.CoolPerSec or (self.CoolPerSec * 2)
        self:SetHeat(math.max(0, self:GetHeat() - rate))
    end

    -- перегрев: остановка
    if self:GetActive() and self:GetHeat() >= self.OverheatAt then
        self:SetActive(false)
        self:EmitSound("ambient/energy/spark6.wav", 70, 100)
        local owner = self:OwnerPlayer()
        if IsValid(owner) then notify(owner, "Печатный станок перегрелся! Охладите его через терминал.", 255, 120, 80) end
    end

    if not self:GetActive() or self:GetBroken() or self:GetHeat() >= self.OverheatAt then
        self:NextThink(now + 1)
        return true
    end

    if (self.NextPrint or 0) <= now then
        self.NextPrint = now + math.max(5, self:GetPrintInterval())
        self:PrintMoney()
    end

    self:NextThink(now + 1)
    return true
end

function ENT:PrintMoney()
    if not (GRM.Economy and GRM.Economy.StateBudgetAdd) then return end
    local amount = self:AmountPerCycle()
    GRM.Economy.StateBudgetAdd(amount, "Печать денег (банковский станок)")
    self:SetTotalPrinted(self:GetTotalPrinted() + amount)
    self:SetHeat(math.min(120, self:GetHeat() + self.HeatPerPrint))
    self:EmitSound("buttons/button17.wav", 58, math.random(95, 110))

    -- Находка 178b: копим в БУФЕР; при достижении 100.000 спавним ПАЛЛЕТУ
    -- у станка. Игрок подносит её к хранилищу и загружает через E-меню.
    local buffer = math.floor(self:GetBuffer() or 0) + amount
    self:SetBuffer(buffer)
    local palletMax = math.floor(tonumber(self.BasePalletMax) or 100000)
    if buffer >= palletMax and GRM.Economy.SpawnCashAt then
        local pos = self:GetPos() + self:GetForward() * 60 + Vector(0, 0, 12)
        local n = math.floor(buffer / palletMax)
        local spawned = 0
        for _ = 1, n do
            spawned = spawned + GRM.Economy.SpawnCashAt(pos, palletMax, nil)
        end
        buffer = buffer - n * palletMax
        self:SetBuffer(buffer)
        if spawned > 0 then
            self:EmitSound("physics/wood/wood_crate_impact_hard1.wav", 65, 100)
        end
    end
end

function ENT:OwnerPlayer()
    local sid = tostring(self:GetOwnerSID64() or "")
    if sid == "" then return nil end
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            local key = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(p)) or p:SteamID64() or ""
            if tostring(key) == sid then return p end
        end
    end
    return nil
end

function ENT:SetPressOwner(ply)
    if not IsValid(ply) then return end
    self:SetOwnerSID64((GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(ply)) or ply:SteamID64() or "")
end

-- ── Действия (через терминал) ─────────────────────────────
function ENT:PressToggle(ply)
    if not self:CanManage(ply) then notify(ply, "Нет доступа к банковскому станку.", 255, 100, 100) return false end
    if self:GetBroken() then notify(ply, "Станок неисправен.", 255, 120, 80) return false end
    if self:GetActive() then
        self:SetActive(false)
        notify(ply, "Печать остановлена.", 200, 220, 255)
    else
        if self:GetHeat() >= self.OverheatAt then
            notify(ply, "Станок перегрет — сначала охладите.", 255, 140, 80)
            return false
        end
        self:SetActive(true)
        self.NextPrint = CurTime() + self:GetPrintInterval()
        notify(ply, "Печать запущена: " .. (GRM.Format and GRM.Format(self:AmountPerCycle()) or tostring(self:AmountPerCycle())) .. " GRM за " .. self:GetPrintInterval() .. " сек.", 100, 220, 130)
    end
    return true
end

function ENT:PressUpgrade(ply)
    if not self:CanManage(ply) then notify(ply, "Нет доступа к банковскому станку.", 255, 100, 100) return false end
    local lvl = math.floor(self:GetSpeedLevel() or 0)
    if lvl >= self.MaxSpeedLevel then notify(ply, "Скорость уже максимальная (ур. " .. lvl .. ").", 255, 190, 90) return false end
    local cost = self.UpgradeBaseCost * (lvl + 1)
    if GRM.HasMoney and not GRM.HasMoney(ply, cost) then notify(ply, "Нужно: " .. (GRM.Format and GRM.Format(cost) or tostring(cost)), 255, 120, 80) return false end
    if GRM.TakeMoney then GRM.TakeMoney(ply, cost, "Прокачка печатного станка") end
    self:SetSpeedLevel(lvl + 1)
    self:SetPrintAmount(self:AmountPerCycle())
    self:EmitSound("buttons/button14.wav", 65, 115)
    notify(ply, "Скорость станка: ур. " .. (lvl + 1) .. " — " .. (GRM.Format and GRM.Format(self:AmountPerCycle()) or tostring(self:AmountPerCycle())) .. " GRM / " .. self:GetPrintInterval() .. " сек.", 100, 220, 130)
    return true
end

function ENT:PressCool(ply)
    if not self:CanManage(ply) then notify(ply, "Нет доступа к банковскому станку.", 255, 100, 100) return false end
    if self:GetHeat() <= 0 then notify(ply, "Станок не нагрет.", 180, 220, 255) return false end
    if GRM.HasMoney and not GRM.HasMoney(ply, self.CoolCost) then notify(ply, "Нужно: " .. (GRM.Format and GRM.Format(self.CoolCost) or tostring(self.CoolCost)), 255, 120, 80) return false end
    if GRM.TakeMoney then GRM.TakeMoney(ply, self.CoolCost, "Охлаждение печатного станка") end
    self:SetHeat(0)
    self:EmitSound("ambient/energy/spark6.wav", 60, 140)
    notify(ply, "Станок охлаждён.", 100, 220, 255)
    return true
end

function ENT:Use(ply)
    if not IsValid(ply) then return end
    if self:CanManage(ply) then
        if GRM.Notify then
            GRM.Notify(ply, "Управляйте станком через терминал (модель holo_wall_unit) рядом со станком.", 200, 220, 255)
        end
    elseif GRM.Notify then
        GRM.Notify(ply, "Печатный станок банка. Доступ: сотрудники с правом экономики.", 200, 200, 120)
    end
end

print("[GRM] Money Press entity loaded (находка 178)")
