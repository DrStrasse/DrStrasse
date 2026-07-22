--[[--------------------------------------------------------------------
    GRM Phone Lines System - Client
--------------------------------------------------------------------]]

if not CLIENT then return end

include("autorun/sh_grm_phone_config.lua")

GRM = GRM or {}
GRM.Phone = GRM.Phone or {}

local NET_OPEN_PHONE   = "GRM_Phone_OpenPhone"
local NET_OPEN_PBX     = "GRM_Phone_OpenPBX"
local NET_OPEN_WIRETAP = "GRM_Phone_OpenWiretap"
local NET_OPEN_TERMINAL = "GRM_Phone_OpenTerminal"
local NET_ACTION       = "GRM_Phone_Action"
local NET_INFO         = "GRM_Phone_Info"
local NET_TEXT         = "GRM_Phone_Text"

local THEME = {
    bg = Color(24, 26, 32, 245),
    panel = Color(35, 38, 48, 240),
    accent = Color(80, 170, 255),
    green = Color(70, 190, 100),
    red = Color(210, 70, 60),
    text = Color(235, 235, 240),
    dim = Color(170, 175, 185),
}

surface.CreateFont("GRMPhone_Title", { font = "Roboto", size = 20, weight = 700, extended = true })
surface.CreateFont("GRMPhone_Normal", { font = "Roboto", size = 14, weight = 500, extended = true })

local function action(ent, name, writer)
    if not IsValid(ent) then return end
    net.Start(NET_ACTION)
        net.WriteString(name)
        net.WriteEntity(ent)
        if writer then writer() end
    net.SendToServer()
end

local function btn(parent, text, color)
    local b = vgui.Create("DButton", parent)
    b:SetText(text)
    b:SetFont("GRMPhone_Normal")
    b:SetTextColor(color_white)
    b.Paint = function(s, w, h)
        local c = s:IsHovered() and Color(math.min(color.r + 25, 255), math.min(color.g + 25, 255), math.min(color.b + 25, 255)) or color
        draw.RoundedBox(6, 0, 0, w, h, c)
    end
    return b
end

net.Receive(NET_INFO, function()
    local msg = net.ReadString()
    local bad = net.ReadBool()
    chat.AddText(bad and Color(255, 80, 80) or Color(100, 200, 255), "[Телефон] ", color_white, msg)
    surface.PlaySound(bad and "buttons/button10.wav" or "buttons/button17.wav")
end)

-- NET_SYNC: сервер рассылает актуальное состояние сущностей линий
-- (P.SyncEntity → broadcast). Приёмника раньше не было — пакеты падали
-- в никуда (аудит протоколов). Сообщение самодостаточно: нижнечтение
-- безопасно. Кэшируем без изменения поведения — пригодится UI телефона.
local NET_SYNC_PH = "GRM_Phone_Sync"
net.Receive(NET_SYNC_PH, function()
    local ent = net.ReadEntity()
    local class = net.ReadString()
    if not IsValid(ent) then return end
    local rec = { class = class }
    local ok = pcall(function()
        if class == "grm_phone" or class == "grm_payphone" then
            rec.number = net.ReadString()
            rec.displayName = net.ReadString()
            rec.exchange = net.ReadString()
            rec.lineState = net.ReadString()
            rec.callId = net.ReadUInt(16)
        elseif class == "grm_pbx_station" then
            rec.exchange = net.ReadString()
            rec.active = net.ReadBool()
            rec.maxLines = net.ReadUInt(12)
        elseif class == "grm_phone_wiretap" then
            rec.targetNumber = net.ReadString()
            rec.exchange = net.ReadString()
            rec.active = net.ReadBool()
        end
    end)
    if not ok then return end
    GRM.Phone._syncCache = GRM.Phone._syncCache or {}
    GRM.Phone._syncCache[ent] = rec
end)

net.Receive(NET_TEXT, function()
    local speaker = net.ReadEntity()
    local callID = net.ReadUInt(16)
    local fromNumber = net.ReadString()
    local toNumber = net.ReadString()
    local msg = net.ReadString()
    local intercepted = net.ReadBool()

    local name = IsValid(speaker) and speaker:Nick() or "Неизвестно"
    if intercepted then
        chat.AddText(Color(255, 170, 60), "[ПРОСЛУШКА #" .. callID .. " " .. fromNumber .. "↔" .. toNumber .. "] ", Color(120, 200, 255), name, color_white, ": " .. msg)
    else
        chat.AddText(Color(100, 200, 255), "[ТЕЛЕФОН #" .. callID .. " " .. fromNumber .. "↔" .. toNumber .. "] ", Color(120, 220, 255), name, color_white, ": " .. msg)
    end
    surface.PlaySound("buttons/button17.wav")
end)

net.Receive(NET_OPEN_PHONE, function()
    local ent = net.ReadEntity()
    local number = net.ReadString()
    local name = net.ReadString()
    local exchange = net.ReadString()
    local state = net.ReadString()
    local callID = net.ReadUInt(16)

    local f = vgui.Create("DFrame")
    f:SetTitle("")
    f:SetSize(360, 310)
    f:Center()
    f:MakePopup()
    f.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, THEME.bg)
        draw.SimpleText("Стационарный телефон", "GRMPhone_Title", 14, 18, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(name .. " | № " .. number .. " | АТС: " .. exchange, "GRMPhone_Normal", 14, 48, THEME.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Статус: " .. state .. (callID > 0 and (" | call #" .. callID) or ""), "GRMPhone_Normal", 14, 72, THEME.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local dial = vgui.Create("DTextEntry", f)
    dial:SetPos(14, 100)
    dial:SetSize(332, 28)
    dial:SetPlaceholderText("Номер телефона")
    dial:SetNumeric(true)

    local dialBtn = btn(f, "Позвонить", THEME.green)
    dialBtn:SetPos(14, 140); dialBtn:SetSize(158, 34)
    dialBtn.DoClick = function()
        action(ent, "phone_dial", function() net.WriteString(dial:GetText()) end)
    end

    local answerBtn = btn(f, "Ответить", THEME.accent)
    answerBtn:SetPos(188, 140); answerBtn:SetSize(158, 34)
    answerBtn.DoClick = function() action(ent, "phone_answer") end

    local pickupBtn = btn(f, "Взять трубку", Color(110, 120, 210))
    pickupBtn:SetPos(14, 184); pickupBtn:SetSize(158, 34)
    pickupBtn.DoClick = function() action(ent, "phone_pickup") end

    local releaseBtn = btn(f, "Положить трубку", Color(120, 120, 130))
    releaseBtn:SetPos(188, 184); releaseBtn:SetSize(158, 34)
    releaseBtn.DoClick = function() action(ent, "phone_release") end

    local hangBtn = btn(f, "Завершить вызов", THEME.red)
    hangBtn:SetPos(14, 230); hangBtn:SetSize(332, 42)
    hangBtn.DoClick = function() action(ent, "phone_hangup") end
end)

net.Receive(NET_OPEN_PBX, function()
    local ent = net.ReadEntity()
    local exchange = net.ReadString()
    local active = net.ReadBool()
    local maxLines = net.ReadUInt(12)

    local f = vgui.Create("DFrame")
    f:SetTitle("АТС")
    f:SetSize(380, 230)
    f:Center(); f:MakePopup()

    local entry = vgui.Create("DTextEntry", f)
    entry:SetPos(14, 40); entry:SetSize(352, 28); entry:SetText(exchange)

    local check = vgui.Create("DCheckBoxLabel", f)
    check:SetPos(14, 78); check:SetSize(300, 24); check:SetText("АТС активна"); check:SetValue(active)

    local lbl = vgui.Create("DLabel", f)
    lbl:SetPos(14, 110); lbl:SetSize(180, 20); lbl:SetText("Количество линий:")

    local lines = vgui.Create("DNumberWang", f)
    lines:SetPos(150, 106); lines:SetSize(100, 28); lines:SetMin(1); lines:SetMax(4095); lines:SetValue(maxLines > 0 and maxLines or 60)

    local hint = vgui.Create("DLabel", f)
    hint:SetPos(14, 138); hint:SetSize(350, 22); hint:SetText("Обычно ставьте 50-70 линий связи.")
    hint:SetTextColor(THEME.dim)

    local save = btn(f, "Сохранить", THEME.green)
    save:SetPos(14, 172); save:SetSize(352, 34)
    save.DoClick = function()
        action(ent, "pbx_set", function()
            net.WriteString(entry:GetText())
            net.WriteBool(check:GetChecked())
            net.WriteUInt(math.Clamp(tonumber(lines:GetValue()) or 60, 1, 4095), 12)
        end)
        f:Close()
    end
end)

net.Receive(NET_OPEN_WIRETAP, function()
    local ent = net.ReadEntity()
    local target = net.ReadString()
    local exchange = net.ReadString()
    local active = net.ReadBool()

    local f = vgui.Create("DFrame")
    f:SetTitle("Оборудование прослушки")
    f:SetSize(400, 250)
    f:Center(); f:MakePopup()

    local targetEntry = vgui.Create("DTextEntry", f)
    targetEntry:SetPos(14, 42); targetEntry:SetSize(372, 28); targetEntry:SetPlaceholderText("Целевой номер, например 1001"); targetEntry:SetText(target)

    local exchangeEntry = vgui.Create("DTextEntry", f)
    exchangeEntry:SetPos(14, 82); exchangeEntry:SetSize(372, 28); exchangeEntry:SetPlaceholderText("АТС для прослушки, например main"); exchangeEntry:SetText(exchange)

    local check = vgui.Create("DCheckBoxLabel", f)
    check:SetPos(14, 120); check:SetSize(300, 24); check:SetText("Прослушка активна"); check:SetValue(active)

    local save = btn(f, "Сохранить настройки", THEME.green)
    save:SetPos(14, 152); save:SetSize(180, 34)
    save.DoClick = function()
        action(ent, "wiretap_set", function() net.WriteString(targetEntry:GetText()); net.WriteString(exchangeEntry:GetText()); net.WriteBool(check:GetChecked()) end)
    end

    local mon = btn(f, "Слушать", THEME.accent)
    mon:SetPos(206, 152); mon:SetSize(180, 34)
    mon.DoClick = function() action(ent, "wiretap_monitor") end

    local stop = btn(f, "Остановить прослушку", THEME.red)
    stop:SetPos(14, 196); stop:SetSize(372, 34)
    stop.DoClick = function() action(ent, "wiretap_stop") end
end)

net.Receive(NET_OPEN_TERMINAL, function()
    local ent = net.ReadEntity()
    local data = net.ReadTable() or { phones = {}, exchanges = {}, calls = {} }

    local f = vgui.Create("DFrame")
    f:SetTitle("Компьютер мониторинга связи")
    f:SetSize(760, 560)
    f:Center()
    f:MakePopup()

    local tabs = vgui.Create("DPropertySheet", f)
    tabs:Dock(FILL)
    tabs:DockMargin(6, 6, 6, 46)

    local function makeList(parent, columns)
        local list = vgui.Create("DListView", parent)
        list:Dock(FILL)
        for _, col in ipairs(columns) do list:AddColumn(col) end
        return list
    end

    local phonesPanel = vgui.Create("DPanel")
    phonesPanel:SetPaintBackground(false)
    local phonesList = makeList(phonesPanel, { "Номер", "Имя", "АТС", "Статус", "CallID", "Тип" })
    for _, row in ipairs(data.phones or {}) do
        phonesList:AddLine(row.number or "", row.name or "", row.exchange or "", row.state or "", row.callID or 0, row.class or "")
    end
    tabs:AddSheet("Телефоны", phonesPanel, "icon16/telephone.png")

    local exPanel = vgui.Create("DPanel")
    exPanel:SetPaintBackground(false)
    local exList = makeList(exPanel, { "АТС", "Активна", "Занято линий", "Всего линий", "Свободно" })
    for _, row in ipairs(data.exchanges or {}) do
        exList:AddLine(row.exchange or "", row.active and "Да" or "Нет", row.used or 0, row.max or 0, math.max((row.max or 0) - (row.used or 0), 0))
    end
    tabs:AddSheet("АТС / линии", exPanel, "icon16/server.png")

    local callsPanel = vgui.Create("DPanel")
    callsPanel:SetPaintBackground(false)
    local callsList = makeList(callsPanel, { "ID", "От", "Кому", "АТС от", "АТС кому", "Ответ", "Возраст" })
    for _, row in ipairs(data.calls or {}) do
        callsList:AddLine(row.id or 0, row.from or "", row.to or "", row.fromExchange or "", row.toExchange or "", row.answered and "Да" or "Нет", row.age or 0)
    end
    tabs:AddSheet("Активные линии", callsPanel, "icon16/connect.png")

    local refresh = btn(f, "Обновить", THEME.accent)
    refresh:SetPos(10, 520); refresh:SetSize(180, 30)
    refresh.DoClick = function()
        action(ent, "terminal_refresh")
        f:Close()
    end
end)

print("[GRM Phone] Client loaded")
