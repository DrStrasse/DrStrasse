--[[--------------------------------------------------------------------
    GRM Server Ban v1.0.0 — бан НА СЕРВЕРЕ (без выкидывания) и глобальный

    Заказ владельца (21.08): бан должен делиться на два вида.

      • «Забанить на сервере» — человек остаётся в игре, но превращается в
        отбывающего наказание: модель `models/player/skeleton.mdl`, материал
        `debugwhite`, красная подсветка, плашка «ЗАБАНЕН» над головой.
        Оружие изымается, самоубийство и меню недоступны, физган и тулган
        не работают, транспорт закрыт. Он может ходить только по отведённой
        территории — точку и радиус задаёт суперадмин.

      • «Глобальный бан» — жёсткий: игрок выкидывается с сервера штатным
        баном (ULib/ULX, иначе banid).

    Хранение: data/grm_admin/serverbans.json (кто и до какого времени) и
    data/grm_admin/serverban_zone.json (точка и радиус для каждой карты).

    Команды: grm_ban_point [радиус] — поставить точку по своей позиции,
             grm_ban_zone — показать текущую настройку,
             grm_serverban_list — список отбывающих.
----------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.ServerBan = GRM.ServerBan or {}
local SB = GRM.ServerBan
SB.Version = "1.0.0"

SB.Model = "models/player/skeleton.mdl"
SB.Material = "debugwhite"
SB.Net = { SYNC = "GRM_ServerBan_Sync" }

SB.Zone = SB.Zone or { pos = nil, radius = 600, map = "" }
SB.Bans = SB.Bans or {}

--- Осталось секунд по записи бана (0 — истёк).
function SB.Left(rec)
    if not istable(rec) then return 0 end
    local until_ = tonumber(rec["until"]) or 0
    if until_ <= 0 then return math.huge end -- бессрочно
    return math.max(0, until_ - os.time())
end

function SB.Describe(rec)
    if not istable(rec) then return "" end
    local left = SB.Left(rec)
    local when = left == math.huge and "бессрочно" or (math.ceil(left / 60) .. " мин.")
    return ("%s · %s"):format(tostring(rec.reason or "нарушение правил"), when)
end

-----------------------------------------------------------------------
-- СЕРВЕР
-----------------------------------------------------------------------
if SERVER then
    util.AddNetworkString(SB.Net.SYNC)

    local DIR = "grm_admin"
    local BANS_FILE = DIR .. "/serverbans.json"
    local ZONE_FILE = DIR .. "/serverban_zone.json"

    local function jsonT(raw)
        local ok, t = pcall(util.JSONToTable, raw or "", false, true)
        return (ok and istable(t)) and t or nil
    end
    local function ensureDir()
        if not file.IsDir(DIR, "DATA") then file.CreateDir(DIR) end
    end
    local function mapName() return string.lower(tostring(game.GetMap() or "unknown")) end

    local function announce(text)
        if GRM.Admin and GRM.Admin.Announce then GRM.Admin.Announce(text, "mod") else print("[GRM Ban] " .. text) end
    end

    local function actorName(ply)
        if not IsValid(ply) then return "Консоль" end
        local rp = ply:GetNWString("GRM_RPName", "")
        return rp ~= "" and rp or ply:Nick()
    end

    -- Диск — через общую очередь: бан пишется в момент действия, а не пачкой.
    if GRM.Save and GRM.Save.Register then
        GRM.Save.Register("serverban.list", { file = BANS_FILE, label = "Баны на сервере", delay = 2, priority = 2,
            build = function() ensureDir() return { version = 1, bans = SB.Bans } end })
        GRM.Save.Register("serverban.zone", { file = ZONE_FILE, label = "Точка отбывания бана", delay = 2,
            build = function() ensureDir() return { version = 1, zones = SB.Zones or {} } end })
    end

    local function saveBans(why)
        if GRM.Save and GRM.Save.Mark then return GRM.Save.Mark("serverban.list", why) end
        ensureDir()
        local ok, raw = pcall(util.TableToJSON, { version = 1, bans = SB.Bans }, true)
        if ok and isstring(raw) then file.Write(BANS_FILE, raw) return true end
        return false
    end
    local function saveZone(why)
        if GRM.Save and GRM.Save.Mark then return GRM.Save.Mark("serverban.zone", why) end
        ensureDir()
        local ok, raw = pcall(util.TableToJSON, { version = 1, zones = SB.Zones or {} }, true)
        if ok and isstring(raw) then file.Write(ZONE_FILE, raw) return true end
        return false
    end

    function SB.Load()
        SB.Bans, SB.Zones = {}, {}
        local data = jsonT(file.Read(BANS_FILE, "DATA") or "")
        if istable(data) and istable(data.bans) then
            for sid, rec in pairs(data.bans) do
                if isstring(sid) and istable(rec) then
                    SB.Bans[sid] = {
                        ["until"] = math.floor(tonumber(rec["until"]) or 0),
                        reason = tostring(rec.reason or ""),
                        by = tostring(rec.by or ""),
                        at = math.floor(tonumber(rec.at) or os.time()),
                        name = tostring(rec.name or ""),
                    }
                end
            end
        end
        local zones = jsonT(file.Read(ZONE_FILE, "DATA") or "")
        if istable(zones) and istable(zones.zones) then
            for map, z in pairs(zones.zones) do
                if isstring(map) and istable(z) and istable(z.pos) then
                    SB.Zones[map] = {
                        pos = Vector(tonumber(z.pos.x) or 0, tonumber(z.pos.y) or 0, tonumber(z.pos.z) or 0),
                        radius = math.Clamp(math.floor(tonumber(z.radius) or 600), 100, 8000),
                    }
                end
            end
        end
        return true
    end

    --- Зона отбывания для текущей карты (может отсутствовать — тогда наказание
    --  применяется «на месте», но без телепорта).
    function SB.CurrentZone()
        return (SB.Zones or {})[mapName()]
    end

    function SB.SetZone(actor, pos, radius)
        if not isvector(pos) then return false, "Нет позиции" end
        SB.Zones = SB.Zones or {}
        SB.Zones[mapName()] = { pos = Vector(pos.x, pos.y, pos.z),
            radius = math.Clamp(math.floor(tonumber(radius) or 600), 100, 8000) }
        saveZone("точка бана " .. mapName())
        if GRM.Audit and GRM.Audit.Write then
            GRM.Audit.Write("admin", "ban.zone", actor, { map = mapName() },
                { radius = SB.Zones[mapName()].radius })
        end
        return true, ("Точка отбывания бана задана · радиус %d"):format(SB.Zones[mapName()].radius)
    end

    -------------------------------------------------------------------
    -- ПРИМЕНЕНИЕ НАКАЗАНИЯ
    -------------------------------------------------------------------
    function SB.IsBanned(v)
        local sid = IsValid(v) and tostring(v:SteamID64() or "") or tostring(v or "")
        local rec = SB.Bans[sid]
        if not rec then return false end
        if SB.Left(rec) <= 0 then SB.Bans[sid] = nil saveBans("истёк " .. sid) return false end
        return true, rec
    end

    --- Наложить визуал и ограничения. Зовётся при бане, при спавне и раз в
    --  полсекунды сторожем: другие модули (одежда, кастомизация) могут
    --  вернуть игроку модель, поэтому наказание надо «дожимать».
    function SB.Apply(ply, teleport)
        if not IsValid(ply) then return end
        local banned, rec = SB.IsBanned(ply)
        if not banned then return end

        if ply:GetModel() ~= SB.Model then ply:SetModel(SB.Model) end
        if ply:GetMaterial() ~= SB.Material then ply:SetMaterial(SB.Material) end
        ply:SetColor(Color(255, 60, 60, 255))
        ply:SetRenderMode(RENDERMODE_TRANSCOLOR)
        ply:SetNWBool("GRM_ServerBanned", true)
        ply:SetNWString("GRM_ServerBanReason", tostring(rec.reason or ""))
        ply:SetNWInt("GRM_ServerBanUntil", math.floor(tonumber(rec["until"]) or 0))

        if ply:GetActiveWeapon() ~= NULL and IsValid(ply:GetActiveWeapon()) then ply:StripWeapons() end
        if #ply:GetWeapons() > 0 then ply:StripWeapons() end
        ply:StripAmmo()

        local zone = SB.CurrentZone()
        if teleport and zone and isvector(zone.pos) then
            ply:SetPos(zone.pos + Vector(0, 0, 8))
            ply:SetVelocity(-ply:GetVelocity())
        end
    end

    function SB.Clear(ply)
        if not IsValid(ply) then return end
        ply:SetNWBool("GRM_ServerBanned", false)
        ply:SetNWString("GRM_ServerBanReason", "")
        ply:SetNWInt("GRM_ServerBanUntil", 0)
        ply:SetMaterial("")
        ply:SetColor(Color(255, 255, 255, 255))
        ply:SetRenderMode(RENDERMODE_NORMAL)
        -- Модель вернут модули внешности; страховкой — стандартная.
        hook.Run("GRM_ServerBanCleared", ply)
        if ply:GetModel() == SB.Model then
            local restored = ply:GetNWString("GRM_PreBanModel", "")
            ply:SetModel(restored ~= "" and restored or "models/player/group01/male_02.mdl")
        end
        ply:Spawn()
    end

    -------------------------------------------------------------------
    -- БАН / РАЗБАН
    -------------------------------------------------------------------
    function SB.Ban(actor, target, minutes, reason)
        if not IsValid(target) or not target:IsPlayer() then return false, "Игрок не в сети" end
        minutes = math.Clamp(math.floor(tonumber(minutes) or 60), 0, 525600)
        reason = string.sub(string.Trim(tostring(reason or "Нарушение правил")), 1, 120)
        local sid = tostring(target:SteamID64() or "")
        if sid == "" then return false, "Нет SteamID" end

        target:SetNWString("GRM_PreBanModel", target:GetModel())
        SB.Bans[sid] = {
            ["until"] = minutes > 0 and (os.time() + minutes * 60) or 0,
            reason = reason, by = actorName(actor), at = os.time(), name = target:Nick(),
        }
        saveBans("бан " .. sid)
        SB.Apply(target, true)

        local text = ("%s забанен на сервере (%s) · %s"):format(target:Nick(),
            minutes > 0 and (minutes .. " мин.") or "бессрочно", reason)
        announce(actorName(actor) .. " выдал бан на сервере: " .. text)
        if GRM.Notify then
            GRM.Notify(target, "Вы забанены на сервере: " .. reason, 255, 90, 90)
        end
        if GRM.Audit and GRM.Audit.Write then
            GRM.Audit.Write("admin", "ban.server", actor, { steamid64 = sid, nick = target:Nick() },
                { minutes = minutes, reason = reason })
        end
        return true, text
    end

    function SB.Unban(actor, query)
        local sid = tostring(query or "")
        local target
        for _, p in ipairs((GRM.Perf and GRM.Perf.Players) and GRM.Perf.Players() or player.GetAll()) do
            if IsValid(p) and (tostring(p:SteamID64() or "") == sid) then target = p break end
        end
        if not SB.Bans[sid] then return false, "Серверного бана нет" end
        SB.Bans[sid] = nil
        saveBans("разбан " .. sid)
        if IsValid(target) then
            SB.Clear(target)
            if GRM.Notify then GRM.Notify(target, "Серверный бан снят.", 100, 220, 130) end
        end
        announce(actorName(actor) .. " снял бан на сервере с " ..
            (IsValid(target) and target:Nick() or sid))
        return true, "Серверный бан снят"
    end

    -------------------------------------------------------------------
    -- ОГРАНИЧЕНИЯ
    -------------------------------------------------------------------
    local function banned(ply) return IsValid(ply) and ply:GetNWBool("GRM_ServerBanned", false) end
    SB.PlayerBanned = banned

    --[[ ЕДИНЫЙ ЗАПРЕТ НА ЭФИР (заказ владельца 21.08). Волны и рации идут не
         через чат, а своими net-пакетами, поэтому блокировка чат-команд их
         не ловила. Модули зовут одну эту функцию и получают готовый текст —
         второй реализации запрета нет. ]]
    function SB.SpeechBlocked(ply, what)
        if not banned(ply) then return false end
        local rec = select(2, SB.IsBanned(ply))
        local left = rec and SB.Left(rec) or 0
        local when = left == math.huge and "бессрочно" or (math.ceil(left / 60) .. " мин.")
        return true, ("Вы отбываете административное наказание (деморган), поэтому %s недоступн%s. Осталось: %s")
            :format(tostring(what or "эфир"), tostring(what or ""):find("рация", 1, true) and "а" or "о", when)
    end

    --- Помощник для модулей: сам пишет игроку отказ и возвращает true.
    function SB.DenySpeech(ply, what)
        local blocked, text = SB.SpeechBlocked(ply, what)
        if not blocked then return false end
        if GRM.Notify then GRM.Notify(ply, text, 255, 110, 90) else ply:ChatPrint("[Бан] " .. text) end
        return true
    end

    hook.Add("CanPlayerSuicide", "GRM_ServerBan_NoSuicide", function(ply)
        if banned(ply) then return false end
    end)
    hook.Add("PlayerSwitchFlashlight", "GRM_ServerBan_NoFlash", function(ply)
        if banned(ply) then return false end
    end)
    hook.Add("PlayerCanPickupWeapon", "GRM_ServerBan_NoWeapons", function(ply)
        if banned(ply) then return false end
    end)
    hook.Add("PlayerCanPickupItem", "GRM_ServerBan_NoItems", function(ply)
        if banned(ply) then return false end
    end)
    hook.Add("CanPlayerEnterVehicle", "GRM_ServerBan_NoVehicle", function(ply)
        if banned(ply) then return false end
    end)
    hook.Add("PlayerNoClip", "GRM_ServerBan_NoClip", function(ply)
        if banned(ply) then return false end
    end)
    hook.Add("PhysgunPickup", "GRM_ServerBan_NoPhysgun", function(ply)
        if banned(ply) then return false end
    end)
    hook.Add("CanTool", "GRM_ServerBan_NoTool", function(ply)
        if banned(ply) then return false end
    end)
    hook.Add("PlayerUse", "GRM_ServerBan_NoUse", function(ply)
        if banned(ply) then return false end
    end)
    hook.Add("PlayerSpawnObject", "GRM_ServerBan_NoSpawn", function(ply)
        if banned(ply) then return false end
    end)
    for _, name in ipairs({ "PlayerSpawnProp", "PlayerSpawnSENT", "PlayerSpawnNPC", "PlayerSpawnVehicle",
        "PlayerSpawnEffect", "PlayerSpawnRagdoll", "PlayerSpawnSWEP", "PlayerGiveSWEP" }) do
        hook.Add(name, "GRM_ServerBan_NoSpawn_" .. name, function(ply)
            if banned(ply) then return false end
        end)
    end
    -- Меню (F1-F4) и служебные окна отбывающему не открываются.
    for _, name in ipairs({ "ShowHelp", "ShowTeam", "ShowSpare1", "ShowSpare2" }) do
        hook.Add(name, "GRM_ServerBan_NoMenus_" .. name, function(ply)
            if banned(ply) then return true end
        end)
    end
    -- Урон отбывающему и от него не проходит: наказание, а не арена.
    hook.Add("EntityTakeDamage", "GRM_ServerBan_NoDamage", function(ent, dmg)
        if banned(ent) then return true end
        local att = dmg and dmg:GetAttacker()
        if IsValid(att) and att:IsPlayer() and banned(att) then return true end
    end)
    --[[ Чат остаётся (человеку надо объясниться с админом), но команды —
         нет: иначе через /f4, /inv и прочее он обходит ограничения. ]]
    SB.WaveCommands = {
        ["/fr"] = "рация фракции", ["/frb"] = "рация фракции (OOC)", ["/frooc"] = "рация фракции (OOC)",
        ["/dep"] = "государственная волна", ["/d"] = "государственная волна",
        ["/depb"] = "государственная волна (OOC)", ["/db"] = "государственная волна (OOC)",
        ["/gnews"] = "государственные новости", ["/radio"] = "рация",
        ["/911"] = "экстренный вызов", ["/pcboard"] = "государственная база",
    }

    hook.Add("PlayerSay", "GRM_ServerBan_NoCommands", function(ply, text)
        if not banned(ply) then return end
        local msg = string.Trim(tostring(text or ""))
        if msg:sub(1, 1) ~= "/" and msg:sub(1, 1) ~= "!" then return end
        local cmd = string.lower(string.Explode(" ", msg)[1] or "")
        local wave = SB.WaveCommands[cmd] or SB.WaveCommands["/" .. cmd:sub(2)]
        SB.DenySpeech(ply, wave or "команды")
        return ""
    end)

    hook.Add("PlayerSpawn", "GRM_ServerBan_Respawn", function(ply)
        timer.Simple(0.5, function()
            if IsValid(ply) and select(1, SB.IsBanned(ply)) then SB.Apply(ply, true) end
        end)
    end)
    hook.Add("PlayerInitialSpawn", "GRM_ServerBan_Join", function(ply)
        timer.Simple(4, function()
            if IsValid(ply) and select(1, SB.IsBanned(ply)) then SB.Apply(ply, true) end
        end)
    end)

    --[[ Один сторож на всех: держит наказанных внутри зоны, дожимает вид
         (другие модули любят вернуть модель) и снимает истёкшие баны. ]]
    timer.Create("GRM_ServerBan_Watch", 0.5, 0, function()
        local zone = SB.CurrentZone()
        for _, ply in ipairs((GRM.Perf and GRM.Perf.Players) and GRM.Perf.Players() or player.GetAll()) do
            if IsValid(ply) then
                local isBanned, rec = SB.IsBanned(ply)
                if isBanned then
                    SB.Apply(ply, false)
                    if zone and isvector(zone.pos) then
                        local r = zone.radius or 600
                        if ply:GetPos():DistToSqr(zone.pos) > r * r then
                            ply:SetPos(zone.pos + Vector(0, 0, 8))
                            ply:SetVelocity(-ply:GetVelocity())
                            if GRM.Notify then GRM.Notify(ply, "Выход за пределы зоны запрещён.", 255, 120, 90) end
                        end
                    end
                elseif ply:GetNWBool("GRM_ServerBanned", false) then
                    -- Срок кончился, пока человек был в сети.
                    SB.Clear(ply)
                    if GRM.Notify then GRM.Notify(ply, "Срок бана истёк.", 100, 220, 130) end
                    announce(ply:Nick() .. ": срок бана на сервере истёк")
                end
            end
        end
    end)

    -------------------------------------------------------------------
    -- КОНСОЛЬ
    -------------------------------------------------------------------
    concommand.Add("grm_ban_point", function(ply, _, args)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end
        local ok, msg = SB.SetZone(ply, ply:GetPos(), tonumber(args and args[1]) or 600)
        ply:ChatPrint("[Бан] " .. tostring(msg))
    end)

    concommand.Add("grm_ban_zone", function(ply)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end
        local zone = SB.CurrentZone()
        local line = zone and ("[Бан] Точка: " .. tostring(zone.pos) .. " · радиус " .. zone.radius)
            or "[Бан] Точка отбывания не задана: встаньте на место и введите grm_ban_point"
        if IsValid(ply) then ply:ChatPrint(line) else print(line) end
    end)

    concommand.Add("grm_serverban_list", function(ply)
        if IsValid(ply) and not ply:IsSuperAdmin() then return end
        local function out(line)
            if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, line) else print(line) end
        end
        local n = 0
        for sid, rec in pairs(SB.Bans) do
            n = n + 1
            out(("  %s · %s · %s"):format(sid, tostring(rec.name or "?"), SB.Describe(rec)))
        end
        out("[Бан] Отбывают наказание на сервере: " .. n)
    end)

    SB.Load()
    if GRM.Boot and GRM.Boot.OnMapStart then
        GRM.Boot.OnMapStart("GRM_ServerBan_Load", "early", function()
            SB.Load()
            for _, ply in ipairs(player.GetAll()) do
                if select(1, SB.IsBanned(ply)) then SB.Apply(ply, true) end
            end
        end, { label = "Баны на сервере" })
    end

    print("[GRM Server Ban] v" .. SB.Version .. " loaded")
end

-----------------------------------------------------------------------
-- КЛИЕНТ: подсветка и плашка «ЗАБАНЕН»
-----------------------------------------------------------------------
if CLIENT then
    surface.CreateFont("GRM_Ban_Head", { font = "Roboto", size = 22, weight = 800, extended = true })
    surface.CreateFont("GRM_Ban_Sub", { font = "Roboto", size = 15, weight = 600, extended = true })

    --- Плашку рисует общий слой шапки (GRM.Nameplate), если он включён —
    --- две отрисовки над головой мы уже один раз чинили.
    hook.Add("GRM_NameplateOverride", "GRM_ServerBan_Plate", function(ply, info)
        if not (IsValid(ply) and istable(info)) then return end
        if not ply:GetNWBool("GRM_ServerBanned", false) then return end
        info.name = "ЗАБАНЕН"
        info.nameKnown = false
        info.tag = ply:GetNWString("GRM_ServerBanReason", "")
        info.tagColor = Color(235, 70, 70)
        info.desc = nil
        info.cid = nil
        info.banned = true
        return info
    end)

    -- Если общий слой шапки выключен, рисуем сами — иначе метка пропадёт.
    hook.Add("HUDPaint", "GRM_ServerBan_Fallback", function()
        if GRM.Nameplate and GRM.Nameplate.Active then return end
        local lp = LocalPlayer()
        if not IsValid(lp) then return end
        for _, ply in ipairs((GRM.Perf and GRM.Perf.Players) and GRM.Perf.Players() or player.GetAll()) do
            if IsValid(ply) and ply ~= lp and ply:GetNWBool("GRM_ServerBanned", false) then
                local screen = (ply:GetPos() + Vector(0, 0, 84)):ToScreen()
                if screen.visible and lp:GetPos():DistToSqr(ply:GetPos()) < 1200 * 1200 then
                    draw.SimpleText("ЗАБАНЕН", "GRM_Ban_Head", screen.x, screen.y,
                        Color(235, 70, 70), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
                end
            end
        end
    end)

    -- Самому наказанному — крупная памятка внизу экрана.
    hook.Add("HUDPaint", "GRM_ServerBan_Self", function()
        local lp = LocalPlayer()
        if not (IsValid(lp) and lp:GetNWBool("GRM_ServerBanned", false)) then return end
        local until_ = lp:GetNWInt("GRM_ServerBanUntil", 0)
        local left = until_ > 0 and math.max(0, until_ - os.time()) or -1
        local text = left < 0 and "бессрочно" or (math.ceil(left / 60) .. " мин.")
        local w, h = 520, 86
        local x, y = ScrW() * 0.5 - w * 0.5, ScrH() - h - 40
        draw.RoundedBox(8, x, y, w, h, Color(28, 10, 12, 235))
        draw.SimpleText("ВЫ ЗАБАНЕНЫ НА СЕРВЕРЕ", "GRM_Ban_Head", x + w * 0.5, y + 22,
            Color(235, 70, 70), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(lp:GetNWString("GRM_ServerBanReason", "нарушение правил") .. " · осталось " .. text,
            "GRM_Ban_Sub", x + w * 0.5, y + 50, Color(230, 210, 210), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("Меню и оружие недоступны. Ждите решения администрации.",
            "GRM_Ban_Sub", x + w * 0.5, y + 70, Color(170, 160, 160), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)

    print("[GRM Server Ban] client v" .. SB.Version .. " loaded")
end
