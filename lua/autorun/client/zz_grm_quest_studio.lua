--[[--------------------------------------------------------------------
    GRM Quest Studio — граф диалогов в духе Talksmith.
    Перехватывает /grm_quests_admin: слева квесты, холст узлов, справа свойства.
----------------------------------------------------------------------]]
if not CLIENT then return end

GRM = GRM or {}
GRM.Quests = GRM.Quests or {}
local Q = GRM.Quests

surface.CreateFont("GRMQS_Title", { font = "Roboto", size = 20, weight = 800, extended = true })
surface.CreateFont("GRMQS_Body", { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("GRMQS_Small", { font = "Roboto", size = 12, weight = 500, extended = true })

local COL = {
    bg = Color(14, 18, 26, 252),
    side = Color(18, 24, 34),
    card = Color(28, 36, 48),
    node = Color(32, 44, 58),
    nodeSel = Color(42, 92, 130),
    line = Color(70, 140, 180, 180),
    accent = Color(70, 190, 200),
    gold = Color(245, 195, 70),
    text = Color(235, 240, 248),
    dim = Color(140, 155, 175),
    red = Color(210, 75, 75),
    green = Color(70, 185, 110),
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

local PRESETS = {
    {
        name = "Приветствие и задание",
        desc = "NPC предлагает квест: принять / отказаться / спросить",
        build = function()
            return {
                { id = "start", speaker = "NPC", text = "Есть дело. Возьмёшься?", _x = 80, _y = 80, next = "", choices = {
                    { text = "Расскажи подробнее.", next = "detail" },
                    { text = "Беру.", next = "yes", action = "accept" },
                    { text = "Не сейчас.", next = "no", action = "close" },
                } },
                { id = "detail", speaker = "NPC", text = "Нужно дойти до точки и доложить.", _x = 360, _y = 80, next = "", choices = {
                    { text = "Понял, беру.", next = "yes", action = "accept" },
                    { text = "Потом.", next = "no", action = "close" },
                } },
                { id = "yes", speaker = "NPC", text = "Отлично. Не подведи.", _x = 360, _y = 260, next = "", choices = {} },
                { id = "no", speaker = "NPC", text = "Как скажешь. Я здесь.", _x = 80, _y = 260, next = "", choices = {} },
            }
        end,
    },
    {
        name = "Проверка во время квеста",
        desc = "Напоминание о цели, пока квест активен",
        build = function()
            return {
                { id = "ask", speaker = "NPC", text = "Ну как продвигается?", _x = 120, _y = 120, next = "", choices = {
                    { text = "Ещё в работе.", next = "wait" },
                    { text = "Уже сделал.", next = "done" },
                } },
                { id = "wait", speaker = "NPC", text = "Тогда не стой — вперёд.", _x = 380, _y = 80, next = "", choices = {} },
                { id = "done", speaker = "NPC", text = "Хорошо. Закроем, когда система подтвердит этап.", _x = 380, _y = 240, next = "", choices = {} },
            }
        end,
    },
}

function Q.OpenGraphStudio(data)
    if IsValid(Q.StudioFrame) then Q.StudioFrame:Remove() end
    data = istable(data) and data or {}
    local defs = data.definitions or {}
    local work, phase, selected = nil, "offer", 0

    local f = vgui.Create("DFrame")
    Q.StudioFrame = f
    Q.AdminFrame = f
    if GRM.UI and GRM.UI.Track then GRM.UI.Track("quest_studio", f) end
    f:SetSize(math.Clamp(ScrW() - 40, 1100, 1600), math.Clamp(ScrH() - 40, 700, 980))
    f:Center()
    f:SetTitle("")
    f:MakePopup()
    f:ShowCloseButton(false)
    f.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, COL.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 44, COL.side, true, true, false, false)
        draw.SimpleText("QUEST STUDIO · ГРАФ ДИАЛОГА", "GRMQS_Title", 16, 22, COL.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(work and (work.title or work.id) or "нет квеста", "GRMQS_Small", w / 2, 22, COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    local close = vgui.Create("DButton", f)
    close:SetSize(34, 26) close:SetText("")
    close.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and COL.red or Color(40, 48, 60))
        draw.SimpleText("X", "GRMQS_Body", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    close.DoClick = function() f:Close() end
    f.PerformLayout = function(_, w) if IsValid(close) then close:SetPos(w - 42, 9) end end

    local left = vgui.Create("DScrollPanel", f)
    left:Dock(LEFT) left:SetWide(260) left:DockMargin(0, 44, 0, 0)
    left.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, COL.side) end

    local right = vgui.Create("DScrollPanel", f)
    right:Dock(RIGHT) right:SetWide(320) right:DockMargin(0, 44, 0, 0)
    right.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, COL.side) end

    local mid = vgui.Create("DPanel", f)
    mid:Dock(FILL) mid:DockMargin(0, 44, 0, 0)
    mid.Paint = function(_, w, h)
        surface.SetDrawColor(22, 28, 38)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(32, 40, 52)
        for x = 0, w, 32 do surface.DrawLine(x, 0, x, h) end
        for y = 0, h, 32 do surface.DrawLine(0, y, w, y) end
    end

    local canvas = vgui.Create("DPanel", mid)
    canvas:SetPos(0, 36)
    canvas:SetSize(2000, 1400)
    canvas:SetPaintBackground(false)

    local function currentNodes()
        if not work then return {} end
        return nodesOf(work, phase)
    end

    local function paintLinks()
        canvas.Paint = function(self, w, h)
            local nodes = currentNodes()
            local byID = {}
            for i, n in ipairs(nodes) do byID[tostring(n.id)] = n end
            surface.SetDrawColor(COL.line)
            for _, n in ipairs(nodes) do
                local sx, sy = (n._x or 0) + 200, (n._y or 0) + 36
                local targets = {}
                if tostring(n.next or "") ~= "" then targets[#targets + 1] = n.next end
                for _, ch in ipairs(n.choices or {}) do
                    if tostring(ch.next or "") ~= "" then targets[#targets + 1] = ch.next end
                end
                for _, tid in ipairs(targets) do
                    local t = byID[tostring(tid)]
                    if t then
                        surface.DrawLine(sx, sy, (t._x or 0) + 20, (t._y or 0) + 36)
                    end
                end
            end
        end
    end

    local function rebuildProps()
        right:Clear()
        local head = vgui.Create("DLabel", right)
        head:Dock(TOP) head:SetTall(28) head:DockMargin(10, 10, 10, 4)
        head:SetFont("GRMQS_Body") head:SetTextColor(COL.gold)
        head:SetText("СВОЙСТВА")
        if not work then return end
        local nodes = currentNodes()
        local n = nodes[selected]
        if not n then
            local hint = vgui.Create("DLabel", right)
            hint:Dock(TOP) hint:SetTall(60) hint:DockMargin(10, 8, 10, 8)
            hint:SetWrap(true) hint:SetFont("GRMQS_Small") hint:SetTextColor(COL.dim)
            hint:SetText("Кликните узел на холсте. Перетаскивание — заголовок карточки.")
            return
        end
        local function field(title, val, multi)
            local l = vgui.Create("DLabel", right)
            l:Dock(TOP) l:SetTall(16) l:DockMargin(10, 8, 10, 0)
            l:SetText(title) l:SetFont("GRMQS_Small") l:SetTextColor(COL.dim)
            local e = vgui.Create("DTextEntry", right)
            e:Dock(TOP) e:SetTall(multi and 80 or 26) e:DockMargin(10, 2, 10, 0)
            e:SetMultiline(multi == true) e:SetText(tostring(val or ""))
            return e
        end
        local idE = field("ID узла", n.id)
        local spE = field("Говорящий", n.speaker)
        local txE = field("Текст", n.text, true)
        local nxE = field("Следующий ID", n.next)
        local apply = vgui.Create("DButton", right)
        apply:Dock(TOP) apply:SetTall(32) apply:DockMargin(10, 10, 10, 6)
        apply:SetText("Применить узел")
        apply.DoClick = function()
            n.id = string.Trim(idE:GetValue() or "")
            n.speaker = spE:GetValue()
            n.text = txE:GetValue()
            n.next = nxE:GetValue()
            Q._studioRebuildCards()
        end
        local addCh = vgui.Create("DButton", right)
        addCh:Dock(TOP) addCh:SetTall(28) addCh:DockMargin(10, 4, 10, 4)
        addCh:SetText("+ Ответ игрока")
        addCh.DoClick = function()
            n.choices = n.choices or {}
            n.choices[#n.choices + 1] = { text = "Новый ответ", next = "", action = "" }
            rebuildProps()
        end
        for i, ch in ipairs(n.choices or {}) do
            local box = vgui.Create("DPanel", right)
            box:Dock(TOP) box:SetTall(92) box:DockMargin(10, 4, 10, 0)
            box.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, COL.card) end
            local t = vgui.Create("DTextEntry", box) t:SetPos(6, 6) t:SetSize(290, 22) t:SetText(ch.text or "")
            local nx = vgui.Create("DTextEntry", box) nx:SetPos(6, 32) nx:SetSize(140, 22) nx:SetPlaceholderText("next id") nx:SetText(ch.next or "")
            local act = vgui.Create("DComboBox", box) act:SetPos(152, 32) act:SetSize(144, 22)
            act:AddChoice("продолжить", "", (ch.action or "") == "")
            act:AddChoice("принять квест", "accept", ch.action == "accept")
            act:AddChoice("закрыть", "close", ch.action == "close")
            t.OnChange = function(s) ch.text = s:GetValue() end
            nx.OnChange = function(s) ch.next = s:GetValue() end
            act.OnSelect = function(_, _, _, v) ch.action = v end
            local del = vgui.Create("DButton", box)
            del:SetPos(6, 60) del:SetSize(80, 22) del:SetText("Удалить")
            del.DoClick = function() table.remove(n.choices, i) rebuildProps() end
        end
    end

    function Q._studioRebuildCards()
        for _, ch in ipairs(canvas:GetChildren()) do ch:Remove() end
        local nodes = currentNodes()
        ensureLayout(nodes)
        paintLinks()
        for i, n in ipairs(nodes) do
            local card = vgui.Create("DPanel", canvas)
            card:SetPos(n._x or 80, n._y or 80)
            card:SetSize(220, 88)
            card.Paint = function(_, w, h)
                draw.RoundedBox(8, 0, 0, w, h, selected == i and COL.nodeSel or COL.node)
                draw.SimpleText(n.id or ("n" .. i), "GRMQS_Small", 10, 8, COL.accent)
                draw.SimpleText(string.sub(tostring(n.text or ""), 1, 42), "GRMQS_Small", 10, 28, COL.text)
                draw.SimpleText((#(n.choices or {}) > 0) and (#n.choices .. " ответа") or "линейно", "GRMQS_Small", 10, 66, COL.dim)
            end
            card.OnMousePressed = function(self, mc)
                if mc ~= MOUSE_LEFT then return end
                selected = i
                self._drag = true
                local mx, my = self:CursorPos()
                self._ox, self._oy = mx, my
                rebuildProps()
            end
            card.OnMouseReleased = function(self) self._drag = false end
            card.Think = function(self)
                if self._drag and input.IsMouseDown(MOUSE_LEFT) then
                    local px, py = canvas:CursorPos()
                    n._x = math.max(0, px - (self._ox or 0))
                    n._y = math.max(0, py - (self._oy or 0))
                    self:SetPos(n._x, n._y)
                elseif self._drag then
                    self._drag = false
                end
            end
        end
    end

    local bar = vgui.Create("DPanel", mid)
    bar:Dock(TOP) bar:SetTall(36)
    bar.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, Color(20, 26, 36)) end
    local function phaseBtn(name, id, x)
        local b = vgui.Create("DButton", bar)
        b:SetPos(x, 4) b:SetSize(110, 28) b:SetText(name)
        b.DoClick = function() phase = id selected = 0 Q._studioRebuildCards() rebuildProps() end
    end
    phaseBtn("До квеста", "offer", 8)
    phaseBtn("Во время", "active", 122)
    phaseBtn("После", "complete", 236)
    local addN = vgui.Create("DButton", bar)
    addN:SetPos(360, 4) addN:SetSize(120, 28) addN:SetText("+ Узел")
    addN.DoClick = function()
        if not work then return end
        local nodes = currentNodes()
        nodes[#nodes + 1] = { id = "n" .. (#nodes + 1), speaker = work.npc or "NPC", text = "Новая реплика", next = "", choices = {}, _x = 120, _y = 120 }
        selected = #nodes
        Q._studioRebuildCards()
        rebuildProps()
    end
    local pres = vgui.Create("DButton", bar)
    pres:SetPos(488, 4) pres:SetSize(150, 28) pres:SetText("Пресеты")
    pres.DoClick = function()
        if not work then return end
        local m = DermaMenu()
        for _, p in ipairs(PRESETS) do
            m:AddOption(p.name, function()
                work.dialogue[phase] = p.build()
                selected = 1
                Q._studioRebuildCards()
                rebuildProps()
            end)
        end
        m:Open()
    end
    local test = vgui.Create("DButton", bar)
    test:SetPos(646, 4) test:SetSize(110, 28) test:SetText("Тест")
    test.DoClick = function()
        if not work then return end
        if Q.TalkFrame and IsValid(Q.TalkFrame) then end
        -- reuse in-world dialogue if available via net-less local clone
        local nodes = currentNodes()
        net.Start("GRM_Quest_PlayerOp") -- no: that's server
        -- local preview:
        chat.AddText(COL.gold, "[Студия] ", COL.text, "Превью: " .. tostring(#nodes) .. " узлов фазы " .. phase)
        if isfunction(Q._previewDialogue) then Q._previewDialogue(work.npc or "NPC", nodes) end
    end

    local function loadWork(def)
        work = table.Copy(def)
        work.dialogue = work.dialogue or { offer = {}, active = {}, complete = {} }
        work.steps = work.steps or {}
        work.rewards = work.rewards or { money = 0, items = {} }
        selected = 0
        Q._studioRebuildCards()
        rebuildProps()
    end

    local function rebuildList()
        left:Clear()
        local title = vgui.Create("DLabel", left)
        title:Dock(TOP) title:SetTall(24) title:DockMargin(10, 10, 10, 4)
        title:SetText("КВЕСТЫ") title:SetFont("GRMQS_Body") title:SetTextColor(COL.gold)
        for _, d in ipairs(defs) do
            local b = vgui.Create("DButton", left)
            b:Dock(TOP) b:SetTall(46) b:DockMargin(8, 0, 8, 6) b:SetText("")
            b.Paint = function(s, w, h)
                draw.RoundedBox(6, 0, 0, w, h, (work and work.id == d.id) and COL.nodeSel or COL.card)
                draw.SimpleText(d.title or d.id, "GRMQS_Body", 10, 10, COL.text)
                draw.SimpleText((d.draft and "черновик · " or "") .. tostring(#(d.steps or {})) .. " эт.", "GRMQS_Small", 10, 28, COL.dim)
            end
            b.DoClick = function() loadWork(d) end
        end
        local nw = vgui.Create("DButton", left)
        nw:Dock(TOP) nw:SetTall(32) nw:DockMargin(8, 8, 8, 4) nw:SetText("Новый квест")
        nw.DoClick = function()
            local draft = { draft = true, id = "quest_" .. os.time(), title = "Новый квест", npc = "guide",
                summary = "", enabled = true, steps = {}, rewards = { money = 0, items = {} },
                dialogue = { offer = {}, active = {}, complete = {} }, cutscene = { accept = {}, complete = {} } }
            defs[#defs + 1] = draft
            loadWork(draft)
            rebuildList()
        end
        local sv = vgui.Create("DButton", left)
        sv:Dock(TOP) sv:SetTall(32) sv:DockMargin(8, 4, 8, 4) sv:SetText("Сохранить")
        sv.DoClick = function()
            if not work then return end
            net.Start("GRM_Quest_AdminOp")
            net.WriteString("save")
            net.WriteTable(work)
            net.SendToServer()
            notification.AddLegacy("Квест отправлен на сервер", NOTIFY_GENERIC, 3)
        end
        local del = vgui.Create("DButton", left)
        del:Dock(TOP) del:SetTall(28) del:DockMargin(8, 4, 8, 8) del:SetText("Удалить")
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

-- Перехватываем админ-открытие: старый табличный конструктор больше не главный.
net.Receive("GRM_Quest_AdminOpen", function()
    Q.OpenGraphStudio(net.ReadTable() or {})
end)

print("[GRM Quest Studio] graph UI loaded")
