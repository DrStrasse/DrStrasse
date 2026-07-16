--[[--------------------------------------------------------------------
    GRM Unified Economy v2.3.9 (Код 43)

    v2.3.9 (репорт: «салари-лог переполняется»): общий фин.лог тонул в
    рутине — при 20 игроках онлайн зарплата каждые 10 минут писала
    ~120 записей/час, лимит 300 вымывал штрафы/переводы/админ-действия
    за пару часов. Теперь рутинные потоки («Зарплата...», «Сверка с
    базой...») в общий лог НЕ пишутся: зарплата остаётся в истории
    фракций и сводке госбюджета, сверка — в консоли сервера.

    v2.3.8 (репорт: «наличка не переживает рестарт, в json — []»):
    антисвайп-стражи: save() не затирает непустую базу пустой памятью;
    сверка не принимает файл без счетов/фракций поверх непустой памяти.
    Полный сброс — только удалением файла на выключенном сервере.

    v2.3.7 (аудит синхронизации HUD/Tab): канал банка GRM_Bank_Sync
    переведён с UInt(32) на Double — счета выше ~4.29 млрд прилетали
    в HUD битыми (переполнение). Оба конца канала меняются здесь же.

    v2.3.5/2.3.6: страж-синглтон; сохранение ≤8с гарантировано (файл
    пишется только при реальных изменениях); сверка с базой 15с +
    /dbcheck; защита от дедлока dirty.

    v2.3.4: сверка с базой grm_economy.json (счета/фракции/гос.бюджет):
            раз в 60с файл перечитывается, если менялся СНАРУЖИ —
            данные поднимаются из базы, счета онлайн-игроков улетают
            в HUD; свои несброшенные изменения сверка не трогает.

    v2.3.3 (заказ владельца): банковский счёт теперь синхронизируется
            в HUD (своя строка «НА СЧЁТУ»): каналы GRM_Bank_Sync/Request,
            пуш при входе и после каждой операции со счётом; быстрый
            сброс данных на диск каждые 5с (переживаем килл процесса).

    v2.3.2: починка вкладки «Фракции» — список/редактор теперь
            раскладываются по РЕАЛЬНЫМ размерам страницы (PerformLayout),
            а не по нулевым в момент создания (DPropertySheet растягивает
            только активную страницу); свой заметный крестик закрытия
            (движковый был невидим на тёмной шапке); единый тёмный фон
            всех вкладок админки и банкомата.

    v2.3.1: фикс краша админ-панели "Tried to use a NULL Panel!"
            (dframe.lua, SetPos) — buildAdminUI больше не зовёт
            adminFrame:Clear(), вычистка только своих панелей.

    ЕДИНЫЙ аддон экономики фракций — написан с нуля.
    ЗАМЕНЯЕТ собой два старых модуля:
      • sh_grm_faction_economy_plus.lua (Код 9) — зарплаты Plus;
      • sh_grm_faction_economy.lua      (Код 12) — базовые бюджеты.

    Что внутри (всё по экономической части):
      1) Бюджеты фракций (единый grm_economy.json, импорт двух старых
         файлов данных — ничего не теряется);
      2) Налоги фракций (ставка 0–50%, налог берётся с ЗАРПЛАТЫ;
         старый вариант Кода 12 — налог со ВСЕГО баланса раз в 300с —
         полностью убран: именно он и давал «двойное налогообложение»);
      3) Персональный налог: приоритет у GRM.GetPlayerTaxRate (Код 13);
      4) Зарплаты по ролям / отделам / базовая, из бюджета либо «воздушные»;
      5) ШТРАФЫ (/fine) — новая механика: деньги осуждённого уходят
         в бюджет фракции выписавшего штраф (либо сгорают, если выписал
         внефракционный суперадмин);
      6) Фракционные настройки: интервал ЗП, payFromBudget, ЗП по ролям
         и отделам — через объединённую админ-панель /salary_admin;
      7) Обратная совместимость API для Кода 13 и будущих модулей:
         GRM.FactionBudgetGet/Add/Set, GRM.FactionTaxGet/Set;
      8) Совместимость чат-команд: !fbudget !fpay !fwithdraw !fpayall
         !fsettax (+ слэш-варианты), /mysalary, /fine.

    Исправление бага старой панели: при сохранении окно админки больше
    НЕ переоткрывается — сервер отвечает свежими данными, а клиент
    обновляет поля НА МЕСТЕ.

    Зависит от: ядра валюты (Код 42: GiveMoney/TakeMoney/HasMoney/
    GetBalance/Format/Notify) и таблицы Factions (Код 10).
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Economy = GRM.Economy or {}
local E = GRM.Economy

-- ============================================================
-- КОНФИГ
-- ============================================================
E.Config = E.Config or {
    DefaultTaxRate     = 0.05,  -- 5%
    MaxTaxRate         = 0.5,   -- потолок 50%
    SalaryInterval     = 600,   -- секунд между выплатами (по умолчанию)
    MinSalaryInterval  = 60,
    HistorySize        = 50,    -- записей истории на фракцию
    PayFromBudget      = true,  -- ЗП из бюджета по умолчанию
    FineToBudget       = true,  -- штрафы → бюджет фракции штрафующего
    FineMaxAmount      = 100000,
    UseDistance        = 180,
    BankTerminalModel  = "models/starless/atm.mdl",
    TaxToState         = true,  -- налоги с ЗП → ГОС.БЮДЖЕТ (false → обратно в бюджет фракции)
    FinesToState       = true,  -- штрафы без фракции-получателя → гос.бюджет (false → сгорают)
    LogSize            = 300,   -- записей общего финансового лога сервера
}

local DATA_FILE  = "grm_economy.json"
local LEGACY_BUDGETS = "grm_faction_budgets.json"       -- Код 12
local LEGACY_PLUS    = "grm_faction_economy_plus.json"  -- Код 9

local NET_OPEN_ADMIN  = "GRM_Eco_AdminOpen"
local NET_ADMIN_DATA  = "GRM_Eco_AdminData"
local NET_ADMIN_ACT   = "GRM_Eco_AdminAction"
local NET_OPEN_BANK   = "GRM_Eco_OpenBank"
local NET_BANK_ACT    = "GRM_Eco_BankAction"
local NET_SYNC        = "GRM_Eco_Sync"
local NET_INFO        = "GRM_Eco_Info"

-- ============================================================
-- СЕРВЕР
-- ============================================================
if SERVER then
    -- GRM-FIX: страж-синглтон: вторая копия модуля пропускается,
    -- иначе две копии грызут один data-файл.
    if GRM._economyCoreActive then
        local src = (debug and debug.getinfo and debug.getinfo(1, "S") and debug.getinfo(1, "S").short_src) or "?"
        print("[GRM Economy][!] ВТОРАЯ копия sh_grm_economy.lua ПРОПУЩЕНА, путь: " .. tostring(src))
        print("[GRM Economy][!] Активен модуль v" .. tostring(GRM._economyCoreVer) ..
              ", путь: " .. tostring(GRM._economyCoreSrc) ..
              ". Оставьте ОДНУ (самую новую) копию, остальные удалите!")
        return
    end
    GRM._economyCoreActive = true
    GRM._economyCoreVer = "2.3.9"
    GRM._economyCoreSrc = (debug and debug.getinfo and debug.getinfo(1, "S") and debug.getinfo(1, "S").short_src) or "?"

    util.AddNetworkString(NET_OPEN_ADMIN)
    util.AddNetworkString(NET_ADMIN_DATA)
    util.AddNetworkString(NET_ADMIN_ACT)
    util.AddNetworkString(NET_OPEN_BANK)
    util.AddNetworkString(NET_BANK_ACT)
    util.AddNetworkString(NET_SYNC)
    util.AddNetworkString(NET_INFO)
    -- Синк банковского счёта в HUD (Код 48): строка «НА СЧЁТУ»
    util.AddNetworkString("GRM_Bank_Sync")
    util.AddNetworkString("GRM_Bank_Request")

    E.Data = E.Data or { version = 2, factions = {} }
    local dirty = false

    -- ── Хелперы уведомлений / инфо ──────────────────────────
    local function notify(ply, msg, r, g, b)
        if GRM.Notify then GRM.Notify(ply, msg, r or 100, g or 220, b or 100) return end
        net.Start(NET_INFO) net.WriteString(tostring(msg or "")) net.Send(ply)
    end

    local function money(n) return GRM.Format and GRM.Format(n) or (tostring(n) .. " GRM") end

    -- ── Доступ к фракциям (Код 10) ──────────────────────────
    local function factionOf(ply)
        if not Factions or not IsValid(ply) then return nil end
        local sid = ply:SteamID()
        for name, f in pairs(Factions) do
            if istable(f) and istable(f.Members) and f.Members[sid] then
                return name, f
            end
        end
        return nil
    end

    local function isLeaderOf(ply, f)
        return IsValid(ply) and istable(f) and tostring(f.Leader or "") == ply:SteamID()
    end

    local function onlineMembers(name, f)
        local out = {}
        f = f or (Factions and Factions[name])
        if not istable(f) or not istable(f.Members) then return out end
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and f.Members[p:SteamID()] then out[#out + 1] = p end
        end
        return out
    end

    -- ── Нормализация записи фракции ─────────────────────────
    local function entry(name)
        E.Data.factions[name] = E.Data.factions[name] or {}
        local e = E.Data.factions[name]
        e.budget              = math.max(0, math.floor(tonumber(e.budget) or 0))
        e.taxRate             = math.Clamp(tonumber(e.taxRate) or E.Config.DefaultTaxRate, 0, E.Config.MaxTaxRate)
        e.baseSalary          = math.max(0, math.floor(tonumber(e.baseSalary) or 0))
        e.salaryInterval      = math.max(E.Config.MinSalaryInterval, math.floor(tonumber(e.salaryInterval) or E.Config.SalaryInterval))
        e.payFromBudget       = e.payFromBudget ~= false
        e.roleSalaries        = istable(e.roleSalaries) and e.roleSalaries or {}
        e.departmentSalaries  = istable(e.departmentSalaries) and e.departmentSalaries or {}
        e.history             = istable(e.history) and e.history or {}
        e.nextPay             = tonumber(e.nextPay) or (os.time() + e.salaryInterval)
        -- Права фракции на систему штрафов (настраивает superadmin).
        -- По умолчанию доступ ВЫКЛЮЧЕН: его выдают точечно фракциям.
        local fp = istable(e.finePerms) and e.finePerms or {}
        e.finePerms = fp
        fp.enabled        = fp.enabled == true     -- фракция может штрафовать вообще
        fp.allRoles       = fp.allRoles == true    -- штрафовать могут все члены
        fp.roles          = istable(fp.roles) and fp.roles or {} -- разрешённые роли
        fp.ownFaction     = fp.ownFaction ~= false -- цели: свои члены фракции
        fp.otherFactions  = fp.otherFactions == true -- цели: другие фракции
        fp.civilians      = fp.civilians ~= false  -- цели: граждане (без фракции)
        fp.maxAmount      = math.max(0, math.floor(tonumber(fp.maxAmount) or 0)) -- лимит (0 = общий)
        return e
    end

    local function addHistory(name, text)
        local h = entry(name).history
        h[#h + 1] = { t = os.time(), s = tostring(text) }
        while #h > E.Config.HistorySize do table.remove(h, 1) end
        dirty = true
    end

    -- ── Сохранение / загрузка / импорт легаси ───────────────
    -- Текст файла, который мы последний раз читали/писали — сверка с базой
    local lastDiskTxt = nil

    local function save(force)
        if not dirty and not force then return end
        -- GRM-FIX v2.3.8: антисвайп-страж. Пустые счета+фракции НИКОГДА не
        -- перезаписывают базу, где они были (после битой загрузки/чужой
        -- записи в файл). Полный сброс — удалением файла на выкл. сервере.
        local myAcc = istable(E.Data.accounts) and next(E.Data.accounts) ~= nil
        local myFac = istable(E.Data.factions) and next(E.Data.factions) ~= nil
        if not myAcc and not myFac then
            local prev = lastDiskTxt
            if (not isstring(prev)) and file.Exists(DATA_FILE, "DATA") then
                prev = file.Read(DATA_FILE, "DATA")
            end
            if isstring(prev) and #prev > 0 then
                local okP, dt = pcall(util.JSONToTable, prev)
                if okP and istable(dt) then
                    local hadAcc = istable(dt.accounts) and next(dt.accounts) ~= nil
                    local hadFac = istable(dt.factions) and next(dt.factions) ~= nil
                    if hadAcc or hadFac then
                        print("[GRM Economy] SAVE ОТКЛОНЁН: память пуста, а в базе есть счета/фракции — базу НЕ затираем (антисвайп-страж v2.3.8)")
                        dirty = false
                        return
                    end
                end
            end
        end
        local txt = util.TableToJSON(E.Data, true) or "{}"
        if txt == lastDiskTxt then dirty = false return end -- без изменений: диск не долбим
        file.Write(DATA_FILE, txt)
        lastDiskTxt = txt
        dirty = false
    end

    local function tryJSON(fname)
        if not file.Exists(fname, "DATA") then return nil end
        local ok, t = pcall(util.JSONToTable, file.Read(fname, "DATA") or "")
        return (ok and istable(t)) and t or nil
    end

    local function importLegacy()
        local imported = 0
        -- Код 12: grm_faction_budgets.json = { [name] = { budget, taxRate } }
        local b12 = tryJSON(LEGACY_BUDGETS)
        if b12 then
            local map = b12.factions or b12
            for name, rec in pairs(map) do
                if istable(rec) then
                    local e = entry(name)
                    if (tonumber(rec.budget) or 0) > e.budget then
                        e.budget = math.floor(tonumber(rec.budget))
                    end
                    if rec.taxRate ~= nil then e.taxRate = math.Clamp(tonumber(rec.taxRate) or 0.05, 0, E.Config.MaxTaxRate) end
                    imported = imported + 1
                end
            end
        end
        -- Код 9: grm_faction_economy_plus.json = { [name] = { budget, taxRate, baseSalary, ... } }
        local p9 = tryJSON(LEGACY_PLUS)
        if p9 then
            local map = p9.factions or p9
            for name, rec in pairs(map) do
                if istable(rec) and not rec.factions then
                    local e = entry(name)
                    if (tonumber(rec.budget) or 0) > e.budget then
                        e.budget = math.floor(tonumber(rec.budget))
                    end
                    if rec.taxRate ~= nil then e.taxRate = math.Clamp(tonumber(rec.taxRate) or 0.05, 0, E.Config.MaxTaxRate) end
                    e.baseSalary = math.max(e.baseSalary, math.floor(tonumber(rec.baseSalary) or 0))
                    if istable(rec.roleSalaries) then for k, v in pairs(rec.roleSalaries) do e.roleSalaries[k] = math.floor(tonumber(v) or 0) end end
                    if istable(rec.departmentSalaries) then for k, v in pairs(rec.departmentSalaries) do e.departmentSalaries[k] = math.floor(tonumber(v) or 0) end end
                    if rec.payFromBudget ~= nil then e.payFromBudget = rec.payFromBudget == true end
                    if rec.salaryInterval then e.salaryInterval = math.max(E.Config.MinSalaryInterval, math.floor(tonumber(rec.salaryInterval))) end
                    imported = imported + 1
                end
            end
        end
        if imported > 0 then
            dirty = true
            print("[GRM Economy] Импортировано фракционных записей из старых модулей: " .. imported)
        end
    end

    -- ── ГОС.БЮДЖЕТ И ГЛОБАЛЬНЫЙ ФИН.ЛОГ (v2.2) ────────────
    -- Применение сохранённых (админ-панелью) настроек поверх дефолтов.
    local function applyConfig()
        local c = E.Data.config
        if not istable(c) then return end
        for k, v in pairs(c) do
            if E.Config[k] ~= nil then E.Config[k] = v end
        end
        if tonumber(c.StartBalance) then GRM.StartBalance = tonumber(c.StartBalance) end
        if isstring(c.CurrencyName) and c.CurrencyName ~= "" then GRM.CurrencyName = c.CurrencyName end
    end

    local function stateHist(text)
        local st = E.Data.state
        st.history = istable(st.history) and st.history or {}
        st.history[#st.history + 1] = { t = os.time(), s = tostring(text) }
        while #st.history > E.Config.HistorySize do table.remove(st.history, 1) end
        dirty = true
    end

    local function stateAdd(delta, reason)
        local st = E.Data.state
        st.budget = math.max(0, math.floor((tonumber(st.budget) or 0) + delta))
        dirty = true
        if reason then stateHist(reason) end
        return st.budget
    end

    local function addLog(text)
        if not istable(E.Data.log) then E.Data.log = {} end
        local lg = E.Data.log
        lg[#lg + 1] = { t = os.time(), s = tostring(text) }
        local max = math.max(50, math.floor(tonumber(E.Config.LogSize) or 300))
        while #lg > max do table.remove(lg, 1) end
        dirty = true
    end
    E.Log = addLog -- публично: другие системы тоже могут писать в фин.лог

    -- Любое движение наличных через ядро валюты попадает в общий лог.
    hook.Add("GRM_MoneyChanged", "GRM_Economy_FinLog", function(ply, newBalance, delta, reason)
        -- v2.3.9: рутина забивает общий лог — фильтруем на входе.
        -- Зарплата видна в истории фракций (addHistory) и гос.бюджете,
        -- сверка с базой — в консоли сервера и форензик-логе валюты.
        if isstring(reason) then
            if string.StartWith(reason, "Зарплата") then return end
            if string.StartWith(reason, "Сверка с базой") then return end
        end
        local who = "?"
        if IsValid(ply) and ply:IsPlayer() then
            who = ply:Nick()
        elseif isstring(ply) then
            who = ply
            if GRM.GetAllBalances then
                local rec = GRM.GetAllBalances()[ply]
                if rec and rec.name then who = tostring(rec.name) end
            end
        end
        delta = math.floor(tonumber(delta) or 0)
        addLog(("%s %s%s (баланс: %s)%s"):format(
            who,
            delta >= 0 and "+" or "-",
            money(math.abs(delta)),
            money(newBalance),
            (isstring(reason) and reason ~= "") and (" | " .. reason) or ""))
    end)

    local function load()
        local t = tryJSON(DATA_FILE)
        if t and istable(t.factions) then
            E.Data = t
        else
            E.Data = { version = 2, factions = {} }
            importLegacy() -- первый запуск: подтянуть данные старых модулей
        end
        E.Data.accounts = istable(E.Data.accounts) and E.Data.accounts or {}
        E.Data.state = istable(E.Data.state) and E.Data.state or { budget = 0, history = {} }
        E.Data.state.budget = math.max(0, math.floor(tonumber(E.Data.state.budget) or 0))
        E.Data.state.history = istable(E.Data.state.history) and E.Data.state.history or {}
        E.Data.log = istable(E.Data.log) and E.Data.log or {}
        E.Data.config = istable(E.Data.config) and E.Data.config or {}
        applyConfig() -- сохранённые настройки поверх дефолтов
        for name in pairs(E.Data.factions) do entry(name) end
    end

        -- ── ЛИЧНЫЕ БАНКОВСКИЕ СЧЕТА (банкомат для ВСЕХ игроков) ──
    local function account(sid, nick)
        sid = tostring(sid or "")
        if sid == "" then return nil end
        local acc = E.Data.accounts[sid]
        if not acc then
            acc = { balance = 0, name = nick or "?" }
            E.Data.accounts[sid] = acc
            dirty = true
        end
        acc.balance = math.max(0, math.floor(tonumber(acc.balance) or 0))
        if nick and nick ~= "" then acc.name = nick end
        return acc
    end

    -- Банковский баланс БЕЗ создания записи (для пассивного синка в HUD)
    local function bankBalOf(sid)
        local acc = E.Data.accounts[tostring(sid or "")]
        return math.max(0, math.floor(acc and acc.balance or 0))
    end

    -- Пуш счёта владельцу (HUD Код 48, строка «НА СЧЁТУ»)
    local function pushBank(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        net.Start("GRM_Bank_Sync")
            net.WriteDouble(bankBalOf(ply:SteamID64())) -- v2.3.7: Double, UInt32 ломал счета > 4.29 млрд
        net.Send(ply)
    end
    net.Receive("GRM_Bank_Request", function(_, ply) pushBank(ply) end)

    -- Найти онлайн-игрока по SteamID64-строке и запушить ему счёт
    local function pushBankBySid(sid)
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:SteamID64() == tostring(sid) then pushBank(p) return end
        end
    end

    -- ply может быть Player или строкой SteamID64
    function E.BankBalance(ply)
        local sid = isstring(ply) and ply or (IsValid(ply) and ply:SteamID64())
        if not sid then return 0 end
        local acc = E.Data.accounts[sid]
        return acc and acc.balance or 0
    end

    -- Наличные -> банковский счёт
    function E.BankDeposit(ply, amount)
        amount = math.max(0, math.floor(tonumber(amount) or 0))
        if not IsValid(ply) or amount <= 0 then return false end
        if not (GRM.HasMoney and GRM.HasMoney(ply, amount)) then return false end
        GRM.TakeMoney(ply, amount, "Банкомат: взнос на счёт")
        local acc = account(ply:SteamID64(), ply:Nick())
        acc.balance = acc.balance + amount
        dirty = true
        return true, acc.balance
    end

    -- Банковский счёт -> наличные
    function E.BankWithdraw(ply, amount)
        amount = math.max(0, math.floor(tonumber(amount) or 0))
        if not IsValid(ply) or amount <= 0 then return false end
        local acc = account(ply:SteamID64(), ply:Nick())
        if acc.balance < amount then return false end
        acc.balance = acc.balance - amount
        dirty = true
        GRM.GiveMoney(ply, amount, "Банкомат: снятие со счёта")
        return true, acc.balance
    end

    -- Счёт -> счёт (получатель может быть офлайн: ключ — SteamID64)
    function E.BankTransfer(ply, toSid, amount)
        amount = math.max(0, math.floor(tonumber(amount) or 0))
        if not IsValid(ply) or amount <= 0 then return false end
        toSid = tostring(toSid or "")
        if toSid == "" or toSid == ply:SteamID64() then return false end
        local from = account(ply:SteamID64(), ply:Nick())
        if from.balance < amount then return false end
        local to = account(toSid)
        if not to then return false end
        from.balance = from.balance - amount
        to.balance = to.balance + amount
        dirty = true
        addLog(("Перевод счёт→счёт: %s → %s: %s"):format(ply:Nick(), toSid, money(amount)))
        return true, from.balance
    end

-- ── ПУБЛИЧНОЕ API (совместимость с Кодом 13 и др.) ───────
    function GRM.FactionBudgetGet(name)
        if not name then return 0 end
        local e = E.Data.factions[name]
        return e and e.budget or 0
    end

    function GRM.FactionBudgetAdd(name, delta, silentReason)
        if not name then return 0 end
        delta = math.floor(tonumber(delta) or 0)
        if delta == 0 then return GRM.FactionBudgetGet(name) end
        local e = entry(name)
        e.budget = math.max(0, e.budget + delta)
        dirty = true
        if silentReason then addHistory(name, silentReason) end
        hook.Run("GRM_FactionBudgetChanged", name, e.budget, delta)
        return e.budget
    end

    function GRM.FactionBudgetSet(name, value)
        if not name then return end
        local e = entry(name)
        e.budget = math.max(0, math.floor(tonumber(value) or 0))
        dirty = true
        hook.Run("GRM_FactionBudgetChanged", name, e.budget, 0)
    end

    function GRM.FactionTaxGet(name)
        if not name then return E.Config.DefaultTaxRate end
        local e = E.Data.factions[name]
        return e and e.taxRate or E.Config.DefaultTaxRate
    end

    function GRM.FactionTaxSet(name, rate)
        if not name then return end
        entry(name).taxRate = math.Clamp(tonumber(rate) or 0, 0, E.Config.MaxTaxRate)
        dirty = true
    end

    -- ── Зарплата конкретного игрока ─────────────────────────
    function E.GetSalaryFor(ply)
        local name, f = factionOf(ply)
        if not name then return 0, nil end
        local e = entry(name)
        local info = f.Members[ply:SteamID()] or {}
        local gross = (info.Role and math.floor(tonumber(e.roleSalaries[info.Role]) or 0) or 0)
        if gross <= 0 and info.Department then
            gross = math.floor(tonumber(e.departmentSalaries[info.Department]) or 0)
        end
        if gross <= 0 then gross = e.baseSalary end
        return gross, name
    end

    -- Эффективная налоговая ставка: персональная (Код 13) > фракционная.
    local function taxRateFor(ply, name)
        if GRM.GetPlayerTaxRate then
            local ok, r = pcall(GRM.GetPlayerTaxRate, ply)
            if ok and tonumber(r) then return math.Clamp(tonumber(r), 0, E.Config.MaxTaxRate) end
        end
        return GRM.FactionTaxGet(name)
    end

    -- ── Движок выплат: один таймер на всё ───────────────────
    local function payFaction(name, e)
        local paid, skipped = 0, 0
        for _, ply in ipairs(onlineMembers(name)) do
            local gross = E.GetSalaryFor(ply)
            if gross and gross > 0 then
                if e.payFromBudget and e.budget < gross then
                    notify(ply, "[" .. name .. "] Зарплата не выплачена: бюджет пуст.", 255, 120, 80)
                    skipped = skipped + 1
                else
                    local rate = taxRateFor(ply, name)
                    local tax  = math.floor(gross * rate)
                    local net  = gross - tax
                    if e.payFromBudget then e.budget = e.budget - gross end
                    if E.Config.TaxToState then
                        stateAdd(tax, ("Налог %d%% с ЗП %s [%s]"):format(math.floor(rate * 100), ply:Nick(), name))
                    else
                        e.budget = math.max(0, e.budget + tax)
                    end
                    GRM.GiveMoney(ply, net, "Зарплата [" .. name .. "]")
                    notify(ply, "Зарплата [" .. name .. "]: " .. money(net)
                        .. " (налог " .. math.floor(rate * 100) .. "%)", 100, 220, 100)
                    addHistory(name, "ЗП " .. ply:Nick() .. ": " .. money(net) .. " (налог " .. money(tax) .. ")")
                    paid = paid + 1
                end
            end
        end
        dirty = true
        if paid > 0 then
            addHistory(name, "Выплата зарплат: " .. paid .. " чел." .. (skipped > 0 and (", пропущено бюджетом: " .. skipped) or ""))
        end
    end

    timer.Create("GRM_Economy_SalaryEngine", 20, 0, function()
        local now = os.time()
        for name in pairs(E.Data.factions) do
            local e = entry(name)
            if now >= e.nextPay then
                e.nextPay = now + e.salaryInterval
                payFaction(name, e)
            end
        end
    end)

    -- (убран старый автосейв 120с — заменён на: флаш 5с по изменениям + авто 8с)
    timer.Create("GRM_Economy_AutoSave8s", 8, 0, function() save(true) end)
    hook.Add("ShutDown", "GRM_Economy_Save", function() dirty = true save() end)
    -- GRM-FIX: сброс изменений на диск каждые 5с — переживаем килл процесса
    timer.Create("GRM_Economy_Flush", 5, 0, function() if dirty then save() end end)

    -- GRM-FIX: сверка с базой (файл grm_economy.json как «база данных»).
    -- Если файл изменился снаружи (правили руками через FTP, другой
    -- инструмент) — поднимаем его целиком; свои несброшенные правки не теряем.
    local function reconcileEconomy(reason)
        if dirty then return false end
        if not file.Exists(DATA_FILE, "DATA") then return false end
        local txt = file.Read(DATA_FILE, "DATA") or ""
        if txt == lastDiskTxt then return false end -- файл не менялся с нашей записи/чтения
        local okJs, t = pcall(util.JSONToTable, txt)
        if not okJs or not istable(t) then return false end
        -- GRM-FIX v2.3.8: пустой файл/дамп без счетов и фракций НЕ вытирает
        -- непустую память (двойник стража в save — иначе каскадный wipe).
        local gotAcc = istable(t.accounts) and next(t.accounts) ~= nil
        local gotFac = istable(t.factions) and next(t.factions) ~= nil
        local memAcc = istable(E.Data.accounts) and next(E.Data.accounts) ~= nil
        local memFac = istable(E.Data.factions) and next(E.Data.factions) ~= nil
        if not gotAcc and not gotFac and (memAcc or memFac) then
            print("[GRM Economy] DB↔MEM ОТКЛОНЕНО: файл пуст/без счетов, а память непуста — память сохранена (антисвайп-страж v2.3.8)")
            lastDiskTxt = txt
            return false
        end
        local oldAccounts = E.Data.accounts
        E.Data = t
        E.Data.version = 2
        E.Data.factions = istable(E.Data.factions) and E.Data.factions or {}
        E.Data.accounts = istable(E.Data.accounts) and E.Data.accounts or {}
        E.Data.state = istable(E.Data.state) and E.Data.state or { budget = 0, history = {} }
        E.Data.log = istable(E.Data.log) and E.Data.log or {}
        E.Data.config = istable(E.Data.config) and E.Data.config or {}
        if applyConfig then pcall(applyConfig) end
        lastDiskTxt = txt
        -- пушим счета, если они реально изменились
        local pushed = 0
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:IsPlayer() then
                local sid = p:SteamID64()
                local oldBal = oldAccounts and oldAccounts[sid] and oldAccounts[sid].balance or 0
                local newBal = E.Data.accounts[sid] and E.Data.accounts[sid].balance or 0
                if oldBal ~= newBal then pushBank(p) pushed = pushed + 1 end
            end
        end
        print(("[GRM Economy] DB↔MEM [%s]: данные подняты из %s, счетов обновлено онлайн: %d")
            :format(tostring(reason), DATA_FILE, pushed))
        return true
    end
    timer.Create("GRM_Economy_Reconcile", 15, 0, function() reconcileEconomy("тик 15с") end)
    concommand.Add("grm_economy_check", function(ply)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end
        local ok = reconcileEconomy("команда")
        print("[GRM Economy] сверка завершена: " .. (ok and "подняты изменения из базы" or "расхождений нет"))
    end)

    -- ── ДОСТУП К ШТРАФАМ (v2.3): кто и кого может штрафовать ──
    -- Возвращает true либо false + причину отказа.
    function E.CanFine(issuer, target)
        if not IsValid(issuer) or not issuer:IsPlayer() then return true end -- система
        if issuer:IsSuperAdmin() then return true end                        -- superadmin: всегда
        if not IsValid(target) or not target:IsPlayer() then return false, "Нет цели" end
        if target == issuer then return false, "Нельзя штрафовать себя" end

        local iname, ifac = factionOf(issuer)
        if not iname then return false, "Ваша фракция не имеет доступа к системе штрафов" end
        local fp = entry(iname).finePerms
        if not fp.enabled then
            return false, "Фракция [" .. iname .. "] не имеет доступа к системе штрафов"
        end
        -- КТО: лидер всегда; иначе — все члены либо отмеченные роли
        if not isLeaderOf(issuer, ifac) and not fp.allRoles then
            local info = ifac.Members[issuer:SteamID()] or {}
            if not fp.roles[tostring(info.Role or "")] then
                return false, "Ваша роль во фракции не имеет права штрафовать"
            end
        end
        -- КОГО: свои / другие фракции / граждане
        local tname = factionOf(target)
        if tname == iname then
            if not fp.ownFaction then return false, "[" .. iname .. "] не может штрафовать своих членов" end
        elseif tname then
            if not fp.otherFactions then return false, "[" .. iname .. "] не может штрафовать другие фракции" end
        else
            if not fp.civilians then return false, "[" .. iname .. "] не может штрафовать граждан (без фракции)" end
        end
        return true
    end

    -- Эффективный лимит штрафа для конкретного игрока.
    function E.FineMaxFor(ply)
        if IsValid(ply) and ply:IsPlayer() and ply:IsSuperAdmin() then return E.Config.FineMaxAmount end
        local iname = factionOf(ply)
        local fp = iname and entry(iname).finePerms
        if fp and fp.enabled and fp.maxAmount > 0 then
            return math.min(fp.maxAmount, E.Config.FineMaxAmount)
        end
        return E.Config.FineMaxAmount
    end

    -- ── ШТРАФЫ ──────────────────────────────────────────────
    function E.Fine(issuer, target, amount, reason)
        if not IsValid(target) or not target:IsPlayer() then return false, "Нет цели" end
        amount = math.floor(tonumber(amount) or 0)
        if amount <= 0 then return false, "Сумма должна быть > 0" end
        local maxFor = E.FineMaxFor and E.FineMaxFor(issuer) or E.Config.FineMaxAmount
        if amount > maxFor then amount = maxFor end
        if GRM.GetBalance(target) <= 0 then return false, "У игрока нет средств" end

        local issued = math.min(amount, GRM.GetBalance(target))
        GRM.TakeMoney(target, issued, "Штраф: " .. tostring(reason or "нарушение"))

        local receiptName = factionOf(issuer)
        if receiptName and E.Config.FineToBudget then
            GRM.FactionBudgetAdd(receiptName, issued,
                ("Штраф %s от %s: %s"):format(target:Nick(), IsValid(issuer) and issuer:Nick() or "система", money(issued)))
        elseif E.Config.FinesToState then
            stateAdd(issued, ("Штраф %s от %s"):format(target:Nick(), IsValid(issuer) and issuer:Nick() or "система"))
        end

        notify(target,
            ("ШТРАФ: -%s | %s | от: %s"):format(money(issued), tostring(reason or "без причины"),
                IsValid(issuer) and issuer:Nick() or "система"),
            255, 80, 70)
        if IsValid(issuer) and issuer ~= target then
            local dest = " (деньги сгорают)"
            if receiptName and E.Config.FineToBudget then dest = " → бюджет [" .. receiptName .. "]"
            elseif E.Config.FinesToState then dest = " → гос.бюджет" end
            notify(issuer, "Штраф выписан: " .. target:Nick() .. " -" .. money(issued) .. dest, 100, 220, 100)
        end
        local tf = factionOf(target)
        if tf and tf ~= receiptName then
            addHistory(tf, ("Штраф %s (-%s) от %s"):format(target:Nick(), money(issued), IsValid(issuer) and issuer:Nick() or "?"))
        end
        hook.Run("GRM_FineIssued", issuer, target, issued, tostring(reason or ""))
        return true, issued
    end

    -- ── СИНХРОНИЗАЦИЯ клиентов ──────────────────────────────
    local function syncPlayer(ply)
        local name, f = factionOf(ply)
        net.Start(NET_SYNC)
            net.WriteString(name or "")
            net.WriteTable(name and entry(name) or {})
        net.Send(ply)
    end

    hook.Add("PlayerInitialSpawn", "GRM_Economy_Sync", function(ply)
        timer.Simple(5, function()
            if IsValid(ply) then syncPlayer(ply) pushBank(ply) end
        end)
    end)

    -- ── АДМИН-ПАНЕЛЬ: данные (единая панель экономики) ─────
    local function buildAdminData()
        local factions = {}
        if Factions then
            for name, f in pairs(Factions) do
                if istable(f) then
                    local roles, depts = {}, {}
                    if istable(f.Roles) then for _, r in ipairs(f.Roles) do roles[#roles + 1] = tostring(r) end end
                    if istable(f.Departments) then for _, dd in ipairs(f.Departments) do depts[#depts + 1] = tostring(dd) end end
                    factions[name] = {
                        entry = entry(name),
                        roles = roles,
                        departments = depts,
                        online = #onlineMembers(name, f),
                        members = f.Members and table.Count(f.Members) or 0,
                    }
                end
            end
        end
        -- известные записи без живой фракции тоже отдаём
        for name in pairs(E.Data.factions) do
            if not factions[name] then
                factions[name] = { entry = entry(name), roles = {}, departments = {}, online = 0, members = 0 }
            end
        end

        -- игроки + их банковские счета + суммарная статистика
        local players, cashSum, bankSum = {}, 0, 0
        if GRM.GetAllBalances then players = GRM.GetAllBalances() end
        for sid, rec in pairs(players) do
            cashSum = cashSum + (tonumber(rec.balance) or 0)
            local acc = E.Data.accounts[sid]
            rec.bank = acc and acc.balance or 0
            bankSum = bankSum + rec.bank
        end

        local fullcfg = table.Copy(E.Config)
        fullcfg.StartBalance = GRM.StartBalance or 1000
        fullcfg.CurrencyName = GRM.CurrencyName or "GRM"

        return {
            factions = factions,
            state = E.Data.state,
            players = players,
            log = E.Data.log,
            config = {
                maxTax = E.Config.MaxTaxRate, minInterval = E.Config.MinSalaryInterval,
            },
            fullconfig = fullcfg,
            stats = {
                players = table.Count(players), cash = cashSum, bank = bankSum,
                factions = table.Count(E.Data.factions), logSize = #(E.Data.log or {}),
            },
        }
    end

    local function sendAdminData(ply)
        net.Start(NET_ADMIN_DATA)
            net.WriteTable(buildAdminData())
        net.Send(ply)
    end

    net.Receive(NET_OPEN_ADMIN, function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        sendAdminData(ply)
    end)

    net.Receive(NET_ADMIN_ACT, function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        local a = net.ReadTable() or {}
        local name = tostring(a.faction or "")
        local function amt(v) return math.max(0, math.floor(tonumber(v) or 0)) end
        local function sidArg() return tostring(a.sid or "") end

        if a.action == "save_entry" then
            if name == "" then return end
            local e = entry(name)
            e.taxRate            = math.Clamp(tonumber(a.taxRate) or e.taxRate, 0, E.Config.MaxTaxRate)
            e.baseSalary         = math.max(0, math.floor(tonumber(a.baseSalary) or 0))
            e.salaryInterval     = math.max(E.Config.MinSalaryInterval, math.floor(tonumber(a.salaryInterval) or e.salaryInterval))
            e.payFromBudget      = a.payFromBudget == true
            if istable(a.roles) then
                e.roleSalaries = {}
                for k, v in pairs(a.roles) do e.roleSalaries[tostring(k)] = math.max(0, math.floor(tonumber(v) or 0)) end
            end
            if istable(a.departments) then
                e.departmentSalaries = {}
                for k, v in pairs(a.departments) do e.departmentSalaries[tostring(k)] = math.max(0, math.floor(tonumber(v) or 0)) end
            end
            if istable(a.fine) then
                local fp = e.finePerms
                fp.enabled       = a.fine.enabled == true
                fp.allRoles      = a.fine.allRoles == true
                fp.ownFaction    = a.fine.ownFaction ~= false
                fp.otherFactions = a.fine.otherFactions == true
                fp.civilians     = a.fine.civilians ~= false
                fp.maxAmount     = math.max(0, math.floor(tonumber(a.fine.maxAmount) or 0))
                if istable(a.fine.roles) then
                    fp.roles = {}
                    for k, v in pairs(a.fine.roles) do if v == true then fp.roles[tostring(k)] = true end end
                end
            end
            dirty = true
            save()
            addHistory(name, "Настройки обновлены админом " .. ply:Nick())
            addLog("Админ " .. ply:Nick() .. " обновил настройки [" .. name .. "]")
            notify(ply, "Фракция [" .. name .. "] сохранена.", 100, 220, 100)

        elseif a.action == "budget_give" or a.action == "budget_take" then
            if name == "" then return end
            local e = entry(name)
            local v = amt(a.amount)
            if a.action == "budget_take" then v = -math.min(v, e.budget) end
            if v ~= 0 then
                GRM.FactionBudgetAdd(name, v, ("Админ %s: %s%s"):format(ply:Nick(), v > 0 and "+" or "", money(math.abs(v))))
                notify(ply, "Бюджет [" .. name .. "]: " .. money(entry(name).budget), 100, 220, 255)
            end

        elseif a.action == "pay_now" then
            if name == "" then return end
            entry(name).nextPay = os.time()
            notify(ply, "Принудительная выплата запрошена для [" .. name .. "].", 255, 200, 80)

        -- ── ГОС.БЮДЖЕТ ──────────────────────────────────────
        elseif a.action == "save_now" then
            dirty = true save()
            notify(ply, "Данные экономики сохранены на диск.", 100, 220, 100)
        elseif a.action == "state_give" then
            local v = amt(a.amount)
            if v <= 0 then return end
            stateAdd(v, ("Админ %s пополнил гос.бюджет: +%s"):format(ply:Nick(), money(v)))
            notify(ply, "Гос.бюджет: " .. money(E.Data.state.budget), 235, 180, 60)
        elseif a.action == "state_take" then
            local v = math.min(amt(a.amount), E.Data.state.budget)
            if v <= 0 then return end
            stateAdd(-v, ("Админ %s изъял из гос.бюджета: -%s"):format(ply:Nick(), money(v)))
            notify(ply, "Гос.бюджет: " .. money(E.Data.state.budget), 235, 180, 60)
        elseif a.action == "state_set" then
            E.Data.state.budget = amt(a.amount)
            dirty = true
            stateHist("Админ " .. ply:Nick() .. " установил гос.бюджет: " .. money(E.Data.state.budget))
            notify(ply, "Гос.бюджет: " .. money(E.Data.state.budget), 235, 180, 60)
        elseif a.action == "state_to_faction" then
            if name == "" then return end
            local v = amt(a.amount)
            if v <= 0 then return end
            if E.Data.state.budget < v then notify(ply, "В гос.бюджете только: " .. money(E.Data.state.budget), 255, 100, 100) return end
            stateAdd(-v, ("Перечислено фракции [%s] (админ %s)"):format(name, ply:Nick()))
            GRM.FactionBudgetAdd(name, v, "Трансфер из гос.бюджета: " .. money(v))
            notify(ply, ("В [%s] перечислено %s из гос.бюджета"):format(name, money(v)), 100, 220, 100)
        elseif a.action == "state_pay" then
            local sid, v = sidArg(), amt(a.amount)
            if sid == "" or v <= 0 then return end
            if E.Data.state.budget < v then notify(ply, "В гос.бюджете только: " .. money(E.Data.state.budget), 255, 100, 100) return end
            stateAdd(-v, ("Выплата игроку %s (админ %s)"):format(sid, ply:Nick()))
            GRM.GiveMoney(sid, v, "Выплата из гос.бюджета")
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p:SteamID64() == sid then
                    notify(p, "Вам выплачено из гос.бюджета: " .. money(v), 100, 220, 100)
                    break
                end
            end
            notify(ply, "Выплачено " .. money(v) .. " игроку " .. sid, 100, 220, 100)

        -- ── ИГРОКИ: балансы наличных и счетов ───────────────
        elseif a.action == "player_give" or a.action == "player_take" or a.action == "player_set" then
            local sid, v = sidArg(), amt(a.amount)
            if sid == "" then return end
            if a.action == "player_give" then
                GRM.GiveMoney(sid, v, "Админ " .. ply:Nick() .. ": выдача")
            elseif a.action == "player_take" then
                GRM.TakeMoney(sid, v, "Админ " .. ply:Nick() .. ": изъятие")
            else
                GRM.SetBalance(sid, v, "Админ " .. ply:Nick() .. ": установка баланса")
            end
            local rec = GRM.GetAllBalances and GRM.GetAllBalances()[sid]
            notify(ply, "Баланс обновлён: " .. money(rec and rec.balance or 0), 100, 220, 100)
        elseif a.action == "player_bank_set" then
            local sid, v = sidArg(), amt(a.amount)
            if sid == "" then return end
            local acc = account(sid)
            acc.balance = v
            dirty = true save()
            pushBankBySid(sid) -- HUD получателя, если он в сети
            addLog(("Админ %s установил банковский счёт %s: %s"):format(ply:Nick(), sid, money(v)))
            notify(ply, "Банковский счёт установлен: " .. money(v), 100, 220, 100)

        -- ── ОБЩИЕ НАСТРОЙКИ ─────────────────────────────────
        elseif a.action == "config_save" and istable(a.config) then
            local c = a.config
            local out = istable(E.Data.config) and E.Data.config or {}
            local function num(key, mn, mx)
                local v = tonumber(c[key])
                if v then out[key] = math.Clamp(math.floor(v * 1000 + 0.5) / 1000, mn, mx) end
            end
            num("DefaultTaxRate", 0, 1)
            num("MaxTaxRate", 0.01, 1)
            num("SalaryInterval", 30, 86400)
            num("MinSalaryInterval", 10, 3600)
            num("HistorySize", 10, 500)
            num("LogSize", 50, 2000)
            num("FineMaxAmount", 100, 100000000)
            num("UseDistance", 50, 1000)
            num("StartBalance", 0, 100000000)
            for _, key in ipairs({ "PayFromBudget", "FineToBudget", "TaxToState", "FinesToState" }) do
                if c[key] ~= nil then out[key] = c[key] == true end
            end
            if isstring(c.CurrencyName) and c.CurrencyName ~= "" then
                out.CurrencyName = string.Left(c.CurrencyName, 16)
            end
            if isstring(c.BankTerminalModel) and string.StartWith(c.BankTerminalModel, "models/")
                and not string.find(c.BankTerminalModel, "..", 1, true) then
                out.BankTerminalModel = string.Left(c.BankTerminalModel, 128)
            end
            E.Data.config = out
            applyConfig()
            dirty = true save()
            addLog("Админ " .. ply:Nick() .. " обновил общие настройки экономики")
            notify(ply, "Настройки экономики сохранены.", 100, 220, 100)
        end

        -- КЛЮЧЕВОЕ ОТЛИЧИЕ от старой панели: НЕ переоткрываем окно,
        -- отдаём свежий пакет данных — клиент обновит поля на месте.
        sendAdminData(ply)
        timer.Simple(0.5, function() for _, p in ipairs(player.GetAll()) do if IsValid(p) then syncPlayer(p) end end end)
    end)

    -- ── БАНК-ТЕРМИНАЛ ───────────────────────────────────────
    function E.OpenBankTerminal(ply, ent)
        if not IsValid(ply) or not IsValid(ent) then return end
        if ply:GetPos():DistToSqr(ent:GetPos()) > (E.Config.UseDistance ^ 2) * 4 then return end
        local name = factionOf(ply)
        local players = {}
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p ~= ply then
                players[#players + 1] = { nick = p:Nick(), sid64 = p:SteamID64() }
            end
        end
        net.Start(NET_OPEN_BANK)
            net.WriteEntity(ent)
            net.WriteTable({
                balance = GRM.GetBalance(ply),
                bank = E.BankBalance(ply),
                faction = name or "",
                factionData = name and entry(name) or nil,
                mySalary = select(1, E.GetSalaryFor(ply)),
                leader = name and isLeaderOf(ply, Factions[name]) or false,
                players = players,
            })
        net.Send(ply)
    end

    net.Receive(NET_BANK_ACT, function(_, ply)
        if not IsValid(ply) then return end
        local a = net.ReadTable() or {}
        local name = factionOf(ply)
        local f = name and Factions[name]
        local amt = math.max(0, math.floor(tonumber(a.amount) or 0))

        if a.type == "bank_deposit" then
            if amt <= 0 then return end
            local ok, newbal = E.BankDeposit(ply, amt)
            if not ok then notify(ply, "Недостаточно наличных.", 255, 100, 100) return end
            notify(ply, ("Внесено на счёт: %s (счёт: %s)"):format(money(amt), money(newbal)), 100, 220, 100)
        elseif a.type == "bank_withdraw" then
            if amt <= 0 then return end
            local ok, newbal = E.BankWithdraw(ply, amt)
            if not ok then notify(ply, "На счёте только: " .. money(E.BankBalance(ply)), 255, 100, 100) return end
            notify(ply, ("Снято со счёта: %s (остаток: %s)"):format(money(amt), money(newbal)), 100, 220, 100)
        elseif a.type == "bank_transfer" then
            if amt <= 0 then return end
            local toSid = tostring(a.to or "")
            local ok = E.BankTransfer(ply, toSid, amt)
            if not ok then notify(ply, "Перевод не выполнен: недостаточно средств на счёте.", 255, 100, 100) return end
            local target
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p:SteamID64() == toSid then target = p break end
            end
            notify(ply, ("Переведено %s → %s"):format(money(amt), IsValid(target) and target:Nick() or toSid), 255, 180, 80)
            if IsValid(target) then
                notify(target, "На ваш счёт поступило " .. money(amt) .. " от " .. ply:Nick(), 100, 220, 100)
                pushBank(target) -- HUD получателя
            end
        elseif a.type == "deposit" then
            if not name then notify(ply, "Вы не во фракции.", 255, 100, 100) return end
            if amt <= 0 then return end
            if not GRM.HasMoney(ply, amt) then notify(ply, "Недостаточно средств.", 255, 100, 100) return end
            GRM.TakeMoney(ply, amt)
            GRM.FactionBudgetAdd(name, amt, ("Взнос %s: %s"):format(ply:Nick(), money(amt)))
            notify(ply, "Внесено в бюджет: " .. money(amt), 100, 220, 100)
        elseif a.type == "withdraw" then
            if not name then notify(ply, "Вы не во фракции.", 255, 100, 100) return end
            if not isLeaderOf(ply, f) then notify(ply, "Только лидер может снимать со счёта фракции.", 255, 100, 100) return end
            if amt <= 0 then return end
            local e = entry(name)
            if e.budget < amt then notify(ply, "В бюджете только: " .. money(e.budget), 255, 100, 100) return end
            e.budget = e.budget - amt
            dirty = true
            addHistory(name, ("Лидер %s снял %s"):format(ply:Nick(), money(amt)))
            GRM.GiveMoney(ply, amt)
            notify(ply, "Снято из бюджета: " .. money(amt), 100, 220, 100)
        elseif a.type == "transfer" then
            if amt <= 0 then return end
            local target
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p:SteamID64() == tostring(a.to or "") then target = p break end
            end
            if not IsValid(target) then notify(ply, "Получатель не в сети.", 255, 100, 100) return end
            if not GRM.HasMoney(ply, amt) then notify(ply, "Недостаточно средств.", 255, 100, 100) return end
            GRM.TakeMoney(ply, amt)
            GRM.GiveMoney(target, amt)
            notify(ply, "Переведено " .. money(amt) .. " → " .. target:Nick(), 255, 180, 80)
            notify(target, "Получено " .. money(amt) .. " от " .. ply:Nick(), 100, 220, 100)
        end
        -- переоткроем с актуальными данными (это УМЕСТНО для терминала —
        -- пользователь ждёт обновления цифр после операции)
        syncPlayer(ply)
        pushBank(ply) -- HUD: строка «НА СЧЁТУ»
    end)

    -- ── ЧАТ-КОМАНДЫ (PlayerSay — работают без GRM.Chat) ─────
    hook.Add("PlayerSay", "GRM_Economy_Chat", function(ply, text)
        local args = string.Explode(" ", string.Trim(text or ""))
        local cmd = string.lower(args[1] or "")

        if cmd == "/feco_admin" or cmd == "!feco_admin" or cmd == "/salary_admin" or cmd == "!salary_admin" then
            if ply:IsSuperAdmin() then net.Start(NET_OPEN_ADMIN) net.Send(ply) end
            return ""
        end

        if cmd == "/mysalary" or cmd == "!mysalary" then
            local gross, name = E.GetSalaryFor(ply)
            if not name then notify(ply, "Вы не во фракции.", 255, 100, 100) return "" end
            local e = entry(name)
            notify(ply, ("Ваша ЗП: %s | налог %d%% | интервал %dс | из бюджета: %s"):format(
                money(gross), math.floor(taxRateFor(ply, name) * 100), e.salaryInterval, e.payFromBudget and "да" or "нет"), 100, 220, 255)
            return ""
        end

        if cmd == "!fbudget" or cmd == "/fbudget" then
            local name = factionOf(ply)
            if not name then notify(ply, "Вы не во фракции.", 255, 100, 100) return "" end
            local e = entry(name)
            notify(ply, ("[%s] Бюджет: %s | Налог: %d%% | База ЗП: %s"):format(
                name, money(e.budget), math.floor(e.taxRate * 100), money(e.baseSalary)), 100, 220, 255)
            return ""
        end

        if cmd == "!fpay" or cmd == "/fpay" then
            local name = factionOf(ply)
            local amt = math.floor(tonumber(args[2]) or 0)
            if not name or amt <= 0 then return "" end
            if not GRM.HasMoney(ply, amt) then notify(ply, "Недостаточно средств.", 255, 100, 100) return "" end
            GRM.TakeMoney(ply, amt)
            GRM.FactionBudgetAdd(name, amt, ("Взнос %s: %s"):format(ply:Nick(), money(amt)))
            notify(ply, "Внесено в бюджет: " .. money(amt), 100, 220, 100)
            syncPlayer(ply)
            return ""
        end

        if cmd == "!fwithdraw" or cmd == "/fwithdraw" then
            local name, f = factionOf(ply)
            local amt = math.floor(tonumber(args[2]) or 0)
            if not name or amt <= 0 then return "" end
            if not isLeaderOf(ply, f) then notify(ply, "Только лидер фракции.", 255, 100, 100) return "" end
            local e = entry(name)
            if e.budget < amt then notify(ply, "В бюджете только: " .. money(e.budget), 255, 100, 100) return "" end
            e.budget = e.budget - amt
            addHistory(name, ("Лидер %s снял %s"):format(ply:Nick(), money(amt)))
            dirty = true
            GRM.GiveMoney(ply, amt)
            notify(ply, "Выведено из бюджета: " .. money(amt), 100, 220, 100)
            syncPlayer(ply)
            return ""
        end

        if cmd == "!fpayall" or cmd == "/fpayall" then
            local name, f = factionOf(ply)
            local amt = math.floor(tonumber(args[2]) or 0)
            if not name or amt <= 0 then return "" end
            if not isLeaderOf(ply, f) then notify(ply, "Только лидер фракции.", 255, 100, 100) return "" end
            local members = onlineMembers(name, f)
            local e = entry(name)
            local total = amt * #members
            if e.budget < total then
                notify(ply, "Не хватает бюджета: нужно " .. money(total) .. ", есть " .. money(e.budget), 255, 100, 100)
                return ""
            end
            e.budget = e.budget - total
            dirty = true
            for _, p in ipairs(members) do
                GRM.GiveMoney(p, amt)
                notify(p, "Премия от фракции [" .. name .. "]: " .. money(amt), 100, 200, 255)
            end
            addHistory(name, ("Лидер %s выплатил %s × %d"):format(ply:Nick(), money(amt), #members))
            notify(ply, "Выплачено " .. money(amt) .. " × " .. #members .. " (итого " .. money(total) .. ")", 100, 220, 100)
            syncPlayer(ply)
            return ""
        end

        if cmd == "!fsettax" or cmd == "/fsettax" then
            local name, f = factionOf(ply)
            local pct = tonumber(args[2])
            if not name or not pct then return "" end
            if not isLeaderOf(ply, f) then notify(ply, "Только лидер фракции.", 255, 100, 100) return "" end
            GRM.FactionTaxSet(name, pct / 100)
            notify(ply, ("[%s] Налог установлен: %d%%"):format(name, math.floor(GRM.FactionTaxGet(name) * 100)), 100, 220, 100)
            addHistory(name, ("Лидер %s установил налог %d%%"):format(ply:Nick(), math.floor(GRM.FactionTaxGet(name) * 100)))
            syncPlayer(ply)
            return ""
        end

        if cmd == "/fine" or cmd == "!fine" then
            -- /fine <сумма> [причина...] — цель: игрок в перекрестии (до 250 юнитов)
            -- Права: E.CanFine — доступ выдаёт superadmin в админ-панели (Фракции → Штрафы).
            local amt = math.floor(tonumber(args[2]) or 0)
            local reason = table.concat(args, " ", 3)
            if amt <= 0 then notify(ply, "/fine <сумма> [причина]", 255, 100, 100) return "" end
            local tr = ply:GetEyeTrace()
            local target = tr.Entity
            if not (IsValid(target) and target:IsPlayer() and target:GetPos():DistToSqr(ply:GetPos()) <= 250 * 250) then
                notify(ply, "Смотрите на игрока (до 250 юнитов).", 255, 100, 100)
                return ""
            end
            local ok, why = E.CanFine(ply, target)
            if not ok then notify(ply, why or "Нет доступа к системе штрафов.", 255, 100, 100) return "" end
            local okFine, issued = E.Fine(ply, target, amt, reason ~= "" and reason or "нарушение")
            if not okFine and issued then notify(ply, tostring(issued), 255, 100, 100) end
            return ""
        end
    end)

    -- ── Консоль ─────────────────────────────────────────────
    -- Чат-команда /dbcheck (superadmin): сверить с базой прямо из игры
    hook.Add("PlayerSay", "GRM_Economy_DBCheck", function(ply, text)
        local cmd = string.lower(string.Trim(text or ""))
        if cmd ~= "/dbcheck" and cmd ~= "!dbcheck" then return end
        if not ply:IsSuperAdmin() then
            if GRM.Notify then GRM.Notify(ply, "Только для superadmin.", 255, 100, 100) end
            return ""
        end
        local changed = reconcileEconomy("чат /dbcheck")
        if GRM.Notify then
            GRM.Notify(ply, changed
                and "Сверка экономики: данные подняты из базы"
                or  "Сверка экономики: расхождений с базой нет",
                100, 220, changed and 100 or 255)
        end
        return ""
    end)

    -- Хук для объединённого ответа на /dbcheck из ядра валюты
    hook.Add("GRM_Economy_DBCheck", "GRM_Economy_DBCheckHook", function()
        return reconcileEconomy("команда")
    end)

    concommand.Add("grm_economy", function(ply, _, cargs)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end
        local mode = tostring(cargs[1] or "")
        if mode == "save" then dirty = true save() print("[GRM Economy] сохранено.")
        elseif mode == "list" then
            print("[GRM Economy] фракций с экономикой: " .. table.Count(E.Data.factions))
            for name in pairs(E.Data.factions) do
                local e = entry(name)
                print(string.format("  [%s] бюджет %s, налог %d%%, ЗП база %s, интервал %ds",
                    name, money(e.budget), math.floor(e.taxRate * 100), money(e.baseSalary), e.salaryInterval))
            end
        elseif mode == "state" then
            print("[GRM Economy] гос.бюджет: " .. money(E.Data.state.budget))
        elseif mode == "accounts" then
            print("[GRM Economy] банковских счетов: " .. table.Count(E.Data.accounts))
        else
            print("[GRM Economy] grm_economy <save|list|state|accounts>")
        end
    end)

    load()
    lastDiskTxt = file.Exists(DATA_FILE, "DATA") and (file.Read(DATA_FILE, "DATA") or "") or nil
    print(("[GRM Economy] Unified Economy v2.3.9 загружена (путь: %s): фракций %d, счетов %d"):format(
        tostring(debug.getinfo(1, "S").short_src), table.Count(E.Data.factions), table.Count(E.Data.accounts)))
end

-- ============================================================
-- КЛИЕНТ
-- ============================================================
if CLIENT then
    E.Local = E.Local or { faction = "", data = {} }

    surface.CreateFont("GRM_Eco_Title",  { font = "Roboto", size = 19, weight = 800, extended = true })
    surface.CreateFont("GRM_Eco_Normal", { font = "Roboto", size = 14, weight = 500, extended = true })
    surface.CreateFont("GRM_Eco_Small",  { font = "Roboto", size = 12, weight = 400, extended = true })

    local CUI = {
        bg = Color(19, 24, 33, 248), panel = Color(33, 42, 56, 245), accent = Color(70, 155, 255),
        green = Color(55, 185, 105), red = Color(205, 70, 65), yellow = Color(235, 180, 60),
        text = Color(240, 244, 250), dim = Color(166, 176, 191),
    }

    local function money(n) return GRM and GRM.Format and GRM.Format(n) or (tostring(n) .. " GRM") end

    local function frame(title, w, h)
        local f = vgui.Create("DFrame")
        f:SetTitle("") f:SetSize(w, h) f:Center() f:MakePopup()
        -- GRM-FIX: движковый крестик (скин) невидим на тёмной шапке —
        -- прячем его и рисуем свой, контрастный.
        f:ShowCloseButton(false)
        f.Paint = function(_, pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, CUI.bg)
            draw.RoundedBoxEx(8, 0, 0, pw, 36, Color(27, 35, 48), true, true, false, false)
            draw.SimpleText(title, "GRM_Eco_Title", 13, 18, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local bx = vgui.Create("DButton", f)
        bx:SetText("") bx:SetPos(w - 42, 6) bx:SetSize(30, 24)
        bx:SetTooltip("Закрыть")
        bx.DoClick = function() f:Close() end
        bx.Paint = function(_, pw, ph)
            draw.RoundedBox(4, 0, 0, pw, ph, _:IsHovered() and Color(196, 62, 62) or Color(46, 56, 74))
            surface.SetDrawColor(240, 242, 246)
            surface.DrawLine(9, 7, pw - 9, ph - 7)
            surface.DrawLine(9, ph - 7, pw - 9, 7)
        end
        -- помечаем как хром окна: пересборка содержимого (buildAdminUI)
        -- НЕ должна удалять крестик
        bx._grmChrome = true
        return f
    end

    local function btn(p, t, c, w, h)
        local x = vgui.Create("DButton", p)
        x:SetText(t) x:SetFont("GRM_Eco_Normal") x:SetTextColor(color_white)
        if w then x:SetWide(w) end if h then x:SetTall(h) end
        x.Paint = function(s, pw, ph)
            local col = not s:IsEnabled() and Color(70, 75, 84)
                or (s:IsHovered() and Color(math.min(c.r + 20, 255), math.min(c.g + 20, 255), math.min(c.b + 20, 255)) or c)
            draw.RoundedBox(5, 0, 0, pw, ph, col)
        end
        return x
    end

    -- ── Синк собственной фракции ────────────────────────────
    net.Receive(NET_SYNC, function()
        E.Local = { faction = net.ReadString(), data = net.ReadTable() or {} }
        hook.Run("GRM_EconomySynced", E.Local.faction, E.Local.data)
    end)

    -- Банковский счёт для HUD (Код 48): GRM.PlayerBank — живое значение
    net.Receive("GRM_Bank_Sync", function()
        GRM.PlayerBank = net.ReadDouble() or 0 -- v2.3.7: парно к WriteDouble на сервере
        hook.Run("GRM_BankBalanceUpdated", GRM.PlayerBank)
    end)

    net.Receive(NET_INFO, function()
        chat.AddText(Color(120, 220, 120), "[Экономика] ", color_white, net.ReadString())
    end)

    -- ── ЕДИНАЯ АДМИН-ПАНЕЛЬ ЭКОНОМИКИ (обновляется НА МЕСТЕ) ──
    local adminFrame = nil

    local function act(t)
        net.Start(NET_ADMIN_ACT)
            net.WriteTable(t)
        net.SendToServer()
    end

    local function buildAdminUI(d)
        if not IsValid(adminFrame) then return end
        -- GRM-FIX: НЕ adminFrame:Clear() — он удалял служебные дети DFrame
        -- (btnClose/btnMaxim/btnMinim/lblTitle), из-за чего PerformLayout
        -- падал с "Tried to use a NULL Panel!" (dframe.lua, SetPos).
        -- Снимаем только наши панели, потомки DFrame не трогаем.
        for _, ch in ipairs(adminFrame:GetChildren()) do
            if ch ~= adminFrame.btnClose and ch ~= adminFrame.btnMaxim
                and ch ~= adminFrame.btnMinim and ch ~= adminFrame.lblTitle
                and ch ~= adminFrame.imgIcon and not ch._grmChrome then
                ch:Remove()
            end
        end

        local f = adminFrame
        local tabs = vgui.Create("DPropertySheet", f)
        tabs:Dock(FILL) tabs:DockMargin(8, 44, 8, 8)

        -- запоминаем активную вкладку, чтобы пересборка свежими данными
        -- возвращала админа на ту же вкладку (без переоткрытия окна)
        local lastTab = f._tabName
        local function sheetPanel(name, icon)
            local p = vgui.Create("DPanel", tabs)
            p:SetPaintBackground(false)
            p.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, CUI.panel) end
            local sh = tabs:AddSheet(name, p, icon)
            local oldClick = sh.Tab.DoClick
            sh.Tab.DoClick = function(...)
                f._tabName = name
                if oldClick then oldClick(...) end
            end
            if lastTab == name then tabs:SetActiveTab(sh.Tab) end
            return p
        end

        local function lbl(p, txt, col, x, y, w, font)
            local l = vgui.Create("DLabel", p)
            l:SetPos(x, y) l:SetSize(w or 560, 22)
            l:SetText(txt) l:SetFont(font or "GRM_Eco_Normal")
            l:SetTextColor(col or CUI.dim)
            return l
        end
        local function amtEntry(p, x, y, w)
            local t = vgui.Create("DTextEntry", p)
            t:SetPos(x, y) t:SetSize(w or 150, 26)
            t:SetNumeric(true) t:SetPlaceholderText("Сумма...")
            return t
        end
        local function getAmt(t) return math.max(0, math.floor(tonumber(t:GetValue()) or 0)) end
        local function histBox(p, list, x, y, w, h)
            local box = vgui.Create("DScrollPanel", p)
            box:SetPos(x, y) box:SetSize(w, h)
            box.Paint = function(_, pw, ph) draw.RoundedBox(6, 0, 0, pw, ph, Color(22, 28, 38, 240)) end
            for i = #list, math.max(1, #list - 80), -1 do
                local rec = list[i]
                local l = vgui.Create("DLabel", box)
                l:Dock(TOP) l:SetTall(16) l:DockMargin(6, 1, 4, 1)
                l:SetFont("GRM_Eco_Small") l:SetTextColor(CUI.dim)
                l:SetText(os.date("%d.%m %H:%M", rec.t or 0) .. " — " .. tostring(rec.s or ""))
            end
            return box
        end

        local stats = d.stats or {}
        local st = d.state or {}
        local full = d.fullconfig or {}

        -- ═══ ВКЛАДКА 1: ОБЗОР ═══
        do
            local p = sheetPanel("Обзор", "icon16/chart_bar.png")
            lbl(p, "Единая панель управления экономикой сервера", CUI.text, 12, 10, 800, "GRM_Eco_Title")
            lbl(p, "Доступ: только superadmin. Изменения сохраняются сразу и пишутся в фин.лог.", CUI.dim, 12, 36, 900)

            lbl(p, "ГОС.БЮДЖЕТ: " .. money(st.budget or 0), CUI.yellow, 12, 70, 800, "GRM_Eco_Title")
            lbl(p, ("Счетов игроков: %d | Наличными на руках: %s | На банковских счетах: %s"):format(
                stats.players or 0, money(stats.cash or 0), money(stats.bank or 0)), CUI.text, 12, 102, 920)
            lbl(p, ("Фракций с экономикой: %d | Записей в общем фин.логе: %d"):format(
                stats.factions or 0, stats.logSize or 0), CUI.text, 12, 128, 920)
            lbl(p, "Открыть панель: чат /feco_admin (или /salary_admin), консоль grm_salary_admin.", CUI.dim, 12, 154, 920)

            local sv = btn(p, "Сохранить данные на диск", CUI.accent, 260, 32)
            sv:SetPos(12, 196)
            sv.DoClick = function() act({ action = "save_now" }) end
        end

        -- ═══ ВКЛАДКА 2: ГОС.БЮДЖЕТ ═══
        do
            local p = sheetPanel("Гос.бюджет", "icon16/money.png")
            lbl(p, "Гос.бюджет: " .. money(st.budget or 0), CUI.yellow, 12, 10, 800, "GRM_Eco_Title")
            lbl(p, "Сюда поступают налоги с зарплат и штрафы (управляется во вкладке «Настройки»).", CUI.dim, 12, 36, 920)

            local amt = amtEntry(p, 12, 66, 150)
            local bg = btn(p, "Пополнить", CUI.green, 120, 26) bg:SetPos(170, 66)
            bg.DoClick = function() act({ action = "state_give", amount = getAmt(amt) }) end
            local bt = btn(p, "Изъять", CUI.red, 100, 26) bt:SetPos(296, 66)
            bt.DoClick = function() act({ action = "state_take", amount = getAmt(amt) }) end
            local bs = btn(p, "Установить", CUI.accent, 110, 26) bs:SetPos(402, 66)
            bs.DoClick = function() act({ action = "state_set", amount = getAmt(amt) }) end

            lbl(p, "Перечислить фракции:", CUI.text, 12, 106, 150)
            local cmb = vgui.Create("DComboBox", p)
            cmb:SetPos(170, 104) cmb:SetSize(250, 26)
            cmb:SetValue("Фракция...")
            for n in pairs(d.factions or {}) do cmb:AddChoice(n, n) end
            local bf = btn(p, "Перечислить из гос.", CUI.yellow, 180, 26) bf:SetPos(430, 104)
            bf.DoClick = function()
                local _, nm = cmb:GetSelected()
                if nm then act({ action = "state_to_faction", faction = nm, amount = getAmt(amt) }) end
            end

            lbl(p, "Выплатить игроку:", CUI.text, 12, 140, 150)
            local cmb2 = vgui.Create("DComboBox", p)
            cmb2:SetPos(170, 138) cmb2:SetSize(250, 26)
            cmb2:SetValue("Игрок (все известные)...")
            for sid, rec in pairs(d.players or {}) do
                cmb2:AddChoice(tostring(rec.name or sid) .. " (" .. sid .. ")", sid)
            end
            local bp = btn(p, "Выплатить из гос.", CUI.green, 180, 26) bp:SetPos(430, 138)
            bp.DoClick = function()
                local _, sid = cmb2:GetSelected()
                if sid then act({ action = "state_pay", sid = sid, amount = getAmt(amt) }) end
            end

            lbl(p, "Операции гос.бюджета:", CUI.text, 12, 176, 400)
            histBox(p, st.history or {}, 12, 200, 930, 320)
        end

        -- ═══ ВКЛАДКА 3: ИГРОКИ ═══
        do
            local p = sheetPanel("Игроки", "icon16/user.png")
            local list = vgui.Create("DListView", p)
            list:SetPos(4, 4) list:SetSize(940, 400)
            list:SetMultiSelect(false)
            list:AddColumn("Ник") list:AddColumn("Наличные") list:AddColumn("Счёт в банке") list:AddColumn("SteamID64")

            local sids = {}
            for sid in pairs(d.players or {}) do sids[#sids + 1] = sid end
            table.sort(sids, function(a1, b1)
                return tostring((d.players[a1] or {}).name or a1):lower() < tostring((d.players[b1] or {}).name or b1):lower()
            end)
            for _, sid in ipairs(sids) do
                local rec = d.players[sid]
                local ln = list:AddLine(tostring(rec.name or "?"), money(rec.balance or 0), money(rec.bank or 0), sid)
                ln.Sid = sid
            end

            local sel = lbl(p, "Выберите игрока в таблице", CUI.text, 12, 414, 920)
            local amt = amtEntry(p, 12, 442, 140)
            local function forSel(mk)
                return function()
                    if not f._playerSid then return end
                    act(mk(f._playerSid, getAmt(amt)))
                end
            end
            local b1 = btn(p, "Выдать", CUI.green, 100, 26) b1:SetPos(160, 442)
            b1.DoClick = forSel(function(sid, v) return { action = "player_give", sid = sid, amount = v } end)
            local b2 = btn(p, "Изъять", CUI.red, 100, 26) b2:SetPos(266, 442)
            b2.DoClick = forSel(function(sid, v) return { action = "player_take", sid = sid, amount = v } end)
            local b3 = btn(p, "Установить наличные", CUI.accent, 180, 26) b3:SetPos(372, 442)
            b3.DoClick = forSel(function(sid, v) return { action = "player_set", sid = sid, amount = v } end)
            local b4 = btn(p, "Установить счёт", CUI.yellow, 160, 26) b4:SetPos(558, 442)
            b4.DoClick = forSel(function(sid, v) return { action = "player_bank_set", sid = sid, amount = v } end)

            local function showSel(sid)
                local rec = (d.players or {})[sid]
                if not rec then return end
                sel:SetText(("Игрок: %s | наличные %s | счёт %s | %s"):format(
                    tostring(rec.name or sid), money(rec.balance or 0), money(rec.bank or 0), sid))
            end
            list.OnRowSelected = function(_, _, ln)
                f._playerSid = ln.Sid
                showSel(ln.Sid)
            end
            if f._playerSid then showSel(f._playerSid) end
        end

        -- ═══ ВКЛАДКА 4: ФРАКЦИИ (ЗП, ставки/надбавки, доступ к штрафам) ═══
        do
            local pnl = sheetPanel("Фракции", "icon16/group.png")
            local listW = 230
            local list = vgui.Create("DListView", pnl)
            list:SetPos(4, 4) list:SetSize(listW, 560)
            list:SetMultiSelect(false)
            list:AddColumn("Фракция") list:AddColumn("Бюджет")

            local names = {}
            for n in pairs(d.factions or {}) do names[#names + 1] = n end
            table.sort(names)
            for _, n in ipairs(names) do
                local fd = d.factions[n]
                local ln = list:AddLine(n, money(fd.entry and fd.entry.budget or 0))
                ln.Faction = n
            end

            local editor = vgui.Create("DPanel", pnl)
            editor:SetPos(listW + 12, 4) editor:SetSize(700, 560)
            editor.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, CUI.panel) end

            -- GRM-FIX: DPropertySheet растягивает страницу только при её
            -- активации, поэтому GetWide()/GetTall() в момент создания почти
            -- всегда нулевые — список «схлопывался», фракции не отображались.
            -- Считаем размеры по РЕАЛЬНОЙ раскладке (PerformLayout).
            local editorSub = nil
            pnl.PerformLayout = function(_, w, h)
                list:SetPos(4, 4) list:SetSize(listW, h - 8)
                if IsValid(editor) then
                    editor:SetPos(listW + 12, 4)
                    editor:SetSize(math.max(200, w - listW - 16), h - 8)
                end
            end
            editor.PerformLayout = function(_, w, h)
                if IsValid(editorSub) then
                    editorSub:SetPos(8, 58)
                    editorSub:SetSize(math.max(300, w - 16), math.max(200, h - 66))
                end
            end

            local function showEditor(name)
                editor:Clear()
                local fd = (d.factions or {})[name]
                if not fd then return end
                local e = fd.entry or {}
                local fp = istable(e.finePerms) and e.finePerms or {}
                -- восстановление выбранной фракции после пересборки свежими данными
                f._restoreFaction = name
                local rolesTbl, deptsTbl, fineChks = {}, {}, {}

                local function label(par, txt, x, y, col, w)
                    local l = vgui.Create("DLabel", par)
                    l:SetPos(x, y) l:SetSize(w or 280, 22)
                    l:SetText(txt) l:SetFont("GRM_Eco_Normal")
                    l:SetTextColor(col or CUI.dim)
                    return l
                end
                local function wang(par, x, y, w, val, maxv)
                    local wn = vgui.Create("DNumberWang", par)
                    wn:SetPos(x, y) wn:SetSize(w, 24)
                    wn:SetMin(0) wn:SetMax(maxv or 1000000) wn:SetValue(val or 0)
                    return wn
                end

                label(editor, "Фракция: " .. name .. "  (онлайн " .. (fd.online or 0) .. "/" .. (fd.members or 0) .. ")", 12, 8, CUI.text, 420)
                label(editor, "Бюджет: " .. money(e.budget or 0), 12, 32, CUI.yellow, 420)

                local sub = vgui.Create("DPropertySheet", editor)
                sub:SetPos(8, 58) sub:SetSize(math.max(300, editor:GetWide() - 16), math.max(200, editor:GetTall() - 66))
                editorSub = sub

                -- ── ПОДВКЛАДКА: ЗАРПЛАТЫ ──
                local pz = vgui.Create("DPanel", sub)
                pz:SetPaintBackground(false)
                sub:AddSheet("Зарплаты", pz, "icon16/money.png")

                label(pz, "Налог, %:", 10, 12)
                local taxW = wang(pz, 120, 10, 80, math.floor((e.taxRate or 0) * 100), (d.config and math.floor((d.config.maxTax or 0.5) * 100)) or 50)
                label(pz, "Базовая ЗП:", 10, 44)
                local baseW = wang(pz, 120, 42, 110, e.baseSalary or 0)
                label(pz, "Интервал ЗП, сек:", 10, 76)
                local intW = wang(pz, 160, 74, 90, e.salaryInterval or 600)

                local pfb = vgui.Create("DCheckBoxLabel", pz)
                pfb:SetPos(10, 108) pfb:SetSize(280, 22)
                pfb:SetText("Выплачивать ЗП из бюджета фракции")
                pfb:SetTextColor(CUI.text) pfb:SetValue(e.payFromBudget and 1 or 0)

                local bAmt = vgui.Create("DTextEntry", pz)
                bAmt:SetPos(10, 138) bAmt:SetSize(90, 24)
                bAmt:SetNumeric(true) bAmt:SetPlaceholderText("Сумма")
                local bgive = btn(pz, "+ Бюджет", CUI.green, 86, 24)
                bgive:SetPos(106, 138)
                bgive.DoClick = function()
                    act({ action = "budget_give", faction = name, amount = math.max(0, math.floor(tonumber(bAmt:GetValue()) or 0)) })
                end
                local btake = btn(pz, "- Бюджет", CUI.red, 86, 24)
                btake:SetPos(198, 138)
                btake.DoClick = function()
                    act({ action = "budget_take", faction = name, amount = math.max(0, math.floor(tonumber(bAmt:GetValue()) or 0)) })
                end

                label(pz, "История:", 10, 174, CUI.text)
                local histZ = histBox(pz, e.history or {}, 10, 198, 270, 300)

                -- ЗП по ролям (ставки)
                label(pz, "ЗП по ролям (ставки):", 300, 8, CUI.text)
                local rolesBox = vgui.Create("DScrollPanel", pz)
                rolesBox:SetPos(300, 30) rolesBox:SetSize(600, 180)
                rolesBox.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(22, 28, 38, 240)) end
                for _, rName in ipairs(fd.roles or {}) do
                    local row = vgui.Create("DPanel", rolesBox)
                    row:Dock(TOP) row:SetTall(26) row:DockMargin(4, 2, 4, 2) row.Paint = nil
                    local l = vgui.Create("DLabel", row) l:Dock(LEFT) l:SetWide(170)
                    l:SetText(rName) l:SetFont("GRM_Eco_Small") l:SetTextColor(CUI.text)
                    local wn = vgui.Create("DNumberWang", row) wn:Dock(RIGHT) wn:SetWide(90)
                    wn:SetMin(0) wn:SetMax(1000000)
                    wn:SetValue((e.roleSalaries or {})[rName] or 0)
                    rolesTbl[rName] = wn
                end

                -- ЗП по отделам (надбавки)
                local deptLbl = label(pz, "ЗП по отделам (надбавки):", 300, 230, CUI.text)
                local deptsBox = vgui.Create("DScrollPanel", pz)
                deptsBox:SetPos(300, 254)
                deptsBox:SetSize(600, 120)
                deptsBox.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(22, 28, 38, 240)) end
                for _, dName in ipairs(fd.departments or {}) do
                    local row = vgui.Create("DPanel", deptsBox)
                    row:Dock(TOP) row:SetTall(26) row:DockMargin(4, 2, 4, 2) row.Paint = nil
                    local l = vgui.Create("DLabel", row) l:Dock(LEFT) l:SetWide(170)
                    l:SetText(dName) l:SetFont("GRM_Eco_Small") l:SetTextColor(CUI.text)
                    local wn = vgui.Create("DNumberWang", row) wn:Dock(RIGHT) wn:SetWide(90)
                    wn:SetMin(0) wn:SetMax(1000000)
                    wn:SetValue((e.departmentSalaries or {})[dName] or 0)
                    deptsTbl[dName] = wn
                end

                -- ── ПОДВКЛАДКА: ШТРАФЫ (доступ фракции к /fine) ──
                local pf = vgui.Create("DPanel", sub)
                pf:SetPaintBackground(false)
                sub:AddSheet("Штрафы", pf, "icon16/accept.png")

                label(pf, "Доступ фракции [" .. name .. "] к системе штрафов", 10, 8, CUI.text, 560)

                local chEn = vgui.Create("DCheckBoxLabel", pf)
                chEn:SetPos(10, 36) chEn:SetSize(560, 22)
                chEn:SetText("Фракции РАЗРЕШЕНО штрафовать (команда /fine)")
                chEn:SetTextColor(CUI.text) chEn:SetValue(fp.enabled and 1 or 0)

                local chAll = vgui.Create("DCheckBoxLabel", pf)
                chAll:SetPos(10, 62) chAll:SetSize(560, 22)
                chAll:SetText("Штрафовать могут ВСЕ члены фракции (выкл — лидер + роли ниже)")
                chAll:SetTextColor(CUI.text) chAll:SetValue(fp.allRoles and 1 or 0)

                local chOwn = vgui.Create("DCheckBoxLabel", pf)
                chOwn:SetPos(10, 88) chOwn:SetSize(560, 22)
                chOwn:SetText("Можно штрафовать СВОИХ членов фракции")
                chOwn:SetTextColor(CUI.text) chOwn:SetValue(fp.ownFaction and 1 or 0)

                local chOther = vgui.Create("DCheckBoxLabel", pf)
                chOther:SetPos(10, 114) chOther:SetSize(560, 22)
                chOther:SetText("Можно штрафовать членов ДРУГИХ ФРАКЦИЙ")
                chOther:SetTextColor(CUI.text) chOther:SetValue(fp.otherFactions and 1 or 0)

                local chCiv = vgui.Create("DCheckBoxLabel", pf)
                chCiv:SetPos(10, 140) chCiv:SetSize(560, 22)
                chCiv:SetText("Можно штрафовать ГРАЖДАН (игроков без фракции)")
                chCiv:SetTextColor(CUI.text) chCiv:SetValue(fp.civilians and 1 or 0)

                label(pf, "Лимит суммы штрафа (0 = общий максимум):", 10, 174)
                local maxW = wang(pf, 330, 172, 110, fp.maxAmount or 0, 100000000)

                label(pf, "Роли с правом штрафовать:", 10, 206, CUI.text, 340)
                local rolesFine = vgui.Create("DScrollPanel", pf)
                rolesFine:SetPos(10, 230) rolesFine:SetSize(340, 240)
                rolesFine.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(22, 28, 38, 240)) end
                for _, rName in ipairs(fd.roles or {}) do
                    local c = vgui.Create("DCheckBoxLabel", rolesFine)
                    c:Dock(TOP) c:SetTall(20) c:DockMargin(8, 1, 4, 1)
                    c:SetText(rName) c:SetTextColor(CUI.text)
                    c:SetValue((fp.roles or {})[rName] and 1 or 0)
                    fineChks[rName] = c
                end

                label(pf, "Правила: superadmin может всегда. Лидер фракции —", 370, 230, CUI.dim, 340)
                label(pf, "всегда, если включён сам доступ. Отмеченные роли", 370, 252, CUI.dim, 340)
                label(pf, "штрафуют дополнительно к лидеру. Категории целей", 370, 274, CUI.dim, 340)
                label(pf, "(свои / другие фракции / граждане) настраиваются", 370, 296, CUI.dim, 340)
                label(pf, "отдельно. Лимит суммы перекрывает общий лимит.", 370, 318, CUI.dim, 340)

                -- ЕДИНОЕ сохранение: зарплаты + права штрафов одним пакетом
                local function doSave()
                    local roles, depts = {}, {}
                    for k, wn in pairs(rolesTbl) do roles[k] = math.floor(tonumber(wn:GetValue()) or 0) end
                    for k, wn in pairs(deptsTbl) do depts[k] = math.floor(tonumber(wn:GetValue()) or 0) end
                    local froles = {}
                    for k, c in pairs(fineChks) do if c:GetChecked() then froles[k] = true end end
                    act({
                        action = "save_entry", faction = name,
                        taxRate = math.Clamp((tonumber(taxW:GetValue()) or 0) / 100, 0, 1),
                        baseSalary = math.floor(tonumber(baseW:GetValue()) or 0),
                        salaryInterval = math.floor(tonumber(intW:GetValue()) or 600),
                        payFromBudget = pfb:GetChecked(),
                        roles = roles, departments = depts,
                        fine = {
                            enabled = chEn:GetChecked(),
                            allRoles = chAll:GetChecked(),
                            ownFaction = chOwn:GetChecked(),
                            otherFactions = chOther:GetChecked(),
                            civilians = chCiv:GetChecked(),
                            maxAmount = math.max(0, math.floor(tonumber(maxW:GetValue()) or 0)),
                            roles = froles,
                        },
                    })
                    -- окно НЕ переоткрываем: сервер пришлёт свежие данные,
                    -- и этот же фрейм пересоберётся через buildAdminUI.
                end

                local saveZ = btn(pz, "Сохранить", CUI.green, 150, 32)
                saveZ:SetPos(10, 520)
                saveZ.DoClick = doSave
                local payNow = btn(pz, "Выплатить ЗП сейчас", CUI.yellow, 180, 32)
                payNow:SetPos(170, 520)
                payNow.DoClick = function()
                    act({ action = "pay_now", faction = name })
                end

                local saveF = btn(pf, "Сохранить", CUI.green, 150, 32)
                saveF:SetPos(10, 520)
                saveF.DoClick = doSave

                -- GRM-FIX: применяем РЕАЛЬНЫЕ размеры страниц при раскладке
                pz.PerformLayout = function(_, w, h)
                    local half = math.max(90, (h - 140) / 2)
                    if IsValid(histZ)    then histZ:SetSize(270, math.max(60, h - 198 - 52)) end
                    if IsValid(rolesBox) then rolesBox:SetSize(math.max(200, w - 312), half) end
                    if IsValid(deptLbl)  then deptLbl:SetPos(300, 34 + half + 10) end
                    if IsValid(deptsBox) then
                        deptsBox:SetPos(300, 34 + half + 32)
                        deptsBox:SetSize(math.max(200, w - 312), math.max(40, half - 50))
                    end
                    if IsValid(saveZ)    then saveZ:SetPos(10, h - 42) end
                    if IsValid(payNow)   then payNow:SetPos(170, h - 42) end
                end
                pf.PerformLayout = function(_, w, h)
                    if IsValid(rolesFine) then rolesFine:SetSize(340, math.max(80, h - 230 - 56)) end
                    if IsValid(saveF)     then saveF:SetPos(10, h - 42) end
                end
            end

            list.OnRowSelected = function(_, _, ln) showEditor(ln.Faction) end
            local restore = f._restoreFaction
            if restore and (d.factions or {})[restore] then
                showEditor(restore)
            elseif #names > 0 then
                showEditor(names[1])
            end
        end

        -- ═══ ВКЛАДКА 5: ФИН.ЛОГ (все операции сервера) ═══
        do
            local p = sheetPanel("Фин.лог", "icon16/table.png")
            lbl(p, "Последние финансовые операции сервера — все системы двигающие деньги:", CUI.text, 12, 10, 760)
            local rf = btn(p, "Обновить", CUI.accent, 100, 24)
            rf:SetPos(844, 8)
            rf.DoClick = function() net.Start(NET_OPEN_ADMIN) net.SendToServer() end
            histBox(p, d.log or {}, 12, 40, 932, 480)
        end

        -- ═══ ВКЛАДКА 6: НАСТРОЙКИ ═══
        do
            local p = sheetPanel("Настройки", "icon16/cog.png")
            lbl(p, "Общие настройки экономики — применяются сразу, хранятся в grm_economy.json", CUI.text, 12, 8, 920)

            local wns, cks = {}, {}
            local function row(txt, key, y, pct, mx)
                lbl(p, txt, CUI.text, 12, y + 2, 340)
                local wn = vgui.Create("DNumberWang", p)
                wn:SetPos(360, y) wn:SetSize(100, 24)
                wn:SetMin(0) wn:SetMax(mx or 100000000)
                local v = tonumber(full[key]) or 0
                if pct then v = math.floor(v * 100 + 0.5) end
                wn:SetValue(v)
                wns[key] = { wn = wn, pct = pct }
            end
            local function chk(txt, key, y)
                local c = vgui.Create("DCheckBoxLabel", p)
                c:SetPos(12, y) c:SetSize(560, 22)
                c:SetText(txt) c:SetTextColor(CUI.text)
                c:SetValue(full[key] and 1 or 0)
                cks[key] = c
            end

            row("Налог по умолчанию, %", "DefaultTaxRate", 38, true, 100)
            row("Максимальный налог, %", "MaxTaxRate", 68, true, 100)
            row("Интервал ЗП по умолчанию, сек", "SalaryInterval", 98, false, 86400)
            row("Минимальный интервал ЗП, сек", "MinSalaryInterval", 128, false, 3600)
            row("Записей истории на фракцию", "HistorySize", 158, false, 500)
            row("Записей общего фин.лога", "LogSize", 188, false, 2000)
            row("Максимальный штраф", "FineMaxAmount", 218, false, 100000000)
            row("Дистанция использования банкомата", "UseDistance", 248, false, 1000)
            row("Стартовый баланс новичка", "StartBalance", 278, false, 100000000)

            lbl(p, "Название валюты:", CUI.text, 12, 312, 340)
            local cname = vgui.Create("DTextEntry", p)
            cname:SetPos(360, 308) cname:SetSize(160, 24)
            cname:SetText(tostring(full.CurrencyName or "GRM"))

            lbl(p, "Модель банкомата:", CUI.text, 12, 342, 340)
            local cmodel = vgui.Create("DTextEntry", p)
            cmodel:SetPos(360, 338) cmodel:SetSize(340, 24)
            cmodel:SetText(tostring(full.BankTerminalModel or "models/starless/atm.mdl"))

            chk("По умолчанию ЗП выплачивается из бюджета фракции", "PayFromBudget", 376)
            chk("Штрафы зачисляются в бюджет фракции штрафующего", "FineToBudget", 400)
            chk("Налоги с зарплат поступают в ГОС.БЮДЖЕТ (выкл — обратно фракции)", "TaxToState", 424)
            chk("Штрафы без фракции-получателя → гос.бюджет (выкл — сгорают)", "FinesToState", 448)

            local sbtn = btn(p, "Сохранить настройки", CUI.green, 240, 32)
            sbtn:SetPos(12, 486)
            sbtn.DoClick = function()
                local out = {}
                for key, rec in pairs(wns) do
                    local v = math.max(0, math.floor(tonumber(rec.wn:GetValue()) or 0))
                    out[key] = rec.pct and math.Clamp(v / 100, 0, 1) or v
                end
                for key, c in pairs(cks) do out[key] = c:GetChecked() end
                local nm = string.Trim(tostring(cname:GetValue() or ""))
                if nm ~= "" then out.CurrencyName = nm end
                local mdl = string.Trim(tostring(cmodel:GetValue() or ""))
                if mdl ~= "" then out.BankTerminalModel = mdl end
                act({ action = "config_save", config = out })
            end
        end
    end

    net.Receive(NET_ADMIN_DATA, function()
        local d = net.ReadTable() or {}
        if IsValid(adminFrame) then
            -- окно НЕ переоткрывается; UI пересобирается на месте,
            -- выбранная фракция восстанавливается через _restoreFaction.
            buildAdminUI(d)
        end
    end)

    net.Receive(NET_OPEN_ADMIN, function()
        if IsValid(adminFrame) then adminFrame:Remove() end
        adminFrame = frame("GRM Economy — единая админ-панель экономики", 1000, 660)
        -- открыли пустой каркас — сразу запрашиваем данные у сервера
        net.Start(NET_OPEN_ADMIN) net.SendToServer()
    end)

    -- ── БАНК-ТЕРМИНАЛ (БАНКОМАТ): вкладки — счёт / перевод / фракция ──
    net.Receive(NET_OPEN_BANK, function()
        local ent = net.ReadEntity()
        local d = net.ReadTable() or {}
        local f = frame("Банкомат GRM", 580, 520)

        local sheet = vgui.Create("DPropertySheet", f)
        sheet:Dock(FILL)
        sheet:DockMargin(8, 34, 8, 8)

        local function bankAction(t, amtEntry, extra)
            local a = math.floor(tonumber(amtEntry:GetValue()) or 0)
            if a <= 0 then return end
            net.Start(NET_BANK_ACT)
                net.WriteTable({ type = t, amount = a, to = extra })
            net.SendToServer()
            f:Close()
        end

        local function tabLabel(p, txt, col, x, y)
            local l = vgui.Create("DLabel", p)
            l:SetPos(x, y) l:SetSize(535, 24)
            l:SetText(txt) l:SetFont("GRM_Eco_Title")
            l:SetTextColor(col or CUI.text)
        end
        local function tabSmall(p, txt, col, x, y)
            local l = vgui.Create("DLabel", p)
            l:SetPos(x, y) l:SetSize(535, 20)
            l:SetText(txt) l:SetFont("GRM_Eco_Normal")
            l:SetTextColor(col or CUI.dim)
        end
        local function tabAmt(p, x, y)
            local amt = vgui.Create("DTextEntry", p)
            amt:SetPos(x, y) amt:SetSize(150, 28)
            amt:SetNumeric(true) amt:SetPlaceholderText("Сумма...")
            return amt
        end

        -- ВКЛАДКА 1: личный счёт — доступна ВСЕМ игрокам
        local p1 = vgui.Create("DPanel", sheet)
        p1:SetPaintBackground(false)
        p1.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, CUI.panel) end
        p1.Paint = function() end
        sheet:AddSheet("Мой счёт", p1, "icon16/money.png")
        tabLabel(p1, "Наличные: " .. money(d.balance or 0), CUI.green, 14, 12)
        tabLabel(p1, "Счёт в банке: " .. money(d.bank or 0), CUI.yellow, 14, 44)
        local amt1 = tabAmt(p1, 14, 86)
        local dep = btn(p1, "Внести на счёт", CUI.green, 160, 28)
        dep:SetPos(174, 86)
        dep.DoClick = function() bankAction("bank_deposit", amt1) end
        local wd = btn(p1, "Снять со счёта", CUI.accent, 160, 28)
        wd:SetPos(344, 86)
        wd.DoClick = function() bankAction("bank_withdraw", amt1) end
        tabSmall(p1, "Счёт в банке сохраняется всегда: при смерти теряются", CUI.dim, 14, 132)
        tabSmall(p1, "только наличные, деньги на счёте — в безопасности.", CUI.dim, 14, 154)

        -- ВКЛАДКА 2: перевод другому игроку (счёт -> счёт)
        local p2 = vgui.Create("DPanel", sheet)
        p2:SetPaintBackground(false)
        p2.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, CUI.panel) end
        p2.Paint = function() end
        sheet:AddSheet("Перевод", p2, "icon16/arrow_right.png")
        tabLabel(p2, "Ваш счёт: " .. money(d.bank or 0), CUI.yellow, 14, 12)
        local combo = vgui.Create("DComboBox", p2)
        combo:SetPos(14, 50) combo:SetSize(330, 28)
        combo:SetValue("Получатель (игроки онлайн)...")
        for _, pl in ipairs(d.players or {}) do combo:AddChoice(pl.nick, pl.sid64) end
        local amt2 = tabAmt(p2, 14, 92)
        local tr = btn(p2, "Перевести со счёта", CUI.green, 190, 28)
        tr:SetPos(174, 92)
        tr.DoClick = function()
            local _, sid = combo:GetSelected()
            if not sid then return end
            bankAction("bank_transfer", amt2, sid)
        end
        tabSmall(p2, "Списывается с вашего счёта, зачисляется на счёт получателя.", CUI.dim, 14, 138)

        -- ВКЛАДКА 3: фракция — только для членов фракции
        if (d.faction or "") ~= "" and d.factionData then
            local p3 = vgui.Create("DPanel", sheet)
        p3:SetPaintBackground(false)
        p3.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, CUI.panel) end
            p3.Paint = function() end
            sheet:AddSheet("Фракция", p3, "icon16/group.png")
            tabLabel(p3, d.faction .. ": бюджет " .. money(d.factionData.budget or 0), CUI.green, 14, 12)
            tabSmall(p3, "Налог: " .. math.floor((d.factionData.taxRate or 0) * 100) .. "%"
                .. "  |  Ваша ЗП: " .. money(d.mySalary or 0)
                .. (d.leader and "  |  Вы — ЛИДЕР" or ""), CUI.yellow, 14, 44)
            local amt3 = tabAmt(p3, 14, 76)
            local fdep = btn(p3, "Внести в бюджет (наличные)", CUI.accent, 210, 28)
            fdep:SetPos(174, 76)
            fdep.DoClick = function() bankAction("deposit", amt3) end
            local fwd = btn(p3, "Вывести (лидер)", CUI.yellow, 150, 28)
            fwd:SetPos(394, 76)
            fwd.DoClick = function() bankAction("withdraw", amt3) end

            if istable(d.factionData.history) then
                tabSmall(p3, "Последние операции фракции:", CUI.text, 14, 118)
                local hist = vgui.Create("DScrollPanel", p3)
                hist:SetPos(14, 142) hist:SetSize(535, 290)
                hist.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, CUI.panel) end
                local h = d.factionData.history
                for i = #h, math.max(1, #h - 30), -1 do
                    local rec = h[i]
                    local l = vgui.Create("DLabel", hist)
                    l:Dock(TOP) l:SetTall(16) l:DockMargin(8, 2, 4, 1)
                    l:SetFont("GRM_Eco_Small") l:SetTextColor(CUI.dim)
                    l:SetText(os.date("%d.%m %H:%M", rec.t or 0) .. " — " .. tostring(rec.s or ""))
                end
            end
        end
    end)

    concommand.Add("grm_salary_admin", function()
        net.Start(NET_OPEN_ADMIN) net.SendToServer()
    end)

    print("[GRM Economy] Unified Economy v2.3 — клиент загружен")
end
