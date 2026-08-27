--[[--------------------------------------------------------------------
    GRM Estate & Business v1.0.0 — ядро зон (фаза 2).

    ЗАЧЕМ. Автоматы, колонки и помещения жили тремя несвязанными
    системами. Игрок не мог ответить «чем я владею и сколько это
    приносит», а на карте не было видно ни свободных объектов, ни
    чужого бизнеса.

    ЧТО ЭТО. Надстройка над готовым GRM.Property — оно уже умеет зоны,
    владельцев, аренду и коммуналку, второй раз это не пишем. Объект
    получает ВИД:

        estate   — жильё:   зелёный значок, уменьшен в 2 раза
        business — бизнес:  жёлтый значок,  уменьшен в 1.5 раза

    Значок — вращающийся models/props_phx/facepunch_logo.mdl над центром
    зоны. Видно издалека, ходить и проверять не нужно.

    СКАНИРОВАНИЕ. Зона сама знает, что внутри: автоматы с едой и
    бензоколонки ищутся по координатам, вручную ничего не привязывается.
    Убрали автомат — точка пересчиталась сама. Это снимает главную боль:
    не нужно помнить, что к чему прикручено.

    РЕШЕНИЯ ВЛАДЕЛЬЦА (27.08), заложенные здесь:
      • одиночный автомат или колонка живут без зоны, как раньше;
        две и более точек в одном месте — только через бизнес-зону;
      • лимит бизнесов на игрока: 3 (конвар grm_estate_limit);
      • просрочка коммуналки даёт ПЕНЮ, а не отключение и не изъятие;
      • цену назначает админ вручную.

    Фаза 2 даёт вид объекта, значки и сканирование. Деньги, рынок и
    личный кабинет — следующие фазы.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Estate = GRM.Estate or {}
local ES = GRM.Estate

ES.Version = "1.0.0"

--- Модель значка и его размеры (заказ владельца).
ES.MarkerModel  = "models/props_phx/facepunch_logo.mdl"
ES.MarkerScale  = { business = 1 / 1.5, estate = 1 / 2 }
ES.MarkerColor  = {
    business = Color(245, 200, 60),    -- жёлтый — бизнес
    estate   = Color(80, 205, 110),    -- зелёный — жильё
    sale     = Color(90, 170, 255),    -- синий — продаётся
}
ES.MarkerHeight = 78          -- на сколько поднять значок над центром зоны
ES.DrawDistance = 2200        -- дальше значок не рисуем: бережём кадр

--- Оборудование, которое считается доходной точкой бизнеса.
ES.EquipmentClasses = {
    grm_vending_machine = { label = "автомат", kind = "vending" },
    grm_fuel_pump       = { label = "колонка", kind = "fuel" },
}

--[[ Какие типы недвижимости к какому виду относятся. Тип уже есть в
     GRM.Property, поэтому вид выводим из него — существующие объекты
     получают вид сами, без ручной правки. ]]
ES.TypeKind = {
    apartment  = "estate",
    shop       = "business",
    office     = "business",
    warehouse  = "business",
    government = "none",
    restricted = "none",
}

if SERVER and not ConVarExists("grm_estate_limit") then
    CreateConVar("grm_estate_limit", "3", bit.bor(FCVAR_ARCHIVE, FCVAR_REPLICATED),
        "Сколько бизнесов может держать один игрок (жильё не считается)")
end

-----------------------------------------------------------------------
-- ОБЩАЯ ЧАСТЬ
-----------------------------------------------------------------------

--- Вид объекта: estate, business или none.
function ES.KindOf(rec)
    if not istable(rec) then return "none" end
    -- Явно заданный вид сильнее типа: админ может сделать бизнесом что угодно.
    local explicit = tostring(rec.estateKind or "")
    if explicit == "business" or explicit == "estate" then return explicit end
    return ES.TypeKind[tostring(rec.type or "")] or "none"
end

function ES.IsBusiness(rec) return ES.KindOf(rec) == "business" end
function ES.IsEstate(rec)   return ES.KindOf(rec) == "estate" end

--- Центр зоны объекта. nil, если зона не задана.
function ES.ZoneCenter(rec)
    if not (istable(rec) and istable(rec.zone)) then return nil end
    local a, b = rec.zone.mins, rec.zone.maxs
    if not (istable(a) and istable(b)) then return nil end
    return Vector((a.x + b.x) * 0.5, (a.y + b.y) * 0.5, (a.z + b.z) * 0.5)
end

--- Площадь зоны в метрах (1 м ≈ 39.37 units) — для подсказки цены.
function ES.ZoneArea(rec)
    if not (istable(rec) and istable(rec.zone)) then return 0 end
    local a, b = rec.zone.mins, rec.zone.maxs
    if not (istable(a) and istable(b)) then return 0 end
    local w = math.abs((b.x or 0) - (a.x or 0)) / 39.37
    local d = math.abs((b.y or 0) - (a.y or 0)) / 39.37
    return math.floor(w * d)
end

function ES.PointInZone(rec, pos)
    if not (istable(rec) and istable(rec.zone) and pos) then return false end
    local a, b = rec.zone.mins, rec.zone.maxs
    if not (istable(a) and istable(b)) then return false end
    return pos.x >= a.x and pos.y >= a.y and pos.z >= a.z
        and pos.x <= b.x and pos.y <= b.y and pos.z <= b.z
end

--- Свободен ли объект (можно купить или арендовать).
function ES.IsVacant(rec)
    if not istable(rec) then return false end
    return tostring(rec.ownerType or "none") == "none"
end

-----------------------------------------------------------------------
-- СЕРВЕР
-----------------------------------------------------------------------
if SERVER then
    --[[ СКАНИРОВАНИЕ ЗОНЫ. Оборудование не привязывается вручную: стоит
         внутри границ — значит принадлежит объекту. Убрали автомат —
         следующий пересчёт это увидит. ]]
    function ES.ScanZone(rec)
        local out = { total = 0, byKind = {}, entities = {} }
        if not (istable(rec) and istable(rec.zone)) then return out end
        for class, info in pairs(ES.EquipmentClasses) do
            local list = (GRM.Perf and GRM.Perf.Entities)
                and GRM.Perf.Entities(class) or ents.FindByClass(class)
            for _, ent in ipairs(list or {}) do
                if IsValid(ent) and ES.PointInZone(rec, ent:GetPos()) then
                    out.total = out.total + 1
                    out.byKind[info.kind] = (out.byKind[info.kind] or 0) + 1
                    out.entities[#out.entities + 1] = ent
                end
            end
        end
        return out
    end

    --- Кэш сканирования: обходить все сущности на каждый чих не нужно.
    ES._scanCache = ES._scanCache or {}
    function ES.ScanCached(rec, maxAge)
        if not istable(rec) then return { total = 0, byKind = {}, entities = {} } end
        local id = tostring(rec.id or "")
        local now = CurTime()
        local hit = ES._scanCache[id]
        if hit and (now - hit.at) < (tonumber(maxAge) or 5) then return hit.data end
        local data = ES.ScanZone(rec)
        ES._scanCache[id] = { at = now, data = data }
        return data
    end

    function ES.InvalidateScan(rec)
        if istable(rec) then ES._scanCache[tostring(rec.id or "")] = nil
        else ES._scanCache = {} end
    end

    --- Текстовая сводка по содержимому зоны для интерфейса.
    function ES.EquipmentSummary(rec)
        local scan = ES.ScanCached(rec)
        if scan.total == 0 then return "оборудования нет" end
        local parts = {}
        if (scan.byKind.vending or 0) > 0 then
            parts[#parts + 1] = scan.byKind.vending .. " автом."
        end
        if (scan.byKind.fuel or 0) > 0 then
            parts[#parts + 1] = scan.byKind.fuel .. " колонк."
        end
        return table.concat(parts, " · ")
    end

    -----------------------------------------------------------------
    -- ПРАВИЛО ОДИНОЧНОЙ ТОЧКИ (решение владельца)
    -----------------------------------------------------------------
    --[[ Одиночный автомат или колонка — личное дело игрока, зона не нужна.
         Две и более точек рядом — это уже сеть, её оформляют бизнес-зоной.
         Считаем соседей в радиусе: если точка не одна, требуем зону. ]]
    ES.ClusterRadius = 700

    function ES.NeighbourCount(pos, exceptEnt)
        local n = 0
        for class in pairs(ES.EquipmentClasses) do
            local list = (GRM.Perf and GRM.Perf.Entities)
                and GRM.Perf.Entities(class) or ents.FindByClass(class)
            for _, ent in ipairs(list or {}) do
                if IsValid(ent) and ent ~= exceptEnt
                    and ent:GetPos():DistToSqr(pos) <= ES.ClusterRadius ^ 2 then
                    n = n + 1
                end
            end
        end
        return n
    end

    --- Объект недвижимости, внутри которого стоит точка (или nil).
    function ES.ZoneAt(pos)
        local P = GRM.Property
        if not (P and istable(P.Records)) then return nil end
        for _, rec in pairs(P.Records) do
            if ES.PointInZone(rec, pos) then return rec end
        end
        return nil
    end

    --[[ Можно ли владеть этой точкой лично, без бизнес-зоны.
         Возвращает: можно ли, причина отказа. ]]
    function ES.CanOwnStandalone(ent)
        if not IsValid(ent) then return false, "Нет объекта" end
        local pos = ent:GetPos()
        -- Внутри оформленной бизнес-зоны точка принадлежит бизнесу.
        local zone = ES.ZoneAt(pos)
        if zone and ES.IsBusiness(zone) then
            return false, "Точка входит в бизнес «" .. tostring(zone.name or "") .. "»"
        end
        -- Одна точка — личное владение разрешено.
        if ES.NeighbourCount(pos, ent) == 0 then return true end
        return false, "Рядом несколько точек — оформите бизнес-зону"
    end

    -----------------------------------------------------------------
    -- ЛИМИТ БИЗНЕСОВ НА ИГРОКА
    -----------------------------------------------------------------
    function ES.Limit()
        local cv = GetConVar and GetConVar("grm_estate_limit")
        return math.max(1, math.floor(cv and cv:GetInt() or 3))
    end

    function ES.CountOwned(ownerKey)
        ownerKey = tostring(ownerKey or "")
        if ownerKey == "" then return 0 end
        local P = GRM.Property
        if not (P and istable(P.Records)) then return 0 end
        local n = 0
        for _, rec in pairs(P.Records) do
            -- Жильё в лимит бизнесов не входит.
            if ES.IsBusiness(rec) and tostring(rec.ownerType or "") == "character"
                and tostring(rec.ownerKey or "") == ownerKey then
                n = n + 1
            end
        end
        return n
    end

    function ES.CanAcquire(ply, rec)
        if not (IsValid(ply) and istable(rec)) then return false, "Нет объекта" end
        if not ES.IsBusiness(rec) then return true end     -- жильё без лимита
        if ply:IsSuperAdmin() then return true end
        local key = (GRM.Identity and GRM.Identity.CharacterKey
            and GRM.Identity.CharacterKey(ply)) or ply:SteamID64()
        local have, limit = ES.CountOwned(key), ES.Limit()
        if have >= limit then
            return false, ("Лимит бизнесов: %d из %d. Продайте один, чтобы купить новый."):format(have, limit)
        end
        return true
    end

    -----------------------------------------------------------------
    -- ПЕНЯ ЗА ПРОСРОЧКУ (решение владельца: не отключать и не изымать)
    -----------------------------------------------------------------
    ES.PenaltyRate = 0.05        -- 5% от долга за расчётный период
    ES.PenaltyGrace = 3          -- сколько периодов долга терпим без пени

    --[[ Начисление пени поверх штатной коммуналки GRM.Property.
         Долг растёт сам, объект не отбирается — как и просил владелец. ]]
    function ES.ApplyPenalty(rec)
        if not istable(rec) then return 0 end
        local debt = math.max(0, math.floor(tonumber(rec.utilityDebt) or 0))
        local rate = math.max(0, math.floor(tonumber(rec.utilityRate) or 0))
        if debt <= 0 or rate <= 0 then
            rec.estatePenalty = 0
            return 0
        end
        -- Пеня начинается, только когда долг перерос несколько периодов.
        if debt < rate * ES.PenaltyGrace then return 0 end
        local add = math.floor(debt * ES.PenaltyRate)
        if add <= 0 then return 0 end
        rec.utilityDebt = math.min(100000000, debt + add)
        rec.estatePenalty = math.max(0, math.floor(tonumber(rec.estatePenalty) or 0)) + add
        return add
    end

    hook.Add("Think", "GRM_Estate_Penalty", function()
        if not (GRM.Perf and GRM.Perf.Throttle) then return end
        -- Раз в 5 минут, тем же ритмом, что и штатная коммуналка.
        if not GRM.Perf.Throttle("estate.penalty", 300) then return end
        local P = GRM.Property
        if not (P and istable(P.Records)) then return end
        local touched = false
        for _, rec in pairs(P.Records) do
            if tostring(rec.ownerType or "none") ~= "none" then
                if ES.ApplyPenalty(rec) > 0 then touched = true end
            end
        end
        if touched and P.Save then pcall(P.Save, "estate-penalty") end
    end)

    -----------------------------------------------------------------
    -- СНИМОК ДЛЯ КЛИЕНТА (значки и сводка)
    -----------------------------------------------------------------
    local NET_SYNC = "GRM_Estate_Sync"
    util.AddNetworkString(NET_SYNC)

    function ES.BuildSnapshot()
        local out = {}
        local P = GRM.Property
        if not (P and istable(P.Records)) then return out end
        for _, rec in pairs(P.Records) do
            local kind = ES.KindOf(rec)
            local center = ES.ZoneCenter(rec)
            if kind ~= "none" and center then
                local scan = ES.ScanCached(rec, 30)
                out[#out + 1] = {
                    id = tostring(rec.id or ""),
                    kind = kind,
                    name = tostring(rec.name or ""),
                    pos = { x = center.x, y = center.y, z = center.z + ES.MarkerHeight },
                    vacant = ES.IsVacant(rec),
                    owner = tostring(rec.ownerName or ""),
                    equipment = kind == "business" and scan.total or 0,
                    price = math.max(0, math.floor(tonumber(rec.purchasePrice) or 0)),
                    area = ES.ZoneArea(rec),
                }
            end
        end
        return out
    end

    function ES.Sync(ply)
        local ok, txt = pcall(util.TableToJSON, ES.BuildSnapshot())
        if not ok or not txt then return end
        local data = util.Compress(txt) or ""
        if #data == 0 then return end
        net.Start(NET_SYNC)
            net.WriteUInt(#txt, 32)
            net.WriteUInt(#data, 32)
            net.WriteData(data, #data)
        if IsValid(ply) then net.Send(ply) else net.Broadcast() end
    end

    hook.Add("PlayerInitialSpawn", "GRM_Estate_Sync", function(ply)
        timer.Simple(6, function() if IsValid(ply) then ES.Sync(ply) end end)
    end)

    -- Смена владельца сразу меняет цвет значка у всех.
    hook.Add("GRM_PropertyOwnerChanged", "GRM_Estate_Resync", function()
        timer.Simple(0.2, function() ES.Sync() end)
    end)

    --- Периодическая пересинхронизация: оборудование могли передвинуть.
    timer.Create("GRM_Estate_Resync", 120, 0, function()
        ES.InvalidateScan()
        ES.Sync()
    end)

    -----------------------------------------------------------------
    -- ТУЛ «GRM: БИЗНЕС-ЗОНА» (фаза 3)
    -----------------------------------------------------------------
    --[[ Тул выделяет зону прямо на месте и сразу показывает, что внутри.
         Заходить в админку и привязывать оборудование руками не нужно —
         сканирование само найдёт автоматы и колонки в границах. ]]
    local NET_TOOL_REQ  = "GRM_Estate_ToolReq"
    local NET_TOOL_DATA = "GRM_Estate_ToolData"
    util.AddNetworkString(NET_TOOL_REQ)
    util.AddNetworkString(NET_TOOL_DATA)

    --- Что лежит в произвольном прямоугольнике: нужно для предпросмотра.
    function ES.ScanBox(mins, maxs)
        local fake = { id = "__preview", zone = {
            mins = { x = mins.x, y = mins.y, z = mins.z },
            maxs = { x = maxs.x, y = maxs.y, z = maxs.z } } }
        return ES.ScanZone(fake)
    end

    --[[ Снимок для тула: существующие зоны с их содержимым плюс
         оборудование, которое пока ничьё — админ сразу видит, что
         осталось неоформленным. ]]
    local function toolSnapshot()
        local zones, loose = {}, {}
        local P = GRM.Property
        local claimed = {}

        for _, rec in pairs((P and P.Records) or {}) do
            local kind = ES.KindOf(rec)
            if kind ~= "none" and istable(rec.zone) then
                local scan = ES.ScanCached(rec, 3)
                for _, ent in ipairs(scan.entities) do claimed[ent] = true end
                zones[#zones + 1] = {
                    id = tostring(rec.id or ""),
                    name = tostring(rec.name or ""),
                    kind = kind,
                    mins = rec.zone.mins,
                    maxs = rec.zone.maxs,
                    vacant = ES.IsVacant(rec),
                    owner = tostring(rec.ownerName or ""),
                    equipment = scan.total,
                    summary = kind == "business" and ES.EquipmentSummary(rec) or "",
                    area = ES.ZoneArea(rec),
                    price = math.max(0, math.floor(tonumber(rec.purchasePrice) or 0)),
                }
            end
        end

        for class, info in pairs(ES.EquipmentClasses) do
            local list = (GRM.Perf and GRM.Perf.Entities)
                and GRM.Perf.Entities(class) or ents.FindByClass(class)
            for _, ent in ipairs(list or {}) do
                if IsValid(ent) and not claimed[ent] then
                    local pos = ent:GetPos()
                    loose[#loose + 1] = { x = pos.x, y = pos.y, z = pos.z, label = info.label }
                end
            end
        end
        return zones, loose
    end

    net.Receive(NET_TOOL_REQ, function(_, ply)
        if not (IsValid(ply) and ply:IsSuperAdmin()) then return end
        if GRM.Perf and GRM.Perf.Throttle
            and not GRM.Perf.Throttle("estate.tool." .. ply:EntIndex(), 0.9) then return end
        local zones, loose = toolSnapshot()
        net.Start(NET_TOOL_DATA)
            net.WriteTable({ zones = zones, loose = loose })
        net.Send(ply)
    end)

    --[[ Создание зоны туллом. Объект недвижимости заводится сразу с
         границами: двери можно привязать потом штатным тулом. ]]
    function ES.CreateZone(ply, a, b, name, kind, price)
        if not (IsValid(ply) and ply:IsSuperAdmin()) then return false, "Только суперадмин" end
        local P = GRM.Property
        if not (P and istable(P.Records)) then return false, "Модуль недвижимости не загружен" end

        local mins = Vector(math.min(a.x, b.x), math.min(a.y, b.y), math.min(a.z, b.z))
        local maxs = Vector(math.max(a.x, b.x), math.max(a.y, b.y), math.max(a.z, b.z) + 190)
        -- Совсем плоскую зону оформлять нельзя: в неё ничего не попадёт.
        if (maxs.x - mins.x) < 32 or (maxs.y - mins.y) < 32 then
            return false, "Зона слишком мала — разведите углы шире"
        end

        kind = (kind == "estate") and "estate" or "business"
        local id = "zone_" .. tostring(math.floor(CurTime() * 100)) .. "_" .. tostring(math.random(100, 999))
        local rec = P.Normalize({
            id = id,
            name = tostring(name or ""),
            -- Тип задаём под вид: жильё квартирой, бизнес магазином.
            type = kind == "estate" and "apartment" or "shop",
            estateKind = kind,
            doors = {},
            purchasePrice = math.max(0, math.floor(tonumber(price) or 0)),
            zone = {
                mins = { x = mins.x, y = mins.y, z = mins.z },
                maxs = { x = maxs.x, y = maxs.y, z = maxs.z },
            },
        })
        if rec.name == "" then
            rec.name = kind == "estate" and "Жилой объект" or "Бизнес-объект"
        end
        P.Records[rec.id] = rec
        if P.Reindex then P.Reindex() end
        if P.Save then pcall(P.Save, "estate-tool") end
        ES.InvalidateScan()
        ES.Sync()

        local scan = ES.ScanZone(rec)
        return true, ("Зона «%s» создана · %d м² · внутри точек: %d"):format(
            rec.name, ES.ZoneArea(rec), scan.total), rec
    end

    --- Удалить зону под прицелом.
    function ES.DeleteZoneAt(ply, pos)
        if not (IsValid(ply) and ply:IsSuperAdmin()) then return false, "Только суперадмин" end
        local P = GRM.Property
        if not (P and istable(P.Records)) then return false, "Модуль недвижимости не загружен" end
        for id, rec in pairs(P.Records) do
            if ES.KindOf(rec) ~= "none" and ES.PointInZone(rec, pos) then
                -- Занятый объект не сносим молча: сначала пусть освободят.
                if not ES.IsVacant(rec) then
                    return false, "Объект занят: " .. tostring(rec.ownerName or "владелец")
                        .. ". Сначала освободите его."
                end
                local name = tostring(rec.name or "")
                P.Records[id] = nil
                if P.Reindex then P.Reindex() end
                if P.Save then pcall(P.Save, "estate-tool-delete") end
                ES.InvalidateScan()
                ES.Sync()
                return true, "Зона «" .. name .. "» удалена"
            end
        end
        return false, "Здесь нет зоны"
    end

    --- Диагностика: grm_estate
    concommand.Add("grm_estate", function(ply)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end
        local function say(t)
            if IsValid(ply) then ply:PrintMessage(HUD_PRINTTALK, t) else print(t) end
        end
        local P = GRM.Property
        say("[Недвижимость] версия " .. ES.Version .. ", лимит бизнесов: " .. ES.Limit())
        if not (P and istable(P.Records)) then say("  Модуль недвижимости не загружен.") return end
        local n = 0
        for _, rec in pairs(P.Records) do
            local kind = ES.KindOf(rec)
            if kind ~= "none" then
                n = n + 1
                say(("  [%s] %s — %s · %d м² · %s"):format(
                    kind == "business" and "БИЗНЕС" or "ЖИЛЬЁ",
                    tostring(rec.name or ""),
                    ES.IsVacant(rec) and "свободно" or ("владелец: " .. tostring(rec.ownerName or "")),
                    ES.ZoneArea(rec),
                    kind == "business" and ES.EquipmentSummary(rec) or "—"))
            end
        end
        if n == 0 then say("  Объектов с зонами нет.") end
    end)

    if GRM.Modules and GRM.Modules.Register then
        GRM.Modules.Register("estate", {
            label = "Бизнес и жильё",
            version = ES.Version,
            Refresh = function(ply) ES.Sync(ply) end,
            Status = function()
                local n = 0
                for _, rec in pairs((GRM.Property and GRM.Property.Records) or {}) do
                    if ES.KindOf(rec) ~= "none" then n = n + 1 end
                end
                return "объектов: " .. n
            end,
            Depends = { "property" },
        })
    end
end

-----------------------------------------------------------------------
-- КЛИЕНТ: вращающиеся значки над зонами
-----------------------------------------------------------------------
if CLIENT then
    ES.Zones = ES.Zones or {}

    surface.CreateFont("GRMEstate_Label", { font = "Roboto", size = 22, weight = 800, extended = true, antialias = true })
    surface.CreateFont("GRMEstate_Sub",   { font = "Roboto", size = 16, weight = 500, extended = true, antialias = true })

    net.Receive("GRM_Estate_Sync", function()
        local rawLen = net.ReadUInt(32)
        local len = net.ReadUInt(32)
        local data = net.ReadData(len)
        local txt = util.Decompress(data, rawLen + 64) or ""
        local ok, t = pcall(util.JSONToTable, txt, false, true)
        ES.Zones = (ok and istable(t)) and t or {}
        -- Модели значков пересоздаём под новый список.
        ES._markers = nil
        hook.Run("GRM_EstateSynced")
    end)

    --[[ Клиентские модели значков. ClientsideModel дешевле энтити и не
         нагружает сеть: значок — чистая декорация. ]]
    local function ensureMarkers()
        if ES._markers then return ES._markers end
        local out = {}
        for _, zone in ipairs(ES.Zones or {}) do
            local mdl = ClientsideModel(ES.MarkerModel, RENDERGROUP_TRANSLUCENT)
            if IsValid(mdl) then
                mdl:SetNoDraw(true)
                mdl:SetPos(Vector(zone.pos.x, zone.pos.y, zone.pos.z))
                local scale = ES.MarkerScale[zone.kind] or 0.5
                mdl:SetModelScale(scale, 0)
                out[#out + 1] = { ent = mdl, zone = zone }
            end
        end
        ES._markers = out
        return out
    end

    hook.Add("PostDrawTranslucentRenderables", "GRM_Estate_Markers", function(depth, sky)
        if depth or sky then return end
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        local markers = ensureMarkers()
        if #markers == 0 then return end

        local eyePos = EyePos()
        local rot = CurTime() * 42        -- медленное вращение
        for _, row in ipairs(markers) do
            local ent, zone = row.ent, row.zone
            if IsValid(ent) then
                local pos = ent:GetPos()
                local dist = eyePos:DistToSqr(pos)
                -- Дальние значки не рисуем: на карте их могут быть десятки.
                if dist <= ES.DrawDistance ^ 2 then
                    --[[ Свободный объект подсвечен синим «продаётся»,
                         занятый — цветом своего вида. ]]
                    local col = zone.vacant and ES.MarkerColor.sale
                        or (ES.MarkerColor[zone.kind] or color_white)
                    ent:SetAngles(Angle(0, rot % 360, 0))
                    render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)
                    ent:DrawModel()
                    render.SetColorModulation(1, 1, 1)
                end
            end
        end
    end)

    --[[ Подпись под значком: название, состояние и что внутри.
         Отдельным проходом, чтобы текст не перекрывался моделью. ]]
    hook.Add("HUDPaint", "GRM_Estate_Labels", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        if GRM.AugHUD and GRM.AugHUD.IsActive and GRM.AugHUD.IsActive() then return end
        local eyePos = EyePos()

        for _, zone in ipairs(ES.Zones or {}) do
            local pos = Vector(zone.pos.x, zone.pos.y, zone.pos.z)
            local dist = eyePos:DistToSqr(pos)
            if dist <= (ES.DrawDistance * 0.55) ^ 2 then
                local screen = (pos - Vector(0, 0, 34)):ToScreen()
                if screen.visible then
                    local col = zone.vacant and ES.MarkerColor.sale
                        or (ES.MarkerColor[zone.kind] or color_white)
                    local title = zone.name ~= "" and zone.name
                        or (zone.kind == "business" and "Бизнес" or "Жильё")
                    draw.SimpleTextOutlined(title, "GRMEstate_Label", screen.x, screen.y,
                        col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))

                    local sub
                    if zone.vacant then
                        sub = zone.price > 0 and ("СВОБОДНО · " .. zone.price .. " GRM") or "СВОБОДНО"
                    else
                        sub = zone.owner ~= "" and zone.owner or "занято"
                    end
                    -- Для бизнеса сразу видно, сколько внутри оборудования.
                    if zone.kind == "business" and (zone.equipment or 0) > 0 then
                        sub = sub .. "  ·  точек: " .. zone.equipment
                    end
                    draw.SimpleTextOutlined(sub, "GRMEstate_Sub", screen.x, screen.y + 20,
                        Color(210, 220, 232), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))
                end
            end
        end
    end)

    --- Уборка моделей при выгрузке.
    hook.Add("ShutDown", "GRM_Estate_Cleanup", function()
        for _, row in ipairs(ES._markers or {}) do
            if IsValid(row.ent) then row.ent:Remove() end
        end
        ES._markers = nil
    end)
end
