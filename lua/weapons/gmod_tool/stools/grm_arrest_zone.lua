TOOL.Category = "GRM"
TOOL.Name = "GRM: Зона тюрьмы"
TOOL.Command = nil
TOOL.ConfigName = ""

if CLIENT then
    language.Add("tool.grm_arrest_zone.name", "GRM: Зона тюрьмы")
    language.Add("tool.grm_arrest_zone.desc", "Прямоугольная зона, внутри которой разрешён арест")
    language.Add("tool.grm_arrest_zone.0", "ЛКМ: первый угол | ПКМ: второй угол и сохранить")
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
