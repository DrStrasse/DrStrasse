--[[--------------------------------------------------------------------
    GRM Persistence Guard v1.1.0 (Код 62)

    Загружается раньше остальных GRM-модулей и снимает boot-копию важных
    DATA-файлов до того, как какой-либо поздний загрузчик успеет записать
    поверх них пустую таблицу. Даёт единый выбор primary/backup по числу
    полезных полей и подробный LOAD-лог с точным именем источника.
----------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() end
if not SERVER then return end

GRM = GRM or {}
GRM.PersistenceGuard = GRM.PersistenceGuard or {}
local P = GRM.PersistenceGuard
P.Version = "1.1.0"
P.Boot = P.Boot or {}

local function jsonT(raw)
    if not isstring(raw) or string.Trim(raw) == "" then return nil end
    local ok, data = pcall(util.JSONToTable, raw, false, true)
    return ok and istable(data) and data or nil
end
P.JSONToTable = jsonT

local function score(value, depth, seen)
    if not istable(value) then return value == nil and 0 or 1 end
    depth = depth or 0
    if depth > 6 then return 1 end
    seen = seen or {}
    if seen[value] then return 0 end
    seen[value] = true
    local n = 0
    for k, v in pairs(value) do
        n = n + 1
        if n >= 20000 then break end
        n = n + score(k, depth + 1, seen) + score(v, depth + 1, seen)
    end
    seen[value] = nil
    return n
end
P.Score = score

local function snapshot(path)
    path = tostring(path or "")
    if path == "" or P.Boot[path] then return end
    local exists = file.Exists(path, "DATA")
    local raw = exists and (file.Read(path, "DATA") or "") or ""
    local data = jsonT(raw)
    P.Boot[path] = {
        exists = exists,
        raw = raw,
        valid = istable(data),
        score = istable(data) and score(data) or 0,
        bytes = #raw,
    }
end
P.Snapshot = snapshot

local map = string.lower(game.GetMap() or "unknown")
for _, path in ipairs({
    "factions.json", "factions_backup.json", "invites.json", "grm_characters.json", "grm_characters_backup.json",
    "grm_inventories.json", "grm_inventories_backup.json",
    "grm_documents.json", "grm_documents_backup.json",
    "grm_medcards.json", "grm_medcards_backup.json", "grm_medcfg.json",
    "grm_services/services.json", "grm_services/services.json.backup",
    "grm_services/invoices.json", "grm_services/invoices.json.backup",
    "grm_services/diplomas.json", "grm_services/diplomas.json.backup",
    "grm_perm_entities.json", "grm_perm_entities_backup.json",
    "grm_wallet.json", "grm_wallet_backup.json",
    "grm_treasury.json", "grm_treasury_backup.json", "grm_bank_nicks.json",
    "grm_vehicle_garages.json", "grm_vehicle_garages.json.backup",
    "grm_vehicle_dealers/" .. map .. ".json", "grm_vehicle_dealers/" .. map .. ".json.backup",
    "grm_factory_fullcycle/maps/" .. map .. ".json", "grm_factory_fullcycle/maps/" .. map .. ".json.backup",
    "grm_factory_fullcycle/weapon_lockers.json", "grm_factory_fullcycle/weapon_lockers.json.backup",
    "grm_factory_fullcycle/weapon_buyers.json", "grm_factory_fullcycle/weapon_buyers.json.backup",
    "grm_factory_fullcycle/weapon_market.json", "grm_factory_fullcycle/weapon_market.json.backup",
    "grm_food/vending_" .. map .. ".json", "grm_food/vending_" .. map .. ".json.backup",
    "grm_electronics/database.json", "grm_electronics/database.json.backup",
    "grm_electronics/" .. map .. ".json", "grm_electronics/" .. map .. ".json.backup",
    "grm_logistics/maps/" .. map .. ".json", "grm_logistics/maps/" .. map .. ".json.backup",
    "grm_phone/" .. map .. ".json", "grm_phone/" .. map .. ".json.backup",
    "grm_roomtap/maps/" .. map .. ".json", "grm_roomtap/maps/" .. map .. ".json.backup",
    "grm_cctv/" .. map .. ".json", "grm_cctv/" .. map .. ".json.backup",
    "grm_alarm/" .. map .. ".json", "grm_alarm/" .. map .. ".json.backup",
}) do snapshot(path) end

-- opts.score(table)->number может переопределить универсальную оценку.
-- Возврат: data, source, raw, meta{hadAny,invalid,score}.
function P.ReadBest(primary, backups, label, opts)
    primary = tostring(primary or "")
    backups = istable(backups) and backups or (isstring(backups) and { backups } or {})
    opts = istable(opts) and opts or {}
    local paths, seen = { primary }, { [primary] = true }
    for _, path in ipairs(backups) do
        path = tostring(path or "")
        if path ~= "" and not seen[path] then paths[#paths + 1], seen[path] = path, true end
    end
    local candidates, hadAny, invalid = {}, false, {}
    local eval = isfunction(opts.score) and opts.score or score
    local function add(path, raw, source, priority)
        if not isstring(raw) or raw == "" then return end
        hadAny = true
        local data = jsonT(raw)
        if not istable(data) then invalid[#invalid + 1] = source return end
        local okS, n = pcall(eval, data)
        n = okS and math.max(0, tonumber(n) or 0) or 0
        candidates[#candidates + 1] = { path = path, source = source, raw = raw, data = data, score = n, priority = priority }
    end
    for index, path in ipairs(paths) do
        local raw = file.Exists(path, "DATA") and (file.Read(path, "DATA") or "") or ""
        add(path, raw, path, 100 - index)
        local boot = P.Boot[path]
        if boot and boot.exists then add(path, boot.raw, path .. "@boot", 50 - index) end
    end
    table.sort(candidates, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.priority > b.priority
    end)
    -- Валидный непустой primary авторитетен даже если старый backup содержит
    -- больше записей (легальное удаление не должно воскресать). Backup/boot
    -- выигрывает только у пустого либо неразбираемого primary.
    local bestPrimary, bestBackup
    for _, cand in ipairs(candidates) do
        if cand.path == primary and not bestPrimary then bestPrimary = cand
        elseif cand.path ~= primary and not bestBackup then bestBackup = cand end
    end
    local best
    if bestPrimary and bestPrimary.score > 0 then best = bestPrimary
    elseif bestBackup and bestBackup.score > (bestPrimary and bestPrimary.score or -1) then best = bestBackup
    else best = bestPrimary or bestBackup end
    local tag = tostring(label or primary)
    if not best then
        if hadAny then
            print(("[GRM Persist][!] %s: нет валидного JSON; кандидаты: %s"):format(tag, table.concat(invalid, ", ")))
        else
            print(("[GRM Persist] %s: файлы отсутствуют, новый контур"):format(tag))
        end
        return nil, nil, nil, { hadAny = hadAny, invalid = invalid, score = 0 }
    end
    print(("[GRM Persist] %s: LOAD data/%s, score=%d, bytes=%d"):format(tag, best.source, best.score, #best.raw))
    return best.data, best.source, best.raw, { hadAny = hadAny, invalid = invalid, score = best.score }
end

function P.Materialize(primary, backup, raw, label)
    if not isstring(raw) or raw == "" or not jsonT(raw) then return false end
    file.Write(primary, raw)
    if file.Read(primary, "DATA") ~= raw then
        print("[GRM Persist][!] materialize primary failed: data/" .. tostring(primary))
        return false
    end
    if isstring(backup) and backup ~= "" then
        file.Write(backup, raw)
        if file.Read(backup, "DATA") ~= raw then
            print("[GRM Persist][!] materialize backup failed: data/" .. tostring(backup))
            return false
        end
    end
    print(("[GRM Persist] %s: primary/backup синхронизированы"):format(tostring(label or primary)))
    return true
end

function P.WriteMirrored(primary, backup, data, label)
    local ok, raw = pcall(util.TableToJSON, data, true)
    if not ok or not isstring(raw) or not jsonT(raw) then
        print("[GRM Persist][!] " .. tostring(label or primary) .. ": сериализация отклонена")
        return false
    end
    return P.Materialize(primary, backup, raw, label)
end

function P.Audit()
    print("[GRM Persist] ===== BOOT DATA AUDIT =====")
    local paths = {}
    for path in pairs(P.Boot) do paths[#paths + 1] = path end
    table.sort(paths)
    for _, path in ipairs(paths) do
        local r = P.Boot[path]
        if r.exists then
            print(("[GRM Persist] data/%s bytes=%d valid=%s score=%d"):format(path, r.bytes, tostring(r.valid), r.score))
        end
    end
    print("[GRM Persist] ===== END AUDIT =====")
end

concommand.Add("grm_persistence_audit", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end
    P.Audit()
end)

print("[GRM Persist] guard v" .. P.Version .. " captured boot files")
