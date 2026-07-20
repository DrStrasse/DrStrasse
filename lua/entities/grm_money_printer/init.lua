AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("GRM_Printer_Broken")

function ENT:Initialize()
    self:SetModel("models/props_junk/cardboard_box004a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)

    self:SetPrinted(0)
    self:SetMaxMoney(5000)
    self:SetActive(true)

    self.PrintTimer = 0
    self.PrintInterval = 30 -- секунд между печатью
    self.BreakChance = 0.05 -- 5% шанс сломаться

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
end

function ENT:Think()
    if not self:GetActive() then return end

    self.PrintTimer = self.PrintTimer + 1
    if self.PrintTimer >= self.PrintInterval then
        self.PrintTimer = 0

        -- Шанс сломаться
        if math.random() < self.BreakChance then
            self:SetActive(false)
            net.Start("GRM_Printer_Broken")
                net.WriteEntity(self)
            net.Broadcast()
            return
        end

        -- Печать денег
        local amount = math.random(100, 500)
        self:SetPrinted(self:GetPrinted() + amount)

        -- Если достигли максимума - снять деньги
        if self:GetPrinted() >= self:GetMaxMoney() then
            self:CollectMoney()
        end
    end

    self:NextTick(CurTime() + 1)
end

function ENT:CollectMoney()
    local amount = self:GetPrinted()
    if amount <= 0 then return end

    -- Найти владельца (кто поставил)
    local owner = self:GetOwner()
    if IsValid(owner) and owner:IsPlayer() then
        if GRM and GRM.GiveMoney then
            GRM.GiveMoney(owner, amount, "Денежный принтер")
            if GRM.Notify then
                GRM.Notify(owner, "Принтер выплатил: " .. GRM.Format(amount), 100, 220, 100)
            end
        end
    end

    self:SetPrinted(0)
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    -- Суперадмин может настроить
    if ply:IsSuperAdmin() then
        self:OpenConfig(ply)
        return
    end

    -- Владелец может снять деньги
    if self:GetOwner() == ply then
        self:CollectMoney()
        if GRM.Notify then
            GRM.Notify(ply, "Снято: " .. GRM.Format(self:GetPrinted()), 100, 220, 100)
        end
    else
        if GRM.Notify then
            GRM.Notify(ply, "Это не ваш принтер", 255, 100, 100)
        end
    end
end

function ENT:OpenConfig(ply)
    -- TODO: UI настройки
    ply:ChatPrint("[Принтер] Настройка через Toolgun")
end

-- Toolgun настройка
if SERVER then
    concommand.Add("grm_printer_config", function(ply, cmd, args)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end

        local ent = ply:GetEyeTrace().Entity
        if not IsValid(ent) or ent:GetClass() ~= "grm_money_printer" then
            ply:ChatPrint("[Принтер] Наведитесь на принтер")
            return
        end

        local key = args[1]
        local value = tonumber(args[2])

        if key == "interval" and value then
            ent.PrintInterval = value
            ply:ChatPrint("[Принтер] Интервал: " .. value .. " сек")
        elseif key == "max" and value then
            ent:SetMaxMoney(value)
            ply:ChatPrint("[Принтер] Максимум: " .. value)
        elseif key == "break" and value then
            ent.BreakChance = value / 100
            ply:ChatPrint("[Принтер] Шанс поломки: " .. value .. "%")
        end
    end)
end

print("[GRM] Money Printer entity loaded")
