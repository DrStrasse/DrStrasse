include("shared.lua")

surface.CreateFont("GRM_Printer_Font", {
    font = "Roboto",
    size = 14,
    weight = 500,
    extended = true
})

function ENT:Draw()
    self:DrawModel()

    -- 3D2D текст над принтером
    local pos = self:GetPos() + Vector(0, 0, 20)
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)

    cam.Start3D2D(pos, ang, 0.1)
        draw.SimpleTextOutlined(
            "Денежный принтер",
            "GRM_Printer_Font",
            0, 0,
            Color(255, 255, 255),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER,
            1,
            Color(0, 0, 0)
        )

        local printed = self:GetPrinted()
        local max = self:GetMaxMoney()
        local percent = math.floor((printed / max) * 100)

        draw.SimpleTextOutlined(
            printed .. " / " .. max .. " (" .. percent .. "%)",
            "GRM_Printer_Font",
            0, 20,
            Color(100, 220, 100),
            TEXT_ALIGN_CENTER,
            TEXT_ALIGN_CENTER,
            1,
            Color(0, 0, 0)
        )

        if not self:GetActive() then
            draw.SimpleTextOutlined(
                "СЛОМАЛСЯ",
                "GRM_Printer_Font",
                0, 40,
                Color(255, 100, 100),
                TEXT_ALIGN_CENTER,
                TEXT_ALIGN_CENTER,
                1,
                Color(0, 0, 0)
            )
        end
    cam.End3D2D()
end

net.Receive("GRM_Printer_Broken", function()
    local ent = net.ReadEntity()
    if IsValid(ent) then
        notification.AddLegacy("Денежный принтер сломался!", NOTIFY_ERROR, 5)
    end
end)
