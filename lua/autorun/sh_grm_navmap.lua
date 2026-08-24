--[[--------------------------------------------------------------------
    GRM Nav Atlas — новая карта (не старый GPS-HUD и не чужие zip).
    Миниатюра справа сверху. Большая карта: метки, закрепление, маршрут.
----------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Nav = GRM.Nav or {}
local N = GRM.Nav
N.Version = "1.0.0"
N.File = "grm_navatlas_" .. string.lower(game.GetMap() or "unknown") .. ".json"

N.Kinds = {
    pin      = { label = "Метка",     col = Color(235, 164, 70) },
    police   = { label = "Полиция",   col = Color(70, 145, 240) },
    hospital = { label = "Медицина",  col = Color(80, 210, 140) },
    shop     = { label = "Торговля",  col = Color(250, 185, 63) },
    danger   = { label = "Опасность", col = Color(230, 70, 80) },
    depot    = { label = "Склад",     col = Color(160, 130, 220) },
    custom   = { label = "Знак",      col = Color(200, 210, 220) },
}

local function jsonLoad(path)
    if not file.Exists(path, "DATA") then return { marks = {} } end
    local ok, t = pcall(util.JSONToTable, file.Read(path, "DATA") or "", false, true)
    if ok and istable(t) then
        t.marks = istable(t.marks) and t.marks or {}
        return t
    end
    return { marks = {} }
end

if SERVER then
    util.AddNetworkString("GRM_Nav_Sync")
    util.AddNetworkString("GRM_Nav_Act")
    util.AddNetworkString("GRM_Nav_Route")

    N.Data = N.Data or jsonLoad(N.File)

    local function save()
        file.Write(N.File, util.TableToJSON({ marks = N.Data.marks }, false) or "{}")
    end

    local function send(ply)
        local payload = { marks = N.Data.marks or {} }
        if GRM.Net and GRM.Net.Stream then
            GRM.Net.Stream("GRM_Nav_Sync", payload, IsValid(ply) and ply or nil, { chunk = 4096, interval = 0.04 })
        else
            net.Start("GRM_Nav_Sync")
            net.WriteTable(payload)
            if IsValid(ply) then net.Send(ply) else net.Broadcast() end
        end
    end

    local function nid()
        return "nav_" .. os.time() .. "_" .. math.random(100, 999)
    end

    local function buildRoute(from, to)
        local path = { { x = from.x, y = from.y, z = from.z } }
        if not (navmesh and navmesh.GetNearestNavArea) then
            path[2] = { x = to.x, y = to.y, z = to.z }
            return path
        end
        local a = navmesh.GetNearestNavArea(from)
        local g = navmesh.GetNearestNavArea(to)
        if not (IsValid(a) and IsValid(g)) then
            path[2] = { x = to.x, y = to.y, z = to.z }
            return path
        end
        local seen, cur = {}, a
        for _ = 1, 90 do
            if cur == g then break end
            seen[cur:GetID()] = true
            local best, bd
            local adj = cur.GetAdjacentAreas and cur:GetAdjacentAreas() or {}
            for _, nb in ipairs(adj) do
                if IsValid(nb) and not seen[nb:GetID()] then
                    local d = nb:GetCenter():DistToSqr(to)
                    if not bd or d < bd then best, bd = nb, d end
                end
            end
            if not best then break end
            cur = best
            local p = cur.GetClosestPointOnArea and cur:GetClosestPointOnArea(to) or cur:GetCenter()
            path[#path + 1] = { x = p.x, y = p.y, z = p.z }
        end
        path[#path + 1] = { x = to.x, y = to.y, z = to.z }
        return path
    end

    net.Receive("GRM_Nav_Act", function(_, ply)
        if not IsValid(ply) then return end
        ply._grmNavNext = ply._grmNavNext or 0
        if CurTime() < ply._grmNavNext then return end
        ply._grmNavNext = CurTime() + 0.2
        local act = string.sub(net.ReadString() or "", 1, 24)

        if act == "route" then
            local tx, ty, tz = net.ReadFloat(), net.ReadFloat(), net.ReadFloat()
            local from, to = ply:GetPos(), Vector(tx, ty, tz)
            local path = buildRoute(from, to)
            net.Start("GRM_Nav_Route")
                net.WriteUInt(#path, 8)
                for _, p in ipairs(path) do
                    net.WriteFloat(p.x) net.WriteFloat(p.y) net.WriteFloat(p.z)
                end
            net.Send(ply)
            return
        end

        if act == "me" then
            -- личная метка живёт на клиенте; сервер только подтверждает
            return
        end

        if not ply:IsSuperAdmin() then return end

        if act == "add" then
            local name = string.sub(string.Trim(net.ReadString() or ""), 1, 48)
            local kind = string.sub(net.ReadString() or "pin", 1, 16)
            if not N.Kinds[kind] then kind = "pin" end
            local pin = net.ReadBool()
            local x, y, z = net.ReadFloat(), net.ReadFloat(), net.ReadFloat()
            if name == "" then name = (N.Kinds[kind] and N.Kinds[kind].label) or "Метка" end
            N.Data.marks[#N.Data.marks + 1] = {
                id = nid(), name = name, kind = kind, pin = pin == true,
                pos = { x = x, y = y, z = z },
            }
            save(); send()
        elseif act == "del" then
            local id = net.ReadString()
            for i = #(N.Data.marks or {}), 1, -1 do
                if tostring(N.Data.marks[i].id) == id then table.remove(N.Data.marks, i) end
            end
            save(); send()
        elseif act == "pin" then
            local id = net.ReadString()
            for _, m in ipairs(N.Data.marks or {}) do
                if tostring(m.id) == id then m.pin = not m.pin end
            end
            save(); send()
        elseif act == "sync" then
            send(ply)
        end
    end)

    hook.Add("PlayerInitialSpawn", "GRM_Nav_Join", function(ply)
        timer.Simple(4, function() if IsValid(ply) then send(ply) end end)
    end)

    print("[GRM Nav] v" .. N.Version .. " server")
end

if CLIENT then
    N.Marks = N.Marks or {}
    N.Route = N.Route or {}
    N.Waypoint = N.Waypoint
    N.Visible = true

    local COL = {
        bg = Color(8, 14, 23, 168),
        line = Color(55, 117, 151, 200),
        text = Color(225, 238, 247),
        dim = Color(132, 160, 178),
        gold = Color(250, 185, 63),
        you = Color(64, 222, 147),
    }

    surface.CreateFont("GRMNav_Tiny", { font = "Roboto", size = 11, weight = 600, extended = true })
    surface.CreateFont("GRMNav_Mid", { font = "Roboto", size = 14, weight = 700, extended = true })
    surface.CreateFont("GRMNav_Big", { font = "Roboto", size = 20, weight = 800, extended = true })

    local apply
    apply = function(t)
        if istable(t) then N.Marks = t.marks or {} end
    end
    net.Receive("GRM_Nav_Sync", function() apply(net.ReadTable() or {}) end)
    if GRM.Net and GRM.Net.Receive then
        GRM.Net.Receive("GRM_Nav_Sync", apply)
    end

    net.Receive("GRM_Nav_Route", function()
        local n = net.ReadUInt(8)
        N.Route = {}
        for i = 1, n do
            N.Route[i] = Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat())
        end
    end)

    local function worldBounds()
        local w = game.GetWorld()
        if not IsValid(w) then return Vector(-8000, -8000, 0), Vector(8000, 8000, 0) end
        local a, b = w:GetModelBounds()
        return Vector(a.x, a.y, a.z), Vector(b.x, b.y, b.z)
    end

    local peekRT = GetRenderTarget("GRM_NavPeekRT", 256, 256, false)
    local peekMat = CreateMaterial("GRM_NavPeekMat", "UnlitGeneric", {
        ["$basetexture"] = peekRT:GetName(),
        ["$vertexalpha"] = 1,
        ["$vertexcolor"] = 1,
    })
    local nextPeek = 0
    local function bakePeek(ply)
        if CurTime() < nextPeek then return end
        nextPeek = CurTime() + 0.28
        local pos = ply:GetPos() + Vector(0, 0, 2400)
        render.PushRenderTarget(peekRT)
        render.Clear(8, 14, 23, 255, true, true)
        render.RenderView({
            origin = pos,
            angles = Angle(90, ply:EyeAngles().y, 0),
            x = 0, y = 0, w = 256, h = 256,
            fov = 58,
            znear = 16, zfar = 20000,
            drawhud = false, drawviewmodel = false, drawskybox = false,
        })
        render.PopRenderTarget()
    end

    local atlasRT = GetRenderTarget("GRM_NavAtlasRT", 768, 768, false)
    local atlasMat = CreateMaterial("GRM_NavAtlasMat", "UnlitGeneric", {
        ["$basetexture"] = atlasRT:GetName(),
        ["$vertexalpha"] = 1,
        ["$vertexcolor"] = 1,
    })
    local atlasReady, atlasCenter, atlasSpan = false, nil, 1

    local function bakeAtlas()
        if atlasReady then return end
        atlasReady = true
        local mn, mx = worldBounds()
        atlasSpan = math.max(mx.x - mn.x, mx.y - mn.y, 2048)
        local mid = Vector((mn.x + mx.x) * 0.5, (mn.y + mx.y) * 0.5, mx.z)
        local surfaceZ = mn.z
        for _, s in ipairs({
            Vector(mid.x, mid.y, mx.z + 6000),
            Vector(mn.x + atlasSpan * 0.2, mn.y + atlasSpan * 0.2, mx.z + 6000),
            Vector(mx.x - atlasSpan * 0.2, mx.y - atlasSpan * 0.2, mx.z + 6000),
        }) do
            local tr = util.TraceLine({ start = s, endpos = Vector(s.x, s.y, mn.z - 4000), mask = MASK_SOLID_BRUSHONLY })
            if tr.Hit then surfaceZ = math.max(surfaceZ, tr.HitPos.z) end
        end
        atlasCenter = Vector(mid.x, mid.y, surfaceZ + 80)
        render.PushRenderTarget(atlasRT)
        render.Clear(8, 14, 23, 255, true, true)
        render.RenderView({
            origin = atlasCenter,
            angles = Angle(90, 90, 0),
            x = 0, y = 0, w = 768, h = 768,
            ortho = true,
            ortholeft = -atlasSpan * 0.5,
            orthoright = atlasSpan * 0.5,
            orthotop = -atlasSpan * 0.5,
            orthobottom = atlasSpan * 0.5,
            znear = 1, zfar = math.max(16000, atlasSpan * 2),
            drawhud = false, drawviewmodel = false, drawskybox = false,
        })
        render.PopRenderTarget()
    end

    local function worldToAtlas(pos, x, y, size)
        if not atlasCenter then return x + size / 2, y + size / 2 end
        local dx = (pos.x - atlasCenter.x) / atlasSpan
        local dy = (pos.y - atlasCenter.y) / atlasSpan
        return x + size * (0.5 + dx), y + size * (0.5 - dy)
    end

    local function atlasToWorld(mx, my, x, y, size)
        if not atlasCenter then return Vector(0, 0, 0) end
        local u = (mx - x) / size - 0.5
        local v = 0.5 - (my - y) / size
        return Vector(atlasCenter.x + u * atlasSpan, atlasCenter.y + v * atlasSpan, atlasCenter.z)
    end

    local function collectBlips()
        local out = {}
        for _, m in ipairs(N.Marks or {}) do
            if istable(m.pos) then
                out[#out + 1] = {
                    id = m.id, name = m.name, kind = m.kind, pin = m.pin,
                    pos = Vector(m.pos.x, m.pos.y, m.pos.z or 0),
                    admin = true,
                }
            end
        end
        local MM = GRM.Minimap
        if MM and MM.OfficialPoints then
            for _, p in ipairs(MM.OfficialPoints() or {}) do
                if istable(p.pos) then
                    out[#out + 1] = {
                        id = p.id, name = p.name, kind = "gps",
                        pos = Vector(p.pos.x, p.pos.y, p.pos.z or 0),
                        gps = true, temp = p.temp,
                    }
                end
            end
        end
        if MM and MM.PersonalPoints then
            for _, p in ipairs(MM.PersonalPoints() or {}) do
                if istable(p.pos) then
                    out[#out + 1] = {
                        id = p.id, name = p.name, kind = "me",
                        pos = Vector(p.pos.x, p.pos.y, p.pos.z or 0),
                        personal = true,
                    }
                end
            end
        end
        return out
    end

    local function kindCol(kind)
        if kind == "gps" then return COL.gold end
        if kind == "me" then return Color(120, 210, 255) end
        local k = N.Kinds[kind]
        return k and k.col or COL.gold
    end

    local function requestRoute(vec)
        net.Start("GRM_Nav_Act")
            net.WriteString("route")
            net.WriteFloat(vec.x) net.WriteFloat(vec.y) net.WriteFloat(vec.z)
        net.SendToServer()
    end

    function N.SetWaypoint(pos, name, gpsId)
        N.Waypoint = { pos = Vector(pos.x, pos.y, pos.z or 0), name = name or "Маршрут", id = gpsId }
        requestRoute(N.Waypoint.pos)
        local MM = GRM.Minimap
        if MM and gpsId and MM.SetGPSTarget then MM.SetGPSTarget(gpsId) end
    end

    function N.ClearWaypoint()
        N.Waypoint = nil
        N.Route = {}
        if GRM.Minimap and GRM.Minimap.ClearGPS then GRM.Minimap.ClearGPS() end
    end

    local function drawRoute(toScreen)
        if not N.Route or #N.Route < 2 then
            if N.Waypoint then
                local a = toScreen(LocalPlayer():GetPos())
                local b = toScreen(N.Waypoint.pos)
                surface.SetDrawColor(COL.gold)
                surface.DrawLine(a.x, a.y, b.x, b.y)
            end
            return
        end
        surface.SetDrawColor(250, 185, 63, 230)
        for i = 1, #N.Route - 1 do
            local a = toScreen(N.Route[i])
            local b = toScreen(N.Route[i + 1])
            surface.DrawLine(a.x, a.y, b.x, b.y)
        end
    end

    local function drawBlip(x, y, col, pin)
        surface.SetDrawColor(col)
        surface.DrawRect(x - 3, y - 3, 6, 6)
        if pin then
            surface.DrawOutlinedRect(x - 6, y - 6, 12, 12, 1)
        end
    end

    -- ── мини-карта справа сверху ──────────────────────────────────
    hook.Add("HUDPaint", "GRM_Nav_Mini", function()
        if not N.Visible then return end
        local lp = LocalPlayer()
        if not IsValid(lp) or not lp:Alive() then return end
        if GRM.AugHUD and GRM.AugHUD.IsActive and GRM.AugHUD.IsActive() then return end
        bakeAtlas()

        local size = 228
        local x, y = ScrW() - 16 - size, 16
        N.MiniRect = { x = x, y = y, w = size, h = size }

        draw.RoundedBox(8, x, y, size, size, COL.bg)
        surface.SetDrawColor(COL.line)
        surface.DrawOutlinedRect(x, y, size, size, 1)

        render.SetScissorRect(x + 2, y + 2, x + size - 2, y + size - 2, true)
        local yaw = lp:EyeAngles().y
        local zoom = 2800
        local function miniXY(world)
            local dx, dy = world.x - lp:GetPos().x, world.y - lp:GetPos().y
            local rad = math.rad(-yaw + 90)
            local c, s = math.cos(rad), math.sin(rad)
            local rx = dx * c - dy * s
            local ry = dx * s + dy * c
            return x + size / 2 + (rx / zoom) * size, y + size / 2 - (ry / zoom) * size
        end

        if atlasReady then
            -- кусок атласа вокруг игрока, поворот под взгляд
            surface.SetMaterial(atlasMat)
            surface.SetDrawColor(255, 255, 255, 210)
            local u = 0.5 + (lp:GetPos().x - (atlasCenter and atlasCenter.x or 0)) / atlasSpan
            local v = 0.5 - (lp:GetPos().y - (atlasCenter and atlasCenter.y or 0)) / atlasSpan
            local span = zoom / atlasSpan
            surface.DrawTexturedRectRotated(x + size / 2, y + size / 2, size / span, size / span, yaw - 90)
        end

        drawRoute(function(vec) local px, py = miniXY(vec) return { x = px, y = py } end)

        for _, b in ipairs(collectBlips()) do
            if b.pin or b.gps or b.personal or (N.Waypoint and N.Waypoint.id == b.id) then
                local px, py = miniXY(b.pos)
                if px > x and px < x + size and py > y and py < y + size then
                    drawBlip(px, py, kindCol(b.kind), b.pin)
                end
            end
        end

        -- игрок
        local cx, cy = x + size / 2, y + size / 2
        surface.SetDrawColor(COL.you)
        surface.DrawPoly({
            { x = cx, y = cy - 8 },
            { x = cx - 5, y = cy + 6 },
            { x = cx + 5, y = cy + 6 },
        })
        render.SetScissorRect(0, 0, 0, 0, false)

        draw.SimpleText("N", "GRMNav_Tiny", x + size / 2, y + 6, Color(230, 80, 70), TEXT_ALIGN_CENTER)
        draw.SimpleText("КАРТА  M", "GRMNav_Tiny", x + 8, y + size - 14, COL.dim, TEXT_ALIGN_LEFT)

        if N.Waypoint then
            local dist = math.floor(lp:GetPos():Distance(N.Waypoint.pos))
            draw.SimpleText(dist .. " м", "GRMNav_Tiny", x + size - 8, y + size - 14, COL.gold, TEXT_ALIGN_RIGHT)
        end
    end)

    -- ── большая карта ─────────────────────────────────────────────
    local atlasFrame
    function N.OpenAtlas()
        bakeAtlas()
        if IsValid(atlasFrame) then atlasFrame:Remove() end
        local fr = vgui.Create("DFrame")
        atlasFrame = fr
        local W, H = math.min(ScrW() - 40, 1100), math.min(ScrH() - 40, 780)
        fr:SetSize(W, H)
        fr:Center()
        fr:SetTitle("")
        fr:MakePopup()
        fr:ShowCloseButton(false)
        fr.Paint = function(_, w, h)
            draw.RoundedBox(10, 0, 0, w, h, Color(8, 14, 23, 250))
            draw.SimpleText("АТЛАС МЕСТНОСТИ", "GRMNav_Big", 16, 18, COL.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("ЛКМ — маршрут   ПКМ админ — знак   /карта", "GRMNav_Tiny", 16, 40, COL.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local close = vgui.Create("DButton", fr)
        close:SetPos(W - 40, 10) close:SetSize(28, 28) close:SetText("×") close:SetTextColor(color_white)
        close.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(180, 50, 50) or Color(50, 60, 75)) end
        close.DoClick = function() fr:Close() end

        local map = vgui.Create("DPanel", fr)
        map:SetPos(12, 54)
        map:SetSize(W - 280, H - 70)

        local kindBox = vgui.Create("DComboBox", fr)
        kindBox:SetPos(W - 252, 54) kindBox:SetSize(236, 26)
        for k, def in pairs(N.Kinds) do kindBox:AddChoice(def.label, k) end
        kindBox:ChooseOptionID(1)

        local nameEnt = vgui.Create("DTextEntry", fr)
        nameEnt:SetPos(W - 252, 86) nameEnt:SetSize(236, 26)
        nameEnt:SetPlaceholderText("Подпись знака")

        local pinChk = vgui.Create("DCheckBoxLabel", fr)
        pinChk:SetPos(W - 252, 118) pinChk:SetText("Закрепить на мини-карте")
        pinChk:SetTextColor(COL.text) pinChk:SetValue(true)

        local list = vgui.Create("DListView", fr)
        list:SetPos(W - 252, 150)
        list:SetSize(236, H - 230)
        list:AddColumn("Знаки")
        local function refill()
            list:Clear()
            for _, m in ipairs(N.Marks or {}) do
                local line = list:AddLine((m.pin and "★ " or "") .. (m.name or m.id))
                line._id = m.id
            end
        end
        refill()

        local function selectedMark()
            local i = list:GetSelectedLine()
            local row = i and list:GetLine(i)
            return row and row._id
        end

        local btnPin = vgui.Create("DButton", fr)
        btnPin:SetPos(W - 252, H - 72) btnPin:SetSize(114, 28) btnPin:SetText("Закреп")
        btnPin.DoClick = function()
            local id = selectedMark()
            if not id then return end
            net.Start("GRM_Nav_Act") net.WriteString("pin") net.WriteString(id) net.SendToServer()
        end
        local btnDel = vgui.Create("DButton", fr)
        btnDel:SetPos(W - 130, H - 72) btnDel:SetSize(114, 28) btnDel:SetText("Удалить")
        btnDel.DoClick = function()
            local id = selectedMark()
            if not id then return end
            net.Start("GRM_Nav_Act") net.WriteString("del") net.WriteString(id) net.SendToServer()
        end
        local btnClr = vgui.Create("DButton", fr)
        btnClr:SetPos(W - 252, H - 40) btnClr:SetSize(236, 26) btnClr:SetText("Сбросить маршрут")
        btnClr.DoClick = function() N.ClearWaypoint() end

        map.Paint = function(self, w, h)
            surface.SetDrawColor(COL.bg)
            surface.DrawRect(0, 0, w, h)
            if atlasReady then
                surface.SetMaterial(atlasMat)
                surface.SetDrawColor(255, 255, 255, 235)
                surface.DrawTexturedRect(0, 0, w, h)
            end
            local function toS(vec)
                local px, py = worldToAtlas(vec, 0, 0, math.min(w, h))
                -- если карта не квадрат — центрируем
                local side = math.min(w, h)
                local ox, oy = (w - side) / 2, (h - side) / 2
                px, py = worldToAtlas(vec, ox, oy, side)
                return { x = px, y = py }
            end
            N._atlasMap = { pnl = self, side = math.min(w, h), ox = (w - math.min(w, h)) / 2, oy = (h - math.min(w, h)) / 2 }
            drawRoute(toS)
            for _, b in ipairs(collectBlips()) do
                local p = toS(b.pos)
                drawBlip(p.x, p.y, kindCol(b.kind), b.pin)
                draw.SimpleText(tostring(b.name or ""), "GRMNav_Tiny", p.x + 7, p.y - 6, kindCol(b.kind))
            end
            local lp = LocalPlayer()
            if IsValid(lp) then
                local p = toS(lp:GetPos())
                surface.SetDrawColor(COL.you)
                surface.DrawRect(p.x - 4, p.y - 4, 8, 8)
            end
        end

        map.OnMousePressed = function(self, code)
            local mx, my = self:CursorPos()
            local side = math.min(self:GetWide(), self:GetTall())
            local ox, oy = (self:GetWide() - side) / 2, (self:GetTall() - side) / 2
            local world = atlasToWorld(mx, my, ox, oy, side)
            if code == MOUSE_LEFT then
                -- клик по блипу цепляет GPS id
                local hit
                for _, b in ipairs(collectBlips()) do
                    local p = worldToAtlas(b.pos, ox, oy, side)
                    if math.abs(p - mx) < 10 and math.abs((select(2, worldToAtlas(b.pos, ox, oy, side))) - my) < 10 then
                        hit = b
                    end
                end
                -- fix: compute properly
                hit = nil
                for _, b in ipairs(collectBlips()) do
                    local px, py = worldToAtlas(b.pos, ox, oy, side)
                    if math.abs(px - mx) < 12 and math.abs(py - my) < 12 then hit = b break end
                end
                if hit then
                    N.SetWaypoint(hit.pos, hit.name, hit.id)
                else
                    if GRM.Minimap and GRM.Minimap.AddPersonal then
                        local p = GRM.Minimap.AddPersonal("Маршрут", world)
                        N.SetWaypoint(world, "Маршрут", p.id)
                    else
                        N.SetWaypoint(world, "Маршрут")
                    end
                end
                surface.PlaySound("buttons/button14.wav")
            elseif code == MOUSE_RIGHT then
                if not LocalPlayer():IsSuperAdmin() then
                    notification.AddLegacy("Знаки на карте ставит администратор.", NOTIFY_ERROR, 3)
                    return
                end
                local _, kind = kindBox:GetSelected()
                net.Start("GRM_Nav_Act")
                    net.WriteString("add")
                    net.WriteString(nameEnt:GetValue())
                    net.WriteString(kind or "pin")
                    net.WriteBool(pinChk:GetChecked())
                    net.WriteFloat(world.x) net.WriteFloat(world.y) net.WriteFloat(world.z)
                net.SendToServer()
            end
        end

        hook.Add("GRM_NavMarks", "GRM_NavAtlasList", function()
            if IsValid(list) then refill() end
        end)
    end

    hook.Add("Think", "GRM_Nav_MarkHook", function()
        -- лёгкий фан-аут после синка
    end)

    local lastMarks
    timer.Create("GRM_Nav_MarkPulse", 0.4, 0, function()
        if lastMarks ~= N.Marks then
            lastMarks = N.Marks
            hook.Run("GRM_NavMarks")
        end
    end)

    hook.Add("PlayerButtonDown", "GRM_Nav_Key", function(ply, btn)
        if ply ~= LocalPlayer() then return end
        if vgui.GetKeyboardFocus() then return end
        if gui.IsGameUIVisible and gui.IsGameUIVisible() then return end
        if btn == KEY_M then
            if IsValid(atlasFrame) then atlasFrame:Close() else N.OpenAtlas() end
        end
    end)

    hook.Add("PlayerSayTransform", "GRM_Nav_Chat", function(ply, pack)
        if ply ~= LocalPlayer() then return end
        local t = string.lower(string.Trim(pack and pack[1] or ""))
        if t == "/карта" or t == "/map" or t == "/atlas" then
            N.OpenAtlas()
            pack[1] = ""
            return true
        end
        if t == "/миникарта" or t == "/minimap" then
            N.Visible = not N.Visible
            pack[1] = ""
            return true
        end
    end)

    concommand.Add("grm_atlas", function() N.OpenAtlas() end)

    hook.Add("Think", "GRM_Nav_Arrive", function()
        if not N.Waypoint then return end
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        if lp:GetPos():DistToSqr(N.Waypoint.pos) < 140 * 140 then
            notification.AddLegacy("Вы на месте.", NOTIFY_GENERIC, 4)
            N.ClearWaypoint()
        end
    end)

    print("[GRM Nav] client")
end
