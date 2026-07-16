--[[--------------------------------------------------------------------
    VEHICLE DEALER v3 — Патч интеграции с системой доступа

    Этот файл загружается ПОСЛЕ сущности sent_vehicle_dealer и
    добавляет интеграцию с GRM_HasVehicleAccess.

    Сущность sent_vehicle_dealer определена в:
      entities/sent_vehicle_dealer/shared.lua
      entities/sent_vehicle_dealer/init.lua
      entities/sent_vehicle_dealer/cl_init.lua

    Зависимости: grm_vehicle_access.lua (GRM_HasVehicleAccess)
--------------------------------------------------------------------]]

if SERVER then
    AddCSLuaFile()
end

if SERVER then

    -- ════════════════════════════════════════════════════════
    -- ХУК: Проверка доступа перед спавном
    -- ════════════════════════════════════════════════════════

    hook.Add("VD_PreSpawnCheck", "GRM_AccessCheck", function(ply, vehicleClass, dealerData)
        -- Если система доступа загружена — проверяем
        if GRM_HasVehicleAccess then
            -- Суперадмин всегда может
            if ply:IsSuperAdmin() then return true end

            -- Проверяем через систему доступа
            if GRM_HasVehicleAccess(ply, vehicleClass) then
                return true
            end

            -- Проверяем, есть ли транспорт в списке дилера (старая логика)
            -- Это позволяет дилеру работать и без системы покупок
            if dealerData and dealerData.vehicles then
                local faction = nil
                if Factions then
                    local steam = ply:SteamID()
                    for fname, f in pairs(Factions) do
                        if f.Members and f.Members[steam] then faction = fname break end
                    end
                end

                local vlist = (faction and dealerData.vehicles[faction] and #dealerData.vehicles[faction] > 0)
                              and dealerData.vehicles[faction]
                              or (dealerData.vehicles["__global"] or {})

                for _, v in ipairs(vlist) do
                    if v.class == vehicleClass then return true end
                end
            end

            return false
        end

        -- Если система доступа не загружена — разрешаем (обратная совместимость)
        return true
    end)

    -- ════════════════════════════════════════════════════════
    -- ХУК: Фильтрация списка транспорта по доступу
    -- ════════════════════════════════════════════════════════

    hook.Add("VD_FilterVehicleList", "GRM_FilterByAccess", function(ply, vlist)
        if not GRM_HasVehicleAccess then return vlist end
        if ply:IsSuperAdmin() then return vlist end

        local filtered = {}
        for _, v in ipairs(vlist) do
            if GRM_HasVehicleAccess(ply, v.class) then
                table.insert(filtered, v)
            end
        end

        -- Если после фильтрации ничего не осталось — показываем всё
        -- (обратная совместимость: дилер без настроенных цен)
        if #filtered == 0 then return vlist end

        return filtered
    end)

    -- ════════════════════════════════════════════════════════
    -- БЛОКИРОВКА СПАВНА ИЗ Q-МЕНЮ
    -- Игрок не может заспавнить транспорт через Q-меню,
    -- если он его не купил и не состоит в нужной фракции.
    -- Суперадмины могут спавнить всё.
    -- ════════════════════════════════════════════════════════

    hook.Add("PlayerSpawnVehicle", "GRM_BlockUnauthorizedSpawn", function(ply, model, vehicleName, vehicleTable)
        if not IsValid(ply) then return end

        -- Суперадмин всегда может
        if ply:IsSuperAdmin() then return end

        -- Если система доступа загружена — проверяем
        if GRM_HasVehicleAccess then
            -- vehicleName — это класс/скрипт транспорта из list.Get("Vehicles")
            -- Ищем совпадение по классу в списке всех транспортов
            local vehicleClass = vehicleName

            -- Иногда vehicleName совпадает с ключом в list.Get("Vehicles"),
            -- иногда нужно искать по модели или VehicleScript. Пробуем оба варианта.
            if not GRM_HasVehicleAccess(ply, vehicleClass) then
                local allVehicles = list.Get("Vehicles")
                if allVehicles then
                    for class, data in pairs(allVehicles) do
                        if class == vehicleName
                            or (data.Model and data.Model == model)
                            or (data.KeyValues and data.KeyValues.VehicleScript
                                and vehicleTable and vehicleTable.KeyValues
                                and vehicleTable.KeyValues.VehicleScript
                                and data.KeyValues.VehicleScript == vehicleTable.KeyValues.VehicleScript)
                        then
                            vehicleClass = class
                            break
                        end
                    end
                end

                if not GRM_HasVehicleAccess(ply, vehicleClass) then
                    ply:ChatPrint("[VD] У вас нет доступа к этому транспорту. Купите его через /vshop или вступите в нужную фракцию.")
                    return false
                end
            end
        end

        -- Если система доступа не загружена — разрешаем (обратная совместимость)
    end)

    -- ════════════════════════════════════════════════════════
    -- Увеличенный cooldown использования дилера (2 секунды)
    -- ════════════════════════════════════════════════════════

    local VD_USE_COOLDOWN = 2
    local _useCooldowns = {}

    hook.Add("PlayerUse", "VD_CooldownPatch", function(ply, ent)
        if not IsValid(ent) or ent:GetClass() ~= "sent_vehicle_dealer" then return end

        local sid = ply:SteamID()
        local now = CurTime()
        if _useCooldowns[sid] and now - _useCooldowns[sid] < VD_USE_COOLDOWN then
            return false  -- Блокируем использование
        end
        _useCooldowns[sid] = now
    end)

    -- ════════════════════════════════════════════════════════
    -- Лог транзакций (спавн транспорта)
    -- ════════════════════════════════════════════════════════

    hook.Add("VD_OnVehicleSpawned", "VD_LogSpawn", function(ent, ply, vehicleClass)
        if not IsValid(ent) then return end
        if not IsValid(ply) then return end

        local logLine = string.format("[%s] %s (%s) заспавнил %s (ID #%d)",
            os.date("%Y-%m-%d %H:%M:%S"),
            ply:Nick(),
            ply:SteamID(),
            vehicleClass or ent:GetClass(),
            ent.VD_ID or 0
        )

        -- Записываем в файл лога
        file.Append("vd_spawn_log.txt", logLine .. "\n")

        if vdDbgPrint then
            vdDbgPrint(logLine)
        end
    end)

    print("[VD v3] Патч доступа к транспорту применён")
end
