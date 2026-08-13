--[[--------------------------------------------------------------------
    GRM Fire Addon — рукава.
    Сервер держит граф (источник → узлы → ствол/стык).
    Клиент рисует кабель. Земля-земля ещё и constraint.Rope.
    Права фракций наложит GRM через хуки (nil = можно всем).
----------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.FireAddon = GRM.FireAddon or {}
local A = GRM.FireAddon

A.HoseCfg = A.HoseCfg or {
    MaxLength   = 2200,
    LayStep     = 70,
    Width       = 5,
    Material    = "cable/redcable",
    Sag         = 14,
    TruckSlots  = 4,
    HydrantPorts = 2,
    JunctionOut = 2,
    SprayCost   = 1,
    SprayDmg    = 10,
}
if A.HoseCfg.MaxLength < 2000 then A.HoseCfg.MaxLength = 2200 end

A.NODE_SOURCE    = 0
A.NODE_LAY       = 1
A.NODE_JUNCTION  = 2
A.NODE_NOZZLE    = 3

function A.CanHose(ply, src, why)
    if not IsValid(ply) then return false end
    local r = hook.Run("GRM_FireAddon_CanHose", ply, src, why or "use")
    if r == false then return false end
    return true
end

function A.HoseCountOn(src)
    local n = 0
    for _, h in ipairs(ents.FindByClass("grm_fire_hose")) do
        if IsValid(h) and h:GetStartEnt() == src then n = n + 1 end
    end
    return n
end

function A.SourceSlots(src)
    if not IsValid(src) then return 0, 0 end
    local cls = src:GetClass()
    if cls == "grm_fire_pump" then
        local max = src.GetHosesMax and src:GetHosesMax() or A.HoseCfg.TruckSlots
        if max <= 0 then max = A.HoseCfg.TruckSlots end
        return A.HoseCountOn(src), max
    end
    if cls == "grm_fire_hydrant" then
        local max = src.GetPortsMax and src:GetPortsMax() or A.HoseCfg.HydrantPorts
        if max <= 0 then max = A.HoseCfg.HydrantPorts end
        return A.HoseCountOn(src), max
    end
    if cls == "grm_fire_hose_node" and src.GetNodeType and src:GetNodeType() == A.NODE_JUNCTION then
        return A.HoseCountOn(src), A.HoseCfg.JunctionOut
    end
    return 0, 0
end

function A.SourceHasFreeSlot(src)
    local used, max = A.SourceSlots(src)
    return used < max
end

if SERVER then
    function A.TakeHose(ply, src)
        if not IsValid(ply) or not IsValid(src) then return nil, "нет цели" end
        if not A.CanHose(ply, src, "take") then return nil, "нет доступа" end
        if IsValid(ply.GRM_FireHose) then return nil, "у вас уже есть рукав" end
        if not A.SourceHasFreeSlot(src) then return nil, "нет свободных рукавов" end
        if src:GetClass() == "grm_fire_hydrant" and src.GetOpen and not src:GetOpen() then
            return nil, "гидрант закрыт"
        end
        if src:GetClass() == "grm_fire_pump" then
            if src.SetPumpOn then src:SetPumpOn(true) end
        end
        local hose = ents.Create("grm_fire_hose")
        if not IsValid(hose) then return nil, "не создался" end
        hose:SetPos(src:WorldSpaceCenter())
        hose:SetStartEnt(src)
        hose:SetMaxLen(A.HoseCfg.MaxLength)
        hose:Spawn()
        hose:Activate()
        local ok, err = hose:DeployTo(ply)
        if not ok then
            hose:Remove()
            return nil, err or "не выдать"
        end
        if src.SetHosesOut and src.GetHosesMax then
            src:SetHosesOut(A.HoseCountOn(src))
        end
        hook.Run("GRM_FireAddon_HoseTaken", ply, src, hose)
        return hose
    end

    function A.ReturnHose(ply, hose)
        hose = hose or (IsValid(ply) and ply.GRM_FireHose)
        if not IsValid(hose) then return false end
        local src = hose:GetStartEnt()
        hose:Rewind()
        if IsValid(src) and src.SetHosesOut then
            src:SetHosesOut(A.HoseCountOn(src))
        end
        hook.Run("GRM_FireAddon_HoseReturned", ply, src, hose)
        return true
    end

    -- E на своём гидранте/насосе: смотать брошенные или свои рукава.
    function A.RewindAtSource(src, ply)
        if not IsValid(src) then return 0 end
        local n = 0
        for _, h in ipairs(ents.FindByClass("grm_fire_hose")) do
            if IsValid(h) and h:GetStartEnt() == src then
                local holder = h.GetHolder and h:GetHolder() or NULL
                if not IsValid(holder) or holder == ply then
                    if A.ReturnHose(ply, h) then n = n + 1 end
                end
            end
        end
        return n
    end

    function A.GiveHose(ply, src)
        if IsValid(src) then
            local h, err = A.TakeHose(ply, src)
            return h ~= nil, err
        end
        if not IsValid(ply) then return false end
        if ply:HasWeapon("weapon_grm_hose") then return true end
        ply:Give("weapon_grm_hose")
        return ply:HasWeapon("weapon_grm_hose")
    end
end
