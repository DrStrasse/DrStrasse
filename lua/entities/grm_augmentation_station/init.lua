AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel("models/props_c17/FurnitureFridge001a.mdl")
	self:PhysicsInit(SOLID_BBOX)
	self:SetMoveType(MOVETYPE_NONE)
	self:SetSolid(SOLID_BBOX)
	self:SetUseType(SIMPLE_USE)
	self:SetCollisionBounds(Vector(-30, -30, 0), Vector(30, 30, 100))
	
	self:SetActive(true)
	self:SetStationName("Augmentation Station")
	
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
		phys:EnableMotion(false)
	end
end

function ENT:Use(activator, caller)
	if not IsValid(caller) or not caller:IsPlayer() then return end
	
	if not self:GetActive() then
		caller:ChatPrint("[Аугментации] Станция неактивна!")
		return
	end
	
	-- Отправка запроса на открытие меню станции
	net.Start("GRM_AugStation_Open")
	net.WriteEntity(self)
	net.Send(caller)
end

function ENT:OnRemove()
	-- Очистка при удалении
end
