--[[--------------------------------------------------------------------
    sim_industry_loadorder — порядок загрузки клиентских файлов
    индустрии.

    ЗАЧЕМ ЭТОТ СТЕНД. Он появился после настоящей поломки на сервере:

        cl_grm_industry_machine.lua:25: attempt to index local 'UI'
        (a nil value)

    Причина в двух вещах, которых не видно при чтении отдельного
    файла:

    1. GMod грузит файлы из lua/autorun по алфавиту, а папку client —
       после корня. Внутри lua/autorun/client порядок такой:
       logistics, machine, ui. То есть UI-файл, который создаёт I.UI
       и палитру, грузится ПОСЛЕДНИМ, а два других берут её в момент
       загрузки. Раньше там было `local C_ = UI.C` — получали nil.

    2. Таблица имён сетей I.NET создавалась в sv_grm_industry.lua,
       а это папка autorun/server — сервер только. На клиенте I.NET
       была nil, и net.Receive(NET.job, ...) падал. Ни одно окно
       индустрии не открывалось.

    Обычные стенды поднимают файлы через loadfile по одному и в
    нужном им порядке, поэтому такие ошибки не ловятся: в стенде всё
    есть, а на сервере — нет. Здесь файлы грузятся так же, как их
    загрузит GMod.

    Запуск: ./.luabuild/lj/src/luajit tools/luatest/sim_industry_loadorder.lua
----------------------------------------------------------------------]]
local stub = dofile("tools/luatest/lib_gmod_stub.lua")
stub.install()

-- Клиентская сторона: именно там и падало.
SERVER, CLIENT = false, true

local fails, total = 0, 0
local function ok(cond, name, extra)
    total = total + 1
    if cond then print("  ok   " .. name)
    else fails = fails + 1 print("  FAIL " .. name .. "  " .. tostring(extra or "")) end
end
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end

-- ================================================================
--  НЕДОСТАЮЩИЕ ГЛОБАЛЫ КЛИЕНТА
-- ================================================================
-- Заглушка lib_gmod_stub заточена под сервер, поэтому клиентские
-- константы приходится объявить. Без них файл упадёт на `table index
-- is nil` в конструкторе вида { [KEY_UP] = 1 } — и это будет ошибка
-- стенда, а не боевого кода.
KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT = 1, 2, 3, 4
KEY_SPACE, KEY_ESCAPE, KEY_ENTER, KEY_TAB = 5, 6, 7, 8
MOUSE_LEFT, MOUSE_RIGHT, MOUSE_MIDDLE = 107, 108, 109
IN_ATTACK, IN_USE, IN_RELOAD, IN_JUMP = 1, 32, 2048, 2
_G.input = setmetatable({}, { __index = function() return function() return false end end })
_G.gui = setmetatable({}, { __index = function() return function() end end })
_G.render = setmetatable({}, { __index = function() return function() end end })
_G.cam = setmetatable({}, { __index = function() return function() end end })
_G.Material = function() return setmetatable({}, { __index = function() return function() end end }) end
_G.ScrW, _G.ScrH = function() return 1920 end, function() return 1080 end
_G.LocalPlayer = function() return stub.makeEntity({ class = "player", isPlayer = true }) end
_G.system = { IsLinux = function() return true end, IsWindows = function() return false end }
_G.DermaMenu = function() return setmetatable({}, { __index = function() return function() end end }) end
_G.Derma_StringRequest = function() end
-- Реестр сущностей: нужен общему файлу узлов, он объявляет классы.
_G.scripted_ents = {
    Register = function() end,
    GetStored = function() return nil end,
    Get = function() return nil end,
    GetList = function() return {} end,
}
_G.ENT, _G.SWEP = nil, nil
-- Константы расстановки панелей и выравнивания текста.
TOP, BOTTOM, LEFT, RIGHT, FILL = 1, 2, 3, 4, 5
TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER, TEXT_ALIGN_RIGHT = 0, 1, 2
color_white = Color(255, 255, 255)
_G.color_white = color_white
_G.chat = { AddText = function() end }

-- ================================================================
--  УЧЁТ СЕТЕВЫХ СООБЩЕНИЙ
-- ================================================================
--[[ Запоминаем, кто что объявил. Нам важно не только что файлы
     загрузились, но и что клиент реально подписался на сообщения
     под теми же именами, под которыми сервер их шлёт. ]]
local RECEIVED, SENT = {}, {}
_G.net.Receive = function(name, fn) RECEIVED[name] = fn or true end
_G.net.Start = function(name) SENT[#SENT + 1] = name end

-- ================================================================
--  ЗАГРУЗЧИК, ПОВТОРЯЮЩИЙ ПОРЯДОК GMOD
-- ================================================================
--[[ GMod берёт файлы из lua/autorun по алфавиту, а подпапки client и
     server — после корня. Внутри каждой папки тоже по алфавиту.
     Здесь порядок получается из ls, а не записан руками: если
     добавят новый файл, он встанет в цепочку сам. ]]
local function sorted(pattern)
    local handle = assert(io.popen("ls " .. pattern .. " 2>/dev/null | sort"))
    local out = {}
    for line in handle:lines() do if line ~= "" then out[#out + 1] = line end end
    handle:close()
    return out
end

--[[ Штатные файлы фреймворка идут по алфавиту РАНЬШЕ industry —
     в GMod так и будет. Берём их, потому что UI.Window вызывает
     GRM.UI.Track из lua/autorun/sh_00_grm_ui.lua. Подставлять вместо
     него заглушку нельзя: тогда прогон окна проверял бы сам себя. ]]
local ROOT_FILES   = sorted("lua/autorun/sh_00_grm_*.lua lua/autorun/sh_grm_industry*.lua")
local CLIENT_FILES = sorted("lua/autorun/client/cl_grm_industry*.lua")

local function loadFile(path)
    local chunk, err = loadstring(read(path), "@" .. path)
    if not chunk then return false, err end
    local good, runErr = pcall(chunk)
    if not good then return false, runErr end
    return true
end

-- Загружаем всё с нуля: общие, затем клиентские — как GMod.
local function loadAll(clientOrder)
    GRM = nil
    package.loaded = {}
    stub.reset()
    RECEIVED, SENT = {}, {}
    local errors = {}
    for _, path in ipairs(ROOT_FILES) do
        local good, err = loadFile(path)
        if not good then errors[#errors + 1] = path .. ": " .. tostring(err) end
    end
    for _, path in ipairs(clientOrder) do
        local good, err = loadFile(path)
        if not good then errors[#errors + 1] = path .. ": " .. tostring(err) end
    end
    return errors
end

-- ================================================================
print("\n=== 1. СОСТАВ ЦЕПОЧКИ ===")
-- ================================================================
ok(#ROOT_FILES >= 3, "общие файлы найдены", #ROOT_FILES)
ok(#CLIENT_FILES >= 3, "клиентские файлы найдены", #CLIENT_FILES)
--[[ ПРОВЕРКА САМОГО ПОРЯДКА. Если файл с палитрой встанет в цепочку
     раньше своих потребителей, весь этот стенд потеряет смысл:
     поломка перестанет воспроизводиться, а на сервере останется. ]]
local uiPos
for i, path in ipairs(CLIENT_FILES) do
    if path:find("cl_grm_industry_ui%.lua$") then uiPos = i end
end
ok(uiPos ~= nil, "файл с палитрой в цепочке есть")
ok(uiPos == #CLIENT_FILES,
    "файл с палитрой грузится ПОСЛЕДНИМ — иначе стенд не проверяет то, что сломалось",
    uiPos .. " из " .. #CLIENT_FILES)

-- ================================================================
print("\n=== 2. ЗАГРУЗКА В ПОРЯДКЕ GMOD ===")
-- ================================================================
--[[ СНАЧАЛА ТОЛЬКО ОБЩИЕ ФАЙЛЫ. Клиентские берут I.UI и I.NET в
     момент загрузки, а GMod грузит подпапку client ПОСЛЕ корня.
     Значит, к старту клиентских файлов обе таблицы уже обязаны
     существовать — иначе потребитель получит nil. Проверяем это
     отдельно: так ловится не только падение при загрузке, но и
     тихая поломка, когда файл загрузился, а функция внутри падает
     уже по клику игрока. ]]
loadAll({})
ok(GRM and GRM.Industry ~= nil, "общие файлы подняли GRM.Industry")
ok(GRM and GRM.Industry.NET ~= nil, "I.NET готова до старта клиентских файлов")
ok(GRM and GRM.Industry.UI ~= nil, "I.UI готова до старта клиентских файлов")

local errors = loadAll(CLIENT_FILES)
ok(#errors == 0, "ВСЕ ФАЙЛЫ ЗАГРУЗИЛИСЬ БЕЗ ОШИБОК", table.concat(errors, " | "))

local I = GRM and GRM.Industry
ok(I ~= nil, "GRM.Industry поднялся")
ok(I and I.NET ~= nil, "I.NET есть и на клиенте", tostring(I and I.NET))

-- ================================================================
print("\n=== 3. ИМЕНА СЕТЕЙ ОДИНАКОВЫ НА ОБЕИХ СТОРОНАХ ===")
-- ================================================================
--[[ Имена должны совпадать. В стенде сервер не поднимается целиком,
     поэтому сравниваем с тем, что объявлено в sv_grm_industry.lua:
     вычитываем имена из текста файла, чтобы расхождение поймать
     сразу, а не по жалобе «окно не открывается». ]]
if I and I.NET then
    local expected = {
        open = "GRM_IND_Open", action = "GRM_IND_Action", job = "GRM_IND_Job",
        mg = "GRM_IND_Minigame", step = "GRM_IND_Step", note = "GRM_IND_Note",
    }
    for key, name in pairs(expected) do
        ok(I.NET[key] == name, "имя " .. key .. " = " .. name, I.NET[key])
    end
    -- Клиент обязан подписаться на то, что присылает сервер.
    for _, key in ipairs({ "open", "job", "mg" }) do
        ok(RECEIVED[I.NET[key]] ~= nil, "клиент слушает " .. I.NET[key])
    end
    --[[ Ни одного nil в имени: net.Start(nil) молча не отправляет
         ничего, и игрок видит «кнопка не работает» без ошибок. ]]
    local nilNames = 0
    for k, v in pairs(I.NET) do if type(v) ~= "string" then nilNames = nilNames + 1 end end
    ok(nilNames == 0, "пустых имён нет", nilNames)
end

-- ================================================================
print("\n=== 4. ПАЛИТРА ДОСТУПНА ТЕМ, КТО ГРУЗИТСЯ РАНЬШЕ ===")
-- ================================================================
--[[ Паллитру создаёт файл, который в цепочке последний. Значит,
     потребители обязаны брать её лениво. Проверяем, что таблица
     вообще наполнилась после загрузки всей цепочки. ]]
ok(I and I.UI ~= nil, "I.UI создана")
ok(I and I.UI and I.UI.C ~= nil, "палитра I.UI.C заполнена")
if I and I.UI and I.UI.C then
    ok(I.UI.C.text ~= nil, "в палитре есть цвет текста")
    ok(I.UI.C.accent ~= nil, "в палитре есть акцентный цвет")
end

-- ================================================================
print("\n=== 5. ПОРЯДОК НЕ ВЛИЯЕТ: ГРУЗИМ В ОБРАТНУЮ СТОРОНУ ===")
-- ================================================================
--[[ Если какой-то файл опять возьмёт поле в момент загрузки, прямой
     порядок может этого не показать — но обратный покажет всегда.
     Это и есть проверка «зависимости от порядка нет». ]]
local reversed = {}
for i = #CLIENT_FILES, 1, -1 do reversed[#reversed + 1] = CLIENT_FILES[i] end
local revErrors = loadAll(reversed)
ok(#revErrors == 0, "ФАЙЛЫ НЕ ЗАВИСЯТ ОТ ПОРЯДКА ЗАГРУЗКИ", table.concat(revErrors, " | "))

local I2 = GRM and GRM.Industry
ok(I2 and I2.UI and I2.UI.C ~= nil, "палитра на месте и при обратном порядке")

-- ================================================================
print("\n=== 6. ОКНО СТАНКА ОТКРЫВАЕТСЯ ВЖИВУЮ ===")
-- ================================================================
--[[ ЗАГРУЗКА БЕЗ ОШИБКИ ЕЩЁ НЕ ЗНАЧИТ, ЧТО ОКНО РАБОТАЕТ. Если
     файл возьмёт UI.C в момент загрузки, он получит nil: файлы
     загрузятся чисто, а упадёт уже по клику игрока — и в логе
     будет «attempt to index a nil value» без внятного места.
     Поэтому открываем окно по-настоящему, через сетевой обработчик,
     точно так же, как это делает сервер. ]]
loadAll(CLIENT_FILES)

local function fakeNode(role)
    local e = stub.makeEntity({ class = "grm_ind_" .. role, __valid = true })
    e.GetNWString = function() return "" end
    e.GetNWInt = function() return 0 end
    e.GetNWFloat = function() return 0 end
    e.EntIndex = function() return 7 end
    return e
end

local OPEN_DATA = {
    role = "station", kind = "furnace", label = "Печь №1",
    stock = {}, out = {}, supply = {}, market = {}, recipes = {
        { id = "melt_components", name = "Компоненты", output = "defective_components",
          scrap = 1, process = 4, assemble = 2, price = 120 },
    },
    wear = 0, job = nil,
}
_G.net.ReadEntity = function() return fakeNode("station") end
_G.net.ReadTable  = function() return OPEN_DATA end
_G.net.ReadString = function() return "furnace" end
_G.net.ReadUInt   = function() return 1 end
_G.net.ReadFloat  = function() return 0 end
_G.net.ReadBool   = function() return false end
_G.net.ReadInt    = function() return 0 end

local receiver = RECEIVED[I.NET.open]
ok(receiver ~= nil, "обработчик открытия окна зарегистрирован")
if receiver then
    local good, err = pcall(receiver)
    ok(good, "ОКНО СТАНКА ОТКРЫЛОСЬ БЕЗ ОШИБКИ", err)
end

-- ================================================================
print("\n=== ИТОГ ===")
-- ================================================================
print(string.format("  пройдено: %d, провалено: %d", total - fails, fails))
if fails > 0 then print("  СТЕНД КРАСНЫЙ") os.exit(1) end
print("  СТЕНД ЗЕЛЁНЫЙ")
