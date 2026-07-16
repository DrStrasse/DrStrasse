--[[--------------------------------------------------------------------
    GRM Factory Full Cycle — shared entity registry
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.FactoryCycle = GRM.FactoryCycle or {}
local FC = GRM.FactoryCycle

if FC.EntitiesRegistered then return end
FC.EntitiesRegistered = true

local function registerEntity(className, printName, kind, spawnable)
    local ENT = {}
    ENT.Type = "anim"
    ENT.Base = "base_gmodentity"
    ENT.PrintName = printName
    ENT.Category = "GRM Factory — Full Cycle"
    ENT.Spawnable = spawnable == true
    ENT.AdminSpawnable = spawnable == true
    ENT.FactoryKind = kind

    function ENT:SetupDataTables()
        self:NetworkVar("String", 0, "FactoryID")
        self:NetworkVar("String", 1, "RecipeID")
        self:NetworkVar("String", 2, "ProductID")
        self:NetworkVar("Bool", 0, "IsWorking")
        self:NetworkVar("Int", 0, "Stock")
        self:NetworkVar("Int", 1, "ProductCount")
        self:NetworkVar("Float", 0, "CraftStart")
        self:NetworkVar("Float", 1, "CraftDuration")
        self:NetworkVar("Float", 2, "NextRefill")
    end

    if SERVER then
        function ENT:Initialize()
            if GRM and GRM.FactoryCycle and GRM.FactoryCycle.InitializeEntity then
                GRM.FactoryCycle.InitializeEntity(self, self.FactoryKind)
            end
        end

        function ENT:Use(ply)
            if GRM and GRM.FactoryCycle and GRM.FactoryCycle.UseEntity then
                GRM.FactoryCycle.UseEntity(ply, self)
            end
        end

        function ENT:OnRemove()
            if GRM and GRM.FactoryCycle and GRM.FactoryCycle.OnEntityRemoved then
                GRM.FactoryCycle.OnEntityRemoved(self)
            end
        end
    else
        function ENT:Draw()
            self:DrawModel()
        end
    end

    scripted_ents.Register(ENT, className)
end

registerEntity("grm_fc_gpu_station", "Станок сборки GPU", "gpu_station", true)
registerEntity("grm_fc_components_station", "Станок комплектующих", "components_station", true)
registerEntity("grm_fc_weapon_station", "Кустарный оружейный верстак", "weapon_station", true)
registerEntity("grm_fc_furnace", "Печь переплавки брака", "furnace", true)
registerEntity("grm_fc_weapon_buyer", "Скупщик оружия", "weapon_buyer", true)
registerEntity("grm_fc_weapon_locker", "Общий оружейный шкаф", "weapon_locker", true)
registerEntity("grm_fc_storage", "Склад продукции", "storage", true)
registerEntity("grm_fc_scrap_bin", "Мусорка металлолома", "scrap_bin", true)
registerEntity("grm_fc_terminal", "Терминал продажи GPU", "terminal", true)
registerEntity("grm_fc_gpu", "Видеокарта", "gpu_product", false)
registerEntity("grm_fc_product", "Заводской продукт", "component_product", false)
