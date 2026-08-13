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
    Width       = 8,
    Material    = "grm/firehose",
    Sag         = 14,
    TruckSlots  = 4,
    HydrantPorts = 2,
    JunctionOut = 2,
    SprayCost        = 8,
    SprayCostWater   = 8,
    SprayCostFoam    = 4,
    SprayCostPowder  = 2,
    SprayDmg         = 10,
    SprayDmgWater    = 10,
    SprayDmgFoam     = 18,
    SprayDmgPowder   = 24,
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

    function A.NearestHydrant(pos, maxd)
        if not isvector(pos) then return nil end
        maxd = tonumber(maxd) or 2200
        local best, bestD
        for _, h in ipairs(ents.FindByClass("grm_fire_hydrant")) do
            if IsValid(h) then
                local d = h:GetPos():Distance(pos)
                if d <= maxd and (not best or d < bestD) then
                    best, bestD = h, d
                end
            end
        end
        return best, bestD
    end

    -- Прямая линия насос ↔ гидрант (без игрока в руках).
    function A.LaySupplyLine(src, dst)
        if not IsValid(src) or not IsValid(dst) then return nil, "нет цели" end
        if src == dst then return nil, "тот же объект" end
        if not A.SourceHasFreeSlot(src) then return nil, "нет свободного порта на источнике" end
        if not A.SourceHasFreeSlot(dst) then return nil, "нет свободного порта на насосе" end
        if src:GetClass() == "grm_fire_hydrant" and src.GetOpen and not src:GetOpen() then
            return nil, "гидрант закрыт — откройте E"
        end
        local a = src:WorldSpaceCenter() + Vector(0, 0, 6)
        local b = dst:WorldSpaceCenter() + Vector(0, 0, 6)
        local dist = a:Distance(b)
        local maxL = A.HoseCfg.MaxLength or 2200
        if dist > maxL then return nil, ("далеко (%.0f > %d)"):format(dist, maxL) end
        local hose = ents.Create("grm_fire_hose")
        if not IsValid(hose) then return nil, "не создался рукав" end
        hose:SetPos(a)
        hose:SetStartEnt(src)
        hose:SetMaxLen(maxL)
        hose:Spawn()
        hose:Activate()
        local startN = hose:MakeNode(A.NODE_SOURCE, a, src)
        if not IsValid(startN) then hose:Remove() return nil, "узел" end
        local last = startN
        local step = math.max(60, A.HoseCfg.LayStep or 70)
        local nsteps = math.max(0, math.floor(dist / step) - 1)
        for i = 1, nsteps do
            local p = LerpVector(i / (nsteps + 1), a, b)
            local tr = util.TraceLine({
                start = p + Vector(0, 0, 48),
                endpos = p - Vector(0, 0, 96),
                mask = MASK_SOLID_BRUSHONLY,
            })
            if tr.Hit then p = tr.HitPos + Vector(0, 0, 3) end
            local node = hose:MakeNode(A.NODE_LAY, p)
            if IsValid(node) then
                last:SetNextNode(node)
                hose:Link(last, node)
                last = node
            end
        end
        local dock = hose:MakeNode(A.NODE_SOURCE, b, dst)
        if not IsValid(dock) then hose:Remove() return nil, "стык" end
        last:SetNextNode(dock)
        hose:Link(last, dock)
        hose:SetEndNode(dock)
        hose:SetDocked(true)
        hose:SetHolder(NULL)
        hose:SetLaidLen(math.floor(hose:LaidDistance()))
        if dst.SetPumpOn then dst:SetPumpOn(true) end
        if src.SetHosesOut then src:SetHosesOut(A.HoseCountOn(src)) end
        if dst.SetHosesOut then dst:SetHosesOut(A.HoseCountOn(dst)) end
        hose:EmitSound("buttons/lever7.wav", 65, 100)
        hook.Run("GRM_FireAddon_HoseDocked", hose, dst, nil)
        return hose
    end
end

if CLIENT then
    local MAT
    function A.HoseMaterial()
        if MAT and not MAT:IsError() then return MAT end
        MAT = Material("grm/firehose")
        if not MAT or MAT:IsError() then MAT = Material("vgui/white") end
        if not MAT or MAT:IsError() then MAT = Material("cable/cable") end
        return MAT
    end

    local COL_CORE = Color(210, 48, 28, 255)
    local COL_EDGE = Color(120, 18, 12, 255)
    local COL_LIVE = Color(255, 90, 40, 255)

    local function nodeTip(ent)
        if not IsValid(ent) then return nil end
        if ent:IsPlayer() then
            local att = ent:LookupAttachment("anim_attachment_RH")
            local dat = att and att > 0 and ent:GetAttachment(att)
            return (dat and dat.Pos) or (ent:WorldSpaceCenter() + Vector(0, 0, 18))
        end
        return ent:GetPos() + Vector(0, 0, 5)
    end

    function A.DrawHoseBeam(a, b, live)
        if not a or not b then return end
        local dist = a:Distance(b)
        if dist < 2 or dist > 2600 then return end
        local mat = A.HoseMaterial()
        if not mat then return end
        render.SetMaterial(mat)
        render.DrawBeam(a, b, 14, 0, dist / 16, COL_EDGE)
        render.DrawBeam(a, b, 9, 0, dist / 20, live and COL_LIVE or COL_CORE)
    end

    -- Запасной проход: все сегменты, не зависит от Draw узла и HL2-кабеля.
    hook.Add("PostDrawOpaqueRenderables", "GRM_FireHose_Beams", function(depth, sky)
        if sky or depth then return end
        for _, n in ipairs(ents.FindByClass("grm_fire_hose_node")) do
            if IsValid(n) and n.GetNextNode then
                local nxt = n:GetNextNode()
                A.DrawHoseBeam(nodeTip(n), nodeTip(nxt), IsValid(nxt) and nxt:IsPlayer())
            end
        end
    end)
    hook.Add("PostDrawTranslucentRenderables", "GRM_FireHose_Beams", function(depth, sky)
        if sky or depth then return end
        for _, n in ipairs(ents.FindByClass("grm_fire_hose_node")) do
            if IsValid(n) and n.GetNextNode then
                local nxt = n:GetNextNode()
                A.DrawHoseBeam(nodeTip(n), nodeTip(nxt), IsValid(nxt) and nxt:IsPlayer())
            end
        end
    end)
end
