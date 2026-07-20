--[[--------------------------------------------------------------------
    GRM Vendor Framework v1.1 (Код 111)
    Единый фреймворк торгашей: оружие / руда / еда / редкости.
    Один энтити-класс grm_vendor, тип задаётся в data (vendorType).
    Каталоги — shared, расширяются аддонами, синхронизируются с
    реальными модулями GRM (Mining, Food, OreDefs).
    UI — единый «киоск» в стиле HUD v10.2 (Roboto, тёмная тема).
    Админка — toolgun grm_vendor_tool (спавн/настройка цен/лимитов).
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
    UseDistance    = 120,     -- дистанция взаимодействия
    MaxVendors     = 64,      -- лимит на карту (доп. к perm)
    SellMultiplier = 0.4,     -- скупка = 40% от цены продажи
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

-- 1) ОРУЖИЕ — ArcCW (базовый набор; расширяется через V.RegisterItem)
V.Catalogs.weapon = V.Catalogs.weapon or {
    ["arccw_ak47"]        = { name = "AK-47 (ArcCW)",     price = 12000, model = "models/weapons/w_rif_ak47.mdl",    category = "Автоматы",  license = "gun" },
    ["arccw_m4a1"]        = { name = "M4A1 (ArcCW)",      price = 13000, model = "models/weapons/w_rif_m4a1.mdl",    category = "Автоматы",  license = "gun" },
    ["arccw_p228"]        = { name = "P228 (ArcCW)",      price = 3500,  model = "models/weapons/w_pist_p228.mdl",   category = "Пистолеты", license = "gun" },
    ["arccw_deagle"]      = { name = "Desert Eagle (ArcCW)", price = 6500, model = "models/weapons/w_pist_deagle.mdl", category = "Пистолеты", license = "gun" },
    ["arccw_shotgun"]     = { name = "Remington 870 (ArcCW)", price = 9000, model = "models/weapons/w_shotgun.mdl",   category = "Дробовики", license = "gun" },
    ["arccw_mp5"]         = { name = "MP5 (ArcCW)",       price = 8500,  model = "models/weapons/w_smg_mp5.mdl",     category = "ПП",        license = "gun" },
    ["arrest_stick"]      = { name = "Полицейская дубинка", price = 500, model = "models/weapons/w_stunbaton.mdl",   category = "Спецназ",   license = "police" },
}

-- 2) РУДА — базовые цены, синхронизируются с GRM.OrePrices
V.Catalogs.ore = V.Catalogs.ore or {
    ["ore_copper"]    = { name = "Медная руда",   price = 50,  model = "models/props_junk/rock001a.mdl", oreType = "copper" },
    ["ore_gold"]      = { name = "Золотая руда",  price = 200, model = "models/props_junk/rock001a.mdl", oreType = "gold" },
    ["ore_aluminum"]  = { name = "Алюминиевая",   price = 80,  model = "models/props_junk/rock001a.mdl", oreType = "aluminum" },
    ["ore_platinum"]  = { name = "Платиновая",    price = 350, model = "models/props_junk/rock001a.mdl", oreType = "platinum" },
}

-- 3) ЕДА — синхронизируется с GRM.Food.Config.FoodItems
V.Catalogs.food = V.Catalogs.food or {
    ["grm_food_apple"]  = { name = "Яблоко",   price = 20,  model = "models/props/cs_italy/orange.mdl",                  hunger = 15, health = 2 },
    ["grm_food_bread"]  = { name = "Хлеб",     price = 44,  model = "models/props_junk/garbage_bag001a.mdl",             hunger = 25, health = 3 },
    ["grm_food_water"]  = { name = "Вода",     price = 10,  model = "models/props_junk/garbage_plasticbottle003a.mdl",  hunger = 10, health = 0 },
    ["grm_food_soda"]   = { name = "Газировка", price = 15, model = "models/props_junk/PopCan01a.mdl",                   hunger = 5,  health = 0 },
}

-- 4) РЕДКОСТИ: itemID -> { name, price, model, desc, maxStack, isWeapon }
-- isWeapon=true → выдаётся через ply:Give() (SWEP), иначе через GRM.Inventory.AddItem()
V.Catalogs.rare = V.Catalogs.rare or {
    -- SWEP (оружие) — продаются через ply:Give()
    ["ds_lockpick"]          = { name = "Отмычка (QTE)",       price = 2500,  model = "models/weapons/w_crowbar.mdl",       desc = "Взлом замков через QTE-мини-игру", maxStack = 1, isWeapon = true },
    ["ds_key_swep"]          = { name = "Дверные ключи",       price = 500,   model = "models/weapons/w_keys.mdl",          desc = "Блокировка/разблокировка дверей",   maxStack = 1, isWeapon = true },
    ["ds_battering_ram"]     = { name = "Полицейский таран",   price = 5000,  model = "models/weapons/w_rocket_launcher.mdl", desc = "Вскрытие дверей по ордеру",         maxStack = 1, isWeapon = true, license = "police" },
    ["grm_handcuffs"]        = { name = "Наручники",           price = 1500,  model = "models/weapons/w_cuffs.mdl",         desc = "Задержание подозреваемых",           maxStack = 1, isWeapon = true, license = "police" },
    ["weapon_grm_megaphone"] = { name = "Мегафон",             price = 3000,  model = "models/props_lab/tpplug.mdl",        desc = "Громкая связь для оповещений",       maxStack = 1, isWeapon = true },

    -- Предметы инвентаря — продаются через GRM.Inventory.AddItem()
    ["item_repair_kit"]      = { name = "Ремкомплект",         price = 5000,  model = "models/props_c17/tools_wrench.mdl",  desc = "Ремонт транспорта",                  maxStack = 3 },
    ["radio_modulator"]      = { name = "Модулятор рации",     price = 8000,  model = "models/props_lab/citizenradio.mdl",  desc = "Доступ к зашумлённым частотам",      maxStack = 1 },
    ["item_healthkit"]       = { name = "Аптечка",             price = 300,   model = "models/items/healthkit.mdl",         desc = "Лечит 25 HP",                        maxStack = 5 },
    ["item_battery"]         = { name = "Батарея",             price = 250,   model = "models/items/battery.mdl",           desc = "Восстанавливает 15 брони",           maxStack = 5 },
}

-- ============================================================
-- СИНХРОНИЗАЦИЯ С РЕАЛЬНЫМИ МОДУЛЯМИ GRM
-- ============================================================

-- Синхронизация цен руды из GRM.OrePrices (sh_grm_ore_admin.lua)
if GRM.OrePrices then
    for oreType, price in pairs(GRM.OrePrices) do
        local id = "ore_" .. oreType
        if V.Catalogs.ore[id] then
            V.Catalogs.ore[id].price = price
        end
    end
end

-- Синхронизация еды из GRM.Food.Config.FoodItems (sh_grm_food_config.lua)
if GRM.Food and GRM.Food.Config and GRM.Food.Config.FoodItems then
    for id, data in pairs(GRM.Food.Config.FoodItems) do
        if V.Catalogs.food[id] then
            V.Catalogs.food[id].price = data.price or V.Catalogs.food[id].price
            V.Catalogs.food[id].hunger = data.hungerRestore
            V.Catalogs.food[id].health = data.healthRestore
        end
    end
end

-- Автодобавление руд из sh_grm_ore_defs.lua (RegisterOre)
if GRM.OreDefs then
    for id, def in pairs(GRM.OreDefs) do
        if not V.Catalogs.ore[id] then
            V.Catalogs.ore[id] = {
                name    = def.name or id,
                price   = (GRM.OrePrices and GRM.OrePrices[def.oreType or id:gsub("ore_","")]) or 50,
                model   = def.model or "models/props_junk/rock001a.mdl",
                oreType = def.oreType or id:gsub("ore_",""),
            }
        end
    end
end

-- ============================================================
-- API
-- ============================================================

function V.GetCatalog(vendorType)
    return V.Catalogs[vendorType] or {}
end

function V.GetItem(vendorType, id)
    return V.GetCatalog(vendorType)[id]
end

function V.GetSellPrice(ply, vendorType, id)
    local item = V.GetItem(vendorType, id)
    if not item then return 0 end
    return math.floor((item.price or 0) * V.Config.SellMultiplier)
end

-- Проверка лицензии на оружие (использует Factions из sh_factions.lua)
function V.CanBuyWeapon(ply, item)
    if not item.license then return true end

    if item.license == "admin" then
        return ply:IsSuperAdmin()
    end

    if item.license == "police" then
        -- Проверяем через глобальную таблицу Factions
        if Factions and Factions.Polizei and Factions.Polizei.Members then
            if Factions.Polizei.Members[ply:SteamID()] or Factions.Polizei.Members[ply:SteamID64()] then
                return true
            end
        end
        return ply:IsSuperAdmin() -- суперадмин всегда может
    end

    if item.license == "gun" then
        return true -- свободная продажа
    end

    return true
end

-- Регистрация каталога из аддонов
function V.RegisterCatalog(vendorType, items)
    V.Catalogs[vendorType] = V.Catalogs[vendorType] or {}
    for id, data in pairs(items or {}) do
        V.Catalogs[vendorType][id] = data
    end
end

-- Регистрация одной позиции
function V.RegisterItem(vendorType, id, data)
    V.Catalogs[vendorType] = V.Catalogs[vendorType] or {}
    V.Catalogs[vendorType][id] = data
end

-- Регистрация модели NPC для нового типа
function V.RegisterModel(vendorType, model)
    V.Models[vendorType] = model
end

print("[GRM Vendor] Framework v1.1 loaded (Code 111)")
