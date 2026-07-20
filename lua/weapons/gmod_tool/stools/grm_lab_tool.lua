TOOL.Category = "GRM"
TOOL.Name = "Лаборатория"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar = {
    grm_lab_type = "narc",
}

local LAB_TYPES = {
    narc = {
        name = "Лаборатория наркотиков",
        class = "grm_narc_lab",
        model = "models/props_wasteland/laundry_washer003.mdl",
    },
    med = {
        name = "Медицинская лаборатория",
        class = "grm_med_lab",
        model = "models/props_wasteland/laundry_washer003.mdl",
    },
}

if CLIENT then
    language.Add("tool.grm_lab_tool.name", "GRM Лаборатория")
    language.Add("tool.grm_lab_tool.desc", "Спавн лабораторий: наркотиков / медицины")
    language.Add("tool.grm_lab_tool.0", "ЛКМ: Поставить лабораторию. R: Удалить. Z: Отмена")
end

function TOOL:LeftClick(tr)
    if not tr.Hit then return false end
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        GRM.Notify(ply, "Только суперадмин!", 255, 100, 100)
        return false
    end

    local labType = self:GetClientInfo("grm_lab_type")
    if not LAB_TYPES[labType] then
        GRM.Notify(ply, "Неизвестный тип лаборатории", 255, 100, 100)
        return false
    end

    local labInfo = LAB_TYPES[labType]
    local ent = ents.Create(labInfo.class)
    if not IsValid(ent) then return false end

    ent:SetPos(tr.HitPos + tr.HitNormal * 8)
    ent:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
    ent:Spawn()
    ent:Activate()

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end

    undo.Create("GRM_Lab")
        undo.AddEntity(ent)
        undo.SetPlayer(ply)
    undo.Finish()

    ply:ChatPrint("[Лаборатория] Поставлен: " .. labInfo.name)
    return true
end

function TOOL:RightClick(tr)
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsSuperAdmin() then return false end

    local ent = tr.Entity
    if not IsValid(ent) then return false end

    if ent:GetClass() == "grm_narc_lab" or ent:GetClass() == "grm_med_lab" then
        ent:Remove()
        ply:ChatPrint("[Лаборатория] Удалён")
        return true
    end

    return false
end

function TOOL:Reload(tr)
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsSuperAdmin() then return false end

    local ent = tr.Entity
    if not IsValid(ent) then return false end

    if ent:GetClass() == "grm_narc_lab" or ent:GetClass() == "grm_med_lab" then
        ent:Remove()
        ply:ChatPrint("[Лаборатория] Удалён")
        return true
    end

    return false
end

function TOOL.BuildCPanel(CPanel)
    CPanel:AddControl("Header", {
        Description = "Спавн лабораторий: наркотиков и медицинских"
    })

    CPanel:AddControl("ComboBox", {
        Label = "Тип лаборатории",
        Options = {
            ["Лаборатория наркотиков"] = { grm_lab_type = "narc" },
            ["Медицинская лаборатория"] = { grm_lab_type = "med" },
        }
    })

    CPanel:Help("ЛКМ — поставить лабораторию\nR — удалить лабораторию\nZ — отмена последнего")
end
