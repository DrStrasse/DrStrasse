-- GRM Vehicle Dealer + unified delivery pad tool v3.1
TOOL.Category = "GRM"
TOOL.Name = "#tool.vehicle_dealer_tool.name"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar = {
    model = "models/Humans/Group01/Male_02.mdl",
    name = "Дилер транспорта",
}

local function isDealer(ent)
    return IsValid(ent) and ent:GetClass() == "sent_vehicle_dealer"
end

if CLIENT then
    language.Add("tool.vehicle_dealer_tool.name", "GRM Дилер и площадка выдачи")
    language.Add("tool.vehicle_dealer_tool.desc", "Единая настройка дилера, гаража и безопасной площадки")
    language.Add("tool.vehicle_dealer_tool.0", "ЛКМ: создать • ПКМ по дилеру: настроить • Shift+ЛКМ по дилеру: выбрать площадку • Shift+ЛКМ по земле: 1-й угол • Shift+ПКМ: 2-й угол • Shift+R: очистить площадку")

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
            end
        end
    end)
end

local function resetPadSetup(tool)
    tool.PadDealer = nil
    tool.PadFirstCorner = nil
    tool:SetStage(0)
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
            GRM.Notify(ply, "Выбран дилер «" .. trace.Entity:GetDealerName() .. "». Shift+ЛКМ по земле — первый угол площадки.", 100, 190, 255)
            return true
        end
        if not isDealer(self.PadDealer) then
            GRM.Notify(ply, "Сначала Shift+ЛКМ по нужному дилеру.", 255, 165, 90)
            return false
        end
        self.PadFirstCorner = trace.HitPos
        self:SetStage(2)
        GRM.Notify(ply, "Первый угол задан. Shift+ПКМ по противоположному углу — сохранить площадку.", 100, 220, 130)
        return true
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
        if not isDealer(self.PadDealer) or not self.PadFirstCorner then
            GRM.Notify(ply, "Сначала выберите дилера и первый угол через Shift+ЛКМ.", 255, 165, 90)
            return false
        end
        local dealer = self.PadDealer
        local ok, reason = GRM.VehicleDealer.SetSpawnZone(dealer, self.PadFirstCorner, trace.HitPos)
        if ok then
            dealer:SetSpawnAngle(Angle(0, ply:EyeAngles().y, 0))
            GRM.VehicleDealer.SaveDealer(dealer)
            GRM.Notify(ply, "Площадка выдачи сохранена для «" .. dealer:GetDealerName() .. "».", 100, 220, 130)
        else
            GRM.Notify(ply, tostring(reason or "Не удалось сохранить площадку"), 255, 130, 90)
        end
        resetPadSetup(self)
        return ok == true
    end

    local ent = trace.Entity
    if not isDealer(ent) then return false end
    net.Start("GRM_VD_AdminOpen")
        net.WriteEntity(ent)
        net.WriteTable({
            name = ent:GetDealerName(), model = ent:GetDealerModel(), vehicles = ent.VD_Vehicles or {},
            hasSpawn = ent:GetHasCustomSpawn(), hasSpawnZone = ent:GetHasSpawnZone(),
            spawnPos = ent:GetSpawnPos(), spawnAng = ent:GetSpawnAngle(),
            available = GRM.VehicleDealer.AllVehicleClasses(),
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
        local ok = GRM.VehicleDealer.ClearSpawnZone(ent)
        resetPadSetup(self)
        GRM.Notify(ply, ok and "Площадка очищена. Временно используется место перед дилером." or "Не удалось очистить площадку", ok and 100 or 255, ok and 220 or 120, 100)
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
        panel:AddControl("Header", { Description = "Один инструмент для дилера и площадки выдачи. Отдельных «точки» и «зоны» больше нет." })
        panel:TextEntry("Название", "vehicle_dealer_tool_name")
        panel:TextEntry("Модель NPC", "vehicle_dealer_tool_model")
        panel:Help("ОБЫЧНЫЙ РЕЖИМ\nЛКМ — создать дилера\nПКМ по дилеру — ассортимент и цены\nR по дилеру — удалить")
        panel:Help("ПЛОЩАДКА ВЫДАЧИ (держите Shift)\n1. ЛКМ по дилеру — выбрать\n2. ЛКМ по земле — первый угол\n3. ПКМ по земле — противоположный угол\nShift+R по дилеру — очистить площадку")
        panel:Help("Транспорт ищет свободное безопасное место внутри площадки. Синяя линия показывает направление появления.")
    end
end
