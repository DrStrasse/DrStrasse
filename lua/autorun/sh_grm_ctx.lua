--[[--------------------------------------------------------------------
    GRM Context Menu — единое контекстное меню (server + client)
--------------------------------------------------------------------]]

if SERVER then
    AddCSLuaFile()
    util.AddNetworkString("GRM_Ctx_Check")
    util.AddNetworkString("GRM_Ctx_Result")
    util.AddNetworkString("GRM_Ctx_VehAct")

    local function getPlayerFaction(ply)
        if not Factions then return nil, nil end
        local sid = ply:SteamID()
        for name, f in pairs(Factions) do
            if istable(f) and istable(f.Members) and f.Members[sid] then
                return name, f
            end
        end
        return nil, nil
    end

    -- Транспорт в прицеле (Код 82): имя/замок/права для кнопок меню
    local function vehInfo(ply)
        if not (_G.VK and VK.IsVehicle) then return nil end
        local veh = nil
        if VK.GetAimedVehicle then veh = VK.GetAimedVehicle(ply, 240) end
        if not (IsValid(veh) and VK.IsVehicle(veh)) then return nil end
        local canManage = (VK.CanInteract and VK.CanInteract(veh, ply, true)) or ply:IsSuperAdmin()
        local canUse = (VK.CanInteract and VK.CanInteract(veh, ply, false)) or ply:IsSuperAdmin()
        local mine = (veh.VD_Owner == ply)
            or (veh.VK_OwnerType == "player" and veh.VK_OwnerSteam == ply:SteamID())
            or ply:IsSuperAdmin()
        local tracked = (VD_AllVehicles and VD_AllVehicles[veh:EntIndex()] ~= nil)
            or veh.VD_Owner ~= nil or veh.VD_ID ~= nil
        return {
            name = (VK.GetVehicleDisplayName and VK.GetVehicleDisplayName(veh)) or veh:GetClass(),
            locked = veh.VK_Locked == true or veh:GetNW2Bool("VK_Locked", false),
            canManage = canManage == true,   -- владелец/ключи/суперадмин → замок
            canUse = canUse == true,         -- член фракции/ключи → багажник (дальше решит TK.CanAccess)
            canRemove = mine and tracked,    -- только Т/С дилера у своего владельца; суперадмин — любое дилерское
        }
    end

    net.Receive("GRM_Ctx_Check", function(_, ply)
        if not IsValid(ply) then return end
        local result = {}
        local factionName, faction = getPlayerFaction(ply)
        result.isFactionMember = (factionName ~= nil)
        result.isLeaderOrAdmin = (faction and faction.Leader == ply:SteamID()) or ply:IsSuperAdmin()
        result.factionName = factionName or ""
        result.veh = vehInfo(ply)
        result.hasMaskAccess = false
        if factionName and FactionsExt and FactionsExt[factionName] then
            local cfg = FactionsExt[factionName]
            local member = faction and faction.Members[ply:SteamID()]
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

        -- «Убрать Т/С»: только дилерское, своё; суперадмин — любое дилерское
        if doAct == "remove" then
            local tracked = (VD_AllVehicles and VD_AllVehicles[veh:EntIndex()] ~= nil)
                or veh.VD_Owner ~= nil or veh.VD_ID ~= nil
            if not tracked then
                if GRM.Notify then GRM.Notify(ply, "Это не транспорт из дилера", 255, 140, 120) end
                return
            end
            local mine = (veh.VD_Owner == ply)
                or (veh.VK_OwnerType == "player" and veh.VK_OwnerSteam == ply:SteamID())
            if not (mine or ply:IsSuperAdmin()) then
                if GRM.Notify then GRM.Notify(ply, "Это не ваш транспорт", 255, 140, 120) end
                return
            end
            local owner = veh.VD_Owner
            local price = tonumber(veh.VD_Price) or 0
            local refund = (mine and price > 0) and math.floor(price * 0.5) or 0
            local cls = tostring(veh.VD_Class or veh:GetClass())
            if VD_AllVehicles then VD_AllVehicles[veh:EntIndex()] = nil end
            veh:Remove()
            if refund > 0 and GRM.GiveMoney and IsValid(owner) then
                GRM.GiveMoney(owner, refund, "Возврат за удалённый транспорт: " .. cls)
            end
            hook.Run("VD_OnVehicleRemoved", veh, ply, cls)
            if GRM.Notify then
                GRM.Notify(ply, "Транспорт убран: " .. cls .. (refund > 0 and (" • возврат " .. (GRM.Format and GRM.Format(refund) or refund)) or ""), 140, 230, 150)
            end
            return
        end
    end)

    print("[GRM CTX] Server loaded (v2: кнопки транспорта, Код 82)")
end

if CLIENT then

local MENU_Y = 300

surface.CreateFont("GRMCtx_Normal", { font = "Roboto", size = 13, weight = 500, extended = true })

local CC = {
    ticket  = Color(180, 100, 60),  ticketH  = Color(200, 120, 80),
    inv     = Color(50, 120, 200),  invH     = Color(70, 140, 220),
    market  = Color(60, 180, 100),  marketH  = Color(80, 200, 120),
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
local data = {}
local tp = false

local function actTicket()    RunConsoleCommand("grm_ticket") end
local function actInv()       RunConsoleCommand("grm_inventory") end
local function actMarket()    RunConsoleCommand("grm_market") end
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
local function actFactions()  RunConsoleCommand("say", "/factions") end
local function actMask()      RunConsoleCommand("say", "/mask") end

-- Транспорт рядом (Код 82): сервер сам перепроверит прицел и права
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
    { id = "market",     l = "Маркет",       fn = actMarket,     c = CC.market,  ch = CC.marketH,  ok = function() return true end },
    -- ── транспорт (Код 82): только когда смотрим на машину ──
    { id = "veh_lock",   l = function() return (istable(data.veh) and data.veh.locked) and "Открыть замок Т/С" or "Закрыть Т/С на замок" end,
      fn = vehAct("lock"),   c = Color(90, 140, 200), ch = Color(110, 160, 220), ok = vehOk("canManage") },
    { id = "veh_trunk",  l = "Багажник (открыть/закрыть)", fn = vehAct("trunk"),
      c = Color(200, 160, 80), ch = Color(220, 180, 100), ok = vehOk("canUse") },
    { id = "veh_remove", l = "Убрать Т/С (возврат 50%)", fn = vehAct("remove"),
      c = Color(190, 90, 80), ch = Color(210, 110, 100), ok = vehOk("canRemove") },
    { id = "tp",         l = function() return (tp and "Выкл" or "Вкл") .. " 3-е лицо" end, fn = actTp, c = CC.third, ch = CC.thirdH, ok = function() return true end },
    { id = "radio",      l = "Рация",        fn = actRadio,      c = CC.radio,   ch = CC.radioH,   ok = function() return true end },
    { id = "faction",    l = "Меню фракции", fn = actFactions,   c = CC.faction, ch = CC.factionH, ok = function() return data.isLeaderOrAdmin == true or data.isFactionMember == true end },
    { id = "mask",       l = "Маскировка",   fn = actMask,       c = CC.mask,    ch = CC.maskH,    ok = function() return data.hasMaskAccess == true end },
}

local function req()
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

    for _, b in ipairs(list) do
        local bx, by = x + pad, cy
        local col, colH = b.c, b.ch
        if b.id == "tp" then
            col = tp and Color(60, 160, 80) or b.c
            colH = tp and Color(80, 180, 100) or b.ch
        end
        local hov = mx >= bx and mx <= bx + bw and my >= by and my <= by + bh
        draw.RoundedBox(4, bx, by, bw, bh, hov and colH or col)
        local lbl = type(b.l) == "function" and b.l() or b.l
        draw.SimpleText(lbl, "GRMCtx_Normal", bx + bw / 2, by + bh / 2, Color(255, 255, 255, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if hov and click then
            local cd = cooldowns[b.id]
            if not cd or CurTime() > cd then
                cooldowns[b.id] = CurTime() + 0.3
                b.fn()
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
