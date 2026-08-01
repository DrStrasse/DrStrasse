--[[
	GRM Augmentation Chips System
	Система программируемых чипов для аугментаций
]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.AugChips = GRM.AugChips or {}
local CHIPS = GRM.AugChips

-- Конфигурация
CHIPS.Config = {
	MaxChipsPerPlayer = 5,           -- Максимум чипов на игрока
	ImplantSuccessRate = 0.85,       -- Шанс успешной имплантации (85%)
	RejectionChance = 0.10,          -- Шанс отторжения (10%)
	ComplicationChance = 0.05,       -- Шанс осложнений (5%)
	
	-- Модификаторы чипов
	Modifiers = {
		speed = {
			name = "Скорость",
			description = "Увеличение скорости передвижения",
			minValue = 1.0,
			maxValue = 2.0,
			defaultValue = 1.0,
			unit = "x"
		},
		stamina = {
			name = "Выносливость",
			description = "Увеличение выносливости и времени бега",
			minValue = 1.0,
			maxValue = 3.0,
			defaultValue = 1.0,
			unit = "x"
		},
		carryWeight = {
			name = "Грузоподъемность",
			description = "Увеличение максимального веса инвентаря",
			minValue = 0,
			maxValue = 100,
			defaultValue = 0,
			unit = "kg"
		},
		health = {
			name = "Здоровье",
			description = "Увеличение максимального здоровья",
			minValue = 0,
			maxValue = 500,
			defaultValue = 0,
			unit = "HP"
		},
		armor = {
			name = "Броня",
			description = "Увеличение максимальной брони",
			minValue = 0,
			maxValue = 200,
			defaultValue = 0,
			unit = "AP"
		},
		vision = {
			name = "Зрение",
			description = "Тип визуального эффекта",
			options = {"normal", "infrared", "nightvision", "zoom", "xray"},
			defaultValue = "normal"
		}
	},
	
	-- Типы чипов по категориям
	ChipCategories = {
		civilian = {
			name = "Гражданские",
			maxLevel = 2,
			color = Color(50, 200, 100),
			allowed = {"speed", "stamina", "carryWeight", "health"}
		},
		service = {
			name = "Служебные",
			maxLevel = 3,
			color = Color(0, 150, 255),
			allowed = {"speed", "stamina", "carryWeight", "health", "armor", "vision"}
		},
		military = {
			name = "Военные",
			maxLevel = 5,
			color = Color(255, 180, 50),
			allowed = {"speed", "stamina", "carryWeight", "health", "armor", "vision"}
		},
		experimental = {
			name = "Экспериментальные",
			maxLevel = 10,
			color = Color(255, 80, 80),
			allowed = {"speed", "stamina", "carryWeight", "health", "armor", "vision"}
		}
	}
}

-- Хранилище чипов
CHIPS.PlayerChips = CHIPS.PlayerChips or {}
CHIPS.ChipDatabase = CHIPS.ChipDatabase or {}

-- Получение чипов игрока
function CHIPS.GetPlayerChips(ply)
	if not IsValid(ply) then return {} end
	local charKey = GRM.Identity and GRM.Identity.CharacterKey(ply) or ply:SteamID64()
	CHIPS.PlayerChips[charKey] = CHIPS.PlayerChips[charKey] or {}
	return CHIPS.PlayerChips[charKey]
end

-- Создание нового чипа
function CHIPS.CreateChip(ply, chipData)
	if not IsValid(ply) then return false, "Недействительный игрок" end
	
	local playerChips = CHIPS.GetPlayerChips(ply)
	if #playerChips >= CHIPS.Config.MaxChipsPerPlayer then
		return false, "Достигнут максимум чипов (" .. CHIPS.Config.MaxChipsPerPlayer .. ")"
	end
	
	-- Валидация данных чипа
	if not chipData.category or not CHIPS.Config.ChipCategories[chipData.category] then
		return false, "Неверная категория чипа"
	end
	
	if not chipData.name or chipData.name == "" then
		return false, "Не указано название чипа"
	end
	
	local category = CHIPS.Config.ChipCategories[chipData.category]
	
	-- Проверка модификаторов
	local modifiers = {}
	for modKey, modValue in pairs(chipData.modifiers or {}) do
		local modConfig = CHIPS.Config.Modifiers[modKey]
		if modConfig and table.HasValue(category.allowed, modKey) then
			if modConfig.options then
				-- Опциональный модификатор (например, vision)
				if table.HasValue(modConfig.options, modValue) then
					modifiers[modKey] = modValue
				end
			else
				-- Числовой модификатор
				local numValue = tonumber(modValue)
				if numValue then
					numValue = math.Clamp(numValue, modConfig.minValue, modConfig.maxValue * (category.maxLevel / 5))
					modifiers[modKey] = numValue
				end
			end
		end
	end
	
	-- Создание чипа
	local chip = {
		id = "chip_" .. os.time() .. "_" .. math.random(1000, 9999),
		name = chipData.name,
		category = chipData.category,
		level = math.Clamp(tonumber(chipData.level) or 1, 1, category.maxLevel),
		modifiers = modifiers,
		implanted = false,
		created = os.time(),
		creator = GRM.Identity and GRM.Identity.CharacterKey(ply) or ply:SteamID64()
	}
	
	table.insert(playerChips, chip)
	CHIPS.SaveData()
	
	return true, chip
end

-- Удаление чипа
function CHIPS.RemoveChip(ply, chipId)
	if not IsValid(ply) then return false end
	
	local playerChips = CHIPS.GetPlayerChips(ply)
	for i, chip in ipairs(playerChips) do
		if chip.id == chipId then
			if chip.implanted then
				-- Снятие эффектов перед удалением
				CHIPS.RemoveChipEffects(ply, chip)
			end
			table.remove(playerChips, i)
			CHIPS.SaveData()
			return true
		end
	end
	
	return false
end

-- Имплантация чипа
function CHIPS.ImplantChip(ply, chipId)
	if not IsValid(ply) then return false, "Недействительный игрок" end
	
	local playerChips = CHIPS.GetPlayerChips(ply)
	local chip = nil
	
	for _, c in ipairs(playerChips) do
		if c.id == chipId then
			chip = c
			break
		end
	end
	
	if not chip then return false, "Чип не найден" end
	if chip.implanted then return false, "Чип уже имплантирован" end
	
	-- Подсчет имплантированных чипов
	local implantedCount = 0
	for _, c in ipairs(playerChips) do
		if c.implanted then implantedCount = implantedCount + 1 end
	end
	
	if implantedCount >= CHIPS.Config.MaxChipsPerPlayer then
		return false, "Достигнут максимум имплантированных чипов"
	end
	
	-- Бросок на успех имплантации
	local roll = math.random()
	
	if roll <= CHIPS.Config.ImplantSuccessRate then
		-- Успех
		chip.implanted = true
		chip.implantTime = os.time()
		CHIPS.ApplyChipEffects(ply, chip)
		CHIPS.SaveData()
		return true, "Имплантация успешна"
		
	elseif roll <= CHIPS.Config.ImplantSuccessRate + CHIPS.Config.RejectionChance then
		-- Отторжение
		CHIPS.RemoveChip(ply, chipId)
		ply:TakeDamage(math.random(20, 40))
		return false, "Отторжение чипа! Вы получили урон."
		
	else
		-- Осложнения
		chip.implanted = true
		chip.implantTime = os.time()
		chip.hasComplications = true
		CHIPS.ApplyChipEffects(ply, chip)
		CHIPS.SaveData()
		ply:TakeDamage(math.random(10, 25))
		return true, "Имплантация с осложнениями! Чип работает, но вы получили урон."
	end
end

-- Применение эффектов чипа
function CHIPS.ApplyChipEffects(ply, chip)
	if not IsValid(ply) or not chip or not chip.implanted then return end
	
	for modKey, modValue in pairs(chip.modifiers or {}) do
		if modKey == "speed" then
			local baseSpeed = 200
			local baseRunSpeed = 400
			ply:SetWalkSpeed(baseSpeed * modValue)
			ply:SetRunSpeed(baseRunSpeed * modValue)
			
		elseif modKey == "health" then
			local currentMax = ply:GetMaxHealth()
			ply:SetMaxHealth(currentMax + modValue)
			ply:SetHealth(ply:Health() + modValue)
			
		elseif modKey == "armor" then
			local currentArmor = ply:Armor()
			ply:SetArmor(math.min(currentArmor + modValue, 255))
			
		elseif modKey == "carryWeight" then
			-- Интеграция с системой инвентаря (если есть)
			if GRM.Inventory and GRM.Inventory.SetBonusWeight then
				GRM.Inventory.SetBonusWeight(ply, modValue)
			end
			ply:SetNWInt("GRM_ChipCarryWeight", modValue)
			
		elseif modKey == "stamina" then
			-- Интеграция с системой выносливости (если есть)
			if GRM.Stamina and GRM.Stamina.SetMultiplier then
				GRM.Stamina.SetMultiplier(ply, modValue)
			end
			ply:SetNWFloat("GRM_ChipStamina", modValue)
			
		elseif modKey == "vision" then
			-- Интеграция с системой зрения
			if SERVER then
				net.Start("GRM_Augmentation_Update")
				net.WriteString(modValue) -- infrared, nightvision, etc.
				net.WriteBool(true)
				net.Send(ply)
			end
		end
	end
	
	-- Уведомление
	if SERVER then
		ply:ChatPrint("[Аугментации] Эффекты чипа '" .. chip.name .. "' активированы")
	end
end

-- Снятие эффектов чипа
function CHIPS.RemoveChipEffects(ply, chip)
	if not IsValid(ply) or not chip then return end
	
	for modKey, modValue in pairs(chip.modifiers or {}) do
		if modKey == "speed" then
			ply:SetWalkSpeed(200)
			ply:SetRunSpeed(400)
			
		elseif modKey == "health" then
			local currentMax = ply:GetMaxHealth()
			ply:SetMaxHealth(currentMax - modValue)
			ply:SetHealth(math.min(ply:Health(), ply:GetMaxHealth()))
			
		elseif modKey == "armor" then
			local currentArmor = ply:Armor()
			ply:SetArmor(math.max(0, currentArmor - modValue))
			
		elseif modKey == "carryWeight" then
			if GRM.Inventory and GRM.Inventory.SetBonusWeight then
				GRM.Inventory.SetBonusWeight(ply, 0)
			end
			ply:SetNWInt("GRM_ChipCarryWeight", 0)
			
		elseif modKey == "stamina" then
			if GRM.Stamina and GRM.Stamina.SetMultiplier then
				GRM.Stamina.SetMultiplier(ply, 1.0)
			end
			ply:SetNWFloat("GRM_ChipStamina", 1.0)
			
		elseif modKey == "vision" then
			if SERVER then
				net.Start("GRM_Augmentation_Update")
				net.WriteString(modValue)
				net.WriteBool(false)
				net.Send(ply)
			end
		end
	end
end

-- Извлечение чипа
function CHIPS.ExtractChip(ply, chipId)
	if not IsValid(ply) then return false, "Недействительный игрок" end
	
	local playerChips = CHIPS.GetPlayerChips(ply)
	local chip = nil
	
	for _, c in ipairs(playerChips) do
		if c.id == chipId then
			chip = c
			break
		end
	end
	
	if not chip then return false, "Чип не найден" end
	if not chip.implanted then return false, "Чип не имплантирован" end
	
	-- Снятие эффектов
	CHIPS.RemoveChipEffects(ply, chip)
	chip.implanted = false
	chip.implantTime = nil
	chip.hasComplications = nil
	
	CHIPS.SaveData()
	
	if SERVER then
		ply:ChatPrint("[Аугментации] Чип '" .. chip.name .. "' извлечен")
	end
	
	return true, "Чип извлечен"
end

-- Сохранение данных
function CHIPS.SaveData()
	if not SERVER then return end
	
	file.CreateDir("grm_augmentations")
	file.Write("grm_augmentations/chips.txt", util.TableToJSON(CHIPS.PlayerChips, true))
end

-- Загрузка данных
function CHIPS.LoadData()
	if not SERVER then return end
	
	if not file.Exists("grm_augmentations/chips.txt", "DATA") then return end
	
	local data = util.JSONToTable(file.Read("grm_augmentations/chips.txt", "DATA"))
	if data then
		CHIPS.PlayerChips = data
	end
end

-- Восстановление эффектов при спавне
if SERVER then
	util.AddNetworkString("GRM_AugChip_Create")
	util.AddNetworkString("GRM_AugChip_Remove")
	util.AddNetworkString("GRM_AugChip_Implant")
	util.AddNetworkString("GRM_AugChip_Extract")
	util.AddNetworkString("GRM_AugChip_GetList")
	util.AddNetworkString("GRM_AugChip_SendList")
	util.AddNetworkString("GRM_AugChip_OpenProgrammer")
	util.AddNetworkString("GRM_AugStation_Open")
	util.AddNetworkString("GRM_AugStation_SpawnChip")
	
	hook.Add("Initialize", "GRM_AugChips_Init", function()
		CHIPS.LoadData()
	end)
	
	hook.Add("ShutDown", "GRM_AugChips_Save", function()
		CHIPS.SaveData()
	end)
	
	hook.Add("PlayerSpawn", "GRM_AugChips_Spawn", function(ply)
		local playerChips = CHIPS.GetPlayerChips(ply)
		
		timer.Simple(0.2, function()
			if not IsValid(ply) then return end
			
			for _, chip in ipairs(playerChips) do
				if chip.implanted then
					CHIPS.ApplyChipEffects(ply, chip)
				end
			end
		end)
	end)
	
	-- Обработка создания чипа
	net.Receive("GRM_AugChip_Create", function(len, ply)
		local chipData = net.ReadTable()
		local success, result = CHIPS.CreateChip(ply, chipData)
		
		net.Start("GRM_AugChip_Create")
		net.WriteBool(success)
		if success then
			net.WriteTable(result)
		else
			net.WriteString(result)
		end
		net.Send(ply)
	end)
	
	-- Обработка удаления чипа
	net.Receive("GRM_AugChip_Remove", function(len, ply)
		local chipId = net.ReadString()
		local success = CHIPS.RemoveChip(ply, chipId)
		
		net.Start("GRM_AugChip_Remove")
		net.WriteBool(success)
		net.WriteString(chipId)
		net.Send(ply)
	end)
	
	-- Обработка имплантации
	net.Receive("GRM_AugChip_Implant", function(len, ply)
		local chipId = net.ReadString()
		local success, message = CHIPS.ImplantChip(ply, chipId)
		
		net.Start("GRM_AugChip_Implant")
		net.WriteBool(success)
		net.WriteString(message)
		net.WriteString(chipId)
		net.Send(ply)
	end)
	
	-- Извлечение чипа
	net.Receive("GRM_AugChip_Extract", function(len, ply)
		local chipId = net.ReadString()
		local success, message = CHIPS.ExtractChip(ply, chipId)
		
		net.Start("GRM_AugChip_Extract")
		net.WriteBool(success)
		net.WriteString(message)
		net.WriteString(chipId)
		net.Send(ply)
	end)
	
	-- Получение списка чипов
	net.Receive("GRM_AugChip_GetList", function(len, ply)
		local playerChips = CHIPS.GetPlayerChips(ply)
		
		net.Start("GRM_AugChip_SendList")
		net.WriteTable(playerChips)
		net.WriteTable(CHIPS.Config)
		net.Send(ply)
	end)
	
	-- Открытие станции
	net.Receive("GRM_AugStation_Open", function(len, ply)
		local station = net.ReadEntity()
		if not IsValid(station) then return end
		
		-- Отправка данных для открытия меню станции
		net.Start("GRM_AugStation_Open")
		net.WriteEntity(station)
		net.WriteTable(CHIPS.Config)
		net.Send(ply)
	end)
	
	-- Создание физического чипа
	net.Receive("GRM_AugStation_SpawnChip", function(len, ply)
		local chipData = net.ReadTable()
		
		-- Создание чипа в базе данных
		local success, result = CHIPS.CreateChip(ply, chipData)
		if not success then
			ply:ChatPrint("[Аугментации] Ошибка создания чипа: " .. result)
			return
		end
		
		-- Создание физической модели чипа
		local chip = ents.Create("grm_augmentation_chip")
		if IsValid(chip) then
			chip:SetPos(ply:GetPos() + ply:GetForward() * 50 + Vector(0, 0, 10))
			chip:SetAngles(Angle(0, ply:EyeAngles().y, 0))
			chip:SetChipID(result.id)
			chip:SetChipName(result.name)
			chip:SetChipCategory(result.category)
			chip:SetChipLevel(result.level)
			chip:Spawn()
			
			-- Сохранение в базе данных чипов
			CHIPS.ChipDatabase[result.id] = result
			
			ply:ChatPrint("[Аугментации] Чип создан: " .. result.name)
			ply:ChatPrint("[Аугментации] Подберите чип чтобы добавить его в инвентарь")
		end
	end)
	
	print("[GRM AugChips] Chip system v1.0 loaded")
end
