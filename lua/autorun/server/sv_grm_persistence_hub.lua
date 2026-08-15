-- GRM unified map persistence hub
if not SERVER then return end

GRM = GRM or {}
GRM.PersistenceHub = GRM.PersistenceHub or { Version = "1.2.0" }
GRM.PersistenceHub.Version = "1.2.0"

util.AddNetworkString("GRM_Persistence_Open")
util.AddNetworkString("GRM_Persistence_Action")
util.AddNetworkString("GRM_Persistence_Result")

local function notify(ply, ok, text)
    if IsValid(ply) then
        net.Start("GRM_Persistence_Result")
            net.WriteBool(ok == true)
            net.WriteString(tostring(text or ""))
        net.Send(ply)
    end
end

local function call(label, fn, ply)
    if not isfunction(fn) then return false, label .. ": модуль не загружен" end
    local ok, result, detail = pcall(fn, ply)
    if not ok then return false, label .. ": " .. tostring(result) end
    if result == false then return false, label .. ": " .. tostring(detail or "операция не выполнена") end
    return true, label .. ": " .. tostring(detail or "операция выполнена")
end


local function invoke(moduleName, method, fallback, ...)
    local mod = GRM and GRM[moduleName] or nil
    if not istable(mod) then return false, "модуль " .. moduleName .. " не загружен" end
    local fn = mod[method]
    if not isfunction(fn) and isstring(fallback) and fallback ~= "" then fn = mod[fallback] end
    if not isfunction(fn) then
        return false, ("метод %s.%s не загружен"):format(moduleName, method)
    end
    return fn(...)
end

local function operation(id, ply)
    local save = id:sub(-5) == "_save"
    local load = id:sub(-5) == "_load"
    local base = save and id:sub(1, -6) or (load and id:sub(1, -6) or id)
    local ops = {
        phone = {
            save = function(p) return invoke("Phone", "SaveAll", "SaveMapEntities", p) end,
            load = function(p) return invoke("Phone", "LoadAll", "LoadMapEntities", p) end,
        },
        cctv = { save = function() return invoke("CCTV", "SaveAll", "SavePermanent") end, load = function() return invoke("CCTV", "LoadAll", "LoadPermanent") end },
        alarm = { save = function() return invoke("Alarm", "SaveAll", "SavePermanent") end, load = function() return invoke("Alarm", "LoadAll", "LoadPermanent") end },
        factory = {
            save = function(p) return invoke("FactoryCycle", "SaveAll", "SaveMap", p, "admin hub") end,
            load = function(p) return invoke("FactoryCycle", "LoadAll", "LoadMap", p) end,
        },
        logistics = { save = function(p) return invoke("Logistics", "SaveAll", "SaveMap", p) end, load = function(p) return invoke("Logistics", "LoadAll", "LoadMap", p) end },
        food = {
            save = function(p) return invoke("Food", "SaveAll", "SaveVendingMachines", p) end,
            load = function(p) return invoke("Food", "LoadAll", "LoadVendingMachines", p, true) end,
        },
        roomtap = { save = function(p) return invoke("RoomTap", "SaveAll", "SaveMapEquipment", p) end, load = function(p) return invoke("RoomTap", "LoadAll", "LoadMapEquipment", p) end },
        wanted = { save = function() return invoke("Wanted", "Save") end, load = function() return invoke("Wanted", "Load") end },
        mining = {
            save = function(p)
                if GRM.MiningPersistence and GRM.MiningPersistence.SaveAll then return GRM.MiningPersistence.SaveAll(p) end
                if not isfunction(GRM_SaveEntities) then return false, "модуль шахты не загружен" end
                local count = GRM_SaveEntities(); return true, "legacy saver: " .. tostring(count)
            end,
            load = function(p)
                if GRM.MiningPersistence and GRM.MiningPersistence.LoadAll then return GRM.MiningPersistence.LoadAll(p) end
                if not isfunction(GRM_LoadEntities) then return false, "модуль шахты не загружен" end
                local count = GRM_LoadEntities(); return true, "legacy loader: " .. tostring(count)
            end,
        },
        doors = {
            save = function()
                if not GRM.Doors then return false, "модуль дверей не загружен" end
                GRM.Doors.SaveDoors(); GRM.Doors.SaveCategories(); GRM.Doors.SaveWarrants(); return true
            end,
            load = function()
                if not GRM.Doors then return false, "модуль дверей не загружен" end
                GRM.Doors.LoadDoors(); GRM.Doors.LoadCategories(); GRM.Doors.LoadWarrants(); return true
            end,
        },
        arrest = { save = function() return invoke("Arrest", "SaveConfig") end, load = function() return invoke("Arrest", "LoadConfig") end },
        customization = { save = function() return invoke("Customization", "SaveData") end, load = function() return invoke("Customization", "LoadData") end },
        vendors = { save = function() return invoke("Vendor", "SaveMapVendors") end, load = function() return invoke("Vendor", "LoadMapVendors") end },
        vehicle_dealers = { save = function() return invoke("VehicleDealer", "SaveAll") end, load = function() return invoke("VehicleDealer", "LoadAll") end },
        quests = { save = function() return invoke("Quests", "SaveAll") end, load = function() return invoke("Quests", "LoadAll") end },
        electronics = { save = function() return invoke("Electronics", "SaveAll") end, load = function() return invoke("Electronics", "LoadAll") end },
        perm = { save = function() return invoke("Perm", "SaveAll") end, load = function() return invoke("Perm", "LoadAll") end },
    }
    -- Совместимость с уже открытым старым клиентским меню.
    ops.vending = ops.food
    if not save and not load then return false, "Неизвестная операция" end
    local mod = ops[base]
    if not mod then return false, "Неизвестный модуль: " .. base end
    return call(base .. (save and " save" or " load"), mod[save and "save" or "load"], ply)
end

local function all(ply, mode)
    local ids = { "phone", "cctv", "alarm", "factory", "logistics", "food", "roomtap", "wanted", "mining", "doors", "arrest", "customization", "vendors", "vehicle_dealers", "quests", "electronics", "perm" }
    local done, errors = 0, {}
    for _, id in ipairs(ids) do
        local ok, msg = operation(id .. "_" .. mode, ply)
        if ok then done = done + 1 else errors[#errors + 1] = msg end
    end
    if #errors > 0 then return false, (mode == "save" and "Сохранение" or "Загрузка") .. ": " .. done .. "/" .. #ids .. "; " .. table.concat(errors, " | ") end
    return true, (mode == "save" and "Сохранено" or "Загружено") .. ": " .. done .. " модулей на карте " .. game.GetMap()
end

net.Receive("GRM_Persistence_Open", function(_, ply)
    if IsValid(ply) and ply:IsSuperAdmin() then
        net.Start("GRM_Persistence_Open") net.Send(ply)
    end
end)

net.Receive("GRM_Persistence_Action", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    local id = tostring(net.ReadString() or "")
    local ok, msg
    if id == "all_save" or id == "all_load" then
        ok, msg = all(ply, id:sub(5) == "save" and "save" or "load")
    else
        ok, msg = operation(id, ply)
    end
    notify(ply, ok, msg)
end)

concommand.Add("grm_persistence_admin", function(ply)
    if IsValid(ply) and ply:IsSuperAdmin() then
        net.Start("GRM_Persistence_Open") net.Send(ply)
    end
end)

hook.Add("PlayerSay", "GRM_Persistence_ChatCommand", function(ply, text)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    local command = string.lower(string.Trim(tostring(text or "")))
    if command == "/grm_persistence" or command == "!grm_persistence" then
        net.Start("GRM_Persistence_Open") net.Send(ply)
        return ""
    end
end)
