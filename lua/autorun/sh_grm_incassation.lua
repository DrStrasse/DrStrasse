--[[--------------------------------------------------------------------
    GRM Incassation (Код 126 — «Инкассация») v1.2.1

    Схема работы по ТЗ владельца:
      1. Игрок садится в служебную машину фракции, за рулём пишет /incass —
         старт рейса, машина помечается NW'ами, игроку присваивается инкасс-машина.
      2. Подъехав к банкомату (grm_bank_terminal) и выйдя из машины — жмёт G,
         открывается МЕНЮ ТЕРМИНАЛА: показывает наличные в терминале, поле
         ввода суммы, кнопки «Забрать указанную сумму» / «Забрать ВСЁ».
         После клика — списывает N из терминала, в правую руку выдаётся
         чемодан (weapon_grm_incass_bag, worldmodel
         models/weapons/w_suitcase_passenger.mdl, holdtype=pistol).
         Деньги НЕ идут в кошелёк/наличку игрока — они в чемодане.
      3. Подходит к инкасс-машине — жмёт G — МЕНЮ МАШИНЫ с двумя кнопками:
         «ЗАГРУЗИТЬ» (чемодан из руки → багажник) / «РАЗГРУЗИТЬ»
         (багажник → чемодан в руку; выгрузка доступна только у вольта).
      4. Подъехав к банку — выходит, жмёт G на машину → РАЗГРУЗИТЬ,
         чемодан в руке.
      5. Подходит к grm_bank_vault (банк-хранилищу) — жмёт G — МЕНЮ ХРАНИЛИЩА:
         счётчик денег в хранилище, кнопки «Загрузить в хранилище»
         (чемодан из руки → HeldCash вольта) / «Выгрузить из хранилища»
         (HeldCash вольта → чемодан в руку).
      6. Команда /incass_off — завершить рейс в любом месте (чемодан из руки
         снимается, деньги в багажнике при отмене не переносятся и не
         пропадают в кошелёк — рейс просто закрывается, груз остаётся в машине
         как её NW-индикатор сброшен; т.е. при удалении ТС пропадает).

    Зависимости:
      - Код 42 (sh_grm_currency.lua)   — GRM.Notify / GRM.Format
      - Код 43 (sh_grm_economy.lua)    — GRM.Economy.*, вольты, гос.бюджет
      - Factions (sh_factions.lua)     — фракции/роли/IncassoSettings
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Incass = GRM.Incass or {}
local I = GRM.Incass

I.Version    = "1.2.1"
I.Code       = 126
I.ModuleName = "incassation"

-- Сетевые строки
local NET_NOTIFY        = "GRM_Incass_Notify"
local NET_TERM_MENU     = "GRM_Incass_TermMenu"
local NET_TERM_TAKE     = "GRM_Incass_TermTake"
local NET_CAR_MENU      = "GRM_Incass_CarMenu"
local NET_CAR_LOAD      = "GRM_Incass_CarLoad"
local NET_CAR_UNLOAD    = "GRM_Incass_CarUnload"
local NET_VAULT_MENU    = "GRM_Incass_VaultMenu"
local NET_VAULT_LOAD    = "GRM_Incass_VaultLoad"
local NET_VAULT_UNLOAD  = "GRM_Incass_VaultUnload"

if SERVER then
    for _, s in ipairs({ NET_NOTIFY, NET_TERM_MENU, NET_TERM_TAKE, NET_CAR_MENU,
                         NET_CAR_LOAD, NET_CAR_UNLOAD, NET_VAULT_MENU,
                         NET_VAULT_LOAD, NET_VAULT_UNLOAD }) do
        util.AddNetworkString(s)
    end
end

-- ──────────────────────────────────────────────────────────────────
-- Настройки (жёстко, по ТЗ)
-- ──────────────────────────────────────────────────────────────────
I.CFG = {
    MaxCarryPerCar         = 250000,
    TerminalRadius         = 220,
    VaultRadius            = 320,
    CarInteractRadius      = 250,
    TerminalDepositCut     = 0.05,
    TerminalMinCollect     = 100,
    RequireDriverSeat      = true,
    LockTerminalOnCollect  = true,
    TerminalCollectCooldown= 120,
    NotifyPoliceRadius     = 1200,
    CarClassCheck          = true,
    BagChunk               = 50000,
    BagWeaponClass         = "weapon_grm_incass_bag",
}

-- ──────────────────────────────────────────────────────────────────
-- Живое состояние
-- ──────────────────────────────────────────────────────────────────
I.ActiveRuns          = {}
I.CarToRun            = {}
I.PlyToCar            = {}
I.LockedTerminals     = {}
I.TerminalCash        = {}
I.TerminalLastCollect = {}
I.NextRunID           = 1
I._carAliasCache      = {}

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

local function getDriverOf(veh)
    if not IsValid(veh) then return nil end
    local ok, d = pcall(function() return veh:GetDriver() end)
    if ok and IsValid(d) and d:IsPlayer() then return d end
    if isfunction(veh.GetDriverSeat) then
        local s
        ok, s = pcall(veh.GetDriverSeat, veh)
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

local function getVehicleSpawnName(veh)
    if not IsValid(veh) then return nil end
    if isstring(veh.GRM_IncassSpawnName) and veh.GRM_IncassSpawnName ~= "" then return veh.GRM_IncassSpawnName end
    for _, fn in ipairs({ "GetSpawn_List", "GetSpawnList", "GetSpawningName",
                          "GetVehicleListName", "GetVehicleName",
                          "GetLVSVehicleName", "GetVehicleClass" }) do
        if isfunction(veh[fn]) then
            local ok, v = pcall(veh[fn], veh)
            if ok and isstring(v) and v ~= "" then return v end
        end
    end
    for _, k in ipairs({ "SpawnList", "Spawn_List", "SpawnName", "VehicleName",
                          "List_ID", "ListName", "LVSVehicleName", "VehicleClassName" }) do
        if isstring(veh[k]) and veh[k] ~= "" then return veh[k] end
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
        local member
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
        if ok and isstring(mdl) then add(mdl); add(mdl:match("([^/\\]+)$")) end
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
            if d < bestD and d <= radius*radius then best, bestD = ent, d end
        end
    end
    return best
end

function I.FindNearestVault(pos, radius)
    radius = radius or I.CFG.VaultRadius
    if GRM.Economy and GRM.Economy.Vaults then
        local best, bestD = nil, math.huge
        for _, ent in pairs(GRM.Economy.Vaults) do
            if IsValid(ent) then
                local d = ent:GetPos():DistToSqr(pos)
                if d < bestD and d <= radius*radius then best, bestD = ent, d end
            end
        end
        return best
    end
    for _, ent in ipairs(ents.FindByClass("grm_bank_vault")) do
        if IsValid(ent) and pos:DistToSqr(ent:GetPos()) <= radius*radius then return ent end
    end
    return nil
end

-- Работа с чемоданом-SWEP в правой руке
function I.PlayerBagAmount(ply)
    if not isPly(ply) then return 0 end
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
    if not IsValid(w) then w = ply:Give(I.CFG.BagWeaponClass) end
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
    if amt > 0 then ply:StripWeapon(I.CFG.BagWeaponClass) end
    ply:SetNWBool("GRMIncass_Carrying", false)
    ply:SetNWInt("GRMIncass_BagAmount", 0)
    return amt
end

function I.NearbyVault(ply)
    return I.FindNearestVault(ply:GetPos(), I.CFG.VaultRadius)
end

----------------------------------------------------------------------
-- SERVER
----------------------------------------------------------------------
if SERVER then

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
        if I.PlayerBagAmount(run.driver) > 0 then I.TakeBagWeapon(run.driver) end
        notify(run.driver, "Рейс инкассации #" .. runID .. " завершён: " .. tostring(reason or "—"), 100, 220, 130)
    end
    I.ActiveRuns[runID] = nil
    print("[GRM Incass] RUN #" .. runID .. " finished: " .. tostring(reason or ""))
end

function I.CancelRun(plyOrCaller, runID, reason)
    local run = I.ActiveRuns[runID]
    if not run then return false end
    I.FinishRun(runID, tostring(reason or ""))
    return true
end

function I.StartRun(ply)
    if not isPly(ply) then return false, "Игрок невалиден" end
    local ok, fnameOrErr = I.CanPlayerIncass(ply)
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
        if not IsValid(drv) then return false, "Сядьте за РУЛЬ (водительское место)" end
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

    notify(ply, "Рейс #" .. runID .. " начат (" .. tostring(spawnName) .. "). Порядок: G у терминала → меню/забрать → чемодан в руке → G у машины → ЗАГРУЗИТЬ → до вольта → G у машины → РАЗГРУЗИТЬ → G у вольта → Загрузить.", 100, 220, 130)

    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) and p ~= ply and p:IsAdmin()
           and p:GetPos():DistToSqr(ply:GetPos()) <= (I.CFG.NotifyPoliceRadius^2) then
            notify(p, "[АДМИН] " .. ply:Nick() .. " начал рейс инкассации #" .. runID, 200, 180, 80)
        end
    end
    print("[GRM Incass] RUN #" .. runID .. " started by " .. ply:Nick())
    return true, runID
end

-- Взять сумму из терминала в руку
function I.CollectFromTerminal(ply, terminal, amount)
    if not isPly(ply) or not IsValid(terminal) or terminal:GetClass() ~= "grm_bank_terminal" then
        return false, "Нет терминала"
    end
    local runID; for rid, r in pairs(I.ActiveRuns) do
        if IsValid(r.driver) and r.driver == ply then runID = rid break end
    end
    if not runID then return false, "У вас нет активного рейса" end
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
        return false, "В руках уже чемодан — загрузите его в машину (G на машину → ЗАГРУЗИТЬ)"
    end
    local run = I.ActiveRuns[runID]
    local free = math.max(0, I.CFG.MaxCarryPerCar - run.carCash)
    if free <= 0 then return false, "Машина полна" end
    amount = math.floor(tonumber(amount) or cash)
    amount = math.Clamp(amount, 1, math.min(cash, free, I.CFG.BagChunk))
    if amount <= 0 then return false, "Некорректная сумма" end
    I.TerminalCash[eid] = cash - amount
    I.TerminalLastCollect[eid] = CurTime()
    if I.CFG.LockTerminalOnCollect then I.LockedTerminals[eid] = runID end
    local w = I.GiveBagWeapon(ply, amount)
    if not IsValid(w) then
        I.TerminalCash[eid] = I.TerminalCash[eid] + amount
        return false, "Не удалось выдать чемодан"
    end
    terminal:EmitSound("buttons/blip1.wav", 55, 100)
    notify(ply, "Чемодан " .. fmt(amount) .. " в руке. Подойдите к машине → G → ЗАГРУЗИТЬ.", 100, 220, 130)
    return true, amount
end

-- Загрузить чемодан из руки в багажник (G у машины + ЗАГРУЗИТЬ)
function I.LoadBagIntoCar(ply, car)
    if not isPly(ply) or not IsValid(car) then return false, "Нет машины" end
    local runID = I.CarToRun[car:EntIndex()]
    if not runID or not I.ActiveRuns[runID] then return false, "Это не инкасс-машина" end
    local run = I.ActiveRuns[runID]
    if run.driver ~= ply then return false, "Это не ваша инкасс-машина" end
    if ply:GetPos():DistToSqr(car:GetPos()) > (I.CFG.CarInteractRadius^2) then return false, "Подойдите к машине" end
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

-- Выгрузить один чемодан из багажника в руку (G у машины + РАЗГРУЗИТЬ, только у вольта)
function I.UnloadBagFromCar(ply, car)
    if not isPly(ply) or not IsValid(car) then return false, "Нет машины" end
    local runID = I.CarToRun[car:EntIndex()]
    if not runID or not I.ActiveRuns[runID] then return false, "Это не инкасс-машина" end
    local run = I.ActiveRuns[runID]
    if run.driver ~= ply then return false, "Это не ваша инкасс-машина" end
    if ply:GetPos():DistToSqr(car:GetPos()) > (I.CFG.CarInteractRadius^2) then return false, "Подойдите к машине" end
    if not I.NearbyVault(ply) then return false, "Разгрузка доступна только у банк-хранилища" end
    if run.carCash <= 0 then return false, "В машине нет денег" end
    if I.PlayerBagAmount(ply) > 0 then return false, "В руках уже чемодан — сдайте его в хранилище" end
    local take = math.min(I.CFG.BagChunk, run.carCash)
    run.carCash = run.carCash - take
    car:SetNWInt("GRM_IncassCarCash", run.carCash)
    local w = I.GiveBagWeapon(ply, take)
    if not IsValid(w) then
        run.carCash = run.carCash + take
        car:SetNWInt("GRM_IncassCarCash", run.carCash)
        return false, "Не удалось взять чемодан"
    end
    car:EmitSound("physics/metal/metal_solid_impact_hard" .. math.random(1,3) .. ".wav", 50, 100)
    notify(ply, "Чемодан " .. fmt(take) .. " в руке. Подойдите к хранилищу → G → Загрузить в хранилище.", 120, 200, 255)
    return true, take
end

-- Загрузить чемодан из руки в вольт
function I.LoadBagIntoVault(ply, vault)
    if not isPly(ply) then return false, "Нет игрока" end
    if not IsValid(vault) or vault:GetClass() ~= "grm_bank_vault" then return false, "Это не банк-хранилище" end
    if ply:GetPos():DistToSqr(vault:GetPos()) > (I.CFG.VaultRadius^2) then return false, "Слишком далеко от хранилища" end
    local amt = I.PlayerBagAmount(ply)
    if amt <= 0 then return false, "В руках нет чемодана" end
    if not (vault.SetHeldCash and vault.GetHeldCash) then return false, "Хранилище не принимает деньги" end
    vault:SetHeldCash(math.floor(vault:GetHeldCash() or 0) + amt)
    if GRM.PermData and GRM.PermData.UpdateEntry then GRM.PermData.UpdateEntry(vault) end
    I.TakeBagWeapon(ply)
    vault:EmitSound("ambient/levels/labs/coinslot1.wav", 65, 95)
    notify(ply, "Загружено в хранилище: " .. fmt(amt) .. ". Всего в хранилище: " .. fmt(math.floor(vault:GetHeldCash() or 0)), 100, 220, 130)
    return true, amt
end

-- Выгрузить чемодан из вольта в руку (обратная операция)
function I.UnloadBagFromVault(ply, vault)
    if not isPly(ply) then return false, "Нет игрока" end
    if not IsValid(vault) or vault:GetClass() ~= "grm_bank_vault" then return false, "Это не банк-хранилище" end
    if ply:GetPos():DistToSqr(vault:GetPos()) > (I.CFG.VaultRadius^2) then return false, "Слишком далеко от хранилища" end
    if not (vault.SetHeldCash and vault.GetHeldCash) then return false, "Хранилище не поддерживает выгрузку" end
    local held = math.floor(vault:GetHeldCash() or 0)
    if held <= 0 then return false, "В хранилище нет денег" end
    if I.PlayerBagAmount(ply) > 0 then return false, "В руках уже чемодан" end
    local take = math.min(I.CFG.BagChunk, held)
    vault:SetHeldCash(held - take)
    if GRM.PermData and GRM.PermData.UpdateEntry then GRM.PermData.UpdateEntry(vault) end
    local w = I.GiveBagWeapon(ply, take)
    if not IsValid(w) then
        vault:SetHeldCash(held)
        if GRM.PermData and GRM.PermData.UpdateEntry then GRM.PermData.UpdateEntry(vault) end
        return false, "Не удалось взять чемодан"
    end
    vault:EmitSound("ambient/levels/labs/coinslot1.wav", 65, 95)
    notify(ply, "Из хранилища выгружено: " .. fmt(take) .. " (в руке). Осталось в хранилище: " .. fmt(math.floor(vault:GetHeldCash() or 0)), 120, 200, 255)
    return true, take
end

-- Комиссия 5% от пополнений терминала оседает в инкасс-ячейке
hook.Add("GRM_Incass_TerminalDeposit", "GRM_Incass_TerminalDeposit", function(ply, amount, terminal)
    if not IsValid(terminal) or terminal:GetClass() ~= "grm_bank_terminal" then return end
    local cut = math.floor((tonumber(amount) or 0) * (I.CFG.TerminalDepositCut or 0))
    if cut <= 0 then return end
    I.TerminalCash[terminal:EntIndex()] = (I.TerminalCash[terminal:EntIndex()] or 0) + cut
end)

-- Блокировка терминалов для обычных игроков
hook.Add("PlayerUse", "GRM_Incass_TermLock", function(ply, ent)
    if not isPly(ply) or not IsValid(ent) then return end
    if ent:GetClass() ~= "grm_bank_terminal" then return end
    local rid = I.LockedTerminals[ent:EntIndex()]
    if not rid then return end
    local myRun; for r2, r in pairs(I.ActiveRuns) do
        if IsValid(r.driver) and r.driver == ply then myRun = r2 break end
    end
    if myRun == rid then return end -- инкассиру рейса — не блокируем (он не использует Use, жмёт G)
    notify(ply, "Этот банкомат обслуживается инкассацией. Попробуйте позже.", 255, 180, 80)
    return false
end)

-- Чужим не сесть в машину рейса
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

-- Удаление ТС → закрыть рейс
hook.Add("EntityRemoved", "GRM_Incass_CarRemoved", function(ent)
    if not IsValid(ent) then return end
    local rid = I.CarToRun[ent:EntIndex()]
    if rid and I.ActiveRuns[rid] then I.CancelRun(nil, rid, "машина удалена/уничтожена") end
    if ent:GetClass() == "grm_bank_terminal" then
        local eid = ent:EntIndex()
        I.TerminalCash[eid] = nil; I.TerminalLastCollect[eid] = nil; I.LockedTerminals[eid] = nil
    end
end)

hook.Add("PlayerDisconnected", "GRM_Incass_DC", function(ply)
    for rid, r in pairs(I.ActiveRuns) do
        if IsValid(r.driver) and r.driver == ply then
            I.CancelRun(nil, rid, "водитель отключился (" .. ply:Nick() .. ")")
        end
    end
end)

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
       or t == "/инкасс_офф" or t == "/инкасс_стоп"
       or t == "/incass_delivery" or t == "!incass_delivery"
       or t == "/incass_deliver" or t == "/сдать" then
        local runID; for rid, r in pairs(I.ActiveRuns) do
            if IsValid(r.driver) and r.driver == ply then runID = rid break end
        end
        if not runID then notify(ply, "У вас нет активного рейса", 255, 100, 100)
        else I.CancelRun(ply, runID, "принудительное завершение (" .. t .. ")") end
        return ""
    end
end)

-- Net: открыть меню терминала
local function sendTerminalMenu(ply, terminal)
    if not isPly(ply) or not IsValid(terminal) or terminal:GetClass() ~= "grm_bank_terminal" then return end
    if ply:GetPos():DistToSqr(terminal:GetPos()) > (I.CFG.TerminalRadius^2) then return end
    local myRun; for rid, r in pairs(I.ActiveRuns) do
        if IsValid(r.driver) and r.driver == ply then myRun = r break end
    end
    if not myRun then
        notify(ply, "У вас нет активного рейса инкассации.", 255, 120, 120); return
    end
    local cash = math.floor(tonumber(I.TerminalCash[terminal:EntIndex()]) or 0)
    net.Start(NET_TERM_MENU)
        net.WriteEntity(terminal)
        net.WriteInt(cash, 32)
        net.WriteInt(myRun.carCash or 0, 32)
        net.WriteInt(I.CFG.MaxCarryPerCar, 32)
        net.WriteInt(I.PlayerBagAmount(ply), 32)
    net.Send(ply)
end

net.Receive(NET_TERM_TAKE, function(_, ply)
    local ent = net.ReadEntity()
    local amt = net.ReadInt(32)
    if not isPly(ply) or not IsValid(ent) then return end
    local ok, err = I.CollectFromTerminal(ply, ent, amt)
    if not ok and err then notify(ply, err, 255, 100, 100) end
end)

-- Net: открыть меню машины
concommand.Add("grm_incass_car_use", function(ply)
    if not isPly(ply) then return end
    local runID; for rid, r in pairs(I.ActiveRuns) do
        if IsValid(r.driver) and r.driver == ply then runID = rid break end
    end
    if not runID then return end
    local run = I.ActiveRuns[runID]
    if not run or not IsValid(run.car) then I.CancelRun(ply, runID, "машина утеряна"); return end
    if ply:GetPos():DistToSqr(run.car:GetPos()) > (I.CFG.CarInteractRadius^2) then return end
    local vault = I.NearbyVault(ply)
    net.Start(NET_CAR_MENU)
        net.WriteEntity(run.car)
        net.WriteInt(run.carCash, 32)
        net.WriteBool(IsValid(vault))
        net.WriteInt(I.PlayerBagAmount(ply), 32)
    net.Send(ply)
end)

net.Receive(NET_CAR_LOAD, function(_, ply)
    local car = net.ReadEntity()
    if not isPly(ply) or not IsValid(car) then return end
    local ok, err = I.LoadBagIntoCar(ply, car)
    if not ok and err then notify(ply, err, 255, 100, 100) end
    -- повторно открыть меню для дальнейших действий
    if ok then
        local runID = I.CarToRun[car:EntIndex()]
        if runID and I.ActiveRuns[runID] and IsValid(I.ActiveRuns[runID].car) then
            net.Start(NET_CAR_MENU)
                net.WriteEntity(car)
                net.WriteInt(I.ActiveRuns[runID].carCash, 32)
                net.WriteBool(IsValid(I.NearbyVault(ply)))
                net.WriteInt(I.PlayerBagAmount(ply), 32)
            net.Send(ply)
        end
    end
end)

net.Receive(NET_CAR_UNLOAD, function(_, ply)
    local car = net.ReadEntity()
    if not isPly(ply) or not IsValid(car) then return end
    local ok, err = I.UnloadBagFromCar(ply, car)
    if not ok and err then notify(ply, err, 255, 100, 100) end
end)

-- Net: открыть меню вольта
net.Receive(NET_VAULT_MENU, function(_, ply)
    local vault = net.ReadEntity()
    if not isPly(ply) or not IsValid(vault) then return end
    if vault:GetClass() ~= "grm_bank_vault" then return end
    if ply:GetPos():DistToSqr(vault:GetPos()) > (I.CFG.VaultRadius^2) then return end
    local held = 0
    if vault.GetHeldCash then held = math.floor(vault:GetHeldCash() or 0) end
    net.Start(NET_VAULT_MENU)
        net.WriteEntity(vault)
        net.WriteInt(held, 32)
        net.WriteInt(I.PlayerBagAmount(ply), 32)
    net.Send(ply)
end)

net.Receive(NET_VAULT_LOAD, function(_, ply)
    local vault = net.ReadEntity()
    if not isPly(ply) or not IsValid(vault) then return end
    local ok, err = I.LoadBagIntoVault(ply, vault)
    if not ok and err then notify(ply, err, 255, 100, 100) end
end)

net.Receive(NET_VAULT_UNLOAD, function(_, ply)
    local vault = net.ReadEntity()
    if not isPly(ply) or not IsValid(vault) then return end
    local ok, err = I.UnloadBagFromVault(ply, vault)
    if not ok and err then notify(ply, err, 255, 100, 100) end
end)

-- Отладка
concommand.Add("grm_incass_debug", function(ply)
    if not isPly(ply) or not ply:IsSuperAdmin() then return end
    local veh = ply:GetVehicle()
    if not IsValid(veh) then ply:PrintMessage(HUD_PRINTCONSOLE, "[INCASS DEBUG] Вы не в ТС"); return end
    local root = getRootVehicle(veh)
    local spn = getVehicleSpawnName(root)
    ply:PrintMessage(HUD_PRINTCONSOLE, "[INCASS DEBUG] seat=" .. tostring(veh:GetClass()) .. " root=" .. tostring(IsValid(root) and root:GetClass() or "nil"))
    ply:PrintMessage(HUD_PRINTCONSOLE, "[INCASS DEBUG] getVehicleSpawnName=" .. tostring(spn))
    ply:PrintMessage(HUD_PRINTCONSOLE, "[INCASS DEBUG] bagInHands=" .. tostring(I.PlayerBagAmount(ply)))
    local myCar = ply:GetNWEntity("GRM_IncassMyCar", NULL)
    if IsValid(myCar) then
        local rid = I.CarToRun[myCar:EntIndex()]
        ply:PrintMessage(HUD_PRINTCONSOLE, "[INCASS DEBUG] myCar run=" .. tostring(rid) .. " carCash=" .. tostring(rid and I.ActiveRuns[rid] and I.ActiveRuns[rid].carCash))
    end
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
    accent  = Color(220, 170, 60),
    accentDk= Color(170, 120, 30),
    success = Color(70, 180, 100),
    danger  = Color(210, 70, 70),
    text    = Color(235, 235, 240),
    dim     = Color(160, 165, 178),
}

local function closeFrame(fr) if IsValid(fr) then fr:Remove() end end
local GRM_INC_TERM_FRAME, GRM_INC_CAR_FRAME, GRM_INC_VAULT_FRAME

-- МЕНЮ ТЕРМИНАЛА
net.Receive(NET_TERM_MENU, function()
    local term = net.ReadEntity()
    local cash = net.ReadInt(32)
    local inCar = net.ReadInt(32)
    local cap   = net.ReadInt(32)
    local bag   = net.ReadInt(32)
    closeFrame(GRM_INC_TERM_FRAME)
    local f = vgui.Create("DFrame"); GRM_INC_TERM_FRAME = f
    f:SetSize(420, 300); f:Center(); f:SetTitle(""); f:MakePopup()
    function f:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, INC_UI.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 38, Color(40,45,58), true, true, false, false)
        draw.SimpleText("Банкомат (инкассация)", "GRMInc_Title", 12, 20, INC_UI.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
    line("Наличных в терминале: " .. (GRM.Incass.FormatMoney and GRM.Incass.FormatMoney(cash) or tostring(cash)), INC_UI.accent, 6)
    line("В машине: " .. (GRM.Incass.FormatMoney and GRM.Incass.FormatMoney(inCar) or tostring(inCar)) .. " / " .. tostring(cap), INC_UI.dim)
    if bag > 0 then line("В руках чемодан: " .. fmt_bag(bag), INC_UI.danger) end
    if cash < (I.CFG and I.CFG.TerminalMinCollect or 100) then
        line("В терминале слишком мало наличных для изъятия.", INC_UI.dim)
    end
    local amountEntry = vgui.Create("DTextEntry", body)
    amountEntry:Dock(TOP); amountEntry:DockMargin(4, 14, 4, 6)
    amountEntry:SetTall(28); amountEntry:SetFont("GRMInc_Normal")
    amountEntry:SetNumeric(true); amountEntry:SetText(tostring(math.max(0, cash)))
    local function take(amount)
        net.Start(NET_TERM_TAKE); net.WriteEntity(term); net.WriteInt(amount, 32); net.SendToServer()
        closeFrame(f)
    end
    local btnTake = vgui.Create("DButton", body)
    btnTake:Dock(TOP); btnTake:DockMargin(4, 8, 4, 4); btnTake:SetTall(34); btnTake:SetFont("GRMInc_Normal")
    btnTake:SetText("Забрать указанную сумму")
    btnTake:SetEnabled(cash > 0 and bag <= 0)
    function btnTake:Paint(w, h)
        local c = self:IsEnabled() and (self:IsHovered() and INC_UI.accentDk or INC_UI.accent) or Color(80,80,90)
        draw.RoundedBox(4, 0, 0, w, h, c)
    end
    function btnTake:DoClick()
        local v = math.floor(tonumber(amountEntry:GetText()) or 0)
        if v > 0 then take(v) end
    end
    local btnTakeAll = vgui.Create("DButton", body)
    btnTakeAll:Dock(TOP); btnTakeAll:DockMargin(4, 2, 4, 4); btnTakeAll:SetTall(28); btnTakeAll:SetFont("GRMInc_Normal")
    btnTakeAll:SetText("Забрать ВСЁ")
    btnTakeAll:SetEnabled(cash > 0 and bag <= 0)
    function btnTakeAll:Paint(w, h)
        local c = self:IsEnabled() and (self:IsHovered() and Color(50,160,80) or INC_UI.success) or Color(80,80,90)
        draw.RoundedBox(4, 0, 0, w, h, c)
    end
    function btnTakeAll:DoClick() take(math.max(0, cash)) end
end)

-- МЕНЮ МАШИНЫ: ЗАГРУЗИТЬ / РАЗГРУЗИТЬ
net.Receive(NET_CAR_MENU, function()
    local car = net.ReadEntity(); local cash = net.ReadInt(32)
    local nearVault = net.ReadBool(); local bag = net.ReadInt(32)
    closeFrame(GRM_INC_CAR_FRAME)
    local f = vgui.Create("DFrame"); GRM_INC_CAR_FRAME = f
    f:SetSize(420, 260); f:Center(); f:SetTitle(""); f:MakePopup()
    function f:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, INC_UI.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 38, Color(40,45,58), true, true, false, false)
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
    line("В багажнике: " .. (GRM.Incass.FormatMoney and GRM.Incass.FormatMoney(cash) or tostring(cash)) .. " / " .. tostring(I.CFG.MaxCarryPerCar), INC_UI.accent, 6)
    if bag > 0 then line("В руках чемодан: " .. (GRM.Incass.FormatMoney and GRM.Incass.FormatMoney(bag) or tostring(bag)), Color(120,200,255)) end
    if not nearVault then line("Разгрузка доступна только у банк-хранилища.", INC_UI.danger) end

    local function mkBtn(text, enabled, color, fn)
        local b = vgui.Create("DButton", body)
        b:Dock(BOTTOM); b:DockMargin(4, 6, 4, 4); b:SetTall(38); b:SetFont("GRMInc_Normal")
        b:SetText(text); b:SetEnabled(enabled)
        function b:Paint(w, h)
            local c = self:IsEnabled() and (self:IsHovered() and INC_UI.accentDk or (color or INC_UI.accent)) or Color(80,80,90)
            draw.RoundedBox(4, 0, 0, w, h, c)
        end
        function b:DoClick() if self:IsEnabled() then fn() end end
        return b
    end
    mkBtn("ЗАГРУЗИТЬ (чемодан из руки → багажник)", bag > 0, INC_UI.success, function()
        net.Start(NET_CAR_LOAD); net.WriteEntity(car); net.SendToServer()
        closeFrame(f)
    end)
    mkBtn("РАЗГРУЗИТЬ (багажник → чемодан в руку)", nearVault and cash > 0 and bag <= 0, INC_UI.accent, function()
        net.Start(NET_CAR_UNLOAD); net.WriteEntity(car); net.SendToServer()
        closeFrame(f)
    end)
end)

-- МЕНЮ ВОЛЬТА: загрузить / выгрузить + счётчик
net.Receive(NET_VAULT_MENU, function()
    local vault = net.ReadEntity(); local held = net.ReadInt(32); local bag = net.ReadInt(32)
    closeFrame(GRM_INC_VAULT_FRAME)
    local f = vgui.Create("DFrame"); GRM_INC_VAULT_FRAME = f
    f:SetSize(420, 240); f:Center(); f:SetTitle(""); f:MakePopup()
    function f:Paint(w, h)
        draw.RoundedBox(8, 0, 0, w, h, INC_UI.bg)
        draw.RoundedBoxEx(8, 0, 0, w, 38, Color(40,45,58), true, true, false, false)
        draw.SimpleText("Банк-хранилище", "GRMInc_Title", 12, 20, INC_UI.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
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
    line("В хранилище: " .. (GRM.Incass.FormatMoney and GRM.Incass.FormatMoney(held) or tostring(held)), INC_UI.accent, 6)
    if bag > 0 then line("В руках чемодан: " .. (GRM.Incass.FormatMoney and GRM.Incass.FormatMoney(bag) or tostring(bag)), Color(120,200,255)) end
    local function mkBtn(text, enabled, color, fn)
        local b = vgui.Create("DButton", body)
        b:Dock(BOTTOM); b:DockMargin(4, 6, 4, 4); b:SetTall(38); b:SetFont("GRMInc_Normal")
        b:SetText(text); b:SetEnabled(enabled)
        function b:Paint(w, h)
            local c = self:IsEnabled() and (self:IsHovered() and INC_UI.accentDk or (color or INC_UI.accent)) or Color(80,80,90)
            draw.RoundedBox(4, 0, 0, w, h, c)
        end
        function b:DoClick() if self:IsEnabled() then fn() end end
        return b
    end
    mkBtn("ЗАГРУЗИТЬ в хранилище (чемодан из руки → хранилище)", bag > 0, INC_UI.success, function()
        net.Start(NET_VAULT_LOAD); net.WriteEntity(vault); net.SendToServer()
        closeFrame(f)
    end)
    mkBtn("ВЫГРУЗИТЬ из хранилища (хранилище → чемодан в руку)", held > 0 and bag <= 0, INC_UI.accent, function()
        net.Start(NET_VAULT_UNLOAD); net.WriteEntity(vault); net.SendToServer()
        closeFrame(f)
    end)
end)

-- Уведомления
net.Receive(NET_NOTIFY, function()
    local m = net.ReadString()
    local r = net.ReadUInt(8); local g = net.ReadUInt(8); local b = net.ReadUInt(8)
    chat.AddText(Color(r, g, b), "[ИНКАСС] " .. m)
    notification.AddLegacy(m, NOTIFY_GENERIC, 5)
    surface.PlaySound("buttons/lightswitch2.wav")
end)

-- Вспомогательная форматировка для клиента (до загрузки I.CFG использует safe fmt)
local function fmt_bag(n)
    n = math.floor(tonumber(n) or 0)
    if GRM.Format then
        local ok, s = pcall(GRM.Format, n)
        if ok then return s end
    end
    return tostring(n) .. " GRM"
end

-- Единый G
hook.Add("PlayerButtonDown", "GRM_Incass_GKey", function(ply, button)
    if button ~= KEY_G then return end
    if ply ~= LocalPlayer() then return end
    local tr = ply:GetEyeTrace()
    local hit = IsValid(tr.Entity) and tr.Entity or nil

    -- Приоритет: терминал → вольт → машина в прицеле / машина где сидит
    if IsValid(hit) and hit:GetClass() == "grm_bank_terminal"
       and ply:GetPos():DistToSqr(hit:GetPos()) <= ((I.CFG and I.CFG.TerminalRadius or 220)^2) then
        RunConsoleCommand("grm_incass_term_use")
        return true
    end

    if IsValid(hit) and hit:GetClass() == "grm_bank_vault"
       and ply:GetPos():DistToSqr(hit:GetPos()) <= ((I.CFG and I.CFG.VaultRadius or 320)^2) then
        RunConsoleCommand("grm_incass_vault_use")
        return true
    end

    local car = nil
    local ec = IsValid(hit) and (hit:GetClass() or "") or ""
    if IsValid(hit) and (hit:IsVehicle() or string.StartWith(ec, "simfphys_")
       or string.StartWith(ec, "lvs_") or string.StartWith(ec, "gmod_sent_vehicle")
       or string.StartWith(ec, "prop_vehicle_")) then
        car = hit
    end
    if not IsValid(car) then
        local veh = ply:GetVehicle()
        if IsValid(veh) then car = getRootVehicle(veh) end
    end
    if IsValid(car) and car:GetNWInt("GRM_IncassRun", 0) > 0
       and ply:GetPos():DistToSqr(car:GetPos()) <= 250*250 then
        RunConsoleCommand("grm_incass_car_use")
        return true
    end
end)

-- Вспомогательные getRootVehicle на клиенте (копия для использования в HUD)
local function getRootVehicleClient(ent)
    if not IsValid(ent) then return nil end
    local cur = ent
    local seen = {}
    for _ = 1, 8 do
        if not IsValid(cur) then break end
        seen[cur] = true
        local p = cur:GetParent()
        if IsValid(p) and not p:IsPlayer() and not p:IsWorld() then
            local pc = p:GetClass() or ""
            local isCar = p:IsVehicle() or string.StartWith(pc,"simfphys_") or string.StartWith(pc,"lvs_")
                          or string.StartWith(pc,"gmod_sent_vehicle") or string.StartWith(pc,"prop_vehicle_")
            if isCar and not seen[p] then cur = p else break end
        else break end
    end
    return cur
end

local function getMyIncassCar(ply)
    local my = ply:GetNWEntity("GRM_IncassMyCar", NULL)
    if IsValid(my) and my:GetNWInt("GRM_IncassRun", 0) > 0 then return my end
    local veh = ply:GetVehicle()
    if IsValid(veh) then
        local root = getRootVehicleClient(veh)
        if IsValid(root) and root:GetNWInt("GRM_IncassRun", 0) > 0 then return root end
    end
    return nil
end

-- HUD
hook.Add("HUDPaint", "GRM_Incass_HUD", function()
    local ply = LocalPlayer(); if not IsValid(ply) then return end
    local car = getMyIncassCar(ply)
    local carrying = ply:GetNWBool("GRMIncass_Carrying", false)
    local bagAmt = ply:GetNWInt("GRMIncass_BagAmount", 0)
    if carrying and bagAmt > 0 then
        draw.SimpleText("ИНКАСС: в руке чемодан " .. fmt_bag(bagAmt),
            "GRMInc_Normal", ScrW()/2, ScrH()-120, Color(120, 200, 255, 230), TEXT_ALIGN_CENTER)
        draw.SimpleText("[G на машину = загрузить / G на хранилище = сдать]",
            "GRMInc_Small", ScrW()/2, ScrH()-98, Color(180, 210, 255, 210), TEXT_ALIGN_CENTER)
    elseif IsValid(car) then
        local rid = car:GetNWInt("GRM_IncassRun", 0)
        local cash = car:GetNWInt("GRM_IncassCarCash", 0)
        local txt = "ИНКАСС рейс #" .. rid .. " | в машине: " .. fmt_bag(cash)
        if cash >= (I.CFG and I.CFG.MaxCarryPerCar or 250000) then
            txt = txt .. " (МАШИНА ПОЛНА)"
        else
            txt = txt .. "  [G = меню]"
        end
        draw.SimpleText(txt, "GRMInc_Normal", ScrW()/2, ScrH()-120, Color(255, 220, 120, 230), TEXT_ALIGN_CENTER)
    end
    local tr = ply:GetEyeTrace()
    if IsValid(tr.Entity) then
        local pos = tr.Entity:GetPos()
        local d = ply:GetPos():DistToSqr(pos)
        if tr.Entity:GetClass() == "grm_bank_terminal" and d <= 250*250 and IsValid(car) then
            draw.SimpleText("[G] — открыть меню терминала (изъять деньги)", "GRMInc_Normal",
                ScrW()/2, ScrH()/2+40, Color(255, 220, 120, 230), TEXT_ALIGN_CENTER)
        elseif tr.Entity:GetClass() == "grm_bank_vault" and d <= 250*250 then
            draw.SimpleText("[G] — открыть меню хранилища", "GRMInc_Normal",
                ScrW()/2, ScrH()/2+40, Color(120, 255, 160, 230), TEXT_ALIGN_CENTER)
        end
    end
end)

print("[GRM Incass] CLIENT: модуль Код 126 v" .. I.Version .. " загружен")
end -- if SERVER/CLIENT

-- Серверные concommand-открывалки меню терминала/вольта (триггер по G)
if SERVER then
    concommand.Add("grm_incass_term_use", function(ply)
        if not isPly(ply) then return end
        local tr = ply:GetEyeTrace()
        if IsValid(tr.Entity) and tr.Entity:GetClass() == "grm_bank_terminal" then
            sendTerminalMenu(ply, tr.Entity)
        end
    end)
    concommand.Add("grm_incass_vault_use", function(ply)
        if not isPly(ply) then return end
        local tr = ply:GetEyeTrace()
        if not IsValid(tr.Entity) or tr.Entity:GetClass() ~= "grm_bank_vault" then return end
        local v = tr.Entity
        if ply:GetPos():DistToSqr(v:GetPos()) > (I.CFG.VaultRadius^2) then return end
        local held = v.GetHeldCash and math.floor(v:GetHeldCash() or 0) or 0
        net.Start(NET_VAULT_MENU)
            net.WriteEntity(v)
            net.WriteInt(held, 32)
            net.WriteInt(I.PlayerBagAmount(ply), 32)
        net.Send(ply)
    end)
end
