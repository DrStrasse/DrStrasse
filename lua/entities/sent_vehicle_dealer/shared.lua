--[[--------------------------------------------------------------------
    sent_vehicle_dealer — shared.lua
    NPC-подобный дилер транспорта. Игрок подходит, нажимает [E],
    выбирает машину из списка — машина спавнится рядом.
    
    Поддерживает:
      • Фракционные списки транспорта (vehicles[faction] = {...})
      • Глобальный список (vehicles.__global = {...})
      • Хуки VD_PreSpawnCheck / VD_FilterVehicleList / VD_OnVehicleSpawned
      • Интеграцию с GRM_HasVehicleAccess через патч vehicle_dealer.lua
--------------------------------------------------------------------]]

ENT.Type           = "anim"
ENT.Base           = "base_gmodentity"
ENT.PrintName      = "Дилер транспорта"
ENT.Author         = "GRM System v3"
ENT.Category       = "GRM Vehicles"
ENT.Spawnable      = true
ENT.AdminSpawnable = true
ENT.RenderGroup    = RENDERGROUP_OPAQUE

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "DealerID")     -- уникальный ID дилера
    self:NetworkVar("String", 1, "DealerName")   -- отображаемое имя
    self:NetworkVar("String", 2, "DealerModel")  -- путь к модели дилера
    self:NetworkVar("Vector", 0, "SpawnPos")     -- точка спавна транспорта
    self:NetworkVar("Angle", 0, "SpawnAngle")    -- угол спавна транспорта
    self:NetworkVar("Bool", 0, "HasCustomSpawn") -- есть ли кастомная точка спавна
end
