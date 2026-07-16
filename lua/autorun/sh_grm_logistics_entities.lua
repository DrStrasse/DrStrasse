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
    else
        function ENT:Draw() self:DrawModel() end
    end

    scripted_ents.Register(ENT, class)
end

register("grm_logistics_loading", "Точка погрузки логистики", "loading", true)
register("grm_logistics_warehouse", "Склад фракции", "warehouse", true)
register("grm_logistics_armory", "Оружейный шкаф фракции", "armory", true)
register("grm_logistics_crate", "Грузовой ящик", "crate", false)
