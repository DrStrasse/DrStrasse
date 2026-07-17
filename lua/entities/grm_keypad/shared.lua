--[[--------------------------------------------------------------------
    grm_keypad — Интерактивный Кейпад GRM (Код 70)
    Поддерживает:
      - 3D2D экран и интерактивные кнопки на корпусе
      - Режимы: PIN-код, Доступ Фракции, Платный проход (GRM Cash)
      - Прямую связку с Fading Door и Numpad
      - Взлом с помощью QTE-Отмычки ds_lockpick / Крякера
----------------------------------------------------------------------]]

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "FFD Keypad"
ENT.Author = "GRM"
ENT.Contact = ""
ENT.Purpose = "Электронный кодовый замок с 3D2D дисплеем"
ENT.Instructions = "Нажимайте кнопки на экране или используйте [E]"
ENT.Category = "GRM"

ENT.Spawnable = true
ENT.AdminSpawnable = true

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "Password")
    self:NetworkVar("String", 1, "DisplayText")
    self:NetworkVar("Int",    0, "Status")      -- 0: Normal, 1: Granted, 2: Denied
    self:NetworkVar("Int",    1, "Cost")        -- Платный проход в GRM
    self:NetworkVar("Int",    2, "Mode")        -- 0: PIN, 1: Faction, 2: Paid
    self:NetworkVar("String", 2, "Faction")
end

if SERVER then
    function ENT:IsKeypadLocked()
        return self:GetStatus() == 2 or self.IsGrantActive
    end
end
