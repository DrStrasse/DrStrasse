--[[--------------------------------------------------------------------
    GRM CCTV — shared configuration (Код 60)
    Видеонаблюдение: камеры, монитор (ПК), серверная стойка сети.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.CCTV = GRM.CCTV or {}

local C = GRM.CCTV

C.Config = C.Config or {
    -- Модели (владелец: computer / camera / servers).
    CameraModel  = "models/props_silo/camera.mdl",
    CameraModelAlt = "models/props/cs_assault/camera.mdl",
    MonitorModel = "models/natalya/sims/computer.mdl",
    MonitorModelAlt = "models/props/cs_office/computer.mdl",
    ServerModel  = "models/props_lab/servers.mdl",

    -- Сеть: камера видна монитору, если у них один NetworkID
    -- И есть хотя бы одна включённая серверная стойка с тем же NetworkID.
    DefaultNetwork = "main",
    MaxNetworkLen  = 32,
    MaxLabelLen    = 48,

    -- Камера
    DefaultFOV     = 75,
    MinFOV         = 40,
    MaxFOV         = 100,
    MaxCamerasPerNetwork = 32,
    MaxMonitorsPerMap    = 24,
    MaxServersPerMap     = 12,

    -- Дальность Use()
    UseDistance = 140,

    -- Обновление списка камер на мониторе (сек)
    ListRefreshSeconds = 2,

    -- Персистентность (permanent-устройства, поставленные админом/tool)
    SaveDir  = "grm_cctv",
    -- файл: data/grm_cctv/<map>.json — массив устройств (без числовых ключей-sid)

    -- Доступ
    Access = {
        SuperAdminBypass = true,
        -- Если true — смотреть монитор могут все; настройка камер/стойки — только с доступом.
        PublicView = false,
        -- SteamID64 в белом списке (заполняет владелец)
        AllowSteam = {
            -- ["7656119..."] = true,
        },
        -- Имена фракций из Factions (если таблица есть)
        AllowFactions = {
            -- ["Полиция"] = true,
        },
    },

    -- 3D2D / подписи
    DrawLabels = true,
    LabelDistance = 420,

    -- Переключение «живого» вида: клиент ставит ViewEntity на камеру
    -- (рендер чужого prop как «камеры» — штатный приём GMod CCTV).
    SwitchCooldown = 0.15,
}

function C.NormalizeNetwork(value)
    value = string.Trim(tostring(value or C.Config.DefaultNetwork or "main"))
    if value == "" then value = C.Config.DefaultNetwork or "main" end
    value = string.lower(string.sub(value, 1, C.Config.MaxNetworkLen or 32))
    value = string.gsub(value, "[^%w%-%_%.]", "")
    if value == "" then value = "main" end
    return value
end

function C.ClampFOV(fov)
    local cfg = C.Config
    fov = tonumber(fov) or cfg.DefaultFOV or 75
    return math.Clamp(math.floor(fov + 0.5), cfg.MinFOV or 40, cfg.MaxFOV or 100)
end

print("[GRM CCTV] config v1.0.0")
