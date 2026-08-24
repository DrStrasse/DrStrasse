-- Свой приборник: скорость + топливо. Стандарт simfphys/LVS гасим.
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
timer.Create("GRM_VehHUD_HideStock", 8, 0, hideStock)

hook.Add("HUDShouldDraw", "GRM_VehHUD_HideNames", function(name)
    if not LocalPlayer():InVehicle() then return end
    if name == "CHudHealth" or name == "CHudBattery" or name == "CHudDamageIndicator" then
        return false
    end
end)

surface.CreateFont("GRMVeh_Big", { font = "Roboto", size = 28, weight = 800, extended = true })
surface.CreateFont("GRMVeh_Mid", { font = "Roboto", size = 15, weight = 700, extended = true })
surface.CreateFont("GRMVeh_Sm", { font = "Roboto", size = 12, weight = 600, extended = true })

local function rootVeh(ent)
    if GRM.Fuel and GRM.Fuel.RootVehicle then return GRM.Fuel.RootVehicle(ent) end
    if IsValid(ent) and IsValid(ent:GetParent()) then return ent:GetParent() end
    return ent
end

hook.Remove("HUDPaint", "GRM_Fuel_HUD")

hook.Add("HUDPaint", "GRM_Vehicle_Cluster", function()
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:InVehicle() then return end
    if GRM.AugHUD and GRM.AugHUD.IsActive and GRM.AugHUD.IsActive() then return end
    local veh = rootVeh(lp:GetVehicle())
    if not IsValid(veh) then return end
    local vel = veh:GetVelocity():Length()
    if veh.GetVelocity and veh.GetChassis then
        local ch = veh:GetChassis()
        if IsValid(ch) then vel = ch:GetVelocity():Length() end
    end
    local kmh = math.floor(vel * 0.09144)
    local fuel = veh:GetNWFloat("GRM_Fuel", -1)
    local fmax = math.max(1, veh:GetNWFloat("GRM_FuelMax", 55))
    local typ = veh:GetNWString("GRM_FuelType", "petrol")
    local typN = (GRM.Fuel.Types and GRM.Fuel.Types[typ]) or typ
    local empty = veh:GetNWBool("GRM_OutOfFuel", false) or (fuel >= 0 and fuel <= 0.05)

    local w, h = 268, 92
    local x, y = ScrW() / 2 - w / 2, ScrH() - h - 28
    draw.RoundedBox(10, x, y, w, h, Color(10, 14, 22, 230))
    surface.SetDrawColor(55, 117, 151, 180)
    surface.DrawOutlinedRect(x, y, w, h, 1)
    draw.SimpleText(string.format("%d", kmh), "GRMVeh_Big", x + 22, y + 18, Color(235, 242, 250))
    draw.SimpleText("км/ч", "GRMVeh_Sm", x + 22, y + 48, Color(140, 160, 180))
    if fuel >= 0 then
        local pct = math.Clamp(fuel / fmax, 0, 1)
        local bx, by, bw, bh = x + 118, y + 28, 132, 12
        draw.SimpleText(typN, "GRMVeh_Sm", bx, y + 10, Color(250, 185, 63))
        surface.SetDrawColor(30, 36, 46)
        surface.DrawRect(bx, by, bw, bh)
        surface.SetDrawColor(pct < 0.15 and Color(220, 70, 50) or Color(240, 170, 50))
        surface.DrawRect(bx, by, bw * pct, bh)
        draw.SimpleText(string.format("%.0f / %.0f л", fuel, fmax), "GRMVeh_Sm", bx, by + 16, Color(210, 220, 230))
        if empty then
            draw.SimpleText("НЕТ ТОПЛИВА", "GRMVeh_Mid", x + w / 2, y + 74, Color(230, 80, 70), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    else
        draw.SimpleText("бак не привязан", "GRMVeh_Sm", x + 118, y + 32, Color(140, 160, 180))
    end
end)

print("[GRM Fuel] vehicle HUD")
