--[[--------------------------------------------------------------------
    GRM Vendor Entity — вывеска торговца в стиле GRM.

    Было: HUDPaint каждый кадр обходил ВСЕХ торговцев на карте и рисовал
    плоский чёрный прямоугольник с текстом (плюс эмодзи, которые часть
    шрифтов не тянет). Стало: 3D2D-вывеска в палитре GRM рисуется самим
    энтити (ENT:Draw), то есть только когда торговец в кадре.
----------------------------------------------------------------------]]
include("shared.lua")

surface.CreateFont("GRM_VendorSign",  { font = "Roboto", size = 26, weight = 800, extended = true })
surface.CreateFont("GRM_VendorLabel", { font = "Roboto", size = 17, weight = 700, extended = true })
surface.CreateFont("GRM_VendorHint",  { font = "Roboto", size = 14, weight = 600, extended = true })

local LABELS = {
    weapon    = "ТОРГОВЕЦ ОРУЖИЕМ",
    ore       = "СКУПЩИК РУДЫ",
    food      = "ЛАРЁК ЕДЫ",
    rare      = "ТОРГОВЕЦ РЕДКОСТЯМИ",
    accessory = "ТОРГОВЕЦ АКСЕССУАРАМИ",
    phone     = "САЛОН СВЯЗИ",
}

local COLORS = {
    weapon    = Color(225, 110, 90),
    ore       = Color(245, 195, 65),
    food      = Color(120, 210, 130),
    rare      = Color(190, 140, 245),
    accessory = Color(75, 195, 170),
    phone     = Color(90, 165, 245),
}

function ENT:Draw()
    self:DrawModel()

    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    local dist = lp:GetPos():DistToSqr(self:GetPos())
    if dist > 400 * 400 then return end

    local vtype = self:GetNWString("VendorType", self.VendorType or "weapon")
    local title = LABELS[vtype] or "ТОРГОВЕЦ GRM"
    local name = self:GetNWString("GRMVendorName", "")
    local accent = COLORS[vtype] or Color(245, 195, 65)

    local ang = Angle(0, (lp:EyeAngles().y + 90) % 360, 90)
    cam.Start3D2D(self:GetPos() + Vector(0, 0, 82), ang, 0.16)
        draw.RoundedBox(8, -180, -46, 360, 84, Color(12, 17, 25, 235))
        draw.RoundedBox(8, -180, -46, 360, 6, accent)
        draw.SimpleText(title, "GRM_VendorSign", 0, -24, accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        draw.SimpleText(name ~= "" and name or "Товары и услуги", "GRM_VendorLabel", 0, 4,
            Color(235, 240, 248), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        if dist < 220 * 220 then
            draw.SimpleText("E — открыть магазин", "GRM_VendorHint", 0, 24,
                Color(120, 205, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    cam.End3D2D()
end
