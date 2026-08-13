--[[--------------------------------------------------------------------
    GRM Fire — панель насосной станции (G после /firetruck).
    Баки: вода / пена / порошок. Закачка с гидранта, слив, прямая подача.
----------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Fire = GRM.Fire or {}
local F = GRM.Fire

local NET_OPEN = "GRM_FirePump_Open"
local NET_DATA = "GRM_FirePump_Data"
local NET_ACT  = "GRM_FirePump_Act"

local function tell(ply, msg, r, g, b)
    if IsValid(ply) and GRM.Notify then GRM.Notify(ply, msg, r or 220, g or 180, b or 80)
    elseif IsValid(ply) then ply:ChatPrint("[Насос] " .. tostring(msg)) end
end

local function findPumpFor(ply)
    if not IsValid(ply) then return nil, nil end
    local veh = ply:GetNWEntity("GRM_FireMyTruck")
    if not IsValid(veh) then
        local seat = ply:GetVehicle()
        if IsValid(seat) then
            local p = seat:GetParent()
            if IsValid(p) and p:GetNWBool("GRM_FireTruck", false) then veh = p
            elseif seat:GetNWBool("GRM_FireTruck", false) then veh = seat end
        end
    end
    if IsValid(veh) and F.FindPumpOn then
        local pump = F.FindPumpOn(veh)
        if IsValid(pump) then return pump, veh end
    end
    local tr = ply:GetEyeTrace()
    if IsValid(tr.Entity) then
        if tr.Entity:GetClass() == "grm_fire_pump" then
            return tr.Entity, tr.Entity:GetHostVehicle()
        end
        if F.IsFireTruck and F.IsFireTruck(tr.Entity) and F.FindPumpOn then
            local pump = F.FindPumpOn(tr.Entity)
            if IsValid(pump) then return pump, tr.Entity end
        end
    end
    for _, e in ipairs(ents.FindInSphere(ply:GetPos(), 280)) do
        if IsValid(e) and e:GetClass() == "grm_fire_pump" then
            return e, e.GetHostVehicle and e:GetHostVehicle() or e:GetParent()
        end
    end
    return nil, nil
end

local function pack(pump)
    local hyd = pump.FindLinkedHydrant and pump:FindLinkedHydrant() or nil
    local cab = pump.FindLinkedCabinet and pump:FindLinkedCabinet() or nil
    return {
        water = pump:GetTank() or 0,
        waterMax = pump:GetTankMax() or 4000,
        foam = pump:GetFoam() or 0,
        foamMax = pump:GetFoamMax() or 500,
        powder = pump:GetPowder() or 0,
        powderMax = pump:GetPowderMax() or 250,
        agent = pump:GetAgent() ~= "" and pump:GetAgent() or "water",
        pumpOn = pump:GetPumpOn() == true,
        filling = pump:GetFilling() == true,
        feed = pump:GetHydrantFeed() == true,
        hydrant = IsValid(hyd),
        cabinet = IsValid(cab),
        hoses = pump:GetHosesOut() or 0,
        hosesMax = pump:GetHosesMax() or 4,
        idx = pump:EntIndex(),
    }
end

if SERVER then
    util.AddNetworkString(NET_OPEN)
    util.AddNetworkString(NET_DATA)
    util.AddNetworkString(NET_ACT)

    local function send(ply, pump)
        if not IsValid(ply) or not IsValid(pump) then return end
        net.Start(NET_DATA)
            net.WriteTable(pack(pump))
        net.Send(ply)
    end

    function F.OpenPumpPanel(ply)
        if not IsValid(ply) then return false, "нет игрока" end
        if not (F.CanFightPro and F.CanFightPro(ply)) then
            return false, "нет доступа пожарного"
        end
        local pump = select(1, findPumpFor(ply))
        if not IsValid(pump) then return false, "подойдите к пожарной машине или насосу" end
        if ply:GetPos():DistToSqr(pump:GetPos()) > 360 * 360 then
            return false, "слишком далеко от насоса"
        end
        send(ply, pump)
        return true
    end

    net.Receive(NET_OPEN, function(_, ply)
        local ok, err = F.OpenPumpPanel(ply)
        if not ok then tell(ply, err, 255, 140, 90) end
    end)

    net.Receive(NET_ACT, function(_, ply)
        if not IsValid(ply) then return end
        if not (F.CanFightPro and F.CanFightPro(ply)) then return end
        local act = tostring(net.ReadString() or "")
        local extra = tostring(net.ReadString() or "")
        local pump = select(1, findPumpFor(ply))
        if not IsValid(pump) then tell(ply, "насос не найден", 255, 140, 90) return end
        if ply:GetPos():DistToSqr(pump:GetPos()) > 360 * 360 then return end

        if act == "agent" and (extra == "water" or extra == "foam" or extra == "powder") then
            pump:SetAgent(extra)
            tell(ply, "Ствол: " .. (extra == "foam" and "пена" or extra == "powder" and "порошок" or "вода"), 120, 200, 255)
        elseif act == "pump" then
            pump:SetPumpOn(not pump:GetPumpOn())
            pump:EmitSound(pump:GetPumpOn() and "ambient/machines/floodgate_stop1.wav" or "buttons/lever4.wav", 65, 100)
        elseif act == "feed" then
            pump:SetHydrantFeed(not pump:GetHydrantFeed())
            tell(ply, pump:GetHydrantFeed() and "Прямая подача с гидранта — бак воды не тратится."
                or "Подача из бака — вода списывается при тушении.", 120, 200, 255)
        elseif act == "fill" then
            local ag = pump:GetAgent()
            if ag == "" then ag = "water" end
            if ag == "powder" then
                if not IsValid(pump:FindLinkedCabinet()) then
                    tell(ply, "Порошок: встаньте шкафом огнетушителей.", 255, 160, 80)
                    return
                end
            else
                if not IsValid(pump:FindLinkedHydrant()) then
                    tell(ply, "Нет связи с открытым гидрантом. Откройте колонку рядом или стыкуйте рукав.", 255, 160, 80)
                    return
                end
            end
            pump:SetFilling(not pump:GetFilling())
            tell(ply, pump:GetFilling() and "Закачка включена." or "Закачка остановлена.", 100, 220, 130)
        elseif act == "drain" then
            local ag = extra ~= "" and extra or (pump:GetAgent() ~= "" and pump:GetAgent() or "water")
            if pump.DrainAgent then pump:DrainAgent(ag, 99999) end
            if pump.SyncHost then pump:SyncHost() end
            tell(ply, "Бак слит: " .. ag, 255, 180, 90)
        elseif act == "refresh" then
        end
        if pump.SyncHost then pump:SyncHost() end
        send(ply, pump)
    end)

    concommand.Add("grm_fire_pump_ui", function(ply)
        if not IsValid(ply) then return end
        local ok, err = F.OpenPumpPanel(ply)
        if not ok then tell(ply, err, 255, 140, 90) end
    end)

    print("[GRM Fire] Pump UI server loaded")
end

if CLIENT then
    surface.CreateFont("GRMFireTrk_Title", { font = "Roboto", size = 18, weight = 700, extended = true })
    surface.CreateFont("GRMFireTrk_N", { font = "Roboto", size = 14, weight = 500, extended = true })
    local frame

    local function paintBar(x, y, w, h, frac, col, label, have, maxv)
        draw.RoundedBox(4, x, y, w, h, Color(18, 22, 30, 240))
        local fw = math.floor(w * math.Clamp(frac, 0, 1))
        if fw > 2 then draw.RoundedBox(4, x + 1, y + 1, fw - 2, h - 2, col) end
        draw.SimpleText(string.format("%s  %d / %d", label, have, maxv), "GRMFireTrk_N", x + 8, y + h / 2, Color(235, 238, 242), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local function openUI(st)
        if IsValid(frame) then frame:Remove() end
        local T = GRM.UI and GRM.UI.Theme
        local C = T and T.Colors or {
            bg = Color(8, 14, 23, 248), panel = Color(16, 27, 42, 245),
            text = Color(225, 238, 247), cyan = Color(48, 204, 255),
            green = Color(64, 222, 147), amber = Color(250, 185, 63),
            red = Color(244, 78, 96), header = Color(10, 22, 37, 255),
        }
        frame = vgui.Create("DFrame")
        frame:SetSize(520, 520)
        frame:Center()
        frame:SetTitle("")
        frame:MakePopup()
        if GRM.UI and GRM.UI.Track then GRM.UI.Track("fire_pump", frame) end
        frame.Paint = function(_, w, h)
            draw.RoundedBox(9, 0, 0, w, h, C.bg or Color(8, 14, 23, 248))
            draw.RoundedBoxEx(9, 0, 0, w, 52, C.header or Color(10, 22, 37, 255), true, true, false, false)
            draw.SimpleText("НАСОСНАЯ СТАНЦИЯ", "GRMFireTrk_Title", 16, 18, C.text or color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("вода · пена · порошок", "GRMFireTrk_N", 16, 38, C.cyan or Color(48, 204, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local close = vgui.Create("DButton", frame)
        close:SetPos(480, 12) close:SetSize(28, 28) close:SetText("X")
        close:SetTextColor(C.text or color_white)
        close.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and (C.red or Color(244, 78, 96)) or (C.panel or Color(16, 27, 42)))
        end
        close.DoClick = function() frame:Close() end

        local body = vgui.Create("DPanel", frame)
        body:Dock(FILL) body:DockMargin(14, 58, 14, 12)
        body:SetPaintBackground(false)

        frame._st = st
        body.Paint = function(_, w, h)
            local s = frame._st or st
            paintBar(0, 4, w, 28, s.water / math.max(1, s.waterMax), Color(50, 140, 230), "ВОДА", s.water, s.waterMax)
            paintBar(0, 38, w, 28, s.foam / math.max(1, s.foamMax), Color(230, 80, 70), "ПЕНА", s.foam, s.foamMax)
            paintBar(0, 72, w, 28, s.powder / math.max(1, s.powderMax), Color(200, 190, 80), "ПОРОШОК", s.powder, s.powderMax)
            local link = s.hydrant and "гидрант: СВЯЗАН (открыт)" or "гидрант: нет связи"
            local cab = s.cabinet and "  ·  шкаф рядом" or ""
            draw.SimpleText(link .. cab, "GRMFireTrk_N", 0, 110, s.hydrant and Color(80, 220, 140) or Color(255, 170, 80))
            draw.SimpleText("рукава " .. (s.hoses or 0) .. "/" .. (s.hosesMax or 4) .. "   ствол: " .. tostring(s.agent or "water"), "GRMFireTrk_N", 0, 130, Color(200, 205, 215))
        end

        local function act(a, extra)
            net.Start(NET_ACT)
                net.WriteString(a)
                net.WriteString(extra or "")
            net.SendToServer()
        end

        local function mk(txt, col, fn)
            local b = vgui.Create("DButton", body)
            b:Dock(TOP) b:SetTall(30) b:DockMargin(0, 4, 0, 0)
            b:SetText(txt) b:SetTextColor(color_white)
            b.Paint = function(self, w, h)
                local c = col
                if self:IsHovered() then c = Color(math.min(255, c.r + 25), math.min(255, c.g + 25), math.min(255, c.b + 25)) end
                draw.RoundedBox(5, 0, 0, w, h, c)
            end
            b.DoClick = fn
            return b
        end

        local spacer = vgui.Create("DPanel", body)
        spacer:Dock(TOP) spacer:SetTall(148) spacer:SetPaintBackground(false)

        mk("Ствол: ВОДА", Color(40, 110, 190), function() act("agent", "water") end)
        mk("Ствол: ПЕНА", Color(170, 50, 50), function() act("agent", "foam") end)
        mk("Ствол: ПОРОШОК", Color(150, 140, 40), function() act("agent", "powder") end)
        mk(st.pumpOn and "Насос: ВЫКЛЮЧИТЬ" or "Насос: ВКЛЮЧИТЬ", st.pumpOn and Color(70, 160, 90) or Color(70, 90, 110), function() act("pump") end)
        mk(st.filling and "Закачка: СТОП" or "Закачка С гидранта / шкафа", Color(50, 130, 160), function() act("fill") end)
        mk(st.feed and "Прямая подача с гидранта: ВКЛ" or "Прямая подача с гидранта: выкл", Color(90, 70, 40), function() act("feed") end)
        mk("Слить выбранный бак", Color(140, 50, 50), function() act("drain", st.agent) end)

        frame.Think = function()
            if (frame._next or 0) > CurTime() then return end
            frame._next = CurTime() + 0.45
            if not IsValid(frame) then return end
            net.Start(NET_ACT) net.WriteString("refresh") net.WriteString("") net.SendToServer()
        end
    end

    net.Receive(NET_DATA, function()
        local st = net.ReadTable() or {}
        if IsValid(frame) then
            -- rebuild to refresh numbers
            openUI(st)
        else
            openUI(st)
        end
    end)

    hook.Add("PlayerButtonDown", "GRM_FirePump_GKey", function(ply, button)
        if button ~= KEY_G then return end
        if ply ~= LocalPlayer() then return end
        local tr = ply:GetEyeTrace()
        local hit = IsValid(tr.Entity) and tr.Entity or nil
        if IsValid(hit) then
            local cls = hit:GetClass() or ""
            if cls == "grm_bank_terminal" or cls == "grm_bank_vault" then return end
        end
        local duty = ply:GetNWEntity("GRM_FireMyTruck")
        local nearPump = false
        if IsValid(hit) and (hit:GetClass() == "grm_fire_pump" or hit:GetNWBool("GRM_FireTruck", false)) then
            nearPump = true
        end
        if not nearPump then
            for _, e in ipairs(ents.FindInSphere(ply:GetPos(), 260)) do
                if IsValid(e) and e:GetClass() == "grm_fire_pump" then nearPump = true break end
            end
        end
        if not nearPump and not IsValid(duty) then return end
        RunConsoleCommand("grm_fire_pump_ui")
    end)

    print("[GRM Fire] Pump UI client loaded")
end
