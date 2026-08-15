-- GRM Colour Tool v1.0.0 — безопасная замена штатного colour/color
TOOL.Category = "GRM"
TOOL.Name = "GRM Цвет"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar = { r = "255", g = "255", b = "255", a = "255" }
TOOL.Information = { { name = "left" }, { name = "right" }, { name = "reload" } }

if CLIENT then
    language.Add("tool.grm_colour.name", "GRM Цвет")
    language.Add("tool.grm_colour.desc", "Безопасная окраска только своих объектов")
    language.Add("tool.grm_colour.left", "Применить цвет и прозрачность")
    language.Add("tool.grm_colour.right", "Скопировать цвет")
    language.Add("tool.grm_colour.reload", "Сбросить цвет")
end

local function target(trace)
    local ent = trace and trace.Entity
    if IsValid(ent) and IsValid(ent.AttachedEntity) then ent = ent.AttachedEntity end
    return ent
end
local function canEdit(ply, ent)
    return GRM and GRM.BuildTools and GRM.BuildTools.CanEdit and GRM.BuildTools.CanEdit(ply, ent)
end
local function apply(ent, col)
    ent:SetColor(col)
    ent:SetRenderMode(col.a < 255 and RENDERMODE_TRANSCOLOR or RENDERMODE_NORMAL)
    ent:SetKeyValue("renderfx", 0)
    if SERVER and duplicator and duplicator.StoreEntityModifier then
        duplicator.StoreEntityModifier(ent, "colour", { Color = col, RenderMode = ent:GetRenderMode(), RenderFX = 0 })
    end
end

function TOOL:LeftClick(trace)
    local ent = target(trace)
    if not IsValid(ent) then return false end
    if CLIENT then return true end
    if not canEdit(self:GetOwner(), ent) then return false end
    apply(ent, Color(math.Clamp(self:GetClientNumber("r", 255), 0, 255), math.Clamp(self:GetClientNumber("g", 255), 0, 255), math.Clamp(self:GetClientNumber("b", 255), 0, 255), math.Clamp(self:GetClientNumber("a", 255), 20, 255)))
    if ent._grmPerm and GRM.Perm and GRM.Perm.Update then GRM.Perm.Update(self:GetOwner(), ent) end
    return true
end

function TOOL:RightClick(trace)
    local ent = target(trace)
    if not IsValid(ent) then return false end
    if CLIENT then return true end
    if not canEdit(self:GetOwner(), ent) then return false end
    local c, ply = ent:GetColor(), self:GetOwner()
    ply:ConCommand("grm_colour_r " .. c.r) ply:ConCommand("grm_colour_g " .. c.g)
    ply:ConCommand("grm_colour_b " .. c.b) ply:ConCommand("grm_colour_a " .. c.a)
    return true
end

function TOOL:Reload(trace)
    local ent = target(trace)
    if not IsValid(ent) then return false end
    if CLIENT then return true end
    if not canEdit(self:GetOwner(), ent) then return false end
    apply(ent, Color(255, 255, 255, 255))
    if ent._grmPerm and GRM.Perm and GRM.Perm.Update then GRM.Perm.Update(self:GetOwner(), ent) end
    return true
end

function TOOL.BuildCPanel(panel)
    panel:Help("Штатный Colour отключён. Прозрачность ограничена минимумом 20.")
    panel:ColorPicker("Цвет", "grm_colour_r", "grm_colour_g", "grm_colour_b", "grm_colour_a")
end
