--[[--------------------------------------------------------------------
    GRM CCTV — client UI + live view overlay (Код 60)
----------------------------------------------------------------------]]

if not CLIENT then return end

include("autorun/sh_grm_cctv_config.lua")

GRM = GRM or {}
GRM.CCTV = GRM.CCTV or {}
local CCTV = GRM.CCTV

local NET_OPEN_CAM   = "GRM_CCTV_OpenCam"
local NET_OPEN_MON   = "GRM_CCTV_OpenMon"
local NET_OPEN_SRV   = "GRM_CCTV_OpenSrv"
local NET_LIST       = "GRM_CCTV_List"
local NET_ACTION     = "GRM_CCTV_Action"
local NET_VIEW       = "GRM_CCTV_View"
local NET_VIEW_STOP  = "GRM_CCTV_ViewStop"
local NET_NOTIFY     = "GRM_CCTV_Notify"

local ViewState = {
    active = false,
    cam = NULL,
    monitor = NULL,
    label = "",
    network = "",
    fov = 75,
}

local function sendAction(action, ent, writeExtra)
    net.Start(NET_ACTION)
        net.WriteString(action)
        net.WriteEntity(IsValid(ent) and ent or NULL)
        if writeExtra then writeExtra() end
    net.SendToServer()
end

local function styleFrame(frame, title)
    frame:SetTitle(title or "GRM CCTV")
    frame:SetSize(math.min(ScrW() * 0.5, 560), math.min(ScrH() * 0.6, 480))
    frame:Center()
    frame:MakePopup()
    frame:SetKeyboardInputEnabled(true)
    frame:SetMouseInputEnabled(true)
end

local function addLabeledEntry(parent, y, label, default, numeric)
    local lbl = vgui.Create("DLabel", parent)
    lbl:SetPos(15, y)
    lbl:SetSize(120, 20)
    lbl:SetText(label)
    lbl:SetTextColor(Color(220, 220, 220))

    local entry
    if numeric then
        entry = vgui.Create("DNumberWang", parent)
        entry:SetPos(140, y)
        entry:SetSize(180, 22)
        entry:SetMin(40)
        entry:SetMax(100)
        entry:SetValue(tonumber(default) or 75)
    else
        entry = vgui.Create("DTextEntry", parent)
        entry:SetPos(140, y)
        entry:SetSize(280, 22)
        entry:SetValue(tostring(default or ""))
    end
    return entry
end

local function addBtn(parent, x, y, w, h, text, col, fn)
    local b = vgui.Create("DButton", parent)
    b:SetPos(x, y)
    b:SetSize(w, h)
    b:SetText(text)
    if col then b:SetTextColor(col) end
    b.DoClick = fn
    return b
end

-- ── notify ─────────────────────────────────────────────────
net.Receive(NET_NOTIFY, function()
    local ok = net.ReadBool()
    local msg = net.ReadString() or ""
    if GRM and isfunction(GRM.Notify) then
        GRM.Notify(LocalPlayer(), msg, ok and 100 or 255, ok and 220 or 120, ok and 100 or 120)
    else
        chat.AddText(ok and Color(100, 220, 100) or Color(255, 120, 120), "[CCTV] ", color_white, msg)
    end
end)

-- ── camera config ──────────────────────────────────────────
net.Receive(NET_OPEN_CAM, function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    if IsValid(CCTV._camFrame) then CCTV._camFrame:Remove() end
    local f = vgui.Create("DFrame")
    CCTV._camFrame = f
    styleFrame(f, "Камера — " .. (ent:GetLabel() or ""))
    f:SetSize(460, 280)

    local label = addLabeledEntry(f, 40, "Подпись", ent:GetLabel())
    local network = addLabeledEntry(f, 70, "Сеть", ent:GetNetworkID())
    local fov = addLabeledEntry(f, 100, "FOV", ent:GetCamFOV(), true)

    local active = vgui.Create("DCheckBoxLabel", f)
    active:SetPos(15, 140)
    active:SetText("Камера включена (ONLINE)")
    active:SetValue(ent:GetActive())
    active:SizeToContents()

    local perm = vgui.Create("DCheckBoxLabel", f)
    perm:SetPos(15, 165)
    perm:SetText("Permanent (суперадмин, переживает рестарт)")
    perm:SetValue(ent:GetPermanent())
    perm:SizeToContents()

    local idlbl = vgui.Create("DLabel", f)
    idlbl:SetPos(15, 195)
    idlbl:SetSize(420, 18)
    idlbl:SetText("ID: " .. tostring(ent:GetDeviceID() or ""))
    idlbl:SetTextColor(Color(150, 150, 150))

    addBtn(f, 15, 230, 120, 28, "Сохранить", Color(100, 220, 120), function()
        sendAction("set_label", ent, function() net.WriteString(label:GetValue()) end)
        sendAction("set_network", ent, function() net.WriteString(network:GetValue()) end)
        sendAction("set_fov", ent, function() net.WriteUInt(math.Clamp(tonumber(fov:GetValue()) or 75, 40, 100), 8) end)
        sendAction("set_active", ent, function() net.WriteBool(active:GetChecked()) end)
        sendAction("set_permanent", ent, function() net.WriteBool(perm:GetChecked()) end)
        f:Close()
    end)
    addBtn(f, 150, 230, 100, 28, "Отмена", nil, function() f:Close() end)
end)

-- ── server config ──────────────────────────────────────────
net.Receive(NET_OPEN_SRV, function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    if IsValid(CCTV._srvFrame) then CCTV._srvFrame:Remove() end
    local f = vgui.Create("DFrame")
    CCTV._srvFrame = f
    styleFrame(f, "Сервер CCTV — " .. (ent:GetLabel() or ""))
    f:SetSize(460, 250)

    local label = addLabeledEntry(f, 40, "Подпись", ent:GetLabel())
    local network = addLabeledEntry(f, 70, "Сеть", ent:GetNetworkID())

    local active = vgui.Create("DCheckBoxLabel", f)
    active:SetPos(15, 110)
    active:SetText("Стойка ONLINE (без неё камеры сети не видны)")
    active:SetValue(ent:GetActive())
    active:SizeToContents()

    local perm = vgui.Create("DCheckBoxLabel", f)
    perm:SetPos(15, 140)
    perm:SetText("Permanent (суперадмин)")
    perm:SetValue(ent:GetPermanent())
    perm:SizeToContents()

    local hint = vgui.Create("DLabel", f)
    hint:SetPos(15, 170)
    hint:SetSize(420, 30)
    hint:SetWrap(true)
    hint:SetText("Камеры и мониторы с тем же ID сети работают только при включённой стойке.")
    hint:SetTextColor(Color(180, 180, 180))

    addBtn(f, 15, 205, 120, 28, "Сохранить", Color(100, 220, 120), function()
        sendAction("set_label", ent, function() net.WriteString(label:GetValue()) end)
        sendAction("set_network", ent, function() net.WriteString(network:GetValue()) end)
        sendAction("set_active", ent, function() net.WriteBool(active:GetChecked()) end)
        sendAction("set_permanent", ent, function() net.WriteBool(perm:GetChecked()) end)
        f:Close()
    end)
    addBtn(f, 150, 205, 100, 28, "Отмена", nil, function() f:Close() end)
end)

-- ── monitor UI ─────────────────────────────────────────────
local function buildMonitorUI(monitor, netID, hasSrv, canCfg, cams)
    if IsValid(CCTV._monFrame) then CCTV._monFrame:Remove() end
    local f = vgui.Create("DFrame")
    CCTV._monFrame = f
    f:SetTitle("Видеонаблюдение — сеть «" .. tostring(netID) .. "»")
    f:SetSize(math.min(ScrW() * 0.55, 640), math.min(ScrH() * 0.7, 520))
    f:Center()
    f:MakePopup()

    local status = vgui.Create("DLabel", f)
    status:SetPos(15, 32)
    status:SetSize(f:GetWide() - 30, 22)
    if hasSrv then
        status:SetText("Сервер сети: ONLINE · камер: " .. tostring(#cams))
        status:SetTextColor(Color(100, 220, 120))
    else
        status:SetText("Сервер сети: OFFLINE — просмотр недоступен (поставь/включи grm_cctv_server)")
        status:SetTextColor(Color(255, 140, 100))
    end

    local list = vgui.Create("DListView", f)
    list:SetPos(15, 60)
    list:SetSize(f:GetWide() - 30, f:GetTall() - 160)
    list:AddColumn("№"):SetFixedWidth(36)
    list:AddColumn("Камера")
    list:AddColumn("Статус"):SetFixedWidth(80)
    list:AddColumn("FOV"):SetFixedWidth(50)
    list:AddColumn("ID"):SetFixedWidth(120)
    list:SetMultiSelect(false)

    for i, cam in ipairs(cams) do
        local line = list:AddLine(
            tostring(i),
            cam.label or "Камера",
            cam.active and "ONLINE" or "OFF",
            tostring(cam.fov or 75),
            string.sub(cam.id or "", 1, 16)
        )
        line._camEnt = cam.ent
        line._active = cam.active
        if not cam.active and isfunction(line.SetTextColor) then
            line:SetTextColor(Color(160, 100, 100))
        end
    end

    local function selectedCam()
        local lines = list:GetSelected()
        if not lines or not lines[1] then return nil end
        return lines[1]._camEnt, lines[1]._active
    end

    addBtn(f, 15, f:GetTall() - 85, 140, 30, "Смотреть", Color(100, 200, 255), function()
        if not hasSrv then
            chat.AddText(Color(255, 140, 100), "[CCTV] ", color_white, "Нет ONLINE-сервера сети.")
            return
        end
        local cam, active = selectedCam()
        if not IsValid(cam) then
            chat.AddText(Color(255, 200, 100), "[CCTV] ", color_white, "Выбери камеру в списке.")
            return
        end
        if not active then
            chat.AddText(Color(255, 140, 100), "[CCTV] ", color_white, "Камера выключена.")
            return
        end
        sendAction("view_cam", monitor, function()
            net.WriteEntity(cam)
        end)
        f:Close()
    end)

    addBtn(f, 165, f:GetTall() - 85, 110, 30, "Обновить", nil, function()
        sendAction("refresh_list", monitor)
    end)

    if canCfg then
        local label = addLabeledEntry(f, f:GetTall() - 50, "Сеть монитора", netID)
        label:SetPos(15, f:GetTall() - 48)
        label:SetSize(200, 22)
        addBtn(f, 230, f:GetTall() - 50, 120, 26, "Сменить сеть", Color(220, 200, 100), function()
            sendAction("set_network", monitor, function() net.WriteString(label:GetValue()) end)
            timer.Simple(0.2, function()
                if IsValid(monitor) then sendAction("refresh_list", monitor) end
            end)
        end)
        addBtn(f, 360, f:GetTall() - 50, 100, 26, "Permanent", nil, function()
            sendAction("set_permanent", monitor, function() net.WriteBool(true) end)
        end)
    end

    addBtn(f, f:GetWide() - 115, f:GetTall() - 85, 100, 30, "Закрыть", nil, function() f:Close() end)

    list.DoDoubleClick = function()
        if hasSrv then
            local cam, active = selectedCam()
            if IsValid(cam) and active then
                sendAction("view_cam", monitor, function() net.WriteEntity(cam) end)
                f:Close()
            end
        end
    end

    CCTV._monList = list
    CCTV._monEntity = monitor
end

local function readCamList(n)
    local cams = {}
    for i = 1, n do
        local ent = net.ReadEntity()
        local label = net.ReadString()
        local id = net.ReadString()
        local active = net.ReadBool()
        local fov = net.ReadUInt(8)
        cams[#cams + 1] = { ent = ent, label = label, id = id, active = active, fov = fov }
    end
    return cams
end

net.Receive(NET_OPEN_MON, function()
    local mon = net.ReadEntity()
    local netID = net.ReadString()
    local hasSrv = net.ReadBool()
    local canCfg = net.ReadBool()
    local n = net.ReadUInt(8)
    local cams = readCamList(n)
    if not IsValid(mon) then return end
    buildMonitorUI(mon, netID, hasSrv, canCfg, cams)
end)

net.Receive(NET_LIST, function()
    local mon = net.ReadEntity()
    local netID = net.ReadString()
    local hasSrv = net.ReadBool()
    local n = net.ReadUInt(8)
    local cams = readCamList(n)
    if not IsValid(mon) then return end
    -- rebuild preserving configure rights if frame open
    buildMonitorUI(mon, netID, hasSrv, true, cams)
end)

-- ── live view ──────────────────────────────────────────────
net.Receive(NET_VIEW, function()
    local cam = net.ReadEntity()
    local mon = net.ReadEntity()
    local label = net.ReadString()
    local network = net.ReadString()
    local fov = net.ReadUInt(8)
    ViewState.active = true
    ViewState.cam = cam
    ViewState.monitor = mon
    ViewState.label = label
    ViewState.network = network
    ViewState.fov = fov
    if IsValid(CCTV._monFrame) then CCTV._monFrame:Close() end
end)

net.Receive(NET_VIEW_STOP, function()
    ViewState.active = false
    ViewState.cam = NULL
    ViewState.monitor = NULL
end)

hook.Add("CalcView", "GRM_CCTV_CalcView", function(ply, pos, ang, fov)
    if not ViewState.active then return end
    local cam = ViewState.cam
    if not IsValid(cam) then return end
    local origin = cam:GetPos() + cam:GetForward() * 6 + cam:GetUp() * 2
    local angles = cam:GetAngles()
    return {
        origin = origin,
        angles = angles,
        fov = ViewState.fov or cam:GetCamFOV() or 75,
        drawviewer = false,
    }
end)

hook.Add("HUDShouldDraw", "GRM_CCTV_HideHUD", function(name)
    if not ViewState.active then return end
    if name == "CHudWeaponSelection" or name == "CHudAmmo" or name == "CHudSecondaryAmmo" then
        return false
    end
end)

surface.CreateFont("GRM_CCTV_Title", { font = "Roboto", size = 22, weight = 700, extended = true })
surface.CreateFont("GRM_CCTV_Meta", { font = "Roboto", size = 16, weight = 500, extended = true })

hook.Add("HUDPaint", "GRM_CCTV_Overlay", function()
    if not ViewState.active then return end
    local w, h = ScrW(), ScrH()

    -- vignette bars (letterbox)
    surface.SetDrawColor(0, 0, 0, 180)
    surface.DrawRect(0, 0, w, 48)
    surface.DrawRect(0, h - 56, w, 56)

    -- scanline-ish
    surface.SetDrawColor(0, 255, 120, 12)
    for y = 48, h - 56, 4 do
        surface.DrawRect(0, y, w, 1)
    end

    -- REC indicator
    local blink = (math.floor(CurTime() * 2) % 2 == 0)
    if blink then
        surface.SetDrawColor(220, 40, 40, 230)
        draw.NoTexture()
        surface.DrawRect(18, 16, 12, 12)
    end
    draw.SimpleText("REC  LIVE", "GRM_CCTV_Meta", 38, 14, Color(255, 80, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    draw.SimpleText(
        ViewState.label ~= "" and ViewState.label or "Камера",
        "GRM_CCTV_Title", w * 0.5, 12, Color(220, 255, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
    )
    draw.SimpleText(
        "сеть: " .. tostring(ViewState.network or "?") .. "  ·  FOV " .. tostring(ViewState.fov or 75),
        "GRM_CCTV_Meta", w * 0.5, 34, Color(160, 200, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
    )

    local t = os.date("%Y-%m-%d %H:%M:%S")
    draw.SimpleText(t, "GRM_CCTV_Meta", w - 16, 14, Color(200, 200, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    draw.SimpleText(
        "[RMB / ESC / E] выйти с камеры",
        "GRM_CCTV_Meta", w * 0.5, h - 36, Color(220, 220, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP
    )
end)

local function stopView()
    if not ViewState.active then return end
    sendAction("stop_view", ViewState.monitor)
    ViewState.active = false
end

hook.Add("PlayerButtonDown", "GRM_CCTV_ExitKeys", function(ply, btn)
    if not ViewState.active then return end
    if ply ~= LocalPlayer() then return end
    if btn == MOUSE_RIGHT or btn == KEY_ESCAPE or btn == KEY_E then
        stopView()
    end
end)

-- also bind +use edge
hook.Add("KeyPress", "GRM_CCTV_ExitUse", function(ply, key)
    if ply ~= LocalPlayer() or not ViewState.active then return end
    if key == IN_USE or key == IN_ATTACK2 then
        stopView()
    end
end)

concommand.Add("grm_cctv_stop", function()
    stopView()
end)

print("[GRM CCTV] client v1.0.0")
