--[[--------------------------------------------------------------------
    FFD Scanner — Toolgun Module (Код 107)
    Инструмент установки сканера фракционного доступа (grm_scanner):
    никакого ввода кода — человек подходит и жмёт [E], сканер решает по
    его фракции (белый список ниже). Кейпад (FFD Keypad) оставлен только
    для PIN-кода — это ПАРА инструментов, а не конкуренты.

    ЛКМ: Разместить Сканер на поверхности
    ПКМ: Скопировать настройки с существующего Сканера
----------------------------------------------------------------------]]

TOOL.Category = "GRM"
TOOL.Name = "FFD Scanner"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar["key_granted"] = "1"
TOOL.ClientConVar["key_denied"] = "2"
TOOL.ClientConVar["hold_time"] = "4"
TOOL.ClientConVar["faction"] = ""

if CLIENT then
    language.Add("tool.ffd_scanner.name", "FFD Scanner (Сканер фракций)")
    language.Add("tool.ffd_scanner.desc", "Размещает сканер: человек жмёт [E] — сканер проверяет его фракцию по белому списку и открывает двери")
    language.Add("tool.ffd_scanner.0", "ЛКМ: Установить Сканер | ПКМ: Скопировать настройки с объекта")
end

-- ============================================================
-- СЕРВЕРНАЯ ЛОГИКА СОЗДАНИЯ СКАНЕРА
-- ============================================================
if SERVER then
    function TOOL:SpawnScanner(ply, trace, kGranted, kDenied, holdTime, faction)
        if not IsValid(ply) or not trace.Hit then return false end

        local ent = ents.Create("grm_scanner")
        if not IsValid(ent) then return false end

        -- та же доказанная геометрия, что у кейпада (находка 121):
        -- модель лицом в +X, чистый HitNormal:Angle() без поворотов
        ent:SetPos(trace.HitPos + trace.HitNormal * 1.2)
        ent:SetAngles(trace.HitNormal:Angle())

        ent.ScannerOwner = ply
        ent.KeyGranted = math.Clamp(tonumber(kGranted) or 1, 1, 9)
        ent.KeyDenied = math.Clamp(tonumber(kDenied) or 2, 1, 9)
        ent.HoldTime = math.max(0.5, tonumber(holdTime) or 4)

        ent:Spawn()
        ent:Activate()

        ent:SetFaction(tostring(faction or ""))

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false) -- автозаморозка на стене
        end

        undo.Create("FFD Scanner")
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
    local kGranted = self:GetClientNumber("key_granted", 1)
    local kDenied = self:GetClientNumber("key_denied", 2)
    local holdTime = self:GetClientNumber("hold_time", 4)
    local faction = self:GetClientInfo("faction")

    local ok = self:SpawnScanner(ply, trace, kGranted, kDenied, holdTime, faction)

    if ok and GRM and GRM.Notify then
        GRM.Notify(ply, "FFD Scanner установлен — доступ по фракции стоящего рядом!", 100, 220, 100)
    end

    return ok
end

function TOOL:RightClick(trace)
    local ent = trace.Entity
    if not IsValid(ent) or ent:GetClass() ~= "grm_scanner" then return false end

    if SERVER then
        local ply = self:GetOwner()
        ply:ConCommand("ffd_scanner_faction " .. tostring(ent:GetFaction()))
        ply:ConCommand("ffd_scanner_hold_time " .. tostring(ent.HoldTime or 4))

        if GRM and GRM.Notify then
            GRM.Notify(ply, "Настройки Сканера скопированы!", 100, 220, 255)
        end
    end

    return true
end

-- ============================================================
-- VGUI ПАНЕЛЬ НАСТРОЙКИ В МЕНЮ ИНСТРУМЕНТОВ
-- ============================================================
function TOOL.BuildCPanel(panel)
    panel:AddControl("Header", { Description = "Сканер решает по фракции стоящего рядом человека (проверка строгая — владелец и админ тоже сканируются). Ввод кода ему не нужен." })

    -- Окошко фракций с чекбоксами (находка 123): источник списка на
    -- клиенте — живой кэш FactionsData (синк Factions_SyncAll из
    -- sh_factions.lua); запасной — серверный глобал Factions. Окно
    -- строится ВСЕГДА и само перестраивается, когда синк подтянулся.
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
        local cv = GetConVar and GetConVar("ffd_scanner_faction")
        for name in string.gmatch((cv and cv:GetString()) or "", "([^,]+)") do
            cur[string.Trim(name)] = true
        end
        return cur
    end

    panel:Help("Фракции с доступом (белый список):")
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
                    RunConsoleCommand("ffd_scanner_faction", table.concat(out, ","))
                end
            end
        else
            wrap:SetTall(28)
            local te = vgui.Create("DTextEntry", wrap)
            te:Dock(TOP) te:DockMargin(6, 2, 0, 2)
            if te.SetUpdateOnType then te:SetUpdateOnType(true) end
            if te.SetConVar then te:SetConVar("ffd_scanner_faction") end
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

    panel:AddControl("Numpad", { Label = "Сигнал успешного допуска (Granted):", Command = "ffd_scanner_key_granted" })
    panel:AddControl("Numpad", { Label = "Сигнал отказа (Denied):", Command = "ffd_scanner_key_denied" })

    panel:AddControl("Slider", { Label = "Время удержания дверей (сек):", Command = "ffd_scanner_hold_time", Type = "Float", Min = 1, Max = 30 })
end
