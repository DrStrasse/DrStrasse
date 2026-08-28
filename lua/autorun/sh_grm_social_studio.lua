--[[ Студия соц.анимаций: гизмо костей, T-pose/sequence, сейв, доступ игрокам.
     Не PAC3: свой слой, без копирования аддона. ]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Social = GRM.Social or {}
local S = GRM.Social
S.StudioFile = "grm_social_poses.json"

local function jsonT(txt)
    local ok, t = pcall(util.JSONToTable, txt, false, true)
    return (ok and istable(t)) and t or nil
end

local function slug(s)
    s = string.lower(string.Trim(tostring(s or "")))
    s = string.gsub(s, "[^%w_%-]+", "_")
    if s == "" then s = "pose_" .. tostring(os.time() % 100000) end
    return string.sub(s, 1, 32)
end

if SERVER then
    util.AddNetworkString("GRM_SocStudio_Open")
    util.AddNetworkString("GRM_SocStudio_Sync")
    util.AddNetworkString("GRM_SocStudio_Act")

    S.Catalog = S.Catalog or {}

    function S.LoadCatalog()
        if not file.Exists(S.StudioFile, "DATA") then
            S.Catalog = {}
            S.CatList = { { id = "general", name = "Общее" }, { id = "docs", name = "Документы" } }
            return
        end
        local t = jsonT(file.Read(S.StudioFile, "DATA") or "")
        if istable(t) and istable(t.poses) then
            S.Catalog = t.poses
            S.CatList = istable(t.cats) and t.cats or {}
        else
            S.Catalog = istable(t) and t or {}
            S.CatList = {}
        end
        if #(S.CatList or {}) == 0 then
            S.CatList = { { id = "general", name = "Общее" }, { id = "docs", name = "Документы" } }
        end
        if S.ApplyCatalog then S.ApplyCatalog(S.Catalog, S.CatList) end
    end

    function S.SaveCatalog()
        local fn = function()
            local ok, txt = pcall(util.TableToJSON, { poses = S.Catalog or {}, cats = S.CatList or {} }, false)
            if ok and txt then file.Write(S.StudioFile, txt) end
        end
        if GRM.Perf and GRM.Perf.Coalesce then GRM.Perf.Coalesce("grm_socstudio_save", 0.4, fn) else fn() end
    end

    function S.SyncCatalog(ply)
        net.Start("GRM_SocStudio_Sync")
        net.WriteTable({ poses = S.Catalog or {}, cats = S.CatList or {} })
        if IsValid(ply) then net.Send(ply) else net.Broadcast() end
    end

    local function admin(ply)
        return IsValid(ply) and ply:IsSuperAdmin()
    end

    local function setFreeze(ply, on, stance, seq)
        if not IsValid(ply) then return end
        ply._grmSocStudio = on and true or nil
        ply:SetNWBool("GRM_SocStudio", on == true)
        ply:SetNWString("GRM_SocStance", on and (stance or "tpose") or "")
        ply:SetNWString("GRM_SocSeq", on and (seq or "") or "")
        if ply.Freeze then ply:Freeze(on == true) end
        if not on then
            ply:SetNWString("GRM_SocAnim", "")
        end
    end

    function S.StudioOpen(ply)
        if not admin(ply) then return end
        S.LoadCatalog()
        setFreeze(ply, true, "tpose", "")
        S.SyncCatalog(ply)
        net.Start("GRM_SocStudio_Open")
        net.Send(ply)
    end

    net.Receive("GRM_SocStudio_Act", function(_, ply)
        if not admin(ply) then return end
        if GRM.Perf and GRM.Perf.Throttle and not GRM.Perf.Throttle("socstudio." .. ply:EntIndex(), 0.05) then return end
        local op = string.sub(tostring(net.ReadString() or ""), 1, 16)
        if op == "close" then
            setFreeze(ply, false)
            return
        end
        if op == "ping" then
            ply._grmSocStudio = true
            return
        end
        if op == "stance" then
            local st = string.sub(net.ReadString() or "tpose", 1, 16)
            ply:SetNWString("GRM_SocStance", st)
            return
        end
        if op == "seq" then
            ply:SetNWString("GRM_SocSeq", string.sub(net.ReadString() or "", 1, 64))
            return
        end
        if op == "save" then
            local rec = net.ReadTable() or {}
            rec.id = slug(rec.id or rec.name)
            rec.name = string.sub(string.Trim(tostring(rec.name or rec.id)), 1, 48)
            rec.players = rec.players ~= false
            rec.crouch = rec.crouch == true
            rec.walk = rec.walk ~= false
            rec.hold = rec.hold ~= false
            rec.stance = tostring(rec.stance or "idle")
            rec.sequence = tostring(rec.sequence or "")
            rec.bones = istable(rec.bones) and rec.bones or {}
            rec.prop = tostring(rec.prop or "")
            rec.freeze = rec.freeze == true
            rec.nomove = rec.nomove == true
            rec.cat = slug(rec.cat or rec.catName or "general")
            rec.catName = string.sub(string.Trim(tostring(rec.catName or rec.cat)), 1, 32)
            S.CatList = S.CatList or {}
            local haveCat
            for i = 1, #S.CatList do
                if S.CatList[i].id == rec.cat then
                    if rec.catName ~= "" then S.CatList[i].name = rec.catName end
                    haveCat = true
                    break
                end
            end
            if not haveCat then
                S.CatList[#S.CatList + 1] = { id = rec.cat, name = rec.catName ~= "" and rec.catName or rec.cat }
            end
            local found
            for i = 1, #(S.Catalog or {}) do
                if S.Catalog[i].id == rec.id then S.Catalog[i] = rec found = true break end
            end
            if not found then
                S.Catalog = S.Catalog or {}
                S.Catalog[#S.Catalog + 1] = rec
            end
            S.SaveCatalog()
            if S.ApplyCatalog then S.ApplyCatalog(S.Catalog) end
            S.SyncCatalog()
            if GRM.Notify then GRM.Notify(ply, "Поза сохранена: " .. rec.name, 120, 210, 140) end
            return
        end
        if op == "delete" then
            local id = slug(net.ReadString())
            for i = #(S.Catalog or {}), 1, -1 do
                if S.Catalog[i].id == id then table.remove(S.Catalog, i) end
            end
            S.SaveCatalog()
            S.SyncCatalog()
            return
        end
        if op == "addcat" then
            local name = string.sub(string.Trim(tostring(net.ReadString() or "")), 1, 32)
            if name == "" then return end
            local id = slug(name)
            S.CatList = S.CatList or {}
            for i = 1, #S.CatList do if S.CatList[i].id == id then return end end
            S.CatList[#S.CatList + 1] = { id = id, name = name }
            S.SaveCatalog()
            S.SyncCatalog()
            return
        end
        if op == "delcat" then
            local id = slug(net.ReadString())
            if id == "general" then return end
            S.CatList = S.CatList or {}
            for i = #S.CatList, 1, -1 do if S.CatList[i].id == id then table.remove(S.CatList, i) end end
            -- позы удалённой категории уходят в «Общее»
            for _, p in ipairs(S.Catalog or {}) do
                if p.cat == id then p.cat, p.catName = "general", "Общее" end
            end
            if #S.CatList == 0 then S.CatList = { { id = "general", name = "Общее" } } end
            S.SaveCatalog()
            S.SyncCatalog()
            return
        end
        if op == "renamecat" then
            local id = slug(net.ReadString())
            local name = string.sub(string.Trim(tostring(net.ReadString() or "")), 1, 32)
            if name == "" then return end
            for i = 1, #(S.CatList or {}) do
                if S.CatList[i].id == id then
                    S.CatList[i].name = name
                    for _, p in ipairs(S.Catalog or {}) do if p.cat == id then p.catName = name end end
                    break
                end
            end
            S.SaveCatalog()
            S.SyncCatalog()
            return
        end
        if op == "movepose" then
            local id = slug(net.ReadString())
            local toCat = slug(net.ReadString())
            local catName = ""
            for i = 1, #(S.CatList or {}) do
                if S.CatList[i].id == toCat then catName = S.CatList[i].name break end
            end
            if catName == "" then return end
            for _, p in ipairs(S.Catalog or {}) do
                if p.id == id then p.cat, p.catName = toCat, catName break end
            end
            S.SaveCatalog()
            S.SyncCatalog()
            return
        end
    end)

    hook.Add("CalcMainActivity", "GRM_SocStudio_Act", function(ply)
        if not IsValid(ply) or not ply:GetNWBool("GRM_SocStudio") then return end
        local st = ply:GetNWString("GRM_SocStance", "tpose")
        local named = ply:GetNWString("GRM_SocSeq", "")
        if named ~= "" and ply.LookupSequence then
            local seq = ply:LookupSequence(named)
            if seq and seq >= 0 then return ACT_INVALID, seq end
        end
        if st == "crouch" then return ACT_HL2MP_IDLE_CROUCH, -1 end
        if st == "idle" then return ACT_HL2MP_IDLE, -1 end
        if ply.LookupSequence then
            local seq = ply:LookupSequence("reference")
            if not seq or seq < 0 then seq = ply:LookupSequence("ragdoll") end
            if seq and seq >= 0 then return ACT_INVALID, seq end
        end
        return ACT_HL2MP_IDLE, -1
    end)

    hook.Add("StartCommand", "GRM_SocStudio_Hold", function(ply, cmd)
        if not IsValid(ply) or not ply:GetNWBool("GRM_SocStudio") then return end
        cmd:ClearMovement()
        cmd:RemoveKey(IN_JUMP)
        cmd:RemoveKey(IN_ATTACK)
        cmd:RemoveKey(IN_ATTACK2)
    end)

    hook.Add("PlayerDeath", "GRM_SocStudio_Death", function(ply) setFreeze(ply, false) end)
    hook.Add("PlayerDisconnected", "GRM_SocStudio_Disc", function(ply) setFreeze(ply, false) end)

    hook.Add("PlayerSay", "GRM_SocStudio_Chat", function(ply, text)
        local t = string.lower(string.Trim(tostring(text or "")))
        if t == "/animstudio" or t == "/анимстудия" or t == "/posedit" then
            S.StudioOpen(ply)
            return ""
        end
    end)

    hook.Add("PlayerInitialSpawn", "GRM_SocStudio_Join", function(ply)
        timer.Simple(3, function() if IsValid(ply) then S.SyncCatalog(ply) end end)
    end)

    concommand.Add("grm_anim_studio", function(ply)
        if IsValid(ply) then S.StudioOpen(ply) end
    end)

    S.LoadCatalog()
    print("[GRM Social Studio] server")
    return
end

-----------------------------------------------------------------------
-- CLIENT
-----------------------------------------------------------------------
surface.CreateFont("GRMSocEd_H", { font = "Roboto", size = 16, weight = 800, extended = true })
surface.CreateFont("GRMSocEd_B", { font = "Roboto", size = 13, weight = 500, extended = true })

local ST = { on = false, yaw = 160, pitch = 6, dist = 90, bone = "ValveBiped.Bip01_R_UpperArm", bones = {}, mode = "rotate" }

net.Receive("GRM_SocStudio_Sync", function()
    local payload = net.ReadTable() or {}
    local poses = istable(payload.poses) and payload.poses or (istable(payload) and payload or {})
    local cats  = istable(payload.cats)  and payload.cats  or {}
    if #cats == 0 then cats = { { id = "general", name = "Общее" }, { id = "docs", name = "Документы" } } end
    ST.catalog = poses
    ST.cats = cats
    if GRM.Social and GRM.Social.ApplyCatalog then GRM.Social.ApplyCatalog(poses, cats) end
    if ST.rebuildCats then ST.rebuildCats() end
    if ST.rebuildList then ST.rebuildList() end
end)

--[[ БАГ (найден 28.08). Функция принимала РОВНО ОДИН аргумент, а
     «Переместить в…» вызывает её с двумя: sendAct("movepose", id, cat).
     Второй молча терялся, сервер читал пустую строку вместо категории,
     не находил её в списке и выходил по `if catName == "" then return end`.
     Перемещение поз не работало вообще и делало это тихо.

     Теперь принимаем произвольное число аргументов. Таблица по-прежнему
     уходит как таблица, остальное — строками, в том же порядке, в каком
     их читает сервер. ]]
local function sendAct(op, ...)
    net.Start("GRM_SocStudio_Act")
    net.WriteString(op)
    local n = select("#", ...)
    for i = 1, n do
        local extra = select(i, ...)
        if extra ~= nil then
            if istable(extra) then net.WriteTable(extra)
            else net.WriteString(tostring(extra)) end
        end
    end
    net.SendToServer()
end

local function boneNames(ply)
    local out = {}
    if not IsValid(ply) or not ply.GetBoneCount then return out end
    for i = 0, (ply:GetBoneCount() or 1) - 1 do
        local n = ply:GetBoneName(i)
        if n and n ~= "" and n ~= "__INVALIDBONE__" then out[#out + 1] = n end
    end
    table.sort(out)
    return out
end

local function recOf(name)
    ST.bones[name] = ST.bones[name] or { p = 0, yaw = 0, r = 0, px = 0, py = 0, pz = 0 }
    return ST.bones[name]
end

local function applyLocal()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    for i = 0, (lp:GetBoneCount() or 1) - 1 do
        lp:ManipulateBoneAngles(i, Angle(0, 0, 0))
        lp:ManipulateBonePosition(i, Vector(0, 0, 0))
    end
    for name, rec in pairs(ST.bones) do
        local b = lp:LookupBone(name)
        if b then
            lp:ManipulateBoneAngles(b, Angle(rec.p or 0, rec.yaw or 0, rec.r or 0))
            lp:ManipulateBonePosition(b, Vector(rec.px or 0, rec.py or 0, rec.pz or 0))
        end
    end
end

local function boneWorld()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    local idx = lp:LookupBone(ST.bone)
    if not idx then return end
    local mtx = lp:GetBoneMatrix(idx)
    if not mtx then return end
    return mtx:GetTranslation(), mtx:GetAngles()
end

local AX = {
    x = { c = Color(230, 70, 70), v = function(a) return a:Forward() end },
    y = { c = Color(70, 200, 90), v = function(a) return a:Right() end },
    z = { c = Color(70, 140, 240), v = function(a) return a:Up() end },
}

local function gizmoLen(o)
    return math.Clamp(EyePos():Distance(o) * 0.055, 12, 32)
end

local function rotBasis(axis, ang)
    if axis == "x" then return ang:Right(), ang:Up() end
    if axis == "y" then return ang:Forward(), ang:Up() end
    return ang:Forward(), ang:Right()
end

local function ringPt(o, ang, axis, rad, r)
    local a, b = rotBasis(axis, ang)
    return o + a * math.cos(rad) * r + b * math.sin(rad) * r
end

local function pickGizmo(mx, my)
    local o, ang = boneWorld()
    if not o then return end
    local os = o:ToScreen()
    if not os or os.visible == false then return end
    local best, bd, bdx, bdy
    local len = gizmoLen(o)
    if ST.mode == "rotate" then
        for axis in pairs(AX) do
            local prev = ringPt(o, ang, axis, 0, len):ToScreen()
            for i = 1, 48 do
                local cur = ringPt(o, ang, axis, math.pi * 2 * i / 48, len):ToScreen()
                local dx, dy = cur.x - prev.x, cur.y - prev.y
                local l2 = dx * dx + dy * dy
                if l2 > 1 then
                    local t = math.Clamp(((mx - prev.x) * dx + (my - prev.y) * dy) / l2, 0, 1)
                    local px, py = prev.x + dx * t, prev.y + dy * t
                    local d = math.sqrt((mx - px) ^ 2 + (my - py) ^ 2)
                    if d <= 12 and (not bd or d < bd) then
                        local l = math.sqrt(l2)
                        best, bd, bdx, bdy = axis, d, dx / l, dy / l
                    end
                end
                prev = cur
            end
        end
    else
        for axis, data in pairs(AX) do
            local es = (o + data.v(ang) * len):ToScreen()
            local dx, dy = es.x - os.x, es.y - os.y
            local l2 = dx * dx + dy * dy
            if l2 > 4 then
                local t = math.Clamp(((mx - os.x) * dx + (my - os.y) * dy) / l2, 0, 1)
                local px, py = os.x + dx * t, os.y + dy * t
                local d = math.sqrt((mx - px) ^ 2 + (my - py) ^ 2)
                if d <= 14 and (not bd or d < bd) then
                    local l = math.sqrt(l2)
                    best, bd, bdx, bdy = axis, d, dx / l, dy / l
                end
            end
        end
    end
    return best, bdx, bdy
end

hook.Add("PostDrawTranslucentRenderables", "GRM_SocStudio_Gizmo", function(depth, sky)
    if not ST.on or depth or sky then return end
    local o, a = boneWorld()
    if not o then return end
    render.SetColorMaterial()
    render.DrawWireframeSphere(o, 1.6, 8, 8, Color(255, 240, 180), false)
    local len = gizmoLen(o)
    if ST.mode == "rotate" then
        for axis, d in pairs(AX) do
            local prev = ringPt(o, a, axis, 0, len)
            for i = 1, 48 do
                local cur = ringPt(o, a, axis, math.pi * 2 * i / 48, len)
                render.DrawLine(prev, cur, d.c, false)
                prev = cur
            end
        end
    else
        for _, d in pairs(AX) do
            local e = o + d.v(a) * len
            render.DrawLine(o, e, d.c, false)
            render.DrawWireframeSphere(e, 1.2, 6, 6, d.c, false)
        end
    end
end)

hook.Add("CalcView", "GRM_SocStudio_Cam", function(ply)
    if not ST.on or ply ~= LocalPlayer() then return end
    local tgt = ply:GetPos() + Vector(0, 0, 40)
    local ang = Angle(ST.pitch, ST.yaw, 0)
    local want = tgt - ang:Forward() * ST.dist
    local tr = util.TraceHull({ start = tgt, endpos = want, filter = ply, mins = Vector(-4, -4, -4), maxs = Vector(4, 4, 4) })
    return { origin = tr.HitPos, angles = (tgt - tr.HitPos):Angle(), fov = 50, drawviewer = true }
end)
hook.Add("ShouldDrawLocalPlayer", "GRM_SocStudio_DrawMe", function()
    if ST.on then return true end
end)
hook.Add("CalcMainActivity", "GRM_SocStudio_ActCl", function(ply)
    if not ST.on or ply ~= LocalPlayer() then return end
    local st = ply:GetNWString("GRM_SocStance", "tpose")
    local named = ply:GetNWString("GRM_SocSeq", "")
    if named ~= "" then
        local seq = ply:LookupSequence(named)
        if seq and seq >= 0 then return ACT_INVALID, seq end
    end
    if st == "crouch" then return ACT_HL2MP_IDLE_CROUCH, -1 end
    if st == "idle" then return ACT_HL2MP_IDLE, -1 end
    local seq = ply:LookupSequence("reference")
    if not seq or seq < 0 then seq = ply:LookupSequence("ragdoll") end
    if seq and seq >= 0 then return ACT_INVALID, seq end
end)

local function closeStudio()
    if not ST.on then return end
    ST.on = false
    sendAct("close")
    if IsValid(ST.frame) then ST.frame:Remove() end
    ST.frame = nil
    local lp = LocalPlayer()
    if IsValid(lp) then
        for i = 0, (lp:GetBoneCount() or 1) - 1 do
            lp:ManipulateBoneAngles(i, Angle(0, 0, 0))
            lp:ManipulateBonePosition(i, Vector(0, 0, 0))
        end
    end
end

local function openStudio()
    if IsValid(ST.frame) then ST.frame:Remove() end
    ST.on = true
    ST.bones = {}
    local lp = LocalPlayer()
    local names = boneNames(lp)
    ST.bone = names[1] or ST.bone

    local f = vgui.Create("DFrame")
    ST.frame = f
    f:SetSize(ScrW(), ScrH())
    f:SetPos(0, 0)
    f:SetTitle("")
    f:ShowCloseButton(false)
    f:MakePopup()
    f.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, 48, Color(14, 18, 26, 250))
        draw.SimpleText("СТУДИЯ СОЦ. АНИМАЦИЙ", "GRMSocEd_H", 18, 24, Color(245, 195, 65), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("ЛКМ по панели — орбита  ·  слайдеры/гизмо — кости  ·  суперадмин", "GRMSocEd_B", w / 2, 24, Color(160, 175, 190), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    f.OnRemove = function() if ST.on then closeStudio() end end

    local view = vgui.Create("DPanel", f)
    view:SetPos(300, 56)
    view:SetSize(ScrW() - 640, ScrH() - 70)
    view:SetPaintBackground(false)
    view.OnMousePressed = function(s, key)
        if key ~= MOUSE_LEFT then return end
        local mx, my = gui.MousePos()
        local axis, dx, dy = pickGizmo(mx, my)
        if axis then
            local rec = recOf(ST.bone)
            ST.gzAxis, ST.gzDX, ST.gzDY = axis, dx, dy
            ST.gzX, ST.gzY = mx, my
            if ST.mode == "rotate" then
                ST.gzVal = (axis == "x" and rec.p) or (axis == "y" and rec.yaw) or rec.r
            else
                ST.gzVal = (axis == "x" and rec.px) or (axis == "y" and rec.py) or rec.pz
            end
        else
            s.drag = true
            s.lx, s.ly = mx, my
        end
        s:MouseCapture(true)
    end
    view.OnMouseReleased = function(s)
        s.drag = false
        ST.gzAxis = nil
        s:MouseCapture(false)
        if ST.refreshSliders then ST.refreshSliders() end
    end
    view.OnCursorMoved = function(s)
        local mx, my = gui.MousePos()
        if ST.gzAxis then
            local rec = recOf(ST.bone)
            local proj = (mx - (ST.gzX or mx)) * (ST.gzDX or 0) + (my - (ST.gzY or my)) * (ST.gzDY or 0)
            if ST.mode == "rotate" then
                local v = math.NormalizeAngle((ST.gzVal or 0) + proj * 0.45)
                if ST.gzAxis == "x" then rec.p = v
                elseif ST.gzAxis == "y" then rec.yaw = v
                else rec.r = v end
            else
                local v = math.Clamp((ST.gzVal or 0) + proj * 0.04, -20, 20)
                if ST.gzAxis == "x" then rec.px = v
                elseif ST.gzAxis == "y" then rec.py = v
                else rec.pz = v end
            end
            applyLocal()
            if ST.refreshSliders then ST.refreshSliders() end
            return
        end
        if not s.drag then return end
        ST.yaw = ST.yaw - (mx - (s.lx or mx)) * 0.35
        ST.pitch = math.Clamp(ST.pitch + (my - (s.ly or my)) * 0.25, -30, 50)
        s.lx, s.ly = mx, my
    end
    view.OnMouseWheeled = function(_, d)
        ST.dist = math.Clamp(ST.dist - d * 8, 50, 220)
        return true
    end

    local left = vgui.Create("DPanel", f)
    left:SetPos(10, 56)
    left:SetSize(280, ScrH() - 70)
    left.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(20, 26, 36, 248))
    end
    local right = vgui.Create("DPanel", f)
    right:SetPos(ScrW() - 330, 56)
    right:SetSize(320, ScrH() - 70)
    right.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(20, 26, 36, 248))
    end

    local idE = vgui.Create("DTextEntry", left)
    idE:SetPos(10, 10) idE:SetSize(120, 24) idE:SetPlaceholderText("id")
    local nameE = vgui.Create("DTextEntry", left)
    nameE:SetPos(136, 10) nameE:SetSize(134, 24) nameE:SetPlaceholderText("название")

    local chkP = vgui.Create("DCheckBoxLabel", left)
    chkP:SetPos(10, 40) chkP:SetText("Игрокам") chkP:SetValue(1) chkP:SetTextColor(color_white)
    local chkC = vgui.Create("DCheckBoxLabel", left)
    chkC:SetPos(110, 40) chkC:SetText("Присед") chkC:SetTextColor(color_white)
    local chkW = vgui.Create("DCheckBoxLabel", left)
    chkW:SetPos(200, 40) chkW:SetText("Ходьба") chkW:SetValue(1) chkW:SetTextColor(color_white)

    -- «Заморозка»: при проигрывании этой анимации игрок не может двигаться.
    local chkFreeze = vgui.Create("DCheckBoxLabel", left)
    chkFreeze:SetPos(10, 58) chkFreeze:SetText("Заморозить при проигрывании") chkFreeze:SetValue(0)
    chkFreeze:SetTextColor(color_white) chkFreeze:SetTooltip("Игрок не сможет двигаться, пока активна эта анимация (можно крутить камерой)")

    local catBox = vgui.Create("DComboBox", left)
    catBox:SetPos(10, 86) catBox:SetSize(168, 24)
    catBox:SetValue("Общее")
    catBox.OnSelect = function() if ST.rebuildList then ST.rebuildList() end end
    function ST.rebuildCats()
        if not IsValid(catBox) then return end
        local keep = catBox:GetOptionData(catBox:GetSelectedID() or 0) or "general"
        catBox:Clear()
        -- 0 = все категории
        catBox:AddChoice("Все категории", "all", keep == "all")
        local cats = ST.cats or (GRM.Social and GRM.Social.CatList) or {}
        if #cats == 0 then cats = { { id = "general", name = "Общее" } } end
        local sel = false
        for _, c in ipairs(cats) do
            local on = c.id == keep
            catBox:AddChoice(c.name or c.id, c.id, on)
            if on then sel = true end
        end
        if not sel then catBox:AddChoice("Общее", "general", true) end
    end
    ST.rebuildCats()
    local catNew = vgui.Create("DButton", left)
    catNew:SetPos(182, 86) catNew:SetSize(88, 24) catNew:SetText("")
    catNew.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(60, 150, 90) or Color(46, 110, 70))
        draw.SimpleText("+ КАТЕГОРИЯ", "GRMSocEd_B", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    catNew.DoClick = function()
        Derma_StringRequest("Новая категория", "Название категории поз", "", function(n)
            n = string.Trim(n or "")
            if n ~= "" then sendAct("addcat", n) end
        end)
    end

    local catDel = vgui.Create("DButton", left)
    catDel:SetPos(10, 144) catDel:SetSize(260, 20) catDel:SetText("")
    catDel.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(150, 60, 60) or Color(90, 50, 50))
        draw.SimpleText("Удалить текущую категорию", "GRMSocEd_B", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    catDel.DoClick = function()
        local id = IsValid(catBox) and catBox:GetOptionData(catBox:GetSelectedID()) or "general"
        if id == "general" then return end
        Derma_Query("Удалить категорию и перенести позы в «Общее»?", "Категория",
            "Удалить", function() sendAct("delcat", id) end, "Отмена", function() end)
    end

    local stance = vgui.Create("DComboBox", left)
    stance:SetPos(10, 114) stance:SetSize(126, 24)
    stance:AddChoice("T-pose", "tpose", true)
    stance:AddChoice("Стойка", "idle")
    stance:AddChoice("Присед", "crouch")
    stance.OnSelect = function(_, _, _, v) sendAct("stance", v or "tpose") end

    local seq = vgui.Create("DComboBox", left)
    seq:SetPos(142, 114) seq:SetSize(128, 24)
    seq:SetValue("sequence")
    seq:AddChoice("(нет)", "", true)
    if IsValid(lp) and lp.GetSequenceList then
        local seen = {}
        for _, n in ipairs(lp:GetSequenceList() or {}) do
            if not seen[n] then
                seen[n] = true
                seq:AddChoice(n, n)
            end
        end
    end
    seq.OnSelect = function(_, _, _, v) sendAct("seq", v or "") end

    local statusL = vgui.Create("DLabel", left)
    statusL:SetPos(10, 150) statusL:SetSize(260, 18)
    -- Шрифта GRMSocEd_Small в модуле нет: объявлены только _H и _B.
    statusL:SetFont("GRMSocEd_B") statusL:SetTextColor(Color(110, 200, 130))
    statusL:SetText("")
    function ST.setStatus(txt) if IsValid(statusL) then statusL:SetText(txt or "") end end

    local list = vgui.Create("DListView", left)
    list:SetPos(10, 170) list:SetSize(260, 118)
    list:AddColumn("Сохранённые позы")
    list:SetMultiSelect(false)
    --[[ STACK OVERFLOW (жалоба владельца 28.08).

         Была замкнутая цепочка вызовов:

           OnRowSelected → loadPose → catBox:ChooseOptionID
             → catBox.OnSelect → rebuildList → list:SelectItem
             → OnRowSelected → …

         То есть выбор строки в списке в итоге приводил к повторному
         выбору строки — и так до переполнения стека. Игра падала при
         обычном клике по сохранённой позе.

         Лечим флагом повторного входа: пока идёт перестроение списка или
         загрузка позы, обработчики выбора не запускают цепочку заново.
         Это надёжнее, чем расставлять «не вызывай меня» по одному месту:
         любой новый обработчик автоматически попадёт под защиту. ]]
    function ST.rebuildList()
        if not IsValid(list) then return end
        if ST._busy then return end
        ST._busy = true
        list:Clear()
        local keep = IsValid(catBox) and catBox:GetOptionData(catBox:GetSelectedID() or 0) or "all"
        local cats = ST.cats or {}
        local catNameOf = function(id)
            for _, c in ipairs(cats) do if c.id == id then return c.name end end
            return id
        end
        for _, p in ipairs(ST.catalog or {}) do
            if keep == "all" or (p.cat or "general") == keep then
                local cat = p.catName or p.cat or "общее"
                local line = list:AddLine((p.players ~= false and "● " or "○ ") .. (p.name or p.id) .. "  [" .. tostring(cat) .. "]")
                line._id = p.id
                line._cat = p.cat or "general"
                --[[ Подсветка ранее выбранной строки. SelectItem дёргает
                     OnRowSelected — под флагом ST._busy он не станет
                     заново грузить позу и крутить combobox. ]]
                if p.id == ST.selectedID then
                    list:SelectItem(line)
                end
            end
        end
        ST._busy = false
    end
    ST.rebuildList()

    --[[ ЛКМ — загрузить позу, ПКМ — меню.

         Обработчик один. Раньше их было ДВА (здесь и ниже, после
         loadPose): второй молча перезаписывал первый. Работал по факту
         только нижний, а этот вводил в заблуждение при чтении кода. ]]
    list.OnRowSelected = function(_, _, line)
        -- Идёт перестроение списка — это не клик игрока, а подсветка.
        if ST._busy then return end
        if line and line._id then
            ST.selectedID = line._id
            loadPose(line._id)
        end
    end
    -- контекстное меню позы: загрузить / переместить / удалить
    list.OnRowRightClick = function(_, _, line)
        if not (line and line._id) then return end
        local menu = DermaMenu()
        menu:AddOption("Загрузить", function() loadPose(line._id) end)
        local move = menu:AddSubMenu("Переместить в…")
        for _, c in ipairs(ST.cats or { { id = "general", name = "Общее" } }) do
            move:AddOption(c.name or c.id, function()
                sendAct("movepose", line._id, c.id)
            end)
        end
        menu:AddOption("Удалить", function()
            Derma_Query("Удалить позу «" .. tostring(line._id) .. "»?", "Удаление",
                "Удалить", function()
                    ST.selectedID = nil
                    sendAct("delete", line._id)
                    notification.AddLegacy("Поза удалена", NOTIFY_UNDO, 3)
                end, "Отмена", function() end)
        end)
        menu:Open()
    end

    local function loadPose(id)
        for _, p in ipairs(ST.catalog or {}) do
            if p.id == id then
                idE:SetText(p.id)
                nameE:SetText(p.name or "")
                chkP:SetValue(p.players ~= false)
                chkC:SetValue(p.crouch == true)
                chkW:SetValue(p.walk ~= false)
                if chkFreeze then chkFreeze:SetValue(p.freeze == true or p.nomove == true) end
                --[[ Переключаем combobox на категорию позы. ChooseOptionID
                     дёргает OnSelect, а тот перестраивает список — на этом
                     и замыкалась рекурсия. Под флагом цепочка обрывается:
                     список нам сейчас перестраивать не нужно, поза уже
                     выбрана. ]]
                if IsValid(catBox) then
                    local wasBusy = ST._busy
                    ST._busy = true
                    for i = 1, 48 do
                        local d = catBox:GetOptionData(i)
                        if not d then break end
                        if d == (p.cat or "general") then catBox:ChooseOptionID(i) break end
                    end
                    ST._busy = wasBusy
                end
                ST.selectedID = id
                if ST.setStatus then ST.setStatus("Загружено: " .. tostring(p.name or id)) end
                ST.bones = {}
                for bn, rec in pairs(p.bones or {}) do
                    if isangle(rec) then
                        ST.bones[bn] = { p = rec.p, yaw = rec.y, r = rec.r, px = 0, py = 0, pz = 0 }
                    else
                        ST.bones[bn] = {
                            p = rec.p or 0, yaw = rec.yaw or rec.y or 0, r = rec.r or 0,
                            px = rec.px or rec.x or 0, py = rec.py or 0, pz = rec.pz or rec.z or 0,
                        }
                    end
                end
                applyLocal()
                if ST.refreshSliders then ST.refreshSliders() end
                return
            end
        end
    end
    --[[ Здесь БЫЛ второй list.OnRowSelected, дословно повторявший тот,
         что объявлен выше. Он перезаписывал первый: два обработчика на
         одно событие — это гарантированная путаница при отладке.
         Оставлен один, с защитой от повторного входа. ]]

    local bonesc = vgui.Create("DScrollPanel", left)
    bonesc:SetPos(10, 296) bonesc:SetSize(260, ScrH() - 438)
    for _, n in ipairs(names) do
        local b = vgui.Create("DButton", bonesc)
        b:Dock(TOP) b:SetTall(20) b:DockMargin(0, 0, 0, 1)
        b:SetText(string.gsub(n, "ValveBiped.Bip01_", ""))
        b:SetTextColor(Color(235, 240, 248))
        b.DoClick = function()
            ST.bone = n
            if ST.refreshSliders then ST.refreshSliders() end
        end
        b.Paint = function(s, w, h)
            draw.RoundedBox(3, 0, 0, w, h, ST.bone == n and Color(65, 145, 235) or Color(32, 40, 54))
        end
    end

    local moveB = vgui.Create("DButton", right)
    moveB:SetPos(10, 8) moveB:SetSize(145, 26) moveB:SetText("ПЕРЕМЕЩЕНИЕ")
    moveB:SetTextColor(Color(240, 244, 250))
    local rotB = vgui.Create("DButton", right)
    rotB:SetPos(163, 8) rotB:SetSize(145, 26) rotB:SetText("ВРАЩЕНИЕ")
    rotB:SetTextColor(Color(240, 244, 250))
    local function paintMode(s, w, h, on, col)
        draw.RoundedBox(5, 0, 0, w, h, on and col or Color(40, 48, 62))
    end
    moveB.Paint = function(s, w, h) paintMode(s, w, h, ST.mode == "move", Color(65, 145, 235)) end
    rotB.Paint = function(s, w, h) paintMode(s, w, h, ST.mode == "rotate", Color(230, 150, 60)) end
    moveB.DoClick = function() ST.mode = "move" end
    rotB.DoClick = function() ST.mode = "rotate" end

    local sliders = {}
    local function addSl(y, label, key, mn, mx)
        local s = vgui.Create("DNumSlider", right)
        s:SetPos(8, y) s:SetSize(300, 28)
        s:SetText(label) s:SetMin(mn) s:SetMax(mx) s:SetDecimals(1)
        s:SetDark(false)
        if IsValid(s.Label) then
            s.Label:SetTextColor(Color(230, 236, 245))
            s.Label:SetFont("GRMSocEd_B")
        end
        if IsValid(s.TextArea) then
            s.TextArea:SetTextColor(Color(240, 244, 250))
        end
        s.OnValueChanged = function(_, v)
            local rec = recOf(ST.bone)
            rec[key] = tonumber(v) or 0
            applyLocal()
        end
        sliders[key] = s
        return y + 30
    end
    local yy = 42
    yy = addSl(yy, "Pitch", "p", -180, 180)
    yy = addSl(yy, "Yaw", "yaw", -180, 180)
    yy = addSl(yy, "Roll", "r", -180, 180)
    yy = addSl(yy, "Сдвиг X", "px", -20, 20)
    yy = addSl(yy, "Сдвиг Y", "py", -20, 20)
    yy = addSl(yy, "Сдвиг Z", "pz", -20, 20)

    function ST.refreshSliders()
        local rec = recOf(ST.bone)
        for k, s in pairs(sliders) do
            if IsValid(s) then s:SetValue(tonumber(rec[k]) or 0) end
        end
    end
    ST.refreshSliders()

    local function mk(txt, col, y, fn)
        local b = vgui.Create("DButton", right)
        b:SetPos(12, y) b:SetSize(296, 30) b:SetText(txt)
        b:SetTextColor(Color(245, 248, 252))
        b.Paint = function(s, w, h)
            draw.RoundedBox(5, 0, 0, w, h, s:IsHovered() and Color(col.r + 20, col.g + 20, col.b + 20) or col)
        end
        b.DoClick = fn
        return b
    end
    mk("СБРОСИТЬ КОСТЬ", Color(80, 90, 110), yy + 8, function()
        ST.bones[ST.bone] = { p = 0, yaw = 0, r = 0, px = 0, py = 0, pz = 0 }
        applyLocal()
        ST.refreshSliders()
    end)
    mk("СБРОСИТЬ ВСЕ КОСТИ", Color(90, 70, 70), yy + 44, function()
        ST.bones = {}
        applyLocal()
        ST.refreshSliders()
    end)
    mk("СОХРАНИТЬ ПОЗУ", Color(50, 150, 90), yy + 88, function()
        local catId = IsValid(catBox) and catBox:GetOptionData(catBox:GetSelectedID()) or "general"
        local catName = IsValid(catBox) and catBox:GetValue() or "Общее"
        sendAct("save", {
            id = idE:GetValue(),
            name = nameE:GetValue(),
            players = chkP:GetChecked(),
            crouch = chkC:GetChecked(),
            walk = chkW:GetChecked(),
            freeze = chkFreeze:GetChecked(),
            hold = true,
            stance = stance:GetOptionData(stance:GetSelectedID()) or "idle",
            sequence = seq:GetOptionData(seq:GetSelectedID()) or "",
            bones = ST.bones,
            cat = catId,
            catName = catName,
        })
        if ST.setStatus then ST.setStatus("Сохранено") end
    end)
    mk("УДАЛИТЬ ВЫБРАННУЮ", Color(180, 70, 70), yy + 124, function()
        local _, line = list:GetSelectedLine()
        if line and line._id then sendAct("delete", line._id) end
    end)
    mk("ЗАКРЫТЬ", Color(50, 55, 70), yy + 168, function() closeStudio() end)
end

net.Receive("GRM_SocStudio_Open", function() openStudio() end)

-- Клиентская команда для каталога админки / F4: серверный concommand
-- grm_anim_studio есть только на сервере, поэтому здесь открываем студией локально.
concommand.Add("grm_anim_studio", function()
    -- сначала просим сервер открыть студию (заморозка, синк каталога)
    net.Start("GRM_SocStudio_Act")
        net.WriteString("open")
    net.SendToServer()
    -- и открываем окно у себя
    openStudio()
end)
timer.Create("GRM_SocStudio_Ping", 2, 0, function()
    if ST.on then sendAct("ping") applyLocal() end
end)

print("[GRM Social Studio] client")
