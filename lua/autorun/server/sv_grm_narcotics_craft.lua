--[[--------------------------------------------------------------------
    GRM Narcotics Craft UI v1.0 (Код 120) — интерфейс варки наркотиков
    
    КРАФТ-СТАНЦИИ:
    - Лаборатория для наркотиков (grm_narc_lab)
    - Мед.лаборатория (grm_med_lab)
    
    UI:
    - Список рецептов
    - Инвентарь ингредиентов
    - Прогресс-бар варки
    - Уведомления о готовности
----------------------------------------------------------------------]]

if CLIENT then return end

GRM = GRM or {}
GRM.NarcCraft = GRM.NarcCraft or {}
local CRAFT = GRM.NarcCraft

util.AddNetworkString("GRM_NarcCraft_Open")
util.AddNetworkString("GRM_NarcCraft_Start")
util.AddNetworkString("GRM_NarcCraft_Progress")
util.AddNetworkString("GRM_NarcCraft_Done")

-- ============================================================
-- КРАФТ-СТАНЦИЯ: ЛАБОРАТОРИЯ
-- ============================================================

-- Рецепты наркотиков (дублируем здесь чтобы были доступны на сервере)
local NARC_RECIPES = {
    marijuana = {
        name = "Марихуана",
        model = "models/jmod/resources/propellent.mdl",
        ingredients = { narc_solvent = 2, narc_precursor = 1 },
        cook_time = 30,
        yield = 3,
    },
    amphetamine = {
        name = "Амфетамин",
        model = "models/bloocobalt/l4d/items/w_eq_pills.mdl",
        ingredients = { narc_solvent = 3, narc_precursor = 3 },
        cook_time = 60,
        yield = 5,
    },
    cocaine = {
        name = "Кокаин",
        model = "models/bloocobalt/l4d/items/w_eq_pills.mdl",
        ingredients = { narc_solvent = 5, narc_precursor = 5, narc_equipment = 1 },
        cook_time = 90,
        yield = 7,
    },
}

-- Рецепты мед.препаратов
local MED_RECIPES = {
    painkillers = {
        name = "Обезболивающее",
        model = "models/bloocobalt/l4d/items/w_eq_pills.mdl",
        ingredients = { narc_solvent = 2, narc_precursor = 1 },
        cook_time = 20,
        yield = 5,
    },
    antibiotics = {
        name = "Антибиотики",
        model = "models/bloocobalt/l4d/items/w_eq_pills.mdl",
        ingredients = { narc_solvent = 3, narc_precursor = 2 },
        cook_time = 30,
        yield = 4,
    },
    adrenaline = {
        name = "Адреналин",
        model = "models/jmod/resources/coolant_bottle.mdl",
        ingredients = { narc_solvent = 5, narc_precursor = 3, narc_equipment = 1 },
        cook_time = 45,
        yield = 2,
    },
}

CRAFT.LabType = {
    narc = {
        name = "Лаборатория наркотиков",
        model = "models/props_wasteland/laundry_washer003.mdl",
        recipes = NARC_RECIPES,
    },
    med = {
        name = "Медицинская лаборатория",
        model = "models/props_wasteland/laundry_washer003.mdl",
        recipes = MED_RECIPES,
    },
}

local function recipeTable(labType)
    if labType == "narc" then
        return (GRM.Narcotics and GRM.Narcotics.Recipes) or NARC_RECIPES
    end
    return (GRM.MedicalFull and GRM.MedicalFull.Recipes) or MED_RECIPES
end

local function recipeTime(recipe)
    return math.max(1, math.floor(tonumber(recipe and (recipe.time or recipe.cook_time)) or 30))
end

local function invReady()
    return GRM.Inventory and GRM.Inventory.CountItem and GRM.Inventory.RemoveItem and GRM.Inventory.AddItem
end

-- ============================================================
-- ПРОВЕРКА РЕЦЕПТА
-- ============================================================
function CRAFT.CanCraft(ply, recipeID, labType)
    if not IsValid(ply) then return false, "Игрок недействителен" end
    
    if not invReady() then return false, "Инвентарь не загружен" end
    local recipes = recipeTable(labType)
    local recipe = recipes and recipes[recipeID]
    if not recipe then return false, "Неизвестный рецепт" end

    -- Проверяем ингредиенты
    for ingredient, count in pairs(recipe.ingredients) do
        local have = GRM.Inventory.CountItem(ply, ingredient) or 0
        if have < count then
            return false, string.format("Нужно %d %s (у вас: %d)", count, ingredient, have)
        end
    end
    
    return true
end

-- ============================================================
-- НАЧАЛО КРАФТА
-- ============================================================
function CRAFT.StartCraft(ply, recipeID, labType)
    local ok, err = CRAFT.CanCraft(ply, recipeID, labType)
    if not ok then
        if GRM.Notify then GRM.Notify(ply, err, 255, 100, 100) end
        return
    end
    
    local recipes = recipeTable(labType)
    local recipe = recipes and recipes[recipeID]
    if not recipe then return end
    local t = recipeTime(recipe)

    -- Списываем ингредиенты
    for ingredient, count in pairs(recipe.ingredients) do
        GRM.Inventory.RemoveItem(ply, ingredient, count)
    end
    
    -- Отправляем прогресс
    net.Start("GRM_NarcCraft_Progress")
        net.WriteString(recipe.name)
        net.WriteUInt(t, 16)
    net.Send(ply)
    
    if GRM.Notify then
        GRM.Notify(ply, "Варка " .. recipe.name .. " начата (" .. t .. " сек)", 100, 200, 255)
    end
    
    -- Таймер завершения
    timer.Simple(t, function()
        if not IsValid(ply) then return end
        
        -- Добавляем продукт
        local outputID = (labType == "narc" and "narc_" or "med_") .. recipeID
        local left = GRM.Inventory.AddItem(ply, outputID, recipe.yield)
        
        if left > 0 then
            if GRM.Notify then GRM.Notify(ply, "Инвентарь полон! Потеряно: " .. left, 255, 100, 100) end
        else
            if GRM.Notify then GRM.Notify(ply, "Готово! Получено: " .. recipe.yield .. " " .. recipe.name, 100, 220, 100) end
        end
        
        net.Start("GRM_NarcCraft_Done")
            net.WriteString(recipe.name)
        net.Send(ply)
    end)
end

-- ============================================================
-- СЕТЬ
-- ============================================================
net.Receive("GRM_NarcCraft_Open", function(_, ply)
    if not IsValid(ply) then return end
    
    local labType = net.ReadString()
    if labType ~= "narc" and labType ~= "med" then return end
    local lab = CRAFT.LabType[labType]
    if not lab then return end
    
    -- Отправляем список рецептов
    net.Start("GRM_NarcCraft_Open")
        net.WriteString(labType)
        local recipes = lab.recipes
        net.WriteUInt(table.Count(recipes), 8)
        for recipeID, recipe in pairs(recipes) do
            net.WriteString(recipeID)
            net.WriteString(recipe.name)
            net.WriteUInt(recipe.cook_time or recipe.time or 30, 16)
            net.WriteUInt(recipe.yield or 1, 8)
            net.WriteUInt(table.Count(recipe.ingredients), 8)
            for ing, count in pairs(recipe.ingredients) do
                net.WriteString(ing)
                net.WriteUInt(count, 8)
            end
        end
    net.Send(ply)
end)

net.Receive("GRM_NarcCraft_Start", function(_, ply)
    if not IsValid(ply) then return end
    
    local labType = net.ReadString()
    local recipeID = net.ReadString()
    if labType ~= "narc" and labType ~= "med" then return end
    CRAFT.StartCraft(ply, recipeID, labType)
end)

print("[GRM] Narcotics Craft UI loaded (Код 120)")
