AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("grm_ore_buyer_open")
util.AddNetworkString("grm_ore_sell")
util.AddNetworkString("grm_ore_buyer_give_jackhammer")
util.AddNetworkString("grm_ore_buyer_return_jackhammer")  -- новое

function ENT:Initialize()
    self:SetModel(self.Model)
    self:SetSolid(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_NPC)

    self:SetUseType(SIMPLE_USE)
    self:SetAutomaticFrameAdvance(true)

    self:SetupIdleAnimation()
end

function ENT:SetupIdleAnimation()
    local seq = self:SelectWeightedSequence(ACT_IDLE)
    if seq and seq >= 0 then
        self:ResetSequence(seq)
        self:SetPlaybackRate(1)
        self:SetCycle(0)
        return
    end

    seq = self:LookupSequence("idle_all")
    if seq and seq >= 0 then
        self:ResetSequence(seq)
        self:SetPlaybackRate(1)
        self:SetCycle(0)
        return
    end

    local fallbacks = {"idle", "idle_unarmed", "stand", "ref"}
    for _, name in ipairs(fallbacks) do
        seq = self:LookupSequence(name)
        if seq and seq >= 0 then
            self:ResetSequence(seq)
            self:SetPlaybackRate(1)
            self:SetCycle(0)
            return
        end
    end
end

function ENT:Think()
    self:NextThink(CurTime() + 0.02)
    return true
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    net.Start("grm_ore_buyer_open")
        net.WriteTable(GRM.OrePrices or {})
    net.Send(activator)
end

list.Set("SpawnableEntities", "grm_ore_buyer", {
    PrintName = "Скупщик руды",
    ClassName = "grm_ore_buyer",
    Category = "GRM MINE"
})

-- ============================================================
-- ОБРАБОТЧИК ПРОДАЖИ
-- ============================================================
net.Receive("grm_ore_sell", function(_, ply)
    if not IsValid(ply) then return end

    local oreType = net.ReadString()
    local itemID = "ore_" .. oreType

    local inv = GRM.Inventory.GetPlayerInv(ply)
    if not inv then
        GRM.Notify(ply, "Ошибка инвентаря", 255, 100, 100)
        return
    end

    local slotsToRemove = {}
    local totalCount = 0
    for i, slot in pairs(inv.slots) do
        if slot and slot.id == itemID then
            local count = slot.count or 1
            table.insert(slotsToRemove, { idx = i, count = count })
            totalCount = totalCount + count
        end
    end

    if totalCount <= 0 then
        GRM.Notify(ply, "У вас нет этой руды", 255, 100, 100)
        return
    end

    local price = GRM.OrePrices[oreType]
    if not price or price <= 0 then
        GRM.Notify(ply, "Цена не установлена", 255, 100, 100)
        return
    end

    local removedCount = 0
    for _, data in ipairs(slotsToRemove) do
        local ok = GRM.Inventory.RemoveFromSlot(ply, data.idx, data.count)
        if ok then
            removedCount = removedCount + data.count
        end
    end

    if removedCount > 0 then
        local total = removedCount * price
        GRM.GiveMoney(ply, total)
        GRM.Notify(ply, "Продано " .. removedCount .. " " .. oreType .. " за " .. GRM.Format(total), 100, 220, 100)
    else
        GRM.Notify(ply, "Ошибка удаления", 255, 100, 100)
    end
end)

-- ============================================================
-- ОБРАБОТЧИК ВЫДАЧИ БУРА
-- ============================================================
net.Receive("grm_ore_buyer_give_jackhammer", function(_, ply)
    if not IsValid(ply) then return end

    if ply:HasWeapon("weapon_jackhammer_sd") then
        GRM.Notify(ply, "Ошибка. У вас уже есть бур.", 255, 100, 100)
        return
    end

    ply:Give("weapon_jackhammer_sd")
    GRM.Notify(ply, "Вы получили бур!", 100, 220, 100)
end)

-- ============================================================
-- ОБРАБОТЧИК СДАЧИ БУРА
-- ============================================================
net.Receive("grm_ore_buyer_return_jackhammer", function(_, ply)
    if not IsValid(ply) then return end

    if not ply:HasWeapon("weapon_jackhammer_sd") then
        GRM.Notify(ply, "У вас нет бура, чтобы сдать.", 255, 100, 100)
        return
    end

    ply:StripWeapon("weapon_jackhammer_sd")
    GRM.Notify(ply, "Вы сдали бур.", 100, 220, 100)
end)

print("[GRM Ore Buyer] Сервер загружен (с выдачей и сдачей бура)")
