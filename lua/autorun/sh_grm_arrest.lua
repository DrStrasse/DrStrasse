--[[
    GRM Arrest System v1.0.0
    Камеры ареста, группы заключённых, точки камер, /arrest и /unarrest.
]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Arrest = GRM.Arrest or {}
local A = GRM.Arrest
A.Version = "1.0.0"
A.File = "grm_arrest.json"
A.Cfg = A.Cfg or {
    model = "models/player/Group03/male_07.mdl",
    groups = {
        criminals = { name = "Уголовники", model = "models/player/Group03/male_07.mdl" },
        political = { name = "Политические", model = "models/player/Group03/male_04.mdl" },
        guardhouse = { name = "Гауптвахта", model = "models/player/Group01/male_07.mdl" },
    },
    cameras = {},
    spawns = {},
}

local function key(ply)
    if IsValid(ply) and ply:IsPlayer() then
        if GRM.Identity and GRM.Identity.CharacterKey then return GRM.Identity.CharacterKey(ply) end
        return tostring(ply:SteamID64() or ply:SteamID() or "") .. ":char1"
    end
    return tostring(ply or "")
end

local function save()
    if SERVER then file.Write(A.File, util.TableToJSON(A.Cfg, true)) end
end

local function load()
    if not SERVER or not file.Exists(A.File, "DATA") then return end
    local ok, t = pcall(util.JSONToTable, file.Read(A.File, "DATA") or "", false, true)
    if ok and istable(t) then
        for k, v in pairs(t) do A.Cfg[k] = v end
    end
    A.Cfg.groups = istable(A.Cfg.groups) and A.Cfg.groups or {}
    A.Cfg.cameras = istable(A.Cfg.cameras) and A.Cfg.cameras or {}
    A.Cfg.spawns = istable(A.Cfg.spawns) and A.Cfg.spawns or {}
end

local function group(id)
    return A.Cfg.groups[tostring(id or "")] or A.Cfg.groups.criminals
end

if SERVER then
    util.AddNetworkString("GRM_Arrest_Admin")
    util.AddNetworkString("GRM_Arrest_AdminData")
    util.AddNetworkString("GRM_Arrest_AdminAction")

    load()

    local function vec(t) return Vector(tonumber(t.x) or 0, tonumber(t.y) or 0, tonumber(t.z) or 0) end
    local function ang(t) return Angle(tonumber(t.p) or 0, tonumber(t.y) or 0, tonumber(t.r) or 0) end
    local function vdata(v) return { x = v.x, y = v.y, z = v.z } end
    local function adata(a) return { p = a.p, y = a.y, r = a.r } end

    local function spawnCamera(rec)
        local ent = ents.Create("grm_arrest_camera")
        if not IsValid(ent) then return nil end
        ent:SetPos(vec(rec.pos)) ent:SetAngles(ang(rec.ang))
        ent:Spawn() ent:Activate()
        ent:SetCameraID(rec.id or "")
        ent:SetCameraName(rec.name or rec.id or "Камера")
        ent:SetArrestGroup(rec.group or "criminals")
        ent.GRMArrestID = rec.id
        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then phys:EnableMotion(false) end
        return ent
    end

    local function loadCameras()
        for _, ent in ipairs(ents.FindByClass("grm_arrest_camera")) do ent:Remove() end
        for _, rec in ipairs(A.Cfg.cameras or {}) do if istable(rec) then spawnCamera(rec) end end
    end

    function A.OpenAdmin(ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        net.Start("GRM_Arrest_AdminData")
            net.WriteTable(A.Cfg)
        net.Send(ply)
    end

    local function nearestPlayer(ply)
        local tr = ply:GetEyeTrace()
        local target = tr and tr.Entity
        if IsValid(target) and target:IsPlayer() and target ~= ply and ply:GetPos():DistToSqr(target:GetPos()) <= 220 * 220 then return target end
        return nil
    end

    local function chooseCamera(groupID)
        for _, rec in ipairs(A.Cfg.cameras or {}) do
            if tostring(rec.group or "criminals") == tostring(groupID) then return rec end
        end
        return A.Cfg.cameras[1]
    end

    local function chooseSpawn(camera)
        if camera and camera.spawnID then
            for _, rec in ipairs(A.Cfg.spawns or {}) do if rec.id == camera.spawnID then return rec end end
        end
        return A.Cfg.spawns[1]
    end

    function A.ArrestPlayer(actor, target, groupID)
        if not IsValid(actor) or not IsValid(target) then return false, "Цель не найдена" end
        local HC = GRM.Handcuffs
        if not (HC and HC.IsCuffed and HC.IsCuffed(target)) then return false, "Сначала наденьте на человека наручники" end
        if target:GetNWBool("GRM_Arrested", false) then return false, "Человек уже арестован" end
        local cam = chooseCamera(groupID)
        if not cam then return false, "Для этой группы не настроена камера ареста" end
        local sp = chooseSpawn(cam)
        if not sp then return false, "Для камеры не назначена точка арестованного" end
        local g = group(groupID)
        target.GRM_ArrestOriginalModel = target:GetModel()
        target.GRM_ArrestOriginalSkin = target:GetSkin()
        target.GRM_ArrestOriginalBodygroups = {}
        for i = 0, (target:GetNumBodyGroups() or 0) - 1 do target.GRM_ArrestOriginalBodygroups[i] = target:GetBodygroup(i) end
        target:SetNWBool("GRM_Arrested", true)
        target:SetNWString("GRM_ArrestGroup", groupID or "criminals")
        target:SetNWString("GRM_ArrestGroupName", g.name or groupID or "Арестованный")
        if isstring(g.model) and g.model:match("^models/.+%.mdl$") then target:SetModel(g.model) end
        target:SetSkin(math.max(0, math.floor(tonumber(g.skin) or 0)))
        for group, value in pairs(g.bodygroups or {}) do target:SetBodygroup(tonumber(group) or 0, tonumber(value) or 0) end
        target:SetPos(vec(sp.pos))
        target:SetEyeAngles(ang(sp.ang or { p = 0, y = 0, r = 0 }))
        target:Freeze(false)
        if GRM.Notify then GRM.Notify(target, "Вы арестованы: " .. tostring(g.name), 255, 150, 100) end
        actor:ChatPrint("[Арест] Арестованный отправлен в: " .. tostring(g.name))
        return true
    end

    function A.UnarrestPlayer(actor, target)
        if not IsValid(target) or not target:GetNWBool("GRM_Arrested", false) then return false end
        target:SetNWBool("GRM_Arrested", false)
        target:SetNWString("GRM_ArrestGroup", "")
        target:SetNWString("GRM_ArrestGroupName", "")
        if target.GRM_ArrestOriginalModel and util.IsValidModel(target.GRM_ArrestOriginalModel) then target:SetModel(target.GRM_ArrestOriginalModel) end
        target:SetSkin(tonumber(target.GRM_ArrestOriginalSkin) or 0)
        for group, value in pairs(target.GRM_ArrestOriginalBodygroups or {}) do target:SetBodygroup(tonumber(group) or 0, tonumber(value) or 0) end
        target.GRM_ArrestOriginalModel = nil
        target.GRM_ArrestOriginalSkin = nil
        target.GRM_ArrestOriginalBodygroups = nil
        if GRM.Notify then GRM.Notify(target, "Вы освобождены.", 120, 220, 140) end
        return true
    end

    hook.Add("CanPlayerSuicide", "GRM_Arrest_BlockSuicide", function(ply)
        if IsValid(ply) and ply:GetNWBool("GRM_Arrested", false) then
            if GRM.Notify then GRM.Notify(ply, "Самоубийство во время ареста запрещено.", 255, 100, 100) end
            return false
        end
        -- Запрещаем консольный kill для всех игроков RP-сервера.
        if IsValid(ply) and not ply:IsSuperAdmin() then
            if GRM.Notify then GRM.Notify(ply, "Команда kill запрещена.", 255, 100, 100) end
            return false
        end
    end)

    hook.Add("PlayerSay", "GRM_Arrest_Commands", function(ply, text)
        local msg = string.Trim(text or "")
        local low = string.lower(msg)
        if low == "/arrest" or low:sub(1, 8) == "/arrest " then
            local gid = string.Trim(msg:sub(8))
            if gid == "" then gid = "criminals" end
            local target = nearestPlayer(ply)
            local ok, err = A.ArrestPlayer(ply, target, gid)
            if not ok then ply:ChatPrint("[Арест] " .. tostring(err)) end
            return ""
        end
        if low == "/unarrest" then
            local target = nearestPlayer(ply)
            if not A.UnarrestPlayer(ply, target) then ply:ChatPrint("[Арест] Цель не арестована.") end
            return ""
        end
    end)

    net.Receive("GRM_Arrest_Admin", function(_, ply) A.OpenAdmin(ply) end)
    net.Receive("GRM_Arrest_AdminAction", function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        local action = net.ReadString()
        local id = string.Trim(net.ReadString() or "")
        if action == "add_camera" then
            local tr = ply:GetEyeTrace()
            local rec = { id = id ~= "" and id or ("cam_" .. os.time()), name = id ~= "" and id or "Камера", group = "criminals", pos = vdata(tr.HitPos), ang = adata(Angle(0, ply:EyeAngles().y, 0)), spawnID = "" }
            A.Cfg.cameras[#A.Cfg.cameras + 1] = rec
            spawnCamera(rec) save()
        elseif action == "add_spawn" then
            local rec = { id = id ~= "" and id or ("spawn_" .. os.time()), name = id ~= "" and id or "Точка ареста", pos = vdata(ply:GetPos()), ang = adata(ply:EyeAngles()) }
            A.Cfg.spawns[#A.Cfg.spawns + 1] = rec save()
        elseif action == "set_group" then
            local name = string.Trim(net.ReadString() or "")
            local model = string.Trim(net.ReadString() or "")
            if id:match("^[%w_%-]+$") and name ~= "" then
                A.Cfg.groups[id] = A.Cfg.groups[id] or {}
                A.Cfg.groups[id].name = name
                if model ~= "" and util.IsValidModel(model) then A.Cfg.groups[id].model = model end
                save()
            end
        elseif action == "set_group_model" then
            local model = string.Trim(net.ReadString() or "")
            if A.Cfg.groups[id] and model:match("^models/.+%.mdl$") then
                A.Cfg.groups[id].model = model
                save()
            end
        elseif action == "set_group_data" then
            local data = net.ReadTable() or {}
            local model = string.Trim(tostring(data.model or ""))
            if A.Cfg.groups[id] and model:match("^models/.+%.mdl$") then
                A.Cfg.groups[id].model = model
                A.Cfg.groups[id].skin = math.max(0, math.floor(tonumber(data.skin) or 0))
                A.Cfg.groups[id].bodygroups = {}
                for group, value in pairs(data.bodygroups or {}) do
                    local gi, vi = tonumber(group), tonumber(value)
                    if gi and vi then A.Cfg.groups[id].bodygroups[gi] = vi end
                end
                save()
            end
        elseif action == "set_camera_group" then
            local groupID = string.Trim(net.ReadString() or "")
            if A.Cfg.groups[groupID] then
                for _, cam in ipairs(A.Cfg.cameras) do if cam.id == id then cam.group = groupID end end
                save()
            end
        elseif action == "assign_camera_spawn" then
            local spawnID = string.Trim(net.ReadString() or "")
            for _, cam in ipairs(A.Cfg.cameras) do if cam.id == id then cam.spawnID = spawnID end end
            save()
        elseif action == "reload" then
            loadCameras()
        end
        A.OpenAdmin(ply)
    end)

    concommand.Add("grm_arrest_admin", function(ply) A.OpenAdmin(ply) end)
    concommand.Add("grm_arrest_reload", function(ply) if not IsValid(ply) or ply:IsSuperAdmin() then loadCameras() end end)
    hook.Add("InitPostEntity", "GRM_Arrest_LoadCameras", function() timer.Simple(2, loadCameras) end)
    hook.Add("ShutDown", "GRM_Arrest_Save", save)
end

if CLIENT then
    surface.CreateFont("GRMArrestTitle", { font = "Roboto", size = 20, weight = 800, extended = true })
    net.Receive("GRM_Arrest_AdminData", function()
        local data = net.ReadTable() or {}
        local f = vgui.Create("DFrame") f:SetSize(860, 640) f:Center() f:MakePopup() f:SetTitle("GRM — Арестованные и камеры")
        local scroll = vgui.Create("DScrollPanel", f) scroll:Dock(FILL) scroll:DockMargin(8, 8, 8, 48)
        local function button(text, y, action, id, extra)
            local b = vgui.Create("DButton", scroll) b:Dock(TOP) b:SetTall(30) b:DockMargin(0, 2, 0, 2) b:SetText(text)
            b.DoClick = function()
                local actionID = id or ""
                if actionID == "" and IsValid(idEntry) then actionID = idEntry:GetValue() end
                net.Start("GRM_Arrest_AdminAction")
                    net.WriteString(action)
                    net.WriteString(actionID)
                    if extra then extra() end
                net.SendToServer()
            end
        end
        local help = vgui.Create("DLabel", scroll) help:Dock(TOP) help:SetTall(54) help:SetWrap(true)
        help:SetText("Камера ставится в точку прицела. Точка арестованного — в месте, где вы стоите. Затем свяжите камеру с точкой и назначьте группе модель.")
        local idEntry = vgui.Create("DTextEntry", scroll) idEntry:Dock(TOP) idEntry:SetTall(28) idEntry:SetPlaceholderText("ID камеры/точки или group id")
        button("Добавить камеру в прицеле", 0, "add_camera", "", function() end)
        button("Добавить точку арестованного здесь", 0, "add_spawn", "", function() end)
        local groupName = vgui.Create("DTextEntry", scroll) groupName:Dock(TOP) groupName:SetTall(26) groupName:SetPlaceholderText("Название новой группы")
        local groupModel = vgui.Create("DTextEntry", scroll) groupModel:Dock(TOP) groupModel:SetTall(26) groupModel:SetPlaceholderText("Модель группы: models/...mdl")
        local groupID = vgui.Create("DTextEntry", scroll) groupID:Dock(TOP) groupID:SetTall(26) groupID:SetPlaceholderText("ID группы: criminals/political/guardhouse")
        local groupAdd = vgui.Create("DButton", scroll) groupAdd:Dock(TOP) groupAdd:SetTall(28) groupAdd:SetText("Создать/сохранить группу")
        groupAdd.DoClick = function()
            net.Start("GRM_Arrest_AdminAction")
                net.WriteString("set_group") net.WriteString(groupID:GetValue())
                net.WriteString(groupName:GetValue()) net.WriteString(groupModel:GetValue())
            net.SendToServer()
        end
        local function openGroupEditor(gid, source)
            local ed = table.Copy(source or {})
            ed.bodygroups = istable(ed.bodygroups) and ed.bodygroups or {}
            local w = vgui.Create("DFrame") w:SetSize(760, 620) w:Center() w:MakePopup()
            w:SetTitle("Настройка группы арестованных: " .. tostring(ed.name or gid))
            local model = vgui.Create("DTextEntry", w) model:SetPos(12, 38) model:SetSize(520, 28) model:SetText(ed.model or "")
            local preview = vgui.Create("DModelPanel", w) preview:SetPos(550, 38) preview:SetSize(190, 300) preview:SetFOV(42) preview.LayoutEntity = function() end
            local scrollBG = vgui.Create("DScrollPanel", w) scrollBG:SetPos(12, 78) scrollBG:SetSize(520, 300)
            local load = vgui.Create("DButton", w) load:SetPos(12, 388) load:SetSize(160, 28) load:SetText("Считать модель")
            local skin = vgui.Create("DNumSlider", w) skin:SetPos(180, 388) skin:SetSize(350, 28) skin:SetMin(0) skin:SetMax(16) skin:SetDecimals(0) skin:SetValue(ed.skin or 0)
            local function rebuild()
                scrollBG:Clear()
                local ent = IsValid(preview:GetEntity()) and preview:GetEntity() or nil
                if not IsValid(ent) then return end
                for i = 0, (ent:GetNumBodyGroups() or 0) - 1 do
                    local count = ent:GetBodygroupCount(i) or 1
                    if count > 1 then
                        local combo = vgui.Create("DComboBox", scrollBG) combo:Dock(TOP) combo:SetTall(28) combo:SetValue(ent:GetBodygroupName(i) or ("Группа " .. i))
                        for value = 0, count - 1 do combo:AddChoice((ent:GetBodygroupName(i) or ("Группа " .. i)) .. " — вариант " .. value, value) end
                        combo.OnSelect = function(_, _, value) ed.bodygroups[i] = tonumber(value) or 0 end
                        if ed.bodygroups[i] then combo:SetValue((ent:GetBodygroupName(i) or ("Группа " .. i)) .. " — вариант " .. tostring(ed.bodygroups[i])) end
                    end
                end
            end
            load.DoClick = function()
                if util.IsValidModel(model:GetValue()) then preview:SetModel(model:GetValue()) rebuild() end
            end
            if util.IsValidModel(model:GetValue()) then preview:SetModel(model:GetValue()) rebuild() end
            local save = vgui.Create("DButton", w) save:SetPos(550, 570) save:SetSize(190, 32) save:SetText("Сохранить группу")
            save.DoClick = function()
                net.Start("GRM_Arrest_AdminAction") net.WriteString("set_group_data") net.WriteString(gid)
                    net.WriteTable({ model = model:GetValue(), skin = skin:GetValue(), bodygroups = ed.bodygroups })
                net.SendToServer() w:Close()
            end
        end

        for gid, g in pairs(data.groups or {}) do
            local label = vgui.Create("DLabel", scroll) label:Dock(TOP) label:SetTall(28) label:SetText("Группа: " .. tostring(g.name) .. " [" .. gid .. "] — " .. tostring(g.model or ""))
            local model = vgui.Create("DTextEntry", scroll) model:Dock(TOP) model:SetTall(26) model:SetText(g.model or "") model:SetPlaceholderText("models/...mdl")
            local b = vgui.Create("DButton", scroll) b:Dock(TOP) b:SetTall(28) b:SetText("Настроить модель, skin и bodygroups: " .. gid)
            b.DoClick = function() openGroupEditor(gid, g) end
        end
        for _, cam in ipairs(data.cameras or {}) do
            local label = vgui.Create("DLabel", scroll) label:Dock(TOP) label:SetTall(24) label:SetText("Камера " .. tostring(cam.id) .. " → точка: " .. tostring(cam.spawnID or "не назначена"))
            local groupCombo = vgui.Create("DComboBox", scroll) groupCombo:Dock(TOP) groupCombo:SetTall(26) groupCombo:SetValue("Группа: " .. tostring(cam.group or "criminals"))
            for gid, g in pairs(data.groups or {}) do groupCombo:AddChoice(tostring(g.name or gid) .. " [" .. gid .. "]", gid) end
            local groupSet = vgui.Create("DButton", scroll) groupSet:Dock(TOP) groupSet:SetTall(26) groupSet:SetText("Назначить группу камере")
            groupSet.DoClick = function()
                local gid = groupCombo:GetOptionData(groupCombo:GetSelectedID()) or cam.group or "criminals"
                net.Start("GRM_Arrest_AdminAction") net.WriteString("set_camera_group") net.WriteString(cam.id) net.WriteString(gid) net.SendToServer()
            end
            for _, sp in ipairs(data.spawns or {}) do button("Привязать " .. cam.id .. " к " .. sp.id, 0, "assign_camera_spawn", cam.id, function() net.WriteString(sp.id) end) end
        end
    end)

    hook.Add("HUDPaint", "GRM_Arrest_Label", function()
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        for _, p in ipairs(player.GetAll()) do
            if IsValid(p) and p:GetNWBool("GRM_Arrested", false) and (p == lp or lp:GetPos():DistToSqr(p:GetPos()) < 600 * 600) then
                local sp = (p:GetPos() + Vector(0, 0, 82)):ToScreen()
                if sp.visible then
                    draw.SimpleText("АРЕСТОВАННЫЙ: " .. p:GetNWString("GRM_ArrestGroupName", ""), "GRMArrestTitle", sp.x, sp.y, Color(255, 150, 100), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
            end
        end
    end)
end

print("[GRM Arrest] v" .. A.Version .. " loaded")
