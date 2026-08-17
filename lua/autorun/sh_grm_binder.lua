--[[--------------------------------------------------------------------
    GRM Binder v1.0.0 — личные бинды действий

    Команды: /binder, /autobinder, /rpbinder, /бинды (и консольная grm_binder)

    Что умеет:
      * до 40 слотов (по умолчанию открыто 20, кнопка добавляет ещё);
      * два типа действия на слот:
          «в чат»     — отправляет строку как say (в т.ч. /me, /dep, /fr…);
          «в консоль» — выполняет консольную команду (можно несколько через ;);
      * своя клавиша выполнения на каждый слот (DBinder, любая клавиша);
      * СВЯЗКА: слот может дёрнуть другой слот через заданную паузу — так
        собираются цепочки «отыгровка + команда» одним нажатием;
      * задержка перед выполнением, персональный кулдаун, вкл/выкл слота;
      * кнопка «Проверить» выполняет слот прямо из меню;
      * всё хранится локально в data/grm_binder.json (у каждого игрока своё).

    Безопасность и производительность:
      * бинды не срабатывают, пока открыт чат, консоль, меню игры или любое
        окно с курсором — иначе набор текста сам себя выполнял бы;
      * цепочки защищены от зацикливания (глубина + список посещённых);
      * персональный кулдаун слота (по умолчанию 0.35 с) режет автоспам;
      * нажатие клавиши смотрит в таблицу «клавиша → слоты», а не перебирает
        все слоты (PlayerButtonDown зовётся на каждое нажатие в игре).
----------------------------------------------------------------------]]

if SERVER then
    AddCSLuaFile()

    util.AddNetworkString("GRM_Binder_Open")

    -- Само меню чисто клиентское, но команду надо перехватывать на сервере:
    -- иначе «/binder» уйдёт в общий чат и его увидят все. Ловим и в PlayerSay,
    -- и в PlayerSayTransform (EasyChat) — как принято во всей сборке.
    local CMDS = {
        ["/binder"] = true, ["!binder"] = true,
        ["/autobinder"] = true, ["!autobinder"] = true,
        ["/rpbinder"] = true, ["!rpbinder"] = true,
        ["/бинды"] = true, ["/биндер"] = true,
    }

    local function handleBinderChat(ply, text)
        if not IsValid(ply) then return false end
        local cmd = string.lower(string.Trim(tostring(text or "")))
        if not CMDS[cmd] then return false end
        net.Start("GRM_Binder_Open")
        net.Send(ply)
        return true
    end

    hook.Add("PlayerSay", "GRM_Binder_Chat", function(ply, text)
        if handleBinderChat(ply, text) then return "" end
    end)

    hook.Add("PlayerSayTransform", "GRM_Binder_ChatEC", function(ply, datapack)
        if not istable(datapack) or not isstring(datapack[1]) then return end
        if not handleBinderChat(ply, datapack[1]) then return end
        datapack[1] = ""
        datapack.SkipPlayerSay = true
    end)

    return
end

GRM = GRM or {}
GRM.Binder = GRM.Binder or {}
local BD = GRM.Binder
BD.Version = "1.0.0"

BD.MaxSlots      = 40
BD.DefaultSlots  = 20
BD.File          = "grm_binder.json"
BD.MaxChainDepth = 8

surface.CreateFont("GRMBind_Title", { font = "Roboto", size = 21, weight = 800, extended = true })
surface.CreateFont("GRMBind_Head",  { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("GRMBind_Body",  { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("GRMBind_Small", { font = "Roboto", size = 12, weight = 400, extended = true })

local C = {
    bg     = Color(16, 20, 28, 252),
    head   = Color(12, 15, 22, 255),
    card   = Color(22, 28, 38, 245),
    border = Color(38, 48, 66, 200),
    acc    = Color(65, 145, 235),
    green  = Color(55, 185, 110),
    gold   = Color(245, 195, 65),
    red    = Color(225, 70, 70),
    violet = Color(170, 130, 235),
    text   = Color(240, 244, 250),
    dim    = Color(155, 170, 190),
    off    = Color(58, 66, 80),
}

local function click(path)
    if GRM.Sound and GRM.Sound.UI then GRM.Sound.UI(path or "buttons/button15.wav")
    else surface.PlaySound(path or "buttons/button15.wav") end
end

-----------------------------------------------------------------------
-- Данные
-----------------------------------------------------------------------
local function blankSlot(i)
    return {
        id = i,
        name = "Слот " .. i,
        mode = "chat",        -- chat | console
        text = "",
        key = KEY_NONE,
        enabled = true,
        delay = 0,            -- задержка перед выполнением, сек
        cooldown = 0.35,      -- личный кулдаун слота, сек
        chain = 0,            -- id связанного слота (0 = нет)
        chainDelay = 0.5,     -- через сколько дёрнуть связанный слот
    }
end

BD.Slots = BD.Slots or {}
BD.KeyMap = BD.KeyMap or {}

-- Клавиша → список слотов: нажатие сразу берёт нужные, без перебора всех.
function BD.RebuildKeyMap()
    BD.KeyMap = {}
    for i = 1, BD.MaxSlots do
        local s = BD.Slots[i]
        if istable(s) and s.enabled and s.key and s.key > KEY_NONE and s.text ~= "" then
            BD.KeyMap[s.key] = BD.KeyMap[s.key] or {}
            table.insert(BD.KeyMap[s.key], i)
        end
    end
end

function BD.Load()
    BD.Slots = {}
    local raw = file.Read(BD.File, "DATA")
    local data = (raw and raw ~= "") and util.JSONToTable(raw) or nil
    if istable(data) then
        for _, row in ipairs(data) do
            if istable(row) then
                local i = math.Clamp(math.floor(tonumber(row.id) or 0), 0, BD.MaxSlots)
                if i > 0 then
                    local slot = blankSlot(i)
                    slot.name = tostring(row.name or slot.name)
                    slot.mode = (row.mode == "console") and "console" or "chat"
                    slot.text = tostring(row.text or "")
                    slot.key = math.Clamp(math.floor(tonumber(row.key) or KEY_NONE), 0, 159)
                    slot.enabled = row.enabled ~= false
                    slot.delay = math.Clamp(tonumber(row.delay) or 0, 0, 30)
                    slot.cooldown = math.Clamp(tonumber(row.cooldown) or 0.35, 0, 30)
                    slot.chain = math.Clamp(math.floor(tonumber(row.chain) or 0), 0, BD.MaxSlots)
                    slot.chainDelay = math.Clamp(tonumber(row.chainDelay) or 0.5, 0, 30)
                    BD.Slots[i] = slot
                end
            end
        end
    end
    local shown = BD.DefaultSlots
    for i = 1, BD.MaxSlots do if BD.Slots[i] then shown = math.max(shown, i) end end
    for i = 1, shown do
        if not BD.Slots[i] then BD.Slots[i] = blankSlot(i) end
    end
    BD.RebuildKeyMap()
    return BD.Slots
end

function BD.Save()
    local arr = {}
    for i = 1, BD.MaxSlots do
        local s = BD.Slots[i]
        if istable(s) then
            arr[#arr + 1] = {
                id = i, name = s.name, mode = s.mode, text = s.text, key = s.key,
                enabled = s.enabled, delay = s.delay, cooldown = s.cooldown,
                chain = s.chain, chainDelay = s.chainDelay,
            }
        end
    end
    file.Write(BD.File, util.TableToJSON(arr, true))
    BD.RebuildKeyMap()
    return true
end

-----------------------------------------------------------------------
-- Выполнение
-----------------------------------------------------------------------
local lastRun = {}

local function doAction(slot)
    local text = string.Trim(tostring(slot.text or ""))
    if text == "" then return false end
    if slot.mode == "console" then
        -- Несколько команд подряд разделяются точкой с запятой.
        LocalPlayer():ConCommand(text .. "\n")
    else
        -- say корректно уносит и обычный текст, и команды вида /me, /dep, /fr.
        RunConsoleCommand("say", text)
    end
    return true
end

-- Выполнить слот. depth/visited защищают от бесконечных цепочек.
function BD.Run(index, depth, visited, force)
    index = math.floor(tonumber(index) or 0)
    local slot = BD.Slots[index]
    if not istable(slot) then return false end
    if not force and not slot.enabled then return false end

    depth = depth or 1
    visited = visited or {}
    if depth > BD.MaxChainDepth or visited[index] then
        chat.AddText(C.red, "[Биндер] ", C.text, "Цепочка прервана: слишком длинная или зациклена.")
        return false
    end
    visited[index] = true

    local now = RealTime()
    if not force then
        local cd = tonumber(slot.cooldown) or 0
        if cd > 0 and (lastRun[index] or 0) + cd > now then return false end
    end
    lastRun[index] = now

    local function fire()
        doAction(slot)
        local nextID = math.floor(tonumber(slot.chain) or 0)
        if nextID > 0 and nextID ~= index then
            local wait = math.Clamp(tonumber(slot.chainDelay) or 0, 0, 30)
            timer.Simple(wait, function() BD.Run(nextID, depth + 1, visited, force) end)
        end
    end

    local delay = math.Clamp(tonumber(slot.delay) or 0, 0, 30)
    if delay > 0 then timer.Simple(delay, fire) else fire() end
    return true
end

-- Бинды не должны стрелять, когда игрок печатает или залез в меню.
local function inputBusy()
    if gui.IsGameUIVisible() or gui.IsConsoleVisible() then return true end
    if vgui.CursorVisible() then return true end
    local lp = LocalPlayer()
    if IsValid(lp) and lp.IsTyping and lp:IsTyping() then return true end
    return false
end

hook.Add("PlayerButtonDown", "GRM_Binder_Keys", function(ply, key)
    if ply ~= LocalPlayer() then return end
    local slots = BD.KeyMap[key]
    if not slots then return end
    if inputBusy() then return end
    for _, index in ipairs(slots) do BD.Run(index) end
end)

-----------------------------------------------------------------------
-- Меню
-----------------------------------------------------------------------
local frame

local function mkBtn(parent, label, col, onClick)
    local b = vgui.Create("DButton", parent)
    b:SetText("")
    b.Label = label
    b.Paint = function(s, w, h)
        local base = col or C.acc
        local c = s:IsHovered()
            and Color(math.min(255, base.r + 25), math.min(255, base.g + 25), math.min(255, base.b + 25))
            or base
        draw.RoundedBox(5, 0, 0, w, h, c)
        surface.SetDrawColor(255, 255, 255, 22)
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText(s.Label, "GRMBind_Body", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    b.DoClick = function() click() if onClick then onClick(b) end end
    return b
end

local function mkEntry(parent, placeholder, value, onChange)
    local e = vgui.Create("DTextEntry", parent)
    e:SetFont("GRMBind_Body")
    e:SetPlaceholderText(placeholder or "")
    e:SetText(tostring(value or ""))
    e:SetUpdateOnType(true)
    e.Paint = function(s, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(14, 18, 26))
        surface.SetDrawColor(C.border.r, C.border.g, C.border.b, 255)
        surface.DrawOutlinedRect(0, 0, w, h)
        s:DrawTextEntryText(C.text, C.acc, C.text)
        if s:GetText() == "" and not s:HasFocus() then
            draw.SimpleText(s:GetPlaceholderText() or "", "GRMBind_Small", 7, h / 2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
    end
    e.OnValueChange = function(_, v) if onChange then onChange(v) end end
    return e
end

function BD.Open()
    if IsValid(frame) then frame:Remove() end
    BD.Load()

    frame = vgui.Create("DFrame")
    frame:SetSize(math.min(1080, ScrW() - 80), math.min(760, ScrH() - 80))
    frame:Center() frame:MakePopup() frame:ShowCloseButton(false) frame:SetTitle("")
    frame:SetDeleteOnClose(true)
    if GRM.UI and GRM.UI.Track then GRM.UI.Track("binder", frame) end

    frame.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, C.bg)
        draw.RoundedBox(8, 0, 0, w, 50, C.head)
        surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText("БИНДЕР ДЕЙСТВИЙ", "GRMBind_Title", 18, 25, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Чат и консоль по клавише • связки действий • до " .. BD.MaxSlots .. " слотов",
            "GRMBind_Small", 240, 26, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", frame)
    close:SetPos(frame:GetWide() - 42, 10) close:SetSize(30, 30) close:SetText("✕")
    close:SetFont("GRMBind_Head") close:SetTextColor(C.dim)
    close.Paint = function(s, w, h) if s:IsHovered() then draw.RoundedBox(4, 0, 0, w, h, C.red) end end
    close.DoClick = function() frame:Close() end

    local body = vgui.Create("DPanel", frame)
    body:Dock(FILL) body:DockMargin(12, 58, 12, 12) body:SetPaintBackground(false)

    local hint = vgui.Create("DPanel", body)
    hint:Dock(TOP) hint:SetTall(50) hint:DockMargin(0, 0, 0, 8)
    hint.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, C.card)
        draw.SimpleText("«В чат» отправляет строку как обычное сообщение — работают и команды: /me, /dep, /fr, /roll.",
            "GRMBind_Small", 14, 15, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("«В консоль» выполняет консольную команду. «Связка» дёргает другой слот через паузу — так собирается цепочка.",
            "GRMBind_Small", 14, 33, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local scroll = vgui.Create("DScrollPanel", body)
    scroll:Dock(FILL)

    local footer = vgui.Create("DPanel", body)
    footer:Dock(BOTTOM) footer:SetTall(40) footer:DockMargin(0, 8, 0, 0) footer:SetPaintBackground(false)

    local rebuild

    local function slotRow(slot)
        local row = vgui.Create("DPanel", scroll)
        row:Dock(TOP) row:SetTall(92) row:DockMargin(0, 0, 0, 6)
        row.Paint = function(_, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            draw.RoundedBox(2, 0, 0, 4, h, slot.enabled and (slot.mode == "console" and C.violet or C.green) or C.off)
            draw.SimpleText("#" .. slot.id, "GRMBind_Small", 14, 16, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local name = mkEntry(row, "название бинда", slot.name, function(v) slot.name = v BD.Save() end)
        name:SetPos(46, 8) name:SetSize(190, 26)

        local modeBtn = mkBtn(row, slot.mode == "console" and "В КОНСОЛЬ" or "В ЧАТ",
            slot.mode == "console" and C.violet or C.green, function()
                slot.mode = (slot.mode == "console") and "chat" or "console"
                BD.Save()
                rebuild()
            end)
        modeBtn:SetPos(244, 8) modeBtn:SetSize(120, 26)

        local keyLbl = vgui.Create("DLabel", row)
        keyLbl:SetPos(376, 10) keyLbl:SetSize(60, 22)
        keyLbl:SetFont("GRMBind_Small") keyLbl:SetTextColor(C.dim) keyLbl:SetText("Клавиша:")

        local binder = vgui.Create("DBinder", row)
        binder:SetPos(438, 8) binder:SetSize(120, 26)
        binder:SetValue(slot.key or KEY_NONE)
        binder.OnChange = function(_, num)
            slot.key = math.floor(tonumber(num) or KEY_NONE)
            BD.Save()
        end

        local onBtn = mkBtn(row, slot.enabled and "ВКЛ" or "ВЫКЛ", slot.enabled and C.green or C.off, function()
            slot.enabled = not slot.enabled
            BD.Save()
            rebuild()
        end)
        onBtn:SetPos(566, 8) onBtn:SetSize(70, 26)

        local testBtn = mkBtn(row, "Проверить", C.acc, function() BD.Run(slot.id, 1, {}, true) end)
        testBtn:SetPos(644, 8) testBtn:SetSize(96, 26)

        local clearBtn = mkBtn(row, "Очистить", C.red, function()
            BD.Slots[slot.id] = blankSlot(slot.id)
            BD.Save()
            rebuild()
        end)
        clearBtn:SetPos(748, 8) clearBtn:SetSize(90, 26)

        local text = mkEntry(row,
            slot.mode == "console" and "например: +duck; wait 20; -duck" or "например: /me поправляет фуражку",
            slot.text, function(v) slot.text = v BD.Save() end)
        text:SetPos(46, 40) text:SetSize(792, 26)

        local function numField(x, label, value, minv, maxv, apply)
            local l = vgui.Create("DLabel", row)
            l:SetPos(x, 70) l:SetSize(120, 18)
            l:SetFont("GRMBind_Small") l:SetTextColor(C.dim) l:SetText(label)
            local w = vgui.Create("DNumberWang", row)
            w:SetPos(x + 92, 68) w:SetSize(62, 20)
            w:SetMin(minv) w:SetMax(maxv) w:SetDecimals(2) w:SetValue(value)
            w.OnValueChanged = function(_, v) apply(tonumber(v) or 0) BD.Save() end
        end

        numField(46, "Задержка, с", slot.delay or 0, 0, 30, function(v) slot.delay = v end)
        numField(214, "Кулдаун, с", slot.cooldown or 0.35, 0, 30, function(v) slot.cooldown = v end)

        local chainLbl = vgui.Create("DLabel", row)
        chainLbl:SetPos(382, 70) chainLbl:SetSize(110, 18)
        chainLbl:SetFont("GRMBind_Small") chainLbl:SetTextColor(C.dim) chainLbl:SetText("Связка со слотом:")

        local chainCombo = vgui.Create("DComboBox", row)
        chainCombo:SetPos(494, 68) chainCombo:SetSize(150, 20)
        chainCombo:SetFont("GRMBind_Small")
        chainCombo:AddChoice("— нет —", 0, (slot.chain or 0) == 0)
        for i = 1, BD.MaxSlots do
            local other = BD.Slots[i]
            if other and i ~= slot.id then
                chainCombo:AddChoice("#" .. i .. " " .. tostring(other.name or ""), i, slot.chain == i)
            end
        end
        chainCombo.OnSelect = function(_, _, _, id)
            slot.chain = math.floor(tonumber(id) or 0)
            BD.Save()
        end

        local delayLbl = vgui.Create("DLabel", row)
        delayLbl:SetPos(654, 70) delayLbl:SetSize(110, 18)
        delayLbl:SetFont("GRMBind_Small") delayLbl:SetTextColor(C.dim) delayLbl:SetText("пауза связки, с")

        local chainDelay = vgui.Create("DNumberWang", row)
        chainDelay:SetPos(770, 68) chainDelay:SetSize(62, 20)
        chainDelay:SetMin(0) chainDelay:SetMax(30) chainDelay:SetDecimals(2)
        chainDelay:SetValue(slot.chainDelay or 0.5)
        chainDelay.OnValueChanged = function(_, v) slot.chainDelay = tonumber(v) or 0 BD.Save() end

        return row
    end

    rebuild = function()
        local keep = 0
        if IsValid(scroll) and IsValid(scroll.VBar) then keep = scroll.VBar:GetScroll() end
        scroll:Clear()
        for i = 1, BD.MaxSlots do
            if BD.Slots[i] then slotRow(BD.Slots[i]) end
        end
        if keep > 0 then
            timer.Simple(0, function()
                if IsValid(scroll) and IsValid(scroll.VBar) then scroll.VBar:SetScroll(keep) end
            end)
        end
    end
    rebuild()

    local addBtn = mkBtn(footer, "+ ДОБАВИТЬ СЛОТ", C.acc, function()
        local n = 0
        for i = 1, BD.MaxSlots do if BD.Slots[i] then n = i end end
        if n >= BD.MaxSlots then
            chat.AddText(C.red, "[Биндер] ", C.text, "Достигнут предел в " .. BD.MaxSlots .. " слотов.")
            return
        end
        BD.Slots[n + 1] = blankSlot(n + 1)
        BD.Save()
        rebuild()
    end)
    addBtn:Dock(LEFT) addBtn:SetWide(200)

    local infoLbl = vgui.Create("DLabel", footer)
    infoLbl:Dock(FILL) infoLbl:DockMargin(12, 0, 12, 0)
    infoLbl:SetFont("GRMBind_Small") infoLbl:SetTextColor(C.dim)
    infoLbl:SetText("Сохраняется автоматически в data/grm_binder.json. Бинды молчат, когда открыт чат, консоль или меню.")

    local closeBtn = mkBtn(footer, "ЗАКРЫТЬ", C.off, function() frame:Close() end)
    closeBtn:Dock(RIGHT) closeBtn:SetWide(140)
end

-----------------------------------------------------------------------
-- Точки входа
-----------------------------------------------------------------------
concommand.Add("grm_binder", function() BD.Open() end)

-- Открытие приходит с сервера: он же проглатывает команду из чата, поэтому
-- «/binder» не улетает всем в общий чат.
net.Receive("GRM_Binder_Open", function() BD.Open() end)

BD.Load()

print("[GRM Binder] v" .. BD.Version .. ": /binder, /autobinder, /rpbinder — до " .. BD.MaxSlots .. " биндов")
