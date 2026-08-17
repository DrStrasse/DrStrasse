--[[--------------------------------------------------------------------
    sim_binder_chat_forms — три заказа владельца:
      1) текст в форме регистрации организации не исчезает при автосинке;
      2) /dep и /fr выводятся так же, как /gnews (шапка + перенос строки);
      3) биндер действий: /binder, /autobinder, /rpbinder.

    Запуск: ./.luabuild/lj/src/luajit tools/luatest/sim_binder_chat_forms.lua
----------------------------------------------------------------------]]
local function read(p) local f = assert(io.open(p, "rb")) local s = f:read("*a") f:close() return s end

local fails, total = 0, 0
local function ok(cond, name, extra)
    total = total + 1
    if cond then print("  ok   " .. name)
    else fails = fails + 1 print("  FAIL " .. name .. "  " .. tostring(extra or "")) end
end

local ui       = read("lua/autorun/client/cl_grm_factions_unified_ui.lua")
local factions = read("lua/autorun/sh_factions.lua")
local binder   = read("lua/autorun/sh_grm_binder.lua")

print("\n=== 1. ФОРМА РЕГИСТРАЦИИ: ТЕКСТ НЕ ИСЧЕЗАЕТ ===")
ok(ui:find("local function hasActiveInput", 1, true) ~= nil,
    "определяется, что пользователь сейчас печатает")
ok(ui:find("pendingRefreshData = data", 1, true) ~= nil,
    "автосинк во время ввода откладывается, а не рушит панель")
ok(ui:find('hook.Add("Think", "GRM_FactionUnified_PendingRefresh"', 1, true) ~= nil,
    "отложенное обновление применяется, когда ввод закончен")
ok(ui:find("local function bindFormField", 1, true) ~= nil,
    "поля формы помечаются и переживают пересборку")
ok(ui:find('bindFormField(entKey, "create.key")', 1, true) ~= nil
    and ui:find('bindFormField(entDisp, "create.display")', 1, true) ~= nil
    and ui:find('bindFormField(entTag, "create.tag")', 1, true) ~= nil,
    "все три поля регистрации организации защищены")
ok(ui:find("local function collectFormValues", 1, true) ~= nil, "значения собираются перед Clear")
ok(ui:find('formValues["create.key"], formValues["create.display"], formValues["create.tag"] = nil, nil, nil', 1, true) ~= nil,
    "после создания организации черновик очищается")
ok(ui:find("local function rebuildCurrentTab", 1, true) ~= nil,
    "единая точка пересборки вкладки (со скроллом и значениями)")
ok(ui:find("lastTypedAt = RealTime()", 1, true) ~= nil,
    "пауза после последнего нажатия клавиши учитывается")

print("\n=== 2. /dep И /fr КАК /gnews ===")
ok(factions:find("local function printChannel", 1, true) ~= nil, "единый вывод служебных каналов")
ok(factions:find('tagColor, "[" .. tostring(tag or "") .. "]\\n"', 1, true) ~= nil,
    "после тэга идёт перенос строки — как в /gnews")
ok(factions:find('Color(100, 200, 255), tostring(name or "")', 1, true) ~= nil,
    "имя выделено тем же цветом, что в /gnews")
ok(factions:find('printChannel("[Рация] "', 1, true) ~= nil, "/fr использует общий вывод")
ok(factions:find('printChannel("[Волна] "', 1, true) ~= nil, "/dep использует общий вывод")
ok(factions:find('printChannel("[Волна OOC] "', 1, true) ~= nil, "/depb тоже приведён к общему виду")
ok(factions:find('local msg = string.format("[%s] %s (%s): %s", tag, ply:Nick()', 1, true) == nil,
    "старая склейка всего в одну строку убрана из /fr")
ok(factions:find('local msgText = string.format("[%s] %s (%s): - %s"', 1, true) == nil,
    "старая склейка убрана из /dep")
ok(factions:find('local rpName = ply:GetNWString("GRM_RPName", "")', 1, true) ~= nil,
    "в канал уходит RP-имя, а не ник Steam (как в /gnews)")
ok(factions:find("GRM.Factions.RoleDisplayName", 1, true) ~= nil,
    "должность показывается публичным названием")
ok(select(2, factions:gsub("net%.WriteString%(tag%)", "")) >= 1
    and select(2, factions:gsub("net%.WriteString%(displayTag%)", "")) >= 2,
    "сервер шлёт поля раздельно (тэг, имя, должность, текст)")

print("\n=== 3. БИНДЕР ДЕЙСТВИЙ ===")
ok(binder:find('GRM.Binder', 1, true) ~= nil and binder:find('BD.Version = "1.0.0"', 1, true) ~= nil,
    "модуль GRM.Binder v1.0.0")
ok(binder:find("BD.MaxSlots      = 40", 1, true) ~= nil and binder:find("BD.DefaultSlots  = 20", 1, true) ~= nil,
    "20 слотов по умолчанию, до 40 всего")
ok(binder:find('["/binder"] = true', 1, true) ~= nil
    and binder:find('["/autobinder"] = true', 1, true) ~= nil
    and binder:find('["/rpbinder"] = true', 1, true) ~= nil,
    "все три команды: /binder, /autobinder, /rpbinder")
ok(binder:find('concommand.Add("grm_binder"', 1, true) ~= nil, "консольная команда")
ok(binder:find('hook.Add("PlayerSay", "GRM_Binder_Chat"', 1, true) ~= nil
    and binder:find('hook.Add("PlayerSayTransform", "GRM_Binder_ChatEC"', 1, true) ~= nil,
    "команда ловится на сервере (и в EasyChat) — в общий чат не улетает")
ok(binder:find('RunConsoleCommand("say", text)', 1, true) ~= nil, "режим «в чат» отправляет say")
ok(binder:find('LocalPlayer():ConCommand(text .. "\\n")', 1, true) ~= nil, "режим «в консоль» выполняет команду")
ok(binder:find("DBinder", 1, true) ~= nil, "клавиша выбирается стандартным биндером")
ok(binder:find("slot.chain", 1, true) ~= nil and binder:find("chainDelay", 1, true) ~= nil,
    "связка слотов с задержкой")
ok(binder:find("BD.MaxChainDepth", 1, true) ~= nil and binder:find("visited[index]", 1, true) ~= nil,
    "цепочка защищена от зацикливания")
ok(binder:find("local function inputBusy", 1, true) ~= nil
    and binder:find("lp:IsTyping()", 1, true) ~= nil,
    "бинды молчат, пока открыт чат/консоль/меню")
ok(binder:find("function BD.RebuildKeyMap", 1, true) ~= nil and binder:find("BD.KeyMap[key]", 1, true) ~= nil,
    "нажатие смотрит в таблицу клавиш, а не перебирает слоты")
ok(binder:find("slot.cooldown", 1, true) ~= nil, "персональный кулдаун слота")
ok(binder:find('file.Write(BD.File, util.TableToJSON(arr, true))', 1, true) ~= nil,
    "сохранение в data/grm_binder.json")
ok(binder:find("Проверить", 1, true) ~= nil, "кнопка проверки слота из меню")
ok(binder:find("GRMBind_Title", 1, true) ~= nil and binder:find("bg     = Color(16, 20, 28, 252)", 1, true) ~= nil,
    "оформление в стиле GRM")

print("\n=== 4. ЖИВОЙ ПРОГОН БИНДЕРА ===")
local stub = dofile("tools/luatest/lib_gmod_stub.lua")
stub.install()
stub.reset()
_G.CLIENT, _G.SERVER = true, false
_G.KEY_NONE = 0
_G.KEY_F = 26
_G.RealTime = function() return stub.time or 0 end
_G.chat = { AddText = function() end }
_G.gui = { IsGameUIVisible = function() return false end, IsConsoleVisible = function() return false end }
_G.vgui.CursorVisible = function() return false end
_G.surface.CreateFont = function() end
_G.color_white = { r = 255, g = 255, b = 255 }
_G.TEXT_ALIGN_LEFT, _G.TEXT_ALIGN_CENTER, _G.TEXT_ALIGN_RIGHT = 0, 1, 2

local saved = nil
_G.file.Write = function(_, data) saved = data end
_G.file.Read = function() return saved end
_G.util.TableToJSON = function(t)
    -- примитивная сериализация для стенда
    local parts = {}
    for _, row in ipairs(t) do
        parts[#parts + 1] = table.concat({ row.id, row.mode, row.text, row.key, row.chain }, "\1")
    end
    return table.concat(parts, "\2")
end
_G.util.JSONToTable = function(raw)
    if not raw or raw == "" then return nil end
    local out = {}
    for chunk in string.gmatch(raw, "([^\2]+)") do
        local f = {}
        for piece in string.gmatch(chunk .. "\1", "([^\1]*)\1") do f[#f + 1] = piece end
        out[#out + 1] = { id = tonumber(f[1]), mode = f[2], text = f[3], key = tonumber(f[4]), chain = tonumber(f[5]) }
    end
    return out
end

local sentSay, sentCon = {}, {}
_G.RunConsoleCommand = function(cmd, arg) if cmd == "say" then sentSay[#sentSay + 1] = arg end end
local lp = stub.makeEntity({ class = "player", isPlayer = true })
lp.ConCommand = function(_, cmd) sentCon[#sentCon + 1] = cmd end
lp.IsTyping = function() return false end
_G.LocalPlayer = function() return lp end

local loaded, err = stub.loadModule("lua/autorun/sh_grm_binder.lua")
ok(loaded, "биндер поднялся в моке", err)
local BD = _G.GRM and _G.GRM.Binder
ok(BD and #BD.Slots >= 20, "создано 20 пустых слотов", BD and #BD.Slots)

BD.Slots[1].mode = "chat"     BD.Slots[1].text = "/me поправляет фуражку"  BD.Slots[1].key = KEY_F
BD.Slots[2].mode = "console"  BD.Slots[2].text = "grm_binder"              BD.Slots[2].key = KEY_NONE
BD.Slots[1].chain = 2         BD.Slots[1].chainDelay = 0
BD.Save()

ok(BD.KeyMap[KEY_F] ~= nil and BD.KeyMap[KEY_F][1] == 1, "слот попал в таблицу клавиш")

stub.time = 100
_G.hook.Run("PlayerButtonDown", lp, KEY_F)
stub.runTimers()
ok(sentSay[1] == "/me поправляет фуражку", "чат-действие ушло через say", sentSay[1])
ok(sentCon[1] == "grm_binder\n", "связанный слот выполнил консольную команду", sentCon[1])

-- кулдаун
local before = #sentSay
_G.hook.Run("PlayerButtonDown", lp, KEY_F)
ok(#sentSay == before, "повторное нажатие внутри кулдауна игнорируется")

-- ввод занят
stub.time = 200
lp.IsTyping = function() return true end
_G.hook.Run("PlayerButtonDown", lp, KEY_F)
ok(#sentSay == before, "во время печати в чат бинд не срабатывает")
lp.IsTyping = function() return false end

-- защита от зацикливания
sentSay, sentCon = {}, {}
BD.Slots[1].chain = 2 BD.Slots[2].chain = 1 BD.Slots[2].mode = "chat" BD.Slots[2].text = "второй"
BD.Slots[1].cooldown = 0 BD.Slots[2].cooldown = 0
BD.Slots[1].chainDelay = 0 BD.Slots[2].chainDelay = 0
stub.time = 300
BD.Run(1, 1, {}, true)
for _ = 1, 12 do stub.runTimers() end
ok(#sentSay <= 2, ("цепочка не зациклилась: выполнено %d действий"):format(#sentSay))

print(("\nBINDER + CHAT + FORMS: %d/%d, провалов: %d"):format(total - fails, total, fails))
os.exit(fails == 0 and 0 or 1)
