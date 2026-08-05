include("shared.lua")

function ENT:Draw()
	self:DrawModel()
	
	-- Отображение информации о чипе
	local pos = self:GetPos() + Vector(0, 0, 15)
	local ang = LocalPlayer():EyeAngles()
	ang:RotateAroundAxis(ang:Up(), -90)
	ang:RotateAroundAxis(ang:Forward(), 90)
	
	cam.Start3D2D(pos, ang, 0.1)
		draw.SimpleTextOutlined(
			self:GetChipName() or "Unknown Chip",
			"DermaDefault",
			0, 0,
			Color(255, 255, 255),
			TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER,
			1,
			Color(0, 0, 0)
		)
		
		local category = self:GetChipCategory() or "unknown"
		local level = self:GetChipLevel() or 1
		draw.SimpleTextOutlined(
			category .. " (Lvl " .. level .. ")",
			"DermaDefault",
			0, 20,
			Color(200, 200, 200),
			TEXT_ALIGN_CENTER,
			TEXT_ALIGN_CENTER,
			1,
			Color(0, 0, 0)
		)
		
		if self:GetImplanted() then
			draw.SimpleTextOutlined(
				"[ИМПЛАНТИРОВАН]",
				"DermaDefault",
				0, 40,
				Color(255, 100, 100),
				TEXT_ALIGN_CENTER,
				TEXT_ALIGN_CENTER,
				1,
				Color(0, 0, 0)
			)
		end
	cam.End3D2D()
end
