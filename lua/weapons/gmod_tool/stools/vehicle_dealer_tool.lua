--[[--------------------------------------------------------------------
    GRM Vehicle Dealer Tool — fixed

    Full replacement for:
      lua/weapons/gmod_tool/stools/vehicle_dealer_tool.lua

    Dealers use a separate Sandbox count category: grm_vehicle_dealers.
    No ragdoll is created and ragdoll limits are never used.
----------------------------------------------------------------------]]

TOOL.Category = "GRM Vehicles"
TOOL.Name = "#tool.vehicle_dealer_tool.name"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar = {
    model = "models/Humans/Group01/Male_02.mdl",
    name = "Дилер транспорта",
    radius = "700",
    freeze = "1",
}

local DEALER_CLASS = "sent_vehicle_dealer"
local LIMIT_NAME = "grm_vehicle_dealers"

if SERVER then
    cleanup.Register(LIMIT_NAME)
    CreateConVar("sbox_max" .. LIMIT_NAME, "20", FCVAR_ARCHIVE, "Maximum GRM vehicle dealers per admin")
end

if CLIENT then
    language.Add("tool.vehicle_dealer_tool.name", "Дилер транспорта")
    language.Add("tool.vehicle_dealer_tool.desc", "Создание и настройка дилеров транспорта")
    language.Add("tool.vehicle_dealer_tool.0", "ЛКМ: создать | Shift+ЛКМ: точка спавна | ПКМ: обновить | R: удалить | Shift+R: убрать точку")
end

local function isDealer(ent)
    return IsValid(ent) and ent:GetClass() == DEALER_CLASS
end

local function validModel(model)
    model = tostring(model or "")
    return model ~= "" and string.EndsWith(string.lower(model), ".mdl") and util.IsValidModel(model)
end

local function call(ent, method, ...)
    if not IsValid(ent) or not isfunction(ent[method]) then return false end
    return pcall(ent[method], ent, ...)
end

local function dealerID(ent)
    if not IsValid(ent) then return "" end
    if ent.GetDealerID then
        local ok, value = pcall(ent.GetDealerID, ent)
        if ok and value and value ~= "" then return value end
    end
    return ent.VD_ID or ""
end

local function dealerName(ent)
    if not IsValid(ent) then return "Дилер транспорта" end
    if ent.GetDealerName then
        local ok, value = pcall(ent.GetDealerName, ent)
        if ok and value and value ~= "" then return value end
    end
    return ent.VD_Name or "Дилер транспорта"
end

local function saveDealers(ply)
    if isfunction(SaveVehicleDealers) then
        local ok, err = pcall(SaveVehicleDealers)
        if not ok and IsValid(ply) then ply:ChatPrint("[VD Tool] Ошибка сохранения: " .. tostring(err)) end
        return ok
    end
    if IsValid(ply) then ply:ChatPrint("[VD Tool] SaveVehicleDealers() не найдена.") end
    return false
end

local function applyIdle(ent)
    if not IsValid(ent) then return end

    local sequences = { "idle_all_01", "idle_all", "idle_subtle", "idle", "idle01", "pose_standing_01" }
    for _, name in ipairs(sequences) do
        local sequence = ent:LookupSequence(name)
        if sequence and sequence >= 0 then
            ent:ResetSequence(sequence)
            ent:SetPlaybackRate(1)
            ent:SetCycle(0)
            ent:SetAutomaticFrameAdvance(true)
            return
        end
    end

    local sequence = ent:SelectWeightedSequence(ACT_IDLE)
    if sequence and sequence >= 0 then
        ent:ResetSequence(sequence)
        ent:SetPlaybackRate(1)
        ent:SetCycle(0)
        ent:SetAutomaticFrameAdvance(true)
    end
end

local function normalizeDealerPhysics(ent)
    if not IsValid(ent) then return end

    -- Dealer is an anim entity, not a prop/ragdoll.
    ent:PhysicsDestroy()
    ent:SetSolid(SOLID_BBOX)
    ent:SetMoveType(MOVETYPE_NONE)
    ent:SetCollisionBounds(Vector(-16, -16, 0), Vector(16, 16, 72))
    ent:SetCollisionGroup(COLLISION_GROUP_NPC)
    ent:SetUseType(SIMPLE_USE)
    ent:SetAutomaticFrameAdvance(true)
    applyIdle(ent)
end

local function registerDealer(ent)
    if not IsValid(ent) then return end

    VehicleDealers = VehicleDealers or {}
    local id = dealerID(ent)

    if id == "" then
        id = "dealer_" .. ent:EntIndex() .. "_" .. os.time()
        ent.VD_ID = id
        call(ent, "SetDealerID", id)
    end

    VehicleDealers[id] = ent
end

local function nearestDealer(ply, radius)
    local result, best = nil, (tonumber(radius) or 700) ^ 2

    for _, ent in ipairs(ents.FindByClass(DEALER_CLASS)) do
        local distance = ply:GetPos():DistToSqr(ent:GetPos())
        if distance <= best then
            result, best = ent, distance
        end
    end

    if IsValid(result) then registerDealer(result) end
    return result
end

local function setDealerInfo(ent, name, model)
    name = string.Trim(tostring(name or "Дилер транспорта"))
    if name == "" then name = "Дилер транспорта" end
    if not validModel(model) then model = "models/Humans/Group01/Male_02.mdl" end

    ent.VD_Name = name
    ent.VD_Model = model
    call(ent, "SetDealerName", name)
    call(ent, "SetDealerModel", model)
    ent:SetModel(model)
    normalizeDealerPhysics(ent)
end

local function setSpawnPoint(dealer, pos, angle)
    angle = angle or Angle(0, 0, 0)
    angle.p, angle.r = 0, 0

    dealer.VD_HasCustomSpawn = true
    dealer.VD_SpawnPos = pos
    dealer.VD_SpawnAngle = angle
    call(dealer, "SetSpawnPos", pos)
    call(dealer, "SetSpawnAngle", angle)
    call(dealer, "SetHasCustomSpawn", true)
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsAdmin() then return false end

    local radius = tonumber(self:GetClientInfo("radius")) or 700

    if ply:KeyDown(IN_SPEED) then
        local dealer = nearestDealer(ply, radius)
        if not IsValid(dealer) then
            ply:ChatPrint("[VD Tool] Поблизости нет дилера.")
            return false
        end

        setSpawnPoint(dealer, trace.HitPos, Angle(0, ply:EyeAngles().y, 0))
        saveDealers(ply)
        ply:ChatPrint("[VD Tool] Точка спавна задана: " .. dealerName(dealer))
        return true
    end

    -- Separate SENT category, not the ragdoll category.
    if not ply:CheckLimit(LIMIT_NAME) then
        ply:ChatPrint("[VD Tool] Достигнут лимит дилеров.")
        return false
    end

    local model = self:GetClientInfo("model")
    if not validModel(model) then
        ply:ChatPrint("[VD Tool] Некорректная модель: " .. tostring(model))
        return false
    end

    local dealer = ents.Create(DEALER_CLASS)
    if not IsValid(dealer) then
        ply:ChatPrint("[VD Tool] Не удалось создать " .. DEALER_CLASS)
        return false
    end

    dealer:SetPos(trace.HitPos + Vector(0, 0, 4))
    dealer:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
    dealer:Spawn()
    dealer:Activate()

    setDealerInfo(dealer, self:GetClientInfo("name"), model)
    registerDealer(dealer)

    -- Dedicated cleanup/count category. Does not touch ragdoll limits.
    ply:AddCount(LIMIT_NAME, dealer)
    ply:AddCleanup(LIMIT_NAME, dealer)

    undo.Create("GRM Vehicle Dealer")
        undo.AddEntity(dealer)
        undo.SetPlayer(ply)
    undo.Finish()

    saveDealers(ply)
    ply:ChatPrint("[VD Tool] Дилер создан: " .. dealerName(dealer))
    return true
end

function TOOL:RightClick(trace)
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsAdmin() then return false end

    local dealer = nearestDealer(ply, tonumber(self:GetClientInfo("radius")) or 700)
    if not IsValid(dealer) then
        ply:ChatPrint("[VD Tool] Поблизости нет дилера.")
        return false
    end

    setDealerInfo(dealer, self:GetClientInfo("name"), self:GetClientInfo("model"))
    registerDealer(dealer)
    saveDealers(ply)
    ply:ChatPrint("[VD Tool] Дилер обновлён: " .. dealerName(dealer))
    return true
end

function TOOL:Reload(trace)
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsAdmin() then return false end

    local dealer = nearestDealer(ply, tonumber(self:GetClientInfo("radius")) or 700)
    if not IsValid(dealer) then
        ply:ChatPrint("[VD Tool] Поблизости нет дилера.")
        return false
    end

    if ply:KeyDown(IN_SPEED) then
        dealer.VD_HasCustomSpawn = false
        dealer.VD_SpawnPos, dealer.VD_SpawnAngle = nil, nil
        call(dealer, "SetHasCustomSpawn", false)
        saveDealers(ply)
        ply:ChatPrint("[VD Tool] Точка спавна очищена.")
        return true
    end

    local id = dealerID(dealer)
    dealer.VD_PermanentDelete = true
    if VehicleDealers then VehicleDealers[id] = nil end
    dealer:Remove()
    saveDealers(ply)
    ply:ChatPrint("[VD Tool] Дилер удалён.")
    return true
end

if CLIENT then
    function TOOL.BuildCPanel(panel)
        panel:ClearControls()
        panel:Help("ЛКМ — создать дилера")
        panel:Help("Shift + ЛКМ — точка спавна транспорта")
        panel:Help("ПКМ — обновить ближайшего дилера")
        panel:Help("R — удалить дилера")
        panel:Help("Shift + R — убрать точку спавна")

        panel:TextEntry("Название дилера", "vehicle_dealer_tool_name")
        panel:TextEntry("Модель дилера", "vehicle_dealer_tool_model")
        panel:NumSlider("Радиус поиска", "vehicle_dealer_tool_radius", 100, 2000, 0)
        panel:CheckBox("Заморозить дилера", "vehicle_dealer_tool_freeze")
        panel:Help("Дилеры учитываются отдельно от рэгдоллов: grm_vehicle_dealers.")
    end
end
