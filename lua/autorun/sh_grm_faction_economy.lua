--[[--------------------------------------------------------------------
    GRM Economy — Фракционная экономика (Sandbox)
    Совместим с системой фракций из factions_fixed.lua + factions_extended.

    Возможности:
      • Фракционный бюджет (отдельный кошелёк фракции)
      • Налоговая система (периодические отчисления участников → бюджет фракции)
      • Персональный налог (переопределяется через AdminMenu)
      • Команды управления бюджетом:
          !fbudget             — просмотр бюджета своей фракции
          !fpay <сумма>        — перевести из личного кошелька в бюджет фракции
          !fwithdraw <сумма>   — (только лидер) вывести из бюджета
          !fpayall <сумма>     — (только лидер) выплата всем участникам из бюджета
          !fsettax <процент>   — (только лидер) установить налоговую ставку 0-50%
          !fbudgetinfo         — (только admin) информация по всем фракциям
      • Интеграция с Factions (из factions_fixed.lua):
          Используется глобальная таблица Factions и функция getFactionOfPlayer
      • Публичное API для AdminMenu:
          GRM.FactionBudgetGet(name) → number
          GRM.FactionBudgetAdd(name, delta)
          GRM.FactionTaxGet(name) → number (0–0.5)
          GRM.FactionTaxSet(name, rate)
--------------------------------------------------------------------]]

if CLIENT then
    net.Receive("grm_faction_budget", function()
        local factionName = net.ReadString()
        local budget      = net.ReadInt(32)
        local taxRate     = net.ReadFloat()

        GRM = GRM or {}
        GRM.FactionName   = factionName
        GRM.FactionBudget = budget
        GRM.FactionTax    = taxRate
    end)
    return
end

-- ================================================================
--  СЕРВЕРНАЯ ЧАСТЬ
-- ================================================================
util.AddNetworkString("grm_faction_budget")
util.AddNetworkString("grm_faction_pay")
util.AddNetworkString("grm_faction_withdraw")

-- ── Файл хранения бюджетов ───────────────────────────────────────
local BUDGET_FILE    = "grm_faction_budgets.json"
local FactionBudgets = {}  -- [factionName] = { budget = N, taxRate = 0.05 }

local function loadBudgets()
    if not file.Exists(BUDGET_FILE, "DATA") then return end
    local raw = file.Read(BUDGET_FILE, "DATA") or ""
    local ok, t = pcall(util.JSONToTable, raw)
    if ok and istable(t) then FactionBudgets = t end
end

local function saveBudgets()
    local ok, enc = pcall(util.TableToJSON, FactionBudgets, true)
    if ok then file.Write(BUDGET_FILE, enc) end
end

loadBudgets()

-- ── Вспомогательные функции ──────────────────────────────────────
local function getFactionEntry(name)
    if not FactionBudgets[name] then
        FactionBudgets[name] = { budget = 0, taxRate = 0.05 }
    end
    -- Нормализуем на случай старых записей без поля
    FactionBudgets[name].budget  = FactionBudgets[name].budget  or 0
    FactionBudgets[name].taxRate = FactionBudgets[name].taxRate or 0.05
    return FactionBudgets[name]
end

local function getPlayerFaction(ply)
    if not Factions then return nil, nil end
    local sid = ply:SteamID()
    for name, f in pairs(Factions) do
        if istable(f) and istable(f.Members) and f.Members[sid] then
            return name, f
        end
    end
    return nil, nil
end

local function isLeader(ply, faction)
    if not faction then return false end
    return faction.Leader == ply:SteamID()
end

local function pushFactionBudget(ply)
    if not IsValid(ply) then return end
    local fName = getPlayerFaction(ply)
    if not fName then return end
    local entry = getFactionEntry(fName)

    net.Start("grm_faction_budget")
        net.WriteString(fName)
        net.WriteInt(math.Clamp(entry.budget, -2147483648, 2147483647), 32)
        net.WriteFloat(entry.taxRate)
    net.Send(ply)
end

-- ================================================================
--  ПУБЛИЧНОЕ API ДЛЯ ДРУГИХ МОДУЛЕЙ (AdminMenu, etc.)
-- ================================================================
function GRM.FactionBudgetGet(name)
    if not name or not FactionBudgets[name] then return 0 end
    return FactionBudgets[name].budget or 0
end

function GRM.FactionBudgetAdd(name, delta)
    if not name then return end
    local entry  = getFactionEntry(name)
    entry.budget = math.max(0, entry.budget + math.floor(delta))
    saveBudgets()

    -- Синхронизируем онлайн-участников фракции
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            local fn = getPlayerFaction(ply)
            if fn == name then pushFactionBudget(ply) end
        end
    end
end

function GRM.FactionTaxGet(name)
    if not name or not FactionBudgets[name] then return 0.05 end
    return FactionBudgets[name].taxRate or 0.05
end

function GRM.FactionTaxSet(name, rate)
    if not name then return end
    local entry  = getFactionEntry(name)
    entry.taxRate = math.Clamp(tonumber(rate) or 0.05, 0, 0.5)
    saveBudgets()
end

-- ================================================================
--  НАЧИСЛЕНИЕ НАЛОГОВ (раз в 5 минут)
-- ================================================================
local TAX_INTERVAL = 300

timer.Create("GRM_TaxTimer", TAX_INTERVAL, 0, function()
    if not Factions then return end
    local changed = {}   -- фракции, у которых изменился бюджет

    for _, ply in ipairs(player.GetAll()) do
        if not IsValid(ply) then continue end

        local fName, faction = getPlayerFaction(ply)
        if not fName or not faction then continue end

        -- Лидер налог не платит
        if faction.Leader == ply:SteamID() then continue end

        local entry = getFactionEntry(fName)

        -- Персональный налог (от AdminMenu) имеет приоритет над фракционным
        local rate
        local ptax = GRM.GetPlayerTaxRate and GRM.GetPlayerTaxRate(ply)
        if ptax ~= nil then
            rate = math.Clamp(ptax, 0, 0.5)
        else
            rate = math.Clamp(entry.taxRate, 0, 0.5)
        end
        if rate <= 0 then continue end

        local balance = GRM.GetBalance(ply)
        local tax     = math.floor(balance * rate)
        if tax <= 0 then continue end

        GRM.TakeMoney(ply, tax)
        entry.budget = entry.budget + tax
        changed[fName] = true

        local isPersonal = (ptax ~= nil)
        GRM.Notify(ply,
            (isPersonal and "Персональный налог" or ("Налог фракции [" .. fName .. "]")) ..
            ": -" .. GRM.Format(tax) .. " (" .. math.floor(rate * 100) .. "%)",
            255, 180, 60
        )
    end

    if next(changed) then saveBudgets() end

    -- Синхронизируем всех
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then pushFactionBudget(ply) end
    end
end)

-- ── Синхронизация при входе ──────────────────────────────────────
hook.Add("PlayerInitialSpawn", "GRM_FactionBudgetSync", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) then pushFactionBudget(ply) end
    end)
end)

-- ================================================================
--  ЧАТ-КОМАНДЫ
-- ================================================================
hook.Add("PlayerSay", "GRM_FactionEconCmds", function(ply, text)
    local args = string.Explode(" ", text:Trim())
    local cmd  = (args[1] or ""):lower()

    -- !fbudget
    if cmd == "!fbudget" then
        local fName = getPlayerFaction(ply)
        if not fName then
            GRM.Notify(ply, "Вы не состоите ни в одной фракции", 255,100,100); return ""
        end
        local entry = getFactionEntry(fName)
        ply:ChatPrint(string.format(
            "[GRM] Фракция [%s] | Бюджет: %s | Налог: %d%%",
            fName,
            GRM.Format(entry.budget),
            math.floor(entry.taxRate * 100)
        ))
        pushFactionBudget(ply)
        return ""
    end

    -- !fpay <сумма>
    if cmd == "!fpay" or cmd == "!fdeposit" then
        local amount = math.floor(tonumber(args[2]) or 0)
        local fName  = getPlayerFaction(ply)
        if not fName then
            GRM.Notify(ply, "Вы не состоите ни в одной фракции", 255,100,100); return ""
        end
        if amount <= 0 then
            GRM.Notify(ply, "!fpay <сумма>", 255,100,100); return ""
        end
        if not GRM.HasMoney(ply, amount) then
            GRM.Notify(ply, "Недостаточно средств", 255,100,100); return ""
        end
        GRM.TakeMoney(ply, amount)
        GRM.FactionBudgetAdd(fName, amount)   -- используем публичное API (включает sync)
        GRM.Notify(ply, "Внесено в бюджет [" .. fName .. "]: " .. GRM.Format(amount), 100,220,100)
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p ~= ply then
                local fn2 = getPlayerFaction(p)
                if fn2 == fName then
                    GRM.Notify(p, ply:Nick() .. " внёс " .. GRM.Format(amount) .. " в бюджет фракции", 100,200,255)
                end
            end
        end
        return ""
    end

    -- !fwithdraw <сумма>
    if cmd == "!fwithdraw" then
        local amount      = math.floor(tonumber(args[2]) or 0)
        local fName, faction = getPlayerFaction(ply)
        if not fName then
            GRM.Notify(ply, "Вы не состоите ни в одной фракции", 255,100,100); return ""
        end
        if not isLeader(ply, faction) and not ply:IsAdmin() then
            GRM.Notify(ply, "Только лидер фракции может выводить средства", 255,100,100); return ""
        end
        if amount <= 0 then
            GRM.Notify(ply, "!fwithdraw <сумма>", 255,100,100); return ""
        end
        local cur = GRM.FactionBudgetGet(fName)
        if cur < amount then
            GRM.Notify(ply, "В бюджете только: " .. GRM.Format(cur), 255,100,100); return ""
        end
        GRM.FactionBudgetAdd(fName, -amount)
        GRM.GiveMoney(ply, amount)
        GRM.Notify(ply, "Выведено из бюджета [" .. fName .. "]: " .. GRM.Format(amount), 100,220,100)
        return ""
    end

    -- !fpayall <сумма>
    if cmd == "!fpayall" then
        local amount      = math.floor(tonumber(args[2]) or 0)
        local fName, faction = getPlayerFaction(ply)
        if not fName then
            GRM.Notify(ply, "Вы не состоите ни в одной фракции", 255,100,100); return ""
        end
        if not isLeader(ply, faction) and not ply:IsAdmin() then
            GRM.Notify(ply, "Только лидер фракции может выплачивать зарплату", 255,100,100); return ""
        end
        if amount <= 0 then
            GRM.Notify(ply, "!fpayall <сумма>", 255,100,100); return ""
        end

        local members = {}
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and getPlayerFaction(p) == fName then
                table.insert(members, p)
            end
        end

        local total = amount * #members
        local cur   = GRM.FactionBudgetGet(fName)
        if cur < total then
            GRM.Notify(ply,
                "Недостаточно в бюджете. Нужно: " .. GRM.Format(total) ..
                ", есть: " .. GRM.Format(cur),
                255,100,100
            ); return ""
        end

        GRM.FactionBudgetAdd(fName, -total)
        for _, p in ipairs(members) do
            GRM.GiveMoney(p, amount)
            GRM.Notify(p, "Выплата от фракции [" .. fName .. "]: " .. GRM.Format(amount), 100,220,255)
        end

        GRM.Notify(ply,
            "Выплачено " .. GRM.Format(amount) .. " × " .. #members ..
            " участников (итого: " .. GRM.Format(total) .. ")",
            100, 220, 100
        )
        return ""
    end

    -- !fsettax <процент>
    if cmd == "!fsettax" then
        local pct = tonumber(args[2])
        if not pct then GRM.Notify(ply, "!fsettax <0-50>", 255,100,100); return "" end
        pct = math.Clamp(math.floor(pct), 0, 50)

        local fName, faction = getPlayerFaction(ply)
        if not fName then
            GRM.Notify(ply, "Вы не состоите ни в одной фракции", 255,100,100); return ""
        end
        if not isLeader(ply, faction) and not ply:IsAdmin() then
            GRM.Notify(ply, "Только лидер фракции может менять налог", 255,100,100); return ""
        end

        GRM.FactionTaxSet(fName, pct / 100)
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) then
                local fn2 = getPlayerFaction(p)
                if fn2 == fName then
                    GRM.Notify(p,
                        "Налог фракции [" .. fName .. "] изменён: " .. pct .. "% (каждые 5 мин)",
                        255, 200, 80
                    )
                    pushFactionBudget(p)
                end
            end
        end
        return ""
    end

    -- !fbudgetinfo (только admin)
    if cmd == "!fbudgetinfo" then
        if not ply:IsAdmin() then return end
        ply:ChatPrint("[GRM] Бюджеты фракций:")
        for name, entry in pairs(FactionBudgets) do
            ply:ChatPrint(string.format(
                "  [%s] бюджет: %s | налог: %d%%",
                name,
                GRM.Format(entry.budget or 0),
                math.floor((entry.taxRate or 0) * 100)
            ))
        end
        return ""
    end
end)

print("[GRM] Faction Economy — загружен")
