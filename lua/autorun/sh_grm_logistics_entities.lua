if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Logistics = GRM.Logistics or {}
local L = GRM.Logistics

if L.EntitiesRegistered then return end
L.EntitiesRegistered = true

local function register(class, name, kind, spawnable)
    local ENT = {}
    ENT.Type = "anim"
    ENT.Base = "base_gmodentity"
    ENT.PrintName = name
    ENT.Category = "GRM Faction Logistics"
    ENT.Spawnable = spawnable
    ENT.AdminSpawnable = spawnable
    ENT.LogisticsKind = kind

    function ENT:SetupDataTables()
        self:NetworkVar("String", 0, "LogisticsID")
        self:NetworkVar("String", 1, "FactionName")
        self:NetworkVar("String", 2, "NetworkID")
        self:NetworkVar("String", 3, "PointName")
        self:NetworkVar("String", 4, "CargoKind")
        self:NetworkVar("String", 5, "CargoID")
        self:NetworkVar("Int", 0, "CargoAmount")
        self:NetworkVar("Int", 1, "Capacity")
        self:NetworkVar("Bool", 0, "FactionMode")
    end

    if SERVER then
        function ENT:Initialize()
            if GRM.Logistics and GRM.Logistics.InitializeEntity then GRM.Logistics.InitializeEntity(self) end
        end

        function ENT:Use(ply)
            if GRM.Logistics and GRM.Logistics.UseEntity then GRM.Logistics.UseEntity(ply, self) end
        end

        -- Barney-склад должен постоянно обновлять анимацию idle, иначе
        -- humanoid-модель остаётся в T-позе.
        function ENT:Think()
            if self.LogisticsKind=="warehouse" then
                self:NextThink(CurTime()+0.1)
                return true
            end
        end

        -- PERM-DATA (Код 112): сохранение настроек для /permadd
        function ENT:GetPermData()
            local d = {}
            d.factionName = self:GetFactionName()
            d.networkID   = self:GetNetworkID()
            d.pointName   = self:GetPointName()
            d.factionMode = self:GetFactionMode()
            d.cargoKind   = self:GetCargoKind()
            d.cargoID     = self:GetCargoID()
            d.cargoAmount = self:GetCargoAmount()
            d.capacity    = self:GetCapacity()
            -- Дополнительные данные из GRM.Logistics
            if GRM.Logistics then
                if self.LogisticsKind == "warehouse" then
                    local wd = GRM.Logistics.GetWarehouseData and GRM.Logistics.GetWarehouseData(self)
                    if wd then d.warehouseData = wd end
                elseif self.LogisticsKind == "armory" then
                    local ad = GRM.Logistics.GetArmoryData and GRM.Logistics.GetArmoryData(self)
                    if ad then d.armoryData = ad end
                end
            end
            return d
        end

        function ENT:ApplyPermData(data)
            if not data then return end
            if data.factionName then self:SetFactionName(data.factionName) end
            if data.networkID then self:SetNetworkID(data.networkID) end
            if data.pointName then self:SetPointName(data.pointName) end
            if data.factionMode ~= nil then self:SetFactionMode(data.factionMode) end
            if data.cargoKind then self:SetCargoKind(data.cargoKind) end
            if data.cargoID then self:SetCargoID(data.cargoID) end
            if data.cargoAmount then self:SetCargoAmount(data.cargoAmount) end
            if data.capacity then self:SetCapacity(data.capacity) end
            -- Восстановление данных склада/шкафа
            if GRM.Logistics then
                if data.warehouseData and GRM.Logistics.RestoreWarehouseData then
                    GRM.Logistics.RestoreWarehouseData(self, data.warehouseData)
                end
                if data.armoryData and GRM.Logistics.RestoreArmoryData then
                    GRM.Logistics.RestoreArmoryData(self, data.armoryData)
                end
            end
        end
    else
        function ENT:Draw() self:DrawModel() end
    end

    scripted_ents.Register(ENT, class)
end

register("grm_logistics_loading", "Точка погрузки логистики", "loading", true)
register("grm_logistics_warehouse", "Склад фракции", "warehouse", true)
register("grm_logistics_armory", "Оружейный шкаф фракции", "armory", true)
register("grm_logistics_crate", "Грузовой ящик", "crate", false)
