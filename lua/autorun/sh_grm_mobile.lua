--[[--------------------------------------------------------------------
    GRM Mobile v2.0.0 — мобильные телефоны (упрощённая версия)
    
    ПРЕДМЕТ: телефон добавляется в инвентарь через /phoneshop
    УПРАВЛЕНИЕ: /mobile или кнопка в C-меню
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Mobile = GRM.Mobile or {}
local MB = GRM.Mobile

MB.DataFile = "grm_mobile.json"
MB.SmsCap = 40
MB.ContactsCap = 50
MB.NotesCap = 30

-- ТИЕРЫ телефонов
MB.Tiers = {
    crappy = {
        item = "mobile_crappy",
        name = "Badger Crappy",
        model = "models/props_junk/popcan01a.mdl",
        price = 700,
        desc = "Дешёвая трубка. Только звонки.",
    },
    badger = {
        item = "mobile_badger",
        name = "Badger Classic",
        model = "models/props_junk/popcan01a.mdl",
        price = 1800,
        desc = "Рабочая лошадка: звонки, SMS, контакты.",
    },
    touch = {
        item = "mobile_touch",
        name = "Badger Touch",
        model = "models/props_junk/popcan01a.mdl",
        price = 3500,
        desc = "Сенсорный: звонки, SMS, контакты, заметки.",
    },
    smartphone = {
        item = "mobile_smartphone",
        name = "Smartphone",
        model = "models/props_junk/popcan01a.mdl",
        price = 6500,
        desc = "Смартфон: все функции.",
    },
}

-- Регистрация предметов в инвентаре
if SERVER then
    local function registerPhones()
        if not (GRM.Inventory and GRM.Inventory.RegisterItem) then return end
        
        for tierKey, tier in pairs(MB.Tiers) do
            GRM.Inventory.RegisterItem(tier.item, {
                type = "item",
                name = "Телефон: " .. tier.name,
                desc = tier.desc,
                icon = "icon16/phone.png",
                maxStack = 1,
                weight = 0.35,
                model = tier.model,
                useFunc = "mobile_use",
            })
        end
    end
    
    registerPhones()
    timer.Simple(2, registerPhones)
    
    -- Обработчик использования телефона
    GRM.Inventory.RegisterUseHandler("mobile_use", function(ply, slotIdx, slot, def)
        net.Start("GRM_Mobile_Open")
        net.Send(ply)
    end)
    
    print("[GRM Mobile] v2.0.0 loaded")
end

-- Клиентская часть
if CLIENT then
    surface.CreateFont("GRMMobile_Title", {font = "Roboto", size = 20, weight = 700, extended = true})
    surface.CreateFont("GRMMobile_Normal", {font = "Roboto", size = 14, weight = 500, extended = true})
    
    local CUI = {
        bg = Color(20, 20, 30, 250),
        panel = Color(40, 40, 50, 240),
        accent = Color(70, 155, 255),
        text = Color(240, 240, 240),
    }
    
    net.Receive("GRM_Mobile_Open", function()
        local frame = vgui.Create("DFrame")
        frame:SetTitle("Мобильный телефон")
        frame:SetSize(400, 500)
        frame:Center()
        frame:MakePopup()
        
        local scroll = vgui.Create("DScrollPanel", frame)
        scroll:Dock(FILL)
        scroll:DockMargin(8, 30, 8, 8)
        
        -- Главное меню
        local function addAppButton(name, icon)
            local btn = vgui.Create("DButton", scroll)
            btn:Dock(TOP)
            btn:SetTall(50)
            btn:DockMargin(0, 0, 0, 4)
            btn:SetText("")
            btn.Paint = function(self, w, h)
                draw.RoundedBox(6, 0, 0, w, h, CUI.panel)
                draw.SimpleText(name, "GRMMobile_Normal", 60, h/2, CUI.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
        end
        
        addAppButton("Телефон", "")
        addAppButton("SMS", "💬")
        addAppButton("Контакты", "👥")
        addAppButton("Заметки", "📝")
    end)
    
    -- Команда /mobile
    hook.Add("PlayerSay", "GRM_Mobile_Command", function(ply, text)
        if string.lower(string.Trim(text)) == "/mobile" then
            net.Start("GRM_Mobile_Open")
            net.SendToServer()
            return ""
        end
    end)
end
