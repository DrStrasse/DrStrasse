--[[ Соц.анимации: костные позы, радиальное меню, бинд F4, C-меню. ]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Social = GRM.Social or {}
local S = GRM.Social
S.Version = "1.1.0"
S.CatList = S.CatList or { { id = "general", name = "Общее" } }

-- Поза трубки: не в радиальном меню, ставит модуль телефона.
-- Локальное крепление к ValveBiped.Bip01_R_Hand (не мир, FollowBone).
S.PhoneHold = {
    pos = Vector(2.85, 1.15, 0.22),
    ang = Angle(12, 98, 88),
    scale = 1,
}
S.PhonePose = {
    id = "phone",
    bones = {
        ["ValveBiped.Bip01_R_UpperArm"] = Angle(22, -38, 22),
        ["ValveBiped.Bip01_R_Forearm"]  = Angle(-6, -52, 18),
        ["ValveBiped.Bip01_R_Hand"]     = Angle(-18, -6, 28),
        ["ValveBiped.Bip01_Head1"]      = Angle(4, -18, -10),
        ["ValveBiped.Bip01_Neck1"]      = Angle(0, -8, 0),
    },
}

S.List = {
    {
        id = "hands",
        name = "Руки вверх",
        cat = "general",
        hold = true,
        walk = true,
        bones = {
            ["ValveBiped.Bip01_R_UpperArm"] = Angle(-16, -28, -64),
            ["ValveBiped.Bip01_R_Forearm"]  = Angle(8, -22, 4),
            ["ValveBiped.Bip01_R_Hand"]     = Angle(0, 6, 8),
            ["ValveBiped.Bip01_L_UpperArm"] = Angle(16, -28, 64),
            ["ValveBiped.Bip01_L_Forearm"]  = Angle(-8, -22, -4),
            ["ValveBiped.Bip01_L_Hand"]     = Angle(0, 6, -8),
        },
    },
    {
        id = "back",
        name = "Руки за спиной",
        cat = "general",
        hold = true,
        walk = true,
        bones = {
            ["ValveBiped.Bip01_R_UpperArm"] = Angle(-8, -12, -88),
            ["ValveBiped.Bip01_R_Forearm"]  = Angle(6, -28, 8),
            ["ValveBiped.Bip01_R_Hand"]     = Angle(0, 4, 12),
            ["ValveBiped.Bip01_L_UpperArm"] = Angle(8, -12, 88),
            ["ValveBiped.Bip01_L_Forearm"]  = Angle(-6, -28, -8),
            ["ValveBiped.Bip01_L_Hand"]     = Angle(0, 4, -12),
        },
    },
    {
        id = "kneel",
        name = "Руки вверх, на коленях",
        cat = "general",
        hold = true,
        crouch = true,
        walk = false,
        bones = {
            ["ValveBiped.Bip01_R_UpperArm"] = Angle(-16, -28, -64),
            ["ValveBiped.Bip01_R_Forearm"]  = Angle(8, -22, 4),
            ["ValveBiped.Bip01_R_Hand"]     = Angle(0, 6, 8),
            ["ValveBiped.Bip01_L_UpperArm"] = Angle(16, -28, 64),
            ["ValveBiped.Bip01_L_Forearm"]  = Angle(-8, -22, -4),
            ["ValveBiped.Bip01_L_Hand"]     = Angle(0, 6, -8),
        },
    },
    {
        id = "docs",
        name = "Рассматривать документы",
        cat = "docs",
        hold = true,
        walk = true,
        prop = "models/props_lab/clipboard.mdl",
        bones = {
            ["ValveBiped.Bip01_R_UpperArm"] = Angle(28, -42, 18),
            ["ValveBiped.Bip01_R_Forearm"]  = Angle(-4, -62, 16),
            ["ValveBiped.Bip01_R_Hand"]     = Angle(-6, -18, 36),
            ["ValveBiped.Bip01_L_UpperArm"] = Angle(-16, -28, -18),
            ["ValveBiped.Bip01_L_Forearm"]  = Angle(8, -48, -10),
            ["ValveBiped.Bip01_L_Hand"]     = Angle(8, 8, -16),
            ["ValveBiped.Bip01_Head1"]      = Angle(2, -16, -8),
            ["ValveBiped.Bip01_Neck1"]      = Angle(0, -8, 0),
        },
    },
}

function S.ByID(id)
    id = tostring(id or "")
    for i = 1, #S.List do
        if S.List[i].id == id then return S.List[i] end
    end
    for i = 1, #(S.Catalog or {}) do
        if S.Catalog[i].id == id then return S.Catalog[i] end
    end
end

local ALL_BONES = {}
local function markBones(t)
    for name in pairs(t or {}) do ALL_BONES[name] = true end
end
function S.MarkAllBones()
    ALL_BONES = {}
    for i = 1, #S.List do markBones(S.List[i].bones) end
    markBones(S.PhonePose.bones)
end
S.MarkAllBones()

function S.BoneToAngle(rec)
    if isangle(rec) then return rec end
    if not istable(rec) then return Angle(0, 0, 0) end
    return Angle(tonumber(rec.p) or 0, tonumber(rec.yaw or rec.y) or 0, tonumber(rec.r) or 0)
end

function S.BoneToPos(rec)
    if not istable(rec) then return Vector(0, 0, 0) end
    return Vector(tonumber(rec.px or rec.x) or 0, tonumber(rec.py) or 0, tonumber(rec.pz or rec.z) or 0)
end

function S.CatName(id)
    id = tostring(id or "general")
    for i = 1, #(S.CatList or {}) do
        if S.CatList[i].id == id then return S.CatList[i].name or id end
    end
    if id == "docs" then return "Документы" end
    if id == "general" then return "Общее" end
    return id
end

function S.Categories()
    local seen, out = {}, {}
    for i = 1, #(S.CatList or {}) do
        local c = S.CatList[i]
        if istable(c) and c.id and not seen[c.id] then
            seen[c.id] = true
            out[#out + 1] = { id = c.id, name = c.name or c.id }
        end
    end
    for i = 1, #(S.List or {}) do
        local id = tostring(S.List[i].cat or "general")
        if id ~= "" and not seen[id] then
            seen[id] = true
            out[#out + 1] = { id = id, name = S.CatName(id) }
        end
    end
    if #out == 0 then out[1] = { id = "general", name = "Общее" } end
    return out
end

function S.InCat(cat)
    cat = tostring(cat or "general")
    local out = {}
    for i = 1, #(S.List or {}) do
        local p = S.List[i]
        if tostring(p.cat or "general") == cat then out[#out + 1] = p end
    end
    if #out == 0 and cat == "general" then
        for i = 1, #(S.List or {}) do out[#out + 1] = S.List[i] end
    end
    return out
end

function S.ApplyCatalog(list, cats)
    if istable(list) and list.poses then
        cats = list.cats or cats
        list = list.poses
    end
    if istable(cats) then S.CatList = cats end
    if not istable(list) then return end
    S.Catalog = list
    local out = {}
    for i = 1, #list do
        local p = list[i]
        if istable(p) and p.players ~= false and p.id then
            p.cat = tostring(p.cat or "general")
            out[#out + 1] = p
        end
    end
    if #out > 0 then S.List = out end
    S.MarkAllBones()
end

if SERVER then
    util.AddNetworkString("GRM_Soc_Set")

    local function busy(ply)
        if not IsValid(ply) or not ply:Alive() then return "недоступно" end
        if ply:InVehicle() then return "в транспорте" end
        if ply:GetNWBool("GRM_Cuffed") then return "наручники" end
        if ply:GetNWBool("GRM_Arrested") then return "арест" end
        if ply:GetNWBool("GRM_Prone") then return "лёжа" end
        if ply:GetNWBool("GRM_911_Downed") then return "ранен" end
        return nil
    end

    function S.Stop(ply)
        if not IsValid(ply) then return end
        ply:SetNWString("GRM_SocAnim", "")
        ply:SetNWBool("GRM_SocCrouch", false)
    end

    function S.Play(ply, id)
        local why = busy(ply)
        if why then
            if GRM.Notify then GRM.Notify(ply, "Анимация: " .. why, 255, 160, 90) end
            return false
        end
        if id == "" or id == "off" or id == "stop" then
            S.Stop(ply)
            return true
        end
        local def = S.ByID(id)
        if not def then return false end
        if ply:GetNWString("GRM_SocAnim", "") == def.id then
            S.Stop(ply)
            return true
        end
        ply:SetNWString("GRM_SocAnim", def.id)
        ply:SetNWBool("GRM_SocCrouch", def.crouch == true)
        return true
    end

    net.Receive("GRM_Soc_Set", function(_, ply)
        if not IsValid(ply) then return end
        if GRM.Perf and GRM.Perf.Throttle and not GRM.Perf.Throttle("soc." .. ply:EntIndex(), 0.15) then return end
        local id = string.sub(tostring(net.ReadString() or ""), 1, 32)
        S.Play(ply, id)
    end)

    hook.Add("PlayerDeath", "GRM_Soc_Death", S.Stop)
    hook.Add("PlayerSilentDeath", "GRM_Soc_Death2", S.Stop)
    hook.Add("PlayerEnteredVehicle", "GRM_Soc_Veh", function(ply) S.Stop(ply) end)
    hook.Add("PlayerSpawn", "GRM_Soc_Spawn", S.Stop)

    hook.Add("StartCommand", "GRM_Soc_Hold", function(ply, cmd)
        if not IsValid(ply) then return end
        if ply:GetNWString("GRM_SocAnim", "") == "" then return end
        local def = S.ByID(ply:GetNWString("GRM_SocAnim", ""))
        if not def then return end
        if def.crouch then
            cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_DUCK))
            cmd:RemoveKey(IN_JUMP)
            if not def.walk then cmd:ClearMovement() end
        end
        cmd:RemoveKey(IN_ATTACK)
        cmd:RemoveKey(IN_ATTACK2)
    end)

    hook.Add("CalcMainActivity", "GRM_Soc_Act", function(ply, vel)
        if not IsValid(ply) then return end
        if ply:GetNWString("GRM_SocAnim", "") == "" then return end
        local def = S.ByID(ply:GetNWString("GRM_SocAnim", ""))
        if not def or not def.crouch then return end
        local moving = vel and vel:Length2D() > 8
        return moving and ACT_HL2MP_WALK_CROUCH or ACT_HL2MP_IDLE_CROUCH, -1
    end)

    hook.Add("PlayerSay", "GRM_Soc_Chat", function(ply, text)
        local t = string.lower(string.Trim(tostring(text or "")))
        if t == "/anim" or t == "/аним" or t == "/анимации" or t == "/social" then
            if GRM.Notify then GRM.Notify(ply, "Соц.анимации: клавиша из F4 → Настройки. Позы также в /binder как шаг АНИМ.", 180, 210, 240) end
            return ""
        end
        if t == "/animstop" or t == "/стоппоза" then
            S.Stop(ply)
            return ""
        end
    end)

    print("[GRM Social] server v" .. S.Version)
    return
end

-----------------------------------------------------------------------
-- CLIENT
-----------------------------------------------------------------------
CreateClientConVar("grm_cl_social_key", "18", true, false, "Клавиша меню соц.анимаций (KEY_*)")

surface.CreateFont("GRMSoc_Head", { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("GRMSoc_Body", { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("GRMSoc_Sm", { font = "Roboto", size = 12, weight = 400, extended = true })

local applied = {}
local clips = {}

local function resetBones(ply)
    if not IsValid(ply) then return end
    for name in pairs(ALL_BONES) do
        local b = ply:LookupBone(name)
        if b then
            ply:ManipulateBoneAngles(b, Angle(0, 0, 0))
            ply:ManipulateBonePosition(b, Vector(0, 0, 0))
        end
    end
    if ply.InvalidateBoneCache then ply:InvalidateBoneCache() end
    applied[ply] = nil
end

local function applyPose(ply, def)
    if not IsValid(ply) or not def then return end
    if applied[ply] ~= def.id then resetBones(ply) end
    for name, rec in pairs(def.bones or {}) do
        local b = ply:LookupBone(name)
        if b then
            ply:ManipulateBoneAngles(b, S.BoneToAngle(rec))
            local pos = S.BoneToPos(rec)
            if pos:LengthSqr() > 0.0001 then ply:ManipulateBonePosition(b, pos) end
        end
    end
    applied[ply] = def.id
end

local function killClip(ply)
    local rec = clips[ply]
    local m = istable(rec) and rec.ent or rec
    if IsValid(m) then
        if m.SetParent then pcall(m.SetParent, m, NULL) end
        m:Remove()
    end
    clips[ply] = nil
end

hook.Add("Think", "GRM_Soc_Apply", function()
    if GRM.Perf and GRM.Perf.Throttle and not GRM.Perf.Throttle("soc.apply", 0.12) then return end
    local list = (GRM.Perf and GRM.Perf.Players and GRM.Perf.Players()) or player.GetAll()
    for i = 1, #list do
        local ply = list[i]
        if not IsValid(ply) then continue end
        local id = ply:GetNWString("GRM_SocAnim", "")
        local phoneMdl = ply:GetNWString("GRM_MobHold", "")
        if id == "" and phoneMdl == "" then
            if applied[ply] then resetBones(ply) end
            if clips[ply] then killClip(ply) end
        elseif phoneMdl ~= "" then
            applyPose(ply, S.PhonePose)
        else
            local def = S.ByID(id)
            if def then applyPose(ply, def) end
        end
    end
end)

hook.Add("EntityRemoved", "GRM_Soc_EntGone", function(ent)
    if applied[ent] then resetBones(ent) end
    if clips[ent] then killClip(ent) end
end)

local function wantProp(ply)
    local phoneMdl = ply:GetNWString("GRM_MobHold", "")
    if phoneMdl ~= "" then return phoneMdl, "phone" end
    if ply:GetNWString("GRM_SocAnim", "") == "docs" then
        return "models/props_lab/clipboard.mdl", "docs"
    end
end

hook.Add("PostPlayerDraw", "GRM_Soc_ClipFixed", function(ply)
    if not IsValid(ply) then return end
    local mdl, kind = wantProp(ply)
    if not mdl then
        if clips[ply] then killClip(ply) end
        return
    end
    local rec = clips[ply]
    local m = istable(rec) and rec.ent or rec
    if not IsValid(m) or (istable(rec) and rec.mdl ~= mdl) then
        if IsValid(m) then m:Remove() end
        m = ClientsideModel(mdl)
        if not IsValid(m) then return end
        m:SetModelScale(kind == "phone" and ((S.PhoneHold and S.PhoneHold.scale) or 1) or 0.82, 0)
        clips[ply] = { ent = m, mdl = mdl, bone = nil }
    end
    local bone = ply:LookupBone("ValveBiped.Bip01_R_Hand")
    if not bone then return end
    rec = clips[ply]
    if kind == "phone" then
        m:SetNoDraw(false)
        if rec.bone ~= bone or m:GetParent() ~= ply then
            m:FollowBone(ply, bone)
            rec.bone = bone
        end
        local hold = S.PhoneHold or { pos = Vector(2.85, 1.15, 0.22), ang = Angle(12, 98, 88) }
        m:SetLocalPos(hold.pos)
        m:SetLocalAngles(hold.ang)
        return
    end
    m:SetNoDraw(true)
    if m.SetParent then m:SetParent(NULL) end
    rec.bone = nil
    local mtx = ply.GetBoneMatrix and ply:GetBoneMatrix(bone)
    local pos, ang
    if mtx then pos, ang = mtx:GetTranslation(), mtx:GetAngles()
    else pos, ang = ply:GetBonePosition(bone) end
    if not pos or not ang then return end
    ang:RotateAroundAxis(ang:Forward(), 95)
    ang:RotateAroundAxis(ang:Right(), 8)
    ang:RotateAroundAxis(ang:Up(), 4)
    pos = pos + ang:Forward() * 5.8 + ang:Right() * 0.2 + ang:Up() * 0.8
    m:SetPos(pos)
    m:SetAngles(ang)
    m:DrawModel()
end)

hook.Add("CalcMainActivity", "GRM_Soc_Act", function(ply, vel)
    if not IsValid(ply) then return end
    if ply:GetNWString("GRM_SocAnim", "") == "" then return end
    local def = S.ByID(ply:GetNWString("GRM_SocAnim", ""))
    if not def then return end
    if def.crouch then
        local moving = vel and vel:Length2D() > 8
        return moving and ACT_HL2MP_WALK_CROUCH or ACT_HL2MP_IDLE_CROUCH, -1
    end
end)

local function sendPlay(id)
    net.Start("GRM_Soc_Set")
    net.WriteString(tostring(id or "stop"))
    net.SendToServer()
end

S.Request = sendPlay
S.Open = S.Open
S.RadialOpen = false
S._menuCat = "general"

local function inputBusy()
    if gui.IsGameUIVisible() or gui.IsConsoleVisible() then return true end
    local lp = LocalPlayer()
    if IsValid(lp) and lp.IsTyping and lp:IsTyping() then return true end
    return false
end

local function keyNum()
    return math.Clamp(math.floor(GetConVarNumber("grm_cl_social_key") or 18), 0, 159)
end

function S.CloseMenu()
    S.RadialOpen = false
    if IsValid(S._menu) then S._menu:Remove() end
    S._menu = nil
    gui.EnableScreenClicker(false)
end

function S.OpenMenu()
    if IsValid(S._menu) then
        S._menu:SetVisible(true)
        S._menu:MakePopup()
        S._menu:MoveToFront()
        return
    end
    local cats = isfunction(S.Categories) and S.Categories() or { { id = "general", name = "Общее" } }
    local have
    for i = 1, #cats do if cats[i].id == S._menuCat then have = true break end end
    if not have then S._menuCat = cats[1] and cats[1].id or "general" end

    local f = vgui.Create("DFrame")
    S._menu = f
    S.RadialOpen = true
    f:SetTitle("")
    f:SetSize(460, 420)
    f:Center()
    f:MakePopup()
    f:ShowCloseButton(false)
    f:SetKeyboardInputEnabled(false)
    f.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(16, 20, 28, 252))
        draw.RoundedBox(8, 0, 0, w, 40, Color(12, 15, 22, 255))
        draw.SimpleText("СОЦ. АНИМАЦИИ", "GRMSoc_Head", 14, 20, Color(245, 195, 65), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local cur = LocalPlayer():GetNWString("GRM_SocAnim", "")
        local mine = S.ByID(cur)
        if mine then
            draw.SimpleText("сейчас: " .. mine.name, "GRMSoc_Sm", w - 48, 20, Color(90, 200, 120), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
    f.OnRemove = function() S.RadialOpen = false S._menu = nil end

    local x = vgui.Create("DButton", f)
    x:SetPos(426, 8) x:SetSize(24, 24) x:SetText("✕")
    x:SetTextColor(Color(200, 210, 220))
    x.Paint = function(s, w, h) if s:IsHovered() then draw.RoundedBox(4, 0, 0, w, h, Color(180, 60, 60)) end end
    x.DoClick = function() S.CloseMenu() end

    local tabs = vgui.Create("DHorizontalScroller", f)
    tabs:SetPos(10, 46) tabs:SetSize(440, 30)
    tabs:SetOverlap(-4)

    local grid = vgui.Create("DScrollPanel", f)
    grid:SetPos(10, 82) grid:SetSize(440, 292)

    local function fill()
        grid:Clear()
        local items = (isfunction(S.InCat) and S.InCat(S._menuCat)) or (S.List or {})
        local col, bw, bh, gap = 2, 210, 36, 8
        for i, def in ipairs(items) do
            local r = math.floor((i - 1) / col)
            local c = (i - 1) % col
            local b = vgui.Create("DButton", grid)
            b:SetPos(c * (bw + gap), r * (bh + gap))
            b:SetSize(bw, bh)
            b:SetText(def.name)
            b:SetFont("GRMSoc_Body")
            b:SetTextColor(Color(240, 244, 250))
            b.Paint = function(s, w, h)
                local on = LocalPlayer():GetNWString("GRM_SocAnim", "") == def.id
                local bg = on and Color(50, 130, 90) or (s:IsHovered() and Color(55, 120, 210) or Color(32, 40, 54))
                draw.RoundedBox(5, 0, 0, w, h, bg)
            end
            b.DoClick = function()
                if surface and surface.PlaySound then surface.PlaySound("common/wpn_select.wav") end
                sendPlay(def.id)
                S.CloseMenu()
            end
        end
        if #items == 0 then
            local empty = vgui.Create("DLabel", grid)
            empty:SetPos(8, 8) empty:SetSize(400, 24)
            empty:SetText("В этой категории нет поз. Добавьте в /animstudio.")
            empty:SetTextColor(Color(160, 175, 190))
        end
    end

    for _, cat in ipairs(cats) do
        local b = vgui.Create("DButton", tabs)
        b:SetSize(math.max(88, utf8 and utf8.len(cat.name) and (#cat.name * 8 + 24) or (#cat.name * 8 + 24)), 28)
        b:SetText(cat.name)
        b:SetFont("GRMSoc_Sm")
        b:SetTextColor(Color(240, 244, 250))
        b.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, S._menuCat == cat.id and Color(65, 145, 235) or Color(36, 44, 58))
        end
        b.DoClick = function() S._menuCat = cat.id fill() end
        tabs:AddPanel(b)
    end
    fill()

    local stop = vgui.Create("DButton", f)
    stop:SetPos(10, 380) stop:SetSize(216, 30) stop:SetText("Снять позу")
    stop:SetTextColor(Color(240, 244, 250))
    stop.Paint = function(s, w, h) draw.RoundedBox(5, 0, 0, w, h, s:IsHovered() and Color(180, 80, 70) or Color(140, 60, 55)) end
    stop.DoClick = function() sendPlay("stop") S.CloseMenu() end
    local hint = vgui.Create("DLabel", f)
    hint:SetPos(236, 384) hint:SetSize(210, 22)
    hint:SetText("ПКМ / ✕ — закрыть")
    hint:SetTextColor(Color(150, 165, 180))
    if surface and surface.PlaySound then surface.PlaySound("common/wpn_hudon.wav") end
end

function S.OpenRadial() S.OpenMenu() end
function S.CloseRadial() S.CloseMenu() end

S._keyLock = 0
hook.Add("PlayerButtonDown", "GRM_Soc_Key", function(ply, key)
    if ply ~= LocalPlayer() then return end
    if IsValid(S._menu) and (key == MOUSE_RIGHT or key == KEY_ESCAPE) then
        S.CloseMenu()
        return
    end
    if key ~= keyNum() or key <= 0 then return end
    if inputBusy() then return end
    local now = CurTime()
    if now < (S._keyLock or 0) then return end
    S._keyLock = now + 0.35
    -- Удержание не закрывает: повтор клавиши при hold давал мерцание.
    if IsValid(S._menu) then return end
    S.OpenMenu()
end)

hook.Add("StartCommand", "GRM_Soc_MenuFreeze", function(ply, cmd)
    if not IsValid(S._menu) then return end
    if ply ~= LocalPlayer() then return end
    cmd:ClearMovement()
    cmd:RemoveKey(IN_ATTACK)
    cmd:RemoveKey(IN_ATTACK2)
end)

function S.OpenPicker()
    S.OpenMenu()
end

function S.OpenFromContext()
    S.OpenMenu()
end

function S._OpenFromContextLegacy()
    S.OpenMenu()
end

concommand.Add("grm_social", function(_, _, args)
    local a = string.lower(tostring(args[1] or ""))
    if a == "" or a == "menu" then S.OpenFromContext() return end
    sendPlay(a)
end)
concommand.Add("grm_social_stop", function() sendPlay("stop") end)

-- Вкладку «Анимации» не добавляем: в F4 только бинд в «Настройки».

print("[GRM Social] client v" .. S.Version)
