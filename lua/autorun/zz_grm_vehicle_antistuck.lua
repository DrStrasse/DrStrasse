--[[--------------------------------------------------------------------
    GRM Vehicle Anti-Stuck / Anti-Stack

    Куда положить:
      garrysmod/addons/grm_vehicle_antistuck/lua/autorun/zz_grm_vehicle_antistuck.lua

    Можно положить и в любой существующий аддон в lua/autorun/.

    Что делает:
      • После выхода из машины переносит игрока в безопасную точку рядом с транспортом.
      • Временно отключает столкновение игрока с машиной, чтобы его не зажало моделью.
      • Если игрок всё же оказался внутри bounding box машины — выталкивает наружу.
      • Поддерживает обычный транспорт, simfphys, LVS и vehicle seats/children.
--------------------------------------------------------------------]]

if SERVER then
    AddCSLuaFile()
end

GRM = GRM or {}
GRM.VehicleAntiStuck = GRM.VehicleAntiStuck or {}
local AS = GRM.VehicleAntiStuck

AS.Config = AS.Config or {
    Enabled = true,
    -- ТОНКАЯ ЛОГИКА:
    -- true  = вообще не трогать игроков, которые просто подошли к машине.
    -- false = включить старую общую проверку рядом с машинами.
    OnlyAfterVehicleExit = true,
    -- Не телепортировать сразу при выходе, а сначала проверить, реально ли игрок внутри машины.
    -- Это убирает ощущение, что система откидывает слишком далеко при нормальном выходе.
    ForceMoveOnExit = false,
    -- Сколько секунд после выхода игрок временно не сталкивается с машиной.
    NoCollideTime = 1.25,
    -- Сколько секунд после выхода проверять, не застрял ли игрок.
    PostExitCheckTime = 1.8,
    -- Как часто проверять только игроков, которые недавно вышли из транспорта.
    ThinkInterval = 0.25,
    -- Насколько далеко от края машины искать безопасную точку.
    -- Небольшое значение, чтобы не швыряло далеко.
    ExitExtraDistance = 26,
    -- Радиус поиска связанных сидений/транспорта.
    VehicleChildSearchRadius = 420,
    -- Мягкий толчок после переноса. 0 = вообще без толчка.
    PushVelocity = 35,
    -- Безопасная высота над найденной землёй.
    GroundOffset = 3,
    -- Насколько расширять OBB машины при проверке "внутри".
    -- Маленькое значение, чтобы не срабатывало при обычном подходе к машине.
    InsideOBBExpand = 2,
    -- Дополнительная hull-проверка StartSolid. По умолчанию выключена,
    -- потому что она часто срабатывает просто рядом с машиной.
    UseHullStartSolidCheck = false,
    -- Игнорировать проверку для админов в noclip.
    IgnoreNoclip = true,
    -- Временно делать игрока COLLISION_GROUP_DEBRIS_TRIGGER после выхода.
    TemporaryPlayerCollisionGroup = true,
}

-- Если файл обновлён поверх старой версии через lua_refresh, мягко переводим старые настройки
-- на новый адекватный профиль один раз.
AS.Config.ProfileVersion = AS.Config.ProfileVersion or 0
if AS.Config.ProfileVersion < 2 then
    AS.Config.OnlyAfterVehicleExit = true
    AS.Config.ForceMoveOnExit = false
    AS.Config.NoCollideTime = 1.25
    AS.Config.PostExitCheckTime = 1.8
    AS.Config.ThinkInterval = 0.25
    AS.Config.ExitExtraDistance = 26
    AS.Config.VehicleChildSearchRadius = 420
    AS.Config.PushVelocity = 35
    AS.Config.GroundOffset = 3
    AS.Config.InsideOBBExpand = 2
    AS.Config.UseHullStartSolidCheck = false
    AS.Config.IgnoreNoclip = true
    AS.Config.TemporaryPlayerCollisionGroup = true
    AS.Config.ProfileVersion = 2
end

-- Безопасные дефолты.
AS.Config.Enabled = AS.Config.Enabled ~= false
AS.Config.OnlyAfterVehicleExit = AS.Config.OnlyAfterVehicleExit ~= false
AS.Config.ForceMoveOnExit = AS.Config.ForceMoveOnExit == true
AS.Config.NoCollideTime = AS.Config.NoCollideTime or 1.25
AS.Config.PostExitCheckTime = AS.Config.PostExitCheckTime or 1.8
AS.Config.ThinkInterval = AS.Config.ThinkInterval or 0.25
AS.Config.ExitExtraDistance = AS.Config.ExitExtraDistance or 26
AS.Config.VehicleChildSearchRadius = AS.Config.VehicleChildSearchRadius or 420
AS.Config.PushVelocity = AS.Config.PushVelocity or 35
AS.Config.GroundOffset = AS.Config.GroundOffset or 3
AS.Config.InsideOBBExpand = AS.Config.InsideOBBExpand or 2
AS.Config.UseHullStartSolidCheck = AS.Config.UseHullStartSolidCheck == true
AS.Config.IgnoreNoclip = AS.Config.IgnoreNoclip ~= false
AS.Config.TemporaryPlayerCollisionGroup = AS.Config.TemporaryPlayerCollisionGroup ~= false

local PLAYER_MINS = Vector(-16, -16, 0)
local PLAYER_MAXS = Vector(16, 16, 72)

local function cfg()
    return AS.Config or {}
end

local function isVehicleLike(ent)
    if not IsValid(ent) then return false end
    if ent:IsVehicle() then return true end
    local class = string.lower(ent:GetClass() or "")
    if string.find(class, "prop_vehicle", 1, true) then return true end
    if string.find(class, "gmod_sent_vehicle", 1, true) then return true end
    if string.find(class, "sim_fphys", 1, true) then return true end
    if string.find(class, "lvs", 1, true) then return true end
    if string.find(class, "gred", 1, true) then return true end
    return false
end

local function getVehicleBase(ent)
    if not IsValid(ent) then return ent end
    local parent = ent:GetParent()
    if IsValid(parent) and isVehicleLike(parent) then
        return parent
    end

    -- У simfphys/LVS игрок часто сидит в prop_vehicle_prisoner_pod,
    -- а реальная машина является parent или находится совсем рядом.
    if ent:IsVehicle() then
        local radius = cfg().VehicleChildSearchRadius or 480
        local best = ent
        local bestDist = math.huge
        for _, v in ipairs(ents.FindInSphere(ent:GetPos(), radius)) do
            if IsValid(v) and v ~= ent and isVehicleLike(v) and not v:IsVehicle() then
                local d = v:GetPos():DistToSqr(ent:GetPos())
                if d < bestDist then
                    best = v
                    bestDist = d
                end
            end
        end
        return best
    end

    return ent
end

local function collectRelatedEntities(base, seat)
    local filter = {}
    local function add(ent)
        if IsValid(ent) then filter[#filter + 1] = ent end
    end
    add(base)
    add(seat)

    if IsValid(base) then
        for _, child in ipairs(base:GetChildren()) do
            add(child)
        end

        local radius = cfg().VehicleChildSearchRadius or 480
        for _, ent in ipairs(ents.FindInSphere(base:GetPos(), radius)) do
            if IsValid(ent) and ent:IsVehicle() then
                if ent:GetParent() == base or ent:GetPos():DistToSqr(base:GetPos()) <= 280 * 280 then
                    add(ent)
                end
            end
        end
    end

    return filter
end

local function vehicleRadius(ent)
    if not IsValid(ent) then return 96 end
    local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
    local size = maxs - mins
    local r = math.max(math.abs(size.x), math.abs(size.y)) * 0.5
    return math.Clamp(r, 64, 360)
end

local function isPointInsideVehicleOBB(pos, ent, expand)
    if not IsValid(ent) then return false end
    expand = expand or 10

    local localPos = ent:WorldToLocal(pos)
    local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
    mins = mins - Vector(expand, expand, expand)
    maxs = maxs + Vector(expand, expand, expand)

    return localPos.x >= mins.x and localPos.x <= maxs.x
       and localPos.y >= mins.y and localPos.y <= maxs.y
       and localPos.z >= mins.z and localPos.z <= maxs.z
end

local function groundAndHullClear(pos, filter)
    local start = pos + Vector(0, 0, 96)
    local endpos = pos - Vector(0, 0, 160)

    local ground = util.TraceLine({
        start = start,
        endpos = endpos,
        filter = filter,
        mask = MASK_PLAYERSOLID,
    })

    local finalPos = ground.Hit and (ground.HitPos + Vector(0, 0, cfg().GroundOffset or 4)) or pos

    local hull = util.TraceHull({
        start = finalPos,
        endpos = finalPos,
        mins = PLAYER_MINS,
        maxs = PLAYER_MAXS,
        filter = filter,
        mask = MASK_PLAYERSOLID,
    })

    if hull.StartSolid or hull.Hit then
        return nil
    end

    return finalPos
end

local function candidateDirections(ply, base)
    local dirs = {}
    if IsValid(ply) and IsValid(base) then
        local away = ply:GetPos() - base:GetPos()
        away.z = 0
        if away:LengthSqr() > 1 then
            away:Normalize()
            dirs[#dirs + 1] = away
        end
    end

    if IsValid(base) then
        dirs[#dirs + 1] = base:GetRight()
        dirs[#dirs + 1] = -base:GetRight()
        dirs[#dirs + 1] = -base:GetForward()
        dirs[#dirs + 1] = base:GetForward()
    end

    if IsValid(ply) then
        dirs[#dirs + 1] = ply:GetRight()
        dirs[#dirs + 1] = -ply:GetRight()
        dirs[#dirs + 1] = -ply:GetForward()
        dirs[#dirs + 1] = ply:GetForward()
    end

    return dirs
end

function AS.FindSafeExitPos(ply, vehicleOrSeat)
    if not IsValid(ply) or not IsValid(vehicleOrSeat) then return nil end

    local base = getVehicleBase(vehicleOrSeat)
    if not IsValid(base) then base = vehicleOrSeat end

    local filter = collectRelatedEntities(base, vehicleOrSeat)
    filter[#filter + 1] = ply

    local radius = vehicleRadius(base) + (cfg().ExitExtraDistance or 54)
    local origin = base:GetPos()

    for _, dir in ipairs(candidateDirections(ply, base)) do
        dir.z = 0
        if dir:LengthSqr() > 1 then
            dir:Normalize()
            for _, mult in ipairs({ 1, 1.25, 1.55, 2.0 }) do
                local pos = origin + dir * radius * mult + Vector(0, 0, 32)
                local clear = groundAndHullClear(pos, filter)
                if clear then
                    return clear, dir, base
                end
            end
        end
    end

    -- Последний шанс: вверх и назад от машины.
    local fallbackDir = IsValid(ply) and ply:GetForward() or Vector(1, 0, 0)
    fallbackDir.z = 0
    if fallbackDir:LengthSqr() < 1 then fallbackDir = Vector(1, 0, 0) end
    fallbackDir:Normalize()

    return origin + fallbackDir * (radius + 48) + Vector(0, 0, 24), fallbackDir, base
end

AS.NoCollidePairs = AS.NoCollidePairs or {}

local function pairKey(a, b)
    if not IsValid(a) or not IsValid(b) then return nil end
    local ia, ib = a:EntIndex(), b:EntIndex()
    if ia > ib then ia, ib = ib, ia end
    return ia .. ":" .. ib
end

function AS.TempNoCollide(ply, base, seat, duration)
    if not IsValid(ply) then return end
    duration = duration or (cfg().NoCollideTime or 2.5)
    local untilTime = CurTime() + duration

    local entities = collectRelatedEntities(base, seat)
    for _, ent in ipairs(entities) do
        if IsValid(ent) then
            local key = pairKey(ply, ent)
            if key then
                AS.NoCollidePairs[key] = untilTime
            end
        end
    end

    if cfg().TemporaryPlayerCollisionGroup and SERVER then
        ply.GRM_AntiStuck_OldCollisionGroup = ply.GRM_AntiStuck_OldCollisionGroup or ply:GetCollisionGroup()
        ply:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)

        timer.Create("GRM_AntiStuck_RestoreCG_" .. ply:EntIndex(), duration, 1, function()
            if not IsValid(ply) then return end
            ply:SetCollisionGroup(ply.GRM_AntiStuck_OldCollisionGroup or COLLISION_GROUP_PLAYER)
            ply.GRM_AntiStuck_OldCollisionGroup = nil
        end)
    end
end

hook.Add("ShouldCollide", "GRM_VehicleAntiStuck_TempNoCollide", function(a, b)
    if not AS.Config or AS.Config.Enabled == false then return end
    local key = pairKey(a, b)
    if not key then return end
    local untilTime = AS.NoCollidePairs[key]
    if not untilTime then return end
    if CurTime() > untilTime then
        AS.NoCollidePairs[key] = nil
        return
    end
    return false
end)

function AS.MovePlayerOutOfVehicle(ply, vehicleOrSeat, reason)
    if not IsValid(ply) or not IsValid(vehicleOrSeat) then return false end
    if cfg().IgnoreNoclip and ply:GetMoveType() == MOVETYPE_NOCLIP then return false end

    local pos, dir, base = AS.FindSafeExitPos(ply, vehicleOrSeat)
    if not pos then return false end

    AS.TempNoCollide(ply, base or vehicleOrSeat, vehicleOrSeat, cfg().NoCollideTime or 2.5)

    ply:SetPos(pos)
    ply:SetLocalVelocity(Vector(0, 0, 0))

    local push = tonumber(cfg().PushVelocity) or 35
    if dir and push > 0 then
        ply:SetVelocity(dir * push + Vector(0, 0, math.min(push * 0.25, 12)))
    end

    ply.GRM_AntiStuck_LastVehicle = base or vehicleOrSeat
    ply.GRM_AntiStuck_LastSeat = vehicleOrSeat
    ply.GRM_AntiStuck_LastFix = CurTime()

    return true
end

local function playerLooksStuckInVehicle(ply, ent)
    if not IsValid(ply) or not IsValid(ent) then return false end

    local expand = tonumber(cfg().InsideOBBExpand) or 2
    local pos = ply:GetPos()
    local pelvis = pos + Vector(0, 0, 24)
    local chest = pos + Vector(0, 0, 48)

    -- Срабатываем только если тело реально внутри OBB машины.
    -- Маленький expand предотвращает срабатывание, когда игрок просто подошёл к машине.
    if isPointInsideVehicleOBB(pelvis, ent, expand) or isPointInsideVehicleOBB(chest, ent, expand) then
        return true
    end

    -- Старую hull-проверку оставляем опциональной. Она часто ловит "рядом с машиной"
    -- как StartSolid и поэтому по умолчанию отключена.
    if cfg().UseHullStartSolidCheck then
        local hull = util.TraceHull({
            start = ply:GetPos(),
            endpos = ply:GetPos(),
            mins = PLAYER_MINS,
            maxs = PLAYER_MAXS,
            filter = ply,
            mask = MASK_PLAYERSOLID,
        })
        if hull.StartSolid and IsValid(hull.Entity) and isVehicleLike(hull.Entity) then
            return true
        end
    end

    return false
end

if SERVER then

    hook.Add("PlayerLeaveVehicle", "GRM_VehicleAntiStuck_OnLeave", function(ply, vehicle)
        if not cfg().Enabled then return end
        if not IsValid(ply) or not IsValid(vehicle) then return end

        local base = getVehicleBase(vehicle)

        ply.GRM_AntiStuck_LastVehicle = base
        ply.GRM_AntiStuck_LastSeat = vehicle
        ply.GRM_AntiStuck_PostExitUntil = CurTime() + (cfg().PostExitCheckTime or 3.0)

        -- Временно отключаем столкновение с машиной сразу после выхода,
        -- но НЕ переносим игрока, если он нормально вышел.
        AS.TempNoCollide(ply, base, vehicle, cfg().NoCollideTime or 1.25)

        if cfg().ForceMoveOnExit then
            timer.Simple(0, function()
                if IsValid(ply) and IsValid(vehicle) then
                    AS.MovePlayerOutOfVehicle(ply, vehicle, "leave_force")
                end
            end)
        end

        for i, delay in ipairs({ 0.12, 0.28, 0.55, 0.95, 1.45 }) do
            timer.Simple(delay, function()
                if not IsValid(ply) then return end
                local last = IsValid(ply.GRM_AntiStuck_LastVehicle) and ply.GRM_AntiStuck_LastVehicle or vehicle
                if not IsValid(last) then return end
                if ply:InVehicle() then return end
                if playerLooksStuckInVehicle(ply, last) then
                    AS.MovePlayerOutOfVehicle(ply, last, "post_exit_check")
                end
            end)
        end
    end)

    -- Если игрок умер/отключился, возвращаем collision group.
    local function cleanupPlayer(ply)
        if not IsValid(ply) then return end
        if ply.GRM_AntiStuck_OldCollisionGroup then
            ply:SetCollisionGroup(ply.GRM_AntiStuck_OldCollisionGroup)
            ply.GRM_AntiStuck_OldCollisionGroup = nil
        end
    end
    hook.Add("PlayerDeath", "GRM_VehicleAntiStuck_CleanupDeath", cleanupPlayer)
    hook.Add("PlayerDisconnected", "GRM_VehicleAntiStuck_CleanupDisconnect", cleanupPlayer)

    timer.Create("GRM_VehicleAntiStuck_Think", AS.Config.ThinkInterval, 0, function()
        if not cfg().Enabled then return end

        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and ply:Alive() and not ply:InVehicle() then
                if not (cfg().IgnoreNoclip and ply:GetMoveType() == MOVETYPE_NOCLIP) then
                    -- Новый режим: проверяем только игроков, которые недавно вышли из машины.
                    -- Игроков, которые просто подошли к машине, не трогаем.
                    if ply.GRM_AntiStuck_PostExitUntil and CurTime() <= ply.GRM_AntiStuck_PostExitUntil then
                        local ent = IsValid(ply.GRM_AntiStuck_LastVehicle) and ply.GRM_AntiStuck_LastVehicle or nil
                        if IsValid(ent) and playerLooksStuckInVehicle(ply, ent) then
                            AS.MovePlayerOutOfVehicle(ply, ent, "post_exit_think")
                        end
                    end
                end
            end
        end
    end)

    concommand.Add("grm_antistuck_vehicle", function(ply)
        if not IsValid(ply) then return end
        if not ply:IsAdmin() and not ply:IsSuperAdmin() then return end

        local tr = ply:GetEyeTrace()
        local ent = tr.Entity
        if not IsValid(ent) or not isVehicleLike(ent) then
            ply:ChatPrint("[AntiStuck] Наведитесь на транспорт.")
            return
        end

        AS.MovePlayerOutOfVehicle(ply, ent, "manual")
    end)

    print("[GRM Vehicle Anti-Stuck] Server loaded.")
else
    print("[GRM Vehicle Anti-Stuck] Client loaded.")
end
