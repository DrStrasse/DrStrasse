include("shared.lua")

local COL_LABEL = Color(255, 210, 210)
local COL_DIM = Color(180, 150, 150)
local COL_DONE = Color(150, 240, 170)

--[[ ВРАЩЕНИЕ — НА КЛИЕНТЕ (заказ владельца: «чекпоинты крутящиеся»).

     Считаем угол от RealTime и рисуем модель повёрнутой. Гонять угол по
     сети каждый кадр ради украшения — пустая нагрузка и на сервер, и на
     канал: на игровую логику вращение не влияет никак.

     RealTime, а не CurTime: он не замирает на паузе одиночной игры и не
     дёргается при лагах сервера, поэтому вращение остаётся ровным. ]]
function ENT:Draw()
    local base = self:GetAngles()
    local spin = (RealTime() * (self.SpinSpeed or 45)) % 360

    local ang = Angle(base.p, base.y + spin, base.r)
    self:SetRenderAngles(ang)
    self:DrawModel()
    self:SetRenderAngles(nil)          -- иначе поворот утечёт на другие проходы

    local ply = LocalPlayer()
    if not IsValid(ply) then return end

    local pos = self:GetPos()
    if ply:GetPos():DistToSqr(pos) > 900 * 900 then return end

    local label = self:GetLabel()
    if label == "" then label = "Чекпоинт" end
    local done = self:GetReached()

    local look = (ply:EyeAngles() or Angle(0, 0, 0))
    local textAng = Angle(0, look.y - 90, 90)

    cam.Start3D2D(pos + Vector(0, 0, 26), textAng, 0.12)
        draw.SimpleText(string.upper(label), "Trebuchet24", 0, -14,
            done and COL_DONE or COL_LABEL, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(done and "пройдено" or "цель задания", "Trebuchet24", 0, 12,
            done and COL_DONE or COL_DIM, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

--[[ Маркер полупрозрачный, значит движок обязан рисовать его в
     translucent-проходе. Без этого сквозь него не видно того, что
     позади, и «прозрачность 50%» на глаз пропадает. ]]
function ENT:GetRenderGroup()
    return RENDERGROUP_BOTH
end
