include("shared.lua")

surface.CreateFont("GRM_VendorLabel", { font = "Roboto", size = 22, weight = 700, extended = true, antialias = true })

hook.Add("HUDPaint", "GRM_VendorLabel", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local maxDist = 300
    for _, ent in ipairs(ents.FindByClass("grm_vendor")) do
        if not IsValid(ent) then continue end
        local dist = ply:GetPos():Distance(ent:GetPos())
        if dist > maxDist then continue end
        local offset = Vector(0, 0, 55)
        local scr = (ent:GetPos() + offset):ToScreen()
        if not scr.visible then continue end
        local x, y = scr.x, scr.y
        local alpha = math.Clamp(255 - (dist / maxDist) * 200, 55, 255)
        local labels = { weapon = "Торговец оружием", ore = "Скупщик руды", food = "Ларек еды", rare = "Торговец редкостями" }
        local text = labels[ent.VendorType] or "Торгаш"
        surface.SetFont("GRM_VendorLabel")
        local tw, th = surface.GetTextSize(text)
        local pad = 8
        surface.SetDrawColor(0, 0, 0, alpha * 0.6)
        surface.DrawRect(x - pad, y - pad, tw + pad*2, th + pad*2)
        surface.SetTextColor(255, 220, 80, alpha)
        surface.SetTextPos(x, y)
        surface.DrawText(text)
    end
end)