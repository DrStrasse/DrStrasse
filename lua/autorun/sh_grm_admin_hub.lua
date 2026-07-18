--[[--------------------------------------------------------------------
    GRM Admin Hub v1.0.0 (Код 79) — Единая админ-панель сборки

    Одно окно для суперадмина вместо охоты по разным меню. Открытие:
    /grm_admin в чате (через чат-контракт находки 89), консоль grm_admin.

    Вкладки:
      «Сервер»   — онлайн, карта, аптайм сессии, версии модулей GRM,
                   счётчики (активные задачи/публикации/багажники/фракции);
      «Доступы»  — матрица фракция × (ДОСКА/ЭФИР/ОПОВЕЩ/БИРЖА) — те же
                   хранилища, что у /factions → «Доступы» и чат-команд,
                   но СОБСТВЕННЫЙ протокол (не воюет за receiver'ы моста);
      «Биржа»    — активные задачи игроков (с провалом), заказы и
                   вакансии фракций (с удалением и возвратом эскроу);
      «Игроки»   — онлайн: ник/RP-имя/SID64/баланс/ачивки, копия
                   SteamID, сброс ачивок (AC.AdminReset);
      «Меню»     — быстрый запуск остальных админ-меню сборки
                   (/factions, экономика, двери, модели, оружие,
                   ЗП/логистика/транспорт/телефоны/ордера).

    Протокол свой: GRM_HUB_Get {tab} → GRM_HUB_Data {tab, payload};
    GRM_HUB_Act {action, args}. Везде проверка IsSuperAdmin на сервере.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.AdminHub = GRM.AdminHub or {}
local HB = GRM.AdminHub

HB.Version = "1.0.0"

local NET_GET  = "GRM_HUB_Get"
local NET_DATA = "GRM_HUB_Data"
local NET_ACT  = "GRM_HUB_Act"
local NET_OPEN = "GRM_HUB_Open"

-- ============================================================
-- СЕРВЕР
-- ============================================================
if SERVER then
    util.AddNetworkString(NET_GET)
    util.AddNetworkString(NET_DATA)
    util.AddNetworkString(NET_ACT)
    util.AddNetworkString(NET_OPEN)

    local function accTable(kind)
        if kind == "board" then
            return (GRM.Board and GRM.Board.Cfg and GRM.Board.Cfg.allow) or {}
        elseif kind == "journ" then
            return (GRM.Broadcast and GRM.Broadcast.Cfg and GRM.Broadcast.Cfg.journalists) or {}
        elseif kind == "alert" then
            return (GRM.Broadcast and GRM.Broadcast.Cfg and GRM.Broadcast.Cfg.alerters) or {}
        elseif kind == "jobs" then
            return (GRM.Jobs and GRM.Jobs.Cfg and GRM.Jobs.Cfg.allow) or {}
        end
        return {}
    end

    local function factionsList()
        local out = {}
        if istable(Factions) then
            for name, f in pairs(Factions) do
                if istable(f) then
                    out[#out + 1] = { name = name, leader = tostring(f.Leader or "—"), members = istable(f.Members) and table.Count(f.Members) or 0 }
                end
            end
        end
        table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
        return out
    end

    local function payloadServer()
        local vers = {}
        local function v(name, val) vers[#vers + 1] = { name = name, ver = tostring(val or "—") } end
        v("Биржа труда", GRM.Jobs and GRM.Jobs.Version)
        v("Ачивки", GRM.Ach and GRM.Ach.Version)
        v("Багажник", GRM.Trunk and GRM.Trunk.Version)
        v("Радио/оповещение", GRM.Broadcast and GRM.Broadcast.Version)
        v("Доска набора", GRM.Board and GRM.Board.Version)
        v("Валюта", "2.0.2")
        v("Экономика", "3.0.3")
        local posts = 0
        if GRM.Jobs and istable(GRM.Jobs.Cfg) then
            for _, list in pairs(GRM.Jobs.Cfg.posts or {}) do posts = posts + #list end
        end
        return {
            online = #player.GetAll(), map = game.GetMap(), uptime = math.floor(CurTime() or 0),
            versions = vers,
            counters = {
                { name = "Фракций", val = istable(Factions) and table.Count(Factions) or 0 },
                { name = "Активных задач биржи", val = (GRM.Jobs and GRM.Jobs.Active) and table.Count(GRM.Jobs.Active) or 0 },
                { name = "Публикаций на бирже", val = posts },
                { name = "Багажников в базе", val = (GRM.Trunk and GRM.Trunk.Store) and table.Count(GRM.Trunk.Store) or 0 },
                { name = "Записей ачивок", val = (GRM.Ach and GRM.Ach.Records) and table.Count(GRM.Ach.Records) or 0 },
            },
            factions = factionsList(),
        }
    end

    local function payloadAccess()
        return {
            factions = factionsList(),
            board = accTable("board"), journ = accTable("journ"), alert = accTable("alert"), jobs = accTable("jobs"),
        }
    end

    local function payloadJobs()
        local active = {}
        if GRM.Jobs and istable(GRM.Jobs.Active) then
            for sid, j in pairs(GRM.Jobs.Active) do
                if istable(j) then
                    active[#active + 1] = {
                        sid = tostring(sid), title = tostring(j.title or ""), jtype = tostring(j.jtype or ""),
                        remain = math.max(0, (j.deadline or os.time()) - os.time()),
                        stayLeft = tonumber(j.stayLeft) or 0, reward = tonumber(j.reward) or 0,
                    }
                end
            end
        end
        local posts = {}
        if GRM.Jobs and istable(GRM.Jobs.Cfg) then
            for fac, list in pairs(GRM.Jobs.Cfg.posts or {}) do
                for _, p in ipairs(list or {}) do
                    posts[#posts + 1] = {
                        fac = fac, id = tonumber(p.id) or 0, kind = tostring(p.kind or "order"),
                        title = tostring(p.title or ""), taken = p.takenBy ~= nil,
                        escrow = (GRM.Jobs.PostEscrow and GRM.Jobs.PostEscrow(p)) or (tonumber(p.reward) or 0),
                        shiftsLeft = tonumber(p.shiftsLeft) or 0,
                    }
                end
            end
        end
        table.sort(active, function(a, b) return a.sid < b.sid end)
        table.sort(posts, function(a, b) return (a.fac == b.fac) and (a.id < b.id) or (a.fac < b.fac) end)
        return { active = active, posts = posts }
    end

    local function payloadPlayers()
        local out = {}
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) then
                local sid = p:SteamID64() or p:SteamID()
                local achDone, achTotal = 0, 0
                if GRM.Ach then
                    achTotal = #(GRM.Ach.Order or {})
                    local rec = GRM.Ach.Records and GRM.Ach.Records[sid]
                    if istable(rec) then for id in pairs(rec.u or {}) do achDone = achDone + 1 end end
                end
                out[#out + 1] = {
                    nick = p:Nick(), rp = p:GetNWString("GRM_RPName", ""), sid = tostring(sid),
                    bal = (GRM.GetBalance and GRM.GetBalance(p)) or 0,
                    ach = achDone, achTotal = achTotal,
                }
            end
        end
        table.sort(out, function(a, b) return a.nick:lower() < b.nick:lower() end)
        return out
    end

    local function pushTab(ply, tab)
        local payload = {}
        if tab == "server" then payload = payloadServer()
        elseif tab == "access" then payload = payloadAccess()
        elseif tab == "jobs" then payload = payloadJobs()
        elseif tab == "players" then payload = payloadPlayers()
        else tab = "server" payload = payloadServer() end
        net.Start(NET_DATA)
            net.WriteString(tab)
            net.WriteTable(payload)
        net.Send(ply)
    end

    net.Receive(NET_GET, function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        pushTab(ply, tostring(net.ReadString() or "server"))
    end)

    net.Receive(NET_ACT, function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        local act = tostring(net.ReadString() or "")
        local args = net.ReadTable() or {}
        local msg = nil

        if act == "accSet" then
            local kind, fac, allow = tostring(args.kind or ""), tostring(args.fac or ""), args.allow == true
            if not (istable(Factions) and istable(Factions[fac])) then msg = "Фракция не найдена"
            elseif kind == "board" and GRM.Board and GRM.Board.Cfg then
                GRM.Board.Cfg.allow[fac] = allow and true or nil
                if not allow then GRM.Board.Cfg.open[fac] = nil end
                GRM.Board.SaveCfg()
                msg = "ДОСКА «" .. fac .. "»: " .. (allow and "ВЫДАН" or "ОТОЗВАН")
            elseif (kind == "journ" or kind == "alert") and GRM.Broadcast and GRM.Broadcast.Cfg then
                accTable(kind)[fac] = allow and true or nil
                GRM.Broadcast.SaveCfg()
                msg = (kind == "journ" and "ЭФИР «" or "ОПОВЕЩ. «") .. fac .. "»: " .. (allow and "ВЫДАН" or "ОТОЗВАН")
            elseif kind == "jobs" and GRM.Jobs and GRM.Jobs.Cfg then
                GRM.Jobs.Cfg.allow[fac] = allow and true or nil
                GRM.Jobs.SaveCfg("hub: БИРЖА " .. fac)
                msg = "БИРЖА «" .. fac .. "»: " .. (allow and "ВЫДАН" or "ОТОЗВАН")
            else msg = "Канал недоступен" end
            if IsValid(ply) then ply:PrintMessage(HUD_PRINTTALK, "[Хаб] " .. tostring(msg)) end
            pushTab(ply, "access")
        elseif act == "jobFail" then
            if GRM.Jobs and GRM.Jobs.Fail then
                local sid = tostring(args.sid or "")
                local target = nil
                for _, p in ipairs(player.GetAll()) do
                    if IsValid(p) and (p:SteamID64() == sid or p:SteamID() == sid) then target = p break end
                end
                if IsValid(target) then GRM.Jobs.Fail(target, "снято администратором") else GRM.Jobs.Fail(sid, "снято администратором") end
                ply:PrintMessage(HUD_PRINTTALK, "[Хаб] Задача снята: " .. sid)
            end
            pushTab(ply, "jobs")
        elseif act == "postDel" then
            local fac, id = tostring(args.fac or ""), tostring(args.id or "")
            local done, refund = false, 0
            if GRM.Jobs and istable(GRM.Jobs.Cfg) and istable(GRM.Jobs.Cfg.posts[fac]) then
                local list = GRM.Jobs.Cfg.posts[fac]
                for i, p in ipairs(list) do
                    if tostring(p.id) == id then
                        if p.takenBy ~= nil then
                            -- исполнитель в пути: проваливаем (многоразовая вакансия при этом ОСТАНЕТСЯ
                            -- на витрине со снятой бронью — урок фикса Кода 77 v1.1.0)
                            for _, pl in ipairs(player.GetAll()) do
                                if IsValid(pl) then
                                    local j = GRM.Jobs.Active and GRM.Jobs.Active[pl:SteamID64() or pl:SteamID()]
                                    if istable(j) and j.fromPost and tostring(j.postId) == tostring(p.id) then
                                        GRM.Jobs.Fail(pl, "публикация удалена админом")
                                    end
                                end
                            end
                        end
                        -- пост ещё на витрине? вернуть остаток эскроу и снять окончательно
                        local idx = nil
                        for k, q in ipairs(list) do if tostring(q.id) == id then idx = k break end end
                        if idx then
                            refund = (GRM.Jobs.PostEscrow and GRM.Jobs.PostEscrow(p)) or 0
                            if refund > 0 and GRM.FactionBudgetAdd then GRM.FactionBudgetAdd(fac, refund, "Хаб: публикация удалена") end
                            table.remove(list, idx)
                            GRM.Jobs.SaveCfg("hub: удаление поста")
                        end
                        done = true
                        break
                    end
                end
            end
            ply:PrintMessage(HUD_PRINTTALK, "[Хаб] Публикация " .. (done and ("удалена" .. (refund > 0 and (", остаток эскроу " .. refund .. " возвращён") or "")) or "не найдена") .. ": " .. fac .. " #" .. id)
            pushTab(ply, "jobs")
        elseif act == "achReset" then
            if GRM.Ach and GRM.Ach.AdminReset then
                GRM.Ach.AdminReset(tostring(args.sid or ""))
                for _, p in ipairs(player.GetAll()) do
                    if IsValid(p) and (p:SteamID64() == tostring(args.sid or "") or p:SteamID() == tostring(args.sid or "")) then
                        if GRM.Notify then GRM.Notify(p, "Ваш прогресс ачивок сброшен администрацией.", 255, 130, 110) end
                    end
                end
                ply:PrintMessage(HUD_PRINTTALK, "[Хаб] Ачивки сброшены: " .. tostring(args.sid))
            end
            pushTab(ply, "players")
        end
    end)

    local function openHub(ply)
        if not IsValid(ply) then return false end
        if not ply:IsSuperAdmin() then
            ply:PrintMessage(HUD_PRINTTALK, "[Хаб] Единая админ-панель — только суперадмин.")
            return true
        end
        net.Start(NET_OPEN)
        net.Send(ply)
        return true
    end
    concommand.Add("grm_admin", function(ply) openHub(ply) end)

    hook.Add("PlayerSayTransform", "GRM_Hub_TransformCmds", function(ply, datapack)
        if not istable(datapack) then return end
        local msg = datapack[1]
        if not isstring(msg) then return end
        -- алиас "/admin" сознательно НЕ занимаем: его могут использовать внешние аддоны
        if string.lower(string.Trim(msg)) == "/grm_admin" then
            if openHub(ply) then
                datapack[1] = ""
                datapack.SkipPlayerSay = true
            end
        end
    end)
    hook.Add("PlayerSay", "GRM_Hub_ChatCmds", function(ply, text)
        if string.lower(string.Trim(tostring(text or ""))) == "/grm_admin" then
            if openHub(ply) then return "" end
        end
    end)

    print("[GRM Hub] Единая админ-панель v" .. HB.Version .. " загружена (Код 79): /grm_admin")
end

-- ============================================================
-- КЛИЕНТ
-- ============================================================
if CLIENT then
    surface.CreateFont("GRMHub_Title",  { font = "Roboto", size = 20, weight = 800, extended = true })
    surface.CreateFont("GRMHub_Sub",    { font = "Roboto", size = 15, weight = 600, extended = true })
    surface.CreateFont("GRMHub_Normal", { font = "Roboto", size = 13, weight = 500, extended = true })
    surface.CreateFont("GRMHub_Small",  { font = "Roboto", size = 12, weight = 500, extended = true })

    local C = {
        bg    = Color(24, 28, 38, 240),
        head  = Color(18, 22, 30, 255),
        panel = Color(32, 38, 50, 245),
        panel2= Color(26, 32, 42, 235),
        acc   = Color(70, 150, 240),
        green = Color(60, 190, 110),
        red   = Color(220, 75, 70),
        yellow= Color(230, 180, 60),
        teal  = Color(80, 200, 170),
        text  = Color(240, 245, 250),
        dim   = Color(170, 180, 195),
    }

    local function fmtMoney(n) return GRM.Format and GRM.Format(n) or (tostring(n) .. " GRM") end
    local function fmtTime(s)
        s = math.max(0, math.floor(tonumber(s) or 0))
        return string.format("%d:%02d:%02d", math.floor(s / 3600), math.floor((s % 3600) / 60), s % 60)
    end

    local function mkBtn(p, txt, col, w, h)
        local b = vgui.Create("DButton", p)
        b:SetText(txt) b:SetFont("GRMHub_Normal") b:SetTextColor(color_white)
        if w and h then b:SetSize(w, h) end
        b.Paint = function(self, pw, ph)
            local cc = col or C.acc
            if self:IsHovered() then cc = Color(math.min(255, cc.r + 25), math.min(255, cc.g + 25), math.min(255, cc.b + 25)) end
            draw.RoundedBox(5, 0, 0, pw, ph, cc)
        end
        return b
    end

    local function askTab(tab)
        net.Start(NET_GET)
            net.WriteString(tab)
        net.SendToServer()
    end
    local function act(action, args)
        net.Start(NET_ACT)
            net.WriteString(action)
            net.WriteTable(args or {})
        net.SendToServer()
    end

    local function block(sc, h, title, accent)
        local b = vgui.Create("DPanel", sc)
        b:Dock(TOP) b:SetTall(h) b:DockMargin(0, 0, 0, 6)
        b.Paint = function(_, pw, ph)
            draw.RoundedBox(6, 0, 0, pw, ph, C.panel)
            draw.SimpleText(title, "GRMHub_Sub", 10, 13, accent or C.acc, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        return b
    end

    -- ==== вкладка СЕРВЕР ====
    local function buildServer(sc, d)
        sc:Clear()
        local b1 = block(sc, 78, "Сервер:", C.acc)
        local l = vgui.Create("DLabel", b1)
        l:SetPos(12, 26) l:SetSize(900, 46) l:SetFont("GRMHub_Normal") l:SetTextColor(C.text)
        l:SetText("Онлайн: " .. tostring(d.online or 0) .. "    Карта: " .. tostring(d.map or "?") .. "    Аптайм сессии: " .. fmtTime(d.uptime or 0) ..
            "\nПанель: /grm_admin • аудит протоколов: tools/proto_audit.py • версии модулей ниже")
        l:SetWrap(true) l:SetAutoStretchVertical(true)

        local cnt = istable(d.counters) and d.counters or {}
        local b2 = block(sc, 30 + #cnt * 22 + 8, "Счётчики сборки:", C.yellow)
        for i, cRow in ipairs(cnt) do
            local r = vgui.Create("DLabel", b2)
            r:SetPos(12, 24 + (i - 1) * 22) r:SetSize(600, 20) r:SetFont("GRMHub_Normal")
            r:SetTextColor(C.text) r:SetText(tostring(cRow.name) .. ": " .. tostring(cRow.val))
        end

        local vers = istable(d.versions) and d.versions or {}
        local b3 = block(sc, 30 + #vers * 22 + 8, "Версии модулей:", C.teal)
        for i, v in ipairs(vers) do
            local r = vgui.Create("DLabel", b3)
            r:SetPos(12, 24 + (i - 1) * 22) r:SetSize(600, 20) r:SetFont("GRMHub_Normal")
            r:SetTextColor(C.text) r:SetText(tostring(v.name) .. " — v" .. tostring(v.ver))
        end

        local fs = istable(d.factions) and d.factions or {}
        local b4 = block(sc, 30 + math.max(1, #fs) * 24 + 8, "Фракции (" .. tostring(#fs) .. "):", C.green)
        if #fs == 0 then
            local r = vgui.Create("DLabel", b4)
            r:SetPos(12, 28) r:SetSize(880, 20) r:SetFont("GRMHub_Normal") r:SetTextColor(C.dim)
            r:SetText("Фракций нет. Создание: /factions → вкладка «Создать».")
        end
        for i, f in ipairs(fs) do
            local r = vgui.Create("DLabel", b4)
            r:SetPos(12, 26 + (i - 1) * 24) r:SetSize(900, 22) r:SetFont("GRMHub_Normal") r:SetTextColor(C.text)
            r:SetText(tostring(f.name) .. "   •   лидер: " .. tostring(f.leader) .. "   •   состав: " .. tostring(f.members))
        end
    end

    -- ==== вкладка ДОСТУПЫ ====
    local function buildAccess(sc, d)
        sc:Clear()
        local fs = istable(d.factions) and d.factions or {}
        local note = vgui.Create("DLabel", sc)
        note:Dock(TOP) note:SetTall(34) note:SetFont("GRMHub_Small") note:SetTextColor(C.dim)
        note:SetText("Те же хранилища, что /factions → «Доступы» и /board_allow /bcast_allow /alert_allow /job_allow. Суперадмин может всё без галочек.")
        note:SetWrap(true) note:SetAutoStretchVertical(true)

        local head = vgui.Create("DPanel", sc)
        head:Dock(TOP) head:SetTall(24) head:SetPaintBackground(false)
        local function hl(x, t, col)
            local l = vgui.Create("DLabel", head)
            l:SetPos(x, 1) l:SetSize(150, 22) l:SetFont("GRMHub_Sub") l:SetTextColor(col) l:SetText(t)
        end
        hl(10, "Фракция", C.dim) hl(370, "Доска", C.teal) hl(520, "Эфир", C.acc) hl(670, "Оповещ.", C.red) hl(820, "Биржа", C.yellow)

        for _, f in ipairs(fs) do
            local row = vgui.Create("DPanel", sc)
            row:Dock(TOP) row:SetTall(28) row:DockMargin(0, 0, 0, 2)
            row.Paint = function(_, pw, ph) draw.RoundedBox(4, 0, 0, pw, ph, C.panel2) end
            local name = tostring(f.name)
            local nl = vgui.Create("DLabel", row)
            nl:SetPos(10, 3) nl:SetSize(350, 22) nl:SetFont("GRMHub_Normal") nl:SetTextColor(C.text) nl:SetText(name)
            local function chk(x, tbl, kind, col)
                local c = vgui.Create("DCheckBoxLabel", row)
                c:SetPos(x, 3) c:SetSize(140, 22)
                local cur = istable(tbl) and tbl[name] == true
                c:SetText(cur and "выдан" or "нет")
                c:SetFont("GRMHub_Normal") c:SetTextColor(cur and col or C.dim)
                c:SetValue(cur and 1 or 0)
                c.OnChange = function(_, v)
                    act("accSet", { kind = kind, fac = name, allow = v and true or false })
                    c:SetText(v and "выдан" or "нет")
                    c:SetTextColor(v and col or C.dim)
                end
            end
            chk(370, d.board, "board", C.teal)
            chk(520, d.journ, "journ", C.acc)
            chk(670, d.alert, "alert", C.red)
            chk(820, d.jobs, "jobs", C.yellow)
        end
        if #fs == 0 then
            local r = vgui.Create("DLabel", sc)
            r:Dock(TOP) r:SetTall(26) r:SetFont("GRMHub_Normal") r:SetTextColor(C.dim)
            r:SetText("Фракций нет — галочки появятся после создания первой.")
        end
    end

    -- ==== вкладка БИРЖА ====
    local function buildJobs(sc, d)
        sc:Clear()
        local active = istable(d.active) and d.active or {}
        local b1 = block(sc, 30 + math.max(1, #active) * 30 + 8, "Активные задачи игроков (" .. tostring(#active) .. "):", C.yellow)
        if #active == 0 then
            local r = vgui.Create("DLabel", b1)
            r:SetPos(12, 28) r:SetSize(880, 20) r:SetFont("GRMHub_Normal") r:SetTextColor(C.dim)
            r:SetText("Активных задач нет.")
        end
        for i, j in ipairs(active) do
            local row = vgui.Create("DPanel", b1)
            row:SetPos(8, 26 + (i - 1) * 30) row:SetSize(930, 28)
            row.Paint = function(_, pw, ph)
                draw.RoundedBox(4, 0, 0, pw, ph, C.panel2)
                draw.SimpleText(tostring(j.title) .. "  (" .. tostring(j.jtype) .. ")", "GRMHub_Normal", 8, ph / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                local left = string.format("%d:%02d", math.floor((tonumber(j.remain) or 0) / 60), (tonumber(j.remain) or 0) % 60)
                local extra = ((tonumber(j.stayLeft) or 0) > 0) and (" • в зоне " .. tostring(j.stayLeft) .. " с") or ""
                draw.SimpleText(tostring(j.sid) .. " • " .. left .. extra .. " • " .. fmtMoney(j.reward or 0), "GRMHub_Small", 8, ph / 2 + 7, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            local bFail = mkBtn(row, "Провалить", C.red, 90, 22)
            bFail:SetPos(830, 3)
            bFail.DoClick = function() act("jobFail", { sid = j.sid }) end
        end

        local posts = istable(d.posts) and d.posts or {}
        local b2 = block(sc, 30 + math.max(1, #posts) * 30 + 8, "Публикации фракций — заказы и вакансии (" .. tostring(#posts) .. "):", C.teal)
        if #posts == 0 then
            local r = vgui.Create("DLabel", b2)
            r:SetPos(12, 28) r:SetSize(880, 20) r:SetFont("GRMHub_Normal") r:SetTextColor(C.dim)
            r:SetText("Публикаций нет.")
        end
        for i, p in ipairs(posts) do
            local row = vgui.Create("DPanel", b2)
            row:SetPos(8, 26 + (i - 1) * 30) row:SetSize(930, 28)
            row.Paint = function(_, pw, ph)
                draw.RoundedBox(4, 0, 0, pw, ph, C.panel2)
                draw.SimpleText((p.kind == "vacancy" and "ВАКАНСИЯ «" or "заказ «") .. tostring(p.title) .. "» — " .. tostring(p.fac), "GRMHub_Normal", 8, ph / 2, p.kind == "vacancy" and C.green or C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                local extra = (p.kind == "vacancy") and (" • смен осталось: " .. tostring(p.shiftsLeft or 0)) or ""
                draw.SimpleText("эскроу: " .. fmtMoney(p.escrow or 0) .. extra .. (p.taken and " • ВЗЯТ" or " • свободен"), "GRMHub_Small", 8, ph / 2 + 7, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            local bDel = mkBtn(row, "Удалить", C.red, 90, 22)
            bDel:SetPos(830, 3)
            bDel.DoClick = function()
                Derma_Query("Удалить публикацию «" .. tostring(p.title) .. "» (" .. tostring(p.fac) .. ")?\nСвободное эскроу вернётся в бюджет.",
                    "Хаб • Биржа", "Удалить", function() act("postDel", { fac = p.fac, id = p.id }) end, "Отмена", function() end)
            end
        end
    end

    -- ==== вкладка ИГРОКИ ====
    local function buildPlayers(sc, d)
        sc:Clear()
        local list = istable(d) and d or {}
        local b1 = block(sc, 30 + math.max(1, #list) * 32 + 8, "Онлайн (" .. tostring(#list) .. "):", C.acc)
        for i, p in ipairs(list) do
            local row = vgui.Create("DPanel", b1)
            row:SetPos(8, 26 + (i - 1) * 32) row:SetSize(930, 30)
            row.Paint = function(_, pw, ph)
                draw.RoundedBox(4, 0, 0, pw, ph, C.panel2)
                local nm = tostring(p.nick)
                if p.rp ~= "" and p.rp ~= p.nick then nm = tostring(p.rp) .. "  (Steam: " .. tostring(p.nick) .. ")" end
                draw.SimpleText(nm, "GRMHub_Normal", 8, ph / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(tostring(p.sid) .. " • " .. fmtMoney(p.bal or 0) .. " • ачивки " .. tostring(p.ach or 0) .. "/" .. tostring(p.achTotal or 0),
                    "GRMHub_Small", 8, ph / 2 + 8, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            local bCopy = mkBtn(row, "SteamID", C.acc, 80, 22)
            bCopy:SetPos(650, 4)
            bCopy.DoClick = function()
                SetClipboardText(tostring(p.sid))
                surface.PlaySound("buttons/button9.wav")
            end
            local bReset = mkBtn(row, "Сброс ачивок", C.red, 130, 22)
            bReset:SetPos(738, 4)
            bReset.DoClick = function()
                Derma_Query("Сбросить ВЕСЬ прогресс ачивок игрока " .. tostring(p.nick) .. " (" .. tostring(p.sid) .. ")?",
                    "Хаб • Игроки", "Сбросить", function() act("achReset", { sid = p.sid }) end, "Отмена", function() end)
            end
        end
        if #list == 0 then
            local r = vgui.Create("DLabel", b1)
            r:SetPos(12, 28) r:SetSize(880, 20) r:SetFont("GRMHub_Normal") r:SetTextColor(C.dim)
            r:SetText("Никого нет в сети.")
        end
    end

    -- ==== вкладка МЕНЮ (ярлыки) ====
    -- m[1] название, m[2] команда, m[3] подсказка, m[4]==true → только подпись (без нажатия)
    local MENU_LINKS = {
        { "Фракции (админ)", "/factions", "Создание, лидеры, роли, доступы, двери и ордера" },
        { "Экономика GRM", "!grmmenu", "Балансы, бюджеты, налоги, переводы, журнал" },
        { "Доступ к дверям", "/door_access", "Матрица доступов дверей, категории и фракции" },
        { "Модели фракций", "/models_admin", "Фракционные модели и превью" },
        { "Оружие фракций", "/weapons_admin", "Выдача оружия по фракциям" },
        { "Маски", "/mask_admin", "Настройки масок" },
        { "Зарплаты", "/salary_admin", "Ставки ЗП фракций" },
        { "Логистика", "/logistics_admin", "Склады и логистика фракций" },
        { "Магазин транспорта", "/vshop_admin", "Цены доступа к транспорту" },
        { "Скан транспорта", "/scanvehicles", "Все машины на карте" },
        { "Магазин телефонов", "/phoneshop_admin", "Доступ к телефонам/АТС" },
        { "Телефонный доступ", "/phone_access", "Кто пользуется телефонией" },
        { "Ордера", "/warrants", "Активные ордера на обыск" },
        { "Каналы эфира/оповещения", "/bcasters", "Печать в чат: фракции с доступами эфира и оповещения" },
        { "Оповещение: синтаксис", "/alert", "Сервер ответит подсказкой: /alert текст (район) или /alertall текст (весь город)" },
        { "Спавн транспорта (ТАБ)", "ТАБ → игрок", "ТАБ → клик по игроку → «Спавн транспорта»: у ближайшего дилера, без цены/лимита", true },
    }
    local function buildMenu(sc)
        sc:Clear()
        local b1 = block(sc, 30 + #MENU_LINKS * 36 + 8, "Быстрый запуск админ-меню сборки:", C.yellow)
        for i, m in ipairs(MENU_LINKS) do
            local row = vgui.Create("DPanel", b1)
            row:SetPos(8, 26 + (i - 1) * 36) row:SetSize(930, 32)
            row.Paint = function(_, pw, ph)
                draw.RoundedBox(4, 0, 0, pw, ph, C.panel2)
                draw.SimpleText(m[1], "GRMHub_Sub", 8, ph / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(m[3], "GRMHub_Small", pw - 8, ph / 2, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
            end
            local b = mkBtn(row, m[2], m[4] and C.panel or C.green, 200, 24)
            b:SetPos(430, 4)
            if not m[4] then
                local cmd = m[2]
                b.DoClick = function()
                    LocalPlayer():ConCommand("say " .. cmd)
                    chat.AddText(C.acc, "[Хаб] ", C.text, "Запуск: ", C.green, cmd)
                end
            end
        end
    end

    -- ==== главное окно ====
    net.Receive(NET_OPEN, function()
        if IsValid(HB._frame) then HB._frame:Remove() end
        local f = vgui.Create("DFrame")
        HB._frame = f
        f:SetTitle("")
        f:SetSize(1000, 660)
        f:Center()
        f:MakePopup()
        f:ShowCloseButton(false)
        f.Paint = function(_, pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, C.bg)
            draw.RoundedBoxEx(8, 0, 0, pw, 46, C.head, true, true, false, false)
            draw.SimpleText("GRM — Единая админ-панель", "GRMHub_Title", 14, 23, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("v" .. HB.Version .. " • /grm_admin", "GRMHub_Normal", pw - 52, 23, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        local x = vgui.Create("DButton", f)
        x:SetText("X") x:SetFont("GRMHub_Title") x:SetTextColor(color_white)
        x:SetPos(952, 8) x:SetSize(32, 30)
        x.DoClick = function() f:Close() end
        x.Paint = function(self, pw, ph) draw.RoundedBox(4, 0, 0, pw, ph, self:IsHovered() and C.red or Color(45, 52, 68)) end

        local sheet = vgui.Create("DPropertySheet", f)
        sheet:Dock(FILL) sheet:DockMargin(10, 52, 10, 10)

        local pages = {}
        local function mkPage(tab, label, icon)
            local p = vgui.Create("DPanel")
            p:SetPaintBackground(false)
            p:DockPadding(6, 6, 6, 6)
            local sc = vgui.Create("DScrollPanel", p)
            sc:Dock(FILL) sc:DockMargin(0, 0, 0, 34)
            local bRef = mkBtn(p, "Обновить", C.acc)
            bRef:Dock(BOTTOM) bRef:SetTall(28) bRef:SetFont("GRMHub_Sub")
            bRef.DoClick = function() askTab(tab) end
            pages[tab] = sc
            sheet:AddSheet(label, p, icon)
            return sc
        end

        mkPage("server", "Сервер", "icon16/server.png")
        mkPage("access", "Доступы", "icon16/key.png")
        mkPage("jobs", "Биржа", "icon16/bricks.png")
        mkPage("players", "Игроки", "icon16/group.png")
        mkPage("menu", "Меню", "icon16/application_view_tile.png")

        HB._activeTab = "server"
        sheet.OnActiveTabChanged = function(_, _, newPnl)
            for tab, sc in pairs(pages) do
                if IsValid(sc) and sc:GetParent() == newPnl then HB._activeTab = tab askTab(tab) end
            end
        end

        net.Receive(NET_DATA, function()
            if not IsValid(f) then return end
            local tab = net.ReadString()
            local d = net.ReadTable() or {}
            local sc = pages[tab]
            if not IsValid(sc) then return end
            if tab == "server" then buildServer(sc, d)
            elseif tab == "access" then buildAccess(sc, d)
            elseif tab == "jobs" then buildJobs(sc, d)
            elseif tab == "players" then buildPlayers(sc, d) end
        end)

        buildMenu(pages["menu"])
        timer.Simple(0.15, function() if IsValid(f) then askTab("server") end end)
    end)

    print("[GRM Hub] Клиент единой админ-панели v" .. HB.Version .. " загружен")
end
