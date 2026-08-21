include("shared.lua")

--[[ Рисование номера.
     Размер лицевой стороны берём из габаритов модели, а не из «магических»
     чисел: если знак когда-нибудь заменят на другую модель, надпись всё
     равно ляжет по центру и не вылезет за края. ]]
function ENT:Initialize()
    self:SetMaterial(self.Material)
end

local function faceGeometry(ent)
    if ent.GRMFace then return ent.GRMFace end
    local mins, maxs = ent:OBBMins(), ent:OBBMaxs()
    local size = maxs - mins
    local center = (mins + maxs) * 0.5

    -- Самая тонкая ось — толщина знака, значит остальные две дают лицо.
    local thin = "z"
    if size.x <= size.y and size.x <= size.z then thin = "x"
    elseif size.y <= size.x and size.y <= size.z then thin = "y" end

    local face = { thin = thin, center = center }
    if thin == "z" then
        face.w, face.h = size.x, size.y
        face.offset = Vector(center.x, center.y, maxs.z + 0.15)
        face.rot = { { "up", 0 } }
    elseif thin == "y" then
        face.w, face.h = size.x, size.z
        face.offset = Vector(center.x, maxs.y + 0.15, center.z)
        face.rot = { { "forward", 90 }, { "right", 90 } }
    else
        face.w, face.h = size.y, size.z
        face.offset = Vector(maxs.x + 0.15, center.y, center.z)
        face.rot = { { "up", 90 }, { "right", 90 } }
    end
    ent.GRMFace = face
    return face
end

local function plateAngles(ent, face)
    local ang = ent:GetAngles()
    if face.thin == "z" then
        ang:RotateAroundAxis(ang:Up(), 90)
        ang:RotateAroundAxis(ang:Right(), 0)
    elseif face.thin == "y" then
        ang:RotateAroundAxis(ang:Right(), 90)
        ang:RotateAroundAxis(ang:Up(), 90)
    else
        ang:RotateAroundAxis(ang:Up(), 90)
        ang:RotateAroundAxis(ang:Forward(), 90)
    end
    return ang
end

function ENT:Draw()
    self:DrawModel()

    local PL = GRM and GRM.Plates
    if not PL then return end
    local number = self:GetNWString("GRM_Plate", "")
    if number == "" then return end

    local lp = LocalPlayer()
    if IsValid(lp) and lp:GetPos():DistToSqr(self:GetPos()) > 600 * 600 then return end

    local kind = self:GetNWString("GRM_PlateType", "civil")
    local status = self:GetNWString("GRM_PlateStatus", "active")
    local def = PL.TypeDef(kind)
    local face = faceGeometry(self)
    local text = PL.FormatNumber(number, kind)

    local pos = self:LocalToWorld(face.offset)
    local ang = plateAngles(self, face)

    local scale = 0.06
    local w, h = face.w / scale, face.h / scale

    cam.Start3D2D(pos, ang, scale)
        -- поле знака и цветная полоса слева
        draw.RoundedBox(0, -w / 2, -h / 2, w, h, Color(def.plate[1], def.plate[2], def.plate[3]))
        draw.RoundedBox(0, -w / 2, -h / 2, w * 0.14, h, Color(def.band[1], def.band[2], def.band[3]))

        local textCol = Color(def.text[1], def.text[2], def.text[3])
        if status ~= "active" then textCol = Color(190, 40, 40) end

        -- подгоняем надпись под ширину поля
        surface.SetFont("GRMPlate_Number")
        local tw, th = surface.GetTextSize(text)
        local avail = w * 0.80
        local k = math.min(1, avail / math.max(1, tw))
        local m = Matrix()
        m:Translate(Vector(w * 0.07, 0, 0))
        m:Scale(Vector(k, k, 1))
        cam.PushModelMatrix(m)
            draw.SimpleText(text, "GRMPlate_Number", 0, 0, textCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        cam.PopModelMatrix()

        if status ~= "active" then
            draw.SimpleText(string.upper(PL.Statuses[status] or status), "GRMPlate_Small",
                0, h / 2 - 8, Color(190, 40, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()
end

--- Подсказка при взгляде на незакреплённый знак.
function ENT:DrawTranslucent()
    self:Draw()
end
