--[[--------------------------------------------------------------------
    GRM Addon Studio — клиент: окно студии.

    СТРУКТУРА ОКНА:
        слева   — палитра узлов (по категориям из A.Cats);
        центр   — холст 3000x2000: карточки, порты, связи, панорамирование;
        справа  — DPropertySheet с вкладками:
            «Свойства» — инспектор выбранного узла;
            «3D»       — вьюпорт: модель, сетка, гизмо, снимок;
            «Код»      — компиляция: черновик GLua + манифест, копирование.

    ПРИНЦИПЫ.
      * Всё состояние живёт в V.state.work (манифест-проект). Карточки и
        инспектор — его представления; сохранение уходит текстом
        манифеста на сервер (sv_grm_addon_studio).
      * 3D-вьюпорт — собственный cam.Start3D в Paint панели, проекция
        считается вручную (eye/right/up/focal): гизмо и орбита не
        зависят от камеры игры.
      * Снимок — render.Capture: рисуем ту же сцену в буфер, байты
        уходят серверу, он кладёт их в data/grm_studio/shots.
      * Сканы моделей/материалов/звуков идут НА КЛИЕНТЕ по кадрам
        (file.Find "GAME"), чтобы не тащить мегабайты по сети.
----------------------------------------------------------------------]]
if not CLIENT then return end

GRM = GRM or {}
GRM.AddonStudio = GRM.AddonStudio or {}
local A = GRM.AddonStudio

A.UI = A.UI or {}
local V = A.UI

surface.CreateFont("AS_Title", { font = "Roboto", size = 20, weight = 800, extended = true })
surface.CreateFont("AS_Head", { font = "Roboto", size = 15, weight = 700, extended = true })
surface.CreateFont("AS_Body", { font = "Roboto", size = 14, weight = 600, extended = true })
surface.CreateFont("AS_Small", { font = "Roboto", size = 12, weight = 500, extended = true })
surface.CreateFont("AS_Tiny", { font = "Roboto", size = 10, weight = 500, extended = true })

local COL = {
    bg = Color(12, 16, 24, 252), side = Color(16, 22, 32), card = Color(26, 34, 46),
    node = Color(30, 42, 56), nodeSel = Color(40, 88, 124), line = Color(70, 140, 180, 180),
    accent = Color(70, 190, 200), gold = Color(245, 195, 70), text = Color(235, 240, 248),
    dim = Color(140, 155, 175), red = Color(210, 75, 75), green = Color(70, 185, 110),
    grid = Color(30, 38, 50), vp = Color(18, 24, 34),
}

--[[ ЦВЕТ УЗЛА. В общем файле цвета — числами (без Derma), тут Color. ]]
local defColor = {}
local function colorOf(kind)
    local c = defColor[kind]
    if not c then
        local d = A.DefOf(kind)
        local e = d.color or {}
        c = Color(tonumber(e.r) or 120, tonumber(e.g) or 160, tonumber(e.b) or 200)
        defColor[kind] = c
    end
    return c
end

local CARD_W, CARD_H, PORT = 240, 96, 13
local CANVAS_W, CANVAS_H = 3000, 2000

V.state = {
    on = false, work = nil, blocks = {}, selected = 0, linking = nil, toPort = "in",
    panX = 0, panY = 0, projects = {}, drag = nil,
    view = { yaw = 200, pitch = 14, dist = 120, mode = "move", hover = nil, active = nil },
    layout = { sel = 0, drag = nil },
    scan = { started = false, queue = {}, models = {}, materials = {}, sounds = {}, shots = {} },
}

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function notify(txt)
    if GRM.Notify then GRM.Notify(LocalPlayer(), txt, 120, 220, 140) end
end

-- Форвард-декларации: эти функции зовут друг друга вперемешку.
local rebuildAll, rebuildCards, rebuildInspector, rebuildCode, rebuildViewport, scrollToBlock
local addBlock, selectNode, deleteNode
local rebuildLayout, rebuildCheck, renderLayoutWidgets

local function blockByUID(uid)
    for _, b in ipairs(V.state.blocks) do if b.uid == tostring(uid) then return b end end
end

local function selectedBlock()
    return V.state.blocks[V.state.selected]
end

local function vectorFrom(t)
    t = t or {}
    return Vector(tonumber(t.x) or 0, tonumber(t.y) or 0, tonumber(t.z) or 0)
end

local function angleFrom(t)
    t = t or {}
    return Angle(tonumber(t.p) or 0, tonumber(t.y) or 0, tonumber(t.r) or 0)
end

local function mkBtn(parent, txt, col)
    local b = vgui.Create("DButton", parent)
    b:SetText(txt) b:SetFont("AS_Body") b:SetTextColor(COL.text)
    b.Paint = function(s, w, h)
        local c = col or COL.card
        if s:IsHovered() then c = Color(math.min(255, c.r + 22), math.min(255, c.g + 22), math.min(255, c.b + 22)) end
        draw.RoundedBox(6, 0, 0, w, h, c)
    end
    return b
end

-----------------------------------------------------------------------
-- СКАНЫ КАТАЛОГОВ (клиент, по кадрам)
-----------------------------------------------------------------------
--[[ file.Find("GAME") на клиенте видит весь контент сервера, но рекурсия
     по models/ — тысячи записей. Сканируем по 4 папки за тик, чтобы окно
     не фризилось; по завершении каждый список сортируется. ]]
function V.StartScans()
    local st = V.state.scan
    if st.started then return end
    st.started = true
    st.queue = {
        { root = "models/", exts = { mdl = true }, cap = 1400, skip = "models/gm_", list = {}, done = false },
        { root = "materials/", exts = { vmt = true }, cap = 1000, skip = "materials/vgui", list = {}, done = false },
        { root = "sound/", exts = { wav = true, ogg = true, mp3 = true, wma = true }, cap = 1200, skip = "", list = {}, done = false },
    }
    st.models = st.queue[1].list
    st.materials = st.queue[2].list
    st.sounds = st.queue[3].list
end

function V.ScanTick()
    local st = V.state.scan
    if not st.started then return false end
    for _, s in ipairs(st.queue) do
        if not s.done then
            local dirs = s.dirs or { s.root }
            s.dirs = dirs
            local budget = 4
            while budget > 0 and #dirs > 0 do
                budget = budget - 1
                local dir = table.remove(dirs, 1)
                local files, subdirs = file.Find(dir .. "*", "GAME")
                for _, sd in ipairs(subdirs or {}) do dirs[#dirs + 1] = dir .. sd .. "/" end
                for _, f in ipairs(files or {}) do
                    local path = dir .. f
                    local ext = string.match(string.lower(path), "%.([%w]+)$")
                    if ext and s.exts[ext] and #s.list < s.cap
                        and (s.skip == "" or not string.find(path, s.skip, 1, true)) then
                        s.list[#s.list + 1] = path
                    end
                end
            end
            if #dirs == 0 then
                s.done = true
                table.sort(s.list)
            end
            return false
        end
    end
    -- Сканы завершились. Пересобрать окно нужно РОВНО ОДИН раз:
    -- постоянный true ниже заставил бы rebuildAll каждый кадр.
    if not st.finished then
        st.finished = true
        return true
    end
    return false
end

local function scanProgressText()
    local st = V.state.scan
    local done, total = 0, #st.queue
    for _, s in ipairs(st.queue) do if s.done then done = done + 1 end end
    return string.format("Каталоги %d/%d · модели %d · материалы %d · звуки %d",
        done, total, #st.models, #st.materials, #st.sounds)
end

-----------------------------------------------------------------------
-- ПИКЕР (модель/материал/звук/класс/фото)
-----------------------------------------------------------------------
local PICKER_SOURCES = {
    model = function() return V.state.scan.models end,
    material = function() return V.state.scan.materials end,
    sound = function() return V.state.scan.sounds end,
    class = function() return A.CatalogEnts or {} end,
    photo = function() return V.state.scan.shots end,
}

local function openPicker(source, title, onPick)
    local list = source and source() or {}
    local f = vgui.Create("DFrame")
    f:SetSize(420, 480) f:Center() f:SetTitle(title or "Выбрать")
    f:MakePopup() f:SetDraggable(true)
    f.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, COL.bg) end

    local search = vgui.Create("DTextEntry", f)
    search:Dock(TOP) search:SetTall(28) search:DockMargin(8, 8, 8, 0)
    search:SetPlaceholderText("Поиск…")

    local listPanel = vgui.Create("DListView", f)
    listPanel:Dock(FILL) listPanel:DockMargin(8, 4, 8, 8)
    listPanel:AddColumn("Имя")
    listPanel:SetMultiSelect(false)
    listPanel.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, COL.card) end

    local function fill(filter)
        listPanel:Clear()
        local shown = 0
        for _, item in ipairs(list) do
            local s = tostring(item)
            if filter == "" or string.find(string.lower(s), string.lower(filter), 1, true) then
                listPanel:AddLine(s)
                shown = shown + 1
                if shown >= 600 then break end
            end
        end
    end
    fill("")
    search.OnChange = function(_, txt) fill(tostring(txt or "")) end
    listPanel.OnRowSelected = function(_, _, row)
        -- Второй аргумент строки — сама строка, GetLine() тут не нужен.
        local text = row and row.GetValue and row:GetValue(1) or ""
        onPick(tostring(text))
        f:Close() f:Remove()
    end
end

-----------------------------------------------------------------------
-- ПОЛЯ ИНСПЕКТОРА
-----------------------------------------------------------------------
local function fieldRow(parent, f, node, afterChange)
    local row = vgui.Create("DPanel", parent)
    row:Dock(TOP)
    row:SetTall(f.type == "code" and 132 or (f.type == "long" and 76 or 44))
    row:DockMargin(10, 4, 10, 0)
    row:SetPaintBackground(false)

    local lab = vgui.Create("DLabel", row)
    lab:Dock(TOP) lab:SetTall(16)
    lab:SetText(tostring(f.label or "")) lab:SetFont("AS_Small") lab:SetTextColor(COL.dim)

    local function store(v)
        node.data[f.key] = v
        if afterChange then afterChange() end
    end

    local t = f.type
    if t == "check" then
        local box = vgui.Create("DCheckBox", row)
        box:Dock(TOP) box:SetTall(22)
        box:SetChecked(node.data[f.key] == true)
        box.OnChange = function(_, v) store(v == true) end
    elseif t == "select" then
        local cb = vgui.Create("DComboBox", row)
        cb:Dock(TOP) cb:SetTall(24)
        for _, opt in ipairs(f.opts or {}) do cb:AddChoice(tostring(opt[2]), opt[1]) end
        cb:SetValue(tostring(node.data[f.key] or f.def))
        cb.OnSelect = function(_, _, val) store(val) end
    elseif t == "vector" or t == "angle" then
        local names = t == "vector" and { "x", "y", "z" } or { "p", "y", "r" }
        local wrap = vgui.Create("DPanel", row)
        wrap:Dock(TOP) wrap:SetTall(24)
        wrap:SetPaintBackground(false)
        local cur = node.data[f.key] or {}
        --[[ Ширина во время создания ещё 0 (Dock разложит позже) —
             берём ширину родителя, иначе треть = 2px. ]]
        local pw = row:GetWide()
        if pw <= 0 then pw = math.max(300, parent:GetWide()) end
        local third = math.max(30, (pw - 24) / 3)
        for i, k in ipairs(names) do
            local e = vgui.Create("DTextEntry", wrap)
            e:SetPos((i - 1) * (third + 2), 0)
            e:SetSize(third, 24)
            e:SetText(tostring(tonumber(cur[k]) or 0))
            e.OnChange = function(self)
                local n = tonumber(self:GetText())
                cur[k] = n and n or 0
                store(cur)
            end
        end
    elseif t == "color" then
        local cur = node.data[f.key] or {}
        local btn = vgui.Create("DButton", row)
        btn:Dock(TOP) btn:SetTall(24)
        btn:SetText(string.format("#%02X%02X%02X", tonumber(cur.r) or 255, tonumber(cur.g) or 255, tonumber(cur.b) or 255))
        local swatch = vgui.Create("DPanel", btn)
        swatch:SetPos(4, 4) swatch:SetSize(16, 16)
        swatch.Paint = function(_, w, h)
            surface.SetDrawColor(tonumber(cur.r) or 255, tonumber(cur.g) or 255, tonumber(cur.b) or 255, 255)
            surface.DrawRect(0, 0, w, h)
        end
        local mixer
        btn.DoClick = function()
            if IsValid(mixer) then mixer:Remove() mixer = nil return end
            mixer = vgui.Create("DColorMixer", row)
            mixer:Dock(TOP) mixer:SetTall(140)
            mixer:SetColor(Color(tonumber(cur.r) or 255, tonumber(cur.g) or 255, tonumber(cur.b) or 255))
            mixer.ValueChanged = function(_, c)
                cur.r, cur.g, cur.b = c.r, c.g, c.b
                btn:SetText(string.format("#%02X%02X%02X", c.r, c.g, c.b))
                store(cur)
            end
        end
    elseif PICKER_SOURCES[t] then
        local e = vgui.Create("DTextEntry", row)
        local ew = row:GetWide()
        if ew <= 0 then ew = math.max(300, parent:GetWide()) end
        e:Dock(LEFT) e:SetWide(math.max(120, ew - 64)) e:SetTall(24)
        e:SetText(tostring(node.data[f.key] or ""))
        e.OnChange = function(self) store(self:GetText()) end
        local pick = mkBtn(row, "…", COL.accent)
        pick:Dock(RIGHT) pick:SetWide(56) pick:SetTall(24)
        pick.DoClick = function()
            openPicker(PICKER_SOURCES[t], tostring(f.label or ""), function(v) e:SetText(v) store(v) end)
        end
    else
        local e = vgui.Create("DTextEntry", row)
        e:Dock(FILL) e:SetTall(t == "code" and 96 or 24)
        e:SetMultiline(t == "code" or t == "long")
        e:SetText(tostring(node.data[f.key] or ""))
        e.OnChange = function(self)
            local raw = self:GetText()
            if f.type == "number" then
                local n = tonumber(raw)
                store(n and clamp(n, tonumber(f.min) or -1e9, tonumber(f.max) or 1e9) or (tonumber(f.def) or 0))
            else
                store(raw)
            end
        end
    end
end

-----------------------------------------------------------------------
-- ПОРТЫ И КАРТОЧКИ
-----------------------------------------------------------------------
local function outPorts(b)
    local d = A.DefOf(b.kind)
    return d.ports and d.ports.out or { "out" }
end
local function inPorts(b)
    local d = A.DefOf(b.kind)
    return d.ports and d.ports["in"] or { "in" }
end

local function portY(b, side, name)
    local list = side == "out" and outPorts(b) or inPorts(b)
    local idx = 1
    for i, p in ipairs(list) do if p == name then idx = i break end end
    local step = (CARD_H - 52) / (math.max(#list, 1) + 1)
    return 28 + idx * step
end

local function outXY(b, port) return (b.x or 0) + CARD_W, (b.y or 0) + portY(b, "out", port) end
local function inXY(b, port) return (b.x or 0), (b.y or 0) + portY(b, "in", port) end

local function drawLink(x1, y1, x2, y2, col, alpha)
    local back = x2 < x1
    local dx
    if back then dx = math.min(90, math.max(40, math.abs(x2 - x1) * 0.25))
    else dx = math.max(40, math.abs(x2 - x1) * 0.5) end
    surface.SetDrawColor(Color(col.r, col.g, col.b, alpha or 200))
    local px, py = x1, y1
    for i = 1, 18 do
        local t = i / 18
        local mt = 1 - t
        local x = mt ^ 3 * x1 + 3 * mt ^ 2 * t * (x1 + dx) + 3 * mt * t ^ 2 * (x2 - dx) + t ^ 3 * x2
        local y = mt ^ 3 * y1 + 3 * mt ^ 2 * t * y1 + 3 * mt * t ^ 2 * y2 + t ^ 3 * y2
        surface.DrawLine(px, py, x, y)
        px, py = x, y
    end
end

local function canvasPaint()
    local canvas = V.state.canvas
    if not IsValid(canvas) then return end
    local w, h = canvas:GetWide(), canvas:GetTall()
    surface.SetDrawColor(19, 24, 33) surface.DrawRect(0, 0, w, h)
    surface.SetDrawColor(COL.grid)
    for x = 0, w, 32 do surface.DrawLine(x, 0, x, h) end
    for y = 0, h, 32 do surface.DrawLine(0, y, w, y) end

    local work = V.state.work
    if not work then return end
    for _, e in ipairs(work.edges) do
        local a, b = blockByUID(e.a), blockByUID(e.b)
        if a and b then
            local x1, y1 = outXY(a, e.ap)
            local x2, y2 = inXY(b, e.bp)
            drawLink(x1, y1, x2, y2, e.ap == "else" and COL.red or COL.line)
        end
    end
    local L = V.state.linking
    if L and L.from then
        local mx, my = canvas:CursorPos()
        local x1, y1
        if L.side == "out" then x1, y1 = outXY(L.from, L.port) else x1, y1 = inXY(L.from, L.port) end
        drawLink(x1, y1, mx, my, COL.gold, 220)
    end
end

rebuildCards = function()
    local canvas = V.state.canvas
    if not IsValid(canvas) then return end
    for _, c in ipairs(canvas:GetChildren()) do c:Remove() end

    local function makePort(card, b, side, name, cy)
        local port = vgui.Create("DPanel", card)
        port:SetSize(PORT, PORT)
        local x = side == "out" and (CARD_W - PORT / 2 - 1) or (-PORT / 2 + 1)
        port:SetPos(x, cy - PORT / 2)
        port:SetCursor("hand")
        port.Paint = function(_, w, h)
            local linked = false
            for _, e in ipairs((V.state.work and V.state.work.edges) or {}) do
                if side == "out" and e.a == b.uid and e.ap == name then linked = true end
                if side == "in" and e.b == b.uid and e.bp == name then linked = true end
            end
            local col = (name == "else") and Color(235, 90, 90)
                or (linked and Color(120, 200, 140) or Color(60, 74, 92))
            draw.RoundedBox(w / 2, 0, 0, w, h, col)
            local L = V.state.linking
            if L and L.from == b and L.side == side and L.port == name then
                surface.SetDrawColor(COL.gold) surface.DrawOutlinedRect(0, 0, w, h, 2)
            end
        end
        port.OnMousePressed = function(_, mc)
            if mc == MOUSE_RIGHT then
                local work = V.state.work
                local keep = {}
                for _, e in ipairs((work and work.edges) or {}) do
                    local hit = (side == "out" and e.a == b.uid and e.ap == name)
                        or (side == "in" and e.b == b.uid and e.bp == name)
                    if not hit then keep[#keep + 1] = e end
                end
                if work then work.edges = keep end
                rebuildCards() rebuildCode()
                return
            end
            if mc == MOUSE_LEFT then
                V.state.linking = { from = b, side = side, port = name }
                if side == "in" then V.state.toPort = name end
            end
        end
        return port
    end

    for i, b in ipairs(V.state.blocks) do
        local d = A.DefOf(b.kind)
        local card = vgui.Create("DPanel", canvas)
        card:SetPos(b.x or 40, b.y or 40)
        card:SetSize(CARD_W, CARD_H)
        card.Paint = function(_, w, h)
            local sel = V.state.selected == i
            draw.RoundedBox(8, 0, 0, w, h, sel and COL.nodeSel or COL.node)
            if sel then surface.SetDrawColor(COL.accent) surface.DrawOutlinedRect(0, 0, w, h, 2) end
            draw.RoundedBoxEx(8, 0, 0, w, 22, colorOf(b.kind), true, true, false, false)
            draw.SimpleText(d.name, "AS_Tiny", 8, 11, Color(10, 14, 20), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(string.sub(A.Caption(b.kind, b), 1, 58), "AS_Small", 8, 42, COL.text)
            draw.SimpleText("uid " .. tostring(b.uid), "AS_Tiny", 8, h - 14, COL.dim)
        end

        local grip = vgui.Create("DPanel", card)
        grip:SetPos(0, 0) grip:SetSize(CARD_W - PORT * 2, 22)
        grip:SetPaintBackground(false) grip:SetCursor("sizeall")
        grip.OnMousePressed = function(_, mc)
            if mc ~= MOUSE_LEFT then return end
            V.state.selected = i
            local mx, my = card:CursorPos()
            V.state.drag = { b = b, ox = mx, oy = my }
            rebuildInspector() rebuildViewport()
        end
        grip.OnMouseReleased = function() V.state.drag = nil end
        grip.Think = function()
            local drag = V.state.drag
            if not drag or drag.b ~= b then return end
            if input.IsMouseDown(MOUSE_LEFT) then
                local px, py = canvas:CursorPos()
                b.x = clamp(px - drag.ox, 0, CANVAS_W - CARD_W)
                b.y = clamp(py - drag.oy, 0, CANVAS_H - CARD_H)
                card:SetPos(b.x, b.y)
                rebuildCode()
            else
                V.state.drag = nil
            end
        end

        card.OnMousePressed = function(_, mc)
            if mc == MOUSE_LEFT then selectNode(i) end
        end
        card.OnMouseReleased = function(_, mc)
            if mc ~= MOUSE_LEFT then return end
            local L = V.state.linking
            local toPort = V.state.toPort
            V.state.linking = nil
            if L and L.from and L.from ~= b and L.side == "out" then
                V.state.work.edges[#V.state.work.edges + 1] =
                    { a = L.from.uid, ap = L.port, b = b.uid, bp = toPort or "in" }
                rebuildCode()
            end
            rebuildCards()
        end

        for _, p in ipairs(outPorts(b)) do makePort(card, b, "out", p, portY(b, "out", p)) end
        for _, p in ipairs(inPorts(b)) do makePort(card, b, "in", p, portY(b, "in", p)) end
    end
end

-----------------------------------------------------------------------
-- ИНСПЕКТОР
-----------------------------------------------------------------------
rebuildInspector = function()
    local holder = V.state.inspHolder
    if not IsValid(holder) then return end
    for _, c in ipairs(holder:GetChildren()) do c:Remove() end
    local b = selectedBlock()
    if not b then
        local l = vgui.Create("DLabel", holder)
        l:Dock(TOP) l:SetTall(40)
        l:SetText("Выберите блок на холсте") l:SetFont("AS_Small") l:SetTextColor(COL.dim)
        return
    end
    local d = A.DefOf(b.kind)
    local head = vgui.Create("DPanel", holder)
    head:Dock(TOP) head:SetTall(30)
    head.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h - 4, colorOf(b.kind))
        draw.SimpleText(d.name .. " · " .. b.uid, "AS_Small", 8, (h - 4) / 2, Color(10, 14, 20), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    local del = mkBtn(holder, "УДАЛИТЬ БЛОК", COL.red)
    del:Dock(TOP) del:SetTall(24) del:DockMargin(10, 4, 10, 4)
    del.DoClick = function() deleteNode() end

    for _, f in ipairs(d.fields or {}) do
        fieldRow(holder, f, b, function()
            rebuildCards()
            rebuildViewport()
            rebuildCode()
        end)
    end
end

-----------------------------------------------------------------------
-- ПАЛИТРА
-----------------------------------------------------------------------
local function buildPalette()
    local left = V.state.palette
    if not IsValid(left) then return end
    for _, c in ipairs(left:GetChildren()) do
        if not (c == V.state.scanStatus) then c:Remove() end
    end
    for _, cat in ipairs(A.Cats) do
        local h = vgui.Create("DLabel", left)
        h:Dock(TOP) h:SetTall(22)
        h:SetText(string.upper(cat.name)) h:SetFont("AS_Small") h:SetTextColor(COL.gold)
        for _, d in ipairs(A.Defs) do
            if d.cat == cat.id then
                local btn = vgui.Create("DButton", left)
                btn:Dock(TOP) btn:SetTall(30) btn:DockMargin(6, 2, 6, 2)
                btn:SetText(d.name) btn:SetFont("AS_Small") btn:SetTextColor(COL.text)
                btn.Paint = function(s, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(44, 60, 80) or COL.card)
                    draw.RoundedBox(6, 0, 0, 4, h, colorOf(d.id))
                end
                btn.DoClick = function() addBlock(d.id) end
                btn:SetTooltip(d.hint or "")
            end
        end
    end
end

-----------------------------------------------------------------------
-- 3D-ВЬЮПОРТ
-----------------------------------------------------------------------
local function orbitCamera(w, h)
    local st = V.state.view
    local ang = Angle(tonumber(st.pitch) or 14, tonumber(st.yaw) or 200, 0)
    local eye = Vector(0, 0, 0) - ang:Forward() * (tonumber(st.dist) or 120)
    local focal = (h / 2) / math.tan(math.rad(55) / 2)
    local function project(v)
        local rel = v - eye
        local z = rel:Dot(ang:Forward())
        if z <= 2 then return nil end
        return { x = w / 2 + rel:Dot(ang:Right()) * focal / z,
                 y = h / 2 - rel:Dot(ang:Up()) * focal / z, z = z }
    end
    return eye, ang, focal, project
end

local function nodeWorld(b)
    local d = b.data or {}
    return vectorFrom(d.pos), angleFrom(d.ang), tonumber(d.scale) or 1
end

--[[ Сцена вьюпорта. Рисуется и в Paint панели, и в render.Capture —
     одна и та же функция, снимок ровно то, что видно. ]]
local function drawScene(w, h, eye, ang)
    cam.Start3D(eye, ang, 55, w, h, 1, 4000)
    render.SetColorMaterial()
    for gx = -240, 240, 40 do render.DrawBeam(Vector(gx, -240, 0), Vector(gx, 240, 0), 1, 0, 1, Color(36, 46, 62)) end
    for gy = -240, 240, 40 do render.DrawBeam(Vector(-240, gy, 0), Vector(240, gy, 0), 1, 0, 1, Color(36, 46, 62)) end
    render.DrawBeam(Vector(0, 0, 0), Vector(80, 0, 0), 1.6, 0, 1, Color(235, 78, 72))
    render.DrawBeam(Vector(0, 0, 0), Vector(0, 80, 0), 1.6, 0, 1, Color(86, 214, 116))
    render.DrawBeam(Vector(0, 0, 0), Vector(0, 0, 40), 1.6, 0, 1, Color(84, 150, 255))

    local b = selectedBlock()
    if b then
        local pos, angV, scale = nodeWorld(b)
        local kind = b.kind
        if kind == "model" or kind == "prop" then
            local m = tostring((b.data or {}).model or "")
            if m ~= "" then
                local c = (b.data or {}).color or {}
                render.Model(m, pos, angV, scale,
                    Color(tonumber(c.r) or 255, tonumber(c.g) or 255, tonumber(c.b) or 255))
            end
        elseif kind == "entity" then
            render.DrawWireframeBox(pos, angV, Vector(-20, -20, 0), Vector(20, 20, 40))
        elseif kind == "screen" then
            render.DrawWireframeBox(pos, angV, Vector(-40, -8, 0), Vector(40, 8, 50))
        elseif kind == "light" then
            render.DrawWireframeSphere(pos, 12, 8, 8, Color(250, 200, 90, 120))
        else
            render.DrawWireframeSphere(pos, 10, 8, 8, colorOf(b.kind))
        end

        if GRM.Gizmo and (kind == "model" or kind == "prop" or kind == "entity" or kind == "screen") then
            local size = V.state.view.mode == "rotate" and 26 or 34
            GRM.Gizmo.Draw(V.state.view.mode, pos, angV, size, V.state.view.hover, V.state.view.active)
        end
    end
    cam.End3D()
end

--[[ Перетаскивание гизмо. Для перемещения экранное направление оси
     (dx, dy из GRM.Gizmo.Pick) превращается в сдвиг по проекции на
     плоскость, перпендикулярную взгляду: ось ведёт себя предсказуемо. ]]
local function handleGizmoDrag(self)
    local st = V.state.view
    if not st.active then return end
    local b = selectedBlock()
    if not b then st.active = nil return end
    local mx, my = self:ScreenToLocal(gui.MousePos())
    local dpx, dpy = mx - (st.startX or 0), my - (st.startY or 0)
    local dirX, dirY = st.dx or 1, st.dy or 0
    if st.mode == "move" then
        local eye, ang, focal = orbitCamera(self:GetWide(), self:GetTall())
        local pos = vectorFrom(b.data.pos)
        local z = math.max((pos - eye):Dot(ang:Forward()), 6)
        local k = z / focal
        local delta = (dpx * dirX + dpy * dirY) * k
        b.data.pos = b.data.pos or {}
        local cur = tonumber(b.data.pos[st.axisKey]) or 0
        local val = cur + delta
        if input.IsKeyDown(KEY_LCONTROL) then val = math.Round(val, 1) end
        b.data.pos[st.axisKey] = math.Round(val * 10) / 10
    else
        local delta = (dpx * dirX + dpy * dirY) / 5
        b.data.ang = b.data.ang or {}
        local key = GRM.Gizmo.AngleKey(st.axis, "y")
        b.data.ang[key] = math.NormalizeAngle((tonumber(b.data.ang[key]) or 0) + delta)
    end
    rebuildCards() rebuildViewport() rebuildInspector()
end

rebuildViewport = function()
    -- Вьюпорт самодостаточен: Paint пересчитывает камеру из орбиты.
    -- Пересборка здесь нужна только чтобы подсветить изменение полей.
end

local function bindViewport(vp)
    vp.Paint = function(self, w, h)
        local eye, ang = orbitCamera(w, h)
        drawScene(w, h, eye, ang)
        draw.RoundedBox(4, 6, h - 22, w - 12, 18, Color(8, 12, 20, 170))
        draw.SimpleText("ЛКМ-гизмо · ПКМ/средняя-орбита · колесо-зум · Ctrl-шаг 1", "AS_Tiny", 10, h - 16, COL.dim)
    end
    vp.OnMousePressed = function(self, mc)
        local b = selectedBlock()
        if not b then return end
        local visual = b.kind == "model" or b.kind == "prop" or b.kind == "entity" or b.kind == "screen"
        local mx, my = self:ScreenToLocal(gui.MousePos())
        if mc == MOUSE_LEFT and visual and GRM.Gizmo then
            local eye, ang, _, project = orbitCamera(self:GetWide(), self:GetTall())
            local pos = vectorFrom(b.data.pos)
            local size = V.state.view.mode == "rotate" and 26 or 34
            local axis, dx, dy = GRM.Gizmo.Pick(V.state.view.mode, pos, angleFrom(b.data.ang),
                size, mx, my, project, eye)
            if axis then
                local st = V.state.view
                st.active, st.axis = axis, axis
                if st.mode == "move" then st.axisKey = axis
                else st.axisKey = GRM.Gizmo.AngleKey(axis, "y") end
                st.startX, st.startY = mx, my
                st.dx, st.dy = dx, dy
                self:MouseCapture(true)
                return
            end
        end
        if mc == MOUSE_RIGHT or mc == MOUSE_MIDDLE then
            self._orbit = true
            self._ox, self._oy = mx, my
            self._yaw, self._pitch = V.state.view.yaw, V.state.view.pitch
            self:MouseCapture(true)
        end
    end
    vp.OnMouseReleased = function(self)
        self._orbit = false
        V.state.view.active = nil
        V.state.view.hover = nil
        self:MouseCapture(false)
    end
    vp.OnMouseWheeled = function(_, delta)
        local st = V.state.view
        local k = input.IsKeyDown(KEY_LCONTROL) and 8 or 6
        st.dist = clamp((tonumber(st.dist) or 120) - delta * k, 20, 800)
        return true
    end
    vp.Think = function(self)
        local b = selectedBlock()
        local visual = b and (b.kind == "model" or b.kind == "prop" or b.kind == "entity" or b.kind == "screen")
        local mx, my = self:ScreenToLocal(gui.MousePos())
        if self._orbit then
            local st = V.state.view
            st.yaw = (self._yaw or 0) - (mx - (self._ox or 0)) * 0.5
            st.pitch = clamp((self._pitch or 14) + (my - (self._oy or 0)) * 0.5, -70, 70)
        elseif V.state.view.active then
            handleGizmoDrag(self)
        elseif visual and GRM.Gizmo then
            local eye, ang, _, project = orbitCamera(self:GetWide(), self:GetTall())
            local pos = vectorFrom(b.data.pos)
            local size = V.state.view.mode == "rotate" and 26 or 34
            V.state.view.hover = GRM.Gizmo.Pick(V.state.view.mode, pos, angleFrom(b.data.ang),
                size, mx, my, project, eye)
        end
    end
end

--[[ ОТПРАВКА КУСКАМИ. Сетевые сообщения GMod ограничены по размеру,
     конвенция сборки — куски по 8 КБ (GRM.Net.Stream). Сжимаем, режем,
     шлём begin + part-ы; сервер собирает по индексам. ]]
local function sendChunked(tag, rawBytes)
    if not isstring(rawBytes) or rawBytes == "" then return end
    local packed = util.Compress(rawBytes)
    local chunks, size = {}, 8192
    for i = 1, #packed, size do chunks[#chunks + 1] = string.sub(packed, i, math.min(i + size - 1, #packed)) end
    if #chunks > 200 then notify("Слишком большой проект — сократи") return end
    net.Start("GRM_AS_Act")
    net.WriteString("begin")
    net.WriteString(tag)
    net.WriteByte(#chunks)
    net.SendToServer()
    for i, chunk in ipairs(chunks) do
        net.Start("GRM_AS_Act")
        net.WriteString("part")
        net.WriteByte(i)
        net.WriteData(chunk)
        net.SendToServer()
    end
end

local function captureShot(vp)
    local w, h = vp:GetWide(), vp:GetTall()
    if w < 64 or h < 64 then return end
    -- Ограничиваем кадр: 480x320 при 78% качества укладывается в
    -- разумный JPEG для сети без подтормаживаний.
    local k = math.min(1, 480 / w, 320 / h)
    local cw, ch = math.floor(w * k), math.floor(h * k)
    local eye, ang = orbitCamera(cw, ch)
    local data = render.Capture({ x = 0, y = 0, width = cw, height = ch, format = "jpeg", quality = 78 },
        function() drawScene(cw, ch, eye, ang) end)
    if not istable(data) or #data == 0 then notify("Снимок не удался") return end
    local parts = {}
    for i = 1, #data, 1024 do
        parts[#parts + 1] = string.char((table.unpack or unpack)(data, i, math.min(i + 1023, #data)))
    end
    local slug = (V.state.work and V.state.work.id) or "shot"
    sendChunked("photo:" .. slug, table.concat(parts))
    notify("Кадр уходит на сервер кусками…")
end

-----------------------------------------------------------------------
-- КОМПИЛЯЦИЯ / ИМПОРТ
-----------------------------------------------------------------------
rebuildCode = function()
    local holder = V.state.codeHolder
    if not IsValid(holder) then return end
    for _, c in ipairs(holder:GetChildren()) do c:Remove() end
    local work = V.state.work
    if not work then return end
    local tabs = vgui.Create("DPropertySheet", holder)
    tabs:Dock(FILL)

    local function mkCodeTab(label, content, icon)
        local p = vgui.Create("DPanel", tabs)
        p.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, COL.bg) end
        local e = vgui.Create("DTextEntry", p)
        e:Dock(FILL) e:DockMargin(8, 8, 8, 34)
        e:SetMultiline(true) e:SetReadOnly(true)
        e:SetText(content)
        local copy = mkBtn(p, "КОПИРОВАТЬ В БУФЕР", COL.accent)
        copy:Dock(BOTTOM) copy:SetTall(26) copy:DockMargin(8, 0, 8, 6)
        copy.DoClick = function()
            SetClipboardText(tostring(e:GetText() or ""))
            notify("Скопировано — вставь агенту в чат")
        end
        tabs:AddSheet(label, p, icon)
    end

    mkCodeTab("ЧЕРНОВИК КОДА", A.Generate(work), "icon16/page_white_code.png")
    mkCodeTab("МАНИФЕСТ", "local ASPROJECT = " .. A.ToLuaText(work) .. "\n", "icon16/page_white_text.png")
end

local function openImport()
    local f = vgui.Create("DFrame")
    f:SetSize(640, 520) f:Center() f:SetTitle("Импорт манифеста")
    f:MakePopup()
    f.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, COL.bg) end
    local e = vgui.Create("DTextEntry", f)
    e:Dock(FILL) e:DockMargin(10, 10, 10, 42)
    e:SetMultiline(true)
    e:SetPlaceholderText("Вставь текст из вкладки «МАНИФЕСТ» или присланный агентом…")
    local ok = mkBtn(f, "ЗАГРУЗИТЬ", COL.green)
    ok:Dock(BOTTOM) ok:SetTall(30) ok:DockMargin(10, 0, 10, 8)
    ok.DoClick = function()
        local proj = A.ParseText(tostring(e:GetText() or ""))
        if not proj or #(proj.nodes or {}) == 0 then notify("Не распознан манифест") return end
        V.state.work = proj
        V.state.blocks = proj.nodes
        V.state.selected = 0
        rebuildAll()
        f:Close() f:Remove()
    end
end

-----------------------------------------------------------------------
-- ХОЛСТ: ПАНОРАМА, ДОБАВЛЕНИЕ, УДАЛЕНИЕ
-----------------------------------------------------------------------
local function viewSize()
    local mid = V.state.mid
    if not IsValid(mid) then return 800, 600 end
    return mid:GetWide(), math.max(1, mid:GetTall() - 36)
end

local function applyPan()
    local vw, vh = viewSize()
    local minX = math.min(0, vw - CANVAS_W)
    local minY = math.min(0, vh - CANVAS_H)
    V.state.panX = clamp(V.state.panX, minX, 0)
    V.state.panY = clamp(V.state.panY, minY, 0)
    if IsValid(V.state.canvas) then V.state.canvas:SetPos(V.state.panX, 36 + V.state.panY) end
end

addBlock = function(kind)
    local work = V.state.work
    if not work then return end
    local d = A.DefOf(kind)
    if d.once then
        for _, b in ipairs(V.state.blocks) do
            if b.kind == kind then notify("Такой блок уже есть") return end
        end
    end
    local used = {}
    for _, b in ipairs(V.state.blocks) do used[b.uid] = true end
    local n = 1
    while used["n" .. n] do n = n + 1 end
    local node = { uid = "n" .. n, kind = kind, x = 40, y = 40, data = A.Defaults(kind) }

    -- Свободное место в видимой области (блок появляется там, куда смотрит авторизованный).
    local vw, vh = viewSize()
    local stepX, stepY = CARD_W + 28, CARD_H + 24
    local startX = math.max(20, -V.state.panX + 24)
    local startY = math.max(20, -V.state.panY + 24)
    local function free(x, y)
        for _, ob in ipairs(V.state.blocks) do
            if x < (ob.x or 0) + CARD_W + 12 and x + CARD_W + 12 > (ob.x or 0)
                and y < (ob.y or 0) + CARD_H + 12 and y + CARD_H + 12 > (ob.y or 0) then return false end
        end
        return true
    end
    local placed = false
    local cols = math.max(1, math.floor((vw - 48) / stepX))
    local rows = math.max(1, math.floor((vh - 48) / stepY))
    for r = 0, rows - 1 do
        for c = 0, cols - 1 do
            local x, y = startX + c * stepX, startY + r * stepY
            if free(x, y) then node.x, node.y = x, y placed = true break end
        end
        if placed then break end
    end
    V.state.blocks[#V.state.blocks + 1] = node
    work.nodes = V.state.blocks
    V.state.selected = #V.state.blocks
    rebuildAll()
    scrollToBlock(node)
end

scrollToBlock = function(b)
    if not b then return end
    local vw, vh = viewSize()
    local M = 40
    local bx, by = b.x or 0, b.y or 0
    if bx + V.state.panX < M then V.state.panX = M - bx end
    if bx + CARD_W + V.state.panX > vw - M then V.state.panX = vw - M - bx - CARD_W end
    if by + V.state.panY < M then V.state.panY = M - by end
    if by + CARD_H + V.state.panY > vh - M then V.state.panY = vh - M - by - CARD_H end
    applyPan()
end

selectNode = function(i)
    V.state.selected = i
    rebuildInspector()
    rebuildViewport()
    rebuildCards()
end

deleteNode = function()
    local b = selectedBlock()
    if not b then return end
    local work = V.state.work
    local keep = {}
    for _, e in ipairs(work.edges or {}) do
        if e.a ~= b.uid and e.b ~= b.uid then keep[#keep + 1] = e end
    end
    work.edges = keep
    table.remove(V.state.blocks, V.state.selected)
    V.state.selected = math.min(V.state.selected, math.max(0, #V.state.blocks))
    rebuildAll()
end

-----------------------------------------------------------------------
-- КОНСТРУКТОР ОКОН (вкладка «МАКЕТ»)
-----------------------------------------------------------------------
--[[ Реальная сборка виджетов из макета. Одна функция на два случая:
     редактор (клик = выбрать, перетаскивание = двигать) и «ТЕСТ ОКНА»
     (тот же код — значит, дизайн работоспособен, а не «нарисован»).
     Каждый виджет несёт _asIndex — связь с массивом layout.widgets. ]]
renderLayoutWidgets = function(layout, parent, interactive)
    layout = A.NormalizeLayout(layout)
    for _, c in ipairs(parent:GetChildren()) do c:Remove() end
    local box = vgui.Create("DPanel", parent)
    box:SetSize(layout.w, layout.h)
    box:SetPos(0, 0)
    box.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(20, 26, 36))
        surface.SetDrawColor(COL.grid)
        for x = 0, w, 24 do surface.DrawLine(x, 0, x, h) end
        for y = 0, h, 24 do surface.DrawLine(0, y, w, y) end
    end

    for i, wgt in ipairs(layout.widgets) do
        local w, h = tonumber(wgt.w) or 100, tonumber(wgt.h) or 30
        local x, y = tonumber(wgt.x) or 8, tonumber(wgt.y) or 8
        local ctrl
        if wgt.kind == "button" then
            local b = vgui.Create("DButton", box)
            b:SetText(tostring(wgt.label or "Кнопка"))
            b.DoClick = function() end -- действие назначает агент (см. манифест)
            ctrl = b
        elseif wgt.kind == "label" then
            local l = vgui.Create("DLabel", box)
            l:SetText(tostring(wgt.text or "Текст"))
            ctrl = l
        elseif wgt.kind == "entry" then
            local e = vgui.Create("DTextEntry", box)
            e:SetPlaceholderText(tostring(wgt.placeholder or "Ввод…"))
            ctrl = e
        elseif wgt.kind == "check" then
            local c = vgui.Create("DCheckBox", box)
            c:SetText(tostring(wgt.label or "Галка"))
            ctrl = c
        elseif wgt.kind == "slider" then
            local s = vgui.Create("DSlider", box)
            s:SetMinMax(tonumber(wgt.min) or 0, tonumber(wgt.max) or 100)
            s:SetValue(tonumber(wgt.value) or 50)
            ctrl = s
        elseif wgt.kind == "list" then
            local l = vgui.Create("DListView", box)
            l:AddColumn("Вариант")
            for opt in tostring(wgt.options or ""):gmatch("[^;]+") do l:AddLine(string.Trim(opt)) end
            ctrl = l
        elseif wgt.kind == "image" then
            local img = vgui.Create("DImage", box)
            if tostring(wgt.material or "") ~= "" then
                img:SetMaterial(Material(tostring(wgt.material)))
            end
            ctrl = img
        else
            local p = vgui.Create("DPanel", box)
            p.Paint = function(_, ww, hh)
                draw.RoundedBox(4, 0, 0, ww, hh, Color(30, 40, 54))
                draw.SimpleText(tostring(wgt.caption or "Панель"), "AS_Tiny", 4, 2, COL.dim)
            end
            ctrl = p
        end
        ctrl:SetPos(0, 0)
        ctrl:SetSize(w, h)
        if interactive then
            --[[ Хост-обводка: клики и перетаскивание обрабатывает ХОСТ,
                 а не сам виджет. Иначе DTextEntry теряет ввод текста
                 (его OnMousePressed занят фокусом), а DButton — отрисовку. ]]
            local host = vgui.Create("DPanel", box)
            host:SetPos(x, y)
            host:SetSize(w, h)
            ctrl:SetParent(host)
            ctrl:SetPos(0, 0)
            ctrl:SetSize(w, h)
            host.Paint = function(_, ww, hh)
                local selected = V.state.layout.sel == i
                if selected then
                    surface.SetDrawColor(COL.accent)
                    surface.DrawOutlinedRect(0, 0, ww, hh)
                else
                    surface.SetDrawColor(70, 90, 115, 60)
                    surface.DrawOutlinedRect(0, 0, ww, hh)
                end
            end
            host.OnMousePressed = function(_, mc)
                if mc == MOUSE_LEFT then
                    V.state.layout.sel = i
                    V.state.layout.drag = { wgt = wgt, ox = 0, oy = 0 }
                    local mx, my = host:CursorPos()
                    V.state.layout.drag.ox, V.state.layout.drag.oy = mx, my
                    rebuildInspector()
                end
                if mc == MOUSE_RIGHT then
                    table.remove(layout.widgets, i)
                    V.state.layout.sel = 0
                    rebuildLayout()
                    rebuildCode()
                end
            end
            host.Think = function()
                local drag = V.state.layout.drag
                if not drag or drag.wgt ~= wgt then return end
                if input.IsMouseDown(MOUSE_LEFT) then
                    local mx, my = box:CursorPos()
                    wgt.x = math.Clamp(mx - drag.ox, 0, math.max(0, layout.w - w))
                    wgt.y = math.Clamp(my - drag.oy, 0, math.max(0, layout.h - h))
                    host:SetPos(wgt.x, wgt.y)
                else
                    V.state.layout.drag = nil
                end
            end
        else
            ctrl:SetPos(x, y)
            ctrl:SetSize(w, h)
        end
    end
    return box
end

--[[ Шаблоны макета: сохраняются в проекте (project.templates) и уходят
     с манифестом. «ТЕСТ ОКНА» открывает настоящее DFrame с виджетами —
     работоспособность проверяется до компиляции. ]]
rebuildLayout = function()
    local left = V.state.layoutHolder
    if not IsValid(left) then return end
    for _, c in ipairs(left:GetChildren()) do c:Remove() end
    local work = V.state.work
    if not work then return end
    work.layout = A.NormalizeLayout(work.layout or {})

    local bar = vgui.Create("DPanel", left)
    bar:Dock(TOP) bar:SetTall(34)
    bar.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(18, 24, 34)) end

    local function tb(txt, fn)
        local b = mkBtn(bar, txt, COL.card)
        b:Dock(LEFT) b:SetWide(96) b:SetTall(26) b:DockMargin(4, 4, 0, 4)
        b.DoClick = fn
        return b
    end
    tb("ТЕСТ ОКНА", function()
        local f = vgui.Create("DFrame")
        f:SetSize(work.layout.w, work.layout.h)
        f:Center() f:SetTitle(tostring(work.name or "Макет")) f:MakePopup()
        f.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, COL.bg) end
        renderLayoutWidgets(work.layout, f, false)
    end)
    tb("ШАБЛОНЫ", function()
        local menu = DMenu()
        if #(work.templates or {}) == 0 then
            menu:AddOption("Шаблонов нет", function() end):SetEnabled(false)
        else
            for _, tpl in ipairs(work.templates or {}) do
                menu:AddOption(tostring(tpl.name or tpl.id), function()
                    work.layout = A.NormalizeLayout(tpl.layout)
                    V.state.layout.sel = 0
                    rebuildLayout() rebuildCode()
                    notify("Шаблон применён: " .. tostring(tpl.name))
                end)
            end
        end
        menu:AddSpacer()
        menu:AddOption("СОХРАНИТЬ КАК ШАБЛОН…", function()
            local inp = vgui.Create("DFrame")
            inp:SetSize(380, 120) inp:Center() inp:SetTitle("Имя шаблона") inp:MakePopup()
            local e = vgui.Create("DTextEntry", inp)
            e:Dock(FILL) e:DockMargin(10, 10, 10, 34)
            local okb = mkBtn(inp, "ОК", COL.green)
            okb:Dock(BOTTOM) okb:SetTall(26) okb:DockMargin(10, 0, 10, 8)
            okb.DoClick = function()
                local name = string.Trim(tostring(e:GetText() or "Макет"))
                if name == "" then return end
                local list = work.templates or {}
                list[#list + 1] = { id = A.Slug(name), name = name, layout = A.NormalizeLayout(work.layout) }
                work.templates = A.NormalizeTemplates(list)
                rebuildLayout() rebuildCode()
                notify("Шаблон сохранён")
                inp:Close() inp:Remove()
            end
        end)
    end)

    -- Палитра виджетов (по правому краю этой вкладки не влезет — строка кнопок).
    local kinds = vgui.Create("DScrollPanel", bar)
    kinds:Dock(FILL) kinds:SetTall(30) kinds:DockMargin(2, 2, 2, 2)
    kinds.Paint = function() end
    for _, k in ipairs(A.WidgetKinds) do
        local b = vgui.Create("DButton", kinds)
        b:Dock(LEFT) b:SetWide(86) b:SetTall(26) b:DockMargin(2, 0, 2, 0)
        b:SetText(k.name) b:SetFont("AS_Tiny")
        b.DoClick = function()
            local wgt = { kind = k.id, x = 12, y = 12, w = 120, h = 30 }
            for kk, vv in pairs(A.WidgetDefaults[k.id] or {}) do wgt[kk] = vv end
            work.layout.widgets[#work.layout.widgets + 1] = wgt
            V.state.layout.sel = #work.layout.widgets
            rebuildLayout() rebuildCode()
        end
    end

    local scroll = vgui.Create("DScrollPanel", left)
    scroll:Dock(FILL) scroll:DockMargin(0, 34, 0, 0)
    local box = renderLayoutWidgets(work.layout, scroll, true)
    box:Dock(TOP)

    -- Инспектор выбранного виджета.
    local wgt = work.layout.widgets[V.state.layout.sel]
    local inspector = vgui.Create("DPanel", left)
    inspector:Dock(BOTTOM) inspector:SetTall(120)
    inspector.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(22, 30, 42)) end
    if not wgt then
        local l = vgui.Create("DLabel", inspector)
        l:Dock(TOP) l:SetTall(20)
        l:SetText("Выбери виджет и перетащи его") l:SetFont("AS_Tiny") l:SetTextColor(COL.dim)
    else
        local names = { { "x", "x" }, { "y", "y" }, { "w", "w" }, { "h", "h" } }
        local cur = 0
        for _, pair in ipairs(names) do
            local k, lab = pair[1], pair[2]
            local lbl = vgui.Create("DLabel", inspector)
            lbl:SetPos(10 + cur * 110, 8) lbl:SetSize(50, 18)
            lbl:SetText(lab) lbl:SetFont("AS_Tiny") lbl:SetTextColor(COL.dim)
            local e = vgui.Create("DTextEntry", inspector)
            e:SetPos(40 + cur * 110, 6) e:SetSize(60, 20)
            e:SetText(tostring(tonumber(wgt[k]) or 0))
            e.OnChange = function(self)
                local n = tonumber(self:GetText())
                if n then
                    wgt[k] = math.Clamp(n, 0, 4000)
                    rebuildLayout() rebuildCode()
                end
            end
            cur = cur + 1
        end
        local del = mkBtn(inspector, "УДАЛИТЬ", COL.red)
        del:SetPos(10, 40) del:SetSize(88, 24)
        del.DoClick = function()
            table.remove(work.layout.widgets, V.state.layout.sel)
            V.state.layout.sel = 0
            rebuildLayout() rebuildCode()
        end
        local txt = vgui.Create("DTextEntry", inspector)
        txt:SetPos(120, 40) txt:SetSize(math.max(120, inspector:GetWide() - 240), 24)
        txt:SetText(tostring(wgt.label or wgt.text or wgt.caption or ""))
        txt.OnChange = function(self)
            local k = wgt.label ~= nil and "label" or (wgt.text ~= nil and "text" or "caption")
            wgt[k] = self:GetText()
            rebuildLayout()
        end
    end
end

-----------------------------------------------------------------------
-- ПРОВЕРКА ПРОЕКТА (вкладка «ПРОВЕРКА»)
-----------------------------------------------------------------------
rebuildCheck = function()
    local holder = V.state.checkHolder
    if not IsValid(holder) then return end
    for _, c in ipairs(holder:GetChildren()) do c:Remove() end
    local work = V.state.work
    if not work then return end

    local sum = vgui.Create("DLabel", holder)
    sum:Dock(TOP) sum:SetTall(24) sum:DockMargin(10, 6, 10, 0)
    sum:SetFont("AS_Small") sum:SetText("Нажми «ПРОВЕРИТЬ» — валидация манифеста и синтаксис черновика")
    sum:SetTextColor(COL.dim)

    local list = vgui.Create("DListView", holder)
    list:Dock(FILL) list:DockMargin(10, 4, 10, 40)
    list:AddColumn("Тип")
    list:AddColumn("Сообщение")
    list.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, COL.card) end

    local btn = mkBtn(holder, "ПРОВЕРИТЬ", COL.accent)
    btn:Dock(BOTTOM) btn:SetTall(28) btn:DockMargin(10, 0, 10, 8)
    btn.DoClick = function()
        list:Clear()
        --[[ Каталоги с клиента — массивы; валидатор ждёт lookup, строим
             индексы один раз на нажатие. ]]
        local cat = {
            models = A.CatalogIndex(V.state.scan.models or {}),
            materials = A.CatalogIndex(V.state.scan.materials or {}),
            sounds = A.CatalogIndex(V.state.scan.sounds or {}),
            ents = A.CatalogIndex(A.CatalogEnts or {}),
        }
        local res = A.Validate(work, cat)
        local okSyntax, syntaxErr = A.CheckSyntax(work)
        local row = 1
        for _, e in ipairs(res.errors) do
            list:AddLine("ОШИБКА", e)
            list:GetLine(row):SetTextColor(1, Color(210, 75, 75))
            row = row + 1
        end
        for _, w in ipairs(res.warnings) do
            list:AddLine("ПРЕДУПР.", w)
            list:GetLine(row):SetTextColor(1, Color(245, 195, 70))
            row = row + 1
        end
        list:AddLine(okSyntax and "СИНТАКСИС" or "СИНТАКСИС", okSyntax and "черновик компилируется" or tostring(syntaxErr or "ошибка"))
        list:GetLine(row):SetTextColor(1, okSyntax and Color(70, 185, 110) or Color(210, 75, 75))
        row = row + 1
        local head = string.format("Ошибок: %d · Предупреждений: %d · Синтаксис: %s",
            #res.errors, #res.warnings, okSyntax and "OK" or "ошибка")
        sum:SetText(head)
        sum:SetTextColor(#res.errors > 0 and COL.red or (okSyntax and COL.green or COL.gold))
    end
end

rebuildAll = function()
    rebuildInspector()
    rebuildCards()
    rebuildCode()
    rebuildViewport()
    rebuildLayout()
    rebuildCheck()
    if IsValid(V.state.scanStatus) then
        V.state.scanStatus:SetText(scanProgressText())
    end
end

-----------------------------------------------------------------------
-- ОКНО
-----------------------------------------------------------------------
local function newProject()
    V.state.work = A.Normalize({
        name = "Новый проект",
        id = "proj_" .. tostring(math.floor(os.time() % 1000000)),
    })
    V.state.blocks = V.state.work.nodes
    V.state.selected = 0
    rebuildAll()
end

function V.Open()
    if IsValid(V.frame) then
        V.frame:SetVisible(true) V.frame:MakePopup()
        return
    end
    if not V.state.work then newProject() end

    local f = vgui.Create("DFrame")
    V.frame = f
    if GRM.UI and GRM.UI.Track then GRM.UI.Track("addon_studio", f) end
    f:SetSize(math.Clamp(ScrW() - 24, 1180, 1780), math.Clamp(ScrH() - 24, 740, 1040))
    f:Center() f:SetTitle("") f:MakePopup() f:ShowCloseButton(false)
    f.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, COL.bg)
        draw.RoundedBoxEx(10, 0, 0, w, 48, COL.side, true, true, false, false)
        draw.SimpleText("ADDON STUDIO", "AS_Title", 16, 24, COL.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local head = V.state.work and (tostring(V.state.work.name or "") .. " · " .. tostring(V.state.work.id or "")) or "нет проекта"
        draw.SimpleText(head, "AS_Small", w / 2, 16, COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("узлов: " .. #(V.state.blocks or {}) .. " · связей: " .. #((V.state.work and V.state.work.edges) or {}),
            "AS_Tiny", w / 2, 33, COL.accent, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local close = mkBtn(f, "X", COL.red)
    close:SetSize(34, 26)
    close.DoClick = function() f:SetVisible(false) end

    -- Кнопки шапки. Выстраиваются справа в одном PerformLayout.
    local headerBtns = {}
    local function headerBtn(txt, col, fn)
        local b = mkBtn(f, txt, col)
        b:SetSize(118, 26)
        b.DoClick = fn
        headerBtns[#headerBtns + 1] = b
        return b
    end
    headerBtn("НОВЫЙ", COL.card, newProject)
    headerBtn("СОХРАНИТЬ", COL.green, function()
        local work = V.state.work
        if not work then return end
        local id = (work.id or "") == "" and A.Slug(work.name) or work.id
        sendChunked("save:" .. id, "local ASPROJECT = " .. A.ToLuaText(work))
        notify("Сохранение " .. tostring(id) .. "…")
    end)
    headerBtn("ПРОЕКТЫ", COL.card, function()
        local menu = DMenu()
        local projects = V.state.projects or {}
        if #projects == 0 then
            menu:AddOption("Проектов нет", function() end):SetEnabled(false)
        else
            for _, slug in ipairs(projects) do
                menu:AddOption(tostring(slug), function()
                    net.Start("GRM_AS_Act")
                    net.WriteString("load")
                    net.WriteString(tostring(slug))
                    net.SendToServer()
                end)
            end
        end
        menu:Open()
    end)
    headerBtn("ИМПОРТ", COL.card, openImport)
    headerBtn("≈ КОД", COL.accent, function() rebuildCode() end)

    f.PerformLayout = function(_, w)
        if IsValid(close) then close:SetPos(w - 42, 11) end
        local x = w - 42 - 36
        for _, b in ipairs(headerBtns) do
            x = x - 124
            b:SetPos(x, 11)
        end
    end

    -- Палитра слева.
    local left = vgui.Create("DScrollPanel", f)
    left:Dock(LEFT) left:SetWide(224) left:DockMargin(0, 48, 0, 0)
    left.Paint = function(_, w, h) surface.SetDrawColor(COL.side) surface.DrawRect(0, 0, w, h) end
    V.state.palette = left

    local scanStatus = vgui.Create("DLabel", left)
    scanStatus:Dock(BOTTOM) scanStatus:SetTall(20)
    scanStatus:SetText("Каталоги…") scanStatus:SetFont("AS_Tiny") scanStatus:SetTextColor(COL.dim)
    V.state.scanStatus = scanStatus

    -- Правая колонка с вкладками.
    local right = vgui.Create("DPropertySheet", f)
    right:Dock(RIGHT) right:SetWide(500) right:DockMargin(0, 48, 0, 0)

    local insp = vgui.Create("DScrollPanel", right)
    V.state.inspHolder = insp
    right:AddSheet("СВОЙСТВА", insp, "icon16/wrench.png")

    local vpWrap = vgui.Create("DPanel", right)
    vpWrap.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, COL.vp) end
    local vp = vgui.Create("DPanel", vpWrap)
    vp:Dock(FILL) vp:DockMargin(4, 4, 4, 92)
    vp:SetPaintBackground(false)
    V.state.viewPanel = vp
    bindViewport(vp)

    local shot = mkBtn(vpWrap, "СНЯТЬ КАДР", COL.gold)
    shot:Dock(BOTTOM) shot:SetTall(26) shot:DockMargin(4, 0, 4, 62)
    shot.DoClick = function() captureShot(vp) end

    local modeRot = mkBtn(vpWrap, "ВРАЩЕНИЕ", COL.card)
    modeRot:Dock(BOTTOM) modeRot:SetTall(24) modeRot:DockMargin(4, 0, 4, 34)
    modeRot.DoClick = function() V.state.view.mode = "rotate" end

    local modeMove = mkBtn(vpWrap, "ПЕРЕМЕЩЕНИЕ", COL.card)
    modeMove:Dock(BOTTOM) modeMove:SetTall(24) modeMove:DockMargin(4, 0, 4, 6)
    modeMove.DoClick = function() V.state.view.mode = "move" end
    right:AddSheet("3D", vpWrap, "icon16/camera.png")

    local codeWrap = vgui.Create("DPanel", right)
    V.state.codeHolder = codeWrap
    right:AddSheet("КОД", codeWrap, "icon16/page_white_code.png")

    local layoutWrap = vgui.Create("DPanel", right)
    V.state.layoutHolder = layoutWrap
    right:AddSheet("МАКЕТ", layoutWrap, "icon16/layout.png")

    local checkWrap = vgui.Create("DPanel", right)
    V.state.checkHolder = checkWrap
    right:AddSheet("ПРОВЕРКА", checkWrap, "icon16/accept.png")

    -- Центр: холст.
    local mid = vgui.Create("DPanel", f)
    mid:Dock(FILL) mid:DockMargin(0, 48, 0, 0)
    V.state.mid = mid
    mid.Paint = function(_, w, h) surface.SetDrawColor(19, 24, 33) surface.DrawRect(0, 0, w, h) end

    local bar = vgui.Create("DPanel", mid)
    bar:Dock(TOP) bar:SetTall(36)
    bar.Paint = function(_, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(18, 24, 34))
        draw.SimpleText("Палитра слева → блок на холст. Выход (справа) → вход (слева). ПКМ по порту — снять связь. Delete — удалить блок. ПКМ/колесо по пустому — панорама.",
            "AS_Tiny", 12, h / 2, COL.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local canvas = vgui.Create("DPanel", mid)
    canvas:SetPos(0, 36)
    canvas:SetSize(CANVAS_W, CANVAS_H)
    canvas:SetPaintBackground(false)
    V.state.canvas = canvas
    canvas.Paint = canvasPaint

    canvas.OnMousePressed = function(self, mc)
        if mc == MOUSE_RIGHT or mc == MOUSE_MIDDLE then
            local mx, my = gui.MousePos()
            self._pan, self._px, self._py = true, mx, my
            self._sx, self._sy = V.state.panX, V.state.panY
            self:MouseCapture(true)
        end
        V.state.linking = nil
        if mc == MOUSE_LEFT then
            V.state.selected = 0
            rebuildInspector() rebuildViewport()
        end
    end
    canvas.OnMouseReleased = function(self)
        V.state.linking = nil
        if self._pan then self._pan = false self:MouseCapture(false) end
    end
    canvas.OnMouseWheeled = function(_, delta)
        if input.IsKeyDown(KEY_LSHIFT) or input.IsKeyDown(KEY_RSHIFT) then
            V.state.panX = V.state.panX + delta * 90
        else
            V.state.panY = V.state.panY + delta * 90
        end
        applyPan()
        return true
    end
    canvas.Think = function(self)
        if V.state.linking and not input.IsMouseDown(MOUSE_LEFT) then V.state.linking = nil end
        if self._pan then
            if input.IsMouseDown(MOUSE_RIGHT) or input.IsMouseDown(MOUSE_MIDDLE) then
                local mx, my = gui.MousePos()
                V.state.panX = (self._sx or 0) + (mx - (self._px or mx))
                V.state.panY = (self._sy or 0) + (my - (self._py or my))
                applyPan()
            else
                self._pan = false
                self:MouseCapture(false)
            end
        end
    end

    f.Think = function()
        if V.ScanTick() then
            rebuildAll()
        end
    end
    f.OnKeyCodePressed = function(_, code)
        if code == KEY_DELETE then deleteNode() end
    end

    applyPan()
    buildPalette()
    rebuildAll()
    f:SetVisible(true)
    V.state.on = true
end

-----------------------------------------------------------------------
-- СЕТЬ
-----------------------------------------------------------------------
net.Receive("GRM_AS_Open", function()
    V.Open()
end)

net.Receive("GRM_AS_Sync", function()
    local payload = net.ReadTable() or {}
    if istable(payload.ents) then A.CatalogEnts = payload.ents end
    if istable(payload.projects) then V.state.projects = payload.projects end
    if istable(payload.shots) then V.state.scan.shots = payload.shots end
    if payload.shotPath then
        V.state.scan.shots[#V.state.scan.shots + 1] = payload.shotPath
        notify("Кадр сохранён: " .. tostring(payload.shotPath))
        rebuildInspector()
    end
    if payload.saved then notify("Проект сохранён: " .. tostring(payload.saved)) end
    if payload.loadError then notify("Загрузка не удалась: " .. tostring(payload.loadError)) end
    if payload.project then
        V.state.work = A.Normalize(payload.project)
        V.state.blocks = V.state.work.nodes
        V.state.selected = 0
        if IsValid(V.frame) then rebuildAll() end
        notify("Проект загружен")
    end
end)

V.StartScans()

print("[GRM Addon Studio] client loaded")
