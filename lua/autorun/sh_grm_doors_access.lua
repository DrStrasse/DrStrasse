--[[--------------------------------------------------------------------
    GRM Doors Access Manager v2.2.0 (Код 64)
    Центральный менеджер прав доступа к дверям, ордерам на обыск и вскрытию.
    Интеграция с меню /factions (вкладка «Двери и Ордера»).
    v2.2.0: вкладка «Категории фракций» — создание/переименование/удаление
            кастомных категорий и объединение фракций в них (используются
            как владельцы дверей и в ACL дверей); меню запоминает активную
            вкладку и прокрутку при авто-обновлении; кнопка быстрого входа
            в категории из вкладки «Двери и Ордера» меню /factions.

      - Управление фракционными категориями;
      - Гибкая выдача прав на ордера на обыск (/warrant):
        по Фракциям, Рангам, Подразделениям (Отделам) и SteamID;
      - Права на таран / вскрытие дверей (ForceDoor);
      - Настройки "своих" фракций/категорий для сигнализаций;
      - Команды: /door_access, !door_access, grm_door_access;
      - Данные: data/grm_doors/access.json.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Doors = GRM.Doors or {}
GRM.Doors.AccessManager = GRM.Doors.AccessManager or {}
local AM = GRM.Doors.AccessManager

local NET_REQ, NET_DATA, NET_SAVE, NET_RESULT, NET_CAT =
    "GRM_DoorAccess_Request", "GRM_DoorAccess_Data", "GRM_DoorAccess_Save", "GRM_DoorAccess_Result", "GRM_DoorAccess_CatAct"

local ACCESS_FILE = "grm_doors/access.json"

local function jsonT(txt)
    local ok, t = pcall(util.JSONToTable, txt, false, true)
    return (ok and istable(t)) and t or nil
end

local function normalize(d)
    d = istable(d) and d or {}
    for _, k in ipairs({
        "ManageFactions", "WarrantFactions", "ForceFactions",
        "ManageRoles", "WarrantRoles", "ForceRoles",
        "ManageDepartments", "WarrantDepartments", "ForceDepartments",
        "ManageSteam", "WarrantSteam", "ForceSteam",
        "AlarmFriendlyFactions", "AlarmFriendlyCategories",
    }) do
        d[k] = istable(d[k]) and d[k] or {}
    end
    return d
end

local function factionInfo(ply)
    if not IsValid(ply) or not istable(Factions) then return nil, nil, nil end
    local sid, sid64 = ply:SteamID(), ply:SteamID64()
    for n, f in pairs(Factions) do
        if istable(f) and istable(f.Members) then
            local m = f.Members[sid] or f.Members[sid64]
            if istable(m) then return n, m.Role, m.Department end
        end
    end
    return nil, nil, nil
end

local function nested(t, fac, key)
    return istable(t) and key and istable(t[fac]) and t[fac][key] == true
end

-- ============================================================
-- СЕРВЕРНАЯ ЧАСТЬ
-- ============================================================
if SERVER then
    util.AddNetworkString(NET_REQ)
    util.AddNetworkString(NET_DATA)
    util.AddNetworkString(NET_SAVE)
    util.AddNetworkString(NET_RESULT)
    util.AddNetworkString(NET_CAT)

    function AM.Load()
        if not file.IsDir("grm_doors", "DATA") then file.CreateDir("grm_doors") end
        if not file.Exists(ACCESS_FILE, "DATA") then
            AM.Data = normalize({
                WarrantFactions = { Polizei = true, FBI = true },
                ForceFactions   = { Polizei = true, FBI = true },
                AlarmFriendlyFactions = { Polizei = true },
            })
            AM.Save(AM.Data)
            return AM.Data
        end
        AM.Data = normalize(jsonT(file.Read(ACCESS_FILE, "DATA") or "") or {})
        return AM.Data
    end

    function AM.Save(data)
        AM.Data = normalize(data or AM.Data)
        local ok, txt = pcall(util.TableToJSON, AM.Data, true)
        if ok and txt then
            file.Write(ACCESS_FILE, txt)
            return true
        end
        return false
    end

    AM.Load()

    local function buildFactionsMap()
        local out = {}
        if istable(Factions) then
            for n, f in pairs(Factions) do
                if istable(f) then
                    out[n] = {
                        Roles = f.Roles or {},
                        Departments = f.Departments or {},
                    }
                end
            end
        end
        return out
    end

    local function sendData(ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        net.Start(NET_DATA)
            net.WriteTable(buildFactionsMap())
            net.WriteTable(AM.Data or normalize({}))
            local cats = {}
            if GRM.Doors and GRM.Doors.Data and GRM.Doors.Data.categories then
                for id, c in pairs(GRM.Doors.Data.categories) do
                    local cc = istable(c) and table.Copy(c) or {}
                    cc.id = id
                    cats[#cats + 1] = cc
                end
            end
            net.WriteTable(cats)
        net.Send(ply)
    end

    net.Receive(NET_REQ, function(_, ply) sendData(ply) end)

    net.Receive(NET_SAVE, function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        AM.Save(net.ReadTable() or {})
        net.Start(NET_RESULT)
            net.WriteBool(true)
            net.WriteString("Настройки доступа к дверям и ордерам сохранены.")
        net.Send(ply)
        sendData(ply)
    end)

    -- v2.2.0: операции с кастомными категориями фракций
    net.Receive(NET_CAT, function(_, ply)
        if not IsValid(ply) or not AM.CanManage(ply) then return end
        if not (GRM.Doors and GRM.Doors.CreateCategory) then return end

        local a = net.ReadTable() or {}
        local op = tostring(a.op or "")
        local ok, res, msg = false, nil, ""

        if op == "create" then
            res, msg = GRM.Doors.CreateCategory(a.id, a.name)
            ok = istable(res)
            if ok then msg = "Категория создана: " .. tostring(res.name or res.id) end
        elseif op == "rename" then
            ok, msg = GRM.Doors.RenameCategory(a.id, a.name)
            if ok then msg = "Категория переименована." end
        elseif op == "delete" then
            ok, msg = GRM.Doors.DeleteCategory(a.id)
            if ok then msg = "Категория удалена (ссылки дверей очищены)." end
        elseif op == "setfaction" then
            ok, msg = GRM.Doors.CategorySetFaction(a.id, a.faction, a.on == true)
            if ok then msg = (a.on and "Фракция добавлена в категорию: " or "Фракция убрана из категории: ") .. tostring(a.faction) end
        else
            msg = "Неизвестная операция."
        end

        net.Start(NET_RESULT)
            net.WriteBool(ok and true or false)
            net.WriteString(tostring(msg or ""))
        net.Send(ply)
        if ok then sendData(ply) end
    end)

    local function checkAccess(ply, manageKey, roleKey, deptKey, steamKey)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return true end
        local d = normalize(AM.Data or AM.Load())
        local sid, sid64 = ply:SteamID(), ply:SteamID64()
        if d[steamKey][sid64] or d[steamKey][sid] then return true end

        local fac, role, dept = factionInfo(ply)
        if not fac then return false end
        if d[manageKey][fac] then return true end
        if nested(d[roleKey], fac, role) then return true end
        if nested(d[deptKey], fac, dept) then return true end
        return false
    end

    function AM.CanManage(ply)
        return checkAccess(ply, "ManageFactions", "ManageRoles", "ManageDepartments", "ManageSteam")
    end

    function AM.CanWarrant(ply)
        return checkAccess(ply, "WarrantFactions", "WarrantRoles", "WarrantDepartments", "WarrantSteam")
    end

    function AM.CanForceDoor(ply)
        return checkAccess(ply, "ForceFactions", "ForceRoles", "ForceDepartments", "ForceSteam")
    end

    function AM.IsFriendly(ply, networkID)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return true end
        if AM.CanForceDoor(ply) or AM.CanWarrant(ply) or AM.CanManage(ply) then return true end

        local d = normalize(AM.Data or AM.Load())
        local fac = factionInfo(ply)
        if fac and d.AlarmFriendlyFactions[fac] then return true end

        if fac and istable(d.AlarmFriendlyCategories) then
            local cats = (GRM.Doors and GRM.Doors.Data and GRM.Doors.Data.categories) or {}
            for catId, on in pairs(d.AlarmFriendlyCategories) do
                if on then
                    local cat = cats[catId]
                    if istable(cat) and istable(cat.factions) then
                        if cat.factions[fac] == true then return true end
                        for _, n in pairs(cat.factions) do if n == fac then return true end end
                    end
                end
            end
        end

        if GRM.Alarm and GRM.Alarm.AccessManager and GRM.Alarm.AccessManager.CanControl then
            if GRM.Alarm.AccessManager.CanControl(ply) then return true end
        end
        return false
    end

    concommand.Add("grm_door_access", function(ply)
        if IsValid(ply) and ply:IsSuperAdmin() then sendData(ply) end
    end)

    hook.Add("PlayerSay", "GRM_DoorAccess_Chat", function(ply, text)
        local msg = string.lower(string.Trim(text or ""))
        if msg == "/door_access" or msg == "!door_access" then
            if ply:IsSuperAdmin() then sendData(ply) end
            return ""
        end
    end)

    print("[GRM Doors] Менеджер доступа к дверям v2.2.0 загружен (сервер)")
end

-- ============================================================
-- КЛИЕНТСКАЯ ЧАСТЬ
-- ============================================================
if CLIENT then
    surface.CreateFont("GRMDoorAcc_Title",  { font = "Roboto", size = 18, weight = 800, extended = true })
    surface.CreateFont("GRMDoorAcc_Normal", { font = "Roboto", size = 13, weight = 500, extended = true })

    local CUI = {
        bg     = Color(20, 24, 32, 250),
        panel  = Color(32, 38, 50, 245),
        accent = Color(70, 150, 240),
        green  = Color(60, 190, 110),
        red    = Color(220, 75, 70),
        yellow = Color(230, 180, 60),
        text   = Color(240, 245, 250),
        dim    = Color(160, 170, 185),
    }

    local function sortKeys(t)
        local k = {}
        for key in pairs(t or {}) do k[#k + 1] = key end
        table.sort(k, function(a, b) return tostring(a) < tostring(b) end)
        return k
    end

    -- v2.2.0: поиск скролла вкладки (вкладка может БЫТЬ скроллом или содержать его)
    local function pageScroll(pnl)
        if not IsValid(pnl) then return nil end
        if pnl.ClassName == "DScrollPanel" then return pnl end
        for _, ch in ipairs(pnl:GetChildren()) do
            if IsValid(ch) and ch.ClassName == "DScrollPanel" then return ch end
        end
        return nil
    end

    local function mkBtn(p, text, col, w, h)
        local b = vgui.Create("DButton", p)
        if w then b:SetWide(w) end
        if h then b:SetTall(h) end
        b:SetText(text) b:SetTextColor(color_white) b:SetFont("GRMDoorAcc_Normal")
        b.Paint = function(self, pw, ph)
            local c = col or CUI.accent
            if not self:IsEnabled() then c = Color(60, 65, 75)
            elseif self:IsHovered() then c = Color(math.min(255, c.r + 25), math.min(255, c.g + 25), math.min(255, c.b + 25)) end
            draw.RoundedBox(6, 0, 0, pw, ph, c)
        end
        return b
    end

    local function openAccessMenu(factionsMap, data, cats)
        data = normalize(data)
        cats = cats or {}
        table.sort(cats, function(a, b) return tostring(a and a.id) < tostring(b and b.id) end)

        -- v2.2.0: запоминаем активную вкладку и прокрутку ДО пересборки
        local wantTab = AM._wantTab
        AM._wantTab = nil
        local prevTab, prevScroll
        if IsValid(AM._tabs) then
            local at = AM._tabs:GetActiveTab()
            if IsValid(at) then
                prevTab = at:GetText()
                for _, it in ipairs(AM._tabs.Items or {}) do
                    if it.Tab == at then
                        local sp = pageScroll(it.Panel)
                        if sp then prevScroll = sp:GetVBar():GetScroll() end
                        break
                    end
                end
            end
        end

        if IsValid(AM._f) then AM._f:Remove() end
        local frame = vgui.Create("DFrame")
        AM._f = frame
        frame:SetTitle("")
        frame:SetSize(960, 680)
        frame:Center()
        frame:MakePopup()
        frame:ShowCloseButton(false)
        frame.Paint = function(_, pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, CUI.bg)
            draw.RoundedBoxEx(8, 0, 0, pw, 38, Color(28, 34, 46), true, true, false, false)
            draw.SimpleText("Настройка доступа: Двери, Ордера на обыск (/warrant) и Сигнализация", "GRMDoorAcc_Title", 14, 19, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local closeBtn = vgui.Create("DButton", frame)
        closeBtn:SetText("X") closeBtn:SetFont("GRMDoorAcc_Title") closeBtn:SetTextColor(color_white)
        closeBtn:SetPos(916, 6) closeBtn:SetSize(32, 26)
        closeBtn.DoClick = function() frame:Close() end
        closeBtn.Paint = function(self, pw, ph)
            draw.RoundedBox(4, 0, 0, pw, ph, self:IsHovered() and CUI.red or Color(45, 52, 68))
        end

        local tabs = vgui.Create("DPropertySheet", frame)
        tabs:Dock(FILL)
        tabs:DockMargin(8, 44, 8, 52)
        AM._tabs = tabs

        local function addFactionTab(title, field, icon)
            local sc = vgui.Create("DScrollPanel")
            sc:DockMargin(4, 4, 4, 4)
            for _, fn in ipairs(sortKeys(factionsMap)) do
                local r = vgui.Create("DPanel", sc)
                r:Dock(TOP) r:SetTall(32) r:DockMargin(0, 0, 0, 4)
                r.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, CUI.panel) end

                local chk = vgui.Create("DCheckBoxLabel", r)
                chk:Dock(FILL) chk:DockMargin(10, 0, 0, 0)
                chk:SetText("Разрешить всей фракции: " .. fn) chk:SetTextColor(CUI.text)
                chk:SetValue(data[field][fn] and 1 or 0)
                chk.OnChange = function(_, val)
                    if val then data[field][fn] = true else data[field][fn] = nil end
                end
            end
            tabs:AddSheet(title, sc, icon or "icon16/group.png")
        end

        addFactionTab("Ордера: Фракции", "WarrantFactions", "icon16/exclamation.png")
        addFactionTab("Вскрытие: Фракции", "ForceFactions", "icon16/key.png")
        addFactionTab("Управление: Фракции", "ManageFactions", "icon16/shield.png")
        addFactionTab("Сигнализация «Свои»: Фракции", "AlarmFriendlyFactions", "icon16/bell.png")

        -- v2.2.0 ВКЛАДКА «КАТЕГОРИИ ФРАКЦИЙ»: создание категорий, объединение
        -- фракций, переименование/удаление. Категории используются как
        -- владельцы дверей и в ACL дверей (меню двери, вкладка «Фракции и Роли»).
        do
            local catPage = vgui.Create("DPanel")
            catPage:SetPaintBackground(false)

            local cr = vgui.Create("DPanel", catPage)
            cr:Dock(TOP) cr:SetTall(64) cr:DockMargin(8, 8, 8, 6)
            cr.Paint = function(_, pw, ph)
                draw.RoundedBox(6, 0, 0, pw, ph, CUI.panel)
                draw.SimpleText("Создать категорию (ID — латиница/цифры/_/-, напр. polizei_swat)", "GRMDoorAcc_Normal", 10, 14, CUI.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            local idEntry = vgui.Create("DTextEntry", cr)
            idEntry:SetPos(10, 30) idEntry:SetSize(200, 26) idEntry:SetPlaceholderText("ID категории")
            local nameEntry = vgui.Create("DTextEntry", cr)
            nameEntry:SetPos(218, 30) nameEntry:SetSize(320, 26) nameEntry:SetPlaceholderText("Название категории")
            local bCreate = mkBtn(cr, "Создать", CUI.green, 120, 26)
            bCreate:SetPos(546, 30)
            bCreate.DoClick = function()
                net.Start(NET_CAT)
                net.WriteTable({ op = "create", id = idEntry:GetValue(), name = nameEntry:GetValue() })
                net.SendToServer()
            end

            local catScroll = vgui.Create("DScrollPanel", catPage)
            catScroll:Dock(FILL) catScroll:DockMargin(8, 4, 8, 8)

            local facNames = sortKeys(factionsMap)

            local function buildCatBlock(c)
                local cid = tostring(c.id or "")
                if cid == "" then return end
                local cname = tostring(c.name or cid)

                local facs, seenF = {}, {}
                if istable(c.factions) then
                    for k, v in pairs(c.factions) do
                        local fn
                        if v == true and isstring(k) then fn = k
                        elseif isnumber(k) and isstring(v) then fn = v end
                        if fn and not seenF[fn] then seenF[fn] = true facs[#facs + 1] = fn end
                    end
                end
                table.sort(facs)

                local n = #facs
                local block = vgui.Create("DPanel", catScroll)
                block:Dock(TOP) block:SetTall(34 + n * 26 + 36 + 36) block:DockMargin(0, 0, 0, 6)
                block.Paint = function(_, pw, ph)
                    draw.RoundedBox(6, 0, 0, pw, ph, CUI.panel)
                    draw.SimpleText(cname .. "   [" .. cid .. "]", "GRMDoorAcc_Normal", 10, 15, CUI.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                end

                for i, fn in ipairs(facs) do
                    local rf = vgui.Create("DPanel", block)
                    rf:SetPos(10, 30 + (i - 1) * 26) rf:SetSize(430, 22)
                    rf.Paint = function(_, pw, ph)
                        draw.RoundedBox(4, 0, 0, pw, ph, Color(26, 32, 42))
                        draw.SimpleText("• " .. fn, "GRMDoorAcc_Normal", 8, ph / 2, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                    local bRem = mkBtn(rf, "убрать", CUI.red, 100, 20)
                    bRem:SetPos(322, 1)
                    bRem.DoClick = function()
                        net.Start(NET_CAT)
                        net.WriteTable({ op = "setfaction", id = cid, faction = fn, on = false })
                        net.SendToServer()
                    end
                end

                local yA = 34 + n * 26
                local addCombo = vgui.Create("DComboBox", block)
                addCombo:SetPos(10, yA) addCombo:SetSize(300, 26)
                addCombo:SetValue("Добавить фракцию...")
                for _, fn in ipairs(facNames) do addCombo:AddChoice(fn) end
                local bAdd = mkBtn(block, "Добавить", CUI.green, 120, 26)
                bAdd:SetPos(318, yA)
                bAdd.DoClick = function()
                    local _, fn = addCombo:GetSelected()
                    if fn then
                        net.Start(NET_CAT)
                        net.WriteTable({ op = "setfaction", id = cid, faction = fn, on = true })
                        net.SendToServer()
                    end
                end

                local yB = yA + 36
                local renEntry = vgui.Create("DTextEntry", block)
                renEntry:SetPos(10, yB) renEntry:SetSize(300, 26) renEntry:SetValue(cname)
                local bRen = mkBtn(block, "Переименовать", CUI.accent, 120, 26)
                bRen:SetPos(318, yB)
                bRen.DoClick = function()
                    net.Start(NET_CAT)
                    net.WriteTable({ op = "rename", id = cid, name = renEntry:GetValue() })
                    net.SendToServer()
                end
                local bDel = mkBtn(block, "Удалить категорию", CUI.red, 160, 26)
                bDel:SetPos(448, yB)
                bDel.DoClick = function()
                    Derma_Query("Удалить категорию «" .. cname .. "»?\nСсылки дверей на неё будут очищены.", "Удаление категории",
                        "Удалить", function()
                            net.Start(NET_CAT)
                            net.WriteTable({ op = "delete", id = cid })
                            net.SendToServer()
                        end,
                        "Отмена", function() end)
                end
            end

            for _, c in ipairs(cats) do buildCatBlock(c) end
            if #cats == 0 then
                local empty = vgui.Create("DLabel", catScroll)
                empty:Dock(TOP) empty:SetTall(30) empty:DockMargin(4, 4, 4, 4)
                empty:SetText("Пока нет ни одной категории — создайте первую выше.")
                empty:SetTextColor(CUI.dim) empty:SetFont("GRMDoorAcc_Normal")
            end

            tabs:AddSheet("Категории фракций", catPage, "icon16/folder_user.png")
        end

        local function addNestedTab(title, field, sourceKey, icon)
            local panel = vgui.Create("DPanel")
            panel:SetPaintBackground(false)

            local combo = vgui.Create("DComboBox", panel)
            combo:Dock(TOP) combo:SetTall(30) combo:DockMargin(8, 8, 8, 4)
            combo:SetValue("Выберите фракцию...")

            local sc = vgui.Create("DScrollPanel", panel)
            sc:Dock(FILL) sc:DockMargin(8, 4, 8, 8)

            local function rebuild(fname)
                sc:Clear()
                local f = factionsMap[fname]
                if not f or not istable(f[sourceKey]) then return end

                for _, key in ipairs(f[sourceKey]) do
                    local r = vgui.Create("DPanel", sc)
                    r:Dock(TOP) r:SetTall(32) r:DockMargin(0, 0, 0, 4)
                    r.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, CUI.panel) end

                    data[field][fname] = istable(data[field][fname]) and data[field][fname] or {}
                    local chk = vgui.Create("DCheckBoxLabel", r)
                    chk:Dock(FILL) chk:DockMargin(10, 0, 0, 0)
                    chk:SetText(tostring(key)) chk:SetTextColor(CUI.text)
                    chk:SetValue(data[field][fname][key] and 1 or 0)
                    chk.OnChange = function(_, val)
                        data[field][fname] = data[field][fname] or {}
                        if val then data[field][fname][key] = true else data[field][fname][key] = nil end
                    end
                end
            end

            for _, fn in ipairs(sortKeys(factionsMap)) do combo:AddChoice(fn) end
            combo.OnSelect = function(_, _, val) rebuild(val) end

            tabs:AddSheet(title, panel, icon or "icon16/user.png")
        end

        addNestedTab("Ордера: Ранги", "WarrantRoles", "Roles", "icon16/user_suit.png")
        addNestedTab("Ордера: Подразделения", "WarrantDepartments", "Departments", "icon16/building.png")
        addNestedTab("Вскрытие: Ранги", "ForceRoles", "Roles", "icon16/key_add.png")
        addNestedTab("Вскрытие: Подразделения", "ForceDepartments", "Departments", "icon16/building_add.png")

        -- v2.2.0: восстанавливаем вкладку (и прокрутку) после пересборки;
        -- явный wantTab (вход по кнопке из /factions) в приоритете
        local restoreName = wantTab or prevTab
        if restoreName then
            for _, it in ipairs(tabs.Items or {}) do
                if IsValid(it.Tab) and it.Tab:GetText() == restoreName then
                    tabs:SetActiveTab(it.Tab)
                    if prevScroll and not wantTab then
                        local rPnl = it.Panel
                        timer.Simple(0, function()
                            local sp = pageScroll(rPnl)
                            if sp then sp:GetVBar():SetScroll(prevScroll) end
                        end)
                    end
                    break
                end
            end
        end

        local bot = vgui.Create("DPanel", frame)
        bot:Dock(BOTTOM) bot:SetTall(44) bot:SetPaintBackground(false)

        local bSave = mkBtn(bot, "Сохранить настройки доступа", CUI.green, 240, 32)
        bSave:Dock(RIGHT) bSave:DockMargin(0, 6, 12, 6)
        bSave.DoClick = function()
            net.Start(NET_SAVE) net.WriteTable(data) net.SendToServer()
        end
    end

    net.Receive(NET_DATA, function()
        openAccessMenu(net.ReadTable() or {}, net.ReadTable() or {}, net.ReadTable() or {})
    end)

    net.Receive(NET_RESULT, function()
        local ok = net.ReadBool()
        local msg = net.ReadString()
        if notification then
            notification.AddLegacy(msg, ok and NOTIFY_GENERIC or NOTIFY_ERROR, 4)
        else
            chat.AddText(ok and Color(100, 220, 100) or Color(255, 100, 100), "[Доступ Дверей] ", color_white, msg)
        end
    end)

    function AM.OpenMenu(tabName)
        if isstring(tabName) and tabName ~= "" then AM._wantTab = tabName end
        net.Start(NET_REQ) net.SendToServer()
    end

    concommand.Add("grm_door_access", AM.OpenMenu)

    hook.Add("OnPlayerChat", "GRM_DoorAccess_ChatCl", function(ply, text)
        if ply ~= LocalPlayer() then return end
        local msg = string.lower(string.Trim(text or ""))
        if msg == "/door_access" or msg == "!door_access" then
            AM.OpenMenu()
            return true
        end
    end)

    -- Вставка вкладки в меню /factions
    local function installFactionsTab()
        if not OpenAdminMenu or AM._wrappedOpenAdminMenu then return end
        AM._oldOpenAdminMenu = OpenAdminMenu
        AM._wrappedOpenAdminMenu = true
        OpenAdminMenu = function(...)
            if AM._oldOpenAdminMenu then AM._oldOpenAdminMenu(...) end
            timer.Simple(0.3, function()
                if not ui or not IsValid(ui.currentFrame) then return end
                local sheet
                for _, child in ipairs(ui.currentFrame:GetChildren()) do
                    if child.ClassName == "DPropertySheet" then sheet = child break end
                end
                if not IsValid(sheet) then return end
                for _, item in ipairs(sheet.Items or {}) do
                    if item.Tab and (item.Tab:GetText() == "Двери и Ордера" or item.Tab:GetText() == "Двери") then return end
                end
                local panel = vgui.Create("DPanel")
                panel:SetPaintBackground(false)

                local label = vgui.Create("DLabel", panel)
                label:Dock(TOP)
                label:SetTall(70)
                label:DockMargin(12, 12, 12, 4)
                label:SetWrap(true)
                label:SetText("Централизованное управление правами на двери, выписку ордеров на обыск (/warrant) и вскрытие замков по Фракциям, Рангам и Подразделениям.")
                label:SetTextColor(Color(220, 220, 230))

                local button = mkBtn(panel, "Настроить доступ к Дверям и Ордерам", CUI.accent)
                button:Dock(TOP)
                button:SetTall(38)
                button:DockMargin(12, 8, 12, 0)
                button.DoClick = function() AM.OpenMenu() end

                local btnCats = mkBtn(panel, "Управление категориями фракций (владельцы дверей)", CUI.green)
                btnCats:Dock(TOP)
                btnCats:SetTall(38)
                btnCats:DockMargin(12, 8, 12, 0)
                btnCats.DoClick = function() AM.OpenMenu("Категории фракций") end

                sheet:AddSheet("Двери и Ордера", panel, "icon16/door.png")
            end)
        end
    end

    timer.Create("GRM_DoorAccess_WaitFactions", 0.5, 24, installFactionsTab)
    timer.Simple(1, installFactionsTab)

    print("[GRM Doors] Менеджер доступа к дверям v2.2.0 загружен (клиент)")
end
