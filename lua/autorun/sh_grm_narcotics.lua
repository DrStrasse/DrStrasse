--[[--------------------------------------------------------------------
    GRM Narcotics System v1.0 (Код 117) — варка наркотиков
    
    СВЯЗЬ С ДОБЫЧЕЙ:
    - Руды (медь, алюминий) → растворители
    - Металлолом → оборудование для варки
    - Химикаты (из factory) → прекурсоры
    
    ИНГРЕДИЕНТЫ:
    - Растворитель (из руды)
    - Прекурсор (из химикатов)
    - Оборудование (лаборатория)
    
    НАРКОТИКИ:
    - Марихуана (простая варка)
    - Амфетамин (средняя сложность)
    - Кокаин (сложная варка)
    
    ЭФФЕКТЫ:
    - Кратковременные бафы (скорость, сила)
    - Долгосрочные дебафы (зависимость, здоровье)
    - Передозировка (смерть)
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Narcotics = GRM.Narcotics or {}
local NARC = GRM.Narcotics

-- ============================================================
-- КОНФИГ
-- ============================================================
NARC.Config = {
    -- Шанс зависимости при употреблении (0-1)
    AddictionChance = 0.15,
    
    -- Максимальный уровень зависимости (0-100)
    MaxAddiction = 100,
    
    -- Урон от передозировки
    OverdoseDamage = 10,
    
    -- Время варки (секунды)
    CookTime = {
        marijuana = 30,
        amphetamine = 60,
        cocaine = 90,
    },
    
    -- Эффекты наркотиков
    Effects = {
        marijuana = {
            duration = 120,
            speed = 1.1,      -- +10% скорость
            jump = 1.2,       -- +20% прыжок
            health_regen = 2, -- регенерация HP/сек
            addiction = 10,   -- уровень зависимости
        },
        amphetamine = {
            duration = 180,
            speed = 1.3,
            stamina = 2.0,    -- бесконечная стамина
            health_regen = 0,
            addiction = 25,
        },
        cocaine = {
            duration = 90,
            speed = 1.5,
            damage = 1.3,     -- +30% урон
            health_regen = 5,
            addiction = 40,
        },
    },
}

-- ============================================================
-- ИНГРЕДИЕНТЫ (связь с рудой/металлом)
-- ============================================================
NARC.Ingredients = {
    -- Растворитель (из алюминиевой руды)
    solvent = {
        name = "Растворитель",
        model = "models/jmod/resources/coolant_bottle.mdl",
        from_ore = "ore_aluminum", -- нужна алюминиевая руда
        yield = 5, -- из 1 руды = 5 растворителя
    },
    
    -- Прекурсор (из медной руды + химикатов)
    precursor = {
        name = "Прекурсор",
        model = "models/props/cs_office/cardboard_box03.mdl",
        from_ore = "ore_copper",
        yield = 3,
    },
    
    -- Оборудование (из металла)
    equipment = {
        name = "Оборудование для варки",
        model = "models/props_wasteland/laundry_washer003.mdl",
        from_scrap = true, -- нужен металлолом
        scrap_needed = 10,
    },
}

-- ============================================================
-- РЕЦЕПТЫ
-- ============================================================
NARC.Recipes = {
    marijuana = {
        name = "Марихуана",
        model = "models/jmod/resources/propellent.mdl",
        ingredients = {
            solvent = 2,
            precursor = 1,
        },
        cook_time = 30,
        yield = 3, -- порций
        difficulty = 1, -- 1-10
    },
    
    amphetamine = {
        name = "Амфетамин",
        model = "models/bloocobalt/l4d/items/w_eq_pills.mdl",
        ingredients = {
            solvent = 3,
            precursor = 3,
        },
        cook_time = 60,
        yield = 5,
        difficulty = 5,
    },
    
    cocaine = {
        name = "Кокаин",
        model = "models/bloocobalt/l4d/items/w_eq_pills.mdl",
        ingredients = {
            solvent = 5,
            precursor = 5,
            equipment = 1,
        },
        cook_time = 90,
        yield = 7,
        difficulty = 8,
    },
}

-- ============================================================
-- РЕГИСТРАЦИЯ ПРЕДМЕТОВ В ИНВЕНТАРЕ
-- ============================================================
local function RegisterNarcotics()
    if not (GRM.Inventory and GRM.Inventory.RegisterItem) then return end
    
    -- Ингредиенты
    GRM.Inventory.RegisterItem("narc_solvent", {
        type = "item",
        name = "Растворитель",
        desc = "Химический растворитель для варки. Из алюминиевой руды.",
        icon = "icon16/bottle.png",
        maxStack = 10,
        weight = 0.5,
        model = "models/jmod/resources/coolant_bottle.mdl",
    })
    
    GRM.Inventory.RegisterItem("narc_precursor", {
        type = "item",
        name = "Прекурсор",
        desc = "Химический прекурсор. Из медной руды.",
        icon = "icon16/box.png",
        maxStack = 10,
        weight = 1.0,
        model = "models/props/cs_office/cardboard_box03.mdl",
    })
    
    GRM.Inventory.RegisterItem("narc_equipment", {
        type = "item",
        name = "Оборудование для варки",
        desc = "Лабораторное оборудование. Из металлолома.",
        icon = "icon16/wrench.png",
        maxStack = 1,
        weight = 5.0,
        model = "models/props_wasteland/laundry_washer003.mdl",
    })
    
    -- Наркотики
    for id, recipe in pairs(NARC.Recipes) do
        GRM.Inventory.RegisterItem("narc_" .. id, {
            type = "item",
            name = recipe.name,
            desc = "Наркотическое вещество. Вызывает зависимость!",
            icon = "icon16/pill.png",
            maxStack = 5,
            weight = 0.2,
            model = recipe.model,
            useFunc = "narc_use_" .. id,
        })
    end
end

-- Регистрируем сразу и с задержкой (инвентарь может грузиться позже)
RegisterNarcotics()
timer.Simple(2, RegisterNarcotics)

-- ============================================================
-- СЕРВЕРНАЯ ЧАСТЬ
-- ============================================================
if SERVER then
    util.AddNetworkString("GRM_Narc_Cook")
    util.AddNetworkString("GRM_Narc_Use")
    util.AddNetworkString("GRM_Narc_Status")
    
    -- Использование наркотика
    GRM.Inventory.RegisterUseHandler("narc_use_marijuana", function(ply, slotIdx, slot, def)
        NARC.ApplyEffect(ply, "marijuana")
        GRM.Inventory.RemoveItem(ply, "narc_marijuana", 1)
    end)
    
    GRM.Inventory.RegisterUseHandler("narc_use_amphetamine", function(ply, slotIdx, slot, def)
        NARC.ApplyEffect(ply, "amphetamine")
        GRM.Inventory.RemoveItem(ply, "narc_amphetamine", 1)
    end)
    
    GRM.Inventory.RegisterUseHandler("narc_use_cocaine", function(ply, slotIdx, slot, def)
        NARC.ApplyEffect(ply, "cocaine")
        GRM.Inventory.RemoveItem(ply, "narc_cocaine", 1)
    end)
    
    -- Применение эффектов
    function NARC.ApplyEffect(ply, narcType)
        if not IsValid(ply) then return end
        
        local effect = NARC.Config.Effects[narcType]
        if not effect then return end
        
        -- Шанс зависимости
        if math.random() < NARC.Config.AddictionChance then
            local currentAddiction = ply:GetNWInt("GRM_Addiction", 0)
            ply:SetNWInt("GRM_Addiction", math.min(NARC.Config.MaxAddiction, currentAddiction + effect.addiction))
        end
        
        -- Временные бафы
        ply:SetNWBool("GRM_NarcActive", true)
        ply:SetNWString("GRM_NarcType", narcType)
        
        -- Таймер окончания эффекта
        timer.Simple(effect.duration, function()
            if IsValid(ply) then
                ply:SetNWBool("GRM_NarcActive", false)
                ply:SetNWString("GRM_NarcType", "")
            end
        end)
        
        if GRM.Notify then
            GRM.Notify(ply, "Вы употребили " .. NARC.Recipes[narcType].name, 255, 100, 100)
        end
    end
    
    -- Регенерация здоровья от наркотиков
    hook.Add("Think", "GRM_Narc_Regen", function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() and ply:GetNWBool("GRM_NarcActive") then
                local narcType = ply:GetNWString("GRM_NarcType", "")
                local effect = NARC.Config.Effects[narcType]
                if effect and effect.health_regen > 0 then
                    local hp = ply:Health()
                    if hp < 100 then
                        ply:SetHealth(math.min(100, hp + effect.health_regen * 0.1))
                    end
                end
                
                -- Урон от передозировки (если зависимость высокая)
                local addiction = ply:GetNWInt("GRM_Addiction", 0)
                if addiction > 80 then
                    ply:TakeDamage(NARC.Config.OverdoseDamage * 0.01, game.GetWorld(), game.GetWorld())
                end
            end
        end
    end)
    
    print("[GRM] Narcotics System loaded (Код 117)")
end
