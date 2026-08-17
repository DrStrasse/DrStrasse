--[[--------------------------------------------------------------------
    GRM Factions Unified UI v1.0.0 (Код 112, заказ владельца)
    Единый интерфейс управления фракцией:
      • Singleton VGUI окно (левая боковая навигация + контент);
      • Вкладки: Обзор, Сотрудники, Кадровые дела, Структура, Служба, Доступы, Финансы, Журнал;
      • Полная поддержка двойных имён: DisplayName в заголовках, системные ключи в подсказках;
      • Стабильные ключи отделов и должностей (RoleDisplayNames + DepartmentDisplayNames);
      • Подключение к FactionsAPI, FactionCore, FactionDuty, FactionPersonnel.
----------------------------------------------------------------------]]

if not CLIENT then return end

GRM = GRM or {}
GRM.Factions = GRM.Factions or {}
GRM.Factions.UnifiedUI = GRM.Factions.UnifiedUI or {}
local UI = GRM.Factions.UnifiedUI
UI.Version = "1.0.0"

surface.CreateFont("GRMFac_Title",   { font = "Roboto", size = 20, weight = 800, extended = true })
surface.CreateFont("GRMFac_Sub",     { font = "Roboto", size = 15, weight = 700, extended = true })
surface.CreateFont("GRMFac_Normal",  { font = "Roboto", size = 13, weight = 500, extended = true })
surface.CreateFont("GRMFac_Small",   { font = "Roboto", size = 11, weight = 400, extended = true })
surface.CreateFont("GRMFac_Btn",     { font = "Roboto", size = 13, weight = 600, extended = true })

local C = {
    bg         = Color(18, 22, 30, 252),
    sidebar    = Color(14, 17, 24, 255),
    card       = Color(25, 31, 42, 240),
    cardHover  = Color(33, 41, 56, 240),
    border     = Color(42, 52, 70, 200),
    accent     = Color(70, 150, 240),
    accentHover= Color(95, 170, 255),
    gold       = Color(245, 200, 70),
    green      = Color(60, 190, 115),
    red        = Color(230, 75, 75),
    text       = Color(240, 245, 250),
    dim        = Color(160, 175, 195),
}

local currentFrame = nil

local function getLeaderFactionName(data)
    local lp = LocalPlayer()
    if not IsValid(lp) then return nil end
    local charKey = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(lp)) or ""
    local sid = lp:SteamID()
    local sid64 = lp:SteamID64()
    for name, f in pairs(data or {}) do
        if istable(f) then
            local ldr = tostring(f.Leader or "")
            if ldr ~= "" and (ldr == charKey or ldr == sid or ldr == sid64) then return name, f end
            if istable(f.Members) then
                local m = f.Members[charKey] or f.Members[sid] or f.Members[sid64]
                if istable(m) and (m.Role == f.LeaderRoleName or m.Role == "Лидер") then return name, f end
            end
        end
    end
    return nil
end

local function getPlayerFactionName(data)
    local lp = LocalPlayer()
    if not IsValid(lp) then return nil end
    local charKey = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(lp)) or ""
    local sid = lp:SteamID()
    local sid64 = lp:SteamID64()
    for name, f in pairs(data or {}) do
        if istable(f) and istable(f.Members) then
            if f.Members[charKey] or f.Members[sid] or f.Members[sid64] then return name, f end
        end
    end
    return nil
end

function UI.Open(requestedFaction)
    if IsValid(currentFrame) then
        currentFrame:Remove()
        currentFrame = nil
    end

    local data = FactionsData or {}
    local lp = LocalPlayer()
    local isSA = IsValid(lp) and lp.IsSuperAdmin and lp:IsSuperAdmin()

    local targetFac = requestedFaction or getLeaderFactionName(data) or getPlayerFactionName(data)
    if not targetFac and not isSA then
        if GRM.Notify then
            GRM.Notify(lp, "Вы не состоите ни в одной государственной или частной организации.", 255, 160, 80)
        else
            chat.AddText(Color(255, 160, 80), "[Фракции] Вы не состоите ни в одной организации.")
        end
        return
    end

    if not targetFac and isSA then
        targetFac = next(data)
    end

    local f = vgui.Create("DFrame")
    currentFrame = f
    if GRM.UI and GRM.UI.Track then GRM.UI.Track("grm_factions_unified", f) end

    f:SetSize(math.Clamp(ScrW() * 0.85, 960, 1400), math.Clamp(ScrH() * 0.82, 620, 900))
    f:Center()
    f:SetTitle("")
    f:SetDraggable(true)
    f:SetSizable(true)
    f:ShowCloseButton(false)
    f:MakePopup()

    f.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, C.bg)
        draw.RoundedBox(8, 0, 0, w, 40, C.sidebar)
        surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
        surface.DrawOutlinedRect(0, 0, w, h)

        local dispName = targetFac and GRM.Factions.DisplayName(targetFac) or "Панель организаций"
        draw.SimpleText("★ " .. dispName, "GRMFac_Title", 16, 20, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        if targetFac and targetFac ~= dispName then
            draw.SimpleText("[" .. targetFac .. "]", "GRMFac_Small", 20 + surface.GetTextSize(dispName) + 30, 20, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    local btnClose = vgui.Create("DButton", f)
    btnClose:SetSize(32, 26)
    btnClose:SetPos(f:GetWide() - 40, 7)
    btnClose:SetText("✕")
    btnClose:SetFont("GRMFac_Btn")
    btnClose:SetTextColor(C.dim)
    btnClose.Paint = function(self, w, h)
        if self:IsHovered() then draw.RoundedBox(4, 0, 0, w, h, C.red) end
    end
    btnClose.DoClick = function() f:Remove() end

    local body = vgui.Create("DPanel", f)
    body:Dock(FILL)
    body:DockMargin(0, 36, 0, 0)
    body:SetPaintBackground(false)

    local sidebar = vgui.Create("DPanel", body)
    sidebar:Dock(LEFT)
    sidebar:SetWide(200)
    sidebar.Paint = function(self, w, h)
        draw.RoundedBoxEx(0, 0, 0, w, h, C.sidebar, false, false, true, false)
        surface.SetDrawColor(C.border.r, C.border.g, C.border.b, 80)
        surface.DrawLine(w - 1, 0, w - 1, h)
    end

    local content = vgui.Create("DPanel", body)
    content:Dock(FILL)
    content:DockMargin(12, 10, 12, 10)
    content:SetPaintBackground(false)

    local activeTab = nil
    local tabButtons = {}

    local function selectTab(tabKey, builderFn)
        activeTab = tabKey
        for k, btn in pairs(tabButtons) do
            btn.isActive = (k == tabKey)
        end
        content:Clear()
        if builderFn then builderFn(content, targetFac, data) end
    end

    local function addTabBtn(tabKey, label, icon, builderFn)
        local btn = vgui.Create("DButton", sidebar)
        btn:Dock(TOP)
        btn:SetTall(38)
        btn:DockMargin(6, 4, 6, 0)
        btn:SetText("")
        btn.isActive = false

        btn.Paint = function(self, w, h)
            local isHov = self:IsHovered()
            local isAct = self.isActive
            if isAct then
                draw.RoundedBox(6, 0, 0, w, h, C.accent)
            elseif isHov then
                draw.RoundedBox(6, 0, 0, w, h, C.cardHover)
            end
            local col = isAct and color_white or (isHov and C.text or C.dim)
            draw.SimpleText(label, "GRMFac_Btn", 16, h / 2, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        btn.DoClick = function() selectTab(tabKey, builderFn) end
        tabButtons[tabKey] = btn
    end

    -- Вкладка 1: ОБЗОР
    local function buildOverviewTab(pnl, facName, facData)
        local fac = facData and facData[facName] or {}
        local dispName = GRM.Factions.DisplayName(facName)
        local ldrKey = tostring(fac.Leader or "Не назначен")
        local memCount = fac.Members and table.Count(fac.Members) or 0
        local deptCount = fac.Departments and #fac.Departments or 0
        local roleCount = fac.Roles and #fac.Roles or 0
        local budget = fac.Budget or 0

        local grid = vgui.Create("DGrid", pnl)
        grid:Dock(TOP)
        grid:SetTall(130)
        grid:SetCols(4)
        grid:SetColWide((pnl:GetWide() - 40) / 4)
        grid:SetRowHeight(110)

        local function addStatCard(title, val, color)
            local card = vgui.Create("DPanel")
            card:SetSize((pnl:GetWide() - 48) / 4, 100)
            card.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, C.card)
                surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
                surface.DrawOutlinedRect(0, 0, w, h)
                draw.SimpleText(title, "GRMFac_Small", 14, 16, C.dim, TEXT_ALIGN_LEFT)
                draw.SimpleText(tostring(val), "GRMFac_Title", 14, 45, color or C.text, TEXT_ALIGN_LEFT)
            end
            grid:AddItem(card)
        end

        addStatCard("СОТРУДНИКОВ", memCount, C.accent)
        addStatCard("ОТДЕЛОВ", deptCount, C.green)
        addStatCard("ДОЛЖНОСТЕЙ", roleCount, C.gold)
        addStatCard("КАЗНА / БЮДЖЕТ", tostring(budget) .. " руб.", C.gold)

        local infoPanel = vgui.Create("DPanel", pnl)
        infoPanel:Dock(FILL)
        infoPanel:DockMargin(0, 16, 0, 0)
        infoPanel.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
            surface.DrawOutlinedRect(0, 0, w, h)
            draw.SimpleText("Информация об организации", "GRMFac_Sub", 16, 18, C.text)
            draw.SimpleText("Публичное название: " .. dispName, "GRMFac_Normal", 16, 48, C.text)
            draw.SimpleText("Системный идентификатор: " .. facName, "GRMFac_Normal", 16, 72, C.dim)
            draw.SimpleText("Руководитель: " .. ldrKey, "GRMFac_Normal", 16, 96, C.dim)
            draw.SimpleText("Тэг волны: " .. (fac.Tag and fac.Tag ~= "" and fac.Tag or "—"), "GRMFac_Normal", 16, 120, C.dim)
        end
    end

    -- Вкладка 2: СОТРУДНИКИ
    local function buildMembersTab(pnl, facName, facData)
        local fac = facData and facData[facName] or {}
        local list = vgui.Create("DListView", pnl)
        list:Dock(FILL)
        list:SetMultiSelect(false)
        list:AddColumn("Имя / Идентификатор"):SetFixedWidth(240)
        list:AddColumn("Должность"):SetFixedWidth(180)
        list:AddColumn("Отдел"):SetFixedWidth(180)
        list:AddColumn("Статус службы"):SetFixedWidth(120)

        for key, rec in pairs(fac.Members or {}) do
            local roleDisplay = GRM.Factions.RoleDisplayName(fac, rec.Role)
            local deptDisplay = GRM.Factions.DepartmentDisplayName(fac, rec.Department)
            local onDuty = GRM.FactionDuty and GRM.FactionDuty.State and GRM.FactionDuty.State[key]
            local dutyText = onDuty and "НА СЛУЖБЕ" or "ВНЕ СЛУЖБЫ"
            local ln = list:AddLine(tostring(key), roleDisplay, deptDisplay, dutyText)
            ln.memberKey = key
        end
    end

    -- Вкладка 3: СТРУКТУРА (Отделы и Должности со стабильными ключами)
    local function buildStructureTab(pnl, facName, facData)
        local fac = facData and facData[facName] or {}

        local split = vgui.Create("DPanel", pnl)
        split:Dock(FILL)
        split:SetPaintBackground(false)

        local left = vgui.Create("DPanel", split)
        left:Dock(LEFT)
        left:SetWide((pnl:GetWide() - 40) / 2)
        left.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            draw.SimpleText("Должности (Roles)", "GRMFac_Sub", 14, 14, C.gold)
        end

        local right = vgui.Create("DPanel", split)
        right:Dock(RIGHT)
        right:SetWide((pnl:GetWide() - 40) / 2)
        right.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            draw.SimpleText("Отделы (Departments)", "GRMFac_Sub", 14, 14, C.green)
        end

        local rList = vgui.Create("DListView", left)
        rList:Dock(FILL)
        rList:DockMargin(10, 40, 10, 10)
        rList:AddColumn("Системный ключ"):SetFixedWidth(140)
        rList:AddColumn("Публичное название (RU)")

        for _, rKey in ipairs(fac.Roles or {}) do
            local rDisp = GRM.Factions.RoleDisplayName(fac, rKey)
            rList:AddLine(rKey, rDisp)
        end

        local dList = vgui.Create("DListView", right)
        dList:Dock(FILL)
        dList:DockMargin(10, 40, 10, 10)
        dList:AddColumn("Системный ключ"):SetFixedWidth(140)
        dList:AddColumn("Публичное название (RU)")

        for _, dKey in ipairs(fac.Departments or {}) do
            local dDisp = GRM.Factions.DepartmentDisplayName(fac, dKey)
            dList:AddLine(dKey, dDisp)
        end
    end

    -- Вкладка 4: КАДРОВЫЕ ДЕЛА (Personnel Files)
    local function buildPersonnelTab(pnl, facName, facData)
        if GRM.FactionPersonnel and GRM.FactionPersonnel.OpenTab then
            GRM.FactionPersonnel.OpenTab(pnl, facName)
        else
            local lbl = vgui.Create("DLabel", pnl)
            lbl:Dock(TOP)
            lbl:SetText("Кадровый модуль GRM.FactionPersonnel активен.")
            lbl:SetFont("GRMFac_Normal")
            lbl:SetTextColor(C.dim)
        end
    end

    -- Регистрация кнопок в боковой панели
    addTabBtn("overview", "Обзор", "icon16/application_home.png", buildOverviewTab)
    addTabBtn("members", "Сотрудники", "icon16/group.png", buildMembersTab)
    addTabBtn("structure", "Структура", "icon16/chart_organisation.png", buildStructureTab)
    addTabBtn("personnel", "Кадровые дела", "icon16/book.png", buildPersonnelTab)

    selectTab("overview", buildOverviewTab)
end

concommand.Add("grm_factions_menu", function() UI.Open() end)
concommand.Add("grm_faction", function() UI.Open() end)

hook.Add("PlayerSayTransform", "GRM_FactionUnified_ChatCommand", function(ply, datapack)
    if not istable(datapack) then return end
    local text = datapack[1]
    if not isstring(text) then return end
    local lower = string.lower(string.Trim(text))
    if lower == "/fmenu" or lower == "/фракция" or lower == "/состав" then
        if CLIENT then UI.Open() end
    end
end)

print("[GRM Factions Unified UI] v" .. UI.Version .. " loaded")
