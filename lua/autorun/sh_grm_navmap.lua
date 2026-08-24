--[[--------------------------------------------------------------------
    GRM Nav Atlas v1.3 — зум атласа, граф маршрута, редактор меток.
----------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Nav = GRM.Nav or {}
local N = GRM.Nav
N.Version = "1.3.0"
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
    if not file.Exists(path, "DATA") then return { marks = {}, nodes = {}, edges = {} } end
    local ok, t = pcall(util.JSONToTable, file.Read(path, "DATA") or "", false, true)
    if ok and istable(t) then
        t.marks = istable(t.marks) and t.marks or {}
        t.nodes = istable(t.nodes) and t.nodes or {}
        t.edges = istable(t.edges) and t.edges or {}
        return t
    end
    return { marks = {}, nodes = {}, edges = {} }
end

if SERVER then
    util.AddNetworkString("GRM_Nav_Sync")
    util.AddNetworkString("GRM_Nav_Act")
    util.AddNetworkString("GRM_Nav_Route")
    util.AddNetworkString("GRM_Nav_Bounds")

    N.Data = N.Data or jsonLoad(N.File)

    local function save()
        local fn = function()
            file.Write(N.File, util.TableToJSON({
                marks = N.Data.marks or {},
                nodes = N.Data.nodes or {},
                edges = N.Data.edges or {},
            }, false) or "{}")
        end
        if GRM.Perf and GRM.Perf.Coalesce then GRM.Perf.Coalesce("grm_nav_save", 0.5, fn) else fn() end
    end

    local function send(ply)
        local payload = {
            marks = N.Data.marks or {},
            nodes = N.Data.nodes or {},
            edges = N.Data.edges or {},
        }
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

    local function nodePos(n)
        return Vector(n.x or 0, n.y or 0, n.z or 0)
    end

    local function nearestNode(pos)
        local best, bd
        for _, n in ipairs(N.Data.nodes or {}) do
            local d = nodePos(n):DistToSqr(pos)
            if not bd or d < bd then best, bd = n, d end
        end
        return best, bd
    end

    local function graphNeighbors(id)
        local out = {}
        for _, e in ipairs(N.Data.edges or {}) do
            if e.a == id then out[#out + 1] = e.b
            elseif e.b == id then out[#out + 1] = e.a end
        end
        return out
    end

    local function findNode(id)
        for _, n in ipairs(N.Data.nodes or {}) do
            if n.id == id then return n end
        end
    end

    local function graphPath(fromId, toId)
        if not fromId or not toId then return end
        if fromId == toId then return { fromId } end
        local dist, prev, q = { [fromId] = 0 }, {}, { fromId }
        local seen = { [fromId] = true }
        local qi = 1
        while qi <= #q do
            local cur = q[qi]
            qi = qi + 1
            if cur == toId then break end
            local cn = findNode(cur)
            if cn then
                local cp = nodePos(cn)
                for _, nid in ipairs(graphNeighbors(cur)) do
                    local nn = findNode(nid)
                    if nn then
                        local nd = (dist[cur] or 0) + cp:Distance(nodePos(nn))
                        if not dist[nid] or nd < dist[nid] then
                            dist[nid] = nd
                            prev[nid] = cur
                            if not seen[nid] then
                                seen[nid] = true
                                q[#q + 1] = nid
                            end
                        end
                    end
                end
            end
        end
        if not prev[toId] and fromId ~= toId then return end
        local chain, c = {}, toId
        while c do
            table.insert(chain, 1, c)
            c = prev[c]
        end
        return chain
    end

    local function buildRoute(from, to)
        local path = { { x = from.x, y = from.y, z = from.z } }
        local a, ad = nearestNode(from)
        local b, bd = nearestNode(to)
        local snap = 1800 * 1800
        if a and b and ad and bd and ad < snap and bd < snap then
            local ids = graphPath(a.id, b.id)
            if ids and #ids > 0 then
                for _, id in ipairs(ids) do
                    local n = findNode(id)
                    if n then path[#path + 1] = { x = n.x, y = n.y, z = n.z } end
                end
                path[#path + 1] = { x = to.x, y = to.y, z = to.z }
                return path
            end
        end
        if not (navmesh and navmesh.GetNearestNavArea) then
            path[2] = { x = to.x, y = to.y, z = to.z }
            return path
        end
        local sa, sg = navmesh.GetNearestNavArea(from), navmesh.GetNearestNavArea(to)
        if not (IsValid(sa) and IsValid(sg)) then
            path[2] = { x = to.x, y = to.y, z = to.z }
            return path
        end
        local seen, cur = {}, sa
        for _ = 1, 90 do
            if cur == sg then break end
            seen[cur:GetID()] = true
            local best, bdist
            for _, nb in ipairs(cur.GetAdjacentAreas and cur:GetAdjacentAreas() or {}) do
                if IsValid(nb) and not seen[nb:GetID()] then
                    local d = nb:GetCenter():DistToSqr(to)
                    if not bdist or d < bdist then best, bdist = nb, d end
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
        local actPeek = string.sub(net.ReadString() or "", 1, 24)
        local cool = (actPeek == "gadd" or actPeek == "glink") and 0.05 or 0.2
        if CurTime() < ply._grmNavNext then return end
        ply._grmNavNext = CurTime() + cool
        local act = actPeek

        if act == "route" then
            local path = buildRoute(ply:GetPos(), Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat()))
            if #path > 250 then
                local slim = { path[1] }
                local step = math.max(1, math.floor(#path / 240))
                for i = 2, #path - 1, step do slim[#slim + 1] = path[i] end
                slim[#slim + 1] = path[#path]
                path = slim
            end
            net.Start("GRM_Nav_Route")
                net.WriteUInt(math.min(#path, 250), 8)
                for i = 1, math.min(#path, 250) do
                    local p = path[i]
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
        elseif act == "gadd" then
            N.Data.nodes = N.Data.nodes or {}
            N.Data.edges = N.Data.edges or {}
            local x, y, z = net.ReadFloat(), net.ReadFloat(), net.ReadFloat()
            local link = net.ReadString()
            local id = nid()
            N.Data.nodes[#N.Data.nodes + 1] = { id = id, x = x, y = y, z = z }
            if link ~= "" then
                N.Data.edges[#N.Data.edges + 1] = { a = link, b = id }
            end
            save(); send()
        elseif act == "glink" then
            local a, b = net.ReadString(), net.ReadString()
            if a ~= "" and b ~= "" and a ~= b then
                N.Data.edges = N.Data.edges or {}
                local dup
                for _, e in ipairs(N.Data.edges) do
                    if (e.a == a and e.b == b) or (e.a == b and e.b == a) then dup = true break end
                end
                if not dup then
                    N.Data.edges[#N.Data.edges + 1] = { a = a, b = b }
                    save(); send()
                end
            end
        elseif act == "gdel" then
            local id = net.ReadString()
            for i = #(N.Data.nodes or {}), 1, -1 do
                if N.Data.nodes[i].id == id then table.remove(N.Data.nodes, i) end
            end
            for i = #(N.Data.edges or {}), 1, -1 do
                local e = N.Data.edges[i]
                if e.a == id or e.b == id then table.remove(N.Data.edges, i) end
            end
            save(); send()
        elseif act == "gclear" then
            N.Data.nodes, N.Data.edges = {}, {}
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
N.Nodes, N.Edges = N.Nodes or {}, N.Edges or {}
N.Opt = N.Opt or { gps = true, admin = true, me = true, players = true, grid = true, graph = true }
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
    if not istable(t) then return end
    N.Marks = t.marks or {}
    N.Nodes = t.nodes or {}
    N.Edges = t.edges or {}
    if N._graphWait then
        local best, bd
        for _, n in ipairs(N.Nodes) do
            local d = Vector(n.x, n.y, n.z or 0):DistToSqr(N._graphWait)
            if not bd or d < bd then best, bd = n, d end
        end
        if best then N._lastNode = best.id end
        N._graphWait = nil
    end
    hook.Run("GRM_NavMarks")
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

-- Мини + живой атлас: один PostRender, без JPEG-слайдов.
local peekRT = GetRenderTarget("GRM_NavPeek3", 128, 128, false)
local peekMat = CreateMaterial("GRM_NavPeek3Mat", "UnlitGeneric", {
    ["$basetexture"] = peekRT:GetName(), ["$vertexalpha"] = 1, ["$vertexcolor"] = 1,
})
local peekAt, peekPos, peekYaw, peekBusy = 0, Vector(0, 0, 0), 0, false
local atlasRT = GetRenderTarget("GRM_NavLiveRT", 512, 512, false)
local atlasLiveMat = CreateMaterial("GRM_NavLiveMat", "UnlitGeneric", {
    ["$basetexture"] = atlasRT:GetName(), ["$vertexalpha"] = 1, ["$vertexcolor"] = 1,
})
local atlasShotAt, atlasBusy = 0, false
N._atlasCam = N._atlasCam or { x = 0, y = 0, z = 4000, span = 8000 }

hook.Add("PostRender", "GRM_Nav_Peek", function()
    if peekBusy or atlasBusy then return end
    local lp = LocalPlayer()
    if not IsValid(lp) or not lp:Alive() then return end
    if N._open then
        local now = CurTime()
        if now - atlasShotAt < 0.15 then return end
        atlasBusy, atlasShotAt = true, now
        local cam = N._atlasCam
        local lpz = lp:GetPos().z
        render.PushRenderTarget(atlasRT)
        render.Clear(8, 14, 23, 255, true, true)
        render.RenderView({
            origin = Vector(cam.x, cam.y, lpz + (cam.z or 2200)),
            angles = Angle(90, 90, 0),
            x = 0, y = 0, w = 512, h = 512,
            fov = 62, znear = 16, zfar = math.max(14000, (cam.z or 4000) + 8000),
            drawhud = false, drawviewmodel = false, drawskybox = false,
        })
        render.PopRenderTarget()
        atlasBusy = false
        return
    end
    if not N.Visible then return end
    local now, pos, yaw = CurTime(), lp:GetPos(), lp:EyeAngles().y
    local moved = pos:DistToSqr(peekPos) > 36 * 36 or math.abs(math.AngleDifference(yaw, peekYaw)) > 6
    if now - peekAt < (moved and 0.16 or 0.5) then return end
    peekBusy, peekAt, peekPos, peekYaw = true, now, pos, yaw
    render.PushRenderTarget(peekRT)
    render.Clear(8, 14, 23, 255, true, true)
    render.RenderView({
        origin = pos + Vector(0, 0, 1600),
        angles = Angle(90, yaw, 0),
        x = 0, y = 0, w = 128, h = 128,
        fov = 62, znear = 24, zfar = 10000,
        drawhud = false, drawviewmodel = false, drawskybox = false,
    })
    render.PopRenderTarget()
    peekBusy = false
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
                out[#out + 1] = { id = m.id, name = m.name, kind = m.kind, pin = m.pin, src = "admin", pos = Vector(m.pos.x, m.pos.y, m.pos.z or 0) }
            end
        end
    end
    local MM = GRM.Minimap
    if N.Opt.gps and MM and MM.OfficialPoints then
        for _, p in ipairs(MM.OfficialPoints() or {}) do
            if istable(p.pos) then
                out[#out + 1] = { id = p.id, name = p.name, kind = "gps", src = "gps", pos = Vector(p.pos.x, p.pos.y, p.pos.z or 0) }
            end
        end
    end
    if N.Opt.me and MM and MM.PersonalPoints then
        for _, p in ipairs(MM.PersonalPoints() or {}) do
            if istable(p.pos) then
                out[#out + 1] = { id = p.id, name = p.name, kind = "me", src = "me", pos = Vector(p.pos.x, p.pos.y, p.pos.z or 0) }
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

function N.DeleteMark(id, src)
    id = tostring(id or "")
    if id == "" then return end
    if src == "me" then
        if GRM.Minimap and GRM.Minimap.RemovePersonal then GRM.Minimap.RemovePersonal(id) end
        if N.Waypoint and tostring(N.Waypoint.id) == id then N.ClearWaypoint() end
        blipAt = 0
        hook.Run("GRM_NavMarks")
        return
    end
    if src == "gps" then
        net.Start("GRM_Minimap_Action")
            net.WriteString("delete_point")
            net.WriteString(id)
        net.SendToServer()
        blipAt = 0
        return
    end
    net.Start("GRM_Nav_Act")
        net.WriteString("del")
        net.WriteString(id)
    net.SendToServer()
    blipAt = 0
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
    if not N.Visible or N._open then return end
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


local function grmBtn(parent, txt, col)
    local b = vgui.Create("DButton", parent)
    b:SetText(txt)
    b:SetFont("GRMNav_Mid")
    b:SetTextColor(COL.text)
    b.Paint = function(s, w, h)
        local c = col or Color(22, 34, 50)
        if s:IsHovered() then c = Color(math.min(255, c.r + 30), math.min(255, c.g + 30), math.min(255, c.b + 30)) end
        draw.RoundedBox(6, 0, 0, w, h, c)
        surface.SetDrawColor(55, 117, 151, 180)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
    return b
end

local function camToScreen(world, x, y, w, h)
    local cam = N._atlasCam
    local half = math.tan(math.rad(31)) * (cam.z or 2200)
    local dx, dy = world.x - cam.x, world.y - cam.y
    return x + w * 0.5 + (dx / half) * (w * 0.5), y + h * 0.5 - (dy / half) * (h * 0.5)
end

local function screenToCam(mx, my, x, y, w, h)
    local cam = N._atlasCam
    local half = math.tan(math.rad(31)) * (cam.z or 2200)
    local ux = (mx - x) / w - 0.5
    local uy = 0.5 - (my - y) / h
    local lp = LocalPlayer()
    return Vector(cam.x + ux * 2 * half, cam.y + uy * 2 * half, IsValid(lp) and lp:GetPos().z or 0)
end

function N.CloseAtlas()
    N._open = false
    gui.EnableScreenClicker(false)
    if IsValid(N._catch) then N._catch:Remove() end
    if IsValid(N._frame) then N._frame:Remove() end
end

local function atlasZoom(delta, mx, my)
    local cam = N._atlasCam
    local oldZ = cam.z or 4200
    local newZ = math.Clamp(oldZ * (delta > 0 and 0.82 or 1.22), 380, 16000)
    if mx and my then
        local x, y, w, h = 12, 12, ScrW() - 276 - 28, ScrH() - 24
        local before = screenToCam(mx, my, x, y, w, h)
        cam.z = newZ
        local after = screenToCam(mx, my, x, y, w, h)
        cam.x = cam.x + (before.x - after.x)
        cam.y = cam.y + (before.y - after.y)
    else
        cam.z = newZ
    end
end

function N.OpenAtlas()
    net.Start("GRM_Nav_Act") net.WriteString("sync") net.SendToServer()
    local lp = LocalPlayer()
    local pos = IsValid(lp) and lp:GetPos() or Vector(0, 0, 0)
    N._atlasCam = { x = pos.x, y = pos.y, z = 4800 }
    N._mode = N._mode or "nav"
    N._open = true
    if IsValid(N._frame) then N._frame:Remove() end
    if IsValid(N._catch) then N._catch:Remove() end
    local catch = vgui.Create("DPanel")
    N._catch = catch
    catch:SetPos(12, 12)
    catch:SetSize(ScrW() - 276 - 28, ScrH() - 24)
    catch:SetPaintBackground(false)
    catch:SetMouseInputEnabled(true)
    catch:SetKeyboardInputEnabled(false)
    catch.OnMouseWheeled = function(_, d)
        atlasZoom(d, gui.MouseX(), gui.MouseY())
        return true
    end
    catch.OnMousePressed = function() end

    local sideW = 276
    local fr = vgui.Create("DFrame")
    N._frame = fr
    fr:SetSize(sideW, ScrH() - 24)
    fr:SetPos(ScrW() - sideW - 12, 12)
    fr:SetTitle("")
    fr:MakePopup()
    fr:ShowCloseButton(false)
    fr:SetKeyboardInputEnabled(false)
    fr.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(8, 14, 23, 242))
        surface.SetDrawColor(COL.line)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("АТЛАС", "GRMNav_Big", 14, 18, COL.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("живой вид, как мини", "GRMNav_Tiny", 14, 38, COL.dim)
    end
    fr.OnRemove = function()
        N._open = false
        gui.EnableScreenClicker(false)
        if IsValid(N._catch) then N._catch:Remove() end
    end

    local close = grmBtn(fr, "✕", Color(120, 40, 44))
    close:SetPos(sideW - 40, 10) close:SetSize(28, 26)
    close.DoClick = N.CloseAtlas

    local yy = 52
    local function chk(txt, key)
        local c = vgui.Create("DCheckBoxLabel", fr)
        c:SetPos(14, yy) c:SetSize(240, 20)
        c:SetText(txt) c:SetTextColor(COL.text) c:SetValue(N.Opt[key] ~= false)
        c.OnChange = function(_, v) N.Opt[key] = v blipAt = 0 end
        yy = yy + 22
    end
    local lab = vgui.Create("DLabel", fr)
    lab:SetPos(14, yy) lab:SetSize(240, 20) lab:SetFont("GRMNav_Mid") lab:SetTextColor(COL.gold) lab:SetText("СЛОИ")
    yy = yy + 22
    chk("GPS-точки", "gps")
    chk("Знаки админа", "admin")
    chk("Личные точки", "me")
    chk("Игроки", "players")
    chk("Сетка узлов", "graph")

    local labM = vgui.Create("DLabel", fr)
    labM:SetPos(14, yy + 6) labM:SetSize(240, 20) labM:SetFont("GRMNav_Mid") labM:SetTextColor(COL.gold) labM:SetText("РЕЖИМ")
    yy = yy + 30
    local modeBox = vgui.Create("DComboBox", fr)
    modeBox:SetPos(14, yy) modeBox:SetSize(248, 24)
    modeBox:AddChoice("Навигация / пан", "nav")
    if IsValid(lp) and lp:IsSuperAdmin() then
        modeBox:AddChoice("Знак на карте", "sign")
        modeBox:AddChoice("GPS-точка всем", "gps")
        modeBox:AddChoice("Узлы маршрута", "graph")
    end
    modeBox:ChooseOptionID(1)
    modeBox.OnSelect = function(_, _, _, k) N._mode = k or "nav" end
    yy = yy + 28
    if IsValid(lp) and lp:IsSuperAdmin() then
        local g1 = grmBtn(fr, "СБРОСИТЬ УЗЛЫ", Color(90, 40, 40))
        g1:SetPos(14, yy) g1:SetSize(248, 24)
        g1.DoClick = function()
            net.Start("GRM_Nav_Act") net.WriteString("gclear") net.SendToServer()
            N._lastNode = nil
        end
        yy = yy + 28
    end

    local lab2 = vgui.Create("DLabel", fr)
    lab2:SetPos(14, yy + 6) lab2:SetSize(240, 20) lab2:SetFont("GRMNav_Mid") lab2:SetTextColor(COL.gold) lab2:SetText("ЗНАК АДМИНА")
    yy = yy + 30
    local kindBox = vgui.Create("DComboBox", fr)
    kindBox:SetPos(14, yy) kindBox:SetSize(248, 24)
    for k, def in pairs(N.Kinds) do kindBox:AddChoice(def.label, k) end
    kindBox:ChooseOptionID(1)
    kindBox.OnSelect = function(_, _, _, k) N._signKind = k end
    yy = yy + 28
    local nameEnt = vgui.Create("DTextEntry", fr)
    nameEnt:SetPos(14, yy) nameEnt:SetSize(248, 24) nameEnt:SetPlaceholderText("Подпись знака")
    nameEnt.OnChange = function(s) N._signName = s:GetValue() end
    yy = yy + 28
    local pinChk = vgui.Create("DCheckBoxLabel", fr)
    pinChk:SetPos(14, yy) pinChk:SetSize(248, 20) pinChk:SetText("Закрепить на мини") pinChk:SetTextColor(COL.text) pinChk:SetValue(true)
    pinChk.OnChange = function(_, v) N._signPin = v end
    yy = yy + 28

    local list = vgui.Create("DListView", fr)
    list:SetPos(14, yy) list:SetSize(248, math.max(120, ScrH() - yy - 200))
    list:AddColumn("Метки")
    local function refill()
        if not IsValid(list) then return end
        list:Clear()
        for _, b in ipairs(collectBlips()) do
            local tag = b.src == "gps" and "GPS · " or (b.src == "me" and "моё · " or "")
            local line = list:AddLine((b.pin and "★ " or "") .. tag .. (b.name or b.id))
            line._id, line._pos, line._name, line._src = b.id, b.pos, b.name, b.src
        end
    end
    refill()
    list.OnRowSelected = function(_, _, line)
        if line and line._pos then
            N._atlasCam.x, N._atlasCam.y = line._pos.x, line._pos.y
            N.SetWaypoint(line._pos, line._name, line._id)
        end
    end
    hook.Add("GRM_NavMarks", "GRM_NavAtlasList", refill)

    local by = ScrH() - 24 - 12 - 148
    local function sel()
        local i = list:GetSelectedLine()
        return i and list:GetLine(i)
    end
    local b1 = grmBtn(fr, "ВЕСТИ СЮДА", Color(28, 88, 54))
    b1:SetPos(14, by) b1:SetSize(248, 32)
    b1.DoClick = function()
        local row = sel()
        if row and row._pos then N.SetWaypoint(row._pos, row._name, row._id) end
    end
    local b2 = grmBtn(fr, "СБРОСИТЬ МАРШРУТ", Color(78, 58, 22))
    b2:SetPos(14, by + 36) b2:SetSize(248, 30)
    b2.DoClick = N.ClearWaypoint
    local b3 = grmBtn(fr, "УДАЛИТЬ МЕТКУ", Color(118, 34, 38))
    b3:SetPos(14, by + 70) b3:SetSize(248, 32)
    b3.DoClick = function()
        local row = sel()
        if not row or not row._id then notification.AddLegacy("Выбери метку.", NOTIFY_ERROR, 3) return end
        if (row._src == "gps" or row._src == "admin") and not LocalPlayer():IsSuperAdmin() then
            notification.AddLegacy("GPS снимает администратор.", NOTIFY_ERROR, 3)
            return
        end
        N.DeleteMark(row._id, row._src)
        timer.Simple(0.25, refill)
    end
    local b4 = grmBtn(fr, "КО МНЕ", Color(28, 52, 82))
    b4:SetPos(14, by + 106) b4:SetSize(248, 28)
    b4.DoClick = function()
        if IsValid(LocalPlayer()) then
            local q = LocalPlayer():GetPos()
            N._atlasCam.x, N._atlasCam.y = q.x, q.y
        end
    end
    gui.EnableScreenClicker(true)
end

hook.Add("HUDPaint", "GRM_Nav_AtlasHUD", function()
    if not N._open then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    local x, y = 12, 12
    local w, h = ScrW() - 276 - 28, ScrH() - 24
    draw.RoundedBox(8, x, y, w, h, Color(8, 14, 23, 230))
    surface.SetDrawColor(COL.line)
    surface.DrawOutlinedRect(x, y, w, h, 1)
    render.SetScissorRect(x + 2, y + 2, x + w - 2, y + h - 2, true)
    if atlasLiveMat then
        surface.SetMaterial(atlasLiveMat)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(x + 3, y + 3, w - 6, h - 6)
    end
    local function toS(vec)
        local px, py = camToScreen(vec, x, y, w, h)
        return { x = px, y = py }
    end
    drawRoute(toS)
    if N.Opt.graph ~= false and (N.Nodes or N._mode == "graph") then
        local idPos = {}
        for _, n in ipairs(N.Nodes or {}) do
            idPos[n.id] = toS(Vector(n.x, n.y, n.z or 0))
        end
        surface.SetDrawColor(90, 200, 255, 160)
        for _, e in ipairs(N.Edges or {}) do
            local a, b = idPos[e.a], idPos[e.b]
            if a and b then surface.DrawLine(a.x, a.y, b.x, b.y) end
        end
        for _, n in ipairs(N.Nodes or {}) do
            local p = idPos[n.id]
            if p then
                surface.SetDrawColor(30, 160, 220, 230)
                surface.DrawRect(p.x - 3, p.y - 3, 6, 6)
            end
        end
    end
    for _, b in ipairs(collectBlips()) do
        local pt = toS(b.pos)
        drawBlip(pt.x, pt.y, kindCol(b.kind), b.name, true)
    end
    if N.Opt.players ~= false then
        eachPlayer(function(pl)
            local pt = toS(pl:GetPos())
            drawPlayerDot(pt.x, pt.y, plyNick(pl), pl == lp, true)
        end)
    end
    render.SetScissorRect(0, 0, 0, 0, false)
    local zoomTxt = string.format("зум %d м", math.floor(N._atlasCam.z or 0))
    draw.SimpleText("колёсико зум  ·  ЛКМ тяни / точка  ·  режим справа  ·  " .. zoomTxt, "GRMNav_Tiny", x + 12, y + h - 18, COL.dim)
end)

local drag
hook.Add("GUIMousePressed", "GRM_Nav_AtlasClick", function(code)
    if not N._open then return end
    local mx, my = gui.MousePos()
    local x, y, w, h = 12, 12, ScrW() - 276 - 28, ScrH() - 24
    if mx < x or my < y or mx > x + w or my > y + h then return end
    if code == MOUSE_LEFT then
        drag = { x = mx, y = my, cx = N._atlasCam.x, cy = N._atlasCam.y }
        local world = screenToCam(mx, my, x, y, w, h)
        if N._mode == "graph" and LocalPlayer():IsSuperAdmin() then
            local hitN
            for _, n in ipairs(N.Nodes or {}) do
                local px, py = camToScreen(Vector(n.x, n.y, n.z or 0), x, y, w, h)
                if math.abs(px - mx) < 12 and math.abs(py - my) < 12 then hitN = n break end
            end
            if hitN and N._lastNode and N._lastNode ~= hitN.id then
                net.Start("GRM_Nav_Act") net.WriteString("glink") net.WriteString(N._lastNode) net.WriteString(hitN.id) net.SendToServer()
                N._lastNode = hitN.id
            elseif hitN then
                N._lastNode = hitN.id
            else
                net.Start("GRM_Nav_Act")
                    net.WriteString("gadd")
                    net.WriteFloat(world.x) net.WriteFloat(world.y) net.WriteFloat(world.z)
                    net.WriteString(N._lastNode or "")
                net.SendToServer()
            end
            return true
        end
        if N._mode == "sign" and LocalPlayer():IsSuperAdmin() then
            net.Start("GRM_Nav_Act")
                net.WriteString("add")
                net.WriteString(N._signName or "")
                net.WriteString(N._signKind or "pin")
                net.WriteBool(N._signPin ~= false)
                net.WriteFloat(world.x) net.WriteFloat(world.y) net.WriteFloat(world.z)
            net.SendToServer()
            return true
        end
        if N._mode == "gps" and LocalPlayer():IsSuperAdmin() then
            net.Start("GRM_Minimap_Action")
                net.WriteString("add_point_at")
                net.WriteString(N._signName ~= "" and N._signName or "GPS")
                net.WriteUInt(180, 16)
                net.WriteFloat(world.x) net.WriteFloat(world.y) net.WriteFloat(world.z)
            net.SendToServer()
            return true
        end
        local hit
        for _, b in ipairs(collectBlips()) do
            local px, py = camToScreen(b.pos, x, y, w, h)
            if math.abs(px - mx) < 14 and math.abs(py - my) < 14 then hit = b break end
        end
        if hit then N.SetWaypoint(hit.pos, hit.name, hit.id)
        else N._clickAt = { t = CurTime(), w = world } end
        return true
    elseif code == MOUSE_RIGHT then
        if N._mode == "graph" and LocalPlayer():IsSuperAdmin() then
            local hitN
            for _, n in ipairs(N.Nodes or {}) do
                local px, py = camToScreen(Vector(n.x, n.y, n.z or 0), x, y, w, h)
                if math.abs(px - mx) < 12 and math.abs(py - my) < 12 then hitN = n break end
            end
            if hitN then
                net.Start("GRM_Nav_Act") net.WriteString("gdel") net.WriteString(hitN.id) net.SendToServer()
                if N._lastNode == hitN.id then N._lastNode = nil end
            else
                N._lastNode = nil
            end
            return true
        end
        if not LocalPlayer():IsSuperAdmin() then return end
        local world = screenToCam(mx, my, x, y, w, h)
        net.Start("GRM_Nav_Act")
            net.WriteString("add")
            net.WriteString(N._signName or "")
            net.WriteString(N._signKind or "pin")
            net.WriteBool(N._signPin ~= false)
            net.WriteFloat(world.x) net.WriteFloat(world.y) net.WriteFloat(world.z)
        net.SendToServer()
        return true
    end
end)

hook.Add("GUIMouseReleased", "GRM_Nav_AtlasRel", function(code)
    if not N._open then return end
    if code == MOUSE_LEFT and N._clickAt and CurTime() - N._clickAt.t < 0.22 then
        local world = N._clickAt.w
        if GRM.Minimap and GRM.Minimap.AddPersonal then
            local p = GRM.Minimap.AddPersonal("Точка", world)
            N.SetWaypoint(world, "Точка", p.id)
        else
            N.SetWaypoint(world, "Точка")
        end
    end
    drag, N._clickAt = nil, nil
end)

hook.Add("Think", "GRM_Nav_AtlasDrag", function()
    if not N._open or not drag then return end
    if not input.IsMouseDown(MOUSE_LEFT) then drag = nil return end
    local mx, my = gui.MousePos()
    local half = math.tan(math.rad(31)) * (N._atlasCam.z or 2200)
    local w = ScrW() - 276 - 28
    N._atlasCam.x = drag.cx - (mx - drag.x) / w * half * 2
    N._atlasCam.y = drag.cy + (my - drag.y) / (ScrH() - 24) * half * 2
end)

hook.Add("PlayerBindPress", "GRM_Nav_AtlasWheel", function(ply, bind, pressed)
    if not N._open or not pressed then return end
    if bind == "invnext" then
        N._atlasCam.z = math.Clamp((N._atlasCam.z or 2000) + 280, 900, 7000)
        return true
    end
    if bind == "invprev" then
        N._atlasCam.z = math.Clamp((N._atlasCam.z or 2000) - 280, 900, 7000)
        return true
    end
end)

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
    if N._open then N.CloseAtlas() else N.OpenAtlas() end
end)

hook.Add("PlayerSayTransform", "GRM_Nav_Chat", function(ply, pack)
    if ply ~= LocalPlayer() then return end
    local t = string.lower(string.Trim(pack and pack[1] or ""))
    if t == "/карта" or t == "/map" or t == "/atlas" then N.OpenAtlas() pack[1] = "" return true end
    if t == "/миникарта" or t == "/minimap" then N.Visible = not N.Visible pack[1] = "" return true end
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
