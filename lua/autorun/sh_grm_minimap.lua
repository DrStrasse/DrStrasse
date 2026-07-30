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
    function MM.AddPoint(ply, name, pointPos, radius)
        MM.Data.points[#MM.Data.points + 1] = { id = nextID("point"), name = string.sub(string.Trim(name or "Точка захвата"), 1, 48), pos = { x = pointPos.x, y = pointPos.y, z = pointPos.z }, radius = math.Clamp(tonumber(radius) or 180, 100, 2000), capture = 0, capturing = "", owner = "", allowedFactions = {} }
        save(); send(); return true
    end
    function MM.AddDistrict(ply, name, center, radius)
        MM.Data.districts[#MM.Data.districts + 1] = { id = nextID("district"), name = string.sub(string.Trim(name or "Район"), 1, 48), center = { x = center.x, y = center.y, z = center.z }, radius = math.Clamp(tonumber(radius) or 500, 100, 10000), color = { r = 70, g = 150, b = 240 }, polygon = {}, owner = "" }
        save(); send(); return true
    end
    function MM.AddDistrictVertex(id, point)
        for _, district in ipairs(MM.Data.districts or {}) do
            if tostring(district.id) == tostring(id) then
                district.polygon = istable(district.polygon) and district.polygon or {}
                district.polygon[#district.polygon + 1] = { x = point.x, y = point.y, z = point.z }
                save(); send(); return true
            end
        end
        return false
    end
    function MM.CloseNearestDistrict(point)
        local nearest, dist
        for _, district in ipairs(MM.Data.districts or {}) do
            local center = district.center or {}
            local d = Vector(center.x or 0, center.y or 0, point.z or 0):DistToSqr(point)
            if not dist or d < dist then nearest, dist = district, d end
        end
        if nearest then nearest.polygonClosed = true; save(); send(); return true end
        return false
    end
    load()

    local function factionOf(ply)
        if not IsValid(ply) then return "" end
        for name, faction in pairs(Factions or {}) do
            if GRM.Identity and GRM.Identity.FactionMember and GRM.Identity.FactionMember(faction, ply) then return tostring(name) end
        end
        return ""
    end

    local function insideDistrict(point, district)
        local poly = district.polygon
        if istable(poly) and #poly >= 3 and district.polygonClosed then
            local inside = false
            for i = 1, #poly do
                local a, b = poly[i], poly[i % #poly + 1]
                if ((a.y > point.y) ~= (b.y > point.y)) and point.x < (b.x - a.x) * (point.y - a.y) / math.max(0.0001, b.y - a.y) + a.x then inside = not inside end
            end
            return inside
        end
        local c = district.center or {}
        return Vector(c.x or 0, c.y or 0, point.z or 0):DistToSqr(point) <= (tonumber(district.radius) or 500)^2
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
                    local allowed = point.allowedFactions or {}
                    local restricted = false
                    for _, enabled in pairs(allowed) do if enabled == true then restricted = true break end end
                    if fac ~= "" and (not restricted or allowed[fac] == true) then groups[fac] = (groups[fac] or 0) + 1; count = count + 1 end
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
        for _, district in ipairs(MM.Data.districts or {}) do
            local scores = {}
            for _, point in ipairs(MM.Data.points or {}) do
                local p = Vector(point.pos.x, point.pos.y, point.pos.z)
                if insideDistrict(p, district) and tostring(point.owner or "") ~= "" then scores[point.owner] = (scores[point.owner] or 0) + 1 end
            end
            local winner, best = "", 0
            for faction, score in pairs(scores) do if score > best then winner, best = faction, score elseif score == best then winner = "" end end
            if district.owner ~= winner then district.owner = winner; changed = true end
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
            MM.Data.points[#MM.Data.points + 1] = { id = nextID("point"), name = name ~= "" and name or "Точка захвата", pos = pos(ply:GetPos()), radius = radius, capture = 0, capturing = "", owner = "", allowedFactions = {} }
            save(); send()
        elseif action == "set_point_access" then
            local id, incoming = net.ReadString(), net.ReadTable() or {}
            for _, point in ipairs(MM.Data.points or {}) do
                if tostring(point.id) == id then
                    point.allowedFactions = {}
                    for name, enabled in pairs(incoming) do if isstring(name) and enabled == true then point.allowedFactions[name] = true end end
                end
            end
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
    local MUI = { bg = Color(10, 15, 23, 253), head = Color(19, 28, 41), card = Color(24, 35, 51), card2 = Color(29, 43, 61), line = Color(55, 75, 99), text = Color(235, 242, 250), dim = Color(150, 169, 190), blue = Color(67, 145, 240), green = Color(65, 195, 125), red = Color(215, 75, 84), orange = Color(235, 164, 70) }
    surface.CreateFont("GRMMM_Title", { font = "Roboto", size = 21, weight = 900, extended = true })
    surface.CreateFont("GRMMM_Body", { font = "Roboto", size = 13, weight = 600, extended = true })
    surface.CreateFont("GRMMM_Small", { font = "Roboto", size = 11, weight = 500, extended = true })
    local function styleButton(b, color)
        b:SetFont("GRMMM_Body") b:SetTextColor(MUI.text)
        b.Paint = function(self, w, h) local c = color or MUI.card2; if self:IsHovered() then c = Color(math.min(c.r + 18, 255), math.min(c.g + 18, 255), math.min(c.b + 18, 255)) end draw.RoundedBox(6, 0, 0, w, h, c) end
        return b
    end
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
    local mapSnapshotReady = false
    local function renderMapSnapshot()
        if mapSnapshotReady and CurTime() < nextMapRender then return end
        nextMapRender = CurTime() + 5
        mapSnapshotReady = true
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
        frame = vgui.Create("DFrame") frame:SetSize(980, 720) frame:Center() frame:MakePopup() frame:SetTitle("") frame:ShowCloseButton(false) frame:SetDeleteOnClose(true)
        frame.Paint = function(_, w, h) draw.RoundedBox(10, 0, 0, w, h, MUI.bg); draw.RoundedBoxEx(10, 0, 0, w, 64, MUI.head, true, true, false, false); draw.SimpleText("GRM  /  КАРТА И ТЕРРИТОРИИ", "GRMMM_Small", 22, 18, MUI.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER); draw.SimpleText("Районы, точки захвата и навигация", "GRMMM_Title", 22, 43, MUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER) end
        local close = styleButton(vgui.Create("DButton", frame), MUI.red) close:SetPos(936, 16) close:SetSize(30, 30) close:SetText("×") close.DoClick = function() frame:Close() end
        local name = vgui.Create("DTextEntry", frame) name:SetPos(22, 82) name:SetSize(370, 34) name:SetFont("GRMMM_Body") name:SetPlaceholderText("Название района или точки") name.Paint = function(self, w, h) draw.RoundedBox(6, 0, 0, w, h, MUI.card2); self:DrawTextEntryText(MUI.text, MUI.blue, MUI.text) end
        local radius = vgui.Create("DNumberWang", frame) radius:SetPos(402, 82) radius:SetSize(120, 34) radius:SetMin(100) radius:SetMax(10000) radius:SetValue(500) radius:SetFont("GRMMM_Body")
        local addD = styleButton(vgui.Create("DButton", frame), MUI.blue) addD:SetPos(534, 82) addD:SetSize(190, 34) addD:SetText("+  ДОБАВИТЬ РАЙОН") addD.DoClick = function() send("add_district", function() net.WriteString(name:GetValue()); net.WriteUInt(radius:GetValue(), 16) end) end
        local addP = styleButton(vgui.Create("DButton", frame), MUI.orange) addP:SetPos(734, 82) addP:SetSize(220, 34) addP:SetText("+  ДОБАВИТЬ ТОЧКУ") addP.DoClick = function() send("add_point", function() net.WriteString(name:GetValue()); net.WriteUInt(radius:GetValue(), 16) end) end
        local sc = vgui.Create("DScrollPanel", frame) sc:SetPos(22, 132) sc:SetSize(932, 550)
        local function editAccess(point)
            local w = vgui.Create("DFrame") w:SetSize(420, 520) w:Center() w:MakePopup() w:SetTitle("Доступ к точке: " .. tostring(point.name))
            local selected = table.Copy(point.allowedFactions or {})
            local list = vgui.Create("DScrollPanel", w) list:Dock(FILL) list:DockMargin(10, 10, 10, 48)
            for factionName in SortedPairs(FactionsData or {}) do
                local c = vgui.Create("DCheckBoxLabel", list) c:Dock(TOP) c:SetTall(30) c:SetText(tostring(factionName)) c:SetValue(selected[factionName] == true)
                c.OnChange = function(_, value) selected[factionName] = value == true end
            end
            local saveAccess = vgui.Create("DButton", w) saveAccess:Dock(BOTTOM) saveAccess:SetTall(34) saveAccess:SetText("Сохранить доступ")
            saveAccess.DoClick = function() send("set_point_access", function() net.WriteString(point.id); net.WriteTable(selected) end) w:Close() end
        end
        local function rebuild()
            if not IsValid(sc) or not IsValid(frame) then return end
            sc:Clear()
            local title = vgui.Create("DLabel", sc) title:Dock(TOP) title:SetTall(34) title:SetFont("GRMMM_Body") title:SetTextColor(MUI.blue) title:SetText("РАЙОНЫ")
            for _, d in ipairs(data.districts or {}) do
                local row = vgui.Create("DPanel", sc) row:Dock(TOP) row:SetTall(42) row:DockMargin(0, 0, 0, 5) row.Paint = function(_, w, h) draw.RoundedBox(7, 0, 0, w, h, MUI.card) end
                local l = vgui.Create("DLabel", row) l:Dock(FILL) l:DockMargin(14, 0, 0, 0) l:SetFont("GRMMM_Body") l:SetTextColor(MUI.text) l:SetText(tostring(d.name) .. "   •   радиус " .. tostring(d.radius) .. "   •   " .. tostring(d.id))
                local b = styleButton(vgui.Create("DButton", row), MUI.red) b:Dock(RIGHT) b:DockMargin(5, 5, 5, 5) b:SetWide(110) b:SetText("Удалить") b.DoClick = function() send("delete_district", function() net.WriteString(d.id) end) end
            end
            local pt = vgui.Create("DLabel", sc) pt:Dock(TOP) pt:SetTall(40) pt:SetFont("GRMMM_Body") pt:SetTextColor(MUI.orange) pt:SetText("ТОЧКИ ЗАХВАТА")
            for _, p in ipairs(data.points or {}) do
                local row = vgui.Create("DPanel", sc) row:Dock(TOP) row:SetTall(48) row:DockMargin(0, 0, 0, 5) row.Paint = function(_, w, h) draw.RoundedBox(7, 0, 0, w, h, MUI.card) end
                local l = vgui.Create("DLabel", row) l:Dock(FILL) l:DockMargin(14, 0, 0, 0) l:SetFont("GRMMM_Small") l:SetTextColor(MUI.text) l:SetText(tostring(p.name) .. "   •   R " .. tostring(p.radius or 180) .. "   •   владелец: " .. (p.owner ~= "" and p.owner or "свободна") .. "   •   захват: " .. (p.capturing ~= "" and tostring(p.capturing) or "нет"))
                local access = styleButton(vgui.Create("DButton", row), MUI.blue) access:Dock(RIGHT) access:DockMargin(5, 7, 0, 7) access:SetWide(110) access:SetText("Доступ") access.DoClick = function() editAccess(p) end
                local b = styleButton(vgui.Create("DButton", row), MUI.red) b:Dock(RIGHT) b:DockMargin(5, 7, 5, 7) b:SetWide(110) b:SetText("Удалить") b.DoClick = function() send("delete_point", function() net.WriteString(p.id) end) end
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
    hook.Add("PostDrawTranslucentRenderables", "GRM_Minimap_CaptureFlags", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        for _, point in ipairs(data.points or {}) do
            local pos = Vector(point.pos.x, point.pos.y, point.pos.z or 0)
            if lp:GetPos():DistToSqr(pos) <= 1400 * 1400 then
                local col = point.owner ~= "" and Color(90, 220, 140, 230) or Color(240, 180, 70, 230)
                render.DrawLine(pos, pos + Vector(0, 0, 82), col, true)
                cam.Start3D2D(pos + Vector(0, 0, 84), Angle(0, lp:EyeAngles().y - 90, 90), 0.08)
                    draw.RoundedBox(5, -115, -23, 230, 46, Color(10, 16, 24, 220))
                    draw.SimpleText("ТОЧКА ЗАХВАТА", "DermaDefaultBold", 0, -8, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText(tostring(point.name), "DermaDefault", 0, 10, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                cam.End3D2D()
            end
        end
    end)

    hook.Add("HUDPaint", "GRM_Minimap_HUD", function()
        local lp = LocalPlayer() if not IsValid(lp) then return end
        renderMapSnapshot()
        local size, x, y = 280, ScrW() - 300, 18
        draw.RoundedBox(8, x - 4, y - 4, size + 8, size + 8, Color(10, 16, 24, 235))
        surface.SetMaterial(mapMat) surface.SetDrawColor(255, 255, 255, 185) surface.DrawTexturedRect(x, y, size, size)
        surface.SetDrawColor(45, 65, 86, 255) surface.DrawOutlinedRect(x, y, size, size, 2)
        for i = 1, 7 do surface.SetDrawColor(30, 48, 66, 180) surface.DrawLine(x + i * size / 8, y, x + i * size / 8, y + size) surface.DrawLine(x, y + i * size / 8, x + size, y + i * size / 8) end
        local mn, mx = worldBounds()
        local worldSpan = math.max(mx.x - mn.x, mx.y - mn.y)
        for _, d in ipairs(data.districts or {}) do
            local dx, dy = mapPos(Vector(d.center.x, d.center.y, 0), x, y, size)
            local dr = math.Clamp((tonumber(d.radius) or 500) / worldSpan * size, 6, size / 2)
            surface.SetDrawColor(80, 160, 245, 120)
            if istable(d.polygon) and #d.polygon >= 3 and d.polygonClosed then
                for i = 1, #d.polygon do
                    local a, b = d.polygon[i], d.polygon[i % #d.polygon + 1]
                    local ax, ay = mapPos(Vector(a.x, a.y, 0), x, y, size)
                    local bx, by = mapPos(Vector(b.x, b.y, 0), x, y, size)
                    surface.DrawLine(ax, ay, bx, by)
                end
            else surface.DrawCircle(dx, dy, dr, 80, 160, 245, 120) end
            draw.SimpleText(tostring(d.name) .. (d.owner ~= "" and " • " .. d.owner or ""), "DermaDefaultBold", dx, dy, Color(100, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        for _, p in ipairs(data.points or {}) do
            local px, py = mapPos(Vector(p.pos.x, p.pos.y, 0), x, y, size)
            local col = p.owner ~= "" and Color(100, 220, 140, 255) or Color(240, 180, 70, 255)
            local pr = math.Clamp((tonumber(p.radius) or 180) / worldSpan * size, 4, 34)
            surface.SetDrawColor(col) surface.DrawCircle(px, py, pr, col.r, col.g, col.b, 80)
            surface.SetDrawColor(col) surface.DrawRect(px - 3, py - 3, 6, 6)
            draw.SimpleText(tostring(p.name), "DermaDefault", px, py - 8, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
            if tonumber(p.capture or 0) > 0 then draw.SimpleText(math.floor((p.capture or 0) / 30 * 100) .. "%", "DermaDefault", px, py + 8, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP) end
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
                    local target = Vector(p.pos.x, p.pos.y, p.pos.z or lp:GetPos().z)
                    local relative = (target - lp:GetPos()):Angle().y - lp:EyeAngles().y
                    local arrowX, arrowY = ScrW() / 2, ScrH() - 105
                    local rad = math.rad(relative)
                    local dir = Vector(math.cos(rad), math.sin(rad), 0)
                    local side = Vector(-dir.y, dir.x, 0)
                    surface.SetDrawColor(255, 220, 90, 255)
                    surface.DrawPoly({ { x = arrowX + dir.x * 22, y = arrowY + dir.y * 22 }, { x = arrowX - dir.x * 12 + side.x * 10, y = arrowY - dir.y * 12 + side.y * 10 }, { x = arrowX - dir.x * 12 - side.x * 10, y = arrowY - dir.y * 12 - side.y * 10 } })
                    draw.SimpleText("GPS: " .. tostring(p.name) .. "  •  " .. math.floor(lp:GetPos():Distance(target)) .. " юн.", "DermaDefaultBold", ScrW() / 2, ScrH() - 70, Color(255, 220, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    break
                end
            end
        end
        local current = "Вне района"
        for _, d in ipairs(data.districts or {}) do if lp:GetPos():DistToSqr(Vector(d.center.x, d.center.y, d.center.z or 0)) <= (tonumber(d.radius) or 0)^2 then current = d.name end end
        draw.SimpleText(current, "DermaDefaultBold", x + size / 2, y + size + 10, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end)
end
