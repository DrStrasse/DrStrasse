--[[--------------------------------------------------------------------
    GRM Mobile v1.0.0 (Код 88) — мобильный телефон GTA IV-style.

    ПРЕДМЕТ: телефон — вещь инвентаря (7 моделей GTA IV от ivancorn,
    падает на землю своей 3D-моделью). Пока телефон В ИНВЕНТАРЕ —
    у игрока ЖИВАЯ сотовая линия (энтити grm_mobile_line, эндпоинт
    телефонной системы Кода 74): ему можно позвонить, он может
    позвонить; выкинул телефон — «абонент недоступен».

    МОДЕЛИ/ТИЕРЫ (цены в /phoneshop, раздел «Мобильные»):
      Badger Crappy   — только звонки, плохой приём (нужен сигнал ≥35%)
      Badger          — + SMS + контакты
      Badger Touch    — + заметки
      The Lost (flip) — + заметки
      Panoramic Tinkle— + приложения (биржа/фракция/форум)
      Whiz Highspeed  — всё + лучший приём
      Whiz Gold       — престижная: всё + приём почти везде

    УПРАВЛЕНИЕ (как в GTA IV): СТРЕЛКА ВВЕРХ — достать телефон,
    ↑/↓ — навигация, ENTER — открыть/ответить, BACKSPACE — назад/
    положить трубку. Во время разговора телефон виден в руке
    (prop у кисти — видят все), голос идёт по голосовому каналу
    телефонии. Прослушка номера — обычным оборудованием
    (grm_phone_wiretap по номеру/АТС).

    ПРИЛОЖЕНИЯ: Телефон (набор номера), SMS, Контакты, Заметки,
    Биржа труда (вакансии/заказы фракций + моя активная работа из
    Кода 77), Моя фракция (участники: онлайн/офлайн, ранг, отдел),
    Форум (внутренний городской), Калькулятор.

    СИГНАЛ: если на карте построена радиосеть RadioNet (есть активная
    стойка) — сотовая связь работает только в её покрытии (механика
    «инфраструктура нужна», Код 85/87); качество сигнала влияет на
    доступность по тиру телефона и обрывает разговор при потере.
    Если сети нет вовсе — связь свободная (как раньше).

    НОМЕРА: мобильные — 5-значные (стационарные 4-значные) — коллизий
    между пулами нет по построению. Хранение: grm_mobile.json (личные
    данные по sid64 — jsonT 3-м аргументом, н65), grm_mobile_forum.json.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Mobile = GRM.Mobile or {}
local MB = GRM.Mobile

MB.Version   = "1.1.0"
MB.DataFile  = "grm_mobile.json"
MB.ForumFile = "grm_mobile_forum.json"
MB.SmsCap       = 40    -- глубина ящика SMS
MB.NotesCap     = 30
MB.ContactsCap  = 50
MB.ForumCap     = 120
MB.ForumRate    = 5     -- сек между постами форума
MB.ForumMaxLen  = 800
MB.SmsMaxLen    = 240
MB.NoteMaxLen   = 400
MB.Exchange     = "cell" -- АТС сотовой сети (виртуальная)

-- локальные пути моделей (GTA IV phones by ivancorn)
local MP = "models/ivancorn/gtaiv/electrical/phones/"

-- ТИЕРЫ. apps: набор «умных» приложений. minQ: минимальное качество
-- сигнала RadioNet для связи (1 = требуется центр сети; 0.10 = ловит на краю).
MB.Tiers = {
    crappy = {
        item = "mobile_crappy", name = "Badger Crappy", model = MP .. "cellphone_badger_crappy.mdl",
        price = 700, minQ = 0.35, operator = "Badger",
        sms = false, contacts = false, notes = false, apps = false,
        desc = "Дешёвая трубка. Только звонки. Плохой приёмник — на окраинах молчит.",
    },
    badger = {
        item = "mobile_badger", name = "Badger Classic", model = MP .. "cellphone_badger.mdl",
        price = 1800, minQ = 0.25, operator = "Badger",
        sms = true, contacts = true, notes = false, apps = false,
        desc = "Рабочая лошадка Badger: звонки, SMS и контакты.",
    },
    badger_touch = {
        item = "mobile_badger_touch", name = "Badger Touch", model = MP .. "phone_mobile_badger_touchscreen.mdl",
        price = 3500, minQ = 0.18, operator = "Badger",
        sms = true, contacts = true, notes = true, apps = false,
        desc = "Сенсорный Badger: SMS, контакты и заметки.",
    },
    lost = {
        item = "mobile_lost", name = "The Lost Flip", model = MP .. "cellphone_thelostdamned.mdl",
        price = 4200, minQ = 0.18, operator = "Whiz",
        sms = true, contacts = true, notes = true, apps = false,
        desc = "Байкерская раскладушка из Liberty City. Крепкая, громкая.",
    },
    tinkle = {
        item = "mobile_tinkle", name = "Panoramic Tinkle", model = MP .. "cellphone_panoramic_tinkle.mdl",
        price = 6500, minQ = 0.15, operator = "Panoramic",
        sms = true, contacts = true, notes = true, apps = true,
        desc = "Смартфон Panoramic Tinkle: все приложения — биржа, фракция, форум.",
    },
    whiz_high = {
        item = "mobile_whiz_high", name = "Whiz Highspeed", model = MP .. "cellphone_whiz_highspeed.mdl",
        price = 9000, minQ = 0.12, operator = "Whiz",
        sms = true, contacts = true, notes = true, apps = true,
        desc = "Флагман Whiz: всё сразу, уверенный приём на окраинах.",
    },
    whiz_gold = {
        item = "mobile_whiz_gold", name = "Whiz Gold", model = MP .. "cellphone_whiz_gold.mdl",
        price = 14000, minQ = 0.10, operator = "Whiz",
        sms = true, contacts = true, notes = true, apps = true,
        desc = "Золотой Whiz. Статус и лучший приёмник в городе.",
    },
}
MB.Order = { "crappy", "badger", "badger_touch", "lost", "tinkle", "whiz_high", "whiz_gold" }

-- приложения (порядок на экране): id → {название, icбыль, нужен флаг тира}
MB.Apps = {
    { id = "dial",   name = "Телефон",    need = nil },
    { id = "sms",    name = "SMS",        need = "sms" },
    { id = "contacts", name = "Контакты", need = "contacts" },
    { id = "notes",  name = "Заметки",    need = "notes" },
    { id = "jobs",   name = "Биржа труда", need = "apps" },
    { id = "fac",    name = "Моя фракция", need = "apps" },
    { id = "forum",  name = "Форум",      need = "apps" },
    { id = "calc",   name = "Калькулятор", need = nil },
}

function MB.AvailableApps(tierKey)
    local t = MB.Tiers[tierKey]
    local out = {}
    for _, app in ipairs(MB.Apps) do
        if app.need == nil or (t and t[app.need] == true) then out[#out + 1] = app end
    end
    return out
end

if SERVER then
    util.AddNetworkString("GRM_Mob_State")
    util.AddNetworkString("GRM_Mob_Act")
    util.AddNetworkString("GRM_Mob_Data")

    -- форвард-декларации (урок 97-хотфикса)
    local recOf
    local carriedTier
    local ensureLineInternal
    local dropLineInternal
    local buildState
    local pushState
    local pushData
    local rpName
    local saveData
    local saveForum

    ----------------------------------------------------------------
    -- хранилище
    ----------------------------------------------------------------
    local function jsonT(txt)
        local ok, t = pcall(util.JSONToTable, txt, false, true)
        return (ok and istable(t)) and t or nil
    end
    MB.Data = MB.Data or {}
    local function loadData()
        local t = jsonT(file.Read(MB.DataFile, "DATA") or "")
        if istable(t) then MB.Data = t end
    end
    saveData = function(why)
        local ok, txt = pcall(util.TableToJSON, MB.Data or {}, true)
        if ok and txt then
            file.Write(MB.DataFile, txt)
            local rb = file.Read(MB.DataFile, "DATA")
            print("[GRM Mobile] SAVE ok (" .. tostring(why or "?") .. "), владельцев: " .. tostring(table.Count(MB.Data or {})) .. ", read-back: " .. tostring(rb ~= nil))
        end
    end
    loadData()

    MB.Forum = MB.Forum or { posts = {} }
    local function loadForum()
        local t = jsonT(file.Read(MB.ForumFile, "DATA") or "")
        if istable(t) and istable(t.posts) then MB.Forum.posts = t.posts end
    end
    saveForum = function(why)
        local ok, txt = pcall(util.TableToJSON, { posts = MB.Forum.posts or {} }, true)
        if ok and txt then
            file.Write(MB.ForumFile, txt)
            local rb = file.Read(MB.ForumFile, "DATA")
            print("[GRM Mobile] FORUM SAVE ok (" .. tostring(why or "?") .. ", постов: " .. tostring(#(MB.Forum.posts or {})) .. "), read-back: " .. tostring(rb ~= nil))
        end
    end
    loadForum()

    recOf = function(sid64)
        sid64 = tostring(sid64 or "")
        if sid64 == "" then return nil end
        local r = MB.Data[sid64]
        if not istable(r) then
            r = { number = nil, contacts = {}, notes = {}, sms = {} }
            MB.Data[sid64] = r
        end
        r.contacts = istable(r.contacts) and r.contacts or {}
        r.notes = istable(r.notes) and r.notes or {}
        r.sms = istable(r.sms) and r.sms or {}
        return r
    end

    rpName = function(ply)
        if not IsValid(ply) then return "?" end
        local n = ply:GetNWString("GRM_RPName", "")
        return (n ~= "" and n) or ply:Nick()
    end

    -- мобильные номера: 5-значные, пул отдельный от стационарных (4-зн.)
    local function numberTaken(n)
        for _, r in pairs(MB.Data or {}) do
            if istable(r) and r.number == n then return true end
        end
        return false
    end
    function MB.GenerateNumber()
        for _ = 1, 2000 do
            local n = tostring(math.random(10000, 99999))
            if not numberTaken(n) then return n end
        end
        return tostring(math.random(100000, 999999))
    end

    ----------------------------------------------------------------
    -- инвентарь: есть ли телефон и какой (лучший из имеющихся)
    ----------------------------------------------------------------
    carriedTier = function(ply)
        if not IsValid(ply) then return nil end
        if not (GRM.Inventory and GRM.Inventory.GetPlayerInv) then return nil end
        local inv = GRM.Inventory.GetPlayerInv(ply)
        if not (istable(inv) and istable(inv.slots)) then return nil end
        local have = {}
        for _, slot in pairs(inv.slots) do
            if istable(slot) and isstring(slot.id) then have[slot.id] = true end
        end
        for i = #MB.Order, 1, -1 do
            local tk = MB.Order[i]
            if have[MB.Tiers[tk].item] then return tk end
        end
        return nil
    end
    MB.CarriedTier = carriedTier

    ----------------------------------------------------------------
    -- сотовые линии (энтити grm_mobile_line)
    ----------------------------------------------------------------
    MB.Lines = MB.Lines or {} -- sid64 → ent
    local function ownerOf(line)
        if not IsValid(line) then return nil end
        return player.GetBySteamID64(line:GetOwnerSID64())
    end

    ensureLineInternal = function(ply)
        local sid64 = ply:SteamID64()
        local line = MB.Lines[sid64]
        if IsValid(line) then return line end
        local rec = recOf(sid64)
        if not rec then return nil end
        if not rec.number then rec.number = MB.GenerateNumber() saveData("номер выдан " .. sid64) end
        line = ents.Create("grm_mobile_line")
        if not IsValid(line) then return nil end
        line:SetPos(ply:GetPos())
        line:Spawn() line:Activate()
        line:SetOwnerSID64(sid64)
        line:SetPhoneNumber(rec.number)
        line:SetDisplayName("Моб. " .. rpName(ply))
        line:SetExchangeID(MB.Exchange)
        MB.Lines[sid64] = line
        return line
    end

    dropLineInternal = function(sid64, reason)
        local line = MB.Lines[sid64]
        if IsValid(line) then
            if line:GetLineState() ~= "idle" and GRM.Phone and GRM.Phone.ForceEndCall then
                local call = GRM.Phone.Calls and GRM.Phone.Calls[line:GetCallID()]
                if call then GRM.Phone.ForceEndCall(call, reason or "line offline") end
            end
            line:Remove()
        end
        MB.Lines[sid64] = nil
    end

    ----------------------------------------------------------------
    -- сигнал сети (RadioNet Код 85/87)
    ----------------------------------------------------------------
    function MB.SignalOf(ply)
        if not IsValid(ply) then return 0 end
        local rn = GRM and GRM.RadioNet
        if not (rn and rn.QualityAt) then return 1 end
        if #(rn._activeRacks or {}) == 0 then return 1 end -- сети не построено — свободная связь
        return rn.QualityAt(ply:GetPos())
    end
    function MB.SignalOK(ply, tierKey)
        local t = MB.Tiers[tierKey]
        return MB.SignalOf(ply) >= ((t and t.minQ) or 0.15)
    end
    function MB.LineOnline(line)
        local ply = ownerOf(line)
        if not IsValid(ply) then return false end
        local tk = carriedTier(ply)
        if not tk then return false end
        return MB.SignalOK(ply, tk)
    end
    -- hand-шлюз из sv_grm_phone (canUsePhone): «телефон в руке» = телефон в инвентаре
    function MB.CanUseLine(ply, line)
        if not IsValid(ply) or not IsValid(line) then return false end
        if ply:SteamID64() ~= line:GetOwnerSID64() then return false end
        return carriedTier(ply) ~= nil
    end

    -- вызов из инвентаря (useFunc mobile_open): подсказка + форс-свежий пуш состояния
    function MB.ServerNotify(ply, msg)
        if GRM.Notify then GRM.Notify(ply, tostring(msg or ""), 120, 200, 255) end
        if pushState then pushState(ply, true) end
    end

    ----------------------------------------------------------------
    -- телефон в руке во время вызова (prop_dynamic у кисти)
    ----------------------------------------------------------------
    MB.HandProps = MB.HandProps or {}
    local function syncHandProp(ply, tk, lineState)
        local want = (tk ~= nil) and (lineState == "call" or lineState == "dialing" or lineState == "ringing")
        local cur = MB.HandProps[ply]
        if want and not IsValid(cur) then
            local bone = ply:LookupBone("ValveBiped.Bip01_R_Hand")
            if bone then
                local p = ents.Create("prop_dynamic")
                if IsValid(p) then
                    p:SetModel(MB.Tiers[tk].model)
                    p:SetMoveType(MOVETYPE_NONE)
                    p:SetSolid(SOLID_NONE)
                    p:FollowBone(ply, bone)
                    p:SetLocalPos(Vector(1.5, 1.5, -0.5))
                    p:SetLocalAngles(Angle(0, -90, 90))
                    p:Spawn()
                    MB.HandProps[ply] = p
                end
            end
        elseif (not want) and IsValid(cur) then
            cur:Remove()
            MB.HandProps[ply] = nil
        end
    end

    ----------------------------------------------------------------
    -- звонки: ops из UI
    ----------------------------------------------------------------
    function MB.Dial(ply, number)
        local tk = carriedTier(ply)
        if not tk then return end
        local line = ensureLineInternal(ply)
        if not IsValid(line) then return end
        number = tostring(number or "")
        if not number:match("^%d%d%d%d+$") then
            if GRM.Notify then GRM.Notify(ply, "Номер: 4–6 цифр (мобильные — 5, городские — 4).", 255, 180, 90) end
            return
        end
        if not MB.SignalOK(ply, tk) then
            if GRM.Notify then GRM.Notify(ply, "Нет сигнала сотовой связи здесь (сигнал слабее " .. math.floor((MB.Tiers[tk].minQ or 0.15) * 100) .. "%).", 255, 140, 110) end
            return
        end
        if GRM.Phone and GRM.Phone.Dial then GRM.Phone.Dial(ply, line, number) end
    end
    function MB.Answer(ply)
        local line = MB.Lines[ply:SteamID64()]
        if not IsValid(line) then return end
        if GRM.Phone and GRM.Phone.Answer then GRM.Phone.Answer(ply, line) end
    end
    function MB.Hangup(ply)
        local line = MB.Lines[ply:SteamID64()]
        if not IsValid(line) then return end
        if GRM.Phone and GRM.Phone.Hangup then GRM.Phone.Hangup(ply, line) end
    end

    ----------------------------------------------------------------
    -- SMS
    ----------------------------------------------------------------
    local function pushSms(rec, entry)
        rec.sms[#rec.sms + 1] = entry
        while #rec.sms > MB.SmsCap do table.remove(rec.sms, 1) end
    end
    function MB.SendSms(from, toNumber, text)
        local tk = carriedTier(from)
        if not tk or MB.Tiers[tk].sms ~= true then
            if GRM.Notify then GRM.Notify(from, "Этот телефон не умеет SMS.", 255, 180, 90) end
            return
        end
        text = string.sub(string.Trim(tostring(text or "")), 1, MB.SmsMaxLen)
        if #text < 1 then return end
        toNumber = tostring(toNumber or "")
        local myRec = recOf(from:SteamID64())
        local target64 = nil
        for sid64, r in pairs(MB.Data or {}) do
            if istable(r) and r.number == toNumber then target64 = sid64 break end
        end
        if not target64 then
            if GRM.Notify then GRM.Notify(from, "Абонент с номером " .. toNumber .. " не обслуживается (нет такого мобильного).", 255, 140, 110) end
            return
        end
        if not MB.SignalOK(from, tk) then
            if GRM.Notify then GRM.Notify(from, "SMS не ушло: нет сигнала.", 255, 140, 110) end
            return
        end
        pushSms(myRec, { dir = "out", num = toNumber, text = text, ts = os.time(), read = true })
        local tRec = recOf(target64)
        pushSms(tRec, { dir = "in", num = myRec.number, fromName = rpName(from), text = text, ts = os.time(), read = false })
        saveData("sms " .. tostring(myRec.number) .. " → " .. toNumber)
        local tp = player.GetBySteamID64(target64)
        if IsValid(tp) and GRM.Notify then
            GRM.Notify(tp, "SMS от " .. tostring(myRec.number) .. ": «" .. string.sub(text, 1, 60) .. "»", 120, 200, 255)
            pushState(tp, true)
        end
        if GRM.Notify then GRM.Notify(from, "SMS отправлено.", 120, 220, 140) end
        pushState(from, true)
    end

    ----------------------------------------------------------------
    -- данные приложений
    ----------------------------------------------------------------
    local function smsRows(ply)
        local rec = recOf(ply:SteamID64())
        local out = {}
        for i, e in ipairs(rec.sms) do
            out[#out + 1] = {
                i = i, dir = e.dir, num = tostring(e.num or "?"), fromName = tostring(e.fromName or ""),
                text = tostring(e.text or ""), ts = tonumber(e.ts) or 0, read = e.read == true,
            }
        end
        return out
    end
    local function contactRows(ply)
        local rec = recOf(ply:SteamID64())
        local out = {}
        for i, c in ipairs(rec.contacts) do
            out[#out + 1] = { i = i, name = tostring(c.name or "?"), num = tostring(c.num or "") }
        end
        return out
    end
    local function noteRows(ply)
        local rec = recOf(ply:SteamID64())
        local out = {}
        for i, n in ipairs(rec.notes) do
            out[#out + 1] = { i = i, text = tostring(n.text or ""), ts = tonumber(n.ts) or 0 }
        end
        return out
    end
    local function jobsRows(ply)
        local rows = {}
        if GRM.Jobs and istable(GRM.Jobs.Cfg) and istable(GRM.Jobs.Cfg.posts) then
            for fac, list in pairs(GRM.Jobs.Cfg.posts) do
                for _, p in ipairs(list or {}) do
                    if istable(p) and p.takenBy == nil then
                        local isVac = tostring(p.kind or "order") == "vacancy"
                        local left = tonumber(p.shiftsLeft) or 0
                        if (not isVac) or left > 0 then
                            rows[#rows + 1] = {
                                fac = tostring(fac), title = tostring(p.title or "?"),
                                kind = isVac and "вакансия" or "заказ",
                                pay = isVac and ("з/п " .. tostring(p.salary or 0) .. " ×" .. tostring(left))
                                            or tostring(p.reward or 0),
                                desc = tostring(p.desc or ""),
                            }
                        end
                    end
                end
            end
        end
        table.sort(rows, function(a, b) if a.fac ~= b.fac then return a.fac < b.fac end return a.title < b.title end)
        while #rows > 60 do table.remove(rows) end
        local mine = nil
        if GRM.Jobs and istable(GRM.Jobs.Active) then
            local j = GRM.Jobs.Active[ply:SteamID64()]
            if istable(j) then mine = { title = tostring(j.title or "?"), desc = tostring(j.desc or "") } end
        end
        return rows, mine
    end
    local function memberRec(f, ply)
        if not (istable(f) and istable(f.Members) and IsValid(ply)) then return nil end
        return f.Members[ply:SteamID()] or f.Members[ply:SteamID64()]
    end
    function MB.FactionOf(ply)
        if not istable(Factions) or not IsValid(ply) then return nil end
        for name, f in pairs(Factions) do
            if istable(f) and memberRec(f, ply) then return name, f end
        end
        return nil
    end
    local function factionRows(ply)
        local name, f = MB.FactionOf(ply)
        if not name then return nil end
        local online = {}
        for _, p in ipairs(player.GetAll()) do if IsValid(p) then online[p:SteamID()] = p online[p:SteamID64()] = p end end
        local rows, on = {}, 0
        for key, m in pairs(f.Members or {}) do
            local p = online[key]
            local isOn = IsValid(p)
            if isOn then on = on + 1 end
            local mname = isOn and rpName(p) or tostring(key)
            rows[#rows + 1] = {
                name = mname, online = isOn,
                role = tostring(istable(m) and m.Role or "?"),
                dept = tostring(istable(m) and m.Department or "—"),
                leader = (f.Leader == key),
            }
        end
        table.sort(rows, function(a, b)
            if a.online ~= b.online then return a.online end
            return tostring(a.name) < tostring(b.name)
        end)
        local myM = memberRec(f, ply) or {}
        return {
            name = name, myRole = tostring(myM.Role or "?"), myDept = tostring(myM.Department or "—"),
            total = table.Count(f.Members or {}), online = on, rows = rows,
        }
    end
    local function forumRows()
        local out, posts = {}, MB.Forum.posts or {}
        local from = math.max(1, #posts - 39)
        for i = #posts, from, -1 do
            local p = posts[i]
            out[#out + 1] = { id = tonumber(p.id) or i, author = tostring(p.author or "?"), text = tostring(p.text or ""), ts = tonumber(p.ts) or 0 }
        end
        return out
    end

    ----------------------------------------------------------------
    -- состояние для клиента (GTA-оболочка)
    ----------------------------------------------------------------
    buildState = function(ply)
        local tk = carriedTier(ply)
        local st = { has = tk ~= nil }
        if not tk then return st end
        local t = MB.Tiers[tk]
        local rec = recOf(ply:SteamID64())
        local line = MB.Lines[ply:SteamID64()]
        local unread = 0
        for _, e in ipairs(rec.sms) do if e.dir == "in" and e.read ~= true then unread = unread + 1 end end
        local sig = MB.SignalOf(ply)
        st.tier = tk
        st.modelName = t.name
        st.operator = t.operator
        st.number = rec.number or ""
        st.signal = sig
        st.bars = (MB.SignalOK(ply, tk)) and math.max(1, math.ceil(sig * 5)) or 0
        st.unread = unread
        st.exchange = MB.Exchange
        if IsValid(line) then
            st.lineState = line:GetLineState()
            if IsValid(line:GetOtherPhone()) then
                st.otherNumber = line:GetOtherPhone():GetPhoneNumber()
                st.otherName = line:GetOtherPhone():GetDisplayName()
            end
        else
            st.lineState = "offline"
        end
        return st
    end

    pushState = function(ply, force)
        if not IsValid(ply) then return end
        local st = buildState(ply)
        local sigParts = {
            tostring(st.has), tostring(st.tier), tostring(st.number), tostring(st.lineState),
            tostring(st.otherNumber), tostring(st.unread), string.format("%.2f", tonumber(st.signal) or 0),
        }
        local sig = table.concat(sigParts, "|")
        if not force and ply._grmMobSig == sig then return end
        ply._grmMobSig = sig
        net.Start("GRM_Mob_State")
            net.WriteTable(st)
        net.Send(ply)
    end

    pushData = function(ply, tab, payload)
        net.Start("GRM_Mob_Data")
            net.WriteString(tab)
            net.WriteTable(payload or {})
        net.Send(ply)
    end

    ----------------------------------------------------------------
    -- действия из телефона (все перевалидируются: предмет/тир/лимиты)
    ----------------------------------------------------------------
    function MB.HandleAction(ply, a)
        if not IsValid(ply) or not istable(a) then return end
        local op = tostring(a.op or "")
        local tk = carriedTier(ply)
        local tier = tk and MB.Tiers[tk] or nil
        local rec = recOf(ply:SteamID64())

        if op == "open" then
            if not tk then return end
            pushState(ply, true)
            pushData(ply, "contacts", { rows = contactRows(ply) })
            pushData(ply, "notes", { rows = noteRows(ply) })
            pushData(ply, "sms", { rows = smsRows(ply) })
            return
        end

        if not tk then
            if GRM.Notify then GRM.Notify(ply, "Нужен мобильный телефон в инвентаре (/phoneshop → «Мобильные»).", 255, 180, 90) end
            return
        end

        if op == "dial" then MB.Dial(ply, a.number) return end
        if op == "answer" then MB.Answer(ply) return end
        if op == "hangup" then MB.Hangup(ply) return end

        if op == "sms" then
            if tier.sms ~= true then
                if GRM.Notify then GRM.Notify(ply, "Этот телефон не умеет SMS.", 255, 180, 90) end
                return
            end
            MB.SendSms(ply, a.num, a.text)
            pushData(ply, "sms", { rows = smsRows(ply) })
            return
        end
        if op == "sms_read" then
            local changed = false
            for _, e in ipairs(rec.sms) do
                if e.dir == "in" and e.read ~= true then e.read = true changed = true end
            end
            if changed then saveData("sms прочитаны " .. ply:SteamID64()) end
            pushData(ply, "sms", { rows = smsRows(ply) })
            pushState(ply, true)
            return
        end
        if op == "contact_add" then
            if tier.contacts ~= true then return end
            local name = string.sub(string.Trim(tostring(a.name or "")), 1, 24)
            local num = tostring(a.num or ""):gsub("%D", "")
            if name == "" or #num < 4 or #num > 6 then return end
            if #rec.contacts >= MB.ContactsCap then
                if GRM.Notify then GRM.Notify(ply, "Контакты полны (" .. MB.ContactsCap .. ").", 255, 180, 90) end
                return
            end
            rec.contacts[#rec.contacts + 1] = { name = name, num = num }
            table.sort(rec.contacts, function(x, y) return tostring(x.name) < tostring(y.name) end)
            saveData("контакт + " .. ply:SteamID64())
            pushData(ply, "contacts", { rows = contactRows(ply) })
            return
        end
        if op == "contact_del" then
            if tier.contacts ~= true then return end
            local i = math.floor(tonumber(a.i) or 0)
            if istable(rec.contacts[i]) then
                table.remove(rec.contacts, i)
                saveData("контакт - " .. ply:SteamID64())
                pushData(ply, "contacts", { rows = contactRows(ply) })
            end
            return
        end
        if op == "note_add" then
            if tier.notes ~= true then return end
            local text = string.sub(string.Trim(tostring(a.text or "")), 1, MB.NoteMaxLen)
            if text == "" then return end
            if #rec.notes >= MB.NotesCap then
                if GRM.Notify then GRM.Notify(ply, "Заметки полны (" .. MB.NotesCap .. ").", 255, 180, 90) end
                return
            end
            rec.notes[#rec.notes + 1] = { text = text, ts = os.time() }
            saveData("заметка + " .. ply:SteamID64())
            pushData(ply, "notes", { rows = noteRows(ply) })
            return
        end
        if op == "note_del" then
            if tier.notes ~= true then return end
            local i = math.floor(tonumber(a.i) or 0)
            if istable(rec.notes[i]) then
                table.remove(rec.notes, i)
                saveData("заметка - " .. ply:SteamID64())
                pushData(ply, "notes", { rows = noteRows(ply) })
            end
            return
        end
        if op == "jobs_query" then
            if tier.apps ~= true then return end
            local rows, mine = jobsRows(ply)
            pushData(ply, "jobs", { rows = rows, mine = mine })
            return
        end
        if op == "fac_query" then
            if tier.apps ~= true then return end
            pushData(ply, "fac", { data = factionRows(ply) })
            return
        end
        if op == "forum_query" then
            if tier.apps ~= true then return end
            pushData(ply, "forum", { rows = forumRows() })
            return
        end
        if op == "forum_post" then
            if tier.apps ~= true then return end
            local now = os.time()
            if ply._grmMobForumTs and (now - ply._grmMobForumTs) < MB.ForumRate then
                if GRM.Notify then GRM.Notify(ply, "Не так быстро: пост раз в " .. MB.ForumRate .. " сек.", 255, 180, 90) end
                return
            end
            local text = string.sub(string.Trim(tostring(a.text or "")), 1, MB.ForumMaxLen)
            if #text < 2 then return end
            ply._grmMobForumTs = now
            local posts = MB.Forum.posts
            local nid = (posts[#posts] and tonumber(posts[#posts].id) or 0) + 1
            posts[#posts + 1] = { id = nid, author = rpName(ply), text = text, ts = now }
            while #posts > MB.ForumCap do table.remove(posts, 1) end
            saveForum("пост " .. nid)
            pushData(ply, "forum", { rows = forumRows() })
            return
        end
    end
    net.Receive("GRM_Mob_Act", function(_, ply)
        MB.HandleAction(ply, net.ReadTable())
    end)

    ----------------------------------------------------------------
    -- жизненный цикл линий и потеря сигнала посреди разговора
    ----------------------------------------------------------------
    timer.Create("GRM_Mob_Think", 1, 0, function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                local sid64 = ply:SteamID64()
                local tk = carriedTier(ply)
                if tk then
                    local line = ensureLineInternal(ply)
                    if IsValid(line) then
                        line:SetPos(ply:GetPos()) -- звуки линии идут от владельца
                        if line:GetDisplayName() ~= ("Моб. " .. rpName(ply)) then
                            line:SetDisplayName("Моб. " .. rpName(ply))
                        end
                        local st = line:GetLineState()
                        if (st == "call" or st == "dialing" or st == "ringing") and not MB.SignalOK(ply, tk) then
                            if GRM.Phone and GRM.Phone.ForceEndCall then
                                local call = GRM.Phone.Calls and GRM.Phone.Calls[line:GetCallID()]
                                if call then
                                    GRM.Phone.ForceEndCall(call, "signal lost")
                                    if GRM.Notify then GRM.Notify(ply, "Связь прервалась: потерян сигнал сети.", 255, 140, 110) end
                                end
                            end
                        end
                        syncHandProp(ply, tk, line:GetLineState())
                    end
                else
                    if IsValid(MB.Lines[sid64]) then dropLineInternal(sid64, "phone unequipped") end
                    local hp = MB.HandProps[ply]
                    if IsValid(hp) then hp:Remove() end
                    MB.HandProps[ply] = nil
                end
                pushState(ply)
            end
        end
    end)

    hook.Add("PlayerDisconnected", "GRM_Mob_Cleanup", function(ply)
        if not IsValid(ply) then return end
        dropLineInternal(ply:SteamID64(), "disconnect")
        local hp = MB.HandProps[ply]
        if IsValid(hp) then hp:Remove() end
        MB.HandProps[ply] = nil
        ply._grmMobSig = nil
    end)

    ----------------------------------------------------------------
    -- предметы инвентаря (7 трубок GTA IV)
    ----------------------------------------------------------------
    if GRM.Inventory and GRM.Inventory.RegisterItem then
        local function regPhones()
            for _, tk in ipairs(MB.Order) do
                local t = MB.Tiers[tk]
                GRM.Inventory.RegisterItem(t.item, {
                    type = "item",
                    name = "Телефон: " .. t.name,
                    desc = t.desc .. " Оператор: " .. t.operator .. ". Открыть — СТРЕЛКА ВВЕРХ.",
                    icon = "icon16/phone.png",
                    maxStack = 1,
                    weight = 0.35,
                    model = t.model,      -- на земле падает настоящей моделью трубки
                    useFunc = "mobile_open",
                })
            end
        end
        -- инвентарь может грузиться позже: пробуем сразу и отложенно
        regPhones()
        timer.Simple(2, regPhones)
    end

    -- MP-константа доступна тестам
    MB._dev = { recOf = recOf, jsonT = jsonT }

    print("[GRM Mobile] Мобильные телефоны v" .. MB.Version .. " загружены (Код 88). Моделей: " .. tostring(#MB.Order))
end

-- ============================================================
-- КЛИЕНТ: оболочка телефона — Код 88.2 (v1.1.0)
-- Плавная навигация: собственный репит-клок вместо OS-авторепита
-- (PlayerButtonDown шлёт системный повтор клавиши 20-40 Гц с плавающей
-- частотой — отсюда «дёрганое» меню, находка 104), анимированная
-- плашка выделения, прокрутка списков окном + скроллбар, silk-иконки
-- приложений, SMS-диалоги пузырьками, fade-переходы экранов.
-- ============================================================
if CLIENT then
    surface.CreateFont("GRMMob_T",  { font = "Roboto", size = 20, weight = 800, extended = true })
    surface.CreateFont("GRMMob_S",  { font = "Roboto", size = 15, weight = 600, extended = true })
    surface.CreateFont("GRMMob_X",  { font = "Roboto", size = 13, weight = 500, extended = true })
    surface.CreateFont("GRMMob_B",  { font = "Roboto", size = 26, weight = 700, extended = true })
    surface.CreateFont("GRMMob_M",  { font = "Roboto", size = 11, weight = 500, extended = true })

    local MC = {
        body  = Color(8, 9, 13, 255),      -- корпус (борт)
        bg    = Color(15, 18, 27, 255),    -- экран
        bgA   = Color(24, 30, 46, 120),    -- обойное пятно 1
        bgB   = Color(38, 28, 58, 90),     -- обойное пятно 2
        head  = Color(21, 26, 38, 255),
        acc   = Color(88, 141, 239),
        green = Color(74, 222, 128),
        red   = Color(248, 113, 113),
        yellow = Color(251, 191, 36),
        text  = Color(243, 246, 251),
        dim   = Color(139, 147, 167),
        panel = Color(24, 30, 44, 235),
        panel2 = Color(31, 39, 57, 235),
        sel   = Color(52, 74, 112, 200),
        scrollc = Color(90, 100, 122, 160),
        bubIn  = Color(29, 36, 53, 255),   -- входящий пузырь
        bubOut = Color(47, 74, 120, 255),  -- исходящий пузырь
    }

    local M = {
        st = { has = false }, open = false, screen = "home",
        sel = 1, scroll = 0, selY = nil, tabs = {}, dialNum = "",
        ringWas = false, callSec = 0, entryPanel = nil,
        down = {}, nextRep = {}, animT = 0, openT = 0,
        flash = {}, threadNum = nil, homeRows = {},
    }

    net.Receive("GRM_Mob_State", function()
        local st = net.ReadTable()
        if not istable(st) then return end
        M.st = st
        local ringing = st.lineState == "ringing"
        if ringing and not M.ringWas then
            local S = (GRM.Phone and GRM.Phone.Config and GRM.Phone.Config.Sounds) or {}
            surface.PlaySound(S.Ring or "ambient/alarms/klaxon1.wav")
        end
        M.ringWas = ringing
        if st.has ~= true and M.open then
            M.open = false M.screen = "home" M.sel = 1
            M.down = {} M.nextRep = {}
        end
    end)
    net.Receive("GRM_Mob_Data", function()
        local tab = net.ReadString()
        local t = net.ReadTable()
        if not istable(t) then return end
        M.tabs[tab] = t
    end)

    local function sendAct(t)
        net.Start("GRM_Mob_Act") net.WriteTable(t or {}) net.SendToServer()
    end

    local function curApps()
        local out = {}
        local tk = M.st.tier
        for _, app in ipairs(MB.Apps) do
            if app.need == nil then
                out[#out + 1] = app
            elseif tk and MB.Tiers[tk] and MB.Tiers[tk][app.need] == true then
                out[#out + 1] = app
            end
        end
        return out
    end

    -- ----------------------------------------------------------
    -- утилиты отрисовки
    -- ----------------------------------------------------------
    local function txt(str, font, x, y, col, ax, ay)
        draw.SimpleText(str, font, x, y, col or MC.text, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_CENTER)
    end

    -- безопасная резка UTF-8 (старый string.sub ломал кириллицу на границе)
    local function usub(s, i, j)
        if utf8 and utf8.sub then
            local ok, r = pcall(utf8.sub, s, i, j)
            if ok then return r end
        end
        return string.sub(s, i, j)
    end
    local function ulen(s)
        if utf8 and utf8.len then
            local ok, r = pcall(utf8.len, s)
            if ok and r then return r end
        end
        return #s
    end

    -- перенос текста по словам под ширину (для пузырей SMS и карточек)
    local function wrapText(s, font, maxW)
        surface.SetFont(font)
        local lines, cur = {}, ""
        for word in string.gmatch(tostring(s), "%S+") do
            local cand = (cur == "") and word or (cur .. " " .. word)
            if surface.GetTextSize(cand) <= maxW then
                cur = cand
            else
                if cur ~= "" then lines[#lines + 1] = cur end
                while ulen(word) > 1 and surface.GetTextSize(word) > maxW do
                    local cut = ulen(word)
                    while cut > 1 and surface.GetTextSize(usub(word, 1, cut)) > maxW do cut = cut - 1 end
                    lines[#lines + 1] = usub(word, 1, cut)
                    word = usub(word, cut + 1, ulen(word))
                end
                cur = word
            end
        end
        if cur ~= "" then lines[#lines + 1] = cur end
        if #lines == 0 then lines[1] = "" end
        return lines
    end

    -- silk-иконки (icon16/* идут в поставке GMod — клиентские материалы)
    local matCache = {}
    local function mat(path)
        local m = matCache[path]
        if not m then
            m = Material(path)
            matCache[path] = m
        end
        return m
    end
    local function drawIcon(path, x, y, s, alpha)
        surface.SetDrawColor(255, 255, 255, alpha or 235)
        surface.SetMaterial(mat(path))
        surface.DrawTexturedRect(x, y, s, s)
    end
    local APP_ICONS = {
        dial = "icon16/phone.png", sms = "icon16/email.png",
        contacts = "icon16/vcard.png", notes = "icon16/note.png",
        jobs = "icon16/briefcase.png", fac = "icon16/group.png",
        forum = "icon16/world.png", calc = "icon16/calculator.png",
    }

    local function bars(x, y)
        local b = tonumber(M.st.bars) or 0
        for i = 1, 5 do
            local h = 4 + i * 2
            local on = i <= b
            draw.RoundedBox(1, x + (i - 1) * 6, y + 12 - h, 4, h, on and MC.green or Color(52, 58, 72))
        end
    end

    -- ----------------------------------------------------------
    -- окно телефона
    -- ----------------------------------------------------------
    local PW, PH = 340, 560
    local CX, CW = 14, PW - 28
    local Y_TOP, Y_BOT = 76, PH - 48
    local phone

    local function killEntry()
        if IsValid(M.entryPanel) then M.entryPanel:Remove() M.entryPanel = nil end
    end

    local screenDraw = {}
    local screenKey = {}
    local screenEnter = {}

    local function goScreen(id)
        if M.screen == id then return end
        M.screen = id M.sel = 1 M.scroll = 0 M.selY = nil
        M.animT = CurTime()
        if screenEnter[id] then screenEnter[id]() end
    end
    local function goHome() goScreen("home") end

    local function openPhone()
        if M.st.has ~= true then return end
        M.open = true M.screen = "home" M.sel = 1 M.dialNum = "" M.scroll = 0
        M.selY = nil M.openT = CurTime() M.animT = CurTime()
        M.down = {} M.nextRep = {}
        sendAct({ op = "open" })
        if screenEnter.home then screenEnter.home() end
    end
    local function closePhone()
        M.open = false M.screen = "home" M.sel = 1 M.dialNum = "" M.scroll = 0
        M.down = {} M.nextRep = {}
        killEntry()
    end

    -- ---------- мягкая панель-заголовок экрана приложения ----------
    local function appHeader(icon, title, right)
        drawIcon(icon, CX, Y_TOP - 6, 20, 240)
        txt(title, "GRMMob_T", CX + 28, Y_TOP + 4, MC.text)
        if right then txt(right, "GRMMob_M", CX + CW, Y_TOP + 4, MC.dim, TEXT_ALIGN_RIGHT) end
        draw.RoundedBox(1, CX, Y_TOP + 18, CW, 1, Color(44, 52, 70, 160))
        return Y_TOP + 30
    end

    -- ---------- универсальный список с окном, анимацией и скроллбаром ----------
    -- render(i, x, y, w, sel) рисует строку (высотой rowH)
    local function drawList(x, w, yTop, yBot, count, rowH, render)
        if count < 1 then return end
        if M.sel < 1 then M.sel = 1 end
        if M.sel > count then M.sel = count end
        local maxVis = math.max(1, math.floor((yBot - yTop) / rowH))
        if M.scroll > count - maxVis then M.scroll = math.max(0, count - maxVis) end
        if M.sel - 1 < M.scroll then M.scroll = M.sel - 1 end
        if M.sel > M.scroll + maxVis then M.scroll = M.sel - maxVis end
        if M.scroll < 0 then M.scroll = 0 end
        local first = M.scroll + 1
        local last = math.min(count, M.scroll + maxVis)
        -- анимированная плашка выделения: лерп по вертикали между строк
        local targetY = yTop + (M.sel - first) * rowH
        if M.selY == nil then M.selY = targetY end
        local ft = math.min(0.25, FrameTime())
        M.selY = M.selY + (targetY - M.selY) * math.min(1, ft * 18)
        if math.abs(M.selY - targetY) < 0.5 then M.selY = targetY end
        if M.sel >= first and M.sel <= last then
            draw.RoundedBox(9, x, math.floor(M.selY) + 1, w, rowH - 3, MC.sel)
            draw.RoundedBox(3, x + 2, math.floor(M.selY) + 7, 4, rowH - 15, MC.acc)
        end
        for i = first, last do
            local y = yTop + (i - first) * rowH
            render(i, x + 12, y, w - 12, i == M.sel)
        end
        if count > maxVis then
            local trackH = yBot - yTop
            local thumbH = math.max(24, math.floor(trackH * maxVis / count))
            local ty = yTop + math.floor((trackH - thumbH) * (M.scroll / (count - maxVis)))
            draw.RoundedBox(2, x + w - 4, ty, 3, thumbH, MC.scrollc)
        end
    end

    -- круговая навигация списком; extra(btn) обрабатывает прочие клавиши
    local function listNavKey(btn, count, extra)
        if btn == KEY_UP then
            M.sel = M.sel - 1
            if M.sel < 1 then M.sel = math.max(1, count) end
        elseif btn == KEY_DOWN then
            M.sel = M.sel + 1
            if M.sel > math.max(1, count) then M.sel = 1 end
        elseif btn == KEY_BACKSPACE then
            goHome()
        elseif extra then
            extra(btn)
        end
    end

    -- ---------- ДОМАШНИЙ (иконки приложений) ----------
    screenEnter.home = function()
        M.homeRows = curApps()
        if M.sel > #M.homeRows then M.sel = #M.homeRows end
        if M.sel < 1 then M.sel = 1 end
    end
    screenDraw.home = function(w, h)
        local rows = M.homeRows
        if #rows == 0 then screenEnter.home() rows = M.homeRows end
        drawList(CX, CW, Y_TOP + 4, Y_BOT, #rows, 42, function(i, x, y, rw, sel)
            local app = rows[i]
            drawIcon(APP_ICONS[app.id] or "icon16/application.png", x + 2, y + 9, 22, sel and 255 or 210)
            txt(app.name, "GRMMob_S", x + 36, y + 20, sel and MC.text or MC.dim)
            if app.id == "sms" and (tonumber(M.st.unread) or 0) > 0 then
                local badge = tostring(M.st.unread)
                surface.SetFont("GRMMob_M")
                local bw = math.max(18, surface.GetTextSize(badge) + 12)
                draw.RoundedBox(9, x + rw - bw - 6, y + 11, bw, 18, MC.red)
                txt(badge, "GRMMob_M", x + rw - bw - 6 + bw / 2, y + 20, Color(255, 255, 255), TEXT_ALIGN_CENTER)
            end
        end)
    end
    -- RP-обмен номерами: номер уходит в ЛОКАЛЬНЫЙ чат (/me радиусом),
    -- как в GTA Online диктуют номер вслух — стоящий рядом запишет его в контакты.
    local function dictateNumber()
        local n = tostring(M.st.number or "")
        if #n < 4 then
            notification.AddLegacy("Номер ещё не выдан — достаньте телефон и подождите пару секунд", NOTIFY_HINT, 4)
            return
        end
        RunConsoleCommand("say", "/me диктует свой мобильный номер: " .. n)
    end
    screenKey.home = function(btn)
        local rows = M.homeRows
        if btn == KEY_UP then
            M.sel = M.sel - 1
            if M.sel < 1 then M.sel = #rows end
        elseif btn == KEY_DOWN then
            M.sel = M.sel + 1
            if M.sel > #rows then M.sel = 1 end
        elseif btn == KEY_E then dictateNumber()
        elseif btn == KEY_ENTER or btn == KEY_PAD_ENTER then
            local app = rows[M.sel]
            if app then
                M.dialNum = ""
                goScreen(app.id)
                if app.id == "jobs" then sendAct({ op = "jobs_query" })
                elseif app.id == "fac" then sendAct({ op = "fac_query" })
                elseif app.id == "forum" then sendAct({ op = "forum_query" })
                elseif app.id == "sms" then sendAct({ op = "open" }) sendAct({ op = "sms_read" }) end
            end
        elseif btn == KEY_BACKSPACE then closePhone() end
    end

    -- ---------- ТЕЛЕФОН (набор) ----------
    local DIAL_KEYS = {
        { "1", "2", "3" }, { "4", "5", "6" }, { "7", "8", "9" },
        { "del", "0", "go" },
    }
    screenDraw.dial = function(w, h)
        local y0 = appHeader(APP_ICONS.dial, "Телефон")
        draw.RoundedBox(10, CX + 6, y0 + 6, CW - 12, 46, Color(12, 16, 25, 255))
        txt(M.dialNum ~= "" and M.dialNum or "введите номер…", "GRMMob_B", w / 2, y0 + 29,
            M.dialNum ~= "" and MC.text or Color(90, 98, 116), TEXT_ALIGN_CENTER)
        local bw, gap = 66, 14
        local x0 = math.floor((w - (3 * bw + 2 * gap)) / 2)
        local now = CurTime()
        for ri, row in ipairs(DIAL_KEYS) do
            for ci, k in ipairs(row) do
                local bx = x0 + (ci - 1) * (bw + gap)
                local by = y0 + 68 + (ri - 1) * (bw * 0.82 + gap)
                local bh = bw * 0.82
                local col = MC.panel
                local tcol = MC.dim
                if k == "go" then col = Color(34, 86, 52, 255) tcol = MC.green end
                if k == "del" then col = Color(38, 32, 40, 255) tcol = MC.red end
                -- вспышка подсветки при наборе цифры (0.15с плавного затухания)
                local ft = M.flash[k]
                if ft then
                    local a = 1 - math.min(1, (now - ft) / 0.15)
                    if a > 0 then col = Color(70 + 40 * a, 90 + 60 * a, 130 + 70 * a, 255) end
                end
                draw.RoundedBox(math.floor(bh / 2), bx, by, bw, bh, col)
                if k == "go" then
                    drawIcon("icon16/phone.png", bx + bw / 2 - 8, by + bh / 2 - 8, 16, 255)
                else
                    txt(k == "del" and "DEL" or k, "GRMMob_T", bx + bw / 2, by + bh / 2, tcol, TEXT_ALIGN_CENTER)
                end
            end
        end
    end
    screenKey.dial = function(btn)
        if btn == KEY_ENTER or btn == KEY_PAD_ENTER then
            if #M.dialNum >= 4 then
                sendAct({ op = "dial", number = M.dialNum })
                M.flash["go"] = CurTime()
                M.dialNum = ""
                goScreen("call")
            end
        elseif btn == KEY_BACKSPACE then
            if #M.dialNum > 0 then
                M.flash["del"] = CurTime()
                M.dialNum = string.sub(M.dialNum, 1, -2)
            else goHome() end
        else
            local d = nil
            if btn >= KEY_0 and btn <= KEY_9 then d = tostring(btn - KEY_0)
            elseif btn >= KEY_PAD_0 and btn <= KEY_PAD_9 then d = tostring(btn - KEY_PAD_0) end
            if d and #M.dialNum < 6 then
                M.flash[d] = CurTime()
                M.dialNum = M.dialNum .. d
            end
        end
    end

    -- ---------- ВЫЗОВ (карточка) ----------
    screenDraw.call = function(w, h)
        local st = M.st
        local state = st.lineState or "idle"
        local num = tostring(st.otherNumber or "…")
        local name = tostring(st.otherName or "")
        -- аватар-круг с инициалом
        local cx, cy, r = w / 2, 158, 46
        local letter = "?"
        if name ~= "" then letter = usub(name, 1, 1)
        elseif num ~= "…" and #num > 0 then letter = usub(num, 1, 1) end
        -- пульс при вызове/входящем
        if state == "dialing" or state == "ringing" then
            local p = (CurTime() * 1.6) % 1
            draw.RoundedBox(r + 14, cx - r - 14, cy - r - 14, (r + 14) * 2, (r + 14) * 2,
                Color(88, 141, 239, math.floor(70 * (1 - p))))
        end
        draw.RoundedBox(r, cx - r, cy - r, r * 2, r * 2, Color(52, 74, 112, 255))
        txt(string.upper(letter), "GRMMob_B", cx, cy, MC.text, TEXT_ALIGN_CENTER)
        txt(num, "GRMMob_B", w / 2, cy + r + 26, MC.text, TEXT_ALIGN_CENTER)
        if name ~= "" then
            txt(name, "GRMMob_S", w / 2, cy + r + 50, MC.dim, TEXT_ALIGN_CENTER)
        end
        local lbl = state == "dialing" and "ВЫЗОВ…"
            or state == "ringing" and "ВХОДЯЩИЙ ВЫЗОВ"
            or state == "call" and ("РАЗГОВОР  " .. string.FormattedTime(M.callSec or 0, "%02i:%02i"))
            or "линия свободна"
        local lcol = state == "call" and MC.green or state == "ringing" and MC.yellow or MC.dim
        txt(lbl, "GRMMob_S", w / 2, cy + r + 74, lcol, TEXT_ALIGN_CENTER)
        -- большие кнопки действий
        local function bigBtn(bx, bw, bh, col, ic, label, sub)
            draw.RoundedBox(12, bx, Y_BOT - 86, bw, bh, col)
            drawIcon(ic, bx + 14, Y_BOT - 86 + bh / 2 - 8, 16, 255)
            txt(label, "GRMMob_S", bx + 40, Y_BOT - 86 + bh / 2 - 7, MC.text)
            txt(sub, "GRMMob_M", bx + 40, Y_BOT - 86 + bh / 2 + 9, Color(220, 226, 238))
        end
        if state == "ringing" then
            bigBtn(CX, 150, 52, Color(24, 74, 44, 255), "icon16/phone.png", "ОТВЕТИТЬ", "ENTER")
            bigBtn(w - CX - 150, 150, 52, Color(88, 32, 32, 255), "icon16/phone_delete.png", "ОТКЛОНИТЬ", "BACKSPACE")
        elseif state == "dialing" or state == "call" then
            if state == "call" then
                txt("Говорите — голос идёт в трубку", "GRMMob_X", w / 2, Y_BOT - 104, MC.dim, TEXT_ALIGN_CENTER)
            end
            bigBtn(CX + (CW - 200) / 2, 200, 52, Color(88, 32, 32, 255), "icon16/phone_delete.png", "ЗАВЕРШИТЬ", "BACKSPACE")
        else
            txt("BACKSPACE — назад", "GRMMob_M", w / 2, Y_BOT - 20, MC.dim, TEXT_ALIGN_CENTER)
        end
    end
    screenKey.call = function(btn)
        if (btn == KEY_ENTER or btn == KEY_PAD_ENTER) and M.st.lineState == "ringing" then
            sendAct({ op = "answer" })
        elseif btn == KEY_BACKSPACE then
            if M.st.lineState == "idle" then
                goHome()
            else
                sendAct({ op = "hangup" })
            end
        end
    end

    -- ---------- SMS: треды (как в современных телефонах) ----------
    local function smsRows() return (M.tabs.sms and M.tabs.sms.rows) or {} end
    local function contactName(num)
        for _, c in ipairs((M.tabs.contacts and M.tabs.contacts.rows) or {}) do
            if tostring(c.num) == tostring(num) then return tostring(c.name) end
        end
        return nil
    end
    local function smsThreads()
        local byNum, order = {}, {}
        for _, e in ipairs(smsRows()) do
            local k = tostring(e.num or "?")
            local th = byNum[k]
            if not th then
                th = { num = k, unread = 0, last = nil }
                byNum[k] = th
                order[#order + 1] = th
            end
            if e.dir == "in" and e.read ~= true then th.unread = th.unread + 1 end
            th.last = e
        end
        table.sort(order, function(a, b)
            local ta = (a.last and tonumber(a.last.ts)) or 0
            local tb = (b.last and tonumber(b.last.ts)) or 0
            return ta > tb
        end)
        return order
    end
    screenDraw.sms = function(w, h)
        local y0 = appHeader(APP_ICONS.sms, "SMS", "N — новая")
        local ths = smsThreads()
        if #ths == 0 then
            txt("ящик пуст", "GRMMob_S", w / 2, y0 + 90, MC.dim, TEXT_ALIGN_CENTER)
            txt("N — написать первое сообщение", "GRMMob_X", w / 2, y0 + 114, MC.dim, TEXT_ALIGN_CENTER)
            return
        end
        drawList(CX, CW, y0 + 6, Y_BOT, #ths, 52, function(i, x, y, rw, sel)
            local th = ths[i]
            local nm = contactName(th.num)
            txt(nm or th.num, "GRMMob_S", x, y + 13, sel and MC.text or MC.text)
            if nm then txt(th.num, "GRMMob_M", x, y + 30, MC.dim) end
            local prev = th.last and (usub(tostring(th.last.text), 1, 30) .. (ulen(tostring(th.last.text)) > 30 and "…" or "")) or ""
            txt(prev, "GRMMob_X", x, nm and (y + 43) or (y + 34), th.unread > 0 and MC.text or MC.dim)
            if th.last then
                txt(os.date("%d.%m %H:%M", th.last.ts), "GRMMob_M", x + rw - 4, y + 13, MC.dim, TEXT_ALIGN_RIGHT)
            end
            if th.unread > 0 then
                draw.RoundedBox(5, x + rw - 14, y + 32, 10, 10, MC.acc)
            end
        end)
    end
    local function smsWrite(preNum)
        Derma_StringRequest("SMS", "Номер получателя (5 цифр мобильного):", preNum or "", function(num)
            num = tostring(num or ""):gsub("%D", "")
            if #num < 4 then return end
            Derma_StringRequest("SMS → " .. num, "Текст сообщения (макс " .. tostring(MB.SmsMaxLen) .. "):", "", function(tx)
                if string.Trim(tostring(tx or "")) == "" then return end
                sendAct({ op = "sms", num = num, text = tx })
            end)
        end)
    end
    screenKey.sms = function(btn)
        local ths = smsThreads()
        if btn == KEY_N then
            smsWrite("")
        elseif btn == KEY_ENTER or btn == KEY_PAD_ENTER then
            local th = ths[M.sel]
            if th then
                M.threadNum = th.num
                M.scroll = 0
                goScreen("smsThread")
            end
        else
            listNavKey(btn, #ths)
        end
    end

    -- ---------- SMS: диалог пузырьками ----------
    local function threadMsgs()
        local out = {}
        for _, e in ipairs(smsRows()) do
            if tostring(e.num) == tostring(M.threadNum) then out[#out + 1] = e end
        end
        return out
    end
    screenDraw.smsThread = function(w, h)
        local nm = contactName(M.threadNum)
        local y0 = appHeader(APP_ICONS.sms, nm or tostring(M.threadNum), nm and tostring(M.threadNum) or nil)
        local msgs = threadMsgs()
        if #msgs == 0 then
            txt("сообщений нет", "GRMMob_X", w / 2, y0 + 90, MC.dim, TEXT_ALIGN_CENTER)
            return
        end
        -- пузыри снизу вверх; M.scroll = сколько пузырей пропущено от конца
        local maxOff = math.max(0, #msgs - 1)
        if M.scroll > maxOff then M.scroll = maxOff end
        if M.scroll < 0 then M.scroll = 0 end
        local y = Y_BOT - 4
        local maxW = math.floor(CW * 0.66)
        local idx = #msgs - M.scroll
        while idx >= 1 and y > y0 + 30 do
            local e = msgs[idx]
            local lines = wrapText(tostring(e.text or ""), "GRMMob_X", maxW)
            if #lines > 6 then
                local cut = {}
                for li = 1, 6 do cut[li] = lines[li] end
                cut[6] = usub(cut[6], 1, math.max(1, ulen(cut[6]) - 1)) .. "…"
                lines = cut
            end
            local bw = 0
            surface.SetFont("GRMMob_X")
            for _, ln in ipairs(lines) do
                local lw = surface.GetTextSize(ln)
                if lw > bw then bw = lw end
            end
            bw = math.max(44, bw + 22)
            local bh = #lines * 15 + 12
            local mineOut = e.dir ~= "in"
            local bx = mineOut and (w - CX - bw) or CX
            y = y - bh
            if y < y0 + 20 then break end
            draw.RoundedBox(10, bx, y, bw, bh, mineOut and MC.bubOut or MC.bubIn)
            for li, ln in ipairs(lines) do
                txt(ln, "GRMMob_X", bx + 11, y + 6 + (li - 1) * 15 + 8, MC.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            local tsl = os.date("%H:%M", e.ts)
            txt(tsl, "GRMMob_M", mineOut and (bx - 6) or (bx + bw + 6), y + bh - 8, Color(90, 98, 116),
                mineOut and TEXT_ALIGN_RIGHT or TEXT_ALIGN_LEFT)
            y = y - 8
            idx = idx - 1
        end
        txt("ENTER — ответить • ↑/↓ — листать • BACKSPACE — назад", "GRMMob_M", w / 2, Y_BOT + 8, MC.dim, TEXT_ALIGN_CENTER)
    end
    screenKey.smsThread = function(btn)
        local msgs = threadMsgs()
        if btn == KEY_UP then
            M.scroll = math.min(math.max(0, #msgs - 1), M.scroll + 1)
        elseif btn == KEY_DOWN then
            M.scroll = math.max(0, M.scroll - 1)
        elseif btn == KEY_BACKSPACE then
            goScreen("sms")
        elseif btn == KEY_ENTER or btn == KEY_PAD_ENTER or btn == KEY_N then
            smsWrite(tostring(M.threadNum or ""))
        end
    end

    -- ---------- КОНТАКТЫ ----------
    local function conRows() return (M.tabs.contacts and M.tabs.contacts.rows) or {} end
    screenDraw.contacts = function(w, h)
        local y0 = appHeader(APP_ICONS.contacts, "Контакты", "N — добавить")
        local rows = conRows()
        if #rows == 0 then
            txt("пусто", "GRMMob_S", w / 2, y0 + 90, MC.dim, TEXT_ALIGN_CENTER)
            txt("N — добавить контакт", "GRMMob_X", w / 2, y0 + 114, MC.dim, TEXT_ALIGN_CENTER)
            return
        end
        drawList(CX, CW, y0 + 6, Y_BOT, #rows, 36, function(i, x, y, rw, sel)
            local c = rows[i]
            drawIcon("icon16/vcard.png", x, y + 10, 16, sel and 255 or 190)
            txt(c.name, "GRMMob_S", x + 24, y + 18, sel and MC.text or MC.dim)
            txt(c.num, "GRMMob_S", x + rw, y + 18, sel and MC.acc or MC.dim, TEXT_ALIGN_RIGHT)
        end)
    end
    screenKey.contacts = function(btn)
        local rows = conRows()
        if btn == KEY_N then
            Derma_StringRequest("Новый контакт", "Имя:", "", function(nm)
                nm = string.Trim(tostring(nm or ""))
                if nm == "" then return end
                Derma_StringRequest("Контакт: " .. nm, "Номер (4–6 цифр):", "", function(num)
                    sendAct({ op = "contact_add", name = nm, num = num })
                end)
            end)
        elseif btn == KEY_ENTER or btn == KEY_PAD_ENTER then
            local c = rows[M.sel]
            if not c then return end
            local m = DermaMenu()
            m:AddOption("Позвонить " .. c.num, function()
                sendAct({ op = "dial", number = c.num }) goScreen("call")
            end):SetIcon("icon16/phone.png")
            if M.st.tier and MB.Tiers[M.st.tier] and MB.Tiers[M.st.tier].sms then
                m:AddOption("Написать SMS", function()
                    Derma_StringRequest("SMS → " .. c.num, "Текст:", "", function(tx)
                        if string.Trim(tostring(tx or "")) == "" then return end
                        sendAct({ op = "sms", num = c.num, text = tx })
                    end)
                end):SetIcon("icon16/email.png")
            end
            m:AddOption("Удалить контакт", function()
                sendAct({ op = "contact_del", i = c.i })
            end):SetIcon("icon16/delete.png")
            m:Open()
        else
            listNavKey(btn, #rows)
        end
    end

    -- ---------- ЗАМЕТКИ ----------
    local function noteRows() return (M.tabs.notes and M.tabs.notes.rows) or {} end
    screenDraw.notes = function(w, h)
        local y0 = appHeader(APP_ICONS.notes, "Заметки", "N — новая")
        local rows = noteRows()
        if #rows == 0 then
            txt("пусто", "GRMMob_S", w / 2, y0 + 90, MC.dim, TEXT_ALIGN_CENTER)
            txt("N — новая заметка • DEL — удалить выбранную", "GRMMob_X", w / 2, y0 + 114, MC.dim, TEXT_ALIGN_CENTER)
            return
        end
        drawList(CX, CW, y0 + 6, Y_BOT, #rows, 46, function(i, x, y, rw, sel)
            local n = rows[i]
            drawIcon("icon16/note.png", x, y + 8, 16, sel and 255 or 190)
            txt(usub(n.text, 1, 44) .. (ulen(n.text) > 44 and "…" or ""), "GRMMob_X", x + 24, y + 15, sel and MC.text or MC.dim)
            txt(os.date("%d.%m.%y %H:%M", n.ts), "GRMMob_M", x + 24, y + 33, Color(98, 106, 126))
        end)
    end
    screenKey.notes = function(btn)
        local rows = noteRows()
        if btn == KEY_N then
            Derma_StringRequest("Новая заметка", "Текст (макс " .. tostring(MB.NoteMaxLen) .. "):", "", function(tx)
                if string.Trim(tostring(tx or "")) == "" then return end
                sendAct({ op = "note_add", text = tx })
            end)
        elseif btn == KEY_DELETE then
            local n = rows[M.sel]
            if n then sendAct({ op = "note_del", i = n.i }) end
        else
            listNavKey(btn, #rows)
        end
    end

    -- ---------- БИРЖА ----------
    screenDraw.jobs = function(w, h)
        local d = M.tabs.jobs or {}
        local rows = d.rows or {}
        local y0 = appHeader(APP_ICONS.jobs, "Биржа труда", "ENTER — обновить")
        if d.mine then
            draw.RoundedBox(8, CX, y0 + 4, CW, 26, Color(24, 58, 40, 220))
            txt("Моя работа: " .. d.mine.title, "GRMMob_X", CX + 10, y0 + 17, MC.green)
            y0 = y0 + 36
        else
            txt("активной работы нет (взять — терминал биржи)", "GRMMob_M", CX + 2, y0 + 12, MC.dim)
            y0 = y0 + 26
        end
        if #rows == 0 then
            txt("публикаций нет", "GRMMob_S", w / 2, y0 + 70, MC.dim, TEXT_ALIGN_CENTER)
            return
        end
        drawList(CX, CW, y0 + 6, Y_BOT, #rows, 44, function(i, x, y, rw, sel)
            local r = rows[i]
            txt(r.title, "GRMMob_S", x, y + 13, sel and MC.text or MC.dim)
            txt(r.fac .. " • " .. r.pay, "GRMMob_M", x, y + 31, sel and MC.text or MC.dim)
            -- бейдж вида публикации
            local badge = r.kind
            surface.SetFont("GRMMob_M")
            local bw = surface.GetTextSize(badge) + 12
            local bc = (r.kind == "вакансия") and Color(24, 74, 44, 255) or Color(35, 56, 92, 255)
            local btx = (r.kind == "вакансия") and MC.green or MC.acc
            draw.RoundedBox(8, x + rw - bw, y + 5, bw, 16, bc)
            txt(badge, "GRMMob_M", x + rw - bw / 2, y + 13, btx, TEXT_ALIGN_CENTER)
        end)
    end
    screenKey.jobs = function(btn)
        local rows = (M.tabs.jobs or {}).rows or {}
        if btn == KEY_ENTER or btn == KEY_PAD_ENTER then
            sendAct({ op = "jobs_query" })
        else
            listNavKey(btn, #rows)
        end
    end

    -- ---------- ФРАКЦИЯ ----------
    screenDraw.fac = function(w, h)
        local d = (M.tabs.fac or {}).data
        local y0 = appHeader(APP_ICONS.fac, "Моя фракция", "ENTER — обновить")
        if not d then
            txt("Вы не состоите во фракции", "GRMMob_S", w / 2, y0 + 90, MC.dim, TEXT_ALIGN_CENTER)
            txt("вступить — доска набора (Код 76)", "GRMMob_X", w / 2, y0 + 114, MC.dim, TEXT_ALIGN_CENTER)
            return
        end
        txt(d.name, "GRMMob_T", w / 2, y0 + 16, MC.text, TEXT_ALIGN_CENTER)
        txt("вы: " .. d.myRole .. " • " .. d.myDept .. "   |   онлайн " .. tostring(d.online) .. "/" .. tostring(d.total),
            "GRMMob_X", w / 2, y0 + 38, MC.dim, TEXT_ALIGN_CENTER)
        local rows = d.rows or {}
        local rowH, yTop = 26, y0 + 56
        local maxVis = math.max(1, math.floor((Y_BOT - yTop) / rowH))
        if M.scroll > math.max(0, #rows - maxVis) then M.scroll = math.max(0, #rows - maxVis) end
        if M.scroll < 0 then M.scroll = 0 end
        for i = M.scroll + 1, math.min(#rows, M.scroll + maxVis) do
            local r = rows[i]
            local y = yTop + (i - M.scroll - 1) * rowH
            local colr = r.online and MC.green or MC.dim
            draw.RoundedBox(4, CX + 4, y + 5, 8, 8, r.online and MC.green or Color(70, 76, 92))
            txt(r.name .. (r.leader and " ★" or ""), "GRMMob_X", CX + 20, y + 9, r.online and MC.text or MC.dim)
            txt(r.role .. " / " .. r.dept, "GRMMob_M", CX + CW - 8, y + 9, colr, TEXT_ALIGN_RIGHT)
        end
        if #rows > maxVis then
            local trackH = Y_BOT - yTop
            local thumbH = math.max(24, math.floor(trackH * maxVis / #rows))
            local ty = yTop + math.floor((trackH - thumbH) * (M.scroll / (#rows - maxVis)))
            draw.RoundedBox(2, CX + CW - 4, ty, 3, thumbH, MC.scrollc)
        end
    end
    screenKey.fac = function(btn)
        local d = (M.tabs.fac or {}).data
        local rows = (d and d.rows) or {}
        if btn == KEY_ENTER or btn == KEY_PAD_ENTER then
            sendAct({ op = "fac_query" })
        elseif btn == KEY_UP then
            M.scroll = math.max(0, M.scroll - 1)
        elseif btn == KEY_DOWN then
            local rowH, yTop = 26, Y_TOP + 86
            local maxVis = math.max(1, math.floor((Y_BOT - yTop) / rowH))
            M.scroll = math.min(math.max(0, #rows - maxVis), M.scroll + 1)
        elseif btn == KEY_BACKSPACE then
            goHome()
        end
    end

    -- ---------- ФОРУМ ----------
    screenDraw.forum = function(w, h)
        local rows = (M.tabs.forum or {}).rows or {}
        local y0 = appHeader(APP_ICONS.forum, "Городской форум", "N — написать")
        if #rows == 0 then
            txt("пусто — будь первым!", "GRMMob_S", w / 2, y0 + 90, MC.dim, TEXT_ALIGN_CENTER)
            return
        end
        local rowH = 66
        local maxVis = math.max(1, math.floor((Y_BOT - y0 - 6) / rowH))
        if M.scroll > math.max(0, #rows - maxVis) then M.scroll = math.max(0, #rows - maxVis) end
        if M.scroll < 0 then M.scroll = 0 end
        for i = M.scroll + 1, math.min(#rows, M.scroll + maxVis) do
            local p = rows[i]
            local y = y0 + 6 + (i - M.scroll - 1) * rowH
            draw.RoundedBox(9, CX, y, CW, rowH - 8, MC.panel)
            txt(p.author, "GRMMob_X", CX + 10, y + 12, MC.acc)
            txt(os.date("%d.%m %H:%M", p.ts), "GRMMob_M", CX + CW - 10, y + 12, MC.dim, TEXT_ALIGN_RIGHT)
            local lines = wrapText(p.text, "GRMMob_X", CW - 20)
            local shown = math.min(2, #lines)
            for li = 1, shown do
                local ln = lines[li]
                if li == shown and #lines > 2 then ln = usub(ln, 1, math.max(1, ulen(ln) - 1)) .. "…" end
                txt(ln, "GRMMob_X", CX + 10, y + 27 + (li - 1) * 14, MC.text)
            end
        end
        if #rows > maxVis then
            local trackH = Y_BOT - y0 - 6
            local thumbH = math.max(24, math.floor(trackH * maxVis / #rows))
            local ty = y0 + 6 + math.floor((trackH - thumbH) * (M.scroll / (#rows - maxVis)))
            draw.RoundedBox(2, CX + CW - 4, ty, 3, thumbH, MC.scrollc)
        end
    end
    screenKey.forum = function(btn)
        local rows = (M.tabs.forum or {}).rows or {}
        if btn == KEY_BACKSPACE then
            goHome()
        elseif btn == KEY_ENTER or btn == KEY_PAD_ENTER then
            sendAct({ op = "forum_query" })
        elseif btn == KEY_UP then
            M.scroll = math.max(0, M.scroll - 1)
        elseif btn == KEY_DOWN then
            local rowH = 66
            local maxVis = math.max(1, math.floor((Y_BOT - Y_TOP - 36) / rowH))
            M.scroll = math.min(math.max(0, #rows - maxVis), M.scroll + 1)
        elseif btn == KEY_N then
            Derma_StringRequest("Пост на форум", "Текст (макс " .. tostring(MB.ForumMaxLen) .. "):", "", function(tx)
                if #string.Trim(tostring(tx or "")) < 2 then return end
                sendAct({ op = "forum_post", text = tx })
            end)
        end
    end

    -- ---------- КАЛЬКУЛЯТОР ----------
    local calc = { cur = "0", acc = nil, oper = nil, fresh = true }
    local function calcKey(k)
        if k == "C" then calc.cur, calc.acc, calc.oper, calc.fresh = "0", nil, nil, true
        elseif k == "=" then
            local b = tonumber(calc.cur) or 0
            local a = tonumber(calc.acc) or b
            local r = b
            if calc.oper == "+" then r = a + b
            elseif calc.oper == "-" then r = a - b
            elseif calc.oper == "*" then r = a * b
            elseif calc.oper == "/" then r = (b ~= 0) and (a / b) or 0 end
            calc.cur = tostring(math.floor(r * 100 + 0.5) / 100)
            calc.acc, calc.oper, calc.fresh = nil, nil, true
        elseif k == "+" or k == "-" or k == "*" or k == "/" then
            calc.acc = tonumber(calc.cur) or 0
            calc.oper = k calc.fresh = true
        else
            if calc.fresh or calc.cur == "0" then calc.cur = k calc.fresh = false
            elseif #calc.cur < 9 then calc.cur = calc.cur .. k end
        end
    end
    local CALC_KEYS = {
        { "7", "8", "9", "/" }, { "4", "5", "6", "*" },
        { "1", "2", "3", "-" }, { "0", "C", "=", "+" },
    }
    screenDraw.calc = function(w, h)
        local y0 = appHeader(APP_ICONS.calc, "Калькулятор")
        draw.RoundedBox(10, CX + 6, y0 + 4, CW - 12, 46, Color(12, 16, 25, 255))
        local disp = calc.cur
        if calc.oper then disp = tostring(calc.acc) .. " " .. calc.oper .. " " .. (calc.fresh and "" or calc.cur) end
        txt(disp, "GRMMob_B", CX + CW - 20, y0 + 27, MC.text, TEXT_ALIGN_RIGHT)
        local now = CurTime()
        for ri, row in ipairs(CALC_KEYS) do
            for ci, k in ipairs(row) do
                local i = (ri - 1) * 4 + ci
                local bx = CX + 6 + (ci - 1) * 62
                local by = y0 + 62 + (ri - 1) * 52
                local sel = (M.sel == i)
                local isOp = (k == "+" or k == "-" or k == "*" or k == "/")
                local col = sel and MC.sel or (isOp and Color(38, 48, 72, 255) or MC.panel)
                local tcol = sel and MC.text or (isOp and MC.acc or (k == "=" and MC.green or MC.dim))
                local ft = M.flash["c" .. i]
                if ft then
                    local a = 1 - math.min(1, (now - ft) / 0.15)
                    if a > 0 then col = Color(70 + 40 * a, 90 + 60 * a, 130 + 70 * a, 255) end
                end
                draw.RoundedBox(10, bx, by, 54, 44, col)
                txt(k, "GRMMob_T", bx + 27, by + 22, tcol, TEXT_ALIGN_CENTER)
            end
        end
        txt("стрелки + ENTER или цифры клавиатуры", "GRMMob_M", w / 2, Y_BOT + 8, MC.dim, TEXT_ALIGN_CENTER)
    end
    screenKey.calc = function(btn)
        if btn == KEY_UP then M.sel = M.sel - 4 if M.sel < 1 then M.sel = M.sel + 16 end
        elseif btn == KEY_DOWN then M.sel = M.sel + 4 if M.sel > 16 then M.sel = M.sel - 16 end
        elseif btn == KEY_LEFT then M.sel = M.sel - 1 if M.sel < 1 then M.sel = 16 end
        elseif btn == KEY_RIGHT then M.sel = M.sel + 1 if M.sel > 16 then M.sel = 1 end
        elseif btn == KEY_ENTER or btn == KEY_PAD_ENTER then
            local i = M.sel
            local k = CALC_KEYS[math.floor((i - 1) / 4) + 1][(i - 1) % 4 + 1]
            M.flash["c" .. i] = CurTime()
            calcKey(k)
        elseif btn == KEY_BACKSPACE then goHome()
        else
            local d = nil
            if btn >= KEY_0 and btn <= KEY_9 then d = tostring(btn - KEY_0)
            elseif btn >= KEY_PAD_0 and btn <= KEY_PAD_9 then d = tostring(btn - KEY_PAD_0)
            elseif btn == KEY_PAD_DIVIDE then d = "/"
            elseif btn == KEY_PAD_MULTIPLY then d = "*"
            elseif btn == KEY_PAD_MINUS then d = "-"
            elseif btn == KEY_PAD_PLUS then d = "+" end
            if d then calcKey(d) end
        end
    end

    -- ----------------------------------------------------------
    -- отрисовка корпуса и экрана (современный смартфон)
    -- ----------------------------------------------------------
    local function ensurePhone()
        if IsValid(phone) then return phone end
        phone = vgui.Create("DPanel")
        phone:SetSize(PW, PH)
        phone:SetPos(ScrW() - PW - 24, ScrH() - PH - 80)
        phone:SetVisible(false)
        phone.Paint = function(_, w, h)
            if not M.open then return end
            -- плавный подъём снизу при открытии (0.18с, easing-out)
            local ox = ScrW() - PW - 24
            local oy = ScrH() - PH - 80
            local ot = CurTime() - (M.openT or 0)
            if ot < 0.18 then
                local k = 1 - ot / 0.18
                oy = oy + math.floor(k * k * 30)
            end
            local px, py = phone:GetPos()
            if px ~= ox or py ~= oy then phone:SetPos(ox, oy) end
            -- корпус: толстый борт + экран внутри
            draw.RoundedBox(24, 0, 0, w, h, MC.body)
            draw.RoundedBox(18, 2, 2, w - 4, h - 4, Color(28, 30, 40, 255))
            draw.RoundedBox(16, 8, 8, w - 16, h - 16, MC.bg)
            -- «обои»: два мягких пятна
            draw.RoundedBox(90, w - 150, 30, 190, 190, MC.bgA)
            draw.RoundedBox(80, -60, 300, 170, 170, MC.bgB)
            -- статус-бар
            bars(20, 24)
            txt(M.st.operator or "—", "GRMMob_X", 58, 27, MC.dim)
            txt(os.date("%H:%M"), "GRMMob_S", w - 18, 27, MC.dim, TEXT_ALIGN_RIGHT)
            txt(tostring(M.st.modelName or "—") .. "  •  " .. tostring(M.st.number ~= "" and M.st.number or "нет номера"),
                "GRMMob_X", w / 2, 56, MC.dim, TEXT_ALIGN_CENTER)
            draw.RoundedBox(1, CX, 66, CW, 1, Color(44, 52, 70, 160))
            -- контент экрана с fade-переходом между экранами (0.12с)
            local a = math.min(1, (CurTime() - (M.animT or 0)) / 0.12)
            surface.SetAlphaMultiplier(a)
            local fn = screenDraw[M.screen] or screenDraw.home
            fn(w, h)
            surface.SetAlphaMultiplier(1)
            -- софт-кей бар
            draw.RoundedBox(1, CX, Y_BOT + 34, CW, 1, Color(44, 52, 70, 160))
            draw.RoundedBox(8, CX, Y_BOT + 40, 148, 24, Color(24, 30, 44, 220))
            drawIcon("icon16/accept.png", CX + 8, Y_BOT + 44, 16, 230)
            txt("ENTER — выбрать", "GRMMob_M", CX + 30, Y_BOT + 52, MC.dim)
            draw.RoundedBox(8, w - CX - 148, Y_BOT + 40, 148, 24, Color(24, 30, 44, 220))
            drawIcon("icon16/arrow_undo.png", w - CX - 140, Y_BOT + 44, 16, 230)
            txt("BACKSPACE — назад", "GRMMob_M", w - CX - 118, Y_BOT + 52, MC.dim)
        end
        phone.OnMousePressed = function(_, mc)
            -- клики по кнопкам калькулятора
            if M.open and M.screen == "calc" then
                local mx, my = phone:CursorPos()
                for ri, row in ipairs(CALC_KEYS) do
                    for ci, k in ipairs(row) do
                        local bx = CX + 6 + (ci - 1) * 62
                        local by = (Y_TOP + 30) + 62 + (ri - 1) * 52
                        if mx >= bx and mx <= bx + 54 and my >= by and my <= by + 44 then
                            M.sel = (ri - 1) * 4 + ci
                            calcKey(k)
                            return
                        end
                    end
                end
            end
        end
        return phone
    end

    -- ----------------------------------------------------------
    -- клавиши: собственный репит-клок (лечение «дёрганого» меню)
    -- OS-авторепит клавиатуры шлёт PlayerButtonDown пачками с плавающей
    -- частотой (настройки ОС, SDL) — половина «рывков» меню была отсюда.
    -- Мы глушим системный повтор и сами повторяем стрелки ровно:
    -- удержание 0.45с, затем шаг 0.11с (≈9 строк/с) — как в GTA IV.
    -- ----------------------------------------------------------
    local NAV_KEYS = {
        [KEY_UP] = true, [KEY_DOWN] = true, [KEY_LEFT] = true, [KEY_RIGHT] = true,
    }
    local REP_DELAY, REP_INT = 0.45, 0.11
    local noPhoneHintTs = 0

    local function fireKey(btn)
        if not M.open then
            if btn == KEY_UP and M.st.has == true then
                openPhone()
                phone = ensurePhone()
                phone:SetVisible(true)
                screenEnter.home()
            elseif (btn == KEY_ENTER or btn == KEY_PAD_ENTER) and M.st.lineState == "ringing" then
                sendAct({ op = "answer" })
                if not M.open then
                    openPhone()
                    phone = ensurePhone()
                    phone:SetVisible(true)
                    goScreen("call")
                end
            elseif btn == KEY_BACKSPACE and M.st.lineState == "ringing" then
                sendAct({ op = "hangup" })
            end
            return
        end
        local fn = screenKey[M.screen] or screenKey.home
        fn(btn)
    end

    hook.Add("PlayerButtonDown", "GRM_Mob_Keys", function(ply, btn)
        if ply ~= LocalPlayer() then return end
        if vgui.GetKeyboardFocus() ~= nil then return end
        if not M.st.has then
            if btn == KEY_UP and CurTime() - noPhoneHintTs >= 15 then
                noPhoneHintTs = CurTime()
                notification.AddLegacy("Мобильного нет: купите трубку в /phoneshop (раздел «Мобильные»)", NOTIFY_HINT, 5)
            end
            return
        end
        -- системный авторепит глушим: повторный Down без Up — не наше событие
        if M.down[btn] then return end
        M.down[btn] = CurTime()
        M.nextRep[btn] = CurTime() + REP_DELAY
        fireKey(btn)
    end)

    hook.Add("PlayerButtonUp", "GRM_Mob_KeysUp", function(ply, btn)
        if ply ~= LocalPlayer() then return end
        M.down[btn] = nil
        M.nextRep[btn] = nil
    end)

    hook.Add("Think", "GRM_Mob_NavTick", function()
        if not M.open then return end
        if vgui.GetKeyboardFocus() ~= nil then return end
        local now = CurTime()
        for btn, _ in pairs(M.down) do
            -- подстраховка от «залипания»: событие Up потерялось (альт-таб и т.п.)
            if not input.IsKeyDown(btn) then
                M.down[btn] = nil
                M.nextRep[btn] = nil
            elseif NAV_KEYS[btn] and M.nextRep[btn] and now >= M.nextRep[btn] then
                M.nextRep[btn] = now + REP_INT
                fireKey(btn)
            end
        end
    end)

    -- запасной путь открытия (у кого стрелки заняты биндами): grm_mobile_open
    concommand.Add("grm_mobile_open", function()
        if not M.st.has then
            notification.AddLegacy("Мобильного нет: купите трубку в /phoneshop (раздел «Мобильные»)", NOTIFY_HINT, 5)
            return
        end
        if M.open then return end
        openPhone()
        phone = ensurePhone()
        phone:SetVisible(true)
        screenEnter.home()
    end)

    -- секундомер разговора + скрытие панели при закрытии
    timer.Create("GRM_Mob_Tick", 1, 0, function()
        if M.st.lineState == "call" then M.callSec = (M.callSec or 0) + 1 else M.callSec = 0 end
        if IsValid(phone) then phone:SetVisible(M.open and M.st.has == true) end
        if M.open and M.st.has ~= true then closePhone() end
    end)

    -- мини-карточка входящего в HUD (даже когда телефон убран): пульс рамки
    hook.Add("HUDPaint", "GRM_Mob_Incoming", function()
        if M.open then return end
        if M.st.lineState ~= "ringing" then return end
        local w, h = 310, 96
        local x, y = ScrW() - w - 24, ScrH() - h - 168
        local pulse = math.floor(60 + 50 * math.sin(CurTime() * 5))
        draw.RoundedBox(12, x, y, w, h, Color(12, 16, 24, 240))
        draw.RoundedBox(12, x, y, w, 2, Color(251, 191, 36, pulse + 60))
        drawIcon("icon16/phone_sound.png", x + 14, y + 14, 16, 255)
        txt("ВХОДЯЩИЙ ВЫЗОВ", "GRMMob_S", x + 38, y + 22, MC.yellow)
        txt(tostring(M.st.otherNumber or "…"), "GRMMob_T", x + w / 2, y + 48, MC.text, TEXT_ALIGN_CENTER)
        if M.st.otherName and M.st.otherName ~= "" then
            txt(tostring(M.st.otherName), "GRMMob_X", x + w / 2, y + 66, MC.dim, TEXT_ALIGN_CENTER)
        end
        txt("ENTER — ответить  •  BACKSPACE — отклонить", "GRMMob_M", x + w / 2, y + h - 12, MC.dim, TEXT_ALIGN_CENTER)
    end)

    print("[GRM Mobile] Клиент v" .. MB.Version .. " загружен (стрелка ВВЕРХ — достать телефон; плавная навигация 88.2)")
end
