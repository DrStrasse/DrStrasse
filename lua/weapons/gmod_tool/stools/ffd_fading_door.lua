--[[--------------------------------------------------------------------
    FFD Fading Door — Toolgun Module (Код 69)
    Надёжная переработанная система Fading Door с поддержкой Numpad,
    автоматического закрытия, инверсии и прямой интеграции с Кейпадами.

    ЛКМ: Создать / Обновить Fading Door на пропе
    ПКМ: Снять статус Fading Door с пропа
    R: Скопировать настройки с пропа
----------------------------------------------------------------------]]

TOOL.Category = "GRM"
TOOL.Name = "FFD Fading Door"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["key"] = "1"
TOOL.ClientConVar["reversed"] = "0"
TOOL.ClientConVar["toggle"] = "1"
TOOL.ClientConVar["autoclose"] = "0"
TOOL.ClientConVar["time"] = "5"

if CLIENT then
    language.Add("tool.ffd_fading_door.name", "FFD Fading Door (Исчезающая дверь)")
    language.Add("tool.ffd_fading_door.desc", "Превращает любой проп в исчезающую дверь с нумпадом и таймером")
    language.Add("tool.ffd_fading_door.0", "ЛКМ: Применить Fading Door | ПКМ: Снять с пропа | R: Скопировать настройки")
end

-- ============================================================
-- СЕРВЕРНАЯ ЛОГИКА FADING DOOR
-- ============================================================
if SERVER then
    local function applyFadeState(ent, active)
        if not IsValid(ent) or not ent.isFadingDoor then return end

        local reverse = ent.FFD_Reversed == true
        local shouldFade = active
        if reverse then shouldFade = not active end

        if shouldFade then
            -- Скрытие и выключение коллизии
            ent:SetNotSolid(true)
            ent:SetRenderMode(RENDERMODE_TRANSCOLOR)
            ent:SetColor(Color(255, 255, 255, 40))
            ent:DrawShadow(false)

            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then phys:EnableCollisions(false) end

            ent.FFD_IsFaded = true
            ent:SetNWBool("FFD_Faded", true)
        else
            -- Проявление и возобновление коллизии
            ent:SetNotSolid(false)
            ent:SetRenderMode(RENDERMODE_NORMAL)
            ent:SetColor(Color(255, 255, 255, 255))
            ent:DrawShadow(true)

            local phys = ent:GetPhysicsObject()
            if IsValid(phys) then phys:EnableCollisions(true) end

            ent.FFD_IsFaded = false
            ent:SetNWBool("FFD_Faded", false)
        end
    end

    local function fadeOn(ply, ent)
        if not IsValid(ent) or not ent.isFadingDoor then return end
        if ent.FFD_IsActive then return end

        ent.FFD_IsActive = true
        applyFadeState(ent, true)
        ent:EmitSound("doors/door1_move.wav", 65, 110, 0.6)

        -- Автозакрытие по таймеру
        if ent.FFD_AutoClose and tonumber(ent.FFD_CloseTime) and ent.FFD_CloseTime > 0 then
            timer.Create("FFD_AutoClose_" .. ent:EntIndex(), ent.FFD_CloseTime, 1, function()
                if IsValid(ent) and ent.isFadingDoor and ent.FFD_IsActive then
                    fadeOff(ply, ent)
                end
            end)
        end
    end

    local function fadeOff(ply, ent)
        if not IsValid(ent) or not ent.isFadingDoor then return end
        if not ent.FFD_IsActive then return end

        timer.Remove("FFD_AutoClose_" .. ent:EntIndex())
        ent.FFD_IsActive = false
        applyFadeState(ent, false)
        ent:EmitSound("doors/door_latch1.wav", 65, 100, 0.6)
    end

    local function fadeToggle(ply, ent)
        if not IsValid(ent) or not ent.isFadingDoor then return end
        if ent.FFD_IsActive then
            fadeOff(ply, ent)
        else
            fadeOn(ply, ent)
        end
    end

    numpad.Register("FFD_Fade_On", function(ply, ent)
        if not IsValid(ent) or not ent.isFadingDoor then return end
        if ent.FFD_Toggle then
            fadeToggle(ply, ent)
        else
            fadeOn(ply, ent)
        end
    end)

    numpad.Register("FFD_Fade_Off", function(ply, ent)
        if not IsValid(ent) or not ent.isFadingDoor then return end
        if not ent.FFD_Toggle then
            fadeOff(ply, ent)
        end
    end)

    function TOOL:MakeFadingDoor(ply, ent, key, reversed, toggle, autoclose, closeTime)
        if not IsValid(ent) then return false end

        -- Очистка старых нумпад-импульсов
        if ent.isFadingDoor and ent.FFD_NumDown then
            numpad.Remove(ent.FFD_NumDown)
            numpad.Remove(ent.FFD_NumUp)
        end

        ent.isFadingDoor = true
        ent.FFD_Reversed = reversed == true or reversed == 1
        ent.FFD_Toggle = toggle == true or toggle == 1
        ent.FFD_AutoClose = autoclose == true or autoclose == 1
        ent.FFD_CloseTime = math.max(0.5, tonumber(closeTime) or 5)
        ent.FFD_Key = key

        -- Регистрация нумпад связи
        ent.FFD_NumDown = numpad.OnDown(ply, key, "FFD_Fade_On", ent)
        ent.FFD_NumUp = numpad.OnUp(ply, key, "FFD_Fade_Off", ent)

        -- Публичные API методы для связки с Кейпадом и Отмычкой
        ent.FadeActivate = function() fadeOn(ply, ent) end
        ent.FadeDeactivate = function() fadeOff(ply, ent) end
        ent.FadeToggle = function() fadeToggle(ply, ent) end

        -- Устанавливаем начальное состояние
        ent.FFD_IsActive = false
        applyFadeState(ent, false)

        duplicator.StoreEntityModifier(ent, "FFD_FadingDoor", {
            key = key,
            reversed = reversed,
            toggle = toggle,
            autoclose = autoclose,
            time = closeTime,
        })

        return true
    end

    duplicator.RegisterEntityModifier("FFD_FadingDoor", function(ply, ent, data)
        TOOL:MakeFadingDoor(ply, ent, data.key, data.reversed, data.toggle, data.autoclose, data.time)
    end)
end

function TOOL:LeftClick(trace)
    local ent = trace.Entity
    if not IsValid(ent) or ent:IsPlayer() or ent:IsNPC() or ent:IsWorld() then return false end

    if CLIENT then return true end

    local ply = self:GetOwner()
    local key = self:GetClientNumber("key", 1)
    local reversed = self:GetClientNumber("reversed", 0) == 1
    local toggle = self:GetClientNumber("toggle", 1) == 1
    local autoclose = self:GetClientNumber("autoclose", 0) == 1
    local time = self:GetClientNumber("time", 5)

    self:MakeFadingDoor(ply, ent, key, reversed, toggle, autoclose, time)

    if GRM and GRM.Notify then
        GRM.Notify(ply, "FFD Fading Door успешно настроен!", 100, 220, 100)
    end

    return true
end

function TOOL:RightClick(trace)
    local ent = trace.Entity
    if not IsValid(ent) or not ent.isFadingDoor then return false end

    if CLIENT then return true end

    local ply = self:GetOwner()

    timer.Remove("FFD_AutoClose_" .. ent:EntIndex())
    if ent.FFD_NumDown then numpad.Remove(ent.FFD_NumDown) end
    if ent.FFD_NumUp then numpad.Remove(ent.FFD_NumUp) end

    ent.isFadingDoor = nil
    ent.FFD_IsActive = nil
    ent.FFD_IsFaded = nil

    ent:SetNotSolid(false)
    ent:SetRenderMode(RENDERMODE_NORMAL)
    ent:SetColor(Color(255, 255, 255, 255))

    duplicator.ClearEntityModifier(ent, "FFD_FadingDoor")

    if GRM and GRM.Notify then
        GRM.Notify(ply, "Статус Fading Door снят с объекта.", 235, 180, 60)
    end

    return true
end

function TOOL:Reload(trace)
    local ent = trace.Entity
    if not IsValid(ent) or not ent.isFadingDoor then return false end

    if SERVER then
        local ply = self:GetOwner()
        ply:ConCommand("ffd_fading_door_key " .. tostring(ent.FFD_Key or 1))
        ply:ConCommand("ffd_fading_door_reversed " .. (ent.FFD_Reversed and "1" or "0"))
        ply:ConCommand("ffd_fading_door_toggle " .. (ent.FFD_Toggle and "1" or "0"))
        ply:ConCommand("ffd_fading_door_autoclose " .. (ent.FFD_AutoClose and "1" or "0"))
        ply:ConCommand("ffd_fading_door_time " .. tostring(ent.FFD_CloseTime or 5))

        if GRM and GRM.Notify then
            GRM.Notify(ply, "Настройки Fading Door скопированы!", 100, 220, 255)
        end
    end

    return true
end

-- ============================================================
-- VGUI ПАНЕЛЬ НАСТРОЙКИ В МЕНЮ ИНСТРУМЕНТОВ
-- ============================================================
function TOOL.BuildCPanel(panel)
    panel:AddControl("Header", { Description = "Создание исчезающей двери FFD Fading Door с нумпадом и гибокй настройкой." })

    panel:AddControl("Numpad", { Label = "Клавиша отпирания (Numpad):", Command = "ffd_fading_door_key" })

    panel:AddControl("Checkbox", { Label = "Режим переключателя (Toggle)", Command = "ffd_fading_door_toggle" })
    panel:AddControl("Checkbox", { Label = "Инверсия (Сначала открыто, нажатие закрывает)", Command = "ffd_fading_door_reversed" })
    panel:AddControl("Checkbox", { Label = "Автоматическое закрытие", Command = "ffd_fading_door_autoclose" })

    panel:AddControl("Slider", { Label = "Время задержки авто-закрытия (сек):", Command = "ffd_fading_door_time", Type = "Float", Min = 0.5, Max = 30 })
end
