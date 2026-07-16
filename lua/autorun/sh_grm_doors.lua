--[[--------------------------------------------------------------------
    GRM Doors System v1.0.0 (Код 64)
    Владение / аренда / доступ по фракциям, категориям, рангам.
    Ордера на обыск. Интеграция с сигнализацией (игнор «своих»).

    Команды:
      /door — меню двери (смотришь на дверь)
      /door_admin — superadmin: категории, сброс
      /warrant <ник|sid> [мин] [причина] — ордер (нужны права)
      /unwarrant <ник|sid>
      /warrants — список ордеров

    Данные: data/grm_doors/<map>.json , categories.json , warrants.json
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Doors = GRM.Doors or {}
local D = GRM.Doors

D.Config = D.Config or {
    UseDistance = 120,
    MaxOwnersPerDoor = 8,
    DefaultRentSeconds = 7 * 24 * 3600, -- 7 дней
    RentPrice = 5000,                   -- если есть GRM.TakeMoney
    SuperAdminBypass = true,
    -- Классы map-doors
    DoorClasses = {
        prop_door_rotating = true,
        func_door = true,
        func_door_rotating = true,
        prop_dynamic = false, -- optional
    },
}

local NET_OPEN = "GRM_Doors_Open"
local NET_ACT  = "GRM_Doors_Act"
local NET_INFO = "GRM_Doors_Info"
local NET_ADMIN = "GRM_Doors_Admin"
local NET_ADMIN_ACT = "GRM_Doors_AdminAct"

-- ============================================================
if SERVER then
    util.AddNetworkString(NET_OPEN)
    util.AddNetworkString(NET_ACT)
    util.AddNetworkString(NET_INFO)
    util.AddNetworkString(NET_ADMIN)
    util.AddNetworkString(NET_ADMIN_ACT)

    if GRM._doorsCoreActive then
        print("[GRM Doors] duplicate skipped")
        return
    end
    GRM._doorsCoreActive = true

    local DATA_DIR = "grm_doors"
    -- doors[map] = array of { id, map, ent_index_hint, model, pos, classes... ownership fields }
    -- We key doors by stable ID: map + round(pos) + class
    D.Data = D.Data or { doors = {}, categories = {}, warrants = {} }

    local function jsonT(txt)
        local ok, t = pcall(util.JSONToTable, txt, false, true)
        return (ok and istable(t)) and t or nil
    end

    local function ensureDir()
        if not file.IsDir(DATA_DIR, "DATA") then file.CreateDir(DATA_DIR) end
    end

    local function mapName()
        return string.lower(game.GetMap() or "unknown")
    end

    local function notify(ply, msg, r, g, b)
        if not IsValid(ply) then return end
        if GRM.Notify then GRM.Notify(ply, msg, r or 100, g or 220, b or 100) return end
        net.Start(NET_INFO)
            net.WriteString(tostring(msg or ""))
        net.Send(ply)
    end

    local function steam64(ply)
        if isstring(ply) then return tostring(ply) end
        if not IsValid(ply) then return "" end
        local id = ply:SteamID64()
        if id and id ~= "0" then return id end
        return ply:SteamID() or ""
    end

    local function isDoorEnt(ent)
        if not IsValid(ent) then return false end
        local cls = ent:GetClass()
        local cfg = D.Config.DoorClasses or {}
        if cfg[cls] then return true end
        -- also: doors with internal name
        if ent:GetClass() == "prop_door_rotating" or ent:GetClass() == "func_door"
            or ent:GetClass() == "func_door_rotating" then
            return true
        end
        return false
    end

    local function doorID(ent)
        if not IsValid(ent) then return nil end
        local pos = ent:GetPos()
        return string.format("%s_%s_%.0f_%.0f_%.0f",
            mapName(), ent:GetClass(),
            math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5))
    end

    local function aimDoor(ply)
        if not IsValid(ply) then return nil end
        local tr = util.TraceLine({
            start = ply:GetShootPos(),
            endpos = ply:GetShootPos() + ply:GetAimVector() * (D.Config.UseDistance or 120) * 2,
            filter = ply,
        })
        local ent = tr.Entity
        if isDoorEnt(ent) then return ent end
        -- parent/child
        if IsValid(ent) and IsValid(ent:GetParent()) and isDoorEnt(ent:GetParent()) then
            return ent:GetParent()
        end
        return nil
    end

    -- ── storage ────────────────────────────────────────────
    local function doorsFile()
        ensureDir()
        return DATA_DIR .. "/" .. mapName() .. ".json"
    end
    local function catFile()
        ensureDir()
        return DATA_DIR .. "/categories.json"
    end
    local function warFile()
        ensureDir()
        return DATA_DIR .. "/warrants.json"
    end

    function D.SaveDoors()
        local arr = {}
        for id, rec in pairs(D.Data.doors or {}) do
            if istable(rec) then
                rec.id = id
                arr[#arr + 1] = rec
            end
        end
        table.sort(arr, function(a, b) return tostring(a.id) < tostring(b.id) end)
        local ok, txt = pcall(util.TableToJSON, arr, true)
        if ok and isstring(txt) then
            file.Write(doorsFile(), txt)
            return true
        end
        return false
    end

    function D.LoadDoors()
        D.Data.doors = {}
        local path = doorsFile()
        if not file.Exists(path, "DATA") then return end
        local t = jsonT(file.Read(path, "DATA") or "")
        if not istable(t) then return end
        local list = istable(t[1]) and t or (istable(t.doors) and t.doors or {})
        for _, rec in ipairs(list) do
            if istable(rec) and isstring(rec.id) then
                D.Data.doors[rec.id] = rec
            end
        end
        print("[GRM Doors] loaded " .. table.Count(D.Data.doors) .. " door records")
    end

    function D.SaveCategories()
        local ok, txt = pcall(util.TableToJSON, D.Data.categories or {}, true)
        if ok and isstring(txt) then file.Write(catFile(), txt) end
    end

    function D.LoadCategories()
        D.Data.categories = {}
        if not file.Exists(catFile(), "DATA") then
            -- default categories
            D.Data.categories = {
                {
                    id = "police",
                    name = "Силовики",
                    factions = {}, -- filled by admin
                },
                {
                    id = "med",
                    name = "Медики",
                    factions = {},
                },
            }
            D.SaveCategories()
            return
        end
        local t = jsonT(file.Read(catFile(), "DATA") or "")
        if istable(t) then
            -- support array or map
            if istable(t[1]) then
                for _, c in ipairs(t) do
                    if istable(c) and isstring(c.id) then
                        D.Data.categories[c.id] = c
                    end
                end
            else
                D.Data.categories = t
            end
        end
    end

    function D.SaveWarrants()
        -- array
        local arr = {}
        for sid, w in pairs(D.Data.warrants or {}) do
            if istable(w) then
                w.sid = sid
                arr[#arr + 1] = w
            end
        end
        local ok, txt = pcall(util.TableToJSON, arr, true)
        if ok and isstring(txt) then file.Write(warFile(), txt) end
    end

    function D.LoadWarrants()
        D.Data.warrants = {}
        if not file.Exists(warFile(), "DATA") then return end
        local t = jsonT(file.Read(warFile(), "DATA") or "")
        if not istable(t) then return end
        local list = istable(t[1]) and t or {}
        for _, w in ipairs(list) do
            if istable(w) and isstring(w.sid) then
                D.Data.warrants[w.sid] = w
            end
        end
    end

    local function getRec(ent)
        local id = doorID(ent)
        if not id then return nil, nil end
        D.Data.doors = D.Data.doors or {}
        local rec = D.Data.doors[id]
        if not rec then
            rec = {
                id = id,
                map = mapName(),
                class = ent:GetClass(),
                title = "",
                -- ownership
                owner_type = "none", -- none | player | faction | category
                owner_sid = "",
                owner_nick = "",
                owner_faction = "",
                owner_category = "",
                -- access lists
                co_owners = {},      -- array of sid
                factions = {},      -- map factionName -> true
                categories = {},    -- map catId -> true
                roles = {},         -- map "Faction|Role" -> true
                -- rent
                rent_until = 0,
                rent_price = tonumber(D.Config.RentPrice) or 5000,
                -- flags
                locked = false,
                ownable = true,
            }
            D.Data.doors[id] = rec
        end
        return rec, id
    end

    -- ── faction helpers ────────────────────────────────────
    local function playerFaction(ply)
        if not IsValid(ply) or not istable(Factions) then return nil, nil, nil end
        local sid, sid64 = ply:SteamID(), ply:SteamID64()
        for name, f in pairs(Factions) do
            if istable(f) and istable(f.Members) then
                local m = f.Members[sid] or f.Members[sid64]
                if istable(m) then return name, m.Role, m.Department end
            end
        end
        return nil, nil, nil
    end

    local function factionInCategory(factionName, catId)
        local cat = D.Data.categories and D.Data.categories[catId]
        if not istable(cat) then return false end
        local facs = cat.factions or {}
        if istable(facs) then
            if facs[factionName] == true then return true end
            -- array form
            for _, n in pairs(facs) do
                if n == factionName then return true end
            end
        end
        return false
    end

    function D.HasWarrant(plyOrSid)
        local sid = steam64(plyOrSid)
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

    function D.CanAccessDoor(ply, ent)
        if not IsValid(ply) or not IsValid(ent) then return false, "invalid" end
        if D.Config.SuperAdminBypass ~= false and ply:IsSuperAdmin() then
            return true, "superadmin"
        end
        local rec = select(1, getRec(ent))
        if not rec then return true, "no_rec" end -- unclaimed default open access? 
        -- Unowned doors: everyone can use (map default)
        if rec.owner_type == "none" or not rec.ownable then
            return true, "public"
        end

        local sid = steam64(ply)
        -- owner
        if rec.owner_type == "player" and rec.owner_sid == sid then
            return true, "owner"
        end
        -- co-owners array
        if istable(rec.co_owners) then
            for _, s in ipairs(rec.co_owners) do
                if s == sid then return true, "coowner" end
            end
            if rec.co_owners[sid] == true then return true, "coowner" end
        end

        -- warrant: police-like access to any door
        if D.HasWarrant(ply) then
            -- warrant is ON the target, not the officer — check if THIS player is searching?
            -- Actually warrant is against a player: officers with CanWarrant rights force doors of target property
            -- Simpler: if officer has control rights from access manager and target has warrant, allow.
        end

        local fac, role = playerFaction(ply)
        if rec.owner_type == "faction" and fac and rec.owner_faction == fac then
            return true, "owner_faction"
        end
        if rec.owner_type == "category" and fac and factionInCategory(fac, rec.owner_category) then
            return true, "owner_category"
        end

        -- extra access factions
        if fac and istable(rec.factions) and rec.factions[fac] then
            return true, "acl_faction"
        end
        -- categories ACL
        if fac and istable(rec.categories) then
            for catId, on in pairs(rec.categories) do
                if on and factionInCategory(fac, catId) then
                    return true, "acl_category"
                end
            end
        end
        -- roles "FactionName|RoleName"
        if fac and role and istable(rec.roles) then
            local key = fac .. "|" .. tostring(role)
            if rec.roles[key] then return true, "acl_role" end
        end

        -- global door access from AccessManager (police category etc.)
        if D.AccessManager and D.AccessManager.CanForceDoor and D.AccessManager.CanForceDoor(ply) then
            -- only if warrant exists on door owner or always for force?
            -- For search warrant: if owner has warrant
            if rec.owner_type == "player" and rec.owner_sid ~= "" and D.HasWarrant(rec.owner_sid) then
                return true, "warrant"
            end
            -- also allow force-open if they have ForceAccess right
            if D.AccessManager.CanForceDoor(ply) then
                return true, "force_access"
            end
        end

        return false, "denied"
    end

    -- Used by Alarm: is this player "friendly" to the network / door group?
    function D.IsFriendlyForAlarm(ply, networkID)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return true end
        -- if access manager defines friendly factions for alarm
        if GRM.Alarm and GRM.Alarm.AccessManager and GRM.Alarm.AccessManager.IsFriendly then
            return GRM.Alarm.AccessManager.IsFriendly(ply, networkID)
        end
        -- fallback: members of categories marked ignore_alarm or control access
        if GRM.Alarm and GRM.Alarm.CanControl and GRM.Alarm.CanControl(ply) then
            return true
        end
        return false
    end

    -- ── lock integration ───────────────────────────────────
    local function applyLock(ent, locked)
        if not IsValid(ent) then return end
        if locked then
            ent:Fire("Lock", "", 0)
            ent:SetNWBool("GRM_DoorLocked", true)
        else
            ent:Fire("Unlock", "", 0)
            ent:SetNWBool("GRM_DoorLocked", false)
        end
        local rec = select(1, getRec(ent))
        if rec then
            rec.locked = locked and true or false
            D.SaveDoors()
        end
    end

    hook.Add("PlayerUse", "GRM_Doors_Use", function(ply, ent)
        if not isDoorEnt(ent) then
            if IsValid(ent) and IsValid(ent:GetParent()) and isDoorEnt(ent:GetParent()) then
                ent = ent:GetParent()
            else
                return
            end
        end
        local ok, reason = D.CanAccessDoor(ply, ent)
        local rec = select(1, getRec(ent))
        if rec and rec.locked and not ok then
            notify(ply, "Дверь закрыта. Нет доступа.", 255, 100, 100)
            return false
        end
        if not ok and rec and rec.owner_type ~= "none" then
            notify(ply, "Нет доступа к этой двери.", 255, 100, 100)
            return false
        end
    end)

    -- ── ownership ops ──────────────────────────────────────
    function D.ClaimDoor(ply, ent, mode)
        -- mode: permanent | rent
        if not IsValid(ply) or not IsValid(ent) then return false, "invalid" end
        local rec, id = getRec(ent)
        if not rec or not rec.ownable then return false, "Нельзя приватизировать" end
        if rec.owner_type ~= "none" then
            -- allow reclaim if rent expired
            if rec.owner_type == "player" and (tonumber(rec.rent_until) or 0) > 0 then
                if os.time() < (tonumber(rec.rent_until) or 0) then
                    return false, "Дверь уже занята"
                end
            else
                return false, "Дверь уже занята"
            end
        end
        local price = tonumber(rec.rent_price) or tonumber(D.Config.RentPrice) or 0
        if mode == "rent" and price > 0 and GRM.TakeMoney then
            if not GRM.HasMoney(ply, price) then return false, "Недостаточно денег" end
            GRM.TakeMoney(ply, price, "Аренда двери")
            rec.rent_until = os.time() + (tonumber(D.Config.DefaultRentSeconds) or 604800)
        else
            rec.rent_until = 0 -- permanent
            if mode == "permanent" and price > 0 and GRM.TakeMoney then
                local p2 = price * 3 -- permanent costlier
                if not GRM.HasMoney(ply, p2) then return false, "Недостаточно денег (перм ×3)" end
                GRM.TakeMoney(ply, p2, "Покупка двери")
            end
        end
        rec.owner_type = "player"
        rec.owner_sid = steam64(ply)
        rec.owner_nick = ply:Nick()
        rec.owner_faction = ""
        rec.owner_category = ""
        rec.locked = true
        applyLock(ent, true)
        D.SaveDoors()
        return true
    end

    function D.ReleaseDoor(ply, ent)
        local rec = select(1, getRec(ent))
        if not rec then return false end
        local sid = steam64(ply)
        if rec.owner_type == "player" and rec.owner_sid ~= sid and not ply:IsSuperAdmin() then
            return false, "Вы не владелец"
        end
        rec.owner_type = "none"
        rec.owner_sid = ""
        rec.owner_nick = ""
        rec.owner_faction = ""
        rec.owner_category = ""
        rec.co_owners = {}
        rec.rent_until = 0
        rec.locked = false
        applyLock(ent, false)
        D.SaveDoors()
        return true
    end

    -- ── warrants ───────────────────────────────────────────
    function D.IssueWarrant(issuer, targetSid, minutes, reason)
        if not IsValid(issuer) then return false, "invalid" end
        if not (D.AccessManager and D.AccessManager.CanWarrant and D.AccessManager.CanWarrant(issuer))
            and not issuer:IsSuperAdmin() then
            return false, "Нет прав на ордера"
        end
        targetSid = tostring(targetSid or "")
        if targetSid == "" then return false, "Нет цели" end
        minutes = math.Clamp(math.floor(tonumber(minutes) or 30), 5, 24 * 60)
        local nick = targetSid
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and steam64(p) == targetSid then nick = p:Nick() break end
        end
        D.Data.warrants = D.Data.warrants or {}
        D.Data.warrants[targetSid] = {
            sid = targetSid,
            name = nick,
            reason = tostring(reason or "Ордер на обыск"),
            by = steam64(issuer),
            byNick = issuer:Nick(),
            issued = os.time(),
            expires = os.time() + minutes * 60,
        }
        D.SaveWarrants()
        return true
    end

    function D.RevokeWarrant(issuer, targetSid)
        if not IsValid(issuer) then return false end
        if not issuer:IsSuperAdmin() and not (D.AccessManager and D.AccessManager.CanWarrant and D.AccessManager.CanWarrant(issuer)) then
            return false, "Нет прав"
        end
        targetSid = tostring(targetSid or "")
        if D.Data.warrants then D.Data.warrants[targetSid] = nil end
        D.SaveWarrants()
        return true
    end

    -- ── UI open ────────────────────────────────────────────
    local function packDoor(ent, ply)
        local rec, id = getRec(ent)
        if not rec then return nil end
        local canAccess = select(1, D.CanAccessDoor(ply, ent))
        local isOwner = rec.owner_type == "player" and rec.owner_sid == steam64(ply)
        return {
            id = id,
            class = ent:GetClass(),
            title = rec.title,
            owner_type = rec.owner_type,
            owner_nick = rec.owner_nick,
            owner_sid = rec.owner_sid,
            owner_faction = rec.owner_faction,
            owner_category = rec.owner_category,
            locked = rec.locked and true or false,
            rent_until = tonumber(rec.rent_until) or 0,
            rent_price = tonumber(rec.rent_price) or 0,
            can_access = canAccess,
            is_owner = isOwner,
            is_admin = ply:IsSuperAdmin(),
            factions = rec.factions or {},
            categories = rec.categories or {},
            co_owners = rec.co_owners or {},
            ownable = rec.ownable ~= false,
        }
    end

    function D.OpenDoorMenu(ply)
        local ent = aimDoor(ply)
        if not IsValid(ent) then
            notify(ply, "Смотрите на дверь.", 255, 180, 60)
            return
        end
        local data = packDoor(ent, ply)
        local cats = {}
        for id, c in pairs(D.Data.categories or {}) do
            cats[#cats + 1] = { id = id, name = c.name or id, factions = c.factions or {} }
        end
        local facNames = {}
        for n in pairs(Factions or {}) do facNames[#facNames + 1] = n end
        table.sort(facNames)
        net.Start(NET_OPEN)
            net.WriteEntity(ent)
            net.WriteTable(data or {})
            net.WriteTable(cats)
            net.WriteTable(facNames)
            net.WriteBool(D.AccessManager and D.AccessManager.CanManage and D.AccessManager.CanManage(ply) or ply:IsSuperAdmin())
        net.Send(ply)
    end

    net.Receive(NET_ACT, function(_, ply)
        if not IsValid(ply) then return end
        local a = net.ReadTable() or {}
        local act = tostring(a.action or "")
        local ent = Entity(tonumber(a.entIndex) or -1)
        if act == "open_menu" then D.OpenDoorMenu(ply) return end

        if not IsValid(ent) or not isDoorEnt(ent) then
            notify(ply, "Дверь не найдена.", 255, 100, 100)
            return
        end
        local rec = select(1, getRec(ent))
        if not rec then return end

        if act == "claim_rent" then
            local ok, err = D.ClaimDoor(ply, ent, "rent")
            notify(ply, ok and "Дверь арендована." or tostring(err), ok and 100 or 255, ok and 220 or 100, 100)
            if ok then D.OpenDoorMenu(ply) end
        elseif act == "claim_perm" then
            local ok, err = D.ClaimDoor(ply, ent, "permanent")
            notify(ply, ok and "Дверь в собственности." or tostring(err), ok and 100 or 255, ok and 220 or 100, 100)
            if ok then D.OpenDoorMenu(ply) end
        elseif act == "release" then
            local ok, err = D.ReleaseDoor(ply, ent)
            notify(ply, ok and "Дверь освобождена." or tostring(err), ok and 100 or 255, ok and 220 or 100, 100)
            if ok then D.OpenDoorMenu(ply) end
        elseif act == "lock" then
            local ok = select(1, D.CanAccessDoor(ply, ent))
            local isOwner = rec.owner_type == "player" and rec.owner_sid == steam64(ply)
            if not ok and not isOwner and not ply:IsSuperAdmin() then
                notify(ply, "Нет прав.", 255, 100, 100) return
            end
            applyLock(ent, true)
            notify(ply, "Дверь закрыта.", 100, 220, 100)
            D.OpenDoorMenu(ply)
        elseif act == "unlock" then
            local ok = select(1, D.CanAccessDoor(ply, ent))
            if not ok and not ply:IsSuperAdmin() then
                notify(ply, "Нет прав.", 255, 100, 100) return
            end
            applyLock(ent, false)
            notify(ply, "Дверь открыта.", 100, 220, 100)
            D.OpenDoorMenu(ply)
        elseif act == "set_faction_owner" then
            if not ply:IsSuperAdmin() and not (D.AccessManager and D.AccessManager.CanManage and D.AccessManager.CanManage(ply)) then return end
            rec.owner_type = "faction"
            rec.owner_faction = tostring(a.faction or "")
            rec.owner_sid = ""
            rec.owner_nick = ""
            rec.owner_category = ""
            rec.rent_until = 0
            D.SaveDoors()
            notify(ply, "Владелец: фракция " .. rec.owner_faction, 100, 220, 100)
            D.OpenDoorMenu(ply)
        elseif act == "set_category_owner" then
            if not ply:IsSuperAdmin() then return end
            rec.owner_type = "category"
            rec.owner_category = tostring(a.category or "")
            rec.owner_faction = ""
            rec.owner_sid = ""
            rec.rent_until = 0
            D.SaveDoors()
            notify(ply, "Владелец: категория " .. rec.owner_category, 100, 220, 100)
            D.OpenDoorMenu(ply)
        elseif act == "toggle_acl_faction" then
            local isOwner = rec.owner_type == "player" and rec.owner_sid == steam64(ply)
            if not isOwner and not ply:IsSuperAdmin() then return end
            local fac = tostring(a.faction or "")
            rec.factions = rec.factions or {}
            if rec.factions[fac] then rec.factions[fac] = nil else rec.factions[fac] = true end
            D.SaveDoors()
            D.OpenDoorMenu(ply)
        elseif act == "toggle_acl_category" then
            local isOwner = rec.owner_type == "player" and rec.owner_sid == steam64(ply)
            if not isOwner and not ply:IsSuperAdmin() then return end
            local cat = tostring(a.category or "")
            rec.categories = rec.categories or {}
            if rec.categories[cat] then rec.categories[cat] = nil else rec.categories[cat] = true end
            D.SaveDoors()
            D.OpenDoorMenu(ply)
        elseif act == "add_coowner" then
            local isOwner = rec.owner_type == "player" and rec.owner_sid == steam64(ply)
            if not isOwner and not ply:IsSuperAdmin() then return end
            local sid = tostring(a.sid or "")
            if sid == "" then return end
            rec.co_owners = rec.co_owners or {}
            local found = false
            for _, s in ipairs(rec.co_owners) do if s == sid then found = true break end end
            if not found then rec.co_owners[#rec.co_owners + 1] = sid end
            D.SaveDoors()
            notify(ply, "Совладелец добавлен.", 100, 220, 100)
            D.OpenDoorMenu(ply)
        elseif act == "title" then
            local isOwner = rec.owner_type == "player" and rec.owner_sid == steam64(ply)
            if not isOwner and not ply:IsSuperAdmin() then return end
            rec.title = string.sub(tostring(a.title or ""), 1, 48)
            D.SaveDoors()
            D.OpenDoorMenu(ply)
        end
    end)

    -- admin categories + warrants UI data
    net.Receive(NET_ADMIN, function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        local cats = {}
        for id, c in pairs(D.Data.categories or {}) do
            cats[#cats + 1] = c
            cats[#cats].id = id
        end
        local wars = {}
        for sid, w in pairs(D.Data.warrants or {}) do
            if D.HasWarrant(sid) then wars[#wars + 1] = w end
        end
        local facs = {}
        for n in pairs(Factions or {}) do facs[#facs + 1] = n end
        table.sort(facs)
        net.Start(NET_ADMIN)
            net.WriteTable(cats)
            net.WriteTable(wars)
            net.WriteTable(facs)
        net.Send(ply)
    end)

    net.Receive(NET_ADMIN_ACT, function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        local a = net.ReadTable() or {}
        local act = tostring(a.action or "")
        if act == "save_category" then
            local id = tostring(a.id or "")
            if id == "" then id = "cat_" .. os.time() end
            D.Data.categories = D.Data.categories or {}
            D.Data.categories[id] = {
                id = id,
                name = tostring(a.name or id),
                factions = istable(a.factions) and a.factions or {},
            }
            D.SaveCategories()
            notify(ply, "Категория сохранена: " .. id, 100, 220, 100)
        elseif act == "del_category" then
            local id = tostring(a.id or "")
            if D.Data.categories then D.Data.categories[id] = nil end
            D.SaveCategories()
        end
    end)

    hook.Add("PlayerSay", "GRM_Doors_Chat", function(ply, text)
        local args = string.Explode(" ", string.Trim(text or ""))
        local cmd = string.lower(args[1] or "")
        if cmd == "/door" or cmd == "!door" then
            D.OpenDoorMenu(ply)
            return ""
        end
        if cmd == "/door_admin" or cmd == "!door_admin" then
            if not ply:IsSuperAdmin() then return "" end
            net.Start(NET_ADMIN) -- request filled by receive? send empty trigger client to request
            net.Send(ply)
            -- actually client opens on NET_ADMIN data; trigger server pack:
            timer.Simple(0, function()
                if not IsValid(ply) then return end
                local cats, wars, facs = {}, {}, {}
                for id, c in pairs(D.Data.categories or {}) do
                    local cc = table.Copy(c); cc.id = id; cats[#cats + 1] = cc
                end
                for sid, w in pairs(D.Data.warrants or {}) do
                    if D.HasWarrant(sid) then wars[#wars + 1] = w end
                end
                for n in pairs(Factions or {}) do facs[#facs + 1] = n end
                net.Start(NET_ADMIN)
                    net.WriteTable(cats) net.WriteTable(wars) net.WriteTable(facs)
                net.Send(ply)
            end)
            return ""
        end
        if cmd == "/warrant" or cmd == "!warrant" then
            local who = args[2]
            local mins = tonumber(args[3]) or 30
            local reason = table.concat(args, " ", 4)
            if not who then
                notify(ply, "Использование: /warrant <ник|sid> [мин] [причина]", 255, 180, 80)
                return ""
            end
            local sid = who
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and (string.find(string.lower(p:Nick()), string.lower(who), 1, true)
                    or p:SteamID64() == who or p:SteamID() == who) then
                    sid = p:SteamID64()
                    break
                end
            end
            local ok, err = D.IssueWarrant(ply, sid, mins, reason)
            notify(ply, ok and "Ордер выписан." or tostring(err), ok and 100 or 255, ok and 220 or 100, 100)
            if ok then
                for _, p in ipairs(player.GetAll()) do
                    if IsValid(p) and steam64(p) == sid then
                        notify(p, "На вас выписан ордер на обыск: " .. (reason ~= "" and reason or "без указания"), 230, 80, 80)
                    end
                end
            end
            return ""
        end
        if cmd == "/unwarrant" or cmd == "!unwarrant" then
            local who = args[2]
            if not who then return "" end
            local sid = who
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and (string.find(string.lower(p:Nick()), string.lower(who), 1, true) or p:SteamID64() == who) then
                    sid = p:SteamID64() break
                end
            end
            local ok, err = D.RevokeWarrant(ply, sid)
            notify(ply, ok and "Ордер снят." or tostring(err), ok and 100 or 255, ok and 220 or 100, 100)
            return ""
        end
        if cmd == "/warrants" or cmd == "!warrants" then
            if not D.HasWarrant and not ply:IsSuperAdmin() then end
            local n = 0
            for sid, w in pairs(D.Data.warrants or {}) do
                if D.HasWarrant(sid) then
                    n = n + 1
                    notify(ply, string.format("%s (%s) до %s — %s", tostring(w.name), sid,
                        os.date("%H:%M", w.expires or 0), tostring(w.reason)), 200, 180, 80)
                end
            end
            if n == 0 then notify(ply, "Активных ордеров нет.", 150, 150, 150) end
            return ""
        end
    end)

    -- expire rents
    timer.Create("GRM_Doors_RentTick", 60, 0, function()
        local now = os.time()
        local changed = false
        for id, rec in pairs(D.Data.doors or {}) do
            if istable(rec) and (tonumber(rec.rent_until) or 0) > 0 then
                if now > (tonumber(rec.rent_until) or 0) and rec.owner_type == "player" then
                    rec.owner_type = "none"
                    rec.owner_sid = ""
                    rec.owner_nick = ""
                    rec.rent_until = 0
                    rec.locked = false
                    changed = true
                end
            end
        end
        if changed then D.SaveDoors() end
        -- expire warrants
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

    concommand.Add("grm_door", function(ply) if IsValid(ply) then D.OpenDoorMenu(ply) end end)

    print("[GRM Doors] server v1.0.0")
end

-- ============================================================
if CLIENT then
    surface.CreateFont("GRMDoor_Title", { font = "Roboto", size = 18, weight = 800, extended = true })
    surface.CreateFont("GRMDoor_Normal", { font = "Roboto", size = 14, weight = 500, extended = true })

    local THEME = {
        bg = Color(22, 24, 32, 250), panel = Color(32, 36, 48, 245),
        text = Color(230, 235, 240), dim = Color(150, 160, 175),
        green = Color(70, 180, 110), accent = Color(70, 140, 220),
        yellow = Color(220, 180, 70), red = Color(220, 80, 80),
    }

    local function btn(p, text, col, w, h)
        local b = vgui.Create("DButton", p)
        b:SetSize(w or 140, h or 28)
        b:SetText(text)
        b:SetFont("GRMDoor_Normal")
        b:SetTextColor(color_white)
        b.Paint = function(self, ww, hh)
            local c = col or THEME.accent
            if self:IsHovered() then c = Color(math.min(255, c.r + 20), math.min(255, c.g + 20), math.min(255, c.b + 20)) end
            draw.RoundedBox(6, 0, 0, ww, hh, c)
        end
        return b
    end

    local function act(t)
        net.Start(NET_ACT) net.WriteTable(t or {}) net.SendToServer()
    end

    net.Receive(NET_INFO, function()
        chat.AddText(Color(100, 180, 255), "[Двери] ", color_white, net.ReadString())
    end)

    net.Receive(NET_OPEN, function()
        local ent = net.ReadEntity()
        local d = net.ReadTable() or {}
        local cats = net.ReadTable() or {}
        local facNames = net.ReadTable() or {}
        local canManage = net.ReadBool()
        if not IsValid(ent) then return end

        if IsValid(D._frame) then D._frame:Remove() end
        local f = vgui.Create("DFrame")
        D._frame = f
        f:SetTitle("")
        f:SetSize(480, 520)
        f:Center()
        f:MakePopup()
        f.Paint = function(_, w, h)
            draw.RoundedBox(8, 0, 0, w, h, THEME.bg)
            draw.SimpleText("Дверь", "GRMDoor_Title", 12, 18, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local y = 44
        local function lab(txt, col)
            local l = vgui.Create("DLabel", f)
            l:SetPos(16, y) l:SetSize(440, 18)
            l:SetText(txt) l:SetFont("GRMDoor_Normal") l:SetTextColor(col or THEME.text)
            y = y + 20
        end

        lab("ID: " .. tostring(d.id or "?"), THEME.dim)
        lab("Владелец: " .. (
            d.owner_type == "none" and "—" or
            d.owner_type == "player" and (tostring(d.owner_nick) .. " (" .. tostring(d.owner_sid) .. ")") or
            d.owner_type == "faction" and ("фракция " .. tostring(d.owner_faction)) or
            d.owner_type == "category" and ("категория " .. tostring(d.owner_category)) or tostring(d.owner_type)
        ))
        lab("Замок: " .. (d.locked and "ЗАКРЫТО" or "открыто"), d.locked and THEME.red or THEME.green)
        if (tonumber(d.rent_until) or 0) > os.time() then
            lab("Аренда до: " .. os.date("%d.%m.%Y %H:%M", d.rent_until), THEME.yellow)
        end
        lab("Доступ: " .. (d.can_access and "есть" or "нет"), d.can_access and THEME.green or THEME.red)

        y = y + 8
        local function row(title, col, action, extra)
            local b = btn(f, title, col, 200, 30)
            b:SetPos(16, y)
            b.DoClick = function()
                local t = { action = action, entIndex = ent:EntIndex() }
                if extra then for k, v in pairs(extra) do t[k] = v end end
                act(t)
            end
            y = y + 36
            return b
        end

        if d.owner_type == "none" and d.ownable then
            row("Арендовать", THEME.accent, "claim_rent")
            row("Купить (перманент)", THEME.green, "claim_perm")
        end
        if d.is_owner or d.is_admin then
            row("Закрыть замок", THEME.red, "lock")
            row("Открыть замок", THEME.green, "unlock")
            row("Освободить дверь", THEME.yellow, "release")
        elseif d.can_access then
            row("Закрыть (доступ)", THEME.red, "lock")
            row("Открыть (доступ)", THEME.green, "unlock")
        end

        if d.is_admin or canManage then
            y = y + 4
            lab("Админ: владелец-фракция", THEME.dim)
            local fac = vgui.Create("DComboBox", f)
            fac:SetPos(16, y) fac:SetSize(240, 24)
            fac:SetValue("Фракция…")
            for _, n in ipairs(facNames or {}) do fac:AddChoice(n) end
            local bf = btn(f, "Назначить", THEME.accent, 100, 24)
            bf:SetPos(270, y)
            bf.DoClick = function()
                local _, name = fac:GetSelected()
                if name then act({ action = "set_faction_owner", entIndex = ent:EntIndex(), faction = name }) end
            end
            y = y + 36
            lab("Админ: владелец-категория", THEME.dim)
            local cat = vgui.Create("DComboBox", f)
            cat:SetPos(16, y) cat:SetSize(240, 24)
            cat:SetValue("Категория…")
            for _, c in ipairs(cats or {}) do cat:AddChoice(c.name or c.id, c.id) end
            local bc = btn(f, "Назначить", THEME.accent, 100, 24)
            bc:SetPos(270, y)
            bc.DoClick = function()
                local _, id = cat:GetSelected()
                if id then act({ action = "set_category_owner", entIndex = ent:EntIndex(), category = id }) end
            end
            y = y + 36
        end

        if d.is_owner or d.is_admin then
            lab("Доступ фракциям (клик = вкл/выкл):", THEME.dim)
            local scroll = vgui.Create("DScrollPanel", f)
            scroll:SetPos(16, y)
            scroll:SetSize(440, 80)
            for _, n in ipairs(facNames or {}) do
                local b = vgui.Create("DButton", scroll)
                b:Dock(TOP) b:SetTall(22) b:DockMargin(0, 0, 0, 2)
                local on = d.factions and d.factions[n]
                b:SetText((on and "[+] " or "[ ] ") .. n)
                b.DoClick = function()
                    act({ action = "toggle_acl_faction", entIndex = ent:EntIndex(), faction = n })
                end
            end
        end
    end)

    net.Receive(NET_ADMIN, function()
        local cats = net.ReadTable() or {}
        local wars = net.ReadTable() or {}
        local facs = net.ReadTable() or {}
        local f = vgui.Create("DFrame")
        f:SetTitle("Двери — админ")
        f:SetSize(700, 500)
        f:Center()
        f:MakePopup()
        local sheet = vgui.Create("DPropertySheet", f)
        sheet:Dock(FILL)
        local p1 = vgui.Create("DPanel")
        local lv = vgui.Create("DListView", p1)
        lv:Dock(FILL)
        lv:AddColumn("ID")
        lv:AddColumn("Имя")
        for _, c in ipairs(cats) do lv:AddLine(tostring(c.id), tostring(c.name)) end
        sheet:AddSheet("Категории", p1)
        local p2 = vgui.Create("DPanel")
        local lw = vgui.Create("DListView", p2)
        lw:Dock(FILL)
        lw:AddColumn("Игрок")
        lw:AddColumn("До")
        lw:AddColumn("Причина")
        for _, w in ipairs(wars) do
            lw:AddLine(tostring(w.name), os.date("%d.%m %H:%M", w.expires or 0), tostring(w.reason))
        end
        sheet:AddSheet("Ордера", p2)
    end)

    concommand.Add("grm_door", function()
        net.Start(NET_ACT) net.WriteTable({ action = "open_menu" }) net.SendToServer()
    end)

    print("[GRM Doors] client v1.0.0")
end
