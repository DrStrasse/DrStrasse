AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "Ore Chunk"
ENT.Category = "GRM MINE"
ENT.Spawnable = false

ENT.Model = "models/props_mining/rock_caves01b.mdl"

local ORES = {
    copper = { color = Color(184, 115, 51), material = "models/shiny" },
    gold = { color = Color(255, 215, 0), material = "models/shiny" },
    aluminum = { color = Color(200, 200, 210), material = "" },
    platinum = { color = Color(180, 180, 200), material = "models/props_combine/tprings_globe" }
}

function ENT:Initialize()
    if SERVER then
        self:SetModel(self.Model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_VPHYSICS)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:Wake()
        end
        self:SetUseType(SIMPLE_USE)
        print("[GRM Ore Chunk] Создан")
    end
end

function ENT:SetOreType(oreType)
    self.OreType = oreType
    local data = ORES[oreType]
    if data then
        self:SetColor(data.color)
        if data.material and data.material ~= "" then
            self:SetMaterial(data.material)
        end
        print("[GRM Ore Chunk] Установлен тип:", oreType)
    end
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    print("[GRM Ore Chunk] Игрок", activator:Nick(), "подбирает руду")

    local itemID = "ore_" .. self.OreType
    if not GRM.Inventory or not GRM.Inventory.ItemDefs or not GRM.Inventory.ItemDefs[itemID] then
        activator:PrintMessage(HUD_PRINTTALK, "[Ошибка] Предмет не зарегистрирован в инвентаре.")
        return
    end

    local notAdded = GRM.Inventory.AddItem(activator, itemID, 1)
    if notAdded == 0 then
        activator:EmitSound("items/ammo_pickup.wav")
        activator:PrintMessage(HUD_PRINTTALK, "Вы подобрали кусок " .. self.OreType .. " руды.")
        self:Remove()
    else
        activator:PrintMessage(HUD_PRINTTALK, "Инвентарь полон! Не хватает места.")
    end
end
