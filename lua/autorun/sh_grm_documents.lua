--[[--------------------------------------------------------------------
    GRM Documents & Identity Core v1.1.0 (Код 87)
    Паспорта, Служебные Удостоверения, Ксивы, Военные Билеты, Прикрытие, Реестр

    • Паспорт гражданина: ФИО, пол, дата рождения, гражданство, серия, номер,
      орган выдачи, дата, подпись, фото, MRZ.
    • Служебное удостоверение (Ксива): настраиваемое название на обложке,
      служебный префикс номера жетона, цвет кожаной корочки, тиснение, жетон,
      звание, отдел, матрица 6 спецдопусков (оружие, арест, обыск, ордера,
      спецтранспорт, режимный проход).
    • Военный билет: серия/номер, ФИО, воинское звание, ВУС, воинское
      формирование (выбор/ручной), подразделение/отдел (выбор/ручной),
      должность (ручной ввод), категория годности (А–Д), кем выдан.
    • Документы прикрытия: спецслужбы с CoverDocsAccess фабрикуют 100% аутентичные
      удостоверения любых ведомств для маскировки.
    • Двухфазный интерактивный просмотр: Закрытая обложка ⇄ Раскрытый разворот.
    • Показ документов: /showpassport, /showbadge, /showmilitary, /showmedcard
      с RP /me в чат и интерактивным окном у цели.
    • Полные и сокращённые команды (рус/англ).
    • Единая админ-панель: /doc_admin (настройка дизайна, префиксов и доступов).
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

DOC.Version       = "1.1.0"
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

-- Значки жетонов на левой створке
DOC.BadgeIcons = {
    star     = "★ Звезда шерифа / полиции",
    shield   = "🛡 Щит правопорядка",
    eagle    = "🦅 Государственный герб / Орёл",
    swords   = "⚔ Щит и меч (Госбезопасность)",
    military = "🪖 Воинская звезда / ВС",
    scales   = "⚖ Весы правосудия (Суд / Прокуратура)",
    bank     = "🏛 Банковский резерв / Казна",
    med      = "✚ Медицинский крест",
}

-- Список специальных допусков для удостоверения
DOC.PermissionsList = {
    { id = "weapon",    title = "Ношение табельного оружия", desc = "Право на скрытое/открытое ношение спецвооружения" },
    { id = "arrest",    title = "Проведение задержаний",     desc = "Право на арест и применение спецсредств" },
    { id = "search",    title = "Обыск и досмотр",           desc = "Право на проверку граждан и имущества" },
    { id = "access",    title = "Беспрепятственный доступ",   desc = "Доступ на закрытые и режимные объекты" },
    { id = "transport", title = "Управление спецтранспортом",desc = "Допуск к оперативным автомобилям ведомства" },
    { id = "warrant",   title = "Исполнение ордеров",        desc = "Право на принудительное вскрытие дверей" },
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
                stateTitle    = "РЕСПУБЛИКА ГРАНД",
                docTitle      = "ПАСПОРТ ГРАЖДАНИНА",
                coverColor    = { r = 85, g = 20, b = 25 },
                foilStyle     = "gold",
                defaultSeries = "GRM",
            },
            military = {
                stateTitle    = "ВООРУЖЁННЫЕ СИЛЫ",
                docTitle      = "ВОЕННЫЙ БИЛЕТ",
                coverColor    = { r = 38, g = 58, b = 36 },
                foilStyle     = "gold",
                defaultPrefix = "ВБ-",
                defaultIssuer = "Военный комиссариат Центрального округа",
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
                passports = { ["Department of Labour and Social Protection"] = true },
                badges    = { ["OrdnungPolizei"] = true, ["Department of Labour and Social Protection"] = true },
                military  = { ["OrdnungPolizei"] = true, ["Department of Labour and Social Protection"] = true },
                coverDocs = {},
            }
        }
    end

    function DOC.LoadTemplates()
        DOC.Templates = defaultTemplates()
        if file.Exists(DOC.TemplatesFile, "DATA") then
            local t = jsonT(file.Read(DOC.TemplatesFile, "DATA") or "")
            if istable(t) then
                if istable(t.passport) then DOC.Templates.passport = t.passport end
                if istable(t.military) then DOC.Templates.military = t.military end
                if istable(t.factions) then DOC.Templates.factions = t.factions end
                if istable(t.access)   then DOC.Templates.access   = t.access end
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
        DOC.Registry = { passports = {}, badges = {}, coverBadges = {}, military = {} }
        if file.Exists(DOC.RegistryFile, "DATA") then
            local t = jsonT(file.Read(DOC.RegistryFile, "DATA") or "")
            if istable(t) then
                DOC.Registry.passports   = istable(t.passports) and t.passports or {}
                DOC.Registry.badges      = istable(t.badges) and t.badges or {}
                DOC.Registry.coverBadges = istable(t.coverBadges) and t.coverBadges or {}
                DOC.Registry.military    = istable(t.military) and t.military or {}
            end
        end
        return DOC.Registry
    end

    function DOC.SaveRegistry(why)
        local ok, txt = pcall(util.TableToJSON, DOC.Registry or {}, true)
        if ok and txt then
            file.Write(DOC.RegistryFile, txt)
            print("[GRM Documents] SAVE ok registry (" .. tostring(why or "?") .. "), паспортов: " .. table.Count(DOC.Registry.passports or {}) .. ", удостоверений: " .. table.Count(DOC.Registry.badges or {}) .. ", военников: " .. table.Count(DOC.Registry.military or {}))
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
                charKey     = key,
                steamID64   = sid64,
                fullName    = getPlayerRPName(ply),
                gender      = "Мужской",
                birthDate   = "12.04.1988",
                nationality = "Гражданин Республики",
                series      = tpl.defaultSeries or "GRM",
                number      = tostring(shortSid) .. "-" .. tostring(slotNum ~= "" and slotNum or "1"),
                issuedBy    = "Паспортный стол Центрального района",
                issueDate   = os.date("%d.%m.%Y"),
                status      = "Действителен",
                created     = os.time(),
                updated     = os.time(),
            }
            DOC.Registry.passports[key] = p
            DOC.SaveRegistry("auto passport " .. key)
        else
            local curName = getPlayerRPName(ply)
            if curName ~= "" and curName ~= "?" and p.fullName ~= curName then
                p.fullName = curName
                p.updated = os.time()
            end
        end
        return p
    end
    DOC.EnsurePassport = ensurePassport

    -- Авто-создание / получение служебного удостоверения
    local function ensureBadge(ply)
        local key = getCharKey(ply)
        if key == "" then return nil end
        local factionName = ply:GetNWString("GRM_Faction", "")
        if factionName == "" then return nil end

        DOC.Registry.badges = DOC.Registry.badges or {}
        local b = DOC.Registry.badges[key]
        local role = ply:GetNWString("GRM_Role", "Сотрудник")
        local dept = ply:GetNWString("GRM_Department", "")
        if dept == "Основной" or dept == "—" then dept = "" end

        local tpl = (DOC.Templates.factions and DOC.Templates.factions[factionName]) or {}
        local prefix = tpl.prefix or (factionName:sub(1, 3):upper() .. "-")
        local shortSid = (ply:SteamID64() or "0"):sub(-4)

        if not istable(b) or b.faction ~= factionName then
            b = {
                charKey     = key,
                steamID64   = ply:SteamID64() or "0",
                fullName    = getPlayerRPName(ply),
                faction     = factionName,
                department  = dept ~= "" and dept or "Главное Управление",
                role        = role ~= "" and role or "Сотрудник",
                number      = prefix .. tostring(shortSid),
                issuedBy    = "Руководство ведомства " .. factionName,
                issueDate   = os.date("%d.%m.%Y"),
                validUntil  = "Бессрочно",
                permissions = tblCopy(tpl.defaultPerms or { weapon = true, access = true }),
                status      = "Действителен",
                created     = os.time(),
                updated     = os.time(),
            }
            DOC.Registry.badges[key] = b
            DOC.SaveRegistry("auto badge " .. key)
        else
            if not b.department or b.department == "" or b.department == "Основной" or b.department == "—" then
                b.department = dept ~= "" and dept or "Главное Управление"
            end
            if not b.role or b.role == "" then b.role = role end
            if not b.fullName or b.fullName == "" then b.fullName = getPlayerRPName(ply) end
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
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p:GetPos():DistToSqr(ply:GetPos()) <= 400 * 400 then
                    p:ChatPrint(string.format("[RP] %s %s", senderName, meText))
                end
            end

            net.Start(NET_RECEIVE_VIEW)
                net.WriteString("passport")
                net.WriteTable(pass)
                net.WriteTable(tpl)
                net.WriteBool(true)
                net.WriteString(senderName)
            net.Send({ ply, target })

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
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p:GetPos():DistToSqr(ply:GetPos()) <= 400 * 400 then
                    p:ChatPrint(string.format("[RP] %s %s", senderName, meText))
                end
            end

            net.Start(NET_RECEIVE_VIEW)
                net.WriteString("badge")
                net.WriteTable(badge)
                net.WriteTable(tpl)
                net.WriteBool(true)
                net.WriteString(senderName)
            net.Send({ ply, target })

        elseif docType == "military" then
            local mil = ensureMilitary(ply)
            if not mil or mil.status == "Аннулирован" then
                if GRM.Notify then GRM.Notify(ply, "У вас нет оформленного военного билета (выдаётся в военкомате через Компьютер).", 255, 140, 110) end
                return
            end
            local tpl = DOC.Templates.military or {}

            local meText = string.format("показал(а) военный билет игроку %s (Военный билет №%s, Звание: %s, Формирование: %s)", targetName, mil.number or "—", mil.rank or "—", mil.formation or "—")
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p:GetPos():DistToSqr(ply:GetPos()) <= 400 * 400 then
                    p:ChatPrint(string.format("[RP] %s %s", senderName, meText))
                end
            end

            net.Start(NET_RECEIVE_VIEW)
                net.WriteString("military")
                net.WriteTable(mil)
                net.WriteTable(tpl)
                net.WriteBool(true)
                net.WriteString(senderName)
            net.Send({ ply, target })

        elseif docType == "medcard" then
            if GRM.Medical and GRM.Medical.CardOf then
                local cardKey = getCharKey(ply)
                local card = GRM.Medical.CardOf(cardKey)
                local meText = string.format("передал(а) медицинскую карту на имя %s игроку %s", getPlayerRPName(ply), targetName)
                for _, p in ipairs(player.GetAll()) do
                    if IsValid(p) and p:GetPos():DistToSqr(ply:GetPos()) <= 400 * 400 then
                        p:ChatPrint(string.format("[RP] %s %s", senderName, meText))
                    end
                end

                net.Start(NET_RECEIVE_VIEW)
                    net.WriteString("medcard")
                    net.WriteTable(card or {})
                    net.WriteTable({ patientName = getPlayerRPName(ply) })
                    net.WriteBool(true)
                    net.WriteString(senderName)
                net.Send({ ply, target })
            end
        end
    end
    DOC.ShowDocToTarget = showDocToTarget

    -- Регистрация предметов инвентаря
    local function regInventoryItems()
        if not (GRM.Inventory and GRM.Inventory.RegisterItem) then return end
        GRM.Inventory.RegisterItem("passport", {
            type     = "item",
            name     = "Паспорт гражданина",
            desc     = "Удостоверение личности гражданина. «Использовать» — открыть свой паспорт.",
            icon     = "icon16/vcard.png",
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

    -- Админ-настройка шаблонов
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
            if istable(tpl.passport) then DOC.Templates.passport = tpl.passport end
            if istable(tpl.military) then DOC.Templates.military = tpl.military end
            if istable(tpl.factions) then DOC.Templates.factions = tpl.factions end
            if istable(tpl.access)   then DOC.Templates.access   = tpl.access end
            DOC.SaveTemplates("admin edit by " .. ply:Nick())
            if GRM.Notify then GRM.Notify(ply, "Шаблоны документов успешно сохранены.", 120, 220, 140) end
        end
    end)

    -- Выдача документов через Компьютер
    net.Receive(NET_COMPUTER_ISSUE, function(_, ply)
        if not IsValid(ply) then return end
        local docType = net.ReadString()
        local targetKey = net.ReadString()
        local data = net.ReadTable() or {}

        if targetKey == "" then return end

        if docType == "passport" then
            if not DOC.CanIssuePassports(ply) then
                if GRM.Notify then GRM.Notify(ply, "У вашей фракции нет допуска к оформлению паспортов.", 255, 120, 100) end
                return
            end

            DOC.Registry.passports[targetKey] = data
            data.charKey = targetKey
            data.updated = os.time()
            DOC.SaveRegistry("issue passport " .. targetKey .. " by " .. ply:Nick())
            if GRM.Notify then GRM.Notify(ply, "Паспорт успешно оформлен: " .. tostring(data.fullName), 120, 220, 140) end

            local targetPly = (GRM.Identity and GRM.Identity.ResolveCharacter and GRM.Identity.ResolveCharacter(targetKey))
            if IsValid(targetPly) and GRM.Notify then
                GRM.Notify(targetPly, "Вам оформлен и выдан паспорт гражданина (" .. tostring(data.series) .. " №" .. tostring(data.number) .. ").", 120, 200, 255)
            end

        elseif docType == "badge" then
            local isCover = data.isCover == true
            if isCover then
                local myFac = ply:GetNWString("GRM_Faction", "")
                if not (ply:IsSuperAdmin() or (DOC.Templates.access and DOC.Templates.access.coverDocs and DOC.Templates.access.coverDocs[myFac] == true)) then
                    if GRM.Notify then GRM.Notify(ply, "У вас нет допуска к фабрикации документов прикрытия.", 255, 120, 100) end
                    return
                end
                DOC.Registry.coverBadges[targetKey] = data
                data.charKey = targetKey
                data.updated = os.time()
                DOC.SaveRegistry("issue cover badge " .. targetKey .. " by " .. ply:Nick())
                if GRM.Notify then GRM.Notify(ply, "Документ прикрытия (" .. tostring(data.faction) .. ") успешно выдан: " .. tostring(data.fullName), 120, 220, 140) end
            else
                if not DOC.CanIssueBadges(ply, data.faction) then
                    if GRM.Notify then GRM.Notify(ply, "Вы можете выдавать удостоверения только своего ведомства.", 255, 120, 100) end
                    return
                end
                DOC.Registry.badges[targetKey] = data
                data.charKey = targetKey
                data.updated = os.time()
                DOC.SaveRegistry("issue badge " .. targetKey .. " by " .. ply:Nick())
                if GRM.Notify then GRM.Notify(ply, "Служебное удостоверение оформлено: " .. tostring(data.fullName), 120, 220, 140) end
            end

            local targetPly = (GRM.Identity and GRM.Identity.ResolveCharacter and GRM.Identity.ResolveCharacter(targetKey))
            if IsValid(targetPly) and GRM.Notify then
                GRM.Notify(targetPly, "Вам выдано служебное удостоверение " .. tostring(data.faction) .. " (Жетон: " .. tostring(data.number) .. ").", 120, 200, 255)
            end

        elseif docType == "military" then
            if not DOC.CanIssueMilitary(ply) then
                if GRM.Notify then GRM.Notify(ply, "У вашей фракции нет допуска к выдаче военных билетов.", 255, 120, 100) end
                return
            end

            DOC.Registry.military[targetKey] = data
            data.charKey = targetKey
            data.updated = os.time()
            DOC.SaveRegistry("issue military " .. targetKey .. " by " .. ply:Nick())
            if GRM.Notify then GRM.Notify(ply, "Военный билет оформлен: " .. tostring(data.fullName), 120, 220, 140) end

            local targetPly = (GRM.Identity and GRM.Identity.ResolveCharacter and GRM.Identity.ResolveCharacter(targetKey))
            if IsValid(targetPly) and GRM.Notify then
                GRM.Notify(targetPly, "Вам выдан военный билет №" .. tostring(data.number) .. " (" .. tostring(data.rank) .. ").", 120, 200, 255)
            end
        end
    end)

    net.Receive(NET_COMPUTER_REVOKE, function(_, ply)
        if not IsValid(ply) then return end
        local docType = net.ReadString()
        local targetKey = net.ReadString()
        if docType == "passport" and DOC.Registry.passports[targetKey] then
            if not DOC.CanIssuePassports(ply) then return end
            DOC.Registry.passports[targetKey].status = "Аннулирован"
            DOC.Registry.passports[targetKey].updated = os.time()
            DOC.SaveRegistry("revoke passport " .. targetKey)
            if GRM.Notify then GRM.Notify(ply, "Паспорт аннулирован.", 220, 100, 100) end
        elseif docType == "badge" and DOC.Registry.badges[targetKey] then
            if not DOC.CanIssueBadges(ply) then return end
            DOC.Registry.badges[targetKey].status = "Аннулирован / Изъят"
            DOC.Registry.badges[targetKey].updated = os.time()
            DOC.SaveRegistry("revoke badge " .. targetKey)
            if GRM.Notify then GRM.Notify(ply, "Служебное удостоверение изъято / аннулировано.", 220, 100, 100) end
        elseif docType == "cover" and DOC.Registry.coverBadges[targetKey] then
            DOC.Registry.coverBadges[targetKey].status = "Аннулирован"
            DOC.Registry.coverBadges[targetKey].updated = os.time()
            DOC.SaveRegistry("revoke cover badge " .. targetKey)
            if GRM.Notify then GRM.Notify(ply, "Документ прикрытия аннулирован.", 220, 100, 100) end
        elseif docType == "military" and DOC.Registry.military[targetKey] then
            if not DOC.CanIssueMilitary(ply) then return end
            DOC.Registry.military[targetKey].status = "Аннулирован"
            DOC.Registry.military[targetKey].updated = os.time()
            DOC.SaveRegistry("revoke military " .. targetKey)
            if GRM.Notify then GRM.Notify(ply, "Военный билет аннулирован.", 220, 100, 100) end
        end
    end)

    -- Чат-команды на сервере (резервный перехват)
    hook.Add("PlayerSayTransform", "GRM_Docs_ServerCommands", function(ply, datapack)
        if not istable(datapack) then return end
        local text = datapack[1]
        if not isstring(text) then return end
        local low = string.lower(string.Trim(text))

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
    surface.CreateFont("GRMDoc_CoverTitle", { font = "Roboto", size = 20, weight = 900, extended = true })
    surface.CreateFont("GRMDoc_Foil",       { font = "Roboto", size = 17, weight = 800, extended = true })
    surface.CreateFont("GRMDoc_Header",     { font = "Roboto", size = 15, weight = 700, extended = true })
    surface.CreateFont("GRMDoc_Normal",     { font = "Roboto", size = 13, weight = 500, extended = true })
    surface.CreateFont("GRMDoc_Bold",       { font = "Roboto", size = 13, weight = 700, extended = true })
    surface.CreateFont("GRMDoc_Small",      { font = "Roboto", size = 11, weight = 400, extended = true })
    surface.CreateFont("GRMDoc_MRZ",        { font = "Courier New", size = 12, weight = 700, extended = true })

    local function safeClearFrame(f)
        if not IsValid(f) then return end
        for _, ch in ipairs(f:GetChildren() or {}) do
            if IsValid(ch) and ch ~= f.btnClose and ch ~= f.btnMaxim and ch ~= f.btnMinim and ch ~= f.lblTitle and not ch._grmChrome then
                ch:Remove()
            end
        end
    end

    -- ── ДВУХФАЗНЫЙ РЕНДЕР ПАСПОРТА ────────────────────────────
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
                    draw.SimpleText("🦅", "GRMDoc_CoverTitle", w / 2, 140, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("ГЕРБ ГОСУДАРСТВА", "GRMDoc_Small", w / 2, 175, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    draw.SimpleText(tpl.docTitle or "ПАСПОРТ ГРАЖДАНИНА", "GRMDoc_Foil", w / 2, 320, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("PASSPORT", "GRMDoc_Small", w / 2, 345, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    local topTitle = isShown and ("Вам показал(а) паспорт: " .. tostring(senderName)) or "Ваш паспорт"
                    draw.SimpleText(topTitle, "GRMDoc_Small", w / 2, 20, Color(220, 220, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                end

                local btnExpand = vgui.Create("DButton", frame)
                btnExpand:SetSize(320, 42)
                btnExpand:SetPos(30, 440)
                btnExpand:SetText("📖 Кликните, чтобы развернуть паспорт")
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
                btnFold:SetText("📁 Сложить обложку")
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
                    draw.SimpleText(tpl.stateTitle or "РЕСПУБЛИКА ГРАНД", "GRMDoc_Header", w / 2, 16, Color(50, 45, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText(tpl.docTitle or "ПАСПОРТ ГРАЖДАНИНА", "GRMDoc_Small", w / 2, 36, Color(120, 50, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    draw.RoundedBox(4, 30, 70, 130, 160, Color(210, 205, 195))
                    draw.SimpleText("ФОТОГРАФИЯ", "GRMDoc_Small", 95, 150, Color(150, 145, 135), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                    surface.SetDrawColor(160, 40, 40, 160)
                    surface.DrawOutlinedRect(120, 180, 70, 70)
                    draw.SimpleText("МВД", "GRMDoc_Small", 155, 215, Color(160, 40, 40, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                    draw.SimpleText("Национальность / Статус:", "GRMDoc_Small", 180, 80, Color(110, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText(data.nationality or "Гражданин", "GRMDoc_Bold", 180, 96, Color(40, 35, 30), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.SimpleText("Статус документа:", "GRMDoc_Small", 180, 125, Color(110, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    local statCol = (data.status == "Действителен") and Color(30, 140, 60) or Color(180, 40, 40)
                    draw.SimpleText(data.status or "Действителен", "GRMDoc_Bold", 180, 141, statCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.SimpleText("Личная подпись владельца:", "GRMDoc_Small", 30, 260, Color(110, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    surface.SetDrawColor(80, 75, 65, 180)
                    surface.DrawLine(30, 310, 220, 310)
                    draw.SimpleText(tostring(data.fullName or ""), "GRMDoc_Header", 40, 285, Color(25, 45, 110), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.SimpleText("Владелец паспорта находится под защитой закона.", "GRMDoc_Small", w / 2, 420, Color(130, 125, 115), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end

                local avatar = vgui.Create("AvatarImage", leftPnl)
                avatar:SetPos(35, 75)
                avatar:SetSize(120, 150)
                local sid64 = data.steamID64 or (LocalPlayer():SteamID64())
                avatar:SetSteamID(sid64, 184)

                -- Правая страница
                local rightPnl = vgui.Create("DPanel", frame)
                rightPnl:SetPos(halfW + 24, 32)
                rightPnl:SetSize(halfW - 8, 460)
                rightPnl:SetPaintBackground(false)

                rightPnl.Paint = function(_, w, h)
                    local numStr = "СЕРИЯ " .. tostring(data.series or "GRM") .. "   № " .. tostring(data.number or "000000")
                    draw.SimpleText(numStr, "GRMDoc_Header", w / 2, 16, Color(160, 40, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    local y = 50
                    local function drawField(title, val)
                        draw.SimpleText(title, "GRMDoc_Small", 10, y, Color(110, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        draw.SimpleText(val or "—", "GRMDoc_Bold", 10, y + 16, Color(35, 30, 25), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        surface.SetDrawColor(200, 195, 185)
                        surface.DrawLine(10, y + 36, w - 20, y + 36)
                        y = y + 44
                    end

                    drawField("ФАМИЛИЯ, ИМЯ, ОТЧЕСТВО:", data.fullName or "Гражданин")
                    drawField("ПОЛ:", data.gender or "Мужской")
                    drawField("ДАТА РОЖДЕНИЯ:", data.birthDate or "12.04.1988")
                    drawField("КЕМ ВЫДАН:", data.issuedBy or "Паспортный стол")
                    drawField("ДАТА ВЫДАЧИ:", data.issueDate or os.date("%d.%m.%Y"))

                    draw.RoundedBox(4, 6, 390, w - 16, 50, Color(230, 225, 215))
                    local line1 = string.format("P<GRM%s<<%s<<<<<<<<<<<<<<<<<<", (data.series or "GRM"), (data.fullName or "CITIZEN"):gsub("%s+", "<"):upper())
                    local line2 = string.format("%s4M8804128GRM<<<<<<<<<<<<<<02", (data.number or "000000"):gsub("%D", ""))
                    draw.SimpleText(line1:sub(1, 38), "GRMDoc_MRZ", 14, 396, Color(50, 45, 40), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText(line2:sub(1, 38), "GRMDoc_MRZ", 14, 416, Color(50, 45, 40), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end
            end
        end

        setPhase(false)
    end

    -- ── ДВУХФАЗНЫЙ РЕНДЕР СЛУЖЕБНОГО УДОСТОВЕРЕНИЯ (Ксива) ─────
    local function openBadgeUI(data, tpl, isShown, senderName)
        tpl = tpl or {}
        local coverCol = tpl.coverColor and Color(tpl.coverColor.r or 18, tpl.coverColor.g or 32, tpl.coverColor.b or 60) or Color(18, 32, 60)
        local foil = DOC.FoilStyles[tpl.foilStyle or "gold"] or DOC.FoilStyles.gold
        local badgeIconName = tpl.badgeIcon or "star"
        local badgeSymbol = (badgeIconName == "star" and "★")
            or (badgeIconName == "shield" and "🛡")
            or (badgeIconName == "eagle" and "🦅")
            or (badgeIconName == "swords" and "⚔")
            or (badgeIconName == "military" and "🪖")
            or (badgeIconName == "scales" and "⚖")
            or (badgeIconName == "bank" and "🏛")
            or (badgeIconName == "med" and "✚") or "★"

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
                    draw.RoundedBox(10, 0, 0, w, h, coverCol)
                    draw.RoundedBox(6, 10, 10, w - 20, h - 20, Color(coverCol.r + 8, coverCol.g + 8, coverCol.b + 8))

                    local coverText = tpl.coverTitle or data.faction or "СЛУЖЕБНОЕ УДОСТОВЕРЕНИЕ"
                    draw.SimpleText(coverText, "GRMDoc_CoverTitle", w / 2, 70, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    draw.SimpleText(badgeSymbol, "GRMDoc_CoverTitle", w / 2, 160, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("СЛУЖЕБНОЕ УДОСТОВЕРЕНИЕ", "GRMDoc_Small", w / 2, 260, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("SERVICE ID", "GRMDoc_Small", w / 2, 280, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    local topTitle = isShown and ("Вам предъявили удостоверение: " .. tostring(senderName)) or "Ваше удостоверение"
                    draw.SimpleText(topTitle, "GRMDoc_Small", w / 2, 20, Color(220, 220, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                end

                local btnExpand = vgui.Create("DButton", frame)
                btnExpand:SetSize(300, 40)
                btnExpand:SetPos(30, 400)
                btnExpand:SetText("📖 Кликните, чтобы развернуть корочку")
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
                frame:SetSize(860, 480)
                frame:Center()

                frame.Paint = function(_, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, coverCol)
                    draw.RoundedBox(6, 6, 6, w / 2 - 10, h - 12, Color(245, 245, 248))
                    draw.RoundedBox(6, w / 2 + 4, 6, w / 2 - 10, h - 12, Color(245, 245, 248))

                    surface.SetDrawColor(30, 30, 35, 220)
                    surface.DrawLine(w / 2 - 2, 0, w / 2 - 2, h)
                    surface.DrawLine(w / 2 + 2, 0, w / 2 + 2, h)

                    local topTitle = isShown and ("Вам предъявили удостоверение: " .. tostring(senderName)) or "Служебное удостоверение сотрудника"
                    draw.SimpleText(topTitle, "GRMDoc_Small", 16, 8, Color(120, 120, 130), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end

                local btnFold = vgui.Create("DButton", frame)
                btnFold:SetSize(140, 24)
                btnFold:SetPos(frame:GetWide() - 180, 8)
                btnFold:SetText("📁 Сложить обложку")
                btnFold:SetFont("GRMDoc_Small")
                btnFold:SetTextColor(Color(80, 75, 65))
                btnFold.Paint = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 205, 195) or Color(225, 220, 210)) end
                btnFold.DoClick = function() surface.PlaySound("garrysmod/ui_click.wav") setPhase(false) end

                local btnClose = vgui.Create("DButton", frame)
                btnClose:SetSize(28, 24)
                btnClose:SetPos(frame:GetWide() - 36, 8)
                btnClose:SetText("✕")
                btnClose:SetTextColor(Color(90, 85, 75))
                btnClose:SetFont("GRMDoc_Bold")
                btnClose.Paint = function(s, w, h)
                    draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(210, 80, 80) or Color(220, 215, 205))
                    if s:IsHovered() then s:SetTextColor(color_white) else s:SetTextColor(Color(90, 85, 75)) end
                end
                btnClose.DoClick = function() frame:Close() end

                local halfW = 410

                -- Левая створка: Металлический жетон и спецдопуски
                local leftPnl = vgui.Create("DPanel", frame)
                leftPnl:SetPos(12, 30)
                leftPnl:SetSize(halfW, 436)
                leftPnl:SetPaintBackground(false)

                leftPnl.Paint = function(_, w, h)
                    local coverText = tpl.coverTitle or data.faction or "СЛУЖЕБНОЕ УДОСТОВЕРЕНИЕ"
                    draw.SimpleText(coverText, "GRMDoc_Header", w / 2, 10, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    draw.RoundedBox(12, w / 2 - 60, 45, 120, 130, Color(40, 45, 55))
                    draw.RoundedBox(10, w / 2 - 56, 49, 112, 122, foil.col)
                    draw.RoundedBox(8, w / 2 - 50, 55, 100, 110, Color(30, 35, 45))

                    draw.SimpleText(badgeSymbol, "GRMDoc_CoverTitle", w / 2, 70, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("ЖЕТОН", "GRMDoc_Small", w / 2, 110, Color(180, 185, 195), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText(tostring(data.number or "0000"), "GRMDoc_Bold", w / 2, 130, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    draw.SimpleText("СПЕЦИАЛЬНЫЕ ДОПУСКИ:", "GRMDoc_Small", 20, 195, Color(100, 105, 115), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    local y = 215
                    local perms = data.permissions or {}
                    for _, pDef in ipairs(DOC.PermissionsList) do
                        local has = perms[pDef.id] == true
                        local col = has and Color(35, 140, 60) or Color(160, 165, 175)
                        local mark = has and "✔ " or "✖ "
                        draw.SimpleText(mark .. pDef.title, "GRMDoc_Small", 24, y, col, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        y = y + 18
                    end

                    surface.SetDrawColor(160, 40, 40, 180)
                    surface.DrawOutlinedRect(w - 110, 335, 80, 80)
                    draw.SimpleText("ПЕЧАТЬ", "GRMDoc_Small", w - 70, 370, Color(160, 40, 40, 200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                    draw.SimpleText("Руководитель ведомства:", "GRMDoc_Small", 20, 360, Color(110, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    surface.SetDrawColor(60, 60, 70, 180)
                    surface.DrawLine(20, 400, 180, 400)
                    draw.SimpleText(tostring(data.issuedBy or "Личная подпись"), "GRMDoc_Small", 20, 382, Color(25, 45, 110), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end

                -- Правая створка: Фото и реквизиты сотрудника
                local rightPnl = vgui.Create("DPanel", frame)
                rightPnl:SetPos(frame:GetWide() / 2 + 10, 30)
                rightPnl:SetSize(halfW, 436)
                rightPnl:SetPaintBackground(false)

                rightPnl.Paint = function(_, w, h)
                    draw.RoundedBox(4, 10, 8, w - 20, 32, coverCol)
                    draw.SimpleText(tostring(data.faction or "ГОСУДАРСТВЕННАЯ СЛУЖБА"), "GRMDoc_Bold", w / 2, 24, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                    draw.RoundedBox(4, 15, 52, 110, 135, Color(210, 205, 195))

                    draw.SimpleText("УДОСТОВЕРЕНИЕ №:", "GRMDoc_Small", 135, 54, Color(110, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText(tostring(data.number or "—"), "GRMDoc_Bold", 135, 70, Color(180, 40, 40), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.SimpleText("ДЕЙСТВИТЕЛЬНО ДО:", "GRMDoc_Small", 135, 95, Color(110, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText(tostring(data.validUntil or "Бессрочно"), "GRMDoc_Bold", 135, 111, Color(30, 35, 45), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.SimpleText("СТАТУС:", "GRMDoc_Small", 135, 138, Color(110, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    local statCol = (data.status == "Действителен") and Color(30, 140, 60) or Color(180, 40, 40)
                    draw.SimpleText(tostring(data.status or "Действителен"), "GRMDoc_Bold", 135, 154, statCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    local y = 200
                    local function drawField(title, val)
                        draw.SimpleText(title, "GRMDoc_Small", 15, y, Color(110, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        draw.SimpleText(val or "—", "GRMDoc_Bold", 15, y + 16, Color(35, 30, 25), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                        surface.SetDrawColor(210, 205, 195)
                        surface.DrawLine(15, y + 36, w - 20, y + 36)
                        y = y + 42
                    end

                    drawField("СОТРУДНИК (ФИО):", data.fullName or "Сотрудник")
                    drawField("ДОЛЖНОСТЬ / ЗВАНИЕ:", data.role or "Сотрудник")
                    drawField("ПОДРАЗДЕЛЕНИЕ / ОТДЕЛ:", data.department or "Главное Управление")
                    drawField("ДАТА ВЫДАЧИ:", data.issueDate or os.date("%d.%m.%Y"))
                end

                local avatar = vgui.Create("AvatarImage", rightPnl)
                avatar:SetPos(18, 55)
                avatar:SetSize(104, 129)
                local sid64 = data.steamID64 or (LocalPlayer():SteamID64())
                avatar:SetSteamID(sid64, 184)
            end
        end

        setPhase(false)
    end

    -- ── ДВУХФАЗНЫЙ РЕНДЕР ВОЕННОГО БИЛЕТА ──────────────────────
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
                frame:SetSize(360, 480)
                frame:Center()

                frame.Paint = function(_, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, coverCol)
                    draw.RoundedBox(6, 10, 10, w - 20, h - 20, Color(coverCol.r + 8, coverCol.g + 8, coverCol.b + 8))

                    draw.SimpleText(tpl.stateTitle or "ВООРУЖЁННЫЕ СИЛЫ", "GRMDoc_Header", w / 2, 70, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("🪖", "GRMDoc_CoverTitle", w / 2, 160, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("ВОЕННЫЙ БИЛЕТ", "GRMDoc_Foil", w / 2, 260, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("MILITARY ID", "GRMDoc_Small", w / 2, 285, foil.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    local topTitle = isShown and ("Вам показали военный билет: " .. tostring(senderName)) or "Ваш военный билет"
                    draw.SimpleText(topTitle, "GRMDoc_Small", w / 2, 20, Color(220, 225, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                end

                local btnExpand = vgui.Create("DButton", frame)
                btnExpand:SetSize(300, 40)
                btnExpand:SetPos(30, 400)
                btnExpand:SetText("📖 Кликните, чтобы открыть военный билет")
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
                frame:SetSize(840, 500)
                frame:Center()

                frame.Paint = function(_, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, coverCol)
                    draw.RoundedBox(8, 6, 6, w - 12, h - 12, Color(246, 244, 238))

                    surface.SetDrawColor(180, 185, 175, 180)
                    surface.DrawLine(w / 2, 8, w / 2, h - 8)

                    local topTitle = isShown and ("Вам предъявили военный билет: " .. tostring(senderName)) or "Военный билет военнослужащего"
                    draw.SimpleText(topTitle, "GRMDoc_Small", 14, 10, Color(90, 100, 90), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end

                local btnFold = vgui.Create("DButton", frame)
                btnFold:SetSize(140, 24)
                btnFold:SetPos(frame:GetWide() - 180, 10)
                btnFold:SetText("📁 Сложить обложку")
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
                leftPnl:SetSize(halfW, 440)
                leftPnl:SetPaintBackground(false)

                leftPnl.Paint = function(_, w, h)
                    draw.SimpleText(tpl.stateTitle or "ВООРУЖЁННЫЕ СИЛЫ", "GRMDoc_Header", w / 2, 12, Color(40, 60, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("ВОЕННЫЙ БИЛЕТ № " .. tostring(data.number or "ВБ-000000"), "GRMDoc_Bold", w / 2, 32, Color(160, 40, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    draw.RoundedBox(4, 20, 65, 120, 150, Color(215, 215, 205))
                    draw.SimpleText("ФОТО", "GRMDoc_Small", 80, 140, Color(140, 140, 130), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                    draw.SimpleText("ФИО ВОЕННОСЛУЖАЩЕГО:", "GRMDoc_Small", 155, 65, Color(100, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText(tostring(data.fullName or "Военнослужащий"), "GRMDoc_Bold", 155, 82, Color(30, 40, 30), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.SimpleText("ВУС (Специальность):", "GRMDoc_Small", 155, 115, Color(100, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText(tostring(data.vus or "ВУС-100 (Стрелок)"), "GRMDoc_Normal", 155, 132, Color(30, 40, 30), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.SimpleText("Категория годности:", "GRMDoc_Small", 155, 165, Color(100, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText(tostring(data.fitness or "А — Годен к службе"), "GRMDoc_Bold", 155, 182, Color(25, 120, 50), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.SimpleText("Кем выдан военный билет:", "GRMDoc_Small", 20, 235, Color(100, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText(tostring(data.issuedBy or "Военный комиссариат"), "GRMDoc_Normal", 20, 252, Color(30, 40, 30), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    surface.SetDrawColor(40, 80, 50, 180)
                    surface.DrawOutlinedRect(20, 290, 110, 60)
                    draw.SimpleText("ВОЕНКОМАТ", "GRMDoc_Small", 75, 310, Color(40, 80, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("ПЕЧАТЬ", "GRMDoc_Small", 75, 330, Color(40, 80, 50), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

                    draw.SimpleText("Подпись владельца:", "GRMDoc_Small", 155, 300, Color(100, 105, 95), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    surface.SetDrawColor(60, 60, 70, 180)
                    surface.DrawLine(155, 340, 320, 340)
                    draw.SimpleText(tostring(data.fullName or ""), "GRMDoc_Small", 165, 322, Color(25, 45, 110), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                end

                local avatar = vgui.Create("AvatarImage", leftPnl)
                avatar:SetPos(24, 70)
                avatar:SetSize(112, 140)
                local sid64 = data.steamID64 or (LocalPlayer():SteamID64())
                avatar:SetSteamID(sid64, 184)

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
                        draw.SimpleText(val or "—", "GRMDoc_Bold", 15, y + 16, Color(30, 40, 30), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
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
                    draw.SimpleText("✚", "GRMDoc_CoverTitle", w / 2, 160, Color(220, 70, 70), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                    draw.SimpleText("МЕДИЦИНСКАЯ КАРТА", "GRMDoc_Foil", w / 2, 260, Color(240, 245, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                    draw.SimpleText("MEDICAL RECORD", "GRMDoc_Small", w / 2, 285, Color(180, 205, 195), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

                    local topTitle = isShown and ("Вам передали медкарту: " .. tostring(senderName)) or "Ваша медицинская карта"
                    draw.SimpleText(topTitle, "GRMDoc_Small", w / 2, 20, Color(220, 225, 220), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
                end

                local btnExpand = vgui.Create("DButton", frame)
                btnExpand:SetSize(300, 40)
                btnExpand:SetPos(30, 400)
                btnExpand:SetText("📖 Кликните, чтобы открыть медкарту")
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
                btnFold:SetText("📁 Сложить обложку")
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
                    draw.SimpleText(tostring(card.name or extra.patientName or "Пациент"), "GRMDoc_Bold", 15, 78, Color(25, 35, 30), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.RoundedBox(6, 15, 110, w - 30, 48, Color(230, 240, 235))
                    draw.SimpleText("КАТЕГОРИЯ ГОДНОСТИ К СЛУЖБЕ / РАБОТЕ:", "GRMDoc_Small", 25, 116, Color(60, 90, 75), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    local fit = card.fitnessCategory or "А — Годен к военной службе и работе"
                    draw.SimpleText(fit, "GRMDoc_Bold", 25, 134, Color(20, 100, 50), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.SimpleText("ГРУППА КРОВИ И РЕЗУС-ФАКТОР:", "GRMDoc_Small", 15, 175, Color(100, 110, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText((card.blood and card.blood ~= "") and card.blood or "Не установлена", "GRMDoc_Bold", 15, 193, Color(180, 40, 40), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.SimpleText("АЛЛЕРГИЧЕСКИЕ РЕАКЦИИ:", "GRMDoc_Small", 15, 230, Color(100, 110, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText((card.allergies and card.allergies ~= "") and card.allergies or "Не выявлено", "GRMDoc_Normal", 15, 248, Color(30, 35, 30), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

                    draw.SimpleText("ХРОНИЧЕСКИЕ ЗАБОЛЕВАНИЯ:", "GRMDoc_Small", 15, 290, Color(100, 110, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
                    draw.SimpleText((card.chronic and card.chronic ~= "") and card.chronic or "Отсутствуют", "GRMDoc_Normal", 15, 308, Color(30, 35, 30), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

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
                            draw.SimpleText(tostring(e.text or "—"), "GRMDoc_Normal", 8, 22, Color(30, 35, 30), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
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
        elseif docType == "medcard" then
            openMedCardUI(data, tpl, isShown, senderName)
        end
    end)

    -- ── Админ-меню настройки шаблонов документов ──────────────
    local function openAdminConfigUI(tpl)
        tpl = tpl or {}
        tpl.passport = tpl.passport or {}
        tpl.military = tpl.military or {}
        tpl.factions = tpl.factions or {}
        tpl.access   = tpl.access or { passports = {}, badges = {}, military = {}, coverDocs = {} }

        local frame = vgui.Create("DFrame")
        frame:SetSize(860, 640)
        frame:Center()
        frame:SetTitle("GRM — Настройка шаблонов документов и прав доступа")
        frame:MakePopup()

        local tabs = vgui.Create("DPropertySheet", frame)
        tabs:Dock(FILL)

        -- Вкладка 1: Паспорта
        local passPnl = vgui.Create("DPanel", tabs)
        passPnl:DockPadding(16, 16, 16, 16)
        passPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(30, 35, 45)) end

        local lbl1 = vgui.Create("DLabel", passPnl)
        lbl1:SetPos(16, 16) lbl1:SetText("Название государства:") lbl1:SetFont("GRMDoc_Bold") lbl1:SizeToContents()
        local entState = vgui.Create("DTextEntry", passPnl)
        entState:SetPos(16, 38) entState:SetSize(350, 28) entState:SetText(tpl.passport.stateTitle or "РЕСПУБЛИКА ГРАНД")

        local lbl2 = vgui.Create("DLabel", passPnl)
        lbl2:SetPos(16, 76) lbl2:SetText("Серия паспортов по умолчанию:") lbl2:SetFont("GRMDoc_Bold") lbl2:SizeToContents()
        local entSeries = vgui.Create("DTextEntry", passPnl)
        entSeries:SetPos(16, 98) entSeries:SetSize(150, 28) entSeries:SetText(tpl.passport.defaultSeries or "GRM")

        tabs:AddSheet("Паспорт гражданина", passPnl, "icon16/vcard.png")

        -- Вкладка 2: Военный билет
        local milPnl = vgui.Create("DPanel", tabs)
        milPnl:DockPadding(16, 16, 16, 16)
        milPnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(30, 35, 45)) end

        local lblM1 = vgui.Create("DLabel", milPnl)
        lblM1:SetPos(16, 16) lblM1:SetText("Заголовок на обложке военного билета:") lblM1:SetFont("GRMDoc_Bold") lblM1:SizeToContents()
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

        -- Вкладка 3: Удостоверения фракций
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

        -- Вкладка 4: Права доступа к Компьютеру
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

        -- 4. Документы прикрытия
        mkSection("4. Фракции с допуском к документам прикрытия (Спецслужбы / Контрразведка):", Color(240, 120, 50))
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

            tpl.military.stateTitle = entMilTitle:GetText()
            tpl.military.defaultPrefix = entMilPfx:GetText()
            tpl.military.defaultIssuer = entMilIssuer:GetText()

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

            tpl.access.coverDocs = {}
            for fn, cb in pairs(coverBoxes) do if cb:GetChecked() then tpl.access.coverDocs[fn] = true end end

            net.Start(NET_ADMIN_SAVE)
                net.WriteTable(tpl)
            net.SendToServer()
            frame:Close()
        end
    end

    net.Receive(NET_ADMIN_GET, function()
        local tpl = net.ReadTable() or {}
        openAdminConfigUI(tpl)
    end)

    -- ============================================================
    -- КЛИЕНТСКИЕ КОМАНДЫ ЧАТА (полные и сокращённые)
    -- ============================================================
    hook.Add("PlayerSayTransform", "GRM_Docs_ClientCommands", function(ply, datapack, is_team, is_local)
        if ply ~= LocalPlayer() then return end
        local msg = datapack[1]
        if not isstring(msg) then return end
        local low = msg:lower():Trim()

        -- Паспорт гражданина
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

        -- Служебное удостоверение
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
    concommand.Add("showmedcard", function()
        local tr = LocalPlayer():GetEyeTrace()
        net.Start(NET_SHOW_DOC) net.WriteString("medcard") net.WriteEntity(tr.Entity) net.SendToServer()
    end)

    print("[GRM Documents] Core v" .. DOC.Version .. " (Client) loaded")
end
