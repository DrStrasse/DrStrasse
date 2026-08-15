-- GRM unified map persistence hub
if not SERVER then return end

GRM = GRM or {}
GRM.PersistenceHub = GRM.PersistenceHub or { Version = "1.4.0" }
GRM.PersistenceHub.Version = "1.4.0"

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

local EQUIPMENT_CLASSES = {
    grm_phone=true,grm_payphone=true,grm_pbx_station=true,grm_phone_wiretap=true,grm_phone_terminal=true,
    grm_cctv_camera=true,grm_cctv_monitor=true,grm_cctv_server=true,
    grm_alarm_sensor=true,grm_alarm_hub=true,grm_alarm_terminal=true,grm_alarm_speaker=true,
    grm_fc_gpu_station=true,grm_fc_components_station=true,grm_fc_weapon_station=true,grm_fc_furnace=true,
    grm_fc_weapon_buyer=true,grm_fc_weapon_locker=true,grm_fc_storage=true,grm_fc_scrap_bin=true,grm_fc_terminal=true,
    grm_logistics_loading=true,grm_logistics_warehouse=true,grm_logistics_armory=true,
    grm_vending_machine=true,grm_food_stove=true,grm_food_fridge=true,grm_food_planter=true,
    grm_roomtap_chip=true,grm_roomtap_server=true,grm_roomtap_terminal=true,
    grm_ore_buyer=true,grm_ore_node=true,
    grm_net_router=true,grm_net_computer=true,grm_net_printer=true,grm_net_socket=true,grm_net_plug=true,
    grm_vendor=true,sent_vehicle_dealer=true,grm_keypad=true,grm_scanner=true,grm_wardrobe=true,grm_board=true,
    grm_bank_terminal=true,grm_bank_vault=true,grm_bank_computer=true,grm_money_press=true,
    grm_money_press_terminal=true,grm_money_printer=true,grm_money_launderer=true,
    grm_doc_computer=true,grm_comp_police=true,grm_comp_military_police=true,grm_comp_security=true,
    grm_comp_military=true,grm_comp_traffic=true,grm_comp_medical=true,grm_comp_education=true,
    gmod_light=true,gmod_lamp=true,gmod_cameraprop=true,
}
local MANIFEST_DIR="grm_equipment"
local function manifestFile()return MANIFEST_DIR.."/"..string.lower(game.GetMap()or"unknown")..".json"end
local function manifestBackup()return manifestFile()..".backup"end
local function vecT(v)return{x=v.x,y=v.y,z=v.z}end
local function angT(a)return{p=a.p,y=a.y,r=a.r}end
local function vec(v)return Vector(tonumber(v and v.x)or 0,tonumber(v and v.y)or 0,tonumber(v and v.z)or 0)end
local function ang(a)return Angle(tonumber(a and a.p)or 0,tonumber(a and a.y)or 0,tonumber(a and a.r)or 0)end
local function entityIdentity(ent)
    for _,pair in ipairs({{"device","GetDeviceID"},{"factory","GetFactoryID"},{"logistics","GetLogisticsID"},{"dealer","GetDealerID"}})do
        local fn=ent[pair[2]]
        if isfunction(fn)then local ok,id=pcall(fn,ent);if ok and tostring(id or"")~=""then return pair[1],tostring(id)end end
    end
    if tostring(ent._grmPermUID or"")~=""then return"perm",tostring(ent._grmPermUID)end
    return"",""
end
local function includeEquipment(ent,class)
    if not IsValid(ent)then return false end
    if class=="grm_phone"or class=="grm_payphone"or class=="grm_pbx_station"or class=="grm_phone_wiretap"or class=="grm_phone_terminal"then if ent.GRMPhoneShopOwned then return false end end
    if class=="grm_roomtap_chip"or class=="grm_roomtap_server"or class=="grm_roomtap_terminal"then if ent.GRMRoomTapShopID then return false end end
    if class=="grm_ore_node"then local os=GRM.OreSpawner;if ent.GRMOreSpawned or(os and os.IsManagedNode and os.IsManagedNode(ent))then return false end end
    if EQUIPMENT_CLASSES[class]then return true end
    return tostring(ent._grmPermUID or"")~=""
end

function GRM.PersistenceHub.SaveManifest()
    if not(ents and file and util and isfunction(util.TableToJSON))then return true,"manifest: test environment"end
    if not file.IsDir(MANIFEST_DIR,"DATA")then file.CreateDir(MANIFEST_DIR)end
    local records={}
    local classes={};for class in pairs(EQUIPMENT_CLASSES)do classes[class]=true end
    -- Дополнительно берём классы живых UID-perm без сохранения всех обычных props.
    if ents.GetAll then for _,ent in ipairs(ents.GetAll())do if IsValid(ent)and ent._grmPermUID then classes[ent:GetClass()]=true end end end
    for class in pairs(classes)do
        for _,ent in ipairs(ents.FindByClass(class))do
            if includeEquipment(ent,class)then
                local p=ent.isSlidingDoor and ent.Sliding_BasePos or ent:GetPos();local a=ent:GetAngles();local kind,id=entityIdentity(ent);local model="";pcall(function()model=tostring(ent:GetModel()or"")end)
                records[#records+1]={class=class,model=model,pos=vecT(p),ang=angT(a),idKind=kind,id=id}
            end
        end
    end
    table.sort(records,function(a,b)local ak=a.class.."|"..a.id.."|"..a.pos.x.."|"..a.pos.y.."|"..a.pos.z;local bk=b.class.."|"..b.id.."|"..b.pos.x.."|"..b.pos.y.."|"..b.pos.z;return ak<bk end)
    local guard=GRM.PersistenceGuard;local ok
    if guard and guard.WriteMirrored then ok=guard.WriteMirrored(manifestFile(),manifestBackup(),{version=1,map=game.GetMap(),records=records},"equipment manifest")
    else local good,raw=pcall(util.TableToJSON,{version=1,map=game.GetMap(),records=records},true);ok=good and isstring(raw);if ok then file.Write(manifestFile(),raw);ok=file.Read(manifestFile(),"DATA")==raw end end
    return ok==true,(ok and"manifest сохранён, ожидается entity: "or"ошибка manifest: ")..#records
end

local function applyIdentity(ent,rec)
    local setters={device="SetDeviceID",factory="SetFactoryID",logistics="SetLogisticsID",dealer="SetDealerID"}
    local setter=setters[rec.idKind or""];if setter and isfunction(ent[setter])and tostring(rec.id or"")~=""then pcall(ent[setter],ent,rec.id)end
    if rec.idKind=="perm"and tostring(rec.id or"")~=""then ent._grmPermUID=rec.id end
end
local function findManifestEntity(rec,claimed)
    local target=vec(rec.pos);local best,bestD
    for _,ent in ipairs(ents.FindByClass(rec.class))do
        if IsValid(ent)and not claimed[ent]then
            local kind,id=entityIdentity(ent)
            if rec.id~=""and kind==rec.idKind and id==rec.id then return ent end
            local p=ent.isSlidingDoor and ent.Sliding_BasePos or ent:GetPos();local dx,dy,dz=p.x-target.x,p.y-target.y,p.z-target.z;local d2=dx*dx+dy*dy+dz*dz
            if d2<=1 and(not bestD or d2<bestD)then best,bestD=ent,d2 end
        end
    end
    return best
end
function GRM.PersistenceHub.ReconcileManifest(reason)
    if not(ents and file and util and isfunction(util.JSONToTable))then return true,"manifest: test environment"end
    local canonical=GRM.PersistenceGuard and GRM.PersistenceGuard.CanonicalBackup and GRM.PersistenceGuard.CanonicalBackup(manifestFile(),manifestBackup())or manifestBackup()
    if not file.Exists(manifestFile(),"DATA")and not file.Exists(manifestBackup(),"DATA")and not file.Exists(canonical,"DATA")then return true,"manifest отсутствует; сначала Сохранить всё"end
    local guard=GRM.PersistenceGuard;local data,source,raw,meta
    if guard and guard.ReadBest then data,source,raw,meta=guard.ReadBest(manifestFile(),{manifestBackup()},"equipment manifest")
    else raw=file.Exists(manifestFile(),"DATA")and(file.Read(manifestFile(),"DATA")or"")or"";local good,t=pcall(util.JSONToTable,raw,false,true);data=good and istable(t)and t or nil end
    if not istable(data)or not istable(data.records)then return true,"manifest отсутствует; сначала Сохранить всё"end
    local claimed,created,healed,failed={},0,0,0
    for _,rec in ipairs(data.records)do
        if istable(rec)and isstring(rec.class)and istable(rec.pos)and istable(rec.ang)then
            local ent=findManifestEntity(rec,claimed);local made=false
            if not IsValid(ent)then ent=ents.Create(rec.class);if IsValid(ent)then if isstring(rec.model)and rec.model~=""then pcall(ent.SetModel,ent,rec.model)end;applyIdentity(ent,rec);ent:SetPos(vec(rec.pos));ent:SetAngles(ang(rec.ang));ent:Spawn();ent:Activate();made=true end end
            if IsValid(ent)then claimed[ent]=true;applyIdentity(ent,rec);ent:SetPos(vec(rec.pos));ent:SetAngles(ang(rec.ang));if ent.SetPermanent and not ent.GRMRoomTapShopID then pcall(ent.SetPermanent,ent,true)end;if GRM.PropProtect and GRM.PropProtect.MarkServerEntity then GRM.PropProtect.MarkServerEntity(ent)end;local ph=ent.GetPhysicsObject and ent:GetPhysicsObject();if IsValid(ph)then ph:EnableMotion(false)end;if made then created=created+1 else healed=healed+1 end else failed=failed+1 end
        else failed=failed+1 end
    end
    local detail=("manifest %s: создано %d, уже стояло %d, ошибок %d"):format(tostring(reason or source),created,healed,failed);print("[GRM Persistence] "..detail)
    return failed==0,detail
end

local function all(ply, mode)
    local ids = { "phone", "cctv", "alarm", "factory", "logistics", "food", "roomtap", "wanted", "mining", "doors", "arrest", "customization", "vendors", "vehicle_dealers", "quests", "electronics", "perm" }
    local done, errors, report = 0, {}, {}
    for _, id in ipairs(ids) do
        local ok, msg = operation(id .. "_" .. mode, ply)
        report[#report + 1] = { id = id, ok = ok == true, text = tostring(msg or "") }
        if ok then done = done + 1 else errors[#errors + 1] = id end
        print(("[GRM Persistence] %s %s: %s"):format(mode, id, tostring(msg)))
    end
    local manifestOK,manifestText
    if mode=="save"then manifestOK,manifestText=GRM.PersistenceHub.SaveManifest()else manifestOK,manifestText=GRM.PersistenceHub.ReconcileManifest("manual load")end
    report[#report+1]={id="equipment_manifest",ok=manifestOK==true,text=tostring(manifestText)}
    if manifestOK then done=done+1 else errors[#errors+1]="equipment_manifest"end
    GRM.PersistenceHub.LastReport = report
    if #errors > 0 then
        return false, ("%s: %d/%d. Ошибки: %s. Подробности — чат и консоль сервера.")
            :format(mode == "save" and "Сохранение" or "Загрузка", done, #report, table.concat(errors, ", ")), report
    end
    return true, (mode == "save" and "Сохранено" or "Загружено") .. ": " .. done .. " модулей на карте " .. game.GetMap(), report
end

local function runAction(id, ply)
    local isSave = id == "all_save" or id:sub(-5) == "_save"
    local guard = GRM.PersistenceGuard
    if isSave and guard and guard.BeginManualSave then guard.BeginManualSave(id) end
    local okCall, ok, msg, report = pcall(function()
        if id == "all_save" or id == "all_load" then
            return all(ply, id:sub(5) == "save" and "save" or "load")
        end
        local result, text = operation(id, ply)
        return result, text, { { id = id, ok = result == true, text = tostring(text or "") } }
    end)
    if isSave and guard and guard.EndManualSave then guard.EndManualSave() end
    if not okCall then return false, "Внутренняя ошибка Persistence Hub: " .. tostring(ok), {} end
    return ok, msg, report
end

local function sendReport(ply, report)
    if not IsValid(ply) then return end
    for _, row in ipairs(report or {}) do
        local line = (row.ok and "[OK] " or "[ОШИБКА] ") .. tostring(row.id) .. ": " .. tostring(row.text)
        if ply.ChatPrint then ply:ChatPrint("[GRM Save] " .. line) end
    end
end

net.Receive("GRM_Persistence_Open", function(_, ply)
    if IsValid(ply) and ply:IsSuperAdmin() then
        net.Start("GRM_Persistence_Open") net.Send(ply)
    end
end)

net.Receive("GRM_Persistence_Action", function(_, ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then return end
    local id = tostring(net.ReadString() or "")
    local ok, msg, report = runAction(id, ply)
    sendReport(ply, report)
    notify(ply, ok, msg)
end)

concommand.Add("grm_persistence_status", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    print("[GRM Persistence] ===== LAST REPORT =====")
    for _, row in ipairs(GRM.PersistenceHub.LastReport or {}) do
        print((row.ok and "[OK] " or "[FAIL] ") .. tostring(row.id) .. ": " .. tostring(row.text))
    end
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

-- Manifest is the final safety net after module-specific boot/cleanup loaders.
hook.Add("InitPostEntity","GRM_EquipmentManifest_Boot",function()timer.Simple(8,function()GRM.PersistenceHub.ReconcileManifest("boot 8s")end);timer.Simple(20,function()GRM.PersistenceHub.ReconcileManifest("boot 20s")end)end)
hook.Add("PostCleanupMap","GRM_EquipmentManifest_Cleanup",function()timer.Simple(3,function()GRM.PersistenceHub.ReconcileManifest("cleanup")end)end)
timer.Create("GRM_EquipmentManifest_Watchdog",30,0,function()GRM.PersistenceHub.ReconcileManifest("watchdog")end)
