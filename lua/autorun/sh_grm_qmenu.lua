--[[--------------------------------------------------------------------
    GRM Q-меню и инструменты v1.0.0 (Код 83) — управление песочницей

    Единая точка настройки того, что игрокам разрешено делать через
    Q-меню и toolgun. Суперадмин — вне всех ограничений.

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

QM.Version = "1.0.0"

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
    }
end

QM.Cfg = defaultCfg()

-- ============================================================
-- СЕРВЕР
-- ============================================================
if SERVER then
    local function jsonT(txt) return util.JSONToTable(txt, false, true) end

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
            "allowNPCs", "allowSENTs", "allowSWEPs", "allowVehiclesQ", "whitelistMode" }) do
            if t[k] ~= nil then d[k] = t[k] == true end
        end
        d.toolDeny  = sanitizeList(t.toolDeny)
        d.toolAllow = sanitizeList(t.toolAllow)
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

    QM.Load("старт")
    print("[GRM QMenu] Q-меню и инструменты v" .. QM.Version .. " загружены (Код 83). Настройка: /grm_admin → «Инструменты»")
end

-- Клиент: когда Q закрыто для игрока — не даём открыть спавн-меню вовсе.
if CLIENT then
    hook.Add("SpawnMenuOpen", "GRM_QMenu_BlockOpen", function()
        local lp = LocalPlayer()
        if IsValid(lp) and lp:IsSuperAdmin() then return end
        if GRM.QMenu and GRM.QMenu.Cfg and GRM.QMenu.Cfg.playersQ == false then
            return false
        end
    end)

    hook.Add("ContextMenuOpen", "GRM_QMenu_BlockCtx", function()
        local lp = LocalPlayer()
        if IsValid(lp) and lp:IsSuperAdmin() then return end
        if GRM.QMenu and GRM.QMenu.Cfg and GRM.QMenu.Cfg.playersQ == false then
            return false -- C-меню песочницы тоже закрыто (наше GRM-меню живёт своим хуком)
        end
    end)
end
