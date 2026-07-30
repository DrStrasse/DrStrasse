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
            MM.Data.points[#MM.Data.points + 1] = { id = nextID("point"), name = name ~= "" and name or "Точка захвата", pos = pos(ply:GetPos()), owner = "" }
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
        return Vector(a.x, a.y, -100000), Vector(b.x, b.y, 100000)
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
    net.Receive("GRM_Minimap_Data", function() data = net.ReadTable() or data end)
    net.Receive("GRM_Minimap_Open", function()
        if IsValid(frame) then frame:Remove() end
        frame = vgui.Create("DFrame") frame:SetSize(760, 620) frame:Center() frame:MakePopup() frame:SetTitle("GRM — Районы и мини-карта")
        local name = vgui.Create("DTextEntry", frame) name:SetPos(18, 42) name:SetSize(300, 28) name:SetPlaceholderText("Название района/точки")
        local radius = vgui.Create("DNumberWang", frame) radius:SetPos(328, 42) radius:SetSize(110, 28) radius:SetMin(100) radius:SetMax(10000) radius:SetValue(500)
        local addD = vgui.Create("DButton", frame) addD:SetPos(448, 42) addD:SetSize(140, 28) addD:SetText("+ Район здесь") addD.DoClick = function() send("add_district", function() net.WriteString(name:GetValue()); net.WriteUInt(radius:GetValue(), 16) end) end
        local addP = vgui.Create("DButton", frame) addP:SetPos(594, 42) addP:SetSize(140, 28) addP:SetText("+ Точка здесь") addP.DoClick = function() send("add_point", function() net.WriteString(name:GetValue()) end) end
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
                local l = vgui.Create("DLabel", row) l:Dock(FILL) l:SetText(tostring(p.name) .. "  |  владелец: " .. (p.owner ~= "" and p.owner or "свободна") .. "  |  " .. tostring(p.id))
                local b = vgui.Create("DButton", row) b:Dock(RIGHT) b:SetWide(100) b:SetText("Удалить") b.DoClick = function() send("delete_point", function() net.WriteString(p.id) end) end
            end
        end
        timer.Simple(0, rebuild)
        net.Receive("GRM_Minimap_Data", rebuild)
    end)
    concommand.Add("grm_minimap_admin", function() if IsValid(LocalPlayer()) and LocalPlayer():IsSuperAdmin() then net.Start("GRM_Minimap_Open") net.SendToServer() end end)
    hook.Add("HUDPaint", "GRM_Minimap_HUD", function()
        local lp = LocalPlayer() if not IsValid(lp) then return end
        local size, x, y = 220, ScrW() - 238, 18
        draw.RoundedBox(8, x - 4, y - 4, size + 8, size + 8, Color(10, 16, 24, 235))
        surface.SetDrawColor(45, 65, 86, 255) surface.DrawOutlinedRect(x, y, size, size, 2)
        for i = 1, 7 do surface.SetDrawColor(30, 48, 66, 180) surface.DrawLine(x + i * size / 8, y, x + i * size / 8, y + size) surface.DrawLine(x, y + i * size / 8, x + size, y + i * size / 8) end
        for _, d in ipairs(data.districts or {}) do
            local dx, dy = mapPos(Vector(d.center.x, d.center.y, 0), x, y, size)
            draw.SimpleText(tostring(d.name), "DermaDefaultBold", dx, dy, Color(100, 180, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        for _, p in ipairs(data.points or {}) do
            local px, py = mapPos(Vector(p.pos.x, p.pos.y, 0), x, y, size)
            surface.SetDrawColor(240, 180, 70, 255) surface.DrawRect(px - 3, py - 3, 6, 6)
        end
        local px, py = mapPos(lp:GetPos(), x, y, size)
        surface.SetDrawColor(90, 255, 150, 255) surface.DrawRect(px - 4, py - 4, 8, 8)
        local current = "Вне района"
        for _, d in ipairs(data.districts or {}) do if lp:GetPos():DistToSqr(Vector(d.center.x, d.center.y, d.center.z or 0)) <= (tonumber(d.radius) or 0)^2 then current = d.name end end
        draw.SimpleText(current, "DermaDefaultBold", x + size / 2, y + size + 10, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
    end)
end
