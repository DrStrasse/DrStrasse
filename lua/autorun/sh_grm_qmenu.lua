--[[--------------------------------------------------------------------
    GRM Q-меню «Стройка» v4.1.0 (Код 96) — переписано с нуля

    v4.1.1: три колонки — меню | инструменты | панель настроек;
      окно шире и выше; параметры в отдельной правой колонке, не под тулами.
    v4.1.0: инструменты справа (как ваниль / v3), не вкладкой;
      панель параметров с нуля — только ручная схема с человеческими
      подписями; авто-дамп ClientConVar в UI не используется
      (это давало a1/b3 у 3D2D Textscreen); нет кнопки +menu.
    v4.0.0: чужой BuildCPanel больше не вызывается; настройки — из схемы
      данных; иконки порциями; ничего не меряем в Paint; раскладка
      константами; HOLD-Q как ваниль (зажал — открыто, отпустил — закрыто).
    Совместимость: GRM.QMenu.Cfg / Save / ToolCatalog / Version / CanUseTool
      / CanSpawn / CanOpenQ; data/grm_qmenu.json без смены формата;
      те же 12 net-каналов + List/RemoveIdx для вкладки «Мои объекты».
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.QMenu = GRM.QMenu or {}
local QM = GRM.QMenu

QM.Version = "4.1.1"

local CONFIG_FILE = "grm_qmenu.json"

QM.ToolCatalog = {
    { id = "weld",       label = "Сварка (скрепление пропов)", desc = "Склеивает два пропа жёстко.",            cat = "connect" },
    { id = "axis",       label = "Ось",                        desc = "Соединение вращением вокруг точки.",     cat = "connect" },
    { id = "ballsocket", label = "Шарнир",                     desc = "Подвижное шаровое соединение.",          cat = "connect" },
    { id = "nocollide",  label = "Без столкновений",           desc = "Два пропа перестают сталкиваться.",      cat = "connect" },
    { id = "rope",       label = "Верёвка",                    desc = "Связывает пропы тросом.",                cat = "connect" },
    { id = "pulley",     label = "Блок",                       desc = "Трос через блок.",                       cat = "connect" },
    { id = "winch",      label = "Лебёдка",                    desc = "Трос с управляемой длиной.",             cat = "connect" },
    { id = "hydraulics", label = "Гидравлика",                 desc = "Управляемое давление/ход.",              cat = "connect" },
    { id = "muscle",     label = "Мышца",                      desc = "Упругая связка-амортизатор.",            cat = "connect" },
    { id = "slider",     label = "Слайдер",                    desc = "Движение вдоль оси.",                    cat = "connect" },
    { id = "wheel",      label = "Колесо",                     desc = "Ставит колесо на проп.",                 cat = "mech" },
    { id = "motor",      label = "Мотор",                      desc = "Вращение по вводу.",                     cat = "mech" },
    { id = "thruster",   label = "Ускоритель",                 desc = "Реактивная тяга по клавише.",            cat = "mech" },
    { id = "hoverball",  label = "Ховербол",                   desc = "Поднимает предмет на высоте.",           cat = "mech" },
    { id = "balloon",    label = "Воздушный шар",              desc = "Воздушный шар с тяговым усилием.",       cat = "mech" },
    { id = "light",      label = "Источник света",              desc = "Точечный источник света.",               cat = "light" },
    { id = "lamp",       label = "Лампа",                      desc = "Прожектор/лампа.",                       cat = "light" },
    { id = "emitter",    label = "Эмиттер",                    desc = "Частицы/эффекты — дым, огонь.",          cat = "light" },
    { id = "button",     label = "Кнопка",                     desc = "Сигнальная кнопка.",                     cat = "ui" },
    { id = "camera",     label = "Камера",                     desc = "Камера наблюдателя.",                    cat = "ui" },
    { id = "textscreen", label = "Текстовый экран",            desc = "Табличка с текстом на карте.",           cat = "ui" },
    { id = "grm_minimap",        label = "GRM: районы и точки",              desc = "Районы, точки захвата и мини-карта.", cat = "ui" },
    { id = "grm_vendor_tool",    label = "GRM: торговцы",                    desc = "Торговцы предметами и аксессуарами.", cat = "ui" },
    { id = "vehicle_dealer_tool",label = "GRM: дилер и площадка выдачи",     desc = "Дилер, гараж и площадка транспорта.", cat = "ui" },
    { id = "grm_quest_tool",     label = "GRM: конструктор квестов",         desc = "Квестовые NPC, зоны и кат-сцены.", cat = "ui" },
    { id = "grm_network_tool",   label = "GRM: электроника и интернет",      desc = "Компьютеры, роутеры, розетки.", cat = "ui" },
    { id = "grm_door_admin",     label = "GRM: двери",                       desc = "Канонические двери и доступы.", cat = "ui" },
    { id = "grm_sliding_door",   label = "GRM: раздвижная дверь",            desc = "Проп → раздвижная дверь + FFD Link.", cat = "ui" },
    { id = "grm_bank_tool",      label = "GRM: банковское оборудование",     desc = "Хранилище, станок, терминал, отмыв.", cat = "ui" },
    { id = "grm_perm_tool",      label = "GRM: перм-проп (закрепление)",     desc = "Закрепить объект на карте.", cat = "ui" },
    { id = "grm_service_tool",   label = "GRM: служебное оборудование",      desc = "Компьютеры ведомств.", cat = "ui" },
    { id = "grm_arrest_zone",    label = "GRM: зона ареста",                 desc = "Камеры и зоны содержания.", cat = "ui" },
    { id = "grm_augmentation",   label = "GRM: аугментации",                 desc = "Станции и поды аугментаций.", cat = "ui" },
    { id = "grm_citadel_core",   label = "GRM: ядро Цитадели",               desc = "Размещение ядра Цитадели.", cat = "ui" },
    { id = "grm_lab_tool",       label = "GRM: лаборатории",                 desc = "Мед- и нарко-лаборатории.", cat = "ui" },
    { id = "grm_fire_place",     label = "GRM: пожарное железо",             desc = "Гидрант, насос, шкаф, точка, лестница.", cat = "ui" },
    { id = "colour",     label = "Цвет",                 desc = "Перекраска и прозрачность.",             cat = "decor" },
    { id = "material",   label = "Материал",             desc = "Смена материала/текстуры.",              cat = "decor" },
    { id = "paint",      label = "Краска",               desc = "Спрей-декали.",                          cat = "decor" },
    { id = "trails",     label = "Трейлы",               desc = "Шлейф за объектом.",                     cat = "decor" },
    { id = "remover",    label = "Ремувер",              desc = "Убирает проп; свои — всегда можно.",     cat = "precise" },
    { id = "precision",  label = "Точное перемещение",   desc = "Точный сдвиг/поворот.",                  cat = "precise" },
    { id = "stacker",    label = "Стакер",               desc = "Колонны/ряды одинаковых пропов.",        cat = "precise" },
    { id = "duplicator", label = "Дубликатор",           desc = "Копирует конструкции — абуз.",           cat = "precise" },
    { id = "advdupe2",   label = "Adv. Duplicator 2",    desc = "Продвинутый дубликатор — абуз.",         cat = "precise" },
    { id = "dynamite",   label = "Динамит",              desc = "Взрывчатка — опасно.",                   cat = "danger" },
    { id = "turret",     label = "Турель",               desc = "Стреляющая турель — опасно.",            cat = "danger" },
    { id = "igniter",    label = "Поджигатель",          desc = "Поджигает цель.",                        cat = "danger" },
    { id = "spawner",    label = "Спавнер",              desc = "Автоспавн предметов — абуз.",            cat = "danger" },
    { id = "ffd_fading_door", label = "GRM: исчезающая дверь", desc = "Проп → fading door.",              cat = "misc" },
    { id = "ffd_keypad",      label = "GRM: кодовый замок",    desc = "PIN-кейпад.",                      cat = "misc" },
    { id = "ffd_link",        label = "GRM: связь FFD",        desc = "Связать кейпад/сканер с дверью.",  cat = "misc" },
    { id = "ffd_scanner",     label = "GRM: сканер фракций",   desc = "Доступ по фракции.",               cat = "misc" },
    { id = "fading_door",     label = "Fading Door (легаси)",  desc = "Старый fading door.",              cat = "misc" },
    { id = "keypad",          label = "Кейпад (легаси)",       desc = "Старый кейпад.",                   cat = "misc" },
}

QM.ToolCategories = {
    { id = "connect", name = "Соединения" },
    { id = "mech",    name = "Механика" },
    { id = "light",   name = "Свет и эффекты" },
    { id = "ui",      name = "Интерфейс" },
    { id = "decor",   name = "Оформление" },
    { id = "precise", name = "Точность и копирование" },
    { id = "danger",  name = "Опасное (админ)" },
    { id = "misc",    name = "Прочее" },
}

QM.SeedProps = {
    "models/props_c17/furnituretable001a.mdl",
    "models/props_c17/furnituretable002a.mdl",
    "models/props_c17/furniturechair001a.mdl",
    "models/props_c17/furniturecouch001a.mdl",
    "models/props_c17/furniturecouch002a.mdl",
    "models/props_c17/furnitureshelf001b.mdl",
    "models/props_c17/furnituredresser001a.mdl",
    "models/props_c17/furniturebed001a.mdl",
    "models/props_c17/furniturefridge001a.mdl",
    "models/props_combine/breenchair.mdl",
    "models/props_c17/oildrum001.mdl",
    "models/props_junk/wood_crate001a.mdl",
    "models/props_junk/wood_crate002a.mdl",
    "models/props_junk/wood_pallet001a.mdl",
    "models/props_junk/trashbin01a.mdl",
    "models/props_c17/concrete_barrier001a.mdl",
    "models/props_junk/gascan001a.mdl",
    "models/props_junk/propanecanister001a.mdl",
}

local function defaultCfg()
    return {
        playersQ     = true,
        allowProps   = true,
        allowRagdolls= true,
        allowEffects = false,
        allowNPCs    = false,
        allowSENTs   = false,
        allowSWEPs   = false,
        allowVehiclesQ = false,
        whitelistMode  = false,
        toolDeny  = {
            dynamite = true, turret = true, igniter = true, spawner = true,
            duplicator = true, advdupe2 = true, emitter = true,
        },
        toolAllow = {},
        grmBuildMenu = true,
        propsFree    = false,
        propList     = {},
        menuPropCap  = 24,
        protectFurniture = true,
        adminsToo    = false,
    }
end

QM.Cfg = QM.Cfg or defaultCfg()

function QM.InCatalog(id)
    id = string.lower(tostring(id or ""))
    for _, t in ipairs(QM.ToolCatalog) do
        if t.id == id then return true end
    end
    return false
end

-- Схема настроек: данные, не чужой код. BuildCPanel не вызывается.
QM.Schema = {
    grm_perm_tool = {
        { cvar = "grm_perm_tool_owner",  type = "choice", label = "Кому принадлежит",
          choices = { { "Серверное оборудование", "server" }, { "Фракция", "faction" }, { "Мой персонаж", "character" } } },
        { cvar = "grm_perm_tool_faction", type = "text", label = "Фракция (пусто = ваша)" },
        { cvar = "grm_perm_tool_freeze", type = "bool",   label = "Заморозить" },
        { cvar = "grm_perm_tool_label",  type = "text",   label = "Метка" },
    },
    grm_service_tool = {
        { cvar = "grm_service_tool_type", type = "choice", label = "Тип компьютера",
          choices = { { "Полиция", "police" }, { "Жандармерия", "military_police" }, { "Спецслужбы", "security" },
                      { "Военкомат", "military" }, { "Автоинспекция", "traffic" }, { "Госпиталь", "medical" } } },
        { cvar = "grm_service_tool_title", type = "text", label = "Заголовок" },
        { cvar = "grm_service_tool_make_perm", type = "bool", label = "Сохранять на карте" },
    },
    grm_bank_tool = {
        { cvar = "grm_bank_tool_type", type = "choice", label = "Тип",
          choices = { { "Хранилище", "vault" }, { "Компьютер банка", "computer" }, { "Станок", "press" },
                      { "Терминал станка", "terminal" }, { "Точка выдачи", "spawnpoint" },
                      { "Отмывщик", "launderer" }, { "Цель ивента", "heisttarget" } } },
    },
    grm_sliding_door = {
        { cvar = "grm_sliding_door_direction", type = "choice", label = "Направление",
          choices = { { "Влево", "left" }, { "Вправо", "right" }, { "Вверх", "up" }, { "Вниз", "down" } } },
        { cvar = "grm_sliding_door_distance", type = "number", label = "Дистанция" },
        { cvar = "grm_sliding_door_speed",    type = "number", label = "Скорость" },
        { cvar = "grm_sliding_door_smooth",   type = "bool",   label = "Плавность" },
        { cvar = "grm_sliding_door_toggle",   type = "bool",   label = "Переключатель" },
        { cvar = "grm_sliding_door_autoclose",type = "bool",   label = "Автозакрытие" },
        { cvar = "grm_sliding_door_closetime",type = "number", label = "Секунд до закрытия" },
    },
    grm_vendor_tool = {
        { cvar = "grm_vendor_tool_type", type = "choice", label = "Тип торговца",
          choices = { { "Оружие", "weapon" }, { "Руда", "ore" }, { "Еда", "food" },
                      { "Редкости", "rare" }, { "Аксессуары", "accessory" } } },
    },
    ffd_fading_door = {
        { cvar = "ffd_fading_door_key", type = "number", label = "Клавиша" },
        { cvar = "ffd_fading_door_reversed", type = "bool", label = "Инверсия" },
        { cvar = "ffd_fading_door_toggle", type = "bool", label = "Переключатель" },
        { cvar = "ffd_fading_door_autoclose", type = "bool", label = "Автозакрытие" },
        { cvar = "ffd_fading_door_time", type = "number", label = "Секунд" },
    },
    ffd_keypad = {
        { cvar = "ffd_keypad_password", type = "text", label = "PIN" },
        { cvar = "ffd_keypad_hold_time", type = "number", label = "Удержание, сек" },
    },
    ffd_scanner = {
        { cvar = "ffd_scanner_faction", type = "text", label = "Фракция" },
        { cvar = "ffd_scanner_hold_time", type = "number", label = "Удержание, сек" },
    },
    light = {
        { cvar = "light_r", type = "number", label = "Красный" },
        { cvar = "light_g", type = "number", label = "Зелёный" },
        { cvar = "light_b", type = "number", label = "Синий" },
        { cvar = "light_brightness", type = "number", label = "Яркость" },
        { cvar = "light_size", type = "number", label = "Радиус" },
        { cvar = "light_toggle", type = "bool", label = "Переключатель" },
    },
    lamp = {
        { cvar = "lamp_r", type = "number", label = "Красный" },
        { cvar = "lamp_g", type = "number", label = "Зелёный" },
        { cvar = "lamp_b", type = "number", label = "Синий" },
        { cvar = "lamp_brightness", type = "number", label = "Яркость" },
        { cvar = "lamp_fov", type = "number", label = "Угол луча" },
        { cvar = "lamp_distance", type = "number", label = "Дальность" },
        { cvar = "lamp_toggle", type = "bool", label = "Переключатель" },
    },
    colour = {
        { cvar = "colour_r", type = "number", label = "Красный" },
        { cvar = "colour_g", type = "number", label = "Зелёный" },
        { cvar = "colour_b", type = "number", label = "Синий" },
        { cvar = "colour_a", type = "number", label = "Прозрачность" },
    },
    weld = {
        { cvar = "weld_forcelimit", type = "number", label = "Предел силы (0 = без лимита)" },
        { cvar = "weld_nocollide", type = "bool", label = "Не сталкиваться" },
    },
    grm_lab_tool = {
        { cvar = "grm_lab_tool_type", type = "choice", label = "Тип лаборатории",
          choices = { { "Лаборатория наркотиков", "narc" }, { "Медицинская лаборатория", "med" } } },
    },
    grm_fire_place = {
        { cvar = "grm_fire_place_type", type = "choice", label = "Тип",
          choices = {
              { "Гидрант", "hydrant" }, { "Насос машины", "pump" },
              { "Шкаф огнетушителей", "cabinet" }, { "Точка очага", "spot" },
              { "Пожарная лестница", "ladder" },
          } },
    },
    grm_network_tool = {
        { cvar = "grm_network_tool_mode", type = "choice", label = "Режим",
          choices = { { "Установка устройства", "spawn" }, { "Соединение кабелем", "link" } } },
        { cvar = "grm_network_tool_kind", type = "choice", label = "Устройство",
          choices = { { "Компьютер", "computer" }, { "Wi-Fi роутер", "router" },
                      { "Сетевой принтер", "printer" }, { "Розетка", "socket" }, { "Штекер", "plug" } } },
        { cvar = "grm_network_tool_name", type = "text", label = "Название" },
        { cvar = "grm_network_tool_network", type = "text", label = "Сеть / SSID" },
    },
    grm_quest_tool = {
        { cvar = "grm_quest_tool_mode", type = "choice", label = "Режим",
          choices = { { "Квестовый NPC", "npc" }, { "Зона этапа", "zone" }, { "Точка кат-сцены", "cutscene" } } },
        { cvar = "grm_quest_tool_npc_id", type = "text", label = "ID NPC" },
        { cvar = "grm_quest_tool_npc_name", type = "text", label = "Имя NPC" },
        { cvar = "grm_quest_tool_quest_id", type = "text", label = "ID квеста" },
        { cvar = "grm_quest_tool_step", type = "number", label = "Номер этапа" },
        { cvar = "grm_quest_tool_phase", type = "choice", label = "Фаза кат-сцены",
          choices = { { "При принятии", "accept" }, { "При завершении", "complete" } } },
    },
    vehicle_dealer_tool = {
        { cvar = "vehicle_dealer_tool_name", type = "text", label = "Название дилера" },
        { cvar = "vehicle_dealer_tool_model", type = "text", label = "Модель NPC" },
        { cvar = "vehicle_dealer_tool_direction", type = "choice", label = "Направление появления",
          choices = { { "По взгляду", "look" }, { "Вперёд от дилера", "forward" }, { "Назад", "back" },
                      { "Влево", "left" }, { "Вправо", "right" }, { "Север", "north" },
                      { "Восток", "east" }, { "Юг", "south" }, { "Запад", "west" } } },
        { cvar = "vehicle_dealer_tool_lift", type = "number", label = "Высота над землёй" },
    },
    grm_augmentation = {
        { cvar = "grm_augmentation_type", type = "choice", label = "Оборудование",
          choices = { { "Станция аугментаций", "station" }, { "Капсула аугментации", "pod" } } },
    },
    grm_citadel_core = {
        { cvar = "grm_citadel_core_type", type = "choice", label = "Оборудование",
          choices = { { "Ядро Цитадели", "core" }, { "Терминал Ядра", "terminal" },
                      { "Связать терминал с ядром", "link" } } },
    },
}

function QM.SchemaFromConVars(cvars)
    local out = {}
    if not istable(cvars) then return out end
    local n = 0
    for k, v in pairs(cvars) do
        n = n + 1
        if n > 32 then break end
        if isstring(k) then
            local sv = tostring(v)
            local row = { cvar = k, label = k }
            if sv == "0" or sv == "1" then
                row.type = "bool"
            elseif tonumber(sv) ~= nil then
                row.type = "number"
            else
                row.type = "text"
            end
            out[#out + 1] = row
        end
    end
    table.sort(out, function(a, b) return a.cvar < b.cvar end)
    return out
end

-- Только ручная схема. Авто из ClientConVar UI не использует
-- (SchemaFromConVars оставлена для стенда sim_qmenu_v4_schema).
function QM.ResolveSchema(toolId)
    toolId = tostring(toolId or "")
    if QM.Schema[toolId] then return QM.Schema[toolId], "hand" end
    return nil, "none"
end

--[[ Построить панель настроек инструмента. Оставлено для регрессии
     sim_qmenu_toolpanel: UI v4 эту функцию НЕ вызывает. ]]
function QM.BuildToolPanel(tool, panel)
    local isfn = function(v) return type(v) == "function" end
    local istbl = function(v) return type(v) == "table" end
    if not istbl(tool) or not (istbl(panel) or type(panel) == "userdata") then
        return false, nil
    end
    local bcp = tool.BuildCPanel
    if isfn(bcp) then
        local ok, err = pcall(bcp, panel)
        if ok then return true, nil end
        if pcall(bcp, tool, panel) then return true, nil end
        return false, err
    end
    if isfn(panel.GetChildren) then
        local ok, ch = pcall(panel.GetChildren, panel)
        if ok and istbl(ch) and #ch > 0 then return true, nil end
    end
    return false, nil
end

-- ============================================================
-- СЕРВЕР
-- ============================================================
if SERVER then
    local function jsonT(txt)
        local ok, t = pcall(util.JSONToTable, txt, false, true)
        return (ok and istable(t)) and t or nil
    end

    local NET_SYNC    = "GRM_QMenu_Sync"
    local NET_SPAWN   = "GRM_QMenu_SpawnProp"
    local NET_REMOVE1 = "GRM_QMenu_RemoveOne"
    local NET_CLEAR   = "GRM_QMenu_ClearProps"
    local NET_GUN     = "GRM_QMenu_Toolgun"
    local NET_TOOL    = "GRM_QMenu_SetTool"
    local NET_CURATE  = "GRM_QMenu_Curate"
    local NET_SEED    = "GRM_QMenu_Seed"
    local NET_SETOPT  = "GRM_QMenu_SetOpt"
    local NET_FEED    = "GRM_QMenu_Feedback"
    local NET_OPEN    = "GRM_QMenu_Open"
    local NET_DIAG    = "GRM_QMenu_Diag"
    local NET_LIST    = "GRM_QMenu_List"
    local NET_RMIDX   = "GRM_QMenu_RemoveIdx"
    for _, s in ipairs({ NET_SYNC, NET_SPAWN, NET_REMOVE1, NET_CLEAR, NET_GUN,
        NET_TOOL, NET_CURATE, NET_SEED, NET_SETOPT, NET_FEED, NET_OPEN, NET_DIAG,
        NET_LIST, NET_RMIDX }) do
        util.AddNetworkString(s)
    end

    function QM.PushSync(ply)
        net.Start(NET_SYNC)
            net.WriteTable(QM.Cfg or defaultCfg())
        if IsValid(ply) then net.Send(ply) else net.Broadcast() end
    end
    hook.Add("PlayerInitialSpawn", "GRM_QMenu_SyncJoin", function(ply)
        timer.Simple(4, function()
            if IsValid(ply) and GRM.QMenu then GRM.QMenu.PushSync(ply) end
        end)
    end)

    local function feedCount(ply)
        if not IsValid(ply) then return end
        local list = QM._menuProps and QM._menuProps[ply] or {}
        local n = 0
        for _, e in ipairs(list) do if IsValid(e) then n = n + 1 end end
        net.Start(NET_FEED)
            net.WriteUInt(1, 4)
            net.WriteUInt(n, 16)
            net.WriteUInt(math.max(1, tonumber(QM.Cfg.menuPropCap) or 24), 16)
        net.Send(ply)
    end
    local function feedToast(ply, text)
        if not IsValid(ply) then return end
        net.Start(NET_FEED)
            net.WriteUInt(2, 4)
            net.WriteString(string.sub(tostring(text or ""), 1, 200))
        net.Send(ply)
    end
    QM._devFeedCount = feedCount
    QM._devFeedToast = feedToast

    local function sanitizeList(t)
        local out = {}
        if istable(t) then
            for k, v in pairs(t) do
                if v == true and isstring(k) then out[k] = true end
            end
            for _, v in ipairs(t) do
                if isstring(v) then out[v] = true end
            end
        end
        return out
    end

    function QM.Load(why)
        if not file.Exists(CONFIG_FILE, "DATA") then return false end
        local raw = file.Read(CONFIG_FILE, "DATA") or ""
        if raw == "" then return false end
        local t = jsonT(raw)
        if not istable(t) then
            print("[GRM QMenu][!] конфиг повреждён, оставлены дефолты (" .. tostring(why) .. ")")
            return false
        end
        local d = defaultCfg()
        for _, k in ipairs({ "playersQ", "allowProps", "allowRagdolls", "allowEffects",
            "allowNPCs", "allowSENTs", "allowSWEPs", "allowVehiclesQ", "whitelistMode",
            "grmBuildMenu", "propsFree", "protectFurniture", "adminsToo" }) do
            if t[k] ~= nil then d[k] = t[k] == true end
        end
        d.toolDeny  = sanitizeList(t.toolDeny)
        d.toolAllow = sanitizeList(t.toolAllow)
        d.propList  = {}
        if istable(t.propList) then
            for _, v in ipairs(t.propList) do
                if isstring(v) and v ~= "" then d.propList[#d.propList + 1] = v end
            end
        end
        d.menuPropCap = math.Clamp(math.floor(tonumber(t.menuPropCap) or 24), 1, 500)
        QM.Cfg = d
        print("[GRM QMenu] конфиг загружен (" .. tostring(why) .. ")")
        return true
    end

    function QM.Save(why)
        local ok, txt = pcall(util.TableToJSON, QM.Cfg, true)
        if not ok or not isstring(txt) then return false end
        file.Write(CONFIG_FILE, txt)
        local back = file.Read(CONFIG_FILE, "DATA") or ""
        if back == "" then print("[GRM QMenu][!] КОНТРОЛЬ ЗАПИСИ: файл пуст после save (" .. tostring(why) .. ")") end
        QM.PushSync(nil)
        return true
    end
    function QM.Reload() return QM.Load("ручная") end

    function QM.CanOpenQ(ply)
        if IsValid(ply) and (ply:GetNWBool("GRM_Cuffed", false) or ply:GetNWBool("GRM_Stunned", false)) then
            return false
        end
        if IsValid(ply) and ply:IsSuperAdmin() then return true end
        return QM.Cfg.playersQ == true
    end

    local SpawnFlags = {
        prop = "allowProps", ragdoll = "allowRagdolls", effect = "allowEffects",
        npc = "allowNPCs", sent = "allowSENTs", swep = "allowSWEPs", vehicle = "allowVehiclesQ",
    }

    function QM.CanSpawn(ply, what)
        if IsValid(ply) and (ply:GetNWBool("GRM_Cuffed", false) or ply:GetNWBool("GRM_Stunned", false)) then
            return false, "Игрок ограничен наручниками/оглушением"
        end
        if IsValid(ply) and ply:IsSuperAdmin() then return true end
        local flag = SpawnFlags[tostring(what or "")]
        if not flag then return true end
        return QM.Cfg[flag] == true
    end

    function QM.CanUseTool(ply, tool)
        if IsValid(ply) and (ply:GetNWBool("GRM_Cuffed", false) or ply:GetNWBool("GRM_Stunned", false)) then
            return false, "Игрок ограничен наручниками/оглушением"
        end
        if IsValid(ply) and ply:IsSuperAdmin() then return true end
        tool = string.lower(tostring(tool or ""))
        if tool == "" then return true end
        if QM.Cfg.toolDeny[tool] == true then
            return false, "Инструмент «" .. tool .. "» запрещён администрацией"
        end
        if QM.Cfg.whitelistMode == true and QM.Cfg.toolAllow[tool] ~= true then
            return false, "Инструмент «" .. tool .. "» не в списке разрешённых"
        end
        return true
    end

    hook.Add("PlayerSpawnProp", "GRM_QMenu_Prop", function(ply)
        if not GRM.QMenu.CanSpawn(ply, "prop") then
            ply:PrintMessage(HUD_PRINTCENTER, "Спавн пропов запрещён администрацией")
            return false
        end
    end)
    hook.Add("PlayerSpawnRagdoll", "GRM_QMenu_Ragdoll", function(ply)
        if not GRM.QMenu.CanSpawn(ply, "ragdoll") then return false end
    end)
    hook.Add("PlayerSpawnEffect", "GRM_QMenu_Effect", function(ply)
        if not GRM.QMenu.CanSpawn(ply, "effect") then return false end
    end)
    hook.Add("PlayerSpawnNPC", "GRM_QMenu_NPC", function(ply)
        if not GRM.QMenu.CanSpawn(ply, "npc") then return false end
    end)
    hook.Add("PlayerSpawnSENT", "GRM_QMenu_SENT", function(ply)
        if not GRM.QMenu.CanSpawn(ply, "sent") then return false end
    end)
    hook.Add("PlayerSpawnSWEP", "GRM_QMenu_SWEP", function(ply)
        if not GRM.QMenu.CanSpawn(ply, "swep") then return false end
    end)
    hook.Add("PlayerSpawnVehicle", "GRM_QMenu_Vehicle", function(ply)
        if not GRM.QMenu.CanSpawn(ply, "vehicle") then
            ply:PrintMessage(HUD_PRINTCENTER, "Транспорт — через дилера или магазин (/vshop)")
            return false
        end
    end)

    local function grmFurniture(ent)
        if not IsValid(ent) then return false end
        if ent._grmPerm or ent._grmRNKey or ent._grmBCKey then return true end
        local cls = tostring(ent:GetClass() or "")
        if string.sub(cls, 1, 4) == "grm_" then return true end
        return false
    end

    hook.Add("CanTool", "GRM_QMenu_CanTool", function(ply, tr, toolname)
        local ok, why = GRM.QMenu.CanUseTool(ply, toolname)
        if not ok then
            ply:PrintMessage(HUD_PRINTCENTER, why or "Инструмент запрещён")
            return false
        end
        toolname = string.lower(tostring(toolname or ""))
        if toolname == "remover" and QM.Cfg.protectFurniture ~= false
            and IsValid(ply) and not ply:IsSuperAdmin() then
            local ent = tr and tr.Entity or nil
            if IsValid(ent) then
                local own = ent.GRM_MenuOwner == ply or ent._grmQMenuOwner == ply
                if not own then
                    if grmFurniture(ent) then
                        ply:PrintMessage(HUD_PRINTCENTER, "Это имущество сервера — удалять нельзя")
                        return false
                    end
                    ply:PrintMessage(HUD_PRINTCENTER, "Удалять можно только свои пропы")
                    return false
                end
            end
        end
    end)

    QM._menuProps = QM._menuProps or {}
    QM._spawnRate = QM._spawnRate or {}

    local function cleanRegistry(ply)
        local list = QM._menuProps[ply]
        if not istable(list) then list = {} QM._menuProps[ply] = list end
        for i = #list, 1, -1 do
            if not IsValid(list[i]) then table.remove(list, i) end
        end
        return list
    end

    local function modelPathOk(model)
        model = tostring(model or "")
        if model == "" or string.find(model, "%.%.") then return false end
        if not string.match(model, "^models/.+%.mdl$") then return false end
        return true
    end

    function QM.CanSpawnMenuProp(ply, model)
        if not IsValid(ply) then return false, "?" end
        model = tostring(model or "")
        if model == "" or string.find(model, "%.%.") then return false, "Некорректная модель" end
        if ply:IsSuperAdmin() then return true end
        if not modelPathOk(model) then return false, "Некорректная модель" end
        if QM.Cfg.grmBuildMenu ~= true then return false, "Меню стройки отключено администрацией" end
        if not QM.CanSpawn(ply, "prop") then return false, "Спавн пропов запрещён администрацией" end
        if QM.Cfg.propsFree == true then return true end
        for _, m in ipairs(QM.Cfg.propList or {}) do
            if m == model then return true end
        end
        return false, "Модель вне каталога меню стройки"
    end

    local function registerSpawned(ply, ent)
        if undo and undo.Create then
            pcall(function()
                undo.Create("Prop")
                    undo.AddEntity(ent)
                    undo.SetPlayer(ply)
                undo.Finish()
            end)
        end
        if cleanup and cleanup.Add then
            pcall(function() cleanup.Add(ply, "props", ent) end)
        end
        ent.GRM_MenuOwner = ply
        ent._grmQMenuOwner = ply
        if GRM.Identity and isfunction(GRM.Identity.CharacterKey) then
            ent._grmQMenuChar = GRM.Identity.CharacterKey(ply)
        end
    end

    function QM.SpawnMenuProp(ply, model)
        model = string.lower(tostring(model or ""))
        local ok0, why0 = QM.CanSpawnMenuProp(ply, model)
        if not ok0 then return false, why0 end
        if not util.IsValidModel(model) then return false, "Модель не существует на сервере" end
        if hook.Run("PlayerSpawnProp", ply, model) == false then return false, "Спавн пропов запрещён" end
        local now = CurTime()
        if QM._spawnRate[ply] and now - QM._spawnRate[ply] < 0.4 then return false, "Не так быстро (антиспам)" end
        QM._spawnRate[ply] = now
        local list = cleanRegistry(ply)
        local cap = math.max(1, tonumber(QM.Cfg.menuPropCap) or 24)
        if not ply:IsSuperAdmin() and #list >= cap then
            return false, "Лимит пропов меню: " .. tostring(cap) .. " (удалите свои)"
        end
        local tr = util.TraceLine({ start = ply:EyePos(), endpos = ply:EyePos() + ply:GetAimVector() * 2200, filter = ply })
        local ent = ents.Create("prop_physics")
        if not IsValid(ent) then return false, "Не удалось создать энтити" end
        ent:SetModel(model)
        ent:SetPos(tr.HitPos + tr.HitNormal * 2)
        local ang = (ply:GetPos() - tr.HitPos):Angle()
        ent:SetAngles(Angle(0, ang.y, 0))
        ent:Spawn()
        ent:Activate()
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then phys:Wake() end
        list[#list + 1] = ent
        registerSpawned(ply, ent)
        hook.Run("PlayerSpawnedProp", ply, model, ent)
        return true, ent
    end

    net.Receive(NET_SPAWN, function(_, ply)
        if not IsValid(ply) then return end
        local ok, msg = QM.SpawnMenuProp(ply, net.ReadString())
        if ok then feedCount(ply) else feedToast(ply, tostring(msg)) end
    end)

    local function clearProps(ply)
        local list = QM._menuProps[ply] or {}
        local n = 0
        for _, e in ipairs(list) do if IsValid(e) then e:Remove() n = n + 1 end end
        QM._menuProps[ply] = {}
        return n
    end

    net.Receive(NET_CLEAR, function(_, ply)
        if not IsValid(ply) then return end
        local n = clearProps(ply)
        feedToast(ply, "Убрано ваших пропов: " .. tostring(n))
        feedCount(ply)
    end)

    net.Receive(NET_REMOVE1, function(_, ply)
        if not IsValid(ply) then return end
        local tr = ply.GetEyeTrace and ply:GetEyeTrace() or util.TraceLine({ start = ply:EyePos(), endpos = ply:EyePos() + ply:GetAimVector() * 250, filter = ply })
        local ent = tr and tr.Entity or nil
        if not IsValid(ent) or (ent.GRM_MenuOwner ~= ply and not ply:IsSuperAdmin()) then
            feedToast(ply, "В прицеле нет вашего пропа")
            return
        end
        ent:Remove()
        cleanRegistry(ply)
        feedToast(ply, "Проп убран")
        feedCount(ply)
    end)

    local function sendList(ply)
        if not IsValid(ply) then return end
        local list = cleanRegistry(ply)
        local n = 0
        for _, e in ipairs(list) do if IsValid(e) then n = n + 1 end end
        net.Start(NET_LIST)
            net.WriteUInt(math.min(n, 200), 8)
            local sent = 0
            for _, e in ipairs(list) do
                if IsValid(e) and sent < 200 then
                    sent = sent + 1
                    local dist = 0
                    if e.GetPos and ply.GetPos then
                        local a, b = e:GetPos(), ply:GetPos()
                        if a.Distance then
                            dist = math.floor(a:Distance(b))
                        elseif a.DistToSqr then
                            dist = math.floor(math.sqrt(a:DistToSqr(b)))
                        end
                    end
                    net.WriteString(string.sub(tostring(e:GetModel() or ""), 1, 120))
                    net.WriteUInt(math.Clamp(dist, 0, 65535), 16)
                    net.WriteUInt(e:EntIndex() or 0, 16)
                end
            end
        net.Send(ply)
    end
    net.Receive(NET_LIST, function(_, ply)
        if IsValid(ply) then sendList(ply) end
    end)
    net.Receive(NET_RMIDX, function(_, ply)
        if not IsValid(ply) then return end
        local idx = net.ReadUInt(16)
        local list = cleanRegistry(ply)
        for _, e in ipairs(list) do
            if IsValid(e) and e:EntIndex() == idx and (e.GRM_MenuOwner == ply or ply:IsSuperAdmin()) then
                e:Remove()
                cleanRegistry(ply)
                feedToast(ply, "Проп убран")
                feedCount(ply)
                sendList(ply)
                return
            end
        end
        feedToast(ply, "Объект не найден")
    end)

    hook.Add("PlayerDisconnected", "GRM_QMenu_Disconnect", function(ply)
        if QM._menuProps then QM._menuProps[ply] = nil end
        if QM._spawnRate then QM._spawnRate[ply] = nil end
    end)

    local function anyToolAllowed(ply)
        if IsValid(ply) and ply:IsSuperAdmin() then return true end
        for _, t in ipairs(QM.ToolCatalog) do
            if QM.CanUseTool(ply, t.id) then return true end
        end
        return false
    end

    net.Receive(NET_GUN, function(_, ply)
        if not IsValid(ply) then return end
        if net.ReadBool() then
            if not anyToolAllowed(ply) then
                feedToast(ply, "Вам не разрешён ни один инструмент")
                return
            end
            if not ply:HasWeapon("gmod_tool") then ply:Give("gmod_tool") end
        else
            if ply:HasWeapon("gmod_tool") then ply:StripWeapon("gmod_tool") end
        end
    end)

    net.Receive(NET_TOOL, function(_, ply)
        if not IsValid(ply) then return end
        local id = string.lower(tostring(net.ReadString() or ""))
        if not string.match(id, "^[%w_]+$") then return end
        local ok, why = QM.CanUseTool(ply, id)
        if not ok then
            feedToast(ply, tostring(why or "Инструмент запрещён"))
            return
        end
        if not ply:HasWeapon("gmod_tool") then ply:Give("gmod_tool") end
        ply:ConCommand("gmod_tool \"" .. id .. "\"")
        ply:SelectWeapon("gmod_tool")
    end)

    local function curateAdd(ply, model)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return false, "Только суперадмин" end
        model = string.lower(tostring(model or ""))
        if model == "" or string.find(model, "%.%.") then return false, "Некорректная модель" end
        QM.Cfg.propList = QM.Cfg.propList or {}
        for _, m in ipairs(QM.Cfg.propList) do
            if m == model then return false, "Уже в каталоге" end
        end
        table.insert(QM.Cfg.propList, model)
        QM.Save("prop add")
        return true
    end
    local function curateDel(ply, model)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return false, "Только суперадмин" end
        model = string.lower(tostring(model or ""))
        for i, m in ipairs(QM.Cfg.propList or {}) do
            if m == model then
                table.remove(QM.Cfg.propList, i)
                QM.Save("prop del")
                return true
            end
        end
        return false, "Нет такой модели в каталоге"
    end
    QM.PropCatalogAdd = curateAdd
    QM.PropCatalogDel = curateDel

    net.Receive(NET_CURATE, function(_, ply)
        if not IsValid(ply) then return end
        local op = net.ReadUInt(4)
        local model = net.ReadString()
        if op == 1 then
            local ok, msg = curateAdd(ply, model)
            feedToast(ply, ok and ("В каталог: " .. string.lower(tostring(model))) or tostring(msg))
        elseif op == 2 then
            local ok, msg = curateDel(ply, model)
            feedToast(ply, ok and "Убрано из каталога" or tostring(msg))
        end
    end)

    local function seedCatalog(ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return nil, "Только суперадмин" end
        QM.Cfg.propList = QM.Cfg.propList or {}
        local have = {}
        for _, m in ipairs(QM.Cfg.propList) do have[m] = true end
        local added = 0
        for _, mdl in ipairs(QM.SeedProps) do
            if not have[mdl] and util.IsValidModel(mdl) then
                table.insert(QM.Cfg.propList, mdl)
                have[mdl] = true
                added = added + 1
            end
        end
        if added > 0 then QM.Save("seed +" .. tostring(added)) end
        return added
    end
    QM.SeedCatalog = seedCatalog

    net.Receive(NET_SEED, function(_, ply)
        if not IsValid(ply) then return end
        local n, msg = seedCatalog(ply)
        if n == nil then
            feedToast(ply, tostring(msg or "Нет прав"))
        elseif n == 0 then
            feedToast(ply, "Каталог уже содержит весь набор (или модели отсутствуют на сервере)")
        else
            feedToast(ply, "Мебельный набор: добавлено " .. tostring(n))
        end
    end)

    local OPT_BOOL = {
        playersQ = true, grmBuildMenu = true, propsFree = true,
        whitelistMode = true, protectFurniture = true, adminsToo = true,
        allowProps = true, allowRagdolls = true, allowEffects = true,
        allowNPCs = true, allowSENTs = true, allowSWEPs = true, allowVehiclesQ = true,
    }
    net.Receive(NET_SETOPT, function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        local key = tostring(net.ReadString() or "")
        local isInt = net.ReadBool()
        if isInt then
            local v = net.ReadUInt(16)
            if key == "menuPropCap" then
                QM.Cfg.menuPropCap = math.Clamp(math.floor(v), 1, 500)
                QM.Save("menu cap")
                feedToast(ply, "Лимит пропов: " .. tostring(QM.Cfg.menuPropCap))
            end
        else
            local v = net.ReadBool()
            if OPT_BOOL[key] then
                QM.Cfg[key] = v == true
                QM.Save("opt " .. key)
                feedToast(ply, key .. " = " .. tostring(QM.Cfg[key]))
            end
        end
    end)

    local lastChat = {}
    function QM.HandleChat(ply, text)
        local low = string.lower(string.Trim(text or ""))
        local stamp = tostring(ply) .. "|" .. low
        if lastChat[stamp] == CurTime() then return true end
        if low == "/qm" or low == "/build" then
            lastChat[stamp] = CurTime()
            net.Start(NET_OPEN)
            net.Send(ply)
            return true
        end
        if low == "/qm_diag" then
            if not ply:IsSuperAdmin() then ply:PrintMessage(HUD_PRINTTALK, "[Стройка] Только суперадмин.") return true end
            net.Start(NET_DIAG)
            net.Send(ply)
            ply:PrintMessage(HUD_PRINTTALK, "[Стройка] Дамп обработчиков Q-меню → в КОНСОЛЬ клиента (клавиша ~). Ищите строки «ЧУЖОЙ».")
            return true
        end
        if low == "/qm_seed" then
            local n, msg = seedCatalog(ply)
            ply:PrintMessage(HUD_PRINTTALK, "[Стройка] " .. (n and ("Мебельный набор: +" .. tostring(n)) or tostring(msg)))
            return true
        end
        if low == "/qm_prop_add" then
            if not ply:IsSuperAdmin() then ply:PrintMessage(HUD_PRINTTALK, "[Стройка] Только суперадмин.") return true end
            local tr = ply:GetEyeTrace()
            local mdl = (IsValid(tr.Entity) and tr.Entity.GetModel) and tr.Entity:GetModel() or ""
            local ok, msg = curateAdd(ply, mdl)
            ply:PrintMessage(HUD_PRINTTALK, "[Стройка] " .. (ok and ("В каталог: " .. mdl) or tostring(msg)))
            return true
        end
        if string.sub(low, 1, 17) == "/qm_prop_addmodel" then
            if not ply:IsSuperAdmin() then ply:PrintMessage(HUD_PRINTTALK, "[Стройка] Только суперадмин.") return true end
            local ok, msg = curateAdd(ply, string.sub(string.Trim(text), 19))
            ply:PrintMessage(HUD_PRINTTALK, "[Стройка] " .. (ok and "Добавлено." or tostring(msg)))
            return true
        end
        if low == "/qm_prop_list" then
            if not ply:IsSuperAdmin() then ply:PrintMessage(HUD_PRINTTALK, "[Стройка] Только суперадмин.") return true end
            ply:PrintMessage(HUD_PRINTTALK, "[Стройка] Каталог (" .. tostring(#(QM.Cfg.propList or {})) .. "): " .. table.concat(QM.Cfg.propList or {}, ", "))
            return true
        end
        if string.sub(low, 1, 12) == "/qm_prop_del" then
            if not ply:IsSuperAdmin() then ply:PrintMessage(HUD_PRINTTALK, "[Стройка] Только суперадмин.") return true end
            local ok, msg = curateDel(ply, string.sub(string.Trim(text), 14))
            ply:PrintMessage(HUD_PRINTTALK, "[Стройка] " .. (ok and "Убрано." or tostring(msg)))
            return true
        end
        if low == "/qm_clearprops" then
            local n = clearProps(ply)
            ply:PrintMessage(HUD_PRINTTALK, "[Стройка] Убрано ваших пропов: " .. tostring(n))
            return true
        end
        return false
    end
    hook.Add("PlayerSayTransform", "GRM_QMenu_TransformCmds", function(ply, datapack)
        if not istable(datapack) then return end
        local msg = datapack[1]
        if not isstring(msg) then return end
        if QM.HandleChat and QM.HandleChat(ply, msg) then
            datapack[1] = ""
            datapack.SkipPlayerSay = true
        end
    end)
    hook.Add("PlayerSay", "GRM_QMenu_Cmds", function(ply, text)
        if QM.HandleChat and QM.HandleChat(ply, text) then return "" end
    end)

    QM.Load("старт")
    print("[GRM QMenu] Стройка v" .. QM.Version .. " загружена. Игрок: зажать Q | Админ: /qm | Хаб: /grm_admin → «Инструменты»")
end

-- ============================================================
-- КЛИЕНТ
-- ============================================================
if CLIENT then
    if istable(surface) and surface.CreateFont then
        surface.CreateFont("GRMQ_Title", { font = "Roboto", size = 20, weight = 800, extended = true })
        surface.CreateFont("GRMQ_Sub",   { font = "Roboto", size = 15, weight = 600, extended = true })
        surface.CreateFont("GRMQ_Text",  { font = "Roboto", size = 13, weight = 500, extended = true })
        surface.CreateFont("GRMQ_Small", { font = "Roboto", size = 11, weight = 400, extended = true })
        surface.CreateFont("GRMQ_Tab",   { font = "Roboto", size = 13, weight = 700, extended = true })
    end

    local _C = isfunction(Color) and Color
        or function(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
    local QC = {
        bg = _C(17, 21, 29, 252), head = _C(24, 29, 40, 255), panel = _C(30, 36, 49, 240),
        panel2 = _C(36, 43, 58, 255), line = _C(52, 62, 82, 255),
        acc = _C(64, 145, 240), green = _C(58, 188, 108), red = _C(216, 74, 70),
        yellow = _C(228, 178, 58), text = _C(238, 243, 250), dim = _C(150, 160, 178),
        dim2 = _C(96, 105, 124),
    }

    if isfunction(CreateClientConVar) then
        CreateClientConVar("grm_qmenu_safe", "0", true, false, "1 — без иконок моделей")
        CreateClientConVar("grm_qmenu_profile", "0", true, false, "1 — печать этапов сборки")
    end

    local function safeMode()
        if ConVarExists and ConVarExists("grm_qmenu_safe") then
            local cv = GetConVar("grm_qmenu_safe")
            return cv and cv.GetBool and cv:GetBool() or false
        end
        return false
    end
    local function profileOn()
        if ConVarExists and ConVarExists("grm_qmenu_profile") then
            local cv = GetConVar("grm_qmenu_profile")
            return cv and cv.GetBool and cv:GetBool() or false
        end
        return false
    end

    net.Receive("GRM_QMenu_Sync", function()
        local t = net.ReadTable()
        if not istable(t) then return end
        local d = GRM.QMenu.Cfg or {}
        for k, v in pairs(t) do d[k] = v end
        GRM.QMenu.Cfg = d
        QM._stale = true
    end)

    net.Receive("GRM_QMenu_Feedback", function()
        local op = net.ReadUInt(4)
        if op == 1 then
            GRM.QMenu._count = net.ReadUInt(16)
            GRM.QMenu._cap = net.ReadUInt(16)
        elseif op == 2 then
            GRM.QMenu._toast = net.ReadString()
            GRM.QMenu._toastAt = CurTime() + 3
            GRM.QMenu._toastBad = true
        end
    end)

    net.Receive("GRM_QMenu_Open", function()
        if not (GRM.QMenu and GRM.QMenu.OpenMenu) then return end
        if IsValid(GRM.QMenu._frame) then
            if GRM.QMenu._holdOpen then return end
            if GRM.QMenu.CloseMenu then GRM.QMenu.CloseMenu() end
        else
            GRM.QMenu.OpenMenu(false)
        end
    end)

    local function isOurs(id)
        local s = tostring(id)
        return string.find(s, "GRM", 1, true) ~= nil or string.find(s, "grm_", 1, true) ~= nil
    end
    local function censusQHooks(evs)
        local out = {}
        if not (istable(hook) and isfunction(hook.GetTable)) then return out end
        local ht = hook.GetTable()
        if not istable(ht) then return out end
        for _, ev in ipairs(evs) do
            local t = ht[ev]
            if istable(t) then
                for id in pairs(t) do
                    if not isOurs(id) then out[#out + 1] = { ev = ev, id = tostring(id) } end
                end
            end
        end
        return out
    end
    function QM.DiagDump(why)
        print("[GRM QMenu] ==== дамп обработчиков Q-меню (" .. tostring(why or "?") .. ") ====")
        local evs = { "SpawnMenuOpen", "OnSpawnMenuOpen", "ContextMenuOpen", "OnContextMenuOpen", "PlayerBindPress" }
        local bad = censusQHooks(evs)
        for _, r in ipairs(bad) do
            print(("[GRM QMenu]  %s  [ %s ]  <-- ЧУЖОЙ"):format(r.ev, r.id))
        end
        print(("[GRM QMenu] чужих обработчиков: %d. Диагностика: /qm_diag"):format(#bad))
    end
    net.Receive("GRM_QMenu_Diag", function()
        if QM.DiagDump then QM.DiagDump("/qm_diag") end
    end)
    if istable(concommand) and isfunction(concommand.Add) then
        concommand.Add("grm_qmenu_diag", function()
            if QM.DiagDump then QM.DiagDump("консоль") end
        end)
    end
    if istable(timer) and isfunction(timer.Simple) then
        timer.Simple(6, function()
            local bad = censusQHooks({ "SpawnMenuOpen", "OnSpawnMenuOpen", "ContextMenuOpen" })
            if #bad > 0 then
                local ids = {}
                for _, r in ipairs(bad) do ids[#ids + 1] = r.ev .. "[" .. r.id .. "]" end
                print("[GRM QMenu][!] Q-меню перехватывают чужие хуки: " .. table.concat(ids, ", ")
                    .. " — «Стройка» может не показываться. Диагностика: /qm_diag")
            end
        end)
    end

    local function cfg() return GRM.QMenu.Cfg or {} end
    local function isAdmin() return IsValid(LocalPlayer()) and LocalPlayer():IsSuperAdmin() end

    local function qBlockedForMe()
        local lp = LocalPlayer()
        if IsValid(lp) and (lp:GetNWBool("GRM_Cuffed", false) or lp:GetNWBool("GRM_Stunned", false)) then return true end
        local c = cfg()
        if c.playersQ ~= false then return false end
        if isAdmin() and c.adminsToo ~= true then return false end
        return true
    end

    hook.Add("SpawnMenuOpen", "GRM_QMenu_BlockOpen", function()
        if qBlockedForMe() then return false end
    end)
    hook.Add("ContextMenuOpen", "GRM_QMenu_BlockCtx", function()
        if qBlockedForMe() then return false end
    end)

    local function toolLabel(t)
        local fallback = tostring(t.label or t.id or "")
        local id = tostring(t.id or "")
        if id == "" then return fallback end
        if istable(language) and isfunction(language.GetPhrase) then
            local key = "tool." .. id .. ".name"
            local ok, phrase = pcall(language.GetPhrase, key)
            if ok and isstring(phrase) and phrase ~= "" and phrase ~= key then
                return phrase
            end
        end
        return fallback
    end
    QM.ToolLabel = toolLabel

    -- fitText оставлен (регрессия sim_qmenu_fittext). В Paint v4 не зовётся.
    local fitCache = {}
    local function fitText(txt, font, maxW)
        txt = tostring(txt or "")
        if not istable(surface) then return txt end
        if not (isfunction(surface.SetFont) and isfunction(surface.GetTextSize)) then return txt end
        maxW = isnumber(maxW) and maxW or 0
        if maxW <= 8 then return "" end
        local key = txt .. "|" .. tostring(font) .. "|" .. math.floor(maxW)
        local hit = fitCache[key]
        if hit ~= nil then return hit end
        surface.SetFont(font)
        local w = select(1, surface.GetTextSize(txt))
        if not isnumber(w) or w <= maxW then
            fitCache[key] = txt
            return txt
        end
        local cut, out, guard = txt, txt, 0
        while #cut > 1 do
            guard = guard + 1
            if guard > 256 then break end
            local prevLen = #cut
            local nxt
            if GRM and isfunction(GRM.Utf8Sub) and isfunction(GRM.Utf8Len) then
                nxt = GRM.Utf8Sub(cut, GRM.Utf8Len(cut) - 1)
            end
            if not isstring(nxt) or #nxt >= prevLen then
                nxt = string.sub(cut, 1, prevLen - 1)
            end
            cut = nxt
            local ww = select(1, surface.GetTextSize(cut .. "…"))
            if not isnumber(ww) or ww <= maxW then
                out = cut .. "…"
                fitCache[key] = out
                return out
            end
        end
        fitCache[key] = out
        return out
    end
    QM.FitText = fitText

    local function toolWhy(id)
        if isAdmin() then return nil end
        local c = cfg()
        id = string.lower(id)
        if istable(c.toolDeny) and c.toolDeny[id] == true then return "закрыт чёрным списком" end
        if c.whitelistMode == true and (not istable(c.toolAllow) or c.toolAllow[id] ~= true) then
            return "включён белый режим"
        end
        return nil
    end
    local function canToolLocal(id) return toolWhy(id) == nil end

    local function menuHasContent()
        if isAdmin() then return true end
        local c = cfg()
        if c.grmBuildMenu ~= true then return false end
        if c.allowProps == true then return true end
        for _, t in ipairs(QM.ToolCatalog) do
            if canToolLocal(t.id) then return true end
        end
        return false
    end

    local function mkBtn(p, txt, col)
        local b = vgui.Create("DButton", p)
        b:SetText(txt) b:SetFont("GRMQ_Sub") b:SetTextColor(color_white)
        b.Paint = function(self, pw, ph)
            local cc = col or QC.acc
            if self:IsHovered() then cc = Color(math.min(255, cc.r + 22), math.min(255, cc.g + 22), math.min(255, cc.b + 22)) end
            draw.RoundedBox(5, 0, 0, pw, ph, cc)
        end
        return b
    end

    local function shortModel(mdl)
        local s = tostring(mdl or "")
        s = string.match(s, "([^/\\]+)$") or s
        s = string.gsub(s, "%.[Mm][Dd][Ll]$", "")
        if GRM and isfunction(GRM.Utf8Ellipsis) then return GRM.Utf8Ellipsis(s, 16) end
        if #s > 17 then s = string.sub(s, 1, 15) .. ".." end
        return s
    end

    local HEAD_H, TAB_H, FOOT_H, TOOLS_W, PANEL_W, PAD = 52, 38, 44, 260, 300, 12
    local TILE_W, TILE_H, TILE_ICON = 104, 120, 96
    local ICON_BUDGET = 8

    QM._toolCatsCollapsed = QM._toolCatsCollapsed or {}
    QM._activeTool = QM._activeTool or nil
    QM._iconQueue = QM._iconQueue or {}
    QM._holdOpen = false
    -- _grmFitting: имя оставлено, чтобы регрессия layout_loop видела отказ
    -- от самозаказа раскладки. В v4 SetTall по содержимому не вызывается.
    QM._grmFitting = false

    function QM.CloseMenu()
        QM._holdOpen = false
        QM._iconQueue = {}
        QM._settingsBody = nil
        QM._toolsBody = nil
        if IsValid(QM._frame) then QM._frame:Remove() end
        QM._frame = nil
    end

    local function cvarSet(name, val)
        if RunConsoleCommand then RunConsoleCommand(name, tostring(val)) end
    end
    local function cvarGet(name)
        if GetConVar then
            local cv = GetConVar(name)
            if cv and cv.GetString then return tostring(cv:GetString() or "") end
        end
        return ""
    end

    local function fillSchema(body, toolId)
        if not IsValid(body) then return end
        if isfunction(body.Clear) then body:Clear() end
        local function addHint(txt)
            local l = vgui.Create("DLabel", body)
            l:Dock(TOP) l:SetTall(78) l:SetFont("GRMQ_Text") l:SetTextColor(QC.dim) l:SetWrap(true)
            l:DockMargin(6, 6, 6, 4)
            l:SetText(txt)
            if isfunction(body.AddItem) then body:AddItem(l) end
        end
        if not isstring(toolId) or toolId == "" then
            addHint("Выберите инструмент слева. Параметры появятся здесь, если для него есть схема Стройки.")
            return
        end
        -- Только ручная схема. Авто из ClientConVar сюда не попадает.
        local schema = QM.ResolveSchema(toolId)
        if not schema then
            local name = toolId
            for _, t in ipairs(QM.ToolCatalog) do
                if t.id == toolId then name = toolLabel(t) break end
            end
            addHint("«" .. tostring(name) .. "» — панели в Стройке нет. Инструмент уже выбран: работайте в мире.")
            return
        end
        for _, row in ipairs(schema) do
            local caption = row.label
            if isstring(caption) and caption ~= "" and isstring(row.cvar) and row.cvar ~= "" then
                local kind = row.type
                local tall = 28
                if kind == "choice" or kind == "text" then tall = 48
                elseif kind == "bool" then tall = 24 end
                local box = vgui.Create("DPanel", body)
                box:Dock(TOP) box:SetTall(tall) box:DockMargin(2, 2, 2, 2)
                box:SetPaintBackground(false)
                if isfunction(body.AddItem) then body:AddItem(box) end
                if kind == "bool" then
                    local cb = vgui.Create("DCheckBoxLabel", box)
                    cb:SetPos(4, 3) cb:SetSize(276, 18)
                    cb:SetFont("GRMQ_Text") cb:SetTextColor(QC.text)
                    cb:SetText(caption)
                    cb:SetValue(cvarGet(row.cvar) ~= "0" and 1 or 0)
                    cb.OnChange = function(_, v) cvarSet(row.cvar, v and "1" or "0") end
                else
                    local lab = vgui.Create("DLabel", box)
                    lab:SetPos(4, 2) lab:SetSize(276, 16) lab:SetFont("GRMQ_Small") lab:SetTextColor(QC.dim)
                    lab:SetText(caption)
                    if kind == "choice" then
                        local combo = vgui.Create("DComboBox", box)
                        combo:SetPos(4, 20) combo:SetSize(276, 22)
                        local cur = cvarGet(row.cvar)
                        for _, ch in ipairs(row.choices or {}) do
                            combo:AddChoice(ch[1], ch[2], ch[2] == cur)
                        end
                        combo.OnSelect = function(_, _, _, data) if data then cvarSet(row.cvar, data) end end
                    elseif kind == "number" then
                        local nw = vgui.Create("DNumberWang", box)
                        nw:SetPos(176, 4) nw:SetSize(100, 20)
                        nw:SetMin(-99999) nw:SetMax(99999)
                        nw:SetValue(tonumber(cvarGet(row.cvar)) or 0)
                        nw.OnValueChanged = function(_, v) cvarSet(row.cvar, tostring(v)) end
                    else
                        local te = vgui.Create("DTextEntry", box)
                        te:SetPos(4, 20) te:SetSize(276, 22) te:SetFont("GRMQ_Text")
                        te:SetValue(cvarGet(row.cvar))
                        te.OnEnter = function() cvarSet(row.cvar, te:GetValue() or "") end
                        te.OnLoseFocus = function() cvarSet(row.cvar, te:GetValue() or "") end
                    end
                end
            end
        end
    end

    function QM.OpenMenu(fromHold)
        if IsValid(QM._frame) then return end
        QM._holdOpen = fromHold == true
        local admin = isAdmin()
        if QM._tab == "tools" then QM._tab = "catalog" end
        if QM._tab ~= "catalog" and QM._tab ~= "mine" and QM._tab ~= "settings" then
            QM._tab = "catalog"
        end
        if not admin and QM._tab == "settings" then QM._tab = "catalog" end

        local FW, FH = 1400, 780
        if isfunction(ScrW) and isfunction(ScrH) then
            local sw, sh = ScrW(), ScrH()
            if isnumber(sw) and isnumber(sh) and sw > 0 and sh > 0 then
                FW = math.Clamp(math.floor(sw * 0.88), 1100, 1680)
                FH = math.Clamp(math.floor(sh * 0.84), 640, 960)
            end
        end
        -- Три колонки: меню | инструменты | панель. Иконки в safe-режиме
        -- отключаются отдельно; колонки тулов прятать нельзя.
        local toolsW, panelW = TOOLS_W, PANEL_W
        local tabsY = HEAD_H
        local contY = HEAD_H + TAB_H
        local footY = FH - FOOT_H
        local CW = FW - PAD * 4 - toolsW - panelW
        local CH = footY - contY - PAD

        local t0 = (isfunction(SysTime) and SysTime()) or 0
        local function stage(name)
            if not profileOn() then return end
            local now = (isfunction(SysTime) and SysTime()) or 0
            print(string.format("[GRM QMenu] stage %s: %.1f ms", name, (now - t0) * 1000))
            if (now - t0) * 1000 > 50 then
                print("[GRM QMenu][!] сторож: этап " .. name .. " превысил 50 мс")
            end
            t0 = now
        end

        local f = vgui.Create("DFrame")
        QM._frame = f
        if GRM.UI and isfunction(GRM.UI.Track) then GRM.UI.Track("qmenu", f) end
        f:SetTitle("") f:SetSize(FW, FH) f:Center() f:MakePopup() f:ShowCloseButton(false)
        f:SetDeleteOnClose(true)
        f.Paint = function(_, pw, ph)
            draw.RoundedBox(10, 0, 0, pw, ph, QC.bg)
            draw.RoundedBoxEx(10, 0, 0, pw, HEAD_H, QC.head, true, true, false, false)
            draw.RoundedBox(0, 0, HEAD_H, pw, 2, QC.acc)
            draw.SimpleText("GRM · СТРОЙКА", "GRMQ_Title", 14, 18, QC.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("v" .. tostring(QM.Version), "GRMQ_Small", 168, 20, QC.dim2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local lp = LocalPlayer()
            local ug = "user"
            if IsValid(lp) and isfunction(lp.GetUserGroup) then
                local g = lp:GetUserGroup()
                if isstring(g) and g ~= "" then ug = g end
            end
            local facTxt = ""
            local facName = IsValid(lp) and lp:GetNWString("GRM_Faction", "") or ""
            local facRole = IsValid(lp) and lp:GetNWString("GRM_Role", "") or ""
            if facName ~= "" then
                facTxt = "  ·  " .. facName
                if facRole ~= "" then facTxt = facTxt .. " (" .. facRole .. ")" end
            end
            draw.SimpleText("группа: " .. ug .. facTxt, "GRMQ_Small", 14, 38, QC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        f.Think = function()
            local lp = LocalPlayer()
            local dead = IsValid(lp) and lp.Alive and not lp:Alive()
            local cuffed = IsValid(lp) and (lp:GetNWBool("GRM_Cuffed", false) or lp:GetNWBool("GRM_Stunned", false))
            if dead or cuffed then QM.CloseMenu() return end
            if QM._stale and QM._rebuild then
                QM._stale = false
                QM._rebuild()
            end
        end
        f.OnRemove = function()
            QM._iconQueue = {}
            QM._settingsBody = nil
            QM._toolsBody = nil
            if QM._frame == f then QM._frame = nil end
            QM._holdOpen = false
        end
        local x = mkBtn(f, "✕", QC.red) x:SetPos(FW - 44, 12) x:SetSize(32, 28)
        x.DoClick = function() QM.CloseMenu() end

        local tabDefs = {
            { "catalog", "Каталог", 110 },
            { "mine", "Мои объекты", 128 },
        }
        if admin then tabDefs[#tabDefs + 1] = { "settings", "Настройки ⚙", 128 } end
        local tabX = PAD
        for _, td in ipairs(tabDefs) do
            local id, txt, w = td[1], td[2], td[3]
            local tb = vgui.Create("DButton", f)
            tb:SetText(txt) tb:SetFont("GRMQ_Tab") tb:SetTextColor(QC.dim)
            tb:SetPos(tabX, tabsY + 4) tb:SetSize(w, TAB_H - 8)
            tb.Paint = function(self, pw, ph)
                local sel = QM._tab == id
                if sel then
                    draw.RoundedBoxEx(4, 0, 0, pw, ph, QC.panel2, true, true, false, false)
                    draw.RoundedBox(0, 0, ph - 3, pw, 3, QC.acc)
                elseif self:IsHovered() then
                    draw.RoundedBoxEx(4, 0, 0, pw, ph, QC.panel, true, true, false, false)
                end
                self:SetTextColor(sel and QC.text or QC.dim)
            end
            tb.DoClick = function()
                surface.PlaySound("ui/buttonclick.wav")
                if QM._switchTab then QM._switchTab(id) end
            end
            tabX = tabX + w + 6
        end

        local content = vgui.Create("DPanel", f)
        content:SetPos(PAD, contY) content:SetSize(CW, CH)
        content.Paint = function() end

        local settingsBody, toolsBody
        local COL_HEAD = 26
        do
            local toolsCol = vgui.Create("DPanel", f)
            toolsCol:SetPos(PAD + CW + PAD, contY) toolsCol:SetSize(toolsW, CH)
            toolsCol.Paint = function(_, pw, ph)
                draw.RoundedBox(6, 0, 0, pw, ph, QC.panel)
                draw.RoundedBoxEx(6, 0, 0, pw, COL_HEAD, QC.head, true, true, false, false)
                draw.SimpleText("ИНСТРУМЕНТЫ", "GRMQ_Small", 10, COL_HEAD / 2, QC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            toolsBody = vgui.Create("DScrollPanel", toolsCol)
            toolsBody:SetPos(4, COL_HEAD + 2) toolsBody:SetSize(toolsW - 8, CH - COL_HEAD - 6)
            QM._toolsBody = toolsBody

            local panelCol = vgui.Create("DPanel", f)
            panelCol:SetPos(PAD + CW + PAD + toolsW + PAD, contY) panelCol:SetSize(panelW, CH)
            panelCol.Paint = function(_, pw, ph)
                draw.RoundedBox(6, 0, 0, pw, ph, QC.panel)
                draw.RoundedBoxEx(6, 0, 0, pw, COL_HEAD, QC.head, true, true, false, false)
                draw.SimpleText("ПАРАМЕТРЫ", "GRMQ_Small", 10, COL_HEAD / 2, QC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            settingsBody = vgui.Create("DScrollPanel", panelCol)
            settingsBody:SetPos(4, COL_HEAD + 2) settingsBody:SetSize(panelW - 8, CH - COL_HEAD - 6)
            QM._settingsBody = settingsBody
        end

        local foot = vgui.Create("DPanel", f)
        foot:SetPos(PAD, footY) foot:SetSize(FW - PAD * 2, FOOT_H - PAD)
        local bGun = mkBtn(foot, "Тулган", QC.acc) bGun:SetPos(6, 4) bGun:SetSize(88, 26)
        bGun.DoClick = function()
            net.Start("GRM_QMenu_Toolgun") net.WriteBool(true) net.SendToServer()
        end
        local bOff = mkBtn(foot, "Убрать тулган", QC.panel2) bOff:SetPos(100, 4) bOff:SetSize(120, 26)
        bOff.DoClick = function()
            net.Start("GRM_QMenu_Toolgun") net.WriteBool(false) net.SendToServer()
        end
        local bLast = mkBtn(foot, "Убрать последний", QC.yellow) bLast:SetPos(228, 4) bLast:SetSize(140, 26)
        bLast.DoClick = function()
            net.Start("GRM_QMenu_RemoveOne") net.SendToServer()
        end
        foot.Paint = function(_, pw, ph)
            draw.RoundedBox(6, 0, 0, pw, ph, QC.panel)
            draw.SimpleText("Мои объекты: " .. tostring(QM._count or 0) .. " / " .. tostring(QM._cap or (cfg().menuPropCap or 24)),
                "GRMQ_Text", 380, ph / 2, QC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local toast = (QM._toastAt and CurTime() < QM._toastAt) and (QM._toast or "") or ""
            draw.SimpleText(toast, "GRMQ_Small", pw - 8, ph / 2, QC.red, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        stage("frame")

        local builders = {}

        local function clearEmptyBox(sc)
            if sc and IsValid(sc._emptyBox) then sc._emptyBox:Remove() end
            if sc then sc._emptyBox = nil end
        end
        local function emptyBox(sc, l1, l2)
            clearEmptyBox(sc)
            local box = vgui.Create("DPanel")
            box:SetTall(l2 and 70 or 44)
            box:SetPaintBackground(false)
            local a = vgui.Create("DLabel", box)
            a:SetPos(12, 14) a:SetSize(CW - 40, 22) a:SetFont("GRMQ_Sub") a:SetTextColor(QC.dim) a:SetText(l1)
            if l2 then
                local b = vgui.Create("DLabel", box)
                b:SetPos(12, 40) b:SetSize(CW - 40, 22) b:SetFont("GRMQ_Text") b:SetTextColor(QC.dim2) b:SetText(l2)
            end
            if isfunction(sc.AddItem) then
                box:Dock(TOP)
                sc:AddItem(box)
            else
                box:SetParent(sc)
            end
            sc._emptyBox = box
            return box
        end

        local function enqueueIcon(tile, mdl)
            if safeMode() then return end
            QM._iconQueue[#QM._iconQueue + 1] = { tile = tile, mdl = mdl }
        end

        builders.catalog = function()
            content:Clear()
            QM._iconQueue = {}
            local c = cfg()
            local propsAllowed = admin or c.allowProps == true
            local search = vgui.Create("DTextEntry", content)
            search:SetPos(10, 6) search:SetSize(280, 22) search:SetFont("GRMQ_Text")
            search:SetPlaceholderText("часть пути модели…")
            local sc = vgui.Create("DScrollPanel", content)
            sc:SetPos(6, 34) sc:SetSize(CW - 12, CH - 40)
            local lay = vgui.Create("DIconLayout", sc)
            lay:Dock(FILL) lay:SetSpaceX(8) lay:SetSpaceY(8)

            local function mkTile(mdl, rmbDel)
                local tile = vgui.Create("DButton", lay)
                tile:SetText("") tile:SetSize(TILE_W, TILE_H)
                tile._short = shortModel(mdl)
                tile.Paint = function(self, pw, ph)
                    local hov = self:IsHovered()
                    if hov then draw.RoundedBox(6, 0, 0, pw, ph, QC.acc) end
                    draw.RoundedBox(6, 1, 1, pw - 2, ph - 2, hov and QC.panel2 or QC.panel)
                    draw.SimpleText(self._short or "", "GRMQ_Small", pw / 2, TILE_ICON + 12,
                        hov and QC.text or QC.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                tile.DoClick = function()
                    surface.PlaySound("ui/buttonclickrelease.wav")
                    net.Start("GRM_QMenu_SpawnProp") net.WriteString(mdl) net.SendToServer()
                end
                if rmbDel then
                    tile.DoRightClick = function()
                        net.Start("GRM_QMenu_Curate") net.WriteUInt(2, 4) net.WriteString(mdl) net.SendToServer()
                    end
                end
                enqueueIcon(tile, mdl)
                return tile
            end

            local function rebuildGrid()
                lay:Clear()
                clearEmptyBox(sc)
                QM._iconQueue = {}
                if not propsAllowed then
                    emptyBox(sc, "Спавн пропов игрокам запрещён администрацией.")
                    return
                end
                local q = string.lower(string.Trim(search:GetValue() or ""))
                local shown, total = 0, #(c.propList or {})
                for _, mdl in ipairs(c.propList or {}) do
                    if q == "" or string.find(string.lower(mdl), q, 1, true) then
                        shown = shown + 1
                        lay:Add(mkTile(mdl, admin))
                    end
                end
                if shown == 0 then
                    if total == 0 then
                        emptyBox(sc, "Каталог пуст.",
                            admin and "Суперадмин наполняет его командой /qm_prop_add, глядя на объект. Или /qm_seed."
                            or "Администрация ещё не заполнила каталог.")
                    else
                        emptyBox(sc, "Ничего не найдено по запросу «" .. q .. "».")
                    end
                end
            end
            search.OnChange = rebuildGrid
            rebuildGrid()
        end

        local function fillToolList()
            local sc = toolsBody
            if not IsValid(sc) then return end
            if isfunction(sc.Clear) then sc:Clear() end
            local function scrollAdd(pnl, mTop)
                pnl:Dock(TOP)
                pnl:DockMargin(2, mTop or 2, 2, 0)
                if isfunction(sc.AddItem) then sc:AddItem(pnl) end
            end
            local innerW = math.max(40, toolsW - 28)
            local catsShown = 0
            for _, catDef in ipairs(QM.ToolCategories or {}) do
                local here = {}
                for _, t in ipairs(QM.ToolCatalog) do
                    if (t.cat or "misc") == catDef.id then here[#here + 1] = t end
                end
                if #here > 0 then
                    catsShown = catsShown + 1
                    local collapsed = QM._toolCatsCollapsed[catDef.id] == true
                    local hdr = vgui.Create("DButton")
                    hdr:SetText("") hdr:SetTall(22)
                    local hdrTxt = (collapsed and ">  " or "v  ") .. catDef.name .. "  (" .. tostring(#here) .. ")"
                    hdr.Paint = function(self, pw, ph)
                        draw.RoundedBox(4, 0, 0, pw, ph, self:IsHovered() and QC.line or QC.panel2)
                        draw.SimpleText(hdrTxt, "GRMQ_Small", 8, ph / 2, self:IsHovered() and QC.text or QC.dim,
                            TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                    hdr.DoClick = function()
                        QM._toolCatsCollapsed[catDef.id] = not collapsed
                        fillToolList()
                    end
                    scrollAdd(hdr, 3)
                    if not collapsed then
                        for _, t in ipairs(here) do
                            local why = toolWhy(t.id)
                            local allowed = why == nil
                            local row = vgui.Create("DButton")
                            row:SetText("") row:SetTall(22)
                            local tlabel = fitText(toolLabel(t), "GRMQ_Text", innerW)
                            local tid = t.id
                            row:SetTooltip(toolLabel(t) .. " [" .. tid .. "]\n" .. tostring(t.desc or "")
                                .. (why and ("\nНЕДОСТУПНО: " .. why) or ""))
                            row.Paint = function(self, pw, ph)
                                local active = QM._activeTool == tid
                                if active then
                                    draw.RoundedBox(4, 0, 0, pw, ph, QC.acc)
                                elseif allowed and self:IsHovered() then
                                    draw.RoundedBox(4, 0, 0, pw, ph, QC.panel2)
                                end
                                local tcol = active and QC.text or (allowed and QC.dim or QC.dim2)
                                draw.SimpleText(tlabel, "GRMQ_Text", 8, ph / 2, tcol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                            end
                            row.DoClick = function()
                                if not allowed then
                                    surface.PlaySound("buttons/button10.wav")
                                    QM._toast = "«" .. tostring(toolLabel(t)) .. "» " .. (why or "закрыт")
                                    QM._toastAt = CurTime() + 3
                                    return
                                end
                                surface.PlaySound("ui/buttonclick.wav")
                                QM._activeTool = tid
                                net.Start("GRM_QMenu_SetTool") net.WriteString(tid) net.SendToServer()
                                if settingsBody then fillSchema(settingsBody, tid) end
                            end
                            scrollAdd(row, 1)
                        end
                    end
                end
            end
            if catsShown == 0 then
                emptyBox(sc, "Инструменты закрыты.", "Списки — в /grm_admin.")
            end
            if settingsBody then fillSchema(settingsBody, QM._activeTool) end
        end

        QM._mineRows = QM._mineRows or {}
        net.Receive("GRM_QMenu_List", function()
            local n = net.ReadUInt(8)
            local rows = {}
            for i = 1, n do
                rows[#rows + 1] = { mdl = net.ReadString(), dist = net.ReadUInt(16), idx = net.ReadUInt(16) }
            end
            QM._mineRows = rows
            if QM._tab == "mine" and IsValid(QM._frame) and builders.mine then builders.mine() end
        end)

        builders.mine = function()
            content:Clear()
            local top = vgui.Create("DLabel", content)
            top:SetPos(10, 6) top:SetSize(CW - 20, 20) top:SetFont("GRMQ_Text") top:SetTextColor(QC.dim)
            top:SetText("Заспавненное из меню. Убрать — кнопка в строке или «Убрать все».")
            local bAll = mkBtn(content, "Убрать все", QC.red)
            bAll:SetPos(CW - 130, 4) bAll:SetSize(120, 24)
            bAll.DoClick = function()
                net.Start("GRM_QMenu_ClearProps") net.SendToServer()
                timer.Simple(0.2, function()
                    if IsValid(QM._frame) then net.Start("GRM_QMenu_List") net.SendToServer() end
                end)
            end
            local sc = vgui.Create("DScrollPanel", content)
            sc:SetPos(6, 34) sc:SetSize(CW - 12, CH - 40)
            local rows = QM._mineRows or {}
            if #rows == 0 then
                emptyBox(sc, "Пока нет объектов.", "Заспавните модель из каталога — она появится здесь.")
            else
                for _, r in ipairs(rows) do
                    local row = vgui.Create("DPanel", sc)
                    row:Dock(TOP) row:SetTall(26) row:DockMargin(2, 2, 2, 0)
                    local caption = shortModel(r.mdl) .. "   ·   " .. tostring(r.dist) .. " юн."
                    row.Paint = function(_, pw, ph)
                        draw.RoundedBox(4, 0, 0, pw, ph, QC.panel2)
                        draw.SimpleText(caption, "GRMQ_Text", 8, ph / 2, QC.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                    local b = mkBtn(row, "Убрать", QC.red)
                    b:Dock(RIGHT) b:SetWide(72)
                    local idx = r.idx
                    b.DoClick = function()
                        net.Start("GRM_QMenu_RemoveIdx") net.WriteUInt(idx, 16) net.SendToServer()
                    end
                    if isfunction(sc.AddItem) then sc:AddItem(row) end
                end
            end
            net.Start("GRM_QMenu_List") net.SendToServer()
        end

        builders.settings = function()
            content:Clear()
            if not admin then return end
            local c = cfg()
            local y = 8
            local function optRow(id, labelTxt)
                local cb = vgui.Create("DCheckBoxLabel", content)
                cb:SetPos(12, y) cb:SetSize(CW - 24, 22)
                cb:SetFont("GRMQ_Text") cb:SetTextColor(QC.text)
                cb:SetText(labelTxt)
                cb:SetValue(c[id] == true and 1 or 0)
                cb.OnChange = function(_, val)
                    net.Start("GRM_QMenu_SetOpt")
                        net.WriteString(id)
                        net.WriteBool(false)
                        net.WriteBool(val == true)
                    net.SendToServer()
                end
                y = y + 24
            end
            local hint = vgui.Create("DLabel", content)
            hint:SetPos(12, y) hint:SetSize(CW - 24, 18) hint:SetFont("GRMQ_Small") hint:SetTextColor(QC.dim)
            hint:SetText("Пишется сразу в data/grm_qmenu.json. Дублирует вкладку «Инструменты» хаба.")
            y = y + 22
            optRow("playersQ", "Ванильное Q игрокам (ВЫКЛ = наше меню)")
            optRow("grmBuildMenu", "Меню GRM Стройка вместо ванильного Q")
            optRow("propsFree", "Свободный спавн любых моделей")
            optRow("whitelistMode", "Белый режим инструментов")
            optRow("protectFurniture", "Защита чужих/серверных пропов от remover")
            optRow("adminsToo", "Суперадмину тоже Стройка вместо ванильного Q")
            optRow("allowProps", "Пропы игрокам")
            local capL = vgui.Create("DLabel", content)
            capL:SetPos(12, y + 6) capL:SetSize(240, 20) capL:SetFont("GRMQ_Text") capL:SetTextColor(QC.text)
            capL:SetText("Лимит объектов на игрока:")
            local nw = vgui.Create("DNumberWang", content)
            nw:SetPos(250, y + 4) nw:SetSize(72, 22) nw:SetMin(1) nw:SetMax(500)
            nw:SetValue(tonumber(c.menuPropCap) or 24)
            local bCap = mkBtn(content, "Применить", QC.acc)
            bCap:SetPos(330, y + 4) bCap:SetSize(100, 22)
            bCap.DoClick = function()
                net.Start("GRM_QMenu_SetOpt")
                    net.WriteString("menuPropCap")
                    net.WriteBool(true)
                    net.WriteUInt(math.floor(tonumber(nw:GetValue()) or 24), 16)
                net.SendToServer()
            end
            y = y + 36
            local bSeed = mkBtn(content, "Засидеть каталог мебелью", QC.yellow)
            bSeed:SetPos(12, y) bSeed:SetSize(220, 26)
            bSeed.DoClick = function() net.Start("GRM_QMenu_Seed") net.SendToServer() end
            local bAim = mkBtn(content, "+ модель из прицела", QC.green)
            bAim:SetPos(242, y) bAim:SetSize(180, 26)
            bAim.DoClick = function()
                local tr = LocalPlayer():GetEyeTrace()
                local mdl = (IsValid(tr.Entity) and tr.Entity:GetModel()) or ""
                if mdl == "" then return end
                net.Start("GRM_QMenu_Curate") net.WriteUInt(1, 4) net.WriteString(string.lower(mdl)) net.SendToServer()
            end
        end

        function QM._switchTab(id)
            if id == "tools" then id = "catalog" end
            QM._tab = id
            if builders[id] then builders[id]() end
        end
        QM._rebuild = function()
            if QM._tab == "tools" or not builders[QM._tab] then QM._tab = "catalog" end
            builders[QM._tab]()
            fillToolList()
        end

        builders[QM._tab]()
        fillToolList()
        stage("tab")
    end

    hook.Add("Think", "GRM_QMenu_Icons", function()
        local q = QM._iconQueue
        if not istable(q) or #q == 0 then return end
        if not IsValid(QM._frame) then QM._iconQueue = {} return end
        local n = 0
        while #q > 0 and n < ICON_BUDGET do
            local job = table.remove(q, 1)
            n = n + 1
            if job and IsValid(job.tile) then
                local icon = vgui.Create("SpawnIcon", job.tile)
                icon:SetPos(4, 0) icon:SetSize(TILE_ICON, TILE_ICON)
                icon:SetModel(job.mdl)
                icon:SetMouseInputEnabled(false)
            end
        end
    end)

    -- HOLD-Q как ванильное: press → открыть, release → закрыть.
    hook.Add("PlayerBindPress", "GRM_QMenu_BindBlock", function(_, bind, pressed)
        if bind ~= "+menu" then return end
        if qBlockedForMe() then
            if pressed then
                if menuHasContent() then
                    if not IsValid(QM._frame) then QM.OpenMenu(true) end
                elseif IsValid(LocalPlayer()) then
                    LocalPlayer():PrintMessage(HUD_PRINTCENTER, "Q-меню и стройка закрыты администрацией")
                end
            else
                QM.CloseMenu()
            end
            return true
        end
    end)
end
