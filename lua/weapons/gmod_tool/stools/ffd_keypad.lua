--[[--------------------------------------------------------------------
    FFD Keypad — Toolgun Module (Код 70, форма Кода 107)
    Инструмент установки электронного Кейпада (grm_keypad) — ТОЛЬКО PIN.
    Фракционный доступ переехал в FFD Scanner (стул ffd_scanner). Толл
    и режим-переключатель удалены из панели и спавна.

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

if CLIENT then
    language.Add("tool.ffd_keypad.name", "FFD Keypad (Кодовый замок)")
    language.Add("tool.ffd_keypad.desc", "Размещает электронный кейпад — доступ ТОЛЬКО по PIN-коду (фракции — у FFD Scanner)")
    language.Add("tool.ffd_keypad.0", "ЛКМ: Установить Кейпад | ПКМ: Скопировать настройки с объекта")
    -- алиас-стул «keypad» (include-обёртка) — те же подписи, иначе #tool.keypad.*
    language.Add("tool.keypad.name", "FFD Keypad (Кодовый замок)")
    language.Add("tool.keypad.desc", "Размещает электронный кейпад — доступ ТОЛЬКО по PIN-коду (фракции — у FFD Scanner)")
    language.Add("tool.keypad.0", "ЛКМ: Установить Кейпад | ПКМ: Скопировать настройки с объекта")
end

-- ============================================================
-- СЕРВЕРНАЯ ЛОГИКА СОЗДАНИЯ КЕЙПАДА
-- ============================================================
if SERVER then
    function TOOL:SpawnKeypad(ply, trace, pass, kGranted, kDenied, holdTime)
        if not IsValid(ply) or not trace.Hit then return false end

        local ent = ents.Create("grm_keypad")
        if not IsValid(ent) then return false end

        -- Код 104 (находка 121): кейпад-модель смотрит лицом в +X,
        -- любые доп. повороты КЛАДУТ её набок. Чистый HitNormal:Angle().
        ent:SetPos(trace.HitPos + trace.HitNormal * 1.2)
        ent:SetAngles(trace.HitNormal:Angle())

        ent.KeypadOwner = ply
        ent.KeyGranted = math.Clamp(tonumber(kGranted) or 1, 1, 9)
        ent.KeyDenied = math.Clamp(tonumber(kDenied) or 2, 1, 9)
        ent.HoldTime = math.max(0.5, tonumber(holdTime) or 5)

        ent:Spawn()
        ent:Activate()

        -- Код 107: пароль ТРИМИТСЯ (хвостовой пробел из поля ввода давал
        -- «верный PIN → отказ», до Кода 106 маскировался байпасом)
        local pw = string.Trim(tostring(pass or "1234"))
        ent:SetPassword(pw ~= "" and pw or "1234")
        ent:SetMode(0) -- только PIN, навсегда
        ent:SetCost(0)
        ent:SetFaction("")

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

    local ok = self:SpawnKeypad(ply, trace, pass, kGranted, kDenied, holdTime)

    if ok and GRM and GRM.Notify then
        GRM.Notify(ply, "FFD Keypad успешно установлен (режим: только PIN)!", 100, 220, 100)
    end

    return ok
end

function TOOL:RightClick(trace)
    local ent = trace.Entity
    if not IsValid(ent) or ent:GetClass() ~= "grm_keypad" then return false end

    if SERVER then
        local ply = self:GetOwner()
        ply:ConCommand("ffd_keypad_password " .. string.Trim(tostring(ent:GetPassword())))
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
    panel:AddControl("Header", { Description = "Кодовый замок FFD Keypad — доступ ТОЛЬКО по PIN-коду. Фракционный доступ проверяет FFD Scanner (отдельный инструмент)." })

    -- Код 102/105 (находка 119/122): хелпер DForm — настоящий живой
    -- контрол (голый AddControl("TextEntry") молча пропускался).
    if panel.TextEntry then
        panel:TextEntry("Пароль (PIN-код):", "ffd_keypad_password")
    else
        panel:AddControl("TextBox", { Label = "Пароль (PIN-код):", Command = "ffd_keypad_password" })
    end

    panel:AddControl("Numpad", { Label = "Сигнал успешного входа (Granted):", Command = "ffd_keypad_key_granted" })
    panel:AddControl("Numpad", { Label = "Сигнал отказа (Denied):", Command = "ffd_keypad_key_denied" })

    panel:AddControl("Slider", { Label = "Время задержки сигнала (сек):", Command = "ffd_keypad_hold_time", Type = "Float", Min = 1, Max = 30 })
end
