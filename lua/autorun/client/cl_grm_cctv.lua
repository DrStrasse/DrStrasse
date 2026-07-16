--[[--------------------------------------------------------------------
    GRM CCTV — client v1.2.0
    UI, live view, pan, zoom, freeze local input, screenshots, help HUD.
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
local NET_SHOT_OK    = "GRM_CCTV_ShotOk"

local ViewState = {
    active = false,
    cam = NULL,
    monitor = NULL,
    label = "",
    network = "",
    baseFov = 75,
    fov = 75,
    allowPan = true,
    yawMax = 55,
    pitchMax = 35,
    sens = 0.06,
    yawOff = 0,
    pitchOff = 0,
    baseAng = Angle(0, 0, 0),
    allowZoom = true,
    zoomStep = 4,
    zoomMin = 25,
    zoomMax = 100,
    shotEnabled = true,
    shotDir = "grm_cctv/screenshots",
    shotFormat = "jpeg",
    shotQuality = 90,
    shotHideUI = true,
    shotCooldown = 1.0,
    shotMap = "map",
    shotCamId = "cam",
    hideOverlay = false,
    lastShot = 0,
    flashUntil = 0,
    lastShotPath = "",
    pendingShot = false,
    shotRT = nil,
    shotRTW = 0,
    shotRTH = 0,
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
        entry:SetMin(10)
        entry:SetMax(150)
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

local function safePart(s)
    s = string.lower(tostring(s or "x"))
    s = string.gsub(s, "[^%w%-%_]", "_")
    if s == "" then s = "x" end
    return string.sub(s, 1, 40)
end

local function ensureShotDirs(relFile)
    -- relFile like grm_cctv/screenshots/main/cam/file.jpg
    local parts = string.Explode("/", relFile)
    local acc = ""
    for i = 1, #parts - 1 do
        acc = (acc == "") and parts[i] or (acc .. "/" .. parts[i])
        if not file.IsDir(acc, "DATA") then
            file.CreateDir(acc)
        end
    end
end

net.Receive(NET_NOTIFY, function()
    local ok = net.ReadBool()
    local msg = net.ReadString() or ""
    if GRM and isfunction(GRM.Notify) then
        GRM.Notify(LocalPlayer(), msg, ok and 100 or 255, ok and 220 or 120, ok and 100 or 120)
    else
        chat.AddText(ok and Color(100, 220, 100) or Color(255, 120, 120), "[CCTV] ", color_white, msg)
    end
end)

net.Receive(NET_SHOT_OK, function()
    local path = net.ReadString() or ""
    ViewState.lastShotPath = path
    ViewState.flashUntil = CurTime() + 0.35
end)

-- ── config menus (camera / server / monitor) ───────────────
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
        sendAction("set_fov", ent, function() net.WriteUInt(math.Clamp(tonumber(fov:GetValue()) or 75, 10, 150), 8) end)
        sendAction("set_active", ent, function() net.WriteBool(active:GetChecked()) end)
        sendAction("set_permanent", ent, function() net.WriteBool(perm:GetChecked()) end)
        f:Close()
    end)
    addBtn(f, 150, 230, 100, 28, "Отмена", nil, function() f:Close() end)
end)

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
    addBtn(f, 15, 205, 120, 28, "Сохранить", Color(100, 220, 120), function()
        sendAction("set_label", ent, function() net.WriteString(label:GetValue()) end)
        sendAction("set_network", ent, function() net.WriteString(network:GetValue()) end)
        sendAction("set_active", ent, function() net.WriteBool(active:GetChecked()) end)
        sendAction("set_permanent", ent, function() net.WriteBool(perm:GetChecked()) end)
        f:Close()
    end)
    addBtn(f, 150, 205, 100, 28, "Отмена", nil, function() f:Close() end)
end)

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
        status:SetText("Сервер сети: OFFLINE — просмотр недоступен")
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
        local line = list:AddLine(tostring(i), cam.label or "Камера", cam.active and "ONLINE" or "OFF",
            tostring(cam.fov or 75), string.sub(cam.id or "", 1, 16))
        line._camEnt = cam.ent
        line._active = cam.active
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
            chat.AddText(Color(255, 200, 100), "[CCTV] ", color_white, "Выбери камеру.")
            return
        end
        if not active then
            chat.AddText(Color(255, 140, 100), "[CCTV] ", color_white, "Камера выключена.")
            return
        end
        sendAction("view_cam", monitor, function() net.WriteEntity(cam) end)
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
        if not hasSrv then return end
        local cam, active = selectedCam()
        if IsValid(cam) and active then
            sendAction("view_cam", monitor, function() net.WriteEntity(cam) end)
            f:Close()
        end
    end
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
    if IsValid(mon) then buildMonitorUI(mon, netID, hasSrv, canCfg, cams) end
end)

net.Receive(NET_LIST, function()
    local mon = net.ReadEntity()
    local netID = net.ReadString()
    local hasSrv = net.ReadBool()
    local n = net.ReadUInt(8)
    local cams = readCamList(n)
    if IsValid(mon) then buildMonitorUI(mon, netID, hasSrv, true, cams) end
end)

-- ── live view ──────────────────────────────────────────────
local function resetPan()
    ViewState.yawOff = 0
    ViewState.pitchOff = 0
    if IsValid(ViewState.cam) then
        ViewState.baseAng = ViewState.cam:GetAngles()
    else
        ViewState.baseAng = Angle(0, 0, 0)
    end
end

local function stopView()
    if not ViewState.active then return end
    sendAction("stop_view", ViewState.monitor)
    ViewState.active = false
    ViewState.cam = NULL
    ViewState.monitor = NULL
    ViewState.yawOff = 0
    ViewState.pitchOff = 0
    ViewState.hideOverlay = false
    gui.EnableScreenClicker(false)
end

local function clampZoom(fov)
    return math.Clamp(tonumber(fov) or 75, ViewState.zoomMin or 25, ViewState.zoomMax or 100)
end

local function applyZoomDelta(dir)
    if not ViewState.active or not ViewState.allowZoom then return end
    -- dir > 0 = zoom in (меньший FOV), dir < 0 = zoom out
    local step = ViewState.zoomStep or 4
    ViewState.fov = clampZoom((ViewState.fov or 75) - dir * step)
end

-- Снимок через RenderView в RT: обычный render.Capture экрана при SetViewEntity
-- часто даёт ЧЁРНЫЙ кадр (буфер viewentity не тот). Рендерим вид камеры сами.
local function getShotView()
    local cam = ViewState.cam
    if not IsValid(cam) then return nil end
    local base = ViewState.baseAng or cam:GetAngles()
    local viewAng = Angle(base.p, base.y, base.r)
    viewAng:RotateAroundAxis(viewAng:Up(), ViewState.yawOff or 0)
    viewAng:RotateAroundAxis(viewAng:Right(), ViewState.pitchOff or 0)
    local origin = cam:GetPos() + viewAng:Forward() * 6 + viewAng:Up() * 2
    return origin, viewAng, ViewState.fov or cam:GetCamFOV() or 75
end

local function getShotRT(w, h)
    w = math.floor(math.Clamp(w or ScrW(), 320, 1920))
    h = math.floor(math.Clamp(h or ScrH(), 240, 1080))
    if not ViewState.shotRT or ViewState.shotRTW ~= w or ViewState.shotRTH ~= h then
        ViewState.shotRT = GetRenderTargetEx(
            "GRM_CCTV_ShotRT_" .. w .. "x" .. h,
            w, h,
            RT_SIZE_NO_CHANGE,
            MATERIAL_RT_DEPTH_SEPARATE,
            0, 0,
            IMAGE_FORMAT_RGB888
        )
        ViewState.shotRTW = w
        ViewState.shotRTH = h
    end
    return ViewState.shotRT, w, h
end

local function finishScreenshot(data, rel)
    ViewState.hideOverlay = false
    ViewState.pendingShot = false
    if not data or data == "" then
        chat.AddText(Color(255, 120, 120), "[CCTV] ", color_white, "Скриншот пустой (чёрный/ошибка захвата).")
        return
    end
    -- грубая проверка «всё чёрное»: слишком маленький jpeg/png почти всегда брак
    if #data < 800 then
        chat.AddText(Color(255, 160, 80), "[CCTV] ", color_white, "Снимок подозрительно мал — возможно, чёрный кадр. Попробуйте ещё раз.")
    end
    ensureShotDirs(rel)
    file.Write(rel, data)
    ViewState.lastShotPath = rel
    ViewState.flashUntil = CurTime() + 0.45
    sendAction("screenshot", ViewState.monitor, function()
        net.WriteString(rel)
        net.WriteString(ViewState.label or "")
    end)
    chat.AddText(Color(100, 220, 140), "[CCTV] ", color_white, "Скриншот: ", Color(180, 220, 255), "garrysmod/data/" .. rel)
end

local function takeScreenshot()
    if not ViewState.active or not ViewState.shotEnabled then return end
    if ViewState.pendingShot then return end
    local now = CurTime()
    if now < (ViewState.lastShot or 0) + (ViewState.shotCooldown or 1) then
        chat.AddText(Color(255, 200, 100), "[CCTV] ", color_white, "Подождите перед следующим снимком.")
        return
    end
    if not IsValid(ViewState.cam) then return end

    ViewState.lastShot = now
    ViewState.pendingShot = true
    if ViewState.shotHideUI ~= false then
        ViewState.hideOverlay = true
    end
end

-- Захват строго в PostRender: RT + RenderView (не framebuffer ViewEntity)
hook.Add("PostRender", "GRM_CCTV_CaptureShot", function()
    if not ViewState.pendingShot then return end
    if not ViewState.active or not IsValid(ViewState.cam) then
        ViewState.pendingShot = false
        ViewState.hideOverlay = false
        return
    end

    local origin, angles, fov = getShotView()
    if not origin then
        ViewState.pendingShot = false
        ViewState.hideOverlay = false
        chat.AddText(Color(255, 120, 120), "[CCTV] ", color_white, "Нет вида камеры для снимка.")
        return
    end

    local fmt = string.lower(ViewState.shotFormat or "jpeg")
    if fmt ~= "png" then fmt = "jpeg" end
    local ext = (fmt == "png") and "png" or "jpg"
    local stamp = os.date("%Y%m%d_%H%M%S")
    local netPart = safePart(ViewState.network)
    local camPart = safePart(ViewState.shotCamId)
    local mapPart = safePart(ViewState.shotMap)
    local dir = tostring(ViewState.shotDir or "grm_cctv/screenshots")
    dir = string.gsub(dir, "^/+", "")
    dir = string.gsub(dir, "%.%.", "")
    local rel = string.format("%s/%s/%s/%s_%s_%s_%s.%s",
        dir, netPart, camPart, mapPart, netPart, camPart, stamp, ext)

    -- разрешение снимка (не обязательно full HD — стабильнее)
    local sw, sh = ScrW(), ScrH()
    local capW = math.min(sw, 1280)
    local capH = math.floor(capW * (sh / math.max(sw, 1)))
    capH = math.Clamp(capH, 240, 720)

    local rt, w, h = getShotRT(capW, capH)
    local data
    local ok, err = pcall(function()
        local oldW, oldH = ScrW(), ScrH()
        render.PushRenderTarget(rt)
        render.Clear(0, 0, 0, 255, true, true)
        render.SetViewPort(0, 0, w, h)

        -- Явно рисуем мир с точки камеры (обходит чёрный SetViewEntity-буфер)
        render.RenderView({
            origin = origin,
            angles = angles,
            x = 0, y = 0,
            w = w, h = h,
            fov = fov,
            aspectratio = w / math.max(h, 1),
            drawhud = false,
            drawviewmodel = false,
            drawmonitors = true,
            dopostprocess = false,
            bloomtone = false,
        })

        render.CapturePixels() -- на части билдов стабилизирует Capture из RT
        data = render.Capture({
            format = fmt,
            quality = math.Clamp(tonumber(ViewState.shotQuality) or 90, 10, 100),
            x = 0, y = 0,
            w = w, h = h,
            alpha = false,
        })

        render.SetViewPort(0, 0, oldW, oldH)
        render.PopRenderTarget()
    end)

    if not ok then
        ViewState.pendingShot = false
        ViewState.hideOverlay = false
        chat.AddText(Color(255, 120, 120), "[CCTV] ", color_white, "Ошибка снимка: " .. tostring(err))
        -- на всякий случай снимем RT
        pcall(function() render.PopRenderTarget() end)
        return
    end

    finishScreenshot(data, rel)
end)

net.Receive(NET_VIEW, function()
    local cam = net.ReadEntity()
    local mon = net.ReadEntity()
    local label = net.ReadString()
    local network = net.ReadString()
    local fov = net.ReadUInt(8)
    local allowPan = net.ReadBool()
    local yawMax = net.ReadUInt(8)
    local pitchMax = net.ReadUInt(8)
    local sens = net.ReadFloat()
    local allowZoom = net.ReadBool()
    local zoomStep = net.ReadUInt(8)
    local zoomMin = net.ReadUInt(8)
    local zoomMax = net.ReadUInt(8)
    local shotEnabled = net.ReadBool()
    local shotDir = net.ReadString()
    local shotFormat = net.ReadString()
    local shotQuality = net.ReadUInt(8)
    local shotHideUI = net.ReadBool()
    local shotCooldown = net.ReadFloat()
    local shotMap = net.ReadString()
    local shotCamId = net.ReadString()

    ViewState.active = true
    ViewState.cam = cam
    ViewState.monitor = mon
    ViewState.label = label
    ViewState.network = network
    ViewState.baseFov = fov
    ViewState.fov = fov
    ViewState.allowPan = allowPan
    ViewState.yawMax = yawMax
    ViewState.pitchMax = pitchMax
    ViewState.sens = (sens and sens > 0) and sens or 0.06
    ViewState.allowZoom = allowZoom
    ViewState.zoomStep = zoomStep
    ViewState.zoomMin = zoomMin
    ViewState.zoomMax = zoomMax
    ViewState.shotEnabled = shotEnabled
    ViewState.shotDir = shotDir
    ViewState.shotFormat = shotFormat
    ViewState.shotQuality = shotQuality
    ViewState.shotHideUI = shotHideUI
    ViewState.shotCooldown = shotCooldown
    ViewState.shotMap = shotMap
    ViewState.shotCamId = shotCamId
    ViewState.hideOverlay = false
    resetPan()

    if IsValid(CCTV._monFrame) then CCTV._monFrame:Close() end
    gui.EnableScreenClicker(false)
end)

net.Receive(NET_VIEW_STOP, function()
    ViewState.active = false
    ViewState.cam = NULL
    ViewState.monitor = NULL
    ViewState.yawOff = 0
    ViewState.pitchOff = 0
    ViewState.hideOverlay = false
    gui.EnableScreenClicker(false)
end)

hook.Add("InputMouseApply", "GRM_CCTV_MousePan", function(cmd, x, y, ang)
    if not ViewState.active or not ViewState.allowPan then return end
    if not IsValid(ViewState.cam) then return end
    local sens = ViewState.sens or 0.06
    ViewState.yawOff = math.Clamp((ViewState.yawOff or 0) - x * sens, -(ViewState.yawMax or 55), (ViewState.yawMax or 55))
    ViewState.pitchOff = math.Clamp((ViewState.pitchOff or 0) + y * sens, -(ViewState.pitchMax or 35), (ViewState.pitchMax or 35))
    cmd:SetMouseX(0)
    cmd:SetMouseY(0)
    return true
end)

-- Колёсико: приблизить / отдалить
hook.Add("PlayerBindPress", "GRM_CCTV_ZoomBinds", function(ply, bind, pressed)
    if not ViewState.active or ply ~= LocalPlayer() then return end
    bind = string.lower(tostring(bind or ""))
    if not pressed then
        if string.find(bind, "invnext", 1, true) or string.find(bind, "invprev", 1, true) then
            return true -- block weapon switch even on release
        end
        return
    end
    if string.find(bind, "invnext", 1, true) then
        applyZoomDelta(-1) -- scroll down = out
        return true
    end
    if string.find(bind, "invprev", 1, true) then
        applyZoomDelta(1) -- scroll up = in
        return true
    end
end)

hook.Add("CalcView", "GRM_CCTV_CalcView", function(ply, pos, ang, fov)
    if not ViewState.active then return end
    local cam = ViewState.cam
    if not IsValid(cam) then return end
    local base = ViewState.baseAng or cam:GetAngles()
    local viewAng = Angle(base.p, base.y, base.r)
    viewAng:RotateAroundAxis(viewAng:Up(), ViewState.yawOff or 0)
    viewAng:RotateAroundAxis(viewAng:Right(), ViewState.pitchOff or 0)
    local origin = cam:GetPos() + viewAng:Forward() * 6 + viewAng:Up() * 2
    return {
        origin = origin,
        angles = viewAng,
        fov = ViewState.fov or cam:GetCamFOV() or 75,
        drawviewer = false,
    }
end)

hook.Add("CreateMove", "GRM_CCTV_CreateMove", function(cmd)
    if not ViewState.active then return end
    cmd:ClearMovement()
    cmd:SetButtons(0)
    cmd:SetForwardMove(0)
    cmd:SetSideMove(0)
    cmd:SetUpMove(0)
end)

hook.Add("HUDShouldDraw", "GRM_CCTV_HideHUD", function(name)
    if not ViewState.active then return end
    if name == "CHudWeaponSelection" or name == "CHudAmmo" or name == "CHudSecondaryAmmo" then
        return false
    end
end)

surface.CreateFont("GRM_CCTV_Title", { font = "Roboto", size = 22, weight = 700, extended = true })
surface.CreateFont("GRM_CCTV_Meta", { font = "Roboto", size = 16, weight = 500, extended = true })
surface.CreateFont("GRM_CCTV_Help", { font = "Roboto", size = 16, weight = 600, extended = true })
surface.CreateFont("GRM_CCTV_HelpTitle", { font = "Roboto", size = 17, weight = 800, extended = true })
surface.CreateFont("GRM_CCTV_Key", { font = "Roboto", size = 14, weight = 700, extended = true })

local function drawKeyChip(x, y, keyText, desc, alpha)
    alpha = alpha or 230
    surface.SetFont("GRM_CCTV_Key")
    local kw, kh = surface.GetTextSize(keyText)
    local padX, padY = 7, 3
    local boxW, boxH = kw + padX * 2, kh + padY * 2
    surface.SetDrawColor(20, 28, 22, alpha)
    surface.DrawRect(x, y, boxW, boxH)
    surface.SetDrawColor(90, 220, 130, alpha)
    surface.DrawOutlinedRect(x, y, boxW, boxH, 1)
    draw.SimpleText(keyText, "GRM_CCTV_Key", x + boxW * 0.5, y + boxH * 0.5,
        Color(200, 255, 210, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    if desc and desc ~= "" then
        draw.SimpleText(desc, "GRM_CCTV_Help", x + boxW + 8, y + boxH * 0.5,
            Color(230, 235, 230, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return boxH
end

hook.Add("HUDPaint", "GRM_CCTV_Overlay", function()
    if not ViewState.active then return end
    if ViewState.hideOverlay then return end

    local w, h = ScrW(), ScrH()
    local helpH = 148

    surface.SetDrawColor(0, 0, 0, 190)
    surface.DrawRect(0, 0, w, 56)
    surface.SetDrawColor(0, 0, 0, 205)
    surface.DrawRect(0, h - helpH, w, helpH)

    surface.SetDrawColor(0, 255, 120, 10)
    for y = 56, h - helpH, 4 do
        surface.DrawRect(0, y, w, 1)
    end

    local blink = (math.floor(CurTime() * 2) % 2 == 0)
    if blink then
        surface.SetDrawColor(220, 40, 40, 230)
        draw.NoTexture()
        surface.DrawRect(18, 20, 12, 12)
    end
    draw.SimpleText("REC  LIVE", "GRM_CCTV_Meta", 38, 18, Color(255, 80, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

    draw.SimpleText(ViewState.label ~= "" and ViewState.label or "Камера",
        "GRM_CCTV_Title", w * 0.5, 8, Color(220, 255, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    local zoomPct = 0
    do
        local zmin, zmax = ViewState.zoomMin or 25, ViewState.zoomMax or 100
        local f = ViewState.fov or 75
        if zmax > zmin then
            zoomPct = math.floor((1 - (f - zmin) / (zmax - zmin)) * 100 + 0.5)
        end
    end
    draw.SimpleText(
        string.format("сеть: %s  ·  FOV %d  ·  зум %d%%",
            tostring(ViewState.network or "?"), tonumber(ViewState.fov) or 75, zoomPct),
        "GRM_CCTV_Meta", w * 0.5, 34, Color(160, 200, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

    draw.SimpleText(os.date("%Y-%m-%d %H:%M:%S"), "GRM_CCTV_Meta", w - 16, 18,
        Color(200, 200, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    -- crosshair
    local cx, cy = w * 0.5, h * 0.5
    surface.SetDrawColor(80, 255, 120, 150)
    surface.DrawLine(cx - 10, cy, cx + 10, cy)
    surface.DrawLine(cx, cy - 10, cx, cy + 10)

    -- flash on shot
    if CurTime() < (ViewState.flashUntil or 0) then
        surface.SetDrawColor(255, 255, 255, 60)
        surface.DrawRect(0, 0, w, h)
    end

    -- help panel
    local baseY = h - helpH + 8
    draw.SimpleText("УПРАВЛЕНИЕ КАМЕРОЙ", "GRM_CCTV_HelpTitle", 16, baseY, Color(120, 230, 150))

    local col1, col2, col3 = 16, math.floor(w * 0.34), math.floor(w * 0.66)
    local y1, y2, y3 = baseY + 24, baseY + 24, baseY + 24

    -- col1 pan
    draw.SimpleText("Обзор:", "GRM_CCTV_Help", col1, y1, Color(180, 200, 180))
    y1 = y1 + 18
    if ViewState.allowPan then
        y1 = y1 + drawKeyChip(col1, y1, "МЫШЬ ← →", "смотреть влево / вправо") + 5
        y1 = y1 + drawKeyChip(col1, y1, "МЫШЬ ↑ ↓", "смотреть вверх / вниз") + 4
        draw.SimpleText(string.format("углы: %+.0f° / %+.0f° (±%d / ±%d)",
            ViewState.yawOff or 0, ViewState.pitchOff or 0, ViewState.yawMax or 55, ViewState.pitchMax or 35),
            "GRM_CCTV_Meta", col1, y1, Color(140, 175, 140))
    else
        draw.SimpleText("поворот выключен", "GRM_CCTV_Help", col1, y1, Color(200, 180, 120))
    end

    -- col2 zoom
    draw.SimpleText("Зум / масштаб:", "GRM_CCTV_Help", col2, y2, Color(180, 200, 180))
    y2 = y2 + 18
    if ViewState.allowZoom then
        y2 = y2 + drawKeyChip(col2, y2, "КОЛЁСИКО ↑", "приблизить (zoom in)") + 5
        y2 = y2 + drawKeyChip(col2, y2, "КОЛЁСИКО ↓", "отдалить (zoom out)") + 5
        y2 = y2 + drawKeyChip(col2, y2, "+ / =", "приблизить") + 5
        y2 = y2 + drawKeyChip(col2, y2, "-", "отдалить") + 4
        draw.SimpleText(string.format("FOV %d  (ближе %d … шире %d)",
            tonumber(ViewState.fov) or 75, ViewState.zoomMin or 25, ViewState.zoomMax or 100),
            "GRM_CCTV_Meta", col2, y2, Color(140, 175, 140))
    else
        draw.SimpleText("зум выключен", "GRM_CCTV_Help", col2, y2, Color(200, 180, 120))
    end

    -- col3 exit + shot
    draw.SimpleText("Снимок и выход:", "GRM_CCTV_Help", col3, y3, Color(180, 200, 180))
    y3 = y3 + 18
    if ViewState.shotEnabled then
        y3 = y3 + drawKeyChip(col3, y3, "F", "сделать скриншот") + 5
        y3 = y3 + drawKeyChip(col3, y3, "ПРОБЕЛ", "сделать скриншот") + 4
    end
    y3 = y3 + drawKeyChip(col3, y3, "ПКМ", "выйти из режима") + 5
    y3 = y3 + drawKeyChip(col3, y3, "ESC / E", "выйти из режима") + 4

    local pathHint = ViewState.lastShotPath ~= "" and ("последний: data/" .. ViewState.lastShotPath)
        or ("папка: garrysmod/data/" .. tostring(ViewState.shotDir or "grm_cctv/screenshots") .. "/…")
    draw.SimpleText(
        pathHint .. "   |   тело у монитора стоит   |   !camexit / grm_cctv_stop",
        "GRM_CCTV_Meta", w * 0.5, h - 14, Color(150, 160, 150), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)

-- keys: exit / zoom / screenshot
local function onExitButton(btn)
    if not ViewState.active then return end
    if btn == MOUSE_RIGHT or btn == KEY_ESCAPE or btn == KEY_E
        or btn == KEY_BACKSPACE or btn == KEY_Q then
        stopView()
        return true
    end
    -- zoom keys
    if ViewState.allowZoom then
        if btn == KEY_EQUAL or btn == KEY_PAD_PLUS then
            applyZoomDelta(1)
            return true
        end
        if btn == KEY_MINUS or btn == KEY_PAD_MINUS then
            applyZoomDelta(-1)
            return true
        end
    end
    -- screenshot (Space used for shot; not exit)
    if ViewState.shotEnabled and (btn == KEY_F or btn == KEY_SPACE) then
        takeScreenshot()
        return true
    end
end

hook.Add("PlayerButtonDown", "GRM_CCTV_Keys", function(ply, btn)
    if ply ~= LocalPlayer() then return end
    onExitButton(btn)
end)

hook.Add("KeyPress", "GRM_CCTV_KeyPress", function(ply, key)
    if ply ~= LocalPlayer() or not ViewState.active then return end
    if key == IN_USE or key == IN_ATTACK2 then
        stopView()
    elseif key == IN_JUMP and ViewState.shotEnabled then
        -- Space also fires KeyPress JUMP — screenshot already via PlayerButtonDown
    end
end)

hook.Add("Think", "GRM_CCTV_ExitThink", function()
    if not ViewState.active then return end
    if input.IsKeyDown(KEY_ESCAPE) or input.IsMouseDown(MOUSE_RIGHT) then
        local now = CurTime()
        if (ViewState._exitCD or 0) > now then return end
        ViewState._exitCD = now + 0.25
        stopView()
    end
end)

hook.Add("Think", "GRM_CCTV_CamValid", function()
    if ViewState.active and not IsValid(ViewState.cam) then
        stopView()
    end
end)

concommand.Add("grm_cctv_stop", function() stopView() end)
concommand.Add("grm_cctv_shot", function() takeScreenshot() end)

hook.Add("OnPlayerChat", "GRM_CCTV_ChatExit", function(ply, text)
    if ply ~= LocalPlayer() or not ViewState.active then return end
    local t = string.Trim(string.lower(tostring(text or "")))
    if t == "!camexit" or t == "/camexit" or t == "!cctvexit" then
        stopView()
        return true
    end
    if t == "!camshot" or t == "/camshot" then
        takeScreenshot()
        return true
    end
end)

print("[GRM CCTV] client v1.2.1")
