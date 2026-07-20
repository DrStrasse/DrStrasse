--[[--------------------------------------------------------------------
    GRM Laws System v1.1 (Код 123) — Единое окно законодательства
    
    Одна команда /laws открывает окно со всеми законами:
    - Список всех действующих законов
    - Кнопка "Добавить закон" (для суперадмин/с доступом law_publish)
    - Кнопка "Удалить" рядом с каждым законом (для суперадмин/с доступом law_remove)
    
    Размер окна как у Q-меню (~1000x700)
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Laws = GRM.Laws or {}
local LAWS = GRM.Laws

LAWS.ConfigFile = "grm_laws.json"
LAWS.MaxLaws = 100
LAWS.MaxLawLength = 1000

-- Загрузка законов
function LAWS.Load()
    if not file.Exists(LAWS.ConfigFile, "DATA") then
        LAWS.Data = {}
        return
    end
    
    local data = file.Read(LAWS.ConfigFile, "DATA")
    local ok, tbl = pcall(util.JSONToTable, data)
    if ok and istable(tbl) then
        LAWS.Data = tbl
    else
        LAWS.Data = {}
    end
end

-- Сохранение законов
function LAWS.Save()
    local ok, data = pcall(util.TableToJSON, LAWS.Data or {}, true)
    if ok then
        file.Write(LAWS.ConfigFile, data)
    end
end

-- Добавить закон
function LAWS.Add(authorName, text)
    if not LAWS.Data then LAWS.Load() end
    
    if #LAWS.Data >= LAWS.MaxLaws then
        return false, "Достигнут лимит законов (" .. LAWS.MaxLaws .. ")"
    end
    
    if #text > LAWS.MaxLawLength then
        return false, "Закон слишком длинный (макс. " .. LAWS.MaxLawLength .. " символов)"
    end
    
    local law = {
        id = #LAWS.Data + 1,
        text = text,
        author = authorName,
        date = os.date("%d.%m.%Y %H:%M"),
        timestamp = os.time(),
    }
    
    table.insert(LAWS.Data, law)
    LAWS.Save()
    return true, law
end

-- Удалить закон
function LAWS.Remove(lawID)
    if not LAWS.Data then LAWS.Load() end
    
    for i, law in ipairs(LAWS.Data) do
        if law.id == lawID then
            table.remove(LAWS.Data, i)
            LAWS.Save()
            return true
        end
    end
    
    return false, "Закон не найден"
end

-- Редактировать закон
function LAWS.Edit(lawID, newText)
    if not LAWS.Data then LAWS.Load() end
    
    if #newText > LAWS.MaxLawLength then
        return false, "Закон слишком длинный (макс. " .. LAWS.MaxLawLength .. " символов)"
    end
    
    for _, law in ipairs(LAWS.Data) do
        if law.id == lawID then
            law.text = newText
            law.date = os.date("%d.%m.%Y %H:%M") .. " (ред.)"
            LAWS.Save()
            return true, law
        end
    end
    
    return false, "Закон не найден"
end

-- Получить все законы
function LAWS.GetAll()
    if not LAWS.Data then LAWS.Load() end
    return LAWS.Data or {}
end

-- Инициализация
if SERVER then
    LAWS.Load()
    
    util.AddNetworkString("GRM_Laws_Open")
    util.AddNetworkString("GRM_Laws_List")
    util.AddNetworkString("GRM_Laws_Add")
    util.AddNetworkString("GRM_Laws_Remove")
    util.AddNetworkString("GRM_Laws_Edit")
    
    -- Команда /laws
    hook.Add("PlayerSay", "GRM_Laws_Command", function(ply, text)
        local cmd = string.lower(string.Trim(text or ""))
        
        if cmd == "/laws" or cmd == "!laws" or cmd == "/закон" then
            net.Start("GRM_Laws_Open")
            net.Send(ply)
            return ""
        end
    end)
    
    -- Открыть окно законов
    net.Receive("GRM_Laws_Open", function(_, ply)
        local laws = LAWS.GetAll()
        local canAdd = ply:IsSuperAdmin() or (GRM.FactionEconomy and GRM.FactionEconomy.CanPublishLaws(ply))
        local canRemove = ply:IsSuperAdmin() or (GRM.FactionEconomy and GRM.FactionEconomy.HasAccess(ply, "law_remove"))
        local canEdit = canAdd -- Редактирование = добавление
        
        net.Start("GRM_Laws_List")
            net.WriteUInt(#laws, 16)
            for _, law in ipairs(laws) do
                net.WriteUInt(law.id, 16)
                net.WriteString(law.text)
                net.WriteString(law.author)
                net.WriteString(law.date)
            end
            net.WriteBool(canAdd)
            net.WriteBool(canRemove)
            net.WriteBool(canEdit)
        net.Send(ply)
    end)
    
    -- Добавить закон
    net.Receive("GRM_Laws_Add", function(_, ply)
        -- Проверка доступа
        if not ply:IsSuperAdmin() then
            if not (GRM.FactionEconomy and GRM.FactionEconomy.CanPublishLaws(ply)) then
                ply:ChatPrint("[Законы] У вас нет прав для публикации законов.")
                return
            end
        end
        
        local text = net.ReadString()
        if not text or #text < 10 then
            ply:ChatPrint("[Законы] Текст закона слишком короткий (мин. 10 символов).")
            return
        end
        
        local ok, result = LAWS.Add(ply:Nick(), text)
        if ok then
            ply:ChatPrint("[Законы] Закон #" .. result.id .. " добавлен.")
            -- Обновить окно
            net.Start("GRM_Laws_Open")
            net.Send(ply)
        else
            ply:ChatPrint("[Законы] Ошибка: " .. result)
        end
    end)
    
    -- Удалить закон
    net.Receive("GRM_Laws_Remove", function(_, ply)
        -- Проверка доступа
        if not ply:IsSuperAdmin() then
            if not (GRM.FactionEconomy and GRM.FactionEconomy.HasAccess(ply, "law_remove")) then
                ply:ChatPrint("[Законы] У вас нет прав для удаления законов.")
                return
            end
        end
        
        local lawID = net.ReadUInt(16)
        local ok, err = LAWS.Remove(lawID)
        if ok then
            ply:ChatPrint("[Законы] Закон #" .. lawID .. " удалён.")
            -- Обновить окно
            net.Start("GRM_Laws_Open")
            net.Send(ply)
        else
            ply:ChatPrint("[Законы] Ошибка: " .. err)
        end
    end)
    
    -- Редактировать закон
    net.Receive("GRM_Laws_Edit", function(_, ply)
        -- Проверка доступа
        if not ply:IsSuperAdmin() then
            if not (GRM.FactionEconomy and GRM.FactionEconomy.CanPublishLaws(ply)) then
                ply:ChatPrint("[Законы] У вас нет прав для редактирования законов.")
                return
            end
        end
        
        local lawID = net.ReadUInt(16)
        local newText = net.ReadString()
        
        if not newText or #newText < 10 then
            ply:ChatPrint("[Законы] Текст закона слишком короткий (мин. 10 символов).")
            return
        end
        
        local ok, result = LAWS.Edit(lawID, newText)
        if ok then
            ply:ChatPrint("[Законы] Закон #" .. lawID .. " отредактирован.")
            -- Обновить окно
            net.Start("GRM_Laws_Open")
            net.Send(ply)
        else
            ply:ChatPrint("[Законы] Ошибка: " .. result)
        end
    end)
    
    print("[GRM] Laws System v1.1 loaded (Код 123)")
end

-- Клиентская часть
if CLIENT then
    surface.CreateFont("GRMLaws_Title", {font = "Roboto", size = 22, weight = 700, extended = true})
    surface.CreateFont("GRMLaws_Normal", {font = "Roboto", size = 14, weight = 500, extended = true})
    surface.CreateFont("GRMLaws_Small", {font = "Roboto", size = 12, weight = 400, extended = true})
    
    local CUI = {
        bg = Color(19, 24, 33, 248),
        panel = Color(33, 42, 56, 245),
        accent = Color(70, 155, 255),
        green = Color(55, 185, 105),
        red = Color(205, 70, 65),
        yellow = Color(235, 180, 60),
        text = Color(240, 244, 250),
        dim = Color(166, 176, 191),
    }
    
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
        
        -- Создаём окно (размер как у Q-меню)
        local frame = vgui.Create("DFrame")
        frame:SetTitle("")
        frame:SetSize(1400, 900)
        frame:Center()
        frame:MakePopup()
        frame:ShowCloseButton(true)
        
        frame.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, CUI.bg)
            draw.RoundedBoxEx(8, 0, 0, w, 44, Color(27, 35, 48), true, true, false, false)
            draw.SimpleText("Законы государства", "GRMLaws_Title", 16, 22, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("Законов: " .. #laws, "GRMLaws_Small", w - 16, 22, CUI.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
        
        -- Кнопка добавления (в шапке окна)
        if canAdd then
            local btnAdd = vgui.Create("DButton", frame)
            btnAdd:SetPos(frame:GetWide() - 180, 8)
            btnAdd:SetSize(170, 30)
            btnAdd:SetText("")
            btnAdd.Paint = function(self, w, h)
                local col = self:IsHovered() and Color(75, 205, 125) or CUI.green
                draw.RoundedBox(5, 0, 0, w, h, col)
                draw.SimpleText("+ Добавить закон", "GRMLaws_Normal", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
            btnAdd.DoClick = function()
                Derma_StringRequest("Добавить закон", "Введите текст закона:", "", function(text)
                    if text and #text >= 10 then
                        net.Start("GRM_Laws_Add")
                            net.WriteString(text)
                        net.SendToServer()
                    else
                        notification.AddLegacy("Текст слишком короткий (мин. 10 символов)", NOTIFY_ERROR, 3)
                    end
                end)
            end
        end
        
        -- Список законов
        local scroll = vgui.Create("DScrollPanel", frame)
        scroll:Dock(FILL)
        scroll:DockMargin(8, 52, 8, 8)
        
        if #laws == 0 then
            local label = vgui.Create("DLabel", scroll)
            label:Dock(TOP)
            label:SetTall(40)
            label:SetText("Законов пока нет.")
            label:SetTextColor(CUI.dim)
            label:SetFont("GRMLaws_Normal")
            return
        end
        
        for _, law in ipairs(laws) do
            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP)
            row:SetTall(80)
            row:DockMargin(0, 0, 0, 5)
            
            row.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, CUI.panel)
            end
            
            -- Заголовок
            local header = vgui.Create("DLabel", row)
            header:Dock(TOP)
            header:SetTall(22)
            header:DockMargin(12, 8, 12, 0)
            header:SetText(string.format("Закон #%d — %s (%s)", law.id, law.author, law.date))
            header:SetTextColor(CUI.yellow)
            header:SetFont("GRMLaws_Normal")
            
            -- Текст закона
            local text = vgui.Create("DLabel", row)
            text:Dock(FILL)
            text:DockMargin(12, 0, 12, 8)
            text:SetText(law.text)
            text:SetTextColor(CUI.text)
            text:SetFont("GRMLaws_Small")
            
            -- Кнопки действий (справа)
            local btnsPanel = vgui.Create("DPanel", row)
            btnsPanel:Dock(RIGHT)
            btnsPanel:SetWide(180)
            btnsPanel:DockMargin(0, 8, 8, 8)
            btnsPanel:SetPaintBackground(false)
            
            if canEdit then
                local btnEdit = vgui.Create("DButton", btnsPanel)
                btnEdit:Dock(TOP)
                btnEdit:SetTall(36)
                btnEdit:DockMargin(0, 0, 0, 4)
                btnEdit:SetText("")
                btnEdit.Paint = function(self, w, h)
                    local col = self:IsHovered() and Color(90, 175, 255) or CUI.accent
                    draw.RoundedBox(5, 0, 0, w, h, col)
                    draw.SimpleText("Изменить", "GRMLaws_Normal", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                btnEdit.DoClick = function()
                    Derma_StringRequest("Редактировать закон #" .. law.id, "Новый текст закона:", law.text, function(newText)
                        if newText and #newText >= 10 then
                            net.Start("GRM_Laws_Edit")
                                net.WriteUInt(law.id, 16)
                                net.WriteString(newText)
                            net.SendToServer()
                        else
                            notification.AddLegacy("Текст слишком короткий (мин. 10 символов)", NOTIFY_ERROR, 3)
                        end
                    end)
                end
            end
            
            if canRemove then
                local btnDel = vgui.Create("DButton", btnsPanel)
                btnDel:Dock(TOP)
                btnDel:SetTall(36)
                btnDel:SetText("")
                btnDel.Paint = function(self, w, h)
                    local col = self:IsHovered() and Color(225, 90, 85) or CUI.red
                    draw.RoundedBox(5, 0, 0, w, h, col)
                    draw.SimpleText("Удалить", "GRMLaws_Normal", w/2, h/2, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                end
                btnDel.DoClick = function()
                    Derma_Query("Удалить закон #" .. law.id .. "?", "Подтверждение", "Да", function()
                        net.Start("GRM_Laws_Remove")
                            net.WriteUInt(law.id, 16)
                        net.SendToServer()
                    end, "Нет")
                end
            end
        end
    end)
end
