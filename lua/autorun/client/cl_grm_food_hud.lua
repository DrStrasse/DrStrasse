--[[
    GRM Food HUD - отображение голода
    В этой версии специально убираем старый HUD-хук из предыдущего архива,
    чтобы сытость не рисовалась два раза, если на сервере случайно остался старый аддон.
]]

if not CLIENT then return end

CreateClientConVar("grm_cl_foodhud", "1", true, false) -- F4 → Настройки
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

--[[ Сытость переехала в общую панель состояния (заказ владельца 22.08).
     Раньше полоса рисовалась по АБСОЛЮТНЫМ координатам (x = ScrW() - 1066,
     y = 1044): на любом разрешении, кроме одного, она уезжала за экран или
     налезала на другие полосы. Теперь модуль только отдаёт значение, а где
     и как его показать, решает HUD. ]]
local function hungerColor(frac)
    if frac < 0.3 then return Color(220, 80, 80) end
    if frac < 0.6 then return Color(220, 200, 80) end
    return Color(80, 205, 125)
end

local function hungerText(frac, hunger)
    if frac <= 0 then return "ГОЛОДАНИЕ" end
    if frac < 0.2 then return "очень голоден · " .. math.floor(hunger) .. "%" end
    if frac < 0.5 then return "голоден · " .. math.floor(hunger) .. "%" end
    return math.floor(hunger) .. "%"
end

if GRM.HUD and GRM.HUD.RegisterBar then
    GRM.HUD.RegisterBar("hunger", {
        label = "СЫТОСТЬ", order = 50,
        Get = function()
            local cv = GetConVar("grm_cl_foodhud")
            if cv and cv:GetInt() == 0 then return nil end
            local config = GRM.Food.Config or {}
            local maxHunger = config.HungerMax or 100
            local hunger = math.Clamp(tonumber(GRM.Food.ClientHunger) or maxHunger, 0, maxHunger)
            local frac = hunger / math.max(1, maxHunger)
            return hunger, maxHunger, hungerText(frac, hunger), hungerColor(frac)
        end,
    })
end
