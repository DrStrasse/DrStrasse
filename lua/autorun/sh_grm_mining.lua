--[[
    sh_grm_mining.lua — общий хук + прогресс-бар
    Версия с универсальной проверкой джекхаммера и регистрацией net-сообщений
]]

if SERVER then

    -- Регистрируем сетевые сообщения
    util.AddNetworkString("grm_ore_progress")
    util.AddNetworkString("grm_ore_buyer_open")
    util.AddNetworkString("grm_ore_sell")

    -- Хук на урон (обрабатывает только grm_ore_node)
    hook.Add("EntityTakeDamage", "GRM_OreNodeDamage", function(target, dmginfo)
        if not IsValid(target) then return end
        if target:GetClass() ~= "grm_ore_node" then return end

        local attacker = dmginfo:GetAttacker()
        if not IsValid(attacker) or not attacker:IsPlayer() then return end

        local wep = attacker:GetActiveWeapon()
        if not IsValid(wep) then return end

        -- Проверяем, что оружие — джекхаммер (любой вариант названия)
        if not string.find(wep:GetClass(), "jackhammer") then
            return
        end

        -- Вызываем кастомную функцию урона в энтити
        if target.TakeDamageCustom then
            target:TakeDamageCustom(dmginfo:GetDamage(), attacker)
            dmginfo:SetDamage(0) -- отключаем стандартный урон
        end
    end)

    -- Регистрация в спавн-меню (категория уже задана в ENT.Category)
    list.Set("SpawnableEntities", "grm_ore_node", {
        PrintName = "Ore Node (Copper/Aluminum/Gold/Platinum)",
        ClassName = "grm_ore_node",
        Category = "GRM MINE"
    })

    print("[GRM Mining] Серверная часть загружена (универсальный джекхаммер)")

else -- CLIENT

    -- Клиентский прогресс-бар
    local progress = 0
    local oreEntity = nil
    local showProgress = false

    net.Receive("grm_ore_progress", function()
        oreEntity = net.ReadEntity()
        progress = net.ReadFloat()
        showProgress = true
    end)

    hook.Add("HUDPaint", "GRM_Mining_ProgressBar", function()
        if not showProgress then return end
        if not IsValid(oreEntity) then
            showProgress = false
            return
        end

        local scrW, scrH = ScrW(), ScrH()
        local barWidth = 200
        local barHeight = 16
        local x = scrW/2 - barWidth/2
        local y = scrH/2 + 100

        surface.SetDrawColor(0, 0, 0, 180)
        surface.DrawRect(x, y, barWidth, barHeight)

        surface.SetDrawColor(255, 200, 0, 255)
        surface.DrawRect(x, y, barWidth * progress, barHeight)

        surface.SetTextColor(255, 255, 255, 255)
        surface.SetFont("default")
        surface.SetTextPos(x + barWidth/2 - 20, y + 2)
        surface.DrawText(string.format("%.0f%%", progress * 100))
    end)

    -- Скрываем, если игрок умер или убрал оружие
    hook.Add("PostRender", "GRM_ResetProgress", function()
        if not IsValid(LocalPlayer()) then return end
        local wep = LocalPlayer():GetActiveWeapon()
        if not IsValid(wep) or not string.find(wep:GetClass(), "jackhammer") then
            showProgress = false
        end
    end)

    print("[GRM Mining] Клиентская часть загружена (универсальный джекхаммер)")

end
