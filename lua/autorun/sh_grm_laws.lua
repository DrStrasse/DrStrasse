--[[--------------------------------------------------------------------
    GRM Laws System v1.0 (Код 123) — Система законодательства
    
    SUPERAADMIN / Лидер с доступом law_publish:
    - /law_add <текст> — добавить закон
    - /law_remove <ID> — удалить закон
    - /law_list — список законов (всем)
    
    ИГРОКИ:
    - Через C-меню → "Законы государства" — просмотр всех законов
    
    Хранение: data/grm_laws.json
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Laws = GRM.Laws or {}
local LAWS = GRM.Laws

LAWS.ConfigFile = "grm_laws.json"
LAWS.MaxLaws = 50
LAWS.MaxLawLength = 500

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

-- Получить все законы
function LAWS.GetAll()
    if not LAWS.Data then LAWS.Load() end
    return LAWS.Data or {}
end

-- Инициализация
if SERVER then
    LAWS.Load()
    
    util.AddNetworkString("GRM_Laws_List")
    util.AddNetworkString("GRM_Laws_Add")
    util.AddNetworkString("GRM_Laws_Remove")
    
    -- Команды
    hook.Add("PlayerSay", "GRM_Laws_Commands", function(ply, text)
        local cmd = string.lower(string.Trim(text or ""))
        
        if cmd == "/law_list" or cmd == "!law_list" or cmd == "/laws" then
            local laws = LAWS.GetAll()
            if #laws == 0 then
                ply:ChatPrint("[Законы] Законов пока нет.")
            else
                ply:ChatPrint("[Законы] Действующие законы:")
                for _, law in ipairs(laws) do
                    ply:ChatPrint(string.format("  #%d [%s] %s — %s", law.id, law.date, law.author, law.text))
                end
            end
            return ""
        end
        
        if string.StartWith(cmd, "/law_add ") or string.StartWith(cmd, "!law_add ") then
            -- Проверка доступа
            if not ply:IsSuperAdmin() and not GRM.FactionPerms.PlayerHasPermission(ply, "law_publish") then
                ply:ChatPrint("[Законы] У вас нет прав для публикации законов.")
                return ""
            end
            
            local lawText = string.sub(text, 10)
            if #lawText < 10 then
                ply:ChatPrint("[Законы] Текст закона слишком короткий (мин. 10 символов).")
                return ""
            end
            
            local ok, result = LAWS.Add(ply:Nick(), lawText)
            if ok then
                ply:ChatPrint("[Законы] Закон добавлен: " .. lawText)
                -- Уведомить всех
                for _, p in ipairs(player.GetAll()) do
                    if IsValid(p) and p ~= ply then
                        p:ChatPrint(string.format("[Законы] Новый закон #%d от %s: %s", result.id, ply:Nick(), lawText))
                    end
                end
            else
                ply:ChatPrint("[Законы] Ошибка: " .. result)
            end
            return ""
        end
        
        if string.StartWith(cmd, "/law_remove ") or string.StartWith(cmd, "!law_remove ") then
            -- Проверка доступа
            if not ply:IsSuperAdmin() and not GRM.FactionPerms.PlayerHasPermission(ply, "law_remove") then
                ply:ChatPrint("[Законы] У вас нет прав для удаления законов.")
                return ""
            end
            
            local lawID = tonumber(string.Explode(" ", cmd)[2])
            if not lawID then
                ply:ChatPrint("[Законы] Использование: /law_remove <ID>")
                return ""
            end
            
            local ok, err = LAWS.Remove(lawID)
            if ok then
                ply:ChatPrint("[Законы] Закон #" .. lawID .. " удалён.")
            else
                ply:ChatPrint("[Законы] Ошибка: " .. err)
            end
            return ""
        end
    end)
    
    -- Сеть для C-меню
    net.Receive("GRM_Laws_List", function(_, ply)
        local laws = LAWS.GetAll()
        net.Start("GRM_Laws_List")
            net.WriteUInt(#laws, 16)
            for _, law in ipairs(laws) do
                net.WriteUInt(law.id, 16)
                net.WriteString(law.text)
                net.WriteString(law.author)
                net.WriteString(law.date)
            end
        net.Send(ply)
    end)
    
    print("[GRM] Laws System loaded (Код 123)")
end

-- Клиентская часть для C-меню
if CLIENT then
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
        
        -- Открываем окно законов
        local frame = vgui.Create("DFrame")
        frame:SetTitle("Законы государства")
        frame:SetSize(600, 500)
        frame:Center()
        frame:MakePopup()
        frame:ShowCloseButton(true)
        
        local scroll = vgui.Create("DScrollPanel", frame)
        scroll:Dock(FILL)
        scroll:DockMargin(8, 30, 8, 8)
        
        if #laws == 0 then
            local label = vgui.Create("DLabel", scroll)
            label:Dock(TOP)
            label:SetTall(30)
            label:SetText("Законов пока нет.")
            label:SetTextColor(Color(200, 200, 200))
            label:SetFont("DermaDefault")
            return
        end
        
        for _, law in ipairs(laws) do
            local row = vgui.Create("DPanel", scroll)
            row:Dock(TOP)
            row:SetTall(60)
            row:DockMargin(0, 0, 0, 5)
            
            row.Paint = function(self, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 200))
            end
            
            local header = vgui.Create("DLabel", row)
            header:Dock(TOP)
            header:SetTall(20)
            header:DockMargin(8, 4, 8, 0)
            header:SetText(string.format("Закон #%d — %s (%s)", law.id, law.author, law.date))
            header:SetTextColor(Color(255, 200, 100))
            header:SetFont("DermaDefaultBold")
            
            local text = vgui.Create("DLabel", row)
            text:Dock(FILL)
            text:DockMargin(8, 0, 8, 4)
            text:SetText(law.text)
            text:SetTextColor(Color(255, 255, 255))
            text:SetFont("DermaDefault")
        end
    end)
end
