--[[--------------------------------------------------------------------
    GRM RadioNet v1.0.0 (Код 85) — Радиосеть: стойки, антенны,
    передатчики, мегафон, маршрутизация голоса с «радио-искажением».

    ЗАЧЕМ. До этого модуля радиосвязь/эфир/оповещение работали «по
    волшебству»: микрофон без единого провода вещал на весь город,
    рация била сквозь карту, громкоговорители жили сами по себе.
    Теперь вещанию нужна ИНФРАСТРУКТУРА:

      СЕРВЕРНАЯ СТОЙКА (grm_server_rack, E = питание вкл/выкл)
        — ядро сети. Сама по себе слабый репитер (RN.RackRange).
      АНТЕННА (grm_antenna)
        — работает, если в радиусе RN.LinkDist от АКТИВНОЙ стойки.
          Каждая связанная антенна даёт круг покрытия RN.AntennaRange —
          тем самым УСИЛИВАЕТ частоту/дальность сигнала сети.
      РАДИОПЕРЕДАТЧИК (grm_radio_station)
        — аппаратура передачи: микрофон подключается к ней, она —
          к активной стойке. Цепочка «микрофон → передатчик → стойка →
          антенны» выводит голос/текст в город.

    ЧТО ЗАВЕДЕНО НА СЕТЬ:
      1) Эфир микрофона (Код 75): до приёмников доходит, только если
         микрофон в сети И приёмник в покрытии антенн. Качество сигнала
         q(позиция приёмника) задаёт ВЫПАДЕНИЯ голоса (эмуляция
         радио-искажения: связь на краю покрытия хрипит и рвётся).
      2) ГРОМКАЯ СВЯЗЬ (новый режим микрофона, доступ = /alert_allow):
         голос ведущего звучит УСИЛЕННО (не объёмно, «из рупора») для
         всех, кто рядом с громкоговорителями, подключёнными к сети;
         громкоговорители щёлкают реле, голос идёт с треском/выпадениями
         — чистая Lua не меняет голосовой поток, эффект собран честными
         средствами: маршрутизация PlayerCanHearPlayersVoice + звуки.
      3) Ручная рация (подсистема телефонии): действует, если ОБА
         абонента в покрытии сети; без сети — только прямая дальность
         RN.DirectRadio (поймал собеседника в упор — договорился).
      4) Мегафон (weapon_grm_megaphone): голос владельца слышно на
         RN.MegaRange с эффектом кабельного рупора (треск, без 3D-
         затухания).
      5) /alert (текст, Код 75): теперь звучит только из громкого-
         ворителей, реально подключённых к сети.

    ТЕХНИЧЕСКИ. VoiceRoute(listener, speaker) — единая точка решений
    (возвращает canHear,is3D или nil = «нет мнения»). Телефонный модуль
    (sv_grm_phone) вызывает её ПЕРВОЙ в своём хуке — иначе хуки
    PlayerCanHearPlayersVoice били бы друг друга в случайном порядке
    pairs() (находка 100). Легаси-хук ш_grм_broadcast самоотключается,
    пока RadioNet в сборке.

    Спавн (суперадмин): /rack_add /antenna_add /rstation_add (+_remove),
    диагностика: /rn_status. Автоперсистентность: grm_rnents/<map>.json
    (аналог Кода 75, антидубль при рестарте).
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.RadioNet = GRM.RadioNet or {}
local RN = GRM.RadioNet

RN.Version    = "1.0.0"

-- настройки сети (юниты = юниты Source; ~40 юн = 1 м)
RN.LinkDist     = 700    -- радиус связывания оборудования со стойкой
RN.AntennaRange = 3200   -- круг покрытия одной связанной антенны
RN.RackRange    = 1200   -- стойка сама = слабый репитер
RN.DirectRadio  = 1500   -- прямая дальность рации вне сети
RN.CoverMinQ    = 0.15   -- мин. качество покрытия для работы
RN.SpeakerRadius = 700   -- радиус слышимости громкоговорителя (совпадает с Кодом 75)
RN.MegaRange    = 1600   -- дальность мегафона
RN.PAQuality    = 0.85   -- «металлическая» громкая связь: базовое качество
RN.MegaQuality  = 0.92   -- качество мегафона

local NET_FX = "GRM_RN_FX"

-- ============================================================
-- СЕРВЕР
-- ============================================================
if SERVER then
    util.AddNetworkString(NET_FX)

    -- форвард-декларации (урок 97-хотфикса: замыкания выше объявлений)
    local recompute
    local paVoiceHear
    local radioVoiceHear
    local notifyFx

    ----------------------------------------------------------------
    -- Пересчёт топологии сети (кэш для дешёвых запросов голоса)
    ----------------------------------------------------------------
    RN._racks = {}
    RN._activeRacks = {}
    RN._coverage = {}      -- массив {pos=Vector, r=число}
    RN._antsTotal = 0
    RN._antsLinked = 0

    local function nearActiveRack(pos, dist)
        local d2max = dist * dist
        for _, r in ipairs(RN._activeRacks) do
            if IsValid(r) and r:GetPos():DistToSqr(pos) <= d2max then return true end
        end
        return false
    end
    RN.NearActiveRack = nearActiveRack

    -- качество сигнала в точке: 1.0 внутри 55% радиуса ближайшего круга
    -- покрытия, далее плавный спад к краю до 0
    function RN.QualityAt(pos)
        local best = 0
        for _, c in ipairs(RN._coverage) do
            local d2 = pos:DistToSqr(c.pos)
            local r = c.r
            if d2 <= r * r then
                local d = math.sqrt(d2)
                local q = 1
                if d > r * 0.55 then
                    q = 1 - (d - r * 0.55) / (r * 0.45)
                end
                if q > best then best = q end
            end
        end
        return best
    end

    function RN.CoveredAt(pos)
        return RN.QualityAt(pos) >= RN.CoverMinQ
    end

    -- громкоговоритель в сети: рядом активная стойка ИЛИ точка в покрытии
    function RN.SpeakerActive(spk)
        if not IsValid(spk) then return false end
        local pos = spk:GetPos()
        if nearActiveRack(pos, RN.LinkDist) then return true end
        return RN.CoveredAt(pos)
    end

    -- радиоприёмник ловит станцию только в покрытии антенн
    function RN.ReceiverOK(radioEnt)
        if not IsValid(radioEnt) then return false end
        return RN.CoveredAt(radioEnt:GetPos())
    end

    -- состояние канала микрофона:
    --   2 = в сети (стойка напрямую ИЛИ через пристыкованный передатчик)
    --   1 = передатчик рядом, но сам вне сети (стойка погашена/далеко)
    --   0 = голый микрофон — эфир в город не выйдет
    function RN.MicLink(mic)
        if not IsValid(mic) then return 0 end
        local pos = mic:GetPos()
        if nearActiveRack(pos, RN.LinkDist) then return 2 end
        for _, st in ipairs(ents.FindByClass("grm_radio_station")) do
            if IsValid(st) and st:GetPos():DistToSqr(pos) <= RN.LinkDist * RN.LinkDist then
                if nearActiveRack(st:GetPos(), RN.LinkDist) then return 2 end
                return 1
            end
        end
        return 0
    end

    -- гейт ручной рации: оба в покрытии ИЛИ прямая близость
    function RN.RadioPairOK(speaker, listener)
        if not IsValid(speaker) or not IsValid(listener) then return false end
        local sp, lp = speaker:GetPos(), listener:GetPos()
        if RN.CoveredAt(sp) and RN.CoveredAt(lp) then return true end
        return sp:DistToSqr(lp) <= RN.DirectRadio * RN.DirectRadio
    end

    ----------------------------------------------------------------
    -- «Радио-искажение»: детерминированные выпадения пакетов.
    -- Одинаковый срез времени у сервера = устойчивое решение внутри
    -- среза; вероятность слышать == q.
    ----------------------------------------------------------------
    function RN.Drop(lkey, q)
        if q >= 0.985 then return false end
        if q <= 0 then return true end
        local slice = math.floor((CurTime() or 0) * 5)
        local h = (lkey * 2654435761 + slice * 40503) % 1000
        return h > (q * 1000)
    end

    ----------------------------------------------------------------
    -- ЕДИНАЯ МАРШРУТИЗАЦИЯ ГОЛОСА
    -- Возвращает canHear, is3D  — или nil («нет мнения», пусть решают
    -- локальный голос/телефония/поведение по умолчанию).
    ----------------------------------------------------------------
    local function receiveRadius()
        return (GRM.Broadcast and GRM.Broadcast.ReceiveRadius) or 500
    end

    -- слышимость эфира: слушатель стоит у настроенного приёмника,
    -- приёмник в покрытии; качество покрытия задаёт выпадения
    radioVoiceHear = function(listener, mic)
        local rr = receiveRadius()
        for _, r in ipairs(ents.FindByClass("grm_radio")) do
            if r:GetNWBool("GRM_BC_On", false) and r:GetNWInt("GRM_BC_Mic", 0) == mic:EntIndex() then
                if RN.ReceiverOK(r) and listener:GetPos():DistToSqr(r:GetPos()) <= rr * rr then
                    local q = RN.QualityAt(r:GetPos())
                    if RN.Drop(listener:EntIndex(), q) then return nil end
                    return true
                end
            end
        end
        return nil
    end

    -- громкая связь: слушатель рядом с СЕТЕВЫМ громкоговорителем —
    -- голос звучит усиленно (не 3D) и слегка «хрипит»
    paVoiceHear = function(listener)
        local rr = RN.SpeakerRadius
        for _, s in ipairs(ents.FindByClass("grm_loudspeaker")) do
            if RN.SpeakerActive(s) and listener:GetPos():DistToSqr(s:GetPos()) <= rr * rr then
                if RN.Drop(listener:EntIndex() + 3, RN.PAQuality) then return nil end
                return true
            end
        end
        return nil
    end

    function RN.VoiceRoute(listener, speaker)
        if not IsValid(listener) or not IsValid(speaker) then return nil end
        if listener == speaker then return nil end
        -- ближняя зона: физический голос важнее любой аппаратуры,
        -- отдаём решение локальному голосу/телефонии
        local lpos, spos = listener:GetPos(), speaker:GetPos()
        if lpos:DistToSqr(spos) <= 400 * 400 then return nil end
        local now = CurTime()

        -- (1) голос ведущего микрофона (эфир / громкая связь)
        local mic = speaker._grmBCMic
        if IsValid(mic) and mic.BCLive and mic.BCSpeaker == speaker then
            if mic:GetNWBool("GRM_BC_PA", false) then
                local r = paVoiceHear(listener)
                if r ~= nil then
                    speaker._rnTxSeen = now speaker._rnFx = "pa"
                    return r, false
                end
                -- в громкой связи вне громкоговорителей — не звучит
                return false, false
            else
                if RN.MicLink(mic) >= 2 then
                    local r = radioVoiceHear(listener, mic)
                    if r ~= nil then
                        speaker._rnTxSeen = now speaker._rnFx = "radio"
                        return r, false
                    end
                    -- вещает по сети: вне приёмников радиослушателей нет
                    return false, false
                end
                -- микрофон вне сети: эфир не выходит, слышно лишь локально
                return nil
            end
        end

        -- (2) мегафон: усиленный голос с треском
        if speaker._rnMegaOn == true then
            if lpos:DistToSqr(spos) <= RN.MegaRange * RN.MegaRange then
                if RN.Drop(listener:EntIndex() + 7, RN.MegaQuality) then return nil end
                speaker._rnTxSeen = now speaker._rnFx = "mega"
                return true, false
            end
        end

        return nil
    end

    -- собственный хук (при живом телефонном модуле он вызывает
    -- VoiceRoute сам первым делом — наш хук тогда просто дублирует
    -- то же решение, конфликтов нет)
    hook.Add("PlayerCanHearPlayersVoice", "GRM_RadioNet_Voice", function(listener, speaker)
        local c, h = RN.VoiceRoute(listener, speaker)
        if c ~= nil then return c, h end
    end)

    ----------------------------------------------------------------
    -- FX-рассылка «передача идёт/закончена» (щелчки реле, треск)
    ----------------------------------------------------------------
    RN._fxState = {} -- ply → kind или nil
    notifyFx = function(ply, kind, on)
        net.Start(NET_FX)
            net.WriteUInt(ply:EntIndex(), 16)
            net.WriteString(kind or "")
            net.WriteBool(on and true or false)
        net.Broadcast()
    end

    -- релейные щелчки сетевых громкоговорителей (старт/стоп громкой связи)
    local function paRelayClicks(onT)
        local snd = onT and "buttons/button9.wav" or "buttons/button18.wav"
        for _, s in ipairs(ents.FindByClass("grm_loudspeaker")) do
            if RN.SpeakerActive(s) then s:EmitSound(snd, 62, 100) end
        end
    end

    RN._fxLastKind = {}
    timer.Create("GRM_RN_FxWatch", 0.35, 0, function()
        local now = CurTime()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                local active = ply._rnTxSeen and (now - ply._rnTxSeen) < 0.6
                local kind = active and ply._rnFx or nil
                if RN._fxState[ply] ~= kind then
                    if kind then
                        notifyFx(ply, kind, true)
                        if kind == "pa" then paRelayClicks(true) end
                    else
                        notifyFx(ply, RN._fxLastKind[ply] or "radio", false)
                        if RN._fxLastKind[ply] == "pa" then paRelayClicks(false) end
                    end
                    RN._fxState[ply] = kind
                end
                if kind then RN._fxLastKind[ply] = kind end
            end
        end
    end)

    ----------------------------------------------------------------
    -- Автоперсистентность энтити сети (паттерн Кода 75)
    ----------------------------------------------------------------
    local PERSIST_CLASSES = { grm_server_rack = true, grm_antenna = true, grm_radio_station = true }
    local function jsonT(txt)
        local ok, t = pcall(util.JSONToTable, txt, false, true)
        return (ok and istable(t)) and t or nil
    end
    local function entsFile()
        if not file.IsDir("grm_rnents", "DATA") then file.CreateDir("grm_rnents") end
        return "grm_rnents/" .. string.lower(game.GetMap() or "unknown") .. ".json"
    end
    RN.Persist = RN.Persist or {}
    local function loadPersist()
        local t = jsonT(file.Read(entsFile(), "DATA") or "")
        RN.Persist = istable(t) and t or {}
    end
    local function savePersist(reason)
        local ok, txt = pcall(util.TableToJSON, RN.Persist or {}, true)
        if ok and txt then
            file.Write(entsFile(), txt)
            local rb = file.Read(entsFile(), "DATA")
            print("[GRM RadioNet] SAVE ok (" .. tostring(reason or "?") .. "), записей: " .. tostring(table.Count(RN.Persist or {})) .. ", read-back: " .. tostring(rb ~= nil))
        end
    end
    loadPersist()

    local function persistKey(class, pos)
        return tostring(class) .. "|" .. string.format("%.0f_%.0f_%.0f", pos.x, pos.y, pos.z)
    end

    function RN.PersistAdd(ent)
        if not IsValid(ent) or RN._restoring then return end
        local class = ent:GetClass()
        if not PERSIST_CLASSES[class] then return end
        local pos, ang = ent:GetPos(), ent:GetAngles()
        RN.Persist[persistKey(class, pos)] = {
            class = class,
            pos = { x = pos.x, y = pos.y, z = pos.z },
            ang = { p = ang.p or 0, y = ang.y or 0, r = ang.r or 0 },
        }
        savePersist("persist add " .. class)
    end

    function RN.PersistRemove(ent)
        if not IsValid(ent) then return end
        local k = persistKey(ent:GetClass(), ent:GetPos())
        if RN.Persist[k] then RN.Persist[k] = nil savePersist("persist remove") end
    end

    hook.Add("InitPostEntity", "GRM_RN_Restore", function()
        timer.Simple(4, function()
            RN._restoring = true
            local restored = 0
            for k, rec in pairs(RN.Persist or {}) do
                if PERSIST_CLASSES[rec.class] and istable(rec.pos) then
                    local pos = Vector(tonumber(rec.pos.x) or 0, tonumber(rec.pos.y) or 0, tonumber(rec.pos.z) or 0)
                    local dup = false
                    for _, e in ipairs(ents.FindByClass(rec.class)) do
                        if IsValid(e) and e:GetPos():DistToSqr(pos) < 64 then dup = true break end
                    end
                    if not dup then
                        local ent = ents.Create(rec.class)
                        if IsValid(ent) then
                            ent:SetPos(pos)
                            local a = istable(rec.ang) and rec.ang or {}
                            ent:SetAngles(Angle(tonumber(a.p) or 0, tonumber(a.y) or 0, tonumber(a.r) or 0))
                            ent:Spawn() ent:Activate()
                            local phys = ent:GetPhysicsObject()
                            if IsValid(phys) then phys:EnableMotion(false) end
                            if rec.class == "grm_server_rack" then ent:SetNWBool("GRM_RN_On", true) end
                            restored = restored + 1
                        end
                    end
                end
            end
            RN._restoring = false
            print("[GRM RadioNet] Персистент: записей " .. tostring(table.Count(RN.Persist or {})) .. ", восстановлено " .. tostring(restored))
        end)
    end)

    ----------------------------------------------------------------
    -- Периодический пересчёт сети
    ----------------------------------------------------------------
    recompute = function()
        local racks = ents.FindByClass("grm_server_rack")
        RN._racks = racks
        local active = {}
        for _, r in ipairs(racks) do
            if IsValid(r) and r:GetNWBool("GRM_RN_On", true) then active[#active + 1] = r end
        end
        RN._activeRacks = active

        local cov = {}
        for _, r in ipairs(active) do cov[#cov + 1] = { pos = r:GetPos(), r = RN.RackRange } end

        local ants, linked = ents.FindByClass("grm_antenna"), 0
        for _, a in ipairs(ants) do
            if IsValid(a) then
                local isL = nearActiveRack(a:GetPos(), RN.LinkDist)
                if a:GetNWBool("GRM_RN_Linked", false) ~= isL then a:SetNWBool("GRM_RN_Linked", isL) end
                if isL then
                    linked = linked + 1
                    cov[#cov + 1] = { pos = a:GetPos(), r = RN.AntennaRange }
                end
            end
        end
        RN._antsTotal = #ants
        RN._antsLinked = linked
        RN._coverage = cov

        for _, m in ipairs(ents.FindByClass("grm_broadcast_mic")) do
            if IsValid(m) then
                local l = RN.MicLink(m)
                if m:GetNWInt("GRM_RN_Link", -1) ~= l then m:SetNWInt("GRM_RN_Link", l) end
            end
        end
        for _, st in ipairs(ents.FindByClass("grm_radio_station")) do
            if IsValid(st) then
                local on = nearActiveRack(st:GetPos(), RN.LinkDist)
                if st:GetNWBool("GRM_RN_Online", false) ~= on then st:SetNWBool("GRM_RN_Online", on) end
            end
        end
    end
    RN.Recompute = recompute
    timer.Create("GRM_RN_Watch", 0.7, 0, recompute)
    timer.Simple(1, recompute)

    ----------------------------------------------------------------
    -- Диагностика
    ----------------------------------------------------------------
    function RN.StatusLines()
        local spk, spkOn = ents.FindByClass("grm_loudspeaker"), 0
        for _, s in ipairs(spk) do if RN.SpeakerActive(s) then spkOn = spkOn + 1 end end
        local mics = ents.FindByClass("grm_broadcast_mic")
        local m2, m1 = 0, 0
        for _, m in ipairs(mics) do
            local l = RN.MicLink(m)
            if l >= 2 then m2 = m2 + 1 elseif l == 1 then m1 = m1 + 1 end
        end
        local stations = ents.FindByClass("grm_radio_station")
        local stOn = 0
        for _, s in ipairs(stations) do if nearActiveRack(s:GetPos(), RN.LinkDist) then stOn = stOn + 1 end end
        local racksOn = #RN._activeRacks
        return {
            "Стойки: " .. tostring(racksOn) .. "/" .. tostring(#(RN._racks or {})) .. " активны (питание — клавиша E)",
            "Антенны: " .. tostring(RN._antsLinked) .. "/" .. tostring(RN._antsTotal) .. " связаны со стойками (радиус связи " .. RN.LinkDist .. ", покрытие антенны " .. RN.AntennaRange .. " юн)",
            "Передатчики в сети: " .. tostring(stOn) .. "/" .. tostring(#stations),
            "Микрофоны: в сети " .. tostring(m2) .. ", передатчик вне сети " .. tostring(m1) .. ", голых " .. tostring(#mics - m2 - m1),
            "Громкоговорители в сети: " .. tostring(spkOn) .. "/" .. tostring(#spk),
            "Покрытие: " .. tostring(#(RN._coverage or {})) .. " кругов (стойка " .. RN.RackRange .. " юн, антенна " .. RN.AntennaRange .. " юн); рация вне сети — " .. RN.DirectRadio .. " юн напрямую",
        }
    end

    ----------------------------------------------------------------
    -- Чат-команды (тот же каркас PlayerSayTransform+PlayerSay,
    -- что у Кода 75 — чат-системы не проглатывают)
    ----------------------------------------------------------------
    local function spawnAtAim(ply, class, label)
        if not IsValid(ply) or not ply:IsSuperAdmin() then
            if IsValid(ply) then ply:PrintMessage(HUD_PRINTTALK, "[" .. label .. "] Только для суперадмина.") end
            return
        end
        local tr = util.TraceLine({ start = ply:GetShootPos(), endpos = ply:GetShootPos() + ply:GetAimVector() * 320, filter = ply })
        if not tr.Hit then ply:PrintMessage(HUD_PRINTTALK, "[" .. label .. "] Прицельтесь в пол/стену рядом.") return end
        local nt = ents.Create(class)
        if not IsValid(nt) then ply:PrintMessage(HUD_PRINTTALK, "[" .. label .. "] Энтити не зарегистрирована!") return end
        nt:SetPos(tr.HitPos + tr.HitNormal * 2)
        local ang = (ply:GetPos() - tr.HitPos):Angle()
        nt:SetAngles(Angle(0, ang.y, 0))
        nt:Spawn() nt:Activate()
        local phys = nt:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
        if class == "grm_server_rack" then nt:SetNWBool("GRM_RN_On", true) end
        RN.PersistAdd(nt)
        recompute()
        ply:PrintMessage(HUD_PRINTTALK, "[" .. label .. "] Установлен и СОХРАНЁН на карте автоматически. Снять: /" ..
            (class == "grm_server_rack" and "rack" or class == "grm_antenna" and "antenna" or "rstation") .. "_remove прицелом.")
        if GRM.Notify then GRM.Notify(ply, label .. " установлен (персистентно).", 100, 220, 100) end
    end
    local function removeAtAim(ply, class, label)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        local tr = util.TraceLine({ start = ply:GetShootPos(), endpos = ply:GetShootPos() + ply:GetAimVector() * 220, filter = ply })
        local ent = tr.Entity
        if not IsValid(ent) or ent:GetClass() ~= class then
            ply:PrintMessage(HUD_PRINTTALK, "[" .. label .. "] В прицеле нет такой энтити.")
            return
        end
        RN.PersistRemove(ent)
        ent:Remove()
        recompute()
        ply:PrintMessage(HUD_PRINTTALK, "[" .. label .. "] Удалён (и из персистента).")
    end

    hook.Add("PlayerSayTransform", "GRM_RN_TransformCmds", function(ply, datapack)
        if not istable(datapack) then return end
        local msg = datapack[1]
        if not isstring(msg) then return end
        if RN.HandleChat and RN.HandleChat(ply, msg) then
            datapack[1] = ""
            datapack.SkipPlayerSay = true
        end
    end)

    hook.Add("PlayerSay", "GRM_RN_Cmds", function(ply, text)
        if RN.HandleChat and RN.HandleChat(ply, text) then return "" end
    end)

    function RN.HandleChat(ply, text)
        local low = string.lower(string.Trim(text or ""))
        if low == "/rack_add" then spawnAtAim(ply, "grm_server_rack", "Серверная стойка") return true end
        if low == "/rack_remove" then removeAtAim(ply, "grm_server_rack", "Серверная стойка") return true end
        if low == "/antenna_add" then spawnAtAim(ply, "grm_antenna", "Антенна") return true end
        if low == "/antenna_remove" then removeAtAim(ply, "grm_antenna", "Антенна") return true end
        if low == "/rstation_add" then spawnAtAim(ply, "grm_radio_station", "Радиопередатчик") return true end
        if low == "/rstation_remove" then removeAtAim(ply, "grm_radio_station", "Радиопередатчик") return true end
        if low == "/rn_status" or low == "/rn_net" then
            if not ply:IsSuperAdmin() then ply:PrintMessage(HUD_PRINTTALK, "[Радиосеть] Только для суперадмина.") return true end
            recompute()
            ply:PrintMessage(HUD_PRINTTALK, "[Радиосеть] ===== диагностика =====")
            for _, ln in ipairs(RN.StatusLines()) do
                ply:PrintMessage(HUD_PRINTTALK, "[Радиосеть] " .. ln)
            end
            return true
        end
        return false
    end

    print("[GRM RadioNet] Сервер v" .. RN.Version .. " загружен")
end

-- ============================================================
-- КЛИЕНТ: щелчки/треск «радио-искажения»
-- ============================================================
if CLIENT then
    local fxTalkers = {} -- entindex → "radio"/"pa"/"mega"
    net.Receive(NET_FX, function()
        local idx = net.ReadUInt(16)
        local kind = net.ReadString()
        local on = net.ReadBool()
        if on then
            fxTalkers[idx] = kind
            if kind == "pa" then surface.PlaySound("buttons/combine_button1.wav")
            elseif kind == "mega" then surface.PlaySound("buttons/button15.wav")
            else surface.PlaySound("buttons/button9.wav") end
        else
            if fxTalkers[idx] == "pa" then surface.PlaySound("buttons/button18.wav") end
            fxTalkers[idx] = nil
        end
    end)

    -- треск помех: пока «сетевой» говорящий реально говорит, время от
    -- времени проскакивает щелчок статики; если он рядом физически —
    -- не искажаем (слышим живой голос)
    timer.Create("GRM_RN_Crackle", 0.5, 0, function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        for idx, kind in pairs(fxTalkers) do
            local t = Entity(idx)
            if IsValid(t) and t.IsSpeaking and t:IsSpeaking() then
                local near = t:GetPos():DistToSqr(lp:GetPos()) <= 500 * 500
                if not near then
                    local p = (kind == "pa") and 0.55 or (kind == "mega") and 0.35 or 0.25
                    if math.Rand(0, 1) < p then
                        surface.PlaySound("ambient/energy/spark" .. tostring(math.random(1, 6)) .. ".wav")
                    end
                end
            end
        end
    end)

    print("[GRM RadioNet] Клиент v" .. RN.Version .. " загружен")
end
