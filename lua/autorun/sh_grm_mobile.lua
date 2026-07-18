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

MB.Version   = "1.0.1"
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
-- КЛИЕНТ: оболочка телефона (стрелки, как в GTA IV)
-- ============================================================
if CLIENT then
    surface.CreateFont("GRMMob_T",  { font = "Roboto", size = 20, weight = 800, extended = true })
    surface.CreateFont("GRMMob_S",  { font = "Roboto", size = 15, weight = 600, extended = true })
    surface.CreateFont("GRMMob_X",  { font = "Roboto", size = 13, weight = 500, extended = true })
    surface.CreateFont("GRMMob_B",  { font = "Roboto", size = 26, weight = 700, extended = true })
    surface.CreateFont("GRMMob_M",  { font = "Roboto", size = 11, weight = 500, extended = true })

    local MC = {
        bg = Color(10, 12, 18, 245), head = Color(24, 30, 42, 255), acc = Color(70, 160, 250),
        green = Color(80, 210, 130), red = Color(225, 85, 80), yellow = Color(235, 195, 75),
        text = Color(240, 245, 250), dim = Color(150, 158, 172), panel = Color(30, 36, 48, 240),
        sel = Color(58, 90, 130, 255),
    }

    local M = {
        st = { has = false }, open = false, screen = "home",
        sel = 1, scroll = 0, tabs = {}, dialNum = "", ringWas = false,
        callSec = 0, entryPanel = nil, hint = "",
    }
    local appsList = {}

    net.Receive("GRM_Mob_State", function()
        local st = net.ReadTable()
        if not istable(st) then return end
        M.st = st
        -- звонок входящего: звук при переходе
        local ringing = st.lineState == "ringing"
        if ringing and not M.ringWas then
            local S = (GRM.Phone and GRM.Phone.Config and GRM.Phone.Config.Sounds) or {}
            surface.PlaySound(S.Ring or "ambient/alarms/klaxon1.wav")
        end
        M.ringWas = ringing
        if st.has ~= true and M.open then M.open = false M.screen = "home" M.sel = 1 end
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
        appsList = {}
        local tk = M.st.tier
        for _, app in ipairs(MB.Apps) do
            if app.need == nil then
                appsList[#appsList + 1] = app
            elseif tk and MB.Tiers[tk] and MB.Tiers[tk][app.need] == true then
                appsList[#appsList + 1] = app
            end
        end
        return appsList
    end

    local function openPhone()
        if M.st.has ~= true then return end
        M.open = true M.screen = "home" M.sel = 1 M.dialNum = "" M.scroll = 0
        sendAct({ op = "open" })
    end
    local function closePhone()
        M.open = false M.screen = "home" M.sel = 1 M.dialNum = "" M.scroll = 0
        if IsValid(M.entryPanel) then M.entryPanel:Remove() M.entryPanel = nil end
    end

    -- ----------------------------------------------------------
    -- окно телефона (фиксированная панель у правого края)
    -- ----------------------------------------------------------
    local PW, PH = 340, 560
    local phone

    local function killEntry()
        if IsValid(M.entryPanel) then M.entryPanel:Remove() M.entryPanel = nil end
    end

    local function bars(x, y)
        local b = tonumber(M.st.bars) or 0
        for i = 1, 5 do
            local on = i <= b
            draw.RoundedBox(1, x + (i - 1) * 7, y - i * 2, 5, 4 + i * 2, on and MC.green or Color(60, 66, 78))
        end
    end

    local function txt(str, font, x, y, col, ax, ay)
        draw.SimpleText(str, font, x, y, col or MC.text, ax or TEXT_ALIGN_LEFT, ay or TEXT_ALIGN_CENTER)
    end

    local screenDraw = {}
    local screenKey = {}
    local screenEnter = {}

    -- ---------- ДОМАШНИЙ ----------
    local HOME_ROWS = {}
    screenEnter.home = function()
        HOME_ROWS = curApps()
        if M.sel > #HOME_ROWS then M.sel = #HOME_ROWS end
        if M.sel < 1 then M.sel = 1 end
    end
    screenDraw.home = function(w, h)
        local y = 88
        for i, app in ipairs(HOME_ROWS) do
            local sel = (i == M.sel)
            if sel then draw.RoundedBox(6, 12, y - 16, w - 24, 34, MC.sel) end
            txt(app.name, "GRMMob_S", 22, y, sel and MC.text or MC.dim)
            if app.id == "sms" and (tonumber(M.st.unread) or 0) > 0 then
                txt(tostring(M.st.unread), "GRMMob_S", w - 26, y, MC.red, TEXT_ALIGN_RIGHT)
            end
            y = y + 40
        end
        txt("↑/↓ — выбор • ENTER — открыть • BACKSPACE — убрать", "GRMMob_M", w / 2, h - 14, MC.dim, TEXT_ALIGN_CENTER)
    end
    screenKey.home = function(btn)
        if btn == KEY_UP then M.sel = M.sel - 1 if M.sel < 1 then M.sel = #HOME_ROWS end
        elseif btn == KEY_DOWN then M.sel = M.sel + 1 if M.sel > #HOME_ROWS then M.sel = 1 end
        elseif btn == KEY_ENTER then
            local app = HOME_ROWS[M.sel]
            if app then
                M.screen = app.id M.sel = 1 M.scroll = 0 M.dialNum = ""
                if screenEnter[app.id] then screenEnter[app.id]() end
                if app.id == "jobs" then sendAct({ op = "jobs_query" })
                elseif app.id == "fac" then sendAct({ op = "fac_query" })
                elseif app.id == "forum" then sendAct({ op = "forum_query" })
                elseif app.id == "sms" then sendAct({ op = "open" }) sendAct({ op = "sms_read" }) end
            end
        elseif btn == KEY_BACKSPACE then closePhone() end
    end

    -- ---------- ТЕЛЕФОН (набор) ----------
    screenDraw.dial = function(w, h)
        txt("Введите номер:", "GRMMob_S", w / 2, 100, MC.dim, TEXT_ALIGN_CENTER)
        draw.RoundedBox(8, 40, 116, w - 80, 48, Color(20, 26, 36, 255))
        txt(M.dialNum ~= "" and M.dialNum or "_", "GRMMob_B", w / 2, 140, M.dialNum ~= "" and MC.text or MC.dim, TEXT_ALIGN_CENTER)
        local y = 190
        for i = 1, 10 do
            local d = tostring(i % 10)
            local col = (i - 1) % 3
            local row = math.floor((i - 1) / 3)
            local bx = 60 + col * 74
            local by = y + row * 46
            draw.RoundedBox(6, bx, by, 64, 38, MC.panel)
            txt(d, "GRMMob_T", bx + 32, by + 19, MC.dim, TEXT_ALIGN_CENTER)
        end
        txt("ENTER — позвонить • BACKSPACE — стереть/назад", "GRMMob_M", w / 2, h - 14, MC.dim, TEXT_ALIGN_CENTER)
    end
    screenKey.dial = function(btn)
        if btn == KEY_ENTER then
            if #M.dialNum >= 4 then
                sendAct({ op = "dial", number = M.dialNum })
                M.dialNum = ""
                M.screen = "call"
            end
        elseif btn == KEY_BACKSPACE then
            if #M.dialNum > 0 then M.dialNum = string.sub(M.dialNum, 1, -2)
            else M.screen = "home" M.sel = 1 screenEnter.home() end
        else
            local d = nil
            if btn >= KEY_0 and btn <= KEY_9 then d = tostring(btn - KEY_0)
            elseif btn >= KEY_PAD_0 and btn <= KEY_PAD_9 then d = tostring(btn - KEY_PAD_0) end
            if d and #M.dialNum < 6 then M.dialNum = M.dialNum .. d end
        end
    end

    -- ---------- ВЫЗОВ (карточка) ----------
    screenDraw.call = function(w, h)
        local st = M.st
        local state = st.lineState or "idle"
        local num = st.otherNumber or "…"
        txt(num, "GRMMob_B", w / 2, 130, MC.text, TEXT_ALIGN_CENTER)
        local lbl = state == "dialing" and "ВЫЗОВ…"
            or state == "ringing" and "ВХОДЯЩИЙ ВЫЗОВ"
            or state == "call" and ("РАЗГОВОР  " .. string.FormattedTime(M.callSec or 0, "%02i:%02i"))
            or "линия свободна"
        txt(lbl, "GRMMob_S", w / 2, 172,
            state == "call" and MC.green or state == "ringing" and MC.yellow or MC.dim, TEXT_ALIGN_CENTER)
        if state == "ringing" then
            txt("ENTER — ответить", "GRMMob_S", w / 2, h - 90, MC.green, TEXT_ALIGN_CENTER)
        end
        if state == "call" then
            txt("Говорите — голос идёт в трубку", "GRMMob_X", w / 2, 210, MC.dim, TEXT_ALIGN_CENTER)
        end
        txt("BACKSPACE — " .. (state == "idle" and "назад" or "положить трубку"), "GRMMob_M", w / 2, h - 14, MC.dim, TEXT_ALIGN_CENTER)
    end
    screenKey.call = function(btn)
        if btn == KEY_ENTER and M.st.lineState == "ringing" then
            sendAct({ op = "answer" })
        elseif btn == KEY_BACKSPACE then
            if M.st.lineState == "idle" then
                M.screen = "home" M.sel = 1 screenEnter.home()
            else
                sendAct({ op = "hangup" })
            end
        end
    end

    -- ---------- SMS ----------
    local function smsRows() return (M.tabs.sms and M.tabs.sms.rows) or {} end
    screenDraw.sms = function(w, h)
        local rows = smsRows()
        txt("SMS (ENTER — написать)", "GRMMob_X", 16, 92, MC.dim)
        local y = 116
        local start = math.max(1, #rows - 7)
        for i = start, #rows do
            local e = rows[i]
            local sel = (i == M.sel)
            local who = (e.dir == "in") and ("от " .. e.num .. (e.fromName ~= "" and (" (" .. e.fromName .. ")") or "")) or ("мне → " .. e.num)
            local colr = e.dir == "in" and (e.read and MC.dim or MC.text) or MC.green
            txt(who, "GRMMob_X", 16, y, colr)
            txt(string.sub(e.text, 1, 44), "GRMMob_X", 16, y + 13, e.dir == "in" and (e.read and MC.dim or MC.text) or MC.dim)
            txt(os.date("%d.%m %H:%M", e.ts), "GRMMob_M", w - 14, y, MC.dim, TEXT_ALIGN_RIGHT)
            y = y + 32
        end
        if #rows == 0 then txt("ящик пуст", "GRMMob_X", w / 2, 200, MC.dim, TEXT_ALIGN_CENTER) end
        txt("ENTER в списке — ответить • BACKSPACE — назад", "GRMMob_M", w / 2, h - 14, MC.dim, TEXT_ALIGN_CENTER)
    end
    screenKey.sms = function(btn)
        if btn == KEY_BACKSPACE then
            M.screen = "home" M.sel = 1 screenEnter.home()
        elseif btn == KEY_ENTER then
            -- компоузер: номер + текст двумя запросами
            local rows = smsRows()
            local pre = ""
            local e = rows[M.sel]
            if e then pre = (e.dir == "in") and e.num or e.num end
            Derma_StringRequest("SMS", "Номер получателя (5 цифр мобильного):", pre, function(num)
                num = tostring(num or ""):gsub("%D", "")
                if #num < 4 then return end
                Derma_StringRequest("SMS → " .. num, "Текст сообщения (макс " .. tostring(MB.SmsMaxLen) .. "):", "", function(tx)
                    if string.Trim(tostring(tx or "")) == "" then return end
                    sendAct({ op = "sms", num = num, text = tx })
                end)
            end)
        end
    end

    -- ---------- КОНТАКТЫ ----------
    local function conRows() return (M.tabs.contacts and M.tabs.contacts.rows) or {} end
    screenDraw.contacts = function(w, h)
        local rows = conRows()
        txt("Контакты: ENTER — действия • N — добавить", "GRMMob_X", 16, 92, MC.dim)
        local y = 116
        for i, c in ipairs(rows) do
            if i > 14 then break end
            local sel = (i == M.sel)
            if sel then draw.RoundedBox(6, 10, y - 12, w - 20, 26, MC.sel) end
            txt(c.name, "GRMMob_X", 16, y, sel and MC.text or MC.dim)
            txt(c.num, "GRMMob_X", w - 16, y, sel and MC.text or MC.dim, TEXT_ALIGN_RIGHT)
            y = y + 28
        end
        if #rows == 0 then txt("пусто (N — добавить)", "GRMMob_X", w / 2, 200, MC.dim, TEXT_ALIGN_CENTER) end
    end
    screenKey.contacts = function(btn)
        local rows = conRows()
        if btn == KEY_UP then M.sel = math.max(1, M.sel - 1)
        elseif btn == KEY_DOWN then M.sel = math.min(math.max(1, #rows), M.sel + 1)
        elseif btn == KEY_BACKSPACE then M.screen = "home" M.sel = 1 screenEnter.home()
        elseif btn == KEY_N then
            Derma_StringRequest("Новый контакт", "Имя:", "", function(nm)
                nm = string.Trim(tostring(nm or ""))
                if nm == "" then return end
                Derma_StringRequest("Контакт: " .. nm, "Номер (4–6 цифр):", "", function(num)
                    sendAct({ op = "contact_add", name = nm, num = num })
                end)
            end)
        elseif btn == KEY_ENTER then
            local c = rows[M.sel]
            if not c then return end
            local m = DermaMenu()
            m:AddOption("Позвонить " .. c.num, function()
                sendAct({ op = "dial", number = c.num }) M.screen = "call"
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
        end
    end

    -- ---------- ЗАМЕТКИ ----------
    local function noteRows() return (M.tabs.notes and M.tabs.notes.rows) or {} end
    screenDraw.notes = function(w, h)
        local rows = noteRows()
        txt("Заметки: N — новая • DEL — удалить", "GRMMob_X", 16, 92, MC.dim)
        local y = 116
        for i, n in ipairs(rows) do
            if i > 13 then break end
            local sel = (i == M.sel)
            if sel then draw.RoundedBox(6, 10, y - 12, w - 20, 42, MC.sel) end
            txt(string.sub(n.text, 1, 52), "GRMMob_X", 16, y, sel and MC.text or MC.dim)
            txt(os.date("%d.%m.%y %H:%M", n.ts), "GRMMob_M", 16, y + 14, MC.dim)
            y = y + 44
        end
        if #rows == 0 then txt("пусто (N — новая)", "GRMMob_X", w / 2, 200, MC.dim, TEXT_ALIGN_CENTER) end
    end
    screenKey.notes = function(btn)
        local rows = noteRows()
        if btn == KEY_UP then M.sel = math.max(1, M.sel - 1)
        elseif btn == KEY_DOWN then M.sel = math.min(math.max(1, #rows), M.sel + 1)
        elseif btn == KEY_BACKSPACE then M.screen = "home" M.sel = 1 screenEnter.home()
        elseif btn == KEY_N then
            Derma_StringRequest("Новая заметка", "Текст (макс " .. tostring(MB.NoteMaxLen) .. "):", "", function(tx)
                if string.Trim(tostring(tx or "")) == "" then return end
                sendAct({ op = "note_add", text = tx })
            end)
        elseif btn == KEY_DELETE then
            local n = rows[M.sel]
            if n then sendAct({ op = "note_del", i = n.i }) end
        end
    end

    -- ---------- БИРЖА ----------
    screenDraw.jobs = function(w, h)
        local d = M.tabs.jobs or {}
        local rows = d.rows or {}
        txt("Биржа труда (заказы/вакансии фракций)", "GRMMob_X", 16, 92, MC.dim)
        if d.mine then
            txt("Моя работа: " .. d.mine.title, "GRMMob_X", 16, 110, MC.green)
        else
            txt("активной работы нет (взять — терминал биржи)", "GRMMob_M", 16, 110, MC.dim)
        end
        local y = 134
        for i, r in ipairs(rows) do
            if i > 13 then break end
            local sel = (i == M.sel)
            if sel then draw.RoundedBox(6, 10, y - 12, w - 20, 40, MC.sel) end
            txt(r.title .. "  [" .. r.kind .. "]", "GRMMob_X", 16, y, sel and MC.text or MC.dim)
            txt(r.fac .. " • " .. r.pay, "GRMMob_M", 16, y + 13, sel and MC.text or MC.dim)
            y = y + 42
        end
        if #rows == 0 then txt("публикаций нет", "GRMMob_X", w / 2, 220, MC.dim, TEXT_ALIGN_CENTER) end
    end
    screenKey.jobs = function(btn)
        local rows = (M.tabs.jobs or {}).rows or {}
        if btn == KEY_UP then M.sel = math.max(1, M.sel - 1)
        elseif btn == KEY_DOWN then M.sel = math.min(math.max(1, #rows), M.sel + 1)
        elseif btn == KEY_ENTER then sendAct({ op = "jobs_query" })
        elseif btn == KEY_BACKSPACE then M.screen = "home" M.sel = 1 screenEnter.home() end
    end

    -- ---------- ФРАКЦИЯ ----------
    screenDraw.fac = function(w, h)
        local d = (M.tabs.fac or {}).data
        if not d then
            txt("Вы не состоите во фракции", "GRMMob_S", w / 2, 200, MC.dim, TEXT_ALIGN_CENTER)
            txt("вступить — доска набора (Код 76)", "GRMMob_X", w / 2, 226, MC.dim, TEXT_ALIGN_CENTER)
            return
        end
        txt(d.name, "GRMMob_T", w / 2, 96, MC.text, TEXT_ALIGN_CENTER)
        txt("вы: " .. d.myRole .. " • " .. d.myDept .. "   |   онлайн " .. tostring(d.online) .. "/" .. tostring(d.total),
            "GRMMob_X", w / 2, 120, MC.dim, TEXT_ALIGN_CENTER)
        local y = 146
        for i, r in ipairs(d.rows or {}) do
            if i > 14 then break end
            local colr = r.online and MC.green or MC.dim
            txt((r.online and "● " or "○ ") .. r.name .. (r.leader and " ★" or ""), "GRMMob_X", 16, y, colr)
            txt(r.role .. " / " .. r.dept, "GRMMob_M", w - 14, y, colr, TEXT_ALIGN_RIGHT)
            y = y + 26
        end
    end
    screenKey.fac = function(btn)
        if btn == KEY_ENTER then sendAct({ op = "fac_query" })
        elseif btn == KEY_BACKSPACE then M.screen = "home" M.sel = 1 screenEnter.home() end
    end

    -- ---------- ФОРУМ ----------
    screenDraw.forum = function(w, h)
        local rows = (M.tabs.forum or {}).rows or {}
        txt("Городской форум: N — написать пост", "GRMMob_X", 16, 92, MC.dim)
        local y = 116
        for i, p in ipairs(rows) do
            if i > 6 then break end
            txt(p.author .. "  •  " .. os.date("%d.%m %H:%M", p.ts), "GRMMob_M", 16, y, MC.dim)
            -- простой перенос: режем по 46 символов
            local t = p.text
            local lines = {}
            while #t > 0 do
                lines[#lines + 1] = string.sub(t, 1, 46)
                t = string.sub(t, 47)
                if #lines >= 3 then break end
            end
            for _, ln in ipairs(lines) do
                y = y + 14
                txt(ln, "GRMMob_X", 20, y, MC.text)
            end
            y = y + 12
        end
        if #rows == 0 then txt("пусто — будь первым!", "GRMMob_X", w / 2, 220, MC.dim, TEXT_ALIGN_CENTER) end
    end
    screenKey.forum = function(btn)
        if btn == KEY_BACKSPACE then M.screen = "home" M.sel = 1 screenEnter.home()
        elseif btn == KEY_ENTER then sendAct({ op = "forum_query" })
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
        draw.RoundedBox(8, 40, 92, w - 80, 46, Color(20, 26, 36, 255))
        txt(calc.cur, "GRMMob_B", w / 2, 115, MC.text, TEXT_ALIGN_CENTER)
        for ri, row in ipairs(CALC_KEYS) do
            for ci, k in ipairs(row) do
                local bx = 46 + (ci - 1) * 62
                local by = 160 + (ri - 1) * 46
                local sel = (M.sel == (ri - 1) * 4 + ci)
                draw.RoundedBox(6, bx, by, 54, 38, sel and MC.sel or MC.panel)
                txt(k, "GRMMob_T", bx + 27, by + 19, sel and MC.text or MC.dim, TEXT_ALIGN_CENTER)
            end
        end
        txt("стрелки + ENTER или цифры клавиатуры", "GRMMob_M", w / 2, h - 32, MC.dim, TEXT_ALIGN_CENTER)
    end
    screenKey.calc = function(btn)
        if btn == KEY_UP then M.sel = M.sel - 4 if M.sel < 1 then M.sel = M.sel + 16 end
        elseif btn == KEY_DOWN then M.sel = M.sel + 4 if M.sel > 16 then M.sel = M.sel - 16 end
        elseif btn == KEY_LEFT then M.sel = M.sel - 1 if M.sel < 1 then M.sel = 16 end
        elseif btn == KEY_RIGHT then M.sel = M.sel + 1 if M.sel > 16 then M.sel = 1 end
        elseif btn == KEY_ENTER then
            local i = M.sel
            local k = CALC_KEYS[math.floor((i - 1) / 4) + 1][(i - 1) % 4 + 1]
            calcKey(k)
        elseif btn == KEY_BACKSPACE then M.screen = "home" M.sel = 1 screenEnter.home()
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

    -- ---------- отрисовка телефона ----------
    local function ensurePhone()
        if IsValid(phone) then return phone end
        phone = vgui.Create("DPanel")
        phone:SetSize(PW, PH)
        phone:SetPos(ScrW() - PW - 24, ScrH() - PH - 80)
        phone:SetVisible(false)
        phone.Paint = function(_, w, h)
            if not M.open then return end
            draw.RoundedBox(14, 0, 0, w, h, MC.bg)
            draw.RoundedBoxEx(14, 0, 0, w, 74, MC.head, true, true, false, false)
            -- статус-бар
            bars(16, 26)
            txt(M.st.operator or "—", "GRMMob_X", 56, 22, MC.dim)
            txt(os.date("%H:%M"), "GRMMob_X", w - 14, 22, MC.dim, TEXT_ALIGN_RIGHT)
            txt(M.st.modelName .. "  •  " .. tostring(M.st.number ~= "" and M.st.number or "нет номера"),
                "GRMMob_S", w / 2, 50, MC.text, TEXT_ALIGN_CENTER)
            local fn = screenDraw[M.screen] or screenDraw.home
            fn(w, h)
        end
        phone.OnMousePressed = function(_, mc)
            -- клики по кнопкам калькулятора
            if M.open and M.screen == "calc" then
                local mx, my = phone:CursorPos()
                for ri, row in ipairs(CALC_KEYS) do
                    for ci, k in ipairs(row) do
                        local bx = 46 + (ci - 1) * 62
                        local by = 160 + (ri - 1) * 46
                        if mx >= bx and mx <= bx + 54 and my >= by and my <= by + 38 then
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

    -- ---------- клавиши стрелок (ядро GTA-управления) ----------
    local noPhoneHintTs = 0
    hook.Add("PlayerButtonDown", "GRM_Mob_Keys", function(ply, btn)
        if ply ~= LocalPlayer() then return end
        -- не лезем, когда открыт чат/набор в других окнах
        if vgui.GetKeyboardFocus() ~= nil then return end
        if not M.st.has then
            -- подсказка новичку, куда девался телефон (троттл 15с)
            if btn == KEY_UP and CurTime() - noPhoneHintTs >= 15 then
                noPhoneHintTs = CurTime()
                notification.AddLegacy("Мобильного нет: купите трубку в /phoneshop (раздел «Мобильные»)", NOTIFY_HINT, 5)
            end
            return
        end
        if not M.open then
            if btn == KEY_UP and M.st.has == true then
                openPhone()
                phone = ensurePhone()
                phone:SetVisible(true)
                screenEnter.home()
            elseif btn == KEY_ENTER and M.st.lineState == "ringing" then
                sendAct({ op = "answer" })
                if not M.open then openPhone() phone = ensurePhone() phone:SetVisible(true) M.screen = "call" end
            elseif btn == KEY_BACKSPACE and M.st.lineState == "ringing" then
                sendAct({ op = "hangup" })
            end
            return
        end
        local fn = screenKey[M.screen] or screenKey.home
        fn(btn)
    end)

    -- запасной путь открытия (у кого стрелки заняты биндами): grm_mobile_open / say !mob
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
        -- отпустили вызов снаружи — показать карточку, если болтались внутри
        if M.open and M.st.has ~= true then closePhone() end
    end)

    -- мини-подсказка в HUD при входящем (даже когда телефон убран)
    hook.Add("HUDPaint", "GRM_Mob_Incoming", function()
        if M.open then return end
        if M.st.lineState ~= "ringing" then return end
        local w, h = 300, 74
        local x, y = ScrW() - w - 24, ScrH() - h - 160
        draw.RoundedBox(10, x, y, w, h, Color(12, 16, 24, 235))
        txt("ВХОДЯЩИЙ ВЫЗОВ", "GRMMob_S", x + w / 2, y + 18, MC.yellow, TEXT_ALIGN_CENTER)
        txt(tostring(M.st.otherNumber or "…"), "GRMMob_T", x + w / 2, y + 40, MC.text, TEXT_ALIGN_CENTER)
        txt("ENTER — ответить  •  BACKSPACE — отклонить", "GRMMob_M", x + w / 2, y + 60, MC.dim, TEXT_ALIGN_CENTER)
    end)

    print("[GRM Mobile] Клиент v" .. MB.Version .. " загружен (стрелка ВВЕРХ — достать телефон)")
end
