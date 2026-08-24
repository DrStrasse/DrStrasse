--[[ Топливо GRM v1.1: колонка → пистолет → горловина бака. ]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Fuel = GRM.Fuel or {}
local F = GRM.Fuel
F.Version = "1.1.0"
F.File = "grm_fuel.json"
F.PricePerLiter = 8
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

function F.TankSize(ent)
    return 55
end

function F.TankWorld(ent)
    if not IsValid(ent) then return vector_origin end
    local mn, mx = ent:OBBMins(), ent:OBBMaxs()
    return ent:LocalToWorld(Vector(mn.x + 12, mx.y - 8, (mn.z + mx.z) * 0.35))
end

if SERVER then
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
        rec.liters = math.Clamp(tonumber(rec.liters) or 40, 0, F.TankSize(ent))
        ent:SetNWFloat("GRM_Fuel", rec.liters)
        ent:SetNWFloat("GRM_FuelMax", F.TankSize(ent))
        ent:SetNWString("GRM_FuelType", rec.typ)
    end

    function F.AddLiters(ent, amount, typ)
        if not IsValid(ent) then return 0 end
        ent = F.RootVehicle(ent) or ent
        F.ApplyNW(ent)
        local rec = F.Get(F.UID(ent))
        if typ and rec.typ ~= typ then return 0, "wrong" end
        local max = F.TankSize(ent)
        local room = max - rec.liters
        local add = math.min(room, math.max(0, tonumber(amount) or 0))
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
        end
        local ply = wep:GetOwner()
        if msg and IsValid(ply) and GRM.Notify then GRM.Notify(ply, msg, 180, 210, 140) end
    end

    function F.ReturnNozzle(wep, pump, ply)
        F.StopNozzle(wep)
        if IsValid(wep) then wep:Remove() end
        if IsValid(pump) then
            pump:SetBusy(false)
            pump:SetUser(NULL)
            pump:SetNWEntity("NozzleWep", NULL)
        end
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
            local price = F.PricePerLiter or 8
            if GRM.HasMoney and not GRM.HasMoney(ply, price) then
                F.StopNozzle(wep, "Деньги кончились.")
                return
            end
            local added = select(1, F.AddLiters(veh, 1.15, pump:GetFuelKind())) or 0
            if added <= 0 then
                F.StopNozzle(wep, "Бак полный.")
                return
            end
            if GRM.TakeMoney then GRM.TakeMoney(ply, math.ceil(price * added), "Заправка") end
        end)
        if GRM.Notify then GRM.Notify(ply, "Пистолет в баке. Идёт заливка.", 120, 220, 140) end
    end

    hook.Add("Think", "GRM_Fuel_Consume", function()
        if GRM.Perf and GRM.Perf.Throttle and not GRM.Perf.Throttle("fuel.tick", 0.35) then return end
        for _, ply in ipairs(player.GetAll()) do
            if not (IsValid(ply) and ply:InVehicle()) then continue end
            local veh = F.RootVehicle(ply:GetVehicle())
            if not IsValid(veh) then continue end
            local VK = _G.VK or GRM.VehicleKeys
            if VK and VK.IsVehicle then
                if not VK.IsVehicle(veh) then continue end
            elseif not (veh.IsVehicle and veh:IsVehicle()) and not veh.IsSimfphysCar and not veh.LVS then
                continue
            end
            F.ApplyNW(veh)
            local rec = F.Get(F.UID(veh))
            if rec.liters <= 0 then
                killEngine(veh)
                continue
            end
            veh:SetNWBool("GRM_OutOfFuel", false)
            local burn = 0.018
            if ply:KeyDown(IN_FORWARD) then burn = burn + 0.04 end
            if ply:KeyDown(IN_SPEED) then burn = burn + 0.03 end
            rec.liters = math.max(0, rec.liters - burn)
            veh:SetNWFloat("GRM_Fuel", rec.liters)
        end
    end)

    hook.Add("OnEntityCreated", "GRM_Fuel_Spawn", function(ent)
        timer.Simple(0.2, function()
            if not IsValid(ent) then return end
            local VK = GRM.VehicleKeys or _G.VK
            if VK and VK.IsVehicle and VK.IsVehicle(ent) then F.ApplyNW(ent) end
        end)
    end)

    F.Load()
    print("[GRM Fuel] server v" .. F.Version)
end
