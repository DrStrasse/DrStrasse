--[[--------------------------------------------------------------------
    GRM Faction Duty v1.1.0 (Код 102)
    Смена статуса «на службе / вне службы» через служебного NPC.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.FactionDuty = GRM.FactionDuty or {}
local FD = GRM.FactionDuty
FD.Version = "1.1.0"

local NET_OPEN = "GRM_FactionDuty_Open"
local NET_SET = "GRM_FactionDuty_Set"
local NET_ADMIN = "GRM_FactionDuty_Admin"
local NET_ADMIN_SAVE = "GRM_FactionDuty_AdminSave"

local function characterKey(ply)
    if GRM.Identity and GRM.Identity.CharacterKey then return GRM.Identity.CharacterKey(ply) end
    return IsValid(ply) and (ply:SteamID64() .. ":char1") or ""
end

local function factionOf(ply)
    if not IsValid(ply) or not istable(Factions) then return nil end
    if _G.FactionsAPI and _G.FactionsAPI.GetFactionOf then
        local name = _G.FactionsAPI.GetFactionOf(ply)
        if name then return name end
    end
    for name, f in pairs(Factions) do
        if istable(f) and istable(f.Members) then
            local member
            if GRM.Identity and GRM.Identity.FactionMember then member = GRM.Identity.FactionMember(f, ply)
            else member = f.Members[characterKey(ply)] or f.Members[ply:SteamID64()] or f.Members[ply:SteamID()] end
            if member then return name, member, f end
        end
    end
    return nil
end
FD.FactionOf = factionOf

if SERVER then
    util.AddNetworkString(NET_OPEN)
    util.AddNetworkString(NET_SET)
    util.AddNetworkString(NET_ADMIN)
    util.AddNetworkString(NET_ADMIN_SAVE)

    local DATA_FILE = "grm_faction_duty.json"
    local function jsonT(raw)
        local ok, t = pcall(util.JSONToTable, raw or "", false, true)
        return ok and istable(t) and t or nil
    end
    local function load()
        local raw = file.Read(DATA_FILE, "DATA") or ""
        local t = jsonT(raw)
        if raw ~= "" and not t then file.Write(DATA_FILE .. ".corrupt." .. os.time() .. ".txt", raw) end
        FD.State = {}
        for _, r in ipairs(istable(t) and (t.records or t) or {}) do
            if istable(r) and isstring(r.key) and r.key ~= "" then FD.State[r.key] = r.onDuty ~= false end
        end
    end
    local function save(why)
        local rows = {}
        for key, onDuty in pairs(FD.State or {}) do rows[#rows + 1] = { key = key, onDuty = onDuty == true } end
        table.sort(rows, function(a, b) return a.key < b.key end)
        local ok, raw = pcall(util.TableToJSON, { version = 1, records = rows }, true)
        if not ok or not raw then return false end
        file.Write(DATA_FILE, raw)
        if not jsonT(file.Read(DATA_FILE, "DATA") or "") then print("[GRM Duty] SAVE FAIL") return false end
        print("[GRM Duty] SAVE ok [" .. tostring(why or "-") .. "]: " .. #rows .. " записей")
        return true
    end
    load()

    function FD.HasFaction(ply) return factionOf(ply) ~= nil end
    function FD.IsOnDuty(ply)
        if not FD.HasFaction(ply) then return false end
        local state = FD.State[characterKey(ply)]
        if state == nil then return true end -- член фракции впервые входит на службу
        return state == true
    end
    function FD.CanTakeCivilJob(ply)
        if not FD.HasFaction(ply) then return true end
        return not FD.IsOnDuty(ply)
    end

    local function applyAppearance(ply)
        if not IsValid(ply) then return end
        local list = isfunction(GetModelsForPlayer) and GetModelsForPlayer(ply) or nil
        if istable(list) and list[1] and isfunction(ApplyModelSettings) then ApplyModelSettings(ply, list[1]) end
        if isfunction(ApplyWeaponsToPlayer) then ApplyWeaponsToPlayer(ply) end
        if isfunction(sendModelsToPlayer) then sendModelsToPlayer(ply) end
    end

    function FD.Apply(ply)
        if not IsValid(ply) then return end
        local hasFaction = FD.HasFaction(ply)
        local onDuty = hasFaction and FD.IsOnDuty(ply)
        ply:SetNWBool("GRM_FactionOnDuty", onDuty)
        ply:SetNWBool("GRM_FactionOffDuty", hasFaction and not onDuty)
        if not onDuty then
            ply:SetNWBool("IsMasked", false)
            ply:SetNWString("MaskModel", "")
            ply:SetNWString("MaskName", "")
            ply.FactionsExt_MaskEntry = nil
        end
        timer.Simple(0, function() if IsValid(ply) then applyAppearance(ply) end end)
        hook.Run("GRM_FactionDutyChanged", ply, onDuty, factionOf(ply))
        if isfunction(broadcastFactionData) then broadcastFactionData() end
    end

    function FD.Set(ply, onDuty, actor)
        local fac = factionOf(ply)
        if not fac then return false, "Вы не состоите во фракции" end
        onDuty = onDuty == true
        if onDuty and GRM.Jobs and GRM.Jobs.Active and GRM.Jobs.Active[characterKey(ply)] then
            return false, "Сначала завершите или отмените гражданскую работу (/jobcancel)"
        end
        FD.State[characterKey(ply)] = onDuty
        save((onDuty and "выход на службу: " or "уход со службы: ") .. ply:Nick())
        FD.Apply(ply)
        return true, onDuty and "Вы вышли на службу. Форма и снаряжение восстановлены." or "Вы вне службы. Теперь доступны гражданские подработки."
    end

    function FD.Open(ply, ent)
        if not IsValid(ply) or not IsValid(ent) or ent:GetClass() ~= "grm_duty_npc" then return end
        if ply:GetPos():DistToSqr(ent:GetPos()) > 220 * 220 then return end
        local fac = factionOf(ply)
        if not fac then
            if GRM.Notify then GRM.Notify(ply, "Этот пункт предназначен для сотрудников фракций.", 255, 170, 90) end
            return
        end
        local stationFac = ent:GetNWString("GRM_DutyFaction", "")
        if stationFac == "" or stationFac == "*" or not (Factions and Factions[stationFac]) then
            if GRM.Notify then GRM.Notify(ply, "Этот служебный диспетчер не настроен. Суперадмин должен привязать его к фракции.", 255, 170, 90) end
            return
        end
        if stationFac ~= fac then
            if GRM.Notify then GRM.Notify(ply, "Этот пункт обслуживает только фракцию «" .. stationFac .. "».", 255, 130, 110) end
            return
        end
        net.Start(NET_OPEN)
            net.WriteEntity(ent)
            net.WriteString(fac)
            net.WriteBool(FD.IsOnDuty(ply))
            net.WriteString(ent:GetNWString("GRM_DutyTitle", "Пункт выхода на службу"))
        net.Send(ply)
    end

    function FD.OpenAdmin(ply, ent)
        if not IsValid(ply) or not ply:IsSuperAdmin() or not IsValid(ent) or ent:GetClass() ~= "grm_duty_npc" then return end
        if ply:GetPos():DistToSqr(ent:GetPos()) > 300 * 300 then return end
        local factions = {}
        for name in pairs(Factions or {}) do factions[#factions + 1] = name end
        table.sort(factions, function(a,b) return string.lower(a) < string.lower(b) end)
        net.Start(NET_ADMIN)
            net.WriteEntity(ent)
            net.WriteString(ent:GetNWString("GRM_DutyFaction", ""))
            net.WriteString(ent:GetNWString("GRM_DutyTitle", "ПУНКТ ВЫХОДА НА СЛУЖБУ"))
            net.WriteString(ent:GetNWString("GRM_DutyModel", ent:GetModel()))
            net.WriteTable(factions)
        net.Send(ply)
    end

    net.Receive(NET_ADMIN_SAVE, function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() or (ply._grmDutyAdminAt or 0) > CurTime() then return end
        ply._grmDutyAdminAt = CurTime() + 0.5
        local ent = net.ReadEntity()
        local fac = string.sub(string.Trim(net.ReadString() or ""), 1, 80)
        local title = string.sub(string.Trim(net.ReadString() or ""), 1, 80)
        local mdl = string.sub(string.Trim(net.ReadString() or ""), 1, 180)
        if not IsValid(ent) or ent:GetClass() ~= "grm_duty_npc" or ply:GetPos():DistToSqr(ent:GetPos()) > 300 * 300 then return end
        if not (Factions and Factions[fac]) then
            if GRM.Notify then GRM.Notify(ply, "Выберите существующую фракцию.", 255, 130, 110) end
            return
        end
        if title == "" then title = "ПУНКТ ВЫХОДА НА СЛУЖБУ" end
        ent:SetNWString("GRM_DutyFaction", fac)
        ent:SetNWString("GRM_DutyTitle", title)
        if util.IsValidModel(mdl) then ent:SetNWString("GRM_DutyModel",mdl);ent:SetModel(mdl);if ent.RefreshIdle then ent:RefreshIdle(true)end end
        if GRM.Perm and GRM.Perm.Update then GRM.Perm.Update(ply, ent) end
        if GRM.Notify then GRM.Notify(ply, "Диспетчер привязан к фракции «" .. fac .. "».", 80, 230, 150) end
    end)

    net.Receive(NET_SET, function(_, ply)
        if not IsValid(ply) or (ply._grmDutyActAt or 0) > CurTime() then return end
        ply._grmDutyActAt = CurTime() + 1
        local ent = net.ReadEntity()
        local want = net.ReadBool()
        if not IsValid(ent) or ent:GetClass() ~= "grm_duty_npc" or ply:GetPos():DistToSqr(ent:GetPos()) > 220 * 220 then return end
        local stationFac, fac = ent:GetNWString("GRM_DutyFaction", ""), factionOf(ply)
        if not fac or stationFac == "" or stationFac == "*" or stationFac ~= fac then return end
        local ok, msg = FD.Set(ply, want, ply)
        if GRM.Notify then GRM.Notify(ply, msg, ok and 80 or 255, ok and 230 or 130, ok and 150 or 110) else ply:ChatPrint("[Служба] " .. msg) end
    end)

    local function delayedApply(ply)
        timer.Simple(2, function() if IsValid(ply) then FD.Apply(ply) end end)
    end
    hook.Add("PlayerInitialSpawn", "GRM_Duty_Join", delayedApply)
    hook.Add("PlayerSpawn", "GRM_Duty_Spawn", function(ply) timer.Simple(0.5, function() if IsValid(ply) then FD.Apply(ply) end end) end)
    hook.Add("GRM_CharacterChanged", "GRM_Duty_Character", function(ply) delayedApply(ply) end)
    hook.Add("ShutDown", "GRM_Duty_Save", function() save("shutdown") end)

    -- Регистрация перма отложена: ядро sh_grm_perm_entities.lua грузится позже.
    local function registerPerm()
        if GRM.Perm and GRM.Perm.RegisterClass then GRM.Perm.RegisterClass("grm_duty_npc", true) end
        if not (GRM.PermData and GRM.PermData.Extract and GRM.PermData.Apply) then return end
        GRM.PermData.Extract["grm_duty_npc"] = function(ent)
            return { duty = { faction = ent:GetNWString("GRM_DutyFaction", ""), title = ent:GetNWString("GRM_DutyTitle", "ПУНКТ ВЫХОДА НА СЛУЖБУ"), model = ent:GetNWString("GRM_DutyModel", ent:GetModel()) } }
        end
        GRM.PermData.Apply["grm_duty_npc"] = function(ent, data)
            local d = istable(data) and data.duty or nil
            if not istable(d) then return end
            ent:SetNWString("GRM_DutyFaction", tostring(d.faction or ""))
            ent:SetNWString("GRM_DutyTitle", tostring(d.title or "ПУНКТ ВЫХОДА НА СЛУЖБУ"))
            if util.IsValidModel(tostring(d.model or""))then ent:SetNWString("GRM_DutyModel",d.model);ent:SetModel(d.model);if ent.RefreshIdle then ent:RefreshIdle(true)end end
        end
    end
    timer.Simple(1, registerPerm)
    timer.Simple(4, registerPerm)

    local function statusChat(ply, text)
        local low = string.lower(string.Trim(text or ""))
        if low ~= "/duty" and low ~= "/служба" then return false end
        local fac = factionOf(ply)
        if not fac then ply:ChatPrint("[Служба] Вы не состоите во фракции.")
        else ply:ChatPrint("[Служба] " .. fac .. ": " .. (FD.IsOnDuty(ply) and "НА СЛУЖБЕ" or "ВНЕ СЛУЖБЫ") .. ". Смена статуса — у служебного NPC.") end
        return true
    end
    hook.Add("PlayerSayTransform", "GRM_Duty_Transform", function(ply, data) if istable(data) and isstring(data[1]) and statusChat(ply, data[1]) then data[1] = "" data.SkipPlayerSay = true end end)
    hook.Add("PlayerSay", "GRM_Duty_Chat", function(ply, text) if statusChat(ply, text) then return "" end end)
else
    surface.CreateFont("GRMDuty_Title", { font = "Roboto", size = 22, weight = 800, extended = true })
    surface.CreateFont("GRMDuty_Text", { font = "Roboto", size = 14, weight = 500, extended = true })
    net.Receive(NET_ADMIN, function()
        local ent, current, currentTitle, currentModel, factions = net.ReadEntity(), net.ReadString(), net.ReadString(), net.ReadString(), net.ReadTable() or {}
        if not IsValid(ent) then return end
        if IsValid(FD._adminFrame) then FD._adminFrame:Remove() end
        local f=vgui.Create("DFrame") FD._adminFrame=f; f:SetSize(620,390); f:Center(); f:MakePopup(); f:SetTitle("Настройка служебного диспетчера")
        local selectedFaction=current
        local fac=vgui.Create("DComboBox",f); fac:SetPos(20,60); fac:SetSize(580,32); fac:SetValue(current ~= "" and current or "Выберите фракцию")
        for _,name in ipairs(factions) do fac:AddChoice(name,name,name==current) end
        fac.OnSelect=function(_,_,_,data) selectedFaction=tostring(data or "") end
        local title=vgui.Create("DTextEntry",f); title:SetPos(20,120); title:SetSize(580,30); title:SetValue(currentTitle); title:SetPlaceholderText("Надпись пункта")
        local mdl=vgui.Create("DTextEntry",f); mdl:SetPos(20,180); mdl:SetSize(580,30); mdl:SetValue(currentModel); mdl:SetPlaceholderText("Модель NPC")
        local hint=vgui.Create("DLabel",f); hint:SetPos(20,225); hint:SetSize(580,55); hint:SetWrap(true); hint:SetText("Каждый NPC обслуживает только одну выбранную фракцию. Название фракции автоматически показывается на 3D2D-табличке над ним.")
        local saveBtn=vgui.Create("DButton",f); saveBtn:SetPos(20,305); saveBtn:SetSize(580,42); saveBtn:SetText("СОХРАНИТЬ И ОБНОВИТЬ ПЕРМ")
        saveBtn.DoClick=function() net.Start(NET_ADMIN_SAVE); net.WriteEntity(ent); net.WriteString(tostring(selectedFaction or "")); net.WriteString(title:GetValue()); net.WriteString(mdl:GetValue()); net.SendToServer(); f:Close() end
    end)

    net.Receive(NET_OPEN, function()
        local ent, fac, onDuty, title = net.ReadEntity(), net.ReadString(), net.ReadBool(), net.ReadString()
        if IsValid(FD._frame) then FD._frame:Remove() end
        local f = vgui.Create("DFrame") FD._frame = f
        f:SetSize(580, 330) f:Center() f:MakePopup() f:SetTitle("") f:ShowCloseButton(false)
        f.Paint = function(_, w, h) draw.RoundedBox(9, 0, 0, w, h, Color(8,14,23,248)); draw.RoundedBoxEx(9,0,0,w,54,Color(10,22,37),true,true,false,false); draw.SimpleText(title,"GRMDuty_Title",16,27,Color(225,238,247),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
        local close=vgui.Create("DButton",f) close:SetPos(536,11) close:SetSize(30,30) close:SetText("✕") close.DoClick=function() f:Close() end
        local info=vgui.Create("DLabel",f) info:SetPos(18,78) info:SetSize(544,88) info:SetFont("GRMDuty_Text") info:SetTextColor(Color(225,238,247)) info:SetWrap(true)
        info:SetText("Фракция: "..fac.."\nТекущий статус: "..(onDuty and "НА СЛУЖБЕ" or "ВНЕ СЛУЖБЫ").."\nНа службе используются форма и вооружение фракции. Вне службы — гражданская одежда и доступ к городским работам.")
        local b=vgui.Create("DButton",f) b:SetPos(18,196) b:SetSize(544,46) b:SetText(onDuty and "ЗАВЕРШИТЬ СЛУЖБУ" or "ВЫЙТИ НА СЛУЖБУ") b:SetTextColor(color_white)
        b.Paint=function(s,w,h) draw.RoundedBox(6,0,0,w,h,onDuty and Color(244,150,70) or Color(64,222,147)) end
        b.DoClick=function() if not IsValid(ent) then return end net.Start(NET_SET) net.WriteEntity(ent) net.WriteBool(not onDuty) net.SendToServer() f:Close() end
        local hint=vgui.Create("DLabel",f) hint:SetPos(18,258) hint:SetSize(544,42) hint:SetFont("GRMDuty_Text") hint:SetTextColor(Color(132,160,178)) hint:SetWrap(true); hint:SetText(onDuty and "После завершения службы вы сможете работать курьером, таксистом или мусоровозом." or "Перед выходом на службу завершите активную гражданскую работу.")
    end)
end

print("[GRM Duty] v" .. FD.Version .. " loaded")
