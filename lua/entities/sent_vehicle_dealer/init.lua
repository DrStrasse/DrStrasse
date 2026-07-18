--[[--------------------------------------------------------------------
    sent_vehicle_dealer — init.lua (SERVER)
    NPC-подобный дилер транспорта.
    
    Спавн:  qmenu → Entities → GRM Vehicles → Дилер транспорта
    Использование: [E] на дилера → открытие меню выбора транспорта
    
    Конфигурация дилера сохраняется в data/grm/dealers/<dealerID>.json
    Формат: { name = "...", vehicles = { __global = {...}, [faction] = {...} } }
    
    Хуки (для внешних систем):
      VD_PreSpawnCheck(ply, vehicleClass, dealerData)  — вернуть false чтобы запретить
      VD_FilterVehicleList(ply, vehicleList)            — вернуть отфильтрованный список
      VD_OnVehicleSpawned(ent, ply, vehicleClass)       — уведомление о спавне
--------------------------------------------------------------------]]

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

-- ════════════════════════════════════════════════════════
-- Глобальные таблицы
-- ════════════════════════════════════════════════════════
VD_AllVehicles  = VD_AllVehicles or {}
VehicleDealers  = VehicleDealers or {}

-- ════════════════════════════════════════════════════════
-- Константы
-- ════════════════════════════════════════════════════════
local VD_SPAWN_OFFSET    = Vector(0, 0, 50)    -- смещение от дилера до точки спавна
local VD_SPAWN_FORWARD   = 200                   -- расстояние спавна вперёд от дилера
local VD_MAX_VEHICLES    = 3                     -- макс. машин на игрока
local VD_DEALER_DIR      = "grm/dealers/"
local VD_AdminBypassClass = nil                  -- админ-спавн из ТАБ (аудит): обход лимита/доступа/цены на один класс

-- Модель дилера по умолчанию
local DEALER_DEFAULT_MODEL = "models/Humans/Group01/Male_02.mdl"

-- ════════════════════════════════════════════════════════
-- Сеть
-- ════════════════════════════════════════════════════════
local VD_REFUND_RATE      = 0.5                  -- возврат при удалении своего Т/С (50% цены)

-- Цена класса в списках дилера: ищем по __global/__nofaction/[фракция игрока]
-- Фракционный транспорт — служебный, бесплатный (price = 0).
local function priceOf(dealer, faction, vehicleClass)
    local vehicles = dealer.VD_Vehicles or {}
    if faction and vehicles[faction] then
        for _, v in ipairs(vehicles[faction]) do
            if v.class == vehicleClass then return 0, faction end
        end
    end
    for _, v in ipairs(vehicles["__global"] or {}) do
        if v.class == vehicleClass then return math.max(0, math.floor(tonumber(v.price) or 0)), "global" end
    end
    for _, v in ipairs(vehicles["__nofaction"] or {}) do
        if v.class == vehicleClass then return math.max(0, math.floor(tonumber(v.price) or 0)), "nofaction" end
    end
    return 0, nil
end

local pushMyVehicles -- fwd: список «Мои Т/С» в меню дилера (Код 82)

util.AddNetworkString("VD_OpenMenu")
util.AddNetworkString("VD_SpawnRequest")
util.AddNetworkString("VD_SpawnResult")
util.AddNetworkString("VD_ConfigOpen")
util.AddNetworkString("VD_ConfigData")
util.AddNetworkString("VD_ConfigSave")
util.AddNetworkString("VD_SetSpawnPoint")
util.AddNetworkString("VD_MyList")
util.AddNetworkString("VD_RemoveRequest")

-- ════════════════════════════════════════════════════════
-- Отладка
-- ════════════════════════════════════════════════════════
CreateConVar("vd_debug", "0", FCVAR_ARCHIVE, "Vehicle Dealer debug output")

function vdDbgPrint(...)
    if GetConVar("vd_debug"):GetBool() then
        print("[VD] ", ...)
    end
end

-- ════════════════════════════════════════════════════════
-- Сохранение / загрузка конфигурации дилера
-- ════════════════════════════════════════════════════════
local function safeJSON(path, default)
    if file.Exists(path, "DATA") then
        local data = file.Read(path, "DATA")
        local ok, decoded = pcall(util.JSONToTable, data)
        if ok and decoded then return decoded end
    end
    return default
end

local function SaveDealerConfig(dealerID, data)
    if not dealerID or dealerID == "" then return end
    file.CreateDir(VD_DEALER_DIR)
    file.Write(VD_DEALER_DIR .. dealerID .. ".json", util.TableToJSON(data, true))
    vdDbgPrint("Конфиг дилера сохранён:", dealerID)
end

local function LoadDealerConfig(dealerID)
    return safeJSON(VD_DEALER_DIR .. dealerID .. ".json", nil)
end

local function SafeGetDealerName(dealer)
    if dealer.GetDealerName and dealer:GetDealerName() ~= "" then
        return dealer:GetDealerName()
    end
    return dealer.VD_Name or ""
end

local function SafeGetDealerModel(dealer)
    if dealer.GetDealerModel and dealer:GetDealerModel() ~= "" then
        return dealer:GetDealerModel()
    end
    return dealer.VD_Model or ""
end

local function SaveAllDealers()
    for id, dealer in pairs(VehicleDealers) do
        if IsValid(dealer) then
            local spawnPos = Vector(0, 0, 0)
            local spawnAngle = Angle(0, 0, 0)
            local hasCustom = false
            pcall(function()
                hasCustom = dealer:GetHasCustomSpawn()
                if hasCustom then
                    spawnPos = dealer:GetSpawnPos()
                    spawnAngle = dealer:GetSpawnAngle()
                end
            end)

            SaveDealerConfig(id, {
                name           = SafeGetDealerName(dealer),
                model          = SafeGetDealerModel(dealer),
                vehicles       = dealer.VD_Vehicles,
                pos            = dealer:GetPos(),
                angles         = dealer:GetAngles(),
                hasCustomSpawn = hasCustom,
                spawnPos       = spawnPos,
                spawnAngle     = spawnAngle,
            })
        end
    end
end

-- Глобальная обёртка для доступа из tool stool и других скриптов
function SaveVehicleDealers()
    SaveAllDealers()
end

-- ════════════════════════════════════════════════════════
-- Генерация уникального ID дилера
-- ════════════════════════════════════════════════════════
local function GenerateDealerID()
    local id
    repeat
        id = "dealer_" .. math.random(1000, 9999)
    until not VehicleDealers[id]
    return id
end

-- ════════════════════════════════════════════════════════
-- Получение списка транспорта для игрока (ИСПРАВЛЕНО)
-- ════════════════════════════════════════════════════════
local function GetVehicleListForPlayer(ply, dealer)
    if not IsValid(dealer) then return {} end

    local vehicles = dealer.VD_Vehicles or {}
    local vlist = {}
    local seen = {}

    -- ═══ Определяем фракцию игрока ═══
    local faction = nil
    if Factions then
        local steam = ply:SteamID()
        for fname, f in pairs(Factions) do
            if f.Members and f.Members[steam] then
                faction = fname
                break
            end
        end
    end

    -- ═══ Глобальный список (для ВСЕХ) ═══
    local globalList = vehicles["__global"] or {}
    for _, v in ipairs(globalList) do
        if not seen[v.class] then
            seen[v.class] = true
            table.insert(vlist, { class = v.class, name = v.name, price = v.price, source = "global" })
        end
    end

    -- ═══ Безфракционный список ═══
    if not faction then
        local nofactionList = vehicles["__nofaction"] or {}
        for _, v in ipairs(nofactionList) do
            if not seen[v.class] then
                seen[v.class] = true
                table.insert(vlist, { class = v.class, name = v.name, price = v.price, source = "nofaction" })
            end
        end
    end

    -- ═══ Фракционный список дилера ═══
    if faction and vehicles[faction] then
        for _, v in ipairs(vehicles[faction]) do
            if not seen[v.class] then
                seen[v.class] = true
                table.insert(vlist, { class = v.class, name = v.name, price = v.price, source = faction })
            end
        end
    end

    -- ═══ Фильтруем по доступу, НО НЕ фракционные машины ═══
    if GRM_HasVehicleAccess then
        local filtered = {}
        for _, v in ipairs(vlist) do
            -- Если машина из фракции игрока – пропускаем без проверки
            if v.source == faction then
                table.insert(filtered, v)
            elseif GRM_HasVehicleAccess(ply, v.class) then
                table.insert(filtered, v)
            end
        end
        -- Если после фильтрации ничего не осталось, но в дилере есть конфиг –
        -- показываем полный список (обратная совместимость)
        if #filtered > 0 then
            vlist = filtered
        end
    end

    -- Если у дилера нет конфига – показываем только доступный транспорт
    if #vlist == 0 and #globalList == 0 and (not faction or not vehicles[faction]) then
        if GRM_GetAccessibleVehicles then
            local accessible = GRM_GetAccessibleVehicles(ply)
            for _, item in ipairs(accessible) do
                if not seen[item.class] then
                    seen[item.class] = true
                    local name = item.class
                    local price = 0
                    if GRM_GetAllVehicleClasses then
                        for _, veh in ipairs(GRM_GetAllVehicleClasses()) do
                            if veh.class == item.class then
                                name = veh.name or item.class
                                break
                            end
                        end
                    end
                    table.insert(vlist, {
                        class = item.class,
                        name  = name,
                        price = price,
                        source = item.source,
                    })
                end
            end
        end
    end

    -- Хук фильтрации (для внешних систем)
    local hookResult = hook.Run("VD_FilterVehicleList", ply, vlist)
    if hookResult and istable(hookResult) then
        vlist = hookResult
    end

    return vlist
end

-- ════════════════════════════════════════════════════════
-- Спавн транспорта (ИСПРАВЛЕНО)
-- ════════════════════════════════════════════════════════
local function SpawnVehicleForPlayer(ply, dealer, vehicleClass)
    if not IsValid(ply) or not IsValid(dealer) then return false, "Ошибка: невалидный игрок или дилер" end
    if not vehicleClass or vehicleClass == "" then return false, "Не указан класс транспорта" end

    -- Проверка лимита (админ-спавн из ТАБ обходит и лимит, и фильтры доступа)
    local count = 0
    for id, ent in pairs(VD_AllVehicles) do
        if IsValid(ent) and ent.VD_Owner == ply then
            count = count + 1
        end
    end
    if count >= VD_MAX_VEHICLES and VD_AdminBypassClass ~= vehicleClass then
        return false, "Лимит транспорта достигнут (" .. VD_MAX_VEHICLES .. "). Удалите старую машину."
    end

    -- ═══ Определяем, является ли класс фракционным для игрока ═══
    local isFactionVehicle = false
    local faction = nil
    if Factions then
        local steam = ply:SteamID()
        for fname, f in pairs(Factions) do
            if f.Members and f.Members[steam] then
                faction = fname
                break
            end
        end
    end
    if faction and dealer.VD_Vehicles and dealer.VD_Vehicles[faction] then
        for _, v in ipairs(dealer.VD_Vehicles[faction]) do
            if v.class == vehicleClass then
                isFactionVehicle = true
                break
            end
        end
    end

    -- ═══ Проверки доступа (пропускаем для фракционных машин и админ-спавна) ═══
    if not isFactionVehicle and VD_AdminBypassClass ~= vehicleClass then
        local dealerData = {
            vehicles = dealer.VD_Vehicles or {},
        }
        local hookResult = hook.Run("VD_PreSpawnCheck", ply, vehicleClass, dealerData)
        if hookResult == false then
            return false, "У вас нет доступа к этому транспорту"
        end

        local accessResult = hook.Run("VD_CheckVehicleAccess", ply, vehicleClass, dealerData)
        if accessResult == false then
            return false, "Доступ запрещён системой доступа"
        end
    end

    -- ═══ Определяем позицию спавна ═══
    local spawnPos, spawnAngle
    local hasCustom = false
    pcall(function() hasCustom = dealer:GetHasCustomSpawn() end)

    if hasCustom then
        pcall(function()
            spawnPos = dealer:GetSpawnPos()
            spawnAngle = dealer:GetSpawnAngle()
        end)
    end

    -- ═══ Оплата (Код 82): цена из списков дилера; фракционный — бесплатно; ═══
    -- ═══ админ-спавн из ТАБ (VD_AdminBypassClass) — без списания.           ═══
    local vdPaid = 0
    local vdPrice, vdPriceSrc = priceOf(dealer, faction, vehicleClass)
    local vdFree = (VD_AdminBypassClass == vehicleClass) or (vdPriceSrc == faction)
    if not vdFree and vdPrice > 0 then
        if not (GRM and GRM.TakeMoney) then
            return false, "Модуль валюты недоступен — покупка невозможна"
        end
        if GRM.GetBalance and GRM.GetBalance(ply) < vdPrice then
            return false, "Не хватает наличных: нужно " .. tostring(GRM.Format and GRM.Format(vdPrice) or vdPrice)
        end
        GRM.TakeMoney(ply, vdPrice, "Покупка транспорта у дилера: " .. tostring(vehicleClass))
        vdPaid = vdPrice
    end

    if not spawnPos then
        local forwardDir = dealer:GetForward()
        local traceStart = dealer:GetPos() + Vector(0, 0, 40)
        local traceEnd   = traceStart + forwardDir * VD_SPAWN_FORWARD

        local tr = util.TraceLine({
            start  = traceStart,
            endpos = traceEnd,
            filter = {dealer, ply},
        })

        if tr.Hit then
            spawnPos = tr.HitPos - forwardDir * 80
        else
            spawnPos = traceEnd
        end

        local groundTr = util.TraceLine({
            start  = spawnPos + Vector(0, 0, 100),
            endpos = spawnPos - Vector(0, 0, 200),
            filter = {dealer, ply},
        })
        if groundTr.Hit then
            spawnPos = groundTr.HitPos + Vector(0, 0, 5)
        end

        spawnAngle = dealer:GetAngles()
        spawnAngle.y = spawnAngle.y + 90
        spawnAngle.p = 0
        spawnAngle.r = 0
    end

    -- ═══ Спавн транспорта (без изменений) ═══
    local vehicleList = list.Get("Vehicles") or {}
    local vehicleData = vehicleList[vehicleClass]
    local simfphysList = list.Get("simfphys_vehicles") or {}
    local simfphysData = simfphysList[vehicleClass]
    local lvsList = list.Get("LVS_Vehicles") or {}

    local ent
    local displayName = vehicleClass

    if simfphysData then
        displayName = simfphysData.Name or simfphysData.PrintName or vehicleClass
        local spawnList = vehicleClass
        if simfphysData.SpawnList and simfphysData.SpawnList ~= "" then
            spawnList = simfphysData.SpawnList
        end
        if spawnList and spawnList ~= "" and simfphys and simfphys.SpawnVehicle then
            local ok, result = pcall(simfphys.SpawnVehicle, ply, spawnPos, spawnAngle, spawnList)
            if ok and IsValid(result) then
                ent = result
            else
                vdDbgPrint("simfphys.SpawnVehicle failed for:", spawnList, tostring(result))
            end
        end
        if not IsValid(ent) and simfphys and simfphys.SpawnVehicleSimple then
            local ok, result = pcall(simfphys.SpawnVehicleSimple, spawnList, spawnPos, spawnAngle)
            if ok and IsValid(result) then
                ent = result
            else
                vdDbgPrint("simfphys.SpawnVehicleSimple also failed for:", spawnList)
            end
        end

    elseif lvsList[vehicleClass] then
        local lvsData = lvsList[vehicleClass]
        displayName = lvsData.Name or lvsData.PrintName or vehicleClass
        ent = ents.Create(lvsData.Class or "lvs_base")
        if IsValid(ent) then
            ent:SetModel(lvsData.Model or "models/buggy.mdl")
            ent:SetPos(spawnPos)
            ent:SetAngles(spawnAngle)
            if lvsData.KeyValues then
                for k, v in pairs(lvsData.KeyValues) do
                    ent:SetKeyValue(k, v)
                end
            end
            ent:Spawn()
            ent:Activate()
        end

    elseif vehicleData then
        displayName = vehicleData.Name or vehicleClass
        ent = ents.Create(vehicleData.Class or "prop_vehicle_jeep")
        if IsValid(ent) then
            ent:SetModel(vehicleData.Model or "models/buggy.mdl")
            ent:SetKeyValue("vehiclescript", vehicleData.KeyValues and vehicleData.KeyValues.VehicleScript or "scripts/vehicles/jeep_test.txt")
            ent:SetKeyValue("actionScale", vehicleData.KeyValues and vehicleData.KeyValues.actionScale or "1")
            ent:SetPos(spawnPos)
            ent:SetAngles(spawnAngle)
            ent:Spawn()
            ent:Activate()
        end

    else
        for class, data in pairs(simfphysList) do
            if class == vehicleClass or (data.SpawnList and data.SpawnList == vehicleClass) then
                displayName = data.Name or data.PrintName or vehicleClass
                local sList = class
                if data.SpawnList and data.SpawnList ~= "" then
                    sList = data.SpawnList
                end
                if sList and sList ~= "" and simfphys and simfphys.SpawnVehicle then
                    local ok, result = pcall(simfphys.SpawnVehicle, ply, spawnPos, spawnAngle, sList)
                    if ok and IsValid(result) then
                        ent = result
                    end
                end
                break
            end
        end
        if not IsValid(ent) then
            ent = ents.Create("prop_vehicle_jeep")
            if IsValid(ent) then
                ent:SetModel("models/buggy.mdl")
                ent:SetKeyValue("vehiclescript", "scripts/vehicles/jeep_test.txt")
                ent:SetPos(spawnPos)
                ent:SetAngles(spawnAngle)
                ent:Spawn()
                ent:Activate()
                displayName = vehicleClass .. " (fallback: Jeep)"
            end
        end
    end

    if not IsValid(ent) then
        if vdPaid > 0 and GRM and GRM.GiveMoney then
            GRM.GiveMoney(ply, vdPaid, "Возврат: транспорт не создан")
            ply:ChatPrint("[VD] Транспорт не создан — деньги возвращены: " .. tostring(GRM.Format and GRM.Format(vdPaid) or vdPaid))
        end
        return false, "Не удалось создать транспорт: " .. vehicleClass
    end

    ent.VD_Owner     = ply
    ent.VD_ID        = ent:EntIndex()
    ent.VD_Class     = vehicleClass
    ent.VD_SpawnTime = CurTime()
    ent.VD_Price     = vdPaid -- для возврата 50% при удалении (VD_REFUND_RATE)
    VD_AllVehicles[ent:EntIndex()] = ent

    -- ═══ Владение ключами (Код 82): машина сразу закрыта, ключ у владельца ═══
    if VK then
        if vdPriceSrc and vdPriceSrc ~= "global" and vdPriceSrc ~= "nofaction" and faction and VK.SetFactionOwner then
            pcall(VK.SetFactionOwner, ent, faction)
        elseif VK.SetPlayerOwner then
            pcall(VK.SetPlayerOwner, ent, ply)
        end
    end

    local payNote = ""
    if vdPaid > 0 then
        payNote = " • оплачено: " .. tostring(GRM.Format and GRM.Format(vdPaid) or vdPaid)
    end
    ply:ChatPrint("[VD] Транспорт заспавнен: " .. displayName .. payNote)
    hook.Run("VD_OnVehicleSpawned", ent, ply, vehicleClass)

    local dID = dealer.VD_ID or ""
    pcall(function() dID = dealer:GetDealerID() end)
    vdDbgPrint(ply:Nick(), "заспавнил", vehicleClass, "через дилера", dID, "paid:", vdPaid)
    pcall(pushMyVehicles, ply) -- обновить «Мои Т/С» в меню дилера (Код 82)

    return true, "Транспорт заспавнен: " .. displayName .. payNote
end

-- ════════════════════════════════════════════════════════
-- «Мои Т/С»: снапшот владельцу для меню дилера (Код 82)
-- ════════════════════════════════════════════════════════
pushMyVehicles = function(ply)
    if not IsValid(ply) then return end
    local out = {}
    for id, ent in pairs(VD_AllVehicles) do
        if IsValid(ent) and ent.VD_Owner == ply then
            local refund = math.floor((tonumber(ent.VD_Price) or 0) * VD_REFUND_RATE)
            out[#out + 1] = {
                id = ent:EntIndex(),
                class = tostring(ent.VD_Class or ent:GetClass()),
                name = (VK and VK.GetVehicleDisplayName and VK.GetVehicleDisplayName(ent)) or tostring(ent.VD_Class or ent:GetClass()),
                price = tonumber(ent.VD_Price) or 0,
                refund = refund,
            }
        end
    end
    net.Start("VD_MyList")
        net.WriteTable(out)
    net.Send(ply)
end

-- ════════════════════════════════════════════════════════
-- ENTITY: Initialize
-- ════════════════════════════════════════════════════════
function ENT:Initialize()
    -- Модель: из DealerModel или по умолчанию
    local mdl = DEALER_DEFAULT_MODEL
    pcall(function() mdl = self:GetDealerModel() end)
    if mdl == "" or not mdl then
        mdl = DEALER_DEFAULT_MODEL
    end
    self.VD_Model = mdl
    pcall(function() self:SetDealerModel(mdl) end)
    self:SetModel(mdl)

    self:SetSolid(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetUseType(SIMPLE_USE)

    self:PhysicsInit(SOLID_BBOX)
    self:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end

    self:DropToFloor()

    -- Исправление T-Pose
    local seq = self:LookupSequence("idle_all")
    if seq and seq > 0 then
        self:SetSequence(seq)
    else
        seq = self:LookupSequence("idle")
        if seq and seq > 0 then
            self:SetSequence(seq)
        else
            seq = self:LookupSequence("idle_subtle")
            if seq and seq > 0 then
                self:SetSequence(seq)
            end
        end
    end
    if seq and seq > 0 then
        self:SetPlaybackRate(1)
        self:SetCycle(0)
    end

    self.VD_Vehicles = self.VD_Vehicles or {
        __global = {},
        __nofaction = {},
    }

    local dealerID = ""
    pcall(function() dealerID = self:GetDealerID() end)
    if dealerID == "" or not dealerID then
        dealerID = GenerateDealerID()
        pcall(function() self:SetDealerID(dealerID) end)
    end
    self.VD_ID = dealerID

    local dName = ""
    pcall(function() dName = self:GetDealerName() end)
    if dName == "" then
        dName = "Дилер транспорта"
        pcall(function() self:SetDealerName(dName) end)
    end
    self.VD_Name = dName

    VehicleDealers[dealerID] = self

    local saved = LoadDealerConfig(dealerID)
    if saved then
        if saved.name and saved.name ~= "" then
            self.VD_Name = saved.name
            pcall(function() self:SetDealerName(saved.name) end)
        end
        if saved.model and saved.model ~= "" then
            self.VD_Model = saved.model
            pcall(function() self:SetDealerModel(saved.model) end)
            self:SetModel(saved.model)
            local newSeq = self:LookupSequence("idle_all") or self:LookupSequence("idle") or 0
            if newSeq > 0 then
                self:SetSequence(newSeq)
                self:SetPlaybackRate(1)
                self:SetCycle(0)
            end
        end
        if saved.vehicles then
            self.VD_Vehicles = saved.vehicles
        end
        if saved.hasCustomSpawn and saved.spawnPos then
            pcall(function()
                self:SetSpawnPos(saved.spawnPos)
                self:SetSpawnAngle(saved.spawnAngle or Angle(0, 0, 0))
                self:SetHasCustomSpawn(true)
            end)
            self.VD_HasCustomSpawn = true
            self.VD_SpawnPos = saved.spawnPos
            self.VD_SpawnAngle = saved.spawnAngle or Angle(0, 0, 0)
        end
        vdDbgPrint("Конфиг дилера загружен:", dealerID)
    end

    vdDbgPrint("Дилер заспавнен:", dealerID, self.VD_Name, "model:", self.VD_Model)
end

-- ════════════════════════════════════════════════════════
-- ENTITY: Think
-- ════════════════════════════════════════════════════════
function ENT:Think()
    local seq = self:GetSequence()
    if seq and seq > 0 then
        self:FrameAdvance(0)
    end
    self:NextThink(CurTime() + 0.1)
    return true
end

-- ════════════════════════════════════════════════════════
-- ENTITY: Use
-- ════════════════════════════════════════════════════════
function ENT:Use(activator, caller)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    local vlist = GetVehicleListForPlayer(activator, self)

    net.Start("VD_OpenMenu")
        net.WriteString(self:GetDealerID())
        net.WriteString(self:GetDealerName())
        net.WriteTable(vlist)
    net.Send(activator)
    pcall(pushMyVehicles, activator) -- «Мои Т/С» (Код 82)
end

-- ════════════════════════════════════════════════════════
-- ENTITY: OnRemove
-- ════════════════════════════════════════════════════════
function ENT:OnRemove()
    local dealerID = self.VD_ID or ""
    pcall(function() dealerID = self:GetDealerID() end)
    if dealerID and dealerID ~= "" then
        if not self.VD_PermanentDelete then
            local spawnPos = Vector(0, 0, 0)
            local spawnAngle = Angle(0, 0, 0)
            local hasCustom = false
            pcall(function()
                hasCustom = self:GetHasCustomSpawn()
                if hasCustom then
                    spawnPos = self:GetSpawnPos()
                    spawnAngle = self:GetSpawnAngle()
                end
            end)

            SaveDealerConfig(dealerID, {
                name           = SafeGetDealerName(self),
                model          = SafeGetDealerModel(self),
                vehicles       = self.VD_Vehicles,
                pos            = self:GetPos(),
                angles         = self:GetAngles(),
                hasCustomSpawn = hasCustom,
                spawnPos       = spawnPos,
                spawnAngle     = spawnAngle,
            })
        end
        VehicleDealers[dealerID] = nil
        vdDbgPrint("Дилер удалён:", dealerID, self.VD_PermanentDelete and "(навсегда)" or "(сохранён)")
    end
end

-- ════════════════════════════════════════════════════════
-- Сетевые обработчики
-- ════════════════════════════════════════════════════════

net.Receive("VD_SpawnRequest", function(_, ply)
    if not IsValid(ply) then return end

    local dealerID    = net.ReadString()
    local vehicleClass = net.ReadString()

    local dealer = VehicleDealers[dealerID]

    if not IsValid(dealer) then
        local minDist = 400
        for id, d in pairs(VehicleDealers) do
            if IsValid(d) then
                local dist = ply:GetPos():Distance(d:GetPos())
                if dist < minDist then
                    minDist = dist
                    dealer = d
                end
            end
        end
    end

    if not IsValid(dealer) then
        net.Start("VD_SpawnResult")
            net.WriteBool(false)
            net.WriteString("Дилер не найден — подойдите ближе к дилеру")
        net.Send(ply)
        return
    end

    if ply:GetPos():Distance(dealer:GetPos()) > 300 then
        net.Start("VD_SpawnResult")
            net.WriteBool(false)
            net.WriteString("Слишком далеко от дилера")
        net.Send(ply)
        return
    end

    local ok, msg = SpawnVehicleForPlayer(ply, dealer, vehicleClass)

    net.Start("VD_SpawnResult")
        net.WriteBool(ok)
        net.WriteString(msg or "")
    net.Send(ply)
end)

net.Receive("VD_RemoveRequest", function(_, ply)
    if not IsValid(ply) then return end
    local veh = net.ReadEntity()
    local function res(ok, msg)
        net.Start("VD_SpawnResult")
            net.WriteBool(ok == true)
            net.WriteString(tostring(msg or ""))
        net.Send(ply)
    end
    if not IsValid(veh) then res(false, "Транспорт не найден") return end
    local idx = veh:EntIndex()
    local tracked = (VD_AllVehicles and VD_AllVehicles[idx] ~= nil) or veh.VD_Owner ~= nil or veh.VD_ID ~= nil
    if not tracked then res(false, "Это не транспорт из дилера") return end
    local mine = (veh.VD_Owner == ply)
        or (veh.VK_OwnerType == "player" and veh.VK_OwnerSteam == ply:SteamID())
    if not (mine or ply:IsSuperAdmin()) then res(false, "Это не ваш транспорт") return end
    if ply:GetPos():DistToSqr(veh:GetPos()) > 600 * 600 then res(false, "Слишком далеко от транспорта") return end

    -- возврат владельцу (Код 82): 50% фактической цены покупки
    local refund = 0
    local price = tonumber(veh.VD_Price) or 0
    local owner = veh.VD_Owner
    if mine and price > 0 then
        refund = math.floor(price * VD_REFUND_RATE)
    end
    local cls = tostring(veh.VD_Class or veh:GetClass())
    if VD_AllVehicles then VD_AllVehicles[idx] = nil end
    veh:Remove()
    if refund > 0 and GRM and GRM.GiveMoney and IsValid(owner) then
        GRM.GiveMoney(owner, refund, "Возврат за удалённый транспорт: " .. cls)
    end
    vdDbgPrint(ply:Nick(), "удалил транспорт", cls, "возврат:", refund)
    hook.Run("VD_OnVehicleRemoved", veh, ply, cls)
    res(true, "Транспорт убран: " .. cls .. (refund > 0 and (" • возврат " .. tostring(GRM.Format and GRM.Format(refund) or refund)) or ""))
    pcall(pushMyVehicles, ply)
end)

net.Receive("VD_ConfigOpen", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    local dealerID = net.ReadString()
    local dealer = VehicleDealers[dealerID]
    if not IsValid(dealer) then return end

    local serverVehicleList = {}
    if GRM_GetAllVehicleClasses then
        serverVehicleList = GRM_GetAllVehicleClasses()
    end

    net.Start("VD_ConfigData")
        net.WriteString(dealerID)
        net.WriteString(dealer:GetDealerName())
        net.WriteString(dealer:GetDealerModel())
        net.WriteTable(dealer.VD_Vehicles or {})
        net.WriteTable(serverVehicleList)
    net.Send(ply)
end)

net.Receive("VD_ConfigSave", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    local dealerID   = net.ReadString()
    local dealerName = net.ReadString()
    local dealerModel = net.ReadString()
    local vehicles   = net.ReadTable()

    local dealer = VehicleDealers[dealerID]
    if not IsValid(dealer) then return end

    dealer:SetDealerName(dealerName)

    if dealerModel and dealerModel ~= "" then
        dealer:SetDealerModel(dealerModel)
        dealer:SetModel(dealerModel)
        dealer.VD_Model = dealerModel

        local seq = dealer:LookupSequence("idle_all") or dealer:LookupSequence("idle") or 0
        if seq > 0 then
            dealer:SetSequence(seq)
            dealer:SetPlaybackRate(1)
            dealer:SetCycle(0)
        end
    end

    local allVehClasses = {}
    if GRM_GetAllVehicleClasses then
        allVehClasses = GRM_GetAllVehicleClasses()
    end
    local nameMap = {}
    for _, veh in ipairs(allVehClasses) do
        nameMap[veh.class] = veh.name or veh.class
    end

    for factionKey, vehList in pairs(vehicles) do
        if istable(vehList) then
            for i, v in ipairs(vehList) do
                if istable(v) and v.class then
                    v.name = nameMap[v.class] or v.name or v.class
                end
            end
        end
    end

    dealer.VD_Vehicles = vehicles

    local spawnPos = Vector(0, 0, 0)
    local spawnAngle = Angle(0, 0, 0)
    local hasCustom = false
    pcall(function()
        hasCustom = dealer:GetHasCustomSpawn()
        if hasCustom then
            spawnPos = dealer:GetSpawnPos()
            spawnAngle = dealer:GetSpawnAngle()
        end
    end)

    SaveDealerConfig(dealerID, {
        name           = dealerName,
        model          = dealerModel,
        vehicles       = vehicles,
        pos            = dealer:GetPos(),
        angles         = dealer:GetAngles(),
        hasCustomSpawn = hasCustom,
        spawnPos       = spawnPos,
        spawnAngle     = spawnAngle,
    })

    ply:ChatPrint("[VD] Конфигурация дилера сохранена: " .. dealerName)
    vdDbgPrint(ply:Nick(), "сохранил конфиг дилера:", dealerID, "model:", dealerModel)
end)

net.Receive("VD_SetSpawnPoint", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end

    local dealerID   = net.ReadString()
    local spawnPos   = net.ReadVector()
    local spawnAngle = net.ReadAngle()

    local dealer = VehicleDealers[dealerID]
    if not IsValid(dealer) then
        ply:ChatPrint("[VD] Дилер не найден")
        return
    end

    dealer:SetSpawnPos(spawnPos)
    dealer:SetSpawnAngle(spawnAngle)
    dealer:SetHasCustomSpawn(true)
    dealer.VD_HasCustomSpawn = true
    dealer.VD_SpawnPos = spawnPos
    dealer.VD_SpawnAngle = spawnAngle

    SaveDealerConfig(dealerID, {
        name           = SafeGetDealerName(dealer),
        model          = SafeGetDealerModel(dealer),
        vehicles       = dealer.VD_Vehicles,
        pos            = dealer:GetPos(),
        angles         = dealer:GetAngles(),
        hasCustomSpawn = true,
        spawnPos       = spawnPos,
        spawnAngle     = spawnAngle,
    })

    ply:ChatPrint("[VD] Точка спавна установлена для дилера: " .. SafeGetDealerName(dealer))
    vdDbgPrint(ply:Nick(), "установил точку спавна для", dealerID, tostring(spawnPos))
end)

-- ════════════════════════════════════════════════════════
-- Чат-команды (без изменений)
-- ════════════════════════════════════════════════════════
hook.Add("PlayerSay", "VD_ChatCommands", function(ply, text)
    local lower = string.lower(string.Trim(text))

    if lower == "/vd_config" or lower == "!vd_config" then
        if not ply:IsSuperAdmin() then
            ply:ChatPrint("[VD] Только для суперадминов")
            return ""
        end

        local closest = nil
        local minDist = 500
        for id, dealer in pairs(VehicleDealers) do
            if IsValid(dealer) then
                local dist = ply:GetPos():Distance(dealer:GetPos())
                if dist < minDist then
                    minDist = dist
                    closest = dealer
                end
            end
        end

        if not IsValid(closest) then
            ply:ChatPrint("[VD] Поблизости нет дилера (подойдите ближе 500 ед.)")
            return ""
        end

        local serverVehicleList = {}
        if GRM_GetAllVehicleClasses then
            serverVehicleList = GRM_GetAllVehicleClasses()
        end

        net.Start("VD_ConfigData")
            net.WriteString(closest:GetDealerID())
            net.WriteString(closest:GetDealerName())
            net.WriteString(closest:GetDealerModel())
            net.WriteTable(closest.VD_Vehicles or {})
            net.WriteTable(serverVehicleList)
        net.Send(ply)

        return ""
    end

    if lower == "/vd_spawn" or lower == "!vd_spawn" then
        if not ply:IsSuperAdmin() then
            ply:ChatPrint("[VD] Только для суперадминов")
            return ""
        end

        local closest = nil
        local minDist = 800
        for id, dealer in pairs(VehicleDealers) do
            if IsValid(dealer) then
                local dist = ply:GetPos():Distance(dealer:GetPos())
                if dist < minDist then
                    minDist = dist
                    closest = dealer
                end
            end
        end

        if not IsValid(closest) then
            ply:ChatPrint("[VD] Поблизости нет дилера (подойдите ближе 800 ед.)")
            return ""
        end

        local spawnPos = ply:GetPos()
        local spawnAngle = ply:GetAngles()
        spawnAngle.p = 0
        spawnAngle.r = 0

        closest:SetSpawnPos(spawnPos)
        closest:SetSpawnAngle(spawnAngle)
        closest:SetHasCustomSpawn(true)
        closest.VD_HasCustomSpawn = true
        closest.VD_SpawnPos = spawnPos
        closest.VD_SpawnAngle = spawnAngle

        local dealerID = closest.VD_ID or ""
        pcall(function() dealerID = closest:GetDealerID() end)

        SaveDealerConfig(dealerID, {
            name           = SafeGetDealerName(closest),
            model          = SafeGetDealerModel(closest),
            vehicles       = closest.VD_Vehicles,
            pos            = closest:GetPos(),
            angles         = closest:GetAngles(),
            hasCustomSpawn = true,
            spawnPos       = spawnPos,
            spawnAngle     = spawnAngle,
        })

        ply:ChatPrint("[VD] Точка спавна установлена на вашей позиции для дилера: " .. SafeGetDealerName(closest))
        vdDbgPrint(ply:Nick(), "установил точку спавна через чат для", dealerID)

        return ""
    end

    if lower == "/vd_clearspawn" or lower == "!vd_clearspawn" then
        if not ply:IsSuperAdmin() then
            ply:ChatPrint("[VD] Только для суперадминов")
            return ""
        end

        local closest = nil
        local minDist = 800
        for id, dealer in pairs(VehicleDealers) do
            if IsValid(dealer) then
                local dist = ply:GetPos():Distance(dealer:GetPos())
                if dist < minDist then
                    minDist = dist
                    closest = dealer
                end
            end
        end

        if not IsValid(closest) then
            ply:ChatPrint("[VD] Поблизости нет дилера")
            return ""
        end

        closest:SetHasCustomSpawn(false)
        closest.VD_HasCustomSpawn = false

        local dealerID = closest.VD_ID or ""
        pcall(function() dealerID = closest:GetDealerID() end)

        SaveDealerConfig(dealerID, {
            name           = SafeGetDealerName(closest),
            model          = SafeGetDealerModel(closest),
            vehicles       = closest.VD_Vehicles,
            pos            = closest:GetPos(),
            angles         = closest:GetAngles(),
            hasCustomSpawn = false,
        })

        ply:ChatPrint("[VD] Кастомная точка спавна удалена для дилера: " .. SafeGetDealerName(closest))
        return ""
    end

    if lower == "/vd_save" or lower == "!vd_save" then
        if not ply:IsSuperAdmin() then
            ply:ChatPrint("[VD] Только для суперадминов")
            return ""
        end
        SaveAllDealers()
        local count = 0
        for id, d in pairs(VehicleDealers) do
            if IsValid(d) then count = count + 1 end
        end
        ply:ChatPrint("[VD] Все дилеры сохранены (" .. count .. " шт.). Дилеры восстановятся после рестарта карты.")
        return ""
    end

    if lower == "/vd_delete" or lower == "!vd_delete" then
        if not ply:IsSuperAdmin() then
            ply:ChatPrint("[VD] Только для суперадминов")
            return ""
        end

        local closest = nil
        local closestID = nil
        local minDist = 500
        for id, dealer in pairs(VehicleDealers) do
            if IsValid(dealer) then
                local dist = ply:GetPos():Distance(dealer:GetPos())
                if dist < minDist then
                    minDist = dist
                    closest = dealer
                    closestID = id
                end
            end
        end

        if not IsValid(closest) then
            ply:ChatPrint("[VD] Поблизости нет дилера (подойдите ближе 500 ед.)")
            return ""
        end

        local dealerName = SafeGetDealerName(closest)
        local dealerID = closestID
        pcall(function() dealerID = closest:GetDealerID() end)

        if dealerID and dealerID ~= "" then
            file.Delete(VD_DEALER_DIR .. dealerID .. ".json")
            vdDbgPrint("Файл сохранения удалён:", dealerID)
        end

        closest.VD_PermanentDelete = true
        closest:Remove()

        ply:ChatPrint("[VD] Дилер удалён навсегда: " .. dealerName)
        return ""
    end

    if lower == "/vd_remove" or lower == "!vd_remove" then
        local removed, refunded = 0, 0
        for id, ent in pairs(VD_AllVehicles) do
            if IsValid(ent) and ent.VD_Owner == ply then
                local price = tonumber(ent.VD_Price) or 0
                if price > 0 then refunded = refunded + math.floor(price * VD_REFUND_RATE) end
                ent:Remove()
                VD_AllVehicles[id] = nil
                removed = removed + 1
            end
        end
        if refunded > 0 and GRM and GRM.GiveMoney then
            GRM.GiveMoney(ply, refunded, "Возврат за удалённый транспорт (/vd_remove)")
        end
        ply:ChatPrint("[VD] Удалено транспорта: " .. removed .. (refunded > 0 and (" • возврат " .. tostring(GRM.Format and GRM.Format(refunded) or refunded)) or ""))
        pcall(pushMyVehicles, ply)
        return ""
    end
end)

-- ════════════════════════════════════════════════════════
-- Периодическое сохранение и очистка (без изменений)
-- ════════════════════════════════════════════════════════
timer.Create("VD_AutoSave", 120, 0, function()
    SaveAllDealers()
end)

timer.Create("VD_CleanupVehicles", 60, 0, function()
    if not VD_AllVehicles then return end
    local removed = 0
    for id, ent in pairs(VD_AllVehicles) do
        if not IsValid(ent) then
            VD_AllVehicles[id] = nil
            removed = removed + 1
        end
    end
    if removed > 0 then
        vdDbgPrint("Очищено " .. removed .. " невалидных записей из VD_AllVehicles")
    end
end)

hook.Add("InitPostEntity", "VD_LoadSavedDealers", function()
    if not file.IsDir(VD_DEALER_DIR, "DATA") then return end

    local files = file.Find(VD_DEALER_DIR .. "*.json", "DATA")
    for _, fname in ipairs(files) do
        local dealerID = string.gsub(fname, "%.json$", "")

        if VehicleDealers[dealerID] and IsValid(VehicleDealers[dealerID]) then
            vdDbgPrint("Дилер уже существует, пропускаем:", dealerID)
            continue
        end

        local data = LoadDealerConfig(dealerID)
        if data and data.pos then
            local ent = ents.Create("sent_vehicle_dealer")
            if IsValid(ent) then
                ent:SetPos(data.pos)
                ent:SetAngles(data.angles or Angle(0, 0, 0))
                ent:SetDealerID(dealerID)
                ent:Spawn()
                ent:Activate()

                if data.name and data.name ~= "" then
                    ent:SetDealerName(data.name)
                    ent.VD_Name = data.name
                end
                if data.model and data.model ~= "" then
                    ent:SetDealerModel(data.model)
                    ent:SetModel(data.model)
                    ent.VD_Model = data.model
                    local seq = ent:LookupSequence("idle_all") or ent:LookupSequence("idle") or 0
                    if seq > 0 then
                        ent:SetSequence(seq)
                        ent:SetPlaybackRate(1)
                        ent:SetCycle(0)
                    end
                end
                if data.vehicles then
                    ent.VD_Vehicles = data.vehicles
                end
                if data.hasCustomSpawn and data.spawnPos then
                    ent:SetSpawnPos(data.spawnPos)
                    ent:SetSpawnAngle(data.spawnAngle or Angle(0, 0, 0))
                    ent:SetHasCustomSpawn(true)
                    ent.VD_HasCustomSpawn = true
                    ent.VD_SpawnPos = data.spawnPos
                    ent.VD_SpawnAngle = data.spawnAngle or Angle(0, 0, 0)
                end

                ent.VD_ID = dealerID
                VehicleDealers[dealerID] = ent
                vdDbgPrint("Дилер восстановлен:", dealerID, data.name or "без имени")
            end
        else
            vdDbgPrint("Найден конфиг дилера (без позиции):", dealerID, data and data.name or "без имени")
        end
    end
end)

hook.Add("ShutDown", "VD_SaveOnShutdown", function()
    SaveAllDealers()
end)

print("[VD] Сущность sent_vehicle_dealer загружена")

-- ════════════════════════════════════════════════════════
-- Мост ТАБ-меню (аудит протоколов): админ-спавн транспорта игроку
-- Раньше ТАБ слал VD_RequestVehicleList / VD_AdminSpawnVehicle в никуда —
-- кнопки «Заспавнить» были мёртвыми. Обработчики здесь, поверх
-- того же контура SpawnVehicleForPlayer (без денег и фильтров доступа).
-- ════════════════════════════════════════════════════════
util.AddNetworkString("VD_RequestVehicleList")
util.AddNetworkString("VD_AdminSpawnVehicle")
util.AddNetworkString("VD_VehicleList")

function _G.VD_AdminSpawnFor(targetPly, vehicleClass)
    if not IsValid(targetPly) then return false, "Игрок не в сети" end
    local dealer, bd = nil, math.huge
    for id, d in pairs(VehicleDealers or {}) do
        if IsValid(d) then
            local dist = targetPly:GetPos():DistToSqr(d:GetPos())
            if dist < bd then bd = dist dealer = d end
        end
    end
    if not IsValid(dealer) then
        for _, d in ipairs(ents.FindByClass("sent_vehicle_dealer")) do
            if IsValid(d) then dealer = d break end
        end
    end
    if not IsValid(dealer) then return false, "На карте нет авто-дилеров (sent_vehicle_dealer)" end
    VD_AdminBypassClass = vehicleClass
    local ok, err = SpawnVehicleForPlayer(targetPly, dealer, vehicleClass)
    VD_AdminBypassClass = nil
    return ok, err
end

net.Receive("VD_RequestVehicleList", function(_, ply)
    if not IsValid(ply) or not (ply:IsSuperAdmin() or ply:IsAdmin()) then return end
    local out, seen = {}, {}
    local function collect(dealer)
        if not IsValid(dealer) or not istable(dealer.VD_Vehicles) then return end
        local dname = SafeGetDealerName and SafeGetDealerName(dealer) or "дилер"
        for _, arr in pairs(dealer.VD_Vehicles) do
            if istable(arr) then
                for _, v in ipairs(arr) do
                    if istable(v) and isstring(v.class) and v.class ~= "" and not seen[v.class] then
                        seen[v.class] = true
                        out[#out + 1] = { class = v.class, name = tostring(v.name or v.PrintName or v.class), dealer = tostring(dname) }
                    end
                end
            end
        end
    end
    for _, dealer in ipairs(ents.FindByClass("sent_vehicle_dealer")) do collect(dealer) end
    for _, d in pairs(VehicleDealers or {}) do collect(d) end
    table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
    net.Start("VD_VehicleList")
        net.WriteTable(out)
    net.Send(ply)
end)

net.Receive("VD_AdminSpawnVehicle", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTTALK, "[ТАБ•Транспорт] Только суперадмин.") end
        return
    end
    local sid64  = tostring(net.ReadString() or "")
    local vclass = string.Trim(tostring(net.ReadString() or ""))
    if vclass == "" then return end
    local target = nil
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p:SteamID64() == sid64 then target = p break end
    end
    if not IsValid(target) then
        ply:PrintMessage(HUD_PRINTTALK, "[ТАБ•Транспорт] Игрок с таким SID64 не в сети.")
        return
    end
    local ok, err = _G.VD_AdminSpawnFor(target, vclass)
    if ok then
        ply:PrintMessage(HUD_PRINTTALK, "[ТАБ•Транспорт] Выдано " .. vclass .. " → " .. target:Nick())
        if GRM and GRM.Notify then GRM.Notify(target, "Администрация выдала вам транспорт: " .. vclass, 160, 220, 255) end
    else
        ply:PrintMessage(HUD_PRINTTALK, "[ТАБ•Транспорт] Ошибка: " .. tostring(err or "неизвестно"))
    end
end)
