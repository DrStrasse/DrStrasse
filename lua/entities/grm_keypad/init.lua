--[[--------------------------------------------------------------------
    grm_keypad — init.lua (Серверный обработчик кейпада)
----------------------------------------------------------------------]]

AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

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

    -- Фракционный режим (Faction Mode)
    if mode == 1 then
        local fac = self:GetFaction()
        local plyFac = nil
        if Factions and IsValid(ply) then
            for fName, fData in pairs(Factions) do
                if istable(fData) and istable(fData.Members) and (fData.Members[ply:SteamID()] or fData.Members[ply:SteamID64()]) then
                    plyFac = fName break
                end
            end
        end

        if ply:IsSuperAdmin() or (fac ~= "" and plyFac == fac) or (ply == self.KeypadOwner) then
            self:ProcessGrant(ply)
        else
            if GRM.Notify then GRM.Notify(ply, "Доступ ограничен фракцией [" .. (fac ~= "" and fac or "—") .. "]", 255, 100, 100) end
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
        local targetPass = self:GetPassword()
        if self.CurrentInput == targetPass or (ply == self.KeypadOwner or ply:IsSuperAdmin()) then
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
    if not IsValid(ply) then return end
    self:PressButton("OK", ply)
end
