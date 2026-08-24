--[[ Соц.анимации: костные позы, радиальное меню, бинд F4, C-меню. ]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Social = GRM.Social or {}
local S = GRM.Social
S.Version = "1.0.0"

S.List = {
    {
        id = "hands",
        name = "Руки вверх",
        hold = true,
        walk = true,
        bones = {
            ["ValveBiped.Bip01_R_UpperArm"] = Angle(-12, -28, 78),
            ["ValveBiped.Bip01_R_Forearm"]  = Angle(8, -18, 12),
            ["ValveBiped.Bip01_R_Hand"]     = Angle(0, 8, 18),
            ["ValveBiped.Bip01_L_UpperArm"] = Angle(12, -28, -78),
            ["ValveBiped.Bip01_L_Forearm"]  = Angle(-8, -18, -12),
            ["ValveBiped.Bip01_L_Hand"]     = Angle(0, 8, -18),
        },
    },
    {
        id = "kneel",
        name = "Руки вверх, на коленях",
        hold = true,
        crouch = true,
        walk = false,
        bones = {
            ["ValveBiped.Bip01_Spine"]      = Angle(8, 6, 0),
            ["ValveBiped.Bip01_Spine2"]     = Angle(4, 4, 0),
            ["ValveBiped.Bip01_R_Thigh"]    = Angle(8, 18, 0),
            ["ValveBiped.Bip01_L_Thigh"]    = Angle(-8, 18, 0),
            ["ValveBiped.Bip01_R_Calf"]     = Angle(0, -28, 0),
            ["ValveBiped.Bip01_L_Calf"]     = Angle(0, -28, 0),
            ["ValveBiped.Bip01_R_UpperArm"] = Angle(-10, -22, 82),
            ["ValveBiped.Bip01_R_Forearm"]  = Angle(6, -14, 10),
            ["ValveBiped.Bip01_R_Hand"]     = Angle(0, 6, 16),
            ["ValveBiped.Bip01_L_UpperArm"] = Angle(10, -22, -82),
            ["ValveBiped.Bip01_L_Forearm"]  = Angle(-6, -14, -10),
            ["ValveBiped.Bip01_L_Hand"]     = Angle(0, 6, -16),
        },
    },
    {
        id = "docs",
        name = "Рассматривать документы",
        hold = true,
        walk = true,
        prop = "models/props_lab/clipboard.mdl",
        bones = {
            ["ValveBiped.Bip01_R_UpperArm"] = Angle(18, -32, 18),
            ["ValveBiped.Bip01_R_Forearm"]  = Angle(-8, -48, 12),
            ["ValveBiped.Bip01_R_Hand"]     = Angle(-12, -8, 24),
            ["ValveBiped.Bip01_L_UpperArm"] = Angle(-8, -18, -22),
            ["ValveBiped.Bip01_L_Forearm"]  = Angle(6, -36, -8),
            ["ValveBiped.Bip01_L_Hand"]     = Angle(10, 4, -12),
            ["ValveBiped.Bip01_Head1"]      = Angle(0, -12, -8),
            ["ValveBiped.Bip01_Neck1"]      = Angle(0, -6, 0),
        },
    },
}

function S.ByID(id)
    id = tostring(id or "")
    for i = 1, #S.List do
        if S.List[i].id == id then return S.List[i] end
    end
end

local ALL_BONES = {}
for i = 1, #S.List do
    for name in pairs(S.List[i].bones or {}) do
        ALL_BONES[name] = true
    end
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
        local id = string.sub(tostring(net.ReadString() or ""), 1, 24)
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
            if GRM.Notify then GRM.Notify(ply, "Соц.анимации: удержите назначенную клавишу или C-меню.", 180, 210, 240) end
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
    for name, ang in pairs(def.bones or {}) do
        local b = ply:LookupBone(name)
        if b then ply:ManipulateBoneAngles(b, ang) end
    end
    applied[ply] = def.id
end

local function killClip(ply)
    local m = clips[ply]
    if IsValid(m) then m:Remove() end
    clips[ply] = nil
end

hook.Add("Think", "GRM_Soc_Apply", function()
    if GRM.Perf and GRM.Perf.Throttle and not GRM.Perf.Throttle("soc.apply", 0.12) then return end
    local list = (GRM.Perf and GRM.Perf.Players and GRM.Perf.Players()) or player.GetAll()
    for i = 1, #list do
        local ply = list[i]
        if not IsValid(ply) then continue end
        local id = ply:GetNWString("GRM_SocAnim", "")
        if id == "" then
            if applied[ply] then resetBones(ply) end
            if clips[ply] then killClip(ply) end
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

hook.Add("PostPlayerDraw", "GRM_Soc_Clip", function(ply)
    if not IsValid(ply) then return end
    if ply:GetNWString("GRM_SocAnim", "") ~= "docs" then
        if clips[ply] then killClip(ply) end
        return
    end
    local m = clips[ply]
    if not IsValid(m) then
        m = ClientsideModel("models/props_lab/clipboard.mdl")
        if not IsValid(m) then return end
        m:SetNoDraw(true)
        m:SetModelScale(0.95, 0)
        clips[ply] = m
    end
    local bone = ply:LookupBone("ValveBiped.Bip01_R_Hand")
    if not bone then return end
    local pos, ang = ply:GetBonePosition(bone)
    if not pos then return end
    ang:RotateAroundAxis(ang:Right(), 200)
    ang:RotateAroundAxis(ang:Up(), 12)
    ang:RotateAroundAxis(ang:Forward(), 90)
    pos = pos + ang:Forward() * 3 + ang:Right() * 1.5 + ang:Up() * 1
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

S.Open = S.Open
S.RadialOpen = false
S.RadialPick = 0

local function inputBusy()
    if gui.IsGameUIVisible() or gui.IsConsoleVisible() then return true end
    if IsValid(vgui.GetKeyboardFocus()) then return true end
    local lp = LocalPlayer()
    if IsValid(lp) and lp.IsTyping and lp:IsTyping() then return true end
    return false
end

local function keyNum()
    return math.Clamp(math.floor(GetConVarNumber("grm_cl_social_key") or 18), 0, 159)
end

function S.OpenRadial()
    if S.RadialOpen then return end
    S.RadialOpen = true
    S.RadialPick = 0
    S.RadialAnim = {}
    gui.EnableScreenClicker(true)
    if surface and surface.PlaySound then surface.PlaySound("common/wpn_hudon.wav") end
end

function S.CloseRadial(execute)
    if not S.RadialOpen then return end
    S.RadialOpen = false
    S._fromCtx = false
    timer.Remove("GRM_Soc_CtxHold")
    gui.EnableScreenClicker(false)
    local pick = S.RadialPick
    S.RadialPick = 0
    if execute and pick > 0 and S.List[pick] then
        if surface and surface.PlaySound then surface.PlaySound("common/wpn_select.wav") end
        sendPlay(S.List[pick].id)
        return
    end
    if surface and surface.PlaySound then surface.PlaySound("common/wpn_hudoff.wav") end
end

hook.Add("PlayerButtonDown", "GRM_Soc_Key", function(ply, key)
    if ply ~= LocalPlayer() then return end
    if S.RadialOpen then
        if key == MOUSE_LEFT then S.CloseRadial(true) return end
        if key == MOUSE_RIGHT then S.CloseRadial(false) return end
    end
    if key ~= keyNum() or key <= 0 then return end
    if inputBusy() then return end
    S.OpenRadial()
end)

hook.Add("PlayerButtonUp", "GRM_Soc_KeyUp", function(ply, key)
    if ply ~= LocalPlayer() then return end
    if key ~= keyNum() then return end
    if S.RadialOpen then S.CloseRadial(false) end
end)

hook.Add("StartCommand", "GRM_Soc_RadialFreeze", function(ply, cmd)
    if not S.RadialOpen then return end
    if ply ~= LocalPlayer() then return end
    cmd:ClearMovement()
    cmd:ClearButtons()
end)

hook.Add("Think", "GRM_Soc_RadialGuard", function()
    if not S.RadialOpen then return end
    local k = keyNum()
    if k <= 0 then S.CloseRadial(false) return end
    if not input.IsKeyDown(k) and not input.IsMouseDown(k) and not S._fromCtx then
        S.CloseRadial(false)
    end
end)

hook.Add("HUDPaint", "GRM_Soc_Radial", function()
    if not S.RadialOpen then return end
    local count = #S.List
    local sw, sh = ScrW(), ScrH()
    local cx, cy = sw / 2, sh / 2
    local outer = math.min(sw, sh) * 0.26
    local inner = outer * 0.40
    local mx, my = gui.MousePos()
    if mx == 0 and my == 0 then mx, my = cx, cy end
    local dx, dy = mx - cx, my - cy
    local pick = 0
    if (dx * dx + dy * dy) >= (inner * inner) then
        local ang = math.deg(math.atan2(dx, -dy))
        if ang < 0 then ang = ang + 360 end
        pick = math.floor((ang + (180 / count)) / (360 / count)) + 1
        if pick > count then pick = 1 end
    end
    if pick ~= S.RadialPick and pick > 0 and surface and surface.PlaySound then
        surface.PlaySound("common/wpn_moveselect.wav")
    end
    S.RadialPick = pick
    S.RadialAnim = S.RadialAnim or {}
    local ft = math.min(FrameTime() * 9, 1)
    for i = 1, count do
        local target = (pick == i) and 1 or 0
        S.RadialAnim[i] = (S.RadialAnim[i] or 0) + (target - (S.RadialAnim[i] or 0)) * ft
    end
    surface.SetDrawColor(0, 0, 0, 160)
    surface.DrawRect(0, 0, sw, sh)
    local step = 360 / count
    for i, def in ipairs(S.List) do
        local anim = S.RadialAnim[i] or 0
        local startAng = (i - 1) * step - step / 2 - 90
        local segs = math.max(8, math.floor(step / 3))
        local r1 = outer + 14 * anim
        local r0 = inner - 3 * anim
        local gap = math.rad(1.4)
        local poly = {}
        for s2 = 0, segs do
            local a = math.rad(startAng) + gap + (math.rad(step) - gap * 2) * (s2 / segs)
            poly[#poly + 1] = { x = cx + math.cos(a) * r1, y = cy + math.sin(a) * r1 }
        end
        for s2 = segs, 0, -1 do
            local a = math.rad(startAng) + gap + (math.rad(step) - gap * 2) * (s2 / segs)
            poly[#poly + 1] = { x = cx + math.cos(a) * r0, y = cy + math.sin(a) * r0 }
        end
        draw.NoTexture()
        surface.SetDrawColor(Lerp(anim, 28, 70), Lerp(anim, 36, 150), Lerp(anim, 48, 235), 230)
        surface.DrawPoly(poly)
        local midA = math.rad(startAng + step / 2)
        local tr = (r0 + r1) / 2
        draw.SimpleTextOutlined(def.name, "GRMSoc_Body", cx + math.cos(midA) * tr, cy + math.sin(midA) * tr,
            color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(8, 12, 18, 230))
    end
    draw.SimpleText("СОЦ. АНИМАЦИИ", "GRMSoc_Head", cx, cy - 14, Color(245, 195, 65), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    local cur = LocalPlayer():GetNWString("GRM_SocAnim", "")
    local hint = (pick > 0) and "ЛКМ — выбрать" or (cur ~= "" and "повтор позы снимет её" or "наведите сектор")
    draw.SimpleText(hint, "GRMSoc_Sm", cx, cy + 10, Color(180, 195, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    local mine = S.ByID(cur)
    if mine then
        draw.SimpleText("сейчас: " .. mine.name, "GRMSoc_Sm", cx, cy + 26, Color(90, 200, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)

function S.OpenFromContext()
    S._fromCtx = true
    S.OpenRadial()
    timer.Create("GRM_Soc_CtxHold", 8, 1, function()
        S._fromCtx = false
        if S.RadialOpen then S.CloseRadial(false) end
    end)
end

concommand.Add("grm_social", function(_, _, args)
    local a = string.lower(tostring(args[1] or ""))
    if a == "" or a == "menu" then S.OpenFromContext() return end
    sendPlay(a)
end)
concommand.Add("grm_social_stop", function() sendPlay("stop") end)

hook.Add("GRM_F4_BuildTabs", "GRM_Soc_F4", function(sheet)
    if not IsValid(sheet) then return end
    local p = vgui.Create("DPanel")
    p:SetPaintBackground(false)
    local sc = vgui.Create("DScrollPanel", p)
    sc:Dock(FILL)
    local card = vgui.Create("DPanel", sc)
    card:Dock(TOP) card:SetTall(220) card:DockMargin(4, 4, 4, 4)
    card.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(32, 38, 50, 245))
        draw.SimpleText("Социальные анимации", "GRMF4_Sub" , 12, 16, Color(230, 180, 60), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Удерживайте клавишу — круг выбора. Повтор той же позы снимает её. C-меню → «Соц. анимации».",
            "GRMF4_Normal", 12, 40, Color(160, 170, 185), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    local lbl = vgui.Create("DLabel", card)
    lbl:SetPos(12, 68) lbl:SetSize(220, 22)
    lbl:SetFont("GRMF4_Normal") lbl:SetTextColor(Color(240, 245, 250))
    lbl:SetText("Клавиша меню анимаций:")
    local binder = vgui.Create("DBinder", card)
    binder:SetPos(220, 64) binder:SetSize(140, 28)
    binder:SetValue(keyNum())
    binder.OnChange = function(_, num)
        RunConsoleCommand("grm_cl_social_key", tostring(math.floor(tonumber(num) or 18)))
    end
    local y = 108
    for _, def in ipairs(S.List) do
        local b = vgui.Create("DButton", card)
        b:SetPos(12, y) b:SetSize(260, 26) b:SetText(def.name)
        b.DoClick = function() sendPlay(def.id) end
        y = y + 30
    end
    local stop = vgui.Create("DButton", card)
    stop:SetPos(280, 108) stop:SetSize(160, 26) stop:SetText("Снять позу")
    stop.DoClick = function() sendPlay("stop") end
    sheet:AddSheet("Анимации", p, "icon16/user_comment.png")
end)

print("[GRM Social] client v" .. S.Version)
