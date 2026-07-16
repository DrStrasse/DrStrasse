--[[--------------------------------------------------------------------
    GRM Currency Core v1.5.8 (Код 42)

    v1.5.8 (по предложению владельца): БАЗА ПЕРЕЕХАЛА на новое имя
    data/grm_wallet.json — чужой «фантомный писатель» знал только старое
    имя и затирал его пустым «[]»; старый grm_currency.json оставлен
    ДЕКОЕМ и больше НЕ читается вообще. Миграция ТОЛЬКО из зеркала
    grm_currency_backup.json (туда реально писались живые сейвы):
    поднимается разово при первом старте, если в нём есть счета.

    v1.5.7 (репорт: «SAVE ok есть, а в файле [] — кто-то перезаписывает»):
    СТОРОЖ ФАЙЛА (2с): любая чужая запись grm_currency.json фиксируется
    в форензик-логе и данные мгновенно восстанавливаются из памяти;
    ЗАХВАТ СЛОТОВ: таймеры/хуки/API с нашими именами принудительно
    наши — старая копия без синглтон-стража глушится до 10с даже при
    загрузке после нас; форензик-лог всех событий в
    data/grm_currency_forensics.txt (кто/когда/почему сохранял).

    v1.5.6 (репорт: «пишет SAVE ok, но после рестарта пропадает; в json — []»):
    антисвайп-страж: ПУСТАЯ память никогда не перезаписывает НЕПУСТОЙ файл
    базы (раньше пустой дамп «[]» легально затирал реальные счета — отсюда
    вечная потеря данных после рестарта). Полный wipe — только удалением
    файла на выключенном сервере.

    v1.5.5 (аудит синхронизации HUD/Tab): GRM.Notify шлёт ОБА канала
    (GRM_Currency_Notify + легаси grm_notify), поэтому при установленном
    HUD (Код 48) каждое уведомление показывалось дважды — всплывашкой
    HUD и строкой в чате/legacy. Клиентский вывод GRM_Currency_Notify
    теперь молчит, если стек HUD присутствует (GRM.HUD).

    v1.5.4 (репорт: «attempt to call global 'cleanNick' (a nil value)»,
    таймер GRM_Currency_Flush умирал): cleanNick была объявлена НИЖЕ
    места использования — каждый вызов уходил в nil-глобал, поэтому
    падали ВСЕ сохранения (флаш 5с и автосейв 8с) и ничего не писалось
    на диск. Хелпер поднят выше sanitizedDump/loadData.

    v1.5.3 (репорт: «SAVE ОШИБКА сериализации» нонстоп): порог длины
    JSON считал пустую таблицу "{}" ошибкой + возможна «ядовитая»
    запись с управляющими символами в нике. Теперь: валидность =
    живой парсинг (round-trip), ники чистятся на входе и перед
    записью; при сбое — аварийный пословный формат, в дампе
    ВИДНО виновника (sid + очищенное имя).

    v1.5.2: сохранение ≤8с гарантировано + сверка ≤15с.
      Авто-запись каждые 8с, но файл ПИШЕТСЯ только при реальных
      изменениях (сравнение с последним записанным содержимым) —
      пустого долбёжки диска нет, внешние правки сверка видит.

    v1.5.1 (репорт: «не подтягивает из базы»): найден дедлок —
    защита от перезаписи при ошибке сериализации не сбрасывала dirty,
    а сверка пропускалась при dirty → замок навсегда.
    Теперь: ошибка сериализации не блокирует систему; сверка НЕ
    зависит от dirty (позаписная проверка «запись не тронута локально»);
    страж-синглтон от второй копии аддона; чат-команда /dbcheck.

    v1.5 (заказ владельца): сверка «память ↔ база» (disk reconcile).
      - Ядро хранит зеркало последнего состояния диска (diskMirror);
      - каждые 60с И при входе игрока файл перечитывается: если запись
        в базе ОТЛИЧАЕТСЯ от зеркала (базу правили снаружи/другой процесс) —
        баланс в игре ПОДНИМАЕТСЯ ИЗ БАЗЫ с пушем в HUD и записью в лог;
      - свои свежие изменения сверка не затирает (файл == зеркалу → пропуск);
      - ручной прогон: grm_money check в серверной консоли.

    v1.4.1: диагностика персистентности + защита от перезаписи:
      - SAVE/LOAD печатают факты (счетов, байт, путь) — видно, где обрыв;
      - если сериализация вернула nil/мусор — основной файл НЕ трогаем,
        пишем grm_currency_err_<t>.txt с дампом памяти;
      - зеркальная копия каждой записи: data/grm_currency_backup.json;
      - normalize отсекает NaN (мог убить сериализацию всего файла).

    v1.4 (заказ владельца — «валюта сбрасывается после рестарта»):
      - мгновенный сброс на диск: тикер 5с сбрасывает любые изменения,
        больше не зависим от ShutDown и автосейва раз в 180с;
      - чтение JSON через pcall: битый файл НЕ затирает счета, а
        откладывается в grm_currency_corrupt_<time>.txt.

    v1.3 (аудит синхронизации с HUD/Tab):
      - API, вызванное по SteamID64-строке (админ-панель, гос.выплаты),
        теперь находит онлайн-игрока и мгновенно пушит баланс в HUD/Tab
        (раньше pushBalance срабатывал только при объекте Player);
      - выставлен маркер GRM._currencyReqBalRcv, чтобы Tab Menu (Код 47)
        не перекрывал серверный обработчик grm_request_bal (терялся NET_SYNC).

    Ядро валюты GRM — восстановлено с нуля (старый файл утерян).
    Реализует контракт, который ожидают уже существующие модули:

      Сервер:  GRM.GiveMoney(ply, amount)      — начислить
               GRM.TakeMoney(ply, amount)      — списать (баланс не ниже 0)
               GRM.HasMoney(ply, amount)       — достаточно ли средств
               GRM.GetBalance(ply)             — текущий баланс (число)
               GRM.SetBalance(ply, amount)     — установить (админ)
               GRM.Notify(ply, msg, r, g, b)   — цветное уведомление игроку
      Шаред:   GRM.Format(amount)              — "1 500 GRM"
      Клиент:  GRM.LocalBalance                — живой баланс локального игрока
      Конфиг:  GRM.StartBalance                — стартовый баланс новичка
      Мета:    GRM.CurrencyName                — суффикс валюты в Format

    Все аргументы ply могут быть Player ИЛИ строкой SteamID64 — так ядро
    работает и с офлайн-игроками (админ-действия, налоги и т.п.).

    Персистентность: data/grm_currency.json (SteamID64 → баланс/ник).
    Автосохранение каждые 180с + сохранение при дисконнекте/выключении.

    Хук для сторонних систем:
      hook.Add("GRM_MoneyChanged", ..., function(ply, newBalance, delta) end)
      — вызывается на СЕРВЕРЕ при любом изменении баланса; на клиенте
      вызывается как hook "GRM_LocalMoneyChanged"(newBalance) при синке.

    Совместимые алиасы (на будущее): GRM.AddMoney = GRM.GiveMoney,
    GRM.CanAfford = GRM.HasMoney.
----------------------------------------------------------------------]]

GRM = GRM or {}

-- ============================================================
-- КОНФИГ
-- ============================================================
GRM.StartBalance  = GRM.StartBalance  or 1000   -- стартовый баланс нового игрока
GRM.CurrencyName  = GRM.CurrencyName  or "GRM"  -- суффикс валюты
GRM.MaxBalance    = GRM.MaxBalance    or 2000000000 -- защита от переполнения NW2/net

local DATA_FILE   = "grm_wallet.json" -- v1.5.8: НОВОЕ имя базы; grm_currency.json — декой для фантома, не читаем
local NET_SYNC    = "GRM_Currency_Sync"
local NET_NOTIFY  = "GRM_Currency_Notify"
local AUTOSAVE    = 8   -- секунды: гарантированный интервал автосохранения
local RECONCILE   = 15  -- секунды: интервал сверки «память ↔ база»

-- Форензик-лог всех событий сохранений/сторожа: data/grm_currency_forensics.txt
local FRX_FILE = "grm_currency_forensics.txt"
local function logForensic(line)
    local prev = file.Read(FRX_FILE, "DATA") or ""
    local txt = prev .. "[" .. os.date("%d.%m %H:%M:%S") .. "] " .. tostring(line) .. "\r\n"
    if #txt > 60000 then txt = string.sub(txt, #txt - 50000) end -- держим хвост
    file.Write(FRX_FILE, txt)
end

-- ============================================================
-- ШАРЕД: форматирование
-- ============================================================
function GRM.Format(amount)
    local n = math.floor(tonumber(amount) or 0)
    local neg = n < 0
    n = math.abs(n)
    local s = tostring(n)
    -- разбиение на тысячи: 1234567 -> "1 234 567"
    local out, cnt = "", 0
    for i = #s, 1, -1 do
        out = s:sub(i, i) .. out
        cnt = cnt + 1
        if cnt % 3 == 0 and i > 1 then out = " " .. out end
    end
    return (neg and "-" or "") .. out .. " " .. (GRM.CurrencyName or "GRM")
end

-- ============================================================
-- СЕРВЕР
-- ============================================================
if SERVER then
    -- GRM-FIX: страж-синглтон. Если ядро уже загружено (вторая копия
    -- файла в другом аддоне) — НЕ поднимаем второй экземпляр: две копии
    -- грызли бы один data-файл и затирали друг друга.
    if GRM._currencyCoreActive then
        local src = (debug and debug.getinfo and debug.getinfo(1, "S") and debug.getinfo(1, "S").short_src) or "?"
        print("[GRM Currency][!] ВТОРАЯ копия sh_grm_currency.lua ПРОПУЩЕНА, путь: " .. tostring(src))
        print("[GRM Currency][!] Активно ядро v" .. tostring(GRM._currencyCoreVer) ..
              ", путь: " .. tostring(GRM._currencyCoreSrc) ..
              ". Оставьте ОДНУ (самую новую) копию, остальные удалите!")
        return
    end
    GRM._currencyCoreActive = true
    GRM._currencyCoreVer = "1.5.8"
    GRM._currencyCoreSrc = (debug and debug.getinfo and debug.getinfo(1, "S") and debug.getinfo(1, "S").short_src) or "?"

    util.AddNetworkString(NET_SYNC)
    util.AddNetworkString(NET_NOTIFY)
    -- Совместимость с внешними модулями (Tab Menu Код 47, HUD Код 48):
    util.AddNetworkString("grm_balance")
    util.AddNetworkString("grm_request_bal")
    util.AddNetworkString("grm_notify")

    -- records[sid64] = { balance = number, name = string }
    local records = {}
    local dirty = false
    -- Зеркало последнего состояния файла на диске (sid64 → balance):
    -- чем файл отличается от зеркала — то изменилось СНАРУЖИ (не нами).
    local diskMirror = {}
    local function mirrorFill()
        diskMirror = {}
        for sid, rec in pairs(records) do diskMirror[sid] = rec.balance end
    end

    local function normalize(amount)
        amount = math.floor(tonumber(amount) or 0)
        if amount ~= amount then amount = 0 end -- NaN убивал бы сериализацию файла
        if amount > GRM.MaxBalance then amount = GRM.MaxBalance end
        if amount < 0 then amount = 0 end
        return amount
    end

    local function sidOf(ply)
        if isstring(ply) then return ply end
        if IsValid(ply) then return ply:SteamID64() end
        return nil
    end

    -- Если API вызвали по SteamID64-строке (админ-панель, гос.выплаты),
    -- ищем онлайн-игрока, чтобы мгновенно запушить баланс в HUD/Tab.
    local function onlinePlayerOf(sid)
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:SteamID64() == sid then return p end
        end
        return nil
    end

    local lastSavedTxt = nil -- что реально лежит в файле (защита от пустых записей)

    -- Управляющие байты (кроме перевода строки) и DEL ломали бы JSON.
    -- ВАЖНО: объявлена ПЕРЕД sanitizedDump/loadData — они вызывают её как upvalue;
    -- определение ниже по файлу превращало вызов в nil-глобал и убивало КАЖДОЕ сохранение.
    local function cleanNick(s)
        s = tostring(s or "?")
        s = string.gsub(s, "[\1-\9\11-\31\127]", "")
        if s == "" then s = "?" end
        if #s > 64 then s = s:sub(1, 64) end
        return s
    end

    -- Очистка структуры перед сериализацией: ники без управляющих байт,
    -- счётчики нормализуются. Если какая-то запись "ядовитая" — в лог
    -- улетает её sid и очищенное имя (становится видно виновника).
    local function sanitizedDump()
        local clean, poison = {}, {}
        for sid, rec in pairs(records) do
            local nm = cleanNick(rec and rec.name)
            if istable(rec) and rec.name ~= nil and tostring(rec.name) ~= nm then
                poison[#poison + 1] = tostring(sid) .. " («" .. nm .. "»)"
            end
            clean[tostring(sid)] = { balance = normalize(rec and rec.balance), name = nm }
        end
        return clean, poison
    end

    local function saveNow(force, why)
        if not dirty and not force then return end
        local clean, poison = sanitizedDump()
        -- GRM-FIX v1.5.6: ПУСТАЯ память НИКОГДА не перезаписывает НЕПУСТУЮ базу.
        -- "[]" (пустая таблица) — легальный JSON, поэтому без этого стража пустой
        -- дамп молча затирал реальные счета (после битой загрузки, чужой записи
        -- в файл по FTP и т.п.). Полный сброс — только ручным удалением файла
        -- при выключенном сервере.
        if next(clean) == nil then
            local prev = lastSavedTxt
            if (not isstring(prev)) and file.Exists(DATA_FILE, "DATA") then
                prev = file.Read(DATA_FILE, "DATA")
            end
            local hadRecords = false
            if isstring(prev) and #prev > 0 then
                local okP, prevTab = pcall(util.JSONToTable, prev)
                hadRecords = okP and istable(prevTab) and next(prevTab) ~= nil
            end
            if hadRecords then
                local msg = ("SAVE ОТКЛОНЁН (вызов: %s): память пуста, а в базе есть счета — базу НЕ затираем (антисвайп-страж)"):format(tostring(why or "?"))
                print("[GRM Currency] " .. msg)
                logForensic(msg .. " | стек: " .. string.sub(tostring(debug.traceback("", 2)), 1, 300))
                dirty = false
                return
            end
        end
        if #poison > 0 then
            print("[GRM Currency] SAVE: очищены подозрительные ники: " .. table.concat(poison, ", "))
        end
        local txt = util.TableToJSON(clean, true)
        -- GRM-FIX: валидность = живой парсинг (round-trip), а не длина.
        -- Пустая таблица "{}" — легальное состояние, а не ошибка.
        local okRound = isstring(txt) and (pcall(util.JSONToTable, txt) == true)
        if not okRound then
            -- АВАРИЙНЫЙ путь: пишем пословный формат "sid|balance|name",
            -- чтобы данные пережили даже полностью сломанный сериализатор.
            local lines = {}
            for sid, rec in pairs(clean) do
                lines[#lines + 1] = sid .. "|" .. tostring(rec.balance) .. "|" .. rec.name
            end
            local rescue = table.concat(lines, "\n")
            file.Write(DATA_FILE, rescue)
            file.Write("grm_wallet_err_" .. os.time() .. ".txt",
                "TableToJSON/sanity: " .. tostring(txt) .. "\r\nПодозреваемые: " .. table.concat(poison, ", ") ..
                "\r\nДамп памяти записан в основной файл строками sid|balance|name")
            lastSavedTxt = rescue
            mirrorFill()
            dirty = false
            print("[GRM Currency] SAVE: JSON не собрался — записан АВАРИЙНЫЙ формат (" .. tostring(#lines) .. " счетов), данные спасены")
            return
        end
        -- GRM-FIX: содержимое не изменилось → файл НЕ трогаем вообще:
        -- нулевой износ диска и сверка с базой видит внешние правки.
        if txt == lastSavedTxt then dirty = false return end
        file.Write(DATA_FILE, txt)
        file.Write("grm_wallet_backup.json", txt) -- зеркало на случай повреждения
        lastSavedTxt = txt
        mirrorFill() -- записали мы: зеркало = нашему состоянию
        dirty = false
        print(("[GRM Currency] SAVE ok: счетов %d, %d байт -> data/%s%s")
            :format(table.Count(records), #txt, DATA_FILE, why and (" [" .. tostring(why) .. "]") or ""))
    end

    -- v1.5.8: разовая миграция. По указанию владельца старый основной
    -- grm_currency.json НЕ читается (скомпрометирован фантомом) — только
    -- зеркало grm_currency_backup.json, куда реально писались сейвы.
    local MIGRATE_FROM = { "grm_currency_backup.json" }

    local function loadData()
        records = {}
        local rawTxt, srcName = nil, DATA_FILE
        if file.Exists(DATA_FILE, "DATA") then
            rawTxt = file.Read(DATA_FILE, "DATA") or ""
        else
            for _, legacy in ipairs(MIGRATE_FROM) do
                if file.Exists(legacy, "DATA") then
                    local t = file.Read(legacy, "DATA") or ""
                    local okL, tab = pcall(util.JSONToTable, t)
                    if okL and istable(tab) and next(tab) ~= nil then
                        rawTxt, srcName = t, legacy
                        break
                    end
                end
            end
        end
        if rawTxt == nil then
            print("[GRM Currency] LOAD: файла data/" .. DATA_FILE .. " нет и мигрировать нечего — стартуем с пустых счетов")
            logForensic("LOAD: новый файл отсутствует, миграционный источник пуст — старт с нуля")
            return
        end
        print(("[GRM Currency] LOAD: читаю data/%s (%d байт)"):format(srcName, #rawTxt))
        -- GRM-FIX: битый JSON (обрыв записи при падении) больше не
        -- обнуляет счета молча — файл откладывается для ручного спасения.
        local okJs, raw = pcall(util.JSONToTable, rawTxt)
        if not okJs or not istable(raw) then
            local backup = "grm_wallet_corrupt_" .. os.time() .. ".txt"
            file.Write(backup, rawTxt)
            print("[GRM Currency] ОШИБКА парсинга " .. DATA_FILE ..
                  " — копия сохранена как data/" .. backup)
            raw = {}
            -- GRM-FIX: пробуем АВАРИЙНЫЙ формат (sid|balance|name построчно)
            local rescued = 0
            for line in rawTxt:gmatch("[^\n]+") do
                local lsid, lbal, lname = line:match("^(%S+)%|(-?%d+)%|(.*)$")
                if lsid and lbal then
                    raw[lsid] = { balance = tonumber(lbal), name = cleanNick(lname or "?") }
                    rescued = rescued + 1
                end
            end
            if rescued > 0 then
                print(("[GRM Currency] LOAD: из аварийного формата поднято счетов: %d"):format(rescued))
            end
        end
        for sid, rec in pairs(raw) do
            if isstring(sid) and type(rec) == "table" then
                records[sid] = {
                    balance = normalize(rec.balance),
                    name = tostring(rec.name or "?"),
                }
            end
        end
        if srcName ~= DATA_FILE then
            dirty = true -- первая же запись уйдёт в НОВЫЙ файл
            print(("[GRM Currency] МИГРАЦИЯ: поднято счетов %d из data/%s -> будет записано в data/%s"):format(
                table.Count(records), srcName, DATA_FILE))
            logForensic(("МИГРАЦИЯ из %s: счетов %d"):format(srcName, table.Count(records)))
        end
    end

    local function ensure(sid, nick)
        nick = nick and cleanNick(nick) or nil
        if not records[sid] then
            records[sid] = { balance = normalize(GRM.StartBalance), name = nick or "?" }
            dirty = true
        end
        if nick and nick ~= "" and records[sid].name ~= nick then
            records[sid].name = nick
            dirty = true
        end
        return records[sid]
    end

    -- Отправка актуального баланса конкретному онлайн-игроку.
    local function pushBalance(ply)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        local rec = records[ply:SteamID64()]
        local bal = rec and rec.balance or 0
        ply:SetNW2Int("GRM_Money", bal) -- для внешних HUD
        net.Start(NET_SYNC)
            net.WriteUInt(bal, 32)
        net.Send(ply)
        -- Легаси-пуш для Tab Menu / HUD (мгновенное обновление баланса там)
        net.Start("grm_balance")
            net.WriteInt(bal, 32)
        net.Send(ply)
    end

    -- Запрос баланса от внешних клиентов (HUD при входе, Tab при обновлении)
    net.Receive("grm_request_bal", function(_, ply)
        if IsValid(ply) then pushBalance(ply) end
    end)

    -- Маркер для Tab Menu (Код 47): НЕ переустанавливать свой легаси-
    -- обработчик grm_request_bal поверх этого (иначе теряется NET_SYNC-пуш).
    GRM._currencyReqBalRcv = true

    local function changed(ply, newBalance, delta, reason)
        hook.Run("GRM_MoneyChanged", ply, newBalance, delta, reason or "")
    end

    -- ========================================================
    -- ПУБЛИЧНОЕ API (контракт остальных модулей)
    -- ========================================================
    function GRM.GetBalance(ply)
        local sid = sidOf(ply)
        if not sid then return 0 end
        if IsValid(ply) and ply:IsPlayer() then ensure(sid, ply:Nick()) end
        local rec = records[sid]
        return rec and rec.balance or 0
    end

    function GRM.HasMoney(ply, amount)
        amount = math.floor(tonumber(amount) or 0)
        if amount <= 0 then return true end
        return GRM.GetBalance(ply) >= amount
    end

    function GRM.SetBalance(ply, amount, reason)
        local sid = sidOf(ply)
        if not sid then return false end
        local nick = IsValid(ply) and ply:IsPlayer() and ply:Nick() or nil
        local rec = ensure(sid, nick)
        local old = rec.balance
        rec.balance = normalize(amount)
        dirty = true
        saveNow(false, "SetBalance")
        local onlinePly = (IsValid(ply) and ply:IsPlayer()) and ply or onlinePlayerOf(sid)
        if onlinePly then rec.name = onlinePly:Nick() pushBalance(onlinePly) end
        changed(IsValid(ply) and ply or sid, rec.balance, rec.balance - old, reason)
        return true
    end

    function GRM.GiveMoney(ply, amount, reason)
        amount = math.floor(tonumber(amount) or 0)
        if amount <= 0 then return false end
        local sid = sidOf(ply)
        if not sid then return false end
        local nick = IsValid(ply) and ply:IsPlayer() and ply:Nick() or nil
        local rec = ensure(sid, nick)
        rec.balance = normalize(rec.balance + amount)
        dirty = true
        local onlinePly = (IsValid(ply) and ply:IsPlayer()) and ply or onlinePlayerOf(sid)
        if onlinePly then rec.name = onlinePly:Nick() pushBalance(onlinePly) end
        changed(IsValid(ply) and ply or sid, rec.balance, amount, reason)
        return true
    end

    function GRM.TakeMoney(ply, amount, reason)
        amount = math.floor(tonumber(amount) or 0)
        if amount <= 0 then return false end
        local sid = sidOf(ply)
        if not sid then return false end
        local nick = IsValid(ply) and ply:IsPlayer() and ply:Nick() or nil
        local rec = ensure(sid, nick)
        local taken = math.min(amount, rec.balance) -- уход в минус запрещён
        rec.balance = rec.balance - taken
        dirty = true
        local onlinePly = (IsValid(ply) and ply:IsPlayer()) and ply or onlinePlayerOf(sid)
        if onlinePly then rec.name = onlinePly:Nick() pushBalance(onlinePly) end
        changed(IsValid(ply) and ply or sid, rec.balance, -taken, reason)
        return taken >= amount
    end

    -- Алиасы для будущих модулей.
    GRM.AddMoney  = GRM.GiveMoney
    GRM.CanAfford = GRM.HasMoney

    -- Копия всех счетов (sid64 → {balance, name}) — для единой
    -- админ-панели экономики (Код 43) и других админ-инструментов.
    function GRM.GetAllBalances()
        local out = {}
        for sid, rec in pairs(records) do
            out[sid] = { balance = rec.balance, name = rec.name }
        end
        return out
    end

    -- Цветное уведомление: тост + продублировано в чат.
    function GRM.Notify(ply, msg, r, g, b)
        if not IsValid(ply) or not ply:IsPlayer() then return end
        local rr = math.Clamp(math.floor(tonumber(r) or 255), 0, 255)
        local gg = math.Clamp(math.floor(tonumber(g) or 255), 0, 255)
        local bb = math.Clamp(math.floor(tonumber(b) or 255), 0, 255)
        net.Start(NET_NOTIFY)
            net.WriteString(tostring(msg or ""))
            net.WriteUInt(rr, 8)
            net.WriteUInt(gg, 8)
            net.WriteUInt(bb, 8)
        net.Send(ply)
        -- Легаси-дубль для стека уведомлений HUD (Код 48)
        net.Start("grm_notify")
            net.WriteString(tostring(msg or ""))
            net.WriteUInt(rr, 8)
            net.WriteUInt(gg, 8)
            net.WriteUInt(bb, 8)
        net.Send(ply)
    end

    -- ========================================================
    -- СВЕРКА «ПАМЯТЬ ↔ БАЗА»: база главнее, если её правили снаружи
    -- ========================================================
    -- Поднимает баланс игрока из файла, если в файле значение отличается
    -- от последнего известного нам состояния диска. Свои свежие, ещё не
    -- сброшенные изменения НЕ трогает (файл тогда == зеркалу).
    local function reconcile(reason)
        if not file.Exists(DATA_FILE, "DATA") then return 0 end
        local rawTxt = file.Read(DATA_FILE, "DATA") or ""
        local okJs, raw = pcall(util.JSONToTable, rawTxt)
        if not okJs or not istable(raw) then return 0 end
        local adopted = 0
        for sid, rec in pairs(raw) do
            if isstring(sid) and type(rec) == "table" then
                local diskBal = normalize(rec.balance)
                local mirrorBal = diskMirror[sid]
                local memRec = records[sid]
                if mirrorBal == nil and memRec == nil then
                    -- запись есть в базе, но её нет в памяти и не было: поднимаем
                    local mem = ensure(sid, tostring(rec.name or "?"))
                    mem.balance = diskBal
                    diskMirror[sid] = diskBal
                    adopted = adopted + 1
                    print(("[GRM Currency] DB↔MEM [%s] новая запись из базы: %s"):format(reason, sid))
                elseif mirrorBal ~= nil and diskBal ~= mirrorBal then
                    -- файл менялся снаружи...
                    -- GRM-FIX: поднимаем ТОЛЬКО если эту запись не трогали
                    -- локально с последней записи/чтения диска (memory == mirror) —
                    -- свои свежие и не сброшенные деньги не затираем никогда.
                    if memRec and memRec.balance ~= mirrorBal then
                        diskMirror[sid] = diskBal
                    else
                        local mem = memRec or ensure(sid, tostring(rec.name or "?"))
                        local old = mem.balance
                        if old ~= diskBal then
                            mem.balance = diskBal
                            mem.name = tostring(rec.name or mem.name)
                            dirty = true -- сбросим файл в консистентное состояние
                            adopted = adopted + 1
                            local online = onlinePlayerOf(sid)
                            if online then pushBalance(online) end
                            hook.Run("GRM_MoneyChanged", online or sid, diskBal, diskBal - old,
                                "Сверка с базой (" .. tostring(reason) .. ")")
                            print(("[GRM Currency] DB↔MEM [%s] %s: %d → %d (поднято из базы)")
                                :format(reason, sid, old, diskBal))
                        else
                            diskMirror[sid] = diskBal
                        end
                    end
                end
            end
        end
        return adopted
    end

    concommand.Add("grm_money_check", function(ply)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end
        local n = reconcile("команда")
        print(("[GRM Currency] сверка завершена: принято изменений из базы: %d"):format(n))
    end)

    -- Чат-команда для superadmin (работает из игры, на ответ есть нотифай)
    hook.Add("PlayerSay", "GRM_Currency_DBCheck", function(ply, text)
        local cmd = string.lower(string.Trim(text or ""))
        if cmd ~= "/dbcheck" and cmd ~= "!dbcheck" then return end
        if not ply:IsSuperAdmin() then
            if GRM.Notify then GRM.Notify(ply, "Только для superadmin.", 255, 100, 100) end
            return ""
        end
        local n1 = reconcile("чат /dbcheck")
        local n2 = (hook.Run("GRM_Economy_DBCheck") == true) and 1 or 0
        if GRM.Notify then
            GRM.Notify(ply, ("Сверка с базой: наличка +%d, экономика %s"):format(
                n1, n2 > 0 and "обновлена" or "без изменений"), 100, 220, 255)
        end
        return ""
    end)

    -- ========================================================
    -- ЖИЗНЕННЫЙ ЦИКЛ
    -- ========================================================
    loadData()
    mirrorFill()
    lastSavedTxt = file.Exists(DATA_FILE, "DATA") and (file.Read(DATA_FILE, "DATA") or "") or nil

    -- ========================================================
    -- СЛОТЫ ЖИЗНЕННОГО ЦИКЛА + СТОРОЖ ФАЙЛА + ЗАХВАТ РЕГИСТРАЦИЙ (v1.5.7)
    -- Всё сгруппировано в installHostSlots(): чужие копии модуля без
    -- синглтон-стража, регистрирующие таймеры/хуки/API с ТЕМИ ЖЕ именами,
    -- детерминированно глушатся нами (≤10с) даже если загрузились позже.
    -- ========================================================
    local apiSnapshot = {}
    for _, n in ipairs({ "GiveMoney", "TakeMoney", "SetBalance", "GetBalance", "HasMoney",
                         "AddMoney", "CanAfford", "Format", "Notify", "GetAllBalances" }) do
        apiSnapshot[n] = GRM[n]
    end

    local function onInitSpawn(ply)
        if not IsValid(ply) or ply:IsBot() then return end
        local sid = ply:SteamID64()
        local rec = records[sid]
        if not rec then
            ensure(sid, ply:Nick())
            dirty = true
            saveNow(false, "вход игрока")
        else
            rec.name = ply:Nick()
        end
        -- Клиент может быть ещё не готов принимать net — шлём с задержкой.
        local tag = "GRM_Currency_FirstSync_" .. sid
        timer.Create(tag, 2, 1, function()
            if IsValid(ply) then
                reconcile("вход игрока") -- поднять правки базы, сделанные пока игрок был офлайн
                pushBalance(ply)
            end
        end)
    end

    local function onDisconnect(ply)
        if not IsValid(ply) then return end
        local rec = records[ply:SteamID64()]
        if rec then rec.name = ply:Nick() end
        dirty = true
        saveNow(false, "дисконнект")
    end

    local function onShutdown()
        dirty = true
        saveNow(false, "shutdown")
    end

    local function tickAutoSave() saveNow(true, "автосейв 8с") end
    local function tickFlush() if dirty then saveNow(false, "флаш 5с") end end
    local function tickReconcile()
        local n = reconcile("тик 15с")
        if n > 0 then
            print(("[GRM Currency] сверка: принято %d изменений из базы"):format(n))
            logForensic(("сверка: принято %d изменений"):format(n))
        end
    end

    local reclaimed = {}
    local function installHostSlots(report)
        -- Таймеры по имени: Create заменяет одноимённые — наш слот всегда наш.
        timer.Create("GRM_Currency_AutoSave", AUTOSAVE, 0, tickAutoSave)
        timer.Create("GRM_Currency_Flush", 5, 0, tickFlush)
        timer.Create("GRM_Currency_Reconcile", RECONCILE, 0, tickReconcile)
        -- Хуки (событие+ID): чужая копия с теми же ID вытесняется.
        local slots = {
            { "PlayerInitialSpawn", "GRM_Currency_Init", onInitSpawn },
            { "PlayerDisconnected", "GRM_Currency_Disconnect", onDisconnect },
            { "ShutDown",           "GRM_Currency_Shutdown", onShutdown },
        }
        for _, s in ipairs(slots) do
            local ev = hook.GetTable()[s[1]]
            local cur = ev and ev[s[2]]
            if cur ~= s[3] then
                if cur ~= nil and report and not reclaimed[s[2]] then
                    reclaimed[s[2]] = true
                    print("[GRM Currency] ЗАХВАТ: чужая регистрация " .. s[2] .. " вытеснена — на сервере ЖИЛА вторая копия модуля!")
                    logForensic("захват слота " .. s[2] .. " (была чужая регистрация)")
                end
                hook.Remove(s[1], s[2])
                hook.Add(s[1], s[2], s[3])
            end
        end
        -- API ядра: если переопределено чужой копией — возвращаем свои ссылки.
        for n, fn in pairs(apiSnapshot) do
            if fn ~= nil and GRM[n] ~= fn then
                GRM[n] = fn
                if report and not reclaimed["API_" .. n] then
                    reclaimed["API_" .. n] = true
                    print("[GRM Currency] ЗАХВАТ: API GRM." .. n .. " возвращён у чужой копии")
                    logForensic("захват API " .. n)
                end
            end
        end
    end

    installHostSlots(false) -- первичная установка слотов при загрузке
    -- Сторожевой захват: копия, загруженная ПОЗЖЕ нас, живёт ≤10 секунд.
    timer.Create("GRM_Currency_Takeover", 10, 0, function() installHostSlots(true) end)

    -- СТОРОЖ ФАЙЛА (v1.5.7): любая ЧУЖАЯ запись grm_currency.json фиксируется
    -- в форензик-логе, легальные правки поднимаются, данные восстанавливаются.
    local lastBark = 0
    timer.Create("GRM_Currency_Watchdog", 2, 0, function()
        if not isstring(lastSavedTxt) then return end
        if not file.Exists(DATA_FILE, "DATA") then return end
        local txt = file.Read(DATA_FILE, "DATA") or ""
        if txt == lastSavedTxt then return end
        -- Безобидный случай: система хостинга переписала файл ТЕМ ЖЕ смыслом
        -- в другом форматировании — принимаем его как эталон, диск не долбим.
        local okW, ext = pcall(util.JSONToTable, txt)
        if okW and istable(ext) then
            local clean = sanitizedDump()
            local same = true
            for sid, rec in pairs(clean) do
                local e = ext[sid]
                if not (istable(e) and normalize(e.balance) == rec.balance) then same = false break end
            end
            if same then
                for sid in pairs(ext) do
                    if clean[sid] == nil then same = false break end
                end
            end
            if same then lastSavedTxt = txt mirrorFill() return end
        end
        -- Файл изменил НЕ наш saveNow: либо правка по FTP (легальна — поднимаем),
        -- либо чужой писатель (вредоносен — затрётся нашим состоянием).
        local n = reconcile("сторож файла")
        dirty = true
        saveNow(true, "сторож-самолечение")
        logForensic(("ЧУЖАЯ ЗАПИСЬ в %s (%d байт, поднято правок %d) — файл приведён к состоянию памяти"):format(DATA_FILE, #txt, n))
        if os.time() - lastBark >= 30 then
            lastBark = os.time()
            print(("[GRM Currency] СТОРОЖ: файл %s перезаписан снаружи (%d байт)! Данные восстановлены; детали: data/grm_currency_forensics.txt"):format(DATA_FILE, #txt))
        end
    end)

    -- Форензик-строка загрузки: путь файла виден прямо в логе data/.
    logForensic(("BOOT v1.5.8: путь=%s, база=%s, счетов=%d, файл=%s байт"):format(
        tostring(debug.getinfo(1, "S").short_src), DATA_FILE,
        table.Count(records),
        file.Exists(DATA_FILE, "DATA") and tostring(#(file.Read(DATA_FILE, "DATA") or "")) or "нет файла"))

    -- ========================================================
    -- КОНСОЛЬНЫЕ УТИЛИТЫ (сервер-консоль / суперадмин)
    -- ========================================================
    local function canUseConsole(ply)
        return not IsValid(ply) or (IsValid(ply) and ply:IsSuperAdmin())
    end

    local function findTarget(query)
        query = tostring(query or "")
        if records[query] then return query, records[query].name end -- точный SteamID64
        local low = query:lower()
        for _, p in ipairs(player.GetAll()) do
            if p:Nick():lower():find(low, 1, true) then
                return p:SteamID64(), p:Nick(), p
            end
        end
        for sid, rec in pairs(records) do
            if tostring(rec.name):lower():find(low, 1, true) then
                return sid, rec.name
            end
        end
        return nil
    end

    local function moneyCmd(ply, _, args)
        if not canUseConsole(ply) then return end
        local mode, query = tostring(args[1] or ""), tostring(args[2] or "")
        local amount = math.floor(tonumber(args[3] or "") or 0)

        if mode == "save" then dirty = true saveNow(false, "команда save") print("[GRM Currency] сохранено") return end
        if mode == "list" then
            print("[GRM Currency] счетов: " .. tostring(table.Count(records)))
            local n = 0
            for sid, rec in pairs(records) do
                n = n + 1
                print(string.format("  %s | %s | %s", sid, tostring(rec.name), GRM.Format(rec.balance)))
                if n >= 25 then print("  ... (показаны первые 25)") break end
            end
            return
        end
        if mode ~= "give" and mode ~= "take" and mode ~= "set" and mode ~= "info" then
            print("[GRM Currency] grm_money <give|take|set|info|list|save> <SteamID64|ник> [сумма]")
            return
        end
        if query == "" then print("[GRM Currency] укажите цель") return end

        local sid, name, onlinePly = findTarget(query)
        if not sid then print("[GRM Currency] игрок не найден: " .. query) return end
        local target = (IsValid(onlinePly) and onlinePly) or sid

        if mode == "info" then
            print("[GRM Currency] " .. tostring(name) .. " (" .. sid .. "): " .. GRM.Format(GRM.GetBalance(target)))
        elseif mode == "give" then
            GRM.GiveMoney(target, amount)
            print("[GRM Currency] +" .. GRM.Format(amount) .. " → " .. tostring(name) .. " = " .. GRM.Format(GRM.GetBalance(target)))
        elseif mode == "take" then
            GRM.TakeMoney(target, amount)
            print("[GRM Currency] -" .. GRM.Format(amount) .. " → " .. tostring(name) .. " = " .. GRM.Format(GRM.GetBalance(target)))
        elseif mode == "set" then
            GRM.SetBalance(target, amount)
            print("[GRM Currency] " .. tostring(name) .. " = " .. GRM.Format(GRM.GetBalance(target)))
        end
        dirty = true
        saveNow(false, "grm_money")
    end
    concommand.Add("grm_money", moneyCmd)

    print(("[GRM Currency] ядро загружено v1.5.8, путь: %s, база: data/%s, счетов в памяти: %d"):format(
        tostring(debug.getinfo(1, "S").short_src), DATA_FILE, table.Count(records)))
end

-- ============================================================
-- КЛИЕНТ
-- ============================================================
if CLIENT then
    GRM.LocalBalance = GRM.LocalBalance or 0

    net.Receive(NET_SYNC, function()
        GRM.LocalBalance = net.ReadUInt(32)
        hook.Run("GRM_LocalMoneyChanged", GRM.LocalBalance)
    end)

    -- Зеркало для внешних модулей: HUD (Код 48) и Tab Menu (Код 47)
    -- читают GRM.PlayerBalance как единственный источник баланса.
    GRM.PlayerBalance = GRM.PlayerBalance or GRM.LocalBalance
    hook.Add("GRM_LocalMoneyChanged", "GRM_Currency_MirrorPlayerBalance", function(bal)
        GRM.PlayerBalance = bal
    end)

    net.Receive(NET_NOTIFY, function()
        -- v1.5.5: наш HUD (Код 48) уже рисует это уведомление всплывашкой
        -- из легаси-канала grm_notify (GRM.Notify шлёт оба) — не дублируем.
        if GRM.HUD then return end
        local msg = net.ReadString()
        local r, g, b = net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8)
        local col = Color(r, g, b)
        -- Красноватые уведомления считаем ошибками, остальные — обычными.
        local ntype = (r >= 200 and g <= 160) and NOTIFY_ERROR or NOTIFY_GENERIC
        notification.AddLegacy(msg, ntype, 4)
        chat.AddText(col, msg)
    end)

    -- Клиентская GRM.Notify: терпимая к обоим порядкам аргументов.
    -- (ply, msg, r,g,b) игнорирует ply, (msg, r,g,b) — показывает локально.
    function GRM.Notify(a, b, c, d, e)
        local msg, r, g, bl
        if isentity(a) then msg, r, g, bl = b, c, d, e else msg, r, g, bl = a, b, c, d end
        msg = tostring(msg or "")
        local col = Color(tonumber(r) or 255, tonumber(g) or 255, tonumber(bl) or 255)
        notification.AddLegacy(msg, NOTIFY_GENERIC, 4)
        chat.AddText(col, msg)
    end

    -- Локальный просмотр баланса: grm_balance
    concommand.Add("grm_balance", function()
        chat.AddText(Color(100, 220, 100), "[GRM] Ваш баланс: " .. GRM.Format(GRM.LocalBalance))
    end)

    print("[GRM Currency] client loaded")
end
