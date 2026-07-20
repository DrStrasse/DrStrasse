--[[--------------------------------------------------------------------
    GRM Logistics — client UI (Код 40)
----------------------------------------------------------------------]]
if not CLIENT then return end

include("autorun/sh_grm_logistics_config.lua")

GRM=GRM or {}; GRM.Logistics=GRM.Logistics or {}; local L,C=GRM.Logistics,GRM.Logistics.Config

local N={result="GRML_Result",routeMenu="GRML_RouteMenu",routeSync="GRML_RouteSync",loading="GRML_LoadingUI",crate="GRML_CrateUI",crateInv="GRML_CrateInventory",warehouse="GRML_WarehouseUI",armory="GRML_ArmoryUI",admin="GRML_AdminUI",action="GRML_Action"}

surface.CreateFont("GRML_Title",{font="Roboto",size=20,weight=800,extended=true})
surface.CreateFont("GRML_Normal",{font="Roboto",size=14,weight=500,extended=true})
surface.CreateFont("GRML_Small",{font="Roboto",size=12,weight=400,extended=true})

local CUI={bg=Color(20,25,34,248),panel=Color(34,43,57,245),accent=Color(70,155,255),green=Color(55,185,105),red=Color(205,70,65),yellow=Color(235,180,60),text=Color(240,244,250),dim=Color(165,175,190)}

-- ========== СТИЛИЗАЦИЯ DERMA-ЭЛЕМЕНТОВ (тёмная тема HUD v10.2) ==========
local inputBg   = Color(25, 30, 40, 240)
local inputBgH  = Color(30, 38, 52, 245)
local inputText = Color(220, 225, 235)
local inputBorder = Color(60, 70, 85, 200)

-- DTextEntry / DNumberWang — тёмные поля ввода
local DTextEntryCT = vgui.GetControlTable("DTextEntry")
if DTextEntryCT and DTextEntryCT.Paint then
    local oldDEPaint = DTextEntryCT.Paint
    DTextEntryCT.Paint = function(self, w, h)
        if self.__grml_skinned then return oldDEPaint(self, w, h) end
        local bg = self:IsHovered() and inputBgH or inputBg
        draw.RoundedBox(4, 0, 0, w, h, bg)
        surface.SetDrawColor(inputBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        self:DrawTextEntryText(inputText, CUI.accent, CUI.text)
    end
end

-- DComboBox — тёмный выпадающий список
local DComboBoxCT = vgui.GetControlTable("DComboBox")
if DComboBoxCT and DComboBoxCT.Paint then
    local oldDCPaint = DComboBoxCT.Paint
    DComboBoxCT.Paint = function(self, w, h)
        if self.__grml_skinned then return oldDCPaint(self, w, h) end
        local bg = self:IsHovered() and inputBgH or inputBg
        draw.RoundedBox(4, 0, 0, w, h, bg)
        surface.SetDrawColor(inputBorder)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
    end
end
-- Меню DComboBox
local DMenuCT = vgui.GetControlTable("DMenu")
if DMenuCT and DMenuCT.PaintBackground then
    local oldDMenuPaint = DMenuCT.PaintBackground
    DMenuCT.PaintBackground = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(30, 38, 52, 250))
    end
end

-- DListView — тёмная таблица
local DListViewCT = vgui.GetControlTable("DListView")
if DListViewCT and DListViewCT.Paint then
    local oldDLVPaint = DListViewCT.Paint
    DListViewCT.Paint = function(self, w, h)
        if self.__grml_skinned then return oldDLVPaint(self, w, h) end
        draw.RoundedBox(4, 0, 0, w, h, inputBg)
    end
end
-- Заголовки DListView
local DListView_Line = vgui.GetControlTable("DListView_Line")
if DListView_Line and DListView_Line.Paint then
    DListView_Line.Paint = function(self, w, h)
        if self:IsLineSelected() then
            draw.RoundedBox(2, 0, 0, w, h, Color(70, 100, 160, 200))
        elseif self.m_bSelected then
            draw.RoundedBox(2, 0, 0, w, h, Color(50, 70, 120, 160))
        end
        self:DrawBackground(w, h)
    end
end

-- DLabel — тёмный текст по умолчанию
local oldLabelPaint = vgui.GetControlTable("DLabel").PaintBackground
vgui.GetControlTable("DLabel").PaintBackground = function(self, w, h)
    -- Прозрачный фон
end

local route={active=false}

local function note(s,ok) notification.AddLegacy(s,ok and NOTIFY_GENERIC or NOTIFY_ERROR,4) end

local function f(title,w,h) local x=vgui.Create("DFrame");x:SetTitle("");x:SetSize(w,h);x:Center();x:MakePopup();x.Paint=function(_,pw,ph) draw.RoundedBox(8,0,0,pw,ph,CUI.bg);draw.RoundedBoxEx(8,0,0,pw,36,Color(28,36,49),true,true,false,false);draw.SimpleText(title,"GRML_Title",12,18,CUI.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER) end;return x end

local function b(p,t,c,w,h) local x=vgui.Create("DButton",p);x:SetText(t);x:SetFont("GRML_Normal");x:SetTextColor(color_white);if w then x:SetWide(w) end;if h then x:SetTall(h) end;x.Paint=function(s,pw,ph)local col=s:IsHovered() and Color(math.min(c.r+20,255),math.min(c.g+20,255),math.min(c.b+20,255))or c;draw.RoundedBox(5,0,0,pw,ph,col)end;return x end

local function act(a,e,wr)
    if not IsValid(e) and a~="admin_open" and a~="crate_list" and a~="admin_access" then return end
    net.Start(N.action)
        net.WriteString(a)
        net.WriteEntity(IsValid(e) and e or NULL)
        if wr then wr() end
    net.SendToServer()
end

local function iname(id) local d=GRM.Inventory and GRM.Inventory.GetItemDef and GRM.Inventory.GetItemDef(id);return d and d.name or id end

net.Receive(N.result,function()
    local success=net.ReadBool()
    local message=net.ReadString()
    note(message,success)
end)

net.Receive(N.routeSync,function()
    route.active=net.ReadBool()
    if not route.active then route.phase=nil;route.target=nil;route.cargo=0;route.minimum=0;return end
    route.phase=net.ReadString();route.target=net.ReadEntity();route.name=net.ReadString();route.cargo=net.ReadUInt(8);route.minimum=net.ReadUInt(8)
end)

net.Receive(N.routeMenu,function()
    local truck=net.ReadEntity();local loads=net.ReadTable()or{};local wh=net.ReadTable()or{}
    -- пустая инфраструктура — главный тихий фейл «меню не открылось/нечего выбрать»
    if #loads==0 or #wh==0 then
        local x=f("Начать логистический рейс",560,330)
        local d=vgui.Create("DLabel",x);d:SetPos(20,70);d:SetSize(520,200);d:SetFont("GRML_Normal");d:SetTextColor(CUI.dim)
        d:SetWrap(true);d:SetAutoStretchVertical(true)
        d:SetText("Логистика на этой карте не развёрнута:\n"
            .. (#loads==0 and "• нет ни одной ТОЧКИ ПОГРУЗКИ (суперадмин: grm_logistics_place_loading)\n" or "")
            .. (#wh==0 and "• нет ни одного СКЛАДА фракции (суперадмин: grm_logistics_place_warehouse <фракция> MAIN)\n" or "")
            .. "\nПосле установки откройте меню снова: /logistics_start")
        return
    end
    local x=f("Начать логистический рейс",560,330)

    local lc=vgui.Create("DComboBox",x);lc:SetPos(20,65);lc:SetSize(520,30);lc:SetValue("Точка погрузки")
    for _,v in ipairs(loads)do lc:AddChoice(v.name,v.id)end

    local wc=vgui.Create("DComboBox",x);wc:SetPos(20,125);wc:SetSize(520,30);wc:SetValue("Склад получатель")
    for _,v in ipairs(wh)do wc:AddChoice((v.faction or "?").." — "..v.name,v.id)end

    local start=b(x,"Начать рейс",CUI.green,520,40);start:SetPos(20,205);start.DoClick=function()local li=lc:GetSelectedID();local wi=wc:GetSelectedID();local l=li and lc:GetOptionData(li);local w=wi and wc:GetOptionData(wi);if not l or not w then note("Выберите точку и склад",false)return end;act("start_route",truck,function()net.WriteString(l);net.WriteString(w)end);x:Close()end
end)

net.Receive(N.loading,function()
    local point=net.ReadEntity();local d=net.ReadTable()or{};local x=f("Комплектация груза",700,470)
    local tabs=vgui.Create("DPropertySheet",x);tabs:Dock(FILL);tabs:DockMargin(8,44,8,52)

    local empty=b(x,"Получить пустой ящик в руки",CUI.accent,280,34);empty:SetPos(8,428)
    empty.DoClick=function()act("loading_empty_crate",point);x:Close()end

    local hint=vgui.Create("DLabel",x);hint:SetPos(300,435);hint:SetSize(390,25);hint:SetText("R при переноске — поставить ящик на землю");hint:SetFont("GRML_Small");hint:SetTextColor(CUI.dim)

    local function make(title,list,kind)
        local p=vgui.Create("DPanel",tabs);p:SetPaintBackground(false)
        local bar=vgui.Create("DPanel",p);bar:Dock(BOTTOM);bar:SetTall(42);bar:DockMargin(4,2,4,4);bar.Paint=function(_,w,h)draw.RoundedBox(5,0,0,w,h,CUI.panel)end
        local lv=vgui.Create("DListView",p);lv:Dock(FILL);lv:DockMargin(4,4,4,0);lv:SetMultiSelect(false);lv:AddColumn("Предмет");lv:AddColumn("Количество")
        for _,v in ipairs(list)do local line=lv:AddLine(v.name or v.class or v.id,tostring(v.count or 1));line.ID=v.class or v.id;line.Count=v.count or 1 end
        local pack=b(bar,"Упаковать выбранное",CUI.green,220,32);pack:SetPos(5,5)
        pack.DoClick=function()local i=lv:GetSelectedLine();local line=i and lv:GetLine(i);if not IsValid(line)then note("Выберите груз",false)return end;act("pack",point,function()net.WriteString(kind);net.WriteString(line.ID);net.WriteUInt(kind=="weapon" and 1 or math.min(line.Count,120),8)end);x:Close()end
        tabs:AddSheet(title,p,"icon16/box.png")
    end

    make("Оружие",d.weapons or{},"weapon")
    make("Патроны",(function()local o={}for _,v in ipairs(d.items or{})do if v.type=="ammo"then o[#o+1]=v end end return o end)(),"ammo")
    make("Материалы",(function()local o={}for _,v in ipairs(d.items or{})do if v.type=="item"then o[#o+1]=v end end return o end)(),"material")
end)

net.Receive(N.crate,function()
    local e=net.ReadEntity();local d=net.ReadTable()or{};local x=f("Грузовой ящик",420,300)
    local l=vgui.Create("DLabel",x);l:SetPos(18,55);l:SetSize(385,80);l:SetWrap(true);l:SetFont("GRML_Normal");l:SetTextColor(CUI.text)

    if d.kind=="" then
        l:SetText("Пустой ящик\nПоставьте на землю, возьмите оружие в руки и нажмите кнопку упаковки.")
    elseif d.kind=="weapon" then
        l:SetText(string.format("Оружейный ящик: %d оружий\nПистолеты: %d / 2 | Автоматы: %d / 5\nНужно заполнить минимум 2 пистолетами и 5 автоматами.",d.total or d.amount or 0,d.pistols or 0,d.automatics or 0))
    else
        l:SetText("Груз: "..d.kind.."\n"..iname(d.id).." x"..(d.amount or 1))
    end

    if d.kind=="" or d.kind=="weapon" then
        local pack=b(x,d.kind=="" and "Положить активное оружие" or "Добавить активное оружие",CUI.green,384,34);pack:SetPos(18,145);pack.DoClick=function()act("crate_pack_active",e);x:Close()end
    end

    local carry=b(x,"Нести в руках",CUI.accent,185,38);carry:SetPos(18,240);carry.DoClick=function()act("crate_carry",e);x:Close()end
    local store=b(x,"Убрать в инвентарь",CUI.yellow,185,38);store:SetPos(217,240);store.DoClick=function()act("crate_store",e);x:Close()end
end)

net.Receive(N.crateInv,function()
    local crates=net.ReadTable()or{};local x=f("Грузовые ящики в инвентаре",520,420);local lv=vgui.Create("DListView",x);lv:Dock(FILL);lv:DockMargin(8,44,8,48);lv:AddColumn("Груз");lv:AddColumn("Количество");for id,d in pairs(crates)do local line=lv:AddLine(iname(d.id),tostring(d.amount));line.CrateID=id end
    local out=b(x,"Достать выбранный ящик",CUI.green,230,34);out:SetPos(8,378);out.DoClick=function()local i=lv:GetSelectedLine();local line=i and lv:GetLine(i);if not IsValid(line)then note("Выберите ящик",false)return end;net.Start(N.action);net.WriteString("crate_extract");net.WriteEntity(NULL);net.WriteString(line.CrateID);net.SendToServer();x:Close()end
end)

local function addStockRows(list,data)
    for id,n in pairs((data.weapons)or{})do local q=list:AddLine("Оружие",id,tostring(n));q.K="weapon";q.ID=id end
    for id,n in pairs((data.items)or{})do local q=list:AddLine("Предмет",iname(id),tostring(n));q.K=(id:find("ammo")and"ammo"or"material");q.ID=id end
end

local function openStockPanel(parent,stock,entity,actionCode,label)
    local lv=vgui.Create("DListView",parent);lv:Dock(FILL);lv:DockMargin(4,4,4,44);lv:SetMultiSelect(false);lv:AddColumn("Тип");lv:AddColumn("Предмет");lv:AddColumn("Количество");addStockRows(lv,stock or {})
    local bt=b(parent,label,CUI.green,220,34);bt:SetPos(4,380);bt.DoClick=function()local i=lv:GetSelectedLine();local q=i and lv:GetLine(i);if not IsValid(q)then note("Выберите предмет",false)return end;act(actionCode,entity,function()net.WriteString(q.K);net.WriteString(q.ID);net.WriteUInt(1,12)end)end
end

net.Receive(N.warehouse,function()
    local e=net.ReadEntity();local d=net.ReadTable()or{}
    local x=f("Склад фракции",650,500)
    if not d.admin then openStockPanel(x,d.stock,e,"warehouse_take","Достать");return end

    local tabs=vgui.Create("DPropertySheet",x);tabs:Dock(FILL);tabs:DockMargin(6,42,6,6)
    local stock=vgui.Create("DPanel",tabs);stock:SetPaintBackground(false);openStockPanel(stock,d.stock,e,"warehouse_take","Достать");tabs:AddSheet("Запасы",stock,"icon16/briefcase.png")

    local setup=vgui.Create("DPanel",tabs);setup:SetPaintBackground(false)
    local hint=vgui.Create("DLabel",setup);hint:SetPos(14,12);hint:SetSize(600,38);hint:SetWrap(true);hint:SetText("Сначала настройте этот склад: выберите фракцию и задайте Network ID. Затем связывайте с ним оружейные шкафы.");hint:SetFont("GRML_Small");hint:SetTextColor(CUI.dim)

    local fc=vgui.Create("DComboBox",setup);fc:SetPos(14,64);fc:SetSize(280,30);fc:SetValue(d.faction~="" and d.faction or "Выберите фракцию")
    for _,name in ipairs(d.factions or{})do fc:AddChoice(name)end

    local ne=vgui.Create("DTextEntry",setup);ne:SetPos(14,108);ne:SetSize(280,30);ne:SetText(d.network or "");ne:SetPlaceholderText("Network ID, например POLICE_MAIN")

    local cap=d.capacity or {}
    local capFields={}
    local labels={{"weapons","Оружие"},{"ammo","Патроны"},{"materials","Материалы"},{"medical","Мед"},{"repair","Ремкомплекты"}}
    for idx,info in ipairs(labels)do
        local l=vgui.Create("DLabel",setup);l:SetPos(320,52+(idx-1)*34);l:SetSize(120,24);l:SetText(info[2]);l:SetFont("GRML_Small");l:SetTextColor(CUI.text)
        local w=vgui.Create("DNumberWang",setup);w:SetPos(445,50+(idx-1)*34);w:SetSize(110,26);w:SetMin(0);w:SetMax(100000);w:SetValue(cap[info[1]] or 0);capFields[info[1]]=w
    end

    local save=b(setup,"Сохранить настройки склада",CUI.green,260,34);save:SetPos(14,160);save.DoClick=function()
        local i=fc:GetSelectedID();local faction=i and fc:GetOptionData(i)or fc:GetValue();local out={}
        for key,w in pairs(capFields)do out[key]=math.max(0,math.floor(tonumber(w:GetValue())or 0))end
        act("admin_warehouse",e,function()net.WriteString(faction or "");net.WriteString(ne:GetValue());net.WriteTable(out)end);x:Close()
    end
    tabs:AddSheet("Настройка склада",setup,"icon16/cog.png")

    local links=vgui.Create("DPanel",tabs);links:SetPaintBackground(false)
    local actionBar=vgui.Create("DPanel",links);actionBar:Dock(BOTTOM);actionBar:SetTall(42);actionBar:DockMargin(8,2,8,4);actionBar.Paint=function(_,w,h)draw.RoundedBox(5,0,0,w,h,CUI.panel)end
    local hint2=vgui.Create("DLabel",links);hint2:Dock(TOP);hint2:SetTall(44);hint2:DockMargin(8,6,8,2);hint2:SetWrap(true);hint2:SetText("Сканирование показывает шкафы на карте. Выберите шкаф и нажмите «Связать выбранный». Шкаф автоматически получит фракцию и Network ID склада.");hint2:SetFont("GRML_Small");hint2:SetTextColor(CUI.dim)
    local list=vgui.Create("DListView",links);list:Dock(FILL);list:DockMargin(8,0,8,0);list:SetMultiSelect(false);list:AddColumn("Шкаф ID");list:AddColumn("Фракция");list:AddColumn("Network ID");list:AddColumn("Связь")
    for _,a in ipairs(d.armories or{})do local q=list:AddLine(a.id,a.faction~="" and a.faction or "—",a.network~="" and a.network or "—",a.linked and "Связан" or "Не связан");q.ArmoryID=a.id end

    local scan=b(actionBar,"Сканировать шкафы",CUI.accent,180,32);scan:SetPos(5,5);scan.DoClick=function()act("warehouse_scan",e);x:Close()end
    local link=b(actionBar,"Связать выбранный",CUI.green,200,32);link:SetPos(194,5);link.DoClick=function()local i=list:GetSelectedLine();local q=i and list:GetLine(i);if not IsValid(q)then note("Выберите шкаф",false)return end;act("warehouse_link",e,function()net.WriteString(q.ArmoryID)end);x:Close()end
    tabs:AddSheet("Связь со шкафами",links,"icon16/link.png")
end)

net.Receive(N.armory,function()
    local e=net.ReadEntity();local d=net.ReadTable()or{};local x=f("Арсенал фракции",620,510);local tabs=vgui.Create("DPropertySheet",x);tabs:Dock(FILL);tabs:DockMargin(6,42,6,6)

    local own=vgui.Create("DPanel",tabs);own:SetPaintBackground(false);openStockPanel(own,d.stock,e,"armory_take","Достать из шкафа");tabs:AddSheet("В шкафу",own,"icon16/briefcase.png")

    -- Вкладка: Положить оружие / предметы в шкаф
    local depositPnl=vgui.Create("DPanel",tabs);depositPnl:SetPaintBackground(false)
    local topBar=vgui.Create("DPanel",depositPnl);topBar:Dock(TOP);topBar:SetTall(42);topBar:DockMargin(4,4,4,4);topBar.Paint=function(_,w,h)draw.RoundedBox(5,0,0,w,h,CUI.panel)end

    local bDepActive=b(topBar,"Положить активное оружие из рук",CUI.green,320,32)
    bDepActive:SetPos(5,5)
    bDepActive.DoClick=function()
        act("armory_deposit_active",e)
        x:Close()
    end

    local depLV=vgui.Create("DListView",depositPnl);depLV:Dock(FILL);depLV:DockMargin(4,2,4,44);depLV:SetMultiSelect(false);depLV:AddColumn("Категория");depLV:AddColumn("Название");depLV:AddColumn("Количество")

    for _,w in ipairs(d.myWeapons or {}) do
        local q=depLV:AddLine("Оружие",w.name or w.class,"1")
        q.K="weapon"; q.ID=w.class; q.Count=1
    end
    for _,it in ipairs(d.myItems or {}) do
        local q=depLV:AddLine(it.type=="ammo" and "Патроны" or "Предмет",it.name or it.id,tostring(it.count or 1))
        q.K=it.type=="ammo" and "ammo" or "material"; q.ID=it.id; q.Count=it.count or 1
    end

    local bDepSel=b(depositPnl,"Положить выбранное в шкаф",CUI.accent,240,34);bDepSel:SetPos(4,390)
    bDepSel.DoClick=function()
        local i=depLV:GetSelectedLine();local q=i and depLV:GetLine(i)
        if not IsValid(q) then note("Выберите оружие или предмет из списка",false) return end
        act("armory_deposit",e,function()
            net.WriteString(q.K)
            net.WriteString(q.ID)
            net.WriteUInt(1,12)
        end)
        x:Close()
    end

    tabs:AddSheet("Положить",depositPnl,"icon16/add.png")

    local supply=vgui.Create("DPanel",tabs);supply:SetPaintBackground(false);openStockPanel(supply,d.supply,e,"armory_request","Запросить со склада");tabs:AddSheet("Запросить",supply,"icon16/arrow_down.png")

    if d.admin then
        local cfg=vgui.Create("DPanel",tabs);cfg:SetPaintBackground(false)
        local lbl=vgui.Create("DLabel",cfg);lbl:SetPos(14,12);lbl:SetSize(560,34);lbl:SetWrap(true);lbl:SetText("Настройте фракцию-владельца и Network ID или свяжите шкаф с уже выставленным складом.");lbl:SetFont("GRML_Small");lbl:SetTextColor(CUI.dim)

        local fc=vgui.Create("DComboBox",cfg);fc:SetPos(14,60);fc:SetSize(280,30);fc:SetValue(d.faction~="" and d.faction or "Выберите фракцию")
        for _,name in ipairs(d.factions or{})do fc:AddChoice(name)end

        local ne=vgui.Create("DTextEntry",cfg);ne:SetPos(14,102);ne:SetSize(280,30);ne:SetText(d.network or "");ne:SetPlaceholderText("Network ID, например POLICE_MAIN")

        local mode=vgui.Create("DCheckBoxLabel",cfg);mode:SetPos(14,142);mode:SetSize(300,25);mode:SetText("Фракционный режим (доступ только фракции)");mode:SetTextColor(CUI.text);mode:SetValue(d.mode and 1 or 0)

        local save=b(cfg,"Сохранить настройки шкафа",CUI.green,250,34);save:SetPos(14,180);save.DoClick=function()local si=fc:GetSelectedID();local faction=si and fc:GetOptionData(si)or fc:GetValue();act("admin_armory",e,function()net.WriteString(faction or "");net.WriteString(ne:GetValue());net.WriteBool(mode:GetChecked());net.WriteTable({})end);x:Close()end

        local list=vgui.Create("DListView",cfg);list:SetPos(310,60);list:SetSize(290,250);list:SetMultiSelect(false);list:AddColumn("Склад");list:AddColumn("Фракция");list:AddColumn("Связь")
        for _,w in ipairs(d.warehouses or{})do local q=list:AddLine(w.network~="" and w.network or w.id,w.faction~="" and w.faction or "—",w.linked and "Связан" or "Нет");q.WarehouseID=w.id end

        local scan=b(cfg,"Сканировать склады",CUI.accent,180,32);scan:SetPos(310,322);scan.DoClick=function()act("refresh",e);x:Close()end
        local link=b(cfg,"Связать выбранный",CUI.green,190,32);link:SetPos(410,322);link.DoClick=function()local i=list:GetSelectedLine();local q=i and list:GetLine(i);if not IsValid(q)then note("Выберите склад",false)return end;act("armory_link",e,function()net.WriteString(q.WarehouseID)end);x:Close()end
        tabs:AddSheet("Настройка",cfg,"icon16/cog.png")
    end
end)

net.Receive(N.admin,function()
    local d=net.ReadTable()or{}
    local x=f("Админ: доступ к логистике",620,560)
    local pending={}
    local scroll=vgui.Create("DScrollPanel",x);scroll:Dock(FILL);scroll:DockMargin(8,44,8,54)

    local h=vgui.Create("DLabel",scroll);h:Dock(TOP);h:SetTall(38);h:SetWrap(true);h:SetText("Отметьте фракции, которым разрешено начинать рейсы и работать на точках погрузки. Затем нажмите «Сохранить доступ».");h:SetFont("GRML_Small");h:SetTextColor(CUI.dim)

    for _,name in ipairs(d.factions or{})do
        pending[name]=d.access and d.access[name] or false
        local row=vgui.Create("DPanel",scroll);row:Dock(TOP);row:SetTall(34);row:DockMargin(0,0,0,4);row.Paint=function(_,w,h)draw.RoundedBox(4,0,0,w,h,CUI.panel)end
        local c=c or vgui.Create("DCheckBoxLabel",row);c:Dock(FILL);c:DockMargin(10,0,0,0);c:SetText(name);c:SetFont("GRML_Normal");c:SetTextColor(CUI.text);c:SetValue(pending[name] and 1 or 0)
        c.OnChange=function(_,v) pending[name]=v and true or false end
    end

    local save=b(x,"Сохранить доступ",CUI.green,190,34);save:SetPos(8,518)
    save.DoClick=function()
        for name,enabled in pairs(pending)do act("admin_access",NULL,function()net.WriteString(name);net.WriteBool(enabled)end)end
        note("Настройки доступа логистики сохранены",true)
    end
end)

concommand.Add("grm_logistics_admin_menu",function() act("admin_open",NULL) end)

local function findSheet(panel)
    if not IsValid(panel) then return nil end
    if panel.ClassName=="DPropertySheet" then return panel end
    for _,child in ipairs(panel:GetChildren())do local s=findSheet(child);if s then return s end end
end

timer.Create("GRML_FactionsMenuTab",0.7,0,function()
    if not IsValid(LocalPlayer()) or not LocalPlayer():IsSuperAdmin() then return end
    local sheet=findSheet(ui and ui.currentFrame)
    if not IsValid(sheet) then return end
    for _,it in ipairs(sheet.Items or{})do if IsValid(it.Tab) and it.Tab:GetText()=="Логистика" then return end end
    local panel=vgui.Create("DPanel");panel:SetPaintBackground(false)
    local text=vgui.Create("DLabel",panel);text:Dock(TOP);text:SetTall(60);text:DockMargin(12,12,12,4);text:SetWrap(true);text:SetText("Настройка фракций, имеющих доступ к матовозкам и точкам погрузки.");text:SetFont("GRML_Normal");text:SetTextColor(CUI.text)
    local open=b(panel,"Открыть настройки логистики",CUI.accent,300,36);open:Dock(TOP);open:DockMargin(12,4,12,0);open.DoClick=function()act("admin_open",NULL)end
    sheet:AddSheet("Логистика",panel,"icon16/lorry.png")
end)

hook.Add("HUDPaint","GRML_EntityLabels",function()
    local ply=LocalPlayer();if not IsValid(ply) then return end

    local function label(e,title,hint,col)
        local pos=e:LocalToWorld(Vector(0,0,e:OBBMaxs().z+8)):ToScreen()
        if not pos.visible then return end
        draw.SimpleTextOutlined(title,"GRML_Normal",pos.x,pos.y,col or CUI.yellow,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,Color(0,0,0,220))
        draw.SimpleTextOutlined(hint,"GRML_Small",pos.x,pos.y+17,CUI.text,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,Color(0,0,0,220))
    end

    for _,class in ipairs({"grm_logistics_warehouse","grm_logistics_armory","grm_logistics_loading"})do
        for _,e in ipairs(ents.FindByClass(class))do
            local hiddenLoading=class=="grm_logistics_loading" and not e:GetNWBool("GRML_LoadingActive",false) and not ply:IsSuperAdmin()
            if IsValid(e) and not hiddenLoading and ply:GetPos():DistToSqr(e:GetPos())<=700*700 then
                if class=="grm_logistics_warehouse" then label(e,"Склад фракции: "..(e:GetFactionName()~="" and e:GetFactionName() or "не настроен"),"[E] Открыть склад")
                elseif class=="grm_logistics_armory" then label(e,"Оружейный шкаф: "..(e:GetFactionName()~="" and e:GetFactionName() or "не настроен"),"[E] Открыть арсенал")
                else label(e,"Точка погрузки: "..(e:GetPointName()~="" and e:GetPointName() or "не настроена"),"[E] Открыть меню погрузки",CUI.yellow) end
            end
        end
    end

    for _,crate in ipairs(ents.FindByClass("grm_logistics_crate"))do
        if IsValid(crate) and not IsValid(crate:GetParent()) and ply:GetPos():DistToSqr(crate:GetPos())<=500*500 then
            local kind=crate:GetCargoKind()
            local title=kind=="" and "Пустой грузовой ящик" or ("Грузовой ящик: "..kind)
            label(crate,title,"[E] Поднять / открыть ящик",kind=="" and CUI.accent or CUI.green)
        end
    end
end)

hook.Add("HUDPaint","GRML_RouteHUD",function()
    if not route.active or not IsValid(route.target) then return end;local s=(route.target:GetPos()+Vector(0,0,80)):ToScreen();if not s.visible then return end;draw.SimpleText(route.phase=="to_loading" and "ТОЧКА ПОГРУЗКИ" or "СКЛАД-ПОЛУЧАТЕЛЬ","GRML_Title",s.x,s.y,CUI.yellow,TEXT_ALIGN_CENTER,TEXT_ALIGN_BOTTOM);draw.SimpleText(route.name.." | Оружейных ящиков: "..(route.cargo or 0).." / "..(route.minimum or 0),"GRML_Normal",s.x,s.y+5,CUI.text,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP)
end)

hook.Add("HUDPaint","GRML_CarryHints",function()
    local ply=LocalPlayer()
    if IsValid(ply) and ply:GetNWBool("GRML_Carrying",false) then
        draw.SimpleTextOutlined("[E] Загрузить ящик в матовозку   |   [R] Поставить ящик на землю","GRML_Normal",ScrW()/2,ScrH()-185,CUI.yellow,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,Color(0,0,0,230))
    end
end)

hook.Add("CalcMainActivity","GRML_CarryAnimation",function(ply,vel) if ply:GetNWBool("GRML_Carrying",false) then return vel:Length2D()>10 and ACT_HL2MP_WALK_PASSIVE or ACT_HL2MP_IDLE_PASSIVE,-1 end end)

concommand.Add("grm_logistics_crates",function() net.Start(N.action);net.WriteString("crate_list");net.WriteEntity(NULL);net.SendToServer()end)

print("[GRM Logistics] client loaded")
