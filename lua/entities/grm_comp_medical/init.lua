--[[--------------------------------------------------------------------
    grm_comp_medical — init.lua (Серверная часть)
----------------------------------------------------------------------]]
AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

util.AddNetworkString("GRM_CompMedical_Open")
util.AddNetworkString("GRM_CompMedical_SaveCard")

function ENT:Initialize()
    local mdl = self.Model
    if not util.IsValidModel(mdl) then mdl = self.ModelFallback end
    self:SetModel(mdl)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    if self:GetComputerName() == "" then
        self:SetComputerName("МЕДИЦИНСКАЯ СЛУЖБА • ГОСПИТАЛЬ И ВВК")
    end

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() phys:EnableMotion(false) end
end

function ENT:CanManage(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return false end
    if ply:IsSuperAdmin() then return true end

    local fName = ply:GetNWString("GRM_Faction", "")
    if fName == "" then return false end

    if fName:lower():find("мед") or fName:lower():find("госпитал") or fName:lower():find("врач") or fName:lower():find("hospital") or fName:lower():find("medic") then
        return true
    end
    return false
end

function ENT:Use(ply)
    if not (IsValid(ply) and ply:IsPlayer()) then return end
    if not self:CanManage(ply) then
        if GRM.Notify then
            GRM.Notify(ply, "Доступ к медицинской базе разрешён только медицинскому персоналу госпиталя.", 255, 120, 100)
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

    local medCards = GRM.Medical and GRM.Medical.Cards or {}

    net.Start("GRM_CompMedical_Open")
        net.WriteEntity(self)
        net.WriteTable(onlineList)
        net.WriteTable(medCards)
        net.WriteString(ply:GetNWString("GRM_Faction", "Госпиталь"))
        net.WriteBool(ply:IsSuperAdmin())
    net.Send(ply)
end

net.Receive("GRM_CompMedical_SaveCard", function(_, ply)
    if not IsValid(ply) then return end
    local targetKey = net.ReadString()
    local cardData = net.ReadTable()
    if not isstring(targetKey) or targetKey == "" or not istable(cardData) then return end

    if GRM.Medical and GRM.Medical.Cards then
        GRM.Medical.Cards[targetKey] = cardData
        if GRM.Medical.Save then GRM.Medical.Save("doctor update by " .. ply:Nick()) end
        if GRM.Notify then GRM.Notify(ply, "Медицинская карта пациента сохранена.", 100, 220, 120) end
    end
end)
