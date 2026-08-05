--[[--------------------------------------------------------------------
    grm_bank_vault — клиент: 3D2D-дисплей «В ГОСБЮДЖЕТЕ СЕЙЧАС»
----------------------------------------------------------------------]]
include("shared.lua")

surface.CreateFont("GRMVault_Title", { font = "Roboto", size = 17, weight = 900, extended = true })
surface.CreateFont("GRMVault_Normal", { font = "Roboto", size = 12, weight = 600, extended = true })
surface.CreateFont("GRMVault_Small", { font = "Roboto", size = 10, weight = 500, extended = true })

local function money(n)
    return GRM and GRM.Format and GRM.Format(tonumber(n) or 0) or (tostring(math.floor(tonumber(n) or 0)) .. " GRM")
end

function ENT:Draw()
    self:DrawModel()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > 900 * 900 then return end

    local pos = self:GetPos() + self:GetUp() * 42
    local ang = Angle(0, EyeAngles().y - 90, 90)
    cam.Start3D2D(pos, ang, 0.07)
        local w, h = 340, 120
        draw.RoundedBox(8, -w/2, -h/2, w, h, Color(8, 12, 18, 225))
        draw.RoundedBox(6, -w/2 + 5, -h/2 + 5, w - 10, h - 10, Color(16, 24, 34, 235))
        draw.SimpleText("БАНКОВСКОЕ ХРАНИЛИЩЕ", "GRMVault_Title", 0, -46, Color(120, 210, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("В ГОСБЮДЖЕТЕ СЕЙЧАС: " .. money(self:GetStateBudget() or 0), "GRMVault_Title", 0, -20, Color(255, 220, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("В хранилище: " .. money(self:GetHeldCash() or 0) .. " / " .. money(self:GetCapacity() or 0), "GRMVault_Normal", 0, 12, Color(200, 220, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Деньги дропаются сюда при пополнении/изъятии гос.бюджета и печати станка", "GRMVault_Small", 0, 36, Color(140, 155, 175), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("E — статус (для сотрудников банка)", "GRMVault_Small", 0, 52, Color(110, 130, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end
