--[[--------------------------------------------------------------------
    GRM: транспорт — ЕДИНЫЙ тул гаражей, точек выдачи и дилеров.

    Раньше это были два разных инструмента с разной логикой: «GRM: гаражи»
    (зоны, места стоянки, стойки, ворота) и «Точка выдачи транспорта»
    (дилер и одна точка спавна). Из-за этого точки выдачи жили в двух
    несвязанных местах, и админ каждый раз вспоминал, каким тулом что
    ставится. Теперь один инструмент и один порядок работы:

      1. «Зона гаража» — два ЛКМ по земле: углы зоны. Гараж создан и выбран.
      2. «Место стоянки» — ЛКМ внутри зоны. Мест может быть сколько угодно:
         именно по ним разъезжаются машины при выдаче (личные и служебные).
      3. «Стойка вызова» — ЛКМ: терминал гаража.
      4. «Ворота» — ЛКМ по двери: она открывается вместе с гаражом.
      5. «Дилер» — ЛКМ: поставить дилера; ПКМ по дилеру — его ассортимент.
      6. «Связать дилера» — ПКМ по дилеру: покупки этого дилера приписываются
         к выбранному гаражу и выдаются на его местах.

    ПКМ по земле — выбрать гараж под ногами. R — удалить ближайшее место /
    стойку / дилера (в режиме «Дилер»).
----------------------------------------------------------------------]]

TOOL.Category = "GRM"
TOOL.Name = "#tool.grm_transport.name"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar = {
    mode      = "zone",
    name      = "Городской гараж",
    kind      = "public",
    faction   = "",
    fee       = "0",
    lift      = "10",
    direction = "look",
    slotname  = "",
    dealer    = "Автосалон",
    model     = "models/Humans/Group02/male_07.mdl",
}

local function G() return GRM and GRM.Garage end
local function VD() return GRM and GRM.VehicleDealer end

local function notify(ply, text, good)
    if not IsValid(ply) then return end
    if GRM and GRM.Notify then
        GRM.Notify(ply, text, good and 100 or 255, good and 220 or 150, good and 130 or 100)
    else
        ply:ChatPrint("[GRM] " .. tostring(text))
    end
end

local function isDealer(ent)
    return IsValid(ent) and ent:GetClass() == "sent_vehicle_dealer"
end

if CLIENT then
    language.Add("tool.grm_transport.name", "GRM: транспорт (гаражи и дилеры)")
    language.Add("tool.grm_transport.desc", "Зоны гаражей, места выдачи, стойки, ворота, дилеры")
    language.Add("tool.grm_transport.0", "ЛКМ: поставить • ПКМ: выбрать гараж / дилера • R: удалить")

    function TOOL.BuildCPanel(panel)
        panel:AddControl("Header", { Description =
            "Один инструмент на весь транспорт: гараж, его МЕСТА ВЫДАЧИ, стойка, ворота и дилеры.\n" ..
            "Машины (личные и служебные) появляются по местам стоянки, а не в одной точке." })

        local mode = panel:ComboBox("Что ставим", "grm_transport_mode")
        mode:AddChoice("Зона гаража (2 клика по углам)", "zone")
        mode:AddChoice("Место стоянки / выдачи", "slot")
        mode:AddChoice("Стойка вызова", "terminal")
        mode:AddChoice("Ворота гаража (по двери)", "door")
        mode:AddChoice("Дилер транспорта", "dealer")
        mode:AddChoice("Связать дилера с гаражом", "link")

        panel:TextEntry("Название гаража", "grm_transport_name")
        local kind = panel:ComboBox("Тип гаража", "grm_transport_kind")
        kind:AddChoice("Городской (для всех)", "public")
        kind:AddChoice("Ведомственный", "faction")
        kind:AddChoice("Личный", "private")
        panel:TextEntry("Организация (для ведомственного)", "grm_transport_faction")
        panel:TextEntry("Плата за выезд", "grm_transport_fee")
        panel:TextEntry("Название места", "grm_transport_slotname")

        local dir = panel:ComboBox("Направление машины на месте", "grm_transport_direction")
        dir:AddChoice("По взгляду при установке", "look")
        dir:AddChoice("Север (0°)", "north")
        dir:AddChoice("Восток (90°)", "east")
        dir:AddChoice("Юг (180°)", "south")
        dir:AddChoice("Запад (270°)", "west")
        panel:NumSlider("Высота появления", "grm_transport_lift", 0, 100, 0)

        panel:TextEntry("Название дилера", "grm_transport_dealer")
        panel:TextEntry("Модель дилера", "grm_transport_model")

        panel:Help("ПОРЯДОК: зона → места стоянки (сколько нужно) → стойка → ворота.\n" ..
            "Дилер: поставить, ПКМ — ассортимент, режим «Связать» — приписать покупки к гаражу.\n" ..
            "Служебная техника закупается организацией в /автопарк и выдаётся в её гараже.")
    end
end

local function yawFor(tool, ply)
    local dir = tool:GetClientInfo("direction") or "look"
    if dir == "north" then return 0 end
    if dir == "east" then return 90 end
    if dir == "south" then return 180 end
    if dir == "west" then return 270 end
    return ply:EyeAngles().y
end

local function selectedGarage(ply)
    local g = G()
    if not g then return nil end
    local id = ply.GRMGarageSelected
    local rec = id and g.Get and g.Get(id) or nil
    if rec then return rec end
    return g.FindByPos and g.FindByPos(ply:GetPos()) or nil
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not (IsValid(ply) and ply:IsSuperAdmin()) then return false end
    local g = G()
    if not g then notify(ply, "Модуль гаражей не загружен") return false end

    local mode = self:GetClientInfo("mode") or "zone"

    if mode == "zone" then
        if not self.GRMCorner then
            self.GRMCorner = trace.HitPos
            self:SetStage(1)
            notify(ply, "Первый угол зоны поставлен. Кликните второй.", true)
            return true
        end
        local first, second = self.GRMCorner, trace.HitPos
        self.GRMCorner = nil
        self:SetStage(0)
        local ok, rec = g.Create(ply, first, second, {
            name = self:GetClientInfo("name"),
            kind = self:GetClientInfo("kind"),
            faction = self:GetClientInfo("faction"),
            fee = tonumber(self:GetClientInfo("fee")) or 0,
        })
        if not ok then notify(ply, tostring(rec)) return false end
        ply.GRMGarageSelected = rec.id
        notify(ply, ("Гараж «%s» создан. Разметьте места выдачи."):format(rec.name), true)
        return true
    end

    if mode == "dealer" then
        local vd = VD()
        if not vd then notify(ply, "Модуль дилеров не загружен") return false end
        local ent = ents.Create("sent_vehicle_dealer")
        if not IsValid(ent) then return false end
        ent:SetPos(trace.HitPos + trace.HitNormal)
        ent:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
        ent:SetDealerName(self:GetClientInfo("dealer"))
        local model = self:GetClientInfo("model")
        if util.IsValidModel(model) then ent:SetDealerModel(model) end
        ent:Spawn()
        ent:Activate()
        local ok, id = vd.SaveDealer(ent)
        notify(ply, ok and ("Дилер создан: " .. tostring(id) .. ". Свяжите его с гаражом (режим «Связать»).")
            or "Ошибка сохранения дилера", ok)
        return true
    end

    local rec = selectedGarage(ply)
    if not rec then notify(ply, "Встаньте в зону гаража или выберите его ПКМ.") return false end

    if mode == "slot" then
        local ok, slot = g.AddSlot(rec.id, trace.HitPos, Angle(0, yawFor(self, ply), 0),
            tonumber(self:GetClientInfo("lift")) or 10, self:GetClientInfo("slotname"))
        if not ok then notify(ply, tostring(slot)) return false end
        notify(ply, ("Место «%s» добавлено (всего мест: %d)."):format(slot.name, #(rec.slots or {})), true)
        return true
    end

    if mode == "terminal" then
        local ok, term = g.AddTerminal(rec.id, trace.HitPos + trace.HitNormal * 2,
            Angle(0, ply:EyeAngles().y + 180, 0))
        if not ok then notify(ply, tostring(term)) return false end
        notify(ply, ("Стойка вызова поставлена у гаража «%s»."):format(rec.name), true)
        return true
    end

    if mode == "door" then
        local door = trace.Entity
        if not (IsValid(door) and GRM.Doors and GRM.Doors.IsDoor and GRM.Doors.IsDoor(door)) then
            notify(ply, "Наведитесь на дверь или ворота.")
            return false
        end
        local doorID = GRM.Doors.GetDoorID and GRM.Doors.GetDoorID(door) or ""
        local ok, msg = g.LinkDoor(rec.id, doorID)
        notify(ply, tostring(msg), ok)
        return ok == true
    end

    if mode == "link" then
        local ent = trace.Entity
        if not isDealer(ent) then notify(ply, "Наведитесь на дилера транспорта.") return false end
        local ok, msg = g.LinkDealer(rec.id, ent:GetDealerID())
        notify(ply, tostring(msg), ok)
        return ok == true
    end

    return false
end

function TOOL:RightClick(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not (IsValid(ply) and ply:IsSuperAdmin()) then return false end
    local g = G()
    if not g then return false end

    -- ПКМ по дилеру: ассортимент (как в старом туле) либо привязка к гаражу
    if isDealer(trace.Entity) then
        local mode = self:GetClientInfo("mode") or "zone"
        if mode == "link" then
            local rec = selectedGarage(ply)
            if not rec then notify(ply, "Сначала выберите гараж.") return false end
            local ok, msg = g.LinkDealer(rec.id, trace.Entity:GetDealerID())
            notify(ply, tostring(msg), ok)
            return ok == true
        end
        local vd = VD()
        if not vd then return false end
        net.Start("GRM_VD_AdminOpen")
            net.WriteEntity(trace.Entity)
            net.WriteTable({
                name = trace.Entity:GetDealerName(), model = trace.Entity:GetDealerModel(),
                vehicles = trace.Entity.VD_Vehicles or {},
                hasSpawn = trace.Entity:GetHasCustomSpawn(), hasSpawnZone = trace.Entity:GetHasSpawnZone(),
                delivery = vd.DeliveryMode(trace.Entity), showRetrieve = vd.ShowRetrieve(trace.Entity),
                spawnPos = trace.Entity:GetSpawnPos(), spawnAng = trace.Entity:GetSpawnAngle(),
                available = vd.AllVehicleClasses(),
                factions = vd.FactionList(),
                categories = vd.CategoryList(trace.Entity.VD_Vehicles or {}),
            })
        net.Send(ply)
        return true
    end

    -- ПКМ по земле: выбрать гараж под ногами
    local rec = g.FindByPos and g.FindByPos(trace.HitPos) or nil
    if not rec then notify(ply, "Здесь нет зоны гаража.") return false end
    ply.GRMGarageSelected = rec.id
    notify(ply, ("Выбран гараж «%s» (мест: %d)."):format(rec.name, #(rec.slots or {})), true)
    return true
end

function TOOL:Reload(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not (IsValid(ply) and ply:IsSuperAdmin()) then return false end
    local g = G()
    if not g then return false end

    local mode = self:GetClientInfo("mode") or "zone"

    if mode == "dealer" then
        local ent = trace.Entity
        if not isDealer(ent) then notify(ply, "Наведитесь на дилера.") return false end
        local vd = VD()
        if vd and vd.DeleteDealer then
            ent.VD_PermanentDelete = true
            vd.DeleteDealer(ent)
        end
        ent:Remove()
        notify(ply, "Дилер удалён из карты и базы.", true)
        return true
    end

    if mode == "slot" then
        local ok, msg = g.RemoveNearestSlot(trace.HitPos, 200)
        notify(ply, tostring(msg or (ok and "Место удалено" or "Рядом нет места")), ok)
        return ok == true
    end

    if mode == "terminal" then
        local ok, msg = g.RemoveNearestTerminal(trace.HitPos, 200)
        notify(ply, tostring(msg or (ok and "Стойка удалена" or "Рядом нет стойки")), ok)
        return ok == true
    end

    if mode == "zone" and ply:KeyDown(IN_SPEED) then
        local rec = g.FindByPos(trace.HitPos)
        if not rec then notify(ply, "Здесь нет гаража.") return false end
        local ok, msg = g.Remove(rec.id, ply)
        notify(ply, tostring(msg or (ok and "Гараж удалён" or "Не удалось")), ok)
        return ok == true
    end

    notify(ply, "R удаляет: место (режим «Место»), стойку (режим «Стойка»), дилера (режим «Дилер»), Shift+R — гараж.")
    return false
end
