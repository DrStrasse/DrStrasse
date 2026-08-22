--[[--------------------------------------------------------------------
    GRM Identity Core v1.7.0 (Код 72) — Персонажи, RP-имена, регистрация
    v1.7.0: reentrancy/action guards; singleton signature survives rebuild.
    Ядро + точки расширения (патчи-провайдеры):

      - При КАЖДОМ входе игрок встречает меню персонажа:
        нет персонажа → создание (RP-имя + внешность с живым превью);
        есть персонаж → продолжить / изменить имя / изменить внешность.
      - RP-имя хранится на сервере (grm_characters.json) и рассылается
        клиентам (NWString GRM_RPName). Команда /name Имя Фамилия.
      - Внешность (модель/skin/bodygroups) валидируется против списков
        фракционной системы (DefaultModels → фракция/роль/отдел) и
        применяется через FactionsExt ApplyModelSettings — аппарат
        строгого удержания внешности (ModelCheck) конфликтов не даёт.
      - PROVIDER API (патчи): GRM.Char.RegisterProvider(id, def) —
        меню персонажа собирается из провайдеров; фракционный гардероб
        уже встроен как провайдер "faction". Любой будущий модуль
        (гардероб-энтити, работы, лицензии) добавляет свои секции без
        правок ядра.
      - Синхронизация со спавн-поинтами: при первичной регистрации члена
        фракции игрок переносится на фракционную точку (GetSpawnPointForPlayer).
    Данные: data/grm_characters.json  (ключи sid64 — чтение ТОЛЬКО jsonT c
    третьим аргументом, урок находки 65).
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Char = GRM.Char or {}
local CH = GRM.Char

CH.Version    = "1.7.0"
CH.NameMin    = 3     -- минимальная длина RP-имени (в символах, не байтах)
CH.NameMax    = 32
CH.NameWordsMin = 2   -- имя и фамилия
CH.NameWordsMax = 4   -- «Александр Фон Грённер» и запас на титул
CH.NamePartMin  = 2   -- минимальная длина слова/части через дефис
CH.NamePartMax  = 20
CH.DescMax      = 300  -- описание персонажа, символов
    CH.DataFile   = "grm_characters.json"
CH.MaxSlots    = 3
CH.PendingSelection = CH.PendingSelection or {}
CH.PendingMandatory = CH.PendingMandatory or {}

local NET_OPEN    = "GRM_Char_Open"
local NET_SAVE    = "GRM_Char_Save"
local NET_REQUEST = "GRM_Char_Request"
local NET_CLOSE   = "GRM_Char_Close"
local NET_CANCEL   = "GRM_Char_Cancel"

-- ------------------------------------------------------------
-- SHARED: валидация имени и нормализация внешности
--
-- РП-имя — это не ник в стиме: в нём не должно быть эмодзи, цифр,
-- скобок, «крутых» символов и одинаковых имён у двух персонажей.
-- Правила (одинаковые на клиенте и сервере, чтобы окно персонажа
-- подсказывало ровно то, что примет сервер):
--   • только буквы (кириллица и латиница), пробел, дефис и апостроф;
--   • от CH.NameMin до CH.NameMax СИМВОЛОВ (utf-8, а не байтов);
--   • от 2 до 4 слов, каждое слово (и часть через дефис) 2…20 букв;
--   • без двойных разделителей и без «Ааааа» (4+ одинаковых подряд);
--   • первая буква каждой части поднимается в верхний регистр.
-- Уникальность имени проверяется на сервере (CH.FindNameOwner).
-- ------------------------------------------------------------

--- Разбить строку на utf-8 символы (в Lua 5.1 нет utf8-библиотеки).
function CH.Chars(s)
    local out, i, n = {}, 1, #tostring(s or "")
    s = tostring(s or "")
    while i <= n do
        local b = string.byte(s, i) or 0
        local len = 1
        if b >= 0xF0 then len = 4
        elseif b >= 0xE0 then len = 3
        elseif b >= 0xC0 then len = 2 end
        out[#out + 1] = string.sub(s, i, i + len - 1)
        i = i + len
    end
    return out
end

function CH.Len(s) return #CH.Chars(s) end

--- Буква ли это (латиница или кириллица, включая Ё/ё).
function CH.IsLetter(ch)
    ch = tostring(ch or "")
    if #ch == 1 then
        local b = string.byte(ch)
        return (b >= 65 and b <= 90) or (b >= 97 and b <= 122)
    elseif #ch == 2 then
        local b1, b2 = string.byte(ch, 1), string.byte(ch, 2)
        if b1 == 0xD0 then return (b2 >= 0x90 and b2 <= 0xBF) or b2 == 0x81 end
        if b1 == 0xD1 then return (b2 >= 0x80 and b2 <= 0x8F) or b2 == 0x91 end
    end
    return false
end

--- Верхний/нижний регистр одного символа (кириллица + латиница).
function CH.UpperChar(ch)
    ch = tostring(ch or "")
    if #ch == 1 then return string.upper(ch) end
    if #ch ~= 2 then return ch end
    local b1, b2 = string.byte(ch, 1), string.byte(ch, 2)
    if b1 == 0xD0 and b2 >= 0xB0 and b2 <= 0xBF then return string.char(0xD0, b2 - 0x20) end
    if b1 == 0xD1 and b2 >= 0x80 and b2 <= 0x8F then return string.char(0xD0, b2 + 0x20) end
    if b1 == 0xD1 and b2 == 0x91 then return string.char(0xD0, 0x81) end
    return ch
end

function CH.LowerChar(ch)
    ch = tostring(ch or "")
    if #ch == 1 then return string.lower(ch) end
    if #ch ~= 2 then return ch end
    local b1, b2 = string.byte(ch, 1), string.byte(ch, 2)
    if b1 == 0xD0 and b2 >= 0x90 and b2 <= 0x9F then return string.char(0xD0, b2 + 0x20) end
    if b1 == 0xD0 and b2 >= 0xA0 and b2 <= 0xAF then return string.char(0xD1, b2 - 0x20) end
    if b1 == 0xD0 and b2 == 0x81 then return string.char(0xD1, 0x91) end
    return ch
end

function CH.Lower(s)
    local out = {}
    for i, ch in ipairs(CH.Chars(s)) do out[i] = CH.LowerChar(ch) end
    return table.concat(out)
end

--- Ключ имени для сравнения: регистр, Ё/ё и дефисы значения не имеют,
--  чтобы «Мария Готтен-Фон-Штоцкая» и «мария готтен фон штоцкая» считались
--  одним и тем же именем.
function CH.NameKey(s)
    local out = {}
    for _, ch in ipairs(CH.Chars(s)) do
        local c = CH.LowerChar(ch)
        if c == "ё" or c == string.char(0xD1, 0x91) then c = string.char(0xD0, 0xB5) end
        if c == "-" or c == "'" or c == " " then c = " " end
        out[#out + 1] = c
    end
    local key = table.concat(out)
    key = string.gsub(key, "%s+", " ")
    return (string.gsub(key, "^%s*(.-)%s*$", "%1"))
end

--- Описание персонажа: чистим управляющие символы и режем по длине.
--  Пустая строка — законный ответ (описание убрали).
function CH.CleanDesc(raw)
    local s = string.Trim(tostring(raw or ""))
    s = string.gsub(s, "[%z\1-\8\11\12\14-\31]", "")
    s = string.gsub(s, "\r\n", "\n")
    local chars = CH.Chars(s)
    if #chars > CH.DescMax then
        local cut = {}
        for i = 1, CH.DescMax do cut[i] = chars[i] end
        s = table.concat(cut)
    end
    return s
end

--- Проверка и приведение РП-имени. Возвращает имя либо nil + причину.
function CH.ValidateName(raw)
    local s = string.Trim(tostring(raw or ""))
    s = string.gsub(s, "%s+", " ")
    local chars = CH.Chars(s)

    if #chars < CH.NameMin then
        return nil, "Имя короче " .. CH.NameMin .. " символов"
    end
    if #chars > CH.NameMax then
        return nil, "Имя длиннее " .. CH.NameMax .. " символов"
    end

    local sep = { [" "] = true, ["-"] = true, ["'"] = true }
    local prevSep, same, prevLower = false, 1, nil
    for i, ch in ipairs(chars) do
        if not (CH.IsLetter(ch) or sep[ch]) then
            return nil, "В имени разрешены только буквы, пробел, дефис и апостроф (без цифр, эмодзи и символов)"
        end
        if sep[ch] then
            if i == 1 or i == #chars then return nil, "Имя не может начинаться или заканчиваться разделителем" end
            if prevSep then return nil, "Два разделителя подряд" end
            prevSep, same, prevLower = true, 1, nil
        else
            prevSep = false
            local low = CH.LowerChar(ch)
            if low == prevLower then
                same = same + 1
                if same >= 4 then return nil, "Слишком много одинаковых букв подряд" end
            else
                same, prevLower = 1, low
            end
        end
    end

    -- слова и части через дефис
    local words, cur = {}, {}
    for _, ch in ipairs(chars) do
        if ch == " " then
            if #cur > 0 then words[#words + 1] = table.concat(cur) cur = {} end
        else
            cur[#cur + 1] = ch
        end
    end
    if #cur > 0 then words[#words + 1] = table.concat(cur) end

    if #words < CH.NameWordsMin then
        return nil, "Укажите имя и фамилию (минимум два слова)"
    end
    if #words > CH.NameWordsMax then
        return nil, "Слишком много слов в имени (максимум " .. CH.NameWordsMax .. ")"
    end

    local rebuilt = {}
    for wi, word in ipairs(words) do
        -- слово делится дефисами на части; апостроф живёт ВНУТРИ части
        -- («О'Брайен» — одна часть, «Готтен-Фон-Штоцкая» — три).
        local parts, buf = {}, {}
        for _, ch in ipairs(CH.Chars(word)) do
            if ch == "-" then
                parts[#parts + 1] = table.concat(buf)
                buf = {}
            else
                buf[#buf + 1] = ch
            end
        end
        parts[#parts + 1] = table.concat(buf)
        if #parts > 3 then return nil, "Слишком много частей в слове «" .. word .. "»" end

        local outParts = {}
        for pi, part in ipairs(parts) do
            local pc = CH.Chars(part)
            if pc[1] == "'" or pc[#pc] == "'" then
                return nil, "Апостроф должен стоять внутри слова"
            end
            local letters = 0
            for _, ch in ipairs(pc) do if CH.IsLetter(ch) then letters = letters + 1 end end
            if letters < CH.NamePartMin then
                return nil, "Каждая часть имени — минимум " .. CH.NamePartMin .. " буквы"
            end
            if #pc > CH.NamePartMax then
                return nil, "Слишком длинная часть имени (максимум " .. CH.NamePartMax .. ")"
            end
            pc[1] = CH.UpperChar(pc[1])
            for i = 2, #pc do
                if pc[i - 1] == "'" then pc[i] = CH.UpperChar(pc[i]) end
            end
            outParts[pi] = table.concat(pc)
        end
        rebuilt[wi] = table.concat(outParts, "-")
    end

    return table.concat(rebuilt, " ")
end

function CH.GetName(plyOrSid64)
    if IsValid(plyOrSid64) and plyOrSid64:IsPlayer() then
        return plyOrSid64:GetNWString("GRM_RPName", "")
    end
    return ""
end

function CH.GetActiveID(ply)
    if IsValid(ply) and ply:IsPlayer() then return ply:GetNWString("GRM_CharacterID", "") end
    return ""
end

function CH.GetActiveKey(ply)
    if GRM.Identity and GRM.Identity.CharacterKey then
        return GRM.Identity.CharacterKey(ply)
    end
    if IsValid(ply) and ply:IsPlayer() then
        local key = ply:GetNWString("GRM_CharacterKey", "")
        if key ~= "" then return key end
        return ply:SteamID64()
    end
    return tostring(ply or "")
end

function CH.MakeCharacterID(ply)
    local sid = IsValid(ply) and ply:SteamID64() or "0"
    return sid .. ":char1"
end

-- ------------------------------------------------------------
-- Провайдер-патчи (shared-регистрация, исполнение на сервере)
-- def = { Order=100, Title=function(ply).., Outfits=function(ply) -> {entry,...} }
-- entry = { path=..., skin=0, bodygroups={} }
-- ------------------------------------------------------------
CH.Providers = CH.Providers or {}
function CH.RegisterProvider(id, def)
    if not isstring(id) or not istable(def) then return end
    if not isfunction(def.Outfits) then return end
    CH.Providers[id] = def
    table.sort(CH.ProvidersSort or {}, function() end) -- no-op guard
end

-- ============================================================
-- СЕРВЕР
-- ============================================================
if SERVER then
    util.AddNetworkString(NET_OPEN)
    util.AddNetworkString(NET_SAVE)
    util.AddNetworkString(NET_REQUEST)
    util.AddNetworkString(NET_CLOSE)
    util.AddNetworkString(NET_CANCEL)

    local function jsonT(txt)
        local ok, t = pcall(util.JSONToTable, txt, false, true)
        return (ok and istable(t)) and t or nil
    end

    local function loadChars()
        CH.Data = CH.Data or {}
        if not file.Exists(CH.DataFile, "DATA") then return CH.Data end
        local t = jsonT(file.Read(CH.DataFile, "DATA") or "")
        if istable(t) then CH.Data = t end
        return CH.Data
    end

    local function saveChars(reason)
        local ok, txt = pcall(util.TableToJSON, CH.Data or {}, true)
        if ok and txt then
            file.Write(CH.DataFile, txt)
            local back = readbackCheck()
            if not back then
                ErrorNoHalt("[GRM Char] SAVE FAIL (" .. tostring(reason) .. ")\n")
            end
        end
    end
    function readbackCheck()
        local t = file.Read(CH.DataFile, "DATA")
        return t ~= nil and #t > 2
    end

    loadChars()

    local function sid64(ply) return IsValid(ply) and ply:SteamID64() or "" end
    local function clampSlot(n)
        n = math.floor(tonumber(n) or 1)
        if n < 1 then return 1 end
        if n > (CH.MaxSlots or 3) then return CH.MaxSlots or 3 end
        return n
    end
    local function slotID(n) return "char" .. tostring(clampSlot(n)) end

    local function normalizePlayerData(ply)
        if not IsValid(ply) then return nil end
        local sid = sid64(ply)
        CH.Data[sid] = istable(CH.Data[sid]) and CH.Data[sid] or {}
        local rec = CH.Data[sid]

        -- Legacy migration: old format stored one character directly at CH.Data[sid].
        if not istable(rec.slots) then
            local old = table.Copy(rec)
            rec = { active = "char1", slots = {} }
            if old.name or old.model or old.id then
                old.id = "char1"
                old.key = sid .. ":char1"
                rec.slots.char1 = old
            end
            CH.Data[sid] = rec
            saveChars("migrate-multichar")
        end

        rec.active = tostring(rec.active or "char1")
        if not rec.active:match("^char[123]$") then rec.active = "char1" end
        rec.slots = istable(rec.slots) and rec.slots or {}
        return rec
    end

    local function activeSlot(ply)
        local rec = normalizePlayerData(ply)
        return rec and rec.active or "char1"
    end

    local function activeChar(ply)
        local rec = normalizePlayerData(ply)
        if not rec then return nil end
        local c = rec.slots[rec.active]
        if istable(c) then
            c.id = rec.active
            c.key = sid64(ply) .. ":" .. rec.active
            return c
        end
        return nil
    end

    local function hasCharacter(ply, slot)
        local rec = normalizePlayerData(ply)
        slot = tostring(slot or (rec and rec.active) or "char1")
        return rec and rec.slots and istable(rec.slots[slot]) and tostring(rec.slots[slot].name or "") ~= ""
    end

    --[[ ЛИМБ: ГДЕ ИГРОК ЖИВЁТ ДО ВЫБОРА ПЕРСОНАЖА (заказ владельца 22.08).

         Пока персонаж не подтверждён, игрок не должен ни стоять на карте,
         ни мешать другим, ни попадать под пули и чужие пропы. Поэтому его
         уносит далеко вверх за пределы карты: без модели, без коллизии,
         без оружия, неуязвимым и замороженным. Как только персонаж выбран,
         он выходит из лимба и его СРАЗУ ставят на точку спавна — свою
         фракционную, если он во фракции (эти точки считает система
         /spawnmenu), иначе на общую. ]]
    CH.LimboPos = Vector(0, 0, 15500)

    function CH.SendToLimbo(ply)
        if not IsValid(ply) or ply.GRMCharLimbo then return end
        ply.GRMCharLimbo = true
        ply.GRMCharLimboWeapons = true
        ply:StripWeapons()
        ply:SetMoveType(MOVETYPE_NOCLIP)
        ply:SetPos(CH.LimboPos)
        ply:SetNoDraw(true)
        ply:DrawShadow(false)
        ply:SetNotSolid(true)
        ply:SetNoTarget(true)
        ply:GodEnable()
        ply:Freeze(true)
    end

    --- Поставить игрока на его точку спавна (фракционную или общую).
    function CH.PlaceOnSpawnPoint(ply)
        if not IsValid(ply) then return false end
        local pos, ang
        if _G.GetSpawnPointForPlayer then pos, ang = _G.GetSpawnPointForPlayer(ply) end
        if not pos then
            local list = ents.FindByClass("info_player_start")
            local pick = list and list[math.random(1, math.max(1, #list))]
            if IsValid(pick) then pos, ang = pick:GetPos(), pick:GetAngles() end
        end
        if not pos then return false end
        ply:SetPos(pos)
        if ang then ply:SetEyeAngles(Angle(0, ang.y or 0, 0)) end
        -- Персонаж на месте — вот теперь выдаём набор из /weapons_admin.
        if _G.ApplyWeaponsToPlayer then
            timer.Simple(0.1, function()
                if IsValid(ply) and not CH.PendingSelection[ply:SteamID64()] then
                    _G.ApplyWeaponsToPlayer(ply)
                end
            end)
        end
        return true
    end

    function CH.ReleaseFromLimbo(ply)
        if not IsValid(ply) or not ply.GRMCharLimbo then return end
        ply.GRMCharLimbo = nil
        ply:SetNoDraw(false)
        ply:DrawShadow(true)
        ply:SetNotSolid(false)
        ply:SetNoTarget(false)
        ply:GodDisable()
        ply:Freeze(false)
        ply:SetMoveType(MOVETYPE_WALK)
        -- Спавн заново: игрок получает модель, экипировку и здоровье как
        -- обычно, а точку ему выставляем сразу после спавна.
        ply.GRMCharPlaceOnSpawn = true
        ply:Spawn()
        timer.Simple(0, function()
            if IsValid(ply) then CH.PlaceOnSpawnPoint(ply) end
        end)
    end

    hook.Add("PlayerSpawn", "GRM_Char_PlaceAfterSelect", function(ply)
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            if not ply.GRMCharPlaceOnSpawn then return end
            ply.GRMCharPlaceOnSpawn = nil
            CH.PlaceOnSpawnPoint(ply)
        end)
    end)

    local function setCharacterLock(ply, locked, mandatory)
        if not IsValid(ply) then return end
        local sid = ply:SteamID64()
        CH.PendingSelection[sid] = locked == true or nil
        CH.PendingMandatory[sid] = locked == true and mandatory == true or nil
        if ply.SetNWBool then
            ply:SetNWBool("GRM_CharacterPending", locked == true)
            ply:SetNWBool("GRM_CharacterMandatory", locked == true and mandatory == true)
        end
        if ply.Freeze then ply:Freeze(locked == true) end
        -- Лимб включается вместе с блокировкой и выключается вместе с ней.
        if locked == true then
            CH.SendToLimbo(ply)
        elseif ply.GRMCharLimbo then
            CH.ReleaseFromLimbo(ply)
        end
    end

    local function ensureChar(ply, slot)
        local rec = normalizePlayerData(ply)
        if not rec then return nil end
        slot = tostring(slot or rec.active or "char1")
        if not slot:match("^char[123]$") then slot = "char1" end
        rec.active = slot
        rec.slots[slot] = istable(rec.slots[slot]) and rec.slots[slot] or {}
        local c = rec.slots[slot]
        c.id = slot
        c.key = sid64(ply) .. ":" .. slot
        ply:SetNWString("GRM_CharacterID", c.id)
        ply:SetNWString("GRM_CharacterKey", c.key)
        return c
    end
    CH.Ensure = ensureChar

    function CH.Get(ply) return activeChar(ply) end
    function CH.GetActiveID(ply) return activeSlot(ply) end
    function CH.GetActiveKey(ply) return sid64(ply) .. ":" .. activeSlot(ply) end

    local function applyActiveCharacter(ply)
        local c = CH.Get(ply)
        -- Сбрасываем желаемую модель прошлого персонажа до проверки нового.
        ply.FactionsExt_DesiredModelData = nil
        if istable(c) then
            ply:SetNWString("GRM_CharacterID", tostring(c.id or activeSlot(ply)))
            ply:SetNWString("GRM_CharacterKey", tostring(c.key or CH.GetActiveKey(ply)))
            ply:SetNWString("GRM_RPName", tostring(c.name or ""))
            if GRM.RPDesc and GRM.RPDesc.SetFor then GRM.RPDesc.SetFor(ply, tostring(c.desc or "")) end
            local applied = false
            if isstring(c.model) and c.model ~= "" then
                applied = CH.ApplyAppearance(ply, { path = c.model, skin = c.skin, bodygroups = c.bodygroups }) == true
            end
            -- Старый/чужой faction-модельный путь не должен оставаться на новом
            -- персонаже: берём первую разрешённую модель текущей роли/гражданина.
            if not applied and _G.GetModelsForPlayer then
                local allowed = _G.GetModelsForPlayer(ply) or {}
                local fallback = allowed[1]
                if istable(fallback) and isstring(fallback.path) then
                    c.model = fallback.path
                    c.skin = tonumber(fallback.skin) or 0
                    c.bodygroups = table.Copy(fallback.bodygroups or {})
                    CH.ApplyAppearance(ply, fallback)
                    saveChars("model-fallback")
                end
            end
        else
            ply:SetNWString("GRM_CharacterID", activeSlot(ply))
            ply:SetNWString("GRM_CharacterKey", CH.GetActiveKey(ply))
            ply:SetNWString("GRM_RPName", "")
        end
    end

    function CH.SetActiveSlot(ply, slot, forceSpawn)
        local oldKey = CH.GetActiveKey(ply)
        local rec = normalizePlayerData(ply)
        if not rec then return false end
        slot = tostring(slot or "char1")
        if not slot:match("^char[123]$") then return false end
        rec.active = slot
        saveChars("select-slot")
        applyActiveCharacter(ply)
        setCharacterLock(ply, not hasCharacter(ply, slot), true)
        if GRM.Inventory and GRM.Inventory.SyncToClient then
            timer.Simple(0.05, function() if IsValid(ply) then GRM.Inventory.SyncToClient(ply) end end)
        end
        local newKey = CH.GetActiveKey(ply)
        hook.Run("GRM_CharacterChanged", ply, oldKey, newKey)
        local shouldSpawn = forceSpawn == true or oldKey ~= newKey
        if shouldSpawn then
            timer.Simple(0, function()
                if not IsValid(ply) or not hasCharacter(ply, slot) then return end
                if ply.Alive and ply:Alive() and ply.Spawn then ply:Spawn() end
            end)
        end
        return true
    end

    -- ── УНИКАЛЬНОСТЬ РП-ИМЁН ────────────────────────────────────────
    --[[ Два «Александра Фон Грённера» на сервере — это готовый абуз:
         подставить чужое имя и делать что угодно от его лица. Поэтому
         имя занимает тот, кто зарегистрировал его первым; сравнение
         идёт по ключу (регистр, Ё/ё и дефисы не спасают). ]]
    local cvUnique = CreateConVar("grm_name_unique", "1", FCVAR_ARCHIVE,
        "1 — запретить двум персонажам одинаковые РП-имена")

    function CH.UniqueNames() return cvUnique:GetBool() end

    --- Кто уже носит это имя. Возвращает sid64, слот и само имя.
    function CH.FindNameOwner(name, exceptSid, exceptSlot)
        local key = CH.NameKey(name)
        if key == "" then return nil end
        for sid, rec in pairs(CH.Data or {}) do
            if istable(rec) then
                if istable(rec.slots) then
                    for slot, c in pairs(rec.slots) do
                        if istable(c) and CH.NameKey(c.name or "") == key
                            and not (sid == exceptSid and slot == exceptSlot) then
                            return sid, slot, tostring(c.name or "")
                        end
                    end
                elseif rec.name and CH.NameKey(rec.name) == key and sid ~= exceptSid then
                    return sid, "char1", tostring(rec.name)
                end
            end
        end
        return nil
    end

    concommand.Add("grm_name_owner", function(ply, _, args)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end
        local q = table.concat(args or {}, " ")
        local function say(t) if IsValid(ply) then ply:ChatPrint(t) else print(t) end end
        local clean, err = CH.ValidateName(q)
        if not clean then say("[Персонаж] " .. tostring(err)) return end
        local sid, slot, nm = CH.FindNameOwner(clean)
        if sid then
            say(("[Персонаж] «%s» занято: %s (%s)"):format(nm, sid, slot))
        else
            say(("[Персонаж] «%s» свободно"):format(clean))
        end
    end)

    --[[ ОПИСАНИЕ ПЕРСОНАЖА.
         Оно принадлежит ПЕРСОНАЖУ, а не аккаунту: сменил слот — сменилось
         описание над головой. Поэтому храним его в записи персонажа и
         отдаём в RPDesc, который и рисует его в мире. ]]
    function CH.SetDesc(ply, text, slot)
        if not IsValid(ply) then return false end
        local clean = CH.CleanDesc(text)
        local c = ensureChar(ply, slot)
        if not istable(c) then return false end
        c.desc = clean
        c.updated = os.time()
        saveChars("setdesc")
        if GRM.RPDesc and GRM.RPDesc.SetFor then GRM.RPDesc.SetFor(ply, clean) end
        return true, clean
    end

    function CH.SetName(ply, name, slot)
        local clean, err = CH.ValidateName(name)
        if not clean then return false, tostring(err or "Некорректное имя") end
        local mySid = sid64(ply)
        local mySlot = tostring(slot or activeSlot(ply))
        if not mySlot:match("^char[123]$") then mySlot = activeSlot(ply) end
        if CH.UniqueNames() then
            local ownerSid, ownerSlot, ownerName = CH.FindNameOwner(clean, mySid, mySlot)
            if ownerSid then
                return false, ("Имя «%s» уже занято другим персонажем — придумайте другое."):format(
                    tostring(ownerName or clean))
            end
        end
        local c = ensureChar(ply, slot)
        c.name = clean
        c.updated = os.time()
        ply:SetNWString("GRM_RPName", clean)
        saveChars("setname")
        return true
    end

    local function isAllowedModel(ply, path)
        if _G.IsModelAllowedForPlayer then
            return _G.IsModelAllowedForPlayer(ply, path)
        end
        return true
    end

    function CH.ApplyAppearance(ply, entry)
        if IsValid(ply) and ply:GetNWBool("GRM_Arrested", false) then return false, "Внешность заблокирована во время ареста" end
        if not IsValid(ply) or not istable(entry) or not isstring(entry.path) then return false end
        if not isAllowedModel(ply, entry.path) then return false, "Модель не разрешена вашей фракцией/ролью" end

        if _G.ApplyModelSettings then
            _G.ApplyModelSettings(ply, { path = entry.path, skin = tonumber(entry.skin) or 0, bodygroups = entry.bodygroups or {} })
        else
            ply:SetModel(entry.path)
            ply:SetSkin(tonumber(entry.skin) or 0)
            local count = ply:GetNumBodyGroups() or 0
            for i = 0, count - 1 do ply:SetBodygroup(i, 0) end
            for g, v in pairs(entry.bodygroups or {}) do
                ply:SetBodygroup(tonumber(g) or 0, tonumber(v) or 0)
            end
        end
        -- синхронизация со строгим удержанием FactionsExt: эта запись побеждает в ModelCheck
        ply.FactionsExt_DesiredModelData = { path = entry.path, skin = tonumber(entry.skin) or 0, bodygroups = table.Copy(entry.bodygroups or {}) }

        local c = ensureChar(ply)
        c.model = entry.path
        c.skin = tonumber(entry.skin) or 0
        c.bodygroups = table.Copy(entry.bodygroups or {})
        c.updated = os.time()
        saveChars("appearance")
        return true
    end

    local function factionMembership(ply, characterKey)
        characterKey = tostring(characterKey or "")
        for name,f in pairs(Factions or {}) do
            if istable(f) and istable(f.Members) then
                local member
                if characterKey ~= "" then member = f.Members[characterKey]
                else member = GRM.Identity and GRM.Identity.FactionMember and GRM.Identity.FactionMember(f,ply) end
                if istable(member) then return name,member,f end
            end
        end
        return nil
    end

    local function modelsForContext(ply, context)
        if not istable(context) or not context.preview then
            return _G.GetModelsForPlayer and (_G.GetModelsForPlayer(ply) or {}) or {}
        end
        if context.factionName and context.faction then
            if context.onDuty == false then return istable(DefaultModels) and DefaultModels or {} end
            local f, member = context.faction, context.member or {}
            local role, department = member.Role, member.Department
            if role and istable(f.RoleModels) and istable(f.RoleModels[role]) and #f.RoleModels[role] > 0 then return f.RoleModels[role] end
            if department and istable(f.DepartmentModels) and istable(f.DepartmentModels[department]) and #f.DepartmentModels[department] > 0 then return f.DepartmentModels[department] end
            if istable(f.Models) and #f.Models > 0 then return f.Models end
        end
        return istable(DefaultModels) and DefaultModels or {}
    end

    -- провайдеры по умолчанию -----------------------------------
    CH.RegisterProvider("civilian", {
        Order = 10,
        Title = function(ply) return "Гражданская внешность" end,
        Outfits = function(ply)
            local out = {}
            if istable(DefaultModels) then
                for _, e in ipairs(DefaultModels) do
                    if istable(e) and isstring(e.path) then out[#out + 1] = { path = e.path, skin = tonumber(e.skin) or 0, bodygroups = table.Copy(istable(e.bodygroups) and e.bodygroups or {}) } end
                end
            end
            return out
        end,
    })

    CH.RegisterProvider("faction", {
        Order = 20,
        Title = function(ply, context)
            local n,m = context and context.factionName, context and context.member
            if not n then n,m=factionMembership(ply) end
            if not n then return nil end
            local onDuty = context and context.onDuty
            if onDuty == nil then onDuty = GRM.FactionDuty and GRM.FactionDuty.IsOnDuty and GRM.FactionDuty.IsOnDuty(ply) end
            return "Фракция: "..n..(m.Role and (" — "..tostring(m.Role)) or "").." • "..(onDuty and "НА СЛУЖБЕ" or "ВНЕ СЛУЖБЫ")
        end,
        Outfits = function(ply, context)
            local factionName = context and context.factionName or factionMembership(ply)
            if not factionName then return {} end
            local out = {}
            for _, e in ipairs(modelsForContext(ply, context) or {}) do
                if istable(e) and isstring(e.path) then out[#out + 1] = { path = e.path, skin = tonumber(e.skin) or 0, bodygroups = table.Copy(istable(e.bodygroups) and e.bodygroups or {}) } end
            end
            return out
        end,
    })

    -- полезная нагрузка меню ------------------------------------
    -- opts: { wardrobe=bool, title=str, allowCivilian/allowFaction/
    --         allowSkin/allowBodygroups = bool|nil, ent=Entity }
    function CH.BuildPayload(ply, opts)
        opts = istable(opts) and opts or {}
        local rec = normalizePlayerData(ply) or { active = "char1", slots = {} }
        local previewSlot = tostring(opts.previewSlot or rec.active or "char1")
        if not previewSlot:match("^char[123]$") then previewSlot = rec.active or "char1" end
        local previewKey = sid64(ply) .. ":" .. previewSlot
        local previewChar = istable(rec.slots[previewSlot]) and rec.slots[previewSlot] or nil
        if previewChar then previewChar.id = previewSlot; previewChar.key = previewKey end
        local factionName,member,faction=factionMembership(ply, previewKey)
        local hasFaction=factionName~=nil
        local onDuty = false
        if hasFaction then
            local state = GRM.FactionDuty and GRM.FactionDuty.State and GRM.FactionDuty.State[previewKey]
            onDuty = state == nil or state == true
        end
        local context = { preview = previewSlot ~= rec.active, slot = previewSlot, characterKey = previewKey,
            character = previewChar, factionName = factionName, member = member, faction = faction, onDuty = onDuty }
        local sections = {}
        local ids = {}
        for id in pairs(CH.Providers) do ids[#ids + 1] = id end
        table.sort(ids, function(a, b)
            local oa = tonumber(CH.Providers[a].Order) or 100
            local ob = tonumber(CH.Providers[b].Order) or 100
            if oa == ob then return a < b end
            return oa < ob
        end)
        for _, id in ipairs(ids) do
            local skip = false
            -- Гражданская и фракционная внешность взаимоисключающие:
            -- персонаж фракции не видит civilian-пул, гражданский не видит faction-пул.
            if id == "civilian" and hasFaction then skip = true end
            if id == "faction" and not hasFaction then skip = true end
            if opts.wardrobe and id == "civilian" and opts.allowCivilian == false then skip = true end
            if opts.wardrobe and id == "faction" and opts.allowFaction == false then skip = true end
            if not skip then
                local def = CH.Providers[id]
                local okT, title = pcall(def.Title or function() return id end, ply, context)
                if okT and title then
                    local okO, outfits = pcall(def.Outfits, ply, context)
                    if okO and istable(outfits) and #outfits > 0 then
                        sections[#sections + 1] = { id = id, title = tostring(title), outfits = outfits }
                    end
                end
            end
        end
        local allOutfits,seenOutfits = {},{}
        for _,section in ipairs(sections) do
            for _,outfit in ipairs(section.outfits or {}) do
                local sig=string.lower(tostring(outfit.path or "")).."|"..tostring(tonumber(outfit.skin) or 0).."|"..tostring(util.TableToJSON(outfit.bodygroups or {}) or "")
                if not seenOutfits[sig] then
                    seenOutfits[sig]=true; local copy=table.Copy(outfit); copy.provider=section.id; copy.providerTitle=section.title; allOutfits[#allOutfits+1]=copy
                end
            end
        end

        local slots = {}
        for i = 1, CH.MaxSlots do
            local id = slotID(i)
            local c = rec.slots[id]
            local slotFaction, slotMember = factionMembership(ply, sid64(ply) .. ":" .. id)
            slots[#slots + 1] = { id = id, index = i, exists = istable(c), name = istable(c) and tostring(c.name or "") or "",
                model = istable(c) and tostring(c.model or "") or "", skin = istable(c) and tonumber(c.skin) or 0,
                bodygroups = istable(c) and table.Copy(c.bodygroups or {}) or {}, factionName = slotFaction or "",
                factionRole = slotMember and tostring(slotMember.Role or "") or "",
                factionDepartment = slotMember and tostring(slotMember.Department or "") or "" }
        end
        return {
            char = previewChar,
            slots = slots,
            activeSlot = rec.active or "char1",
            previewSlot = previewSlot,
            characterID = previewSlot,
            characterKey = previewKey,
            identityNote = "Предпросмотр CharacterKey: " .. previewKey .. ". Активный: " .. CH.GetActiveKey(ply) .. ".",
            sections = sections, -- legacy payload compatibility
            outfits = allOutfits,
            nameMin = CH.NameMin, nameMax = CH.NameMax,
            desc = previewChar and tostring(previewChar.desc or "") or "",
            maxSlots = CH.MaxSlots,
            wardrobe = opts.wardrobe == true or nil,
            wardrobeTitle = opts.title,
            wardrobeEnt = IsValid(opts.ent) and opts.ent:EntIndex() or nil,
            allowSkin = opts.allowSkin, allowBodygroups = opts.allowBodygroups,
            isAdmin = ply:IsSuperAdmin() or nil,
            pending = CH.PendingSelection[sid64(ply)] == true,
            mandatory = CH.PendingMandatory[sid64(ply)] == true,
            factionName = factionName or "",
            factionRole = member and tostring(member.Role or "") or "",
            factionDepartment = member and tostring(member.Department or "") or "",
            onDuty = onDuty,
        }
    end

    local function sendMenu(ply, previewSlot)
        if not IsValid(ply) then return end
        net.Start(NET_OPEN)
            net.WriteTable(CH.BuildPayload(ply, { previewSlot = previewSlot }))
        net.Send(ply)
    end
    CH.OpenMenu = sendMenu

    local function closeMenu(ply)
        if not IsValid(ply) then return end
        net.Start(NET_CLOSE)
        net.Send(ply)
    end

    -- вход: меню при КАЖДОМ заходе -------------------------------
    hook.Add("PlayerInitialSpawn", "GRM_Char_OnJoin", function(ply)
        timer.Simple(1.5, function() if IsValid(ply) then sendMenu(ply) end end)
        timer.Simple(0.2, function()
            if not IsValid(ply) then return end
            normalizePlayerData(ply)
            -- При каждом входе игрок обязан явно подтвердить персонажа.
            setCharacterLock(ply, true, true)
        end)
        timer.Simple(2.2, function()
            if not IsValid(ply) then return end
            normalizePlayerData(ply)
            applyActiveCharacter(ply)
            setCharacterLock(ply, true, true)
        end)
    end)

    hook.Add("PlayerSpawn", "GRM_Char_BlockUnselectedSpawn", function(ply)
        timer.Simple(0, function()
            if not IsValid(ply) then return end
            if CH.PendingSelection[ply:SteamID64()] then
                setCharacterLock(ply, true, CH.PendingMandatory[ply:SteamID64()] == true)
                -- Меню уже открывается одним таймером PlayerInitialSpawn.
                -- Не отправляем его из каждого PlayerSpawn, иначе окна наслаиваются.
            end
        end)
    end)

    local function characterPending(ply)
        return IsValid(ply) and CH.PendingSelection[ply:SteamID64()] == true
    end

    hook.Add("StartCommand", "GRM_Char_BlockInput", function(ply, cmd)
        if not characterPending(ply) then return end
        ply:Freeze(true)
        cmd:ClearMovement()
        cmd:ClearButtons()
    end)

    --[[ Пока персонаж не выбран, стандартный набор (физган, тулган,
         камера) тоже не выдаётся: возвращаем true — движок считает, что
         экипировка уже выдана, и ничего не даёт. ]]
    hook.Add("PlayerLoadout", "GRM_Char_BlockLoadout", function(ply)
        if not characterPending(ply) then return end
        ply:StripWeapons()
        if ply.RemoveAllAmmo then ply:RemoveAllAmmo() end
        return true
    end)

    hook.Add("PlayerUse", "GRM_Char_BlockUse", function(ply)
        if characterPending(ply) then return false end
    end)

    hook.Add("PlayerSpawnProp", "GRM_Char_BlockProp", function(ply)
        if characterPending(ply) then return false end
    end)

    hook.Add("CanTool", "GRM_Char_BlockTool", function(ply)
        if characterPending(ply) then return false end
    end)

    hook.Add("CanPlayerEnterVehicle", "GRM_Char_BlockVehicle", function(ply)
        if characterPending(ply) then return false end
    end)

    hook.Add("PlayerSay", "GRM_Char_BlockChat", function(ply)
        if characterPending(ply) then return "" end
    end)

    hook.Add("PlayerDisconnected", "GRM_Char_ClearPending", function(ply)
        if IsValid(ply) then
            CH.PendingSelection[ply:SteamID64()] = nil
            CH.PendingMandatory[ply:SteamID64()] = nil
            saveChars("disconnect")
        end
    end)

    net.Receive(NET_REQUEST, function(bits, ply)
        if not IsValid(ply) then return end
        if GRM.Net and GRM.Net.Guard then
            local allowed = GRM.Net.Guard(ply, "character.menu.request", { rate = .2, burst = 4, maxBits = 1024 }, { bits = bits })
            if not allowed then return end
        end
        if ply:GetNWBool("GRM_Arrested", false) then
            if GRM.Notify then GRM.Notify(ply, "Во время ареста меню персонажа недоступно.", 255, 100, 100) end
            return
        end
        local previewSlot = ""
        if bits and bits >= 8 then previewSlot = tostring(net.ReadString() or "") end
        if not previewSlot:match("^char[123]$") then previewSlot = activeSlot(ply) end
        -- Открытие персонажей через F4 /char переводит игрока в тот же
        -- безопасный режим выбора: мир затемняется и блокируется до подтверждения.
        setCharacterLock(ply, true, false)
        sendMenu(ply, previewSlot)
    end)

    net.Receive(NET_CANCEL,function(bits,ply)
        if not IsValid(ply)then return end;if GRM.Net and not GRM.Net.Guard(ply,"character.menu.cancel",{rate=.5,burst=1,maxBits=128},{bits=bits})then return end
        if ply:GetNWBool("GRM_Arrested", false) then
            closeMenu(ply)
            return
        end
        if CH.PendingMandatory[ply:SteamID64()] == true then
            -- Первичный вход нельзя закрыть крестиком: меню возвращается,
            -- игрок остаётся заблокирован до подтверждения персонажа.
            sendMenu(ply)
            return
        end
        -- Отмена не должна повторно применять/сохранять внешность:
        -- черновик жил только на клиенте, активный персонаж не менялся.
        setCharacterLock(ply, false, false)
        closeMenu(ply)
    end)

    net.Receive(NET_SAVE,function(bits,ply)
        if not IsValid(ply)then return end
        if GRM.Net and not GRM.Net.Guard(ply,"character.menu.save",{rate=1,burst=1,maxBits=262144},{bits=bits})then return end
        if(ply._grmCharacterSaveAt or 0)>CurTime()then return end;ply._grmCharacterSaveAt=CurTime()+.75
        if ply:GetNWBool("GRM_Arrested", false) then
            if GRM.Notify then GRM.Notify(ply, "Нельзя менять персонажа во время ареста.", 255, 100, 100) end
            return
        end
        local d = net.ReadTable() or {}
        if d.action == "select_slot" then
            local slot = tostring(d.slot or "char1")
            if not slot:match("^char[123]$") then return end
            local sameActive = slot == activeSlot(ply)
            local mandatory = CH.PendingMandatory[ply:SteamID64()] == true
            if sameActive and not mandatory then
                -- Anti-abuse: повторный выбор уже активного персонажа не
                -- вызывает Spawn, телепорт, reset inventory или повторный gear-flow.
                setCharacterLock(ply, false, false)
                closeMenu(ply)
                return
            end
            local ok = CH.SetActiveSlot(ply, slot, mandatory)
            if ok and hasCharacter(ply, slot) then closeMenu(ply) else sendMenu(ply) end
            return
        end
        local requestedSlot = tostring(d.slot or activeSlot(ply))
        local mandatory = CH.PendingMandatory[ply:SteamID64()] == true
        local sameActive = requestedSlot == activeSlot(ply)
        if not sameActive or mandatory then
            CH.SetActiveSlot(ply, requestedSlot, mandatory)
        end
        local wasNew = CH.Get(ply) == nil

        if d.desc ~= nil then CH.SetDesc(ply, d.desc, d.slot) end

        -- Имя принято сервером? Если нет (эмодзи, одно слово, занято другим) —
        -- меню НЕ закрываем, иначе персонаж остаётся без имени.
        local nameOK = d.name == nil
        if d.name ~= nil then
            local ok, err = CH.SetName(ply, d.name, d.slot)
            nameOK = ok == true
            if not ok then
                if GRM.Notify then GRM.Notify(ply, tostring(err), 255, 100, 100) end
                ply:PrintMessage(HUD_PRINTTALK, "[Персонаж] " .. tostring(err))
            end
        end

        if isstring(d.model) and d.model ~= "" then
            local wardrobeRule = nil
            if d.wardrobe == true then
                local wardrobe = Entity(tonumber(d.wardrobeEnt) or 0)
                if not IsValid(wardrobe) or wardrobe:GetClass() ~= "grm_wardrobe"
                    or ply:GetPos():DistToSqr(wardrobe:GetPos()) > 220 * 220 then
                    if GRM.Notify then GRM.Notify(ply, "Гардероб недоступен или слишком далеко.", 255, 100, 100) end
                    return
                end
                local cfg = wardrobe.cfg or {}
                wardrobeRule = istable(cfg.modelRules) and cfg.modelRules[d.model] or {}
            end
            local bg = {}
            for g, v in pairs(d.bodygroups or {}) do
                local gi, vi = tonumber(g), tonumber(v)
                local groupRule = wardrobeRule and wardrobeRule.bodygroups and gi and wardrobeRule.bodygroups[gi]
                local allowed = not groupRule or groupRule == true
                    or (istable(groupRule) and groupRule[vi] ~= false)
                if gi and vi and vi ~= 0 and allowed then bg[gi] = vi end
            end
            local chosenSkin = tonumber(d.skin) or 0
            if wardrobeRule and wardrobeRule.allowSkin == false then chosenSkin = 0 end
            local ok, err = CH.ApplyAppearance(ply, { path = d.model, skin = chosenSkin, bodygroups = bg })
            if not ok and GRM.Notify then GRM.Notify(ply, tostring(err or "Не удалось применить внешность"), 255, 100, 100) end
            if ok and GRM.Notify then GRM.Notify(ply, "Внешность персонажа сохранена.", 100, 220, 100) end
        end

        if CH.Get(ply) ~= nil and isstring(d.name) and nameOK then
            setCharacterLock(ply, false)
            if wasNew then
                hook.Run("GRM_CharacterChanged", ply, nil, CH.GetActiveKey(ply))
            end
            if wasNew and ply.Spawn then ply:Spawn() end
        end

        -- первичная регистрация: синхронизируем с фракционным спавном
        if wasNew and CH.Get(ply) ~= nil and _G.GetSpawnPointForPlayer then
            local pos, ang = _G.GetSpawnPointForPlayer(ply)
            if pos then
                ply:SetPos(pos)
                if ang then ply:SetEyeAngles(ang) end
            end
        end

        if CH.Get(ply) ~= nil and nameOK then
            timer.Simple(0.05, function() if IsValid(ply) then closeMenu(ply) end end)
        else
            sendMenu(ply)
        end
    end)

    -- команда /name Имя Фамилия ----------------------------------
    hook.Add("PlayerSay", "GRM_Char_NameCmd", function(ply, text)
        local t = string.Trim(text or "")
        local low = string.lower(t)
        if string.sub(low, 1, 6) == "/name " or string.sub(low, 1, 6) == "!name " then
            local ok, resOrErr = CH.SetName(ply, string.sub(t, 7))
            if ok then
                ply:PrintMessage(HUD_PRINTTALK, "[Персонаж] Игровое имя установлено: " .. tostring(CH.GetName(ply)))
            else
                ply:PrintMessage(HUD_PRINTTALK, "[Персонаж] " .. tostring(resOrErr))
            end
            return ""
        end
        if low == "/name" or low == "!name" then
            ply:PrintMessage(HUD_PRINTTALK, "[Персонаж] Ваше игровое имя: " .. (CH.GetName(ply) ~= "" and CH.GetName(ply) or "(не задано — откройте F4 → Персонаж)"))
            return ""
        end
    end)

    -- автосохранение уже не нужно (каждый Save пишет сразу), но подстрахуемся на выключении
    hook.Add("ShutDown", "GRM_Char_Save", function() saveChars("shutdown") end)

    print("[GRM Char] Ядро персонажей v" .. CH.Version .. " загружено (сервер)")
end

-- ============================================================
-- КЛИЕНТ
-- ============================================================
if CLIENT then
    surface.CreateFont("GRMChar_Big",    { font = "Roboto", size = 26, weight = 800, extended = true })
    surface.CreateFont("GRMChar_Title",  { font = "Roboto", size = 20, weight = 800, extended = true })
    surface.CreateFont("GRMChar_Sub",    { font = "Roboto", size = 15, weight = 600, extended = true })
    surface.CreateFont("GRMChar_Normal", { font = "Roboto", size = 13, weight = 500, extended = true })
    surface.CreateFont("GRMChar_Small",  { font = "Roboto", size = 12, weight = 400, extended = true })

    -- Плоская палитра (MapStudio-стиль): ограниченный набор слотов + свои кнопки.
    local C = {
        bg     = Color(13, 16, 24, 255),
        head   = Color(22, 28, 40, 255),
        panel  = Color(24, 30, 42, 245),
        panel2 = Color(30, 38, 52, 245),
        border = Color(70, 82, 105, 180),
        acc    = Color(75, 149, 255),
        accHov = Color(100, 170, 255, 255),
        green  = Color(46, 204, 113),
        red    = Color(225, 83, 83),
        yellow = Color(245, 200, 70),
        text   = Color(235, 239, 247),
        dim    = Color(150, 160, 175),
    }

    -----------------------------------------------------------
    -- Главное меню персонажа
    -----------------------------------------------------------
    --[[ ОКНО ПЕРСОНАЖА v2 (полная переработка, заказ владельца 22.08).

         ЧТО ИЗМЕНИЛОСЬ ПО СУТИ:
           • окно на ВЕСЬ экран и без крестика: пока персонаж не выбран,
             мир недоступен, а само окно нельзя закрыть ни мышью, ни ESC;
           • три зоны вместо каши: слева персонажи, по центру живая модель,
             справа настройки вкладками (внешность / телосложение / имя и
             описание);
           • ЛЮБОЕ изменение сразу видно на модели — окно не пересобирается
             и не открывается второй раз поверх себя;
           • бодигруппы и скин — отдельная вкладка, а не хвост под списком;
           • описание персонажа редактируется прямо здесь;
           • лишние ползунки и подписи убраны: остались модель, телосложение
             и данные персонажа.
    ]]
    local function openCharMenu(payload)
        local lp = LocalPlayer()
        if IsValid(lp) and lp:GetNWBool("GRM_Arrested", false) then
            notification.AddLegacy("Во время ареста меню персонажа недоступно.", NOTIFY_ERROR, 5)
            return
        end
        payload = istable(payload) and payload or {}

        -- ── данные ──────────────────────────────────────────────────────
        local char     = istable(payload.char) and payload.char or nil
        local sections = istable(payload.sections) and payload.sections or {}
        local outfits  = istable(payload.outfits) and payload.outfits or {}
        if #outfits == 0 then
            for _, sec in ipairs(sections) do
                for _, outfit in ipairs(sec.outfits or {}) do
                    local copy = table.Copy(outfit)
                    copy.provider, copy.providerTitle = sec.id, sec.title
                    outfits[#outfits + 1] = copy
                end
            end
        end
        local defaultOutfit = outfits[1]
        for _, outfit in ipairs(outfits) do
            if outfit.provider == "civilian" then defaultOutfit = outfit break end
        end

        local slots            = istable(payload.slots) and payload.slots or {}
        local serverActiveSlot = tostring(payload.activeSlot or "char1")
        local activeSlot       = tostring(payload.previewSlot or serverActiveSlot)
        local isWardrobe       = payload.wardrobe == true
        local mandatory        = payload.mandatory == true
        CH._previewSlot, CH._actionPending, CH._actionKind = activeSlot, false, nil

        local draft = {
            name = char and tostring(char.name or "") or "",
            desc = char and tostring(char.desc or "") or tostring(payload.desc or ""),
            model = char and tostring(char.model or "") or "",
            skin = char and tonumber(char.skin) or 0,
            bodygroups = char and table.Copy(char.bodygroups or {}) or {},
            wardrobeRule = {},
        }
        local matched
        for _, outfit in ipairs(outfits) do
            if string.lower(tostring(outfit.path or "")) == string.lower(draft.model) then matched = outfit break end
        end
        if (draft.model == "" or not matched) and defaultOutfit then
            draft.model = defaultOutfit.path
            draft.skin = tonumber(defaultOutfit.skin) or 0
            draft.bodygroups = table.Copy(defaultOutfit.bodygroups or {})
            matched = defaultOutfit
        end
        if matched then draft.wardrobeRule = table.Copy(matched.wardrobeRule or {}) end

        -- ── окно ────────────────────────────────────────────────────────
        if IsValid(CH._frame) then CH._frame:Remove() CH._frame = nil end
        local f = vgui.Create("DFrame")
        CH._frame = f
        CH._frameMode = isWardrobe and "wardrobe" or "character"
        f.OnRemove = function()
            if CH._frame == f then
                CH._frame, CH._frameMode, CH._liveSignature = nil, nil, nil
                CH._actionPending, CH._actionKind = false, nil
            end
        end
        if GRM.UI and GRM.UI.Track then GRM.UI.Track("character.appearance", f) end

        f:SetTitle("")
        f:SetSize(ScrW(), ScrH())
        f:SetPos(0, 0)
        f:MakePopup()
        f:ShowCloseButton(false)
        f:SetDraggable(false)
        f:SetSizable(false)
        -- Обязательное окно не закрывается ни крестиком, ни ESC.
        f.OnKeyCodePressed = function(_, key)
            if mandatory and key == KEY_ESCAPE then return true end
        end
        if mandatory then
            f.Close = function() end
        end

        local title = isWardrobe and tostring(payload.wardrobeTitle or "ГАРДЕРОБ")
            or (char and "МЕНЮ ПЕРСОНАЖА" or "СОЗДАНИЕ ПЕРСОНАЖА")
        local factionLine = payload.factionName ~= "" and
            (((GRM.Factions and GRM.Factions.DisplayName and GRM.Factions.DisplayName(payload.factionName)) or payload.factionName)
                .. " • " .. tostring(payload.factionRole or "")
                .. (payload.onDuty and " • НА СЛУЖБЕ" or "")) or "ГРАЖДАНСКИЙ"

        f.Paint = function(_, pw, ph)
            draw.RoundedBox(0, 0, 0, pw, ph, Color(8, 10, 16, 252))
            draw.RoundedBox(0, 0, 0, pw, 70, C.head)
            draw.RoundedBox(0, 0, 70, pw, 2, C.acc)
            draw.SimpleText(title, "GRMChar_Title", 34, 22, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(factionLine, "GRMChar_Small", 34, 48, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(mandatory and "Выберите или создайте персонажа — без этого вход в мир закрыт"
                or "Изменения применяются после подтверждения", "GRMChar_Small",
                pw - 34, 48, mandatory and C.yellow or C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        end

        -- Кнопка выхода из окна — только когда персонаж уже подтверждён.
        if not mandatory then
            local x = vgui.Create("DButton", f)
            x:SetText("") x:SetSize(120, 30) x:SetPos(f:GetWide() - 150, 20)
            x.Paint = function(self, pw, ph)
                draw.RoundedBox(6, 0, 0, pw, ph, self:IsHovered() and Color(90, 60, 70) or Color(46, 52, 66))
                draw.SimpleText("ЗАКРЫТЬ", "GRMChar_Sub", pw / 2, ph / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            x.DoClick = function() f:Remove() end
        end

        local body = vgui.Create("DPanel", f)
        body:Dock(FILL) body:DockMargin(24, 84, 24, 20) body:SetPaintBackground(false)

        local footer = vgui.Create("DPanel", f)
        footer:SetSize(f:GetWide() - 48, 62)
        footer:SetPos(24, f:GetTall() - 78)
        footer:SetPaintBackground(false)

        -- ── ЦЕНТР: живая модель ─────────────────────────────────────────
        local center = vgui.Create("DPanel", body)
        center:Dock(FILL) center:DockMargin(14, 0, 14, 78)
        center.Paint = function(_, pw, ph)
            draw.RoundedBox(10, 0, 0, pw, ph, C.panel)
            surface.SetDrawColor(C.border) surface.DrawOutlinedRect(0, 0, pw, ph, 1)
        end

        local preview = vgui.Create("DModelPanel", center)
        preview:Dock(FILL) preview:DockMargin(8, 8, 8, 8)
        preview:SetFOV(34)
        preview:SetAnimated(true)
        preview.LayoutEntity = function(self, ent)
            if self.bAnimated then self:RunAnimation() end
            ent:SetAngles(Angle(0, self.GRMYaw or 45, 0))
        end
        preview.GRMYaw = 45
        preview.OnMousePressed = function(self) self.GRMDrag = true self:MouseCapture(true) end
        preview.OnMouseReleased = function(self) self.GRMDrag = false self:MouseCapture(false) end
        preview.OnCursorMoved = function(self, x)
            if not self.GRMDrag then return end
            local last = self.GRMLastX or x
            self.GRMYaw = (self.GRMYaw or 45) + (x - last) * 0.6
            self.GRMLastX = x
        end
        preview.Think = function(self) if not self.GRMDrag then self.GRMLastX = nil end end

        local modelName = vgui.Create("DLabel", center)
        modelName:Dock(BOTTOM) modelName:SetTall(24) modelName:DockMargin(14, 0, 14, 8)
        modelName:SetFont("GRMChar_Small") modelName:SetTextColor(C.dim)

        --[[ Живое обновление: одна функция на всё окно. Меняем модель, скин
             или бодигруппу — она сразу видна, без пересборки окна. ]]
        local rebuildBodygroups
        local function applyPreview(fullModel)
            if not IsValid(preview) then return end
            if fullModel then preview:SetModel(draft.model) end
            local ent = preview:GetEntity()
            if not IsValid(ent) then return end
            ent:SetSkin(math.max(0, math.floor(tonumber(draft.skin) or 0)))
            local count = ent:GetNumBodyGroups() or 0
            for i = 0, count - 1 do ent:SetBodygroup(i, 0) end
            for g, v in pairs(draft.bodygroups or {}) do
                ent:SetBodygroup(tonumber(g) or 0, tonumber(v) or 0)
            end
            -- камера по габаритам модели: персонаж всегда в кадре целиком
            local mn, mx = ent:GetRenderBounds()
            local center3 = (mn + mx) * 0.5
            local size = mx.z - mn.z
            preview:SetLookAt(Vector(0, 0, center3.z))
            preview:SetCamPos(Vector(size * 1.05, size * 0.9, center3.z + size * 0.18))
            modelName:SetText("Модель: " .. tostring(draft.model))
        end

        -- ── ЛЕВО: персонажи ─────────────────────────────────────────────
        local left = vgui.Create("DPanel", body)
        left:Dock(LEFT) left:SetWide(340) left:SetPaintBackground(false)

        local slotHead = vgui.Create("DLabel", left)
        slotHead:Dock(TOP) slotHead:SetTall(26) slotHead:SetFont("GRMChar_Sub") slotHead:SetTextColor(C.yellow)
        slotHead:SetText(isWardrobe and "Гардероб" or "Ваши персонажи")

        local slotButtons = {}
        if not isWardrobe then
            for i = 1, (payload.maxSlots or 3) do
                local info = slots[i] or { id = "char" .. i, index = i, exists = false }
                local b = vgui.Create("DButton", left)
                b:SetText("") b:Dock(TOP) b:SetTall(104) b:DockMargin(0, 0, 0, 10)
                b._slotID, b._selected, b._active = info.id, info.id == activeSlot, info.id == serverActiveSlot
                slotButtons[#slotButtons + 1] = b
                b.Paint = function(self, pw, ph)
                    local sel, has = self._selected == true, info.exists == true
                    draw.RoundedBox(10, 0, 0, pw, ph, sel and Color(30, 48, 72) or C.panel)
                    surface.SetDrawColor(sel and C.acc or C.border) surface.DrawOutlinedRect(0, 0, pw, ph, sel and 2 or 1)
                    draw.RoundedBox(4, 0, 0, 4, ph, sel and C.acc or (has and C.green or Color(70, 78, 92)))
                    local nm = has and (info.name ~= "" and info.name or ("Персонаж " .. i)) or ("Свободный слот " .. i)
                    draw.SimpleText(nm, "GRMChar_Sub", 18, 14, has and C.text or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    local detail = (info.factionName or "") ~= "" and
                        (((GRM.Factions and GRM.Factions.DisplayName and GRM.Factions.DisplayName(info.factionName)) or info.factionName)
                            .. ((info.factionRole or "") ~= "" and (" • " .. info.factionRole) or "")) or "Гражданский"
                    draw.SimpleText(has and detail or "Нажмите, чтобы создать", "GRMChar_Small", 18, 40,
                        (has and (info.factionName or "") ~= "") and C.yellow or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    if has and (info.model or "") ~= "" then
                        draw.SimpleText(tostring(info.model):match("([^/]+)$") or info.model, "GRMChar_Small",
                            18, 60, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    end
                    draw.SimpleText(self._active and "АКТИВЕН" or (sel and "ПРОСМОТР" or "ВЫБРАТЬ"), "GRMChar_Small",
                        pw - 16, ph - 20, sel and C.acc or C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
                b.DoClick = function()
                    if info.id == activeSlot or CH._actionPending then return end
                    CH._actionPending, CH._actionKind, CH._previewSlot = true, "preview", info.id
                    for _, sb in ipairs(slotButtons) do sb:SetEnabled(false) end
                    net.Start(NET_REQUEST) net.WriteString(info.id) net.SendToServer()
                    timer.Simple(4, function()
                        if IsValid(f) and CH._frame == f and CH._actionPending then
                            CH._actionPending, CH._actionKind = false, nil
                            for _, sb in ipairs(slotButtons) do if IsValid(sb) then sb:SetEnabled(true) end end
                        end
                    end)
                end
            end
        end

        local idHint = vgui.Create("DLabel", left)
        idHint:Dock(BOTTOM) idHint:SetTall(20) idHint:SetFont("GRMChar_Small") idHint:SetTextColor(C.dim)
        idHint:SetText("CharacterID: " .. tostring(payload.characterID or "будет создан"))

        -- ── ПРАВО: настройки вкладками ──────────────────────────────────
        local right = vgui.Create("DPanel", body)
        right:Dock(RIGHT) right:SetWide(430) right:SetPaintBackground(false)

        local tabBar = vgui.Create("DPanel", right)
        tabBar:Dock(TOP) tabBar:SetTall(38) tabBar:SetPaintBackground(false)

        local pages, tabButtons = {}, {}
        local function showPage(id)
            for pid, pg in pairs(pages) do if IsValid(pg) then pg:SetVisible(pid == id) end end
            for tid, tb in pairs(tabButtons) do if IsValid(tb) then tb._on = (tid == id) end end
        end

        local function addTab(id, label)
            local b = vgui.Create("DButton", tabBar)
            b:SetText("") b:Dock(LEFT) b:SetWide(140) b:DockMargin(0, 0, 6, 0)
            b.Paint = function(self, pw, ph)
                draw.RoundedBox(8, 0, 0, pw, ph, self._on and C.acc or (self:IsHovered() and C.panel2 or C.panel))
                draw.SimpleText(label, "GRMChar_Small", pw / 2, ph / 2, self._on and color_white or C.dim,
                    TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            b.DoClick = function() showPage(id) end
            tabButtons[id] = b
            local page = vgui.Create("DPanel", right)
            page:Dock(FILL) page:DockMargin(0, 8, 0, 0) page:SetPaintBackground(false)
            pages[id] = page
            return page
        end

        local pageLook = addTab("look", "ВНЕШНОСТЬ")
        local pageBody = addTab("body", "ТЕЛОСЛОЖЕНИЕ")
        local pageInfo = addTab("info", "ИМЯ И ОПИСАНИЕ")

        -- Вкладка «Внешность»: список разрешённых моделей.
        local lookScroll = vgui.Create("DScrollPanel", pageLook)
        lookScroll:Dock(FILL)
        local outfitButtons = {}
        local function refreshOutfitButtons()
            for _, ob in ipairs(outfitButtons) do
                ob._on = string.lower(ob._path) == string.lower(draft.model or "")
            end
        end
        for _, outfit in ipairs(outfits) do
            local path = tostring(outfit.path or "")
            if path ~= "" then
                local row = vgui.Create("DButton", lookScroll)
                row:SetText("") row:Dock(TOP) row:SetTall(74) row:DockMargin(0, 0, 6, 6)
                row._path = path
                outfitButtons[#outfitButtons + 1] = row
                local icon = vgui.Create("SpawnIcon", row)
                icon:SetPos(8, 5) icon:SetSize(64, 64)
                icon:SetModel(path, tonumber(outfit.skin) or 0)
                icon:SetMouseInputEnabled(false)
                row.Paint = function(self, pw, ph)
                    draw.RoundedBox(8, 0, 0, pw, ph, self._on and Color(30, 48, 72) or (self:IsHovered() and C.panel2 or C.panel))
                    surface.SetDrawColor(self._on and C.acc or C.border) surface.DrawOutlinedRect(0, 0, pw, ph, self._on and 2 or 1)
                    local nm = (tostring(outfit.label or path):match("([^/]+)$") or path):gsub("%.mdl$", "")
                    draw.SimpleText(nm, "GRMChar_Normal", 82, 18, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText(tostring(outfit.providerTitle or outfit.provider or "Доступная модель"),
                        "GRMChar_Small", 82, 40, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end
                row.DoClick = function()
                    draft.model = path
                    draft.skin = tonumber(outfit.skin) or 0
                    draft.bodygroups = table.Copy(outfit.bodygroups or {})
                    draft.wardrobeRule = table.Copy(outfit.wardrobeRule or {})
                    refreshOutfitButtons()
                    applyPreview(true)
                    rebuildBodygroups()
                end
            end
        end
        refreshOutfitButtons()
        if #outfits == 0 then
            local none = vgui.Create("DLabel", lookScroll)
            none:Dock(TOP) none:SetText("Для вашей роли нет доступных моделей.")
            none:SetFont("GRMChar_Normal") none:SetTextColor(C.dim)
        end

        -- Вкладка «Телосложение»: скин и бодигруппы, всё вживую.
        local bodyScroll = vgui.Create("DScrollPanel", pageBody)
        bodyScroll:Dock(FILL)

        local function stepperRow(parent, label, get, set, count)
            local row = vgui.Create("DPanel", parent)
            row:Dock(TOP) row:SetTall(46) row:DockMargin(0, 0, 6, 6)
            row.Paint = function(_, pw, ph)
                draw.RoundedBox(8, 0, 0, pw, ph, C.panel)
                draw.SimpleText(label, "GRMChar_Normal", 14, ph / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(tostring(get()) .. " / " .. tostring(math.max(0, count() - 1)), "GRMChar_Small",
                    pw - 96, ph / 2, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
            local function arrow(text, dir, x)
                local b = vgui.Create("DButton", row)
                b:SetText("") b:SetSize(32, 28) b:SetPos(x, 9)
                b.Paint = function(self, pw, ph)
                    draw.RoundedBox(6, 0, 0, pw, ph, self:IsHovered() and C.accHov or C.panel2)
                    draw.SimpleText(text, "GRMChar_Sub", pw / 2, ph / 2, C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                b.DoClick = function()
                    local total = math.max(1, count())
                    set((get() + dir) % total)
                    applyPreview(false)
                end
                return b
            end
            arrow("◀", -1, 0)
            arrow("▶", 1, 0)
            row.PerformLayout = function(self, pw)
                local kids = self:GetChildren()
                if IsValid(kids[1]) then kids[1]:SetPos(pw - 78, 9) end
                if IsValid(kids[2]) then kids[2]:SetPos(pw - 42, 9) end
            end
            return row
        end

        rebuildBodygroups = function()
            if not IsValid(bodyScroll) then return end
            bodyScroll:Clear()
            local ent = IsValid(preview) and preview:GetEntity() or nil
            if not IsValid(ent) then return end

            if payload.allowSkin ~= false then
                stepperRow(bodyScroll, "Вариант окраски (скин)",
                    function() return math.floor(tonumber(draft.skin) or 0) end,
                    function(v) draft.skin = v end,
                    function() return math.max(1, ent:SkinCount() or 1) end)
            end

            local rule = draft.wardrobeRule or {}
            local added = 0
            for i = 0, (ent:GetNumBodyGroups() or 0) - 1 do
                local total = ent:GetBodygroupCount(i) or 1
                local groupRule = rule.bodygroups and rule.bodygroups[i]
                local allowed = (payload.allowBodygroups ~= false)
                    and (not isWardrobe or groupRule == nil or groupRule == true or istable(groupRule))
                if total > 1 and allowed then
                    added = added + 1
                    local name = ent:GetBodygroupName(i)
                    if name == "" then name = "Группа " .. i end
                    stepperRow(bodyScroll, name,
                        function() return math.floor(tonumber(draft.bodygroups[i]) or 0) end,
                        function(v) draft.bodygroups[i] = v end,
                        function() return total end)
                end
            end
            if added == 0 then
                local none = vgui.Create("DLabel", bodyScroll)
                none:Dock(TOP) none:SetText("У этой модели нет настраиваемых частей.")
                none:SetFont("GRMChar_Normal") none:SetTextColor(C.dim)
            end
        end

        -- Вкладка «Имя и описание».
        local infoPad = vgui.Create("DPanel", pageInfo)
        infoPad:Dock(FILL) infoPad:SetPaintBackground(false)

        local nameLbl = vgui.Create("DLabel", infoPad)
        nameLbl:Dock(TOP) nameLbl:SetTall(22) nameLbl:SetFont("GRMChar_Sub") nameLbl:SetTextColor(C.yellow)
        nameLbl:SetText("Игровое имя (Имя Фамилия)")

        local nameEntry = vgui.Create("DTextEntry", infoPad)
        nameEntry:Dock(TOP) nameEntry:SetTall(34) nameEntry:DockMargin(0, 4, 6, 4)
        nameEntry:SetFont("GRMChar_Sub")
        nameEntry:SetText(draft.name)
        nameEntry:SetUpdateOnType(true)

        local nameHint = vgui.Create("DLabel", infoPad)
        nameHint:Dock(TOP) nameHint:SetTall(22) nameHint:SetFont("GRMChar_Normal")

        local function updHint()
            local n, err = CH.ValidateName(draft.name)
            nameHint:SetText(n and ("✓ " .. n) or tostring(err or "Только буквы, пробел, дефис и апостроф"))
            nameHint:SetTextColor(n and C.green or C.red)
        end
        nameEntry.OnChange = function() draft.name = nameEntry:GetValue() updHint() end
        updHint()

        local descLbl = vgui.Create("DLabel", infoPad)
        descLbl:Dock(TOP) descLbl:SetTall(24) descLbl:SetFont("GRMChar_Sub") descLbl:SetTextColor(C.yellow)
        descLbl:DockMargin(0, 8, 0, 0)
        descLbl:SetText("Описание персонажа (видно другим)")

        local descEntry = vgui.Create("DTextEntry", infoPad)
        descEntry:Dock(TOP) descEntry:SetTall(120) descEntry:DockMargin(0, 4, 6, 4)
        descEntry:SetMultiline(true)
        descEntry:SetFont("GRMChar_Normal")
        descEntry:SetText(draft.desc)

        local descHint = vgui.Create("DLabel", infoPad)
        descHint:Dock(TOP) descHint:SetTall(20) descHint:SetFont("GRMChar_Small") descHint:SetTextColor(C.dim)
        local function updDesc()
            draft.desc = descEntry:GetValue() or ""
            descHint:SetText(("Символов: %d из %d"):format(CH.Len(draft.desc), CH.DescMax or 300))
        end
        descEntry.OnChange = updDesc
        updDesc()

        local idLbl = vgui.Create("DLabel", infoPad)
        idLbl:Dock(TOP) idLbl:SetTall(20) idLbl:SetFont("GRMChar_Small") idLbl:SetTextColor(C.dim)
        idLbl:SetText("Ключ персонажа: " .. tostring(payload.characterKey or "будет создан"))

        showPage(char and "look" or "info")

        -- ── ФУТЕР: подтверждение ────────────────────────────────────────
        local function submitCharacter()
            local nm, nmErr = CH.ValidateName(draft.name)
            if not nm then
                Derma_Message(tostring(nmErr or "Укажите игровое имя.") ..
                    "\nПример: Александр Фон Грённер, Мария Готтен-Фон-Штоцкая.", "Персонаж", "Ок")
                showPage("info")
                return
            end
            if CH._actionPending then return end
            CH._actionPending, CH._actionKind = true, "save"
            net.Start(NET_SAVE)
                net.WriteTable({
                    slot = activeSlot or "char1", name = draft.name, desc = draft.desc,
                    model = draft.model, skin = draft.skin, bodygroups = draft.bodygroups,
                    wardrobe = isWardrobe, wardrobeEnt = payload.wardrobeEnt, wardrobeRule = draft.wardrobeRule,
                })
            net.SendToServer()
            timer.Simple(5, function()
                if IsValid(f) and CH._frame == f then CH._actionPending, CH._actionKind = false, nil end
            end)
        end

        local hint = vgui.Create("DLabel", footer)
        hint:Dock(LEFT) hint:SetWide(700) hint:SetFont("GRMChar_Normal") hint:SetTextColor(C.dim)
        hint:SetText(isWardrobe and "Гардероб: выберите внешность и сохраните."
            or "Модель крутится мышью. Изменения видны сразу, в мир они уйдут после подтверждения.")

        local confirm = vgui.Create("DButton", footer)
        confirm:SetText("") confirm:Dock(RIGHT) confirm:SetWide(320) confirm:DockMargin(8, 8, 0, 8)
        local confirmText = isWardrobe and "СОХРАНИТЬ ВНЕШНОСТЬ"
            or (char and "ИГРАТЬ ЗА ЭТОГО ПЕРСОНАЖА" or "СОЗДАТЬ И ВОЙТИ В МИР")
        confirm.Paint = function(self, pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, self:IsHovered() and Color(70, 220, 130) or C.green)
            draw.SimpleText(confirmText, "GRMChar_Sub", pw / 2, ph / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        confirm.DoClick = submitCharacter

        applyPreview(true)
        rebuildBodygroups()
        -- модель приходит в панель не мгновенно: перепроверяем раскладку
        timer.Simple(0.12, function()
            if IsValid(f) and IsValid(preview) then applyPreview(false) rebuildBodygroups() end
        end)
    end

    local function payloadSignature(p)
        local parts={tostring(p.wardrobe),tostring(p.wardrobeEnt),tostring(p.activeSlot),tostring(p.previewSlot),tostring(p.characterKey),tostring(p.factionName),tostring(p.factionRole),tostring(p.factionDepartment),tostring(p.onDuty),tostring(p.char and p.char.name),tostring(p.char and p.char.model)}
        for _,sl in ipairs(p.slots or{})do parts[#parts+1]=tostring(sl.id)..":"..tostring(sl.name)..":"..tostring(sl.model)..":"..tostring(sl.factionName)..":"..tostring(sl.factionRole)..":"..tostring(sl.factionDepartment)end
        for _,o in ipairs(p.outfits or {}) do parts[#parts+1]=tostring(o.path)..":"..tostring(o.skin) end
        return table.concat(parts,"|")
    end
    function CH.ReceiveMenuPayload(payload)
        payload=istable(payload)and payload or{};local sig=payloadSignature(payload);local mode=payload.wardrobe==true and"wardrobe"or"character"
        if IsValid(CH._frame)and CH._liveSignature==sig and CH._frameMode==mode then if CH._actionKind=="preview"then CH._actionPending=false;CH._actionKind=nil end return false end
        if CH._opening then CH._queuedPayload=payload return false end
        CH._opening=true;local ok,err=pcall(openCharMenu,payload);CH._opening=false
        if not ok then ErrorNoHalt("[GRM Character] menu build failed: "..tostring(err).."\n")return false end
        -- Set AFTER old frame removal: its OnRemove clears the previous signature.
        CH._liveSignature=sig;CH._actionPending=false;CH._actionKind=nil
        local queued=CH._queuedPayload;CH._queuedPayload=nil;if queued then timer.Simple(0,function()CH.ReceiveMenuPayload(queued)end)end
        return true
    end
    net.Receive(NET_OPEN,function() CH.ReceiveMenuPayload(net.ReadTable() or {}) end)
    timer.Create("GRM_Char_LiveRefresh",2,0,function()
        if IsValid(CH._frame)and CH._frameMode=="character"and not CH._actionPending and not CH._opening then
            net.Start(NET_REQUEST); net.WriteString(CH._previewSlot or "char1"); net.SendToServer()
        end
    end)

    --[[ Закрытие окна по команде сервера.
         Раньше звали :Close(), но у обязательного окна он специально
         отключён (чтобы игрок не закрыл его сам) — поэтому меню висело
         на экране и после выбора персонажа. Сносим панель напрямую. ]]
    net.Receive(NET_CLOSE, function()
        CH._reopenAt = RealTime() + 2
        if IsValid(CH._frame) then
            CH._frame:SetVisible(false)
            CH._frame:Remove()
        end
        CH._frame, CH._frameMode, CH._liveSignature = nil, nil, nil
        CH._actionPending, CH._actionKind = false, nil
    end)

    -- Точка входа гардероба проходит через тот же singleton/dedup guard.
    CH._openFromWardrobe = CH.ReceiveMenuPayload

    function CH.OpenMenu()
        local lp = LocalPlayer()
        if IsValid(lp) and lp:GetNWBool("GRM_Arrested", false) then
            notification.AddLegacy("Во время ареста меню персонажа недоступно.", NOTIFY_ERROR, 5)
            return
        end
        if IsValid(CH._frame) and CH._frameMode == "character" then
            CH._frame:MakePopup(); CH._frame:MoveToFront(); return
        end
        if (CH._nextOpenRequest or 0) > RealTime() then return end
        CH._nextOpenRequest = RealTime() + .5
        local slot = CH._previewSlot or (IsValid(lp) and lp:GetNWString("GRM_CharacterID", "char1")) or "char1"
        net.Start(NET_REQUEST); net.WriteString(slot); net.SendToServer()
    end
    concommand.Add("grm_character", CH.OpenMenu)

    hook.Add("PlayerSayTransform", "GRM_Char_ChatCl", function(ply, text)
        if ply ~= LocalPlayer() then return end
        local msg = string.lower(string.Trim(text and (istable(text) and text[1] or text) or ""))
        if msg == "/char" or msg == "/chars" or msg == "!char" then
            CH.OpenMenu()
            if istable(text) then text[1] = "" end
            return true
        end
    end)

    local function clientCharacterPending()
        local lp = LocalPlayer()
        return IsValid(lp) and lp:GetNWBool("GRM_CharacterPending", false)
    end

    hook.Add("HUDPaintBackground", "GRM_Char_LockScreen", function()
        if not clientCharacterPending() then return end
        surface.SetDrawColor(0, 0, 0, 255)
        surface.DrawRect(0, 0, ScrW(), ScrH())
        draw.SimpleText("Выберите персонажа", "GRMChar_Title", ScrW() / 2, ScrH() - 84,
            Color(235, 235, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Игровой мир заблокирован до подтверждения персонажа", "GRMChar_Normal",
            ScrW() / 2, ScrH() - 58, Color(145, 155, 175), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)

    hook.Add("HUDShouldDraw", "GRM_Char_HideHUD", function()
        if clientCharacterPending() then return false end
    end)

    hook.Add("PlayerBindPress", "GRM_Char_BlockBinds", function(_, bind)
        if clientCharacterPending() then return true end
    end)

    hook.Add("SpawnMenuOpen", "GRM_Char_BlockSpawnMenu", function()
        if clientCharacterPending() then return false end
    end)

    hook.Add("ContextMenuOpen", "GRM_Char_BlockContextMenu", function()
        if clientCharacterPending() then return false end
    end)

    -- ESC не должен ни открывать игровое меню, ни закрывать окно выбора.
    hook.Add("OnPauseMenuShow", "GRM_Char_BlockPause", function()
        if clientCharacterPending() then return false end
    end)

    -- Пока персонаж не выбран, окно всегда на экране: если игрок его
    -- как-то закрыл (сторож окон, чужой аддон), просим меню заново.
    hook.Add("Think", "GRM_Char_KeepMenu", function()
        if not clientCharacterPending() then return end
        if IsValid(CH._frame) then return end
        if (CH._reopenAt or 0) > RealTime() then return end
        CH._reopenAt = RealTime() + 1.5
        net.Start(NET_REQUEST) net.WriteString(CH._previewSlot or "char1") net.SendToServer()
    end)

    hook.Add("Think", "GRM_Char_CloseForeignMenus", function()
        if not clientCharacterPending() then CH._foreignMenuCheckAt=nil return end
        local now=CurTime();if(CH._foreignMenuCheckAt or 0)>now then return end;CH._foreignMenuCheckAt=now+.1
        if GRM.Mobile and GRM.Mobile.ClientIsOpen and GRM.Mobile.ClientIsOpen()
            and GRM.Mobile.ClientClose then
            GRM.Mobile.ClientClose()
        end
    end)

    print("[GRM Char] Ядро персонажей v" .. CH.Version .. " загружено (клиент)")
end
