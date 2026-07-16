--[[--------------------------------------------------------------------
    GRM Doors Access Manager v2.0.0 (Код 64 — ПЕРЕПИСАНО С НУЛЯ)
    Центральный менеджер прав доступа к дверям, ордерам на обыск и вскрытию.
      - Управление фракционными категориями;
      - Права на выдачу ордеров /warrant (по фракциям, рангам, SteamID);
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

    print("[GRM Doors] Mенеджер доступа к дверям v2.0.0 загружен (сервер)")
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

        if IsValid(AM._f) then AM._f:Remove() end
        local frame = vgui.Create("DFrame")
        AM._f = frame
        frame:SetTitle("")
        frame:SetSize(940, 680)
        frame:Center()
        frame:MakePopup()
        frame:ShowCloseButton(false)
        frame.Paint = function(_, pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, CUI.bg)
            draw.RoundedBoxEx(8, 0, 0, pw, 38, Color(28, 34, 46), true, true, false, false)
            draw.SimpleText("Менеджер прав: Двери, Ордера и Сигнализация", "GRMDoorAcc_Title", 14, 19, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local closeBtn = vgui.Create("DButton", frame)
        closeBtn:SetText("X") closeBtn:SetFont("GRMDoorAcc_Title") closeBtn:SetTextColor(color_white)
        closeBtn:SetPos(896, 6) closeBtn:SetSize(32, 26)
        closeBtn.DoClick = function() frame:Close() end
        closeBtn.Paint = function(self, pw, ph)
            draw.RoundedBox(4, 0, 0, pw, ph, self:IsHovered() and CUI.red or Color(45, 52, 68))
        end

        local tabs = vgui.Create("DPropertySheet", frame)
        tabs:Dock(FILL)
        tabs:DockMargin(8, 44, 8, 52)

        local function addFactionTab(title, field)
            local sc = vgui.Create("DScrollPanel")
            sc:DockMargin(4, 4, 4, 4)
            for _, fn in ipairs(sortKeys(factionsMap)) do
                local r = vgui.Create("DPanel", sc)
                r:Dock(TOP) r:SetTall(32) r:DockMargin(0, 0, 0, 4)
                r.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, CUI.panel) end

                local chk = vgui.Create("DCheckBoxLabel", r)
                chk:Dock(FILL) chk:DockMargin(10, 0, 0, 0)
                chk:SetText("Разрешить фракции: " .. fn) chk:SetTextColor(CUI.text)
                chk:SetValue(data[field][fn] and 1 or 0)
                chk.OnChange = function(_, val)
                    if val then data[field][fn] = true else data[field][fn] = nil end
                end
            end
            tabs:AddSheet(title, sc, "icon16/group.png")
        end

        addFactionTab("Управление: Фракции", "ManageFactions")
        addFactionTab("Ордера: Фракции", "WarrantFactions")
        addFactionTab("Вскрытие: Фракции", "ForceFactions")
        addFactionTab("Сигнализация «Свои»: Фракции", "AlarmFriendlyFactions")

        -- Категории "Свои"
        do
            local sc = vgui.Create("DScrollPanel")
            sc:DockMargin(4, 4, 4, 4)

            local lbl = vgui.Create("DLabel", sc)
            lbl:Dock(TOP) lbl:SetTall(36) lbl:DockMargin(6, 4, 6, 6)
            lbl:SetWrap(true) lbl:SetTextColor(CUI.dim) lbl:SetFont("GRMDoorAcc_Normal")
            lbl:SetText("Фракции из этих категорий считаются «своими» для охранных систем и не вызывают тревогу:")

            for _, c in ipairs(cats) do
                local cid = c.id or c.name
                local r = vgui.Create("DPanel", sc)
                r:Dock(TOP) r:SetTall(32) r:DockMargin(0, 0, 0, 4)
                r.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, CUI.panel) end

                local chk = vgui.Create("DCheckBoxLabel", r)
                chk:Dock(FILL) chk:DockMargin(10, 0, 0, 0)
                chk:SetText("Категория: " .. tostring(c.name or cid))
                chk:SetTextColor(CUI.text)
                chk:SetValue(data.AlarmFriendlyCategories[cid] and 1 or 0)
                chk.OnChange = function(_, val)
                    if val then data.AlarmFriendlyCategories[cid] = true else data.AlarmFriendlyCategories[cid] = nil end
                end
            end
            tabs:AddSheet("Сигнализация «Свои»: Категории", sc, "icon16/bell.png")
        end

        local bot = vgui.Create("DPanel", frame)
        bot:Dock(BOTTOM) bot:SetTall(44) bot:SetPaintBackground(false)

        local bSave = mkBtn(bot, "Сохранить изменения", CUI.green, 200, 32)
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

    function AM.OpenMenu()
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

    print("[GRM Doors] Менеджер доступа к дверям v2.0.0 загружен (клиент)")
end
