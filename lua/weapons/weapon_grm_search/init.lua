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

function SWEP:CanSearch(ply)
    -- Проверяем фракцию полиции
    if Factions and Factions["Полиция"] then
        local f = Factions["Полиция"]
        if istable(f.Members) then
            local sid = ply:SteamID()
            local sid64 = ply:SteamID64()
            if f.Members[sid] or f.Members[sid64] then
                return true
            end
        end
    end
    
    -- Или суперадмин
    return ply:IsSuperAdmin()
end

function SWEP:PerformSearch(searcher, target)
    local found = {}
    local confiscated = {}
    
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
                            
                            -- Изъятие (автоматическое)
                            GRM.Inventory.RemoveItem(target, slot.id, slot.count or 1)
                            confiscated[#confiscated + 1] = slot.id
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
                
                -- Изъятие оружия
                target:StripWeapon(class)
                confiscated[#confiscated + 1] = class
            end
        end
    end
    
    -- Отправляем результат обыскивающему
    net.Start("GRM_Search_Result")
        net.WriteEntity(searcher)
        net.WriteEntity(target)
        net.WriteUInt(#found, 8)
        for _, item in ipairs(found) do
            net.WriteString(item.type)
            net.WriteString(item.id)
            net.WriteUInt(item.count or 1, 8)
        end
        net.WriteUInt(#confiscated, 8)
        for _, id in ipairs(confiscated) do
            net.WriteString(id)
        end
    net.Send(searcher)
    
    -- Уведомление цели
    if #found > 0 then
        if GRM.Notify then
            GRM.Notify(target, "У вас провели обыск и изъяли запрещённые предметы!", 255, 100, 100)
        end
    else
        if GRM.Notify then
            GRM.Notify(target, "У вас провели обыск. Ничего не найдено.", 100, 220, 100)
        end
    end
    
    -- Логирование
    self:LogSearch(searcher, target, found, confiscated)
end

function SWEP:CheckDocuments(searcher, target)
    -- Проверяем медкарту
    local hasMedicalCard = false
    if GRM.Medical and GRM.Medical.Cards then
        local sid64 = target:SteamID64()
        if GRM.Medical.Cards[sid64] then
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

function SWEP:LogSearch(searcher, target, found, confiscated)
    -- Записываем в лог (можно расширить для сохранения в файл)
    local log = string.format("[ОБЫСК] %s обыскал %s | Найдено: %d | Изъято: %d",
        searcher:Nick(),
        target:Nick(),
        #found,
        #confiscated
    )
    
    print(log)
    
    -- Отправляем в чат полиции (если есть)
    if Factions and Factions["Полиция"] then
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) then
                local f = Factions["Полиция"]
                if istable(f.Members) then
                    local sid = ply:SteamID()
                    local sid64 = ply:SteamID64()
                    if f.Members[sid] or f.Members[sid64] then
                        ply:ChatPrint(log)
                    end
                end
            end
        end
    end
end
