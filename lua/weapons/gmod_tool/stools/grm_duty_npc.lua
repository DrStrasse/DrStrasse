TOOL.Category = "GRM"
TOOL.Name = "#tool.grm_duty_npc.name"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar = {
    faction = "*",
    title = "ПУНКТ ВЫХОДА НА СЛУЖБУ",
    model = "models/Humans/Group01/Male_07.mdl",
    make_perm = "1",
}

if CLIENT then
    language.Add("tool.grm_duty_npc.name", "GRM Служебный диспетчер")
    language.Add("tool.grm_duty_npc.desc", "NPC для выхода сотрудников на службу и ухода со службы")
    language.Add("tool.grm_duty_npc.0", "ЛКМ: поставить | ПКМ: открыть | R: удалить")
end

function TOOL:LeftClick(tr)
    if CLIENT then return true end
    local ply=self:GetOwner()
    if not IsValid(ply) or not ply:IsSuperAdmin() or not tr or not tr.Hit then return false end
    local ent=ents.Create("grm_duty_npc")
    if not IsValid(ent) then return false end
    local mdl=self:GetClientInfo("model")
    if not util.IsValidModel(mdl or "") then mdl="models/Humans/Group01/Male_07.mdl" end
    local fac=string.sub(string.Trim(self:GetClientInfo("faction") or "*"),1,80)
    if fac=="" then fac="*" end
    local title=string.sub(string.Trim(self:GetClientInfo("title") or ""),1,80)
    if title=="" then title="ПУНКТ ВЫХОДА НА СЛУЖБУ" end
    ent:SetNWString("GRM_DutyModel",mdl)
    ent:SetNWString("GRM_DutyFaction",fac)
    ent:SetNWString("GRM_DutyTitle",title)
    ent:SetPos(tr.HitPos+tr.HitNormal*2)
    ent:SetAngles(Angle(0,ply:EyeAngles().y+180,0))
    ent:Spawn() ent:Activate()
    if self:GetClientInfo("make_perm")~="0" and GRM.Perm and GRM.Perm.Add then GRM.Perm.Add(ply,ent,{ownerKind="server",freeze=true,label="Служебный диспетчер"}) end
    if GRM.Notify then GRM.Notify(ply,"Служебный диспетчер установлен.",80,230,150) end
    return true
end

function TOOL:RightClick(tr)
    if CLIENT then return true end
    local ply=self:GetOwner(); local ent=tr and tr.Entity
    if not IsValid(ply) or not IsValid(ent) or ent:GetClass()~="grm_duty_npc" then return false end
    if GRM and GRM.FactionDuty and GRM.FactionDuty.Open then GRM.FactionDuty.Open(ply,ent) end
    return true
end

function TOOL:Reload(tr)
    if CLIENT then return true end
    local ply=self:GetOwner(); local ent=tr and tr.Entity
    if not IsValid(ply) or not ply:IsSuperAdmin() or not IsValid(ent) or ent:GetClass()~="grm_duty_npc" then return false end
    if GRM.Perm and GRM.Perm.Remove then GRM.Perm.Remove(ply,ent,false) end
    ent:Remove()
    return true
end

function TOOL.BuildCPanel(panel)
    panel:AddControl("Header",{Description="Сотрудник фракции по умолчанию находится на службе. У этого NPC он меняет статус, форму и снаряжение."})
    panel:TextEntry("Фракция (* = все)","grm_duty_npc_faction")
    panel:TextEntry("Заголовок","grm_duty_npc_title")
    panel:TextEntry("Модель NPC","grm_duty_npc_model")
    panel:CheckBox("Сохранить на карте","grm_duty_npc_make_perm")
end
