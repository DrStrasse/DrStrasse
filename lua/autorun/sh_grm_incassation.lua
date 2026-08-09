--[[--------------------------------------------------------------------
    GRM Incassation (Код 126 — «Инкассация») v1.1.0

    Механика (по ТЗ владельца):
      • Суперадмин настраивает фракции/роли/ТС на вкладке «Инкассация» /factions.
      • Сотрудник фракции с подходящей ролью пишет /incass СИДЯ В СЛУЖЕБНОЙ МАШИНЕ.
      • Подъехав к банкомату (grm_bank_terminal) в радиусе, жмёт G на терминал —
        в правую руку выдаётся чемодан (weapon_grm_incass_bag, модель
        models/weapons/w_suitcase_passenger.mdl), на сумму BAG_CHUNK, деньги
        списываются из терминала. Блокировка терминала — на время рейса.
      • С чемоданом в руках вернуться к машине и нажать G — чемодан «загружается»
        в багажник (carCash += сумма чемодана).
      • Доехав до grm_bank_vault, нажать G на машину — открывается меню
        загрузки/выгрузки. Кнопка «Выгрузить чемодан» — даёт чемодан в руку.
        С чемоданом в руках нажать G на вольт — чемодан сдаётся в вольт
        (HeldCash += сумма).
      • Кнопка «Сдать всё в хранилище» в меню машины — мгновенная сдача всего.
      • Команда /incass_off — завершить рейс в любом месте (несданные деньги
        в машине и в руке пропадают / возвращаются в бюджет, чемоданы в руках
        снимаются).
      • Деньги НЕ ПОПАДАЮТ в кошелёк игрока и НЕ идут в гос.бюджет автоматически.
        Путь: терминал → чемодан в руках → машина → чемодан в руках → вольт.

    Зависимости:
      - Код 42 (sh_grm_currency.lua)   — GRM.Notify / GRM.Format / GRM.GiveMoney
      - Код 43 (sh_grm_economy.lua)    — GRM.Economy.*, банк-вольты, гос.бюджет
      - Factions (sh_factions.lua)     — фракции/роли/IncassoSettings
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Incass = GRM.Incass or {}
local I = GRM.Incass

I.Version    = "1.1.0"
I.Code       = 126
I.ModuleName = "incassation"

-- Сетевые строки
local NET_NOTIFY       = "GRM_Incass_Notify"
local NET_CAR_MENU     = "GRM_Incass_CarMenu"
local NET_CAR_DELIVER  = "GRM_Incass_CarDeliver"
local NET_CAR_LOAD     = "GRM_Incass_CarLoad"
local NET_CAR_UNLOAD   = "GRM_Incass_CarUnload"
local NET_TERM_TAKE    = "GRM_Incass_TermTake"
local NET_VAULT_DELIVER= "GRM_Incass_VaultDeliver"

if SERVER then
    for _, s in ipairs({ NET_NOTIFY, NET_CAR_MENU, NET_CAR_DELIVER, NET_CAR_LOAD,
                         NET_CAR_UNLOAD, NET_TERM_TAKE, NET_VAULT_DELIVER }) do
        util.AddNetworkString(s)
    end
end

-- ──────────────────────────────────────────────────────────────────
-- Настройки (жёстко, как просил владелец)
-- ──────────────────────────────────────────────────────────────────
I.CFG = {
    MaxCarryPerCar         = 250000,
    TerminalRadius         = 220,
    VaultRadius            = 320,
    TerminalDepositCut     = 0.05,
    TerminalMinCollect     = 100,
    RequireDriverSeat      = true,
    LockTerminalOnCollect  = true,
    TerminalCollectCooldown= 120,
    NotifyPoliceRadius     = 1200,
    CarClassCheck          = true,
    BagChunk               = 50000, -- размер одного чемодана
    BagWeaponClass         = "weapon_grm_incass_bag",
}

-- ──────────────────────────────────────────────────────────────────
-- Живое состояние (в памяти; между рестартами сбрасывается)
-- ──────────────────────────────────────────────────────────────────
I.ActiveRuns        = {} -- [runID] = { id, car, driver, faction, carCash, collected, started }
I.CarToRun          = {} -- [veh:EntIndex()] = runID
I.PlyToCar          = {} -- [ply:EntIndex()] = veh
I.LockedTerminals   = {} -- [ent:EntIndex()] = runID
I.TerminalCash      = {} -- [ent:EntIndex()] = amount (накоплено комиссией)
I.TerminalLastCollect = {} -- [ent:EntIndex()] = CurTime()
I.NextRunID         = 1
I._carAliasCache    = {}

----------------------------------------------------------------------
-- Утилиты
----------------------------------------------------------------------
local function isPly(p) return IsValid(p) and p:IsPlayer() end

local function notify(ply, msg, r, g, b)
    if not isPly(ply) then return end
    if CLIENT then
        chat.AddText(Color(r or 220, g or 220, b or 220), "[ИНКАСС] " .. tostring(msg))
        notification.AddLegacy(tostring(msg), NOTIFY_GENERIC, 5)
        surface.PlaySound("buttons/lightswitch2.wav")
        return
    end
    if GRM.Notify then
        GRM.Notify(ply, msg, r or 220, g or 220, b or 220)
        return
    end
    net.Start(NET_NOTIFY)
        net.WriteString(tostring(msg))
        net.WriteUInt(r or 220, 8); net.WriteUInt(g or 220, 8); net.WriteUInt(b or 220, 8)
    net.Send(ply)
end
I.Notify = notify

local function fmt(n)
    n = math.floor(tonumber(n) or 0)
    if GRM.Format then
        local ok, s = pcall(GRM.Format, n)
        if ok then return s end
    end
    return tostring(n) .. " GRM"
end
I.FormatMoney = fmt

-- Машиноподобный энтити?
local function isCarEntity(ent)
    if not IsValid(ent) then return false end
    local cls = ent:GetClass() or ""
    if ent:IsVehicle() then return true end
    if string.StartWith(cls, "simfphys_") then return true end
    if string.StartWith(cls, "lvs_") then return true end
    if string.StartWith(cls, "gmod_sent_vehicle") then return true end
    if string.StartWith(cls, "prop_vehicle_") then return true end
    return false
end

-- Корневое ТС (подняться по parent-цепочке от сиденья)
local function getRootVehicle(ent)
    if not IsValid(ent) then return nil end
    local cur = ent
    local seen = {}
    for _ = 1, 8 do
        if not IsValid(cur) then break end
        seen[cur] = true
        local p = cur:GetParent()
        if IsValid(p) and not p:IsPlayer() and not p:IsWorld() and isCarEntity(p) and not seen[p] then
            cur = p
        else break end
    end
    return cur
end

-- Водитель ТС (универсально)
local function getDriverOf(veh)
    if not IsValid(veh) then return nil end
    local ok, d = pcall(function() return veh:GetDriver() end)
    if ok and IsValid(d) and d:IsPlayer() then return d end
    if isfunction(veh.GetDriverSeat) then
        local s; ok, s = pcall(veh.GetDriverSeat, veh)
        if ok and IsValid(s) then
            ok, d = pcall(s.GetDriver, s)
            if ok and IsValid(d) and d:IsPlayer() then return d end
        end
    end
    if istable(veh:GetChildren()) then
        for _, child in ipairs(veh:GetChildren()) do
            if IsValid(child) and child:IsVehicle() then
                ok, d = pcall(child.GetDriver, child)
                if ok and IsValid(d) and d:IsPlayer() then return d end
            end
        end
    end
    return nil
end

-- Spawn-name ТС (ключ из list.Get(...))
local function getVehicleSpawnName(veh)
    if not IsValid(veh) then return nil end
    if isstring(veh.GRM_IncassSpawnName) and veh.GRM_IncassSpawnName ~= "" then return veh.GRM_IncassSpawnName end
    local function try(fn)
        if not isfunction(veh[fn]) then return nil end
        local ok, v = pcall(veh[fn], veh)
        if ok and isstring(v) and v ~= "" then return v end
        return nil
    end
    for _, fn in ipairs({ "GetSpawn_List", "GetSpawnList", "GetSpawningName",
                          "GetVehicleListName", "GetVehicleName",
                          "GetLVSVehicleName", "GetVehicleClass" }) do
        local v = try(fn); if v then return v end
    end
    for _, k in ipairs({ "SpawnList", "Spawn_List", "SpawnName", "VehicleName",
                          "List_ID", "ListName", "LVSVehicleName", "VehicleClassName" }) do
        local v = veh[k]
        if isstring(v) and v ~= "" then return v end
    end
    if isfunction(veh.GetKeyValues) then
        local ok, kv = pcall(veh.GetKeyValues, veh)
        if ok and istable(kv) then
            for _, k in ipairs({ "vehiclescript", "vehicletype" }) do
                if isstring(kv[k]) and kv[k] ~= "" then return kv[k] end
            end
        end
    end
    local lists = { list.Get("simfphys_vehicles") or {}, list.Get("Vehicles") or {}, list.Get("LVS_Vehicles") or {} }
    local okM, myMdl = pcall(veh.GetModel, veh)
    local vehModel = (okM and isstring(myMdl)) and string.lower(myMdl) or nil
    for _, lst in pairs(lists) do
        for key, info in pairs(lst) do
            if isstring(key) and vehModel and istable(info) and isstring(info.Model)
               and string.lower(info.Model) == vehModel then return key end
        end
    end
    return veh:GetClass()
end

----------------------------------------------------------------------
-- Доступы
----------------------------------------------------------------------
function I.GetPlayerIncassoInfo(ply)
    if not isPly(ply) then return nil, nil, nil end
    if not Factions then return nil, nil, nil end
    for fname, f in pairs(Factions) do
        if not istable(f) or not istable(f.Members) then continue end
        local member = nil
        if GRM.Identity and GRM.Identity.FactionMember then
            member = GRM.Identity.FactionMember(f, ply)
        end
        if not member then
            local ck = (GRM.Identity and GRM.Identity.CharacterKey)
                and GRM.Identity.CharacterKey(ply) or ply:SteamID64()
            member = f.Members[ck] or f.Members[ply:SteamID64()] or f.Members[ply:SteamID()]
        end
        if istable(member) then
            local inc = istable(f.IncassoSettings) and f.IncassoSettings
                or { Enabled = false, Roles = {}, Vehicles = {} }
            return inc, member.Role or "Участник", fname, f
        end
    end
    return nil, nil, nil, nil
end

function I.CanPlayerIncass(ply)
    local inc, roleName, fname = I.GetPlayerIncassoInfo(ply)
    if not inc then return false, "Вы не состоите во фракции" end
    if not inc.Enabled then return false, "Инкассация не включена для вашей фракции" end
    local roleAllowed = false
    for _, r in ipairs(inc.Roles or {}) do
        if r == roleName then roleAllowed = true break end
    end
    if ply:IsSuperAdmin() then roleAllowed = true end
    if not roleAllowed then
        return false, "Ваша роль («" .. tostring(roleName) .. "») не допущена к инкассации"
    end
    return true, fname, inc, roleName
end

function I.IsIncassCarForFaction(veh, factionName)
    if not IsValid(veh) or not factionName then return false end
    local f = Factions and Factions[factionName]
    if not f or not istable(f.IncassoSettings) then return false end
    local allowed = f.IncassoSettings.Vehicles or {}
    if #allowed == 0 then return false end
    local eid = veh:EntIndex()
    if I._carAliasCache[eid] then
        for _, cand in ipairs(I._carAliasCache[eid]) do
            for _, name in ipairs(allowed) do
                if cand == string.lower(name) then return true end
            end
        end
        return false
    end
    local aliases = {}
    local function add(v)
        if isstring(v) and v ~= "" then
            local vl = string.lower(v)
            for _, ex in ipairs(aliases) do if ex == vl then return end end
            aliases[#aliases+1] = vl
        end
    end
    add(veh:GetClass())
    for _, fn in ipairs({ "GetSpawn_List", "GetSpawnList", "GetSpawningName",
                          "GetVehicleListName", "GetVehicleName",
                          "GetLVSVehicleName", "GetVehicleClass" }) do
        if isfunction(veh[fn]) then
            local ok, v = pcall(veh[fn], veh)
            if ok and isstring(v) then add(v) end
        end
    end
    for _, k in ipairs({ "SpawnList", "Spawn_List", "SpawnName", "VehicleName",
                          "List_ID", "ListName", "LVSVehicleName", "VehicleClassName" }) do
        if isstring(veh[k]) then add(veh[k]) end
    end
    if isfunction(veh.GetKeyValues) then
        local ok, kv = pcall(veh.GetKeyValues, veh)
        if ok and istable(kv) then
            for _, k in ipairs({ "vehiclescript", "vehicletype" }) do
                if isstring(kv[k]) then add(kv[k]) end
            end
        end
    end
    if isfunction(veh.GetModel) then
        local ok, mdl = pcall(veh.GetModel, veh)
        if ok and isstring(mdl) then
            add(mdl)
            add(mdl:match("([^/\\]+)$"))
        end
    end
    for _, lstName in ipairs({ "simfphys_vehicles", "Vehicles", "LVS_Vehicles" }) do
        local lst = list.Get(lstName)
        if istable(lst) then
            for key, info in pairs(lst) do
                if isstring(key) then
                    local okM, myMdl = pcall(veh.GetModel, veh)
                    if okM and isstring(myMdl) and istable(info) and isstring(info.Model)
                       and string.lower(info.Model) == string.lower(myMdl) then add(key) end
                end
            end
        end
    end
    I._carAliasCache[eid] = aliases
    for _, cand in ipairs(aliases) do
        for _, name in ipairs(allowed) do
            if cand == string.lower(name) then return true end
        end
    end
    return false
end

function I.IsActiveIncassCar(veh)
    if not IsValid(veh) then return false end
    local r = I.CarToRun[veh:EntIndex()]
    return r and I.ActiveRuns[r] and IsValid(I.ActiveRuns[r].car) or false
end

function I.FindNearestTerminal(pos, radius)
    local best, bestD = nil, math.huge
    radius = radius or I.CFG.TerminalRadius
    for _, ent in ipairs(ents.FindByClass("grm_bank_terminal")) do
        if IsValid(ent) then
            local d = ent:GetPos():DistToSqr(pos)
            if d < bestD and d <= radius * radius then best, bestD = ent, d end
        end
    end
    return best
end

function I.FindNearestVault(pos, radius)
    if GRM.Economy and GRM.Economy.Vaults then
        local best, bestD = nil, math.huge
        radius = radius or I.CFG.VaultRadius
        for _, ent in pairs(GRM.Economy.Vaults) do
            if IsValid(ent) then
                local d = ent:GetPos():DistToSqr(pos)
                if d < bestD and d <= radius * radius then best, bestD = ent, d end
            end
        end
        return best
    end
    for _, ent in ipairs(ents.FindByClass("grm_bank_vault")) do
        if IsValid(ent) and pos:DistToSqr(ent:GetPos()) <= (radius or I.CFG.VaultRadius)^2 then
            return ent
        end
    end
    return nil
end

-- Работа с чемоданом-SWEP в руке
function I.PlayerBagAmount(ply)
    if not isPly(ply) then return 0 end
    local w = ply:GetActiveWeapon()
    if IsValid(w) and w:GetClass() == I.CFG.BagWeaponClass and isfunction(w.GetCarriedAmount) then
        return math.max(0, math.floor(w:GetCarriedAmount() or 0))
    end
    for _, wp in ipairs(ply:GetWeapons() or {}) do
        if IsValid(wp) and wp:GetClass() == I.CFG.BagWeaponClass and isfunction(wp.GetCarriedAmount) then
            return math.max(0, math.floor(wp:GetCarriedAmount() or 0))
        end
    end
    return 0
end

function I.GiveBagWeapon(ply, amount)
    if not isPly(ply) then return nil end
    if I.PlayerBagAmount(ply) > 0 then return nil end
    local w = ply:GetWeapon(I.CFG.BagWeaponClass)
    if not IsValid(w) then
        w = ply:Give(I.CFG.BagWeaponClass)
    end
    if not IsValid(w) then return nil end
    if w.SetCarriedAmount then w:SetCarriedAmount(amount) end
    ply:SelectWeapon(I.CFG.BagWeaponClass)
    ply:SetNWBool("GRMIncass_Carrying", true)
    ply:SetNWInt("GRMIncass_BagAmount", amount)
    return w
end

function I.TakeBagWeapon(ply)
    if not isPly(ply) then return 0 end
    local amt = I.PlayerBagAmount(ply)
    if amt > 0 then
        ply:StripWeapon(I.CFG.BagWeaponClass)
    end
    ply:SetNWBool("GRMIncass_Carrying", false)
    ply:SetNWInt("GRMIncass_BagAmount", 0)
    return amt
end

if SERVER then

----------------------------------------------------------------------
-- SERVER
----------------------------------------------------------------------

local function unlockTerminalsOfRun(runID)
    for eid, rid in pairs(I.LockedTerminals) do
        if rid == runID then I.LockedTerminals[eid] = nil end
    end
end

function I.FinishRun(runID, reason)
    local run = I.ActiveRuns[runID]
    if not run then return end
    unlockTerminalsOfRun(runID)
    if IsValid(run.car) then
        I.CarToRun[run.car:EntIndex()] = nil
        if run.car.SetNWInt then
            run.car:SetNWInt("GRM_IncassRun", 0)
            run.car:SetNWInt("GRM_IncassCarCash", 0)
        end
        if run.car.SetNWString then
            run.car:SetNWString("GRM_IncassUID", "")
            run.car:SetNWString("GRM_IncassSpawnName", "")
        end
        I._carAliasCache[run.car:EntIndex()] = nil
        run.car.GRM_IncassUID = nil
        run.car.GRM_IncassFaction = nil
        run.car.GRM_IncassSpawnName = nil
        run.car.GRM_IncassDriver = nil
    end
    if IsValid(run.driver) then
        I.PlyToCar[run.driver:EntIndex()] = nil
        if run.driver.SetNWEntity then run.driver:SetNWEntity("GRM_IncassMyCar", NULL) end
        -- Снять чемодан из рук при завершении
        if I.PlayerBagAmount(run.driver) > 0 then
            I.TakeBagWeapon(run.driver)
        end
        run.driver:SetNWBool("GRMIncass_Carrying", false)
        run.driver:SetNWInt("GRMIncass_BagAmount", 0)
        notify(run.driver, "Рейс инкассации #" .. runID .. " завершён: " .. tostring(reason or "—"), 100, 220, 130)
    end
    I.ActiveRuns[runID] = nil
    print("[GRM Incass] RUN #" .. runID .. " finished: " .. tostring(reason or ""))
end

function I.CancelRun(plyOrCaller, runID, reason)
    local run = I.ActiveRuns[runID]
    if not run then return false end
    -- Содержимое машины: пропадает / уходит в бюджет (оставим пропаданием, т.к. игрок сам закончил)
    I.FinishRun(runID, tostring(reason or ""))
    return true
end

function I.StartRun(ply)
    if not isPly(ply) then return false, "Игрок невалиден" end
    local ok, fnameOrErr, inc, roleName = I.CanPlayerIncass(ply)
    if not ok then return false, fnameOrErr end

    local veh = ply:GetVehicle()
    if I.CFG.RequireDriverSeat then
        if not IsValid(veh) then return false, "Сядьте за руль служебной машины" end
        veh = getRootVehicle(veh)
        if not IsValid(veh) then return false, "Не найдено ТС" end
        local drv = getDriverOf(veh)
        if IsValid(drv) and drv ~= ply then
            return false, "Вы должны быть за рулём, а не пассажиром"
        end
        if not IsValid(drv) then
            return false, "Сядьте за РУЛЬ (водительское место)"
        end
    else
        veh = getRootVehicle(ply:GetVehicle())
    end
    if not IsValid(veh) then return false, "Не найдено ТС" end

    for rid, r in pairs(I.ActiveRuns) do
        if IsValid(r.driver) and r.driver == ply then
            return false, "У вас уже идёт рейс #" .. rid .. ". Завершить: /incass_off"
        end
        if IsValid(r.car) and r.car == veh then
            return false, "Эта машина уже в рейсе #" .. rid
        end
    end

    if I.CFG.CarClassCheck and not I.IsIncassCarForFaction(veh, fnameOrErr) then
        local spawnNm = getVehicleSpawnName(veh) or veh:GetClass()
        return false, "Этот класс ТС («" .. tostring(veh:GetClass())
            .. (spawnNm and spawnNm ~= veh:GetClass() and "/" .. tostring(spawnNm) or "")
            .. "») не разрешён для инкассации фракции «" .. fnameOrErr .. "»"
    end

    local runID = I.NextRunID; I.NextRunID = I.NextRunID + 1
    local spawnName = getVehicleSpawnName(veh) or veh:GetClass()
    veh.GRM_IncassUID = "INC-" .. runID .. "-" .. os.time()
    veh.GRM_IncassFaction = fnameOrErr
    veh.GRM_IncassSpawnName = spawnName
    veh.GRM_IncassDriver = ply
    I._carAliasCache[veh:EntIndex()] = nil

    I.ActiveRuns[runID] = {
        id = runID, uid = veh.GRM_IncassUID, car = veh, driver = ply,
        faction = fnameOrErr, carClass = veh:GetClass(), spawnName = spawnName,
        carCash = 0, collected = {}, started = CurTime(),
    }
    I.CarToRun[veh:EntIndex()] = runID
    I.PlyToCar[ply:EntIndex()] = veh
    veh:SetNWInt("GRM_IncassRun", runID)
    veh:SetNWInt("GRM_IncassCarCash", 0)
    veh:SetNWString("GRM_IncassFaction", fnameOrErr)
    veh:SetNWString("GRM_IncassSpawnName", tostring(spawnName))
    veh:SetNWString("GRM_IncassUID", tostring(veh.GRM_IncassUID))
    ply:SetNWEntity("GRM_IncassMyCar", veh)

    notify(ply, "Рейс #" .. runID .. " начат (" .. tostring(spawnName)
        .. "). Берите чемодан на G у терминала, грузите в машину G-же, сдавайте в вольт G-же по приезде.", 100, 220, 130)

    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p ~= ply and p:IsAdmin()
           and p:GetPos():DistToSqr(ply:GetPos()) <= (I.CFG.NotifyPoliceRadius^2) then
            notify(p, "[АДМИН] " .. ply:Nick() .. " начал рейс инкассации #" .. runID, 200, 180, 80)
        end
    end
    print("[GRM Incass] RUN #" .. runID .. " started by " .. ply:Nick() .. " (" .. fnameOrErr .. "/" .. tostring(roleName) .. ")")
    return true, runID
end

-- Взять один чемодан из терминала в руку
function I.CollectFromTerminal(ply, terminal)
    if not isPly(ply) or not IsValid(terminal) or terminal:GetClass() ~= "grm_bank_terminal" then
        return false, "Нет терминала"
    end
    local runID; for rid, r in pairs(I.ActiveRuns) do
        if IsValid(r.driver) and r.driver == ply then runID = rid break end
    end
    if not runID then return false, "У вас нет активного рейса" end
    local run = I.ActiveRuns[runID]
    if not IsValid(run.car) then I.CancelRun(ply, runID, "машина утеряна"); return false, "Рейс закрыт" end
    if ply:GetPos():DistToSqr(terminal:GetPos()) > (I.CFG.TerminalRadius^2) then
        return false, "Слишком далеко от терминала"
    end
    local eid = terminal:EntIndex()
    local cash = math.floor(tonumber(I.TerminalCash[eid]) or 0)
    if cash <= 0 then return false, "В терминале нечего забирать" end
    local lastT = I.TerminalLastCollect[eid] or 0
    if lastT + I.CFG.TerminalCollectCooldown > CurTime() then
        return false, "Терминал на кулдауне (ждите " .. math.ceil(lastT + I.CFG.TerminalCollectCooldown - CurTime()) .. " сек)"
    end
    if I.PlayerBagAmount(ply) > 0 then
        return false, "В руках уже чемодан — загрузите его в машину (G на машину)"
    end
    local free = math.max(0, I.CFG.MaxCarryPerCar - run.carCash)
    if free <= 0 then return false, "Машина полна" end
    local take = math.min(I.CFG.BagChunk, cash, free)
    if take <= 0 then return false, "Нечего брать" end
    I.TerminalCash[eid] = cash - take
    I.TerminalLastCollect[eid] = CurTime()
    if I.CFG.LockTerminalOnCollect then I.LockedTerminals[eid] = runID end
    local w = I.GiveBagWeapon(ply, take)
    if not IsValid(w) then
        I.TerminalCash[eid] = (I.TerminalCash[eid] or 0) + take
        return false, "Не удалось выдать чемодан"
    end
    terminal:EmitSound("buttons/blip1.wav", 55, 100)
    notify(ply, "В руке чемодан с " .. fmt(take) .. ". Подойдите к машине и нажмите G, чтобы загрузить.", 100, 220, 130)
    return true, take
end

-- Загрузить чемодан из руки в машину (G на машину, в руках чемодан)
function I.LoadBagIntoCar(ply, car)
    if not isPly(ply) or not IsValid(car) then return false, "Нет цели" end
    local runID = I.CarToRun[car:EntIndex()]
    if not runID or not I.ActiveRuns[runID] then return false, "Это не инкасс-машина" end
    local run = I.ActiveRuns[runID]
    if run.driver ~= ply then return false, "Это не ваша инкасс-машина" end
    if ply:GetPos():DistToSqr(car:GetPos()) > (250^2) then return false, "Подойдите к машине" end
    local amt = I.PlayerBagAmount(ply)
    if amt <= 0 then return false, "В руках нет чемодана" end
    if run.carCash + amt > I.CFG.MaxCarryPerCar then return false, "В машине не хватает места" end
    I.TakeBagWeapon(ply)
    run.carCash = run.carCash + amt
    car:SetNWInt("GRM_IncassCarCash", run.carCash)
    car:EmitSound("physics/metal/metal_solid_impact_hard" .. math.random(1,3) .. ".wav", 50, 100)
    notify(ply, "Загружено: " .. fmt(amt) .. " (в машине " .. fmt(run.carCash) .. " / " .. fmt(I.CFG.MaxCarryPerCar) .. ")", 100, 220, 130)
    return true, amt
end

-- Выгрузить один чемодан из машины в руку (у вольта)
function I.UnloadOneBag(ply)
    if not isPly(ply) then return false, "Игрок невалиден" end
    local runID; for rid, r in pairs(I.ActiveRuns) do
        if IsValid(r.driver) and r.driver == ply then runID = rid break end
    end
    if not runID then return false, "У вас нет активного рейса" end
    local run = I.ActiveRuns[runID]
    if not IsValid(run.car) then I.CancelRun(ply, runID, "машина утеряна"); return false, "Рейс закрыт" end
    if run.carCash <= 0 then return false, "В машине нет денег" end
    local vault = I.FindNearestVault(ply:GetPos(), I.CFG.VaultRadius)
    if not vault then return false, "Рядом нет банк-хранилища" end
    if ply:GetPos():DistToSqr(run.car:GetPos()) > (250^2) then return false, "Подойдите к машине" end
    if I.PlayerBagAmount(ply) > 0 then return false, "В руках уже чемодан — сдайте его (G на вольт)" end
    local take = math.min(I.CFG.BagChunk, run.carCash)
    run.carCash = run.carCash - take
    run.car:SetNWInt("GRM_IncassCarCash", run.carCash)
    local w = I.GiveBagWeapon(ply, take)
    if not IsValid(w) then
        run.carCash = run.carCash + take
        run.car:SetNWInt("GRM_IncassCarCash", run.carCash)
        return false, "Не удалось взять чемодан"
    end
    run.car:EmitSound("physics/metal/metal_solid_impact_hard" .. math.random(1,3) .. ".wav", 50, 100)
    notify(ply, "В руке чемодан " .. fmt(take) .. ". Подойдите к вольту и нажмите G, чтобы сдать.", 120, 200, 255)
    return true, take
end

-- Сдать чемодан из руки в вольт (G на вольт)
function I.DeliverBagToVault(ply, vault)
    if not isPly(ply) then return false, "Нет игрока" end
    if not IsValid(vault) or vault:GetClass() ~= "grm_bank_vault" then return false, "Это не банк-хранилище" end
    local runID; for rid, r in pairs(I.ActiveRuns) do
        if IsValid(r.driver) and r.driver == ply then runID = rid break end
    end
    if not runID then return false, "У вас нет активного рейса" end
    if ply:GetPos():DistToSqr(vault:GetPos()) > (I.CFG.VaultRadius^2) then return false, "Слишком далеко от вольта" end
    local amt = I.PlayerBagAmount(ply)
    if amt <= 0 then return false, "В руках нет чемодана" end
    if vault.SetHeldCash and vault.GetHeldCash then
        vault:SetHeldCash(math.floor(vault:GetHeldCash() or 0) + amt)
        if GRM.PermData and GRM.PermData.UpdateEntry then GRM.PermData.UpdateEntry(vault) end
    end
    I.TakeBagWeapon(ply)
    vault:EmitSound("ambient/levels/labs/coinslot1.wav", 65, 95)
    notify(ply, "Сдано в хранилище: " .. fmt(amt) .. ".", 100, 220, 130)
    return true, amt
end

-- Сдать ВСЮ сумму из машины в вольт (оптом из меню)
function I.DeliverAllToVault(ply)
    if not isPly(ply) then return false, "Игрок невалиден" end
    local runID; for rid, r in pairs(I.ActiveRuns) do
        if IsValid(r.driver) and r.driver == ply then runID = rid break end
    end
    if not runID then return false, "У вас нет активного рейса" end
    local run = I.ActiveRuns[runID]
    if not IsValid(run.car) then I.CancelRun(ply, runID, "машина утеряна"); return false, "Рейс закрыт" end
    if I.PlayerBagAmount(ply) > 0 then return false, "Сначала сдайте чемодан из рук" end
    if run.carCash <= 0 then return false, "В машине нет денег" end
    local vault = I.FindNearestVault(ply:GetPos(), I.CFG.VaultRadius)
    if not vault then return false, "Рядом нет банк-хранилища" end
    if ply:GetPos():DistToSqr(run.car:GetPos()) > (250^2) then return false, "Подойдите к машине" end
    local amount = run.carCash
    if vault.SetHeldCash and vault.GetHeldCash then
        vault:SetHeldCash(math.floor(vault:GetHeldCash() or 0) + amount)
        if GRM.PermData and GRM.PermData.UpdateEntry then GRM.PermData.UpdateEntry(vault) end
    else
        return false, "Хранилище не принимает деньги"
    end
    run.carCash = 0
    run.car:SetNWInt("GRM_IncassCarCash", 0)
    vault:EmitSound("ambient/levels/labs/coinslot1.wav", 65, 95)
    notify(ply, "Сдано в хранилище: " .. fmt(amount) .. ". Рейс #" .. runID .. " закрыт.", 100, 220, 130)
    I.FinishRun(runID, "доставка " .. fmt(amount) .. " в банк-вольт")
    return true, amount
end

-- Хук на GRM_Incass_TerminalDeposit (из экономики): 5% от вкладов оседает в терминале
hook.Add("GRM_Incass_TerminalDeposit", "GRM_Incass_TerminalDeposit", function(ply, amount, terminal)
    if not IsValid(terminal) or terminal:GetClass() ~= "grm_bank_terminal" then return end
    local eid = terminal:EntIndex()
    local cut = math.floor((tonumber(amount) or 0) * (I.CFG.TerminalDepositCut or 0))
    if cut <= 0 then return end
    I.TerminalCash[eid] = (I.TerminalCash[eid] or 0) + cut
end)

-- Блокировка обычных депозитов в терминал, если он на инкассации
hook.Add("PlayerUse", "GRM_Incass_TerminalLock", function(ply, ent)
    if not isPly(ply) or not IsValid(ent) then return end
    if ent:GetClass() ~= "grm_bank_terminal" then return end
    local runForLock = I.LockedTerminals[ent:EntIndex()]
    -- Своя машина рядом — инкассир работает, не блокируем ему E на терминале (но его E мы не перехватываем, он жмёт G)
    if runForLock then
        -- Инкассиру рейса разрешаем использовать (на случай если он хочет сделать вклад)
        local myRun; for rid, r in pairs(I.ActiveRuns) do
            if IsValid(r.driver) and r.driver == ply then myRun = rid break end
        end
        if myRun == runForLock then return end
        notify(ply, "Этот банкомат обслуживается инкассацией. Попробуйте позже.", 255, 180, 80)
        return false
    end
end)

-- Чужим нельзя входить в гружёную машину рейса
hook.Add("CanPlayerEnterVehicle", "GRM_Incass_NoEntry", function(ply, veh)
    if not isPly(ply) or not IsValid(veh) then return end
    local root = getRootVehicle(veh)
    if not IsValid(root) then return end
    local rid = I.CarToRun[root:EntIndex()]
    if not rid then return end
    local run = I.ActiveRuns[rid]
    if not run then return end
    if IsValid(run.driver) and run.driver == ply then return end
    notify(ply, "В инкассаторскую машину во время рейса нельзя садиться посторонним.", 255, 100, 100)
    return false
end)

-- Удаление ТС → аварийное завершение
hook.Add("EntityRemoved", "GRM_Incass_CarRemoved", function(ent)
    if not IsValid(ent) then return end
    local rid = I.CarToRun[ent:EntIndex()]
    if rid and I.ActiveRuns[rid] then
        I.CancelRun(nil, rid, "машина удалена/уничтожена")
    end
    if ent:GetClass() == "grm_bank_terminal" then
        local eid = ent:EntIndex()
        I.TerminalCash[eid] = nil
        I.TerminalLastCollect[eid] = nil
        I.LockedTerminals[eid] = nil
    end
end)

-- Дисконнект
hook.Add("PlayerDisconnected", "GRM_Incass_DC", function(ply)
    for rid, r in pairs(I.ActiveRuns) do
        if IsValid(r.driver) and r.driver == ply then
            I.CancelRun(nil, rid, "водитель отключился (" .. ply:Nick() .. ")")
        end
    end
end)

-- Смерть — уронить чемодан (просто снять, деньги возвращаются в терминал как «потеря»? Снимаем с рук.)
hook.Add("PlayerDeath", "GRM_Incass_Death", function(ply)
    if I.PlayerBagAmount(ply) > 0 then
        I.TakeBagWeapon(ply)
        notify(ply, "Чемодан выпал из рук при смерти (деньги утеряны).", 255, 120, 120)
    end
end)

-- Чат-команды
hook.Add("PlayerSay", "GRM_Incass_Cmds", function(ply, text)
    if not isPly(ply) then return end
    local t = string.Trim(string.lower(text or ""))
    if t == "/incass" or t == "!incass" or t == "/инкасс" then
        local ok, err = I.StartRun(ply)
        if not ok then notify(ply, err, 255, 100, 100) end
        return ""
    end
    if t == "/incass_off" or t == "!incass_off" or t == "/incass_end"
       or t == "/инкасс_офф" or t == "/инкасс_стоп" then
        local runID; for rid, r in pairs(I.ActiveRuns) do
            if IsValid(r.driver) and r.driver == ply then runID = rid break end
        end
        if not runID then notify(ply, "У вас нет активного рейса", 255, 100, 100)
        else I.CancelRun(ply, runID, "принудительное завершение (/incass_off)") end
        return ""
    end
    if t == "/incass_delivery" or t == "!incass_delivery" or t == "/incass_deliver" or t == "/сдать" then
        local ok, err = I.DeliverAllToVault(ply)
        if not ok then notify(ply, err, 255, 100, 100) end
        return ""
    end
end)

-- Net: клиент жмёт G на ТЕРМИНАЛ
net.Receive(NET_TERM_TAKE, function(_, ply)
    local ent = net.ReadEntity()
    if not isPly(ply) or not IsValid(ent) then return end
    local ok, err = I.CollectFromTerminal(ply, ent)
    if not ok and err then notify(ply, err, 255, 100, 100) end
end)

-- Net: клиент жмёт G на МАШИНУ — открыть меню
concommand.Add("grm_incass_car_use", function(ply)
    if not isPly(ply) then return end
    local runID; for rid, r in pairs(I.ActiveRuns) do
        if IsValid(r.driver) and r.driver == ply then runID = rid break end
    end
    if not runID then return end
    local run = I.ActiveRuns[runID]
    if not run or not IsValid(run.car) then
        I.CancelRun(ply, runID, "машина утеряна"); return
    end
    -- Если в руках чемодан — сразу загрузить (не открывая меню)
    if I.PlayerBagAmount(ply) > 0 then
        local ok, err = I.LoadBagIntoCar(ply, run.car)
        if not ok and err then notify(ply, err, 255, 100, 100) end
        return
    end
    local vault = I.FindNearestVault(ply:GetPos(), I.CFG.VaultRadius)
    net.Start(NET_CAR_MENU)
        net.WriteEntity(run.car)
        net.WriteInt(run.carCash, 32)
        net.WriteBool(IsValid(vault))
    net.Send(ply)
end)

-- Net: клиент жмёт G на ВОЛЬТ
net.Receive(NET_VAULT_DELIVER, function(_, ply)
    local ent = net.ReadEntity()
    if not isPly(ply) or not IsValid(ent) then return end
    local ok, err = I.DeliverBagToVault(ply, ent)
    if not ok and err then notify(ply, err, 255, 100, 100) end
end)

-- Net: выгрузить один чемодан в руку (из меню машины)
net.Receive(NET_CAR_UNLOAD, function(_, ply)
    local ok, err = I.UnloadOneBag(ply)
    if not ok and err then notify(ply, err, 255, 100, 100) end
end)

-- Net: сдать всё из меню машины
net.Receive(NET_CAR_DELIVER, function(_, ply)
    local ok, err = I.DeliverAllToVault(ply)
    if not ok and err then notify(ply, err, 255, 100, 100) end
end)

-- Отладочная команда
concommand.Add("grm_incass_debug", function(ply)
    if not isPly(ply) or not ply:IsSuperAdmin() then return end
    local veh = ply:GetVehicle()
    if not IsValid(veh) then
        ply:PrintMessage(HUD_PRINTCONSOLE, "[INCASS DEBUG] Вы не в ТС"); return
    end
    local root = getRootVehicle(veh)
    local spn = getVehicleSpawnName(root)
    ply:PrintMessage(HUD_PRINTCONSOLE, "[INCASS DEBUG] seat: " .. tostring(veh:GetClass()))
    ply:PrintMessage(HUD_PRINTCONSOLE, "[INCASS DEBUG] root: " .. tostring(IsValid(root) and root:GetClass() or "nil"))
    for _, k in ipairs({ "SpawnList", "Spawn_List", "SpawnName", "VehicleName", "List_ID",
                         "ListName", "LVSVehicleName", "VehicleClassName", "GRM_IncassSpawnName" }) do
        local v = IsValid(root) and root[k] or nil
        ply:PrintMessage(HUD_PRINTCONSOLE, "[INCASS DEBUG]   root." .. k .. " = " .. tostring(v))
    end
    for _, fn in ipairs({ "GetClass", "GetSpawn_List", "GetSpawnList", "GetSpawningName",
                          "GetVehicleClass", "GetVehicleName", "GetModel" }) do
        if IsValid(root) and isfunction(root[fn]) then
            local ok, r = pcall(root[fn], root)
            ply:PrintMessage(HUD_PRINTCONSOLE, "[INCASS DEBUG]   root:" .. fn .. "() = " .. tostring(ok and r or "ERR"))
        end
    end
    I._carAliasCache[IsValid(root) and root:EntIndex() or 0] = nil
    I.IsIncassCarForFaction(root, "")
    local alias = I._carAliasCache[IsValid(root) and root:EntIndex() or 0] or {}
    ply:PrintMessage(HUD_PRINTCONSOLE, "[INCASS DEBUG]   aliases = { " .. table.concat(alias, ", ") .. " }")
    ply:PrintMessage(HUD_PRINTCONSOLE, "[INCASS DEBUG] getVehicleSpawnName(root) = " .. tostring(spn))
    ply:PrintMessage(HUD_PRINTCONSOLE, "[INCASS DEBUG] bagInHands = " .. tostring(I.PlayerBagAmount(ply)))
end)

print("[GRM Incass] SERVER: модуль Код 126 v" .. I.Version .. " загружен")

else -- CLIENT
----------------------------------------------------------------------
-- CLIENT
----------------------------------------------------------------------

surface.CreateFont("GRMInc_Title", { font = "Roboto", size = 18, weight = 700, extended = true })
surface.CreateFont("GRMInc_Normal",{ font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("GRMInc_Small", { font = "Roboto", size = 12, weight = 400, extended = true })

local INC_UI = {
    bg      = Color(25, 28, 36, 240),
    panel   = Color(34, 40, 52, 245),
    accent  = Color(220, 170, 60),
    accentDk= Color(170, 120, 30),
    success = Color(70, 180, 100),
    danger  = Color(210, 70, 70),
    text    = Color(235, 235, 240),
    dim     = Color(160, 165, 178),
}

local function closeFrame(fr) if IsValid(fr) then fr:Remove() end end

-- Меню машины (выгрузка/сдача)
local GRM_INC_CAR_FRAME
net.Receive(NET_CAR_MENU, function()
    local car = net.ReadEntity()
    local cash = net.ReadInt(32)
    local nearVault = net.ReadBool()
    if IsValid(GRM_INC_CAR_FRAME) then GRM_INC_CAR_FRAME:Remove() end
    local f = vgui.Create("DFrame")
    GRM_INC_CAR_FRAME = f
    f:SetSize(400, 220); f:Center(); f:SetTitle(""); f:MakePopup()
    function f:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, INC_UI.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 38, Color(40, 45, 58), true, true, false, false)
        draw.SimpleText("Инкассаторская машина", "GRMInc_Title", 12, 20, INC_UI.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    local body = vgui.Create("DPanel", f)
    body:Dock(FILL); body:DockMargin(12, 46, 12, 12); body:SetPaintBackground(false)

    local function line(text, color, dy)
        local l = vgui.Create("DLabel", body)
        l:Dock(TOP); l:DockMargin(4, dy or 4, 4, 0)
        l:SetFont("GRMInc_Normal"); l:SetTextColor(color or INC_UI.text)
        l:SetText(tostring(text)); l:SizeToContents()
        return l
    end
    line("В машине наличными: " .. (GRM.Incass.FormatMoney and GRM.Incass.FormatMoney(cash) or tostring(cash)), INC_UI.accent, 6)
    local carrying = LocalPlayer():GetNWBool("GRMIncass_Carrying", false)
    if carrying then
        line("В руках чемодан — закройте меню и подойдите к вольту (G на вольт).", INC_UI.danger)
    end
    if not nearVault then
        line("Для выгрузки/сдачи доедьте до банк-хранилища (grm_bank_vault).", INC_UI.danger)
    end

    local btnUnload = vgui.Create("DButton", body)
    btnUnload:Dock(BOTTOM); btnUnload:DockMargin(4, 8, 4, 4)
    btnUnload:SetTall(32); btnUnload:SetFont("GRMInc_Normal")
    btnUnload:SetText(nearVault and "Выгрузить один чемодан (в руку)" or "Выгрузить (нужно быть у вольта)")
    btnUnload:SetEnabled(nearVault and cash > 0 and not carrying or false)
    function btnUnload:Paint(w, h)
        local c = self:IsEnabled() and (self:IsHovered() and INC_UI.accentDk or INC_UI.accent) or Color(80,80,90)
        draw.RoundedBox(4, 0, 0, w, h, c)
    end
    function btnUnload:DoClick()
        net.Start(NET_CAR_UNLOAD); net.SendToServer(); closeFrame(f)
    end

    local btnDeliver = vgui.Create("DButton", body)
    btnDeliver:Dock(BOTTOM); btnDeliver:DockMargin(4, 12, 4, 4)
    btnDeliver:SetTall(36); btnDeliver:SetFont("GRMInc_Normal")
    btnDeliver:SetText(nearVault and "Сдать ВСЁ в хранилище" or "Сдать (нужно быть у вольта)")
    btnDeliver:SetEnabled(nearVault and cash > 0 and not carrying or false)
    function btnDeliver:Paint(w, h)
        local c = self:IsEnabled() and (self:IsHovered() and INC_UI.accentDk or INC_UI.accent) or Color(80,80,90)
        draw.RoundedBox(4, 0, 0, w, h, c)
    end
    function btnDeliver:DoClick()
        net.Start(NET_CAR_DELIVER); net.SendToServer(); closeFrame(f)
    end
end)

-- Уведомления от сервера
net.Receive(NET_NOTIFY, function()
    local m = net.ReadString()
    local r = net.ReadUInt(8)
    local g = net.ReadUInt(8)
    local b = net.ReadUInt(8)
    chat.AddText(Color(r, g, b), "[ИНКАСС] " .. m)
    notification.AddLegacy(m, NOTIFY_GENERIC, 5)
    surface.PlaySound("buttons/lightswitch2.wav")
end)

-- Единая G-клавиша: терминал / машина / вольт
hook.Add("PlayerButtonDown", "GRM_Incass_GKey", function(ply, button)
    if button ~= KEY_G then return end
    if ply ~= LocalPlayer() then return end
    local tr = ply:GetEyeTrace()
    local hit = IsValid(tr.Entity) and tr.Entity or nil

    -- 1) В прицеле ТЕРМИНАЛ? → взять чемодан
    if IsValid(hit) and hit:GetClass() == "grm_bank_terminal"
       and ply:GetPos():DistToSqr(hit:GetPos()) <= (I.CFG.TerminalRadius or 220)^2 then
        net.Start(NET_TERM_TAKE); net.WriteEntity(hit); net.SendToServer()
        return true
    end

    -- 2) В прицеле ВОЛЬТ? → сдать чемодан из руки
    if IsValid(hit) and hit:GetClass() == "grm_bank_vault"
       and ply:GetPos():DistToSqr(hit:GetPos()) <= (I.CFG.VaultRadius or 320)^2 then
        net.Start(NET_VAULT_DELIVER); net.WriteEntity(hit); net.SendToServer()
        return true
    end

    -- 3) В прицеле ИНКАСС-МАШИНА? → открыть меню (или загрузить чемодан — сервер разберётся)
    local carEntity = nil
    local ec = IsValid(hit) and (hit:GetClass() or "") or ""
    if IsValid(hit) and (hit:IsVehicle() or string.StartWith(ec, "simfphys_")
       or string.StartWith(ec, "lvs_") or string.StartWith(ec, "gmod_sent_vehicle")
       or string.StartWith(ec, "prop_vehicle_")) then
        carEntity = hit
    end
    -- Или машина, в которой игрок сидит
    if not IsValid(carEntity) then
        local veh = ply:GetVehicle()
        if IsValid(veh) then carEntity = getRootVehicle and getRootVehicle(veh) or veh end
    end
    if IsValid(carEntity) and carEntity:GetNWInt("GRM_IncassRun", 0) > 0
       and ply:GetPos():DistToSqr(carEntity:GetPos()) <= 250*250 then
        RunConsoleCommand("grm_incass_car_use")
        return true
    end
end)

-- HUD
local function getMyIncassCar(ply)
    local my = ply:GetNWEntity("GRM_IncassMyCar", NULL)
    if IsValid(my) and my:GetNWInt("GRM_IncassRun", 0) > 0 then return my end
    local veh = ply:GetVehicle()
    if IsValid(veh) then
        local root = veh
        if IsValid(veh:GetParent()) and not veh:GetParent():IsPlayer() then
            local p = veh:GetParent()
            local pc = p:GetClass() or ""
            if string.StartWith(pc, "simfphys_") or string.StartWith(pc, "lvs_")
               or string.StartWith(pc, "gmod_sent_vehicle") then root = p end
        end
        if root:GetNWInt("GRM_IncassRun", 0) > 0 then return root end
    end
    return nil
end

hook.Add("HUDPaint", "GRM_Incass_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) then return end
    local car = getMyIncassCar(ply)
    local carrying = ply:GetNWBool("GRMIncass_Carrying", false)
    local bagAmt = ply:GetNWInt("GRMIncass_BagAmount", 0)

    if carrying and bagAmt > 0 then
        draw.SimpleText("ИНКАСС: в руке чемодан " .. fmt(bagAmt) .. "  [G на машину = загрузить / G на вольт = сдать]",
            "GRMInc_Normal", ScrW()/2, ScrH()-120, Color(120, 200, 255, 230), TEXT_ALIGN_CENTER)
    elseif IsValid(car) then
        local rid = car:GetNWInt("GRM_IncassRun", 0)
        local cash = car:GetNWInt("GRM_IncassCarCash", 0)
        local txt = "ИНКАСС рейс #" .. rid .. " | в машине: " .. fmt(cash) .. "  [G = меню / терминал = взять чемодан]"
        if cash >= (I.CFG.MaxCarryPerCar or 250000) then
            txt = txt .. " (МАШИНА ПОЛНА — сдайте в вольт!)"
        end
        draw.SimpleText(txt, "GRMInc_Normal", ScrW()/2, ScrH()-120, Color(255, 220, 120, 230), TEXT_ALIGN_CENTER)
    end

    -- Подсказка на терминале / вольте
    local tr = ply:GetEyeTrace()
    if IsValid(tr.Entity) then
        local pos = tr.Entity:GetPos()
        local dist = ply:GetPos():DistToSqr(pos)
        if tr.Entity:GetClass() == "grm_bank_terminal" and dist <= 250*250 and IsValid(car) then
            draw.SimpleText("[G] — взять чемодан из терминала", "GRMInc_Normal",
                ScrW()/2, ScrH()/2+40, Color(255, 220, 120, 230), TEXT_ALIGN_CENTER)
        end
        if tr.Entity:GetClass() == "grm_bank_vault" and dist <= 250*250 and carrying then
            draw.SimpleText("[G] — сдать чемодан в хранилище", "GRMInc_Normal",
                ScrW()/2, ScrH()/2+40, Color(120, 255, 160, 230), TEXT_ALIGN_CENTER)
        end
    end
end)

print("[GRM Incass] CLIENT: модуль Код 126 v" .. I.Version .. " загружен")
end -- if SERVER/CLIENT
