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

if SERVER then
    util.AddNetworkString("GRM_Narc_Cook")
    util.AddNetworkString("GRM_Narc_Use")
    util.AddNetworkString("GRM_Narc_Status")

    local function notify(ply, msg, r, g, b)
        if GRM.Notify then GRM.Notify(ply, msg, r or 255, g or 120, b or 120)
        elseif IsValid(ply) and ply.ChatPrint then ply:ChatPrint("[Наркотики] " .. tostring(msg or "")) end
    end

    function NARC.GetAddiction(ply)
        return IsValid(ply) and (ply:GetNWInt("GRM_Addiction", 0) or 0) or 0
    end
    function NARC.SetAddiction(ply, value, reason)
        if not IsValid(ply) then return end
        value = math.Clamp(math.floor(tonumber(value) or 0), 0, NARC.Config.MaxAddiction or 100)
        ply:SetNWInt("GRM_Addiction", value)
        ply:SetNWString("GRM_AddictionReason", tostring(reason or ""))
    end
    function NARC.ClearAddiction(ply, amount, reason)
        if not IsValid(ply) then return end
        amount = math.max(0, math.floor(tonumber(amount) or 100))
        NARC.SetAddiction(ply, math.max(0, NARC.GetAddiction(ply) - amount), reason or "treatment")
        ply:SetNWInt("GRM_Poisoned", math.max(0, (ply:GetNWInt("GRM_Poisoned", 0) or 0) - amount))
        notify(ply, "Детоксикация: зависимость снижена", 100, 220, 140)
    end

    function NARC.ApplyEffect(ply, narcType)
        if not IsValid(ply) or not ply:Alive() then return false end
        narcType = tostring(narcType or "")
        local effect = NARC.Config.Effects[narcType]
        local recipe = NARC.Recipes[narcType]
        if not effect or not recipe then return false end

        local now = CurTime()
        local untilTime = now + (tonumber(effect.duration) or 60)
        NARC.Active[ply] = { type = narcType, untilTime = untilTime, nextRegen = now, nextDamage = now }
        ply:SetNWBool("GRM_NarcActive", true)
        ply:SetNWString("GRM_NarcType", narcType)
        ply:SetNWFloat("GRM_NarcUntil", untilTime)

        local add = tonumber(effect.addiction) or 0
        if math.random() < (NARC.Config.AddictionChance or 0.15) then
            add = math.max(add, 1)
        else
            add = math.floor(add * 0.35)
        end
        NARC.SetAddiction(ply, NARC.GetAddiction(ply) + add, narcType)
        if add >= 20 then ply:SetNWInt("GRM_Poisoned", math.min(100, (ply:GetNWInt("GRM_Poisoned", 0) or 0) + math.floor(add / 2))) end

        timer.Create("GRM_Narc_End_" .. ply:SteamID64(), tonumber(effect.duration) or 60, 1, function()
            if IsValid(ply) and NARC.Active[ply] and NARC.Active[ply].type == narcType then
                NARC.Active[ply] = nil
                ply:SetNWBool("GRM_NarcActive", false)
                ply:SetNWString("GRM_NarcType", "")
                ply:SetNWFloat("GRM_NarcUntil", 0)
                notify(ply, "Действие вещества прошло: " .. recipe.name, 180, 180, 220)
            end
        end)

        notify(ply, "Вы употребили: " .. recipe.name, 255, 120, 120)
        return true
    end

    local function registerUseHandlers()
        if not (GRM.Inventory and GRM.Inventory.RegisterUseHandler) then return false end
        for id in pairs(NARC.Recipes or {}) do
            GRM.Inventory.RegisterUseHandler("narc_use_" .. id, function(ply, slotIdx, slot, def)
                if NARC.ApplyEffect(ply, id) then
                    if GRM.Inventory.RemoveFromSlot then GRM.Inventory.RemoveFromSlot(ply, slotIdx, 1)
                    else GRM.Inventory.RemoveItem(ply, "narc_" .. id, 1) end
                end
            end)
        end
        return true
    end
    registerUseHandlers()
    timer.Simple(2, registerUseHandlers)
    timer.Simple(6, registerUseHandlers)

    hook.Add("Think", "GRM_Narc_Regen", function()
        local now = CurTime()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() then
                local active = NARC.Active[ply]
                if active and active.untilTime > now then
                    local effect = NARC.Config.Effects[active.type]
                    if effect then
                        if (effect.health_regen or 0) > 0 and (active.nextRegen or 0) <= now then
                            active.nextRegen = now + 1
                            if ply:Health() < ply:GetMaxHealth() then
                                ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + (effect.health_regen or 0)))
                            end
                        end
                    end
                elseif active then
                    NARC.Active[ply] = nil
                    ply:SetNWBool("GRM_NarcActive", false)
                    ply:SetNWString("GRM_NarcType", "")
                end

                local addiction = NARC.GetAddiction(ply)
                if addiction > 80 and (ply._grmNarcNextOD or 0) <= now then
                    ply._grmNarcNextOD = now + 5
                    ply:TakeDamage(NARC.Config.OverdoseDamage or 10, game.GetWorld(), game.GetWorld())
                    notify(ply, "Передозировка/ломка наносит вред!", 255, 80, 80)
                end
            end
        end
    end)

    hook.Add("PlayerSay", "GRM_Narc_StatusCmd", function(ply, text)
        local cmd = string.lower(string.Trim(text or ""))
        if cmd == "/narc_status" or cmd == "!narc_status" or cmd == "/drugstatus" then
            local active = ply:GetNWBool("GRM_NarcActive") and ply:GetNWString("GRM_NarcType", "") or "нет"
            ply:ChatPrint("[Наркотики] Активный эффект: " .. tostring(active))
            ply:ChatPrint("[Наркотики] Зависимость: " .. tostring(NARC.GetAddiction(ply)) .. "/100")
            ply:ChatPrint("[Наркотики] Отравление: " .. tostring(ply:GetNWInt("GRM_Poisoned", 0)) .. "/100")
            return ""
        end
    end)

    print("[GRM] Narcotics System loaded v" .. tostring(NARC.Version))
end
