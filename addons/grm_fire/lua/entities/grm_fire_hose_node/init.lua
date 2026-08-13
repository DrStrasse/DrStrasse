AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local function A() return GRM and GRM.FireAddon end

function ENT:Initialize()
    local FA = A()
    local typ = self:GetNodeType() or 0
    local mdl
    if FA then
        if typ == FA.NODE_JUNCTION then
            mdl = FA.SafeModel(FA.Models.coil)
        elseif typ == FA.NODE_NOZZLE then
            mdl = util.IsValidModel("models/weapons/w_firehose_grm.mdl") and "models/weapons/w_firehose_grm.mdl" or FA.SafeModel(FA.Models.nozzle)
        elseif typ == FA.NODE_SOURCE then
            mdl = FA.SafeModel(FA.Models.nozzle)
        else
            mdl = "models/hunter/blocks/cube025x025x025.mdl"
        end
    else
        mdl = "models/hunter/blocks/cube025x025x025.mdl"
    end
    self:SetModel(mdl)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    self:SetCollisionGroup(COLLISION_GROUP_WEAPON)
    if typ == (FA and FA.NODE_LAY or 1) then
        self:SetModelScale(0.35, 0)
        self:SetColor(Color(140, 30, 25, 210))
        self:SetRenderMode(RENDERMODE_TRANSALPHA)
        self:DrawShadow(false)
        self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    end
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:EnableMotion(false)
    end
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    local FA = A()
    if not FA then return end
    local hose = self:GetHose()
    local typ = self:GetNodeType()

    if typ == FA.NODE_NOZZLE and IsValid(hose) then
        if hook.Run("GRM_FireAddon_HoseNodeUse", ply, self) == false then return end
        hose:PickNozzle(ply)
        return
    end

    if typ == FA.NODE_JUNCTION then
        if hook.Run("GRM_FireAddon_HoseNodeUse", ply, self) == false then return end
        if IsValid(ply.GRM_FireHose) then
            ply.GRM_FireHose:DockTo(self, ply)
            return
        end
        local h, err = FA.TakeHose(ply, self)
        if not h and err and ply.ChatPrint then ply:ChatPrint("[Рукав] " .. err) end
        return
    end
end
