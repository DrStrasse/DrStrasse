-- GRM Light Tool v1.0.0 — безопасная замена штатного light
TOOL.Category = "GRM"
TOOL.Name = "GRM Источник света"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar = { r = "255", g = "245", b = "220", brightness = "2", size = "256", key = "37", toggle = "1", freeze = "1" }
TOOL.Information = { { name = "left" }, { name = "right" }, { name = "reload" } }

if CLIENT then
    language.Add("tool.grm_light.name", "GRM Источник света")
    language.Add("tool.grm_light.desc", "Безопасный динамический источник света")
    language.Add("tool.grm_light.left", "Поставить или обновить свой источник")
    language.Add("tool.grm_light.right", "Скопировать настройки источника")
    language.Add("tool.grm_light.reload", "Удалить свой источник")
end
cleanup.Register("grm_lights")

local function canEdit(ply, ent)
    return GRM and GRM.BuildTools and GRM.BuildTools.CanEdit and GRM.BuildTools.CanEdit(ply, ent)
end

local function readCfg(tool)
    return math.Clamp(tool:GetClientNumber("r", 255), 0, 255),
        math.Clamp(tool:GetClientNumber("g", 255), 0, 255),
        math.Clamp(tool:GetClientNumber("b", 255), 0, 255),
        math.Clamp(tool:GetClientNumber("brightness", 2), -6, 8),
        math.Clamp(tool:GetClientNumber("size", 256), 32, 1024),
        math.Clamp(math.floor(tool:GetClientNumber("key", 37)), 1, 159),
        tool:GetClientNumber("toggle", 1) == 1
end

local function bindKey(ply, ent, key)
    if not numpad then return end
    if ent.GRMNumDown then numpad.Remove(ent.GRMNumDown) end
    if ent.GRMNumUp then numpad.Remove(ent.GRMNumUp) end
    ent.GRMNumDown = numpad.OnDown(ply, key, "GRM_LightToggle", ent, 1)
    ent.GRMNumUp = numpad.OnUp(ply, key, "GRM_LightToggle", ent, 0)
end

if SERVER then
    numpad.Register("GRM_LightToggle", function(_, ent, state)
        if not IsValid(ent) or ent:GetClass() ~= "gmod_light" then return false end
        if ent.GetToggle and ent:GetToggle() then
            if state == 0 then return end
            if ent.Toggle then return ent:Toggle() end
        elseif ent.SetOn then
            ent:SetOn(state == 1)
        end
    end)
end

function TOOL:LeftClick(trace)
    if IsValid(trace.Entity) and trace.Entity:IsPlayer() then return false end
    if CLIENT then return true end
    local ply = self:GetOwner()
    local r, g, b, brightness, size, key, toggle = readCfg(self)
    local ent = trace.Entity
    if IsValid(ent) and ent:GetClass() == "gmod_light" then
        if not canEdit(ply, ent) then return false end
    else
        if not ply:CheckLimit("lights") then return false end
        ent = ents.Create("gmod_light")
        if not IsValid(ent) then return false end
        ent:SetPos(trace.HitPos + trace.HitNormal * 8)
        ent:SetAngles(trace.HitNormal:Angle() - Angle(90, 0, 0))
        ent:SetPlayer(ply)
        ent:Spawn()
        ent:Activate()
        ply:AddCount("lights", ent)
        ply:AddCleanup("grm_lights", ent)
        if GRM and GRM.BuildTools and GRM.BuildTools.MarkOwned then GRM.BuildTools.MarkOwned(ply, ent) end
        undo.Create("GRM Источник света") undo.AddEntity(ent) undo.SetPlayer(ply) undo.Finish()
    end
    ent:SetColor(Color(r, g, b, 255))
    if ent.SetBrightness then ent:SetBrightness(brightness) end
    if ent.SetLightSize then ent:SetLightSize(size) end
    if ent.SetToggle then ent:SetToggle(toggle) end
    if ent.SetOn then ent:SetOn(true) end
    ent.lightr, ent.lightg, ent.lightb = r, g, b
    ent.Brightness, ent.Size, ent.KeyDown, ent.on = brightness, size, key, true
    bindKey(ply, ent, key)
    local ph = ent:GetPhysicsObject()
    if IsValid(ph) and self:GetClientNumber("freeze", 1) == 1 then ph:EnableMotion(false) end
    return true
end

function TOOL:RightClick(trace)
    local ent = trace.Entity
    if not IsValid(ent) or ent:GetClass() ~= "gmod_light" then return false end
    if CLIENT then return true end
    if not canEdit(self:GetOwner(), ent) then return false end
    local c = ent:GetColor()
    local ply = self:GetOwner()
    ply:ConCommand("grm_light_r " .. c.r) ply:ConCommand("grm_light_g " .. c.g) ply:ConCommand("grm_light_b " .. c.b)
    ply:ConCommand("grm_light_brightness " .. tostring(ent.Brightness or 2))
    ply:ConCommand("grm_light_size " .. tostring(ent.Size or 256))
    return true
end

function TOOL:Reload(trace)
    if CLIENT then return true end
    local ent = trace.Entity
    if not IsValid(ent) or ent:GetClass() ~= "gmod_light" or not canEdit(self:GetOwner(), ent) then return false end
    ent:Remove()
    return true
end

function TOOL.BuildCPanel(panel)
    panel:Help("Штатный Light отключён. Источник принадлежит создавшему его персонажу.")
    panel:KeyBinder("Клавиша", "grm_light_key")
    panel:NumSlider("Яркость", "grm_light_brightness", -6, 8, 0)
    panel:NumSlider("Радиус", "grm_light_size", 32, 1024, 0)
    panel:CheckBox("Переключатель", "grm_light_toggle")
    panel:CheckBox("Заморозить", "grm_light_freeze")
    panel:ColorPicker("Цвет", "grm_light_r", "grm_light_g", "grm_light_b")
end
