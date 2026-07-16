--[[--------------------------------------------------------------------
    GRM Context Menu — единое контекстное меню (server + client)
--------------------------------------------------------------------]]

if SERVER then
    AddCSLuaFile()
    util.AddNetworkString("GRM_Ctx_Check")
    util.AddNetworkString("GRM_Ctx_Result")

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

    net.Receive("GRM_Ctx_Check", function(_, ply)
        if not IsValid(ply) then return end
        local result = {}
        local factionName, faction = getPlayerFaction(ply)
        result.isFactionMember = (factionName ~= nil)
        result.isLeaderOrAdmin = (faction and faction.Leader == ply:SteamID()) or ply:IsSuperAdmin()
        result.factionName = factionName or ""
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

    print("[GRM CTX] Server loaded")
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

local BTNS = {
    { id = "ticket",     l = "Тикет",        fn = actTicket,     c = CC.ticket,  ch = CC.ticketH,  ok = function() return true end },
    { id = "inventory",  l = "Инвентарь",    fn = actInv,        c = CC.inv,     ch = CC.invH,     ok = function() return true end },
    { id = "market",     l = "Маркет",       fn = actMarket,     c = CC.market,  ch = CC.marketH,  ok = function() return true end },
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

    local th = #list * (bh + gap) - gap + pad * 2
    local x, y = sw - bw - 20, MENU_Y

    draw.RoundedBox(6, x, y, bw + pad * 2, th, BG)
    surface.SetDrawColor(BORD)
    surface.DrawOutlinedRect(x, y, bw + pad * 2, th, 1)

    local mx, my = gui.MouseX(), gui.MouseY()
    local down = input.IsMouseDown(MOUSE_LEFT)
    local click = down and not wasDown
    local cy = y + pad

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
