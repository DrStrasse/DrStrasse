AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    -- невидимый, но твёрдый маркер (E попадает по нему)
    self:SetModel("models/props_junk/wood_crate001a.mdl")
    self:SetNoDraw(true)
    self:SetSolid(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    self:PhysicsInitBox(Vector(-30, -30, -6), Vector(30, 30, 76))
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
end

function ENT:Setup(data)
    if not istable(data) then return end
    self.VictimName  = tostring(data.victimName or "?")
    self.VictimKey   = tostring(data.victimKey or "")
    self.At          = tonumber(data.at) or os.time()
    self.By          = tostring(data.byName or "—")
    self.Cause       = tostring(data.cause or "урон")
    self.Hitgroup    = tonumber(data.hitgroup) or 0
    self.VictimModel = tostring(data.model or "")

    self:SetNWString("GRM_CorpseVictim", self.VictimName)
    self:SetNWString("GRM_CorpseBy", self.By)
    self:SetNWString("GRM_CorpseCause", self.Cause)
    self:SetNWInt("GRM_CorpseAt", self.At)

    -- видимое тело: рагдолл с моделью погибшего (лежит естественно)
    if self.Ragdoll and IsValid(self.Ragdoll) then self.Ragdoll:Remove() end
    local mdl = self.VictimModel
    if not (mdl ~= "" and util.IsValidModel(mdl)) then mdl = "models/player/group01/male_01.mdl" end
    if not util.IsValidModel(mdl) then mdl = "models/Barney.mdl" end
    if not util.IsValidModel(mdl) then return end
    local rag = ents.Create("prop_ragdoll")
    if not IsValid(rag) then return end
    rag:SetModel(mdl)
    rag:SetPos(self:GetPos())
    rag:SetAngles(self:GetAngles())
    rag:Spawn()
    rag:Activate()
    local n = rag:GetPhysicsObjectCount() or 0
    for i = 0, n - 1 do
        local p = rag:GetPhysicsObject(i)
        if IsValid(p) then p:Sleep() end
    end
    self.Ragdoll = rag
end

function ENT:Use(activator)
    if IsValid(activator) and activator:IsPlayer() and GRM.E911 and GRM.E911.Examine then
        GRM.E911.Examine(activator, self)
    end
end

function ENT:GetData()
    return {
        victimName = self.VictimName or "?",
        victimKey  = self.VictimKey or "",
        at         = self.At or os.time(),
        byName     = self.By or "—",
        cause      = self.Cause or "урон",
        hitgroup   = self.Hitgroup or 0,
        model      = self.VictimModel or "",
    }
end

function ENT:OnRemove()
    if self.Ragdoll and IsValid(self.Ragdoll) then self.Ragdoll:Remove() end
end
