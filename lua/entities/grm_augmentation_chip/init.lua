AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
	self:SetModel("models/bull/gates/logic.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	
	local phys = self:GetPhysicsObject()
	if IsValid(phys) then
		phys:Wake()
	end
	
	self:SetImplanted(false)
end

function ENT:Use(activator, caller)
	if not IsValid(caller) or not caller:IsPlayer() then return end
	
	-- Если чип уже имплантирован, нельзя взять
	if self:GetImplanted() then
		caller:ChatPrint("[Аугментации] Этот чип уже имплантирован!")
		return
	end
	
	-- Проверка лимита чипов
	local playerChips = GRM.AugChips.GetPlayerChips(caller)
	if #playerChips >= GRM.AugChips.Config.MaxChipsPerPlayer then
		caller:ChatPrint("[Аугментации] У вас уже максимум чипов (" .. GRM.AugChips.Config.MaxChipsPerPlayer .. ")!")
		return
	end
	
	-- Получение данных чипа
	local chipId = self:GetChipID()
	local chipData = GRM.AugChips.ChipDatabase[chipId]
	
	if not chipData then
		caller:ChatPrint("[Аугментации] Ошибка: данные чипа не найдены!")
		return
	end
	
	-- Добавление чипа игроку
	table.insert(playerChips, chipData)
	self:SetImplanted(true)
	self:SetOwner(caller)
	
	caller:ChatPrint("[Аугментации] Вы получили чип: " .. chipData.name)
	
	-- Удаление физической модели
	self:Remove()
	
	GRM.AugChips.SaveData()
end

function ENT:OnRemove()
	-- Очистка при удалении
end
