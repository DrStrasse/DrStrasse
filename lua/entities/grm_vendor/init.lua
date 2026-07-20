AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("GRM_Vendor_Open")
util.AddNetworkString("GRM_Vendor_Buy")
util.AddNetworkString("GRM_Vendor_Sell")

function ENT:Initialize()
    self:SetModel(GRM.Vendor.Models[self.VendorType] or "models/kleiner.mdl")
    self:SetSolid(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_NPC)
    self:SetUseType(SIMPLE_USE)
    self:SetAutomaticFrameAdvance(true)
    self:SetupIdleAnimation()
end

function ENT:SetupIdleAnimation()
    local seq = self:SelectWeightedSequence(ACT_IDLE)
    if seq and seq >= 0 then self:ResetSequence(seq) self:SetPlaybackRate(1) return end
    for _, name in ipairs({"idle_all","idle","idle_unarmed","stand","ref"}) do
        local seq = self:LookupSequence(name)
        if seq and seq >= 0 then self:ResetSequence(seq) self:SetPlaybackRate(1) return end
    end
end

function ENT:Think() self:NextThink(CurTime() + 0.02) return true end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > (GRM.Vendor.Config.UseDistance^2) then return end

    local cat = GRM.Vendor.GetCatalog(self.VendorType)
    local prices = {}
    for id, item in pairs(cat) do
        local price = (self.CustomPrices and self.CustomPrices[id]) or item.price
        prices[id] = {
            price = price, name = item.name, model = item.model, desc = item.desc,
            category = item.category, license = item.license,
            hunger = item.hunger, health = item.health, maxStack = item.maxStack
        }
    end

    net.Start("GRM_Vendor_Open")
        net.WriteEntity(self)
        net.WriteString(self.VendorType)
        net.WriteTable(prices)
    net.Send(ply)
end

-- ===== ПОКУПКА =====
net.Receive("GRM_Vendor_Buy", function(_, ply)
    local ent = net.ReadEntity()
    local itemID = net.ReadString()
    if not IsValid(ent) or ent:GetClass() ~= "grm_vendor" then return end
    if ply:GetPos():DistToSqr(ent:GetPos()) > (GRM.Vendor.Config.UseDistance^2) then return end

    local item = GRM.Vendor.GetItem(ent.VendorType, itemID)
    if not item then GRM.Notify(ply, "Товар не найден", 255,100,100) return end

    local price = (ent.CustomPrices and ent.CustomPrices[itemID]) or item.price
    if not GRM.HasMoney(ply, price) then GRM.Notify(ply, "Недостаточно средств. Нужно: "..GRM.Format(price), 255,100,100) return end

    if ent.VendorType == "weapon" and not GRM.Vendor.CanBuyWeapon(ply, item) then
        GRM.Notify(ply, "Нет лицензии на это оружие", 255,100,100) return
    end

    if ent.CustomLimits and ent.CustomLimits[itemID] then
        local count = 0
        if ent.VendorType == "weapon" then
            for _, wep in ipairs(ply:GetWeapons()) do if wep:GetClass() == itemID then count = count + 1 end end
        else
            count = GRM.Inventory.CountItem(ply, itemID)
        end
        if count >= ent.CustomLimits[itemID] then GRM.Notify(ply, "Лимит: "..ent.CustomLimits[itemID], 255,100,100) return end
    end

    GRM.TakeMoney(ply, price, "Покупка у торгаша: "..item.name)

    if ent.VendorType == "weapon" then
        ply:Give(itemID)
        GRM.Notify(ply, "Куплено: "..item.name.." за "..GRM.Format(price), 100,220,100)
    elseif ent.VendorType == "food" or ent.VendorType == "rare" then
        GRM.Inventory.AddItem(ply, itemID, 1)
        GRM.Notify(ply, "Куплено: "..item.name, 100,220,100)
    elseif ent.VendorType == "ore" then
        GRM.Inventory.AddItem(ply, itemID, 1)
        GRM.Notify(ply, "Куплено: "..item.name, 100,220,100)
    end
end)

-- ===== СКУПКА =====
net.Receive("GRM_Vendor_Sell", function(_, ply)
    local ent = net.ReadEntity()
    local itemID = net.ReadString()
    local count = net.ReadUInt(16)
    if not IsValid(ent) or ent:GetClass() ~= "grm_vendor" then return end
    if ply:GetPos():DistToSqr(ent:GetPos()) > (GRM.Vendor.Config.UseDistance^2) then return end

    local sellPrice = GRM.Vendor.GetSellPrice(ply, ent.VendorType, itemID)
    if sellPrice <= 0 then GRM.Notify(ply, "Этот товар не скупается", 255,100,100) return end

    local removed = 0
    if ent.VendorType == "weapon" then
        for _, wep in ipairs(ply:GetWeapons()) do
            if wep:GetClass() == itemID and removed < count then
                ply:StripWeapon(itemID)
                removed = removed + 1
            end
        end
        if removed < count then
            removed = removed + GRM.Inventory.RemoveItem(ply, "weapon:"..itemID, count - removed)
        end
    else
        removed = count - GRM.Inventory.RemoveItem(ply, itemID, count)
    end

    if removed > 0 then
        local total = removed * sellPrice
        GRM.GiveMoney(ply, total, "Скупка у торгаша: "..itemID)
        GRM.Notify(ply, "Продано "..removed.."x за "..GRM.Format(total), 100,220,100)
    else
        GRM.Notify(ply, "У вас нет этого предмета", 255,100,100)
    end
end)

-- Для перм-энтити (Код 50)
function ENT:GetPermData()
    return {
        vendorType = self.VendorType,
        customPrices = self.CustomPrices,
        customLimits = self.CustomLimits,
    }
end

function ENT:ApplyPermData(data)
    if not data then return end
    self.VendorType = data.vendorType or "weapon"
    self.CustomPrices = data.customPrices
    self.CustomLimits = data.customLimits
    if GRM.Vendor.Models[self.VendorType] then
        self:SetModel(GRM.Vendor.Models[self.VendorType])
        self:SetupIdleAnimation()
    end
end

print("[GRM Vendor] Entity server loaded")