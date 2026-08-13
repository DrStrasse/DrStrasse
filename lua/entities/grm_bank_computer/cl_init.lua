--[[--------------------------------------------------------------------
    grm_bank_computer — клиент: 3D2D экран + меню управления банком
----------------------------------------------------------------------]]
include("shared.lua")

surface.CreateFont("GRMBComp_Title", { font = "Roboto", size = 18, weight = 900, extended = true })
surface.CreateFont("GRMBComp_Head",  { font = "Roboto", size = 15, weight = 700, extended = true })
surface.CreateFont("GRMBComp_Norm",  { font = "Roboto", size = 13, weight = 500, extended = true })
surface.CreateFont("GRMBComp_Small", { font = "Roboto", size = 11, weight = 400, extended = true })

local function money(n)
    return GRM and GRM.Format and GRM.Format(tonumber(n) or 0) or (tostring(math.floor(tonumber(n) or 0)) .. " GRM")
end

function ENT:Draw()
    self:DrawModel()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    if ply:GetPos():DistToSqr(self:GetPos()) > (500 * 500) then return end

    local pos = self:GetPos() + Vector(0, 0, 24)
    local ang = EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    cam.Start3D2D(pos, Angle(0, ang.y, 90), 0.07)
        draw.RoundedBox(6, -140, -28, 280, 56, Color(16, 22, 32, 230))
        draw.RoundedBox(4, -138, -26, 276, 24, Color(30, 42, 60, 245))
        draw.SimpleText("КОМПЬЮТЕР УПРАВЛЕНИЯ", "GRMBComp_Head", 0, -14, Color(100, 200, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("[E] Финансовые операции банка", "GRMBComp_Small", 0, 14, Color(220, 230, 245), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

-- ── Клиентский интерфейс управления банком ─────────────────────────
local C = {
    bg      = Color(19, 24, 34, 250),
    panel   = Color(28, 36, 50, 245),
    header  = Color(25, 32, 45, 255),
    accent  = Color(70, 155, 255),
    gold    = Color(245, 190, 60),
    green   = Color(65, 190, 110),
    red     = Color(225, 75, 75),
    text    = Color(240, 244, 250),
    dim     = Color(160, 172, 190),
}

local compFrame = nil

local function sendAction(comp, action, target, amount)
    if not IsValid(comp) then return end
    net.Start("GRM_BankComp_Action")
        net.WriteEntity(comp)
        net.WriteString(action)
        net.WriteString(target or "")
        net.WriteUInt(math.max(0, math.floor(tonumber(amount) or 0)), 32)
    net.SendToServer()
end

net.Receive("GRM_BankComp_Open", function()
    local comp = net.ReadEntity()
    local d = net.ReadTable() or {}
    if not IsValid(comp) then return end

    if IsValid(compFrame) then compFrame:Remove() end
    local f = vgui.Create("DFrame")
    compFrame = f
    f:SetSize(780, 580)
    f:Center()
    f:SetTitle("")
    f:MakePopup()

    f.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, C.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 44, C.header, true, true, false, false)
        draw.SimpleText("КОМПЬЮТЕР УПРАВЛЕНИЯ БАНКОМ", "GRMBComp_Title", 14, 22, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local body = vgui.Create("DPanel", f)
    body:Dock(FILL)
    body:DockMargin(12, 54, 12, 12)
    body:SetPaintBackground(false)

    -- ── Карточки сводки вверху ──
    local summary = vgui.Create("DPanel", body)
    summary:Dock(TOP)
    summary:SetTall(84)
    summary:DockMargin(0, 0, 0, 10)
    summary.Paint = function(self, w, h)
        local cw = math.floor((w - 12) / 3)
        -- Карточка 1: Госбюджет
        draw.RoundedBox(6, 0, 0, cw, h, C.panel)
        draw.SimpleText("ГОСУДАРСТВЕННЫЙ БЮДЖЕТ", "GRMBComp_Small", 10, 14, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(money(d.stateBudget or 0), "GRMBComp_Head", 10, 42, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- Карточка 2: В хранилищах
        draw.RoundedBox(6, cw + 6, 0, cw, h, C.panel)
        draw.SimpleText("В ХРАНИЛИЩАХ (НАЛИЧНЫМИ)", "GRMBComp_Small", cw + 16, 14, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local vtxt = money(d.nearestVaultHeld or d.totalHeld or 0) .. " / " .. money(d.nearestVaultCap or d.totalCap or 500000)
        draw.SimpleText(vtxt, "GRMBComp_Head", cw + 16, 42, C.green, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

        -- Карточка 3: Печатный станок
        draw.RoundedBox(6, cw * 2 + 12, 0, cw, h, C.panel)
        draw.SimpleText("ПЕЧАТНЫЙ СТАНОК", "GRMBComp_Small", cw * 2 + 22, 14, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        if d.press and d.press.found then
            local st = d.press.broken and "ПЕРЕГРЕВ" or (d.press.active and "РАБОТАЕТ" or "ВЫКЛЮЧЕН")
            local scol = d.press.broken and C.red or (d.press.active and C.green or C.dim)
            draw.SimpleText(st .. " (буфер " .. money(d.press.buffer or 0) .. ")", "GRMBComp_Norm", cw * 2 + 22, 42, scol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("Не подключен рядом", "GRMBComp_Norm", cw * 2 + 22, 42, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end

    -- ── Вкладки управления ──
    local tabs = vgui.Create("DPropertySheet", body)
    tabs:Dock(FILL)

    -- ================= Вкладка 1: Распределение средств =================
    local distPnl = vgui.Create("DPanel", tabs)
    distPnl:DockPadding(10, 10, 10, 10)
    distPnl:SetPaintBackground(false)

    local function makeActionCard(parent, title, desc, btnText, btnColor, fn)
        local p = vgui.Create("DPanel", parent)
        p:Dock(TOP)
        p:SetTall(68)
        p:DockMargin(0, 0, 0, 8)
        p.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.panel)
            draw.SimpleText(title, "GRMBComp_Head", 12, 20, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(desc, "GRMBComp_Small", 12, 44, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local b = vgui.Create("DButton", p)
        b:Dock(RIGHT)
        b:DockMargin(0, 14, 12, 14)
        b:SetWide(190)
        b:SetText(btnText)
        b:SetFont("GRMBComp_Norm")
        b.Paint = function(self, w, h)
            local col = self:IsHovered() and Color(math.min(btnColor.r + 20, 255), math.min(btnColor.g + 20, 255), math.min(btnColor.b + 20, 255)) or btnColor
            draw.RoundedBox(4, 0, 0, w, h, col)
            draw.SimpleText(btnText, "GRMBComp_Norm", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        b.DoClick = fn
        return p
    end

    -- Кнопка 1: Хранилище -> Госбюджет
    makeActionCard(distPnl, "1. Зачислить из хранилища в госбюджет",
        "Переносит наличные средства из банковского хранилища на счёт казны сервера",
        "Зачислить в казну", C.gold, function()
            Derma_StringRequest("Зачисление в госбюджет", "Сумма для зачисления из хранилища:", "50000", function(val)
                local amt = math.floor(tonumber(val) or 0)
                if amt > 0 then sendAction(comp, "vault_to_state", "", amt) end
            end)
        end)

    -- Кнопка 2: Госбюджет -> Хранилище
    makeActionCard(distPnl, "2. Выделить из госбюджета в хранилище",
        "Выделяет средства из казны в виде физического запаса хранилища (для инкассации/снятия)",
        "Выделить в вольт", C.green, function()
            Derma_StringRequest("Выделение в хранилище", "Сумма из госбюджета в хранилище:", "50000", function(val)
                local amt = math.floor(tonumber(val) or 0)
                if amt > 0 then sendAction(comp, "state_to_vault", "", amt) end
            end)
        end)

    -- Кнопка 3: Хранилище -> Бюджет фракции
    makeActionCard(distPnl, "3. Перевести из хранилища во фракцию",
        "Прямой перевод наличного резерва хранилища на банковский бюджет конкретной организации",
        "Перевод фракции", Color(60, 140, 220), function()
            local menu = DermaMenu()
            for fName, _ in pairs(d.factions or {}) do
                menu:AddOption(fName, function()
                    Derma_StringRequest("Перевод фракции «" .. fName .. "»", "Сумма из хранилища:", "50000", function(val)
                        local amt = math.floor(tonumber(val) or 0)
                        if amt > 0 then sendAction(comp, "vault_to_faction", fName, amt) end
                    end)
                end)
            end
            menu:Open()
        end)

    -- Кнопка 4: Госбюджет -> Бюджет фракции
    makeActionCard(distPnl, "4. Государственная субсидия фракции",
        "Официальное финансирование организации напрямую из казны государства",
        "Выдать субсидию", Color(130, 90, 210), function()
            local menu = DermaMenu()
            for fName, _ in pairs(d.factions or {}) do
                menu:AddOption(fName, function()
                    Derma_StringRequest("Субсидия фракции «" .. fName .. "»", "Сумма субсидии из госбюджета:", "100000", function(val)
                        local amt = math.floor(tonumber(val) or 0)
                        if amt > 0 then sendAction(comp, "state_to_faction", fName, amt) end
                    end)
                end)
            end
            menu:Open()
        end)

    tabs:AddSheet("Распределение средств", distPnl, "icon16/money.png")

    -- ================= Вкладка 2: Печатный станок =================
    local pressPnl = vgui.Create("DPanel", tabs)
    pressPnl:DockPadding(12, 12, 12, 12)
    pressPnl:SetPaintBackground(false)

    if d.press and d.press.found then
        local pInfo = vgui.Create("DPanel", pressPnl)
        pInfo:Dock(TOP)
        pInfo:SetTall(100)
        pInfo:DockMargin(0, 0, 0, 12)
        pInfo.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.panel)
            draw.SimpleText("ПАРАМЕТРЫ ПЕЧАТНОГО СТАНКА (grm_money_press)", "GRMBComp_Head", 12, 18, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local l1 = "Статус: " .. (d.press.active and "ВКЛЮЧЕН (печатает)" or "ВЫКЛЮЧЕН") .. " | Температура: " .. (d.press.heat or 0) .. "°C"
            draw.SimpleText(l1, "GRMBComp_Norm", 12, 44, d.press.active and C.green or C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local l2 = "Номинал партии: " .. money(d.press.printAmount or 5000) .. " | В буфере паллет: " .. money(d.press.buffer or 0)
            draw.SimpleText(l2, "GRMBComp_Norm", 12, 68, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local function mkPressBtn(title, col, fn)
            local b = vgui.Create("DButton", pressPnl)
            b:Dock(TOP)
            b:DockMargin(0, 0, 0, 8)
            b:SetTall(38)
            b:SetText(title)
            b:SetFont("GRMBComp_Norm")
            b.Paint = function(self, w, h)
                local c = self:IsHovered() and Color(math.min(col.r + 20, 255), math.min(col.g + 20, 255), math.min(col.b + 20, 255)) or col
                draw.RoundedBox(4, 0, 0, w, h, c)
                draw.SimpleText(title, "GRMBComp_Norm", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            b.DoClick = fn
        end

        mkPressBtn(d.press.active and "⏸ ПРИОСТАНОВИТЬ ПЕЧАТЬ" or "▶ ЗАПУСТИТЬ ПЕЧАТЬ", d.press.active and C.red or C.green, function()
            sendAction(comp, "press_toggle", "", 0)
        end)

        mkPressBtn("❄ ОХЛАДИТЬ СТАНОК (сброс температуры)", C.accent, function()
            sendAction(comp, "press_cool", "", 0)
        end)

        mkPressBtn("📦 ВЫДАТЬ ПАЛЛЕТУ ДЕНЕГ ИЗ БУФЕРА", C.gold, function()
            sendAction(comp, "press_flush_buffer", "", 0)
        end)
    else
        local l = vgui.Create("DLabel", pressPnl)
        l:Dock(TOP)
        l:SetTall(60)
        l:SetFont("GRMBComp_Norm")
        l:SetTextColor(C.dim)
        l:SetText("Печатный станок (grm_money_press) не найден в радиусе 1200 юнитов.\nУстановите банковский печатный станок рядом с компьютером управления.")
    end

    tabs:AddSheet("Печатный станок", pressPnl, "icon16/cog.png")

    -- ================= Вкладка 3: Реестр фракций =================
    local facPnl = vgui.Create("DPanel", tabs)
    facPnl:DockPadding(8, 8, 8, 8)
    facPnl:SetPaintBackground(false)

    local list = vgui.Create("DListView", facPnl)
    list:Dock(FILL)
    list:AddColumn("Фракция"):SetFixedWidth(240)
    list:AddColumn("Бюджет фракции"):SetFixedWidth(200)
    list:AddColumn("Налоговая ставка")

    for fName, info in pairs(d.factions or {}) do
        local line = list:AddLine(fName, money(info.budget or 0), math.floor((info.taxRate or 0.05) * 100) .. "%")
    end

    tabs:AddSheet("Справка по фракциям", facPnl, "icon16/group.png")
end)
