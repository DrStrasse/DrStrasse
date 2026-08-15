-- GRM Material Tool v1.0.0 — безопасная замена штатного material
TOOL.Category = "GRM"
TOOL.Name = "GRM Материал"
TOOL.Command = nil
TOOL.ConfigName = ""
TOOL.ClientConVar = { override = "models/debug/debugwhite" }
TOOL.Information = { { name = "left" }, { name = "right" }, { name = "reload" } }

if CLIENT then
    language.Add("tool.grm_material.name", "GRM Материал")
    language.Add("tool.grm_material.desc", "Безопасная смена материала только своих объектов")
    language.Add("tool.grm_material.left", "Применить материал")
    language.Add("tool.grm_material.right", "Скопировать разрешённый материал")
    language.Add("tool.grm_material.reload", "Сбросить материал")
end

local function target(trace)
    local ent = trace and trace.Entity
    if IsValid(ent) and IsValid(ent.AttachedEntity) then ent = ent.AttachedEntity end
    return ent
end
local function canEdit(ply, ent)
    return GRM and GRM.BuildTools and GRM.BuildTools.CanEdit and GRM.BuildTools.CanEdit(ply, ent)
end
local function allowed(mat)
    mat = string.lower(string.Trim(tostring(mat or "")))
    if #mat > 96 or string.find(mat, "%.%.", 1, true) then return nil end
    return GRM and GRM.BuildTools and GRM.BuildTools.Materials and GRM.BuildTools.Materials[mat] and mat or nil
end
local function apply(ent, mat)
    ent:SetMaterial(mat)
    if SERVER and duplicator and duplicator.StoreEntityModifier then
        duplicator.StoreEntityModifier(ent, "material", { MaterialOverride = mat })
    end
end

function TOOL:LeftClick(trace)
    local ent = target(trace)
    if not IsValid(ent) then return false end
    if CLIENT then return true end
    if not canEdit(self:GetOwner(), ent) then return false end
    local mat = allowed(self:GetClientInfo("override"))
    if mat == nil then
        if GRM.BuildTools.Notify then GRM.BuildTools.Notify(self:GetOwner(), "Материал отсутствует в разрешённом наборе.", false) end
        return false
    end
    apply(ent, mat)
    if ent._grmPerm and GRM.Perm and GRM.Perm.Update then GRM.Perm.Update(self:GetOwner(), ent) end
    return true
end

function TOOL:RightClick(trace)
    local ent = target(trace)
    if not IsValid(ent) then return false end
    if CLIENT then return true end
    if not canEdit(self:GetOwner(), ent) then return false end
    local mat = allowed(ent:GetMaterial()) or ""
    self:GetOwner():ConCommand("grm_material_override \"" .. mat .. "\"")
    return true
end

function TOOL:Reload(trace)
    local ent = target(trace)
    if not IsValid(ent) then return false end
    if CLIENT then return true end
    if not canEdit(self:GetOwner(), ent) then return false end
    apply(ent, "")
    if ent._grmPerm and GRM.Perm and GRM.Perm.Update then GRM.Perm.Update(self:GetOwner(), ent) end
    return true
end

function TOOL.BuildCPanel(panel)
    panel:Help("Штатный Material отключён. Доступен ограниченный проверенный набор материалов.")
    local box = panel:ComboBox("Материал", "grm_material_override")
    local rows = {}
    if GRM and GRM.BuildTools then for mat in pairs(GRM.BuildTools.Materials or {}) do rows[#rows + 1] = mat end end
    table.sort(rows)
    for _, mat in ipairs(rows) do box:AddChoice(mat == "" and "Обычный материал" or mat, mat) end
end
