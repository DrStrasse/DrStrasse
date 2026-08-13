TOOL.Category = "GRM"
TOOL.Name = "#tool.grm_arrest_zone.name"
TOOL.Command = nil
TOOL.ConfigName = ""

if CLIENT then
    local zones = {}
    language.Add("tool.grm_arrest_zone.name", "GRM Зона тюрьмы")
    language.Add("tool.grm_arrest_zone.desc", "Прямоугольная зона, внутри которой разрешён арест")
    language.Add("tool.grm_arrest_zone.0", "ЛКМ: первый угол | ПКМ: второй угол и сохранить")
    net.Receive("GRM_Arrest_ZoneData", function() zones = net.ReadTable() or {} end)
    hook.Add("Think", "GRM_ArrestZone_Request", function()
        local ply = LocalPlayer()
        local wep = IsValid(ply) and ply:GetActiveWeapon() or nil
        if IsValid(wep) and wep:GetClass() == "gmod_tool" and wep.GetMode and wep:GetMode() == "grm_arrest_zone" then
            if (wep.GRMZoneRequest or 0) < CurTime() then
                wep.GRMZoneRequest = CurTime() + 1
                net.Start("GRM_Arrest_ZoneRequest") net.SendToServer()
            end
        end
    end)
    hook.Add("PostDrawTranslucentRenderables", "GRM_ArrestZone_Draw", function()
        local ply = LocalPlayer()
        local wep = IsValid(ply) and ply:GetActiveWeapon() or nil
        if not IsValid(wep) or wep:GetClass() ~= "gmod_tool" or not wep.GetMode or wep:GetMode() ~= "grm_arrest_zone" then return end
        for _, zone in ipairs(zones or {}) do
            local mn, mx = zone.min or {}, zone.max or {}
            local mins = Vector(mn.x or 0, mn.y or 0, mn.z or 0)
            local maxs = Vector(mx.x or 0, mx.y or 0, mx.z or 0)
            local center = (mins + maxs) * 0.5
            render.DrawWireframeBox(center, angle_zero, mins - center, maxs - center, Color(255, 150, 70, 220), true)
        end
    end)
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsSuperAdmin() then return false end
    self.GRM_FirstCorner = trace.HitPos
    self:SetStage(1)
    owner:ChatPrint("[Арест] Первый угол зоны установлен. Прицельтесь в противоположный угол и нажмите ПКМ.")
    return true
end

function TOOL:RightClick(trace)
    if CLIENT then return true end
    local owner = self:GetOwner()
    if not IsValid(owner) or not owner:IsSuperAdmin() or not self.GRM_FirstCorner then return false end
    if GRM.Arrest and GRM.Arrest.AddPrisonZone then
        GRM.Arrest.AddPrisonZone(self.GRM_FirstCorner, trace.HitPos, "Тюрьма")
        owner:ChatPrint("[Арест] Прямоугольная зона тюрьмы сохранена.")
    end
    self.GRM_FirstCorner = nil
    self:SetStage(0)
    return true
end

function TOOL:Reload()
    if CLIENT then return true end
    self.GRM_FirstCorner = nil
    self:SetStage(0)
    return true
end
