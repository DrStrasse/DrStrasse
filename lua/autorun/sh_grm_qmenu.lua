--[[--------------------------------------------------------------------
    GRM Q-меню и инструменты v2.0.0 (Код 83) — управление песочницей

    v2.0.0: когда ванильное Q игрокам ЗАКРЫТО (playersQ=false), Q теперь
    открывает СОБСТВЕННОЕ меню стройки GRM — игроки могут ставить
    разрешённые пропы и выбирать разрешённые инструменты, НЕ имея доступа
    к стандартному spawnmenu (абуз исключён: каталог пропов курирует
    суперадмин — кнопка «+ проп из прицела» или /qm_prop_add; инструменты —
    те же списки allow/deny/whitelist; спавн идёт через сервер с rate-limit
    и кэпом). Флаги grmBuildMenu/propsFree — во вкладке «Инструменты» хаба.

    v1.1.0: конфиг ТЕПЕРЬ синкается всем клиентам

    Единая точка настройки того, что игрокам разрешено делать через
    Q-меню и toolgun. Суперадмин — вне всех ограничений.

    v1.1.0 (findings 98): конфиг ТЕПЕРЬ синкается всем клиентам
    (GRM_QMenu_Sync: на вход и после каждой правки из хаба — раньше
    клиент держал дефолт и клиентские гейты «приоткрывались»), а флаг
    playersQ закрывает и ВАНИЛЬНОЕ, и КАСТОМНОЕ Q-меню: дополнительный
    универсальный слой PlayerBindPress глушит сам бинд "+menu", поэтому
    НИ ОДИН аддон спавн-меню, открывающийся по Q, не стартует.
    (Слои 2/3 — спавн по типам и toolgun — серверные и так работают
    против любой менюшки.)

    Настройка: /grm_admin → вкладка «Инструменты» (суперадмин).
    Конфиг персистится: data/grm_qmenu.json (jsonT 3-им аргументом, н65).

    Публичное API (для сторонних модулей и сим-стендов):
      GRM.QMenu.CanUseTool(ply, tool)  → bool, why  — проверка toolgun-инструмента
      GRM.QMenu.CanSpawn(ply, what)    → bool, why  — "prop|ragdoll|effect|npc|sent|swep|vehicle"
      GRM.QMenu.CanOpenQ(ply)          → bool       — открытие спавн-меню
      GRM.QMenu.Save()/Reload()
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.QMenu = GRM.QMenu or {}
local QM = GRM.QMenu

QM.Version = "2.0.0"

local CONFIG_FILE = "grm_qmenu.json"

-- Каталог известных инструментов (для вкладки в /grm_admin):
-- id — имя инструмента toolgun, label — по-русски.
QM.ToolCatalog = {
    { id = "weld",       label = "Сварка (скрепление пропов)" },
    { id = "axis",       label = "Ось вращения" },
    { id = "ballsocket", label = "Шарнир" },
    { id = "nocollide",  label = "Без столкновений" },
    { id = "rope",       label = "Верёвка" },
    { id = "pulley",     label = "Блок-трос" },
    { id = "winch",      label = "Лебёдка" },
    { id = "hydraulics", label = "Гидравлика" },
    { id = "muscle",     label = "Пневмомышца" },
    { id = "slider",     label = "Слайдер" },
    { id = "wheel",      label = "Колёса" },
    { id = "motor",      label = "Мотор" },
    { id = "thruster",   label = "Двигатель-тяга" },
    { id = "hoverball",  label = "Ховербол" },
    { id = "balloon",    label = "Шарики" },
    { id = "light",      label = "Фонарик-точка" },
    { id = "lamp",       label = "Лампа" },
    { id = "emitter",    label = "Эмиттер (эффекты)" },
    { id = "dynamite",   label = "Динамит (ВЗРЫВ)" },
    { id = "turret",     label = "Турель (ОРУЖИЕ)" },
    { id = "igniter",    label = "Поджигатель" },
    { id = "spawner",    label = "Спавнер предметов" },
    { id = "button",     label = "Кнопка" },
    { id = "camera",     label = "Камера" },
    { id = "colour",     label = "Цвет пропа" },
    { id = "material",   label = "Материал пропа" },
    { id = "paint",      label = "Краска (декали)" },
    { id = "textscreen", label = "Текстовый экран" },
    { id = "trails",     label = "Трейлы" },
    { id = "remover",    label = "Удаление пропов" },
    { id = "duplicator", label = "Дубликатор" },
    { id = "advdupe2",   label = "Adv. Duplicator 2" },
    { id = "precision",  label = "Precision (точное перемещение)" },
    { id = "stacker",    label = "Stacker (стопки пропов)" },
}

-- Заводской дефолт конфига (RP-профиль):
-- игрокам Q открыто, но опасные инструменты и спавн «боевого» контента закрыты.
local function defaultCfg()
    return {
        playersQ     = true,   -- Q-меню доступно игрокам
        allowProps   = true,   -- пропы (sbox-лимиты движка действуют)
        allowRagdolls= true,
        allowEffects = false,  -- эффекты (smoke/explosion и т.п.) — админам
        allowNPCs    = false,
        allowSENTs   = false,  -- энтити из Q (кроме наших GRM — они AdminOnly)
        allowSWEPs   = false,  -- оружие из Q
        allowVehiclesQ = false,-- транспорт из Q (через дилера/магазин!)
        whitelistMode  = false,-- true → игрокам разрешены ТОЛЬКО инструменты из toolAllow
        toolDeny  = {          -- игрокам запрещено (чёрный список)
            dynamite = true, turret = true, igniter = true, spawner = true,
            duplicator = true, advdupe2 = true, emitter = true,
        },
        toolAllow = {},        -- белый список (при whitelistMode=true)
        -- v2.0.0: собственное меню стройки при закрытом ванильном Q
        grmBuildMenu = true,   -- Q у игрока открывает меню GRM (пропы/инструменты)
        propsFree    = false,  -- true → любые модели; false → только propList
        propList     = {},     -- кураторский каталог моделей (массив строк)
        menuPropCap  = 24,     -- сколько меню-пропов может держать игрок на карте
    }
end

QM.Cfg = defaultCfg()

-- ============================================================
-- СЕРВЕР
-- ============================================================
if SERVER then
    local function jsonT(txt) return util.JSONToTable(txt, false, true) end

    -- v1.1.0: синк конфига всем клиентам (раньше клиент жил с дефолтом
    -- и клиентские гейты открытия Q работали некорректно после правок хаба)
    local NET_SYNC = "GRM_QMenu_Sync"
    util.AddNetworkString(NET_SYNC)
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

    local function sanitizeList(t)
        local out = {}
        if istable(t) then
            for k, v in pairs(t) do
                if v == true then
                    if isstring(k) then out[k] = true
                    elseif isnumber(k) and isstring(v) then out[v] = true end -- страховка от массива
                end
            end
            for _, v in ipairs(istable(t) and t or {}) do
                if isstring(v) then out[v] = true end -- массив имён
            end
        end
        return out
    end

    function QM.Load(why)
        if not file.Exists(CONFIG_FILE, "DATA") then return false end
        local raw = file.Read(CONFIG_FILE, "DATA") or ""
        if raw == "" then return false end
        local ok, t = pcall(jsonT, raw)
        if not ok or not istable(t) then
            print("[GRM QMenu][!] конфиг повреждён, оставлены дефолты (" .. tostring(why) .. ")")
            return false
        end
        local d = defaultCfg()
        for _, k in ipairs({ "playersQ", "allowProps", "allowRagdolls", "allowEffects",
            "allowNPCs", "allowSENTs", "allowSWEPs", "allowVehiclesQ", "whitelistMode",
            "grmBuildMenu", "propsFree" }) do
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
        d.menuPropCap = math.max(1, math.floor(tonumber(t.menuPropCap) or defaultCfg().menuPropCap))
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
        QM.PushSync(nil) -- v1.1.0: клиенты сразу получают свежий конфиг
        return true
    end

    -- ── Проверки (публичные; суперадмин всегда может) ─────────
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

    -- ── Хуки песочницы ────────────────────────────────────────
    -- (SpawnMenuOpen/ContextMenuOpen — клиентские хуки, см. ниже
    --  if CLIENT; здесь только серверные гейты спавна и toolgun)

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

    hook.Add("CanTool", "GRM_QMenu_CanTool", function(ply, tr, toolname)
        local ok, why = GRM.QMenu.CanUseTool(ply, toolname)
        if not ok then
            ply:PrintMessage(HUD_PRINTCENTER, why or "Инструмент запрещён")
            return false
        end
    end)

    -- ========================================================
    -- v2.0.0: собственное меню стройки (при закрытом ванильном Q)
    -- ========================================================
    local NET_SPAWN   = "GRM_QMenu_SpawnProp"
    local NET_TOOL    = "GRM_QMenu_SetTool"
    local NET_GUN     = "GRM_QMenu_Toolgun"
    local NET_CLEAR   = "GRM_QMenu_ClearProps"
    local NET_PROPADD = "GRM_QMenu_PropAdd"
    local NET_PROPDEL = "GRM_QMenu_PropDel"
    for _, s in ipairs({ NET_SPAWN, NET_TOOL, NET_GUN, NET_CLEAR, NET_PROPADD, NET_PROPDEL }) do
        util.AddNetworkString(s)
    end

    QM._menuProps = QM._menuProps or {} -- ply → массив энтити, поставленных через меню
    QM._spawnRate = QM._spawnRate or {}

    -- есть ли у игрока вообще что-то доступное для меню
    function QM.BuildMenuContent(ply)
        if IsValid(ply) and ply:IsSuperAdmin() then return true, true end
        local props = QM.Cfg.grmBuildMenu == true and QM.CanSpawn(ply, "prop")
        local tools = false
        for _, t in ipairs(QM.ToolCatalog) do
            if QM.CanUseTool(ply, t.id) then tools = true break end
        end
        return props and true or false, tools
    end

    function QM.CanSpawnMenuProp(ply, model)
        if not IsValid(ply) then return false, "?" end
        model = tostring(model or "")
        if model == "" or string.find(model, "%.%.") then return false, "Некорректная модель" end
        if IsValid(ply) and ply:IsSuperAdmin() then return true end
        if QM.Cfg.grmBuildMenu ~= true then return false, "Меню стройки отключено администрацией" end
        if not QM.CanSpawn(ply, "prop") then return false, "Спавн пропов запрещён администрацией" end
        if QM.Cfg.propsFree == true then return true end
        for _, m in ipairs(QM.Cfg.propList or {}) do
            if m == model then return true end
        end
        return false, "Модель вне каталога меню стройки (добавляет суперадмин: /qm_prop_add)"
    end

    local function cleanRegistry(ply)
        local list = QM._menuProps[ply]
        if not istable(list) then list = {} QM._menuProps[ply] = list end
        for i = #list, 1, -1 do
            if not IsValid(list[i]) then table.remove(list, i) end
        end
        return list
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
        if IsValid(ply) and not ply:IsSuperAdmin() and #list >= (QM.Cfg.menuPropCap or 24) then
            return false, "Лимит пропов меню: " .. tostring(QM.Cfg.menuPropCap or 24) .. " (кнопка «Убрать мои пропы»)"
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
        ent.GRM_MenuOwner = ply
        hook.Run("PlayerSpawnedProp", ply, model, ent)
        return true, ent
    end

    net.Receive(NET_SPAWN, function(_, ply)
        if not IsValid(ply) then return end
        local ok, msg = QM.SpawnMenuProp(ply, net.ReadString())
        if not ok and GRM.Notify then GRM.Notify(ply, "[Стройка] " .. tostring(msg), 255, 140, 110) end
    end)

    net.Receive(NET_CLEAR, function(_, ply)
        if not IsValid(ply) then return end
        local list = QM._menuProps[ply] or {}
        local n = 0
        for _, e in ipairs(list) do if IsValid(e) then e:Remove() n = n + 1 end end
        QM._menuProps[ply] = {}
        if GRM.Notify then GRM.Notify(ply, "Убрано ваших пропов: " .. tostring(n), 120, 220, 140) end
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
        local want = net.ReadBool()
        if not want then
            if ply:HasWeapon("gmod_tool") then ply:StripWeapon("gmod_tool") end
            return
        end
        if not anyToolAllowed(ply) then
            if GRM.Notify then GRM.Notify(ply, "Вам не разрешён ни один инструмент.", 255, 140, 110) end
            return
        end
        if not ply:HasWeapon("gmod_tool") then ply:Give("gmod_tool") end
    end)

    net.Receive(NET_TOOL, function(_, ply)
        if not IsValid(ply) then return end
        local id = string.lower(tostring(net.ReadString() or ""))
        if not string.match(id, "^[%w_]+$") then return end -- защита: ConCommand-инъекция
        local ok, why = QM.CanUseTool(ply, id)
        if not ok then
            if GRM.Notify then GRM.Notify(ply, "[Стройка] " .. tostring(why or "Инструмент запрещён"), 255, 140, 110) end
            return
        end
        if not ply:HasWeapon("gmod_tool") then ply:Give("gmod_tool") end
        ply:ConCommand("gmod_tool \"" .. id .. "\"")
        ply:SelectWeapon("gmod_tool")
    end)

    local function curateAdd(ply, model)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return false, "Только суперадмин" end
        model = string.lower(tostring(model or ""))
        if model == "" then return false, "Пустая модель" end
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

    net.Receive(NET_PROPADD, function(_, ply)
        local ok, msg = curateAdd(ply, net.ReadString())
        if GRM.Notify then GRM.Notify(ply, ok and "Модель добавлена в каталог меню стройки." or ("[Стройка] " .. tostring(msg)), ok and 120 or 255, ok and 220 or 140, 110) end
    end)
    net.Receive(NET_PROPDEL, function(_, ply)
        local ok, msg = curateDel(ply, net.ReadString())
        if GRM.Notify then GRM.Notify(ply, ok and "Модель убрана из каталога." or ("[Стройка] " .. tostring(msg)), ok and 120 or 255, ok and 220 or 140, 110) end
    end)

    -- чат-команды куратора (паттерн н75: Transform + PlayerSay)
    function QM.HandleChat(ply, text)
        local low = string.lower(string.Trim(text or ""))
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
            local list = QM._menuProps[ply] or {}
            local n = 0
            for _, e in ipairs(list) do if IsValid(e) then e:Remove() n = n + 1 end end
            QM._menuProps[ply] = {}
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
    print("[GRM QMenu] Q-меню и инструменты v" .. QM.Version .. " загружены (Код 83). Настройка: /grm_admin → «Инструменты»")
end

-- Клиент: когда Q закрыто для игрока — не даём открыть спавн-меню вовсе.
-- v2.0.0: вместо молчаливого запрета — собственное меню стройки GRM.
if CLIENT then
    if istable(surface) and surface.CreateFont then -- guard: тест-стенды без движкового surface
        surface.CreateFont("GRMQ_Title", { font = "Roboto", size = 18, weight = 800, extended = true })
        surface.CreateFont("GRMQ_Sub",   { font = "Roboto", size = 14, weight = 600, extended = true })
        surface.CreateFont("GRMQ_Text",  { font = "Roboto", size = 12, weight = 500, extended = true })
    end

    -- v1.1.0: живой конфиг с сервера (и при входе, и после правок хаба)
    net.Receive("GRM_QMenu_Sync", function()
        local t = net.ReadTable()
        if not istable(t) then return end
        local d = defaultCfg()
        for k, v in pairs(t) do d[k] = v end -- слить поверх дефолтов
        GRM.QMenu.Cfg = d
    end)

    local _QC_Color = isfunction(Color) and Color or function() return { Unpack = function() return 255, 255, 255, 255 end } end
    local QC = {
        bg = _QC_Color(20, 24, 32, 250), head = _QC_Color(28, 34, 46, 255), panel = _QC_Color(32, 38, 50, 240),
        acc = _QC_Color(70, 150, 240), green = _QC_Color(60, 190, 110), red = _QC_Color(220, 75, 70),
        yellow = _QC_Color(230, 180, 60), text = _QC_Color(240, 245, 250), dim = _QC_Color(160, 170, 185),
    }

    local function qBlockedForMe()
        local lp = LocalPlayer()
        if IsValid(lp) and lp:IsSuperAdmin() then return false end
        return GRM.QMenu and GRM.QMenu.Cfg and GRM.QMenu.Cfg.playersQ == false
    end

    hook.Add("SpawnMenuOpen", "GRM_QMenu_BlockOpen", function()
        if qBlockedForMe() then return false end
    end)

    hook.Add("ContextMenuOpen", "GRM_QMenu_BlockCtx", function()
        if qBlockedForMe() then
            return false -- C-меню песочницы тоже закрыто (наше GRM-меню живёт своим хуком)
        end
    end)

    ----------------------------------------------------------------
    -- Меню стройки GRM (при закрытом ванильном Q)
    ----------------------------------------------------------------
    local _frame

    local function canToolLocal(id)
        local lp = LocalPlayer()
        if IsValid(lp) and lp:IsSuperAdmin() then return true end
        local c = GRM.QMenu.Cfg or {}
        id = string.lower(id)
        if istable(c.toolDeny) and c.toolDeny[id] == true then return false end
        if c.whitelistMode == true and (not istable(c.toolAllow) or c.toolAllow[id] ~= true) then return false end
        return true
    end

    local function menuHasContent()
        if IsValid(LocalPlayer()) and LocalPlayer():IsSuperAdmin() then return true end
        local c = GRM.QMenu.Cfg or {}
        if c.grmBuildMenu ~= true then return false end
        if c.allowProps == true then return true end
        for _, t in ipairs(QM.ToolCatalog) do
            if canToolLocal(t.id) then return true end
        end
        return false
    end

    local function mkBtn(p, txt, col, w0, h0)
        local b = vgui.Create("DButton", p)
        b:SetText(txt) b:SetFont("GRMQ_Sub") b:SetTextColor(color_white)
        if w0 then b:SetWide(w0) end if h0 then b:SetTall(h0) end
        b.Paint = function(self, pw, ph)
            local cc = col or QC.acc
            if self:IsHovered() then cc = Color(math.min(255, cc.r + 25), math.min(255, cc.g + 25), math.min(255, cc.b + 25)) end
            draw.RoundedBox(5, 0, 0, pw, ph, cc)
        end
        return b
    end

    local function openBuildMenu()
        if IsValid(_frame) then _frame:Remove() _frame = nil return end
        local cfg = GRM.QMenu.Cfg or {}
        local isAdmin = IsValid(LocalPlayer()) and LocalPlayer():IsSuperAdmin()

        local f = vgui.Create("DFrame")
        _frame = f
        f:SetTitle("") f:SetSize(720, 560) f:Center() f:MakePopup() f:ShowCloseButton(false)
        f.Paint = function(_, pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, QC.bg)
            draw.RoundedBoxEx(8, 0, 0, pw, 42, QC.head, true, true, false, false)
            draw.SimpleText("GRM Стройка", "GRMQ_Title", 14, 21, QC.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("ванильное Q закрыто администрацией — доступен только этот каталог", "GRMQ_Text", pw - 110, 21, QC.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        local x = mkBtn(f, "X", QC.red, 32, 28) x:SetPos(720 - 40, 7) x.DoClick = function() f:Remove() _frame = nil end

        local tabs = vgui.Create("DPropertySheet", f)
        tabs:SetPos(8, 48) tabs:SetSize(704, 464)

        -- ---------- вкладка ПРОПЫ ----------
        local pProps = vgui.Create("DPanel", tabs)
        pProps:SetPaintBackground(false)
        tabs:AddSheet(" Пропы ", pProps, "icon16/box.png")

        local grid = vgui.Create("DIconLayout", pProps)
        grid:SetPos(6, 6) grid:SetSize(688, 380)
        grid:SetSpaceX(6) grid:SetSpaceY(6)

        local list = cfg.propList or {}
        if cfg.allowProps == true then
            if cfg.propsFree == true or isAdmin then
                local free = vgui.Create("DTextEntry", pProps)
                free:SetPos(6, 392) free:SetSize(430, 28) free:SetFont("GRMQ_Sub")
                free:SetPlaceholderText("models/путь/к/модели.mdl (свободный спавн)")
                local bFree = mkBtn(pProps, "Заспавнить", QC.green, 240, 28)
                bFree:SetPos(444, 392)
                bFree.DoClick = function()
                    local m = string.lower(string.Trim(free:GetValue() or ""))
                    if m == "" then return end
                    net.Start("GRM_QMenu_SpawnProp")
                        net.WriteString(m)
                    net.SendToServer()
                end
            end
            if #list == 0 and not (cfg.propsFree or isAdmin) then
                local d = vgui.Create("DLabel", pProps)
                d:SetPos(10, 12) d:SetSize(670, 24) d:SetFont("GRMQ_Sub") d:SetTextColor(QC.dim)
                d:SetText("Каталог пропов пуст — администрация ещё не добавила модели (/qm_prop_add).")
            end
            for _, mdl in ipairs(list) do
                local icon = vgui.Create("SpawnIcon", grid)
                icon:SetModel(mdl)
                icon:SetSize(76, 76)
                icon:SetTooltip(mdl .. (isAdmin and "\nПКМ — убрать из каталога" or ""))
                icon.DoClick = function()
                    surface.PlaySound("ui/buttonclickrelease.wav")
                    net.Start("GRM_QMenu_SpawnProp")
                        net.WriteString(mdl)
                    net.SendToServer()
                end
                if isAdmin then
                    icon.DoRightClick = function()
                        net.Start("GRM_QMenu_PropDel")
                            net.WriteString(mdl)
                        net.SendToServer()
                        timer.Simple(0.6, function() if IsValid(_frame) then _frame:Remove() _frame = nil openBuildMenu() end end)
                    end
                end
                grid:Add(icon)
            end
        else
            local d = vgui.Create("DLabel", pProps)
            d:SetPos(10, 12) d:SetSize(670, 24) d:SetFont("GRMQ_Sub") d:SetTextColor(QC.dim)
            d:SetText("Спавн пропов игрокам запрещён администрацией.")
        end

        -- ---------- вкладка ИНСТРУМЕНТЫ ----------
        local pTools = vgui.Create("DPanel", tabs)
        pTools:SetPaintBackground(false)
        tabs:AddSheet(" Инструменты ", pTools, "icon16/wrench.png")

        local sc = vgui.Create("DScrollPanel", pTools)
        sc:SetPos(6, 6) sc:SetSize(688, 344)
        local shown = 0
        for _, tinfo in ipairs(QM.ToolCatalog) do
            if canToolLocal(tinfo.id) then
                shown = shown + 1
                local b = mkBtn(sc, tinfo.label .. "   [" .. tinfo.id .. "]", QC.panel, 660, 30)
                b:Dock(TOP) b:DockMargin(2, 2, 2, 0)
                b.DoClick = function()
                    surface.PlaySound("ui/buttonclick.wav")
                    net.Start("GRM_QMenu_SetTool")
                        net.WriteString(tinfo.id)
                    net.SendToServer()
                    if IsValid(_frame) then _frame:Remove() _frame = nil end -- сразу в руку тулган
                end
            end
        end
        if shown == 0 then
            local d = vgui.Create("DLabel", pTools)
            d:SetPos(10, 12) d:SetSize(670, 24) d:SetFont("GRMQ_Sub") d:SetTextColor(QC.dim)
            d:SetText("Инструменты игрокам запрещены (списки — в /grm_admin → «Инструменты»).")
        end

        -- ---------- футер ----------
        local bGun = mkBtn(f, "Взять тулган", QC.acc, 160, 30) bGun:SetPos(10, 520)
        bGun.DoClick = function()
            net.Start("GRM_QMenu_Toolgun") net.WriteBool(true) net.SendToServer()
        end
        local bGunOff = mkBtn(f, "Убрать тулган", QC.panel, 160, 30) bGunOff:SetPos(178, 520)
        bGunOff.DoClick = function()
            net.Start("GRM_QMenu_Toolgun") net.WriteBool(false) net.SendToServer()
        end
        local bClear = mkBtn(f, "Убрать мои пропы", QC.yellow, 170, 30) bClear:SetPos(346, 520)
        bClear.DoClick = function()
            net.Start("GRM_QMenu_ClearProps") net.SendToServer()
        end
        if isAdmin then
            local bCur = mkBtn(f, "+ проп из прицела в каталог", QC.green, 190, 30) bCur:SetPos(524, 520)
            bCur.DoClick = function()
                local tr = LocalPlayer():GetEyeTrace()
                local mdl = (IsValid(tr.Entity) and tr.Entity:GetModel()) or ""
                if mdl == "" then return end
                net.Start("GRM_QMenu_PropAdd")
                    net.WriteString(string.lower(mdl))
                net.SendToServer()
                timer.Simple(0.6, function() if IsValid(_frame) then _frame:Remove() _frame = nil openBuildMenu() end end)
            end
        end
    end

    -- v1.1.0: УНИВЕРСАЛЬНЫЙ слой — глушим сам бинд "+menu" (Q).
    -- Работает против ВАНИЛЬНОГО и ЛЮБОГО КАСТОМНОГО спавн-меню, открываемого
    -- по Q: бинд не доходит ни до одного аддона. (Контекстный бинд C не трогаем:
    -- там живёт наше GRM-меню — замок/багажник/инвентарь.)
    -- v2.0.0: вместо глухого запрета открываем собственное меню стройки.
    hook.Add("PlayerBindPress", "GRM_QMenu_BindBlock", function(_, bind, pressed)
        if not pressed then return end
        if bind ~= "+menu" then return end
        if qBlockedForMe() then
            if menuHasContent() then
                openBuildMenu()
            elseif IsValid(LocalPlayer()) then
                LocalPlayer():PrintMessage(HUD_PRINTCENTER, "Q-меню и стройка закрыты администрацией")
            end
            return true
        end
    end)
end
