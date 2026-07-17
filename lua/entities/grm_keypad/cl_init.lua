--[[--------------------------------------------------------------------
    grm_keypad — cl_init.lua (Клиентский 3D2D экран и интерактивные кнопки)
----------------------------------------------------------------------]]

include("shared.lua")

surface.CreateFont("Keypad_Screen", { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("Keypad_Btn",    { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("Keypad_Small",  { font = "Roboto", size = 12, weight = 500, extended = true })

local BUTTONS = {
    { text = "1", x = 12, y = 80, w = 36, h = 28 },
    { text = "2", x = 54, y = 80, w = 36, h = 28 },
    { text = "3", x = 96, y = 80, w = 36, h = 28 },

    { text = "4", x = 12, y = 114, w = 36, h = 28 },
    { text = "5", x = 54, y = 114, w = 36, h = 28 },
    { text = "6", x = 96, y = 114, w = 36, h = 28 },

    { text = "7", x = 12, y = 148, w = 36, h = 28 },
    { text = "8", x = 54, y = 148, w = 36, h = 28 },
    { text = "9", x = 96, y = 148, w = 36, h = 28 },

    { text = "CLR", x = 12, y = 182, w = 36, h = 28 },
    { text = "0",   x = 54, y = 182, w = 36, h = 28 },
    { text = "OK",  x = 96, y = 182, w = 36, h = 28 },
}

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local dist = ply:GetPos():DistToSqr(self:GetPos())
    if dist > 350 * 350 then return end

    local pos = self:LocalToWorld(Vector(2.4, -2.4, 4.4))
    local ang = self:LocalToWorldAngles(Angle(0, 90, 90))

    cam.Start3D2D(pos, ang, 0.035)
        -- Главный фон экрана
        draw.RoundedBox(6, 0, 0, 144, 220, Color(16, 20, 28, 250))
        surface.SetDrawColor(45, 55, 75)
        surface.DrawOutlinedRect(0, 0, 144, 220, 2)

        -- Шапка экрана
        local status = self:GetStatus()
        local mode = self:GetMode()

        local headerBg = Color(28, 36, 48)
        local statusText = "ВВЕДИТЕ ПИН"
        local statusColor = Color(220, 230, 245)

        if status == 1 then
            headerBg = Color(30, 140, 70)
            statusText = "ОТКРЫТО"
            statusColor = Color(255, 255, 255)
        elseif status == 2 then
            headerBg = Color(180, 50, 50)
            statusText = "ОТКАЗАНО"
            statusColor = Color(255, 255, 255)
        elseif mode == 1 then
            statusText = "ФРАКЦИЯ"
            statusColor = Color(80, 180, 255)
        elseif mode == 2 then
            statusText = tostring(self:GetCost()) .. " GRM"
            statusColor = Color(235, 180, 60)
        end

        draw.RoundedBoxEx(4, 4, 4, 136, 32, headerBg, true, true, false, false)
        draw.SimpleText(statusText, "Keypad_Screen", 72, 20, statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Индикатор введённых цифр
        local typed = self:GetDisplayText()
        if typed == "" and status == 0 and mode == 0 then typed = "_ _ _ _" end
        draw.RoundedBox(4, 4, 40, 136, 30, Color(24, 30, 42))
        draw.SimpleText(typed, "Keypad_Screen", 72, 55, Color(100, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- Кнопки
        for _, b in ipairs(BUTTONS) do
            local btnCol = Color(38, 46, 62)
            if b.text == "OK" then btnCol = Color(40, 140, 80)
            elseif b.text == "CLR" then btnCol = Color(160, 60, 60) end

            draw.RoundedBox(4, b.x, b.y, b.w, b.h, btnCol)
            draw.SimpleText(b.text, "Keypad_Btn", b.x + b.w / 2, b.y + b.h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()
end
