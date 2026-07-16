-- Round-trip тест персистентности GRM currency/economy (мок GMod API + сценарии)
-- Запуск: собрать LuaJIT (github.com/LuaJIT/LuaJIT, ветка v2.1), из КОРНЯ репо:
--   rm -rf tools/luatest/data && ./luajit tools/luatest/roundtrip_test.lua save  (и далее load/corrupt/corrupt_all/treasury_corrupt)

-- GMod API mock + harness для round-trip теста GRM currency/economy
local PHASE = arg[1] or "save"
local DATA = "tools/luatest/data"

os.execute('mkdir -p "' .. DATA .. '"')

SERVER, CLIENT = true, false

-- ── утилиты ────────────────────────────────────────────────
function isstring(v) return type(v) == "string" end
function istable(v) return type(v) == "table" end
function isentity(v) return istable(v) and rawget(v, "__ent") == true end
function IsValid(v) return v ~= nil and (not istable(v) or rawget(v, "__valid") ~= false) and (istable(v) or type(v) == "userdata") end

math.Clamp = math.Clamp or function(v, a, b) if v < a then return a elseif v > b then return b else return v end end
string.Trim = string.Trim or function(s) return (tostring(s):gsub("^%s+", ""):gsub("%s+$", "")) end
string.StartWith = string.StartWith or function(s, p) return s:sub(1, #p) == p end
string.Left = string.Left or function(s, n) return s:sub(1, n) end
string.Explode = string.Explode or function(sep, s)
    local out, cur = {}, ""
    for i = 1, #s do
        local c = s:sub(i, i)
        if c == sep then out[#out + 1] = cur cur = "" else cur = cur .. c end
    end
    out[#out + 1] = cur
    return out
end
table.Count = table.Count or function(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
function AddCSLuaFile() end

-- ── JSON ───────────────────────────────────────────────────
local function jsonEncode(v, pretty, ind)
    ind = ind or ""
    local t = type(v)
    if t == "nil" then return "null"
    elseif t == "boolean" or t == "number" then return tostring(v)
    elseif t == "string" then
        return '"' .. v:gsub('[%z\1-\31\\"]', function(c)
            local m = {['"']='\\"', ['\\']='\\\\', ['\n']='\\n', ['\r']='\\r', ['\t']='\\t'}
            return m[c] or string.format("\\u%04x", c:byte())
        end) .. '"'
    elseif t == "table" then
        local n, isArr = 0, true
        for k in pairs(v) do n = n + 1 end
        if n > 0 then for i = 1, n do if rawget(v, i) == nil then isArr = false break end end
        else isArr = false end
        local nl = pretty and "\n" or ""
        local pad = pretty and (ind .. "\t") or ""
        local parts = {}
        if isArr and n > 0 then
            for i = 1, n do parts[#parts + 1] = pad .. jsonEncode(v[i], pretty, pad) end
            return "[" .. nl .. table.concat(parts, "," .. nl) .. nl .. ind .. "]"
        end
        for k, val in pairs(v) do
            parts[#parts + 1] = pad .. jsonEncode(tostring(k), false) .. (pretty and ": " or ":") .. jsonEncode(val, pretty, pad)
        end
        if #parts == 0 then return "{}" end
        return "{" .. nl .. table.concat(parts, "," .. nl) .. nl .. ind .. "}"
    end
    error("jsonEncode: unsupported " .. t)
end

local function jsonDecode(s)
    local pos = 1
    local function ws() while pos <= #s and s:sub(pos, pos):match("%s") do pos = pos + 1 end end
    local function parseVal()
        ws()
        local c = s:sub(pos, pos)
        if c == "{" then
            local t = {}
            pos = pos + 1 ws()
            if s:sub(pos, pos) == "}" then pos = pos + 1 return t end
            while true do
                ws()
                local k = parseVal()
                ws() assert(s:sub(pos, pos) == ":", "expected : at " .. pos) pos = pos + 1
                t[k] = parseVal()
                ws()
                c = s:sub(pos, pos)
                if c == "," then pos = pos + 1
                elseif c == "}" then pos = pos + 1 return t
                else error("expected , or } at " .. pos) end
            end
        elseif c == "[" then
            local t, i = {}, 1
            pos = pos + 1 ws()
            if s:sub(pos, pos) == "]" then pos = pos + 1 return t end
            while true do
                t[i] = parseVal() i = i + 1
                ws()
                c = s:sub(pos, pos)
                if c == "," then pos = pos + 1
                elseif c == "]" then pos = pos + 1 return t
                else error("expected , or ] at " .. pos) end
            end
        elseif c == '"' then
            pos = pos + 1
            local out = {}
            while pos <= #s do
                c = s:sub(pos, pos)
                if c == '"' then pos = pos + 1 return table.concat(out) end
                if c == "\\" then
                    local e = s:sub(pos + 1, pos + 1)
                    local m = { n = "\n", r = "\r", t = "\t", ['"'] = '"', ["\\"] = "\\", ["/"] = "/" }
                    if m[e] then out[#out + 1] = m[e] pos = pos + 2
                    elseif e == "u" then
                        out[#out + 1] = "?" pos = pos + 6
                    else out[#out + 1] = e pos = pos + 2 end
                else out[#out + 1] = c pos = pos + 1 end
            end
            error("unterminated string")
        elseif s:sub(pos, pos + 3) == "true" then pos = pos + 4 return true
        elseif s:sub(pos, pos + 4) == "false" then pos = pos + 5 return false
        elseif s:sub(pos, pos + 3) == "null" then pos = pos + 4 return nil
        else
            local num = s:match("^%-?%d+%.?%d*[eE]?[%+%-]?%d*", pos)
            if num and #num > 0 then pos = pos + #num return tonumber(num) end
            error("bad value at " .. pos .. ": " .. s:sub(pos, pos + 10))
        end
    end
    return parseVal()
end

util = {
    AddNetworkString = function() end,
    TableToJSON = function(t, pretty) return jsonEncode(t, pretty) end,
    JSONToTable = function(s) return jsonDecode(s) end,
}

-- ── file ───────────────────────────────────────────────────
file = {
    Write = function(name, content)
        local f = io.open(DATA .. "/" .. name, "wb")
        if not f then error("file.Write failed: " .. name) end
        f:write(content) f:close()
    end,
    Read = function(name)
        local f = io.open(DATA .. "/" .. name, "rb")
        if not f then return nil end
        local c = f:read("*a") f:close()
        return c
    end,
    Exists = function(name)
        local f = io.open(DATA .. "/" .. name, "rb");
        if f then f:close() return true end
        return false
    end,
    Append = function(name, content)
        local f = io.open(DATA .. "/" .. name, "ab")
        if f then f:write(content) f:close() end
    end,
}

-- ── net / hook / timer / concommand ────────────────────────
net = {
    Start = function() return true end,
    WriteUInt = function() end, WriteInt = function() end, WriteDouble = function() end,
    WriteString = function() end, WriteTable = function() end, WriteEntity = function() end,
    ReadUInt = function() return 0 end, ReadInt = function() return 0 end, ReadDouble = function() return 0 end,
    ReadString = function() return "" end, ReadTable = function() return {} end, ReadEntity = function() return nil end,
    Send = function() end, SendToServer = function() end, Broadcast = function() end,
    Receive = function() end,
}
local HOOKS = {}
hook = {
    Add = function(ev, id, fn) HOOKS[ev] = HOOKS[ev] or {} HOOKS[ev][id] = fn end,
    Remove = function(ev, id) if HOOKS[ev] then HOOKS[ev][id] = nil end end,
    GetTable = function() return HOOKS end,
    Run = function(ev, ...)
        local ret
        if HOOKS[ev] then for _, fn in pairs(HOOKS[ev]) do ret = fn(...) end end
        return ret
    end,
}
local TIMERS = {}
timer = {
    Create = function(name, delay, reps, fn) TIMERS[name] = { fn = fn } end,
    Simple = function(_, fn) TIMERS[#TIMERS + 1] = { fn = fn } end,
    Remove = function(name) TIMERS[name] = nil end,
}
concommand = { Add = function(name, fn) concommand[name] = fn end }
player = { GetAll = function() return _G.__PLAYERS or {} end }

-- ── фейковый игрок ─────────────────────────────────────────
local function mkPly(nick, sid64, sid)
    local p = {
        __ent = true, __valid = true,
        SteamID64 = function() return sid64 end,
        SteamID = function() return sid end,
        Nick = function() return nick end,
        IsPlayer = function() return true end,
        IsBot = function() return false end,
        IsSuperAdmin = function() return true end,
        SetNW2Int = function() end,
        GetPos = function() return { DistToSqr = function() return 0 end } end,
    }
    p.__mt = { __index = function(t, k) return rawget(t, k) end }
    return p
end

-- ================= ТЕСТ СЦЕНАРИЙ ===========================
local function fireHook(ev, ...)
    if HOOKS[ev] then for _, fn in pairs(HOOKS[ev]) do fn(...) end end
end

GRM = nil
Factions = {
    Polizei = {
        Members = { ["STEAM_0:1:100"] = { Role = "Officer" } },
        Leader = "STEAM_0:1:100", Roles = { "Officer" }, Departments = {},
    },
}

if PHASE == "save" then
    GRM = GRM or {}
    dofile("lua/autorun/sh_grm_currency.lua")
    dofile("lua/autorun/sh_grm_economy.lua")

    local ply = mkPly("Alexander Von Groenner", "76561199385153957", "STEAM_0:1:100")
    _G.__PLAYERS = { ply }
    fireHook("PlayerInitialSpawn", ply)

    print("  баланс на спавне: " .. GRM.GetBalance(ply))
    GRM.SetBalance(ply, 500200, "тест")
    assert(GRM.GetBalance(ply) == 500200, "SetBalance не применился")

    GRM.FactionBudgetAdd("Polizei", 250000, "тестовый взнос")
    assert(GRM.FactionBudgetGet("Polizei") == 250000, "бюджет фракции не применился")
    local ok = GRM.Economy.BankDeposit(ply, 200000)
    assert(ok, "BankDeposit не прошёл")
    assert(GRM.Economy.BankBalance(ply) == 200000, "банк != 200000")
    assert(GRM.GetBalance(ply) == 300200, "наличка после взноса != 300200, а " .. tonumber(GRM.GetBalance(ply)))

    fireHook("ShutDown") -- имитация выключения

    local w = file.Read("grm_wallet.json") or ""
    local tr = file.Read("grm_treasury.json") or ""
    assert(w:find("300200"), "wallet не содержит 300200: " .. w)
    assert(tr:find("Polizei") and tr:find("250000"), "treasury без фракции/бюджета")
    print("PHASE save: OK (wallet=" .. #w .. " байт, treasury=" .. #tr .. " байт)")
    print("  наличка игрока сейчас: " .. GRM.GetBalance(ply) .. ", банк: " .. GRM.Economy.BankBalance(ply) ..
          ", бюджет Polizei: " .. GRM.FactionBudgetGet("Polizei"))

elseif PHASE == "load" then
    dofile("lua/autorun/sh_grm_currency.lua")
    dofile("lua/autorun/sh_grm_economy.lua")

    local ply = mkPly("Alexander Von Groenner", "76561199385153957", "STEAM_0:1:100")
    _G.__PLAYERS = { ply }
    fireHook("PlayerInitialSpawn", ply)

    assert(GRM.GetBalance(ply) == 300200, "РЕСТАРТ: наличка != 300200, а " .. tostring(GRM.GetBalance(ply)))
    assert(GRM.Economy.BankBalance(ply) == 200000, "РЕСТАРТ: банк != 200000, а " .. tostring(GRM.Economy.BankBalance(ply)))
    assert(GRM.FactionBudgetGet("Polizei") == 250000, "РЕСТАРТ: бюджет != 250000")
    print("PHASE load: OK — всё пережило рестарт")

elseif PHASE == "corrupt" then
    -- ломаем wallet: обрез 90% (запись цела, обрублены лишь финальные скобки),
    -- зеркало целое: проверяем rescue И штатный фолбэк на зеркало
    local w = file.Read("grm_wallet.json") or ""
    file.Write("grm_wallet.json", w:sub(1, math.floor(#w * 0.9)))
    -- зеркало оставляем ЦЕЛЫМ: loader обязан поднять либо rescue, либо зеркало
    dofile("lua/autorun/sh_grm_currency.lua")
    local bal = GRM.GetBalance("76561199385153957")
    assert(bal == 300200, "СПАСЕНИЕ из битого файла не сработало: " .. tostring(bal))
    print("PHASE corrupt: OK — запись спасена из обрубленного файла")

elseif PHASE == "corrupt_all" then
    -- обрезаем и основной, и зеркало (90%): возможно только regex-спасение
    local w = file.Read("grm_wallet.json") or ""
    local cut = w:sub(1, math.floor(#w * 0.9))
    file.Write("grm_wallet.json", cut)
    file.Write("grm_wallet_backup.json", cut)
    dofile("lua/autorun/sh_grm_currency.lua")
    local bal = GRM.GetBalance("76561199385153957")
    assert(bal == 300200, "corrupt_all: баланс спасён неточно: " .. tostring(bal))
    print("PHASE corrupt_all: OK — из полностью битых копий спасено: " .. tostring(bal))

elseif PHASE == "treasury_corrupt" then
    local tr = file.Read("grm_treasury.json") or ""
    file.Write("grm_treasury.json", "{CORRUPT")
    file.Write("grm_treasury_backup.json", tr) -- зеркало живое
    dofile("lua/autorun/sh_grm_currency.lua")
    dofile("lua/autorun/sh_grm_economy.lua")
    assert(GRM.FactionBudgetGet("Polizei") == 250000, "treasury не поднялся из зеркала")
    assert(GRM.Economy.BankBalance("76561199385153957") == 200000, "банк пропал из зеркала")
    print("PHASE treasury_corrupt: OK — экономика поднялась из зеркала")

end
