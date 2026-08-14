--[[--------------------------------------------------------------------
    GRM Documents & Identity Core v1.4.1 (Код 87)
    Паспорта, Служебные Удостоверения, Ксивы, Военные Билеты,
    Водительские Удостоверения (Дорожная Инспекция ПП и ВАИ),
    Специальные Военные Допуски, Прикрытие, Реестр

    • Паспорт гражданина: ФИО, пол, дата рождения, гражданство, серия, номер,
      орган выдачи, дата, подпись, фото, MRZ.
    • Служебное удостоверение (Ксива): настраиваемое название на обложке,
      служебный префикс номера жетона, цвет кожаной корочки, тиснение, жетон,
      звание, отдел, матрица 6 спецдопусков (оружие, арест, обыск, ордера,
      спецтранспорт, режимный проход).
    • Военный билет: серия/номер, ФИО, воинское звание, ВУС, воинское
      формирование (выбор/ручной), подразделение/отдел (выбор/ручной),
      должность (ручной ввод), категория годности (А–Д), кем выдан.
    • Водительское удостоверение (Дорожная Инспекция ПП / Гражданские):
      категории вождения (A, B, C, D, E, СПЕЦ), номер В/У, ФИО, дата рождения,
      орган выдачи, особые отметки (стаж, очки, трансмиссия), статус.
    • Удостоверение военного водителя (ВАИ Полевой Жандармерии): тактический
      армейский бланк, воинское звание, воинская часть/гарнизон, ВУС военного
      водителя (837/838/843/845), военные категории (A-В, B-В, C-В, D-В, E-В, СПЕЦ-В),
      специальные допуски (колонны, спецсигналы, марш 500 км, опасные грузы, бронетехника).
    • Документы прикрытия: спецслужбы с CoverDocsAccess фабрикуют 100% аутентичные
      удостоверения любых ведомств для маскировки.
    • Двухфазный интерактивный просмотр: Закрытая обложка ⇄ Раскрытый разворот.
    • Показ документов: /showpassport, /showbadge, /showmilitary, /showlicense,
      /showmillicense, /showmedcard с RP /me в чат и интерактивным окном у цели.
    • Типографика GMod: 100% валидные BMP-символы, поддержка кириллицы, авто-перенос строк.

    История версий:
    • v1.4.1 — Убрана реальная государственность из паспорта: заголовок разворота
      «РОССИЙСКАЯ ФЕДЕРАЦИЯ» заменён на настраиваемое название государства
      (tpl.stateTitle, по умолчанию «РЕСПУБЛИКА ГРАНД»), код страны «RUS» в MRZ
      заменён на настраиваемый countryCode (по умолчанию «GRM»). Код страны
      редактируется в шаблонах документов, вкладка «Паспорт».
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

local function makeCol(r, g, b, a)
    if Color then return Color(r, g, b, a) end
    return { r = r or 255, g = g or 255, b = b or 255, a = a or 255 }
end

local function tblCopy(t)
    if table and table.Copy then return table.Copy(t) end
    local res = {}
    for k, v in pairs(t or {}) do
        res[k] = (type(v) == "table") and tblCopy(v) or v
    end
    return res
end

GRM = GRM or {}
GRM.Documents = GRM.Documents or {}
local DOC = GRM.Documents

DOC.Version       = "2.0.0 — licenses v2 expiry/points + photoPath"
DOC.RegistryFile  = "grm_documents.json"
DOC.TemplatesFile = "grm_doc_templates.json"

local NET_OPEN_DOC       = "GRM_Doc_OpenDoc"
local NET_SHOW_DOC       = "GRM_Doc_ShowDoc"
local NET_RECEIVE_VIEW   = "GRM_Doc_ReceiveView"
local NET_ADMIN_GET      = "GRM_Doc_AdminGet"
local NET_ADMIN_SAVE     = "GRM_Doc_AdminSave"
local NET_COMPUTER_OPEN  = "GRM_Doc_ComputerOpen"
local NET_COMPUTER_ISSUE = "GRM_Doc_ComputerIssue"
local NET_COMPUTER_REVOKE= "GRM_Doc_ComputerRevoke"

-- Пресеты цветов обложек
DOC.CoverColors = {
    { id = "black",    name = "Чёрный (Классика)",       col = makeCol(20, 20, 24) },
    { id = "maroon",   name = "Бордовый (Госслужба)",     col = makeCol(90, 22, 26) },
    { id = "navy",     name = "Тёмно-синий (Полиция)",    col = makeCol(18, 32, 60) },
    { id = "khaki",    name = "Хаки / Олива (Военный)",  col = makeCol(38, 58, 36) },
    { id = "emerald",  name = "Изумрудный (Охрана)",      col = makeCol(20, 52, 38) },
    { id = "grey",     name = "Графит (Спецслужбы)",      col = makeCol(42, 45, 52) },
    { id = "brown",    name = "Коричневая кожа",         col = makeCol(65, 42, 28) },
}

-- Стили тиснения
DOC.FoilStyles = {
    gold   = { name = "Золотое тиснение",   col = makeCol(245, 205, 90),  shadow = makeCol(140, 100, 20) },
    silver = { name = "Серебряное тиснение", col = makeCol(225, 230, 240), shadow = makeCol(110, 115, 125) },
    bronze = { name = "Бронзовое тиснение", col = makeCol(210, 140, 85),  shadow = makeCol(120, 70, 30) },
    white  = { name = "Белый штамп",        col = makeCol(240, 240, 245), shadow = makeCol(80, 80, 90) },
}

-- Значки жетонов на левой створке (BMP-символы)
DOC.BadgeIcons = {
    star     = "★ Звезда шерифа / полиции",
    shield   = "[Щит] Щит правопорядка",
    eagle    = "★ Государственный герб",
    swords   = "[Меч] Щит и меч (Госбезопасность)",
    military = "[ВС] Воинская звезда / ВС",
    scales   = "[Суд] Весы правосудия (Юстиция)",
    bank     = "[Банк] Банковский резерв / Казна",
    med      = "✚ Медицинский крест",
}

-- Список специальных допусков для служебного удостоверения
DOC.PermissionsList = {
    { id = "weapon",    title = "Ношение табельного оружия", desc = "Право на скрытое/открытое ношение спецвооружения" },
    { id = "arrest",    title = "Проведение задержаний",     desc = "Право на арест и применение спецсредств" },
    { id = "search",    title = "Обыск и досмотр",           desc = "Право на проверку граждан и имущества" },
    { id = "access",    title = "Беспрепятственный доступ",   desc = "Доступ на закрытые и режимные объекты" },
    { id = "transport", title = "Управление спецтранспортом",desc = "Допуск к оперативным автомобилям ведомства" },
    { id = "warrant",   title = "Исполнение ордеров",        desc = "Право на принудительное вскрытие дверей" },
}

-- Категории гражданского водительского удостоверения (Дорожная Инспекция ПП)
DOC.DriveCategories = {
    { id = "A",    name = "Категория A (Мото)",     desc = "Мототранспорт и легкие мотоциклы", icon = "[A]" },
    { id = "B",    name = "Категория B (Легковые)", desc = "Легковые автомобили (до 3.5т, до 8 мест)", icon = "[B]" },
    { id = "C",    name = "Категория C (Грузовые)", desc = "Грузовой автотранспорт (> 3.5т)",  icon = "[C]" },
    { id = "D",    name = "Категория D (Автобусы)", desc = "Автобусы и пассажирский транспорт", icon = "[D]" },
    { id = "E",    name = "Категория E (Прицепы)",  desc = "Тягачи с прицепами и автопоезда (BE/CE/DE)", icon = "[E]" },
    { id = "SPEC", name = "Спецтехника",            desc = "Тракторы, самоходные машины, погрузчики", icon = "[СПЕЦ]" },
}

-- Военные категории водительского удостоверения (ВАИ Полевой Жандармерии)
DOC.MilDriveCategories = {
    { id = "A-В",    name = "Категория A-В",    desc = "Армейские мотоциклы, квадроциклы и разведбагги", icon = "[A-В]" },
    { id = "B-В",    name = "Категория B-В",    desc = "Штабные и оперативные легковые внедорожники", icon = "[B-В]" },
    { id = "C-В",    name = "Категория C-В",    desc = "Военные грузовые автомобили и тягачи (КамАЗ, Урал)", icon = "[C-В]" },
    { id = "D-В",    name = "Категория D-В",    desc = "Войсковой пассажирский транспорт и автоколонны", icon = "[D-В]" },
    { id = "E-В",    name = "Категория E-В",    desc = "Артиллерийские тягачи и тяжелые платформы", icon = "[E-В]" },
    { id = "СПЕЦ-В", name = "Категория СПЕЦ-В", desc = "Колёсная и гусеничная бронетехника (БТР, БМП, МТ-ЛБ)", icon = "[СПЕЦ-В]" },
}

-- Специальные допуски военного водителя (Endorsements)
DOC.MilEndorsements = {
    { id = "sirens",     title = "Спецсигналы (СГУ/Маяки)",     desc = "Управление Т/С с проблесковыми маяками и сиренами ВАИ/ВП", icon = "[!]" },
    { id = "convoy",     title = "Войсковые автоколонны",       desc = "Движение и руководство в составе организованных войсковых колонн", icon = "[#]" },
    { id = "march",      title = "Марш 500 км (Стажировка)",   desc = "Пройден обязательный норматив марша войскового водителя", icon = "[★]" },
    { id = "passengers", title = "Перевозка личного состава",   desc = "Допуск к перевозке военнослужащих в кузовах и автобусах", icon = "[+]" },
    { id = "hazmat",     title = "Опасные и военные грузы",     desc = "Перевозка боеприпасов, вооружения и ГСМ (ADR/ВВ)", icon = "[!]" },
    { id = "armor",      title = "Управление бронетехникой",    desc = "Допуск к управлению бронированными боевыми машинами", icon = "[★]" },
}

-- Воинские звания
DOC.MilitaryRanks = {
    "Рядовой", "Ефрейтор", "Младший сержант", "Сержант", "Старший сержант",
    "Старшина", "Прапорщик", "Старший прапорщик", "Младший лейтенант",
    "Лейтенант", "Старший лейтенант", "Капитан", "Майор", "Подполковник",
    "Полковник", "Генерал-майор", "Генерал-лейтенант", "Генерал-полковник", "Генерал армии"
}

-- Военно-учётные специальности (ВУС)
DOC.MilitaryVUS = {
    "ВУС-100 (Стрелковая подготовка)",
    "ВУС-106 (Войсковая разведка)",
    "ВУС-107 (Подразделения специального назначения)",
    "ВУС-121 (Бронетанковая служба)",
    "ВУС-124 (Водитель спецтранспорта)",
    "ВУС-166 (Инженерно-сапёрная служба)",
    "ВУС-837 (Военная автоинспекция и комендатура)",
    "ВУС-878 (Медицинская служба)",
    "ВУС-900 (Штабная и командная служба)",
    "ВУС-999 (Не годен к военной службе)",
}

-- ВУС специально для военных водителей
DOC.MilitaryDriverVUS = {
    "ВУС-837 (Водитель транспортных средств категории C)",
    "ВУС-838 (Водитель-автомеханик автомобильных подразделений)",
    "ВУС-843 (Механик-водитель боевых колёсных машин / БТР)",
    "ВУС-845 (Водитель тяжелых тягачей и танковозов)",
    "ВУС-124 (Водитель оперативно-штабного спецтранспорта)",
    "ВУС-166 (Механик-водитель инженерных машин разграждения)",
}

-- Хелпер ключа персонажа
local function getCharKey(ply)
    if IsValid(ply) and ply:IsPlayer() then
        if GRM.Identity and GRM.Identity.CharacterKey then
            return GRM.Identity.CharacterKey(ply)
        end
        local sid = ply:SteamID64() or ply:SteamID() or "0"
        local slot = (ply.GetNWString and ply:GetNWString("GRM_CharacterID", "char1")) or "char1"
        return sid .. ":" .. slot
    end
    local s = tostring(ply or "")
    if s:match(":char[1-3]$") then return s end
    if s:match("^%d+$") then return s .. ":char1" end
    return s
end
DOC.GetCharKey = getCharKey

local function getPlayerRPName(ply)
    if not IsValid(ply) then return "?" end
    local n = ply:GetNWString("GRM_RPName", "")
    return (n ~= "" and n) or ply:Nick()
end
DOC.GetPlayerRPName = getPlayerRPName

-- ============================================================
-- СЕРВЕРНАЯ ЧАСТЬ
-- ============================================================
if SERVER then
    for _, str in ipairs({
        NET_OPEN_DOC, NET_SHOW_DOC, NET_RECEIVE_VIEW,
        NET_ADMIN_GET, NET_ADMIN_SAVE, NET_COMPUTER_OPEN,
        NET_COMPUTER_ISSUE, NET_COMPUTER_REVOKE
    }) do
        util.AddNetworkString(str)
    end

    local function jsonT(txt)
        local ok, t = pcall(util.JSONToTable, txt, false, true)
        return (ok and istable(t)) and t or nil
    end

    -- Загрузка шаблонов оформления
    local function defaultTemplates()
        return {
            passport = {
                stateTitle         = "РЕСПУБЛИКА ГРАНД",
                docTitle           = "ПАСПОРТ ГРАЖДАНИНА",
                coverColor         = { r = 85, g = 20, b = 25 },
                foilStyle          = "gold",
                countryCode        = "GRM",
                defaultSeries      = "GRM",
                defaultNationality = "Гражданин Республики",
                defaultBirthPlace  = "г. Приморск, Республика Гранд",
            },
            military = {
                stateTitle    = "ВООРУЖЁННЫЕ СИЛЫ",
                docTitle      = "ВОЕННЫЙ БИЛЕТ",
                coverColor    = { r = 38, g = 58, b = 36 },
                foilStyle     = "gold",
                defaultPrefix = "ВБ-",
                defaultIssuer = "Военный комиссариат Центрального округа",
            },
            license = {
                stateTitle    = "ДОРОЖНАЯ ИНСПЕКЦИЯ ПП",
                docTitle      = "ВОДИТЕЛЬСКОЕ УДОСТОВЕРЕНИЕ",
                coverColor    = { r = 35, g = 60, b = 95 },
                foilStyle     = "gold",
                defaultPrefix = "ВУ-",
                defaultIssuer = "Дорожная Инспекция Полиции Порядка",
            },
            militaryLicense = {
                stateTitle    = "ВОЕННАЯ АВТОМОБИЛЬНАЯ ИНСПЕКЦИЯ",
                docTitle      = "УДОСТОВЕРЕНИЕ ВОЕННОГО ВОДИТЕЛЯ",
                coverColor    = { r = 38, g = 58, b = 36 },
                foilStyle     = "gold",
                defaultPrefix = "ВАИ-",
                defaultIssuer = "101-я Военная автомобильная инспекция (ВАИ)",
            },
            factions = {
                ["OrdnungPolizei"] = {
                    coverTitle   = "ORDNUNGSPOLIZEI",
                    coverColor   = { r = 18, g = 32, b = 60 },
                    foilStyle    = "gold",
                    badgeIcon    = "star",
                    prefix       = "POL-",
                    defaultPerms = { weapon = true, arrest = true, search = true, transport = true },
                },
                ["Feldgendarmerie"] = {
                    coverTitle   = "FELDGENDARMERIE",
                    coverColor   = { r = 35, g = 55, b = 35 },
                    foilStyle    = "silver",
                    badgeIcon    = "military",
                    prefix       = "FELD-",
                    defaultPerms = { weapon = true, arrest = true, search = true, transport = true },
                },
                ["Gestapo"] = {
                    coverTitle   = "STAATSPOLIZEI (GESTAPO)",
                    coverColor   = { r = 24, g = 20, b = 26 },
                    foilStyle    = "gold",
                    badgeIcon    = "swords",
                    prefix       = "GST-",
                    defaultPerms = { weapon = true, arrest = true, search = true, access = true, transport = true, warrant = true },
                },
                ["Department of Labour and Social Protection"] = {
                    coverTitle   = "ДЕПАРТАМЕНТ ТРУДА И СОЦЗАЩИТЫ",
                    coverColor   = { r = 24, g = 50, b = 40 },
                    foilStyle    = "silver",
                    badgeIcon    = "shield",
                    prefix       = "ДТЗСЗ-",
                    defaultPerms = { access = true, transport = true },
                },
            },
            access = {
                passports   = { ["OrdnungPolizei"] = true, ["Department of Labour and Social Protection"] = true },
                badges      = { ["OrdnungPolizei"] = true, ["Feldgendarmerie"] = true, ["Gestapo"] = true, ["Department of Labour and Social Protection"] = true },
                military    = { ["Feldgendarmerie"] = true },
                licenses    = { ["OrdnungPolizei"] = true },
                milLicenses = { ["Feldgendarmerie"] = true },
                coverDocs   = { ["Gestapo"] = true },
            }
        }
    end

    function DOC.LoadTemplates()
        DOC.Templates = defaultTemplates()
        if file.Exists(DOC.TemplatesFile, "DATA") then
            local t = jsonT(file.Read(DOC.TemplatesFile, "DATA") or "")
            if istable(t) then
                if istable(t.passport)        then DOC.Templates.passport        = t.passport end
                if istable(t.military)        then DOC.Templates.military        = t.military end
                if istable(t.license)         then DOC.Templates.license         = t.license end
                if istable(t.militaryLicense) then DOC.Templates.militaryLicense = t.militaryLicense end
                if istable(t.factions)        then DOC.Templates.factions        = t.factions end
                if istable(t.access)          then DOC.Templates.access          = t.access end
            end
        end
        if SetGlobalString and DOC.Templates.passport then
            SetGlobalString("GRM_StateTitle", tostring(DOC.Templates.passport.stateTitle or "РЕСПУБЛИКА ГРАНД"))
        end
        return DOC.Templates
    end

    function DOC.SaveTemplates(why)
        local ok, txt = pcall(util.TableToJSON, DOC.Templates or defaultTemplates(), true)
        if ok and txt then
            file.Write(DOC.TemplatesFile, txt)
            if SetGlobalString and DOC.Templates.passport then
                SetGlobalString("GRM_StateTitle", tostring(DOC.Templates.passport.stateTitle or "РЕСПУБЛИКА ГРАНД"))
            end
            net.Start(NET_ADMIN_GET)
                net.WriteTable(DOC.Templates)
            net.Broadcast()
            print("[GRM Documents] SAVE ok templates (" .. tostring(why or "?") .. ")")
        end
    end

    -- Загрузка базы выданных документов
    function DOC.LoadRegistry()
        DOC.Registry = { passports = {}, badges = {}, coverBadges = {}, military = {}, licenses = {}, milLicenses = {} }
        if file.Exists(DOC.RegistryFile, "DATA") then
            local t = jsonT(file.Read(DOC.RegistryFile, "DATA") or "")
            if istable(t) then
                DOC.Registry.passports   = istable(t.passports) and t.passports or {}
                DOC.Registry.badges      = istable(t.badges) and t.badges or {}
                DOC.Registry.coverBadges = istable(t.coverBadges) and t.coverBadges or {}
                DOC.Registry.military    = istable(t.military) and t.military or {}
                DOC.Registry.licenses    = istable(t.licenses) and t.licenses or {}
                DOC.Registry.milLicenses = istable(t.milLicenses) and t.milLicenses or {}
            end
        end
        return DOC.Registry
    end

    function DOC.SaveRegistry(why)
        local ok, txt = pcall(util.TableToJSON, DOC.Registry or {}, true)
        if ok and txt then
            file.Write(DOC.RegistryFile, txt)
            print("[GRM Documents] SAVE ok registry (" .. tostring(why or "?") .. "), паспортов: " .. table.Count(DOC.Registry.passports or {}) .. ", удостоверений: " .. table.Count(DOC.Registry.badges or {}) .. ", прав Дорожной Инспекции: " .. table.Count(DOC.Registry.licenses or {}) .. ", прав ВАИ: " .. table.Count(DOC.Registry.milLicenses or {}))
        end
    end

    DOC.LoadTemplates()
    DOC.LoadRegistry()

    -- Авто-создание паспорта гражданина при необходимости
    local function ensurePassport(ply)
        local key = getCharKey(ply)
        if key == "" then return nil end
        DOC.Registry.passports = DOC.Registry.passports or {}
        local p = DOC.Registry.passports[key]
        if not istable(p) then
            local sid64 = ply:SteamID64() or "0"
            local shortSid = sid64:sub(-6)
            local slot = (ply.GetNWString and ply:GetNWString("GRM_CharacterID", "char1")) or "char1"
            local slotNum = slot:gsub("%D", "")
            local tpl = DOC.Templates.passport or {}

            p = {
                fullName    = getPlayerRPName(ply),
                gender      = "Мужской",
                birthDate   = "12.04.1988",
                nationality = tpl.defaultNationality or "Гражданин Республики",
                birthPlace  = tpl.defaultBirthPlace or "г. Приморск, Республика Гранд",
                series      = tpl.defaultSeries or "GRM",
                number      = string.format("%02d%s", tonumber(slotNum) or 1, shortSid),
                issuedBy    = "Паспортный стол Центрального округа",
                issueDate   = os.date("%d.%m.%Y"),
                validUntil  = "Бессрочно",
                status      = "Действителен",
                steamID64   = sid64,
                created     = os.time(),
                updated     = os.time(),
            }
            DOC.Registry.passports[key] = p
            DOC.SaveRegistry("auto create passport for " .. key)
        end
        return p
    end
    DOC.EnsurePassport = ensurePassport

    -- Получение служебного удостоверения персонажа
    local function ensureBadge(ply)
        local key = getCharKey(ply)
        if key == "" then return nil end
        DOC.Registry.badges = DOC.Registry.badges or {}
        local b = DOC.Registry.badges[key]

        local factionName = ply:GetNWString("GRM_Faction", "")
        if factionName == "" then return nil end

        local roleName = ply:GetNWString("GRM_Role", "")
        local deptName = ply:GetNWString("GRM_Department", "")
        if deptName == "" then deptName = "Главное Управление" end

        local tpl = (DOC.Templates.factions and DOC.Templates.factions[factionName]) or {}
        local pfx = tpl.prefix or (factionName:sub(1, 3):upper() .. "-")
        local sid64 = ply:SteamID64() or "0"
        local shortSid = sid64:sub(-4)

        if not istable(b) then
            b = {
                fullName    = getPlayerRPName(ply),
                faction     = factionName,
                role        = roleName,
                department  = deptName,
                number      = pfx .. shortSid,
                permissions = tblCopy(tpl.defaultPerms or { weapon = true, transport = true }),
                issuedBy    = "Руководство ведомства " .. factionName,
                issueDate   = os.date("%d.%m.%Y"),
                validUntil  = "Бессрочно",
                status      = "Действителен",
                steamID64   = sid64,
                isCover     = false,
                created     = os.time(),
                updated     = os.time(),
            }
            DOC.Registry.badges[key] = b
            DOC.SaveRegistry("auto create badge for " .. key)
        else
            b.faction = factionName
            b.role = roleName
            if not b.department or b.department == "" or b.department == "Основной" or b.department == "—" then
                b.department = deptName
            end
        end
        return b
    end
    DOC.EnsureBadge = ensureBadge

    -- Получение военного билета
    local function ensureMilitary(ply)
        local key = getCharKey(ply)
        if key == "" then return nil end
        DOC.Registry.military = DOC.Registry.military or {}
        return DOC.Registry.military[key]
    end
    DOC.EnsureMilitary = ensureMilitary

    -- Получение гражданского водительского удостоверения (Дорожная Инспекция)
    local function ensureLicense(ply)
        local key = getCharKey(ply)
        if key == "" then return nil end
        DOC.Registry.licenses = DOC.Registry.licenses or {}
        return DOC.Registry.licenses[key]
    end
    DOC.EnsureLicense = ensureLicense

    -- Получение удостоверения военного водителя (ВАИ)
    local function ensureMilLicense(ply)
        local key = getCharKey(ply)
        if key == "" then return nil end
        DOC.Registry.milLicenses = DOC.Registry.milLicenses or {}
        return DOC.Registry.milLicenses[key]
    end
    DOC.EnsureMilLicense = ensureMilLicense

    -- Лицензии v2: баллы и приостановка
    local function addPoints(charKey, add, reason)
        if not charKey or charKey=="" then return false, "Нет ключа" end
        local lic = DOC.Registry.licenses and DOC.Registry.licenses[charKey]
        local mil = DOC.Registry.milLicenses and DOC.Registry.milLicenses[charKey]
        local target = lic or mil
        if not target then return false, "Нет В/У" end
        target.points = math.max(0, (tonumber(target.points) or 0) + (tonumber(add) or 0))
        target.maxPoints = tonumber(target.maxPoints) or 12
        if target.points >= target.maxPoints then
            target.status = (lic and "Приостановлено (баллы)") or "Приостановлено ВАИ (баллы)"
            target.suspendedUntil = os.time() + 30*24*3600
            target.updated = os.time()
            DOC.SaveRegistry("suspend points "..charKey)
            return true, "Приостановлено до "..os.date("%d.%m.%Y", target.suspendedUntil)
        end
        target.updated = os.time()
        DOC.SaveRegistry("add points "..charKey.." +"..tostring(add).." "..tostring(reason or ""))
        return true, "Баллы: "..tostring(target.points).."/"..tostring(target.maxPoints)
    end
    DOC.AddLicensePoints = addPoints

    function DOC.GetLicensePoints(charKey)
        local lic = DOC.Registry.licenses and DOC.Registry.licenses[charKey]
        local mil = DOC.Registry.milLicenses and DOC.Registry.milLicenses[charKey]
        local t = lic or mil
        if not t then return 0,12 end
        return tonumber(t.points) or 0, tonumber(t.maxPoints) or 12, t.status
    end

    -- Проверка просрочки при выдаче / загрузке (миграция уже есть в PlayerEnteredVehicle, но и тут)
    function DOC.IsLicenseExpired(lic)
        if not lic or not lic.expiry then return false end
        return os.time() > tonumber(lic.expiry)
    end


    -- Проверка прав игрока на выдачу документов
    function DOC.CanIssuePassports(ply)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return true end
        local fac = ply:GetNWString("GRM_Faction", "")
        if fac ~= "" and DOC.Templates.access and DOC.Templates.access.passports and DOC.Templates.access.passports[fac] == true then
            return true
        end
        return false
    end

    function DOC.CanIssueBadges(ply, targetFaction)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return true end
        local fac = ply:GetNWString("GRM_Faction", "")
        if fac == "" then return false end

        local hasBadgeAccess = (DOC.Templates.access and DOC.Templates.access.badges and DOC.Templates.access.badges[fac] == true)
        local isLead = (_G.FactionsAPI and _G.FactionsAPI.IsLeader and _G.FactionsAPI.IsLeader(ply, fac)) == true

        if isLead or hasBadgeAccess then
            if targetFaction == nil or targetFaction == fac then return true end
        end

        if DOC.Templates.access and DOC.Templates.access.coverDocs and DOC.Templates.access.coverDocs[fac] == true then
            return true
        end

        return false
    end

    function DOC.CanIssueMilitary(ply)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return true end
        local fac = ply:GetNWString("GRM_Faction", "")
        if fac ~= "" and DOC.Templates.access and DOC.Templates.access.military and DOC.Templates.access.military[fac] == true then
            return true
        end
        return false
    end

    function DOC.CanIssueLicenses(ply)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return true end
        local fac = ply:GetNWString("GRM_Faction", "")
        if fac ~= "" and DOC.Templates.access and DOC.Templates.access.licenses and DOC.Templates.access.licenses[fac] == true then
            return true
        end
        return false
    end

    function DOC.CanIssueMilLicenses(ply)
        if not IsValid(ply) then return false end
        if ply:IsSuperAdmin() then return true end
        local fac = ply:GetNWString("GRM_Faction", "")
        if fac ~= "" and DOC.Templates.access then
            if DOC.Templates.access.milLicenses and DOC.Templates.access.milLicenses[fac] == true then
                return true
            end
            if DOC.Templates.access.military and DOC.Templates.access.military[fac] == true then
                return true
            end
            if DOC.Templates.access.licenses and DOC.Templates.access.licenses[fac] == true then
                return true
            end
        end
        return false
    end

    -- Отправка документа игроку на экран
    local function sendOwnDoc(ply, docType, subType)
        if not IsValid(ply) then return end
        local payload = nil
        local tpl = nil

        if docType == "passport" then
            payload = ensurePassport(ply)
            tpl = DOC.Templates.passport
        elseif docType == "badge" then
            local key = getCharKey(ply)
            if subType == "cover" then
                payload = DOC.Registry.coverBadges and DOC.Registry.coverBadges[key]
                if not (istable(payload) and payload.status == "Действителен") then
                    if GRM.Notify then GRM.Notify(ply, "У вас нет активного документа прикрытия.", 255, 140, 110) end
                    return
                end
                tpl = (DOC.Templates.factions and DOC.Templates.factions[payload.faction]) or {}
            elseif subType == "official" then
                payload = ensureBadge(ply)
                if not payload then
                    if GRM.Notify then GRM.Notify(ply, "У вас нет служебного удостоверения (вы не состоите во фракции).", 255, 140, 110) end
                    return
                end
                tpl = (DOC.Templates.factions and DOC.Templates.factions[payload.faction]) or {}
            else
                local cover = DOC.Registry.coverBadges and DOC.Registry.coverBadges[key]
                if istable(cover) and cover.status == "Действителен" then
                    payload = cover
                    tpl = (DOC.Templates.factions and DOC.Templates.factions[payload.faction]) or {}
                else
                    payload = ensureBadge(ply)
                    if not payload then
                        if GRM.Notify then GRM.Notify(ply, "У вас нет служебного удостоверения (вы не состоите во фракции).", 255, 140, 110) end
                        return
                    end
                    tpl = (DOC.Templates.factions and DOC.Templates.factions[payload.faction]) or {}
                end
            end
        elseif docType == "military" then
            payload = ensureMilitary(ply)
            if not payload or payload.status == "Аннулирован" then
                if GRM.Notify then GRM.Notify(ply, "У вас нет оформленного военного билета (выдаётся в военкомате через Компьютер).", 255, 140, 110) end
                return
            end
            tpl = DOC.Templates.military or {}
        elseif docType == "license" or docType == "civilian_license" then
            if subType == "military" then
                return sendOwnDoc(ply, "milLicense")
            end
            payload = ensureLicense(ply)
            if not payload or payload.status == "Аннулировано" or payload.status == "Лишён права управления" then
                local mil = ensureMilLicense(ply)
                if mil and mil.status ~= "Аннулировано" and mil.status ~= "Лишён ВАИ" and subType ~= "civilian" then
                    return sendOwnDoc(ply, "milLicense")
                end
                if not payload then
                    if GRM.Notify then GRM.Notify(ply, "У вас нет водительского удостоверения Дорожной Инспекции (оформляется в Автошколе).", 255, 140, 110) end
                    return
                end
            end
            tpl = DOC.Templates.license or {}
        elseif docType == "milLicense" or docType == "military_license" then
            payload = ensureMilLicense(ply)
            if not payload or payload.status == "Аннулировано" or payload.status == "Лишён ВАИ" then
                if GRM.Notify then GRM.Notify(ply, "У вас нет оформленного удостоверения военного водителя ВАИ (выдаётся в Полевой Жандармерии).", 255, 140, 110) end
                return
            end
            tpl = DOC.Templates.militaryLicense or {}
        elseif docType == "medcard" then
            if GRM.Medical and GRM.Medical.CardOf then
                local cardKey = getCharKey(ply)
                payload = GRM.Medical.CardOf(cardKey)
                tpl = { patientName = getPlayerRPName(ply) }
            end
        end

        if payload then
            net.Start(NET_RECEIVE_VIEW)
                net.WriteString(docType)
                net.WriteTable(payload)
                net.WriteTable(tpl or {})
                net.WriteBool(false)
                net.WriteString("")
            net.Send(ply)
        end
    end
    DOC.SendOwnDoc = sendOwnDoc

    -- Трансляция RP-действия в чат всем игрокам поблизости.
    -- Используем ЕДИНЫЙ канал доставки (как sendTo в sh_grm_rp_chat.lua):
    --   1. EasyChat      -> если установлен,
    --   2. GRM RPChat-net-> иначе,
    --   3. ChatPrint     -> последний резерв.
    -- Раньше отыгровка шла всеми тремя сразу и дублировалась в чат.
    local function broadcastDocAction(ply, meText)
        if not IsValid(ply) then return end
        local senderName = getPlayerRPName(ply)
        local fullText = "* " .. senderName .. " " .. meText
        local origin = ply:GetPos()

        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:GetPos():DistToSqr(origin) <= 400 * 400 then
                if EasyChat and EasyChat.PlayerAddText then
                    -- EasyChat сам рисует сообщение — других каналов не трогаем.
                    EasyChat.PlayerAddText(p, Color(200, 160, 255), fullText)
                elseif util.NetworkStringToID("GRM_RPChat_Msg") ~= 0 then
                    -- Клиент GRM RPChat рисует это через chat.AddText (см. sh_grm_rp_chat.lua).
                    net.Start("GRM_RPChat_Msg")
                        net.WriteUInt(2, 8)
                        net.WriteBool(true)
                        net.WriteUInt(200, 8)
                        net.WriteUInt(160, 8)
                        net.WriteUInt(255, 8)
                        net.WriteBool(false)
                        net.WriteString(fullText)
                    net.Send(p)
                else
                    -- Резерв без EasyChat и без GRM RPChat.
                    p:ChatPrint(fullText)
                end
            end
        end
    end

    -- Показ документа целевому игроку (в прицеле или явная цель)
    local function showDocToTarget(ply, docType, explicitTarget, subType)
        if not IsValid(ply) then return end
        local target = explicitTarget
        if not (IsValid(target) and target:IsPlayer() and target:Alive()) then
            local tr = ply:GetEyeTrace()
            target = tr.Entity
        end

        if not (IsValid(target) and target:IsPlayer() and target:Alive()) then
            if GRM.Notify then GRM.Notify(ply, "Наведитесь на игрока перед собой (дистанция до 200 юнитов).", 255, 180, 90) end
            return
        end

        if ply:GetPos():DistToSqr(target:GetPos()) > 200 * 200 then
            if GRM.Notify then GRM.Notify(ply, "Игрок слишком далеко — подойдите ближе.", 255, 180, 90) end
            return
        end

        local senderName = getPlayerRPName(ply)
        local targetName = getPlayerRPName(target)

        if docType == "passport" then
            local pass = ensurePassport(ply)
            local tpl = DOC.Templates.passport or {}

            local meText = string.format("показал(а) паспорт гражданина игроку %s (Серия %s №%s, ФИО: %s)", targetName, pass.series or "GRM", pass.number or "—", pass.fullName or senderName)
            broadcastDocAction(ply, meText)

            net.Start(NET_RECEIVE_VIEW)
                net.WriteString("passport")
                net.WriteTable(pass)
                net.WriteTable(tpl)
                net.WriteBool(true)
                net.WriteString(senderName)
            net.Send(target)

            if GRM.Notify then GRM.Notify(ply, "Вы показали паспорт гражданина игроку " .. targetName .. ".", 100, 220, 130) end

        elseif docType == "badge" then
            local key = getCharKey(ply)
            local badge = nil

            if subType == "cover" then
                badge = DOC.Registry.coverBadges and DOC.Registry.coverBadges[key]
            elseif subType == "official" then
                badge = ensureBadge(ply)
            else
                badge = (DOC.Registry.coverBadges and DOC.Registry.coverBadges[key] and DOC.Registry.coverBadges[key].status == "Действителен" and DOC.Registry.coverBadges[key])
                    or ensureBadge(ply)
            end

            if not badge then
                if GRM.Notify then GRM.Notify(ply, "У вас нет служебного удостоверения (вы не состоите во фракции).", 255, 140, 110) end
                return
            end
            local tpl = (DOC.Templates.factions and DOC.Templates.factions[badge.faction]) or {}

            local meText = string.format("предъявил(а) служебное удостоверение %s игроку %s (Жетон: %s, Должность: %s)", badge.faction or "организации", targetName, badge.number or "—", badge.role or "—")
            broadcastDocAction(ply, meText)

            net.Start(NET_RECEIVE_VIEW)
                net.WriteString("badge")
                net.WriteTable(badge)
                net.WriteTable(tpl)
                net.WriteBool(true)
                net.WriteString(senderName)
            net.Send(target)

            if GRM.Notify then GRM.Notify(ply, "Вы предъявили служебное удостоверение игроку " .. targetName .. ".", 100, 220, 130) end

        elseif docType == "military" then
            local mil = ensureMilitary(ply)
            if not mil or mil.status == "Аннулирован" then
                if GRM.Notify then GRM.Notify(ply, "У вас нет оформленного военного билета (выдаётся в военкомате через Компьютер).", 255, 140, 110) end
                return
            end
            local tpl = DOC.Templates.military or {}

            local meText = string.format("показал(а) военный билет игроку %s (Военный билет №%s, Звание: %s, Формирование: %s)", targetName, mil.number or "—", mil.rank or "—", mil.formation or "—")
            broadcastDocAction(ply, meText)

            net.Start(NET_RECEIVE_VIEW)
                net.WriteString("military")
                net.WriteTable(mil)
                net.WriteTable(tpl)
                net.WriteBool(true)
                net.WriteString(senderName)
            net.Send(target)

            if GRM.Notify then GRM.Notify(ply, "Вы показали военный билет игроку " .. targetName .. ".", 100, 220, 130) end

        elseif docType == "license" or docType == "civilian_license" then
            if subType == "military" then
                return showDocToTarget(ply, "milLicense", target, "military")
            end
            local lic = ensureLicense(ply)
            if not lic or lic.status == "Аннулировано" then
                local mil = ensureMilLicense(ply)
                if mil and mil.status ~= "Аннулировано" and subType ~= "civilian" then
                    return showDocToTarget(ply, "milLicense", target, "military")
                end
                if not lic then
                    if GRM.Notify then GRM.Notify(ply, "У вас нет водительского удостоверения (оформляется в Автошколе).", 255, 140, 110) end
                    return
                end
            end
            local tpl = DOC.Templates.license or {}

            local meText = string.format("показал(а) водительское удостоверение Дорожной Инспекции игроку %s (№%s, Категории: %s)", targetName, lic.number or "—", lic.categoriesStr or "B")
            broadcastDocAction(ply, meText)

            net.Start(NET_RECEIVE_VIEW)
                net.WriteString("license")
                net.WriteTable(lic)
                net.WriteTable(tpl)
                net.WriteBool(true)
                net.WriteString(senderName)
            net.Send(target)

            if GRM.Notify then GRM.Notify(ply, "Вы показали водительские права игроку " .. targetName .. ".", 100, 220, 130) end

        elseif docType == "milLicense" or docType == "military_license" then
            local milLic = ensureMilLicense(ply)
            if not milLic or milLic.status == "Аннулировано" then
                if GRM.Notify then GRM.Notify(ply, "У вас нет оформленного удостоверения военного водителя ВАИ.", 255, 140, 110) end
                return
            end
            local tpl = DOC.Templates.militaryLicense or {}

            local meText = string.format("предъявил(а) удостоверение военного водителя ВАИ игроку %s (№%s, Звание: %s, ВУС: %s, Категории: %s)", targetName, milLic.number or "—", milLic.rank or "Рядовой", milLic.vus or "ВУС-837", milLic.categoriesStr or "B-В C-В")
            broadcastDocAction(ply, meText)

            net.Start(NET_RECEIVE_VIEW)
                net.WriteString("milLicense")
                net.WriteTable(milLic)
                net.WriteTable(tpl)
                net.WriteBool(true)
                net.WriteString(senderName)
            net.Send(target)

            if GRM.Notify then GRM.Notify(ply, "Вы предъявили удостоверение военного водителя ВАИ игроку " .. targetName .. ".", 100, 220, 130) end

        elseif docType == "medcard" then
            if GRM.Medical and GRM.Medical.CardOf then
                local cardKey = getCharKey(ply)
                local card = GRM.Medical.CardOf(cardKey)
                local meText = string.format("передал(а) медицинскую карту на имя %s игроку %s", getPlayerRPName(ply), targetName)
                broadcastDocAction(ply, meText)

                net.Start(NET_RECEIVE_VIEW)
                    net.WriteString("medcard")
                    net.WriteTable(card or {})
                    net.WriteTable({ patientName = getPlayerRPName(ply) })
                    net.WriteBool(true)
                    net.WriteString(senderName)
                net.Send(target)

                if GRM.Notify then GRM.Notify(ply, "Вы передали медицинскую карту игроку " .. targetName .. ".", 100, 220, 130) end
            end
        end
    end
    DOC.ShowDocToTarget = showDocToTarget

    -- Регистрация предметов инвентаря для быстрого открытия
    local function regInventoryItems()
        if not (GRM.Inventory and GRM.Inventory.RegisterItem) then return end
        GRM.Inventory.RegisterItem("passport", {
            type     = "item",
            name     = "Паспорт гражданина",
            desc     = "Главный документ, удостоверяющий личность гражданина. «Использовать» — открыть паспорт.",
            icon     = "icon16/book.png",
            maxStack = 1,
            weight   = 0.1,
            model    = "models/props_lab/clipboard.mdl",
            useFunc  = "doc_passport_view",
        })
        GRM.Inventory.RegisterItem("badge", {
            type     = "item",
            name     = "Служебное удостоверение",
            desc     = "Служебное удостоверение сотрудника ведомства. «Использовать» — открыть корочку.",
            icon     = "icon16/shield.png",
            maxStack = 1,
            weight   = 0.1,
            model    = "models/props_lab/clipboard.mdl",
            useFunc  = "doc_badge_view",
        })
        GRM.Inventory.RegisterItem("military_ticket", {
            type     = "item",
            name     = "Военный билет",
            desc     = "Военный билет военнослужащего. «Использовать» — открыть военный билет.",
            icon     = "icon16/book_open.png",
            maxStack = 1,
            weight   = 0.1,
            model    = "models/props_lab/clipboard.mdl",
            useFunc  = "doc_military_view",
        })
        GRM.Inventory.RegisterItem("driver_license", {
            type     = "item",
            name     = "Водительское удостоверение",
            desc     = "Водительские права на управление ТС Дорожной Инспекции. «Использовать» — открыть удостоверение.",
            icon     = "icon16/car.png",
            maxStack = 1,
            weight   = 0.05,
            model    = "models/props_lab/clipboard.mdl",
            useFunc  = "doc_license_view",
        })
        GRM.Inventory.RegisterItem("military_license", {
            type     = "item",
            name     = "Удостоверение военного водителя (ВАИ)",
            desc     = "Военное водительское удостоверение ВАИ с допусками к управлению военной техникой. «Использовать» — открыть.",
            icon     = "icon16/car.png",
            maxStack = 1,
            weight   = 0.05,
            model    = "models/props_lab/clipboard.mdl",
            useFunc  = "doc_mil_license_view",
        })

        if GRM.Inventory.RegisterUseHandler then
            GRM.Inventory.RegisterUseHandler("doc_passport_view", function(ply) sendOwnDoc(ply, "passport") return true end)
            GRM.Inventory.RegisterUseHandler("doc_badge_view", function(ply) sendOwnDoc(ply, "badge") return true end)
            GRM.Inventory.RegisterUseHandler("doc_military_view", function(ply) sendOwnDoc(ply, "military") return true end)
            GRM.Inventory.RegisterUseHandler("doc_license_view", function(ply) sendOwnDoc(ply, "license", "civilian") return true end)
            GRM.Inventory.RegisterUseHandler("doc_mil_license_view", function(ply) sendOwnDoc(ply, "milLicense", "military") return true end)
        end
    end
    regInventoryItems()
    timer.Simple(2, regInventoryItems)

    -- Сетевые обработчики
    net.Receive(NET_OPEN_DOC, function(_, ply)
        local docType = net.ReadString()
        local subType = net.ReadString()
        sendOwnDoc(ply, docType, subType)
    end)

    net.Receive(NET_SHOW_DOC, function(_, ply)
        local docType = net.ReadString()
        local target = net.ReadEntity()
        local subType = net.ReadString()
        showDocToTarget(ply, docType, target, subType)
    end)

    net.Receive(NET_ADMIN_GET, function(_, ply)
        if not (IsValid(ply) and ply:IsSuperAdmin()) then return end
        net.Start(NET_ADMIN_GET)
            net.WriteTable(DOC.Templates)
        net.Send(ply)
    end)

    net.Receive(NET_ADMIN_SAVE, function(_, ply)
        if not (IsValid(ply) and ply:IsSuperAdmin()) then return end
        local tpl = net.ReadTable()
        if istable(tpl) then
            if istable(tpl.passport)        then DOC.Templates.passport        = tpl.passport end
            if istable(tpl.military)        then DOC.Templates.military        = tpl.military end
            if istable(tpl.license)         then DOC.Templates.license         = tpl.license end
            if istable(tpl.militaryLicense) then DOC.Templates.militaryLicense = tpl.militaryLicense end
            if istable(tpl.factions)        then DOC.Templates.factions        = tpl.factions end
            if istable(tpl.access)          then DOC.Templates.access          = tpl.access end
            DOC.SaveTemplates("admin edit by " .. ply:Nick())
        end
    end)

    net.Receive(NET_COMPUTER_ISSUE, function(_, ply)
        if not IsValid(ply) then return end
        local docType = net.ReadString()
        local targetKey = net.ReadString()
        local data = net.ReadTable()

        if not isstring(targetKey) or targetKey == "" or not istable(data) then return end

        if docType == "passport" then
            if not DOC.CanIssuePassports(ply) then return end
            DOC.Registry.passports[targetKey] = data
            DOC.SaveRegistry("issue passport " .. targetKey .. " by " .. ply:Nick())

        elseif docType == "badge" then
            local myFac = ply:GetNWString("GRM_Faction", "")
            if data.isCover == true then
                if not (ply:IsSuperAdmin() or (DOC.Templates.access and DOC.Templates.access.coverDocs and DOC.Templates.access.coverDocs[myFac] == true)) then
                    if GRM.Notify then GRM.Notify(ply, "У вашей фракции нет допуска к оформлению документов прикрытия!", 255, 100, 100) end
                    return
                end
                DOC.Registry.coverBadges[targetKey] = data
                DOC.SaveRegistry("issue cover doc " .. targetKey .. " by " .. ply:Nick())
            else
                if not DOC.CanIssueBadges(ply, data.faction) then
                    if GRM.Notify then GRM.Notify(ply, "У вас нет права выдавать удостоверения этой организации!", 255, 100, 100) end
                    return
                end
                DOC.Registry.badges[targetKey] = data
                DOC.SaveRegistry("issue badge " .. targetKey .. " by " .. ply:Nick())
            end

        elseif docType == "military" then
            if not DOC.CanIssueMilitary(ply) then
                if GRM.Notify then GRM.Notify(ply, "У вашей фракции нет допуска к оформлению военных билетов!", 255, 100, 100) end
                return
            end
            DOC.Registry.military[targetKey] = data
            DOC.SaveRegistry("issue military " .. targetKey .. " by " .. ply:Nick())

        elseif docType == "license" or docType == "civilian_license" then
            if not DOC.CanIssueLicenses(ply) then
                if GRM.Notify then GRM.Notify(ply, "У вашей фракции нет допуска к выдаче водительских прав!", 255, 100, 100) end
                return
            end
            DOC.Registry.licenses[targetKey] = data
            DOC.SaveRegistry("issue civilian license " .. targetKey .. " by " .. ply:Nick())

        elseif docType == "milLicense" or docType == "license_mil" or docType == "military_license" then
            if not DOC.CanIssueMilLicenses(ply) then
                if GRM.Notify then GRM.Notify(ply, "У вашей фракции нет допуска к выдаче военных водительских удостоверений (ВАИ)!", 255, 100, 100) end
                return
            end
            DOC.Registry.milLicenses[targetKey] = data
            DOC.SaveRegistry("issue military license " .. targetKey .. " by " .. ply:Nick())
        end

        if GRM.Notify then GRM.Notify(ply, "Документ успешно оформлен и внесён в базу данных.", 100, 220, 120) end
    end)

    net.Receive(NET_COMPUTER_REVOKE, function(_, ply)
        if not IsValid(ply) then return end
        local docType = net.ReadString()
        local targetKey = net.ReadString()
        if not isstring(targetKey) or targetKey == "" then return end

        if docType == "passport" and DOC.Registry.passports[targetKey] then
            if not DOC.CanIssuePassports(ply) then return end
            DOC.Registry.passports[targetKey].status = "Аннулирован"
            DOC.Registry.passports[targetKey].updated = os.time()
            DOC.SaveRegistry("revoke passport " .. targetKey)

        elseif docType == "badge" and DOC.Registry.badges[targetKey] then
            if not DOC.CanIssueBadges(ply, DOC.Registry.badges[targetKey].faction) then return end
            DOC.Registry.badges[targetKey].status = "Аннулирован / Изъят"
            DOC.Registry.badges[targetKey].updated = os.time()
            DOC.SaveRegistry("revoke badge " .. targetKey)

        elseif docType == "cover" and DOC.Registry.coverBadges[targetKey] then
            DOC.Registry.coverBadges[targetKey].status = "Аннулирован"
            DOC.Registry.coverBadges[targetKey].updated = os.time()
            DOC.SaveRegistry("revoke cover " .. targetKey)

        elseif docType == "military" and DOC.Registry.military[targetKey] then
            if not DOC.CanIssueMilitary(ply) then return end
            DOC.Registry.military[targetKey].status = "Аннулирован"
            DOC.Registry.military[targetKey].updated = os.time()
            DOC.SaveRegistry("revoke military " .. targetKey)

        elseif (docType == "license" or docType == "civilian_license") and DOC.Registry.licenses[targetKey] then
            if not DOC.CanIssueLicenses(ply) then return end
            DOC.Registry.licenses[targetKey].status = "Лишён права управления"
            DOC.Registry.licenses[targetKey].updated = os.time()
            DOC.SaveRegistry("revoke civilian license " .. targetKey)

        elseif (docType == "milLicense" or docType == "license_mil" or docType == "military_license") and DOC.Registry.milLicenses[targetKey] then
            if not DOC.CanIssueMilLicenses(ply) then return end
            DOC.Registry.milLicenses[targetKey].status = "Лишён ВАИ"
            DOC.Registry.milLicenses[targetKey].updated = os.time()
            DOC.SaveRegistry("revoke military license " .. targetKey)
        end

        if GRM.Notify then GRM.Notify(ply, "Статус документа изменён (аннулирован / лишён прав).", 255, 140, 100) end
    end)

    -- Инспекция водительских прав при посадке за руль
    local playerVehicleCooldowns = {}
    hook.Add("PlayerEnteredVehicle", "GRM_Doc_VehicleDriverCheck", function(ply, veh, role)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        if not IsValid(veh) then return end
        if role and role ~= 0 then return end

        local now = CurTime()
        local sid = ply:SteamID64() or "0"
        if playerVehicleCooldowns[sid] and (now - playerVehicleCooldowns[sid]) < 8 then
            return
        end
        playerVehicleCooldowns[sid] = now

        local charKey = getCharKey(ply)
        local civLic = DOC.Registry.licenses and DOC.Registry.licenses[charKey]
        local milLic = DOC.Registry.milLicenses and DOC.Registry.milLicenses[charKey]

        local mdl = string.lower(veh:GetModel() or "")
        local cl = string.lower(veh:GetClass() or "")

        local reqCatCiv = "B"
        local reqCatMil = "B-В"
        local catName = "B (Легковой автотранспорт)"

        if mdl:find("moto") or mdl:find("bike") or mdl:find("quad") or cl:find("moto") or cl:find("bicycle") then
            reqCatCiv = "A"
            reqCatMil = "A-В"
            catName = "A (Мототранспорт)"
        elseif mdl:find("bus") or mdl:find("coach") or mdl:find("transit") then
            reqCatCiv = "D"
            reqCatMil = "D-В"
            catName = "D (Автобусы и пассажирский транспорт)"
        elseif mdl:find("btr") or mdl:find("bmp") or mdl:find("tank") or mdl:find("apc") or mdl:find("armored") or mdl:find("mtlb") then
            reqCatCiv = "SPEC"
            reqCatMil = "СПЕЦ-В"
            catName = "СПЕЦ-В (Бронетехника / Спецмашины)"
        elseif mdl:find("truck") or mdl:find("kamaz") or mdl:find("ural") or mdl:find("zil") or mdl:find("semi") or mdl:find("tractor") or mdl:find("trailer") then
            reqCatCiv = "C"
            reqCatMil = "C-В"
            catName = "C (Грузовой автотранспорт)"
        end

        -- v2.0 expiry/points/suspended check + migration
        local function isExpired(lic)
            if not lic then return false end
            if lic.expiry and tonumber(lic.expiry) and tonumber(lic.expiry) > 0 then
                return os.time() > tonumber(lic.expiry)
            end
            return false
        end
        local function isSuspended(lic)
            if not lic then return false, 0 end
            if lic.suspendedUntil and tonumber(lic.suspendedUntil) and tonumber(lic.suspendedUntil) > os.time() then
                return true, tonumber(lic.suspendedUntil)
            end
            if isstring(lic.status) and lic.status:find("Приостановлен") then
                -- fallback parse date if suspendedUntil missing, treat as suspended
                return true, 0
            end
            return false, 0
        end
        local function hasPointsIssue(lic)
            if not lic then return false end
            local pts = tonumber(lic.points) or 0
            local maxPts = tonumber(lic.maxPoints) or 12
            return pts >= maxPts
        end

        -- migration for old records: add expiry = created + 10y civ / 5y mil, points=0
        if civLic and not civLic.expiry then
            local base = tonumber(civLic.created) or os.time()
            civLic.expiry = base + 10*365*24*3600
            civLic.points = civLic.points or 0
            civLic.maxPoints = civLic.maxPoints or 12
        end
        if milLic and not milLic.expiry then
            local base = tonumber(milLic.created) or os.time()
            milLic.expiry = base + 5*365*24*3600
            milLic.points = milLic.points or 0
            milLic.maxPoints = milLic.maxPoints or 12
        end

        local hasCivCat = civLic and istable(civLic.categories) and (civLic.categories[reqCatCiv] == true or civLic.categories["SPEC"] == true)
        local hasMilCat = milLic and istable(milLic.categories) and (milLic.categories[reqCatMil] == true or milLic.categories["СПЕЦ-В"] == true)

        local civExpired = isExpired(civLic)
        local milExpired = isExpired(milLic)
        local civSusp, civSuspUntil = isSuspended(civLic)
        local milSusp, milSuspUntil = isSuspended(milLic)
        local civPointsBad = hasPointsIssue(civLic)
        local milPointsBad = hasPointsIssue(milLic)

        local hasCiv = hasCivCat and civLic and (civLic.status == "Действительно" or civLic.status == "Действителен") and not civExpired and not civSusp and not civPointsBad
        local hasMil = hasMilCat and milLic and (milLic.status == "Действительно" or milLic.status == "Действительно (на службе)" or milLic.status == "Действителен") and not milExpired and not milSusp and not milPointsBad

        if hasMil then
            if GRM.Notify then
                local extra = ""
                if milLic.points and tonumber(milLic.points) and tonumber(milLic.points) > 0 then extra = " | Баллы: "..tostring(milLic.points).."/"..tostring(milLic.maxPoints or 12) end
                GRM.Notify(ply, "ВАИ проверено (Категория " .. reqCatMil .. " действительна)"..extra..".", 100, 200, 120)
            end
        elseif hasCiv then
            if GRM.Notify then
                local extra = ""
                if civLic.points and tonumber(civLic.points) and tonumber(civLic.points) > 0 then extra = " | Баллы: "..tostring(civLic.points).."/"..tostring(civLic.maxPoints or 12) end
                GRM.Notify(ply, "В/У проверено (Категория " .. reqCatCiv .. " действительна)"..extra..".", 100, 200, 120)
            end
        else
            if civExpired or milExpired then
                if GRM.Notify then GRM.Notify(ply, "ВНИМАНИЕ: Срок действия В/У истёк! Обратитесь в Автоинспекцию/ВАИ для перевыпуска.", 255, 80, 80) end
                ply:ChatPrint("[Автоинспекция] ВУ просрочено — требуется перевыпуск.")
            elseif civSusp or milSusp then
                local untilStr = ""
                local untilTs = civSusp and civSuspUntil or milSuspUntil
                if untilTs and untilTs > 0 then untilStr = " до "..os.date("%d.%m.%Y", untilTs) end
                if GRM.Notify then GRM.Notify(ply, "ВНИМАНИЕ: В/У приостановлено"..untilStr.."!", 255, 80, 80) end
                ply:ChatPrint("[Автоинспекция] В/У приостановлено"..untilStr..".")
            elseif civPointsBad or milPointsBad then
                if GRM.Notify then GRM.Notify(ply, "ВНИМАНИЕ: Превышены баллы нарушений (12/12) — В/У подлежит приостановке!", 255, 80, 80) end
                ply:ChatPrint("[Автоинспекция] Баллы 12/12 — обратитесь в ГАИ.")
            elseif (civLic and civLic.status == "Лишён права управления") or (milLic and milLic.status == "Лишён ВАИ") then
                if GRM.Notify then GRM.Notify(ply, "ВНИМАНИЕ: Вы лишены права управления ТС!", 255, 80, 80) end
                ply:ChatPrint("[Автоинспекция] Вы лишены прав — управление незаконно!")
            else
                if GRM.Notify then GRM.Notify(ply, "Внимание: Нет В/У категории " .. catName .. "!", 255, 160, 60) end
                ply:ChatPrint("[Автоинспекция] Нет прав категории " .. catName .. " (Автошкола/ВАИ).")
            end
        end
    end)

    -- Обработка чат-команд на сервере
    hook.Add("PlayerSayTransform", "GRM_Doc_Commands", function(ply, datapack)
        if not IsValid(ply) or not istable(datapack) then return end
        local txt = datapack[1] or ""
        local low = string.lower(string.Trim(txt))

        -- Паспорт
        if low == "/passport" or low == "/pass" or low == "/myid" or low == "/id" or low == "/mypasport" or low == "/паспорт" or low == "/пас" then
            sendOwnDoc(ply, "passport")
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end
        if low == "/showpassport" or low == "/showpass" or low == "/showid" or low == "/показатьпаспорт" or low == "/покпас" then
            showDocToTarget(ply, "passport")
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end

        -- Удостоверение
        if low == "/badge" or low == "/mybadge" or low == "/udost" or low == "/myudost" or low == "/ксива" or low == "/удостоверение" or low == "/удост" then
            sendOwnDoc(ply, "badge")
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end
        if low == "/showbadge" or low == "/showudost" or low == "/показатьудостоверение" or low == "/показатьксиву" or low == "/покудост" then
            showDocToTarget(ply, "badge")
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end

        -- Военный билет
        if low == "/military" or low == "/militaryid" or low == "/milcard" or low == "/warcard" or low == "/vb" or low == "/военник" or low == "/военныйбилет" or low == "/вб" then
            sendOwnDoc(ply, "military")
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end
        if low == "/showmilitary" or low == "/showmilitaryid" or low == "/showmil" or low == "/showwarcard" or low == "/showvb" or low == "/показатьвоенник" or low == "/показатьвоенныйбилет" or low == "/поквб" then
            showDocToTarget(ply, "military")
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end

        -- Водительские права (Гражданские)
        if low == "/civlicense" or low == "/civprava" or low == "/гражданскиеправа" or low == "/граждправа" then
            sendOwnDoc(ply, "license", "civilian")
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end
        if low == "/showcivlicense" or low == "/showcivprava" or low == "/показатьгражданскиеправа" or low == "/покграждправа" then
            showDocToTarget(ply, "license", nil, "civilian")
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end

        -- Военные водительские права (ВАИ)
        if low == "/millicense" or low == "/milprava" or low == "/mallicense" or low == "/военныеправа" or low == "/ваиправа" or low == "/вуваи" or low == "/увв" or low == "/военноеву" or low == "/прававаи" or low == "/военныеводправа" then
            sendOwnDoc(ply, "milLicense", "military")
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end
        if low == "/showmillicense" or low == "/showmilprava" or low == "/показатьваи" or low == "/показатьвоенныеправа" or low == "/покваи" or low == "/покувв" or low == "/показатьувв" or low == "/поквоенправа" then
            showDocToTarget(ply, "milLicense", nil, "military")
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end

        -- Водительские права (Общая команда)
        if low == "/license" or low == "/prava" or low == "/mylicense" or low == "/driverlicense" or low == "/права" or low == "/водправа" or low == "/водительское" or low == "/ву" then
            sendOwnDoc(ply, "license")
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end
        if low == "/showlicense" or low == "/showprava" or low == "/showdriverlicense" or low == "/показатьправа" or low == "/показатьводправа" or low == "/покправа" or low == "/покву" then
            showDocToTarget(ply, "license")
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end

        -- Медкарта
        if low == "/medcard" or low == "/mycard" or low == "/med" or low == "/медкарта" or low == "/мед" then
            sendOwnDoc(ply, "medcard")
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end
        if low == "/showmedcard" or low == "/showmed" or low == "/показатьмедкарту" or low == "/покмед" then
            showDocToTarget(ply, "medcard")
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end

        -- Лицензии v2: баллы
        if low == "/license_points" or low == "/points" or low == "/баллы" or low == "/моибаллы" then
            local key = getCharKey(ply)
            local pts, maxPts, status = DOC.GetLicensePoints(key)
            if GRM.Notify then GRM.Notify(ply, "Баллы В/У: "..tostring(pts).."/"..tostring(maxPts).." | Статус: "..tostring(status or "Нет В/У"), 100, 200, 160) end
            ply:ChatPrint("[Автоинспекция] Баллы: "..tostring(pts).."/"..tostring(maxPts).." | Статус: "..tostring(status or "Нет В/У"))
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end
        if low:find("^/license_check") or low:find("^/check_license") or low:find("^/проверить_права") then
            -- формат: /license_check <часть ника/charKey>
            local targetName = string.Trim(txt:sub(("/license_check"):len()+1))
            if targetName=="" then targetName = string.Trim(txt:sub(("/check_license"):len()+1)) end
            if targetName=="" then targetName = string.Trim(txt:sub(("/проверить_права"):len()+1)) end
            if targetName=="" then
                if GRM.Notify then GRM.Notify(ply, "Укажите ник/ключ для проверки: /license_check <ник>", 255,160,80) end
                datapack.SkipPlayerSay=true
                datapack[1]=""
                return
            end
            -- поиск по онлайн
            local foundKey=nil
            for _,p in ipairs(player.GetAll()) do
                if IsValid(p) and (p:Nick():lower():find(targetName:lower(),1,true) or (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(p)==targetName)) then
                    foundKey = getCharKey(p)
                    break
                end
            end
            if not foundKey then foundKey=targetName end
            local pts,maxPts,status = DOC.GetLicensePoints(foundKey)
            if GRM.Notify then GRM.Notify(ply, "Проверка В/У "..foundKey..": "..tostring(pts).."/"..tostring(maxPts).." | "..tostring(status or "Нет"), 100,200,160) end
            datapack.SkipPlayerSay=true
            datapack[1]=""
            return
        end

        -- Админка
        if low == "/doc_admin" or low == "/doccfg" or low == "/docadmin" or low == "/документы" or low == "/докадмин" then
            if ply:IsSuperAdmin() then
                net.Start(NET_ADMIN_GET)
                    net.WriteTable(DOC.Templates)
                net.Send(ply)
            end
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end
    end)

    print("[GRM Documents] Core v" .. DOC.Version .. " (Server) loaded")
end

-- ============================================================
-- КЛИЕНТСКАЯ ЧАСТЬ (Интерактивные развороты документов и UI)
-- ============================================================
if CLIENT then
    surface.CreateFont("GRMDoc_CoverTitle", { font = "Roboto", size = 20, weight = 900, extended = true, antialias = true })
    surface.CreateFont("GRMDoc_Foil",       { font = "Roboto", size = 17, weight = 800, extended = true, antialias = true })
    surface.CreateFont("GRMDoc_Header",     { font = "Roboto", size = 15, weight = 700, extended = true, antialias = true })
    surface.CreateFont("GRMDoc_Normal",     { font = "Roboto", size = 13, weight = 500, extended = true, antialias = true })
    surface.CreateFont("GRMDoc_Bold",       { font = "Roboto", size = 13, weight = 700, extended = true, antialias = true })
    surface.CreateFont("GRMDoc_Small",      { font = "Roboto", size = 11, weight = 500, extended = true, antialias = true })
    surface.CreateFont("GRMDoc_Tiny",       { font = "Roboto", size = 10, weight = 400, extended = true, antialias = true })
    surface.CreateFont("GRMDoc_MRZ",        { font = "Courier New", size = 12, weight = 700, extended = true, antialias = true })
    surface.CreateFont("GRMDoc_Badge",      { font = "Roboto", size = 12, weight = 800, extended = true, antialias = true })

    -- Хелпер авто-переноса текста
    local function wrapText(text, font, maxW)
        if not isstring(text) or text == "" then return { "" } end
        surface.SetFont(font)
        local words = string.Explode(" ", text)
        local lines = {}
        local curLine = ""

        for _, word in ipairs(words) do
            local testLine = (curLine == "") and word or (curLine .. " " .. word)
            local w, _ = surface.GetTextSize(testLine)
            if w > maxW and curLine ~= "" then
                lines[#lines + 1] = curLine
                curLine = word
            else
                curLine = testLine
            end
        end
        if curLine ~= "" then
            lines[#lines + 1] = curLine
        end
        return lines
    end

    local function drawWrapped(text, font, x, y, maxW, lineH, col, alignX)
        local lines = wrapText(text, font, maxW)
        alignX = alignX or TEXT_ALIGN_LEFT
        for i, line in ipairs(lines) do
            draw.SimpleText(line, font, x, y + (i - 1) * lineH, col, alignX, TEXT_ALIGN_TOP)
        end
        return #lines * lineH
    end

    local function safeClearFrame(f)
        if not IsValid(f) then return end
        for _, ch in ipairs(f:GetChildren() or {}) do
            if IsValid(ch) and ch ~= f.btnClose and ch ~= f.btnMaxim and ch ~= f.btnMinim and ch ~= f.lblTitle then
                ch:Remove()
            end
        end
    end

    -- Меню выбора водительских прав при наличии обоих документов
    function DOC.ShowLicenseChoiceDialog(targetEnt, isShow)
        local frame = vgui.Create("DFrame")
        frame:SetSize(460, 220)
        frame:Center()
        frame:SetTitle("")
        frame:MakePopup()
        frame:ShowCloseButton(false)

        frame.Paint = function(s, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(24, 28, 38, 250))
            draw.RoundedBox(6, 2, 2, w - 4, 34, Color(35, 45, 60))
            draw.SimpleText("ВЫБОР ВОДИТЕЛЬСКОГО УДОСТОВЕРЕНИЯ", "GRMDoc_Bold", w / 2, 17, Color(240, 245, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            local sub = isShow and "Выберите удостоверение для предъявления игроку:" or "Выберите удостоверение для личного просмотра:"
            draw.SimpleText(sub, "GRMDoc_Small", w / 2, 50, Color(180, 190, 205), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end

        local btnCiv = vgui.Create("DButton", frame)
        btnCiv:SetSize(420, 44)
        btnCiv:SetPos(20, 75)
        btnCiv:SetText("Дорожная Инспекция ПП (Гражданские права)")
        btnCiv:SetFont("GRMDoc_Bold")
        btnCiv:SetTextColor(color_white)
        btnCiv:SetIcon("icon16/car.png")
        btnCiv.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(35, 90, 180) or Color(25, 70, 140))
            surface.SetDrawColor(80, 140, 240, 180)
            surface.DrawOutlinedRect(0, 0, w, h)
        end
        btnCiv.DoClick = function()
            frame:Close()
            if isShow then
                net.Start(NET_SHOW_DOC)
                    net.WriteString("license")
                    net.WriteEntity(IsValid(targetEnt) and targetEnt or LocalPlayer():GetEyeTrace().Entity)
                    net.WriteString("civilian")
                net.SendToServer()
            else
                net.Start(NET_OPEN_DOC)
                    net.WriteString("license")
                    net.WriteString("civilian")
                net.SendToServer()
            end
        end

        local btnMil = vgui.Create("DButton", frame)
        btnMil:SetSize(420, 44)
        btnMil:SetPos(20, 130)
        btnMil:SetText("Военная Автоинспекция (ВАИ Полевой Жандармерии)")
        btnMil:SetFont("GRMDoc_Bold")
        btnMil:SetTextColor(color_white)
        btnMil:SetIcon("icon16/shield.png")
        btnMil.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(45, 110, 50) or Color(35, 85, 40))
            surface.SetDrawColor(100, 200, 110, 180)
            surface.DrawOutlinedRect(0, 0, w, h)
        end
        btnMil.DoClick = function()
            frame:Close()
            if isShow then
                net.Start(NET_SHOW_DOC)
                    net.WriteString("milLicense")
                    net.WriteEntity(IsValid(targetEnt) and targetEnt or LocalPlayer():GetEyeTrace().Entity)
                    net.WriteString("military")
                net.SendToServer()
            else
                net.Start(NET_OPEN_DOC)
                    net.WriteString("milLicense")
                    net.WriteString("military")
                net.SendToServer()
            end
        end

        local btnClose = vgui.Create("DButton", frame)
        btnClose:SetSize(28, 22)
        btnClose:SetPos(frame:GetWide() - 34, 6)
        btnClose:SetText("✕")
        btnClose:SetTextColor(Color(200, 210, 225))
        btnClose:SetFont("GRMDoc_Bold")
        btnClose.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 80, 80) or Color(0, 0, 0, 0)) end
        btnClose.DoClick = function() frame:Close() end
    end

    -- ── ДВУХФАЗНЫЙ РЕНДЕР ПАСПОРТА ─────────────────────────────
    local function openPassportUI(data, tpl, isShown, senderName)
        tpl = tpl or {}
        local coverCol = tpl.coverColor and Color(tpl.coverColor.r or 85, tpl.coverColor.g or 20, tpl.coverColor.b or 25) or Color(85, 20, 25)
        local foil = DOC.FoilStyles[tpl.foilStyle or "gold"] or DOC.FoilStyles.gold

        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:MakePopup()
        frame:ShowCloseButton(false)

        local function setPhase(expanded)
            if not expanded then
                safeClearFrame(frame)
                frame:SetSize(380, 520)
                frame:Center()

                frame.Paint = function(_, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, coverCol)
                    draw.RoundedBox(6, 12, 12, w - 24, h - 24, Color(coverCol.r + 10, coverCol.g + 10, coverCol.b + 10))

                    draw.SimpleText(tpl.stateTitle or "РЕСПУБЛИКА ГРАНД", "GRMDoc_CoverTitle", w / 2, 60, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("★ ★ ★", "GRMDoc_CoverTitle", w / 2, 140, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("ГОСУДАРСТВЕННЫЙ ГЕРБ", "GRMDoc_Small", w / 2, 175, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    draw.SimpleText(tpl.docTitle or "ПАСПОРТ ГРАЖДАНИНА", "GRMDoc_Foil", w / 2, 320, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("PASSPORT", "GRMDoc_Small", w / 2, 345, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    local topTitle = isShown and ("Вам показал(а) паспорт: " .. tostring(senderName)) or "Ваш паспорт"
                    draw.SimpleText(topTitle, "GRMDoc_Small", w / 2, 20, Color(220, 220, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                end

                local btnExpand = vgui.Create("DButton", frame)
                btnExpand:SetSize(320, 42)
                btnExpand:SetPos(30, 440)
                btnExpand:SetText("◄► Кликните, чтобы развернуть паспорт")
                btnExpand:SetFont("GRMDoc_Bold")
                btnExpand:SetTextColor(foil.col)
                btnExpand.Paint = function(s, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(0, 0, 0, 180) or Color(0, 0, 0, 120))
                    surface.SetDrawColor(foil.col.r, foil.col.g, foil.col.b, 160)
                    surface.DrawOutlinedRect(0, 0, w, h)
                end
                btnExpand.DoClick = function() surface.PlaySound("garrysmod/ui_click.wav") setPhase(true) end

                local btnClose = vgui.Create("DButton", frame)
                btnClose:SetSize(28, 24)
                btnClose:SetPos(frame:GetWide() - 34, 8)
                btnClose:SetText("✕")
                btnClose:SetTextColor(Color(220, 220, 230))
                btnClose:SetFont("GRMDoc_Bold")
                btnClose.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 80, 80) or Color(0, 0, 0, 80)) end
                btnClose.DoClick = function() frame:Close() end

            else
                safeClearFrame(frame)
                frame:SetSize(840, 520)
                frame:Center()

                frame.Paint = function(_, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, coverCol)
                    draw.RoundedBox(8, 6, 6, w - 12, h - 12, Color(245, 240, 230))

                    surface.SetDrawColor(180, 175, 160, 180)
                    surface.DrawLine(w / 2, 8, w / 2, h - 8)

                    local topTitle = isShown and ("Вам предъявили паспорт: " .. tostring(senderName)) or "Ваш паспорт гражданина"
                    draw.SimpleText(topTitle, "GRMDoc_Small", 14, 10, Color(100, 95, 85), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end

                local btnFold = vgui.Create("DButton", frame)
                btnFold:SetSize(140, 24)
                btnFold:SetPos(frame:GetWide() - 180, 10)
                btnFold:SetText("◄► Сложить обложку")
                btnFold:SetFont("GRMDoc_Small")
                btnFold:SetTextColor(Color(80, 75, 65))
                btnFold.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 205, 195) or Color(225, 220, 210)) end
                btnFold.DoClick = function() surface.PlaySound("garrysmod/ui_click.wav") setPhase(false) end

                local btnClose = vgui.Create("DButton", frame)
                btnClose:SetSize(28, 24)
                btnClose:SetPos(frame:GetWide() - 36, 10)
                btnClose:SetText("✕")
                btnClose:SetTextColor(Color(90, 85, 75))
                btnClose:SetFont("GRMDoc_Bold")
                btnClose.Paint = function(s, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 80, 80) or Color(220, 215, 205))
                    if s:IsHovered() then s:SetTextColor(color_white) else s:SetTextColor(Color(90, 85, 75)) end
                end
                btnClose.DoClick = function() frame:Close() end

                local halfW = 400

                -- Левая страница (Герб и орган выдачи)
                local leftPnl = vgui.Create("DPanel", frame)
                leftPnl:SetPos(16, 32)
                leftPnl:SetSize(halfW, 460)
                leftPnl:SetPaintBackground(false)

                leftPnl.Paint = function(_, w, h)
                    draw.SimpleText(tpl.stateTitle or "РЕСПУБЛИКА ГРАНД", "GRMDoc_Header", w / 2, 20, Color(40, 35, 30), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("★ ★ ★", "GRMDoc_CoverTitle", w / 2, 70, Color(60, 50, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                    draw.SimpleText("Паспорт выдан государственным органом:", "GRMDoc_Small", w / 2, 115, Color(100, 95, 85), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    drawWrapped(tostring(data.issuedBy or "Паспортный стол"), "GRMDoc_Bold", w / 2, 135, w - 40, 16, Color(30, 25, 20), TEXT_ALIGN_CENTER)

                    draw.SimpleText("Дата выдачи: " .. tostring(data.issueDate or os.date("%d.%m.%Y")), "GRMDoc_Normal", w / 2, 185, Color(50, 45, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("Код подразделения: " .. tostring(data.series or "GRM") .. "-770", "GRMDoc_Normal", w / 2, 205, Color(50, 45, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    surface.SetDrawColor(120, 40, 40, 180)
                    surface.DrawOutlinedRect(w / 2 - 70, 245, 140, 70)
                    draw.SimpleText("М.П.", "GRMDoc_Bold", w / 2, 265, Color(120, 40, 40, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("ГОСУДАРСТВЕННАЯ", "GRMDoc_Small", w / 2, 285, Color(120, 40, 40, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("ПЕЧАТЬ", "GRMDoc_Small", w / 2, 300, Color(120, 40, 40, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                    draw.SimpleText("Личная подпись владельца:", "GRMDoc_Small", w / 2, 350, Color(100, 95, 85), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    surface.SetDrawColor(60, 55, 50, 180)
                    surface.DrawLine(w / 2 - 90, 390, w / 2 + 90, 390)
                    draw.SimpleText(tostring(data.fullName or ""), "GRMDoc_Small", w / 2, 375, Color(30, 45, 110), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                end

                -- Правая страница (Персональные данные и фото)
                local rightPnl = vgui.Create("DPanel", frame)
                rightPnl:SetPos(halfW + 24, 32)
                rightPnl:SetSize(halfW - 8, 460)
                rightPnl:SetPaintBackground(false)

                rightPnl.Paint = function(_, w, h)
                    draw.SimpleText(tostring(tpl.stateTitle or "РЕСПУБЛИКА ГРАНД") .. " / PASSPORT", "GRMDoc_Header", w / 2, 10, Color(40, 35, 30), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    draw.SimpleText("Серия и номер: " .. tostring(data.series or "GRM") .. " № " .. tostring(data.number or "000000"), "GRMDoc_Bold", w - 10, 34, Color(160, 30, 30), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

                    local y = 65
                    local function drawField(title, val)
                        draw.SimpleText(title, "GRMDoc_Small", 145, y, Color(110, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        drawWrapped(val or "—", "GRMDoc_Bold", 145, y + 15, w - 155, 16, Color(25, 20, 15), TEXT_ALIGN_LEFT)
                        y = y + 42
                    end

                    drawField("ФАМИЛИЯ, ИМЯ, ОТЧЕСТВО:", data.fullName)
                    drawField("ПОЛ / SEX:", data.gender or "Мужской")
                    drawField("ДАТА РОЖДЕНИЯ:", data.birthDate or "12.04.1988")
                    drawField("МЕСТО РОЖДЕНИЯ:", data.birthPlace or "г. Приморск, Республика Гранд")
                    drawField("ГРАЖДАНСТВО:", data.nationality or "Гражданин Республики")

                    -- MRZ машиночитаемая зона
                    surface.SetDrawColor(220, 215, 205)
                    surface.DrawRect(10, 380, w - 20, 60)
                    local ctry = string.upper(tostring(tpl.countryCode or "GRM")):gsub("[^A-Z]", "")
                    if #ctry < 3 then ctry = "GRM" end
                    ctry = ctry:sub(1, 3)
                    local mrz1 = string.format("P<%s%s<<%s<<<<<<<<<<<<<<<<<<<", ctry, (data.series or "GRM"), (data.fullName or "CITIZEN"):gsub("%s+", "<"):upper())
                    local mrz2 = string.format("%s4%s8804128M2801017<<<<<<<<<<<<<<02", data.number or "000000", ctry)
                    draw.SimpleText(mrz1:sub(1, 38), "GRMDoc_MRZ", 18, 390, Color(30, 30, 35), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText(mrz2:sub(1, 38), "GRMDoc_MRZ", 18, 412, Color(30, 30, 35), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end

                local sid64 = data.steamID64 or (LocalPlayer():SteamID64())
                if data.photoPath and file.Exists(data.photoPath, "DATA") then
                    local img = vgui.Create("DImage", rightPnl)
                    img:SetPos(15, 65)
                    img:SetSize(115, 145)
                    img:SetImage("../data/"..data.photoPath)
                else
                    local avatar = vgui.Create("AvatarImage", rightPnl)
                    avatar:SetPos(15, 65)
                    avatar:SetSize(115, 145)
                    avatar:SetSteamID(sid64, 184)
                end
            end
        end

        setPhase(false)
    end

    -- ── ДВУХФАЗНЫЙ РЕНДЕР СЛУЖЕБНОГО УДОСТОВЕРЕНИЯ (КСИВА) ─────
    local function openBadgeUI(data, tpl, isShown, senderName)
        tpl = tpl or {}
        local coverCol = tpl.coverColor and Color(tpl.coverColor.r or 18, tpl.coverColor.g or 32, tpl.coverColor.b or 60) or Color(18, 32, 60)
        local foil = DOC.FoilStyles[tpl.foilStyle or "gold"] or DOC.FoilStyles.gold

        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:MakePopup()
        frame:ShowCloseButton(false)

        local function setPhase(expanded)
            if not expanded then
                safeClearFrame(frame)
                frame:SetSize(420, 290)
                frame:Center()

                frame.Paint = function(_, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, coverCol)
                    draw.RoundedBox(8, 8, 8, w - 16, h - 16, Color(coverCol.r + 8, coverCol.g + 8, coverCol.b + 8))

                    local title = tpl.coverTitle or data.faction or "СЛУЖЕБНОЕ УДОСТОВЕРЕНИЕ"
                    draw.SimpleText(title, "GRMDoc_Foil", w / 2, 70, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("★", "GRMDoc_CoverTitle", w / 2, 120, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("УДОСТОВЕРЕНИЕ", "GRMDoc_CoverTitle", w / 2, 150, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    local topTitle = isShown and ("Вам предъявили удостоверение: " .. tostring(senderName)) or "Ваше служебное удостоверение"
                    draw.SimpleText(topTitle, "GRMDoc_Small", w / 2, 16, Color(200, 200, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                end

                local btnExpand = vgui.Create("DButton", frame)
                btnExpand:SetSize(360, 36)
                btnExpand:SetPos(30, 230)
                btnExpand:SetText("◄► Кликните, чтобы раскрыть удостоверение")
                btnExpand:SetFont("GRMDoc_Bold")
                btnExpand:SetTextColor(foil.col)
                btnExpand.Paint = function(s, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(0, 0, 0, 180) or Color(0, 0, 0, 120))
                    surface.SetDrawColor(foil.col.r, foil.col.g, foil.col.b, 160)
                    surface.DrawOutlinedRect(0, 0, w, h)
                end
                btnExpand.DoClick = function() surface.PlaySound("garrysmod/ui_click.wav") setPhase(true) end

                local btnClose = vgui.Create("DButton", frame)
                btnClose:SetSize(28, 24)
                btnClose:SetPos(frame:GetWide() - 34, 8)
                btnClose:SetText("✕")
                btnClose:SetTextColor(Color(220, 220, 230))
                btnClose:SetFont("GRMDoc_Bold")
                btnClose.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 80, 80) or Color(0, 0, 0, 80)) end
                btnClose.DoClick = function() frame:Close() end

            else
                safeClearFrame(frame)
                frame:SetSize(780, 320)
                frame:Center()

                frame.Paint = function(_, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, coverCol)
                    draw.RoundedBox(8, 6, 6, w - 12, h - 12, Color(248, 246, 242))

                    surface.SetDrawColor(180, 175, 160, 180)
                    surface.DrawLine(w / 2, 8, w / 2, h - 8)

                    local topTitle = isShown and ("Вам предъявили удостоверение: " .. tostring(senderName)) or "Служебное удостоверение"
                    draw.SimpleText(topTitle, "GRMDoc_Small", 14, 8, Color(110, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end

                local btnFold = vgui.Create("DButton", frame)
                btnFold:SetSize(130, 22)
                btnFold:SetPos(frame:GetWide() - 170, 8)
                btnFold:SetText("◄► Сложить корочку")
                btnFold:SetFont("GRMDoc_Small")
                btnFold:SetTextColor(Color(80, 75, 65))
                btnFold.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 205, 195) or Color(225, 220, 210)) end
                btnFold.DoClick = function() surface.PlaySound("garrysmod/ui_click.wav") setPhase(false) end

                local btnClose = vgui.Create("DButton", frame)
                btnClose:SetSize(28, 22)
                btnClose:SetPos(frame:GetWide() - 34, 8)
                btnClose:SetText("✕")
                btnClose:SetTextColor(Color(90, 85, 75))
                btnClose:SetFont("GRMDoc_Bold")
                btnClose.Paint = function(s, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 80, 80) or Color(220, 215, 205))
                    if s:IsHovered() then s:SetTextColor(color_white) else s:SetTextColor(Color(90, 85, 75)) end
                end
                btnClose.DoClick = function() frame:Close() end

                local halfW = 370

                -- Левая створка (Спецдопуски и жетон)
                local leftPnl = vgui.Create("DPanel", frame)
                leftPnl:SetPos(14, 30)
                leftPnl:SetSize(halfW, 275)
                leftPnl:SetPaintBackground(false)

                leftPnl.Paint = function(_, w, h)
                    draw.SimpleText(tostring(data.faction or "ВЕДОМСТВО"):upper(), "GRMDoc_Bold", w / 2, 6, Color(25, 45, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("СЛУЖЕБНЫЕ ДОПУСКИ И ПОЛНОМОЧИЯ:", "GRMDoc_Small", 10, 30, Color(110, 110, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    local y = 50
                    local perms = data.permissions or {}
                    for _, pDef in ipairs(DOC.PermissionsList or {}) do
                        local has = perms[pDef.id] == true
                        local boxCol = has and Color(220, 245, 225) or Color(238, 238, 240)
                        local txtCol = has and Color(20, 100, 40) or Color(140, 140, 150)
                        local icon = has and "✔ " or "✖ "

                        draw.RoundedBox(4, 10, y, w - 20, 22, boxCol)
                        draw.SimpleText(icon .. pDef.title, "GRMDoc_Small", 16, y + 11, txtCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        y = y + 26
                    end

                    draw.SimpleText("ЖЕТОН: " .. tostring(data.number or "0000"), "GRMDoc_Bold", w / 2, 245, Color(140, 30, 30), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                end

                -- Правая створка (ФИО, фото, должность, отдел)
                local rightPnl = vgui.Create("DPanel", frame)
                rightPnl:SetPos(halfW + 26, 30)
                rightPnl:SetSize(halfW, 275)
                rightPnl:SetPaintBackground(false)

                rightPnl.Paint = function(_, w, h)
                    draw.SimpleText("СЛУЖЕБНОЕ УДОСТОВЕРЕНИЕ", "GRMDoc_Bold", w / 2, 6, Color(30, 30, 35), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("№ " .. tostring(data.number or "POL-0001"), "GRMDoc_Bold", w - 10, 6, Color(160, 30, 30), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

                    local y = 35
                    local function drawField(title, val, col)
                        draw.SimpleText(title, "GRMDoc_Small", 115, y, Color(110, 110, 120), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        drawWrapped(val or "—", "GRMDoc_Bold", 115, y + 14, w - 125, 16, col or Color(25, 25, 30), TEXT_ALIGN_LEFT)
                        y = y + 36
                    end

                    drawField("ФИО СОТРУДНИКА:", data.fullName or "Сотрудник")
                    drawField("СПЕЦИАЛЬНОЕ ЗВАНИЕ / ЧИН:", data.role or "Служащий", Color(25, 65, 140))
                    drawField("ПОДРАЗДЕЛЕНИЕ / ОТДЕЛ:", data.department or "Главное Управление")
                    drawField("ВЫДАНО:", (data.issueDate or os.date("%d.%m.%Y")) .. " (Бессрочно)")
                    drawField("СТАТУС:", data.status or "Действителен", (data.status == "Действителен" and Color(20, 140, 50) or Color(180, 40, 40)))
                end

                local sid64 = data.steamID64 or (LocalPlayer():SteamID64())
                if data.photoPath and file.Exists(data.photoPath, "DATA") then
                    local img = vgui.Create("DImage", rightPnl)
                    img:SetPos(10, 35)
                    img:SetSize(95, 120)
                    img:SetImage("../data/"..data.photoPath)
                else
                    local avatar = vgui.Create("AvatarImage", rightPnl)
                    avatar:SetPos(10, 35)
                    avatar:SetSize(95, 120)
                    avatar:SetSteamID(sid64, 184)
                end
            end
        end

        setPhase(false)
    end

    -- ── ДВУХФАЗНЫЙ РЕНДЕР ВОЕННОГО БИЛЕТА ─────────────────────
    local function openMilitaryUI(data, tpl, isShown, senderName)
        tpl = tpl or {}
        local coverCol = tpl.coverColor and Color(tpl.coverColor.r or 38, tpl.coverColor.g or 58, tpl.coverColor.b or 36) or Color(38, 58, 36)
        local foil = DOC.FoilStyles[tpl.foilStyle or "gold"] or DOC.FoilStyles.gold

        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:MakePopup()
        frame:ShowCloseButton(false)

        local function setPhase(expanded)
            if not expanded then
                safeClearFrame(frame)
                frame:SetSize(380, 520)
                frame:Center()

                frame.Paint = function(_, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, coverCol)
                    draw.RoundedBox(6, 12, 12, w - 24, h - 24, Color(coverCol.r + 10, coverCol.g + 10, coverCol.b + 10))

                    draw.SimpleText(tpl.stateTitle or "ВООРУЖЁННЫЕ СИЛЫ", "GRMDoc_CoverTitle", w / 2, 60, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("★ МИНИСТЕРСТВО ОБОРОНЫ ★", "GRMDoc_Header", w / 2, 140, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("ВОЕННЫЙ КОМИССАРИАТ", "GRMDoc_Small", w / 2, 175, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    draw.SimpleText(tpl.docTitle or "ВОЕННЫЙ БИЛЕТ", "GRMDoc_Foil", w / 2, 320, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("MILITARY ID", "GRMDoc_Small", w / 2, 345, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    local topTitle = isShown and ("Вам показали военный билет: " .. tostring(senderName)) or "Ваш военный билет"
                    draw.SimpleText(topTitle, "GRMDoc_Small", w / 2, 20, Color(210, 225, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                end

                local btnExpand = vgui.Create("DButton", frame)
                btnExpand:SetSize(320, 42)
                btnExpand:SetPos(30, 440)
                btnExpand:SetText("◄► Кликните, чтобы развернуть военный билет")
                btnExpand:SetFont("GRMDoc_Bold")
                btnExpand:SetTextColor(foil.col)
                btnExpand.Paint = function(s, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(0, 0, 0, 180) or Color(0, 0, 0, 120))
                    surface.SetDrawColor(foil.col.r, foil.col.g, foil.col.b, 160)
                    surface.DrawOutlinedRect(0, 0, w, h)
                end
                btnExpand.DoClick = function() surface.PlaySound("garrysmod/ui_click.wav") setPhase(true) end

                local btnClose = vgui.Create("DButton", frame)
                btnClose:SetSize(28, 24)
                btnClose:SetPos(frame:GetWide() - 34, 8)
                btnClose:SetText("✕")
                btnClose:SetTextColor(Color(220, 220, 230))
                btnClose:SetFont("GRMDoc_Bold")
                btnClose.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 80, 80) or Color(0, 0, 0, 80)) end
                btnClose.DoClick = function() frame:Close() end

            else
                safeClearFrame(frame)
                frame:SetSize(840, 520)
                frame:Center()

                frame.Paint = function(_, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, coverCol)
                    draw.RoundedBox(8, 6, 6, w - 12, h - 12, Color(242, 244, 238))

                    surface.SetDrawColor(165, 175, 160, 180)
                    surface.DrawLine(w / 2, 8, w / 2, h - 8)

                    local topTitle = isShown and ("Вам предъявили военный билет: " .. tostring(senderName)) or "Военный билет военнослужащего"
                    draw.SimpleText(topTitle, "GRMDoc_Small", 14, 10, Color(90, 105, 90), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end

                local btnFold = vgui.Create("DButton", frame)
                btnFold:SetSize(140, 24)
                btnFold:SetPos(frame:GetWide() - 180, 10)
                btnFold:SetText("◄► Сложить обложку")
                btnFold:SetFont("GRMDoc_Small")
                btnFold:SetTextColor(Color(70, 85, 70))
                btnFold.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(205, 215, 200) or Color(220, 228, 215)) end
                btnFold.DoClick = function() surface.PlaySound("garrysmod/ui_click.wav") setPhase(false) end

                local btnClose = vgui.Create("DButton", frame)
                btnClose:SetSize(28, 24)
                btnClose:SetPos(frame:GetWide() - 36, 10)
                btnClose:SetText("✕")
                btnClose:SetTextColor(Color(80, 95, 80))
                btnClose:SetFont("GRMDoc_Bold")
                btnClose.Paint = function(s, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 80, 80) or Color(215, 225, 210))
                    if s:IsHovered() then s:SetTextColor(color_white) else s:SetTextColor(Color(80, 95, 80)) end
                end
                btnClose.DoClick = function() frame:Close() end

                local halfW = 400

                -- Левая страница
                local leftPnl = vgui.Create("DPanel", frame)
                leftPnl:SetPos(16, 32)
                leftPnl:SetSize(halfW, 460)
                leftPnl:SetPaintBackground(false)

                leftPnl.Paint = function(_, w, h)
                    draw.SimpleText("ВООРУЖЁННЫЕ СИЛЫ", "GRMDoc_Header", w / 2, 10, Color(30, 45, 30), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("ВОЕННЫЙ БИЛЕТ № " .. tostring(data.number or "ВБ-000000"), "GRMDoc_Bold", w / 2, 30, Color(160, 30, 30), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    draw.SimpleText("ФИО ВОЕННОСЛУЖАЩЕГО:", "GRMDoc_Small", 155, 65, Color(100, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    drawWrapped(tostring(data.fullName or "Военнослужащий"), "GRMDoc_Bold", 155, 82, w - 165, 16, Color(30, 40, 30), TEXT_ALIGN_LEFT)

                    draw.SimpleText("ВУС (Специальность):", "GRMDoc_Small", 155, 115, Color(100, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    drawWrapped(tostring(data.vus or "ВУС-100 (Стрелок)"), "GRMDoc_Normal", 155, 132, w - 165, 15, Color(30, 40, 30), TEXT_ALIGN_LEFT)

                    draw.SimpleText("Категория годности:", "GRMDoc_Small", 155, 165, Color(100, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText(tostring(data.fitness or "А — Годен к службе"), "GRMDoc_Bold", 155, 182, Color(25, 120, 50), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.SimpleText("Кем выдан военный билет:", "GRMDoc_Small", 20, 235, Color(100, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    drawWrapped(tostring(data.issuedBy or "Военный комиссариат"), "GRMDoc_Normal", 20, 252, w - 40, 15, Color(30, 40, 30), TEXT_ALIGN_LEFT)

                    surface.SetDrawColor(40, 80, 50, 180)
                    surface.DrawOutlinedRect(20, 290, 110, 60)
                    draw.SimpleText("ВОЕНКОМАТ", "GRMDoc_Small", 75, 310, Color(40, 80, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("ПЕЧАТЬ", "GRMDoc_Small", 75, 330, Color(40, 80, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                    draw.SimpleText("Подпись владельца:", "GRMDoc_Small", 155, 300, Color(100, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    surface.SetDrawColor(60, 60, 70, 180)
                    surface.DrawLine(155, 340, 320, 340)
                    draw.SimpleText(tostring(data.fullName or ""), "GRMDoc_Small", 165, 322, Color(25, 45, 110), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end

                local sid64 = data.steamID64 or (LocalPlayer():SteamID64())
                if data.photoPath and file.Exists(data.photoPath, "DATA") then
                    local img = vgui.Create("DImage", leftPnl)
                    img:SetPos(24, 70)
                    img:SetSize(112, 140)
                    img:SetImage("../data/"..data.photoPath)
                else
                    local avatar = vgui.Create("AvatarImage", leftPnl)
                    avatar:SetPos(24, 70)
                    avatar:SetSize(112, 140)
                    avatar:SetSteamID(sid64, 184)
                end

                -- Правая страница
                local rightPnl = vgui.Create("DPanel", frame)
                rightPnl:SetPos(halfW + 24, 32)
                rightPnl:SetSize(halfW - 8, 440)
                rightPnl:SetPaintBackground(false)

                rightPnl.Paint = function(_, w, h)
                    draw.SimpleText("ПРОХОЖДЕНИЕ ВОИНСКОЙ СЛУЖБЫ", "GRMDoc_Header", w / 2, 12, Color(40, 60, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    local y = 50
                    local function drawField(title, val)
                        draw.SimpleText(title, "GRMDoc_Small", 15, y, Color(100, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        drawWrapped(val or "—", "GRMDoc_Bold", 15, y + 16, w - 30, 16, Color(30, 40, 30), TEXT_ALIGN_LEFT)
                        surface.SetDrawColor(205, 205, 195)
                        surface.DrawLine(15, y + 36, w - 20, y + 36)
                        y = y + 46
                    end

                    drawField("ВОИНСКОЕ ЗВАНИЕ:", data.rank or "Рядовой")
                    drawField("ВОИНСКОЕ ФОРМИРОВАНИЕ / ЧАСТЬ:", data.formation or "Вооружённые силы")
                    drawField("ПОДРАЗДЕЛЕНИЕ / ОТДЕЛ:", data.department or "Штаб")
                    drawField("ЗАНИМАЕМАЯ ДОЛЖНОСТЬ:", data.position or "Стрелок")
                    drawField("ДАТА ВЫДАЧИ:", data.issueDate or os.date("%d.%m.%Y"))
                    drawField("СТАТУС ВОЕННОСЛУЖАЩЕГО:", data.status or "В запасе")
                end
            end
        end

        setPhase(false)
    end

    -- ── ДВУХФАЗНЫЙ РЕНДЕР ГРАЖДАНСКОГО ВОДИТЕЛЬСКОГО УДОСТОВЕРЕНИЯ ──
    local function openLicenseUI(data, tpl, isShown, senderName)
        tpl = tpl or {}
        local coverCol = tpl.coverColor and Color(tpl.coverColor.r or 35, tpl.coverColor.g or 60, tpl.coverColor.b or 95) or Color(35, 60, 95)
        local foil = DOC.FoilStyles[tpl.foilStyle or "gold"] or DOC.FoilStyles.gold

        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:MakePopup()
        frame:ShowCloseButton(false)

        local function setPhase(expanded)
            if not expanded then
                -- Фаза 1: Лицевая сторона пластиковой карты (500×310)
                safeClearFrame(frame)
                frame:SetSize(500, 310)
                frame:Center()

                frame.Paint = function(_, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, coverCol)
                    draw.RoundedBox(8, 4, 4, w - 8, h - 8, Color(242, 246, 252))

                    -- Шапка
                    draw.RoundedBox(4, 8, 8, w - 16, 32, coverCol)
                    draw.SimpleText(tpl.stateTitle or "ДОРОЖНАЯ ИНСПЕКЦИЯ", "GRMDoc_Bold", 20, 24, foil.col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText("DRIVER LICENSE", "GRMDoc_Small", w - 20, 24, Color(220, 230, 245), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

                    -- Фото
                    draw.RoundedBox(4, 16, 52, 90, 115, Color(210, 215, 225))

                    -- Реквизиты
                    draw.SimpleText("ВОДИТЕЛЬСКОЕ УДОСТОВЕРЕНИЕ", "GRMDoc_Small", 120, 50, Color(100, 110, 130), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText("№ " .. tostring(data.number or "ВУ-000000"), "GRMDoc_Bold", 120, 66, Color(180, 40, 40), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.SimpleText("1. ФИО: " .. tostring(data.fullName or "Водитель"), "GRMDoc_Bold", 120, 90, Color(25, 30, 40), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText("2. Дата рожд.: " .. tostring(data.birthDate or "12.04.1988"), "GRMDoc_Normal", 120, 112, Color(40, 45, 55), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText("3. Выдано: " .. tostring(data.issueDate or os.date("%d.%m.%Y")) .. "  •  Срок: " .. tostring(data.validUntil or "10 лет"), "GRMDoc_Normal", 120, 132, Color(40, 45, 55), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    drawWrapped("4. Орган: " .. tostring(data.issuedBy or "Дорожная Инспекция"), "GRMDoc_Small", 120, 152, w - 130, 14, Color(90, 100, 115), TEXT_ALIGN_LEFT)

                    -- Значки категорий внизу
                    draw.RoundedBox(4, 8, 185, w - 16, 55, Color(230, 236, 245))
                    draw.SimpleText("РАЗРЕШЁННЫЕ КАТЕГОРИИ:", "GRMDoc_Small", 16, 190, Color(100, 110, 130), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    local cats = data.categories or {}
                    local cx = 16
                    for _, cat in ipairs(DOC.DriveCategories or {}) do
                        local has = (cats[cat.id] == true)
                        local boxCol = has and Color(35, 110, 190) or Color(205, 212, 222)
                        local txtCol = has and color_white or Color(125, 135, 145)
                        draw.RoundedBox(4, cx, 208, 65, 24, boxCol)
                        draw.SimpleText(cat.id, "GRMDoc_Bold", cx + 32, 220, txtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        cx = cx + 70
                    end

                    local statCol = (data.status == "Действительно") and Color(30, 140, 60) or Color(180, 40, 40)
                    draw.SimpleText("СТАТУС: " .. tostring(data.status or "Действительно"), "GRMDoc_Bold", w - 16, 190, statCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                end

                local sid64 = data.steamID64 or (LocalPlayer():SteamID64())
                if data.photoPath and file.Exists(data.photoPath, "DATA") then
                    local img = vgui.Create("DImage", frame)
                    img:SetPos(20, 56)
                    img:SetSize(82, 107)
                    img:SetImage("../data/"..data.photoPath)
                else
                    local avatar = vgui.Create("AvatarImage", frame)
                    avatar:SetPos(20, 56)
                    avatar:SetSize(82, 107)
                    avatar:SetSteamID(sid64, 184)
                end

                local btnTurn = vgui.Create("DButton", frame)
                btnTurn:SetSize(320, 32)
                btnTurn:SetPos(frame:GetWide() / 2 - 160, 260)
                btnTurn:SetText("◄► Перевернуть карту (таблица категорий)")
                btnTurn:SetFont("GRMDoc_Bold")
                btnTurn:SetTextColor(Color(25, 45, 75))
                btnTurn.Paint = function(s, bw, bh)
                    draw.RoundedBox(4, 0, 0, bw, bh, s:IsHovered() and Color(210, 225, 245) or Color(225, 235, 250))
                    surface.SetDrawColor(180, 200, 230)
                    surface.DrawOutlinedRect(0, 0, bw, bh)
                end
                btnTurn.DoClick = function() surface.PlaySound("garrysmod/ui_click.wav") setPhase(true) end

                local btnClose = vgui.Create("DButton", frame)
                btnClose:SetSize(28, 24)
                btnClose:SetPos(frame:GetWide() - 34, 8)
                btnClose:SetText("✕")
                btnClose:SetTextColor(Color(220, 220, 230))
                btnClose:SetFont("GRMDoc_Bold")
                btnClose.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 80, 80) or Color(0, 0, 0, 80)) end
                btnClose.DoClick = function() frame:Close() end

            else
                -- Фаза 2: Оборотная сторона пластиковой карты (500×400)
                safeClearFrame(frame)
                frame:SetSize(500, 400)
                frame:Center()

                frame.Paint = function(_, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, coverCol)
                    draw.RoundedBox(8, 4, 4, w - 8, h - 8, Color(242, 246, 252))

                    draw.SimpleText("ТАБЛИЦА КАТЕГОРИЙ ТРАНСПОРТНЫХ СРЕДСТВ", "GRMDoc_Bold", w / 2, 14, Color(30, 45, 65), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    local y = 42
                    local cats = data.categories or {}
                    for _, cat in ipairs(DOC.DriveCategories or {}) do
                        local has = cats[cat.id] == true
                        draw.RoundedBox(4, 12, y, w - 24, 26, has and Color(225, 242, 230) or Color(236, 238, 242))
                        draw.SimpleText(cat.icon .. "  " .. cat.name .. " (" .. cat.desc .. ")", "GRMDoc_Small", 20, y + 13, Color(30, 35, 45), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        local mark = has and "✔ РАЗРЕШЕНО" or "—"
                        local markCol = has and Color(30, 140, 60) or Color(150, 155, 165)
                        draw.SimpleText(mark, "GRMDoc_Bold", w - 24, y + 13, markCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                        y = y + 30
                    end

                    -- Особые отметки
                    drawWrapped("12. Особые отметки: " .. tostring(data.restrictions or "Стаж вождения подтверждён"), "GRMDoc_Small", 16, y + 8, w - 32, 14, Color(90, 95, 110), TEXT_ALIGN_LEFT)
                    drawWrapped("Кем выдано: " .. tostring(data.issuedBy or "Дорожная Инспекция"), "GRMDoc_Small", 16, y + 26, w - 32, 14, Color(90, 95, 110), TEXT_ALIGN_LEFT)
                end

                local btnTurn = vgui.Create("DButton", frame)
                btnTurn:SetSize(200, 28)
                btnTurn:SetPos(16, 356)
                btnTurn:SetText("◄► Лицевая сторона")
                btnTurn:SetFont("GRMDoc_Bold")
                btnTurn:SetTextColor(Color(25, 45, 75))
                btnTurn.Paint = function(s, bw, bh)
                    draw.RoundedBox(4, 0, 0, bw, bh, s:IsHovered() and Color(210, 225, 245) or Color(225, 235, 250))
                    surface.SetDrawColor(180, 200, 230)
                    surface.DrawOutlinedRect(0, 0, bw, bh)
                end
                btnTurn.DoClick = function() surface.PlaySound("garrysmod/ui_click.wav") setPhase(false) end

                local btnClose = vgui.Create("DButton", frame)
                btnClose:SetSize(120, 28)
                btnClose:SetPos(frame:GetWide() - 136, 356)
                btnClose:SetText("✕ Закрыть")
                btnClose:SetTextColor(color_white)
                btnClose:SetFont("GRMDoc_Bold")
                btnClose.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 80, 80) or Color(150, 50, 50)) end
                btnClose.DoClick = function() frame:Close() end
            end
        end

        setPhase(false)
    end

    -- ── ДВУХФАЗНЫЙ РЕНДЕР ВОЕННОГО ВОДИТЕЛЬСКОГО УДОСТОВЕРЕНИЯ (ВАИ) ──
    local function openMilLicenseUI(data, tpl, isShown, senderName)
        data = data or {}
        tpl = tpl or {}
        local coverCol = tpl.coverColor and Color(tpl.coverColor.r or 38, tpl.coverColor.g or 58, tpl.coverColor.b or 36) or Color(38, 58, 36)
        local foil = DOC.FoilStyles[tpl.foilStyle or "gold"] or DOC.FoilStyles.gold

        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:MakePopup()
        frame:ShowCloseButton(false)

        local function setPhase(expanded)
            if not expanded then
                -- Фаза 1: Лицевая сторона военного удостоверения водителя (520×320)
                safeClearFrame(frame)
                frame:SetSize(520, 320)
                frame:Center()

                frame.Paint = function(_, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, coverCol)
                    draw.RoundedBox(8, 4, 4, w - 8, h - 8, Color(240, 244, 238))

                    -- Шапка
                    draw.RoundedBox(4, 8, 8, w - 16, 32, coverCol)
                    draw.SimpleText(tpl.stateTitle or "ВОЕННАЯ АВТОМОБИЛЬНАЯ ИНСПЕКЦИЯ", "GRMDoc_Bold", 20, 24, foil.col, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                    draw.SimpleText("MILITARY DRIVER", "GRMDoc_Small", w - 20, 24, Color(210, 225, 205), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

                    -- Фото
                    draw.RoundedBox(4, 16, 52, 90, 115, Color(200, 210, 195))

                    -- Реквизиты
                    draw.SimpleText("УДОСТОВЕРЕНИЕ ВОЕННОГО ВОДИТЕЛЯ", "GRMDoc_Small", 120, 50, Color(80, 100, 75), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText("№ " .. tostring(data.number or "ВАИ-000000"), "GRMDoc_Bold", 120, 66, Color(180, 35, 35), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.SimpleText("1. ФИО: " .. tostring(data.fullName or "Военнослужащий"), "GRMDoc_Bold", 120, 90, Color(25, 35, 25), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText("2. Звание: " .. tostring(data.rank or "Рядовой"), "GRMDoc_Bold", 120, 110, Color(40, 75, 45), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText("3. В/Ч (Часть): " .. tostring(data.formation or "Автобат"), "GRMDoc_Normal", 120, 130, Color(45, 55, 45), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText("4. ВУС: " .. tostring(data.vus or "ВУС-837 (Водитель спецтранспорта)"), "GRMDoc_Normal", 120, 150, Color(45, 55, 45), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText("5. Выдано: " .. tostring(data.issueDate or os.date("%d.%m.%Y")) .. "  •  Срок: " .. tostring(data.validUntil or "На срок службы"), "GRMDoc_Small", 120, 170, Color(80, 95, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    -- Значки военных категорий внизу
                    draw.RoundedBox(4, 8, 195, w - 16, 55, Color(226, 235, 222))
                    draw.SimpleText("РАЗРЕШЁННЫЕ ВОЕННЫЕ КАТЕГОРИИ:", "GRMDoc_Small", 16, 200, Color(80, 100, 75), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    local cats = data.categories or {}
                    local cx = 16
                    for _, cat in ipairs(DOC.MilDriveCategories or {}) do
                        local has = (cats[cat.id] == true)
                        local boxCol = has and Color(45, 125, 60) or Color(195, 205, 195)
                        local txtCol = has and color_white or Color(110, 125, 110)
                        draw.RoundedBox(4, cx, 218, 65, 24, boxCol)
                        draw.SimpleText(cat.id, "GRMDoc_Bold", cx + 32, 230, txtCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                        cx = cx + 70
                    end

                    local statCol = (data.status == "Действительно" or data.status == "Действительно (на службе)") and Color(30, 140, 60) or Color(180, 40, 40)
                    draw.SimpleText("СТАТУС: " .. tostring(data.status or "Действительно (на службе)"), "GRMDoc_Bold", w - 16, 200, statCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
                end

                local sid64 = data.steamID64 or (LocalPlayer():SteamID64())
                if data.photoPath and file.Exists(data.photoPath, "DATA") then
                    local img = vgui.Create("DImage", frame)
                    img:SetPos(20, 56)
                    img:SetSize(82, 107)
                    img:SetImage("../data/"..data.photoPath)
                else
                    local avatar = vgui.Create("AvatarImage", frame)
                    avatar:SetPos(20, 56)
                    avatar:SetSize(82, 107)
                    avatar:SetSteamID(sid64, 184)
                end

                -- Печать ВАИ
                local pnlStamp = vgui.Create("DPanel", frame)
                pnlStamp:SetPos(70, 125)
                pnlStamp:SetSize(60, 45)
                pnlStamp:SetPaintBackground(false)
                pnlStamp.Paint = function(s, pw, ph)
                    surface.SetDrawColor(180, 40, 40, 180)
                    surface.DrawOutlinedRect(0, 0, pw, ph)
                    draw.SimpleText("ВАИ МО", "GRMDoc_Small", pw / 2, 8, Color(180, 40, 40, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("★ ПЕЧАТЬ ★", "GRMDoc_Small", pw / 2, 28, Color(180, 40, 40, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end

                local btnTurn = vgui.Create("DButton", frame)
                btnTurn:SetSize(320, 32)
                btnTurn:SetPos(frame:GetWide() / 2 - 160, 270)
                btnTurn:SetText("◄► Перевернуть карту (Военные допуски и колонны)")
                btnTurn:SetFont("GRMDoc_Bold")
                btnTurn:SetTextColor(Color(25, 55, 30))
                btnTurn.Paint = function(s, bw, bh)
                    draw.RoundedBox(4, 0, 0, bw, bh, s:IsHovered() and Color(205, 225, 195) or Color(220, 235, 215))
                    surface.SetDrawColor(160, 190, 150)
                    surface.DrawOutlinedRect(0, 0, bw, bh)
                end
                btnTurn.DoClick = function() surface.PlaySound("garrysmod/ui_click.wav") setPhase(true) end

                local btnClose = vgui.Create("DButton", frame)
                btnClose:SetSize(28, 24)
                btnClose:SetPos(frame:GetWide() - 34, 8)
                btnClose:SetText("✕")
                btnClose:SetTextColor(Color(220, 230, 215))
                btnClose:SetFont("GRMDoc_Bold")
                btnClose.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 80, 80) or Color(0, 0, 0, 80)) end
                btnClose.DoClick = function() frame:Close() end

            else
                -- Фаза 2: Оборотная сторона военного удостоверения (520×430)
                safeClearFrame(frame)
                frame:SetSize(520, 430)
                frame:Center()

                frame.Paint = function(_, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, coverCol)
                    draw.RoundedBox(8, 4, 4, w - 8, h - 8, Color(240, 244, 238))

                    draw.SimpleText("ДОПУСКИ К УПРАВЛЕНИЮ ВОЕННОЙ ТЕХНИКОЙ И АВТОКОЛОННАМИ", "GRMDoc_Bold", w / 2, 14, Color(30, 55, 30), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    -- Таблица категорий (6 штук)
                    local y = 38
                    local cats = data.categories or {}
                    for _, cat in ipairs(DOC.MilDriveCategories or {}) do
                        local has = cats[cat.id] == true
                        draw.RoundedBox(4, 12, y, w - 24, 22, has and Color(215, 238, 215) or Color(230, 235, 228))
                        draw.SimpleText(cat.icon .. "  " .. cat.name .. " (" .. cat.desc .. ")", "GRMDoc_Small", 20, y + 11, Color(30, 40, 30), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        local mark = has and "✔ РАЗРЕШЕНО" or "—"
                        local markCol = has and Color(25, 130, 50) or Color(150, 160, 150)
                        draw.SimpleText(mark, "GRMDoc_Bold", w - 24, y + 11, markCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                        y = y + 25
                    end

                    -- Спецдопуски (Endorsements)
                    draw.SimpleText("СПЕЦИАЛЬНЫЕ ДОПУСКИ ВОЕННОГО ВОДИТЕЛЯ:", "GRMDoc_Bold", 16, y + 8, Color(35, 70, 40), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    y = y + 28

                    local ends = data.endorsements or {}
                    local colW = (w - 32) / 2
                    for i, endDef in ipairs(DOC.MilEndorsements or {}) do
                        local has = ends[endDef.id] == true
                        local ex = (i % 2 == 1) and 16 or (16 + colW + 4)
                        local ey = y + math.floor((i - 1) / 2) * 26

                        draw.RoundedBox(4, ex, ey, colW - 4, 22, has and Color(210, 235, 215) or Color(232, 236, 230))
                        draw.SimpleText(endDef.icon .. " " .. endDef.title, "GRMDoc_Small", ex + 6, ey + 11, Color(30, 40, 30), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                        local mark = has and "✔ ДОПУЩЕН" or "—"
                        local markCol = has and Color(25, 130, 50) or Color(145, 155, 145)
                        draw.SimpleText(mark, "GRMDoc_Small", ex + colW - 10, ey + 11, markCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                    end

                    y = y + math.ceil(#(DOC.MilEndorsements or {}) / 2) * 26 + 10

                    -- Особые отметки
                    drawWrapped("12. Особые отметки: " .. tostring(data.restrictions or data.specialNotes or "Норматив вождения сдан. Стажировка пройдена."), "GRMDoc_Small", 16, y, w - 32, 14, Color(80, 95, 80), TEXT_ALIGN_LEFT)
                    drawWrapped("Кем выдано: " .. tostring(data.issuedBy or "101-я Военная автомобильная инспекция (ВАИ)"), "GRMDoc_Small", 16, y + 18, w - 32, 14, Color(80, 95, 80), TEXT_ALIGN_LEFT)
                end

                local btnTurn = vgui.Create("DButton", frame)
                btnTurn:SetSize(200, 28)
                btnTurn:SetPos(16, 390)
                btnTurn:SetText("◄► Лицевая сторона")
                btnTurn:SetFont("GRMDoc_Bold")
                btnTurn:SetTextColor(Color(25, 55, 30))
                btnTurn.Paint = function(s, bw, bh)
                    draw.RoundedBox(4, 0, 0, bw, bh, s:IsHovered() and Color(205, 225, 195) or Color(220, 235, 215))
                    surface.SetDrawColor(160, 190, 150)
                    surface.DrawOutlinedRect(0, 0, bw, bh)
                end
                btnTurn.DoClick = function() surface.PlaySound("garrysmod/ui_click.wav") setPhase(false) end

                local btnClose = vgui.Create("DButton", frame)
                btnClose:SetSize(120, 28)
                btnClose:SetPos(frame:GetWide() - 136, 390)
                btnClose:SetText("✕ Закрыть")
                btnClose:SetTextColor(color_white)
                btnClose:SetFont("GRMDoc_Bold")
                btnClose.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 80, 80) or Color(150, 50, 50)) end
                btnClose.DoClick = function() frame:Close() end
            end
        end

        setPhase(false)
    end

    -- ── ДВУХФАЗНЫЙ РЕНДЕР МЕДИЦИНСКОЙ КАРТЫ ───────────────────
    local function openMedCardUI(card, extra, isShown, senderName)
        card = card or {}
        extra = extra or {}
        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:MakePopup()
        frame:ShowCloseButton(false)

        local function setPhase(expanded)
            if not expanded then
                safeClearFrame(frame)
                frame:SetSize(360, 480)
                frame:Center()

                frame.Paint = function(_, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, Color(30, 65, 55))
                    draw.RoundedBox(6, 10, 10, w - 20, h - 20, Color(36, 75, 64))

                    draw.SimpleText("МИНИСТЕРСТВО ЗДРАВООХРАНЕНИЯ", "GRMDoc_Header", w / 2, 70, Color(240, 245, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("✚ МЕДИЦИНСКАЯ СЛУЖБА ✚", "GRMDoc_Header", w / 2, 160, Color(220, 70, 70), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("МЕДИЦИНСКАЯ КАРТА", "GRMDoc_Foil", w / 2, 260, Color(240, 245, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("MEDICAL RECORD", "GRMDoc_Small", w / 2, 285, Color(180, 205, 195), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    local topTitle = isShown and ("Вам передали медкарту: " .. tostring(senderName)) or "Ваша медицинская карта"
                    draw.SimpleText(topTitle, "GRMDoc_Small", w / 2, 20, Color(220, 225, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                end

                local btnExpand = vgui.Create("DButton", frame)
                btnExpand:SetSize(300, 40)
                btnExpand:SetPos(30, 400)
                btnExpand:SetText("◄► Кликните, чтобы открыть медкарту")
                btnExpand:SetFont("GRMDoc_Bold")
                btnExpand:SetTextColor(color_white)
                btnExpand.Paint = function(s, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(0, 0, 0, 180) or Color(0, 0, 0, 120))
                    surface.SetDrawColor(200, 230, 210, 160)
                    surface.DrawOutlinedRect(0, 0, w, h)
                end
                btnExpand.DoClick = function() surface.PlaySound("garrysmod/ui_click.wav") setPhase(true) end

                local btnClose = vgui.Create("DButton", frame)
                btnClose:SetSize(28, 24)
                btnClose:SetPos(frame:GetWide() - 34, 8)
                btnClose:SetText("✕")
                btnClose:SetTextColor(Color(220, 220, 230))
                btnClose:SetFont("GRMDoc_Bold")
                btnClose.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 80, 80) or Color(0, 0, 0, 80)) end
                btnClose.DoClick = function() frame:Close() end

            else
                safeClearFrame(frame)
                frame:SetSize(840, 520)
                frame:Center()

                frame.Paint = function(_, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, Color(30, 65, 55))
                    draw.RoundedBox(8, 6, 6, w - 12, h - 12, Color(248, 248, 244))

                    surface.SetDrawColor(180, 190, 180, 180)
                    surface.DrawLine(w / 2, 8, w / 2, h - 8)

                    local topTitle = isShown and ("Вам передали медицинскую карту: " .. tostring(senderName)) or "Медицинская карта пациента"
                    draw.SimpleText(topTitle, "GRMDoc_Small", 14, 10, Color(100, 115, 105), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end

                local btnFold = vgui.Create("DButton", frame)
                btnFold:SetSize(140, 24)
                btnFold:SetPos(frame:GetWide() - 180, 10)
                btnFold:SetText("◄► Сложить обложку")
                btnFold:SetFont("GRMDoc_Small")
                btnFold:SetTextColor(Color(80, 75, 65))
                btnFold.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 205, 195) or Color(225, 220, 210)) end
                btnFold.DoClick = function() surface.PlaySound("garrysmod/ui_click.wav") setPhase(false) end

                local btnClose = vgui.Create("DButton", frame)
                btnClose:SetSize(28, 24)
                btnClose:SetPos(frame:GetWide() - 36, 10)
                btnClose:SetText("✕")
                btnClose:SetTextColor(Color(90, 85, 75))
                btnClose:SetFont("GRMDoc_Bold")
                btnClose.Paint = function(s, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 80, 80) or Color(220, 215, 205))
                    if s:IsHovered() then s:SetTextColor(color_white) else s:SetTextColor(Color(90, 85, 75)) end
                end
                btnClose.DoClick = function() frame:Close() end

                local halfW = 400

                -- Левая страница
                local leftPnl = vgui.Create("DPanel", frame)
                leftPnl:SetPos(16, 32)
                leftPnl:SetSize(halfW, 460)
                leftPnl:SetPaintBackground(false)

                leftPnl.Paint = function(_, w, h)
                    draw.SimpleText("МИНИСТЕРСТВО ЗДРАВООХРАНЕНИЯ", "GRMDoc_Header", w / 2, 10, Color(30, 70, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("МЕДИЦИНСКАЯ КАРТА ПАЦИЕНТА", "GRMDoc_Small", w / 2, 30, Color(100, 110, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    draw.SimpleText("ПАЦИЕНТ (ФИО):", "GRMDoc_Small", 15, 60, Color(100, 110, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    drawWrapped(tostring(card.name or extra.patientName or "Пациент"), "GRMDoc_Bold", 15, 78, w - 30, 16, Color(25, 35, 30), TEXT_ALIGN_LEFT)

                    draw.RoundedBox(6, 15, 110, w - 30, 48, Color(230, 240, 235))
                    draw.SimpleText("КАТЕГОРИЯ ГОДНОСТИ К СЛУЖБЕ / РАБОТЕ:", "GRMDoc_Small", 25, 116, Color(60, 90, 75), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    local fit = card.fitnessCategory or "А — Годен к военной службе и работе"
                    draw.SimpleText(fit, "GRMDoc_Bold", 25, 134, Color(20, 100, 50), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.SimpleText("ГРУППА КРОВИ И РЕЗУС-ФАКТОР:", "GRMDoc_Small", 15, 175, Color(100, 110, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText((card.blood and card.blood ~= "") and card.blood or "Не установлена", "GRMDoc_Bold", 15, 193, Color(180, 40, 40), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.SimpleText("АЛЛЕРГИЧЕСКИЕ РЕАКЦИИ:", "GRMDoc_Small", 15, 230, Color(100, 110, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    drawWrapped((card.allergies and card.allergies ~= "") and card.allergies or "Не выявлено", "GRMDoc_Normal", 15, 248, w - 30, 15, Color(30, 35, 30), TEXT_ALIGN_LEFT)

                    draw.SimpleText("ХРОНИЧЕСКИЕ ЗАБОЛЕВАНИЯ:", "GRMDoc_Small", 15, 290, Color(100, 110, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    drawWrapped((card.chronic and card.chronic ~= "") and card.chronic or "Отсутствуют", "GRMDoc_Normal", 15, 308, w - 30, 15, Color(30, 35, 30), TEXT_ALIGN_LEFT)

                    surface.SetDrawColor(30, 110, 80, 180)
                    surface.DrawOutlinedRect(15, 375, 130, 60)
                    draw.SimpleText("МИНЗДРАВ", "GRMDoc_Small", 80, 395, Color(30, 110, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("ГОСПИТАЛЬ", "GRMDoc_Small", 80, 415, Color(30, 110, 80), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end

                -- Правая страница
                local rightPnl = vgui.Create("DPanel", frame)
                rightPnl:SetPos(halfW + 24, 32)
                rightPnl:SetSize(halfW - 8, 460)
                rightPnl:SetPaintBackground(false)

                rightPnl.Paint = function(_, w, h)
                    draw.SimpleText("ЖУРНАЛ МЕДИЦИНСКИХ ЗАПИСЕЙ И ПРИЁМОВ", "GRMDoc_Header", w / 2, 10, Color(30, 70, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                end

                local scroll = vgui.Create("DScrollPanel", rightPnl)
                scroll:SetPos(10, 36)
                scroll:SetSize(halfW - 28, 410)

                local entries = card.entries or {}
                if #entries == 0 then
                    local lbl = vgui.Create("DLabel", scroll)
                    lbl:Dock(TOP)
                    lbl:DockMargin(0, 20, 0, 0)
                    lbl:SetFont("GRMDoc_Normal")
                    lbl:SetTextColor(Color(130, 135, 130))
                    lbl:SetText("Медицинских записей пока нет.")
                    lbl:SizeToContents()
                else
                    for i = #entries, 1, -1 do
                        local e = entries[i]
                        local row = vgui.Create("DPanel", scroll)
                        row:Dock(TOP)
                        row:DockMargin(0, 0, 0, 6)
                        row:SetTall(56)
                        row.Paint = function(_, w, h)
                            draw.RoundedBox(4, 0, 0, w, h, Color(236, 240, 236))
                            local dateStr = os.date("%d.%m.%Y %H:%M", e.ts or os.time())
                            draw.SimpleText(tostring(e.kind or "Запись") .. "  •  " .. dateStr, "GRMDoc_Small", 8, 6, Color(60, 100, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                            drawWrapped(tostring(e.text or "—"), "GRMDoc_Normal", 8, 22, w - 16, 15, Color(30, 35, 30), TEXT_ALIGN_LEFT)
                            draw.SimpleText("Врач: " .. tostring(e.doctor or "—"), "GRMDoc_Small", 8, 38, Color(110, 120, 115), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        end
                    end
                end
            end
        end

        setPhase(false)
    end

    -- Приём документа на клиенте
    net.Receive(NET_RECEIVE_VIEW, function()
        local docType = net.ReadString()
        local data = net.ReadTable() or {}
        local tpl = net.ReadTable() or {}
        local isShown = net.ReadBool()
        local senderName = net.ReadString()

        if docType == "passport" then
            openPassportUI(data, tpl, isShown, senderName)
        elseif docType == "badge" then
            openBadgeUI(data, tpl, isShown, senderName)
        elseif docType == "military" then
            openMilitaryUI(data, tpl, isShown, senderName)
        elseif docType == "license" or docType == "civilian_license" then
            openLicenseUI(data, tpl, isShown, senderName)
        elseif docType == "milLicense" or docType == "license_mil" or docType == "military_license" then
            openMilLicenseUI(data, tpl, isShown, senderName)
        elseif docType == "medcard" then
            openMedCardUI(data, tpl, isShown, senderName)
        end
    end)

    -- ── Админ-меню настройки шаблонов документов ──────────────
    local function openAdminUI(tpl)
        tpl = tpl or {}
        tpl.passport        = tpl.passport        or {}
        tpl.military        = tpl.military        or {}
        tpl.license         = tpl.license         or {}
        tpl.militaryLicense = tpl.militaryLicense or {}
        tpl.factions        = tpl.factions        or {}
        tpl.access          = tpl.access          or { passports = {}, badges = {}, military = {}, licenses = {}, milLicenses = {}, coverDocs = {} }

        local frame = vgui.Create("DFrame")
        frame:SetSize(720, 600)
        frame:Center()
        frame:SetTitle("GRM — Настройка шаблонов бланков документов и прав доступа")
        frame:MakePopup()
        frame.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, Color(22, 26, 34)) end

        local tabs = vgui.Create("DPropertySheet", frame)
        tabs:Dock(FILL)
        tabs:DockMargin(8, 8, 8, 8)

        -- Вкладка 1: Паспорт
        local passPnl = vgui.Create("DPanel", tabs)
        passPnl:DockPadding(16, 16, 16, 16)
        passPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(30, 35, 45)) end

        local lblS1 = vgui.Create("DLabel", passPnl)
        lblS1:SetPos(16, 16) lblS1:SetText("Название государства в паспорте:") lblS1:SetFont("GRMDoc_Bold") lblS1:SizeToContents()
        local entState = vgui.Create("DTextEntry", passPnl)
        entState:SetPos(16, 38) entState:SetSize(350, 28) entState:SetText(tpl.passport.stateTitle or "РЕСПУБЛИКА ГРАНД")

        local lblS2 = vgui.Create("DLabel", passPnl)
        lblS2:SetPos(16, 76) lblS2:SetText("Серия паспорта по умолчанию:") lblS2:SetFont("GRMDoc_Bold") lblS2:SizeToContents()
        local entSeries = vgui.Create("DTextEntry", passPnl)
        entSeries:SetPos(16, 98) entSeries:SetSize(150, 28) entSeries:SetText(tpl.passport.defaultSeries or "GRM")

        local lblS2b = vgui.Create("DLabel", passPnl)
        lblS2b:SetPos(196, 76) lblS2b:SetText("Код страны в MRZ (3 буквы A-Z):") lblS2b:SetFont("GRMDoc_Bold") lblS2b:SizeToContents()
        local entCountry = vgui.Create("DTextEntry", passPnl)
        entCountry:SetPos(196, 98) entCountry:SetSize(170, 28) entCountry:SetText(tpl.passport.countryCode or "GRM")

        local lblS3 = vgui.Create("DLabel", passPnl)
        lblS3:SetPos(16, 136) lblS3:SetText("Гражданство по умолчанию:") lblS3:SetFont("GRMDoc_Bold") lblS3:SizeToContents()
        local entNat = vgui.Create("DTextEntry", passPnl)
        entNat:SetPos(16, 158) entNat:SetSize(350, 28) entNat:SetText(tpl.passport.defaultNationality or "Гражданин Республики")

        local lblS4 = vgui.Create("DLabel", passPnl)
        lblS4:SetPos(16, 196) lblS4:SetText("Место рождения по умолчанию:") lblS4:SetFont("GRMDoc_Bold") lblS4:SizeToContents()
        local entBPlace = vgui.Create("DTextEntry", passPnl)
        entBPlace:SetPos(16, 218) entBPlace:SetSize(350, 28) entBPlace:SetText(tpl.passport.defaultBirthPlace or "г. Приморск, Республика Гранд")

        tabs:AddSheet("Паспорт", passPnl, "icon16/book.png")

        -- Вкладка 2: Военный билет
        local milPnl = vgui.Create("DPanel", tabs)
        milPnl:DockPadding(16, 16, 16, 16)
        milPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(30, 35, 45)) end

        local lblM1 = vgui.Create("DLabel", milPnl)
        lblM1:SetPos(16, 16) lblM1:SetText("Заголовок бланка военного билета:") lblM1:SetFont("GRMDoc_Bold") lblM1:SizeToContents()
        local entMilTitle = vgui.Create("DTextEntry", milPnl)
        entMilTitle:SetPos(16, 38) entMilTitle:SetSize(350, 28) entMilTitle:SetText(tpl.military.stateTitle or "ВООРУЖЁННЫЕ СИЛЫ")

        local lblM2 = vgui.Create("DLabel", milPnl)
        lblM2:SetPos(16, 76) lblM2:SetText("Префикс номера военного билета:") lblM2:SetFont("GRMDoc_Bold") lblM2:SizeToContents()
        local entMilPfx = vgui.Create("DTextEntry", milPnl)
        entMilPfx:SetPos(16, 98) entMilPfx:SetSize(150, 28) entMilPfx:SetText(tpl.military.defaultPrefix or "ВБ-")

        local lblM3 = vgui.Create("DLabel", milPnl)
        lblM3:SetPos(16, 136) lblM3:SetText("Военкомат / Орган выдачи по умолчанию:") lblM3:SetFont("GRMDoc_Bold") lblM3:SizeToContents()
        local entMilIssuer = vgui.Create("DTextEntry", milPnl)
        entMilIssuer:SetPos(16, 158) entMilIssuer:SetSize(350, 28) entMilIssuer:SetText(tpl.military.defaultIssuer or "Военный комиссариат Центрального округа")

        tabs:AddSheet("Военный билет", milPnl, "icon16/book_open.png")

        -- Вкладка 3: Гражданские водительские права (Дорожная Инспекция)
        local licPnl = vgui.Create("DPanel", tabs)
        licPnl:DockPadding(16, 16, 16, 16)
        licPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(30, 35, 45)) end

        local lblL1 = vgui.Create("DLabel", licPnl)
        lblL1:SetPos(16, 16) lblL1:SetText("Заголовок бланка прав Дорожной Инспекции:") lblL1:SetFont("GRMDoc_Bold") lblL1:SizeToContents()
        local entLicTitle = vgui.Create("DTextEntry", licPnl)
        entLicTitle:SetPos(16, 38) entLicTitle:SetSize(350, 28) entLicTitle:SetText(tpl.license.stateTitle or "ДОРОЖНАЯ ИНСПЕКЦИЯ")

        local lblL2 = vgui.Create("DLabel", licPnl)
        lblL2:SetPos(16, 76) lblL2:SetText("Префикс номера прав:") lblL2:SetFont("GRMDoc_Bold") lblL2:SizeToContents()
        local entLicPfx = vgui.Create("DTextEntry", licPnl)
        entLicPfx:SetPos(16, 98) entLicPfx:SetSize(150, 28) entLicPfx:SetText(tpl.license.defaultPrefix or "ВУ-")

        local lblL3 = vgui.Create("DLabel", licPnl)
        lblL3:SetPos(16, 136) lblL3:SetText("Орган выдачи прав по умолчанию:") lblL3:SetFont("GRMDoc_Bold") lblL3:SizeToContents()
        local entLicIssuer = vgui.Create("DTextEntry", licPnl)
        entLicIssuer:SetPos(16, 158) entLicIssuer:SetSize(350, 28) entLicIssuer:SetText(tpl.license.defaultIssuer or "Дорожная Инспекция Полиции Порядка")

        tabs:AddSheet("Права (Дорожная Инспекция)", licPnl, "icon16/car.png")

        -- Вкладка 4: Военные водительские права (ВАИ)
        local milLicPnl = vgui.Create("DPanel", tabs)
        milLicPnl:DockPadding(16, 16, 16, 16)
        milLicPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(30, 35, 45)) end

        local lblML1 = vgui.Create("DLabel", milLicPnl)
        lblML1:SetPos(16, 16) lblML1:SetText("Заголовок бланка прав ВАИ:") lblML1:SetFont("GRMDoc_Bold") lblML1:SizeToContents()
        local entMilLicTitle = vgui.Create("DTextEntry", milLicPnl)
        entMilLicTitle:SetPos(16, 38) entMilLicTitle:SetSize(350, 28) entMilLicTitle:SetText(tpl.militaryLicense.stateTitle or "ВОЕННАЯ АВТОМОБИЛЬНАЯ ИНСПЕКЦИЯ")

        local lblML2 = vgui.Create("DLabel", milLicPnl)
        lblML2:SetPos(16, 76) lblML2:SetText("Префикс номера прав ВАИ:") lblML2:SetFont("GRMDoc_Bold") lblML2:SizeToContents()
        local entMilLicPfx = vgui.Create("DTextEntry", milLicPnl)
        entMilLicPfx:SetPos(16, 98) entMilLicPfx:SetSize(150, 28) entMilLicPfx:SetText(tpl.militaryLicense.defaultPrefix or "ВАИ-")

        local lblML3 = vgui.Create("DLabel", milLicPnl)
        lblML3:SetPos(16, 136) lblML3:SetText("Орган выдачи прав ВАИ по умолчанию:") lblML3:SetFont("GRMDoc_Bold") lblML3:SizeToContents()
        local entMilLicIssuer = vgui.Create("DTextEntry", milLicPnl)
        entMilLicIssuer:SetPos(16, 158) entMilLicIssuer:SetSize(350, 28) entMilLicIssuer:SetText(tpl.militaryLicense.defaultIssuer or "101-я Военная автомобильная инспекция (ВАИ)")

        tabs:AddSheet("Права (ВАИ)", milLicPnl, "icon16/car.png")

        -- Вкладка 5: Удостоверения фракций
        local facPnl = vgui.Create("DPanel", tabs)
        facPnl:DockPadding(16, 16, 16, 16)
        facPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(30, 35, 45)) end

        local lblF = vgui.Create("DLabel", facPnl)
        lblF:SetPos(16, 16) lblF:SetText("Выберите фракцию для настройки:") lblF:SetFont("GRMDoc_Bold") lblF:SizeToContents()

        local comboFac = vgui.Create("DComboBox", facPnl)
        comboFac:SetPos(16, 38) comboFac:SetSize(350, 28)

        local names = {}
        for fname, f in pairs(Factions or FactionsData or {}) do
            if isstring(fname) and istable(f) then names[#names+1] = fname end
        end
        table.sort(names)
        for _, fn in ipairs(names) do comboFac:AddChoice(fn) end

        local lblTitle = vgui.Create("DLabel", facPnl)
        lblTitle:SetPos(16, 80) lblTitle:SetText("Надпись на обложке (тиснение):") lblTitle:SetFont("GRMDoc_Bold") lblTitle:SizeToContents()
        local entCoverTitle = vgui.Create("DTextEntry", facPnl)
        entCoverTitle:SetPos(16, 102) entCoverTitle:SetSize(350, 28)

        local lblPfx = vgui.Create("DLabel", facPnl)
        lblPfx:SetPos(16, 140) lblPfx:SetText("Служебный префикс номера жетона:") lblPfx:SetFont("GRMDoc_Bold") lblPfx:SizeToContents()
        local entPrefix = vgui.Create("DTextEntry", facPnl)
        entPrefix:SetPos(16, 162) entPrefix:SetSize(180, 28)

        local lblCol = vgui.Create("DLabel", facPnl)
        lblCol:SetPos(16, 200) lblCol:SetText("Цвет кожаной обложки:") lblCol:SetFont("GRMDoc_Bold") lblCol:SizeToContents()
        local comboCol = vgui.Create("DComboBox", facPnl)
        comboCol:SetPos(16, 222) comboCol:SetSize(250, 28)
        for _, cDef in ipairs(DOC.CoverColors) do comboCol:AddChoice(cDef.name, cDef) end

        local lblFoil = vgui.Create("DLabel", facPnl)
        lblFoil:SetPos(16, 260) lblFoil:SetText("Стиль тиснения надписи:") lblFoil:SetFont("GRMDoc_Bold") lblFoil:SizeToContents()
        local comboFoil = vgui.Create("DComboBox", facPnl)
        comboFoil:SetPos(16, 282) comboFoil:SetSize(250, 28)
        for fId, fDef in pairs(DOC.FoilStyles) do comboFoil:AddChoice(fDef.name, fId) end

        local lblIcon = vgui.Create("DLabel", facPnl)
        lblIcon:SetPos(16, 320) lblIcon:SetText("Значок металлического жетона:") lblIcon:SetFont("GRMDoc_Bold") lblIcon:SizeToContents()
        local comboIcon = vgui.Create("DComboBox", facPnl)
        comboIcon:SetPos(16, 342) comboIcon:SetSize(250, 28)
        for icId, icName in pairs(DOC.BadgeIcons) do comboIcon:AddChoice(icName, icId) end

        local function loadFactionSettings(fname)
            tpl.factions = tpl.factions or {}
            local cfg = tpl.factions[fname] or {}
            entCoverTitle:SetText(cfg.coverTitle or fname)
            entPrefix:SetText(cfg.prefix or (fname:sub(1, 3):upper() .. "-"))
            comboCol:SetValue("Выбрать цвет")
            comboFoil:SetValue(DOC.FoilStyles[cfg.foilStyle or "gold"] and DOC.FoilStyles[cfg.foilStyle or "gold"].name or "Золотое тиснение")
            comboIcon:SetValue(DOC.BadgeIcons[cfg.badgeIcon or "star"] or "★ Звезда")
        end

        comboFac.OnSelect = function(_, _, fname) loadFactionSettings(fname) end

        if #names > 0 then
            comboFac:SetValue(names[1])
            loadFactionSettings(names[1])
        end

        tabs:AddSheet("Служебные удостоверения", facPnl, "icon16/shield.png")

        -- Вкладка 6: Права доступа к Компьютеру
        local accPnl = vgui.Create("DPanel", tabs)
        accPnl:DockPadding(10, 10, 10, 10)
        accPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(30, 35, 45)) end

        local accScroll = vgui.Create("DScrollPanel", accPnl)
        accScroll:Dock(FILL)

        local function mkSection(title, col)
            local lbl = vgui.Create("DLabel", accScroll)
            lbl:Dock(TOP)
            lbl:DockMargin(0, 10, 0, 4)
            lbl:SetText(title)
            lbl:SetFont("GRMDoc_Bold")
            lbl:SetTextColor(col or Color(80, 160, 255))
            lbl:SetTall(22)
            return lbl
        end

        -- 1. Паспорта
        mkSection("1. Фракции с правом оформления паспортов (Паспортный стол):", Color(245, 200, 70))
        local passBoxes = {}
        for _, fname in ipairs(names) do
            local chk = vgui.Create("DCheckBoxLabel", accScroll)
            chk:Dock(TOP) chk:DockMargin(12, 2, 0, 2)
            chk:SetText(fname)
            chk:SetValue(tpl.access.passports and tpl.access.passports[fname] == true)
            passBoxes[fname] = chk
        end

        -- 2. Служебные удостоверения
        mkSection("2. Фракции с правом выдачи служебных удостоверений (Отдел кадров):", Color(80, 160, 255))
        local badgeBoxes = {}
        for _, fname in ipairs(names) do
            local chk = vgui.Create("DCheckBoxLabel", accScroll)
            chk:Dock(TOP) chk:DockMargin(12, 2, 0, 2)
            chk:SetText(fname)
            chk:SetValue(tpl.access.badges and tpl.access.badges[fname] == true)
            badgeBoxes[fname] = chk
        end

        -- 3. Военные билеты
        mkSection("3. Фракции с правом выдачи военных билетов (Военкомат / Комендатура):", Color(120, 220, 140))
        local milBoxes = {}
        for _, fname in ipairs(names) do
            local chk = vgui.Create("DCheckBoxLabel", accScroll)
            chk:Dock(TOP) chk:DockMargin(12, 2, 0, 2)
            chk:SetText(fname)
            chk:SetValue(tpl.access.military and tpl.access.military[fname] == true)
            milBoxes[fname] = chk
        end

        -- 4. Гражданские водительские права
        mkSection("4. Фракции с правом выдачи гражданских прав (Автошкола / Дорожная Инспекция):", Color(80, 190, 240))
        local licBoxes = {}
        for _, fname in ipairs(names) do
            local chk = vgui.Create("DCheckBoxLabel", accScroll)
            chk:Dock(TOP) chk:DockMargin(12, 2, 0, 2)
            chk:SetText(fname)
            chk:SetValue(tpl.access.licenses and tpl.access.licenses[fname] == true)
            licBoxes[fname] = chk
        end

        -- 5. Военные водительские права
        mkSection("5. Фракции с правом выдачи военных прав (ВАИ / Полевая Жандармерия / ВС):", Color(100, 210, 120))
        local milLicBoxes = {}
        for _, fname in ipairs(names) do
            local chk = vgui.Create("DCheckBoxLabel", accScroll)
            chk:Dock(TOP) chk:DockMargin(12, 2, 0, 2)
            chk:SetText(fname)
            chk:SetValue(tpl.access.milLicenses and tpl.access.milLicenses[fname] == true)
            milLicBoxes[fname] = chk
        end

        -- 6. Документы прикрытия
        mkSection("6. Фракции с допуском к документам прикрытия (Спецслужбы / Контрразведка):", Color(240, 120, 50))
        local coverBoxes = {}
        for _, fname in ipairs(names) do
            local chk = vgui.Create("DCheckBoxLabel", accScroll)
            chk:Dock(TOP) chk:DockMargin(12, 2, 0, 2)
            chk:SetText(fname)
            chk:SetValue(tpl.access.coverDocs and tpl.access.coverDocs[fname] == true)
            coverBoxes[fname] = chk
        end

        tabs:AddSheet("Права доступа к Компьютеру", accPnl, "icon16/key.png")

        -- Кнопка сохранения
        local btnSave = vgui.Create("DButton", frame)
        btnSave:Dock(BOTTOM)
        btnSave:DockMargin(16, 8, 16, 12)
        btnSave:SetTall(36)
        btnSave:SetText("✔ Сохранить шаблоны документов и права доступа")
        btnSave:SetFont("GRMDoc_Bold")
        btnSave:SetTextColor(color_white)
        btnSave.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(40, 180, 90) or Color(30, 150, 75))
        end
        btnSave.DoClick = function()
            tpl.passport.stateTitle = entState:GetText()
            tpl.passport.defaultSeries = entSeries:GetText()

            local cc = string.upper(entCountry:GetText() or ""):gsub("[^A-Z]", "")
            tpl.passport.countryCode = (#cc >= 3) and cc:sub(1, 3) or "GRM"
            tpl.passport.defaultNationality = entNat:GetText()
            tpl.passport.defaultBirthPlace = entBPlace:GetText()

            tpl.military.stateTitle = entMilTitle:GetText()
            tpl.military.defaultPrefix = entMilPfx:GetText()
            tpl.military.defaultIssuer = entMilIssuer:GetText()

            tpl.license.stateTitle = entLicTitle:GetText()
            tpl.license.defaultPrefix = entLicPfx:GetText()
            tpl.license.defaultIssuer = entLicIssuer:GetText()

            tpl.militaryLicense.stateTitle = entMilLicTitle:GetText()
            tpl.militaryLicense.defaultPrefix = entMilLicPfx:GetText()
            tpl.militaryLicense.defaultIssuer = entMilLicIssuer:GetText()

            local curFac = comboFac:GetValue()
            if curFac and curFac ~= "" then
                tpl.factions = tpl.factions or {}
                local fCfg = tpl.factions[curFac] or {}
                fCfg.coverTitle = entCoverTitle:GetText()
                fCfg.prefix = entPrefix:GetText()

                local _, colData = comboCol:GetSelected()
                if istable(colData) and colData.col then
                    fCfg.coverColor = { r = colData.col.r, g = colData.col.g, b = colData.col.b }
                end

                local _, foilId = comboFoil:GetSelected()
                if isstring(foilId) then fCfg.foilStyle = foilId end

                local _, iconId = comboIcon:GetSelected()
                if isstring(iconId) then fCfg.badgeIcon = iconId end

                tpl.factions[curFac] = fCfg
            end

            tpl.access.passports = {}
            for fn, cb in pairs(passBoxes) do if cb:GetChecked() then tpl.access.passports[fn] = true end end

            tpl.access.badges = {}
            for fn, cb in pairs(badgeBoxes) do if cb:GetChecked() then tpl.access.badges[fn] = true end end

            tpl.access.military = {}
            for fn, cb in pairs(milBoxes) do if cb:GetChecked() then tpl.access.military[fn] = true end end

            tpl.access.licenses = {}
            for fn, cb in pairs(licBoxes) do if cb:GetChecked() then tpl.access.licenses[fn] = true end end

            tpl.access.milLicenses = {}
            for fn, cb in pairs(milLicBoxes) do if cb:GetChecked() then tpl.access.milLicenses[fn] = true end end

            tpl.access.coverDocs = {}
            for fn, cb in pairs(coverBoxes) do if cb:GetChecked() then tpl.access.coverDocs[fn] = true end end

            net.Start(NET_ADMIN_SAVE)
                net.WriteTable(tpl)
            net.SendToServer()
            frame:Close()
        end
    end

    net.Receive(NET_ADMIN_GET, function()
        local tpl = net.ReadTable()
        openAdminUI(tpl)
    end)

    -- Быстрый вызов через клиентские хуки чата
    hook.Add("PlayerSayTransform", "GRM_Doc_ClientTransform", function(ply, datapack)
        if not istable(datapack) then return end
        local txt = datapack[1] or ""
        local low = string.lower(string.Trim(txt))

        -- Паспорт
        if low == "/passport" or low == "/pass" or low == "/myid" or low == "/id" or low == "/mypasport" or low == "/паспорт" or low == "/пас" then
            net.Start(NET_OPEN_DOC)
            net.WriteString("passport")
            net.SendToServer()
            datapack[1] = ""
            datapack.SkipPlayerSay = true
            return
        end

        if low == "/showpassport" or low == "/showpass" or low == "/showid" or low == "/показатьпаспорт" or low == "/покпас" then
            local tr = LocalPlayer():GetEyeTrace()
            net.Start(NET_SHOW_DOC)
                net.WriteString("passport")
                net.WriteEntity(tr.Entity)
            net.SendToServer()
            datapack[1] = ""
            datapack.SkipPlayerSay = true
            return
        end

        -- Удостоверение
        if low == "/badge" or low == "/mybadge" or low == "/udost" or low == "/myudost" or low == "/ксива" or low == "/удостоверение" or low == "/удост" then
            net.Start(NET_OPEN_DOC)
            net.WriteString("badge")
            net.SendToServer()
            datapack[1] = ""
            datapack.SkipPlayerSay = true
            return
        end

        if low == "/showbadge" or low == "/showudost" or low == "/показатьудостоверение" or low == "/показатьксиву" or low == "/покудост" then
            local tr = LocalPlayer():GetEyeTrace()
            net.Start(NET_SHOW_DOC)
                net.WriteString("badge")
                net.WriteEntity(tr.Entity)
            net.SendToServer()
            datapack[1] = ""
            datapack.SkipPlayerSay = true
            return
        end

        -- Военный билет
        if low == "/military" or low == "/militaryid" or low == "/milcard" or low == "/warcard" or low == "/vb" or low == "/военник" or low == "/военныйбилет" or low == "/вб" then
            net.Start(NET_OPEN_DOC)
            net.WriteString("military")
            net.SendToServer()
            datapack[1] = ""
            datapack.SkipPlayerSay = true
            return
        end

        if low == "/showmilitary" or low == "/showmilitaryid" or low == "/showmil" or low == "/showwarcard" or low == "/showvb" or low == "/показатьвоенник" or low == "/показатьвоенныйбилет" or low == "/поквб" then
            local tr = LocalPlayer():GetEyeTrace()
            net.Start(NET_SHOW_DOC)
                net.WriteString("military")
                net.WriteEntity(tr.Entity)
            net.SendToServer()
            datapack[1] = ""
            datapack.SkipPlayerSay = true
            return
        end

        -- Гражданские права (Дорожная Инспекция)
        if low == "/civlicense" or low == "/civprava" or low == "/гражданскиеправа" or low == "/граждправа" then
            net.Start(NET_OPEN_DOC)
                net.WriteString("license")
                net.WriteString("civilian")
            net.SendToServer()
            datapack[1] = ""
            datapack.SkipPlayerSay = true
            return
        end

        if low == "/showcivlicense" or low == "/showcivprava" or low == "/показатьгражданскиеправа" or low == "/покграждправа" then
            local tr = LocalPlayer():GetEyeTrace()
            net.Start(NET_SHOW_DOC)
                net.WriteString("license")
                net.WriteEntity(tr.Entity)
                net.WriteString("civilian")
            net.SendToServer()
            datapack[1] = ""
            datapack.SkipPlayerSay = true
            return
        end

        -- Военные права (ВАИ)
        if low == "/millicense" or low == "/milprava" or low == "/mallicense" or low == "/военныеправа" or low == "/ваиправа" or low == "/вуваи" or low == "/увв" or low == "/военноеву" or low == "/прававаи" or low == "/военныеводправа" then
            net.Start(NET_OPEN_DOC)
                net.WriteString("milLicense")
                net.WriteString("military")
            net.SendToServer()
            datapack[1] = ""
            datapack.SkipPlayerSay = true
            return
        end

        if low == "/showmillicense" or low == "/showmilprava" or low == "/показатьваи" or low == "/показатьвоенныеправа" or low == "/покваи" or low == "/покувв" or low == "/показатьувв" or low == "/поквоенправа" then
            local tr = LocalPlayer():GetEyeTrace()
            net.Start(NET_SHOW_DOC)
                net.WriteString("milLicense")
                net.WriteEntity(tr.Entity)
                net.WriteString("military")
            net.SendToServer()
            datapack[1] = ""
            datapack.SkipPlayerSay = true
            return
        end

        -- Общие права
        if low == "/license" or low == "/prava" or low == "/mylicense" or low == "/driverlicense" or low == "/права" or low == "/водправа" or low == "/водительское" or low == "/ву" then
            net.Start(NET_OPEN_DOC)
            net.WriteString("license")
            net.SendToServer()
            datapack[1] = ""
            datapack.SkipPlayerSay = true
            return
        end

        if low == "/showlicense" or low == "/showprava" or low == "/showdriverlicense" or low == "/показатьправа" or low == "/показатьводправа" or low == "/покправа" or low == "/покву" then
            local tr = LocalPlayer():GetEyeTrace()
            net.Start(NET_SHOW_DOC)
                net.WriteString("license")
                net.WriteEntity(tr.Entity)
            net.SendToServer()
            datapack[1] = ""
            datapack.SkipPlayerSay = true
            return
        end

        -- Медкарта
        if low == "/medcard" or low == "/mycard" or low == "/med" or low == "/медкарта" or low == "/мед" then
            net.Start(NET_OPEN_DOC)
            net.WriteString("medcard")
            net.SendToServer()
            datapack[1] = ""
            datapack.SkipPlayerSay = true
            return
        end

        if low == "/showmedcard" or low == "/showmed" or low == "/показатьмедкарту" or low == "/покмед" then
            local tr = LocalPlayer():GetEyeTrace()
            net.Start(NET_SHOW_DOC)
                net.WriteString("medcard")
                net.WriteEntity(tr.Entity)
            net.SendToServer()
            datapack[1] = ""
            datapack.SkipPlayerSay = true
            return
        end

        -- Админка
        if low == "/doc_admin" or low == "/doccfg" or low == "/docadmin" or low == "/документы" or low == "/докадмин" then
            if LocalPlayer():IsSuperAdmin() then
                net.Start(NET_ADMIN_GET)
                net.SendToServer()
            end
            datapack[1] = ""
            datapack.SkipPlayerSay = true
            return
        end
    end)

    -- Консольные команды
    concommand.Add("passport", function() net.Start(NET_OPEN_DOC) net.WriteString("passport") net.SendToServer() end)
    concommand.Add("badge", function() net.Start(NET_OPEN_DOC) net.WriteString("badge") net.SendToServer() end)
    concommand.Add("military", function() net.Start(NET_OPEN_DOC) net.WriteString("military") net.SendToServer() end)
    concommand.Add("license", function() net.Start(NET_OPEN_DOC) net.WriteString("license") net.SendToServer() end)
    concommand.Add("millicense", function() net.Start(NET_OPEN_DOC) net.WriteString("milLicense") net.WriteString("military") net.SendToServer() end)
    concommand.Add("medcard", function() net.Start(NET_OPEN_DOC) net.WriteString("medcard") net.SendToServer() end)
    concommand.Add("showpassport", function()
        local tr = LocalPlayer():GetEyeTrace()
        net.Start(NET_SHOW_DOC) net.WriteString("passport") net.WriteEntity(tr.Entity) net.SendToServer()
    end)
    concommand.Add("showbadge", function()
        local tr = LocalPlayer():GetEyeTrace()
        net.Start(NET_SHOW_DOC) net.WriteString("badge") net.WriteEntity(tr.Entity) net.SendToServer()
    end)
    concommand.Add("showmilitary", function()
        local tr = LocalPlayer():GetEyeTrace()
        net.Start(NET_SHOW_DOC) net.WriteString("military") net.WriteEntity(tr.Entity) net.SendToServer()
    end)
    concommand.Add("showlicense", function()
        local tr = LocalPlayer():GetEyeTrace()
        net.Start(NET_SHOW_DOC) net.WriteString("license") net.WriteEntity(tr.Entity) net.SendToServer()
    end)
    concommand.Add("showmillicense", function()
        local tr = LocalPlayer():GetEyeTrace()
        net.Start(NET_SHOW_DOC) net.WriteString("milLicense") net.WriteEntity(tr.Entity) net.WriteString("military") net.SendToServer()
    end)
    concommand.Add("showmedcard", function()
        local tr = LocalPlayer():GetEyeTrace()
        net.Start(NET_SHOW_DOC) net.WriteString("medcard") net.WriteEntity(tr.Entity) net.SendToServer()
    end)

    print("[GRM Documents] Core v" .. DOC.Version .. " (Client) loaded")
end
