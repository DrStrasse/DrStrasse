--[[--------------------------------------------------------------------
    grm_keypad — cl_init.lua (Клиентская 3D2D-панель, Код 104)

    Геометрия — только через shared-хелперы (KeypadScreenOrigin/Angles):
    правильный спавн кейпада — чистый HitNormal:Angle() без поворотов,
    плоскость строится парой (Right,-90)/(Up,-90) — текст больше не
    зеркалит. Кнопка под прицелом подсвечивается и жмётся по E; нажатие
    подсвечивается вспышкой у ВСЕХ клиентов (net GRM_KeypadPress),
    цвет шапки плавно лерпается, курсор поля ввода мигает.
----------------------------------------------------------------------]]

include("shared.lua")

surface.CreateFont("Keypad_Screen", { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("Keypad_Btn",    { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("Keypad_Small",  { font = "Roboto", size = 12, weight = 500, extended = true })

net.Receive("GRM_KeypadPress", function()
    local ent = net.ReadEntity()
    local idx = net.ReadUInt(8)
    if not IsValid(ent) then return end
    ent.__btnFlash = ent.__btnFlash or {}
    ent.__btnFlash[idx] = CurTime() + 0.25
end)

local function lerpColor(cur, target, rate)
    local f = math.min(1, rate)
    cur.r = cur.r + (target.r - cur.r) * f
    cur.g = cur.g + (target.g - cur.g) * f
    cur.b = cur.b + (target.b - cur.b) * f
    cur.a = cur.a + (target.a - cur.a) * f
    return cur
end

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local dist = ply:GetPos():DistToSqr(self:GetPos())
    if dist > 350 * 350 then return end

    -- какая кнопка под прицелом (подсветка + намёк, что жать E)
    local hoverIdx = nil
    if dist < 140 * 140 then
        local tr = ply:GetEyeTrace()
        if tr and IsValid(tr.Entity) and tr.Entity == self then
            hoverIdx = self:KeypadButtonAt(tr.HitPos)
        end
    end

    local S = self.ScreenScale or 0.035
    local W = self.ScreenW or 144
    local H = self.ScreenH or 220

    cam.Start3D2D(self:KeypadScreenOrigin(), self:KeypadScreenAngles(), S)
        -- фон панели
        draw.RoundedBox(6, 0, 0, W, H, Color(16, 20, 28, 250))
        surface.SetDrawColor(45, 55, 75)
        surface.DrawOutlinedRect(0, 0, W, H, 2)

        -- шапка (плавный переход цвета статуса)
        local status = self:GetStatus()
        local mode = self:GetMode()
        local headerTarget = Color(28, 36, 48)
        local statusText = "ВВЕДИТЕ ПИН"
        local statusColor = Color(220, 230, 245)

        if status == 1 then
            headerTarget = Color(30, 140, 70)
            statusText = "ОТКРЫТО"
            statusColor = Color(255, 255, 255)
        elseif status == 2 then
            headerTarget = Color(180, 50, 50)
            statusText = "ОТКАЗАНО"
            statusColor = Color(255, 255, 255)
        elseif mode == 1 then
            statusText = "ФРАКЦИЯ"
            statusColor = Color(80, 180, 255)
        elseif mode == 2 then
            statusText = tostring(self:GetCost()) .. " GRM"
            statusColor = Color(235, 180, 60)
        end

        self.__hdrCol = self.__hdrCol or Color(headerTarget.r, headerTarget.g, headerTarget.b)
        lerpColor(self.__hdrCol, headerTarget, FrameTime() * 10)
        draw.RoundedBoxEx(4, 4, 4, W - 8, 32, self.__hdrCol, true, true, false, false)
        draw.SimpleText(statusText, "Keypad_Screen", W / 2, 20, statusColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- поле ввода с мигающим курсором
        local typed = self:GetDisplayText()
        if status == 0 and mode == 0 then
            if typed == "" then typed = "_ _ _ _"
            elseif math.floor(CurTime() * 2) % 2 == 0 then typed = typed .. "▪" end
        end
        draw.RoundedBox(4, 4, 40, W - 8, 30, Color(24, 30, 42))
        draw.SimpleText(typed, "Keypad_Screen", W / 2, 55, Color(100, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

        -- кнопки: подсветка под прицелом + вспышка нажатия
        local now = CurTime()
        for i, b in ipairs(self.Buttons or {}) do
            local btnCol = Color(38, 46, 62)
            if b.text == "OK" then btnCol = Color(40, 140, 80)
            elseif b.text == "CLR" then btnCol = Color(160, 60, 60) end

            if hoverIdx == i then
                btnCol = Color(math.min(255, btnCol.r + 45), math.min(255, btnCol.g + 45), math.min(255, btnCol.b + 45))
            end
            if self.__btnFlash and (self.__btnFlash[i] or 0) > now then
                btnCol = Color(240, 240, 250)
            end

            draw.RoundedBox(4, b.x, b.y, b.w, b.h, btnCol)
            draw.SimpleText(b.text, "Keypad_Btn", b.x + b.w / 2, b.y + b.h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()
end
