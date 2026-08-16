include("shared.lua")

surface.CreateFont("GRMDutyNPC_Title", { font="Roboto", size=19, weight=800, extended=true })
surface.CreateFont("GRMDutyNPC_Faction", { font="Roboto", size=22, weight=900, extended=true })
surface.CreateFont("GRMDutyNPC_Text", { font="Roboto", size=13, weight=500, extended=true })

function ENT:Draw()
    self:DrawModel()
    local lp=LocalPlayer()
    if not IsValid(lp) or lp:GetPos():DistToSqr(self:GetPos())>550*550 then return end
    local pos=self:GetPos()+Vector(0,0,86)
    local ang=Angle(0,EyeAngles().y-90,90)
    local fac=self:GetNWString("GRM_DutyFaction","")
    local configured=fac~="" and fac~="*"
    cam.Start3D2D(pos,ang,0.075)
        draw.RoundedBox(8,-230,-62,460,124,Color(8,14,23,238))
        surface.SetDrawColor(configured and Color(48,204,255,220) or Color(244,78,96,220))
        surface.DrawOutlinedRect(-230,-62,460,124,2)
        draw.SimpleText(self:GetNWString("GRM_DutyTitle","ПУНКТ ВЫХОДА НА СЛУЖБУ"),"GRMDutyNPC_Title",0,-49,Color(225,238,247),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
        draw.SimpleText(configured and fac or "НЕ НАСТРОЕН", "GRMDutyNPC_Faction",0,-15,configured and Color(48,204,255) or Color(244,78,96),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
        draw.SimpleText(configured and "E — выйти на службу / завершить службу" or "Суперадмин: ПКМ инструментом для настройки","GRMDutyNPC_Text",0,25,Color(132,160,178),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
    cam.End3D2D()
end
