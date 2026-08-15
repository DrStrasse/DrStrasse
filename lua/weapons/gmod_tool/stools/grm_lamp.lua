-- GRM Lamp Tool v1.0.0 — безопасная замена штатного lamp
TOOL.Category = "GRM"
TOOL.Name = "GRM Лампа-прожектор"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar = { r = "255", g = "245", b = "220", brightness = "4", fov = "90", distance = "1024", texture = "effects/flashlight001", key = "37", toggle = "1", freeze = "1" }
TOOL.Information = { { name = "left" }, { name = "right" }, { name = "reload" } }

if CLIENT then
    language.Add("tool.grm_lamp.name", "GRM Лампа-прожектор")
    language.Add("tool.grm_lamp.desc", "Управляемая лампа с ограниченными безопасными параметрами")
    language.Add("tool.grm_lamp.left", "Поставить или обновить свою лампу")
    language.Add("tool.grm_lamp.right", "Скопировать настройки лампы")
    language.Add("tool.grm_lamp.reload", "Удалить свою лампу")
end
cleanup.Register("grm_lamps")

local function canEdit(ply, ent)
    return GRM and GRM.BuildTools and GRM.BuildTools.CanEdit and GRM.BuildTools.CanEdit(ply, ent)
end
local function textureAllowed(tex)
    tex = string.lower(tostring(tex or ""))
    return GRM and GRM.BuildTools and GRM.BuildTools.LampTextures and GRM.BuildTools.LampTextures[tex] and tex or "effects/flashlight001"
end
local function bindKey(ply, ent, key)
    if ent.GRMNumDown then numpad.Remove(ent.GRMNumDown) end
    if ent.GRMNumUp then numpad.Remove(ent.GRMNumUp) end
    ent.GRMNumDown = numpad.OnDown(ply, key, "GRM_LampToggle", ent, 1)
    ent.GRMNumUp = numpad.OnUp(ply, key, "GRM_LampToggle", ent, 0)
end
if SERVER then
    numpad.Register("GRM_LampToggle", function(_, ent, state)
        if not IsValid(ent) or ent:GetClass() ~= "gmod_lamp" then return false end
        if ent.GetToggle and ent:GetToggle() then
            if state == 0 then return end
            if ent.Toggle then return ent:Toggle() end
        elseif ent.Switch then ent:Switch(state == 1) end
    end)
end

function TOOL:LeftClick(trace)
    if IsValid(trace.Entity) and trace.Entity:IsPlayer() then return false end
    if CLIENT then return true end
    local ply = self:GetOwner()
    local ent = trace.Entity
    local created = false
    if IsValid(ent) and ent:GetClass() == "gmod_lamp" then
        if not canEdit(ply, ent) then return false end
    else
        if not ply:CheckLimit("lamps") then return false end
        ent = ents.Create("gmod_lamp")
        if not IsValid(ent) then return false end
        ent:SetModel("models/lamps/torch.mdl")
        ent:SetPos(trace.HitPos + trace.HitNormal * 12)
        ent:SetAngles(trace.HitNormal:Angle() - Angle(90, 0, 0))
        ent:SetPlayer(ply)
        ent:Spawn()
        ent:Activate()
        created = true
    end
    local r = math.Clamp(self:GetClientNumber("r", 255), 0, 255)
    local g = math.Clamp(self:GetClientNumber("g", 255), 0, 255)
    local b = math.Clamp(self:GetClientNumber("b", 255), 0, 255)
    local brightness = math.Clamp(self:GetClientNumber("brightness", 4), 0, 8)
    local fov = math.Clamp(self:GetClientNumber("fov", 90), 10, 170)
    local distance = math.Clamp(self:GetClientNumber("distance", 1024), 64, 2048)
    local key = math.Clamp(math.floor(self:GetClientNumber("key", 37)), 1, 159)
    local toggle = self:GetClientNumber("toggle", 1) == 1
    local tex = textureAllowed(self:GetClientInfo("texture"))
    ent:SetColor(Color(r, g, b, 255))
    if ent.SetFlashlightTexture then ent:SetFlashlightTexture(tex) end
    if ent.SetLightFOV then ent:SetLightFOV(fov) end
    if ent.SetDistance then ent:SetDistance(distance) end
    if ent.SetBrightness then ent:SetBrightness(brightness) end
    if ent.SetToggle then ent:SetToggle(toggle) end
    if ent.Switch then ent:Switch(true) end
    if ent.UpdateLight then ent:UpdateLight() end
    ent.Texture, ent.fov, ent.distance, ent.brightness, ent.KeyDown = tex, fov, distance, brightness, key
    ent.r, ent.g, ent.b = r, g, b
    bindKey(ply, ent, key)
    local ph = ent:GetPhysicsObject()
    if IsValid(ph) and self:GetClientNumber("freeze", 1) == 1 then ph:EnableMotion(false) end
    if created then
        ply:AddCount("lamps", ent) ply:AddCleanup("grm_lamps", ent)
        if GRM and GRM.BuildTools and GRM.BuildTools.MarkOwned then GRM.BuildTools.MarkOwned(ply, ent) end
        undo.Create("GRM Лампа") undo.AddEntity(ent) undo.SetPlayer(ply) undo.Finish()
    end
    return true
end

function TOOL:RightClick(trace)
    local ent = trace.Entity
    if not IsValid(ent) or ent:GetClass() ~= "gmod_lamp" then return false end
    if CLIENT then return true end
    if not canEdit(self:GetOwner(), ent) then return false end
    local c, ply = ent:GetColor(), self:GetOwner()
    ply:ConCommand("grm_lamp_r " .. c.r) ply:ConCommand("grm_lamp_g " .. c.g) ply:ConCommand("grm_lamp_b " .. c.b)
    ply:ConCommand("grm_lamp_brightness " .. tostring(ent.brightness or 4))
    ply:ConCommand("grm_lamp_fov " .. tostring(ent.fov or 90))
    ply:ConCommand("grm_lamp_distance " .. tostring(ent.distance or 1024))
    ply:ConCommand("grm_lamp_texture " .. textureAllowed(ent.Texture))
    return true
end

function TOOL:Reload(trace)
    if CLIENT then return true end
    local ent = trace.Entity
    if not IsValid(ent) or ent:GetClass() ~= "gmod_lamp" or not canEdit(self:GetOwner(), ent) then return false end
    ent:Remove()
    return true
end

function TOOL.BuildCPanel(panel)
    panel:Help("Штатный Lamp отключён. Текстуры ограничены безопасным набором GRM.")
    panel:KeyBinder("Клавиша", "grm_lamp_key")
    panel:NumSlider("Яркость", "grm_lamp_brightness", 0, 8, 0)
    panel:NumSlider("Угол луча", "grm_lamp_fov", 10, 170, 0)
    panel:NumSlider("Дальность", "grm_lamp_distance", 64, 2048, 0)
    panel:CheckBox("Переключатель", "grm_lamp_toggle")
    panel:CheckBox("Заморозить", "grm_lamp_freeze")
    panel:ColorPicker("Цвет", "grm_lamp_r", "grm_lamp_g", "grm_lamp_b")
end
