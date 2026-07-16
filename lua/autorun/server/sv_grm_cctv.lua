--[[--------------------------------------------------------------------
    GRM CCTV — server (Код 60)
    Реестр устройств, доступ, сеть, открытие UI, view switch, сейв.
----------------------------------------------------------------------]]

if CLIENT then return end

AddCSLuaFile("autorun/sh_grm_cctv_config.lua")
AddCSLuaFile("autorun/client/cl_grm_cctv.lua")
include("autorun/sh_grm_cctv_config.lua")

GRM = GRM or {}
GRM.CCTV = GRM.CCTV or {}
local CCTV = GRM.CCTV
local CFG = function() return CCTV.Config or {} end

CCTV.Devices = CCTV.Devices or {} -- [entIndex] = ent

local NET_OPEN_CAM   = "GRM_CCTV_OpenCam"
local NET_OPEN_MON   = "GRM_CCTV_OpenMon"
local NET_OPEN_SRV   = "GRM_CCTV_OpenSrv"
local NET_LIST       = "GRM_CCTV_List"
local NET_ACTION     = "GRM_CCTV_Action"
local NET_VIEW       = "GRM_CCTV_View"
local NET_VIEW_STOP  = "GRM_CCTV_ViewStop"
local NET_NOTIFY     = "GRM_CCTV_Notify"

util.AddNetworkString(NET_OPEN_CAM)
util.AddNetworkString(NET_OPEN_MON)
util.AddNetworkString(NET_OPEN_SRV)
util.AddNetworkString(NET_LIST)
util.AddNetworkString(NET_ACTION)
util.AddNetworkString(NET_VIEW)
util.AddNetworkString(NET_VIEW_STOP)
util.AddNetworkString(NET_NOTIFY)

-- ── utils ──────────────────────────────────────────────────
local function jsonT(txt)
    local ok, t = pcall(util.JSONToTable, txt, false, true)
    return (ok and istable(t)) and t or nil
end

local function notify(ply, ok, msg)
    if not IsValid(ply) then return end
    net.Start(NET_NOTIFY)
        net.WriteBool(ok and true or false)
        net.WriteString(string.sub(tostring(msg or ""), 1, 200))
    net.Send(ply)
    if GRM and isfunction(GRM.Notify) then
        local r, g, b = ok and 100 or 255, ok and 220 or 120, ok and 100 or 120
        GRM.Notify(ply, msg, r, g, b)
    end
end

local function steam64(ply)
    if not IsValid(ply) then return "" end
    local id = ply:SteamID64()
    if id and id ~= "0" then return id end
    return ply:SteamID() or ""
end

local function withinUse(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return false end
    local d = CFG().UseDistance or 140
    return ply:GetPos():DistToSqr(ent:GetPos()) <= (d + 40) * (d + 40)
end

local function classOf(ent)
    return IsValid(ent) and tostring(ent:GetClass() or "") or ""
end

local function isCCTVClass(cls)
    return cls == "grm_cctv_camera" or cls == "grm_cctv_monitor" or cls == "grm_cctv_server"
end

-- ── access ─────────────────────────────────────────────────
function CCTV.HasAccess(ply)
    if not IsValid(ply) then return false end
    local acc = CFG().Access or {}
    if acc.SuperAdminBypass ~= false and ply:IsSuperAdmin() then return true end
    local sid = steam64(ply)
    if istable(acc.AllowSteam) and (acc.AllowSteam[sid] or acc.AllowSteam[ply:SteamID()]) then
        return true
    end
    if istable(acc.AllowFactions) and Factions then
        local sid1 = ply:SteamID()
        for fname, allowed in pairs(acc.AllowFactions) do
            if allowed then
                local f = Factions[fname]
                if istable(f) and istable(f.Members) and (f.Members[sid1] or f.Members[sid]) then
                    return true
                end
            end
        end
    end
    return false
end

function CCTV.CanView(ply)
    if not IsValid(ply) then return false end
    if (CFG().Access or {}).PublicView then return true end
    return CCTV.HasAccess(ply)
end

function CCTV.CanConfigure(ply, ent)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    if not CCTV.HasAccess(ply) then return false end
    if IsValid(ent) then
        local owner = ent.GetOwnerSteam and ent:GetOwnerSteam() or ""
        if owner ~= "" and (owner == steam64(ply) or owner == ply:SteamID()) then
            return true
        end
    end
    return CCTV.HasAccess(ply)
end

-- ── registry ───────────────────────────────────────────────
function CCTV.RegisterDevice(ent)
    if not IsValid(ent) then return end
    CCTV.Devices[ent:EntIndex()] = ent
end

function CCTV.UnregisterDevice(ent)
    if not IsValid(ent) then return end
    CCTV.Devices[ent:EntIndex()] = nil
end

function CCTV.NetworkHasServer(networkID)
    networkID = CCTV.NormalizeNetwork(networkID)
    for _, ent in pairs(CCTV.Devices) do
        if IsValid(ent) and classOf(ent) == "grm_cctv_server"
            and CCTV.NormalizeNetwork(ent:GetNetworkID()) == networkID
            and ent:GetActive() then
            return true, ent
        end
    end
    return false, nil
end

function CCTV.ListCameras(networkID, onlyActive)
    networkID = CCTV.NormalizeNetwork(networkID)
    local out = {}
    for _, ent in pairs(CCTV.Devices) do
        if IsValid(ent) and classOf(ent) == "grm_cctv_camera"
            and CCTV.NormalizeNetwork(ent:GetNetworkID()) == networkID then
            if (not onlyActive) or ent:GetActive() then
                out[#out + 1] = ent
            end
        end
    end
    table.sort(out, function(a, b)
        return tostring(a:GetLabel()) < tostring(b:GetLabel())
    end)
    return out
end

local function countClass(cls)
    local n = 0
    for _, ent in pairs(CCTV.Devices) do
        if IsValid(ent) and classOf(ent) == cls then n = n + 1 end
    end
    return n
end

-- ── persistence (array of records; finding 65-safe) ────────
local function savePath()
    local dir = CFG().SaveDir or "grm_cctv"
    if not file.IsDir(dir, "DATA") then file.CreateDir(dir) end
    local map = string.lower(game.GetMap() or "unknown")
    map = string.gsub(map, "[^%w%-%_]", "_")
    return dir .. "/" .. map .. ".json"
end

local function vecT(v)
    if isvector and isvector(v) then return { x = v.x, y = v.y, z = v.z } end
    if istable(v) then return { x = tonumber(v.x) or 0, y = tonumber(v.y) or 0, z = tonumber(v.z) or 0 } end
    return { x = 0, y = 0, z = 0 }
end

local function angT(a)
    if isangle and isangle(a) then return { p = a.p, y = a.y, r = a.r } end
    if istable(a) then return { p = tonumber(a.p) or 0, y = tonumber(a.y) or 0, r = tonumber(a.r) or 0 } end
    return { p = 0, y = 0, r = 0 }
end

function CCTV.SavePermanent()
    local list = {}
    for _, ent in pairs(CCTV.Devices) do
        if IsValid(ent) and isCCTVClass(classOf(ent)) and ent:GetPermanent() then
            list[#list + 1] = {
                class = classOf(ent),
                model = ent:GetModel() or "",
                pos = vecT(ent:GetPos()),
                ang = angT(ent:GetAngles()),
                device_id = ent:GetDeviceID(),
                label = ent:GetLabel(),
                network = ent:GetNetworkID(),
                owner_steam = ent:GetOwnerSteam(),
                owner_name = ent:GetOwnerName(),
                active = (ent.GetActive and ent:GetActive()) or true,
                fov = (ent.GetCamFOV and ent:GetCamFOV()) or (CFG().DefaultFOV or 75),
            }
        end
    end
    local path = savePath()
    local ok, txt = pcall(util.TableToJSON, list, true)
    if not ok or not isstring(txt) then
        print("[GRM CCTV] SAVE fail: serialize")
        return false
    end
    file.Write(path, txt)
    local chk = file.Read(path, "DATA")
    if chk ~= txt then
        print("[GRM CCTV] SAVE fail: read-back mismatch " .. path)
        return false
    end
    print(("[GRM CCTV] SAVE ok: %d устройств -> data/%s"):format(#list, path))
    return true
end

function CCTV.LoadPermanent()
    local path = savePath()
    if not file.Exists(path, "DATA") then return 0 end
    local raw = file.Read(path, "DATA") or ""
    local t = jsonT(raw)
    if not istable(t) then
        local q = (CFG().SaveDir or "grm_cctv") .. "/corrupt_" .. os.time() .. ".txt"
        file.Write(q, raw)
        print("[GRM CCTV] LOAD: битый файл, карантин data/" .. q)
        return 0
    end
    local spawned = 0
    for _, rec in ipairs(t) do
        if istable(rec) and isstring(rec.class) and isCCTVClass(rec.class) then
            local pos = Vector(tonumber(rec.pos and rec.pos.x) or 0, tonumber(rec.pos and rec.pos.y) or 0, tonumber(rec.pos and rec.pos.z) or 0)
            local busy = false
            for _, e in ipairs(ents.FindInSphere(pos, 6)) do
                if IsValid(e) and classOf(e) == rec.class then busy = true break end
            end
            if not busy then
                local ent = ents.Create(rec.class)
                if IsValid(ent) then
                    ent:SetPos(pos)
                    ent:SetAngles(Angle(tonumber(rec.ang and rec.ang.p) or 0, tonumber(rec.ang and rec.ang.y) or 0, tonumber(rec.ang and rec.ang.r) or 0))
                    if isstring(rec.model) and rec.model ~= "" then ent:SetModel(rec.model) end
                    ent:Spawn()
                    ent:Activate()
                    if isstring(rec.device_id) and rec.device_id ~= "" then ent:SetDeviceID(rec.device_id) end
                    if isstring(rec.label) then ent:SetLabel(rec.label) end
                    if isstring(rec.network) then ent:SetNetworkID(CCTV.NormalizeNetwork(rec.network)) end
                    if isstring(rec.owner_steam) then ent:SetOwnerSteam(rec.owner_steam) end
                    if isstring(rec.owner_name) then ent:SetOwnerName(rec.owner_name) end
                    if ent.SetActive then ent:SetActive(rec.active ~= false) end
                    if ent.SetCamFOV then ent:SetCamFOV(CCTV.ClampFOV(rec.fov)) end
                    ent:SetPermanent(true)
                    local phys = ent:GetPhysicsObject()
                    if IsValid(phys) then phys:EnableMotion(false) end
                    spawned = spawned + 1
                end
            end
        end
    end
    print(("[GRM CCTV] LOAD: восстановлено %d устройств из data/%s"):format(spawned, path))
    return spawned
end

-- ── open menus ─────────────────────────────────────────────
function CCTV.OpenCameraMenu(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    if not withinUse(ply, ent) then return end
    if not CCTV.CanConfigure(ply, ent) then
        notify(ply, false, "Нет доступа к настройке камеры.")
        return
    end
    net.Start(NET_OPEN_CAM)
        net.WriteEntity(ent)
    net.Send(ply)
end

function CCTV.OpenServerMenu(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    if not withinUse(ply, ent) then return end
    if not CCTV.CanConfigure(ply, ent) then
        notify(ply, false, "Нет доступа к серверной стойке.")
        return
    end
    net.Start(NET_OPEN_SRV)
        net.WriteEntity(ent)
    net.Send(ply)
end

function CCTV.OpenMonitorMenu(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    if not withinUse(ply, ent) then return end
    if not CCTV.CanView(ply) then
        notify(ply, false, "Нет доступа к системе видеонаблюдения.")
        return
    end
    local netID = CCTV.NormalizeNetwork(ent:GetNetworkID())
    local hasSrv = CCTV.NetworkHasServer(netID)
    local cams = CCTV.ListCameras(netID, false)
    net.Start(NET_OPEN_MON)
        net.WriteEntity(ent)
        net.WriteString(netID)
        net.WriteBool(hasSrv)
        net.WriteBool(CCTV.CanConfigure(ply, ent))
        net.WriteUInt(math.min(#cams, 255), 8)
        for i = 1, math.min(#cams, 255) do
            local c = cams[i]
            net.WriteEntity(c)
            net.WriteString(string.sub(c:GetLabel() or "Камера", 1, 48))
            net.WriteString(string.sub(c:GetDeviceID() or "", 1, 40))
            net.WriteBool(c:GetActive())
            net.WriteUInt(CCTV.ClampFOV(c:GetCamFOV()), 8)
        end
    net.Send(ply)
end

local function sendList(ply, monitor)
    if not IsValid(ply) or not IsValid(monitor) then return end
    local netID = CCTV.NormalizeNetwork(monitor:GetNetworkID())
    local hasSrv = CCTV.NetworkHasServer(netID)
    local cams = CCTV.ListCameras(netID, false)
    net.Start(NET_LIST)
        net.WriteEntity(monitor)
        net.WriteString(netID)
        net.WriteBool(hasSrv)
        net.WriteUInt(math.min(#cams, 255), 8)
        for i = 1, math.min(#cams, 255) do
            local c = cams[i]
            net.WriteEntity(c)
            net.WriteString(string.sub(c:GetLabel() or "Камера", 1, 48))
            net.WriteString(string.sub(c:GetDeviceID() or "", 1, 40))
            net.WriteBool(c:GetActive())
            net.WriteUInt(CCTV.ClampFOV(c:GetCamFOV()), 8)
        end
    net.Send(ply)
end

-- ── actions from client ────────────────────────────────────
local VALID_ACTIONS = {
    set_label = true,
    set_network = true,
    set_active = true,
    set_fov = true,
    set_permanent = true,
    refresh_list = true,
    save_all = true,
    view_cam = true,
    stop_view = true,
}

net.Receive(NET_ACTION, function(_, ply)
    if not IsValid(ply) then return end
    local action = net.ReadString() or ""
    local ent = net.ReadEntity()
    if not VALID_ACTIONS[action] then return end

    if action == "refresh_list" then
        if IsValid(ent) and classOf(ent) == "grm_cctv_monitor" and withinUse(ply, ent) and CCTV.CanView(ply) then
            sendList(ply, ent)
        end
        return
    end

    if action == "save_all" then
        if not ply:IsSuperAdmin() then
            notify(ply, false, "Сохранение — только суперадмин.")
            return
        end
        local ok = CCTV.SavePermanent()
        notify(ply, ok, ok and "CCTV: permanent-устройства сохранены." or "CCTV: ошибка сохранения.")
        return
    end

    if action == "stop_view" then
        if ply._grmCCTVView then
            ply:SetViewEntity(nil)
            ply._grmCCTVView = nil
            ply._grmCCTVCam = nil
            net.Start(NET_VIEW_STOP)
            net.Send(ply)
        end
        return
    end

    if action == "view_cam" then
        local cam = net.ReadEntity()
        local monitor = ent
        if not IsValid(monitor) or classOf(monitor) ~= "grm_cctv_monitor" then return end
        if not withinUse(ply, monitor) then return end
        if not CCTV.CanView(ply) then
            notify(ply, false, "Нет доступа.")
            return
        end
        if not IsValid(cam) or classOf(cam) ~= "grm_cctv_camera" then
            notify(ply, false, "Камера недоступна.")
            return
        end
        local netID = CCTV.NormalizeNetwork(monitor:GetNetworkID())
        if CCTV.NormalizeNetwork(cam:GetNetworkID()) ~= netID then
            notify(ply, false, "Камера в другой сети.")
            return
        end
        if not cam:GetActive() then
            notify(ply, false, "Камера выключена.")
            return
        end
        if not CCTV.NetworkHasServer(netID) then
            notify(ply, false, "Нет активной серверной стойки в сети «" .. netID .. "».")
            return
        end
        local now = CurTime()
        if (ply._grmCCTVCD or 0) > now then return end
        ply._grmCCTVCD = now + (CFG().SwitchCooldown or 0.15)

        -- ViewEntity = камера; клиент рисует HUD оверлей.
        ply:SetViewEntity(cam)
        ply._grmCCTVView = true
        ply._grmCCTVCam = cam
        ply._grmCCTVMonitor = monitor
        net.Start(NET_VIEW)
            net.WriteEntity(cam)
            net.WriteEntity(monitor)
            net.WriteString(string.sub(cam:GetLabel() or "Камера", 1, 48))
            net.WriteString(netID)
            net.WriteUInt(CCTV.ClampFOV(cam:GetCamFOV()), 8)
        net.Send(ply)
        return
    end

    -- configure actions need entity
    if not IsValid(ent) or not isCCTVClass(classOf(ent)) then return end
    if not withinUse(ply, ent) then return end
    if not CCTV.CanConfigure(ply, ent) then
        notify(ply, false, "Нет прав на настройку.")
        return
    end

    if action == "set_label" then
        local label = string.sub(string.Trim(net.ReadString() or ""), 1, CFG().MaxLabelLen or 48)
        if label == "" then label = "Устройство" end
        ent:SetLabel(label)
        notify(ply, true, "Подпись: " .. label)
    elseif action == "set_network" then
        local nw = CCTV.NormalizeNetwork(net.ReadString())
        ent:SetNetworkID(nw)
        notify(ply, true, "Сеть: " .. nw)
    elseif action == "set_active" then
        if not ent.SetActive then return end
        local on = net.ReadBool()
        ent:SetActive(on)
        notify(ply, true, on and "Включено." or "Выключено.")
    elseif action == "set_fov" then
        if not ent.SetCamFOV then return end
        local fov = CCTV.ClampFOV(net.ReadUInt(8))
        ent:SetCamFOV(fov)
        notify(ply, true, "FOV: " .. tostring(fov))
    elseif action == "set_permanent" then
        if not ply:IsSuperAdmin() then
            notify(ply, false, "Permanent — только суперадмин.")
            return
        end
        local on = net.ReadBool()
        ent:SetPermanent(on)
        if on then
            local sid = steam64(ply)
            if ent:GetOwnerSteam() == "" then
                ent:SetOwnerSteam(sid)
                ent:SetOwnerName(ply:Nick())
            end
        end
        CCTV.SavePermanent()
        notify(ply, true, on and "Устройство в permanent-сейве." or "Снято с permanent.")
    end
end)

-- ── safety: stop view if far / invalid ─────────────────────
hook.Add("Think", "GRM_CCTV_ViewGuard", function()
    for _, ply in ipairs(player.GetAll()) do
        if ply._grmCCTVView then
            local mon = ply._grmCCTVMonitor
            local cam = ply._grmCCTVCam
            local bad = false
            if not IsValid(mon) or not IsValid(cam) then bad = true end
            if not bad and not withinUse(ply, mon) then bad = true end
            if not bad and not cam:GetActive() then bad = true end
            if not bad and not CCTV.NetworkHasServer(cam:GetNetworkID()) then bad = true end
            if bad then
                ply:SetViewEntity(nil)
                ply._grmCCTVView = nil
                ply._grmCCTVCam = nil
                ply._grmCCTVMonitor = nil
                net.Start(NET_VIEW_STOP)
                net.Send(ply)
            end
        end
    end
end)

hook.Add("PlayerDisconnected", "GRM_CCTV_Disconnect", function(ply)
    if IsValid(ply) then
        ply:SetViewEntity(nil)
        ply._grmCCTVView = nil
    end
end)

hook.Add("PlayerDeath", "GRM_CCTV_Death", function(ply)
    if IsValid(ply) and ply._grmCCTVView then
        ply:SetViewEntity(nil)
        ply._grmCCTVView = nil
        net.Start(NET_VIEW_STOP)
        net.Send(ply)
    end
end)

-- block weapon fire while viewing? optional soft lock via Move
hook.Add("StartCommand", "GRM_CCTV_Lock", function(ply, cmd)
    if not IsValid(ply) or not ply._grmCCTVView then return end
    cmd:RemoveKey(IN_ATTACK)
    cmd:RemoveKey(IN_ATTACK2)
    cmd:RemoveKey(IN_RELOAD)
end)

-- ── spawn helpers / limits ─────────────────────────────────
hook.Add("PlayerSpawnedSENT", "GRM_CCTV_Spawned", function(ply, ent)
    if not IsValid(ent) or not isCCTVClass(classOf(ent)) then return end
    local cls = classOf(ent)
    local cfg = CFG()
    if cls == "grm_cctv_camera" and countClass(cls) > (cfg.MaxCamerasPerNetwork or 32) * 4 then
        -- soft global cap
    end
    if IsValid(ply) then
        ent:SetOwnerSteam(steam64(ply))
        ent:SetOwnerName(ply:Nick())
    end
    CCTV.RegisterDevice(ent)
end)

-- ── load / save hooks ──────────────────────────────────────
hook.Add("InitPostEntity", "GRM_CCTV_Load", function()
    timer.Simple(2, function()
        CCTV.LoadPermanent()
    end)
end)

hook.Add("PostCleanupMap", "GRM_CCTV_Reload", function()
    timer.Simple(1, function()
        CCTV.LoadPermanent()
    end)
end)

hook.Add("ShutDown", "GRM_CCTV_ShutdownSave", function()
    CCTV.SavePermanent()
end)

-- console
concommand.Add("grm_cctv_save", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local ok = CCTV.SavePermanent()
    if IsValid(ply) then notify(ply, ok, ok and "CCTV saved." or "CCTV save failed.") end
end)

concommand.Add("grm_cctv_load", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local n = CCTV.LoadPermanent()
    if IsValid(ply) then notify(ply, true, "CCTV load: " .. tostring(n)) end
end)

concommand.Add("grm_cctv_list", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    local nCam, nMon, nSrv = 0, 0, 0
    for _, ent in pairs(CCTV.Devices) do
        if IsValid(ent) then
            local c = classOf(ent)
            if c == "grm_cctv_camera" then nCam = nCam + 1
            elseif c == "grm_cctv_monitor" then nMon = nMon + 1
            elseif c == "grm_cctv_server" then nSrv = nSrv + 1 end
        end
    end
    local msg = ("CCTV: cams=%d mon=%d srv=%d"):format(nCam, nMon, nSrv)
    print("[GRM CCTV] " .. msg)
    if IsValid(ply) then ply:ChatPrint(msg) end
end)

print("[GRM CCTV] server v1.0.0")
