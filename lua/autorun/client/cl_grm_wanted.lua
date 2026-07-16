--[[--------------------------------------------------------------------
    GRM Wanted — client UI (Код 61)
----------------------------------------------------------------------]]

if not CLIENT then return end

include("autorun/sh_grm_wanted_config.lua")

GRM = GRM or {}
GRM.Wanted = GRM.Wanted or {}
local W = GRM.Wanted

local NET_OPEN = "GRM_Wanted_Open"
local NET_DATA = "GRM_Wanted_Data"
local NET_ACT  = "GRM_Wanted_Act"
local NET_SYNC = "GRM_Wanted_Sync"
local NET_INFO = "GRM_Wanted_Info"
local NET_LIST = "GRM_Wanted_List"

local THEME = {
    bg = Color(22, 24, 32, 250),
    panel = Color(32, 36, 48, 245),
    text = Color(230, 235, 242),
    dim = Color(150, 160, 175),
    green = Color(70, 180, 110),
    accent = Color(70, 140, 220),
    yellow = Color(220, 180, 70),
    red = Color(220, 80, 80),
}

surface.CreateFont("GRMWanted_Title", { font = "Roboto", size = 20, weight = 800, extended = true })
surface.CreateFont("GRMWanted_Normal", { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("GRMWanted_Small", { font = "Roboto", size = 12, weight = 400, extended = true })

W.LocalLevel = W.LocalLevel or 0

local function money(n)
    if GRM.Format then return GRM.Format(n) end
    return tostring(n) .. " GRM"
end

local function btn(parent, text, col, w, h)
    local b = vgui.Create("DButton", parent)
    b:SetSize(w or 120, h or 28)
    b:SetText(text)
    b:SetFont("GRMWanted_Normal")
    b:SetTextColor(color_white)
    b.Paint = function(self, ww, hh)
        local c = col or THEME.accent
        if self:IsHovered() then c = Color(math.min(255, c.r + 25), math.min(255, c.g + 25), math.min(255, c.b + 25)) end
        draw.RoundedBox(6, 0, 0, ww, hh, c)
    end
    return b
end

local function act(tbl)
    net.Start(NET_ACT)
        net.WriteTable(tbl or {})
    net.SendToServer()
end

local function levelName(levels, lvl)
    local info = istable(levels) and levels[lvl]
    if istable(info) then return info.name or ("Ур." .. lvl) end
    local _, i = GRM.Wanted.GetLevelInfo and GRM.Wanted.GetLevelInfo(lvl)
    return (i and i.name) or ("Ур." .. tostring(lvl))
end

local function openWantedUI(canEdit, list, catalog, players, history, levels, maxLevel)
    if IsValid(W._frame) then W._frame:Remove() end
    local f = vgui.Create("DFrame")
    W._frame = f
    f:SetTitle("")
    f:SetSize(960, 640)
    f:Center()
    f:MakePopup()
    f.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, THEME.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 36, Color(36, 40, 54), true, true, false, false)
        draw.SimpleText("База розыска GRM", "GRMWanted_Title", 14, 18, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(canEdit and "режим: редактирование" or "режим: только просмотр", "GRMWanted_Small", w - 14, 18, canEdit and THEME.green or THEME.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local sheet = vgui.Create("DPropertySheet", f)
    sheet:Dock(FILL)
    sheet:DockMargin(8, 42, 8, 8)

    local selectedSid

    -- ═══ РОЗЫСК ═══
    do
        local p = vgui.Create("DPanel")
        p:SetPaintBackground(false)

        local left = vgui.Create("DPanel", p)
        left:Dock(LEFT)
        left:SetWide(420)
        left:DockMargin(4, 4, 4, 4)
        left.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, THEME.panel) end

        local lbl = vgui.Create("DLabel", left)
        lbl:Dock(TOP)
        lbl:SetTall(24)
        lbl:DockMargin(8, 6, 8, 2)
        lbl:SetText("Активный розыск (уровень > 0)")
        lbl:SetFont("GRMWanted_Normal")
        lbl:SetTextColor(THEME.text)

        local listView = vgui.Create("DListView", left)
        listView:Dock(FILL)
        listView:DockMargin(6, 2, 6, 6)
        listView:AddColumn("Ур."):SetFixedWidth(36)
        listView:AddColumn("Игрок")
        listView:AddColumn("Статей"):SetFixedWidth(50)
        listView:AddColumn("SID"):SetFixedWidth(120)
        listView:SetMultiSelect(false)

        for _, row in ipairs(list or {}) do
            local line = listView:AddLine(tostring(row.level or 0), tostring(row.name or "?"), tostring(row.reasons or 0), string.sub(tostring(row.sid or ""), 1, 17))
            line._sid = row.sid
            line._level = row.level
        end

        local right = vgui.Create("DPanel", p)
        right:Dock(FILL)
        right:DockMargin(4, 4, 4, 4)
        right.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, THEME.panel) end

        local detail = vgui.Create("DLabel", right)
        detail:Dock(TOP)
        detail:SetTall(48)
        detail:DockMargin(10, 8, 10, 4)
        detail:SetWrap(true)
        detail:SetFont("GRMWanted_Normal")
        detail:SetTextColor(THEME.text)
        detail:SetText("Выберите запись слева или игрока онлайн ниже.")

        local reasons = vgui.Create("DListView", right)
        reasons:Dock(FILL)
        reasons:DockMargin(8, 4, 8, 8)
        reasons:AddColumn("#"):SetFixedWidth(28)
        reasons:AddColumn("Тип"):SetFixedWidth(70)
        reasons:AddColumn("Статья")
        reasons:AddColumn("Кем"):SetFixedWidth(100)
        reasons:AddColumn("Ур."):SetFixedWidth(36)

        local function showRecord(sid)
            selectedSid = sid
            act({ action = "get", sid = sid })
        end

        listView.OnRowSelected = function(_, _, ln)
            if ln and ln._sid then showRecord(ln._sid) end
        end

        net.Receive(NET_LIST, function()
            local full = net.ReadTable() or {}
            if not full.sid then
                detail:SetText("Запись не найдена.")
                reasons:Clear()
                return
            end
            selectedSid = full.sid
            local _, info = W.GetLevelInfo(full.level or 0)
            detail:SetText(string.format("%s  |  %s (ур. %d)  |  %s\nобновлено: %s",
                tostring(full.name), info and info.name or "?", tonumber(full.level) or 0, tostring(full.sid),
                os.date("%d.%m.%Y %H:%M", tonumber(full.updated) or os.time())))
            reasons:Clear()
            for i, r in ipairs(full.reasons or {}) do
                local line = reasons:AddLine(tostring(i), tostring(r.type or "?"), tostring(r.title or r.id or "?"),
                    tostring(r.byNick or "?"), tostring(r.level or 0))
                line._index = i
            end
        end)

        if canEdit then
            local bar = vgui.Create("DPanel", right)
            bar:Dock(BOTTOM)
            bar:SetTall(40)
            bar:SetPaintBackground(false)
            local clr = btn(bar, "Снять с розыска", THEME.green, 150, 30)
            clr:Dock(LEFT)
            clr:DockMargin(8, 5, 4, 5)
            clr.DoClick = function()
                if not selectedSid then return end
                act({ action = "clear", sid = selectedSid, text = "UI clear" })
            end
            local rm = btn(bar, "Удалить статью", THEME.yellow, 140, 30)
            rm:Dock(LEFT)
            rm:DockMargin(4, 5, 4, 5)
            rm.DoClick = function()
                if not selectedSid then return end
                local lines = reasons:GetSelected()
                if not lines or not lines[1] or not lines[1]._index then return end
                act({ action = "remove_reason", sid = selectedSid, index = lines[1]._index })
            end
        end

        sheet:AddSheet("Розыск", p, "icon16/exclamation.png")
    end

    -- ═══ ВЫПИСАТЬ ═══
    if canEdit then
        local p = vgui.Create("DPanel")
        p:SetPaintBackground(false)

        local y = 12
        local function label(txt, yy)
            local l = vgui.Create("DLabel", p)
            l:SetPos(16, yy)
            l:SetSize(500, 20)
            l:SetText(txt)
            l:SetFont("GRMWanted_Normal")
            l:SetTextColor(THEME.text)
        end

        label("Игрок (онлайн) или SteamID64:", y)
        local combo = vgui.Create("DComboBox", p)
        combo:SetPos(16, y + 22)
        combo:SetSize(360, 28)
        combo:SetValue("Выберите игрока…")
        for _, pl in ipairs(players or {}) do
            combo:AddChoice(string.format("%s  [ур.%d]  %s", pl.nick, pl.level or 0, pl.sid64), pl.sid64)
        end
        local sidEntry = vgui.Create("DTextEntry", p)
        sidEntry:SetPos(390, y + 22)
        sidEntry:SetSize(240, 28)
        sidEntry:SetPlaceholderText("или SID64 вручную")

        y = y + 64
        label("Статья из каталога:", y)
        local artCombo = vgui.Create("DComboBox", p)
        artCombo:SetPos(16, y + 22)
        artCombo:SetSize(500, 28)
        artCombo:SetValue("Статья…")
        for _, art in ipairs(catalog or {}) do
            artCombo:AddChoice(string.format("[%s] %s (ур.%s, штраф %s)",
                art.type or "?", art.title or art.id, tostring(art.defaultLevel or 1), money(art.fine or 0)), art.id)
        end

        y = y + 64
        label("Комментарий / обстоятельства:", y)
        local note = vgui.Create("DTextEntry", p)
        note:SetPos(16, y + 22)
        note:SetSize(614, 28)
        note:SetPlaceholderText("Необязательно")

        y = y + 64
        label("Принудительный уровень (0 = по статье):", y)
        local lvl = vgui.Create("DNumberWang", p)
        lvl:SetPos(16, y + 22)
        lvl:SetSize(80, 28)
        lvl:SetMin(0)
        lvl:SetMax(maxLevel or 5)
        lvl:SetValue(0)

        local add = btn(p, "Выписать статью", THEME.red, 180, 32)
        add:SetPos(110, y + 20)
        add.DoClick = function()
            local _, sid = combo:GetSelected()
            if not sid or sid == "" then sid = string.Trim(sidEntry:GetValue() or "") end
            if sid == "" then return end
            local _, artId = artCombo:GetSelected()
            if not artId then return end
            local force = math.floor(tonumber(lvl:GetValue()) or 0)
            act({
                action = "add_charge",
                sid = sid,
                article = artId,
                text = note:GetValue(),
                level = force > 0 and force or nil,
            })
        end

        local setL = btn(p, "Поставить уровень", THEME.accent, 160, 32)
        setL:SetPos(300, y + 20)
        setL.DoClick = function()
            local _, sid = combo:GetSelected()
            if not sid or sid == "" then sid = string.Trim(sidEntry:GetValue() or "") end
            if sid == "" then return end
            act({
                action = "set_level",
                sid = sid,
                level = math.floor(tonumber(lvl:GetValue()) or 0),
                text = note:GetValue(),
            })
        end

        sheet:AddSheet("Выписать", p, "icon16/pencil.png")
    end

    -- ═══ КАТАЛОГ ═══
    do
        local p = vgui.Create("DPanel")
        p:SetPaintBackground(false)
        local lv = vgui.Create("DListView", p)
        lv:Dock(FILL)
        lv:DockMargin(8, 8, 8, 8)
        lv:AddColumn("ID")
        lv:AddColumn("Тип"):SetFixedWidth(70)
        lv:AddColumn("Название")
        lv:AddColumn("Ур."):SetFixedWidth(40)
        lv:AddColumn("Штраф"):SetFixedWidth(90)
        for _, art in ipairs(catalog or {}) do
            lv:AddLine(tostring(art.id), tostring(art.type), tostring(art.title),
                tostring(art.defaultLevel or 1), money(art.fine or 0))
        end
        sheet:AddSheet("Статьи", p, "icon16/book.png")
    end

    -- ═══ ИСТОРИЯ ═══
    do
        local p = vgui.Create("DPanel")
        p:SetPaintBackground(false)
        local scroll = vgui.Create("DScrollPanel", p)
        scroll:Dock(FILL)
        scroll:DockMargin(8, 8, 8, 8)
        local h = history or {}
        for i = #h, math.max(1, #h - 80), -1 do
            local rec = h[i]
            local l = vgui.Create("DLabel", scroll)
            l:Dock(TOP)
            l:SetTall(18)
            l:DockMargin(4, 1, 4, 1)
            l:SetFont("GRMWanted_Small")
            l:SetTextColor(THEME.dim)
            l:SetText(os.date("%d.%m %H:%M", rec.t or 0) .. " — " .. tostring(rec.s or ""))
        end
        sheet:AddSheet("Журнал", p, "icon16/time.png")
    end

    local refresh = btn(f, "Обновить", THEME.accent, 100, 26)
    refresh:SetPos(f:GetWide() - 120, 5)
    refresh.DoClick = function() act({ action = "refresh" }) end
end

net.Receive(NET_DATA, function()
    local canEdit = net.ReadBool()
    local list = net.ReadTable() or {}
    local catalog = net.ReadTable() or {}
    local players = net.ReadTable() or {}
    local history = net.ReadTable() or {}
    local levels = net.ReadTable() or {}
    local maxLevel = net.ReadUInt(4)
    openWantedUI(canEdit, list, catalog, players, history, levels, maxLevel)
end)

net.Receive(NET_SYNC, function()
    W.LocalLevel = net.ReadUInt(4)
    local name = net.ReadString()
    hook.Run("GRM_WantedLevelChanged", W.LocalLevel, name)
end)

net.Receive(NET_INFO, function()
    local msg = net.ReadString()
    local r, g, b = net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8)
    chat.AddText(Color(r, g, b), "[Розыск] ", color_white, msg)
end)

function W.OpenMenu()
    net.Start(NET_OPEN)
    net.SendToServer()
end

concommand.Add("grm_wanted", W.OpenMenu)

hook.Add("OnPlayerChat", "GRM_Wanted_ClientChat", function(ply, text)
    if ply ~= LocalPlayer() then return end
    local msg = string.lower(string.Trim(text or ""))
    if msg == "/wanted" or msg == "!wanted" or msg == "/розыск" or msg == "!розыск" then
        W.OpenMenu()
        return true
    end
end)

-- лёгкий индикатор своего уровня (не перекрывает HP — справа сверху под краем)
hook.Add("HUDPaint", "GRM_Wanted_SelfBadge", function()
    local lvl = tonumber(W.LocalLevel) or LocalPlayer():GetNW2Int("GRM_WantedLevel", 0)
    if not lvl or lvl <= 0 then return end
    if GRM.CCTV and GRM.CCTV._viewActive then return end -- optional
    local _, info = W.GetLevelInfo(lvl)
    local col = (info and info.color) or Color(230, 120, 50)
    local w = ScrW()
    draw.SimpleTextOutlined(
        "РОЗЫСК " .. (info and info.short or tostring(lvl)) .. "  " .. (info and info.name or ""),
        "GRMWanted_Normal", w - 16, 56, col, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP, 1, Color(0, 0, 0, 200))
end)

print("[GRM Wanted] client v1.0.0")
