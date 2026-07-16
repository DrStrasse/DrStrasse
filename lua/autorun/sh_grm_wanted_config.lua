--[[--------------------------------------------------------------------
    GRM Wanted — shared config (Код 61)
    Уровни розыска, каталог статей, лимиты.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Wanted = GRM.Wanted or {}
local W = GRM.Wanted

W.Config = W.Config or {
    MaxLevel = 5,
    MaxReasonsPerPlayer = 32,
    MaxActiveRecords = 512,
    HistorySize = 200,
    -- Авто-спад уровня (0 = выкл), секунды
    LevelDecaySeconds = 0,
    -- Показывать уровень в HUD/Tab (если модули читают GRM.Wanted.GetLevel)
    SyncToClient = true,
    -- Суперадмин всегда может всё
    SuperAdminBypass = true,
}

-- Уровни: index 0 = чист, 1..MaxLevel
W.Levels = W.Levels or {
    [0] = { name = "Чист",          color = Color(140, 200, 140), short = "—" },
    [1] = { name = "Административка", color = Color(220, 200, 80),  short = "★" },
    [2] = { name = "Лёгкий розыск",   color = Color(230, 170, 60),  short = "★★" },
    [3] = { name = "Розыск",          color = Color(230, 120, 50),  short = "★★★" },
    [4] = { name = "Особый розыск",   color = Color(220, 60, 60),   short = "★★★★" },
    [5] = { name = "Федеральный",     color = Color(160, 40, 200),  short = "★★★★★" },
}

-- Каталог статей по умолчанию (id → запись). type: "admin" | "crime"
W.DefaultCatalog = W.DefaultCatalog or {
    { id = "admin_noise",     type = "admin", title = "Нарушение общественного порядка", fine = 500,  defaultLevel = 1 },
    { id = "admin_traffic",   type = "admin", title = "Нарушение ПДД",                   fine = 1000, defaultLevel = 1 },
    { id = "admin_id",        type = "admin", title = "Отказ предъявить документы",     fine = 1500, defaultLevel = 1 },
    { id = "crime_theft",     type = "crime", title = "Кража",                           fine = 5000, defaultLevel = 2 },
    { id = "crime_assault",   type = "crime", title = "Нападение / побои",               fine = 8000, defaultLevel = 3 },
    { id = "crime_robbery",   type = "crime", title = "Грабёж",                          fine = 15000, defaultLevel = 3 },
    { id = "crime_weapon",    type = "crime", title = "Незаконное оружие",               fine = 20000, defaultLevel = 4 },
    { id = "crime_murder",    type = "crime", title = "Убийство",                        fine = 0,     defaultLevel = 5 },
    { id = "crime_escape",    type = "crime", title = "Побег / уклонение",               fine = 10000, defaultLevel = 4 },
    { id = "crime_corrupt",   type = "crime", title = "Коррупция / взятка",              fine = 25000, defaultLevel = 4 },
}

function W.GetLevelInfo(level)
    level = math.floor(tonumber(level) or 0)
    local maxL = (W.Config and W.Config.MaxLevel) or 5
    level = math.Clamp(level, 0, maxL)
    local info = (W.Levels and W.Levels[level]) or { name = "Ур." .. level, color = color_white, short = tostring(level) }
    return level, info
end

function W.ClampLevel(level)
    local maxL = (W.Config and W.Config.MaxLevel) or 5
    return math.Clamp(math.floor(tonumber(level) or 0), 0, maxL)
end

print("[GRM Wanted] config v1.0.0")
