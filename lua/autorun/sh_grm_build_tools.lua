--[[--------------------------------------------------------------------
    GRM Build Tools v1.0.0 (Код 61)
    Общий безопасный слой кастомных инструментов оформления:
      grm_camera, grm_light, grm_lamp, grm_material, grm_colour.

    Штатные camera/light/lamp/material/colour блокируются Q-меню; этот
    модуль даёт новым инструментам единый контроль владения и сохранение
    параметров света/камер через GRM.PermData.
----------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.BuildTools = GRM.BuildTools or {}
local B = GRM.BuildTools
B.Version = "1.0.0"

B.DisabledStockTools = {
    camera = true,
    light = true,
    lamp = true,
    material = true,
    colour = true,
    color = true,
}

B.Materials = {
    [""] = true,
    ["models/debug/debugwhite"] = true,
    ["models/wireframe"] = true,
    ["models/shiny"] = true,
    ["models/flesh"] = true,
    ["models/props_c17/furniturefabric003a"] = true,
    ["models/props_c17/furnituremetal001a"] = true,
    ["models/props_c17/frostedglass_01a"] = true,
    ["models/props_lab/tank_glass001"] = true,
    ["models/props_pipes/guttermetal01a"] = true,
    ["models/props_pipes/pipesystem01a_skin3"] = true,
    ["models/props_wasteland/wood_fence01a"] = true,
    ["brick/brick_model"] = true,
    ["phoenix_storms/metalset_1-2"] = true,
    ["phoenix_storms/metalfloor_2-3"] = true,
    ["phoenix_storms/plastic"] = true,
    ["phoenix_storms/wood"] = true,
    ["phoenix_storms/bluemetal"] = true,
    ["phoenix_storms/wire/pcb_green"] = true,
    ["phoenix_storms/wire/pcb_red"] = true,
    ["phoenix_storms/wire/pcb_blue"] = true,
    ["hunter/myplastic"] = true,
}

B.LampTextures = {
    ["effects/flashlight001"] = true,
    ["effects/flashlight/slit"] = true,
    ["effects/flashlight/circles"] = true,
    ["effects/flashlight/window"] = true,
    ["effects/flashlight/logo"] = true,
}

local function characterKey(ply)
    if not IsValid(ply) then return "" end
    if GRM.Identity and isfunction(GRM.Identity.CharacterKey) then
        local ok, key = pcall(GRM.Identity.CharacterKey, ply)
        if ok and isstring(key) then return key end
    end
    return tostring(ply.SteamID64 and ply:SteamID64() or "") .. ":char1"
end
B.CharacterKey = characterKey

function B.CanEdit(ply, ent)
    if not (IsValid(ply) and ply:IsPlayer() and IsValid(ent)) then return false end
    if ent:IsWorld() or ent:IsPlayer() or ent:IsNPC() then return false end
    if ply:IsSuperAdmin() then return true end
    if GRM.PropProtect and isfunction(GRM.PropProtect.CanInteract) then
        return GRM.PropProtect.CanInteract(ply, ent, "tool") == true
    end
    local key = characterKey(ply)
    local owner = ent.GRM_PropOwnerCharacterKey or ent.GRM_EntityOwnerCharacterKey
        or (ent.GetNWString and (ent:GetNWString("GRM_PropOwnerCharacterKey", "") ~= ""
            and ent:GetNWString("GRM_PropOwnerCharacterKey", "")
            or ent:GetNWString("GRM_EntityOwnerCharacterKey", "")))
    return owner ~= nil and tostring(owner) == key
end

function B.MarkOwned(ply, ent)
    if not (SERVER and IsValid(ply) and IsValid(ent)) then return end
    local key = characterKey(ply)
    local name = ply.GetNWString and ply:GetNWString("GRM_RPName", "") or ""
    if name == "" then name = ply:Nick() end
    ent.GRM_EntityOwnerCharacterKey = key
    ent.GRM_EntityOwnerAccountKey = tostring(ply:SteamID64() or "")
    ent.GRM_EntityOwnerName = name
    pcall(function()
        ent:SetNWString("GRM_EntityOwnerCharacterKey", key)
        ent:SetNWString("GRM_EntityOwnerName", name)
    end)
    hook.Run("PlayerSpawnedSENT", ply, ent)
end

function B.Notify(ply, text, good)
    if not IsValid(ply) then return end
    if GRM.Notify then
        if good == false then GRM.Notify(ply, text, 255, 110, 100)
        else GRM.Notify(ply, text, 100, 220, 140) end
    else
        ply:ChatPrint("[Стройка] " .. tostring(text))
    end
end

-- Данные экземпляров для перм-системы. У каждого инструмента свой ключ,
-- поэтому цепочки PermData не затирают делегаты других модулей.
GRM.PermData = GRM.PermData or { Extract = {}, Apply = {} }
GRM.PermData.Extract = GRM.PermData.Extract or {}
GRM.PermData.Apply = GRM.PermData.Apply or {}

GRM.PermData.Extract["gmod_light"] = function(ent)
    local c = ent:GetColor()
    return { grmLight = {
        r = c.r, g = c.g, b = c.b,
        brightness = tonumber(ent.Brightness) or (ent.GetBrightness and ent:GetBrightness()) or 2,
        size = tonumber(ent.Size) or (ent.GetLightSize and ent:GetLightSize()) or 256,
        toggle = ent.GetToggle and ent:GetToggle() == true or false,
        on = ent.GetOn and ent:GetOn() == true or ent.on == true,
        key = tonumber(ent.KeyDown) or 37,
    } }
end
GRM.PermData.Apply["gmod_light"] = function(ent, data)
    local d = istable(data) and data.grmLight or nil
    if not istable(d) then return end
    local r, g, b = math.Clamp(tonumber(d.r) or 255, 0, 255), math.Clamp(tonumber(d.g) or 255, 0, 255), math.Clamp(tonumber(d.b) or 255, 0, 255)
    ent:SetColor(Color(r, g, b, 255))
    if ent.SetBrightness then ent:SetBrightness(math.Clamp(tonumber(d.brightness) or 2, -6, 8)) end
    if ent.SetLightSize then ent:SetLightSize(math.Clamp(tonumber(d.size) or 256, 32, 1024)) end
    if ent.SetToggle then ent:SetToggle(d.toggle == true) end
    if ent.SetOn then ent:SetOn(d.on ~= false) end
    ent.Brightness, ent.Size, ent.KeyDown, ent.on = tonumber(d.brightness) or 2, tonumber(d.size) or 256, tonumber(d.key) or 37, d.on ~= false
end

GRM.PermData.Extract["gmod_lamp"] = function(ent)
    local c = ent:GetColor()
    return { grmLamp = {
        r = c.r, g = c.g, b = c.b,
        brightness = tonumber(ent.brightness) or (ent.GetBrightness and ent:GetBrightness()) or 4,
        fov = tonumber(ent.fov) or (ent.GetLightFOV and ent:GetLightFOV()) or 90,
        distance = tonumber(ent.distance) or (ent.GetDistance and ent:GetDistance()) or 1024,
        texture = tostring(ent.Texture or (ent.GetFlashlightTexture and ent:GetFlashlightTexture()) or "effects/flashlight001"),
        toggle = ent.GetToggle and ent:GetToggle() == true or false,
        on = ent.GetOn and ent:GetOn() == true or true,
        key = tonumber(ent.KeyDown) or 37,
    } }
end
GRM.PermData.Apply["gmod_lamp"] = function(ent, data)
    local d = istable(data) and data.grmLamp or nil
    if not istable(d) then return end
    local tex = string.lower(tostring(d.texture or "effects/flashlight001"))
    if not B.LampTextures[tex] then tex = "effects/flashlight001" end
    ent:SetColor(Color(math.Clamp(tonumber(d.r) or 255, 0, 255), math.Clamp(tonumber(d.g) or 255, 0, 255), math.Clamp(tonumber(d.b) or 255, 0, 255), 255))
    if ent.SetFlashlightTexture then ent:SetFlashlightTexture(tex) end
    if ent.SetLightFOV then ent:SetLightFOV(math.Clamp(tonumber(d.fov) or 90, 10, 170)) end
    if ent.SetDistance then ent:SetDistance(math.Clamp(tonumber(d.distance) or 1024, 64, 2048)) end
    if ent.SetBrightness then ent:SetBrightness(math.Clamp(tonumber(d.brightness) or 4, 0, 8)) end
    if ent.SetToggle then ent:SetToggle(d.toggle == true) end
    if ent.Switch then ent:Switch(d.on ~= false) end
    if ent.UpdateLight then ent:UpdateLight() end
    ent.Texture, ent.fov, ent.distance, ent.brightness, ent.KeyDown = tex, tonumber(d.fov) or 90, tonumber(d.distance) or 1024, tonumber(d.brightness) or 4, tonumber(d.key) or 37
end

GRM.PermData.Extract["gmod_cameraprop"] = function(ent)
    return { grmCamera = {
        key = tonumber(ent.controlkey) or 37,
        locked = ent.locked == true or ent.locked == 1,
        toggle = ent.toggle == true or ent.toggle == 1,
    } }
end
GRM.PermData.Apply["gmod_cameraprop"] = function(ent, data)
    local d = istable(data) and data.grmCamera or nil
    if not istable(d) then return end
    local key = math.Clamp(math.floor(tonumber(d.key) or 37), 1, 159)
    if ent.SetKey then ent:SetKey(key) end
    if ent.SetLocked then ent:SetLocked(d.locked == true) end
    if ent.SetTracking then ent:SetTracking(NULL, Vector(0, 0, 0)) end
    ent.controlkey, ent.locked, ent.toggle = key, d.locked == true, d.toggle == true
end

local function registerPermClasses()
    if not (GRM.Perm and isfunction(GRM.Perm.RegisterClass)) then return false end
    GRM.Perm.RegisterClass("gmod_light", true)
    GRM.Perm.RegisterClass("gmod_lamp", true)
    GRM.Perm.RegisterClass("gmod_cameraprop", true)
    return true
end
if SERVER then
    hook.Add("InitPostEntity", "GRM_BuildTools_PermClasses", registerPermClasses)
    timer.Simple(1, registerPermClasses)
end

print("[GRM BuildTools] v" .. B.Version .. " loaded")
