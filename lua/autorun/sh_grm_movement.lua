--[[--------------------------------------------------------------------
    GRM Movement System v1.3 — Полное управление звуком дыхания
    - Используется CreateSound для точного контроля (Play/Stop)
    - Звук корректно останавливается при восстановлении стамины до 100%
    - Полоса выносливости в центре снизу
--------------------------------------------------------------------]]

if SERVER then
    util.AddNetworkString("GRM_Stamina_Sync")
end

GRM = GRM or {}
GRM.Movement = GRM.Movement or {}

-- ============================================================
-- КОНФИГУРАЦИЯ
-- ============================================================
GRM.Movement.Config = {
    WalkSpeed       = 160,
    RunSpeed        = 220,
    ExhaustedSpeed  = 80,
    StaminaMax      = 100,
    StaminaDrain    = 16,
    StaminaJumpCost = 15,
    StaminaRegen    = 8,
    JumpCooldown    = 0.5,
    BhopLimit       = 20,
    StaminaWarningThreshold = 30,
}

-- ============================================================
-- СЕРВЕР
-- ============================================================
if SERVER then
    local playerData = {}

    local function getPlayerData(ply)
        local sid = ply:SteamID64()
        if not playerData[sid] then
            playerData[sid] = {
                stamina = GRM.Movement.Config.StaminaMax,
                lastJump = 0,
            }
        end
        return playerData[sid]
    end

    local function syncStamina(ply)
        if not IsValid(ply) then return end
        local data = getPlayerData(ply)
        net.Start("GRM_Stamina_Sync")
        net.WriteFloat(data.stamina)
        net.Send(ply)
    end

    timer.Create("GRM_StaminaTick", 0.1, 0, function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and not ply:InVehicle() then
                local data = getPlayerData(ply)
                local isRunning = ply:KeyDown(IN_SPEED) and ply:GetVelocity():Length2D() > 50
                local isOnGround = ply:IsOnGround()

                if isRunning and isOnGround then
                    data.stamina = math.max(0, data.stamina - GRM.Movement.Config.StaminaDrain * 0.1)
                else
                    if isOnGround then
                        data.stamina = math.min(GRM.Movement.Config.StaminaMax, data.stamina + GRM.Movement.Config.StaminaRegen * 0.1)
                    end
                end

                syncStamina(ply)
            end
        end
    end)

    hook.Add("Move", "GRM_Movement_Move", function(ply, mv)
        if not IsValid(ply) then return end
        -- В транспорте стамина не влияет на скорость
        if ply:InVehicle() then return end
        
        local data = getPlayerData(ply)
        local isOnGround = ply:IsOnGround()
        local isRunning = ply:KeyDown(IN_SPEED)
        local vel = mv:GetVelocity()
        local speed = vel:Length2D()

        local maxSpeed
        if isOnGround and isRunning and data.stamina > 0 then
            maxSpeed = GRM.Movement.Config.RunSpeed
        elseif isOnGround and not isRunning then
            maxSpeed = GRM.Movement.Config.WalkSpeed
        else
            maxSpeed = GRM.Movement.Config.WalkSpeed * (1 + GRM.Movement.Config.BhopLimit / 100)
        end

        if isOnGround and data.stamina <= 0 then
            maxSpeed = math.min(maxSpeed, GRM.Movement.Config.ExhaustedSpeed)
        end

        if speed > maxSpeed then
            local ratio = maxSpeed / speed
            mv:SetVelocity(Vector(vel.x * ratio, vel.y * ratio, vel.z))
        end

        if ply:KeyPressed(IN_JUMP) and isOnGround then
            if CurTime() - data.lastJump < GRM.Movement.Config.JumpCooldown then
                mv:SetVelocity(Vector(vel.x, vel.y, 0))
                return
            end
            if data.stamina >= GRM.Movement.Config.StaminaJumpCost then
                data.stamina = data.stamina - GRM.Movement.Config.StaminaJumpCost
                data.lastJump = CurTime()
            else
                mv:SetVelocity(Vector(vel.x, vel.y, 0))
            end
        end
    end)

    hook.Add("PlayerInitialSpawn", "GRM_Movement_Init", function(ply)
        timer.Simple(0.5, function()
            if IsValid(ply) then
                getPlayerData(ply)
                syncStamina(ply)
            end
        end)
    end)

    hook.Add("InitPostEntity", "GRM_Movement_ClearData", function()
        playerData = {}
    end)

    print("[GRM] Movement System (сервер) загружена")
end

-- ============================================================
-- КЛИЕНТ
-- ============================================================
if CLIENT then
    CreateClientConVar("grm_cl_staminahud", "1", true, false) -- F4 → Настройки
    GRM.LocalStamina = GRM.LocalStamina or GRM.Movement.Config.StaminaMax

    local breathSound = nil
    local isBreathing = false

    -- Создаём звуковой объект при загрузке
    hook.Add("InitPostEntity", "GRM_Movement_InitSound", function()
        breathSound = CreateSound(LocalPlayer(), "player/breathe1.wav")
        if breathSound then
            breathSound:SetSoundLevel(70) -- громкость
        end
    end)

    -- При переподключении или смене карты пересоздаём звук
    hook.Add("PlayerInitialSpawn", "GRM_Movement_ReinitSound", function(ply)
        if ply ~= LocalPlayer() then return end
        if breathSound then
            breathSound:Stop()
            breathSound = nil
        end
        timer.Simple(0.5, function()
            if IsValid(LocalPlayer()) then
                breathSound = CreateSound(LocalPlayer(), "player/breathe1.wav")
                if breathSound then
                    breathSound:SetSoundLevel(70)
                end
            end
        end)
    end)

    -- Управление звуком усталости
    hook.Add("Think", "GRM_StaminaSound", function()
        local stamina = GRM.LocalStamina or 0
        local maxStamina = GRM.Movement.Config.StaminaMax
        local threshold = maxStamina * (GRM.Movement.Config.StaminaWarningThreshold / 100)

        -- Звук должен играть: стамина > 0 и стамина <= порога (30%)
        local shouldPlay = stamina > 0 and stamina <= threshold
        local isPlaying = isBreathing

        if shouldPlay and not isPlaying then
            -- Начинаем играть
            if breathSound then
                breathSound:Play()
                isBreathing = true
            end
        elseif not shouldPlay and isPlaying then
            -- Останавливаем звук
            if breathSound then
                breathSound:Stop()
                isBreathing = false
            end
        end

        -- Дополнительно: если стамина == 100%, гарантированно останавливаем
        if stamina >= maxStamina and isPlaying then
            if breathSound then
                breathSound:Stop()
                isBreathing = false
            end
        end
    end)

    -- Очистка при выходе или закрытии
    hook.Add("ShutDown", "GRM_Movement_CleanupSound", function()
        if breathSound then
            breathSound:Stop()
            breathSound = nil
        end
    end)

    -- Синхронизация стамины с сервера
    net.Receive("GRM_Stamina_Sync", function()
        GRM.LocalStamina = net.ReadFloat()
        hook.Run("GRM_StaminaUpdated", GRM.LocalStamina)
    end)

    -- Полоса выносливости (центр снизу, над HUD)
    hook.Add("HUDPaint", "GRM_Movement_StaminaHUD", function()
        local cv = GetConVar("grm_cl_staminahud")
        if cv and cv:GetInt() == 0 then return end
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end
        local stamina = GRM.LocalStamina or 0
        local maxStamina = GRM.Movement.Config.StaminaMax

        local sw, sh = ScrW(), ScrH()
        local barW, barH = 250, 14
        local x = (sw - barW) / 2
        local y = sh - 66 -- над основным HUD

        draw.RoundedBox(4, x, y, barW, barH, Color(30, 32, 40, 200))

        local frac = math.Clamp(stamina / maxStamina, 0, 1)
        local color = Color(80, 220, 200)
        if frac < 0.3 then color = Color(220, 80, 80)
        elseif frac < 0.6 then color = Color(220, 200, 80) end
        draw.RoundedBox(4, x, y, barW * frac, barH, color)

        draw.SimpleText("Выносливость", "GRM_HUD_Label", x + 10, y - 16, Color(160, 165, 175, 255), TEXT_ALIGN_LEFT)
        draw.SimpleText(math.floor(stamina) .. "%", "GRM_HUD_Value", x + barW - 10, y + barH / 2, Color(255,255,255,240), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end)

    -- Статус движения (центр, над полосой)
    hook.Add("HUDPaint", "GRM_Movement_StatusHUD", function()
        local ply = LocalPlayer()
        if not IsValid(ply) or not ply:Alive() then return end
        local stamina = GRM.LocalStamina or 0
        local isRunning = ply:KeyDown(IN_SPEED)
        local vel = ply:GetVelocity():Length2D()
        local isMoving = vel > 50

        local status = "Ходьба"
        local color = Color(200,200,200)

        if isMoving then
            if isRunning then
                if stamina > 0 then
                    status = "Бег"
                    color = Color(80,220,200)
                else
                    status = "Выдохся"
                    color = Color(220,80,80)
                end
            else
                status = "Ходьба"
                color = Color(200,200,200)
            end
        else
            status = "Стою"
            color = Color(150,150,150)
        end

        local sw, sh = ScrW(), ScrH()
        draw.SimpleText(status, "GRM_HUD_Label", sw/2, sh - 100, color, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
    end)

    print("[GRM] Movement System (клиент) загружена")
end
