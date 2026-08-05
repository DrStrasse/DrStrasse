-- GRM Electronics client v1.5.0
if not CLIENT then return end
GRM=GRM or{};GRM.Electronics=GRM.Electronics or{};local E=GRM.Electronics;E.Topology=E.Topology or{devices={},links={}}
surface.CreateFont("GRMNet_Title",{font="Roboto",size=24,weight=800,extended=true});surface.CreateFont("GRMNet_Head",{font="Roboto",size=17,weight=700,extended=true});surface.CreateFont("GRMNet_Body",{font="Roboto",size=14,weight=500,extended=true});surface.CreateFont("GRMNet_Small",{font="Roboto",size=12,weight=500,extended=true});surface.CreateFont("GRMNet_Calc",{font="Roboto",size=36,weight=700,extended=true});surface.CreateFont("GRMNet_CalcHist",{font="Roboto",size=14,weight=400,extended=true});surface.CreateFont("GRMNet_Tiny",{font="Roboto",size=10,weight=500,extended=true});surface.CreateFont("GRMNet_BigIcon",{font="Roboto",size=48,weight=300,extended=true});surface.CreateFont("GRMNet_Status",{font="Roboto",size=11,weight=600,extended=true});surface.CreateFont("GRMNet_Bold",{font="Roboto",size=14,weight=700,extended=true});surface.CreateFont("GRMNet_Normal",{font="Roboto",size=13,weight=500,extended=true});surface.CreateFont("GRMNet_Bold",{font="Roboto",size=14,weight=700,extended=true})
local C={bg=Color(8,14,23,249),panel=Color(20,30,45),card=Color(29,42,62),hover=Color(45,65,92),blue=Color(65,145,240),green=Color(70,205,125),red=Color(220,78,82),yellow=Color(242,190,75),text=Color(240,245,252),dim=Color(150,165,185),purple=Color(140,100,220),orange=Color(230,140,60),cyan=Color(80,200,220),skin=Color(225,195,165),skinDark=Color(190,160,130),hair=Color(70,50,35),lip=Color(185,75,75)}
local ICONS={Home=Material("icon16/house.png"),Apps=Material("icon16/application_view_tile.png"),WiFi=Material("icon16/transmit.png"),Login=Material("icon16/key.png"),Files=Material("icon16/folder.png"),Modules=Material("icon16/application_view_tile.png"),Logout=Material("icon16/door_out.png"),Settings=Material("icon16/cog.png"),Print=Material("icon16/printer.png"),Save=Material("icon16/disk.png"),Delete=Material("icon16/delete.png"),Share=Material("icon16/group_go.png"),Calc=Material("icon16/calculator.png"),Note=Material("icon16/note.png"),Edit=Material("icon16/page_white_edit.png"),Photo=Material("icon16/user.png"),Mail=Material("icon16/email.png"),Network=Material("icon16/server.png")}
local function iconFor(text)local t=string.lower(tostring(text or""));if t:find("главн")then return ICONS.Home elseif t:find("прилож")then return ICONS.Apps elseif t:find("wi%-fi")then return ICONS.WiFi elseif t:find("вход")then return ICONS.Login elseif t:find("файл")then return ICONS.Files elseif t:find("модул")then return ICONS.Modules elseif t:find("настрой")then return ICONS.Settings elseif t:find("выйти")then return ICONS.Logout elseif t:find("печат")then return ICONS.Print elseif t:find("сохран")then return ICONS.Save elseif t:find("удал")then return ICONS.Delete elseif t:find("передат")then return ICONS.Share elseif t:find("калькул")then return ICONS.Calc elseif t:find("замет")then return ICONS.Note elseif t:find("редакт")then return ICONS.Edit elseif t:find("фото")then return ICONS.Photo elseif t:find("почт")or t:find("рассыл")or t:find("письм")then return ICONS.Mail elseif t:find("network")then return ICONS.Network end end
local function frame(title,w,h)local f=vgui.Create("DFrame");f:SetTitle("");f:SetSize(math.min(w,ScrW()-40),math.min(h,ScrH()-40));f:Center();f:MakePopup();f.Paint=function(_,pw,ph)draw.RoundedBox(10,0,0,pw,ph,C.bg);draw.RoundedBoxEx(10,0,0,pw,50,Color(15,25,40),true,true,false,false);draw.SimpleText(title,"GRMNet_Title",18,25,C.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER);draw.SimpleText(os.date("%H:%M"),"GRMNet_Small",pw-16,25,C.dim,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)end;return f end
local function btn(p,text,x,y,w,h,col,fn)local b=vgui.Create("DButton",p);b:SetPos(x,y);b:SetSize(w,h);b:SetText("");b.DoClick=function()surface.PlaySound("buttons/button15.wav");if fn then fn()end end;b.Paint=function(self,pw,ph)local base=col or C.card;local c=self:IsDown()and Color(math.max(0,base.r-20),math.max(0,base.g-20),math.max(0,base.b-20))or(self:IsHovered()and C.hover or base);draw.RoundedBox(8,0,0,pw,ph,c);surface.SetDrawColor(self:IsHovered()and Color(110,175,245)or Color(55,78,108));surface.DrawOutlinedRect(0,0,pw,ph,1);local icon=iconFor(text);local tx=pw/2;if icon then surface.SetMaterial(icon);surface.SetDrawColor(255,255,255,235);surface.DrawTexturedRect(12,ph/2-8,16,16);tx=tx+8 end;draw.SimpleText(text,"GRMNet_Body",tx,ph/2+(self:IsDown()and 1 or 0),C.text,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)end;return b end
local function appTile(p,title,subtitle,icon,x,y,color,fn)local b=vgui.Create("DButton",p);b:SetPos(x,y);b:SetSize(190,108);b:SetText("");b.DoClick=function()surface.PlaySound("buttons/button15.wav");fn()end;b.Paint=function(self,w,h)local c=self:IsDown()and Color(24,35,52)or(self:IsHovered()and C.hover or C.card);draw.RoundedBox(12,0,0,w,h,c);surface.SetDrawColor(color or C.blue);surface.DrawOutlinedRect(0,0,w,h,2);surface.SetMaterial(Material(icon,"smooth"));surface.SetDrawColor(255,255,255,245);surface.DrawTexturedRect(16,18,28,28);draw.SimpleText(title,"GRMNet_Head",54,22,C.text);draw.SimpleText(subtitle,"GRMNet_Small",54,44,C.dim);draw.SimpleText("ОТКРЫТЬ  ›","GRMNet_Small",16,84,color or C.blue)end;return b end
local function entry(p,placeholder,x,y,w,h,multi)local e=vgui.Create("DTextEntry",p);e:SetPos(x,y);e:SetSize(w,h or 30);e:SetPlaceholderText(placeholder);e:SetMultiline(multi==true);e.GRMPlaceholder=placeholder;e.Paint=function(self,pw,ph)draw.RoundedBox(6,0,0,pw,ph,Color(13,21,34));surface.SetDrawColor(self:HasFocus()and C.blue or Color(55,75,100));surface.DrawOutlinedRect(0,0,pw,ph,1);local value=self:GetText()or"";if self.GRMSecret then if value==""and not self:HasFocus()then draw.SimpleText(self.GRMPlaceholder,"GRMNet_Body",8,ph/2,C.dim,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)else local length=(utf8 and utf8.len and utf8.len(value))or#value;draw.SimpleText(string.rep("•",math.min(64,length)),"GRMNet_Body",8,ph/2,C.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)end else self:DrawTextEntryText(C.text,C.blue,C.text)end end;return e end
local function secureEntry(p,placeholder,x,y,w,h)local e=entry(p,placeholder,x,y,w,h,false);e.GRMSecret=true;return e end
local function textLabel(p,text,x,y,w,h,font,color)local l=vgui.Create("DLabel",p);l:SetPos(x,y);l:SetSize(w,h);l:SetText(text);l:SetFont(font or"GRMNet_Body");l:SetTextColor(color or C.text);l:SetWrap(true);return l end
local function send(ent,op,writer)net.Start("GRM_Net_Action");net.WriteEntity(ent);net.WriteString(op);if writer then writer()end;net.SendToServer()end
local function darkList(p,x,y,w,h,cols)local l=vgui.Create("DListView",p);l:SetPos(x,y);l:SetSize(w,h);for _,c in ipairs(cols)do l:AddColumn(c[1]):SetFixedWidth(c[2])end;l.Paint=function(_,pw,ph)draw.RoundedBox(7,0,0,pw,ph,Color(12,20,32))end;return l end
local function addLine(l,...)local line=l:AddLine(...);for _,c in ipairs(line.Columns or{})do c:SetTextColor(C.text)end;line.Paint=function(self,w,h)draw.RoundedBox(4,1,1,w-2,h-2,self:IsSelected()and C.blue or(self:IsHovered()and C.hover or C.card));for _,c in ipairs(self.Columns or{})do c:SetTextColor(C.text)end end;return line end
net.Receive("GRM_Net_Topology",function()E.Topology=net.ReadTable()or{devices={},links={}}end)
local cableMaterial=Material("cable/blue_elec")
hook.Add("PostDrawTranslucentRenderables","GRM_Net_Cables",function(depth,sky,sky3d)if depth or sky or sky3d then return end;render.SetMaterial(cableMaterial);local by={};for _,d in ipairs(E.Topology.devices or{})do if IsValid(d.ent)then by[d.id]=d.ent end end;for _,l in ipairs(E.Topology.links or{})do local a,b=by[l.a],by[l.b];if IsValid(a)and IsValid(b)then render.DrawBeam(a:WorldSpaceCenter(),b:WorldSpaceCenter(),3,0,1,Color(55,165,255,230))end end end)

local current={ent=nil,data=nil,files={},deviceID=""}
local function openComputer(ent,data)
 if IsValid(E.ActiveFrame)then E.ActiveFrame:Remove()end
 local f=frame("GRM NET OS · "..tostring(data.name),1060,720);current.ent,current.data,current.deviceID=ent,data,data.deviceID or""
 local side=vgui.Create("DPanel",f);side:SetPos(14,62);side:SetSize(190,640);side.Paint=function(_,w,h)draw.RoundedBox(9,0,0,w,h,C.panel);draw.RoundedBox(6,8,8,w-16,60,Color(12,20,35));surface.SetMaterial(Material("icon16/computer.png"));surface.SetDrawColor(C.blue);surface.DrawTexturedRect(16,18,32,32);draw.SimpleText(tostring(data.name),"GRMNet_Small",56,20,C.text);draw.SimpleText(tostring(current.deviceID):sub(1,16),"GRMNet_Tiny",56,38,C.dim)end
 local body=vgui.Create("DPanel",f);body:SetPos(216,62);body:SetSize(830,640);body.Paint=function(_,w,h)draw.RoundedBox(9,0,0,w,h,C.panel)end
 local function clear()body:Clear()end
 -- Login
 local function loginPage()
  clear()
  
  -- Internet connection indicator (prominent at top)
  local connPanel=vgui.Create("DPanel",body)
  connPanel:SetPos(0,0)
  connPanel:SetSize(830,50)
  connPanel.Paint=function(_,w,h)
   local bgColor=data.online and Color(20,60,30)or Color(60,20,20)
   draw.RoundedBoxEx(8,0,0,w,h,bgColor,true,true,false,false)
   local icon=data.online and"🌐"or"⚠"
   local statusText=data.online and"ИНТЕРНЕТ: ПОДКЛЮЧЕНО"or"НЕТ ПОДКЛЮЧЕНИЯ К ИНТЕРНЕТУ"
   local textColor=data.online and Color(100,255,100)or Color(255,100,100)
   draw.SimpleText(icon.." "..statusText,"GRMNet_Head",w/2,20,textColor,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
   if not data.online then
    draw.SimpleText("Подключитесь к Wi-Fi через роутер для доступа к сети","GRMNet_Small",w/2,38,C.dim,TEXT_ALIGN_CENTER)
   end
  end
  
  -- Login form
  local logo=vgui.Create("DPanel",body)
  logo:SetPos(180,70)
  logo:SetSize(420,380)
  logo.Paint=function(_,w,h)
   draw.RoundedBox(14,0,0,w,h,Color(14,22,38))
   surface.SetDrawColor(C.blue)
   surface.DrawOutlinedRect(0,0,w,h,2)
   draw.SimpleText("GRM NET","GRMNet_Title",w/2,40,C.blue,TEXT_ALIGN_CENTER)
   draw.SimpleText("ОПЕРАЦИОННАЯ СИСТЕМА","GRMNet_Small",w/2,68,C.dim,TEXT_ALIGN_CENTER)
   surface.SetMaterial(Material("icon16/shield.png"))
   surface.SetDrawColor(C.blue)
   surface.DrawTexturedRect(w/2-32,90,64,64)
   draw.SimpleText("АВТОРИЗАЦИЯ","GRMNet_Head",w/2,170,C.text,TEXT_ALIGN_CENTER)
  end
  
  local user=entry(body,"Логин",230,260,320,38)
  local pass=secureEntry(body,"Пароль",230,310,320,38)
  
  btn(body,"ВОЙТИ",230,362,150,44,C.blue,function()
   if not data.online then
    notification.AddLegacy("Нет подключения к интернету!",NOTIFY_ERROR,4)
    return
   end
   send(ent,"login",function()net.WriteString(user:GetText());net.WriteString(pass:GetText())end)
  end)
  
  btn(body,"РЕГИСТРАЦИЯ",390,362,160,44,C.green,function()
   if not data.online then
    notification.AddLegacy("Нет подключения к интернету!",NOTIFY_ERROR,4)
    return
   end
   send(ent,"register",function()net.WriteString(user:GetText());net.WriteString(pass:GetText())end)
  end)
  
  -- Info panel
  local infoPanel=vgui.Create("DPanel",body)
  infoPanel:SetPos(180,470)
  infoPanel:SetSize(420,120)
  infoPanel.Paint=function(_,w,h)
   draw.RoundedBox(8,0,0,w,h,Color(20,30,45))
   draw.SimpleText("💡 Информация:","GRMNet_Small",12,12,C.blue)
   draw.SimpleText("• Устройство: "..tostring(current.deviceID):sub(1,24),"GRMNet_Tiny",12,30,C.dim)
   draw.SimpleText("• Сессия привязана к этому устройству","GRMNet_Tiny",12,44,C.dim)
   draw.SimpleText("• При переходе на другой ПК нужна новая авторизация","GRMNet_Tiny",12,58,C.dim)
   draw.SimpleText("• Логин: от 3 символов | Пароль: от 5 символов","GRMNet_Tiny",12,72,C.dim)
   draw.SimpleText("• Все данные хранятся локально на устройстве","GRMNet_Tiny",12,86,C.dim)
   draw.SimpleText("• Файлы и почта привязаны к этому компьютеру","GRMNet_Tiny",12,100,C.dim)
  end
 end
 -- Wi-Fi
 local function wifiPage()clear();textLabel(body,"ПОДКЛЮЧЕНИЕ К WI-FI",200,20,410,36,"GRMNet_Title",C.text);textLabel(body,"Введите SSID и пароль настроенного роутера",200,56,460,24,"GRMNet_Body",C.dim);local ssid=entry(body,"SSID сети",200,100,410,38);local password=secureEntry(body,"Пароль Wi-Fi",200,150,410,38);btn(body,"ПОДКЛЮЧИТЬСЯ",200,210,410,44,C.blue,function()send(ent,"connect",function()net.WriteString(ssid:GetText());net.WriteString(password:GetText())end)end)end
 -- Files
 local function filesPage(files)
  clear();current.files=files or current.files or{};local headBar=vgui.Create("DPanel",body);headBar:SetPos(0,0);headBar:SetSize(830,44);headBar.Paint=function(_,w,h)draw.RoundedBoxEx(9,0,0,w,h,Color(14,22,38),true,true,false,false);surface.SetMaterial(ICONS.Files);surface.SetDrawColor(C.blue);surface.DrawTexturedRect(16,10,24,24);draw.SimpleText("ФАЙЛОВЫЙ МЕНЕДЖЕР","GRMNet_Head",48,22,C.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER);draw.SimpleText(tostring(current.deviceID):sub(1,24),"GRMNet_Small",w-16,22,C.dim,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)end
  local list=darkList(body,14,52,310,500,{{"Файл",160},{"Владелец",85},{"КБ",42}});for _,r in ipairs(current.files)do local line=addLine(list,r.name,r.owner,math.ceil((r.size or 0)/1024));line._file=r end
  local name=entry(body,"Название документа",340,52,470,34);local content=entry(body,"Текст файла",340,96,470,260,true);local selectedID=""
  list.OnRowSelected=function(_,_,line)selectedID=line._file.id;send(ent,"file_open",function()net.WriteString(selectedID)end)end
  local share=entry(body,"Логин получателя",340,418,240,34);btn(body,"Передать",590,418,160,34,C.blue,function()send(ent,"file_share",function()net.WriteString(selectedID);net.WriteString(share:GetText())end)end)
  -- Printer section with visual settings
  local printPanel=vgui.Create("DPanel",body);printPanel:SetPos(340,464);printPanel:SetSize(470,166);printPanel.Paint=function(_,w,h)draw.RoundedBox(8,0,0,w,h,Color(14,22,38));surface.SetMaterial(ICONS.Print);surface.SetDrawColor(C.yellow);surface.DrawTexturedRect(14,12,22,22);draw.SimpleText("ПЕЧАТЬ ДОКУМЕНТА","GRMNet_Head",44,22,C.yellow,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)end
  local printer=vgui.Create("DComboBox",printPanel);printer:SetPos(14,44);printer:SetSize(220,30);printer.PrinterID="";for _,d in ipairs(E.Topology.devices or{})do if d.kind=="printer"and d.online then printer:AddChoice("🖨 "..d.name,d.id)end end;printer.OnSelect=function(_,_,_,id)printer.PrinterID=id end
  local paper=vgui.Create("DComboBox",printPanel);paper:SetPos(244,44);paper:SetSize(100,30);paper:AddChoice("A4","A4");paper:AddChoice("A5","A5");paper:AddChoice("Letter","Letter");paper:ChooseOptionID(1)
  local orient=vgui.Create("DComboBox",printPanel);orient:SetPos(354,44);orient:SetSize(100,30);orient:AddChoice("Книжная","portrait");orient:AddChoice("Альбом.","landscape");orient:ChooseOptionID(1)
  local copiesLabel=vgui.Create("DLabel",printPanel);copiesLabel:SetPos(14,84);copiesLabel:SetSize(60,26);copiesLabel:SetText("Копий:");copiesLabel:SetFont("GRMNet_Small");copiesLabel:SetTextColor(C.dim)
  local copies=vgui.Create("DNumberWang",printPanel);copies:SetPos(76,82);copies:SetSize(50,28);copies:SetMin(1);copies:SetMax(10);copies:SetValue(1)
  local quality=vgui.Create("DComboBox",printPanel);quality:SetPos(140,82);quality:SetSize(120,28);quality:AddChoice("Черновик","draft");quality:AddChoice("Обычное","normal");quality:AddChoice("Высокое","high");quality:ChooseOptionID(2)
  btn(printPanel,"ПЕЧАТАТЬ",300,82,156,28,C.yellow,function()send(ent,"print",function()net.WriteString(selectedID);net.WriteString(printer.PrinterID);local _,pd=paper:GetSelected();net.WriteString(pd or"A4");local _,od=orient:GetSelected();net.WriteString(od or"portrait");net.WriteUInt(copies:GetValue(),4);local _,qd=quality:GetSelected();net.WriteString(qd or"normal")end)end)
  -- Print preview
  local preview=vgui.Create("DPanel",printPanel);preview:SetPos(300,116);preview:SetSize(156,42);preview.Paint=function(_,w,h)
   draw.RoundedBox(4,0,0,w,h,Color(240,240,230));local _,pd=paper:GetSelected();local landscape=orient:GetText()=="Альбом."
   if landscape then draw.RoundedBox(2,8,4,w-16,h-8,Color(255,255,255));for i=1,4 do surface.SetDrawColor(200,200,200);surface.DrawLine(14,8+i*7,w-14,8+i*7)end else draw.RoundedBox(2,w/2-20,4,40,h-8,Color(255,255,255));for i=1,4 do surface.SetDrawColor(200,200,200);surface.DrawLine(w/2-16,8+i*7,w/2+16,8+i*7)end end
   draw.SimpleText(pd or"A4","GRMNet_Tiny",w/2,h-4,Color(120,120,120),TEXT_ALIGN_CENTER,TEXT_ALIGN_BOTTOM)
  end
  body._fileName=name;body._fileContent=content
 end
 -- Modules
 local function modulesPage()clear();textLabel(body,"Сетевые модули",18,10,300,28,"GRMNet_Title",C.text);textLabel(body,"Интеграция с системами сервера",18,38,400,20,"GRMNet_Small",C.dim);local modules={{"Фракция","Состав и принадлежность","faction","icon16/group.png",C.blue},{"Аресты","Текущие задержанные","arrest","icon16/lock.png",C.red},{"Розыск / штрафы","Объявление в розыск","fines","icon16/money.png",C.yellow},{"CCTV","Камеры и сети","cctv","icon16/camera.png",C.green},{"Прослушка","RoomTap интеграция","roomtap","icon16/sound.png",C.purple}};for i,m in ipairs(modules)do local col=(i-1)%3;local row=math.floor((i-1)/3);appTile(body,m[1],m[2],m[4],18+col*204,64+row*122,m[5],function()
    if m[3]=="fines"then
     -- Open existing wanted system
     if GRM.Wanted and GRM.Wanted.OpenMenu then
      GRM.Wanted.OpenMenu()
      if IsValid(E.ActiveFrame)then E.ActiveFrame:Close()end
     else
      notification.AddLegacy("Система розыска недоступна",NOTIFY_ERROR,4)
     end
    elseif m[3]=="arrest"then
     -- Open existing arrest system
     if GRM.Arrest and GRM.Arrest.OpenAdmin then
      net.Start("GRM_Arrest_Admin")
      net.SendToServer()
      if IsValid(E.ActiveFrame)then E.ActiveFrame:Close()end
     else
      notification.AddLegacy("Система арестов недоступна",NOTIFY_ERROR,4)
     end
    elseif m[3]=="cctv"then
     -- Open existing CCTV system
     if GRM.CCTV and GRM.CCTV.AccessManager and GRM.CCTV.AccessManager.OpenMenu then
      GRM.CCTV.AccessManager.OpenMenu()
      if IsValid(E.ActiveFrame)then E.ActiveFrame:Close()end
     else
      notification.AddLegacy("Система CCTV недоступна",NOTIFY_ERROR,4)
     end
    elseif m[3]=="faction"then
     -- Open existing faction system
     RunConsoleCommand("factions")
     if IsValid(E.ActiveFrame)then E.ActiveFrame:Close()end
    elseif m[3]=="roomtap"then
     -- Open existing roomtap system
     RunConsoleCommand("roomtap_access")
     if IsValid(E.ActiveFrame)then E.ActiveFrame:Close()end
    else
     send(ent,"module",function()net.WriteString(m[3])end)
    end
   end)end;local output=entry(body,"Результат выбранного приложения",18,320,794,296,true);output:SetEditable(false);body._moduleOutput=output end
 -- Calculator (improved)
 local function calcPage()
  clear();textLabel(body,"КАЛЬКУЛЯТОР",18,10,200,28,"GRMNet_Title",C.text)
  local display=vgui.Create("DPanel",body);display:SetPos(18,48);display:SetSize(580,80);display.Value="0";display.History="";display.Paint=function(_,w,h)
   draw.RoundedBox(8,0,0,w,h,Color(10,18,30));surface.SetDrawColor(C.blue);surface.DrawOutlinedRect(0,0,w,h,1)
   draw.SimpleText(display.History,"GRMNet_CalcHist",w-16,14,C.dim,TEXT_ALIGN_RIGHT);draw.SimpleText(display.Value,"GRMNet_Calc",w-16,50,C.text,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
  end
  local keys={{"7","8","9","÷"},{"4","5","6","×"},{"1","2","3","-"},{"0",".","=","+"},{"C","⌫","(",")"}};local btnW=136;local btnH=60
  for row,rowKeys in ipairs(keys)do for col,key in ipairs(rowKeys)do
   local bx=18+(col-1)*(btnW+6);local by=138+(row-1)*(btnH+6)
   local isNum=key:match("[%d%.]");local isOp=("+-×÷"):find(key,1,true);local isEq=key=="=";local isC=key=="C";local isBsp=key=="⌫"
   local col2=isEq and C.blue or isC and C.red or isBsp and C.orange or isOp and C.yellow or C.card
   local b=vgui.Create("DButton",body);b:SetPos(bx,by);b:SetSize(btnW,btnH);b:SetText("")
   b.DoClick=function()surface.PlaySound(isEq and"buttons/button14.wav"or isC and"buttons/button10.wav"or"buttons/button15.wav");local v=display.Value
    if isC then display.Value="0";display.History=""
    elseif isBsp then display.Value=#v>1 and string.sub(v,1,-2)or"0"
    elseif isEq then local expr=v:gsub("×","*"):gsub("÷","/");local ok,res=pcall(function()return CompileString("return "..expr,"calc",false)()end);display.History=v.." =";display.Value=ok and tostring(res)or"Ошибка"
    else display.Value=(v=="0"and isNum)and key or v..key end
   end
   b.Paint=function(self,w,h)local c=self:IsDown()and Color(18,28,44)or(self:IsHovered()and C.hover or col2);draw.RoundedBox(10,0,0,w,h,c);surface.SetDrawColor(self:IsHovered()and Color(110,175,245)or Color(45,65,90));surface.DrawOutlinedRect(0,0,w,h,1);draw.SimpleText(key,isNum and"GRMNet_Head"or"GRMNet_Title",w/2,h/2,isEq and Color(255,255,255)or C.text,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)end
  end end
  -- History panel
  local hist=vgui.Create("DPanel",body);hist:SetPos(614,48);hist:SetSize(200,544);hist.Paint=function(_,w,h)draw.RoundedBox(8,0,0,w,h,Color(14,22,38));draw.SimpleText("ИСТОРИЯ","GRMNet_Small",w/2,8,C.dim,TEXT_ALIGN_CENTER)end
 end
 -- Notes (improved)
 local function notesPage()
  clear();textLabel(body,"ЗАМЕТКИ",18,10,200,28,"GRMNet_Title",C.text)
  local list=darkList(body,18,42,250,570,{{"Заметка",195},{"Дата",47}})
  local noteContent=entry(body,"Текст заметки...",284,42,528,460,true)
  local noteName=entry(body,"Заголовок",284,512,340,34)
  local selectedNoteID=""
  local function loadNotes()list:Clear();for _,r in ipairs(current.files)do if r.category=="note"then local line=addLine(list,r.name,os.date("%d.%m",r.updated));line._file=r end end end;loadNotes()
  list.OnRowSelected=function(_,_,line)selectedNoteID=line._file.id;send(ent,"file_open",function()net.WriteString(selectedNoteID)end)end
  btn(body,"Новая",636,512,84,34,C.blue,function()selectedNoteID="";noteName:SetText("");noteContent:SetText("")end)
  btn(body,"Сохранить",730,512,84,34,C.green,function()send(ent,"file_save",function()net.WriteString(selectedNoteID);net.WriteString(noteName:GetText());net.WriteString(noteContent:GetText());net.WriteString("note")end)end)
  btn(body,"Удалить",636,554,178,34,C.red,function()send(ent,"file_delete",function()net.WriteString(selectedNoteID)end)end)
  -- Quick stats
  local statsPanel=vgui.Create("DPanel",body);statsPanel:SetPos(284,596);statsPanel:SetSize(528,22);statsPanel.Paint=function(_,w,h)draw.RoundedBox(4,0,0,w,h,Color(14,22,38));local count=0;for _,r in ipairs(current.files)do if r.category=="note"then count=count+1 end end;draw.SimpleText("Заметок: "..count,"GRMNet_Small",12,11,C.dim,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)end
  body._noteName=noteName;body._noteContent=noteContent;body._reloadNotes=loadNotes
 end
 -- Text Editor (improved)
 local function editorPage()
  clear();textLabel(body,"ТЕКСТОВЫЙ РЕДАКТОР",18,10,300,28,"GRMNet_Title",C.text)
  local toolbar=vgui.Create("DPanel",body);toolbar:SetPos(18,42);toolbar:SetSize(794,36);toolbar.Paint=function(_,w,h)draw.RoundedBox(6,0,0,w,h,Color(15,24,38));surface.SetDrawColor(Color(40,55,75));surface.DrawLine(0,h-1,w,h-1)end
  local area=entry(body,"Начните вводить текст...",18,84,794,500,true)
  local docName=entry(body,"Название документа",18,594,400,30)
  local tbBtns={{"B","Жирный",function()local t=area:GetText();area:SetText(t.."**жирный**")end},{"I","Курсив",function()local t=area:GetText();area:SetText(t.."_курсив_")end},{"H","# Заголовок",function()local t=area:GetText();area:SetText(t.."\n# Заголовок\n")end},{"•","Список",function()local t=area:GetText();area:SetText(t.."\n  • пункт")end},{"☰","Шаблон",function()area:SetText("ДОКУМЕНТ\n═══════════\n\nДата: "..os.date("%d.%m.%Y").."\nАвтор: "..tostring(current.data.logged or"").."\n\n---\n\n")end},{"✕","Очистить",function()area:SetText("")end}}
  for i,tb in ipairs(tbBtns)do local bx=4+(i-1)*132;local b=vgui.Create("DButton",toolbar);b:SetPos(bx,4);b:SetSize(126,28);b:SetText("");b.DoClick=function()surface.PlaySound("buttons/button15.wav");tb[3]()end;b.Paint=function(self,w,h)local c=self:IsDown()and Color(20,32,50)or(self:IsHovered()and C.hover or C.card);draw.RoundedBox(5,0,0,w,h,c);draw.SimpleText(tb[1],"GRMNet_Body",8,h/2,C.blue,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER);draw.SimpleText(tb[2],"GRMNet_Small",28,h/2,C.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)end end
  local selectedDocID=""
  btn(body,"Сохранить",430,594,120,30,C.green,function()send(ent,"file_save",function()net.WriteString(selectedDocID);net.WriteString(docName:GetText());net.WriteString(area:GetText());net.WriteString("doc")end)end)
  btn(body,"Файлы",560,594,120,30,C.blue,function()send(ent,"files")end)
  -- Status bar
  local statusBar=vgui.Create("DPanel",body);statusBar:SetPos(18,630);statusBar:SetSize(794,14);statusBar.Paint=function(_,w,h)draw.RoundedBox(3,0,0,w,h,Color(14,22,38));local text=area:GetText()or"";local chars=#text;local lines=select(2,string.gsub(text,"\n",""))+1;draw.SimpleText("Символов: "..chars.."  |  Строк: "..lines,"GRMNet_Tiny",8,h/2,C.dim,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)end
  body._editorArea=area;body._editorName=docName
 end
 -- Photo Robot (drawn composite sketch)
 local function photoGallery()
  -- Show gallery of saved photo robots first
  clear()
  textLabel(body,"ФОТОРОБОТ",18,10,200,28,"GRMNet_Title",C.text)
  textLabel(body,"Галерея сохранённых фотороботов",18,38,400,20,"GRMNet_Small",C.dim)
  
  -- Gallery list
  local list=darkList(body,18,70,500,480,{{"Название",240},{"Дата",100},{"Размер",80},{"Тип",70}})
  
  -- Load saved photos
  local function loadGallery()
   list:Clear()
   for _,r in ipairs(current.files)do
    if r.category=="photo"or r.category=="photo_print"then
     local line=addLine(list,r.name,os.date("%d.%m",r.updated),math.ceil((r.size or 0)/1024).."KB",r.category=="photo"and"Сохранён"or"Печать")
     line._file=r
    end
   end
  end
  
  -- Selected photo
  local selectedFile=nil
  list.OnRowSelected=function(_,_,line)selectedFile=line._file end
  
  -- Action buttons
  btn(body,"НОВЫЙ ФОТОРОБОТ",534,70,280,40,C.blue,function()
   -- Open editor
   if E._photoEditor then E._photoEditor() end
  end)
  
  btn(body,"ОТКРЫТЬ",534,120,280,36,C.green,function()
   if not selectedFile then notification.AddLegacy("Выберите фоторобот из списка",NOTIFY_ERROR,3)return end
   -- Open the selected photo
   send(ent,"file_open",function()net.WriteString(selectedFile.id)end)
  end)
  
  btn(body,"УДАЛИТЬ",534,166,280,36,C.red,function()
   if not selectedFile then notification.AddLegacy("Выберите фоторобот из списка",NOTIFY_ERROR,3)return end
   send(ent,"file_delete",function()net.WriteString(selectedFile.id)end)
   timer.Simple(0.5,loadGallery)
  end)
  
  btn(body,"Обновить список",534,212,280,32,C.card,loadGallery)
  
  -- Info panel
  local infoPanel=vgui.Create("DPanel",body)
  infoPanel:SetPos(534,254)
  infoPanel:SetSize(280,296)
  infoPanel.Paint=function(_,w,h)
   draw.RoundedBox(8,0,0,w,h,Color(14,22,38))
   draw.SimpleText("ИНФОРМАЦИЯ","GRMNet_Head",w/2,16,C.text,TEXT_ALIGN_CENTER)
   if selectedFile then
    draw.SimpleText("Название: "..selectedFile.name,"GRMNet_Body",20,50,C.text)
    draw.SimpleText("Владелец: "..selectedFile.owner,"GRMNet_Small",20,74,C.dim)
    draw.SimpleText("Дата: "..os.date("%d.%m.%Y %H:%M",selectedFile.updated),"GRMNet_Small",20,94,C.dim)
    draw.SimpleText("Тип: "..(selectedFile.category=="photo"and"Сохранён"or"Печать"),"GRMNet_Small",20,114,C.dim)
    draw.SimpleText("Размер: "..math.ceil((selectedFile.size or 0)/1024).." KB","GRMNet_Small",20,134,C.dim)
   else
    draw.SimpleText("Выберите фоторобот","GRMNet_Body",w/2,140,C.dim,TEXT_ALIGN_CENTER)
    draw.SimpleText("из списка слева","GRMNet_Small",w/2,164,C.dim,TEXT_ALIGN_CENTER)
   end
  end
  
  -- Stats
  local statsPanel=vgui.Create("DPanel",body)
  statsPanel:SetPos(18,560)
  statsPanel:SetSize(500,22)
  statsPanel.Paint=function(_,w,h)
   draw.RoundedBox(4,0,0,w,h,Color(14,22,38))
   local count=0
   for _,r in ipairs(current.files)do
    if r.category=="photo"or r.category=="photo_print"then count=count+1 end
   end
   draw.SimpleText("Всего фотороботов: "..count,"GRMNet_Small",12,11,C.dim,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  end
  
  -- Load gallery with current files
  loadGallery()
 end
 
 -- Save reference for net.Receive handler
 E._photoGallery = photoGallery
 
 local function photoPage()
  -- Request files first, then show gallery
  net.Start("GRM_Net_Action")
  net.WriteEntity(ent)
  net.WriteString("files")
  net.SendToServer()
  
  -- Set flag to show gallery instead of files page
  E._showPhotoGallery=true
  
  -- Show gallery immediately with current files (will update when response arrives)
  photoGallery()
 end
 
 local function photoEditor()
  clear();textLabel(body,"РЕДАКТОР ФОТОРОБОТА",18,10,300,28,"GRMNet_Title",C.text);textLabel(body,"Система составления фоторобота · GRM Police Sketch",18,38,500,20,"GRMNet_Small",C.dim)
  
  -- Back button
  btn(body,"◄ К ГАЛЕРЕЕ",650,10,164,28,C.card,function()
   photoGallery()
  end)
  -- State
  local state={face=1,hair=1,eyes=1,brows=1,nose=1,mouth=1,chin=1,extras=0,gender="male",effect="normal"}
  -- Drawn face parts database (styled after GMod citizens)
  local faceParts={
   face={
    {name="Овальное",draw=function(cx,cy,s,col)draw.RoundedBox(90*s,cx-55*s,cy-70*s,110*s,150*s,col)end},
    {name="Квадратное",draw=function(cx,cy,s,col)draw.RoundedBox(20*s,cx-58*s,cy-68*s,116*s,148*s,col)end},
    {name="Круглое",draw=function(cx,cy,s,col)draw.RoundedBox(75*s,cx-60*s,cy-60*s,120*s,130*s,col)end},
    {name="Длинное",draw=function(cx,cy,s,col)draw.RoundedBox(55*s,cx-48*s,cy-75*s,96*s,160*s,col)end},
    {name="Худое",draw=function(cx,cy,s,col)draw.RoundedBox(45*s,cx-42*s,cy-68*s,84*s,146*s,col)end},
    {name="Широкое",draw=function(cx,cy,s,col)draw.RoundedBox(60*s,cx-65*s,cy-60*s,130*s,135*s,col)end}
   },
   hair={
    {name="Короткая",draw=function(cx,cy,s,col)draw.RoundedBox(40*s,cx-58*s,cy-78*s,116*s,50*s,col);draw.RoundedBox(4*s,cx-60*s,cy-55*s,10*s,30*s,col);draw.RoundedBox(4*s,cx+50*s,cy-55*s,10*s,30*s,col)end},
    {name="Зачёс назад",draw=function(cx,cy,s,col)draw.RoundedBox(30*s,cx-55*s,cy-80*s,110*s,35*s,col);for i=0,6 do draw.RoundedBox(3*s,cx-50*s+i*16*s,cy-82*s,10*s,40*s,col)end end},
    {name="Длинная",draw=function(cx,cy,s,col)draw.RoundedBox(10*s,cx-62*s,cy-78*s,124*s,130*s,col);draw.RoundedBox(80*s,cx-50*s,cy-60*s,100*s,110*s,Color(col.r+40,col.g+35,col.b+30))end},
    {name="Лысый",draw=function(cx,cy,s,col)end},
    {name="Ёжик",draw=function(cx,cy,s,col)for i=0,8 do draw.RoundedBox(2*s,cx-48*s+i*12*s,cy-80*s,6*s,18*s,col)end end},
    {name="Кудри",draw=function(cx,cy,s,col)for i=0,7 do for j=0,2 do draw.RoundedBox(10*s,cx-52*s+i*15*s,cy-82*s+j*12*s,14*s,14*s,col)end end end},
    {name="Пробор",draw=function(cx,cy,s,col)draw.RoundedBox(6*s,cx-58*s,cy-76*s,54*s,45*s,col);draw.RoundedBox(6*s,cx+4*s,cy-76*s,54*s,45*s,col)end},
    {name="Хвост",draw=function(cx,cy,s,col)draw.RoundedBox(35*s,cx-55*s,cy-76*s,110*s,35*s,col);draw.RoundedBox(8*s,cx+40*s,cy-60*s,16*s,60*s,col)end}
   },
   eyes={
    {name="Обычные",draw=function(cx,cy,s,col)draw.RoundedBox(10*s,cx-35*s,cy-20*s,28*s,16*s,Color(255,255,255));draw.RoundedBox(10*s,cx+7*s,cy-20*s,28*s,16*s,Color(255,255,255));draw.RoundedBox(8*s,cx-26*s,cy-16*s,12*s,10*s,col);draw.RoundedBox(8*s,cx+16*s,cy-16*s,12*s,10*s,col);draw.RoundedBox(4*s,cx-22*s,cy-14*s,5*s,5*s,Color(20,20,20));draw.RoundedBox(4*s,cx+20*s,cy-14*s,5*s,5*s,Color(20,20,20))end},
    {name="Узкие",draw=function(cx,cy,s,col)draw.RoundedBox(6*s,cx-35*s,cy-16*s,30*s,10*s,Color(255,255,255));draw.RoundedBox(6*s,cx+5*s,cy-16*s,30*s,10*s,Color(255,255,255));draw.RoundedBox(4*s,cx-24*s,cy-14*s,10*s,7*s,col);draw.RoundedBox(4*s,cx+16*s,cy-14*s,10*s,7*s,col)end},
    {name="Большие",draw=function(cx,cy,s,col)draw.RoundedBox(14*s,cx-38*s,cy-24*s,34*s,24*s,Color(255,255,255));draw.RoundedBox(14*s,cx+4*s,cy-24*s,34*s,24*s,Color(255,255,255));draw.RoundedBox(12*s,cx-28*s,cy-18*s,16*s,14*s,col);draw.RoundedBox(12*s,cx+12*s,cy-18*s,16*s,14*s,col);draw.RoundedBox(4*s,cx-24*s,cy-14*s,8*s,7*s,Color(20,20,20));draw.RoundedBox(4*s,cx+16*s,cy-14*s,8*s,7*s,Color(20,20,20))end},
    {name="Грустные",draw=function(cx,cy,s,col)draw.RoundedBox(10*s,cx-35*s,cy-18*s,28*s,14*s,Color(255,255,255));draw.RoundedBox(10*s,cx+7*s,cy-18*s,28*s,14*s,Color(255,255,255));surface.SetDrawColor(col);surface.DrawLine(cx-36*s,cy-22*s,cx-8*s,cy-16*s);surface.DrawLine(cx+8*s,cy-16*s,cx+36*s,cy-22*s);draw.RoundedBox(6*s,cx-26*s,cy-16*s,10*s,8*s,col);draw.RoundedBox(6*s,cx+16*s,cy-16*s,10*s,8*s,col)end},
    {name="Злые",draw=function(cx,cy,s,col)draw.RoundedBox(8*s,cx-34*s,cy-18*s,28*s,14*s,Color(255,255,255));draw.RoundedBox(8*s,cx+6*s,cy-18*s,28*s,14*s,Color(255,255,255));surface.SetDrawColor(col);surface.DrawLine(cx-36*s,cy-14*s,cx-8*s,cy-22*s);surface.DrawLine(cx+8*s,cy-22*s,cx+36*s,cy-14*s);draw.RoundedBox(6*s,cx-24*s,cy-16*s,10*s,8*s,Color(180,40,40));draw.RoundedBox(6*s,cx+16*s,cy-16*s,10*s,8*s,Color(180,40,40))end},
    {name="Маленькие",draw=function(cx,cy,s,col)draw.RoundedBox(6*s,cx-30*s,cy-16*s,18*s,10*s,Color(255,255,255));draw.RoundedBox(6*s,cx+12*s,cy-16*s,18*s,10*s,Color(255,255,255));draw.RoundedBox(4*s,cx-24*s,cy-14*s,7*s,6*s,col);draw.RoundedBox(4*s,cx+18*s,cy-14*s,7*s,6*s,col)end}
   },
   brows={
    {name="Обычные",draw=function(cx,cy,s,col)surface.SetDrawColor(col);surface.DrawLine(cx-38*s,cy-30*s,cx-8*s,cy-32*s);surface.DrawLine(cx+8*s,cy-32*s,cx+38*s,cy-30*s)end},
    {name="Густые",draw=function(cx,cy,s,col)draw.RoundedBox(3*s,cx-40*s,cy-34*s,34*s,8*s,col);draw.RoundedBox(3*s,cx+6*s,cy-34*s,34*s,8*s,col)end},
    {name="Тонкие",draw=function(cx,cy,s,col)surface.SetDrawColor(col);surface.DrawLine(cx-36*s,cy-30*s,cx-8*s,cy-31*s);surface.DrawLine(cx+8*s,cy-31*s,cx+36*s,cy-30*s)end},
    {name="Злые",draw=function(cx,cy,s,col)surface.SetDrawColor(col);surface.DrawLine(cx-38*s,cy-26*s,cx-8*s,cy-34*s);surface.DrawLine(cx+8*s,cy-34*s,cx+38*s,cy-26*s)end},
    {name="Дугой",draw=function(cx,cy,s,col)surface.SetDrawColor(col);for i=0,8 do local t=i/8;surface.DrawLine(cx-38*s+i*3.5*s,cy-30*s-math.sin(t*3.14)*6*s,cx-38*s+(i+1)*3.5*s,cy-30*s-math.sin((t+0.125)*3.14)*6*s)end;for i=0,8 do local t=i/8;surface.DrawLine(cx+8*s+i*3.5*s,cy-30*s-math.sin(t*3.14)*6*s,cx+8*s+(i+1)*3.5*s,cy-30*s-math.sin((t+0.125)*3.14)*6*s)end end}
   },
   nose={
    {name="Прямой",draw=function(cx,cy,s,col)surface.SetDrawColor(col.r-30,col.g-30,col.b-30);surface.DrawLine(cx,cy-8*s,cx-6*s,cy+18*s);surface.DrawLine(cx-6*s,cy+18*s,cx+6*s,cy+18*s);surface.DrawLine(cx+6*s,cy+18*s,cx,cy-8*s)end},
    {name="Широкий",draw=function(cx,cy,s,col)draw.RoundedBox(6*s,cx-12*s,cy-4*s,24*s,24*s,Color(col.r-20,col.g-20,col.b-20))end},
    {name="Длинный",draw=function(cx,cy,s,col)surface.SetDrawColor(col.r-30,col.g-30,col.b-30);surface.DrawLine(cx-2*s,cy-12*s,cx-8*s,cy+24*s);surface.DrawLine(cx+2*s,cy-12*s,cx+8*s,cy+24*s);surface.DrawLine(cx-8*s,cy+24*s,cx+8*s,cy+24*s)end},
    {name="Кнопкой",draw=function(cx,cy,s,col)draw.RoundedBox(8*s,cx-8*s,cy+4*s,16*s,14*s,Color(col.r-20,col.g-20,col.b-20))end},
    {name="Горбинкой",draw=function(cx,cy,s,col)surface.SetDrawColor(col.r-30,col.g-30,col.b-30);surface.DrawLine(cx,cy-10*s,cx+6*s,cy+4*s);surface.DrawLine(cx+6*s,cy+4*s,cx-4*s,cy+20*s);surface.DrawLine(cx-4*s,cy+20*s,cx+6*s,cy+20*s)end}
   },
   mouth={
    {name="Прямой",draw=function(cx,cy,s,col)surface.SetDrawColor(col);surface.DrawLine(cx-20*s,cy+35*s,cx+20*s,cy+35*s)end},
    {name="Улыбка",draw=function(cx,cy,s,col)draw.RoundedBox(12*s,cx-18*s,cy+28*s,36*s,14*s,col)end},
    {name="Открытый",draw=function(cx,cy,s,col)draw.RoundedBox(10*s,cx-14*s,cy+30*s,28*s,16*s,Color(40,20,20));surface.SetDrawColor(col);surface.DrawOutlinedRect(cx-14*s,cy+30*s,28*s,16*s,2)end},
    {name="Тонкий",draw=function(cx,cy,s,col)surface.SetDrawColor(col);surface.DrawLine(cx-16*s,cy+35*s,cx+16*s,cy+35*s)end},
    {name="Полный",draw=function(cx,cy,s,col)draw.RoundedBox(8*s,cx-16*s,cy+30*s,32*s,12*s,Color(col.r+15,col.g-10,col.b-10))end},
    {name="Кривой",draw=function(cx,cy,s,col)surface.SetDrawColor(col);surface.DrawLine(cx-18*s,cy+33*s,cx,cy+36*s);surface.DrawLine(cx,cy+36*s,cx+18*s,cy+32*s)end}
   },
   chin={
    {name="Обычный",draw=function(cx,cy,s,col)end},
    {name="Волевой",draw=function(cx,cy,s,col)draw.RoundedBox(4*s,cx-40*s,cy+55*s,80*s,20*s,Color(col.r-10,col.g-10,col.b-10))end},
    {name="Двойной",draw=function(cx,cy,s,col)draw.RoundedBox(30*s,cx-35*s,cy+60*s,70*s,25*s,Color(col.r-15,col.g-15,col.b-15))end},
    {name="Острый",draw=function(cx,cy,s,col)draw.RoundedBox(4*s,cx-8*s,cy+65*s,16*s,15*s,Color(col.r-10,col.g-10,col.b-10))end}
   },
   extras={
    {name="Нет",draw=function()end},
    {name="Шрам",draw=function(cx,cy,s,col)surface.SetDrawColor(180,80,80);surface.DrawLine(cx-25*s,cy-10*s,cx+15*s,cy+30*s);surface.DrawLine(cx-23*s,cy-10*s,cx+17*s,cy+30*s)end},
    {name="Родинка",draw=function(cx,cy,s,col)draw.RoundedBox(4*s,cx+22*s,cy+5*s,6*s,6*s,Color(60,40,30))end},
    {name="Борода",draw=function(cx,cy,s,col)draw.RoundedBox(20*s,cx-38*s,cy+25*s,76*s,50*s,Color(70,50,35,200))end},
    {name="Щетина",draw=function(cx,cy,s,col)for i=0,12 do for j=0,4 do draw.RoundedBox(1*s,cx-35*s+i*6*s,cy+28*s+j*6*s,2*s,2*s,Color(80,60,40,150))end end end},
    {name="Очки",draw=function(cx,cy,s,col)surface.SetDrawColor(40,40,50);surface.DrawOutlinedRect(cx-40*s,cy-24*s,34*s,22*s,3);surface.DrawOutlinedRect(cx+6*s,cy-24*s,34*s,22*s,3);surface.DrawLine(cx-6*s,cy-14*s,cx+6*s,cy-14*s);surface.DrawLine(cx-40*s,cy-14*s,cx-52*s,cy-18*s);surface.DrawLine(cx+40*s,cy-14*s,cx+52*s,cy-18*s)end},
    {name="Усы",draw=function(cx,cy,s,col)draw.RoundedBox(4*s,cx-20*s,cy+22*s,40*s,8*s,Color(70,50,35))end},
    {name="Серёжка",draw=function(cx,cy,s,col)draw.RoundedBox(3*s,cx-55*s,cy-5*s,5*s,8*s,Color(200,180,50))end}
   }
  }
  -- Skin colors
  local skinColors={Color(245,215,190),Color(230,195,165),Color(210,175,140),Color(185,150,115),Color(155,120,85),Color(120,85,60),Color(85,60,40)}
  local hairColors={Color(60,40,25),Color(40,25,15),Color(160,130,60),Color(190,80,25),Color(140,140,140),Color(25,25,25),Color(180,50,30)}
  local eyeColors={Color(60,90,140),Color(50,120,60),Color(120,80,40),Color(40,40,40),Color(80,130,150)}
  local skinIdx,hairIdx,eyeIdx=2,1,1
  -- Photo effects
  local effects={"normal","bw","sepia","vintage","grain","highcontrast"}
  local effectIdx=1
  -- 3D model panel (hidden, for reference) + Canvas for drawing
  local canvas=vgui.Create("DPanel",body);canvas:SetPos(18,64);canvas:SetSize(400,520)
  canvas.Paint=function(self,w,h)
   -- Background (paper texture)
   draw.RoundedBox(6,0,0,w,h,Color(235,225,210))
   -- Paper grain
   for i=1,40 do draw.RoundedBox(1,math.random(w),math.random(h),math.random(2,4),math.random(1,2),Color(200,190,175,40))end
   local cx,cy=w/2,h/2-10;local s=1.5
   local skinCol=skinColors[skinIdx]or skinColors[2]
   local hairCol=hairColors[hairIdx]or hairColors[1]
   local eyeCol=eyeColors[eyeIdx]or eyeColors[1]
   -- Draw face parts in order
   -- Ears
   draw.RoundedBox(12*s,cx-68*s,cy-15*s,14*s,30*s,skinCol)
   draw.RoundedBox(12*s,cx+54*s,cy-15*s,14*s,30*s,skinCol)
   -- Neck
   draw.RoundedBox(4*s,cx-18*s,cy+70*s,36*s,40*s,skinCol)
   -- Face shape
   local fp=faceParts.face[state.face]or faceParts.face[1];fp.draw(cx,cy,s,skinCol)
   -- Chin
   local cp=faceParts.chin[state.chin]or faceParts.chin[1];cp.draw(cx,cy,s,skinCol)
   -- Eyes
   local ep=faceParts.eyes[state.eyes]or faceParts.eyes[1];ep.draw(cx,cy,s,eyeCol)
   -- Brows
   local bp=faceParts.brows[state.brows]or faceParts.brows[1];bp.draw(cx,cy,s,hairCol)
   -- Nose
   local np=faceParts.nose[state.nose]or faceParts.nose[1];np.draw(cx,cy,s,skinCol)
   -- Mouth
   local mp=faceParts.mouth[state.mouth]or faceParts.mouth[1];mp.draw(cx,cy,s,Color(185,75,75))
   -- Hair (on top)
   local hp=faceParts.hair[state.hair]or faceParts.hair[1];hp.draw(cx,cy,s,hairCol)
   -- Extras
   if state.extras>0 then local xp=faceParts.extras[state.extras]or faceParts.extras[1];xp.draw(cx,cy,s,skinCol)end
   -- Photo effects
   local eff=effects[effectIdx]
   if eff=="bw"then
    draw.RoundedBox(0,0,0,w,h,Color(0,0,0,120))
    draw.RoundedBox(0,0,0,w,h,Color(255,255,255,40))
   elseif eff=="sepia"then
    draw.RoundedBox(0,0,0,w,h,Color(112,66,20,70))
   elseif eff=="vintage"then
    draw.RoundedBox(0,0,0,w,h,Color(90,60,30,80))
    for i=1,20 do surface.SetDrawColor(0,0,0,math.random(10,30));surface.DrawLine(math.random(w),0,math.random(w),h)end
   elseif eff=="grain"then
    for i=1,200 do draw.RoundedBox(1,math.random(w),math.random(h),1,1,Color(0,0,0,math.random(20,60)))end
   elseif eff=="highcontrast"then
    draw.RoundedBox(0,0,0,w,h,Color(0,0,0,50))
   end
   -- Vignette (always)
   for i=1,12 do local a=i*6;draw.RoundedBox(0,0,0,w,i,Color(0,0,0,a));draw.RoundedBox(0,0,h-i,w,i,Color(0,0,0,a));draw.RoundedBox(0,0,0,i,h,Color(0,0,0,a));draw.RoundedBox(0,w-i,0,i,h,Color(0,0,0,a))end
   -- Footer
   draw.RoundedBox(4,0,h-26,w,26,Color(0,0,0,100))
   draw.SimpleText("GRM ФОТОРОБОТ · "..os.date("%d.%m.%Y %H:%M"),"GRMNet_Small",w/2,h-13,Color(220,220,220),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
  end
  -- Controls panel (right side, compact)
  local ctrlPanel=vgui.Create("DPanel",body);ctrlPanel:SetPos(434,64);ctrlPanel:SetSize(378,520);ctrlPanel.Paint=function(_,w,h)draw.RoundedBox(8,0,0,w,h,Color(14,22,38))end
  local cy=12
  -- Part categories with cycling buttons
  local parts={
   {name="Лицо",key="face",max=#faceParts.face},
   {name="Причёска",key="hair",max=#faceParts.hair},
   {name="Глаза",key="eyes",max=#faceParts.eyes},
   {name="Брови",key="brows",max=#faceParts.brows},
   {name="Нос",key="nose",max=#faceParts.nose},
   {name="Рот",key="mouth",max=#faceParts.mouth},
   {name="Подбородок",key="chin",max=#faceParts.chin},
   {name="Приметы",key="extras",max=#faceParts.extras}
  }
  for _,part in ipairs(parts)do
   textLabel(ctrlPanel,part.name..":",14,cy,80,18,"GRMNet_Small",C.dim)
   local lbl=vgui.Create("DLabel",ctrlPanel);lbl:SetPos(100,cy);lbl:SetSize(170,18);lbl:SetFont("GRMNet_Small");lbl:SetTextColor(C.text)
   local function updateLabel()local p=faceParts[part.key][state[part.key]];lbl:SetText((p and p.name or"?").." ("..state[part.key].."/"..part.max..")")end
   updateLabel()
   local prevBtn=vgui.Create("DButton",ctrlPanel);prevBtn:SetPos(280,cy);prevBtn:SetSize(36,18);prevBtn:SetText("◄");prevBtn:SetFont("GRMNet_Small");prevBtn:SetTextColor(C.text);prevBtn.Paint=function(self,w,h)draw.RoundedBox(3,0,0,w,h,self:IsHovered()and C.hover or C.card)end
   prevBtn.DoClick=function()state[part.key]=state[part.key]-1;if state[part.key]<1 then state[part.key]=part.max end;updateLabel()end
   local nextBtn=vgui.Create("DButton",ctrlPanel);nextBtn:SetPos(320,cy);nextBtn:SetSize(36,18);nextBtn:SetText("►");nextBtn:SetFont("GRMNet_Small");nextBtn:SetTextColor(C.text);nextBtn.Paint=function(self,w,h)draw.RoundedBox(3,0,0,w,h,self:IsHovered()and C.hover or C.card)end
   nextBtn.DoClick=function()state[part.key]=state[part.key]+1;if state[part.key]>part.max then state[part.key]=1 end;updateLabel()end
   cy=cy+24
  end
  cy=cy+6
  -- Color pickers
  textLabel(ctrlPanel,"Цвет кожи:",14,cy,90,18,"GRMNet_Small",C.dim)
  for i,col in ipairs(skinColors)do local bx=110+(i-1)*26;local p=vgui.Create("DButton",ctrlPanel);p:SetPos(bx,cy);p:SetSize(22,18);p:SetText("");p.Paint=function(_,w,h)draw.RoundedBox(4,0,0,w,h,col);if skinIdx==i then surface.SetDrawColor(255,255,255);surface.DrawOutlinedRect(0,0,w,h,2)end end;p.DoClick=function()skinIdx=i end end
  cy=cy+24
  textLabel(ctrlPanel,"Цвет волос:",14,cy,90,18,"GRMNet_Small",C.dim)
  for i,col in ipairs(hairColors)do local bx=110+(i-1)*26;local p=vgui.Create("DButton",ctrlPanel);p:SetPos(bx,cy);p:SetSize(22,18);p:SetText("");p.Paint=function(_,w,h)draw.RoundedBox(4,0,0,w,h,col);if hairIdx==i then surface.SetDrawColor(255,255,255);surface.DrawOutlinedRect(0,0,w,h,2)end end;p.DoClick=function()hairIdx=i end end
  cy=cy+24
  textLabel(ctrlPanel,"Цвет глаз:",14,cy,90,18,"GRMNet_Small",C.dim)
  for i,col in ipairs(eyeColors)do local bx=110+(i-1)*26;local p=vgui.Create("DButton",ctrlPanel);p:SetPos(bx,cy);p:SetSize(22,18);p:SetText("");p.Paint=function(_,w,h)draw.RoundedBox(4,0,0,w,h,col);if eyeIdx==i then surface.SetDrawColor(255,255,255);surface.DrawOutlinedRect(0,0,w,h,2)end end;p.DoClick=function()eyeIdx=i end end
  cy=cy+24
  -- Effects
  textLabel(ctrlPanel,"Эффект:",14,cy,70,18,"GRMNet_Small",C.dim)
  local effectNames={"Обычный","Ч/Б","Сепия","Винтаж","Зерно","Контраст"}
  local effectLbl=vgui.Create("DLabel",ctrlPanel);effectLbl:SetPos(90,cy);effectLbl:SetSize(180,18);effectLbl:SetFont("GRMNet_Small");effectLbl:SetTextColor(C.text);effectLbl:SetText(effectNames[1])
  local effPrev=vgui.Create("DButton",ctrlPanel);effPrev:SetPos(280,cy);effPrev:SetSize(36,18);effPrev:SetText("◄");effPrev:SetFont("GRMNet_Small");effPrev:SetTextColor(C.text);effPrev.Paint=function(self,w,h)draw.RoundedBox(3,0,0,w,h,self:IsHovered()and C.hover or C.card)end
  effPrev.DoClick=function()effectIdx=effectIdx-1;if effectIdx<1 then effectIdx=#effects end;effectLbl:SetText(effectNames[effectIdx])end
  local effNext=vgui.Create("DButton",ctrlPanel);effNext:SetPos(320,cy);effNext:SetSize(36,18);effNext:SetText("►");effNext:SetFont("GRMNet_Small");effNext:SetTextColor(C.text);effNext.Paint=function(self,w,h)draw.RoundedBox(3,0,0,w,h,self:IsHovered()and C.hover or C.card)end
  effNext.DoClick=function()effectIdx=effectIdx+1;if effectIdx>#effects then effectIdx=1 end;effectLbl:SetText(effectNames[effectIdx])end
  cy=cy+28
  -- Description
  textLabel(ctrlPanel,"Подпись:",14,cy,70,18,"GRMNet_Small",C.dim)
  local desc=entry(ctrlPanel,"Описание, приметы...",90,cy,274,44,true);desc:SetMultiline(true)
  cy=cy+52
  -- Action buttons
  btn(ctrlPanel,"💾 СОХРАНИТЬ",14,cy,114,30,C.green,function()
   -- Capture canvas as image (grm_photorobot)
   local x,y=canvas:LocalToScreen(0,0)
   local w,h=canvas:GetSize()
   local captureData={
    format="jpeg",
    quality=95,
    x=x,
    y=y,
    w=w,
    h=h
   }
   local screenshot=render.Capture(captureData)
   if screenshot then
    -- Save to subfolder
    if not file.IsDir("grm_photos","DATA")then file.CreateDir("grm_photos")end
    local filename="grm_photos/photorobot_"..os.date("%Y%m%d_%H%M%S")..".jpg"
    file.Write(filename,screenshot)
    -- Also save text description
    local text="ФОТОРОБОТ "..os.date("%d.%m.%Y %H:%M").."\nЭффект: "..effectNames[effectIdx].."\nИзображение: "..filename.."\n\n"..desc:GetText()
    send(ent,"image_save",function() net.WriteString("Фоторобот_"..os.date("%d%m_%H%M")); net.WriteString("photo"); net.WriteUInt(#screenshot,24); net.WriteData(screenshot,#screenshot) end)
    notification.AddLegacy("Изображение сохранено: "..filename,NOTIFY_GENERIC,4)
   else
    notification.AddLegacy("Ошибка захвата изображения",NOTIFY_ERROR,4)
   end
  end)
  btn(ctrlPanel,"🖨️ ПЕЧАТЬ",134,cy,114,30,C.yellow,function()
   -- Capture canvas as image for printing
   local x,y=canvas:LocalToScreen(0,0)
   local w,h=canvas:GetSize()
   local captureData={
    format="jpeg",
    quality=90,
    x=x,
    y=y,
    w=w,
    h=h
   }
   local screenshot=render.Capture(captureData)
   if screenshot then
    -- Save to subfolder
    if not file.IsDir("grm_photos","DATA")then file.CreateDir("grm_photos")end
    local filename="grm_photos/print_"..os.date("%Y%m%d_%H%M%S")..".jpg"
    file.Write(filename,screenshot)
    -- Save print job with image reference
    local text="[ИЗОБРАЖЕНИЕ: "..filename.."]\nФОТОРОБОТ "..os.date("%d.%m.%Y %H:%M").."\nЭффект: "..effectNames[effectIdx].."\n\n"..desc:GetText()
    send(ent,"image_save",function() net.WriteString("Печать_"..os.date("%d%m_%H%M")); net.WriteString("photo_print"); net.WriteUInt(#screenshot,24); net.WriteData(screenshot,#screenshot) end)
    notification.AddLegacy("Печать: изображение сохранено",NOTIFY_GENERIC,4)
    surface.PlaySound("ambient/machines/combine_terminal_idle4.wav")
   else
    notification.AddLegacy("Ошибка захвата изображения",NOTIFY_ERROR,4)
   end
  end)
  btn(ctrlPanel,"📧 РАССЫЛКА",254,cy,114,30,C.purple,function()
   local mf=frame("РАССЫЛКА ФОТОРОБОТА",420,300);local toEntry=entry(mf,"Кому",18,60,384,28);local bodyEntry=entry(mf,"Текст",18,100,384,120,true);bodyEntry:SetText("Фоторобот "..os.date("%d.%m.%Y").."\n"..desc:GetText())
   btn(mf,"ОТПРАВИТЬ",18,230,384,36,C.blue,function()send(ent,"mail_send",function()net.WriteString(toEntry:GetText());net.WriteString("Фоторобот");net.WriteString(bodyEntry:GetText())end);mf:Close()end)
  end)
  cy=cy+38
  -- Presets
  textLabel(ctrlPanel,"Быстрые шаблоны:",14,cy,150,18,"GRMNet_Small",C.dim);cy=cy+22
  local presetBtns={
   {name="Подозреваемый 1",data={face=1,hair=1,eyes=1,brows=2,nose=1,mouth=1,chin=1,extras=0}},
   {name="Подозреваемый 2",data={face=2,hair=4,eyes=3,brows=4,nose=3,mouth=4,chin=2,extras=4}},
   {name="Подозреваемый 3",data={face=3,hair=6,eyes=5,brows=1,nose=2,mouth=2,chin=1,extras=6}},
   {name="Подозреваемый 4",data={face=5,hair=2,eyes=2,brows=3,nose=5,mouth=6,chin=3,extras=1}}
  }
  for i,preset in ipairs(presetBtns)do
   local bx=14+((i-1)%2)*182;local by=cy+math.floor((i-1)/2)*30
   btn(ctrlPanel,preset.name,bx,by,176,26,C.card,function()
    for k,v in pairs(preset.data)do state[k]=v end;effectIdx=math.random(1,3);effectLbl:SetText(effectNames[effectIdx])
   end)
  end
 end
 
 -- Save reference for use in photoGallery
 E._photoEditor = photoEditor
 
 -- Internet Browser
 local function internetPage()
  clear()
  textLabel(body,"ИНТЕРНЕТ-БРАУЗЕР",18,10,300,28,"GRMNet_Title",C.text)
  
	-- Sample websites
	local websites={
		{name="GRM News",url="news.grm.net",content="[НАЖМИТЕ ДЛЯ ОТКРЫТИЯ НОВОСТНОГО ПОРТАЛА]",action="news"},
		{name="GRM Mail",url="mail.grm.net",content="GRM Mail Service\n\nВаш почтовый сервис.\n\nИспользуйте приложение 'Почта' для работы с письмами."},
		{name="GRM Social",url="social.grm.net",content="GRM Social Network\n\nСоциальная сеть города.\n\nФункционал в разработке..."},
		{name="GRM Weather",url="weather.grm.net",content="Погода в городе\n\nСегодня: +22°C, ясно\nЗавтра: +20°C, облачно\n\nВлажность: 45%\nВетер: 3 м/с"},
		{name="GRM Maps",url="maps.grm.net",content="GRM Maps\n\nИнтерактивная карта города.\n\nФункционал в разработке..."}
	}
  
  -- Tabs system
  local tabs = {}
  local activeTabIndex = 1
  local tabWidth = 150
  local loadSite
  
  -- Tabs bar
  local tabsBar = vgui.Create("DPanel", body)
  tabsBar:SetPos(18, 50)
  tabsBar:SetSize(794, 30)
  tabsBar.Paint = function(_, w, h)
   draw.RoundedBox(4, 0, 0, w, h, Color(20, 30, 45))
  end
  
  -- New tab button
  local newTabBtn = vgui.Create("DButton", tabsBar)
  newTabBtn:SetPos(754, 4)
  newTabBtn:SetSize(30, 22)
  newTabBtn:SetText("+")
  newTabBtn:SetFont("GRMNet_Head")
  newTabBtn:SetTextColor(C.text)
  newTabBtn.Paint = function(self, w, h)
   local col = self:IsHovered() and C.hover or Color(40, 50, 65)
   draw.RoundedBox(3, 0, 0, w, h, col)
  end
  
  -- URL bar
  local urlBar = vgui.Create("DPanel", body)
  urlBar:SetPos(18, 85)
  urlBar:SetSize(794, 40)
  urlBar.Paint = function(_, w, h)
   draw.RoundedBox(6, 0, 0, w, h, Color(20, 30, 45))
  end
  
  local urlEntry = entry(urlBar, "Введите адрес сайта...", 110, 6, 610, 28)
  
  local backBtn = vgui.Create("DButton", urlBar)
  backBtn:SetPos(6, 6)
  backBtn:SetSize(48, 28)
  backBtn:SetText("◄")
  backBtn:SetFont("GRMNet_Head")
  backBtn:SetTextColor(C.text)
  backBtn.Paint = function(self, w, h)
   local col = self:IsHovered() and C.hover or C.card
   draw.RoundedBox(4, 0, 0, w, h, col)
  end
  
  local refreshBtn = vgui.Create("DButton", urlBar)
  refreshBtn:SetPos(58, 6)
  refreshBtn:SetSize(48, 28)
  refreshBtn:SetText("↻")
  refreshBtn:SetFont("GRMNet_Head")
  refreshBtn:SetTextColor(C.text)
  refreshBtn.Paint = function(self, w, h)
   local col = self:IsHovered() and C.hover or C.card
   draw.RoundedBox(4, 0, 0, w, h, col)
  end
  
  local goBtn = vgui.Create("DButton", urlBar)
  goBtn:SetPos(726, 6)
  goBtn:SetSize(62, 28)
  goBtn:SetText("→")
  goBtn:SetFont("GRMNet_Head")
  goBtn:SetTextColor(C.text)
  goBtn.Paint = function(self, w, h)
   local col = self:IsHovered() and C.hover or C.blue
   draw.RoundedBox(4, 0, 0, w, h, col)
  end
  
  -- Browser content area
  local browserFrame = vgui.Create("DPanel", body)
  browserFrame:SetPos(18, 135)
  browserFrame:SetSize(794, 445)
  browserFrame.Paint = function(_, w, h)
   draw.RoundedBox(8, 0, 0, w, h, Color(240, 240, 240))
  end
  
  -- Bookmarks panel
  local bookmarksPanel = vgui.Create("DPanel", body)
  bookmarksPanel:SetPos(18, 590)
  bookmarksPanel:SetSize(794, 30)
  bookmarksPanel.Paint = function(_, w, h)
   draw.RoundedBox(4, 0, 0, w, h, Color(20, 30, 45))
   draw.SimpleText("⭐ Закладки:", "GRMNet_Small", 10, 15, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
  end
  
  local currentSite = nil
  
  -- Function to update tabs display
  local function updateTabs()
   -- Clear old tabs
   for _, tab in ipairs(tabs) do
    if IsValid(tab.panel) then
     tab.panel:Remove()
    end
   end
   
   -- Create new tabs
   for i, tab in ipairs(tabs) do
    local tabPanel = vgui.Create("DPanel", tabsBar)
    tabPanel:SetPos((i-1) * tabWidth, 4)
    tabPanel:SetSize(tabWidth - 5, 22)
    tabPanel.Paint = function(_, w, h)
     local col = (i == activeTabIndex) and C.blue or Color(40, 50, 65)
     draw.RoundedBox(3, 0, 0, w, h, col)
     draw.SimpleText(tab.name, "GRMNet_Small", 10, 11, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    
    -- Close button
    local closeBtn = vgui.Create("DButton", tabPanel)
    closeBtn:SetPos(tabWidth - 25, 3)
    closeBtn:SetSize(16, 16)
    closeBtn:SetText("×")
    closeBtn:SetFont("GRMNet_Small")
    closeBtn:SetTextColor(C.text)
    closeBtn.Paint = function(self, w, h)
     local col = self:IsHovered() and C.red or Color(60, 70, 85)
     draw.RoundedBox(2, 0, 0, w, h, col)
    end
    closeBtn.DoClick = function()
     if #tabs > 1 then
      table.remove(tabs, i)
      if activeTabIndex > #tabs then
       activeTabIndex = #tabs
      end
      updateTabs()
      if tabs[activeTabIndex] then
       loadSite(tabs[activeTabIndex].site)
      end
     else
      notification.AddLegacy("Нельзя закрыть последнюю вкладку", NOTIFY_ERROR, 3)
     end
    end
    
    -- Tab click
    tabPanel.OnMousePressed = function()
     activeTabIndex = i
     updateTabs()
     loadSite(tab.site)
    end
    
    tab.panel = tabPanel
   end
   
   -- Update new tab button position
   newTabBtn:SetPos(math.min(#tabs * tabWidth, 724), 4)
  end
  
  -- Function to load a website
  loadSite = function(site)
   -- Проверка на специальное действие
   if site.action == "news" then
    if GRM.News and GRM.News.OpenPortal then
     GRM.News.OpenPortal()
    else
     notification.AddLegacy("Новостной портал недоступен", NOTIFY_ERROR, 3)
    end
    return
   end
   
   currentSite = site
   browserFrame:Clear()
   
   local header = vgui.Create("DPanel", browserFrame)
   header:SetPos(0, 0)
   header:SetSize(794, 50)
   header.Paint = function(_, w, h)
    draw.RoundedBoxEx(8, 0, 0, w, h, C.blue, true, true, false, false)
    draw.SimpleText(site.name, "GRMNet_Title", 20, 25, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
   end
   
   local content = vgui.Create("DTextEntry", browserFrame)
   content:SetPos(20, 60)
   content:SetSize(754, 365)
   content:SetMultiline(true)
   content:SetEditable(false)
   content:SetText(site.content)
   content:SetFont("GRMNet_Body")
   
   urlEntry:SetText(site.url)
   
   -- Update tab if exists
   if tabs[activeTabIndex] then
    tabs[activeTabIndex].name = site.name
    tabs[activeTabIndex].site = site
    updateTabs()
   end
  end
  
  -- Add bookmark buttons
  local bookmarkX = 100
  for i, site in ipairs(websites) do
   local bBtn = vgui.Create("DButton", bookmarksPanel)
   bBtn:SetPos(bookmarkX, 4)
   bBtn:SetSize(120, 22)
   bBtn:SetText(site.name)
   bBtn:SetFont("GRMNet_Small")
   bBtn:SetTextColor(C.text)
   bBtn.Paint = function(self, w, h)
    local col = self:IsHovered() and C.hover or Color(40, 50, 65)
    draw.RoundedBox(3, 0, 0, w, h, col)
   end
   bBtn.DoClick = function()
    -- Open in new tab
    table.insert(tabs, {name = site.name, site = site, panel = nil})
    activeTabIndex = #tabs
    updateTabs()
    loadSite(site)
   end
   bookmarkX = bookmarkX + 126
  end
  
  goBtn.DoClick = function()
   local url = urlEntry:GetText()
   for _, site in ipairs(websites) do
    if site.url == url then
     -- Update current tab
     if tabs[activeTabIndex] then
      tabs[activeTabIndex].name = site.name
      tabs[activeTabIndex].site = site
     end
     loadSite(site)
     return
    end
   end
   notification.AddLegacy("Сайт не найден: " .. url, NOTIFY_ERROR, 3)
  end
  
  refreshBtn.DoClick = function()
   if currentSite then
    loadSite(currentSite)
    notification.AddLegacy("Страница обновлена", NOTIFY_GENERIC, 2)
   end
  end
  
  urlEntry.OnEnter = goBtn.DoClick
  
  newTabBtn.DoClick = function()
   -- Create new tab with first website
   local defaultSite = websites[1]
   table.insert(tabs, {name = defaultSite.name, site = defaultSite, panel = nil})
   activeTabIndex = #tabs
   updateTabs()
   loadSite(defaultSite)
  end
  
  -- Initialize first tab
  table.insert(tabs, {name = websites[1].name, site = websites[1], panel = nil})
  updateTabs()
  loadSite(websites[1])
 end
 
 -- Social Networks
 local function socialPage()
  if GRM.Computer and GRM.Computer.Social then net.Start("GRM_Computer_Social_Request"); net.SendToServer() end
  clear()
  textLabel(body,"СОЦИАЛЬНЫЕ СЕТИ",18,10,300,28,"GRMNet_Title",C.text)
  textLabel(body,"GRM Social Network",18,38,400,20,"GRMNet_Small",C.dim)
  
  -- Feed panel
  local feedPanel=vgui.Create("DPanel",body)
  feedPanel:SetPos(18,70)
  feedPanel:SetSize(500,540)
  feedPanel.Paint=function(_,w,h)
   draw.RoundedBox(8,0,0,w,h,Color(20,30,45))
  end
  
  -- Серверная лента; локальные демо-записи больше не используются.
  local posts=(GRM.Computer and GRM.Computer.Social and GRM.Computer.Social.posts) or {}
  if #posts==0 then posts={{author="Система",time="--:--",text="Подключение к серверной ленте..."}} end
  
  local y=20
  for i,post in ipairs(posts)do
   local postPanel=vgui.Create("DPanel",feedPanel)
   postPanel:SetPos(20,y)
   postPanel:SetSize(460,100)
   postPanel.Paint=function(_,w,h)
    draw.RoundedBox(6,0,0,w,h,Color(30,40,55))
    draw.SimpleText(post.author,"GRMNet_Head",15,15,C.blue,TEXT_ALIGN_LEFT)
    draw.SimpleText(post.time,"GRMNet_Small",w-15,15,C.dim,TEXT_ALIGN_RIGHT)
   end
   
   local postText=vgui.Create("DLabel",postPanel)
   postText:SetPos(15,40)
   postText:SetSize(430,50)
   postText:SetFont("GRMNet_Body")
   postText:SetTextColor(C.text)
   postText:SetWrap(true)
   postText:SetText(post.text)
   
   y=y+110
  end
  
  -- New post panel
  local newPostPanel=vgui.Create("DPanel",body)
  newPostPanel:SetPos(530,70)
  newPostPanel:SetSize(282,250)
  newPostPanel.Paint=function(_,w,h)
   draw.RoundedBox(8,0,0,w,h,Color(20,30,45))
   draw.SimpleText("Новая запись","GRMNet_Head",15,15,C.text,TEXT_ALIGN_LEFT)
  end
  
  local postEntry=entry(newPostPanel,"Что у вас нового?",15,50,252,120,true)
  
  btn(newPostPanel,"ОПУБЛИКОВАТЬ",15,180,252,40,C.green,function()
   local text=postEntry:GetText()
   if text==""then
    notification.AddLegacy("Напишите что-нибудь!",NOTIFY_ERROR,3)
    return
   end
   net.Start("GRM_Computer_Social_Post"); net.WriteString(text); net.SendToServer()
   notification.AddLegacy("Запись отправлена на сервер!",NOTIFY_GENERIC,3)
   postEntry:SetText("")
  end)
  
  -- Friends panel
  local friendsPanel=vgui.Create("DPanel",body)
  friendsPanel:SetPos(530,330)
  friendsPanel:SetSize(282,280)
  friendsPanel.Paint=function(_,w,h)
   draw.RoundedBox(8,0,0,w,h,Color(20,30,45))
   draw.SimpleText("Друзья онлайн","GRMNet_Head",15,15,C.text,TEXT_ALIGN_LEFT)
  end
  
  local friendsList=darkList(friendsPanel,15,50,252,215,{{"Имя",150},{"Статус",80}})
  for i=1,5 do
   addLine(friendsList,"Player"..i,"В сети")
  end
 end
 
 -- Chat System
 local function chatPage()
  clear()
  textLabel(body,"ЧАТЫ И СООБЩЕНИЯ",18,10,300,28,"GRMNet_Title",C.text)
  
  -- Chat list
  local chatList=darkList(body,18,50,250,560,{{"Чат",180},{"Последнее",60}})
  
  local chats={
   {name="Общий чат",last="12:30"},
   {name="Player1",last="11:45"},
   {name="Player2",last="10:20"},
   {name="Администрация",last="09:15"},
   {name="Группа: Друзья",last="Вчера"}
  }
  
  for _,chat in ipairs(chats)do
   addLine(chatList,chat.name,chat.last)
  end
  
  -- Chat area
  local chatArea=vgui.Create("DPanel",body)
  chatArea:SetPos(280,50)
  chatArea:SetSize(532,500)
  chatArea.Paint=function(_,w,h)
   draw.RoundedBox(8,0,0,w,h,Color(20,30,45))
  end
  
  local chatHeader=vgui.Create("DPanel",chatArea)
  chatHeader:SetPos(0,0)
  chatHeader:SetSize(532,40)
  chatHeader.Paint=function(_,w,h)
   draw.RoundedBoxEx(8,0,0,w,h,Color(30,40,55),true,true,false,false)
   draw.SimpleText("Общий чат","GRMNet_Head",15,20,C.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  end
  
  local messages=vgui.Create("DTextEntry",chatArea)
  messages:SetPos(15,50)
  messages:SetSize(502,400)
  messages:SetMultiline(true)
  messages:SetEditable(false)
  messages:SetFont("GRMNet_Body")
  messages:SetText("[12:30] Admin: Добро пожаловать в общий чат!\n[12:35] Player1: Привет всем!\n[12:40] Player2: Как дела?\n[12:45] Admin: Напоминаю о правилах поведения.")
  
  -- Message input
  local msgInput=entry(body,"Введите сообщение...",280,560,440,30)
  
  btn(body,"ОТПРАВИТЬ",730,560,82,30,C.blue,function()
   local text=msgInput:GetText()
   if text==""then return end
   local time=os.date("%H:%M")
   local user=current.data.logged or"Вы"
   net.Start("GRM_Computer_Chat_Send"); net.WriteString("общий"); net.WriteString(text); net.SendToServer()
   messages:SetText(messages:GetText().."\n["..time.."] "..user..": "..text)
   msgInput:SetText("")
  end)
 end
 
 local function mailPage()
  clear()
  -- Header (ПОЧТА / РАССЫЛКА)
  local header=vgui.Create("DPanel",body)
  header:SetPos(0,0)
  header:SetSize(830,50)
  header.Paint=function(_,w,h)
   draw.RoundedBoxEx(8,0,0,w,h,Color(15,25,40),true,true,false,false)
   surface.SetMaterial(Material("icon16/email.png"))
   surface.SetDrawColor(C.blue)
   surface.DrawTexturedRect(16,13,24,24)
   draw.SimpleText("ПОЧТА GRM NET","GRMNet_Title",48,25,C.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
  end
  
  -- Inbox section
  textLabel(body,"Входящие:",18,58,150,20,"GRMNet_Head",C.dim)
  local inbox=darkList(body,18,80,370,400,{{"От",80},{"Тема",195},{"Дата",50},{"",30}})
  
  -- Message view section
  textLabel(body,"Просмотр письма:",404,58,200,20,"GRMNet_Head",C.dim)
  local msgView=entry(body,"Выберите письмо из списка слева...",404,80,408,400,true)
  msgView:SetEditable(false)
  
  local selectedMsgID=""
  inbox.OnRowSelected=function(_,_,line)
   selectedMsgID=line._msg and line._msg.id or""
   if selectedMsgID~=""then
    send(ent,"mail_open",function()net.WriteString(selectedMsgID)end)
   end
  end
  
  -- Action buttons
  btn(body,"✉ НОВОЕ ПИСЬМО",18,492,176,38,C.blue,function()
   local cf=frame("НОВОЕ ПИСЬМО",520,440)
   local toE=entry(cf,"Кому (логин получателя)",18,60,484,36)
   local subjE=entry(cf,"Тема письма",18,106,484,36)
   local bodyE=entry(cf,"Текст письма",18,152,484,220,true)
   btn(cf,"ОТПРАВИТЬ",18,384,484,42,C.green,function()
    send(ent,"mail_send",function()
     net.WriteString(toE:GetText())
     net.WriteString(subjE:GetText())
     net.WriteString(bodyE:GetText())
    end)
    cf:Close()
   end)
  end)
  
  btn(body,"🗑 УДАЛИТЬ",206,492,120,38,C.red,function()
   if selectedMsgID==""then
    notification.AddLegacy("Выберите письмо для удаления",NOTIFY_ERROR,3)
    return
   end
   send(ent,"mail_delete",function()net.WriteString(selectedMsgID)end)
  end)
  
  btn(body,"🔄 ОБНОВИТЬ",338,492,120,38,C.card,function()
   send(ent,"inbox")
   notification.AddLegacy("Обновление...",NOTIFY_GENERIC,2)
  end)
  
  if data.canConfigure then
   btn(body,"📢 РАССЫЛКА ВСЕМ",470,492,170,38,C.yellow,function()
    local bf=frame("РАССЫЛКА ВСЕМ ПОЛЬЗОВАТЕЛЯМ",520,360)
    local subjE=entry(bf,"Тема",18,60,484,36)
    local bodyE=entry(bf,"Текст рассылки",18,106,484,190,true)
    btn(bf,"ОТПРАВИТЬ ВСЕМ",18,306,484,40,C.red,function()
     net.Start("GRM_Net_MailSend")
     net.WriteString(subjE:GetText())
     net.WriteString(bodyE:GetText())
     net.SendToServer()
     bf:Close()
     notification.AddLegacy("Рассылка запущена",NOTIFY_GENERIC,4)
    end)
   end)
  end
  
  -- Info panel
  local infoPanel=vgui.Create("DPanel",body)
  infoPanel:SetPos(18,542)
  infoPanel:SetSize(800,70)
  infoPanel.Paint=function(_,w,h)
   draw.RoundedBox(6,0,0,w,h,Color(20,30,45))
   draw.SimpleText("💡 Подсказки:","GRMNet_Small",12,12,C.blue)
   draw.SimpleText("• Нажмите на письмо в списке чтобы прочитать","GRMNet_Tiny",12,30,C.dim)
   draw.SimpleText("• Непрочитанные письма отмечены символом ●","GRMNet_Tiny",12,44,C.dim)
   draw.SimpleText("• Используйте кнопку 'НОВОЕ ПИСЬМО' чтобы отправить сообщение","GRMNet_Tiny",12,58,C.dim)
  end
  
  send(ent,"inbox")
  body._inbox=inbox
  body._msgView=msgView
 end
 -- Home Page
 -- Graphic Editor
 local function graphicEditorPage()
  clear()
  textLabel(body,"ГРАФИЧЕСКИЙ РЕДАКТОР",18,10,300,28,"GRMNet_Title",C.text)
  
  -- Canvas for drawing
  local canvas = vgui.Create("DPanel", body)
  canvas:SetPos(18, 50)
  canvas:SetSize(600, 550)
  canvas:SetCursor("crosshair")
  
  local pixels = {}
  local brushSize = 3
  local brushColor = Color(0, 0, 0)
  local isDrawing = false
  
  canvas.Paint = function(self, w, h)
   draw.RoundedBox(4, 0, 0, w, h, Color(255, 255, 255))
   
   -- Draw pixels
   for _, px in ipairs(pixels) do
    surface.SetDrawColor(px.color)
    surface.DrawRect(px.x, px.y, px.size, px.size)
   end
  end
  
  canvas.OnMousePressed = function(self, code)
   if code == MOUSE_LEFT then
    isDrawing = true
    local x, y = self:CursorPos()
    table.insert(pixels, {x = x, y = y, size = brushSize, color = brushColor})
   end
  end
  
  canvas.OnMouseReleased = function(self, code)
   if code == MOUSE_LEFT then
    isDrawing = false
   end
  end
  
  canvas.OnCursorMoved = function(self)
   if isDrawing then
    local x, y = self:CursorPos()
    table.insert(pixels, {x = x, y = y, size = brushSize, color = brushColor})
   end
  end
  
  -- Tools panel
  local toolsPanel = vgui.Create("DPanel", body)
  toolsPanel:SetPos(630, 50)
  toolsPanel:SetSize(182, 550)
  toolsPanel.Paint = function(_, w, h)
   draw.RoundedBox(6, 0, 0, w, h, Color(20, 30, 45))
  end
  
  local yPos = 10
  
  -- Brush size
  local sizeLabel = vgui.Create("DLabel", toolsPanel)
  sizeLabel:SetPos(10, yPos)
  sizeLabel:SetSize(162, 20)
  sizeLabel:SetText("Размер кисти:")
  sizeLabel:SetFont("GRMNet_Small")
  sizeLabel:SetTextColor(C.text)
  yPos = yPos + 25
  
  local sizeSlider = vgui.Create("DNumSlider", toolsPanel)
  sizeSlider:SetPos(10, yPos)
  sizeSlider:SetSize(162, 30)
  sizeSlider:SetMin(1)
  sizeSlider:SetMax(20)
  sizeSlider:SetDecimals(0)
  sizeSlider:SetValue(brushSize)
  sizeSlider:SetText("")
  sizeSlider.OnValueChanged = function(_, val)
   brushSize = val
  end
  yPos = yPos + 40
  
  -- Color picker
  local colorLabel = vgui.Create("DLabel", toolsPanel)
  colorLabel:SetPos(10, yPos)
  colorLabel:SetSize(162, 20)
  colorLabel:SetText("Цвет:")
  colorLabel:SetFont("GRMNet_Small")
  colorLabel:SetTextColor(C.text)
  yPos = yPos + 25
  
  local colors = {
   Color(0, 0, 0), Color(255, 0, 0), Color(0, 255, 0), Color(0, 0, 255),
   Color(255, 255, 0), Color(255, 0, 255), Color(0, 255, 255), Color(255, 128, 0),
   Color(128, 0, 255), Color(255, 255, 255), Color(128, 128, 128), Color(64, 64, 64)
  }
  
  local colorX = 10
  for i, col in ipairs(colors) do
   local colorBtn = vgui.Create("DButton", toolsPanel)
   colorBtn:SetPos(colorX, yPos)
   colorBtn:SetSize(30, 30)
   colorBtn:SetText("")
   colorBtn.Paint = function(self, w, h)
    draw.RoundedBox(4, 0, 0, w, h, col)
    if self:IsHovered() then
     surface.SetDrawColor(255, 255, 255)
     surface.DrawOutlinedRect(0, 0, w, h, 2)
    end
   end
   colorBtn.DoClick = function()
    brushColor = col
   end
   colorX = colorX + 35
   if i % 4 == 0 then
    colorX = 10
    yPos = yPos + 35
   end
  end
  yPos = yPos + 45
  
  -- Clear button
  local clearBtn = vgui.Create("DButton", toolsPanel)
  clearBtn:SetPos(10, yPos)
  clearBtn:SetSize(162, 35)
  clearBtn:SetText("ОЧИСТИТЬ")
  clearBtn:SetFont("GRMNet_Bold")
  clearBtn:SetTextColor(C.text)
  clearBtn.Paint = function(self, w, h)
   local col = self:IsHovered() and C.red or Color(200, 60, 60)
   draw.RoundedBox(6, 0, 0, w, h, col)
  end
  clearBtn.DoClick = function()
   pixels = {}
   notification.AddLegacy("Холст очищен", NOTIFY_GENERIC, 2)
  end
  yPos = yPos + 45
  
  -- Save button
  local saveBtn = vgui.Create("DButton", toolsPanel)
  saveBtn:SetPos(10, yPos)
  saveBtn:SetSize(162, 35)
  saveBtn:SetText("СОХРАНИТЬ")
  saveBtn:SetFont("GRMNet_Bold")
  saveBtn:SetTextColor(C.text)
  saveBtn.Paint = function(self, w, h)
   local col = self:IsHovered() and C.green or Color(40, 160, 80)
   draw.RoundedBox(6, 0, 0, w, h, col)
  end
  saveBtn.DoClick = function()
   -- Save as file
   local saveData = {
    pixels = pixels,
    width = 600,
    height = 550,
    created = os.time()
   }
   local filename = "drawing_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
   send(ent, "file_save", function()
    net.WriteString("")
    net.WriteString(filename)
    net.WriteString(util.TableToJSON(saveData))
    net.WriteString("drawing")
   end)
   notification.AddLegacy("Рисунок сохранен: " .. filename, NOTIFY_GENERIC, 3)
  end
  yPos = yPos + 45
  
  -- Print button
  local printBtn = vgui.Create("DButton", toolsPanel)
  printBtn:SetPos(10, yPos)
  printBtn:SetSize(162, 35)
  printBtn:SetText("ПЕЧАТАТЬ")
  printBtn:SetFont("GRMNet_Bold")
  printBtn:SetTextColor(C.text)
  printBtn.Paint = function(self, w, h)
   local col = self:IsHovered() and C.yellow or Color(200, 160, 40)
   draw.RoundedBox(6, 0, 0, w, h, col)
  end
  printBtn.DoClick = function()
   notification.AddLegacy("Отправка на печать...", NOTIFY_GENERIC, 2)
   -- Save as printable document
   local saveData = {
    pixels = pixels,
    width = 600,
    height = 550,
    created = os.time(),
    type = "print"
   }
   local filename = "print_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
   send(ent, "file_save", function()
    net.WriteString("")
    net.WriteString(filename)
    net.WriteString(util.TableToJSON(saveData))
    net.WriteString("print_drawing")
   end)
  end
  yPos = yPos + 50
  
  -- Info
  local infoLabel = vgui.Create("DLabel", toolsPanel)
  infoLabel:SetPos(10, yPos)
  infoLabel:SetSize(162, 80)
  infoLabel:SetText("ЛКМ - рисовать\n\nСохраняет в файлы\nМожно печатать")
  infoLabel:SetFont("GRMNet_Small")
  infoLabel:SetTextColor(C.text_dim)
  infoLabel:SetWrap(true)
 end

 local function homePage()clear()
  local head=vgui.Create("DPanel",body);head:SetPos(0,0);head:SetSize(830,100);head.Paint=function(_,w,h)
   draw.RoundedBoxEx(9,0,0,w,h,Color(15,25,40),true,true,false,false)
   -- User info
   draw.SimpleText(tostring(current.data.logged or"пользователь"),"GRMNet_Title",72,20,current.data.role=="root"and C.yellow or C.text)
   if current.data.role=="root"then draw.SimpleText("ROOT","GRMNet_Status",72,48,C.red)else draw.SimpleText(tostring(current.data.role or"user"),"GRMNet_Status",72,48,C.dim)end
   -- Status indicators
   surface.SetMaterial(Material("icon16/user.png"));surface.SetDrawColor(C.blue);surface.DrawTexturedRect(20,18,40,40)
   local statusColor=current.data.online and C.green or C.red;draw.SimpleText(current.data.online and"● ONLINE"or"○ OFFLINE","GRMNet_Head",w-200,20,statusColor)
   draw.SimpleText("Сеть: "..tostring(current.data.network or"нет"),"GRMNet_Small",w-200,48,C.dim)
   draw.SimpleText("Устройство: "..tostring(current.deviceID):sub(1,20),"GRMNet_Tiny",w-200,68,C.dim)
  -- Time
  draw.SimpleText(os.date("%H:%M:%S"),"GRMNet_Head",w-80,68,C.dim)
 end
 
 -- OS Type definitions
 local osTypes = {
  civilian = {name = "Гражданская", color = C.green, apps = {"internet", "social", "chat", "mail", "files", "calculator", "notes", "editor", "graphic"}},
  service = {name = "Служебная", color = C.blue, apps = {"internet", "social", "chat", "mail", "files", "calculator", "notes", "editor", "graphic", "modules", "wifi"}},
  personal = {name = "Персональная", color = C.purple, apps = {"internet", "social", "chat", "mail", "files", "calculator", "notes", "editor", "graphic", "photorobot", "modules", "wifi"}},
  business = {name = "Бизнес", color = C.yellow, apps = {"internet", "mail", "files", "calculator", "notes", "editor", "modules"}},
  lawenforcement = {name = "Правоохранительная", color = C.red, apps = {"internet", "mail", "files", "notes", "modules", "wifi", "photorobot"}}
 }
 
 local currentOSType = current.data.osType or "civilian"
 local osConfig = osTypes[currentOSType] or osTypes.civilian
 local allowedApps = osConfig.apps
 
 -- OS Type indicator
 draw.SimpleText("ОС: " .. osConfig.name, "GRMNet_Small", 20, 75, osConfig.color)
 
 -- App grid with filtering
 local function canShow(appId) return table.HasValue(allowedApps, appId) end
 
 if canShow("internet") then appTile(body,"Интернет","Веб-браузер","icon16/world.png",18,116,C.blue,internetPage) end
 if canShow("social") then appTile(body,"Соцсети","Социальная сеть","icon16/group.png",218,116,C.cyan,socialPage) end
 if canShow("chat") then appTile(body,"Чаты","Мгновенные сообщения","icon16/comments.png",418,116,C.green,chatPage) end
 if canShow("mail") then appTile(body,"Почта","Электронная почта","icon16/email.png",618,116,C.purple,mailPage) end
 if canShow("files") then appTile(body,"Файлы","Хранилище устройства","icon16/folder.png",18,240,C.blue,function()send(ent,"files")end) end
 if canShow("calculator") then appTile(body,"Калькулятор","Вычисления","icon16/calculator.png",218,240,C.green,calcPage) end
 if canShow("notes") then appTile(body,"Заметки","Быстрые записи","icon16/note.png",418,240,C.yellow,notesPage) end
 if canShow("editor") then appTile(body,"Редактор","Текстовый редактор","icon16/page_white_edit.png",618,240,C.orange,editorPage) end
 if canShow("graphic") then appTile(body,"Графика","Графический редактор","icon16/paintbrush.png",18,364,C.orange,graphicEditorPage) end
 if canShow("photorobot") then appTile(body,"Фоторобот","Составление портрета","icon16/user.png",218,364,C.purple,photoPage) end
 if canShow("modules") then appTile(body,"Модули","Фракции, CCTV","icon16/application_view_tile.png",418,364,C.green,modulesPage) end
 if canShow("wifi") then appTile(body,"Wi-Fi","Подключение","icon16/transmit.png",618,364,C.yellow,wifiPage) end
 if canShow("files") then appTile(body,"Печать","Файл на принтер","icon16/printer.png",18,488,C.yellow,function()send(ent,"files")end) end
 if data.canConfigure then appTile(body,"Администрирование","Управление сетью и доступы","icon16/cog.png",218,488,C.red,function()send(ent,"control_center")end)end
  -- Footer
  local footer=vgui.Create("DPanel",body);footer:SetPos(0,618);footer:SetSize(830,22);footer.Paint=function(_,w,h)draw.RoundedBox(4,0,0,w,h,Color(12,18,30));draw.SimpleText("GRM NET OS v1.5.0 · Electronics Ecosystem","GRMNet_Tiny",12,11,C.dim,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER);draw.SimpleText("Файлов на устройстве: "..#current.files,"GRMNet_Tiny",w-12,11,C.dim,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)end
 end
 -- Side navigation
 btn(side,"Главная",12,80,166,40,C.card,homePage)
 btn(side,"Интернет",12,128,166,36,C.card,internetPage)
 btn(side,"Соцсети",12,170,166,36,C.card,socialPage)
 btn(side,"Чаты",12,212,166,36,C.card,chatPage)
 btn(side,"Почта",12,254,166,36,C.card,mailPage)
 btn(side,"Файлы",12,296,166,36,C.card,function()send(ent,"files")end)
 btn(side,"Заметки",12,338,166,36,C.card,notesPage)
 btn(side,"Редактор",12,380,166,36,C.card,editorPage)
 btn(side,"Калькулятор",12,422,166,36,C.card,calcPage)
 btn(side,"Фоторобот",12,464,166,36,C.card,photoPage)
 btn(side,"Модули",12,506,166,36,C.card,modulesPage)
 btn(side,"Wi-Fi",12,548,166,36,C.card,wifiPage)
 if data.canConfigure then btn(side,"Network Center",12,590,166,36,C.yellow,function()send(ent,"control_center")end)end
 btn(side,"Выйти",12,640,166,42,C.red,function()send(ent,"logout");f:Close()end)
 E.ActiveFrame=f;E.ActiveBody=body;E.FilePage=filesPage;E.HomePage=homePage;E.SidePanel=side
 if data.logged~=""then
  side:SetVisible(true)
  homePage()
 else
  side:SetVisible(false)
  loginPage()
 end
end
local function openDevice(ent,data)
 if data.kind=="computer"then openComputer(ent,data)return end
 local f=frame(tostring(data.name),540,430);local status=vgui.Create("DLabel",f);status:SetPos(24,76);status:SetSize(490,100);status:SetFont("GRMNet_Head");status:SetTextColor(data.online and C.green or C.red);status:SetText((data.online and"● ONLINE"or"○ OFFLINE").."\nСеть: "..tostring(data.network).."\nВладелец: "..tostring(data.owner));if data.canConfigure then btn(f,"НАСТРОИТЬ УСТРОЙСТВО / ДОСТУПЫ",24,250,492,48,C.blue,function()send(ent,"admin");f:Close()end)end
end
net.Receive("GRM_Net_Open",function()openDevice(net.ReadEntity(),net.ReadTable()or{})end)
local function formatModule(data)local out={tostring(data.title or"Сетевой модуль"),string.rep("—",42)};for _,row in ipairs(data.rows or{})do local parts={};for key,value in pairs(row)do parts[#parts+1]=tostring(key)..": "..tostring(value)end;table.sort(parts);out[#out+1]=table.concat(parts,"   ")end;if#(data.rows or{})==0 then out[#out+1]="Нет записей"end;return table.concat(out,"\n\n")end
net.Receive("GRM_Net_Result",function()local ok=net.ReadBool();local msg=net.ReadString();local payload=net.ReadTable()or{};notification.AddLegacy(msg,ok and NOTIFY_GENERIC or NOTIFY_ERROR,4);surface.PlaySound(ok and"buttons/button14.wav"or"buttons/button10.wav");if not ok then return end
 if payload.files and IsValid(E.ActiveFrame)then
  if E._showPhotoGallery then
   E._showPhotoGallery=false
   current.files=payload.files
   if E._photoGallery then
    local ok, err = pcall(E._photoGallery)
    if not ok then MsgC(Color(255,0,0), "[GRM Electronics] photoGallery error: "..tostring(err).."\n") end
   end
  elseif E.FilePage then
   E.FilePage(payload.files)
  end
 end
 if payload.file and IsValid(E.ActiveFrame)then local b=E.ActiveBody;if IsValid(b)then
  if IsValid(b._fileName)then b._fileName:SetText(payload.file.name or"")end
  if IsValid(b._fileContent)then
   -- Check if this is a photo file with image reference
   local content=payload.file.content or""
   local imgFile=content:match("%[ИЗОБРАЖЕНИЕ: ([^%]]+)%]")or content:match("Изображение: ([%w_%.%-]+)")
   if imgFile and(payload.file.category=="photo"or payload.file.category=="photo_print")then
    -- Load and display image
    local imgPath=imgFile
    if not imgFile:find("/")then imgPath=imgFile end
    if file.Exists(imgPath,"DATA")then
     b._fileContent:SetText("[ФОТО ИЗОБРАЖЕНИЕ]\n\nФайл: "..imgFile.."\n\n"..content)
     -- Create image viewer window
     local imgFrame=vgui.Create("DFrame",E.ActiveFrame)
     imgFrame:SetTitle("Просмотр фоторобота")
     imgFrame:SetSize(420,540)
     imgFrame:Center()
     imgFrame:MakePopup()
     local html=vgui.Create("DHTML",imgFrame)
     html:SetPos(10,30)
     html:SetSize(400,500)
     html:SetHTML([[<html><body style="margin:0;padding:10px;background:#2a2a2a;"><img src="file://]]..imgPath..[[" style="max-width:100%;max-height:480px;border:2px solid #444;"></body></html>]])
    else
     b._fileContent:SetText(content)
    end
   else
    b._fileContent:SetText(content)
   end
  end
  if IsValid(b._noteName)then b._noteName:SetText(payload.file.name or"")end
  if IsValid(b._noteContent)then b._noteContent:SetText(payload.file.content or"")end
  if IsValid(b._editorName)then b._editorName:SetText(payload.file.name or"")end
  if IsValid(b._editorArea)then b._editorArea:SetText(payload.file.content or"")end
 end end
 if payload.module and IsValid(E.ActiveFrame)then local b=E.ActiveBody;if IsValid(b)and IsValid(b._moduleOutput)then b._moduleOutput:SetText(formatModule(payload.module))end end
 if payload.inbox and IsValid(E.ActiveFrame)then local b=E.ActiveBody;if IsValid(b)and IsValid(b._inbox)then b._inbox:Clear();for _,m in ipairs(payload.inbox)do local line=addLine(b._inbox,m.from,m.subject,os.date("%d.%m",m.date),m.read and""or"●");line._msg=m end end end
 if payload.mail and IsValid(E.ActiveFrame)then local b=E.ActiveBody;if IsValid(b)and IsValid(b._msgView)then b._msgView:SetText("От: "..payload.mail.from.."\nТема: "..payload.mail.subject.."\nДата: "..os.date("%d.%m.%Y %H:%M",payload.mail.date).."\n\n"..payload.mail.body)end end
end)
local function adminAction(op,id)net.Start("GRM_Net_AdminAction");net.WriteString(op);net.WriteString(id or"");net.SendToServer()end
net.Receive("GRM_Net_AdminData",function()
 local data=net.ReadTable()or{};if IsValid(E.AdminCenter)then E.AdminCenter:Remove()end;local f=frame("GRM NETWORK CONTROL CENTER",1120,720);E.AdminCenter=f
 local stats={{"УСТРОЙСТВА",#(data.devices or{}),"icon16/server.png",C.blue},{"КАБЕЛИ",#(data.links or{}),"icon16/connect.png",C.green},{"АККАУНТЫ",data.accounts or 0,"icon16/group.png",C.yellow},{"ФАЙЛЫ",data.files or 0,"icon16/folder.png",C.purple}};for i,s in ipairs(stats)do local x=16+(i-1)*270;local p=vgui.Create("DPanel",f);p:SetPos(x,62);p:SetSize(256,82);p.Paint=function(_,w,h)draw.RoundedBox(10,0,0,w,h,C.card);surface.SetMaterial(Material(s[3]));surface.SetDrawColor(255,255,255);surface.DrawTexturedRect(16,24,32,32);draw.SimpleText(s[1],"GRMNet_Small",62,20,C.dim);draw.SimpleText(tostring(s[2]),"GRMNet_Title",62,48,s[4])end end
 local list=darkList(f,16,160,650,490,{{"Устройство",180},{"Тип",105},{"Сеть",110},{"Статус",75},{"Владелец",150}});local selected="";local selectedRow=nil
 local detail=vgui.Create("DPanel",f);detail:SetPos(680,160);detail:SetSize(424,490);detail.Paint=function(_,w,h)draw.RoundedBox(10,0,0,w,h,C.panel);if not selectedRow then draw.SimpleText("Выберите устройство","GRMNet_Head",w/2,70,C.dim,TEXT_ALIGN_CENTER)else draw.SimpleText(selectedRow.name,"GRMNet_Title",18,24,C.text);draw.SimpleText("ID: "..selectedRow.id,"GRMNet_Small",18,62,C.dim);draw.SimpleText("Тип: "..selectedRow.kind,"GRMNet_Body",18,92,C.text);draw.SimpleText("Сеть: "..selectedRow.network,"GRMNet_Body",18,120,C.text);draw.SimpleText("Маршрут: "..(selectedRow.router~=""and selectedRow.router or"нет"),"GRMNet_Body",18,148,selectedRow.online and C.green or C.red)end end
 for _,d in ipairs(data.devices or{})do local line=addLine(list,d.name,d.kind,d.network,d.online and"ONLINE"or"OFFLINE",d.owner);line._data=d end;list.OnRowSelected=function(_,_,line)selectedRow=line._data;selected=selectedRow.id end
 btn(detail,"Настроить",18,220,186,42,C.blue,function()if selected~=""then adminAction("configure",selected)end end);btn(detail,"Вкл / выкл",220,220,186,42,C.yellow,function()if selected~=""then adminAction("toggle",selected)end end);btn(detail,"Удалить кабели",18,276,186,42,C.card,function()if selected~=""then adminAction("unlink",selected)end end);btn(detail,"Удалить устройство",220,276,186,42,C.red,function()if selected==""then return end;Derma_Query("Удалить устройство и его кабели?","GRM Network","Удалить",function()adminAction("delete",selected)end,"Отмена")end)
 btn(f,"Обновить",16,662,150,40,C.blue,function()adminAction("refresh","")end);btn(f,"Закрыть",954,662,150,40,C.card,function()f:Close()end);textLabel(f,"ПКМ устройством через Toolgun открывает те же настройки. Все изменения сохраняются автоматически.",184,668,750,28,"GRMNet_Body",C.dim)
end)
net.Receive("GRM_Net_AdminOpen",function()
 if IsValid(E.ActiveFrame)then E.ActiveFrame:Remove()end;if IsValid(E.AdminCenter)then E.AdminCenter:Remove()end
 local ent=net.ReadEntity();local cfg=net.ReadTable()or{};if not IsValid(ent)then return end;local f=frame("НАСТРОЙКА СЕТЕВОГО УСТРОЙСТВА",620,680);local name=entry(f,"Название",24,78,270,34);name:SetText(ent:GetDisplayName());local network=entry(f,"SSID / сеть",310,78,270,34);network:SetText(ent:GetNetworkID());local password=secureEntry(f,"Новый пароль Wi-Fi (пусто = не менять)",24,126,556,34);local range=vgui.Create("DNumberWang",f);range:SetPos(24,174);range:SetSize(180,34);range:SetMin(100);range:SetMax(5000);range:SetValue(cfg.range or 900);local faction=entry(f,"Ограничить модули фракцией (пусто = всем)",220,174,360,34);faction:SetText(cfg.faction or"")
 
 -- OS Type selector
 local osTypeLabel=vgui.Create("DLabel",f);osTypeLabel:SetPos(24,214);osTypeLabel:SetSize(180,30);osTypeLabel:SetText("Тип операционной системы:");osTypeLabel:SetFont("GRMNet_Normal");osTypeLabel:SetTextColor(C.text)
 local osTypeCombo=vgui.Create("DComboBox",f);osTypeCombo:SetPos(220,214);osTypeCombo:SetSize(360,30);osTypeCombo:SetFont("GRMNet_Normal")
 local osTypes={
  {id="civilian",name="Гражданская (базовые приложения)"},
  {id="service",name="Служебная (+модули, Wi-Fi)"},
  {id="personal",name="Персональная (+фоторобот)"},
  {id="business",name="Бизнес (финансы, документы)"},
  {id="lawenforcement",name="Правоохранительная (+розыск, CCTV)"}
 }
 for _,osType in ipairs(osTypes)do osTypeCombo:AddChoice(osType.name,osType.id)end
 local currentOS=cfg.osType or"civilian"
 for i,osType in ipairs(osTypes)do if osType.id==currentOS then osTypeCombo:ChooseOptionID(i)break end end
 
 local active=vgui.Create("DCheckBoxLabel",f);active:SetPos(24,254);active:SetText("Устройство включено");active:SetTextColor(C.text);active:SetValue(ent:GetDeviceActive()and 1 or 0);active:SizeToContents();local clearPassword=vgui.Create("DCheckBoxLabel",f);clearPassword:SetPos(220,254);clearPassword:SetText("Сделать Wi-Fi открытым");clearPassword:SetTextColor(C.text);clearPassword:SizeToContents();local flags={};for i,v in ipairs({{"allowFaction","Фракционная база"},{"allowArrest","Аресты"},{"allowFines","Розыск и штрафы"},{"allowCCTV","CCTV"},{"allowRoomTap","Прослушка"}})do local c=vgui.Create("DCheckBoxLabel",f);c:SetPos(24,272+(i-1)*42);c:SetText(v[2]);c:SetTextColor(C.text);c:SetValue(cfg[v[1]]and 1 or 0);c:SizeToContents();flags[v[1]]=c end;btn(f,"СОХРАНИТЬ",24,530,556,48,C.green,function()local d={name=name:GetText(),network=network:GetText(),password=password:GetText(),range=range:GetValue(),faction=faction:GetText(),active=active:GetChecked(),clearPassword=clearPassword:GetChecked(),osType=osTypeCombo:GetSelected()};for k,c in pairs(flags)do d[k]=c:GetChecked()end;net.Start("GRM_Net_AdminSave");net.WriteEntity(ent);net.WriteTable(d);net.SendToServer();f:Close()end)
end)
net.Receive("GRM_Net_Document",function()
 local ent=net.ReadEntity()
 local title=net.ReadString()
 local content=net.ReadString()
 local owner=net.ReadString()
 local imgFile=net.ReadString()
 local category=net.ReadString()
 local imageBytes=net.ReadUInt(24); local imageData=imageBytes>0 and net.ReadData(imageBytes) or nil
 if imageData and imgFile~="" then file.CreateDir("grm_computer/images"); local localImage="grm_computer/images/"..string.GetFileFromFilename(imgFile); file.Write(localImage,imageData); imgFile=localImage end
 
 -- Check if this is a photo document with image
 if imgFile~=""and(category=="photo"or category=="photo_print")then
  -- Photo document viewer
  local f=frame("ФОТОРОБОТ · "..title,520,680)
  
  -- Image panel
  local imgPanel=vgui.Create("DPanel",f)
  imgPanel:SetPos(20,60)
  imgPanel:SetSize(480,480)
  imgPanel.Paint=function(_,w,h)
   draw.RoundedBox(8,0,0,w,h,Color(235,225,210))
   -- Paper texture
   for i=1,30 do
    draw.RoundedBox(1,math.random(w),math.random(h),math.random(2,4),math.random(1,2),Color(200,190,175,40))
   end
  end
  
  -- Try to load image using DImage with correct path
  local img=vgui.Create("DImage",imgPanel)
  img:SetPos(20,20)
  img:SetSize(440,440)
  
  -- Check if file exists and load
  if file.Exists(imgFile,"DATA")then
   -- Use ../data/ path for DImage
   img:SetImage("../data/"..imgFile)
  else
   -- Try without subfolder
   local altFile=imgFile:match("([^/]+)$")
   if file.Exists("grm_photos/"..altFile,"DATA")then
    img:SetImage("../data/grm_photos/"..altFile)
   else
    -- Fallback to error image
    img:SetImage("vgui/error")
   end
  end
  
  -- Description
  local desc=content:gsub("%[ИЗОБРАЖЕНИЕ: [^%]]+%]",""):gsub("ФОТОРОБОТ[^\n]*\n",""):gsub("Эффект:[^\n]*\n",""):gsub("^%s+","")
  local descLabel=vgui.Create("DLabel",f)
  descLabel:SetPos(20,550)
  descLabel:SetSize(480,80)
  descLabel:SetFont("GRMNet_Body")
  descLabel:SetTextColor(C.text)
  descLabel:SetWrap(true)
  descLabel:SetText(desc)
  
  -- Owner
  local ownerLabel=vgui.Create("DLabel",f)
  ownerLabel:SetPos(20,640)
  ownerLabel:SetSize(480,20)
  ownerLabel:SetFont("GRMNet_Small")
  ownerLabel:SetTextColor(C.dim)
  ownerLabel:SetText("Автор: "..owner.." · "..os.date("%d.%m.%Y"))
 else
  -- Regular text document viewer
  local f=frame("ДОКУМЕНТ · "..title,700,600)
  local text=vgui.Create("DTextEntry",f)
  text:SetPos(18,68)
  text:SetSize(664,492)
  text:SetMultiline(true)
  text:SetEditable(false)
  text:SetText(content)
  text:SetFont("GRMNet_Body")
  
  local o=vgui.Create("DLabel",f)
  o:SetPos(18,564)
  o:SetSize(660,22)
  o:SetText("Автор: "..owner)
  o:SetFont("GRMNet_Small")
  o:SetTextColor(C.dim)
 end
end)
net.Receive("GRM_Net_MailSend",function()end)
print("[GRM Electronics] client v1.5.0 loaded")

-- Persistent social/chat snapshot bridge.
GRM=GRM or {}; GRM.Computer=GRM.Computer or {}; GRM.Computer.Social=GRM.Computer.Social or {}
net.Receive("GRM_Computer_Social_Snapshot",function()
    GRM.Computer.Social=net.ReadTable() or {}
    hook.Run("GRM_ComputerSocialUpdated",GRM.Computer.Social)
end)
concommand.Add("grm_social_refresh",function()
    net.Start("GRM_Computer_Social_Request"); net.SendToServer()
end)

hook.Add("GRM_ComputerSocialUpdated", "GRM_ComputerSocial_Notify", function(state)
    if not state then return end
    GRM.Computer = GRM.Computer or {}
    local total=0
    for _, messages in pairs(state.messages or {}) do total=total + #messages end
    GRM.Computer.UnreadMessages=total
    if total>0 then notification.AddLegacy("GRM: синхронизированы публикации и сообщения ("..total..")",NOTIFY_GENERIC,3) end
end)
