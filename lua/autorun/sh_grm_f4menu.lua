--[[--------------------------------------------------------------------
    GRM F4 Menu v1.0.0 (Код 74) — Игровое меню на F4
      - «Профиль»: игровое имя (RP Name) со сменой, внешность (меню
        персонажа Код 72), описание персонажа (RPDesc Код 71),
        карточка (SteamID64, фракция/роль, баланс).
      - «Команды»: интерактивная шпаргалка по игровым командам сгруппировано
        (Чат RP, Персонаж, Фракции, Деньги, Двери, Транспорт, Телефон, Прочее).
      - «Настройки»: клиентские выключатели HUD (RPDesc над головами,
        дистанция RPDesc, HUD дверей, полоса стамины, полоса сытости).
      - Открытие: F4 (ShowSpare2) — уступает дверям (прицел на дверь → меню двери),
        команда /menu, !menu, /f4, concommand grm_f4.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end
if not CLIENT then return end

GRM = GRM or {}
GRM.F4 = GRM.F4 or {}
local F4 = GRM.F4
F4.Version = "1.0.0"

surface.CreateFont("GRMF4_Title",  { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("GRMF4_Sub",    { font = "Roboto", size = 15, weight = 600, extended = true })
surface.CreateFont("GRMF4_Normal", { font = "Roboto", size = 13, weight = 500, extended = true })
surface.CreateFont("GRMF4_Small",  { font = "Roboto", size = 12, weight = 400, extended = true })

local C = {
    bg    = Color(20, 24, 32, 252),
    head  = Color(28, 34, 46, 255),
    panel = Color(32, 38, 50, 245),
    panel2= Color(26, 32, 42, 245),
    acc   = Color(70, 150, 240),
    green = Color(60, 190, 110),
    red   = Color(220, 75, 70),
    yellow= Color(230, 180, 60),
    text  = Color(240, 245, 250),
    dim   = Color(160, 170, 185),
}

local function mkBtn(p, txt, col)
    local b = vgui.Create("DButton", p)
    b:SetText(txt) b:SetFont("GRMF4_Sub") b:SetTextColor(color_white)
    b.Paint = function(self, pw, ph)
        local cc = col or C.acc
        if not self:IsEnabled() then cc = Color(60, 65, 75)
        elseif self:IsHovered() then cc = Color(math.min(255, cc.r + 25), math.min(255, cc.g + 25), math.min(255, cc.b + 25)) end
        draw.RoundedBox(6, 0, 0, pw, ph, cc)
    end
    return b
end

local function block(parent, h, title)
    local b = vgui.Create("DPanel", parent)
    b:Dock(TOP) b:SetTall(h) b:DockMargin(0, 0, 0, 6)
    b.Paint = function(_, pw, ph)
        draw.RoundedBox(6, 0, 0, pw, ph, C.panel)
        draw.SimpleText(title, "GRMF4_Sub", 10, 14, C.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return b
end

local function infoRow(parent, label, value, col)
    local r = vgui.Create("DPanel", parent)
    r:Dock(TOP) r:SetTall(24) r:DockMargin(10, 2, 10, 0)
    r.Paint = function(_, pw, ph)
        draw.SimpleText(label, "GRMF4_Normal", 4, ph / 2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(value, "GRMF4_Sub", pw - 4, ph / 2, col or C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    return r
end

-----------------------------------------------------------
-- Справочник команд
-----------------------------------------------------------
local CMD_GROUPS = {
    { name = "Персонаж", items = {
        { "/char, /chars", "Меню персонажа (внешность, имя)" },
        { "/name Имя Фамилия", "Сменить игровое (RP) имя" },
        { "/rpdesc", "Редактировать описание персонажа" },
        { "/mask, /maskcfg", "Маскировка (по доступу)" },
        { "/model", "Выбор модели из разрешённых" },
    }},
    { name = "RP-чат", items = {
        { "/me текст", "Действие от лица персонажа" },
        { "/do текст", "Событие вокруг персонажа" },
        { "/it текст", "Предмет/объект рядом" },
        { "/try текст", "Попытка действия (удача/неудача)" },
        { "/roll", "Случайное число 0–100" },
        { "/w текст", "Шёпот (ближний радиус)" },
        { "/y текст", "Крик (дальний радиус)" },
        { "/looc текст", "Локальный Out-Of-Character чат" },
        { "/ooc текст", "Глобальный Out-Of-Character чат" },
    }},
    { name = "Фракции", items = {
        { "/fjoin Имя", "Вступить во фракцию (по приглашению)" },
        { "/fleave", "Покинуть фракцию" },
        { "/fr текст", "Рация фракции" },
        { "/dep, /depb", "Волна/муляж подкрепления" },
        { "/factions", "Меню фракций (руководство/админ)" },
        { "/gnews текст", "Гос. новости (по доступу)" },
        { "/kom_hour, off", "Комендантский час (по доступу)" },
    }},
    { name = "Деньги", items = {
        { "!fbudget", "Бюджет своей фракции" },
        { "!fpay, !fwithdraw", "Взнос/вывод из бюджета (по правам)" },
        { "!fpayall", "Выплатить ЗП всем (лидер)" },
        { "!fsettax N", "Ставка налога фракции (лидер)" },
        { "/mysalary", "Информация о своей ЗП" },
        { "/fine сумма [причина]", "Оштрафовать (по правам)" },
        { "Банкомат (E)", "Счёт, переводы, бюджет фракции" },
    }},
    { name = "Двери и имущество", items = {
        { "/door", "Меню двери (аренда, совладельцы, доступы)" },
        { "/lock /unlock", "Замок двери в прицеле" },
        { "/drop", "Выбросить активное оружие/предмет" },
        { "/inv", "Инвентарь" },
        { "/store", "Меню склада фракции (у точки)" },
    }},
    { name = "Транспорт", items = {
        { "/vshop", "Магазин транспорта" },
        { "/vlist, /myvehicles", "Доступный/мой транспорт" },
        { "Ключи от машины", "ЛКМ/ПКМ — замок авто" },
    }},
    { name = "Телефон", items = {
        { "/phoneshop", "Магазин телефонов/AТC (по доступу)" },
        { "/phone_remove", "Снять свой телефон из прицела" },
    }},
}

-----------------------------------------------------------
-- Вкладка «Профиль»
-----------------------------------------------------------
local function buildProfileTab(sc, refresh)
    local lp = LocalPlayer()

    local b1 = block(sc, 116, "Игровое имя (RP Name):")
    local cur = lp:GetNWString("GRM_RPName", "")
    local nm = vgui.Create("DTextEntry", b1)
    nm:SetPos(10, 32) nm:SetSize(320, 30) nm:SetFont("GRMF4_Sub")
    nm:SetPlaceholderText("Имя Фамилия")
    nm:SetText(cur ~= "" and cur or "")

    local hint = vgui.Create("DLabel", b1)
    hint:SetPos(10, 88) hint:SetSize(700, 20) hint:SetFont("GRMF4_Normal") hint:SetTextColor(C.dim)
    hint:SetText("Виден над головой и в документах. Также команда: /name Имя Фамилия")

    local bSaveName = mkBtn(b1, "Сохранить имя", C.green)
    bSaveName:SetPos(340, 32) bSaveName:SetSize(170, 30)
    bSaveName.DoClick = function()
        local v = string.Trim(nm:GetValue() or "")
        if #v < 3 then
            Derma_Message("Имя короче 3 символов.", "F4", "Ок")
            return
        end
        net.Start("GRM_Char_Save")
            net.WriteTable({ name = v })
        net.SendToServer()
        timer.Simple(0.5, function() if IsValid(sc) then refresh() end end)
    end

    local b2 = block(sc, 96, "Персонаж:")
    local bChar = mkBtn(b2, "Меню персонажа (внешность)", C.acc)
    bChar:SetPos(10, 30) bChar:SetSize(250, 30)
    bChar.DoClick = function() if GRM.Char and GRM.Char.OpenMenu then GRM.Char.OpenMenu() end end
    local bDesc = mkBtn(b2, "Описание (RPDesc)", C.acc)
    bDesc:SetPos(10, 64) bDesc:SetSize(250, 30)
    bDesc.DoClick = function() if GRM.RPDesc and GRM.RPDesc.OpenEditor then GRM.RPDesc.OpenEditor() end end
    local descNow = (GRM.RPDesc and GRM.RPDesc.Get(lp)) or ""
    if #descNow > 60 then descNow = string.sub(descNow, 1, 60) .. "…" end
    local descLbl = vgui.Create("DLabel", b2)
    descLbl:SetPos(270, 56) descLbl:SetSize(600, 26)
    descLbl:SetFont("GRMF4_Normal") descLbl:SetTextColor(C.dim)
    descLbl:SetText("Описание сейчас: " .. (descNow ~= "" and descNow or "не задано"))

    local b3 = block(sc, 110, "Карточка:")
    infoRow(b3, "Steam-ник:", lp:Nick())
    infoRow(b3, "SteamID64:", lp:SteamID64())
    infoRow(b3, "RP-имя:", cur ~= "" and cur or "(не задано)")
    infoRow(b3, "Баланс наличных:", (GRM.Format and GRM.Format(GRM.LocalBalance or 0)) or tostring(GRM.LocalBalance or 0))

    local fac = "—"
    if istable(FactionsData) then
        for fname, fd in pairs(FactionsData) do
            if istable(fd) and istable(fd.Members) and (fd.Members[lp:SteamID()] or fd.Members[lp:SteamID64()]) then
                fac = fname break
            end
        end
    end
    infoRow(b3, "Фракция:", fac)
end

-----------------------------------------------------------
-- Вкладка «Команды»
-----------------------------------------------------------
local function buildCommandsTab(sc)
    for _, grp in ipairs(CMD_GROUPS) do
        local n = #grp.items
        local b = block(sc, 30 + n * 24 + 8, grp.name .. ":")
        for i, it in ipairs(grp.items) do
            local r = vgui.Create("DPanel", b)
            r:SetPos(10, 26 + (i - 1) * 24) r:SetSize(760, 22)
            r.Paint = function(_, pw, ph)
                draw.RoundedBox(3, 0, 0, 200, ph - 2, C.panel2)
                draw.SimpleText(it[1], "GRMF4_Small", 6, (ph - 2) / 2, C.acc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(it[2], "GRMF4_Normal", 210, ph / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
    end
end

-----------------------------------------------------------
-- Вкладка «Настройки»
-----------------------------------------------------------
local function buildSettingsTab(sc)
    local b = block(sc, 300, "Отображение HUD (только для вас):")

    local function toggle(y, cvar, label)
        local cv = GetConVar(cvar)
        local chk = vgui.Create("DCheckBoxLabel", b)
        chk:SetPos(14, y) chk:SetSize(500, 24)
        chk:SetText(label) chk:SetFont("GRMF4_Normal") chk:SetTextColor(C.text)
        chk:SetValue((not cv or cv:GetInt() ~= 0) and 1 or 0)
        chk.OnChange = function(_, v)
            RunConsoleCommand(cvar, v and "1" or "0")
        end
        return chk
    end

    toggle(30,  "grm_cl_rpdesc",     "Описания персонажей над головами (RPDesc)")
    toggle(58,  "grm_cl_doorhud",    "3D2D-таблички дверей (владелец/замок)")
    toggle(86,  "grm_cl_staminahud", "Полоса выносливости (стамина)")
    toggle(114, "grm_cl_foodhud",    "Полоса сытости (еда)")

    local lbl = vgui.Create("DLabel", b)
    lbl:SetPos(14, 146) lbl:SetSize(300, 22) lbl:SetFont("GRMF4_Sub") lbl:SetTextColor(C.text)
    lbl:SetText("Дистанция отрисовки RPDesc (юниты)")

    local sl = vgui.Create("DNumSlider", b)
    sl:SetPos(10, 168) sl:SetSize(420, 30)
    sl:SetMin(50) sl:SetMax(1000) sl:SetDecimals(0)
    sl:SetConVar("grm_cl_rpdesc_dist")

    local note = vgui.Create("DLabel", b)
    note:SetPos(14, 206) note:SetSize(700, 40)
    note:SetFont("GRMF4_Normal") note:SetTextColor(C.dim)
    note:SetText("Стандарт RPDesc — 200 юнитов (~5 метров). Настройки хранятся на вашем ПК (garrysmod/cfg).")
    note:SetWrap(true) note:SetAutoStretchVertical(true)
end

-----------------------------------------------------------
-- Главное окно
-----------------------------------------------------------
local function buildMenu()
    if IsValid(F4._frame) then F4._frame:Remove() end

    local f = vgui.Create("DFrame")
    F4._frame = f
    f:SetTitle("")
    f:SetSize(880, 640)
    f:Center()
    f:MakePopup()
    f:ShowCloseButton(false)
    f.Paint = function(_, pw, ph)
        draw.RoundedBox(8, 0, 0, pw, ph, C.bg)
        draw.RoundedBoxEx(8, 0, 0, pw, 46, C.head, true, true, false, false)
        draw.SimpleText("GRM — Игровое меню", "GRMF4_Title", 16, 23, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("F4 / /menu", "GRMF4_Normal", pw - 16, 23, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local x = vgui.Create("DButton", f)
    x:SetText("X") x:SetFont("GRMF4_Title") x:SetTextColor(color_white)
    x:SetPos(836, 8) x:SetSize(32, 28)
    x.DoClick = function() f:Close() end
    x.Paint = function(self, pw, ph) draw.RoundedBox(4, 0, 0, pw, ph, self:IsHovered() and C.red or Color(45, 52, 68)) end

    local sheet = vgui.Create("DPropertySheet", f)
    sheet:Dock(FILL)
    sheet:DockMargin(10, 52, 10, 10)

    -- Профиль (пересобирается для мгновенного обновления значений)
    local p1 = vgui.Create("DPanel")
    p1:SetPaintBackground(false)
    local sc1 = vgui.Create("DScrollPanel", p1)
    sc1:Dock(FILL)
    local function refreshProfile()
        if not IsValid(sc1) then return end
        sc1:Clear()
        buildProfileTab(sc1, refreshProfile)
    end
    refreshProfile()
    sheet:AddSheet("Профиль", p1, "icon16/user.png")

    local p2 = vgui.Create("DPanel")
    p2:SetPaintBackground(false)
    local sc2 = vgui.Create("DScrollPanel", p2)
    sc2:Dock(FILL)
    buildCommandsTab(sc2)
    sheet:AddSheet("Команды", p2, "icon16/book_open.png")

    local p3 = vgui.Create("DPanel")
    p3:SetPaintBackground(false)
    local sc3 = vgui.Create("DScrollPanel", p3)
    sc3:Dock(FILL)
    buildSettingsTab(sc3)
    sheet:AddSheet("Настройки", p3, "icon16/cog.png")
end

function F4.Open()
    buildMenu()
end

concommand.Add("grm_f4", F4.Open)

-- F4 (ShowSpare2): уступаем прицелу на дверь (там меню двери)
hook.Add("ShowSpare2", "GRM_F4_Open", function(ply)
    local tr = IsValid(ply) and ply:GetEyeTrace() or nil
    if tr and IsValid(tr.Entity) and GRM and GRM.Doors and GRM.Doors.IsDoor
        and GRM.Doors.IsDoor(tr.Entity)
        and tr.StartPos:DistToSqr(tr.HitPos) <= (GRM.Doors.Config and (GRM.Doors.Config.UseDistance or 180) or 180) ^ 2 then
        return -- двери откроют своё меню
    end
    if ply == LocalPlayer() then
        F4.Open()
        return true
    end
end)

hook.Add("PlayerSayTransform", "GRM_F4_Chat", function(ply, datapack)
    if ply ~= LocalPlayer() then return end
    local msg = datapack and datapack[1]
    if not msg then return end
    local low = string.lower(string.Trim(msg))
    if low == "/menu" or low == "!menu" or low == "/f4" or low == "!f4" then
        F4.Open()
        datapack[1] = ""
    end
end)

print("[GRM F4] Игровое меню v" .. F4.Version .. " загружено")
