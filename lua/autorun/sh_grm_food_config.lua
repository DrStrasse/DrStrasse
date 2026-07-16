--[[
    GRM Food System - Конфиг
    Файл общий: загружается и на сервере, и на клиенте.
]]

if SERVER then
    AddCSLuaFile()
end

GRM = GRM or {}
GRM.Food = GRM.Food or {}

GRM.Food.Config = {
    -- Голод
    HungerMax = 100,
    HungerDrainPerSecond = 0.02,
    HungerDamageInterval = 10,
    HungerDamageAmount = 2,
    HungerWarningThreshold = 20,

    -- Лечение от еды не выше максимального HP игрока
    RespectMaxHealth = true,

    -- Расстояние использования/покупки у автомата
    VendingUseDistance = 150,

    -- Еда
    FoodItems = {
        ["grm_food_apple"] = {
            name = "Яблоко",
            model = "models/props/cs_italy/orange.mdl",
            hungerRestore = 15,
            healthRestore = 2,
            price = 20,
        },

        ["grm_food_bread"] = {
            name = "Хлеб",
            model = "models/props_junk/garbage_bag001a.mdl",
            hungerRestore = 25,
            healthRestore = 3,
            price = 44,
        },

        ["grm_food_water"] = {
            name = "Вода",
            model = "models/props_junk/garbage_plasticbottle003a.mdl",
            hungerRestore = 10,
            healthRestore = 0,
            price = 10,
        },

        ["grm_food_soda"] = {
            name = "Газировка",
            model = "models/props_junk/PopCan01a.mdl",
            hungerRestore = 5,
            healthRestore = 0,
            price = 15,
        },
    },

    -- Автомат
    VendingMachineModel = "models/props_interiors/VendingMachineSoda01a.mdl",

    VendingMachineItems = {
        "grm_food_apple",
        "grm_food_bread",
        "grm_food_water",
        "grm_food_soda",
    },
}
