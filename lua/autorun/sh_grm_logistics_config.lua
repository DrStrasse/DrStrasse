if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Logistics = GRM.Logistics or {}
local L = GRM.Logistics

L.Config = L.Config or {
    UseDistance = 190,
    CheckpointRadius = 350,
    LoadRadius = 125,
    TruckRearOffset = Vector(-165, 0, 38),
    -- Поднято ещё на 30 units: ящик держится выше, на уровне груди/рук.
    CarryOffset = Vector(26, 0, 60),
    CarryAngle = Angle(0, 0, 0),
    DefaultTruckCapacity = 12,
    MinimumWeaponCrates = 10,
    WeaponCrate = {
        MaxWeapons = 7,
        MinPistols = 2,
        MinAutomatics = 5,
        MaxPistols = 2,
        MaxAutomatics = 5,
        PistolPatterns = { "pistol", "makarov", "p228", "glock", "deagle", "revolver" },
        AutomaticPatterns = { "smg", "p90", "m4", "ak", "rifle", "ar2", "mp5" },
    },
    RewardPerCrate = { weapon = 600, ammo = 300, material = 200 },
    CrateModel = "models/props/cs_militia/footlocker01_closed.mdl",
    WarehouseModel = "models/Barney.mdl",
    ArmoryModel = "models/props_lab/lockers.mdl",
    LoadingPointModel = "models/hunter/tubes/tube2x2x1.mdl", -- полупрозрачный маркер погрузки
    Capacity = {
        weapons = 80,
        ammo = 5000,
        materials = 5000,
        medical = 500,
        repair = 500,
    },
    Vehicles = {
        ["simfphys_gta_sa_barracks"] = { capacity = 12, rearOffset = Vector(-165, 0, 38) },
    },
}
