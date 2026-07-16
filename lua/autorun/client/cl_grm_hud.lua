--[[--------------------------------------------------------------------
    GRM HUD v10.2 — Полноценный HUD для Sandbox
    v10.2: разделённые строки денег «НАЛИЧКА» (кошелёк, ядро валюты)
           и «НА СЧЁТУ» (банк, экономика → GRM_Bank_Sync)
    v10.1: ресивер grm_balance рассылает хук GRM_BalanceUpdated
           (мгновенное обновление Tab Menu); сумма рисуется через
           GRM.Format (имя валюты из экономики), $ — только fallback
    Путь: garrysmod/addons/grm_hud/lua/autorun/client/cl_grm_hud.lua
    (Код 48; сохранено агентом: снят ГМЛ-манглинг веб-вставки — восстановлены < > * _)
--------------------------------------------------------------------]]
if not CLIENT then return end

GRM = GRM or {}
GRM.HUD = GRM.HUD or {}
GRM.HUD.Config = {
    bgColor        = Color(12, 14, 20, 210),
    bgShadow       = Color(0, 0, 0, 60),
    textColor      = Color(230, 230, 235, 255),
    labelColor     = Color(160, 165, 175, 255),
    hpColorFull    = Color(80, 210, 120, 255),
    hpColorMid     = Color(230, 200, 50, 255),
    hpColorLow     = Color(220, 60, 60, 255),
    armorColor     = Color(60, 150, 220, 255),
    moneyColor     = Color(80, 220, 130, 255),
    bankColor      = Color(95, 170, 255, 255),
    ammoColor      = Color(220, 180, 60, 255),
    ammo2Color     = Color(180, 180, 190, 255),
    slotBg         = Color(20, 22, 30, 220),
    slotBorder     = Color(60, 65, 80, 200),
    slotActive     = Color(80, 160, 255, 255),
    slotHover      = Color(60, 120, 200, 150),
    slotText       = Color(200, 205, 215, 255),
    slotKeyColor   = Color(255, 200, 60, 255),
    animSpeed       = 8,
    selectorTimeout = 3,
}

-- ШРИФТЫ
if not GRM.HUD._fontsCreated then
    GRM.HUD._fontsCreated = true
    local fonts = {
        {"GRM_HUD_Label",      10, 600},
        {"GRM_HUD_Value",      14, 700},
        {"GRM_HUD_ValueLg",    18, 700},
        {"GRM_HUD_Money",      13, 700},
        {"GRM_HUD_Ammo",       28, 700},
        {"GRM_HUD_Ammo2",      16, 600},
        {"GRM_Notify",         13, 500},
        {"GRM_SlotKey",        11, 700},
        {"GRM_SlotName",       11, 500},
        {"GRM_SlotNameActive", 12, 600},
    }
    for _, f in ipairs(fonts) do
        surface.CreateFont(f[1], {
            font      = "Roboto",
            size      = f[2],
            weight    = f[3],
            extended  = true,
            antialias = true,
        })
    end
end

-- БАЛАНС
GRM.PlayerBalance = GRM.PlayerBalance or 0
if not GRM.HUD._balRcv then
    GRM.HUD._balRcv = true
    net.Receive("grm_balance", function()
        local bal = net.ReadInt(32)
        GRM.PlayerBalance = bal
        -- Фан-аут для Tab Menu (Код 47) и других модулей: HUD грузится
        -- последним и перекрывает их ресиверы, поэтому рассылаем хук.
        hook.Run("GRM_BalanceUpdated", bal)
    end)
end

-- УВЕДОМЛЕНИЯ
GRM.Notifications = GRM.Notifications or {}
if not GRM.HUD._notRcv then
    GRM.HUD._notRcv = true
    net.Receive("grm_notify", function()
        GRM.AddNotification(net.ReadString(), 5, Color(net.ReadUInt(8), net.ReadUInt(8), net.ReadUInt(8), 255))
    end)
end

function GRM.AddNotification(text, duration, color)
    duration = duration or 5
    color = color or Color(255, 255, 255, 255)
    table.insert(GRM.Notifications, 1, { text = text, time = CurTime(), duration = duration, color = color, alpha = 0, yOff = 12 })
    while #GRM.Notifications > 6 do table.remove(GRM.Notifications) end
end

hook.Add("InitPostEntity", "GRM_HUD_ReqBal", function()
    timer.Simple(1, function()
        net.Start("grm_request_bal")
        net.SendToServer()
        net.Start("GRM_Bank_Request")  -- банковский счёт (экономика)
        net.SendToServer()
    end)
end)

-- АНИМАЦИЯ
local anim = { hp = 100, armor = 0, bal = 0, bank = 0, ammo1 = 0, ammo2 = 0 }
local actual = { hp = 100, maxHp = 100, armor = 0, bal = 0, bank = 0, ammo1 = 0, ammo2 = 0, alive = true }
local lastUpdate = 0

local function UpdateValues()
    local now = CurTime()
    if now - lastUpdate < 0.05 then return end
    lastUpdate = now
    local lp = LocalPlayer()
    if not IsValid(lp) then actual.alive = false; return end
    actual.alive = lp:Alive()
    actual.hp = lp:Health()
    actual.maxHp = math.max(lp:GetMaxHealth(), 1)
    actual.armor = lp:Armor()
    actual.bal = GRM.PlayerBalance or 0
    actual.bank = GRM.PlayerBank or 0
    local wep = lp:GetActiveWeapon()
    if IsValid(wep) then
        actual.ammo1 = wep:Clip1() or 0
        actual.ammo2 = lp:GetAmmoCount(wep:GetPrimaryAmmoType()) or 0
    else
        actual.ammo1 = -1
        actual.ammo2 = 0
    end
end

local function AnimateValues()
    local spd = GRM.HUD.Config.animSpeed * FrameTime()
    anim.hp    = Lerp(spd, anim.hp, actual.hp)
    anim.armor = Lerp(spd, anim.armor, actual.armor)
    anim.bal   = Lerp(spd * 0.5, anim.bal, actual.bal)
    anim.bank  = Lerp(spd * 0.5, anim.bank, actual.bank)
    anim.ammo1 = Lerp(spd * 2, anim.ammo1, actual.ammo1)
    anim.ammo2 = Lerp(spd * 2, anim.ammo2, actual.ammo2)
end

-- СЕЛЕКТОР ОРУЖИЯ
local selector = { active = false, slot = 1, pos = 1, lastInput = 0, alpha = 0, weapons = {}, lastRefresh = 0 }

local function RefreshWeapons()
    local now = CurTime()
    if now - selector.lastRefresh < 0.2 then return end
    selector.lastRefresh = now
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    selector.weapons = {}
    for _, wep in ipairs(lp:GetWeapons()) do
        if IsValid(wep) then
            local s = wep:GetSlot() + 1
            local p = wep:GetSlotPos() + 1
            if not selector.weapons[s] then selector.weapons[s] = {} end
            table.insert(selector.weapons[s], { weapon = wep, name = wep:GetPrintName() or wep:GetClass(), slotPos = p })
        end
    end
    for s, weps in pairs(selector.weapons) do table.sort(weps, function(a, b) return a.slotPos < b.slotPos end) end
end

local function CloseSelector() selector.active = false end

local function SelectWeapon()
    local slotWeps = selector.weapons[selector.slot]
    if slotWeps and slotWeps[selector.pos] then
        local wep = slotWeps[selector.pos].weapon
        if IsValid(wep) then input.SelectWeapon(wep) end
    end
    CloseSelector()
end

local function FindCurrentWeapon()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    local activeWep = lp:GetActiveWeapon()
    if IsValid(activeWep) then
        local curSlot = activeWep:GetSlot() + 1
        selector.slot = curSlot
        local slotWeps = selector.weapons[curSlot]
        if slotWeps then
            for i, w in ipairs(slotWeps) do
                if w.weapon == activeWep then selector.pos = i; return end
            end
        end
        selector.pos = 1
    else
        selector.slot = 1; selector.pos = 1
    end
end

local function NextWeapon()
    local slotWeps = selector.weapons[selector.slot]
    if slotWeps and #slotWeps > 0 then
        selector.pos = selector.pos + 1
        if selector.pos > #slotWeps then
            for offset = 1, 6 do
                local nextSlot = ((selector.slot - 1 + offset) % 6) + 1
                if selector.weapons[nextSlot] and #selector.weapons[nextSlot] > 0 then
                    selector.slot = nextSlot; selector.pos = 1; return
                end
            end
        end
    else
        for offset = 1, 6 do
            local nextSlot = ((selector.slot - 1 + offset) % 6) + 1
            if selector.weapons[nextSlot] and #selector.weapons[nextSlot] > 0 then
                selector.slot = nextSlot; selector.pos = 1; return
            end
        end
    end
end

local function PrevWeapon()
    local slotWeps = selector.weapons[selector.slot]
    if slotWeps and #slotWeps > 0 then
        selector.pos = selector.pos - 1
        if selector.pos < 1 then
            for offset = 1, 6 do
                local prevSlot = ((selector.slot - 1 - offset) % 6) + 1
                if selector.weapons[prevSlot] and #selector.weapons[prevSlot] > 0 then
                    selector.slot = prevSlot; selector.pos = #selector.weapons[prevSlot]; return
                end
            end
        end
    else
        for offset = 1, 6 do
            local prevSlot = ((selector.slot - 1 - offset) % 6) + 1
            if selector.weapons[prevSlot] and #selector.weapons[prevSlot] > 0 then
                selector.slot = prevSlot; selector.pos = #selector.weapons[prevSlot]; return
            end
        end
    end
end

hook.Add("PlayerBindPress", "GRM_HUD_Selector", function(ply, bind, pressed)
    if not pressed then return end
    if not IsValid(ply) or not ply:Alive() then return end
    if bind == "invnext" then
        RefreshWeapons()
        if not selector.active then selector.active = true; FindCurrentWeapon() end
        NextWeapon()
        selector.lastInput = CurTime()
        return true
    elseif bind == "invprev" then
        RefreshWeapons()
        if not selector.active then selector.active = true; FindCurrentWeapon() end
        PrevWeapon()
        selector.lastInput = CurTime()
        return true
    end
    for i = 1, 6 do
        if bind == "slot" .. i then
            RefreshWeapons()
            if selector.active and selector.slot == i then
                local slotWeps = selector.weapons[i]
                if slotWeps and #slotWeps > 0 then selector.pos = (selector.pos % #slotWeps) + 1 end
            else
                selector.active = true; selector.slot = i; selector.pos = 1
            end
            selector.lastInput = CurTime()
            return true
        end
    end
    if bind == "+attack" and selector.active then SelectWeapon(); return true end
    if bind == "+attack2" and selector.active then CloseSelector(); return true end
end)

local hideElements = {
    ["CHudHealth"]          = true,
    ["CHudBattery"]         = true,
    ["CHudAmmo"]            = true,
    ["CHudSecondaryAmmo"]   = true,
    ["CHudWeaponSelection"] = true,
}
hook.Add("HUDShouldDraw", "GRM_HUD_Hide", function(name)
    if hideElements[name] then return false end
end)

-- ОТРИСОВКА
local function DrawMainHUD()
    UpdateValues()
    AnimateValues()
    if not actual.alive then return end
    local cfg = GRM.HUD.Config
    local sh, sw = ScrH(), ScrW()
    local px, py = 16, sh - 16 - 118
    local pw, ph = 210, 112
    draw.RoundedBox(8, px + 2, py + 2, pw, ph, cfg.bgShadow)
    draw.RoundedBox(8, px, py, pw, ph, cfg.bgColor)
    local barX, barY = px + 10, py + 20
    local barW, barH = pw - 20, 14
    local hpFrac = math.Clamp(anim.hp / actual.maxHp, 0, 1)
    draw.SimpleText("ЗДОРОВЬЕ", "GRM_HUD_Label", barX, py + 7, cfg.labelColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.RoundedBox(4, barX, barY, barW, barH, Color(30, 32, 40, 255))
    local hpColor
    if hpFrac > 0.6 then hpColor = cfg.hpColorFull
    elseif hpFrac > 0.3 then
        local t = (hpFrac - 0.3) / 0.3
        hpColor = Color(Lerp(t, cfg.hpColorMid.r, cfg.hpColorFull.r), Lerp(t, cfg.hpColorMid.g, cfg.hpColorFull.g), Lerp(t, cfg.hpColorMid.b, cfg.hpColorFull.b), 255)
    else
        local t = hpFrac / 0.3
        hpColor = Color(Lerp(t, cfg.hpColorLow.r, cfg.hpColorMid.r), Lerp(t, cfg.hpColorLow.g, cfg.hpColorMid.g), Lerp(t, cfg.hpColorLow.b, cfg.hpColorMid.b), 255)
    end
    if hpFrac > 0 then draw.RoundedBox(4, barX, barY, barW * hpFrac, barH, hpColor) end
    draw.SimpleText(math.Round(anim.hp) .. " / " .. actual.maxHp, "GRM_HUD_Value", barX + barW / 2, barY + barH / 2, Color(255, 255, 255, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    local arBarY = barY + barH + 10
    local arFrac = math.Clamp(anim.armor / 100, 0, 1)
    draw.SimpleText("БРОНЯ", "GRM_HUD_Label", barX, arBarY - 11, cfg.labelColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.RoundedBox(4, barX, arBarY, barW, barH, Color(30, 32, 40, 255))
    if arFrac > 0 then draw.RoundedBox(4, barX, arBarY, barW * arFrac, barH, cfg.armorColor) end
    draw.SimpleText(math.Round(anim.armor), "GRM_HUD_Value", barX + barW / 2, arBarY + barH / 2, Color(255, 255, 255, 240), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    -- GRM-FIX: две строки денег — наличка (кошелёк) и счёт (банк)
    local moneyY = arBarY + barH + 8
    draw.SimpleText("НАЛИЧКА", "GRM_HUD_Label", barX, moneyY + 2, cfg.labelColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    local cashTxt = (GRM.Format and GRM.Format(math.Round(anim.bal))) or ("$" .. string.Comma(math.Round(anim.bal)))
    draw.SimpleText(cashTxt, "GRM_HUD_Money", barX + barW, moneyY, cfg.moneyColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    local bankY = moneyY + 18
    draw.SimpleText("НА СЧЁТУ", "GRM_HUD_Label", barX, bankY + 2, cfg.labelColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    local bankTxt = (GRM.PlayerBank ~= nil)
        and ((GRM.Format and GRM.Format(math.Round(anim.bank))) or ("$" .. string.Comma(math.Round(anim.bank))))
        or "—"
    draw.SimpleText(bankTxt, "GRM_HUD_Money", barX + barW, bankY, cfg.bankColor or cfg.moneyColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)

    if actual.ammo1 >= 0 then
        local ax, ay = sw - 16 - 150, sh - 16 - 60
        local aw, ah = 150, 54
        draw.RoundedBox(8, ax + 2, ay + 2, aw, ah, cfg.bgShadow)
        draw.RoundedBox(8, ax, ay, aw, ah, cfg.bgColor)
        draw.SimpleText("ПАТРОНЫ", "GRM_HUD_Label", ax + aw - 10, ay + 6, cfg.labelColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        local ammoStr = tostring(math.Round(anim.ammo1))
        draw.SimpleText(ammoStr, "GRM_HUD_Ammo", ax + 12, ay + ah / 2 + 4, cfg.ammoColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        surface.SetFont("GRM_HUD_Ammo")
        local ammoW = surface.GetTextSize(ammoStr)
        draw.SimpleText(" / " .. math.Round(anim.ammo2), "GRM_HUD_Ammo2", ax + 14 + ammoW, ay + ah / 2 + 6, cfg.ammo2Color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
end

local function DrawWeaponSelector()
    local cfg = GRM.HUD.Config
    if selector.active and CurTime() - selector.lastInput > cfg.selectorTimeout then SelectWeapon() end
    local targetAlpha = selector.active and 255 or 0
    selector.alpha = math.Approach(selector.alpha, targetAlpha, FrameTime() * 900)
    if selector.alpha < 1 then return end
    local sw = ScrW()
    local alpha = selector.alpha / 255
    local slotW, slotH, slotGap, headerH, padding = 170, 30, 5, 26, 6
    local totalSlots = 6
    local totalW = totalSlots * (slotW + slotGap) - slotGap
    local startX, startY = (sw - totalW) / 2, 20

    RefreshWeapons()
    for slot = 1, totalSlots do
        local sx = startX + (slot - 1) * (slotW + slotGap)
        local slotWeps = selector.weapons[slot] or {}
        local numWeps = #slotWeps
        local colH = headerH + math.max(numWeps, 1) * (slotH + 2) + padding
        local isActiveSlot = (selector.slot == slot)
        local bgA = isActiveSlot and (210 * alpha) or (170 * alpha)
        draw.RoundedBox(6, sx, startY, slotW, colH, Color(cfg.slotBg.r, cfg.slotBg.g, cfg.slotBg.b, bgA))
        if isActiveSlot then
            surface.SetDrawColor(cfg.slotActive.r, cfg.slotActive.g, cfg.slotActive.b, 200 * alpha)
            surface.DrawOutlinedRect(sx, startY, slotW, colH, 2)
        else
            surface.SetDrawColor(cfg.slotBorder.r, cfg.slotBorder.g, cfg.slotBorder.b, 100 * alpha)
            surface.DrawOutlinedRect(sx, startY, slotW, colH, 1)
        end
        draw.SimpleText(tostring(slot), "GRM_SlotKey", sx + 8, startY + 5, Color(cfg.slotKeyColor.r, cfg.slotKeyColor.g, cfg.slotKeyColor.b, 255 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("СЛОТ " .. slot, "GRM_HUD_Label", sx + 22, startY + 6, Color(cfg.labelColor.r, cfg.labelColor.g, cfg.labelColor.b, 200 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        if numWeps > 0 then
            for i, wepData in ipairs(slotWeps) do
                local wy = startY + headerH + (i - 1) * (slotH + 2)
                local isSelected = isActiveSlot and (selector.pos == i)
                if isSelected then
                    draw.RoundedBox(4, sx + 3, wy, slotW - 6, slotH, Color(cfg.slotActive.r, cfg.slotActive.g, cfg.slotActive.b, 70 * alpha))
                    surface.SetDrawColor(cfg.slotActive.r, cfg.slotActive.g, cfg.slotActive.b, 255 * alpha)
                    surface.DrawRect(sx + 3, wy + 5, 3, slotH - 10)
                end
                local lp = LocalPlayer()
                local activeWep = IsValid(lp) and lp:GetActiveWeapon()
                local isEquipped = IsValid(activeWep) and activeWep == wepData.weapon
                local nameFont = isSelected and "GRM_SlotNameActive" or "GRM_SlotName"
                local nameColor
                if isEquipped then nameColor = Color(cfg.hpColorFull.r, cfg.hpColorFull.g, cfg.hpColorFull.b, 255 * alpha)
                elseif isSelected then nameColor = Color(255, 255, 255, 255 * alpha)
                else nameColor = Color(cfg.slotText.r, cfg.slotText.g, cfg.slotText.b, 200 * alpha) end
                local displayName = wepData.name
                if #displayName > 20 then displayName = string.sub(displayName, 1, 18) .. ".." end
                draw.SimpleText(displayName, nameFont, sx + 14, wy + slotH / 2, nameColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                if isEquipped then
                    draw.SimpleText("●", "GRM_SlotKey", sx + slotW - 12, wy + slotH / 2, Color(cfg.hpColorFull.r, cfg.hpColorFull.g, cfg.hpColorFull.b, 200 * alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
            end
        else
            draw.SimpleText("— пусто —", "GRM_SlotName", sx + slotW / 2, startY + headerH + 10, Color(70, 70, 80, 140 * alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    end

    if selector.active then
        local hintX = startX + totalW + 16
        local hintY = startY + 4
        local hints = {{"ЛКМ","Выбрать"},{"ПКМ","Отмена"},{"Колесо","Листать"},{"1-6","Слот"}}
        for i, hint in ipairs(hints) do
            local hy = hintY + (i - 1) * 18
            draw.SimpleText(hint[1], "GRM_SlotKey", hintX, hy, Color(cfg.slotKeyColor.r, cfg.slotKeyColor.g, cfg.slotKeyColor.b, 180 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(hint[2], "GRM_HUD_Label", hintX + 48, hy + 1, Color(cfg.labelColor.r, cfg.labelColor.g, cfg.labelColor.b, 160 * alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end
end

local function DrawNotifications()
    local sw, sh = ScrW(), ScrH()
    local nx, baseY = sw - 20, sh - 130
    for i = #GRM.Notifications, 1, -1 do
        local n = GRM.Notifications[i]
        local elapsed = CurTime() - n.time
        if elapsed > n.duration then table.remove(GRM.Notifications, i)
        else
            local tA, tY = 255, 0
            if elapsed < 0.35 then tA = (elapsed / 0.35) * 255; tY = (1 - elapsed / 0.35) * 10
            elseif elapsed > n.duration - 0.6 then tA = ((n.duration - elapsed) / 0.6) * 255 end
            n.alpha = math.Approach(n.alpha or 0, tA, FrameTime() * 700)
            n.yOff = math.Approach(n.yOff or 0, tY, FrameTime() * 500)
            local idx = #GRM.Notifications - i
            local y = baseY - idx * 26 - n.yOff
            surface.SetFont("GRM_Notify")
            local tw = surface.GetTextSize(n.text)
            draw.RoundedBox(4, nx - tw - 22, y - 10, tw + 16, 22, Color(12, 14, 20, n.alpha * 0.75))
            draw.SimpleText(n.text, "GRM_Notify", nx - 8, y, Color(n.color.r, n.color.g, n.color.b, n.alpha), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
end

hook.Add("HUDPaint", "GRM_HUD_Main", function()
    pcall(DrawMainHUD)
    pcall(DrawWeaponSelector)
    pcall(DrawNotifications)
end)

hook.Add("InitPostEntity", "GRM_HUD_Welcome", function()
    timer.Simple(4, function()
        if IsValid(LocalPlayer()) then GRM.AddNotification("HUD v10.2 загружен — колёсико для выбора оружия", 5, Color(100, 180, 255)) end
    end)
end)

print("[GRM] HUD v10.2 загружен")
