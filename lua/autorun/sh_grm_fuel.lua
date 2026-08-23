--[[ Топливо GRM: бак на UID машины, колонка, расход, глушение. ]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Fuel = GRM.Fuel or {}
local F = GRM.Fuel
F.Version = "1.0.0"
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
        local ok, txt = pcall(util.TableToJSON, F.Data or {}, true)
        if ok and txt then file.Write(F.File, txt) end
    end

    function F.Get(uid)
        uid = tostring(uid or "")
        if uid == "" then return nil end
        F.Data[uid] = F.Data[uid] or { liters = 40, typ = "petrol" }
        return F.Data[uid]
    end

    function F.ApplyNW(ent)
        if not IsValid(ent) then return end
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
        end)
        ent:SetNWBool("GRM_OutOfFuel", true)
    end

    hook.Add("Think", "GRM_Fuel_Consume", function()
        if GRM.Perf and GRM.Perf.Throttle and not GRM.Perf.Throttle("fuel.tick", 0.35) then return end
        for _, ply in ipairs(player.GetAll()) do
            if not (IsValid(ply) and ply:InVehicle()) then continue end
            local veh = ply:GetVehicle()
            if not IsValid(veh) then continue end
            if veh.GetThirdPersonMode and veh.GetParent and IsValid(veh:GetParent()) then
                veh = veh:GetParent()
            end
            local VK = _G.VK
            if VK and VK.IsVehicle then
                if not VK.IsVehicle(veh) then continue end
            elseif not (veh.IsVehicle and veh:IsVehicle()) then
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
end

if CLIENT then
    hook.Add("HUDPaint", "GRM_Fuel_HUD", function()
        local lp = LocalPlayer()
        if not IsValid(lp) or not lp:InVehicle() then return end
        local veh = lp:GetVehicle()
        if IsValid(veh) and veh.GetParent and IsValid(veh:GetParent()) then veh = veh:GetParent() end
        if not IsValid(veh) then return end
        local cur = veh:GetNWFloat("GRM_Fuel", -1)
        if cur < 0 then return end
        local max = math.max(1, veh:GetNWFloat("GRM_FuelMax", 55))
        local pct = cur / max
        local w, h = 160, 10
        local x, y = ScrW() - w - 24, ScrH() - 86
        draw.RoundedBox(4, x - 4, y - 16, w + 8, h + 22, Color(16, 20, 28, 200))
        draw.SimpleText(string.format("Топливо  %.0f л", cur), "DermaDefault", x, y - 14, Color(250, 190, 70), TEXT_ALIGN_LEFT)
        surface.SetDrawColor(40, 40, 40, 220)
        surface.DrawRect(x, y, w, h)
        surface.SetDrawColor(pct < 0.15 and Color(220, 70, 40) or Color(240, 170, 50))
        surface.DrawRect(x, y, w * pct, h)
    end)
end
