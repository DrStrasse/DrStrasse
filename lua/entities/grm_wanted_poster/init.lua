AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    self:SetModel("models/props_junk/garbage_newspaper001a.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
    if self:GetHeadline() == "" then self:SetHeadline("ВНИМАНИЕ! РОЗЫСК!") end
end

function ENT:SetPosterData(photoId, headline, body, subject)
    self:SetPhotoID(tostring(photoId or ""))
    self:SetHeadline(string.sub(tostring(headline or "ВНИМАНИЕ! РОЗЫСК!"), 1, 80))
    self:SetBody(string.sub(tostring(body or ""), 1, 180))
    self:SetSubjectName(string.sub(tostring(subject or ""), 1, 64))
end

function ENT:Use(ply)
    if not IsValid(ply) then return end
    if GRM.Notify then
        GRM.Notify(ply, self:GetHeadline() .. "  " .. self:GetSubjectName(), 230, 70, 60)
    end
    if GRM.Photo and GRM.Photo.ReadBytes and self:GetPhotoID() ~= "" then
        local bytes = GRM.Photo.ReadBytes(self:GetPhotoID())
        if bytes then
            net.Start("GRM_Photo_Blob")
                net.WriteString(self:GetPhotoID())
                net.WriteString("stamp")
                net.WriteUInt(#bytes, 16)
                net.WriteData(bytes, #bytes)
            net.Send(ply)
        end
    end
end
