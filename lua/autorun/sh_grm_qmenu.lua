--[[--------------------------------------------------------------------
    GRM Q-меню и инструменты v3.0.0 (Код 91) — «GRM Стройка+»

    ПОЛНАЯ ПЕРЕРАБОТКА Кода 83 v2.0.0 (находка 108): урезанное spawnmenu
    теперь настраивается суперадмином КАК ПРОДУКТ, а не командами.

    Модель работы:
      playersQ=true  → игроки живут с ванильным Q (серверные гейты
                       спавна/toolgun по флагам allow* действуют всегда).
      playersQ=false → бинд +menu у игроков глушится универсально (ваниль
                       и ЛЮБОЕ кастомное меню) и вместо него открывается
                       GRM Стройка+ — кастомное меню:
         · Каталог пропов: живой поиск, сетка иконок, лимит N/cap пушами.
         · Инструменты: список с описаниями и поиском, клик = тулган в руку.
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

QM.Version = "3.0.0"

local CONFIG_FILE = "grm_qmenu.json"

-- Каталог известных инструментов (id — toolgun имя, label — по-русски, desc — подсказка)
QM.ToolCatalog = {
    { id = "weld",       label = "Сварка (скрепление пропов)",      desc = "Склеивает два пропа жёстко." },
    { id = "axis",       label = "Ось вращения",                    desc = "Соединение вращением вокруг точки." },
    { id = "ballsocket", label = "Шарнир",                          desc = "Подвижное шаровое соединение." },
    { id = "nocollide",  label = "Без столкновений",                desc = "Два пропа перестают сталкиваться." },
    { id = "rope",       label = "Верёвка",                         desc = "Связывает пропы тросом." },
    { id = "pulley",     label = "Блок-трос",                       desc = "Трос через блок." },
    { id = "winch",      label = "Лебёдка",                         desc = "Трос с управляемой длиной." },
    { id = "hydraulics", label = "Гидравлика",                      desc = "Управляемое давление/ход." },
    { id = "muscle",     label = "Пневмомышца",                     desc = "Упругая связка-амортизатор." },
    { id = "slider",     label = "Слайдер",                         desc = "Движение вдоль оси." },
    { id = "wheel",      label = "Колёса",                          desc = "Ставит колесо на проп." },
    { id = "motor",      label = "Мотор",                           desc = "Вращение по вводу." },
    { id = "thruster",   label = "Двигатель-тяга",                  desc = "Реактивная тяга по клавише." },
    { id = "hoverball",  label = "Ховербол",                        desc = "Поднимает предмет на высоте." },
    { id = "balloon",    label = "Шарики",                          desc = "Воздушный шар с тяговым усилием." },
    { id = "light",      label = "Фонарик-точка",                   desc = "Точечный источник света." },
    { id = "lamp",       label = "Лампа",                           desc = "Прожектор/лампа." },
    { id = "emitter",    label = "Эмиттер (эффекты)",               desc = "Частицы/эффекты — дым, огонь." },
    { id = "dynamite",   label = "Динамит (ВЗРЫВ)",                 desc = "Взрывчатка — опасно." },
    { id = "turret",     label = "Турель (ОРУЖИЕ)",                 desc = "Стреляющая турель — опасно." },
    { id = "igniter",    label = "Поджигатель",                     desc = "Поджигает цель." },
    { id = "spawner",    label = "Спавнер предметов",               desc = "Автоспавн предметов — абуз." },
    { id = "button",     label = "Кнопка",                          desc = "Сигнальная кнопка." },
    { id = "camera",     label = "Камера",                          desc = "Камера наблюдателя." },
    { id = "colour",     label = "Цвет пропа",                      desc = "Перекраска и прозрачность." },
    { id = "material",   label = "Материал пропа",                  desc = "Смена материала/текстуры." },
    { id = "paint",      label = "Краска (декали)",                 desc = "Спрей-декали." },
    { id = "textscreen", label = "Текстовый экран",                 desc = "Табличка с текстом на карте." },
    { id = "trails",     label = "Трейлы",                          desc = "Шлейф за объектом." },
    { id = "remover",    label = "Удаление пропов",                 desc = "Убирает проп; свои — всегда можно." },
    { id = "duplicator", label = "Дубликатор",                      desc = "Копирует конструкции — абуз." },
    { id = "advdupe2",   label = "Adv. Duplicator 2",               desc = "Продвинутый дубликатор — абуз." },
    { id = "precision",  label = "Precision (точное перемещение)",  desc = "Точный сдвиг/поворот." },
    { id = "stacker",    label = "Stacker (стопки пропов)",         desc = "Колонны/ряды одинаковых пропов." },
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
    for _, s in ipairs({ NET_SYNC, NET_SPAWN, NET_REMOVE1, NET_CLEAR, NET_GUN,
        NET_TOOL, NET_CURATE, NET_SEED, NET_SETOPT, NET_FEED, NET_OPEN }) do
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
            "grmBuildMenu", "propsFree", "protectFurniture" }) do
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
        whitelistMode = true, protectFurniture = true,
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
    print("[GRM QMenu] Стройка+ v" .. QM.Version .. " загружена (Код 91). Игрок: Q | Админ: /qm | Хаб: /grm_admin → «Инструменты»")
end

-- ============================================================
-- КЛИЕНТ (меню GRM Стройка+ v3.0.0)
-- ============================================================
if CLIENT then
    if istable(surface) and surface.CreateFont then
        surface.CreateFont("GRMQ_Title", { font = "Roboto", size = 20, weight = 800, extended = true })
        surface.CreateFont("GRMQ_Sub",   { font = "Roboto", size = 15, weight = 600, extended = true })
        surface.CreateFont("GRMQ_Text",  { font = "Roboto", size = 13, weight = 500, extended = true })
        surface.CreateFont("GRMQ_Small", { font = "Roboto", size = 11, weight = 400, extended = true })
    end

    -- guard для тест-стендов без движкового Color (как было в v2)
    local _C = isfunction(Color) and Color
        or function(r, g, b, a) return { r = r, g = g, b = b, a = a or 255 } end
    local QC = {
        bg = _C(17, 21, 29, 252), head = _C(24, 29, 40, 255), panel = _C(30, 36, 49, 240),
        panel2 = _C(36, 43, 58, 255), line = _C(52, 62, 82, 255),
        acc = _C(64, 145, 240), green = _C(58, 188, 108), red = _C(216, 74, 70),
        yellow = _C(228, 178, 58), text = _C(238, 243, 250), dim = _C(150, 160, 178),
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

    -- feedback: op 1 = счётчик, op 2 = тост
    net.Receive("GRM_QMenu_Feedback", function()
        local op = net.ReadUInt(4)
        if op == 1 then
            local n = net.ReadUInt(16)
            local cap = net.ReadUInt(16)
            GRM.QMenu._count, GRM.QMenu._cap = n, cap
            if IsValid(GRM.QMenu._cntLab) then
                GRM.QMenu._cntLab:SetText("Мои пропы: " .. tostring(n) .. " / " .. tostring(cap))
            end
        elseif op == 2 then
            local msg = net.ReadString()
            GRM.QMenu._toast, GRM.QMenu._toastAt = msg, CurTime() + 4
            if IsValid(GRM.QMenu._toastLab) then GRM.QMenu._toastLab:SetText(msg) end
        end
    end)

    net.Receive("GRM_QMenu_Open", function()
        if GRM.QMenu and GRM.QMenu.OpenMenu then GRM.QMenu.OpenMenu() end
    end)

    local function cfg() return GRM.QMenu.Cfg or {} end

    local function isAdmin() return IsValid(LocalPlayer()) and LocalPlayer():IsSuperAdmin() end

    local function qBlockedForMe()
        if isAdmin() then return false end
        return cfg().playersQ == false
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

    local function mkSideBtn(p, txt, id)
        local b = vgui.Create("DButton", p)
        b:SetText(txt) b:SetFont("GRMQ_Sub") b:SetTextColor(QC.dim)
        b._tab = id
        b.Paint = function(self, pw, ph)
            local sel = GRM.QMenu._tab == id
            draw.RoundedBox(4, 0, 0, pw, ph, sel and QC.acc or (self:IsHovered() and QC.panel2 or QC.panel))
            if sel then draw.RoundedBox(0, 0, 0, 3, ph, QC.text) end
        end
        b.DoClick = function()
            surface.PlaySound("ui/buttonclick.wav")
            if GRM.QMenu._switchTab then GRM.QMenu._switchTab(id) end
        end
        return b
    end

    local function lab(p, txt, x, y, w, col, font)
        local d = vgui.Create("DLabel", p)
        d:SetPos(x, y) d:SetSize(w or 400, 20)
        d:SetFont(font or "GRMQ_Text") d:SetTextColor(col or QC.text) d:SetText(txt)
        return d
    end

    -- ── главная рамка ───────────────────────────────────────
    local FRAME_W, FRAME_H = 980, 640

    function QM.OpenMenu()
        if IsValid(QM._frame) then QM._frame:Remove() QM._frame = nil return end
        local admin = isAdmin()
        QM._tab = QM._tab or "catalog"

        local f = vgui.Create("DFrame")
        QM._frame = f
        f:SetTitle("") f:SetSize(FRAME_W, FRAME_H) f:Center() f:MakePopup() f:ShowCloseButton(false)
        f:SetDeleteOnClose(true)
        f.Paint = function(_, pw, ph)
            draw.RoundedBox(10, 0, 0, pw, ph, QC.bg)
            draw.RoundedBoxEx(10, 0, 0, pw, 46, QC.head, true, true, false, false)
            draw.SimpleText("GRM Стройка+", "GRMQ_Title", 16, 23, QC.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            local modeTxt = admin and "режим суперадмина"
                or ((cfg().propsFree == true) and "свободный спавн моделей" or "каталог (" .. tostring(#(cfg().propList or {})) .. ")")
            draw.SimpleText("ванильное Q закрыто · " .. modeTxt, "GRMQ_Text", pw - 60, 23, QC.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            -- тост
            local toast = (QM._toastAt and CurTime() < QM._toastAt) and (QM._toast or "") or ""
            if GRM.QMenu._toastLab then GRM.QMenu._toastLab:SetText(toast) end
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
        local x = mkBtn(f, "✕", QC.red) x:SetPos(FRAME_W - 44, 9) x:SetSize(32, 28)
        x.DoClick = function() if IsValid(f) then f:Remove() end QM._frame = nil end

        -- сайдбар
        local side = vgui.Create("DPanel", f)
        side:SetPos(10, 54) side:SetSize(170, FRAME_H - 110)
        side.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, QC.panel) end
        local sideBtns = {}
        local function addSide(txt, id, yy)
            local b = mkSideBtn(side, txt, id)
            b:SetPos(6, yy) b:SetSize(158, 38)
            sideBtns[#sideBtns + 1] = b
            return yy + 44
        end
        local yy = addSide("Каталог", "catalog", 8)
        yy = addSide("Инструменты", "tools", yy)
        if admin then
            yy = addSide("Куратор каталога", "curate", yy)
            yy = addSide("Настройки", "settings", yy)
        end

        -- контент
        local content = vgui.Create("DPanel", f)
        content:SetPos(188, 54) content:SetSize(FRAME_W - 198, FRAME_H - 110)
        content.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, Color(0, 0, 0, 0)) end

        -- футер
        local foot = vgui.Create("DPanel", f)
        foot:SetPos(10, FRAME_H - 48) foot:SetSize(FRAME_W - 20, 38)
        foot.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, QC.panel) end
        local bGun = mkBtn(foot, "Взять тулган", QC.acc) bGun:SetPos(6, 5) bGun:SetSize(130, 28)
        bGun.DoClick = function()
            net.Start("GRM_QMenu_Toolgun") net.WriteBool(true) net.SendToServer()
        end
        local bGunOff = mkBtn(foot, "Убрать тулган", QC.panel2) bGunOff:SetPos(142, 5) bGunOff:SetSize(130, 28)
        bGunOff.DoClick = function()
            net.Start("GRM_QMenu_Toolgun") net.WriteBool(false) net.SendToServer()
        end
        local bRmOne = mkBtn(foot, "Убрать проп в прицеле", QC.yellow) bRmOne:SetPos(278, 5) bRmOne:SetSize(180, 28)
        bRmOne.DoClick = function()
            net.Start("GRM_QMenu_RemoveOne") net.SendToServer()
        end
        local bRmAll = mkBtn(foot, "Убрать все мои", QC.red) bRmAll:SetPos(464, 5) bRmAll:SetSize(140, 28)
        bRmAll.DoClick = function()
            net.Start("GRM_QMenu_ClearProps") net.SendToServer()
        end
        QM._cntLab = lab(foot, "Мои пропы: " .. tostring(QM._count or 0) .. " / " .. tostring(QM._cap or (cfg().menuPropCap or 24)), 612, 9, 150, QC.dim, "GRMQ_Text")
        QM._toastLab = lab(foot, "", 766, 9, 188, QC.green, "GRMQ_Small")

        -- контент-билдеры (размеры — константы: content = 782×530;
        -- без GetWide() в рантайме, иначе ломаются тест-стенды и любые движки
        -- с отложенной верификацией панели)
        local CW, CH = FRAME_W - 198, FRAME_H - 110
        local builders = {}

        builders.catalog = function()
            content:Clear()
            local c = cfg()
            local propsAllowed = admin or c.allowProps == true
            lab(content, "КАТАЛОГ ПРОПОВ", 10, 6, 300, QC.dim, "GRMQ_Small")
            local search = vgui.Create("DTextEntry", content)
            search:SetPos(150, 2) search:SetSize(CW - 160, 24)
            search:SetFont("GRMQ_Sub") search:SetPlaceholderText("поиск модели… (часть пути)")
            lab(content, "Моделей: " .. tostring(#(c.propList or {})), 10, 30, 300, QC.text, "GRMQ_Sub")
            if c.propsFree == true or admin then
                lab(content, "Свободный спавн: любая модель из каталога ИЛИ по пути (кнопка ниже)", 170, 30, 600, QC.dim, "GRMQ_Small")
            end

            local sc = vgui.Create("DScrollPanel", content)
            sc:SetPos(6, 56) sc:SetSize(CW - 12, CH - 120)
            local lay = vgui.Create("DIconLayout", sc)
            lay:Dock(FILL) lay:SetSpaceX(6) lay:SetSpaceY(6)

            local function rebuildGrid()
                lay:Clear()
                local q = string.lower(string.Trim(search:GetValue() or ""))
                local shown = 0
                if not propsAllowed then
                    lab(sc, "Спавн пропов игрокам запрещён администрацией.", 10, 10, 600, QC.dim, "GRMQ_Sub")
                    return
                end
                for _, mdl in ipairs(c.propList or {}) do
                    if q == "" or string.find(string.lower(mdl), q, 1, true) then
                        shown = shown + 1
                        local icon = vgui.Create("SpawnIcon", lay)
                        icon:SetModel(mdl)
                        icon:SetSize(88, 88)
                        icon:SetTooltip(mdl)
                        icon.DoClick = function()
                            surface.PlaySound("ui/buttonclickrelease.wav")
                            net.Start("GRM_QMenu_SpawnProp")
                                net.WriteString(mdl)
                            net.SendToServer()
                        end
                        lay:Add(icon)
                    end
                end
                if shown == 0 then
                    lab(sc, #c.propList == 0 and "Каталог пуст." or "Ничего не найдено по запросу.", 10, 10, 620, QC.dim, "GRMQ_Sub")
                    if #c.propList == 0 then
                        lab(sc, admin and "Засидите базовой мебелью на вкладке «Куратор каталога»."
                            or "Администрация ещё не заполнила каталог.", 10, 36, 620, QC.dim, "GRMQ_Text")
                    end
                end
            end
            search.OnChange = rebuildGrid
            rebuildGrid()

            if c.propsFree == true or admin then
                local free = vgui.Create("DTextEntry", content)
                free:SetPos(6, CH - 58) free:SetSize(500, 26) free:SetFont("GRMQ_Sub")
                free:SetPlaceholderText("models/путь/к/модели.mdl")
                local bFree = mkBtn(content, "Заспавнить по пути", QC.green)
                bFree:SetPos(512, CH - 58) bFree:SetSize(170, 26)
                bFree.DoClick = function()
                    local m = string.lower(string.Trim(free:GetValue() or ""))
                    if m == "" then return end
                    net.Start("GRM_QMenu_SpawnProp")
                        net.WriteString(m)
                    net.SendToServer()
                end
            end
        end

        builders.tools = function()
            content:Clear()
            lab(content, "ИНСТРУМЕНТЫ TOOLGUN", 10, 6, 300, QC.dim, "GRMQ_Small")
            local search = vgui.Create("DTextEntry", content)
            search:SetPos(180, 2) search:SetSize(CW - 190, 24)
            search:SetFont("GRMQ_Sub") search:SetPlaceholderText("поиск инструмента…")
            local sc = vgui.Create("DScrollPanel", content)
            sc:SetPos(6, 36) sc:SetSize(CW - 12, CH - 44)
            local function rebuild()
                sc:Clear()
                local q = string.lower(string.Trim(search:GetValue() or ""))
                local shown = 0
                for _, tInfo in ipairs(QM.ToolCatalog) do
                    if canToolLocal(tInfo.id) then
                        local hay = string.lower(tInfo.label .. " " .. tInfo.id)
                        if q == "" or string.find(hay, q, 1, true) then
                            shown = shown + 1
                            local card = vgui.Create("DButton", sc)
                            card:SetText("") card:Dock(TOP) card:SetTall(46) card:DockMargin(2, 3, 2, 0)
                            card.Paint = function(self, pw, ph)
                                draw.RoundedBox(5, 0, 0, pw, ph, self:IsHovered() and QC.panel2 or QC.panel)
                                draw.SimpleText(tInfo.label .. "  [" .. tInfo.id .. "]", "GRMQ_Sub", 12, 11, self:IsHovered() and QC.text or QC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                                draw.SimpleText(tInfo.desc or "", "GRMQ_Small", 12, 29, QC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                            end
                            card.DoClick = function()
                                surface.PlaySound("ui/buttonclick.wav")
                                net.Start("GRM_QMenu_SetTool")
                                    net.WriteString(tInfo.id)
                                net.SendToServer()
                                if IsValid(QM._frame) then QM._frame:Remove() QM._frame = nil end
                            end
                        end
                    end
                end
                if shown == 0 then
                    lab(sc, q ~= "" and "Ничего не найдено." or "Инструменты игрокам запрещены (списки — в /grm_admin → «Инструменты»).",
                        10, 12, 660, QC.dim, "GRMQ_Sub")
                end
            end
            search.OnChange = rebuild
            rebuild()
        end

        builders.curate = function()
            content:Clear()
            local c = cfg()
            lab(content, "КУРАТОР КАТАЛОГА (суперадмин)", 10, 6, 400, QC.dim, "GRMQ_Small")
            lab(content, "Моделей в каталоге: " .. tostring(#(c.propList or {})), 10, 28, 300, QC.text, "GRMQ_Sub")

            local bAim = mkBtn(content, "+ проп из прицела", QC.green)
            bAim:SetPos(6, 52) bAim:SetSize(170, 30)
            bAim.DoClick = function()
                local tr = LocalPlayer():GetEyeTrace()
                local mdl = (IsValid(tr.Entity) and tr.Entity:GetModel()) or ""
                if mdl == "" then return end
                net.Start("GRM_QMenu_Curate") net.WriteUInt(1, 4) net.WriteString(string.lower(mdl)) net.SendToServer()
            end
            local entry = vgui.Create("DTextEntry", content)
            entry:SetPos(184, 52) entry:SetSize(320, 30) entry:SetFont("GRMQ_Sub")
            entry:SetPlaceholderText("models/путь/к/модели.mdl")
            local bAdd = mkBtn(content, "+ путь", QC.acc)
            bAdd:SetPos(510, 52) bAdd:SetSize(80, 30)
            bAdd.DoClick = function()
                local m = string.lower(string.Trim(entry:GetValue() or ""))
                if m == "" then return end
                net.Start("GRM_QMenu_Curate") net.WriteUInt(1, 4) net.WriteString(m) net.SendToServer()
            end
            local bSeed = mkBtn(content, "Засидеть базовой мебелью (+" .. tostring(#QM.SeedProps) .. ")", QC.yellow)
            bSeed:SetPos(596, 52) bSeed:SetSize(240, 30)
            bSeed.DoClick = function()
                net.Start("GRM_QMenu_Seed") net.SendToServer()
            end

            lab(content, "ПКМ по иконке — удалить из каталога", 10, 88, 500, QC.dim, "GRMQ_Text")
            local sc = vgui.Create("DScrollPanel", content)
            sc:SetPos(6, 112) sc:SetSize(CW - 12, CH - 120)
            local lay = vgui.Create("DIconLayout", sc)
            lay:Dock(FILL) lay:SetSpaceX(6) lay:SetSpaceY(6)
            for _, mdl in ipairs(c.propList or {}) do
                local icon = vgui.Create("SpawnIcon", lay)
                icon:SetModel(mdl)
                icon:SetSize(88, 88)
                icon:SetTooltip(mdl .. "\nПКМ — удалить")
                icon.DoClick = function()
                    surface.PlaySound("ui/buttonclickrelease.wav")
                    net.Start("GRM_QMenu_SpawnProp")
                        net.WriteString(mdl)
                    net.SendToServer()
                end
                icon.DoRightClick = function()
                    net.Start("GRM_QMenu_Curate") net.WriteUInt(2, 4) net.WriteString(mdl) net.SendToServer()
                end
                lay:Add(icon)
            end
            if #(c.propList or {}) == 0 then
                lab(sc, "Каталог пуст — нажмите «Засидеть базовой мебелью» или добавьте свои модели.", 10, 10, 760, QC.dim, "GRMQ_Sub")
            end
        end

        builders.settings = function()
            content:Clear()
            local c = cfg()
            lab(content, "НАСТРОЙКИ УРЕЗАННОГО Q (суперадмин)", 10, 6, 500, QC.dim, "GRMQ_Small")
            local y = 34
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
                y = y + 28
            end
            optRow("playersQ", "Ванильное Q-меню игрокам (ВЫКЛ = наше меню)")
            optRow("grmBuildMenu", "Меню GRM Стройка+ вместо ванильного Q")
            optRow("propsFree", "Свободный спавн ЛЮБЫХ моделей (ВЫКЛ = только каталог)")
            optRow("whitelistMode", "Белый режим инструментов (только из toolAllow)")
            optRow("protectFurniture", "Защита чужих/серверных пропов от remover игроков")

            lab(content, "Лимит пропов на игрока (menuPropCap):", 12, y + 6, 300, QC.text, "GRMQ_Text")
            local nw = vgui.Create("DNumberWang", content)
            nw:SetPos(320, y + 2) nw:SetSize(90, 24)
            nw:SetMin(1) nw:SetMax(500)
            nw:SetValue(tonumber(c.menuPropCap) or 24)
            local bCap = mkBtn(content, "Применить", QC.acc)
            bCap:SetPos(418, y + 2) bCap:SetSize(100, 24)
            bCap.DoClick = function()
                net.Start("GRM_QMenu_SetOpt")
                    net.WriteString("menuPropCap")
                    net.WriteBool(true)
                    net.WriteUInt(math.floor(tonumber(nw:GetValue()) or 24), 16)
                net.SendToServer()
            end
            y = y + 40
            lab(content, "Инструменты allow/deny и типы спавна (нпс/оружие/транспорт) — в /grm_admin → «Инструменты».", 12, y + 4, 760, QC.dim, "GRMQ_Text")
        end

        function QM._switchTab(id)
            QM._tab = id
            if builders[id] then builders[id]() end
        end
        QM._rebuild = function()
            if builders[QM._tab] then builders[QM._tab]() end
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
