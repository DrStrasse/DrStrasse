TOOL.Category = "GRM"
TOOL.Name = "Торгаш (Vendor)"
TOOL.Command = nil
TOOL.ConfigName = ""

TOOL.ClientConVar = {
    type = "weapon",
}

local VENDOR_TYPES = { "weapon", "ore", "food", "rare" }
local MODELS = { weapon = "models/mossman.mdl", ore = "models/kleiner.mdl", food = "models/barney.mdl", rare = "models/gman_high.mdl" }

if CLIENT then
    language.Add("tool.grm_vendor.name", "GRM Vendor Tool")
    language.Add("tool.grm_vendor.desc", "Спавн и настройка торгашей: оружие / руда / еда / редкости")
    language.Add("tool.grm_vendor.0", "ЛКМ: Поставить торгаша. ПКМ: Настроить существующего. R: Удалить.")
end

function TOOL:LeftClick(tr)
    if not tr.Hit then return false end
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not ply:IsSuperAdmin() then return false end

    local vtype = self:GetClientInfo("type")
    if not table.HasValue(VENDOR_TYPES, vtype) then vtype = "weapon" end

    local ent = ents.Create("grm_vendor")
    if not IsValid(ent) then return false end

    ent:SetPos(tr.HitPos + tr.HitNormal * 8)
    ent:SetAngles(Angle(0, ply:EyeAngles().y + 180, 0))
    ent.VendorType = vtype
    ent:SetModel(MODELS[vtype] or "models/kleiner.mdl")
    ent:Spawn()
    ent:Activate()

    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end

    ply:ChatPrint("[GRM Vendor] Поставлен: "..vtype..". Наведись и введи /permadd чтобы закрепить на карте.")
    return true
end

function TOOL:RightClick(tr)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not ply:IsSuperAdmin() then return false end

    local ent = tr.Entity
    if not IsValid(ent) or ent:GetClass() ~= "grm_vendor" then return false end

    self:OpenConfigPanel(ply, ent)
    return true
end

function TOOL:Reload(tr)
    if CLIENT then return true end
    local ply = self:GetOwner()
    if not ply:IsSuperAdmin() then return false end
    local ent = tr.Entity
    if not IsValid(ent) or ent:GetClass() ~= "grm_vendor" then return false end
    ent:Remove()
    ply:ChatPrint("[GRM Vendor] Удалён.")
    return true
end

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
        if not ply:IsSuperAdmin() then return end
        local ent = net.ReadEntity()
        if not IsValid(ent) or ent:GetClass() ~= "grm_vendor" then return end
        ent.CustomPrices = net.ReadTable() or {}
        ent.CustomLimits = net.ReadTable() or {}
        ply:ChatPrint("[GRM Vendor] Настройки сохранены для "..ent.VendorType..". Не забудь /permadd.")
    end)
end

if CLIENT then
    net.Receive("GRM_VendorTool_Config", function()
        local ent = net.ReadEntity()
        local vtype = net.ReadString()
        local customPrices = net.ReadTable() or {}
        local customLimits = net.ReadTable() or {}
        local catalog = net.ReadTable() or {}

        local frame = vgui.Create("DFrame")
        frame:SetTitle("Настройка торгаша: "..vtype)
        frame:SetSize(520, 560)
        frame:Center()
        frame:MakePopup()

        local scroll = vgui.Create("DScrollPanel", frame)
        scroll:Dock(FILL)
        scroll:DockMargin(8, 8, 8, 8)

        for id, item in pairs(catalog) do
            local row = scroll:Add("DPanel")
            row:Dock(TOP)
            row:SetTall(44)
            row:DockMargin(0, 0, 0, 4)

            row.Paint = function(_, w, h)
                draw.RoundedBox(4, 0, 0, w, h, Color(34, 36, 44, 240))
                draw.SimpleText(item.name, "DermaDefaultBold", 8, 4, color_white)
                draw.SimpleText("Базовая: "..GRM.Format(item.price), "DermaDefault", 8, 24, Color(180, 185, 195))
            end

            local priceEntry = vgui.Create("DNumberWang", row)
            priceEntry:SetPos(280, 4)
            priceEntry:SetSize(100, 24)
            priceEntry:SetMin(0)
            priceEntry:SetMax(10000000)
            priceEntry:SetValue(customPrices[id] or item.price)

            local limitEntry = vgui.Create("DNumberWang", row)
            limitEntry:SetPos(390, 4)
            limitEntry:SetSize(80, 24)
            limitEntry:SetMin(0)
            limitEntry:SetMax(100)
            limitEntry:SetValue(customLimits[id] or 0)

            local lbl1 = vgui.Create("DLabel", row)
            lbl1:SetPos(280, 26)
            lbl1:SetSize(100, 16)
            lbl1:SetText("Цена (0 = база)")
            lbl1:SetTextColor(Color(180, 185, 195))

            local lbl2 = vgui.Create("DLabel", row)
            lbl2:SetPos(390, 26)
            lbl2:SetSize(80, 16)
            lbl2:SetText("Лимит (0 = нет)")
            lbl2:SetTextColor(Color(180, 185, 195))

            row._id = id
            row._priceEntry = priceEntry
            row._limitEntry = limitEntry
        end

        local save = vgui.Create("DButton", frame)
        save:Dock(BOTTOM)
        save:SetTall(34)
        save:DockMargin(8, 4, 8, 8)
        save:SetText("Сохранить настройки")
        save.DoClick = function()
            local outPrices, outLimits = {}, {}
            for _, row in ipairs(scroll:GetChildren()) do
                if row._id then
                    local p = row._priceEntry:GetValue()
                    local l = row._limitEntry:GetValue()
                    if p and p ~= GRM.Vendor.GetCatalog(vtype)[row._id].price then outPrices[row._id] = math.floor(p) end
                    if l and l > 0 then outLimits[row._id] = math.floor(l) end
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

    function TOOL.BuildCPanel(CPanel)
        CPanel:AddControl("Header", { Description = "Торгаш: спавн/настройка/удаление" })

        local combo = vgui.Create("DComboBox", CPanel)
        combo:SetValue("Тип: Оружие")
        combo:AddChoice("Оружие", "weapon")
        combo:AddChoice("Руда", "ore")
        combo:AddChoice("Еда", "food")
        combo:AddChoice("Редкости", "rare")
        combo.OnSelect = function(_, _, val, data)
            RunConsoleCommand("grm_vendor_type", data)
        end
        CPanel:AddItem(combo)

        CPanel:Help("ЛКМ — поставить торгаша выбранного типа\nПКМ — настроить цены/лимиты у существующего\nR — удалить торгаша\n/permadd — закрепить на карте (переживёт рестарт)")
    end
end