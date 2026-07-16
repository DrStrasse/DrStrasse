--[[--------------------------------------------------------------------
    ds_key_swep — Дверные ключи GRM
    Управление замками дверей и открытием меню:
      - ЛКМ: Заблокировать замок (Lock)
      - ПКМ: Разблокировать замок (Unlock)
      - R (Перезарядка): Открыть VGUI-меню двери (/door)
----------------------------------------------------------------------]]

AddCSLuaFile()

SWEP.PrintName = "Дверные ключи"
SWEP.Author = "GRM"
SWEP.Instructions = "ЛКМ: Заблокировать замок | ПКМ: Разблокировать замок | R: Меню управления дверью"
SWEP.Category = "GRM"
SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.DrawWeaponSelection = true
SWEP.ViewModel = "models/weapons/c_arms_citizen.mdl"
SWEP.WorldModel = ""
SWEP.UseHands = true
SWEP.HoldType = "normal"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

local ACTION_COOLDOWN = 0.5

function SWEP:Initialize()
    self:SetHoldType("normal")
end

function SWEP:Deploy()
    self:SetHoldType("normal")
    return true
end

function SWEP:GetAimedDoor()
    local ply = self:GetOwner()
    if not IsValid(ply) then return nil end

    local dist = (GRM and GRM.Doors and GRM.Doors.Config and GRM.Doors.Config.UseDistance) or 180
    local tr = util.TraceLine({
        start = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * dist,
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
    self._nextAction = CurTime() + ACTION_COOLDOWN
    self:SetNextPrimaryFire(self._nextAction)

    if CLIENT and not IsFirstTimePredicted() then return end

    local door = self:GetAimedDoor()
    if not IsValid(door) then return end

    if SERVER then
        local ply = self:GetOwner()
        if not IsValid(ply) or not GRM or not GRM.Doors then return end

        local canAccess = select(1, GRM.Doors.CanAccessDoor(ply, door))
        if not canAccess then
            ply:EmitSound("buttons/button10.wav", 65, 100, 0.7)
            if GRM.Notify then GRM.Notify(ply, "У вас нет ключей от этой двери.", 255, 100, 100) end
            return
        end

        GRM.Doors.LockDoor(door, true)
        ply:EmitSound("doors/door_latch1.wav", 65, 100)
        if GRM.Notify then GRM.Notify(ply, "Замок двери заблокирован.", 100, 220, 100) end
    end

    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
end

function SWEP:SecondaryAttack()
    if CurTime() < (self._nextAction or 0) then return end
    self._nextAction = CurTime() + ACTION_COOLDOWN
    self:SetNextSecondaryFire(self._nextAction)

    if CLIENT and not IsFirstTimePredicted() then return end

    local door = self:GetAimedDoor()
    if not IsValid(door) then return end

    if SERVER then
        local ply = self:GetOwner()
        if not IsValid(ply) or not GRM or not GRM.Doors then return end

        local canAccess = select(1, GRM.Doors.CanAccessDoor(ply, door))
        if not canAccess then
            ply:EmitSound("buttons/button10.wav", 65, 100, 0.7)
            if GRM.Notify then GRM.Notify(ply, "У вас нет ключей от этой двери.", 255, 100, 100) end
            return
        end

        GRM.Doors.LockDoor(door, false)
        ply:EmitSound("doors/door_latch3.wav", 65, 100)
        if GRM.Notify then GRM.Notify(ply, "Замок двери разблокирован.", 100, 220, 100) end
    end

    self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
end

function SWEP:Reload()
    if CurTime() < (self._nextReload or 0) then return end
    self._nextReload = CurTime() + 0.8

    local door = self:GetAimedDoor()
    if not IsValid(door) then return end

    if SERVER then
        local ply = self:GetOwner()
        if IsValid(ply) and GRM and GRM.Doors and GRM.Doors.OpenDoorMenu then
            GRM.Doors.OpenDoorMenu(ply)
        end
    end
end

if CLIENT then
    surface.CreateFont("DSKey_HUD_Hint",  { font = "Roboto", size = 14, weight = 600, extended = true })
    surface.CreateFont("DSKey_HUD_Small", { font = "Roboto", size = 12, weight = 500, extended = true })

    function SWEP:DrawHUD()
        local ply = self:GetOwner()
        if ply ~= LocalPlayer() then return end

        local door = self:GetAimedDoor()
        if not IsValid(door) then return end

        local locked = door:GetNWBool("GRM_DoorLocked", false)
        local title = door:GetNWString("GRM_DoorTitle", "")
        local ownerStr = door:GetNWString("GRM_DoorOwner", "")

        local sw, sh = ScrW(), ScrH()
        local width = 340
        local height = 85
        local x = sw / 2 - width / 2
        local y = sh / 2 + 100

        draw.RoundedBox(8, x, y, width, height, Color(16, 20, 28, 230))
        surface.SetDrawColor(locked and Color(220, 70, 70) or Color(60, 190, 110))
        surface.DrawOutlinedRect(x, y, width, height, 2)

        local dispTitle = title ~= "" and title or "Дверь"
        draw.SimpleText(dispTitle, "DSKey_HUD_Hint", sw / 2, y + 14, Color(240, 245, 250), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local lockTxt = locked and "ЗАБЛОКИРОВАНО" or "РАЗБЛОКИРОВАНО"
        local lockCol = locked and Color(240, 80, 80) or Color(80, 220, 120)
        draw.SimpleText(lockTxt, "DSKey_HUD_Small", sw / 2, y + 32, lockCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        local tips = "ЛКМ: Закрыть | ПКМ: Открыть | R: Меню"
        draw.SimpleText(tips, "DSKey_HUD_Small", sw / 2, y + 58, Color(180, 190, 205), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end
