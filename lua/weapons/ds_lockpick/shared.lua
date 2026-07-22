--[[--------------------------------------------------------------------
    ds_lockpick — Интерактивная QTE-Отмычка для взлома дверей и Кейпадов (Код 68)

    Назначение: Интерактивный взлом замка дверей и FFD Keypad с мини-игрой QTE.
    Игрок подбирает 4 пина защёлки, нажимая ПРОБЕЛ или ЛКМ в "зелёной зоне".
----------------------------------------------------------------------]]

AddCSLuaFile()

SWEP.PrintName = "Отмычка"
SWEP.Author = "GRM"
SWEP.Instructions = "ЛКМ: Начать QTE-взлом двери или кейпада (подберите 4 пина защёлки)"
SWEP.Category = "GRM"
SWEP.Spawnable = true
SWEP.AdminSpawnable = true
SWEP.DrawWeaponSelection = true
SWEP.ViewModel = "models/weapons/c_crowbar.mdl"
SWEP.WorldModel = "models/weapons/w_crowbar.mdl"
SWEP.UseHands = true
SWEP.HoldType = "crowbar"

SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"

if SERVER then
    util.AddNetworkString("GRM_Lockpick_StartQTE")
    util.AddNetworkString("GRM_Lockpick_FinishQTE")
end

function SWEP:Initialize()
    self:SetHoldType("crowbar")
end

function SWEP:Deploy()
    self:SetHoldType("crowbar")
    return true
end

function SWEP:GetAimedTarget()
    local ply = self:GetOwner()
    if not IsValid(ply) then return nil end

    local tr = util.TraceLine({
        start = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * 110,
        filter = ply,
        mask = MASK_SHOT,
    })

    local ent = tr.Entity
    if IsValid(ent) then
        if ent:GetClass() == "grm_keypad" then
            return ent
        end
        if GRM and GRM.Doors and GRM.Doors.IsDoor and GRM.Doors.IsDoor(ent) then
            return ent
        end
        if IsValid(ent:GetParent()) and GRM and GRM.Doors and GRM.Doors.IsDoor and GRM.Doors.IsDoor(ent:GetParent()) then
            return ent:GetParent()
        end
    end
    return nil
end

function SWEP:PrimaryAttack()
    if CurTime() < (self._nextAction or 0) then return end
    self._nextAction = CurTime() + 0.8
    self:SetNextPrimaryFire(self._nextAction)

    local target = self:GetAimedTarget()
    local ply = self:GetOwner()
    if not IsValid(target) or not IsValid(ply) then return end

    if SERVER then
        net.Start("GRM_Lockpick_StartQTE")
            net.WriteEntity(target)
        net.Send(ply)
    end
end

function SWEP:SecondaryAttack()
    self:PrimaryAttack()
end

-- ============================================================
-- СЕРВЕРНАЯ ОБРАБОТКА РЕЗУЛЬТАТА QTE
-- ============================================================
if SERVER then
    net.Receive("GRM_Lockpick_FinishQTE", function(_, ply)
        if not IsValid(ply) then return end
        local target = net.ReadEntity()
        local success = net.ReadBool()

        if not IsValid(target) then return end
        if ply:GetPos():DistToSqr(target:GetPos()) > 180 * 180 then return end

        if success then
            if target:GetClass() == "grm_keypad" and target.ProcessGrant then
                target:ProcessGrant(ply)
                if GRM.Notify then
                    GRM.Notify(ply, "Кейпад успешно взломан! Доступ разрешён.", 100, 220, 100)
                end
            elseif GRM and GRM.Doors and GRM.Doors.IsDoor and GRM.Doors.IsDoor(target) then
                GRM.Doors.LockDoor(target, false)
                target:Fire("Open", "", 0.1)

                local partner = GRM.Doors.GetPartnerDoor and GRM.Doors.GetPartnerDoor(target)
                if IsValid(partner) then partner:Fire("Open", "", 0.1) end

                ply:EmitSound("buttons/button14.wav", 75, 100)
                hook.Run("GRM_OnDoorLockpicked", ply, target)

                if GRM.Notify then
                    GRM.Notify(ply, "Замок двери успешно взломан!", 100, 220, 100)
                end
            end
        else
            ply:EmitSound("weapons/crowbar/crowbar_impact1.wav", 75, 90)
            if GRM.Notify then
                GRM.Notify(ply, "Отмычка соскочила! Взлом не удался.", 255, 100, 100)
            end
        end
    end)
end

-- ============================================================
-- КЛИЕНТСКАЯ QTE МИНИ-ИГРА ВЗЛОМА
-- ============================================================
if CLIENT then
    surface.CreateFont("QTE_Title", { font = "Roboto", size = 18, weight = 800, extended = true })
    surface.CreateFont("QTE_Sub",   { font = "Roboto", size = 13, weight = 600, extended = true })

    local function startLockpickQTE(target)
        if not IsValid(target) then return end

        local pinCurrent = 1
        local maxPins = 4
        local mistakes = 0
        local maxMistakes = 3
        local active = true

        local targetMin = math.random(20, 60)
        local targetWidth = 22
        local speed = 1.8

        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:SetSize(460, 250)
        frame:Center()
        frame:MakePopup()
        frame:ShowCloseButton(false)

        local isKeypad = (target:GetClass() == "grm_keypad")

        frame.Paint = function(_, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(16, 20, 28, 252))
            draw.RoundedBoxEx(8, 0, 0, w, 38, Color(28, 34, 46), true, true, false, false)
            draw.SimpleText(isKeypad and "ВЗЛОМ КЕЙПАДА — QTE МИНИ-ИГРА" or "ВЗЛОМ ЗАМКА — QTE МИНИ-ИГРА", "QTE_Title", 14, 19, Color(240, 245, 250), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)

            draw.SimpleText("Пин: " .. pinCurrent .. " / " .. maxPins, "QTE_Sub", 16, 54, Color(80, 180, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Ошибки: " .. mistakes .. " / " .. maxMistakes, "QTE_Sub", w - 16, 54, mistakes > 0 and Color(255, 90, 90) or Color(160, 170, 185), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

            local barX, barY = 20, 92
            local barW, barH = 420, 38
            draw.RoundedBox(6, barX, barY, barW, barH, Color(28, 34, 46))

            local zoneX = barX + (barW * (targetMin / 100))
            local zoneW = barW * (targetWidth / 100)
            draw.RoundedBox(4, zoneX, barY + 3, zoneW, barH - 6, Color(60, 200, 110, 220))
            surface.SetDrawColor(80, 230, 130)
            surface.DrawOutlinedRect(zoneX, barY + 3, zoneW, barH - 6, 2)

            local t = CurTime() * speed
            local posPct = (math.sin(t) + 1) / 2
            local pinX = barX + (barW * posPct)

            surface.SetDrawColor(255, 220, 80)
            surface.DrawRect(pinX - 2, barY - 4, 5, barH + 8)

            draw.SimpleText("Нажмите ПРОБЕЛ или КЛИКНИТЕ когда игла в зелёной зоне!", "QTE_Sub", w / 2, 162, Color(200, 210, 225), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("ESC — Отменить взлом", "QTE_Sub", w / 2, 195, Color(140, 150, 165), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        local function checkPin()
            if not active then return end

            local t = CurTime() * speed
            local posPct = ((math.sin(t) + 1) / 2) * 100

            if posPct >= targetMin and posPct <= (targetMin + targetWidth) then
                surface.PlaySound("buttons/button14.wav")
                pinCurrent = pinCurrent + 1

                if pinCurrent > maxPins then
                    active = false
                    frame:Close()
                    net.Start("GRM_Lockpick_FinishQTE")
                        net.WriteEntity(target)
                        net.WriteBool(true)
                    net.SendToServer()
                    return
                end

                targetMin = math.random(15, 68)
                targetWidth = math.max(12, targetWidth - 2.5)
                speed = speed + 0.6
            else
                surface.PlaySound("weapons/crowbar/crowbar_impact1.wav")
                mistakes = mistakes + 1

                if mistakes >= maxMistakes then
                    active = false
                    frame:Close()
                    net.Start("GRM_Lockpick_FinishQTE")
                        net.WriteEntity(target)
                        net.WriteBool(false)
                    net.SendToServer()
                end
            end
        end

        frame.OnKeyCodePressed = function(_, key)
            if key == KEY_SPACE or key == MOUSE_LEFT or key == MOUSE_FIRST then
                checkPin()
            elseif key == KEY_ESCAPE then
                frame:Close()
            end
        end

        local bgBtn = vgui.Create("DButton", frame)
        bgBtn:SetSize(460, 250)
        bgBtn:SetText("")
        bgBtn:SetPaintBackground(false)
        bgBtn.DoClick = function()
            checkPin()
        end
    end

    net.Receive("GRM_Lockpick_StartQTE", function()
        local ent = net.ReadEntity()
        startLockpickQTE(ent)
    end)
end
