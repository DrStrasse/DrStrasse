--[[
	GRM Augmentations HUD
	Отображение активных аугментаций и чипов на экране
]]

if not CLIENT then return end

GRM = GRM or {}
GRM.AugHUD = GRM.AugHUD or {}
local HUD = GRM.AugHUD

-- Настройки HUD
HUD.Config = {
	Enabled = true,
	ShowChips = true,
	ShowEffects = true,
	Position = {x = 20, y = ScrH() - 200},
	AutoRefresh = 5, -- секунды
}

-- GRM UI Style
local GRM_COLORS = {
	bg = Color(15, 20, 30, 200),
	panel = Color(25, 35, 50, 220),
	accent = Color(0, 150, 255),
	text = Color(220, 230, 240),
	text_dim = Color(140, 150, 170),
	success = Color(50, 200, 100),
	warning = Color(255, 180, 50),
	error = Color(255, 80, 80),
	border = Color(60, 80, 110, 150)
}

-- GRM Fonts
surface.CreateFont("GRMAugHUD_Title", { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("GRMAugHUD_Normal", { font = "Roboto", size = 13, weight = 500, extended = true })
surface.CreateFont("GRMAugHUD_Small", { font = "Roboto", size = 11, weight = 500, extended = true })

-- Кэш данных
HUD.CachedChips = {}
HUD.LastUpdate = 0

-- Обновление данных
function HUD.UpdateData()
	local ply = LocalPlayer()
	if not IsValid(ply) then return end
	
	-- Получение списка чипов
	if GRM.AugChips then
		HUD.CachedChips = GRM.AugChips.GetPlayerChips(ply) or {}
	end
	
	HUD.LastUpdate = CurTime()
end

-- Автообновление
timer.Create("GRM_AugHUD_AutoRefresh", HUD.Config.AutoRefresh, 0, function()
	HUD.UpdateData()
end)

-- HUD Paint
hook.Add("HUDPaint", "GRM_Augmentations_ChipsHUD", function()
	if not HUD.Config.Enabled then return end
	
	local ply = LocalPlayer()
	if not IsValid(ply) or not ply:Alive() then return end
	
	-- Проверка наличия аугментаций
	if not GRM.Augmentations then return end
	
	local playerData = GRM.Augmentations.GetPlayerData(ply)
	if not playerData or not playerData.augmented then return end
	
	local chips = HUD.CachedChips or {}
	local implantedChips = {}
	
	for _, chip in ipairs(chips) do
		if chip.implanted then
			table.insert(implantedChips, chip)
		end
	end
	
	if #implantedChips == 0 then return end
	
	local x, y = HUD.Config.Position.x, HUD.Config.Position.y
	local panelWidth = 250
	local panelHeight = 40 + (#implantedChips * 25)
	
	-- Фон панели
	draw.RoundedBox(6, x, y, panelWidth, panelHeight, GRM_COLORS.bg)
	surface.SetDrawColor(GRM_COLORS.border)
	surface.DrawOutlinedRect(x, y, panelWidth, panelHeight, 1)
	
	-- Заголовок
	draw.RoundedBoxEx(6, x, y, panelWidth, 30, GRM_COLORS.panel, true, true, false, false)
	draw.SimpleText("🔧 АУГМЕНТАЦИИ", "GRMAugHUD_Title", x + 10, y + 15, GRM_COLORS.accent, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	draw.SimpleText(#implantedChips, "GRMAugHUD_Small", x + panelWidth - 10, y + 15, GRM_COLORS.text_dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	
	-- Список чипов
	local chipY = y + 35
	for _, chip in ipairs(implantedChips) do
		local catConfig = GRM.AugChips.Config.ChipCategories[chip.category]
		local catColor = catConfig and catConfig.color or GRM_COLORS.text
		
		-- Иконка статуса
		local statusIcon = chip.hasComplications and "⚠️" or "✓"
		local statusColor = chip.hasComplications and GRM_COLORS.warning or GRM_COLORS.success
		
		draw.SimpleText(statusIcon, "GRMAugHUD_Normal", x + 10, chipY, statusColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		
		-- Название чипа
		draw.SimpleText(chip.name, "GRMAugHUD_Normal", x + 30, chipY, GRM_COLORS.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
		
		-- Категория
		draw.SimpleText(catConfig and catConfig.name or chip.category, "GRMAugHUD_Small", x + panelWidth - 10, chipY, catColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
		
		chipY = chipY + 25
	end
end)

-- Консольные команды
concommand.Add("grm_aughud_toggle", function()
	HUD.Config.Enabled = not HUD.Config.Enabled
	chat.AddText(HUD.Config.Enabled and Color(100, 255, 100) or Color(255, 100, 100), 
		"[GRM] HUD аугментаций ", HUD.Config.Enabled and "включен" or "выключен")
end)

concommand.Add("grm_aughud_refresh", function()
	HUD.UpdateData()
	chat.AddText(Color(100, 200, 255), "[GRM] Данные HUD обновлены")
end)

-- Инициализация
hook.Add("InitPostEntity", "GRM_AugHUD_Init", function()
	HUD.UpdateData()
end)

print("[GRM AugHUD] Augmentations HUD loaded")
