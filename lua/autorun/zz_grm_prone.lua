--[[ Мост GRM ↔ Prone Mod (SYSTEM PRONE). Сам мод не копируем:
     анимации и модели живут в отдельном аддоне dist/system_prone.zip.
     Здесь только лимбо/стамина и алиасы. ]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Prone = GRM.Prone or {}

function GRM.Prone.ModLoaded()
    return istable(prone) and isfunction(prone.Handle)
end

function GRM.Prone.Is(ply)
    if not IsValid(ply) then return false end
    if ply.IsProne and ply:IsProne() then return true end
    return ply:GetNWBool("GRM_Prone", false)
end

hook.Add("Think", "GRM_Prone_Mirror", function()
    if CLIENT then return end
    if GRM.Perf and not GRM.Perf.Throttle("prone.mirror", 0.2) then return end
    for _, ply in ipairs((GRM.Perf and GRM.Perf.Players and GRM.Perf.Players()) or player.GetAll()) do
        if IsValid(ply) then
            local on = ply.IsProne and ply:IsProne() or false
            if ply:GetNWBool("GRM_Prone", false) ~= on then
                ply:SetNWBool("GRM_Prone", on)
            end
        end
    end
end)

hook.Add("prone.CanEnter", "GRM_Prone_Gates", function(ply)
    if not IsValid(ply) then return false end
    if ply:GetNWBool("GRM_CharacterPending", false) then return false end
    if ply.GRMCharLimbo then return false end
    if ply:GetNWBool("GRM_Arrested", false) then return false end
    if ply:InVehicle() then return false end
end)

if SERVER then
    hook.Add("PlayerSay", "GRM_Prone_Cmd", function(ply, text)
        local t = string.lower(string.Trim(text or ""))
        if t ~= "/prone" and t ~= "!prone" and t ~= "/лечь" then return end
        if GRM.Prone.ModLoaded() then
            if CLIENT then return "" end
            -- сервер: клиентский concommand prone шлёт impulse; зовём Handle
            if isfunction(prone.Handle) then prone.Handle(ply) end
            return ""
        end
        if GRM.Notify then GRM.Notify(ply, "Аддон лежания не установлен (system_prone).", 255, 180, 80) end
        return ""
    end)
end

if CLIENT then
    concommand.Add("grm_prone", function()
        if GRM.Prone.ModLoaded() and isfunction(prone.Request) then
            prone.Request()
        else
            RunConsoleCommand("prone")
        end
    end)
end
