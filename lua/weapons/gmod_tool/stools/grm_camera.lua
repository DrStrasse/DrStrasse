-- GRM Camera Tool v1.0.0 — безопасная замена штатного camera
TOOL.Category = "GRM"
TOOL.Name = "GRM Камера"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar = { key = "37", locked = "0", toggle = "1" }
TOOL.Information = { { name = "left" }, { name = "right" }, { name = "reload" } }

if CLIENT then
    language.Add("tool.grm_camera.name", "GRM Камера")
    language.Add("tool.grm_camera.desc", "Камера наблюдения с безопасным владением")
    language.Add("tool.grm_camera.left", "Поставить камеру из текущего вида")
    language.Add("tool.grm_camera.right", "Поставить камеру, следящую за целью")
    language.Add("tool.grm_camera.reload", "Удалить свою камеру")
end

cleanup.Register("grm_cameras")

local function canEdit(ply, ent)
    return GRM and GRM.BuildTools and GRM.BuildTools.CanEdit and GRM.BuildTools.CanEdit(ply, ent)
end

local function makeCamera(ply, key, locked, toggle, trace)
    if not IsValid(ply) or not ply:CheckLimit("cameras") then return nil end
    for _, old in ipairs(ents.FindByClass("gmod_cameraprop")) do
        if IsValid(old) and tonumber(old.controlkey) == key and canEdit(ply, old) then old:Remove() end
    end
    local ent = ents.Create("gmod_cameraprop")
    if not IsValid(ent) then return nil end
    ent:SetPos(trace.StartPos)
    ent:SetAngles(ply:EyeAngles())
    ent:SetPlayer(ply)
    ent.controlkey, ent.locked, ent.toggle = key, locked, toggle
    if ent.SetKey then ent:SetKey(key) end
    ent:Spawn()
    ent:Activate()
    if ent.SetTracking then ent:SetTracking(NULL, Vector(0, 0, 0)) end
    if ent.SetLocked then ent:SetLocked(locked) end
    if ent.ApplyKeybinds then ent:ApplyKeybinds(ply) end
    ply:AddCount("cameras", ent)
    ply:AddCleanup("grm_cameras", ent)
    if GRM and GRM.BuildTools and GRM.BuildTools.MarkOwned then GRM.BuildTools.MarkOwned(ply, ent) end
    undo.Create("GRM Камера") undo.AddEntity(ent) undo.SetPlayer(ply) undo.Finish()
    return ent
end

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not IsValid(ply) then return false end
    local key = math.Clamp(math.floor(self:GetClientNumber("key", 37)), 1, 159)
    local ent = makeCamera(ply, key, self:GetClientNumber("locked", 0) == 1, self:GetClientNumber("toggle", 1) == 1, trace)
    return IsValid(ent), ent
end

function TOOL:RightClick(trace)
    if CLIENT then return true end
    local ok, camera = self:LeftClick(trace)
    if not ok or not IsValid(camera) then return false end
    local target = trace.Entity
    if not IsValid(target) or target:IsWorld() then target = self:GetOwner() end
    local hit = target:IsPlayer() and target:GetPos() or trace.HitPos
    if camera.SetTracking then camera:SetTracking(target, target:WorldToLocal(hit)) end
    return true
end

function TOOL:Reload(trace)
    if CLIENT then return true end
    local ent = trace.Entity
    if not IsValid(ent) or ent:GetClass() ~= "gmod_cameraprop" or not canEdit(self:GetOwner(), ent) then return false end
    ent:Remove()
    return true
end

function TOOL.BuildCPanel(panel)
    panel:Help("Штатная камера отключена. Используйте только этот инструмент GRM.")
    panel:KeyBinder("Клавиша камеры", "grm_camera_key")
    panel:CheckBox("Зафиксировать направление", "grm_camera_locked")
    panel:CheckBox("Режим переключателя", "grm_camera_toggle")
end
