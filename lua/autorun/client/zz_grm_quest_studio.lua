--[[--------------------------------------------------------------------
    GRM Quest Studio v2 — один экран: граф + этапы + камеры + награды.
----------------------------------------------------------------------]]
if not CLIENT then return end

GRM = GRM or {}
GRM.Quests = GRM.Quests or {}
local Q = GRM.Quests

surface.CreateFont("GRMQS_Title", { font = "Roboto", size = 20, weight = 800, extended = true })
surface.CreateFont("GRMQS_Body", { font = "Roboto", size = 14, weight = 600, extended = true })
surface.CreateFont("GRMQS_Small", { font = "Roboto", size = 12, weight = 500, extended = true })

local COL = {
    bg = Color(12, 16, 24, 252), side = Color(16, 22, 32), card = Color(26, 34, 46),
    node = Color(30, 42, 56), nodeSel = Color(40, 88, 124), line = Color(70, 140, 180, 180),
    accent = Color(70, 190, 200), gold = Color(245, 195, 70), text = Color(235, 240, 248),
    dim = Color(140, 155, 175), red = Color(210, 75, 75), green = Color(70, 185, 110),
}

local function nodesOf(work, phase)
    work.dialogue = work.dialogue or { offer = {}, active = {}, complete = {} }
    local list = work.dialogue[phase]
    if isstring(list) then
        list = list ~= "" and { { id = "n1", text = list, choices = {} } } or {}
        work.dialogue[phase] = list
    end
    if istable(list) and istable(list.nodes) then list = list.nodes work.dialogue[phase] = list end
    work.dialogue[phase] = istable(list) and list or {}
    return work.dialogue[phase]
end

local function ensureLayout(nodes)
    for i, n in ipairs(nodes) do
        n._x = tonumber(n._x) or (80 + ((i - 1) % 4) * 240)
        n._y = tonumber(n._y) or (60 + math.floor((i - 1) / 4) * 160)
        n.id = tostring(n.id or ("n" .. i))
        n.choices = istable(n.choices) and n.choices or {}
    end
end

local function mkBtn(p, txt, col)
    local b = vgui.Create("DButton", p)
    b:SetText(txt) b:SetFont("GRMQS_Body") b:SetTextColor(COL.text)
    b.Paint = function(s, w, h)
        local c = col or COL.card
        if s:IsHovered() then c = Color(math.min(255, c.r + 22), math.min(255, c.g + 22), math.min(255, c.b + 22)) end
        draw.RoundedBox(6, 0, 0, w, h, c)
    end
    return b
end

local function field(parent, title, val, multi)
    local l = vgui.Create("DLabel", parent)
    l:Dock(TOP) l:SetTall(16) l:DockMargin(10, 8, 10, 0)
    l:SetText(title) l:SetFont("GRMQS_Small") l:SetTextColor(COL.dim)
    local e = vgui.Create("DTextEntry", parent)
    e:Dock(TOP) e:SetTall(multi and 72 or 26) e:DockMargin(10, 2, 10, 0)
    e:SetMultiline(multi == true) e:SetText(tostring(val or ""))
    return e
end

function Q.OpenGraphStudio(data)
    if IsValid(Q.StudioFrame) then Q.StudioFrame:Remove() end
    data = istable(data) and data or {}
    local defs = data.definitions or {}
    local work, tab, phase, selected = nil, "graph", "offer", 0

    local f = vgui.Create("DFrame")
    Q.StudioFrame, Q.AdminFrame = f, f
    if GRM.UI and GRM.UI.Track then GRM.UI.Track("quest_studio", f) end
    f:SetSize(math.Clamp(ScrW() - 36, 1180, 1680), math.Clamp(ScrH() - 36, 720, 1000))
    f:Center() f:SetTitle("") f:MakePopup() f:ShowCloseButton(false)
    f.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, COL.bg)
        draw.RoundedBoxEx(10, 0, 0, w, 48, COL.side, true, true, false, false)
        draw.SimpleText("QUEST STUDIO", "GRMQS_Title", 16, 24, COL.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(work and ((work.title or work.id) .. (work.draft and "  · черновик" or "")) or "нет квеста", "GRMQS_Small", w / 2, 24, COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    local close = mkBtn(f, "X", COL.red)
    close:SetSize(34, 26)
    close.DoClick = function() f:Close() end
    f.PerformLayout = function(_, w) if IsValid(close) then close:SetPos(w - 42, 11) end end

    local left = vgui.Create("DScrollPanel", f)
    left:Dock(LEFT) left:SetWide(248) left:DockMargin(0, 48, 0, 0)
    left.Paint = function(_, w, h) surface.SetDrawColor(COL.side) surface.DrawRect(0, 0, w, h) end

    local right = vgui.Create("DScrollPanel", f)
    right:Dock(RIGHT) right:SetWide(310) right:DockMargin(0, 48, 0, 0)
    right.Paint = function(_, w, h) surface.SetDrawColor(COL.side) surface.DrawRect(0, 0, w, h) end

    local mid = vgui.Create("DPanel", f)
    mid:Dock(FILL) mid:DockMargin(0, 48, 0, 0)
    mid.Paint = function(_, w, h)
        surface.SetDrawColor(20, 26, 36) surface.DrawRect(0, 0, w, h)
        if tab == "graph" then
            surface.SetDrawColor(30, 38, 50)
            for x = 0, w, 32 do surface.DrawLine(x, 36, x, h) end
            for y = 36, h, 32 do surface.DrawLine(0, y, w, y) end
        end
    end

    local bar = vgui.Create("DPanel", mid)
    bar:Dock(TOP) bar:SetTall(36)
    bar.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(18, 24, 34)) end

    local canvas = vgui.Create("DPanel", mid)
    canvas:SetPos(0, 36)
    canvas:SetSize(2200, 1500)
    canvas:SetPaintBackground(false)

    local form = vgui.Create("DScrollPanel", mid)
    form:Dock(FILL) form:DockMargin(8, 4, 8, 8)
    form:SetVisible(false)

    local function currentNodes()
        if not work then return {} end
        return nodesOf(work, phase)
    end

    --[[ ПЕРЕНОС ТЕКСТА В КАРТОЧКЕ (заказ владельца 28.08: «в поле графа
         текст квеста должен нормально отражаться»).

         Раньше карточка резала реплику через string.sub(text,1,42) — на
         скриншоте видно обрубок «- Здравствуй, путник! Ви». Теперь
         разбиваем по словам на строки нужной ширины: видно начало
         реплики целиком, а не половину слова. ]]
    local function wrapText(text, font, maxW, maxLines)
        surface.SetFont(font)
        local words, lines, cur = {}, {}, ""
        for w in tostring(text or ""):gmatch("%S+") do words[#words + 1] = w end
        for _, w in ipairs(words) do
            local try = cur == "" and w or (cur .. " " .. w)
            if surface.GetTextSize(try) <= maxW then
                cur = try
            else
                if cur ~= "" then lines[#lines + 1] = cur end
                cur = w
                if #lines >= maxLines then break end
            end
        end
        if cur ~= "" and #lines < maxLines then lines[#lines + 1] = cur end
        -- Последняя строка получает многоточие, если текст не влез.
        if #lines == maxLines then
            local total = 0
            for _, l in ipairs(lines) do total = total + #l + 1 end
            if total < #tostring(text or "") then
                local last = lines[maxLines]
                while last ~= "" and surface.GetTextSize(last .. "…") > maxW do
                    last = string.sub(last, 1, -2)
                end
                lines[maxLines] = last .. "…"
            end
        end
        return lines
    end

    --[[ РАЗМЕРЫ КАРТОЧКИ. Вынесены в константы: по ним же считаются
         точки выхода связей, иначе линии разъедутся с портами. ]]
    local CARD_W, CARD_H = 250, 116
    local PORT = 13   -- радиус круглого порта на краю карточки

    --[[ Точка выхода: правый край карточки. У реплики один общий выход
         (переход «дальше»), у каждого ответа — свой, они разнесены по
         вертикали, чтобы линии не слипались. ]]
    local function outPort(n, slot, count)
        local x = (n._x or 0) + CARD_W
        local y = (n._y or 0) + 30
        if count and count > 0 then
            y = (n._y or 0) + 46 + (slot - 0.5) * (CARD_H - 56) / count
        end
        return x, y
    end
    local function inPort(n)
        return (n._x or 0), (n._y or 0) + 30
    end

    --[[ Состояние протяжки связи мышью: от какого узла и какого выхода
         тянем. Владелец просил именно «визуально соединять элементы». ]]
    local linking = nil    -- { from = node, slot = 0|N, count = N }

    local function paintLinks()
        canvas.Paint = function(_, cw, ch)
            if tab ~= "graph" then return end
            local nodes = currentNodes()
            local byID = {}
            for _, n in ipairs(nodes) do byID[tostring(n.id)] = n end

            --[[ Связи рисуем КРИВОЙ БЕЗЬЕ, а не прямой линией: на прямых
                 пересекающиеся переходы сливаются в кашу, и непонятно,
                 что куда ведёт. ]]
            local function curve(x1, y1, x2, y2, col)
                local dx = math.max(40, math.abs(x2 - x1) * 0.5)
                local px, py = x1, y1
                surface.SetDrawColor(col)
                for i = 1, 18 do
                    local t = i / 18
                    local mt = 1 - t
                    local x = mt^3 * x1 + 3 * mt^2 * t * (x1 + dx) + 3 * mt * t^2 * (x2 - dx) + t^3 * x2
                    local y = mt^3 * y1 + 3 * mt^2 * t * y1 + 3 * mt * t^2 * y2 + t^3 * y2
                    surface.DrawLine(px, py, x, y)
                    px, py = x, y
                end
                -- Стрелка у цели: сразу видно направление связи.
                surface.DrawLine(x2, y2, x2 - 8, y2 - 5)
                surface.DrawLine(x2, y2, x2 - 8, y2 + 5)
            end

            for _, n in ipairs(nodes) do
                local chs = n.choices or {}
                -- Линейный переход реплики.
                if tostring(n.next or "") ~= "" then
                    local t = byID[tostring(n.next)]
                    if t then
                        local x1, y1 = outPort(n, 0, 0)
                        local x2, y2 = inPort(t)
                        curve(x1, y1, x2, y2, COL.line)
                    end
                end
                -- Переходы от ответов игрока: своим цветом, чтобы отличать.
                for i, c in ipairs(chs) do
                    if tostring(c.next or "") ~= "" then
                        local t = byID[tostring(c.next)]
                        if t then
                            local x1, y1 = outPort(n, i, #chs)
                            local x2, y2 = inPort(t)
                            curve(x1, y1, x2, y2, Color(120, 200, 140, 190))
                        end
                    end
                end
            end

            -- Резинка: тянется за курсором, пока не отпустили кнопку.
            if linking and linking.from then
                local x1, y1 = outPort(linking.from, linking.slot, linking.count)
                local mx, my = canvas:CursorPos()
                surface.SetDrawColor(COL.gold)
                surface.DrawLine(x1, y1, mx, my)
                draw.SimpleText("отпустите на нужной реплике", "GRMQS_Small", mx + 12, my + 6, COL.gold)
            end
        end
    end

    local rebuildProps, rebuildCards, rebuildForm

    rebuildProps = function()
        right:Clear()
        local head = vgui.Create("DLabel", right)
        head:Dock(TOP) head:SetTall(26) head:DockMargin(10, 10, 10, 4)
        head:SetFont("GRMQS_Body") head:SetTextColor(COL.gold)
        head:SetText(tab == "graph" and "УЗЕЛ" or "СВОЙСТВА")
        if not work then return end
        if tab ~= "graph" then
            local hint = vgui.Create("DLabel", right)
            hint:Dock(TOP) hint:SetTall(80) hint:DockMargin(10, 8, 10, 8)
            hint:SetWrap(true) hint:SetFont("GRMQS_Small") hint:SetTextColor(COL.dim)
            hint:SetText("Слева квест. Вкладки сверху — граф диалога, этапы, камеры, награды. Сохранить пишет на сервер.")
            return
        end
        local n = currentNodes()[selected]
        if not n then
            local hint = vgui.Create("DLabel", right)
            hint:Dock(TOP) hint:SetTall(120) hint:DockMargin(10, 8, 10, 8)
            hint:SetWrap(true) hint:SetFont("GRMQS_Small") hint:SetTextColor(COL.dim)
            hint:SetText("Клик по карточке — выбрать.\nТяни за заголовок — переместить.\n\nСВЯЗИ: тяни от круглого порта справа к другой карточке. Серый порт — переход реплики, зелёные — ответы игрока.\n\nПКМ по порту — убрать связь.")
            return
        end
        local idE = field(right, "ID узла", n.id)
        local spE = field(right, "Говорящий", n.speaker)
        local txE = field(right, "Текст", n.text, true)
        local nxE = field(right, "Следующий ID", n.next)
        local apply = mkBtn(right, "Применить узел", COL.green)
        apply:Dock(TOP) apply:SetTall(30) apply:DockMargin(10, 10, 10, 6)
        apply.DoClick = function()
            n.id = string.Trim(idE:GetValue() or "")
            n.speaker, n.text, n.next = spE:GetValue(), txE:GetValue(), nxE:GetValue()
            rebuildCards()
        end
        local addCh = mkBtn(right, "+ Ответ игрока", COL.card)
        addCh:Dock(TOP) addCh:SetTall(26) addCh:DockMargin(10, 4, 10, 4)
        addCh.DoClick = function()
            n.choices = n.choices or {}
            n.choices[#n.choices + 1] = { text = "Новый ответ", next = "", action = "" }
            rebuildProps() rebuildCards()
        end
        for i, ch in ipairs(n.choices or {}) do
            local box = vgui.Create("DPanel", right)
            box:Dock(TOP) box:SetTall(88) box:DockMargin(10, 4, 10, 0)
            box.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, COL.card) end
            local t = vgui.Create("DTextEntry", box) t:SetPos(6, 6) t:SetSize(280, 22) t:SetText(ch.text or "")
            local nx = vgui.Create("DTextEntry", box) nx:SetPos(6, 32) nx:SetSize(130, 22) nx:SetText(ch.next or "")
            local act = vgui.Create("DComboBox", box) act:SetPos(140, 32) act:SetSize(146, 22)
            act:AddChoice("продолжить", "", (ch.action or "") == "")
            act:AddChoice("принять квест", "accept", ch.action == "accept")
            act:AddChoice("закрыть", "close", ch.action == "close")
            t.OnChange = function(s) ch.text = s:GetValue() rebuildCards() end
            nx.OnChange = function(s) ch.next = s:GetValue() rebuildCards() end
            act.OnSelect = function(_, _, _, v) ch.action = v rebuildCards() end
            local del = mkBtn(box, "Удалить", COL.red)
            del:SetPos(6, 58) del:SetSize(80, 22)
            del.DoClick = function() table.remove(n.choices, i) rebuildProps() rebuildCards() end
        end
    end

    rebuildCards = function()
        for _, ch in ipairs(canvas:GetChildren()) do ch:Remove() end
        if tab ~= "graph" then return end
        local nodes = currentNodes()
        ensureLayout(nodes)
        paintLinks()

        --[[ Порт-кружок на краю карточки. От него тянется связь, ПКМ по
             нему связь снимает. Это и есть «визуально соединять
             элементы», о чём просил владелец. ]]
        local function makePort(card, node, slot, count, cy)
            local port = vgui.Create("DPanel", card)
            port:SetSize(PORT, PORT)
            port:SetPos(CARD_W - PORT / 2 - 1, cy - PORT / 2)
            port:SetCursor("hand")
            local isChoice = slot > 0
            port.Paint = function(_, w, h)
                local linked = isChoice and tostring((node.choices[slot] or {}).next or "") ~= ""
                    or (not isChoice and tostring(node.next or "") ~= "")
                local col = isChoice and Color(120, 200, 140) or COL.line
                draw.RoundedBox(w / 2, 0, 0, w, h, linked and col or Color(60, 74, 92))
                if linking and linking.from == node and linking.slot == slot then
                    surface.SetDrawColor(COL.gold) surface.DrawOutlinedRect(0, 0, w, h, 2)
                end
            end
            port.OnMousePressed = function(_, mc)
                if mc == MOUSE_RIGHT then
                    -- Снять связь: частая операция, не должна требовать полей.
                    if isChoice then node.choices[slot].next = "" else node.next = "" end
                    rebuildCards() rebuildProps()
                    return
                end
                linking = { from = node, slot = slot, count = count }
            end
            return port
        end

        for i, n in ipairs(nodes) do
            local card = vgui.Create("DPanel", canvas)
            card:SetPos(n._x or 80, n._y or 80)
            card:SetSize(CARD_W, CARD_H)
            card.Paint = function(_, w, h)
                local sel = selected == i
                draw.RoundedBox(8, 0, 0, w, h, sel and COL.nodeSel or COL.node)
                if sel then
                    surface.SetDrawColor(COL.accent) surface.DrawOutlinedRect(0, 0, w, h, 2)
                end
                -- Полоса заголовка: за неё карточку и таскают.
                draw.RoundedBoxEx(8, 0, 0, w, 24, Color(20, 30, 42), true, true, false, false)
                draw.SimpleText(n.id or ("n" .. i), "GRMQS_Small", 10, 12, COL.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

                --[[ Реплика с переносом по словам. Владелец просил, чтобы
                     текст «нормально отражался» — обрубок на полуслове
                     это как раз то, что было на скриншоте. ]]
                local lines = wrapText(n.text, "GRMQS_Small", w - 24, 3)
                for li, line in ipairs(lines) do
                    draw.SimpleText(line, "GRMQS_Small", 10, 32 + (li - 1) * 15, COL.text)
                end

                local chs = n.choices or {}
                local foot = #chs > 0 and (#chs .. " отв.") or "линейно"
                -- Отдельно помечаем узел, который выдаёт квест: это ключевая точка.
                for _, c in ipairs(chs) do
                    if tostring(c.action or "") == "accept" then foot = foot .. "  ·  ВЫДАЁТ КВЕСТ" break end
                end
                draw.SimpleText(foot, "GRMQS_Small", 10, h - 12, COL.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end

            -- Заголовок: перетаскивание карточки.
            local grip = vgui.Create("DPanel", card)
            grip:SetPos(0, 0) grip:SetSize(CARD_W - PORT * 2, 24)
            grip:SetPaintBackground(false)
            grip:SetCursor("sizeall")
            grip.OnMousePressed = function(self, mc)
                if mc ~= MOUSE_LEFT then return end
                selected = i
                local mx, my = card:CursorPos()
                self._drag, self._ox, self._oy = true, mx, my
                rebuildProps()
            end
            grip.OnMouseReleased = function(self) self._drag = false end
            grip.Think = function(self)
                if self._drag and input.IsMouseDown(MOUSE_LEFT) then
                    local px, py = canvas:CursorPos()
                    n._x = math.max(0, px - (self._ox or 0))
                    n._y = math.max(0, py - (self._oy or 0))
                    card:SetPos(n._x, n._y)
                elseif self._drag then
                    self._drag = false
                end
            end

            -- Клик по телу карточки выбирает её и завершает протяжку связи.
            card.OnMousePressed = function(_, mc)
                if mc ~= MOUSE_LEFT then return end
                selected = i
                rebuildProps()
            end
            card.OnMouseReleased = function()
                --[[ Отпустили связь на этой карточке — она и становится
                     целью. Пишем ID, а не индекс: узлы можно двигать и
                     удалять, ID переживёт перестановку. ]]
                if linking and linking.from and linking.from ~= n then
                    local target = tostring(n.id or "")
                    if linking.slot > 0 then
                        local c = linking.from.choices[linking.slot]
                        if c then c.next = target end
                    else
                        linking.from.next = target
                    end
                    linking = nil
                    rebuildCards() rebuildProps()
                else
                    linking = nil
                end
            end

            -- Порты: общий выход реплики + по одному на каждый ответ.
            local chs = n.choices or {}
            if #chs == 0 then
                makePort(card, n, 0, 0, 30)
            else
                for ci = 1, #chs do
                    local _, py = outPort(n, ci, #chs)
                    makePort(card, n, ci, #chs, py - (n._y or 0))
                end
            end
        end
    end

    --[[ Отпустили кнопку мимо карточек — протяжка отменяется. Без этого
         резинка залипала бы за курсором навсегда. ]]
    canvas.OnMouseReleased = function() linking = nil end
    canvas.Think = function()
        if linking and not input.IsMouseDown(MOUSE_LEFT) then linking = nil end
    end

    local g = {}
    rebuildForm = function()
        form:Clear()
        if not work or tab == "graph" then return end
        if tab == "meta" then
            g.id = field(form, "ID квеста", work.id)
            g.title = field(form, "Название", work.title)
            g.npc = field(form, "ID NPC", work.npc)
            g.summary = field(form, "Описание игроку", work.summary, true)
            g.cat = field(form, "Категория", work.category)
            local function chk(txt, key)
                local c = vgui.Create("DCheckBoxLabel", form)
                c:Dock(TOP) c:SetTall(22) c:DockMargin(10, 6, 10, 0)
                c:SetText(txt) c:SetTextColor(COL.text) c:SetValue(work[key] == true)
                c.OnChange = function(_, v) work[key] = v end
            end
            chk("Включён", "enabled")
            chk("Повтор", "repeatable")
            chk("Автостарт", "autoStart")
            local apply = mkBtn(form, "Записать поля в черновик", COL.green)
            apply:Dock(TOP) apply:SetTall(32) apply:DockMargin(10, 12, 10, 8)
            apply.DoClick = function()
                work.id, work.title = g.id:GetValue(), g.title:GetValue()
                work.npc, work.summary, work.category = g.npc:GetValue(), g.summary:GetValue(), g.cat:GetValue()
            end
        elseif tab == "steps" then
            work.steps = work.steps or {}
            for i, s in ipairs(work.steps) do
                local row = vgui.Create("DPanel", form)
                row:Dock(TOP) row:SetTall(86) row:DockMargin(8, 6, 8, 0)
                row.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, COL.card) end
                local t = vgui.Create("DTextEntry", row) t:SetPos(8, 8) t:SetSize(280, 22) t:SetText(s.title or "")
                t.OnChange = function(e) s.title = e:GetValue() end
                local typ = vgui.Create("DComboBox", row) typ:SetPos(296, 8) typ:SetSize(140, 22)
                for _, k in ipairs({ "visit", "talk", "event", "item" }) do typ:AddChoice(k, k, s.type == k) end
                typ.OnSelect = function(_, _, _, v) s.type = v end
                local ev = vgui.Create("DTextEntry", row) ev:SetPos(8, 36) ev:SetSize(160, 22) ev:SetPlaceholderText("event / npc / item") ev:SetText(s.event or s.npc or s.item or "")
                ev.OnChange = function(e)
                    if s.type == "talk" then s.npc = e:GetValue()
                    elseif s.type == "item" then s.item = e:GetValue()
                    else s.event = e:GetValue() end
                end
                local cnt = vgui.Create("DNumberWang", row) cnt:SetPos(176, 36) cnt:SetSize(70, 22) cnt:SetMin(1) cnt:SetMax(100000) cnt:SetValue(s.count or 1)
                cnt.OnValueChanged = function(_, v) s.count = v end
                local del = mkBtn(row, "×", COL.red) del:SetPos(448, 8) del:SetSize(28, 22)
                del.DoClick = function() table.remove(work.steps, i) rebuildForm() end
            end
            local add = mkBtn(form, "+ Этап", COL.green)
            add:Dock(TOP) add:SetTall(30) add:DockMargin(8, 10, 8, 8)
            add.DoClick = function()
                work.steps[#work.steps + 1] = { type = "event", title = "Новый этап", event = "generic", count = 1 }
                rebuildForm()
            end
            local tool = mkBtn(form, "Тул: зона visit", Color(70, 90, 50))
            tool:Dock(TOP) tool:SetTall(28) tool:DockMargin(8, 0, 8, 8)
            tool.DoClick = function()
                if not work then return end
                RunConsoleCommand("grm_quest_tool_mode", "zone")
                RunConsoleCommand("grm_quest_tool_quest_id", work.id or "")
                RunConsoleCommand("gmod_tool", "grm_quest_tool")
            end
        elseif tab == "cams" then
            work.cutscene = work.cutscene or { accept = {}, complete = {} }
            local phaseBox = vgui.Create("DComboBox", form)
            phaseBox:Dock(TOP) phaseBox:SetTall(26) phaseBox:DockMargin(10, 10, 10, 6)
            phaseBox:AddChoice("При принятии", "accept", true)
            phaseBox:AddChoice("При завершении", "complete")
            local cphase = "accept"
            phaseBox.OnSelect = function(_, _, _, v) cphase = v or "accept" end
            local add = mkBtn(form, "+ Камера из взгляда", COL.green)
            add:Dock(TOP) add:SetTall(30) add:DockMargin(10, 6, 10, 6)
            add.DoClick = function()
                local list = work.cutscene[cphase]
                list[#list + 1] = {
                    id = "camera_" .. (#list + 1), next = "", transition = #list == 0 and "cut" or "move",
                    moveDuration = 1, duration = 3, fov = 75, caption = "",
                    pos = { x = EyePos().x, y = EyePos().y, z = EyePos().z },
                    ang = { p = EyeAngles().p, y = EyeAngles().y, r = EyeAngles().r },
                }
                if list[#list - 1] then list[#list - 1].next = list[#list].id end
                rebuildForm()
            end
            for i, n in ipairs(work.cutscene[cphase] or {}) do
                local row = vgui.Create("DPanel", form)
                row:Dock(TOP) row:SetTall(70) row:DockMargin(10, 4, 10, 0)
                row.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, COL.card) end
                local cap = vgui.Create("DTextEntry", row) cap:SetPos(8, 8) cap:SetSize(300, 22) cap:SetText(n.caption or "")
                cap.OnChange = function(e) n.caption = e:GetValue() end
                local dur = vgui.Create("DNumberWang", row) dur:SetPos(8, 36) dur:SetSize(70, 22) dur:SetMin(0.2) dur:SetMax(30) dur:SetValue(n.duration or 3)
                dur.OnValueChanged = function(_, v) n.duration = v end
                local del = mkBtn(row, "×", COL.red) del:SetPos(316, 8) del:SetSize(28, 22)
                del.DoClick = function() table.remove(work.cutscene[cphase], i) rebuildForm() end
            end
            local tool = mkBtn(form, "Тул: точки в мире", Color(70, 90, 50))
            tool:Dock(TOP) tool:SetTall(28) tool:DockMargin(10, 10, 10, 8)
            tool.DoClick = function()
                RunConsoleCommand("grm_quest_tool_mode", "cutscene")
                RunConsoleCommand("grm_quest_tool_quest_id", work.id or "")
                RunConsoleCommand("grm_quest_tool_phase", cphase)
                RunConsoleCommand("gmod_tool", "grm_quest_tool")
            end
        elseif tab == "loot" then
            work.rewards = work.rewards or { money = 0, items = {} }
            work.achievement = work.achievement or {}
            local mon = field(form, "Деньги за квест", tostring(work.rewards.money or 0))
            local item = field(form, "Предмет ID", "")
            local ic = field(form, "Кол-во предмета", "1")
            local addI = mkBtn(form, "Добавить предмет", COL.green)
            addI:Dock(TOP) addI:SetTall(28) addI:DockMargin(10, 8, 10, 6)
            addI.DoClick = function()
                local id = string.Trim(item:GetValue() or "")
                if id ~= "" then work.rewards.items[id] = math.max(1, tonumber(ic:GetValue()) or 1) end
                rebuildForm()
            end
            for id, c in pairs(work.rewards.items or {}) do
                local lab = vgui.Create("DLabel", form)
                lab:Dock(TOP) lab:SetTall(20) lab:DockMargin(12, 2, 10, 0)
                lab:SetText(id .. " × " .. tostring(c)) lab:SetTextColor(COL.text)
            end
            local ach = vgui.Create("DCheckBoxLabel", form)
            ach:Dock(TOP) ach:SetTall(22) ach:DockMargin(10, 12, 10, 0)
            ach:SetText("Выдать ачивку") ach:SetTextColor(COL.text)
            ach:SetValue(work.achievement.enabled == true)
            ach.OnChange = function(_, v) work.achievement.enabled = v end
            local an = field(form, "Название ачивки", work.achievement.name or work.title)
            local ad = field(form, "Описание ачивки", work.achievement.description or work.summary, true)
            local apply = mkBtn(form, "Записать награды", COL.green)
            apply:Dock(TOP) apply:SetTall(30) apply:DockMargin(10, 10, 10, 8)
            apply.DoClick = function()
                work.rewards.money = math.max(0, tonumber(mon:GetValue()) or 0)
                work.achievement.name = an:GetValue()
                work.achievement.description = ad:GetValue()
                if work.achievement.id == nil or work.achievement.id == "" then
                    work.achievement.id = "quest_" .. tostring(work.id or "")
                end
            end
        end
    end

    local function showTab(id)
        tab = id
        canvas:SetVisible(id == "graph")
        form:SetVisible(id ~= "graph")
        if id == "graph" then rebuildCards() else rebuildForm() end
        rebuildProps()
    end

    local function tabBtn(name, id, x)
        local b = mkBtn(bar, name, COL.card)
        b:SetPos(x, 4) b:SetSize(108, 28)
        b.DoClick = function() showTab(id) end
    end
    tabBtn("Граф", "graph", 8)
    tabBtn("Квест", "meta", 120)
    tabBtn("Этапы", "steps", 232)
    tabBtn("Камеры", "cams", 344)
    tabBtn("Награды", "loot", 456)

    local ph = vgui.Create("DComboBox", bar)
    ph:SetPos(572, 5) ph:SetSize(110, 26)
    ph:AddChoice("До квеста", "offer", true)
    ph:AddChoice("Во время", "active")
    ph:AddChoice("После", "complete")
    ph.OnSelect = function(_, _, _, v) phase = v or "offer" selected = 0 rebuildCards() rebuildProps() end

    local addN = mkBtn(bar, "+ Узел", COL.green)
    addN:SetPos(690, 4) addN:SetSize(90, 28)
    addN.DoClick = function()
        if not work then return end
        showTab("graph")
        local nodes = currentNodes()
        nodes[#nodes + 1] = { id = "n" .. (#nodes + 1), speaker = work.npc or "NPC", text = "Новая реплика", next = "", choices = {}, _x = 140, _y = 140 }
        selected = #nodes
        rebuildCards() rebuildProps()
    end

    local function loadWork(def)
        work = table.Copy(def)
        work.dialogue = work.dialogue or { offer = {}, active = {}, complete = {} }
        work.steps = work.steps or {}
        work.rewards = work.rewards or { money = 0, items = {} }
        work.cutscene = work.cutscene or { accept = {}, complete = {} }
        selected = 0
        showTab(tab)
    end

    local function rebuildList()
        left:Clear()
        local title = vgui.Create("DLabel", left)
        title:Dock(TOP) title:SetTall(22) title:DockMargin(10, 10, 10, 4)
        title:SetText("КВЕСТЫ") title:SetFont("GRMQS_Body") title:SetTextColor(COL.gold)
        for _, d in ipairs(defs) do
            local b = vgui.Create("DButton", left)
            b:Dock(TOP) b:SetTall(44) b:DockMargin(8, 0, 8, 6) b:SetText("")
            b.Paint = function(s, w, h)
                draw.RoundedBox(6, 0, 0, w, h, (work and work.id == d.id) and COL.nodeSel or COL.card)
                draw.SimpleText(d.title or d.id, "GRMQS_Body", 10, 8, COL.text)
                draw.SimpleText((d.draft and "черновик · " or "") .. tostring(#(d.steps or {})) .. " эт.", "GRMQS_Small", 10, 26, COL.dim)
            end
            b.DoClick = function() loadWork(d) end
        end
        local nw = mkBtn(left, "Новый квест", COL.green)
        nw:Dock(TOP) nw:SetTall(30) nw:DockMargin(8, 8, 8, 4)
        nw.DoClick = function()
            local draft = {
                draft = true, id = "quest_" .. os.time(), title = "Новый квест", npc = "guide",
                summary = "", enabled = true, steps = {}, rewards = { money = 0, items = {} },
                dialogue = { offer = {}, active = {}, complete = {} }, cutscene = { accept = {}, complete = {} },
            }
            defs[#defs + 1] = draft
            loadWork(draft)
            rebuildList()
        end
        local sv = mkBtn(left, "Сохранить", COL.green)
        sv:Dock(TOP) sv:SetTall(30) sv:DockMargin(8, 4, 8, 4)
        sv.DoClick = function()
            if not work then return end
            work.draft = #(work.steps or {}) == 0
            net.Start("GRM_Quest_AdminOp")
            net.WriteString("save")
            net.WriteTable(work)
            net.SendToServer()
            notification.AddLegacy("Квест отправлен", NOTIFY_GENERIC, 3)
        end
        local del = mkBtn(left, "Удалить", COL.red)
        del:Dock(TOP) del:SetTall(26) del:DockMargin(8, 4, 8, 8)
        del.DoClick = function()
            if not work then return end
            Derma_Query("Удалить «" .. tostring(work.title) .. "»?", "Студия", "Удалить", function()
                net.Start("GRM_Quest_AdminOp") net.WriteString("delete") net.WriteString(work.id or "") net.SendToServer()
            end, "Отмена")
        end
    end

    rebuildList()
    if defs[1] then loadWork(defs[1]) else rebuildProps() end
end

net.Receive("GRM_Quest_AdminOpen", function()
    Q.OpenGraphStudio(net.ReadTable() or {})
end)

print("[GRM Quest Studio] v2 unified")
