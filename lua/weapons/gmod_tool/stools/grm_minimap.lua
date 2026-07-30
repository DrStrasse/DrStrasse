TOOL.Category = "GRM"
TOOL.Name = "GRM: районы и точки"
TOOL.Command = nil
TOOL.ConfigName = ""

if CLIENT then
    language.Add("tool.grm_minimap.name", "GRM: районы и точки")
    language.Add("tool.grm_minimap.desc", "Размещение GPS-точек, районов и точек захвата")
    language.Add("tool.grm_minimap.0", "ЛКМ: точка | ПКМ: район | присед+ПКМ: вершина | присед+R: центр обзора карты")
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    if not IsValid(self:GetOwner()) or not self:GetOwner():IsSuperAdmin() then return false end
    if GRM.Minimap and GRM.Minimap.AddPoint then
        GRM.Minimap.AddPoint(self:GetOwner(), "Точка захвата", trace.HitPos, 180)
        self:GetOwner():ChatPrint("[Мини-карта] Точка захвата установлена. Откройте /grm_minimap_admin для настройки.")
        return true
    end
    return false
end

function TOOL:RightClick(trace)
    if CLIENT then return true end
    if not IsValid(self:GetOwner()) or not self:GetOwner():IsSuperAdmin() then return false end
    if self:GetOwner():Crouching() and GRM.Minimap and GRM.Minimap.AddDistrictVertex then
        local nearest, best
        for _, district in ipairs(GRM.Minimap.Data and GRM.Minimap.Data.districts or {}) do
            local c = district.center or {}
            local d = Vector(c.x or 0, c.y or 0, trace.HitPos.z):DistToSqr(trace.HitPos)
            if not best or d < best then nearest, best = district, d end
        end
        if nearest then GRM.Minimap.AddDistrictVertex(nearest.id, trace.HitPos); self:GetOwner():ChatPrint("[Мини-карта] Вершина полигона добавлена.") return true end
    end
    if GRM.Minimap and GRM.Minimap.AddDistrict then
        GRM.Minimap.AddDistrict(self:GetOwner(), "Новый район", trace.HitPos, 500)
        self:GetOwner():ChatPrint("[Мини-карта] Район установлен. Откройте /grm_minimap_admin для настройки.")
        return true
    end
    return false
end

function TOOL:Reload(trace)
    if CLIENT then return true end
    if IsValid(self:GetOwner()) and self:GetOwner():IsSuperAdmin() then
        if self:GetOwner():Crouching() and GRM.Minimap and GRM.Minimap.SetOverview then
            GRM.Minimap.SetOverview(trace.HitPos, 4096)
            self:GetOwner():ChatPrint("[Мини-карта] Центр обзора карты установлен в точке прицела.")
        elseif GRM.Minimap and GRM.Minimap.CloseNearestDistrict then
            GRM.Minimap.CloseNearestDistrict(trace.HitPos)
        end
        self:GetOwner():ConCommand("grm_minimap_admin")
        return true
    end
    return false
end
