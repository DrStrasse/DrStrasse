--[[ Круиз и автопилот: /cruise 30 — потолок, /autopilot 50 — сам жмёт газ. ]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Cruise = GRM.Cruise or {}
local C = GRM.Cruise
C.Version = "1.0.0"

local function root(ent)
    if GRM.Fuel and GRM.Fuel.RootVehicle then return GRM.Fuel.RootVehicle(ent) end
    if IsValid(ent) and IsValid(ent.GetParent and ent:GetParent()) then return ent:GetParent() end
    return ent
end

local function kmh(ent)
    if not IsValid(ent) then return 0 end
    local v = ent:GetVelocity()
    if ent.GetChassis then
        local ch = ent:GetChassis()
        if IsValid(ch) then v = ch:GetVelocity() end
    end
    return v:Length() * 0.09144
end

local function clear(ply)
    if not IsValid(ply) then return end
    ply:SetNWBool("GRM_AutoPilot", false)
    ply:SetNWBool("GRM_CruiseOn", false)
    ply:SetNWInt("GRM_CruiseKmh", 0)
end

if SERVER then
    util.AddNetworkString("GRM_Cruise")

    local function setMode(ply, mode, speed)
        if not IsValid(ply) or not ply:InVehicle() then
            return false, "Садись за руль."
        end
        speed = math.Clamp(math.floor(tonumber(speed) or 0), 0, 200)
        if speed <= 0 or mode == "off" then
            clear(ply)
            return true, "Круиз и автопилот сняты."
        end
        ply:SetNWInt("GRM_CruiseKmh", speed)
        if mode == "auto" then
            ply:SetNWBool("GRM_AutoPilot", true)
            ply:SetNWBool("GRM_CruiseOn", true)
            return true, "Автопилот " .. speed .. " км/ч. S или /cruise 0 — стоп."
        end
        ply:SetNWBool("GRM_AutoPilot", false)
        ply:SetNWBool("GRM_CruiseOn", true)
        return true, "Круиз: не быстрее " .. speed .. " км/ч."
    end

    net.Receive("GRM_Cruise", function(_, ply)
        if not IsValid(ply) then return end
        ply._grmCruise = ply._grmCruise or 0
        if CurTime() < ply._grmCruise then return end
        ply._grmCruise = CurTime() + 0.2
        local mode = string.sub(net.ReadString() or "", 1, 8)
        local speed = net.ReadUInt(8)
        local ok, msg = setMode(ply, mode, speed)
        if GRM.Notify then GRM.Notify(ply, msg, ok and 120 or 255, ok and 210 or 140, 90) end
    end)

    hook.Add("PlayerLeaveVehicle", "GRM_Cruise_Leave", function(ply) clear(ply) end)
    hook.Add("PlayerDeath", "GRM_Cruise_Die", function(ply) clear(ply) end)

    hook.Add("Think", "GRM_Cruise_Cap", function()
        if GRM.Perf and GRM.Perf.Throttle and not GRM.Perf.Throttle("cruise.cap", 0.05) then return end
        for _, ply in ipairs(player.GetAll()) do
            if not (IsValid(ply) and ply:InVehicle() and ply:GetNWBool("GRM_CruiseOn")) then continue end
            local cap = ply:GetNWInt("GRM_CruiseKmh", 0)
            if cap <= 0 then continue end
            local veh = root(ply:GetVehicle())
            if not IsValid(veh) then continue end
            local speed = kmh(veh)
            if speed > cap + 1 then
                local phys = veh:GetPhysicsObject()
                if IsValid(phys) then
                    local v = phys:GetVelocity()
                    local want = cap / math.max(0.1, speed)
                    phys:SetVelocity(v * want)
                else
                    local v = veh:GetVelocity()
                    veh:SetVelocity(v * (cap / math.max(0.1, speed)) - v)
                end
            end
        end
    end)

    hook.Add("PlayerSayTransform", "GRM_Cruise_Chat", function(ply, pack)
        if not istable(pack) then return end
        local t = string.lower(string.Trim(pack[1] or ""))
        local mode, num
        local a, b = t:match("^/(autopilot)%s*(%d*)$")
        if not a then a, b = t:match("^/(автопилот)%s*(%d*)$") end
        if a then mode = (b == "" or b == "0") and "off" or "auto" num = tonumber(b) or 0 end
        if not mode then
            local c, d = t:match("^/(cruise)%s*(%d*)$")
            if not c then c, d = t:match("^/(круиз)%s*(%d*)$") end
            if c then mode = (d == "" or d == "0") and "off" or "cruise" num = tonumber(d) or 0 end
        end
        if not mode then return end
        local ok, msg = setMode(ply, mode, num)
        if GRM.Notify then GRM.Notify(ply, msg, ok and 120 or 255, ok and 210 or 140, 90) end
        pack[1] = ""
        pack.SkipPlayerSay = true
    end)

    print("[GRM Cruise] server v" .. C.Version)
end

if CLIENT then
    hook.Add("CreateMove", "GRM_Cruise_Drive", function(cmd)
        local lp = LocalPlayer()
        if not IsValid(lp) or not lp.InVehicle or not lp:InVehicle() then return end
        local cap = lp:GetNWInt("GRM_CruiseKmh", 0)
        if cap <= 0 then return end
        if bit.band(cmd:GetButtons(), IN_BACK) ~= 0 then
            if lp:GetNWBool("GRM_AutoPilot") then
                net.Start("GRM_Cruise") net.WriteString("off") net.WriteUInt(0, 8) net.SendToServer()
            end
            return
        end
        local veh = root(lp:GetVehicle())
        local speed = kmh(veh)
        if lp:GetNWBool("GRM_AutoPilot") then
            if speed < cap - 1 then
                cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_FORWARD))
            elseif speed > cap + 0.8 then
                cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(IN_FORWARD)))
            else
                cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_FORWARD))
            end
        elseif lp:GetNWBool("GRM_CruiseOn") and speed >= cap then
            cmd:SetButtons(bit.band(cmd:GetButtons(), bit.bnot(IN_FORWARD)))
        end
    end)

    hook.Add("HUDPaint", "GRM_Cruise_HUD", function()
        local lp = LocalPlayer()
        if not IsValid(lp) or not lp.InVehicle or not lp:InVehicle() then return end
        if not lp:GetNWBool("GRM_CruiseOn") then return end
        local cap = lp:GetNWInt("GRM_CruiseKmh", 0)
        local mode = lp:GetNWBool("GRM_AutoPilot") and "АВТОПИЛОТ" or "КРУИЗ"
        draw.SimpleTextOutlined(mode .. "  " .. cap .. " км/ч", "DermaDefault", ScrW() / 2, ScrH() - 132,
            Color(250, 185, 63), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
    end)
end
