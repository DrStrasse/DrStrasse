--[[ Топливо GRM v1.2: шланг с провисом, сессия заливки, частные колонки. ]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Fuel = GRM.Fuel or {}
local F = GRM.Fuel
F.Version = "1.2.2"
F.File = "grm_fuel.json"
F.PumpFile = "grm_fuel_pumps_" .. string.lower(game.GetMap() or "unknown") .. ".json"
F.PricePerLiter = 8
F.PumpPrice = 15000
F.StationRadius = 700
F.Types = { petrol = "Бензин", diesel = "Дизель", electric = "Заряд" }

function F.UID(ent)
    if GRM.Vehicles and GRM.Vehicles.UID then
        local id = GRM.Vehicles.UID(ent)
        if id ~= "" then return id end
    end
    if IsValid(ent) then return "ent:" .. tostring(ent:EntIndex()) end
    return ""
end

function F.RootVehicle(ent)
    if not IsValid(ent) then return nil end
    if IsValid(ent.GetParent and ent:GetParent()) then
        local p = ent:GetParent()
        local VK = GRM.VehicleKeys or _G.VK
        if VK and VK.IsVehicle and VK.IsVehicle(p) then return p end
        if p.IsSimfphysCar or p.LVS or p.IsLVSVehicle then return p end
    end
    for _, name in ipairs({ "BaseVehicle", "SimfphysVehicle", "LVS", "Vehicle" }) do
        local b = ent.GetNWEntity and ent:GetNWEntity(name)
        if IsValid(b) then return b end
        if IsValid(ent[name]) then return ent[name] end
    end
    return ent
end

function F.GuessType(ent)
    if not IsValid(ent) then return "petrol" end
    local cls = string.lower(ent:GetClass() or "")
    local mdl = string.lower(ent:GetModel() or "")
    if string.find(cls, "electric") or string.find(mdl, "tesla") then return "electric" end
    if string.find(cls, "truck") or string.find(mdl, "kamaz") or string.find(mdl, "ural")
        or string.find(mdl, "diesel") then return "diesel" end
    return "petrol"
end

function F.TankSize()
    return 55
end

function F.TankWorld(ent)
    if not IsValid(ent) then return vector_origin end
    local mn, mx = ent:OBBMins(), ent:OBBMaxs()
    return ent:LocalToWorld(Vector(mn.x + 12, mx.y - 8, (mn.z + mx.z) * 0.35))
end

function F.CharKey(ply)
    if GRM.Identity and GRM.Identity.CharacterKey then return GRM.Identity.CharacterKey(ply) end
    return IsValid(ply) and (ply:SteamID64() .. ":char1") or ""
end

function F.PriceOf(pump)
    if IsValid(pump) and pump.GetPriceL then
        local p = tonumber(pump:GetPriceL()) or 0
        if p > 0 then return p end
    end
    return F.PricePerLiter or 8
end

if SERVER then
    util.AddNetworkString("GRM_Fuel_Station")
    F.Data = F.Data or {}

    local function jsonT(txt)
        local ok, t = pcall(util.JSONToTable, txt, false, true)
        return (ok and istable(t)) and t or nil
    end

    function F.Load()
        if not file.Exists(F.File, "DATA") then F.Data = {} return end
        F.Data = jsonT(file.Read(F.File, "DATA") or "") or {}
    end

    function F.Save()
        local fn = function()
            local ok, txt = pcall(util.TableToJSON, F.Data or {}, true)
            if ok and txt then file.Write(F.File, txt) end
        end
        if GRM.Perf and GRM.Perf.Coalesce then GRM.Perf.Coalesce("grm_fuel_save", 0.8, fn) else fn() end
    end

    function F.SavePumps()
        local rows = {}
        for _, e in ipairs(ents.FindByClass("grm_fuel_pump")) do
            if IsValid(e) then
                rows[#rows + 1] = {
                    pos = { x = e:GetPos().x, y = e:GetPos().y, z = e:GetPos().z },
                    ang = { p = e:GetAngles().p, y = e:GetAngles().y, r = e:GetAngles().r },
                    kind = e:GetFuelKind(),
                    owner = e:GetOwnerKey(),
                    station = e:GetStationID(),
                    price = e:GetPriceL(),
                    cash = e:GetCash(),
                }
            end
        end
        local fn = function()
            file.Write(F.PumpFile, util.TableToJSON(rows, false) or "[]")
        end
        if GRM.Perf and GRM.Perf.Coalesce then GRM.Perf.Coalesce("grm_fuel_pumps", 1, fn) else fn() end
    end

    function F.LoadPumps()
        if not file.Exists(F.PumpFile, "DATA") then return end
        local rows = jsonT(file.Read(F.PumpFile, "DATA") or "")
        if not istable(rows) then return end
        for _, r in ipairs(rows) do
            if istable(r.pos) then
                local spot = Vector(r.pos.x or 0, r.pos.y or 0, r.pos.z or 0)
                local busy
                for _, ex in ipairs(ents.FindInSphere(spot, 8)) do
                    if IsValid(ex) and ex:GetClass() == "grm_fuel_pump" then busy = true break end
                end
                if busy then continue end
                local e = ents.Create("grm_fuel_pump")
                if IsValid(e) then
                    e:SetPos(Vector(r.pos.x, r.pos.y, r.pos.z))
                    if istable(r.ang) then e:SetAngles(Angle(r.ang.p, r.ang.y, r.ang.r)) end
                    e:Spawn()
                    e:SetFuelKind(r.kind ~= "" and r.kind or "petrol")
                    e:SetOwnerKey(r.owner or "")
                    e:SetStationID(r.station or "")
                    e:SetPriceL(tonumber(r.price) or F.PricePerLiter)
                    e:SetCash(math.floor(tonumber(r.cash) or 0))
                end
            end
        end
    end

    function F.Get(uid)
        uid = tostring(uid or "")
        if uid == "" then return nil end
        F.Data[uid] = F.Data[uid] or { liters = 40, typ = "petrol" }
        return F.Data[uid]
    end

    function F.ApplyNW(ent)
        if not IsValid(ent) then return end
        ent = F.RootVehicle(ent) or ent
        if GRM.Vehicles and GRM.Vehicles.EnsureUID then GRM.Vehicles.EnsureUID(ent) end
        local uid = F.UID(ent)
        if uid == "" then return end
        local rec = F.Get(uid)
        rec.typ = rec.typ or F.GuessType(ent)
        rec.liters = math.Clamp(tonumber(rec.liters) or 40, 0, F.TankSize())
        ent:SetNWFloat("GRM_Fuel", rec.liters)
        ent:SetNWFloat("GRM_FuelMax", F.TankSize())
        ent:SetNWString("GRM_FuelType", rec.typ)
    end

    function F.AddLiters(ent, amount, typ)
        if not IsValid(ent) then return 0 end
        ent = F.RootVehicle(ent) or ent
        F.ApplyNW(ent)
        local rec = F.Get(F.UID(ent))
        if typ and rec.typ ~= typ then return 0, "wrong" end
        local max = F.TankSize()
        local add = math.min(max - rec.liters, math.max(0, tonumber(amount) or 0))
        rec.liters = rec.liters + add
        F.ApplyNW(ent)
        F.Save()
        return add
    end

    local function killEngine(ent)
        if not IsValid(ent) then return end
        pcall(function()
            if ent.EnableEngine then ent:EnableEngine(false) end
            if ent.StartEngine then ent:StartEngine(false) end
            if ent.SetActive then ent:SetActive(false) end
            if ent.TurnOff then ent:TurnOff() end
            if ent.StopEngine then ent:StopEngine() end
        end)
        ent:SetNWBool("GRM_OutOfFuel", true)
    end

    function F.ClearHose(pump)
        if not IsValid(pump) then return end
        constraint.RemoveConstraints(pump, "Rope")
        constraint.RemoveConstraints(pump, "Winch")
        constraint.RemoveConstraints(pump, "Elastic")
        if IsValid(pump.GRMHoseDummy) then pump.GRMHoseDummy:Remove() end
        pump.GRMHoseDummy = nil
    end

    function F.AttachHose(pump)
        F.ClearHose(pump)
    end

    function F.HoseToTank(pump)
        F.ClearHose(pump)
    end

    function F.StopNozzle(wep, msg)
        if not IsValid(wep) then return end
        local pump = wep:GetNWEntity("GRM_Pump")
        local key = "GRM_Nozzle_" .. wep:EntIndex()
        if timer.Exists(key) then timer.Remove(key) end
        wep:SetNWBool("Inserted", false)
        wep:SetNWEntity("GRM_Veh", NULL)
        if IsValid(pump) then
            pump:SetBusy(false)
            pump:SetNWEntity("NozzleWep", wep)
            if IsValid(wep:GetOwner()) then F.ClearHose(pump) end
        end
        local ply = wep:GetOwner()
        if msg and IsValid(ply) and GRM.Notify then GRM.Notify(ply, msg, 180, 210, 140) end
    end

    function F.ReturnNozzle(wep, pump, ply)
        F.StopNozzle(wep)
        if IsValid(pump) then
            F.ClearHose(pump)
            pump:SetBusy(false)
            pump:SetUser(NULL)
            pump:SetNWEntity("NozzleWep", NULL)
            pump:SetSessionL(0)
            pump:SetSessionPay(0)
        end
        if IsValid(wep) then wep:Remove() end
        if IsValid(ply) and GRM.Notify then GRM.Notify(ply, "Пистолет на колонке.", 180, 210, 140) end
    end

    function F.GiveNozzle(pump, ply)
        if not (IsValid(pump) and IsValid(ply)) then return end
        if ply:HasWeapon("weapon_grm_fuel_nozzle") then
            if GRM.Notify then GRM.Notify(ply, "Пистолет уже в руках.", 255, 180, 80) end
            return
        end
        local wep = ply:Give("weapon_grm_fuel_nozzle")
        if not IsValid(wep) then return end
        wep:SetNWEntity("GRM_Pump", pump)
        ply:SelectWeapon("weapon_grm_fuel_nozzle")
        pump:SetUser(ply)
        pump:SetNWEntity("NozzleWep", wep)
        pump:SetSessionL(0)
        pump:SetSessionPay(0)
        F.ClearHose(pump)
        if GRM.Notify then GRM.Notify(ply, "Пистолет снят. Вставь в бак у заднего крыла.", 120, 220, 140) end
    end

    function F.StartNozzle(wep, pump, veh, ply)
        if not (IsValid(wep) and IsValid(pump) and IsValid(veh) and IsValid(ply)) then return end
        veh = F.RootVehicle(veh) or veh
        F.ApplyNW(veh)
        local need = veh:GetNWString("GRM_FuelType", "petrol")
        if need ~= pump:GetFuelKind() then
            if GRM.Notify then GRM.Notify(ply, "Не тот тип. Нужен: " .. tostring((F.Types or {})[need] or need), 255, 120, 80) end
            return
        end
        wep:SetNWBool("Inserted", true)
        wep:SetNWEntity("GRM_Veh", veh)
        pump:SetBusy(true)
        pump:SetSessionL(0)
        pump:SetSessionPay(0)
        pump:SetTankNow(veh:GetNWFloat("GRM_Fuel", 0))
        pump:SetTankMax(veh:GetNWFloat("GRM_FuelMax", 55))
        F.ClearHose(pump)
        pump:EmitSound("ambient/water/leak_1.wav", 50, 95)
        local key = "GRM_Nozzle_" .. wep:EntIndex()
        timer.Create(key, 0.35, 0, function()
            if not (IsValid(wep) and IsValid(pump) and IsValid(veh) and IsValid(ply)) then
                F.StopNozzle(wep)
                return
            end
            if not wep:GetNWBool("Inserted") then return end
            if ply:GetPos():DistToSqr(pump:GetPos()) > 430 * 430 then
                F.StopNozzle(wep, "Шланг натянулся — пистолет вырвало.")
                return
            end
            if ply:GetPos():DistToSqr(F.TankWorld(veh)) > 150 * 150 then
                F.StopNozzle(wep, "Отошёл от бака.")
                return
            end
            local price = F.PriceOf(pump)
            if GRM.HasMoney and not GRM.HasMoney(ply, price) then
                F.StopNozzle(wep, "Деньги кончились.")
                return
            end
            local added = select(1, F.AddLiters(veh, 1.15, pump:GetFuelKind())) or 0
            if added <= 0 then
                F.StopNozzle(wep, "Бак полный.")
                return
            end
            local cost = math.ceil(price * added)
            if GRM.TakeMoney then GRM.TakeMoney(ply, cost, "Заправка") end
            local owner = pump:GetOwnerKey() or ""
            if owner ~= "" then
                pump:SetCash(pump:GetCash() + cost)
            end
            pump:SetSessionL((pump:GetSessionL() or 0) + added)
            pump:SetSessionPay((pump:GetSessionPay() or 0) + cost)
            pump:SetTankNow(veh:GetNWFloat("GRM_Fuel", 0))
            pump:SetTankMax(veh:GetNWFloat("GRM_FuelMax", 55))
            wep:SetNWFloat("SessL", pump:GetSessionL())
            wep:SetNWFloat("SessPay", pump:GetSessionPay())
            wep:SetNWFloat("TankNow", pump:GetTankNow())
            wep:SetNWFloat("TankMax", pump:GetTankMax())
        end)
        if GRM.Notify then GRM.Notify(ply, "Пистолет в баке. Идёт заливка.", 120, 220, 140) end
    end

    local function nearbyPumps(origin, radius)
        local out = {}
        for _, e in ipairs(ents.FindByClass("grm_fuel_pump")) do
            if IsValid(e) and e:GetPos():DistToSqr(origin) <= radius * radius then out[#out + 1] = e end
        end
        return out
    end

    function F.IsOwner(ply, pump)
        if not IsValid(ply) or not IsValid(pump) then return false end
        if ply:IsSuperAdmin() then return true end
        return pump:GetOwnerKey() == F.CharKey(ply)
    end

    function F.BuyPump(ply, pump, whole)
        if not IsValid(ply) or not IsValid(pump) then return false, "Нет колонки" end
        if ply:GetPos():DistToSqr(pump:GetPos()) > 220 * 220 then return false, "Подойдите ближе" end
        local list = whole and nearbyPumps(pump:GetPos(), F.StationRadius) or { pump }
        local free = {}
        for _, e in ipairs(list) do
            local o = e:GetOwnerKey() or ""
            if o == "" or o == F.CharKey(ply) then free[#free + 1] = e end
        end
        if #free == 0 then return false, "Нечего выкупать" end
        local needBuy = 0
        for _, e in ipairs(free) do
            if (e:GetOwnerKey() or "") == "" then needBuy = needBuy + 1 end
        end
        local price = needBuy * F.PumpPrice
        if whole and needBuy > 1 then price = math.floor(price * 0.85) end
        if price > 0 then
            if GRM.HasMoney and not GRM.HasMoney(ply, price) then
                return false, "Нужно " .. price .. " GRM"
            end
            if GRM.TakeMoney then GRM.TakeMoney(ply, price, "покупка заправки") end
        end
        local sid = pump:GetStationID()
        if sid == "" then sid = "st_" .. os.time() .. "_" .. math.random(100, 999) end
        local key = F.CharKey(ply)
        for _, e in ipairs(free) do
            e:SetOwnerKey(key)
            e:SetStationID(sid)
            if (e:GetPriceL() or 0) <= 0 then e:SetPriceL(F.PricePerLiter) end
        end
        F.SavePumps()
        if GRM.PermData and GRM.PermData.Upsert then
            for _, e in ipairs(free) do GRM.PermData.Upsert(e) end
        end
        return true, whole and ("Заправка: " .. #free .. " колонок, " .. price .. " GRM") or ("Колонка куплена за " .. price .. " GRM")
    end

    function F.SetStationPrice(ply, pump, price)
        if not F.IsOwner(ply, pump) then return false, "Это не ваша колонка" end
        price = math.Clamp(math.floor(tonumber(price) or 8), 1, 200)
        local sid = pump:GetStationID()
        for _, e in ipairs(ents.FindByClass("grm_fuel_pump")) do
            if IsValid(e) and (sid == "" and e == pump or e:GetStationID() == sid) and F.IsOwner(ply, e) then
                e:SetPriceL(price)
            end
        end
        F.SavePumps()
        if GRM.PermData and GRM.PermData.Upsert then
            for _, e in ipairs(ents.FindByClass("grm_fuel_pump")) do
                if IsValid(e) and F.IsOwner(ply, e) then GRM.PermData.Upsert(e) end
            end
        end
        return true, "Цена станции: " .. price .. " GRM/л"
    end

    function F.Withdraw(ply, pump)
        if not F.IsOwner(ply, pump) then return false, "Это не ваша колонка" end
        local sid = pump:GetStationID()
        local sum = 0
        for _, e in ipairs(ents.FindByClass("grm_fuel_pump")) do
            if IsValid(e) and (sid == "" and e == pump or e:GetStationID() == sid) and F.IsOwner(ply, e) then
                sum = sum + (e:GetCash() or 0)
                e:SetCash(0)
            end
        end
        if sum <= 0 then return false, "Касса пуста" end
        if GRM.GiveMoney then GRM.GiveMoney(ply, sum, "касса заправки") end
        F.SavePumps()
        return true, "Снято " .. sum .. " GRM"
    end

    net.Receive("GRM_Fuel_Station", function(_, ply)
        if not IsValid(ply) then return end
        ply._grmFuelMenu = ply._grmFuelMenu or 0
        if CurTime() < ply._grmFuelMenu then return end
        ply._grmFuelMenu = CurTime() + 0.25
        local op = string.sub(net.ReadString() or "", 1, 16)
        local ent = net.ReadEntity()
        if not (IsValid(ent) and ent:GetClass() == "grm_fuel_pump") then return end
        local ok, msg
        if op == "buy" then ok, msg = F.BuyPump(ply, ent, false)
        elseif op == "buyall" then ok, msg = F.BuyPump(ply, ent, true)
        elseif op == "price" then ok, msg = F.SetStationPrice(ply, ent, net.ReadFloat())
        elseif op == "cash" then ok, msg = F.Withdraw(ply, ent)
        elseif op == "del" then
            if not (F.IsOwner(ply, ent) or ply:IsSuperAdmin()) then
                ok, msg = false, "Нельзя снять чужую колонку"
            else
                if GRM.Perm and GRM.Perm.Remove then
                    local rok, rmsg = GRM.Perm.Remove(ply, ent, true)
                    if rok then ok, msg = true, "Колонка снята с карты и из перма"
                    elseif IsValid(ent) then ent:Remove() ok, msg = true, "Колонка удалена"
                    else ok, msg = false, tostring(rmsg) end
                else
                    if IsValid(ent) then ent:Remove() end
                    ok, msg = true, "Колонка удалена"
                end
                F.SavePumps()
            end
        else return end
        if GRM.Notify then GRM.Notify(ply, tostring(msg), ok and 120 or 255, ok and 220 or 140, 100) end
    end)

    hook.Add("Think", "GRM_Fuel_Consume", function()
        if GRM.Perf and GRM.Perf.Throttle and not GRM.Perf.Throttle("fuel.tick", 0.5) then return end
        local list = (GRM.Perf and GRM.Perf.Players) and GRM.Perf.Players() or player.GetAll()
        local dirty
        for i = 1, #list do
            local ply = list[i]
            if not (IsValid(ply) and ply:InVehicle()) then continue end
            local veh = F.RootVehicle(ply:GetVehicle())
            if not IsValid(veh) then continue end
            local uid = F.UID(veh)
            if uid == "" then
                F.ApplyNW(veh)
                uid = F.UID(veh)
            end
            if uid == "" then continue end
            local rec = F.Get(uid)
            if rec.liters <= 0 then
                if not veh:GetNWBool("GRM_OutOfFuel", false) then killEngine(veh) end
                continue
            end
            local burn = 0.026
            if ply:KeyDown(IN_FORWARD) then burn = burn + 0.055 end
            if ply:KeyDown(IN_SPEED) then burn = burn + 0.04 end
            if veh:GetNWBool("GRM_VehBroken") then continue end
            rec.liters = math.max(0, rec.liters - burn)
            if GRM.Perf and GRM.Perf.NWFloat then
                GRM.Perf.NWFloat(veh, "GRM_Fuel", rec.liters, 0.05)
                GRM.Perf.NWBool(veh, "GRM_OutOfFuel", false)
            else
                veh:SetNWFloat("GRM_Fuel", rec.liters)
                veh:SetNWBool("GRM_OutOfFuel", false)
            end
            dirty = true
        end
        if dirty then F.Save() end
    end)

    hook.Add("OnEntityCreated", "GRM_Fuel_Spawn", function(ent)
        if GRM.Perf and GRM.Perf.Queue then
            GRM.Perf.Queue("fuel.spawn." .. tostring(ent), function()
                if not IsValid(ent) then return end
                local VK = GRM.VehicleKeys or _G.VK
                if VK and VK.IsVehicle and VK.IsVehicle(ent) then F.ApplyNW(ent) end
            end)
            return
        end
        timer.Simple(0.2, function()
            if not IsValid(ent) then return end
            local VK = GRM.VehicleKeys or _G.VK
            if VK and VK.IsVehicle and VK.IsVehicle(ent) then F.ApplyNW(ent) end
        end)
    end)

    function F.ScrubOrphanRopes()
        local ropes = ents.FindByClass("keyframe_rope")
        if #ropes == 0 then return end
        local fn = function(e)
            if not IsValid(e) then return end
            local a = e.Ent1 or e.GetInternalVariable and e:GetInternalVariable("m_hStartPoint")
            local b = e.Ent2 or e.GetInternalVariable and e:GetInternalVariable("m_hEndPoint")
            local dead = (not IsValid(a) and not IsValid(b))
            if dead then SafeRemoveEntity(e) end
        end
        if GRM.Perf and GRM.Perf.Spread then
            GRM.Perf.Spread("fuel.scrub_ropes", ropes, fn, { chunk = 24 })
        else
            for i = 1, #ropes do fn(ropes[i]) end
        end
        for _, pump in ipairs(ents.FindByClass("grm_fuel_pump")) do
            if IsValid(pump) then F.ClearHose(pump) end
        end
    end

    hook.Add("InitPostEntity", "GRM_Fuel_LoadPumps", function()
        timer.Simple(2, function()
            if #ents.FindByClass("grm_fuel_pump") == 0 then F.LoadPumps() end
            F.ScrubOrphanRopes()
        end)
    end)
    hook.Add("ShutDown", "GRM_Fuel_SavePumps", function() F.SavePumps() end)

    concommand.Add("grm_fuel_scrub", function(ply)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end
        F.ScrubOrphanRopes()
        local msg = "[GRM Fuel] сиротские верёвки сняты порциями"
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, msg) else print(msg) end
    end)

    timer.Simple(0, function()
        if GRM.Perm and GRM.Perm.RegisterClass then GRM.Perm.RegisterClass("grm_fuel_pump", true) end
        if not (GRM.PermData and GRM.PermData.Extract) then return end
        GRM.PermData.Extract["grm_fuel_pump"] = function(ent)
            if not IsValid(ent) then return nil end
            return {
                owner = ent:GetOwnerKey(),
                station = ent:GetStationID(),
                price = ent:GetPriceL(),
                cash = ent:GetCash(),
                kind = ent:GetFuelKind(),
            }
        end
        GRM.PermData.Apply["grm_fuel_pump"] = function(ent, data)
            if not (IsValid(ent) and istable(data)) then return end
            if isstring(data.owner) then ent:SetOwnerKey(data.owner) end
            if isstring(data.station) then ent:SetStationID(data.station) end
            if tonumber(data.price) then ent:SetPriceL(tonumber(data.price)) end
            if tonumber(data.cash) then ent:SetCash(math.floor(tonumber(data.cash))) end
            if isstring(data.kind) and data.kind ~= "" then ent:SetFuelKind(data.kind) end
        end
    end)

    F.Load()
    print("[GRM Fuel] server v" .. F.Version)
end

if CLIENT then
    local function send(op, ent, extra)
        net.Start("GRM_Fuel_Station")
        net.WriteString(op)
        net.WriteEntity(ent)
        if extra then extra() end
        net.SendToServer()
    end

    function F.OpenStation(ent)
        if not IsValid(ent) then return end
        if IsValid(F._menu) then F._menu:Remove() end
        local fr = vgui.Create("DFrame")
        F._menu = fr
        fr:SetSize(380, 260)
        fr:Center()
        fr:SetTitle("")
        fr:MakePopup()
        fr:ShowCloseButton(true)
        fr.Paint = function(_, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(12, 16, 24, 245))
            draw.SimpleText("ЗАПРАВКА", "DermaLarge", 16, 18, Color(250, 185, 63), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local own = ent:GetOwnerKey() or ""
        local price = F.PriceOf(ent)
        local info = vgui.Create("DLabel", fr)
        info:SetPos(16, 44) info:SetSize(348, 40)
        info:SetText(own == "" and ("Свободна. Колонка " .. F.PumpPrice .. " GRM, комплект рядом −15%.")
            or ("Частная. Касса: " .. tostring(ent:GetCash() or 0) .. " GRM"))
        info:SetWrap(true)
        local buy = vgui.Create("DButton", fr)
        buy:SetPos(16, 92) buy:SetSize(168, 32) buy:SetText("Купить колонку")
        buy.DoClick = function() send("buy", ent) fr:Close() end
        local all = vgui.Create("DButton", fr)
        all:SetPos(196, 92) all:SetSize(168, 32) all:SetText("Купить заправку")
        all.DoClick = function() send("buyall", ent) fr:Close() end
        local wang = vgui.Create("DNumberWang", fr)
        wang:SetPos(16, 140) wang:SetSize(120, 28) wang:SetMin(1) wang:SetMax(200) wang:SetValue(price)
        local setp = vgui.Create("DButton", fr)
        setp:SetPos(144, 140) setp:SetSize(220, 28) setp:SetText("Цена GRM / литр (станция)")
        setp.DoClick = function()
            send("price", ent, function() net.WriteFloat(wang:GetValue()) end)
        end
        local cash = vgui.Create("DButton", fr)
        cash:SetPos(16, 184) cash:SetSize(168, 32) cash:SetText("Снять кассу")
        cash.DoClick = function() send("cash", ent) fr:Close() end
        local del = vgui.Create("DButton", fr)
        del:SetPos(196, 184) del:SetSize(168, 32) del:SetText("Удалить колонку")
        del.DoClick = function()
            Derma_Query("Снять колонку с карты и из перма?", "Заправка", "Удалить", function()
                send("del", ent) fr:Close()
            end, "Отмена")
        end
        local hint = vgui.Create("DLabel", fr)
        hint:SetPos(16, 224) hint:SetSize(348, 24)
        hint:SetText("E — пистолет. Shift+E — касса. /permadd — закрепить.")
    end

    hook.Add("PlayerButtonDown", "GRM_Fuel_StationKey", function(ply, btn)
        if ply ~= LocalPlayer() or btn ~= KEY_E then return end
        if not input.IsKeyDown(KEY_LSHIFT) and not input.IsKeyDown(KEY_RSHIFT) then return end
        local tr = ply:GetEyeTrace()
        local e = IsValid(tr.Entity) and tr.Entity
        if IsValid(e) and e:GetClass() == "grm_fuel_pump" and ply:GetPos():DistToSqr(e:GetPos()) < 220 * 220 then
            F.OpenStation(e)
            return true
        end
    end)
end
