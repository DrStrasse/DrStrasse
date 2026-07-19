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

        -- Код 104 (находка 121): кейпад-модель смотрит лицом в +X,
        -- любые доп. повороты КЛАДУТ её набок (скрин владельца). Чистый
        -- HitNormal:Angle() без RotateAroundAxis — как у модовых кейпадов.
        ent:SetPos(trace.HitPos + trace.HitNormal * 1.2)
        ent:SetAngles(trace.HitNormal:Angle())

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

    -- Код 102 (находка 119): рукомесный vgui.Create+"combo:SetDock" падал
    -- (SetDock — несуществующий метод), панель инструмента вылетала целиком.
    -- Стандартный хелпер DForm сам докирует и синкает конвар.
    local combo = panel:ComboBox("Режим работы:", "ffd_keypad_mode")
    if IsValid(combo) then
        combo:AddChoice("0: Пароль (PIN-код)", 0)
        combo:AddChoice("1: Доступ по Фракции", 1)
        combo:AddChoice("2: Платный проход (GRM Cash)", 2)
    end

    -- Код 104 (находка 121): окошко фракций с чекбоксами (замечание №1
    -- владельца). Для режима «Фракция» — можно выбрать НЕСКОЛЬКО, список
    -- летит в конвар ffd_keypad_faction через запятую (кейпад разберёт).
    if istable(Factions) and next(Factions) then
        panel:Help("Фракции с доступом (режим «Доступ по Фракции»):")
        local cur = {}
        local cvStr = ""
        local cv = GetConVar and GetConVar("ffd_keypad_faction")
        if cv then cvStr = cv:GetString() or "" end
        for name in string.gmatch(cvStr, "([^,]+)") do
            cur[string.Trim(name)] = true
        end
        local names = {}
        for name in pairs(Factions) do names[#names + 1] = name end
        table.sort(names)
        local wrap = vgui.Create("DPanel", panel)
        wrap:SetPaintBackground(false)
        wrap:SetTall(#names * 22 + 4)
        for _, name in ipairs(names) do
            local cb = vgui.Create("DCheckBoxLabel", wrap)
            cb:Dock(TOP) cb:DockMargin(6, 0, 0, 2)
            cb:SetText(name)
            cb:SetChecked(cur[name] == true)
            cb.facName = name
            cb.checked = cur[cb.facName] == true -- для сим-слежки
            cb.OnChange = function(self, v)
                cur[self.facName] = v == true
                self.checked = v == true          -- для сим-слежки
                local out = {}
                for _, n in ipairs(names) do
                    if cur[n] then out[#out + 1] = n end
                end
                RunConsoleCommand("ffd_keypad_faction", table.concat(out, ","))
            end
        end
        panel:AddItem(wrap)
    else
        -- фолбэк вне GRM-окружения: одна фракция текстом (legacy-поведение)
        panel:AddControl("TextEntry", { Label = "Фракция с доступом:", Command = "ffd_keypad_faction" })
    end

    panel:AddControl("Numpad", { Label = "Сигнал успешного входа (Granted):", Command = "ffd_keypad_key_granted" })
    panel:AddControl("Numpad", { Label = "Сигнал отказа (Denied):", Command = "ffd_keypad_key_denied" })

    panel:AddControl("Slider", { Label = "Время задержки сигнала (сек):", Command = "ffd_keypad_hold_time", Type = "Float", Min = 1, Max = 30 })
    panel:AddControl("Slider", { Label = "Плата за проход (GRM Cash):", Command = "ffd_keypad_cost", Type = "Int", Min = 0, Max = 100000 })
end
