--[[--------------------------------------------------------------------
    sent_vehicle_dealer — cl_init.lua (CLIENT)
    Отрисовка дилера (3D2D подпись) и меню выбора транспорта.
--------------------------------------------------------------------]]

include("shared.lua")

-- ════════════════════════════════════════════════════════
-- Шрифты
-- ════════════════════════════════════════════════════════
surface.CreateFont("VD_Title", {
    font = "Verdana", size = 24, weight = 700, antialias = true
})
surface.CreateFont("VD_Subtitle", {
    font = "Verdana", size = 16, weight = 500, antialias = true
})
surface.CreateFont("VD_Hint", {
    font = "Verdana", size = 13, weight = 400, antialias = true
})
surface.CreateFont("VD_MenuTitle", {
    font = "Verdana", size = 20, weight = 700, antialias = true
})
surface.CreateFont("VD_MenuItem", {
    font = "Verdana", size = 15, weight = 500, antialias = true
})
surface.CreateFont("VD_MenuSmall", {
    font = "Verdana", size = 12, weight = 400, antialias = true
})

local matGlow = Material("sprites/light_glow02_add")
local matRing = Material("models/effects/vol_light001")

-- ════════════════════════════════════════════════════════
-- Отрисовка маркера точки спавна
-- ════════════════════════════════════════════════════════
local function DrawSpawnMarker(spawnPos, spawnAngle, alpha)
    if not spawnPos then return end

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local dist = lp:GetPos():Distance(spawnPos)
    if dist > 600 then return end

    local markerAlpha = math.Clamp((600 - dist) / 150, 0, 1) * alpha
    local pulse = math.abs(math.sin(CurTime() * 2.5)) * 0.4 + 0.6

    -- Пульсирующее кольцо на земле
    local ringPos = spawnPos + Vector(0, 0, 2)
    local ringAng = Angle(0, CurTime() * 30, 0)

    cam.Start3D2D(ringPos, ringAng, 0.15)
        -- Внешнее кольцо
        surface.SetDrawColor(40, 220, 100, math.floor(180 * markerAlpha * pulse))
        surface.DrawOutlinedRect(-60, -60, 120, 120, 3)

        -- Внутреннее кольцо
        surface.SetDrawColor(40, 220, 100, math.floor(120 * markerAlpha * pulse))
        surface.DrawOutlinedRect(-40, -40, 80, 80, 2)

        -- Центральная точка
        surface.SetDrawColor(80, 255, 140, math.floor(200 * markerAlpha * pulse))
        surface.DrawRect(-4, -4, 8, 8)

        -- Стрелка направления
        if spawnAngle then
            local fwd = spawnAngle:Forward()
            local arrowX = fwd.x * 50
            local arrowY = fwd.y * 50
            surface.SetDrawColor(40, 220, 100, math.floor(160 * markerAlpha * pulse))
            surface.DrawLine(0, 0, arrowX, arrowY)
        end

        -- Текст "SPAWN"
        draw.SimpleText(
            "SPAWN",
            "VD_MenuSmall",
            0, 70,
            Color(80, 255, 140, math.floor(200 * markerAlpha * pulse)),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )
    cam.End3D2D()

    -- Спрайт свечения над точкой
    render.SetMaterial(matGlow)
    render.DrawSprite(
        spawnPos + Vector(0, 0, 30),
        20 * pulse, 20 * pulse,
        Color(40, 220, 100, math.floor(100 * markerAlpha * pulse))
    )
end

-- ════════════════════════════════════════════════════════
-- 3D2D Отрисовка над дилером
-- ════════════════════════════════════════════════════════
function ENT:Draw()
    self:DrawModel()

    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    local dist = lp:GetPos():Distance(self:GetPos())
    if dist > 400 then return end

    local alpha = math.Clamp((400 - dist) / 120, 0, 1)
    local name  = self:GetDealerName()
    if name == "" then name = "Дилер транспорта" end

    local pos = self:GetPos() + Vector(0, 0, 85)
    local ang = lp:EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    cam.Start3D2D(pos, ang, 0.08)

        -- Фон
        surface.SetDrawColor(10, 20, 40, math.floor(210 * alpha))
        surface.DrawRect(-120, -28, 240, 56)

        -- Синяя рамка
        surface.SetDrawColor(60, 140, 220, math.floor(210 * alpha))
        surface.DrawOutlinedRect(-120, -28, 240, 56, 2)

        -- Имя дилера
        draw.SimpleText(
            name,
            "VD_Title",
            0, -10,
            Color(100, 200, 255, math.floor(255 * alpha)),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )

        -- Подсказка
        draw.SimpleText(
            "[E] Открыть каталог",
            "VD_Subtitle",
            0, 14,
            Color(180, 220, 255, math.floor(200 * alpha)),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER
        )

    cam.End3D2D()

    -- Мягкое свечение
    if dist < 250 then
        local pulse = math.abs(math.sin(CurTime() * 2)) * 0.3 + 0.7
        local sz = 16 + pulse * 6
        render.SetMaterial(matGlow)
        render.DrawSprite(
            self:GetPos() + Vector(0, 0, 80),
            sz, sz,
            Color(60, 160, 255, math.floor(120 * alpha * pulse))
        )
    end

    -- ═══ Отрисовка маркера точки спавна ═══
    local hasCustom = false
    pcall(function() hasCustom = self:GetHasCustomSpawn() end)

    if hasCustom then
        local spawnPos, spawnAngle
        pcall(function()
            spawnPos = self:GetSpawnPos()
            spawnAngle = self:GetSpawnAngle()
        end)
        if spawnPos then
            DrawSpawnMarker(spawnPos, spawnAngle, alpha)
        end
    end
end

-- ════════════════════════════════════════════════════════
-- Меню дилера (Диллер 2.1): вкладки «Каталог» и «Мой транспорт»
-- Каталог: поиск, живое превью модели, баланс, цена, кнопка покупки.
-- Мой транспорт: статус замка, дистанция, удалённая сдача с возвратом 50%.
-- ════════════════════════════════════════════════════════
surface.CreateFont("VD_RTitle", { font = "Roboto", size = 20, weight = 700, extended = true })
surface.CreateFont("VD_RItem",  { font = "Roboto", size = 16, weight = 600, extended = true })
surface.CreateFont("VD_RSmall", { font = "Roboto", size = 13, weight = 500, extended = true })
surface.CreateFont("VD_RTiny",  { font = "Roboto", size = 11, weight = 500, extended = true })
surface.CreateFont("VD_RBig",   { font = "Roboto", size = 24, weight = 800, extended = true })

local function fmtMoney(n)
    n = tonumber(n) or 0
    if GRM and GRM.Format then return GRM.Format(n) end
    return tostring(n) .. " $"
end

-- Бейдж источника доступа к позиции каталога
local SRC_STYLE = {
    global     = { t = "ОБЩИЙ",       c = Color(150, 200, 255) },
    nofaction  = { t = "БЕЗ ФРАКЦИИ", c = Color(190, 190, 255) },
    role       = { t = "РАНГ",        c = Color(200, 140, 255) },
    department = { t = "ОТДЕЛ",       c = Color(255, 190,  90) },
    personal   = { t = "ЛИЧНЫЙ",      c = Color(120, 230, 130) },
}
local function srcStyle(src)
    return SRC_STYLE[src] or { t = string.upper(tostring(src or "фракция")), c = Color(90, 190, 255) }
end

local function styleScroll(sp)
    local sb = sp:GetVBar()
    sb:SetWide(6)
    sb.Paint = function(_, w, h) surface.SetDrawColor(28, 42, 64, 200) surface.DrawRect(0, 0, w, h) end
    if sb.btnUp then sb.btnUp.Paint = function() end end
    if sb.btnDown then sb.btnDown.Paint = function() end end
    sb.btnGrip.Paint = function(_, w, h) surface.SetDrawColor(70, 140, 210, 190) surface.DrawRect(0, 0, w, h) end
end

-- Кэш «Мой транспорт» (Код 82 + 2.1: locked/dist) + живое обновление
local VD_MyVehicles = {}
local VD_MenuFrame = nil
local refreshMySection -- fwd: пересборка вкладки «Мой транспорт» открытого меню

net.Receive("VD_MyList", function()
    VD_MyVehicles = net.ReadTable() or {}
    if refreshMySection then refreshMySection() end
end)

local function OpenVehicleMenu(dealerID, dealerName, vlist, balance)
    vlist = vlist or {}
    balance = math.max(0, tonumber(balance) or 0)
    if #vlist == 0 and #VD_MyVehicles == 0 then
        chat.AddText(Color(255, 100, 100), "[VD] ", Color(200, 200, 200), "У вас нет доступа к транспорту у этого дилера")
        return
    end

    local frame = vgui.Create("DFrame")
    VD_MenuFrame = frame
    frame:SetTitle("")
    frame:SetSize(940, 620)
    frame:Center()
    frame:MakePopup()
    frame._balance = balance
    frame._pendingPrice = 0 -- цена незавершённой покупки (для локального пересчёта баланса)

    frame.Paint = function(_, w, h)
        surface.SetDrawColor(13, 18, 28, 250)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(62, 138, 214, 220)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        surface.SetDrawColor(22, 32, 48, 255)
        surface.DrawRect(0, 0, w, 30)
        draw.SimpleText(tostring(dealerName or "Дилер транспорта"), "VD_RTitle", 12, 15,
            Color(120, 200, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("каталог • покупка за наличные • сдача своего Т/С — возврат 50%", "VD_RTiny", w - 34, 15,
            Color(130, 150, 175), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    -- Подвал (создаём ДО вкладок: док-лейаут держит порядок создания)
    local footer = vgui.Create("DLabel", frame)
    footer:Dock(BOTTOM)
    footer:SetTall(18)
    footer:DockMargin(10, 0, 10, 4)
    footer:SetFont("VD_RTiny")
    footer:SetTextColor(Color(115, 135, 160))
    footer:SetContentAlignment(5)
    footer:SetText("Двойной клик по позиции — купить сразу  •  C возле машины — замок / багажник / сдача  •  /vd_remove — сдать всё из чата")

    local tabs = vgui.Create("DPropertySheet", frame)
    tabs:Dock(FILL)
    tabs:DockMargin(10, 34, 10, 2)
    tabs.Paint = function(_, w, h)
        surface.SetDrawColor(17, 24, 36, 245)
        surface.DrawRect(0, 0, w, h)
    end
    frame._tabs = tabs

    -- ═══════════ ВКЛАДКА «КАТАЛОГ» ═══════════
    local pageCat = vgui.Create("DPanel")
    pageCat:SetPaintBackground(false)

    local topBar = vgui.Create("DPanel", pageCat)
    topBar:Dock(TOP) topBar:SetTall(30) topBar:DockMargin(6, 6, 6, 4)
    topBar:SetPaintBackground(false)

    local search = vgui.Create("DTextEntry", topBar)
    search:Dock(LEFT) search:SetWide(300)
    search:SetFont("VD_RSmall")
    search:SetPlaceholderText("Поиск: название, класс или источник…")

    local balLbl = vgui.Create("DLabel", topBar)
    balLbl:Dock(RIGHT) balLbl:SetWide(250)
    balLbl:SetFont("VD_RItem")
    balLbl:SetTextColor(Color(140, 220, 160))
    balLbl:SetContentAlignment(6)
    frame._updBalance = function()
        if IsValid(balLbl) then
            balLbl:SetText("Наличные: " .. fmtMoney(frame._balance))
        end
    end
    frame._updBalance()

    -- Правая панель деталей (превью/цена/кнопка)
    local detail = vgui.Create("DPanel", pageCat)
    detail:Dock(RIGHT) detail:SetWide(300) detail:DockMargin(4, 0, 6, 6)
    detail.Paint = function(_, w, h)
        surface.SetDrawColor(20, 28, 42, 240)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(50, 90, 140, 160)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end

    local list = vgui.Create("DScrollPanel", pageCat)
    list:Dock(FILL) list:DockMargin(6, 0, 4, 6)
    styleScroll(list)

    local function rebuildDetail()
        detail:Clear()
        local veh = frame._sel
        if not veh then
            local em = vgui.Create("DLabel", detail)
            em:Dock(FILL)
            em:SetFont("VD_RSmall")
            em:SetContentAlignment(5)
            em:SetTextColor(Color(140, 155, 180))
            em:SetText("Выберите транспорт\nв списке слева")
            return
        end

        -- Живое превью модели
        local mp = vgui.Create("DModelPanel", detail)
        mp:Dock(TOP) mp:SetTall(168) mp:DockMargin(6, 6, 6, 4)
        local mdl = tostring(veh.model or "")
        if mdl == "" or not util.IsValidModel(mdl) then mdl = "models/buggy.mdl" end
        mp:SetModel(mdl)
        if IsValid(mp.Entity) then
            local mn, mx = mp.Entity:GetRenderBounds()
            mn = mn or Vector(0, 0, 0)
            mx = mx or Vector(100, 100, 60)
            local size = mn:Distance(mx)
            if size < 60 then size = 60 end
            mp:SetCamPos(Vector(size * 0.75, size * 0.75, size * 0.5))
            mp:SetLookAt((mn + mx) * 0.5)
        end

        local nm = vgui.Create("DLabel", detail)
        nm:Dock(TOP) nm:SetTall(24) nm:DockMargin(10, 2, 10, 0)
        nm:SetFont("VD_RItem") nm:SetTextColor(Color(225, 238, 255))
        nm:SetText(tostring(veh.name or veh.class or "Транспорт"))

        local cl = vgui.Create("DLabel", detail)
        cl:Dock(TOP) cl:SetTall(15) cl:DockMargin(10, 0, 10, 0)
        cl:SetFont("VD_RTiny") cl:SetTextColor(Color(115, 135, 160))
        cl:SetText(tostring(veh.class or ""))

        local st = srcStyle(veh.source)
        local sr = vgui.Create("DLabel", detail)
        sr:Dock(TOP) sr:SetTall(15) sr:DockMargin(10, 1, 10, 0)
        sr:SetFont("VD_RTiny") sr:SetTextColor(st.c)
        sr:SetText("Доступ: " .. st.t)

        local price = math.max(0, tonumber(veh.price) or 0)
        local isService = (SRC_STYLE[veh.source] == nil) -- фракционный список = служебный
        local afford = price <= 0 or frame._balance >= price

        local pr = vgui.Create("DLabel", detail)
        pr:Dock(TOP) pr:SetTall(34) pr:DockMargin(10, 6, 10, 0)
        pr:SetFont("VD_RBig")
        if isService then
            pr:SetText("СЛУЖЕБНЫЙ") pr:SetTextColor(st.c)
        elseif price > 0 then
            pr:SetText(fmtMoney(price)) pr:SetTextColor(Color(120, 230, 130))
        else
            pr:SetText("БЕСПЛАТНО") pr:SetTextColor(Color(140, 170, 200))
        end

        if not afford then
            local nd = vgui.Create("DLabel", detail)
            nd:Dock(TOP) nd:SetTall(16) nd:DockMargin(10, 0, 10, 0)
            nd:SetFont("VD_RTiny") nd:SetTextColor(Color(255, 130, 120))
            nd:SetText("Не хватает: " .. fmtMoney(price - frame._balance))
        end

        local buy = vgui.Create("DButton", detail)
        buy:Dock(TOP) buy:SetTall(42) buy:DockMargin(10, 10, 10, 0)
        buy:SetText("")
        buy:SetEnabled(afford)
        buy.Paint = function(self, w, h)
            local c
            if not afford then c = Color(60, 70, 85, 210)
            elseif self:IsHovered() then c = Color(70, 190, 110, 245)
            else c = Color(50, 155, 90, 225) end
            surface.SetDrawColor(c)
            surface.DrawRect(0, 0, w, h)
            local t = (price > 0 and not isService) and "КУПИТЬ" or "ЗАСПАВНИТЬ"
            draw.SimpleText(t, "VD_RItem", w / 2, h / 2,
                afford and Color(255, 255, 255) or Color(150, 160, 175),
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        buy.DoClick = function()
            local v = frame._sel
            if not v then return end
            frame._pendingPrice = (price > 0 and not isService and afford) and price or 0
            net.Start("VD_SpawnRequest")
                net.WriteString(dealerID)
                net.WriteString(v.class or "")
            net.SendToServer()
        end

        local note = vgui.Create("DLabel", detail)
        note:Dock(TOP) note:DockMargin(10, 8, 10, 0)
        note:SetFont("VD_RTiny") note:SetTextColor(Color(120, 140, 160))
        note:SetAutoStretchVertical(true) note:SetWrap(true)
        note:SetText("Списание с наличных при покупке. Сдача своего Т/С — 50% цены: вкладка «Мой транспорт» или C у машины.")
    end
    frame._showDetail = function(veh)
        frame._sel = veh
        rebuildDetail()
    end

    -- Строки каталога
    local rows = {}
    for _, veh in ipairs(vlist) do
        local row = vgui.Create("DButton", list)
        row:Dock(TOP) row:SetTall(52) row:DockMargin(0, 0, 0, 4)
        row:SetText("")
        row._veh = veh
        local st = srcStyle(veh.source)
        local price = math.max(0, tonumber(veh.price) or 0)
        local isService = (SRC_STYLE[veh.source] == nil)
        row.Paint = function(self, w, h)
            local hov = self:IsHovered()
            surface.SetDrawColor(self._sel and Color(30, 48, 72, 245) or (hov and Color(27, 39, 58, 235) or Color(22, 31, 47, 225)))
            surface.DrawRect(0, 0, w, h)
            surface.SetDrawColor(self._sel and Color(80, 160, 230, 220) or Color(45, 75, 115, 120))
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            draw.SimpleText(tostring(veh.name or veh.class or "?"), "VD_RItem", 10, 10,
                Color(224, 236, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(tostring(veh.class or ""), "VD_RTiny", 10, 29,
                Color(115, 135, 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("● " .. st.t, "VD_RTiny", 10, 40, st.c, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local pt, pc
            if isService then pt, pc = "служебный", st.c
            elseif price > 0 then pt, pc = fmtMoney(price), Color(120, 230, 130)
            else pt, pc = "бесплатно", Color(120, 150, 180) end
            draw.SimpleText(pt, "VD_RItem", w - 12, h / 2, pc, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        row.DoClick = function(self)
            for _, r in ipairs(rows) do r._sel = (r == self) end
            frame._showDetail(veh)
        end
        row.DoDoubleClick = function(self)
            for _, r in ipairs(rows) do r._sel = (r == self) end
            frame._showDetail(veh)
            frame._pendingPrice = (price > 0 and not isService and frame._balance >= price) and price or 0
            net.Start("VD_SpawnRequest")
                net.WriteString(dealerID)
                net.WriteString(veh.class or "")
            net.SendToServer()
        end
        table.insert(rows, row)
    end

    search.OnChange = function(self)
        local q = string.lower(self:GetText() or "")
        for _, r in ipairs(rows) do
            local v = r._veh
            local vis = q == ""
                or string.find(string.lower(tostring(v.name or "")), q, 1, true)
                or string.find(string.lower(tostring(v.class or "")), q, 1, true)
                or string.find(string.lower(tostring(v.source or "")), q, 1, true)
            r:SetVisible(vis == true)
        end
        list:InvalidateLayout()
    end

    rebuildDetail()

    -- ═══════════ ВКЛАДКА «МОЙ ТРАНСПОРТ» ═══════════
    local pageMy = vgui.Create("DPanel")
    pageMy:SetPaintBackground(false)

    local myHead = vgui.Create("DLabel", pageMy)
    myHead:Dock(TOP) myHead:SetTall(22) myHead:DockMargin(8, 6, 8, 2)
    myHead:SetFont("VD_RSmall") myHead:SetTextColor(Color(150, 205, 175))

    local myScroll = vgui.Create("DScrollPanel", pageMy)
    myScroll:Dock(FILL) myScroll:DockMargin(6, 0, 6, 4)
    styleScroll(myScroll)

    local myBottom = vgui.Create("DPanel", pageMy)
    myBottom:Dock(BOTTOM) myBottom:SetTall(34) myBottom:DockMargin(6, 2, 6, 4)
    myBottom:SetPaintBackground(false)

    local function sendRemove(entID)
        net.Start("VD_RemoveRequest")
            net.WriteEntity(Entity(entID or 0))
            net.WriteBool(true) -- fromMenu: сдаём удалённо, стоя у дилера (гараж)
        net.SendToServer()
    end

    local function rebuildMy()
        if not IsValid(myScroll) or not IsValid(myBottom) then return end
        myScroll:Clear()
        myBottom:Clear()
        local n = #VD_MyVehicles
        myHead:SetText(string.format("Мой транспорт (%d/3)  •  сдача возвращает 50%%  •  обновление каждые 5 сек", n))

        local totalRefund = 0
        for _, mv in ipairs(VD_MyVehicles) do
            totalRefund = totalRefund + (tonumber(mv.refund) or 0)
            local row = vgui.Create("DPanel", myScroll)
            row:Dock(TOP) row:SetTall(48) row:DockMargin(0, 0, 0, 4)
            row._mv = mv
            row.Paint = function(self, w, h)
                local m = self._mv
                surface.SetDrawColor(24, 36, 54, 230)
                surface.DrawRect(0, 0, w, h)
                surface.SetDrawColor(60, 110, 90, 130)
                surface.DrawOutlinedRect(0, 0, w, h, 1)
                draw.SimpleText(tostring(m.name or m.class or "?"), "VD_RItem", 10, 9,
                    Color(224, 236, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(tostring(m.class or ""), "VD_RTiny", 10, 27,
                    Color(115, 135, 160), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                -- статус замка
                local lc = m.locked and Color(235, 130, 120) or Color(130, 225, 150)
                draw.SimpleText(m.locked and "ЗАКРЫТ" or "ОТКРЫТ", "VD_RTiny", 250, 27,
                    lc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                -- дистанция до Т/С
                draw.SimpleText("≈ " .. tostring(m.dist or 0) .. " м", "VD_RTiny", 250, 9,
                    Color(140, 160, 185), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                -- возврат
                if (tonumber(m.refund) or 0) > 0 then
                    draw.SimpleText("вернуть " .. fmtMoney(m.refund), "VD_RSmall", w - 126, h / 2,
                        Color(130, 225, 145), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                else
                    draw.SimpleText("без возврата", "VD_RTiny", w - 126, h / 2,
                        Color(130, 145, 165), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
            end
            local del = vgui.Create("DButton", row)
            del:Dock(RIGHT) del:DockMargin(6, 8, 8, 8) del:SetWide(104)
            del:SetText("")
            del._mv = mv
            del.Paint = function(self, w, h)
                local c = self:IsHovered() and Color(205, 95, 85, 245) or Color(165, 70, 62, 215)
                surface.SetDrawColor(c)
                surface.DrawRect(0, 0, w, h)
                draw.SimpleText("УБРАТЬ", "VD_RSmall", w / 2, h / 2,
                    Color(255, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            del.DoClick = function(self)
                local m = self._mv
                if not m then return end
                local rf = (tonumber(m.refund) or 0) > 0
                    and ("Возврат: " .. fmtMoney(m.refund)) or "Без возврата средств"
                Derma_Query("Убрать «" .. tostring(m.name or m.class) .. "»?\n" .. rf,
                    "Сдать транспорт дилеру",
                    "Убрать", function() sendRemove(m.id) end,
                    "Оставить", function() end)
            end
        end

        if n == 0 then
            local em = vgui.Create("DLabel", myScroll)
            em:Dock(TOP) em:SetTall(60)
            em:SetFont("VD_RSmall")
            em:SetContentAlignment(5)
            em:SetTextColor(Color(130, 150, 175))
            em:SetText("У вас нет заспавненного транспорта.\nКупите в каталоге или возьмите служебный.")
        end

        if n > 0 then
            local sum = vgui.Create("DLabel", myBottom)
            sum:Dock(LEFT) sum:SetWide(380)
            sum:SetFont("VD_RSmall") sum:SetTextColor(Color(150, 200, 170))
            sum:SetText("Сдать всё: " .. n .. " ед. • суммарный возврат " .. fmtMoney(totalRefund))

            local all = vgui.Create("DButton", myBottom)
            all:Dock(RIGHT) all:SetWide(180)
            all:SetText("")
            all._count = n
            all._sum = totalRefund
            all.Paint = function(self, w, h)
                local c = self:IsHovered() and Color(200, 90, 70, 245) or Color(160, 60, 50, 215)
                surface.SetDrawColor(c)
                surface.DrawRect(0, 0, w, h)
                draw.SimpleText("УБРАТЬ ВСЁ (" .. self._count .. ")", "VD_RSmall", w / 2, h / 2,
                    Color(255, 240, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            all.DoClick = function(self)
                Derma_Query("Сдать ВЕСЬ транспорт (" .. self._count .. " ед.)?\nСуммарный возврат: " .. fmtMoney(self._sum),
                    "Сдать весь транспорт",
                    "Убрать всё", function()
                        for _, mv in ipairs(VD_MyVehicles) do sendRemove(mv.id) end
                    end,
                    "Отмена", function() end)
            end
        end
    end

    refreshMySection = rebuildMy -- живое обновление по VD_MyList (Код 82/2.1)
    rebuildMy()

    -- Автообновление гаража, пока меню открыто (замок/дистанция/возврат)
    local tname = "VD_MyRefresh_" .. tostring(frame)
    timer.Create(tname, 5, 0, function()
        if not IsValid(frame) then timer.Remove(tname) return end
        net.Start("VD_MyListReq")
        net.SendToServer()
    end)

    tabs:AddSheet("  Каталог  ", pageCat, "icon16/car.png")
    local sheetMy = tabs:AddSheet("  Мой транспорт  ", pageMy, "icon16/money.png")
    frame._myTab = sheetMy

    -- Каталог пуст (напр. только свой служебный) — сразу гараж
    if #vlist == 0 and sheetMy and IsValid(sheetMy.Tab) then
        tabs:SetActiveTab(sheetMy.Tab)
    end
end

-- ════════════════════════════════════════════════════════
-- Меню конфигурации (суперадмин) — с вкладками фракций
-- ════════════════════════════════════════════════════════
local function OpenConfigMenu(dealerID, dealerName, dealerModel, vehicles, serverVehicleList)
    vehicles = vehicles or {}
    serverVehicleList = serverVehicleList or {}

    local frame = vgui.Create("DFrame")
    frame:SetTitle("Конфигурация дилера: " .. (dealerName or ""))
    frame:SetSize(900, 700)
    frame:Center()
    frame:MakePopup()

    frame.Paint = function(self, w, h)
        surface.SetDrawColor(15, 25, 45, 245)
        surface.DrawRect(0, 0, w, h)
        surface.SetDrawColor(220, 140, 40, 200)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        surface.SetDrawColor(40, 30, 10, 250)
        surface.DrawRect(0, 0, w, 28)
        draw.SimpleText(self:GetTitle(), "VD_MenuTitle", w / 2, 14, Color(255, 200, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    -- ═══ Верхняя панель: имя + модель ═══
    local topPanel = vgui.Create("DPanel", frame)
    topPanel:Dock(TOP)
    topPanel:SetTall(90)
    topPanel:DockMargin(10, 34, 10, 4)
    topPanel:SetPaintBackground(false)

    local nameLabel = vgui.Create("DLabel", topPanel)
    nameLabel:SetPos(0, 4) nameLabel:SetSize(100, 20)
    nameLabel:SetText("Имя дилера:") nameLabel:SetFont("VD_MenuSmall")
    nameLabel:SetTextColor(Color(200, 200, 200))

    local nameEntry = vgui.Create("DTextEntry", topPanel)
    nameEntry:SetPos(110, 2) nameEntry:SetSize(300, 22)
    nameEntry:SetText(dealerName or "") nameEntry:SetFont("VD_MenuSmall")

    local modelLabel = vgui.Create("DLabel", topPanel)
    modelLabel:SetPos(0, 34) modelLabel:SetSize(100, 20)
    modelLabel:SetText("Модель .mdl:") modelLabel:SetFont("VD_MenuSmall")
    modelLabel:SetTextColor(Color(200, 200, 200))

    local modelEntry = vgui.Create("DTextEntry", topPanel)
    modelEntry:SetPos(110, 32) modelEntry:SetSize(500, 22)
    modelEntry:SetText(dealerModel or "") modelEntry:SetFont("VD_MenuSmall")
    modelEntry:SetPlaceholderText("models/Humans/Group01/Male_02.mdl")

    local infoLabel = vgui.Create("DLabel", topPanel)
    infoLabel:SetPos(0, 62) infoLabel:SetSize(860, 20)
    infoLabel:SetText("Настройте транспорт: Глобальный (все), Без фракции (только вне фракций), по фракциям (только члены).")
    infoLabel:SetFont("VD_MenuSmall")
    infoLabel:SetTextColor(Color(160, 180, 200))

    -- ═══ Информация о количестве транспорта на сервере ═══
    local vehCountLabel = vgui.Create("DLabel", frame)
    vehCountLabel:Dock(TOP)
    vehCountLabel:SetTall(18)
    vehCountLabel:DockMargin(16, 0, 10, 2)
    vehCountLabel:SetText("Транспорт на сервере: " .. #serverVehicleList .. " ед. (GMod + SimFPhys + LVS)")
    vehCountLabel:SetFont("VD_MenuSmall")
    vehCountLabel:SetTextColor(Color(100, 200, 100))

    -- ═══ Вкладки фракций ═══
    local tabs = vgui.Create("DPropertySheet", frame)
    tabs:Dock(FILL)
    tabs:DockMargin(6, 4, 6, 44)

    function tabs:Paint(w, h)
        surface.SetDrawColor(20, 30, 50, 240)
        surface.DrawRect(0, 0, w, h)
    end

    -- Рабочая копия vehicles для редактирования
    local editVehicles = table.Copy(vehicles)

    -- Получаем все фракции из глобальных данных
    local factionNames = {}
    if FactionsData then
        for name, _ in pairs(FactionsData) do
            table.insert(factionNames, name)
        end
    end
    table.sort(factionNames)

    -- Используем список транспорта с сервера
    local allVehicles = serverVehicleList

    -- ═══ Функция создания панели с чекбоксами транспорта ═══
    local function CreateVehicleCheckboxPanel(parentTabs, tabTitle, tabIcon, infoText, infoColor, storageKey)
        local panel = vgui.Create("DPanel")
        panel:SetPaintBackground(false)
        panel:DockPadding(4, 4, 4, 4)

        local info = vgui.Create("DLabel", panel)
        info:Dock(TOP) info:SetTall(24) info:DockMargin(4, 0, 4, 4)
        info:SetText(infoText)
        info:SetFont("VD_MenuSmall") info:SetTextColor(infoColor)

        -- Поиск/фильтр
        local searchPanel = vgui.Create("DPanel", panel)
        searchPanel:Dock(TOP) searchPanel:SetTall(26) searchPanel:DockMargin(4, 0, 4, 4)
        searchPanel:SetPaintBackground(false)

        local searchLabel = vgui.Create("DLabel", searchPanel)
        searchLabel:SetPos(0, 3) searchLabel:SetSize(50, 20)
        searchLabel:SetText("Поиск:") searchLabel:SetFont("VD_MenuSmall")
        searchLabel:SetTextColor(Color(180, 180, 200))

        local searchEntry = vgui.Create("DTextEntry", searchPanel)
        searchEntry:SetPos(55, 0) searchEntry:SetSize(300, 24)
        searchEntry:SetFont("VD_MenuSmall")
        searchEntry:SetPlaceholderText("Введите название или класс...")

        -- Счётчик выбранных
        local countLabel = vgui.Create("DLabel", searchPanel)
        countLabel:SetPos(370, 3) countLabel:SetSize(200, 20)
        countLabel:SetFont("VD_MenuSmall")
        countLabel:SetTextColor(Color(100, 220, 100))

        local scroll = vgui.Create("DScrollPanel", panel)
        scroll:Dock(FILL)

        -- Инициализируем набор
        if not editVehicles[storageKey] then editVehicles[storageKey] = {} end
        local checkSet = {}
        for _, v in ipairs(editVehicles[storageKey]) do
            checkSet[v.class] = true
        end

        -- Обновляем счётчик
        local function updateCount()
            local count = 0
            for _, _ in pairs(checkSet) do count = count + 1 end
            if IsValid(countLabel) then
                countLabel:SetText("Выбрано: " .. count .. " / " .. #allVehicles)
            end
        end
        updateCount()

        -- Строки чекбоксов
        local rows = {}

        for _, veh in ipairs(allVehicles) do
            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP) row:SetTall(26) row:DockMargin(0, 1, 0, 1)

            local isChecked = checkSet[veh.class] or false

            row.Paint = function(self, w, h)
                if checkSet[veh.class] then
                    surface.SetDrawColor(30, 50, 35, 180)
                else
                    surface.SetDrawColor(25, 30, 40, 120)
                end
                surface.DrawRect(0, 0, w, h)
            end

            local chk = vgui.Create("DCheckBoxLabel", row)
            chk:SetPos(6, 3) chk:SetSize(550, 20)
            chk:SetText(veh.name .. "  [" .. veh.class .. "]")
            chk:SetFont("VD_MenuSmall") chk:SetTextColor(Color(220, 220, 230))
            chk:SetValue(isChecked)
            chk.OnChange = function(_, val)
                if val then
                    checkSet[veh.class] = true
                else
                    checkSet[veh.class] = nil
                end
                updateCount()
            end

            -- Категория/аддон справа
            local catLabel = vgui.Create("DLabel", row)
            catLabel:SetPos(570, 3) catLabel:SetSize(200, 20)
            local catText = (veh.category or "")
            if veh.addon and veh.addon ~= "gmod" then
                catText = catText .. " (" .. veh.addon .. ")"
            end
            catLabel:SetText(catText)
            catLabel:SetFont("VD_MenuSmall") catLabel:SetTextColor(Color(120, 140, 160))

            row._veh = veh
            row._chk = chk
            table.insert(rows, row)
        end

        -- Фильтрация по поиску
        searchEntry.OnChange = function()
            local query = string.lower(searchEntry:GetText() or "")
            for _, row in ipairs(rows) do
                if IsValid(row) and row._veh then
                    local match = query == ""
                        or string.find(string.lower(row._veh.name or ""), query, 1, true)
                        or string.find(string.lower(row._veh.class or ""), query, 1, true)
                        or string.find(string.lower(row._veh.category or ""), query, 1, true)
                    row:SetVisible(match)
                end
            end
            scroll:InvalidateLayout()
        end

        -- Кнопки "Выбрать все" / "Снять все"
        local btnPanel = vgui.Create("DPanel", panel)
        btnPanel:Dock(BOTTOM) btnPanel:SetTall(28) btnPanel:DockMargin(4, 4, 4, 0)
        btnPanel:SetPaintBackground(false)

        local btnAll = vgui.Create("DButton", btnPanel)
        btnAll:SetPos(0, 0) btnAll:SetSize(120, 26) btnAll:SetText("Выбрать все")
        btnAll:SetFont("VD_MenuSmall")
        btnAll.Paint = function(self, w, h)
            surface.SetDrawColor(self:IsHovered() and Color(60, 140, 80, 200) or Color(40, 100, 60, 180))
            surface.DrawRect(0, 0, w, h)
            draw.SimpleText("✓ Выбрать все", "VD_MenuSmall", w/2, h/2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btnAll.DoClick = function()
            for _, row in ipairs(rows) do
                if IsValid(row) and row._veh and row:IsVisible() then
                    checkSet[row._veh.class] = true
                    if IsValid(row._chk) then row._chk:SetValue(true) end
                end
            end
            updateCount()
        end

        local btnNone = vgui.Create("DButton", btnPanel)
        btnNone:SetPos(130, 0) btnNone:SetSize(120, 26) btnNone:SetText("Снять все")
        btnNone:SetFont("VD_MenuSmall")
        btnNone.Paint = function(self, w, h)
            surface.SetDrawColor(self:IsHovered() and Color(140, 60, 60, 200) or Color(100, 40, 40, 180))
            surface.DrawRect(0, 0, w, h)
            draw.SimpleText("✕ Снять все", "VD_MenuSmall", w/2, h/2, Color(255,255,255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        btnNone.DoClick = function()
            for _, row in ipairs(rows) do
                if IsValid(row) and row._veh and row:IsVisible() then
                    checkSet[row._veh.class] = nil
                    if IsValid(row._chk) then row._chk:SetValue(false) end
                end
            end
            updateCount()
        end

        panel._checkSet = checkSet
        panel._storageKey = storageKey

        parentTabs:AddSheet(tabTitle, panel, tabIcon)
        return panel
    end

    -- ═══ Вкладка: Глобальный транспорт (для ВСЕХ) ═══
    local globalPanel = CreateVehicleCheckboxPanel(
        tabs,
        "🌐 Глобальный",
        "icon16/world.png",
        "Глобальный транспорт — доступен ВСЕМ игрокам, независимо от фракции",
        Color(200, 200, 100),
        "__global"
    )

    -- ═══ Вкладка: Без фракции (для игроков вне фракций) ═══
    local nofactionPanel = CreateVehicleCheckboxPanel(
        tabs,
        "👤 Без фракции",
        "icon16/user.png",
        "Транспорт для игроков БЕЗ фракции — видят только те, кто не состоит ни в одной фракции",
        Color(180, 180, 255),
        "__nofaction"
    )

    -- ═══ Вкладки фракций ═══
    for _, factionName in ipairs(factionNames) do
        local fData = FactionsData[factionName]
        local fColor = (fData and fData.Color) and Color(fData.Color.r or 255, fData.Color.g or 200, fData.Color.b or 50) or Color(255, 200, 50)

        CreateVehicleCheckboxPanel(
            tabs,
            "🎖 " .. factionName,
            "icon16/group.png",
            "Транспорт для фракции: " .. factionName .. " — видят только члены этой фракции",
            fColor,
            factionName
        )
    end

    -- ═══ Кнопка сохранения ═══
    local saveBtn = vgui.Create("DButton", frame)
    saveBtn:Dock(BOTTOM)
    saveBtn:DockMargin(10, 4, 10, 8)
    saveBtn:SetTall(32)
    saveBtn:SetText("")
    saveBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and Color(220, 160, 40, 240) or Color(180, 120, 20, 200)
        surface.SetDrawColor(col)
        surface.DrawRect(0, 0, w, h)
        draw.SimpleText("💾 Сохранить конфигурацию", "VD_MenuItem", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    saveBtn.DoClick = function()
        local newName  = nameEntry:GetText()
        local newModel = modelEntry:GetText()

        -- Собираем все списки из вкладок
        local newVehicles = {}

        for _, sheet in ipairs(tabs.Items) do
            if IsValid(sheet.Panel) and sheet.Panel._checkSet and sheet.Panel._storageKey then
                local key = sheet.Panel._storageKey
                local cSet = sheet.Panel._checkSet
                newVehicles[key] = {}
                for class, _ in pairs(cSet) do
                    table.insert(newVehicles[key], {
                        class = class,
                        name = class,
                        price = 0,
                    })
                end
            end
        end

        net.Start("VD_ConfigSave")
            net.WriteString(dealerID)
            net.WriteString(newName)
            net.WriteString(newModel)
            net.WriteTable(newVehicles)
        net.SendToServer()

        chat.AddText(Color(100, 220, 100), "[VD] Конфигурация сохранена")
        frame:Close()
    end
end

-- ════════════════════════════════════════════════════════
-- Сетевые обработчики (клиент)
-- ════════════════════════════════════════════════════════

-- Открытие меню дилера (2.1: 4-е поле — баланс наличных для UI)
net.Receive("VD_OpenMenu", function()
    local dealerID   = net.ReadString()
    local dealerName = net.ReadString()
    local vlist      = net.ReadTable()
    local balance    = net.ReadUInt(32) or 0
    OpenVehicleMenu(dealerID, dealerName, vlist, balance)
end)

-- Результат операции (покупка/сдача)
net.Receive("VD_SpawnResult", function()
    local ok  = net.ReadBool()
    local msg = net.ReadString()
    if ok then
        chat.AddText(Color(100, 220, 100), "[VD] ", Color(200, 255, 200), msg)
        if IsValid(VD_MenuFrame) then
            local f = VD_MenuFrame
            -- локальный пересчёт баланса после покупки (сервер — источник истины)
            f._balance = math.max(0, (tonumber(f._balance) or 0) - (tonumber(f._pendingPrice) or 0))
            f._pendingPrice = 0
            if f._updBalance then f._updBalance() end
            -- после покупки переключаемся в гараж: туда уже летит свежий VD_MyList
            if f._tabs and f._myTab and IsValid(f._myTab.Tab) then
                f._tabs:SetActiveTab(f._myTab.Tab)
            end
        end
    else
        chat.AddText(Color(255, 100, 100), "[VD] ", Color(255, 200, 200), msg)
        if IsValid(VD_MenuFrame) then VD_MenuFrame._pendingPrice = 0 end
    end
end)

-- Открытие конфигурации (админ)
net.Receive("VD_ConfigData", function()
    local dealerID         = net.ReadString()
    local dealerName       = net.ReadString()
    local dealerModel      = net.ReadString()
    local vehicles         = net.ReadTable()
    local serverVehicleList = net.ReadTable()
    OpenConfigMenu(dealerID, dealerName, dealerModel, vehicles, serverVehicleList)
end)

print("[VD] Клиентская часть sent_vehicle_dealer загружена")
