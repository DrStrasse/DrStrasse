--[[ GRM Net Guard v1.0.0: common validation for client intentions. ]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Net = GRM.Net or {}
local N = GRM.Net
N.Version = "1.0.0"
N._buckets = N._buckets or setmetatable({}, { __mode = "k" })

local function deny(reason)
    return false, tostring(reason or "denied")
end

function N.Guard(ply, key, options, context)
    options = istable(options) and options or {}
    context = istable(context) and context or {}
    if not (IsValid(ply) and ply.IsPlayer and ply:IsPlayer()) then return deny("invalid_player") end
    key = tostring(key or "unnamed")

    local bits = tonumber(context.bits) or 0
    if options.maxBits and bits > tonumber(options.maxBits) then return deny("payload_too_large") end

    local now = CurTime()
    local rate = math.max(0.01, tonumber(options.rate) or 1)
    local burst = math.max(1, math.floor(tonumber(options.burst) or 1))
    N._buckets[ply] = N._buckets[ply] or {}
    local bucket = N._buckets[ply][key] or { tokens = burst, at = now }
    bucket.tokens = math.min(burst, bucket.tokens + math.max(0, now - bucket.at) / rate)
    bucket.at = now
    if bucket.tokens < 1 then N._buckets[ply][key] = bucket return deny("rate_limited") end
    bucket.tokens = bucket.tokens - 1
    N._buckets[ply][key] = bucket

    local ent = context.entity
    if options.distance and IsValid(ent) then
        local origin = ply.GetShootPos and ply:GetShootPos() or ply:GetPos()
        local target = ent.NearestPoint and ent:NearestPoint(origin) or ent:GetPos()
        if origin:DistToSqr(target) > tonumber(options.distance) ^ 2 then return deny("too_far") end
    elseif options.requireEntity and not IsValid(ent) then
        return deny("invalid_entity")
    end

    if options.capability then
        if not (GRM.Access and GRM.Access.Can) then return deny("access_unavailable") end
        local allowed, reason = GRM.Access.Can(ply, options.capability, context)
        if not allowed then return deny(reason or "access_denied") end
    end
    if isfunction(options.permission) then
        local ok, allowed, reason = pcall(options.permission, ply, context)
        if not ok or allowed ~= true then return deny(reason or "permission_denied") end
    end
    return true, "ok"
end

function N.String(value, maxChars, allowEmpty)
    if not isstring(value) then return nil, "string_required" end
    value = string.Trim(value)
    if not allowEmpty and value == "" then return nil, "empty_string" end
    maxChars = math.max(1, tonumber(maxChars) or 256)
    if GRM.Utf8Sub then value = GRM.Utf8Sub(value, maxChars) else value = value:sub(1, maxChars) end
    return value
end

function N.Number(value, minimum, maximum, integer)
    value = tonumber(value)
    if not value or value ~= value or value == math.huge or value == -math.huge then return nil, "invalid_number" end
    if minimum ~= nil then value = math.max(tonumber(minimum), value) end
    if maximum ~= nil then value = math.min(tonumber(maximum), value) end
    if integer then value = math.floor(value) end
    return value
end

if SERVER then hook.Add("PlayerDisconnected", "GRM_NetGuard_Cleanup", function(ply) N._buckets[ply] = nil end) end
print("[GRM Net] guard v" .. N.Version .. " loaded")
