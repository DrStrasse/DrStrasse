--[[--------------------------------------------------------------------
    GRM Photo / Correspondence
    Камера → альбом → почта ведомства → печать ориентировки.
    Чужой Typography/GTA не копируется.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Photo = GRM.Photo or {}
local P = GRM.Photo
P.Version = "1.0.0"

P.Config = {
    MaxBytes = 40000,
    MaxPerPlayer = 24,
    MaxMail = 80,
    MaxTitle = 48,
    CamW = 512,
    CamH = 384,
    InboxCivil = "civil",
    InboxMilitary = "military",
}

local DIR = "grm_photos"
local IDX = DIR .. "/index.json"
local MAIL = DIR .. "/mail.json"

local function jsonLoad(path)
    if not file.Exists(path, "DATA") then return {} end
    local raw = file.Read(path, "DATA") or ""
    local ok, t = pcall(util.JSONToTable, raw, false, true)
    return (ok and istable(t)) and t or {}
end

local function jsonSave(path, t)
    if not file.Exists(DIR, "DATA") then file.CreateDir(DIR) end
    file.Write(path, util.TableToJSON(t, false) or "{}")
end

local function charKey(v)
    if IsValid(v) and v:IsPlayer() then
        if GRM.Identity and isfunction(GRM.Identity.CharacterKey) then
            return GRM.Identity.CharacterKey(v)
        end
        return tostring(v:SteamID64()) .. ":char1"
    end
    return tostring(v or "")
end

local function rpName(ply)
    if not IsValid(ply) then return "?" end
    local n = ply:GetNWString("GRM_RPName", "")
    if n == "" then n = ply:Nick() end
    return n
end

function P.CanOfficial(ply)
    if not IsValid(ply) then return false end
    if ply:IsSuperAdmin() then return true end
    if GRM.Wanted and isfunction(GRM.Wanted.CanView) and GRM.Wanted.CanView(ply) then return true end
    local f = string.lower(ply:GetNWString("GRM_Faction", ""))
    if f == "" then return false end
    return string.find(f, "ordnung", 1, true)
        or string.find(f, "polizei", 1, true)
        or string.find(f, "полиц", 1, true)
        or string.find(f, "жандарм", 1, true)
        or string.find(f, "feldgendarmerie", 1, true)
        or string.find(f, "военн", 1, true)
        or string.find(f, "journalist", 1, true)
        or string.find(f, "журнал", 1, true)
end

if SERVER then
    util.AddNetworkString("GRM_Photo_Capture")
    util.AddNetworkString("GRM_Photo_Upload")
    util.AddNetworkString("GRM_Photo_List")
    util.AddNetworkString("GRM_Photo_Get")
    util.AddNetworkString("GRM_Photo_Blob")
    util.AddNetworkString("GRM_Photo_Mail")
    util.AddNetworkString("GRM_Photo_MailList")
    util.AddNetworkString("GRM_Photo_Print")
    util.AddNetworkString("GRM_Photo_OpenUI")
    util.AddNetworkString("GRM_Photo_Notify")

    P.Index = P.Index or jsonLoad(IDX)
    P.Mail = P.Mail or jsonLoad(MAIL)

    local function saveAll()
        jsonSave(IDX, P.Index)
        jsonSave(MAIL, P.Mail)
    end

    local function notify(ply, msg, ok)
        if not IsValid(ply) then return end
        net.Start("GRM_Photo_Notify")
            net.WriteString(tostring(msg or ""))
            net.WriteBool(ok and true or false)
        net.Send(ply)
    end

    local function albumOf(sid)
        local out = {}
        for _, rec in ipairs(P.Index) do
            if rec.owner == sid then out[#out + 1] = rec end
        end
        return out
    end

    local function findPhoto(id)
        id = tostring(id or "")
        for _, rec in ipairs(P.Index) do
            if rec.id == id then return rec end
        end
    end

    function P.ReadBytes(id)
        local path = DIR .. "/" .. tostring(id) .. ".jpg"
        if not file.Exists(path, "DATA") then return nil end
        return file.Read(path, "DATA")
    end

    local function sendList(ply)
        local sid = ply:SteamID64()
        local list = {}
        for _, rec in ipairs(albumOf(sid)) do
            list[#list + 1] = {
                id = rec.id, title = rec.title, created = rec.created,
                subject = rec.subject, filter = rec.filter, w = rec.w, h = rec.h,
            }
        end
        net.Start("GRM_Photo_List")
            net.WriteUInt(#list, 8)
            for _, r in ipairs(list) do
                net.WriteString(r.id)
                net.WriteString(r.title or "")
                net.WriteUInt(tonumber(r.created) or 0, 32)
                net.WriteString(r.subject or "")
                net.WriteString(r.filter or "none")
                net.WriteUInt(tonumber(r.w) or 512, 16)
                net.WriteUInt(tonumber(r.h) or 384, 16)
            end
        net.Send(ply)
    end

    local function sendMail(ply, inbox)
        inbox = inbox == "military" and "military" or "civil"
        local rows = {}
        for _, m in ipairs(P.Mail) do
            if m.inbox == inbox then rows[#rows + 1] = m end
        end
        net.Start("GRM_Photo_MailList")
            net.WriteString(inbox)
            net.WriteUInt(math.min(#rows, 60), 8)
            local n = 0
            for i = #rows, 1, -1 do
                local m = rows[i]
                n = n + 1
                if n > 60 then break end
                net.WriteString(tostring(m.id or ""))
                net.WriteString(tostring(m.photoId or ""))
                net.WriteString(tostring(m.fromName or ""))
                net.WriteString(tostring(m.caption or ""))
                net.WriteString(tostring(m.subject or ""))
                net.WriteUInt(tonumber(m.created) or 0, 32)
            end
        net.Send(ply)
    end

    net.Receive("GRM_Photo_Upload", function(_, ply)
        if not IsValid(ply) then return end
        ply._grmPhotoNext = ply._grmPhotoNext or 0
        if CurTime() < ply._grmPhotoNext then return end
        ply._grmPhotoNext = CurTime() + 1.2

        local title = string.sub(net.ReadString() or "", 1, P.Config.MaxTitle)
        local subject = string.sub(net.ReadString() or "", 1, 64)
        local filt = string.sub(net.ReadString() or "none", 1, 16)
        local w = net.ReadUInt(16)
        local h = net.ReadUInt(16)
        local n = net.ReadUInt(16)
        if n <= 0 or n > P.Config.MaxBytes then notify(ply, "Кадр слишком большой.", false) return end
        local data = net.ReadData(n)
        if not data or #data ~= n then notify(ply, "Кадр повреждён.", false) return end

        local sid = ply:SteamID64()
        if #albumOf(sid) >= P.Config.MaxPerPlayer then
            notify(ply, "Альбом полон (макс. " .. P.Config.MaxPerPlayer .. ").", false)
            return
        end

        if title == "" then title = "Кадр " .. os.date("%H:%M:%S") end
        local id = string.format("%08x", tonumber(util.CRC(sid .. SysTime() .. math.random() .. n)) or math.random(1, 0x7fffffff))
        if not file.Exists(DIR, "DATA") then file.CreateDir(DIR) end
        file.Write(DIR .. "/" .. id .. ".jpg", data)

        P.Index[#P.Index + 1] = {
            id = id, owner = sid, ownerName = rpName(ply),
            title = title, subject = subject, filter = filt,
            w = w, h = h, created = os.time(),
        }
        saveAll()

        if GRM.Inventory and GRM.Inventory.AddItem then
            GRM.Inventory.AddItem(ply, "grm_photo", 1, {
                photoId = id, title = title, subject = subject,
            })
        end
        notify(ply, "Снимок сохранён: " .. title, true)
        sendList(ply)
    end)

    net.Receive("GRM_Photo_Get", function(_, ply)
        if not IsValid(ply) then return end
        local id = string.sub(net.ReadString() or "", 1, 16)
        local rec = findPhoto(id)
        if not rec then return end
        local own = rec.owner == ply:SteamID64()
        local mailHit = false
        if not own then
            for _, m in ipairs(P.Mail) do
                if m.photoId == id then mailHit = true break end
            end
        end
        if not (own or mailHit or P.CanOfficial(ply)) then return end
        local bytes = P.ReadBytes(id)
        if not bytes then return end
        net.Start("GRM_Photo_Blob")
            net.WriteString(id)
            net.WriteString(rec.filter or "none")
            net.WriteUInt(#bytes, 16)
            net.WriteData(bytes, #bytes)
        net.Send(ply)
    end)

    net.Receive("GRM_Photo_Mail", function(_, ply)
        if not IsValid(ply) then return end
        if not P.CanOfficial(ply) then notify(ply, "Нет доступа к служебной почте.", false) return end
        local photoId = string.sub(net.ReadString() or "", 1, 16)
        local inbox = net.ReadString() == "military" and "military" or "civil"
        local caption = string.sub(net.ReadString() or "", 1, 180)
        local rec = findPhoto(photoId)
        if not rec then notify(ply, "Фото не найдено.", false) return end
        if rec.owner ~= ply:SteamID64() and not ply:IsSuperAdmin() then
            notify(ply, "Можно отправить только свой снимок.", false)
            return
        end
        if #P.Mail >= P.Config.MaxMail then table.remove(P.Mail, 1) end
        P.Mail[#P.Mail + 1] = {
            id = string.format("m%08x", tonumber(util.CRC(photoId .. os.time())) or os.time()),
            photoId = photoId,
            inbox = inbox,
            from = ply:SteamID64(),
            fromName = rpName(ply),
            caption = caption,
            subject = rec.subject or "",
            created = os.time(),
        }
        saveAll()
        notify(ply, "Снимок ушёл на " .. (inbox == "military" and "компьютер жандармерии" or "компьютер полиции") .. ".", true)
    end)

    net.Receive("GRM_Photo_Print", function(_, ply)
        if not IsValid(ply) then return end
        if not P.CanOfficial(ply) then notify(ply, "Печать ориентировок только со службы.", false) return end
        local photoId = string.sub(net.ReadString() or "", 1, 16)
        local headline = string.sub(net.ReadString() or "", 1, 80)
        local body = string.sub(net.ReadString() or "", 1, 240)
        local rec = findPhoto(photoId)
        if not rec then notify(ply, "Фото не найдено.", false) return end
        if headline == "" then headline = "ВНИМАНИЕ! РОЗЫСК!" end
        if GRM.Inventory and GRM.Inventory.AddItem then
            local left = GRM.Inventory.AddItem(ply, "grm_wanted_poster", 1, {
                photoId = photoId, headline = headline, body = body,
                subject = rec.subject or "",
            })
            if left and left > 0 then notify(ply, "Инвентарь полон.", false) return end
        end
        local ent = ents.Create("grm_wanted_poster")
        if IsValid(ent) then
            ent:SetPos(ply:GetPos() + ply:GetForward() * 40 + Vector(0, 0, 40))
            ent:SetAngles(Angle(0, ply:EyeAngles().y, 0))
            ent:Spawn()
            if ent.SetPosterData then ent:SetPosterData(photoId, headline, body, rec.subject or "") end
        end
        notify(ply, "Лист отпечатан.", true)
    end)

    net.Receive("GRM_Photo_OpenUI", function(_, ply)
        if not IsValid(ply) then return end
        sendList(ply)
        if P.CanOfficial(ply) then
            sendMail(ply, "civil")
            sendMail(ply, "military")
        end
    end)

    function P.AttachTabOpen(ply)
        if not IsValid(ply) then return end
        sendList(ply)
        sendMail(ply, ply.GRM_CompTerminalJur == "military" and "military" or "civil")
    end

    hook.Add("PlayerSay", "GRM_Photo_Cmd", function(ply, text)
        local t = string.Trim(string.lower(text or ""))
        if t == "/фото" or t == "/photo" or t == "/альбом" then
            net.Start("GRM_Photo_OpenUI") net.Send(ply)
            sendList(ply)
            if P.CanOfficial(ply) then
                sendMail(ply, "civil")
                sendMail(ply, "military")
            end
            return ""
        end
    end)

    if GRM.Inventory and GRM.Inventory.RegisterItem then
        GRM.Inventory.RegisterItem("grm_photo", {
            type = "item",
            name = "Фотоснимок",
            desc = "Отпечаток с камеры. «Использовать» — просмотр.",
            icon = "icon16/camera.png",
            maxStack = 1,
            weight = 0.05,
            model = "models/props_lab/frame002a.mdl",
            useFunc = "grm_photo_view",
        })
        GRM.Inventory.RegisterItem("grm_wanted_poster", {
            type = "item",
            name = "Лист розыска",
            desc = "Ориентировка с фото. «Использовать» — развернуть.",
            icon = "icon16/page_error.png",
            maxStack = 5,
            weight = 0.08,
            model = "models/props_junk/garbage_newspaper001a.mdl",
            useFunc = "grm_poster_view",
        })
    end

    if GRM.Inventory and GRM.Inventory.RegisterUseHandler then
        GRM.Inventory.RegisterUseHandler("grm_photo_view", function(ply, slotIdx, slot)
            local id = slot.data and slot.data.photoId
            if not id then return end
            net.Start("GRM_Photo_OpenUI") net.Send(ply)
            sendList(ply)
        end)
        GRM.Inventory.RegisterUseHandler("grm_poster_view", function(ply, slotIdx, slot)
            local d = slot.data or {}
            net.Start("GRM_Photo_Blob")
            -- заголовок без байтов: клиент запросит фото отдельно
            net.WriteString(tostring(d.photoId or ""))
            net.WriteString("poster")
            net.WriteUInt(0, 16)
            net.Send(ply)
            if d.photoId and d.photoId ~= "" then
                timer.Simple(0.05, function()
                    if not IsValid(ply) then return end
                    local bytes = P.ReadBytes(d.photoId)
                    if not bytes then return end
                    net.Start("GRM_Photo_Blob")
                        net.WriteString(d.photoId)
                        net.WriteString("none")
                        net.WriteUInt(#bytes, 16)
                        net.WriteData(bytes, #bytes)
                    net.Send(ply)
                end)
            end
            if GRM.Notify then
                GRM.Notify(ply, (d.headline or "ВНИМАНИЕ! РОЗЫСК!") .. " — " .. tostring(d.subject or ""), 230, 80, 70)
            end
        end)
    end

    print("[GRM Photo] v" .. P.Version .. " server")
end

if CLIENT then
    P.Album = P.Album or {}
    P.MailRows = P.MailRows or {}
    P.Mats = P.Mats or {}

    local function cacheMat(id, bytes)
        if not id or not bytes or bytes == "" then return end
        if not file.Exists("grm_photos_cache", "DATA") then file.CreateDir("grm_photos_cache") end
        local path = "grm_photos_cache/" .. id .. ".jpg"
        file.Write(path, bytes)
        P.Mats[id] = Material("data/" .. path, "smooth")
        return P.Mats[id]
    end

    net.Receive("GRM_Photo_Notify", function()
        local msg = net.ReadString()
        local ok = net.ReadBool()
        notification.AddLegacy(msg, ok and NOTIFY_GENERIC or NOTIFY_ERROR, 4)
        surface.PlaySound(ok and "buttons/button15.wav" or "buttons/button10.wav")
    end)

    net.Receive("GRM_Photo_List", function()
        local n = net.ReadUInt(8)
        P.Album = {}
        for i = 1, n do
            P.Album[#P.Album + 1] = {
                id = net.ReadString(),
                title = net.ReadString(),
                created = net.ReadUInt(32),
                subject = net.ReadString(),
                filter = net.ReadString(),
                w = net.ReadUInt(16),
                h = net.ReadUInt(16),
            }
        end
        hook.Run("GRM_PhotoAlbum")
    end)

    net.Receive("GRM_Photo_MailList", function()
        local inbox = net.ReadString()
        local n = net.ReadUInt(8)
        P.MailRows[inbox] = {}
        for i = 1, n do
            P.MailRows[inbox][#P.MailRows[inbox] + 1] = {
                id = net.ReadString(),
                photoId = net.ReadString(),
                fromName = net.ReadString(),
                caption = net.ReadString(),
                subject = net.ReadString(),
                created = net.ReadUInt(32),
            }
        end
        hook.Run("GRM_PhotoMail")
    end)

    net.Receive("GRM_Photo_Blob", function()
        local id = net.ReadString()
        local filt = net.ReadString()
        local n = net.ReadUInt(16)
        if n > 0 then
            local data = net.ReadData(n)
            cacheMat(id, data)
            P.LastFilter = filt
            hook.Run("GRM_PhotoBlob", id, filt)
        end
    end)

    net.Receive("GRM_Photo_Capture", function()
        hook.Run("GRM_PhotoDoCapture")
    end)

    net.Receive("GRM_Photo_OpenUI", function()
        if P.OpenStudio then P.OpenStudio() end
    end)

    function P.RequestBlob(id)
        if not id or id == "" then return end
        net.Start("GRM_Photo_Get")
            net.WriteString(id)
        net.SendToServer()
    end

    function P.SendMail(photoId, inbox, caption)
        net.Start("GRM_Photo_Mail")
            net.WriteString(photoId or "")
            net.WriteString(inbox or "civil")
            net.WriteString(caption or "")
        net.SendToServer()
    end

    function P.PrintPoster(photoId, headline, body)
        net.Start("GRM_Photo_Print")
            net.WriteString(photoId or "")
            net.WriteString(headline or "ВНИМАНИЕ! РОЗЫСК!")
            net.WriteString(body or "")
        net.SendToServer()
    end

    local function drawPreview(id, x, y, w, h, filter)
        local mat = P.Mats[id]
        if mat and not mat:IsError() then
            if filter == "mono" then
                surface.SetDrawColor(180, 180, 180, 255)
            elseif filter == "contrast" then
                surface.SetDrawColor(255, 255, 255, 255)
            else
                surface.SetDrawColor(255, 255, 255, 255)
            end
            surface.SetMaterial(mat)
            surface.DrawTexturedRect(x, y, w, h)
            if filter == "mono" then
                surface.SetDrawColor(0, 0, 0, 70)
                surface.DrawRect(x, y, w, h)
            end
        else
            surface.SetDrawColor(20, 24, 32, 255)
            surface.DrawRect(x, y, w, h)
            draw.SimpleText("нет кадра", "DermaDefault", x + w / 2, y + h / 2, Color(160, 170, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        if filter == "stamp" or filter == "wanted" then
            surface.SetDrawColor(180, 30, 30, 40)
            surface.DrawRect(x, y, w, 28)
            draw.SimpleText("ВНИМАНИЕ! РОЗЫСК!", "DermaDefaultBold", x + w / 2, y + 14, Color(230, 50, 40), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end
    P.DrawPreview = drawPreview

    function P.OpenStudio()
        if IsValid(P._frame) then P._frame:Remove() end
        local fr = vgui.Create("DFrame")
        P._frame = fr
        fr:SetSize(820, 560)
        fr:Center()
        fr:SetTitle("")
        fr:MakePopup()
        fr.Paint = function(_, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(16, 20, 28, 248))
            draw.SimpleText("СЛУЖЕБНЫЙ АЛЬБОМ / КОРРЕСПОНДЕНЦИЯ", "DermaDefaultBold", 14, 14, Color(230, 80, 70), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end

        local list = vgui.Create("DListView", fr)
        list:SetPos(12, 36)
        list:SetSize(280, 400)
        list:AddColumn("Снимок")
        list:AddColumn("Объект")

        local function refill()
            list:Clear()
            for _, r in ipairs(P.Album or {}) do
                local line = list:AddLine(r.title or r.id, r.subject ~= "" and r.subject or "—")
                line._id = r.id
                line._rec = r
            end
        end
        refill()

        local preview = vgui.Create("DPanel", fr)
        preview:SetPos(304, 36)
        preview:SetSize(500, 300)
        local curId, curFilt = "", "none"
        preview.Paint = function(_, w, h)
            drawPreview(curId, 0, 0, w, h, curFilt)
        end

        list.OnRowSelected = function(_, _, line)
            if not line or not line._id then return end
            curId = line._id
            curFilt = line._rec and line._rec.filter or "none"
            P.RequestBlob(curId)
        end

        hook.Add("GRM_PhotoAlbum", "GRM_PhotoStudio", function()
            if IsValid(list) then refill() end
        end)
        hook.Add("GRM_PhotoBlob", "GRM_PhotoStudio", function()
            if IsValid(preview) then preview:InvalidateLayout() end
        end)

        local cap = vgui.Create("DTextEntry", fr)
        cap:SetPos(304, 344)
        cap:SetSize(500, 26)
        cap:SetPlaceholderText("Подпись к письму / ориентировке…")

        local head = vgui.Create("DTextEntry", fr)
        head:SetPos(304, 376)
        head:SetSize(500, 26)
        head:SetValue("ВНИМАНИЕ! РОЗЫСК!")

        local function selId()
            local i = list:GetSelectedLine()
            local row = i and list:GetLine(i)
            return row and row._id
        end

        local function mk(x, y, w, txt, col, fn)
            local b = vgui.Create("DButton", fr)
            b:SetPos(x, y) b:SetSize(w, 30)
            b:SetText(txt) b:SetTextColor(color_white)
            b.Paint = function(s, bw, bh)
                draw.RoundedBox(4, 0, 0, bw, bh, s:IsHovered() and col or Color(col.r * 0.7, col.g * 0.7, col.b * 0.7))
            end
            b.DoClick = fn
            return b
        end

        mk(12, 448, 280, "На полицейский ПК", Color(50, 110, 190), function()
            local id = selId()
            if not id then return end
            P.SendMail(id, "civil", cap:GetValue())
        end)
        mk(12, 484, 280, "На ПК жандармерии", Color(140, 90, 40), function()
            local id = selId()
            if not id then return end
            P.SendMail(id, "military", cap:GetValue())
        end)
        mk(304, 448, 240, "Печать РОЗЫСК", Color(180, 40, 40), function()
            local id = selId()
            if not id then return end
            P.PrintPoster(id, head:GetValue(), cap:GetValue())
        end)
        mk(556, 448, 248, "Проявка: ч/б", Color(70, 70, 80), function()
            curFilt = curFilt == "mono" and "none" or "mono"
        end)
        mk(304, 484, 240, "Штамп РОЗЫСК", Color(160, 50, 40), function()
            curFilt = "stamp"
        end)
        mk(556, 484, 248, "Закрыть", Color(50, 55, 65), function() fr:Close() end)

        local mail = vgui.Create("DListView", fr)
        mail:SetPos(12, 518)
        mail:SetSize(796, 32)
        mail:AddColumn("Входящие (откройте терминал для полного ящика)")
        for _, box in pairs(P.MailRows or {}) do
            for _, m in ipairs(box) do
                mail:AddLine((m.fromName or "?") .. " — " .. (m.caption or ""))
            end
        end
    end

    function P.AttachTab(tabs)
        if not IsValid(tabs) then return end
        local pnl = vgui.Create("DPanel", tabs)
        pnl.Paint = function(_, w, h) draw.RoundedBox(6, 0, 0, w, h, Color(25, 34, 50, 245)) end

        local list = vgui.Create("DListView", pnl)
        list:Dock(LEFT)
        list:SetWide(340)
        list:DockMargin(10, 10, 8, 10)
        list:AddColumn("От кого")
        list:AddColumn("Объект")
        list:AddColumn("Подпись")

        local right = vgui.Create("DPanel", pnl)
        right:Dock(FILL)
        right:DockMargin(0, 10, 10, 10)
        local cur = ""
        right.Paint = function(_, w, h)
            drawPreview(cur, 0, 0, w, math.max(120, h - 90), "stamp")
        end

        local function fill()
            list:Clear()
            local jur = GRM_CompTerminal_ActiveJur == "military" and "military" or "civil"
            for _, m in ipairs(P.MailRows[jur] or {}) do
                local line = list:AddLine(m.fromName or "?", m.subject or "—", m.caption or "")
                line._pid = m.photoId
            end
        end
        fill()
        hook.Add("GRM_PhotoMail", "GRM_PhotoTab", function() if IsValid(list) then fill() end end)

        list.OnRowSelected = function(_, _, line)
            if line and line._pid then
                cur = line._pid
                P.RequestBlob(cur)
            end
        end

        local btn = vgui.Create("DButton", right)
        btn:Dock(BOTTOM)
        btn:SetTall(32)
        btn:SetText("Печать выбранного — ВНИМАНИЕ! РОЗЫСК!")
        btn:SetTextColor(color_white)
        btn.Paint = function(s, w, h)
            draw.RoundedBox(4, 0, 0, w, h, s:IsHovered() and Color(200, 50, 50) or Color(150, 35, 35))
        end
        btn.DoClick = function()
            if cur == "" then return end
            P.PrintPoster(cur, "ВНИМАНИЕ! РОЗЫСК!", "")
        end

        local btn2 = vgui.Create("DButton", right)
        btn2:Dock(BOTTOM)
        btn2:SetTall(28)
        btn2:SetText("Открыть личный альбом")
        btn2.DoClick = function() P.OpenStudio() end

        net.Start("GRM_Photo_OpenUI") net.SendToServer()
        tabs:AddSheet("Фото и почта", pnl, "icon16/camera.png")
    end

    print("[GRM Photo] client")
end
