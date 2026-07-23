--[[--------------------------------------------------------------------
    GRM Identity Core v1.1.0 (Код 72) — Персонажи, RP-имена, регистрация
    v1.1.0: ширина меню удвоена (до 1880 px, адаптивно под экран).
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

CH.Version    = "1.3.0"
CH.NameMin    = 3     -- минимальная длина RP-имени
CH.NameMax    = 48
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
-- ------------------------------------------------------------
function CH.ValidateName(raw)
    local s = string.Trim(tostring(raw or ""))
    s = string.gsub(s, "%s+", " ")
    if #s < CH.NameMin then return nil, "Имя короче " .. CH.NameMin .. " символов" end
    if #s > CH.NameMax then s = string.sub(s, 1, CH.NameMax) end
    return s
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

    function CH.SetName(ply, name, slot)
        name = CH.ValidateName(name)
        if not name then return false, "Некорректное имя" end
        local c = ensureChar(ply, slot)
        c.name = name
        c.updated = os.time()
        ply:SetNWString("GRM_RPName", name)
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
        Title = function(ply)
            if not istable(Factions) then return "Фракция" end
            local sid, s64 = ply:SteamID(), ply:SteamID64()
            local ck = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(ply)) or nil
            for n, f in pairs(Factions) do
                local m = nil
                if istable(f) and istable(f.Members) then
                    if ck then m = f.Members[ck]
                    else m = f.Members[sid] or f.Members[s64] end
                end
                if istable(m) then
                    return "Фракция: " .. n .. (m.Role and (" — " .. tostring(m.Role)) or "")
                end
            end
            return nil -- скрыть секцию для гражданских
        end,
        Outfits = function(ply)
            if _G.GetModelsForPlayer then
                local hasFaction = false
                if istable(Factions) then
                    local sid, s64 = ply:SteamID(), ply:SteamID64()
                    local ck = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(ply)) or nil
                    for _, f in pairs(Factions) do
                        if istable(f) and istable(f.Members) then
                            local member
                            if ck then member = f.Members[ck]
                            else member = f.Members[sid] or f.Members[s64] end
                            if member then hasFaction = true break end
                        end
                    end
                end
                if not hasFaction then return {} end
                local out = {}
                for _, e in ipairs(_G.GetModelsForPlayer(ply) or {}) do
                    if istable(e) and isstring(e.path) then out[#out + 1] = { path = e.path, skin = tonumber(e.skin) or 0, bodygroups = table.Copy(istable(e.bodygroups) and e.bodygroups or {}) } end
                end
                return out
            end
            return {}
        end,
    })

    -- полезная нагрузка меню ------------------------------------
    -- opts: { wardrobe=bool, title=str, allowCivilian/allowFaction/
    --         allowSkin/allowBodygroups = bool|nil, ent=Entity }
    function CH.BuildPayload(ply, opts)
        opts = istable(opts) and opts or {}
        local sections = {}
        local ids = {}
        for id in pairs(CH.Providers) do ids[#ids + 1] = id end
        table.sort(ids, function(a, b)
            local oa = tonumber(CH.Providers[a].Order) or 100
            local ob = tonumber(CH.Providers[b].Order) or 100
            if oa == ob then return a < b end
            return oa < ob
        end)
        local hasFaction = false
        if istable(Factions) and GRM.Identity and GRM.Identity.FactionMember then
            for _, faction in pairs(Factions) do
                if GRM.Identity.FactionMember(faction, ply) then hasFaction = true break end
            end
        end
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
                local okT, title = pcall(def.Title or function() return id end, ply)
                if okT and title then
                    local okO, outfits = pcall(def.Outfits, ply)
                    if okO and istable(outfits) and #outfits > 0 then
                        sections[#sections + 1] = { id = id, title = tostring(title), outfits = outfits }
                    end
                end
            end
        end
        local allOutfits = {}
        for _, section in ipairs(sections) do
            for _, outfit in ipairs(section.outfits or {}) do
                local copy = table.Copy(outfit)
                copy.provider = section.id
                copy.providerTitle = section.title
                allOutfits[#allOutfits + 1] = copy
            end
        end

        local rec = normalizePlayerData(ply) or { active = "char1", slots = {} }
        local slots = {}
        for i = 1, CH.MaxSlots do
            local id = slotID(i)
            local c = rec.slots[id]
            slots[#slots + 1] = { id = id, index = i, exists = istable(c), name = istable(c) and tostring(c.name or "") or "", model = istable(c) and tostring(c.model or "") or "" }
        end
        return {
            char = CH.Get(ply),
            slots = slots,
            activeSlot = rec.active or "char1",
            characterID = CH.GetActiveID(ply),
            characterKey = CH.GetActiveKey(ply),
            identityNote = "Активный CharacterKey: " .. CH.GetActiveKey(ply) .. ". Новые модули должны использовать GRM.Char.GetActiveKey(ply).",
            sections = sections, -- legacy payload compatibility
            outfits = allOutfits,
            nameMin = CH.NameMin, nameMax = CH.NameMax,
            wardrobe = opts.wardrobe == true or nil,
            wardrobeTitle = opts.title,
            wardrobeEnt = IsValid(opts.ent) and opts.ent:EntIndex() or nil,
            allowSkin = opts.allowSkin, allowBodygroups = opts.allowBodygroups,
            isAdmin = ply:IsSuperAdmin() or nil,
            pending = CH.PendingSelection[sid64(ply)] == true,
            mandatory = CH.PendingMandatory[sid64(ply)] == true,
        }
    end

    local function sendMenu(ply)
        if not IsValid(ply) then return end
        net.Start(NET_OPEN)
            net.WriteTable(CH.BuildPayload(ply))
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

    net.Receive(NET_REQUEST, function(_, ply)
        if not IsValid(ply) then return end
        -- Открытие персонажей через F4 /char переводит игрока в тот же
        -- безопасный режим выбора: мир затемняется и блокируется до подтверждения.
        setCharacterLock(ply, true, false)
        sendMenu(ply)
    end)

    net.Receive(NET_CANCEL, function(_, ply)
        if not IsValid(ply) then return end
        if CH.PendingMandatory[ply:SteamID64()] == true then
            -- Первичный вход нельзя закрыть крестиком: меню возвращается,
            -- игрок остаётся заблокирован до подтверждения персонажа.
            sendMenu(ply)
            return
        end
        setCharacterLock(ply, false, false)
        applyActiveCharacter(ply)
        closeMenu(ply)
    end)

    net.Receive(NET_SAVE, function(_, ply)
        if not IsValid(ply) then return end
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

        if d.name ~= nil then
            local ok, err = CH.SetName(ply, d.name, d.slot)
            if not ok then
                if GRM.Notify then GRM.Notify(ply, tostring(err), 255, 100, 100) end
            end
        end

        if isstring(d.model) and d.model ~= "" then
            local bg = {}
            for g, v in pairs(d.bodygroups or {}) do
                local gi, vi = tonumber(g), tonumber(v)
                if gi and vi and vi ~= 0 then bg[gi] = vi end
            end
            local ok, err = CH.ApplyAppearance(ply, { path = d.model, skin = tonumber(d.skin) or 0, bodygroups = bg })
            if not ok and GRM.Notify then GRM.Notify(ply, tostring(err or "Не удалось применить внешность"), 255, 100, 100) end
            if ok and GRM.Notify then GRM.Notify(ply, "Внешность персонажа сохранена.", 100, 220, 100) end
        end

        if CH.Get(ply) ~= nil and isstring(d.name) and CH.ValidateName(d.name) then
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

        if CH.Get(ply) ~= nil and (not d.name or CH.ValidateName(d.name)) then
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
    surface.CreateFont("GRMChar_Title",  { font = "Roboto", size = 20, weight = 800, extended = true })
    surface.CreateFont("GRMChar_Sub",    { font = "Roboto", size = 15, weight = 600, extended = true })
    surface.CreateFont("GRMChar_Normal", { font = "Roboto", size = 13, weight = 500, extended = true })

    local C = {
        bg    = Color(20, 24, 32, 252),
        head  = Color(28, 34, 46, 255),
        panel = Color(32, 38, 50, 245),
        panel2= Color(26, 32, 42, 245),
        acc   = Color(70, 150, 240),
        green = Color(60, 190, 110),
        red   = Color(220, 75, 70),
        yellow= Color(230, 180, 60),
        text  = Color(240, 245, 250),
        dim   = Color(160, 170, 185),
    }

    local function mkBtn(p, txt, col)
        local b = vgui.Create("DButton", p)
        b:SetText(txt) b:SetFont("GRMChar_Sub") b:SetTextColor(color_white)
        b.Paint = function(self, pw, ph)
            local cc = col or C.acc
            if not self:IsEnabled() then cc = Color(60, 65, 75)
            elseif self:IsHovered() then cc = Color(math.min(255, cc.r + 25), math.min(255, cc.g + 25), math.min(255, cc.b + 25)) end
            draw.RoundedBox(6, 0, 0, pw, ph, cc)
        end
        return b
    end

    -----------------------------------------------------------
    -- Главное меню персонажа
    -----------------------------------------------------------
    local function openCharMenu(payload)
        payload = istable(payload) and payload or {}
        -- Bodygroups персонажа задаются моделью фракции через /models_admin.
        -- В обычном меню персонажа их нельзя вручную переопределять.
        if payload.wardrobe ~= true then payload.allowBodygroups = false end
        local char = istable(payload.char) and payload.char or nil
        local sections = istable(payload.sections) and payload.sections or {}
        local outfits = istable(payload.outfits) and payload.outfits or {}
        if #outfits == 0 then
            for _, sec in ipairs(sections) do
                for _, outfit in ipairs(sec.outfits or {}) do
                    local copy = table.Copy(outfit)
                    copy.provider = sec.id
                    copy.providerTitle = sec.title
                    outfits[#outfits + 1] = copy
                end
            end
        end
        local defaultOutfit = outfits[1]
        for _, outfit in ipairs(outfits) do
            if outfit.provider == "civilian" then defaultOutfit = outfit break end
        end
        local slots = istable(payload.slots) and payload.slots or {}
        local activeSlot = tostring(payload.activeSlot or "char1")
        local refreshPreview, refreshSkinMax, rebuildBodygroups
        local skinSlider
        local bContinue, bSave

        -- состояние редактора (черновик)
        local draft = {
            name = char and tostring(char.name or "") or "",
            model = char and tostring(char.model or "") or "",
            skin = char and tonumber(char.skin) or 0,
            bodygroups = char and table.Copy(char.bodygroups or {}) or {},
        }
        if draft.model == "" and defaultOutfit then
            draft.model = defaultOutfit.path
            draft.skin = tonumber(defaultOutfit.skin) or 0
            draft.bodygroups = table.Copy(defaultOutfit.bodygroups or {})
        end

        if IsValid(CH._frame) then
            CH._frame:Remove()
            CH._frame = nil
        end
        local f = vgui.Create("DFrame")
        CH._frame = f
        f.OnRemove = function()
            if CH._frame == f then CH._frame = nil end
        end
        f:SetTitle("")
        -- v1.2: меню больше по высоте и компактнее по ширине: не «полоса», а полноценный экран персонажа
        local fw = math.min(1320, ScrW() - 80)
        local fh = math.min(860, ScrH() - 80)
        local leftW = math.min(560, math.floor(fw * 0.44))
        f:SetSize(fw, fh)
        f:Center()
        f:MakePopup()
        f:ShowCloseButton(false)
        f:SetDraggable(false)
        f.Paint = function(_, pw, ph)
            draw.RoundedBox(12, 0, 0, pw, ph, Color(9, 12, 18, 252))
            draw.RoundedBox(10, 8, 8, pw - 16, ph - 16, C.bg)
            draw.RoundedBoxEx(10, 8, 8, pw - 16, 58, C.head, true, true, false, false)
            local ttl = payload.wardrobe and tostring(payload.wardrobeTitle or "Гардероб")
                or (char and "Меню персонажа" or "Создание персонажа")
            draw.SimpleText(ttl, "GRMChar_Title", 24, 29, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("ID: " .. tostring(payload.characterID or "—"), "GRMChar_Normal", pw - 24, 22, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            draw.SimpleText("GRM Identity v" .. CH.Version, "GRMChar_Normal", pw - 24, 42, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        local function canClose() return payload.wardrobe == true or (char ~= nil and payload.pending ~= true) end

        local x = vgui.Create("DButton", f)
        x:SetText("X") x:SetFont("GRMChar_Title") x:SetTextColor(color_white)
        x:SetPos(fw - 48, 18) x:SetSize(32, 28)
        x.DoClick = function()
            if payload.wardrobe == true then
                f:Close()
                return
            end
            -- Отмена через крестик: сервер сам решает, можно ли выйти.
            net.Start(NET_CANCEL)
            net.SendToServer()
            f:Close()
        end
        x.Paint = function(self, pw, ph) draw.RoundedBox(4, 0, 0, pw, ph, self:IsHovered() and C.red or Color(45, 52, 68)) end

        -- админская кнопка настройки гардероба
        if payload.wardrobe and payload.isAdmin and payload.wardrobeEnt then
            local bCfg = mkBtn(f, "⚙ Настройка гардероба", C.yellow)
            bCfg:SetTextColor(Color(30, 28, 20))
            bCfg:SetPos(fw - 320, 8) bCfg:SetSize(220, 28)
            bCfg.DoClick = function()
                net.Start("GRM_Wardrobe_CfgReq")
                    net.WriteUInt(tonumber(payload.wardrobeEnt) or 0, 16)
                net.SendToServer()
                f:Close()
            end
        end

        -- ЛЕВАЯ КОЛОНКА: имя + провайдеры (список внешностей)
        local left = vgui.Create("DPanel", f)
        left:Dock(LEFT) left:DockMargin(18, 78, 8, 18) left:SetWide(leftW)
        left:SetPaintBackground(false)

        local nameBox = vgui.Create("DPanel", left)
        nameBox:Dock(TOP) nameBox:SetTall(118) nameBox:DockMargin(0, 0, 0, 10)
        nameBox.Paint = function(_, pw, ph)
            draw.RoundedBox(6, 0, 0, pw, ph, C.panel)
            draw.SimpleText("Игровое имя (RP Name)", "GRMChar_Sub", 10, 14, C.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local nameEntry = vgui.Create("DTextEntry", nameBox)
        nameEntry:SetPos(10, 30) nameEntry:SetSize(math.min(560, leftW - 30), 30)
        nameEntry:SetFont("GRMChar_Sub")
        nameEntry:SetPlaceholderText("Имя Фамилия")
        nameEntry:SetText(draft.name)
        nameEntry:SetUpdateOnType(true)
        nameEntry.OnChange = function() draft.name = nameEntry:GetValue() end
        local nameHint = vgui.Create("DLabel", nameBox)
        nameHint:SetPos(10, 62) nameHint:SetSize(leftW - 20, 20) nameHint:SetFont("GRMChar_Normal") nameHint:SetTextColor(C.dim)
        local idHint = vgui.Create("DLabel", nameBox)
        idHint:SetPos(10, 88) idHint:SetSize(leftW - 20, 22) idHint:SetFont("GRMChar_Normal") idHint:SetTextColor(C.dim)
        idHint:SetText("CharacterID: " .. tostring(payload.characterID or "будет создан"))
        local function updHint()
            local n = CH.ValidateName(draft.name)
            nameHint:SetText(n and ("OK: «" .. n .. "»") or ("Имя: мин. " .. (payload.nameMin or 3) .. " символа"))
            nameHint:SetTextColor(n and C.green or C.red)
        end
        updHint() nameEntry.OnChange = function() draft.name = nameEntry:GetValue() updHint() end

        local slotPanel = vgui.Create("DPanel", left)
        slotPanel:Dock(TOP) slotPanel:SetTall(72) slotPanel:DockMargin(0, 0, 0, 10)
        slotPanel.Paint = function(_, pw, ph)
            draw.RoundedBox(6, 0, 0, pw, ph, C.panel)
            draw.SimpleText("Слоты персонажей", "GRMChar_Sub", 10, 14, C.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local slotButtons = {}
        local function refreshSlotButtons()
            for _, slotButton in ipairs(slotButtons) do
                slotButton._selected = slotButton._slotID == activeSlot
            end
        end
        for i = 1, 3 do
            local info = slots[i] or { id = "char" .. i, index = i, exists = false }
            local b = mkBtn(slotPanel, (info.exists and (info.name ~= "" and info.name or ("Персонаж " .. i)) or ("+ Слот " .. i)), info.id == activeSlot and C.green or C.panel2)
            b._slotID = info.id
            b._selected = info.id == activeSlot
            slotButtons[#slotButtons + 1] = b
            b.Paint = function(self, pw, ph)
                local cc = self._selected and C.green or C.panel2
                if not self:IsEnabled() then cc = Color(45, 50, 60)
                elseif self:IsHovered() then cc = Color(math.min(255, cc.r + 18), math.min(255, cc.g + 18), math.min(255, cc.b + 18)) end
                draw.RoundedBox(6, 0, 0, pw, ph, cc)
            end
            b:SetPos(10 + (i - 1) * math.floor((leftW - 34) / 3), 30)
            b:SetSize(math.floor((leftW - 40) / 3), 34)
            b:SetFont("GRMChar_Normal")
            b:SetEnabled(not (info.id == payload.activeSlot and payload.pending and payload.mandatory ~= true))
            b:SetTooltip(info.model ~= "" and ("Текущая модель: " .. info.model) or "Персонаж ещё не создан")
            b.DoClick = function()
                -- Выбор карточки — только локальный черновик. Серверный активный
                -- CharacterKey, счета, фракция и spawn НЕ меняются до подтверждения.
                activeSlot = info.id
                refreshSlotButtons()
                draft.name = tostring(info.name or "")
                draft.model = tostring(info.model or "")
                draft.skin = 0
                draft.bodygroups = {}
                if draft.model == "" and defaultOutfit then
                    draft.model = defaultOutfit.path
                    draft.skin = tonumber(defaultOutfit.skin) or 0
                    draft.bodygroups = table.Copy(defaultOutfit.bodygroups or {})
                end
                nameEntry:SetText(draft.name)
                updHint()
                refreshPreview()
                refreshSkinMax()
                skinSlider:SetValue(draft.skin)
                rebuildBodygroups()
                bContinue:SetVisible(info.exists == true)
                bSave:SetVisible(info.exists ~= true or payload.wardrobe == true)
                bSave:SetText(info.exists and "" or "Создать и выбрать")
            end
        end

        -- ПРАВАЯ КОЛОНКА: превью + настройка модели
        local right = vgui.Create("DPanel", f)
        right:Dock(FILL) right:DockMargin(8, 78, 18, 18)
        right:SetPaintBackground(false)

        local previewTitle = vgui.Create("DPanel", right)
        previewTitle:Dock(TOP) previewTitle:SetTall(54) previewTitle:DockMargin(0,0,0,8)
        previewTitle.Paint = function(_, pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, C.panel)
            draw.SimpleText("3D-превью персонажа", "GRMChar_Sub", 14, 18, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Модель, скин и bodygroups применяются после сохранения", "GRMChar_Normal", 14, 38, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local preview = vgui.Create("DModelPanel", right)
        preview:Dock(FILL) preview:DockMargin(0, 0, 0, 10)
        preview:SetFOV(36)
        preview:SetDirectionalLight(BOX_TOP, Color(255, 255, 255))
        preview:SetDirectionalLight(BOX_FRONT, Color(180, 200, 255))
        preview:SetAmbientLight(Color(90, 100, 125))
        function preview:LayoutEntity(ent) end
        -- Используем штатный Paint DModelPanel: он корректно запускает
        -- cam.Start3D/DrawModel на всех ветках GMod.

        refreshPreview = function()
            if not IsValid(preview) then return end
            if draft.model == "" then return end
            preview:SetModel(draft.model)
            local ent = preview:GetEntity()
            if IsValid(ent) then
                local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
                local center = (mins + maxs) * 0.5
                local height = math.max(32, maxs.z - mins.z)
                local width = math.max(32, maxs.y - mins.y)
                local fov = 36
                -- DModelPanel использует FOV для вертикального кадра не так,
                -- как обычная камера. Считаем дистанцию по высоте модели,
                -- иначе голова/ноги обрезаются на разных моделях.
                local distance = math.max(height * 1.35, width * 2.4,
                    (height * 0.5) / math.tan(math.rad(fov * 0.5)) * 1.35)
                preview:SetFOV(fov)
                preview:SetLookAt(center + Vector(0, 0, height * 0.02))
                preview:SetCamPos(center + Vector(distance, 0, height * 0.03))
                ent:SetSkin(math.Clamp(tonumber(draft.skin) or 0, 0, 64))
                for i = 0, (ent:GetNumBodyGroups() or 1) - 1 do ent:SetBodygroup(i, 0) end
                for g, v in pairs(draft.bodygroups or {}) do
                    ent:SetBodygroup(tonumber(g) or 0, tonumber(v) or 0)
                end
            end
        end
        refreshPreview()
        timer.Simple(0, function() if IsValid(preview) then refreshPreview() end end)
        timer.Simple(0.15, function() if IsValid(preview) then refreshPreview() end end)

        local sets = vgui.Create("DPanel", right)
        sets:Dock(BOTTOM) sets:SetTall(132) sets:SetPaintBackground(false)

        local skinLbl = vgui.Create("DLabel", sets)
        skinLbl:Dock(TOP) skinLbl:SetTall(18) skinLbl:SetFont("GRMChar_Sub") skinLbl:SetTextColor(C.text)
        skinLbl:SetText("Скин")

        skinSlider = vgui.Create("DNumSlider", sets)
        skinSlider:Dock(TOP) skinSlider:SetTall(26)
        skinSlider:SetMin(0) skinSlider:SetDecimals(0)
        skinSlider:SetValue(draft.skin)
        skinSlider.OnValueChanged = function(_, val)
            draft.skin = math.floor(tonumber(val) or 0)
            local ent = IsValid(preview) and preview:GetEntity()
            if IsValid(ent) then ent:SetSkin(draft.skin) end
        end
        -- гардероб может отключать настройку скинов
        if payload.allowSkin == false then
            skinLbl:SetVisible(false) skinSlider:SetVisible(false)
            sets:SetTall(88)
        end
        -- и настройку бодигрупп
        if payload.allowBodygroups == false then
            sets:SetTall(payload.allowSkin == false and 4 or 60)
        end
        refreshSkinMax = function()
            local ent = IsValid(preview) and preview:GetEntity()
            local mx = IsValid(ent) and (ent:SkinCount() - 1) or 0
            skinSlider:SetMax(mx)
            if draft.skin > mx then draft.skin = mx skinSlider:SetValue(mx) end
            skinLbl:SetText("Скин (макс: " .. mx .. ")")
        end
        refreshSkinMax()

        -- bodygroups
        local bgScroll = vgui.Create("DScrollPanel", sets)
        bgScroll:Dock(FILL) bgScroll:DockMargin(0, 4, 0, 0)
        if payload.allowBodygroups == false then bgScroll:SetVisible(false) end

        rebuildBodygroups = function()
            bgScroll:Clear()
            local ent = IsValid(preview) and preview:GetEntity()
            if not IsValid(ent) then return end
            local n = ent:GetNumBodyGroups() or 0
            for i = 0, n - 1 do
                local count = ent:GetBodygroupCount(i) or 1
                if count > 1 then
                    local row = vgui.Create("DPanel", bgScroll)
                    row:Dock(TOP) row:SetTall(24) row:DockMargin(0, 0, 0, 2)
                    row.Paint = function(_, pw, ph) draw.RoundedBox(4, 0, 0, pw, ph, C.panel2) end
                    local gname = ent:GetBodygroupName(i) or ("Группа " .. i)
                    local cur = tonumber(draft.bodygroups[i]) or 0

                    local bL = mkBtn(row, "◀", C.acc) bL:Dock(LEFT) bL:SetWide(30) bL:DockMargin(2, 2, 0, 2)
                    local bR = mkBtn(row, "▶", C.acc) bR:Dock(RIGHT) bR:SetWide(30) bR:DockMargin(0, 2, 2, 2)
                    local valLbl = vgui.Create("DLabel", row)
                    valLbl:Dock(FILL) valLbl:DockMargin(6, 0, 6, 0)
                    valLbl:SetFont("GRMChar_Normal") valLbl:SetTextColor(C.text)
                    local function upd()
                        local v = tonumber(draft.bodygroups[i]) or 0
                        valLbl:SetText(gname .. ":  " .. v .. " / " .. (count - 1))
                        valLbl:SizeToContentsX() valLbl:SetWide(190)
                        ent:SetBodygroup(i, v)
                    end
                    bL.DoClick = function()
                        local v = tonumber(draft.bodygroups[i]) or 0
                        v = (v - 1) % count
                        draft.bodygroups[i] = v
                        if v == 0 then draft.bodygroups[i] = nil end
                        upd()
                    end
                    bR.DoClick = function()
                        local v = tonumber(draft.bodygroups[i]) or 0
                        v = (v + 1) % count
                        draft.bodygroups[i] = v
                        if v == 0 then draft.bodygroups[i] = nil end
                        upd()
                    end
                    upd()
                end
            end
            if bgScroll:GetCanvas():GetTall() <= 2 then
                local none = vgui.Create("DLabel", bgScroll)
                none:Dock(TOP) none:SetText("У этой модели нет бодигрупп для настройки.")
                none:SetFont("GRMChar_Normal") none:SetTextColor(C.dim)
            end
        end
        rebuildBodygroups()

        local function selectModel(entry)
            draft.model = entry.path
            draft.skin = tonumber(entry.skin) or 0
            draft.bodygroups = table.Copy(entry.bodygroups or {})
            refreshPreview()
            refreshSkinMax()
            skinSlider:SetValue(draft.skin)
            rebuildBodygroups()
        end

        -- Единый список внешности: гражданские и фракционные модели
        -- не разделяются вкладками. Доступный набор уже отфильтрован сервером
        -- для активного CharacterKey.
        local sheet = vgui.Create("DPropertySheet", left)
        sheet:Dock(FILL)
        local sc = vgui.Create("DScrollPanel")
        sc:DockMargin(2, 2, 2, 2)
        for _, entry in ipairs(outfits) do
            local row = vgui.Create("DPanel", sc)
            row:Dock(TOP) row:SetTall(66) row:DockMargin(0, 0, 0, 6)
            row.Paint = function(_, pw, ph)
                draw.RoundedBox(6, 0, 0, pw, ph, (entry.path == draft.model) and Color(44, 66, 96) or C.panel)
            end

            local bn = mkBtn(row, "", C.panel)
            bn:Dock(FILL) bn:DockMargin(0, 3, 3, 3)
            bn:SetFont("GRMChar_Normal") bn:SetTextColor(C.text)
            bn.Paint = function(self, pw, ph)
                local cc = (entry.path == draft.model) and Color(44, 66, 96) or C.panel2
                if self:IsHovered() then cc = Color(cc.r + 14, cc.g + 14, cc.b + 14) end
                draw.RoundedBox(5, 0, 0, pw, ph, cc)
            end
            local provider = entry.providerTitle and tostring(entry.providerTitle) or "Внешность"
            bn:SetText(provider .. (entry.path == draft.model and "  •  ВЫБРАНО" or ""))
            bn:SetTooltip("Выбрать этот образ")
            bn.DoClick = function()
                selectModel(entry)
                surface.PlaySound("buttons/button15.wav")
            end
        end
        sheet:AddSheet("Внешность", sc, "icon16/user.png")

        -- НИЗ: действия
        local bot = vgui.Create("DPanel", f)
        bot:Dock(BOTTOM) bot:SetTall(50) bot:DockMargin(10, 0, 10, 10)
        bot:SetPaintBackground(false)

        local function submitCharacter()
            local nm = CH.ValidateName(draft.name)
            if not nm then
                Derma_Message("Укажите игровое имя (мин. " .. (payload.nameMin or 3) .. " символа).", "Персонаж", "Ок")
                return
            end
            net.Start(NET_SAVE)
                net.WriteTable({ slot = activeSlot or "char1", name = draft.name, model = draft.model, skin = draft.skin, bodygroups = draft.bodygroups })
            net.SendToServer()
        end

        bContinue = mkBtn(bot, char and "Продолжить" or "", C.acc)
        bContinue:Dock(RIGHT) bContinue:SetWide(150) bContinue:DockMargin(8, 6, 0, 6)
        bContinue:SetVisible(char ~= nil)
        bContinue.DoClick = submitCharacter

        bSave = mkBtn(bot, char and "" or "Создать персонажа", C.green)
        bSave:Dock(RIGHT) bSave:SetWide(230) bSave:DockMargin(8, 6, 0, 6)
        bSave:SetVisible(char == nil or payload.wardrobe == true)
        bSave.DoClick = submitCharacter

        if not char then
            bSave:SetText("Создать персонажа (обязательно)")
        end
    end

    net.Receive(NET_OPEN, function()
        openCharMenu(net.ReadTable() or {})
    end)

    net.Receive(NET_CLOSE, function()
        if IsValid(CH._frame) then
            CH._frame:Close()
            CH._frame = nil
        end
    end)

    -- точка входа гардероба (grm_wardrobe, Код 73)
    CH._openFromWardrobe = openCharMenu

    function CH.OpenMenu()
        net.Start(NET_REQUEST) net.SendToServer()
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

    hook.Add("Think", "GRM_Char_CloseForeignMenus", function()
        if not clientCharacterPending() then return end
        if GRM.Mobile and GRM.Mobile.ClientIsOpen and GRM.Mobile.ClientIsOpen()
            and GRM.Mobile.ClientClose then
            GRM.Mobile.ClientClose()
        end
    end)

    print("[GRM Char] Ядро персонажей v" .. CH.Version .. " загружено (клиент)")
end
