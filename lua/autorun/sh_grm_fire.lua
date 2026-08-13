--[[--------------------------------------------------------------------
    GRM Fire v1.3.3 (Код 58)
    Серверная обвязка аддона grm_fire + vFire.
    Не содержит моделей/рукава — они в аддоне.
    Права, персист очагов, рандом по точкам, плита, оповещение.
    Не трогает: FFD, Q-меню, двери, принтер, пресс.
----------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Fire = GRM.Fire or {}
local F = GRM.Fire
F.Version = "1.3.3"

F.Config = F.Config or {
    StoveEnabled = true,
    RandomEnabled = true,
    RandomMinSec = 480,
    RandomMaxSec = 900,
    SpotCooldownSec = 2700,
    PersistTTL = 1800,
    MaxIncidents = 8,
    StoveNear = 200,
    StoveChanceNear = 0.008,
    StoveChanceAway = 0.024,
    AnnounceRadius = 420,
}

local function jsonT(txt)
    local ok, t = pcall(util.JSONToTable, txt, false, true)
    return (ok and istable(t)) and t or nil
end

local function tell(ply, msg, r, g, b)
    if IsValid(ply) and GRM.Notify then GRM.Notify(ply, msg, r or 220, g or 200, b or 90)
    elseif IsValid(ply) then ply:ChatPrint("[Пожар] " .. tostring(msg)) end
end

function F.AddonReady()
    return GRM_FireAddon == true
end

function F.VFireReady()
    return vFireInstalled == true and isfunction(CreateVFire)
end

function F.CanFight(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    return true
end

function F.CanFightPro(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    local AM = GRM.Fire and GRM.Fire.AccessManager
    if AM and AM.CanControl then return AM.CanControl(ply) == true end
    return false
end

function F.CanDispatch(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    local AM = GRM.Fire and GRM.Fire.AccessManager
    if AM and AM.CanView then return AM.CanView(ply) == true end
    return false
end

function F.CanManage(ply)
    if not IsValid(ply) then return false end
    return ply:IsSuperAdmin() == true
end

function F.IsBurning(pos)
    if not isvector(pos) then
        if IsValid(pos) and pos.GetPos then pos = pos:GetPos() else return false end
    end
    for _, ent in ipairs(ents.FindByClass("vfire")) do
        if IsValid(ent) and ent:GetPos():DistToSqr(pos) < 96 * 96 then return true end
    end
    return false
end

if SERVER then
    local DIR = "grm_fire"
    local dirty, lastSave = false, 0

    local function ensureDir()
        if not file.IsDir(DIR, "DATA") then file.CreateDir(DIR) end
    end

    local function activePath()
        return DIR .. "/active_" .. tostring(game.GetMap() or "nomap") .. ".json"
    end

    function F.Snapshot()
        local out = {}
        for _, ent in ipairs(ents.FindByClass("vfire")) do
            if not IsValid(ent) then
            else
                local p, n = ent:GetPos(), ent:GetForward()
                out[#out + 1] = {
                    x = p.x, y = p.y, z = p.z,
                    nx = n.x, ny = n.y, nz = n.z,
                    feed = math.floor(tonumber(ent.feed) or 80),
                    life = math.floor(tonumber(ent.life) or 20),
                    started = tonumber(ent._grmStarted) or os.time(),
                    source = tostring(ent._grmSource or "unknown"),
                }
            end
        end
        return out
    end

    function F.SaveActive(reason)
        ensureDir()
        local payload = { version = 1, incidents = F.Snapshot() }
        local ok, txt = pcall(util.TableToJSON, payload, true)
        if not ok or not isstring(txt) then
            print("[GRM Fire] SAVE fail serialize [" .. tostring(reason or "?") .. "]")
            return false
        end
        file.Write(activePath(), txt)
        local chk = file.Read(activePath(), "DATA")
        if chk ~= txt then
            print("[GRM Fire] SAVE read-back fail [" .. tostring(reason or "?") .. "]")
            return false
        end
        dirty = false
        lastSave = CurTime()
        print(("[GRM Fire] SAVE ok %d очагов [%s]"):format(#payload.incidents, tostring(reason or "")))
        return true
    end

    function F.MarkDirty()
        dirty = true
    end

    function F.LoadActive()
        ensureDir()
        local path = activePath()
        if not file.Exists(path, "DATA") then return 0 end
        local raw = file.Read(path, "DATA") or ""
        local t = jsonT(raw)
        if not istable(t) then
            local q = path .. ".corrupt." .. os.time()
            file.Write(q, raw)
            print("[GRM Fire] active битый — карантин " .. q)
            return 0
        end
        local n, now, ttl = 0, os.time(), tonumber(F.Config.PersistTTL) or 1800
        for _, rec in ipairs(istable(t.incidents) and t.incidents or {}) do
            if istable(rec) then
                local started = tonumber(rec.started) or now
                if now - started <= ttl and F.VFireReady() then
                    local pos = Vector(tonumber(rec.x) or 0, tonumber(rec.y) or 0, tonumber(rec.z) or 0)
                    local nrm = Vector(tonumber(rec.nx) or 0, tonumber(rec.ny) or 0, tonumber(rec.nz) or 1)
                    if nrm:LengthSqr() < 0.01 then nrm = Vector(0, 0, 1) end
                    nrm:Normalize()
                    local fire = CreateVFire(game.GetWorld(), pos, nrm, math.max(20, tonumber(rec.feed) or 80))
                    if IsValid(fire) then
                        fire._grmStarted = started
                        fire._grmSource = tostring(rec.source or "persist")
                        if fire.ChangeLife and rec.life then fire:ChangeLife(tonumber(rec.life) or fire.life) end
                        n = n + 1
                    end
                end
            end
        end
        print(("[GRM Fire] LOAD %d очагов с диска"):format(n))
        return n
    end

    local announced = {}
    function F.Announce(pos, source)
        if not isvector(pos) then return end
        local key = math.floor(pos.x / 512) .. ":" .. math.floor(pos.y / 512)
        if announced[key] and CurTime() - announced[key] < 75 then return end
        announced[key] = CurTime()
        local text = "ПОЖАР"
        if source == "stove" then text = "ПОЖАР: плита"
        elseif source == "random" then text = "ПОЖАР: очаг"
        elseif source == "admin" then text = "ПОЖАР (админ)" end
        hook.Run("GRM_FireStarted", pos, source)
        if GRM.Alarm and GRM.Alarm.Log then
            pcall(GRM.Alarm.Log, "main", "fire", text)
        end
        if F.NotifyFactions then F.NotifyFactions("⚠ " .. text, pos) end
        if GRM.Minimap and GRM.Minimap.AddTempPoint then
            GRM.Minimap.AddTempPoint("ПОЖАР", pos, 120)
            if GRM.Minimap.SendTo then
                for _, p in ipairs(player.GetAll()) do
                    if F.CanDispatch(p) or p:IsSuperAdmin() then GRM.Minimap.SendTo(p) end
                end
            end
        end
        print("[GRM Fire] " .. text .. " @ " .. tostring(pos))
    end

    function F.Ignite(pos, source, starter)
        if not F.VFireReady() then return nil, "vFire не загружен" end
        if #ents.FindByClass("vfire") >= (tonumber(F.Config.MaxIncidents) or 8) * 12 then
            return nil, "лимит очагов"
        end
        source = tostring(source or "system")
        local nrm = Vector(0, 0, 1)
        local parent = game.GetWorld()
        if isentity(pos) and IsValid(pos) then
            parent = pos
            local p = pos:WorldSpaceCenter()
            local tr = util.TraceLine({ start = p + Vector(0, 0, 8), endpos = p - Vector(0, 0, 64), filter = pos })
            pos = (tr.Hit and tr.HitPos) or p
            nrm = tr.Hit and tr.HitNormal or nrm
        elseif isvector(pos) then
            local tr = util.TraceLine({ start = pos + Vector(0, 0, 16), endpos = pos - Vector(0, 0, 80) })
            if tr.Hit then
                pos = tr.HitPos
                nrm = tr.HitNormal
                if IsValid(tr.Entity) and not tr.Entity:IsWorld() then parent = tr.Entity end
            end
        else
            return nil, "нет позиции"
        end
        local fire = CreateVFire(parent, pos, nrm, 160)
        if IsValid(fire) then
            fire._grmStarted = os.time()
            fire._grmSource = source
            fire._grmStarter = tostring(starter or "")
            F.Announce(pos, source)
            F.MarkDirty()
        end
        return fire
    end

    function F.ExtinguishAround(pos, radius)
        radius = tonumber(radius) or 128
        local n = 0
        for _, ent in ipairs(ents.FindInSphere(pos, radius)) do
            if IsValid(ent) and ent:GetClass() == "vfire" then
                ent:Remove()
                n = n + 1
            end
        end
        if n > 0 then F.MarkDirty() end
        return n
    end

    -- ── права аддона ────────────────────────────────────────
    hook.Add("GRM_FireAddon_CanHose", "GRM_Fire", function(ply)
        if F.CanFightPro(ply) then return end
        return false
    end)
    hook.Add("GRM_FireAddon_HydrantUse", "GRM_Fire", function(ply)
        if F.CanFightPro(ply) then return end
        return false
    end)
    hook.Add("GRM_FireAddon_PumpUse", "GRM_Fire", function(ply)
        if F.CanFightPro(ply) then return end
        return false
    end)
    hook.Add("GRM_FireAddon_HoseNodeUse", "GRM_Fire", function(ply)
        if F.CanFightPro(ply) then return end
        return false
    end)

    hook.Add("GRM_FireAddon_Placed", "GRM_Fire_AutoPerm", function(ent, ply)
        if not IsValid(ent) then return end
        if GRM.Perm and GRM.Perm.RegisterClass then
            GRM.Perm.RegisterClass(ent:GetClass(), true)
        end
        if GRM.Perm and GRM.Perm.Add and IsValid(ply) then
            local ok, msg = GRM.Perm.Add(ply, ent, { ownerKind = "server", label = "fire" })
            if ok then tell(ply, "Закреплено на карте (перм).", 100, 220, 130)
            elseif msg then tell(ply, "Перм: " .. tostring(msg) .. " — поставьте /permadd.", 255, 190, 90) end
        end
    end)

    hook.Add("vFireCreated", "GRM_Fire_Track", function(fire)
        if not IsValid(fire) then return end
        fire._grmStarted = fire._grmStarted or os.time()
        F.MarkDirty()
        local pos = fire:GetPos()
        local near = 0
        for _, o in ipairs(ents.FindByClass("vfire")) do
            if o ~= fire and IsValid(o) and o:GetPos():DistToSqr(pos) < 400 * 400 then
                near = near + 1
            end
        end
        if near == 0 then F.Announce(pos, fire._grmSource or "fire") end
    end)
    hook.Add("vFireRemoved", "GRM_Fire_Track", function()
        F.MarkDirty()
        if #ents.FindByClass("vfire") == 0 and GRM.Minimap and GRM.Minimap.RemoveTempPoint then
            GRM.Minimap.RemoveTempPoint("ПОЖАР")
        end
    end)

    -- ── перм классов + данные ───────────────────────────────
    local function installPerm()
        if not (GRM.Perm and GRM.Perm.RegisterClass) then return end
        for _, cls in ipairs({ "grm_fire_hydrant", "grm_fire_pump", "grm_fire_cabinet", "grm_fire_spot", "grm_fire_ladder" }) do
            GRM.Perm.RegisterClass(cls, true)
        end
        if GRM.PermData then
            GRM.PermData.Extract["grm_fire_hydrant"] = function(ent)
                return { open = ent.GetOpen and ent:GetOpen() == true, ports = ent.GetPortsMax and ent:GetPortsMax() or 2 }
            end
            GRM.PermData.Apply["grm_fire_hydrant"] = function(ent, data)
                if istable(data) and ent.SetOpen then ent:SetOpen(data.open == true) end
                if istable(data) and data.ports and ent.SetPortsMax then ent:SetPortsMax(tonumber(data.ports) or 2) end
            end
            GRM.PermData.Extract["grm_fire_pump"] = function(ent)
                return {
                    tank = ent.GetTank and ent:GetTank() or 0,
                    tankmax = ent.GetTankMax and ent:GetTankMax() or 4000,
                    foam = ent.GetFoam and ent:GetFoam() or 0,
                    foammax = ent.GetFoamMax and ent:GetFoamMax() or 500,
                    powder = ent.GetPowder and ent:GetPowder() or 0,
                    powdermax = ent.GetPowderMax and ent:GetPowderMax() or 250,
                    slots = ent.GetHosesMax and ent:GetHosesMax() or 4,
                }
            end
            GRM.PermData.Apply["grm_fire_pump"] = function(ent, data)
                if not istable(data) then return end
                if data.tankmax and ent.SetTankMax then ent:SetTankMax(math.min(20000, tonumber(data.tankmax) or 4000)) end
                if data.tank and ent.SetTank then ent:SetTank(math.max(0, tonumber(data.tank) or 0)) end
                if data.foammax and ent.SetFoamMax then ent:SetFoamMax(tonumber(data.foammax) or 500) end
                if data.foam and ent.SetFoam then ent:SetFoam(tonumber(data.foam) or 0) end
                if data.powdermax and ent.SetPowderMax then ent:SetPowderMax(tonumber(data.powdermax) or 250) end
                if data.powder and ent.SetPowder then ent:SetPowder(tonumber(data.powder) or 0) end
                if data.slots and ent.SetHosesMax then ent:SetHosesMax(tonumber(data.slots) or 4) end
            end
            GRM.PermData.Extract["grm_fire_spot"] = function(ent)
                return { weight = ent.GetWeight and ent:GetWeight() or 1, label = ent.GetSpotLabel and ent:GetSpotLabel() or "" }
            end
            GRM.PermData.Apply["grm_fire_spot"] = function(ent, data)
                if not istable(data) then return end
                if data.weight and ent.SetWeight then ent:SetWeight(math.max(1, tonumber(data.weight) or 1)) end
                if isstring(data.label) and ent.SetSpotLabel then ent:SetSpotLabel(data.label) end
            end
        end
    end
    timer.Simple(0, installPerm)
    timer.Simple(2, installPerm)

    -- ── рандом ──────────────────────────────────────────────
    local function pickSpot()
        local spots, weights = {}, {}
        local now = os.time()
        local cd = tonumber(F.Config.SpotCooldownSec) or 2700
        for _, ent in ipairs(ents.FindByClass("grm_fire_spot")) do
            if IsValid(ent) and not F.IsBurning(ent:GetPos()) then
                local last = ent.GetLastIgnite and tonumber(ent:GetLastIgnite()) or 0
                if last == 0 or now - last >= cd then
                    spots[#spots + 1] = ent
                    weights[#weights + 1] = math.max(1, ent.GetWeight and ent:GetWeight() or 1)
                end
            end
        end
        if #spots == 0 then return nil end
        local sum = 0
        for i = 1, #weights do sum = sum + weights[i] end
        local roll = math.Rand(0, sum)
        for i = 1, #spots do
            roll = roll - weights[i]
            if roll <= 0 then return spots[i] end
        end
        return spots[#spots]
    end

    local function scheduleRandom()
        if not F.Config.RandomEnabled then return end
        local a = tonumber(F.Config.RandomMinSec) or 480
        local b = tonumber(F.Config.RandomMaxSec) or 900
        if b < a then b = a end
        timer.Create("GRM_Fire_Random", math.Rand(a, b), 1, function()
            if F.Config.RandomEnabled and F.VFireReady() then
                local live = #ents.FindByClass("vfire")
                if live < (tonumber(F.Config.MaxIncidents) or 8) * 6 then
                    local spot = pickSpot()
                    if IsValid(spot) then
                        if spot.IgniteSpot then
                            local fire = spot:IgniteSpot(180, "system")
                            if IsValid(fire) then
                                fire._grmSource = "random"
                                fire._grmStarted = os.time()
                            end
                        else
                            F.Ignite(spot:GetPos(), "random", "system")
                        end
                    end
                end
            end
            scheduleRandom()
        end)
    end

    -- ── плита ───────────────────────────────────────────────
    timer.Create("GRM_Fire_Stove", 2, 0, function()
        if not F.Config.StoveEnabled or not F.VFireReady() then return end
        for _, stove in ipairs(ents.FindByClass("grm_food_stove")) do
            if IsValid(stove) and stove.GetStoveState and stove:GetStoveState() == 1 then
                if F.IsBurning(stove:GetPos()) then
                else
                    local near = false
                    local r = tonumber(F.Config.StoveNear) or 200
                    for _, p in ipairs(player.GetAll()) do
                        if IsValid(p) and p:Alive() and p:GetPos():DistToSqr(stove:GetPos()) <= r * r then
                            near = true
                            break
                        end
                    end
                    local ch = near and (F.Config.StoveChanceNear or 0.008) or (F.Config.StoveChanceAway or 0.024)
                    if math.Rand(0, 1) < ch then
                        if stove.SetStoveState then stove:SetStoveState(0) end
                        if stove.SetStoveRecipe then stove:SetStoveRecipe("") end
                        F.Ignite(stove, "stove", "system")
                    end
                end
            end
        end
    end)

    timer.Create("GRM_Fire_Autosave", 15, 0, function()
        if dirty and CurTime() - lastSave > 10 then F.SaveActive("autosave") end
    end)

    hook.Add("ShutDown", "GRM_Fire_Save", function() F.SaveActive("shutdown") end)
    hook.Add("InitPostEntity", "GRM_Fire_Boot", function()
        timer.Simple(3, function()
            F.LoadActive()
            scheduleRandom()
        end)
    end)
    hook.Add("PostCleanupMap", "GRM_Fire_Cleanup", function()
        timer.Simple(2, function() F.LoadActive() end)
    end)

    hook.Add("PlayerSay", "GRM_Fire_AdminChat", function(ply, text)
        local t = string.lower(string.Trim(tostring(text or "")))
        if t == "/fire_ignite" or t == "!fire_ignite" then
            if not ply:IsSuperAdmin() then tell(ply, "Только суперадмин.", 255, 100, 100) return "" end
            local tr = ply:GetEyeTrace()
            F.Ignite(tr.HitPos, "admin", (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(ply)) or ply:SteamID64())
            tell(ply, "Очаг создан.", 100, 220, 130)
            return ""
        end
        if t == "/fire_kill" or t == "!fire_kill" then
            if not ply:IsSuperAdmin() then tell(ply, "Только суперадмин.", 255, 100, 100) return "" end
            local n = F.ExtinguishAround(ply:GetEyeTrace().HitPos, 180)
            tell(ply, "Погашено клеток: " .. tostring(n), 100, 220, 255)
            return ""
        end
    end)

    concommand.Add("grm_fire_ignite", function(ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        F.Ignite(ply:GetEyeTrace().HitPos, "admin", ply:SteamID64())
    end)
    concommand.Add("grm_fire_kill", function(ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        F.ExtinguishAround(ply:GetEyeTrace().HitPos, 180)
    end)

    print("[GRM Fire] v" .. F.Version .. " (Код 58) серверная обвязка")
end
