--[[--------------------------------------------------------------------
    GRM Fleet v1.0.0 — закупка транспорта организациями (заказ 21.08).

    ЗАЧЕМ. Раньше ведомственный транспорт просто существовал: дилер выдавал
    его по факту принадлежности к организации. Теперь у техники есть путь:

      1. РЫНОК. Суперадмин заранее собирает рынок закупок: какие машины
         вообще продаются государством, по какой цене, кому (уровень допуска
         и/или конкретные организации), сколько единиц одного класса можно
         держать в парке.
      2. ЗАКУПКА. Лидер организации (или роль с правом «Закупка транспорта»)
         покупает нужное количество машин в АВТОПАРК организации. Деньги
         списываются с бюджета организации и уходят в государственную казну.
      3. ПРИПИСКА. Каждая купленная единица приписана к гаражу — тому
         самому, с размеченными местами стоянки. Машины выдаются по местам,
         а не в одну точку.
      4. ЭКСПЛУАТАЦИЯ. Сотрудник берёт машину в гараже своей организации и
         возвращает её туда же. Списать единицу с баланса может тот, кто
         имеет право распоряжаться парком (возврат части стоимости).

    Данные:
      data/grm_fleet/market.json       — рынок (общий для сервера)
      data/grm_fleet/fleet_<карта>.json — сам парк (привязан к гаражам карты)
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Fleet = GRM.Fleet or {}
local FL = GRM.Fleet
FL.Version = "1.0.0"

FL.Net = {
    OPEN = "GRM_Fleet_Open",
    SYNC = "GRM_Fleet_Sync",
    ACT  = "GRM_Fleet_Act",
}

--- Уровни рынка: чем выше, тем уже круг покупателей.
FL.Tiers = {
    civil    = { name = "Гражданская техника", order = 10 },
    gov      = { name = "Государственная",     order = 20, levels = { police = true, medical = true, fire = true, justice = true, military = true, special = true, admin = true } },
    police   = { name = "Полицейская",         order = 30, levels = { police = true, justice = true, special = true, admin = true } },
    military = { name = "Военная",             order = 40, levels = { military = true, special = true, admin = true } },
    special  = { name = "Спецтехника",         order = 50, levels = { special = true, admin = true } },
}

FL.UnitStatuses = {
    stored = "в гараже",
    active = "на линии",
    scrap  = "списана",
}

function FL.TierName(tier) 
    local def = FL.Tiers[tostring(tier or "")]
    return def and def.name or "Гражданская техника"
end

function FL.TierList()
    local out = {}
    for key, def in pairs(FL.Tiers) do out[#out + 1] = { key = key, name = def.name, order = def.order or 100 } end
    table.sort(out, function(a, b) return a.order < b.order end)
    return out
end

-----------------------------------------------------------------------
-- ДОСТУП (чистая логика — гоняется в стенде)
-----------------------------------------------------------------------

--- Разрешена ли позиция рынка этой организации на этом уровне допуска.
--  entry.factions пустой = «всем»; entry.tier ограничивает по уровню госбазы.
function FL.EntryAllowed(entry, faction, level, isAdmin)
    if not istable(entry) then return false, "Позиция не найдена" end
    if isAdmin then return true end
    faction = tostring(faction or "")
    if faction == "" then return false, "Закупка доступна только организациям" end

    if istable(entry.factions) and #entry.factions > 0 then
        local hit = false
        for _, f in ipairs(entry.factions) do if tostring(f) == faction then hit = true break end end
        if not hit then return false, "Эта техника вашей организации не отпускается" end
        return true
    end

    local tier = FL.Tiers[tostring(entry.tier or "civil")] or FL.Tiers.civil
    if not istable(tier.levels) then return true end
    if tier.levels[tostring(level or "none")] ~= true then
        return false, ("Уровень допуска организации не позволяет закупать: %s"):format(tier.name)
    end
    return true
end

--[[ ЗАКРЕПЛЕНИЕ ТЕХНИКИ ЗА ДОЛЖНОСТЯМИ И ОТДЕЛАМИ.
     «Кому какая машина положена» — обычное требование: патрульная не для
     штабного, броневик не для стажёра. Пустые списки = техника доступна
     всем сотрудникам организации. Функция чистая: на вход единица и
     «актор» { faction, role, department, subdepartment, superadmin }. ]]
function FL.UnitAllowedFor(unit, actor)
    if not istable(unit) then return false, "Единица не найдена" end
    actor = istable(actor) and actor or {}
    if actor.superadmin then return true end
    if tostring(actor.faction or "") ~= tostring(unit.faction or "") then
        return false, "Это техника другой организации"
    end

    local roles = istable(unit.roles) and unit.roles or {}
    local depts = istable(unit.depts) and unit.depts or {}
    if #roles == 0 and #depts == 0 then return true end

    for _, r in ipairs(roles) do
        if tostring(r) == tostring(actor.role or "") then return true end
    end
    for _, d in ipairs(depts) do
        local dd = tostring(d)
        if dd == tostring(actor.department or "") or dd == tostring(actor.subdepartment or "") then return true end
    end
    return false, "Эта машина закреплена за другими должностями"
end

--- Человекочитаемое «за кем закреплена».
function FL.RestrictionText(unit)
    if not istable(unit) then return "" end
    local roles = istable(unit.roles) and unit.roles or {}
    local depts = istable(unit.depts) and unit.depts or {}
    if #roles == 0 and #depts == 0 then return "доступна всем сотрудникам" end
    local parts = {}
    if #roles > 0 then parts[#parts + 1] = "должности: " .. table.concat(roles, ", ") end
    if #depts > 0 then parts[#parts + 1] = "отделы: " .. table.concat(depts, ", ") end
    return table.concat(parts, "   •   ")
end

--- Сколько единиц этого класса уже в парке организации (без списанных).
function FL.CountClass(faction, class)
    local n = 0
    for _, unit in pairs(FL.Units or {}) do
        if istable(unit) and tostring(unit.faction) == tostring(faction)
            and tostring(unit.class) == tostring(class) and unit.status ~= "scrap" then
            n = n + 1
        end
    end
    return n
end

--- Проверка закупки без денег и записи: сколько реально можно взять.
function FL.CanOrder(entry, faction, count, have)
    count = math.max(1, math.floor(tonumber(count) or 1))
    local limit = math.max(0, math.floor(tonumber(entry and entry.limit) or 0))
    if limit > 0 then
        have = tonumber(have) or 0
        if have >= limit then
            return 0, ("В парке уже %d ед. «%s» — это предел"):format(have, tostring(entry.name or entry.class))
        end
        if have + count > limit then
            return limit - have, ("Можно закупить ещё %d ед. — предел %d"):format(limit - have, limit)
        end
    end
    return count
end

--- Итоговая стоимость партии.
function FL.OrderPrice(entry, count)
    local price = math.max(0, math.floor(tonumber(entry and entry.price) or 0))
    count = math.max(1, math.floor(tonumber(count) or 1))
    return price * count, price
end

-----------------------------------------------------------------------
-- ОБЩИЕ ДАННЫЕ
-----------------------------------------------------------------------
FL.Market = FL.Market or {}   -- id -> позиция рынка
FL.Units  = FL.Units  or {}   -- id -> единица парка
FL.Active = FL.Active or {}   -- id -> живая машина

function FL.Entry(id) return FL.Market[tostring(id or "")] end
function FL.Unit(id) return FL.Units[tostring(id or "")] end

function FL.MarketList()
    local out = {}
    for id, entry in pairs(FL.Market) do
        if istable(entry) then entry.id = id out[#out + 1] = entry end
    end
    table.sort(out, function(a, b)
        local ta = (FL.Tiers[a.tier or "civil"] or FL.Tiers.civil).order
        local tb = (FL.Tiers[b.tier or "civil"] or FL.Tiers.civil).order
        if ta ~= tb then return ta < tb end
        return tostring(a.name) < tostring(b.name)
    end)
    return out
end

function FL.UnitsOf(faction)
    local out = {}
    for id, unit in pairs(FL.Units) do
        if istable(unit) and tostring(unit.faction) == tostring(faction) and unit.status ~= "scrap" then
            unit.id = id
            out[#out + 1] = unit
        end
    end
    table.sort(out, function(a, b) return tostring(a.name) .. tostring(a.id) < tostring(b.name) .. tostring(b.id) end)
    return out
end

--- Единицы парка, приписанные к конкретному гаражу.
function FL.UnitsInGarage(garageID, faction)
    local out = {}
    garageID = tostring(garageID or "")
    for id, unit in pairs(FL.Units) do
        if istable(unit) and unit.status ~= "scrap" and tostring(unit.garageID or "") == garageID
            and (faction == nil or tostring(unit.faction) == tostring(faction)) then
            unit.id = id
            out[#out + 1] = unit
        end
    end
    table.sort(out, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return out
end

if SERVER then

    util.AddNetworkString(FL.Net.OPEN)
    util.AddNetworkString(FL.Net.SYNC)
    util.AddNetworkString(FL.Net.ACT)

    FL.ScrapCvar = FL.ScrapCvar or CreateConVar("grm_fleet_scrap", "60", FCVAR_ARCHIVE,
        "Процент стоимости, который возвращается организации при списании техники")
    FL.StateShareCvar = FL.StateShareCvar or CreateConVar("grm_fleet_state_share", "100", FCVAR_ARCHIVE,
        "Какая доля закупки уходит в государственную казну (в процентах)")

    local DIR = "grm_fleet"
    local MARKET_FILE = DIR .. "/market.json"
    local function fleetFile() return DIR .. "/fleet_" .. string.lower(game.GetMap() or "unknown") .. ".json" end

    local function ensureDir()
        if not file.IsDir(DIR, "DATA") then file.CreateDir(DIR) end
    end

    local function trim(s, n) return string.sub(string.Trim(tostring(s or "")), 1, n or 64) end

    local function notify(ply, text, good)
        if not IsValid(ply) then return end
        if GRM.Notify then
            GRM.Notify(ply, text, good and 100 or 255, good and 220 or 140, good and 130 or 100)
        else
            ply:ChatPrint("[Автопарк] " .. tostring(text))
        end
    end

    local function charKey(ply)
        if not IsValid(ply) then return "" end
        if GRM.Identity and GRM.Identity.CharacterKey then return GRM.Identity.CharacterKey(ply) end
        return tostring(ply:SteamID64() or "0") .. ":char1"
    end

    local function factionOf(ply)
        return IsValid(ply) and ply:GetNWString("GRM_Faction", "") or ""
    end
    FL.FactionOf = factionOf

    local function levelOf(ply)
        if GRM.PCBoard and GRM.PCBoard.PlayerLevel then
            return (GRM.PCBoard.PlayerLevel(ply))
        end
        return "none"
    end

    -- ── доступ ──────────────────────────────────────────────────────

    --- Право закупать технику для организации.
    function FL.CanBuy(ply, faction)
        if not IsValid(ply) then return false, "Игрок не найден" end
        if ply:IsSuperAdmin() then return true end
        faction = tostring(faction or factionOf(ply))
        if faction == "" then return false, "Вы не состоите в организации" end
        if factionOf(ply) ~= faction then return false, "Это чужая организация" end

        if _G.FactionsAPI and FactionsAPI.IsLeader and FactionsAPI.IsLeader(ply, faction) then return true end
        if GRM.FactionPerms and GRM.FactionPerms.PlayerHasPermission
            and GRM.FactionPerms.PlayerHasPermission(ply, "fleet_buy") then return true end
        if GRM.Access and GRM.Access.Can and GRM.Access.Can(ply, "fleet.buy") then return true end
        return false, "Закупкой техники занимается руководство организации"
    end

    --- Право распоряжаться парком: приписка к гаражу, списание.
    function FL.CanManage(ply, faction)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return true end
        faction = tostring(faction or factionOf(ply))
        if faction == "" or factionOf(ply) ~= faction then return false end
        if _G.FactionsAPI and FactionsAPI.IsLeader and FactionsAPI.IsLeader(ply, faction) then return true end
        if GRM.FactionPerms and GRM.FactionPerms.PlayerHasPermission then
            if GRM.FactionPerms.PlayerHasPermission(ply, "fleet_manage") then return true end
            if GRM.FactionPerms.PlayerHasPermission(ply, "fleet_buy") then return true end
        end
        return false
    end

    --- Право взять машину из парка (любой сотрудник организации).
    function FL.CanUse(ply, faction)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return true end
        return factionOf(ply) ~= "" and factionOf(ply) == tostring(faction or "")
    end

    --- «Актор» для проверки закрепления техники за должностью.
    function FL.ActorOf(ply)
        if not IsValid(ply) then return {} end
        return {
            faction = factionOf(ply),
            role = ply:GetNWString("GRM_Role", ""),
            department = ply:GetNWString("GRM_Department", ""),
            subdepartment = ply:GetNWString("GRM_Subdepartment", ""),
            superadmin = ply:IsSuperAdmin(),
        }
    end

    --- Закрепить технику за должностями/отделами (право «распоряжение парком»).
    function FL.SetRestriction(ply, unitID, roles, depts)
        local unit = FL.Unit(unitID)
        if not unit then return false, "Единица не найдена" end
        if not FL.CanManage(ply, unit.faction) then return false, "Нет права распоряжаться парком" end
        local function clean(list)
            local out = {}
            for _, v in ipairs(istable(list) and list or {}) do
                local s = trim(v, 64)
                if s ~= "" and #out < 12 then out[#out + 1] = s end
            end
            return out
        end
        unit.roles = clean(roles)
        unit.depts = clean(depts)
        FL.SaveFleet("закрепление техники")
        return true, ("Техника «%s»: %s"):format(tostring(unit.name), FL.RestrictionText(unit))
    end

    -- ── хранение ────────────────────────────────────────────────────
    --[[ Та же защита, что и у номеров: пока рынок и парк не прочитаны с
         диска, записывать нечего — иначе очередь сохранит пустоту поверх
         закупленной техники. ]]
    FL._loaded = FL._loaded or false

    local function marketPayload()
        if not FL._loaded then return nil end
        local arr = {}
        for id, entry in pairs(FL.Market) do
            if istable(entry) then entry.id = id arr[#arr + 1] = entry end
        end
        table.sort(arr, function(a, b) return tostring(a.id) < tostring(b.id) end)
        return { version = 1, market = arr }
    end

    local function fleetPayload()
        if not FL._loaded then return nil end
        local arr = {}
        for id, unit in pairs(FL.Units) do
            if istable(unit) then unit.id = id arr[#arr + 1] = unit end
        end
        table.sort(arr, function(a, b) return tostring(a.id) < tostring(b.id) end)
        return { version = 1, units = arr }
    end

    local function writeJSON(path, tbl)
        ensureDir()
        local ok, txt = pcall(util.TableToJSON, tbl, true)
        if not ok or not isstring(txt) then return false end
        file.Write(path, txt)
        return file.Read(path, "DATA") == txt
    end

    function FL.SaveMarketNow()
        if not FL._loaded then return false end
        return writeJSON(MARKET_FILE, marketPayload())
    end
    function FL.SaveFleetNow()
        if not FL._loaded then return false end
        return writeJSON(fleetFile(), fleetPayload())
    end

    if GRM.Save and GRM.Save.Register then
        FL._marketSave = GRM.Save.Register("grm_fleet_market", {
            file = MARKET_FILE, delay = 3, label = "рынок техники", build = marketPayload })
        FL._fleetSave = GRM.Save.Register("grm_fleet_units", {
            file = fleetFile(), delay = 3, label = "автопарк", build = fleetPayload })
    end

    function FL.SaveMarket(why)
        if not FL._loaded then return false end
        if FL._marketSave and GRM.Save and GRM.Save.Mark then return GRM.Save.Mark("grm_fleet_market", why) end
        return FL.SaveMarketNow()
    end

    function FL.SaveFleet(why)
        if not FL._loaded then return false end
        if FL._fleetSave and GRM.Save and GRM.Save.Mark then return GRM.Save.Mark("grm_fleet_units", why) end
        return FL.SaveFleetNow()
    end

    local function readJSON(path)
        if not file.Exists(path, "DATA") then return nil end
        local raw = file.Read(path, "DATA") or ""
        local ok, t = pcall(util.JSONToTable, raw, false, true)
        return (ok and istable(t)) and t or nil
    end

    function FL.Load()
        FL.Market, FL.Units = {}, {}
        local m = readJSON(MARKET_FILE)
        for _, entry in ipairs(istable(m) and m.market or {}) do
            if istable(entry) and tostring(entry.id or "") ~= "" then
                FL.Market[tostring(entry.id)] = entry
            end
        end
        local f = readJSON(fleetFile())
        for _, unit in ipairs(istable(f) and f.units or {}) do
            if istable(unit) and tostring(unit.id or "") ~= "" then
                FL.Units[tostring(unit.id)] = unit
            end
        end
        FL._loaded = true
        return true
    end

    -- ── рынок (суперадмин) ──────────────────────────────────────────
    local function newID(prefix)
        return string.format("%s_%d_%03d", prefix, os.time(), math.random(0, 999))
    end

    function FL.MarketAdd(opts)
        opts = istable(opts) and opts or {}
        local class = trim(opts.class, 96)
        if class == "" then return nil, "Не указан класс транспорта" end
        local info = (GRM.VehicleDealer and GRM.VehicleDealer.VehicleInfo)
            and GRM.VehicleDealer.VehicleInfo(class) or { name = class, model = "" }
        local tier = tostring(opts.tier or "civil")
        if not FL.Tiers[tier] then tier = "civil" end

        local entry = {
            id = newID("mk"),
            class = class,
            name = trim(opts.name ~= nil and opts.name ~= "" and opts.name or info.name, 96),
            model = tostring(info.model or ""),
            price = math.max(0, math.floor(tonumber(opts.price) or 0)),
            tier = tier,
            kind = tostring(opts.kind or "government"),
            factions = istable(opts.factions) and opts.factions or {},
            limit = math.max(0, math.floor(tonumber(opts.limit) or 0)),
            category = trim(opts.category, 64),
            note = trim(opts.note, 160),
        }
        FL.Market[entry.id] = entry
        FL.SaveMarket("рынок: добавление")
        return entry
    end

    function FL.MarketUpdate(id, fields)
        local entry = FL.Entry(id)
        if not entry then return false, "Позиция не найдена" end
        fields = istable(fields) and fields or {}
        if fields.name ~= nil then entry.name = trim(fields.name, 96) end
        if fields.price ~= nil then entry.price = math.max(0, math.floor(tonumber(fields.price) or 0)) end
        if fields.limit ~= nil then entry.limit = math.max(0, math.floor(tonumber(fields.limit) or 0)) end
        if fields.tier ~= nil and FL.Tiers[tostring(fields.tier)] then entry.tier = tostring(fields.tier) end
        if fields.kind ~= nil then entry.kind = tostring(fields.kind) end
        if fields.category ~= nil then entry.category = trim(fields.category, 64) end
        if fields.note ~= nil then entry.note = trim(fields.note, 160) end
        if istable(fields.factions) then entry.factions = fields.factions end
        FL.SaveMarket("рынок: правка")
        return true
    end

    function FL.MarketRemove(id)
        if not FL.Entry(id) then return false, "Позиция не найдена" end
        FL.Market[tostring(id)] = nil
        FL.SaveMarket("рынок: удаление")
        return true
    end

    -- ── закупка ─────────────────────────────────────────────────────

    --- Купить count единиц позиции рынка в парк организации.
    function FL.Buy(ply, marketID, count, garageID)
        if not IsValid(ply) then return nil, "Игрок не найден" end
        local faction = factionOf(ply)
        if ply:IsSuperAdmin() and tostring(garageID or "") ~= "" then
            -- суперадмин может закупать для организации гаража
            local g = GRM.Garage and GRM.Garage.Get and GRM.Garage.Get(garageID) or nil
            if istable(g) and tostring(g.faction or "") ~= "" then faction = tostring(g.faction) end
        end
        local can, why = FL.CanBuy(ply, faction)
        if not can then return nil, why or "Нет права закупки" end

        local entry = FL.Entry(marketID)
        if not entry then return nil, "Позиция рынка не найдена" end

        local allowed, whyAllowed = FL.EntryAllowed(entry, faction, levelOf(ply), ply:IsSuperAdmin())
        if not allowed then return nil, whyAllowed end

        count = math.max(1, math.min(20, math.floor(tonumber(count) or 1)))
        local canTake, limitWhy = FL.CanOrder(entry, faction, count, FL.CountClass(faction, entry.class))
        if canTake <= 0 then return nil, limitWhy end
        count = canTake

        -- гараж приписки: обязателен, иначе технику негде выдавать
        local garage = GRM.Garage and GRM.Garage.Get and GRM.Garage.Get(garageID) or nil
        if not istable(garage) then return nil, "Выберите гараж, куда поставить технику" end
        if #(garage.slots or {}) == 0 then return nil, ("В гараже «%s» не размечено ни одного места"):format(garage.name) end
        if tostring(garage.kind) == "faction" and tostring(garage.faction or "") ~= faction and not ply:IsSuperAdmin() then
            return nil, "Этот гараж принадлежит другой организации"
        end

        local total, unitPrice = FL.OrderPrice(entry, count)
        if total > 0 then
            local budget = GRM.FactionBudgetGet and GRM.FactionBudgetGet(faction) or 0
            if budget < total then
                return nil, ("Не хватает бюджета: нужно %s, в казне организации %s"):format(
                    GRM.Format and GRM.Format(total) or total, GRM.Format and GRM.Format(budget) or budget)
            end
            if GRM.FactionBudgetAdd then GRM.FactionBudgetAdd(faction, -total, "закупка техники") end
            local share = math.Clamp(FL.StateShareCvar:GetInt(), 0, 100)
            if share > 0 and GRM.Economy and GRM.Economy.StateBudgetAdd then
                GRM.Economy.StateBudgetAdd(math.floor(total * share / 100), "продажа техники: " .. entry.name)
            end
        end

        local made = {}
        for _ = 1, count do
            local unit = {
                id = newID("fu"),
                faction = faction,
                class = entry.class,
                name = entry.name,
                model = entry.model,
                price = unitPrice,
                kind = entry.kind,
                garageID = garage.id,
                status = "stored",
                boughtBy = charKey(ply),
                boughtByName = ply:Nick(),
                boughtAt = os.time(),
                marketID = entry.id,
            }
            FL.Units[unit.id] = unit
            made[#made + 1] = unit
        end
        FL.SaveFleet("закупка техники")

        if GRM.Audit and GRM.Audit.Write then
            GRM.Audit.Write("fleet", "buy", ply, { faction = faction, class = entry.class },
                { count = count, total = total, garage = garage.id })
        end
        hook.Run("GRM_FleetBought", faction, entry, made, ply)
        return made, nil, total
    end

    --- Переприписать единицу к другому гаражу.
    function FL.SetGarage(ply, unitID, garageID)
        local unit = FL.Unit(unitID)
        if not unit then return false, "Единица не найдена" end
        if not FL.CanManage(ply, unit.faction) then return false, "Нет права распоряжаться парком" end
        local garage = GRM.Garage and GRM.Garage.Get and GRM.Garage.Get(garageID) or nil
        if not istable(garage) then return false, "Гараж не найден" end
        if IsValid(FL.Active[unit.id]) then return false, "Сначала верните машину в гараж" end
        unit.garageID = garage.id
        FL.SaveFleet("приписка техники")
        return true, ("Техника приписана к гаражу «%s»"):format(garage.name)
    end

    --- Списать единицу с возвратом части стоимости в бюджет организации.
    function FL.Scrap(ply, unitID)
        local unit = FL.Unit(unitID)
        if not unit then return false, "Единица не найдена" end
        if not FL.CanManage(ply, unit.faction) then return false, "Нет права списывать технику" end
        if IsValid(FL.Active[unit.id]) then return false, "Машина на линии — сначала верните её в гараж" end

        local rate = math.Clamp(FL.ScrapCvar:GetInt(), 0, 100)
        local payout = math.floor((tonumber(unit.price) or 0) * rate / 100)
        if payout > 0 and GRM.FactionBudgetAdd then
            GRM.FactionBudgetAdd(unit.faction, payout, "списание техники")
        end
        unit.status = "scrap"
        unit.scrappedAt = os.time()
        FL.SaveFleet("списание техники")
        if GRM.Audit and GRM.Audit.Write then
            GRM.Audit.Write("fleet", "scrap", ply, { unit = unit.id, faction = unit.faction }, { payout = payout })
        end
        return true, ("Техника списана. Возврат в бюджет: %s"):format(GRM.Format and GRM.Format(payout) or payout)
    end

    -- ── выдача из гаража ────────────────────────────────────────────

    --- Выдать единицу парка на свободное место её гаража.
    function FL.Issue(ply, unitID, garage)
        local unit = FL.Unit(unitID)
        if not unit then return nil, "Единица не найдена" end
        if unit.status == "scrap" then return nil, "Эта машина списана" end
        if not FL.CanUse(ply, unit.faction) then return nil, "Это техника другой организации" end
        local allowed, whyRole = FL.UnitAllowedFor(unit, FL.ActorOf(ply))
        if not allowed then return nil, whyRole or "Техника закреплена за другими должностями" end
        if IsValid(FL.Active[unit.id]) then return nil, "Машина уже выдана" end

        local G = GRM.Garage
        garage = garage or (G and G.Get and G.Get(unit.garageID))
        if not istable(garage) then return nil, "Гараж приписки не найден" end
        if tostring(unit.garageID or "") ~= "" and tostring(garage.id) ~= tostring(unit.garageID) then
            return nil, ("Эта машина приписана к другому гаражу")
        end

        local place, slotErr = G and G.FreeSlot and G.FreeSlot(garage, ply) or nil
        if not place then return nil, slotErr or "Нет свободного места в гараже" end

        local VD = GRM.VehicleDealer
        if not (VD and VD.Spawn) then return nil, "Модуль транспорта не загружен" end
        local ent, _, spawnErrors = VD.Spawn(unit.class, nil, ply, place)
        if not IsValid(ent) then return nil, (spawnErrors and spawnErrors[1]) or "Не удалось выдать технику" end

        ent.GRMFleetUnit = unit.id
        ent.GRMFleetFaction = unit.faction
        ent.GRMGarageOwner = ply
        if VD.TagVehicle then VD.TagVehicle(ent, ply, unit.class, tostring(unit.kind or "government"), unit) end
        ent:SetNWString("GRM_FleetFaction", tostring(unit.faction))
        FL.Active[unit.id] = ent
        unit.status = "active"
        unit.lastUser = charKey(ply)
        unit.lastUserName = ply:Nick()
        unit.lastOut = os.time()
        FL.SaveFleet("выдача техники")

        hook.Run("GRM_FleetIssued", ply, ent, unit, garage)
        return ent
    end

    --- Вернуть единицу в гараж.
    function FL.Store(ply, unitID)
        local unit = FL.Unit(unitID)
        if not unit then return false, "Единица не найдена" end
        if not FL.CanUse(ply, unit.faction) then return false, "Это техника другой организации" end
        local ent = FL.Active[unit.id]
        if not IsValid(ent) then
            unit.status = "stored"
            FL.SaveFleet("возврат техники")
            return true, "Машина уже не на карте — запись обновлена"
        end
        local driver = ent.GetDriver and ent:GetDriver() or nil
        if IsValid(driver) and driver ~= ply then return false, "В машине сидит водитель" end
        ent:Remove()
        FL.Active[unit.id] = nil
        unit.status = "stored"
        unit.lastIn = os.time()
        FL.SaveFleet("возврат техники")
        hook.Run("GRM_FleetStored", ply, unit)
        return true, "Техника возвращена в гараж"
    end

    -- машину уничтожили/убрали мимо системы — не держим «призрак» выданной
    hook.Add("EntityRemoved", "GRM_Fleet_Track", function(ent)
        local id = IsValid(ent) and ent.GRMFleetUnit or nil
        if not id then return end
        if FL.Active[id] == ent then
            FL.Active[id] = nil
            local unit = FL.Unit(id)
            if unit and unit.status ~= "scrap" then
                unit.status = "stored"
                FL.SaveFleet("машина покинула карту")
            end
        end
    end)

    -- ── сеть ────────────────────────────────────────────────────────
    local function packEntry(entry, faction, level, isAdmin)
        local allowed, why = FL.EntryAllowed(entry, faction, level, isAdmin)
        return {
            id = entry.id, class = entry.class, name = entry.name, model = entry.model,
            price = entry.price, tier = entry.tier, tierName = FL.TierName(entry.tier),
            kind = entry.kind, limit = entry.limit, category = entry.category, note = entry.note,
            factions = entry.factions or {},
            allowed = allowed == true, reason = allowed and "" or tostring(why or ""),
            owned = FL.CountClass(faction, entry.class),
        }
    end

    local function packUnit(unit)
        local garage = GRM.Garage and GRM.Garage.Get and GRM.Garage.Get(unit.garageID) or nil
        return {
            id = unit.id, class = unit.class, name = unit.name, model = unit.model,
            price = unit.price, status = unit.status, statusName = FL.UnitStatuses[unit.status] or unit.status,
            garageID = unit.garageID, garageName = garage and garage.name or "",
            onMap = IsValid(FL.Active[unit.id]),
            boughtByName = unit.boughtByName, boughtAt = unit.boughtAt,
            lastUserName = unit.lastUserName or "",
            roles = istable(unit.roles) and unit.roles or {},
            depts = istable(unit.depts) and unit.depts or {},
            restriction = FL.RestrictionText(unit),
            -- номер закреплён за конкретной единицей техники (UID автопарка)
            plate = (GRM.Plates and GRM.Plates.PlateOfVehicleKey)
                and tostring(GRM.Plates.PlateOfVehicleKey("fleet:" .. tostring(unit.id)) or "") or "",
        }
    end

    local function garageChoices(ply, faction)
        local out = {}
        local G = GRM.Garage
        if not (G and G.List) then return out end
        for _, rec in ipairs(G.List()) do
            local kind = tostring(rec.kind or "public")
            local mine = (kind == "faction" and tostring(rec.faction or "") == faction)
            if ply:IsSuperAdmin() or mine or kind == "public" then
                out[#out + 1] = {
                    id = rec.id, name = rec.name, kind = kind, kindName = G.KindName and G.KindName(kind) or kind,
                    faction = rec.faction or "", slots = #(rec.slots or {}),
                    units = #FL.UnitsInGarage(rec.id, faction),
                    mine = mine,
                }
            end
        end
        table.sort(out, function(a, b)
            if a.mine ~= b.mine then return a.mine end
            return tostring(a.name) < tostring(b.name)
        end)
        return out
    end

    --- Должности и отделы организации — чтобы закрепление выбиралось из
    --  списка, а не набиралось руками (опечатка = машина никому не доступна).
    function FL.StructureOf(faction)
        local out = { roles = {}, depts = {} }
        local f = _G.Factions and _G.Factions[tostring(faction or "")] or nil
        if not istable(f) then return out end
        for _, r in ipairs(istable(f.Roles) and f.Roles or {}) do
            local disp = istable(f.RoleDisplayNames) and f.RoleDisplayNames[r] or nil
            out.roles[#out.roles + 1] = { key = tostring(r), name = tostring(disp ~= nil and disp ~= "" and disp or r) }
        end
        for _, d in ipairs(istable(f.Departments) and f.Departments or {}) do
            local disp = istable(f.DepartmentDisplayNames) and f.DepartmentDisplayNames[d] or nil
            out.depts[#out.depts + 1] = { key = tostring(d), name = tostring(disp ~= nil and disp ~= "" and disp or d) }
        end
        if istable(f.Subdepartments) then
            for key, sub in pairs(f.Subdepartments) do
                if istable(sub) then
                    out.depts[#out.depts + 1] = { key = tostring(key), name = tostring(sub.name or key) .. " (подотдел)" }
                end
            end
        end
        return out
    end

    --[[ Снимок автопарка тоже уходит порциями: рынок, парк, список гаражей
         и структура организации в одном пакете давали заметный кусок
         трафика на каждое действие. GRM.Net.Stream режет его по кадрам, а
         GRM.Perf.Coalesce схлопывает серию действий в одну отправку. ]]
    local function snapshot(ply)
        local faction = factionOf(ply)
        local level = levelOf(ply)
        local isAdmin = ply:IsSuperAdmin()

        local market = {}
        for _, entry in ipairs(FL.MarketList()) do market[#market + 1] = packEntry(entry, faction, level, isAdmin) end
        local units = {}
        for _, unit in ipairs(FL.UnitsOf(faction)) do units[#units + 1] = packUnit(unit) end

        return {
            faction = faction,
            budget = math.max(0, math.floor(GRM.FactionBudgetGet and GRM.FactionBudgetGet(faction) or 0)),
            canBuy = select(1, FL.CanBuy(ply, faction)) == true,
            canManage = FL.CanManage(ply, faction) == true,
            isAdmin = isAdmin,
            market = market, units = units,
            garages = garageChoices(ply, faction),
            factions = (GRM.VehicleDealer and GRM.VehicleDealer.FactionList) and GRM.VehicleDealer.FactionList() or {},
            structure = FL.StructureOf(faction),
        }
    end

    function FL.Push(ply)
        if not IsValid(ply) then return end
        local data = snapshot(ply)
        if GRM.Net and GRM.Net.Stream then
            GRM.Net.Stream(FL.Net.SYNC, data, ply, { chunk = 8192, interval = 0.03 })
            return
        end
        net.Start(FL.Net.SYNC)
            net.WriteString(data.faction)
            net.WriteUInt(data.budget, 32)
            net.WriteBool(data.canBuy)
            net.WriteBool(data.canManage)
            net.WriteBool(data.isAdmin)
            net.WriteTable(data.market)
            net.WriteTable(data.units)
            net.WriteTable(data.garages)
            net.WriteTable(data.factions)
            net.WriteTable(data.structure)
        net.Send(ply)
    end

    --- Пачка действий подряд = одна отправка снимка.
    function FL.PushSoon(ply)
        if not IsValid(ply) then return end
        if not (GRM.Perf and GRM.Perf.Coalesce) then return FL.Push(ply) end
        GRM.Perf.Coalesce("fleet.push." .. tostring(ply:SteamID64() or ply:EntIndex()), function()
            if IsValid(ply) then FL.Push(ply) end
        end, 0.15)
    end

    function FL.Open(ply)
        if not IsValid(ply) then return end
        net.Start(FL.Net.OPEN) net.Send(ply)
        FL.Push(ply)
    end

    net.Receive(FL.Net.ACT, function(_, ply)
        if not IsValid(ply) then return end
        ply.GRMFleetNext = ply.GRMFleetNext or 0
        if CurTime() < ply.GRMFleetNext then return end
        ply.GRMFleetNext = CurTime() + 0.35

        local act = net.ReadString()
        local data = net.ReadTable() or {}

        if act == "refresh" then
            FL.PushSoon(ply)

        elseif act == "buy" then
            local made, err, total = FL.Buy(ply, data.marketID, data.count, data.garageID)
            if not made then notify(ply, tostring(err or "Закупка не прошла")) FL.Push(ply) return end
            notify(ply, ("Закуплено единиц: %d на сумму %s. Техника в гараже."):format(#made,
                GRM.Format and GRM.Format(total or 0) or tostring(total or 0)), true)
            FL.PushSoon(ply)

        elseif act == "issue" then
            local ent, err = FL.Issue(ply, data.unitID)
            notify(ply, IsValid(ent) and "Техника подана на место стоянки." or tostring(err or "Не удалось выдать"), IsValid(ent))
            FL.PushSoon(ply)

        elseif act == "store" then
            local ok, msg = FL.Store(ply, data.unitID)
            notify(ply, tostring(msg or (ok and "Возвращено" or "Не удалось")), ok)
            FL.PushSoon(ply)

        elseif act == "sethome" then
            local ok, msg = FL.SetGarage(ply, data.unitID, data.garageID)
            notify(ply, tostring(msg or (ok and "Приписано" or "Не удалось")), ok)
            FL.PushSoon(ply)

        elseif act == "restrict" then
            local ok, msg = FL.SetRestriction(ply, data.unitID, data.roles, data.depts)
            notify(ply, tostring(msg or (ok and "Закрепление обновлено" or "Не удалось")), ok)
            FL.PushSoon(ply)

        elseif act == "scrap" then
            local ok, msg = FL.Scrap(ply, data.unitID)
            notify(ply, tostring(msg or (ok and "Списано" or "Не удалось")), ok)
            FL.PushSoon(ply)

        elseif act == "market_add" then
            if not ply:IsSuperAdmin() then return end
            local entry, err = FL.MarketAdd(data)
            notify(ply, entry and ("Позиция добавлена: " .. entry.name) or tostring(err), entry ~= nil)
            FL.PushSoon(ply)

        elseif act == "market_update" then
            if not ply:IsSuperAdmin() then return end
            local ok, err = FL.MarketUpdate(data.id, data)
            notify(ply, ok and "Позиция обновлена" or tostring(err), ok)
            FL.PushSoon(ply)

        elseif act == "market_remove" then
            if not ply:IsSuperAdmin() then return end
            local ok, err = FL.MarketRemove(data.id)
            notify(ply, ok and "Позиция убрана с рынка" or tostring(err), ok)
            FL.PushSoon(ply)
        end
    end)

    -- ── команды ─────────────────────────────────────────────────────
    local function chatCommand(ply, text)
        local low = string.lower(string.Trim(tostring(text or "")))
        if low == "/автопарк" or low == "/fleet" or low == "/закупка" then
            FL.Open(ply)
            return true
        end
        return false
    end

    hook.Add("PlayerSay", "GRM_Fleet_Chat", function(ply, text)
        if chatCommand(ply, text) then return "" end
    end)
    hook.Add("PlayerSayTransform", "GRM_Fleet_ChatT", function(ply, pack)
        if not istable(pack) or not isstring(pack[1]) then return end
        if chatCommand(ply, pack[1]) then pack[1] = "" pack.SkipPlayerSay = true end
    end)
    concommand.Add("grm_fleet", function(ply) FL.Open(ply) end)

    local function boot()
        FL.Load()
        print(("[GRM Fleet] рынок: %d позиций, парк: %d единиц"):format(
            table.Count(FL.Market), table.Count(FL.Units)))
    end
    -- читаем сразу: до загрузки запись заблокирована
    boot()
    if GRM.Boot and GRM.Boot.OnMapStart then
        GRM.Boot.OnMapStart("GRM_Fleet_Load", "normal", boot)
    else
        hook.Add("InitPostEntity", "GRM_Fleet_Load", boot)
    end
end

if CLIENT then

    surface.CreateFont("GRMFleet_Title", { font = "Roboto", size = 21, weight = 800, extended = true })
    surface.CreateFont("GRMFleet_Sub",   { font = "Roboto", size = 15, weight = 700, extended = true })
    surface.CreateFont("GRMFleet_Body",  { font = "Roboto", size = 14, weight = 500, extended = true })
    surface.CreateFont("GRMFleet_Small", { font = "Roboto", size = 11, weight = 400, extended = true })

    local C = {
        bg      = Color(16, 20, 28, 252),
        card    = Color(22, 28, 38, 240),
        cardHov = Color(32, 42, 56, 240),
        border  = Color(38, 48, 66, 200),
        accent  = Color(65, 145, 235),
        green   = Color(55, 185, 110),
        gold    = Color(245, 195, 65),
        red     = Color(225, 70, 70),
        text    = Color(240, 244, 250),
        dim     = Color(155, 170, 190),
    }

    FL.State = FL.State or { market = {}, units = {}, garages = {}, factions = {}, structure = { roles = {}, depts = {} },
        faction = "", budget = 0, canBuy = false, canManage = false, isAdmin = false }

    local function money(n) return GRM.Format and GRM.Format(n) or (tostring(n) .. " GRM") end

    local function act(name, data)
        net.Start(FL.Net.ACT)
        net.WriteString(tostring(name))
        net.WriteTable(istable(data) and data or {})
        net.SendToServer()
    end
    FL.Act = act

    local function button(parent, label, base, onClick)
        local b = vgui.Create("DButton", parent)
        b:SetText("")
        b.Paint = function(self, w, h)
            local col = base
            if not self:IsEnabled() then col = Color(38, 44, 56)
            elseif self:IsHovered() then col = Color(math.min(255, col.r + 24), math.min(255, col.g + 24), math.min(255, col.b + 24)) end
            draw.RoundedBox(6, 0, 0, w, h, col)
            draw.SimpleText(label, "GRMFleet_Body", w / 2, h / 2, self:IsEnabled() and C.text or C.dim,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function() if onClick then onClick() end end
        return b
    end

    local function combo(parent, w)
        local c = vgui.Create("DComboBox", parent)
        c:SetFont("GRMFleet_Body")
        c:SetTextColor(C.text)
        if w then c:SetWide(w) end
        c.Paint = function(_, pw, ph)
            draw.RoundedBox(6, 0, 0, pw, ph, Color(18, 23, 32))
            surface.SetDrawColor(C.border) surface.DrawOutlinedRect(0, 0, pw, ph, 1)
        end
        return c
    end

    local function entry(parent, placeholder)
        local e = vgui.Create("DTextEntry", parent)
        e:SetFont("GRMFleet_Body")
        e:SetPlaceholderText(placeholder or "")
        --[[ Со своим Paint GMod НЕ рисует подсказку поля: у окна получались
             безымянные пустые прямоугольники (заказ владельца 21.08).
             Рисуем подсказку сами, пока поле пустое и не в фокусе. ]]
        e.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(18, 23, 32))
            surface.SetDrawColor(C.border) surface.DrawOutlinedRect(0, 0, w, h, 1)
            if (self:GetText() or "") == "" and not self:HasFocus() then
                draw.SimpleText(placeholder or "", "GRMFleet_Small", 8, h / 2, C.dim,
                    TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            self:DrawTextEntryText(C.text, C.accent, C.text)
        end
        return e
    end

    --- Раздел «Автопарк» — общий для окна и вкладки терминала.
    function FL.BuildPanel(parent)
        parent:DockPadding(10, 10, 10, 10)

        local sheet = vgui.Create("DPropertySheet", parent)
        sheet:Dock(FILL)
        sheet.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, Color(18, 23, 32, 240)) end

        local buyPnl = vgui.Create("DPanel", sheet)
        buyPnl:SetPaintBackground(false)
        local parkPnl = vgui.Create("DPanel", sheet)
        parkPnl:SetPaintBackground(false)
        local adminPnl = vgui.Create("DPanel", sheet)
        adminPnl:SetPaintBackground(false)

        sheet:AddSheet("Закупка", buyPnl, "icon16/cart.png")
        sheet:AddSheet("Автопарк организации", parkPnl, "icon16/lorry.png")
        if FL.State.isAdmin then sheet:AddSheet("Рынок (суперадмин)", adminPnl, "icon16/wrench.png") end

        local rebuild

        -- ── ЗАКУПКА ────────────────────────────────────────────────
        local function buildBuy()
            buyPnl:Clear()
            local head = vgui.Create("DPanel", buyPnl)
            head:Dock(TOP) head:SetTall(52) head:DockMargin(0, 0, 0, 8)
            head.Paint = function(_, w, h)
                draw.RoundedBox(8, 0, 0, w, h, C.card)
                draw.SimpleText(("Организация: %s"):format(FL.State.faction ~= "" and FL.State.faction or "—"),
                    "GRMFleet_Sub", 14, 12, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(("Бюджет: %s   •   %s"):format(money(FL.State.budget),
                    FL.State.canBuy and "у вас есть право закупки" or "закупка доступна руководству"),
                    "GRMFleet_Small", 14, 32, FL.State.canBuy and C.green or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            local bar = vgui.Create("DPanel", buyPnl)
            bar:Dock(TOP) bar:SetTall(44) bar:DockMargin(0, 0, 0, 8)
            bar.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, C.card) end

            bar:SetTall(64)
            local barTitle = bar.Paint
            bar.Paint = function(self, w, h)
                if barTitle then barTitle(self, w, h) end
                draw.SimpleText("ГАРАЖ ПРИПИСКИ", "GRMFleet_Small", 12, 6, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("СКОЛЬКО ЕДИНИЦ", "GRMFleet_Small", 342, 6, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            local garageCombo = combo(bar)
            garageCombo:Dock(LEFT) garageCombo:SetWide(320) garageCombo:DockMargin(10, 24, 8, 8)
            garageCombo:SetValue("Гараж приписки...")
            local pickedGarage = ""
            for _, g in ipairs(FL.State.garages) do
                local label = ("%s — %s, мест %d, техники %d"):format(g.name, g.kindName or g.kind, g.slots or 0, g.units or 0)
                garageCombo:AddChoice(label, g.id, g.mine)
                if g.mine and pickedGarage == "" then pickedGarage = g.id end
            end
            garageCombo.OnSelect = function(_, _, _, val) pickedGarage = tostring(val or "") end

            local countEntry = entry(bar, "Сколько единиц")
            countEntry:Dock(LEFT) countEntry:SetWide(140) countEntry:DockMargin(0, 24, 8, 8)
            countEntry:SetValue("1")

            local refresh = button(bar, "Обновить", C.cardHov, function() act("refresh") end)
            refresh:Dock(RIGHT) refresh:SetWide(130) refresh:DockMargin(8, 24, 10, 8)

            local list = vgui.Create("DScrollPanel", buyPnl)
            list:Dock(FILL)

            for _, e in ipairs(FL.State.market) do
                local card = vgui.Create("DPanel", list)
                card:Dock(TOP) card:SetTall(76) card:DockMargin(0, 0, 4, 6)
                card.Paint = function(self, w, h)
                    draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and C.cardHov or C.card)
                    surface.SetDrawColor(C.border) surface.DrawOutlinedRect(0, 0, w, h, 1)
                    draw.SimpleText(e.name, "GRMFleet_Sub", 14, 10, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText(("%s  •  %s"):format(e.tierName or "", e.class), "GRMFleet_Small", 14, 32, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    local limitTxt = (tonumber(e.limit) or 0) > 0 and ("в парке %d из %d"):format(e.owned or 0, e.limit)
                        or ("в парке %d"):format(e.owned or 0)
                    draw.SimpleText(limitTxt, "GRMFleet_Small", 14, 52, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText(money(e.price), "GRMFleet_Sub", w - 200, h / 2, C.gold, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    if not e.allowed then
                        draw.SimpleText(e.reason ~= "" and e.reason or "недоступно", "GRMFleet_Small",
                            w - 200, h - 18, C.red, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end
                end

                local buy = button(card, "ЗАКУПИТЬ", C.green, function()
                    local n = math.max(1, math.floor(tonumber(countEntry:GetValue()) or 1))
                    if pickedGarage == "" then
                        notification.AddLegacy("Выберите гараж приписки", NOTIFY_ERROR, 3)
                        return
                    end
                    Derma_Query(("Закупить %d ед. «%s» на сумму %s?\nДеньги спишутся с бюджета организации."):format(
                            n, e.name, money((tonumber(e.price) or 0) * n)),
                        "Закупка техники", "Закупить",
                        function() act("buy", { marketID = e.id, count = n, garageID = pickedGarage }) end,
                        "Отмена")
                end)
                buy:Dock(RIGHT) buy:SetWide(170) buy:DockMargin(6, 20, 12, 20)
                buy:SetEnabled(e.allowed and FL.State.canBuy)
            end

            if #FL.State.market == 0 then
                local empty = vgui.Create("DPanel", list)
                empty:Dock(TOP) empty:SetTall(70)
                empty.Paint = function(_, w, h)
                    draw.RoundedBox(8, 0, 0, w, h, C.card)
                    draw.SimpleText("Рынок пуст — суперадмин ещё не собрал каталог закупок.",
                        "GRMFleet_Body", w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end

        -- ── ПАРК ───────────────────────────────────────────────────
        local function buildPark()
            parkPnl:Clear()
            local list = vgui.Create("DScrollPanel", parkPnl)
            list:Dock(FILL)

            if #FL.State.units == 0 then
                local empty = vgui.Create("DPanel", list)
                empty:Dock(TOP) empty:SetTall(70)
                empty.Paint = function(_, w, h)
                    draw.RoundedBox(8, 0, 0, w, h, C.card)
                    draw.SimpleText("В автопарке пока пусто — закупите технику на вкладке «Закупка».",
                        "GRMFleet_Body", w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end

            --[[ Автопарк показываем такими же ячейками, как личный
                 транспорт у дилера и в гараже (общий слой GRM.VehicleCells):
                 одна карточка на весь сервер, без разнобоя. ]]
            local VC = GRM.VehicleCells
            local grid = (VC and #FL.State.units > 0) and VC.Grid(list) or nil
            for _, u in ipairs(FL.State.units) do
                if grid then
                    local menu = {}
                    if FL.State.canManage then
                        --[[ КОМУ ПОЛОЖЕНА МАШИНА: список структуры организации,
                             ключи руками не набираются — опечатка невозможна. ]]
                        menu[#menu + 1] = { label = "Доступна всем сотрудникам", icon = "icon16/group.png",
                            fn = function() act("restrict", { unitID = u.id, roles = {}, depts = {} }) end }
                        local st = FL.State.structure or {}
                        for _, r in ipairs(st.roles or {}) do
                            menu[#menu + 1] = { label = "Закрепить за должностью: " .. tostring(r.name),
                                icon = "icon16/user.png",
                                fn = function() act("restrict", { unitID = u.id, roles = { r.key }, depts = {} }) end }
                        end
                        for _, d in ipairs(st.depts or {}) do
                            menu[#menu + 1] = { label = "Закрепить за отделом: " .. tostring(d.name),
                                icon = "icon16/group_gear.png",
                                fn = function() act("restrict", { unitID = u.id, roles = {}, depts = { d.key } }) end }
                        end
                        menu[#menu + 1] = { label = "СПИСАТЬ с баланса", icon = "icon16/car_delete.png",
                            fn = function()
                                Derma_Query(("Списать «%s» с баланса организации?"):format(u.name), "Автопарк",
                                    "Списать", function() act("scrap", { unitID = u.id }) end, "Отмена")
                            end }
                    end

                    VC.Cell(grid, {
                        name = u.name, class = u.class, model = u.model, plate = u.plate,
                        accent = C.gold,
                        state = { text = tostring(u.statusName or (u.onMap and "на линии" or "в гараже")),
                                  good = not u.onMap },
                        lines = {
                            { text = ("Гараж: %s"):format((u.garageName or "") ~= "" and u.garageName or "не приписана"),
                              color = (u.garageName or "") ~= "" and C.dim or C.gold },
                            { text = (u.restriction or "") ~= "" and u.restriction or "Доступна всем сотрудникам",
                              color = (#(u.roles or {}) > 0 or #(u.depts or {}) > 0) and C.gold or C.dim },
                            { text = (u.lastUserName or "") ~= "" and ("Последний водитель: " .. u.lastUserName) or "",
                              color = C.dim },
                        },
                        buttons = {
                            { label = u.onMap and "ВЕРНУТЬ В ГАРАЖ" or "ВЫДАТЬ",
                              color = u.onMap and C.accent or C.green,
                              fn = function() act(u.onMap and "store" or "issue", { unitID = u.id }) end },
                            FL.State.canManage and { label = "ДОСТУП И СПИСАНИЕ (ПКМ)", color = C.cardHov,
                              fn = function()
                                  local m = DermaMenu()
                                  for _, item in ipairs(menu) do
                                      local opt = m:AddOption(item.label, item.fn)
                                      if item.icon then opt:SetIcon(item.icon) end
                                  end
                                  m:Open()
                              end } or nil,
                        },
                        menu = menu,
                    })
                end
            end
        end

        -- ── РЫНОК (суперадмин) ─────────────────────────────────────
        local function buildAdmin()
            adminPnl:Clear()
            if not FL.State.isAdmin then return end

            local form = vgui.Create("DPanel", adminPnl)
            form:Dock(TOP) form:SetTall(164) form:DockMargin(0, 0, 0, 8)
            --[[ Каждое поле подписано ЯВНО: раньше в окне стояли четыре
                 безымянных прямоугольника, и понять, куда что вводить, было
                 нельзя (заказ владельца 21.08). ]]
            form.Paint = function(_, w, h)
                draw.RoundedBox(8, 0, 0, w, h, C.card)
                draw.SimpleText("ДОБАВИТЬ ПОЗИЦИЮ НА РЫНОК", "GRMFleet_Sub", 14, 10, C.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("Класс берётся из установленных на сервере машин; лимит 0 — без предела",
                    "GRMFleet_Small", 14, 32, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("КЛАСС ТРАНСПОРТА", "GRMFleet_Small", 14, 56, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("НАЗВАНИЕ В КАТАЛОГЕ", "GRMFleet_Small", 322, 56, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("ЦЕНА ЗА ЕДИНИЦУ", "GRMFleet_Small", 570, 56, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("ЛИМИТ НА ОРГАНИЗАЦИЮ", "GRMFleet_Small", 728, 56, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("УРОВЕНЬ ДОПУСКА", "GRMFleet_Small", 14, 104, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("КОМУ ПРОДАЁМ", "GRMFleet_Small", 322, 104, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            local classEntry = entry(form, "например simfphys_uaz")
            classEntry:SetPos(14, 72) classEntry:SetSize(300, 28)
            local nameEntry = entry(form, "Патрульный УАЗ")
            nameEntry:SetPos(322, 72) nameEntry:SetSize(240, 28)
            local priceEntry = entry(form, "50000")
            priceEntry:SetPos(570, 72) priceEntry:SetSize(150, 28)
            local limitEntry = entry(form, "0 — без предела")
            limitEntry:SetPos(728, 72) limitEntry:SetSize(170, 28)

            local tierCombo = combo(form)
            tierCombo:SetPos(14, 120) tierCombo:SetSize(300, 28)
            local pickedTier = "civil"
            for _, t in ipairs(FL.TierList()) do tierCombo:AddChoice(t.name, t.key, t.key == "civil") end
            tierCombo.OnSelect = function(_, _, _, val) pickedTier = tostring(val or "civil") end

            local facCombo = combo(form)
            facCombo:SetPos(322, 120) facCombo:SetSize(240, 28)
            facCombo:AddChoice("Все организации по уровню", "", true)
            for _, f in ipairs(FL.State.factions) do
                facCombo:AddChoice(tostring(f.display or f.name or f), tostring(f.name or f))
            end
            local pickedFaction = ""
            facCombo.OnSelect = function(_, _, _, val) pickedFaction = tostring(val or "") end

            local addBtn = button(form, "ДОБАВИТЬ", C.green, function()
                act("market_add", {
                    class = classEntry:GetValue(), name = nameEntry:GetValue(),
                    price = tonumber(priceEntry:GetValue()) or 0,
                    limit = tonumber(limitEntry:GetValue()) or 0,
                    tier = pickedTier,
                    factions = pickedFaction ~= "" and { pickedFaction } or {},
                })
            end)
            addBtn:SetPos(570, 120) addBtn:SetSize(328, 28)

            local list = vgui.Create("DScrollPanel", adminPnl)
            list:Dock(FILL)
            for _, e in ipairs(FL.State.market) do
                local row = vgui.Create("DPanel", list)
                row:Dock(TOP) row:SetTall(58) row:DockMargin(0, 0, 4, 6)
                row.Paint = function(_, w, h)
                    draw.RoundedBox(8, 0, 0, w, h, C.card)
                    draw.SimpleText(("%s  —  %s"):format(e.name, money(e.price)), "GRMFleet_Body", 14, 10, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    local who = (#(e.factions or {}) > 0) and ("только: " .. table.concat(e.factions, ", ")) or e.tierName
                    draw.SimpleText(("%s  •  %s  •  лимит %s"):format(e.class, who,
                        (tonumber(e.limit) or 0) > 0 and e.limit or "нет"),
                        "GRMFleet_Small", 14, 32, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end
                local del = button(row, "УБРАТЬ", C.red, function() act("market_remove", { id = e.id }) end)
                del:Dock(RIGHT) del:SetWide(130) del:DockMargin(6, 12, 12, 12)

                local priceBtn = button(row, "ЦЕНА", C.cardHov, function()
                    Derma_StringRequest("Рынок закупок", "Новая цена для «" .. e.name .. "»", tostring(e.price),
                        function(val) act("market_update", { id = e.id, price = tonumber(val) or e.price }) end)
                end)
                priceBtn:Dock(RIGHT) priceBtn:SetWide(120) priceBtn:DockMargin(6, 12, 0, 12)
            end
        end

        rebuild = function()
            buildBuy()
            buildPark()
            buildAdmin()
        end
        rebuild()
        FL._rebuild = rebuild
        parent.OnRemove = function() if FL._rebuild == rebuild then FL._rebuild = nil end end
        return rebuild
    end

    function FL.AttachTab(sheetPanel)
        if not IsValid(sheetPanel) then return end
        local pnl = vgui.Create("DPanel", sheetPanel)
        pnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(20, 26, 36, 245)) end
        FL.BuildPanel(pnl)
        sheetPanel:AddSheet("Автопарк", pnl, "icon16/lorry_add.png")
        act("refresh")
        return pnl
    end

    local function applyState(data)
        if not istable(data) then return end
        FL.State.faction = tostring(data.faction or "")
        FL.State.budget = tonumber(data.budget) or 0
        FL.State.canBuy = data.canBuy == true
        FL.State.canManage = data.canManage == true
        FL.State.isAdmin = data.isAdmin == true
        FL.State.market = istable(data.market) and data.market or {}
        FL.State.units = istable(data.units) and data.units or {}
        FL.State.garages = istable(data.garages) and data.garages or {}
        FL.State.factions = istable(data.factions) and data.factions or {}
        FL.State.structure = istable(data.structure) and data.structure or { roles = {}, depts = {} }
        if FL._rebuild then FL._rebuild() end
    end

    if GRM.Net and GRM.Net.Receive then
        GRM.Net.Receive(FL.Net.SYNC, applyState)
    end

    net.Receive(FL.Net.SYNC, function()
        applyState({
            faction = net.ReadString(), budget = net.ReadUInt(32),
            canBuy = net.ReadBool(), canManage = net.ReadBool(), isAdmin = net.ReadBool(),
            market = net.ReadTable(), units = net.ReadTable(), garages = net.ReadTable(),
            factions = net.ReadTable(), structure = net.ReadTable(),
        })
    end)

    net.Receive(FL.Net.OPEN, function()
        if IsValid(FL._frame) then FL._frame:Remove() end
        local f = vgui.Create("DFrame")
        f:SetSize(math.Clamp(ScrW() * 0.7, 1000, 1400), math.Clamp(ScrH() * 0.74, 640, 900))
        f:Center() f:SetTitle("") f:ShowCloseButton(false) f:MakePopup()
        FL._frame = f
        if GRM.UI and GRM.UI.Track then GRM.UI.Track("grm_fleet", f) end
        f.Paint = function(_, w, h)
            draw.RoundedBox(10, 0, 0, w, h, C.bg)
            draw.RoundedBoxEx(10, 0, 0, w, 48, Color(22, 28, 40), true, true, false, false)
            draw.RoundedBox(0, 0, 48, w, 2, C.accent)
            draw.SimpleText("АВТОПАРК ОРГАНИЗАЦИИ · ЗАКУПКА ТЕХНИКИ", "GRMFleet_Title", 18, 16, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("/автопарк  •  техника закупается в парк и выдаётся в гараже по местам стоянки",
                "GRMFleet_Small", 18, 32, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        local close = button(f, "✕", C.red, function() f:Remove() end)
        close:SetSize(32, 28) close:SetPos(f:GetWide() - 42, 10)

        local body = vgui.Create("DPanel", f)
        body:Dock(FILL) body:DockMargin(6, 52, 6, 6) body:SetPaintBackground(false)
        FL.BuildPanel(body)
    end)
end

print("[GRM Fleet] v" .. FL.Version .. " loaded (" .. (SERVER and "Server" or "Client") .. ")")
