--[[--------------------------------------------------------------------
    ds_lockpick — Отмычка для взлома дверей (Код 68)

    Назначение: Взлом запертых дверей с прогресс-баром и звуками защелки.
    ЛКМ: Удерживать прицел на запертой двери для взлома.
----------------------------------------------------------------------]]

AddCSLuaFile()

SWEP.PrintName = "Отмычка"
SWEP.Author = "GRM"
SWEP.Instructions = "ЛКМ: Начать взлом запертой двери (удерживайте прицел)"
SWEP.Category = "GRM"
SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.DrawWeaponSelection = true
SWEP.ViewModel = "models/weapons/c_crowbar.mdl"
SWEP.WorldModel = "models/weapons/w_crowbar.mdl"
SWEP.UseHands = true
SWEP.HoldType = "crowbar"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

local PICK_TIME = 7.5

function SWEP:Initialize()
    self:SetHoldType("crowbar")
end

function SWEP:Deploy()
    self:SetHoldType("crowbar")
    self._picking = false
    self._pickStart = 0
    return true
end

function SWEP:Holster()
    self._picking = false
    self._pickStart = 0
    return true
end

function SWEP:GetAimedDoor()
    local ply = self:GetOwner()
    if not IsValid(ply) then return nil end

    local tr = util.TraceLine({
        start = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 85,
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
    local door = self:GetAimedDoor()
    local ply = self:GetOwner()

    if not IsValid(door) or not IsValid(ply) then
        self._picking = false
        self._pickStart = 0
        return
    end

    local isLocked = (GRM and GRM.Doors and GRM.Doors.IsDoorLocked and GRM.Doors.IsDoorLocked(door)) or door:GetNWBool("GRM_DoorLocked", false)
    if not isLocked then
        if SERVER and (self._nextUnlocksMsg or 0) < CurTime() then
            self._nextUnlocksMsg = CurTime() + 1.5
            if GRM.Notify then GRM.Notify(ply, "Эта дверь и так открыта!", 235, 180, 60) end
        end
        self._picking = false
        self._pickStart = 0
        return
    end

    if not self._picking then
        self._picking = true
        self._pickStart = CurTime()
        self._pickTarget = door
        self._nextSound = CurTime()
    end

    if self._pickTarget ~= door then
        self._pickStart = CurTime()
        self._pickTarget = door
    end

    if CurTime() >= (self._nextSound or 0) then
        self._nextSound = CurTime() + 0.65
        ply:EmitSound("weapons/357/357_reload1.wav", 65, 110, 0.7)
    end

    local progress = (CurTime() - self._pickStart) / PICK_TIME

    if progress >= 1 then
        self._picking = false
        self._pickStart = 0

        if SERVER then
            GRM.Doors.LockDoor(door, false)
            door:Fire("Open", "", 0.1)

            local partner = GRM.Doors.GetPartnerDoor and GRM.Doors.GetPartnerDoor(door)
            if IsValid(partner) then partner:Fire("Open", "", 0.1) end

            ply:EmitSound("buttons/button14.wav", 75, 100)
            hook.Run("GRM_OnDoorLockpicked", ply, door)

            if GRM.Notify then
                GRM.Notify(ply, "Замок успешно взломан!", 100, 220, 100)
            end
        end
    end
end

function SWEP:SecondaryAttack()
end

if CLIENT then
    surface.CreateFont("PICK_HUD_Title", { font = "Roboto", size = 15, weight = 700, extended = true })
    surface.CreateFont("PICK_HUD_Sub",   { font = "Roboto", size = 13, weight = 600, extended = true })

    function SWEP:DrawHUD()
        local ply = self:GetOwner()
        if ply ~= LocalPlayer() then return end

        local door = self:GetAimedDoor()
        if not IsValid(door) or not self._picking or self._pickStart <= 0 then return end

        local elapsed = CurTime() - self._pickStart
        local progress = math.Clamp(elapsed / PICK_TIME, 0, 1)

        local sw, sh = ScrW(), ScrH()
        local bw, bh = 340, 70
        local cx, cy = sw / 2, sh / 2 + 100

        draw.RoundedBox(8, cx - bw / 2, cy, bw, bh, Color(18, 22, 32, 240))
        surface.SetDrawColor(70, 150, 240)
        surface.DrawOutlinedRect(cx - bw / 2, cy, bw, bh, 2)

        draw.SimpleText("ВЗЛОМ ЗАМКА DВЕРИ...", "PICK_HUD_Title", cx, cy + 18, Color(240, 245, 250), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Прогресс бар
        local barW, barH = 300, 18
        local barX, barY = cx - barW / 2, cy + 40
        draw.RoundedBox(4, barX, barY, barW, barH, Color(30, 36, 48))
        draw.RoundedBox(4, barX, barY, barW * progress, barH, Color(60, 190, 110))

        local pctText = string.format("%d%%", math.floor(progress * 100))
        draw.SimpleText(pctText, "PICK_HUD_Sub", cx, barY + barH / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end
