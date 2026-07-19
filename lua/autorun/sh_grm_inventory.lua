--[[--------------------------------------------------------------------
    GRM Inventory System v1.1.0 (Код 97)
    Полноценный инвентарь с ячейками для патронов, оружия и предметов

    Возможности:
      • Сетка инвентаря с настраиваемым количеством слотов
      • Хранение: оружие, патроны, предметы
      • Перетаскивание предметов (drag & drop)
      • Подбор предметов с земли / выброс из инвентаря
      • Использование предметов (экипировка оружия, применение патронов)
      • Сохранение инвентаря в файл (персистентность)
    v1.1.0 (Код 97, находка 114): ЛОАДЕР калечил весь инвентарь при рестарте —
    bare util.JSONToTable конвертировал sid64-ключ в битый double → записи
    сиротели («пропадают купленные телефоны» — пропадало ВСЁ). Теперь:
    jsonT 3-им аргументом (н65), нормализация ключей слотов в числа,
    ленивое sid64-rescue для уже битых сейвов, дебаунс-автосейв 2с на любых
    мутациях (окно 10с автотаймера закрыто), read-back SAVE-печать.
      • Синхронизация сервер ↔ клиент
      • Стакирование одинаковых предметов (патроны)
      • Интеграция с GRM Currency

    Команды:
      /inv или /inventory — открыть инвентарь

    Типы предметов:
      "weapon"  — оружие (не стакируется)
      "ammo"    — патроны (стакируются)
      "item"    — предметы (стакируются по настройке)
--------------------------------------------------------------------]]

GRM = GRM or {}
GRM.Inventory = GRM.Inventory or {}

-- ================================================================
--  КОНФИГУРАЦИЯ
-- ================================================================
GRM.Inventory.Config = {
    MaxSlots       = 24,         -- Количество слотов инвентаря
    MaxStack       = 999,        -- Максимальный стак для патронов
    ItemMaxStack   = 10,         -- Максимальный стак для предметов
    SaveInterval   = 10,         -- Интервал автосохранения (секунды)
    DropDistance   = 80,         -- Дистанция выброса предмета
}

-- ================================================================
--  ОПРЕДЕЛЕНИЯ ПРЕДМЕТОВ (Shared)
-- ================================================================
-- Реестр всех возможных предметов
GRM.Inventory.ItemDefs = {
    -- === ПАТРОНЫ ===
    ["ammo_pistol"] = {
        type = "ammo",
        name = "Пистолетные патроны",
        desc = "Стандартные патроны калибра 9мм",
        icon = "icon16/bullet_blue.png",
        ammoType = "Pistol",
        maxStack = 120,
        weight = 0.1,
    },
    ["ammo_smg1"] = {
        type = "ammo",
        name = "Патроны SMG",
        desc = "Патроны для пистолетов-пулемётов",
        icon = "icon16/bullet_orange.png",
        ammoType = "SMG1",
        maxStack = 240,
        weight = 0.1,
    },
    ["ammo_ar2"] = {
        type = "ammo",
        name = "Патроны AR2",
        desc = "Энергетические патроны для AR2",
        icon = "icon16/bullet_purple.png",
        ammoType = "AR2",
        maxStack = 120,
        weight = 0.2,
    },
    ["ammo_357"] = {
        type = "ammo",
        name = "Патроны .357",
        desc = "Мощные патроны калибра .357 Magnum",
        icon = "icon16/bullet_red.png",
        ammoType = "357",
        maxStack = 36,
        weight = 0.3,
    },
    ["ammo_buckshot"] = {
        type = "ammo",
        name = "Картечь",
        desc = "Патроны для дробовика",
        icon = "icon16/bullet_yellow.png",
        ammoType = "Buckshot",
        maxStack = 48,
        weight = 0.2,
    },
    ["ammo_crossbow"] = {
        type = "ammo",
        name = "Болты арбалета",
        desc = "Стальные болты для арбалета",
        icon = "icon16/bullet_green.png",
        ammoType = "XBowBolt",
        maxStack = 12,
        weight = 0.5,
    },
    ["ammo_rpg"] = {
        type = "ammo",
        name = "Ракеты RPG",
        desc = "Ракеты для гранатомёта",
        icon = "icon16/bomb.png",
        ammoType = "RPG_Round",
        maxStack = 6,
        weight = 2.0,
    },
    ["ammo_grenade"] = {
        type = "ammo",
        name = "Гранаты",
        desc = "Осколочные гранаты",
        icon = "icon16/bomb.png",
        ammoType = "Grenade",
        maxStack = 6,
        weight = 1.0,
    },
    ["ammo_smg1_grenade"] = {
        type = "ammo",
        name = "Гранаты SMG",
        desc = "Подствольные гранаты для SMG",
        icon = "icon16/bomb.png",
        ammoType = "SMG1_Grenade",
        maxStack = 6,
        weight = 1.0,
    },

    -- === ПРЕДМЕТЫ ===
    ["item_healthkit"] = {
        type = "item",
        name = "Аптечка",
        desc = "Восстанавливает 25 HP",
        icon = "icon16/heart.png",
        maxStack = 5,
        weight = 1.0,
        useFunc = "heal_25",
    },
    ["item_battery"] = {
        type = "item",
        name = "Батарея",
        desc = "Восстанавливает 15 брони",
        icon = "icon16/shield.png",
        maxStack = 5,
        weight = 1.0,
        useFunc = "armor_15",
    },
    ["item_lockpick"] = {
        type = "item",
        name = "Отмычка",
        desc = "Позволяет вскрывать замки",
        icon = "icon16/key.png",
        maxStack = 3,
        weight = 0.5,
    },
    ["item_repair_kit"] = {
        type = "item",
        name = "Ремкомплект",
        desc = "Для ремонта транспорта",
        icon = "icon16/wrench.png",
        maxStack = 3,
        weight = 2.0,
    },

    -- === ДЕНЬГИ (физические, Код 81) ===
    -- Число в стаке = сумма. Дроп на землю — моделью cs_assault/money.mdl
    -- (см. grm_item_drop: def.model). Хранится в инвентаре и багажнике.
    ["money"] = {
        type = "item",
        name = "Деньги",
        desc = "Пачка наличных (число = сумма). Использование — обналичить в кошелёк.",
        icon = "icon16/money.png",
        maxStack = 50000,
        weight = 0.001,
        model = "models/props/cs_assault/money.mdl",
        useFunc = "cash_to_wallet",
    },
}

-- Функция регистрации нового предмета (для аддонов)
function GRM.Inventory.RegisterItem(id, data)
    if not id or not data then return end
    GRM.Inventory.ItemDefs[id] = data
end

-- Получить определение предмета
function GRM.Inventory.GetItemDef(itemID)
    return GRM.Inventory.ItemDefs[itemID]
end

-- Получить максимальный стак для предмета
function GRM.Inventory.GetMaxStack(itemID)
    local def = GRM.Inventory.ItemDefs[itemID]
    if not def then return 1 end
    if def.type == "weapon" then return 1 end
    return def.maxStack or GRM.Inventory.Config.MaxStack
end

-- ================================================================
--  СЕРВЕР
-- ================================================================
if SERVER then
    AddCSLuaFile()

    util.AddNetworkString("grm_inv_sync")
    util.AddNetworkString("grm_inv_update_slot")
    util.AddNetworkString("grm_inv_action")
    util.AddNetworkString("grm_inv_result")
    util.AddNetworkString("grm_inv_open")
    util.AddNetworkString("grm_inv_drop")
    util.AddNetworkString("grm_inv_use")
    util.AddNetworkString("grm_inv_move")
    util.AddNetworkString("grm_inv_split")

    local INV_FILE = "grm_inventories.json"
    local Inventories = {}  -- [SteamID64] = { slots = { [1] = {id="ammo_pistol", count=30}, ... } }

    -- ── Загрузка / Сохранение ────────────────────────────────────
    -- находка 114: лоадер БЕЗ 3-го аргумента конвертировал sid64-ключ
    -- «7656…» в битый double — после рестарта ВСЕ записи сиротели.
    local function loadInventories()
        if not file.Exists(INV_FILE, "DATA") then return {} end
        local raw = file.Read(INV_FILE, "DATA") or ""
        if raw == "" then return {} end
        local ok, t = pcall(util.JSONToTable, raw, false, true) -- н65: s64-ключи не конвертируем
        if not (ok and istable(t)) then return {} end
        local out = {}
        for k, rec in pairs(t) do
            if istable(rec) then
                local sk = k
                if isnumber(k) then sk = string.format("%.0f", k) end -- легаси битых сейвов
                if isstring(sk) and sk ~= "" then
                    local slots = {}
                    for kk, vv in pairs(rec.slots or {}) do
                        if istable(vv) then
                            slots[tonumber(kk) or kk] = vv -- ключи слотов — строго числа
                        end
                    end
                    rec.slots = slots
                    out[sk] = rec
                end
            end
        end
        return out
    end

    local function saveInventories(why)
        local ok, enc = pcall(util.TableToJSON, Inventories, true)
        if not ok or not isstring(enc) then
            print("[GRM Inv][!] TableToJSON упал, сейв пропущен (" .. tostring(why or "?") .. ")")
            return false
        end
        file.Write(INV_FILE, enc)
        local rb = file.Read(INV_FILE, "DATA") or ""
        if rb == "" then
            print("[GRM Inv][!] КОНТРОЛЬ ЗАПИСИ: файл пуст после save (" .. tostring(why or "?") .. ")")
            return false
        end
        return true
    end

    -- дебаунс-автосейв 2с на любых мутациях: закрывает окно 10с автотаймера
    local function saveSoon(why)
        timer.Create("GRM_Inv_SaveSoon", 2, 1, function()
            saveInventories("дебаунс: " .. tostring(why or "?"))
        end)
    end
    GRM.Inventory._devSaveSoon = saveSoon -- тест-экспорт

    Inventories = loadInventories()

    -- Автосохранение
    timer.Create("GRM_Inv_AutoSave", tonumber(GRM.Inventory.Config.SaveInterval) or 10, 0, function()
        saveInventories("авто")
    end)

    -- ── Получить инвентарь игрока ────────────────────────────────
    function GRM.Inventory.GetPlayerInv(ply)
        if not IsValid(ply) then return nil end
        local sid = ply:SteamID64()
        if not sid or sid == "0" then return nil end
        if not Inventories[sid] then
            -- находка 114: ленивое самолечение записи, покалеченной старым лоадером
            local num = tonumber(sid)
            if num then
                -- кандидаты: числовые ключи И числовые строки (после легаси-конвертации)
                local cand, cnt = nil, 0
                for k in pairs(Inventories) do
                    if k ~= sid then
                        local kn = isnumber(k) and k or (isstring(k) and tonumber(k) or nil)
                        if kn and math.abs(kn - num) < 64 then cand, cnt = k, cnt + 1 end
                    end
                end
                if cnt == 1 then -- строго единственный: чужой инвентарь не отдаём
                    Inventories[sid] = Inventories[cand]
                    Inventories[cand] = nil
                    saveSoon("sid64-rescue")
                    print("[GRM Inv] запись с битым ключом восстановлена → " .. sid)
                end
            end
        end
        if not Inventories[sid] then
            Inventories[sid] = { slots = {} }
        end
        return Inventories[sid]
    end

    -- ── Синхронизация с клиентом ─────────────────────────────────
    function GRM.Inventory.SyncToClient(ply)
        if not IsValid(ply) then return end
        local inv = GRM.Inventory.GetPlayerInv(ply)
        if not inv then return end
        net.Start("grm_inv_sync")
            net.WriteTable(inv.slots or {})
        net.Send(ply)
    end

    function GRM.Inventory.SyncSlot(ply, slotIdx)
        if not IsValid(ply) then return end
        local inv = GRM.Inventory.GetPlayerInv(ply)
        if not inv then return end
        net.Start("grm_inv_update_slot")
            net.WriteUInt(slotIdx, 8)
            net.WriteTable(inv.slots[slotIdx] or {})
        net.Send(ply)
    end

    -- ── Добавить предмет в инвентарь ─────────────────────────────
    -- Возвращает: количество, которое НЕ удалось добавить (0 = всё добавлено)
    function GRM.Inventory.AddItem(ply, itemID, count)
        if not IsValid(ply) then return count end
        local inv = GRM.Inventory.GetPlayerInv(ply)
        if not inv then return count end

        local def = GRM.Inventory.GetItemDef(itemID)
        if not def then return count end

        count = count or 1
        local maxStack = GRM.Inventory.GetMaxStack(itemID)
        local remaining = count

        -- Сначала пытаемся добавить в существующие стаки
        if def.type ~= "weapon" then
            for i = 1, GRM.Inventory.Config.MaxSlots do
                if remaining <= 0 then break end
                local slot = inv.slots[i]
                if slot and slot.id == itemID and (slot.count or 0) < maxStack then
                    local canAdd = math.min(remaining, maxStack - (slot.count or 0))
                    slot.count = (slot.count or 0) + canAdd
                    remaining = remaining - canAdd
                    GRM.Inventory.SyncSlot(ply, i)
                end
            end
        end

        -- Затем ищем пустые слоты
        while remaining > 0 do
            local emptySlot = nil
            for i = 1, GRM.Inventory.Config.MaxSlots do
                if not inv.slots[i] or not inv.slots[i].id then
                    emptySlot = i
                    break
                end
            end
            if not emptySlot then break end -- Инвентарь полон
            local toAdd = math.min(remaining, maxStack)
            inv.slots[emptySlot] = {
                id = itemID,
                count = toAdd,
            }
            remaining = remaining - toAdd
            GRM.Inventory.SyncSlot(ply, emptySlot)
        end

        saveSoon("add " .. tostring(itemID))
        return remaining
    end

    -- ── Добавить оружие в инвентарь ──────────────────────────────
    function GRM.Inventory.AddWeapon(ply, weaponClass, clip1, clip2)
        if not IsValid(ply) then return false end
        local inv = GRM.Inventory.GetPlayerInv(ply)
        if not inv then return false end

        -- Ищем пустой слот
        local emptySlot = nil
        for i = 1, GRM.Inventory.Config.MaxSlots do
            if not inv.slots[i] or not inv.slots[i].id then
                emptySlot = i
                break
            end
        end
        if not emptySlot then return false end -- Инвентарь полон

        inv.slots[emptySlot] = {
            id = "weapon:" .. weaponClass,
            count = 1,
            data = {
                class = weaponClass,
                clip1 = clip1 or 0,
                clip2 = clip2 or 0,
            }
        }
        GRM.Inventory.SyncSlot(ply, emptySlot)
        saveSoon("addweapon")
        return true
    end

    -- ── Удалить предмет из слота ─────────────────────────────────
    function GRM.Inventory.RemoveFromSlot(ply, slotIdx, count)
        if not IsValid(ply) then return false end
        local inv = GRM.Inventory.GetPlayerInv(ply)
        if not inv then return false end

        local slot = inv.slots[slotIdx]
        if not slot or not slot.id then return false end
        count = count or 1
        slot.count = (slot.count or 1) - count
        if slot.count <= 0 then
            inv.slots[slotIdx] = nil
        end
        GRM.Inventory.SyncSlot(ply, slotIdx)
        saveSoon("removefromslot")
        return true
    end

    -- ── Удалить предмет по ID ────────────────────────────────────
    function GRM.Inventory.RemoveItem(ply, itemID, count)
        if not IsValid(ply) then return count end
        local inv = GRM.Inventory.GetPlayerInv(ply)
        if not inv then return count end

        count = count or 1
        local remaining = count
        for i = 1, GRM.Inventory.Config.MaxSlots do
            if remaining <= 0 then break end
            local slot = inv.slots[i]
            if slot and slot.id == itemID then
                local toRemove = math.min(remaining, slot.count or 1)
                slot.count = (slot.count or 1) - toRemove
                remaining = remaining - toRemove
                if slot.count <= 0 then
                    inv.slots[i] = nil
                end
                GRM.Inventory.SyncSlot(ply, i)
            end
        end
        saveSoon("remove " .. tostring(itemID))
        return remaining
    end

    -- ── Подсчёт предмета в инвентаре ─────────────────────────────
    function GRM.Inventory.CountItem(ply, itemID)
        if not IsValid(ply) then return 0 end
        local inv = GRM.Inventory.GetPlayerInv(ply)
        if not inv then return 0 end

        local total = 0
        for i = 1, GRM.Inventory.Config.MaxSlots do
            local slot = inv.slots[i]
            if slot and slot.id == itemID then
                total = total + (slot.count or 1)
            end
        end
        return total
    end

    -- ── Проверить, есть ли свободные слоты ───────────────────────
    function GRM.Inventory.HasFreeSlot(ply)
        if not IsValid(ply) then return false end
        local inv = GRM.Inventory.GetPlayerInv(ply)
        if not inv then return false end

        for i = 1, GRM.Inventory.Config.MaxSlots do
            if not inv.slots[i] or not inv.slots[i].id then
                return true
            end
        end
        return false
    end

    -- ── Использование предмета ───────────────────────────────────
    local function useItem(ply, slotIdx)
        if not IsValid(ply) then return end
        local inv = GRM.Inventory.GetPlayerInv(ply)
        if not inv then return end

        local slot = inv.slots[slotIdx]
        if not slot or not slot.id then return end
        local itemID = slot.id

        -- Оружие — экипировать
        if string.StartWith(itemID, "weapon:") then
            local weaponClass = slot.data and slot.data.class
            if not weaponClass then return end

            -- Проверяем, нет ли уже этого оружия
            if ply:HasWeapon(weaponClass) then
                GRM.Notify(ply, "У вас уже есть это оружие", 255, 100, 100)
                return
            end
            local wep = ply:Give(weaponClass)
            if IsValid(wep) then
                if slot.data.clip1 and slot.data.clip1 > 0 then
                    wep:SetClip1(slot.data.clip1)
                end
                -- Удаляем из инвентаря
                inv.slots[slotIdx] = nil
                GRM.Inventory.SyncSlot(ply, slotIdx)
                GRM.Notify(ply, "Оружие экипировано", 100, 220, 100)
            end
            return
        end

        -- Патроны — добавить в запас
        local def = GRM.Inventory.GetItemDef(itemID)
        if not def then return end
        if def.type == "ammo" and def.ammoType then
            local amount = slot.count or 1
            ply:GiveAmmo(amount, def.ammoType, true)
            inv.slots[slotIdx] = nil
            GRM.Inventory.SyncSlot(ply, slotIdx)
            GRM.Notify(ply, "Получено " .. amount .. "x " .. def.name, 100, 220, 100)
            return
        end

        -- Предметы — использовать функцию
        if def.type == "item" and def.useFunc then
            local used = false
            if def.useFunc == "heal_25" then
                if ply:Health() < ply:GetMaxHealth() then
                    ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + 25))
                    used = true
                else
                    GRM.Notify(ply, "Здоровье уже полное", 255, 180, 60)
                    return
                end
            elseif def.useFunc == "armor_15" then
                if ply:Armor() < 100 then
                    ply:SetArmor(math.min(100, ply:Armor() + 15))
                    used = true
                else
                    GRM.Notify(ply, "Броня уже полная", 255, 180, 60)
                    return
                end
            elseif def.useFunc == "cash_to_wallet" then
                -- Деньги: число в стаке = сумма, обналичиваем ВЕСЬ стак
                local amt = math.max(0, math.floor(tonumber(slot.count) or 0))
                if amt > 0 and GRM.GiveMoney then
                    inv.slots[slotIdx] = nil
                    GRM.Inventory.SyncSlot(ply, slotIdx)
                    GRM.GiveMoney(ply, amt, "Обналичены деньги из инвентаря")
                    GRM.Notify(ply, "Обналичено: " .. (GRM.Format and GRM.Format(amt) or tostring(amt)), 100, 220, 100)
                    hook.Run("GRM_Money_Cashed", ply, amt)
                end
                return
            elseif def.useFunc == "mobile_open" then
                -- Код 88: мобильный телефон из инвентаря — предмет НЕ тратится.
                if GRM.Mobile and GRM.Mobile.ServerNotify then
                    GRM.Mobile.ServerNotify(ply, "Телефон у вас. Нажмите СТРЕЛКУ ВВЕРХ, чтобы открыть меню")
                else
                    GRM.Notify(ply, "Нажмите СТРЕЛКУ ВВЕРХ, чтобы открыть телефон", 100, 220, 100)
                end
                return
            end
            if used then
                GRM.Inventory.RemoveFromSlot(ply, slotIdx, 1)
                GRM.Notify(ply, "Использовано: " .. def.name, 100, 220, 100)
            end
            return
        end

        GRM.Notify(ply, "Этот предмет нельзя использовать", 255, 180, 60)
    end

    -- ── Выброс предмета ──────────────────────────────────────────
    local function dropItem(ply, slotIdx, count)
        if not IsValid(ply) then return end
        local inv = GRM.Inventory.GetPlayerInv(ply)
        if not inv then return end

        local slot = inv.slots[slotIdx]
        if not slot or not slot.id then return end
        count = math.min(count or 1, slot.count or 1)
        if count <= 0 then return end

        -- Создаём entity дропа
        local ent = ents.Create("grm_item_drop")
        if not IsValid(ent) then return end

        local pos = ply:GetPos() + ply:GetForward() * GRM.Inventory.Config.DropDistance + Vector(0, 0, 20)
        ent:SetPos(pos)
        ent:SetAngles(Angle(0, math.random(0, 360), 0))
        ent:Spawn()
        ent:SetItemID(slot.id)
        ent:SetItemCount(count)
        if slot.data then
            ent.ItemData = table.Copy(slot.data)
        end

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetVelocity(ply:GetForward() * 150 + Vector(0, 0, 80))
        end

        -- Удаляем из инвентаря
        slot.count = (slot.count or 1) - count
        if slot.count <= 0 then
            inv.slots[slotIdx] = nil
        end
        GRM.Inventory.SyncSlot(ply, slotIdx)

        GRM.Notify(ply, "Выброшено", 100, 220, 100)
    end

    -- ── Перемещение предмета между слотами ───────────────────────
    local function moveItem(ply, fromSlot, toSlot)
        if not IsValid(ply) then return end
        if fromSlot == toSlot then return end
        if fromSlot < 1 or fromSlot > GRM.Inventory.Config.MaxSlots then return end
        if toSlot < 1 or toSlot > GRM.Inventory.Config.MaxSlots then return end

        local inv = GRM.Inventory.GetPlayerInv(ply)
        if not inv then return end

        local from = inv.slots[fromSlot]
        local to = inv.slots[toSlot]

        if not from or not from.id then return end

        -- Если целевой слот пуст — просто перемещаем
        if not to or not to.id then
            inv.slots[toSlot] = from
            inv.slots[fromSlot] = nil
        -- Если тот же предмет — пытаемся стакировать
        elseif to.id == from.id and not string.StartWith(from.id, "weapon:") then
            local maxStack = GRM.Inventory.GetMaxStack(from.id)
            local canAdd = math.min(from.count or 1, maxStack - (to.count or 0))
            if canAdd > 0 then
                to.count = (to.count or 0) + canAdd
                from.count = (from.count or 1) - canAdd
                if from.count <= 0 then
                    inv.slots[fromSlot] = nil
                end
            else
                -- Меняем местами
                inv.slots[fromSlot] = to
                inv.slots[toSlot] = from
            end
        else
            -- Разные предметы — меняем местами
            inv.slots[fromSlot] = to
            inv.slots[toSlot] = from
        end

        GRM.Inventory.SyncSlot(ply, fromSlot)
        GRM.Inventory.SyncSlot(ply, toSlot)
    end

    -- ── Разделение стака ─────────────────────────────────────────
    local function splitStack(ply, slotIdx, splitCount)
        if not IsValid(ply) then return end
        local inv = GRM.Inventory.GetPlayerInv(ply)
        if not inv then return end

        local slot = inv.slots[slotIdx]
        if not slot or not slot.id then return end
        if string.StartWith(slot.id, "weapon:") then return end
        if (slot.count or 1) <= 1 then return end

        splitCount = math.Clamp(splitCount, 1, (slot.count or 1) - 1)

        -- Ищем пустой слот
        local emptySlot = nil
        for i = 1, GRM.Inventory.Config.MaxSlots do
            if not inv.slots[i] or not inv.slots[i].id then
                emptySlot = i
                break
            end
        end
        if not emptySlot then
            GRM.Notify(ply, "Нет свободных слотов", 255, 100, 100)
            return
        end

        slot.count = slot.count - splitCount
        inv.slots[emptySlot] = {
            id = slot.id,
            count = splitCount,
        }

        GRM.Inventory.SyncSlot(ply, slotIdx)
        GRM.Inventory.SyncSlot(ply, emptySlot)
    end

    -- ── Убрать оружие в инвентарь (из рук) ───────────────────────
    function GRM.Inventory.StoreActiveWeapon(ply)
        if not IsValid(ply) then return false end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) then
            GRM.Notify(ply, "Нет активного оружия", 255, 100, 100)
            return false
        end

        local class = wep:GetClass()
        if class == "weapon_fists" then
            GRM.Notify(ply, "Кулаки нельзя убрать в инвентарь", 255, 100, 100)
            return false
        end

        local clip1 = wep:Clip1()
        local clip2 = wep:Clip2()

        if not GRM.Inventory.HasFreeSlot(ply) then
            GRM.Notify(ply, "Инвентарь полон!", 255, 100, 100)
            return false
        end

        local ok = GRM.Inventory.AddWeapon(ply, class, clip1, clip2)
        if ok then
            ply:StripWeapon(class)
            GRM.Notify(ply, "Оружие убрано в инвентарь", 100, 220, 100)
            return true
        end
        return false
    end

    -- ── Подбор патронов с игрока (при смерти или вручную) ─────────
    function GRM.Inventory.StoreAmmoFromPlayer(ply, ammoType, amount)
        if not IsValid(ply) or amount <= 0 then return 0 end

        -- Находим itemID по ammoType
        local itemID = nil
        for id, def in pairs(GRM.Inventory.ItemDefs) do
            if def.type == "ammo" and def.ammoType == ammoType then
                itemID = id
                break
            end
        end
        if not itemID then return amount end

        local notAdded = GRM.Inventory.AddItem(ply, itemID, amount)
        local added = amount - notAdded
        if added > 0 then
            ply:RemoveAmmo(added, ammoType)
        end
        return notAdded
    end

    -- ── Сетевые обработчики ──────────────────────────────────────
    -- Открытие инвентаря
    net.Receive("grm_inv_open", function(_, ply)
        GRM.Inventory.SyncToClient(ply)
        net.Start("grm_inv_open")
        net.Send(ply)
    end)

    -- Использование предмета
    net.Receive("grm_inv_use", function(_, ply)
        local slotIdx = net.ReadUInt(8)
        useItem(ply, slotIdx)
        saveSoon("use")
    end)

    -- Выброс предмета
    net.Receive("grm_inv_drop", function(_, ply)
        local slotIdx = net.ReadUInt(8)
        local count = net.ReadUInt(16)
        dropItem(ply, slotIdx, count)
        saveSoon("drop")
    end)

    -- Перемещение предмета
    net.Receive("grm_inv_move", function(_, ply)
        local fromSlot = net.ReadUInt(8)
        local toSlot = net.ReadUInt(8)
        moveItem(ply, fromSlot, toSlot)
        saveSoon("move")
    end)

    -- Разделение стака
    net.Receive("grm_inv_split", function(_, ply)
        local slotIdx = net.ReadUInt(8)
        local splitCount = net.ReadUInt(16)
        splitStack(ply, slotIdx, splitCount)
        saveSoon("split")
    end)

    -- Действие (убрать оружие)
    net.Receive("grm_inv_action", function(_, ply)
        local action = net.ReadString()
        if action == "store_weapon" then
            GRM.Inventory.StoreActiveWeapon(ply)
            saveSoon("store_weapon")
        end
    end)

    -- ── Хуки ─────────────────────────────────────────────────────
    hook.Add("PlayerInitialSpawn", "GRM_Inv_Join", function(ply)
        timer.Simple(3, function()
            if IsValid(ply) then
                GRM.Inventory.SyncToClient(ply)
            end
        end)
    end)

    hook.Add("PlayerDisconnected", "GRM_Inv_Leave", function(ply)
        saveInventories()
    end)

    hook.Add("ShutDown", "GRM_Inv_Shutdown", function()
        saveInventories()
    end)

    -- ── Чат-команды ──────────────────────────────────────────────
    
    -- ── /drop — выбросить активное оружие на землю ───────────
    function GRM.Inventory.DropActiveWeapon(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return false end
        local wep = ply:GetActiveWeapon()
        if not IsValid(wep) then
            if GRM.Notify then GRM.Notify(ply, "Нет оружия в руках", 255, 180, 60) end
            return false
        end
        local class = wep:GetClass()
        if class == "weapon_fists" or class == "weapon_physgun" or class == "gmod_tool"
            or class == "weapon_physcannon" or class == "weapon_crowbar" then
            if GRM.Notify then GRM.Notify(ply, "Это нельзя выбросить", 255, 180, 60) end
            return false
        end
        -- SWEP наручников / ключей — не дропаем служебное
        if class == "grm_handcuffs" or class == "grm_cuffed" or class == "vehicle_keys_swep" then
            if GRM.Notify then GRM.Notify(ply, "Служебное оружие нельзя выбросить", 255, 180, 60) end
            return false
        end

        local clip1 = wep:Clip1()
        local clip2 = wep:Clip2()
        local itemID = "weapon:" .. class

        local ent = ents.Create("grm_item_drop")
        if not IsValid(ent) then
            -- fallback: engine drop
            ply:DropWeapon(wep)
            if GRM.Notify then GRM.Notify(ply, "Оружие выброшено (fallback)", 100, 220, 100) end
            return true
        end

        local dist = (GRM.Inventory.Config and GRM.Inventory.Config.DropDistance) or 80
        local pos = ply:GetShootPos() + ply:GetAimVector() * 40
        -- slightly forward of player feet if aim is bad
        if not pos or pos:DistToSqr(ply:GetPos()) > 40000 then
            pos = ply:GetPos() + ply:GetForward() * dist + Vector(0, 0, 30)
        end
        ent:SetPos(pos)
        ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
        ent:SetItemID(itemID)
        ent:SetItemCount(1)
        ent:SetDisplayName(wep:GetPrintName() ~= "" and wep:GetPrintName() or class)
        ent.ItemData = { class = class, clip1 = clip1, clip2 = clip2 }
        ent:Spawn()
        ent:Activate()

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:SetVelocity(ply:GetAimVector() * 180 + Vector(0, 0, 60))
        end

        ply:StripWeapon(class)
        if GRM.Notify then GRM.Notify(ply, "Оружие выброшено: " .. (ent:GetDisplayName() or class), 100, 220, 100) end
        return true
    end

    hook.Add("PlayerSay", "GRM_Inv_ChatCmds", function(ply, text)
        local cmd = string.Trim(string.lower(text or ""))
        local args = string.Explode(" ", cmd)
        local c0 = args[1] or ""

        if c0 == "/inv" or c0 == "/inventory" or c0 == "!inv" or c0 == "!inventory" then
            GRM.Inventory.SyncToClient(ply)
            net.Start("grm_inv_open")
            net.Send(ply)
            return ""
        end

        if c0 == "/store" or c0 == "!store" then
            GRM.Inventory.StoreActiveWeapon(ply)
            return ""
        end

        -- /drop — оружие из рук на землю (entity grm_item_drop)
        if c0 == "/drop" or c0 == "!drop" or c0 == "/dropweapon" or c0 == "!dropweapon" then
            GRM.Inventory.DropActiveWeapon(ply)
            return ""
        end
    end)

    print("[GRM] Inventory v1.1.0 (Код 97) — сервер загружен")
end

-- ================================================================
--  КЛИЕНТ
-- ================================================================
if CLIENT then
    GRM.Inventory.LocalSlots = GRM.Inventory.LocalSlots or {}

    net.Receive("grm_inv_sync", function()
        GRM.Inventory.LocalSlots = net.ReadTable() or {}
        hook.Run("GRM_InventoryUpdated")
    end)

    net.Receive("grm_inv_update_slot", function()
        local idx = net.ReadUInt(8)
        local data = net.ReadTable()
        if data and data.id then
            GRM.Inventory.LocalSlots[idx] = data
        else
            GRM.Inventory.LocalSlots[idx] = nil
        end
        hook.Run("GRM_InventoryUpdated")
    end)

    net.Receive("grm_inv_open", function()
        GRM.Inventory.OpenGUI()
    end)

    -- Запрос открытия
    function GRM.Inventory.RequestOpen()
        net.Start("grm_inv_open")
        net.SendToServer()
    end

    -- Действия
    function GRM.Inventory.UseSlot(slotIdx)
        net.Start("grm_inv_use")
            net.WriteUInt(slotIdx, 8)
        net.SendToServer()
    end

    function GRM.Inventory.DropSlot(slotIdx, count)
        net.Start("grm_inv_drop")
            net.WriteUInt(slotIdx, 8)
            net.WriteUInt(count or 1, 16)
        net.SendToServer()
    end

    function GRM.Inventory.MoveSlot(fromSlot, toSlot)
        net.Start("grm_inv_move")
            net.WriteUInt(fromSlot, 8)
            net.WriteUInt(toSlot, 8)
        net.SendToServer()
    end

    function GRM.Inventory.SplitSlot(slotIdx, count)
        net.Start("grm_inv_split")
            net.WriteUInt(slotIdx, 8)
            net.WriteUInt(count, 16)
        net.SendToServer()
    end

    function GRM.Inventory.StoreWeapon()
        net.Start("grm_inv_action")
            net.WriteString("store_weapon")
        net.SendToServer()
    end

    -- Бинд на клавишу (по умолчанию I)
    hook.Add("PlayerBindPress", "GRM_Inv_Bind", function(ply, bind, pressed)
        -- Можно добавить бинд на кнопку
    end)

    concommand.Add("grm_inventory", function()
        GRM.Inventory.RequestOpen()
    end)

    print("[GRM] Inventory v1.1.0 — клиент загружен")
end
