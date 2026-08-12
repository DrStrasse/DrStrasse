--[[--------------------------------------------------------------------
    GRM Education v1.0.0 — рабочее место учреждения образования

    ЗАЧЕМ ЭТОТ МОДУЛЬ СУЩЕСТВУЕТ
    ----------------------------
    Раньше диплом выписывали через банкомат. Это было неправильно:
    банкомат — это касса, а не деканат. Разделение ответственности:

      • БАНКОМАТ (sh_grm_atm.lua) — только деньги и справки:
        оплата обучения по счёту, проверка чужого диплома по номеру,
        просмотр своих дипломов. Выписывать бланки там больше нельзя.

      • УЧРЕЖДЕНИЕ ОБРАЗОВАНИЯ (этот модуль) — выписка бланков:
        вкладка «Учреждение образования» в меню фракций (F4/меню лидера)
        и отдельная сущность grm_comp_education — компьютер деканата.

    Кто и что может:
      • сотрудник учреждения (фракция с доступом canDiploma) — выписывать
        дипломы и видеть реестр своего учреждения;
      • руководитель учреждения — плюс аннулирование своих дипломов;
      • суперадмин — всё и по любому учреждению.

    Выпускник выбирается из РЕЕСТРА ПЕРСОНАЖЕЙ (GRM.Services.CharacterRegistry):
    онлайн, офлайн из паспортов и составов фракций. Диплом принадлежит
    персонажу (CharacterKey), а не сессии игрока.

    Данные модуль не хранит — источник истины остаётся
    data/grm_services/diplomas.json (sh_grm_diplomas.lua). Миграция не
    требуется: формат записей не менялся.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Education = GRM.Education or {}

local EDU = GRM.Education
EDU.Version = "1.0.0"

EDU.Config = EDU.Config or {
    UseRange     = 200,     -- дистанция до компьютера деканата
    RateLimit    = 0.35,    -- пауза между действиями, сек
    MaxDiplomas  = 200,     -- сколько записей реестра отдаём клиенту
    MaxCharacters= 400,     -- сколько персонажей отдаём в выбор выпускника
}

-----------------------------------------------------------------------
-- ОБЩЕЕ
-----------------------------------------------------------------------
local function money(v)
    if GRM.FormatMoney then return GRM.FormatMoney(v) end
    return string.Comma(math.floor(tonumber(v) or 0)) .. " GRM"
end

-----------------------------------------------------------------------
-- СЕРВЕР
-----------------------------------------------------------------------
if SERVER then

util.AddNetworkString("GRM_Edu_Open")     -- сервер -> клиент: снимок данных
util.AddNetworkString("GRM_Edu_Data")     -- сервер -> клиент: обновление
util.AddNetworkString("GRM_Edu_Act")      -- клиент -> сервер: действие
util.AddNetworkString("GRM_Edu_Result")   -- сервер -> клиент: итог
util.AddNetworkString("GRM_Edu_Request")  -- клиент -> сервер: дай данные

local nextAct = {}

local function result(ply, ok, msg)
    if not IsValid(ply) then return end
    net.Start("GRM_Edu_Result")
        net.WriteBool(ok and true or false)
        net.WriteString(tostring(msg or ""))
    net.Send(ply)
    if GRM.Notify then
        GRM.Notify(ply, tostring(msg or ""), ok and 120 or 255, ok and 220 or 140, ok and 150 or 120)
    end
end

--- Может ли игрок работать с рабочим местом учреждения.
-- Единый источник истины — GRM.Diplomas.CanIssue (доступ canDiploma
-- у фракции + байпас суперадмина). Своей копии прав здесь нет намеренно.
function EDU.CanUse(ply)
    local D = GRM.Diplomas
    if not D or not isfunction(D.CanIssue) then return false, nil, "Модуль дипломов не загружен" end
    return D.CanIssue(ply)
end

--- Снимок данных рабочего места.
function EDU.Snapshot(ply)
    local D, S = GRM.Diplomas, GRM.Services
    local can, fname = EDU.CanUse(ply)
    local isSuper = IsValid(ply) and ply:IsSuperAdmin()

    local snap = {
        canIssue    = can and true or false,
        isSuper     = isSuper and true or false,
        faction     = fname or "",
        institution = "",
        isLeader    = false,
        levels      = {},
        forms       = {},
        diplomas    = {},
        characters  = {},
        stats       = { total = 0, valid = 0, revoked = 0 },
    }

    if D then
        for _, l in ipairs(D.Levels or {}) do snap.levels[#snap.levels + 1] = { id = l.id, name = l.name } end
        for _, f in ipairs(D.Forms  or {}) do snap.forms[#snap.forms  + 1] = { id = f.id, name = f.name } end
        if fname and fname ~= "" and isfunction(D.InstitutionOf) then
            snap.institution = D.InstitutionOf(fname)
        end
    end

    if S and isfunction(S.IsLeaderOf) and fname then
        snap.isLeader = S.IsLeaderOf(ply, fname) and true or false
    end

    -- Реестр своего учреждения; суперадмину — весь реестр.
    if D then
        local list
        if isSuper and isfunction(D.Page) then
            list = D.Page({}, 0, EDU.Config.MaxDiplomas)
        elseif fname and isfunction(D.ByFaction) then
            list = D.ByFaction(fname, EDU.Config.MaxDiplomas)
        end
        for _, rec in ipairs(list or {}) do
            snap.diplomas[#snap.diplomas + 1] = {
                number = rec.number, graduate = rec.graduate, graduateName = rec.graduateName,
                institution = rec.institution, faction = rec.faction, specialty = rec.specialty,
                qualification = rec.qualification, level = rec.level, form = rec.form,
                grade = rec.grade, paid = rec.paid, invoiceID = rec.invoiceID,
                issued = rec.issued, revoked = rec.revoked, revokeReason = rec.revokeReason,
                issuerName = rec.issuerName, signedBy = rec.signedBy,
            }
            snap.stats.total = snap.stats.total + 1
            if rec.revoked then snap.stats.revoked = snap.stats.revoked + 1
            else snap.stats.valid = snap.stats.valid + 1 end
        end
    end

    -- Выпускники: персонажи, а не сессии (см. GRM.Services.CharacterRegistry)
    if S and isfunction(S.CharacterRegistry) then
        local n = 0
        for _, rec in ipairs(S.CharacterRegistry()) do
            snap.characters[#snap.characters + 1] = {
                key = rec.key, name = rec.name, faction = rec.faction, online = rec.online,
            }
            n = n + 1
            if n >= EDU.Config.MaxCharacters then break end
        end
    end

    return snap
end

--- Открыть рабочее место (по компьютеру деканата).
function EDU.Open(ply, ent)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    if IsValid(ent) and ply:GetPos():DistToSqr(ent:GetPos()) > (EDU.Config.UseRange ^ 2) then return end

    local can, _, why = EDU.CanUse(ply)
    if not can then
        if GRM.Notify then GRM.Notify(ply, why or "Нет доступа", 255, 150, 120)
        else ply:ChatPrint(why or "Нет доступа") end
        return
    end

    ply._grmEduEnt = IsValid(ent) and ent or nil
    net.Start("GRM_Edu_Open")
        net.WriteTable(EDU.Snapshot(ply))
    net.Send(ply)
end

--- Дослать свежие данные (после действия).
local function push(ply)
    if not IsValid(ply) then return end
    net.Start("GRM_Edu_Data")
        net.WriteTable(EDU.Snapshot(ply))
    net.Send(ply)
end
EDU.Push = push

-----------------------------------------------------------------------
-- Действия
-----------------------------------------------------------------------
local handlers = {}

handlers.issue = function(ply, a)
    local D = GRM.Diplomas
    if not D then return false, "Модуль дипломов не загружен" end
    local ok, res = D.Issue(ply, {
        graduate      = a.graduate,
        institution   = a.institution,
        specialty     = a.specialty,
        qualification = a.qualification,
        level         = a.level,
        form          = a.form,
        grade         = a.grade,
        paid          = a.paid == true,
        invoiceID     = a.invoiceID,
        signedBy      = a.signedBy,
        note          = a.note,
    })
    if not ok then return false, tostring(res) end
    return true, ("Диплом %s выдан: %s — %s")
        :format(res.number, tostring(res.graduateName), tostring(res.specialty))
end

handlers.revoke = function(ply, a)
    local D = GRM.Diplomas
    if not D then return false, "Модуль дипломов не загружен" end
    local ok, res = D.Revoke(ply, a.number, a.reason)
    if not ok then return false, tostring(res) end
    return true, ("Диплом %s аннулирован"):format(tostring(res.number))
end

handlers.check = function(ply, a)
    local D = GRM.Diplomas
    if not D then return false, "Модуль дипломов не загружен" end
    local rec = D.ByNumber(a.number)
    if not rec then return false, "Диплом с таким номером не найден" end
    return true, ("%s | %s | %s | %s | %s"):format(
        rec.number, tostring(rec.graduateName), tostring(rec.institution),
        tostring(rec.specialty), rec.revoked and "АННУЛИРОВАН" or "ДЕЙСТВИТЕЛЕН")
end

handlers.refresh = function() return true, "" end

--- Правка бланка: учреждение — свой диплом, суперадмин — любой.
handlers.edit = function(ply, a)
    local D = GRM.Diplomas
    if not D or not isfunction(D.Edit) then return false, "Правка недоступна" end
    local ok, res = D.Edit(ply, a.number, a.patch or {})
    if not ok then return false, tostring(res) end
    return true, ("Диплом %s изменён"):format(tostring(a.number))
end

net.Receive("GRM_Edu_Act", function(_, ply)
    if not IsValid(ply) then return end
    local action = net.ReadString()
    local args = net.ReadTable() or {}

    local now = CurTime()
    if (nextAct[ply] or 0) > now then return end
    nextAct[ply] = now + EDU.Config.RateLimit

    -- Если работа идёт от компьютера деканата — проверяем дистанцию.
    -- Из меню фракций сущности нет, тогда проверка не нужна.
    local ent = ply._grmEduEnt
    if IsValid(ent) and ply:GetPos():DistToSqr(ent:GetPos()) > (EDU.Config.UseRange ^ 2) then
        result(ply, false, "Вы отошли от рабочего места")
        return
    end

    local can, _, why = EDU.CanUse(ply)
    if not can then result(ply, false, why or "Нет доступа") return end

    local h = handlers[action]
    if not h then result(ply, false, "Неизвестная операция") return end

    local ok, msg = h(ply, args)
    if msg and msg ~= "" then result(ply, ok, msg) end
    push(ply)
end)

net.Receive("GRM_Edu_Request", function(_, ply)
    if not IsValid(ply) then return end
    local now = CurTime()
    if (nextAct[ply] or 0) > now then return end
    nextAct[ply] = now + EDU.Config.RateLimit
    -- Данные шлём всем, у кого есть доступ; вкладка сама решает, что рисовать.
    push(ply)
end)

hook.Add("PlayerDisconnected", "GRM_Edu_Cleanup", function(ply)
    nextAct[ply] = nil
end)

end -- SERVER

-----------------------------------------------------------------------
-- КЛИЕНТ
-----------------------------------------------------------------------
if CLIENT then

local snap = {}
EDU.Snap = snap

local UI = {
    bg     = Color(16, 22, 34, 250),
    panel  = Color(22, 30, 46, 245),
    panel2 = Color(26, 36, 54, 245),
    line   = Color(60, 80, 110, 200),
    text   = Color(232, 238, 248),
    muted  = Color(150, 168, 192),
    cyan   = Color(90, 180, 255),
    green  = Color(80, 200, 130),
    red    = Color(225, 90, 90),
    gold   = Color(245, 205, 80),
}
EDU.UI = UI

surface.CreateFont("GRM_Edu_Title", { font = "Roboto", size = 22, weight = 700, extended = true })
surface.CreateFont("GRM_Edu_Head",  { font = "Roboto", size = 18, weight = 600, extended = true })
surface.CreateFont("GRM_Edu_Body",  { font = "Roboto", size = 16, weight = 500, extended = true })
surface.CreateFont("GRM_Edu_Small", { font = "Roboto", size = 13, weight = 500, extended = true })

local function act(action, args)
    net.Start("GRM_Edu_Act")
        net.WriteString(action)
        net.WriteTable(args or {})
    net.SendToServer()
end
EDU.Act = act

local function dateOf(ts)
    ts = tonumber(ts) or 0
    if ts <= 0 then return "—" end
    return os.date("%d.%m.%Y", ts)
end

local function levelName(id)
    for _, l in ipairs(snap.levels or {}) do if l.id == id then return l.name end end
    return "—"
end

local function formName(id)
    for _, f in ipairs(snap.forms or {}) do if f.id == id then return f.name end end
    return "—"
end

-----------------------------------------------------------------------
-- Мелкие элементы
-----------------------------------------------------------------------
local function label(parent, text, font, col, x, y, w, h)
    local l = vgui.Create("DLabel", parent)
    l:SetText(text or "")
    l:SetFont(font or "GRM_Edu_Body")
    l:SetTextColor(col or UI.text)
    l:SetPos(x or 0, y or 0)
    l:SetSize(w or 200, h or 20)
    return l
end

local function button(parent, text, col, w, h)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b:SetSize(w or 120, h or 30)
    b.Paint = function(self, bw, bh)
        local c = self:IsHovered() and Color(col.r, col.g, col.b, 255) or Color(col.r, col.g, col.b, 190)
        draw.RoundedBox(4, 0, 0, bw, bh, c)
        draw.SimpleText(text, "GRM_Edu_Body", bw / 2, bh / 2, Color(12, 18, 28),
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    return b
end

local function entry(parent, placeholder, numeric, w, h)
    local e = vgui.Create("DTextEntry", parent)
    e:SetSize(w or 200, h or 28)
    e:SetFont("GRM_Edu_Body")
    e:SetPlaceholderText(placeholder or "")
    if numeric then e:SetNumeric(true) end
    e.Paint = function(self, ew, eh)
        draw.RoundedBox(4, 0, 0, ew, eh, Color(12, 20, 32, 245))
        surface.SetDrawColor(UI.line)
        surface.DrawOutlinedRect(0, 0, ew, eh, 1)
        self:DrawTextEntryText(UI.text, UI.cyan, UI.muted)
    end
    return e
end

local function combo(parent, placeholder, w, h)
    local c = vgui.Create("DComboBox", parent)
    c:SetSize(w or 200, h or 28)
    c:SetFont("GRM_Edu_Body")
    c:SetValue(placeholder or "")
    c:SetTextColor(UI.text)
    c.Paint = function(_, cw, ch)
        draw.RoundedBox(4, 0, 0, cw, ch, Color(12, 20, 32, 245))
        surface.SetDrawColor(UI.line)
        surface.DrawOutlinedRect(0, 0, cw, ch, 1)
    end
    return c
end

local function scroll(parent)
    local s = vgui.Create("DScrollPanel", parent)
    local bar = s:GetVBar()
    bar:SetWide(8)
    bar.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, Color(10, 18, 28, 200)) end
    bar.btnUp.Paint, bar.btnDown.Paint = function() end, function() end
    bar.btnGrip.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, UI.line) end
    return s
end

--- Карточка. Ширину НЕ фиксируем: раскладка идёт от фактической ширины
-- родителя в PerformLayout, поэтому содержимое не уезжает за правый край.
local function card(parent, h)
    local isScroll = istable(parent) and isfunction(parent.AddItem)
    local p = vgui.Create("DPanel", (not isScroll) and parent or nil)
    p:SetTall(h or 64)
    p:Dock(TOP) p:DockMargin(0, 0, 0, 6)
    p.Paint = function(_, w, ph)
        draw.RoundedBox(6, 0, 0, w, ph, UI.panel2)
        surface.SetDrawColor(UI.line)
        surface.DrawOutlinedRect(0, 0, w, ph, 1)
    end
    return p
end

local function empty(parent, text)
    local p = card(parent, 44)
    p.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(14, 24, 38, 200)) end
    label(p, text, "GRM_Edu_Body", UI.muted, 14, 12, 700, 20)
    return p
end

--- Выбор персонажа с поиском: онлайн и офлайн (паспорта, составы фракций).
local function charPicker(parent, placeholder, w)
    local p = vgui.Create("DPanel", parent)
    p:SetSize(w or 300, 56)
    p.Paint = function() end
    p._key = ""

    local find = vgui.Create("DTextEntry", p)
    find:SetPos(0, 0) find:SetSize(w or 300, 22)
    find:SetFont("GRM_Edu_Small")
    find:SetPlaceholderText("Поиск: имя, фракция или ключ...")
    find.Paint = function(self, ew, eh)
        draw.RoundedBox(4, 0, 0, ew, eh, Color(10, 16, 26, 240))
        surface.SetDrawColor(UI.line)
        surface.DrawOutlinedRect(0, 0, ew, eh, 1)
        self:DrawTextEntryText(UI.text, UI.cyan, UI.muted)
    end

    local list = vgui.Create("DComboBox", p)
    list:SetPos(0, 26) list:SetSize(w or 300, 28)
    list:SetFont("GRM_Edu_Body")
    list:SetValue(placeholder or "Выберите выпускника...")
    list:SetTextColor(UI.text)
    list.Paint = function(_, cw, ch)
        draw.RoundedBox(4, 0, 0, cw, ch, Color(12, 20, 32, 245))
        surface.SetDrawColor(UI.line)
        surface.DrawOutlinedRect(0, 0, cw, ch, 1)
    end

    local function fill(filter)
        filter = string.lower(string.Trim(filter or ""))
        list:Clear()
        list:SetValue(placeholder or "Выберите выпускника...")
        local shown = 0
        for _, ch in ipairs(snap.characters or {}) do
            local name = tostring(ch.name or ch.key or "")
            local fac  = tostring(ch.faction or "")
            local hay  = string.lower(name .. " " .. fac .. " " .. tostring(ch.key or ""))
            if filter == "" or string.find(hay, filter, 1, true) then
                local tail = fac ~= "" and ("  [" .. fac .. "]") or ""
                list:AddChoice((ch.online and "• " or "  ") .. name .. tail, ch.key)
                shown = shown + 1
                if shown >= 150 then break end
            end
        end
        if shown == 0 then list:SetValue("Ничего не найдено") end
    end
    fill("")

    find.OnChange = function(self) fill(self:GetValue()) end
    list.OnSelect = function(_, _, _, data) p._key = tostring(data or "") end

    p.GetKey = function(self) return self._key or "" end
    p.SetKey = function(self, k) self._key = tostring(k or "") end
    p.Reload = function(self) fill(find:GetValue()) end
    p.PerformLayout = function(_, pw)
        find:SetSize(pw, 22)
        list:SetSize(pw, 28)
    end
    return p
end
EDU.CharPicker = charPicker

-----------------------------------------------------------------------
-- Панель рабочего места (используется и во фракциях, и в компьютере)
-----------------------------------------------------------------------
--- Строит содержимое рабочего места внутри переданной панели.
-- Возвращает функцию перерисовки: её зовут при получении новых данных.
function EDU.BuildWorkspace(parent)
    if not IsValid(parent) then return function() end end

    local sheet = vgui.Create("DPropertySheet", parent)
    sheet:Dock(FILL)
    sheet:DockMargin(8, 8, 8, 8)
    sheet:SetFadeTime(0)
    sheet.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(0, 0, 0, 0)) end

    local pIssue = vgui.Create("DPanel", sheet) pIssue.Paint = function() end
    local pReg   = vgui.Create("DPanel", sheet) pReg.Paint = function() end
    local pCheck = vgui.Create("DPanel", sheet) pCheck.Paint = function() end
    sheet:AddSheet("Выписать диплом", pIssue, "icon16/page_white_edit.png")
    sheet:AddSheet("Реестр учреждения", pReg, "icon16/book.png")
    sheet:AddSheet("Проверка", pCheck, "icon16/magnifier.png")

    -- ============================ ВЫПИСКА ============================
    local scIssue = scroll(pIssue) scIssue:Dock(FILL)

    local function buildIssue()
        scIssue:Clear()

        if not (snap.canIssue or snap.isSuper) then
            scIssue:AddItem(empty(scIssue,
                "Вашей организации не выдан доступ на выдачу дипломов. Доступ включает суперадмин."))
            return
        end

        local head = card(scIssue, 58)
        label(head, "БЛАНК ГОСУДАРСТВЕННОГО ДИПЛОМА", "GRM_Edu_Head", UI.gold, 14, 10, 420, 22)
        local sub = label(head, ("Учреждение: %s"):format(
            tostring(snap.institution ~= "" and snap.institution or snap.faction or "—")),
            "GRM_Edu_Small", UI.muted, 14, 34, 500, 16)
        head.PerformLayout = function(_, w) sub:SetSize(math.max(200, w - 28), 16) end
        scIssue:AddItem(head)

        -- Форма. Раскладка в PerformLayout: две колонки от фактической ширины,
        -- высота карточки считается по факту (иначе нижний ряд с кнопкой
        -- «ВЫДАТЬ ДИПЛОМ» уезжал за край карточки и обрезался VGUI).
        local f = card(scIssue, 360)

        local lInst = label(f, "Учреждение образования", "GRM_Edu_Small", UI.muted, 14, 12, 260, 14)
        local inst  = entry(f, "Название учреждения...", false, 300, 28)
        inst:SetParent(f)
        inst:SetValue(tostring(snap.institution ~= "" and snap.institution or (snap.faction or "")))

        local lGrad = label(f, "Выпускник (в том числе офлайн)", "GRM_Edu_Small", UI.muted, 14, 12, 300, 14)
        local grad  = charPicker(f, "Выберите выпускника...", 300)
        grad:SetParent(f)

        local lSpec = label(f, "Специальность", "GRM_Edu_Small", UI.muted, 14, 12, 260, 14)
        local spec  = entry(f, "Например: юриспруденция", false, 300, 28)
        spec:SetParent(f)

        local lQual = label(f, "Квалификация", "GRM_Edu_Small", UI.muted, 14, 12, 260, 14)
        local qual  = entry(f, "Например: юрист", false, 300, 28)
        qual:SetParent(f)

        local lLvl = label(f, "Уровень образования", "GRM_Edu_Small", UI.muted, 14, 12, 260, 14)
        local lvl  = combo(f, "Уровень...", 300, 28)
        lvl:SetParent(f)
        for _, l in ipairs(snap.levels or {}) do lvl:AddChoice(l.name, l.id) end

        local lFrm = label(f, "Форма обучения", "GRM_Edu_Small", UI.muted, 14, 12, 260, 14)
        local frm  = combo(f, "Форма...", 300, 28)
        frm:SetParent(f)
        for _, l in ipairs(snap.forms or {}) do frm:AddChoice(l.name, l.id) end

        local lGrade = label(f, "Оценка / отличие", "GRM_Edu_Small", UI.muted, 14, 12, 260, 14)
        local grade  = entry(f, "отлично / с отличием", false, 300, 28)
        grade:SetParent(f)

        local lSign = label(f, "Подпись (должностное лицо)", "GRM_Edu_Small", UI.muted, 14, 12, 260, 14)
        local sign  = entry(f, "Оставьте пустым — подставится ваш ник", false, 300, 28)
        sign:SetParent(f)

        local paidChk = vgui.Create("DCheckBoxLabel", f)
        paidChk:SetSize(240, 20)
        paidChk:SetText("Обучение было платным")
        paidChk:SetFont("GRM_Edu_Small")
        paidChk:SetTextColor(UI.muted)

        local lInv = label(f, "Счёт об оплате (№, необязательно)", "GRM_Edu_Small", UI.muted, 14, 12, 300, 14)
        local invID = entry(f, "№ счёта", true, 140, 28)
        invID:SetParent(f)

        local bIssue = button(f, "ВЫДАТЬ ДИПЛОМ", UI.green, 200, 32)
        bIssue:SetParent(f)

        local hint = label(f, "Счёт должен быть оплачен, иначе бланк не выдаётся. Оплата — в банкомате.",
            "GRM_Edu_Small", UI.muted, 14, 12, 460, 16)

        -- Вся раскладка — от фактической ширины карточки (правый край не режется)
        f.PerformLayout = function(self, w)
            local pad, gap = 14, 12
            local colW = math.max(160, math.floor((w - pad * 2 - gap) / 2))
            local xL, xR = pad, pad + colW + gap
            local y = 12

            local function row(lLeft, cLeft, lRight, cRight, hCtl)
                lLeft:SetPos(xL, y) lLeft:SetSize(colW, 14)
                if lRight then lRight:SetPos(xR, y) lRight:SetSize(colW, 14) end
                cLeft:SetPos(xL, y + 16) cLeft:SetSize(colW, hCtl or 28)
                if cRight then cRight:SetPos(xR, y + 16) cRight:SetSize(colW, hCtl or 28) end
                y = y + 16 + (hCtl or 28) + 10
            end

            -- выпускник — панель на 56px, поэтому строка выше
            lInst:SetPos(xL, y) lInst:SetSize(colW, 14)
            lGrad:SetPos(xR, y) lGrad:SetSize(colW, 14)
            inst:SetPos(xL, y + 16) inst:SetSize(colW, 28)
            grad:SetPos(xR, y + 16) grad:SetSize(colW, 56)
            y = y + 16 + 56 + 10

            row(lSpec, spec, lQual, qual)
            row(lLvl, lvl, lFrm, frm)
            row(lGrade, grade, lSign, sign)

            paidChk:SetPos(xL, y + 4) paidChk:SetSize(colW, 20)
            lInv:SetPos(xR, y) lInv:SetSize(colW, 14)
            invID:SetPos(xR, y + 16) invID:SetSize(math.min(160, colW), 28)
            y = y + 16 + 28 + 10

            bIssue:SetPos(xL, y) bIssue:SetSize(math.min(220, colW), 32)
            hint:SetPos(xR, y + 8) hint:SetSize(colW, 16)

            -- Высота — по фактическому содержимому. Без этого нижний ряд
            -- (кнопка выдачи) оказывался ниже границы карточки и не рисовался.
            local need = y + 32 + 14
            if math.abs((self:GetTall() or 0) - need) > 1 then self:SetTall(need) end
        end

        bIssue.DoClick = function()
            local gkey = grad:GetKey()
            if gkey == "" then
                notification.AddLegacy("Выберите выпускника", NOTIFY_ERROR, 3)
                surface.PlaySound("buttons/button10.wav")
                return
            end
            if string.Trim(spec:GetValue() or "") == "" then
                notification.AddLegacy("Укажите специальность", NOTIFY_ERROR, 3)
                return
            end
            local _, lid = lvl:GetSelected()
            local _, fid = frm:GetSelected()
            act("issue", {
                graduate = gkey,
                institution = inst:GetValue(),
                specialty = spec:GetValue(),
                qualification = qual:GetValue(),
                level = lid or "course",
                form = fid or "full",
                grade = grade:GetValue(),
                signedBy = sign:GetValue(),
                paid = paidChk:GetChecked(),
                invoiceID = tonumber(invID:GetValue()) or 0,
            })
            spec:SetValue("") qual:SetValue("") grade:SetValue("") invID:SetValue("")
        end

        scIssue:AddItem(f)
    end

    -- ============================ РЕЕСТР ============================
    local topReg = vgui.Create("DPanel", pReg)
    topReg:Dock(TOP) topReg:SetTall(38) topReg.Paint = function() end
    local search = entry(topReg, "Поиск: номер, ФИО, специальность...", false, 320, 28)
    search:SetParent(topReg) search:SetPos(0, 4)
    local scReg = scroll(pReg) scReg:Dock(FILL)

    local function buildReg()
        scReg:Clear()
        local q = string.lower(string.Trim(search:GetValue() or ""))
        local stat = card(scReg, 40)
        label(stat, ("Всего: %d    Действительных: %d    Аннулированных: %d")
            :format(snap.stats and snap.stats.total or 0,
                    snap.stats and snap.stats.valid or 0,
                    snap.stats and snap.stats.revoked or 0),
            "GRM_Edu_Body", UI.cyan, 14, 10, 600, 20)
        scReg:AddItem(stat)

        local shown = 0
        for _, d in ipairs(snap.diplomas or {}) do
            local hay = string.lower(table.concat({
                d.number or "", d.graduateName or "", d.specialty or "",
                d.institution or "", d.qualification or "" }, " "))
            if q == "" or string.find(hay, q, 1, true) then
                shown = shown + 1
                local c = card(scReg, 92)
                local col = d.revoked and UI.red or UI.text
                local lNum  = label(c, tostring(d.number or ""), "GRM_Edu_Head", col, 14, 8, 240, 20)
                local lName = label(c, tostring(d.graduateName or "?"), "GRM_Edu_Body", UI.cyan, 14, 30, 320, 18)
                local lSpec = label(c, ("%s | %s | %s"):format(
                    tostring(d.specialty or "—"), levelName(d.level), formName(d.form)),
                    "GRM_Edu_Small", UI.muted, 14, 50, 420, 16)
                local lMore = label(c, ("Выдал: %s    %s    %s"):format(
                    tostring(d.issuerName or "—"), dateOf(d.issued),
                    d.paid and "платно" or "бесплатно"), "GRM_Edu_Small", UI.muted, 14, 68, 420, 16)
                local lStat = label(c, d.revoked and "АННУЛИРОВАН" or "ДЕЙСТВИТЕЛЕН",
                    "GRM_Edu_Small", d.revoked and UI.red or UI.green, 0, 10, 150, 16)

                local bRev
                if (snap.isLeader or snap.isSuper) and not d.revoked then
                    bRev = button(c, "Аннулировать", UI.red, 150, 26)
                    bRev:SetParent(c)
                    bRev.DoClick = function()
                        Derma_StringRequest("Аннулирование диплома",
                            ("Причина аннулирования %s:"):format(tostring(d.number)), "",
                            function(txt) act("revoke", { number = d.number, reason = txt }) end)
                    end
                end

                c.PerformLayout = function(_, w)
                    local right = math.max(160, w - 170)
                    lNum:SetSize(math.max(120, right - 20), 20)
                    lName:SetSize(math.max(120, right - 20), 18)
                    lSpec:SetSize(math.max(120, right - 20), 16)
                    lMore:SetSize(math.max(120, right - 20), 16)
                    lStat:SetPos(w - 158, 10) lStat:SetSize(150, 16)
                    if IsValid(bRev) then bRev:SetPos(w - 164, 52) bRev:SetSize(150, 26) end
                end
                scReg:AddItem(c)
            end
        end
        if shown == 0 then
            scReg:AddItem(empty(scReg, q == "" and "Реестр пуст: дипломы ещё не выдавались."
                or "По запросу ничего не найдено."))
        end
    end
    search.OnChange = function() timer.Simple(0, buildReg) end

    -- ============================ ПРОВЕРКА ============================
    local scChk = scroll(pCheck) scChk:Dock(FILL)
    local function buildCheck()
        scChk:Clear()
        local c = card(scChk, 96)
        label(c, "ПРОВЕРКА ДИПЛОМА ПО ЕДИНОМУ РЕЕСТРУ", "GRM_Edu_Small", UI.muted, 14, 10, 420, 16)
        local num = entry(c, "Номер бланка, например ГД-2026-000123", false, 340, 30)
        num:SetParent(c) num:SetPos(14, 34)
        local b = button(c, "Проверить", UI.cyan, 150, 30)
        b:SetParent(c)
        local hint = label(c, "Результат придёт уведомлением и в чат.", "GRM_Edu_Small", UI.muted, 14, 70, 420, 16)
        b.DoClick = function()
            local v = string.Trim(num:GetValue() or "")
            if v == "" then return end
            act("check", { number = v })
        end
        c.PerformLayout = function(_, w)
            num:SetSize(math.max(160, w - 190), 30)
            b:SetPos(w - 164, 34)
            hint:SetSize(math.max(160, w - 28), 16)
        end
        scChk:AddItem(c)
    end

    local function rebuild()
        if not IsValid(parent) then return end
        buildIssue() buildReg() buildCheck()
    end
    rebuild()
    return rebuild
end

-----------------------------------------------------------------------
-- Вкладка в меню фракций
-----------------------------------------------------------------------
local factionRebuild
hook.Add("GRM_FactionsAdmin_BuildTabs", "GRM_Edu_FactionTab", function(tabs)
    if not IsValid(tabs) then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    -- Вкладку видит только тот, кому есть что делать: сотрудник учреждения
    -- с доступом или суперадмин. Право проверяет сервер, здесь — только
    -- предварительный показ по последнему снимку.
    local panel = vgui.Create("DPanel")
    panel:SetPaintBackground(false)
    tabs:AddSheet("Учреждение образования", panel, "icon16/user_suit.png")

    local rebuild = EDU.BuildWorkspace(panel)
    factionRebuild = function()
        if IsValid(panel) then rebuild() end
    end

    net.Start("GRM_Edu_Request") net.SendToServer()
    timer.Simple(0.6, function() if IsValid(panel) then rebuild() end end)
end)

-----------------------------------------------------------------------
-- Приём данных
-----------------------------------------------------------------------
local function applySnap(t)
    table.Empty(snap)
    for k, v in pairs(t or {}) do snap[k] = v end
end

net.Receive("GRM_Edu_Data", function()
    applySnap(net.ReadTable())
    if isfunction(factionRebuild) then pcall(factionRebuild) end
    if isfunction(EDU._computerRebuild) then pcall(EDU._computerRebuild) end
end)

net.Receive("GRM_Edu_Result", function()
    local ok = net.ReadBool()
    local msg = net.ReadString()
    if msg == "" then return end
    notification.AddLegacy(msg, ok and NOTIFY_GENERIC or NOTIFY_ERROR, 6)
    surface.PlaySound(ok and "buttons/button14.wav" or "buttons/button10.wav")
end)

-----------------------------------------------------------------------
-- Отдельное окно рабочего места (компьютер деканата)
-----------------------------------------------------------------------
function EDU.OpenFrame()
    local W, H = 940, 660
    local frame = vgui.Create("DFrame")
    frame:SetSize(W, H)
    frame:Center()
    frame:SetTitle("")
    frame:MakePopup()
    frame:ShowCloseButton(false)
    frame.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, UI.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 44, UI.panel, true, true, false, false)
        draw.SimpleText("УЧРЕЖДЕНИЕ ОБРАЗОВАНИЯ — РАБОЧЕЕ МЕСТО", "GRM_Edu_Title", 16, 22,
            UI.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(tostring(snap.institution ~= "" and snap.institution or (snap.faction or "")),
            "GRM_Edu_Small", w - 52, 22, UI.muted, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", frame)
    close:SetSize(30, 26) close:SetPos(W - 40, 9) close:SetText("")
    close.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, self:IsHovered() and UI.red or Color(50, 62, 84))
        draw.SimpleText("X", "GRM_Edu_Body", w / 2, h / 2, UI.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    close.DoClick = function() frame:Close() end

    local body = vgui.Create("DPanel", frame)
    body:SetPos(0, 44) body:SetSize(W, H - 44)
    body.Paint = function() end

    local rebuild = EDU.BuildWorkspace(body)
    EDU._computerRebuild = function() if IsValid(frame) then rebuild() end end
    frame.OnRemove = function() EDU._computerRebuild = nil end
    return frame
end

net.Receive("GRM_Edu_Open", function()
    applySnap(net.ReadTable())
    EDU.OpenFrame()
end)

end -- CLIENT
