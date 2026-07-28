if SERVER then AddCSLuaFile() end

SWEP.PrintName = "Электродубинка"
SWEP.Author = "GRM"
SWEP.Instructions = "ЛКМ — оглушить игрока без урона"
SWEP.Category = "GRM RP"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.ViewModel = "models/weapons/v_stunbaton.mdl"
SWEP.WorldModel = "models/weapons/w_stunbaton.mdl"
SWEP.UseHands = true
SWEP.HoldType = "melee2"
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.DrawAmmo = false

function SWEP:Initialize() self:SetHoldType(self.HoldType) end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + 1.5)
    if CLIENT then return end
    local ply = self:GetOwner()
    if not IsValid(ply) then return end
    local tr = util.TraceHull({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * 90,
        filter = ply,
        mins = Vector(-8, -8, -8),
        maxs = Vector(8, 8, 8),
        mask = MASK_SHOT,
    })
    local target = tr.Entity
    if not IsValid(target) or not target:IsPlayer() then
        ply:EmitSound("weapons/stunstick/stunstick_swing1.wav", 65, 100, 0.7)
        return
    end
    if GRM.Handcuffs and GRM.Handcuffs.StunPlayer then
        GRM.Handcuffs.StunPlayer(ply, target, 4)
    end
end

function SWEP:SecondaryAttack() self:SetNextSecondaryFire(CurTime() + 0.5) end
