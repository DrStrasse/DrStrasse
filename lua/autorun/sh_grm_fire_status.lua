--[[--------------------------------------------------------------------
    GRM Fire — учёт тушения.
    Кластер vFire = один пожар. Уведомления:
      «Пожар локализован» — очаг сжат и больше не растёт (после работы ствола).
      «Пожар потушен» — клеток не осталось.
    Журнал data/grm_fire/log.json (массив). Не трогает Q / factions / FFD.
----------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Fire = GRM.Fire or {}
local F = GRM.Fire

F.Incidents = F.Incidents or {}
F._nextInc = F._nextInc or 1

local CLUSTER = 480
local LOG_FILE = "grm_fire/log.json"
local LOG_CAP = 80

local function jsonT(txt)
    local ok, t = pcall(util.JSONToTable, txt, false, true)
    return (ok and istable(t)) and t or nil
end

local function plyKey(ply)
    if not IsValid(ply) then return nil end
    if GRM.Identity and isfunction(GRM.Identity.CharacterKey) then
        local k = GRM.Identity.CharacterKey(ply)
        if isstring(k) and k ~= "" then return k end
    end
    if ply.SteamID64 then return tostring(ply:SteamID64() or "") end
    return tostring(ply:SteamID() or "")
end

local function plyNick(ply)
    if not IsValid(ply) then return "?" end
    return tostring(ply:Nick() or "?")
end

function F.NotifyFire(text, r, g, b, pos)
    r = tonumber(r) or 255
    g = tonumber(g) or 160
    b = tonumber(b) or 80
    if F.NotifyFactions then
        F.NotifyFactions(text, pos, r, g, b)
    end
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and (p:IsSuperAdmin() or (F.CanDispatch and F.CanDispatch(p))) then
            if GRM.Notify then GRM.Notify(p, text, r, g, b)
            else p:ChatPrint("[Пожар] " .. text) end
        end
    end
    print("[GRM Fire] " .. tostring(text))
end

if SERVER then
    local function ensureDir()
        if not file.IsDir("grm_fire", "DATA") then file.CreateDir("grm_fire") end
    end

    function F.LoadFireLog()
        ensureDir()
        if not file.Exists(LOG_FILE, "DATA") then return {} end
        local t = jsonT(file.Read(LOG_FILE, "DATA") or "")
        if not istable(t) then return {} end
        local out = {}
        for _, rec in ipairs(t) do
            if istable(rec) then out[#out + 1] = rec end
        end
        return out
    end

    function F.AppendFireLog(rec)
        if not istable(rec) then return false end
        ensureDir()
        local list = F.LoadFireLog()
        table.insert(list, 1, rec)
        while #list > LOG_CAP do list[#list] = nil end
        local ok, txt = pcall(util.TableToJSON, list, true)
        if not ok or not isstring(txt) then return false end
        file.Write(LOG_FILE, txt)
        return true
    end

    local function countAround(origin)
        if not origin then return 0 end
        local n, r2 = 0, CLUSTER * CLUSTER
        for _, e in ipairs(ents.FindByClass("vfire")) do
            if IsValid(e) and e.GetPos and e:GetPos():DistToSqr(origin) <= r2 then
                n = n + 1
            end
        end
        return n
    end

    local function findInc(pos)
        if not pos then return nil end
        local best, bestD
        local r2 = CLUSTER * CLUSTER
        for _, inc in ipairs(F.Incidents) do
            if inc and not inc.out and inc.origin then
                local d = pos:DistToSqr(inc.origin)
                if d <= r2 and (not best or d < bestD) then best, bestD = inc, d end
            end
        end
        return best
    end

    function F.OpenIncident(pos, source)
        if not pos then return nil end
        local exist = findInc(pos)
        if exist then return exist end
        local id = F._nextInc
        F._nextInc = F._nextInc + 1
        local inc = {
            id = id,
            origin = Vector(pos.x, pos.y, pos.z),
            source = tostring(source or "fire"),
            peak = 0,
            cells = 0,
            started = CurTime(),
            lastNew = CurTime(),
            lastKill = 0,
            fought = false,
            localized = false,
            out = false,
            fighters = {},
        }
        F.Incidents[#F.Incidents + 1] = inc
        return inc
    end

    function F.NoteFight(ply, pos)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        pos = pos or (ply.GetEyeTrace and ply:GetEyeTrace().HitPos) or ply:GetPos()
        local inc = findInc(pos)
        if not inc then return end
        inc.fought = true
        inc.lastFight = CurTime()
        local key = plyKey(ply)
        if not key or key == "" then return end
        for _, f in ipairs(inc.fighters) do
            if f.key == key then f.nick = plyNick(ply) return end
        end
        inc.fighters[#inc.fighters + 1] = { key = key, nick = plyNick(ply) }
    end

    local function notifyCrew(inc, text, r, g, b)
        F.NotifyFire(text, r, g, b, inc and inc.origin)
        if not inc then return end
        for _, rec in ipairs(inc.fighters or {}) do
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and plyKey(p) == rec.key then
                    if GRM.Notify then GRM.Notify(p, text, r, g, b) end
                end
            end
        end
    end

    local function logEvent(inc, event)
        local fighters = {}
        for _, f in ipairs(inc.fighters or {}) do
            fighters[#fighters + 1] = { key = tostring(f.key or ""), nick = tostring(f.nick or "") }
        end
        local o = inc.origin or Vector(0, 0, 0)
        F.AppendFireLog({
            t = os.time(),
            map = tostring(game.GetMap() or ""),
            event = event,
            peak = math.floor(tonumber(inc.peak) or 0),
            cells = math.floor(tonumber(inc.cells) or 0),
            source = tostring(inc.source or ""),
            x = math.floor(o.x or 0),
            y = math.floor(o.y or 0),
            z = math.floor(o.z or 0),
            fighters = fighters,
            sec = math.floor(CurTime() - (inc.started or CurTime())),
        })
    end

    function F.MarkLocalized(inc)
        if not inc or inc.localized or inc.out then return false end
        inc.localized = true
        inc.localizedAt = CurTime()
        logEvent(inc, "localized")
        hook.Run("GRM_FireLocalized", inc.origin, inc)
        notifyCrew(inc, "Пожар локализован", 255, 190, 70)
        return true
    end

    function F.MarkExtinguished(inc)
        if not inc or inc.out then return false end
        inc.out = true
        inc.cells = 0
        inc.outAt = CurTime()
        if not inc.localized and inc.fought and (inc.peak or 0) >= 2 then
            inc.localized = true
        end
        logEvent(inc, "out")
        hook.Run("GRM_FireExtinguished", inc.origin, inc)
        notifyCrew(inc, "Пожар потушен", 100, 220, 130)
        local live = #ents.FindByClass("vfire")
        if live == 0 and GRM.Minimap and GRM.Minimap.RemoveTempPoint then
            GRM.Minimap.RemoveTempPoint("ПОЖАР")
        end
        return true
    end

    function F.RefreshIncidents(hintPos)
        if hintPos then F.OpenIncident(hintPos, "fire") end
        local now = CurTime()
        for _, inc in ipairs(F.Incidents) do
            if inc and not inc.out then
                local n = countAround(inc.origin)
                if n > (inc.cells or 0) then inc.lastNew = now end
                if n < (inc.cells or 0) then inc.lastKill = now end
                inc.cells = n
                if n > (inc.peak or 0) then inc.peak = n end
                if n == 0 and (inc.peak or 0) > 0 then
                    F.MarkExtinguished(inc)
                elseif not inc.localized and inc.fought
                    and (inc.peak or 0) >= 3
                    and n <= math.max(1, math.floor((inc.peak or 0) * 0.5))
                    and (now - (inc.lastNew or now)) >= 6 then
                    F.MarkLocalized(inc)
                end
            end
        end
        -- вычистить старые закрытые, чтобы таблица не росла
        if #F.Incidents > 24 then
            local keep = {}
            for _, inc in ipairs(F.Incidents) do
                if inc and (not inc.out or (now - (inc.outAt or 0)) < 180) then
                    keep[#keep + 1] = inc
                end
            end
            F.Incidents = keep
        end
    end

    hook.Add("vFireCreated", "GRM_Fire_Status", function(fire)
        if not IsValid(fire) then return end
        local pos = fire.GetPos and fire:GetPos() or nil
        if not pos then return end
        local src = fire._grmSource or "fire"
        local inc = F.OpenIncident(pos, src)
        if inc then
            inc.cells = countAround(inc.origin)
            if inc.cells > (inc.peak or 0) then inc.peak = inc.cells end
            inc.lastNew = CurTime()
        end
    end)

    hook.Add("vFireRemoved", "GRM_Fire_Status", function(fire)
        local pos
        if IsValid(fire) and fire.GetPos then pos = fire:GetPos() end
        if pos then
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:GetPos():DistToSqr(pos) <= 320 * 320 then
                    local w = ply:GetActiveWeapon()
                    local cls = IsValid(w) and w:GetClass() or ""
                    if cls == "weapon_grm_hose" or cls == "weapon_extinguisher" or cls == "weapon_firehose" then
                        F.NoteFight(ply, pos)
                    end
                end
            end
        end
        timer.Simple(0, function() F.RefreshIncidents(pos) end)
    end)

    hook.Add("Think", "GRM_Fire_StatusTick", function()
        if (F._statusAt or 0) > CurTime() then return end
        F._statusAt = CurTime() + 0.8
        if #F.Incidents == 0 then return end
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:KeyDown(IN_ATTACK) then
                local w = ply:GetActiveWeapon()
                local cls = IsValid(w) and w:GetClass() or ""
                if cls == "weapon_grm_hose" or cls == "weapon_extinguisher" or cls == "weapon_firehose" then
                    local tr = ply:GetEyeTrace()
                    F.NoteFight(ply, tr and tr.HitPos or ply:GetPos())
                end
            end
        end
        F.RefreshIncidents()
    end)

    print("[GRM Fire] Status: учёт тушения загружен")
end
