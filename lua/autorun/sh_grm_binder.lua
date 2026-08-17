--[[--------------------------------------------------------------------
    GRM Binder v2.0.0 — бинды-последовательности для отыгровки

    Команды: /binder, /autobinder, /rpbinder, /бинды (и консольная grm_binder)

    ЧТО ЭТО. Слот = одна клавиша + СПИСОК ШАГОВ, которые выполняются по
    порядку со своими паузами. Один слот может быть целой сценой:

        [G]  шаг 1  чат:    /me исполнил воинское приветствие
             шаг 2  консоль: act salute

        [B]  шаг 1  чат: /dep Займу гос.волну, просьба не перебивать!
             шаг 2  чат: /gnews Уважаемые граждане, минуточку внимания!   (пауза 2 с)
             шаг 3  чат: /gnews В Корпус производится набор...            (пауза 4 с)
             шаг 4  чат: /gnews Требования — адекватный внешний вид...    (пауза 4 с)
             шаг 5  чат: /gnews С уважением, Генерал-Фельджандарм A.V.G!  (пауза 3 с)

    Возможности:
      * до 40 слотов, до 16 шагов в каждом;
      * шаг: тип «в чат» (say — работают /me, /do, /dep, /gnews, /fr) либо
        «в консоль» (act salute, +duck и т.п.) + собственная пауза ПЕРЕД ним;
      * порядок шагов меняется стрелками, любой шаг можно отключить;
      * клавиша на слот (DBinder), общая задержка старта, кулдаун, вкл/выкл;
      * связка со следующим слотом (цепочка сцен);
      * готовые ПРЕСЕТЫ: отыгровки, документы, служебные каналы —
        вставляются в слот одним кликом;
      * «Проверить» проигрывает сцену прямо из меню, «Стоп» гасит все
        отложенные шаги;
      * всё хранится локально в data/grm_binder.json.

    Безопасность и производительность:
      * бинды не срабатывают, пока открыт чат, консоль, меню игры или любое
        окно с курсором;
      * между шагами чата выдерживается минимальная пауза (антифлуд-защита
        сервера иначе просто съест часть строк);
      * цепочки защищены от зацикливания (глубина + список посещённых);
      * нажатие клавиши смотрит в таблицу «клавиша → слоты», а не перебирает
        все слоты (PlayerButtonDown зовётся на каждое нажатие).
----------------------------------------------------------------------]]

if SERVER then
    AddCSLuaFile()

    util.AddNetworkString("GRM_Binder_Open")

    -- Само меню клиентское, но команду перехватываем на сервере: иначе
    -- «/binder» уйдёт в общий чат. Ловим и PlayerSay, и PlayerSayTransform.
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
BD.Version = "2.0.0"

BD.MaxSlots      = 40
BD.DefaultSlots  = 20
BD.MaxSteps      = 16
BD.File          = "grm_binder.json"
BD.MaxChainDepth = 8
BD.MinChatGap    = 0.6   -- минимальная пауза между сообщениями в чат

surface.CreateFont("GRMBind_Title", { font = "Roboto", size = 21, weight = 800, extended = true })
surface.CreateFont("GRMBind_Head",  { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("GRMBind_Body",  { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("GRMBind_Small", { font = "Roboto", size = 12, weight = 400, extended = true })
surface.CreateFont("GRMBind_Memo",  { font = "Roboto", size = 15, weight = 700, extended = true })

local C = {
    bg     = Color(16, 20, 28, 252),
    head   = Color(12, 15, 22, 255),
    card   = Color(22, 28, 38, 245),
    step   = Color(27, 34, 46, 245),
    border = Color(38, 48, 66, 200),
    acc    = Color(65, 145, 235),
    green  = Color(55, 185, 110),
    gold   = Color(245, 195, 65),
    goldBg = Color(58, 46, 14, 250),
    red    = Color(225, 70, 70),
    violet = Color(170, 130, 235),
    text   = Color(240, 244, 250),
    dim    = Color(155, 170, 190),
    off    = Color(58, 66, 80),
}

local MEMO = "БИНДЕР служит упрощением отыгровки монотонных механик и выполнения определённых действий, " ..
             "но не может служить заменой полноценной отыгровки РП процесса!"

local function click(path)
    if GRM.Sound and GRM.Sound.UI then GRM.Sound.UI(path or "buttons/button15.wav")
    else surface.PlaySound(path or "buttons/button15.wav") end
end

-----------------------------------------------------------------------
-- Пресеты: готовые сцены в один клик
-----------------------------------------------------------------------
BD.Presets = {
    {
        group = "Отыгровка",
        name = "Воинское приветствие",
        key = "KEY_G",
        steps = {
            { mode = "chat",    text = "/me исполнил воинское приветствие", delay = 0 },
            { mode = "console", text = "act salute",                        delay = 0.2 },
        },
    },
    {
        group = "Отыгровка",
        name = "Представиться",
        steps = {
            { mode = "chat", text = "/me приложил руку к головному убору и представился", delay = 0 },
            { mode = "chat", text = "/do На груди виден служебный жетон.",                delay = 1.5 },
        },
    },
    {
        group = "Отыгровка",
        name = "Досмотр гражданина",
        steps = {
            { mode = "chat", text = "/me попросил гражданина предъявить документы",      delay = 0 },
            { mode = "chat", text = "/do Рука легла на планшет с бланками.",             delay = 1.5 },
            { mode = "chat", text = "/y Предъявите документы, пожалуйста!",              delay = 1.5 },
        },
    },
    {
        group = "Документы",
        name = "Показать удостоверение",
        steps = {
            { mode = "chat", text = "/me достал служебное удостоверение и раскрыл его", delay = 0 },
            { mode = "chat", text = "/showbadge",                                        delay = 1.2 },
        },
    },
    {
        group = "Документы",
        name = "Показать паспорт",
        steps = {
            { mode = "chat", text = "/me достал паспорт из внутреннего кармана", delay = 0 },
            { mode = "chat", text = "/showpassport",                              delay = 1.2 },
        },
    },
    {
        group = "Документы",
        name = "Показать права",
        steps = {
            { mode = "chat", text = "/me протянул водительское удостоверение", delay = 0 },
            { mode = "chat", text = "/showprava",                               delay = 1.2 },
        },
    },
    {
        group = "Документы",
        name = "Показать военный билет",
        steps = {
            { mode = "chat", text = "/me предъявил военный билет", delay = 0 },
            { mode = "chat", text = "/showmilitary",                delay = 1.2 },
        },
    },
    {
        group = "Документы",
        name = "Показать медкарту",
        steps = {
            { mode = "chat", text = "/me открыл медицинскую карту", delay = 0 },
            { mode = "chat", text = "/showmedcard",                  delay = 1.2 },
        },
    },
    {
        group = "Документы",
        name = "Мои документы (список)",
        steps = {
            { mode = "chat", text = "/myid",       delay = 0 },
            { mode = "chat", text = "/mypasport",  delay = 0.8 },
            { mode = "chat", text = "/mylicense",  delay = 0.8 },
        },
    },
    {
        group = "Служебные каналы",
        name = "Объявление по гос.волне",
        steps = {
            { mode = "chat", text = "/dep Займу гос.волну, просьба не перебивать!",              delay = 0 },
            { mode = "chat", text = "/gnews Уважаемые граждане, минуточку внимания!",            delay = 2 },
            { mode = "chat", text = "/gnews Текст объявления — замените на свой.",               delay = 4 },
            { mode = "chat", text = "/gnews С уважением, администрация организации.",            delay = 4 },
        },
    },
    {
        group = "Служебные каналы",
        name = "Набор в организацию",
        steps = {
            { mode = "chat", text = "/dep Займу гос.волну, просьба не перебивать!",                                   delay = 0 },
            { mode = "chat", text = "/gnews Уважаемые граждане, минуточку внимания!",                                 delay = 2 },
            { mode = "chat", text = "/gnews Производится набор в нашу организацию, ждём вас по адресу.",              delay = 4 },
            { mode = "chat", text = "/gnews Требования: адекватный внешний вид, паспорт, медкарта, диплом.",          delay = 4 },
            { mode = "chat", text = "/gnews С уважением, руководство организации!",                                   delay = 4 },
        },
    },
    {
        group = "Служебные каналы",
        name = "Доклад по рации",
        steps = {
            { mode = "chat", text = "/fr Приём, докладываю обстановку.", delay = 0 },
            { mode = "chat", text = "/frb (( свободен, могу подъехать ))", delay = 1.5 },
        },
    },
}

-----------------------------------------------------------------------
-- Данные
-----------------------------------------------------------------------
local function blankStep()
    return { mode = "chat", text = "", delay = 0, enabled = true }
end

local function blankSlot(i)
    return {
        id = i,
        name = "Слот " .. i,
        key = KEY_NONE,
        enabled = true,
        delay = 0,            -- задержка перед стартом сцены
        cooldown = 0.5,       -- личный кулдаун слота
        chain = 0,            -- id связанного слота (0 = нет)
        chainDelay = 1,
        steps = { blankStep() },
    }
end
BD.BlankSlot = blankSlot
BD.BlankStep = blankStep

BD.Slots = BD.Slots or {}
BD.KeyMap = BD.KeyMap or {}

local function slotHasWork(slot)
    for _, st in ipairs(slot.steps or {}) do
        if st.enabled ~= false and string.Trim(tostring(st.text or "")) ~= "" then return true end
    end
    return false
end

function BD.RebuildKeyMap()
    BD.KeyMap = {}
    for i = 1, BD.MaxSlots do
        local s = BD.Slots[i]
        if istable(s) and s.enabled and s.key and s.key > KEY_NONE and slotHasWork(s) then
            BD.KeyMap[s.key] = BD.KeyMap[s.key] or {}
            table.insert(BD.KeyMap[s.key], i)
        end
    end
end

-- Старый формат (одно действие на слот) читается и переводится в шаги.
local function normalizeSlot(row, i)
    local slot = blankSlot(i)
    slot.name = tostring(row.name or slot.name)
    slot.key = math.Clamp(math.floor(tonumber(row.key) or KEY_NONE), 0, 159)
    slot.enabled = row.enabled ~= false
    slot.delay = math.Clamp(tonumber(row.delay) or 0, 0, 60)
    slot.cooldown = math.Clamp(tonumber(row.cooldown) or 0.5, 0, 60)
    slot.chain = math.Clamp(math.floor(tonumber(row.chain) or 0), 0, BD.MaxSlots)
    slot.chainDelay = math.Clamp(tonumber(row.chainDelay) or 1, 0, 60)

    slot.steps = {}
    if istable(row.steps) and #row.steps > 0 then
        for _, st in ipairs(row.steps) do
            if istable(st) and #slot.steps < BD.MaxSteps then
                slot.steps[#slot.steps + 1] = {
                    mode = (st.mode == "console") and "console" or "chat",
                    text = tostring(st.text or ""),
                    delay = math.Clamp(tonumber(st.delay) or 0, 0, 60),
                    enabled = st.enabled ~= false,
                }
            end
        end
    elseif row.text and row.text ~= "" then
        -- миграция v1 → v2
        slot.steps[1] = {
            mode = (row.mode == "console") and "console" or "chat",
            text = tostring(row.text),
            delay = 0,
            enabled = true,
        }
    end
    if #slot.steps == 0 then slot.steps[1] = blankStep() end
    return slot
end

function BD.Load()
    BD.Slots = {}
    local raw = file.Read(BD.File, "DATA")
    local data = (raw and raw ~= "") and util.JSONToTable(raw) or nil
    if istable(data) then
        for _, row in ipairs(data) do
            if istable(row) then
                local i = math.Clamp(math.floor(tonumber(row.id) or 0), 0, BD.MaxSlots)
                if i > 0 then BD.Slots[i] = normalizeSlot(row, i) end
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
            local steps = {}
            for _, st in ipairs(s.steps or {}) do
                steps[#steps + 1] = { mode = st.mode, text = st.text, delay = st.delay, enabled = st.enabled }
            end
            arr[#arr + 1] = {
                id = i, name = s.name, key = s.key, enabled = s.enabled,
                delay = s.delay, cooldown = s.cooldown,
                chain = s.chain, chainDelay = s.chainDelay, steps = steps,
            }
        end
    end
    file.Write(BD.File, util.TableToJSON(arr, true))
    BD.RebuildKeyMap()
    return true
end

-----------------------------------------------------------------------
-- Выполнение сцены
-----------------------------------------------------------------------
local lastRun = {}
BD.Running = BD.Running or {}   -- id таймеров активных сцен

local function runStep(step)
    local text = string.Trim(tostring(step.text or ""))
    if text == "" then return false end
    if step.mode == "console" then
        LocalPlayer():ConCommand(text .. "\n")
    else
        RunConsoleCommand("say", text)
    end
    return true
end

function BD.StopAll()
    local n = 0
    for name in pairs(BD.Running) do
        if timer.Exists(name) then timer.Remove(name) end
        n = n + 1
    end
    BD.Running = {}
    return n
end

-- Проиграть сцену слота. depth/visited защищают цепочку слотов.
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

    -- Считаем абсолютное время каждого шага: пауза шага + минимальный
    -- интервал между сообщениями в чат (иначе антифлуд сервера съест строки).
    local at = math.Clamp(tonumber(slot.delay) or 0, 0, 60)
    local lastChatAt = -math.huge
    local seq = 0

    for _, step in ipairs(slot.steps or {}) do
        if step.enabled ~= false and string.Trim(tostring(step.text or "")) ~= "" then
            at = at + math.Clamp(tonumber(step.delay) or 0, 0, 60)
            if step.mode ~= "console" then
                if at - lastChatAt < BD.MinChatGap then at = lastChatAt + BD.MinChatGap end
                lastChatAt = at
            end
            seq = seq + 1
            local tname = ("GRM_Binder_%d_%d_%f"):format(index, seq, now)
            if at <= 0 then
                runStep(step)
            else
                BD.Running[tname] = true
                timer.Create(tname, at, 1, function()
                    BD.Running[tname] = nil
                    runStep(step)
                end)
            end
        end
    end

    local nextID = math.floor(tonumber(slot.chain) or 0)
    if nextID > 0 and nextID ~= index then
        local wait = math.max(at, 0) + math.Clamp(tonumber(slot.chainDelay) or 0, 0, 60)
        local tname = ("GRM_BinderChain_%d_%f"):format(index, now)
        BD.Running[tname] = true
        timer.Create(tname, wait, 1, function()
            BD.Running[tname] = nil
            BD.Run(nextID, depth + 1, visited, force)
        end)
    end
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

local function mkBtn(parent, label, col, onClick, font)
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
        draw.SimpleText(s.Label, font or "GRMBind_Body", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
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

-- Окно выбора пресета
local function openPresetPicker(onPick)
    local f = vgui.Create("DFrame")
    f:SetSize(560, 560) f:Center() f:MakePopup() f:ShowCloseButton(false) f:SetTitle("")
    f.Paint = function(_, w, h)
        draw.RoundedBox(7, 0, 0, w, h, C.bg)
        draw.RoundedBox(7, 0, 0, w, 44, C.head)
        surface.SetDrawColor(C.border.r, C.border.g, C.border.b, 255)
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText("ГОТОВЫЕ СЦЕНЫ", "GRMBind_Head", 16, 22, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    local close = vgui.Create("DButton", f)
    close:SetPos(f:GetWide() - 38, 8) close:SetSize(28, 28) close:SetText("✕")
    close:SetFont("GRMBind_Head") close:SetTextColor(C.dim)
    close.Paint = function(s, w, h) if s:IsHovered() then draw.RoundedBox(4, 0, 0, w, h, C.red) end end
    close.DoClick = function() f:Close() end

    local scroll = vgui.Create("DScrollPanel", f)
    scroll:Dock(FILL) scroll:DockMargin(12, 52, 12, 12)

    local lastGroup
    for _, preset in ipairs(BD.Presets) do
        if preset.group ~= lastGroup then
            lastGroup = preset.group
            local hdr = vgui.Create("DLabel", scroll)
            hdr:Dock(TOP) hdr:SetTall(24) hdr:DockMargin(0, 8, 0, 2)
            hdr:SetFont("GRMBind_Small") hdr:SetTextColor(C.acc)
            hdr:SetText("— " .. string.upper(preset.group))
        end
        local row = vgui.Create("DButton", scroll)
        row:Dock(TOP) row:SetTall(46) row:DockMargin(0, 0, 0, 4) row:SetText("")
        row.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and C.step or C.card)
            draw.SimpleText(preset.name, "GRMBind_Body", 12, 15, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText(#preset.steps .. " шаг(ов): " .. tostring(preset.steps[1].text):sub(1, 58),
                "GRMBind_Small", 12, 32, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        row.DoClick = function()
            click()
            onPick(preset)
            f:Close()
        end
    end
end

function BD.Open()
    if IsValid(frame) then frame:Remove() end
    BD.Load()

    frame = vgui.Create("DFrame")
    frame:SetSize(math.min(1120, ScrW() - 60), math.min(800, ScrH() - 60))
    frame:Center() frame:MakePopup() frame:ShowCloseButton(false) frame:SetTitle("")
    frame:SetDeleteOnClose(true)
    if GRM.UI and GRM.UI.Track then GRM.UI.Track("binder", frame) end

    frame.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, C.bg)
        draw.RoundedBox(8, 0, 0, w, 50, C.head)
        surface.SetDrawColor(C.border.r, C.border.g, C.border.b, C.border.a)
        surface.DrawOutlinedRect(0, 0, w, h)
        draw.SimpleText("БИНДЕР ДЕЙСТВИЙ", "GRMBind_Title", 18, 25, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Сцены из шагов • чат и консоль • паузы и последовательность • до " .. BD.MaxSlots .. " слотов",
            "GRMBind_Small", 240, 26, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local close = vgui.Create("DButton", frame)
    close:SetPos(frame:GetWide() - 42, 10) close:SetSize(30, 30) close:SetText("✕")
    close:SetFont("GRMBind_Head") close:SetTextColor(C.dim)
    close.Paint = function(s, w, h) if s:IsHovered() then draw.RoundedBox(4, 0, 0, w, h, C.red) end end
    close.DoClick = function() frame:Close() end

    local body = vgui.Create("DPanel", frame)
    body:Dock(FILL) body:DockMargin(12, 58, 12, 12) body:SetPaintBackground(false)

    -- ЗОЛОТИСТАЯ ПАМЯТКА (заказ владельца)
    local memo = vgui.Create("DPanel", body)
    memo:Dock(TOP) memo:SetTall(56) memo:DockMargin(0, 0, 0, 8)
    memo.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, C.goldBg)
        surface.SetDrawColor(C.gold.r, C.gold.g, C.gold.b, 220)
        surface.DrawOutlinedRect(0, 0, w, h, 2)
        draw.RoundedBox(2, 0, 0, 5, h, C.gold)
        draw.SimpleText("ПАМЯТКА", "GRMBind_Memo", 16, 16, C.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(MEMO, "GRMBind_Body", 16, 36, Color(250, 238, 205), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local hint = vgui.Create("DPanel", body)
    hint:Dock(TOP) hint:SetTall(44) hint:DockMargin(0, 0, 0, 8)
    hint.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, C.card)
        draw.SimpleText("Шаг «в чат» уходит как обычное сообщение — работают /me, /do, /dep, /gnews, /fr, /frb. Шаг «в консоль» — команды вроде act salute.",
            "GRMBind_Small", 14, 14, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Пауза указывается ПЕРЕД шагом; между сообщениями в чат автоматически держится минимум " .. BD.MinChatGap .. " с, чтобы антифлуд не съел строки.",
            "GRMBind_Small", 14, 30, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local scroll = vgui.Create("DScrollPanel", body)
    scroll:Dock(FILL)

    local footer = vgui.Create("DPanel", body)
    footer:Dock(BOTTOM) footer:SetTall(40) footer:DockMargin(0, 8, 0, 0) footer:SetPaintBackground(false)

    local rebuild

    local function stepRow(parent, slot, idx)
        local step = slot.steps[idx]
        local row = vgui.Create("DPanel", parent)
        row:Dock(TOP) row:SetTall(32) row:DockMargin(28, 0, 0, 3)
        row.Paint = function(_, w, h)
            draw.RoundedBox(5, 0, 0, w, h, C.step)
            draw.RoundedBox(2, 0, 0, 3, h, step.enabled ~= false
                and (step.mode == "console" and C.violet or C.green) or C.off)
            draw.SimpleText(idx .. ".", "GRMBind_Small", 12, h / 2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local modeBtn = mkBtn(row, step.mode == "console" and "КОНСОЛЬ" or "ЧАТ",
            step.mode == "console" and C.violet or C.green, function()
                step.mode = (step.mode == "console") and "chat" or "console"
                BD.Save() rebuild()
            end)
        modeBtn:SetPos(32, 4) modeBtn:SetSize(90, 24)

        local text = mkEntry(row,
            step.mode == "console" and "act salute" or "/me поправляет фуражку",
            step.text, function(v) step.text = v BD.Save() end)
        text:SetPos(128, 4) text:SetSize(520, 24)

        local delayLbl = vgui.Create("DLabel", row)
        delayLbl:SetPos(656, 6) delayLbl:SetSize(50, 20)
        delayLbl:SetFont("GRMBind_Small") delayLbl:SetTextColor(C.dim) delayLbl:SetText("пауза")

        local delay = vgui.Create("DNumberWang", row)
        delay:SetPos(700, 5) delay:SetSize(58, 22)
        delay:SetMin(0) delay:SetMax(60) delay:SetDecimals(1) delay:SetValue(step.delay or 0)
        delay.OnValueChanged = function(_, v) step.delay = tonumber(v) or 0 BD.Save() end

        local up = mkBtn(row, "▲", C.off, function()
            if idx > 1 then
                slot.steps[idx], slot.steps[idx - 1] = slot.steps[idx - 1], slot.steps[idx]
                BD.Save() rebuild()
            end
        end)
        up:SetPos(768, 4) up:SetSize(26, 24)

        local down = mkBtn(row, "▼", C.off, function()
            if idx < #slot.steps then
                slot.steps[idx], slot.steps[idx + 1] = slot.steps[idx + 1], slot.steps[idx]
                BD.Save() rebuild()
            end
        end)
        down:SetPos(798, 4) down:SetSize(26, 24)

        local onBtn = mkBtn(row, step.enabled ~= false and "вкл" or "выкл",
            step.enabled ~= false and C.green or C.off, function()
                step.enabled = not (step.enabled ~= false)
                BD.Save() rebuild()
            end)
        onBtn:SetPos(828, 4) onBtn:SetSize(52, 24)

        local del = mkBtn(row, "✕", C.red, function()
            table.remove(slot.steps, idx)
            if #slot.steps == 0 then slot.steps[1] = blankStep() end
            BD.Save() rebuild()
        end)
        del:SetPos(884, 4) del:SetSize(26, 24)
    end

    local function slotCard(slot)
        local steps = slot.steps or {}
        local card = vgui.Create("DPanel", scroll)
        card:Dock(TOP) card:SetTall(74 + #steps * 35 + 38) card:DockMargin(0, 0, 0, 8)
        card.Paint = function(_, w, h)
            draw.RoundedBox(6, 0, 0, w, h, C.card)
            draw.RoundedBox(2, 0, 0, 4, h, slot.enabled and C.acc or C.off)
            draw.SimpleText("#" .. slot.id, "GRMBind_Small", 14, 20, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local name = mkEntry(card, "название сцены", slot.name, function(v) slot.name = v BD.Save() end)
        name:SetPos(46, 10) name:SetSize(220, 26)

        local keyLbl = vgui.Create("DLabel", card)
        keyLbl:SetPos(276, 12) keyLbl:SetSize(60, 22)
        keyLbl:SetFont("GRMBind_Small") keyLbl:SetTextColor(C.dim) keyLbl:SetText("Клавиша:")

        local binder = vgui.Create("DBinder", card)
        binder:SetPos(338, 10) binder:SetSize(110, 26)
        binder:SetValue(slot.key or KEY_NONE)
        binder.OnChange = function(_, num) slot.key = math.floor(tonumber(num) or KEY_NONE) BD.Save() end

        local startLbl = vgui.Create("DLabel", card)
        startLbl:SetPos(458, 12) startLbl:SetSize(70, 22)
        startLbl:SetFont("GRMBind_Small") startLbl:SetTextColor(C.dim) startLbl:SetText("старт, с")

        local startW = vgui.Create("DNumberWang", card)
        startW:SetPos(516, 11) startW:SetSize(56, 24)
        startW:SetMin(0) startW:SetMax(60) startW:SetDecimals(1) startW:SetValue(slot.delay or 0)
        startW.OnValueChanged = function(_, v) slot.delay = tonumber(v) or 0 BD.Save() end

        local cdLbl = vgui.Create("DLabel", card)
        cdLbl:SetPos(582, 12) cdLbl:SetSize(70, 22)
        cdLbl:SetFont("GRMBind_Small") cdLbl:SetTextColor(C.dim) cdLbl:SetText("кулдаун")

        local cdW = vgui.Create("DNumberWang", card)
        cdW:SetPos(640, 11) cdW:SetSize(56, 24)
        cdW:SetMin(0) cdW:SetMax(60) cdW:SetDecimals(1) cdW:SetValue(slot.cooldown or 0.5)
        cdW.OnValueChanged = function(_, v) slot.cooldown = tonumber(v) or 0 BD.Save() end

        local onBtn = mkBtn(card, slot.enabled and "ВКЛ" or "ВЫКЛ", slot.enabled and C.green or C.off, function()
            slot.enabled = not slot.enabled BD.Save() rebuild()
        end)
        onBtn:SetPos(706, 10) onBtn:SetSize(64, 26)

        local testBtn = mkBtn(card, "Проверить", C.acc, function() BD.Run(slot.id, 1, {}, true) end)
        testBtn:SetPos(776, 10) testBtn:SetSize(92, 26)

        local presetBtn = mkBtn(card, "Сцена…", C.gold, function()
            openPresetPicker(function(preset)
                slot.name = preset.name
                slot.steps = {}
                for _, st in ipairs(preset.steps) do
                    slot.steps[#slot.steps + 1] = {
                        mode = st.mode, text = st.text, delay = st.delay or 0, enabled = true,
                    }
                end
                BD.Save() rebuild()
            end)
        end)
        presetBtn:SetPos(874, 10) presetBtn:SetSize(84, 26)

        local clearBtn = mkBtn(card, "Очистить", C.red, function()
            BD.Slots[slot.id] = blankSlot(slot.id)
            BD.Save() rebuild()
        end)
        clearBtn:SetPos(964, 10) clearBtn:SetSize(88, 26)

        local stepsHost = vgui.Create("DPanel", card)
        stepsHost:SetPos(0, 44) stepsHost:SetSize(card:GetWide(), #steps * 35 + 34)
        stepsHost:SetPaintBackground(false)
        stepsHost.PerformLayout = function(s) s:SetWide((s:GetParent():GetWide() or 0)) end

        for i = 1, #steps do stepRow(stepsHost, slot, i) end

        local addStep = mkBtn(stepsHost, "+ шаг", C.off, function()
            if #slot.steps >= BD.MaxSteps then
                chat.AddText(C.red, "[Биндер] ", C.text, "В сцене не больше " .. BD.MaxSteps .. " шагов.")
                return
            end
            slot.steps[#slot.steps + 1] = blankStep()
            BD.Save() rebuild()
        end)
        addStep:Dock(TOP) addStep:SetTall(26) addStep:DockMargin(28, 4, 620, 0)

        local chainLbl = vgui.Create("DLabel", card)
        chainLbl:SetPos(28, card:GetTall() - 30) chainLbl:SetSize(120, 20)
        chainLbl:SetFont("GRMBind_Small") chainLbl:SetTextColor(C.dim) chainLbl:SetText("Затем запустить слот:")

        local chainCombo = vgui.Create("DComboBox", card)
        chainCombo:SetPos(160, card:GetTall() - 32) chainCombo:SetSize(170, 22)
        chainCombo:SetFont("GRMBind_Small")
        chainCombo:AddChoice("— нет —", 0, (slot.chain or 0) == 0)
        for i = 1, BD.MaxSlots do
            local other = BD.Slots[i]
            if other and i ~= slot.id then
                chainCombo:AddChoice("#" .. i .. " " .. tostring(other.name or ""), i, slot.chain == i)
            end
        end
        chainCombo.OnSelect = function(_, _, _, id) slot.chain = math.floor(tonumber(id) or 0) BD.Save() end

        local chainDelayLbl = vgui.Create("DLabel", card)
        chainDelayLbl:SetPos(342, card:GetTall() - 30) chainDelayLbl:SetSize(110, 20)
        chainDelayLbl:SetFont("GRMBind_Small") chainDelayLbl:SetTextColor(C.dim) chainDelayLbl:SetText("через, с")

        local chainDelay = vgui.Create("DNumberWang", card)
        chainDelay:SetPos(404, card:GetTall() - 32) chainDelay:SetSize(56, 22)
        chainDelay:SetMin(0) chainDelay:SetMax(60) chainDelay:SetDecimals(1)
        chainDelay:SetValue(slot.chainDelay or 1)
        chainDelay.OnValueChanged = function(_, v) slot.chainDelay = tonumber(v) or 0 BD.Save() end
    end

    rebuild = function()
        local keep = 0
        if IsValid(scroll) and IsValid(scroll.VBar) then keep = scroll.VBar:GetScroll() end
        scroll:Clear()
        for i = 1, BD.MaxSlots do
            if BD.Slots[i] then slotCard(BD.Slots[i]) end
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
        BD.Save() rebuild()
    end)
    addBtn:Dock(LEFT) addBtn:SetWide(190)

    local stopBtn = mkBtn(footer, "СТОП (сбросить отложенные)", C.red, function()
        local n = BD.StopAll()
        chat.AddText(C.gold, "[Биндер] ", C.text, "Отменено отложенных шагов: " .. n)
    end)
    stopBtn:Dock(LEFT) stopBtn:SetWide(250) stopBtn:DockMargin(8, 0, 0, 0)

    local infoLbl = vgui.Create("DLabel", footer)
    infoLbl:Dock(FILL) infoLbl:DockMargin(12, 0, 12, 0)
    infoLbl:SetFont("GRMBind_Small") infoLbl:SetTextColor(C.dim)
    infoLbl:SetText("Сохраняется автоматически в data/grm_binder.json. Бинды молчат, когда открыт чат, консоль или меню.")

    local closeBtn = mkBtn(footer, "ЗАКРЫТЬ", C.off, function() frame:Close() end)
    closeBtn:Dock(RIGHT) closeBtn:SetWide(130)
end

-----------------------------------------------------------------------
-- Точки входа
-----------------------------------------------------------------------
concommand.Add("grm_binder", function() BD.Open() end)
concommand.Add("grm_binder_stop", function() BD.StopAll() end)

-- Открытие приходит с сервера: он же проглатывает команду из чата, поэтому
-- «/binder» не улетает всем в общий чат.
net.Receive("GRM_Binder_Open", function() BD.Open() end)

BD.Load()

print("[GRM Binder] v" .. BD.Version .. ": сцены из шагов, пресеты, /binder /autobinder /rpbinder")
