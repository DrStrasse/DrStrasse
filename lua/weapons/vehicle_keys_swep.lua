--[[--------------------------------------------------------------------
    GRM Vehicle Keys — SWEP

    LMB: lock / unlock
    RMB: open / close doors
    R: personal-owner key menu

    This file intentionally contains NO VK_Keys_Give / VK_Keys_Revoke
    net receivers. They are registered exclusively in sv_vehicle_keys.lua.
----------------------------------------------------------------------]]

AddCSLuaFile()

if not VK then include("autorun/sh_vehicle_keys.lua") end
VK = VK or {}

SWEP.PrintName = "Связка ключей транспорта"
SWEP.Author = "GRM"
SWEP.Instructions = "ЛКМ: замок | ПКМ: двери | R: управление личными ключами"
SWEP.Category = "GRM Vehicle Keys"
SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.DrawWeaponSelection = true
SWEP.ViewModel = "models/weapons/c_arms_citizen.mdl"
SWEP.WorldModel = ""
SWEP.UseHands = true
SWEP.HoldType = "normal"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

local ACTION_COOLDOWN = 0.55

local function interactionRange()
    return tonumber(VK.INTERACT_RANGE) or 180
end

function SWEP:Initialize()
    self:SetHoldType("normal")
end

function SWEP:Deploy()
    self:SetHoldType("normal")
    return true
end

function SWEP:GetAimedVehicle()
    local ply = self:GetOwner()
    if not IsValid(ply) then return nil end

    local trace = util.TraceLine({
        start = ply:EyePos(),
        endpos = ply:EyePos() + ply:GetAimVector() * interactionRange(),
        filter = ply,
        mask = MASK_ALL,
    })

    if IsValid(trace.Entity) and VK.IsVehicle and VK.IsVehicle(trace.Entity) then
        return trace.Entity
    end

    return nil
end

function SWEP:CanInteract(veh, requireOwnerLevel)
    local ply = self:GetOwner()
    if not IsValid(ply) or not IsValid(veh) then return false end

    if SERVER then
        return VK.CanInteract and VK.CanInteract(veh, ply, requireOwnerLevel) or false
    end

    if ply:IsSuperAdmin() then return true end

    local ownerType, ownerSteam, _, factionName = VK.GetOwnerState(veh)
    if ownerType == VK.OWNER_TYPE.PLAYER and ownerSteam == ply:SteamID() then return true end
    if requireOwnerLevel then return false end

    if ownerType == VK.OWNER_TYPE.FACTION and istable(Factions) and istable(Factions[factionName]) then
        local members = Factions[factionName].Members or {}
        if members[ply:SteamID()] or members[ply:SteamID64()] then return true end
    end

    if ownerType == VK.OWNER_TYPE.PLAYER then
        for _, key in pairs(VK.ClientKeys or {}) do
            if key.owner_steam == ownerSteam then return true end
        end
    end

    return false
end

local function deny(ply, message)
    if not IsValid(ply) then return end
    ply:EmitSound((VK.SND and VK.SND.DENY) or "buttons/button10.wav", 65, 100, 0.7)
    if VK.Result then VK.Result(ply, false, message) end
end

function SWEP:PrimaryAttack()
    if CurTime() < (self._nextAction or 0) then return end
    self._nextAction = CurTime() + ACTION_COOLDOWN
    self:SetNextPrimaryFire(self._nextAction)

    if CLIENT and not IsFirstTimePredicted() then return end

    local veh = self:GetAimedVehicle()
    if not IsValid(veh) then return end

    if SERVER then
        local ply = self:GetOwner()

        if not self:CanInteract(veh, false) then
            deny(ply, "У вас нет ключа или доступа к этой машине")
            return
        end

        if not veh.VK_OwnerType then
            deny(ply, "У машины нет владельца")
            return
        end

        veh.VK_Locked = not (veh.VK_Locked == true)
        ply:EmitSound(veh.VK_Locked and VK.SND.LOCK or VK.SND.UNLOCK, 65, 100)
        VK.SyncVehicle(veh)

        VK.Result(ply, true, veh.VK_Locked and "Машина заблокирована" or "Машина разблокирована")
    end

    self:SendWeaponAnim(ACT_VM_PRIMARYATTACK)
end

function SWEP:SecondaryAttack()
    if CurTime() < (self._nextAction or 0) then return end
    self._nextAction = CurTime() + ACTION_COOLDOWN
    self:SetNextSecondaryFire(self._nextAction)

    if CLIENT and not IsFirstTimePredicted() then return end

    local veh = self:GetAimedVehicle()
    if not IsValid(veh) then return end

    if SERVER then
        local ply = self:GetOwner()

        if not self:CanInteract(veh, false) then
            deny(ply, "У вас нет ключа или доступа к этой машине")
            return
        end

        if veh.VK_Locked then
            deny(ply, "Машина заблокирована — сначала разблокируйте её")
            return
        end

        local ok = VK.ToggleDoors and VK.ToggleDoors(veh)
        if ok then
            VK.Result(ply, true, veh.VK_DoorsOpen and "Двери открыты" or "Двери закрыты")
        else
            VK.Result(ply, false, "Эта база транспорта не поддерживает управление дверями")
        end
    end

    self:SendWeaponAnim(ACT_VM_SECONDARYATTACK)
end

function SWEP:Reload()
    if SERVER then return end
    if CurTime() < (self._nextReload or 0) then return end
    self._nextReload = CurTime() + 0.8

    if not IsFirstTimePredicted() then return end

    local veh = self:GetAimedVehicle()
    if not IsValid(veh) then return end

    if not VK.ClientCanManagePersonalKeys or not VK.ClientCanManagePersonalKeys(veh) then
        chat.AddText(Color(255, 100, 100), "[VK] ", color_white, "Управлять личными ключами может только владелец или superadmin.")
        return
    end

    net.Start("VK_RequestPlayerList")
        net.WriteEntity(veh)
    net.SendToServer()
end

if CLIENT then
    surface.CreateFont("VK_SWEP_Hint", { font = "Roboto", size = 14, weight = 600, extended = true })
    surface.CreateFont("VK_SWEP_Small", { font = "Roboto", size = 12, weight = 500, extended = true })

    function SWEP:DrawHUD()
        local ply = self:GetOwner()
        if ply ~= LocalPlayer() then return end

        local veh = self:GetAimedVehicle()
        if not IsValid(veh) then return end

        local _, _, _, _, locked = VK.GetOwnerState(veh)
        local canUse = self:CanInteract(veh, false)
        local canManage = self:CanInteract(veh, true)
        local sw, sh = ScrW(), ScrH()
        local y = sh / 2 + 92

        local width = 350
        local rows = canManage and 3 or 2
        local height = 12 + rows * 23
        local x = sw / 2 - width / 2

        draw.RoundedBox(7, x, y, width, height, Color(8, 12, 28, 225))
        surface.SetDrawColor(55, 135, 255, 150)
        surface.DrawOutlinedRect(x, y, width, height, 1)

        local function hint(row, key, text, color)
            local lineY = y + 7 + (row - 1) * 23
            draw.RoundedBox(3, x + 9, lineY, 36, 18, Color(40, 55, 110))
            draw.SimpleText(key, "VK_SWEP_Small", x + 27, lineY + 9, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(text, "VK_SWEP_Hint", x + 54, lineY + 9, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        hint(1, "ЛКМ", locked and "Разблокировать" or "Заблокировать", locked and Color(80, 220, 100) or Color(235, 85, 85))
        hint(2, "ПКМ", "Открыть / закрыть двери", Color(195, 205, 230))
        if canManage then hint(3, "R", "Выдать / отозвать ключ", Color(150, 205, 255)) end

        local stateText = locked and "ЗАБЛОКИРОВАНА" or "РАЗБЛОКИРОВАНА"
        draw.SimpleText(stateText, "VK_SWEP_Small", sw / 2, y - 7,
            locked and Color(255, 90, 90) or Color(80, 230, 110), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)

        if not canUse then
            draw.SimpleText("Нет доступа к транспорту", "VK_SWEP_Small", sw / 2, y + height + 4,
                Color(255, 160, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
        end
    end
end
