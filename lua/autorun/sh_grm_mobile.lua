--[[--------------------------------------------------------------------
    GRM Mobile v2.0.1 — мобильные телефоны (стабилизационный слой)

    ВНИМАНИЕ: README/ANALYSIS описывают более крупный Mobile v1.2.2.
    В этой ветке лежала упрощённая v2.0.0. Этот файл не восстанавливает
    весь старый смартфон, но приводит текущий модуль в порядок:
    - item-id синхронизированы с /phoneshop (7 мобильных товаров Кода 88);
    - useFunc = mobile_open, как ждёт инвентарь v1.5.0;
    - RegisterUseHandler вызывается только когда API инвентаря реально поднят;
    - ретраи регистрации живут даже при перевёрнутом порядке загрузки;
    - СТРЕЛКА ВВЕРХ и /mobile открывают простое окно телефона;
    - повторное открытие не плодит DFrame-окна.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Mobile = GRM.Mobile or {}
local MB = GRM.Mobile

MB.DataFile = "grm_mobile.json"
MB.SmsCap = 40
MB.ContactsCap = 50
MB.NotesCap = 30
MB.Version = "2.0.1"

MB.Tiers = {
    crappy = {
        item = "mobile_crappy",
        name = "Badger Crappy",
        model = "models/ivancorn/gtaiv/electrical/phones/cellphone_badger_crappy.mdl",
        price = 700,
        desc = "Дешёвая трубка. Только звонки.",
        sms = false, contacts = false, notes = false, apps = false, minQ = 0.35,
    },
    badger = {
        item = "mobile_badger",
        name = "Badger Classic",
        model = "models/ivancorn/gtaiv/electrical/phones/cellphone_badger.mdl",
        price = 1800,
        desc = "Рабочая лошадка: звонки, SMS, контакты.",
        sms = true, contacts = true, notes = false, apps = false, minQ = 0.30,
    },
    badger_touch = {
        item = "mobile_badger_touch",
        name = "Badger Touch",
        model = "models/ivancorn/gtaiv/electrical/phones/phone_mobile_badger_touchscreen.mdl",
        price = 3500,
        desc = "Сенсорный Badger: SMS, контакты, заметки.",
        sms = true, contacts = true, notes = true, apps = false, minQ = 0.25,
    },
    lost = {
        item = "mobile_lost",
        name = "The Lost Flip",
        model = "models/ivancorn/gtaiv/electrical/phones/cellphone_thelostdamned.mdl",
        price = 4200,
        desc = "Байкерская раскладушка: SMS, контакты, заметки.",
        sms = true, contacts = true, notes = true, apps = false, minQ = 0.22,
    },
    tinkle = {
        item = "mobile_tinkle",
        name = "Panoramic Tinkle",
        model = "models/ivancorn/gtaiv/electrical/phones/cellphone_panoramic_tinkle.mdl",
        price = 6500,
        desc = "Смартфон: базовые приложения, биржа, фракция, форум.",
        sms = true, contacts = true, notes = true, apps = true, minQ = 0.18,
    },
    whiz_high = {
        item = "mobile_whiz_high",
        name = "Whiz Highspeed",
        model = "models/ivancorn/gtaiv/electrical/phones/cellphone_whiz_highspeed.mdl",
        price = 9000,
        desc = "Флагман Whiz: уверенный приём и все приложения.",
        sms = true, contacts = true, notes = true, apps = true, minQ = 0.14,
    },
    whiz_gold = {
        item = "mobile_whiz_gold",
        name = "Whiz Gold",
        model = "models/ivancorn/gtaiv/electrical/phones/cellphone_whiz_gold.mdl",
        price = 14000,
        desc = "Золотой Whiz: статус и лучший приёмник в городе.",
        sms = true, contacts = true, notes = true, apps = true, minQ = 0.10,
    },
}

MB.Order = { "crappy", "badger", "badger_touch", "lost", "tinkle", "whiz_high", "whiz_gold" }
local TierOrder = MB.Order
MB.TierOrder = TierOrder
MB.Lines = MB.Lines or {}
MB.Data = MB.Data or {}
MB.Forum = MB.Forum or { posts = {} }
MB.ForumCap = MB.ForumCap or 120

local AppBase = { "Телефон", "Калькулятор" }

function MB.AvailableApps(tierKey)
    local tier = MB.Tiers[tostring(tierKey or "")]
    local apps = { AppBase[1], AppBase[2] }
    if not tier then return apps end
    if tier.sms then apps[#apps + 1] = "SMS" end
    if tier.contacts then apps[#apps + 1] = "Контакты" end
    if tier.notes then apps[#apps + 1] = "Заметки" end
    if tier.apps then
        apps[#apps + 1] = "Биржа"
        apps[#apps + 1] = "Моя фракция"
        apps[#apps + 1] = "Форум"
    end
    return apps
end

function MB.GenerateNumber()
    return tostring(math.random(10000, 99999))
end

function MB.GetTierByItem(itemID)
    itemID = tostring(itemID or "")
    for _, key in ipairs(TierOrder) do
        local tier = MB.Tiers[key]
        if tier and tier.item == itemID then return tier, key end
    end
    return nil
end

function MB.CarriedTier(ply)
    if not (IsValid(ply) and GRM.Inventory and GRM.Inventory.CountItem) then return nil end
    for i = #TierOrder, 1, -1 do
        local key = TierOrder[i]
        local tier = MB.Tiers[key]
        if tier and (GRM.Inventory.CountItem(ply, tier.item) or 0) > 0 then
            return key
        end
    end
    return nil
end

function MB.SignalOf(ply)
    if not IsValid(ply) then return 0 end
    if not (GRM.RadioNet and GRM.RadioNet.QualityAt) then return 1 end
    local ok, q = pcall(GRM.RadioNet.QualityAt, ply:GetPos())
    if ok then return math.max(0, math.min(1, tonumber(q) or 0)) end
    return 0
end

function MB.SignalOK(ply, tierKey)
    local tier = MB.Tiers[tostring(tierKey or "")]
    if not tier then return false end
    return MB.SignalOf(ply) >= (tonumber(tier.minQ) or 0)
end

function MB.LineOnline(line)
    if not IsValid(line) then return false end
    local owner = line._grmOwner
    local tierKey = owner and MB.CarriedTier(owner) or line._grmTier
    if not tierKey then return false end
    return MB.SignalOK(owner, tierKey)
end

function MB.CanUseLine(ply, line)
    return IsValid(ply) and IsValid(line) and line._grmOwner == ply and MB.CarriedTier(ply) ~= nil
end

function MB.EnsureData(ply)
    if not IsValid(ply) then return nil end
    local sid = ply:SteamID64()
    MB.Data[sid] = MB.Data[sid] or { contacts = {}, sms = {}, notes = {}, number = MB.GenerateNumber() }
    local d = MB.Data[sid]
    d.contacts = istable(d.contacts) and d.contacts or {}
    d.sms = istable(d.sms) and d.sms or {}
    d.notes = istable(d.notes) and d.notes or {}
    d.number = tostring(d.number or "")
    if #d.number ~= 5 then d.number = MB.GenerateNumber() end
    return d
end

function MB.RemoveLine(plyOrSid)
    local sid = isstring(plyOrSid) and plyOrSid or (IsValid(plyOrSid) and plyOrSid:SteamID64() or nil)
    if not sid then return end
    local line = MB.Lines[sid]
    if IsValid(line) then line:Remove() end
    MB.Lines[sid] = nil
end

function MB.EnsureLine(ply)
    if not IsValid(ply) then return nil end
    local tierKey = MB.CarriedTier(ply)
    if not tierKey then
        MB.RemoveLine(ply)
        return nil
    end

    local sid = ply:SteamID64()
    local data = MB.EnsureData(ply)
    local line = MB.Lines[sid]

    if not IsValid(line) then
        line = ents.Create("grm_mobile_line")
        if not IsValid(line) then return nil end
        MB.Lines[sid] = line
        line._grmOwner = ply
        line._grmTier = tierKey
        line.IsMobile = true
        if line.SetOwnerSID64 then line:SetOwnerSID64(sid) end
        if line.SetPhoneNumber then line:SetPhoneNumber(data.number) end
        if line.SetDisplayName then line:SetDisplayName(ply:Nick()) end
        if line.SetExchangeID then line:SetExchangeID("cell") end
        if line.SetLineState then line:SetLineState("idle") end
        if line.SetCallID then line:SetCallID(0) end
        if line.SetPos then line:SetPos(ply:GetPos()) end
        if line.Spawn then line:Spawn() end
        if line.Activate then line:Activate() end
    end

    line._grmOwner = ply
    line._grmTier = tierKey
    if line.SetPos then line:SetPos(ply:GetPos()) end
    if line.GetExchangeID and line.SetExchangeID and line:GetExchangeID() == "" then line:SetExchangeID("cell") end
    if line.GetLineState and line.SetLineState and line:GetLineState() == "" then line:SetLineState("idle") end
    if line.GetPhoneNumber and line.SetPhoneNumber and line:GetPhoneNumber() == "" then line:SetPhoneNumber(data.number) end
    return line
end

function MB.Think()
    local list = player.GetAll and player.GetAll() or {}
    local seen = {}
    for _, ply in ipairs(list) do
        if IsValid(ply) then
            local sid = ply:SteamID64()
            seen[sid] = true
            local line = MB.EnsureLine(ply)
            if ply._grmMobUI and CurTime() - ply._grmMobUI > 3 then
                ply._grmMobUI = nil
            end
            if ply._grmMobUI then
                local lastPush = tonumber(ply._grmMobDataTs) or -999
                if CurTime() - lastPush >= 3 then
                    local d = MB.EnsureData(ply)
                    net.Start("GRM_Mob_Data")
                        net.WriteString("contacts")
                        net.WriteTable({ rows = d and d.contacts or {} })
                    net.Send(ply)
                    ply._grmMobDataTs = CurTime()
                end
            end
            if IsValid(line) and line.GetLineState and line:GetLineState() ~= "idle" and not MB.LineOnline(line) then
                local call = nil
                if GRM.Phone and GRM.Phone.Calls and line.GetCallID then
                    call = GRM.Phone.Calls[line:GetCallID()]
                end
                if GRM.Phone and GRM.Phone.ForceEndCall and call then
                    GRM.Phone.ForceEndCall(call, "mobile signal lost")
                elseif line.SetLineState then
                    line:SetLineState("idle")
                    if line.SetCallID then line:SetCallID(0) end
                end
                if MB.ServerNotify then MB.ServerNotify(ply, "Разговор завершён: потерян сигнал сотовой связи.") end
            end
        end
    end
    for sid, line in pairs(MB.Lines or {}) do
        if not seen[sid] then
            if IsValid(line) then line:Remove() end
            MB.Lines[sid] = nil
        end
    end
end

function MB.Dial(ply, number)
    if not (GRM.Phone and GRM.Phone.Dial) then
        if MB.ServerNotify then MB.ServerNotify(ply, "Телефонное ядро ещё не загружено.") end
        return false
    end
    local line = MB.EnsureLine(ply)
    if not IsValid(line) then
        if MB.ServerNotify then MB.ServerNotify(ply, "У вас нет активной мобильной линии.") end
        return false
    end
    GRM.Phone.Dial(ply, line, tostring(number or ""))
    return true
end

function MB.Answer(ply)
    if not (GRM.Phone and GRM.Phone.Answer) then return false end
    local line = MB.EnsureLine(ply)
    if not IsValid(line) then return false end
    GRM.Phone.Answer(ply, line)
    return true
end

function MB.Hangup(ply)
    if not (GRM.Phone and GRM.Phone.Hangup) then return false end
    local sid = IsValid(ply) and ply:SteamID64() or nil
    local line = sid and MB.Lines[sid] or nil
    if not IsValid(line) then return false end
    GRM.Phone.Hangup(ply, line)
    return true
end

function MB.FindLineByNumber(num)
    num = tostring(num or "")
    for _, line in pairs(MB.Lines or {}) do
        if IsValid(line) and line.GetPhoneNumber and line:GetPhoneNumber() == num then return line end
    end
    return nil
end

local function ownerOfLine(line)
    return IsValid(line) and line._grmOwner or nil
end

function MB.UnreadCount(ply)
    local d = MB.EnsureData(ply)
    local n = 0
    for _, msg in ipairs(d and d.sms or {}) do
        if msg.dir == "in" and msg.read ~= true then n = n + 1 end
    end
    return n
end

function MB.PushState(ply)
    if not IsValid(ply) then return end
    local tierKey = MB.CarriedTier(ply)
    local data = MB.EnsureData(ply)
    net.Start("GRM_Mob_State")
        net.WriteTable({
            tier = tierKey or "",
            number = data and data.number or "",
            signal = MB.SignalOf(ply),
            unread = MB.UnreadCount(ply),
            apps = MB.AvailableApps(tierKey or ""),
            has = tierKey ~= nil,
        })
    net.Send(ply)
end

function MB.SendSms(ply, num, text)
    if not IsValid(ply) then return false end
    local tierKey = MB.CarriedTier(ply)
    local tier = tierKey and MB.Tiers[tierKey] or nil
    if not (tier and tier.sms) then
        if MB.ServerNotify then MB.ServerNotify(ply, "Ваш телефон не умеет SMS.") end
        return false
    end
    local targetLine = MB.FindLineByNumber(num)
    local target = ownerOfLine(targetLine)
    if not IsValid(target) then
        if MB.ServerNotify then MB.ServerNotify(ply, "Номер не обслуживается.") end
        return false
    end
    local fromData = MB.EnsureData(ply)
    local toData = MB.EnsureData(target)
    text = tostring(text or ""):sub(1, 500)
    if text == "" then return false end
    local now = os.time()
    toData.sms[#toData.sms + 1] = { dir = "in", from = fromData.number, num = fromData.number, text = text, time = now, read = false }
    fromData.sms[#fromData.sms + 1] = { dir = "out", to = tostring(num or ""), num = tostring(num or ""), text = text, time = now, read = true }
    return true
end

local function sortContacts(d)
    table.sort(d.contacts, function(a, b) return tostring(a.name or "") < tostring(b.name or "") end)
end

function MB.HandleAction(ply, act)
    if not IsValid(ply) then return end
    act = istable(act) and act or {}
    local op = tostring(act.op or "")
    local tierKey = MB.CarriedTier(ply)
    local tier = tierKey and MB.Tiers[tierKey] or nil
    local d = MB.EnsureData(ply)

    if op == "open" or op == "ping" then
        ply._grmMobUI = CurTime()
        MB.PushState(ply)
        return
    elseif op == "close" then
        ply._grmMobUI = nil
        return
    elseif op == "sms_read" then
        for _, msg in ipairs(d.sms) do msg.read = true end
        return
    elseif op == "sms" then
        MB.SendSms(ply, act.num, act.text)
        return
    elseif op == "contact_add" then
        if not (tier and tier.contacts) then return end
        if #d.contacts >= MB.ContactsCap then return end
        local name = string.Trim(tostring(act.name or "")):sub(1, 48)
        local num = string.Trim(tostring(act.num or "")):sub(1, 16)
        if name ~= "" and num ~= "" then
            d.contacts[#d.contacts + 1] = { name = name, num = num }
            sortContacts(d)
        end
        return
    elseif op == "contact_del" then
        table.remove(d.contacts, math.max(1, math.floor(tonumber(act.i) or 0)))
        return
    elseif op == "note_add" then
        if not (tier and tier.notes) then return end
        if #d.notes >= MB.NotesCap then return end
        local text = string.Trim(tostring(act.text or "")):sub(1, 500)
        if text ~= "" then d.notes[#d.notes + 1] = { text = text, time = os.time() } end
        return
    elseif op == "note_del" then
        table.remove(d.notes, math.max(1, math.floor(tonumber(act.i) or 0)))
        return
    elseif op == "forum_post" then
        if not (tier and tier.apps) then return end
        local now = os.time()
        if ply._grmMobForumTs and now - ply._grmMobForumTs < 5 then return end
        local text = string.Trim(tostring(act.text or "")):sub(1, 500)
        if text == "" then return end
        ply._grmMobForumTs = now
        table.insert(MB.Forum.posts, 1, { author = ply:Nick(), text = text, time = now })
        while #MB.Forum.posts > MB.ForumCap do table.remove(MB.Forum.posts) end
        return
    elseif op == "forum_query" then
        local rows = {}
        for i = 1, math.min(40, #MB.Forum.posts) do rows[i] = MB.Forum.posts[i] end
        net.Start("GRM_Mob_Data")
            net.WriteString("forum")
            net.WriteTable({ rows = rows })
        net.Send(ply)
        return
    elseif op == "jobs_query" then
        local rows = {}
        local posts = GRM.Jobs and GRM.Jobs.Cfg and GRM.Jobs.Cfg.posts or {}
        for fac, list in pairs(posts) do
            if istable(list) then
                for _, job in ipairs(list) do
                    if istable(job) and not job.takenBy then
                        rows[#rows + 1] = {
                            fac = tostring(fac),
                            title = tostring(job.title or ""),
                            kind = tostring(job.kind or ""),
                            reward = tonumber(job.reward or job.salary or 0) or 0,
                            desc = tostring(job.desc or ""),
                        }
                    end
                end
            end
        end
        table.sort(rows, function(a, b)
            if a.fac == b.fac then return a.title < b.title end
            return a.fac < b.fac
        end)
        net.Start("GRM_Mob_Data")
            net.WriteString("jobs")
            net.WriteTable({ rows = rows })
        net.Send(ply)
        return
    elseif op == "fac_query" then
        local sid, sid64 = ply:SteamID(), ply:SteamID64()
        local foundName, found = nil, nil
        for name, fac in pairs(Factions or {}) do
            if istable(fac) and istable(fac.Members) and (fac.Members[sid] or fac.Members[sid64]) then
                foundName, found = tostring(name), fac
                break
            end
        end
        local payload = { data = nil }
        if found then
            local rows, online = {}, 0
            for msid, rec in pairs(found.Members or {}) do
                local oply = player.GetBySteamID64 and player.GetBySteamID64(tostring(msid)) or nil
                if not IsValid(oply) then
                    for _, pp in ipairs(player.GetAll and player.GetAll() or {}) do
                        if IsValid(pp) and (pp:SteamID64() == tostring(msid) or pp:SteamID() == tostring(msid)) then oply = pp break end
                    end
                end
                local isOn = IsValid(oply)
                if isOn then online = online + 1 end
                rows[#rows + 1] = {
                    sid = tostring(msid),
                    name = isOn and oply:Nick() or tostring(msid),
                    role = istable(rec) and tostring(rec.Role or "") or "",
                    dept = istable(rec) and tostring(rec.Department or "") or "",
                    online = isOn,
                    leader = tostring(found.Leader or "") == tostring(msid),
                }
            end
            table.sort(rows, function(a, b)
                if a.online ~= b.online then return a.online end
                if a.leader ~= b.leader then return a.leader end
                return a.name < b.name
            end)
            payload.data = { name = foundName, total = #rows, online = online, rows = rows }
        end
        net.Start("GRM_Mob_Data")
            net.WriteString("fac")
            net.WriteTable(payload)
        net.Send(ply)
        return
    end
end

if SERVER then
    util.AddNetworkString("GRM_Mobile_Open")
    util.AddNetworkString("GRM_Mob_State")
    util.AddNetworkString("GRM_Mob_Data")

    function MB.ServerNotify(ply, msg)
        if not IsValid(ply) then return end
        if GRM.Notify then
            GRM.Notify(ply, msg, 100, 220, 100)
        elseif ply.ChatPrint then
            ply:ChatPrint("[Телефон] " .. tostring(msg or ""))
        end
    end

    function MB.HasPhone(ply)
        if not IsValid(ply) then return false end
        if not (GRM.Inventory and GRM.Inventory.CountItem) then
            -- Инвентарь ещё не поднят: не блокируем команду ложным отказом.
            return true
        end
        for _, key in ipairs(TierOrder) do
            local tier = MB.Tiers[key]
            if tier and (GRM.Inventory.CountItem(ply, tier.item) or 0) > 0 then
                return true, tier
            end
        end
        return false
    end

    local function registerPhones()
        if not (GRM.Inventory and GRM.Inventory.RegisterItem) then return false end

        for _, key in ipairs(TierOrder) do
            local tier = MB.Tiers[key]
            GRM.Inventory.RegisterItem(tier.item, {
                type = "item",
                name = "Телефон: " .. tier.name,
                desc = tier.desc,
                icon = "icon16/phone.png",
                maxStack = 1,
                weight = 0.35,
                model = tier.model,
                useFunc = "mobile_open",
            })
        end

        if GRM.Inventory.RegisterUseHandler then
            local function openHandler(ply)
                MB.Open(ply)
            end
            -- mobile_open — актуальный контракт инвентаря; mobile_use — alias для старых сохранённых предметов.
            GRM.Inventory.RegisterUseHandler("mobile_open", openHandler)
            GRM.Inventory.RegisterUseHandler("mobile_use", openHandler)
        end

        return true
    end

    function MB.RegisterPhones()
        return registerPhones()
    end

    function MB.Open(ply)
        if not IsValid(ply) then return end
        local hasPhone = MB.HasPhone(ply)
        if not hasPhone then
            MB.ServerNotify(ply, "У вас нет мобильного телефона. Купите его в /phoneshop.")
            return
        end
        net.Start("GRM_Mobile_Open")
        net.Send(ply)
    end

    registerPhones()
    timer.Simple(1, registerPhones)
    timer.Simple(3, registerPhones)
    timer.Simple(6, registerPhones)
    timer.Create("GRM_Mob_Think", 1, 0, function()
        MB.Think()
    end)

    hook.Add("PlayerDisconnected", "GRM_Mobile_RemoveLine", function(ply)
        MB.RemoveLine(ply)
    end)

    hook.Add("StartCommand", "GRM_Mobile_FreezeOpenUI", function(ply, cmd)
        if not (IsValid(ply) and ply._grmMobUI and CurTime() - ply._grmMobUI <= 3) then return end
        if cmd.ClearMovement then cmd:ClearMovement() end
        if cmd.ClearButtons then cmd:ClearButtons() end
    end)

    net.Receive("GRM_Mobile_Open", function(_, ply)
        MB.Open(ply)
    end)

    hook.Add("PlayerSay", "GRM_Mobile_ChatCommand", function(ply, text)
        local cmd = string.lower(string.Trim(text or ""))
        if cmd == "/mobile" or cmd == "!mobile" or cmd == "/phone" or cmd == "/телефон" then
            MB.Open(ply)
            return ""
        end
    end)

    print("[GRM Mobile] v" .. MB.Version .. " loaded (stabilized)")
end

if CLIENT then
    surface.CreateFont("GRMMobile_Title", { font = "Roboto", size = 20, weight = 700, extended = true })
    surface.CreateFont("GRMMobile_Normal", { font = "Roboto", size = 14, weight = 500, extended = true })
    surface.CreateFont("GRMMobile_Small", { font = "Roboto", size = 12, weight = 400, extended = true })

    local CUI = {
        bg = Color(20, 20, 30, 250),
        panel = Color(40, 40, 50, 240),
        panel2 = Color(30, 36, 48, 245),
        accent = Color(70, 155, 255),
        text = Color(240, 240, 240),
        dim = Color(160, 170, 185),
    }

    local mobFrame = nil
    local nextOpenAt = 0

    local function requestOpen()
        local now = CurTime and CurTime() or 0
        if now < nextOpenAt then return end
        nextOpenAt = now + 0.35
        net.Start("GRM_Mobile_Open")
        net.SendToServer()
    end

    local function addAppButton(parent, name)
        local btn = vgui.Create("DButton", parent)
        btn:Dock(TOP)
        btn:SetTall(48)
        btn:DockMargin(0, 0, 0, 5)
        btn:SetText("")
        btn.Paint = function(self, w, h)
            local col = self:IsHovered() and Color(52, 64, 84, 245) or CUI.panel
            draw.RoundedBox(7, 0, 0, w, h, col)
            draw.SimpleText(name, "GRMMobile_Normal", 18, h / 2, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("›", "GRMMobile_Title", w - 20, h / 2, CUI.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btn.DoClick = function()
            if notification and notification.AddLegacy then
                notification.AddLegacy("Раздел «" .. name .. "» будет восстановлен в следующем проходе mobile.", NOTIFY_GENERIC, 3)
            end
        end
        return btn
    end

    local function openFrame()
        if IsValid(mobFrame) then
            mobFrame:MakePopup()
            mobFrame:MoveToFront()
            return
        end

        local frame = vgui.Create("DFrame")
        if not IsValid(frame) then return end
        mobFrame = frame

        frame:SetTitle("")
        frame:SetSize(420, 560)
        frame:Center()
        frame:MakePopup()
        frame:ShowCloseButton(true)
        frame:SetDeleteOnClose(true)
        frame.OnRemove = function()
            if mobFrame == frame then mobFrame = nil end
        end
        frame.Paint = function(self, w, h)
            draw.RoundedBox(18, 0, 0, w, h, Color(8, 10, 16, 252))
            draw.RoundedBox(14, 10, 10, w - 20, h - 20, CUI.bg)
            draw.RoundedBoxEx(14, 10, 10, w - 20, 54, CUI.panel2, true, true, false, false)
            draw.SimpleText("GRM Mobile", "GRMMobile_Title", 24, 37, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("v" .. tostring(MB.Version or "2.0.1"), "GRMMobile_Small", w - 48, 39, CUI.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        local scroll = vgui.Create("DScrollPanel", frame)
        scroll:Dock(FILL)
        scroll:DockMargin(22, 74, 22, 22)

        addAppButton(scroll, "Телефон")
        addAppButton(scroll, "SMS")
        addAppButton(scroll, "Контакты")
        addAppButton(scroll, "Заметки")
        addAppButton(scroll, "Биржа")
        addAppButton(scroll, "Моя фракция")
        addAppButton(scroll, "Форум")
    end

    net.Receive("GRM_Mob_State", function()
        MB.ClientState = net.ReadTable() or {}
        if MB.ClientState.has == false and IsValid(mobFrame) then
            mobFrame:Close()
            return
        end
        if IsValid(mobFrame) then
            -- Упрощённый UI пока не перерисовывает приложения по state, но данные не теряются.
            mobFrame._grmMobState = MB.ClientState
        end
    end)

    net.Receive("GRM_Mob_Data", function()
        local kind = net.ReadString()
        local payload = net.ReadTable() or {}
        MB.ClientData = MB.ClientData or {}
        MB.ClientData[tostring(kind or "")] = payload
    end)

    net.Receive("GRM_Mobile_Open", function()
        openFrame()
    end)

    hook.Add("PlayerButtonDown", "GRM_Mobile_OpenKey", function(ply, key)
        if ply ~= LocalPlayer() then return end
        if key == KEY_UP then
            requestOpen()
        end
    end)
end
