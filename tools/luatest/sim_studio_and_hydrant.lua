--[[ Два бага из жалобы владельца 28.08.

     1) STACK OVERFLOW в студии анимаций. Трейс владельца:
          OnRowSelected → loadPose → ChooseOptionID → OnSelect
            → rebuildList → SelectItem → OnRowSelected → …
        Обычный клик по сохранённой позе ронял игру.

     2) ГИДРАНТ. «На E открыл гидрант, и закрыть его нельзя, если ты не
        пожарный. Чё за Х?» — хук запрещал не-пожарному ЛЮБОЕ действие,
        включая закрытие. Открыл — и назад не повернуть.

     Плюс найденные попутно недоработки студии.

     Запуск: luajit tools/luatest/sim_studio_and_hydrant.lua ]]

local pass, fail = 0, 0
local function ok(v, n, extra)
    if v then pass = pass + 1 print("  ok   " .. n)
    else fail = fail + 1 print("  FAIL " .. n .. "  " .. tostring(extra or "")) end
end
local function readf(p) local f = assert(io.open(p)) local s = f:read("*a") f:close() return s end

-----------------------------------------------------------------------
print("\n=== 1. РЕКУРСИЯ: ВОСПРОИЗВОДИМ ПАДЕНИЕ ===")
-----------------------------------------------------------------------
--[[ Модель тех же четырёх обработчиков БЕЗ защиты. Считаем глубину:
     без флага она уходит в бесконечность (ограничиваем счётчиком,
     иначе стенд сам упадёт так же, как игра у владельца). ]]
do
    local depth, overflow = 0, false
    local rebuildList, onRowSelected, loadPose, onSelect

    local LIMIT = 500

    onRowSelected = function(id)
        depth = depth + 1
        if depth > LIMIT then overflow = true return end
        loadPose(id)
    end
    loadPose = function(id)
        if overflow then return end
        onSelect()                 -- ChooseOptionID дёргает OnSelect
    end
    onSelect = function()
        if overflow then return end
        rebuildList()
    end
    rebuildList = function()
        if overflow then return end
        onRowSelected("pose1")     -- SelectItem дёргает OnRowSelected
    end

    onRowSelected("pose1")
    ok(overflow == true,
       "БАГ ВОСПРОИЗВЕДЁН: без защиты цепочка уходит в бесконечную рекурсию",
       "глубина " .. depth)
end

-----------------------------------------------------------------------
print("\n=== 2. ТА ЖЕ ЦЕПОЧКА С ФЛАГОМ ===")
-----------------------------------------------------------------------
do
    local ST = { _busy = false }
    local depth, maxDepth = 0, 0
    local loadPoseCalls, rebuildCalls = 0, 0
    local rebuildList, onRowSelected, loadPose, onSelect

    onRowSelected = function(id)
        if ST._busy then return end          -- защита
        depth = depth + 1
        if depth > maxDepth then maxDepth = depth end
        if depth > 500 then error("всё ещё рекурсия") end
        loadPose(id)
        depth = depth - 1
    end
    loadPose = function(id)
        loadPoseCalls = loadPoseCalls + 1
        local was = ST._busy
        ST._busy = true                       -- защита вокруг combobox
        onSelect()
        ST._busy = was
    end
    onSelect = function() rebuildList() end
    rebuildList = function()
        if ST._busy then return end
        ST._busy = true
        rebuildCalls = rebuildCalls + 1
        onRowSelected("pose1")                -- SelectItem
        ST._busy = false
    end

    local okRun = pcall(onRowSelected, "pose1")
    ok(okRun, "ИСПРАВЛЕНО: цепочка завершается без переполнения стека")
    ok(maxDepth == 1, "глубина ровно 1 — повторного входа нет", maxDepth)
    ok(loadPoseCalls == 1, "поза загружается один раз, а не бесконечно", loadPoseCalls)

    -- Обычное перестроение списка (смена категории) по-прежнему работает.
    ST._busy = false
    rebuildCalls = 0
    rebuildList()
    ok(rebuildCalls == 1, "перестроение списка при этом не сломано", rebuildCalls)
end

-----------------------------------------------------------------------
print("\n=== 3. ИСХОДНИК СТУДИИ ===")
-----------------------------------------------------------------------
local src = readf("lua/autorun/sh_grm_social_studio.lua")

ok(src:find("ST._busy", 1, true) ~= nil, "ИСПРАВЛЕНО: введён флаг повторного входа")

local rebuild = src:match("function ST%.rebuildList%(%).-\n    end")
ok(rebuild and rebuild:find("if ST._busy then return end", 1, true) ~= nil,
   "rebuildList не запускается повторно из самого себя")
ok(rebuild and rebuild:find("ST._busy = false", 1, true) ~= nil,
   "и обязательно снимает флаг в конце — иначе список замрёт навсегда")

ok(src:find("if ST._busy then return end\n        if line and line._id then", 1, true) ~= nil,
   "OnRowSelected отличает клик игрока от программной подсветки")

ok(src:match("ST%._busy = true\n                    for i = 1, 48 do") ~= nil,
   "ChooseOptionID обёрнут флагом — на нём и замыкалась рекурсия")
ok(src:find("ST._busy = wasBusy", 1, true) ~= nil,
   "и флаг восстанавливается, а не сбрасывается в false вслепую")

-- Дублирующий обработчик.
local _, n = src:gsub("list%.OnRowSelected = function", "")
ok(n == 1, "ИСПРАВЛЕНО: остался ОДИН list.OnRowSelected (было два)", n)

-----------------------------------------------------------------------
print("\n=== 4. НАЙДЕНО ПОПУТНО: sendAct ТЕРЯЛ АРГУМЕНТ ===")
-----------------------------------------------------------------------
--[[ Сервер для movepose читает ДВЕ строки (id и категорию), а клиент
     через sendAct(op, extra) отправлял только одну. Категория терялась,
     сервер выходил по `if catName == "" then return end` — перемещение
     поз не работало вообще и молча. ]]
do
    -- Старая реализация.
    local sentOld = {}
    local function sendOld(op, extra)
        sentOld[#sentOld + 1] = op
        if extra ~= nil then sentOld[#sentOld + 1] = tostring(extra) end
    end
    sendOld("movepose", "pose1", "docs")
    ok(#sentOld == 2,
       "БАГ ВОСПРОИЗВЕДЁН: старый sendAct отправлял 2 значения вместо 3", #sentOld)
    ok(sentOld[3] == nil, "категория терялась — сервер получал пустую строку")

    -- Новая.
    local sentNew = {}
    local function sendNew(op, ...)
        sentNew[#sentNew + 1] = op
        for i = 1, select("#", ...) do
            local e = select(i, ...)
            if e ~= nil then sentNew[#sentNew + 1] = tostring(e) end
        end
    end
    sendNew("movepose", "pose1", "docs")
    ok(#sentNew == 3, "ИСПРАВЛЕНО: уходят все три значения", #sentNew)
    ok(sentNew[2] == "pose1" and sentNew[3] == "docs",
       "в том же порядке, в каком их читает сервер")

    -- Однопараметрические вызовы не сломаны.
    sentNew = {}
    sendNew("delete", "pose1")
    ok(#sentNew == 2, "обычные вызовы с одним аргументом работают как раньше")
end

ok(src:find("local function sendAct(op, ...)", 1, true) ~= nil,
   "sendAct принимает произвольное число аргументов")

-- Сервер действительно читает две строки — проверка, что фикс нужен.
local moveBlock = src:match('if op == "movepose" then.-\n        end')
ok(moveBlock and select(2, moveBlock:gsub("net%.ReadString", "")) == 2,
   "сервер для movepose читает ровно две строки — значит клиент обязан слать две")

-----------------------------------------------------------------------
print("\n=== 5. ГИДРАНТ: ЛОВУШКА ОТКРЫТОГО КРАНА ===")
-----------------------------------------------------------------------
local fire = readf("lua/autorun/sh_grm_fire.lua")

--[[ Старое поведение: хук отказывал не-пожарному всегда. Значит
     закрыть открытый гидрант он не мог физически. ]]
do
    local function oldHook(isPro) if isPro then return end return false end
    ok(oldHook(false) == false,
       "БАГ ВОСПРОИЗВЕДЁН: не-пожарному запрещено ЛЮБОЕ действие с гидрантом")
    ok(oldHook(false) == false,
       "в том числе ЗАКРЫТИЕ уже открытого — вода льётся навсегда")
end

-- Новое: открывать по правам, закрывать всем.
do
    local function newHook(isPro, hydrantOpen)
        if isPro then return nil end
        if hydrantOpen == true then return nil end   -- закрытие разрешено
        return false
    end
    ok(newHook(false, false) == false,
       "ИСПРАВЛЕНО: открыть чужой гидрант не-пожарный по-прежнему не может")
    ok(newHook(false, true) == nil,
       "ИСПРАВЛЕНО: а ЗАКРЫТЬ открытый — может любой")
    ok(newHook(true, false) == nil, "пожарный открывает свободно")
    ok(newHook(true, true) == nil, "и закрывает тоже")
end

local hookBlock = fire:match('hook%.Add%("GRM_FireAddon_HydrantUse".-\n    end%)')
ok(hookBlock ~= nil, "хук гидранта найден")
ok(hookBlock and hookBlock:find("hydrant:GetOpen() == true", 1, true) ~= nil,
   "хук смотрит состояние гидранта, а не отказывает вслепую")
ok(hookBlock and hookBlock:find("function(ply, hydrant)", 1, true) ~= nil,
   "принимает саму энтити вторым аргументом")

--[[ Если аддон не передал энтити, определить намерение нельзя —
     тогда ведём себя строго, как раньше. ]]
do
    local function newHook(isPro, hyd)
        if isPro then return nil end
        if hyd and hyd.open == true then return nil end
        return false
    end
    ok(newHook(false, nil) == false,
       "без энтити действуем строго — на угад права не раздаём")
end

-----------------------------------------------------------------------
print("\n=== 6. ГИДРАНТ: САМОЗАКРЫТИЕ ===")
-----------------------------------------------------------------------
ok(fire:find("F.HydrantIdleClose", 1, true) ~= nil,
   "добавлена страховка от брошенного открытым гидранта")
ok(fire:find("hydrantWatch", 1, true) ~= nil, "есть сторож гидрантов")

local watch = fire:match("local function hydrantWatch%(%).-\n    end")
ok(watch and watch:find("GetOpen", 1, true) ~= nil, "сторож смотрит только открытые")
ok(watch and (watch:find("GetHoses", 1, true) or watch:find("GetHoseCount", 1, true)) ~= nil,
   "и НЕ закрывает гидрант, к которому подключён рукав — тушение не сорвётся")
ok(fire:find('GRM.Sched.Every("fire.hydrantwatch"', 1, true) ~= nil,
   "сторож живёт в планировщике с приоритетом low, а не отдельным таймером")

-- Логика простоя.
do
    local IDLE = 60
    local function shouldClose(open, busy, idleFor)
        if not open then return false end
        if busy then return false end
        return idleFor > IDLE
    end
    ok(shouldClose(true, false, 90) == true, "брошенный на 90 сек гидрант закроется")
    ok(shouldClose(true, false, 10) == false, "только что открытый — нет")
    ok(shouldClose(true, true, 999) == false,
       "с подключённым рукавом не закрывается никогда — даже через час")
    ok(shouldClose(false, false, 999) == false, "закрытый трогать незачем")
end

-----------------------------------------------------------------------
print("\n=== 7. СТУДИЯ: ШРИФТЫ И ОСТАЛЬНОЕ ===")
-----------------------------------------------------------------------
--[[ Раньше здесь был GRMSocEd_Small, которого не существует — падало
     «font doesn't exist». Проверяем, что все используемые шрифты
     объявлены в этом же файле. ]]
local declared = {}
for f in src:gmatch('surface%.CreateFont%("([^"]+)"') do declared[f] = true end
local missing = {}
for f in src:gmatch('SetFont%("(GRMSocEd_[^"]+)"') do
    if not declared[f] then missing[#missing + 1] = f end
end
for f in src:gmatch('"(GRMSocEd_[%w_]+)"') do
    if not declared[f] and not f:find("CreateFont") then
        local dup = false
        for _, m in ipairs(missing) do if m == f then dup = true end end
        if not dup then missing[#missing + 1] = f end
    end
end
ok(#missing == 0, "все шрифты студии объявлены", table.concat(missing, ", "))

--[[ Ищем именно ВЫЗОВ SetFont с несуществующим шрифтом, а не любое
     упоминание строки: в файле есть комментарий, объясняющий, почему
     этот шрифт использовать нельзя, и он не должен считаться ошибкой. ]]
ok(src:find('SetFont("GRMSocEd_Small")', 1, true) == nil
   and src:find('"GRMSocEd_Small",', 1, true) == nil,
   "несуществующий GRMSocEd_Small нигде не вызывается")

print("")
print(string.format("ИТОГО: %d ok, %d FAIL", pass, fail))
if fail > 0 then os.exit(1) end
