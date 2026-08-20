--[[--------------------------------------------------------------------
    GRM Vehicle Dealer — клиент v4.3.0

    Что изменилось против v3.2:
      • Единый стиль GRM (палитра и шрифты как в /factions): тёмный корпус,
        золотой заголовок, боковое меню разделов, карточки товара.
      • Каталог больше НЕ один общий список: слева дерево разделов
        (Все → Личные → категории → служебные по организациям), справа —
        карточки. Поиск работает по названию, классу и категории.
      • Админка: фракция выбирается ИЗ СПИСКА организаций (было ручное поле,
        любая опечатка делала машину недоступной), категория — из списка
        с возможностью добавить свою.
----------------------------------------------------------------------]]
include("shared.lua")

surface.CreateFont("GRMVD_Title",  { font = "Roboto", size = 21, weight = 800, extended = true })
surface.CreateFont("GRMVD_Head",   { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("GRMVD_Body",   { font = "Roboto", size = 13, weight = 550, extended = true })
surface.CreateFont("GRMVD_Btn",    { font = "Roboto", size = 13, weight = 600, extended = true })
surface.CreateFont("GRMVD_Small",  { font = "Roboto", size = 11, weight = 500, extended = true })
surface.CreateFont("GRMVD_Price",  { font = "Roboto", size = 18, weight = 800, extended = true })

local C = {
    bg          = Color(16, 20, 28, 252),
    sidebar     = Color(12, 15, 22, 255),
    card        = Color(22, 28, 38, 240),
    cardLight   = Color(28, 36, 48, 240),
    cardHover   = Color(36, 46, 62, 240),
    border      = Color(38, 48, 66, 200),
    accent      = Color(65, 145, 235),
    accentHover = Color(85, 165, 255),
    gold        = Color(245, 195, 65),
    green       = Color(55, 185, 110),
    teal        = Color(75, 195, 170),
    red         = Color(225, 70, 70),
    text        = Color(240, 244, 250),
    dim         = Color(155, 170, 190),
}

local function money(n)
    return GRM.Format and GRM.Format(n) or (tostring(n) .. " GRM")
end

-- Кнопка в стиле GRM: плоская, подсветка при наведении, без Derma-градиента.
local function grmButton(parent, label, base, textCol)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b.base = base or C.accent
    b.Paint = function(self, w, h)
        local col = self.base
        if not self:IsEnabled() then
            col = C.cardLight
        elseif self:IsHovered() then
            col = Color(math.min(255, col.r + 22), math.min(255, col.g + 22), math.min(255, col.b + 22))
        end
        draw.RoundedBox(6, 0, 0, w, h, col)
        draw.SimpleText(label, "GRMVD_Btn", w / 2, h / 2,
            self:IsEnabled() and (textCol or color_white) or C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return b
end

local function skinEntry(entry, placeholder)
    entry:SetFont("GRMVD_Body")
    entry:SetTextColor(C.text)
    entry:SetCursorColor(C.text)
    if placeholder then entry:SetPlaceholderText(placeholder) end
    entry.Paint = function(self, w, h)
        draw.RoundedBox(5, 0, 0, w, h, C.cardLight)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h)
        self:DrawTextEntryText(C.text, C.accent, C.text)
        if self:GetText() == "" and self.GetPlaceholderText and self:GetPlaceholderText() then
            draw.SimpleText(self:GetPlaceholderText(), "GRMVD_Small", 8, h / 2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    return entry
end

local function skinCombo(combo)
    combo:SetFont("GRMVD_Body")
    combo:SetTextColor(C.text)
    combo.Paint = function(self, w, h)
        draw.RoundedBox(5, 0, 0, w, h, C.cardLight)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
    return combo
end

local function preview(p, model)
    if not util.IsValidModel(model or "") then return end
    p:SetModel(model)
    local e = p:GetEntity()
    if not IsValid(e) then return end
    local mn, mx = e:GetRenderBounds()
    local size = math.max((mx - mn):Length(), 30)
    p:SetFOV(34)
    p:SetCamPos(Vector(size, size, size * 0.55))
    p:SetLookAt((mn + mx) * 0.5)
    p.LayoutEntity = function(self, ent) ent:SetAngles(Angle(0, RealTime() * 15 % 360, 0)) end
end

local function send(dealer, op, id, extra)
    net.Start("GRM_VD_Action")
    net.WriteEntity(dealer)
    net.WriteString(op)
    if id then net.WriteString(id) end
    if extra ~= nil then net.WriteString(tostring(extra)) end
    net.SendToServer()
    if GRM.HUD and GRM.HUD.SelectorSound then GRM.HUD.SelectorSound("pick", 0.05)
    else surface.PlaySound("common/wpn_select.wav") end
end

-----------------------------------------------------------------------
-- Табличка над NPC
-----------------------------------------------------------------------
function ENT:Draw()
    self:DrawModel()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    local d = lp:GetPos():Distance(self:GetPos())
    if d > 600 then return end

    local top = self:LocalToWorld(Vector(0, 0, (self:OBBMaxs().z or 72) + 16))
    local s = top:ToScreen()
    if not s.visible then return end

    local a = math.Clamp(255 - (d - 120) * 0.42, 45, 255)
    local name = self:GetDealerName()
    if name == "" then name = "Дилер транспорта" end

    surface.SetFont("GRMVD_Head")
    local tw = surface.GetTextSize(name)
    local width = math.Clamp(tw + 42, 270, 520)

    draw.RoundedBox(7, s.x - width / 2, s.y - 30, width, 58, Color(12, 15, 22, a * 0.92))
    surface.SetDrawColor(C.gold.r, C.gold.g, C.gold.b, a * 0.8)
    surface.DrawOutlinedRect(s.x - width / 2, s.y - 30, width, 58, 2)
    draw.SimpleText(name, "GRMVD_Head", s.x, s.y - 10, Color(C.gold.r, C.gold.g, C.gold.b, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    draw.SimpleText("ТРАНСПОРТНЫЙ ЦЕНТР  •  [E]", "GRMVD_Small", s.x, s.y + 13, Color(220, 230, 240, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-----------------------------------------------------------------------
-- Каркас окна GRM (шапка + боковое меню + контент)
-----------------------------------------------------------------------
local function grmFrame(title, subtitle, w, h)
    local f = vgui.Create("DFrame")
    f:SetSize(w, h)
    f:Center()
    f:MakePopup()
    f:SetTitle("")
    f:ShowCloseButton(false)
    f:SetSizable(true)
    f.Paint = function(_, fw, fh)
        draw.RoundedBox(8, 0, 0, fw, fh, C.bg)
        draw.RoundedBoxEx(8, 0, 0, fw, 52, C.sidebar, true, true, false, false)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, fw, fh)
        draw.SimpleText(subtitle, "GRMVD_Small", 18, 15, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(title, "GRMVD_Title", 18, 30, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", f)
    close:SetText("")
    close:SetSize(32, 28)
    close.Paint = function(self, bw, bh)
        if self:IsHovered() then draw.RoundedBox(5, 0, 0, bw, bh, C.red) end
        draw.SimpleText("✕", "GRMVD_Btn", bw / 2, bh / 2, self:IsHovered() and color_white or C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    close.DoClick = function() f:Close() end
    f.PerformLayout = function(self, lw)
        if IsValid(close) then close:SetPos(lw - 42, 12) end
    end

    local body = vgui.Create("DPanel", f)
    body:Dock(FILL)
    body:DockMargin(0, 52, 0, 0)
    body:SetPaintBackground(false)
    return f, body
end

-- Боковое меню разделов (как в /factions).
local function sideNav(parent, width)
    local nav = vgui.Create("DScrollPanel", parent)
    nav:Dock(LEFT)
    nav:SetWide(width or 232)
    nav.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, C.sidebar)
        surface.SetDrawColor(C.border)
        surface.DrawLine(w - 1, 0, w - 1, h)
    end
    nav.Buttons = {}
    function nav:AddSection(key, label, count, onClick)
        local b = vgui.Create("DButton", self)
        b:Dock(TOP)
        b:SetTall(36)
        b:DockMargin(6, 4, 8, 0)
        b:SetText("")
        b.isActive = false
        b.Paint = function(self2, w, h)
            if self2.isActive then
                draw.RoundedBox(6, 0, 0, w, h, C.accent)
            elseif self2:IsHovered() then
                draw.RoundedBox(6, 0, 0, w, h, C.cardHover)
            end
            local col = self2.isActive and color_white or (self2:IsHovered() and C.text or C.dim)
            draw.SimpleText(label, "GRMVD_Btn", 14, h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            if count and count > 0 then
                draw.SimpleText(tostring(count), "GRMVD_Small", w - 12, h / 2,
                    self2.isActive and color_white or C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
        end
        b.DoClick = function()
            for _, other in pairs(nav.Buttons) do other.isActive = false end
            b.isActive = true
            if GRM.HUD and GRM.HUD.SelectorSound then GRM.HUD.SelectorSound("move", 0.03) end
            onClick()
        end
        nav.Buttons[key] = b
        return b
    end
    function nav:AddCaption(text)
        local l = vgui.Create("DPanel", self)
        l:Dock(TOP)
        l:SetTall(26)
        l:DockMargin(6, 10, 8, 2)
        l.Paint = function(_, w, h)
            draw.SimpleText(string.upper(text), "GRMVD_Small", 14, h / 2, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        return l
    end
    return nav
end

-----------------------------------------------------------------------
-- КАТАЛОГ ИГРОКА
-----------------------------------------------------------------------
net.Receive("GRM_VD_Open", function()
    local dealer  = net.ReadEntity()
    local name    = net.ReadString()
    local catalog = net.ReadTable() or {}
    local garage  = net.ReadTable() or {}
    local activeVeh = net.ReadTable() or {}
    local garageChoices = net.ReadTable() or {}

    if IsValid(GRM.VehicleDealerFrame) then GRM.VehicleDealerFrame:Remove() end

    local f, body = grmFrame(name ~= "" and name or "Дилер транспорта", "GRM / ТРАНСПОРТНЫЙ ЦЕНТР",
        math.Clamp(ScrW() * 0.84, 1080, 1520), math.Clamp(ScrH() * 0.86, 700, 950))
    GRM.VehicleDealerFrame = f
    if GRM.UI and GRM.UI.Track then GRM.UI.Track("vehicle_dealer", f) end

    local nav = sideNav(body, 250)

    local right = vgui.Create("DPanel", body)
    right:Dock(FILL)
    right:DockMargin(12, 10, 12, 12)
    right:SetPaintBackground(false)

    local searchRow = vgui.Create("DPanel", right)
    searchRow:Dock(TOP)
    searchRow:SetTall(34)
    searchRow:DockMargin(0, 0, 0, 8)
    searchRow:SetPaintBackground(false)

    local search = skinEntry(vgui.Create("DTextEntry", searchRow), "Поиск: название, класс, категория…")
    search:Dock(FILL)

    --[[ ВЫБОР ГАРАЖА ДЛЯ ПОКУПКИ (заказ владельца 19.08): игрок сам решает,
         куда приписать машину, а не «куда система решила». Пустое значение —
         автоподбор (привязанный к дилеру → личный → ближайший). ]]
    local targetGarage = ""
    if #garageChoices > 0 then
        local gcombo = skinCombo(vgui.Create("DComboBox", searchRow))
        gcombo:Dock(RIGHT)
        gcombo:SetWide(330)
        gcombo:DockMargin(8, 0, 0, 0)
        gcombo:AddChoice("Гараж: автоматически", "", true)
        for _, g in ipairs(garageChoices) do
            local label = ("Гараж: %s — мест %d/%d"):format(tostring(g.name), tonumber(g.free) or 0, tonumber(g.slots) or 0)
            if g.suggested then label = label .. " ★" end
            gcombo:AddChoice(label, g.id)
        end
        gcombo.OnSelect = function(_, _, _, val) targetGarage = tostring(val or "") end
    end

    local list = vgui.Create("DScrollPanel", right)
    list:Dock(FILL)

    -- ── раскладка каталога по разделам ────────────────────────────────
    local personal, byCategory, byFaction, catOrder, facOrder = {}, {}, {}, {}, {}
    for _, v in ipairs(catalog) do
        local kind = tostring(v.ownershipType or "personal")
        if kind == "personal" then
            personal[#personal + 1] = v
            local cat = tostring(v.category or "Прочее")
            if not byCategory[cat] then byCategory[cat] = {} catOrder[#catOrder + 1] = cat end
            table.insert(byCategory[cat], v)
        else
            local fac = tostring(v.factionName or v.faction or "")
            if fac == "" then fac = tostring(v.ownershipName or "Служебный транспорт") end
            if not byFaction[fac] then byFaction[fac] = {} facOrder[#facOrder + 1] = fac end
            table.insert(byFaction[fac], v)
        end
    end
    table.sort(catOrder, function(a, b) return string.lower(a) < string.lower(b) end)
    table.sort(facOrder, function(a, b) return string.lower(a) < string.lower(b) end)

    local function matches(v, q)
        if q == "" then return true end
        local hay = string.lower(tostring(v.name or "") .. " " .. tostring(v.class or "") .. " " ..
            tostring(v.category or "") .. " " .. tostring(v.factionName or v.faction or ""))
        return string.find(hay, q, 1, true) ~= nil
    end

    local function catalogCard(parent, v)
        local row = vgui.Create("DPanel", parent)
        row:Dock(TOP)
        row:SetTall(116)
        row:DockMargin(0, 0, 6, 8)
        row.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, self:IsHovered() and C.cardHover or C.card)
            surface.SetDrawColor(C.border)
            surface.DrawOutlinedRect(0, 0, w, h)
            draw.SimpleText(v.name or v.class, "GRMVD_Head", 128, 16, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(tostring(v.category or "Транспорт") .. "  •  " .. tostring(v.system or "source") ..
                "  •  " .. tostring(v.class or ""), "GRMVD_Small", 128, 40, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

            if v.ownershipType == "personal" then
                draw.SimpleText(money(v.price or 0), "GRMVD_Price", 128, 66, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            else
                draw.SimpleText(tostring(v.ownershipName or "Служебный транспорт"), "GRMVD_Body", 128, 70, C.teal, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
            local fac = tostring(v.factionName or v.faction or "")
            if fac ~= "" then
                draw.SimpleText("Организация: " .. fac, "GRMVD_Small", 128, 94, C.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end
            -- Лимит одинаковых машин (заказ владельца 19.08): видно ДО покупки,
            -- сколько таких уже за игроком.
            local limit = tonumber(v.classLimit) or 0
            if limit > 0 then
                local owned = tonumber(v.owned) or 0
                local full = owned >= limit
                draw.SimpleText(("У вас: %d из %d"):format(owned, limit), "GRMVD_Small", w - 176, 16,
                    full and C.red or C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
            end
        end

        local m = vgui.Create("DModelPanel", row)
        m:SetPos(10, 10)
        m:SetSize(108, 96)
        preview(m, v.model)

        local limit = tonumber(v.classLimit) or 0
        local owned = tonumber(v.owned) or 0
        local capped = limit > 0 and owned >= limit

        local buy = grmButton(row, capped and "ЛИМИТ" or (v.ownershipType == "personal" and "КУПИТЬ" or "ВЫДАТЬ"),
            capped and C.red or (v.ownershipType == "personal" and C.green or C.accent))
        buy:Dock(RIGHT)
        buy:SetWide(150)
        buy:DockMargin(10, 38, 12, 38)
        buy:SetEnabled(not capped)
        buy.DoClick = function() send(dealer, "buy", v.class, targetGarage) end
        return row
    end

    local function emptyNote(parent, text)
        local l = vgui.Create("DPanel", parent)
        l:Dock(TOP)
        l:SetTall(90)
        l.Paint = function(_, w, h)
            draw.RoundedBox(8, 0, 0, w, h, C.card)
            draw.SimpleText(text, "GRMVD_Body", w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    local currentRows, currentMode = catalog, "catalog"

    local function garageCard(parent, v)
        local row = vgui.Create("DPanel", parent)
        row:Dock(TOP)
        row:SetTall(110)
        row:DockMargin(0, 0, 6, 8)
        row.Paint = function(_, w, h)
            draw.RoundedBox(8, 0, 0, w, h, C.card)
            surface.SetDrawColor(C.border)
            surface.DrawOutlinedRect(0, 0, w, h)
            draw.SimpleText(v.name or v.class, "GRMVD_Head", 124, 16, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(tostring(v.class or ""), "GRMVD_Small", 124, 42, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(v.stored == false and "Выдан на карту" or "В гараже", "GRMVD_Body", 124, 70,
                v.stored == false and C.gold or C.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            local home = tostring(v.homeName or "")
            draw.SimpleText(home ~= "" and ("Гараж: " .. home) or "Гараж не назначен", "GRMVD_Small", 124, 90,
                home ~= "" and C.teal or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        local m = vgui.Create("DModelPanel", row)
        m:SetPos(9, 9)
        m:SetSize(104, 92)
        preview(m, v.model)

        local actions = vgui.Create("DPanel", row)
        actions:Dock(RIGHT)
        actions:SetWide(280)
        actions:DockMargin(6, 12, 12, 12)
        actions:SetPaintBackground(false)

        local main = grmButton(actions, v.stored == false and "В ГАРАЖ" or "ВЫДАТЬ",
            v.stored == false and C.accent or C.green)
        main:Dock(TOP)
        main:SetTall(38)
        main.DoClick = function() send(dealer, v.stored == false and "store" or "retrieve", v.id) end

        local sell = grmButton(actions, "Продать (возврат 50%)", C.red)
        sell:Dock(BOTTOM)
        sell:SetTall(30)
        sell.DoClick = function()
            Derma_Query("Продать транспорт навсегда?", "Гараж", "Продать", function() send(dealer, "sell", v.id) end, "Отмена")
        end
        return row
    end

    --[[ v4.1.0 (заказ владельца): раздел «На карте» — убрать транспорт прямо
         из меню дилера. Раньше кнопка «Убрать Т/С» жила только в C-меню, и
         служебную машину (у неё нет записи гаража) убрать было нечем. ]]
    local function activeCard(parent, v)
        local row = vgui.Create("DPanel", parent)
        row:Dock(TOP)
        row:SetTall(110)
        row:DockMargin(0, 0, 6, 8)
        row.Paint = function(_, w, h)
            draw.RoundedBox(8, 0, 0, w, h, C.card)
            surface.SetDrawColor(C.border)
            surface.DrawOutlinedRect(0, 0, w, h)
            draw.SimpleText(v.name or v.class, "GRMVD_Head", 124, 16, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(tostring(v.class or ""), "GRMVD_Small", 124, 42, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(tostring(v.ownershipName or "Транспорт") .. "  •  " .. tostring(v.distance or 0) .. " юн.",
                "GRMVD_Body", 124, 70, v.personal and C.gold or C.teal, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
        local m = vgui.Create("DModelPanel", row)
        m:SetPos(9, 9)
        m:SetSize(104, 92)
        preview(m, v.model)

        local rm = grmButton(row, v.personal and "УБРАТЬ (В ГАРАЖ)" or "УБРАТЬ ТРАНСПОРТ", C.red)
        rm:Dock(RIGHT)
        rm:SetWide(210)
        rm:DockMargin(6, 34, 12, 34)
        rm.DoClick = function()
            Derma_Query(v.personal
                    and "Убрать транспорт с карты? Он вернётся в гараж."
                    or "Убрать служебный транспорт с карты?",
                "Транспорт", "Убрать", function() send(dealer, "remove", v.id) end, "Отмена")
        end
        return row
    end

    local function render()
        list:Clear()
        local q = string.lower(string.Trim(search:GetValue() or ""))
        local shown = 0
        for _, v in ipairs(currentRows) do
            if matches(v, q) then
                shown = shown + 1
                if currentMode == "garage" then garageCard(list, v)
                elseif currentMode == "active" then activeCard(list, v)
                else catalogCard(list, v) end
            end
        end
        if shown == 0 then
            emptyNote(list, currentMode == "garage"
                and "Гараж пуст. Личный транспорт появится здесь после покупки."
                or (currentMode == "active"
                    and "На карте нет вашего транспорта."
                    or "В этом разделе нет доступного транспорта."))
        end
    end
    search.OnChange = render

    local function showRows(rows, mode)
        currentRows, currentMode = rows or {}, mode or "catalog"
        render()
    end

    nav:AddCaption("Каталог")
    nav:AddSection("all", "Весь каталог", #catalog, function() showRows(catalog, "catalog") end)
    nav:AddSection("personal", "Личный транспорт", #personal, function() showRows(personal, "catalog") end)

    if #catOrder > 0 then
        nav:AddCaption("Категории")
        for _, cat in ipairs(catOrder) do
            local rows = byCategory[cat]
            nav:AddSection("cat_" .. cat, cat, #rows, function() showRows(rows, "catalog") end)
        end
    end

    if #facOrder > 0 then
        nav:AddCaption("Служебный по организациям")
        for _, fac in ipairs(facOrder) do
            local rows = byFaction[fac]
            nav:AddSection("fac_" .. fac, fac, #rows, function() showRows(rows, "catalog") end)
        end
    end

    nav:AddCaption("Мой транспорт")
    nav:AddSection("garage", "Гараж", #garage, function() showRows(garage, "garage") end)
    nav:AddSection("active", "На карте (убрать)", #activeVeh, function() showRows(activeVeh, "active") end)

    if nav.Buttons["all"] then nav.Buttons["all"]:DoClick() end
end)

net.Receive("GRM_VD_Result", function()
    local ok, text = net.ReadBool(), net.ReadString()
    notification.AddLegacy(text, ok and NOTIFY_GENERIC or NOTIFY_ERROR, 5)
    surface.PlaySound(ok and "buttons/button9.wav" or "buttons/button10.wav")
end)

-----------------------------------------------------------------------
-- АДМИНКА ДИЛЕРА
-----------------------------------------------------------------------
net.Receive("GRM_VD_AdminOpen", function()
    local dealer = net.ReadEntity()
    local data   = net.ReadTable() or {}
    local selected = table.Copy(data.vehicles or {})
    local factions = istable(data.factions) and data.factions or {}
    local categories = istable(data.categories) and data.categories or { "Прочее" }

    local f, body = grmFrame("Настройка дилера и гаража", "GRM / АДМИНИСТРИРОВАНИЕ ТРАНСПОРТА", 1240, 800)
    if GRM.UI and GRM.UI.Track then GRM.UI.Track("vehicle_dealer_admin", f) end

    -- Верхняя строка: имя дилера и модель NPC.
    local head = vgui.Create("DPanel", body)
    head:Dock(TOP)
    head:SetTall(48)
    head:DockMargin(12, 10, 12, 6)
    head.Paint = function(_, w, h) draw.RoundedBox(7, 0, 0, w, h, C.card) end

    local nameEntry = skinEntry(vgui.Create("DTextEntry", head), "Название дилера")
    nameEntry:Dock(LEFT)
    nameEntry:SetWide(340)
    nameEntry:DockMargin(10, 10, 8, 10)
    nameEntry:SetText(data.name or "")

    local modelEntry = skinEntry(vgui.Create("DTextEntry", head), "Модель NPC (models/…)")
    modelEntry:Dock(FILL)
    modelEntry:DockMargin(0, 10, 10, 10)
    modelEntry:SetText(data.model or "")

    local save = grmButton(body, "СОХРАНИТЬ ДИЛЕРА, АССОРТИМЕНТ И ГАРАЖ", C.green)
    save:Dock(BOTTOM)
    save:SetTall(40)
    save:DockMargin(12, 6, 12, 12)

    local split = vgui.Create("DPanel", body)
    split:Dock(FILL)
    split:DockMargin(12, 0, 12, 0)
    split:SetPaintBackground(false)

    -- Левая колонка: весь транспорт сервера.
    local left = vgui.Create("DPanel", split)
    left:Dock(LEFT)
    left:SetWide(430)
    left:DockPadding(8, 8, 8, 8)
    left.Paint = function(_, w, h)
        draw.RoundedBox(7, 0, 0, w, h, C.card)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h)
    end

    local searchAvail = skinEntry(vgui.Create("DTextEntry", left), "Поиск транспорта на сервере…")
    searchAvail:Dock(TOP)
    searchAvail:SetTall(28)
    searchAvail:DockMargin(0, 0, 0, 8)

    local available = vgui.Create("DScrollPanel", left)
    available:Dock(FILL)

    -- Правая колонка: ассортимент дилера.
    local right = vgui.Create("DPanel", split)
    right:Dock(FILL)
    right:DockMargin(10, 0, 0, 0)
    right:DockPadding(8, 8, 8, 8)
    right.Paint = function(_, w, h)
        draw.RoundedBox(7, 0, 0, w, h, C.card)
        surface.SetDrawColor(C.border)
        surface.DrawOutlinedRect(0, 0, w, h)
    end

    local selectedScroll = vgui.Create("DScrollPanel", right)
    selectedScroll:Dock(FILL)

    local function exists(class)
        for _, e in ipairs(selected) do if e.class == class then return true end end
        return false
    end

    local rebuildSelected, rebuildAvailable

    rebuildAvailable = function()
        available:Clear()
        local q = string.lower(string.Trim(searchAvail:GetValue() or ""))
        local shown = 0
        for _, v in ipairs(data.available or {}) do
            local hay = string.lower(tostring(v.name or "") .. " " .. tostring(v.class or ""))
            if q == "" or string.find(hay, q, 1, true) then
                shown = shown + 1
                if shown > 400 then break end
                local taken = exists(v.class)
                local b = grmButton(available, v.name .. "   [" .. tostring(v.system or "?") .. "]",
                    taken and C.cardLight or C.accent)
                b:Dock(TOP)
                b:SetTall(30)
                b:DockMargin(0, 0, 4, 4)
                b:SetEnabled(not taken)
                b.DoClick = function()
                    selected[#selected + 1] = {
                        class = v.class, name = v.name, price = 0,
                        category = categories[1] or "Прочее", faction = "",
                        service = false, ownershipType = "personal",
                    }
                    rebuildAvailable()
                    rebuildSelected()
                end
            end
        end
        if shown == 0 then
            local l = vgui.Create("DPanel", available)
            l:Dock(TOP) l:SetTall(60)
            l.Paint = function(_, w, h)
                draw.SimpleText("Ничего не найдено", "GRMVD_Body", w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end

    rebuildSelected = function()
        selectedScroll:Clear()
        if #selected == 0 then
            local l = vgui.Create("DPanel", selectedScroll)
            l:Dock(TOP) l:SetTall(80)
            l.Paint = function(_, w, h)
                draw.SimpleText("Ассортимент пуст — добавьте транспорт слева.", "GRMVD_Body", w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            return
        end

        for index, e in ipairs(selected) do
            local row = vgui.Create("DPanel", selectedScroll)
            row:Dock(TOP)
            row:SetTall(112)
            row:DockMargin(0, 0, 6, 6)
            row.Paint = function(_, w, h)
                draw.RoundedBox(6, 0, 0, w, h, C.cardLight)
                draw.SimpleText(e.name or e.class, "GRMVD_Head", 12, 10, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText(tostring(e.class or ""), "GRMVD_Small", 12, 32, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("ЦЕНА", "GRMVD_Small", 12, 60, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("КАТЕГОРИЯ", "GRMVD_Small", 150, 60, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("ОРГАНИЗАЦИЯ", "GRMVD_Small", 330, 60, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                draw.SimpleText("ТИП ВЛАДЕНИЯ", "GRMVD_Small", 560, 60, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end

            local price = vgui.Create("DNumberWang", row)
            price:SetPos(12, 76)
            price:SetSize(126, 26)
            price:SetMin(0)
            price:SetMax(100000000)
            price:SetDecimals(0)
            price:SetValue(tonumber(e.price) or 0)
            price.OnValueChanged = function(_, v) e.price = math.floor(tonumber(v) or 0) end

            -- Категория: выбор из списка + возможность вписать новую.
            local cat = skinCombo(vgui.Create("DComboBox", row))
            cat:SetPos(150, 76)
            cat:SetSize(170, 26)
            local curCat = tostring(e.category or "Прочее")
            local hasCat = false
            for _, c in ipairs(categories) do
                cat:AddChoice(c, c, c == curCat)
                if c == curCat then hasCat = true end
            end
            if not hasCat and curCat ~= "" then cat:AddChoice(curCat, curCat, true) end
            cat:AddChoice("＋ своя категория…", "__new", false)
            cat.OnSelect = function(self, _, _, value)
                if value == "__new" then
                    Derma_StringRequest("Категория", "Название новой категории:", curCat, function(txt)
                        txt = string.Trim(tostring(txt or ""))
                        if txt == "" then self:SetValue(curCat) return end
                        e.category = txt
                        local found = false
                        for _, c in ipairs(categories) do if c == txt then found = true break end end
                        if not found then categories[#categories + 1] = txt end
                        rebuildSelected()
                    end, function() self:SetValue(curCat) end)
                else
                    e.category = value
                end
            end

            -- Организация: строго из реестра фракций, без ручного ввода.
            local fac = skinCombo(vgui.Create("DComboBox", row))
            fac:SetPos(330, 76)
            fac:SetSize(220, 26)
            local curFac = tostring(e.faction or "")
            fac:AddChoice("— доступно всем —", "", curFac == "")
            local known = curFac == ""
            for _, item in ipairs(factions) do
                fac:AddChoice(item.name .. "  [" .. item.key .. "]", item.key, item.key == curFac)
                if item.key == curFac then known = true end
            end
            if not known then
                -- Сохранённая ранее строка, которой нет в реестре: показываем
                -- как «неизвестная», чтобы админ видел проблему и переназначил.
                fac:AddChoice("⚠ " .. curFac .. " (нет такой организации)", curFac, true)
            end
            fac.OnSelect = function(_, _, _, value)
                e.faction = tostring(value or "")
                if e.faction ~= "" and (e.ownershipType == nil or e.ownershipType == "personal") then
                    e.ownershipType = "government"
                    e.service = true
                    rebuildSelected()
                end
            end

            local kind = skinCombo(vgui.Create("DComboBox", row))
            kind:SetPos(560, 76)
            kind:SetSize(200, 26)
            local kinds = {
                { "Личный купленный", "personal" },
                { "Государственный служебный", "government" },
                { "Общественный транспорт", "public" },
                { "Работа: такси", "job_taxi" },
                { "Работа: мусоровоз", "job_garbage" },
                { "Работа: доставка", "job_courier" },
            }
            local curKind = (GRM.VehicleDealer and GRM.VehicleDealer.EntryKind and GRM.VehicleDealer.EntryKind(e)) or "personal"
            for _, k in ipairs(kinds) do kind:AddChoice(k[1], k[2], curKind == k[2]) end
            kind.OnSelect = function(_, _, _, value)
                e.ownershipType = value
                e.service = value ~= "personal"
            end

            local rem = grmButton(row, "Удалить", C.red)
            rem:SetPos(row:GetWide() - 130, 12)
            rem:SetSize(112, 28)
            rem.PerformLayout = function(self)
                self:SetPos(row:GetWide() - 130, 12)
            end
            rem.DoClick = function()
                table.remove(selected, index)
                rebuildSelected()
                rebuildAvailable()
            end
        end
    end

    searchAvail.OnChange = rebuildAvailable
    rebuildAvailable()
    rebuildSelected()

    save.DoClick = function()
        net.Start("GRM_VD_AdminSave")
        net.WriteEntity(dealer)
        net.WriteTable({ name = nameEntry:GetValue(), model = modelEntry:GetValue(), vehicles = selected })
        net.SendToServer()
        surface.PlaySound("buttons/button15.wav")
    end
end)

print("[GRM VehicleDealer] client v4.0.0 loaded (GRM style, categories, faction picker)")
