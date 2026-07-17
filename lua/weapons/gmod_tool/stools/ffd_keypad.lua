--[[--------------------------------------------------------------------
    FFD Keypad — Toolgun Module (Код 70)
    Инструмент установки и настройки электронного Кейпада (grm_keypad).

    ЛКМ: Разместить Кейпад на поверхности
    ПКМ: Скопировать настройки с существующего Кейпада
----------------------------------------------------------------------]]

TOOL.Category = "GRM"
TOOL.Name = "FFD Keypad"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["password"] = "1234"
TOOL.ClientConVar["key_granted"] = "1"
TOOL.ClientConVar["key_denied"] = "2"
TOOL.ClientConVar["hold_time"] = "5"
TOOL.ClientConVar["mode"] = "0"          -- 0: PIN, 1: Faction, 2: Toll
TOOL.ClientConVar["cost"] = "0"
TOOL.ClientConVar["faction"] = ""

if CLIENT then
    language.Add("tool.ffd_keypad.name", "FFD Keypad (Кодовый замок)")
    language.Add("tool.ffd_keypad.desc", "Размещает электронный кейпад с PIN-кодом, поддержкой платного прохода и фракций")
    language.Add("tool.ffd_keypad.0", "ЛКМ: Установить Кейпад | ПКМ: Скопировать настройки с объекта")
end

-- ============================================================
-- СЕРВЕРНАЯ ЛОГИКА СОЗДАНИЯ КЕЙПАДА
-- ============================================================
if SERVER then
    function TOOL:SpawnKeypad(ply, trace, pass, kGranted, kDenied, holdTime, mode, cost, faction)
        if not IsValid(ply) or not trace.Hit then return false end

        local ent = ents.Create("grm_keypad")
        if not IsValid(ent) then return false end

        local ang = trace.HitNormal:Angle()
        ang:RotateAroundAxis(ang:Right(), -90)
        ang:RotateAroundAxis(ang:Up(), 180)

        ent:SetPos(trace.HitPos + trace.HitNormal * 1.5)
        ent:SetAngles(ang)

        ent.KeypadOwner = ply
        ent.KeyGranted = math.Clamp(tonumber(kGranted) or 1, 1, 9)
        ent.KeyDenied = math.Clamp(tonumber(kDenied) or 2, 1, 9)
        ent.HoldTime = math.max(0.5, tonumber(holdTime) or 5)

        ent:Spawn()
        ent:Activate()

        ent:SetPassword(tostring(pass or "1234"))
        ent:SetMode(tonumber(mode) or 0)
        ent:SetCost(math.max(0, math.floor(tonumber(cost) or 0)))
        ent:SetFaction(tostring(faction or ""))

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false) -- Автозаморозка на стене
        end

        undo.Create("FFD Keypad")
            undo.AddEntity(ent)
            undo.SetPlayer(ply)
        undo.Finish()

        return true
    end
end

function TOOL:LeftClick(trace)
    if not trace.Hit then return false end
    if CLIENT then return true end

    local ply = self:GetOwner()
    local pass = self:GetClientInfo("password")
    local kGranted = self:GetClientNumber("key_granted", 1)
    local kDenied = self:GetClientNumber("key_denied", 2)
    local holdTime = self:GetClientNumber("hold_time", 5)
    local mode = self:GetClientNumber("mode", 0)
    local cost = self:GetClientNumber("cost", 0)
    local faction = self:GetClientInfo("faction")

    local ok = self:SpawnKeypad(ply, trace, pass, kGranted, kDenied, holdTime, mode, cost, faction)

    if ok and GRM and GRM.Notify then
        GRM.Notify(ply, "FFD Keypad успешно установлен!", 100, 220, 100)
    end

    return ok
end

function TOOL:RightClick(trace)
    local ent = trace.Entity
    if not IsValid(ent) or ent:GetClass() ~= "grm_keypad" then return false end

    if SERVER then
        local ply = self:GetOwner()
        ply:ConCommand("ffd_keypad_password " .. tostring(ent:GetPassword()))
        ply:ConCommand("ffd_keypad_mode " .. tostring(ent:GetMode()))
        ply:ConCommand("ffd_keypad_cost " .. tostring(ent:GetCost()))
        ply:ConCommand("ffd_keypad_faction " .. tostring(ent:GetFaction()))
        ply:ConCommand("ffd_keypad_hold_time " .. tostring(ent.HoldTime or 5))

        if GRM and GRM.Notify then
            GRM.Notify(ply, "Настройки Кейпада скопированы!", 100, 220, 255)
        end
    end

    return true
end

-- ============================================================
-- VGUI ПАНЕЛЬ НАСТРОЙКИ В МЕНЮ ИНСТРУМЕНТОВ
-- ============================================================
function TOOL.BuildCPanel(panel)
    panel:AddControl("Header", { Description = "Настройка кодового замка FFD Keypad с поддержкой 3D2D дисплея и фракций." })

    panel:AddControl("TextEntry", { Label = "Пароль (PIN-код):", Command = "ffd_keypad_password" })

    local combo = vgui.Create("DComboBox", panel)
    combo:SetDock(TOP)
    combo:SetTall(28)
    combo:SetValue("Режим работы...")
    combo:AddChoice("0: Пароль (PIN-код)", 0)
    combo:AddChoice("1: Доступ по Фракции", 1)
    combo:AddChoice("2: Платный проход (GRM Cash)", 2)
    combo.OnSelect = function(_, _, _, data)
        RunConsoleCommand("ffd_keypad_mode", tostring(data))
    end
    panel:AddItem(combo)

    panel:AddControl("Numpad", { Label = "Сигнал успешного входа (Granted):", Command = "ffd_keypad_key_granted" })
    panel:AddControl("Numpad", { Label = "Сигнал отказа (Denied):", Command = "ffd_keypad_key_denied" })

    panel:AddControl("Slider", { Label = "Время задержки сигнала (сек):", Command = "ffd_keypad_hold_time", Type = "Float", Min = 1, Max = 30 })
    panel:AddControl("Slider", { Label = "Плата за проход (GRM Cash):", Command = "ffd_keypad_cost", Type = "Int", Min = 0, Max = 100000 })
end
