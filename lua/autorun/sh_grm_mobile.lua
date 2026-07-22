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
MB.Version = "1.2.2"

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
MB.ItemTier = MB.ItemTier or {}
for _, key in ipairs(TierOrder) do
    if MB.Tiers[key] and MB.Tiers[key].item then MB.ItemTier[MB.Tiers[key].item] = key end
end
-- Legacy aliases from earlier broken/short mobile snapshots: if such item is already
-- in a player's inventory, still treat it as a real phone instead of saying "buy one".
MB.ItemTier.mobile_touch = MB.ItemTier.mobile_touch or "badger_touch"
MB.ItemTier.mobile_smartphone = MB.ItemTier.mobile_smartphone or "tinkle"
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

function MB.IsMobileItem(itemID)
    return (MB.ItemTier or {})[tostring(itemID or "")] ~= nil
end

function MB.InventoryMobileStats(ply)
    local total, active, bestActive = 0, 0, nil
    if not (IsValid(ply) and GRM.Inventory and GRM.Inventory.GetPlayerInv) then return total, active, bestActive end
    local inv = GRM.Inventory.GetPlayerInv(ply)
    if not (istable(inv) and istable(inv.slots)) then return total, active, bestActive end
    local bestRank = 0
    for _, slot in pairs(inv.slots) do
        if istable(slot) then
            local key = (MB.ItemTier or {})[tostring(slot.id or "")]
            if key then
                total = total + (tonumber(slot.count) or 1)
                local data = istable(slot.data) and slot.data or nil
                if data and data.active == true then
                    active = active + 1
                    local r = tierRank(key)
                    if r > bestRank then bestActive, bestRank = key, r end
                end
            end
        end
    end
    return total, active, bestActive
end

local function tierRank(key)
    for i, k in ipairs(TierOrder) do if k == key then return i end end
    return 0
end

function MB.CarriedTier(ply)
    if not (IsValid(ply) and GRM.Inventory) then return nil end

    local best, bestRank = nil, 0
    local sawExplicitInactive = false
    local sawAnyMobile = false

    if GRM.Inventory.GetPlayerInv then
        local inv = GRM.Inventory.GetPlayerInv(ply)
        if istable(inv) and istable(inv.slots) then
            for _, slot in pairs(inv.slots) do
                if istable(slot) then
                    local itemID = tostring(slot.id or "")
                    local key = (MB.ItemTier or {})[itemID]
                    if key then
                        sawAnyMobile = true
                        local data = istable(slot.data) and slot.data or nil
                        if data and data.active == true then
                            local r = tierRank(key)
                            if r > bestRank then best, bestRank = key, r end
                        elseif data and data.active == false then
                            sawExplicitInactive = true
                        end
                    end
                end
            end
        end
    end

    if best then return best end

    -- Legacy compatibility: старые телефоны, купленные ДО флага active, не имеют
    -- slot.data.active вообще. Их считаем активными, но новые покупки из phoneshop
    -- кладутся с active=false и требуют «Использовать».
    if sawAnyMobile and not sawExplicitInactive and GRM.Inventory.GetPlayerInv then
        local inv = GRM.Inventory.GetPlayerInv(ply)
        for _, slot in pairs(inv.slots or {}) do
            local key = istable(slot) and (MB.ItemTier or {})[tostring(slot.id or "")] or nil
            if key then
                local r = tierRank(key)
                if r > bestRank then best, bestRank = key, r end
            end
        end
        if best then return best end
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
                    MB.PushAllData(ply)
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
    local line = tierKey and MB.EnsureLine(ply) or nil
    local other = IsValid(line) and line.GetOtherPhone and line:GetOtherPhone() or nil
    net.Start("GRM_Mob_State")
        net.WriteTable({
            tier = tierKey or "",
            number = data and data.number or "",
            signal = MB.SignalOf(ply),
            unread = MB.UnreadCount(ply),
            apps = MB.AvailableApps(tierKey or ""),
            has = tierKey ~= nil,
            active = tierKey ~= nil,
            lineState = IsValid(line) and line.GetLineState and line:GetLineState() or "idle",
            otherNumber = IsValid(other) and other.GetPhoneNumber and other:GetPhoneNumber() or "",
            otherName = IsValid(other) and other.GetDisplayName and other:GetDisplayName() or "",
        })
    net.Send(ply)
end

function MB.PushData(ply, kind)
    if not IsValid(ply) then return end
    kind = tostring(kind or "")
    local d = MB.EnsureData(ply)
    local payload = { rows = {} }

    if kind == "contacts" then
        for i, r in ipairs(d.contacts or {}) do
            payload.rows[#payload.rows + 1] = { i = i, name = r.name, num = r.num }
        end
    elseif kind == "sms" then
        for i, r in ipairs(d.sms or {}) do
            local row = table.Copy(r)
            row.i = i
            payload.rows[#payload.rows + 1] = row
        end
    elseif kind == "notes" then
        for i, r in ipairs(d.notes or {}) do
            payload.rows[#payload.rows + 1] = { i = i, text = r.text, ts = r.ts or r.time }
        end
    elseif kind == "forum" then
        for i = 1, math.min(40, #MB.Forum.posts) do payload.rows[i] = MB.Forum.posts[i] end
    else
        return
    end

    net.Start("GRM_Mob_Data")
        net.WriteString(kind)
        net.WriteTable(payload)
    net.Send(ply)
end

function MB.PushAllData(ply)
    MB.PushData(ply, "contacts")
    MB.PushData(ply, "sms")
    MB.PushData(ply, "notes")
    MB.PushData(ply, "forum")
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
        if op == "open" then MB.PushAllData(ply) end
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
    elseif op == "deactivate" then
        if GRM.Inventory and GRM.Inventory.GetPlayerInv then
            local inv = GRM.Inventory.GetPlayerInv(ply)
            if istable(inv) and istable(inv.slots) then
                for i, sl in pairs(inv.slots) do
                    if istable(sl) and sl.id and MB.IsMobileItem(sl.id) then
                        sl.data = istable(sl.data) and sl.data or {}
                        sl.data.active = false
                        if GRM.Inventory.SyncSlot then GRM.Inventory.SyncSlot(ply, i) end
                    end
                end
                if GRM.Inventory._devSaveSoon then GRM.Inventory._devSaveSoon("mobile deactivate") end
            end
        end
        MB.RemoveLine(ply)
        MB.PushState(ply)
        if MB.ServerNotify then MB.ServerNotify(ply, "Телефон деактивирован. Активировать — через /inv → Использовать.") end
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
        MB.PushData(ply, "notes")
        return
    elseif op == "note_del" then
        table.remove(d.notes, math.max(1, math.floor(tonumber(act.i) or 0)))
        MB.PushData(ply, "notes")
        return
    elseif op == "note_query" then
        MB.PushData(ply, "notes")
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
        MB.PushData(ply, "forum")
        return
    elseif op == "forum_query" then
        MB.PushData(ply, "forum")
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


function MB.ActivateInventoryPhone(ply, slotIdx, slot)
    if not IsValid(ply) then return false end
    if not (GRM.Inventory and GRM.Inventory.GetPlayerInv) then
        if MB.ServerNotify then MB.ServerNotify(ply, "Инвентарь ещё не загружен.") end
        return false
    end

    local inv = GRM.Inventory.GetPlayerInv(ply)
    if not (istable(inv) and istable(inv.slots)) then return false end
    slotIdx = tonumber(slotIdx) or 0
    local changed = false
    local activated = false

    for i, s in pairs(inv.slots) do
        if istable(s) and s.id and MB.IsMobileItem and MB.IsMobileItem(s.id) then
            s.data = istable(s.data) and s.data or {}
            local should = (i == slotIdx)
            if s.data.active ~= should then changed = true end
            s.data.active = should
            if should then activated = true end
            if GRM.Inventory.SyncSlot then GRM.Inventory.SyncSlot(ply, i) end
        end
    end

    -- Fallback if caller passed slot but index comparison failed for any reason.
    if not activated and istable(slot) and slot.id and MB.IsMobileItem and MB.IsMobileItem(slot.id) then
        slot.data = istable(slot.data) and slot.data or {}
        slot.data.active = true
        changed = true
        activated = true
        if slotIdx > 0 and GRM.Inventory.SyncSlot then GRM.Inventory.SyncSlot(ply, slotIdx) end
    end

    if changed then
        if GRM.Inventory._devSaveSoon then
            GRM.Inventory._devSaveSoon("mobile activate")
        elseif GRM.Inventory.SaveSoon then
            GRM.Inventory.SaveSoon("mobile activate")
        end
    end
    if MB.PushState then MB.PushState(ply) end
    if MB.ServerNotify then
        MB.ServerNotify(ply, activated and "Телефон активирован. Открыть — СТРЕЛКА ВВЕРХ, закрыть — СТРЕЛКА ВНИЗ." or "Телефон не найден в инвентаре.")
    end
    return activated
end

if SERVER then
    util.AddNetworkString("GRM_Mobile_Open")
    util.AddNetworkString("GRM_Mob_State")
    util.AddNetworkString("GRM_Mob_Data")
    util.AddNetworkString("GRM_Mob_Act")

    function MB.ServerNotify(ply, msg)
        if not IsValid(ply) then return end
        if GRM.Notify then
            GRM.Notify(ply, msg, 100, 220, 100)
        elseif ply.ChatPrint then
            ply:ChatPrint("[Телефон] " .. tostring(msg or ""))
        end
    end

    function MB.HasAnyPhone(ply)
        if not (IsValid(ply) and GRM.Inventory) then return false end
        local total = MB.InventoryMobileStats and select(1, MB.InventoryMobileStats(ply)) or 0
        if total > 0 then return true, total end
        if GRM.Inventory.CountItem then
            for itemID in pairs(MB.ItemTier or {}) do
                if (GRM.Inventory.CountItem(ply, itemID) or 0) > 0 then return true, 1 end
            end
        end
        return false, 0
    end

    function MB.HasPhone(ply)
        if not IsValid(ply) then return false end
        if not GRM.Inventory then
            -- Инвентарь ещё не поднят: не блокируем команду ложным отказом.
            return true, MB.Tiers.tinkle
        end
        local tierKey = MB.CarriedTier(ply)
        if tierKey then return true, MB.Tiers[tierKey], tierKey end
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
            local function activateHandler(ply, slotIdx, slot)
                MB.ActivateInventoryPhone(ply, slotIdx, slot)
            end
            -- mobile_open/mobile_use: ИСПОЛЬЗОВАТЬ = активировать трубку, НЕ открывать UI.
            GRM.Inventory.RegisterUseHandler("mobile_open", activateHandler)
            GRM.Inventory.RegisterUseHandler("mobile_use", activateHandler)
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
            MB.PushState(ply) -- sends has=false explicitly; client may show throttled hint
            if MB.HasAnyPhone and MB.HasAnyPhone(ply) then
                MB.ServerNotify(ply, "Телефон есть в инвентаре. Нажмите «Использовать», чтобы активировать его.")
            else
                MB.ServerNotify(ply, "У вас нет мобильного телефона. Купите его в /phoneshop.")
            end
            return
        end
        -- Critical: send fresh state BEFORE opening. Without this, the client can still
        -- have startup has=false and will locally say "buy a phone" even though the item
        -- is already in inventory.
        MB.PushState(ply)
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

    net.Receive("GRM_Mob_Act", function(_, ply)
        local act = net.ReadTable() or {}
        local op = tostring(act.op or "")
        if op == "dial" then MB.Dial(ply, act.number or act.num or "") return end
        if op == "answer" then MB.Answer(ply) return end
        if op == "hangup" then MB.Hangup(ply) return end
        MB.HandleAction(ply, act)
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
    surface.CreateFont("GRMMob_T", { font = "Roboto", size = 24, weight = 800, extended = true })
    surface.CreateFont("GRMMob_B", { font = "Roboto", size = 17, weight = 700, extended = true })
    surface.CreateFont("GRMMob_S", { font = "Roboto", size = 13, weight = 500, extended = true })
    surface.CreateFont("GRMMob_XS", { font = "Roboto", size = 11, weight = 400, extended = true })

    local C = {
        shell = Color(8, 10, 16, 252), bg = Color(18, 22, 32, 248), top = Color(30, 38, 54, 248),
        row = Color(38, 47, 65, 242), row2 = Color(48, 61, 84, 245), accent = Color(75, 155, 255),
        text = Color(240, 244, 250), dim = Color(165, 176, 192), green = Color(70, 205, 120), red = Color(225, 80, 75), yellow = Color(245, 195, 70),
        card = Color(26, 32, 46, 246), card2 = Color(34, 43, 62, 246), violet = Color(135, 110, 255)
    }

    local M = {
        open = false, frame = nil, stateKnown = false, state = { has = false, tier = "", number = "", lineState = "idle", unread = 0, signal = 0 },
        data = {}, screen = "home", sel = 1, listSel = 1, smsThread = nil, smsSel = 1,
        dial = "", calc = "", down = {}, lastTap = {}, hold = {}, nextRepeat = {}, noPhoneAt = -999,
        promptOpen = false, lastSelectAt = -999,
        poll = { up = false, down = false, mouse3 = false }
    }
    MB._devUI = M

    local function safe(obj, name, ...)
        if obj and obj[name] then return obj[name](obj, ...) end
    end
    local function lp() return LocalPlayer and LocalPlayer() or nil end
    local function hasPhone() return M.state and M.state.has ~= false and M.state.tier ~= nil and M.state.tier ~= "" end
    local function now() return CurTime and CurTime() or 0 end
    local function clamp(v, lo, hi)
        v = tonumber(v) or lo or 0
        if v < lo then return lo end
        if v > hi then return hi end
        return v
    end

    local function snd(kind)
        if not surface or not surface.PlaySound then return end
        local map = {
            open = "buttons/button14.wav",
            close = "buttons/button19.wav",
            nav = "buttons/lightswitch2.wav",
            select = "buttons/button15.wav",
            back = "buttons/button10.wav",
            err = "buttons/button8.wav",
            ring = "buttons/button17.wav"
        }
        surface.PlaySound(map[kind] or map.select)
    end

    local function notify(txt)
        if notification and notification.AddLegacy then notification.AddLegacy(tostring(txt or ""), NOTIFY_HINT or 3, 3) end
    end

    local function askString(title, text, default, cb)
        if M.promptOpen then return end
        M.promptOpen = true
        Derma_StringRequest(title, text, default or "", function(value)
            M.promptOpen = false
            if cb then cb(value) end
        end, function()
            M.promptOpen = false
        end)
    end

    local function sendAct(t)
        net.Start("GRM_Mob_Act")
        net.WriteTable(t or {})
        net.SendToServer()
    end

    local function appList()
        local tier = tostring(M.state.tier or "")
        local t = MB.Tiers[tier] or MB.Tiers.tinkle or {}
        local out = { { id="dial", name="Телефон" } }
        if t.sms then out[#out+1] = { id="sms", name="SMS" } end
        if t.contacts then out[#out+1] = { id="contacts", name="Контакты" } end
        if t.notes then out[#out+1] = { id="notes", name="Заметки" } end
        if t.apps then
            out[#out+1] = { id="jobs", name="Биржа" }
            out[#out+1] = { id="fac", name="Моя фракция" }
            out[#out+1] = { id="forum", name="Форум" }
        end
        out[#out+1] = { id="calc", name="Калькулятор" }
        return out
    end

    local function rows(kind)
        local d = M.data[kind] or {}
        return d.rows or {}
    end
    local function smsThreads()
        local map = {}
        for _, m in ipairs(rows("sms")) do
            local n = tostring(m.num or m.from or m.to or "")
            if n ~= "" then
                local r = map[n] or { num = n, last = "", ts = 0, unread = 0, rows = {} }
                r.rows[#r.rows+1] = m
                r.last = tostring(m.text or r.last or "")
                r.ts = tonumber(m.ts or m.time or r.ts or 0) or 0
                if m.dir == "in" and m.read == false then r.unread = r.unread + 1 end
                map[n] = r
            end
        end
        local out = {}
        for _, r in pairs(map) do table.sort(r.rows, function(a,b) return (tonumber(a.ts or a.time or 0) or 0) < (tonumber(b.ts or b.time or 0) or 0) end); out[#out+1]=r end
        table.sort(out, function(a,b) return (a.ts or 0) > (b.ts or 0) end)
        return out
    end

    local function calcEval(expr)
        expr = tostring(expr or "")
        local a, op, b = expr:match("^%s*(%-?%d+%.?%d*)%s*([%+%-%*/])%s*(%-?%d+%.?%d*)%s*$")
        a, b = tonumber(a), tonumber(b)
        if not a or not b or not op then return expr end
        if op == "+" then return tostring(a + b) end
        if op == "-" then return tostring(a - b) end
        if op == "*" then return tostring(a * b) end
        if op == "/" then return b ~= 0 and tostring(a / b) or "ERR" end
        return expr
    end

    local function goHome()
        M.screen = "home"
        M.sel = 1
        M.listSel = 1
        M.smsThread = nil
        M.contact = nil
    end

    local function setScreen(scr)
        M.screen = scr or "home"
        M.listSel = 1
    end

    local function screenItems()
        local items = {}
        local function add(label, fn, hint, kind) items[#items + 1] = { label = label, fn = fn, hint = hint, kind = kind } end

        local st = tostring(M.state.lineState or "idle")
        if st == "ringing" then
            add("Ответить", function() sendAct({op="answer"}) end, tostring(M.state.otherName or M.state.otherNumber or ""), "call_good")
            add("Сбросить", function() sendAct({op="hangup"}) end, "входящий вызов", "call_bad")
            add("Назад", function() goHome() end, nil, "back")
            return items
        elseif st == "dialing" or st == "call" then
            add("Сбросить вызов", function() sendAct({op="hangup"}) end, tostring(M.state.otherName or M.state.otherNumber or ""), "call_bad")
            add("Главное меню", function() goHome() end, nil, "back")
            return items
        end

        if M.screen == "home" then
            for _, a in ipairs(appList()) do
                add(a.name, function()
                    if a.id == "dial" then setScreen("dial")
                    elseif a.id == "sms" then setScreen("sms"); sendAct({op="sms_read"})
                    elseif a.id == "contacts" then setScreen("contacts")
                    elseif a.id == "notes" then setScreen("notes"); sendAct({op="note_query"})
                    elseif a.id == "jobs" then setScreen("jobs"); sendAct({op="jobs_query"})
                    elseif a.id == "fac" then setScreen("fac"); sendAct({op="fac_query"})
                    elseif a.id == "forum" then setScreen("forum"); sendAct({op="forum_query"})
                    elseif a.id == "calc" then setScreen("calc") end
                end, a.id == "sms" and tonumber(M.state.unread or 0) > 0 and ("Новых: " .. tostring(M.state.unread)) or nil)
            end
            add("Деактивировать", function() sendAct({op="deactivate"}); closePhone(false) end, "выключить рабочую трубку", "call_bad")
        elseif M.screen == "dial" then
            for _, d in ipairs({"1","2","3","4","5","6","7","8","9"}) do add(d, function() M.dial = (M.dial or "") .. d; snd("select") end, "цифра", "digit") end
            add("←", function() M.dial = string.sub(M.dial or "", 1, math.max(0, #(M.dial or "") - 1)); snd("back") end, "стереть", "digit")
            add("0", function() M.dial = (M.dial or "") .. "0"; snd("select") end, "цифра", "digit")
            add("☎", function() if (M.dial or "") ~= "" then snd("ring"); sendAct({op="dial", number=M.dial}) else snd("err") end end, "позвонить", "call_good")
            add("Очистить", function() M.dial = ""; snd("back") end, nil, "small")
            add("Назад", function() goHome(); snd("back") end, nil, "back")
        elseif M.screen == "sms" then
            for _, th in ipairs(smsThreads()) do add(th.num, function() M.smsThread = th.num; setScreen("sms_dialog") end, (th.unread > 0 and ("новых: " .. th.unread .. " • ") or "") .. tostring(th.last or "")) end
            add("Новое SMS", function()
                askString("SMS", "Номер", "", function(num)
                    askString("SMS", "Текст", "", function(txt) sendAct({op="sms", num=num, text=txt}) end)
                end)
            end)
            add("Назад", function() goHome(); snd("back") end, nil, "back")
        elseif M.screen == "sms_dialog" then
            add("Ответить", function()
                local num = M.smsThread or ""
                askString("SMS", "Текст для " .. num, "", function(txt) sendAct({op="sms", num=num, text=txt}) end)
            end, M.smsThread)
            add("Позвонить", function() if M.smsThread then sendAct({op="dial", number=M.smsThread}) end end)
            add("Назад к SMS", function() setScreen("sms"); snd("back") end, nil, "back")
            add("Главное меню", function() goHome(); snd("back") end, nil, "back")
        elseif M.screen == "contacts" then
            for _, r in ipairs(rows("contacts")) do add(tostring(r.name or r.num or "Контакт"), function() M.contact = r; setScreen("contact_actions") end, tostring(r.num or "")) end
            add("Добавить контакт", function()
                askString("Контакт", "Имя", "", function(name)
                    askString("Контакт", "Номер", "", function(num) sendAct({op="contact_add", name=name, num=num}) end)
                end)
            end)
            add("Назад", function() goHome(); snd("back") end, nil, "back")
        elseif M.screen == "contact_actions" then
            local r = M.contact or {}
            add("Позвонить", function() if r.num then sendAct({op="dial", number=r.num}) end end, tostring(r.num or ""))
            add("SMS", function() askString("SMS", "Текст для " .. tostring(r.num or ""), "", function(txt) sendAct({op="sms", num=r.num or "", text=txt}) end) end)
            add("Удалить", function() if r.i then sendAct({op="contact_del", i=r.i}) end; setScreen("contacts") end, nil, "call_bad")
            add("Назад", function() setScreen("contacts"); snd("back") end, nil, "back")
        elseif M.screen == "notes" then
            for _, r in ipairs(rows("notes")) do add(tostring(r.text or "Заметка"), function() end, "заметка") end
            add("Добавить заметку", function() askString("Заметка", "Текст", "", function(txt) sendAct({op="note_add", text=txt}) end) end)
            add("Удалить выбранную", function() sendAct({op="note_del", i=math.max(1, M.listSel)}) end, nil, "call_bad")
            add("Обновить", function() sendAct({op="note_query"}); snd("select") end, nil, "small")
            add("Назад", function() goHome(); snd("back") end, nil, "back")
        elseif M.screen == "jobs" then
            for _, r in ipairs(rows("jobs")) do add(tostring(r.fac or "") .. ": " .. tostring(r.title or ""), function() end, tostring(r.kind or "") .. " " .. tostring(r.pay or r.reward or "")) end
            add("Обновить", function() sendAct({op="jobs_query"}); snd("select") end, nil, "small")
            add("Назад", function() goHome(); snd("back") end, nil, "back")
        elseif M.screen == "fac" then
            local d = (M.data.fac or {}).data or {}
            for _, r in ipairs(d.rows or {}) do add((r.online and "● " or "○ ") .. tostring(r.name or "?"), function() end, tostring(r.role or "") .. " / " .. tostring(r.dept or "")) end
            add("Обновить", function() sendAct({op="fac_query"}); snd("select") end, nil, "small")
            add("Назад", function() goHome(); snd("back") end, nil, "back")
        elseif M.screen == "forum" then
            for _, r in ipairs(rows("forum")) do add(tostring(r.author or "?") .. ": " .. tostring(r.text or ""), function() end, "пост") end
            add("Новый пост", function() askString("Форум", "Текст поста", "", function(txt) sendAct({op="forum_post", text=txt}) end) end)
            add("Обновить", function() sendAct({op="forum_query"}); snd("select") end, nil, "small")
            add("Назад", function() goHome(); snd("back") end, nil, "back")
        elseif M.screen == "calc" then
            for _, b in ipairs({"7","8","9","+","4","5","6","-","1","2","3","*","0","/","C","="}) do
                add(b, function()
                    if b == "C" then M.calc = ""; snd("back")
                    elseif b == "=" then M.calc = calcEval(M.calc); snd("select")
                    else M.calc = (M.calc or "") .. b; snd("select") end
                end, nil, (b == "=" and "call_good") or (b == "C" and "call_bad") or "digit")
            end
            add("Назад", function() goHome(); snd("back") end, nil, "back")
        end
        return items
    end

    local function closePhone(send)
        if not M.open then return end
        M.open = false
        if send ~= false then sendAct({ op = "close" }) end
        snd("close")
        if IsValid(M.frame) then safe(M.frame, "SetVisible", false); safe(M.frame, "Remove") end
        M.frame = nil
    end

    local function drawEmpty(w, y, title, text)
        draw.RoundedBox(10, 18, y, w - 36, 86, C.card)
        draw.SimpleText(title, "GRMMob_B", w / 2, y + 30, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(text or "", "GRMMob_XS", w / 2, y + 56, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local function drawButtonList(w, startY, maxY)
        local items = screenItems()
        if #items == 0 then return end
        if M.screen == "home" then M.sel = clamp(M.sel, 1, #items) else M.listSel = clamp(M.listSel, 1, #items) end
        local selected = (M.screen == "home") and M.sel or M.listSel

        if (M.screen == "jobs" and #rows("jobs") == 0) then drawEmpty(w, startY, "Нет объявлений", "Нажмите «Обновить», чтобы проверить биржу"); startY = startY + 98 end
        if (M.screen == "forum" and #rows("forum") == 0) then drawEmpty(w, startY, "Форум пуст", "Создайте первый пост или обновите ленту"); startY = startY + 98 end
        if (M.screen == "contacts" and #rows("contacts") == 0) then drawEmpty(w, startY, "Контактов нет", "Добавьте первый контакт"); startY = startY + 98 end
        if (M.screen == "notes" and #rows("notes") == 0) then drawEmpty(w, startY, "Заметок нет", "Добавьте заметку"); startY = startY + 98 end

        if M.screen == "dial" or M.screen == "calc" then
            local cols = (M.screen == "calc") and 4 or 3
            local gap = 8
            local bw = math.floor((w - 36 - (cols - 1) * gap) / cols)
            local bh = 54
            for i, it in ipairs(items) do
                local col = (i - 1) % cols
                local row = math.floor((i - 1) / cols)
                local x = 18 + col * (bw + gap)
                local y = startY + row * (bh + gap)
                if y > maxY then break end
                local active = i == selected
                local color = active and C.accent or C.card2
                if it.kind == "call_good" then color = active and C.green or Color(38, 78, 55, 245) end
                if it.kind == "call_bad" then color = active and C.red or Color(82, 42, 48, 245) end
                if it.kind == "back" then color = active and C.yellow or Color(74, 62, 34, 245) end
                draw.RoundedBox(10, x, y, bw, bh, color)
                draw.SimpleText(tostring(it.label or ""), (it.kind == "digit" or M.screen == "calc") and "GRMMob_T" or "GRMMob_B", x + bw / 2, y + 24, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                if it.hint and tostring(it.hint) ~= "" then draw.SimpleText(tostring(it.hint), "GRMMob_XS", x + bw / 2, y + 43, active and Color(245,250,255) or C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
            end
            return
        end

        local y = startY
        for i, it in ipairs(items) do
            if y > maxY then break end
            local isAction = it.kind == "small" or it.kind == "back" or it.kind == "call_good" or it.kind == "call_bad"
            local h = isAction and 42 or ((M.screen == "forum" or M.screen == "jobs" or M.screen == "contacts" or M.screen == "notes") and 64 or 46)
            local active = i == selected
            local color = active and C.accent or (isAction and C.row or C.card)
            if it.kind == "call_good" then color = active and C.green or Color(38, 78, 55, 245) end
            if it.kind == "call_bad" then color = active and C.red or Color(82, 42, 48, 245) end
            if it.kind == "back" then color = active and C.yellow or Color(74, 62, 34, 245) end
            draw.RoundedBox(10, 18, y, w - 36, h, color)
            draw.SimpleText(tostring(it.label or ""), "GRMMob_B", 34, y + (it.hint and 20 or h/2), C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            if it.hint and tostring(it.hint) ~= "" then draw.SimpleText(tostring(it.hint), "GRMMob_XS", 34, y + h - 18, active and Color(230,240,255) or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
            y = y + h + 8
        end
    end

    local function openPhone(force)
        if not hasPhone() then
            if force then
                M.state.has = true
                if tostring(M.state.tier or "") == "" then M.state.tier = "tinkle" end
            else
                if now() - (M.noPhoneAt or -999) >= 15 then M.noPhoneAt = now(); notify("Купите мобильный телефон в /phoneshop") end
                return
            end
        end
        if not IsValid(M.frame) then
            local f = vgui.Create("DFrame")
            if not IsValid(f) then return end
            M.frame = f
            safe(f, "SetTitle", "")
            safe(f, "ShowCloseButton", false)
            safe(f, "SetDraggable", false)
            local fw, fh = math.min(520, ScrW() - 80), math.min(720, ScrH() - 80)
            safe(f, "SetSize", fw, fh)
            if f.SetPos then f:SetPos(ScrW() - fw - 34, ScrH() - fh - 34) end
            safe(f, "SetVisible", true)
            f.Paint = function(_, w, h)
                draw.RoundedBox(18, 0, 0, w, h, C.shell)
                draw.RoundedBox(14, 10, 10, w - 20, h - 20, C.bg)
                draw.RoundedBoxEx(14, 10, 10, w - 20, 58, C.top, true, true, false, false)
                draw.SimpleText("GRM Mobile", "GRMMob_T", 24, 39, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText("№ " .. tostring(M.state.number or ""), "GRMMob_S", w - 24, 32, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                draw.SimpleText("Колесо — выбор  •  СКМ — нажать  •  ↓ — закрыть", "GRMMob_XS", w - 24, 52, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

                local st = tostring(M.state.lineState or "idle")
                if st == "ringing" then
                    draw.RoundedBox(8, 18, 76, w - 36, 44, C.green)
                    draw.SimpleText("Входящий: " .. tostring(M.state.otherName or M.state.otherNumber or ""), "GRMMob_B", w/2, 98, Color(10,20,15), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end

                local title = ({ home="Главное меню", dial="Набор номера", sms="SMS", sms_dialog="Диалог " .. tostring(M.smsThread or ""), contacts="Контакты", contact_actions="Контакт", notes="Заметки", jobs="Биржа труда", fac="Моя фракция", forum="Форум", calc="Калькулятор" })[M.screen] or M.screen
                draw.SimpleText(title, "GRMMob_B", 24, 92, C.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                local topY = 118
                if M.screen == "dial" then
                    draw.RoundedBox(8, 18, 112, w - 36, 54, C.row2)
                    draw.SimpleText(M.dial == "" and "Введите номер" or M.dial, "GRMMob_T", w/2, 139, C.green, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    topY = 178
                elseif M.screen == "calc" then
                    draw.RoundedBox(8, 18, 112, w - 36, 54, C.row2)
                    draw.SimpleText(M.calc == "" and "0" or M.calc, "GRMMob_T", w/2, 139, C.green, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    topY = 178
                elseif M.screen == "sms_dialog" then
                    local y = 112
                    local rr = {}
                    for _, th in ipairs(smsThreads()) do if th.num == M.smsThread then rr = th.rows end end
                    for i = math.max(1, #rr - 4), #rr do
                        local m = rr[i]
                        if m then
                            local out = m.dir == "out"
                            draw.RoundedBox(8, out and w - 250 or 22, y, 228, 28, out and C.accent or C.row2)
                            draw.SimpleText(tostring(m.text or ""), "GRMMob_XS", out and w - 238 or 34, y + 14, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                            y = y + 32
                        end
                    end
                    topY = y + 8
                end
                drawButtonList(w, topY, h - 24)
            end
        end
        M.open = true
        safe(M.frame, "SetVisible", true)
        M.screen = "home"
        M.sel = 1
        M.listSel = 1
        sendAct({ op = "open" })
        snd("open")
    end

    local function move(delta)
        local items = screenItems()
        if #items == 0 then return end
        if M.screen == "home" then M.sel = ((M.sel - 1 + delta) % #items) + 1 else M.listSel = ((M.listSel - 1 + delta) % #items) + 1 end
        snd("nav")
    end
    local function enter()
        local st = tostring(M.state.lineState or "idle")
        if st == "ringing" then sendAct({op="answer"}); return end
        local items = screenItems()
        local idx = (M.screen == "home") and M.sel or M.listSel
        local it = items[idx]
        if it and it.fn then snd("select"); it.fn() end
    end
    local function back()
        local st=tostring(M.state.lineState or "idle")
        if st=="ringing" or st=="call" or st=="dialing" then sendAct({op="hangup"}); return end
        if M.screen == "home" then closePhone(true) else goHome() end
    end
    local function digit(_) return false end
    local function isMouse3(key)
        return (_G.KEY_MOUSE3 and key == KEY_MOUSE3)
            or (_G.MOUSE_MIDDLE and key == MOUSE_MIDDLE)
            or (_G.MOUSE_3 and key == MOUSE_3)
            or key == 107 -- common KEY_MOUSE3 fallback in GMod key enum
    end

    local function requestServerOpen()
        net.Start("GRM_Mobile_Open")
        net.SendToServer()
    end

    local function keyDown(key)
        -- Contract: UP opens, DOWN closes. No keyboard navigation/actions while open.
        if not M.open then
            if key == KEY_UP then
                if hasPhone() then
                    openPhone(false)
                elseif M.stateKnown then
                    openPhone(false)
                else
                    requestServerOpen()
                end
            end
            return
        end

        if key == KEY_DOWN then
            closePhone(true)
            return
        end
        if key == KEY_LEFT or key == KEY_RIGHT then
            goHome()
            snd("back")
            return
        end

        -- Selection/activation inside the phone is Mouse3 / middle mouse only.
        if isMouse3(key) then
            if now() - (tonumber(M.lastSelectAt) or -999) >= 0.25 then
                M.lastSelectAt = now()
                enter()
            end
            return
        end

        -- Everything else is intentionally ignored. Gameplay buttons are also cleared
        -- server-side by StartCommand and client-side by PlayerBindPress below.
    end

    local function keyUp(key)
        M.down[key]=nil; M.hold[key]=nil; M.nextRepeat[key]=nil
    end

    function MB.ClientIsOpen()
        return M.open == true
    end
    function MB.ClientWheel(delta)
        if M.open then move(tonumber(delta) or 1) return true end
        return false
    end
    local function selectCurrent()
        if now() - (tonumber(M.lastSelectAt) or -999) < 0.25 then return end
        M.lastSelectAt = now()
        enter()
    end

    function MB.ClientSelect()
        if M.open then selectCurrent() return true end
        return false
    end
    function MB.ClientClose()
        if M.open then closePhone(true) return true end
        return false
    end

    net.Receive("GRM_Mob_State", function()
        M.state = net.ReadTable() or {}; M.stateKnown = true; MB.ClientState=M.state
        if M.state.has == false then closePhone(false) end
    end)
    net.Receive("GRM_Mob_Data", function() local k=net.ReadString(); local p=net.ReadTable() or {}; M.data[tostring(k or "")]=p; MB.ClientData=M.data end)
    net.Receive("GRM_Mobile_Open", function() openPhone(true) end)

    hook.Add("PlayerButtonDown", "GRM_Mobile_KeyDown", function(ply, key) if ply ~= lp() then return end keyDown(key) end)
    hook.Add("PlayerButtonUp", "GRM_Mobile_KeyUp", function(ply, key) if ply ~= lp() then return end keyUp(key) end)
    hook.Add("Think", "GRM_Mobile_KeyRepeat", function()
        -- Keyboard repeat intentionally disabled: menu navigation is mouse wheel only.
        -- Live GMod note: DFrame/MakePopup may eat PlayerButtonDown for arrows.
        -- Poll physical keys here so UP opens and DOWN closes even with VGUI focus.
        if not input or not input.IsKeyDown then return end

        local upNow = input.IsKeyDown(KEY_UP) == true
        if upNow and not M.poll.up then
            if not M.open then
                if hasPhone() then openPhone(false)
                elseif M.stateKnown then openPhone(false)
                else requestServerOpen() end
            end
        end
        M.poll.up = upNow

        local downNow = input.IsKeyDown(KEY_DOWN) == true
        if downNow and not M.poll.down then
            if M.open then closePhone(true) end
        end
        M.poll.down = downNow

        local leftNow = input.IsKeyDown(KEY_LEFT) == true
        if leftNow and not M.poll.left and M.open then goHome(); snd("back") end
        M.poll.left = leftNow
        local rightNow = input.IsKeyDown(KEY_RIGHT) == true
        if rightNow and not M.poll.right and M.open then goHome(); snd("back") end
        M.poll.right = rightNow

        local mouse3Now = false
        if _G.KEY_MOUSE3 then mouse3Now = mouse3Now or input.IsKeyDown(KEY_MOUSE3) == true end
        if _G.MOUSE_MIDDLE then
            mouse3Now = mouse3Now or input.IsKeyDown(MOUSE_MIDDLE) == true
            if input.IsMouseDown then mouse3Now = mouse3Now or input.IsMouseDown(MOUSE_MIDDLE) == true end
        end
        if _G.MOUSE_3 then
            mouse3Now = mouse3Now or input.IsKeyDown(MOUSE_3) == true
            if input.IsMouseDown then mouse3Now = mouse3Now or input.IsMouseDown(MOUSE_3) == true end
        end
        mouse3Now = mouse3Now or input.IsKeyDown(107) == true
        if input.IsMouseDown then
            mouse3Now = mouse3Now or input.IsMouseDown(107) == true
        end
        if mouse3Now and not M.poll.mouse3 and M.open then
            if now() - (tonumber(M.lastSelectAt) or -999) >= 0.25 then
                M.lastSelectAt = now()
                enter()
            end
        end
        M.poll.mouse3 = mouse3Now
    end)
    hook.Add("HUDPaint", "GRM_Mobile_CallHUD", function() if M.open and tostring(M.state.lineState or "") == "ringing" then draw.SimpleText("Входящий вызов", "GRMMob_B", ScrW()/2, 120, C.green, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end end)
    hook.Add("PlayerBindPress", "GRM_Mobile_BlockSlots", function(_, bind, pressed)
        if not M.open then return false end
        bind = string.lower(tostring(bind or ""))

        if not pressed then
            return false
        end

        -- Mouse wheel is the only navigation channel while the phone is open.
        if bind == "invnext" then move(1); return true end
        if bind == "invprev" then move(-1); return true end

        -- Middle mouse confirms/selects. Different configs expose it as +attack3/mouse3.
        if bind == "+attack3" or bind == "attack3" or bind == "mouse3" or bind == "+mouse3" then
            enter()
            return true
        end

        -- Block weapon selector, weapon slots and all gameplay actions while phone UI is open.
        if bind:match("^slot%d") or bind == "lastinv" or bind == "phys_swap" then return true end
        if bind == "+attack" or bind == "+attack2" or bind == "+reload" or bind == "+use" then return true end
        if bind == "+jump" or bind == "+duck" or bind == "+speed" or bind == "+walk" then return true end
        if bind == "gmod_undo" or bind == "undo" or bind == "gm_showhelp" or bind == "gm_showteam" or bind == "gm_showspare1" or bind == "gm_showspare2" then return true end

        -- Conservative default: if the phone is open, do not let unknown press-binds leak
        -- into gameplay/addons. DOWN arrow or close button handles closing.
        return true
    end)
    timer.Create("GRM_Mob_Tick", 1, 0, function()
        if not M.open then return end
        local p=lp(); if p and p.Alive and not p:Alive() then closePhone(true); return end
        sendAct({op="ping"})
    end)
end
