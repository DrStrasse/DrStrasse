--[[--------------------------------------------------------------------
    grm_food_stove — Плита (готовка). Код 110, заказ владельца.
    Модель заказана: models/props_c17/furniturestove001a.mdl
    [E] → окно плиты (cl_grm_food_kitchen): выбор рецепта с живой
    проверкой ингредиентов, прогресс готовки, выходной лоток.
----------------------------------------------------------------------]]

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Плита (готовка)"
ENT.Category = "GRM Food"
ENT.Spawnable = true
ENT.AdminSpawnable = true

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "StoveState")   -- 0 свободна, 1 готовит
    self:NetworkVar("Int", 1, "StoveFinish")  -- unix-время готовности
    self:NetworkVar("Int", 2, "StoveReady")   -- блюд на выходном лотке
    self:NetworkVar("String", 0, "StoveRecipe")
end

function ENT:KitchenCfg()
    return (GRM and GRM.FoodKitchen and GRM.FoodKitchen.Cfg and GRM.FoodKitchen.Cfg()) or {}
end
