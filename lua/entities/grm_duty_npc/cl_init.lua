include("shared.lua")

surface.CreateFont("GRMDutyNPC_Title", { font="Roboto", size=19, weight=800, extended=true })
surface.CreateFont("GRMDutyNPC_Text", { font="Roboto", size=13, weight=500, extended=true })

function ENT:Draw()
    self:DrawModel()
    local lp=LocalPlayer()
    if not IsValid(lp) or lp:GetPos():DistToSqr(self:GetPos())>450*450 then return end
    local pos=self:GetPos()+Vector(0,0,82)
    local ang=Angle(0,EyeAngles().y-90,90)
    cam.Start3D2D(pos,ang,0.075)
        draw.RoundedBox(7,-190,-42,380,84,Color(8,14,23,230))
        surface.SetDrawColor(48,204,255,190) surface.DrawOutlinedRect(-190,-42,380,84,2)
        draw.SimpleText(self:GetNWString("GRM_DutyTitle","ПУНКТ ВЫХОДА НА СЛУЖБУ"),"GRMDutyNPC_Title",0,-30,Color(225,238,247),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
        local fac=self:GetNWString("GRM_DutyFaction","")
        draw.SimpleText((fac=="" or fac=="*") and "Все фракции • нажмите E" or (fac.." • нажмите E"),"GRMDutyNPC_Text",0,5,Color(132,160,178),TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
    cam.End3D2D()
end
