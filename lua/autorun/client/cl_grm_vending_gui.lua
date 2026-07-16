--[[
    GRM Vending Machine GUI + клиентская регистрация сущностей для spawnmenu
    Папки lua/entities не используются.
]]

if not CLIENT then return end

GRM = GRM or {}
GRM.Food = GRM.Food or {}

if not GRM.Food.Config then
    include("autorun/sh_grm_food_config.lua")
end

local function cfg()
    return GRM.Food.Config or {}
end

local function getFoodData(itemID)
    local config = cfg()
    return config.FoodItems and config.FoodItems[itemID] or nil
end

-- ============================================================
-- КЛИЕНТСКАЯ РЕГИСТРАЦИЯ СУЩНОСТЕЙ
-- Нужна для корректной отрисовки и гарантированного появления в spawnmenu.
-- ============================================================

local FOOD = {}

FOOD.Type = "anim"
FOOD.Base = "base_gmodentity"
FOOD.PrintName = "Еда"
FOOD.Category = "GRM Food"
FOOD.Spawnable = true
FOOD.AdminSpawnable = true
FOOD.AdminOnly = true

function FOOD:SetupDataTables()
    self:NetworkVar("String", 0, "ItemID")
end

function FOOD:Draw()
    self:DrawModel()

    local itemID = self.GetItemID and self:GetItemID() or ""
    if itemID == "" and self.GetNWString then
        itemID = self:GetNWString("ItemID", "")
    end

    local data = getFoodData(itemID)
    local name = (data and data.name) or "Еда"

    local pos = self:GetPos() + Vector(0, 0, 24)
    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    cam.Start3D2D(pos, Angle(0, ang.y, 90), 0.08)
        draw.SimpleTextOutlined(name, "DermaLarge", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
    cam.End3D2D()
end

scripted_ents.Register(FOOD, "grm_food_item")

local VENDING = {}

VENDING.Type = "anim"
VENDING.Base = "base_gmodentity"
VENDING.PrintName = "Торговый автомат"
VENDING.Category = "GRM Food"
VENDING.Spawnable = true
VENDING.AdminSpawnable = true

function VENDING:Draw()
    self:DrawModel()

    local pos = self:GetPos() + Vector(0, 0, 82)
    local ang = LocalPlayer():EyeAngles()
    ang:RotateAroundAxis(ang:Forward(), 90)
    ang:RotateAroundAxis(ang:Right(), 90)

    cam.Start3D2D(pos, Angle(0, ang.y, 90), 0.1)
        draw.SimpleTextOutlined("Торговый автомат", "DermaLarge", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
        draw.SimpleTextOutlined("Нажмите E", "DermaDefaultBold", 0, 32, Color(230, 230, 230), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0))
    cam.End3D2D()
end

scripted_ents.Register(VENDING, "grm_vending_machine")

-- Дополнительная регистрация в spawnmenu.
-- Именно это чаще всего отвечает за вкладку Q -> Entities.
list.Set("SpawnableEntities", "grm_vending_machine", {
    PrintName = "Торговый автомат",
    ClassName = "grm_vending_machine",
    Category = "GRM Food",
    NormalOffset = 32,
    DropToFloor = true,
    Author = "GRM",
    Spawnable = true,
})

list.Set("SpawnableEntities", "grm_food_item", {
    PrintName = "Еда (тест)",
    ClassName = "grm_food_item",
    Category = "GRM Food",
    NormalOffset = 16,
    DropToFloor = true,
    Author = "GRM",
    AdminOnly = true,
    Spawnable = true,
})

-- ============================================================
-- GUI АВТОМАТА
-- ============================================================

local function createItemRow(parent, ent, itemID, data, frame)
    local panel = parent:Add("DPanel")
    panel:Dock(TOP)
    panel:SetTall(76)
    panel:DockMargin(0, 0, 0, 6)
    panel.Paint = function(_, w, h)
        draw.RoundedBox(6, 0, 0, w, h, Color(30, 35, 45, 220))
    end

    local modelPanel = vgui.Create("DModelPanel", panel)
    modelPanel:Dock(LEFT)
    modelPanel:SetWide(72)
    modelPanel:DockMargin(4, 4, 8, 4)
    modelPanel:SetModel(data.model or "models/props/cs_office/coffee_mug.mdl")
    modelPanel:SetCamPos(Vector(35, 35, 30))
    modelPanel:SetLookAt(Vector(0, 0, 5))
    modelPanel.LayoutEntity = function() end

    local buyBtn = vgui.Create("DButton", panel)
    buyBtn:Dock(RIGHT)
    buyBtn:SetWide(105)
    buyBtn:DockMargin(8, 20, 10, 20)
    buyBtn:SetText("Купить")
    buyBtn:SetFont("DermaDefaultBold")
    buyBtn:SetTextColor(Color(255, 255, 255))
    buyBtn.Paint = function(s, w, h)
        draw.RoundedBox(5, 0, 0, w, h, s:IsHovered() and Color(45, 170, 85) or Color(35, 130, 65))
    end
    buyBtn.DoClick = function()
        if not IsValid(ent) then
            frame:Close()
            return
        end

        net.Start("GRM_Vending_Buy")
            net.WriteEntity(ent)
            net.WriteString(itemID)
        net.SendToServer()

        frame:Close()
    end

    local info = vgui.Create("DPanel", panel)
    info:Dock(FILL)
    info:DockMargin(0, 8, 0, 8)
    info.Paint = nil

    local lblName = vgui.Create("DLabel", info)
    lblName:Dock(TOP)
    lblName:SetTall(22)
    lblName:SetText(data.name or itemID)
    lblName:SetFont("DermaDefaultBold")
    lblName:SetTextColor(Color(255, 255, 255))

    local lblDesc = vgui.Create("DLabel", info)
    lblDesc:Dock(TOP)
    lblDesc:SetTall(20)
    lblDesc:SetText("Сытость: +" .. tostring(data.hungerRestore or 0) .. " | HP: +" .. tostring(data.healthRestore or 0))
    lblDesc:SetFont("DermaDefault")
    lblDesc:SetTextColor(Color(205, 205, 205))

    local lblPrice = vgui.Create("DLabel", info)
    lblPrice:Dock(TOP)
    lblPrice:SetTall(20)
    lblPrice:SetText("Цена: " .. tostring(data.price or 0) .. " GRM")
    lblPrice:SetFont("DermaDefault")
    lblPrice:SetTextColor(Color(255, 210, 70))
end

net.Receive("GRM_Vending_Open", function()
    local ent = net.ReadEntity()
    if not IsValid(ent) then return end

    local frame = vgui.Create("DFrame")
    frame:SetSize(500, 400)
    frame:Center()
    frame:SetTitle("Торговый автомат")
    frame:MakePopup()

    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(10, 10, 10, 10)

    for _, itemID in ipairs(cfg().VendingMachineItems or {}) do
        local data = getFoodData(itemID)
        if data then
            createItemRow(scroll, ent, itemID, data, frame)
        end
    end
end)
