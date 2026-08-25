
------------------------------------------------------------------
-- РЕДАКТОР ОГРАНИЧЕНИЙ БОДИГРУПП ПО ФРАКЦИЯМ/РОЛЯМ/ОТДЕЛАМ
-- Повторяет стиль /models_admin: дерево структуры слева,
-- список моделей и живой предпросмотр справа.
------------------------------------------------------------------
local FB = FB or GRM.FactionBodygroups
if not FB then return end

if SERVER then AddCSLuaFile() return end

surface.CreateFont("GRMFB_Title", { font = "Roboto", size = 20, weight = 800, extended = true })
surface.CreateFont("GRMFB_Head",  { font = "Roboto", size = 15, weight = 700, extended = true })
surface.CreateFont("GRMFB_Body",  { font = "Roboto", size = 13, weight = 500, extended = true })
surface.CreateFont("GRMFB_Small", { font = "Roboto", size = 11, weight = 500, extended = true })

local COL = {
    bg = Color(16, 20, 28, 252), head = Color(12, 15, 22, 255),
    card = Color(22, 28, 38, 245), cardH = Color(30, 38, 52, 245),
    sel = Color(38, 62, 96, 250), border = Color(38, 48, 66, 200),
    acc = Color(65, 145, 235), green = Color(55, 185, 110),
    gold = Color(245, 195, 65), red = Color(225, 70, 70),
    text = Color(240, 244, 250), dim = Color(155, 170, 190),
}

local function trim(s) return string.Trim(tostring(s or "")) end
local function niceName(key, displayName)
    if displayName and displayName ~= "" then return displayName .. " (" .. key .. ")" end
    return key
end

-- Текущий выбор scope: faction, role/department, model
local state = { faction = nil, scopeKind = "faction", scopeKey = "all", model = "*" }

local function ruleKey()
    return table.concat({ state.faction or "", state.scopeKey or "all", string.lower(state.model or "*") }, "|")
end

local function getRule(group)
    FB.Rules = FB.Rules or {}
    local row = FB.Rules[ruleKey()]
    return row and row[tonumber(group)] or nil
end

local function setRule(group, rule)
    FB.Rules = FB.Rules or {}
    local k = ruleKey()
    FB.Rules[k] = FB.Rules[k] or {}
    FB.Rules[k][tonumber(group)] = rule
end

local function clearRule(group)
    FB.Rules = FB.Rules or {}
    local row = FB.Rules[ruleKey()]
    if row then row[tonumber(group)] = nil end
end

------------------------------------------------------------------
-- Собираем модели, доступные фракции/роли/отделу (из лоадаута)
------------------------------------------------------------------
local function modelListForScope()
    local out = { "*" }
    local seen = { ["*"] = true }
    local function add(list)
        for _, e in ipairs(list or {}) do
            if isstring(e) and not seen[e:lower()] then
                seen[e:lower()] = true out[#out + 1] = e
            elseif istable(e) and e.path and not seen[e.path:lower()] then
                seen[e.path:lower()] = true out[#out + 1] = e.path
            end
        end
    end
    if not state.faction then return out end
    local f = (FactionsData or Factions or {})[state.faction]
    if not istable(f) then return out end
    if state.scopeKind == "faction" then
        add(f.Models); add(f.model); add(f.DefaultModels)
        for _, r in ipairs(f.Roles or {}) do
            if istable(f.RoleModels) then add(f.RoleModels[r]) end
        end
    elseif state.scopeKind == "role" then
        if istable(f.RoleModels) then add(f.RoleModels[state.scopeKey]) end
    elseif state.scopeKind == "department" then
        local d = f.Departments and f.Departments[state.scopeKey]
        if istable(d) then add(d.Models); add(d.model) end
        if istable(f.DepartmentModels) then add(f.DepartmentModels[state.scopeKey]) end
    elseif state.scopeKind == "subdepartment" then
        local parent, sub = state.scopeKey:match("^(.-)/(.+)$")
        local d = f.Departments and f.Departments[parent]
        local s = d and d.Subdepartments and d.Subdepartments[sub]
        if istable(s) then add(s.Models); add(s.model) end
    end
    table.sort(out, function(a, b)
        if a == "*" then return true end
        if b == "*" then return false end
        return a < b
    end)
    return out
end

------------------------------------------------------------------
-- UI
------------------------------------------------------------------
local frame, treePanel, modelPanel, editPanel, previewMdl

local function rebuildEdit()
    if not IsValid(editPanel) then return end
    editPanel:Clear()

    local head = vgui.Create("DPanel", editPanel)
    head:Dock(TOP) head:SetTall(58) head:DockMargin(0, 0, 0, 8)
    head.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, COL.card)
        draw.SimpleText("Модель: " .. (state.model == "*" and "ВСЕ" .. " (" .. state.model .. ")" or state.model),
            "GRMFB_Head", 12, 10, COL.text)
        local scopeLabel = state.scopeKind == "faction" and "Фракция"
            or (state.scopeKind == "role" and "Роль")
            or (state.scopeKind == "department" and "Отдел") or "Подотдел"
        draw.SimpleText(scopeLabel .. ": " .. tostring(state.scopeKey or "—"),
            "GRMFB_Small", 12, 34, COL.dim)
    end

    if not IsValid(previewMdl) then
        previewMdl = vgui.Create("DModelPanel", editPanel)
        previewMdl:Dock(TOP) previewMdl:SetTall(280) previewMdl:DockMargin(0, 0, 0, 8)
        -- крутим модель мышкой
        previewMdl:SetAnimated(true)
        function previewMdl:ApplyModel()
            if state.model == "*" then return end
            local ok = pcall(function() self:SetModel(state.model) end)
            if ok then
                local ent = self:GetEntity()
                if IsValid(ent) then
                    ent:SetSkin(0)
                    for i = 0, (ent:GetNumBodyGroups() or 1) - 1 do ent:SetBodygroup(i, 0) end
                    -- применить уже сохранённые форсы
                    for gi = 0, (ent:GetNumBodyGroups() or 1) - 1 do
                        local r = getRule(gi)
                        if r and r.force ~= nil then ent:SetBodygroup(gi, r.force) end
                    end
                    -- поставить камеру по росту модели
                    local mn, mx = ent:GetRenderBounds()
                    local center = (mn + mx) * 0.5
                    local height = math.max(16, mx.z - mn.z)
                    local width  = math.max(16, math.max(mx.x - mn.x, mx.y - mn.y))
                    local fov = 30
                    local need = math.max(height, width * 1.4)
                    local dist = (need / math.tan(math.rad(fov / 2))) * 0.9
                    self:SetFOV(fov)
                    self:SetLookAt(center + Vector(0, 0, height * 0.04))
                    self:SetCamPos(center + Vector(dist * 0.55, dist * 0.85, height * 0.02))
                end
            end
        end
        -- вращение ЛКМ и зум колесом
        previewMdl.OnMousePressed = function(s) s:MouseCapture(true) s._drag = true end
        previewMdl.OnMouseReleased = function(s) s:MouseCapture(false) s._drag = false end
        previewMdl.OnCursorMoved = function(s, x, y)
            if not s._drag then return end
            local ang = s:GetAngles() or Angle(0, 0, 0)
            ang.y = ang.y - (gui.MouseX() - (s._lx or gui.MouseX())) * 0.4
            s:SetAngles(Angle(0, ang.y, 0))
            s._lx, s._ly = gui.MouseX(), gui.MouseY()
        end
        previewMdl._yaw = 0
        previewMdl.LayoutEntity = function(self, ent)
            if not IsValid(ent) then return end
            -- поворот модели мышью
            ent:SetAngles(Angle(0, (self._yaw or 0), 0))
        end
        previewMdl.OnCursorMoved = function(s, x, y)
            if not s._drag then return end
            s._yaw = (s._yaw or 0) - (x - (s._lx or x)) * 0.5
            s._lx, s._ly = x, y
        end
        previewMdl.OnMouseWheeled = function(s, delta)
            local cp = s:GetCamPos()
            local la = s:GetLookAt()
            local d = cp - la
            d = d * (1 - delta * 0.08)
            s:SetCamPos(la + d)
        end
    else
        previewMdl:SetParent(editPanel) previewMdl:Dock(TOP)
    end
    if state.model ~= "*" then previewMdl:ApplyModel() end

    local scroll = vgui.Create("DScrollPanel", editPanel)
    scroll:Dock(FILL)

    if state.model == "*" then
        local hint = vgui.Create("DLabel", scroll)
        hint:Dock(TOP) hint:SetTall(40) hint:SetFont("GRMFB_Small") hint:SetTextColor(COL.dim)
        hint:SetWrap(true)
        hint:SetText("Выберите конкретную модель слева, чтобы настроить бодигруппы. «*» применяется ко всем моделям, если для них нет отдельного правила.")
        return
    end

    -- Используем временную сущность для чтения групп
    local tmp = ClientsideModel(state.model, RENDERGROUP_OTHER)
    if not IsValid(tmp) then
        local err = vgui.Create("DLabel", scroll) err:Dock(TOP) err:SetText("Не удалось загрузить модель")
        err:SetTextColor(COL.red) return
    end
    local count = tmp:GetNumBodyGroups() or 0
    for gi = 0, count - 1 do
        local total = tmp:GetBodygroupCount(gi) or 1
        if total > 1 then
            local gname = tmp:GetBodygroupName(gi)
            if gname == "" then gname = "Группа " .. gi end
            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP) row:SetTall(64) row:DockMargin(0, 0, 0, 4)
            row.Paint = function(_, w, h)
                draw.RoundedBox(6, 0, 0, w, h, COL.cardH)
                draw.SimpleText(string.format("[%d] %s", gi, gname), "GRMFB_Body", 10, 8, COL.text)
                local r = getRule(gi)
                if r and r.force ~= nil then
                    draw.SimpleText("принудительно = " .. r.force, "GRMFB_Small", 10, 30, COL.gold)
                elseif r and r.lock then
                    draw.SimpleText("заблокирована", "GRMFB_Small", 10, 30, COL.red)
                else
                    draw.SimpleText("разрешено", "GRMFB_Small", 10, 30, COL.green)
                end
            end
            local x = 210
            local function chk(txt, val, set)
                local b = vgui.Create("DCheckBoxLabel", row)
                b:SetPos(x, 8) b:SetText(txt) b:SetTextColor(COL.text) b:SetFont("GRMFB_Small")
                b:SetValue(val == true)
                function b:OnChange(v) set(v) end
                x = x + 110
                return b
            end
            local r = getRule(gi)
            local lockChk = chk("Блок", r and r.lock == true, function(v)
                local cur = getRule(gi) or {}
                if v then cur.lock = true cur.force = nil else cur.lock = nil end
                if next(cur) then setRule(gi, cur) else clearRule(gi) end
                rebuildEdit()
            end)
            local forceN = vgui.Create("DNumberWang", row)
            forceN:SetPos(x, 6) forceN:SetSize(70, 22) forceN:SetMin(0) forceN:SetMax(math.max(0, total - 1))
            forceN:SetValue(tonumber(r and r.force) or 0)
            forceN:SetTooltip("Принудительное значение (0 .. " .. (total - 1) .. ")")
            forceN.OnValueChanged = function(_, v)
                local cur = getRule(gi) or {}
                cur.force = math.Clamp(math.floor(tonumber(v) or 0), 0, total - 1)
                cur.lock = true
                setRule(gi, cur)
                if IsValid(previewMdl) then
                    local e = previewMdl:GetEntity()
                    if IsValid(e) then e:SetBodygroup(gi, cur.force) end
                end
            end
            local clear = vgui.Create("DButton", row)
            clear:SetPos(x + 80, 6) clear:SetSize(80, 22) clear:SetText("Сбросить")
            clear:SetTextColor(COL.text) clear:SetFont("GRMFB_Small")
            clear.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(150,60,60) or Color(90,50,50)) end
            clear.DoClick = function() clearRule(gi) rebuildEdit() end
        end
    end
    tmp:Remove()
end

local function rebuildModels()
    if not IsValid(modelPanel) then return end
    modelPanel:Clear()
    local list = modelListForScope()
    local function addRow(path, label)
        local b = vgui.Create("DButton", modelPanel)
        b:Dock(TOP) b:SetTall(28) b:DockMargin(0, 0, 0, 3) b:SetText("")
        local active = path == state.model
        b.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, active and COL.sel or COL.cardH)
            draw.SimpleText(label or path, "GRMFB_Body", 10, h / 2, active and COL.text or COL.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            state.model = path
            rebuildModels() rebuildEdit()
        end
    end
    for _, p in ipairs(list) do addRow(p, p == "*" and "ВСЕ модели (*)" or p) end
end


local function allFactions()
    local out = {}
    for _, src in ipairs({ FactionsData, Factions, GRM.Factions and GRM.Factions.Data }) do
        if istable(src) then for k, v in pairs(src) do if istable(v) then out[k] = v end end end
    end
    return out
end

local function rebuildTree()
    if not IsValid(treePanel) then return end
    treePanel:Clear()
    local data = allFactions()
    local keys = {}
    for k in pairs(data) do keys[#keys + 1] = k end
    table.sort(keys)
    for _, fkey in ipairs(keys) do
        local f = data[fkey]
        if not istable(f) then continue end
        local b = vgui.Create("DButton", treePanel)
        b:Dock(TOP) b:SetTall(26) b:DockMargin(0, 0, 0, 2) b:SetText("")
        local active = (state.faction == fkey and state.scopeKind == "faction")
        b.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, active and COL.sel or COL.card)
            draw.SimpleText("● " .. niceName(fkey, f.DisplayName), "GRMFB_Body", 10, h / 2, COL.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function()
            state.faction = fkey state.scopeKind = "faction" state.scopeKey = "all"
            state.model = "*" rebuildTree() rebuildModels() rebuildEdit()
        end
        -- роли
        for _, rk in ipairs(f.Roles or {}) do
            local rb = vgui.Create("DButton", treePanel)
            rb:Dock(TOP) rb:SetTall(22) rb:DockMargin(16, 0, 0, 2) rb:SetText("")
            local on = (state.faction == fkey and state.scopeKind == "role" and state.scopeKey == rk)
            rb.Paint = function(s, w, h)
                draw.RoundedBox(4, 0, 0, w, h, on and COL.sel or Color(0,0,0,0))
                draw.SimpleText("◆ " .. (GRM.Factions.RoleDisplayName and GRM.Factions.RoleDisplayName(fkey, rk) or rk),
                    "GRMFB_Small", 10, h / 2, on and COL.text or COL.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            rb.DoClick = function()
                state.faction = fkey state.scopeKind = "role" state.scopeKey = rk state.model = "*"
                rebuildTree() rebuildModels() rebuildEdit()
            end
        end
        -- отделы
        for dk, d in SortedPairs(f.Departments or {}) do
            local db = vgui.Create("DButton", treePanel)
            db:Dock(TOP) db:SetTall(22) db:DockMargin(16, 0, 0, 2) db:SetText("")
            local on = (state.faction == fkey and state.scopeKind == "department" and state.scopeKey == dk)
            db.Paint = function(s, w, h)
                draw.RoundedBox(4, 0, 0, w, h, on and COL.sel or Color(0,0,0,0))
                draw.SimpleText("▸ " .. niceName(dk, GRM.Factions.DepartmentDisplayName and GRM.Factions.DepartmentDisplayName(fkey, dk) or dk),
                    "GRMFB_Small", 10, h / 2, on and COL.text or COL.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            db.DoClick = function()
                state.faction = fkey state.scopeKind = "department" state.scopeKey = dk state.model = "*"
                rebuildTree() rebuildModels() rebuildEdit()
            end
        end
    end
end

local function openEditor()
    if IsValid(frame) then frame:Remove() end
    frame = vgui.Create("DFrame")
    frame:SetSize(math.max(1280, ScrW()*0.92), math.max(820, ScrH()*0.92)) frame:Center() frame:MakePopup()
    frame:SetTitle("") frame:ShowCloseButton(false)
    frame.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, COL.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 46, COL.head, true, true, false, false)
        draw.SimpleText("Ограничения бодигрупп по фракциям", "GRMFB_Title", 16, 23, COL.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    local close = vgui.Create("DButton", frame) close:SetPos(1140, 10) close:SetSize(30, 26) close:SetText("X")
    close:SetTextColor(COL.text) close.Paint = function(s, w, h) draw.RoundedBox(4,0,0,w,h,s:IsHovered() and COL.red or Color(45,52,68)) end
    close.DoClick = function() frame:Close() end

    local refresh = vgui.Create("DButton", frame) refresh:SetPos(770, 10) refresh:SetSize(120, 26) refresh:SetText("ОБНОВИТЬ")
    refresh:SetTextColor(COL.text) refresh:SetFont("GRMFB_Body")
    refresh.Paint = function(s,w,h) draw.RoundedBox(4,0,0,w,h,s:IsHovered() and Color(60,110,160) or Color(40,70,110)) end
    refresh.DoClick = function()
        net.Start("Factions_GetData") net.SendToServer()
        rebuildTree() rebuildModels() rebuildEdit()
    end

    local save = vgui.Create("DButton", frame) save:SetPos(900, 10) save:SetSize(120, 26) save:SetText("СОХРАНИТЬ")
    save:SetTextColor(COL.text) save:SetFont("GRMFB_Body")
    save.Paint = function(s, w, h) draw.RoundedBox(4,0,0,w,h,s:IsHovered() and Color(50,160,90) or Color(40,120,70)) end
    save.DoClick = function()
        net.Start(FB.NetSave) net.WriteTable(FB.Rules or {}) net.SendToServer()
        surface.PlaySound("buttons/button15.wav")
    end

    local body = vgui.Create("DPanel", frame)
    body:Dock(FILL) body:DockMargin(8, 54, 8, 8) body:SetPaintBackground(false)

    local left = vgui.Create("DScrollPanel", body)
    left:Dock(LEFT) left:SetWide(280) left:DockMargin(0, 0, 8, 0)
    left.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, COL.card) end
    treePanel = left

    local mid = vgui.Create("DScrollPanel", body)
    mid:Dock(LEFT) mid:SetWide(260) mid:DockMargin(0, 0, 8, 0)
    mid.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, COL.card) end
    modelPanel = mid

    editPanel = vgui.Create("DPanel", body)
    editPanel:Dock(FILL) editPanel:SetPaintBackground(false)

    -- запросить актуальные данные фракций, если локально пусто
    if table.Count(allFactions()) == 0 then
        net.Start("Factions_GetData") net.SendToServer()
    end

    -- выбрать первую фракцию по умолчанию
    if not state.faction then
        for k in pairs(FactionsData or Factions or {}) do state.faction = k state.scopeKind = "faction" state.scopeKey = "all" break end
    end
    rebuildTree() rebuildModels() rebuildEdit()
end

hook.Add("GRM_FactionUIRefreshed", "GRMFB_DataRefresh", function()
    if IsValid(frame) then rebuildTree() rebuildModels() rebuildEdit() end
end)

net.Receive(FB.NetOpen, openEditor)
concommand.Add("grm_faction_bg_editor", function() net.Start(FB.NetOpen) net.SendToServer() end)
