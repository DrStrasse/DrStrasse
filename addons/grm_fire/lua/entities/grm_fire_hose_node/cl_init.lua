include("shared.lua")

local function hoseMat()
    local m = Material("cable/redcable")
    if not m or m:IsError() then m = Material("cable/cable_lit") end
    if not m or m:IsError() then m = Material("sprites/physbeama") end
    return m
end

local MAT = hoseMat()
local COL = Color(210, 30, 24, 255)
local COL_LIVE = Color(255, 70, 40, 255)

local function beamTo(self, nxt)
    if not IsValid(nxt) then return end
    local a = self:GetPos() + Vector(0, 0, 4)
    local b
    if nxt:IsPlayer() then
        local att = nxt:LookupAttachment("anim_attachment_RH")
        local dat = att and att > 0 and nxt:GetAttachment(att)
        b = (dat and dat.Pos) or (nxt:WorldSpaceCenter() + Vector(0, 0, 18))
    else
        b = nxt:GetPos() + Vector(0, 0, 4)
    end
    local col = nxt:IsPlayer() and COL_LIVE or COL
    local dist = a:Distance(b)
    render.SetMaterial(MAT)
    render.DrawBeam(a, b, 10, 0, dist / 18, Color(90, 10, 8, 255))
    render.DrawBeam(a, b, 6.5, 0, dist / 22, col)
end

function ENT:Draw()
    local typ = self.GetNodeType and self:GetNodeType() or 0
    local FA = GRM and GRM.FireAddon
    if FA and (typ == FA.NODE_LAY or typ == FA.NODE_SOURCE) then
        beamTo(self, self:GetNextNode())
        return
    end
    self:DrawModel()
    beamTo(self, self:GetNextNode())
end

function ENT:DrawTranslucent()
    local typ = self.GetNodeType and self:GetNodeType() or 0
    local FA = GRM and GRM.FireAddon
    if not (FA and (typ == FA.NODE_LAY or typ == FA.NODE_SOURCE)) then
        self:DrawModel()
    end
    beamTo(self, self:GetNextNode())
end
