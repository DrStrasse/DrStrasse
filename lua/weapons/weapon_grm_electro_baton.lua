if SERVER then AddCSLuaFile() end

SWEP.PrintName = "Электродубинка"
SWEP.Author = "GRM"
SWEP.Instructions = "ЛКМ — оглушить игрока без урона"
SWEP.Category = "GRM RP"
SWEP.Spawnable = true
SWEP.AdminOnly = false

-- Контракт стандартного weapon_stunstick из HL2/GMod:
-- в руках — v_stunstick, мир — w_stunbaton.
SWEP.ViewModel = "models/weapons/v_stunstick.mdl"
SWEP.WorldModel = "models/weapons/w_stunbaton.mdl"
SWEP.ViewModelFOV = 62
SWEP.UseHands = true
SWEP.HoldType = "melee2"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

local function batonSound(ent, path, level, pitch)
    if IsValid(ent) then ent:EmitSound(path, level or 70, pitch or 100, 0.85, CHAN_WEAPON) end
end

function SWEP:Initialize()
    self:SetHoldType("melee2")
end

function SWEP:Deploy()
    self:SetHoldType("melee2")
    self:SendWeaponAnim(ACT_VM_DRAW)
    return true
end

function SWEP:Holster()
    return true
end

function SWEP:PrimaryAttack()
    local owner = self:GetOwner()
    self:SetNextPrimaryFire(CurTime() + 1.5)
    self:SetNextSecondaryFire(CurTime() + 0.5)

    -- Анимация стандартного stunstick: замах/удар, а не fists/crowbar.
    self:SendWeaponAnim(ACT_VM_HITCENTER)
    if IsValid(owner) then
        owner:SetAnimation(PLAYER_ATTACK1)
        owner:DoAnimationEvent(ACT_HL2MP_GESTURE_RANGE_ATTACK_MELEE)
    end

    if CLIENT then return end
    if not IsValid(owner) then return end

    local tr = util.TraceHull({
        start = owner:EyePos(),
        endpos = owner:EyePos() + owner:GetAimVector() * 90,
        filter = owner,
        mins = Vector(-8, -8, -8),
        maxs = Vector(8, 8, 8),
        mask = MASK_SHOT,
    })
    local target = tr.Entity
    if not IsValid(target) or not target:IsPlayer() then
        batonSound(owner, "weapons/stunstick/stunstick_swing1.wav", 65, 100)
        return
    end

    batonSound(owner, "weapons/stunstick/stunstick_impact1.wav", 78, 100)
    -- Урон намеренно НЕ наносится: только состояние GRM_Stunned.
    if GRM.Handcuffs and GRM.Handcuffs.StunPlayer then
        GRM.Handcuffs.StunPlayer(owner, target, 4)
    end
end

function SWEP:SecondaryAttack()
    self:SetNextSecondaryFire(CurTime() + 0.5)
end
