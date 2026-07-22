--[[--------------------------------------------------------------------
    GRM Context Menu — единое контекстное меню (server + client)
--------------------------------------------------------------------]]

if SERVER then
    AddCSLuaFile()
    util.AddNetworkString("GRM_Ctx_Check")
    util.AddNetworkString("GRM_Ctx_Result")
    util.AddNetworkString("GRM_Ctx_VehAct")
    util.AddNetworkString("GRM_Ctx_MoneyAct")
    util.AddNetworkString("GRM_Ctx_Action")
    util.AddNetworkString("GRM_Laws_Open")
    util.AddNetworkString("Factions_OpenAdminMenu")
    util.AddNetworkString("Factions_OpenLeaderMenu")

    -- Игрок в прицеле (для кнопки «Передать деньги»)
    local function aimPlyInfo(ply)
        -- pcall: в нетиповых средах (тестовые стенды) плейер может не иметь GetEyeTrace
        local ok, tr = pcall(function() return ply:GetEyeTrace() end)
        if not ok or not istable(tr) then return nil end
        local t = tr.Entity
        if IsValid(t) and t:IsPlayer() and t ~= ply
            and t:GetPos():DistToSqr(ply:GetPos()) <= 300 * 300 then
            return { name = t:Nick(), idx = t:EntIndex() }
        end
        return nil
    end

    local function getPlayerFaction(ply)
        if not Factions then return nil, nil end
        local sid = ply:SteamID()
        local s64 = ply:SteamID64()
        local ck = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(ply)) or s64
        for name, f in pairs(Factions) do
            if istable(f) and istable(f.Members) and (f.Members[ck] or f.Members[sid] or f.Members[s64]) then
                return name, f
            end
        end
        return nil, nil
    end

    local function openFactionsMenu(ply)
        if not IsValid(ply) then return end
        if ply:IsSuperAdmin() then
            net.Start("Factions_OpenAdminMenu")
            net.Send(ply)
            return
        end

        local sid, sid64 = ply:SteamID(), ply:SteamID64()
        local ck = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(ply)) or sid64
        local isLeader = false
        for _, f in pairs(Factions or {}) do
            if istable(f) and (f.Leader == ck or f.Leader == sid or f.Leader == sid64) then
                isLeader = true
                break
            end
        end

        if isLeader then
            net.Start("Factions_OpenLeaderMenu")
            net.Send(ply)
        else
            ply:PrintMessage(HUD_PRINTTALK, "[Фракции] У вас нет прав для использования этого меню.")
        end
    end

    -- Транспорт в прицеле (Код 82): имя/замок/права для кнопок меню
    local function vehInfo(ply)
        if not (_G.VK and VK.IsVehicle) then return nil end
        local veh = nil
        if VK.GetAimedVehicle then veh = VK.GetAimedVehicle(ply, 240) end
        if not (IsValid(veh) and VK.IsVehicle(veh)) then return nil end
        local canManage = (VK.CanInteract and VK.CanInteract(veh, ply, true)) or ply:IsSuperAdmin()
        local canUse = (VK.CanInteract and VK.CanInteract(veh, ply, false)) or ply:IsSuperAdmin()
        local mineStrict = (veh.VD_Owner == ply)
            or (veh.VK_OwnerType == "player" and veh.VK_OwnerSteam == ((GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(ply)) or ply:SteamID()))
        local mine = mineStrict or ply:IsSuperAdmin()
        local tracked = (VD_AllVehicles and VD_AllVehicles[veh:EntIndex()] ~= nil)
            or veh.VD_Owner ~= nil or veh.VD_ID ~= nil
        local price = tonumber(veh.VD_Price) or 0
        return {
            name = (VK.GetVehicleDisplayName and VK.GetVehicleDisplayName(veh)) or veh:GetClass(),
            locked = veh.VK_Locked == true or veh:GetNW2Bool("VK_Locked", false),
            canManage = canManage == true,   -- владелец/ключи/суперадмин → замок
            canUse = canUse == true,         -- член фракции/ключи → багажник (дальше решит TK.CanAccess)
            canRemove = mine and tracked,    -- только Т/С дилера у своего владельца; суперадмин — любое дилерское
            refund = (mineStrict and price > 0) and math.floor(price * 0.5) or 0, -- подпись кнопки (2.1)
        }
    end

    net.Receive("GRM_Ctx_Check", function(_, ply)
        if not IsValid(ply) then return end
        local result = {}
        local factionName, faction = getPlayerFaction(ply)
        result.isFactionMember = (factionName ~= nil)
        local ck = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(ply)) or ply:SteamID64()
        result.isLeaderOrAdmin = (faction and (faction.Leader == ck or faction.Leader == ply:SteamID() or faction.Leader == ply:SteamID64())) or ply:IsSuperAdmin()
        result.factionName = factionName or ""
        result.veh = vehInfo(ply)
        result.aimPly = aimPlyInfo(ply)
        result.hasMaskAccess = false
        if factionName and FactionsExt and FactionsExt[factionName] then
            local cfg = FactionsExt[factionName]
            local member = faction and (faction.Members[ck] or faction.Members[ply:SteamID()] or faction.Members[ply:SteamID64()])
            if member and cfg.MaskDepartments then
                for _, dept in pairs(cfg.MaskDepartments) do
                    if istable(dept.Roles) then
                        for _, role in ipairs(dept.Roles) do
                            if role == member.Role then
                                result.hasMaskAccess = true
                                break
                            end
                        end
                    end
                    if result.hasMaskAccess then break end
                end
            end
        end
        net.Start("GRM_Ctx_Result")
            net.WriteTable(result)
        net.Send(ply)
    end)

    net.Receive("GRM_Ctx_Action", function(_, ply)
        if not IsValid(ply) then return end
        local action = tostring(net.ReadString() or "")
        if action == "factions" then
            openFactionsMenu(ply)
            return
        end
    end)

    -- ── Действия с транспортом из контекст-меню (Код 82) ──────
    net.Receive("GRM_Ctx_VehAct", function(_, ply)
        if not IsValid(ply) then return end
        local doAct = tostring(net.ReadString() or "")
        if not (_G.VK and VK.IsVehicle and VK.GetAimedVehicle) then return end
        local veh = VK.GetAimedVehicle(ply, 260)
        if not (IsValid(veh) and VK.IsVehicle(veh)) then return end

        -- «Замок»: владелец/ключи/суперадмин
        if doAct == "lock" then
            local canManage = (VK.CanInteract and VK.CanInteract(veh, ply, true)) or ply:IsSuperAdmin()
            if not canManage then
                if GRM.Notify then GRM.Notify(ply, "Нет доступа к замку (нужен ключ)", 255, 120, 110) end
                return
            end
            veh.VK_Locked = not (veh.VK_Locked == true)
            if VK.SyncVehicle then VK.SyncVehicle(veh) end
            veh:EmitSound(veh.VK_Locked and "doors/door_latch3.wav" or "doors/door_latch1.wav")
            if GRM.Notify then
                GRM.Notify(ply, veh.VK_Locked and "Транспорт ЗАКРЫТ" or "Транспорт ОТКРЫТ", 120, 200, 255)
            end
            return
        end

        -- «Багажник»: делегируем модулю багажника (сам решит доступ)
        if doAct == "trunk" then
            if GRM.Trunk and GRM.Trunk.RequestToggle then
                GRM.Trunk.RequestToggle(ply)
            elseif GRM.Notify then
                GRM.Notify(ply, "Модуль багажника не загружен", 255, 140, 120)
            end
            return
        end

        -- «Убрать Т/С» (Диллер 2.1): ЕДИНАЯ точка удаления с меню дилера —
        -- одинаковые права, возврат 50%, чистка реестра, синк «Мои Т/С».
        if doAct == "remove" then
            local removeFn = _G.VD_RemoveDealerVehicle
            if not removeFn then
                if GRM.Notify then GRM.Notify(ply, "Модуль авто-дилера не загружен", 255, 140, 120) end
                return
            end
            local ok, msg = removeFn(ply, veh, { maxDist = 400 })
            if GRM.Notify then
                if ok then GRM.Notify(ply, tostring(msg or "Готово"), 140, 230, 150)
                else GRM.Notify(ply, tostring(msg or "Отказ"), 255, 140, 120) end
            end
            return
        end
    end)

    -- ── Передача денег из контекст-меню (Код 85.2) ─────────────
    -- Выброс пачки идёт клиентской командой /dropmoney (вся логика на месте).
    local lastGive = {}
    net.Receive("GRM_Ctx_MoneyAct", function(_, ply)
        if not IsValid(ply) then return end
        local op = tostring(net.ReadString() or "")
        if op ~= "give" then return end
        local target = net.ReadEntity()
        local amount = math.floor(net.ReadUInt(32))
        local now = CurTime()
        if lastGive[ply] and now - lastGive[ply] < 0.8 then return end -- антифлуд
        lastGive[ply] = now
        if not (IsValid(target) and target:IsPlayer() and target ~= ply) then
            if GRM.Notify then GRM.Notify(ply, "Игрок не найден.", 255, 140, 120) end
            return
        end
        if target:GetPos():DistToSqr(ply:GetPos()) > 300 * 300 then
            if GRM.Notify then GRM.Notify(ply, "Слишком далеко — подойдите ближе (до 300 юнитов).", 255, 140, 120) end
            return
        end
        if amount <= 0 then return end
        if not (GRM.TakeMoney and GRM.GiveMoney and GRM.GetBalance) then return end
        if GRM.GetBalance(ply) < amount then
            if GRM.Notify then GRM.Notify(ply, "Не хватает наличных (есть " .. tostring(GRM.GetBalance(ply)) .. ").", 255, 140, 120) end
            return
        end
        GRM.TakeMoney(ply, amount, "Передача наличных: " .. target:Nick())
        GRM.GiveMoney(target, amount, "Передача наличных от " .. ply:Nick())
        if GRM.Notify then
            GRM.Notify(ply, "Передано " .. tostring(amount) .. " → " .. target:Nick(), 120, 220, 140)
            GRM.Notify(target, "Вам передали " .. tostring(amount) .. " (от " .. ply:Nick() .. ")", 120, 220, 140)
        end
    end)

    print("[GRM CTX] Server loaded (v3: +передача денег в C-меню)")
end

if CLIENT then

local MENU_Y = 300

surface.CreateFont("GRMCtx_Normal", { font = "Roboto", size = 13, weight = 500, extended = true })

local CC = {
    ticket  = Color(180, 100, 60),  ticketH  = Color(200, 120, 80),
    inv     = Color(50, 120, 200),  invH     = Color(70, 140, 220),
    third   = Color(100, 100, 180), thirdH   = Color(120, 120, 200),
    radio   = Color(180, 160, 60),  radioH   = Color(200, 180, 80),
    faction = Color(80, 80, 180),   factionH = Color(100, 100, 200),
    mask    = Color(140, 80, 160),  maskH    = Color(160, 100, 180),
}
local BG   = Color(14, 16, 22, 230)
local BORD = Color(40, 45, 65, 180)

local visible = false
local wasDown = false
local cooldowns = {}
local armed = { id = nil, untilT = 0 } -- двойное нажатие для опасных кнопок (confirm)
local data = {}
local tp = false

local function actTicket()    RunConsoleCommand("grm_ticket") end
local function actInv()       RunConsoleCommand("grm_inventory") end
local function actTp()
    tp = not tp
    RunConsoleCommand("simple_thirdperson_enable_toggle")
end
local function actRadio()
    Derma_StringRequest("Рация", "Частота (1-999.9) или пусто = отключиться:", "",
        function(v)
            if v and v ~= "" then RunConsoleCommand("say", "/freq " .. v)
            else RunConsoleCommand("say", "/freqleave") end
        end)
end

local function actLaws()
    net.Start("GRM_Laws_Open")
    net.SendToServer()
end
local function actFactions()
    net.Start("GRM_Ctx_Action")
        net.WriteString("factions")
    net.SendToServer()
end
local function actMask()      RunConsoleCommand("say", "/mask") end

-- Деньги в C-меню (по заказу: «выбросить деньги / передать деньги игроку»)
local function actDropMoney()
    Derma_StringRequest("Выбросить наличные", "Сумма (пачка упадёт перед вами):", "",
        function(v)
            local n = math.floor(tonumber(v) or 0)
            if n > 0 then RunConsoleCommand("say", "/dropmoney " .. tostring(n)) end
        end)
end
local function actGiveMoney()
    local ap = istable(data.aimPly) and data.aimPly or nil
    Derma_StringRequest("Передать наличные", "Сумма для передачи " .. (ap and ("(" .. tostring(ap.name) .. ")") or "игроку") .. ":", "",
        function(v)
            local n = math.floor(tonumber(v) or 0)
            if n <= 0 or not ap then return end
            net.Start("GRM_Ctx_MoneyAct")
                net.WriteString("give")
                net.WriteEntity(Entity(ap.idx or 0))
                net.WriteUInt(n, 32)
            net.SendToServer()
        end)
end

-- Транспорт рядом (Код 82): сервер сам перепроверит прицел и права
-- fg: req объявлена форвардом — vehAct вызывает её из замыкания (иначе была бы
-- ссылка на ГЛОБАЛЬНЫЙ req=nil → timer.Simple(function expected, got nil), 18.07.2026)
local req
local function vehAct(what)
    return function()
        net.Start("GRM_Ctx_VehAct")
            net.WriteString(what)
        net.SendToServer()
        timer.Simple(0.25, req) -- обновить статус (замок/список)
    end
end
local function vehOk(field)
    return function() return istable(data.veh) and data.veh[field] == true end
end

local BTNS = {
    { id = "ticket",     l = "Тикет",        fn = actTicket,     c = CC.ticket,  ch = CC.ticketH,  ok = function() return true end },
    { id = "inventory",  l = "Инвентарь",    fn = actInv,        c = CC.inv,     ch = CC.invH,     ok = function() return true end },
    { id = "money_drop", l = "Выбросить деньги…", fn = actDropMoney,
      c = Color(190, 150, 60), ch = Color(210, 170, 80), ok = function() return true end },
    { id = "money_give", l = function()
          if istable(data.aimPly) then
              local n = tostring(data.aimPly.name or "игроку")
              if #n > 16 then n = string.sub(n, 1, 15) .. "…" end
              return "Передать деньги: " .. n
          end
          return "Передать деньги игроку"
      end,
      fn = actGiveMoney,
      c = Color(90, 170, 90), ch = Color(110, 190, 110),
      ok = function() return istable(data.aimPly) end },
    -- ── транспорт (Код 82): только когда смотрим на машину ──
    { id = "veh_lock",   l = function() return (istable(data.veh) and data.veh.locked) and "Открыть замок Т/С" or "Закрыть Т/С на замок" end,
      fn = vehAct("lock"),   c = Color(90, 140, 200), ch = Color(110, 160, 220), ok = vehOk("canManage") },
    { id = "veh_trunk",  l = "Багажник (открыть/закрыть)", fn = vehAct("trunk"),
      c = Color(200, 160, 80), ch = Color(220, 180, 100), ok = vehOk("canUse") },
    { id = "veh_remove", l = function()
          if istable(data.veh) and (data.veh.refund or 0) > 0 then
              local rt = GRM and GRM.Format and GRM.Format(data.veh.refund) or tostring(data.veh.refund)
              return "Убрать Т/С (вернуть " .. rt .. ")"
          end
          return "Убрать Т/С"
      end,
      fn = vehAct("remove"),
      c = Color(190, 90, 80), ch = Color(210, 110, 100), ok = vehOk("canRemove"),
      confirm = true }, -- двойное нажатие-подтверждение (Диллер 2.1)
    { id = "tp",         l = function() return (tp and "Выкл" or "Вкл") .. " 3-е лицо" end, fn = actTp, c = CC.third, ch = CC.thirdH, ok = function() return true end },
    { id = "radio",      l = "Рация",        fn = actRadio,      c = CC.radio,   ch = CC.radioH,   ok = function() return true end },
    { id = "laws",       l = "Законы государства", fn = actLaws, c = Color(200, 180, 100), ch = Color(220, 200, 120), ok = function() return true end },
    { id = "faction",    l = "Меню фракций", fn = actFactions,   c = CC.faction, ch = CC.factionH, ok = function() return data.isLeaderOrAdmin == true or data.isFactionMember == true end },
    { id = "mask",       l = "Маскировка",   fn = actMask,       c = CC.mask,    ch = CC.maskH,    ok = function() return data.hasMaskAccess == true end },
}

req = function()
    net.Start("GRM_Ctx_Check")
    net.SendToServer()
end
net.Receive("GRM_Ctx_Result", function() data = net.ReadTable() or {} end)
timer.Create("GRM_Ctx_Refresh", 15, 0, req)
hook.Add("InitPostEntity", "GRM_Ctx_Init", function() timer.Simple(3, req) end)

local function drawMenu()
    if not visible then return end

    local sw, sh = ScrW(), ScrH()
    local bw, bh, gap, pad = 200, 36, 4, 8
    local list = {}
    for _, b in ipairs(BTNS) do if b.ok() then table.insert(list, b) end end
    if #list == 0 then return end

    local vehBar = istable(data.veh) and 22 or 0
    local th = #list * (bh + gap) - gap + pad * 2 + vehBar
    local x, y = sw - bw - 20, MENU_Y

    draw.RoundedBox(6, x, y, bw + pad * 2, th, BG)
    surface.SetDrawColor(BORD)
    surface.DrawOutlinedRect(x, y, bw + pad * 2, th, 1)

    -- шапка с текущим Т/С (Код 82): имя + статус замка
    if vehBar > 0 then
        local vt = tostring(data.veh.name or "Т/С")
        if #vt > 26 then vt = string.sub(vt, 1, 25) .. "…" end
        local lockCol = data.veh.locked and Color(230, 120, 110) or Color(120, 220, 140)
        draw.SimpleText(vt .. "  •  " .. (data.veh.locked and "ЗАКРЫТА" or "ОТКРЫТА"),
            "GRMCtx_Normal", x + pad + bw / 2, y + pad + 9, lockCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end

    local mx, my = gui.MouseX(), gui.MouseY()
    local down = input.IsMouseDown(MOUSE_LEFT)
    local click = down and not wasDown
    local cy = y + pad + vehBar

    if armed.id and CurTime() > (armed.untilT or 0) then armed.id = nil end -- протухло подтверждение

    for _, b in ipairs(list) do
        local bx, by = x + pad, cy
        local col, colH = b.c, b.ch
        if b.id == "tp" then
            col = tp and Color(60, 160, 80) or b.c
            colH = tp and Color(80, 180, 100) or b.ch
        end
        local isArmed = (armed.id == b.id)
        if isArmed then
            col, colH = Color(210, 70, 60), Color(230, 90, 80)
        end
        local hov = mx >= bx and mx <= bx + bw and my >= by and my <= by + bh
        draw.RoundedBox(4, bx, by, bw, bh, hov and colH or col)
        local lbl = type(b.l) == "function" and b.l() or b.l
        if isArmed then lbl = "⚠ Ещё раз — подтвердить" end
        draw.SimpleText(lbl, "GRMCtx_Normal", bx + bw / 2, by + bh / 2, Color(255, 255, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if hov and click then
            local cd = cooldowns[b.id]
            if not cd or CurTime() > cd then
                if b.confirm and not isArmed then
                    -- опасное действие: первое нажатие только «взводит» кнопку на 3 с
                    armed.id = b.id
                    armed.untilT = CurTime() + 3
                else
                    cooldowns[b.id] = CurTime() + 0.3
                    armed.id = nil
                    b.fn()
                end
            end
        end
        cy = cy + bh + gap
    end
    wasDown = down
end

-- Убираем старые хуки
hook.Remove("OnContextMenuOpen", "GRM_Ctx_Open")
hook.Remove("Think", "GRM_Ctx_CheckQ")
hook.Remove("PlayerBindPress", "GRM_Ctx_Toggle")

hook.Add("OnContextMenuOpen", "GRM_Ctx_Open", function()
    -- Сразу блокируем стандартное меню (return true)
    -- Через кадр проверяем, что это не Q
    timer.Simple(0, function()
        if g_SpawnMenu and g_SpawnMenu:IsVisible() then
            visible = false
            gui.EnableScreenClicker(false)
            return
        end
        visible = true
        wasDown = input.IsMouseDown(MOUSE_LEFT)
        req()
        gui.EnableScreenClicker(true)
    end)
    return true
end)

hook.Add("OnContextMenuClose", "GRM_Ctx_Close", function()
    visible = false
    gui.EnableScreenClicker(false)
end)

hook.Add("PostRenderVGUI", "GRM_Ctx_Draw", drawMenu)

print("[GRM CTX] Client loaded")

end
