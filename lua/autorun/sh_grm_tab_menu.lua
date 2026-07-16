--[[--------------------------------------------------------------------
    GRM Tab Menu v1.7 — Полная синхронизация баланса (исправлено)
    - Используется GRM.PlayerBalance вместо локальной _myBalance
    - Добавлен net-обработчик grm_request_bal на сервере
    - Баланс обновляется мгновенно при изменении
    (Код 47; сохранено агентом: снят ГМЛ-манглинг веб-вставки — восстановлены < > _)
--------------------------------------------------------------------]]

GRM = GRM or {}
GRM.TabMenu = GRM.TabMenu or {}
GRM.TabMenu.ShowBalance    = true
GRM.TabMenu.ShowFaction    = true
GRM.TabMenu.ReplaceDefault = true
GRM.TabMenu.RefreshInterval = 5

GRM.GaggedPlayers = GRM.GaggedPlayers or {}

if SERVER then
    util.AddNetworkString("grm_tab_request")
    util.AddNetworkString("grm_tab_data")
    util.AddNetworkString("grm_tab_action")
    util.AddNetworkString("grm_tab_result")
    util.AddNetworkString("grm_tab_gagupdate")
    util.AddNetworkString("grm_request_bal")   -- добавлено
    util.AddNetworkString("grm_balance")       -- добавлено
end

if SERVER then
    -- ── Функция получения баланса (если не определена) ──────────
    if not GRM.GetBalance then
        -- Предположим, что баланс хранится в GRM.Balances[ply:SteamID()]
        GRM.Balances = GRM.Balances or {}
        function GRM.GetBalance(ply)
            if not IsValid(ply) then return 0 end
            return GRM.Balances[ply:SteamID()] or 0
        end
        function GRM.SetBalance(ply, amount)
            if not IsValid(ply) then return end
            GRM.Balances[ply:SteamID()] = math.max(0, amount)
            -- Отправить обновление клиенту
            net.Start("grm_balance")
                net.WriteInt(amount, 32)
            net.Send(ply)
        end
        print("[GRM Tab] Используется встроенная система баланса (GRM.Balances)")
    end

    -- ── Обработчик запроса баланса (для клиента) ────────────────
    net.Receive("grm_request_bal", function(_, ply)
        if GRM.GetBalance then
            local bal = GRM.GetBalance(ply)
            net.Start("grm_balance")
                net.WriteInt(bal, 32)
            net.Send(ply)
        end
    end)

    -- ── Остальные функции (без изменений) ────────────────────────
    local function getPlayerRank(ply)
        if not IsValid(ply) then return "user" end
        local sid = ply:SteamID()
        if ULib and ULib.ucl and ULib.ucl.getUserGroup then
            local group = ULib.ucl.getUserGroup(sid)
            if group and group ~= "" then return group end
        end
        if ulx and ulx.getUserGroup then
            local group = ulx.getUserGroup(sid)
            if group and group ~= "" then return group end
        end
        if ply:IsSuperAdmin() then return "superadmin" end
        if ply:IsAdmin()      then return "admin"      end
        return "user"
    end

    local function getPlayerFaction(ply)
        if not Factions then return "" end
        local sid = ply:SteamID()
        for name, f in pairs(Factions) do
            if istable(f) and istable(f.Members) and f.Members[sid] then
                return name
            end
        end
        return ""
    end

    local function buildTabData(requester)
        local isAdmin = requester:IsAdmin()
        local players = {}
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                local sid = ply:SteamID64()
                local bal = 0
                if GRM.GetBalance then
                    if isAdmin or ply == requester then
                        bal = GRM.GetBalance(ply)
                    end
                end
                table.insert(players, {
                    sid64    = sid,
                    nick     = ply:Nick(),
                    rank     = getPlayerRank(ply),
                    faction  = GRM.TabMenu.ShowFaction and getPlayerFaction(ply) or "",
                    balance  = bal,
                    showBal  = isAdmin or (ply == requester),
                    pingMs   = ply:Ping(),
                    isBot    = ply:IsBot(),
                    isGagged = GRM.GaggedPlayers[sid] and true or false,
                })
            end
        end
        table.sort(players, function(a, b)
            local function rankVal(r)
                if r == "superadmin" or r == "owner" then return 0 end
                if r == "admin" or r == "operator"   then return 1 end
                return 2
            end
            local ra, rb = rankVal(a.rank), rankVal(b.rank)
            if ra ~= rb then return ra < rb end
            return a.nick:lower() < b.nick:lower()
        end)
        return { players = players }
    end

    net.Receive("grm_tab_request", function(_, ply)
        local data = buildTabData(ply)
        net.Start("grm_tab_data")
            net.WriteTable(data)
        net.Send(ply)
    end)

    net.Receive("grm_tab_action", function(_, admin)
        if not admin:IsAdmin() then return end
        local a = net.ReadTable()
        if not a or not a.type then return end

        local function findBySID64(sid64)
            for _, p in ipairs(player.GetAll()) do
                if IsValid(p) and p:SteamID64() == sid64 then return p end
            end
            return nil
        end

        local function sendResult(ok, msg)
            net.Start("grm_tab_result")
                net.WriteBool(ok)
                net.WriteString(msg or "")
            net.Send(admin)
        end

        if a.type == "gag" or a.type == "ungag" then
            local target = findBySID64(a.sid64)
            if not IsValid(target) then sendResult(false, "Игрок не в сети"); return end
            local gag = (a.type == "gag")
            GRM.GaggedPlayers[a.sid64] = gag or nil
            net.Start("grm_tab_gagupdate")
                net.WriteString(a.sid64)
                net.WriteBool(gag)
            net.Broadcast()
            if gag then
                GRM.Notify(target, "[Система] Вы заглушены в чате администратором " .. admin:Nick(), 255, 80, 80)
                sendResult(true, "Заглушён: " .. target:Nick())
            else
                GRM.Notify(target, "[Система] Вы разглушены администратором " .. admin:Nick(), 100, 220, 100)
                sendResult(true, "Разглушён: " .. target:Nick())
            end

        elseif a.type == "kick" then
            local target = findBySID64(a.sid64)
            if not IsValid(target) then sendResult(false, "Игрок не в сети"); return end
            if target == admin then sendResult(false, "Нельзя кикнуть себя"); return end
            local reason = a.reason or "Кикнут администратором"
            if ULib and ulx and ulx.kick then
                ULib.queueFunctionCall(ulx.kick, admin, target, reason)
            else
                target:Kick("[GRM] " .. reason)
            end
            sendResult(true, "Кикнут: " .. target:Nick())

        elseif a.type == "ban" then
            local target = findBySID64(a.sid64)
            if not IsValid(target) then sendResult(false, "Игрок не в сети"); return end
            if target == admin then sendResult(false, "Нельзя забанить себя"); return end
            if target:IsSuperAdmin() and not admin:IsSuperAdmin() then
                sendResult(false, "Нельзя банить SuperAdmin"); return
            end
            local minutes = math.max(0, math.floor(tonumber(a.minutes) or 0))
            local reason  = a.reason or "Забанен администратором"
            if ULib and ulx and ulx.ban then
                ULib.queueFunctionCall(ulx.ban, admin, target, minutes, reason)
            else
                local steamid = target:SteamID()
                target:Kick("[GRM] Забанен: " .. reason)
                if minutes == 0 then
                    game.ConsoleCommand("banid 0 " .. steamid .. "\n")
                    game.ConsoleCommand("writeid\n")
                else
                    game.ConsoleCommand("banid " .. minutes .. " " .. steamid .. "\n")
                    game.ConsoleCommand("writeid\n")
                end
            end
            local durStr = minutes == 0 and "навсегда" or (minutes .. " мин.")
            sendResult(true, "Забанен (" .. durStr .. "): " .. target:Nick())

        elseif a.type == "ulx_mute" or a.type == "ulx_unmute" then
            if not (ULib and ulx and ulx.mute) then
                sendResult(false, "ULX не установлен или функция mute недоступна"); return
            end
            local target = findBySID64(a.sid64)
            if not IsValid(target) then sendResult(false, "Игрок не в сети"); return end
            local muting = (a.type == "ulx_mute")
            ULib.queueFunctionCall(ulx.mute, admin, target, muting and 1 or 0, muting and "Заглушен голос" or "")
            sendResult(true, (muting and "Заглушен голос: " or "Разглушен голос: ") .. target:Nick())
        end
    end)

    hook.Add("PlayerSay", "GRM_TabGagFilter", function(ply, text)
        if GRM.GaggedPlayers[ply:SteamID64()] then
            net.Start("grm_notify")
                net.WriteString("[Система] Вы заглушены. Чат недоступен.")
                net.WriteUInt(255, 8)
                net.WriteUInt(80,  8)
                net.WriteUInt(80,  8)
            net.Send(ply)
            return ""
        end
    end)

    print("[GRM] Tab Menu v1.7 — сервер загружен")
end

if CLIENT then
    surface.CreateFont("GRMT_Title",   { font = "Roboto", size = 20, weight = 700 })
    surface.CreateFont("GRMT_Head",    { font = "Roboto", size = 14, weight = 700 })
    surface.CreateFont("GRMT_Body",    { font = "Roboto", size = 13, weight = 400 })
    surface.CreateFont("GRMT_Small",   { font = "Roboto", size = 11, weight = 400 })
    surface.CreateFont("GRMT_Badge",   { font = "Roboto", size = 11, weight = 700 })
    surface.CreateFont("GRMT_BigBal",  { font = "Roboto", size = 16, weight = 700 })

    local C = {
        BG       = Color(14,  16,  22,  245),
        PANEL    = Color(22,  25,  36,  255),
        DARK     = Color(12,  14,  20,  255),
        BORDER   = Color(40,  45,  65,  255),
        ROW_ALT  = Color(18,  21,  32,  255),
        ROW_SEL  = Color(30,  50,  90,  255),
        ROW_HOV  = Color(24,  28,  42,  255),
        WHITE    = Color(215, 220, 235, 255),
        GREY     = Color(120, 125, 145, 255),
        GREEN    = Color(60,  200, 90,  255),
        RED      = Color(210, 70,  60,  255),
        BLUE     = Color(70,  140, 220, 255),
        GOLD     = Color(220, 175, 45,  255),
        PURPLE   = Color(160, 90,  220, 255),
        CYAN     = Color(60,  200, 200, 255),
        ORANGE   = Color(220, 130, 40,  255),
    }

    local RANK_INFO = {
        superadmin = { label = "СА",    col = C.GOLD,   priority = 0 },
        owner      = { label = "OWNER", col = C.RED,    priority = 0 },
        admin      = { label = "А",     col = C.BLUE,   priority = 1 },
        operator   = { label = "ОП",    col = C.CYAN,   priority = 1 },
        moderator  = { label = "МОД",   col = C.GREEN,  priority = 1 },
        ["vip+"]   = { label = "VIP+",  col = C.PURPLE, priority = 2 },
        vip        = { label = "VIP",   col = C.PURPLE, priority = 2 },
        user       = { label = "U",     col = C.GREY,   priority = 3 },
    }

    local function getRankInfo(rank)
        return RANK_INFO[rank] or { label = rank:upper():sub(1,3), col = C.ORANGE, priority = 2 }
    end

    local _frame        = nil
    local _data         = nil
    local _voiceMuted   = {}
    local _gagCache     = {}
    local _searchStr    = ""
    local _sortMode     = "rank"
    local _selSID       = nil
    local _selPanel     = nil
    local _vehListCache = nil

    -- Используем GRM.PlayerBalance как единственный источник
    -- Убираем _myBalance, все обращения заменяем на GRM.PlayerBalance
    -- Ресивер для grm_balance (если не определён в другом месте)
    if not GRM._tabBalRcv then
        GRM._tabBalRcv = true
        net.Receive("grm_balance", function()
            local bal = net.ReadInt(32)
            GRM.PlayerBalance = bal
            -- Обновляем локальную запись в _data.players
            if _data and _data.players then
                local lp = LocalPlayer()
                if IsValid(lp) then
                    local mySID = lp:SteamID64()
                    for _, pd in ipairs(_data.players) do
                        if pd.sid64 == mySID then
                            pd.balance = bal
                            pd.showBal = true
                            break
                        end
                    end
                end
            end
            -- Вызываем хук для обновления HUD и других модулей
            hook.Run("GRM_BalanceUpdated", bal)
            -- Если таб открыт, обновляем его
            if IsValid(_frame) and _frame._refresh then
                _frame._refresh()
            end
        end)
    end

    -- Хук на обновление баланса (для внешних вызовов)
    hook.Add("GRM_BalanceUpdated", "GRM_TabBalanceUpdate", function(bal)
        GRM.PlayerBalance = bal
        if _data and _data.players then
            local lp = LocalPlayer()
            if IsValid(lp) then
                local mySID = lp:SteamID64()
                for _, pd in ipairs(_data.players) do
                    if pd.sid64 == mySID then
                        pd.balance = bal
                        pd.showBal = true
                        break
                    end
                end
            end
        end
        if IsValid(_frame) and _frame._refresh then
            _frame._refresh()
        end
    end)

    -- Построение локального списка (до получения серверных данных)
    local function buildLocalPlayers()
        local list = {}
        local lp   = LocalPlayer()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                local rank = "user"
                if ply:IsSuperAdmin() then rank = "superadmin"
                elseif ply:IsAdmin()  then rank = "admin" end
                local bal     = 0
                local showBal = false
                if lp and ply == lp then
                    bal     = GRM.PlayerBalance or 0
                    showBal = true
                end
                table.insert(list, {
                    sid64    = ply:SteamID64(),
                    nick     = ply:Nick(),
                    rank     = rank,
                    faction  = "",
                    balance  = bal,
                    showBal  = showBal,
                    pingMs   = ply:Ping(),
                    isBot    = ply:IsBot(),
                    isGagged = _gagCache[ply:SteamID64()] or false,
                })
            end
        end
        table.sort(list, function(a, b)
            local function rv(r)
                if r == "superadmin" or r == "owner" then return 0 end
                if r == "admin" or r == "operator"   then return 1 end
                return 2
            end
            local ra, rb = rv(a.rank), rv(b.rank)
            if ra ~= rb then return ra < rb end
            return a.nick:lower() < b.nick:lower()
        end)
        return list
    end

    -- VD_VehicleList
    net.Receive("VD_VehicleList", function()
        _vehListCache = net.ReadTable() or {}
        hook.Run("VD_VehicleListReceived", _vehListCache)
    end)

    local function openVehicleSpawnMenu(targetSid64, targetNick)
        local W, H = 500, 420
        local frame = vgui.Create("DFrame")
        frame:SetTitle("Спавн транспорта  →  " .. targetNick)
        frame:SetSize(W, H); frame:Center(); frame:MakePopup()
        frame.Paint = function(_, w, h)
            draw.RoundedBox(8, 0, 0, w, h, C.BG)
            draw.RoundedBox(8, 0, 0, w, 26, C.DARK)
        end

        local lv = vgui.Create("DListView", frame)
        lv:Dock(FILL); lv:DockMargin(8, 8, 8, 54)
        lv:SetMultiSelect(false)
        lv:AddColumn("Название"):SetFixedWidth(180)
        lv:AddColumn("Класс"):SetFixedWidth(180)
        lv:AddColumn("Дилер"):SetFixedWidth(110)

        local function populate(list)
            lv:Clear()
            for _, v in ipairs(list or {}) do
                local ln = lv:AddLine(v.name or v.class, v.class, v.dealer or "—")
                ln._vclass = v.class
            end
        end

        local bot = vgui.Create("DPanel", frame)
        bot:Dock(BOTTOM); bot:SetTall(46); bot:SetPaintBackground(false)
        bot:DockMargin(8, 0, 8, 6)

        local manualEntry = vgui.Create("DTextEntry", bot)
        manualEntry:Dock(FILL); manualEntry:DockMargin(0, 8, 6, 8)
        manualEntry:SetPlaceholderText("Или введи класс вручную...")
        manualEntry:SetFont("GRMT_Body"); manualEntry:SetTextColor(C.WHITE)
        manualEntry.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, C.DARK)
            surface.SetDrawColor(C.BORDER); surface.DrawOutlinedRect(0, 0, w, h, 1)
            s:DrawTextEntryText(C.WHITE, Color(70, 130, 220, 150), C.WHITE)
        end

        local spawnBtn = vgui.Create("DButton", bot)
        spawnBtn:Dock(RIGHT); spawnBtn:SetWide(150); spawnBtn:DockMargin(0, 6, 0, 6)
        spawnBtn:SetText("Заспавнить"); spawnBtn:SetFont("GRMT_Body")
        spawnBtn:SetTextColor(C.WHITE)
        spawnBtn.Paint = function(s, w, h)
            draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(46, 116, 46) or Color(32, 88, 32))
        end
        spawnBtn.DoClick = function()
            local vclass
            local manual = (manualEntry:GetText() or ""):Trim()
            if manual ~= "" then
                vclass = manual
            else
                local line = lv:GetSelectedLine()
                vclass = IsValid(line) and line._vclass
            end
            if not vclass or vclass == "" then
                notification.AddLegacy("Выберите или введите класс", NOTIFY_ERROR, 2); return
            end
            net.Start("VD_AdminSpawnVehicle")
                net.WriteString(targetSid64)
                net.WriteString(vclass)
            net.SendToServer()
            notification.AddLegacy("Запрос спавна: " .. vclass, NOTIFY_GENERIC, 3)
            frame:Close()
        end

        if _vehListCache and #_vehListCache > 0 then
            populate(_vehListCache)
        else
            local waitLbl = vgui.Create("DLabel", frame)
            waitLbl:SetPos(0, H / 2 - 20); waitLbl:SetSize(W, 20)
            waitLbl:SetText("Загрузка списка транспорта...")
            waitLbl:SetFont("GRMT_Body"); waitLbl:SetTextColor(C.GREY)
            waitLbl:SetContentAlignment(5)
            hook.Add("VD_VehicleListReceived", "VD_SpawnMenuFill_" .. targetSid64, function(list)
                hook.Remove("VD_VehicleListReceived", "VD_SpawnMenuFill_" .. targetSid64)
                if IsValid(waitLbl) then waitLbl:Remove() end
                if IsValid(frame) then populate(list) end
            end)
        end

        net.Start("VD_RequestVehicleList"); net.SendToServer()
    end

    net.Receive("grm_tab_data", function()
        _data = net.ReadTable()
        if _data and _data.players then
            for _, pd in ipairs(_data.players) do
                if pd.isGagged then _gagCache[pd.sid64] = true
                else _gagCache[pd.sid64] = nil end
            end
            -- Подставляем актуальный локальный баланс
            local lp = LocalPlayer()
            if IsValid(lp) then
                local mySID = lp:SteamID64()
                for _, pd in ipairs(_data.players) do
                    if pd.sid64 == mySID then
                        pd.balance = GRM.PlayerBalance or 0
                        pd.showBal = true
                        break
                    end
                end
            end
        end
        if IsValid(_frame) and _frame._refresh then _frame._refresh() end
    end)

    net.Receive("grm_tab_gagupdate", function()
        local sid64  = net.ReadString()
        local gagged = net.ReadBool()
        _gagCache[sid64] = gagged or nil
        if IsValid(_frame) and _frame._refresh then _frame._refresh() end
    end)

    net.Receive("grm_tab_result", function()
        local ok  = net.ReadBool()
        local msg = net.ReadString()
        chat.AddText(
            ok and Color(80, 200, 80) or Color(200, 80, 80),
            "[GRM] " .. (ok and "OK " or "ERR ") .. msg
        )
        timer.Simple(0.5, function()
            net.Start("grm_tab_request")
            net.SendToServer()
        end)
    end)

    local function sendAction(tbl)
        net.Start("grm_tab_action")
            net.WriteTable(tbl)
        net.SendToServer()
    end

    local function requestData()
        net.Start("grm_tab_request")
        net.SendToServer()
        -- Также запрашиваем баланс для себя
        net.Start("grm_request_bal")
        net.SendToServer()
    end

    local function isAdmin()
        return IsValid(LocalPlayer()) and LocalPlayer():IsAdmin()
    end

    local function isSuperAdmin()
        return IsValid(LocalPlayer()) and LocalPlayer():IsSuperAdmin()
    end

    local function mkBtn(parent, text, col, x, y, w, h, fn)
        local b = vgui.Create("DButton", parent)
        if not IsValid(b) then return end
        b:SetPos(x, y); b:SetSize(w, h)
        b:SetText(text); b:SetFont("GRMT_Small"); b:SetTextColor(C.WHITE)
        b.Paint = function(s, bw, bh)
            local c = s:IsDown() and Color(math.Clamp(col.r-20,0,255), math.Clamp(col.g-20,0,255), math.Clamp(col.b-20,0,255))
                   or s:IsHovered() and Color(math.Clamp(col.r+25,0,255), math.Clamp(col.g+25,0,255), math.Clamp(col.b+25,0,255))
                   or col
            draw.RoundedBox(4, 0, 0, bw, bh, c)
        end
        b.DoClick = fn
        return b
    end

    -- Детальная панель
    local function buildDetailPanel(parent, pd)
        if IsValid(_selPanel) then _selPanel:Remove() end
        local pw = parent:GetWide()
        local ph = parent:GetTall()
        local dw = 270
        local sp = vgui.Create("DPanel", parent)
        sp:SetPos(pw - dw - 8, 0); sp:SetSize(dw, ph)
        sp.Paint = function(_, w, h)
            draw.RoundedBox(8, 0, 0, w, h, C.PANEL)
            surface.SetDrawColor(C.BORDER)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
        end
        _selPanel = sp

        local ri  = getRankInfo(pd.rank)
        local y   = 14
        local badgeW = 50
        local badge = vgui.Create("DPanel", sp)
        badge:SetPos(12, y); badge:SetSize(badgeW, 22)
        badge.Paint = function(_, w, h) draw.RoundedBox(4, 0, 0, w, h, ri.col) end
        local badgeLbl = vgui.Create("DLabel", badge)
        badgeLbl:SetPos(0,0); badgeLbl:SetSize(badgeW, 22)
        badgeLbl:SetText(ri.label)
        badgeLbl:SetFont("GRMT_Badge"); badgeLbl:SetTextColor(Color(0,0,0,200))
        badgeLbl:SetContentAlignment(5)

        local nameLbl = vgui.Create("DLabel", sp)
        nameLbl:SetPos(68, y+2); nameLbl:SetSize(dw - 80, 20)
        nameLbl:SetText(pd.nick); nameLbl:SetFont("GRMT_Head"); nameLbl:SetTextColor(C.WHITE)
        y = y + 28

        local sidLbl = vgui.Create("DLabel", sp)
        sidLbl:SetPos(12, y); sidLbl:SetSize(dw - 24, 14)
        sidLbl:SetText(pd.sid64); sidLbl:SetFont("GRMT_Small"); sidLbl:SetTextColor(C.GREY)
        y = y + 18

        if pd.faction and pd.faction ~= "" then
            local facLbl = vgui.Create("DLabel", sp)
            facLbl:SetPos(12, y); facLbl:SetSize(dw - 24, 16)
            facLbl:SetText("Фракция: " .. pd.faction); facLbl:SetFont("GRMT_Small"); facLbl:SetTextColor(C.GOLD)
            y = y + 18
        end

        local pingLbl = vgui.Create("DLabel", sp)
        pingLbl:SetPos(12, y); pingLbl:SetSize(dw - 24, 14)
        pingLbl:SetText("Пинг: " .. (pd.pingMs or "?") .. " ms")
        pingLbl:SetFont("GRMT_Small"); pingLbl:SetTextColor(C.GREY)
        y = y + 20

        local sep1 = vgui.Create("DPanel", sp)
        sep1:SetPos(12, y); sep1:SetSize(dw - 24, 1)
        sep1.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, C.BORDER) end
        y = y + 10

        if pd.showBal then
            local balTitle = vgui.Create("DLabel", sp)
            balTitle:SetPos(12, y); balTitle:SetSize(dw - 24, 14)
            balTitle:SetText("БАЛАНС"); balTitle:SetFont("GRMT_Small"); balTitle:SetTextColor(C.GREY)
            y = y + 16
            local balVal = vgui.Create("DLabel", sp)
            balVal:SetPos(12, y); balVal:SetSize(dw - 24, 22)
            local balStr = (GRM and GRM.Format) and GRM.Format(pd.balance) or (pd.balance .. " GRM")
            balVal:SetText(balStr); balVal:SetFont("GRMT_BigBal"); balVal:SetTextColor(C.GREEN)
            y = y + 28
        end

        local sep2 = vgui.Create("DPanel", sp)
        sep2:SetPos(12, y); sep2:SetSize(dw - 24, 1)
        sep2.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, C.BORDER) end
        y = y + 10

        local isMuted = _voiceMuted[pd.sid64] or false
        local lp      = LocalPlayer()
        local isSelf  = IsValid(lp) and lp:SteamID64() == pd.sid64

        if not isSelf then
            local muteLabel = vgui.Create("DLabel", sp)
            muteLabel:SetPos(12, y); muteLabel:SetSize(dw - 24, 14)
            muteLabel:SetText("ЛИЧНЫЕ НАСТРОЙКИ"); muteLabel:SetFont("GRMT_Small"); muteLabel:SetTextColor(C.GREY)
            y = y + 16
            mkBtn(sp,
                isMuted and "Разблокировать голос" or "Заблокировать голос",
                isMuted and Color(60, 100, 60) or Color(70, 70, 100),
                12, y, dw - 24, 26,
                function()
                    _voiceMuted[pd.sid64] = not isMuted
                    buildDetailPanel(parent, pd)
                end
            )
            y = y + 32
        end

        if isAdmin() and not isSelf then
            local canAct = not (pd.rank == "superadmin" or pd.rank == "owner") or isSuperAdmin()
            local sep3 = vgui.Create("DPanel", sp)
            sep3:SetPos(12, y); sep3:SetSize(dw - 24, 1)
            sep3.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, C.BORDER) end
            y = y + 10
            local admLabel = vgui.Create("DLabel", sp)
            admLabel:SetPos(12, y); admLabel:SetSize(dw - 24, 14)
            admLabel:SetText("АДМИНИСТРИРОВАНИЕ"); admLabel:SetFont("GRMT_Small"); admLabel:SetTextColor(C.GREY)
            y = y + 16

            if canAct then
                local bHalf = (dw - 24 - 4) / 2
                local isGagged = _gagCache[pd.sid64] or false
                mkBtn(sp, "Заглушить",
                    isGagged and Color(60, 60, 60) or Color(120, 80, 20),
                    12, y, bHalf, 26,
                    function() sendAction({ type = "gag", sid64 = pd.sid64 }) end
                )
                mkBtn(sp, "Разглушить",
                    isGagged and Color(40, 100, 40) or Color(60, 60, 60),
                    12 + bHalf + 4, y, bHalf, 26,
                    function() sendAction({ type = "ungag", sid64 = pd.sid64 }) end
                )
                y = y + 32

                if ULib and ulx and ulx.mute then
                    mkBtn(sp, "Мут (ULX)", Color(50, 70, 120),
                        12, y, bHalf, 26,
                        function() sendAction({ type = "ulx_mute", sid64 = pd.sid64 }) end
                    )
                    mkBtn(sp, "Размут (ULX)", Color(30, 90, 60),
                        12 + bHalf + 4, y, bHalf, 26,
                        function() sendAction({ type = "ulx_unmute", sid64 = pd.sid64 }) end
                    )
                    y = y + 32
                end

                local sep4 = vgui.Create("DPanel", sp)
                sep4:SetPos(12, y); sep4:SetSize(dw - 24, 1)
                sep4.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, C.BORDER) end
                y = y + 10

                mkBtn(sp, "Кик", Color(130, 80, 30),
                    12, y, bHalf, 26,
                    function()
                        Derma_StringRequest(
                            "Причина кика",
                            "Укажи причину кика для " .. pd.nick,
                            "Нарушение правил",
                            function(reason)
                                sendAction({ type = "kick", sid64 = pd.sid64, reason = reason })
                            end
                        )
                    end
                )
                mkBtn(sp, "Бан", Color(160, 40, 40),
                    12 + bHalf + 4, y, bHalf, 26,
                    function()
                        local menu = DermaMenu()
                        menu:AddOption("Бан 1 час",        function() sendAction({ type="ban", sid64=pd.sid64, minutes=60,    reason="Бан 1ч"  }) end)
                        menu:AddOption("Бан 24 часа",      function() sendAction({ type="ban", sid64=pd.sid64, minutes=1440,  reason="Бан 24ч" }) end)
                        menu:AddOption("Бан 7 дней",       function() sendAction({ type="ban", sid64=pd.sid64, minutes=10080, reason="Бан 7д"  }) end)
                        menu:AddOption("Перманентный бан", function()
                            Derma_StringRequest(
                                "Причина бана",
                                "Перманентный бан для " .. pd.nick,
                                "Нарушение правил",
                                function(reason)
                                    sendAction({ type="ban", sid64=pd.sid64, minutes=0, reason=reason })
                                end
                            )
                        end)
                        menu:Open()
                    end
                )
                y = y + 32

                local sepVeh = vgui.Create("DPanel", sp)
                sepVeh:SetPos(12, y); sepVeh:SetSize(dw - 24, 1)
                sepVeh.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, C.BORDER) end
                y = y + 10
                local vehLbl = vgui.Create("DLabel", sp)
                vehLbl:SetPos(12, y); vehLbl:SetSize(dw - 24, 14)
                vehLbl:SetText("ТРАНСПОРТ"); vehLbl:SetFont("GRMT_Small"); vehLbl:SetTextColor(C.GREY)
                y = y + 16
                mkBtn(sp, "Спавн транспорта", Color(35, 65, 110),
                    12, y, dw - 24, 26,
                    function() openVehicleSpawnMenu(pd.sid64, pd.nick) end
                )
                y = y + 32
            else
                local noAct = vgui.Create("DLabel", sp)
                noAct:SetPos(12, y); noAct:SetSize(dw - 24, 16)
                noAct:SetText("Нельзя влиять на " .. (pd.rank or ""))
                noAct:SetFont("GRMT_Small"); noAct:SetTextColor(C.ORANGE)
            end
        end

        return sp
    end

    -- Строка игрока
    local ROW_H = 52
    local function buildPlayerRow(scroll, pd, idx, bodyW, detailParent)
        local isSelf   = IsValid(LocalPlayer()) and LocalPlayer():SteamID64() == pd.sid64
        local ri       = getRankInfo(pd.rank)
        local isMuted  = _voiceMuted[pd.sid64] or false
        local isGagged = _gagCache[pd.sid64] or false

        local row = vgui.Create("DPanel", scroll)
        row:SetSize(bodyW, ROW_H)
        row:Dock(TOP); row:DockMargin(0, 0, 0, 1)
        row.Paint = function(s, w, h)
            local bg = (_selSID == pd.sid64) and C.ROW_SEL
                    or (s:IsHovered() and C.ROW_HOV)
                    or (idx % 2 == 0 and C.ROW_ALT or C.DARK)
            draw.RoundedBox(4, 0, 0, w, h, bg)
            draw.RoundedBox(2, 0, 0, 3, h, ri.col)
            local badgeW = 34
            draw.RoundedBox(3, 10, (h-18)/2, badgeW, 18, ri.col)
            draw.SimpleText(ri.label, "GRMT_Badge", 10 + badgeW/2, h/2,
                Color(0,0,0,200), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

            local nameX    = 52
            local nameColor = isSelf and C.CYAN or C.WHITE
            draw.SimpleText(pd.nick, "GRMT_Body", nameX, h/2 - 7, nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            if pd.faction and pd.faction ~= "" then
                draw.SimpleText("[" .. pd.faction .. "]", "GRMT_Small", nameX, h/2 + 8, C.GOLD, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            elseif pd.isBot then
                draw.SimpleText("[BOT]", "GRMT_Small", nameX, h/2 + 8, C.GREY, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            if pd.showBal then
                local balStr = (GRM and GRM.Format) and GRM.Format(pd.balance) or tostring(pd.balance)
                draw.SimpleText(balStr, "GRMT_Body", w - 56, h/2, C.GREEN, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
            local iconX = w - 50
            if isMuted  then draw.SimpleText("[M]", "GRMT_Small", iconX + 16, h/2, C.GREY,   TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
            if isGagged then draw.SimpleText("[G]", "GRMT_Small", iconX + 30, h/2, C.ORANGE, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
            if isSelf   then draw.SimpleText("<<",  "GRMT_Small", iconX + 44, h/2, C.CYAN,   TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end

            local ping    = pd.pingMs or 0
            local pingCol = ping < 80 and C.GREEN or ping < 150 and C.GOLD or C.RED
            draw.SimpleText(ping .. "ms", "GRMT_Small", 52, h - 12, pingCol, TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
        end
        row:SetCursor("hand")
        row.OnMousePressed = function()
            _selSID = pd.sid64
            buildDetailPanel(detailParent, pd)
            if IsValid(_frame) and _frame._refresh then _frame._refresh() end
        end
        return row
    end

    -- Главное окно
    function GRM.OpenTabMenu()
        if IsValid(_frame) then return end
        local SW, SH = ScrW(), ScrH()
        local W = math.min(960, SW - 40)
        local H = math.min(640, SH - 40)

        local f = vgui.Create("DFrame")
        f:SetTitle("")
        f:SetSize(W, H)
        f:Center()
        f:MakePopup()
        f:SetDraggable(false)
        f:ShowCloseButton(false)
        _frame = f
        f.Paint = function(_, w, h)
            draw.RoundedBox(10, 0, 0, w, h, C.BG)
            draw.RoundedBox(10, 0, 0, w, 40, C.DARK)
            surface.SetDrawColor(C.BORDER)
            surface.DrawRect(0, 40, w, 1)
        end

        local titleLbl = vgui.Create("DLabel", f)
        titleLbl:SetPos(14, 10); titleLbl:SetSize(400, 22)
        titleLbl:SetText("ИГРОКИ НА СЕРВЕРЕ"); titleLbl:SetFont("GRMT_Title"); titleLbl:SetTextColor(C.WHITE)

        local cntLbl = vgui.Create("DLabel", f)
        cntLbl:SetPos(W/2 - 50, 12); cntLbl:SetSize(100, 18)
        cntLbl:SetFont("GRMT_Head"); cntLbl:SetTextColor(C.GREY); cntLbl:SetContentAlignment(5)

        local closeBtn = vgui.Create("DButton", f)
        closeBtn:SetPos(W - 34, 6); closeBtn:SetSize(28, 28)
        closeBtn:SetText("X"); closeBtn:SetFont("GRMT_Head"); closeBtn:SetTextColor(C.GREY)
        closeBtn.Paint = function(s, w, h)
            if s:IsHovered() then draw.RoundedBox(4, 0, 0, w, h, Color(180,40,40)) end
        end
        closeBtn.DoClick = function() f:Remove(); _frame = nil end

        local refBtn = vgui.Create("DButton", f)
        refBtn:SetPos(W - 130, 8); refBtn:SetSize(90, 24)
        refBtn:SetText("Обновить"); refBtn:SetFont("GRMT_Small"); refBtn:SetTextColor(C.WHITE)
        refBtn.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(45,60,90) or Color(30,40,65))
        end
        refBtn.DoClick = requestData

        local filterY  = 48
        local filterH  = 34
        local filterBg = vgui.Create("DPanel", f)
        filterBg:SetPos(0, filterY); filterBg:SetSize(W, filterH)
        filterBg.Paint = function(_, w, h) draw.RoundedBox(0, 0, 0, w, h, C.PANEL) end

        local searchEntry = vgui.Create("DTextEntry", filterBg)
        searchEntry:SetPos(10, 5); searchEntry:SetSize(180, 24)
        searchEntry:SetFont("GRMT_Body"); searchEntry:SetTextColor(C.WHITE)
        searchEntry:SetPlaceholderText("Поиск игрока...")
        searchEntry.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, C.DARK)
            surface.SetDrawColor(C.BORDER)
            surface.DrawOutlinedRect(0, 0, w, h, 1)
            s:DrawTextEntryText(C.WHITE, Color(70,130,220,150), C.WHITE)
        end
        searchEntry.OnChange = function(s)
            _searchStr = s:GetValue():lower()
            if IsValid(_frame) and _frame._refresh then _frame._refresh() end
        end

        local sortX = 204
        local sorts = {
            { key = "rank",    label = "Ранг"    },
            { key = "name",    label = "Имя"     },
            { key = "balance", label = "Баланс"  },
            { key = "faction", label = "Фракция" },
        }
        for _, s in ipairs(sorts) do
            local sb = vgui.Create("DButton", filterBg)
            sb:SetPos(sortX, 5); sb:SetSize(72, 24)
            sb:SetText(s.label); sb:SetFont("GRMT_Small"); sb:SetTextColor(C.WHITE)
            local sKey = s.key
            sb.Paint = function(btn, w, h)
                local active = _sortMode == sKey
                draw.RoundedBox(4, 0, 0, w, h,
                    active and C.BLUE
                    or (btn:IsHovered() and Color(40,50,75) or Color(28,33,52)))
            end
            sb.DoClick = function()
                _sortMode = sKey
                if IsValid(_frame) and _frame._refresh then _frame._refresh() end
            end
            sortX = sortX + 76
        end

        local bodyY    = filterY + filterH + 2
        local bodyH    = H - bodyY - 8
        local detailW  = 280
        local listW    = W - detailW - 24

        local body = vgui.Create("DPanel", f)
        body:SetPos(8, bodyY); body:SetSize(W - 16, bodyH)
        body.Paint = function() end

        local detailContainer = vgui.Create("DPanel", body)
        detailContainer:SetPos(listW + 8, 0); detailContainer:SetSize(detailW, bodyH)
        detailContainer.Paint = function() end

        local emptyCard = vgui.Create("DPanel", detailContainer)
        emptyCard:SetPos(0, 0); emptyCard:SetSize(detailW, bodyH)
        emptyCard.Paint = function(_, w, h)
            draw.RoundedBox(8, 0, 0, w, h, C.PANEL)
            draw.SimpleText("Выберите игрока", "GRMT_Body", w/2, h/2, C.GREY, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local scroll = vgui.Create("DScrollPanel", body)
        scroll:SetPos(0, 0); scroll:SetSize(listW, bodyH)
        scroll.Paint = function() end
        local vbar = scroll:GetVBar()
        vbar.Paint         = function(s, w, h) draw.RoundedBox(4, 0, 0, w, h, C.DARK) end
        vbar.btnUp.Paint   = function() end
        vbar.btnDown.Paint = function() end
        if IsValid(vbar.btnGrip) then
            vbar.btnGrip.Paint = function(s, w, h)
                draw.RoundedBox(4, 2, 0, w-4, h, s:IsHovered() and C.BLUE or C.BORDER)
            end
        end

        local hdr = vgui.Create("DPanel", body)
        hdr:SetPos(0, -22); hdr:SetSize(listW, 20)
        hdr.Paint = function(_, w, h)
            draw.RoundedBox(0, 0, 0, w, h, C.PANEL)
            draw.SimpleText("РАНГ  ИМЯ / ФРАКЦИЯ", "GRMT_Small", 52, h/2, C.GREY, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("БАЛАНС", "GRMT_Small", w - 56, h/2, C.GREY, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        local function refresh()
            scroll:Clear()
            local players = {}
            if _data and _data.players and #_data.players > 0 then
                players = _data.players
            else
                players = buildLocalPlayers()
            end

            local filtered = {}
            for _, pd in ipairs(players) do
                if _searchStr == "" or pd.nick:lower():find(_searchStr, 1, true) then
                    table.insert(filtered, pd)
                end
            end

            local cnt = #filtered
            if _sortMode == "name" then
                table.sort(filtered, function(a, b) return a.nick:lower() < b.nick:lower() end)
            elseif _sortMode == "balance" then
                table.sort(filtered, function(a, b) return (a.balance or 0) > (b.balance or 0) end)
            elseif _sortMode == "faction" then
                table.sort(filtered, function(a, b)
                    local fa, fb = a.faction or "", b.faction or ""
                    if fa ~= fb then return fa < fb end
                    return a.nick:lower() < b.nick:lower()
                end)
            end
            if IsValid(cntLbl) then
                cntLbl:SetText(cnt .. " игрок" .. (cnt==1 and "" or cnt<5 and "а" or "ов"))
            end

            for i, pd in ipairs(filtered) do
                buildPlayerRow(scroll, pd, i, listW, detailContainer)
            end
            if cnt == 0 then
                local emptyLbl = vgui.Create("DLabel", scroll)
                emptyLbl:SetPos(0, 20); emptyLbl:SetSize(listW, 24)
                emptyLbl:SetText(_searchStr ~= "" and "Ничего не найдено" or "Нет игроков")
                emptyLbl:SetFont("GRMT_Body"); emptyLbl:SetTextColor(C.GREY)
                emptyLbl:SetContentAlignment(5)
            end
        end
        f._refresh = refresh
        refresh()
        requestData()  -- теперь запрашивает и баланс

        timer.Create("GRM_TabAutoRefresh", GRM.TabMenu.RefreshInterval or 5, 0, function()
            if IsValid(f) then
                requestData()
            else
                timer.Remove("GRM_TabAutoRefresh")
            end
        end)
    end

    function GRM.CloseTabMenu()
        timer.Remove("GRM_TabAutoRefresh")
        if IsValid(_frame) then
            _frame:Remove()
            _frame = nil
        end
        _selSID = nil
        if IsValid(_selPanel) then _selPanel:Remove(); _selPanel = nil end
    end

    if GRM.TabMenu.ReplaceDefault then
        hook.Add("ScoreboardShow", "GRM_TabMenuShow", function()
            if not IsValid(_frame) then
                GRM.OpenTabMenu()
            end
            return true
        end)
        hook.Add("ScoreboardHide", "GRM_TabMenuHide", function()
            GRM.CloseTabMenu()
            return true
        end)
    end

    concommand.Add("grm_tabmenu", function()
        if IsValid(_frame) then
            GRM.CloseTabMenu()
        else
            GRM.OpenTabMenu()
        end
    end)

    hook.Add("NotifyShouldTransmit", "GRM_RestoreVoiceMutes", function(ent)
        if ent:IsPlayer() then
            local sid = ent:SteamID64()
            if _voiceMuted[sid] then
                ent:SetVoiceBlock(true)
            end
        end
    end)

    print("[GRM] Tab Menu v1.7 — клиент загружен (полная синхронизация баланса)")
end
