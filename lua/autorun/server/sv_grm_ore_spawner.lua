--[[
    GRM Ore Spawner – автоматический респавн узлов руды в заданных точках
    (версия БЕЗ проверки валидности – точки ставятся по прицелу)
]]

if SERVER then
    GRM = GRM or {}
    GRM.OreSpawner = GRM.OreSpawner or {}
    local OS = GRM.OreSpawner
    OS.Version = "1.1.0"
    OS.LoadBlocked = OS.LoadBlocked == true

    -- ============================================================
    -- КОНФИГУРАЦИЯ
    -- ============================================================
    local SAVE_DIR        = "grm_saves"
    local MAP_NAME        = string.lower(game.GetMap() or "unknown")
    local SPAWN_FILE      = SAVE_DIR .. "/grm_orespawns_" .. MAP_NAME .. ".json"
    local SPAWN_BACKUP    = SAVE_DIR .. "/grm_orespawns_" .. MAP_NAME .. "_backup.json"

    local SPAWN_INTERVAL  = 100  -- 1 минут
    local MIN_ORE_COUNT   = 8    -- минимальное количество узлов на карте
    local OCCUPY_RADIUS   = 48   -- минимальная дистанция между узлами

    local ORE_TYPES = {"copper", "gold", "aluminum", "platinum"}

    -- Глобальная таблица точек (сохраняется между перезагрузками скрипта)
    SpawnPoints = SpawnPoints or {}

    -- ============================================================
    -- ЗАГРУЗКА / СОХРАНЕНИЕ точек (с защитой от сброса)
    -- ============================================================
    local function PointFromTable(t)
        if not istable(t) or not istable(t.pos) then return nil end
        local p = t.pos
        if not (isnumber(p.x) and isnumber(p.y) and isnumber(p.z)) then return nil end
        local a = t.ang or {}
        return {
            pos = Vector(p.x, p.y, p.z),
            ang = Angle(tonumber(a.p) or 0, tonumber(a.y) or 0, tonumber(a.r) or 0),
        }
    end

    local function PointToTable(point)
        return { pos = { x = point.pos.x, y = point.pos.y, z = point.pos.z },
            ang = { p = point.ang.p, y = point.ang.y, r = point.ang.r } }
    end

    local function validatePointArray(data)
        if not istable(data) then return false, "база точек не является таблицей" end
        for key in pairs(data) do
            if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then return false, "база точек не является массивом" end
        end
        local parsed = {}
        for index, row in ipairs(data) do
            local point = PointFromTable(row)
            if not point then return false, "повреждённая точка руды #" .. index end
            parsed[#parsed + 1] = point
        end
        return true, parsed
    end

    local function LoadSpawnPoints()
        local guard, data, source, raw, meta = GRM.PersistenceGuard
        if guard and guard.ReadBest then
            data, source, raw, meta = guard.ReadBest(SPAWN_FILE, { SPAWN_BACKUP }, "ore spawn points")
        else
            raw = file.Exists(SPAWN_FILE, "DATA") and (file.Read(SPAWN_FILE, "DATA") or "") or ""
            local ok, parsed = pcall(util.JSONToTable, raw, false, true)
            data = ok and istable(parsed) and parsed or nil
            source = data and SPAWN_FILE or nil
            meta = { hadAny = raw ~= "" }
        end
        if not istable(data) then
            OS.LoadBlocked = meta and meta.hadAny == true
            if OS.LoadBlocked then
                print("[GRM Ore Spawner][!] LOAD BLOCKED: primary/backup повреждены; живые точки сохранены")
                return false, "primary/backup точек повреждены"
            end
            SpawnPoints = {}
            print("[GRM Ore Spawner] Файл точек отсутствует, новый контур.")
            return true, "точек спавна: 0 (новый контур)"
        end
        local valid, parsed = validatePointArray(data)
        if not valid then
            OS.LoadBlocked = true
            print("[GRM Ore Spawner][!] LOAD rejected: " .. tostring(parsed) .. "; живые точки сохранены")
            return false, tostring(parsed)
        end
        if guard and guard.Materialize and raw and not guard.Materialize(SPAWN_FILE, SPAWN_BACKUP, raw, "ore spawn points") then
            OS.LoadBlocked = true
            return false, "не удалось восстановить primary/backup точек"
        end
        OS.LoadBlocked = false
        SpawnPoints = parsed
        print("[GRM Ore Spawner] LOAD source=" .. tostring(source) .. " points=" .. #SpawnPoints)
        return true, "загружено точек спавна: " .. #SpawnPoints
    end

    local function SaveSpawnPoints()
        if OS.LoadBlocked then
            print("[GRM Ore Spawner][!] SAVE BLOCKED после ошибки primary/backup")
            return false, "сохранение точек заблокировано"
        end
        if not file.Exists(SAVE_DIR, "DATA") then file.CreateDir(SAVE_DIR) end
        local out = {}
        for _, point in ipairs(SpawnPoints) do out[#out + 1] = PointToTable(point) end
        local guard, ok = GRM.PersistenceGuard, false
        if guard and guard.WriteMirrored then
            ok = guard.WriteMirrored(SPAWN_FILE, SPAWN_BACKUP, out, "ore spawn points")
        else
            local okJ, raw = pcall(util.TableToJSON, out, true)
            ok = okJ and isstring(raw) and raw ~= ""
            if ok then
                file.Write(SPAWN_FILE, raw); file.Write(SPAWN_BACKUP, raw)
                ok = file.Read(SPAWN_FILE, "DATA") == raw and file.Read(SPAWN_BACKUP, "DATA") == raw
            end
        end
        print("[GRM Ore Spawner] SAVE " .. tostring(ok) .. " points=" .. #SpawnPoints)
        return ok == true, ok and ("сохранено точек спавна: " .. #SpawnPoints) or "ошибка записи/read-back точек"
    end

    OS.LoadPoints = LoadSpawnPoints
    OS.SavePoints = SaveSpawnPoints
    OS.GetPoints = function() return SpawnPoints end
    function OS.RemovePointAt(pos, tolerance)
        if not pos then return false end
        local r2, best, bestD = (tonumber(tolerance) or 80) ^ 2, nil, nil
        for index, point in ipairs(SpawnPoints) do
            local dx, dy, dz = point.pos.x - pos.x, point.pos.y - pos.y, point.pos.z - pos.z
            local d2 = dx * dx + dy * dy + dz * dz
            if d2 <= r2 and (not bestD or d2 < bestD) then best, bestD = index, d2 end
        end
        if not best then return false end
        table.remove(SpawnPoints, best)
        local ok = SaveSpawnPoints()
        return ok == true
    end

    -- ============================================================
    -- УПРАВЛЕНИЕ ТОЧКАМИ (добавление по прицелу, БЕЗ валидности)
    -- ============================================================
    local function AddSpawnPoint(pos, ang)
        table.insert(SpawnPoints, {
            pos = Vector(pos.x, pos.y, pos.z),
            ang = Angle(ang.p, ang.y, ang.r),
        })
        SaveSpawnPoints()
    end

    local function RemoveSpawnPoint(index)
        if index >= 1 and index <= #SpawnPoints then
            table.remove(SpawnPoints, index)
            SaveSpawnPoints()
            return true
        end
        return false
    end

    -- ============================================================
    -- СПАВН РУДЫ (без проверки валидности)
    -- ============================================================
    local function IsOccupied(pos)
        for _, ent in ipairs(ents.FindInSphere(pos, OCCUPY_RADIUS)) do
            if ent:GetClass() == "grm_ore_node" then return true end
        end
        return false
    end

    local function SpawnOreNode(pos, ang)
        local node = ents.Create("grm_ore_node")
        if not IsValid(node) then return false end
        node.GRMOreSpawned = true
        node:SetPos(pos)
        node:SetAngles(ang or Angle(0, 0, 0))
        node:Spawn()
        if node.SetOreType then
            node:SetOreType(ORE_TYPES[math.random(#ORE_TYPES)])
        end
        return true
    end

    function OS.IsSpawnPointPosition(pos, tolerance)
        if not pos then return false end
        local r2 = (tonumber(tolerance) or 4) ^ 2
        for _, point in ipairs(SpawnPoints) do
            local dx, dy, dz = point.pos.x - pos.x, point.pos.y - pos.y, point.pos.z - pos.z
            if dx * dx + dy * dy + dz * dz <= r2 then return true end
        end
        return false
    end

    function OS.IsManagedNode(ent)
        return IsValid(ent) and ent:GetClass() == "grm_ore_node"
            and (ent.GRMOreSpawned == true or OS.IsSpawnPointPosition(ent:GetPos(), 4))
    end

    function OS.MarkManagedNodes()
        local n = 0
        for _, ent in ipairs(ents.FindByClass("grm_ore_node")) do
            if IsValid(ent) and OS.IsSpawnPointPosition(ent:GetPos(), 4) then ent.GRMOreSpawned = true; n = n + 1 end
        end
        return n
    end

    local function RefillOreNodes()
        if #SpawnPoints == 0 and file.Exists(SPAWN_FILE, "DATA") then
            LoadSpawnPoints()
        end

        OS.MarkManagedNodes()
        local currentNodes = 0
        for _, ent in ipairs(ents.FindByClass("grm_ore_node")) do
            if OS.IsManagedNode(ent) then currentNodes = currentNodes + 1 end
        end

        if currentNodes >= MIN_ORE_COUNT then
            return
        end
        if #SpawnPoints == 0 then
            local hint = file.Exists(SPAWN_FILE, "DATA")
                and " (файл есть, но загрузить не удалось - проверьте структуру JSON)"
                or " (добавьте точки через !addorespawn)"
            print("[GRM Ore Spawner] Нет точек спавна" .. hint .. ", не могу создать руду.")
            return
        end

        -- Используем ВСЕ точки (без фильтрации по валидности)
        local toSpawn = MIN_ORE_COUNT - currentNodes
        local spawned = 0
        local attempts = 0
        local maxAttempts = toSpawn * 4

        while spawned < toSpawn and attempts < maxAttempts and #SpawnPoints > 0 do
            attempts = attempts + 1
            local point = SpawnPoints[math.random(#SpawnPoints)]
            if not IsOccupied(point.pos) then
                if SpawnOreNode(point.pos, point.ang) then
                    spawned = spawned + 1
                end
            end
        end

        if spawned > 0 then
            print("[GRM Ore Spawner] Восстановлено " .. spawned .. " узлов руды.")
        end
    end

    OS.Refill = RefillOreNodes

    -- ============================================================
    -- ЗАГРУЗКА ПРИ СТАРТЕ
    -- ============================================================
    LoadSpawnPoints()

    hook.Add("InitPostEntity", "GRM_OreSpawner_Load", function()
        timer.Simple(3, RefillOreNodes)
    end)

    timer.Create("GRM_OreSpawner_Timer", SPAWN_INTERVAL, 0, RefillOreNodes)

    -- ============================================================
    -- ЧАТ-КОМАНДЫ (админские)
    -- ============================================================
    hook.Add("PlayerSay", "GRM_OreSpawner_Commands", function(ply, text)
        if not IsValid(ply) or not ply:IsAdmin() then return end

        local args = string.Explode(" ", text)
        local cmd = args[1] and args[1]:lower() or ""

        if cmd == "!addorespawn" then
            local tr = ply:GetEyeTrace()
            local pos, ang

            if tr.Hit then
                pos = tr.HitPos + tr.HitNormal * 4
                ang = Angle(0, ply:GetAngles().y + 180, 0)
            else
                pos = ply:GetPos()
                ang = ply:GetAngles()
            end

            -- Проверка валидности УБРАНА
            AddSpawnPoint(pos, ang)
            ply:PrintMessage(HUD_PRINTTALK, "[Ore Spawner] Точка спавна добавлена по прицелу.")
            return ""
        end

        if cmd == "!listorespawns" then
            if #SpawnPoints == 0 then
                ply:PrintMessage(HUD_PRINTTALK, "[Ore Spawner] Нет точек.")
            else
                ply:PrintMessage(HUD_PRINTTALK, "[Ore Spawner] Точки спавна (" .. #SpawnPoints .. "):")
                for i, pt in ipairs(SpawnPoints) do
                    ply:PrintMessage(HUD_PRINTTALK, string.format("  %d. %.1f %.1f %.1f", i, pt.pos.x, pt.pos.y, pt.pos.z))
                end
            end
            return ""
        end

        if cmd == "!removeorespawn" then
            local idx = tonumber(args[2])
            if not idx then
                ply:PrintMessage(HUD_PRINTTALK, "[Ore Spawner] Укажите индекс: !removeorespawn <номер>")
                return ""
            end
            if RemoveSpawnPoint(idx) then
                ply:PrintMessage(HUD_PRINTTALK, "[Ore Spawner] Точка #" .. idx .. " удалена.")
            else
                ply:PrintMessage(HUD_PRINTTALK, "[Ore Spawner] Неверный индекс.")
            end
            return ""
        end

        if cmd == "!refillore" then
            RefillOreNodes()
            ply:PrintMessage(HUD_PRINTTALK, "[Ore Spawner] Принудительное восполнение выполнено.")
            return ""
        end

        if cmd == "!saveorespawns" then
            SaveSpawnPoints()
            ply:PrintMessage(HUD_PRINTTALK, "[Ore Spawner] Точки принудительно сохранены.")
            return ""
        end
    end)

    print("[GRM Ore Spawner] v1.1.0 загружен. Интервал: " .. SPAWN_INTERVAL .. "с, минимум " .. MIN_ORE_COUNT .. " узлов.")
end
