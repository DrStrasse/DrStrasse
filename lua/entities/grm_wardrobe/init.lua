AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local NET_USE     = "GRM_Wardrobe_Use"
local NET_CFG_REQ = "GRM_Wardrobe_CfgReq"
local NET_CFG_GET = "GRM_Wardrobe_CfgGet"
local NET_CFG_SET = "GRM_Wardrobe_CfgSet"
local NET_OPEN    = "GRM_Char_Open"

util.AddNetworkString(NET_USE)
util.AddNetworkString(NET_CFG_REQ)
util.AddNetworkString(NET_CFG_GET)
util.AddNetworkString(NET_CFG_SET)

local function dataFile()
    if not file.IsDir("grm_wardrobe", "DATA") then file.CreateDir("grm_wardrobe") end
    return "grm_wardrobe/" .. string.lower(game.GetMap() or "unknown") .. ".json"
end

local function jsonT(txt)
    local ok, t = pcall(util.JSONToTable, txt, false, true)
    return (ok and istable(t)) and t or nil
end

-- конфиги по позициям: { { pos={x,y,z}, cfg={...} }, ... }
local function loadAll()
    local t = jsonT(file.Read(dataFile(), "DATA") or "")
    return istable(t) and t or {}
end

local function saveAll(tbl, reason)
    local ok, txt = pcall(util.TableToJSON, tbl, true)
    if ok and txt then
        file.Write(dataFile(), txt)
        if not (file.Read(dataFile(), "DATA") or ""):find("%S") then
            ErrorNoHalt("[GRM Wardrobe] SAVE FAIL (" .. tostring(reason) .. ")\n")
        end
    end
end

local function defaultCfg()
    return {
        allowCivilian = true,
        allowFaction = true,
        allowSkin = true,
        allowBodygroups = true,
        extraModels = {},
        hiddenModels = {},
    }
end

local function cfgKey(pos)
    return string.format("%.0f_%.0f_%.0f", pos.x, pos.y, pos.z)
end

local function findCfgRec(ent)
    local all = loadAll()
    local key = cfgKey(ent:GetPos())
    for _, rec in ipairs(all) do
        if isstring(rec.key) and rec.key == key and istable(rec.cfg) then return rec, all end
    end
    return nil, all
end

function ENT:Initialize()
    self:SetModel(self.Model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end

    local rec = select(1, findCfgRec(self))
    self._cfg = rec and rec.cfg or defaultCfg()
    self._extra = rec and istable(rec.extra) and rec.extra or {}
    self._hidden = rec and istable(rec.hidden) and rec.hidden or {}
    self:SetCivilian(self._cfg.allowCivilian and 1 or 0)
    self:SetFaction(self._cfg.allowFaction and 1 or 0)
    self:SetSkin(self._cfg.allowSkin and 1 or 0)
    self:SetBodygroups(self._cfg.allowBodygroups and 1 or 0)
    self.cfg = { allowCivilian = self._cfg.allowCivilian, allowFaction = self._cfg.allowFaction,
                 allowSkin = self._cfg.allowSkin, allowBodygroups = self._cfg.allowBodygroups,
                 extraModels = self._extra, hiddenModels = self._hidden }
end

local function getCfg(ent)
    if not istable(ent.cfg) then
        ent.cfg = defaultCfg()
        ent.cfg.extraModels = {}
        ent.cfg.hiddenModels = {}
    end
    ent.cfg.extraModels = istable(ent.cfg.extraModels) and ent.cfg.extraModels or {}
    ent.cfg.hiddenModels = istable(ent.cfg.hiddenModels) and ent.cfg.hiddenModels or {}
    return ent.cfg
end

local function isCfgAdmin(ply)
    return IsValid(ply) and ply:IsSuperAdmin()
end

-- фильтрация секций по конфигу гардероба
local function filterSections(sections, cfg)
    local out = {}
    local hidden = {}
    for _, p in ipairs(cfg.hiddenModels) do hidden[tostring(p)] = true end

    for _, sec in ipairs(sections or {}) do
        local keep = istable(sec.outfits) and {} or nil
        for _, e in ipairs(sec.outfits or {}) do
            if not hidden[tostring(e.path)] then
                keep[#keep + 1] = e
            end
        end
        if keep and #keep > 0 then
            out[#out + 1] = { id = sec.id, title = sec.title, outfits = keep }
        end
    end

    -- особые модели этого шкафа
    local extra = {}
    for _, p in ipairs(cfg.extraModels) do
        if isstring(p) and p ~= "" and not hidden[p] then
            extra[#extra + 1] = { path = p, skin = 0, bodygroups = {} }
        end
    end
    if #extra > 0 then
        out[#out + 1] = { id = "wardrobe_extra", title = "Особые модели (гардероб)", outfits = extra }
    end
    return out
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end
    if activator:GetPos():DistToSqr(self:GetPos()) > 200 * 200 then return end
    if not (GRM and GRM.Char and GRM.Char.BuildPayload) then return end

    local cfg = getCfg(self)
    -- базовый payload ядра персонажей (учитывает allowCivilian/allowFaction как фильтр провайдеров)
    local payload = GRM.Char.BuildPayload(activator, {
        wardrobe = true, title = "Гардероб", ent = self,
        allowCivilian = cfg.allowCivilian, allowFaction = cfg.allowFaction,
        allowSkin = cfg.allowSkin, allowBodygroups = cfg.allowBodygroups,
    })
    payload.sections = filterSections(payload.sections, cfg)
    payload.wardrobeTitle = "Гардероб — выбор внешности"
    if #payload.sections == 0 then
        if GRM.Notify then GRM.Notify(activator, "Этот гардероб пуст для вас (или вы не в разрешённой фракции).", 255, 180, 60) end
        return
    end

    net.Start(NET_USE)
        net.WriteTable(payload)
    net.Send(activator)
end

-- запрос конфига (админ): EntIndex гардероба
net.Receive(NET_CFG_REQ, function(_, ply)
    if not isCfgAdmin(ply) then return end
    local idx = net.ReadUInt(16)
    local ent = Entity(idx)
    if not IsValid(ent) or ent:GetClass() ~= "grm_wardrobe" then return end
    local cfg = getCfg(ent)
    net.Start(NET_CFG_GET)
        net.WriteUInt(ent:EntIndex(), 16)
        net.WriteTable(cfg)
    net.Send(ply)
end)

-- сохранение конфига (админ)
net.Receive(NET_CFG_SET, function(_, ply)
    if not isCfgAdmin(ply) then return end
    local idx = net.ReadUInt(16)
    local ent = Entity(idx)
    if not IsValid(ent) or ent:GetClass() ~= "grm_wardrobe" then return end
    local cfg = net.ReadTable() or {}

    local clean = defaultCfg()
    clean.allowCivilian   = cfg.allowCivilian ~= false
    clean.allowFaction    = cfg.allowFaction ~= false
    clean.allowSkin       = cfg.allowSkin ~= false
    clean.allowBodygroups = cfg.allowBodygroups ~= false
    clean.extraModels = {}
    for _, p in ipairs(cfg.extraModels or {}) do
        if isstring(p) and p ~= "" then clean.extraModels[#clean.extraModels + 1] = string.Trim(p) end
    end
    clean.hiddenModels = {}
    for _, p in ipairs(cfg.hiddenModels or {}) do
        if isstring(p) and p ~= "" then clean.hiddenModels[#clean.hiddenModels + 1] = string.Trim(p) end
    end

    ent.cfg = clean
    ent:SetCivilian(clean.allowCivilian and 1 or 0)
    ent:SetFaction(clean.allowFaction and 1 or 0)
    ent:SetSkin(clean.allowSkin and 1 or 0)
    ent:SetBodygroups(clean.allowBodygroups and 1 or 0)

    local rec, all = findCfgRec(ent)
    local key = cfgKey(ent:GetPos())
    local newRec = { key = key, pos = { x = ent:GetPos().x, y = ent:GetPos().y, z = ent:GetPos().z }, cfg = clean }
    local replaced = false
    for i, r in ipairs(all) do
        if r.key == key then all[i] = newRec replaced = true break end
    end
    if not replaced then all[#all + 1] = newRec end
    saveAll(all, "cfg_set")

    ply:PrintMessage(HUD_PRINTTALK, "[Гардероб] Настройки сохранены.")
end)

-- общий API (удаление конфига при снятии шкафа админом)
GRM = GRM or {}
GRM.Wardrobe = GRM.Wardrobe or {}
function GRM.Wardrobe.DeleteCfg(ent)
    if not IsValid(ent) then return end
    local all = loadAll()
    local key = cfgKey(ent:GetPos())
    local out = {}
    local removed = false
    for _, r in ipairs(all) do
        if r.key ~= key then out[#out + 1] = r else removed = true end
    end
    if removed then saveAll(out, "delete_cfg") end
    return removed
end

print("[GRM Wardrobe] Энтити гардероба загружена (сервер)")
