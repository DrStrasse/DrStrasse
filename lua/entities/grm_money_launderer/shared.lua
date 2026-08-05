--[[--------------------------------------------------------------------
    grm_money_launderer — отмывщик денег / организатор ограбления (находка 179e)

    • Суперадмин через E-меню настраивает: какие фракции могут брать
      задание на ограбление, минимальное число участников, цель (сумма).
    • Игроки разрешённых фракций жмут E → «ВЗЯТЬ ЗАДАНИЕ» (участники).
    • Когда участников >= минимума — запускается ИВЕНТ «ОГРАБЛЕНИЕ»:
      баннер на весь экран «НАЧАТ ИВЕНТ: ОГРАБЛЕНИЕ», музыка robber_bank.wav.
    • Таймер 50 минут. Деньги (сумка ограбления / паллеты) сдаются
      отмывщику (E → «СДАТЬ ДЕНЬГИ» / /bag_unload рядом).
    • По истечении: если цель достигнута — победа фракции преступников
      (конкретной, сдавшей больше всех), иначе — госструктуры.
----------------------------------------------------------------------]]
ENT.Type      = "anim"
ENT.Base      = "base_gmodentity"
ENT.PrintName = "Отмывщик денег"
ENT.Author    = "GRM"
ENT.Category  = "GRM — Банк"
ENT.Spawnable = false
ENT.AdminSpawnable = false
ENT.RenderGroup = RENDERGROUP_BOTH

ENT.Model         = "models/humans/group03/male_07.mdl"
ENT.ModelFallback = "models/props_c17/consolebox01a.mdl"

ENT.HeistDuration = 3000   -- 50 минут
ENT.JobRadius     = 250    -- радиус E-взаимодействия
ENT.DepositRadius = 400    -- радиус сдачи денег (/bag_unload)

function ENT:SetupDataTables()
    self:NetworkVar("Bool", 0, "Enabled")        -- отмывщик включён
    self:NetworkVar("Bool", 1, "EventActive")    -- идёт ивент
    self:NetworkVar("Int", 0, "MinParticipants") -- минимум участников
    self:NetworkVar("Int", 1, "GoalMoney")       -- цель (сумма)
    self:NetworkVar("Int", 2, "MoneyHeld")       -- сколько сдано
    self:NetworkVar("Int", 3, "ParticipantCount")
    self:NetworkVar("Float", 0, "EventEndsAt")
    self:NetworkVar("String", 0, "AllowedFactions") -- список фракций через запятую (пусто = все)
    self:NetworkVar("String", 1, "WinnerFaction")
end
