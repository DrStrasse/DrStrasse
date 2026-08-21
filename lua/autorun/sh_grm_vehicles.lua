--[[--------------------------------------------------------------------
    GRM Vehicles v1.0.0 — ЕДИНЫЙ слой «машина игрока» (заказ 21.08).

    Зачем. Личный транспорт живёт в записях гаража дилера
    (GRM.VehicleDealer), служебный — в автопарке организации (GRM.Fleet).
    Это два разных хранилища, и раньше каждое окно (дилер, гараж, терминал)
    само разбиралось, где чья машина и какую функцию звать. Копии логики
    расползались, а поведение расходилось: где-то проверялась приписка к
    гаражу, где-то нет.

    Теперь между интерфейсами и хранилищами стоит один диспетчер:
      V.Rows(ply, garage)             — что показать человеку;
      V.Issue(ply, source, id, garage)— выдать (личную или служебную);
      V.Store(ply, source, id)        — вернуть;
      V.SetHome(ply, source, id, gid) — приписать к гаражу.

    source: "personal" — запись гаража игрока, "fleet" — единица автопарка.
    Сами хранилища не меняются: диспетчер только направляет вызов и даёт
    одинаковые ответы и сообщения.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Vehicles = GRM.Vehicles or {}
local V = GRM.Vehicles
V.Version = "1.0.0"

V.Sources = { personal = "Личный транспорт", fleet = "Служебный автопарк" }

--- Нормализация источника: пустой/неизвестный считаем личным.
function V.Source(src)
    src = tostring(src or "")
    return V.Sources[src] and src or "personal"
end

if SERVER then

    local function notifyText(ok, good, bad)
        return ok and good or bad
    end

    local function VD() return GRM.VehicleDealer end
    local function FL() return GRM.Fleet end
    local function GG() return GRM.Garage end

    --- Строки для интерфейсов: личные записи + служебная техника гаража.
    --  garage не обязателен: без него отдаём весь транспорт игрока.
    function V.Rows(ply, garage)
        local out = {}
        if not IsValid(ply) then return out end

        local vd = VD()
        if vd and vd.GarageRecords then
            local G = GG()
            for id, rec in pairs(vd.GarageRecords(ply) or {}) do
                if istable(rec) and not rec.service then
                    local ent = vd.Active and vd.Active[id]
                    local homeID = tostring(rec.garageID or "")
                    local home = G and G.Get and G.Get(homeID) or nil
                    out[#out + 1] = {
                        source = "personal",
                        id = id, name = rec.name or rec.class, class = rec.class, model = rec.model,
                        price = tonumber(rec.price) or 0,
                        onMap = IsValid(ent),
                        distance = IsValid(ent) and math.floor(ply:GetPos():Distance(ent:GetPos())) or 0,
                        homeID = homeID, homeName = home and home.name or "",
                        here = (homeID ~= "" and garage and homeID == garage.id) or false,
                        allowed = true,
                    }
                end
            end
        end

        local fl = FL()
        if fl and fl.UnitsInGarage and istable(garage) then
            local faction = ply:GetNWString("GRM_Faction", "")
            for _, unit in ipairs(fl.UnitsInGarage(garage.id)) do
                if ply:IsSuperAdmin() or tostring(unit.faction) == faction then
                    local allowed, why = true, nil
                    if fl.UnitAllowedFor then
                        allowed, why = fl.UnitAllowedFor(unit, fl.ActorOf and fl.ActorOf(ply) or nil)
                    end
                    out[#out + 1] = {
                        source = "fleet",
                        id = unit.id, name = unit.name, class = unit.class, model = unit.model,
                        faction = unit.faction, status = unit.status,
                        onMap = fl.Active and IsValid(fl.Active[unit.id]) or false,
                        homeID = tostring(unit.garageID or ""), homeName = garage.name,
                        here = true, fleet = true,
                        allowed = allowed == true, reason = allowed and "" or tostring(why or ""),
                        restriction = (fl.RestrictionText and fl.RestrictionText(unit)) or "",
                    }
                end
            end
        end

        table.sort(out, function(a, b)
            if (a.source == "fleet") ~= (b.source == "fleet") then return a.source ~= "fleet" end
            return tostring(a.name) < tostring(b.name)
        end)
        return out
    end

    --- Выдать машину (личную из записи гаража или служебную из парка).
    function V.Issue(ply, source, id, garage)
        source = V.Source(source)
        if source == "fleet" then
            local fl = FL()
            if not (fl and fl.Issue) then return false, "Модуль автопарка не загружен" end
            local ent, err = fl.Issue(ply, id, garage)
            return IsValid(ent), notifyText(IsValid(ent), "Служебная техника подана на место стоянки", err or "Не удалось выдать")
        end
        local G = GG()
        if not (G and G.Retrieve) then return false, "Модуль гаражей не загружен" end
        return G.Retrieve(ply, id)
    end

    --- Вернуть машину.
    function V.Store(ply, source, id)
        source = V.Source(source)
        if source == "fleet" then
            local fl = FL()
            if not (fl and fl.Store) then return false, "Модуль автопарка не загружен" end
            return fl.Store(ply, id)
        end
        local G = GG()
        if not (G and G.Store) then return false, "Модуль гаражей не загружен" end
        return G.Store(ply, id)
    end

    --- Приписать машину к гаражу.
    function V.SetHome(ply, source, id, garageID)
        source = V.Source(source)
        if source == "fleet" then
            local fl = FL()
            if not (fl and fl.SetGarage) then return false, "Модуль автопарка не загружен" end
            return fl.SetGarage(ply, id, garageID)
        end
        local G = GG()
        if not (G and G.SetHome) then return false, "Модуль гаражей не загружен" end
        return G.SetHome(ply, id)
    end

    --- Есть ли у игрока хоть одна машина этого источника (для подсказок).
    function V.Count(ply, source, garage)
        local n = 0
        for _, row in ipairs(V.Rows(ply, garage)) do
            if V.Source(row.source) == V.Source(source) then n = n + 1 end
        end
        return n
    end
end

print("[GRM Vehicles] v" .. V.Version .. " loaded (" .. (SERVER and "Server" or "Client") .. ")")
