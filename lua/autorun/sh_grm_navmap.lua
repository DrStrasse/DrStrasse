--[[--------------------------------------------------------------------
    GRM Nav Atlas v1.2 — мини справа сверху, большой атлас, маршрут.
    Местность: один JPEG-снимок, не RenderView из HUD.
----------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Nav = GRM.Nav or {}
local N = GRM.Nav
N.Version = "1.2.0"
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
        local fn = function()
            file.Write(N.File, util.TableToJSON({ marks = N.Data.marks }, false) or "{}")
        end
        if GRM.Perf and GRM.Perf.Coalesce then GRM.Perf.Coalesce("grm_nav_save", 0.5, fn) else fn() end
    end

    local function send(ply)
        local payload = { marks = N.Data.marks or {} }
        if GRM.Net and GRM.Net.Stream then
            GRM.Net.Stream("GRM_Nav_Sync", payload, IsValid(ply) and ply or nil, { chunk = 4096, interval = 0.05 })
        else
            net.Start("GRM_Nav_Sync")
            net.WriteTable(payload)
            if IsValid(ply) then net.Send(ply) else net.Broadcast() end
        end
    end

    local function walkAxis(start, step, limit, make)
        local last, miss = start, 0
        for i = 1, 2500 do
            local v = start + step * i
            if v > limit or v < -limit then break end
            if util.IsInWorld(make(v)) then last, miss = v, 0
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
        local step, lim = 128, 32000
        local zHigh = walkAxis(origin.z, step, lim, function(z) return Vector(origin.x, origin.y, z) end)
        zHigh = math.Clamp(zHigh, origin.z + 200, origin.z + 8000)
        local n = walkAxis(origin.y, step, lim, function(y) return Vector(origin.x, y, origin.z + 64) end)
        local s = walkAxis(origin.y, -step, lim, function(y) return Vector(origin.x, y, origin.z + 64) end)
        local e = walkAxis(origin.x, step, lim, function(x) return Vector(x, origin.y, origin.z + 64) end)
        local w = walkAxis(origin.x, -step, lim, function(x) return Vector(x, origin.y, origin.z + 64) end)
        if math.abs(e - w) < 800 then w, e = origin.x - 4000, origin.x + 4000 end
        if math.abs(n - s) < 800 then s, n = origin.y - 4000, origin.y + 4000 end
        return { n = n, s = s, e = e, w = w, h = zHigh, cx = (e + w) * 0.5, cy = (n + s) * 0.5 }
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
        local a, g = navmesh.GetNearestNavArea(from), navmesh.GetNearestNavArea(to)
        if not (IsValid(a) and IsValid(g)) then
            path[2] = { x = to.x, y = to.y, z = to.z }
            return path
        end
        local seen, cur = {}, a
        for _ = 1, 70 do
            if cur == g then break end
            seen[cur:GetID()] = true
            local best, bd
            for _, nb in ipairs(cur.GetAdjacentAreas and cur:GetAdjacentAreas() or {}) do
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
            local path = buildRoute(ply:GetPos(), Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat()))
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
            N.Data.marks[#N.Data.marks + 1] = { id = nid(), name = name, kind = kind, pin = pin == true, pos = { x = x, y = y, z = z } }
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

N.Marks, N.Route, N.Visible = N.Marks or {}, N.Route or {}, true
N.Opt = N.Opt or { gps = true, admin = true, me = true, players = true, grid = true }
CreateClientConVar("grm_nav_key", "M", true, false)

local COL = {
    bg = Color(8, 14, 23, 175), panel = Color(12, 18, 28, 250),
    line = Color(55, 117, 151, 200), text = Color(225, 238, 247),
    dim = Color(132, 160, 178), gold = Color(250, 185, 63), you = Color(64, 222, 147),
}

surface.CreateFont("GRMNav_Tiny", { font = "Roboto", size = 11, weight = 600, extended = true })
surface.CreateFont("GRMNav_Mid", { font = "Roboto", size = 14, weight = 700, extended = true })
surface.CreateFont("GRMNav_Big", { font = "Roboto", size = 22, weight = 800, extended = true })

local function apply(t)
    if istable(t) then N.Marks = t.marks or {} hook.Run("GRM_NavMarks") end
end
net.Receive("GRM_Nav_Sync", function() apply(net.ReadTable() or {}) end)
if GRM.Net and GRM.Net.Receive then GRM.Net.Receive("GRM_Nav_Sync", apply) end

net.Receive("GRM_Nav_Route", function()
    local n = net.ReadUInt(8)
    N.Route = {}
    for i = 1, n do N.Route[i] = Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat()) end
end)

local atlasW, atlasE, atlasS, atlasN, atlasCenter
local function applyBounds(b)
    if not istable(b) then return end
    atlasW, atlasE, atlasS, atlasN = b.w, b.e, b.s, b.n
    atlasCenter = Vector(b.cx, b.cy, b.h)
end
net.Receive("GRM_Nav_Bounds", function()
    N.Bounds = {
        w = net.ReadFloat(), e = net.ReadFloat(), s = net.ReadFloat(), n = net.ReadFloat(),
        h = net.ReadFloat(), cx = net.ReadFloat(), cy = net.ReadFloat(),
    }
    applyBounds(N.Bounds)
end)

local function ensureBounds()
    if atlasW and atlasE and atlasE ~= atlasW then return end
    local lp = LocalPlayer()
    local o = IsValid(lp) and lp:GetPos() or Vector(0, 0, 0)
    atlasW, atlasE, atlasS, atlasN = o.x - 5000, o.x + 5000, o.y - 5000, o.y + 5000
    atlasCenter = o
end

local JPEG = "grm_navatlas/" .. string.lower(game.GetMap() or "map") .. ".jpg"
local jpegMat, jpegOk
local function loadJpeg()
    if not file.Exists(JPEG, "DATA") then jpegOk = false return end
    jpegMat = Material("data/" .. JPEG, "smooth noclamp")
    jpegOk = jpegMat and not jpegMat:IsError()
end
if not file.IsDir("grm_navatlas", "DATA") then file.CreateDir("grm_navatlas") end
loadJpeg()

-- Мини: редкий кадр, только PostRender, только если сдвинулись.
local peekRT = GetRenderTarget("GRM_NavPeek2", 160, 160, false)
local peekMat = CreateMaterial("GRM_NavPeek2Mat", "UnlitGeneric", {
    ["$basetexture"] = peekRT:GetName(), ["$vertexalpha"] = 1, ["$vertexcolor"] = 1,
})
local peekAt, peekPos, peekYaw, peekBusy = 0, Vector(0, 0, 0), 0, false

hook.Add("PostRender", "GRM_Nav_Peek", function()
    if not N.Visible or peekBusy then return end
    if IsValid(N._frame) then return end
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:Alive() then return end
    local now, pos, yaw = CurTime(), lp:GetPos(), lp:EyeAngles().y
    if now - peekAt < 0.85 and pos:DistToSqr(peekPos) < 90 * 90 and math.abs(math.AngleDifference(yaw, peekYaw)) < 18 then
        return
    end
    peekBusy, peekAt, peekPos, peekYaw = true, now, pos, yaw
    render.PushRenderTarget(peekRT)
    render.Clear(8, 14, 23, 255, true, true)
    render.RenderView({
        origin = pos + Vector(0, 0, 1800),
        angles = Angle(90, yaw, 0),
        x = 0, y = 0, w = 160, h = 160,
        fov = 62, znear = 32, zfar = 12000,
        drawhud = false, drawviewmodel = false, drawskybox = false,
    })
    render.PopRenderTarget()
    peekBusy = false
end)

-- Снимок большой карты: только когда окно закрыто и нет готового jpeg.
N._needShot = not file.Exists(JPEG, "DATA")
hook.Add("PostRender", "GRM_Nav_Shot", function()
    if not N._needShot or IsValid(N._frame) or peekBusy then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    ensureBounds()
    local cx = (atlasW + atlasE) * 0.5
    local cy = (atlasS + atlasN) * 0.5
    local span = math.max(math.abs(atlasE - atlasW), math.abs(atlasN - atlasS), 3000)
    local camZ = lp:GetPos().z + math.Clamp(span * 0.55, 2500, 14000)
    local rt = GetRenderTarget("GRM_NavShotRT", 512, 512, false)
    render.PushRenderTarget(rt)
    render.Clear(8, 14, 23, 255, true, true)
    render.RenderView({
        origin = Vector(cx, cy, camZ),
        angles = Angle(90, 90, 0),
        x = 0, y = 0, w = 512, h = 512,
        fov = 90, znear = 64, zfar = 50000,
        drawhud = false, drawviewmodel = false, drawskybox = true,
    })
    local data = render.Capture({ format = "jpeg", quality = 70, x = 0, y = 0, w = 512, h = 512 })
    render.PopRenderTarget()
    N._needShot = false
    if data and #data > 200 then
        file.Write(JPEG, data)
        loadJpeg()
    end
end)

local function worldToMap(pos, x, y, w, h, zoom, ox, oy)
    ensureBounds()
    local ux = (pos.x - atlasW) / math.max(1, atlasE - atlasW)
    local uy = 1 - (pos.y - atlasS) / math.max(1, atlasN - atlasS)
    zoom = zoom or 1
    ox, oy = ox or 0, oy or 0
    return x + (ux - 0.5) * w * zoom + w * 0.5 + ox, y + (uy - 0.5) * h * zoom + h * 0.5 + oy
end

local function mapToWorld(mx, my, x, y, w, h, zoom, ox, oy)
    ensureBounds()
    zoom = zoom or 1
    ox, oy = ox or 0, oy or 0
    local ux = ((mx - x - ox) - w * 0.5) / (w * zoom) + 0.5
    local uy = ((my - y - oy) - h * 0.5) / (h * zoom) + 0.5
    return Vector(atlasW + ux * (atlasE - atlasW), atlasN - uy * (atlasN - atlasS), IsValid(LocalPlayer()) and LocalPlayer():GetPos().z or 0)
end

local blipCache, blipAt = {}, 0
local function collectBlips()
    local now = CurTime()
    if now - blipAt < 0.2 then return blipCache end
    blipAt = now
    local out = {}
    if N.Opt.admin then
        for _, m in ipairs(N.Marks or {}) do
            if istable(m.pos) then
                out[#out + 1] = { id = m.id, name = m.name, kind = m.kind, pin = m.pin, pos = Vector(m.pos.x, m.pos.y, m.pos.z or 0) }
            end
        end
    end
    local MM = GRM.Minimap
    if N.Opt.gps and MM and MM.OfficialPoints then
        for _, p in ipairs(MM.OfficialPoints() or {}) do
            if istable(p.pos) then
                out[#out + 1] = { id = p.id, name = p.name, kind = "gps", pos = Vector(p.pos.x, p.pos.y, p.pos.z or 0) }
            end
        end
    end
    if N.Opt.me and MM and MM.PersonalPoints then
        for _, p in ipairs(MM.PersonalPoints() or {}) do
            if istable(p.pos) then
                out[#out + 1] = { id = p.id, name = p.name, kind = "me", pos = Vector(p.pos.x, p.pos.y, p.pos.z or 0) }
            end
        end
    end
    blipCache = out
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
    N.Waypoint, N.Route = nil, {}
    if GRM.Minimap and GRM.Minimap.ClearGPS then GRM.Minimap.ClearGPS() end
end

local function drawRoute(toS)
    surface.SetDrawColor(250, 185, 63, 240)
    if N.Route and #N.Route >= 2 then
        for i = 1, #N.Route - 1 do
            local a, b = toS(N.Route[i]), toS(N.Route[i + 1])
            surface.DrawLine(a.x, a.y, b.x, b.y)
            surface.DrawLine(a.x + 1, a.y, b.x + 1, b.y)
        end
        return
    end
    if N.Waypoint and IsValid(LocalPlayer()) then
        local a, b = toS(LocalPlayer():GetPos()), toS(N.Waypoint.pos)
        surface.DrawLine(a.x, a.y, b.x, b.y)
    end
end

local function plyNick(pl)
    if not IsValid(pl) then return "?" end
    local n = pl:GetNWString("GRM_RPName", "")
    if n == "" then n = pl:Nick() end
    if #n > 18 then n = string.sub(n, 1, 16) .. "…" end
    return n
end

local function drawPlayerDot(x, y, nick, mine, showName)
    local r = mine and 6 or 5
    draw.NoTexture()
    local poly = {}
    for i = 0, 10 do
        local a = (i / 10) * math.pi * 2
        poly[#poly + 1] = { x = x + math.cos(a) * r, y = y + math.sin(a) * r }
    end
    surface.SetDrawColor(0, 0, 0, 255)
    local ring = {}
    for i = 0, 10 do
        local a = (i / 10) * math.pi * 2
        ring[#ring + 1] = { x = x + math.cos(a) * (r + 1.6), y = y + math.sin(a) * (r + 1.6) }
    end
    surface.DrawPoly(ring)
    surface.SetDrawColor(255, 255, 255, 255)
    surface.DrawPoly(poly)
    if showName ~= false and nick and nick ~= "" then
        draw.SimpleTextOutlined(nick, "GRMNav_Tiny", x, y - r - 8, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 230))
    end
end

local function eachPlayer(fn)
    local list = (GRM.Perf and GRM.Perf.Players) and GRM.Perf.Players() or player.GetAll()
    for _, pl in ipairs(list) do
        if IsValid(pl) and pl:Alive() then fn(pl) end
    end
end

local function drawBlip(x, y, col, name, big)
    local s = big and 5 or 3
    surface.SetDrawColor(0, 0, 0, 200)
    surface.DrawRect(x - s - 1, y - s - 1, s * 2 + 2, s * 2 + 2)
    surface.SetDrawColor(col)
    surface.DrawRect(x - s, y - s, s * 2, s * 2)
    if name and big then
        draw.SimpleTextOutlined(name, "GRMNav_Tiny", x + 8, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))
    end
end

local function paintGround(x, y, w, h)
    draw.RoundedBox(0, x, y, w, h, Color(18, 28, 40, 255))
    if atlasLiveMat then
        surface.SetMaterial(atlasLiveMat)
        surface.SetDrawColor(255, 255, 255, 235)
        surface.DrawTexturedRect(x, y, w, h)
    elseif jpegOk and jpegMat then
        surface.SetMaterial(jpegMat)
        surface.SetDrawColor(255, 255, 255, 230)
        surface.DrawTexturedRect(x, y, w, h)
    end
    if N.Opt.grid then
        surface.SetDrawColor(55, 90, 120, 55)
        for i = 1, 7 do
            surface.DrawLine(x + i * w / 8, y, x + i * w / 8, y + h)
            surface.DrawLine(x, y + i * h / 8, x + w, y + i * h / 8)
        end
    end
end

hook.Add("HUDPaint", "GRM_Nav_Mini", function()
    if not N.Visible then return end
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:Alive() then return end
    if GRM.AugHUD and GRM.AugHUD.IsActive and GRM.AugHUD.IsActive() then return end

    local size, x, y = 210, ScrW() - 16 - 210, 16
    draw.RoundedBox(8, x, y, size, size, COL.bg)
    surface.SetDrawColor(COL.line)
    surface.DrawOutlinedRect(x, y, size, size, 1)
    render.SetScissorRect(x + 2, y + 2, x + size - 2, y + size - 2, true)
    surface.SetMaterial(peekMat)
    surface.SetDrawColor(255, 255, 255, 230)
    surface.DrawTexturedRect(x + 3, y + 3, size - 6, size - 6)

    local yaw, zoom = lp:EyeAngles().y, 2600
    local function miniXY(world)
        local dx, dy = world.x - lp:GetPos().x, world.y - lp:GetPos().y
        local rad = math.rad(-yaw)
        local c, s = math.cos(rad), math.sin(rad)
        return x + size / 2 + (dx * c - dy * s) / zoom * size, y + size / 2 - (dx * s + dy * c) / zoom * size
    end
    drawRoute(function(v) local px, py = miniXY(v) return { x = px, y = py } end)
    for _, b in ipairs(collectBlips()) do
        local px, py = miniXY(b.pos)
        if px > x and px < x + size and py > y and py < y + size then
            drawBlip(px, py, kindCol(b.kind), nil, false)
        end
    end
    if N.Opt.players ~= false then
        eachPlayer(function(pl)
            local px, py = miniXY(pl:GetPos())
            if px > x + 4 and px < x + size - 4 and py > y + 4 and py < y + size - 4 then
                drawPlayerDot(px, py, plyNick(pl), pl == lp, true)
            end
        end)
    end
    render.SetScissorRect(0, 0, 0, 0, false)
    draw.SimpleText("N", "GRMNav_Tiny", x + size / 2, y + 6, Color(230, 80, 70), TEXT_ALIGN_CENTER)
    draw.SimpleText("M — атлас", "GRMNav_Tiny", x + 8, y + size - 14, COL.dim)
    if N.Waypoint then
        draw.SimpleText(math.floor(lp:GetPos():Distance(N.Waypoint.pos)) .. " м", "GRMNav_Tiny", x + size - 8, y + size - 14, COL.gold, TEXT_ALIGN_RIGHT)
    end
end)

function N.OpenAtlas()
    net.Start("GRM_Nav_Act") net.WriteString("sync") net.SendToServer()
    ensureBounds()
    if IsValid(N._frame) then N._frame:Remove() end
    local fr = vgui.Create("DFrame")
    N._frame = fr
    local W, H = math.max(ScrW() - 24, 900), math.max(ScrH() - 24, 640)
    fr:SetSize(W, H)
    fr:Center()
    fr:SetTitle("")
    fr:MakePopup()
    fr:ShowCloseButton(false)
    fr.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, COL.panel)
        draw.SimpleText("АТЛАС", "GRMNav_Big", 18, 20, COL.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("ЛКМ маршрут  ·  колёсико зум  ·  СКМ перетаскивание  ·  ПКМ знак (админ)", "GRMNav_Tiny", 18, 42, COL.dim)
    end

    local close = vgui.Create("DButton", fr)
    close:SetSize(32, 28) close:SetPos(W - 44, 12) close:SetText("×") close:SetTextColor(color_white)
    close.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(180, 50, 50) or Color(45, 55, 70)) end
    close.DoClick = function() fr:Close() end

    local map = vgui.Create("DPanel", fr)
    map:SetPos(12, 56)
    map:SetSize(W - 300, H - 70)
    local zoom, ox, oy, drag = 1, 0, 0, nil

    map.OnMouseWheeled = function(_, d)
        zoom = math.Clamp(zoom + d * 0.12, 0.5, 4)
    end
    map.OnMousePressed = function(self, code)
        local mx, my = self:CursorPos()
        local w, h = self:GetWide(), self:GetTall()
        if code == MOUSE_MIDDLE then
            drag = { x = mx, y = my, ox = ox, oy = oy }
            return
        end
        local world = mapToWorld(mx, my, 0, 0, w, h, zoom, ox, oy)
        if code == MOUSE_LEFT then
            local hit
            for _, b in ipairs(collectBlips()) do
                local px, py = worldToMap(b.pos, 0, 0, w, h, zoom, ox, oy)
                if math.abs(px - mx) < 14 and math.abs(py - my) < 14 then hit = b break end
            end
            if hit then N.SetWaypoint(hit.pos, hit.name, hit.id)
            else
                if GRM.Minimap and GRM.Minimap.AddPersonal then
                    local p = GRM.Minimap.AddPersonal("Точка", world)
                    N.SetWaypoint(world, "Точка", p.id)
                else
                    N.SetWaypoint(world, "Точка")
                end
            end
            surface.PlaySound("buttons/button14.wav")
        elseif code == MOUSE_RIGHT then
            if not LocalPlayer():IsSuperAdmin() then
                notification.AddLegacy("Знаки ставит администратор.", NOTIFY_ERROR, 3)
                return
            end
            net.Start("GRM_Nav_Act")
                net.WriteString("add")
                net.WriteString(N._signName or "")
                net.WriteString(N._signKind or "pin")
                net.WriteBool(N._signPin ~= false)
                net.WriteFloat(world.x) net.WriteFloat(world.y) net.WriteFloat(world.z)
            net.SendToServer()
        end
    end
    map.OnMouseReleased = function() drag = nil end
    map.Think = function(self)
        if drag and input.IsMouseDown(MOUSE_MIDDLE) then
            local mx, my = self:CursorPos()
            ox = drag.ox + (mx - drag.x)
            oy = drag.oy + (my - drag.y)
        end
    end

    map.Paint = function(self, w, h)
        ensureBounds()
        local mid = mapToWorld(w * 0.5, h * 0.5, 0, 0, w, h, zoom, ox, oy)
        local span = math.max(math.abs(atlasE - atlasW), math.abs(atlasN - atlasS), 2000) / math.max(zoom, 0.5)
        local lpz = IsValid(LocalPlayer()) and LocalPlayer():GetPos().z or 0
        N._atlasCam = {
            x = mid.x, y = mid.y,
            z = lpz + math.Clamp(span * 0.42, 1400, 12000),
            span = span,
        }
        paintGround(0, 0, w, h)
        local function toS(vec)
            local px, py = worldToMap(vec, 0, 0, w, h, zoom, ox, oy)
            return { x = px, y = py }
        end
        drawRoute(toS)
        for _, b in ipairs(collectBlips()) do
            local p = toS(b.pos)
            drawBlip(p.x, p.y, kindCol(b.kind), b.name, true)
        end
        if N.Opt.players then
            for _, pl in ipairs(player.GetAll()) do
                if IsValid(pl) and pl ~= LocalPlayer() then
                    local p = toS(pl:GetPos())
                    drawBlip(p.x, p.y, Color(180, 200, 220), pl:GetNWString("GRM_RPName", pl:Nick()), true)
                end
            end
        end
        if IsValid(LocalPlayer()) then
            local p = toS(LocalPlayer():GetPos())
            surface.SetDrawColor(COL.you)
            surface.DrawRect(p.x - 5, p.y - 5, 10, 10)
            draw.SimpleTextOutlined("ВЫ", "GRMNav_Tiny", p.x, p.y - 14, COL.you, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 220))
        end
        if not jpegOk then
            draw.SimpleText("Схема карты. Снимок местности достроится, когда закроешь окно.", "GRMNav_Tiny", 12, h - 16, COL.dim)
        end
    end

    local side = vgui.Create("DScrollPanel", fr)
    side:SetPos(W - 276, 56)
    side:SetSize(264, H - 70)

    local function chk(txt, key)
        local c = vgui.Create("DCheckBoxLabel", side)
        c:Dock(TOP) c:DockMargin(4, 4, 4, 2) c:SetText(txt) c:SetTextColor(COL.text)
        c:SetValue(N.Opt[key] ~= false)
        c.OnChange = function(_, v) N.Opt[key] = v blipAt = 0 end
    end
    local lab = vgui.Create("DLabel", side)
    lab:Dock(TOP) lab:SetTall(22) lab:SetText("  СЛОИ") lab:SetFont("GRMNav_Mid") lab:SetTextColor(COL.gold)
    chk("GPS-точки", "gps")
    chk("Знаки админа", "admin")
    chk("Личные точки", "me")
    chk("Игроки", "players")
    chk("Сетка", "grid")

    local lab2 = vgui.Create("DLabel", side)
    lab2:Dock(TOP) lab2:SetTall(28) lab2:SetText("  ЗНАК АДМИНА") lab2:SetFont("GRMNav_Mid") lab2:SetTextColor(COL.gold)
    local kindBox = vgui.Create("DComboBox", side)
    kindBox:Dock(TOP) kindBox:SetTall(26) kindBox:DockMargin(4, 2, 4, 4)
    for k, def in pairs(N.Kinds) do kindBox:AddChoice(def.label, k) end
    kindBox:ChooseOptionID(1)
    kindBox.OnSelect = function(_, _, _, k) N._signKind = k end
    local nameEnt = vgui.Create("DTextEntry", side)
    nameEnt:Dock(TOP) nameEnt:SetTall(26) nameEnt:DockMargin(4, 2, 4, 4)
    nameEnt:SetPlaceholderText("Подпись")
    nameEnt.OnChange = function(s) N._signName = s:GetValue() end
    local pinChk = vgui.Create("DCheckBoxLabel", side)
    pinChk:Dock(TOP) pinChk:DockMargin(4, 2, 4, 6) pinChk:SetText("Закрепить на мини") pinChk:SetTextColor(COL.text) pinChk:SetValue(true)
    pinChk.OnChange = function(_, v) N._signPin = v end

    local list = vgui.Create("DListView", side)
    list:Dock(TOP) list:SetTall(220) list:DockMargin(4, 4, 4, 4)
    list:AddColumn("Все метки")
    local function refill()
        if not IsValid(list) then return end
        list:Clear()
        for _, b in ipairs(collectBlips()) do
            local line = list:AddLine((b.pin and "★ " or "") .. (b.name or b.id))
            line._id = b.id
            line._pos = b.pos
            line._name = b.name
        end
    end
    refill()
    list.OnRowSelected = function(_, _, line)
        if line and line._pos then N.SetWaypoint(line._pos, line._name, line._id) end
    end

    local btnShot = vgui.Create("DButton", side)
    btnShot:Dock(TOP) btnShot:SetTall(30) btnShot:DockMargin(4, 6, 4, 4)
    btnShot:SetText("Переснять местность")
    btnShot.DoClick = function()
        if file.Exists(JPEG, "DATA") then file.Delete(JPEG) end
        jpegOk = false
        N._needShot = true
        notification.AddLegacy("Закрой атлас на секунду — снимок сохранится.", NOTIFY_GENERIC, 4)
    end
    local btnClr = vgui.Create("DButton", side)
    btnClr:Dock(TOP) btnClr:SetTall(30) btnClr:DockMargin(4, 2, 4, 4)
    btnClr:SetText("Сбросить маршрут")
    btnClr.DoClick = function() N.ClearWaypoint() end
    local btnPin = vgui.Create("DButton", side)
    btnPin:Dock(TOP) btnPin:SetTall(28) btnPin:DockMargin(4, 8, 4, 2)
    btnPin:SetText("Закрепить выбранный знак")
    btnPin.DoClick = function()
        local i = list:GetSelectedLine()
        local row = i and list:GetLine(i)
        if row and row._id then
            net.Start("GRM_Nav_Act") net.WriteString("pin") net.WriteString(row._id) net.SendToServer()
        end
    end
    local btnDel = vgui.Create("DButton", side)
    btnDel:Dock(TOP) btnDel:SetTall(28) btnDel:DockMargin(4, 2, 4, 4)
    btnDel:SetText("Удалить знак")
    btnDel.DoClick = function()
        local i = list:GetSelectedLine()
        local row = i and list:GetLine(i)
        if row and row._id then
            net.Start("GRM_Nav_Act") net.WriteString("del") net.WriteString(row._id) net.SendToServer()
        end
    end

    hook.Add("GRM_NavMarks", "GRM_NavAtlasList", refill)
end

local function navKey()
    local cv = GetConVar("grm_nav_key")
    local name = string.upper((cv and cv:GetString()) or "M")
    local code = input.GetKeyCode(name)
    if not code or code <= 0 then return KEY_M end
    return code
end

hook.Add("PlayerButtonDown", "GRM_Nav_Key", function(ply, btn)
    if ply ~= LocalPlayer() or btn ~= navKey() then return end
    if vgui.GetKeyboardFocus() then return end
    if gui.IsGameUIVisible and gui.IsGameUIVisible() then return end
    if IsValid(N._frame) then N._frame:Close() else N.OpenAtlas() end
end)

hook.Add("PlayerSayTransform", "GRM_Nav_Chat", function(ply, pack)
    if ply ~= LocalPlayer() then return end
    local t = string.lower(string.Trim(pack and pack[1] or ""))
    if t == "/карта" or t == "/map" or t == "/atlas" then N.OpenAtlas() pack[1] = "" return true end
    if t == "/миникарта" or t == "/minimap" then N.Visible = not N.Visible pack[1] = "" return true end
    if t == "/карта_переснять" then
        if file.Exists(JPEG, "DATA") then file.Delete(JPEG) end
        jpegOk, N._needShot = false, true
        pack[1] = ""
        return true
    end
end)

concommand.Add("grm_atlas", function() N.OpenAtlas() end)

local nextArrive = 0
hook.Add("Think", "GRM_Nav_Arrive", function()
    if not N.Waypoint then return end
    local now = CurTime()
    if now < nextArrive then return end
    nextArrive = now + 0.25
    local lp = LocalPlayer()
    if IsValid(lp) and lp:GetPos():DistToSqr(N.Waypoint.pos) < 140 * 140 then
        notification.AddLegacy("Вы на месте.", NOTIFY_GENERIC, 4)
        N.ClearWaypoint()
    end
end)

print("[GRM Nav] v" .. N.Version .. " client")
