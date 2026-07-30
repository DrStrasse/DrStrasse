-- GRM unified map persistence hub
if not SERVER then return end

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
    local ok, err = pcall(fn, ply)
    if not ok then return false, label .. ": " .. tostring(err) end
    return true, label .. ": операция выполнена"
end

local function operation(id, ply)
    local save = id:sub(-5) == "_save"
    local load = id:sub(-5) == "_load"
    local base = save and id:sub(1, -6) or (load and id:sub(1, -6) or id)
    local ops = {
        phone = { save = function(p) return GRM.Phone and GRM.Phone.SaveMapEntities(p) end, load = function(p) return GRM.Phone and GRM.Phone.LoadMapEntities(p) end },
        cctv = { save = function() return GRM.CCTV and GRM.CCTV.SavePermanent() end, load = function() return GRM.CCTV and GRM.CCTV.LoadPermanent() end },
        alarm = { save = function() return GRM.Alarm and GRM.Alarm.SavePermanent() end, load = function() return GRM.Alarm and GRM.Alarm.LoadPermanent() end },
        factory = { save = function(p) return GRM.FactoryCycle and GRM.FactoryCycle.SaveMap(p, "admin hub") end, load = function(p) return GRM.FactoryCycle and GRM.FactoryCycle.LoadMap(p) end },
        logistics = { save = function(p) return GRM.Logistics and GRM.Logistics.SaveMap(p) end, load = function(p) return GRM.Logistics and GRM.Logistics.LoadMap(p) end },
        vending = { save = function(p) return GRM.Food and GRM.Food.SaveVendingMachines(p) end, load = function(p) return GRM.Food and GRM.Food.LoadVendingMachines(p, true) end },
        roomtap = { save = function(p) return GRM.RoomTap and GRM.RoomTap.SaveMapEquipment(p) end, load = function(p) return GRM.RoomTap and GRM.RoomTap.LoadMapEquipment(p) end },
        wanted = { save = function() return GRM.Wanted and GRM.Wanted.Save() end, load = function() return GRM.Wanted and GRM.Wanted.Load() end },
        mining = { save = function() return isfunction(GRM_SaveEntities) and GRM_SaveEntities() end, load = function() return isfunction(GRM_LoadEntities) and GRM_LoadEntities() end },
        doors = { save = function() if not GRM.Doors then return false end; GRM.Doors.SaveDoors(); GRM.Doors.SaveCategories(); GRM.Doors.SaveWarrants(); return true end, load = function() if not GRM.Doors then return false end; GRM.Doors.LoadDoors(); GRM.Doors.LoadCategories(); GRM.Doors.LoadWarrants(); return true end },
        arrest = { save = function() return GRM.Arrest and GRM.Arrest.SaveConfig() end, load = function() return GRM.Arrest and GRM.Arrest.LoadConfig() end },
        perm = { save = function() return isfunction(GRM_SaveEntities) and GRM_SaveEntities() end, load = function() return isfunction(GRM_LoadEntities) and GRM_LoadEntities() end }, 
    }
    if not save and not load then return false, "Неизвестная операция" end
    local mod = ops[base]
    if not mod then return false, "Неизвестный модуль: " .. base end
    return call(base .. (save and " save" or " load"), mod[save and "save" or "load"], ply)
end

local function all(ply, mode)
    local ids = { "phone", "cctv", "alarm", "factory", "logistics", "vending", "roomtap", "wanted", "mining", "doors", "arrest", "perm" }
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
