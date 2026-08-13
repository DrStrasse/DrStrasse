include("shared.lua")

function ENT:Draw()
    local typ = self.GetNodeType and self:GetNodeType() or 0
    local FA = GRM and GRM.FireAddon
    if not (FA and (typ == FA.NODE_LAY or typ == FA.NODE_SOURCE)) then
        self:DrawModel()
    end
    if FA and FA.DrawHoseBeam then
        local nxt = self:GetNextNode()
        local a = self:GetPos() + Vector(0, 0, 5)
        local b
        if IsValid(nxt) and nxt:IsPlayer() then
            local att = nxt:LookupAttachment("anim_attachment_RH")
            local dat = att and att > 0 and nxt:GetAttachment(att)
            b = (dat and dat.Pos) or (nxt:WorldSpaceCenter() + Vector(0, 0, 18))
        elseif IsValid(nxt) then
            b = nxt:GetPos() + Vector(0, 0, 5)
        end
        FA.DrawHoseBeam(a, b, IsValid(nxt) and nxt:IsPlayer())
    end
end

function ENT:DrawTranslucent()
    self:Draw()
end
