--[[--------------------------------------------------------------------
    grm_keypad — init.lua (Серверный обработчик кейпада)
    Код 104 (находка 121): кнопки нажимаются ПРИЦЕЛОМ + E (как в модовых
    кейпадах: навёл на цифру — нажал, старый общий [E]=OK убран, чтобы не
    было двойных срабатываний); белый список фракций — СПИСОК через
    запятую (чекбоксы в панели тулгана); вспышка кнопки на экране у всех
    клиентов через net GRM_KeypadPress.
----------------------------------------------------------------------]]

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

util.AddNetworkString("GRM_KeypadPress")

-- ============================================================
-- Код 105 (находка 122): админский ПЕРМ-кейпад. Данные кейпада едут в
-- базу перм-энтити (sh_grm_perm_entities v1.3.0): /permadd по кейпаду
-- фиксирует PIN/режим/цену/список фракций/кнопки сигналов/задержку/
-- владельца — после рестарта сервера или админ-перезагрузки кейпад
-- встаёт на место ГОТОВЫМ К РАБОТЕ, а не пустышкой с 1234.
-- ============================================================
local function keypadPermExtract(ent)
    return {
        password = tostring(ent:GetPassword() or "1234"),
        mode     = tonumber(ent:GetMode()) or 0,
        cost     = tonumber(ent:GetCost()) or 0,
        faction  = tostring(ent:GetFaction() or ""),
        granted  = tonumber(ent.KeyGranted) or 1,
        denied   = tonumber(ent.KeyDenied) or 2,
        hold     = tonumber(ent.HoldTime) or 5,
        owner    = (IsValid(ent.KeypadOwner) and tostring(ent.KeypadOwner:SteamID64() or "")) or tostring(ent.OwnerSID64 or ""),
    }
end
local function keypadPermApply(ent, t)
    ent:SetPassword(tostring(t.password or "1234"))
    ent:SetMode(tonumber(t.mode) or 0)
    ent:SetCost(tonumber(t.cost) or 0)
    ent:SetFaction(tostring(t.faction or ""))
    ent.KeyGranted = math.Clamp(tonumber(t.granted) or 1, 1, 9)
    ent.KeyDenied  = math.Clamp(tonumber(t.denied) or 2, 1, 9)
    ent.HoldTime   = math.max(0.5, tonumber(t.hold) or 5)
    ent.OwnerSID64 = tostring(t.owner or "")
    if ent.OwnerSID64 ~= "" then
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and tostring(p:SteamID64() or "") == ent.OwnerSID64 then
                ent.KeypadOwner = p
                break
            end
        end
    end
end
GRM = GRM or {}
GRM.PermData = GRM.PermData or { Extract = {}, Apply = {} }
GRM.PermData.Extract = GRM.PermData.Extract or {}
GRM.PermData.Apply = GRM.PermData.Apply or {}
GRM.PermData.Extract["grm_keypad"] = keypadPermExtract
GRM.PermData.Apply["grm_keypad"] = keypadPermApply

function ENT:Initialize()
    self:SetModel("models/props_lab/keypad.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end

    self:SetStatus(0)
    self:SetDisplayText("")
    self.CurrentInput = ""

    self.KeyGranted = self.KeyGranted or 1
    self.KeyDenied = self.KeyDenied or 2
    self.HoldTime = self.HoldTime or 5

    self:SetMode(self.Mode or 0)
    self:SetCost(self.Cost or 0)
    self:SetFaction(self.Faction or "")
end

function ENT:ProcessGrant(ply)
    if self:IsKeypadLocked() then return end

    self:SetStatus(1) -- Granted
    self.IsGrantActive = true
    self:EmitSound("buttons/button3.wav", 75, 100)

    -- Посылаем сигнал Numpad
    if self.KeypadOwner and IsValid(self.KeypadOwner) then
        numpad.Activate(self.KeypadOwner, self.KeyGranted)
    end

    -- Находим все Fading Door рядом
    local nearProps = ents.FindInSphere(self:GetPos(), 250)
    for _, prop in ipairs(nearProps) do
        if IsValid(prop) and prop.isFadingDoor and prop.FadeActivate then
            prop:FadeActivate()
        end
    end

    -- Удерживаем сигнал
    local hold = math.max(0.5, tonumber(self.HoldTime) or 5)
    timer.Create("GRM_Keypad_Grant_" .. self:EntIndex(), hold, 1, function()
        if not IsValid(self) then return end
        self:SetStatus(0)
        self:SetDisplayText("")
        self.CurrentInput = ""
        self.IsGrantActive = false

        if self.KeypadOwner and IsValid(self.KeypadOwner) then
            numpad.Deactivate(self.KeypadOwner, self.KeyGranted)
        end

        for _, prop in ipairs(nearProps) do
            if IsValid(prop) and prop.isFadingDoor and prop.FadeDeactivate then
                prop:FadeDeactivate()
            end
        end
    end)
end

function ENT:ProcessDeny(ply)
    if self:IsKeypadLocked() then return end

    self:SetStatus(2) -- Denied
    self.CurrentInput = ""
    self:EmitSound("buttons/button10.wav", 75, 100)

    if self.KeypadOwner and IsValid(self.KeypadOwner) then
        numpad.Activate(self.KeypadOwner, self.KeyDenied)
        timer.Simple(1.5, function()
            if IsValid(self) and IsValid(self.KeypadOwner) then
                numpad.Deactivate(self.KeypadOwner, self.KeyDenied)
            end
        end)
    end

    timer.Create("GRM_Keypad_Deny_" .. self:EntIndex(), 1.8, 1, function()
        if not IsValid(self) then return end
        self:SetStatus(0)
        self:SetDisplayText("")
    end)
end

function ENT:PressButton(btn, ply)
    if self:IsKeypadLocked() then return end

    local mode = self:GetMode()

    -- Платный режим (Toll Mode)
    if mode == 2 then
        local price = self:GetCost()
        if price > 0 and GRM and GRM.HasMoney and GRM.TakeMoney then
            if not GRM.HasMoney(ply, price) then
                if GRM.Notify then GRM.Notify(ply, "Недостаточно денег для прохода (" .. price .. " GRM)", 255, 100, 100) end
                self:ProcessDeny(ply)
                return
            end
            GRM.TakeMoney(ply, price, "Платный проход через Кейпад")
            if GRM.Notify then GRM.Notify(ply, "Оплачено " .. price .. " GRM. Доступ разрешён!", 100, 220, 100) end
        end
        self:ProcessGrant(ply)
        return
    end

    -- Фракционный режим (Faction Mode) — Код 104: список через запятую
    if mode == 1 then
        local plyFac = nil
        if Factions and IsValid(ply) then
            for fName, fData in pairs(Factions) do
                if istable(fData) and istable(fData.Members) and (fData.Members[ply:SteamID()] or fData.Members[ply:SteamID64()]) then
                    plyFac = fName break
                end
            end
        end

        if ply:IsSuperAdmin() or self:IsFactionAllowed(plyFac) or self:IsKeypadOwner(ply) then
            self:ProcessGrant(ply)
        else
            if GRM.Notify then GRM.Notify(ply, "Доступ ограничен фракцией [" .. string.Trim(tostring(self:GetFaction() or "")) .. "]", 255, 100, 100) end
            self:ProcessDeny(ply)
        end
        return
    end

    -- PIN-код режим (Password Mode)
    if btn == "CLR" then
        self.CurrentInput = ""
        self:SetDisplayText("")
        self:EmitSound("buttons/button14.wav", 60, 120)
        return
    end

    if btn == "OK" then
        -- Код 106 (находка 123): PIN-режим — СТРОГОЕ сравнение ДЛЯ ВСЕХ.
        -- Байпасы владельца/суперадмина (Код 104/105) делали кейпад
        -- «неразличающим»: владелец сервера тестирует со своего
        -- суперадмин-аккаунта, и ЛЮБОЙ ввод открывал дверь. Теперь:
        -- хочешь открыть — знай PIN (владелец и админ тоже). Байпас
        -- владельца/админа остаётся только в фракционном режиме выше.
        local targetPass = tostring(self:GetPassword() or "")
        if self.CurrentInput ~= "" and self.CurrentInput == targetPass then
            self:ProcessGrant(ply)
        else
            self:ProcessDeny(ply)
        end
        return
    end

    if #self.CurrentInput < 6 then
        self.CurrentInput = self.CurrentInput .. tostring(btn)
        self:SetDisplayText(string.rep("*", #self.CurrentInput))
        self:EmitSound("buttons/button14.wav", 60, 100 + #self.CurrentInput * 5)
    end
end

function ENT:Use(ply)
    -- Код 104: общий E=OK убран — кнопки жмутся прицелом (см. хук ниже),
    -- чтобы не было двойных срабатываний «и цифра, и OK».
end

-- ============================================================
-- Код 104 (находка 121): нажатие кнопок ПРИЦЕЛОМ + E.
-- Сервер сам считает, какая кнопка под HitPos (геометрия общая, shared),
-- клиент ничего не шлёт — протокол не расширяем пользовательским вводом.
-- ============================================================
hook.Add("KeyPress", "GRM_Keypad_AimPress", function(ply, key)
    if key ~= IN_USE then return end
    if not IsValid(ply) then return end
    local tr = ply:GetEyeTrace()
    if not tr then return end
    local ent = tr.Entity
    if not (IsValid(ent) and ent:GetClass() == "grm_keypad") then return end
    if ply:GetShootPos():DistToSqr(ent:GetPos()) > (130 * 130) then return end
    local now = CurTime()
    if (ply.__grmKeypadNextPress or 0) > now then return end
    ply.__grmKeypadNextPress = now + 0.15 -- лёгкий анти-дабл
    local idx, b = ent:KeypadButtonAt(tr.HitPos)
    if not (idx and b) then return end
    ent:PressButton(b.text, ply)
    -- вспышка нажатой кнопки на экранах всех клиентов
    net.Start("GRM_KeypadPress")
        net.WriteEntity(ent)
        net.WriteUInt(idx, 8)
    net.Broadcast()
end)
