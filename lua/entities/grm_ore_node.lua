AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.PrintName = "Ore Node"
ENT.Category = "GRM MINE"
ENT.Spawnable = true

ENT.Model = "models/props/cs_militia/militiarock05.mdl"
ENT.MineTime = 3

local ORES = {
    copper = {
        color = Color(200, 120, 50),   -- оранжево-медный
        material = "models/debug/debugwhite"
    },
    gold = {
        color = Color(255, 215, 0),    -- золотой
        material = "models/debug/debugwhite"
    },
    aluminum = {
        color = Color(200, 200, 210),  -- серебристый (почти белый)
        material = "models/debug/debugwhite"
    },
    platinum = {
        color = Color(100, 180, 255),  -- голубой (платина)
        material = "models/debug/debugwhite"
    }
}

function ENT:Initialize()
    if SERVER then
        self:SetModel(self.Model)
        self:PhysicsInit(SOLID_VPHYSICS)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetSolid(SOLID_VPHYSICS)

        local phys = self:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
        end

        -- Если тип ещё не задан (например, при спавне через меню), выбираем случайный
        if not self.OreType then
            local keys = {}
            for k in pairs(ORES) do table.insert(keys, k) end
            self:SetOreType(keys[math.random(#keys)])
        else
            -- Если уже задан (через команду), применяем настройки
            self:SetOreType(self.OreType)
        end

        self.MineProgress = 0
        self.LastHitTime = 0
        print("[GRM Ore Node] Инициализирован, тип:", self.OreType)
    end
end

function ENT:SetOreType(oreType)
    if not ORES[oreType] then return end
    self.OreType = oreType
    local data = ORES[oreType]
    self:SetColor(data.color)
    if data.material and data.material ~= "" then
        self:SetMaterial(data.material)
    end
    self.MineProgress = 0
    self.LastHitTime = 0
    print("[GRM Ore Node] Установлен тип:", oreType)
end

function ENT:TakeDamageCustom(dmg, attacker)
    if not IsValid(attacker) or not attacker:IsPlayer() then return end
    print("[GRM Ore Node] TakeDamageCustom вызван, урон:", dmg, "атакующий:", attacker:Nick())

    local ct = CurTime()
    if ct - self.LastHitTime > 1 then
        self.MineProgress = 0
        print("[GRM Ore Node] Сброс прогресса (таймаут)")
    end
    self.LastHitTime = ct

    self.MineProgress = self.MineProgress + dmg / 100
    print("[GRM Ore Node] Прогресс:", self.MineProgress)

    -- Отправляем прогресс атакующему
    net.Start("grm_ore_progress")
        net.WriteEntity(self)
        net.WriteFloat(math.Clamp(self.MineProgress / self.MineTime, 0, 1))
    net.Send(attacker)

    if self.MineProgress >= self.MineTime then
        print("[GRM Ore Node] Руда разрушена!")
        self:OnDestroyed(attacker)
    end
end

function ENT:OnDestroyed(attacker)
    local pos = self:GetPos()
    for i = 1, math.random(4, 7) do
        local chunk = ents.Create("grm_ore_chunk")
        if IsValid(chunk) then
            chunk:SetPos(pos + VectorRand() * 30 + Vector(0, 0, 20))
            chunk:Spawn()
            chunk:SetOreType(self.OreType)
            local phys = chunk:GetPhysicsObject()
            if IsValid(phys) then
                phys:ApplyForceCenter(VectorRand() * 300)
            end
        end
    end
    self:Remove()
end
