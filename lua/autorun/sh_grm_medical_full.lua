--[[--------------------------------------------------------------------
    GRM Medical System v2.0 (Код 119) — полноценная медицина для медиков
    
    ДИАГНОСТИКА:
    - Сканирование пациента
    - Определение травм/болезней
    - История болезни (в медкарте)
    
    ЛЕЧЕНИЕ:
    - Перевязка (кровотечение)
    - Обезболивающие (боль)
    - Антибиотики (инфекция)
    - Операции (тяжёлые травмы)
    
    МЕД.ПРЕПАРАТЫ:
    - Обезболивающие (из наркотической системы)
    - Антибиотики (из переработки)
    - Стимуляторы (адреналин)
    
    СТАТУСЫ ПАЦИЕНТА:
    - Здоровье (0-100)
    - Кровотечение (0-100)
    - Боль (0-100)
    - Инфекция (0-100)
    - Отравление (0-100)
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.MedicalFull = GRM.MedicalFull or {}
local MED = GRM.MedicalFull

-- ============================================================
-- КОНФИГ
-- ============================================================
MED.Config = {
    -- Скорость кровотечения (% в секунду)
    BleedRate = 2,
    
    -- Урон от кровотечения
    BleedDamage = 1,
    
    -- Скорость инфекции
    InfectionRate = 1,
    
    -- Максимальная боль
    MaxPain = 100,
}

-- ============================================================
-- РЕЦЕПТЫ МЕД.ПРЕПАРАТОВ
-- ============================================================
MED.Recipes = {
    painkillers = {
        name = "Обезболивающее",
        model = "models/bloocobalt/l4d/items/w_eq_pills.mdl",
        ingredients = {
            narc_solvent = 2,
            narc_precursor = 1,
        },
        yield = 5,
        time = 20,
        effect = { pain = -50 },
    },
    
    antibiotics = {
        name = "Антибиотики",
        model = "models/bloocobalt/l4d/items/w_eq_pills.mdl",
        ingredients = {
            narc_solvent = 3,
            narc_precursor = 2,
        },
        yield = 4,
        time = 30,
        effect = { infection = -40 },
    },
    
    adrenaline = {
        name = "Адреналин",
        model = "models/jmod/resources/coolant_bottle.mdl",
        ingredients = {
            narc_solvent = 5,
            narc_precursor = 3,
            narc_equipment = 1,
        },
        yield = 2,
        time = 45,
        effect = { health = 30, bleed = -20 },
    },
    detox = {
        name = "Детокс-комплект",
        model = "models/healthvial.mdl",
        ingredients = {
            narc_solvent = 4,
            narc_precursor = 2,
        },
        yield = 2,
        time = 40,
        effect = { addiction = -35, poisoned = -50 },
    },
}

-- ============================================================
-- РЕГИСТРАЦИЯ ПРЕДМЕТОВ
-- ============================================================
local function RegisterMedical()
    if not (GRM.Inventory and GRM.Inventory.RegisterItem) then return end
    
    -- Мед.препараты
    for id, recipe in pairs(MED.Recipes) do
        GRM.Inventory.RegisterItem("med_" .. id, {
            type = "item",
            name = recipe.name,
            desc = "Медицинский препарат. Применение: из инвентаря.",
            icon = "icon16/pill.png",
            maxStack = 10,
            weight = 0.3,
            model = recipe.model,
            useFunc = "med_use_" .. id,
        })
    end
    
    -- Аптечка расширенная
    GRM.Inventory.RegisterItem("med_kit_advanced", {
        type = "item",
        name = "Расширенная аптечка",
        desc = "Лечит 50 HP, останавливает кровотечение.",
        icon = "icon16/heart.png",
        maxStack = 3,
        weight = 2.0,
        model = "models/props/cs_office/cardboard_box03.mdl",
        useFunc = "med_use_kit",
    })
end

RegisterMedical()
timer.Simple(2, RegisterMedical)

-- ============================================================
-- СЕРВЕРНАЯ ЧАСТЬ
-- ============================================================
if SERVER then
    util.AddNetworkString("GRM_Med_Scan")
    util.AddNetworkString("GRM_Med_Treat")
    util.AddNetworkString("GRM_Med_Status")
    
    -- Использование мед.препаратов (safe registrar: inventory may load later)
    local function registerMedHandlers()
        if not (GRM.Inventory and GRM.Inventory.RegisterUseHandler) then return false end

        GRM.Inventory.RegisterUseHandler("med_use_painkillers", function(ply, slotIdx, slot, def)
            local pain = ply:GetNWInt("GRM_Pain", 0)
            ply:SetNWInt("GRM_Pain", math.max(0, pain - 50))
            if GRM.Inventory.RemoveFromSlot then GRM.Inventory.RemoveFromSlot(ply, slotIdx, 1) else GRM.Inventory.RemoveItem(ply, "med_painkillers", 1) end
            if GRM.Notify then GRM.Notify(ply, "Боль уменьшена", 100, 220, 100) end
        end)

        GRM.Inventory.RegisterUseHandler("med_use_antibiotics", function(ply, slotIdx, slot, def)
            local infection = ply:GetNWInt("GRM_Infection", 0)
            ply:SetNWInt("GRM_Infection", math.max(0, infection - 40))
            if GRM.Inventory.RemoveFromSlot then GRM.Inventory.RemoveFromSlot(ply, slotIdx, 1) else GRM.Inventory.RemoveItem(ply, "med_antibiotics", 1) end
            if GRM.Notify then GRM.Notify(ply, "Инфекция подавлена", 100, 220, 100) end
        end)

        GRM.Inventory.RegisterUseHandler("med_use_adrenaline", function(ply, slotIdx, slot, def)
            ply:SetHealth(math.min((ply.GetMaxHealth and ply:GetMaxHealth()) or 100, ply:Health() + 30))
            local bleed = ply:GetNWInt("GRM_Bleed", 0)
            ply:SetNWInt("GRM_Bleed", math.max(0, bleed - 20))
            if GRM.Inventory.RemoveFromSlot then GRM.Inventory.RemoveFromSlot(ply, slotIdx, 1) else GRM.Inventory.RemoveItem(ply, "med_adrenaline", 1) end
            if GRM.Notify then GRM.Notify(ply, "Адреналин вколот! +30 HP", 100, 220, 100) end
        end)

        GRM.Inventory.RegisterUseHandler("med_use_detox", function(ply, slotIdx, slot, def)
            if GRM.Narcotics and GRM.Narcotics.ClearAddiction then
                GRM.Narcotics.ClearAddiction(ply, 35, "detox")
            else
                ply:SetNWInt("GRM_Addiction", math.max(0, (ply:GetNWInt("GRM_Addiction", 0) or 0) - 35))
                ply:SetNWInt("GRM_Poisoned", math.max(0, (ply:GetNWInt("GRM_Poisoned", 0) or 0) - 50))
            end
            if GRM.Inventory.RemoveFromSlot then GRM.Inventory.RemoveFromSlot(ply, slotIdx, 1) else GRM.Inventory.RemoveItem(ply, "med_detox", 1) end
            if GRM.Notify then GRM.Notify(ply, "Детоксикация проведена", 100, 220, 140) end
        end)

        GRM.Inventory.RegisterUseHandler("med_use_kit", function(ply, slotIdx, slot, def)
            ply:SetHealth(math.min((ply.GetMaxHealth and ply:GetMaxHealth()) or 100, ply:Health() + 50))
            ply:SetNWInt("GRM_Bleed", 0)
            if GRM.Inventory.RemoveFromSlot then GRM.Inventory.RemoveFromSlot(ply, slotIdx, 1) else GRM.Inventory.RemoveItem(ply, "med_kit_advanced", 1) end
            if GRM.Notify then GRM.Notify(ply, "Раны перевязаны, кровотечение остановлено", 100, 220, 100) end
        end)
        return true
    end
    registerMedHandlers()
    timer.Simple(2, registerMedHandlers)
    timer.Simple(6, registerMedHandlers)

    -- Обработка кровотечения
    hook.Add("Think", "GRM_Med_Bleed", function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                local bleed = ply:GetNWInt("GRM_Bleed", 0)
                if bleed > 0 then
                    -- Урон от кровотечения
                    if CurTime() - (ply:GetNWInt("GRM_BleedLastDamage", 0)) > 1 then
                        ply:TakeDamage(MED.Config.BleedDamage, game.GetWorld(), game.GetWorld())
                        ply:SetNWInt("GRM_BleedLastDamage", CurTime())
                    end
                    
                    -- Постепенное уменьшение
                    ply:SetNWInt("GRM_Bleed", math.max(0, bleed - MED.Config.BleedRate * 0.1))
                end
                
                -- Инфекция
                local infection = ply:GetNWInt("GRM_Infection", 0)
                if infection > 0 then
                    if CurTime() - (ply:GetNWInt("GRM_InfectionLastDamage", 0)) > 2 then
                        ply:TakeDamage(1, game.GetWorld(), game.GetWorld())
                        ply:SetNWInt("GRM_InfectionLastDamage", CurTime())
                    end
                    
                    -- Распространение инфекции
                    ply:SetNWInt("GRM_Infection", math.min(100, infection + MED.Config.InfectionRate * 0.05))
                end
            end
        end
    end)
    
    -- Команда /diagnose для медиков
    hook.Add("PlayerSay", "GRM_Med_Diagnose", function(ply, text)
        local cmd = string.lower(string.Trim(text or ""))
        
        if cmd == "/diagnose" or cmd == "!diagnose" then
            -- Проверяем доступ медика
            if not MED.IsMedic(ply) then
                ply:ChatPrint("Только медики могут использовать диагностику")
                return ""
            end
            
            -- Сканируем игрока в прицеле
            local trace = ply:GetEyeTrace()
            local target = trace.Entity
            if not IsValid(target) or not target:IsPlayer() then
                ply:ChatPrint("Наведитесь на игрока")
                return ""
            end
            
            -- Отправляем статус
            local status = {
                health = target:Health(),
                bleed = target:GetNWInt("GRM_Bleed", 0),
                pain = target:GetNWInt("GRM_Pain", 0),
                infection = target:GetNWInt("GRM_Infection", 0),
                poisoned = target:GetNWInt("GRM_Poisoned", 0),
                addiction = target:GetNWInt("GRM_Addiction", 0),
                narc = target:GetNWBool("GRM_NarcActive") and target:GetNWString("GRM_NarcType", "") or "нет",
            }
            
            ply:ChatPrint(string.format("=== Диагностика: %s ===", target:Nick()))
            ply:ChatPrint(string.format("  Здоровье: %d/100", status.health))
            ply:ChatPrint(string.format("  Кровотечение: %d%%", status.bleed))
            ply:ChatPrint(string.format("  Боль: %d%%", status.pain))
            ply:ChatPrint(string.format("  Инфекция: %d%%", status.infection))
            ply:ChatPrint(string.format("  Отравление: %d%%", status.poisoned))
            ply:ChatPrint(string.format("  Зависимость: %d%%", status.addiction))
            ply:ChatPrint("  Наркотический эффект: " .. tostring(status.narc))
            
            if status.bleed > 0 then
                ply:ChatPrint("   ТРЕБУЕТСЯ: Перевязка")
            end
            if status.pain > 50 then
                ply:ChatPrint("  ⚠ ТРЕБУЕТСЯ: Обезболивающее")
            end
            if status.infection > 30 then
                ply:ChatPrint("  ⚠ ТРЕБУЕТСЯ: Антибиотики")
            end
            if status.addiction > 30 or status.poisoned > 30 then
                ply:ChatPrint("  ⚠ ТРЕБУЕТСЯ: Детокс-комплект")
            end
            
            return ""
        end
    end)
    
    -- Проверка медика
    function MED.IsMedic(ply)
        if not IsValid(ply) then return false end
        
        -- Проверяем фракцию медика
        if Factions and Factions["Медики"] then
            local f = Factions["Медики"]
            if istable(f.Members) then
                local sid = ply:SteamID()
                local sid64 = ply:SteamID64()
                if f.Members[sid] or f.Members[sid64] then
                    return true
                end
            end
        end
        
        -- Или суперадмин
        return ply:IsSuperAdmin()
    end
    
    print("[GRM] Medical System v2.0 loaded (Код 119)")
end
