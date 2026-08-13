--[[--------------------------------------------------------------------
    GRM Laws System v1.2.0 — единое окно законодательства

    Исправления v1.2.0:
    - НЕ вызываем DFrame:Clear(): он удалял внутреннюю btnClose, после чего
      стандартный DFrame:PerformLayout падал в dframe.lua:246 (NULL Panel -> SetPos).
      Теперь пересоздаётся только вложенный body-панель.
    - /laws открывает окно через клиентский GRM_Laws_Open, а данные идут
      отдельным GRM_Laws_List.
    - Все ответы GRM_Laws_List всегда пишут флаги прав canAdd/canRemove/canEdit.
    - Broadcast обновляет только уже открытые окна, не всплывает всем игрокам.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Laws = GRM.Laws or {}
local LAWS = GRM.Laws

LAWS.ConfigFile = "grm_laws.json"
LAWS.MaxLaws = 100
LAWS.MaxLawLength = 1000

local function jsonT(raw)
    if not raw or raw == "" then return nil end
    local ok, tbl = pcall(util.JSONToTable, raw, false, true)
    if ok and istable(tbl) then return tbl end
    ok, tbl = pcall(util.JSONToTable, raw)
    if ok and istable(tbl) then return tbl end
    return nil
end

local function cleanText(s)
    s = tostring(s or "")
    if string.Trim then s = string.Trim(s) end
    s = s:gsub("\r\n", "\n"):gsub("\r", "\n")
    return s
end

local function normalizeData(tbl)
    local out = {}
    if not istable(tbl) then return out end

    for _, law in ipairs(tbl) do
        if istable(law) then
            local text = cleanText(law.text)
            if text ~= "" then
                out[#out + 1] = {
                    id = math.max(1, math.floor(tonumber(law.id) or (#out + 1))),
                    text = text:sub(1, LAWS.MaxLawLength),
                    author = tostring(law.author or "Система"),
                    date = tostring(law.date or ""),
                    timestamp = tonumber(law.timestamp) or os.time(),
                }
            end
        end
    end

    table.sort(out, function(a, b)
        return (tonumber(a.id) or 0) < (tonumber(b.id) or 0)
    end)

    return out
end

function LAWS.Load()
    if not file.Exists(LAWS.ConfigFile, "DATA") then
        LAWS.Data = {}
        return
    end

    local raw = file.Read(LAWS.ConfigFile, "DATA") or ""
    LAWS.Data = normalizeData(jsonT(raw))
end

function LAWS.Save()
    LAWS.Data = normalizeData(LAWS.Data or {})
    local ok, data = pcall(util.TableToJSON, LAWS.Data, true)
    if ok and data then
        file.Write(LAWS.ConfigFile, data)
        return true
    end
    return false
end

local function nextLawID()
    local maxID = 0
    for _, law in ipairs(LAWS.Data or {}) do
        maxID = math.max(maxID, math.floor(tonumber(law.id) or 0))
    end
    return maxID + 1
end

function LAWS.Add(authorName, text)
    if not LAWS.Data then LAWS.Load() end
    LAWS.Data = normalizeData(LAWS.Data or {})

    text = cleanText(text)
    if #LAWS.Data >= LAWS.MaxLaws then
        return false, "Достигнут лимит законов (" .. LAWS.MaxLaws .. ")"
    end
    if #text < 10 then
        return false, "Текст закона слишком короткий (мин. 10 символов)"
    end
    if #text > LAWS.MaxLawLength then
        return false, "Закон слишком длинный (макс. " .. LAWS.MaxLawLength .. " символов)"
    end

    local law = {
        id = nextLawID(),
        text = text,
        author = tostring(authorName or "Система"),
        date = os.date("%d.%m.%Y %H:%M"),
        timestamp = os.time(),
    }

    table.insert(LAWS.Data, law)
    LAWS.Save()
    return true, law
end

function LAWS.Remove(lawID)
    if not LAWS.Data then LAWS.Load() end
    lawID = math.floor(tonumber(lawID) or 0)

    for i, law in ipairs(LAWS.Data or {}) do
        if tonumber(law.id) == lawID then
            table.remove(LAWS.Data, i)
            LAWS.Save()
            return true
        end
    end

    return false, "Закон не найден"
end

function LAWS.Edit(lawID, newText)
    if not LAWS.Data then LAWS.Load() end
    lawID = math.floor(tonumber(lawID) or 0)
    newText = cleanText(newText)

    if #newText < 10 then
        return false, "Текст закона слишком короткий (мин. 10 символов)"
    end
    if #newText > LAWS.MaxLawLength then
        return false, "Закон слишком длинный (макс. " .. LAWS.MaxLawLength .. " символов)"
    end

    for _, law in ipairs(LAWS.Data or {}) do
        if tonumber(law.id) == lawID then
            law.text = newText
            law.date = os.date("%d.%m.%Y %H:%M") .. " (ред.)"
            law.timestamp = os.time()
            LAWS.Save()
            return true, law
        end
    end

    return false, "Закон не найден"
end

function LAWS.GetAll()
    if not LAWS.Data then LAWS.Load() end
    LAWS.Data = normalizeData(LAWS.Data or {})
    return LAWS.Data or {}
end

if SERVER then
    LAWS.Load()

    util.AddNetworkString("GRM_Laws_Open")
    util.AddNetworkString("GRM_Laws_List")
    util.AddNetworkString("GRM_Laws_Add")
    util.AddNetworkString("GRM_Laws_Remove")
    util.AddNetworkString("GRM_Laws_Edit")
    util.AddNetworkString("GRM_Laws_Refresh")

    local function canPublish(ply)
        if not IsValid(ply) then return false end
        if ply.IsSuperAdmin and ply:IsSuperAdmin() then return true end
        if GRM.FactionEconomy and GRM.FactionEconomy.CanPublishLaws then
            return GRM.FactionEconomy.CanPublishLaws(ply) == true
        end
        return false
    end

    local function canRemoveLaw(ply)
        if not IsValid(ply) then return false end
        if ply.IsSuperAdmin and ply:IsSuperAdmin() then return true end
        if GRM.FactionEconomy and GRM.FactionEconomy.HasAccess then
            return GRM.FactionEconomy.HasAccess(ply, "law_remove") == true
        end
        return false
    end

    local function notify(ply, msg)
        if not IsValid(ply) then return end
        if GRM.Notify then
            GRM.Notify(ply, msg, 220, 220, 120)
        elseif ply.ChatPrint then
            ply:ChatPrint(msg)
        end
    end

    function LAWS.SendList(ply)
        if not IsValid(ply) then return end

        local laws = LAWS.GetAll()
        net.Start("GRM_Laws_List")
            net.WriteUInt(math.min(#laws, 65535), 16)
            for _, law in ipairs(laws) do
                net.WriteUInt(math.max(0, math.min(65535, tonumber(law.id) or 0)), 16)
                net.WriteString(tostring(law.text or ""))
                net.WriteString(tostring(law.author or ""))
                net.WriteString(tostring(law.date or ""))
            end
            net.WriteBool(canPublish(ply))
            net.WriteBool(canRemoveLaw(ply))
            net.WriteBool(canPublish(ply)) -- canEdit = canPublish
        net.Send(ply)
    end

    function LAWS.AskClientOpen(ply)
        if not IsValid(ply) then return end
        net.Start("GRM_Laws_Open")
        net.Send(ply)
    end

    function LAWS.BroadcastUpdate()
        local list = player.GetHumans and player.GetHumans() or player.GetAll()
        for _, ply in ipairs(list or {}) do
            LAWS.SendList(ply)
        end
    end

    hook.Add("PlayerSay", "GRM_Laws_Command", function(ply, text)
        local cmd = string.lower(string.Trim(text or ""))
        if cmd == "/laws" or cmd == "!laws" or cmd == "/закон" or cmd == "/законы" then
            LAWS.AskClientOpen(ply)
            return ""
        end
    end)

    net.Receive("GRM_Laws_Open", function(_, ply)
        LAWS.AskClientOpen(ply)
    end)

    net.Receive("GRM_Laws_Refresh", function(_, ply)
        LAWS.SendList(ply)
    end)

    net.Receive("GRM_Laws_Add", function(_, ply)
        if not canPublish(ply) then
            notify(ply, "[Законы] У вас нет прав для публикации законов.")
            return
        end

        local text = net.ReadString()
        local ok, result = LAWS.Add(ply:Nick(), text)
        if ok then
            notify(ply, "[Законы] Закон #" .. result.id .. " добавлен.")
            LAWS.BroadcastUpdate()
        else
            notify(ply, "[Законы] Ошибка: " .. tostring(result))
        end
    end)

    net.Receive("GRM_Laws_Remove", function(_, ply)
        if not canRemoveLaw(ply) then
            notify(ply, "[Законы] У вас нет прав для удаления законов.")
            return
        end

        local lawID = net.ReadUInt(16)
        local ok, err = LAWS.Remove(lawID)
        if ok then
            notify(ply, "[Законы] Закон #" .. lawID .. " удалён.")
            LAWS.BroadcastUpdate()
        else
            notify(ply, "[Законы] Ошибка: " .. tostring(err))
        end
    end)

    net.Receive("GRM_Laws_Edit", function(_, ply)
        if not canPublish(ply) then
            notify(ply, "[Законы] У вас нет прав для редактирования законов.")
            return
        end

        local lawID = net.ReadUInt(16)
        local newText = net.ReadString()
        local ok, result = LAWS.Edit(lawID, newText)
        if ok then
            notify(ply, "[Законы] Закон #" .. lawID .. " отредактирован.")
            LAWS.BroadcastUpdate()
        else
            notify(ply, "[Законы] Ошибка: " .. tostring(result))
        end
    end)

    print("[GRM] Laws System v1.2.0 loaded (safe DFrame refresh)")
end

if CLIENT then
    surface.CreateFont("GRMLaws_Title", { font = "Roboto", size = 22, weight = 700, extended = true })
    surface.CreateFont("GRMLaws_Normal", { font = "Roboto", size = 14, weight = 500, extended = true })
    surface.CreateFont("GRMLaws_Small", { font = "Roboto", size = 12, weight = 400, extended = true })

    local CUI = {
        bg = Color(19, 24, 33, 248),
        panel = Color(33, 42, 56, 245),
        panel2 = Color(27, 35, 48, 245),
        accent = Color(70, 155, 255),
        green = Color(55, 185, 105),
        red = Color(205, 70, 65),
        yellow = Color(235, 180, 60),
        text = Color(240, 244, 250),
        dim = Color(166, 176, 191),
    }

    local lawsFrame = nil
    local updateTimer = "GRM_Laws_UpdateTimer"
    local lastLaws = {}
    local lastCanAdd, lastCanRemove, lastCanEdit = false, false, false

    local function requestRefresh()
        net.Start("GRM_Laws_Refresh")
        net.SendToServer()
    end

    local function ensureFrame()
        if IsValid(lawsFrame) then return lawsFrame end

        local frame = vgui.Create("DFrame")
        if not IsValid(frame) then return nil end

        lawsFrame = frame
        frame:SetTitle("")
        frame:SetSize(math.min(1400, ScrW() - 80), math.min(900, ScrH() - 80))
        frame:Center()
        frame:MakePopup()
        frame:ShowCloseButton(true)
        frame:SetDeleteOnClose(true)

        frame.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, CUI.bg)
            draw.RoundedBoxEx(8, 0, 0, w, 44, CUI.panel2, true, true, false, false)
            draw.SimpleText("Законы государства", "GRMLaws_Title", 16, 22, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Законов: " .. tostring(#(lastLaws or {})), "GRMLaws_Small", w - 46, 28, CUI.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        frame.OnRemove = function()
            timer.Remove(updateTimer)
            if lawsFrame == frame then lawsFrame = nil end
        end

        timer.Remove(updateTimer)
        timer.Create(updateTimer, 5, 0, function()
            if IsValid(lawsFrame) then
                requestRefresh()
            else
                timer.Remove(updateTimer)
            end
        end)

        return frame
    end

    local function notifyLocal(msg, typ)
        if notification and notification.AddLegacy then
            notification.AddLegacy(msg, typ or NOTIFY_GENERIC, 3)
        else
            chat.AddText(Color(235, 180, 60), msg)
        end
    end

    local function sendAdd(text)
        text = string.Trim(tostring(text or ""))
        if #text < 10 then
            notifyLocal("Текст слишком короткий (мин. 10 символов)", NOTIFY_ERROR)
            return
        end
        net.Start("GRM_Laws_Add")
            net.WriteString(text)
        net.SendToServer()
    end

    local function sendEdit(id, text)
        text = string.Trim(tostring(text or ""))
        if #text < 10 then
            notifyLocal("Текст слишком короткий (мин. 10 символов)", NOTIFY_ERROR)
            return
        end
        net.Start("GRM_Laws_Edit")
            net.WriteUInt(math.max(0, math.min(65535, tonumber(id) or 0)), 16)
            net.WriteString(text)
        net.SendToServer()
    end

    local function rebuildContent(laws, canAdd, canRemove, canEdit)
        local frame = ensureFrame()
        if not IsValid(frame) then return end

        if IsValid(frame._grmLawsBody) then
            frame._grmLawsBody:Remove()
        end

        local body = vgui.Create("DPanel", frame)
        frame._grmLawsBody = body
        body:Dock(FILL)
        body:DockMargin(8, 52, 8, 8)
        body:SetPaintBackground(false)

        if canAdd then
            local btnAdd = vgui.Create("DButton", body)
            btnAdd:Dock(BOTTOM)
            btnAdd:SetTall(40)
            btnAdd:DockMargin(0, 8, 0, 0)
            btnAdd:SetText("")
            btnAdd.Paint = function(self, w, h)
                local col = self:IsHovered() and Color(75, 205, 125) or CUI.green
                draw.RoundedBox(5, 0, 0, w, h, col)
                draw.SimpleText("+ Добавить закон", "GRMLaws_Normal", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            btnAdd.DoClick = function()
                Derma_StringRequest("Добавить закон", "Введите текст закона:", "", sendAdd)
            end
        end

        local scroll = vgui.Create("DScrollPanel", body)
        scroll:Dock(FILL)

        if #laws == 0 then
            local empty = vgui.Create("DLabel", scroll)
            empty:Dock(TOP)
            empty:SetTall(46)
            empty:SetText("Законов пока нет.")
            empty:SetTextColor(CUI.dim)
            empty:SetFont("GRMLaws_Normal")
            return
        end

        for _, law in ipairs(laws) do
            local text = tostring(law.text or "")
            local rowTall = math.max(92, math.min(190, 76 + math.ceil(#text / 120) * 18))

            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP)
            row:SetTall(rowTall)
            row:DockMargin(0, 0, 0, 6)
            row.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, CUI.panel)
            end

            local header = vgui.Create("DLabel", row)
            header:Dock(TOP)
            header:SetTall(24)
            header:DockMargin(12, 8, 12, 0)
            header:SetText(string.format("Закон #%d — %s (%s)", tonumber(law.id) or 0, tostring(law.author or "?"), tostring(law.date or "")))
            header:SetTextColor(CUI.yellow)
            header:SetFont("GRMLaws_Normal")

            local btnsPanel = vgui.Create("DPanel", row)
            btnsPanel:Dock(RIGHT)
            btnsPanel:SetWide((canEdit and canRemove) and 200 or 100)
            btnsPanel:DockMargin(0, 8, 8, 8)
            btnsPanel:SetPaintBackground(false)

            if canEdit then
                local btnEdit = vgui.Create("DButton", btnsPanel)
                btnEdit:Dock(TOP)
                btnEdit:SetTall(32)
                btnEdit:DockMargin(0, 0, 0, 6)
                btnEdit:SetText("")
                btnEdit.Paint = function(self, w, h)
                    local col = self:IsHovered() and Color(90, 175, 255) or CUI.accent
                    draw.RoundedBox(5, 0, 0, w, h, col)
                    draw.SimpleText("Изменить", "GRMLaws_Small", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                btnEdit.DoClick = function()
                    Derma_StringRequest("Редактировать закон #" .. tostring(law.id), "Новый текст закона:", text, function(newText)
                        sendEdit(law.id, newText)
                    end)
                end
            end

            if canRemove then
                local btnDel = vgui.Create("DButton", btnsPanel)
                btnDel:Dock(TOP)
                btnDel:SetTall(32)
                btnDel:SetText("")
                btnDel.Paint = function(self, w, h)
                    local col = self:IsHovered() and Color(225, 90, 85) or CUI.red
                    draw.RoundedBox(5, 0, 0, w, h, col)
                    draw.SimpleText("Удалить", "GRMLaws_Small", w / 2, h / 2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                btnDel.DoClick = function()
                    Derma_Query("Удалить закон #" .. tostring(law.id) .. "?", "Подтверждение", "Да", function()
                        net.Start("GRM_Laws_Remove")
                            net.WriteUInt(math.max(0, math.min(65535, tonumber(law.id) or 0)), 16)
                        net.SendToServer()
                    end, "Нет")
                end
            end

            local textPanel = vgui.Create("DLabel", row)
            textPanel:Dock(FILL)
            textPanel:DockMargin(12, 2, 12, 10)
            textPanel:SetText(text)
            textPanel:SetTextColor(CUI.text)
            textPanel:SetFont("GRMLaws_Small")
            textPanel:SetWrap(true)
            textPanel:SetAutoStretchVertical(true)
        end
    end

    net.Receive("GRM_Laws_Open", function()
        ensureFrame()
        requestRefresh()
    end)

    net.Receive("GRM_Laws_List", function()
        local count = net.ReadUInt(16)
        local laws = {}
        for i = 1, count do
            laws[i] = {
                id = net.ReadUInt(16),
                text = net.ReadString(),
                author = net.ReadString(),
                date = net.ReadString(),
            }
        end

        local canAdd = net.ReadBool()
        local canRemove = net.ReadBool()
        local canEdit = net.ReadBool()

        lastLaws = laws
        lastCanAdd, lastCanRemove, lastCanEdit = canAdd, canRemove, canEdit

        -- Важный контракт: обновления с сервера не должны открывать окно всем.
        -- Окно создаётся только по GRM_Laws_Open; список лишь обновляет уже открытое.
        if IsValid(lawsFrame) then
            rebuildContent(lastLaws, lastCanAdd, lastCanRemove, lastCanEdit)
        end
    end)
end
