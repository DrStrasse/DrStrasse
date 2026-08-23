--[[ Лежание GRM. Чужой prone-аддон не копируем: если он уже есть — уступаем.
     Свой режим: /prone, двойной Ctrl, bind grm_prone. ]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Prone = GRM.Prone or {}

local function foreignProne(ply)
    if not IsValid(ply) then return false end
    if ply.IsProne and ply:IsProne() then return true end
    if ply.GetProne and ply:GetProne() then return true end
    return false
end

local function setProne(ply, on)
    if not IsValid(ply) or not ply:Alive() then return false end
    if ply:InVehicle() or ply:WaterLevel() >= 2 then return false end
    if ply:GetNWBool("GRM_CharacterPending", false) then return false end
    on = on == true
    ply:SetNWBool("GRM_Prone", on)
    if on then
        ply:SetHull(Vector(-16, -16, 0), Vector(16, 16, 24))
        ply:SetHullDuck(Vector(-16, -16, 0), Vector(16, 16, 24))
        ply:SetViewOffset(Vector(0, 0, 18))
        ply:SetViewOffsetDucked(Vector(0, 0, 14))
        ply:SetWalkSpeed(54)
        ply:SetRunSpeed(54)
        ply:SetDuckSpeed(0.1)
    else
        ply:ResetHull()
        ply:SetViewOffset(Vector(0, 0, 64))
        ply:SetViewOffsetDucked(Vector(0, 0, 28))
        local cfg = GRM.Movement and GRM.Movement.Config
        ply:SetWalkSpeed((cfg and cfg.WalkSpeed) or 160)
        ply:SetRunSpeed((cfg and cfg.RunSpeed) or 220)
    end
    return true
end

function GRM.Prone.Is(ply)
    return IsValid(ply) and (ply:GetNWBool("GRM_Prone", false) or foreignProne(ply))
end

function GRM.Prone.Toggle(ply)
    if foreignProne(ply) then return false end
    return setProne(ply, not ply:GetNWBool("GRM_Prone", false))
end

if SERVER then
    util.AddNetworkString("GRM_ProneToggle")

    net.Receive("GRM_ProneToggle", function(_, ply)
        if not IsValid(ply) then return end
        if GRM.Net and GRM.Net.Guard and not GRM.Net.Guard(ply, "prone.toggle", { rate = 0.4, burst = 2, maxBits = 32 }) then return end
        GRM.Prone.Toggle(ply)
    end)

    hook.Add("PlayerSpawn", "GRM_Prone_Reset", function(ply)
        timer.Simple(0, function() if IsValid(ply) then setProne(ply, false) end end)
    end)

    hook.Add("CanPlayerEnterVehicle", "GRM_Prone_NoVeh", function(ply)
        if IsValid(ply) and ply:GetNWBool("GRM_Prone", false) then
            setProne(ply, false)
        end
    end)

    hook.Add("Move", "GRM_Prone_Move", function(ply, mv)
        if not IsValid(ply) or not ply:GetNWBool("GRM_Prone", false) then return end
        local vel = mv:GetVelocity()
        local spd = vel:Length2D()
        if spd > 56 then
            local r = 56 / spd
            mv:SetVelocity(Vector(vel.x * r, vel.y * r, vel.z))
        end
        if ply:KeyPressed(IN_JUMP) then
            setProne(ply, false)
        end
    end)

    hook.Add("PlayerSay", "GRM_Prone_Cmd", function(ply, text)
        local t = string.lower(string.Trim(text or ""))
        if t == "/prone" or t == "!prone" or t == "/лечь" then
            GRM.Prone.Toggle(ply)
            return ""
        end
    end)
end

if CLIENT then
    local lastDuck = 0
    hook.Add("PlayerBindPress", "GRM_Prone_DoubleDuck", function(ply, bind, pressed)
        if not pressed or ply ~= LocalPlayer() then return end
        if bind ~= "+duck" then return end
        local now = CurTime()
        if now - lastDuck < 0.35 then
            net.Start("GRM_ProneToggle") net.SendToServer()
            lastDuck = 0
            return true
        end
        lastDuck = now
    end)

    concommand.Add("grm_prone", function()
        net.Start("GRM_ProneToggle") net.SendToServer()
    end)

    hook.Add("CalcMainActivity", "GRM_Prone_Anim", function(ply)
        if not IsValid(ply) or not ply:GetNWBool("GRM_Prone", false) then return end
        local seq = ply:LookupSequence("zombie_slump_idle_01")
        if seq and seq >= 0 then return ACT_HL2MP_SWIM_IDLE, seq end
    end)
end
