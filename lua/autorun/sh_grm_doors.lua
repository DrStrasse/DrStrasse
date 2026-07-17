--[[--------------------------------------------------------------------
    GRM Doors System v2.0.3 (Код 64 — ПЕРЕПИСАНО С НУЛЯ)
    Полная система управления дверями:
      - Уникальные ID на основе MapCreationID + позиций;
      - Двойные (партнёрские) двери — действия синхронно на обе створки;
      - Точная синхронизация замков: перехват AcceptInput ("Lock"/"Unlock") +
        проверка m_bLocked и автоматическая передача клиентам;
      - Чёткое подавление встроенных/сторонних HUD дверей во избежание наслоений;
      - Перехват клавиш F1-F4 на дверях: отключает чужие окна дверей и открывает GRM Doors;
      - Наглядный 3D2D HUD: одновременно показывает и Владельца, и
        гарантированный статус замка (ЗАКРЫТО / ОТКРЫТО);
      - Персональная покупка / аренда с таймером и авто-выселением;
      - Совладельцы с управлением через GUI (добавить/удалить);
      - Доступ по фракциям, рангам (Faction|Role) и категориям;
      - Ордера на обыск (/warrant, /unwarrant, /warrants) и взлом;
      - Взаимодействие через E, ключи (vehicle_keys_swep, ds_key_swep), /lock, /unlock;
      - Интеграция с Тараном ds_battering_ram и QTE-Отмычкой ds_lockpick.

    Команды:
      /door — меню двери (смотришь на дверь)
      /lock / /unlock — быстрое закрытие/открытие
      /door_admin — супер-админ панель категорий и карт
      /warrant <ник|sid> [мин] [причина] — выписать ордер
      /unwarrant <ник|sid> — отозвать ордер
      /warrants — список активных ордеров

    Данные: data/grm_doors/<map>.json , categories.json , warrants.json
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Doors = GRM.Doors or {}
local D = GRM.Doors

D.Config = D.Config or {
    UseDistance = 180,
    MaxOwnersPerDoor = 12,
    DefaultRentSeconds = 7 * 24 * 3600, -- 7 дней
    RentPrice = 5000,                   -- базовая цена аренды
    PermPriceMultiplier = 3,            -- множитель покупки навечно (х3)
    SuperAdminBypass = true,
    HUDDistance = 220,                  -- дистанция 3D2D HUD
    DoorClasses = {
        prop_door_rotating = true,
        func_door = true,
        func_door_rotating = true,
    },
}

-- ============================================================
-- SHARED ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (доступны на сервере и клиенте)
-- ============================================================
local function mapName()
    return string.lower(game.GetMap() or "unknown")
end

function D.IsDoor(ent)
    if not IsValid(ent) then return false end
    local cls = ent:GetClass()
    local cfg = D.Config and D.Config.DoorClasses or {}
    if cfg[cls] then return true end
    if cls == "prop_door_rotating" or cls == "func_door" or cls == "func_door_rotating" then
        return true
    end
    return false
end

function D.GetDoorID(ent)
    if not IsValid(ent) then return nil end
    local map = mapName()
    local mcid = ent:MapCreationID()
    if mcid and mcid > 0 then
        return string.format("%s_m%d", map, mcid)
    end
    local pos = ent:GetPos()
    return string.format("%s_%s_%.0f_%.0f_%.0f",
        map, ent:GetClass(),
        math.floor(pos.x + 0.5), math.floor(pos.y + 0.5), math.floor(pos.z + 0.5))
end

function D.GetPartnerDoor(ent)
    if not IsValid(ent) or not D.IsDoor(ent) then return nil end
    local pos = ent:GetPos()
    local parent = ent:GetParent()
    if IsValid(parent) and D.IsDoor(parent) then return parent end

    local near = ents.FindInSphere(pos, 110)
    for _, other in ipairs(near) do
        if IsValid(other) and other ~= ent and D.IsDoor(other) then
            local oPos = other:GetPos()
            if math.abs(pos.z - oPos.z) <= 30 then
                return other
            end
        end
    end
    return nil
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

local NET_OPEN      = "GRM_Doors_Open"
local NET_ACT       = "GRM_Doors_Act"
local NET_INFO      = "GRM_Doors_Info"
local NET_ADMIN     = "GRM_Doors_Admin"
local NET_ADMIN_ACT = "GRM_Doors_AdminAct"

-- ============================================================
-- СЕРВЕРНАЯ ЧАСТЬ
-- ============================================================
if SERVER then
    util.AddNetworkString(NET_OPEN)
    util.AddNetworkString(NET_ACT)
    util.AddNetworkString(NET_INFO)
    util.AddNetworkString(NET_ADMIN)
    util.AddNetworkString(NET_ADMIN_ACT)

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
        if GRM.Notify then
            GRM.Notify(ply, msg, r or 100, g or 220, b or 100)
            return
        end
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

    local function playerNickBySid(sid)
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and (p:SteamID64() == sid or p:SteamID() == sid) then
                return p:Nick()
            end
        end
        return sid
    end

    local function syncLockNW(ent, locked)
        if not IsValid(ent) then return end
        ent:SetNWBool("GRM_DoorLocked", locked == true)
        local partner = D.GetPartnerDoor(ent)
        if IsValid(partner) then
            partner:SetNWBool("GRM_DoorLocked", locked == true)
        end
    end

    local function syncTitleNW(ent, title, ownerStr)
        if not IsValid(ent) then return end
        ent:SetNWString("GRM_DoorTitle", title or "")
        ent:SetNWString("GRM_DoorOwner", ownerStr or "")
        local partner = D.GetPartnerDoor(ent)
        if IsValid(partner) then
            partner:SetNWString("GRM_DoorTitle", title or "")
            partner:SetNWString("GRM_DoorOwner", ownerStr or "")
        end
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
        return nil
    end

    -- Перехват входных команд движка Source
    hook.Add("AcceptInput", "GRM_Doors_SyncInput", function(ent, input, activator, caller, value)
        if D.IsDoor(ent) then
            local lIn = string.lower(tostring(input or ""))
            if lIn == "lock" then
                syncLockNW(ent, true)
            elseif lIn == "unlock" then
                syncLockNW(ent, false)
            end
        end
    end)

    -- Перехват нажатий F2 / F4 / биндов дверей на сервере
    local function handleServerDoorBind(ply)
        if not IsValid(ply) then return end
        local ent = aimDoor(ply)
        if IsValid(ent) then
            D.OpenDoorMenu(ply)
            return true
        end
    end

    hook.Add("ShowTeam", "GRM_Doors_ServerOverrideF2", handleServerDoorBind)
    hook.Add("ShowSpare1", "GRM_Doors_ServerOverrideF3", handleServerDoorBind)
    hook.Add("ShowSpare2", "GRM_Doors_ServerOverrideF4", handleServerDoorBind)
    hook.Add("ShowHelp", "GRM_Doors_ServerOverrideF1", handleServerDoorBind)

    -- ── Хранилище ──────────────────────────────────────────
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

        timer.Simple(1, function()
            for _, ent in ipairs(ents.GetAll()) do
                if IsValid(ent) and D.IsDoor(ent) then
                    local id = D.GetDoorID(ent)
                    local rec = D.Data.doors[id]
                    if rec then
                        local ownerTxt = ""
                        if rec.owner_type == "player" then ownerTxt = rec.owner_nick or ""
                        elseif rec.owner_type == "faction" then ownerTxt = "Фракция: " .. tostring(rec.owner_faction)
                        elseif rec.owner_type == "category" then ownerTxt = "Категория: " .. tostring(rec.owner_category) end

                        syncTitleNW(ent, rec.title, ownerTxt)
                        if rec.locked then
                            ent:Fire("Lock", "", 0)
                            syncLockNW(ent, true)
                        else
                            ent:Fire("Unlock", "", 0)
                            syncLockNW(ent, false)
                        end
                    else
                        local isEngLocked = ent:GetInternalVariable("m_bLocked") == true or ent:GetInternalVariable("m_bLocked") == 1
                        syncLockNW(ent, isEngLocked)
                    end
                end
            end
        end)

        print("[GRM Doors] Загружено дверей на карте " .. mapName() .. ": " .. table.Count(D.Data.doors))
    end

    function D.SaveCategories()
        local ok, txt = pcall(util.TableToJSON, D.Data.categories or {}, true)
        if ok and isstring(txt) then file.Write(catFile(), txt) end
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
            return
        end
        local t = jsonT(file.Read(catFile(), "DATA") or "")
        if istable(t) then
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

    local function getRecord(ent)
        local id = D.GetDoorID(ent)
        if not id then return nil, nil end
        D.Data.doors = D.Data.doors or {}
        local rec = D.Data.doors[id]
        if not rec then
            local engLocked = ent:GetInternalVariable("m_bLocked") == true or ent:GetInternalVariable("m_bLocked") == 1
            rec = {
                id = id,
                map = mapName(),
                class = ent:GetClass(),
                title = "",
                owner_type = "none",
                owner_sid = "",
                owner_nick = "",
                owner_faction = "",
                owner_category = "",
                co_owners = {},
                factions = {},
                categories = {},
                roles = {},
                rent_until = 0,
                rent_price = tonumber(D.Config.RentPrice) or 5000,
                locked = engLocked,
                ownable = true,
            }
            D.Data.doors[id] = rec
        end

        local isEngLocked = ent:GetInternalVariable("m_bLocked") == true or ent:GetInternalVariable("m_bLocked") == 1
        local isLocked = rec.locked or isEngLocked
        if isLocked ~= ent:GetNWBool("GRM_DoorLocked", false) then
            syncLockNW(ent, isLocked)
        end

        return rec, id
    end
    D.GetRecord = getRecord

    local function playerFactionInfo(ply)
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

        local rec = select(1, getRecord(ent))
        if not rec then return true, "no_rec" end

        if rec.owner_type == "none" or not rec.ownable then
            return true, "public"
        end

        local sid = steam64(ply)
        if rec.owner_type == "player" and rec.owner_sid == sid then
            return true, "owner"
        end

        if istable(rec.co_owners) then
            for _, s in ipairs(rec.co_owners) do
                if s == sid then return true, "coowner" end
            end
            if rec.co_owners[sid] == true then return true, "coowner" end
        end

        local fac, role = playerFactionInfo(ply)
        if rec.owner_type == "faction" and fac and rec.owner_faction == fac then
            return true, "owner_faction"
        end
        if rec.owner_type == "category" and fac and factionInCategory(fac, rec.owner_category) then
            return true, "owner_category"
        end

        if fac and istable(rec.factions) and rec.factions[fac] then
            return true, "acl_faction"
        end
        if fac and istable(rec.categories) then
            for catId, on in pairs(rec.categories) do
                if on and factionInCategory(fac, catId) then
                    return true, "acl_category"
                end
            end
        end
        if fac and role and istable(rec.roles) then
            local key = fac .. "|" .. tostring(role)
            if rec.roles[key] then return true, "acl_role" end
        end

        if rec.owner_type == "player" and rec.owner_sid ~= "" and D.HasWarrant(rec.owner_sid) then
            if D.AccessManager and D.AccessManager.CanWarrant and D.AccessManager.CanWarrant(ply) then
                return true, "warrant"
            end
        end

        if D.AccessManager and D.AccessManager.CanForceDoor and D.AccessManager.CanForceDoor(ply) then
            return true, "force_access"
        end

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
        local rec = select(1, getRecord(ent))
        local partner = D.GetPartnerDoor(ent)

        local cmd = locked and "Lock" or "Unlock"
        ent:Fire(cmd, "", 0)
        if IsValid(partner) then partner:Fire(cmd, "", 0) end

        syncLockNW(ent, locked)
        if rec then
            rec.locked = locked and true or false
            D.SaveDoors()
        end
    end

    hook.Add("PlayerUse", "GRM_Doors_Use", function(ply, ent)
        if not D.IsDoor(ent) then
            if IsValid(ent) and IsValid(ent:GetParent()) and D.IsDoor(ent:GetParent()) then
                ent = ent:GetParent()
            else
                return
            end
        end

        local isLocked = D.IsDoorLocked(ent)
        local ok, reason = D.CanAccessDoor(ply, ent)

        if isLocked and not ok then
            notify(ply, "Дверь заперта на замок. У вас нет доступа.", 255, 90, 90)
            return false
        end

        if not ok and select(1, getRecord(ent)) and select(1, getRecord(ent)).owner_type ~= "none" then
            notify(ply, "У вас нет доступа к этой двери.", 255, 120, 90)
            return false
        end
    end)

    function D.ClaimDoor(ply, ent, mode)
        if not IsValid(ply) or not IsValid(ent) then return false, "Недействительный объект" end
        local rec, id = getRecord(ent)
        if not rec or not rec.ownable then return false, "Эту дверь нельзя приобрести" end

        if rec.owner_type ~= "none" then
            if rec.owner_type == "player" and (tonumber(rec.rent_until) or 0) > 0 then
                if os.time() < (tonumber(rec.rent_until) or 0) then
                    return false, "Дверь уже арендована другим игроком"
                end
            else
                return false, "Дверь уже находится в собственности"
            end
        end

        local price = tonumber(rec.rent_price) or tonumber(D.Config.RentPrice) or 5000
        if mode == "rent" then
            if price > 0 and GRM.TakeMoney then
                if not GRM.HasMoney(ply, price) then return false, "Недостаточно наличных для аренды" end
                GRM.TakeMoney(ply, price, "Аренда двери " .. tostring(rec.title ~= "" and rec.title or id))
            end
            rec.rent_until = os.time() + (tonumber(D.Config.DefaultRentSeconds) or 604800)
        else
            local permPrice = price * (tonumber(D.Config.PermPriceMultiplier) or 3)
            if permPrice > 0 and GRM.TakeMoney then
                if not GRM.HasMoney(ply, permPrice) then return false, "Недостаточно наличных для покупки (навечно)" end
                GRM.TakeMoney(ply, permPrice, "Покупка двери навечно " .. tostring(rec.title ~= "" and rec.title or id))
            end
            rec.rent_until = 0
        end

        rec.owner_type = "player"
        rec.owner_sid = steam64(ply)
        rec.owner_nick = ply:Nick()
        rec.owner_faction = ""
        rec.owner_category = ""
        rec.co_owners = {}
        rec.locked = true

        D.LockDoor(ent, true)
        syncTitleNW(ent, rec.title, rec.owner_nick)
        D.SaveDoors()
        return true
    end

    function D.ReleaseDoor(ply, ent)
        local rec = select(1, getRecord(ent))
        if not rec then return false, "Запись не найдена" end
        local sid = steam64(ply)
        if rec.owner_type == "player" and rec.owner_sid ~= sid and not ply:IsSuperAdmin() then
            return false, "Вы не являетесь владельцем этой двери"
        end

        rec.owner_type = "none"
        rec.owner_sid = ""
        rec.owner_nick = ""
        rec.owner_faction = ""
        rec.owner_category = ""
        rec.co_owners = {}
        rec.rent_until = 0
        rec.locked = false

        D.LockDoor(ent, false)
        syncTitleNW(ent, rec.title, "")
        D.SaveDoors()
        return true
    end

    function D.IssueWarrant(issuer, targetSid, minutes, reason)
        if not IsValid(issuer) then return false, "Ошибка инициатора" end
        if not (D.AccessManager and D.AccessManager.CanWarrant and D.AccessManager.CanWarrant(issuer))
            and not issuer:IsSuperAdmin() then
            return false, "У вас нет прав выдавать ордера"
        end

        targetSid = tostring(targetSid or "")
        if targetSid == "" then return false, "Не указана цель" end
        minutes = math.Clamp(math.floor(tonumber(minutes) or 30), 5, 24 * 60)

        local nick = playerNickBySid(targetSid)
        D.Data.warrants = D.Data.warrants or {}
        D.Data.warrants[targetSid] = {
            sid = targetSid,
            name = nick,
            reason = tostring(reason or "Ордер на обыск имущества"),
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
            return false, "У вас нет прав отзывать ордера"
        end
        targetSid = tostring(targetSid or "")
        if D.Data.warrants then D.Data.warrants[targetSid] = nil end
        D.SaveWarrants()
        return true
    end

    local function packDoorData(ent, ply)
        local rec, id = getRecord(ent)
        if not rec then return nil end
        local canAccess = select(1, D.CanAccessDoor(ply, ent))
        local isOwner = rec.owner_type == "player" and rec.owner_sid == steam64(ply)
        local isLocked = D.IsDoorLocked(ent)

        local coOwnersInfo = {}
        if istable(rec.co_owners) then
            for _, sid in ipairs(rec.co_owners) do
                coOwnersInfo[#coOwnersInfo + 1] = {
                    sid = sid,
                    nick = playerNickBySid(sid),
                }
            end
        end

        return {
            id = id,
            class = ent:GetClass(),
            title = rec.title or "",
            owner_type = rec.owner_type,
            owner_nick = rec.owner_nick or "",
            owner_sid = rec.owner_sid or "",
            owner_faction = rec.owner_faction or "",
            owner_category = rec.owner_category or "",
            locked = isLocked,
            rent_until = tonumber(rec.rent_until) or 0,
            rent_price = tonumber(rec.rent_price) or (D.Config.RentPrice or 5000),
            can_access = canAccess,
            is_owner = isOwner,
            is_admin = ply:IsSuperAdmin(),
            factions = rec.factions or {},
            roles = rec.roles or {},
            categories = rec.categories or {},
            co_owners = coOwnersInfo,
            ownable = rec.ownable ~= false,
        }
    end

    function D.OpenDoorMenu(ply)
        local ent = aimDoor(ply)
        if not IsValid(ent) then
            notify(ply, "Подойдите ближе и смотрите на дверь.", 255, 180, 60)
            return
        end

        local doorData = packDoorData(ent, ply)
        local catsList = {}
        for id, c in pairs(D.Data.categories or {}) do
            catsList[#catsList + 1] = { id = id, name = c.name or id, factions = c.factions or {} }
        end

        local facList = {}
        if istable(Factions) then
            for n, f in pairs(Factions) do
                if istable(f) then
                    facList[#facList + 1] = { name = n, roles = f.Roles or {}, departments = f.Departments or {} }
                end
            end
        end

        net.Start(NET_OPEN)
            net.WriteEntity(ent)
            net.WriteTable(doorData or {})
            net.WriteTable(catsList)
            net.WriteTable(facList)
            net.WriteBool(D.AccessManager and D.AccessManager.CanManage and D.AccessManager.CanManage(ply) or ply:IsSuperAdmin())
        net.Send(ply)
    end

    net.Receive(NET_ACT, function(_, ply)
        if not IsValid(ply) then return end
        local a = net.ReadTable() or {}
        local act = tostring(a.action or "")

        if act == "open_menu" then
            D.OpenDoorMenu(ply)
            return
        end

        local ent = Entity(tonumber(a.entIndex) or -1)
        if not IsValid(ent) or not D.IsDoor(ent) then
            notify(ply, "Дверь не найдена.", 255, 100, 100)
            return
        end

        local rec = select(1, getRecord(ent))
        if not rec then return end
        local isOwner = rec.owner_type == "player" and rec.owner_sid == steam64(ply)
        local canManage = ply:IsSuperAdmin() or (D.AccessManager and D.AccessManager.CanManage and D.AccessManager.CanManage(ply))

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
            local wantLock = (act == "lock")
            local canLock = select(1, D.CanAccessDoor(ply, ent)) or isOwner or ply:IsSuperAdmin()
            if not canLock then
                notify(ply, "У вас нет прав закрывать/открывать эту дверь.", 255, 100, 100)
                return
            end
            D.LockDoor(ent, wantLock)
            notify(ply, wantLock and "Замок заблокирован." or "Замок разблокирован.", 100, 220, 100)
            D.OpenDoorMenu(ply)

        elseif act == "set_title" then
            if not isOwner and not canManage then return end
            rec.title = string.sub(tostring(a.title or ""), 1, 64)
            syncTitleNW(ent, rec.title, rec.owner_nick)
            D.SaveDoors()
            notify(ply, "Название двери обновлено.", 100, 220, 100)
            D.OpenDoorMenu(ply)

        elseif act == "add_coowner" then
            if not isOwner and not canManage then return end
            local sid = tostring(a.sid or "")
            if sid == "" then return end
            rec.co_owners = rec.co_owners or {}
            if #rec.co_owners >= (D.Config.MaxOwnersPerDoor or 12) then
                notify(ply, "Достигнут лимит совладельцев.", 255, 180, 60)
                return
            end
            local exists = false
            for _, s in ipairs(rec.co_owners) do if s == sid then exists = true break end end
            if not exists then
                rec.co_owners[#rec.co_owners + 1] = sid
                D.SaveDoors()
                notify(ply, "Совладелец добавлен: " .. playerNickBySid(sid), 100, 220, 100)
            end
            D.OpenDoorMenu(ply)

        elseif act == "remove_coowner" then
            if not isOwner and not canManage then return end
            local sid = tostring(a.sid or "")
            if istable(rec.co_owners) then
                local filtered = {}
                for _, s in ipairs(rec.co_owners) do
                    if s ~= sid then filtered[#filtered + 1] = s end
                end
                rec.co_owners = filtered
                D.SaveDoors()
                notify(ply, "Совладелец удалён.", 100, 220, 100)
            end
            D.OpenDoorMenu(ply)

        elseif act == "toggle_acl_faction" then
            if not isOwner and not canManage then return end
            local fac = tostring(a.faction or "")
            rec.factions = rec.factions or {}
            rec.factions[fac] = (not rec.factions[fac]) or nil
            D.SaveDoors()
            D.OpenDoorMenu(ply)

        elseif act == "toggle_acl_role" then
            if not isOwner and not canManage then return end
            local key = tostring(a.roleKey or "")
            rec.roles = rec.roles or {}
            rec.roles[key] = (not rec.roles[key]) or nil
            D.SaveDoors()
            D.OpenDoorMenu(ply)

        elseif act == "toggle_acl_category" then
            if not isOwner and not canManage then return end
            local cat = tostring(a.category or "")
            rec.categories = rec.categories or {}
            rec.categories[cat] = (not rec.categories[cat]) or nil
            D.SaveDoors()
            D.OpenDoorMenu(ply)

        elseif act == "set_faction_owner" then
            if not canManage then return end
            rec.owner_type = "faction"
            rec.owner_faction = tostring(a.faction or "")
            rec.owner_sid = ""
            rec.owner_nick = ""
            rec.owner_category = ""
            rec.rent_until = 0
            syncTitleNW(ent, rec.title, "Фракция: " .. rec.owner_faction)
            D.SaveDoors()
            notify(ply, "Назначен владелец: фракция [" .. rec.owner_faction .. "]", 100, 220, 100)
            D.OpenDoorMenu(ply)

        elseif act == "set_category_owner" then
            if not canManage then return end
            rec.owner_type = "category"
            rec.owner_category = tostring(a.category or "")
            rec.owner_faction = ""
            rec.owner_sid = ""
            rec.rent_until = 0
            syncTitleNW(ent, rec.title, "Категория: " .. rec.owner_category)
            D.SaveDoors()
            notify(ply, "Назначен владелец: категория [" .. rec.owner_category .. "]", 100, 220, 100)
            D.OpenDoorMenu(ply)

        elseif act == "toggle_ownable" then
            if not canManage then return end
            rec.ownable = not (rec.ownable ~= false)
            D.SaveDoors()
            notify(ply, rec.ownable and "Дверь сделана доступной для покупки/аренды" or "Дверь заблокирована от приватизации", 100, 220, 100)
            D.OpenDoorMenu(ply)
        end
    end)

    hook.Add("PlayerSay", "GRM_Doors_Chat", function(ply, text)
        local args = string.Explode(" ", string.Trim(text or ""))
        local cmd = string.lower(args[1] or "")

        if cmd == "/door" or cmd == "!door" then
            D.OpenDoorMenu(ply)
            return ""
        end

        if cmd == "/lock" or cmd == "!lock" then
            local ent = aimDoor(ply)
            if IsValid(ent) then
                local ok = select(1, D.CanAccessDoor(ply, ent))
                if ok then
                    D.LockDoor(ent, true)
                    notify(ply, "Замок заблокирован.", 100, 220, 100)
                else
                    notify(ply, "У вас нет доступа к этой двери.", 255, 100, 100)
                end
            end
            return ""
        end

        if cmd == "/unlock" or cmd == "!unlock" then
            local ent = aimDoor(ply)
            if IsValid(ent) then
                local ok = select(1, D.CanAccessDoor(ply, ent))
                if ok then
                    D.LockDoor(ent, false)
                    notify(ply, "Замок разблокирован.", 100, 220, 100)
                else
                    notify(ply, "У вас нет доступа к этой двери.", 255, 100, 100)
                end
            end
            return ""
        end

        if cmd == "/warrant" or cmd == "!warrant" then
            local who = args[2]
            local mins = tonumber(args[3]) or 30
            local reason = table.concat(args, " ", 4)
            if not who then
                notify(ply, "Использование: /warrant <ник|sid64> [мин] [причина]", 255, 180, 80)
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
            notify(ply, ok and "Ордер выписан на обыск!" or tostring(err), ok and 100 or 255, ok and 220 or 100, 100)
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
            notify(ply, ok and "Ордер отозван." or tostring(err), ok and 100 or 255, ok and 220 or 100, 100)
            return ""
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
            return ""
        end
    end)

    timer.Create("GRM_Doors_Tick", 60, 0, function()
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
                    rec.co_owners = {}
                    changed = true
                end
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

    print("[GRM Doors] Серверная система дверей v2.0.3 загружена")
end

-- ============================================================
-- КЛИЕНТСКАЯ ЧАСТЬ
-- ============================================================
if CLIENT then
    surface.CreateFont("GRMDoor_Title",  { font = "Roboto", size = 18, weight = 800, extended = true })
    surface.CreateFont("GRMDoor_Sub",    { font = "Roboto", size = 14, weight = 600, extended = true })
    surface.CreateFont("GRMDoor_Normal", { font = "Roboto", size = 13, weight = 500, extended = true })
    surface.CreateFont("GRMDoor_HUD",    { font = "Roboto", size = 19, weight = 800, extended = true })
    surface.CreateFont("GRMDoor_HUDSm",  { font = "Roboto", size = 13, weight = 600, extended = true })

    local CUI = {
        bg     = Color(20, 24, 32, 250),
        panel  = Color(32, 38, 50, 245),
        accent = Color(70, 150, 240),
        green  = Color(60, 190, 110),
        red    = Color(220, 75, 70),
        yellow = Color(230, 180, 60),
        text   = Color(240, 245, 250),
        dim    = Color(160, 170, 185),
    }

    local function btn(p, text, col, w, h)
        local b = vgui.Create("DButton", p)
        if w then b:SetWide(w) end
        if h then b:SetTall(h) end
        b:SetText(text)
        b:SetFont("GRMDoor_Normal")
        b:SetTextColor(color_white)
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

    -- ПОДАВЛЕНИЕ СТОРОННИХ / ВСТРОЕННЫХ HUD ДВЕРЕЙ (во избежание наслоений)
    hook.Add("HUDShouldDraw", "GRM_Doors_HideGamemodeDoorHUD", function(name)
        if name == "DarkRP_DoorHUD" or name == "RPDoorHUD" or name == "DoorHUD" or name == "HUDDrawDoorData" or name == "SuperiorDoorHUD" then
            return false
        end
    end)

    hook.Add("HUDDrawDoorData", "GRM_Doors_SuppressGamemodeDoorData", function()
        return true
    end)

    hook.Remove("HUDPaint", "DarkRP_DoorHUD")
    hook.Remove("HUDPaint", "doorHUD")
    hook.Remove("HUDPaint", "DrawDoorInfo")
    hook.Remove("HUDPaint", "HUDPaint_Doors")
    hook.Remove("HUDPaint", "DoorHUD")
    hook.Remove("HUDPaint", "SuperiorDoorHUD")

    -- Перехват биндов клавиш F1-F4 на дверях
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

    -- 3D2D HUD при прицеливании на дверь: ЕДИНСТВЕННЫЙ И НАГЛЯДНЫЙ
    hook.Add("HUDPaint", "GRM_Doors_HUD3D2D", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end

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

        local dispTitle = title ~= "" and title or "Дверь"
        draw.SimpleText(dispTitle, "GRMDoor_HUD", cx, cy + 18, Color(240, 245, 250, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local dispOwner = ownerStr ~= "" and ownerStr or "Продаётся / Ничья"
        draw.SimpleText(dispOwner, "GRMDoor_HUDSm", cx, cy + 38, Color(200, 210, 225, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local lockTxt = locked and "[ЗАКРЫТО]" or "[ОТКРЫТО]"
        local lockCol = locked and Color(255, 90, 90, alpha) or Color(90, 230, 130, alpha)
        draw.SimpleText(lockTxt, "GRMDoor_HUDSm", cx, cy + 58, lockCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)

    -- VGUI Меню управления дверью
    net.Receive(NET_OPEN, function()
        local ent = net.ReadEntity()
        local d = net.ReadTable() or {}
        local catsList = net.ReadTable() or {}
        local facList = net.ReadTable() or {}
        local canManage = net.ReadBool()
        if not IsValid(ent) then return end

        if IsValid(D._frame) then D._frame:Remove() end
        local f = vgui.Create("DFrame")
        D._frame = f
        f:SetTitle("")
        f:SetSize(620, 520)
        f:Center()
        f:MakePopup()
        f:ShowCloseButton(false)
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
        sheet:Dock(FILL)
        sheet:DockMargin(8, 44, 8, 8)

        local p1 = vgui.Create("DPanel", sheet) p1:SetPaintBackground(false)
        sheet:AddSheet("Обзор", p1, "icon16/door.png")

        local scroll1 = vgui.Create("DScrollPanel", p1)
        scroll1:Dock(FILL)

        local function infoRow(parent, labelText, valueText, valColor)
            local r = vgui.Create("DPanel", parent)
            r:Dock(TOP) r:SetTall(32) r:DockMargin(4, 2, 4, 2)
            r.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, CUI.panel) end
            local l1 = vgui.Create("DLabel", r) l1:Dock(LEFT) l1:SetWide(160) l1:DockMargin(10, 0, 0, 0)
            l1:SetText(labelText) l1:SetFont("GRMDoor_Normal") l1:SetTextColor(CUI.dim)
            local l2 = vgui.Create("DLabel", r) l2:Dock(FILL)
            l2:SetText(valueText) l2:SetFont("GRMDoor_Sub") l2:SetTextColor(valColor or CUI.text)
            return r
        end

        local ownerDesc = "Никто"
        if d.owner_type == "player" then ownerDesc = tostring(d.owner_nick) .. " (" .. tostring(d.owner_sid) .. ")"
        elseif d.owner_type == "faction" then ownerDesc = "Фракция: " .. tostring(d.owner_faction)
        elseif d.owner_type == "category" then ownerDesc = "Категория: " .. tostring(d.owner_category) end

        infoRow(scroll1, "ID Двери:", tostring(d.id or "?"), CUI.dim)
        infoRow(scroll1, "Название:", d.title ~= "" and d.title or "Без названия", CUI.text)
        infoRow(scroll1, "Владелец:", ownerDesc, CUI.yellow)
        infoRow(scroll1, "Состояние замка:", d.locked and "ЗАКРЫТО" or "ОТКРЫТО", d.locked and CUI.red or CUI.green)
        if (tonumber(d.rent_until) or 0) > os.time() then
            infoRow(scroll1, "Аренда действительна до:", os.date("%d.%m.%Y %H:%M", d.rent_until), CUI.yellow)
        end

        local actBox = vgui.Create("DPanel", scroll1)
        actBox:Dock(TOP) actBox:SetTall(160) actBox:DockMargin(4, 8, 4, 4)
        actBox.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, CUI.panel) end

        local btnY = 12
        if d.owner_type == "none" and d.ownable then
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

        if d.is_owner or d.is_admin then
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

        if d.is_owner or d.is_admin then
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
                    plyCombo:AddChoice(p:Nick() .. " (" .. p:SteamID64() .. ")", p:SteamID64())
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
        end

        if d.is_owner or d.is_admin then
            local p3 = vgui.Create("DPanel", sheet) p3:SetPaintBackground(false)
            sheet:AddSheet("Фракции и Роли", p3, "icon16/group_key.png")

            local scroll3 = vgui.Create("DScrollPanel", p3)
            scroll3:Dock(FILL) scroll3:DockMargin(4, 4, 4, 4)

            for _, fData in ipairs(facList or {}) do
                local fn = fData.name
                local fHas = d.factions and d.factions[fn] == true

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

                if istable(fData.roles) and #fData.roles > 0 then
                    for _, rName in ipairs(fData.roles) do
                        local roleKey = fn .. "|" .. rName
                        local rHas = d.roles and d.roles[roleKey] == true

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
            end
        end

        if canManage or d.is_admin then
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
            facCombo:SetPos(10, 32) facCombo:SetSize(280, 26)
            facCombo:SetValue("Выберите фракцию...")
            for _, fData in ipairs(facList or {}) do facCombo:AddChoice(fData.name) end
            local bSetFac = btn(b1, "Назначить", CUI.accent, 140, 26)
            bSetFac:SetPos(300, 32)
            bSetFac.DoClick = function()
                local _, fn = facCombo:GetSelected()
                if fn then act({ action = "set_faction_owner", entIndex = ent:EntIndex(), faction = fn }) end
            end

            local b2 = adminBlock("Назначить владельца — Категорию:", 70)
            local catCombo = vgui.Create("DComboBox", b2)
            catCombo:SetPos(10, 32) catCombo:SetSize(280, 26)
            catCombo:SetValue("Выберите категорию...")
            for _, c in ipairs(catsList or {}) do catCombo:AddChoice(c.name or c.id, c.id) end
            local bSetCat = btn(b2, "Назначить", CUI.accent, 140, 26)
            bSetCat:SetPos(300, 32)
            bSetCat.DoClick = function()
                local _, catId = catCombo:GetSelected()
                if catId then act({ action = "set_category_owner", entIndex = ent:EntIndex(), category = catId }) end
            end

            local b3 = adminBlock("Статус доступности для приватизации:", 65)
            local bOwnable = btn(b3, d.ownable and "Разрешена приватизация (Сделать непубличной)" or "Заблокировано (Разрешить покупку/аренду)", d.ownable and CUI.green or CUI.red, 440, 28)
            bOwnable:SetPos(10, 30)
            bOwnable.DoClick = function()
                act({ action = "toggle_ownable", entIndex = ent:EntIndex() })
            end
        end
    end)

    concommand.Add("grm_door", function()
        net.Start(NET_ACT) net.WriteTable({ action = "open_menu" }) net.SendToServer()
    end)

    print("[GRM Doors] Клиентская система дверей v2.0.3 загружена")
end
