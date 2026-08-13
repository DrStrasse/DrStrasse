include("shared.lua")

local MAT = Material("cable/redcable")
local COL = Color(210, 45, 40, 255)
local COL_LIVE = Color(230, 80, 50, 255)

function ENT:Draw()
    local typ = self.GetNodeType and self:GetNodeType() or 0
    local FA = GRM and GRM.FireAddon
    if FA and (typ == FA.NODE_LAY or typ == FA.NODE_SOURCE) then return end
    self:DrawModel()
end

function ENT:DrawTranslucent()
    local typ = self.GetNodeType and self:GetNodeType() or 0
    local FA = GRM and GRM.FireAddon
    if not (FA and (typ == FA.NODE_LAY or typ == FA.NODE_SOURCE)) then
        self:DrawModel()
    end
    local nxt = self:GetNextNode()
    if not IsValid(nxt) then return end
    local a = self:GetPos() + Vector(0, 0, 3)
    local b
    if nxt:IsPlayer() then
        local att = nxt:GetAttachment(nxt:LookupAttachment("anim_attachment_RH"))
        b = (att and att.Pos) or (nxt:WorldSpaceCenter() + Vector(0, 0, 20))
    else
        b = nxt:GetPos() + Vector(0, 0, 3)
    end
    local col = nxt:IsPlayer() and COL_LIVE or COL
    render.SetMaterial(MAT)
    render.DrawBeam(a, b, 5.5, 0, a:Distance(b) / 32, col)
end
