include("shared.lua")

local NET_USE     = "GRM_Wardrobe_Use"
local NET_CFG_REQ = "GRM_Wardrobe_CfgReq"
local NET_CFG_GET = "GRM_Wardrobe_CfgGet"
local NET_CFG_SET = "GRM_Wardrobe_CfgSet"

surface.CreateFont("GRMWard_Title",  { font = "Roboto", size = 20, weight = 800, extended = true })
surface.CreateFont("GRMWard_Sub",    { font = "Roboto", size = 15, weight = 600, extended = true })
surface.CreateFont("GRMWard_Normal", { font = "Roboto", size = 13, weight = 500, extended = true })

local C = {
    bg    = Color(20, 24, 32, 252),
    head  = Color(28, 34, 46, 255),
    panel = Color(32, 38, 50, 245),
    acc   = Color(70, 150, 240),
    green = Color(60, 190, 110),
    red   = Color(220, 75, 70),
    yellow= Color(230, 180, 60),
    text  = Color(240, 245, 250),
    dim   = Color(160, 170, 185),
}

-- открытие меню персонажа в режиме «гардероб»
net.Receive(NET_USE, function()
    local payload = net.ReadTable() or {}
    if GRM and GRM.Char and GRM.Char._openFromWardrobe then
        GRM.Char._openFromWardrobe(payload)
    end
end)

-- 3D2D табличка
local matIcon = Material("icon16/user_suit.png")
function ENT:Draw()
    self:DrawModel()
    if LocalPlayer():GetPos():DistToSqr(self:GetPos()) > 300 * 300 then return end
    local ang = self:GetAngles()
    -- табличка строго над шкафом: считаем высоту от габаритов модели
    local maxs = self:OBBMaxs()
    local pos = self:GetPos() + ang:Up() * ((maxs and maxs.z or 60) + 16)
    cam.Start3D2D(pos, Angle(0, LocalPlayer():EyeAngles().y - 90, 90), 0.08)
        draw.RoundedBox(6, -150, -30, 300, 60, Color(16, 20, 28, 220))
        surface.SetDrawColor(70, 150, 240, 230)
        surface.DrawOutlinedRect(-150, -30, 300, 60, 2)
        draw.SimpleText("Гардероб", "GRMWard_Title", 0, -6, Color(240, 245, 250), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText("[E] Сменить внешность", "GRMWard_Normal", 0, 16, Color(160, 170, 185), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end

-----------------------------------------------------------
-- Админ-окно настройки гардероба
-----------------------------------------------------------
local function mkBtn(p, txt, col)
    local b = vgui.Create("DButton", p)
    b:SetText(txt) b:SetFont("GRMWard_Normal") b:SetTextColor(color_white)
    b.Paint = function(self, pw, ph)
        local cc = col or C.acc
        if self:IsHovered() then cc = Color(math.min(255, cc.r + 25), math.min(255, cc.g + 25), math.min(255, cc.b + 25)) end
        draw.RoundedBox(5, 0, 0, pw, ph, cc)
    end
    return b
end

local function openCfgMenu(entIdx, cfg)
    cfg = istable(cfg) and cfg or {}
    if IsValid(_G._grmWardCfgFrame) then _G._grmWardCfgFrame:Remove() end

    local f = vgui.Create("DFrame")
    _G._grmWardCfgFrame = f
    f:SetTitle("")
    f:SetSize(560, 640)
    f:Center()
    f:MakePopup()
    f:ShowCloseButton(false)
    f.Paint = function(_, pw, ph)
        draw.RoundedBox(8, 0, 0, pw, ph, C.bg)
        draw.RoundedBoxEx(8, 0, 0, pw, 40, C.head, true, true, false, false)
        draw.SimpleText("Настройка гардероба (админ)", "GRMWard_Title", 14, 20, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end

    local x = vgui.Create("DButton", f)
    x:SetText("X") x:SetFont("GRMWard_Title") x:SetTextColor(color_white)
    x:SetPos(516, 6) x:SetSize(32, 26)
    x.DoClick = function() f:Close() end
    x.Paint = function(self, pw, ph) draw.RoundedBox(4, 0, 0, pw, ph, self:IsHovered() and C.red or Color(45, 52, 68)) end

    local scroll = vgui.Create("DScrollPanel", f)
    scroll:Dock(FILL) scroll:DockMargin(10, 46, 10, 56)

    local function block(h, title)
        local b = vgui.Create("DPanel", scroll)
        b:Dock(TOP) b:SetTall(h) b:DockMargin(0, 0, 0, 6)
        b.Paint = function(_, pw, ph)
            draw.RoundedBox(6, 0, 0, pw, ph, C.panel)
            draw.SimpleText(title, "GRMWard_Sub", 10, 14, C.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        return b
    end

    local ed = cfg -- редактируемая копия
    ed.extraModels  = istable(ed.extraModels) and ed.extraModels or {}
    ed.hiddenModels = istable(ed.hiddenModels) and ed.hiddenModels or {}

    -- тоглы
    local b1 = block(150, "Что разрешает гардероб:")
    local function chk(parent, y, txt, get, set)
        local c = vgui.Create("DCheckBoxLabel", parent)
        c:SetPos(14, y) c:SetSize(400, 24)
        c:SetText(txt) c:SetFont("GRMWard_Normal") c:SetTextColor(C.text)
        c:SetValue(get() and 1 or 0)
        c.OnChange = function(_, v) set(v) end
    end
    chk(b1, 30,  "Показывать гражданские модели (Гражданская внешность)", function() return ed.allowCivilian ~= false end, function(v) ed.allowCivilian = v end)
    chk(b1, 58,  "Показывать фракционную внешность игрока (личный шкаф фракции)", function() return ed.allowFaction ~= false end, function(v) ed.allowFaction = v end)
    chk(b1, 86,  "Разрешить настройку скинов", function() return ed.allowSkin ~= false end, function(v) ed.allowSkin = v end)
    chk(b1, 114, "Разрешить настройку бодигрупп", function() return ed.allowBodygroups ~= false end, function(v) ed.allowBodygroups = v end)

    -- особые модели
    local b2 = block(220, "Особые модели этого шкафа (показываются всем):")
    local exScroll = vgui.Create("DScrollPanel", b2)
    exScroll:SetPos(10, 28) exScroll:SetSize(390, 184)
    local function rebuildEx()
        exScroll:Clear()
        for i, p in ipairs(ed.extraModels) do
            local row = vgui.Create("DPanel", exScroll)
            row:Dock(TOP) row:SetTall(24) row:DockMargin(0, 0, 0, 2)
            row.Paint = function(_, pw, ph) draw.RoundedBox(4, 0, 0, pw, ph, Color(26, 32, 42)) end
            local lbl = vgui.Create("DLabel", row)
            lbl:Dock(FILL) lbl:DockMargin(8, 0, 0, 0) lbl:SetText(p) lbl:SetFont("GRMWard_Normal") lbl:SetTextColor(C.text)
            local bx = mkBtn(row, "✕", C.red) bx:Dock(RIGHT) bx:SetWide(24) bx:DockMargin(0, 2, 3, 2)
            bx.DoClick = function() table.remove(ed.extraModels, i) rebuildEx() end
        end
    end
    rebuildEx()
    local exEntry = vgui.Create("DTextEntry", b2)
    exEntry:SetPos(406, 28) exEntry:SetSize(140, 24) exEntry:SetPlaceholderText("models/...mdl")
    local bAdd = mkBtn(b2, "Добавить", C.green)
    bAdd:SetPos(406, 56) bAdd:SetSize(140, 24)
    bAdd.DoClick = function()
        local p = string.Trim(exEntry:GetValue() or "")
        if p ~= "" then
            ed.extraModels[#ed.extraModels + 1] = p
            exEntry:SetValue("") rebuildEx()
        end
    end

    -- скрытые модели
    local b3 = block(220, "Скрытые модели (не показываются в этом шкафу):")
    local hdScroll = vgui.Create("DScrollPanel", b3)
    hdScroll:SetPos(10, 28) hdScroll:SetSize(390, 184)
    local function rebuildHd()
        hdScroll:Clear()
        for i, p in ipairs(ed.hiddenModels) do
            local row = vgui.Create("DPanel", hdScroll)
            row:Dock(TOP) row:SetTall(24) row:DockMargin(0, 0, 0, 2)
            row.Paint = function(_, pw, ph) draw.RoundedBox(4, 0, 0, pw, ph, Color(26, 32, 42)) end
            local lbl = vgui.Create("DLabel", row)
            lbl:Dock(FILL) lbl:DockMargin(8, 0, 0, 0) lbl:SetText(p) lbl:SetFont("GRMWard_Normal") lbl:SetTextColor(C.text)
            local bx = mkBtn(row, "✕", C.red) bx:Dock(RIGHT) bx:SetWide(24) bx:DockMargin(0, 2, 3, 2)
            bx.DoClick = function() table.remove(ed.hiddenModels, i) rebuildHd() end
        end
    end
    rebuildHd()
    local hdEntry = vgui.Create("DTextEntry", b3)
    hdEntry:SetPos(406, 28) hdEntry:SetSize(140, 24) hdEntry:SetPlaceholderText("models/...mdl")
    local bHide = mkBtn(b3, "Скрыть", C.red)
    bHide:SetPos(406, 56) bHide:SetSize(140, 24)
    bHide.DoClick = function()
        local p = string.Trim(hdEntry:GetValue() or "")
        if p ~= "" then
            ed.hiddenModels[#ed.hiddenModels + 1] = p
            hdEntry:SetValue("") rebuildHd()
        end
    end

    local bot = vgui.Create("DPanel", f)
    bot:Dock(BOTTOM) bot:SetTall(50) bot:DockMargin(10, 0, 10, 6)
    bot:SetPaintBackground(false)
    local bSave = mkBtn(bot, "Сохранить настройки", C.green)
    bSave:Dock(RIGHT) bSave:SetWide(220) bSave:DockMargin(0, 8, 0, 8)
    bSave:SetFont("GRMWard_Sub")
    bSave.DoClick = function()
        net.Start(NET_CFG_SET)
            net.WriteUInt(entIdx, 16)
            net.WriteTable(ed)
        net.SendToServer()
        f:Close()
    end
    local bCancel = mkBtn(bot, "Отмена", C.acc)
    bCancel:Dock(RIGHT) bCancel:SetWide(120) bCancel:DockMargin(0, 8, 8, 8)
    bCancel:SetFont("GRMWard_Sub")
    bCancel.DoClick = function() f:Close() end
end

net.Receive(NET_CFG_GET, function()
    local entIdx = net.ReadUInt(16)
    local cfg = net.ReadTable() or {}
    openCfgMenu(entIdx, cfg)
end)
