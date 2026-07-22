--[[--------------------------------------------------------------------
    GRM Alarm — server (Код 63)
    Сети, режимы, скан датчиков, сирена, логи, персист.
----------------------------------------------------------------------]]

if CLIENT then return end

AddCSLuaFile("autorun/sh_grm_alarm_config.lua")
AddCSLuaFile("autorun/client/cl_grm_alarm.lua")
include("autorun/sh_grm_alarm_config.lua")

GRM = GRM or {}
GRM.Alarm = GRM.Alarm or {}
local A = GRM.Alarm
local CFG = function() return A.Config or {} end

A.Devices = A.Devices or {} -- [entIndex] = ent
A.Logs = A.Logs or {}       -- [networkId] = { {t, kind, text, name, sid} }
A.Sirens = A.Sirens or {}   -- [hubIndex] = { patch, stopAt }
A.SpeakerPatches = A.SpeakerPatches or {} -- Код 89: [speakerIndex] = patch

local NET_OPEN_DEV = "GRM_Alarm_OpenDev"
local NET_OPEN_TRM = "GRM_Alarm_OpenTrm"
local NET_ACT      = "GRM_Alarm_Act"
local NET_NOTIFY   = "GRM_Alarm_Notify"
local NET_STATE    = "GRM_Alarm_State" -- push mode/alarm to clients near?

util.AddNetworkString(NET_OPEN_DEV)
util.AddNetworkString(NET_OPEN_TRM)
util.AddNetworkString(NET_ACT)
util.AddNetworkString(NET_NOTIFY)
util.AddNetworkString(NET_STATE)

local function jsonT(txt)
    local ok, t = pcall(util.JSONToTable, txt, false, true)
    return (ok and istable(t)) and t or nil
end

local function notify(ply, ok, msg)
    if not IsValid(ply) then return end
    net.Start(NET_NOTIFY)
        net.WriteBool(ok and true or false)
        net.WriteString(string.sub(tostring(msg or ""), 1, 220))
    net.Send(ply)
    if GRM.Notify then
        GRM.Notify(ply, msg, ok and 100 or 255, ok and 220 or 100, ok and 100 or 100)
    end
end

local function steam64(ply)
    if not IsValid(ply) then return "" end
    local id = ply:SteamID64()
    if id and id ~= "0" then return id end
    return ply:SteamID() or ""
end

local function classOf(ent)
    return IsValid(ent) and tostring(ent:GetClass() or "") or ""
end

local function isAlarmClass(cls)
    -- Код 89: динамик сирены — полноценное устройство сети
    return cls == "grm_alarm_sensor" or cls == "grm_alarm_hub"
        or cls == "grm_alarm_terminal" or cls == "grm_alarm_speaker"
end

local function withinUse(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return false end
    local d = CFG().UseDistance or 140
    return ply:GetPos():DistToSqr(ent:GetPos()) <= (d + 40) * (d + 40)
end

-- ── rights (overridden by access manager) ──────────────────
function A.CanView(ply)
    if not IsValid(ply) then return false end
    if CFG().SuperAdminBypass ~= false and ply:IsSuperAdmin() then return true end
    if A.AccessManager and A.AccessManager.CanView then return A.AccessManager.CanView(ply) end
    return ply:IsSuperAdmin()
end

function A.CanControl(ply)
    if not IsValid(ply) then return false end
    if CFG().SuperAdminBypass ~= false and ply:IsSuperAdmin() then return true end
    if A.AccessManager and A.AccessManager.CanControl then return A.AccessManager.CanControl(ply) end
    return ply:IsSuperAdmin()
end

function A.RegisterDevice(ent)
    if not IsValid(ent) then return end
    A.Devices[ent:EntIndex()] = ent
end

function A.UnregisterDevice(ent)
    if not IsValid(ent) then return end
    A.Devices[ent:EntIndex()] = nil
end

local function devicesOf(networkID, classFilter)
    networkID = A.NormalizeNetwork(networkID)
    local out = {}
    for _, ent in pairs(A.Devices) do
        if IsValid(ent) and A.NormalizeNetwork(ent:GetNetworkID()) == networkID then
            if not classFilter or classOf(ent) == classFilter then
                out[#out + 1] = ent
            end
        end
    end
    return out
end

function A.GetHub(networkID)
    local hubs = devicesOf(networkID, "grm_alarm_hub")
    -- prefer one that exists; if multiple, first
    return hubs[1]
end

function A.GetMode(networkID)
    local hub = A.GetHub(networkID)
    if IsValid(hub) then return A.ClampMode(hub:GetMode()) end
    return A.MODE_OFF
end

-- ── logging ────────────────────────────────────────────────
local function ensureDir()
    local dir = CFG().SaveDir or "grm_alarm"
    if not file.IsDir(dir, "DATA") then file.CreateDir(dir) end
    if not file.IsDir(dir .. "/logs", "DATA") then file.CreateDir(dir .. "/logs") end
    return dir
end

function A.Log(networkID, kind, text, ply)
    networkID = A.NormalizeNetwork(networkID)
    A.Logs[networkID] = A.Logs[networkID] or {}
    local entry = {
        t = os.time(),
        kind = tostring(kind or "info"),
        text = tostring(text or ""),
        name = IsValid(ply) and ply:Nick() or "",
        sid = IsValid(ply) and steam64(ply) or "",
    }
    local list = A.Logs[networkID]
    list[#list + 1] = entry
    local maxL = CFG().MaxLogLinesMemory or 400
    while #list > maxL do table.remove(list, 1) end

    -- append JSONL
    local dir = ensureDir()
    local day = os.date("%Y-%m-%d", entry.t)
    local path = dir .. "/logs/" .. networkID .. "_" .. day .. ".jsonl"
    local ok, line = pcall(util.TableToJSON, entry, false)
    if ok and isstring(line) then
        local prev = file.Exists(path, "DATA") and (file.Read(path, "DATA") or "") or ""
        file.Write(path, prev .. line .. "\n")
    end
end

function A.GetLogs(networkID, limit)
    networkID = A.NormalizeNetwork(networkID)
    local list = A.Logs[networkID] or {}
    limit = math.floor(tonumber(limit) or 80)
    local out = {}
    for i = #list, math.max(1, #list - limit + 1), -1 do
        out[#out + 1] = list[i]
    end
    return out
end

-- ── siren ──────────────────────────────────────────────────
local syncSpeakers -- Код 89 (форвард-декларация, урок 97-хотфикса)

function A.StopSiren(hub)
    if not IsValid(hub) then return end
    local idx = hub:EntIndex()
    local s = A.Sirens[idx]
    if s and s.patch then
        s.patch:Stop()
        s.patch = nil
    end
    A.Sirens[idx] = nil
    hub:SetAlarmActive(false)
    if syncSpeakers then syncSpeakers(hub:GetNetworkID()) end
end

function A.StartSiren(hub, reason, ply)
    if not IsValid(hub) then return end
    local cfg = CFG()
    A.StopSiren(hub)
    hub:SetAlarmActive(true)
    local soundPath = cfg.SirenSound or "ambient/alarms/combine_bank_alarm_loop4.wav"
    local patch = CreateSound(hub, soundPath)
    if patch then
        patch:SetSoundLevel(tonumber(cfg.SirenLevel) or 80)
        patch:PlayEx(tonumber(cfg.SirenVolume) or 1, 100)
    end
    local dur = tonumber(cfg.SirenDuration) or 45
    local stopAt = dur > 0 and (CurTime() + dur) or 0
    A.Sirens[hub:EntIndex()] = { patch = patch, stopAt = stopAt }
    A.Log(hub:GetNetworkID(), "alarm", "ТРЕВОГА: " .. tostring(reason or "?"), ply)
    print(("[GRM Alarm] ALARM net=%s hub=%s reason=%s"):format(
        tostring(hub:GetNetworkID()), tostring(hub:GetDeviceID()), tostring(reason)))
    if syncSpeakers then syncSpeakers(hub:GetNetworkID()) end
end

function A.SetMode(networkID, mode, ply)
    mode = A.ClampMode(mode)
    networkID = A.NormalizeNetwork(networkID)
    local hub = A.GetHub(networkID)
    if not IsValid(hub) then return false, "Нет блока коммутации в сети «" .. networkID .. "»" end
    hub:SetMode(mode)
    if mode ~= A.MODE_ARMED then
        A.StopSiren(hub)
    end
    A.Log(networkID, "mode", "Режим → " .. A.ModeName(mode), ply)
    -- update sensor counts on hubs
    local sensors = devicesOf(networkID, "grm_alarm_sensor")
    hub:SetSensorCount(#sensors)
    return true, mode
end

function A.ResetAlarm(networkID, ply)
    networkID = A.NormalizeNetwork(networkID)
    local hub = A.GetHub(networkID)
    if not IsValid(hub) then return false end
    A.StopSiren(hub)
    A.Log(networkID, "reset", "Сброс тревоги", ply)
    return true
end

-- ── Код 89: динамики сирены ────────────────────────────────
-- Звучат, пока активна тревога в их сети; Active=false — динамик молчит.
-- Синхронизация событийная (старт/стоп сирены хаба, смена режима/активности)
-- + сторожевой прогон в скан-тикере (лента событий не теряется).
local function stopSpeakerPatch(ent)
    local idx = ent:EntIndex()
    local p = A.SpeakerPatches[idx]
    if p then p:Stop() end
    A.SpeakerPatches[idx] = nil
end
A.StopSpeakerPatch = stopSpeakerPatch

syncSpeakers = function(networkID)
    networkID = A.NormalizeNetwork(networkID)
    local hub = A.GetHub(networkID)
    local alarmOn = IsValid(hub) and hub:GetAlarmActive() == true
    for _, ent in ipairs(devicesOf(networkID, "grm_alarm_speaker")) do
        local idx = ent:EntIndex()
        local playing = A.SpeakerPatches[idx] ~= nil
        local should = alarmOn and ent:GetActive() == true
        if should and not playing then
            local cfg = CFG()
            local soundPath = cfg.SirenSound or "ambient/alarms/combine_bank_alarm_loop4.wav"
            local patch = CreateSound(ent, soundPath)
            if patch then
                patch:SetSoundLevel(tonumber(cfg.SirenLevel) or 80)
                patch:PlayEx(tonumber(cfg.SirenVolume) or 1, 100)
                A.SpeakerPatches[idx] = patch
            end
        elseif playing and not should then
            stopSpeakerPatch(ent)
        end
    end
end

local function syncAllSpeakers()
    -- собираем сети из живых динамиков + сети с играющими патчами
    local nets = {}
    for _, ent in pairs(A.Devices) do
        if IsValid(ent) and classOf(ent) == "grm_alarm_speaker" then
            nets[A.NormalizeNetwork(ent:GetNetworkID())] = true
        end
    end
    for n in pairs(nets) do syncSpeakers(n) end
    -- патчи-сироты (динамик удалён, патч остался)
    for idx, patch in pairs(A.SpeakerPatches) do
        local ent = Entity(idx)
        if not IsValid(ent) then
            if patch then patch:Stop() end
            A.SpeakerPatches[idx] = nil
        end
    end
end
A._speakerSync = syncSpeakers      -- тест-экспорт
A._speakerSyncAll = syncAllSpeakers

-- ── sensor scan ────────────────────────────────────────────
local lastScan = 0
hook.Add("Think", "GRM_Alarm_Scan", function()
    local now = CurTime()
    local interval = tonumber(CFG().ScanInterval) or 0.35
    if now - lastScan < interval then return end
    lastScan = now

    for idx, s in pairs(A.Sirens) do
        if s.stopAt and s.stopAt > 0 and now >= s.stopAt then
            local hub = Entity(idx)
            if IsValid(hub) then
                A.StopSiren(hub)
            else
                if s.patch then s.patch:Stop() end
                A.Sirens[idx] = nil
            end
        end
    end

    -- Код 89: сторожевой прогон динамиков сирены (restore/спавн/смена сети)
    if syncAllSpeakers then syncAllSpeakers() end

    local cd = tonumber(CFG().TriggerCooldown) or 4
    for _, sensor in pairs(A.Devices) do
        if IsValid(sensor) and classOf(sensor) == "grm_alarm_sensor" and sensor:GetActive() then
            local netID = A.NormalizeNetwork(sensor:GetNetworkID())
            local hub = A.GetHub(netID)
            if IsValid(hub) then
                local mode = A.ClampMode(hub:GetMode())
                if mode ~= A.MODE_OFF then
                    local radius = math.Clamp(tonumber(sensor:GetRadius()) or 220,
                        tonumber(CFG().MinSensorRadius) or 64,
                        tonumber(CFG().MaxSensorRadius) or 800)
                    local origin = sensor:GetPos()
                    for _, ply in ipairs(player.GetAll()) do
                        if IsValid(ply) and ply:Alive() and origin:DistToSqr(ply:GetPos()) <= radius * radius then
                            -- Игнор «своих»: доступ управления сигналкой / door friendly / warrant force
                            local friendly = false
                            if GRM.Doors and GRM.Doors.IsFriendlyForAlarm then
                                friendly = GRM.Doors.IsFriendlyForAlarm(ply, netID) == true
                            elseif A.CanControl and A.CanControl(ply) then
                                friendly = true
                            end
                            if not friendly then
                                local last = tonumber(sensor:GetLastTrigger()) or 0
                                if now - last >= cd then
                                    local tr = util.TraceLine({
                                        start = origin + Vector(0, 0, 8),
                                        endpos = ply:EyePos(),
                                        filter = { sensor, ply },
                                        mask = MASK_SOLID_BRUSHONLY,
                                    })
                                    if not tr.Hit then
                                        sensor:SetLastTrigger(now)
                                        local text = string.format("Движение: %s @ %s (r=%d)",
                                            ply:Nick(),
                                            sensor:GetLabel() ~= "" and sensor:GetLabel() or sensor:GetDeviceID(),
                                            radius)
                                        if mode == A.MODE_PASSIVE then
                                            A.Log(netID, "motion", text .. " [пассив]", ply)
                                        elseif mode == A.MODE_ARMED then
                                            A.Log(netID, "motion", text .. " [охрана]", ply)
                                            if not hub:GetAlarmActive() then
                                                A.StartSiren(hub, text, ply)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- ── persistence (permanent devices) ────────────────────────
local function savePath()
    local dir = ensureDir()
    local map = string.lower(game.GetMap() or "unknown")
    map = string.gsub(map, "[^%w%-%_]", "_")
    return dir .. "/" .. map .. ".json"
end

-- Код 89: defensive-вариант как в CCTV — если компоненты пришли таблицей
-- (обёртки/восстановленные энтити), позиция не затирается нулями.
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

function A.SavePermanent()
    local list = {}
    for _, ent in pairs(A.Devices) do
        if IsValid(ent) and isAlarmClass(classOf(ent)) and ent:GetPermanent() then
            local rec = {
                class = classOf(ent),
                model = ent:GetModel() or "",
                pos = vecT(ent:GetPos()),
                ang = angT(ent:GetAngles()),
                device_id = ent:GetDeviceID(),
                label = ent:GetLabel(),
                network = ent:GetNetworkID(),
                owner_steam = ent:GetOwnerSteam(),
            }
            if classOf(ent) == "grm_alarm_sensor" then
                rec.radius = ent:GetRadius()
                rec.active = ent:GetActive()
            elseif classOf(ent) == "grm_alarm_speaker" then
                rec.active = ent:GetActive() -- Код 89
            elseif classOf(ent) == "grm_alarm_hub" then
                rec.mode = ent:GetMode()
            end
            list[#list + 1] = rec
        end
    end
    local path = savePath()
    local ok, txt = pcall(util.TableToJSON, list, true)
    if not ok or not isstring(txt) then return false end
    file.Write(path, txt)
    if file.Read(path, "DATA") ~= txt then return false end
    print(("[GRM Alarm] SAVE permanent: %d → data/%s"):format(#list, path))
    return true
end

function A.LoadPermanent()
    local path = savePath()
    if not file.Exists(path, "DATA") then return 0 end
    local t = jsonT(file.Read(path, "DATA") or "")
    if not istable(t) then return 0 end
    local n = 0
    for _, rec in ipairs(t) do
        if istable(rec) and isstring(rec.class) and isAlarmClass(rec.class) then
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
                    if isstring(rec.device_id) then ent:SetDeviceID(rec.device_id) end
                    if isstring(rec.label) then ent:SetLabel(rec.label) end
                    if isstring(rec.network) then ent:SetNetworkID(A.NormalizeNetwork(rec.network)) end
                    if isstring(rec.owner_steam) then ent:SetOwnerSteam(rec.owner_steam) end
                    if classOf(ent) == "grm_alarm_sensor" then
                        if rec.radius then ent:SetRadius(tonumber(rec.radius) or 220) end
                        ent:SetActive(rec.active ~= false)
                    elseif classOf(ent) == "grm_alarm_speaker" then
                        if rec.active ~= nil then ent:SetActive(rec.active == true) end -- Код 89
                    elseif classOf(ent) == "grm_alarm_hub" then
                        ent:SetMode(A.ClampMode(rec.mode or 1))
                    end
                    ent:SetPermanent(true)
                    local phys = ent:GetPhysicsObject()
                    if IsValid(phys) then phys:EnableMotion(false) end
                    n = n + 1
                end
            end
        end
    end
    print(("[GRM Alarm] LOAD permanent: %d"):format(n))
    return n
end

-- ── menus ──────────────────────────────────────────────────
function A.OpenDeviceMenu(ply, ent, kind)
    if not IsValid(ply) or not IsValid(ent) then return end
    if not withinUse(ply, ent) then return end
    if not A.CanControl(ply) then
        notify(ply, false, "Нет доступа к оборудованию сигнализации.")
        return
    end
    net.Start(NET_OPEN_DEV)
        net.WriteEntity(ent)
        net.WriteString(kind or classOf(ent))
        net.WriteString(A.NormalizeNetwork(ent:GetNetworkID()))
        if classOf(ent) == "grm_alarm_hub" then
            net.WriteUInt(A.ClampMode(ent:GetMode()), 3)
            net.WriteBool(ent:GetAlarmActive())
            net.WriteUInt(math.min(#devicesOf(ent:GetNetworkID(), "grm_alarm_sensor"), 255), 8)
        elseif classOf(ent) == "grm_alarm_sensor" then
            net.WriteUInt(math.Clamp(ent:GetRadius(), 0, 2000), 16)
            net.WriteBool(ent:GetActive())
        else
            -- Код 89: speaker — bool = его Active (читается клиентом под kind)
            net.WriteUInt(0, 3)
            net.WriteBool(classOf(ent) == "grm_alarm_speaker" and ent:GetActive() or false)
            net.WriteUInt(0, 8)
        end
    net.Send(ply)
end

function A.OpenTerminal(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return end
    if not withinUse(ply, ent) then return end
    if not A.CanView(ply) then
        notify(ply, false, "Нет доступа к терминалу охраны.")
        return
    end
    local netID = A.NormalizeNetwork(ent:GetNetworkID())
    local hub = A.GetHub(netID)
    local mode = IsValid(hub) and A.ClampMode(hub:GetMode()) or A.MODE_OFF
    local alarm = IsValid(hub) and hub:GetAlarmActive() or false
    local sensors = devicesOf(netID, "grm_alarm_sensor")
    local sensorList = {}
    for _, s in ipairs(sensors) do
        sensorList[#sensorList + 1] = {
            id = s:GetDeviceID(),
            label = s:GetLabel(),
            active = s:GetActive(),
            radius = s:GetRadius(),
            last = s:GetLastTrigger(),
        }
    end
    local logs = A.GetLogs(netID, 60)
    net.Start(NET_OPEN_TRM)
        net.WriteEntity(ent)
        net.WriteString(netID)
        net.WriteUInt(mode, 3)
        net.WriteBool(alarm)
        net.WriteBool(A.CanControl(ply))
        net.WriteBool(IsValid(hub))
        net.WriteUInt(#devicesOf(netID, "grm_alarm_speaker"), 8) -- Код 89
        net.WriteTable(sensorList)
        net.WriteTable(logs)
    net.Send(ply)
end

-- Код 89: любые правки настроек автоматически тонут в персистент
-- (дебонс 1с — серия кликов не дёргает диск подряд)
local function saveSoon()
    timer.Create("GRM_Alarm_SaveSoon", 1, 1, function() A.SavePermanent() end)
end

net.Receive(NET_ACT, function(_, ply)
    if not IsValid(ply) then return end
    local a = net.ReadTable() or {}
    local act = tostring(a.action or "")

    local ent = nil
    if isnumber(a.entIndex) then ent = Entity(a.entIndex) end

    if act == "refresh_terminal" then
        if IsValid(ent) then A.OpenTerminal(ply, ent) end
        return
    end

    if act == "set_mode" then
        if not A.CanControl(ply) then notify(ply, false, "Нет прав.") return end
        local netID = A.NormalizeNetwork(a.network or "main")
        local ok, err = A.SetMode(netID, a.mode, ply)
        if not ok then notify(ply, false, tostring(err)) return end
        notify(ply, true, "Режим: " .. A.ModeName(err))
        saveSoon()
        if IsValid(ent) and classOf(ent) == "grm_alarm_terminal" then
            A.OpenTerminal(ply, ent)
        end
    elseif act == "reset_alarm" then
        if not A.CanControl(ply) then notify(ply, false, "Нет прав.") return end
        local netID = A.NormalizeNetwork(a.network or "main")
        A.ResetAlarm(netID, ply)
        notify(ply, true, "Тревога сброшена.")
        if IsValid(ent) and classOf(ent) == "grm_alarm_terminal" then A.OpenTerminal(ply, ent) end
    elseif act == "set_label" then
        if not A.CanControl(ply) or not IsValid(ent) then return end
        if not withinUse(ply, ent) then return end
        local label = string.sub(string.Trim(tostring(a.label or "")), 1, CFG().MaxLabelLen or 48)
        if label == "" then label = "Устройство" end
        ent:SetLabel(label)
        saveSoon()
        notify(ply, true, "Подпись: " .. label)
    elseif act == "set_network" then
        if not A.CanControl(ply) or not IsValid(ent) then return end
        if not withinUse(ply, ent) then return end
        ent:SetNetworkID(A.NormalizeNetwork(a.network))
        saveSoon()
        if classOf(ent) == "grm_alarm_speaker" then syncSpeakers(ent:GetNetworkID()) end
        notify(ply, true, "Сеть: " .. ent:GetNetworkID())
    elseif act == "set_sensor" then
        if not A.CanControl(ply) or not IsValid(ent) or classOf(ent) ~= "grm_alarm_sensor" then return end
        if not withinUse(ply, ent) then return end
        if a.radius then
            ent:SetRadius(math.Clamp(math.floor(tonumber(a.radius) or 220),
                tonumber(CFG().MinSensorRadius) or 64, tonumber(CFG().MaxSensorRadius) or 800))
        end
        if a.active ~= nil then ent:SetActive(a.active and true or false) end
        saveSoon()
        notify(ply, true, "Датчик обновлён.")
    elseif act == "set_speaker" then -- Код 89: динамик сирены (вкл/выкл)
        if not A.CanControl(ply) or not IsValid(ent) or classOf(ent) ~= "grm_alarm_speaker" then return end
        if not withinUse(ply, ent) then return end
        if a.active ~= nil then
            ent:SetActive(a.active and true or false)
            if not ent:GetActive() then A.StopSpeakerPatch(ent) end
        end
        syncSpeakers(ent:GetNetworkID())
        saveSoon()
        notify(ply, true, "Динамик " .. (ent:GetActive() and "включён." or "выключен."))
    elseif act == "set_permanent" then
        if not ply:IsSuperAdmin() or not IsValid(ent) then return end
        ent:SetPermanent(a.permanent and true or false)
        if a.permanent and ent:GetOwnerSteam() == "" then
            ent:SetOwnerSteam(steam64(ply))
        end
        A.SavePermanent()
        notify(ply, true, a.permanent and "Permanent ON" or "Permanent OFF")
    elseif act == "save_all" then
        if not ply:IsSuperAdmin() then return end
        notify(ply, A.SavePermanent(), "Permanent save")
    elseif act == "open_terminal" then
        if IsValid(ent) then A.OpenTerminal(ply, ent) end
    end
end)

hook.Add("PlayerSpawnedSENT", "GRM_Alarm_Spawned", function(ply, ent)
    if not IsValid(ent) or not isAlarmClass(classOf(ent)) then return end
    if IsValid(ply) then ent:SetOwnerSteam(steam64(ply)) end
    A.RegisterDevice(ent)
end)

hook.Add("InitPostEntity", "GRM_Alarm_Load", function()
    timer.Simple(2.5, function() A.LoadPermanent() end)
end)
hook.Add("PostCleanupMap", "GRM_Alarm_Reload", function()
    timer.Simple(1, function() A.LoadPermanent() end)
end)
hook.Add("ShutDown", "GRM_Alarm_Save", function() A.SavePermanent() end)

concommand.Add("grm_alarm_save", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    A.SavePermanent()
end)

print("[GRM Alarm] server v1.2.0 — динамик сирены, сеть в терминале, автосейв (Код 89)")
