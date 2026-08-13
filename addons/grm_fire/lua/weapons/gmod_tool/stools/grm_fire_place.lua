--[[--------------------------------------------------------------------
    Расстановка железа пожарных. SuperAdmin.
    Категория GRM — общая вкладка со всеми инструментами.
    ЛКМ — поставить / навесить насос или лестницу на машину.
    R — удалить нашу сущность.
----------------------------------------------------------------------]]
TOOL.Category = "GRM"
TOOL.Name = "#tool.grm_fire_place.name"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar = { type = "hydrant" }

if CLIENT then
    language.Add("tool.grm_fire_place.name", "GRM Пожарное железо")
    language.Add("tool.grm_fire_place.desc", "Гидрант, насос, шкаф, точка очага, лестница")
    language.Add("tool.grm_fire_place.0", "ЛКМ: поставить | ЛКМ по машине (насос/лестница): навесить | R: удалить")
end

local TYPES = {
    hydrant = { class = "grm_fire_hydrant", label = "Гидрант" },
    pump    = { class = "grm_fire_pump",    label = "Насос (призрак, 4 рукава)" },
    cabinet = { class = "grm_fire_cabinet", label = "Шкаф огнетушителей" },
    spot    = { class = "grm_fire_spot",    label = "Точка очага" },
    ladder  = { class = "grm_fire_ladder",  label = "Пожарная лестница" },
}

local function can(ply)
    return IsValid(ply) and ply:IsSuperAdmin()
end

local function isCar(ent)
    if not IsValid(ent) then return false end
    if ent.IsVehicle and ent:IsVehicle() then return true end
    local cls = ent:GetClass() or ""
    return string.find(cls, "vehicle", 1, true) or string.StartWith(cls, "simfphys_")
        or string.StartWith(cls, "lvs_") or string.StartWith(cls, "glide_")
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not can(ply) or not trace or not trace.Hit then return false end
    local t = TYPES[self:GetClientInfo("type") or "hydrant"] or TYPES.hydrant

    if t.class == "grm_fire_pump" and isCar(trace.Entity) then
        local pump = ents.Create("grm_fire_pump")
        if not IsValid(pump) then return false end
        pump:SetPos(trace.HitPos + trace.HitNormal * 8)
        pump:Spawn()
        pump:Activate()
        pump:AttachToVehicle(trace.Entity, Vector(0, -46, 16), Angle(0, 90, 0))
        hook.Run("GRM_FireAddon_Placed", pump, ply)
        if ply.ChatPrint then ply:ChatPrint("[Пожар] Насос-призрак на борту. 4 рукава. Без коллизии.") end
        return true
    end

    if t.class == "grm_fire_ladder" and isCar(trace.Entity) then
        local lad = ents.Create("grm_fire_ladder")
        if not IsValid(lad) then return false end
        lad:SetPos(trace.HitPos + trace.HitNormal * 8)
        lad:Spawn()
        lad:Activate()
        lad:AttachToVehicle(trace.Entity, Vector(0, 50, 12), Angle(0, 0, 0))
        hook.Run("GRM_FireAddon_Placed", lad, ply)
        if ply.ChatPrint then ply:ChatPrint("[Пожар] Лестница на борту. E — выдвинуть.") end
        return true
    end

    local ent = ents.Create(t.class)
    if not IsValid(ent) then return false end
    ent:SetPos(trace.HitPos + trace.HitNormal * 4)
    ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
    ent:Spawn()
    ent:Activate()
    hook.Run("GRM_FireAddon_Placed", ent, ply)
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
        or c == "grm_fire_hose" or c == "grm_fire_hose_node" or c == "grm_fire_ladder" then
        trace.Entity:Remove()
        if ply.ChatPrint then ply:ChatPrint("[Пожар] Удалено.") end
        return true
    end
    return false
end

if CLIENT then
    function TOOL.BuildCPanel(panel)
        panel:AddControl("Header", { Description = "Железо пожарных. Категория GRM. Рукава — E на гидрант/насос." })
        local t = panel:ComboBox("Тип", "grm_fire_place_type")
        t:AddChoice("Гидрант (2 порта)", "hydrant")
        t:AddChoice("Насос машины (призрак, 4 рукава)", "pump")
        t:AddChoice("Шкаф огнетушителей", "cabinet")
        t:AddChoice("Точка очага (невидима)", "spot")
        t:AddChoice("Пожарная лестница", "ladder")
        panel:Help(
            "ЛКМ по полу — поставить.\n" ..
            "ЛКМ по машине (насос/лестница) — навесить сбоку, без коллизии.\n" ..
            "R — удалить.\n\n" ..
            "РУКАВ:\n" ..
            "E на открытый гидрант / насос — взять.\n" ..
            "Идёшь — кабель по земле, до 2200 юн.\n" ..
            "Назад по рукаву — сматывается.\n" ..
            "E снова на свой гидрант/насос — свернуть целиком.\n" ..
            "ПКМ — бросить ствол. R — узел.\n\n" ..
            "ЛЕСТНИЦА: E на бортовой — выдвинуть. Подойти и W / прыжок — залезть."
        )
    end
end
