--[[--------------------------------------------------------------------
    GRM Factory Full Cycle — configuration

    Cycle:
      Scrap bin -> scrap_metal -> component station -> components_box
      -> GPU station / weapon bench -> physical product / weapon.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.FactoryCycle = GRM.FactoryCycle or {}
local FC = GRM.FactoryCycle

FC.Config = FC.Config or {
    UseDistance = 180,
    TerminalStorageRange = 900,
    ScrapBinMax = 40,
    ScrapBinStart = 25,
    ScrapRefillEvery = 60,
    ScrapRefillAmount = 2,
    SaveOnShutdown = false, -- manual map save by default

    -- Мини-игра со стрелками для компонентов и оружия.
    QTE = {
        -- Скорость QTE снижена: у игрока больше времени на нажатие.
        gpu = { steps = 6, stepTime = 1.55, successPercent = 0.70 },
        components = { steps = 5, stepTime = 1.8, successPercent = 0.70 },
        weapons = { steps = 8, stepTime = 1.35, successPercent = 0.75 },
        PartialRefundPercent = 0.25,
    },

    Models = {
        gpu = "models/props_lab/reciever01b.mdl",
        gpuStation = "models/props_wasteland/controlroom_desk001a.mdl",
        componentsStation = "models/mosi/fallout4/furniture/workstations/workshopbench.mdl",
        weaponStation = "models/mosi/fallout4/furniture/workstations/weaponworkbench01.mdl",
        furnace = "models/props_forest/furnace01.mdl",
        weaponBuyer = "models/Humans/Group03/male_03.mdl",
        weaponLocker = "models/props_lab/lockers.mdl",
        storage = "models/props_junk/wood_crate002a.mdl",
        scrapBin = "models/props_junk/trashdumpster01a.mdl", -- модель мусорок
        terminal = "models/props/cs_office/computer.mdl",
        components = "models/props_junk/cardboard_box001a.mdl",
        defectiveComponents = "models/props/cs_office/cardboard_box01.mdl",
    },

    GPURecipes = {
        gpu_basic = {
            id = "gpu_basic", name = "Базовая видеокарта",
            input = { components_box = 1 }, duration = 7,
            output = "gpu_basic", color = { r = 80, g = 170, b = 255 },
        },
        gpu_mid = {
            id = "gpu_mid", name = "Средняя видеокарта",
            input = { components_box = 2 }, duration = 13,
            output = "gpu_mid", color = { r = 90, g = 220, b = 115 },
        },
        gpu_premium = {
            id = "gpu_premium", name = "Премиум видеокарта",
            input = { components_box = 4 }, duration = 21,
            output = "gpu_premium", color = { r = 240, g = 175, b = 55 },
        },
    },

    ComponentRecipes = {
        components_box = {
            id = "components_box", name = "Ящик комплектующих",
            input = { scrap_metal = 5 }, duration = 8,
            output = "components_box", outputCount = 1,
        },
    },

    -- Кастомные ArcCW classname, присланные для вашей сборки.
    WeaponRecipes = {
        arccw_makarov = {
            id = "arccw_makarov", weapon = "arccw_makarov", name = "Макаров",
            input = { scrap_metal = 5, components_box = 1 }, duration = 12,
        },
        arccw_p228 = {
            id = "arccw_p228", weapon = "arccw_p228", name = "P228",
            input = { scrap_metal = 5, components_box = 1 }, duration = 16,
        },
        arccw_p90 = {
            id = "arccw_p90", weapon = "arccw_p90", name = "P90",
            input = { scrap_metal = 10, components_box = 3 }, duration = 27,
        },
        arccw_m4a1 = {
            id = "arccw_m4a1", weapon = "arccw_m4a1", name = "M4A1",
            input = { scrap_metal = 10, components_box = 3 }, duration = 34,
        },
        arccw_rpg7 = {
            id = "arccw_rpg7", weapon = "arccw_rpg7", name = "РПГ-7",
            input = { scrap_metal = 30, components_box = 6 }, duration = 48,
        },
    },

    -- Переплавка брака возвращает только часть исходного металла.
    FurnaceRecipes = {
        defective_components = {
            id = "defective_components", name = "Переплавить бракованные комплектующие",
            input = { defective_components = 1 }, duration = 5,
            output = "scrap_metal", outputCount = 2,
        },
        defective_weapon_parts = {
            id = "defective_weapon_parts", name = "Переплавить бракованные оружейные детали",
            input = { defective_weapon_parts = 1 }, duration = 8,
            output = "scrap_metal", outputCount = 4,
        },
        defective_gpu = {
            id = "defective_gpu", name = "Переплавить бракованную видеокарту",
            input = { defective_gpu = 1 }, duration = 10,
            output = "scrap_metal", outputCount = 5,
        },
    },

    -- Оружейный рынок. Цены и стартовый запас редактируются superadmin
    -- через grm_weapon_buyer_admin у выбранного скупщика.
    WeaponMarket = {
        SellPercent = 0.50, -- игрок получает 50% цены покупки
        Weapons = {
            arccw_makarov = { name = "Макаров", price = 2500, seedStock = 0 },
            arccw_p228 = { name = "P228", price = 3500, seedStock = 0 },
            arccw_p90 = { name = "P90", price = 8000, seedStock = 0 },
            arccw_m4a1 = { name = "M4A1", price = 10000, seedStock = 0 },
            arccw_rpg7 = { name = "РПГ-7", price = 25000, seedStock = 0 },
        },
        LockerBlockedWeapons = {
            weapon_fists = true,
            weapon_physgun = true,
            weapon_gravgun = true,
            gmod_tool = true,
            gmod_camera = true,
            vehicle_keys_swep = true,
        },
    },

    SellPrices = {
        gpu_basic = 500,
        gpu_mid = 1000,
        gpu_premium = 1600,
    },
}
