--[[--------------------------------------------------------------------
    GRM Wanted — server core (Код 61)
    База розыска: уровни, статьи, история, net API.
----------------------------------------------------------------------]]

if CLIENT then return end

AddCSLuaFile("autorun/sh_grm_wanted_config.lua")
AddCSLuaFile("autorun/client/cl_grm_wanted.lua")
include("autorun/sh_grm_wanted_config.lua")

GRM = GRM or {}
GRM.Wanted = GRM.Wanted or {}
local W = GRM.Wanted
local CFG = function() return W.Config or {} end

local DATA_DIR  = "grm_wanted"
local DATA_FILE = DATA_DIR .. "/database.json"
local CAT_FILE  = DATA_DIR .. "/catalog.json"

local NET_OPEN   = "GRM_Wanted_Open"
local NET_DATA   = "GRM_Wanted_Data"
local NET_ACT    = "GRM_Wanted_Act"
local NET_SYNC   = "GRM_Wanted_Sync"   -- игроку его уровень
local NET_INFO   = "GRM_Wanted_Info"
local NET_LIST   = "GRM_Wanted_List"   -- краткий список для UI

util.AddNetworkString(NET_OPEN)
util.AddNetworkString(NET_DATA)
util.AddNetworkString(NET_ACT)
util.AddNetworkString(NET_SYNC)
util.AddNetworkString(NET_INFO)
util.AddNetworkString(NET_LIST)

-- records[sid64] = { level, name, reasons = { {id,title,type,text,by,byNick,t,level} }, updated }
W.Records = W.Records or {}
W.Catalog = W.Catalog or {}
W.History = W.History or {} -- global log array

local function jsonT(txt)
    local ok, t = pcall(util.JSONToTable, txt, false, true)
    return (ok and istable(t)) and t or nil
end

local function ensureDir()
    if not file.IsDir(DATA_DIR, "DATA") then file.CreateDir(DATA_DIR) end
end

local function notify(ply, msg, r, g, b)
    if not IsValid(ply) then return end
    if GRM.Notify then GRM.Notify(ply, msg, r or 100, g or 220, b or 100) return end
    net.Start(NET_INFO)
        net.WriteString(tostring(msg or ""))
        net.WriteUInt(math.Clamp(r or 100, 0, 255), 8)
        net.WriteUInt(math.Clamp(g or 220, 0, 255), 8)
        net.WriteUInt(math.Clamp(b or 100, 0, 255), 8)
    net.Send(ply)
end

local function steam64(ply)
    if IsValid(ply) and ply:IsPlayer() then
        if GRM.Identity and GRM.Identity.CharacterKey then return GRM.Identity.CharacterKey(ply) end
        return tostring(ply:SteamID64() or "") .. ":char1"
    end
    local raw = tostring(ply or "")
    if raw:match(":char[1-3]$") then return raw end
    if raw:match("^%d+$") then return raw .. ":char1" end
    if util.SteamIDTo64 then
        local s64 = util.SteamIDTo64(raw)
        if s64 and s64 ~= "0" then return tostring(s64) .. ":char1" end
    end
    return raw
end

local function pushLevel(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if CFG().SyncToClient == false then return end
    local rec = W.Records[steam64(ply)]
    local lvl = rec and W.ClampLevel(rec.level) or 0
    net.Start(NET_SYNC)
        net.WriteUInt(lvl, 4)
        net.WriteString(rec and tostring(rec.name or "") or "")
    net.Send(ply)
    ply:SetNW2Int("GRM_WantedLevel", lvl)
end

local function addHistory(text)
    W.History = istable(W.History) and W.History or {}
    W.History[#W.History + 1] = { t = os.time(), s = tostring(text) }
    local maxH = CFG().HistorySize or 200
    while #W.History > maxH do table.remove(W.History, 1) end
end

-- ── catalog ────────────────────────────────────────────────
local function catalogById()
    local map = {}
    for _, row in ipairs(W.Catalog or {}) do
        if istable(row) and isstring(row.id) then map[row.id] = row end
    end
    return map
end

function W.SaveCatalog()
    ensureDir()
    local ok, txt = pcall(util.TableToJSON, W.Catalog or {}, true)
    if ok and isstring(txt) then file.Write(CAT_FILE, txt) end
end

function W.LoadCatalog()
    ensureDir()
    if file.Exists(CAT_FILE, "DATA") then
        local t = jsonT(file.Read(CAT_FILE, "DATA") or "")
        if istable(t) and istable(t[1]) then
            W.Catalog = t
            return
        end
    end
    W.Catalog = table.Copy(W.DefaultCatalog or {})
    W.SaveCatalog()
end

-- ── database ───────────────────────────────────────────────
function W.Save()
    ensureDir()
    -- массив записей (не map sid→… — урок 65)
    local arr = {}
    for sid, rec in pairs(W.Records or {}) do
        if istable(rec) then
            arr[#arr + 1] = {
                sid = tostring(sid),
                name = tostring(rec.name or "?"),
                level = W.ClampLevel(rec.level),
                reasons = istable(rec.reasons) and rec.reasons or {},
                updated = tonumber(rec.updated) or os.time(),
            }
        end
    end
    table.sort(arr, function(a, b) return a.sid < b.sid end)
    local payload = { version = 1, records = arr, history = W.History or {} }
    local ok, txt = pcall(util.TableToJSON, payload, true)
    if not ok or not isstring(txt) then
        print("[GRM Wanted] SAVE fail serialize")
        return false
    end
    file.Write(DATA_FILE, txt)
    local chk = file.Read(DATA_FILE, "DATA")
    if chk ~= txt then
        print("[GRM Wanted] SAVE fail read-back")
        return false
    end
    print(("[GRM Wanted] SAVE ok: %d записей, %d байт"):format(#arr, #txt))
    return true
end

function W.Load()
    ensureDir()
    W.Records = {}
    W.History = {}
    if not file.Exists(DATA_FILE, "DATA") then return end
    local raw = file.Read(DATA_FILE, "DATA") or ""
    local t = jsonT(raw)
    if not istable(t) then
        local q = DATA_DIR .. "/database_corrupt_" .. os.time() .. ".txt"
        file.Write(q, raw)
        print("[GRM Wanted] LOAD quarantine data/" .. q)
        return
    end
    local list = istable(t.records) and t.records or (istable(t[1]) and t or {})
    for _, rec in ipairs(list) do
        if istable(rec) and isstring(rec.sid) and rec.sid ~= "" then
            local key = steam64(rec.sid)
            W.Records[key] = {
                name = tostring(rec.name or "?"),
                level = W.ClampLevel(rec.level),
                reasons = istable(rec.reasons) and rec.reasons or {},
                updated = tonumber(rec.updated) or os.time(),
            }
        end
    end
    W.History = istable(t.history) and t.history or {}
    print(("[GRM Wanted] LOAD: %d записей"):format(table.Count(W.Records)))
end

local function getOrCreate(sid, nick)
    sid = tostring(sid or "")
    if sid == "" or sid == "0" then return nil end
    local rec = W.Records[sid]
    if not rec then
        rec = { name = nick or "?", level = 0, reasons = {}, updated = os.time() }
        W.Records[sid] = rec
    end
    if nick and nick ~= "" then rec.name = nick end
    rec.level = W.ClampLevel(rec.level)
    rec.reasons = istable(rec.reasons) and rec.reasons or {}
    return rec
end

function W.GetLevel(ply)
    local sid = steam64(ply)
    if sid == "" then return 0 end
    local rec = W.Records[sid]
    return rec and W.ClampLevel(rec.level) or 0
end

function W.GetRecord(ply)
    local sid = steam64(ply)
    if sid == "" then return nil end
    return W.Records[sid]
end

function W.SetLevel(issuer, targetSid, level, reasonText)
    targetSid = tostring(targetSid or "")
    level = W.ClampLevel(level)
    if targetSid == "" then return false, "Нет цели" end
    if not W.CanEdit(issuer) then return false, "Нет прав" end

    local nick
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and steam64(p) == targetSid then nick = p:Nick() break end
    end
    local rec = getOrCreate(targetSid, nick)
    local old = rec.level
    rec.level = level
    rec.updated = os.time()
    if isstring(reasonText) and reasonText ~= "" then
        local maxR = CFG().MaxReasonsPerPlayer or 32
        rec.reasons[#rec.reasons + 1] = {
            id = "manual_level",
            title = "Смена уровня",
            type = "note",
            text = reasonText,
            by = steam64(issuer),
            byNick = IsValid(issuer) and issuer:Nick() or "system",
            t = os.time(),
            level = level,
        }
        while #rec.reasons > maxR do table.remove(rec.reasons, 1) end
    end
    if level == 0 then
        -- очистка при нуле? оставляем историю reasons, level=0
    end
    W.Save()
    addHistory(("%s: уровень %d → %d (%s)%s"):format(
        rec.name, old, level, targetSid,
        (isstring(reasonText) and reasonText ~= "") and (" | " .. reasonText) or ""))
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and steam64(p) == targetSid then pushLevel(p) break end
    end
    return true, rec.level
end

function W.AddCharge(issuer, targetSid, articleId, customText, forceLevel)
    targetSid = tostring(targetSid or "")
    if targetSid == "" then return false, "Нет цели" end
    if not W.CanEdit(issuer) then return false, "Нет прав" end

    local cat = catalogById()
    local art = cat[tostring(articleId or "")]
    local title = art and art.title or tostring(articleId or "Статья")
    local typ = art and art.type or "crime"
    local addLvl = W.ClampLevel(forceLevel or (art and art.defaultLevel) or 1)

    local nick
    local targetPly
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and steam64(p) == targetSid then
            nick = p:Nick()
            targetPly = p
            break
        end
    end
    local rec = getOrCreate(targetSid, nick)
    local maxR = CFG().MaxReasonsPerPlayer or 32
    rec.reasons[#rec.reasons + 1] = {
        id = tostring(articleId or "custom"),
        title = title,
        type = typ,
        text = tostring(customText or ""),
        by = steam64(issuer),
        byNick = IsValid(issuer) and issuer:Nick() or "system",
        t = os.time(),
        level = addLvl,
    }
    while #rec.reasons > maxR do table.remove(rec.reasons, 1) end

    -- уровень = max(текущий, уровень статьи), не суммируем бесконечно
    local newLevel = math.max(rec.level, addLvl)
    rec.level = W.ClampLevel(newLevel)
    rec.updated = os.time()
    W.Save()
    addHistory(("%s: +[%s] «%s» → ур.%d (%s)"):format(
        rec.name, typ, title, rec.level, IsValid(issuer) and issuer:Nick() or "?"))
    if IsValid(targetPly) then
        pushLevel(targetPly)
        notify(targetPly, "Вам выписана статья: " .. title .. " (розыск ур." .. rec.level .. ")", 230, 120, 60)
    end
    return true, rec.level
end

function W.Clear(issuer, targetSid, note)
    return W.SetLevel(issuer, targetSid, 0, note or "Снятие с розыска")
end

function W.RemoveReason(issuer, targetSid, index)
    if not W.CanEdit(issuer) then return false, "Нет прав" end
    targetSid = tostring(targetSid or "")
    local rec = W.Records[targetSid]
    if not rec or not istable(rec.reasons) then return false, "Нет записи" end
    index = math.floor(tonumber(index) or 0)
    if index < 1 or index > #rec.reasons then return false, "Нет статьи" end
    local removed = table.remove(rec.reasons, index)
    -- пересчёт уровня: max по оставшимся, либо 0
    local maxL = 0
    for _, r in ipairs(rec.reasons) do
        maxL = math.max(maxL, W.ClampLevel(r.level))
    end
    rec.level = maxL
    rec.updated = os.time()
    W.Save()
    addHistory(("%s: удалена статья «%s», ур.%d"):format(rec.name, tostring(removed and removed.title), rec.level))
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and steam64(p) == targetSid then pushLevel(p) break end
    end
    return true, rec.level
end

-- ── rights (overridden by access manager if present) ───────
function W.CanView(ply)
    if not IsValid(ply) then return false end
    if CFG().SuperAdminBypass ~= false and ply:IsSuperAdmin() then return true end
    if GRM.Wanted and GRM.Wanted.AccessManager and GRM.Wanted.AccessManager.CanView then
        return GRM.Wanted.AccessManager.CanView(ply)
    end
    return ply:IsSuperAdmin()
end

function W.CanEdit(ply)
    if not IsValid(ply) then return false end
    if CFG().SuperAdminBypass ~= false and ply:IsSuperAdmin() then return true end
    if GRM.Wanted and GRM.Wanted.AccessManager and GRM.Wanted.AccessManager.CanEdit then
        return GRM.Wanted.AccessManager.CanEdit(ply)
    end
    return ply:IsSuperAdmin()
end

-- ── payloads ───────────────────────────────────────────────
local function buildListPayload()
    local list = {}
    for sid, rec in pairs(W.Records or {}) do
        if istable(rec) and W.ClampLevel(rec.level) > 0 then
            list[#list + 1] = {
                sid = sid,
                name = rec.name,
                level = W.ClampLevel(rec.level),
                reasons = #((rec.reasons) or {}),
                updated = rec.updated,
            }
        end
    end
    table.sort(list, function(a, b)
        if a.level ~= b.level then return a.level > b.level end
        return tostring(a.name) < tostring(b.name)
    end)
    return list
end

local function buildFullRecord(sid)
    local rec = W.Records[tostring(sid or "")]
    if not rec then return nil end
    return {
        sid = tostring(sid),
        name = rec.name,
        level = W.ClampLevel(rec.level),
        reasons = rec.reasons or {},
        updated = rec.updated,
    }
end

local function onlinePlayers()
    local t = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            t[#t + 1] = {
                nick = p:Nick(),
                sid64 = steam64(p),
                level = W.GetLevel(p),
            }
        end
    end
    return t
end

function W.OpenMenu(ply)
    if not IsValid(ply) then return end
    if not W.CanView(ply) then
        notify(ply, "Нет доступа к базе розыска.", 255, 100, 100)
        return
    end
    net.Start(NET_DATA)
        net.WriteBool(W.CanEdit(ply))
        net.WriteTable(buildListPayload())
        net.WriteTable(W.Catalog or {})
        net.WriteTable(onlinePlayers())
        net.WriteTable(W.History or {})
        net.WriteTable(W.Levels or {})
        net.WriteUInt(CFG().MaxLevel or 5, 4)
    net.Send(ply)
end

net.Receive(NET_OPEN, function(_, ply)
    W.OpenMenu(ply)
end)

net.Receive(NET_ACT, function(_, ply)
    if not IsValid(ply) then return end
    local a = net.ReadTable() or {}
    local act = tostring(a.action or "")

    if act == "refresh" then
        W.OpenMenu(ply)
        return
    end

    if act == "get" then
        if not W.CanView(ply) then return end
        local sid = tostring(a.sid or "")
        local full = buildFullRecord(sid)
        net.Start(NET_LIST)
            net.WriteTable(full or {})
        net.Send(ply)
        return
    end

    if not W.CanEdit(ply) then
        notify(ply, "Нет прав изменять розыск.", 255, 100, 100)
        return
    end

    if act == "set_level" then
        local ok, err = W.SetLevel(ply, a.sid, a.level, a.text)
        if not ok then notify(ply, tostring(err), 255, 100, 100) return end
        notify(ply, "Уровень розыска: " .. tostring(err), 100, 220, 100)
        W.OpenMenu(ply)
    elseif act == "add_charge" then
        local ok, err = W.AddCharge(ply, a.sid, a.article, a.text, a.level)
        if not ok then notify(ply, tostring(err), 255, 100, 100) return end
        notify(ply, "Статья добавлена. Уровень: " .. tostring(err), 100, 220, 100)
        W.OpenMenu(ply)
    elseif act == "clear" then
        local ok, err = W.Clear(ply, a.sid, a.text)
        if not ok then notify(ply, tostring(err), 255, 100, 100) return end
        notify(ply, "Снят с розыска.", 100, 220, 100)
        W.OpenMenu(ply)
    elseif act == "remove_reason" then
        local ok, err = W.RemoveReason(ply, a.sid, a.index)
        if not ok then notify(ply, tostring(err), 255, 100, 100) return end
        notify(ply, "Статья удалена. Уровень: " .. tostring(err), 100, 220, 100)
        W.OpenMenu(ply)
    elseif act == "save_catalog" and ply:IsSuperAdmin() then
        if istable(a.catalog) then
            W.Catalog = a.catalog
            W.SaveCatalog()
            notify(ply, "Каталог статей сохранён.", 100, 220, 100)
            W.OpenMenu(ply)
        end
    end
end)

-- chat
hook.Add("PlayerSay", "GRM_Wanted_Chat", function(ply, text)
    local args = string.Explode(" ", string.Trim(text or ""))
    local cmd = string.lower(args[1] or "")
    if cmd == "/wanted" or cmd == "!wanted" or cmd == "/розыск" or cmd == "!розыск" then
        W.OpenMenu(ply)
        return ""
    end
    if cmd == "/wanted_set" or cmd == "!wanted_set" then
        if not W.CanEdit(ply) then return "" end
        -- !wanted_set <nick|sid> <level> [reason...]
        local who, lvl = args[2], tonumber(args[3])
        if not who or not lvl then
            notify(ply, "Использование: /wanted_set <ник|sid64> <0-5> [причина]", 255, 180, 80)
            return ""
        end
        local sid = who
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and (string.find(string.lower(p:Nick()), string.lower(who), 1, true)
                or p:SteamID64() == who or p:SteamID() == who) then
                sid = steam64(p)
                break
            end
        end
        local reason = table.concat(args, " ", 4)
        local ok, err = W.SetLevel(ply, sid, lvl, reason)
        notify(ply, ok and ("Уровень установлен: " .. tostring(err)) or tostring(err), ok and 100 or 255, ok and 220 or 100, 100)
        return ""
    end
    if cmd == "/wanted_clear" or cmd == "!wanted_clear" then
        if not W.CanEdit(ply) then return "" end
        local who = args[2]
        if not who then return "" end
        local sid = who
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and (string.find(string.lower(p:Nick()), string.lower(who), 1, true)
                or p:SteamID64() == who) then
                sid = steam64(p)
                break
            end
        end
        W.Clear(ply, sid, "clear cmd")
        notify(ply, "Снят с розыска.", 100, 220, 100)
        return ""
    end
end)

hook.Add("PlayerInitialSpawn", "GRM_Wanted_Join", function(ply)
    timer.Simple(2, function()
        if IsValid(ply) then
            local rec = W.Records[steam64(ply)]
            if rec then rec.name = ply:Nick() end
            pushLevel(ply)
        end
    end)
end)

concommand.Add("grm_wanted", function(ply)
    if IsValid(ply) then W.OpenMenu(ply) end
end)

concommand.Add("grm_wanted_save", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    W.Save()
end)

-- boot
W.LoadCatalog()
W.Load()
print("[GRM Wanted] server v1.0.0 — records=" .. table.Count(W.Records))
