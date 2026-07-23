--[[--------------------------------------------------------------------
    GRM Factory Full Cycle — server
----------------------------------------------------------------------]]

if CLIENT then return end

AddCSLuaFile("autorun/sh_grm_factory_fullcycle_config.lua")
AddCSLuaFile("autorun/sh_grm_factory_fullcycle_entities.lua")
AddCSLuaFile("autorun/client/cl_grm_factory_fullcycle.lua")
include("autorun/sh_grm_factory_fullcycle_config.lua")
include("autorun/sh_grm_factory_fullcycle_entities.lua")

GRM = GRM or {}
GRM.FactoryCycle = GRM.FactoryCycle or {}
local FC = GRM.FactoryCycle
local CFG = FC.Config

local NET_OPEN_CRAFT = "GRM_FC_OpenCraft"
local NET_OPEN_STORAGE = "GRM_FC_OpenStorage"
local NET_OPEN_SCRAP = "GRM_FC_OpenScrap"
local NET_OPEN_TERMINAL = "GRM_FC_OpenTerminal"
local NET_ACTION = "GRM_FC_Action"
local NET_RESULT = "GRM_FC_Result"
local NET_QTE_START = "GRM_FC_QTE_Start"
local NET_QTE_STATE = "GRM_FC_QTE_State"
local NET_QTE_FINISH = "GRM_FC_QTE_Finish"
local NET_QTE_INPUT = "GRM_FC_QTE_Input"
local NET_QTE_ABORT = "GRM_FC_QTE_Abort"
local NET_OPEN_WEAPON_BUYER = "GRM_FC_OpenWeaponBuyer"
local NET_OPEN_WEAPON_LOCKER = "GRM_FC_OpenWeaponLocker"
local NET_OPEN_WEAPON_ADMIN = "GRM_FC_OpenWeaponAdmin"

for _, name in ipairs({ NET_OPEN_CRAFT, NET_OPEN_STORAGE, NET_OPEN_SCRAP, NET_OPEN_TERMINAL, NET_ACTION, NET_RESULT, NET_QTE_START, NET_QTE_STATE, NET_QTE_FINISH, NET_QTE_INPUT, NET_QTE_ABORT, NET_OPEN_WEAPON_BUYER, NET_OPEN_WEAPON_LOCKER, NET_OPEN_WEAPON_ADMIN }) do
    util.AddNetworkString(name)
end

FC.StorageData = FC.StorageData or {}
FC.LoadingMap = false

local EQUIPMENT_CLASSES = {
    grm_fc_gpu_station = true,
    grm_fc_components_station = true,
    grm_fc_weapon_station = true,
    grm_fc_furnace = true,
    grm_fc_weapon_buyer = true,
    grm_fc_weapon_locker = true,
    grm_fc_storage = true,
    grm_fc_scrap_bin = true,
    grm_fc_terminal = true,
}

local PRODUCT_CLASSES = {
    grm_fc_gpu = true,
    grm_fc_product = true,
}

local DATA_DIR = "grm_factory_fullcycle"
local MAP_DIR = DATA_DIR .. "/maps"
local LOCKERS_FILE = DATA_DIR .. "/weapon_lockers.json"
local MARKET_FILE = DATA_DIR .. "/weapon_market.json"
local BUYERS_FILE = DATA_DIR .. "/weapon_buyers.json"

FC.WeaponBuyerData = FC.WeaponBuyerData or {}
FC.WeaponLockerData = FC.WeaponLockerData or {}
FC.WeaponMarketData = FC.WeaponMarketData or {}

local function trim(value) return string.Trim(tostring(value or "")) end

local function ensureDirectories()
    if not file.Exists(DATA_DIR, "DATA") then file.CreateDir(DATA_DIR) end
    if not file.Exists(MAP_DIR, "DATA") then file.CreateDir(MAP_DIR) end
end

local function mapFile()
    return MAP_DIR .. "/" .. string.lower(game.GetMap() or "unknown") .. ".json"
end

local function readJSON(path, fallback)
    if not file.Exists(path, "DATA") then return table.Copy(fallback or {}) end
    local raw = file.Read(path, "DATA") or ""
    if raw == "" then return table.Copy(fallback or {}) end
    local ok, data = pcall(util.JSONToTable, raw)
    return ok and istable(data) and data or table.Copy(fallback or {})
end

local function writeJSON(path, data)
    ensureDirectories()
    local json = util.TableToJSON(data or {}, true)
    if json then file.Write(path, json) end
end

local function defaultMarket()
    local result = {}
    for class, info in pairs((CFG.WeaponMarket and CFG.WeaponMarket.Weapons) or {}) do
        result[class] = { name = info.name or class, price = tonumber(info.price) or 0 }
    end
    return result
end

local function loadWeaponData()
    FC.WeaponLockerData = readJSON(LOCKERS_FILE, {})
    FC.WeaponBuyerData = readJSON(BUYERS_FILE, {})
    FC.WeaponMarketData = readJSON(MARKET_FILE, defaultMarket())

    -- Новые оружия из конфига добавляются, но старые админские цены не затираются.
    for class, info in pairs(defaultMarket()) do
        FC.WeaponMarketData[class] = FC.WeaponMarketData[class] or info
        FC.WeaponMarketData[class].name = FC.WeaponMarketData[class].name or info.name
        FC.WeaponMarketData[class].price = tonumber(FC.WeaponMarketData[class].price) or info.price
    end
end

local function saveLockers()
    writeJSON(LOCKERS_FILE, FC.WeaponLockerData)
end

local function saveMarket()
    writeJSON(MARKET_FILE, FC.WeaponMarketData)
end

local function saveBuyers()
    writeJSON(BUYERS_FILE, FC.WeaponBuyerData)
end

local function vecTable(v) return { x = v.x, y = v.y, z = v.z } end
local function angTable(a) return { p = a.p, y = a.y, r = a.r } end
local function toVec(t) return Vector(tonumber(t and (t.x or t[1])) or 0, tonumber(t and (t.y or t[2])) or 0, tonumber(t and (t.z or t[3])) or 0) end
local function toAng(t) return Angle(tonumber(t and (t.p or t[1])) or 0, tonumber(t and (t.y or t[2])) or 0, tonumber(t and (t.r or t[3])) or 0) end

local function newID(prefix)
    return string.format("%s_%d_%d", prefix or "fc", os.time(), math.random(100000, 999999))
end

local function notify(ply, success, message)
    if not IsValid(ply) then return end
    net.Start(NET_RESULT)
        net.WriteBool(success == true)
        net.WriteString(tostring(message or ""))
    net.Send(ply)
end

local function canUse(ply, ent)
    return IsValid(ply) and IsValid(ent)
        and ply:GetPos():DistToSqr(ent:GetPos()) <= (CFG.UseDistance or 180) ^ 2
end

local function inventoryReady()
    return GRM and GRM.Inventory and isfunction(GRM.Inventory.CountItem)
        and isfunction(GRM.Inventory.AddItem) and isfunction(GRM.Inventory.RemoveItem)
end

local function inventoryCount(ply, itemID)
    return inventoryReady() and (tonumber(GRM.Inventory.CountItem(ply, itemID)) or 0) or 0
end

local function inventoryAdd(ply, itemID, amount)
    if not inventoryReady() then return false, "Инвентарь не загружен" end
    if not GRM.Inventory.GetItemDef or not GRM.Inventory.GetItemDef(itemID) then
        return false, "Предмет не зарегистрирован в инвентаре: " .. tostring(itemID)
    end

    -- Даём понятную причину вместо общего «недостаточно места».
    if GRM.Encumbrance and GRM.Encumbrance.CanCarry and GRM.Encumbrance.GetItemWeight then
        local allowed, state = GRM.Encumbrance.CanCarry(ply, GRM.Encumbrance.GetItemWeight(itemID) * amount)
        if not allowed then
            return false, string.format("Перегруз: %.1f / %.1f кг", state.weight, state.hard)
        end
    end

    local notAdded = GRM.Inventory.AddItem(ply, itemID, amount)
    if tonumber(notAdded) and tonumber(notAdded) > 0 then
        return false, "В инвентаре недостаточно свободных ячеек"
    end
    return true
end

local function inventoryRemove(ply, itemID, amount)
    if inventoryCount(ply, itemID) < amount then return false, "Не хватает: " .. itemID end
    local result = GRM.Inventory.RemoveItem(ply, itemID, amount)
    if result == false then return false, "Не удалось списать предмет" end
    return true
end

local function registerItems(attempt)
    if not GRM or not GRM.Inventory or not istable(GRM.Inventory.ItemDefs) then
        attempt = (attempt or 0) + 1
        if attempt <= 60 then timer.Simple(0.5, function() registerItems(attempt) end) end
        return
    end

    local function add(id, data)
        local existing = GRM.Inventory.ItemDefs[id]
        if not existing then
            GRM.Inventory.ItemDefs[id] = data
        else
            -- Старые версии Factory уже могли зарегистрировать GPU/компоненты.
            -- Дополняем их весом, не затирая название, иконку и настройки сервера.
            if existing.weight == nil then existing.weight = data.weight end
            if existing.maxStack == nil then existing.maxStack = data.maxStack end
        end
    end

    add("scrap_metal", { type = "item", name = "Металлолом", desc = "Собран в мусорках. Нужен для производства.", icon = "icon16/wrench.png", maxStack = 100, weight = 0.45 })
    add("components_box", { type = "item", name = "Ящик комплектующих", desc = "Произведён из металлолома.", icon = "icon16/box.png", maxStack = 50, weight = 2.2 })
    add("gpu_basic", { type = "item", name = "Базовая видеокарта", desc = "Стоимость 500 GRM", icon = "icon16/computer.png", maxStack = 20, weight = 3.0 })
    add("gpu_mid", { type = "item", name = "Средняя видеокарта", desc = "Стоимость 1000 GRM", icon = "icon16/computer.png", maxStack = 20, weight = 4.5 })
    add("gpu_premium", { type = "item", name = "Премиум видеокарта", desc = "Стоимость 1600 GRM", icon = "icon16/computer.png", maxStack = 20, weight = 6.5 })
    add("defective_components", { type = "item", name = "Бракованные комплектующие", desc = "Неудачная сборка. Можно сдать на металлолом.", icon = "icon16/error.png", maxStack = 30, weight = 1.5 })
    add("defective_weapon_parts", { type = "item", name = "Бракованные оружейные детали", desc = "Неудачная кустарная сборка. Можно сдать на металлолом.", icon = "icon16/error.png", maxStack = 20, weight = 2.5 })
    add("defective_gpu", { type = "item", name = "Бракованная видеокарта", desc = "Неудачная сборка GPU. Можно переплавить в лом.", icon = "icon16/error.png", maxStack = 10, weight = 4.0 })
end
timer.Simple(0.2, registerItems)

loadWeaponData()

function FC.GetBuyerData(buyer)
    local id = buyer:GetFactoryID()
    if not FC.WeaponBuyerData[id] then
        local stock = {}
        for class, info in pairs((CFG.WeaponMarket and CFG.WeaponMarket.Weapons) or {}) do
            stock[class] = math.max(0, math.floor(tonumber(info.seedStock) or 0))
        end
        FC.WeaponBuyerData[id] = { stock = stock }
    end
    FC.WeaponBuyerData[id].stock = FC.WeaponBuyerData[id].stock or {}
    return FC.WeaponBuyerData[id]
end

function FC.GetLockerData(locker)
    local id = locker:GetFactoryID()
    FC.WeaponLockerData[id] = FC.WeaponLockerData[id] or { weapons = {} }
    FC.WeaponLockerData[id].weapons = FC.WeaponLockerData[id].weapons or {}
    return FC.WeaponLockerData[id]
end

local function modelForKind(kind)
    local m = CFG.Models or {}
    if kind == "gpu_station" then return m.gpuStation end
    if kind == "components_station" then return m.componentsStation end
    if kind == "weapon_station" then return m.weaponStation end
    if kind == "furnace" then return m.furnace end
    if kind == "weapon_buyer" then return m.weaponBuyer end
    if kind == "weapon_locker" then return m.weaponLocker end
    if kind == "storage" then return m.storage end
    if kind == "scrap_bin" then return m.scrapBin end
    if kind == "terminal" then return m.terminal end
    if kind == "gpu_product" then return m.gpu end
    return m.components
end

function FC.InitializeEntity(ent, kind)
    ent:SetModel(modelForKind(kind) or "models/error.mdl")

    if kind == "weapon_buyer" then
        ent:SetSolid(SOLID_BBOX)
        ent:SetMoveType(MOVETYPE_NONE)
        ent:SetCollisionGroup(COLLISION_GROUP_NPC)
        ent:SetUseType(SIMPLE_USE)
        ent:SetAutomaticFrameAdvance(true)
        local sequence = ent:SelectWeightedSequence(ACT_IDLE)
        if sequence and sequence >= 0 then ent:ResetSequence(sequence) end
    else
        ent:PhysicsInit(SOLID_VPHYSICS)
        ent:SetMoveType(MOVETYPE_VPHYSICS)
        ent:SetSolid(SOLID_VPHYSICS)
        ent:SetUseType(SIMPLE_USE)
    end

    if ent:GetFactoryID() == "" then ent:SetFactoryID(newID(kind)) end
    ent:SetIsWorking(false)
    ent:SetCraftStart(0)
    ent:SetCraftDuration(0)

    if kind == "scrap_bin" then
        ent:SetStock(CFG.ScrapBinStart or 25)
        ent:SetNextRefill(CurTime() + (CFG.ScrapRefillEvery or 60))
    elseif kind == "storage" then
        FC.StorageData[ent:GetFactoryID()] = FC.StorageData[ent:GetFactoryID()] or {}
    elseif kind == "weapon_buyer" then
        FC.GetBuyerData(ent)
    elseif kind == "weapon_locker" then
        FC.GetLockerData(ent)
    elseif kind == "gpu_product" or kind == "component_product" then
        ent:SetProductCount(1)
    end

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
end

function FC.GetStorage(storage)
    if not IsValid(storage) then return {} end
    local id = storage:GetFactoryID()
    FC.StorageData[id] = FC.StorageData[id] or {}
    return FC.StorageData[id]
end

local function storageAdd(storage, itemID, amount)
    local items = FC.GetStorage(storage)
    items[itemID] = (tonumber(items[itemID]) or 0) + amount
end

local function removeFromStorage(storage, itemID, amount)
    local items = FC.GetStorage(storage)
    local current = tonumber(items[itemID]) or 0
    if current < amount then return false end
    items[itemID] = current - amount
    if items[itemID] <= 0 then items[itemID] = nil end
    return true
end

local function closestStorage(position, range)
    local best, bestDistance
    local maxDistance = (range or CFG.TerminalStorageRange or 900) ^ 2
    for _, storage in ipairs(ents.FindByClass("grm_fc_storage")) do
        local distance = storage:GetPos():DistToSqr(position)
        if distance <= maxDistance and (not bestDistance or distance < bestDistance) then
            best, bestDistance = storage, distance
        end
    end
    return best
end

local GPU_COLORS = {
    gpu_basic = Color(80, 170, 255),
    gpu_mid = Color(90, 220, 115),
    gpu_premium = Color(240, 175, 55),
}

local function applyProductVisual(ent, itemID)
    if not IsValid(ent) then return end
    if string.StartWith(itemID or "", "gpu_") then
        ent:SetModel((CFG.Models or {}).gpu or "models/props_lab/reciever01b.mdl")
        ent:SetMaterial("models/debug/debugwhite")
        ent:SetColor(GPU_COLORS[itemID] or color_white)
    elseif itemID == "defective_gpu" then
        ent:SetModel((CFG.Models or {}).gpu or "models/props_lab/reciever01b.mdl")
        ent:SetMaterial("models/debug/debugwhite")
        ent:SetColor(Color(210, 70, 65))
    elseif itemID == "defective_components" then
        ent:SetModel((CFG.Models or {}).defectiveComponents or "models/props/cs_office/cardboard_box01.mdl")
        ent:SetMaterial("models/debug/debugwhite")
        ent:SetColor(Color(210, 70, 65))
    elseif itemID == "defective_weapon_parts" then
        ent:SetModel((CFG.Models or {}).components or "models/props_junk/cardboard_box001a.mdl")
        ent:SetMaterial("models/debug/debugwhite")
        ent:SetColor(Color(210, 70, 65))
    else
        ent:SetModel((CFG.Models or {}).components or "models/props_junk/cardboard_box001a.mdl")
        ent:SetMaterial("")
        ent:SetColor(color_white)
    end
end

local function spawnProduct(position, itemID, amount)
    local class = string.StartWith(itemID or "", "gpu_") and "grm_fc_gpu" or "grm_fc_product"
    local ent = ents.Create(class)
    if not IsValid(ent) then return nil end
    ent:SetPos(position + Vector(math.random(-12, 12), math.random(-12, 12), 48))
    ent:Spawn()
    ent:Activate()
    ent:SetProductID(itemID)
    ent:SetProductCount(amount or 1)
    applyProductVisual(ent, itemID)
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetVelocity(Vector(math.random(-20, 20), math.random(-20, 20), 30))
    end
    return ent
end

local function pickupProduct(ply, ent)
    if not canUse(ply, ent) then return end
    local itemID = ent:GetProductID()
    local amount = math.max(1, ent:GetProductCount())
    if itemID == "" then return end
    local ok, reason = inventoryAdd(ply, itemID, amount)
    if not ok then notify(ply, false, reason) return end
    notify(ply, true, "Получено: " .. amount .. "x " .. itemID)
    ply:EmitSound("items/ammo_pickup.wav")
    ent:Remove()
end

-- Совместимость с существующим GRM Inventory: при выбросе бракованных
-- комплектующих из /inv меняем модель стандартного grm_item_drop.
hook.Add("OnEntityCreated", "GRM_FC_DefectiveComponentsDropModel", function(ent)
    timer.Simple(0.15, function()
        if not IsValid(ent) or ent:GetClass() ~= "grm_item_drop" then return end
        if ent.ItemID ~= "defective_components" then return end
        ent:SetModel((CFG.Models or {}).defectiveComponents or "models/props/cs_office/cardboard_box01.mdl")
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
    end)
end)

local function recipeList(recipes, typeName)
    local out = {}
    for id, recipe in pairs(recipes or {}) do
        out[#out + 1] = {
            id = id,
            name = recipe.name or id,
            input = recipe.input or {},
            duration = recipe.duration or 1,
            output = recipe.output or recipe.weapon or "",
            type = typeName,
        }
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

local function craftData(ent, recipes, kind)
    return {
        kind = kind,
        working = ent:GetIsWorking(),
        recipeID = ent:GetRecipeID(),
        start = ent:GetCraftStart(),
        duration = ent:GetCraftDuration(),
        recipes = recipeList(recipes, kind),
    }
end

local function openCraft(ply, ent, recipes, kind)
    if not canUse(ply, ent) then return end
    net.Start(NET_OPEN_CRAFT)
        net.WriteEntity(ent)
        net.WriteTable(craftData(ent, recipes, kind))
    net.Send(ply)
end

local function storageData(storage)
    return { id = storage:GetFactoryID(), items = table.Copy(FC.GetStorage(storage)) }
end

local function openStorage(ply, storage)
    if not canUse(ply, storage) then return end
    net.Start(NET_OPEN_STORAGE)
        net.WriteEntity(storage)
        net.WriteTable(storageData(storage))
    net.Send(ply)
end

local function openScrap(ply, bin)
    if not canUse(ply, bin) then return end
    net.Start(NET_OPEN_SCRAP)
        net.WriteEntity(bin)
        net.WriteTable({ stock = bin:GetStock(), max = CFG.ScrapBinMax or 40, nextRefill = bin:GetNextRefill() })
    net.Send(ply)
end

local function openTerminal(ply, terminal)
    if not canUse(ply, terminal) then return end
    local storages = {}
    local range = (CFG.TerminalStorageRange or 900) ^ 2
    for _, storage in ipairs(ents.FindByClass("grm_fc_storage")) do
        if storage:GetPos():DistToSqr(terminal:GetPos()) <= range then
            storages[#storages + 1] = storageData(storage)
        end
    end
    net.Start(NET_OPEN_TERMINAL)
        net.WriteEntity(terminal)
        net.WriteTable({ storages = storages, prices = CFG.SellPrices or {} })
    net.Send(ply)
end

local function lockerAllowsWeapon(class)
    return not ((CFG.WeaponMarket and CFG.WeaponMarket.LockerBlockedWeapons) or {})[class]
end

local function playerWeapons(ply, buyerOnly)
    local out = {}
    for _, wep in ipairs(ply:GetWeapons()) do
        if IsValid(wep) then
            local class = wep:GetClass()
            local market = FC.WeaponMarketData[class]
            if lockerAllowsWeapon(class) and (not buyerOnly or market) then
                out[#out + 1] = {
                    class = class,
                    name = (market and market.name) or wep:GetPrintName() or class,
                    clip1 = math.max(0, wep:Clip1() or 0),
                    clip2 = math.max(0, wep:Clip2() or 0),
                }
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

local function buyerPayload(buyer, ply)
    local buyerData = FC.GetBuyerData(buyer)
    local stock = {}
    for class, market in pairs(FC.WeaponMarketData or {}) do
        stock[#stock + 1] = {
            class = class,
            name = market.name or class,
            price = math.max(0, tonumber(market.price) or 0),
            stock = math.max(0, tonumber(buyerData.stock[class]) or 0),
        }
    end
    table.sort(stock, function(a, b) return a.name < b.name end)

    local sellWeapons = playerWeapons(ply, true)
    for _, weapon in ipairs(sellWeapons) do
        weapon.price = FC.WeaponMarketData[weapon.class] and FC.WeaponMarketData[weapon.class].price or 0
    end

    return {
        stock = stock,
        sellWeapons = sellWeapons,
        sellPercent = (CFG.WeaponMarket and CFG.WeaponMarket.SellPercent) or 0.45,
    }
end

local function openWeaponBuyer(ply, buyer)
    if not canUse(ply, buyer) then return end
    net.Start(NET_OPEN_WEAPON_BUYER)
        net.WriteEntity(buyer)
        net.WriteTable(buyerPayload(buyer, ply))
    net.Send(ply)
end

local function openWeaponLocker(ply, locker)
    if not canUse(ply, locker) then return end
    local data = FC.GetLockerData(locker)
    net.Start(NET_OPEN_WEAPON_LOCKER)
        net.WriteEntity(locker)
        net.WriteTable({ weapons = data.weapons, playerWeapons = playerWeapons(ply, false) })
    net.Send(ply)
end

local function openWeaponAdmin(ply, buyer)
    if not IsValid(ply) or not ply:IsSuperAdmin() or not canUse(ply, buyer) then return end
    local data = FC.GetBuyerData(buyer)
    net.Start(NET_OPEN_WEAPON_ADMIN)
        net.WriteEntity(buyer)
        net.WriteTable({ market = FC.WeaponMarketData, stock = data.stock })
    net.Send(ply)
end

function FC.UseEntity(ply, ent)
    local kind = ent.FactoryKind
    if kind == "gpu_station" then openCraft(ply, ent, CFG.GPURecipes, kind)
    elseif kind == "components_station" then openCraft(ply, ent, CFG.ComponentRecipes, kind)
    elseif kind == "weapon_station" then openCraft(ply, ent, CFG.WeaponRecipes, kind)
    elseif kind == "furnace" then openCraft(ply, ent, CFG.FurnaceRecipes, kind)
    elseif kind == "weapon_buyer" then openWeaponBuyer(ply, ent)
    elseif kind == "weapon_locker" then openWeaponLocker(ply, ent)
    elseif kind == "storage" then openStorage(ply, ent)
    elseif kind == "scrap_bin" then openScrap(ply, ent)
    elseif kind == "terminal" then openTerminal(ply, ent)
    elseif kind == "gpu_product" or kind == "component_product" then pickupProduct(ply, ent)
    end
end

local function refundInputs(ply, input)
    if not IsValid(ply) then return end
    for itemID, amount in pairs(input or {}) do inventoryAdd(ply, itemID, amount) end
end

function FC.OnEntityRemoved(ent)
    if not ent then return end
    if ent.FC_QTE then
        local session = ent.FC_QTE
        timer.Remove(qteTimerName and qteTimerName(ent) or ("GRM_FC_QTE_" .. ent:EntIndex()))
        if IsValid(session.owner) then
            refundInputs(session.owner, session.input)
            notify(session.owner, false, "Станок удалён: материалы мини-игры возвращены.")
        end
        ent.FC_QTE = nil
    end
    if ent:GetIsWorking() then
        timer.Remove("GRM_FC_Craft_" .. ent:EntIndex())
        if IsValid(ent.FC_CraftOwner) then
            refundInputs(ent.FC_CraftOwner, ent.FC_CraftInput)
            notify(ent.FC_CraftOwner, false, "Станок удалён: материалы возвращены.")
        end
    end
end

local function stopCraft(ent)
    if not IsValid(ent) then return end
    timer.Remove("GRM_FC_Craft_" .. ent:EntIndex())
    ent:SetIsWorking(false)
    ent:SetCraftStart(0)
    ent:SetCraftDuration(0)
    ent:SetRecipeID("")
    ent.FC_CraftOwner = nil
    ent.FC_CraftInput = nil
end

local function beginCraft(ply, ent, recipe, recipeID, kind, removedInputs)
    local duration = math.max(1, tonumber(recipe.duration) or 1)
    ent:SetIsWorking(true)
    ent:SetRecipeID(recipeID)
    ent:SetCraftStart(CurTime())
    ent:SetCraftDuration(duration)
    ent.FC_CraftOwner = ply
    ent.FC_CraftInput = removedInputs

    timer.Create("GRM_FC_Craft_" .. ent:EntIndex(), duration, 1, function()
        if not IsValid(ent) then return end
        local owner = ent.FC_CraftOwner

        if kind == "gpu_station" then
            spawnProduct(ent:GetPos(), recipe.output, 1)
            if IsValid(owner) then notify(owner, true, "Видеокарта готова. Заберите её со станка.") end
        elseif kind == "components_station" then
            spawnProduct(ent:GetPos(), recipe.output, recipe.outputCount or 1)
            if IsValid(owner) then notify(owner, true, "Комплектующие готовы. Заберите ящик со станка.") end
        elseif kind == "weapon_station" then
            if IsValid(owner) and weapons.Get(recipe.weapon) then
                owner:Give(recipe.weapon)
                notify(owner, true, "Оружие собрано: " .. (recipe.name or recipe.weapon))
            end
        elseif kind == "furnace" then
            if IsValid(owner) then
                local ok, reason = inventoryAdd(owner, recipe.output, recipe.outputCount or 1)
                if ok then
                    notify(owner, true, "Переплавка завершена: получено " .. (recipe.outputCount or 1) .. "x " .. recipe.output)
                else
                    -- Если инвентарь заполнен, лом остаётся физическим предметом у печи.
                    spawnProduct(ent:GetPos(), recipe.output, recipe.outputCount or 1)
                    notify(owner, true, "Переплавка завершена: лом лежит у печи (" .. tostring(reason) .. ")")
                end
            end
        end

        if IsValid(owner) then owner:EmitSound("buttons/button14.wav") end
        stopCraft(ent)
    end)

    notify(ply, true, "Производство запущено: " .. (recipe.name or recipeID))
    ply:EmitSound("buttons/button15.wav")
end

local function consumeRecipeInputs(ply, recipe)
    for itemID, amount in pairs(recipe.input or {}) do
        if inventoryCount(ply, itemID) < amount then
            return false, "Не хватает материала: " .. itemID
        end
    end
    local removed = {}
    for itemID, amount in pairs(recipe.input or {}) do
        local ok, reason = inventoryRemove(ply, itemID, amount)
        if not ok then
            refundInputs(ply, removed)
            return false, reason
        end
        removed[itemID] = amount
    end
    return true, removed
end

-- GPU собираются обычным производством. Компоненты и оружие проходят QTE.
local function startCraft(ply, ent, recipes, recipeID, kind)
    if not canUse(ply, ent) then return end
    if ent:GetIsWorking() or ent.FC_QTE then notify(ply, false, "Этот станок уже занят.") return end
    local recipe = recipes and recipes[recipeID]
    if not recipe then notify(ply, false, "Рецепт не найден.") return end
    if kind == "weapon_station" and not weapons.Get(recipe.weapon) then
        notify(ply, false, "Оружие " .. tostring(recipe.weapon) .. " не установлено на сервере.")
        return
    end
    local ok, removedOrReason = consumeRecipeInputs(ply, recipe)
    if not ok then notify(ply, false, removedOrReason) return end
    beginCraft(ply, ent, recipe, recipeID, kind, removedOrReason)
end

-- ============================================================
-- QTE: сервер задаёт последовательность и сам проверяет каждую клавишу.
-- ============================================================
local QTE_ARROWS = { "UP", "RIGHT", "DOWN", "LEFT" }

local function qteTimerName(ent)
    return "GRM_FC_QTE_" .. ent:EntIndex()
end

local function sendQTEState(session, lastCorrect)
    if not IsValid(session.owner) then return end
    net.Start(NET_QTE_STATE)
        net.WriteEntity(session.ent)
        net.WriteUInt(session.index, 8)
        net.WriteUInt(session.correct, 8)
        net.WriteUInt(session.mistakes, 8)
        net.WriteFloat(session.deadline or CurTime())
        net.WriteBool(lastCorrect == true)
    net.Send(session.owner)
end

local finishQTE

local function scheduleQTEStep(session, lastCorrect)
    if not IsValid(session.ent) or session.ent.FC_QTE ~= session then return end
    if not IsValid(session.owner) or not canUse(session.owner, session.ent) then
        finishQTE(session, false, "Игрок отошёл от станка")
        return
    end
    if session.index > #session.sequence then
        local required = math.ceil(#session.sequence * session.successPercent)
        finishQTE(session, session.correct >= required)
        return
    end
    session.deadline = CurTime() + session.stepTime
    sendQTEState(session, lastCorrect)
    timer.Create(qteTimerName(session.ent), session.stepTime, 1, function()
        if not IsValid(session.ent) or session.ent.FC_QTE ~= session then return end
        session.mistakes = session.mistakes + 1
        session.index = session.index + 1
        scheduleQTEStep(session, false)
    end)
end

finishQTE = function(session, success, reason)
    local ent = session.ent
    if not IsValid(ent) or ent.FC_QTE ~= session then return end
    timer.Remove(qteTimerName(ent))
    ent.FC_QTE = nil

    if success then
        beginCraft(session.owner, ent, session.recipe, session.recipeID, session.kind, session.input)
    else
        -- Провал: игрок получает физический брак и часть исходных материалов.
        local refundPercent = (CFG.QTE and CFG.QTE.PartialRefundPercent) or 0.25
        if IsValid(session.owner) then
            for itemID, amount in pairs(session.input or {}) do
                local refund = math.max(1, math.floor(amount * refundPercent))
                inventoryAdd(session.owner, itemID, refund)
            end
            notify(session.owner, false, "Брак при сборке" .. (reason and ": " .. reason or ".") .. " Часть материалов возвращена.")
            session.owner:EmitSound("buttons/button10.wav")
        end

        local defect
        if session.kind == "components_station" then
            defect = "defective_components"
        elseif session.kind == "gpu_station" then
            defect = "defective_gpu"
        else
            defect = "defective_weapon_parts"
        end
        spawnProduct(ent:GetPos(), defect, 1)
    end

    if IsValid(session.owner) then
        net.Start(NET_QTE_FINISH)
            net.WriteEntity(ent)
            net.WriteBool(success)
            net.WriteUInt(session.correct, 8)
            net.WriteUInt(#session.sequence, 8)
        net.Send(session.owner)
    end
end

local function startQTE(ply, ent, recipes, recipeID, kind)
    if not canUse(ply, ent) then return end
    if ent:GetIsWorking() or ent.FC_QTE then notify(ply, false, "Этот станок уже занят.") return end
    local recipe = recipes and recipes[recipeID]
    if not recipe then notify(ply, false, "Рецепт не найден.") return end
    if kind == "weapon_station" and not weapons.Get(recipe.weapon) then
        notify(ply, false, "Оружие " .. tostring(recipe.weapon) .. " не установлено на сервере.")
        return
    end

    local ok, inputOrReason = consumeRecipeInputs(ply, recipe)
    if not ok then notify(ply, false, inputOrReason) return end

    local settings = {}
    if CFG.QTE then
        if kind == "weapon_station" then settings = CFG.QTE.weapons or {}
        elseif kind == "gpu_station" then settings = CFG.QTE.gpu or {}
        else settings = CFG.QTE.components or {}
        end
    end

    local session = {
        owner = ply,
        ent = ent,
        kind = kind,
        recipe = recipe,
        recipeID = recipeID,
        input = inputOrReason,
        sequence = {},
        index = 1,
        correct = 0,
        mistakes = 0,
        stepTime = math.max(0.3, tonumber(settings.stepTime) or 1),
        successPercent = math.Clamp(tonumber(settings.successPercent) or 0.7, 0.1, 1),
    }

    local steps = math.Clamp(math.floor(tonumber(settings.steps) or 5), 3, 30)
    for i = 1, steps do session.sequence[i] = QTE_ARROWS[math.random(1, #QTE_ARROWS)] end

    ent.FC_QTE = session

    net.Start(NET_QTE_START)
        net.WriteEntity(ent)
        net.WriteString(kind)
        net.WriteTable(session.sequence)
        net.WriteFloat(session.stepTime)
        net.WriteFloat(session.successPercent)
    net.Send(ply)

    scheduleQTEStep(session)
end

net.Receive(NET_QTE_INPUT, function(_, ply)
    local ent = net.ReadEntity()
    local arrow = net.ReadString()
    local session = IsValid(ent) and ent.FC_QTE or nil
    if not session or session.owner ~= ply or CurTime() > (session.deadline or 0) then return end
    timer.Remove(qteTimerName(ent))
    local correct = session.sequence[session.index] == arrow
    if correct then session.correct = session.correct + 1 else session.mistakes = session.mistakes + 1 end
    session.index = session.index + 1
    scheduleQTEStep(session, correct)
end)

net.Receive(NET_QTE_ABORT, function(_, ply)
    local ent = net.ReadEntity()
    local session = IsValid(ent) and ent.FC_QTE or nil
    if session and session.owner == ply then finishQTE(session, false, "Мини-игра прервана") end
end)

local function scrapTake(ply, bin, amount)
    if not canUse(ply, bin) then return end
    amount = math.Clamp(math.floor(tonumber(amount) or 1), 1, 10)
    if bin:GetStock() < amount then notify(ply, false, "В мусорке недостаточно металлолома.") return end
    local ok, reason = inventoryAdd(ply, "scrap_metal", amount)
    if not ok then notify(ply, false, reason) return end
    bin:SetStock(bin:GetStock() - amount)
    scheduleFactorySave("scrap take")
    notify(ply, true, "Собрано металлолома: " .. amount)
end

local function storageTake(ply, storage, itemID, amount)
    if not canUse(ply, storage) then return end
    local available = tonumber(FC.GetStorage(storage)[itemID]) or 0
    amount = math.Clamp(math.floor(tonumber(amount) or 1), 1, available)
    if amount <= 0 then notify(ply, false, "На складе нет этого предмета.") return end
    local ok, reason = inventoryAdd(ply, itemID, amount)
    if not ok then notify(ply, false, reason) return end
    removeFromStorage(storage, itemID, amount)
    notify(ply, true, "Взято со склада: " .. amount .. "x " .. itemID)
end

local function storageDeposit(ply, storage, itemID, amount)
    if not canUse(ply, storage) then return end
    amount = math.Clamp(math.floor(tonumber(amount) or 1), 1, 4095)
    if inventoryCount(ply, itemID) < amount then notify(ply, false, "В инвентаре недостаточно предметов.") return end
    local ok, reason = inventoryRemove(ply, itemID, amount)
    if not ok then notify(ply, false, reason) return end
    storageAdd(storage, itemID, amount)
    notify(ply, true, "Помещено на склад: " .. amount .. "x " .. itemID)
end

local function sellStorage(ply, terminal, storageID)
    if not canUse(ply, terminal) then return end
    local storage
    for _, candidate in ipairs(ents.FindByClass("grm_fc_storage")) do
        if candidate:GetFactoryID() == storageID then storage = candidate break end
    end
    if not IsValid(storage) or storage:GetPos():DistToSqr(terminal:GetPos()) > (CFG.TerminalStorageRange or 900) ^ 2 then
        notify(ply, false, "Склад не найден рядом с терминалом.")
        return
    end
    if not GRM or not isfunction(GRM.GiveMoney) then notify(ply, false, "Экономика GRM не загружена.") return end

    local items = FC.GetStorage(storage)
    local total, text = 0, {}
    for itemID, price in pairs(CFG.SellPrices or {}) do
        local amount = tonumber(items[itemID]) or 0
        if amount > 0 then
            total = total + amount * price
            text[#text + 1] = amount .. "x " .. itemID
            items[itemID] = nil
        end
    end
    if total <= 0 then notify(ply, false, "На складе нет GPU для продажи.") return end

    GRM.GiveMoney(ply, total)
    notify(ply, true, "Продано: " .. table.concat(text, ", ") .. " за " .. (GRM.Format and GRM.Format(total) or (total .. " GRM")))
end

local function canReceiveWeapon(ply, class)
    if ply:HasWeapon(class) then return false, "У вас уже есть это оружие" end
    if GRM.Encumbrance and GRM.Encumbrance.CanCarry and GRM.Encumbrance.GetWeaponWeight then
        local ok, state = GRM.Encumbrance.CanCarry(ply, GRM.Encumbrance.GetWeaponWeight(class))
        if not ok then return false, string.format("Перегруз: %.1f / %.1f кг", state.weight, state.hard) end
    end
    return true
end

local function buyerBuy(ply, buyer, class)
    if not canUse(ply, buyer) then return end
    local market = FC.WeaponMarketData[class]
    local data = FC.GetBuyerData(buyer)
    local stock = tonumber(data.stock[class]) or 0
    if not market or stock <= 0 then notify(ply, false, "У скупщика нет этого оружия.") return end
    if not GRM or not isfunction(GRM.HasMoney) or not isfunction(GRM.TakeMoney) then notify(ply, false, "Экономика GRM не загружена.") return end
    if not GRM.HasMoney(ply, market.price) then notify(ply, false, "Недостаточно средств: нужно " .. market.price .. " GRM") return end

    local ok, reason = canReceiveWeapon(ply, class)
    if not ok then notify(ply, false, reason) return end

    GRM.TakeMoney(ply, market.price)
    ply:Give(class)
    data.stock[class] = stock - 1
    saveBuyers()
    notify(ply, true, "Куплено оружие: " .. (market.name or class))
end

local function buyerSell(ply, buyer, class)
    if not canUse(ply, buyer) then return end
    local market = FC.WeaponMarketData[class]
    if not market then notify(ply, false, "Скупщик не принимает это оружие.") return end
    local weapon = ply:GetWeapon(class)
    if not IsValid(weapon) then notify(ply, false, "У вас нет этого оружия в руках.") return end
    if not GRM or not isfunction(GRM.GiveMoney) then notify(ply, false, "Экономика GRM не загружена.") return end

    ply:StripWeapon(class)
    local data = FC.GetBuyerData(buyer)
    data.stock[class] = (tonumber(data.stock[class]) or 0) + 1
    saveBuyers()

    local price = math.floor((tonumber(market.price) or 0) * ((CFG.WeaponMarket and CFG.WeaponMarket.SellPercent) or 0.45))
    GRM.GiveMoney(ply, price)
    notify(ply, true, "Продано: " .. (market.name or class) .. " за " .. price .. " GRM")
end

local function lockerStore(ply, locker, class)
    if not canUse(ply, locker) then return end
    if not lockerAllowsWeapon(class) then notify(ply, false, "Это служебное оружие нельзя положить в шкаф.") return end
    local weapon = ply:GetWeapon(class)
    if not IsValid(weapon) then notify(ply, false, "У вас нет этого оружия.") return end

    local data = FC.GetLockerData(locker)
    data.weapons[#data.weapons + 1] = {
        class = class,
        clip1 = math.max(0, weapon:Clip1() or 0),
        clip2 = math.max(0, weapon:Clip2() or 0),
        storedBy = ply:Nick(),
        storedAt = os.time(),
    }
    ply:StripWeapon(class)
    saveLockers()
    notify(ply, true, "Оружие помещено в общий шкаф.")
end

local function lockerTake(ply, locker, index)
    if not canUse(ply, locker) then return end
    local data = FC.GetLockerData(locker)
    local entry = data.weapons[index]
    if not entry then notify(ply, false, "Оружие в шкафу не найдено.") return end

    local ok, reason = canReceiveWeapon(ply, entry.class)
    if not ok then notify(ply, false, reason) return end

    local weapon = ply:Give(entry.class)
    if not IsValid(weapon) then notify(ply, false, "Не удалось выдать оружие.") return end
    if entry.clip1 and entry.clip1 > 0 then weapon:SetClip1(entry.clip1) end
    if entry.clip2 and entry.clip2 > 0 then weapon:SetClip2(entry.clip2) end

    table.remove(data.weapons, index)
    saveLockers()
    notify(ply, true, "Оружие взято из шкафа.")
end

local function adminSetWeaponMarket(ply, buyer, class, price, stock)
    if not IsValid(ply) or not ply:IsSuperAdmin() or not canUse(ply, buyer) then return end
    local market = FC.WeaponMarketData[class]
    if not market then notify(ply, false, "Оружие не зарегистрировано в конфиге.") return end
    market.price = math.max(0, math.floor(tonumber(price) or 0))

    local data = FC.GetBuyerData(buyer)
    data.stock[class] = math.max(0, math.floor(tonumber(stock) or 0))
    saveMarket()
    saveBuyers()
    FC.SaveMap(nil) -- сохраняет запас выбранного скупщика
    notify(ply, true, "Рынок оружия обновлён: " .. (market.name or class))
end

net.Receive(NET_ACTION, function(_, ply)
    local action = net.ReadString()
    local ent = net.ReadEntity()

    if action == "gpu_start" and IsValid(ent) and ent.FactoryKind == "gpu_station" then
        startQTE(ply, ent, CFG.GPURecipes, net.ReadString(), "gpu_station")
    elseif action == "components_start" and IsValid(ent) and ent.FactoryKind == "components_station" then
        startQTE(ply, ent, CFG.ComponentRecipes, net.ReadString(), "components_station")
    elseif action == "weapon_start" and IsValid(ent) and ent.FactoryKind == "weapon_station" then
        startQTE(ply, ent, CFG.WeaponRecipes, net.ReadString(), "weapon_station")
    elseif action == "furnace_start" and IsValid(ent) and ent.FactoryKind == "furnace" then
        startCraft(ply, ent, CFG.FurnaceRecipes, net.ReadString(), "furnace")
    elseif action == "weapon_buyer_buy" and IsValid(ent) and ent.FactoryKind == "weapon_buyer" then
        buyerBuy(ply, ent, net.ReadString())
    elseif action == "weapon_buyer_sell" and IsValid(ent) and ent.FactoryKind == "weapon_buyer" then
        buyerSell(ply, ent, net.ReadString())
    elseif action == "weapon_locker_store" and IsValid(ent) and ent.FactoryKind == "weapon_locker" then
        lockerStore(ply, ent, net.ReadString())
    elseif action == "weapon_locker_take" and IsValid(ent) and ent.FactoryKind == "weapon_locker" then
        lockerTake(ply, ent, net.ReadUInt(12))
    elseif action == "weapon_admin_set" and IsValid(ent) and ent.FactoryKind == "weapon_buyer" then
        adminSetWeaponMarket(ply, ent, net.ReadString(), net.ReadUInt(32), net.ReadUInt(12))
    elseif action == "scrap_take" and IsValid(ent) and ent.FactoryKind == "scrap_bin" then
        scrapTake(ply, ent, net.ReadUInt(4))
    elseif action == "storage_take" and IsValid(ent) and ent.FactoryKind == "storage" then
        storageTake(ply, ent, net.ReadString(), net.ReadUInt(12))
    elseif action == "storage_deposit" and IsValid(ent) and ent.FactoryKind == "storage" then
        storageDeposit(ply, ent, net.ReadString(), net.ReadUInt(12))
    elseif action == "terminal_sell" and IsValid(ent) and ent.FactoryKind == "terminal" then
        sellStorage(ply, ent, net.ReadString())
    elseif action == "refresh" and IsValid(ent) then
        FC.UseEntity(ply, ent)
    end
end)

-- Единая автоперсистентность оборудования завода. Factory entities не входят
-- в универсальный /permadd: здесь сохраняется ещё и stock/nextRefill.
local function scheduleFactorySave(reason)
    if FC.LoadingMap then return end
    timer.Create("GRM_FC_SaveSoon", 1, 1, function()
        if not FC.LoadingMap and FC.SaveMap then FC.SaveMap(nil, reason or "mutation") end
    end)
end

-- Scrap bins replenish their finite stock over time.
timer.Create("GRM_FC_ScrapRefill", 2, 0, function()
    local now = CurTime()
    for _, bin in ipairs(ents.FindByClass("grm_fc_scrap_bin")) do
        if bin:GetNextRefill() <= now then
            bin:SetStock(math.min(CFG.ScrapBinMax or 50, bin:GetStock() + (CFG.ScrapRefillAmount or 5)))
            bin:SetNextRefill(now + (CFG.ScrapRefillEvery or 60))
            scheduleFactorySave("scrap refill")
        end
    end
end)

-- Manual persistence for full factory state.
local function entityRecord(ent)
    local record = { class = ent:GetClass(), kind = ent.FactoryKind, id = ent:GetFactoryID(), pos = vecTable(ent:GetPos()), ang = angTable(ent:GetAngles()), model = ent:GetModel() }
    if ent.FactoryKind == "storage" then record.items = table.Copy(FC.GetStorage(ent)) end
    if ent.FactoryKind == "scrap_bin" then record.stock = ent:GetStock(); record.nextRefill = ent:GetNextRefill() end
    if ent.FactoryKind == "weapon_buyer" then record.weaponStock = table.Copy(FC.GetBuyerData(ent).stock) end
    return record
end

function FC.SaveMap(ply, reason)
    if IsValid(ply) and not ply:IsSuperAdmin() then notify(ply, false, "Только superadmin может сохранять завод.") return 0 end
    ensureDirectories()
    local records = {}
    for class in pairs(EQUIPMENT_CLASSES) do
        for _, ent in ipairs(ents.FindByClass(class)) do records[#records + 1] = entityRecord(ent) end
    end
    file.Write(mapFile(), util.TableToJSON(records, true))
    if IsValid(ply) then notify(ply, true, "Сохранено заводского оборудования: " .. #records) end
    print("[GRM Factory Full Cycle] Saved: " .. #records)
    return #records
end

function FC.LoadMap(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then notify(ply, false, "Только superadmin может загружать завод.") return 0 end
    if not file.Exists(mapFile(), "DATA") then return 0 end
    local ok, records = pcall(util.JSONToTable, file.Read(mapFile(), "DATA") or "")
    if not ok or not istable(records) then return 0 end

    FC.LoadingMap = true
    FC.StorageData = {}
    for class in pairs(EQUIPMENT_CLASSES) do
        for _, ent in ipairs(ents.FindByClass(class)) do ent:Remove() end
    end

    local count = 0
    for _, record in ipairs(records) do
        if EQUIPMENT_CLASSES[record.class] then
            local ent = ents.Create(record.class)
            if IsValid(ent) then
                ent:SetPos(toVec(record.pos)); ent:SetAngles(toAng(record.ang)); ent:Spawn(); ent:Activate()
                ent:SetFactoryID(record.id or newID(record.kind))

                if record.kind == "storage" then FC.StorageData[ent:GetFactoryID()] = istable(record.items) and record.items or {} end
                if record.kind == "scrap_bin" then
                    ent:SetStock(math.Clamp(tonumber(record.stock) or CFG.ScrapBinStart, 0, CFG.ScrapBinMax or 40))
                    ent:SetNextRefill(tonumber(record.nextRefill) or (CurTime() + (CFG.ScrapRefillEvery or 60)))
                elseif record.kind == "weapon_buyer" then
                    -- Отдельный файл buyer data свежее ручного сохранения карты.
                    if not FC.WeaponBuyerData[ent:GetFactoryID()] then
                        FC.WeaponBuyerData[ent:GetFactoryID()] = { stock = istable(record.weaponStock) and record.weaponStock or {} }
                    end
                elseif record.kind == "weapon_locker" then
                    FC.GetLockerData(ent)
                end

                local phys = ent:GetPhysicsObject(); if IsValid(phys) then phys:EnableMotion(false); phys:Sleep() end
                count = count + 1
            end
        end
    end
    timer.Simple(1, function() FC.LoadingMap = false end)

    if IsValid(ply) then notify(ply, true, "Загружено оборудования: " .. count) end
    print("[GRM Factory Full Cycle] Loaded: " .. count)
    return count
end

hook.Add("OnEntityCreated", "GRM_FC_AutoSaveCreated", function(ent)
    timer.Simple(0, function()
        if IsValid(ent) and EQUIPMENT_CLASSES[ent:GetClass()] then scheduleFactorySave("entity created") end
    end)
end)
hook.Add("EntityRemoved", "GRM_FC_AutoSaveRemoved", function(ent)
    if ent and EQUIPMENT_CLASSES[ent:GetClass()] then scheduleFactorySave("entity removed") end
end)
hook.Add("PostCleanupMap", "GRM_FC_RestoreAfterCleanup", function()
    timer.Simple(1, function() if FC.LoadMap then FC.LoadMap(nil) end end)
end)

concommand.Add("grm_fc_save", function(ply) FC.SaveMap(ply, "manual") end)
concommand.Add("grm_fc_load", function(ply) FC.LoadMap(ply) end)

hook.Add("InitPostEntity", "GRM_FC_LoadMap", function() timer.Simple(5, function() FC.LoadMap(nil) end) end)
hook.Add("ShutDown", "GRM_FC_SaveShutdown", function() FC.SaveMap(nil, "shutdown") end)

-- Локеры сохраняются независимо от ручного сохранения карты, поэтому
-- положенное оружие не теряется при выходе игрока или рестарте сервера.
timer.Create("GRM_FC_LockerAutoSave", 30, 0, saveLockers)
hook.Add("ShutDown", "GRM_FC_SaveWeaponData", function()
    saveLockers()
    saveMarket()
    saveBuyers()
end)

local function aimedWeaponBuyer(ply)
    if not IsValid(ply) then return nil end
    local trace = util.TraceLine({ start = ply:EyePos(), endpos = ply:EyePos() + ply:GetAimVector() * (CFG.UseDistance or 180), filter = ply, mask = MASK_ALL })
    return IsValid(trace.Entity) and trace.Entity.FactoryKind == "weapon_buyer" and trace.Entity or nil
end

concommand.Add("grm_weapon_buyer_admin", function(ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    local buyer = aimedWeaponBuyer(ply)
    if not IsValid(buyer) then
        notify(ply, false, "Посмотрите на скупщика оружия рядом с вами.")
        return
    end
    openWeaponAdmin(ply, buyer)
end)

print("[GRM Factory Full Cycle] Server loaded")
