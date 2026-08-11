--[[--------------------------------------------------------------------
    grm_comp_police — init.lua (Серверная часть)
----------------------------------------------------------------------]]
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("GRM_CompPolice_Open")
util.AddNetworkString("GRM_CompPolice_WantedAct")

function ENT:Initialize()
    local mdl = self.Model
    if not util.IsValidModel(mdl) then mdl = self.ModelFallback end
    self:SetModel(mdl)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    if self:GetComputerName() == "" then
        self:SetComputerName("ПОЛИЦИЯ ПОРЯДКА (OrdnungPolizei)")
    end

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() phys:EnableMotion(false) end
end

function ENT:CanManage(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return false end
    if ply:IsSuperAdmin() then return true end

    local fName = ply:GetNWString("GRM_Faction", "")
    if fName == "" then return false end

    if fName:lower():find("ordnung") or fName:lower():find("polizei") or fName:lower():find("полиц") then
        return true
    end

    if GRM.Documents and GRM.Documents.Templates and GRM.Documents.Templates.access then
        local acc = GRM.Documents.Templates.access
        if acc.badges and acc.badges[fName] == true then return true end
    end
    return false
end

function ENT:Use(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    if not self:CanManage(ply) then
        if GRM.Notify then
            GRM.Notify(ply, "Доступ к служебному компьютеру разрешён только сотрудникам OrdnungPolizei.", 255, 120, 100)
        end
        return
    end

    local onlineList = {}
    for _, p in ipairs(player.GetAll()) do
        if IsValid(p) then
            local rp = p:GetNWString("GRM_RPName", "")
            if rp == "" then rp = p:Nick() end
            local key = (GRM.Identity and isfunction(GRM.Identity.CharacterKey) and GRM.Identity.CharacterKey(p)) or (p:SteamID64() .. ":char1")
            onlineList[#onlineList + 1] = {
                key        = key,
                steamID64  = p:SteamID64() or "0",
                rpName     = rp,
                nick       = p:Nick(),
                faction    = p:GetNWString("GRM_Faction", ""),
                role       = p:GetNWString("GRM_Role", ""),
                department = p:GetNWString("GRM_Department", ""),
            }
        end
    end

    local wantedRecords = GRM.Wanted and GRM.Wanted.Records or {}
    local tpls = GRM.Documents and GRM.Documents.Templates or {}
    local reg  = GRM.Documents and GRM.Documents.Registry or {}

    net.Start("GRM_CompPolice_Open")
        net.WriteEntity(self)
        net.WriteTable(onlineList)
        net.WriteTable(tpls)
        net.WriteTable(reg)
        net.WriteTable(wantedRecords)
        net.WriteString(ply:GetNWString("GRM_Faction", "OrdnungPolizei"))
        net.WriteBool(ply:IsSuperAdmin())
    net.Send(ply)
end

net.Receive("GRM_CompPolice_WantedAct", function(_, ply)
    if not IsValid(ply) then return end
    local act = net.ReadString()
    local targetKey = net.ReadString()
    local reason = net.ReadString()
    local level = net.ReadUInt(4)

    if act == "add" then
        if GRM.Wanted and GRM.Wanted.AddCharge then
            -- Find target player
            for _, p in ipairs(player.GetAll()) do
                local k = (GRM.Identity and isfunction(GRM.Identity.CharacterKey) and GRM.Identity.CharacterKey(p)) or (p:SteamID64() .. ":char1")
                if k == targetKey or p:SteamID64() == targetKey then
                    GRM.Wanted.AddCharge(ply, p, { code = "УК-ПП", title = reason, level = math.Clamp(level, 1, 5) })
                    break
                end
            end
        end
    elseif act == "clear" then
        if GRM.Wanted and GRM.Wanted.Clear then
            for _, p in ipairs(player.GetAll()) do
                local k = (GRM.Identity and isfunction(GRM.Identity.CharacterKey) and GRM.Identity.CharacterKey(p)) or (p:SteamID64() .. ":char1")
                if k == targetKey or p:SteamID64() == targetKey then
                    GRM.Wanted.Clear(ply, p, reason ~= "" and reason or "Оправдан / Розыск снят полицией")
                    break
                end
            end
        end
    end
end)
