--[[--------------------------------------------------------------------
    GRM Nav Atlas — новая карта.
    Мини справа сверху. Атлас: местность, знаки админа, GPS, маршрут.
----------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Nav = GRM.Nav or {}
local N = GRM.Nav
N.Version = "1.1.0"
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
    util.AddNetworkString("GRM_Nav_Bounds")

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

    local function walkAxis(start, step, limit, make)
        local last, miss = start, 0
        for i = 1, 4000 do
            local v = start + step * i
            if v > limit or v < -limit then break end
            if util.IsInWorld(make(v)) then
                last, miss = v, 0
            else
                miss = miss + 1
                if miss >= 4 then break end
            end
        end
        return last
    end

    local function measureBounds()
        local origin
        for _, e in ipairs(ents.FindByClass("info_player_start")) do
            if IsValid(e) then origin = e:GetPos() break end
        end
        if not origin then
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) then origin = p:GetPos() break end
            end
        end
        origin = origin or Vector(0, 0, 0)
        local step, lim = 96, 48000
        local zHigh = walkAxis(origin.z, step, lim, function(z) return Vector(origin.x, origin.y, z) end)
        local n = walkAxis(origin.y, step, lim, function(y) return Vector(origin.x, y, zHigh) end)
        local s = walkAxis(origin.y, -step, lim, function(y) return Vector(origin.x, y, zHigh) end)
        local e = walkAxis(origin.x, step, lim, function(x) return Vector(x, origin.y, zHigh) end)
        local w = walkAxis(origin.x, -step, lim, function(x) return Vector(x, origin.y, zHigh) end)
        return {
            n = n, s = s, e = e, w = w, h = zHigh + 200,
            cx = (e + w) * 0.5, cy = (n + s) * 0.5,
        }
    end

    function N.SendBounds(ply)
        N.Bounds = N.Bounds or measureBounds()
        net.Start("GRM_Nav_Bounds")
            net.WriteFloat(N.Bounds.w) net.WriteFloat(N.Bounds.e)
            net.WriteFloat(N.Bounds.s) net.WriteFloat(N.Bounds.n)
            net.WriteFloat(N.Bounds.h)
            net.WriteFloat(N.Bounds.cx) net.WriteFloat(N.Bounds.cy)
        if IsValid(ply) then net.Send(ply) else net.Broadcast() end
    end

    hook.Add("InitPostEntity", "GRM_Nav_Bounds", function()
        timer.Simple(2, function() N.Bounds = measureBounds() end)
    end)

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
            local path = buildRoute(ply:GetPos(), Vector(tx, ty, tz))
            net.Start("GRM_Nav_Route")
                net.WriteUInt(#path, 8)
                for _, p in ipairs(path) do
                    net.WriteFloat(p.x) net.WriteFloat(p.y) net.WriteFloat(p.z)
                end
            net.Send(ply)
            return
        end

        if act == "sync" then
            send(ply)
            N.SendBounds(ply)
            return
        end

        if not ply:IsSuperAdmin() then return end

        if act == "add" then
            local name = string.sub(string.Trim(net.ReadString() or ""), 1, 48)
            local kind = string.sub(net.ReadString() or "pin", 1, 16)
            if not N.Kinds[kind] then kind = "pin" end
            local pin = net.ReadBool()
            local x, y, z = net.ReadFloat(), net.ReadFloat(), net.ReadFloat()
            if name == "" then name = N.Kinds[kind].label end
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
        end
    end)

    hook.Add("PlayerInitialSpawn", "GRM_Nav_Join", function(ply)
        timer.Simple(4, function()
            if not IsValid(ply) then return end
            send(ply)
            N.SendBounds(ply)
        end)
    end)

    print("[GRM Nav] v" .. N.Version .. " server")
end

if not CLIENT then return end

N.Marks = N.Marks or {}
N.Route = N.Route or {}
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

local function apply(t)
    if istable(t) then N.Marks = t.marks or {} end
end
net.Receive("GRM_Nav_Sync", function() apply(net.ReadTable() or {}) end)
if GRM.Net and GRM.Net.Receive then GRM.Net.Receive("GRM_Nav_Sync", apply) end

net.Receive("GRM_Nav_Route", function()
    local n = net.ReadUInt(8)
    N.Route = {}
    for i = 1, n do
        N.Route[i] = Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat())
    end
end)

net.Receive("GRM_Nav_Bounds", function()
    N.Bounds = {
        w = net.ReadFloat(), e = net.ReadFloat(),
        s = net.ReadFloat(), n = net.ReadFloat(),
        h = net.ReadFloat(),
        cx = net.ReadFloat(), cy = net.ReadFloat(),
    }
    N._atlasDirty = true
end)

local peekRT = GetRenderTarget("GRM_NavPeekRT", 256, 256, false)
local peekMat = CreateMaterial("GRM_NavPeekMat", "UnlitGeneric", {
    ["$basetexture"] = peekRT:GetName(), ["$vertexalpha"] = 1, ["$vertexcolor"] = 1,
})
local nextPeek = 0
local function bakePeek(ply)
    if CurTime() < nextPeek then return end
    nextPeek = CurTime() + 0.28
    render.PushRenderTarget(peekRT)
    render.Clear(8, 14, 23, 255, true, true)
    render.RenderView({
        origin = ply:GetPos() + Vector(0, 0, 2400),
        angles = Angle(90, ply:EyeAngles().y, 0),
        x = 0, y = 0, w = 256, h = 256,
        fov = 58, znear = 16, zfar = 20000,
        drawhud = false, drawviewmodel = false, drawskybox = false,
    })
    render.PopRenderTarget()
end

local atlasRT = GetRenderTarget("GRM_NavAtlasRT", 768, 768, false)
local atlasMat = CreateMaterial("GRM_NavAtlasMat", "UnlitGeneric", {
    ["$basetexture"] = atlasRT:GetName(), ["$vertexalpha"] = 1, ["$vertexcolor"] = 1,
})
local atlasReady, atlasCenter = false, nil
local atlasW, atlasE, atlasS, atlasN

local function bakeAtlas()
    if atlasReady and not N._atlasDirty then return end
    N._atlasDirty = false
    local b, lp = N.Bounds, LocalPlayer()
    local origin = IsValid(lp) and lp:GetPos() or Vector(0, 0, 0)
    if istable(b) then
        atlasW, atlasE, atlasS, atlasN = b.w, b.e, b.s, b.n
        atlasCenter = Vector(b.cx, b.cy, b.h * 0.82)
    else
        atlasW, atlasE = origin.x - 6000, origin.x + 6000
        atlasS, atlasN = origin.y - 6000, origin.y + 6000
        atlasCenter = Vector(origin.x, origin.y, origin.z + 9000)
    end
    local span = math.max(math.abs(atlasE - atlasW), math.abs(atlasN - atlasS), 2048)
    render.PushRenderTarget(atlasRT)
    render.Clear(8, 14, 23, 255, true, true)
    render.RenderView({
        origin = Vector((atlasW + atlasE) * 0.5, (atlasS + atlasN) * 0.5, atlasCenter.z),
        angles = Angle(90, 90, 0),
        x = 0, y = 0, w = 768, h = 768,
        ortho = true,
        ortholeft = atlasW, orthoright = atlasE,
        orthotop = atlasS, orthobottom = atlasN,
        znear = 8, zfar = math.max(24000, span * 3),
        drawhud = false, drawviewmodel = false, drawskybox = true,
    })
    render.PopRenderTarget()
    atlasReady = true
end

hook.Add("PostRender", "GRM_Nav_Bake", function()
    if gui.IsGameUIVisible and gui.IsGameUIVisible() then return end
    if not atlasReady or N._atlasDirty then bakeAtlas() end
end)

local function worldToAtlas(pos, x, y, size)
    if not atlasW then return x + size / 2, y + size / 2 end
    local ux = (pos.x - atlasW) / math.max(1, atlasE - atlasW)
    local uy = (pos.y - atlasS) / math.max(1, atlasN - atlasS)
    return x + ux * size, y + (1 - uy) * size
end

local function atlasToWorld(mx, my, x, y, size)
    if not atlasW then return Vector(0, 0, 0) end
    local ux = (mx - x) / math.max(1, size)
    local uy = 1 - (my - y) / math.max(1, size)
    return Vector(atlasW + ux * (atlasE - atlasW), atlasS + uy * (atlasN - atlasS), atlasCenter and atlasCenter.z or 0)
end

local function collectBlips()
    local out = {}
    for _, m in ipairs(N.Marks or {}) do
        if istable(m.pos) then
            out[#out + 1] = { id = m.id, name = m.name, kind = m.kind, pin = m.pin, pos = Vector(m.pos.x, m.pos.y, m.pos.z or 0), admin = true }
        end
    end
    local MM = GRM.Minimap
    if MM and MM.OfficialPoints then
        for _, p in ipairs(MM.OfficialPoints() or {}) do
            if istable(p.pos) then
                out[#out + 1] = { id = p.id, name = p.name, kind = "gps", pos = Vector(p.pos.x, p.pos.y, p.pos.z or 0), gps = true }
            end
        end
    end
    if MM and MM.PersonalPoints then
        for _, p in ipairs(MM.PersonalPoints() or {}) do
            if istable(p.pos) then
                out[#out + 1] = { id = p.id, name = p.name, kind = "me", pos = Vector(p.pos.x, p.pos.y, p.pos.z or 0), personal = true }
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

function N.SetWaypoint(pos, name, gpsId)
    N.Waypoint = { pos = Vector(pos.x, pos.y, pos.z or 0), name = name or "Маршрут", id = gpsId }
    net.Start("GRM_Nav_Act")
        net.WriteString("route")
        net.WriteFloat(pos.x) net.WriteFloat(pos.y) net.WriteFloat(pos.z or 0)
    net.SendToServer()
    if GRM.Minimap and gpsId and GRM.Minimap.SetGPSTarget then GRM.Minimap.SetGPSTarget(gpsId) end
end

function N.ClearWaypoint()
    N.Waypoint = nil
    N.Route = {}
    if GRM.Minimap and GRM.Minimap.ClearGPS then GRM.Minimap.ClearGPS() end
end

local function drawRoute(toScreen)
    if not N.Route or #N.Route < 2 then
        if N.Waypoint and IsValid(LocalPlayer()) then
            local a, b = toScreen(LocalPlayer():GetPos()), toScreen(N.Waypoint.pos)
            surface.SetDrawColor(COL.gold)
            surface.DrawLine(a.x, a.y, b.x, b.y)
        end
        return
    end
    surface.SetDrawColor(250, 185, 63, 230)
    for i = 1, #N.Route - 1 do
        local a, b = toScreen(N.Route[i]), toScreen(N.Route[i + 1])
        surface.DrawLine(a.x, a.y, b.x, b.y)
    end
end

local function drawBlip(x, y, col, pin)
    surface.SetDrawColor(col)
    surface.DrawRect(x - 3, y - 3, 6, 6)
    if pin then surface.DrawOutlinedRect(x - 6, y - 6, 12, 12, 1) end
end

hook.Add("HUDPaint", "GRM_Nav_Mini", function()
    if not N.Visible then return end
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:Alive() then return end
    if GRM.AugHUD and GRM.AugHUD.IsActive and GRM.AugHUD.IsActive() then return end
    bakePeek(lp)

    local size = 228
    local x, y = ScrW() - 16 - size, 16
    draw.RoundedBox(8, x, y, size, size, COL.bg)
    surface.SetDrawColor(COL.line)
    surface.DrawOutlinedRect(x, y, size, size, 1)
    render.SetScissorRect(x + 2, y + 2, x + size - 2, y + size - 2, true)

    surface.SetMaterial(peekMat)
    surface.SetDrawColor(255, 255, 255, 220)
    surface.DrawTexturedRect(x + 3, y + 3, size - 6, size - 6)

    local yaw, zoom = lp:EyeAngles().y, 2800
    local function miniXY(world)
        local dx, dy = world.x - lp:GetPos().x, world.y - lp:GetPos().y
        local rad = math.rad(-yaw)
        local c, s = math.cos(rad), math.sin(rad)
        return x + size / 2 + (dx * c - dy * s) / zoom * size, y + size / 2 - (dx * s + dy * c) / zoom * size
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
    local cx, cy = x + size / 2, y + size / 2
    surface.SetDrawColor(COL.you)
    surface.DrawPoly({ { x = cx, y = cy - 8 }, { x = cx - 5, y = cy + 6 }, { x = cx + 5, y = cy + 6 } })
    render.SetScissorRect(0, 0, 0, 0, false)
    draw.SimpleText("N", "GRMNav_Tiny", x + size / 2, y + 6, Color(230, 80, 70), TEXT_ALIGN_CENTER)
    draw.SimpleText("КАРТА  M", "GRMNav_Tiny", x + 8, y + size - 14, COL.dim, TEXT_ALIGN_LEFT)
    if N.Waypoint then
        draw.SimpleText(math.floor(lp:GetPos():Distance(N.Waypoint.pos)) .. " м", "GRMNav_Tiny", x + size - 8, y + size - 14, COL.gold, TEXT_ALIGN_RIGHT)
    end
end)

local atlasFrame
function N.OpenAtlas()
    net.Start("GRM_Nav_Act") net.WriteString("sync") net.SendToServer()
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
        draw.SimpleText("ЛКМ — маршрут   ПКМ админ — знак   снимок печётся в мире, не в меню", "GRMNav_Tiny", 16, 40, COL.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
        if id then net.Start("GRM_Nav_Act") net.WriteString("pin") net.WriteString(id) net.SendToServer() end
    end
    local btnDel = vgui.Create("DButton", fr)
    btnDel:SetPos(W - 130, H - 72) btnDel:SetSize(114, 28) btnDel:SetText("Удалить")
    btnDel.DoClick = function()
        local id = selectedMark()
        if id then net.Start("GRM_Nav_Act") net.WriteString("del") net.WriteString(id) net.SendToServer() end
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
        else
            draw.SimpleText("Снимок местности… закрой окно на секунду, если пусто", "GRMNav_Tiny", w / 2, h / 2, COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        local side = math.min(w, h)
        local ox, oy = (w - side) / 2, (h - side) / 2
        local function toS(vec)
            local px, py = worldToAtlas(vec, ox, oy, side)
            return { x = px, y = py }
        end
        drawRoute(toS)
        for _, b in ipairs(collectBlips()) do
            local p = toS(b.pos)
            drawBlip(p.x, p.y, kindCol(b.kind), b.pin)
            draw.SimpleText(tostring(b.name or ""), "GRMNav_Tiny", p.x + 7, p.y - 6, kindCol(b.kind))
        end
        if IsValid(LocalPlayer()) then
            local p = toS(LocalPlayer():GetPos())
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
            local hit
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

timer.Create("GRM_Nav_MarkPulse", 0.4, 0, function()
    hook.Run("GRM_NavMarks")
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
        N.OpenAtlas() pack[1] = "" return true
    end
    if t == "/миникарта" or t == "/minimap" then
        N.Visible = not N.Visible pack[1] = "" return true
    end
    if t == "/карта_переснять" then
        N._atlasDirty = true pack[1] = "" return true
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
