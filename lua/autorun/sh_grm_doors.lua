--[[--------------------------------------------------------------------
    GRM Doors System v3.0.0 (Код 64 — ПЕРЕПИСАНО С НУЛЯ)

    Слои допуска — CONCEPT_DOORS_V3.md:
      0 SuperAdmin  — всё, включая назначение владельца карты;
      1 проход      — незапертую дверь проходит любой;
      2 ключ        — запертую: владелец / совладелец / фракция /
                      категория / ACL / ордер+CanWarrant;
      3 хозяйство   — имя, совладельцы, ACL: владелец-игрок или SuperAdmin;
      4 покупка     — ничья и ownable;
      5 карта       — фракция/категория/приватизация: только SuperAdmin;
      6 сила        — таран: CanForceDoor или ордер (не ключ на E).

    ownable=false = «не продаётся», НЕ «всем можно».
    AM.CanManage = /door_access, не вкладка R-меню.

    Идентичность: MapCreationID + AABB-склейка дублей одного полотна.
    Персист: только изменённые записи, массив, version=3,
             jsonT(..., false, true). CharacterKey = SteamID64:charN.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Doors = GRM.Doors or {}
local D = GRM.Doors
D.Version = "3.0.0"

D.Config = D.Config or {
    UseDistance = 180,
    MaxOwnersPerDoor = 12,
    DefaultRentSeconds = 7 * 24 * 3600,
    RentPrice = 5000,
    PermPriceMultiplier = 3,
    SuperAdminBypass = true,
    HUDDistance = 220,
    DuplicateCenterDistance = 64,
    DuplicateXYOverlap = 0.55,
    DuplicateZOverlap = 0.72,
    LockSyncInterval = 2.0,
    ActCooldown = 0.4,
    DoorClasses = {
        prop_door_rotating = true,
        func_door = true,
        func_door_rotating = true,
    },
}

local NET_OPEN = "GRM_Doors_Open"
local NET_ACT  = "GRM_Doors_Act"
local NET_INFO = "GRM_Doors_Info"

-----------------------------------------------------------------------
-- SHARED
-----------------------------------------------------------------------
local function mapName()
    return string.lower(game.GetMap() or "unknown")
end

function D.CanAdminDoors(ply)
    return IsValid(ply) and ply.IsPlayer and ply:IsPlayer() and ply:IsSuperAdmin() == true
end

function D.IsDoor(ent)
    if not IsValid(ent) then return false end
    local cls = ent:GetClass()
    local cfg = D.Config and D.Config.DoorClasses or {}
    if cfg[cls] then return true end
    return cls == "prop_door_rotating" or cls == "func_door" or cls == "func_door_rotating"
end

local function baseDoorID(ent)
    if not IsValid(ent) then return nil end
    local map = mapName()
    local mcid = ent.MapCreationID and ent:MapCreationID()
    if mcid and mcid > 0 then return string.format("%s_m%d", map, mcid) end
    local pos = ent:GetPos()
    return string.format("%s_%s_%.0f_%.0f_%.0f", map, ent:GetClass(),
        math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5))
end

local function aabbOverlapRatio(a, b)
    if not IsValid(a) or not IsValid(b) or not a.WorldSpaceAABB or not b.WorldSpaceAABB then return 0, 0 end
    local amin, amax = a:WorldSpaceAABB()
    local bmin, bmax = b:WorldSpaceAABB()
    if not amin or not amax or not bmin or not bmax then return 0, 0 end
    local ox = math.max(0, math.min(amax.x, bmax.x) - math.max(amin.x, bmin.x))
    local oy = math.max(0, math.min(amax.y, bmax.y) - math.max(amin.y, bmin.y))
    local oz = math.max(0, math.min(amax.z, bmax.z) - math.max(amin.z, bmin.z))
    local areaA = math.max(1, (amax.x - amin.x) * (amax.y - amin.y))
    local areaB = math.max(1, (bmax.x - bmin.x) * (bmax.y - bmin.y))
    local heightA = math.max(1, amax.z - amin.z)
    local heightB = math.max(1, bmax.z - bmin.z)
    return (ox * oy) / math.min(areaA, areaB), oz / math.min(heightA, heightB)
end

function D.IsSamePhysicalDoor(a, b)
    if not IsValid(a) or not IsValid(b) or a == b or not D.IsDoor(a) or not D.IsDoor(b) then return false end
    if a:GetParent() == b or b:GetParent() == a then return true end
    local centerA = a.WorldSpaceCenter and a:WorldSpaceCenter() or a:GetPos()
    local centerB = b.WorldSpaceCenter and b:WorldSpaceCenter() or b:GetPos()
    local maxCenter = (D.Config and D.Config.DuplicateCenterDistance) or 64
    if centerA:DistToSqr(centerB) > maxCenter * maxCenter then return false end
    local xy, z = aabbOverlapRatio(a, b)
    return xy >= ((D.Config and D.Config.DuplicateXYOverlap) or 0.55)
        and z >= ((D.Config and D.Config.DuplicateZOverlap) or 0.72)
end

function D.RebuildDoorIdentityCache()
    if D._buildingDoorIdentity then return end
    D._buildingDoorIdentity = true
    local doors = {}
    for _, ent in ipairs(ents.GetAll()) do
        if IsValid(ent) and D.IsDoor(ent) then doors[#doors + 1] = ent end
    end
    local parent = {}
    local function root(i)
        if parent[i] ~= i then parent[i] = root(parent[i]) end
        return parent[i]
    end
    local function unite(a, b)
        local ra, rb = root(a), root(b)
        if ra ~= rb then parent[rb] = ra end
    end
    for i = 1, #doors do parent[i] = i end
    for i = 1, #doors do
        for j = i + 1, #doors do
            if D.IsSamePhysicalDoor(doors[i], doors[j]) then unite(i, j) end
        end
    end
    local ids = {}
    for i, ent in ipairs(doors) do
        local r = root(i)
        local id = baseDoorID(ent)
        if id and (not ids[r] or id < ids[r]) then ids[r] = id end
    end
    D._canonicalDoorIDs, D._equivalentDoors = {}, {}
    for i, ent in ipairs(doors) do
        local id = ids[root(i)] or baseDoorID(ent)
        D._canonicalDoorIDs[ent] = id
        D._equivalentDoors[id] = D._equivalentDoors[id] or {}
        D._equivalentDoors[id][#D._equivalentDoors[id] + 1] = ent
    end
    D._buildingDoorIdentity = nil
end

function D.GetDoorID(ent)
    if not IsValid(ent) or not D.IsDoor(ent) then return nil end
    if not D._canonicalDoorIDs or not D._canonicalDoorIDs[ent] then D.RebuildDoorIdentityCache() end
    return D._canonicalDoorIDs and D._canonicalDoorIDs[ent] or baseDoorID(ent)
end

function D.GetEquivalentDoors(ent)
    local id = D.GetDoorID(ent)
    local list = id and D._equivalentDoors and D._equivalentDoors[id] or nil
    if istable(list) and #list > 0 then return list end
    return IsValid(ent) and { ent } or {}
end

function D.GetPartnerDoor(ent)
    if not IsValid(ent) or not D.IsDoor(ent) then return nil end
    local parent = ent:GetParent()
    if IsValid(parent) and D.IsDoor(parent) then return parent end
end

function D.IsDoorLocked(ent)
    if not IsValid(ent) then return false end
    if ent:GetNWBool("GRM_DoorLocked", false) == true then return true end
    if SERVER and ent.GetInternalVariable then
        local b = ent:GetInternalVariable("m_bLocked")
        if b == true or b == 1 then return true end
    end
    return false
end

local function listHas(arr, value)
    if not istable(arr) or value == nil or value == "" then return false end
    for _, v in ipairs(arr) do if v == value then return true end end
    return false
end

local function recordPriority(rec)
    if not istable(rec) then return -1 end
    local score = 0
    if rec.owner_type and rec.owner_type ~= "none" then score = score + 100 end
    if tostring(rec.title or "") ~= "" then score = score + 10 end
    if rec.locked == true then score = score + 3 end
    if rec.ownable == false then score = score + 1 end
    return score
end

--- Чистая матрица допуска. actor = { superadmin, key, faction, role, canWarrant, hasWarrantOnOwner, canForce, categoryHas }
function D.EvaluateAccess(rec, actor)
    rec = istable(rec) and rec or { owner_type = "none", ownable = true }
    actor = istable(actor) and actor or {}
    local owned = rec.owner_type and rec.owner_type ~= "none"
    local super = actor.superadmin == true
    local key = tostring(actor.key or "")
    local fac = actor.faction
    local role = actor.role

    local isOwner = rec.owner_type == "player" and rec.owner_key == key and key ~= ""
    local isCo = false
    if istable(rec.co_owners) then
        for _, s in ipairs(rec.co_owners) do if s == key then isCo = true break end end
    end
    local isFac = rec.owner_type == "faction" and fac and rec.owner_faction == fac
    local isCat = rec.owner_type == "category" and fac and actor.categoryHas == true
    local acl = (fac and listHas(rec.factions, fac))
        or (fac and role and listHas(rec.roles, fac .. "|" .. tostring(role)))
        or (actor.aclCategory == true)
    local warrant = rec.owner_type == "player" and (rec.owner_key or "") ~= ""
        and actor.hasWarrantOnOwner == true and actor.canWarrant == true
    local hasKey = super or isOwner or isCo or isFac or isCat or acl or warrant

    return {
        walk_unlocked = true,
        walk_locked = hasKey,
        lock = hasKey,
        own = super or isOwner,
        buy = (not owned) and rec.ownable ~= false,
        admin = super,
        force = super or actor.canForce == true or warrant,
        is_owner = isOwner,
        has_key = hasKey,
    }
end

hook.Add("InitPostEntity", "GRM_Doors_BuildIdentityCache", function()
    timer.Simple(0, D.RebuildDoorIdentityCache)
end)
hook.Add("PostCleanupMap", "GRM_Doors_RebuildIdentityCache", function()
    timer.Simple(0.2, D.RebuildDoorIdentityCache)
end)

-----------------------------------------------------------------------
-- SERVER
-----------------------------------------------------------------------
if SERVER then
    util.AddNetworkString(NET_OPEN)
    util.AddNetworkString(NET_ACT)
    util.AddNetworkString(NET_INFO)
    util.AddNetworkString("GRM_Doors_Admin")
    util.AddNetworkString("GRM_Doors_AdminAct")

    if GRM._doorsCoreActive then
        print("[GRM Doors] Вторая копия sh_grm_doors.lua пропущена")
        return
    end
    GRM._doorsCoreActive = true

    local DATA_DIR = "grm_doors"
    D.Data = D.Data or { doors = {}, categories = {}, warrants = {} }

    local function jsonT(txt)
        local ok, t = pcall(util.JSONToTable, txt, false, true)
        return (ok and istable(t)) and t or nil
    end

    local function ensureDir()
        if not file.IsDir(DATA_DIR, "DATA") then file.CreateDir(DATA_DIR) end
    end

    local function notify(ply, msg, r, g, b)
        if not IsValid(ply) then return end
        if GRM.Notify then GRM.Notify(ply, msg, r or 100, g or 220, b or 100) return end
        net.Start(NET_INFO) net.WriteString(tostring(msg or "")) net.Send(ply)
    end

    local function charKey(v)
        if IsValid(v) and v.IsPlayer and v:IsPlayer() then
            if GRM.Identity and GRM.Identity.CharacterKey then return GRM.Identity.CharacterKey(v) end
            return tostring(v:SteamID64() or "") .. ":char1"
        end
        local s = tostring(v or "")
        if s:match(":char[1-3]$") then return s end
        if s:match("^%d+$") then return s .. ":char1" end
        return s
    end

    local function utf8cut(s, n)
        if GRM.Utf8Sub then return GRM.Utf8Sub(s, n) end
        return string.sub(tostring(s or ""), 1, n)
    end

    local function toArray(src)
        local out, seen = {}, {}
        if not istable(src) then return out end
        if #src > 0 then
            for _, v in ipairs(src) do
                local s = tostring(v or "")
                if s ~= "" and not seen[s] then seen[s] = true out[#out + 1] = s end
            end
            return out
        end
        for k, v in pairs(src) do
            local s
            if v == true then s = tostring(k)
            elseif isstring(v) then s = v
            elseif isstring(k) then s = k end
            if s and s ~= "" and not seen[s] then seen[s] = true out[#out + 1] = s end
        end
        return out
    end

    local function nickOf(key)
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and (charKey(p) == key or p:SteamID64() == key or p:SteamID() == key) then
                return p:Nick()
            end
        end
        return key
    end

    local function doorsFile() ensureDir() return DATA_DIR .. "/" .. mapName() .. ".json" end
    local function catFile() ensureDir() return DATA_DIR .. "/categories.json" end
    local function warFile() ensureDir() return DATA_DIR .. "/warrants.json" end

    local function writeJSON(path, data)
        local ok, txt = pcall(util.TableToJSON, data, true)
        if not (ok and isstring(txt)) then return false end
        file.Write(path, txt)
        return file.Read(path, "DATA") == txt
    end

    local function normalizeRec(raw)
        if not istable(raw) then return nil end
        local id = tostring(raw.id or "")
        if id == "" then return nil end
        local ot = raw.owner_type
        if ot ~= "player" and ot ~= "faction" and ot ~= "category" then ot = "none" end
        return {
            id = id,
            title = utf8cut(tostring(raw.title or ""), 64),
            owner_type = ot,
            owner_key = tostring(raw.owner_key or raw.owner_sid or ""),
            owner_nick = utf8cut(tostring(raw.owner_nick or ""), 64),
            owner_faction = tostring(raw.owner_faction or ""),
            owner_category = tostring(raw.owner_category or ""),
            co_owners = toArray(raw.co_owners),
            factions = toArray(raw.factions),
            roles = toArray(raw.roles),
            categories = toArray(raw.categories),
            rent_until = tonumber(raw.rent_until) or 0,
            rent_price = math.max(0, math.floor(tonumber(raw.rent_price) or (D.Config.RentPrice or 5000))),
            locked = raw.locked == true,
            ownable = raw.ownable ~= false,
        }
    end

    local function defaultRec(id, ent)
        local locked = false
        if IsValid(ent) and ent.GetInternalVariable then
            local b = ent:GetInternalVariable("m_bLocked")
            locked = (b == true or b == 1)
        end
        return {
            id = id, title = "", owner_type = "none", owner_key = "", owner_nick = "",
            owner_faction = "", owner_category = "", co_owners = {}, factions = {},
            roles = {}, categories = {}, rent_until = 0,
            rent_price = tonumber(D.Config.RentPrice) or 5000,
            locked = locked, ownable = true, _ephemeral = true,
        }
    end

    local function recDirty(rec)
        if not istable(rec) then return false end
        if rec.owner_type and rec.owner_type ~= "none" then return true end
        if tostring(rec.title or "") ~= "" then return true end
        if rec.ownable == false then return true end
        if rec.locked == true then return true end
        if rec.rent_until and rec.rent_until > 0 then return true end
        if rec.rent_price and rec.rent_price ~= (D.Config.RentPrice or 5000) then return true end
        if #(rec.co_owners or {}) > 0 or #(rec.factions or {}) > 0
            or #(rec.roles or {}) > 0 or #(rec.categories or {}) > 0 then return true end
        return false
    end

    function D.SaveDoors()
        local arr = {}
        for id, rec in pairs(D.Data.doors or {}) do
            if istable(rec) and recDirty(rec) then
                rec.id = id
                rec._ephemeral = nil
                arr[#arr + 1] = rec
            end
        end
        table.sort(arr, function(a, b) return tostring(a.id) < tostring(b.id) end)
        return writeJSON(doorsFile(), { version = 3, doors = arr })
    end

    function D.LoadDoors()
        D.Data.doors = {}
        local path = doorsFile()
        if not file.Exists(path, "DATA") then return true end
        local raw = file.Read(path, "DATA") or ""
        local t = jsonT(raw)
        if not t then
            local bak = path .. ".corrupt." .. os.time()
            file.Write(bak, raw)
            ErrorNoHalt("[GRM Doors] " .. path .. " повреждён, копия: " .. bak .. "\n")
            return false
        end
        local list = istable(t.doors) and t.doors or (istable(t[1]) and t or {})
        for _, rawRec in ipairs(list) do
            local rec = normalizeRec(rawRec)
            if rec and rec.id:sub(1, 5) ~= "pair_" then
                D.Data.doors[rec.id] = rec
            end
        end
        timer.Simple(1, function()
            for _, ent in ipairs(ents.GetAll()) do
                if IsValid(ent) and D.IsDoor(ent) then
                    local rec = select(1, D.GetRecord(ent))
                    if rec and not rec._ephemeral then
                        D.ApplyRecordVisual(ent, rec)
                    else
                        local eng = ent.GetInternalVariable and (ent:GetInternalVariable("m_bLocked") == true or ent:GetInternalVariable("m_bLocked") == 1)
                        D.SyncLockNW(ent, eng)
                    end
                end
            end
        end)
        print("[GRM Doors] Загружено дверей на карте " .. mapName() .. ": " .. table.Count(D.Data.doors))
        return true
    end

    function D.SaveCategories()
        local arr = {}
        for id, c in pairs(D.Data.categories or {}) do
            if istable(c) then
                arr[#arr + 1] = { id = id, name = c.name or id, factions = toArray(c.factions) }
            end
        end
        table.sort(arr, function(a, b) return tostring(a.id) < tostring(b.id) end)
        return writeJSON(catFile(), { version = 3, categories = arr })
    end

    function D.LoadCategories()
        D.Data.categories = {}
        if not file.Exists(catFile(), "DATA") then
            D.Data.categories = {
                police = { id = "police", name = "Полиция и Силовики", factions = {} },
                med    = { id = "med",    name = "Медицинская служба", factions = {} },
                gov    = { id = "gov",    name = "Правительство / Мэрия", factions = {} },
            }
            D.SaveCategories()
            return true
        end
        local t = jsonT(file.Read(catFile(), "DATA") or "")
        if not istable(t) then return false end
        local list = istable(t.categories) and t.categories or (istable(t[1]) and t or nil)
        if list then
            for _, c in ipairs(list) do
                if istable(c) and isstring(c.id) then
                    D.Data.categories[c.id] = { id = c.id, name = c.name or c.id, factions = toArray(c.factions) }
                end
            end
        else
            for id, c in pairs(t) do
                if istable(c) and id ~= "version" then
                    D.Data.categories[tostring(c.id or id)] = {
                        id = tostring(c.id or id), name = c.name or id, factions = toArray(c.factions),
                    }
                end
            end
        end
        return true
    end

    function D.SaveWarrants()
        local arr = {}
        for sid, w in pairs(D.Data.warrants or {}) do
            if istable(w) then w.sid = sid arr[#arr + 1] = w end
        end
        return writeJSON(warFile(), { version = 3, warrants = arr })
    end

    function D.LoadWarrants()
        D.Data.warrants = {}
        if not file.Exists(warFile(), "DATA") then return true end
        local t = jsonT(file.Read(warFile(), "DATA") or "")
        if not istable(t) then return false end
        local list = istable(t.warrants) and t.warrants or (istable(t[1]) and t or {})
        for _, w in ipairs(list) do
            if istable(w) and isstring(w.sid) then D.Data.warrants[w.sid] = w end
        end
        return true
    end

    function D.CreateCategory(id, name)
        id = string.lower(tostring(id or "")):gsub("[^%w_%-]", "")
        if id == "" or #id > 32 then return nil, "Некорректный ID категории" end
        D.Data.categories = D.Data.categories or {}
        if D.Data.categories[id] then return nil, "Категория уже существует" end
        name = utf8cut(tostring(name or ""), 48)
        if name == "" then name = id end
        local c = { id = id, name = name, factions = {} }
        D.Data.categories[id] = c
        D.SaveCategories()
        return c
    end

    function D.RenameCategory(id, name)
        local c = D.Data.categories and D.Data.categories[tostring(id or "")]
        if not istable(c) then return nil, "Категория не найдена" end
        name = utf8cut(tostring(name or ""), 48)
        if name == "" then return nil, "Пустое название" end
        c.name = name
        D.SaveCategories()
        return true
    end

    function D.DeleteCategory(id)
        id = tostring(id or "")
        if not (D.Data.categories and D.Data.categories[id]) then return nil, "Категория не найдена" end
        D.Data.categories[id] = nil
        for _, rec in pairs(D.Data.doors or {}) do
            if istable(rec) then
                if rec.owner_type == "category" and rec.owner_category == id then
                    rec.owner_type, rec.owner_category = "none", ""
                end
                if istable(rec.categories) then
                    local nextCats = {}
                    for _, cid in ipairs(rec.categories) do if cid ~= id then nextCats[#nextCats + 1] = cid end end
                    rec.categories = nextCats
                end
            end
        end
        D.SaveDoors()
        D.SaveCategories()
        return true
    end

    function D.CategorySetFaction(id, factionName, on)
        local c = D.Data.categories and D.Data.categories[tostring(id or "")]
        if not istable(c) then return nil, "Категория не найдена" end
        factionName = tostring(factionName or "")
        if factionName == "" then return nil, "Не указана фракция" end
        c.factions = toArray(c.factions)
        local nextF = {}
        for _, fn in ipairs(c.factions) do if fn ~= factionName then nextF[#nextF + 1] = fn end end
        if on then nextF[#nextF + 1] = factionName end
        c.factions = nextF
        D.SaveCategories()
        return true
    end

    local function factionInCategory(factionName, catId)
        local cat = D.Data.categories and D.Data.categories[catId]
        if not istable(cat) then return false end
        return listHas(toArray(cat.factions), factionName)
    end

    local function playerFactionInfo(ply)
        if not IsValid(ply) or not istable(Factions) then return nil, nil, nil end
        if not (GRM.Identity and GRM.Identity.FactionMember) then return nil, nil, nil end
        for name, f in pairs(Factions) do
            if istable(f) and istable(f.Members) then
                local m = GRM.Identity.FactionMember(f, ply)
                if istable(m) then return name, m.Role, m.Department end
            end
        end
        return nil, nil, nil
    end

    function D.HasWarrant(plyOrSid)
        local sid = charKey(plyOrSid)
        if sid == "" then return false end
        local w = D.Data.warrants and D.Data.warrants[sid]
        if not istable(w) then return false end
        local exp = tonumber(w.expires) or 0
        if exp > 0 and os.time() > exp then
            D.Data.warrants[sid] = nil
            D.SaveWarrants()
            return false
        end
        return true, w
    end

    function D.SyncLockNW(ent, locked)
        if not IsValid(ent) then return end
        for _, equivalent in ipairs(D.GetEquivalentDoors(ent)) do
            if IsValid(equivalent) then equivalent:SetNWBool("GRM_DoorLocked", locked == true) end
        end
        local partner = D.GetPartnerDoor(ent)
        if IsValid(partner) then partner:SetNWBool("GRM_DoorLocked", locked == true) end
    end

    local function ownerLabel(rec)
        if not rec or rec.owner_type == "none" then return "" end
        if rec.owner_type == "player" then return rec.owner_nick or "" end
        if rec.owner_type == "faction" then return "Фракция: " .. tostring(rec.owner_faction) end
        if rec.owner_type == "category" then
            local cc = D.Data.categories and D.Data.categories[rec.owner_category]
            return "Категория: " .. ((istable(cc) and tostring(cc.name or rec.owner_category)) or tostring(rec.owner_category))
        end
        return ""
    end

    function D.ApplyRecordVisual(ent, rec)
        if not IsValid(ent) then return end
        for _, equivalent in ipairs(D.GetEquivalentDoors(ent)) do
            if IsValid(equivalent) then
                equivalent:SetNWString("GRM_DoorTitle", rec and rec.title or "")
                equivalent:SetNWString("GRM_DoorOwner", ownerLabel(rec))
            end
        end
        local partner = D.GetPartnerDoor(ent)
        if IsValid(partner) then
            partner:SetNWString("GRM_DoorTitle", rec and rec.title or "")
            partner:SetNWString("GRM_DoorOwner", ownerLabel(rec))
        end
        D.SyncLockNW(ent, rec and rec.locked == true)
    end

    local function getRecord(ent)
        local id = D.GetDoorID(ent)
        if not id then return nil, nil end
        D.Data.doors = D.Data.doors or {}

        local rec, bestScore = D.Data.doors[id], recordPriority(D.Data.doors[id])
        local aliases = {}
        for _, equivalent in ipairs(D.GetEquivalentDoors(ent)) do
            local aliasID = baseDoorID(equivalent)
            if aliasID then
                aliases[aliasID] = true
                local candidate = D.Data.doors[aliasID]
                local score = recordPriority(candidate)
                if score > bestScore then rec, bestScore = candidate, score end
            end
        end
        if rec then
            rec.id = id
            rec._ephemeral = nil
            D.Data.doors[id] = rec
            for aliasID in pairs(aliases) do
                if aliasID ~= id then D.Data.doors[aliasID] = nil end
            end
            return rec, id
        end
        -- Эфемерная запись в карте: SaveDoors её не пишет, пока recDirty.
        -- Нужна, чтобы TOOL/LockDoor мутировали тот же объект.
        local fresh = defaultRec(id, ent)
        D.Data.doors[id] = fresh
        return fresh, id
    end
    D.GetRecord = getRecord

    local function persist(rec, id)
        if not rec or not id then return rec end
        rec.id = id
        rec._ephemeral = nil
        D.Data.doors = D.Data.doors or {}
        D.Data.doors[id] = rec
        return rec
    end

    local function actorOf(ply, rec)
        local fac, role = playerFactionInfo(ply)
        local catHas = rec and rec.owner_type == "category" and fac and factionInCategory(fac, rec.owner_category)
        local aclCat = false
        if rec and fac and istable(rec.categories) then
            for _, cid in ipairs(rec.categories) do
                if factionInCategory(fac, cid) then aclCat = true break end
            end
        end
        local AM = D.AccessManager
        return {
            superadmin = D.CanAdminDoors(ply),
            key = charKey(ply),
            faction = fac,
            role = role,
            canWarrant = AM and AM.CanWarrant and AM.CanWarrant(ply) or false,
            hasWarrantOnOwner = rec and rec.owner_type == "player" and D.HasWarrant(rec.owner_key) or false,
            canForce = AM and AM.CanForceDoor and AM.CanForceDoor(ply) or false,
            categoryHas = catHas == true,
            aclCategory = aclCat,
        }
    end

    function D.CanAccessDoor(ply, ent)
        if not IsValid(ply) or not IsValid(ent) then return false, "invalid" end
        if D.Config.SuperAdminBypass ~= false and ply:IsSuperAdmin() then return true, "superadmin" end
        local rec = select(1, getRecord(ent))
        local acc = D.EvaluateAccess(rec, actorOf(ply, rec))
        if acc.has_key then return true, "key" end
        return false, "denied"
    end

    function D.IsFriendlyForAlarm(ply, networkID)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return true end
        if D.AccessManager and D.AccessManager.IsFriendly then
            return D.AccessManager.IsFriendly(ply, networkID)
        end
        return false
    end

    function D.LockDoor(ent, locked)
        if not IsValid(ent) then return end
        local rec, id = getRecord(ent)
        local cmd = locked and "Lock" or "Unlock"
        for _, equivalent in ipairs(D.GetEquivalentDoors(ent)) do
            if IsValid(equivalent) then equivalent:Fire(cmd, "", 0) end
        end
        local partner = D.GetPartnerDoor(ent)
        if IsValid(partner) then partner:Fire(cmd, "", 0) end
        D.SyncLockNW(ent, locked)
        if rec then
            rec.locked = locked and true or false
            persist(rec, id)
            D.SaveDoors()
        end
    end

    function D.ClaimDoor(ply, ent, mode)
        if not IsValid(ply) or not IsValid(ent) then return false, "Недействительный объект" end
        local rec, id = getRecord(ent)
        if not rec then return false, "Запись не найдена" end
        local acc = D.EvaluateAccess(rec, actorOf(ply, rec))
        if not acc.buy then
            if rec.ownable == false then return false, "Эту дверь нельзя приобрести" end
            return false, "Дверь уже находится в собственности"
        end
        if rec.owner_type == "player" and (tonumber(rec.rent_until) or 0) > os.time() then
            return false, "Дверь уже арендована другим игроком"
        end

        local price = tonumber(rec.rent_price) or tonumber(D.Config.RentPrice) or 5000
        if mode == "rent" then
            if price > 0 and GRM.TakeMoney then
                if not GRM.HasMoney(ply, price) then return false, "Недостаточно наличных для аренды" end
                GRM.TakeMoney(ply, price, "Аренда двери")
            end
            rec.rent_until = os.time() + (tonumber(D.Config.DefaultRentSeconds) or 604800)
        else
            local permPrice = price * (tonumber(D.Config.PermPriceMultiplier) or 3)
            if permPrice > 0 and GRM.TakeMoney then
                if not GRM.HasMoney(ply, permPrice) then return false, "Недостаточно наличных для покупки (навечно)" end
                GRM.TakeMoney(ply, permPrice, "Покупка двери навечно")
            end
            rec.rent_until = 0
        end
        rec.owner_type = "player"
        rec.owner_key = charKey(ply)
        rec.owner_nick = ply:Nick()
        rec.owner_faction, rec.owner_category = "", ""
        rec.co_owners, rec.factions, rec.roles, rec.categories = {}, {}, {}, {}
        rec.locked = true
        persist(rec, id)
        D.LockDoor(ent, true)
        D.ApplyRecordVisual(ent, rec)
        D.SaveDoors()
        return true
    end

    function D.ReleaseDoor(ply, ent)
        local rec, id = getRecord(ent)
        if not rec then return false, "Запись не найдена" end
        local acc = D.EvaluateAccess(rec, actorOf(ply, rec))
        if not acc.own then return false, "Вы не являетесь владельцем этой двери" end
        rec.owner_type = "none"
        rec.owner_key, rec.owner_nick, rec.owner_faction, rec.owner_category = "", "", "", ""
        rec.co_owners, rec.factions, rec.roles, rec.categories = {}, {}, {}, {}
        rec.rent_until = 0
        rec.locked = false
        persist(rec, id)
        D.LockDoor(ent, false)
        D.ApplyRecordVisual(ent, rec)
        D.SaveDoors()
        return true
    end

    function D.IssueWarrant(issuer, targetSid, minutes, reason)
        if not IsValid(issuer) then return false, "Ошибка инициатора" end
        if not D.CanAdminDoors(issuer)
            and not (D.AccessManager and D.AccessManager.CanWarrant and D.AccessManager.CanWarrant(issuer)) then
            return false, "У вас нет прав выдавать ордера"
        end
        targetSid = charKey(targetSid)
        if targetSid == "" then return false, "Не указана цель" end
        minutes = math.Clamp(math.floor(tonumber(minutes) or 30), 5, 24 * 60)
        D.Data.warrants = D.Data.warrants or {}
        D.Data.warrants[targetSid] = {
            sid = targetSid, name = nickOf(targetSid),
            reason = utf8cut(tostring(reason or "Ордер на обыск имущества"), 160),
            by = charKey(issuer), byNick = issuer:Nick(),
            issued = os.time(), expires = os.time() + minutes * 60,
        }
        D.SaveWarrants()
        return true
    end

    function D.RevokeWarrant(issuer, targetSid)
        if not IsValid(issuer) then return false end
        if not D.CanAdminDoors(issuer)
            and not (D.AccessManager and D.AccessManager.CanWarrant and D.AccessManager.CanWarrant(issuer)) then
            return false, "У вас нет прав отзывать ордера"
        end
        if D.Data.warrants then D.Data.warrants[charKey(targetSid)] = nil end
        D.SaveWarrants()
        return true
    end

    local function aimDoor(ply)
        if not IsValid(ply) then return nil end
        local tr = util.TraceLine({
            start = ply:GetShootPos(),
            endpos = ply:GetShootPos() + ply:GetAimVector() * (D.Config.UseDistance or 180),
            filter = ply,
        })
        local ent = tr.Entity
        if D.IsDoor(ent) then return ent end
        if IsValid(ent) and IsValid(ent:GetParent()) and D.IsDoor(ent:GetParent()) then
            return ent:GetParent()
        end
    end

    local function nearDoor(ply, ent)
        if not (IsValid(ply) and IsValid(ent)) then return false end
        local maxD = D.Config.UseDistance or 180
        return ply:GetPos():DistToSqr(ent:GetPos()) <= (maxD + 40) * (maxD + 40)
    end

    hook.Add("AcceptInput", "GRM_Doors_SyncInput", function(ent, input)
        if not D.IsDoor(ent) then return end
        local lIn = string.lower(tostring(input or ""))
        if lIn == "lock" then D.SyncLockNW(ent, true)
        elseif lIn == "unlock" then D.SyncLockNW(ent, false) end
    end)

    timer.Create("GRM_Doors_LockReconciler", (D.Config and D.Config.LockSyncInterval) or 2.0, 0, function()
        if not istable(D.Data) or not istable(D.Data.doors) then return end
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent) and D.IsDoor(ent) then
                local rec = D.Data.doors[D.GetDoorID(ent)]
                local okE, engRaw = pcall(function() return ent:GetInternalVariable("m_bLocked") end)
                if not okE then engRaw = nil end
                local engLocked = (engRaw == true or engRaw == 1)
                if rec and (rec.locked == true or (rec.owner_type and rec.owner_type ~= "none")) then
                    local want = rec.locked == true
                    if engRaw ~= nil and engLocked ~= want then ent:Fire(want and "Lock" or "Unlock", "", 0) end
                    if ent:GetNWBool("GRM_DoorLocked", false) ~= want then D.SyncLockNW(ent, want) end
                else
                    local want = (rec and rec.locked == true) or engLocked
                    if ent:GetNWBool("GRM_DoorLocked", false) ~= want then D.SyncLockNW(ent, want) end
                end
            end
        end
    end)

    hook.Add("PlayerUse", "GRM_Doors_Use", function(ply, ent)
        if not D.IsDoor(ent) then
            if IsValid(ent) and IsValid(ent:GetParent()) and D.IsDoor(ent:GetParent()) then
                ent = ent:GetParent()
            else
                return
            end
        end
        if not D.IsDoorLocked(ent) then return end
        local rec = select(1, getRecord(ent))
        local acc = D.EvaluateAccess(rec, actorOf(ply, rec))
        if not acc.walk_locked then
            notify(ply, "Дверь заперта на замок. У вас нет доступа.", 255, 90, 90)
            return false
        end
    end)

    local function packDoorData(ent, ply)
        local rec, id = getRecord(ent)
        if not rec then return nil end
        local acc = D.EvaluateAccess(rec, actorOf(ply, rec))
        local payload = {
            id = id,
            title = rec.title or "",
            owner_type = rec.owner_type,
            owner_nick = rec.owner_nick or "",
            owner_faction = rec.owner_faction or "",
            owner_category = rec.owner_category or "",
            owner_category_name = (istable(D.Data.categories) and istable(D.Data.categories[rec.owner_category or ""])
                and tostring(D.Data.categories[rec.owner_category].name or "")) or "",
            locked = D.IsDoorLocked(ent),
            rent_until = tonumber(rec.rent_until) or 0,
            rent_price = tonumber(rec.rent_price) or (D.Config.RentPrice or 5000),
            can_access = acc.has_key,
            is_owner = acc.is_owner,
            is_admin = acc.admin,
            ownable = rec.ownable ~= false,
            can_buy = acc.buy,
            can_own = acc.own,
        }
        if acc.own or acc.admin then
            payload.owner_key = rec.owner_key or ""
            payload.factions = rec.factions or {}
            payload.roles = rec.roles or {}
            payload.categories = rec.categories or {}
            local co = {}
            for _, sid in ipairs(rec.co_owners or {}) do
                co[#co + 1] = { sid = sid, nick = nickOf(sid) }
            end
            payload.co_owners = co
        end
        return payload
    end

    function D.OpenDoorMenu(ply)
        local ent = aimDoor(ply)
        if not IsValid(ent) then
            notify(ply, "Подойдите ближе и смотрите на дверь.", 255, 180, 60)
            return
        end
        local doorData = packDoorData(ent, ply)
        local acc = doorData and (doorData.can_own or doorData.is_admin)
        local catsList, facList = {}, {}
        if acc then
            for id, c in pairs(D.Data.categories or {}) do
                catsList[#catsList + 1] = { id = id, name = c.name or id }
            end
            if istable(Factions) then
                for n, f in pairs(Factions) do
                    if istable(f) then
                        facList[#facList + 1] = { name = n, roles = f.Roles or {} }
                    end
                end
            end
        end
        net.Start(NET_OPEN)
            net.WriteEntity(ent)
            net.WriteTable(doorData or {})
            net.WriteTable(catsList)
            net.WriteTable(facList)
            net.WriteBool(D.CanAdminDoors(ply))
        net.Send(ply)
    end

    local function handleServerDoorBind(ply)
        if not IsValid(ply) then return end
        if IsValid(aimDoor(ply)) then D.OpenDoorMenu(ply) return true end
    end
    hook.Add("ShowTeam", "GRM_Doors_ServerOverrideF2", handleServerDoorBind)
    hook.Add("ShowSpare1", "GRM_Doors_ServerOverrideF3", handleServerDoorBind)
    hook.Add("ShowSpare2", "GRM_Doors_ServerOverrideF4", handleServerDoorBind)
    hook.Add("ShowHelp", "GRM_Doors_ServerOverrideF1", handleServerDoorBind)

    net.Receive(NET_ACT, function(_, ply)
        if not IsValid(ply) then return end
        ply.GRM_DoorActNext = ply.GRM_DoorActNext or 0
        if CurTime() < ply.GRM_DoorActNext then return end
        ply.GRM_DoorActNext = CurTime() + (D.Config.ActCooldown or 0.4)

        local a = net.ReadTable() or {}
        local act = tostring(a.action or "")
        if act == "open_menu" then D.OpenDoorMenu(ply) return end

        local ent = Entity(tonumber(a.entIndex) or -1)
        if not IsValid(ent) or not D.IsDoor(ent) then
            notify(ply, "Дверь не найдена.", 255, 100, 100)
            return
        end
        if not nearDoor(ply, ent) then
            notify(ply, "Подойдите ближе к двери.", 255, 180, 60)
            return
        end

        local rec, id = getRecord(ent)
        if not rec then return end
        local acc = D.EvaluateAccess(rec, actorOf(ply, rec))

        if act == "claim_rent" then
            local ok, err = D.ClaimDoor(ply, ent, "rent")
            notify(ply, ok and "Дверь успешно арендована!" or tostring(err), ok and 100 or 255, ok and 220 or 100, 100)
            if ok then D.OpenDoorMenu(ply) end

        elseif act == "claim_perm" then
            local ok, err = D.ClaimDoor(ply, ent, "permanent")
            notify(ply, ok and "Дверь куплена в постоянную собственность!" or tostring(err), ok and 100 or 255, ok and 220 or 100, 100)
            if ok then D.OpenDoorMenu(ply) end

        elseif act == "release" then
            local ok, err = D.ReleaseDoor(ply, ent)
            notify(ply, ok and "Дверь освобождена." or tostring(err), ok and 100 or 255, ok and 220 or 100, 100)
            if ok then D.OpenDoorMenu(ply) end

        elseif act == "lock" or act == "unlock" then
            if not acc.lock then
                notify(ply, "У вас нет прав закрывать/открывать эту дверь.", 255, 100, 100)
                return
            end
            D.LockDoor(ent, act == "lock")
            notify(ply, act == "lock" and "Замок заблокирован." or "Замок разблокирован.", 100, 220, 100)
            D.OpenDoorMenu(ply)

        elseif act == "set_title" then
            if not acc.own then return end
            rec.title = utf8cut(tostring(a.title or ""), 64)
            persist(rec, id)
            D.ApplyRecordVisual(ent, rec)
            D.SaveDoors()
            notify(ply, "Название двери обновлено.", 100, 220, 100)
            D.OpenDoorMenu(ply)

        elseif act == "add_coowner" then
            if not acc.own then return end
            local sid = charKey(a.sid)
            if sid == "" then return end
            rec.co_owners = rec.co_owners or {}
            if #rec.co_owners >= (D.Config.MaxOwnersPerDoor or 12) then
                notify(ply, "Достигнут лимит совладельцев.", 255, 180, 60)
                return
            end
            if not listHas(rec.co_owners, sid) then rec.co_owners[#rec.co_owners + 1] = sid end
            persist(rec, id)
            D.SaveDoors()
            notify(ply, "Совладелец добавлен: " .. nickOf(sid), 100, 220, 100)
            D.OpenDoorMenu(ply)

        elseif act == "remove_coowner" then
            if not acc.own then return end
            local sid = charKey(a.sid)
            local nextCo = {}
            for _, s in ipairs(rec.co_owners or {}) do if s ~= sid then nextCo[#nextCo + 1] = s end end
            rec.co_owners = nextCo
            persist(rec, id)
            D.SaveDoors()
            notify(ply, "Совладелец удалён.", 100, 220, 100)
            D.OpenDoorMenu(ply)

        elseif act == "toggle_acl_faction" then
            if not acc.own then return end
            local fac = tostring(a.faction or "")
            rec.factions = rec.factions or {}
            if listHas(rec.factions, fac) then
                local n = {}
                for _, f in ipairs(rec.factions) do if f ~= fac then n[#n + 1] = f end end
                rec.factions = n
            else
                rec.factions[#rec.factions + 1] = fac
            end
            persist(rec, id)
            D.SaveDoors()
            D.OpenDoorMenu(ply)

        elseif act == "toggle_acl_role" then
            if not acc.own then return end
            local key = tostring(a.roleKey or "")
            rec.roles = rec.roles or {}
            if listHas(rec.roles, key) then
                local n = {}
                for _, r in ipairs(rec.roles) do if r ~= key then n[#n + 1] = r end end
                rec.roles = n
            else
                rec.roles[#rec.roles + 1] = key
            end
            persist(rec, id)
            D.SaveDoors()
            D.OpenDoorMenu(ply)

        elseif act == "toggle_acl_category" then
            if not acc.own then return end
            local cat = tostring(a.category or "")
            rec.categories = rec.categories or {}
            if listHas(rec.categories, cat) then
                local n = {}
                for _, c in ipairs(rec.categories) do if c ~= cat then n[#n + 1] = c end end
                rec.categories = n
            else
                rec.categories[#rec.categories + 1] = cat
            end
            persist(rec, id)
            D.SaveDoors()
            D.OpenDoorMenu(ply)

        elseif act == "set_faction_owner" then
            if not acc.admin then
                notify(ply, "Только суперадмин может менять принадлежность двери.", 255, 100, 100)
                return
            end
            rec.owner_type = "faction"
            rec.owner_faction = tostring(a.faction or "")
            rec.owner_key, rec.owner_nick, rec.owner_category = "", "", ""
            rec.rent_until = 0
            persist(rec, id)
            D.ApplyRecordVisual(ent, rec)
            D.SaveDoors()
            notify(ply, "Назначен владелец: фракция [" .. rec.owner_faction .. "]", 100, 220, 100)
            D.OpenDoorMenu(ply)

        elseif act == "set_category_owner" then
            if not acc.admin then
                notify(ply, "Только суперадмин может менять принадлежность двери.", 255, 100, 100)
                return
            end
            rec.owner_type = "category"
            rec.owner_category = tostring(a.category or "")
            rec.owner_faction, rec.owner_key, rec.owner_nick = "", "", ""
            rec.rent_until = 0
            persist(rec, id)
            D.ApplyRecordVisual(ent, rec)
            D.SaveDoors()
            local catC = D.Data.categories and D.Data.categories[rec.owner_category]
            local catDisp = (istable(catC) and tostring(catC.name or rec.owner_category)) or rec.owner_category
            notify(ply, "Назначен владелец: категория [" .. catDisp .. "]", 100, 220, 100)
            D.OpenDoorMenu(ply)

        elseif act == "toggle_ownable" then
            if not acc.admin then
                notify(ply, "Только суперадмин может менять статус приватизации.", 255, 100, 100)
                return
            end
            rec.ownable = not (rec.ownable ~= false)
            persist(rec, id)
            D.SaveDoors()
            notify(ply, rec.ownable and "Дверь сделана доступной для покупки/аренды" or "Дверь заблокирована от приватизации", 100, 220, 100)
            D.OpenDoorMenu(ply)
        end
    end)

    local function chatCommand(ply, text)
        local args = string.Explode(" ", string.Trim(text or ""))
        local cmd = string.lower(args[1] or "")
        if cmd == "/door" or cmd == "!door" then D.OpenDoorMenu(ply) return true end
        if cmd == "/lock" or cmd == "!lock" or cmd == "/unlock" or cmd == "!unlock" then
            local ent = aimDoor(ply)
            if IsValid(ent) then
                local rec = select(1, getRecord(ent))
                local acc = D.EvaluateAccess(rec, actorOf(ply, rec))
                if acc.lock then
                    local want = (cmd == "/lock" or cmd == "!lock")
                    D.LockDoor(ent, want)
                    notify(ply, want and "Замок заблокирован." or "Замок разблокирован.", 100, 220, 100)
                else
                    notify(ply, "У вас нет доступа к этой двери.", 255, 100, 100)
                end
            end
            return true
        end
        if cmd == "/warrant" or cmd == "!warrant" then
            local who = args[2]
            if not who then notify(ply, "Использование: /warrant <ник|sid64> [мин] [причина]", 255, 180, 80) return true end
            local sid, mins, reason = who, tonumber(args[3]) or 30, table.concat(args, " ", 4)
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and (string.find(string.lower(p:Nick()), string.lower(who), 1, true)
                    or p:SteamID64() == who or p:SteamID() == who) then
                    sid = charKey(p) break
                end
            end
            local ok, err = D.IssueWarrant(ply, sid, mins, reason)
            notify(ply, ok and "Ордер выписан на обыск!" or tostring(err), ok and 100 or 255, ok and 220 or 100, 100)
            return true
        end
        if cmd == "/unwarrant" or cmd == "!unwarrant" then
            local who = args[2]
            if not who then return true end
            local sid = who
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and (string.find(string.lower(p:Nick()), string.lower(who), 1, true) or p:SteamID64() == who) then
                    sid = charKey(p) break
                end
            end
            local ok, err = D.RevokeWarrant(ply, sid)
            notify(ply, ok and "Ордер отозван." or tostring(err), ok and 100 or 255, ok and 220 or 100, 100)
            return true
        end
        if cmd == "/warrants" or cmd == "!warrants" then
            local n = 0
            for sid, w in pairs(D.Data.warrants or {}) do
                if D.HasWarrant(sid) then
                    n = n + 1
                    notify(ply, string.format("Ордер: %s (%s) до %s — %s", tostring(w.name), sid,
                        os.date("%H:%M", w.expires or 0), tostring(w.reason)), 220, 180, 80)
                end
            end
            if n == 0 then notify(ply, "Активных ордеров на обыск нет.", 150, 150, 150) end
            return true
        end
    end

    hook.Add("PlayerSayTransform", "GRM_Doors_Commands", function(p, pack)
        if not istable(pack) or not isstring(pack[1]) then return end
        if chatCommand(p, pack[1]) then pack[1] = "" pack.SkipPlayerSay = true end
    end)
    hook.Add("PlayerSay", "GRM_Doors_Chat", function(p, t)
        if chatCommand(p, t) then return "" end
    end)

    timer.Create("GRM_Doors_Tick", 60, 0, function()
        local now = os.time()
        local changed = false
        for id, rec in pairs(D.Data.doors or {}) do
            if istable(rec) and rec.owner_type == "player" and (tonumber(rec.rent_until) or 0) > 0
                and now > (tonumber(rec.rent_until) or 0) then
                rec.owner_type = "none"
                rec.owner_key, rec.owner_nick = "", ""
                rec.co_owners, rec.factions, rec.roles, rec.categories = {}, {}, {}, {}
                rec.rent_until, rec.locked = 0, false
                changed = true
            end
        end
        if changed then D.SaveDoors() end
        for sid, w in pairs(D.Data.warrants or {}) do
            if istable(w) and (tonumber(w.expires) or 0) > 0 and now > (tonumber(w.expires) or 0) then
                D.Data.warrants[sid] = nil
                D.SaveWarrants()
            end
        end
    end)

    hook.Add("InitPostEntity", "GRM_Doors_Load", function()
        D.LoadCategories()
        D.LoadDoors()
        D.LoadWarrants()
    end)

    print("[GRM Doors] Серверная система дверей v" .. D.Version .. " загружена")
end

-----------------------------------------------------------------------
-- CLIENT
-----------------------------------------------------------------------
if CLIENT then
    CreateClientConVar("grm_cl_doorhud", "1", true, false)
    surface.CreateFont("GRMDoor_Title",  { font = "Roboto", size = 18, weight = 800, extended = true })
    surface.CreateFont("GRMDoor_Sub",    { font = "Roboto", size = 14, weight = 600, extended = true })
    surface.CreateFont("GRMDoor_Normal", { font = "Roboto", size = 13, weight = 500, extended = true })
    surface.CreateFont("GRMDoor_HUD",    { font = "Roboto", size = 19, weight = 800, extended = true })
    surface.CreateFont("GRMDoor_HUDSm",  { font = "Roboto", size = 13, weight = 600, extended = true })

    local CUI = {
        bg = Color(20, 24, 32, 250), panel = Color(32, 38, 50, 245),
        accent = Color(70, 150, 240), green = Color(60, 190, 110),
        red = Color(220, 75, 70), yellow = Color(230, 180, 60),
        text = Color(240, 245, 250), dim = Color(160, 170, 185),
    }

    local function btn(p, text, col, w, h)
        local b = vgui.Create("DButton", p)
        if w then b:SetWide(w) end
        if h then b:SetTall(h) end
        b:SetText(text) b:SetFont("GRMDoor_Normal") b:SetTextColor(color_white)
        b.Paint = function(self, pw, ph)
            local c = col or CUI.accent
            if not self:IsEnabled() then c = Color(60, 65, 75)
            elseif self:IsHovered() then c = Color(math.min(255, c.r + 25), math.min(255, c.g + 25), math.min(255, c.b + 25)) end
            draw.RoundedBox(6, 0, 0, pw, ph, c)
        end
        return b
    end

    local function act(t)
        net.Start(NET_ACT) net.WriteTable(t or {}) net.SendToServer()
    end

    net.Receive(NET_INFO, function()
        chat.AddText(Color(70, 160, 240), "[Двери] ", color_white, net.ReadString())
    end)

    hook.Add("HUDShouldDraw", "GRM_Doors_HideGamemodeDoorHUD", function(name)
        if name == "DarkRP_DoorHUD" or name == "RPDoorHUD" or name == "DoorHUD"
            or name == "HUDDrawDoorData" or name == "SuperiorDoorHUD" then
            return false
        end
    end)
    hook.Add("HUDDrawDoorData", "GRM_Doors_SuppressGamemodeDoorData", function() return true end)
    timer.Create("GRM_Doors_SuppressDuplicateHUD", 2, 0, function()
        for _, id in ipairs({ "DarkRP_DoorHUD", "doorHUD", "DrawDoorInfo", "HUDPaint_Doors", "DoorHUD", "SuperiorDoorHUD" }) do
            if id ~= "GRM_Doors_HUD3D2D" then hook.Remove("HUDPaint", id) end
        end
    end)

    local function handleDoorBindOverride()
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        local tr = ply:GetEyeTrace()
        if IsValid(tr.Entity) and D.IsDoor(tr.Entity) and tr.StartPos:DistToSqr(tr.HitPos) <= 180 * 180 then
            act({ action = "open_menu" })
            return true
        end
    end
    hook.Add("ShowTeam", "GRM_Doors_OverrideF2", handleDoorBindOverride)
    hook.Add("ShowSpare1", "GRM_Doors_OverrideF3", handleDoorBindOverride)
    hook.Add("ShowSpare2", "GRM_Doors_OverrideF4", handleDoorBindOverride)
    hook.Add("ShowHelp", "GRM_Doors_OverrideF1", handleDoorBindOverride)

    hook.Add("HUDPaint", "GRM_Doors_HUD3D2D", function()
        local cv = GetConVar("grm_cl_doorhud")
        if cv and cv:GetInt() == 0 then return end
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end
        local active = ply:GetActiveWeapon()
        if IsValid(active) and active:GetClass() == "ds_key_swep" then return end
        local tr = ply:GetEyeTrace()
        local ent = tr.Entity
        if not IsValid(ent) then return end
        if not D.IsDoor(ent) and not (IsValid(ent:GetParent()) and D.IsDoor(ent:GetParent())) then return end
        local dist = tr.StartPos:DistToSqr(tr.HitPos)
        local maxDist = (D.Config and D.Config.HUDDistance or 220) ^ 2
        if dist > maxDist then return end
        local alpha = math.Clamp((1 - dist / maxDist) * 255, 0, 240)
        local locked = D.IsDoorLocked(ent)
        local title = ent:GetNWString("GRM_DoorTitle", "")
        local ownerStr = ent:GetNWString("GRM_DoorOwner", "")
        local sw, sh = ScrW(), ScrH()
        local cx, cy = sw / 2, sh / 2 + 90
        local bw, bh = 300, 76
        draw.RoundedBox(8, cx - bw / 2, cy, bw, bh, Color(16, 20, 28, alpha * 0.92))
        surface.SetDrawColor(locked and Color(220, 70, 70, alpha) or Color(60, 190, 110, alpha))
        surface.DrawOutlinedRect(cx - bw / 2, cy, bw, bh, 2)
        draw.SimpleText(title ~= "" and title or "Дверь", "GRMDoor_HUD", cx, cy + 18, Color(240, 245, 250, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(ownerStr ~= "" and ownerStr or "Продаётся / Ничья", "GRMDoor_HUDSm", cx, cy + 38, Color(200, 210, 225, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(locked and "[ЗАКРЫТО]" or "[ОТКРЫТО]", "GRMDoor_HUDSm", cx, cy + 58,
            locked and Color(255, 90, 90, alpha) or Color(90, 230, 130, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)

    net.Receive(NET_OPEN, function()
        local ent = net.ReadEntity()
        local d = net.ReadTable() or {}
        local catsList = net.ReadTable() or {}
        local facList = net.ReadTable() or {}
        local canAdmin = net.ReadBool()
        if not IsValid(ent) then return end

        local prevTabName, prevScroll
        if IsValid(D._sheet) then
            local at = D._sheet:GetActiveTab()
            if IsValid(at) then
                prevTabName = at:GetText()
                for _, it in ipairs(D._sheet.Items or {}) do
                    if it.Tab == at and IsValid(it.Panel) then
                        for _, ch in ipairs(it.Panel:GetChildren()) do
                            if IsValid(ch) and ch.ClassName == "DScrollPanel" then
                                prevScroll = ch:GetVBar():GetScroll()
                                break
                            end
                        end
                    end
                end
            end
        end

        if IsValid(D._frame) then D._frame:Remove() end
        local f = vgui.Create("DFrame")
        D._frame = f
        if GRM.UI and GRM.UI.Track then GRM.UI.Track("grm_door_menu", f) end
        f:SetTitle("") f:SetSize(620, 520) f:Center() f:MakePopup() f:ShowCloseButton(false)
        f.Paint = function(_, pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, CUI.bg)
            draw.RoundedBoxEx(8, 0, 0, pw, 38, Color(28, 34, 46), true, true, false, false)
            draw.SimpleText("Управление дверью", "GRMDoor_Title", 14, 19, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local closeBtn = vgui.Create("DButton", f)
        closeBtn:SetText("X") closeBtn:SetFont("GRMDoor_Sub") closeBtn:SetTextColor(color_white)
        closeBtn:SetPos(576, 6) closeBtn:SetSize(32, 26)
        closeBtn.DoClick = function() f:Close() end
        closeBtn.Paint = function(self, pw, ph)
            draw.RoundedBox(4, 0, 0, pw, ph, self:IsHovered() and CUI.red or Color(45, 52, 68))
        end

        local sheet = vgui.Create("DPropertySheet", f)
        sheet:Dock(FILL) sheet:DockMargin(8, 44, 8, 8)
        D._sheet = sheet

        local p1 = vgui.Create("DPanel", sheet) p1:SetPaintBackground(false)
        sheet:AddSheet("Обзор", p1, "icon16/door.png")
        local scroll1 = vgui.Create("DScrollPanel", p1) scroll1:Dock(FILL)

        local function infoRow(parent, labelText, valueText, valColor)
            local r = vgui.Create("DPanel", parent)
            r:Dock(TOP) r:SetTall(32) r:DockMargin(4, 2, 4, 2)
            r.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, CUI.panel) end
            local l1 = vgui.Create("DLabel", r) l1:Dock(LEFT) l1:SetWide(160) l1:DockMargin(10, 0, 0, 0)
            l1:SetText(labelText) l1:SetFont("GRMDoor_Normal") l1:SetTextColor(CUI.dim)
            local l2 = vgui.Create("DLabel", r) l2:Dock(FILL)
            l2:SetText(valueText) l2:SetFont("GRMDoor_Sub") l2:SetTextColor(valColor or CUI.text)
        end

        local ownerDesc = "Никто"
        if d.owner_type == "player" then ownerDesc = tostring(d.owner_nick)
        elseif d.owner_type == "faction" then ownerDesc = "Фракция: " .. tostring(d.owner_faction)
        elseif d.owner_type == "category" then
            ownerDesc = "Категория: " .. tostring((d.owner_category_name ~= "" and d.owner_category_name) or d.owner_category)
        end
        infoRow(scroll1, "Название:", d.title ~= "" and d.title or "Без названия", CUI.text)
        infoRow(scroll1, "Владелец:", ownerDesc, CUI.yellow)
        infoRow(scroll1, "Состояние замка:", d.locked and "ЗАКРЫТО" or "ОТКРЫТО", d.locked and CUI.red or CUI.green)
        if (tonumber(d.rent_until) or 0) > os.time() then
            infoRow(scroll1, "Аренда до:", os.date("%d.%m.%Y %H:%M", d.rent_until), CUI.yellow)
        end

        local actBox = vgui.Create("DPanel", scroll1)
        actBox:Dock(TOP) actBox:SetTall(160) actBox:DockMargin(4, 8, 4, 4)
        actBox.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, CUI.panel) end
        local btnY = 12
        if d.can_buy then
            local bRent = btn(actBox, "Арендовать (" .. (d.rent_price or 5000) .. " GRM / 7дн)", CUI.accent, 270, 32)
            bRent:SetPos(12, btnY)
            bRent.DoClick = function() act({ action = "claim_rent", entIndex = ent:EntIndex() }) end
            local bPerm = btn(actBox, "Купить навечно (" .. ((d.rent_price or 5000) * 3) .. " GRM)", CUI.green, 270, 32)
            bPerm:SetPos(292, btnY)
            bPerm.DoClick = function() act({ action = "claim_perm", entIndex = ent:EntIndex() }) end
            btnY = btnY + 40
        end
        if d.can_access or d.is_owner or d.is_admin then
            local bLock = btn(actBox, "Заблокировать замок", CUI.red, 270, 32)
            bLock:SetPos(12, btnY)
            bLock.DoClick = function() act({ action = "lock", entIndex = ent:EntIndex() }) end
            local bUnlock = btn(actBox, "Разблокировать замок", CUI.green, 270, 32)
            bUnlock:SetPos(292, btnY)
            bUnlock.DoClick = function() act({ action = "unlock", entIndex = ent:EntIndex() }) end
            btnY = btnY + 40
        end
        if d.can_own or d.is_admin then
            local bRel = btn(actBox, "Освободить / Отказаться от владения", CUI.yellow, 550, 30)
            bRel:SetPos(12, btnY)
            bRel.DoClick = function() act({ action = "release", entIndex = ent:EntIndex() }) end
            btnY = btnY + 36
            local titleEntry = vgui.Create("DTextEntry", actBox)
            titleEntry:SetPos(12, btnY) titleEntry:SetSize(400, 28)
            titleEntry:SetText(tostring(d.title or ""))
            titleEntry:SetPlaceholderText("Изменить название двери...")
            local bTitle = btn(actBox, "Сохранить имя", CUI.accent, 140, 28)
            bTitle:SetPos(422, btnY)
            bTitle.DoClick = function()
                act({ action = "set_title", entIndex = ent:EntIndex(), title = titleEntry:GetValue() })
            end
        end

        if d.can_own or d.is_admin then
            local p2 = vgui.Create("DPanel", sheet) p2:SetPaintBackground(false)
            sheet:AddSheet("Совладельцы", p2, "icon16/user_add.png")
            local addPanel = vgui.Create("DPanel", p2)
            addPanel:Dock(TOP) addPanel:SetTall(40) addPanel:DockMargin(4, 4, 4, 4)
            addPanel.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, CUI.panel) end
            local plyCombo = vgui.Create("DComboBox", addPanel)
            plyCombo:SetPos(10, 7) plyCombo:SetSize(360, 26)
            plyCombo:SetValue("Выберите игрока онлайн...")
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p ~= LocalPlayer() then
                    local ck = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(p)) or p:SteamID64()
                    plyCombo:AddChoice(p:Nick() .. " (" .. ck .. ")", ck)
                end
            end
            local bAddCo = btn(addPanel, "+ Добавить совладельца", CUI.green, 180, 26)
            bAddCo:SetPos(380, 7)
            bAddCo.DoClick = function()
                local _, sid = plyCombo:GetSelected()
                if sid then act({ action = "add_coowner", entIndex = ent:EntIndex(), sid = sid }) end
            end
            local coScroll = vgui.Create("DScrollPanel", p2)
            coScroll:Dock(FILL) coScroll:DockMargin(4, 4, 4, 4)
            for _, co in ipairs(d.co_owners or {}) do
                local row = vgui.Create("DPanel", coScroll)
                row:Dock(TOP) row:SetTall(32) row:DockMargin(0, 0, 0, 4)
                row.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, CUI.panel) end
                local lbl = vgui.Create("DLabel", row)
                lbl:Dock(LEFT) lbl:SetWide(380) lbl:DockMargin(10, 0, 0, 0)
                lbl:SetText(tostring(co.nick) .. " (" .. tostring(co.sid) .. ")")
                lbl:SetFont("GRMDoor_Normal") lbl:SetTextColor(CUI.text)
                local bRem = btn(row, "Удалить", CUI.red, 120, 24)
                bRem:Dock(RIGHT) bRem:DockMargin(0, 4, 10, 4)
                bRem.DoClick = function()
                    act({ action = "remove_coowner", entIndex = ent:EntIndex(), sid = co.sid })
                end
            end

            local p3 = vgui.Create("DPanel", sheet) p3:SetPaintBackground(false)
            sheet:AddSheet("Фракции и Роли", p3, "icon16/group_key.png")
            local scroll3 = vgui.Create("DScrollPanel", p3)
            scroll3:Dock(FILL) scroll3:DockMargin(4, 4, 4, 4)
            for _, fData in ipairs(facList or {}) do
                local fn = fData.name
                local fHas = false
                for _, n in ipairs(d.factions or {}) do if n == fn then fHas = true break end end
                local fRow = vgui.Create("DPanel", scroll3)
                fRow:Dock(TOP) fRow:SetTall(32) fRow:DockMargin(0, 0, 0, 2)
                fRow.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, CUI.panel) end
                local chk = vgui.Create("DCheckBoxLabel", fRow)
                chk:Dock(LEFT) chk:SetWide(300) chk:DockMargin(10, 0, 0, 0)
                chk:SetText("Фракция: " .. fn) chk:SetTextColor(CUI.text)
                chk:SetValue(fHas and 1 or 0)
                chk.OnChange = function()
                    act({ action = "toggle_acl_faction", entIndex = ent:EntIndex(), faction = fn })
                end
                for _, rName in ipairs(fData.roles or {}) do
                    local roleKey = fn .. "|" .. rName
                    local rHas = false
                    for _, n in ipairs(d.roles or {}) do if n == roleKey then rHas = true break end end
                    local rRow = vgui.Create("DPanel", scroll3)
                    rRow:Dock(TOP) rRow:SetTall(26) rRow:DockMargin(24, 0, 0, 2)
                    rRow.Paint = function(_, pw, ph) draw.RoundedBox(4, 0, 0, pw, ph, Color(26, 32, 42)) end
                    local rChk = vgui.Create("DCheckBoxLabel", rRow)
                    rChk:Dock(FILL) rChk:DockMargin(10, 0, 0, 0)
                    rChk:SetText("Роль: " .. rName) rChk:SetTextColor(CUI.dim)
                    rChk:SetValue(rHas and 1 or 0)
                    rChk.OnChange = function()
                        act({ action = "toggle_acl_role", entIndex = ent:EntIndex(), roleKey = roleKey })
                    end
                end
            end
            for _, cData in ipairs(catsList or {}) do
                local cid = cData.id
                if isstring(cid) and cid ~= "" then
                    local cHas = false
                    for _, n in ipairs(d.categories or {}) do if n == cid then cHas = true break end end
                    local cRow = vgui.Create("DPanel", scroll3)
                    cRow:Dock(TOP) cRow:SetTall(32) cRow:DockMargin(0, 0, 0, 2)
                    cRow.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, Color(38, 46, 62)) end
                    local cChk = vgui.Create("DCheckBoxLabel", cRow)
                    cChk:Dock(LEFT) cChk:SetWide(340) cChk:DockMargin(10, 0, 0, 0)
                    cChk:SetText("Категория: " .. tostring(cData.name or cid)) cChk:SetTextColor(CUI.yellow)
                    cChk:SetValue(cHas and 1 or 0)
                    cChk.OnChange = function()
                        act({ action = "toggle_acl_category", entIndex = ent:EntIndex(), category = cid })
                    end
                end
            end
        end

        if d.is_admin == true or canAdmin == true then
            local p4 = vgui.Create("DPanel", sheet) p4:SetPaintBackground(false)
            sheet:AddSheet("Администрирование", p4, "icon16/shield.png")
            local scroll4 = vgui.Create("DScrollPanel", p4)
            scroll4:Dock(FILL) scroll4:DockMargin(4, 4, 4, 4)
            local function adminBlock(title, height)
                local b = vgui.Create("DPanel", scroll4)
                b:Dock(TOP) b:SetTall(height or 80) b:DockMargin(0, 0, 0, 6)
                b.Paint = function(_, pw, ph)
                    draw.RoundedBox(6, 0, 0, pw, ph, CUI.panel)
                    draw.SimpleText(title, "GRMDoor_Sub", 10, 14, CUI.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end
                return b
            end
            local b1 = adminBlock("Назначить владельца — Фракцию:", 70)
            local facCombo = vgui.Create("DComboBox", b1)
            facCombo:SetPos(10, 32) facCombo:SetSize(280, 26) facCombo:SetValue("Выберите фракцию...")
            for _, fData in ipairs(facList or {}) do facCombo:AddChoice(fData.name, fData.name) end
            local bSetFac = btn(b1, "Назначить", CUI.accent, 140, 26)
            bSetFac:SetPos(300, 32)
            bSetFac.DoClick = function()
                local fn = facCombo:GetValue()
                if fn and fn ~= "" and fn ~= "Выберите фракцию..." then
                    act({ action = "set_faction_owner", entIndex = ent:EntIndex(), faction = fn })
                end
            end
            local b2 = adminBlock("Назначить владельца — Категорию:", 70)
            local catCombo = vgui.Create("DComboBox", b2)
            catCombo:SetPos(10, 32) catCombo:SetSize(280, 26) catCombo:SetValue("Выберите категорию...")
            for _, c in ipairs(catsList or {}) do catCombo:AddChoice(c.name or c.id, c.id) end
            local bSetCat = btn(b2, "Назначить", CUI.accent, 140, 26)
            bSetCat:SetPos(300, 32)
            bSetCat.DoClick = function()
                local catId = catCombo:GetOptionData(catCombo:GetSelectedID()) or catCombo:GetValue()
                if catId and catId ~= "" and catId ~= "Выберите категорию..." then
                    act({ action = "set_category_owner", entIndex = ent:EntIndex(), category = catId })
                end
            end
            local b3 = adminBlock("Статус доступности для приватизации:", 65)
            local bOwnable = btn(b3, d.ownable and "Разрешена приватизация (Сделать непубличной)" or "Заблокировано (Разрешить покупку/аренду)",
                d.ownable and CUI.green or CUI.red, 440, 28)
            bOwnable:SetPos(10, 30)
            bOwnable.DoClick = function() act({ action = "toggle_ownable", entIndex = ent:EntIndex() }) end
        end

        if prevTabName then
            for _, it in ipairs(sheet.Items or {}) do
                if IsValid(it.Tab) and it.Tab:GetText() == prevTabName then
                    sheet:SetActiveTab(it.Tab)
                    if prevScroll then
                        local restorePnl = it.Panel
                        timer.Simple(0, function()
                            if not IsValid(restorePnl) then return end
                            for _, ch in ipairs(restorePnl:GetChildren()) do
                                if IsValid(ch) and ch.ClassName == "DScrollPanel" then
                                    ch:GetVBar():SetScroll(prevScroll)
                                    break
                                end
                            end
                        end)
                    end
                    break
                end
            end
        end
    end)

    concommand.Add("grm_door", function()
        net.Start(NET_ACT) net.WriteTable({ action = "open_menu" }) net.SendToServer()
    end)

    print("[GRM Doors] Клиентская система дверей v" .. D.Version .. " загружена")
end
