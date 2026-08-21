--[[--------------------------------------------------------------------
    GRM Prop Guard v1.0.0 — призрачные пропы и защита от спама
    (заказ владельца 21.08).

    ДВЕ ЗАДАЧИ, ОДИН МОДУЛЬ.

    1. ПРИЗРАК ПРИ СПАВНЕ. Только что созданный проп не должен «взрываться»
       физикой, толкать игроков и застревать в геометрии. Поэтому он
       появляется полупрозрачным, без коллизии и без движения — его видно,
       но он никому не мешает. Как только игрок поставил его физганом и
       ЗАМОРОЗИЛ, проп становится обычным: сплошной, с физикой и коллизией.
       Снял с заморозки физганом — снова призрак, можно спокойно двигать.

    2. ЗАЩИТА ОТ СПАМА. Если игрок сыплет пропами очередью, спавн ему
       закрывается на минуту: об этом ему пишут прямо в чат с обратным
       отсчётом, а событие уходит в аудит. Ограничение считается по окну
       времени, а не по общему числу пропов, поэтому спокойная стройка
       никогда под него не попадает.

    Настройки (конвары, все с сохранением):
      grm_prop_ghost        1    — включить призрачный режим
      grm_prop_ghost_alpha  140  — прозрачность призрака (0…255)
      grm_prop_spam_count   10   — сколько пропов подряд считать спамом
      grm_prop_spam_window  8    — за сколько секунд
      grm_prop_spam_block   60   — на сколько секунд закрывать спавн
      grm_prop_spam_admins  0    — 1: правило действует и на суперадминов
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.PropGuard = GRM.PropGuard or {}
local PG = GRM.PropGuard
PG.Version = "1.0.0"

-----------------------------------------------------------------------
-- ЧИСТАЯ ЛОГИКА ОКНА СПАМА (гоняется в стенде без игры)
-----------------------------------------------------------------------

--- Отсечь из списка времён всё, что старше окна.
function PG.Trim(times, now, window)
    local out = {}
    for _, t in ipairs(istable(times) and times or {}) do
        if (now - t) <= window then out[#out + 1] = t end
    end
    return out
end

--- Учесть новый спавн. Возвращает: список времён, сработал ли лимит.
function PG.Register(times, now, window, limit)
    local out = PG.Trim(times, now, window)
    out[#out + 1] = now
    return out, #out >= limit
end

--- Сколько секунд осталось до конца блокировки (0 — не заблокирован).
function PG.BlockLeft(blockedUntil, now)
    local left = (tonumber(blockedUntil) or 0) - now
    if left <= 0 then return 0 end
    return math.ceil(left)
end

if SERVER then

    local cvGhost = CreateConVar("grm_prop_ghost", "1", FCVAR_ARCHIVE,
        "Новые пропы появляются призраком: без коллизии и физики, до заморозки физганом")
    local cvAlpha = CreateConVar("grm_prop_ghost_alpha", "140", FCVAR_ARCHIVE,
        "Прозрачность призрачного пропа (0…255)")
    local cvCount = CreateConVar("grm_prop_spam_count", "10", FCVAR_ARCHIVE,
        "Сколько пропов подряд считается спамом")
    local cvWindow = CreateConVar("grm_prop_spam_window", "8", FCVAR_ARCHIVE,
        "За сколько секунд считаются пропы для защиты от спама")
    local cvBlock = CreateConVar("grm_prop_spam_block", "60", FCVAR_ARCHIVE,
        "На сколько секунд закрывается спавн после спама")
    local cvAdmins = CreateConVar("grm_prop_spam_admins", "0", FCVAR_ARCHIVE,
        "1 — защита от спама действует и на суперадминов")

    PG.Times = PG.Times or {}      -- ply -> массив времён спавна
    PG.Blocked = PG.Blocked or {}  -- ply -> до какого времени закрыт спавн

    local function notify(ply, text, good)
        if not IsValid(ply) then return end
        if GRM.Notify then
            GRM.Notify(ply, text, good and 100 or 255, good and 220 or 150, good and 130 or 100)
        else
            ply:ChatPrint("[Пропы] " .. tostring(text))
        end
    end

    function PG.Window() return math.Clamp(cvWindow:GetInt(), 1, 120) end
    function PG.Limit() return math.Clamp(cvCount:GetInt(), 2, 200) end
    function PG.BlockTime() return math.Clamp(cvBlock:GetInt(), 5, 3600) end
    function PG.GhostEnabled() return cvGhost:GetBool() end

    --- Действует ли на игрока защита (суперадмины по умолчанию свободны).
    function PG.Guarded(ply)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() and not cvAdmins:GetBool() then return false end
        return true
    end

    --- Заблокирован ли спавн прямо сейчас.
    function PG.IsBlocked(ply)
        if not IsValid(ply) then return false, 0 end
        local left = PG.BlockLeft(PG.Blocked[ply], CurTime())
        return left > 0, left
    end

    function PG.Block(ply, seconds)
        if not IsValid(ply) then return end
        seconds = math.max(1, math.floor(tonumber(seconds) or PG.BlockTime()))
        PG.Blocked[ply] = CurTime() + seconds
        PG.Times[ply] = {}
        notify(ply, ("Слишком много пропов подряд. Спавн закрыт на %d секунд."):format(seconds))
        if GRM.Audit and GRM.Audit.Write then
            GRM.Audit.Write("props", "spam_block", ply, {}, { seconds = seconds })
        end
        print(("[GRM PropGuard] %s превысил лимит пропов — спавн закрыт на %d c")
            :format(ply:Nick(), seconds))
        hook.Run("GRM_PropSpamBlocked", ply, seconds)
    end

    function PG.Unblock(ply)
        if not IsValid(ply) then return end
        PG.Blocked[ply] = nil
        PG.Times[ply] = {}
    end

    --- Учёт спавна: true — можно, false — сработал лимит.
    function PG.Account(ply)
        if not PG.Guarded(ply) then return true end
        local blocked = select(1, PG.IsBlocked(ply))
        if blocked then return false end
        local times, hit = PG.Register(PG.Times[ply], CurTime(), PG.Window(), PG.Limit())
        PG.Times[ply] = times
        if hit then
            PG.Block(ply, PG.BlockTime())
            return false
        end
        return true
    end

    -- ── ПРИЗРАЧНЫЙ ПРОП ─────────────────────────────────────────────

    --- Перевести проп в призрак: видно, но никому не мешает.
    function PG.MakeGhost(ent)
        if not IsValid(ent) then return false end
        ent.GRMGhost = true
        ent.GRMGhostGroup = ent.GRMGhostGroup or ent:GetCollisionGroup()
        ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
        ent:SetRenderMode(RENDERMODE_TRANSALPHA)
        local a = math.Clamp(cvAlpha:GetInt(), 40, 255)
        local col = ent:GetColor()
        ent.GRMGhostAlpha = col and col.a or 255
        ent:SetColor(Color(col and col.r or 255, col and col.g or 255, col and col.b or 255, a))
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
        ent:SetNWBool("GRM_PropGhost", true)
        return true
    end

    --- Вернуть пропу физику и коллизию (после заморозки физганом).
    function PG.Materialize(ent, ply)
        if not IsValid(ent) or not ent.GRMGhost then return false end
        ent.GRMGhost = nil
        ent:SetCollisionGroup(ent.GRMGhostGroup or COLLISION_GROUP_NONE)
        ent:SetRenderMode(RENDERMODE_NORMAL)
        local col = ent:GetColor()
        ent:SetColor(Color(col and col.r or 255, col and col.g or 255, col and col.b or 255,
            ent.GRMGhostAlpha or 255))
        ent:SetNWBool("GRM_PropGhost", false)
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
        hook.Run("GRM_PropMaterialized", ent, ply)
        return true
    end

    -- новый проп — сразу призрак
    hook.Add("PlayerSpawnedProp", "GRM_PropGuard_Ghost", function(ply, model, ent)
        if not PG.GhostEnabled() then return end
        if not IsValid(ent) then return end
        PG.MakeGhost(ent)
        if IsValid(ply) then
            notify(ply, "Проп поставлен призраком: закрепите физганом и заморозьте (ПКМ), чтобы он стал твёрдым.", true)
        end
    end)

    -- заморозил физганом → проп «встал» по-настоящему
    hook.Add("PhysgunFreeze", "GRM_PropGuard_Freeze", function(wep, phys, ent, ply)
        if IsValid(ent) and ent.GRMGhost then
            timer.Simple(0, function()
                if IsValid(ent) and IsValid(phys) and not phys:IsMoveable() then
                    PG.Materialize(ent, ply)
                end
            end)
        end
    end)

    hook.Add("OnPhysgunFreeze", "GRM_PropGuard_FreezeAlt", function(wep, phys, ent, ply)
        if IsValid(ent) and ent.GRMGhost then PG.Materialize(ent, ply) end
    end)

    -- снял с заморозки физганом → снова призрак, чтобы двигать без помех
    hook.Add("PhysgunPickup", "GRM_PropGuard_Pickup", function(ply, ent)
        if not PG.GhostEnabled() then return end
        if IsValid(ent) and ent:GetClass() == "prop_physics" and not ent.GRMGhost then
            -- призраком делаем только пропы, которые не защищены чужим владельцем
            local owner = ent.GRMOwner or ent.CPPIGetOwner and ent:CPPIGetOwner() or nil
            if owner == nil or owner == ply then PG.MakeGhost(ent) end
        end
    end)

    -- ── ЗАЩИТА ОТ СПАМА ─────────────────────────────────────────────
    local function guardSpawn(ply)
        if not IsValid(ply) then return end
        local blocked, left = PG.IsBlocked(ply)
        if blocked then
            notify(ply, ("Спавн закрыт ещё %d с — слишком много пропов подряд."):format(left))
            return false
        end
        if not PG.Account(ply) then return false end
    end

    hook.Add("PlayerSpawnProp", "GRM_PropGuard_Limit", guardSpawn)
    hook.Add("PlayerSpawnRagdoll", "GRM_PropGuard_LimitRagdoll", guardSpawn)
    hook.Add("PlayerSpawnEffect", "GRM_PropGuard_LimitEffect", guardSpawn)
    hook.Add("PlayerSpawnSENT", "GRM_PropGuard_LimitSENT", guardSpawn)

    hook.Add("PlayerDisconnected", "GRM_PropGuard_Clear", function(ply)
        PG.Times[ply], PG.Blocked[ply] = nil, nil
    end)

    -- ── команды ─────────────────────────────────────────────────────
    concommand.Add("grm_prop_unblock", function(ply, _, args)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end
        local nick = string.lower(tostring(args and args[1] or ""))
        local n = 0
        for _, target in ipairs(player.GetAll()) do
            if nick == "" or string.lower(target:Nick()):find(nick, 1, true) then
                PG.Unblock(target)
                n = n + 1
            end
        end
        local text = ("[Пропы] снята блокировка спавна: %d игрок(ов)"):format(n)
        if IsValid(ply) then ply:ChatPrint(text) else print(text) end
    end)

    concommand.Add("grm_prop_status", function(ply)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end
        local function say(t) if IsValid(ply) then ply:ChatPrint(t) else print(t) end end
        say(("[Пропы] лимит %d за %d c, блокировка %d c, призрак %s"):format(
            PG.Limit(), PG.Window(), PG.BlockTime(), PG.GhostEnabled() and "вкл" or "выкл"))
        for _, target in ipairs(player.GetAll()) do
            local blocked, left = PG.IsBlocked(target)
            local recent = #PG.Trim(PG.Times[target] or {}, CurTime(), PG.Window())
            if blocked or recent > 0 then
                say(("   %s — за окно %d, %s"):format(target:Nick(), recent,
                    blocked and ("заблокирован ещё " .. left .. " c") or "норма"))
            end
        end
    end)
end

if CLIENT then
    --[[ Подсказка на призрачном пропе: игрок должен понимать, почему проп
         полупрозрачный и что с ним делать. Рисуем только при взгляде на
         него и не чаще, чем нужно: трассировка троттлится. ]]
    surface.CreateFont("GRMPropGuard_Hint", { font = "Roboto", size = 17, weight = 700, extended = true })

    local lookProp, lookAt = nil, 0

    hook.Add("PostDrawTranslucentRenderables", "GRM_PropGuard_Hint", function(depth, sky, sky3d)
        if depth or sky or sky3d then return end
        local lp = LocalPlayer()
        if not IsValid(lp) or not lp:Alive() then return end

        if CurTime() - lookAt > 0.25 then
            lookAt = CurTime()
            local tr = (GRM.Perf and GRM.Perf.EyeTrace) and GRM.Perf.EyeTrace(lp) or lp:GetEyeTrace()
            local ent = tr and tr.Entity or nil
            lookProp = (IsValid(ent) and ent:GetNWBool("GRM_PropGhost", false)) and ent or nil
        end

        local ent = lookProp
        if not IsValid(ent) then return end
        if lp:GetPos():Distance(ent:GetPos()) > 300 then return end

        local ang = (lp:EyePos() - ent:GetPos()):Angle()
        ang:RotateAroundAxis(ang:Right(), -90)
        ang:RotateAroundAxis(ang:Up(), -90)

        cam.Start3D2D(ent:GetPos() + Vector(0, 0, 18), ang, 0.1)
            draw.RoundedBox(6, -190, -20, 380, 40, Color(12, 16, 24, 225))
            draw.SimpleText("ПРИЗРАК — ЗАМОРОЗЬТЕ ФИЗГАНОМ (ПКМ)", "GRMPropGuard_Hint", 0, 0,
                Color(255, 205, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.End3D2D()
    end)
end

print("[GRM PropGuard] v" .. PG.Version .. " loaded (" .. (SERVER and "Server" or "Client") .. ")")
