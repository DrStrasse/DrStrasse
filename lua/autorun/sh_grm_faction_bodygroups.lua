--[[--------------------------------------------------------------------
    GRM Faction Bodygroup Restrictions
    Задаёт для фракции+роли+модели правила на бодигруппы:
      rules[factionKey][roleKey][modelPath][groupIndex] = {
        lock  = true/false,   -- игрок не может менять эту группу
        force = N,           -- принудительное значение (0 = сбросить)
      }
    Применяется:
      • в меню персонажа (stepper заблокирован/подставлен форс);
      • на сервере при сохранении внешности (насильно выставляется force,
        заблокированные игроком изменения отбрасываются).
    Админ-редактор:  grm_faction_bg_editor  (F4 → можно добавить ярлык).
----------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() AddCSLuaFile("grm/cl_faction_bodygroups.lua") end

GRM = GRM or {}
GRM.FactionBodygroups = GRM.FactionBodygroups or {}
FB = GRM.FactionBodygroups  -- global: needed for include()-d client editor

FB.Version = "1.0.0"
FB.NetOpen   = "GRM_FBg_Open"
FB.NetSync   = "GRM_FBg_Sync"
FB.NetSave   = "GRM_FBg_Save"
FB.NetRequest= "GRM_FBg_Request"
FB.File      = "grm_faction_bodygroups.json"

------------------------------------------------------------------ утилиты
local function key(...)
    return table.concat({...}, "|")
end

-- слить правила для игрока по (фракция, роль), от generic "all" к конкретной
function FB.Resolve(ply, model)
    local out = {}
    if not (IsValid(ply) and isstring(model) and model ~= "") then return out end
    local fac = ply:GetNWString("GRM_Faction", "")
    local role = ply:GetNWString("GRM_Role", "")
    if fac == "" then return out end
    local rules = FB.Rules or {}
    -- порядок: generic роль → конкретная роль (конкретная перекрывает)
    local layers = {
        rules[key(fac, "all", "*")],
        rules[key(fac, role, "*")],
        rules[key(fac, "all", string.lower(model))],
        rules[key(fac, role, string.lower(model))],
    }
    for _, set in ipairs(layers) do
        if istable(set) then
            for g, rule in pairs(set) do
                local gi = tonumber(g)
                if gi then out[gi] = table.Merge(out[gi] or {}, rule) end
            end
        end
    end
    return out
end

-- нормализация одной записи
local function normRule(r)
    if r == true then return { lock = true } end
    if not istable(r) then return nil end
    local out = {}
    if r.lock == true or r.locked == true then out.lock = true end
    if r.force ~= nil then out.force = math.Clamp(math.floor(tonumber(r.force) or 0), 0, 32) end
    return out
end

local function normalizeAll(data)
    local out = {}
    if not istable(data) then return out end
    for k, groups in pairs(data) do
        if isstring(k) and istable(groups) then
            local row = {}
            for g, r in pairs(groups) do
                local gi = tonumber(g)
                local nr = normRule(r)
                if gi and nr then row[gi] = nr end
            end
            if next(row) then out[k] = row end
        end
    end
    return out
end

if SERVER then
    util.AddNetworkString(FB.NetOpen)
    util.AddNetworkString(FB.NetSync)
    util.AddNetworkString(FB.NetSave)
    util.AddNetworkString(FB.NetRequest)
    net.Receive(FB.NetRequest, function(_, ply) if IsValid(ply) then FB.SendTo(ply) end end)

    local function load()
        if not file.Exists(FB.File, "DATA") then FB.Rules = {} return end
        local ok, t = pcall(util.JSONToTable, file.Read(FB.File, "DATA") or "")
        FB.Rules = normalizeAll(ok and t or {})
    end
    local function save()
        file.Write(FB.File, util.TableToJSON(FB.Rules or {}, true))
    end
    load()

    function FB.SendTo(ply)
        net.Start(FB.NetSync)
        net.WriteTable(FB.Rules or {})
        if IsValid(ply) then net.Send(ply) else net.Broadcast() end
    end

    function FB.SetRule(faction, role, model, group, rule)
        if not (isstring(faction) and isstring(role) and isstring(model)) then return end
        FB.Rules = FB.Rules or {}
        local k = key(faction, role, string.lower(model))
        FB.Rules[k] = FB.Rules[k] or {}
        local gi = tonumber(group)
        local nr = normRule(rule)
        if gi then
            if not nr then FB.Rules[k][gi] = nil else FB.Rules[k][gi] = nr end
        end
        save()
        FB.SendTo()
    end

    hook.Add("PlayerInitialSpawn", "GRM_FBg_Sync", function(ply)
        timer.Simple(2, function() if IsValid(ply) then FB.SendTo(ply) end end)
    end)

    -- Открыть редактор у админа
    net.Receive(FB.NetOpen, function(_, ply)
        if not (IsValid(ply) and ply:IsSuperAdmin()) then return end
        FB.SendTo(ply)
        net.Start(FB.NetOpen) net.Send(ply)
    end)
    concommand.Add("grm_faction_bg_editor", function(ply)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end
        if IsValid(ply) then FB.SendTo(ply) net.Start(FB.NetOpen) net.Send(ply) end
    end)

    -- Сохранить всю таблицу от админа
    net.Receive(FB.NetSave, function(_, ply)
        if not (IsValid(ply) and ply:IsSuperAdmin()) then return end
        FB.Rules = normalizeAll(net.ReadTable() or {})
        save()
        FB.SendTo()
        ply:ChatPrint("[FB] Правила бодигрупп сохранены.")
    end)

    --[[ Применить при сохранении внешности:
         перехватываем дату после базовой валидации и переписываем группы
         по форсам и блокировкам игрока. ]]
    hook.Add("GRM_CharacterBeforeSaveAppearance", "GRM_FBg_Enforce", function(ply, payload)
        local mdl = isstring(payload and payload.path) and payload.path or ""
        local rules = FB.Resolve(ply, mdl)
        if not next(rules) then return end
        payload.bodygroups = istable(payload.bodygroups) and payload.bodygroups or {}
        for gi, rule in pairs(rules) do
            if rule.force ~= nil then
                payload.bodygroups[gi] = rule.force
            elseif rule.lock then
                -- игрок не может менять эту группу: принудительно 0
                payload.bodygroups[gi] = 0
            end
        end
    end)

    print("[GRM FactionBodygroups] server v" .. FB.Version .. " loaded")
end

if CLIENT then
    -- редактор правил (окно)
    include("grm/cl_faction_bodygroups.lua")
    FB.Rules = FB.Rules or {}
    net.Receive(FB.NetSync, function()
        FB.Rules = net.ReadTable() or {}
        if FB.OnRulesUpdated then FB.OnRulesUpdated() end
        -- открытое меню персонажа должно немедленно скрыть/заблокировать группы
        hook.Run("GRM_FactionBodygroupsUpdated")
    end)
    concommand.Add("grm_faction_bg_editor", function()
        net.Start(FB.NetOpen) net.SendToServer()
    end)
end
