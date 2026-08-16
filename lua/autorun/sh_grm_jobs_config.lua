--[[--------------------------------------------------------------------
    GRM Jobs Configuration v1.0.0 (Код 77, расширение v3)
    Типизированные точки/маршруты, транспорт, такса и городская казна.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Jobs = GRM.Jobs or {}
local JB = GRM.Jobs
JB.ConfigVersion = "1.0.0"

local NET_OPEN = "GRM_JobsAdmin_Open"
local NET_ACT = "GRM_JobsAdmin_Act"
local NET_TAXI = "GRM_JobsTaxi_Open"
local NET_TAXI_SET = "GRM_JobsTaxi_Set"

local POINT_TYPES = {
    all = "Универсальная",
    courier = "Курьер",
    garbage = "Мусорный контейнер",
    dump = "Свалка",
    taxi_pickup = "Посадка такси",
    taxi_dropoff = "Назначение такси",
}
JB.PointTypes = POINT_TYPES

local function clamp(v, lo, hi)
    v = tonumber(v) or lo
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

if SERVER then
    util.AddNetworkString(NET_OPEN)
    util.AddNetworkString(NET_ACT)
    util.AddNetworkString(NET_TAXI)
    util.AddNetworkString(NET_TAXI_SET)

    local DIR = "grm_jobs"
    local CFG_FILE = DIR .. "/config.json"
    local function mapFile() return DIR .. "/points_" .. string.lower(game.GetMap() or "unknown") .. ".json" end
    local function ensureDir() if not file.IsDir(DIR, "DATA") then file.CreateDir(DIR) end end
    local function jsonT(raw)
        local ok, data = pcall(util.JSONToTable, raw or "", false, true)
        return ok and istable(data) and data or nil
    end
    local function quarantine(path, raw)
        if raw and raw ~= "" then file.Write(path .. ".corrupt." .. os.time() .. ".txt", raw) end
    end
    local function defaults()
        return {
            version = 1,
            fundFromState = true,
            taxiMin = 300,
            taxiMax = 2500,
            taxiDefault = 700,
            taxiVehicles = {},
            garbageVehicles = {},
            garbageStops = 2,
        }
    end
    local function normalizeCfg(t)
        local d = defaults()
        t = istable(t) and t or {}
        d.fundFromState = t.fundFromState ~= false
        d.taxiMin = math.floor(clamp(t.taxiMin, 0, 100000))
        d.taxiMax = math.floor(clamp(t.taxiMax, d.taxiMin, 100000))
        d.taxiDefault = math.floor(clamp(t.taxiDefault, d.taxiMin, d.taxiMax))
        d.garbageStops = math.floor(clamp(t.garbageStops, 1, 8))
        d.taxiVehicles = istable(t.taxiVehicles) and t.taxiVehicles or {}
        d.garbageVehicles = istable(t.garbageVehicles) and t.garbageVehicles or {}
        return d
    end
    local function normalizePoints(t)
        local out = {}
        t = istable(t) and (t.points or t) or {}
        for _, r in ipairs(t) do
            if istable(r) and istable(r.pos) then
                local typ = POINT_TYPES[tostring(r.type or "all")] and tostring(r.type or "all") or "all"
                out[#out + 1] = {
                    id = tostring(r.id or ("jp_" .. os.time() .. "_" .. #out + 1)),
                    type = typ,
                    name = string.sub(tostring(r.name or POINT_TYPES[typ]), 1, 64),
                    pos = { x = tonumber(r.pos.x) or 0, y = tonumber(r.pos.y) or 0, z = tonumber(r.pos.z) or 0 },
                    created = tonumber(r.created) or os.time(),
                }
            end
        end
        return out
    end
    local function save(path, data, why)
        ensureDir()
        local ok, raw = pcall(util.TableToJSON, data, true)
        if not ok or not raw then return false end
        file.Write(path, raw)
        local check = jsonT(file.Read(path, "DATA") or "")
        if not check then print("[GRM Jobs v3] SAVE FAIL " .. path) return false end
        print("[GRM Jobs v3] SAVE ok: " .. path .. " [" .. tostring(why or "-") .. "]")
        return true
    end
    function JB.LoadWorkConfig()
        ensureDir()
        local raw = file.Read(CFG_FILE, "DATA") or ""
        local cfg = jsonT(raw)
        if raw ~= "" and not cfg then quarantine(CFG_FILE, raw) end
        JB.WorkConfig = normalizeCfg(cfg)
        raw = file.Read(mapFile(), "DATA") or ""
        local pts = jsonT(raw)
        if raw ~= "" and not pts then quarantine(mapFile(), raw) end
        JB.WorkPoints = normalizePoints(pts)
    end
    function JB.SaveWorkConfig(why)
        return save(CFG_FILE, JB.WorkConfig, why) and save(mapFile(), { version = 1, points = JB.WorkPoints }, why)
    end
    JB.LoadWorkConfig()

    local function pointObject(rec)
        local pos = Vector(rec.pos.x, rec.pos.y, rec.pos.z)
        return {
            _grmJobPoint = rec,
            GetPos = function() return pos end,
            GetNWString = function(_, key, fallback)
                if key == "GRM_JobZoneName" then return rec.name end
                return fallback
            end,
        }
    end
    function JB.GetRoutePoints(kind)
        local out, all = {}, {}
        for _, rec in ipairs(JB.WorkPoints or {}) do
            local obj = pointObject(rec)
            all[#all + 1] = obj
            if kind == "all" or rec.type == kind or rec.type == "all" then out[#out + 1] = obj end
        end
        if #out > 0 then return out end
        if kind == "all" then return all end
        return nil -- старые grm_depot остаются фолбэком ядра
    end

    local function vehicleToken(ent)
        if not IsValid(ent) then return "" end
        local raw = {
            ent:GetClass(), ent:GetNWString("GRMSpawnName", ""), ent:GetNWString("SpawnName", ""),
            ent:GetNWString("VehicleName", ""), ent.VehicleName, ent.SpawnName,
        }
        local candidates = {}
        for _, v in ipairs(raw) do if tostring(v or "") ~= "" then candidates[#candidates + 1] = string.lower(tostring(v)) end end
        return candidates
    end
    function JB.IsWorkVehicleAllowed(ply, workID)
        if not IsValid(ply) or not ply:InVehicle() then return false end
        local veh = ply:GetVehicle()
        if not IsValid(veh) then return false end
        if veh.GetDriver and veh:GetDriver() ~= ply then return false end
        local list = workID == "taxi" and JB.WorkConfig.taxiVehicles or (workID == "garbage" and JB.WorkConfig.garbageVehicles or {})
        if not istable(list) or #list == 0 then return true end
        local tokens = vehicleToken(veh)
        for _, allow in ipairs(list) do
            allow = string.lower(string.Trim(tostring(allow or "")))
            if allow ~= "" then
                for _, token in ipairs(tokens) do if string.lower(tostring(token or "")) == allow then return true end end
            end
        end
        return false
    end

    JB.TaxiFares = JB.TaxiFares or {}
    local function charKey(ply)
        return (GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(ply)) or (ply:SteamID64() .. ":char1")
    end
    function JB.GetTaxiFare(ply, fallback)
        local fare = JB.TaxiFares[charKey(ply)] or JB.WorkConfig.taxiDefault or fallback
        return math.floor(clamp(fare, JB.WorkConfig.taxiMin, JB.WorkConfig.taxiMax))
    end
    function JB.ReserveSystemReward(ply, workID, reward)
        reward = math.max(0, math.floor(tonumber(reward) or 0))
        if not JB.WorkConfig.fundFromState then return true, 0 end
        local E = GRM.Economy
        local get = E and E.StateBudgetGet or GRM.StateBudgetGet
        local add = E and E.StateBudgetAdd
        if not isfunction(get) or not isfunction(add) then return true, 0 end
        if (tonumber(get()) or 0) < reward then return false, "Городская казна не может профинансировать эту работу." end
        add(-reward, "Биржа труда: резерв «" .. tostring(workID) .. "» для " .. ply:Nick())
        return true, reward
    end
    function JB.RefundSystemReward(amount, why)
        amount = math.max(0, math.floor(tonumber(amount) or 0))
        local E = GRM.Economy
        if amount > 0 and E and isfunction(E.StateBudgetAdd) then E.StateBudgetAdd(amount, "Биржа труда: возврат резерва (" .. tostring(why) .. ")") end
    end

    local function snapshot(ply)
        net.Start(NET_OPEN)
            net.WriteTable(JB.WorkConfig or defaults())
            net.WriteTable(JB.WorkPoints or {})
            net.WriteTable(POINT_TYPES)
        net.Send(ply)
    end
    local function openAdmin(ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        snapshot(ply)
    end
    local function parseList(text)
        local out, seen = {}, {}
        for part in string.gmatch(tostring(text or "") .. ",", "(.-),") do
            part = string.lower(string.Trim(part))
            if part ~= "" and #part <= 80 and not seen[part] then seen[part] = true out[#out + 1] = part end
        end
        return out
    end
    net.Receive(NET_ACT, function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        if (ply._grmJobsAdminAt or 0) > CurTime() then return end
        ply._grmJobsAdminAt = CurTime() + 0.25
        local act = net.ReadString()
        if act == "save" then
            local t = net.ReadTable() or {}
            JB.WorkConfig.fundFromState = t.fundFromState ~= false
            JB.WorkConfig.taxiMin = math.floor(clamp(t.taxiMin, 0, 100000))
            JB.WorkConfig.taxiMax = math.floor(clamp(t.taxiMax, JB.WorkConfig.taxiMin, 100000))
            JB.WorkConfig.taxiDefault = math.floor(clamp(t.taxiDefault, JB.WorkConfig.taxiMin, JB.WorkConfig.taxiMax))
            JB.WorkConfig.garbageStops = math.floor(clamp(t.garbageStops, 1, 8))
            JB.WorkConfig.taxiVehicles = parseList(t.taxiVehicles)
            JB.WorkConfig.garbageVehicles = parseList(t.garbageVehicles)
            JB.SaveWorkConfig("админ-настройки")
        elseif act == "add_point" then
            local typ = net.ReadString()
            local name = string.sub(string.Trim(net.ReadString()), 1, 64)
            if not POINT_TYPES[typ] then return end
            local tr = ply:GetEyeTrace()
            local pos = tr and tr.HitPos or ply:GetPos()
            JB.WorkPoints[#JB.WorkPoints + 1] = { id = "jp_" .. os.time() .. "_" .. math.random(1000, 9999), type = typ, name = name ~= "" and name or POINT_TYPES[typ], pos = { x = pos.x, y = pos.y, z = pos.z + 4 }, created = os.time() }
            JB.SaveWorkConfig("добавлена точка")
        elseif act == "remove_point" then
            local id = net.ReadString()
            for i = #JB.WorkPoints, 1, -1 do if JB.WorkPoints[i].id == id then table.remove(JB.WorkPoints, i) break end end
            JB.SaveWorkConfig("удалена точка")
        end
        snapshot(ply)
    end)
    net.Receive(NET_TAXI_SET, function(_, ply)
        if not IsValid(ply) then return end
        local fare = math.floor(clamp(net.ReadUInt(20), JB.WorkConfig.taxiMin, JB.WorkConfig.taxiMax))
        JB.TaxiFares[charKey(ply)] = fare
        ply:ChatPrint("[Такси] Такса установлена: " .. tostring(fare) .. ". Она применится к следующему заказу.")
    end)
    local function openTaxi(ply)
        net.Start(NET_TAXI)
            net.WriteUInt(JB.GetTaxiFare(ply, JB.WorkConfig.taxiDefault), 20)
            net.WriteUInt(JB.WorkConfig.taxiMin, 20)
            net.WriteUInt(JB.WorkConfig.taxiMax, 20)
            net.WriteTable(JB.WorkConfig.taxiVehicles)
        net.Send(ply)
    end
    local function chat(ply, text)
        local low = string.lower(string.Trim(text or ""))
        if low == "/jobs_admin" or low == "/jobadmin" then openAdmin(ply) return true end
        if low == "/taxi" or low == "/такси" then openTaxi(ply) return true end
        return false
    end
    hook.Add("PlayerSayTransform", "GRM_JobsV3_Transform", function(ply, data)
        if istable(data) and isstring(data[1]) and chat(ply, data[1]) then data[1] = "" data.SkipPlayerSay = true end
    end)
    hook.Add("PlayerSay", "GRM_JobsV3_Chat", function(ply, text) if chat(ply, text) then return "" end end)
    concommand.Add("grm_jobs_admin", openAdmin)
else
    surface.CreateFont("GRMJobsCfg_Title", { font = "Roboto", size = 22, weight = 800, extended = true })
    surface.CreateFont("GRMJobsCfg_Text", { font = "Roboto", size = 14, weight = 500, extended = true })
    local C = { bg = Color(8,14,23,248), panel = Color(16,27,42), text = Color(225,238,247), muted = Color(132,160,178), cyan = Color(48,204,255), green = Color(64,222,147), red = Color(244,78,96) }
    local function frame(title, w, h)
        local f = vgui.Create("DFrame") f:SetSize(w,h) f:Center() f:MakePopup() f:SetTitle("") f:ShowCloseButton(false)
        f.Paint=function(_,pw,ph) draw.RoundedBox(9,0,0,pw,ph,C.bg) draw.RoundedBoxEx(9,0,0,pw,52,Color(10,22,37),true,true,false,false) draw.SimpleText(title,"GRMJobsCfg_Title",16,26,C.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end
        local x=vgui.Create("DButton",f) x:SetPos(w-42,10) x:SetSize(30,30) x:SetText("✕") x:SetTextColor(color_white) x.Paint=function(s,pw,ph) draw.RoundedBox(4,0,0,pw,ph,s:IsHovered() and C.red or Color(40,55,70)) end x.DoClick=function() f:Close() end
        return f
    end
    local function field(parent, label, value, y)
        local l=vgui.Create("DLabel",parent) l:SetPos(16,y) l:SetSize(250,20) l:SetText(label) l:SetTextColor(C.muted) l:SetFont("GRMJobsCfg_Text")
        local e=vgui.Create("DTextEntry",parent) e:SetPos(270,y-2) e:SetSize(380,24) e:SetValue(tostring(value or "")) return e
    end
    net.Receive(NET_OPEN, function()
        local cfg, points, types = net.ReadTable() or {}, net.ReadTable() or {}, net.ReadTable() or {}
        if IsValid(JB._adminFrame) then JB._adminFrame:Remove() end
        local f=frame("РАБОТЫ • НАСТРОЙКА МАРШРУТОВ",920,680) JB._adminFrame=f
        local sheet=vgui.Create("DPropertySheet",f) sheet:SetPos(12,60) sheet:SetSize(896,608)
        local settings=vgui.Create("DPanel",sheet) settings.Paint=function(_,w,h) draw.RoundedBox(6,0,0,w,h,C.panel) end
        local min=field(settings,"Минимальная такса",cfg.taxiMin,20)
        local max=field(settings,"Максимальная такса",cfg.taxiMax,56)
        local def=field(settings,"Такса по умолчанию",cfg.taxiDefault,92)
        local tv=field(settings,"Транспорт такси (через запятую)",table.concat(cfg.taxiVehicles or {},", "),128)
        local gv=field(settings,"Транспорт мусоровоза",table.concat(cfg.garbageVehicles or {},", "),164)
        local gs=field(settings,"Контейнеров в маршруте",cfg.garbageStops,200)
        local fund=vgui.Create("DCheckBoxLabel",settings) fund:SetPos(16,242) fund:SetSize(500,28) fund:SetText("Финансировать системные работы из городской казны") fund:SetTextColor(C.text) fund:SetValue(cfg.fundFromState and 1 or 0)
        local save=vgui.Create("DButton",settings) save:SetPos(16,290) save:SetSize(634,38) save:SetText("СОХРАНИТЬ НАСТРОЙКИ") save:SetTextColor(color_white) save.Paint=function(s,w,h) draw.RoundedBox(5,0,0,w,h,s:IsHovered() and Color(80,235,165) or C.green) end
        save.DoClick=function() net.Start(NET_ACT) net.WriteString("save") net.WriteTable({taxiMin=tonumber(min:GetValue()),taxiMax=tonumber(max:GetValue()),taxiDefault=tonumber(def:GetValue()),taxiVehicles=tv:GetValue(),garbageVehicles=gv:GetValue(),garbageStops=tonumber(gs:GetValue()),fundFromState=fund:GetChecked()}) net.SendToServer() end
        sheet:AddSheet("Настройки",settings,"icon16/cog.png")
        local pp=vgui.Create("DPanel",sheet) pp.Paint=function(_,w,h) draw.RoundedBox(6,0,0,w,h,C.panel) end
        local typ=vgui.Create("DComboBox",pp) typ:SetPos(16,16) typ:SetSize(220,28) typ:SetValue("Тип точки") for id,n in pairs(types) do typ:AddChoice(n,id) end
        local name=vgui.Create("DTextEntry",pp) name:SetPos(246,16) name:SetSize(300,28) name:SetPlaceholderText("Название точки")
        local add=vgui.Create("DButton",pp) add:SetPos(556,16) add:SetSize(190,28) add:SetText("Добавить по прицелу") add.DoClick=function() local _,id=typ:GetSelected() if not id then return end net.Start(NET_ACT) net.WriteString("add_point") net.WriteString(id) net.WriteString(name:GetValue()) net.SendToServer() end
        local sc=vgui.Create("DScrollPanel",pp) sc:SetPos(16,56) sc:SetSize(850,490)
        for _,r in ipairs(points) do local row=vgui.Create("DPanel",sc) row:Dock(TOP) row:DockMargin(0,0,0,6) row:SetTall(44) row.Paint=function(_,w,h) draw.RoundedBox(4,0,0,w,h,Color(22,37,56)) draw.SimpleText((types[r.type] or r.type).." • "..r.name,"GRMJobsCfg_Text",12,12,C.text) end local del=vgui.Create("DButton",row) del:Dock(RIGHT) del:SetWide(100) del:SetText("Удалить") del.DoClick=function() net.Start(NET_ACT) net.WriteString("remove_point") net.WriteString(r.id) net.SendToServer() end sc:AddItem(row) end
        sheet:AddSheet("Точки и маршруты",pp,"icon16/map.png")
    end)
    net.Receive(NET_TAXI, function()
        local cur,min,max,vehicles=net.ReadUInt(20),net.ReadUInt(20),net.ReadUInt(20),net.ReadTable() or {}
        local f=frame("ТАКСИ • ТАРИФ",560,280)
        local s=vgui.Create("DNumSlider",f) s:SetPos(18,78) s:SetSize(520,44) s:SetText("Такса за поездку") s:SetMin(min) s:SetMax(max) s:SetDecimals(0) s:SetValue(cur)
        local l=vgui.Create("DLabel",f) l:SetPos(18,130) l:SetSize(520,48) l:SetText("Разрешённый транспорт: "..(#vehicles>0 and table.concat(vehicles,", ") or "любой автомобиль")) l:SetWrap(true) l:SetTextColor(C.muted)
        local b=vgui.Create("DButton",f) b:SetPos(18,198) b:SetSize(520,40) b:SetText("УСТАНОВИТЬ ТАКСУ") b:SetTextColor(color_white) b.Paint=function(_,w,h) draw.RoundedBox(5,0,0,w,h,C.green) end b.DoClick=function() net.Start(NET_TAXI_SET) net.WriteUInt(math.floor(s:GetValue()),20) net.SendToServer() f:Close() end
    end)
end
