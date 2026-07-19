--[[--------------------------------------------------------------------
    GRM Q-меню и инструменты v3.2.1 (Код 94) — «GRM Стройка+»

    v3.2.1 (Код 94, находка 111, визуальный пас по скриншоту): окно КРУПНЕЕ
    и ШИРЕ (0.72/0.82 экрана, пределы 1080..1360 × 680..900), футер 64px
    в два чистых ряда — кнопки 30px с шагом 8px БЕЗ наслоения, строка
    «Мои пропы / активный инструмент / тост» отделена визуально, шапка
    правой колонки инструментов поднята до 30px.
    v3.2.0 (Код 93, находка 110): у владельца живое меню перекрывал ЧУЖОЙ
    аддон «GRM Restricted Q Menu» (не входит в сборку) — он глушил Q раньше
    нашего хука. Добавлено:
      · авто-сенсус чужих обработчиков SpawnMenuOpen/ContextMenuOpen через
        6с после загрузки клиента — предупреждение в консоль с id-кандидатов
        (hook.GetTable, все вызовы в garдах, стенды не трогает);
      · /qm_diag (суперадмин) и консольная grm_qmenu_diag: полный дамп
        хуков Q-ивентов с пометкой «ЧУЖОЙ» — по id видно, какой аддон
        перехватывает меню;
      · Cfg.adminsToo (дефолт false): суперадмину ТОЖЕ открывать
        «Стройка+» вместо ванильного Q — предпросмотр игрового меню без
        захода игроком (чекбокс в Настройках, SetOpt).
    v3.1.0 (Код 92, находка 109): полная переработка визуала по скриншотам
    владельца. Вёрстка «как у ванильного Q»: слева вкладки + контент,
    СПРАВА — сворачиваемые категории инструментов (клик = тул в руку,
    активный подсвечен, меню НЕ закрывается — как в песочнице GMod).
    Плитки каталога — карточки с иконкой и коротким именем модели,
    шапка показывает «группа: X · фракция (ранг)» (GetUserGroup +
    FactionsData), живой счётчик «Мои пропы N/cap» и активный инструмент
    в футере, тосты отказов — там же. Размер окна адаптируется под экран
    (math.Clamp от ScrW/ScrH с жёсткими гардами для стендов).

    v3.0.0 (Код 91, находка 108): урезанное spawnmenu настраивается
    суперадмином КАК ПРОДУКТ, а не командами.

    Модель работы:
      playersQ=true  → игроки живут с ванильным Q (серверные гейты
                       спавна/toolgun по флагам allow* действуют всегда).
      playersQ=false → бинд +menu у игроков глушится универсально (ваниль
                       и ЛЮБОЕ кастомное меню) и вместо него открывается
                       GRM Стройка+ — кастомное меню:
         · Вкладки слева: Каталог пропов (живой поиск, карточки, лимит
           N/cap пушами); у суперадмина + «Куратор» и «Настройки».
         · Колонка ИНСТРУМЕНТОВ справа: категории (Соединения, Механика,
           Свет, Оформление…), свертка кликом по заголовку, запрещённые
           игроку затемнены с подсказкой, активный тул подсвечен.
         · Куратор (суперадмин): +из прицела, +по пути, удаление ПКМ,
           кнопка «Засидеть базовой мебелью» (seed-набор HL2-моделей,
           сервер отфильтровывает отсутствующие через IsValidModel).
         · Настройки (суперадмин): все флаги «урезанного Q» прямо в меню
           (та же таблица Cfg — вкладка «Инструменты» хаба совместима).
      Безопасность: спавн только через сервер (rate 0.4с, кэп menuPropCap,
      IsValidModel, анти-"..", каталог при propsFree=false); undo/cleanup
      движка подключены (Z откатывает меню-пропы); remover игрока работает
      ТОЛЬКО на его пропах — мебель/перм-энтити GRM защищены (protectFurniture).

    Открытие у игрока: Q (при playersQ=false). У суперадмина: /qm или Q
    (при выключенном ванильном Q у админа тоже наше меню по /qm).

    Конфиг: data/grm_qmenu.json (jsonT 3-м аргументом, н65), синк всем
    клиентам (GRM_QMenu_Sync) при входе и каждой правке.

    Публичное API (совместимо с Кодом 83 и хабом):
      GRM.QMenu.CanUseTool(ply, tool)  → bool, why
      GRM.QMenu.CanSpawn(ply, what)    → bool, why
      GRM.QMenu.CanOpenQ(ply)          → bool
      GRM.QMenu.Version/Cfg/ToolCatalog/Save/Reload
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.QMenu = GRM.QMenu or {}
local QM = GRM.QMenu

QM.Version = "3.2.1"

local CONFIG_FILE = "grm_qmenu.json"

-- Каталог известных инструментов (id — toolgun имя, label — по-русски,
-- desc — подсказка, cat — категория правой колонки меню: connect/mech/
-- light/ui/decor/precise/danger/misc; хаб читает только id+label)
QM.ToolCatalog = {
    -- Соединения (constraints)
    { id = "weld",       label = "Сварка (скрепление пропов)",      desc = "Склеивает два пропа жёстко.",            cat = "connect" },
    { id = "axis",       label = "Ось вращения",                    desc = "Соединение вращением вокруг точки.",     cat = "connect" },
    { id = "ballsocket", label = "Шарнир",                          desc = "Подвижное шаровое соединение.",          cat = "connect" },
    { id = "nocollide",  label = "Без столкновений",                desc = "Два пропа перестают сталкиваться.",      cat = "connect" },
    { id = "rope",       label = "Верёвка",                         desc = "Связывает пропы тросом.",                cat = "connect" },
    { id = "pulley",     label = "Блок-трос",                       desc = "Трос через блок.",                       cat = "connect" },
    { id = "winch",      label = "Лебёдка",                         desc = "Трос с управляемой длиной.",             cat = "connect" },
    { id = "hydraulics", label = "Гидравлика",                      desc = "Управляемое давление/ход.",              cat = "connect" },
    { id = "muscle",     label = "Пневмомышца",                     desc = "Упругая связка-амортизатор.",            cat = "connect" },
    { id = "slider",     label = "Слайдер",                         desc = "Движение вдоль оси.",                    cat = "connect" },
    -- Механика
    { id = "wheel",      label = "Колёса",                          desc = "Ставит колесо на проп.",                 cat = "mech" },
    { id = "motor",      label = "Мотор",                           desc = "Вращение по вводу.",                     cat = "mech" },
    { id = "thruster",   label = "Двигатель-тяга",                  desc = "Реактивная тяга по клавише.",            cat = "mech" },
    { id = "hoverball",  label = "Ховербол",                        desc = "Поднимает предмет на высоте.",           cat = "mech" },
    { id = "balloon",    label = "Шарики",                          desc = "Воздушный шар с тяговым усилием.",       cat = "mech" },
    -- Свет и эффекты
    { id = "light",      label = "Фонарик-точка",                   desc = "Точечный источник света.",               cat = "light" },
    { id = "lamp",       label = "Лампа",                           desc = "Прожектор/лампа.",                       cat = "light" },
    { id = "emitter",    label = "Эмиттер (эффекты)",               desc = "Частицы/эффекты — дым, огонь.",          cat = "light" },
    -- Интерфейс
    { id = "button",     label = "Кнопка",                          desc = "Сигнальная кнопка.",                     cat = "ui" },
    { id = "camera",     label = "Камера",                          desc = "Камера наблюдателя.",                    cat = "ui" },
    { id = "textscreen", label = "Текстовый экран",                 desc = "Табличка с текстом на карте.",           cat = "ui" },
    -- Оформление
    { id = "colour",     label = "Цвет пропа",                      desc = "Перекраска и прозрачность.",             cat = "decor" },
    { id = "material",   label = "Материал пропа",                  desc = "Смена материала/текстуры.",              cat = "decor" },
    { id = "paint",      label = "Краска (декали)",                 desc = "Спрей-декали.",                          cat = "decor" },
    { id = "trails",     label = "Трейлы",                          desc = "Шлейф за объектом.",                     cat = "decor" },
    -- Точность и копирование
    { id = "remover",    label = "Удаление пропов",                 desc = "Убирает проп; свои — всегда можно.",     cat = "precise" },
    { id = "precision",  label = "Precision (точное перемещение)",  desc = "Точный сдвиг/поворот.",                  cat = "precise" },
    { id = "stacker",    label = "Stacker (стопки пропов)",         desc = "Колонны/ряды одинаковых пропов.",        cat = "precise" },
    { id = "duplicator", label = "Дубликатор",                      desc = "Копирует конструкции — абуз.",           cat = "precise" },
    { id = "advdupe2",   label = "Adv. Duplicator 2",               desc = "Продвинутый дубликатор — абуз.",         cat = "precise" },
    -- Опасные
    { id = "dynamite",   label = "Динамит (ВЗРЫВ)",                 desc = "Взрывчатка — опасно.",                   cat = "danger" },
    { id = "turret",     label = "Турель (ОРУЖИЕ)",                 desc = "Стреляющая турель — опасно.",            cat = "danger" },
    { id = "igniter",    label = "Поджигатель",                     desc = "Поджигает цель.",                        cat = "danger" },
    { id = "spawner",    label = "Спавнер предметов",               desc = "Автоспавн предметов — абуз.",            cat = "danger" },
}

-- Порядок категорий правой колонки (id ↔ cat в таблице выше)
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

-- Seed-набор базовой мебели (HL2-коробка; сервер отфильтрует отсутствующие)
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

-- Заводской дефолт конфига (RP-профиль)
local function defaultCfg()
    return {
        playersQ     = true,   -- ванильное Q игрокам
        allowProps   = true,   -- пропы
        allowRagdolls= true,
        allowEffects = false,  -- эффекты — админам
        allowNPCs    = false,
        allowSENTs   = false,
        allowSWEPs   = false,
        allowVehiclesQ = false,
        whitelistMode  = false,-- игрокам ТОЛЬКО инструменты из toolAllow
        toolDeny  = {
            dynamite = true, turret = true, igniter = true, spawner = true,
            duplicator = true, advdupe2 = true, emitter = true,
        },
        toolAllow = {},
        grmBuildMenu = true,   -- при playersQ=false Q открывает GRM Стройку
        propsFree    = false,  -- true → любые модели; false → только propList
        propList     = {},
        menuPropCap  = 24,     -- лимит меню-пропов на игрока
        -- v3.0.0
        protectFurniture = true, -- remover игроков — только на их пропах
        -- v3.2.0
        adminsToo    = false,  -- суперадмину тоже наше меню вместо ванильного Q
    }
end

QM.Cfg = QM.Cfg or defaultCfg()

-- ============================================================
-- СЕРВЕР
-- ============================================================
if SERVER then
    local function jsonT(txt)
        local ok, t = pcall(util.JSONToTable, txt, false, true)
        return (ok and istable(t)) and t or nil
    end

    -- ── сеть ────────────────────────────────────────────────
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
    for _, s in ipairs({ NET_SYNC, NET_SPAWN, NET_REMOVE1, NET_CLEAR, NET_GUN,
        NET_TOOL, NET_CURATE, NET_SEED, NET_SETOPT, NET_FEED, NET_OPEN, NET_DIAG }) do
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

    -- Feedback: op 1 = счётчик пропов (count/cap), op 2 = тост-строка
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
    QM._devFeedCount = feedCount -- тест-экспорт
    QM._devFeedToast = feedToast

    -- ── конфиг ──────────────────────────────────────────────
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

    -- ── проверки (суперадмин всегда может) ──────────────────
    function QM.CanOpenQ(ply)
        if IsValid(ply) and ply:IsSuperAdmin() then return true end
        return QM.Cfg.playersQ == true
    end

    local SpawnFlags = {
        prop = "allowProps", ragdoll = "allowRagdolls", effect = "allowEffects",
        npc = "allowNPCs", sent = "allowSENTs", swep = "allowSWEPs", vehicle = "allowVehiclesQ",
    }

    function QM.CanSpawn(ply, what)
        if IsValid(ply) and ply:IsSuperAdmin() then return true end
        local flag = SpawnFlags[tostring(what or "")]
        if not flag then return true end
        return QM.Cfg[flag] == true
    end

    function QM.CanUseTool(ply, tool)
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

    -- ── серверные гейты спавна по типам ─────────────────────
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

    -- защита мебели/перм-энтити GRM от чужого тулгана (v3.0.0, находка 108)
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

    -- ── меню-пропы: реестр, спавн, удаление ─────────────────
    QM._menuProps = QM._menuProps or {} -- ply → массив энтити
    QM._spawnRate = QM._spawnRate or {}

    local function cleanRegistry(ply)
        local list = QM._menuProps[ply]
        if not istable(list) then list = {} QM._menuProps[ply] = list end
        for i = #list, 1, -1 do
            if not IsValid(list[i]) then table.remove(list, i) end
        end
        return list
    end

    function QM.CanSpawnMenuProp(ply, model)
        if not IsValid(ply) then return false, "?" end
        model = tostring(model or "")
        if model == "" or string.find(model, "%.%.") then return false, "Некорректная модель" end
        if ply:IsSuperAdmin() then return true end
        if QM.Cfg.grmBuildMenu ~= true then return false, "Меню стройки отключено администрацией" end
        if not QM.CanSpawn(ply, "prop") then return false, "Спавн пропов запрещён администрацией" end
        if QM.Cfg.propsFree == true then return true end
        for _, m in ipairs(QM.Cfg.propList or {}) do
            if m == model then return true end
        end
        return false, "Модель вне каталога меню стройки"
    end

    local function registerSpawned(ply, ent)
        -- undo (Z) + cleanup движка — guards от отсутствующих библиотек
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
        if ok then
            feedCount(ply)
        else
            feedToast(ply, tostring(msg))
        end
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

    hook.Add("PlayerDisconnected", "GRM_QMenu_Disconnect", function(ply)
        -- пропы остаются на карте (как в ваниле), реестр памяти чистим
        if QM._menuProps then QM._menuProps[ply] = nil end
        if QM._spawnRate then QM._spawnRate[ply] = nil end
    end)

    -- ── тулган / инструменты ────────────────────────────────
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

    -- ── куратор каталога (только суперадмин) ────────────────
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
            feedToast(ply, ok and "В каталог: " .. string.lower(tostring(model)) or tostring(msg))
        elseif op == 2 then
            local ok, msg = curateDel(ply, model)
            feedToast(ply, ok and "Убрано из каталога" or tostring(msg))
        end
    end)

    -- seed: долить базовую мебель (только валидные на сервере модели)
    local function seedCatalog(ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return 0, "Только суперадмин" end
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
        feedToast(ply, n and ("Мебельный набор: добавлено " .. tostring(n)) or tostring(msg or "Нечего добавлять"))
        if n == 0 then feedToast(ply, "Каталог уже содержит весь набор (или модели отсутствуют на сервере)") end
    end)

    -- ── настройки из меню (только суперадмин) ───────────────
    local OPT_BOOL = {
        playersQ = true, grmBuildMenu = true, propsFree = true,
        whitelistMode = true, protectFurniture = true, adminsToo = true,
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

    -- ── /qm и легаси-команды ────────────────────────────────
    function QM.HandleChat(ply, text)
        local low = string.lower(string.Trim(text or ""))
        if low == "/qm" or low == "/build" then
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
    print("[GRM QMenu] Стройка+ v" .. QM.Version .. " загружена (Код 94). Игрок: Q | Админ: /qm | Хаб: /grm_admin → «Инструменты»")
end

-- ============================================================
-- КЛИЕНТ (меню GRM Стройка+ v3.1.0, Код 92 — вёрстка «как ванильное Q»)
-- ============================================================
if CLIENT then
    if istable(surface) and surface.CreateFont then
        surface.CreateFont("GRMQ_Title", { font = "Roboto", size = 20, weight = 800, extended = true })
        surface.CreateFont("GRMQ_Sub",   { font = "Roboto", size = 15, weight = 600, extended = true })
        surface.CreateFont("GRMQ_Text",  { font = "Roboto", size = 13, weight = 500, extended = true })
        surface.CreateFont("GRMQ_Small", { font = "Roboto", size = 11, weight = 400, extended = true })
        surface.CreateFont("GRMQ_Tab",   { font = "Roboto", size = 13, weight = 700, extended = true })
    end

    -- guard для тест-стендов без движкового Color (стенд гоняет OpenMenu
    -- на «пустых» панелях — любая арифметика на них запрещена, н108)
    local _C = isfunction(Color) and Color
        or function(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
    local QC = {
        bg = _C(17, 21, 29, 252), head = _C(24, 29, 40, 255), panel = _C(30, 36, 49, 240),
        panel2 = _C(36, 43, 58, 255), line = _C(52, 62, 82, 255), ink = _C(13, 16, 23, 255),
        acc = _C(64, 145, 240), green = _C(58, 188, 108), red = _C(216, 74, 70),
        yellow = _C(228, 178, 58), text = _C(238, 243, 250), dim = _C(150, 160, 178),
        dim2 = _C(96, 105, 124),
    }

    -- живой конфиг с сервера
    net.Receive("GRM_QMenu_Sync", function()
        local t = net.ReadTable()
        if not istable(t) then return end
        local d = GRM.QMenu.Cfg or {}
        for k, v in pairs(t) do d[k] = v end
        GRM.QMenu.Cfg = d
        if IsValid(GRM.QMenu._frame) and GRM.QMenu._rebuild then GRM.QMenu._rebuild() end
    end)

    -- feedback: op 1 = счётчик, op 2 = тост (отрисовка — в футере рамки)
    net.Receive("GRM_QMenu_Feedback", function()
        local op = net.ReadUInt(4)
        if op == 1 then
            GRM.QMenu._count = net.ReadUInt(16)
            GRM.QMenu._cap = net.ReadUInt(16)
        elseif op == 2 then
            GRM.QMenu._toast = net.ReadString()
            GRM.QMenu._toastAt = CurTime() + 4
        end
    end)

    net.Receive("GRM_QMenu_Open", function()
        if GRM.QMenu and GRM.QMenu.OpenMenu then GRM.QMenu.OpenMenu() end
    end)

    -- ── диагностика перехватчиков Q (v3.2.0, находка 110) ──
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
        print(("[GRM QMenu] чужих обработчиков: %d. Q открывает чужое окно? Отключите аддон по id выше (garrysmod/addons или коллекция Workshop), затем смените карту."):format(#bad))
    end
    net.Receive("GRM_QMenu_Diag", function()
        if QM.DiagDump then QM.DiagDump("/qm_diag") end
    end)
    if istable(concommand) and isfunction(concommand.Add) then
        concommand.Add("grm_qmenu_diag", function()
            if QM.DiagDump then QM.DiagDump("консоль") end
        end)
    end
    -- автосенсус через 6с: предупреждение в консоль, если меню кто-то перехватывает
    if istable(timer) and isfunction(timer.Simple) then
        timer.Simple(6, function()
            local bad = censusQHooks({ "SpawnMenuOpen", "OnSpawnMenuOpen", "ContextMenuOpen" })
            if #bad > 0 then
                local ids = {}
                for _, r in ipairs(bad) do ids[#ids + 1] = r.ev .. "[" .. r.id .. "]" end
                print("[GRM QMenu][!] Q-меню перехватывают чужие хуки: " .. table.concat(ids, ", ")
                    .. " — «Стройка+» может не показываться. Диагностика: /qm_diag")
            end
        end)
    end

    local function cfg() return GRM.QMenu.Cfg or {} end

    local function isAdmin() return IsValid(LocalPlayer()) and LocalPlayer():IsSuperAdmin() end

    local function qBlockedForMe()
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

    local function canToolLocal(id)
        if isAdmin() then return true end
        local c = cfg()
        id = string.lower(id)
        if istable(c.toolDeny) and c.toolDeny[id] == true then return false end
        if c.whitelistMode == true and (not istable(c.toolAllow) or c.toolAllow[id] ~= true) then return false end
        return true
    end

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

    -- ── виджеты темы ────────────────────────────────────────
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

    local function lab(p, txt, x, y, w, col, font)
        local d = vgui.Create("DLabel", p)
        d:SetPos(x, y) d:SetSize(w or 400, 20)
        d:SetFont(font or "GRMQ_Text") d:SetTextColor(col or QC.text) d:SetText(txt)
        return d
    end

    -- короткое имя модели для плитки (чистый Lua, без engine-хелперов)
    local function shortModel(mdl)
        local s = tostring(mdl or "")
        s = string.match(s, "([^/\\]+)$") or s
        s = string.gsub(s, "%.[Mm][Dd][Ll]$", "")
        if #s > 17 then s = string.sub(s, 1, 15) .. ".." end
        return s
    end

    -- ── плитка-карточка каталога v3.1.0 ─────────────────────
    local TILE_W, TILE_H, TILE_ICON = 96, 118, 96
    local function mkTile(p, mdl, rmbDel)
        local tile = vgui.Create("DButton", p)
        tile:SetText("") tile:SetSize(TILE_W, TILE_H)
        tile:SetTooltip(tostring(mdl) .. (rmbDel and "\nПКМ — убрать из каталога" or ""))
        local icon = vgui.Create("SpawnIcon", tile)
        icon:SetPos(0, 0) icon:SetSize(TILE_ICON, TILE_ICON) icon:SetModel(mdl)
        icon:SetMouseInputEnabled(false)
        local short = shortModel(mdl)
        tile.Paint = function(self, pw, ph)
            local hov = self:IsHovered()
            if hov then draw.RoundedBox(6, 0, 0, pw, ph, QC.acc) end
            local m = hov and 1 or 0
            draw.RoundedBox(6, m, m, pw - 2 * m, ph - 2 * m, hov and QC.panel2 or QC.panel)
            draw.RoundedBoxEx(6, m, TILE_ICON + m, pw - 2 * m, ph - TILE_ICON - 2 * m, QC.head, false, false, true, true)
            draw.SimpleText(short, "GRMQ_Small", pw / 2, TILE_ICON + (ph - TILE_ICON) / 2, hov and QC.text or QC.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        tile.DoClick = function()
            surface.PlaySound("ui/buttonclickrelease.wav")
            net.Start("GRM_QMenu_SpawnProp")
                net.WriteString(mdl)
            net.SendToServer()
        end
        if rmbDel then
            tile.DoRightClick = function()
                net.Start("GRM_QMenu_Curate") net.WriteUInt(2, 4) net.WriteString(mdl) net.SendToServer()
            end
        end
        return tile
    end

    -- ── главная рамка ───────────────────────────────────────
    QM._toolCatsCollapsed = QM._toolCatsCollapsed or {}
    QM._activeTool = QM._activeTool or nil

    function QM.OpenMenu()
        if IsValid(QM._frame) then QM._frame:Remove() QM._frame = nil return end
        local admin = isAdmin()
        if QM._tab ~= "catalog" and QM._tab ~= "curate" and QM._tab ~= "settings" then QM._tab = "catalog" end
        if not admin and QM._tab ~= "catalog" then QM._tab = "catalog" end

        -- размер окна: адаптив от экрана (гарды для стендов без ScrW/ScrH)
        local FW, FH = 1200, 780
        if isfunction(ScrW) and isfunction(ScrH) then
            local sw, sh = ScrW(), ScrH()
            if isnumber(sw) and isnumber(sh) and sw > 0 and sh > 0 then
                FW = math.Clamp(math.floor(sw * 0.72), 1080, 1360)
                FH = math.Clamp(math.floor(sh * 0.82), 680, 900)
            end
        end
        local HEAD_H, PAD, SIDE_W, FOOT_H = 46, 10, 238, 64
        local CW = FW - PAD * 2 - 10 - SIDE_W          -- ширина левой (контентной) зоны
        local toolsX = FW - PAD - SIDE_W
        local tabsY, tabsH = HEAD_H + PAD, 30
        local contY = tabsY + tabsH + 6                -- 92 при шапке 46
        local footY = FH - PAD - FOOT_H
        local CH = footY - 6 - contY                   -- высота контент-панели

        local f = vgui.Create("DFrame")
        QM._frame = f
        f:SetTitle("") f:SetSize(FW, FH) f:Center() f:MakePopup() f:ShowCloseButton(false)
        f:SetDeleteOnClose(true)
        f.Paint = function(_, pw, ph)
            draw.RoundedBox(10, 0, 0, pw, ph, QC.bg)
            draw.RoundedBoxEx(10, 0, 0, pw, HEAD_H, QC.head, true, true, false, false)
            draw.RoundedBox(0, 0, HEAD_H, pw, 2, QC.acc)
            draw.SimpleText("GRM Стройка+", "GRMQ_Title", 14, 15, QC.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("v" .. tostring(QM.Version), "GRMQ_Small", 158, 17, QC.dim2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            -- идентичность игрока: группа + фракция (ранг), как в старом меню владельца
            local lp = LocalPlayer()
            local ug = "user"
            if IsValid(lp) and isfunction(lp.GetUserGroup) then
                local g = lp:GetUserGroup()
                if isstring(g) and g ~= "" then ug = g end
            end
            local facTxt = ""
            if istable(FactionsData) and IsValid(lp) and isfunction(lp.SteamID) then
                local sid = lp:SteamID()
                local s64 = isfunction(lp.SteamID64) and lp:SteamID64() or nil
                for fname, fd in pairs(FactionsData) do
                    if istable(fd) and istable(fd.Members) then
                        local info = fd.Members[sid] or (s64 and fd.Members[s64] or nil)
                        if istable(info) then
                            facTxt = "  ·  " .. tostring(fname)
                            if isstring(info.Role) and info.Role ~= "" then
                                facTxt = facTxt .. " (" .. info.Role .. ")"
                            end
                            break
                        end
                    end
                end
            end
            draw.SimpleText("группа: " .. ug .. facTxt, "GRMQ_Small", 14, 33, QC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local modeTxt = admin and "режим суперадмина"
                or ((cfg().propsFree == true) and "свободный спавн моделей" or "каталог (" .. tostring(#(cfg().propList or {})) .. ")")
            draw.SimpleText("ванильное Q закрыто · " .. modeTxt, "GRMQ_Text", pw - 54, 23, QC.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        f.Think = function()
            -- авто-закрытие: ESC (кликер погашен движком) / смерть.
            -- clickerSeen: не гасим на первом тике, пока clicker ещё не поднялся.
            local lp = LocalPlayer()
            local clickerOn = isfunction(gui and gui.ScreenClickerEnabled) and gui.ScreenClickerEnabled() == true
            if clickerOn then f._clickerSeen = true end
            local dead = IsValid(lp) and lp.Alive and not lp:Alive()
            if (f._clickerSeen and not clickerOn) or dead then
                if IsValid(f) then f:Remove() end
                if QM._frame == f then QM._frame = nil end
            end
        end
        local x = mkBtn(f, "✕", QC.red) x:SetPos(FW - 44, 8) x:SetSize(32, 28)
        x.DoClick = function() if IsValid(f) then f:Remove() end QM._frame = nil end

        -- ── вкладки слева сверху (как в ваниле) ─────────────
        local tabDefs = { { "catalog", "Каталог пропов", 152 } }
        if admin then
            tabDefs[#tabDefs + 1] = { "curate", "Куратор каталога", 158 }
            tabDefs[#tabDefs + 1] = { "settings", "Настройки", 128 }
        end
        local tabX = PAD
        for _, td in ipairs(tabDefs) do
            local id, txt, w = td[1], td[2], td[3]
            local tb = vgui.Create("DButton", f)
            tb:SetText(txt) tb:SetFont("GRMQ_Tab") tb:SetTextColor(QC.dim)
            tb:SetPos(tabX, tabsY) tb:SetSize(w, tabsH)
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

        -- контент-панель (лево) — размеры ТОЛЬКО константами FW/FH (н108)
        local content = vgui.Create("DPanel", f)
        content:SetPos(PAD, contY) content:SetSize(CW, CH)
        content.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, Color(0, 0, 0, 0)) end

        -- ── ПРАВАЯ КОЛОНКА: инструменты, как в ванильном Q ──
        local toolsPane = vgui.Create("DPanel", f)
        toolsPane:SetPos(toolsX, HEAD_H + PAD) toolsPane:SetSize(SIDE_W, FH - HEAD_H - PAD - PAD)
        toolsPane.Paint = function(_, pw, ph)
            draw.RoundedBox(6, 0, 0, pw, ph, QC.panel)
            draw.RoundedBoxEx(6, 0, 0, pw, 30, QC.head, true, true, false, false)
            draw.SimpleText("ИНСТРУМЕНТЫ", "GRMQ_Small", 10, 15, QC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local toolsScroll = vgui.Create("DScrollPanel", toolsPane)
        toolsScroll:SetPos(4, 34) toolsScroll:SetSize(SIDE_W - 8, FH - HEAD_H - PAD - PAD - 38)

        local buildToolsPane
        local function scrollAdd(sc, pnl, mTop, mLeft)
            pnl:DockMargin(mLeft or 2, mTop or 3, 2, 0)
            sc:AddItem(pnl)
        end
        buildToolsPane = function()
            toolsScroll:Clear()
            local catsShown = 0
            for _, catDef in ipairs(QM.ToolCategories or {}) do
                local here, allowedN = {}, 0
                for _, t in ipairs(QM.ToolCatalog) do
                    if (t.cat or "misc") == catDef.id then
                        here[#here + 1] = t
                        if canToolLocal(t.id) then allowedN = allowedN + 1 end
                    end
                end
                -- игроку категорию-трупку не показываем вообще (меньше шума)
                if #here > 0 and (admin or allowedN > 0) then
                    catsShown = catsShown + 1
                    local collapsed = QM._toolCatsCollapsed[catDef.id] == true
                    local hdr = vgui.Create("DButton", toolsScroll)
                    hdr:SetText("") hdr:SetTall(24)
                    hdr.Paint = function(self, pw, ph)
                        draw.RoundedBox(4, 0, 0, pw, ph, self:IsHovered() and QC.line or QC.panel2)
                        draw.SimpleText((collapsed and ">  " or "v  ") .. catDef.name .. "  (" .. tostring(allowedN) .. "/" .. tostring(#here) .. ")",
                            "GRMQ_Text", 8, ph / 2, self:IsHovered() and QC.text or QC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    end
                    hdr.DoClick = function()
                        surface.PlaySound("ui/buttonclick.wav")
                        QM._toolCatsCollapsed[catDef.id] = not collapsed
                        buildToolsPane()
                    end
                    scrollAdd(toolsScroll, hdr, 4)
                    if not collapsed then
                        for _, t in ipairs(here) do
                            local allowed = canToolLocal(t.id)
                            local row = vgui.Create("DButton", toolsScroll)
                            row:SetText("") row:SetTall(30)
                            row:SetTooltip(tostring(t.label) .. " [" .. tostring(t.id) .. "]\n" .. tostring(t.desc or "")
                                .. (allowed and "" or "\nНЕДОСТУПНО: закрыто администрацией"))
                            local tid, tlabel = t.id, t.label
                            row.Paint = function(self, pw, ph)
                                local active = QM._activeTool == tid
                                if active then
                                    draw.RoundedBox(4, 0, 0, pw, ph, QC.acc)
                                elseif allowed and self:IsHovered() then
                                    draw.RoundedBox(4, 0, 0, pw, ph, QC.panel2)
                                end
                                local tcol = active and QC.text or (allowed and (self:IsHovered() and QC.text or QC.dim) or QC.dim2)
                                draw.RoundedBox(0, 0, 0, 3, ph, active and QC.text or (allowed and QC.acc or QC.line))
                                draw.SimpleText(tlabel, "GRMQ_Text", 12, ph / 2, tcol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                                draw.SimpleText("[" .. tid .. "]", "GRMQ_Small", pw - 8, ph / 2,
                                    active and QC.text or QC.dim2, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                            end
                            row.DoClick = function()
                                if not allowed then
                                    surface.PlaySound("buttons/button10.wav")
                                    QM._toast = "«" .. tostring(tlabel) .. "» закрыт администрацией"
                                    QM._toastAt = CurTime() + 3
                                    return
                                end
                                surface.PlaySound("ui/buttonclick.wav")
                                QM._activeTool = tid
                                net.Start("GRM_QMenu_SetTool")
                                    net.WriteString(tid)
                                net.SendToServer()
                            end
                            scrollAdd(toolsScroll, row, 1, 12)
                        end
                    end
                end
            end
            if catsShown == 0 then
                lab(toolsScroll, "Инструменты закрыты", 10, 10, 200, QC.dim, "GRMQ_Text")
                lab(toolsScroll, "администрацией (списки —", 10, 30, 210, QC.dim2, "GRMQ_Small")
                lab(toolsScroll, "в /grm_admin → «Инструменты»).", 10, 46, 210, QC.dim2, "GRMQ_Small")
            end
        end
        buildToolsPane()

        -- ── ФУТЕР: действия + счётчик + активный тул + тосты ─
        local foot = vgui.Create("DPanel", f)
        foot:SetPos(PAD, footY) foot:SetSize(CW, FOOT_H)
        local bGun = mkBtn(foot, "Взять тулган", QC.acc) bGun:SetPos(6, 6) bGun:SetSize(124, 30)
        bGun.DoClick = function()
            net.Start("GRM_QMenu_Toolgun") net.WriteBool(true) net.SendToServer()
        end
        local bGunOff = mkBtn(foot, "Убрать тулган", QC.panel2) bGunOff:SetPos(138, 6) bGunOff:SetSize(124, 30)
        bGunOff.DoClick = function()
            net.Start("GRM_QMenu_Toolgun") net.WriteBool(false) net.SendToServer()
        end
        local bRmOne = mkBtn(foot, "Убрать проп в прицеле", QC.yellow) bRmOne:SetPos(270, 6) bRmOne:SetSize(184, 30)
        bRmOne.DoClick = function()
            net.Start("GRM_QMenu_RemoveOne") net.SendToServer()
        end
        local bRmAll = mkBtn(foot, "Убрать все мои", QC.red) bRmAll:SetPos(462, 6) bRmAll:SetSize(140, 30)
        bRmAll.DoClick = function()
            net.Start("GRM_QMenu_ClearProps") net.SendToServer()
        end
        foot.Paint = function(_, pw, ph)
            draw.RoundedBox(6, 0, 0, pw, ph, QC.panel)
            draw.RoundedBox(0, 6, 38, pw - 12, 1, QC.line)
            draw.SimpleText("Мои пропы: " .. tostring(QM._count or 0) .. " / " .. tostring(QM._cap or (cfg().menuPropCap or 24)),
                "GRMQ_Text", 8, ph - 12, QC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local act = "нет"
            if isstring(QM._activeTool) then
                for _, t in ipairs(QM.ToolCatalog) do
                    if t.id == QM._activeTool then act = t.label break end
                end
            end
            draw.SimpleText("Инструмент: " .. act, "GRMQ_Small", 220, ph - 12, QC.dim2, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local toast = (QM._toastAt and CurTime() < QM._toastAt) and (QM._toast or "") or ""
            draw.SimpleText(toast, "GRMQ_Small", pw - 8, ph - 12, QC.green, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        -- ── строители контента вкладок ──────────────────────
        local builders = {}

        local function emptyBox(sc, l1, l2)
            lab(sc, l1, 12, 14, CW - 40, QC.dim, "GRMQ_Sub")
            if l2 then lab(sc, l2, 12, 40, CW - 40, QC.dim2, "GRMQ_Text") end
        end

        builders.catalog = function()
            content:Clear()
            local c = cfg()
            local propsAllowed = admin or c.allowProps == true
            lab(content, "ПОИСК", 10, 8, 46, QC.dim, "GRMQ_Small")
            local search = vgui.Create("DTextEntry", content)
            search:SetPos(60, 4) search:SetSize(280, 22)
            search:SetFont("GRMQ_Text") search:SetPlaceholderText("часть пути модели…")
            lab(content, "Моделей: " .. tostring(#(c.propList or {})), 350, 8, 120, QC.dim, "GRMQ_Small")
            local freeOn = (c.propsFree == true or admin) and propsAllowed
            if freeOn then
                lab(content, "Свободный спавн: любая модель по пути — строка внизу", 476, 8, CW - 490, QC.dim2, "GRMQ_Small")
            end

            local sc = vgui.Create("DScrollPanel", content)
            sc:SetPos(6, 34) sc:SetSize(CW - 12, CH - 40 - (freeOn and 38 or 0))
            local lay = vgui.Create("DIconLayout", sc)
            lay:Dock(FILL) lay:SetSpaceX(8) lay:SetSpaceY(8)

            local function rebuildGrid()
                lay:Clear()
                if not propsAllowed then
                    emptyBox(sc, "Спавн пропов игрокам запрещён администрацией.")
                    return
                end
                local q = string.lower(string.Trim(search:GetValue() or ""))
                local shown = 0
                for _, mdl in ipairs(c.propList or {}) do
                    if q == "" or string.find(string.lower(mdl), q, 1, true) then
                        shown = shown + 1
                        lay:Add(mkTile(lay, mdl, false))
                    end
                end
                if shown == 0 then
                    if #(c.propList or {}) == 0 then
                        emptyBox(sc, "Каталог пуст.",
                            admin and "Засидите базовой мебелью на вкладке «Куратор каталога»."
                            or "Администрация ещё не заполнила каталог.")
                    else
                        emptyBox(sc, "Ничего не найдено по запросу «" .. q .. "».")
                    end
                end
            end
            search.OnChange = rebuildGrid
            rebuildGrid()

            if freeOn then
                local free = vgui.Create("DTextEntry", content)
                free:SetPos(6, CH - 34) free:SetSize(360, 26) free:SetFont("GRMQ_Text")
                free:SetPlaceholderText("models/путь/к/модели.mdl")
                local bFree = mkBtn(content, "Заспавнить по пути", QC.green)
                bFree:SetPos(374, CH - 34) bFree:SetSize(160, 26)
                bFree.DoClick = function()
                    local m = string.lower(string.Trim(free:GetValue() or ""))
                    if m == "" then return end
                    net.Start("GRM_QMenu_SpawnProp")
                        net.WriteString(m)
                    net.SendToServer()
                end
            end
        end

        builders.curate = function()
            content:Clear()
            local c = cfg()
            lab(content, "КУРАТОР КАТАЛОГА (суперадмин)", 10, 4, 400, QC.dim, "GRMQ_Small")
            lab(content, "Моделей: " .. tostring(#(c.propList or {})), 420, 4, 100, QC.dim, "GRMQ_Small")

            local bAim = mkBtn(content, "+ из прицела", QC.green)
            bAim:SetPos(6, 26) bAim:SetSize(124, 28)
            bAim.DoClick = function()
                local tr = LocalPlayer():GetEyeTrace()
                local mdl = (IsValid(tr.Entity) and tr.Entity:GetModel()) or ""
                if mdl == "" then return end
                net.Start("GRM_QMenu_Curate") net.WriteUInt(1, 4) net.WriteString(string.lower(mdl)) net.SendToServer()
            end
            local entry = vgui.Create("DTextEntry", content)
            entry:SetPos(138, 26) entry:SetSize(230, 28) entry:SetFont("GRMQ_Text")
            entry:SetPlaceholderText("models/путь/к/модели.mdl")
            local bAdd = mkBtn(content, "+ путь", QC.acc)
            bAdd:SetPos(374, 26) bAdd:SetSize(64, 28)
            bAdd.DoClick = function()
                local m = string.lower(string.Trim(entry:GetValue() or ""))
                if m == "" then return end
                net.Start("GRM_QMenu_Curate") net.WriteUInt(1, 4) net.WriteString(m) net.SendToServer()
            end
            local bSeed = mkBtn(content, "Засидеть мебелью (+ " .. tostring(#QM.SeedProps) .. ")", QC.yellow)
            bSeed:SetPos(444, 26) bSeed:SetSize(196, 28)
            bSeed.DoClick = function()
                net.Start("GRM_QMenu_Seed") net.SendToServer()
            end

            lab(content, "Клик — заспавнить · ПКМ по карточке — убрать из каталога", 10, 62, 500, QC.dim2, "GRMQ_Text")
            local sc = vgui.Create("DScrollPanel", content)
            sc:SetPos(6, 84) sc:SetSize(CW - 12, CH - 92)
            local lay = vgui.Create("DIconLayout", sc)
            lay:Dock(FILL) lay:SetSpaceX(8) lay:SetSpaceY(8)
            local n = 0
            for _, mdl in ipairs(c.propList or {}) do
                n = n + 1
                lay:Add(mkTile(lay, mdl, true))
            end
            if n == 0 then
                emptyBox(sc, "Каталог пуст —", "нажмите «Засидеть мебелью» или добавьте свои модели.")
            end
        end

        builders.settings = function()
            content:Clear()
            local c = cfg()
            lab(content, "НАСТРОЙКИ УРЕЗАННОГО Q (суперадмин)", 10, 4, 500, QC.dim, "GRMQ_Small")
            local y = 28
            local function optRow(id, labelTxt)
                local cb = vgui.Create("DCheckBoxLabel", content)
                cb:SetPos(12, y) cb:SetSize(560, 22)
                cb:SetFont("GRMQ_Text") cb:SetTextColor(QC.text)
                cb:SetText(labelTxt .. "   [" .. id .. "]")
                cb:SetValue(c[id] == true and 1 or 0)
                cb.OnChange = function(_, val)
                    net.Start("GRM_QMenu_SetOpt")
                        net.WriteString(id)
                        net.WriteBool(false)
                        net.WriteBool(val == true)
                    net.SendToServer()
                end
                y = y + 26
            end
            optRow("playersQ", "Ванильное Q-меню игрокам (ВЫКЛ = наше меню)")
            optRow("grmBuildMenu", "Меню GRM Стройка+ вместо ванильного Q")
            optRow("propsFree", "Свободный спавн ЛЮБЫХ моделей (ВЫКЛ = только каталог)")
            optRow("whitelistMode", "Белый режим инструментов (только из toolAllow)")
            optRow("protectFurniture", "Защита чужих/серверных пропов от remover игроков")
            optRow("adminsToo", "Суперадмину тоже «Стройка+» вместо ванильного Q (предпросмотр)")

            lab(content, "Лимит пропов на игрока (menuPropCap):", 12, y + 7, 300, QC.text, "GRMQ_Text")
            local nw = vgui.Create("DNumberWang", content)
            nw:SetPos(316, y + 3) nw:SetSize(84, 24)
            nw:SetMin(1) nw:SetMax(500)
            nw:SetValue(tonumber(c.menuPropCap) or 24)
            local bCap = mkBtn(content, "Применить", QC.acc)
            bCap:SetPos(408, y + 3) bCap:SetSize(100, 24)
            bCap.DoClick = function()
                net.Start("GRM_QMenu_SetOpt")
                    net.WriteString("menuPropCap")
                    net.WriteBool(true)
                    net.WriteUInt(math.floor(tonumber(nw:GetValue()) or 24), 16)
                net.SendToServer()
            end
            y = y + 36
            lab(content, "Инструменты allow/deny и типы спавна (нпс/оружие/транспорт) — в /grm_admin → «Инструменты».",
                12, y + 4, CW - 40, QC.dim2, "GRMQ_Text")
        end

        function QM._switchTab(id)
            QM._tab = id
            if builders[id] then builders[id]() end
        end
        QM._rebuild = function()
            if not builders[QM._tab] then QM._tab = "catalog" end
            builders[QM._tab]()
            if buildToolsPane then buildToolsPane() end
        end

        builders[QM._tab]()
    end

    -- универсальный слой: бинд +menu глушится, открываем наше меню
    hook.Add("PlayerBindPress", "GRM_QMenu_BindBlock", function(_, bind, pressed)
        if not pressed then return end
        if bind ~= "+menu" then return end
        if qBlockedForMe() then
            if menuHasContent() then
                QM.OpenMenu()
            elseif IsValid(LocalPlayer()) then
                LocalPlayer():PrintMessage(HUD_PRINTCENTER, "Q-меню и стройка закрыты администрацией")
            end
            return true
        end
    end)
end
