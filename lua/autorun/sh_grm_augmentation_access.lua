-- Доступ к оборудованию аугментации: фракция / отдел / роль / действие.
if SERVER then AddCSLuaFile() end
GRM = GRM or {}
GRM.AugmentationAccess = GRM.AugmentationAccess or {}
local A=GRM.AugmentationAccess
A.Config=A.Config or {allowAll=true, actions={create=true,implant=true,reprogram=true,extract=true}, factions={}, departments={}, roles={}}
function A.SetConfig(cfg) A.Config=table.Merge(A.Config,cfg or {}) end
local function value(ply,key)
    if not IsValid(ply) then return "" end
    return ply:GetNWString(key, "")
end
function A.Can(ply, action, ent)
    if not IsValid(ply) then return false,"Недействительный игрок" end
    if ply:IsSuperAdmin() then return true end
    local c=A.Config
    if c.allowAll and c.actions[action] ~= false then return true end
    if c.actions[action] == false then return false,"Действие отключено администрацией" end
    local faction=value(ply,"GRM_Faction"); local department=value(ply,"GRM_Department"); local role=value(ply,"GRM_Role")
    if c.factions[action] and c.factions[action][faction] then return true end
    if c.departments[action] and c.departments[action][department] then return true end
    if c.roles[action] and c.roles[action][role] then return true end
    local result=hook.Run("GRM_AugmentationCan",ply,action,ent,faction,department,role)
    if result==true then return true end
    return false,"Нет доступа к оборудованию аугментации"
end
function A.Deny(ply,msg) if IsValid(ply) then if GRM.Notify then GRM.Notify(ply,msg or "Нет доступа",255,100,80) else ply:ChatPrint("[Аугментации] "..(msg or "Нет доступа")) end end end
-- API для админских/фракционных модулей.
function GRM.AugmentationCan(ply,action,ent) return A.Can(ply,action,ent) end
print("[GRM AugmentationAccess] загружен")
