--[[
    GRM Prop Protect v1.0.0
    Собственная защита пропов для GRM. Не зависит от FPP/Falcons.

    AccountKey используется только для аудита. Владелец пропа — CharacterKey.
    Настройки: data/grm_prop_protect.json.
]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.PropProtect = GRM.PropProtect or {}
local PP = GRM.PropProtect
PP.Version = "1.0.0"
PP.File = "grm_prop_protect.json"
PP.Cfg = PP.Cfg or {
    enabled = true,
    protectProps = true,
    ownPhysgun = true,
    ownTool = true,
    ownRemove = true,
    adminAll = true,
    maxProps = 150,
    stableFriction = true,
}

local function charKey(ply)
    if IsValid(ply) and ply:IsPlayer() then
        if GRM.Identity and GRM.Identity.CharacterKey then return GRM.Identity.CharacterKey(ply) end
        return tostring(ply:SteamID64() or ply:SteamID() or "") .. ":char1"
    end
    return tostring(ply or "")
end

local function ownerOf(ent)
    return tostring(ent.GRM_PropOwnerCharacterKey or ent:GetNWString("GRM_PropOwnerCharacterKey", ""))
end

function PP.IsManaged(ent)
    return IsValid(ent) and ent:GetClass() == "prop_physics"
end

function PP.IsOwner(ply, ent)
    return IsValid(ply) and ownerOf(ent) ~= "" and ownerOf(ent) == charKey(ply)
end

local function isAdmin(ply)
    return IsValid(ply) and ply:IsSuperAdmin() and PP.Cfg.adminAll ~= false
end

function PP.CanInteract(ply, ent, action)
    if not PP.Cfg.enabled or not PP.Cfg.protectProps then return true end
    if isAdmin(ply) then return true end
    if not PP.IsManaged(ent) then return false end
    if not PP.IsOwner(ply, ent) then return false end
    if action == "physgun" then return PP.Cfg.ownPhysgun ~= false end
    if action == "tool" then return PP.Cfg.ownTool ~= false end
    if action == "remove" then return PP.Cfg.ownRemove ~= false end
    return true
end

local function stablePhysics(ent)
    if not PP.Cfg.stableFriction or not IsValid(ent) then return end
    local phys = ent:GetPhysicsObject()
    if not IsValid(phys) then return end
    pcall(function() phys:SetMaterial("default") end)
    pcall(function() phys:SetFriction(0.85) end)
    pcall(function() phys:SetDamping(0.05, 0.05) end)
end

if SERVER then
    util.AddNetworkString("GRM_PropProtect_Open")
    util.AddNetworkString("GRM_PropProtect_Data")
    util.AddNetworkString("GRM_PropProtect_Save")

    local function load()
        if not file.Exists(PP.File, "DATA") then return end
        local ok, t = pcall(util.JSONToTable, file.Read(PP.File, "DATA") or "", false, true)
        if ok and istable(t) then
            for k, v in pairs(t) do PP.Cfg[k] = v end
        end
    end
    local function save()
        file.Write(PP.File, util.TableToJSON(PP.Cfg, true))
    end
    load()

    local function countProps(ply)
        local n = 0
        local key = charKey(ply)
        for _, ent in ipairs(ents.FindByClass("prop_physics")) do
            if ownerOf(ent) == key then n = n + 1 end
        end
        return n
    end

    local function registerProp(ply, ent)
        if not PP.IsManaged(ent) or not IsValid(ply) then return end
        ent.GRM_PropOwnerCharacterKey = charKey(ply)
        ent.GRM_PropOwnerAccountKey = ply:SteamID64()
        ent:SetNWString("GRM_PropOwnerCharacterKey", ent.GRM_PropOwnerCharacterKey)
        ent:SetNWString("GRM_PropOwnerName", ply:GetNWString("GRM_RPName", "") ~= "" and ply:GetNWString("GRM_RPName", "") or ply:Nick())
        stablePhysics(ent)
    end

    hook.Add("PlayerSpawnedProp", "GRM_PropProtect_Register", function(ply, model, ent)
        if not PP.Cfg.enabled or not IsValid(ent) then return end
        if countProps(ply) >= tonumber(PP.Cfg.maxProps or 150) then
            ent:Remove()
            if GRM.Notify then GRM.Notify(ply, "Лимит пропов достигнут.", 255, 100, 100) end
            return
        end
        registerProp(ply, ent)
    end)

    hook.Add("PhysgunPickup", "GRM_PropProtect_Physgun", function(ply, ent)
        if not PP.IsManaged(ent) then return end
        if PP.CanInteract(ply, ent, "physgun") then
            stablePhysics(ent)
            return true
        end
        return false
    end)

    hook.Add("PhysgunDrop", "GRM_PropProtect_PhysgunDrop", function(_, ent)
        if PP.IsManaged(ent) then stablePhysics(ent) end
    end)

    hook.Add("CanTool", "GRM_PropProtect_Tool", function(ply, tr)
        local ent = tr and tr.Entity
        if not PP.IsManaged(ent) then return end
        if PP.CanInteract(ply, ent, "tool") then return end
        return false
    end)

    hook.Add("CanProperty", "GRM_PropProtect_Property", function(ply, property, ent)
        if PP.IsManaged(ent) and not PP.CanInteract(ply, ent, "tool") then return false end
    end)

    hook.Add("CanPlayerUnfreeze", "GRM_PropProtect_Unfreeze", function(ply, ent)
        if PP.IsManaged(ent) and not PP.CanInteract(ply, ent, "physgun") then return false end
    end)

    hook.Add("EntityTakeDamage", "GRM_PropProtect_NoPropDamage", function(ent, dmg)
        if PP.IsManaged(ent) and dmg:IsDamageType(DMG_CRUSH) then return true end
    end)

    -- Явный дополнительный шлюз для принтера: некоторые FPP-сборки
    -- блокируют PhysgunPickup до/после обычного хука.
    hook.Add("PhysgunPickup", "ZZ_GRM_MoneyPrinter_Physgun", function(ply, ent)
        if IsValid(ent) and ent:GetClass() == "grm_money_printer" then
            if ent.IsOwner and ent:IsOwner(ply) or (IsValid(ply) and ply:IsSuperAdmin()) then return true end
            return false
        end
    end)

    net.Receive("GRM_PropProtect_Open", function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        net.Start("GRM_PropProtect_Data") net.WriteTable(PP.Cfg) net.Send(ply)
    end)
    net.Receive("GRM_PropProtect_Save", function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        local t = net.ReadTable() or {}
        for _, k in ipairs({"enabled", "protectProps", "ownPhysgun", "ownTool", "ownRemove", "adminAll", "stableFriction"}) do
            if t[k] ~= nil then PP.Cfg[k] = t[k] == true end
        end
        PP.Cfg.maxProps = math.Clamp(math.floor(tonumber(t.maxProps) or 150), 1, 1000)
        save()
        net.Start("GRM_PropProtect_Data") net.WriteTable(PP.Cfg) net.Send(ply)
    end)

    concommand.Add("grm_prop_admin", function(ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        net.Start("GRM_PropProtect_Data") net.WriteTable(PP.Cfg) net.Send(ply)
    end)

    hook.Add("InitPostEntity", "GRM_PropProtect_StabilizeExisting", function()
        timer.Simple(1, function()
            for _, ent in ipairs(ents.FindByClass("prop_physics")) do
                if PP.IsManaged(ent) and ownerOf(ent) ~= "" then stablePhysics(ent) end
            end
        end)
    end)
end

if CLIENT then
    net.Receive("GRM_PropProtect_Open", function() end)
    net.Receive("GRM_PropProtect_Data", function()
        local cfg = net.ReadTable() or {}
        local f = vgui.Create("DFrame")
        f:SetTitle("GRM Prop Protect") f:SetSize(520, 430) f:Center() f:MakePopup()
        local y = 42
        local function check(text, key)
            local c = vgui.Create("DCheckBoxLabel", f) c:SetPos(20, y) c:SetSize(450, 25)
            c:SetText(text) c:SetValue(cfg[key] and 1 or 0) c.OnChange = function(_, v) cfg[key] = v end y = y + 28
        end
        check("Защита пропов включена", "enabled")
        check("Защищать пропы игроков", "protectProps")
        check("Владелец может брать физганом", "ownPhysgun")
        check("Владелец может менять инструментами", "ownTool")
        check("Владелец может удалять свои пропы", "ownRemove")
        check("Стабилизировать физику/трение", "stableFriction")
        local n = vgui.Create("DNumberWang", f) n:SetPos(20, y + 8) n:SetSize(180, 26) n:SetMin(1) n:SetMax(1000) n:SetValue(cfg.maxProps or 150)
        local l = vgui.Create("DLabel", f) l:SetPos(210, y + 10) l:SetText("Лимит пропов на персонажа")
        local b = vgui.Create("DButton", f) b:SetText("Сохранить") b:SetPos(340, 360) b:SetSize(140, 32)
        b.DoClick = function() cfg.maxProps = n:GetValue(); net.Start("GRM_PropProtect_Save") net.WriteTable(cfg) net.SendToServer(); f:Close() end
    end)
end

print("[GRM PropProtect] v" .. PP.Version .. " loaded")
