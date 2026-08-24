-- Свой приборник: скорость, топливо, прочность, места.
if not CLIENT then return end

GRM = GRM or {}
GRM.Fuel = GRM.Fuel or {}

local function hideStock()
    local cmds = {
        "cl_simfphys_hud", "0",
        "cl_simfphys_healthtips", "0",
        "cl_simfphys_ms_cursor", "0",
        "lvs_showhud", "0",
        "lvs_hud", "0",
        "cl_lvs_hud", "0",
    }
    for i = 1, #cmds, 2 do
        if ConVarExists(cmds[i]) then RunConsoleCommand(cmds[i], cmds[i + 1]) end
    end
end
hook.Add("InitPostEntity", "GRM_VehHUD_HideStock", hideStock)
timer.Create("GRM_VehHUD_HideStock", 12, 2, hideStock)

hook.Add("HUDShouldDraw", "GRM_VehHUD_HideNames", function(name)
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp.InVehicle or not lp:InVehicle() then return end
    if name == "CHudHealth" or name == "CHudBattery" or name == "CHudDamageIndicator" then
        return false
    end
end)

surface.CreateFont("GRMVeh_Big", { font = "Roboto", size = 28, weight = 800, extended = true })
surface.CreateFont("GRMVeh_Mid", { font = "Roboto", size = 15, weight = 700, extended = true })
surface.CreateFont("GRMVeh_Sm", { font = "Roboto", size = 12, weight = 600, extended = true })
surface.CreateFont("GRMVeh_Seat", { font = "Roboto", size = 13, weight = 600, extended = true })

local function rootVeh(ent)
    if GRM.Fuel and GRM.Fuel.RootVehicle then return GRM.Fuel.RootVehicle(ent) end
    if IsValid(ent) and IsValid(ent:GetParent()) then return ent:GetParent() end
    return ent
end

local function lerpCol(a, b, t)
    t = math.Clamp(t, 0, 1)
    return Color(
        a.r + (b.r - a.r) * t,
        a.g + (b.g - a.g) * t,
        a.b + (b.b - a.b) * t,
        255
    )
end

local function hpColor(pct)
    if pct >= 0.5 then
        return lerpCol(Color(230, 190, 50), Color(70, 200, 95), (pct - 0.5) / 0.5)
    end
    if pct >= 0.22 then
        return lerpCol(Color(220, 70, 50), Color(230, 190, 50), (pct - 0.22) / 0.28)
    end
    return Color(210, 45, 40)
end

local function addSeat(list, seen, seat, driver)
    if not IsValid(seat) then return end
    if not seat.IsVehicle or not seat:IsVehicle() then return end
    local id = seat:EntIndex()
    if seen[id] then
        if driver then seen[id].driver = true end
        return
    end
    local row = { seat = seat, driver = driver and true or false }
    seen[id] = row
    list[#list + 1] = row
end

local function pullValue(list, seen, val, driver)
    if IsValid(val) then
        addSeat(list, seen, val, driver)
        return
    end
    if not istable(val) then return end
    for _, v in pairs(val) do
        if IsValid(v) then addSeat(list, seen, v, driver)
        elseif istable(v) then pullValue(list, seen, v, driver) end
    end
end

local function callM(ent, name)
    if not IsValid(ent) or not ent[name] then return nil end
    local ok, r = pcall(ent[name], ent)
    if ok then return r end
    return nil
end

local seatCache, seatCacheT, seatCacheEnt = {}, 0, NULL

local function collectSeats(veh)
    if not IsValid(veh) then return {} end
    if seatCacheEnt == veh and CurTime() - seatCacheT < 0.35 then return seatCache end
    local list, seen = {}, {}
    pullValue(list, seen, callM(veh, "GetDriverSeat"), true)
    pullValue(list, seen, callM(veh, "GetDriverSeatEntity"), true)
    pullValue(list, seen, veh.DriverSeat, true)
    pullValue(list, seen, veh.driverSeat, true)
    pullValue(list, seen, callM(veh, "GetPassengerSeats"), false)
    pullValue(list, seen, callM(veh, "GetPassengerSeat"), false)
    pullValue(list, seen, veh.pSeat, false)
    pullValue(list, seen, veh.pSeats, false)
    pullValue(list, seen, veh.PassengerSeats, false)
    pullValue(list, seen, callM(veh, "GetSeats"), false)
    for _, ch in ipairs(veh:GetChildren()) do
        if IsValid(ch) and ch.IsVehicle and ch:IsVehicle() then
            addSeat(list, seen, ch, false)
        end
    end
    if veh.IsVehicle and veh:IsVehicle() then
        local cls = string.lower(veh:GetClass() or "")
        addSeat(list, seen, veh, cls ~= "prop_vehicle_prisoner_pod")
    end
    local hasDriver = false
    for i = 1, #list do
        if list[i].driver then hasDriver = true break end
    end
    table.sort(list, function(a, b)
        return a.seat:EntIndex() < b.seat:EntIndex()
    end)
    if not hasDriver and #list > 0 then
        list[1].driver = true
    end
    seatCache, seatCacheT, seatCacheEnt = list, CurTime(), veh
    return list
end

local function occupantName(seat)
    if not IsValid(seat) then return nil end
    local d
    if seat.GetDriver then
        local ok, r = pcall(seat.GetDriver, seat)
        if ok then d = r end
    end
    if not IsValid(d) and seat.GetPassenger then
        local ok, r = pcall(seat.GetPassenger, seat)
        if ok then d = r end
    end
    if IsValid(d) and d.IsPlayer and d:IsPlayer() then
        return d:Nick()
    end
    return nil
end

local function vehTitle(veh)
    if GRM.VehicleKeys and GRM.VehicleKeys.GetVehicleDisplayName then
        local ok, n = pcall(GRM.VehicleKeys.GetVehicleDisplayName, veh)
        if ok and isstring(n) and n ~= "" then return n end
    end
    if veh.GetVehicleName then
        local ok, n = pcall(veh.GetVehicleName, veh)
        if ok and isstring(n) and n ~= "" then return n end
    end
    local pr = veh.PrintName or veh.VehicleName
    if isstring(pr) and pr ~= "" then return pr end
    return veh:GetClass() or "транспорт"
end

hook.Remove("HUDPaint", "GRM_Fuel_HUD")

hook.Add("HUDPaint", "GRM_Vehicle_Cluster", function()
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp.InVehicle or not lp:InVehicle() then return end
    if GRM.AugHUD and GRM.AugHUD.IsActive and GRM.AugHUD.IsActive() then return end
    local veh = rootVeh(lp:GetVehicle())
    if not IsValid(veh) then return end

    local vel = veh:GetVelocity():Length()
    if veh.GetChassis then
        local ch = veh:GetChassis()
        if IsValid(ch) then vel = ch:GetVelocity():Length() end
    end
    local kmh = math.floor(vel * 0.09144)
    local fuel = veh:GetNWFloat("GRM_Fuel", -1)
    local fmax = math.max(1, veh:GetNWFloat("GRM_FuelMax", 55))
    local typ = veh:GetNWString("GRM_FuelType", "petrol")
    local typN = (GRM.Fuel.Types and GRM.Fuel.Types[typ]) or typ
    local empty = veh:GetNWBool("GRM_OutOfFuel", false) or (fuel >= 0 and fuel <= 0.05)
    local hp = veh:GetNWFloat("GRM_VehHP", -1)
    local hpmax = math.max(1, veh:GetNWFloat("GRM_VehHPMax", 100))
    local broken = veh:GetNWBool("GRM_VehBroken", false)

    local w, h = 280, 108
    local x, y = ScrW() / 2 - w / 2, ScrH() - h - 28
    draw.RoundedBox(10, x, y, w, h, Color(10, 14, 22, 230))
    surface.SetDrawColor(55, 117, 151, 180)
    surface.DrawOutlinedRect(x, y, w, h, 1)
    draw.SimpleText(string.format("%d", kmh), "GRMVeh_Big", x + 22, y + 14, Color(235, 242, 250))
    draw.SimpleText("км/ч", "GRMVeh_Sm", x + 22, y + 44, Color(140, 160, 180))

    if fuel >= 0 then
        local pct = math.Clamp(fuel / fmax, 0, 1)
        local bx, by, bw, bh = x + 118, y + 24, 140, 10
        draw.SimpleText(typN, "GRMVeh_Sm", bx, y + 8, Color(250, 185, 63))
        surface.SetDrawColor(30, 36, 46)
        surface.DrawRect(bx, by, bw, bh)
        surface.SetDrawColor(pct < 0.15 and Color(220, 70, 50) or Color(240, 170, 50))
        surface.DrawRect(bx, by, bw * pct, bh)
        draw.SimpleText(string.format("%.0f / %.0f л", fuel, fmax), "GRMVeh_Sm", bx, by + 12, Color(210, 220, 230))
        if empty then
            draw.SimpleText("НЕТ ТОПЛИВА", "GRMVeh_Mid", x + w / 2, y + 62, Color(230, 80, 70), TEXT_ALIGN_CENTER)
        end
    else
        draw.SimpleText("бак не привязан", "GRMVeh_Sm", x + 118, y + 28, Color(140, 160, 180))
    end

    if hp >= 0 then
        local pct = math.Clamp(hp / hpmax, 0, 1)
        local bx, by, bw, bh = x + 18, y + h - 20, w - 36, 10
        draw.SimpleText(broken and "ПОЛОМКА" or "прочность", "GRMVeh_Sm", bx, by - 14, broken and Color(230, 80, 70) or Color(180, 195, 210))
        draw.SimpleText(string.format("%d / %d", math.floor(hp + 0.5), math.floor(hpmax)), "GRMVeh_Sm", bx + bw, by - 14, Color(200, 210, 220), TEXT_ALIGN_RIGHT)
        surface.SetDrawColor(28, 32, 40)
        surface.DrawRect(bx, by, bw, bh)
        surface.SetDrawColor(hpColor(pct))
        surface.DrawRect(bx, by, math.max(0, bw * pct), bh)
        surface.SetDrawColor(0, 0, 0, 90)
        surface.DrawOutlinedRect(bx, by, bw, bh, 1)
    end

    local seats = collectSeats(veh)
    if #seats == 0 then return end
    local rowH = 18
    local boxH = 28 + #seats * rowH
    local boxW = 248
    local sx = ScrW() - boxW - 18
    local sy = math.floor(ScrH() * 0.5 - boxH * 0.5)
    draw.RoundedBox(8, sx, sy, boxW, boxH, Color(10, 14, 22, 228))
    surface.SetDrawColor(55, 117, 151, 170)
    surface.DrawOutlinedRect(sx, sy, boxW, boxH, 1)
    draw.SimpleText(vehTitle(veh), "GRMVeh_Sm", sx + 10, sy + 6, Color(180, 200, 215))
    local freeN = 0
    for i = 1, #seats do
        if not occupantName(seats[i].seat) then freeN = freeN + 1 end
    end
    draw.SimpleText(string.format("%d мест · свободно %d", #seats, freeN), "GRMVeh_Sm", sx + boxW - 10, sy + 6, Color(130, 150, 165), TEXT_ALIGN_RIGHT)
    for i = 1, #seats do
        local who = occupantName(seats[i].seat)
        local label = "Место " .. i
        if seats[i].driver then label = label .. " (водитель)" end
        local status, col
        if who then
            status = "Занято: " .. who
            col = Color(230, 160, 90)
        else
            status = "Свободно"
            col = Color(90, 200, 120)
        end
        local ly = sy + 22 + (i - 1) * rowH
        draw.SimpleText(label, "GRMVeh_Seat", sx + 10, ly, Color(220, 228, 236))
        draw.SimpleText(status, "GRMVeh_Seat", sx + boxW - 10, ly, col, TEXT_ALIGN_RIGHT)
    end
end)

print("[GRM Fuel] vehicle HUD seats+hp")
