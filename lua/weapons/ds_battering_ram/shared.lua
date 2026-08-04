--[[--------------------------------------------------------------------
    ds_battering_ram — Таран для силовиков (Код 67)
    Модель: models/weapons/w_rocket_launcher.mdl

    Назначение: Вскрытие запертых дверей при наличии ордера на обыск (/warrant)
    или разрешённого права вскрытия (ForceDoor) через /factions.

    ЛКМ: Удар тараном по двери
----------------------------------------------------------------------]]

AddCSLuaFile()

SWEP.PrintName = "Полицейский таран"
SWEP.Author = "GRM"
SWEP.Instructions = "ЛКМ: Выбить запертую дверь (требуется ордер на обыск или право ForceDoor)"
SWEP.Category = "GRM"
SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.DrawWeaponSelection = true
SWEP.ViewModel = "models/weapons/c_rpg.mdl"
SWEP.WorldModel = "models/weapons/w_rocket_launcher.mdl"
SWEP.UseHands = true
SWEP.HoldType = "rpg"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

local COOLDOWN = 1.8

function SWEP:Initialize()
    self:SetHoldType("rpg")
end

function SWEP:Deploy()
    self:SetHoldType("rpg")
    return true
end

function SWEP:GetAimedDoor()
    local ply = self:GetOwner()
    if not IsValid(ply) then return nil end

    local tr = util.TraceLine({
        start = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 90,
        filter = ply,
        mask = MASK_SHOT,
    })

    local ent = tr.Entity
    if IsValid(ent) then
        if GRM and GRM.Doors and GRM.Doors.IsDoor and GRM.Doors.IsDoor(ent) then
            return ent
        end
        if IsValid(ent:GetParent()) and GRM and GRM.Doors and GRM.Doors.IsDoor and GRM.Doors.IsDoor(ent:GetParent()) then
            return ent:GetParent()
        end
    end
    return nil
end

function SWEP:PrimaryAttack()
    if CurTime() < (self._nextAction or 0) then return end
    self._nextAction = CurTime() + COOLDOWN
    self:SetNextPrimaryFire(self._nextAction)

    if CLIENT and not IsFirstTimePredicted() then return end

    local door = self:GetAimedDoor()
    if not IsValid(door) then return end

    if SERVER then
        local ply = self:GetOwner()
        if not IsValid(ply) or not GRM or not GRM.Doors then return end

        local rec = GRM.Doors.GetRecord and GRM.Doors.GetRecord(door)
        local hasForce = GRM.Doors.AccessManager and GRM.Doors.AccessManager.CanForceDoor and GRM.Doors.AccessManager.CanForceDoor(ply)
        local hasWarrant = false

        if rec and rec.owner_type == "player" and rec.owner_sid ~= "" then
            hasWarrant = GRM.Doors.HasWarrant and GRM.Doors.HasWarrant(rec.owner_sid)
        end

        if not hasForce and not hasWarrant and not ply:IsSuperAdmin() then
            ply:EmitSound("buttons/button10.wav", 65, 100, 0.8)
            if GRM.Notify then
                GRM.Notify(ply, "Вскрытие запрещено: у вас нет ордера на обыск или спец-прав!", 255, 90, 90)
            end
            return
        end

        -- Удар тараном
        ply:EmitSound("physics/wood/wood_box_break1.wav", 85, 100)
        ply:EmitSound("physics/metal/metal_box_break1.wav", 85, 100)

        -- Разблокируем и распахиваем дверь
        GRM.Doors.LockDoor(door, false)
        door:Fire("Open", "", 0.1)

        local partner = GRM.Doors.GetPartnerDoor(door)
        if IsValid(partner) then
            partner:Fire("Open", "", 0.1)
        end

        hook.Run("GRM_OnDoorBreached", ply, door, "battering_ram")

        if GRM.Notify then
            GRM.Notify(ply, "Дверь выбита и разблокирована!", 100, 220, 100)
        end
    end

    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
end

function SWEP:SecondaryAttack()
    self:PrimaryAttack()
end

if CLIENT then
    surface.CreateFont("RAM_HUD_Title", { font = "Roboto", size = 15, weight = 700, extended = true })
    surface.CreateFont("RAM_HUD_Sub",   { font = "Roboto", size = 12, weight = 500, extended = true })

    function SWEP:DrawHUD()
        local ply = self:GetOwner()
        if ply ~= LocalPlayer() then return end

        local door = self:GetAimedDoor()
        if not IsValid(door) then return end

        local sw, sh = ScrW(), ScrH()
        local bw, bh = 320, 60
        local cx, cy = sw / 2, sh / 2 + 100

        draw.RoundedBox(8, cx - bw / 2, cy, bw, bh, Color(18, 22, 32, 235))
        surface.SetDrawColor(235, 120, 50)
        surface.DrawOutlinedRect(cx - bw / 2, cy, bw, bh, 2)

        draw.SimpleText("ПОЛИЦЕЙСКИЙ ТАРАН", "RAM_HUD_Title", cx, cy + 18, Color(240, 245, 250), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("ЛКМ — Выбить дверь с ордером / правом вскрытия", "RAM_HUD_Sub", cx, cy + 40, Color(235, 180, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end
