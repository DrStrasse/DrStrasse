--[[--------------------------------------------------------------------
    GRM Faction Permissions UI — Client (Код 122, v2.1)
    Панель настройки доступов фракций к экономическим функциям ПО РОЛЯМ.
    Команда: grm_faction_perms
----------------------------------------------------------------------]]

if SERVER then return end

GRM = GRM or {}
GRM.FactionPerms = GRM.FactionPerms or {}
local PERMS = GRM.FactionPerms

surface.CreateFont("GRMFPerm_Title",  { font = "Roboto", size = 18, weight = 700, extended = true })
surface.CreateFont("GRMFPerm_Normal", { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("GRMFPerm_Small",  { font = "Roboto", size = 12, weight = 400, extended = true })

local C = {
    bg     = Color(16, 20, 28, 252),
    head   = Color(12, 15, 22, 255),
    card   = Color(22, 28, 38, 245),
    cardH  = Color(30, 38, 52, 245),
    border = Color(38, 48, 66, 200),
    acc    = Color(65, 145, 235),
    green  = Color(55, 185, 110),
    gold   = Color(245, 195, 65),
    red    = Color(225, 70, 70),
    text   = Color(240, 244, 250),
    dim    = Color(155, 170, 190),
}

local frame = nil

local function mkBtn(parent, text, col, hoverCol, doClick)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b:SetFont("GRMFPerm_Normal")
    b.Paint = function(s, w, h)
        local bg = s:IsHovered() and (hoverCol or C.acc) or (col or C.acc)
        draw.RoundedBox(5, 0, 0, w, h, bg)
        surface.SetDrawColor(255, 255, 255, 25)
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText(text, "GRMFPerm_Normal", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = function()
        surface.PlaySound("buttons/button15.wav")
        if doClick then doClick() end
    end
    return b
end

-- Сгруппировать разрешения по категориям (по префиксу до первого '_').
local function categories()
    local cats, order = {}, {}
    for id in pairs(PERMS.Permissions or {}) do
        local cat = id:match("^([^_]+)_") or "прочее"
        if not cats[cat] then cats[cat] = {} order[#order + 1] = cat end
        cats[cat][#cats[cat] + 1] = id
    end
    table.sort(order, function(a, b) return a < b end)
    local out = {}
    for _, cat in ipairs(order) do
        out[#out + 1] = { name = cat, perms = cats[cat] }
    end
    return out
end

local function buildPanel(parent, factionName)
    parent:Clear()

    if not factionName or not FactionsData or not FactionsData[factionName] then
        local lbl = vgui.Create("DLabel", parent)
        lbl:Dock(TOP) lbl:SetTall(40) lbl:SetFont("GRMFPerm_Normal") lbl:SetTextColor(C.dim)
        lbl:SetText("Выберите фракцию слева.")
        return
    end

    local f = FactionsData[factionName]
    local roles = f.Roles or {}
    local rolePerms = PERMS.GetFactionRoles(factionName)

    local scroll = vgui.Create("DScrollPanel", parent)
    scroll:Dock(FILL)

    local header = vgui.Create("DLabel", scroll)
    header:Dock(TOP) header:SetTall(28) header:SetFont("GRMFPerm_Title") header:SetTextColor(C.gold)
    header:SetText("Доступы по ролям: " .. (GRM.Factions.DisplayName(factionName) or factionName))

    if #roles == 0 then
        local lbl = vgui.Create("DLabel", scroll)
        lbl:Dock(TOP) lbl:SetTall(40) lbl:SetFont("GRMFPerm_Normal") lbl:SetTextColor(C.dim)
        lbl:SetText("Ролей нет — создайте во вкладке «Структура».")
        return
    end

    for _, role in ipairs(roles) do
        local rp = rolePerms[role] or {}
        local roleCard = vgui.Create("DPanel", scroll)
        roleCard:Dock(TOP) roleCard:SetTall(30) roleCard:DockMargin(0, 4, 0, 0)
        roleCard.Paint = function(_, w, h)
            draw.RoundedBox(4, 0, 0, w, h, C.head)
            draw.SimpleText("РОЛЬ: " .. role, "GRMFPerm_Normal", 10, h / 2, C.acc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        for _, cat in ipairs(categories()) do
            local catLabel = vgui.Create("DLabel", scroll)
            catLabel:Dock(TOP) catLabel:SetTall(22) catLabel:SetFont("GRMFPerm_Small") catLabel:SetTextColor(C.dim)
            catLabel:SetText("— " .. cat.name:upper())
            catLabel:DockMargin(8, 6, 0, 0)

            for _, permID in ipairs(cat.perms) do
                local row = vgui.Create("DPanel", scroll)
                row:Dock(TOP) row:SetTall(30) row:DockMargin(8, 0, 0, 2)
                row.Paint = function(_, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, C.card)
                end
                local chk = vgui.Create("DCheckBoxLabel", row)
                chk:Dock(FILL) chk:DockMargin(10, 0, 0, 0)
                chk:SetText(PERMS.Permissions[permID] or permID)
                chk:SetFont("GRMFPerm_Normal")
                chk:SetTextColor(rp[permID] and C.green or C.text)
                chk:SetValue(rp[permID] and 1 or 0)
                chk.OnChange = function(_, val)
                    local v = val == true
                    if v then PERMS.GrantToRole(factionName, role, permID)
                    else PERMS.RevokeFromRole(factionName, role, permID) end
                end
            end
        end
    end
end

local function open()
    PERMS.Request()

    if IsValid(frame) then
        frame:Remove()
    end

    frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(900, 680)
    frame:Center()
    frame:MakePopup()
    frame:ShowCloseButton(false)

    frame.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, C.bg)
        draw.RoundedBox(8, 0, 0, w, 46, C.head)
        surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText("Доступы фракций к экономическим функциям (по ролям)", "GRMFPerm_Title", 16, 23, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", frame)
    close:SetPos(frame:GetWide() - 40, 8) close:SetSize(30, 30) close:SetText("✕")
    close:SetFont("GRMFPerm_Title") close:SetTextColor(C.dim)
    close.Paint = function(s, w, h) if s:IsHovered() then draw.RoundedBox(4, 0, 0, w, h, C.red) end end
    close.DoClick = function() frame:Close() end

    local body = vgui.Create("DPanel", frame)
    body:Dock(FILL) body:DockMargin(0, 46, 0, 0) body:SetPaintBackground(false)

    -- Левая колонка — список фракций
    local left = vgui.Create("DListView", body)
    left:Dock(LEFT) left:SetWide(250) left:DockMargin(8, 8, 4, 8)
    left:SetMultiSelect(false)
    left:AddColumn("Фракция")
    left:SetPaintBackground(false)
    left.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, C.card)
        surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
        surface.DrawOutlinedRect(0, 0, w, h)
    end

    local names = {}
    for name, f in pairs(FactionsData or {}) do
        if istable(f) then names[#names + 1] = name end
    end
    table.sort(names, function(a, b) return string.lower(a) < string.lower(b) end)
    for _, name in ipairs(names) do
        local disp = GRM.Factions.DisplayName(name)
        local ln = left:AddLine(disp .. " [" .. name .. "]")
        ln.FactionName = name
        for _, col in pairs(ln.Columns or {}) do
            if IsValid(col) then col:SetFont("GRMFPerm_Normal") col:SetTextColor(C.text) end
        end
    end

    -- Правая колонка — доступы по ролям
    local right = vgui.Create("DPanel", body)
    right:Dock(FILL) right:DockMargin(4, 8, 8, 8) right:SetPaintBackground(false)

    local selected = names[1]

    local function refresh()
        buildPanel(right, selected)
    end

    left.OnRowSelected = function(_, _, line)
        if IsValid(line) then
            selected = line.FactionName
            refresh()
        end
    end

    local btnRefresh = mkBtn(right, "Обновить", C.acc, C.gold, function() PERMS.Request() end)

    refresh()

    -- Автообновление при получении данных с сервера
    hook.Add("GRM_FPermDataUpdated", "GRM_FPermUI_Refresh", function()
        if IsValid(frame) and IsValid(right) then
            refresh()
        end
    end)
end

concommand.Add("grm_faction_perms", function()
    if LocalPlayer():IsSuperAdmin() or (GRM.Factions and GRM.Factions.IsLeader and GRM.Factions.IsLeader(LocalPlayer())) then
        open()
    else
        notification.AddLegacy("Только суперадмин или лидер фракции", NOTIFY_ERROR, 3)
    end
end)

print("[GRM Faction Permissions UI] v2.1 loaded")
