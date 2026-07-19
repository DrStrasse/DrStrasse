--[[--------------------------------------------------------------------
    grm_keypad — Интерактивный Кейпад GRM (Код 70)
    Поддерживает:
      - 3D2D экран и интерактивные кнопки на корпусе
      - Режимы: PIN-код, Доступ Фракции, Платный проход (GRM Cash)
      - Прямую связку с Fading Door и Numpad
      - Взлом с помощью QTE-Отмычки ds_lockpick / Крякера
----------------------------------------------------------------------]]

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "FFD Keypad"
ENT.Author = "GRM"
ENT.Contact = ""
ENT.Purpose = "Электронный кодовый замок с 3D2D дисплеем"
ENT.Instructions = "Нажимайте кнопки на экране или используйте [E]"
ENT.Category = "GRM"

ENT.Spawnable = true
ENT.AdminSpawnable = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "Password")
    self:NetworkVar("String", 1, "DisplayText")
    self:NetworkVar("Int",    0, "Status")      -- 0: Normal, 1: Granted, 2: Denied
    self:NetworkVar("Int",    1, "Cost")        -- Платный проход в GRM
    self:NetworkVar("Int",    2, "Mode")        -- 0: PIN, 1: Faction, 2: Paid
    self:NetworkVar("String", 2, "Faction")     -- Код 104: список через запятую
end

-- ============================================================
-- Код 104 (находка 121): единая геометрия экрана кейпада.
-- Кейпад-модель (props_lab/keypad) смотрит лицом в +X: правильный спавн —
-- чистый ent:SetAngles(HitNormal:Angle()) БЕЗ доп. поворотов (лишние
-- RotateAroundAxis и клали кейпад набок, как на скрине владельца).
-- Оси плоскости 3D2D: экран-X = -GetRight(), экран-Y(вниз) = -GetUp(),
-- нормаль наружу = GetForward(). Поворачиваем угол как (Right, -90)
-- затем (Up, -90) — иначе текст зеркалит (старая пара (0,90,90) в
-- LocalToWorldAngles так и делала).
-- ============================================================
ENT.ScreenScale  = 0.035
ENT.ScreenW      = 144            -- размер клиентской отрисовки, px
ENT.ScreenH      = 220
ENT.ScreenFwdOff = 1.6            -- на сколько экран «приподнят» над лицом модели

ENT.Buttons = {
    { text = "1", x = 12, y = 80,  w = 36, h = 28 },
    { text = "2", x = 54, y = 80,  w = 36, h = 28 },
    { text = "3", x = 96, y = 80,  w = 36, h = 28 },
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

-- левая верхняя точка экрана в мире
function ENT:KeypadScreenOrigin()
    local s = self.ScreenScale or 0.035
    return self:GetPos()
        + self:GetForward() * (self.ScreenFwdOff or 1.6)
        + self:GetRight() * ((self.ScreenW or 144) * s / 2)
        + self:GetUp() * ((self.ScreenH or 220) * s / 2)
end

-- угол плоскости 3D2D (правильная, не зеркальная пара поворотов)
function ENT:KeypadScreenAngles()
    local ang = self:GetAngles()
    ang:RotateAroundAxis(ang:Right(), -90)
    ang:RotateAroundAxis(ang:Up(), -90)
    return ang
end

-- какая кнопка под мировой точкой (прицел): индекс, кнопка или nil
function ENT:KeypadButtonAt(hitPos)
    if not hitPos then return nil end
    local s = self.ScreenScale or 0.035
    local rel = hitPos - self:KeypadScreenOrigin()
    local x = rel:Dot(-self:GetRight()) / s
    local y = rel:Dot(-self:GetUp()) / s
    for i, b in ipairs(self.Buttons or {}) do
        if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
            return i, b
        end
    end
    return nil
end

if SERVER then
    function ENT:IsKeypadLocked()
        return self:GetStatus() == 2 or self.IsGrantActive
    end

    -- Код 104: фракция с доступом может быть СПИСКОМ через запятую
    -- (чекбоксы в панели тулгана). Пустая строка — доступа никому.
    function ENT:IsFactionAllowed(facName)
        local fac = string.Trim(tostring(self:GetFaction() or ""))
        if fac == "" or facName == nil or facName == "" then return false end
        for f in string.gmatch(fac, "([^,]+)") do
            if string.Trim(f) == facName then return true end
        end
        return false
    end
end

