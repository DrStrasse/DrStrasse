--[[--------------------------------------------------------------------
    GRM Perm Entities v1.2.0 (Код 50/Код 89)
    «Пермы» для разворачиваемых энтити GRM: банкомат, таксофон, АТС,
    телефоны, CCTV-камера/монитор/сервер, сигнализация (сенсор/хаб/терминал/
    динамик), кейпад, RoomTap (чип/сервер/терминал), рудный узел/скупщик,
    дилер транспорта. Админ наводит прицел -> команда -> энтити
    переживает рестарт карты и cleanup-кнопку.

    Код 89 (находка 106): «все энтити всех модулей перманентно».
      Добавлены классы: grm_alarm_speaker, grm_keypad, grm_roomtap_chip,
      grm_roomtap_server, grm_roomtap_terminal, grm_ore_node, grm_ore_buyer,
      sent_vehicle_dealer. Лимит 64 -> 256.
      НЕ добавляются (у них и так авто-персистент Код 88.4, двойной
      сейв дал бы дубли): grm_server_rack, grm_antenna, grm_radio_station,
      grm_net_console, grm_loudspeaker. grm_radio/grm_broadcast_mic
      тоже автоперсистентны, оставлены здесь лишь для совместимости
      со старыми базами.
      НЕ добавляются (свой сейв карты со стоком, Код 90):
      grm_logistics_loading, grm_logistics_warehouse, grm_logistics_armory.
      НЕ добавляются (временные по смыслу): grm_item_drop, grm_money_drop,
      grm_ore_chunk (батч-дропы), grm_mobile_line (виртуальная станция),
      grm_logistics_crate (транспортный ящик).

    Хранилище: data/grm_perm_entities.json — МАССИВ записей
    {map, class, model, pos={x,y,z}, ang={p,y,r}}.
    Массив, а не карта: ловушка util.JSONToTable с числовыми
    ключами-строками тут невозможна в принципе (находка 65).
    Чтение всё равно только через jsonT() (ignoreConversions=true).

    Команды (только суперадмин; add/remove — глядя на энтити ≤256 юнитов):
      чат:     /permadd   /permremove   /permlist   /permload
      консоль: grm_perm_add  grm_perm_remove  grm_perm_list  grm_perm_load
      /permload — немедленная загрузка из файла (без рестарта); антидубль:
      на занятое место (тот же класс в радиусе 6 юнитов) второй не ставится.
    Рамки: не больше 256 пермов на карту; дедуп по классу+точке (6 юнитов);
    воскрешённые энтити заморожены (EnableMotion(false)).
----------------------------------------------------------------------]]

-- Код 108: кейпад/сканер несут в rec.data ещё и links — ручные связи
-- с FFD-дверями (sh_grm_ffdlink.lua / инструмент FFD Link); связи
-- разрешаются обратно в энтити по классу+позиции (сфера 15 юнитов).
-- Код 110: перм агрегатов кухни (плита/холодильник/горшок) — состояние
-- (лоток плиты, содержимое холодильника, посадка) едет в rec.data
-- через GRM.PermData-делегаты sh_grm_food_kitchen.lua.
local PERM_VER = "1.5.0"
GRM = GRM or {}
GRM._permEntitiesVer = PERM_VER

-- Код 105 (находка 122): перм с ДАННЫМИ экземпляра. Модули регистрируют
-- GRM.PermData.Extract[class] = fn(ent) -> таблица-данные (или nil) и
-- GRM.PermData.Apply[class] = fn(ent, data). /permadd складывает их в
-- rec.data, спавн после рестарта разворачивает обратно — кейпад
-- восстаёт со своим PIN/режимом/фракциями, FFD-дверь — рабочей дверью.
GRM.PermData = GRM.PermData or { Extract = {}, Apply = {} }
GRM.PermData.Extract = GRM.PermData.Extract or {}
GRM.PermData.Apply = GRM.PermData.Apply or {}

if SERVER then
    local PERM_FILE  = "grm_perm_entities.json"
    local PERM_MAX   = 256 -- Код 89: лимит пермов на карту (было 64)
    local PERM_RANGE = 6   -- юнитов: дедуп при добавлении / поиск при снятии

    -- классы, которым разрешён перм (расширяется здесь)
    local PERM_CLASSES = {
        grm_bank_terminal  = true,
        grm_payphone       = true,
        grm_pbx_station    = true,
        grm_phone_terminal = true,
        grm_phone_wiretap  = true,
        grm_phone          = true,
        -- ВАЖНО: CCTV НЕ здесь! У него своя система сохранения (CCTV.SavePermanent)
        grm_wardrobe       = true,
        -- Broadcast-классы автоперсистентны (Код 88.4) — тут лишь для совместимости со старыми базами
        grm_radio          = true,
        grm_broadcast_mic  = true,
        grm_board          = true,
        -- Биржа труда (Код 77) — модуль и сам автоперсистентен, классы тут для /permadd-совместимости
        grm_jobcenter      = true,
        grm_depot          = true,
        -- Охранная сигнализация (Код 62/Код 89)
        grm_alarm_sensor   = true,
        grm_alarm_hub      = true,
        grm_alarm_terminal = true,
        grm_alarm_speaker  = true, -- Код 89
        -- Кейпад прохода (Код 70/Код 89) и сканер фракций (Код 107)
        grm_keypad         = true,
        grm_scanner        = true,
        -- Кухня «GrandEats» (Код 110): плита, холодильник, горшок
        grm_food_stove     = true,
        grm_food_fridge    = true,
        grm_food_planter   = true,
        -- Код 105: prop_physics допускаем именно ради FFD-дверей
        -- (владелец пермит двери; рабочее состояние восстанавливает
        -- GRM.PermData.Apply["prop_physics"] из стула FFD Fading Door)
        prop_physics       = true,
        -- RoomTap: комнатная прослушка (Код 72/Код 89)
        grm_roomtap_chip     = true,
        grm_roomtap_server   = true,
        grm_roomtap_terminal = true,
        -- GRM Vendor имеет собственный data/grm_vendors/<map>.json.
        -- Здесь намеренно НЕ регистрируется: два механизма создавали дубли.
        -- Денежный принтер (Код 115)
        grm_money_printer    = true,
        -- Банковская система (находка 178): хранилище, печатный станок, терминал
        grm_bank_vault          = true,
        grm_money_press         = true,
        grm_money_press_terminal = true,
        -- Отмывщик денег / ивент «Ограбление» (находка 179e)
        grm_money_launderer     = true,
        -- Лаборатории (Код 120)
        grm_narc_lab         = true,
        grm_med_lab          = true,
        -- GRM Logistics: склады, шкафы, точки погрузки (Код 112)
        grm_logistics_loading   = true,
        grm_logistics_warehouse = true,
        grm_logistics_armory    = true,
        grm_logistics_crate     = true,
        -- ВАЖНО: CCTV (grm_cctv_camera/monitor/server) НЕ в PERM_CLASSES!
        -- У CCTV своя система сохранения через CCTV.SavePermanent/LoadPermanent
        -- (grm_cctv/<map>.json). Добавление сюда создаёт дубликаты.
        -- Рудная ветка (Код 89)
        grm_ore_node       = true,
        grm_ore_buyer      = true,
        -- Терминал контроля чипов (находка 169)
        grm_chip_terminal  = true,
        -- sent_vehicle_dealer имеет собственный GRM VehicleDealer v3 persistence.
        -- Здесь намеренно отсутствует, чтобы не создавать второго NPC.
    }

    -- JSON только без конверсии ключей (находка 65)
    local function jsonT(txt)
        local ok, t = pcall(util.JSONToTable, txt, false, true)
        return (ok and istable(t)) and t or nil
    end

    local function tell(ply, msg, r, g, b)
        if IsValid(ply) and ply:IsPlayer() then
            if GRM.Notify then GRM.Notify(ply, msg, r or 100, g or 220, b or 100) return end
            ply:PrintMessage(HUD_PRINTTALK, tostring(msg))
        else
            print("[GRM Perm] " .. tostring(msg))
        end
    end

    -- ── Хранилище ───────────────────────────────────────────
    local function loadList()
        if not file.Exists(PERM_FILE, "DATA") then return {} end
        local txt = file.Read(PERM_FILE, "DATA") or ""
        if string.Trim(txt) == "" or string.Trim(txt) == "[]" then return {} end
        local t = jsonT(txt)
        if not istable(t) then
            local q = "grm_perm_entities_corrupt_" .. os.time() .. ".txt"
            file.Write(q, txt)
            print("[GRM Perm][!] База пермов битая — копия в data/" .. q .. ", работаем с пустой")
            return {}
        end
        -- в базе только массив записей-таблиц
        local out = {}
        for _, rec in ipairs(t) do
            if istable(rec) and isstring(rec.map) and isstring(rec.class) then
                rec.pos = istable(rec.pos) and rec.pos or { x = 0, y = 0, z = 0 }
                rec.ang = istable(rec.ang) and rec.ang or { p = 0, y = 0, r = 0 }
                out[#out + 1] = rec
            end
        end
        return out
    end

    local function saveList(list)
        local okJ, txt = pcall(util.TableToJSON, list, true)
        if not okJ or not isstring(txt) or txt == "" then
            print("[GRM Perm][!] SAVE: сериализация не удалась — запись пропущена")
            return false
        end
        file.Write(PERM_FILE, txt)
        local chk = file.Read(PERM_FILE, "DATA")
        if chk ~= txt then
            print(("[GRM Perm][!] ЗАПИСЬ НЕ ПОДТВЕРДИЛАСЬ: сохранено %d байт, на диске %s")
                :format(#txt, (isstring(chk) and (tostring(#chk) .. " байт") or "файл пропал")))
            return false
        end
        return true
    end

    local function sameSpot(a, b, classA, classB)
        if classA ~= classB then return false end
        local dx = (tonumber(a.x) or 0) - (tonumber(b.x) or 0)
        local dy = (tonumber(a.y) or 0) - (tonumber(b.y) or 0)
        local dz = (tonumber(a.z) or 0) - (tonumber(b.z) or 0)
        return (dx * dx + dy * dy + dz * dz) <= (PERM_RANGE * PERM_RANGE)
    end

    local function aimEntity(ply)
        if not IsValid(ply) then return nil end
        local tr = util.TraceLine({
            start  = ply:GetShootPos(),
            endpos = ply:GetShootPos() + ply:GetAimVector() * 256,
            filter = ply,
        })
        return tr and tr.Entity or nil
    end

    -- ── Восстановление на карте ─────────────────────────────
    -- Антидубль: не ставим энтити, если того же класса уже стоит на месте
    -- (важно для ручной /permload поверх живой карты)
    local function isOccupied(class, pos)
        local center = Vector(tonumber(pos.x) or 0, tonumber(pos.y) or 0, tonumber(pos.z) or 0)
        for _, ent in ipairs(ents.FindInSphere(center, PERM_RANGE)) do
            if IsValid(ent) and tostring(ent:GetClass() or "") == class then return true end
        end
        return false
    end

    -- Возвращает: сколько заспавнено, сколько пропущено (уже стоят)
    local function spawnAll(reason)
        local map = game.GetMap()
        local done, skipped = 0, 0
        for _, rec in ipairs(loadList()) do
            if rec.map == map and PERM_CLASSES[rec.class] then
                if isOccupied(rec.class, rec.pos) then
                    skipped = skipped + 1
                else
                    local ent = ents.Create(rec.class)
                    if IsValid(ent) then
                        if isstring(rec.model) and rec.model ~= "" then
                            pcall(function() ent:SetModel(rec.model) end)
                        end
                        ent:SetPos(Vector(tonumber(rec.pos.x) or 0, tonumber(rec.pos.y) or 0, tonumber(rec.pos.z) or 0))
                        ent:SetAngles(Angle(tonumber(rec.ang.p) or 0, tonumber(rec.ang.y) or 0, tonumber(rec.ang.r) or 0))
                        ent:Spawn()
                        ent:Activate()
                        if GRM.PropProtect and GRM.PropProtect.MarkServerEntity then GRM.PropProtect.MarkServerEntity(ent) end
                        local ph = ent:GetPhysicsObject()
                        if IsValid(ph) then ph:EnableMotion(false) end -- перм не катается по карте
                        ent._grmPerm = true
                        -- Код 105: данные экземпляра обратно (PIN кейпада,
                        -- конфиг FFD-двери и т.п.) — после Spawn, чтобы
                        -- NetworkVar'ы уже существовали
                        local applyFn = GRM.PermData and GRM.PermData.Apply and GRM.PermData.Apply[rec.class]
                        if istable(rec.data) and applyFn then
                            pcall(applyFn, ent, rec.data)
                        end
                        done = done + 1
                    else
                        print("[GRM Perm][!] Не удалось создать класс " .. tostring(rec.class) .. " — запись пропущена")
                    end
                end
            end
        end
        print(("[GRM Perm] восстановлено перм-энтити на карте %s: %d, уже на месте: %d (%s)")
            :format(tostring(map), done, skipped, tostring(reason or "?")))
        return done, skipped
    end
    hook.Add("InitPostEntity", "GRM_PermEntities_Spawn", function()
        timer.Simple(1, function() spawnAll("InitPostEntity") end)
    end)
    hook.Add("PostCleanupMap", "GRM_PermEntities_Cleanup", function()
        timer.Simple(0.5, function() spawnAll("PostCleanupMap") end)
    end)

    -- ── Действия ────────────────────────────────────────────
    local function countForMap(list, map)
        local n = 0
        for _, rec in ipairs(list) do if rec.map == map then n = n + 1 end end
        return n
    end

    local function addPerm(ply)
        local ent = aimEntity(ply)
        if not IsValid(ent) then tell(ply, "Наведи прицел на энтити (до 256 юнитов).", 255, 200, 80) return end
        local class = tostring(ent:GetClass() or "")
        if not PERM_CLASSES[class] then
            tell(ply, "Класс [" .. class .. "] нельзя пермить (не GRM-разворачиваемое).", 255, 120, 120)
            return
        end
        local list = loadList()
        local map = game.GetMap()
        if countForMap(list, map) >= PERM_MAX then
            tell(ply, "Лимит пермов на карту: " .. PERM_MAX .. ".", 255, 120, 120)
            return
        end
        local pos = ent:GetPos()
        local np = { x = pos.x, y = pos.y, z = pos.z }
        for _, rec in ipairs(list) do
            if rec.map == map and sameSpot(rec.pos, np, rec.class, class) then
                tell(ply, "Этот " .. class .. " уже в пермах.", 255, 200, 80)
                return
            end
        end
        local ang = ent:GetAngles()
        local model = ""
        pcall(function() model = tostring(ent:GetModel() or "") end)
        local rec = {
            map = map, class = class, model = model,
            pos = np,
            ang = { p = ang.p, y = ang.y, r = ang.r },
        }
        -- Код 105: данные экземпляра (PIN кейпада, конфиг двери и т.п.)
        local extractFn = GRM.PermData and GRM.PermData.Extract and GRM.PermData.Extract[class]
        if extractFn then
            local okX, data = pcall(extractFn, ent)
            if okX and istable(data) then rec.data = data end
        end
        list[#list + 1] = rec
        if saveList(list) then
            tell(ply, "[ПЕРМ] " .. class .. " закреплён на карте. Переживёт рестарт и cleanup.", 100, 220, 100)
            print(("[GRM Perm] %s (%s) закрепил %s @ %d %d %d"):format(ply:Nick(), ply:SteamID64() or "?", class, np.x, np.y, np.z))
        else
            tell(ply, "[ПЕРМ] Ошибка записи — смотри консоль сервера.", 255, 120, 120)
        end
    end

    local function removePerm(ply)
        local ent = aimEntity(ply)
        if not IsValid(ent) then tell(ply, "Наведи прицел на перм-энтити.", 255, 200, 80) return end
        local class = tostring(ent:GetClass() or "")
        local list = loadList()
        local map = game.GetMap()
        local pos = ent:GetPos()
        local np = { x = pos.x, y = pos.y, z = pos.z }
        local found = false
        -- Находка 179e: ищем запись по классу + ближайшей позиции (даже если
        -- сущность чуть сдвинули физганом — запись всё равно снимется)
        local bestRec, bestDist = nil, math.huge
        for i, rec in ipairs(list) do
            if rec.map == map and rec.class == class then
                local dx = (tonumber(rec.pos and rec.pos.x) or 0) - np.x
                local dy = (tonumber(rec.pos and rec.pos.y) or 0) - np.y
                local dz = (tonumber(rec.pos and rec.pos.z) or 0) - np.z
                local d2 = dx * dx + dy * dy + dz * dz
                if d2 <= (PERM_RANGE * PERM_RANGE) and d2 < bestDist then
                    bestRec, bestDist = i, d2
                end
            end
        end
        if bestRec then
            table.remove(list, bestRec)
            saveList(list)
            ent:Remove()
            found = true
            tell(ply, "[ПЕРМ] " .. class .. " снят с карты (и из базы).", 235, 180, 60)
            print(("[GRM Perm] %s снял перм %s @ %d %d %d"):format(ply:Nick(), class, np.x, np.y, np.z))
        end
        if not found then
            tell(ply, "В радиусе " .. PERM_RANGE .. " юнитов перм-записи для этого энтити нет.", 255, 200, 80)
        end
    end

    -- Находка 179d: автообновление перм-записи при изменении состояния
    -- сущности (HeldCash хранилища, буфер/скорость станка и т.п.).
    -- /permadd фиксирует состояние ОДИН раз — без этого после загрузки
    -- денег в хранилище запись остаётся со старым (0) значением.
    GRM.PermData.UpdateEntry = function(ent)
        if not IsValid(ent) then return false end
        local class = tostring(ent:GetClass() or "")
        if not PERM_CLASSES[class] then return false end
        local extractFn = GRM.PermData and GRM.PermData.Extract and GRM.PermData.Extract[class]
        if not extractFn then return false end
        local idx = ent:EntIndex()
        -- дебаунс: частые вызовы (подбор паллет) пишут файл не каждый раз
        if ent._grmPermSaveAt and CurTime() < ent._grmPermSaveAt then return false end
        ent._grmPermSaveAt = CurTime() + 1.5
        timer.Simple(1.5, function()
            if not IsValid(ent) then return end
            local list = loadList()
            local map = game.GetMap()
            local pos = ent:GetPos()
            local np = { x = pos.x, y = pos.y, z = pos.z }
            for _, rec in ipairs(list) do
                if rec.map == map and rec.class == class and sameSpot(rec.pos, np, rec.class, class) then
                    local okX, data = pcall(extractFn, ent)
                    if okX and istable(data) then
                        rec.data = data
                        saveList(list)
                    end
                    break
                end
            end
        end)
        return true
    end

    -- Находка 179r: «СОХРАНИТЬ НАСТРОЙКИ» отмывщика (и любых сущностей)
    -- молча теряло настройки, если перм-записи ещё не было: UpdateEntry
    -- no-op, и после рестарта — дефолты. Upsert: запись есть → обновляет
    -- data (как UpdateEntry), нет → создаёт (как /permadd, но без прицела).
    -- Возвращает: "added" / "updated" / "limit" / "invalid" / "noclass" / "savefail".
    GRM.PermData.Upsert = function(ent)
        if not IsValid(ent) then return "invalid" end
        local class = tostring(ent:GetClass() or "")
        if not PERM_CLASSES[class] then return "noclass" end
        local extractFn = GRM.PermData and GRM.PermData.Extract and GRM.PermData.Extract[class]
        local map = game.GetMap()
        local pos = ent:GetPos()
        local np = { x = pos.x, y = pos.y, z = pos.z }
        local list = loadList()
        -- запись уже есть на месте — обновляем данные экземпляра
        for _, rec in ipairs(list) do
            if rec.map == map and rec.class == class and sameSpot(rec.pos, np, rec.class, class) then
                if extractFn then
                    local okX, data = pcall(extractFn, ent)
                    if okX and istable(data) then rec.data = data end
                end
                saveList(list)
                return "updated"
            end
        end
        -- записи нет — создаём (лимит как в /permadd)
        if countForMap(list, map) >= PERM_MAX then return "limit" end
        local ang = ent:GetAngles()
        local model = ""
        pcall(function() model = tostring(ent:GetModel() or "") end)
        local rec = {
            map = map, class = class, model = model,
            pos = np,
            ang = { p = ang.p, y = ang.y, r = ang.r },
        }
        if extractFn then
            local okX, data = pcall(extractFn, ent)
            if okX and istable(data) then rec.data = data end
        end
        list[#list + 1] = rec
        if saveList(list) then
            print(("[GRM Perm] Upsert: создана запись %s @ %d %d %d"):format(class, np.x, np.y, np.z))
            return "added"
        end
        return "savefail"
    end

    local function loadPerm(ply)
        local spawned, skipped = spawnAll("ручная загрузка")
        if spawned == 0 and skipped == 0 then
            tell(ply, "[ПЕРМ] Для этой карты в базе записей нет.", 255, 200, 80)
        else
            tell(ply, ("[ПЕРМ] Загрузка из базы: восстановлено %d, уже на месте %d."):format(spawned, skipped), 100, 220, 255)
        end
    end

    local function listPerm(ply)
        local list = loadList()
        local map = game.GetMap()
        local n = 0
        for _, rec in ipairs(list) do
            if rec.map == map then
                n = n + 1
                print(( "[GRM Perm]  #%d %s @ %d %d %d" ):format(n, rec.class,
                    tonumber(rec.pos.x) or 0, tonumber(rec.pos.y) or 0, tonumber(rec.pos.z) or 0))
            end
        end
        tell(ply, ("Пермов на карте %s: %d (в базе всего: %d). Список — в консоли сервера."):format(map, n, #list), 100, 220, 255)
    end

    -- ── Команды ─────────────────────────────────────────────
    local function guarded(fn)
        return function(ply)
            if not IsValid(ply) then print("[GRM Perm] Команда только из игры (сервер-консоль: нет прицела).") return end
            if not ply:IsSuperAdmin() then tell(ply, "Только суперадмин.", 255, 100, 100) return end
            fn(ply)
        end
    end
    concommand.Add("grm_perm_add", guarded(addPerm))
    concommand.Add("grm_perm_remove", guarded(removePerm))
    concommand.Add("grm_perm_list", guarded(listPerm))
    concommand.Add("grm_perm_load", guarded(loadPerm))

    -- Находка 179e: EasyChat ставит SkipPlayerSay для команд → PlayerSay не
    -- вызывается. Дублируем обработку через PlayerSayTransform (как /factions).
    hook.Add("PlayerSayTransform", "GRM_PermEntities_ChatTransform", function(ply, datapack)
        if not istable(datapack) then return end
        local text = datapack[1]
        if not isstring(text) then return end
        local t = string.lower(string.Trim(text))
        if t ~= "/permadd" and t ~= "/permremove" and t ~= "/permlist" and t ~= "/permload" then return end
        if not IsValid(ply) or not ply:IsSuperAdmin() then
            tell(ply, "Только суперадмин.", 255, 100, 100)
            datapack.SkipPlayerSay = true
            datapack[1] = ""
            return
        end
        if t == "/permadd" then addPerm(ply)
        elseif t == "/permremove" then removePerm(ply)
        elseif t == "/permload" then loadPerm(ply)
        else listPerm(ply) end
        datapack.SkipPlayerSay = true
        datapack[1] = ""
    end)

    hook.Add("PlayerSay", "GRM_PermEntities_Chat", function(ply, text)
        local t = string.lower(string.Trim(tostring(text or "")))
        if t ~= "/permadd" and t ~= "/permremove" and t ~= "/permlist" and t ~= "/permload" then return end
        if not IsValid(ply) or not ply:IsSuperAdmin() then
            tell(ply, "Только суперадмин.", 255, 100, 100)
            return ""
        end
        if t == "/permadd" then addPerm(ply)
        elseif t == "/permremove" then removePerm(ply)
        elseif t == "/permload" then loadPerm(ply)
        else listPerm(ply) end
        return ""
    end)

    -- Делегаты для логистических entity (Код 112)
    -- GRM.PermData.Extract[class] = fn(ent) -> таблица
    -- GRM.PermData.Apply[class]   = fn(ent, data)
    for _, class in ipairs({"grm_logistics_loading", "grm_logistics_warehouse", "grm_logistics_armory"}) do
        GRM.PermData.Extract[class] = function(ent)
            if not IsValid(ent) or not ent.GetPermData then return nil end
            return ent:GetPermData()
        end
        GRM.PermData.Apply[class] = function(ent, data)
            if not IsValid(ent) or not ent.ApplyPermData then return end
            ent:ApplyPermData(data)
        end
    end

    print(("[GRM Perm] Perm Entities v%s загружен (путь: %s, база: data/%s)")
        :format(PERM_VER, tostring(debug.getinfo(1, "S").short_src), PERM_FILE))
end
