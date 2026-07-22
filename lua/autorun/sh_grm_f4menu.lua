--[[--------------------------------------------------------------------
    GRM F4 Menu v1.4.0 (Код 74) — Игровое меню на F4
    v1.4.0: +хук GRM_F4_BuildTabs(sheet) — модули сборки добавляют свои
      вкладки (Коды 77/78: «Работа», «Ачивки»); шпаргалка пополнена
      группами «Биржа труда», «Ачивки и бонусы», доступ /job_allow.
    v1.3.0: шпаргалка команд дополнена группами «Радио и оповещение»,
      «Доска объявлений», «Админ-доступы» (Коды 75/76), + /wardrobe_add,
      указатель на вкладку «Доступы» в /factions.
    v1.2.0: F4 ловится ДВУМЯ путями (бинд gm_showspare2 + прямой опрос
      KEY_F4 в Think с анти-дублем и защитой от ввода текста/консоли/ESC) —
      репорт владельца: бинд до хука не доходил. F4 теперь ещё и ЗАКРЫВАЕТ
      открытое меню (toggle). Новая вкладка «Графика»: пресеты FPS+/Красота,
      выключатели (тени, свет, блики, вода, небо, трава, motion blur, многоядерность),
      слайдеры дальности отрисовки объектов, LOD, текстур и декалей.
    v1.2.1: убран слайдер fps_max (движок блокирует RunConsoleCommand →
      спам-ошибка при открытии вкладки); добавлен тогл вспышек выстрелов.
      - «Профиль»: игровое имя (RP Name) со сменой, внешность (меню
        персонажа Код 72), описание персонажа (RPDesc Код 71),
        карточка (SteamID64, фракция/роль, баланс).
      - «Команды»: интерактивная шпаргалка по игровым командам сгруппировано
        (Чат RP, Персонаж, Фракции, Деньги, Двери, Транспорт, Телефон, Прочее).
      - «Настройки»: клиентские выключатели HUD (RPDesc над головами,
        дистанция RPDesc, HUD дверей, полоса стамины, полоса сытости).
      - Открытие: F4 (бинд ShowSpare2 + резервный опрос KEY_F4) — уступает дверям
        (прицел на дверь → меню двери), команда /menu, !menu, /f4, concommand grm_f4.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end
if not CLIENT then return end

GRM = GRM or {}
GRM.F4 = GRM.F4 or {}
local F4 = GRM.F4
F4.Version = "1.4.9" -- +Код 88: мобильные телефоны (GTA IV): 7 трубок, приложения, звонки/SMS

surface.CreateFont("GRMF4_Title",  { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("GRMF4_Sub",    { font = "Roboto", size = 15, weight = 600, extended = true })
surface.CreateFont("GRMF4_Normal", { font = "Roboto", size = 13, weight = 500, extended = true })
surface.CreateFont("GRMF4_Small",  { font = "Roboto", size = 12, weight = 400, extended = true })

local C = {
    bg    = Color(20, 24, 32, 252),
    head  = Color(28, 34, 46, 255),
    panel = Color(32, 38, 50, 245),
    panel2= Color(26, 32, 42, 245),
    acc   = Color(70, 150, 240),
    green = Color(60, 190, 110),
    red   = Color(220, 75, 70),
    yellow= Color(230, 180, 60),
    text  = Color(240, 245, 250),
    dim   = Color(160, 170, 185),
}

local function mkBtn(p, txt, col)
    local b = vgui.Create("DButton", p)
    b:SetText(txt) b:SetFont("GRMF4_Sub") b:SetTextColor(color_white)
    b.Paint = function(self, pw, ph)
        local cc = col or C.acc
        if not self:IsEnabled() then cc = Color(60, 65, 75)
        elseif self:IsHovered() then cc = Color(math.min(255, cc.r + 25), math.min(255, cc.g + 25), math.min(255, cc.b + 25)) end
        draw.RoundedBox(6, 0, 0, pw, ph, cc)
    end
    return b
end

local function block(parent, h, title)
    local b = vgui.Create("DPanel", parent)
    b:Dock(TOP) b:SetTall(h) b:DockMargin(0, 0, 0, 6)
    b.Paint = function(_, pw, ph)
        draw.RoundedBox(6, 0, 0, pw, ph, C.panel)
        draw.SimpleText(title, "GRMF4_Sub", 10, 14, C.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    return b
end

local function infoRow(parent, label, value, col)
    local r = vgui.Create("DPanel", parent)
    r:Dock(TOP) r:SetTall(24) r:DockMargin(10, 2, 10, 0)
    r.Paint = function(_, pw, ph)
        draw.SimpleText(label, "GRMF4_Normal", 4, ph / 2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText(value, "GRMF4_Sub", pw - 4, ph / 2, col or C.text, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
    return r
end

-----------------------------------------------------------
-- Справочник команд
-----------------------------------------------------------
local CMD_GROUPS = {
    { name = "Персонаж", items = {
        { "/char, /chars", "Меню персонажа (внешность, имя)" },
        { "/name Имя Фамилия", "Сменить игровое (RP) имя" },
        { "/rpdesc", "Редактировать описание персонажа" },
        { "/mask, /maskcfg", "Маскировка (по доступу)" },
        { "/model", "Выбор модели из разрешённых" },
        { "/wardrobe_add", "Поставить гардероб (суперадмин)" },
    }},
    { name = "RP-чат", items = {
        { "/me текст", "Действие от лица персонажа" },
        { "/do текст", "Событие вокруг персонажа" },
        { "/it текст", "Предмет/объект рядом" },
        { "/try текст", "Попытка действия (удача/неудача)" },
        { "/roll", "Случайное число 0–100" },
        { "/dice XdY", "Бросить кости (например 2d6)" },
        { "/w текст", "Шёпот (ближний радиус)" },
        { "/y текст", "Крик (дальний радиус)" },
        { "/looc текст", "Локальный Out-Of-Character чат" },
        { "/ooc текст", "Глобальный Out-Of-Character чат" },
    }},
    { name = "Фракции", items = {
        { "/fjoin Имя", "Вступить во фракцию (по приглашению)" },
        { "/fleave", "Покинуть фракцию" },
        { "/fr текст", "Рация фракции" },
        { "/dep, /depb", "Волна/муляж подкрепления" },
        { "/factions", "Меню фракций (руководство/админ)" },
        { "/gnews текст", "Гос. новости (по доступу)" },
        { "/kom_hour, off", "Комендантский час (по доступу)" },
        { "/wanted_set, /wanted_clear", "Подать/снять розыск (глядя на игрока; по правам)" },
        { "/warrant, /unwarrant", "Ордер на обыск игрока (по правам)" },
    }},
    { name = "Деньги", items = {
        { "!fbudget", "Бюджет своей фракции" },
        { "!fpay, !fwithdraw", "Взнос/вывод из бюджета (по правам)" },
        { "!fpayall", "Выплатить ЗП всем (лидер)" },
        { "!fsettax N", "Ставка налога фракции (лидер)" },
        { "/mysalary", "Информация о своей ЗП" },
        { "/fine сумма [причина]", "Оштрафовать нарушителя (по правам фракции): цель под прицелом ИЛИ по нику (/fine 500 Ник)" },
        { "/fines", "Статус штрафов: права, лимит, кого можно штрафовать + последние 5 штрафов фракции" },
        { "/dropmoney сумма", "Бросить наличные на землю пачкой (модель cs_assault/money): E — подобрать в кошелёк, живёт 10 мин" },
        { "C-меню (зажать C)", "«Выбросить деньги…» и «Передать деньги: Имя» — бережные диалоги, передача тому, кто в прицеле (≤3 м)" },
        { "/money_pack сумма", "Упаковать наличные в инвентарь (предмет «Деньги»): для багажника/склада; использование предмета — обналичить обратно" },
        { "Банкомат (E)", "Счёт, переводы, бюджет фракции" },
    }},
    { name = "Двери и имущество", items = {
        { "/door", "Меню двери (аренда, совладельцы, доступы)" },
        { "/lock /unlock", "Замок двери в прицеле" },
        { "/drop", "Выбросить активное оружие/предмет" },
        { "/inv", "Инвентарь" },
        { "/store", "Меню склада фракции (у точки)" },
    }},
    { name = "Транспорт", items = {
        { "/vshop", "Магазин транспорта" },
        { "/vlist, /myvehicles", "Доступный/мой транспорт" },
        { "Ключи от машины", "ЛКМ/ПКМ — замок авто; машина из дилера закрыта сразу, ключ у владельца" },
        { "C по машине (зажать)", "Контекст Т/С: замок, багажник, сдать своё Т/С (двойное нажатие-подтверждение, на кнопке сумма возврата). Админ — убрать любое дилерское" },
        { "Дилер (E)", "«Каталог»: превью, цены, баланс, двойной клик = купить. «Мой транспорт»: гараж — сдача удалённо (стоя у дилера) поштучно/всё разом, возврат 50%, статус замка и дистанция" },
        { "/vd_remove", "Убрать ВЕСЬ свой транспорт дилера разом (возврат 50% суммарно)" },
        { "/trunk, /багажник", "Багажник ЛЮБОГО транспорта: глядя на машину открыть/закрыть. ЛКМ по слоту — переложить стак (макс 999), SHIFT+ЛКМ — 1 шт. Чужая машина — только пока разблокирована (риск кражи). На ходу крышка захлопывается." },
        { "/logistics_start", "Логистика: начать рейс — при отказе пишет ТОЧНУЮ причину (доступ фракции / Т/С не из списка / нет точек)" },
        { "grm_logistics_debug", "Консоль: полная диагностика логистики (фракция, доступ, текущая сущность/Т/С) — суперадмин" },
        { "grm_logistics_place_loading / _place_warehouse", "Консоль: поставить точку погрузки / склад (суперадмин) — без них меню рейса пустое" },
        { "/logistics_crates", "Логистика: инвентарь ящиков фракции" },
    }},
    { name = "Телефон", items = {
        { "/phoneshop", "Магазин телефонов/АТС (по доступу). Вкладка «Мобильные»: 7 трубок GTA IV 700–14000, кладутся в инвентарь" },
        { "СТРЕЛКА ВВЕРХ", "Открыть мобильный (телефон в инвентаре). ↑↓ — навигация, ENTER — открыть/ответить, BACKSPACE — назад/трубка, цифры — набор, E — продиктовать номер в локальный чат (те, кто рядом, запишут). Запасной путь: консоль grm_mobile_open" },
        { "Приложения", "Телефон, SMS, Контакты, Заметки, Калькулятор; на старших трубках (Tinkle/Whiz): Биржа труда, Моя фракция, Форум" },
        { "Сигнал", "Связь по покрытию радиосети (Коды 85/87). Дешёвые трубки глохнут на окраинах — в дорогих приёмник лучше" },
        { "/phone_remove", "Снять свой телефон из прицела" },
    }},
    { name = "Медицина", items = {
        { "/medcards", "Медицинские карты: у медика — поиск пациентов, редактор карт; у прочих — своя карта" },
        { "/mycard", "Сразу своя мед.карта (кратко)" },
        { "Карта пациента", "Диагнозы (активные/снятые), записи приёмов, назначения, операции, показания (кровь/аллергии/хроника)" },
        { "«Доступ» (суперадмин)", "В окне /medcards: вкл/выкл медицинские фракции + ограничение по рангам и отделам фракции" },
    }},
    { name = "Радио и оповещение", items = {
        { "E по микрофону", "Пульт эфира: позывной, старт/стоп (СМИ), режим ГРОМКАЯ СВЯЗЬ (оповестители)" },
        { "E по приёмнику", "Настроить радио на станцию / выключить (решает покрытие сети!)" },
        { "Мегафон (SWEP)", "weapon_grm_megaphone: ЛКМ вкл — голос ×4.5 дальности с треском рупора" },
        { "E по стойке", "Питание серверной стойки — сердце радиосети (антенны/громкоговорители без неё мертвы)" },
        { "/alert текст", "Оповещение района (только СЕТЕВЫЕ громкоговорители)" },
        { "/alertall текст", "Оповещение всех игроков города" },
        { "/rn_status", "Диагностика радиосети: стойки/антенны/покрытие/громкоговорители в сети (суперадмин)" },
        { "/radiomic_add", "Микрофонная стойка (суперадмин)" },
        { "/radio_add", "Радиоприёмник (суперадмин)" },
        { "/speaker_add", "Громкоговоритель района (суперадмин)" },
        { "/rack_add /antenna_add /rstation_add", "Стойка / антенна-усилитель / радиопередатчик (суперадмин, автоперсистент)" },
        { "/console_add", "Пульт радиосети (компьютер) — работает у АКТИВНОЙ стойки; E — открыть (суперадмин)" },
        { "Пульт (E) → Устройства", "Позывные железок (SPK-001…), точечное вкл/выкл вывода, ПКМ — группы; у микрофона — цель ГРОМКОЙ СВЯЗИ" },
        { "Пульт (E) → Оповещение", "/alert на группу громкоговорителей или на весь город; журнал с пеленгом — кто/что/откуда/качество" },
        { "/rn_log", "Журнал радиосети в чат: последние 12 событий (передачи, оповещения, переключения)" },
    }},
    { name = "Доска объявлений", items = {
        { "E по доске", "Наборы фракций: вступить / управление / журнал" },
        { "E → «Управление» (лидер)", "Открыть/закрыть набор, журнал вступивших, «Отдел/должность» — КУДА именно зачислять вступающих автоматически" },
        { "/board_add", "Поставить доску набора (суперадмин)" },
    }},
    { name = "Биржа труда", items = {
        { "E по терминалу", "Вакансии биржи (курьер/патруль/грузчик/инспектор), заказы и ВАКАНСИИ фракций (зарплата×смены из бюджета)" },
        { "/jobs", "Статус текущей задачи (также вкладка F4 → «Работа»)" },
        { "/jobcancel", "Отказаться от текущей задачи" },
        { "/jobpost", "Лидер: форма заказа/вакансии с любого места — зона смены ловится там, где стоите (станок завода и т.п.)" },
        { "Вкладка F4 → «Работа»", "Живая карточка задачи, счётчик выполненных" },
        { "/jobcenter_add", "Терминал биржи (суперадмин, автосохранение)" },
        { "/jobdepot_add", "Точка доставки/дежурства (суперадмин)" },
    }},
    { name = "Ачивки и бонусы", items = {
        { "Вкладка F4 → «Ачивки»", "Все достижения, прогресс-бары, награды" },
        { "/ach", "Краткая сводка достижений в чат" },
        { "Ежедневный бонус", "Автоначисление за вход; стрик дней растит сумму (макс. 2 000)" },
        { "★ за задачи/эфиры/деньги", "Достижения открываются сами — награда сразу на счёт" },
    }},
    { name = "Админ-доступы", items = {
        { "/grm_admin", "ЕДИНАЯ админ-панель: сервер, все доступы, биржа, игроки, ярлыки меню (суперадмин)" },
        { "/factions → «Доступы»", "Чекбоксы: доска / эфир / оповещение / биржа по фракциям" },
        { "/bcast_allow Имя", "Выдать фракции доступ к эфиру" },
        { "/alert_allow Имя", "Выдать фракции право оповещать" },
        { "/board_allow Имя", "Выдать фракции доступ к доске набора" },
        { "/job_allow Имя", "Доступ работодателя: заказы/вакансии с эскроу бюджета" },
    }},
    { name = "Админ-панели (суперадмин)", items = {
        { "/grm_admin", "ЕДИНАЯ панель: сервер/доступы/ЭКОНОМИКА (гос.бюджет, бюджеты фракций, наличные игроков)/ИНСТРУМЕНТЫ (Q-меню и toolgun игроков)/биржа/игроки/меню" },
        { "/grm_admin → «Инструменты»", "Q-меню игрокам вкл/выкл + GRM-стройка (свой каталог одобренных пропов и инструментов вместо ванильного spawnmenu), спавн (пропы/NPC/SENT/SWEP/транспорт), чёрный список toolgun-инструментов или строгий белый режим" },
        { "Q (стройка)", "playersQ=false: бинд глушится, вместо ванилы — «GRM Стройка»: каталог пропов (админский список), выдача разрешённого тулгана, уборка своих пропов" },
        { "/qm_prop_add", "Добавить проп в каталог стройки глядя на него (или /qm_prop_addmodel models/....mdl) — суперадмин" },
        { "/qm_prop_del, /qm_prop_list", "Убрать проп из каталога (прицел) / показать каталог — суперадмин" },
        { "Защита владельца (Root)", "Удаление фракций суперадмином НЕ-root — в очередь к владельцу: окно одобрить/отклонить; корневой SteamID зашит в коде" },
        { "/root_list, /root_queue", "Только владелец: список корней / очередь заявок на подтверждение" },
        { "/root_add, /root_del STEAM_", "Только владелец: добавить/убрать доп. корневой SteamID" },
        { "/feco_admin", "Экономика: фракции, ЗП и налоги, гос.бюджет, балансы налички/банка, общие настройки" },
        { "/factions", "Фракции: руководство/состав/доступы/расширенные настройки/экономика" },
        { "/door_access", "Матрица доступа к дверям/категориям по фракциям" },
        { "/models_admin, /weapons_admin, /mask_admin", "Модели, оружие и маскировка фракций" },
        { "/logistics_admin", "Логистика: доступ по фракциям и матовозки" },
        { "/vshop_admin, /phoneshop_admin, /phone_access", "Магазины транспорта/телефонов и их доступы" },
        { "/warrants, /wanted_access", "Ордера и настройка прав розыска" },
        { "/scanvehicles", "Аудит техники на карте (владельцы/дубликаты)" },
        { "/permadd, /permlist, /permremove", "Классы прав (пермы) модулей" },
        { "/saveentities, /loadentities", "Сохранение/загрузка расставленных энтити карты" },
        { "/grm_vending_save/load/clear", "Торговые автоматы еды: сохранить/загрузить/снести" },
        { "Спавн энтити", "/wardrobe_add /board_add /radiomic_add /radio_add /speaker_add /jobcenter_add /jobdepot_add (группы выше)" },
        { "/dbcheck", "Сверка налички и экономики с базой данных" },
    }},
    { name = "Законы", items = {
        { "/law_list", "Просмотр действующих законов" },
        { "/law_add текст", "Добавить закон (суперадмин или фракция с доступом)" },
        { "/law_remove <ID>", "Удалить закон (суперадмин или фракция с доступом)" },
        { "C-меню → Законы", "Просмотр законов государства" },
    }},
}

-----------------------------------------------------------
-- Вкладка «Профиль»
-----------------------------------------------------------
local function buildProfileTab(sc, refresh)
    local lp = LocalPlayer()

    local b1 = block(sc, 116, "Игровое имя (RP Name):")
    local cur = lp:GetNWString("GRM_RPName", "")
    local nm = vgui.Create("DTextEntry", b1)
    nm:SetPos(10, 32) nm:SetSize(320, 30) nm:SetFont("GRMF4_Sub")
    nm:SetPlaceholderText("Имя Фамилия")
    nm:SetText(cur ~= "" and cur or "")

    local hint = vgui.Create("DLabel", b1)
    hint:SetPos(10, 88) hint:SetSize(700, 20) hint:SetFont("GRMF4_Normal") hint:SetTextColor(C.dim)
    hint:SetText("Виден над головой и в документах. Также команда: /name Имя Фамилия")

    local bSaveName = mkBtn(b1, "Сохранить имя", C.green)
    bSaveName:SetPos(340, 32) bSaveName:SetSize(170, 30)
    bSaveName.DoClick = function()
        local v = string.Trim(nm:GetValue() or "")
        if #v < 3 then
            Derma_Message("Имя короче 3 символов.", "F4", "Ок")
            return
        end
        net.Start("GRM_Char_Save")
            net.WriteTable({ name = v })
        net.SendToServer()
        timer.Simple(0.5, function() if IsValid(sc) then refresh() end end)
    end

    local b2 = block(sc, 96, "Персонаж:")
    local bChar = mkBtn(b2, "Меню персонажа (внешность)", C.acc)
    bChar:SetPos(10, 30) bChar:SetSize(250, 30)
    bChar.DoClick = function() if GRM.Char and GRM.Char.OpenMenu then GRM.Char.OpenMenu() end end
    local bDesc = mkBtn(b2, "Описание (RPDesc)", C.acc)
    bDesc:SetPos(10, 64) bDesc:SetSize(250, 30)
    bDesc.DoClick = function() if GRM.RPDesc and GRM.RPDesc.OpenEditor then GRM.RPDesc.OpenEditor() end end
    local descNow = (GRM.RPDesc and GRM.RPDesc.Get(lp)) or ""
    if #descNow > 60 then descNow = string.sub(descNow, 1, 60) .. "…" end
    local descLbl = vgui.Create("DLabel", b2)
    descLbl:SetPos(270, 56) descLbl:SetSize(600, 26)
    descLbl:SetFont("GRMF4_Normal") descLbl:SetTextColor(C.dim)
    descLbl:SetText("Описание сейчас: " .. (descNow ~= "" and descNow or "не задано"))

    local b3 = block(sc, 110, "Карточка:")
    infoRow(b3, "Steam-ник:", lp:Nick())
    infoRow(b3, "SteamID64:", lp:SteamID64())
    infoRow(b3, "RP-имя:", cur ~= "" and cur or "(не задано)")
    infoRow(b3, "Баланс наличных:", (GRM.Format and GRM.Format(GRM.LocalBalance or 0)) or tostring(GRM.LocalBalance or 0))

    local fac = "—"
    if istable(FactionsData) then
        for fname, fd in pairs(FactionsData) do
            if istable(fd) and istable(fd.Members) and (fd.Members[lp:SteamID()] or fd.Members[lp:SteamID64()]) then
                fac = fname break
            end
        end
    end
    infoRow(b3, "Фракция:", fac)
end

-----------------------------------------------------------
-- Вкладка «Команды»
-----------------------------------------------------------
local function buildCommandsTab(sc)
    for _, grp in ipairs(CMD_GROUPS) do
        local n = #grp.items
        local b = block(sc, 30 + n * 24 + 8, grp.name .. ":")
        for i, it in ipairs(grp.items) do
            local r = vgui.Create("DPanel", b)
            r:SetPos(10, 26 + (i - 1) * 24) r:SetSize(760, 22)
            r.Paint = function(_, pw, ph)
                draw.RoundedBox(3, 0, 0, 200, ph - 2, C.panel2)
                draw.SimpleText(it[1], "GRMF4_Small", 6, (ph - 2) / 2, C.acc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(it[2], "GRMF4_Normal", 210, ph / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
    end
end

-----------------------------------------------------------
-- Вкладка «Настройки»
-----------------------------------------------------------
local function buildSettingsTab(sc)
    local b = block(sc, 300, "Отображение HUD (только для вас):")

    local function toggle(y, cvar, label)
        local cv = GetConVar(cvar)
        local chk = vgui.Create("DCheckBoxLabel", b)
        chk:SetPos(14, y) chk:SetSize(500, 24)
        chk:SetText(label) chk:SetFont("GRMF4_Normal") chk:SetTextColor(C.text)
        chk:SetValue((not cv or cv:GetInt() ~= 0) and 1 or 0)
        chk.OnChange = function(_, v)
            RunConsoleCommand(cvar, v and "1" or "0")
        end
        return chk
    end

    toggle(30,  "grm_cl_rpdesc",     "Имена и описания персонажей над головами (RPDesc)")
    toggle(58,  "grm_cl_doorhud",    "3D2D-таблички дверей (владелец/замок)")
    toggle(86,  "grm_cl_staminahud", "Полоса выносливости (стамина)")
    toggle(114, "grm_cl_foodhud",    "Полоса сытости (еда)")

    local lbl = vgui.Create("DLabel", b)
    lbl:SetPos(14, 146) lbl:SetSize(300, 22) lbl:SetFont("GRMF4_Sub") lbl:SetTextColor(C.text)
    lbl:SetText("Дистанция отрисовки имён и описаний (юниты)")

    local sl = vgui.Create("DNumSlider", b)
    sl:SetPos(10, 168) sl:SetSize(420, 30)
    sl:SetMin(50) sl:SetMax(1000) sl:SetDecimals(0)
    sl:SetConVar("grm_cl_rpdesc_dist")

    local note = vgui.Create("DLabel", b)
    note:SetPos(14, 206) note:SetSize(700, 40)
    note:SetFont("GRMF4_Normal") note:SetTextColor(C.dim)
    note:SetText("Стандарт RPDesc — 200 юнитов (~5 метров). Настройки хранятся на вашем ПК (garrysmod/cfg).")
    note:SetWrap(true) note:SetAutoStretchVertical(true)
end

-----------------------------------------------------------
-- Вкладка «Графика» (удобная базовая настройка без стандартного меню)
-----------------------------------------------------------
local GFX_PRESET_LOW = {
    { "r_shadows", "0" }, { "r_dynamic", "0" }, { "mat_specular", "0" },
    { "r_waterforceexpensive", "0" }, { "r_WaterDrawReflection", "0" }, { "r_WaterDrawRefraction", "0" },
    { "r_DrawDetailProps", "0" }, { "cl_detaildist", "450" }, { "r_staticprop_lod", "3" },
    { "mat_picmip", "2" }, { "mp_decals", "50" }, { "mat_motion_blur_enabled", "0" },
    { "gmod_mcore_test", "1" }, { "r_drawskybox", "1" },
}
local GFX_PRESET_HIGH = {
    { "r_shadows", "1" }, { "r_dynamic", "1" }, { "mat_specular", "1" },
    { "r_waterforceexpensive", "1" }, { "r_WaterDrawReflection", "1" }, { "r_WaterDrawRefraction", "1" },
    { "r_DrawDetailProps", "1" }, { "cl_detaildist", "1500" }, { "r_staticprop_lod", "-1" },
    { "mat_picmip", "0" }, { "mp_decals", "2048" }, { "mat_motion_blur_enabled", "0" },
    { "gmod_mcore_test", "1" }, { "r_drawskybox", "1" },
}

local GFX_TOGGLES = {
    { { "r_shadows" },            "Динамические тени (дорогие для FPS)" },
    { { "r_dynamic" },            "Динамическое освещение (фонарики, лампы)" },
    { { "mat_specular" },         "Блики и отсветы на поверхностях" },
    { { "r_WaterDrawReflection", "r_WaterDrawRefraction" }, "Отражения и преломление воды" },
    { { "r_waterforceexpensive" },"Дорогая (реалистичная) вода" },
    { { "r_DrawDetailProps" },    "Трава и мелкие детали ландшафта" },
    { { "r_drawskybox" },         "3D-небо (skybox)" },
    { { "mat_motion_blur_enabled" },"Размытие в движении (motion blur)" },
    { { "muzzleflash_light" },      "Вспышки выстрелов (динамический свет)" },
    { { "gmod_mcore_test" },      "Многоядерный рендер (обычно +FPS)" },
}

local GFX_SLIDERS = {
    { "cl_detaildist",    "Дальность отрисовки мелких объектов (трава/детали)", 400, 4096 },
    { "r_staticprop_lod", "Дальность/детализация крупных объектов (LOD: -1 максимум, 3 минимум)", -1, 3 },
    { "mat_picmip",       "Качество текстур (0 — максимум, 4 — минимум)", 0, 4 },
    { "mp_decals",        "Декали — следы выстрелов и крови (шт.)", 0, 2048 },
}

local function buildGraphicsTab(sc, refresh)
    -- пресеты
    local b0 = block(sc, 76, "Быстрые пресеты:")
    local function applyPreset(list, name)
        for _, kv in ipairs(list) do RunConsoleCommand(kv[1], kv[2]) end
        timer.Simple(0.1, function() if refresh then refresh() end end)
        notification.AddLegacy("Пресет графики «" .. name .. "» применён.", NOTIFY_GENERIC, 3)
    end
    local bLow = mkBtn(b0, "FPS+ (низкая графика)", C.green)
    bLow:SetPos(10, 30) bLow:SetSize(250, 32)
    bLow.DoClick = function() applyPreset(GFX_PRESET_LOW, "FPS+") end
    local bHigh = mkBtn(b0, "Красота (высокая графика)", C.acc)
    bHigh:SetPos(270, 30) bHigh:SetSize(250, 32)
    bHigh.DoClick = function() applyPreset(GFX_PRESET_HIGH, "Красота") end

    -- выключатели эффектов
    local b1 = block(sc, 28 + #GFX_TOGGLES * 26 + 8, "Эффекты и качество:")
    for i, t in ipairs(GFX_TOGGLES) do
        local cvars, label = t[1], t[2]
        local cv = GetConVar(cvars[1])
        local y = 26 + (i - 1) * 26
        if not cv then
            local off = vgui.Create("DLabel", b1)
            off:SetPos(14, y) off:SetSize(600, 24) off:SetFont("GRMF4_Normal") off:SetTextColor(C.dim)
            off:SetText(label .. " — недоступно")
        else
            local chk = vgui.Create("DCheckBoxLabel", b1)
            chk:SetPos(14, y) chk:SetSize(600, 24)
            chk:SetText(label) chk:SetFont("GRMF4_Normal") chk:SetTextColor(C.text)
            chk:SetValue(cv:GetInt() ~= 0 and 1 or 0)
            chk.OnChange = function(_, v)
                for _, cn in ipairs(cvars) do RunConsoleCommand(cn, v and "1" or "0") end
            end
        end
    end

    -- слайдеры дальности/качества
    local b2 = block(sc, 28 + #GFX_SLIDERS * 50 + 8, "Дальность отрисовки и качество:")
    for i, s in ipairs(GFX_SLIDERS) do
        local cvar, label, mn, mx = s[1], s[2], s[3], s[4]
        local y = 26 + (i - 1) * 50
        local lbl = vgui.Create("DLabel", b2)
        lbl:SetPos(14, y) lbl:SetSize(720, 18) lbl:SetFont("GRMF4_Normal") lbl:SetTextColor(C.text)
        lbl:SetText(label)
        local sl = vgui.Create("DNumSlider", b2)
        sl:SetPos(10, y + 18) sl:SetSize(560, 28)
        sl:SetMin(mn) sl:SetMax(mx) sl:SetDecimals(0)
        if GetConVar(cvar) then
            sl:SetConVar(cvar)
        else
            sl:SetEnabled(false)
            lbl:SetText(label .. " — недоступно")
            lbl:SetTextColor(C.dim)
        end
    end

    local b3 = block(sc, 78, "Примечание:")
    local note = vgui.Create("DLabel", b3)
    note:SetPos(14, 28) note:SetSize(720, 44)
    note:SetFont("GRMF4_Normal") note:SetTextColor(C.dim)
    note:SetText("Качество текстур и LOD полностью применятся после перезахода на сервер. Значения сохраняются на вашем ПК. Лимит FPS (fps_max) движком запрещён к смене из скриптов — задайте его в консоли вручную при желании.")
    note:SetWrap(true) note:SetAutoStretchVertical(true)
end

-----------------------------------------------------------
-- Главное окно
-----------------------------------------------------------
local function buildMenu()
    if IsValid(F4._frame) then F4._frame:Remove() end

    local f = vgui.Create("DFrame")
    F4._frame = f
    f:SetTitle("")
    f:SetSize(880, 640)
    f:Center()
    f:MakePopup()
    f:ShowCloseButton(false)
    f.Paint = function(_, pw, ph)
        draw.RoundedBox(8, 0, 0, pw, ph, C.bg)
        draw.RoundedBoxEx(8, 0, 0, pw, 46, C.head, true, true, false, false)
        draw.SimpleText("GRM — Игровое меню", "GRMF4_Title", 16, 23, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("F4 / /menu", "GRMF4_Normal", pw - 16, 23, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end

    local x = vgui.Create("DButton", f)
    x:SetText("X") x:SetFont("GRMF4_Title") x:SetTextColor(color_white)
    x:SetPos(836, 8) x:SetSize(32, 28)
    x.DoClick = function() f:Close() end
    x.Paint = function(self, pw, ph) draw.RoundedBox(4, 0, 0, pw, ph, self:IsHovered() and C.red or Color(45, 52, 68)) end

    local sheet = vgui.Create("DPropertySheet", f)
    sheet:Dock(FILL)
    sheet:DockMargin(10, 52, 10, 10)

    -- Профиль (пересобирается для мгновенного обновления значений)
    local p1 = vgui.Create("DPanel")
    p1:SetPaintBackground(false)
    local sc1 = vgui.Create("DScrollPanel", p1)
    sc1:Dock(FILL)
    local function refreshProfile()
        if not IsValid(sc1) then return end
        sc1:Clear()
        buildProfileTab(sc1, refreshProfile)
    end
    refreshProfile()
    sheet:AddSheet("Профиль", p1, "icon16/user.png")

    local p2 = vgui.Create("DPanel")
    p2:SetPaintBackground(false)
    local sc2 = vgui.Create("DScrollPanel", p2)
    sc2:Dock(FILL)
    buildCommandsTab(sc2)
    sheet:AddSheet("Команды", p2, "icon16/book_open.png")

    local p3 = vgui.Create("DPanel")
    p3:SetPaintBackground(false)
    local sc3 = vgui.Create("DScrollPanel", p3)
    sc3:Dock(FILL)
    buildSettingsTab(sc3)
    sheet:AddSheet("Настройки", p3, "icon16/cog.png")

    -- Графика (пересобирается для мгновенного обновления значений)
    local p4 = vgui.Create("DPanel")
    p4:SetPaintBackground(false)
    local sc4 = vgui.Create("DScrollPanel", p4)
    sc4:Dock(FILL)
    local function refreshGfx()
        if not IsValid(sc4) then return end
        sc4:Clear()
        buildGraphicsTab(sc4, refreshGfx)
    end
    refreshGfx()
    sheet:AddSheet("Графика", p4, "icon16/monitor.png")

    -- вкладки модулей сборки (Код 77 «Работа», Код 78 «Ачивки» и др.)
    pcall(function() hook.Call("GRM_F4_BuildTabs", nil, sheet) end)
end

function F4.Open()
    buildMenu()
end

function F4.Close()
    if IsValid(F4._frame) then F4._frame:Remove() end
end

function F4.Toggle()
    if IsValid(F4._frame) then F4.Close() else F4.Open() end
end

concommand.Add("grm_f4", F4.Open)

-- уступаем прицелу на дверь (двери открывают своё меню) — общий предикат
local function yieldsToDoor(ply)
    if not IsValid(ply) then return false end
    if not (GRM and GRM.Doors and GRM.Doors.IsDoor) then return false end
    local tr = ply:GetEyeTrace()
    if not (tr and IsValid(tr.Entity)) then return false end
    if not GRM.Doors.IsDoor(tr.Entity) then return false end
    local maxD = (GRM.Doors.Config and GRM.Doors.Config.UseDistance) or 180
    return tr.StartPos:DistToSqr(tr.HitPos) <= maxD * maxD
end

-- анти-дубль: два канала (бинд и опрос) могут увидеть одно нажатие
local function keyPressHandled()
    local now = CurTime()
    if (F4._keyTs or 0) + 0.25 > now then return true end
    F4._keyTs = now
    return false
end

-- Канал 1: стандартный бинд gm_showspare2 (F4)
hook.Add("ShowSpare2", "GRM_F4_Open", function(ply)
    if not IsValid(ply) or ply ~= LocalPlayer() then return end
    if yieldsToDoor(ply) then return end
    if keyPressHandled() then return true end
    F4.Toggle()
    return true
end)

-- Канал 2: резервный прямой опрос клавиши (если бинд съеден/переопределён)
local f4WasDown = false
hook.Add("Think", "GRM_F4_KeyPoll", function()
    local down = input.IsKeyDown(KEY_F4)
    if down == f4WasDown then return end
    f4WasDown = down
    if not down then return end -- срабатываем на ФРОНТ нажатия, не на удержание
    -- не лезем, когда идёт набор текста, консоль или ESC-меню
    if IsValid(vgui.GetKeyboardFocus()) then return end
    if gui.IsConsoleVisible() then return end
    if gui.IsGameUIVisible() then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if lp.IsTyping and lp:IsTyping() then return end
    if yieldsToDoor(lp) then return end
    if keyPressHandled() then return end
    F4.Toggle()
end)

hook.Add("PlayerSayTransform", "GRM_F4_Chat", function(ply, datapack)
    if ply ~= LocalPlayer() then return end
    local msg = datapack and datapack[1]
    if not msg then return end
    local low = string.lower(string.Trim(msg))
    if low == "/menu" or low == "!menu" or low == "/f4" or low == "!f4" then
        F4.Open()
        datapack[1] = ""
    end
end)

print("[GRM F4] Игровое меню v" .. F4.Version .. " загружено")
