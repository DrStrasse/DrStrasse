--[[--------------------------------------------------------------------
    GRM Unified Economy v2.1 (Код 43)

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
    util.AddNetworkString(NET_OPEN_ADMIN)
    util.AddNetworkString(NET_ADMIN_DATA)
    util.AddNetworkString(NET_ADMIN_ACT)
    util.AddNetworkString(NET_OPEN_BANK)
    util.AddNetworkString(NET_BANK_ACT)
    util.AddNetworkString(NET_SYNC)
    util.AddNetworkString(NET_INFO)

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
        return e
    end

    local function addHistory(name, text)
        local h = entry(name).history
        h[#h + 1] = { t = os.time(), s = tostring(text) }
        while #h > E.Config.HistorySize do table.remove(h, 1) end
        dirty = true
    end

    -- ── Сохранение / загрузка / импорт легаси ───────────────
    local function save()
        if not dirty then return end
        file.Write(DATA_FILE, util.TableToJSON(E.Data, true) or "{}")
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

    local function load()
        local t = tryJSON(DATA_FILE)
        if t and istable(t.factions) then
            E.Data = t
        else
            E.Data = { version = 2, factions = {} }
            importLegacy() -- первый запуск: подтянуть данные старых модулей
        end
        E.Data.accounts = istable(E.Data.accounts) and E.Data.accounts or {}
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
        GRM.TakeMoney(ply, amount)
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
        GRM.GiveMoney(ply, amount)
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
                    e.budget = math.max(0, e.budget + tax)
                    GRM.GiveMoney(ply, net)
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

    timer.Create("GRM_Economy_AutoSave", 120, 0, save)
    hook.Add("ShutDown", "GRM_Economy_Save", function() dirty = true save() end)

    -- ── ШТРАФЫ ──────────────────────────────────────────────
    function E.Fine(issuer, target, amount, reason)
        if not IsValid(target) or not target:IsPlayer() then return false, "Нет цели" end
        amount = math.floor(tonumber(amount) or 0)
        if amount <= 0 then return false, "Сумма должна быть > 0" end
        if amount > E.Config.FineMaxAmount then amount = E.Config.FineMaxAmount end
        if GRM.GetBalance(target) <= 0 then return false, "У игрока нет средств" end

        local issued = math.min(amount, GRM.GetBalance(target))
        GRM.TakeMoney(target, issued)

        local receiptName = factionOf(issuer)
        if receiptName and E.Config.FineToBudget then
            GRM.FactionBudgetAdd(receiptName, issued,
                ("Штраф %s от %s: %s"):format(target:Nick(), IsValid(issuer) and issuer:Nick() or "система", money(issued)))
        end

        notify(target,
            ("ШТРАФ: -%s | %s | от: %s"):format(money(issued), tostring(reason or "без причины"),
                IsValid(issuer) and issuer:Nick() or "система"),
            255, 80, 70)
        if IsValid(issuer) and issuer ~= target then
            notify(issuer, "Штраф выписан: " .. target:Nick() .. " -" .. money(issued)
                .. (receiptName and (" → бюджет [" .. receiptName .. "]") or ""), 100, 220, 100)
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
        timer.Simple(5, function() if IsValid(ply) then syncPlayer(ply) end end)
    end)

    -- ── АДМИН-ПАНЕЛЬ: данные ────────────────────────────────
    local function buildAdminData()
        local factions = {}
        if Factions then
            for name, f in pairs(Factions) do
                if istable(f) then
                    local roles, depts = {}, {}
                    if istable(f.Roles) then for _, r in ipairs(f.Roles) do roles[#roles + 1] = tostring(r) end end
                    if istable(f.Departments) then for _, d in ipairs(f.Departments) do depts[#depts + 1] = tostring(d) end end
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
        return { factions = factions, config = {
            maxTax = E.Config.MaxTaxRate, minInterval = E.Config.MinSalaryInterval,
        } }
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
        if name == "" then return end
        local e = entry(name)

        if a.action == "save_entry" then
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
            dirty = true
            save()
            addHistory(name, "Настройки обновлены админом " .. ply:Nick())
            notify(ply, "Фракция [" .. name .. "] сохранена.", 100, 220, 100)
        elseif a.action == "budget_give" or a.action == "budget_take" then
            local amt = math.max(0, math.floor(tonumber(a.amount) or 0))
            if a.action == "budget_take" then amt = -math.min(amt, e.budget) end
            GRM.FactionBudgetAdd(name, amt, ("Админ %s: %s%s"):format(ply:Nick(), amt > 0 and "+" or "", money(math.abs(amt))))
            notify(ply, "Бюджет [" .. name .. "]: " .. money(e.budget), 100, 220, 255)
        elseif a.action == "pay_now" then
            e.nextPay = os.time()
            notify(ply, "Принудительная выплата запрошена для [" .. name .. "].", 255, 200, 80)
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
            -- /fine <сумма> [причина...] — цель: игрок в перекрестии
            local amt = math.floor(tonumber(args[2]) or 0)
            local reason = table.concat(args, " ", 3)
            if amt <= 0 then notify(ply, "/fine <сумма> [причина]", 255, 100, 100) return "" end
            local tr = ply:GetEyeTrace()
            local target = tr.Entity
            if not (IsValid(target) and target:IsPlayer() and target:GetPos():DistToSqr(ply:GetPos()) <= 250 * 250) then
                notify(ply, "Смотрите на игрока (до 250 юнитов).", 255, 100, 100)
                return ""
            end
            local tf = factionOf(target)
            local allowed = ply:IsSuperAdmin() or (tf and isLeaderOf(ply, Factions[tf]))
            if not allowed then
                notify(ply, "Штрафовать можно только членов своей фракции (лидер) или суперадмином.", 255, 100, 100)
                return ""
            end
            if target == ply then notify(ply, "Нельзя штрафовать себя.", 255, 100, 100) return "" end
            if ply:IsSuperAdmin() and tf then
                -- суперадмин может любого; лидер — только свою фракцию
            elseif not ply:IsSuperAdmin() and not (tf and isLeaderOf(ply, Factions[tf])) then
                return ""
            end
            E.Fine(ply, target, amt, reason ~= "" and reason or "нарушение")
            return ""
        end
    end)

    -- ── Консоль ─────────────────────────────────────────────
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
        else
            print("[GRM Economy] grm_economy <save|list>")
        end
    end)

    load()
    print("[GRM Economy] Unified Economy v2.1 загружена: фракций " .. table.Count(E.Data.factions))
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
        f.Paint = function(_, pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, CUI.bg)
            draw.RoundedBoxEx(8, 0, 0, pw, 36, Color(27, 35, 48), true, true, false, false)
            draw.SimpleText(title, "GRM_Eco_Title", 13, 18, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
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

    net.Receive(NET_INFO, function()
        chat.AddText(Color(120, 220, 120), "[Экономика] ", color_white, net.ReadString())
    end)

    -- ── АДМИН-ПАНЕЛЬ (обновляется НА МЕСТЕ — без переоткрытия) ──
    local adminFrame = nil

    local function buildAdminUI(d)
        if not IsValid(adminFrame) then return end
        adminFrame:Clear()

        local f = adminFrame
        local tabs = vgui.Create("DPropertySheet", f)
        tabs:Dock(FILL) tabs:DockMargin(8, 44, 8, 8)

        local pnl = vgui.Create("DPanel", tabs) pnl:SetPaintBackground(false)

        local listW = 230
        local list = vgui.Create("DListView", pnl)
        list:SetPos(4, 4) list:SetSize(listW, pnl:GetTall() - 8)
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
        editor:SetPos(listW + 12, 4) editor:SetSize(pnl:GetWide() - listW - 16, pnl:GetTall() - 8)
        editor.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, CUI.panel) end

        local function showEditor(name)
            editor:Clear()
            local fd = (d.factions or {})[name]
            if not fd then return end
            local e = fd.entry or {}
            -- запоминаем выбранную фракцию для восстановления после
            -- пересборки свежими данными (никаких переоткрытий окна!)
            f._restoreFaction = name
            local rolesTbl, deptsTbl = {}, {}

            local function label(txt, x, y, col)
                local l = vgui.Create("DLabel", editor)
                l:SetPos(x, y) l:SetSize(200, 22)
                l:SetText(txt) l:SetFont("GRM_Eco_Normal")
                l:SetTextColor(col or CUI.dim)
            end
            local function wang(x, y, w, val, maxv)
                local wn = vgui.Create("DNumberWang", editor)
                wn:SetPos(x, y) wn:SetSize(w, 24)
                wn:SetMin(0) wn:SetMax(maxv or 1000000) wn:SetValue(val or 0)
                return wn
            end

            label("Фракция: " .. name .. "  (онлайн " .. (fd.online or 0) .. "/" .. (fd.members or 0) .. ")", 12, 8, CUI.text)
            label("Налог, %:", 12, 40)
            local taxW = wang(120, 40, 80, math.floor((e.taxRate or 0) * 100), (d.config and math.floor((d.config.maxTax or 0.5) * 100)) or 50)
            label("Базовая ЗП:", 12, 72)
            local baseW = wang(120, 72, 110, e.baseSalary or 0)
            label("Интервал ЗП, сек:", 12, 104)
            local intW = wang(160, 104, 90, e.salaryInterval or 600)

            local pfb = vgui.Create("DCheckBoxLabel", editor)
            pfb:SetPos(12, 136) pfb:SetSize(280, 24)
            pfb:SetText("Выплачивать ЗП из бюджета фракции")
            pfb:SetTextColor(CUI.text) pfb:SetValue(e.payFromBudget and 1 or 0)

            -- ЗП по ролям
            local rolesBox = vgui.Create("DScrollPanel", editor)
            rolesBox:SetPos(300, 40) rolesBox:SetSize(editor:GetWide() - 312, (editor:GetTall() - 120) / 2 - 10)
            rolesBox.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(22, 28, 38, 240)) end
            label("ЗП по ролям:", 300, 18, CUI.text)
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

            -- ЗП по отделам
            local deptsBox = vgui.Create("DScrollPanel", editor)
            deptsBox:SetPos(300, 44 + (editor:GetTall() - 120) / 2)
            deptsBox:SetSize(editor:GetWide() - 312, (editor:GetTall() - 120) / 2 - 30)
            deptsBox.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(22, 28, 38, 240)) end
            label("ЗП по отделам:", 300, 24 + (editor:GetTall() - 120) / 2, CUI.text)
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

            local saveB = btn(editor, "💾 Сохранить", CUI.green, 150, 32)
            saveB:SetPos(12, editor:GetTall() - 44)
            saveB.DoClick = function()
                local roles, depts = {}, {}
                for k, wn in pairs(rolesTbl) do roles[k] = math.floor(tonumber(wn:GetValue()) or 0) end
                for k, wn in pairs(deptsTbl) do depts[k] = math.floor(tonumber(wn:GetValue()) or 0) end
                net.Start(NET_ADMIN_ACT)
                    net.WriteTable({
                        action = "save_entry", faction = name,
                        taxRate = math.Clamp((tonumber(taxW:GetValue()) or 0) / 100, 0, 1),
                        baseSalary = math.floor(tonumber(baseW:GetValue()) or 0),
                        salaryInterval = math.floor(tonumber(intW:GetValue()) or 600),
                        payFromBudget = pfb:GetChecked(),
                        roles = roles, departments = depts,
                    })
                net.SendToServer()
                -- окно НЕ переоткрываем: сервер пришлёт свежие данные,
                -- и этот же фрейм пересоберётся через buildAdminUI.
            end

            local payNow = btn(editor, "⚡ Выплатить ЗП сейчас", CUI.yellow, 190, 32)
            payNow:SetPos(170, editor:GetTall() - 44)
            payNow.DoClick = function()
                net.Start(NET_ADMIN_ACT)
                    net.WriteTable({ action = "pay_now", faction = name })
                net.SendToServer()
            end

            -- История
            local hist = vgui.Create("DScrollPanel", editor)
            hist:SetPos(12, 170) hist:SetSize(270, editor:GetTall() - 170 - 54)
            hist.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(22, 28, 38, 240)) end
            label("История:", 12, 148, CUI.text)
            local h = e.history or {}
            for i = #h, math.max(1, #h - 40), -1 do
                local rec = h[i]
                local l = vgui.Create("DLabel", hist)
                l:Dock(TOP) l:SetTall(16) l:DockMargin(6, 1, 4, 1)
                l:SetFont("GRM_Eco_Small") l:SetTextColor(CUI.dim)
                l:SetText(os.date("%d.%m %H:%M", rec.t or 0) .. " — " .. tostring(rec.s or ""))
            end

            list._sel = name
        end

        list.OnRowSelected = function(_, _, ln) showEditor(ln.Faction) end
        local restore = f._restoreFaction
        if restore and (d.factions or {})[restore] then
            showEditor(restore)
        elseif #names > 0 then
            showEditor(names[1])
        end

        tabs:AddSheet("Фракции и зарплаты", pnl, "icon16/money.png")
        f._selectFaction = function(n) f._restoreFaction = n showEditor(n) end
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
        adminFrame = frame("GRM Economy — админ-панель зарплат и бюджетов", 900, 620)
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

    print("[GRM Economy] Unified Economy v2.1 — клиент загружен")
end
