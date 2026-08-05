--[[--------------------------------------------------------------------
    grm_money_launderer — init (находка 179e)
----------------------------------------------------------------------]]
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("GRM_Heist_Open")     -- меню отмывщика
util.AddNetworkString("GRM_Heist_Action")   -- действия
util.AddNetworkString("GRM_Heist_Event")    -- баннер/музыка на весь сервер

local function notify(ply, msg, r, g, b)
    if IsValid(ply) and GRM and GRM.Notify then
        GRM.Notify(ply, msg, r or 200, g or 200, b or 200)
    end
end

local function money(n)
    return GRM and GRM.Format and GRM.Format(math.floor(tonumber(n) or 0)) or (tostring(math.floor(tonumber(n) or 0)) .. " GRM")
end

function ENT:Initialize()
    local mdl = self.Model
    if not util.IsValidModel(mdl) then
        mdl = self.ModelFallback
        print("[GRM Launderer] ВНИМАНИЕ: модель не найдена, фолбэк '" .. tostring(mdl) .. "'")
    end
    self:SetModel(mdl)
    -- Находка 179g/179i: как у ТОРГАШЕЙ (grm_vendor) — НЕ физический проп,
    -- а «стоящая» энтити: BBOX + MOVETYPE_NONE + NPC-коллизия + автопрокачка
    -- кадров анимации + idle-последовательность (иначе модель человека
    -- стоит в Т-позе).
    self:SetSolid(SOLID_BBOX)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetCollisionGroup(COLLISION_GROUP_NPC)
    self:SetUseType(SIMPLE_USE)
    self:SetAutomaticFrameAdvance(true)

    self:SetEnabled(true)
    self:SetEventActive(false)
    self:SetMinParticipants(2)
    self:SetGoalMoney(500000)
    self:SetMoneyHeld(0)
    self:SetParticipantCount(0)
    self:SetAllowedFactions("")
    self:SetWinnerFaction("")
    self:SetHeistTargetPos(Vector(0, 0, 0))
    self.Participants = self.Participants or {}   -- [sid] = faction
    self.FactionDelivered = self.FactionDelivered or {} -- [faction] = amount

    self:SetupIdleAnimation()
end

-- Находка 179i: idle-анимация как у торгашей (grm_vendor:SetupIdleAnimation)
function ENT:SetupIdleAnimation()
    local sequence = self:SelectWeightedSequence(ACT_IDLE)
    if not sequence or sequence < 0 then
        for _, name in ipairs({ "idle_all", "idle", "idle_unarmed", "stand", "ref", "idle_01" }) do
            sequence = self:LookupSequence(name)
            if sequence and sequence >= 0 then break end
        end
    end
    if sequence and sequence >= 0 then
        self:ResetSequence(sequence)
        self:SetPlaybackRate(1)
        self:ResetSequenceInfo()
    end
end

function ENT:OnRemove()
    -- если шёл ивент — гасим музыку/баннер у всех
    if self:GetEventActive() then
        self:BroadcastEvent("end", "ОГРАБЛЕНИЕ ПРЕРВАНО", "", false)
    end
    self:StopHeistMusic()
end

function ENT:CanManage(ply)
    return IsValid(ply) and ply:IsSuperAdmin()
end

-- Находка 179g: список имён ВСЕХ существующих фракций (для чекбоксов)
function ENT:FactionList()
    local out = {}
    if istable(Factions) then
        for name in pairs(Factions) do
            if istable(Factions[name]) then out[#out + 1] = tostring(name) end
        end
    end
    table.sort(out)
    return out
end

-- фракция игрока (через Factions/Identity, как в сканере)
function ENT:FactionOf(ply)
    if not (Factions and IsValid(ply) and ply.SteamID) then return nil end
    for fName, fData in pairs(Factions) do
        local member = GRM.Identity and GRM.Identity.FactionMember and GRM.Identity.FactionMember(fData, ply)
        if not member and not GRM.Identity then
            member = fData.Members[ply:SteamID()] or fData.Members[ply:SteamID64()]
        end
        if istable(fData) and istable(fData.Members) and member then
            return fName
        end
    end
    return nil
end

function ENT:IsFactionAllowed(facName)
    local list = string.Trim(tostring(self:GetAllowedFactions() or ""))
    if list == "" then return true end
    for f in string.gmatch(list, "([^,]+)") do
        if string.Trim(f) == facName then return true end
    end
    return false
end

function ENT:IsParticipant(ply)
    if not IsValid(ply) then return false end
    local sid = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(ply)) or ply:SteamID64() or ""
    return self.Participants[tostring(sid)] ~= nil
end

-- Находка 179f: цель ивента — установленная точка, иначе ближайшее
-- хранилище (Рейхсбанк), иначе nil.
function ENT:HeistTarget()
    local tp = self:GetHeistTargetPos()
    if tp and (tp.x ~= 0 or tp.y ~= 0 or tp.z ~= 0) then
        return tp
    end
    local best, bestD = nil, math.huge
    for _, ent in ipairs(ents.FindByClass("grm_bank_vault")) do
        if IsValid(ent) then
            local d = self:GetPos():DistToSqr(ent:GetPos())
            if d < bestD then best, bestD = ent, d end
        end
    end
    if IsValid(best) then return best:GetPos() end
    return nil
end

function ENT:SetHeistTarget(pos)
    self:SetHeistTargetPos(pos or Vector(0, 0, 0))
    if GRM.PermData and GRM.PermData.UpdateEntry then GRM.PermData.UpdateEntry(self) end
    return true
end

-- Раздать маркеры цели участникам (GPS-точка на мини-карте) + уведомление
function ENT:SendHeistTargetMarkers()
    local target = self:HeistTarget()
    if not target then return end
    local dur = math.max(60, tonumber(self.HeistDuration) or 3000)
    local tName = "РЕЙХСБАНК — ЦЕЛЬ ОГРАБЛЕНИЯ"
    local coord = ("X %.0f  Y %.0f"):format(target.x, target.y)
    for sid in pairs(self.Participants) do
        local p = nil
        for _, pl in ipairs(player.GetAll()) do
            if IsValid(pl) then
                local key = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(pl)) or pl:SteamID64() or ""
                if tostring(key) == tostring(sid) then p = pl break end
            end
        end
        if IsValid(p) then
            if GRM.Minimap and GRM.Minimap.AddTempPoint then
                GRM.Minimap.AddTempPoint(tName, target, dur)
                if GRM.Minimap.SendTo then GRM.Minimap.SendTo(p) end
            end
            if GRM.Notify then
                GRM.Notify(p, "ЦЕЛЬ ОГРАБЛЕНИЯ: Рейхсбанк (хранилище) — " .. coord .. ". Двигайтесь к локации!", 255, 200, 100)
            end
        end
    end
end

-- ══ ИВЕНТ ══════════════════════════════════════════════════
function ENT:BroadcastEvent(state, title, subtitle, music)
    net.Start("GRM_Heist_Event")
        net.WriteString(state)         -- "start" | "end"
        net.WriteString(tostring(title or ""))
        net.WriteString(tostring(subtitle or ""))
        net.WriteBool(music == true)
        net.WriteFloat(self:GetEventEndsAt() or 0)
    net.Broadcast()
end

function ENT:StartEvent()
    if self:GetEventActive() then return end
    self:SetEventActive(true)
    self:SetEventEndsAt(CurTime() + self.HeistDuration)
    self:SetMoneyHeld(0)
    self.FactionDelivered = {}
    self:SetWinnerFaction("")
    -- Находка 179o: музыка С СЕРВЕРА (не клиентская!) — CreateSound на
    -- отмывщике, зацикливание, SetSoundLevel(0) = без затухания (слышно
    -- на всей карте, как у сирены сигнализации).
    self:StopHeistMusic()
    local patch = CreateSound(self, "music/hl2_song20_submix0.mp3")
    if patch then
        patch:SetSoundLevel(0)
        patch:EnableLooping(true)
        patch:PlayEx(1, 100)
        self.HeistMusic = patch
    end
    -- баннер на весь сервер
    self:BroadcastEvent("start", "НАЧАТ ИВЕНТ: ОГРАБЛЕНИЕ",
        "Участники: " .. self:GetParticipantCount() .. "  •  Цель: " .. money(self:GetGoalMoney()) ..
        "  •  Время: 50 минут  •  Сдайте деньги отмывщику  •  ДВИГАЙТЕСЬ К ЛОКАЦИИ!", true)
    print(("[GRM Heist] ИВЕНТ ОГРАБЛЕНИЕ начат (отмывщик %s, участников %d, цель %s)")
        :format(self:EntIndex(), self:GetParticipantCount(), money(self:GetGoalMoney())))
    -- Находка 179f: грабители получают GPS-маркер на Рейхсбанк (хранилище)
    self:SendHeistTargetMarkers()
end

-- Находка 179o: остановка серверной музыки
function ENT:StopHeistMusic()
    if self.HeistMusic then
        self.HeistMusic:Stop()
        self.HeistMusic = nil
    end
end

function ENT:EndEvent(criminalsWin, reason)
    if not self:GetEventActive() and not criminalsWin then return end
    local winnerFac = tostring(self:GetWinnerFaction() or "")
    local title, sub
    if criminalsWin and winnerFac ~= "" then
        title = "ОГРАБЛЕНИЕ: ПОБЕДА ФРАКЦИИ [" .. winnerFac .. "]"
        sub = "Деньги доставлены отмывщику: " .. money(self:GetMoneyHeld())
    elseif criminalsWin then
        title = "ОГРАБЛЕНИЕ: ПОБЕДА ПРЕСТУПНИКОВ"
        sub = "Деньги доставлены отмывщику: " .. money(self:GetMoneyHeld())
    else
        title = "ОГРАБЛЕНИЕ: ПОБЕДА ГОСУДАРСТВЕННЫХ СТРУКТУР"
        sub = tostring(reason or "Деньги не доставлены отмывщику за отведённое время")
    end
    self:BroadcastEvent("end", title, sub, false)
    self:StopHeistMusic()
    print(("[GRM Heist] ИВЕНТ ОГРАБЛЕНИЕ окончен: %s (%s)"):format(title, sub))
    self:SetEventActive(false)
    self:SetEventEndsAt(0)
    self:SetMoneyHeld(0)
    self:SetWinnerFaction("")
    self.Participants = {}
    self.FactionDelivered = {}
    self:SetParticipantCount(0)
end

-- ══ ДЕЙСТВИЯ ═══════════════════════════════════════════════
-- Взять задание (участник)
function ENT:TakeJob(ply)
    if not self:GetEnabled() then notify(ply, "Отмывщик не принимает заказы.", 255, 190, 90) return false end
    if self:GetEventActive() then notify(ply, "Ивент уже идёт — набор закрыт.", 255, 190, 90) return false end
    if self:IsParticipant(ply) then notify(ply, "Вы уже в списке участников.", 200, 220, 255) return false end
    local fac = self:FactionOf(ply)
    if not self:IsFactionAllowed(fac) then
        notify(ply, "Ваша фракция не может взять задание на ограбление.", 255, 120, 100)
        return false
    end
    local sid = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(ply)) or ply:SteamID64() or ""
    self.Participants[tostring(sid)] = tostring(fac or "")
    self:SetParticipantCount(self:GetParticipantCount() + 1)
    notify(ply, "Задание принято! Участников: " .. self:GetParticipantCount() .. " / минимум " .. self:GetMinParticipants(), 100, 220, 130)

    local minP = math.max(1, self:GetMinParticipants())
    if self:GetParticipantCount() >= minP then
        self:StartEvent()
    else
        notify(ply, "Нужно ещё " .. (minP - self:GetParticipantCount()) .. " участников — ивент начнётся автоматически.", 200, 220, 255)
    end
    return true
end

-- Находка 179m: отмена участия — игрок выходит из ивента
function ENT:LeaveJob(ply)
    if not IsValid(ply) then return false end
    local sid = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(ply)) or ply:SteamID64() or ""
    sid = tostring(sid)
    if not self.Participants[sid] then
        notify(ply, "Вы не участвуете в ограблении.", 200, 220, 255)
        return false
    end
    self.Participants[sid] = nil
    self:SetParticipantCount(math.max(0, self:GetParticipantCount() - 1))
    notify(ply, "Вы вышли из ограбления. Участников: " .. self:GetParticipantCount(), 255, 190, 90)

    -- если ивент ещё не начался и участников стало меньше минимума — ничего,
    -- набор продолжится; если ивент УЖЕ идёт — выход не отменяет ивент,
    -- но игрок больше не участник (победа/маркеры — только оставшимся).
    if not self:GetEventActive() then
        local minP = math.max(1, self:GetMinParticipants())
        if self:GetParticipantCount() < minP then
            notify(ply, "Участников меньше минимума (" .. minP .. ") — ивент не запустится, пока не наберётся.", 200, 220, 255)
        end
    end
    return true
end

-- Сдать деньги отмывщику (сумка + паллеты рядом). Возвращает сумму.
function ENT:DepositFromBag(ply)
    if not IsValid(ply) then return 0 end
    if not self:GetEventActive() then
        notify(ply, "Ивент не идёт — сдать деньги некому.", 255, 190, 90)
        return 0
    end
    local total = 0
    -- 1) сумка ограбления
    if GRM.Customization and GRM.Customization.LootBagGet then
        local bag = GRM.Customization.LootBagGet(ply)
        if bag > 0 then
            GRM.Customization.LootBagSet(ply, 0)
            total = total + bag
        end
    end
    -- 2) паллеты и деньги рядом (радиус 200)
    if GRM.Economy and GRM.Economy.SpawnCashAt then
        for _, ent in ipairs(ents.FindInSphere(self:GetPos(), 200)) do
            if IsValid(ent) and not ent:IsPlayer() and not ent:IsNPC() and not ent:IsWorld() then
                local cls = ent:GetClass()
                if cls == "grm_vault_cash" or cls == "grm_money_drop" then
                    local amt = math.max(0, math.floor(tonumber(ent:GetAmount() or 0)))
                    if amt > 0 then
                        total = total + amt
                        ent:Remove()
                    end
                end
            end
        end
    end
    if total <= 0 then
        notify(ply, "Нет денег: сумка пуста и рядом нет паллет.", 255, 190, 90)
        return 0
    end
    local fac = tostring(self:FactionOf(ply) or "")
    self.FactionDelivered[fac] = (self.FactionDelivered[fac] or 0) + total
    self:SetMoneyHeld(self:GetMoneyHeld() + total)
    -- победитель — фракция, сдавшая больше всех
    local bestFac, bestAmt = "", -1
    for f, amt in pairs(self.FactionDelivered) do
        if amt > bestAmt then bestFac, bestAmt = f, amt end
    end
    self:SetWinnerFaction(bestFac)
    notify(ply, "Сдано отмывщику: " .. money(total) .. "  (всего: " .. money(self:GetMoneyHeld()) .. " / " .. money(self:GetGoalMoney()) .. ")", 100, 220, 130)
    if self:GetMoneyHeld() >= self:GetGoalMoney() then
        self:EndEvent(true, "Цель достигнута")
    end
    return total
end

function ENT:Think()
    if self:GetEventActive() then
        local ends = self:GetEventEndsAt() or 0
        if ends > 0 and CurTime() >= ends then
            self:EndEvent(self:GetMoneyHeld() >= self:GetGoalMoney(), "Время вышло")
        end
    end
    self:NextThink(CurTime() + 1)
    return true
end

-- ══ МЕНЮ ═══════════════════════════════════════════════════
function ENT:SendMenu(ply)
    if not IsValid(ply) then return end
    net.Start("GRM_Heist_Open")
        net.WriteEntity(self)
        net.WriteTable({
            enabled = self:GetEnabled(),
            eventActive = self:GetEventActive(),
            minParticipants = self:GetMinParticipants(),
            participantCount = self:GetParticipantCount(),
            goalMoney = self:GetGoalMoney(),
            moneyHeld = self:GetMoneyHeld(),
            allowedFactions = tostring(self:GetAllowedFactions() or ""),
            eventEndsAt = self:GetEventEndsAt() or 0,
            isParticipant = self:IsParticipant(ply),
            canManage = self:CanManage(ply),
            myFaction = tostring(self:FactionOf(ply) or ""),
            factionAllowed = self:IsFactionAllowed(self:FactionOf(ply)),
            -- находка 179f: цель ивента (маркер GPS)
            hasTarget = self:HeistTarget() ~= nil,
            targetPos = self:HeistTarget(),
            -- находка 179g: список ВСЕХ существующих фракций для чекбоксов
            factionsList = self:FactionList(),
        })
    net.Send(ply)
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end
    if (self._grmUseT or 0) > CurTime() then return end
    self._grmUseT = CurTime() + 0.4
    self:SendMenu(ply)
end

net.Receive("GRM_Heist_Action", function(_, ply)
    if not IsValid(ply) then return end
    local ent = net.ReadEntity()
    local action = net.ReadString()
    if not IsValid(ent) or ent:GetClass() ~= "grm_money_launderer" then return end
    if ply:GetPos():DistToSqr(ent:GetPos()) > (ent.JobRadius * ent.JobRadius) then return end

    if action == "job" then
        ent:TakeJob(ply)
    elseif action == "leave" then
        -- Находка 179m: отмена участия
        ent:LeaveJob(ply)
    elseif action == "deposit" then
        ent:DepositFromBag(ply)
    elseif action == "set_target" then
        -- находка 179f: цель = то, на что смотрит суперадмин (хранилище)
        if not ent:CanManage(ply) then notify(ply, "Только суперадмин.", 255, 100, 100) return end
        local tr = ply:GetEyeTrace()
        local hit = tr and tr.Entity
        if IsValid(hit) then
            ent:SetHeistTarget(hit:GetPos())
            notify(ply, "Цель ивента установлена: " .. tostring(hit:GetClass() or "?") .. " (" .. ("%.0f %.0f %.0f"):format(hit:GetPos().x, hit:GetPos().y, hit:GetPos().z) .. ")", 100, 220, 130)
        else
            notify(ply, "Наведите прицел на хранилище/место цели.", 255, 190, 90)
        end
    elseif action == "clear_target" then
        if not ent:CanManage(ply) then notify(ply, "Только суперадмин.", 255, 100, 100) return end
        ent:SetHeistTarget(Vector(0, 0, 0))
        notify(ply, "Цель ивента сброшена (авто: ближайшее хранилище).", 100, 220, 255)
    elseif action == "config" then
        if not ent:CanManage(ply) then notify(ply, "Только суперадмин.", 255, 100, 100) return end
        local minP = math.max(1, math.floor(tonumber(net.ReadUInt(8)) or 2))
        local goal = math.max(1000, math.floor(tonumber(net.ReadUInt(32)) or 500000))
        local allowed = string.sub(string.Trim(net.ReadString() or ""), 1, 200)
        ent:SetMinParticipants(minP)
        ent:SetGoalMoney(goal)
        ent:SetAllowedFactions(allowed)
        -- автообновление перм-записи (конфиг переживает рестарт)
        if GRM.PermData and GRM.PermData.UpdateEntry then GRM.PermData.UpdateEntry(ent) end
        notify(ply, "Отмывщик настроен: минимум " .. minP .. ", цель " .. money(goal) .. ", фракции [" .. allowed .. "]", 100, 220, 130)
    elseif action == "config_full" then
        -- Находка 179g: полная настройка — минимум, цель, СПИСОК фракций (чекбоксы)
        if not ent:CanManage(ply) then notify(ply, "Только суперадмин.", 255, 100, 100) return end
        local minP = math.max(1, math.floor(tonumber(net.ReadUInt(16)) or 2))
        local goal = math.max(1000, math.floor(tonumber(net.ReadUInt(32)) or 500000))
        local allowedTbl = net.ReadTable() or {}
        local names = {}
        for _, n in ipairs(allowedTbl) do
            if isstring(n) and string.Trim(n) ~= "" then names[#names + 1] = string.Trim(n) end
        end
        table.sort(names)
        local allowed = table.concat(names, ",")
        ent:SetMinParticipants(minP)
        ent:SetGoalMoney(goal)
        ent:SetAllowedFactions(allowed)
        if GRM.PermData and GRM.PermData.UpdateEntry then GRM.PermData.UpdateEntry(ent) end
        notify(ply, "Отмывщик настроен: минимум " .. minP .. ", цель " .. money(goal) .. ", фракций: " .. #names, 100, 220, 130)
    end
    ent:SendMenu(ply)
end)

-- ══ КОМАНДА ЦЕЛИ (находка 179f) ═══════════════════════════
-- /heist_target — суперадмин целится в хранилище (или место), цель
-- ставится ближайшему отмывщику. /heist_target_clear — сброс.
local function heistTargetCmd(ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        if IsValid(ply) then notify(ply, "Только суперадмин.", 255, 100, 100) end
        return
    end
    local tr = ply:GetEyeTrace()
    local hit = tr and tr.Entity
    local launderer = E and E.FindNearestLaunderer and E.FindNearestLaunderer(ply, 2000)
    if not IsValid(launderer) then notify(ply, "Рядом нет отмывщика денег.", 255, 190, 90) return end
    if IsValid(hit) then
        launderer:SetHeistTarget(hit:GetPos())
        notify(ply, "Цель ивента [" .. tostring(hit:GetClass() or "?") .. "] установлена отмывщику.", 100, 220, 130)
    else
        notify(ply, "Наведите прицел на хранилище/место цели.", 255, 190, 90)
    end
end
local function heistTargetClearCmd(ply)
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        if IsValid(ply) then notify(ply, "Только суперадмин.", 255, 100, 100) end
        return
    end
    local launderer = E and E.FindNearestLaunderer and E.FindNearestLaunderer(ply, 2000)
    if IsValid(launderer) then
        launderer:SetHeistTarget(Vector(0, 0, 0))
        notify(ply, "Цель ивента сброшена (авто: ближайшее хранилище).", 100, 220, 255)
    end
end
concommand.Add("grm_heist_target", function(ply) heistTargetCmd(ply) end)
concommand.Add("grm_heist_target_clear", function(ply) heistTargetClearCmd(ply) end)
hook.Add("PlayerSayTransform", "GRM_Heist_TargetTransform", function(ply, datapack)
    if not istable(datapack) then return end
    local text = datapack[1]
    if not isstring(text) then return end
    local t = string.lower(string.Trim(text))
    if t == "/heist_target" then
        heistTargetCmd(ply)
        datapack.SkipPlayerSay = true
        datapack[1] = ""
    elseif t == "/heist_target_clear" then
        heistTargetClearCmd(ply)
        datapack.SkipPlayerSay = true
        datapack[1] = ""
    end
end)

-- ══ ПЕРМ (конфиг переживает рестарт) ═══════════════════════
GRM = GRM or {}
GRM.PermData = GRM.PermData or { Extract = {}, Apply = {} }
GRM.PermData.Extract = GRM.PermData.Extract or {}
GRM.PermData.Apply = GRM.PermData.Apply or {}
GRM.PermData.Extract["grm_money_launderer"] = function(ent)
    local rec = {
        minParticipants = math.floor(ent:GetMinParticipants() or 2),
        goalMoney = math.floor(ent:GetGoalMoney() or 500000),
        allowedFactions = tostring(ent:GetAllowedFactions() or ""),
    }
    -- находка 179f: цель ивента (маркер GPS)
    local tp = ent:GetHeistTargetPos()
    if tp and (tp.x ~= 0 or tp.y ~= 0 or tp.z ~= 0) then
        rec.heistTarget = { x = tp.x, y = tp.y, z = tp.z }
    end
    return rec
end
GRM.PermData.Apply["grm_money_launderer"] = function(ent, data)
    if not istable(data) then return end
    if data.minParticipants then ent:SetMinParticipants(math.max(1, math.floor(tonumber(data.minParticipants) or 2))) end
    if data.goalMoney then ent:SetGoalMoney(math.max(1000, math.floor(tonumber(data.goalMoney) or 500000))) end
    if data.allowedFactions ~= nil then ent:SetAllowedFactions(tostring(data.allowedFactions or "")) end
    if istable(data.heistTarget) then
        ent:SetHeistTargetPos(Vector(tonumber(data.heistTarget.x) or 0, tonumber(data.heistTarget.y) or 0, tonumber(data.heistTarget.z) or 0))
    end
end

print("[GRM] Money Launderer entity loaded (находка 179e)")
