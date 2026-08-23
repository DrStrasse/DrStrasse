--[[
    Доступ служебных компьютеров: у КАЖДОГО экземпляра свой список
    организаций. Пустой список — старое поведение (эвристика / access.json).
]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.CompAccess = GRM.CompAccess or {}
local A = GRM.CompAccess
A.NW = "GRM_CompFactions"

function A.FactionRows()
    local src = (SERVER and istable(Factions) and Factions)
        or (istable(FactionsData) and FactionsData) or {}
    if SERVER and GRM.VehicleDealer and GRM.VehicleDealer.FactionList then
        return GRM.VehicleDealer.FactionList()
    end
    local out = {}
    for name in pairs(src) do
        if isstring(name) and name ~= "" then
            local disp = (GRM.Factions and GRM.Factions.DisplayName and GRM.Factions.DisplayName(name)) or name
            out[#out + 1] = { key = name, name = tostring(disp) }
        end
    end
    table.sort(out, function(a, b) return string.lower(a.name) < string.lower(b.name) end)
    return out
end

function A.Parse(raw)
    local set = {}
    for part in string.gmatch(tostring(raw or ""), "([^,]+)") do
        local s = string.Trim(part)
        if s ~= "" then set[s] = true end
    end
    return set
end

function A.Encode(set)
    local out = {}
    for name, on in pairs(istable(set) and set or {}) do
        if on and tostring(name) ~= "" then out[#out + 1] = tostring(name) end
    end
    table.sort(out)
    return table.concat(out, ",")
end

function A.GetRaw(ent)
    if not IsValid(ent) then return "" end
    if ent.GetNWString then return tostring(ent:GetNWString(A.NW, "") or "") end
    return tostring(ent.GRMCompFactions or "")
end

function A.Set(ent, csv)
    if not IsValid(ent) then return false end
    csv = string.sub(string.Trim(tostring(csv or "")), 1, 512)
    ent.GRMCompFactions = csv
    if ent.SetNWString then ent:SetNWString(A.NW, csv) end
    if SERVER and duplicator and duplicator.StoreEntityModifier then
        duplicator.StoreEntityModifier(ent, "GRM_CompAccess", { factions = csv })
    end
    return true
end

function A.Allowed(ent, ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    if not IsValid(ent) then return true end
    local raw = A.GetRaw(ent)
    if raw == "" then return true end
    local fac = ply:GetNWString("GRM_Faction", "")
    if fac == "" then return false end
    local set = A.Parse(raw)
    return set[fac] == true
end

if SERVER then
    util.AddNetworkString("GRM_CompAccess_List")
    util.AddNetworkString("GRM_CompAccess_ListReq")
    util.AddNetworkString("GRM_CompAccess_Apply")

    if duplicator and duplicator.RegisterEntityModifier then
        duplicator.RegisterEntityModifier("GRM_CompAccess", function(_, ent, data)
            if IsValid(ent) and istable(data) then A.Set(ent, data.factions) end
        end)
    end

    net.Receive("GRM_CompAccess_ListReq", function(_, ply)
        if not IsValid(ply) then return end
        if GRM.Net and GRM.Net.Guard and not GRM.Net.Guard(ply, "comp.access.list", { rate = 1, burst = 3 }, {}) then return end
        net.Start("GRM_CompAccess_List")
            net.WriteTable(A.FactionRows())
        net.Send(ply)
    end)

    net.Receive("GRM_CompAccess_Apply", function(_, ply)
        if not (IsValid(ply) and (ply:IsSuperAdmin() or ply:IsAdmin())) then return end
        local csv = string.sub(net.ReadString() or "", 1, 512)
        local tr = ply:GetEyeTrace()
        local ent = IsValid(tr.Entity) and tr.Entity or nil
        if not IsValid(ent) then
            if GRM.Notify then GRM.Notify(ply, "Наведитесь на служебный компьютер.", 255, 160, 90) end
            return
        end
        A.Set(ent, csv)
        if GRM.Notify then
            GRM.Notify(ply, csv == "" and "Доступ ПК сброшен (как раньше, по ведомству)."
                or ("Доступ ПК записан: " .. csv), 100, 220, 130)
        end
    end)
end

if CLIENT then
    A.Rows = A.Rows or {}
    net.Receive("GRM_CompAccess_List", function()
        A.Rows = net.ReadTable() or {}
        hook.Run("GRM_CompAccess_List", A.Rows)
    end)
end
