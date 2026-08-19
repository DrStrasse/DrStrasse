--[[--------------------------------------------------------------------
    GRM: гаражи — тул разметки зон, мест стоянки и стоек вызова.

    ПОРЯДОК РАБОТЫ (по шагам, без «магии»):
      1. Режим «Зона гаража»: ЛКМ по земле — первый угол, ЛКМ второй раз —
         второй угол. Гараж создаётся и сразу становится выбранным.
      2. Режим «Место стоянки»: ЛКМ внутри зоны — место с направлением
         (по взгляду/по осям) и высотой.
      3. Режим «Стойка вызова»: ЛКМ — стойка, у которой открывается меню.
      3.1 Режим «Ворота гаража»: ЛКМ по двери — привязать/отвязать её к
         выбранному гаражу (двери открываются его владельцу).
         ПКМ по двери объекта недвижимости — продавать гараж вместе с домом.
      4. ПКМ по земле — выбрать гараж под ногами (для правки).
         ПКМ по дилеру — привязать/отвязать дилера: купленный у него
         транспорт будет приписан к выбранному гаражу.
      5. R — удалить ближайшее место (в режиме мест) / стойку (в режиме
         стоек) / гараж под ногами (в режиме зоны, с Shift).
----------------------------------------------------------------------]]
TOOL.Category = "GRM"
TOOL.Name = "#tool.grm_garage.name"
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
}

local function G() return GRM and GRM.Garage end

if CLIENT then
    language.Add("tool.grm_garage.name", "GRM: гаражи")
    language.Add("tool.grm_garage.desc", "Зоны гаражей, места стоянки, стойки вызова")
    language.Add("tool.grm_garage.0", "ЛКМ: поставить выбранное • ПКМ: выбрать гараж / привязать дилера • R: удалить")

    local zones = {}
    net.Receive("GRM_Garage_ToolData", function() zones = net.ReadTable() or {} end)

    local function toolActive()
        local ply = LocalPlayer()
        local wep = IsValid(ply) and ply:GetActiveWeapon()
        return IsValid(wep) and wep:GetClass() == "gmod_tool"
            and wep.GetMode and wep:GetMode() == "grm_garage", ply, wep
    end

    hook.Add("Think", "GRM_GarageTool_Request", function()
        local active, _, wep = toolActive()
        if active and (wep.GRMGarageNext or 0) < CurTime() then
            wep.GRMGarageNext = CurTime() + 1
            net.Start("GRM_Garage_ToolReq") net.SendToServer()
        end
    end)

    hook.Add("PostDrawTranslucentRenderables", "GRM_GarageTool_Draw", function(depth, sky, sky3d)
        if depth or sky or sky3d then return end
        if not toolActive() then return end
        for _, z in ipairs(zones) do
            local mn, mx = Vector(z.min.x, z.min.y, z.min.z), Vector(z.max.x, z.max.y, z.max.z)
            local center = (mn + mx) * 0.5
            local col = z.selected and Color(245, 195, 65, 240) or Color(70, 170, 255, 200)
            render.DrawWireframeBox(center, angle_zero, mn - center, mx - center, col, true)
            cam.Start3D2D(center + Vector(0, 0, (mx.z - mn.z) * 0.5 + 12), Angle(0, EyeAngles().y - 90, 90), 0.1)
                draw.RoundedBox(6, -220, -26, 440, 52, Color(10, 15, 22, 232))
                draw.SimpleText("ГАРАЖ: " .. tostring(z.name), "DermaLarge", 0, -14, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                draw.SimpleText(("мест %d • стоек %d • ворот %d • %s"):format(z.slots or 0, z.terminals or 0, z.doors or 0, tostring(z.kindName or "")),
                    "DermaDefaultBold", 0, 12, Color(190, 205, 225), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            cam.End3D2D()

            for _, s in ipairs(z.slotList or {}) do
                local p = Vector(s.pos.x, s.pos.y, s.pos.z)
                local a = Angle(0, s.ang and s.ang.y or 0, 0)
                local scol = s.free == false and Color(240, 110, 100, 235) or Color(90, 220, 150, 235)
                render.DrawWireframeBox(p + Vector(0, 0, 20), a, Vector(-52, -100, -18), Vector(52, 100, 22), scol, true)
                render.DrawLine(p + Vector(0, 0, 24), p + a:Forward() * 130 + Vector(0, 0, 24), Color(255, 190, 80, 240), true)
                cam.Start3D2D(p + Vector(0, 0, 58), Angle(0, EyeAngles().y - 90, 90), 0.08)
                    draw.SimpleText(tostring(s.name or "Место"), "DermaDefaultBold", 0, 0, scol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                cam.End3D2D()
            end
            for _, t in ipairs(z.terminalList or {}) do
                local p = Vector(t.pos.x, t.pos.y, t.pos.z)
                render.DrawWireframeBox(p + Vector(0, 0, 30), angle_zero, Vector(-20, -20, -30), Vector(20, 20, 40), Color(255, 215, 120, 235), true)
            end
        end
    end)

    function TOOL.BuildCPanel(panel)
        panel:AddControl("Header", { Description = "Гаражи: зона → места стоянки → стойка вызова. Купленный транспорт приписывается к гаражу." })
        local mode = panel:ComboBox("Что ставим", "grm_garage_mode")
        mode:AddChoice("Зона гаража (2 клика)", "zone")
        mode:AddChoice("Место стоянки", "slot")
        mode:AddChoice("Стойка вызова меню", "terminal")
        mode:AddChoice("Ворота гаража (двери)", "door")
        panel:TextEntry("Название гаража", "grm_garage_name")
        local kind = panel:ComboBox("Тип гаража", "grm_garage_kind")
        kind:AddChoice("Городской — для всех", "public")
        kind:AddChoice("Ведомственный — по организации", "faction")
        kind:AddChoice("Личный — по владельцу", "private")
        panel:TextEntry("Организация (для ведомственного)", "grm_garage_faction")
        panel:NumSlider("Плата за выезд", "grm_garage_fee", 0, 5000, 0)
        panel:NumSlider("Высота выдачи над землёй", "grm_garage_lift", 0, 60, 0)
        local dir = panel:ComboBox("Направление машины на месте", "grm_garage_direction")
        dir:AddChoice("По взгляду при установке", "look")
        dir:AddChoice("Север (0°)", "north")
        dir:AddChoice("Восток (90°)", "east")
        dir:AddChoice("Юг (180°)", "south")
        dir:AddChoice("Запад (270°)", "west")
        panel:TextEntry("Название места (необязательно)", "grm_garage_slotname")
        panel:Help("ЛКМ — поставить выбранное. В режиме «Ворота гаража» ЛКМ по двери привязывает её к выбранному гаражу. ПКМ по земле — выбрать гараж под ногами, ПКМ по дилеру — привязать/отвязать его, ПКМ по двери объекта недвижимости — продавать гараж вместе с домом. R — удалить ближайшее (Shift+R в режиме зоны — удалить гараж).")
        panel:Help("Меню гаража: /garage в зоне или E у стойки. Список гаражей — консоль grm_garages.")
    end
end

if SERVER then
    util.AddNetworkString("GRM_Garage_ToolReq")
    util.AddNetworkString("GRM_Garage_ToolData")

    net.Receive("GRM_Garage_ToolReq", function(_, ply)
        local g = G()
        if not (IsValid(ply) and ply:IsSuperAdmin() and g) then return end
        local selected = ply.GRMGarageSelected
        local out = {}
        for _, rec in pairs(g.Garages or {}) do
            local slotList = {}
            for _, s in ipairs(g.SlotState and g.SlotState(rec) or {}) do
                local src
                for _, raw in ipairs(rec.slots or {}) do if raw.id == s.id then src = raw break end end
                slotList[#slotList + 1] = { name = s.name, free = s.free, pos = s.pos, ang = src and src.ang or { y = 0 } }
            end
            local terminalList = {}
            for _, t in ipairs(rec.terminals or {}) do terminalList[#terminalList + 1] = { pos = t.pos } end
            out[#out + 1] = {
                id = rec.id, name = rec.name, kindName = g.KindName(rec.kind),
                min = rec.zone.min, max = rec.zone.max,
                slots = #(rec.slots or {}), terminals = #(rec.terminals or {}), doors = #(rec.doors or {}),
                selected = selected == rec.id,
                slotList = slotList, terminalList = terminalList,
            }
        end
        net.Start("GRM_Garage_ToolData") net.WriteTable(out) net.Send(ply)
    end)
end

local function notify(ply, msg, ok)
    if GRM and GRM.Notify then GRM.Notify(ply, msg, ok == false and 255 or 110, ok == false and 140 or 220, ok == false and 100 or 140)
    elseif IsValid(ply) then ply:ChatPrint("[Гараж] " .. tostring(msg)) end
end

local function selectedGarage(ply)
    local g = G()
    if not g then return nil end
    local rec = ply.GRMGarageSelected and g.Get(ply.GRMGarageSelected)
    if rec then return rec end
    return g.FindByPos(ply:GetPos())
end

local function yawFor(tool, ply)
    local dir = tool:GetClientInfo("direction") or "look"
    if dir == "north" then return 0 elseif dir == "east" then return 90
    elseif dir == "south" then return 180 elseif dir == "west" then return 270 end
    return ply:EyeAngles().y
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not (IsValid(ply) and ply:IsSuperAdmin()) then return false end
    local g = G()
    if not g then notify(ply, "Модуль гаражей не загружен", false) return false end

    local mode = self:GetClientInfo("mode") or "zone"

    if mode == "zone" then
        if not self.GarageCorner then
            self.GarageCorner = trace.HitPos
            self:SetStage(1)
            notify(ply, "Первый угол зоны поставлен. Кликните второй угол.", true)
            return true
        end
        local first, second = self.GarageCorner, trace.HitPos
        self.GarageCorner = nil
        self:SetStage(0)
        local ok, rec = g.Create(ply, first, second, {
            name = self:GetClientInfo("name"),
            kind = self:GetClientInfo("kind"),
            faction = self:GetClientInfo("faction"),
            fee = tonumber(self:GetClientInfo("fee")) or 0,
        })
        if not ok then notify(ply, tostring(rec), false) return false end
        ply.GRMGarageSelected = rec.id
        notify(ply, ("Гараж «%s» создан. Теперь разметьте места стоянки."):format(rec.name), true)
        return true
    end

    local rec = selectedGarage(ply)
    if not rec then notify(ply, "Сначала встаньте в зону гаража или выберите его ПКМ.", false) return false end

    if mode == "slot" then
        local ok, slot = g.AddSlot(rec.id, trace.HitPos, Angle(0, yawFor(self, ply), 0),
            tonumber(self:GetClientInfo("lift")) or 10, self:GetClientInfo("slotname"))
        if not ok then notify(ply, tostring(slot), false) return false end
        notify(ply, ("Место «%s» добавлено в гараж «%s»."):format(slot.name, rec.name), true)
        return true
    end

    if mode == "door" then
        local door = trace.Entity
        if not (IsValid(door) and GRM.Doors and GRM.Doors.IsDoor and GRM.Doors.IsDoor(door)) then
            notify(ply, "Наведитесь на дверь или ворота.", false) return false
        end
        local doorID = GRM.Doors.GetDoorID and GRM.Doors.GetDoorID(door) or ""
        local ok, msg = g.LinkDoor(rec.id, doorID)
        notify(ply, tostring(msg), ok)
        return ok == true
    end

    if mode == "terminal" then
        local ok, term = g.AddTerminal(rec.id, trace.HitPos + trace.HitNormal * 2, Angle(0, ply:EyeAngles().y + 180, 0))
        if not ok then notify(ply, tostring(term), false) return false end
        notify(ply, ("Стойка вызова поставлена у гаража «%s»."):format(rec.name), true)
        return true
    end

    return false
end

function TOOL:RightClick(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not (IsValid(ply) and ply:IsSuperAdmin()) then return false end
    local g = G()
    if not g then return false end

    -- ПКМ по дилеру — привязать/отвязать его к выбранному гаражу.
    local ent = trace.Entity
    if IsValid(ent) and ent:GetClass() == "sent_vehicle_dealer" then
        local rec = selectedGarage(ply)
        if not rec then notify(ply, "Сначала выберите гараж (ПКМ по земле в его зоне).", false) return false end
        local ok, msg = g.LinkDealer(rec.id, ent.GetDealerID and ent:GetDealerID() or "")
        notify(ply, tostring(msg), ok)
        return ok == true
    end

    -- ПКМ по двери объекта недвижимости — гараж продаётся вместе с домом.
    if IsValid(ent) and GRM.Doors and GRM.Doors.IsDoor and GRM.Doors.IsDoor(ent) then
        local selected = selectedGarage(ply)
        if not selected then notify(ply, "Сначала выберите гараж (ПКМ по земле в его зоне).", false) return false end
        local prop = GRM.Property and GRM.Property.GetByDoor and select(1, GRM.Property.GetByDoor(ent)) or nil
        if not prop then notify(ply, "Эта дверь не входит в объект недвижимости (/property_admin).", false) return false end
        local ok, msg = g.LinkProperty(selected.id, prop.id)
        notify(ply, tostring(msg), ok)
        return ok == true
    end

    local rec = g.FindByPos(trace.HitPos) or g.Nearest(trace.HitPos, 900)
    if not rec then notify(ply, "Рядом нет гаража.", false) return false end
    ply.GRMGarageSelected = rec.id
    notify(ply, ("Выбран гараж «%s» (мест %d, стоек %d)."):format(rec.name, #(rec.slots or {}), #(rec.terminals or {})), true)
    return true
end

function TOOL:Reload(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not (IsValid(ply) and ply:IsSuperAdmin()) then return false end
    local g = G()
    if not g then return false end

    local mode = self:GetClientInfo("mode") or "zone"
    if mode == "slot" then
        local ok, res = g.RemoveNearestSlot(trace.HitPos, 260)
        notify(ply, ok and ("Место «" .. tostring(res.name) .. "» удалено") or tostring(res), ok)
        return ok == true
    end
    if mode == "door" then
        local door = trace.Entity
        if not (IsValid(door) and GRM.Doors and GRM.Doors.IsDoor and GRM.Doors.IsDoor(door)) then
            notify(ply, "Наведитесь на привязанную дверь.", false) return false
        end
        local doorID = GRM.Doors.GetDoorID and GRM.Doors.GetDoorID(door) or ""
        local owner = g.GarageByDoorID(doorID)
        if not owner then notify(ply, "Эта дверь не привязана к гаражу.", false) return false end
        local ok, msg = g.LinkDoor(owner.id, doorID)
        notify(ply, tostring(msg), ok)
        return ok == true
    end

    if mode == "terminal" then
        local ok, res = g.RemoveNearestTerminal(trace.HitPos, 260)
        notify(ply, ok and "Стойка удалена" or tostring(res), ok)
        return ok == true
    end

    if not ply:KeyDown(IN_SPEED) then
        self.GarageCorner = nil
        self:SetStage(0)
        notify(ply, "Разметка зоны сброшена. Shift+R удаляет гараж под прицелом.", true)
        return true
    end

    local rec = g.FindByPos(trace.HitPos) or g.Nearest(trace.HitPos, 600)
    if not rec then notify(ply, "Рядом нет гаража.", false) return false end
    local ok, msg = g.Remove(rec.id, ply)
    if ok and ply.GRMGarageSelected == rec.id then ply.GRMGarageSelected = nil end
    notify(ply, tostring(msg), ok)
    return ok == true
end
