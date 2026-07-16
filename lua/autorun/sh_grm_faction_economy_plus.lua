--[[--------------------------------------------------------------------
    GRM Faction Economy Plus
    • Фракционные бюджеты.
    • Налоги.
    • Зарплаты по фракциям, рангам, отделам.
    • Надбавки по рангам/отделам.
    • История транзакций бюджета.
    • Интерактивная админ-панель /salary_admin.

    Файл:
      data/grm_faction_economy_plus.json
--------------------------------------------------------------------]]

GRM = GRM or {}
GRM.FactionEconomyPlus = GRM.FactionEconomyPlus or {}
local ECO = GRM.FactionEconomyPlus

ECO.Config = ECO.Config or {
    DataFile = "grm_faction_economy_plus.json",
    DefaultTaxRate = 0.05,
    SalaryInterval = 600,
    HistoryLimit = 100,
    PaySalariesFromBudget = true,
}

local NET_ADMIN_OPEN = "GRM_FEco_AdminOpen"
local NET_ADMIN_DATA = "GRM_FEco_AdminData"
local NET_ADMIN_SAVE = "GRM_FEco_AdminSave"
local NET_INFO       = "GRM_FEco_Info"
local NET_SYNC       = "GRM_FEco_Sync"

local function readJSON(path, fallback)
    fallback = fallback or {}
    if not file.Exists(path, "DATA") then return table.Copy(fallback) end
    local raw = file.Read(path, "DATA") or ""
    if raw == "" then return table.Copy(fallback) end
    local ok, data = pcall(util.JSONToTable, raw)
    if ok and istable(data) then return data end
    return table.Copy(fallback)
end

local function writeJSON(path, data)
    file.Write(path, util.TableToJSON(data or {}, true))
end

local function getFactionInfo(ply)
    if not IsValid(ply) or not Factions then return nil, nil, nil, nil end
    local sid, sid64 = ply:SteamID(), ply:SteamID64()
    for name, f in pairs(Factions) do
        if istable(f) and istable(f.Members) then
            local m = f.Members[sid] or f.Members[sid64]
            if istable(m) then return name, m.Role, m.Department, f end
        end
    end
    return nil, nil, nil, nil
end

local function isLeader(ply, f)
    if not IsValid(ply) or not istable(f) then return false end
    return f.Leader == ply:SteamID() or f.Leader == ply:SteamID64()
end

local function money(n)
    if GRM.Format then return GRM.Format(n) end
    return tostring(n) .. " GRM"
end

local function notify(ply, msg)
    if not IsValid(ply) then return end
    net.Start(NET_INFO) net.WriteString(msg or "") net.Send(ply)
end

if SERVER then
    AddCSLuaFile()

    util.AddNetworkString(NET_ADMIN_OPEN)
    util.AddNetworkString(NET_ADMIN_DATA)
    util.AddNetworkString(NET_ADMIN_SAVE)
    util.AddNetworkString(NET_INFO)
    util.AddNetworkString(NET_SYNC)

    ECO.Data = ECO.Data or readJSON(ECO.Config.DataFile, {})

    local function normalizeEntry(name)
        ECO.Data[name] = ECO.Data[name] or {}
        local e = ECO.Data[name]
        e.budget = math.max(0, math.floor(tonumber(e.budget) or 0))
        e.taxRate = math.Clamp(tonumber(e.taxRate) or ECO.Config.DefaultTaxRate or 0.05, 0, 0.5)
        e.baseSalary = math.max(0, math.floor(tonumber(e.baseSalary) or 0))
        e.roleSalaries = istable(e.roleSalaries) and e.roleSalaries or {}
        e.departmentSalaries = istable(e.departmentSalaries) and e.departmentSalaries or {}
        e.roleBonuses = istable(e.roleBonuses) and e.roleBonuses or {}
        e.departmentBonuses = istable(e.departmentBonuses) and e.departmentBonuses or {}
        e.salaryInterval = math.max(60, math.floor(tonumber(e.salaryInterval) or ECO.Config.SalaryInterval or 600))
        e.payFromBudget = e.payFromBudget ~= false
        e.history = istable(e.history) and e.history or {}
        return e
    end

    local function save()
        for name in pairs(ECO.Data) do normalizeEntry(name) end
        writeJSON(ECO.Config.DataFile, ECO.Data)
    end

    local function addHistory(factionName, typ, amount, by, note)
        local e = normalizeEntry(factionName)
        e.history[#e.history + 1] = { time = os.time(), type = typ, amount = math.floor(amount or 0), by = by or "system", note = note or "" }
        while #e.history > (ECO.Config.HistoryLimit or 100) do table.remove(e.history, 1) end
    end

    local function sync(ply)
        local fName = getFactionInfo(ply)
        if not fName then return end
        local e = normalizeEntry(fName)
        net.Start(NET_SYNC)
            net.WriteString(fName)
            net.WriteTable(e)
        net.Send(ply)
    end

    function GRM.FactionBudgetGet(name) return normalizeEntry(name).budget end

    function GRM.FactionBudgetAdd(name, delta, reason)
        local e = normalizeEntry(name)
        e.budget = math.max(0, e.budget + math.floor(tonumber(delta) or 0))
        addHistory(name, delta >= 0 and "income" or "expense", delta, "api", reason or "API")
        save()
        for _, p in ipairs(player.GetAll()) do if getFactionInfo(p) == name then sync(p) end end
    end

    function GRM.FactionTaxGet(name) return normalizeEntry(name).taxRate end

    function GRM.FactionTaxSet(name, rate) normalizeEntry(name).taxRate = math.Clamp(tonumber(rate) or 0, 0, 0.5); save() end

    local function calcSalary(ply)
        local fName, role, dept = getFactionInfo(ply)
        if not fName then return 0, nil end
        local e = normalizeEntry(fName)
        local total = e.baseSalary
        total = total + math.floor(tonumber(e.roleSalaries[role]) or 0)
        total = total + math.floor(tonumber(e.departmentSalaries[dept]) or 0)
        total = total + math.floor(tonumber(e.roleBonuses[role]) or 0)
        total = total + math.floor(tonumber(e.departmentBonuses[dept]) or 0)
        return math.max(0, total), fName
    end

    local function paySalary(ply)
        if not IsValid(ply) then return end
        local amount, fName = calcSalary(ply)
        if not fName or amount <= 0 then return end
        local e = normalizeEntry(fName)
        if e.payFromBudget then
            if e.budget < amount then
                notify(ply, "Зарплата не выплачена: в бюджете фракции недостаточно средств.")
                return
            end
            e.budget = e.budget - amount
            addHistory(fName, "salary", -amount, ply:SteamID(), "Зарплата " .. ply:Nick())
        end
        if GRM.GiveMoney then GRM.GiveMoney(ply, amount) end
        notify(ply, "Зарплата фракции [" .. fName .. "]: " .. money(amount))
        save(); sync(ply)
    end

    timer.Create("GRM_FEco_SalaryThink", 10, 0, function()
        local now = CurTime()
        for _, ply in ipairs(player.GetAll()) do
            if not IsValid(ply) then continue end
            local _, fName = calcSalary(ply)
            if not fName then continue end
            local e = normalizeEntry(fName)
            ply.GRM_FEco_NextSalary = ply.GRM_FEco_NextSalary or (now + e.salaryInterval)
            if now >= ply.GRM_FEco_NextSalary then
                ply.GRM_FEco_NextSalary = now + e.salaryInterval
                paySalary(ply)
            end
        end
    end)

    timer.Create("GRM_FEco_TaxThink", 300, 0, function()
        for _, ply in ipairs(player.GetAll()) do
            local fName, _, _, f = getFactionInfo(ply)
            if not fName or isLeader(ply, f) then continue end
            local e = normalizeEntry(fName)
            local bal = GRM.GetBalance and GRM.GetBalance(ply) or 0
            local tax = math.floor(bal * e.taxRate)
            if tax > 0 and GRM.TakeMoney then
                GRM.TakeMoney(ply, tax)
                e.budget = e.budget + tax
                addHistory(fName, "tax", tax, ply:SteamID(), "Налог " .. ply:Nick())
                notify(ply, "Налог фракции [" .. fName .. "]: -" .. money(tax))
            end
        end
        save()
    end)

    local function buildAdminData()
        local out = { factions = {}, economy = ECO.Data }
        for name, f in pairs(Factions or {}) do
            out.factions[name] = { Roles = f.Roles or {}, Departments = f.Departments or {}, Leader = f.Leader }
            normalizeEntry(name)
        end
        return out
    end

    net.Receive(NET_ADMIN_OPEN, function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        net.Start(NET_ADMIN_DATA) net.WriteTable(buildAdminData()) net.Send(ply)
    end)

    net.Receive(NET_ADMIN_SAVE, function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        local data = net.ReadTable() or {}
        ECO.Data = data
        for name in pairs(Factions or {}) do normalizeEntry(name) end
        save()
        notify(ply, "Настройки зарплат и бюджетов сохранены.")
        net.Start(NET_ADMIN_DATA) net.WriteTable(buildAdminData()) net.Send(ply)
    end)

    hook.Add("PlayerInitialSpawn", "GRM_FEco_Sync", function(ply) timer.Simple(5, function() if IsValid(ply) then sync(ply) end end) end)

    hook.Add("PlayerSay", "GRM_FEco_Chat", function(ply, text)
        local args = string.Explode(" ", string.Trim(text or ""))
        local cmd = string.lower(args[1] or "")

        if cmd == "/salary_admin" or cmd == "!salary_admin" or cmd == "/feco_admin" or cmd == "!feco_admin" then
            if ply:IsSuperAdmin() then net.Start(NET_ADMIN_OPEN) net.Send(ply) end
            return ""
        end

        if cmd == "!fbudget" or cmd == "/fbudget" then
            local fName = getFactionInfo(ply); if not fName then notify(ply, "Вы не во фракции.") return "" end
            local e = normalizeEntry(fName)
            notify(ply, "[" .. fName .. "] Бюджет: " .. money(e.budget) .. " | Налог: " .. math.floor(e.taxRate * 100) .. "% | База ЗП: " .. money(e.baseSalary))
            return ""
        end

        if cmd == "!fpay" or cmd == "/fpay" then
            local amount = math.floor(tonumber(args[2]) or 0); local fName = getFactionInfo(ply)
            if not fName or amount <= 0 then return "" end
            if GRM.HasMoney and not GRM.HasMoney(ply, amount) then notify(ply, "Недостаточно средств.") return "" end
            if GRM.TakeMoney then GRM.TakeMoney(ply, amount) end
            GRM.FactionBudgetAdd(fName, amount, "Взнос " .. ply:Nick())
            notify(ply, "Внесено в бюджет: " .. money(amount))
            return ""
        end
    end)

    concommand.Add("grm_salary_admin", function(ply) if IsValid(ply) and ply:IsSuperAdmin() then net.Start(NET_ADMIN_OPEN) net.Send(ply) end end)

    hook.Add("ShutDown", "GRM_FEco_Save", save)
    timer.Create("GRM_FEco_Save", 60, 0, save)

    print("[GRM Faction Economy Plus] Server loaded")
end

if CLIENT then
    local function openAdmin(data)
        local factions = data.factions or {}
        local eco = data.economy or {}

        local frame = vgui.Create("DFrame")
        frame:SetTitle("GRM Зарплаты и бюджеты фракций")
        frame:SetSize(980, 720)
        frame:Center(); frame:MakePopup()

        local top = vgui.Create("DPanel", frame); top:Dock(TOP); top:SetTall(42); top:SetPaintBackground(false)
        local combo = vgui.Create("DComboBox", top); combo:Dock(LEFT); combo:SetWide(300); combo:DockMargin(8,8,8,6)
        local saveBtn = vgui.Create("DButton", top); saveBtn:Dock(RIGHT); saveBtn:SetWide(160); saveBtn:DockMargin(8,8,8,6); saveBtn:SetText("Сохранить всё")

        local body = vgui.Create("DScrollPanel", frame); body:Dock(FILL); body:DockMargin(8,8,8,8)

        local current

        local function entry(parent, label, value, cb)
            local row = vgui.Create("DPanel", parent); row:Dock(TOP); row:SetTall(34); row:SetPaintBackground(false)
            local l = vgui.Create("DLabel", row); l:Dock(LEFT); l:SetWide(210); l:SetText(label)
            local e = vgui.Create("DTextEntry", row); e:Dock(FILL); e:SetText(tostring(value or 0)); e.OnChange = function() cb(tonumber(e:GetText()) or 0) end
            return e
        end

        local function rebuild(name)
            current = name; body:Clear()
            eco[name] = eco[name] or { budget=0,taxRate=0.05,baseSalary=0,roleSalaries={},departmentSalaries={},roleBonuses={},departmentBonuses={},salaryInterval=600,payFromBudget=true,history={} }
            local e = eco[name]

            entry(body, "Бюджет", e.budget, function(v) e.budget = math.max(0, math.floor(v)) end)
            entry(body, "Налог %", math.floor((e.taxRate or 0)*100), function(v) e.taxRate = math.Clamp(v/100,0,0.5) end)
            entry(body, "Базовая зарплата", e.baseSalary, function(v) e.baseSalary = math.max(0, math.floor(v)) end)
            entry(body, "Интервал ЗП сек", e.salaryInterval, function(v) e.salaryInterval = math.max(60, math.floor(v)) end)

            local chk = vgui.Create("DCheckBoxLabel", body); chk:Dock(TOP); chk:SetTall(28); chk:SetText("Платить зарплату из бюджета фракции"); chk:SetValue(e.payFromBudget ~= false); chk.OnChange = function(_,v) e.payFromBudget = v end

            local title = vgui.Create("DLabel", body); title:Dock(TOP); title:SetTall(30); title:SetText("Зарплата и надбавки по рангам")

            e.roleSalaries=e.roleSalaries or {}; e.roleBonuses=e.roleBonuses or {}; e.departmentSalaries=e.departmentSalaries or {}; e.departmentBonuses=e.departmentBonuses or {}

            for _, role in ipairs(factions[name].Roles or {}) do
                entry(body, "Ранг "..role.." — зарплата", e.roleSalaries[role] or 0, function(v) e.roleSalaries[role]=math.max(0,math.floor(v)) end)
                entry(body, "Ранг "..role.." — надбавка", e.roleBonuses[role] or 0, function(v) e.roleBonuses[role]=math.floor(v) end)
            end

            local title2 = vgui.Create("DLabel", body); title2:Dock(TOP); title2:SetTall(30); title2:SetText("Зарплата и надбавки по отделам")

            for _, dep in ipairs(factions[name].Departments or {}) do
                entry(body, "Отдел "..dep.." — зарплата", e.departmentSalaries[dep] or 0, function(v) e.departmentSalaries[dep]=math.max(0,math.floor(v)) end)
                entry(body, "Отдел "..dep.." — надбавка", e.departmentBonuses[dep] or 0, function(v) e.departmentBonuses[dep]=math.floor(v) end)
            end
        end

        local sorted = table.GetKeys(factions); table.sort(sorted)
        for _, name in ipairs(sorted) do combo:AddChoice(name) end
        combo.OnSelect = function(_,_,val) rebuild(val) end
        if sorted[1] then combo:SetValue(sorted[1]); rebuild(sorted[1]) end

        saveBtn.DoClick = function() net.Start(NET_ADMIN_SAVE); net.WriteTable(eco); net.SendToServer() end
    end

    net.Receive(NET_ADMIN_DATA, function() openAdmin(net.ReadTable() or {}) end)
    net.Receive(NET_INFO, function() chat.AddText(Color(120,220,120), "[Экономика] ", color_white, net.ReadString()) end)
    net.Receive(NET_SYNC, function() GRM.FactionEconomyPlus.Local = { faction = net.ReadString(), data = net.ReadTable() } end)

    concommand.Add("grm_salary_admin", function() net.Start(NET_ADMIN_OPEN); net.SendToServer() end)

    print("[GRM Faction Economy Plus] Client loaded")
end
