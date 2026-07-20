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
    -- алиас-стул «keypad» (include-обёртка) — те же подписи, иначе #tool.keypad.*
    language.Add("tool.keypad.name", "FFD Keypad (Кодовый замок)")
    language.Add("tool.keypad.desc", "Размещает электронный кейпад с PIN-кодом, поддержкой платного прохода и фракций")
    language.Add("tool.keypad.0", "ЛКМ: Установить Кейпад | ПКМ: Скопировать настройки с объекта")
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

    -- Код 102/105 (находка 119/122): тот же исправленный путь, что и кейпад-моды —
    -- хелпер DForm: настоящий живой контрол. Голый AddControl("TextEntry")
    -- в этом билде GMod имени контрола НЕ знает и молча пропускал (замечание
    -- владельца «нет поля для ввода PIN-кода»).
    if panel.TextEntry then
        panel:TextEntry("Пароль (PIN-код):", "ffd_keypad_password")
    else
        panel:AddControl("TextBox", { Label = "Пароль (PIN-код):", Command = "ffd_keypad_password" })
    end

    -- Код 102 (находка 119): рукомесный vgui.Create+"combo:SetDock" падал
    -- (SetDock — несуществующий метод), панель инструмента вылетала целиком.
    -- Стандартный хелпер DForm сам докирует и синкает конвар.
    local combo = panel:ComboBox("Режим работы:", "ffd_keypad_mode")
    if IsValid(combo) then
        combo:AddChoice("0: Пароль (PIN-код)", 0)
        combo:AddChoice("1: Доступ по Фракции", 1)
        combo:AddChoice("2: Платный проход (GRM Cash)", 2)
    end

    -- Код 104/106 (находки 121/123): окошко фракций с чекбоксами.
    -- Источник списка НА КЛИЕНТЕ — живой кэш FactionsData (полный синк
    -- Factions_SyncAll из sh_factions.lua при входе и изменениях).
    -- Серверный глобал Factions на клиенте равен НИЛ — Код 104 из-за
    -- этого показывал одно текстовое поле (замечание владельца «окна с
    -- фракциями нету, нужна интерактивность»). Окно строится ВСЕГДА и
    -- само перестраивается: синк пришёл/фракции изменились — чекбоксы
    -- подтянутся без переоткрытия панели (Think-подпись раз в 0.5с).
    local function grmFactionNames()
        local src = (istable(FactionsData) and next(FactionsData) and FactionsData)
            or (istable(Factions) and next(Factions) and Factions)
        if not src then return nil end
        local names = {}
        for name in pairs(src) do names[#names + 1] = tostring(name) end
        table.sort(names)
        return names
    end

    local function readCheckedSet()
        local cur = {}
        local cv = GetConVar and GetConVar("ffd_keypad_faction")
        for name in string.gmatch((cv and cv:GetString()) or "", "([^,]+)") do
            cur[string.Trim(name)] = true
        end
        return cur
    end

    panel:Help("Фракции с доступом (режим «Доступ по Фракции»):")
    local wrap = vgui.Create("DPanel", panel)
    wrap:SetPaintBackground(false)
    wrap:SetTall(30)
    wrap.__sig = nil
    wrap.__nextThink = 0

    local function rebuildWrap(names)
        wrap:Clear()
        local cur = readCheckedSet()
        if names then
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
                    for _, n2 in ipairs(names) do
                        if cur[n2] then out[#out + 1] = n2 end
                    end
                    RunConsoleCommand("ffd_keypad_faction", table.concat(out, ","))
                end
            end
        else
            -- данных фракций пока нет (синк не пришёл): ручное поле —
            -- как только синк подтянется, Think перестроит на чекбоксы
            wrap:SetTall(28)
            local te = vgui.Create("DTextEntry", wrap)
            te:Dock(TOP) te:DockMargin(6, 2, 0, 2)
            if te.SetUpdateOnType then te:SetUpdateOnType(true) end
            if te.SetConVar then te:SetConVar("ffd_keypad_faction") end
            if te.SetTooltip then te:SetTooltip("Фракции ещё не синхронизированы — впишите вручную через запятую; при первом синке здесь появятся чекбоксы") end
        end
    end

    local names0 = grmFactionNames()
    wrap.__sig = names0 and table.concat(names0, "\1") or ""
    rebuildWrap(names0)

    wrap.Think = function(self)
        local now = CurTime()
        if now < (self.__nextThink or 0) then return end
        self.__nextThink = now + 0.5
        local names = grmFactionNames()
        local sig = names and table.concat(names, "\1") or ""
        if sig ~= self.__sig then
            self.__sig = sig
            rebuildWrap(names)
        end
    end

    panel:AddItem(wrap)

    panel:AddControl("Numpad", { Label = "Сигнал успешного входа (Granted):", Command = "ffd_keypad_key_granted" })
    panel:AddControl("Numpad", { Label = "Сигнал отказа (Denied):", Command = "ffd_keypad_key_denied" })

    panel:AddControl("Slider", { Label = "Время задержки сигнала (сек):", Command = "ffd_keypad_hold_time", Type = "Float", Min = 1, Max = 30 })
    panel:AddControl("Slider", { Label = "Плата за проход (GRM Cash):", Command = "ffd_keypad_cost", Type = "Int", Min = 0, Max = 100000 })
end
