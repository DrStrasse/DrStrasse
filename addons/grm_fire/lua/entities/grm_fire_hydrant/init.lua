AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    local A = GRM and GRM.FireAddon
    self:SetModel(A and A.SafeModel(A.Models.hydrant) or "models/props_pipes/valvewheel001.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    if self:GetMaxHose() <= 0 then self:SetMaxHose((A and A.HoseCfg and A.HoseCfg.MaxLength) or 2200) end
    if self:GetPortsMax() <= 0 then self:SetPortsMax((A and A.HoseCfg and A.HoseCfg.HydrantPorts) or 2) end
    self:SetOpen(false)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() phys:EnableMotion(false) end
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if (self._NextUse or 0) > CurTime() then return end
    self._NextUse = CurTime() + 0.3

    local A = GRM and GRM.FireAddon
    local hose = ply.GRM_FireHose

    -- С рукавом в руках E остаётся контекстным: вернуть свой рукав либо
    -- пристыковать рукав от машины/другого источника к гидранту.
    if IsValid(hose) then
        if hook.Run("GRM_FireAddon_HydrantUse", ply, self, true) == false then return end
        if hose:GetStartEnt() == self then
            if A and A.ReturnHose then A.ReturnHose(ply, hose) end
            return
        end
        local ok, err = hose:DockTo(self, ply)
        if not ok and ply.ChatPrint then ply:ChatPrint("[Рукав] " .. tostring(err or "стык не вышел")) end
        return
    end

    -- Выдача рукава отделена от крана: Shift+E на ОТКРЫТОМ гидранте.
    if ply:KeyDown(IN_SPEED) then
        if hook.Run("GRM_FireAddon_HydrantUse", ply, self, true) == false then return end
        if not self:GetOpen() then
            if ply.ChatPrint then ply:ChatPrint("[Гидрант] Сначала откройте гидрант обычным E.") end
            return
        end
        if A and A.TakeHose then
            local h, err = A.TakeHose(ply, self)
            if not h and ply.ChatPrint then ply:ChatPrint("[Рукав] " .. tostring(err or "не удалось взять рукав")) end
        end
        return
    end

    -- Обычное E всегда управляет вентилем: закрытый → открыть, открытый →
    -- закрыть. Подключённые линии остаются на месте, но теряют напор.
    local willOpen = not self:GetOpen()
    if hook.Run("GRM_FireAddon_HydrantUse", ply, self, willOpen) == false then return end
    self:SetOpen(willOpen)
    self:EmitSound(willOpen and "ambient/machines/floodgate_stop1.wav" or "buttons/lever4.wav", 70, willOpen and 100 or 95)
    if ply.ChatPrint then
        ply:ChatPrint(willOpen and "[Гидрант] Открыт. Shift+E — взять рукав."
            or "[Гидрант] Закрыт. Подача воды остановлена.")
    end
end
