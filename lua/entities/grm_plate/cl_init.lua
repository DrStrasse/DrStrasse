include("shared.lua")

--[[ РИСОВАНИЕ НОМЕРА НА ЗНАКЕ.

     Первая версия строила плоскость «на глазок» поворотами RotateAroundAxis
     и промахивалась: надпись уходила ребром к игроку и её не было видно, а
     поле знака рисовалось поперёк (заказ владельца: «номер повернуть на 90»).

     Теперь плоскость строится честно по габаритам модели:
       • самая тонкая ось OBB — это толщина знака, её направление и есть
         нормаль лицевой стороны;
       • из двух оставшихся осей ДЛИННАЯ всегда идёт вдоль строки номера,
         короткая — вверх. Поэтому номер стоит правильно на любой модели и
         при любом развороте знака;
       • угол собирается через Vector:AngleEx(up) — без ручных поворотов.
     Номер печатается с ОБЕИХ сторон, чтобы знак читался, как его ни повесь.
----------------------------------------------------------------------]]

function ENT:Initialize()
    self:SetMaterial(self.Material)
end

--- Геометрия лицевой стороны: считает общий слой, здесь только кэш.
local function faceGeometry(ent)
    if ent.GRMFace then return ent.GRMFace end
    local PL = GRM and GRM.Plates
    if not (PL and PL.FaceGeometry) then return nil end
    ent.GRMFace = PL.FaceGeometry(ent:OBBMins(), ent:OBBMaxs(), PL.Render)
    return ent.GRMFace
end

--- Локальное направление → мировое (без ручных поворотов углов).
local function worldDir(ent, localVec)
    return (ent:LocalToWorld(localVec) - ent:GetPos()):GetNormalized()
end

function ENT:Draw()
    self:DrawModel()

    local PL = GRM and GRM.Plates
    if not PL then return end
    local number = self:GetNWString("GRM_Plate", "")
    if number == "" then return end

    local lp = LocalPlayer()
    if IsValid(lp) and lp:GetPos():DistToSqr(self:GetPos()) > 700 * 700 then return end

    local kind   = self:GetNWString("GRM_PlateType", "civil")
    local status = self:GetNWString("GRM_PlateStatus", "active")
    local def    = PL.TypeDef(kind)
    local face   = faceGeometry(self)
    if not face then return end
    local text   = PL.FormatNumber(number, kind)

    local scale = 0.05
    local w, h = face.w / scale, face.h / scale

    local plateCol = Color(def.plate[1], def.plate[2], def.plate[3])
    local bandCol  = Color(def.band[1], def.band[2], def.band[3])
    local textCol  = Color(def.text[1], def.text[2], def.text[3])
    if status ~= "active" then textCol = Color(200, 40, 40) end

    surface.SetFont("GRMPlate_Number")
    local tw = surface.GetTextSize(text)
    local fit = math.min(1, (w * 0.78) / math.max(1, tw))

    --[[ Рисуем ОДНУ сторону — ту, что смотрит на игрока.

         Раньше рисовались обе: задняя просвечивала сквозь тонкую модель, и
         номер выглядел зеркальным. Плюс надпись висела в 0.15 юнита от
         центра модели, то есть фактически ВНУТРИ пропа — её не было видно
         (заказ владельца 21.08). Теперь надпись выносится наружу на
         настраиваемый «вынос» (/номер_вынос). ]]
    local eye = EyePos()
    local nrmWorld = worldDir(self, face.normal)
    local side = nrmWorld:Dot(eye - self:LocalToWorld(face.center)) >= 0 and 1 or -1

    local up  = worldDir(self, face.up)
    local rgt = worldDir(self, face.right * side)
    local pos = self:LocalToWorld(face.center + face.normal * (face.half + (face.offset or 1.5)) * side)
    local ang = rgt:AngleEx(up)

    cam.Start3D2D(pos, ang, scale)
        draw.RoundedBox(0, -w / 2, -h / 2, w, h, plateCol)
        draw.RoundedBox(0, -w / 2, -h / 2, w * 0.13, h, bandCol)
        if status ~= "active" then
            draw.SimpleText(string.upper(PL.Statuses[status] or status), "GRMPlate_Small",
                w * 0.065, h / 2 - 9, Color(200, 40, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()

    cam.Start3D2D(pos, ang, scale * fit)
        draw.SimpleText(text, "GRMPlate_Number", (w * 0.065) / fit, 0, textCol,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

function ENT:DrawTranslucent()
    self:Draw()
end
