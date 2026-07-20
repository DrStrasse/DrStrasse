if SERVER then
    AddCSLuaFile()
end

SWEP.PrintName = "Ордер на обыск"
SWEP.Author = "GRM"
SWEP.Instructions = "ЛКМ: Обыск игрока\nПКМ: Проверка документов"
SWEP.Category = "GRM — Полиция"

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

SWEP.Weight = 5
SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

SWEP.Slot = 1
SWEP.SlotPos = 1
SWEP.DrawAmmo = false
SWEP.DrawCrosshair = true

SWEP.ViewModel = "models/weapons/v_pistol.mdl"
SWEP.WorldModel = "models/weapons/w_c4.mdl"

SWEP.UseHands = true

-- Запрещённые предметы (находятся при обыске)
SWEP.Contraband = {
    "narc_marijuana",
    "narc_amphetamine",
    "narc_cocaine",
    "narc_solvent",
    "narc_precursor",
    "narc_equipment",
}

-- Запрещённое оружие (кроме служебного)
SWEP.ContrabandWeapons = {
    -- ArcCW
    "arccw_ak47",
    "arccw_m4a1",
    "arccw_p228",
    "arccw_deagle",
    "arccw_shotgun",
    "arccw_mp5",
    -- Старые классы (для совместимости)
    "weapon_ak472",
    "weapon_m42",
    "weapon_glock2",
    "weapon_deagle2",
    "weapon_shotgun2",
    "weapon_mp52",
}
