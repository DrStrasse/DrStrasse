include("shared.lua")

surface.CreateFont("GRMCorp_T", { font = "Roboto", size = 16, weight = 800, extended = true })
surface.CreateFont("GRMCorp_S", { font = "Roboto", size = 12, weight = 500, extended = true })

-- Метка над телом (сам маркер NoDraw, поэтому рисуем глобальным хуком —
-- тот же паттерн, что у маркера заданий биржи).
hook.Add("PostDrawTranslucentRenderables", "GRM_Corpse_Label", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    for _, ent in ipairs(ents.FindByClass("grm_corpse")) do
        if IsValid(ent) and lp:GetPos():DistToSqr(ent:GetPos()) <= 400 * 400 then
            local pos = ent:GetPos() + Vector(0, 0, 74)
            local ang = Angle(0, EyeAngles().y - 90, 90)
            local name = tostring(ent:GetNWString("GRM_CorpseVictim", "Тело") or "Тело")
            cam.Start3D2D(pos, ang, 0.09)
                draw.RoundedBox(6, -160, -34, 320, 46, Color(14, 18, 26, 215))
                surface.SetDrawColor(220, 75, 70, 200)
                surface.DrawOutlinedRect(-160, -34, 320, 46, 2)
                draw.SimpleText("✝ ТЕЛО", "GRMCorp_T", 0, -28, Color(255, 150, 140), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                draw.SimpleText(name .. " • осмотр: E / /examine", "GRMCorp_S", 0, -6, Color(200, 205, 215), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
            cam.End3D2D()
        end
    end
end)
