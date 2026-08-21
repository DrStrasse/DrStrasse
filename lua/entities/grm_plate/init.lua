AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local function PL() return GRM and GRM.Plates end

function ENT:Initialize()
    self:SetModel(self.Model)
    self:SetMaterial(self.Material)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
        phys:SetMass(2)
    end
    if self:GetNWString("GRM_Plate", "") == "" then
        self:SetNWString("GRM_Plate", "")
        self:SetNWString("GRM_PlateType", "civil")
        self:SetNWString("GRM_PlateStatus", "active")
        self:SetNWBool("GRM_PlateMounted", false)
    end
end

--- Записать на знак данные реестра.
function ENT:SetupPlate(rec)
    if not istable(rec) then return end
    self:SetNWString("GRM_Plate", tostring(rec.number or ""))
    self:SetNWString("GRM_PlateType", tostring(rec.type or "civil"))
    self:SetNWString("GRM_PlateStatus", tostring(rec.status or "active"))
    self:SetNWString("GRM_PlateOwner", tostring(rec.ownerName or ""))
    self.GRMPlateOwnerKey = tostring(rec.ownerKey or "")
end

--- Ближайший транспорт, к которому можно приложить знак.
function ENT:FindVehicle(maxDist)
    maxDist = maxDist or 90
    local best, bestD = nil, maxDist * maxDist
    for _, ent in ipairs(ents.FindInSphere(self:GetPos(), maxDist)) do
        if IsValid(ent) and ent ~= self then
            local isVeh = ent:IsVehicle()
            if not isVeh then
                local cls = string.lower(ent:GetClass() or "")
                isVeh = cls:find("simfphys", 1, true) == 1 or cls:find("lvs_", 1, true) == 1
                    or cls:find("prop_vehicle", 1, true) == 1 or ent.IsSimfphysCar == true or ent.LVS ~= nil
                    or ent.IsGlideVehicle == true
            end
            if isVeh then
                -- у simfphys сиденье — отдельная энтити: берём базу
                local base = ent
                if IsValid(ent:GetParent()) and ent:GetParent() ~= self then base = ent:GetParent() end
                if base.GetBase and IsValid(base:GetBase()) then base = base:GetBase() end
                local d = self:GetPos():DistToSqr(base:GetPos())
                if d <= bestD then best, bestD = base, d end
            end
        end
    end
    return best
end

function ENT:Use(ply)
    local P = PL()
    if not (IsValid(ply) and P) then return end
    if (self.GRMNextUse or 0) > CurTime() then return end
    self.GRMNextUse = CurTime() + 0.6

    local can, why = P.CanHandle(ply, self)
    if not can then
        if GRM.Notify then GRM.Notify(ply, "Это чужой знак — трогать его нельзя.", 255, 140, 100) end
        return
    end

    if IsValid(self:GetParent()) then
        local seize = (why == "police") and self.GRMPlateOwnerKey ~= (P.CharKey and P.CharKey(ply) or "")
        P.Detach(self, ply, seize)
        if GRM.Notify then
            GRM.Notify(ply, seize and "Знак изъят с транспорта." or "Знак снят.", 200, 220, 120)
        end
        return
    end

    local veh = self:FindVehicle()
    if not IsValid(veh) then
        if GRM.Notify then GRM.Notify(ply, "Поднесите знак к транспорту физганом и нажмите [E].", 255, 180, 90) end
        return
    end

    local ok, err = P.Attach(self, veh, ply)
    if GRM.Notify then
        GRM.Notify(ply, ok and "Знак закреплён на транспорте." or tostring(err or "Не удалось закрепить"),
            ok and 100 or 255, ok and 220 or 140, ok and 130 or 100)
    end
    if ok then self:EmitSound("physics/metal/metal_solid_impact_hard2.wav", 60, 110) end
end

--- Закреплённый знак физганом не таскают: сначала снимите его [E].
function ENT:PhysgunPickup(ply)
    if IsValid(self:GetParent()) then return false end
    local P = PL()
    if not P then return true end
    return P.CanHandle(ply, self) == true
end

hook.Add("PhysgunPickup", "GRM_Plates_Pickup", function(ply, ent)
    if not (IsValid(ent) and ent:GetClass() == "grm_plate") then return end
    if IsValid(ent:GetParent()) then return false end
    local P = PL()
    if P and P.CanHandle then return P.CanHandle(ply, ent) == true end
end)

function ENT:OnRemove()
    local P = PL()
    local veh = self:GetParent()
    if P and IsValid(veh) and P.RememberLayout then
        timer.Simple(0, function()
            if IsValid(veh) then P.RememberLayout(veh) end
        end)
    end
end
