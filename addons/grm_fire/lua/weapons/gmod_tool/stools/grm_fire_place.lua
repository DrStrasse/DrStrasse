--[[--------------------------------------------------------------------
    Расстановка железа пожарных. SuperAdmin.
    ЛКМ — поставить / навесить насос на машину.
    R — удалить нашу сущность.
----------------------------------------------------------------------]]
TOOL.Category = "GRM Fire"
TOOL.Name = "#tool.grm_fire_place.name"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar = { type = "hydrant" }

if CLIENT then
    language.Add("tool.grm_fire_place.name", "GRM Пожарное железо")
    language.Add("tool.grm_fire_place.desc", "Гидрант, насос, шкаф, точка очага")
    language.Add("tool.grm_fire_place.0", "ЛКМ: поставить | ЛКМ по машине в режиме насоса: навесить | R: удалить")
end

local TYPES = {
    hydrant = { class = "grm_fire_hydrant", label = "Гидрант" },
    pump    = { class = "grm_fire_pump",    label = "Насос (4 рукава)" },
    cabinet = { class = "grm_fire_cabinet", label = "Шкаф огнетушителей" },
    spot    = { class = "grm_fire_spot",    label = "Точка очага" },
}

local function can(ply)
    return IsValid(ply) and ply:IsSuperAdmin()
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not can(ply) or not trace or not trace.Hit then return false end
    local t = TYPES[self:GetClientInfo("type") or "hydrant"] or TYPES.hydrant

    if t.class == "grm_fire_pump" and IsValid(trace.Entity) and (trace.Entity:IsVehicle() or string.find(trace.Entity:GetClass() or "", "vehicle", 1, true)) then
        local pump = ents.Create("grm_fire_pump")
        if not IsValid(pump) then return false end
        pump:SetPos(trace.HitPos + trace.HitNormal * 8)
        pump:Spawn()
        pump:Activate()
        pump:AttachToVehicle(trace.Entity, Vector(0, -40, 20), Angle(0, 90, 0))
        if ply.ChatPrint then ply:ChatPrint("[Пожар] Насос навешен на машину. 4 рукава.") end
        return true
    end

    local ent = ents.Create(t.class)
    if not IsValid(ent) then return false end
    ent:SetPos(trace.HitPos + trace.HitNormal * 4)
    ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    ent:Spawn()
    ent:Activate()
    if ply.ChatPrint then ply:ChatPrint("[Пожар] Поставлено: " .. t.label) end
    return true
end

function TOOL:RightClick(trace)
    if CLIENT then return true end
    return false
end

function TOOL:Reload(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not can(ply) or not IsValid(trace.Entity) then return false end
    local c = trace.Entity:GetClass()
    if c == "grm_fire_hydrant" or c == "grm_fire_pump" or c == "grm_fire_cabinet" or c == "grm_fire_spot"
        or c == "grm_fire_hose" or c == "grm_fire_hose_node" then
        trace.Entity:Remove()
        if ply.ChatPrint then ply:ChatPrint("[Пожар] Удалено.") end
        return true
    end
    return false
end

if CLIENT then
    function TOOL.BuildCPanel(panel)
        panel:AddControl("Header", { Description = "Железо пожарных. Рукава берутся с гидранта/насоса клавишей E." })
        local t = panel:ComboBox("Тип", "grm_fire_place_type")
        t:AddChoice("Гидрант (2 порта)", "hydrant")
        t:AddChoice("Насос машины (4 рукава)", "pump")
        t:AddChoice("Шкаф огнетушителей", "cabinet")
        t:AddChoice("Точка очага (рандом)", "spot")
        panel:Help("ЛКМ по полу — поставить.\nЛКМ по машине в режиме насоса — навесить катушку.\nR — удалить.\n\nИгроки: E на открытый гидрант / насос — взять рукав и идти. Линия кладётся по земле, тянется до 850 юн. ПКМ — бросить ствол. R на стволе — узел. E на другой гидрант/насос — стык.")
    end
end
