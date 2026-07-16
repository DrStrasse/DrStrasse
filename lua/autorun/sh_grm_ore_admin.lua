--[[
    Админ-команды для шахты + обработчик продажи
]]

if SERVER then
    if not GRM then GRM = {} end
    GRM.OrePrices = GRM.OrePrices or {
        copper = 50,
        gold = 100,
        aluminum = 75,
        platinum = 150,
    }

    local ORE_TYPES = { "copper", "gold", "aluminum", "platinum" }

    -- Вспомогательная функция для поиска игрока по части имени
    local function findPlayer(name)
        if not name or name == "" then return nil end
        local lower = name:lower()
        for _, ply in ipairs(player.GetAll()) do
            if ply:Nick():lower():find(lower, 1, true) then
                return ply
            end
        end
        return nil
    end

    hook.Add("PlayerSay", "GRM_OreAdminCmds", function(ply, text)
        if not ply:IsAdmin() then return end  -- только админы

        local args = string.Explode(" ", text)
        local cmd = args[1] and args[1]:lower() or ""

        -- !spawnore <тип>
        if cmd == "!spawnore" then
            local oreType = (args[2] or ""):lower()
            if not table.HasValue(ORE_TYPES, oreType) then
                ply:PrintMessage(HUD_PRINTTALK, "Доступные типы: copper, gold, aluminum, platinum")
                return ""
            end

            local node = ents.Create("grm_ore_node")
            if not IsValid(node) then
                ply:PrintMessage(HUD_PRINTTALK, "Не удалось создать узел")
                return ""
            end
            local tr = ply:GetEyeTrace()
            local pos = tr.HitPos + tr.HitNormal * 10
            node:SetPos(pos)
            node:Spawn()
            node:SetOreType(oreType)
            ply:PrintMessage(HUD_PRINTTALK, "Узел " .. oreType .. " руды создан")
            return ""
        end

        -- !setoreprice <тип> <цена>
        if cmd == "!setoreprice" then
            local oreType = (args[2] or ""):lower()
            local price = tonumber(args[3])
            if not table.HasValue(ORE_TYPES, oreType) or not price or price < 0 then
                ply:PrintMessage(HUD_PRINTTALK, "Использование: !setoreprice <тип> <цена>")
                return ""
            end
            GRM.OrePrices[oreType] = math.floor(price)
            ply:PrintMessage(HUD_PRINTTALK, "Цена для " .. oreType .. " установлена: " .. GRM.Format(price))
            return ""
        end

        -- !oreprices
        if cmd == "!oreprices" then
            ply:PrintMessage(HUD_PRINTTALK, "Текущие цены:")
            for ore, price in pairs(GRM.OrePrices) do
                ply:PrintMessage(HUD_PRINTTALK, "  " .. ore .. ": " .. GRM.Format(price))
            end
            return ""
        end

        -- !giveore <игрок> <тип> <количество>
        if cmd == "!giveore" then
            if not args[2] or not args[3] or not args[4] then
                ply:PrintMessage(HUD_PRINTTALK, "Использование: !giveore <игрок> <тип> <количество>")
                return ""
            end
            local target = findPlayer(args[2])
            if not IsValid(target) then
                ply:PrintMessage(HUD_PRINTTALK, "Игрок не найден")
                return ""
            end
            local oreType = args[3]:lower()
            if not table.HasValue(ORE_TYPES, oreType) then
                ply:PrintMessage(HUD_PRINTTALK, "Неверный тип руды")
                return ""
            end
            local amount = math.floor(tonumber(args[4]) or 0)
            if amount <= 0 then
                ply:PrintMessage(HUD_PRINTTALK, "Количество должно быть > 0")
                return ""
            end

            local itemID = "ore_" .. oreType
            local notAdded = GRM.Inventory.AddItem(target, itemID, amount)
            if notAdded == 0 then
                ply:PrintMessage(HUD_PRINTTALK, "Выдано " .. amount .. " " .. oreType .. " руды игроку " .. target:Nick())
                target:PrintMessage(HUD_PRINTTALK, "Админ выдал вам " .. amount .. " " .. oreType .. " руды")
            else
                ply:PrintMessage(HUD_PRINTTALK, "Инвентарь игрока переполнен, добавлено только " .. (amount - notAdded))
            end
            return ""
        end
    end)

    -- ============================================================
    -- ОБРАБОТЧИК ПРОДАЖИ РУДЫ (единый)
    -- ============================================================
    net.Receive("grm_ore_sell", function(_, ply)
        if not IsValid(ply) then return end

        local oreType = net.ReadString()
        local itemID = "ore_" .. oreType

        -- Диагностика
        print("[GRM Sell] Игрок", ply:Nick(), "продаёт", oreType)

        -- Проверяем наличие руды
        local count = GRM.Inventory.CountItem(ply, itemID)
        if count <= 0 then
            GRM.Notify(ply, "У вас нет этой руды", 255, 100, 100)
            print("[GRM Sell] Ошибка: руды нет")
            return
        end

        -- Проверяем цену
        local price = GRM.OrePrices[oreType]
        if not price or price <= 0 then
            GRM.Notify(ply, "Цена для этого типа не установлена", 255, 100, 100)
            print("[GRM Sell] Ошибка: цена не установлена для", oreType)
            return
        end

        -- Удаляем руду
        local removed = GRM.Inventory.RemoveItem(ply, itemID, count)
        if removed <= 0 then
            GRM.Notify(ply, "Ошибка при удалении руды", 255, 100, 100)
            print("[GRM Sell] Ошибка: не удалось удалить руду")
            return
        end

        -- Выдаём деньги
        local total = count * price
        GRM.GiveMoney(ply, total)
        GRM.Notify(ply, "Продано " .. count .. " " .. oreType .. " руды за " .. GRM.Format(total), 100, 220, 100)
        print("[GRM Sell] Успешно продано", count, oreType, "за", total)
    end)

    print("[GRM Ore Admin] Команды и обработчик продажи загружены")
end
