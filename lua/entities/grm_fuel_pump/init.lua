AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_wasteland/gaspump001a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    if self:GetFuelKind() == "" then self:SetFuelKind("petrol") end
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
end

local function findVeh(pos)
    local VK = GRM.VehicleKeys or _G.VK
    for _, e in ipairs(ents.FindInSphere(pos, 180)) do
        if IsValid(e) and VK and VK.IsVehicle and VK.IsVehicle(e) then return e end
    end
end

function ENT:Use(ply)
    if not IsValid(ply) then return end
    if self:GetBusy() and self:GetUser() ~= ply then
        if GRM.Notify then GRM.Notify(ply, "Колонка занята.", 255, 180, 80) end
        return
    end
    if self:GetBusy() and self:GetUser() == ply then
        self:SetBusy(false)
        self:SetUser(NULL)
        if timer.Exists("GRM_FuelPump_" .. self:EntIndex()) then timer.Remove("GRM_FuelPump_" .. self:EntIndex()) end
        if GRM.Notify then GRM.Notify(ply, "Пистолет повешен.", 180, 210, 140) end
        return
    end
    local veh = findVeh(self:GetPos())
    if not IsValid(veh) then
        if GRM.Notify then GRM.Notify(ply, "Подгоните машину к колонке.", 255, 180, 80) end
        return
    end
    if GRM.Fuel then GRM.Fuel.ApplyNW(veh) end
    local needType = veh:GetNWString("GRM_FuelType", "petrol")
    if needType ~= self:GetFuelKind() then
        if GRM.Notify then GRM.Notify(ply, "Не тот тип топлива. Нужен: " .. tostring((GRM.Fuel.Types or {})[needType] or needType), 255, 120, 80) end
        return
    end
    self:SetBusy(true)
    self:SetUser(ply)
    self:EmitSound("ambient/water/leak_1.wav", 55, 90)
    local idx = self:EntIndex()
    timer.Create("GRM_FuelPump_" .. idx, 0.4, 0, function()
        if not IsValid(self) or not IsValid(ply) or not IsValid(veh) then
            if IsValid(self) then self:SetBusy(false) self:SetUser(NULL) end
            timer.Remove("GRM_FuelPump_" .. idx)
            return
        end
        if ply:GetPos():DistToSqr(self:GetPos()) > 220 * 220 then
            self:SetBusy(false) self:SetUser(NULL)
            timer.Remove("GRM_FuelPump_" .. idx)
            return
        end
        local price = (GRM.Fuel and GRM.Fuel.PricePerLiter) or 8
        if GRM.HasMoney and not GRM.HasMoney(ply, price) then
            if GRM.Notify then GRM.Notify(ply, "Деньги кончились.", 255, 140, 80) end
            self:SetBusy(false) self:SetUser(NULL)
            timer.Remove("GRM_FuelPump_" .. idx)
            return
        end
        local added = GRM.Fuel and select(1, GRM.Fuel.AddLiters(veh, 1.2, self:GetFuelKind())) or 0
        if added <= 0 then
            if GRM.Notify then GRM.Notify(ply, "Бак полный.", 180, 210, 140) end
            self:SetBusy(false) self:SetUser(NULL)
            timer.Remove("GRM_FuelPump_" .. idx)
            return
        end
        if GRM.TakeMoney then GRM.TakeMoney(ply, math.ceil(price * added), "Заправка") end
    end)
    if GRM.Notify then GRM.Notify(ply, "Заправка пошла. E ещё раз — остановить.", 120, 220, 140) end
end
