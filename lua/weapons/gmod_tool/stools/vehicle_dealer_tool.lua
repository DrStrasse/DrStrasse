-- GRM Vehicle Dealer + unified delivery pad tool v3.1
TOOL.Category = "GRM"
TOOL.Name = "#tool.vehicle_dealer_tool.name"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar = {
    model = "models/Humans/Group01/Male_02.mdl",
    name = "Дилер транспорта",
    lift = "30",
    direction = "look",
}

local function isDealer(ent)
    return IsValid(ent) and ent:GetClass() == "sent_vehicle_dealer"
end

if CLIENT then
    language.Add("tool.vehicle_dealer_tool.name", "GRM Дилер и площадка выдачи")
    language.Add("tool.vehicle_dealer_tool.desc", "Единая настройка дилера, гаража и безопасной площадки")
    language.Add("tool.vehicle_dealer_tool.0", "ЛКМ: создать дилера | ПКМ по дилеру: настроить | Shift+ЛКМ по дилеру: выбрать | Shift+ЛКМ/ПКМ по земле: поставить ТОЧКУ выдачи | R: удалить | Shift+R: убрать точку")

    local zones = {}
    net.Receive("GRM_VD_ZoneData", function() zones = net.ReadTable() or {} end)

    local function toolActive()
        local ply = LocalPlayer()
        local weapon = IsValid(ply) and ply:GetActiveWeapon()
        return IsValid(weapon) and weapon:GetClass() == "gmod_tool"
            and weapon.GetMode and weapon:GetMode() == "vehicle_dealer_tool", ply, weapon
    end

    hook.Add("Think", "GRM_VDUnified_RequestPads", function()
        local active, _, weapon = toolActive()
        if active and (weapon.GRMVDPadNext or 0) < CurTime() then
            weapon.GRMVDPadNext = CurTime() + 1
            net.Start("GRM_VD_ZoneRequest")
            net.SendToServer()
        end
    end)

    hook.Add("PostDrawTranslucentRenderables", "GRM_VDUnified_DrawPads", function(depth, sky, sky3d)
        if depth or sky or sky3d then return end
        local active = toolActive()
        if not active then return end
        for _, pad in ipairs(zones) do
            if pad.hasZone then
                local mn = Vector(pad.min.x, pad.min.y, pad.min.z)
                local mx = Vector(pad.max.x, pad.max.y, pad.max.z)
                local center = (mn + mx) * 0.5
                render.DrawWireframeBox(center, angle_zero, mn - center, mx - center, Color(65, 205, 125, 235), true)
                local a = pad.ang or {}
                render.DrawLine(center, center + Angle(a.p or 0, a.y or 0, a.r or 0):Forward() * 100, Color(75, 155, 255, 245), true)
                cam.Start3D2D(center + Vector(0, 0, 8), Angle(0, EyeAngles().y - 90, 90), 0.08)
                    draw.RoundedBox(5, -150, -20, 300, 40, Color(12, 17, 25, 230))
                    draw.SimpleText("ПЛОЩАДКА: " .. tostring(pad.name or pad.id), "DermaDefaultBold", 0, 0, Color(120, 235, 165), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                cam.End3D2D()
            elseif pad.hasPoint and pad.spawnPos then
                local p = Vector(pad.spawnPos.x, pad.spawnPos.y, pad.spawnPos.z)
                local pa = Angle(pad.spawnAng and pad.spawnAng.p or 0, pad.spawnAng and pad.spawnAng.y or 0, pad.spawnAng and pad.spawnAng.r or 0)
                render.DrawWireframeBox(p + Vector(0, 0, 10), angle_zero, Vector(-14, -14, 0), Vector(14, 14, 6), Color(255, 185, 70, 235), true)
                render.DrawLine(p + Vector(0, 0, 14), p + pa:Forward() * 110 + Vector(0, 0, 14), Color(255, 160, 50, 245), true)
                cam.Start3D2D(p + Vector(0, 0, 24), Angle(0, EyeAngles().y - 90, 90), 0.08)
                    draw.RoundedBox(5, -160, -18, 320, 36, Color(12, 17, 25, 230))
                    draw.SimpleText("ТОЧКА: " .. tostring(pad.name or pad.id) .. "  •  высота " .. tostring(pad.lift or 30), "DermaDefaultBold", 0, 0, Color(255, 205, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                cam.End3D2D()
            end
        end
    end)
end

local function resetPadSetup(tool)
    tool.PadDealer = nil
    tool.PadFirstCorner = nil
    tool:SetStage(0)
end

-- v3.1.2: постановка ТОЧКИ выдачи (позиция + направление + высота)
local function placeSpawnPoint(tool, ply, hitPos)
    local dealer = tool.PadDealer
    if not isDealer(dealer) then
        GRM.Notify(ply, "Сначала Shift+ЛКМ по нужному дилеру.", 255, 165, 90)
        return false
    end
    local dir = tool:GetClientInfo("direction") or "look"
    local dy = dealer:GetAngles().y
    local angY
    if dir == "look" then angY = ply:EyeAngles().y
    elseif dir == "forward" then angY = dy
    elseif dir == "back" then angY = dy + 180
    elseif dir == "left" then angY = dy - 90
    elseif dir == "right" then angY = dy + 90
    elseif dir == "north" then angY = 0
    elseif dir == "east" then angY = 90
    elseif dir == "south" then angY = 180
    elseif dir == "west" then angY = 270
    else angY = ply:EyeAngles().y end
    local ok, reason = GRM.VehicleDealer.SetSpawnPoint(dealer, hitPos, Angle(0, angY, 0), tonumber(tool:GetClientInfo("lift")) or 30)
    if ok then
        GRM.Notify(ply, "Точка спавна для «" .. dealer:GetDealerName() .. "» сохранена (направление и высота применены).", 100, 220, 130)
    else
        GRM.Notify(ply, tostring(reason or "Не удалось сохранить точку"), 255, 130, 90)
    end
    tool:SetStage(0)
    return ok == true
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not ply:IsSuperAdmin() then return false end

    if ply:KeyDown(IN_SPEED) then
        if isDealer(trace.Entity) then
            self.PadDealer = trace.Entity
            self.PadFirstCorner = nil
            self:SetStage(1)
            GRM.Notify(ply, "Выбран дилер «" .. trace.Entity:GetDealerName() .. "». Shift+ЛКМ по земле — поставить точку спавна.", 100, 190, 255)
            return true
        end
        return placeSpawnPoint(self, ply, trace.HitPos)
    end

    local ent = ents.Create("sent_vehicle_dealer")
    if not IsValid(ent) then return false end
    ent:SetPos(trace.HitPos + trace.HitNormal)
    ent:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
    ent:SetDealerName(self:GetClientInfo("name"))
    local model = self:GetClientInfo("model")
    if util.IsValidModel(model) then ent:SetDealerModel(model) end
    ent:Spawn()
    ent:Activate()
    local ok, id = GRM.VehicleDealer.SaveDealer(ent)
    GRM.Notify(ply, ok and ("Дилер создан: " .. id .. ". Теперь задайте ему площадку через Shift.") or "Ошибка сохранения", ok and 100 or 255, ok and 220 or 100, 120)
    return true
end

function TOOL:RightClick(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not ply:IsSuperAdmin() then return false end

    if ply:KeyDown(IN_SPEED) then
        return placeSpawnPoint(self, ply, trace.HitPos)
    end

    local ent = trace.Entity
    if not isDealer(ent) then return false end
    net.Start("GRM_VD_AdminOpen")
        net.WriteEntity(ent)
        net.WriteTable({
            name = ent:GetDealerName(), model = ent:GetDealerModel(), vehicles = ent.VD_Vehicles or {},
            hasSpawn = ent:GetHasCustomSpawn(), hasSpawnZone = ent:GetHasSpawnZone(),
            -- Режим выдачи покупок (дилер / гараж / на выбор) и кнопка «ВЫДАТЬ».
            delivery = GRM.VehicleDealer.DeliveryMode(ent),
            showRetrieve = GRM.VehicleDealer.ShowRetrieve(ent),
            spawnPos = ent:GetSpawnPos(), spawnAng = ent:GetSpawnAngle(),
            available = GRM.VehicleDealer.AllVehicleClasses(),
            -- v3.3.0: фракции и категории приходят списком — админ выбирает,
            -- а не набирает вручную (опечатка = машина никому не доступна).
            factions = GRM.VehicleDealer.FactionList(),
            categories = GRM.VehicleDealer.CategoryList(ent.VD_Vehicles or {}),
        })
    net.Send(ply)
    return true
end

function TOOL:Reload(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not ply:IsSuperAdmin() then return false end

    if ply:KeyDown(IN_SPEED) then
        local ent = isDealer(trace.Entity) and trace.Entity or self.PadDealer
        if not isDealer(ent) then
            GRM.Notify(ply, "Наведитесь на дилера, площадку которого нужно очистить.", 255, 165, 90)
            return false
        end
        local ok = GRM.VehicleDealer.ClearSpawnPoint(ent)
        resetPadSetup(self)
        GRM.Notify(ply, ok and "Точка выдачи очищена. Временно используется место перед дилером." or "Не удалось очистить точку", ok and 100 or 255, ok and 220 or 120, 100)
        return ok == true
    end

    local ent = trace.Entity
    if not isDealer(ent) then return false end
    ent.VD_PermanentDelete = true
    GRM.VehicleDealer.DeleteDealer(ent)
    ent:Remove()
    resetPadSetup(self)
    GRM.Notify(ply, "Дилер удалён из карты и базы", 255, 160, 90)
    return true
end

if CLIENT then
    function TOOL.BuildCPanel(panel)
        panel:AddControl("Header", { Description = "Точка выдачи транспорта: одна точка + направление появления + высота." })
        panel:TextEntry("Название", "vehicle_dealer_tool_name")
        panel:TextEntry("Модель NPC", "vehicle_dealer_tool_model")
        local dir = panel:ComboBox("Направление появления", "vehicle_dealer_tool_direction")
        dir:AddChoice("По взгляду при установке", "look")
        dir:AddChoice("Вперёд от дилера", "forward")
        dir:AddChoice("Назад от дилера", "back")
        dir:AddChoice("Влево от дилера", "left")
        dir:AddChoice("Вправо от дилера", "right")
        dir:AddChoice("Север (0°)", "north")
        dir:AddChoice("Восток (90°)", "east")
        dir:AddChoice("Юг (180°)", "south")
        dir:AddChoice("Запад (270°)", "west")
        panel:NumSlider("Высота над землёй", "vehicle_dealer_tool_lift", 0, 100, 0)
        panel:Help("ОБЫЧНЫЙ РЕЖИМ\nЛКМ — создать дилера\nПКМ по дилеру — ассортимент и цены\nR по дилеру — удалить")
        panel:Help("ТОЧКА ВЫДАЧИ (держите Shift)\n1. ЛКМ по дилеру — выбрать дилера\n2. ЛКМ (или ПКМ) по земле — поставить точку\nShift+R по дилеру — убрать точку\nНаправление — из списка выше; высота — ползунком")
        panel:Help("Жёлтый маркер — точка выдачи, оранжевая линия — направление появления машины. Машина ставится на землю (плюс высота) и разворачивается по направлению.")
    end
end
