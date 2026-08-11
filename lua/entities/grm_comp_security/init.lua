--[[--------------------------------------------------------------------
    grm_comp_security — init.lua (Серверная часть)
----------------------------------------------------------------------]]
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("GRM_CompSecurity_Open")

function ENT:Initialize()
    local mdl = self.Model
    if not util.IsValidModel(mdl) then mdl = self.ModelFallback end
    self:SetModel(mdl)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    if self:GetComputerName() == "" then
        self:SetComputerName("СЛУЖБА ГОСУДАРСТВЕННОЙ БЕЗОПАСНОСТИ (Gestapo / Komitet)")
    end

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() phys:EnableMotion(false) end
end

function ENT:CanManage(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return false end
    if ply:IsSuperAdmin() then return true end

    local fName = ply:GetNWString("GRM_Faction", "")
    if fName == "" then return false end

    if fName:lower():find("gestapo") or fName:lower():find("komitet") or fName:lower():find("комитет") or fName:lower():find("сгб") or fName:lower():find("security") then
        return true
    end

    if GRM.Documents and GRM.Documents.Templates and GRM.Documents.Templates.access then
        local acc = GRM.Documents.Templates.access
        if acc.coverDocs and acc.coverDocs[fName] == true then return true end
    end
    return false
end

function ENT:Use(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    if not self:CanManage(ply) then
        if GRM.Notify then
            GRM.Notify(ply, "Доступ строго ограничен. Терминал Службы Государственной Безопасности.", 255, 60, 60)
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
    local medCards = GRM.Medical and GRM.Medical.Cards or {}

    net.Start("GRM_CompSecurity_Open")
        net.WriteEntity(self)
        net.WriteTable(onlineList)
        net.WriteTable(tpls)
        net.WriteTable(reg)
        net.WriteTable(wantedRecords)
        net.WriteTable(medCards)
        net.WriteString(ply:GetNWString("GRM_Faction", "Gestapo"))
        net.WriteBool(ply:IsSuperAdmin())
    net.Send(ply)
end
