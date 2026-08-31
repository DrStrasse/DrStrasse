AddCSLuaFile()
SWEP.PrintName = "Пистолет заправки"
SWEP.Author = "GRM"
SWEP.Spawnable = false
SWEP.AdminOnly = true
SWEP.ViewModel = "models/weapons/c_arms.mdl"
SWEP.WorldModel = "models/props_wasteland/prison_pipefaucet001a.mdl"
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

--[[ ГОРЛОВИНА БЕРЁТСЯ У МАШИНЫ (жалоба владельца 31.08).

     Раньше здесь была своя копия формулы из ядра: 12 юнитов от края
     габарита, 8 от правого борта, 35% высоты. simfphys отдаёт настоящую
     точку — ent:GetFuelPos(). Подсказка «поднеси к горловине бака (зад
     крыла)» ориентировала на точку, которой у половины машин нет. ]]
local function tankPos(veh)
    if not IsValid(veh) then return vector_origin end
    if GRM.Fuel and GRM.Fuel.FillPort then
        local pos = GRM.Fuel.FillPort(veh)
        if isvector(pos) then return pos end
    end
    local mn, mx = veh:OBBMins(), veh:OBBMaxs()
    return veh:LocalToWorld(Vector(mn.x + 12, mx.y - 8, (mn.z + mx.z) * 0.35))
end

--[[ РАДИУС ПОДХОДА СЧИТАЕМ ОТ ВЫСОТЫ МАШИНЫ.
     Была константа 90/110/130 юнитов. У грузовика горловина высоко —
     игрок до неё физически не дотянется, и «вставить пистолет» не
     срабатывало ни с земли, ни с подножки. ]]
local function reach(veh)
    if not IsValid(veh) then return 90 end
    local mn, mx = veh:OBBMins(), veh:OBBMaxs()
    return math.Clamp((mx.z - mn.z) * 0.9 + 60, 90, 220)
end

function SWEP:FindVehicle()
    local ply = self:GetOwner()
    if not IsValid(ply) then return end
    local VK = GRM.VehicleKeys or _G.VK
    local function isVeh(e) return IsValid(e) and VK and VK.IsVehicle and VK.IsVehicle(e) end

    -- 1) смотрим на машину, и цель рядом с горловиной
    local tr = ply:GetEyeTrace()
    if isVeh(tr.Entity) then
        local r = reach(tr.Entity)
        if tr.HitPos:DistToSqr(tankPos(tr.Entity)) < r * r then return tr.Entity end
    end
    -- 2) стоим у горловины вплотную
    for _, ent in ipairs(ents.FindInSphere(ply:GetPos(), 220)) do
        if isVeh(ent) then
            local r = reach(ent) + 30
            if ply:GetPos():DistToSqr(tankPos(ent)) < r * r then return ent end
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
        if GRM.Notify then GRM.Notify(ply, "Поднеси пистолет к горловине бака — она подсвечивается.", 255, 180, 80) end
        return
    end
    local hoseLen = (GRM.Fuel and GRM.Fuel.HoseLength) or 360
    if ply:GetPos():DistToSqr(pump:GetPos()) > hoseLen * hoseLen then
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
                    self:SetRenderOrigin(a.Pos + a.Ang:Forward() * 4 + a.Ang:Right() * 1)
                    local ang = a.Ang
                    ang:RotateAroundAxis(ang:Right(), 90)
                    ang:RotateAroundAxis(ang:Up(), 180)
                    self:SetRenderAngles(ang)
                    self:DrawModel()
                    self:SetRenderOrigin()
                    self:SetRenderAngles()
                    return
                end
            end
        end
        self:DrawModel()
    end
    function SWEP:GetViewModelPosition(pos, ang)
        pos = pos + ang:Forward() * 18 + ang:Right() * 8 - ang:Up() * 6
        ang:RotateAroundAxis(ang:Right(), 20)
        ang:RotateAroundAxis(ang:Up(), 90)
        return pos, ang
    end
    function SWEP:PreDrawViewModel()
        return true
    end
    function SWEP:PostDrawViewModel(_, _, vm)
        local ply = self:GetOwner()
        if not IsValid(ply) then return end
        local pos, ang = ply:EyePos(), ply:EyeAngles()
        pos = pos + ang:Forward() * 22 + ang:Right() * 9 - ang:Up() * 8
        ang:RotateAroundAxis(ang:Right(), 15)
        ang:RotateAroundAxis(ang:Up(), 95)
        render.Model({ model = self.WorldModel, pos = pos, angle = ang })
    end
    function SWEP:DrawHUD()
        local ins = self:GetNWBool("Inserted")
        local txt = ins and "ЛКМ / R — вынуть   ПКМ — повесить" or "ЛКМ — вставить в бак   ПКМ — повесить"
        draw.SimpleTextOutlined(txt, "DermaDefault", ScrW() / 2, ScrH() - 86, Color(250, 190, 70), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
        local sl, pay = self:GetNWFloat("SessL", 0), self:GetNWFloat("SessPay", 0)
        local now, mx = self:GetNWFloat("TankNow", 0), self:GetNWFloat("TankMax", 0)
        if sl > 0 or ins then
            local line = string.format("сессия  %.1f л   %.0f GRM", sl, pay)
            if mx > 0 then line = line .. string.format("   бак %.0f / %.0f", now, mx) end
            draw.SimpleTextOutlined(line, "DermaDefault", ScrW() / 2, ScrH() - 64, Color(220, 230, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
        end
    end
end
