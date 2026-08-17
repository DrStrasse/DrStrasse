--[[--------------------------------------------------------------------
    GRM Perf v1.2.0 — общий слой производительности

    Что даёт:
      * event-driven реестры entity по классу (без ents.FindByClass в кадре);
      * change-only NW-запись (NWString/NWInt/NWBool/NWFloat);
      * P.Players()      — кэш списка игроков (без аллокации таблицы в кадре);
      * P.EyeTrace(ply)  — ОДИН трейс из глаз на кадр на всех потребителей;
      * P.Material(path) — кэш Material() (нельзя звать Material в Paint);
      * P.TextSize(font,text) — кэш surface.GetTextSize;
      * P.Coalesce(key,delay,fn) — один отложенный вызов вместо таймера
        на каждое событие (главный источник фризов при загрузке карты);
      * P.Throttle(key,interval) — «не чаще чем раз в N секунд».

    v1.2.0: OnEntityCreated больше НЕ создаёт timer.Simple на каждую entity
    (на загрузке карты это тысячи таймеров за тик). Теперь новые entity
    складываются в очередь и разбираются одним коалесцированным проходом.
----------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Perf = GRM.Perf or {}
local P = GRM.Perf

P.Version   = "1.2.0"
P._classes  = P._classes or {}
P._throttle = P._throttle or {}
P._pending  = P._pending or {}
P._coalesce = P._coalesce or {}

-----------------------------------------------------------------------
-- Троттлинг и коалесцирование
-----------------------------------------------------------------------
function P.Throttle(key, interval, now)
    now = tonumber(now) or CurTime()
    local at = tonumber(P._throttle[key]) or 0
    if at > now then return false end
    P._throttle[key] = now + math.max(0, tonumber(interval) or 0)
    return true
end

-- Один отложенный вызов на ключ: сколько бы раз ни дёрнули за окно delay,
-- функция выполнится РОВНО один раз. Заменяет «timer.Simple на каждое событие».
function P.Coalesce(key, delay, fn)
    if not isfunction(fn) then return false end
    key = tostring(key or "")
    local slot = P._coalesce[key]
    if slot then
        slot.fn = fn
        return false
    end
    P._coalesce[key] = { fn = fn }
    timer.Simple(math.max(0, tonumber(delay) or 0), function()
        local s = P._coalesce[key]
        P._coalesce[key] = nil
        if s and isfunction(s.fn) then s.fn() end
    end)
    return true
end

-----------------------------------------------------------------------
-- Реестры entity по классу
-----------------------------------------------------------------------
local function bucket(class)
    class = tostring(class or "")
    if class == "" then return nil end
    local b = P._classes[class]
    if b then return b end
    b = { set = setmetatable({}, { __mode = "k" }), array = {}, dirty = true }
    P._classes[class] = b
    for _, ent in ipairs(ents.FindByClass(class)) do
        if IsValid(ent) then b.set[ent] = true end
    end
    return b
end

function P.WatchClass(class) return bucket(class) ~= nil end

function P.Entities(class)
    local b = bucket(class)
    if not b then return {} end
    if not b.dirty then return b.array end
    local out = {}
    for ent in pairs(b.set) do
        if IsValid(ent) then out[#out + 1] = ent else b.set[ent] = nil end
    end
    b.array = out
    b.dirty = false
    return out
end

function P.ForEach(class, fn)
    if not isfunction(fn) then return 0 end
    local n = 0
    local b = bucket(class)
    if not b then return n end
    for ent in pairs(b.set) do
        if IsValid(ent) then n = n + 1 fn(ent) else b.set[ent] = nil end
    end
    return n
end

-- Очередь новых entity: класс у только что созданной entity ещё не задан,
-- поэтому разбор откладываем — но ОДНИМ проходом, а не таймером на штуку.
local function flushPending()
    local queue = P._pending
    P._pending = {}
    for i = 1, #queue do
        local ent = queue[i]
        if IsValid(ent) then
            local b = P._classes[ent:GetClass()]
            if b then b.set[ent] = true b.dirty = true end
        end
    end
end
P.FlushPending = flushPending

hook.Add("OnEntityCreated", "GRM_Perf_EntityCreated", function(ent)
    local q = P._pending
    q[#q + 1] = ent
    P.Coalesce("perf.entities.flush", 0, flushPending)
end)

hook.Add("EntityRemoved", "GRM_Perf_EntityRemoved", function(ent)
    local b = P._classes[ent:GetClass()]
    if b then b.set[ent] = nil b.dirty = true end
end)

-----------------------------------------------------------------------
-- Кэш списка игроков: player.GetAll() создаёт новую таблицу на КАЖДЫЙ вызов,
-- а его зовут из HUDPaint/Think десятки раз за кадр.
-----------------------------------------------------------------------
P._players = P._players or {}
P._playersDirty = true

local function rebuildPlayers()
    local out = {}
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then out[#out + 1] = ply end
    end
    P._players = out
    P._playersDirty = false
    return out
end

function P.Players()
    if P._playersDirty then return rebuildPlayers() end
    local list = P._players
    for i = 1, #list do
        if not IsValid(list[i]) then return rebuildPlayers() end
    end
    return list
end

local function markPlayersDirty() P._playersDirty = true end
hook.Add("OnEntityCreated", "GRM_Perf_PlayersDirtyAdd", function(ent)
    if ent and ent.IsPlayer and ent:IsPlayer() then markPlayersDirty() end
end)
hook.Add("PlayerInitialSpawn", "GRM_Perf_PlayersDirtySpawn", markPlayersDirty)
hook.Add("PlayerDisconnected", "GRM_Perf_PlayersDirtyLeave", markPlayersDirty)
hook.Add("EntityRemoved", "GRM_Perf_PlayersDirtyRemove", function(ent)
    if ent and ent.IsPlayer and ent:IsPlayer() then markPlayersDirty() end
end)

-----------------------------------------------------------------------
-- Общий трейс из глаз. Раньше каждый HUD-модуль звал ply:GetEyeTrace()
-- сам: 6-8 полноценных трейсов в кадр. Теперь — один на кадр на всех.
-----------------------------------------------------------------------
P._eyeTrace = P._eyeTrace or {}

function P.EyeTrace(ply, maxAge)
    ply = IsValid(ply) and ply or (CLIENT and LocalPlayer() or nil)
    if not IsValid(ply) then return nil end
    local slot = P._eyeTrace[ply]
    local now = CurTime()
    local age = tonumber(maxAge) or 0
    if slot and slot.frame == FrameNumber() then return slot.tr end
    if slot and age > 0 and (now - slot.at) < age then return slot.tr end
    local tr = ply:GetEyeTrace()
    P._eyeTrace[ply] = { tr = tr, at = now, frame = FrameNumber() }
    return tr
end

-----------------------------------------------------------------------
-- Кэш материалов и размеров текста (клиент)
-----------------------------------------------------------------------
P._materials = P._materials or {}

function P.Material(path, params)
    path = tostring(path or "")
    if path == "" then return nil end
    local key = params and (path .. "|" .. tostring(params)) or path
    local mat = P._materials[key]
    if mat then return mat end
    mat = Material(path, params)
    P._materials[key] = mat
    return mat
end

P._textSize = P._textSize or {}
P._textSizeCount = P._textSizeCount or 0

function P.TextSize(font, text)
    if not CLIENT then return 0, 0 end
    font = tostring(font or "DermaDefault")
    text = tostring(text or "")
    local key = font .. "\1" .. text
    local cached = P._textSize[key]
    if cached then return cached[1], cached[2] end
    surface.SetFont(font)
    local w, h = surface.GetTextSize(text)
    if P._textSizeCount > 4096 then P._textSize = {} P._textSizeCount = 0 end
    P._textSize[key] = { w, h }
    P._textSizeCount = P._textSizeCount + 1
    return w, h
end

-----------------------------------------------------------------------
-- Change-only NW: пишем в сеть только когда значение реально изменилось.
-----------------------------------------------------------------------
function P.NWString(ent, key, value, default)
    value = tostring(value or "")
    if ent:GetNWString(key, default or "") ~= value then ent:SetNWString(key, value) return true end
    return false
end

function P.NWInt(ent, key, value, default)
    value = math.floor(tonumber(value) or 0)
    if ent:GetNWInt(key, default or -2147483648) ~= value then ent:SetNWInt(key, value) return true end
    return false
end

function P.NWBool(ent, key, value, default)
    value = value == true
    if ent:GetNWBool(key, default == true) ~= value then ent:SetNWBool(key, value) return true end
    return false
end

function P.NWFloat(ent, key, value, epsilon)
    value = tonumber(value) or 0
    if math.abs(ent:GetNWFloat(key, -1e30) - value) > (tonumber(epsilon) or .001) then
        ent:SetNWFloat(key, value)
        return true
    end
    return false
end

print("[GRM Perf] v" .. P.Version .. ": реестры entity, кэш игроков/трейсов/материалов, коалесцирование")
