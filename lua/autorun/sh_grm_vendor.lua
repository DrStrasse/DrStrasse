--[[--------------------------------------------------------------------
    GRM Vendor Framework v1.0 (Код 71)
    Единый фреймворк торгашей: оружие / руда / еда / редкости.
    Один энтити-класс grm_vendor, тип задаётся в data (vendorType).
    Каталоги — shared, расширяются аддонами.
    UI — единый «киоск» в стиле HUD v10.2 (Roboto, тёмная тема).
    Админка — toolgun grm_vendor (спавн/настройка цен/лимитов).
    Персистентность — через sh_grm_perm_entities (Код 50).
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Vendor = GRM.Vendor or {}
local V = GRM.Vendor

-- ============================================================
-- КОНФИГ
-- ============================================================
V.Config = {
    UseDistance     = 120,
    MaxVendors      = 16,           -- лимит на карту (доп. к perm)
    SellMultiplier  = 0.4,          -- скупка = 40% от цены продажи
}

-- ============================================================
-- МОДЕЛИ NPC ПО ТИПУ
-- ============================================================
V.Models = {
    weapon = "models/mossman.mdl",
    ore    = "models/kleiner.mdl",
    food   = "models/barney.mdl",
    rare   = "models/gman_high.mdl",
}

-- ============================================================
-- КАТАЛОГИ (shared, регистрируются до загрузки энтити)
-- ============================================================
V.Catalogs = V.Catalogs or {}

-- 1) ОРУЖИЕ: class -> { name, price, model, desc, category, license }
V.Catalogs.weapon = V.Catalogs.weapon or {
    ["weapon_ak472"]     = { name = "AK-47",              price = 12000, model = "models/weapons/w_rif_ak47.mdl",       category = "Автоматы",  license = "gun" },
    ["weapon_m42"]       = { name = "M4A1",               price = 13000, model = "models/weapons/w_rif_m4a1.mdl",       category = "Автоматы",  license = "gun" },
    ["weapon_glock2"]    = { name = "Glock-18",           price = 3500,  model = "models/weapons/w_pist_glock18.mdl",   category = "Пистолеты", license = "gun" },
    ["weapon_deagle2"]   = { name = "Desert Eagle",       price = 6500,  model = "models/weapons/w_pist_deagle.mdl",    category = "Пистолеты", license = "gun" },
    ["weapon_shotgun2"]  = { name = "Remington 870",      price = 9000,  model = "models/weapons/w_shotgun.mdl",        category = "Дробовики", license = "gun" },
    ["weapon_mp52"]      = { name = "MP5",                price = 8500,  model = "models/weapons/w_smg_mp5.mdl",        category = "ПП",        license = "gun" },
    ["arrest_stick"]     = { name = "Полицейская дубинка", price = 500,  model = "models/weapons/w_stunbaton.mdl",      category = "Спецназ",   license = "police" },
}

-- 2) РУДА: itemID -> { name, price, model, oreType } (базовые цены, перекрываются GRM.OrePrices)
V.Catalogs.ore = V.Catalogs.ore or {
    ["ore_copper"]   = { name = "Медная руда",    price = 50,  model = "models/props_junk/rock001a.mdl" },
    ["ore_gold"]     = { name = "Золотая руда",   price = 200, model = "models/props_junk/rock001a.mdl" },
    ["ore_aluminum"] = { name = "Алюминиевая",    price = 80,  model = "models/props_junk/rock001a.mdl" },
    ["ore_platinum"] = { name = "Платиновая",     price = 350, model = "models/props_junk/rock001a.mdl" },
}

-- 3) ЕДА: itemID -> { name, price, model, hunger, health } (из GRM.Food.Config.FoodItems)
V.Catalogs.food = V.Catalogs.food or {
    ["grm_food_apple"] = { name = "Яблоко",   price = 20,  model = "models/props/cs_italy/orange.mdl",                    hunger = 15, health = 2 },
    ["grm_food_bread"] = { name = "Хлеб",     price = 44,  model = "models/props_junk/garbage_bag001a.mdl",             hunger = 25, health = 3 },
    ["grm_food_water"] = { name = "Вода",     price = 10,  model = "models/props_junk/garbage_plasticbottle003a.mdl",   hunger = 10, health = 0 },
    ["grm_food_soda"]  = { name = "Газировка", price = 15,  model = "models/props_junk/PopCan01a.mdl",                   hunger = 5,  health = 0 },
}

-- 4) РЕДКОСТИ: itemID -> { name, price, model, desc, maxStack }
V.Catalogs.rare = V.Catalogs.rare or {
    ["item_lockpick"]      = { name = "Отмычка",        price = 2500, model = "models/props_c17/TrapPropeller_Lever.mdl", desc = "Взлом замков (QTE)",      maxStack = 3 },
    ["item_repair_kit"]    = { name = "Ремкомплект",    price = 5000, model = "models/props_c17/tools_wrench.mdl",        desc = "Ремонт транспорта",        maxStack = 3 },
    ["radio_modulator"]    = { name = "Модулятор рации", price = 8000, model = "models/props_lab/citizenradio.mdl",        desc = "Доступ к зашумлённым частотам", maxStack = 1 },
    ["item_healthkit"]     = { name = "Аптечка",        price = 300,  model = "models/items/healthkit.mdl",               desc = "Лечит 25 HP",              maxStack = 5 },
    ["item_battery"]       = { name = "Батарея",        price = 250,  model = "models/items/battery.mdl",                 desc = "Восстанавливает 15 брони", maxStack = 5 },
}

-- Синхронизация цен руды из GRM.OrePrices (если есть)
if GRM.OrePrices then
    for oreType, price in pairs(GRM.OrePrices) do
        local id = "ore_" .. oreType
        if V.Catalogs.ore[id] then V.Catalogs.ore[id].price = price end
    end
end

-- Синхронизация еды из GRM.Food.Config.FoodItems
if GRM.Food and GRM.Food.Config and GRM.Food.Config.FoodItems then
    for id, data in pairs(GRM.Food.Config.FoodItems) do
        if V.Catalogs.food[id] then
            V.Catalogs.food[id].price = data.price
            V.Catalogs.food[id].hunger = data.hungerRestore
            V.Catalogs.food[id].health = data.healthRestore
        end
    end
end

-- ============================================================
-- API
-- ============================================================
function V.GetCatalog(vendorType) return V.Catalogs[vendorType] or {} end
function V.GetItem(vendorType, id) return V.GetCatalog(vendorType)[id] end

function V.GetSellPrice(ply, vendorType, id)
    local item = V.GetItem(vendorType, id)
    if not item then return 0 end
    return math.floor((item.price or 0) * V.Config.SellMultiplier)
end

function V.CanBuyWeapon(ply, item)
    if not item.license then return true end
    if item.license == "admin"  then return ply:IsSuperAdmin() end
    if item.license == "police" then
        if ply:Team() == TEAM_POLICE then return true end
        if GRM.Factions and GRM.Factions.Polizei and GRM.Factions.Polizei.Members[ply:SteamID()] then return true end
    end
    if item.license == "gun" then return true end
    return true
end

-- Регистрация каталога аддонами
function V.RegisterCatalog(vendorType, items)
    V.Catalogs[vendorType] = V.Catalogs[vendorType] or {}
    for id, data in pairs(items or {}) do
        V.Catalogs[vendorType][id] = data
    end
end

print("[GRM Vendor] Framework v1.0 loaded (shared)")