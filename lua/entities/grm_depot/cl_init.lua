include("shared.lua")

surface.CreateFont("GRMJobD_T", { font = "Roboto", size = 17, weight = 800, extended = true })
surface.CreateFont("GRMJobD_S", { font = "Roboto", size = 12, weight = 500, extended = true })

function ENT:Draw()
    self:DrawModel()
    local lp = LocalPlayer()
    if not IsValid(lp) or lp:GetPos():DistToSqr(self:GetPos()) > 300 * 300 then return end
    local ang = self:GetAngles()
    local maxs = self:OBBMaxs()
    local pos = self:GetPos() + ang:Up() * ((maxs and maxs.z or 60) + 12)
    -- v2.2.0: тип/имя точки подписываются (маршруты биржи труда)
    local jtype = tostring(self:GetNWString("GRM_JobType", "generic") or "generic")
    local jname = tostring(self:GetNWString("GRM_JobName", "") or "")
    local label = "Точка заданий биржи труда"
    if GRM and GRM.Jobs and istable(GRM.Jobs.DepotTypes) then
        local t = GRM.Jobs.DepotTypes[jtype] or GRM.Jobs.DepotTypes.generic
        if t then label = t.label end
    end
    if jname ~= "" then label = jname end
    cam.Start3D2D(pos, Angle(0, EyeAngles().y - 90, 90), 0.075)
        draw.RoundedBox(6, -140, -36, 280, 72, Color(14, 18, 26, 215))
        surface.SetDrawColor(80, 200, 170, 200)
        surface.DrawOutlinedRect(-140, -36, 280, 72, 2)
        draw.SimpleText("Точка биржи", "GRMJobD_T", 0, -30, Color(240, 245, 250), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText(label, "GRMJobD_S", 0, -4, Color(160, 170, 185), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    cam.End3D2D()
end
