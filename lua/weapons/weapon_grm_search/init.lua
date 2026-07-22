AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("GRM_Search_Result")
util.AddNetworkString("GRM_Search_Confiscate")

function SWEP:Initialize()
    self:SetHoldType("normal")
end

function SWEP:PrimaryAttack()
    if not self.Owner:IsPlayer() then return end
    
    local trace = self.Owner:GetEyeTrace()
    local target = trace.Entity
    
    if not target:IsPlayer() or not target:Alive() then
        self.Owner:ChatPrint("[Обыск] Наведитесь на живого игрока")
        return
    end
    
    -- Проверка дистанции
    if self.Owner:GetPos():Distance(target:GetPos()) > 100 then
        self.Owner:ChatPrint("[Обыск] Слишком далеко (макс. 100 единиц)")
        return
    end
    
    -- Проверка прав (только полиция или админ)
    if not self:CanSearch(self.Owner) then
        self.Owner:ChatPrint("[Обыск] Только полиция может проводить обыск!")
        return
    end
    
    -- Начинаем обыск
    self:PerformSearch(self.Owner, target)
end

function SWEP:SecondaryAttack()
    if not self.Owner:IsPlayer() then return end
    
    local trace = self.Owner:GetEyeTrace()
    local target = trace.Entity
    
    if not target:IsPlayer() or not target:Alive() then
        self.Owner:ChatPrint("[Обыск] Наведитесь на живого игрока")
        return
    end
    
    if self.Owner:GetPos():Distance(target:GetPos()) > 100 then
        self.Owner:ChatPrint("[Обыск] Слишком далеко")
        return
    end
    
    -- Проверка документов
    self:CheckDocuments(self.Owner, target)
end

-- CanSearch теперь в shared.lua

function SWEP:PerformSearch(searcher, target)
    local found = {}
    
    -- Проверяем инвентарь
    if GRM.Inventory and GRM.Inventory.GetPlayerInv then
        local inv = GRM.Inventory.GetPlayerInv(target)
        if istable(inv) and istable(inv.slots) then
            for _, slot in pairs(inv.slots) do
                if istable(slot) and slot.id then
                    -- Запрещённые предметы
                    for _, contraband in ipairs(self.Contraband) do
                        if slot.id == contraband then
                            found[#found + 1] = {type = "item", id = slot.id, count = slot.count or 1}
                        end
                    end
                end
            end
        end
    end
    
    -- Проверяем оружие
    local weapons = target:GetWeapons()
    for _, wep in ipairs(weapons) do
        local class = wep:GetClass()
        for _, contraband in ipairs(self.ContrabandWeapons) do
            if class == contraband then
                found[#found + 1] = {type = "weapon", id = class}
            end
        end
    end
    
    -- Отправляем результат обыскивающему (UI с чекбоксами)
    net.Start("GRM_Search_Result")
        net.WriteEntity(searcher)
        net.WriteEntity(target)
        net.WriteUInt(#found, 8)
        for _, item in ipairs(found) do
            net.WriteString(item.type)
            net.WriteString(item.id)
            net.WriteUInt(item.count or 1, 8)
        end
    net.Send(searcher)
    
    -- Уведомление цели
    if GRM.Notify then
        GRM.Notify(target, "У вас провели обыск.", 255, 200, 100)
    end
    
    -- Логирование
    self:LogSearch(searcher, target, found)
end

function SWEP:CheckDocuments(searcher, target)
    -- Проверяем медкарту
    local hasMedicalCard = false
    if GRM.Medical and GRM.Medical.Cards then
        local sid64 = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(target)) or target:SteamID64()
        if GRM.Medical.Cards[sid64] or GRM.Medical.Cards[target:SteamID64()] then
            hasMedicalCard = true
        end
    end
    
    -- Проверяем оружие (лицензия)
    local hasWeapons = #target:GetWeapons() > 0
    
    local msg = "=== Документы: " .. target:Nick() .. " ===\n"
    msg = msg .. "Медкарта: " .. (hasMedicalCard and "Есть" or "Нет") .. "\n"
    msg = msg .. "Оружие: " .. (hasWeapons and "Есть" or "Нет") .. "\n"
    
    searcher:ChatPrint(msg)
end

function SWEP:LogSearch(searcher, target, found)
    -- Записываем в лог
    local log = string.format("[ОБЫСК] %s обыскал %s | Найдено: %d предметов",
        searcher:Nick(),
        target:Nick(),
        #found
    )
    
    print(log)
    
    -- Отправляем в чат всем игрокам с доступом
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and self:CanSearch(ply) then
            ply:ChatPrint(log)
        end
    end
end

-- Изъятие предмета (по запросу от клиента)
net.Receive("GRM_Search_Confiscate", function(_, searcher)
    if not IsValid(searcher) then return end
    if not searcher:IsPlayer() then return end
    
    -- Проверяем доступ
    local canSearch = false
    if searcher:IsSuperAdmin() then
        canSearch = true
    elseif Factions then
        for _, factionName in ipairs(GRM.Search.AllowedFactions) do
            local f = Factions[factionName]
            if istable(f) and istable(f.Members) then
                local sid = searcher:SteamID()
                local sid64 = searcher:SteamID64()
                local ck = (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(searcher)) or sid64
                if f.Members[ck] or f.Members[sid] or f.Members[sid64] then
                    canSearch = true
                    break
                end
            end
        end
    end
    
    if not canSearch then return end
    
    local target = net.ReadEntity()
    if not IsValid(target) or not target:IsPlayer() then return end
    
    local itemType = net.ReadString()
    local itemID = net.ReadString()
    local count = net.ReadUInt(8)
    
    if itemType == "item" then
        GRM.Inventory.RemoveItem(target, itemID, count)
        if GRM.Notify then
            GRM.Notify(searcher, "Изъято: " .. itemID .. " x" .. count, 100, 220, 100)
            GRM.Notify(target, "У вас изъяли: " .. itemID, 255, 100, 100)
        end
    elseif itemType == "weapon" then
        target:StripWeapon(itemID)
        if GRM.Notify then
            GRM.Notify(searcher, "Изъято оружие: " .. itemID, 100, 220, 100)
            GRM.Notify(target, "У вас изъяли оружие: " .. itemID, 255, 100, 100)
        end
    end
    
    print("[ИЗЪЯТИЕ] " .. searcher:Nick() .. " изъял " .. itemID .. " у " .. target:Nick())
end)

-- Статическая проверка доступа (для net.Receive)
function SWEP:CanSearchStatic(ply)
    return SWEP:CanSearch(ply)
end
