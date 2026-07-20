--[[--------------------------------------------------------------------
    GRM Vendor Toolgun v1.2 (Код 111)
    Исправления:
    - Консольная команда: grm_vendor_tool_type (имя тула + имя конвара)
    - Undo: регистрация удаления для клавиши Z
    - Reload: корректный trace + проверка IsSuperAdmin
----------------------------------------------------------------------]]

TOOL.Category   = "GRM"
TOOL.Name       = "#tool.grm_vendor_tool.name"
TOOL.Command    = nil
TOOL.ConfigName = ""

-- ВАЖНО: GMod создаёт консольные команды по паттерну:
--   grm_<имя_тула>_<имя_конвара>
-- Для ClientConVar.type в tool grm_vendor_tool → grm_vendor_tool_type
TOOL.ClientConVar = {
    type = "weapon",
}

local VENDOR_TYPES = { "weapon", "ore", "food", "rare" }
local VENDOR_LABELS = {
    weapon = "Оружие",
    ore    = "Руда",
    food   = "Еда",
    rare   = "Редкости",
}

-- ========== ЛОКАЛИЗАЦИЯ ==========
if CLIENT then
    language.Add("tool.grm_vendor_tool.name",  "GRM Торгаш")
    language.Add("tool.grm_vendor_tool.desc",  "Спавн и настройка торгашей: оружие / руда / еда / редкости")
    language.Add("tool.grm_vendor_tool.0",     "ЛКМ: Поставить. ПКМ: Настроить. R: Удалить. Z: Отмена.")
    language.Add("tool.grm_vendor_tool.1",     "ЛКМ: Поставить. ПКМ: Настроить. R: Удалить. Z: Отмена.")
end

-- ========== ЛЕВЫЙ КЛИК: СПАВН ==========
function TOOL:LeftClick(tr)
    if not tr.Hit then return false end
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsSuperAdmin() then
        GRM.Notify(ply, "Только суперадмин!", 255, 100, 100)
        return false
    end

    -- Получаем тип из конвара (правильное имя: grm_vendor_tool_type)
    local vtype = self:GetClientInfo("type")
    if not vtype or vtype == "" then vtype = "weapon" end
    if not table.HasValue(VENDOR_TYPES, vtype) then vtype = "weapon" end

    local ent = ents.Create("grm_vendor")
    if not IsValid(ent) then return false end

    -- Правильное позиционирование: ставим на землю, не в воздух
    local spawnPos = tr.HitPos
    if tr.HitNormal.z > 0.7 then -- горизонтальная поверхность
        spawnPos = spawnPos + tr.HitNormal * 1 -- минимальный отступ
    end
    ent:SetPos(spawnPos)
    ent:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
    ent.VendorType = vtype
    local V = GRM.Vendor
    ent:SetModel((V and V.Models and V.Models[vtype]) or "models/kleiner.mdl")
    ent:Spawn()
    ent:Activate()

    -- Физика: заморозить на месте
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
        phys:Sleep()
    end

    -- Регистрация UNDO (клавиша Z)
    undo.Create("GRM_Vendor")
        undo.AddEntity(ent)
        undo.SetPlayer(ply)
    undo.Finish()

    ply:ChatPrint("[GRM Vendor] Поставлен: " .. (VENDOR_LABELS[vtype] or vtype) .. ". Наведись и введи /permadd чтобы закрепить на карте.")
    return true
end

-- ========== ПРАВЫЙ КЛИК: НАСТРОЙКА ==========
function TOOL:RightClick(tr)
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsSuperAdmin() then return false end

    local ent = tr.Entity
    if not IsValid(ent) or ent:GetClass() ~= "grm_vendor" then
        GRM.Notify(ply, "Наведи на торгаша!", 255, 100, 100)
        return false
    end

    self:OpenConfigPanel(ply, ent)
    return true
end

-- ========== РЕЛОАД (R): УДАЛЕНИЕ ==========
function TOOL:Reload(tr)
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsSuperAdmin() then return false end

    -- Получаем entity из trace
    local ent = tr.Entity
    if not IsValid(ent) then
        -- Фолбэк: ищем ближайшего торгаша в прицеле
        ent = ply:GetEyeTrace().Entity
    end
    if not IsValid(ent) or ent:GetClass() ~= "grm_vendor" then
        GRM.Notify(ply, "Наведи на торгаша!", 255, 100, 100)
        return false
    end

    local vtype = ent.VendorType or "weapon"
    ent:Remove()

    ply:ChatPrint("[GRM Vendor] Удалён: " .. (VENDOR_LABELS[vtype] or vtype) .. ".")
    return true
end

-- ========== СЕРВЕРНАЯ ЧАСТЬ ==========
if SERVER then
    util.AddNetworkString("GRM_VendorTool_Config")

    function TOOL:OpenConfigPanel(ply, ent)
        net.Start("GRM_VendorTool_Config")
            net.WriteEntity(ent)
            net.WriteString(ent.VendorType or "weapon")
            net.WriteTable(ent.CustomPrices or {})
            net.WriteTable(ent.CustomLimits or {})
            net.WriteTable(GRM.Vendor.GetCatalog(ent.VendorType))
        net.Send(ply)
    end

    net.Receive("GRM_VendorTool_Config", function(_, ply)
        if not IsValid(ply) or not ply:IsSuperAdmin() then return end

        local ent = net.ReadEntity()
        if not IsValid(ent) or ent:GetClass() ~= "grm_vendor" then return end

        ent.CustomPrices = net.ReadTable() or {}
        ent.CustomLimits = net.ReadTable() or {}

        ply:ChatPrint("[GRM Vendor] Настройки сохранены для " .. (ent.VendorType or "?") .. ". Не забудь /permadd.")
    end)
end

-- ========== КЛИЕНТСКАЯ ЧАСТЬ: ПАНЕЛЬ НАСТРОЙКИ ==========
if CLIENT then
    net.Receive("GRM_VendorTool_Config", function()
        local ent          = net.ReadEntity()
        local vtype        = net.ReadString()
        local customPrices = net.ReadTable() or {}
        local customLimits = net.ReadTable() or {}
        local catalog      = net.ReadTable() or {}

        local frame = vgui.Create("DFrame")
        frame:SetTitle("Настройка торгаша: " .. (VENDOR_LABELS[vtype] or vtype))
        frame:SetSize(560, 580)
        frame:Center()
        frame:MakePopup()

        local scroll = vgui.Create("DScrollPanel", frame)
        scroll:Dock(FILL)
        scroll:DockMargin(8, 36, 8, 8)

        for id, item in pairs(catalog) do
            local row = scroll:Add("DPanel")
            row:Dock(TOP)
            row:SetTall(50)
            row:DockMargin(0, 0, 0, 4)

            row.Paint = function(_, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(34, 36, 44, 240))
                draw.SimpleText(item.name, "DermaDefaultBold", 8, 6, color_white)
                draw.SimpleText("Базовая: " .. (GRM.Format and GRM.Format(item.price) or item.price), "DermaDefault", 8, 26, Color(180, 185, 195))
            end

            local priceEntry = vgui.Create("DNumberWang", row)
            priceEntry:SetPos(300, 8)
            priceEntry:SetSize(110, 24)
            priceEntry:SetMin(0)
            priceEntry:SetMax(10000000)
            priceEntry:SetDecimals(0)
            priceEntry:SetValue(customPrices[id] or item.price)

            local limitEntry = vgui.Create("DNumberWang", row)
            limitEntry:SetPos(420, 8)
            limitEntry:SetSize(70, 24)
            limitEntry:SetMin(0)
            limitEntry:SetMax(100)
            limitEntry:SetDecimals(0)
            limitEntry:SetValue(customLimits[id] or 0)

            local lbl1 = vgui.Create("DLabel", row)
            lbl1:SetPos(300, 30)
            lbl1:SetSize(110, 16)
            lbl1:SetText("Цена (0 = база)")
            lbl1:SetFont("DermaDefault")
            lbl1:SetTextColor(Color(180, 185, 195))

            local lbl2 = vgui.Create("DLabel", row)
            lbl2:SetPos(420, 30)
            lbl2:SetSize(80, 16)
            lbl2:SetText("Лимит (0=∞)")
            lbl2:SetFont("DermaDefault")
            lbl2:SetTextColor(Color(180, 185, 195))

            row._id         = id
            row._priceEntry = priceEntry
            row._limitEntry = limitEntry
        end

        local save = vgui.Create("DButton", frame)
        save:Dock(BOTTOM)
        save:SetTall(36)
        save:DockMargin(8, 4, 8, 8)
        save:SetText("Сохранить настройки")
        save:SetFont("DermaDefaultBold")
        save.DoClick = function()
            local outPrices, outLimits = {}, {}
            for _, row in ipairs(scroll:GetCanvas():GetChildren()) do
                if row._id then
                    local p = row._priceEntry:GetValue()
                    local l = row._limitEntry:GetValue()
                    local basePrice = catalog[row._id] and catalog[row._id].price or 0
                    if p and p ~= basePrice then
                        outPrices[row._id] = math.floor(p)
                    end
                    if l and l > 0 then
                        outLimits[row._id] = math.floor(l)
                    end
                end
            end
            net.Start("GRM_VendorTool_Config")
                net.WriteEntity(ent)
                net.WriteTable(outPrices)
                net.WriteTable(outLimits)
            net.SendToServer()
            frame:Close()
        end
    end)

    -- ========== ПАНЕЛЬ TOOLGUN ==========
    function TOOL.BuildCPanel(CPanel)
        CPanel:AddControl("Header", {
            Description = "GRM Торгаш: спавн / настройка цен и лимитов / удаление"
        })

        -- ВАЖНО: ComboBox должен использовать RunConsoleCommand с ПРАВИЛЬНЫМ именем
        -- grm_vendor_tool + _ + type = grm_vendor_tool_type
        CPanel:AddControl("ComboBox", {
            Label    = "Тип торгаша",
            Options  = {
                ["Оружие"]    = { grm_vendor_tool_type = "weapon" },
                ["Руда"]      = { grm_vendor_tool_type = "ore" },
                ["Еда"]       = { grm_vendor_tool_type = "food" },
                ["Редкости"]  = { grm_vendor_tool_type = "rare" },
            }
        })

        CPanel:Help(
            "ЛКМ — поставить торгаша выбранного типа\n" ..
            "ПКМ — настроить цены/лимиты у существующего\n" ..
            "R — удалить торгаша (навестись)\n" ..
            "Z — отменить последний спавн (Undo)\n" ..
            "/permadd — закрепить на карте (переживёт рестарт)"
        )
    end
end
