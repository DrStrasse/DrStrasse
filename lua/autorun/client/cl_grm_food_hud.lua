--[[
    GRM Food HUD - отображение голода
    В этой версии специально убираем старый HUD-хук из предыдущего архива,
    чтобы сытость не рисовалась два раза, если на сервере случайно остался старый аддон.
]]

if not CLIENT then return end

GRM = GRM or {}
GRM.Food = GRM.Food or {}

if not GRM.Food.Config then
    include("autorun/sh_grm_food_config.lua")
end

GRM.Food.ClientHunger = GRM.Food.ClientHunger or ((GRM.Food.Config and GRM.Food.Config.HungerMax) or 100)

-- Удаляем наш хук перед повторной регистрацией, чтобы lua_refresh/lua_openscript не плодил HUD.
hook.Remove("HUDPaint", "GRM_Food_HUD")

-- Удаляем HUD из самого первого архива grm_food_system.zip.
-- Там он назывался GRM_Food_HUDPaint и из-за него могло быть два индикатора сытости.
hook.Remove("HUDPaint", "GRM_Food_HUDPaint")

-- Если старый аддон загрузился позже этого файла, ещё несколько раз после загрузки карты
-- подчистим его хук. Потом таймер сам удалится.
if timer.Exists("GRM_Food_RemoveOldDuplicateHUD") then
    timer.Remove("GRM_Food_RemoveOldDuplicateHUD")
end

local cleanupTicks = 0
timer.Create("GRM_Food_RemoveOldDuplicateHUD", 1, 10, function()
    cleanupTicks = cleanupTicks + 1
    hook.Remove("HUDPaint", "GRM_Food_HUDPaint")

    if cleanupTicks >= 10 then
        timer.Remove("GRM_Food_RemoveOldDuplicateHUD")
    end
end)

net.Receive("GRM_Food_Sync", function()
    GRM.Food.ClientHunger = net.ReadFloat()
end)

hook.Add("HUDPaint", "GRM_Food_HUD", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end

    -- Читаем глобальное значение, чтобы HUD работал даже если на сервере случайно остался
    -- старый клиентский файл, который перезаписал net.Receive и обновляет GRM.Food.ClientHunger.
    local config = GRM.Food.Config or {}
    local maxHunger = config.HungerMax or 100
    local hunger = math.Clamp(tonumber(GRM.Food.ClientHunger) or maxHunger, 0, maxHunger)
    local frac = math.Clamp(hunger / maxHunger, 0, 1)

    local sw = ScrW()
    local x = sw - 1066
    local y = 1044
    local w = 220
    local h = 22

    local barColor = Color(80, 220, 80, 240)
    if frac < 0.3 then
        barColor = Color(220, 80, 80, 240)
    elseif frac < 0.6 then
        barColor = Color(220, 200, 80, 240)
    end

    local status = "Сытость"
    if frac <= 0 then
        status = "ГОЛОДАНИЕ"
    elseif frac < 0.2 then
        status = "Очень голоден"
    elseif frac < 0.5 then
        status = "Голоден"
    elseif frac < 0.8 then
        status = "Нормально"
    end

    draw.RoundedBox(5, x, y, w, h, Color(30, 32, 40, 210))
    draw.RoundedBox(5, x + 2, y + 2, (w - 4) * frac, h - 4, barColor)
    draw.SimpleText(status .. ": " .. math.floor(hunger) .. "%", "DermaDefaultBold", x + w / 2, y + h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
