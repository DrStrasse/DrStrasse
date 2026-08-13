AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local function cfg()
    return (GRM and GRM.FireAddon and GRM.FireAddon.HoseCfg) or {
        MaxLength = 2200, LayStep = 70, Width = 5,
        Material = "grm/firehose", Sag = 14, SprayCost = 8, SprayDmg = 10,
    }
end

local function A() return GRM and GRM.FireAddon end

util.AddNetworkString("GRM_FireHose_Path")

function ENT:UpdateTransmitState()
    return TRANSMIT_ALWAYS
end

function ENT:Initialize()
    self:SetModel("models/props_junk/PopCan01a.mdl")
    self:DrawShadow(false)
    self:SetSolid(SOLID_NONE)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_IN_VEHICLE)
    self:SetRenderMode(RENDERMODE_TRANSALPHA)
    self:SetColor(Color(220, 40, 30, 1))
    self.Nodes = {}
    if self:GetMaxLen() <= 0 then self:SetMaxLen(cfg().MaxLength) end
    self:SetLaidLen(0)
    self:SetPressurized(false)
    self:SetDocked(false)
end

function ENT:BroadcastPath()
    local pts = {}
    for _, n in ipairs(self.Nodes or {}) do
        if IsValid(n) then
            pts[#pts + 1] = n:GetPos() + Vector(0, 0, 7)
        end
    end
    net.Start("GRM_FireHose_Path")
        net.WriteUInt(self:EntIndex(), 16)
        net.WriteUInt(#pts, 8)
        for i = 1, #pts do net.WriteVector(pts[i]) end
        net.WriteEntity(self:GetHolder())
        net.WriteBool(self:GetDocked() == true)
    net.Broadcast()
end

function ENT:OnRemove()
    local ply = self:GetHolder()
    if IsValid(ply) and ply.GRM_FireHose == self then
        ply.GRM_FireHose = nil
        if ply.SetNW2Entity then ply:SetNW2Entity("GRM_FireHose", NULL) end
        if ply:HasWeapon("weapon_grm_hose") then ply:StripWeapon("weapon_grm_hose") end
    end
    for _, n in ipairs(self.Nodes or {}) do
        if IsValid(n) then n:Remove() end
    end
    net.Start("GRM_FireHose_Path")
        net.WriteUInt(self:EntIndex(), 16)
        net.WriteUInt(0, 8)
        net.WriteEntity(NULL)
        net.WriteBool(false)
    net.Broadcast()
end

function ENT:LastNode()
    for i = #(self.Nodes or {}), 1, -1 do
        if IsValid(self.Nodes[i]) then return self.Nodes[i] end
    end
end

function ENT:MakeNode(typ, pos, parent)
    local n = ents.Create("grm_fire_hose_node")
    if not IsValid(n) then return nil end
    n:SetPos(pos)
    n:SetHose(self)
    n:SetNodeType(typ)
    if IsValid(parent) then
        n:SetParent(parent)
    end
    n:Spawn()
    n:Activate()
    self.Nodes[#self.Nodes + 1] = n
    return n
end

function ENT:Link(a, b, length)
    if not IsValid(a) or not IsValid(b) then return end
    local c = cfg()
    local dist = a:GetPos():Distance(b:GetPos())
    length = tonumber(length) or (dist + c.Sag)
    if constraint.Rope then
        local _, rope = constraint.Rope(
            a, b, 0, 0,
            Vector(0, 0, 2), Vector(0, 0, 2),
            math.max(8, length), 0, 0,
            c.Width, c.Material, false,
            Color(200, 40, 40)
        )
        a.HoseRope = rope
    end
    a:SetNextNode(b)
end

function ENT:DeployTo(ply)
    if not IsValid(ply) then return false, "игрок" end
    local src = self:GetStartEnt()
    if not IsValid(src) then return false, "источник" end
    local FA = A()
    local typ = FA and FA.NODE_SOURCE or 0
    local origin = src:WorldSpaceCenter() + src:GetForward() * 8 + Vector(0, 0, 6)
    local node = self:MakeNode(typ, origin, src)
    if not IsValid(node) then return false, "узел" end
    self:SetEndNode(node)
    self:SetHolder(ply)
    ply.GRM_FireHose = self
    if ply.SetNW2Entity then ply:SetNW2Entity("GRM_FireHose", self) end
    if not ply:HasWeapon("weapon_grm_hose") then ply:Give("weapon_grm_hose") end
    ply:SelectWeapon("weapon_grm_hose")
    node:SetNextNode(ply)
    self:EmitSound("physics/rubber/rubber_tire_impact_soft1.wav", 60, 110)
    self:BroadcastPath()
    return true
end

function ENT:GroundPos(ply)
    local p = IsValid(ply) and ply:GetPos() or self:GetPos()
    local tr = util.TraceLine({
        start = p + Vector(0, 0, 24),
        endpos = p - Vector(0, 0, 80),
        filter = function(ent)
            if not IsValid(ent) then return false end
            if ent:IsPlayer() then return false end
            local c = ent:GetClass()
            if c == "grm_fire_hose" or c == "grm_fire_hose_node" then return false end
            return true
        end,
    })
    if tr.Hit then return tr.HitPos + tr.HitNormal * 3 end
    return p + Vector(0, 0, 2)
end

function ENT:LaidDistance()
    local sum = 0
    local nodes = self.Nodes or {}
    for i = 2, #nodes do
        if IsValid(nodes[i - 1]) and IsValid(nodes[i]) then
            sum = sum + nodes[i - 1]:GetPos():Distance(nodes[i]:GetPos())
        end
    end
    return sum
end

function ENT:Remain()
    return math.max(0, (self:GetMaxLen() or 2200) - self:LaidDistance())
end

function ENT:CanPopLast()
    local nodes = self.Nodes or {}
    if #nodes < 2 then return false end
    local last = nodes[#nodes]
    if not IsValid(last) then return false end
    local FA = A()
    local typ = last:GetNodeType() or 0
    if FA and (typ == FA.NODE_SOURCE or typ == FA.NODE_JUNCTION or typ == FA.NODE_NOZZLE) then
        return false
    end
    return true
end

-- Идём назад к источнику: ближе к предыдущему узлу, чем к последнему.
function ENT:IsWalkingBack(ply)
    if not IsValid(ply) then return false end
    local nodes = self.Nodes or {}
    if #nodes < 2 then return false end
    local last, prev = nodes[#nodes], nodes[#nodes - 1]
    if not IsValid(last) or not IsValid(prev) then return false end
    local ppos = self:GroundPos(ply)
    return ppos:Distance(prev:GetPos()) + 8 < ppos:Distance(last:GetPos())
end

-- Сервер: снять один или несколько узлов укладки, если игрок идёт назад по рукаву.
function ENT:TryRewind(ply)
    if self:GetDocked() or not IsValid(ply) then return false end
    if not self:CanPopLast() then return false end
    local step = cfg().LayStep or 70
    local ppos = self:GroundPos(ply)
    local popped = 0
    for _ = 1, 24 do
        if not self:CanPopLast() then break end
        local nodes = self.Nodes
        local last, prev = nodes[#nodes], nodes[#nodes - 1]
        if not IsValid(prev) then break end
        local toLast = ppos:Distance(last:GetPos())
        local toPrev = ppos:Distance(prev:GetPos())
        if toPrev + 8 >= toLast then break end
        local span = last:GetPos():Distance(prev:GetPos())
        -- далеко в сторону от линии рукава — не сматывать
        if toLast > span + step * 2.5 and toPrev > step * 2.5 then break end
        if constraint.RemoveConstraints then
            pcall(constraint.RemoveConstraints, last, "Rope")
            pcall(constraint.RemoveConstraints, prev, "Rope")
        end
        last:Remove()
        local keep = {}
        for _, n in ipairs(self.Nodes) do
            if IsValid(n) then keep[#keep + 1] = n end
        end
        self.Nodes = keep
        popped = popped + 1
        local now = self:LastNode()
        if IsValid(now) then
            now:SetNextNode(ply)
            self:SetEndNode(now)
        end
        ppos = self:GroundPos(ply)
    end
    if popped <= 0 then return false end
    self:SetLaidLen(math.floor(self:LaidDistance()))
    if self.BroadcastPath then self:BroadcastPath() end
    return true
end

function ENT:TryLay(ply)
    if self:GetDocked() then return end
    local last = self:LastNode()
    if not IsValid(last) or not IsValid(ply) then return end
    local step = cfg().LayStep
    local dest = self:GroundPos(ply)
    local dist = last:GetPos():Distance(dest)
    if dist < step then return end
    if self:LaidDistance() + dist > (self:GetMaxLen() or 2200) then return end
    -- не класть сквозь стену
    local wall = util.TraceLine({
        start = last:GetPos() + Vector(0, 0, 8),
        endpos = dest + Vector(0, 0, 8),
        filter = { last, ply, self },
        mask = MASK_SOLID_BRUSHONLY,
    })
    if wall.Hit then return end
    local FA = A()
    local node = self:MakeNode(FA and FA.NODE_LAY or 1, dest)
    if not IsValid(node) then return end
    last:SetNextNode(node)
    self:Link(last, node, dist + cfg().Sag)
    node:SetNextNode(ply)
    self:SetEndNode(node)
    self:SetLaidLen(math.floor(self:LaidDistance()))
    self:BroadcastPath()
end

function ENT:Leash(ply)
    if not IsValid(ply) or self:GetDocked() then return end
    local last = self:LastNode()
    if not IsValid(last) then return end
    local remain = self:Remain()
    local pos = ply:GetPos()
    local dest = last:GetPos()
    dest.z = pos.z
    local dist = pos:Distance(dest)
    if dist <= remain + 8 then return end
    local dir = (dest - pos)
    dir.z = 0
    if dir:LengthSqr() < 1 then return end
    dir:Normalize()
    ply:SetVelocity(dir * 280 + Vector(0, 0, 10))
end

function ENT:DropNozzle()
    local ply = self:GetHolder()
    local last = self:LastNode()
    if not IsValid(last) then return false end
    local FA = A()
    local pos = IsValid(ply) and self:GroundPos(ply) or (last:GetPos() + last:GetForward() * 16)
    local noz = self:MakeNode(FA and FA.NODE_NOZZLE or 3, pos)
    if not IsValid(noz) then return false end
    last:SetNextNode(noz)
    self:Link(last, noz)
    self:SetEndNode(noz)
    self:SetHolder(NULL)
    if IsValid(ply) then
        ply.GRM_FireHose = nil
        if ply.SetNW2Entity then ply:SetNW2Entity("GRM_FireHose", NULL) end
        if ply:HasWeapon("weapon_grm_hose") then ply:StripWeapon("weapon_grm_hose") end
    end
    self:SetLaidLen(math.floor(self:LaidDistance()))
    self:BroadcastPath()
    return true
end

function ENT:PickNozzle(ply)
    if not IsValid(ply) or IsValid(ply.GRM_FireHose) then return false end
    if not A() or not A().CanHose(ply, self:GetStartEnt(), "pick") then return false end
    local last = self:LastNode()
    if not IsValid(last) or last:GetNodeType() ~= (A() and A().NODE_NOZZLE or 3) then return false end
    if constraint.RemoveConstraints then constraint.RemoveConstraints(last, "Rope") end
    last:Remove()
    -- выкинуть мёртвые
    local keep = {}
    for _, n in ipairs(self.Nodes or {}) do
        if IsValid(n) then keep[#keep + 1] = n end
    end
    self.Nodes = keep
    local now = self:LastNode()
    if IsValid(now) then now:SetNextNode(ply) end
    self:SetHolder(ply)
    ply.GRM_FireHose = self
    if ply.SetNW2Entity then ply:SetNW2Entity("GRM_FireHose", self) end
    if not ply:HasWeapon("weapon_grm_hose") then ply:Give("weapon_grm_hose") end
    ply:SelectWeapon("weapon_grm_hose")
    self:BroadcastPath()
    return true
end

function ENT:PlaceJunction(ply)
    if self:GetDocked() then return false end
    local last = self:LastNode()
    if not IsValid(last) then return false end
    if self:LaidDistance() < 80 then return false end
    local FA = A()
    local pos = IsValid(ply) and self:GroundPos(ply) or last:GetPos()
    local j = self:MakeNode(FA and FA.NODE_JUNCTION or 2, pos)
    if not IsValid(j) then return false end
    last:SetNextNode(j)
    self:Link(last, j)
    self:SetEndNode(j)
    self:SetHolder(NULL)
    self:SetDocked(true)
    if IsValid(ply) then
        ply.GRM_FireHose = nil
        if ply.SetNW2Entity then ply:SetNW2Entity("GRM_FireHose", NULL) end
        if ply:HasWeapon("weapon_grm_hose") then ply:StripWeapon("weapon_grm_hose") end
    end
    self:SetLaidLen(math.floor(self:LaidDistance()))
    self:EmitSound("physics/metal/metal_box_impact_soft1.wav", 65, 100)
    self:BroadcastPath()
    return true
end

function ENT:DockTo(target, ply)
    if not IsValid(target) or self:GetDocked() then return false, "нельзя" end
    if target == self:GetStartEnt() then return false, "тот же источник" end
    local cls = target:GetClass()
    if cls ~= "grm_fire_hydrant" and cls ~= "grm_fire_pump" and not (cls == "grm_fire_hose_node" and target:GetNodeType() == (A() and A().NODE_JUNCTION or 2)) then
        return false, "не стык"
    end
    if A() and not A().SourceHasFreeSlot(target) and cls ~= "grm_fire_hose_node" then
        -- стыковка конца занимает порт цели
        local used, max = A().SourceSlots(target)
        if used >= max then return false, "нет порта" end
    end
    if cls == "grm_fire_hydrant" and target.GetOpen and not target:GetOpen() then
        return false, "гидрант закрыт"
    end
    local last = self:LastNode()
    if not IsValid(last) then return false end
    local FA = A()
    local pos = target:WorldSpaceCenter() + Vector(0, 0, 6)
    local dock = self:MakeNode(FA and FA.NODE_SOURCE or 0, pos, target)
    if not IsValid(dock) then return false end
    last:SetNextNode(dock)
    self:Link(last, dock)
    self:SetEndNode(dock)
    self:SetDocked(true)
    self:SetHolder(NULL)
    if IsValid(ply) then
        ply.GRM_FireHose = nil
        if ply.SetNW2Entity then ply:SetNW2Entity("GRM_FireHose", NULL) end
        if ply:HasWeapon("weapon_grm_hose") then ply:StripWeapon("weapon_grm_hose") end
    end
    if target.SetPumpOn then target:SetPumpOn(true) end
    self:SetLaidLen(math.floor(self:LaidDistance()))
    self:EmitSound("buttons/lever7.wav", 65, 100)
    hook.Run("GRM_FireAddon_HoseDocked", self, target, ply)
    if self.BroadcastPath then self:BroadcastPath() end
    return true
end

local function walkPressure(ent, seen)
    if not IsValid(ent) then return false, nil end
    if seen[ent] then return false, nil end
    seen[ent] = true
    local cls = ent:GetClass()
    if cls == "grm_fire_hydrant" and ent.GetOpen and ent:GetOpen() then
        return true, nil
    end
    if cls == "grm_fire_pump" and ent.GetPumpOn and ent:GetPumpOn() then
        if ent.GetHydrantFeed and ent:GetHydrantFeed() then return true, ent end
        local ag = ent.GetAgent and ent:GetAgent() or "water"
        local have = 0
        if ag == "foam" then have = ent.GetFoam and ent:GetFoam() or 0
        elseif ag == "powder" then have = ent.GetPowder and ent:GetPowder() or 0
        else have = ent:GetTank() or 0 end
        if have > 0 then return true, ent end
    end
    -- рукава, стартующие здесь или пристыкованные сюда
    for _, h in ipairs(ents.FindByClass("grm_fire_hose")) do
        if IsValid(h) and (h:GetStartEnt() == ent or h:GetEndNode() == ent) then
            local other = h:GetStartEnt()
            if other == ent then
                local endN = h:GetEndNode()
                if IsValid(endN) then
                    local p = endN:GetParent()
                    if IsValid(p) then
                        local ok, pump = walkPressure(p, seen)
                        if ok then return true, pump end
                    end
                    local ok, pump = walkPressure(endN, seen)
                    if ok then return true, pump end
                end
            else
                local ok, pump = walkPressure(other, seen)
                if ok then return true, pump end
            end
        end
        if IsValid(h:GetEndNode()) and h:GetEndNode():GetParent() == ent then
            local ok, pump = walkPressure(h:GetStartEnt(), seen)
            if ok then return true, pump end
        end
    end
    if cls == "grm_fire_hose_node" then
        local hose = ent:GetHose()
        if IsValid(hose) then
            local ok, pump = walkPressure(hose:GetStartEnt(), seen)
            if ok then return true, pump end
        end
    end
    return false, nil
end

function ENT:RefreshPressure()
    local ok, pump = walkPressure(self:GetStartEnt(), {})
    if not ok then
        local endN = self:GetEndNode()
        if IsValid(endN) then
            ok, pump = walkPressure(endN:GetParent(), {})
        end
    end
    self:SetPressurized(ok == true)
    self._SupplyPump = pump
    return ok == true
end

function ENT:SupplyPump()
    local src = self:GetStartEnt()
    if IsValid(src) and src:GetClass() == "grm_fire_pump" then
        self:RefreshPressure()
        return src
    end
    local endN = self:GetEndNode()
    if IsValid(endN) then
        local p = endN.GetParent and endN:GetParent() or NULL
        if IsValid(p) and p:GetClass() == "grm_fire_pump" then
            self:RefreshPressure()
            return p
        end
    end
    self:RefreshPressure()
    return self._SupplyPump
end

function ENT:Rewind()
    local ply = self:GetHolder()
    if IsValid(ply) then
        ply.GRM_FireHose = nil
        if ply.SetNW2Entity then ply:SetNW2Entity("GRM_FireHose", NULL) end
        if ply:HasWeapon("weapon_grm_hose") then ply:StripWeapon("weapon_grm_hose") end
    end
    self:Remove()
end

-- ALT: смотать один узел, если стоишь у рукава.
function ENT:ReelIn(ply)
    if self:GetDocked() or not IsValid(ply) or not self:CanPopLast() then return false end
    local last = self:LastNode()
    if not IsValid(last) then return false end
    if self:GroundPos(ply):Distance(last:GetPos()) > 260 then return false end
    local nodes = self.Nodes
    local prev = nodes[#nodes - 1]
    if constraint.RemoveConstraints then
        pcall(constraint.RemoveConstraints, last, "Rope")
        if IsValid(prev) then pcall(constraint.RemoveConstraints, prev, "Rope") end
    end
    last:Remove()
    local keep = {}
    for _, n in ipairs(self.Nodes) do
        if IsValid(n) then keep[#keep + 1] = n end
    end
    self.Nodes = keep
    local now = self:LastNode()
    if IsValid(now) then
        now:SetNextNode(ply)
        self:SetEndNode(now)
    end
    self:SetLaidLen(math.floor(self:LaidDistance()))
    if self.BroadcastPath then self:BroadcastPath() end
    return true
end

function ENT:Think()
    local ply = self:GetHolder()
    if IsValid(ply) and not self:GetDocked() then
        if not ply:Alive() then
            self:DropNozzle()
        else
            local reeled = false
            if ply.KeyDown and ply:KeyDown(IN_WALK) then
                reeled = self:ReelIn(ply)
            end
            if not reeled then reeled = self:TryRewind(ply) end
            if not reeled and not self:IsWalkingBack(ply) then
                self:TryLay(ply)
            end
            self:Leash(ply)
            local last = self:LastNode()
            if IsValid(last) then last:SetNextNode(ply) end
        end
    end
    self:RefreshPressure()
    self:NextThink(CurTime() + 0.10)
    return true
end
