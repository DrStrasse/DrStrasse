--[[ GRM Access Core v1.0.0: capability registry and unified grants. ]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Access = GRM.Access or {}
local A = GRM.Access
A.Version = "1.0.0"
A.Capabilities = A.Capabilities or {}
A.Providers = A.Providers or {}
A.Grants = A.Grants or {}

local function validID(id)
    return isstring(id) and id:match("^[a-z][a-z0-9_]*%.[a-z0-9_%.]+$") ~= nil
end

function A.Register(id, definition)
    id = string.lower(string.Trim(tostring(id or "")))
    if not validID(id) then return false, "invalid_capability_id" end
    definition = istable(definition) and definition or {}
    local current = A.Capabilities[id] or {}
    for key, value in pairs(definition) do current[key] = value end
    current.id = id
    current.label = tostring(current.label or id)
    current.scope = current.scope == "account" and "account" or "character"
    A.Capabilities[id] = current
    return true
end

function A.RegisterProvider(id, priority, callback)
    if not isfunction(callback) then return false, "callback_required" end
    A.Providers[tostring(id)] = { priority = tonumber(priority) or 0, callback = callback }
    return true
end

function A.Actor(ply)
    local actor = {
        player = ply,
        accountKey = IsValid(ply) and tostring(ply:SteamID64() or "") or "",
        characterKey = "",
        faction = IsValid(ply) and ply:GetNWString("GRM_Faction", "") or "",
        role = IsValid(ply) and ply:GetNWString("GRM_Role", "") or "",
        department = IsValid(ply) and ply:GetNWString("GRM_Department", "") or "",
    }
    if GRM.Identity and GRM.Identity.CharacterKey then actor.characterKey = GRM.Identity.CharacterKey(ply) end
    if actor.characterKey == "" and actor.accountKey ~= "" then actor.characterKey = actor.accountKey .. ":char1" end
    return actor
end

local SUBJECT_PRIORITY = { everyone = 0, faction = 10, role = 20, department = 20, account = 30, character = 40 }
local function grantMatches(grant, actor, capability)
    if not istable(grant) or grant.enabled == false then return false end
    if grant.capability ~= "*" and grant.capability ~= capability then return false end
    local kind, subject = tostring(grant.subjectType or ""), tostring(grant.subject or "")
    if kind == "everyone" then return true end
    if kind == "character" then return subject ~= "" and subject == actor.characterKey end
    if kind == "account" then return subject ~= "" and subject == actor.accountKey end
    if kind == "faction" then return subject ~= "" and subject == actor.faction end
    if kind == "role" then
        return subject ~= "" and subject == actor.role and (not grant.faction or grant.faction == "" or grant.faction == actor.faction)
    end
    if kind == "department" then
        return subject ~= "" and subject == actor.department and (not grant.faction or grant.faction == "" or grant.faction == actor.faction)
    end
    return false
end

local function explicitDecision(actor, capability)
    local best, decision, source = -1, nil, nil
    for index, grant in ipairs(A.Grants or {}) do
        if grantMatches(grant, actor, capability) then
            local priority = SUBJECT_PRIORITY[tostring(grant.subjectType)] or -1
            local allow = grant.allow ~= false
            if priority > best or (priority == best and allow == false) then
                best, decision, source = priority, allow, "grant:" .. tostring(index)
            end
        end
    end
    return decision, source
end

function A.Check(ply, capability, context)
    capability = string.lower(string.Trim(tostring(capability or "")))
    local definition = A.Capabilities[capability]
    if not definition then return false, "unknown_capability" end
    if not (IsValid(ply) and ply.IsPlayer and ply:IsPlayer()) then return false, "invalid_actor" end
    if definition.superadminBypass ~= false and ply:IsSuperAdmin() then return true, "superadmin" end

    local actor = A.Actor(ply)
    local decision, source = explicitDecision(actor, capability)
    if decision ~= nil then return decision, source end

    local providers = {}
    for id, provider in pairs(A.Providers) do providers[#providers + 1] = { id = id, value = provider } end
    table.sort(providers, function(a, b)
        if a.value.priority == b.value.priority then return a.id < b.id end
        return a.value.priority > b.value.priority
    end)
    for _, row in ipairs(providers) do
        local ok, allowed, reason = pcall(row.value.callback, ply, capability, context or {}, actor, definition)
        if ok and allowed ~= nil then return allowed == true, reason or ("provider:" .. row.id) end
    end

    if isfunction(definition.legacy) then
        local ok, allowed, reason = pcall(definition.legacy, ply, context or {}, actor)
        if ok and allowed ~= nil then return allowed == true, reason or "legacy" end
    end
    return definition.default == true, "default"
end

function A.Can(ply, capability, context)
    return A.Check(ply, capability, context)
end

function A.List()
    local out = {}
    for id, definition in pairs(A.Capabilities) do out[#out + 1] = { id = id, label = definition.label, scope = definition.scope } end
    table.sort(out, function(a, b) return a.id < b.id end)
    return out
end

local CORE_CAPABILITIES = {
    ["medical.computer.use"] = "Медицинский компьютер: вход",
    ["medical.patient.edit"] = "Медицина: изменение карты пациента",
    ["wanted.civil.view"] = "Розыск: просмотр",
    ["wanted.civil.edit"] = "Розыск: изменение дел",
    ["fire.dispatch"] = "Пожарная служба: диспетчер",
    ["fire.fight"] = "Пожарная служба: работа на месте",
    ["cctv.view"] = "CCTV: просмотр",
    ["cctv.configure"] = "CCTV: настройка",
    ["phone.equipment.use"] = "Телефония: оборудование",
    ["world.perm.manage"] = "Мир: управление постоянными объектами",
    ["doc.passport.issue"] = "Документы: выдача паспорта",
    ["doc.weapon_license.issue"] = "Документы: лицензия на оружие",
}
for id, label in pairs(CORE_CAPABILITIES) do A.Register(id, { label = label, scope = "character" }) end
A.Capabilities["world.perm.manage"].scope = "account"

if SERVER then
    local FILE = "grm_core/access_grants.json"
    function A.Load()
        local defaults = { version = 1, grants = {} }
        local data = GRM.Persistence and GRM.Persistence.LoadJSON and GRM.Persistence.LoadJSON(FILE, defaults, { version = 1 }) or defaults
        A.Grants = istable(data) and istable(data.grants) and data.grants or {}
        return A.Grants
    end
    function A.Save()
        if not (GRM.Persistence and GRM.Persistence.SaveJSON) then return false, "persistence_unavailable" end
        return GRM.Persistence.SaveJSON(FILE, { version = 1, grants = A.Grants }, { version = 1 })
    end
    function A.SetGrants(grants)
        if not istable(grants) then return false, "grants_required" end
        local clean = {}
        for _, grant in ipairs(grants) do
            if istable(grant) and (grant.capability == "*" or A.Capabilities[grant.capability]) and SUBJECT_PRIORITY[grant.subjectType] then
                clean[#clean + 1] = {
                    capability = tostring(grant.capability), subjectType = tostring(grant.subjectType),
                    subject = tostring(grant.subject or ""), faction = tostring(grant.faction or ""),
                    allow = grant.allow ~= false, enabled = grant.enabled ~= false,
                }
            end
        end
        A.Grants = clean
        return A.Save()
    end
    A.Load()

    -- Legacy systems remain authoritative until their UI is migrated.
    A.Capabilities["fire.dispatch"].legacy = function(ply)
        local am = GRM.Fire and GRM.Fire.AccessManager
        return am and am.CanControl and am.CanControl(ply) or nil, "legacy_fire_control"
    end
    A.Capabilities["fire.fight"].legacy = function(ply)
        local am = GRM.Fire and GRM.Fire.AccessManager
        return am and am.CanView and am.CanView(ply) or nil, "legacy_fire_view"
    end
    A.Capabilities["wanted.civil.view"].legacy = function(ply)
        local am = GRM.Wanted and GRM.Wanted.AccessManager
        return am and am.CanView and am.CanView(ply) or nil, "legacy_wanted_view"
    end
    A.Capabilities["wanted.civil.edit"].legacy = function(ply)
        local am = GRM.Wanted and GRM.Wanted.AccessManager
        return am and am.CanEdit and am.CanEdit(ply) or nil, "legacy_wanted_edit"
    end
    A.Capabilities["cctv.view"].legacy = function(ply)
        if GRM.CCTV and GRM.CCTV.CanView then return GRM.CCTV.CanView(ply), "legacy_cctv" end
    end
    A.Capabilities["cctv.configure"].legacy = function(ply, context)
        if GRM.CCTV and GRM.CCTV.CanConfigure then return GRM.CCTV.CanConfigure(ply, context.entity), "legacy_cctv" end
    end
    A.Capabilities["phone.equipment.use"].legacy = function(ply)
        if GRM.Phone and GRM.Phone.HasEquipmentAccess then return GRM.Phone.HasEquipmentAccess(ply), "legacy_phone" end
    end
end

print("[GRM Access] capability core v" .. A.Version .. " loaded")
