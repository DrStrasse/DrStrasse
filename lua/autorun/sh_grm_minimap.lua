-- GRM Minimap / districts / capture points v0.1
if SERVER then AddCSLuaFile() end
GRM = GRM or {}
GRM.Minimap = GRM.Minimap or {}
local MM = GRM.Minimap
MM.File = "grm_minimap_" .. string.lower(game.GetMap() or "unknown") .. ".json"

if SERVER then
    util.AddNetworkString("GRM_Minimap_Data")
    util.AddNetworkString("GRM_Minimap_Open")
    util.AddNetworkString("GRM_Minimap_Action")
    util.AddNetworkString("GRM_Minimap_CaptureEvent")
    MM.Data = MM.Data or { districts = {}, points = {} }

    local function save() file.Write(MM.File, util.TableToJSON(MM.Data, true)) end
    local function load()
        if file.Exists(MM.File, "DATA") then
            local ok, d = pcall(util.JSONToTable, file.Read(MM.File, "DATA") or "")
            if ok and istable(d) then MM.Data = d end
        end
        MM.Data.districts = istable(MM.Data.districts) and MM.Data.districts or {}
        MM.Data.points = istable(MM.Data.points) and MM.Data.points or {}
    end
    local function pos(t) return { x = t.x, y = t.y, z = t.z } end
    local function send(ply)
        net.Start("GRM_Minimap_Data") net.WriteTable(MM.Data) if IsValid(ply) then net.Send(ply) else net.Broadcast() end
    end
    local function nextID(prefix) return prefix .. "_" .. os.time() .. "_" .. math.random(100, 999) end
    load()

    local function factionOf(ply)
        if not IsValid(ply) then return "" end
        for name, faction in pairs(Factions or {}) do
            if GRM.Identity and GRM.Identity.FactionMember and GRM.Identity.FactionMember(faction, ply) then return tostring(name) end
        end
        return ""
    end

    timer.Create("GRM_Minimap_CaptureTick", 1, 0, function()
        local changed = false
        for _, point in ipairs(MM.Data.points or {}) do
            point.radius = tonumber(point.radius) or 180
            local groups, count = {}, 0
            local center = Vector(point.pos.x, point.pos.y, point.pos.z)
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and ply:Alive() and ply:GetPos():DistToSqr(center) <= point.radius * point.radius then
                    local fac = factionOf(ply)
                    if fac ~= "" then groups[fac] = (groups[fac] or 0) + 1; count = count + 1 end
                end
            end
            local only, groupCount = nil, 0
            for fac in pairs(groups) do only = fac; groupCount = groupCount + 1 end
            if count > 0 and groupCount == 1 then
                point.capture = math.min(30, (tonumber(point.capture) or 0) + 1)
                point.capturing = only
                if point.capture >= 30 and point.owner ~= only then
                    point.owner = only
                    changed = true
                    net.Start("GRM_Minimap_CaptureEvent")
                        net.WriteString(tostring(point.name or "Точка"))
                        net.WriteString(tostring(only))
                    net.Broadcast()
                end
            elseif groupCount > 1 then
                point.capture = math.max(0, (tonumber(point.capture) or 0) - 2)
                point.capturing = "Оспаривается"
            else
                point.capturing = ""
            end
        end
        if changed then save() end
        send()
    end)

    net.Receive("GRM_Minimap_Open", function(_, ply)
        if IsValid(ply) and ply:IsSuperAdmin() then send(ply) net.Start("GRM_Minimap_Open") net.Send(ply) end
    end)
    net.Receive("GRM_Minimap_Action", function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        local action = net.ReadString()
        if action == "add_district" then
            local name = string.sub(string.Trim(net.ReadString() or "Район"), 1, 48)
            local radius = math.Clamp(net.ReadUInt(16), 100, 10000)
            MM.Data.districts[#MM.Data.districts + 1] = { id = nextID("district"), name = name ~= "" and name or "Район", center = pos(ply:GetPos()), radius = radius, color = { r = 70, g = 150, b = 240 } }
            save(); send()
        elseif action == "add_point" then
            local name = string.sub(string.Trim(net.ReadString() or "Точка захвата"), 1, 48)
            local radius = math.Clamp(net.ReadUInt(16), 100, 2000)
            MM.Data.points[#MM.Data.points + 1] = { id = nextID("point"), name = name ~= "" and name or "Точка захвата", pos = pos(ply:GetPos()), radius = radius, capture = 0, capturing = "", owner = "" }
            save(); send()
        elseif action == "delete_district" or action == "delete_point" then
            local id = net.ReadString()
            local list = action == "delete_district" and MM.Data.districts or MM.Data.points
            for i = #list, 1, -1 do if tostring(list[i].id) == id then table.remove(list, i) end end
            save(); send()
        elseif action == "save" then save(); send(ply)
        elseif action == "load" then load(); send()
        end
    end)
    concommand.Add("grm_minimap_admin", function(ply) if IsValid(ply) and ply:IsSuperAdmin() then send(ply) net.Start("GRM_Minimap_Open") net.Send(ply) end end)
    hook.Add("PlayerSay", "GRM_Minimap_AdminChat", function(ply, text)
        if IsValid(ply) and ply:IsSuperAdmin() and string.lower(string.Trim(text or "")) == "/grm_minimap_admin" then
            send(ply)
            net.Start("GRM_Minimap_Open") net.Send(ply)
            return ""
        end
    end)
else
    local data = { districts = {}, points = {} }
    local frame
    local function worldBounds()
        local w = game.GetWorld()
        if not IsValid(w) then return Vector(-4096, -4096, -4096), Vector(4096, 4096, 4096) end
        local a, b = w:GetModelBounds()
        return Vector(a.x, a.y, a.z), Vector(b.x, b.y, b.z)
    end
    local function mapPos(v, x, y, size)
        local mn, mx = worldBounds()
        local px = math.Clamp((v.x - mn.x) / math.max(1, mx.x - mn.x), 0, 1)
        local py = math.Clamp(1 - (v.y - mn.y) / math.max(1, mx.y - mn.y), 0, 1)
        return x + px * size, y + py * size
    end
    local function send(action, extra)
        net.Start("GRM_Minimap_Action") net.WriteString(action) if extra then extra() end net.SendToServer()
    end
    local mapRT = GetRenderTarget("GRM_GRM_Minimap_" .. string.lower(game.GetMap() or "map"), 512, 512, false)
    local mapMat = CreateMaterial("GRM_GRM_Minimap_Mat_" .. string.lower(game.GetMap() or "map"), "UnlitGeneric", {
        ["$basetexture"] = mapRT:GetName(), ["$vertexalpha"] = 1, ["$vertexcolor"] = 1,
    })
    local nextMapRender = 0
    local function renderMapSnapshot()
        if CurTime() < nextMapRender then return end
        nextMapRender = CurTime() + 0.6
        local mn, mx = worldBounds()
        local span = math.max(mx.x - mn.x, mx.y - mn.y)
        local center = Vector((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mx.z + math.max(1200, span * 0.75))
        render.PushRenderTarget(mapRT)
        render.Clear(7, 12, 19, 255, true, true)
        render.RenderView({ origin = center, angles = Angle(90, 0, 0), x = 0, y = 0, w = 512, h = 512, fov = 90, drawhud = false, drawviewmodel = false, dopostprocess = false })
        render.PopRenderTarget()
    end
    net.Receive("GRM_Minimap_Data", function() data = net.ReadTable() or data end)
    net.Receive("GRM_Minimap_CaptureEvent", function()
        local pointName, faction = net.ReadString(), net.ReadString()
        notification.AddLegacy("Точка «" .. pointName .. "» захвачена фракцией: " .. faction, NOTIFY_GENERIC, 6)
        surface.PlaySound("buttons/button14.wav")
    end)
    net.Receive("GRM_Minimap_Open", function()
        if IsValid(frame) then frame:Remove() end
        frame = vgui.Create("DFrame") frame:SetSize(760, 620) frame:Center() frame:MakePopup() frame:SetTitle("GRM — Районы и мини-карта")
        local name = vgui.Create("DTextEntry", frame) name:SetPos(18, 42) name:SetSize(300, 28) name:SetPlaceholderText("Название района/точки")
        local radius = vgui.Create("DNumberWang", frame) radius:SetPos(328, 42) radius:SetSize(110, 28) radius:SetMin(100) radius:SetMax(10000) radius:SetValue(500)
        local addD = vgui.Create("DButton", frame) addD:SetPos(448, 42) addD:SetSize(140, 28) addD:SetText("+ Район здесь") addD.DoClick = function() send("add_district", function() net.WriteString(name:GetValue()); net.WriteUInt(radius:GetValue(), 16) end) end
        local addP = vgui.Create("DButton", frame) addP:SetPos(594, 42) addP:SetSize(140, 28) addP:SetText("+ Точка здесь") addP.DoClick = function() send("add_point", function() net.WriteString(name:GetValue()); net.WriteUInt(radius:GetValue(), 16) end) end
        local sc = vgui.Create("DScrollPanel", frame) sc:SetPos(18, 82) sc:SetSize(716, 500)
        local function rebuild()
            sc:Clear()
            local title = vgui.Create("DLabel", sc) title:Dock(TOP) title:SetTall(30) title:SetText("РАЙОНЫ")
            for _, d in ipairs(data.districts or {}) do
                local row = vgui.Create("DPanel", sc) row:Dock(TOP) row:SetTall(34) row:DockMargin(0, 0, 0, 4)
                local l = vgui.Create("DLabel", row) l:Dock(FILL) l:SetText("" .. tostring(d.name) .. "  |  радиус " .. tostring(d.radius) .. "  |  " .. tostring(d.id))
                local b = vgui.Create("DButton", row) b:Dock(RIGHT) b:SetWide(100) b:SetText("Удалить") b.DoClick = function() send("delete_district", function() net.WriteString(d.id) end) end
            end
            local pt = vgui.Create("DLabel", sc) pt:Dock(TOP) pt:SetTall(34) pt:SetText("ТОЧКИ ЗАХВАТА")
            for _, p in ipairs(data.points or {}) do
                local row = vgui.Create("DPanel", sc) row:Dock(TOP) row:SetTall(34) row:DockMargin(0, 0, 0, 4)
                local l = vgui.Create("DLabel", row) l:Dock(FILL) l:SetText(tostring(p.name) .. "  |  радиус: " .. tostring(p.radius or 180) .. "  |  владелец: " .. (p.owner ~= "" and p.owner or "свободна") .. "  |  захват: " .. (p.capturing ~= "" and tostring(p.capturing) or "нет") .. "  |  " .. tostring(p.id))
                local b = vgui.Create("DButton", row) b:Dock(RIGHT) b:SetWide(100) b:SetText("Удалить") b.DoClick = function() send("delete_point", function() net.WriteString(p.id) end) end
            end
        end
        timer.Simple(0, rebuild)
        net.Receive("GRM_Minimap_Data", function() data = net.ReadTable() or data; rebuild() end)
    end)
    local gpsTarget
    local function openGPS()
        if IsValid(frame) then frame:Close() end
        frame = vgui.Create("DFrame") frame:SetSize(520, 500) frame:Center() frame:MakePopup() frame:SetTitle("GRM — GPS и точки")
        local list = vgui.Create("DScrollPanel", frame) list:SetPos(12, 36) list:SetSize(496, 440)
        for _, p in ipairs(data.points or {}) do
            local b = vgui.Create("DButton", list) b:Dock(TOP) b:SetTall(36) b:DockMargin(0, 0, 0, 5)
            b:SetText(tostring(p.name) .. "  •  " .. (p.owner ~= "" and "контроль: " .. p.owner or "свободна"))
            b.DoClick = function() gpsTarget = p.id; frame:Close() end
        end
        local clear = vgui.Create("DButton", frame) clear:SetPos(12, 470) clear:SetSize(496, 24) clear:SetText("Сбросить GPS") clear.DoClick = function() gpsTarget = nil frame:Close() end
    end
    concommand.Add("grm_minimap_admin", function() if IsValid(LocalPlayer()) and LocalPlayer():IsSuperAdmin() then net.Start("GRM_Minimap_Open") net.SendToServer() end end)
    concommand.Add("grm_gps", openGPS)
    hook.Add("PlayerSayTransform", "GRM_Minimap_GPSCommand", function(ply, pack)
        if ply ~= LocalPlayer() then return end
        local text = string.lower(string.Trim(pack and pack[1] or ""))
        if text == "/gps" then openGPS() pack[1] = "" return true end
    end)
    hook.Add("HUDPaint", "GRM_Minimap_HUD", function()
        local lp = LocalPlayer() if not IsValid(lp) then return end
        renderMapSnapshot()
        local size, x, y = 220, ScrW() - 238, 18
        draw.RoundedBox(8, x - 4, y - 4, size + 8, size + 8, Color(10, 16, 24, 235))
        surface.SetMaterial(mapMat) surface.SetDrawColor(255, 255, 255, 185) surface.DrawTexturedRect(x, y, size, size)
        surface.SetDrawColor(45, 65, 86, 255) surface.DrawOutlinedRect(x, y, size, size, 2)
        for i = 1, 7 do surface.SetDrawColor(30, 48, 66, 180) surface.DrawLine(x + i * size / 8, y, x + i * size / 8, y + size) surface.DrawLine(x, y + i * size / 8, x + size, y + i * size / 8) end
        for _, d in ipairs(data.districts or {}) do
            local dx, dy = mapPos(Vector(d.center.x, d.center.y, 0), x, y, size)
            draw.SimpleText(tostring(d.name), "DermaDefaultBold", dx, dy, Color(100, 180, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        for _, p in ipairs(data.points or {}) do
            local px, py = mapPos(Vector(p.pos.x, p.pos.y, 0), x, y, size)
            local col = p.owner ~= "" and Color(100, 220, 140, 255) or Color(240, 180, 70, 255)
            surface.SetDrawColor(col) surface.DrawRect(px - 3, py - 3, 6, 6)
            draw.SimpleText(tostring(p.name), "DermaDefault", px, py - 8, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
        end
        local px, py = mapPos(lp:GetPos(), x, y, size)
        surface.SetDrawColor(90, 255, 150, 255) surface.DrawRect(px - 4, py - 4, 8, 8)
        if gpsTarget then
            for _, p in ipairs(data.points or {}) do
                if p.id == gpsTarget then
                    local tx, ty = mapPos(Vector(p.pos.x, p.pos.y, 0), x, y, size)
                    surface.SetDrawColor(255, 220, 90, 220) surface.DrawLine(px, py, tx, ty)
                    draw.SimpleText("GPS " .. math.floor(lp:GetPos():Distance(Vector(p.pos.x, p.pos.y, p.pos.z or lp:GetPos().z))), "DermaDefaultBold", x + size / 2, y + size + 25, Color(255, 220, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    break
                end
            end
        end
        if gpsTarget then
            for _, p in ipairs(data.points or {}) do
                if p.id == gpsTarget then
                    local screen = Vector(p.pos.x, p.pos.y, p.pos.z or lp:GetPos().z):ToScreen()
                    local angle = math.deg(math.atan2(screen.y - ScrH() / 2, screen.x - ScrW() / 2))
                    draw.SimpleText("GPS: " .. tostring(p.name) .. "  •  " .. math.floor(lp:GetPos():Distance(Vector(p.pos.x, p.pos.y, p.pos.z or lp:GetPos().z))) .. " юн.", "DermaDefaultBold", ScrW() / 2, ScrH() - 70, Color(255, 220, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("↗", "DermaLarge", ScrW() / 2, ScrH() - 105, Color(255, 220, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    break
                end
            end
        end
        local current = "Вне района"
        for _, d in ipairs(data.districts or {}) do if lp:GetPos():DistToSqr(Vector(d.center.x, d.center.y, d.center.z or 0)) <= (tonumber(d.radius) or 0)^2 then current = d.name end end
        draw.SimpleText(current, "DermaDefaultBold", x + size / 2, y + size + 10, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end)
end
