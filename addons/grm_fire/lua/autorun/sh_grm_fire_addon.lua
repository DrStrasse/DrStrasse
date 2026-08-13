--[[--------------------------------------------------------------------
    GRM Fire Addon — маркер + тонкий API сущностей.
    Не зависит от GRM. Серверный скрипт GRM смотрит GRM_FireAddon / vFireInstalled.
----------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() end

GRM_FireAddon = true
GRM = GRM or {}
GRM.FireAddon = GRM.FireAddon or {}
local A = GRM.FireAddon
A.Version = "0.2.0"

A.Models = {
    hydrant  = { "models/props/cs_assault/FireHydrant.mdl", "models/props_pipes/valvewheel001.mdl" },
    cabinet  = { "models/props/cs_office/fire_extinguisher.mdl", "models/props_c17/canister01a.mdl" },
    coil     = { "models/props/cs_assault/wirepipe.mdl", "models/props_c17/GasPipes006a.mdl" },
    nozzle   = { "models/props/cs_assault/wirespout.mdl", "models/props_canal/mattpipe.mdl" },
    detector = { "models/props/cs_office/smoke_detector.mdl", "models/props_lab/reciever01c.mdl" },
    spot     = { "models/hunter/blocks/cube025x025x025.mdl" },
}

function A.SafeModel(list)
    list = istable(list) and list or { tostring(list or "") }
    for i = 1, #list do
        local m = list[i]
        if isstring(m) and m ~= "" and util.IsValidModel(m) then return m end
    end
    return "models/hunter/blocks/cube025x025x025.mdl"
end

function A.IsWaterSource(ent)
    if not IsValid(ent) then return false end
    local cls = ent:GetClass()
    if cls == "grm_fire_hydrant" then
        return ent.GetOpen and ent:GetOpen() == true
    end
    if cls == "grm_fire_pump" then
        if not (ent.GetPumpOn and ent:GetPumpOn()) then return false end
        return (ent.GetTank and ent:GetTank() or 0) > 0
    end
    return false
end

function A.GiveExtinguisher(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if ply:HasWeapon("weapon_extinguisher") then return true end
    ply:Give("weapon_extinguisher")
    return ply:HasWeapon("weapon_extinguisher")
end

function A.GiveHose(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if SERVER and IsValid(ply.GRM_FireHose) then return true end
    if ply:HasWeapon("weapon_grm_hose") then return true end
    ply:Give("weapon_grm_hose")
    return ply:HasWeapon("weapon_grm_hose")
end

function A.Refill(ply, amount)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    amount = math.max(0, math.floor(tonumber(amount) or 0))
    if amount <= 0 then return false end
    local function add(name, cap)
        local id = game.GetAmmoID(name)
        if not id or id < 0 then return end
        local have = ply:GetAmmoCount(id) or 0
        ply:SetAmmo(math.min(cap, have + amount), id)
    end
    add("firehose_water", 1000)
    add("rb655_extinguisher", 1000)
    return true
end

function A.Ready()
    return vFireInstalled == true
end

if SERVER then
    print("[GRM Fire Addon] v" .. A.Version .. " loaded (рукава + гидрант/насос; огонь = vFire)")
end
