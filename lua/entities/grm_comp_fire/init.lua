--[[--------------------------------------------------------------------
    grm_comp_fire — init.lua (Серверная часть пожарной станции)
----------------------------------------------------------------------]]
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("GRM_CompFire_Open")
util.AddNetworkString("GRM_CompFire_Action")

function ENT:Initialize()
    local mdl = self.Model
    if not util.IsValidModel(mdl) then mdl = self.ModelFallback end
    self:SetModel(mdl)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    if self:GetComputerName() == "" then
        self:SetComputerName("ПОЖАРНАЯ СЛУЖБА • ДИСПЕТЧЕРСКАЯ")
    end

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() phys:EnableMotion(false) end
end

-- Кто вправе пользоваться станцией: суперадмин, бойцы (FightPro), диспетчеры.
function ENT:CanManage(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return false end
    if ply:IsSuperAdmin() then return true end
    local F = GRM.Fire
    if not F then return false end
    if isfunction(F.CanFightPro) and F.CanFightPro(ply) == true then return true end
    if isfunction(F.CanDispatch) and F.CanDispatch(ply) == true then return true end
    return false
end

local function snapshot(ply)
    local F = GRM.Fire
    local fires = (F and isfunction(F.Snapshot) and F.Snapshot()) or {}
    local cfg = (F and F.Config) or {}
    return {
        isAdmin       = ply:IsSuperAdmin() == true,
        canControl    = (F and isfunction(F.CanFightPro) and F.CanFightPro(ply) == true),
        canDispatch   = (F and isfunction(F.CanDispatch) and F.CanDispatch(ply) == true),
        addonReady    = (F and isfunction(F.AddonReady) and F.AddonReady() == true),
        vfireReady    = (F and isfunction(F.VFireReady) and F.VFireReady() == true),
        activeFires   = #fires,
        randomEnabled = cfg.RandomEnabled == true,
        stoveEnabled  = cfg.StoveEnabled == true,
        maxIncidents  = tonumber(cfg.MaxIncidents) or 8,
        minSec        = tonumber(cfg.RandomMinSec) or 480,
        maxSec        = tonumber(cfg.RandomMaxSec) or 900,
        name          = self:GetComputerName(),
    }
end

function ENT:Use(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    if not self:CanManage(ply) then
        if GRM.Notify then
            GRM.Notify(ply, "Доступ к пожарной станции — только бойцам, диспетчерам пожарной службы и суперадминам.", 255, 120, 100)
        end
        return
    end

    net.Start("GRM_CompFire_Open")
        net.WriteEntity(self)
        net.WriteTable(snapshot(ply))
    net.Send(ply)
end

-- Дежурство: закрепить машину / снять / взять ствол.
net.Receive("GRM_CompFire_Action", function(_, ply)
    if not IsValid(ply) then return end
    local ent = net.ReadEntity()
    if not IsValid(ent) or ent:GetClass() ~= "grm_comp_fire" then return end
    if ply:GetPos():DistToSqr(ent:GetPos()) > 250 * 250 then return end
    if not ent:CanManage(ply) then return end

    local op = net.ReadString()
    local F = GRM.Fire
    if not F then
        if GRM.Notify then GRM.Notify(ply, "Модуль пожаров не загружен.", 255, 120, 100) end
        return
    end

    local ok, err
    if op == "commission" then
        ok, err = F.CommissionTruck(ply)
    elseif op == "decommission" then
        ok, err = F.DecommissionTruck(ply)
    elseif op == "hose" then
        ok, err = F.TakeHoseFromTruck(ply)
    else
        return
    end

    if GRM.Notify then
        if ok then
            GRM.Notify(ply, tostring(err or "Готово."), 100, 220, 130)
        else
            GRM.Notify(ply, tostring(err or "Не выполнено."), 255, 140, 100)
        end
    end
end)
