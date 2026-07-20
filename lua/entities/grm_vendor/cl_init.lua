--[[--------------------------------------------------------------------
    GRM Vendor Entity — client HUD label (Код 111)
----------------------------------------------------------------------]]

include("shared.lua")

surface.CreateFont("GRM_VendorLabel", {
    font = "Roboto",
    size = 20,
    weight = 700,
    extended = true,
    antialias = true,
})

local LABELS = {
    weapon = "🔫 Торговец оружием",
    ore    = "⛏️ Скупщик руды",
    food   = "🍎 Ларёк еды",
    rare   = " Торговец редкостями",
}

hook.Add("HUDPaint", "GRM_VendorLabel", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local maxDist = 300

    for _, ent in ipairs(ents.FindByClass("grm_vendor")) do
        if not IsValid(ent) then continue end

        local dist = ply:GetPos():Distance(ent:GetPos())
        if dist > maxDist then continue end

        -- Подсказка над головой NPC
        local offset = Vector(0, 0, 62)
        local scr = (ent:GetPos() + offset):ToScreen()
        if not scr.visible then continue end

        local x, y = scr.x, scr.y
        local alpha = math.Clamp(255 - (dist / maxDist) * 200, 55, 255)

        local vtype = ent:GetNWString("VendorType", ent.VendorType or "weapon")
        local text = LABELS[vtype] or "🏪 Торгаш"

        surface.SetFont("GRM_VendorLabel")
        local tw, th = surface.GetTextSize(text)
        local pad = 6

        -- Фон
        surface.SetDrawColor(0, 0, 0, alpha * 0.65)
        surface.DrawRect(x - pad, y - pad, tw + pad * 2, th + pad * 2)

        -- Текст
        surface.SetTextColor(255, 220, 80, alpha)
        surface.SetTextPos(x, y)
        surface.DrawText(text)

        -- Подсказка "E — купить" при близком расстоянии
        if dist < 120 then
            surface.SetFont("GRM_VendorLabel")
            local hint = "[E] — Открыть магазин"
            local hw, hh = surface.GetTextSize(hint)
            surface.SetDrawColor(0, 0, 0, alpha * 0.5)
            surface.DrawRect(x - pad, y + th + 4, hw + pad * 2, hh + pad)
            surface.SetTextColor(200, 220, 255, alpha)
            surface.SetTextPos(x, y + th + 4)
            surface.DrawText(hint)
        end
    end
end)

print("[GRM Vendor] Client HUD loaded")
