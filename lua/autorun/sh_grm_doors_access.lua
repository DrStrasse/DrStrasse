--[[--------------------------------------------------------------------
    GRM Doors Access (Код 64)
    /door_access + вкладка «Двери» в /factions
    Права: Manage (категории/ACL), Warrant (ордера), ForceDoor (вскрытие)
    data/grm_doors/access.json
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Doors = GRM.Doors or {}
GRM.Doors.AccessManager = GRM.Doors.AccessManager or {}
local AM = GRM.Doors.AccessManager

local NET_REQ, NET_DATA, NET_SAVE, NET_RESULT =
    "GRM_DoorAccess_Request", "GRM_DoorAccess_Data", "GRM_DoorAccess_Save", "GRM_DoorAccess_Result"

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

local function facInfo(ply)
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

if SERVER then
    util.AddNetworkString(NET_REQ)
    util.AddNetworkString(NET_DATA)
    util.AddNetworkString(NET_SAVE)
    util.AddNetworkString(NET_RESULT)

    function AM.Load()
        if not file.IsDir("grm_doors", "DATA") then file.CreateDir("grm_doors") end
        if not file.Exists(ACCESS_FILE, "DATA") then AM.Data = normalize({}) return AM.Data end
        AM.Data = normalize(jsonT(file.Read(ACCESS_FILE, "DATA") or "") or {})
        return AM.Data
    end

    function AM.Save(data)
        AM.Data = normalize(data or AM.Data)
        local ok, txt = pcall(util.TableToJSON, AM.Data, true)
        if ok and txt then file.Write(ACCESS_FILE, txt) return true end
        return false
    end

    AM.Load()

    local function buildFac()
        local o = {}
        for n, f in pairs(Factions or {}) do
            if istable(f) then o[n] = { Roles = f.Roles or {}, Departments = f.Departments or {} } end
        end
        return o
    end

    local function sendData(ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        net.Start(NET_DATA)
            net.WriteTable(buildFac())
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
        net.Start(NET_RESULT) net.WriteBool(true) net.WriteString("Доступ дверей/ордеров сохранён.") net.Send(ply)
        sendData(ply)
    end)

    local function has(ply, manageKey, roleKey, deptKey, steamKey)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return true end
        local d = normalize(AM.Data or AM.Load())
        local sid, sid64 = ply:SteamID(), ply:SteamID64()
        if d[steamKey][sid64] or d[steamKey][sid] then return true end
        local fac, role, dept = facInfo(ply)
        if not fac then return false end
        if d[manageKey][fac] then return true end
        if nested(d[roleKey], fac, role) then return true end
        if nested(d[deptKey], fac, dept) then return true end
        return false
    end

    function AM.CanManage(ply)
        return has(ply, "ManageFactions", "ManageRoles", "ManageDepartments", "ManageSteam")
    end
    function AM.CanWarrant(ply)
        return has(ply, "WarrantFactions", "WarrantRoles", "WarrantDepartments", "WarrantSteam")
    end
    function AM.CanForceDoor(ply)
        return has(ply, "ForceFactions", "ForceRoles", "ForceDepartments", "ForceSteam")
    end

    -- Friendly for alarm: control factions + explicit friendly lists + categories
    function AM.IsFriendly(ply, networkID)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return true end
        if AM.CanForceDoor(ply) or AM.CanWarrant(ply) or AM.CanManage(ply) then return true end
        local d = normalize(AM.Data or AM.Load())
        local fac = facInfo(ply)
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
        -- alarm control access also friendly
        if GRM.Alarm and GRM.Alarm.AccessManager and GRM.Alarm.AccessManager.CanControl then
            if GRM.Alarm.AccessManager.CanControl(ply) then return true end
        end
        return false
    end

    function AM.Install()
        if GRM.Doors then
            -- keep module functions; they call AccessManager
        end
    end
    AM.Install()

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
    print("[GRM Doors] Access Manager loaded")
end

if CLIENT then
    surface.CreateFont("GRMDoorAcc_Title", { font = "Roboto", size = 18, weight = 700, extended = true })
    surface.CreateFont("GRMDoorAcc_Normal", { font = "Roboto", size = 13, weight = 500, extended = true })

    local THEME = {
        bg = Color(22, 24, 30, 250), panel = Color(32, 36, 46, 245),
        text = Color(230, 235, 240), dim = Color(150, 160, 175),
        green = Color(70, 180, 110), accent = Color(70, 140, 220), yellow = Color(220, 180, 70),
    }

    local function sk(t)
        local k = {}
        for key in pairs(t or {}) do k[#k + 1] = key end
        table.sort(k, function(a, b) return tostring(a) < tostring(b) end)
        return k
    end

    local function mkBtn(p, text, col)
        local b = vgui.Create("DButton", p)
        b:SetText(text) b:SetTextColor(color_white) b:SetFont("GRMDoorAcc_Normal")
        b.Paint = function(self, w, h)
            local c = col or THEME.accent
            if self:IsHovered() then c = Color(math.min(255, c.r + 20), math.min(255, c.g + 20), math.min(255, c.b + 20)) end
            draw.RoundedBox(6, 0, 0, w, h, c)
        end
        return b
    end

    local function openMenu(factions, data, cats)
        data = normalize(data)
        cats = cats or {}
        if IsValid(AM._f) then AM._f:Remove() end
        local frame = vgui.Create("DFrame")
        AM._f = frame
        frame:SetTitle("")
        frame:SetSize(920, 680)
        frame:Center()
        frame:MakePopup()
        frame.Paint = function(_, w, h)
            draw.RoundedBox(8, 0, 0, w, h, THEME.bg)
            draw.SimpleText("Доступ: двери / ордера / «свои» для сигнализации", "GRMDoorAcc_Title", 12, 18, THEME.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local tabs = vgui.Create("DPropertySheet", frame)
        tabs:Dock(FILL)
        tabs:DockMargin(8, 40, 8, 52)

        local function facSheet(title, field)
            local p = vgui.Create("DScrollPanel")
            for _, n in ipairs(sk(factions)) do
                local row = vgui.Create("DPanel", p)
                row:Dock(TOP) row:SetTall(30) row:DockMargin(6, 2, 6, 2)
                row.Paint = function(_, w, h) draw.RoundedBox(5, 0, 0, w, h, THEME.panel) end
                local chk = vgui.Create("DCheckBoxLabel", row)
                chk:Dock(FILL) chk:DockMargin(8, 0, 0, 0)
                chk:SetText(n) chk:SetTextColor(THEME.text)
                chk:SetValue(data[field][n] and 1 or 0)
                chk.OnChange = function(_, v) if v then data[field][n] = true else data[field][n] = nil end end
            end
            tabs:AddSheet(title, p, "icon16/group.png")
        end

        facSheet("Управление дверями: фракции", "ManageFactions")
        facSheet("Ордера: фракции", "WarrantFactions")
        facSheet("Вскрытие: фракции", "ForceFactions")
        facSheet("Сигналка «свои»: фракции", "AlarmFriendlyFactions")

        -- friendly categories
        do
            local p = vgui.Create("DScrollPanel")
            local lab = vgui.Create("DLabel", p)
            lab:Dock(TOP) lab:SetTall(40) lab:DockMargin(8, 6, 8, 4)
            lab:SetWrap(true) lab:SetTextColor(THEME.dim) lab:SetFont("GRMDoorAcc_Normal")
            lab:SetText("Категории, чьи фракции НЕ триггерят охрану (режим 2) — игнор «своих».")
            for _, c in ipairs(cats) do
                local id = c.id or c.name
                local row = vgui.Create("DPanel", p)
                row:Dock(TOP) row:SetTall(30) row:DockMargin(6, 2, 6, 2)
                row.Paint = function(_, w, h) draw.RoundedBox(5, 0, 0, w, h, THEME.panel) end
                local chk = vgui.Create("DCheckBoxLabel", row)
                chk:Dock(FILL) chk:DockMargin(8, 0, 0, 0)
                chk:SetText(tostring(c.name or id))
                chk:SetTextColor(THEME.text)
                chk:SetValue(data.AlarmFriendlyCategories[id] and 1 or 0)
                chk.OnChange = function(_, v)
                    if v then data.AlarmFriendlyCategories[id] = true else data.AlarmFriendlyCategories[id] = nil end
                end
            end
            tabs:AddSheet("Сигналка «свои»: категории", p, "icon16/bell.png")
        end

        local function nest(title, field, src)
            local p = vgui.Create("DPanel")
            p:SetPaintBackground(false)
            local combo = vgui.Create("DComboBox", p)
            combo:Dock(TOP) combo:SetTall(28) combo:DockMargin(8, 8, 8, 4)
            combo:SetValue("Фракция…")
            local sc = vgui.Create("DScrollPanel", p)
            sc:Dock(FILL) sc:DockMargin(8, 4, 8, 8)
            local function rebuild(fname)
                sc:Clear()
                local f = factions[fname]
                if not f then return end
                for _, key in ipairs(f[src] or {}) do
                    local row = vgui.Create("DPanel", sc)
                    row:Dock(TOP) row:SetTall(28) row:DockMargin(0, 0, 0, 2)
                    row.Paint = function(_, w, h) draw.RoundedBox(5, 0, 0, w, h, THEME.panel) end
                    data[field][fname] = istable(data[field][fname]) and data[field][fname] or {}
                    local chk = vgui.Create("DCheckBoxLabel", row)
                    chk:Dock(FILL) chk:DockMargin(8, 0, 0, 0)
                    chk:SetText(tostring(key)) chk:SetTextColor(THEME.text)
                    chk:SetValue(data[field][fname][key] and 1 or 0)
                    chk.OnChange = function(_, v)
                        data[field][fname] = data[field][fname] or {}
                        if v then data[field][fname][key] = true else data[field][fname][key] = nil end
                    end
                end
            end
            for _, n in ipairs(sk(factions)) do combo:AddChoice(n) end
            combo.OnSelect = function(_, _, v) rebuild(v) end
            tabs:AddSheet(title, p, "icon16/user.png")
        end
        nest("Ордера: ранги", "WarrantRoles", "Roles")
        nest("Вскрытие: ранги", "ForceRoles", "Roles")

        local function steam(title, field)
            local p = vgui.Create("DPanel")
            p:SetPaintBackground(false)
            local row = vgui.Create("DPanel", p)
            row:Dock(TOP) row:SetTall(32) row:DockMargin(8, 8, 8, 4) row:SetPaintBackground(false)
            local e = vgui.Create("DTextEntry", row)
            e:Dock(LEFT) e:SetWide(280)
            local list = vgui.Create("DListView", p)
            list:Dock(FILL) list:DockMargin(8, 4, 8, 8) list:AddColumn("Steam")
            local function rb()
                list:Clear()
                for _, s in ipairs(sk(data[field])) do list:AddLine(s) end
            end
            rb()
            local add = mkBtn(row, "+", THEME.green)
            add:Dock(LEFT) add:SetWide(40) add:DockMargin(4, 0, 0, 0)
            add.DoClick = function()
                local s = string.Trim(e:GetValue() or "")
                if s ~= "" then data[field][s] = true e:SetText("") rb() end
            end
            tabs:AddSheet(title, p, "icon16/key.png")
        end
        steam("Ордера: Steam", "WarrantSteam")
        steam("Вскрытие: Steam", "ForceSteam")

        local bot = vgui.Create("DPanel", frame)
        bot:Dock(BOTTOM) bot:SetTall(44) bot:SetPaintBackground(false)
        local save = mkBtn(bot, "Сохранить", THEME.green)
        save:Dock(RIGHT) save:SetWide(160) save:DockMargin(6, 6, 10, 6)
        save.DoClick = function()
            net.Start(NET_SAVE) net.WriteTable(data) net.SendToServer()
        end
    end

    net.Receive(NET_DATA, function()
        openMenu(net.ReadTable() or {}, net.ReadTable() or {}, net.ReadTable() or {})
    end)
    net.Receive(NET_RESULT, function()
        local ok = net.ReadBool()
        notification.AddLegacy(net.ReadString(), ok and NOTIFY_GENERIC or NOTIFY_ERROR, 4)
    end)

    function AM.OpenMenu()
        net.Start(NET_REQ) net.SendToServer()
    end
    concommand.Add("grm_door_access", AM.OpenMenu)
    hook.Add("OnPlayerChat", "GRM_DoorAccess_Cl", function(ply, text)
        if ply ~= LocalPlayer() then return end
        local m = string.lower(string.Trim(text or ""))
        if m == "/door_access" or m == "!door_access" then AM.OpenMenu() return true end
    end)

    local function install()
        if not OpenAdminMenu or AM._w then return end
        AM._old = OpenAdminMenu
        AM._w = true
        OpenAdminMenu = function(...)
            if AM._old then AM._old(...) end
            timer.Simple(0.4, function()
                if not ui or not IsValid(ui.currentFrame) then return end
                local sheet
                for _, ch in ipairs(ui.currentFrame:GetChildren()) do
                    if ch.ClassName == "DPropertySheet" then sheet = ch break end
                end
                if not IsValid(sheet) then return end
                for _, it in ipairs(sheet.Items or {}) do
                    if it.Tab and it.Tab:GetText() == "Двери" then return end
                end
                local panel = vgui.Create("DPanel")
                panel:SetPaintBackground(false)
                local lab = vgui.Create("DLabel", panel)
                lab:Dock(TOP) lab:SetTall(70) lab:DockMargin(12, 12, 12, 4) lab:SetWrap(true)
                lab:SetText("Двери: категории фракций, права на ордера/вскрытие, «свои» для сигнализации. Также /door на дверь, /warrant.")
                lab:SetTextColor(Color(220, 220, 230))
                local b = mkBtn(panel, "Открыть доступ дверей / ордеров", THEME.accent)
                b:Dock(TOP) b:SetTall(36) b:DockMargin(12, 8, 12, 0)
                b.DoClick = AM.OpenMenu
                sheet:AddSheet("Двери", panel, "icon16/door.png")
            end)
        end
    end
    timer.Create("GRM_DoorAccess_WaitFac", 0.5, 24, install)
    timer.Simple(1, install)
    print("[GRM Doors] Access client loaded")
end
