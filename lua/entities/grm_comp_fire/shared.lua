--[[--------------------------------------------------------------------
    grm_comp_fire — Пожарная станция (диспетчерская)

    Компьютер пожарной службы (Код 58). Не управляет самой системой пожаров
    напрямую — открывает существующие админ-меню пожарки (доступ/оповещение/
    машины/очаги/журнал) и даёт кнопки дежурства: закрепить машину (/firetruck),
    снять её и взять ствол/рукав. Доступ: суперадмин, бойцы (FightPro) и
    диспетчеры (Dispatch).
----------------------------------------------------------------------]]
ENT.Type          = "anim"
ENT.Base          = "base_gmodentity"
ENT.PrintName     = "Пожарная станция (диспетчерская)"
ENT.Author        = "GRM"
ENT.Category      = "GRM — RP"
ENT.Spawnable     = true
ENT.AdminSpawnable= true
ENT.RenderGroup   = RENDERGROUP_BOTH

ENT.Model         = "models/props_lab/monitor01a.mdl"
ENT.ModelFallback = "models/props/cs_office/computer.mdl"

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "ComputerName")
end
