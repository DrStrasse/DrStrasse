--[[--------------------------------------------------------------------
    GRM Food x GRM Inventory Patch

    Куда положить:
      garrysmod/addons/grm_food/lua/autorun/zz_grm_food_inventory_patch.lua

    Что делает:
      1) Отодвигает спавн еды/напитков от автомата.
      2) Исправляет модель еды при покупке: модель берётся из GRM.Food.Config.FoodItems[itemID].model.
      3) Еду/напитки с земли можно подобрать в GRM Inventory через E.
      4) Еду/напитки можно использовать из GRM Inventory.
      5) Ничего не требует править в основных файлах: патч ставится отдельным autorun-файлом.
--------------------------------------------------------------------]]

if SERVER then
    AddCSLuaFile()
end

GRM = GRM or {}
GRM.Food = GRM.Food or {}
GRM.Inventory = GRM.Inventory or {}

-- ===================================================================
-- НАСТРОЙКИ ПАТЧА
-- ===================================================================

GRM.Food.InventoryPatch = GRM.Food.InventoryPatch or {}

-- Дистанция от КРАЯ автомата, а не от его центра.
-- Было 18, теперь 20: на 2 юнита дальше, но всё ещё рядом с автоматом.
GRM.Food.InventoryPatch.VendingDropDistance = GRM.Food.InventoryPatch.VendingDropDistance or 20

-- С какой стороны автомата выдавать товар:
--  1  = по локальному Forward автомата;
-- -1  = с обратной стороны, если на вашей модели forward смотрит назад.
GRM.Food.InventoryPatch.VendingDropForwardSign = GRM.Food.InventoryPatch.VendingDropForwardSign or 1

-- Высота над полом после trace вниз. 12 юнитов хватает, чтобы еда не проваливалась в пол.
GRM.Food.InventoryPatch.VendingDropHeight = GRM.Food.InventoryPatch.VendingDropHeight or 12

-- Скорость лёгкого "выпадения" товара. По умолчанию 0, чтобы предмет оставался
-- именно в рассчитанной точке: по центру автомата и на 20 юнитов от края.
GRM.Food.InventoryPatch.VendingThrowVelocity = GRM.Food.InventoryPatch.VendingThrowVelocity or 0
GRM.Food.InventoryPatch.VendingThrowUpVelocity = GRM.Food.InventoryPatch.VendingThrowUpVelocity or 0

-- Покупка из автомата сразу кладёт еду/напитки в инвентарь.
-- Игрок будет есть/пить уже из инвентаря.
-- Если поставить false, автомат снова будет дропать предмет на землю.
GRM.Food.InventoryPatch.GivePurchasedFoodDirectlyToInventory = true

-- Запретить прямое поедание еды с земли.
-- true = E на еде всегда пытается положить её в инвентарь, а не съесть сразу.
GRM.Food.InventoryPatch.ForceInventoryPickup = true

-- Звуки автомата.
-- ButtonSound играет сразу после нажатия кнопки покупки у валидного автомата.
-- SuccessSound играет при успешной покупке.
-- ErrorSound играет при ошибке покупки: нет денег, нет места, предмет не найден и т.п.
GRM.Food.InventoryPatch.VendingButtonSound = GRM.Food.InventoryPatch.VendingButtonSound or "buttons/button14.wav"
GRM.Food.InventoryPatch.VendingSuccessSound = GRM.Food.InventoryPatch.VendingSuccessSound or "buttons/button9.wav"
GRM.Food.InventoryPatch.VendingErrorSound = GRM.Food.InventoryPatch.VendingErrorSound or "buttons/button10.wav"
GRM.Food.InventoryPatch.VendingSoundLevel = GRM.Food.InventoryPatch.VendingSoundLevel or 65
GRM.Food.InventoryPatch.VendingSoundPitch = GRM.Food.InventoryPatch.VendingSoundPitch or 100

-- ===================================================================
-- ОБЩИЕ ХЕЛПЕРЫ
-- ===================================================================

local function foodCfg()
    return GRM and GRM.Food and GRM.Food.Config or nil
end

local function invCfg()
    return GRM and GRM.Inventory and GRM.Inventory.Config or nil
end

local function getFoodData(itemID)
    local cfg = foodCfg()
    if not cfg or not cfg.FoodItems then return nil end
    return cfg.FoodItems[itemID]
end

local function isFoodItem(itemID)
    return getFoodData(itemID) ~= nil
end

local function notify(ply, msg, r, g, b)
    if SERVER then
        if GRM and GRM.Notify then
            GRM.Notify(ply, msg, r or 255, g or 255, b or 255)
        elseif IsValid(ply) then
            ply:ChatPrint(msg)
        else
            print(msg)
        end
    else
        if GRM and GRM.AddNotification then
            GRM.AddNotification(msg, 4, Color(r or 255, g or 255, b or 255))
        else
            chat.AddText(Color(r or 255, g or 255, b or 255), msg)
        end
    end
end

local function registerFoodItemsInInventory()
    local cfg = foodCfg()
    if not cfg or not cfg.FoodItems then return false end
    if not GRM.Inventory or not GRM.Inventory.RegisterItem then return false end

    local itemMaxStack = 10
    if invCfg() and invCfg().ItemMaxStack then
        itemMaxStack = invCfg().ItemMaxStack
    end

    for itemID, data in pairs(cfg.FoodItems) do
        GRM.Inventory.RegisterItem(itemID, {
            type = "item",
            name = data.name or itemID,
            desc = "Еда/напиток. Сытость: +" .. tostring(data.hungerRestore or 0) .. ", HP: +" .. tostring(data.healthRestore or 0),
            icon = data.icon or "icon16/cup.png",
            model = data.model,
            maxStack = data.maxStack or itemMaxStack,
            weight = data.weight or 0.3,
            useFunc = "grm_food_eat",
            grmFood = true,
            grmFoodID = itemID,
        })
    end

    return true
end

local function startRegistrationTimer()
    if timer.Exists("GRM_FoodInventoryPatch_RegisterItems") then
        timer.Remove("GRM_FoodInventoryPatch_RegisterItems")
    end

    local tries = 0
    timer.Create("GRM_FoodInventoryPatch_RegisterItems", 1, 60, function()
        tries = tries + 1

        if registerFoodItemsInInventory() then
            timer.Remove("GRM_FoodInventoryPatch_RegisterItems")
            return
        end

        if tries >= 60 then
            timer.Remove("GRM_FoodInventoryPatch_RegisterItems")
        end
    end)
end

startRegistrationTimer()
hook.Add("InitPostEntity", "GRM_FoodInventoryPatch_RegisterItems", startRegistrationTimer)

-- ===================================================================
-- КЛИЕНТУ НУЖНА ТОЛЬКО РЕГИСТРАЦИЯ ItemDefs
-- ===================================================================

if CLIENT then
    return
end

-- ===================================================================
-- СЕРВЕР: ИСПОЛЬЗОВАНИЕ ЕДЫ ИЗ ИНВЕНТАРЯ
-- ===================================================================

local function canUseFoodNow(ply, data)
    if not IsValid(ply) then return false end

    local hungerMax = foodCfg() and foodCfg().HungerMax or 100
    local hunger = hungerMax

    if GRM.Food.GetHunger then
        hunger = GRM.Food.GetHunger(ply) or hungerMax
    end

    local restoresHunger = (tonumber(data.hungerRestore) or 0) > 0 and hunger < hungerMax
    local restoresHealth = (tonumber(data.healthRestore) or 0) > 0 and ply:Health() < ply:GetMaxHealth()

    return restoresHunger or restoresHealth
end

local function useFoodFromInventory(ply, slotIdx, slot, itemID, data)
    if not canUseFoodNow(ply, data) then
        notify(ply, "[Еда] Сейчас это не нужно: сытость/здоровье уже полные.", 255, 180, 60)
        return
    end

    if GRM.Food.RestoreHunger then
        GRM.Food.RestoreHunger(ply, tonumber(data.hungerRestore) or 0)
    elseif GRM.Food.SetHunger and GRM.Food.GetHunger then
        GRM.Food.SetHunger(ply, (GRM.Food.GetHunger(ply) or 0) + (tonumber(data.hungerRestore) or 0))
    end

    local hpRestore = tonumber(data.healthRestore) or 0
    if hpRestore > 0 then
        ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + hpRestore))
    end

    if GRM.Inventory and GRM.Inventory.RemoveFromSlot then
        GRM.Inventory.RemoveFromSlot(ply, slotIdx, 1)
    end

    ply:EmitSound("npc/barnacle/barnacle_gulp1.wav", 70, 100)
    notify(ply, "[Еда] Использовано: " .. (data.name or itemID) .. ".", 100, 220, 100)
end

-- Полная замена grm_inv_use нужна потому, что в вашем Inventory useItem — local-функция,
-- её нельзя расширить hook'ом. Поэтому здесь повторяется штатная логика + добавлена еда.
local function patchedInventoryUse(ply, slotIdx)
    if not IsValid(ply) then return end
    if not GRM.Inventory or not GRM.Inventory.GetPlayerInv then return end

    registerFoodItemsInInventory()

    local inv = GRM.Inventory.GetPlayerInv(ply)
    if not inv then return end

    local slot = inv.slots and inv.slots[slotIdx]
    if not slot or not slot.id then return end

    local itemID = slot.id

    -- Еда/напитки GRM Food
    local foodData = getFoodData(itemID)
    if foodData then
        useFoodFromInventory(ply, slotIdx, slot, itemID, foodData)
        return
    end

    -- Оружие — экипировать
    if string.StartWith(itemID, "weapon:") then
        local weaponClass = slot.data and slot.data.class
        if not weaponClass then return end

        if ply:HasWeapon(weaponClass) then
            notify(ply, "У вас уже есть это оружие", 255, 100, 100)
            return
        end

        local wep = ply:Give(weaponClass)
        if IsValid(wep) then
            if slot.data and slot.data.clip1 and slot.data.clip1 > 0 then
                wep:SetClip1(slot.data.clip1)
            end

            inv.slots[slotIdx] = nil
            if GRM.Inventory.SyncSlot then
                GRM.Inventory.SyncSlot(ply, slotIdx)
            end

            notify(ply, "Оружие экипировано", 100, 220, 100)
        end

        return
    end

    local def = GRM.Inventory.GetItemDef and GRM.Inventory.GetItemDef(itemID) or nil
    if not def then return end

    -- Патроны — добавить в запас
    if def.type == "ammo" and def.ammoType then
        local amount = slot.count or 1
        ply:GiveAmmo(amount, def.ammoType, true)
        inv.slots[slotIdx] = nil

        if GRM.Inventory.SyncSlot then
            GRM.Inventory.SyncSlot(ply, slotIdx)
        end

        notify(ply, "Получено " .. amount .. "x " .. (def.name or itemID), 100, 220, 100)
        return
    end

    -- Обычные предметы из Inventory
    if def.type == "item" and def.useFunc then
        local used = false

        if def.useFunc == "heal_25" then
            if ply:Health() < ply:GetMaxHealth() then
                ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + 25))
                used = true
            else
                notify(ply, "Здоровье уже полное", 255, 180, 60)
                return
            end
        elseif def.useFunc == "armor_15" then
            if ply:Armor() < 100 then
                ply:SetArmor(math.min(100, ply:Armor() + 15))
                used = true
            else
                notify(ply, "Броня уже полная", 255, 180, 60)
                return
            end
        elseif def.useFunc == "grm_food_eat" then
            local data = getFoodData(itemID)
            if data then
                useFoodFromInventory(ply, slotIdx, slot, itemID, data)
                return
            end
        end

        if used then
            if GRM.Inventory.RemoveFromSlot then
                GRM.Inventory.RemoveFromSlot(ply, slotIdx, 1)
            end
            notify(ply, "Использовано: " .. (def.name or itemID), 100, 220, 100)
        end

        return
    end

    notify(ply, "Этот предмет нельзя использовать", 255, 180, 60)
end

local function installInventoryUsePatch()
    if not GRM.Inventory or not GRM.Inventory.GetPlayerInv or not GRM.Inventory.SyncSlot then
        return false
    end

    util.AddNetworkString("grm_inv_use")

    net.Receive("grm_inv_use", function(_, ply)
        local slotIdx = net.ReadUInt(8)
        patchedInventoryUse(ply, slotIdx)
    end)

    return true
end

-- ===================================================================
-- СЕРВЕР: ЕДА С ЗЕМЛИ ПОДБИРАЕТСЯ В ИНВЕНТАРЬ
-- ===================================================================

local function resolveFoodEntItemID(ent)
    if not IsValid(ent) then return "" end

    local itemID = ent.GRMFoodItemID

    if (not itemID or itemID == "") and ent.GetItemID then
        itemID = ent:GetItemID()
    end

    if (not itemID or itemID == "") and ent.GetNWString then
        itemID = ent:GetNWString("ItemID", "")
    end

    if not itemID or itemID == "" then
        itemID = "grm_food_apple"
    end

    return itemID
end

local function eatWorldFoodFallback(ent, ply, itemID, data)
    if GRM.Food.RestoreHunger then
        GRM.Food.RestoreHunger(ply, tonumber(data.hungerRestore) or 0)
    end

    local hpRestore = tonumber(data.healthRestore) or 0
    if hpRestore > 0 then
        ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + hpRestore))
    end

    ply:EmitSound("npc/barnacle/barnacle_gulp1.wav", 70, 100)
    notify(ply, "[Еда] Вы использовали: " .. (data.name or itemID) .. ".", 100, 220, 100)
    ent:Remove()
end

local function patchFoodEntityUse()
    local stored = scripted_ents.GetStored("grm_food_item")
    if not stored or not stored.t then return false end

    local entTable = stored.t
    if entTable.GRMFoodInventoryPatch_UsePatched then return true end

    local oldUse = entTable.Use

    entTable.Use = function(self, activator)
        if not IsValid(activator) or not activator:IsPlayer() then return end

        local itemID = resolveFoodEntItemID(self)
        local data = getFoodData(itemID)

        if not data then
            if oldUse then
                return oldUse(self, activator)
            end

            activator:ChatPrint("[Еда] Ошибка: неизвестный тип еды.")
            return
        end

        registerFoodItemsInInventory()

        local patchCfg = GRM.Food.InventoryPatch or {}
        local forceInv = patchCfg.ForceInventoryPickup ~= false
        local invReady = GRM.Inventory and GRM.Inventory.AddItem and GRM.Inventory.GetItemDef

        -- E на еде/напитке кладёт предмет в инвентарь.
        -- Прямое поедание с земли запрещено, чтобы игрок ел уже из GUI инвентаря.
        if invReady then
            if not GRM.Inventory.GetItemDef(itemID) then
                registerFoodItemsInInventory()
            end

            if not GRM.Inventory.GetItemDef(itemID) then
                notify(activator, "[Инвентарь] Предмет не зарегистрирован: " .. itemID, 255, 100, 100)
                return
            end

            local notAdded = GRM.Inventory.AddItem(activator, itemID, 1)

            if notAdded and notAdded <= 0 then
                activator:EmitSound("items/itempickup.wav", 70, 100)
                notify(activator, "[Инвентарь] Подобрано: " .. (data.name or itemID) .. ".", 100, 220, 100)
                self:Remove()
            else
                notify(activator, "[Инвентарь] Нет места для: " .. (data.name or itemID) .. ".", 255, 100, 100)
            end

            return
        end

        if forceInv then
            notify(activator, "[Инвентарь] Инвентарь не загружен, поэтому еду нельзя использовать напрямую.", 255, 180, 60)
            return
        end

        -- Запасной режим, если ForceInventoryPickup = false.
        eatWorldFoodFallback(self, activator, itemID, data)
    end

    entTable.GRMFoodInventoryPatch_UsePatched = true
    return true
end

-- ===================================================================
-- СЕРВЕР: ПОКУПКА ИЗ АВТОМАТА С НОРМАЛЬНЫМ ОТСТУПОМ ОТ АВТОМАТА
-- ===================================================================

local function isItemAllowedInVending(itemID)
    local cfg = foodCfg()
    if not cfg then return false end

    for _, allowedID in ipairs(cfg.VendingMachineItems or {}) do
        if allowedID == itemID then
            return true
        end
    end

    return false
end

local function findVendingDropPos(ply, ent)
    local patchCfg = GRM.Food.InventoryPatch or {}
    local dist = math.Clamp(tonumber(patchCfg.VendingDropDistance) or 20, 0, 24)
    local height = math.Clamp(tonumber(patchCfg.VendingDropHeight) or 12, 6, 24)

    -- Правильная точка выдачи:
    --   X: передний край OBB автомата + 20 юнитов;
    --   Y: центр автомата по ширине;
    --   Z: вычисляется trace'ом до пола + нормальная высота.
    -- Так предмет появляется ровно по центру автомата, а не сбоку от позиции игрока.
    local mins = ent:OBBMins()
    local maxs = ent:OBBMaxs()

    local sign = tonumber(patchCfg.VendingDropForwardSign) or 1
    sign = sign >= 0 and 1 or -1

    local edgeX = sign == 1 and maxs.x or mins.x
    local centerY = (mins.y + maxs.y) * 0.5
    local midZ = (mins.z + maxs.z) * 0.5

    local localDrop = Vector(edgeX + dist * sign, centerY, midZ)
    local base = ent:LocalToWorld(localDrop)

    -- Подбираем позицию около пола, чтобы предмет не висел в воздухе и не проваливался.
    local tr = util.TraceHull({
        start = base + Vector(0, 0, 48),
        endpos = base - Vector(0, 0, 128),
        mins = Vector(-7, -7, 0),
        maxs = Vector(7, 7, 14),
        filter = { ply, ent },
        mask = MASK_SOLID,
    })

    if tr.Hit then
        return tr.HitPos + Vector(0, 0, height)
    end

    return base + Vector(0, 0, height)
end

local function playVendingSound(ent, soundKey)
    if not IsValid(ent) then return end

    local patchCfg = GRM.Food.InventoryPatch or {}
    local soundPath = patchCfg[soundKey]

    if not soundPath or soundPath == "" then return end

    ent:EmitSound(
        soundPath,
        tonumber(patchCfg.VendingSoundLevel) or 65,
        tonumber(patchCfg.VendingSoundPitch) or 100,
        1,
        CHAN_AUTO
    )
end

local function spawnFoodFromVending(ply, ent, itemID, data)
    local food = ents.Create("grm_food_item")
    if not IsValid(food) then return nil end

    -- Ставим itemID и модель ДО Spawn(), чтобы Initialize() не успел поставить дефолт.
    food.GRMFoodItemID = itemID

    if food.SetItemID then
        food:SetItemID(itemID)
    end

    food:SetNWString("ItemID", itemID)
    food:SetModel(data.model or "models/props/cs_office/coffee_mug.mdl")
    food:SetPos(findVendingDropPos(ply, ent))
    food:SetAngles(Angle(0, math.random(0, 360), 0))
    food:Spawn()

    if food.SetFoodItemID then
        food:SetFoodItemID(itemID)
    else
        if food.SetItemID then
            food:SetItemID(itemID)
        end

        food:SetNWString("ItemID", itemID)
        food:SetModel(data.model or "models/props/cs_office/coffee_mug.mdl")
    end

    food:SetOwner(ply)

    local phys = food:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()

        local patchCfg = GRM.Food.InventoryPatch or {}
        local throwVel = math.Clamp(tonumber(patchCfg.VendingThrowVelocity) or 0, 0, 20)
        local upVel = math.Clamp(tonumber(patchCfg.VendingThrowUpVelocity) or 0, 0, 20)

        if throwVel > 0 or upVel > 0 then
            local sign = tonumber(patchCfg.VendingDropForwardSign) or 1
            sign = sign >= 0 and 1 or -1

            local dir = ent:GetForward() * sign
            dir.z = 0

            if dir:LengthSqr() > 1 then
                dir:Normalize()
                phys:SetVelocity(dir * throwVel + Vector(0, 0, upVel))
            else
                phys:SetVelocity(Vector(0, 0, upVel))
            end
        else
            phys:SetVelocity(Vector(0, 0, 0))
        end
    end

    return food
end

local function installVendingBuyPatch()
    if not GRM.Food or not GRM.Food.Config then return false end

    util.AddNetworkString("GRM_Vending_Buy")

    net.Receive("GRM_Vending_Buy", function(_, ply)
        if not IsValid(ply) then return end

        ply.GRMFoodNextBuy = ply.GRMFoodNextBuy or 0
        if CurTime() < ply.GRMFoodNextBuy then return end
        ply.GRMFoodNextBuy = CurTime() + 0.3

        local ent = net.ReadEntity()
        local itemID = net.ReadString()

        if not IsValid(ent) or ent:GetClass() ~= "grm_vending_machine" then
            notify(ply, "[Автомат] Ошибка: неверный автомат.", 255, 100, 100)
            return
        end

        local cfg = foodCfg()
        local maxDist = cfg and (cfg.VendingUseDistance or 150) or 150

        if ply:GetPos():DistToSqr(ent:GetPos()) > maxDist * maxDist then
            notify(ply, "[Автомат] Вы слишком далеко от автомата.", 255, 100, 100)
            return
        end

        -- Звук физической кнопки автомата: игрок нажал "Купить".
        -- Ставим после проверки дистанции, чтобы нельзя было спамить звук через всю карту.
        playVendingSound(ent, "VendingButtonSound")

        if not isItemAllowedInVending(itemID) then
            playVendingSound(ent, "VendingErrorSound")
            notify(ply, "[Автомат] Этот товар нельзя купить здесь.", 255, 100, 100)
            return
        end

        local data = getFoodData(itemID)
        if not data then
            playVendingSound(ent, "VendingErrorSound")
            notify(ply, "[Автомат] Товар не найден.", 255, 100, 100)
            return
        end

        local price = tonumber(data.price) or 0

        if GRM.HasMoney and not GRM.HasMoney(ply, price) then
            playVendingSound(ent, "VendingErrorSound")
            notify(ply, "[Автомат] Недостаточно денег!", 255, 100, 100)
            return
        end

        registerFoodItemsInInventory()

        local directToInv = GRM.Food.InventoryPatch and GRM.Food.InventoryPatch.GivePurchasedFoodDirectlyToInventory

        if directToInv then
            local invReady = GRM.Inventory and GRM.Inventory.AddItem and GRM.Inventory.GetItemDef

            if not invReady then
                playVendingSound(ent, "VendingErrorSound")
                notify(ply, "[Автомат] Инвентарь не загружен, покупка еды невозможна.", 255, 100, 100)
                return
            end

            if not GRM.Inventory.GetItemDef(itemID) then
                registerFoodItemsInInventory()
            end

            if not GRM.Inventory.GetItemDef(itemID) then
                playVendingSound(ent, "VendingErrorSound")
                notify(ply, "[Автомат] Предмет не зарегистрирован в инвентаре: " .. itemID, 255, 100, 100)
                return
            end

            local notAdded = GRM.Inventory.AddItem(ply, itemID, 1)

            if notAdded and notAdded > 0 then
                playVendingSound(ent, "VendingErrorSound")
                notify(ply, "[Автомат] В инвентаре нет места.", 255, 100, 100)
                return
            end

            if GRM.TakeMoney then
                GRM.TakeMoney(ply, price)
            end

            playVendingSound(ent, "VendingSuccessSound")
            notify(ply, "[Автомат] Вы купили " .. (data.name or itemID) .. " — предмет добавлен в инвентарь.", 100, 220, 100)
            return
        end

        local food = spawnFoodFromVending(ply, ent, itemID, data)
        if not IsValid(food) then
            playVendingSound(ent, "VendingErrorSound")
            notify(ply, "[Автомат] Ошибка выдачи товара.", 255, 100, 100)
            return
        end

        if GRM.TakeMoney then
            GRM.TakeMoney(ply, price)
        end

        playVendingSound(ent, "VendingSuccessSound")
        notify(ply, "[Автомат] Вы купили " .. (data.name or itemID) .. ". Нажмите E, чтобы подобрать в инвентарь.", 100, 220, 100)
    end)

    return true
end

-- ===================================================================
-- УСТАНОВКА ПАТЧЕЙ С ЗАДЕРЖКОЙ
-- ===================================================================

local function tryInstallAll()
    registerFoodItemsInInventory()
    installInventoryUsePatch()
    patchFoodEntityUse()
    installVendingBuyPatch()
end

hook.Add("InitPostEntity", "GRM_FoodInventoryPatch_Install", function()
    timer.Simple(1, tryInstallAll)
    timer.Simple(3, tryInstallAll)
    timer.Simple(6, tryInstallAll)
end)

if timer.Exists("GRM_FoodInventoryPatch_InstallTimer") then
    timer.Remove("GRM_FoodInventoryPatch_InstallTimer")
end

local installTries = 0
timer.Create("GRM_FoodInventoryPatch_InstallTimer", 1, 15, function()
    installTries = installTries + 1
    tryInstallAll()

    if installTries >= 15 then
        timer.Remove("GRM_FoodInventoryPatch_InstallTimer")
    end
end)

print("[GRM Food] Inventory patch loaded: pickup/use food + vending drop distance fix.")
