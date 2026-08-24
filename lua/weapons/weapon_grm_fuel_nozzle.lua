AddCSLuaFile()
SWEP.PrintName = "Пистолет заправки"
SWEP.Author = "GRM"
SWEP.Spawnable = false
SWEP.AdminOnly = true
SWEP.ViewModel = "models/weapons/c_pistol.mdl"
SWEP.WorldModel = "models/props_junk/gascan001a.mdl"
SWEP.UseHands = true
SWEP.HoldType = "slam"
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.DrawAmmo = false
SWEP.Slot = 5

function SWEP:Initialize()
    self:SetHoldType(self.HoldType)
    self:SetNWBool("Inserted", false)
end

function SWEP:Deploy()
    self:SetHoldType(self.HoldType)
    return true
end

local function pumpOf(wep)
    return IsValid(wep) and wep.GetNWEntity and wep:GetNWEntity("GRM_Pump") or NULL
end

local function tankPos(veh)
    if not IsValid(veh) then return vector_origin end
    local mn, mx = veh:OBBMins(), veh:OBBMaxs()
    return veh:LocalToWorld(Vector(mn.x + 12, mx.y - 8, (mn.z + mx.z) * 0.35))
end

function SWEP:FindVehicle()
    local ply = self:GetOwner()
    if not IsValid(ply) then return end
    local tr = ply:GetEyeTrace()
    local e = tr.Entity
    local VK = GRM.VehicleKeys or _G.VK
    if IsValid(e) and VK and VK.IsVehicle and VK.IsVehicle(e) then
        if tr.HitPos:DistToSqr(tankPos(e)) < 90 * 90 then return e end
        if ply:GetPos():DistToSqr(tankPos(e)) < 110 * 110 then return e end
    end
    for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), 140)) do
        if IsValid(ent) and VK and VK.IsVehicle and VK.IsVehicle(ent) then
            if ply:GetPos():DistToSqr(tankPos(ent)) < 130 * 130 then return ent end
        end
    end
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 0.4)
    if CLIENT then return end
    local ply = self:GetOwner()
    local pump = pumpOf(self)
    if not IsValid(pump) then
        if GRM.Notify then GRM.Notify(ply, "Пистолет не от колонки.", 255, 140, 80) end
        return
    end
    if self:GetNWBool("Inserted") then
        if GRM.Fuel and GRM.Fuel.StopNozzle then GRM.Fuel.StopNozzle(self, "Пистолет вынут.") end
        return
    end
    local veh = self:FindVehicle()
    if not IsValid(veh) then
        if GRM.Notify then GRM.Notify(ply, "Поднеси пистолет к горловине бака (зад крыла).", 255, 180, 80) end
        return
    end
    if ply:GetPos():DistToSqr(pump:GetPos()) > 420 * 420 then
        if GRM.Notify then GRM.Notify(ply, "Шланг не дотягивается.", 255, 160, 80) end
        return
    end
    if GRM.Fuel and GRM.Fuel.StartNozzle then GRM.Fuel.StartNozzle(self, pump, veh, ply) end
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.5)
    if CLIENT then return end
    local pump = pumpOf(self)
    if GRM.Fuel and GRM.Fuel.ReturnNozzle then GRM.Fuel.ReturnNozzle(self, pump, self:GetOwner()) end
end

function SWEP:Reload()
    if CLIENT then return end
    if self:GetNWBool("Inserted") and GRM.Fuel and GRM.Fuel.StopNozzle then
        GRM.Fuel.StopNozzle(self, "Пистолет вынут.")
    end
end

function SWEP:Holster()
    if SERVER and GRM.Fuel and GRM.Fuel.StopNozzle then GRM.Fuel.StopNozzle(self) end
    return true
end

function SWEP:OnRemove()
    if SERVER and GRM.Fuel and GRM.Fuel.StopNozzle then GRM.Fuel.StopNozzle(self) end
end

if CLIENT then
    function SWEP:DrawWorldModel()
        local ply = self:GetOwner()
        if IsValid(ply) then
            local att = ply:LookupAttachment("anim_attachment_RH")
            if att and att > 0 then
                local a = ply:GetAttachment(att)
                if a then
                    self:SetRenderOrigin(a.Pos)
                    self:SetRenderAngles(a.Ang)
                    self:DrawModel()
                    self:SetRenderOrigin()
                    self:SetRenderAngles()
                    return
                end
            end
        end
        self:DrawModel()
    end
    function SWEP:DrawHUD()
        local txt = self:GetNWBool("Inserted") and "ЛКМ / R — вынуть   ПКМ — повесить" or "ЛКМ — вставить в бак   ПКМ — повесить на колонку"
        draw.SimpleTextOutlined(txt, "DermaDefault", ScrW() / 2, ScrH() - 72, Color(250, 190, 70), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
    end
end
