--[[--------------------------------------------------------------------
    GRM Mining Persistence v1.1.0

    Единый надёжный контур шахты:
      • grm_ore_buyer — постоянный скупщик;
      • grm_ore_node  — только вручную сохранённые узлы;
      • автоматические узлы OreSpawner не дублируются: сохраняются их точки.

    Совместимые команды: !saveentities / !loadentities,
    grm_saveentities / grm_loadentities и старые глобальные API.
----------------------------------------------------------------------]]
if CLIENT then return end

GRM = GRM or {}
GRM.MiningPersistence = GRM.MiningPersistence or {}
local MP = GRM.MiningPersistence
MP.Version = "1.1.0"
MP.LoadBlocked = MP.LoadBlocked == true

local SAVE_DIR = "grm_saves"
local SAVE_FILE = SAVE_DIR .. "/" .. string.lower(game.GetMap() or "unknown") .. ".json"
local BACKUP_FILE = SAVE_FILE .. ".backup"
local CLASSES = { grm_ore_buyer = true, grm_ore_node = true }
local State = MP.State or { loading = false }
MP.State = State

local function ensureDirectory()
    if not file.Exists(SAVE_DIR, "DATA") then file.CreateDir(SAVE_DIR) end
end
local function vtab(v) return { x = v.x, y = v.y, z = v.z } end
local function atab(a) return { p = a.p, y = a.y, r = a.r } end
local function vec(t) return Vector(tonumber(t and (t.x or t[1])) or 0, tonumber(t and (t.y or t[2])) or 0, tonumber(t and (t.z or t[3])) or 0) end
local function ang(t) return Angle(tonumber(t and (t.p or t[1])) or 0, tonumber(t and (t.y or t[2])) or 0, tonumber(t and (t.r or t[3])) or 0) end
local function jsonT(raw)
    local ok, data = pcall(util.JSONToTable, raw or "", false, true)
    return ok and istable(data) and data or nil
end
local uidCounter = 0
local function newUID()
    uidCounter = uidCounter + 1
    return ("mine_%x_%x_%x"):format(os.time(), uidCounter, math.random(0, 0xFFFF))
end

local function isAutoOre(ent)
    if not IsValid(ent) or ent:GetClass() ~= "grm_ore_node" then return false end
    local spawner = GRM.OreSpawner
    return ent.GRMOreSpawned == true or (spawner and spawner.IsManagedNode and spawner.IsManagedNode(ent) == true)
end
local function isPersistentEntity(ent)
    return IsValid(ent) and CLASSES[ent:GetClass()] == true and not isAutoOre(ent)
end

local function validateRecords(records)
    if not istable(records) then return false, "база шахты не является таблицей" end
    for key in pairs(records) do
        if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false, "база шахты не является массивом" end
    end
    local seen = {}
    for index, record in ipairs(records) do
        if not istable(record) or not CLASSES[tostring(record.class or "")]
            or not istable(record.pos) or not istable(record.ang) then
            return false, "некорректная запись шахты #" .. index
        end
        local uid = tostring(record.uid or "")
        if uid ~= "" then
            if seen[uid] then return false, "повторяющийся UID шахты: " .. uid end
            seen[uid] = true
        end
    end
    return true
end

local function readRecords()
    local guard, records, source, raw, meta = GRM.PersistenceGuard
    if guard and guard.ReadBest then
        records, source, raw, meta = guard.ReadBest(SAVE_FILE, { BACKUP_FILE }, "mining equipment")
    else
        raw = file.Exists(SAVE_FILE, "DATA") and (file.Read(SAVE_FILE, "DATA") or "") or ""
        records = jsonT(raw); source = records and SAVE_FILE or nil; meta = { hadAny = raw ~= "" }
    end
    if not istable(records) then
        MP.LoadBlocked = meta and meta.hadAny == true
        if MP.LoadBlocked then return nil, nil, "primary/backup шахты повреждены" end
        return {}, "new", nil
    end
    local valid, why = validateRecords(records)
    if not valid then MP.LoadBlocked = true return nil, nil, why end
    if guard and guard.Materialize and raw and not guard.Materialize(SAVE_FILE, BACKUP_FILE, raw, "mining equipment") then
        MP.LoadBlocked = true
        return nil, nil, "не удалось восстановить primary/backup шахты"
    end
    MP.LoadBlocked = false
    return records, source, nil
end

local function writeRecords(records)
    if MP.LoadBlocked then
        print("[GRM Mining][!] SAVE BLOCKED после ошибки primary/backup")
        return false
    end
    ensureDirectory()
    local guard = GRM.PersistenceGuard
    if guard and guard.WriteMirrored then return guard.WriteMirrored(SAVE_FILE, BACKUP_FILE, records, "mining equipment") end
    local okJ, raw = pcall(util.TableToJSON, records, true)
    if not okJ or not isstring(raw) or raw == "" or not jsonT(raw) then return false end
    file.Write(SAVE_FILE, raw); file.Write(BACKUP_FILE, raw)
    return file.Read(SAVE_FILE, "DATA") == raw and file.Read(BACKUP_FILE, "DATA") == raw
end

local function entityRecord(ent)
    local ph = ent:GetPhysicsObject()
    ent._grmMiningUID = tostring(ent._grmMiningUID or newUID())
    local record = {
        uid = ent._grmMiningUID,
        class = ent:GetClass(), model = tostring(ent:GetModel() or ""),
        pos = vtab(ent:GetPos()), ang = atab(ent:GetAngles()),
        frozen = IsValid(ph) and not ph:IsMotionEnabled() or false,
    }
    if ent:GetClass() == "grm_ore_node" then record.oreType = tostring(ent.OreType or "") end
    return record
end

function MP.SaveEntities(ply)
    if IsValid(ply) and not ply:IsAdmin() then return false, "нет прав", 0 end
    if State.loading then return false, "загрузка шахты ещё выполняется", 0 end
    if MP.LoadBlocked then return false, "сохранение шахты заблокировано после ошибки загрузки", 0 end
    if GRM.OreSpawner and GRM.OreSpawner.MarkManagedNodes then GRM.OreSpawner.MarkManagedNodes() end

    local records, live = {}, {}
    for class in pairs(CLASSES) do
        for _, ent in ipairs(ents.FindByClass(class)) do
            if isPersistentEntity(ent) then records[#records + 1] = entityRecord(ent); live[#live + 1] = ent end
        end
    end
    table.sort(records, function(a, b) return tostring(a.uid) < tostring(b.uid) end)
    local ok = writeRecords(records)
    if ok then
        for _, ent in ipairs(live) do
            if IsValid(ent) then
                ent._grmMiningPersistent = true
                if GRM.PropProtect and GRM.PropProtect.MarkServerEntity then GRM.PropProtect.MarkServerEntity(ent) end
            end
        end
    end
    local detail = (ok and "сохранено" or "ошибка сохранения") .. " оборудования шахты: " .. #records
    print("[GRM Mining] " .. detail)
    return ok == true, detail, #records
end

local function stableModel(ent)
    local model = ""
    pcall(function() model = tostring(ent:GetModel() or "") end)
    return string.lower(model)
end
local function findLive(record, claimed)
    local wantUID, wantModel, target = tostring(record.uid or ""), string.lower(tostring(record.model or "")), vec(record.pos)
    local fallback, bestD
    for _, ent in ipairs(ents.FindByClass(record.class)) do
        if IsValid(ent) and not claimed[ent] and not isAutoOre(ent) then
            if wantUID ~= "" and ent._grmMiningUID == wantUID then return ent end
            if ent._grmMiningUID == nil and (wantModel == "" or stableModel(ent) == wantModel) then
                local p = ent:GetPos(); local dx, dy, dz = p.x - target.x, p.y - target.y, p.z - target.z
                local d2 = dx * dx + dy * dy + dz * dz
                if d2 <= 0.25 * 0.25 and (not bestD or d2 < bestD) then fallback, bestD = ent, d2 end
            end
        end
    end
    return fallback
end

function MP.LoadEntities(ply)
    if IsValid(ply) and not ply:IsAdmin() then return false, "нет прав", 0 end
    local records, source, why = readRecords()
    if not records then
        print("[GRM Mining] LOAD skipped: " .. tostring(why) .. "; live entities preserved")
        return false, why, 0
    end
    if source == "new" then return true, "оборудование шахты: новый пустой контур", 0 end

    State.loading = true
    if GRM.OreSpawner and GRM.OreSpawner.MarkManagedNodes then GRM.OreSpawner.MarkManagedNodes() end
    local claimed, created, healed, failed, migrated = {}, 0, 0, 0, 0
    local clean = {}
    for index, record in ipairs(records) do
        local target = vec(record.pos)
        local oldAutoNode = record.class == "grm_ore_node" and GRM.OreSpawner
            and GRM.OreSpawner.IsSpawnPointPosition and GRM.OreSpawner.IsSpawnPointPosition(target, 4)
        if oldAutoNode then
            migrated = migrated + 1
        else
            clean[#clean + 1] = record
            local ent = findLive(record, claimed)
            local wasCreated = false
            if not IsValid(ent) then
                ent = ents.Create(record.class)
                if IsValid(ent) then
                    ent._grmMiningUID = tostring(record.uid or newUID())
                    if record.class == "grm_ore_node" and isstring(record.oreType) and record.oreType ~= "" then ent.OreType = record.oreType end
                    if isstring(record.model) and record.model ~= "" then ent:SetModel(record.model) end
                    ent:SetPos(target); ent:SetAngles(ang(record.ang)); ent:Spawn(); ent:Activate()
                    wasCreated = true
                end
            else
                ent:SetPos(target); ent:SetAngles(ang(record.ang))
            end
            if IsValid(ent) then
                ent._grmMiningUID = tostring(record.uid or ent._grmMiningUID or newUID())
                ent._grmMiningPersistent = true
                if record.class == "grm_ore_node" and isstring(record.oreType) and record.oreType ~= "" and ent.SetOreType then ent:SetOreType(record.oreType) end
                if GRM.PropProtect and GRM.PropProtect.MarkServerEntity then GRM.PropProtect.MarkServerEntity(ent) end
                claimed[ent] = true
                local ph = ent:GetPhysicsObject()
                if IsValid(ph) then ph:EnableMotion(record.frozen == false); if record.frozen ~= false then ph:Sleep() end end
                if wasCreated then created = created + 1 else healed = healed + 1 end
            else
                failed = failed + 1
                ErrorNoHalt("[GRM Mining] Не удалось создать entity #" .. index .. ": " .. tostring(record.class) .. "\n")
            end
        end
    end

    -- Удаляем только старые entity этого контура, не OreSpawner и не чужие объекты.
    for class in pairs(CLASSES) do
        for _, ent in ipairs(ents.FindByClass(class)) do
            if IsValid(ent) and ent._grmMiningPersistent and not claimed[ent] and not isAutoOre(ent) then ent:Remove() end
        end
    end
    State.loading = false
    MP.LoadBlocked = failed > 0
    if migrated > 0 and failed == 0 then writeRecords(clean) end
    local detail = ("шахта: создано %d, уже стояло %d, ошибок %d, мигрировано auto-node %d")
        :format(created, healed, failed, migrated)
    print("[GRM Mining] LOAD source=" .. tostring(source) .. " " .. detail)
    return failed == 0, detail, created + healed
end

function MP.ClearLive()
    State.loading = true
    for class in pairs(CLASSES) do
        for _, ent in ipairs(ents.FindByClass(class)) do if isPersistentEntity(ent) then ent:Remove() end end
    end
    State.loading = false
end

function MP.SaveAll(ply)
    local spawner = GRM.OreSpawner
    if not (spawner and spawner.SavePoints) then return false, "OreSpawner API не загружен" end
    local pointsOK, pointsDetail = spawner.SavePoints()
    if not pointsOK then return false, tostring(pointsDetail) end
    local entitiesOK, entitiesDetail = MP.SaveEntities(ply)
    return entitiesOK == true, tostring(entitiesDetail) .. "; " .. tostring(pointsDetail)
end
function MP.LoadAll(ply)
    local spawner = GRM.OreSpawner
    if not (spawner and spawner.LoadPoints) then return false, "OreSpawner API не загружен" end
    local pointsOK, pointsDetail = spawner.LoadPoints()
    if not pointsOK then return false, tostring(pointsDetail) end
    local entitiesOK, entitiesDetail = MP.LoadEntities(ply)
    if spawner.Refill then spawner.Refill() end
    return entitiesOK == true, tostring(entitiesDetail) .. "; " .. tostring(pointsDetail)
end

-- Старые глобальные API оставлены для команд и сторонних модулей.
function GRM_SaveEntities()
    local _, _, count = MP.SaveEntities(nil)
    return count or 0
end
function GRM_LoadEntities()
    local _, _, count = MP.LoadEntities(nil)
    return count or 0
end
function GRM_ClearSavedEntities() MP.ClearLive() end

hook.Add("InitPostEntity", "GRM_Saver_AutoLoad", function()
    timer.Simple(5, function() MP.LoadAll(nil) end)
end)
hook.Add("PostCleanupMap", "GRM_Saver_PostCleanup", function()
    timer.Simple(1.5, function() MP.LoadAll(nil) end)
end)
timer.Create("GRM_MiningPersistence_Watchdog", 30, 0, function() MP.LoadAll(nil) end)

local function runCommand(ply, save)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local ok, detail = save and MP.SaveAll(ply) or MP.LoadAll(ply)
    if IsValid(ply) then ply:ChatPrint("[GRM Mining] " .. tostring(detail)) end
    return ok
end
hook.Add("PlayerSay", "GRM_Saver_Commands", function(ply, text)
    local command = string.lower(string.Trim(text or ""))
    if command == "!saveentities" or command == "/saveentities" then runCommand(ply, true) return "" end
    if command == "!loadentities" or command == "/loadentities" then runCommand(ply, false) return "" end
end)
concommand.Add("grm_saveentities", function(ply) runCommand(ply, true) end)
concommand.Add("grm_loadentities", function(ply) runCommand(ply, false) end)

print("[GRM Mining] persistence v" .. MP.Version .. " loaded for map " .. game.GetMap())
