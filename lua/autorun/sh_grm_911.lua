--[[--------------------------------------------------------------------
    GRM 911 v1.0.0 — расследования + трупы + помощь пострадавшим

    «911» — это НЕ просто смерть: игрок, получивший летальный урон,
    падает (Downed/DBNO) и получает время до смерти (BleedoutTime).
    За это время его может оживить медик. Если время вышло (или его
    добили) — на месте остаётся ТЕЛО (grm_corpse) с данными для
    расследования: имя, время смерти, причина, кто нанёс удар, ранения.

    Возможности:
      • Downed-состояние: ScalePlayerDamage режет летальный урон до 1 HP,
        игрок падает (ragdoll/freeze), HUD показывает отсчёт до смерти.
      • Оживление: медик (/revive или меню) в радиусе — через ReviveTime
        игрок встаёт с ReviveHP. Обычные игроки без аптечки не могут.
      • Тело (grm_corpse): при смерти спавнится тело с метаданными;
        живёт CorpseTTL, потом исчезает. E/меню/`/examine` — осмотр.
      • Расследование: осмотр тела даёт сводку (время/причина/ранения/
        нападавший) и пишет запись в журнал происшествий
        (grm_911_incidents.json) — для полиции/юстиции.
      • Вызов «911»: /911 — оповещает онлайн-медиков и полицию с позицией
        (и статусом «без сознания», если игрок Downed). Кулдаун 60 с.
      • Доступ: медики — GRM.MedicalFull.IsMedic / GRM.Medical.CanTreat
        (фолбэк — фракции «Медики»/«Скорая»); полиция — фракция по
        паттерну названия. Суперадмин обходит всё.

    Настройки (суперадмин, data/grm_911.json): /911cfg, /911_set …
      enabled / bleedout / revive / reviveHp / corpseTtl / examineRange
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.E911 = GRM.E911 or {}
local E = GRM.E911

E.Version  = "1.0.0"
E.CfgFile  = "grm_911.json"
E.LogFile  = "grm_911_incidents.json"

E.Config = E.Config or {
    enabled      = true,
    bleedout     = 120,   -- сек до смерти в Downed
    revive       = 5,     -- сек оживления медиком
    reviveHp     = 30,    -- HP после оживления
    corpseTtl    = 600,   -- сколько живёт тело, сек
    examineRange = 160,   -- радиус осмотра тела
    callCooldown = 60,    -- кулдаун /911
}

E.HitgroupNames = {
    [1] = "голова", [2] = "грудь", [3] = "живот",
    [4] = "левая рука", [5] = "правая рука",
    [6] = "левая нога", [7] = "правая нога",
}
function E.HitgroupName(hg)
    return E.HitgroupNames[tonumber(hg) or 0] or "тело"
end

local NET_STATE   = "GRM_E911_State"
local NET_EXAMINE = "GRM_E911_Examine"

local function clampN(v, a, b) if v < a then return a end if v > b then return b end return v end

-- Сворачивание регистра БЕЗ полагания на locale (string.lower в LuaJIT
-- не трогает кириллицу). ASCII A–Z и кириллица А–Я/Ё приводятся к нижнему
-- регистру — иначе паттерны фракций («медик», «полиц») не находят
-- «Медики»/«ПОЛИЦИЯ». Используется для сопоставления названий фракций.
function E.FoldCase(s)
    s = tostring(s or "")
    local out, i = {}, 1
    while i <= #s do
        local b = s:byte(i)
        if b >= 65 and b <= 90 then
            out[#out + 1] = string.char(b + 32)
        elseif (b == 0xD0 or b == 0xD1) and s:byte(i + 1) then
            local b2 = s:byte(i + 1)
            if b == 0xD0 and b2 == 0x81 then
                out[#out + 1] = string.char(0xD1, 0x91)          -- Ё → ё
            elseif b == 0xD0 and b2 >= 0x90 and b2 <= 0x9F then
                out[#out + 1] = string.char(0xD0, b2 + 0x20)     -- А–П → а–п
            elseif b == 0xD0 and b2 >= 0xA0 and b2 <= 0xAF then
                out[#out + 1] = string.char(0xD1, b2 - 0x20)     -- Р–Я → р–я
            else
                out[#out + 1] = string.char(b, b2)
            end
            i = i + 1
        else
            out[#out + 1] = string.char(b)
        end
        i = i + 1
    end
    return table.concat(out)
end

-- ============================================================
-- СЕРВЕР
-- ============================================================
if SERVER then
    util.AddNetworkString(NET_STATE)
    util.AddNetworkString(NET_EXAMINE)

    local function jsonT(txt)
        local ok, t = pcall(util.JSONToTable, txt, false, true)
        return (ok and istable(t)) and t or nil
    end

    local function loadCfg()
        local t = jsonT(file.Read(E.CfgFile, "DATA") or "")
        if istable(t) then
            E.Config.enabled      = (t.enabled ~= nil) and (t.enabled == true) or E.Config.enabled
            E.Config.bleedout     = math.max(10, math.floor(tonumber(t.bleedout) or E.Config.bleedout))
            E.Config.revive       = math.max(1,  math.floor(tonumber(t.revive) or E.Config.revive))
            E.Config.reviveHp     = clampN(math.floor(tonumber(t.reviveHp) or E.Config.reviveHp), 1, 100)
            E.Config.corpseTtl    = math.max(30, math.floor(tonumber(t.corpseTtl) or E.Config.corpseTtl))
            E.Config.examineRange = clampN(math.floor(tonumber(t.examineRange) or E.Config.examineRange), 40, 1000)
            E.Config.callCooldown = math.max(10, math.floor(tonumber(t.callCooldown) or E.Config.callCooldown))
        end
    end
    function E.SaveCfg(why)
        local ok, txt = pcall(util.TableToJSON, E.Config, true)
        if ok and txt then file.Write(E.CfgFile, txt) end
        print("[GRM 911] SAVE cfg (" .. tostring(why or "-") .. ")")
    end
    loadCfg()

    -- журнал происшествий (массивом — урок находки 65) -------------------
    E.Incidents = {}
    local function loadLog()
        local t = jsonT(file.Read(E.LogFile, "DATA") or "")
        E.Incidents = istable(t) and t or {}
    end
    local function saveLog()
        while #E.Incidents > 200 do table.remove(E.Incidents, 1) end
        local ok, txt = pcall(util.TableToJSON, E.Incidents, true)
        if ok and txt then file.Write(E.LogFile, txt) end
    end
    loadLog()

    local function rpName(ply)
        if not IsValid(ply) then return "?" end
        local n = ply:GetNWString("GRM_RPName", "")
        return (n ~= "" and n) or ply:Nick()
    end
    local function charKey(ply)
        if IsValid(ply) and ply:IsPlayer() then
            if GRM.Identity and GRM.Identity.CharacterKey then return GRM.Identity.CharacterKey(ply) end
            return tostring(ply:SteamID64() or ply:SteamID() or "")
        end
        return tostring(ply or "")
    end

    -- ── медик / полиция ────────────────────────────────────────────────
    function E.IsMedic(ply)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return true end
        if GRM.MedicalFull and GRM.MedicalFull.IsMedic then
            if GRM.MedicalFull.IsMedic(ply) then return true end
        end
        if GRM.Medical and GRM.Medical.CanTreat then
            if GRM.Medical.CanTreat(ply) == true then return true end
        end
        if istable(Factions) then
            for name, f in pairs(Factions) do
                if istable(f) and istable(f.Members) then
                    local inF = GRM.Identity and GRM.Identity.FactionMember and GRM.Identity.FactionMember(f, ply)
                        or f.Members[ply:SteamID()] or f.Members[ply:SteamID64()]
                    local n = E.FoldCase(name)
                    if inF and (n:find("медик") or n:find("скор") or n:find("госпитал") or n:find("клиник") or n:find("doctor") or n:find("medic") or n:find("больниц")) then
                        return true
                    end
                end
            end
        end
        return false
    end

    function E.IsPolice(ply)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return true end
        if istable(Factions) then
            for name, f in pairs(Factions) do
                if istable(f) and istable(f.Members) then
                    local inF = GRM.Identity and GRM.Identity.FactionMember and GRM.Identity.FactionMember(f, ply)
                        or f.Members[ply:SteamID()] or f.Members[ply:SteamID64()]
                    local n = E.FoldCase(name)
                    if inF and (n:find("полиц") or n:find("polizei") or n:find("police") or n:find("милиц") or n:find("жандарм") or n:find("орднунг") or n:find("ordnung") or n:find("секьюрити") or n:find("security") or n:find("спецслужб") or n:find("следствен")) then
                        return true
                    end
                end
            end
        end
        return false
    end

    -- ── Downed-состояние ───────────────────────────────────────────────
    E.Downed = E.Downed or {} -- [charKey] = { at, bleedoutAt, by, byName, cause, hitgroup }
    function E.IsDowned(ply)
        return IsValid(ply) and istable(E.Downed[charKey(ply)])
    end

    function E.Down(ply, attacker, inflictor, hitgroup, now)
        if not (IsValid(ply) and ply:IsPlayer()) then return false end
        if not E.Config.enabled then return false end
        if E.IsDowned(ply) then return false end
        now = now or os.time()
        local key = charKey(ply)
        local cause = IsValid(inflictor) and (tostring((inflictor.GetClass and inflictor:GetClass()) or "урон")) or "урон"
        E.Downed[key] = {
            at = now, bleedoutAt = now + (E.Config.bleedout or 120),
            by = IsValid(attacker) and charKey(attacker) or nil,
            byName = IsValid(attacker) and rpName(attacker) or "—",
            cause = cause, hitgroup = tonumber(hitgroup) or 0,
        }
        ply:SetHealth(1)
        if ply.SetRagdolled then pcall(ply.SetRagdolled, ply, true) end
        if ply.Freeze then ply:Freeze(true) end
        ply:SetNWBool("GRM_Downed", true)
        ply:SetNWString("GRM_DownedBy", E.Downed[key].byName or "—")
        E.PushState(ply)
        if GRM.Notify then GRM.Notify(ply, "Вы тяжело ранены и теряете сознание. До смерти " .. tostring(E.Config.bleedout or 120) .. " с. Ждите медика или зовите /911.", 255, 120, 90) end
        hook.Run("GRM_E911_Downed", ply, E.Downed[key])
        return true
    end

    function E.PushState(ply)
        if not IsValid(ply) then return end
        local key = charKey(ply)
        local d = E.Downed[key]
        local isDowned = istable(d)
        local left = isDowned and math.max(0, (d.bleedoutAt or os.time()) - os.time()) or 0
        local reviverName = ""
        if isDowned and IsValid(d.reviver) then reviverName = rpName(d.reviver) end
        net.Start(NET_STATE)
            net.WriteBool(isDowned)
            net.WriteUInt(math.max(0, math.floor(left)), 20)
            net.WriteUInt(isDowned and math.floor(tonumber(d.reviveLeft) or 0) or 0, 10)
            net.WriteString(reviverName)
        net.Send(ply)
    end

    function E.TickDowned(now)
        now = now or os.time()
        for key, d in pairs(E.Downed) do
            if istable(d) then
                local ply
                for _, p in ipairs(player.GetAll()) do
                    if IsValid(p) and charKey(p) == key then ply = p break end
                end
                if not IsValid(ply) then
                    -- отключившегося в Downed обрабатывает PlayerDisconnected
                    -- (тело остаётся на месте, запись снимается там же)
                elseif (d.bleedoutAt or 0) <= now then
                    E.Downed[key] = nil
                    E.FinalKill(ply)
                end
            end
        end
    end

    function E.FinalKill(ply)
        if not IsValid(ply) then return end
        if ply.UnRagdoll then pcall(ply.UnRagdoll, ply) end
        if ply.Freeze then ply:Freeze(false) end
        ply:SetNWBool("GRM_Downed", false)
        if ply.Kill then ply:Kill() end
    end

    -- ── Оживление ──────────────────────────────────────────────────────
    function E.CanRevive(ply)
        if not IsValid(ply) then return false end
        return ply:IsSuperAdmin() or E.IsMedic(ply)
    end

    function E.StartRevive(medic, victim, now)
        if not (IsValid(medic) and IsValid(victim) and medic ~= victim) then return false end
        if not E.IsDowned(victim) then
            if GRM.Notify then GRM.Notify(medic, "Игрок не в бессознательном состоянии.", 255, 190, 90) end
            return false
        end
        if not E.CanRevive(medic) then
            if GRM.Notify then GRM.Notify(medic, "Оживлять могут только медики.", 255, 140, 110) end
            return false
        end
        local d = E.Downed[charKey(victim)]
        if IsValid(d.reviver) and d.reviver ~= medic then
            if GRM.Notify then GRM.Notify(medic, "Игрока уже оживляет " .. rpName(d.reviver) .. ".", 255, 190, 90) end
            return false
        end
        now = now or os.time()
        d.reviver = medic
        d.reviveLeft = math.floor(E.Config.revive or 5)
        d.reviveAt = now + (E.Config.revive or 5)
        if GRM.Notify then
            GRM.Notify(medic, "Оживляете " .. rpName(victim) .. "... (" .. tostring(E.Config.revive) .. " с)", 120, 220, 255)
            GRM.Notify(victim, "Медик " .. rpName(medic) .. " пытается вас реанимировать.", 120, 220, 255)
        end
        E.PushState(victim)
        return true
    end

    function E.TickRevive(now)
        now = now or os.time()
        for key, d in pairs(E.Downed) do
            if istable(d) and IsValid(d.reviver) then
                local victim
                for _, p in ipairs(player.GetAll()) do
                    if IsValid(p) and charKey(p) == key then victim = p break end
                end
                local reviver = d.reviver
                if not IsValid(victim) or not IsValid(reviver) or not reviver:Alive() then
                    d.reviver = nil d.reviveLeft = nil d.reviveAt = nil
                    if IsValid(victim) then E.PushState(victim) end
                elseif (d.reviveAt or 0) <= now then
                    d.reviver = nil d.reviveLeft = nil d.reviveAt = nil
                    E.Revive(victim)
                end
            end
        end
    end

    function E.Revive(victim)
        if not IsValid(victim) then return end
        local key = charKey(victim)
        if not istable(E.Downed[key]) then return end
        E.Downed[key] = nil
        if victim.UnRagdoll then pcall(victim.UnRagdoll, victim) end
        if victim.Freeze then victim:Freeze(false) end
        victim:SetNWBool("GRM_Downed", false)
        victim:SetHealth(math.max(1, math.floor(E.Config.reviveHp or 30)))
        E.PushState(victim)
        if GRM.Notify then GRM.Notify(victim, "Вы приходите в себя. Спасибо медикам.", 120, 255, 150) end
        hook.Run("GRM_E911_Revived", victim)
    end

    -- ── Тело и расследование ───────────────────────────────────────────
    function E.SpawnCorpse(data)
        if not istable(data) then return end
        local pos = istable(data.pos) and Vector(tonumber(data.pos.x) or 0, tonumber(data.pos.y) or 0, tonumber(data.pos.z) or 0) or nil
        local ang = istable(data.ang) and Angle(tonumber(data.ang.p) or 0, tonumber(data.ang.y) or 0, tonumber(data.ang.r) or 0) or Angle(0, 0, 0)
        local ent = ents.Create("grm_corpse")
        if not IsValid(ent) then return end
        if pos then ent:SetPos(pos) end
        ent:SetAngles(ang)
        ent:Spawn()
        ent:Activate()
        if ent.Setup then ent:Setup(data) end
        if IsValid(ent:GetPhysicsObject()) then ent:GetPhysicsObject():EnableMotion(false) end
        -- журнал происшествий
        E.Incidents[#E.Incidents + 1] = {
            id = os.time(), at = tonumber(data.at) or os.time(),
            victim = tostring(data.victimName or "?"), victimKey = tostring(data.victimKey or ""),
            byName = tostring(data.byName or "—"),
            cause = tostring(data.cause or "урон"),
            hitgroup = tonumber(data.hitgroup) or 0,
            pos = pos and { x = math.floor(pos.x), y = math.floor(pos.y), z = math.floor(pos.z) } or nil,
        }
        saveLog()
        -- тело живёт CorpseTtl, потом исчезает (но запись в журнале остаётся)
        timer.Simple(math.max(30, E.Config.corpseTtl or 600), function()
            if IsValid(ent) then ent:Remove() end
        end)
        return ent
    end

    function E.Examine(ply, corpseEnt)
        if not (IsValid(ply) and IsValid(corpseEnt)) then return end
        local data = corpseEnt.GetData and corpseEnt:GetData() or {}
        if not istable(data) or data.victimName == nil then
            if GRM.Notify then GRM.Notify(ply, "Это не тело.", 255, 190, 90) end
            return
        end
        local report = {
            victim = tostring(data.victimName or "?"),
            time = tonumber(data.at) or os.time(),
            cause = tostring(data.cause or "урон"),
            byName = tostring(data.byName or "—"),
            hitgroup = tostring(E.HitgroupName(tonumber(data.hitgroup) or 0)),
            examiner = rpName(ply),
            canInvestigate = ply:IsSuperAdmin() or E.IsPolice(ply) or E.IsMedic(ply),
        }
        -- осмотр фиксируется в журнале (кто осматривал)
        if report.canInvestigate then
            E.Incidents[#E.Incidents + 1] = {
                id = os.time(), at = os.time(),
                victim = report.victim, victimKey = "",
                byName = report.byName, cause = report.cause,
                hitgroup = tonumber(data.hitgroup) or 0,
                examiner = report.examiner, examined = true,
            }
            saveLog()
        end
        net.Start(NET_EXAMINE)
            net.WriteTable(report)
        net.Send(ply)
    end

    -- ── Вызов 911 ──────────────────────────────────────────────────────
    E._lastCall = E._lastCall or {}
    function E.Call911(ply)
        if not IsValid(ply) then return end
        local key = charKey(ply)
        local now = os.time()
        if (E._lastCall[key] or 0) > now - (E.Config.callCooldown or 60) then
            if GRM.Notify then GRM.Notify(ply, "Вызов 911 доступен раз в " .. tostring(E.Config.callCooldown) .. " с.", 255, 190, 90) end
            return
        end
        E._lastCall[key] = now
        local pos = ply:GetPos()
        local downed = E.IsDowned(ply)
        local msg = "911: " .. rpName(ply) .. (downed and " БЕЗ СОЗНАНИЯ (истекает кровью)" or " просит о помощи") ..
            " | " .. string.format("%.0f, %.0f, %.0f", pos.x or 0, pos.y or 0, pos.z or 0)
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and (E.IsMedic(p) or E.IsPolice(p)) then
                p:PrintMessage(HUD_PRINTTALK, "[GRM 911] " .. msg)
                if GRM.Notify then GRM.Notify(p, msg, 255, 120, 90) end
            end
        end
        if GRM.Notify then GRM.Notify(ply, "Вызов 911 отправлен экстренным службам.", 120, 220, 255) end
    end

    -- ── Хуки ───────────────────────────────────────────────────────────
    hook.Add("ScalePlayerDamage", "GRM_E911_DownGate", function(ply, hitgroup, dmginfo)
        if not (IsValid(ply) and ply:IsPlayer()) then return end
        if not (dmginfo and dmginfo.GetDamage) then return end
        if not E.Config.enabled then return end
        local dmg = dmginfo.GetDamage and dmginfo:GetDamage() or 0
        if dmg <= 0 then return end
        if E.IsDowned(ply) then
            -- в Downed добить нельзя — только кровопотеря или оживление
            return 0
        end
        local hp = ply:Health()
        if hp - dmg > 0 then return end
        -- летальный урон → падение; урон гасим полностью, HP=1 ставит Down
        local attacker = dmginfo.GetAttacker and dmginfo:GetAttacker() or nil
        local inflictor = dmginfo.GetInflictor and dmginfo:GetInflictor() or nil
        if E.Down(ply, attacker, inflictor, hitgroup) then
            return 0
        end
    end)

    hook.Add("PlayerDeath", "GRM_E911_Corpse", function(victim, inflictor, attacker)
        if not (IsValid(victim) and victim:IsPlayer()) then return end
        local key = charKey(victim)
        local d = E.Downed[key]
        local data
        if istable(d) then
            data = {
                victimName = rpName(victim), victimKey = key,
                at = os.time(), byName = d.byName or "—",
                cause = d.cause or "урон", hitgroup = d.hitgroup or 0,
                pos = victim:GetPos(), ang = victim:GetAngles(),
                model = victim:GetModel(),
            }
            E.Downed[key] = nil
        else
            local cause = IsValid(inflictor) and (tostring((inflictor.GetClass and inflictor:GetClass()) or "урон")) or "урон"
            data = {
                victimName = rpName(victim), victimKey = key,
                at = os.time(),
                byName = IsValid(attacker) and rpName(attacker) or "—",
                cause = cause, hitgroup = 0,
                pos = victim:GetPos(), ang = victim:GetAngles(),
                model = victim:GetModel(),
            }
        end
        E.SpawnCorpse(data)
    end)

    hook.Add("PlayerDisconnected", "GRM_E911_Disc", function(ply)
        local key = charKey(ply)
        local d = E.Downed[key]
        if istable(d) then
            E.Downed[key] = nil
            E.SpawnCorpse({ victimName = rpName(ply), victimKey = key, at = os.time(), byName = d.byName, cause = d.cause, hitgroup = d.hitgroup, pos = ply:GetPos() })
        end
    end)

    timer.Create("GRM_E911_Tick", 1, 0, function()
        local now = os.time()
        E.TickDowned(now)
        E.TickRevive(now)
    end)

    -- ── Чат-команды ────────────────────────────────────────────────────
    function E.HandleChat(ply, text)
        if not IsValid(ply) then return false end
        local t = string.Trim(tostring(text or ""))
        local low = string.lower(t)
        if low == "/911" then
            E.Call911(ply)
            return true
        end
        if low == "/revive" then
            if not E.CanRevive(ply) then
                ply:PrintMessage(HUD_PRINTTALK, "[911] Оживлять могут только медики.")
                return true
            end
            local tr = ply:GetEyeTrace()
            local tgt = tr and tr.Entity or nil
            if IsValid(tgt) and tgt:IsPlayer() and E.IsDowned(tgt) then
                E.StartRevive(ply, tgt)
            else
                ply:PrintMessage(HUD_PRINTTALK, "[911] Наведитесь на игрока без сознания.")
            end
            return true
        end
        if low == "/examine" or low == "/examinecorpse" or low == "/осмотр" then
            local tr = ply:GetEyeTrace()
            local ent = tr and tr.Entity or nil
            if IsValid(ent) and ent:GetClass() == "grm_corpse" then
                E.Examine(ply, ent)
            else
                ply:PrintMessage(HUD_PRINTTALK, "[911] Наведитесь на тело (grm_corpse).")
            end
            return true
        end
        if low == "/911cfg" then
            if not ply:IsSuperAdmin() then ply:PrintMessage(HUD_PRINTTALK, "[911] Только суперадмин.") return true end
            ply:PrintMessage(HUD_PRINTTALK, string.format("[911] enabled=%s bleedout=%d revive=%d reviveHp=%d corpseTtl=%d examineRange=%d callCooldown=%d",
                tostring(E.Config.enabled), E.Config.bleedout, E.Config.revive, E.Config.reviveHp, E.Config.corpseTtl, E.Config.examineRange, E.Config.callCooldown))
            return true
        end
        if string.sub(low, 1, 9) == "/911_set " then
            if not ply:IsSuperAdmin() then ply:PrintMessage(HUD_PRINTTALK, "[911] Только суперадмин.") return true end
            local key, val = t:match("^%S+%s+(%S+)%s+(%S+)$")
            if key and val then
                local num = tonumber(val)
                if key == "enabled" then E.Config.enabled = (val ~= "0")
                elseif key == "bleedout" and num then E.Config.bleedout = math.max(10, math.floor(num))
                elseif key == "revive" and num then E.Config.revive = math.max(1, math.floor(num))
                elseif key == "reviveHp" and num then E.Config.reviveHp = clampN(math.floor(num), 1, 100)
                elseif key == "corpseTtl" and num then E.Config.corpseTtl = math.max(30, math.floor(num))
                elseif key == "examineRange" and num then E.Config.examineRange = clampN(math.floor(num), 40, 1000)
                elseif key == "callCooldown" and num then E.Config.callCooldown = math.max(10, math.floor(num))
                else
                    ply:PrintMessage(HUD_PRINTTALK, "[911] /911_set <ключ> <значение>: enabled/bleedout/revive/reviveHp/corpseTtl/examineRange/callCooldown")
                    return true
                end
                E.SaveCfg("911_set " .. key)
                ply:PrintMessage(HUD_PRINTTALK, "[911] " .. key .. " = " .. val)
            else
                ply:PrintMessage(HUD_PRINTTALK, "[911] /911_set <ключ> <значение>")
            end
            return true
        end
        if low == "/911_log" then
            if not ply:IsSuperAdmin() then ply:PrintMessage(HUD_PRINTTALK, "[911] Только суперадмин.") return true end
            ply:PrintMessage(HUD_PRINTTALK, "[911] Происшествий в журнале: " .. tostring(#E.Incidents))
            for i = #E.Incidents, math.max(1, #E.Incidents - 9), -1 do
                local r = E.Incidents[i]
                if istable(r) then
                    ply:PrintMessage(HUD_PRINTTALK, string.format("[911] #%d %s — %s (%s)%s",
                        tonumber(r.id) or 0, tostring(r.victim or "?"), tostring(r.cause or "урон"), tostring(r.byName or "—"),
                        r.examined and (" — осмотр: " .. tostring(r.examiner or "?")) or ""))
                end
            end
            return true
        end
        return false
    end

    hook.Add("PlayerSayTransform", "GRM_E911_Transform", function(ply, datapack)
        if not istable(datapack) then return end
        local msg = datapack[1]
        if not isstring(msg) then return end
        if E.HandleChat(ply, msg) then
            datapack[1] = ""
            datapack.SkipPlayerSay = true
        end
    end)
    hook.Add("PlayerSay", "GRM_E911_Chat", function(ply, text)
        if E.HandleChat(ply, text) then return "" end
    end)

    print("[GRM 911] Сервер v" .. E.Version .. " загружен")
end

-- ============================================================
-- КЛИЕНТ
-- ============================================================
if CLIENT then
    surface.CreateFont("GRM911_Title", { font = "Roboto", size = 22, weight = 800, extended = true })
    surface.CreateFont("GRM911_Sub",   { font = "Roboto", size = 15, weight = 600, extended = true })
    surface.CreateFont("GRM911_Text",  { font = "Roboto", size = 13, weight = 500, extended = true })

    local state = { downed = false, left = 0, reviveLeft = 0, reviverName = "" }
    net.Receive(NET_STATE, function()
        state.downed = net.ReadBool()
        state.left = net.ReadUInt(20)
        state.reviveLeft = net.ReadUInt(10)
        state.reviverName = net.ReadString() or ""
    end)

    -- HUD без сознания ----------------------------------------------------
    hook.Add("HUDPaint", "GRM_E911_DownedHud", function()
        if not state.downed then return end
        local w, h = ScrW(), ScrH()
        -- красная виньетка по краям
        surface.SetDrawColor(160, 20, 20, 46)
        surface.DrawRect(0, 0, w, 90)
        surface.DrawRect(0, h - 90, w, 90)
        surface.DrawRect(0, 0, 90, h)
        surface.DrawRect(w - 90, 0, 90, h)
        local mins, secs = math.floor(state.left / 60), math.floor(state.left % 60)
        local txt = string.format("Вы без сознания • до смерти %d:%02d", mins, secs)
        if state.reviverName ~= "" then
            txt = "Вас реанимирует " .. state.reviverName .. "…"
        end
        draw.RoundedBox(8, w / 2 - 300, h - 74, 600, 40, Color(20, 8, 8, 220))
        draw.SimpleText(txt, "GRM911_Sub", w / 2, h - 54, Color(255, 150, 140), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Ждите медика • вызов: /911", "GRM911_Text", w / 2, h - 30, Color(220, 180, 175), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)

    -- панель осмотра тела -------------------------------------------------
    local _exFrame
    net.Receive(NET_EXAMINE, function()
        local r = net.ReadTable() or {}
        if IsValid(_exFrame) then _exFrame:Remove() end
        local f = vgui.Create("DFrame")
        _exFrame = f
        f:SetTitle("") f:SetSize(460, 320) f:Center() f:MakePopup() f:ShowCloseButton(false)
        f.Paint = function(_, pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, Color(20, 24, 32, 248))
            draw.RoundedBoxEx(8, 0, 0, pw, 44, Color(14, 18, 26, 255), true, true, false, false)
            draw.SimpleText("ОСМОТР ТЕЛА", "GRM911_Title", 16, 22, Color(240, 245, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local x = vgui.Create("DButton", f)
        x:SetText("✕") x:SetFont("GRM911_Sub") x:SetTextColor(color_white)
        x:SetPos(418, 8) x:SetSize(30, 26)
        x.Paint = function(self, pw, ph) draw.RoundedBox(4, 0, 0, pw, ph, self:IsHovered() and Color(220, 75, 70) or Color(45, 52, 68)) end
        x.DoClick = function() f:Close() end

        local lines = {
            "Погибший: " .. tostring(r.victim or "?"),
            "Время смерти: " .. os.date("%d.%m.%Y %H:%M", tonumber(r.time) or 0),
            "Причина смерти: " .. tostring(r.cause or "урон"),
            "Повреждения: " .. tostring(r.hitgroup or "тело"),
            "Последний нападавший: " .. tostring(r.byName or "—"),
        }
        if r.canInvestigate then
            lines[#lines + 1] = "Осмотр зафиксирован в журнале происшествий (/911_log у суперадмина)."
        else
            lines[#lines + 1] = "Полный осмотр доступен медикам и полиции."
        end
        local y = 56
        for _, ln in ipairs(lines) do
            local l = vgui.Create("DLabel", f)
            l:SetPos(16, y) l:SetSize(428, 20) l:SetFont("GRM911_Sub") l:SetTextColor(Color(230, 235, 245)) l:SetText(ln)
            y = y + 26
        end
    end)

    print("[GRM 911] Клиент v" .. E.Version .. " загружен")
end
