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

    local function paintLinks()
        canvas.Paint = function()
            if tab ~= "graph" then return end
            local nodes = currentNodes()
            local byID = {}
            for _, n in ipairs(nodes) do byID[tostring(n.id)] = n end
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
                    if t then surface.DrawLine(sx, sy, (t._x or 0) + 20, (t._y or 0) + 36) end
                end
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
            hint:Dock(TOP) hint:SetTall(50) hint:DockMargin(10, 8, 10, 8)
            hint:SetWrap(true) hint:SetFont("GRMQS_Small") hint:SetTextColor(COL.dim)
            hint:SetText("Клик по карточке. Тяни заголовок.")
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
            rebuildProps()
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
            t.OnChange = function(s) ch.text = s:GetValue() end
            nx.OnChange = function(s) ch.next = s:GetValue() end
            act.OnSelect = function(_, _, _, v) ch.action = v end
            local del = mkBtn(box, "Удалить", COL.red)
            del:SetPos(6, 58) del:SetSize(80, 22)
            del.DoClick = function() table.remove(n.choices, i) rebuildProps() end
        end
    end

    rebuildCards = function()
        for _, ch in ipairs(canvas:GetChildren()) do ch:Remove() end
        if tab ~= "graph" then return end
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
    addN:SetPos(690, 4) addN:SetSize(90, 28
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
