include("shared.lua")

local MAT = Material("cable/redcable")
local COL = Color(210, 45, 40, 255)
local COL_LIVE = Color(230, 80, 50, 255)

function ENT:Draw()
    if not self:GetNoDraw() then self:DrawModel() end
end

function ENT:DrawTranslucent()
    self:Draw()
    local nxt = self:GetNextNode()
    if not IsValid(nxt) then return end
    local a = self:WorldSpaceCenter()
    if self:GetNoDraw() then a = self:GetPos() + Vector(0, 0, 3) end
    local b
    if nxt:IsPlayer() then
        local att = nxt:GetAttachment(nxt:LookupAttachment("anim_attachment_RH"))
        b = (att and att.Pos) or (nxt:WorldSpaceCenter() + Vector(0, 0, 20))
    else
        b = nxt:WorldSpaceCenter()
    end
    local col = nxt:IsPlayer() and COL_LIVE or COL
    render.SetMaterial(MAT)
    render.DrawBeam(a, b, 5.5, 0, a:Distance(b) / 32, col)
end
