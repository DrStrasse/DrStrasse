--[[--------------------------------------------------------------------
    GRM Currency Core v1.4 (Код 42)

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

local DATA_FILE   = "grm_currency.json"
local NET_SYNC    = "GRM_Currency_Sync"
local NET_NOTIFY  = "GRM_Currency_Notify"
local AUTOSAVE    = 180 -- секунды

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
    util.AddNetworkString(NET_SYNC)
    util.AddNetworkString(NET_NOTIFY)
    -- Совместимость с внешними модулями (Tab Menu Код 47, HUD Код 48):
    util.AddNetworkString("grm_balance")
    util.AddNetworkString("grm_request_bal")
    util.AddNetworkString("grm_notify")

    -- records[sid64] = { balance = number, name = string }
    local records = {}
    local dirty = false

    local function normalize(amount)
        amount = math.floor(tonumber(amount) or 0)
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

    local function saveNow()
        if not dirty then return end
        file.Write(DATA_FILE, util.TableToJSON(records, true) or "{}")
        dirty = false
    end

    local function loadData()
        records = {}
        if not file.Exists(DATA_FILE, "DATA") then return end
        local rawTxt = file.Read(DATA_FILE, "DATA") or ""
        -- GRM-FIX: битый JSON (обрыв записи при падении) больше не
        -- обнуляет счета молча — файл откладывается для ручного спасения.
        local okJs, raw = pcall(util.JSONToTable, rawTxt)
        if not okJs or not istable(raw) then
            local backup = "grm_currency_corrupt_" .. os.time() .. ".txt"
            file.Write(backup, rawTxt)
            print("[GRM Currency] ОШИБКА чтения " .. DATA_FILE ..
                  " — сохранён как data/" .. backup)
            raw = {}
        end
        for sid, rec in pairs(raw) do
            if isstring(sid) and type(rec) == "table" then
                records[sid] = {
                    balance = normalize(rec.balance),
                    name = tostring(rec.name or "?"),
                }
            end
        end
    end

    local function ensure(sid, nick)
        if not records[sid] then
            records[sid] = { balance = normalize(GRM.StartBalance), name = nick or "?" }
            dirty = true
        end
        if nick and nick ~= "" then records[sid].name = nick end
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
        saveNow()
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
    -- ЖИЗНЕННЫЙ ЦИКЛ
    -- ========================================================
    loadData()

    hook.Add("PlayerInitialSpawn", "GRM_Currency_Init", function(ply)
        if not IsValid(ply) or ply:IsBot() then return end
        local sid = ply:SteamID64()
        local rec = records[sid]
        if not rec then
            ensure(sid, ply:Nick())
            dirty = true
            saveNow()
        else
            rec.name = ply:Nick()
        end
        -- Клиент может быть ещё не готов принимать net — шлём с задержкой.
        local tag = "GRM_Currency_FirstSync_" .. sid
        timer.Create(tag, 2, 1, function()
            if IsValid(ply) then pushBalance(ply) end
        end)
    end)

    hook.Add("PlayerDisconnected", "GRM_Currency_Disconnect", function(ply)
        if not IsValid(ply) then return end
        local rec = records[ply:SteamID64()]
        if rec then rec.name = ply:Nick() end
        dirty = true
        saveNow()
    end)

    hook.Add("ShutDown", "GRM_Currency_Shutdown", function()
        dirty = true
        saveNow()
    end)

    timer.Create("GRM_Currency_AutoSave", AUTOSAVE, 0, saveNow)
    -- GRM-FIX: быстрый сброс изменений на диск каждые 5с — переживаем
    -- килл процесса без ShutDown и длинные окна автосейва.
    timer.Create("GRM_Currency_Flush", 5, 0, function()
        if dirty then saveNow() end
    end)

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

        if mode == "save" then dirty = true saveNow() print("[GRM Currency] сохранено") return end
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
        saveNow()
    end
    concommand.Add("grm_money", moneyCmd)

    print("[GRM Currency] ядро загружено, счетов: " .. tostring(table.Count(records)))
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
