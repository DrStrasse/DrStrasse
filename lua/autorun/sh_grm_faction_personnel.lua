--[[ GRM Faction Personnel v1: кадровые дела, история и испытательный срок. ]]
if SERVER then AddCSLuaFile()end
GRM=GRM or{};GRM.FactionPersonnel=GRM.FactionPersonnel or{};local P=GRM.FactionPersonnel
P.Version="1.0.0";if GRM.Access and GRM.Access.Register then GRM.Access.Register("faction.personnel.view",{label="Фракции: просмотр кадровых дел",scope="character"});GRM.Access.Register("faction.personnel.manage",{label="Фракции: ведение кадровых дел",scope="character"})end;local NREQ="GRM_FactionPersonnel_Request";local NDATA="GRM_FactionPersonnel_Data";local NACT="GRM_FactionPersonnel_Action"
if SERVER then
 util.AddNetworkString(NREQ);util.AddNetworkString(NDATA);util.AddNetworkString(NACT)
 local function charKey(p)return GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(p)or(IsValid(p)and p:SteamID64()..":char1"or"")end
 local function canView(ply,factionName,key)local f=Factions and Factions[factionName];if not f then return false end;if ply:IsSuperAdmin()then return true end;if FactionsAPI and FactionsAPI.IsLeader and FactionsAPI.IsLeader(ply,factionName)then return true end;if GRM.Access and GRM.Access.Can and GRM.Access.Can(ply,"faction.personnel.view",{faction=factionName})==true then return true end;return key==charKey(ply)and f.Members and f.Members[key]~=nil end
 local function canManage(ply,factionName)if ply:IsSuperAdmin()then return true end;if FactionsAPI and FactionsAPI.IsLeader and FactionsAPI.IsLeader(ply,factionName)then return true end;return GRM.Access and GRM.Access.Can and GRM.Access.Can(ply,"faction.personnel.manage",{faction=factionName})==true end
 local function send(ply,factionName,key,ok,message)
  local personnel,rec,archived;if ok~=false and GRM.FactionCore and GRM.FactionCore.GetPersonnel then personnel,rec,archived=GRM.FactionCore.GetPersonnel(factionName,key,true)end;local payload={ok=ok~=false,message=tostring(message or""),faction=factionName,key=key,archived=archived==true,role=rec and rec.Role or"",department=rec and rec.Department or"",personnel=personnel or{}}
  net.Start(NDATA);net.WriteTable(payload);net.Send(ply)
 end
 local function sendList(ply,factionName)local rows=GRM.FactionCore and GRM.FactionCore.ListPersonnel and GRM.FactionCore.ListPersonnel(factionName,true)or{};local out={};for i=1,math.min(500,#rows)do local r=rows[i];out[#out+1]={key=r.key,role=r.role,department=r.department,status=r.personnel and r.personnel.status or"active",joinedAt=r.personnel and r.personnel.joinedAt or 0,archived=r.archived==true}end;net.Start(NDATA);net.WriteTable({ok=true,kind="list",faction=factionName,rows=out});net.Send(ply)end
 net.Receive(NREQ,function(bits,ply)if GRM.Net and not GRM.Net.Guard(ply,"faction.personnel.request",{rate=.25,burst=4,maxBits=4096},{bits=bits})then return end;local factionName,key=net.ReadString(),net.ReadString();if not canView(ply,factionName,key)then send(ply,factionName,key,false,"Нет доступа к кадровому делу")return end;if key==""then sendList(ply,factionName)else send(ply,factionName,key,true)end end)
 net.Receive(NACT,function(bits,ply)if GRM.Net and not GRM.Net.Guard(ply,"faction.personnel.action",{rate=.5,burst=3,maxBits=8192},{bits=bits})then return end;local factionName,key,op,text=net.ReadString(),net.ReadString(),net.ReadString(),string.sub(string.Trim(net.ReadString()or""),1,400);if not canManage(ply,factionName)then send(ply,factionName,key,false,"Нет права редактирования")return end;local ok,result
  if op=="note"then ok,result=GRM.FactionCore.AddRecord(factionName,key,"note",ply,text,{})
  elseif op=="commendation"then ok,result=GRM.FactionCore.AddRecord(factionName,key,"commendation",ply,text~=""and text or"Объявлена благодарность",{})
  elseif op=="reprimand"then ok,result=GRM.FactionCore.AddRecord(factionName,key,"reprimand",ply,text~=""and text or"Объявлено дисциплинарное взыскание",{})
  elseif op=="probation"then local days=math.Clamp(math.floor(tonumber(text)or 0),0,365);ok,result=GRM.FactionCore.SetProbation(factionName,key,days>0 and(os.time()+days*86400)or 0,ply)
  else return end
  if GRM.Audit and GRM.Audit.Write then GRM.Audit.Write("factions","personnel."..op,ply,{faction=factionName,characterKey=key},{text=text,ok=ok==true})end;send(ply,factionName,key,ok,result)
 end)
else
 local C={bg=Color(11,17,26),panel=Color(23,33,47),text=Color(230,238,247),dim=Color(145,160,180),blue=Color(70,155,245),green=Color(55,190,120),red=Color(205,75,85),gold=Color(235,190,80)}
 surface.CreateFont("GRMPersonnelTitle",{font="Roboto",size=21,weight=900,extended=true});surface.CreateFont("GRMPersonnelText",{font="Roboto",size=14,weight=600,extended=true})
 local panel,facCombo,members,summary,history,noteEntry,selectedFaction,selectedKey
 local function displayFac(name)local f=FactionsData and FactionsData[name];return GRM.Factions and GRM.Factions.DisplayName and GRM.Factions.DisplayName(f,name)or name end
 local function displayDept(factionName,key)local f=FactionsData and FactionsData[factionName];return GRM.Factions and GRM.Factions.DepartmentDisplayName and GRM.Factions.DepartmentDisplayName(f,key)or key end
 local function btn(parent,text,color)local b=vgui.Create("DButton",parent);b:SetText(text);b:SetFont("GRMPersonnelText");b:SetTextColor(color_white);b.Paint=function(s,w,h)draw.RoundedBox(6,0,0,w,h,s:IsHovered()and Color(math.min(255,color.r+18),math.min(255,color.g+18),math.min(255,color.b+18))or color)end;return b end
 local function request()if selectedFaction and selectedKey then net.Start(NREQ);net.WriteString(selectedFaction);net.WriteString(selectedKey);net.SendToServer()end end
 local function requestList()if selectedFaction then net.Start(NREQ);net.WriteString(selectedFaction);net.WriteString("");net.SendToServer()end end
 local function rebuildMembers()
  if not IsValid(members)then return end;members:Clear();local f=FactionsData and FactionsData[selectedFaction];for key,rec in pairs(f and f.Members or{})do local line=members:AddLine(rec._rpName or key,rec.Role or"",displayDept(selectedFaction,rec.Department or""),rec._dutyStatus or"");line.CharacterKey=key end
 end
 local function selectFaction(name)selectedFaction=name;selectedKey=nil;if IsValid(summary)then summary:SetText("Загрузка кадрового реестра...")end;if IsValid(history)then history:Clear()end;if IsValid(members)then members:Clear()end;requestList()end
 local function sendAction(op,text)if not selectedFaction or not selectedKey then return end;net.Start(NACT);net.WriteString(selectedFaction);net.WriteString(selectedKey);net.WriteString(op);net.WriteString(tostring(text or""));net.SendToServer()end
 local function refreshFactionChoices(data)if not IsValid(facCombo)then return end;local keep=selectedFaction;facCombo:Clear();local names={};for name in pairs(data or FactionsData or{})do names[#names+1]=name end;table.sort(names,function(a,b)return displayFac(a)<displayFac(b)end);for _,name in ipairs(names)do facCombo:AddChoice(displayFac(name).."  ["..name.."]",name,name==keep)end;if keep and(data or FactionsData or{})[keep]then facCombo:SetValue(displayFac(keep).."  ["..keep.."]")end end
 local function build(parent)
  panel=parent;parent.Paint=function(_,w,h)draw.RoundedBox(7,0,0,w,h,C.bg)end
  facCombo=vgui.Create("DComboBox",parent);facCombo:SetPos(14,14);facCombo:SetSize(420,30);facCombo:SetValue("Выберите фракцию");local own=LocalPlayer():GetNWString("GRM_Faction","");facCombo.OnSelect=function(_,_,_,data)selectFaction(data)end;refreshFactionChoices(FactionsData)
  members=vgui.Create("DListView",parent);members:SetPos(14,56);members:SetSize(500,570);members:AddColumn("Сотрудник");members:AddColumn("Должность");members:AddColumn("Отдел");members:AddColumn("Статус");members.OnRowSelected=function(_,_,line)selectedKey=line.CharacterKey;request()end
  summary=vgui.Create("DLabel",parent);summary:SetPos(530,56);summary:SetSize(700,100);summary:SetWrap(true);summary:SetFont("GRMPersonnelTitle");summary:SetTextColor(C.text);summary:SetText("Выберите сотрудника слева")
  history=vgui.Create("DListView",parent);history:SetPos(530,160);history:SetSize(700,315);history:AddColumn("Дата"):SetFixedWidth(130);history:AddColumn("Событие"):SetFixedWidth(170);history:AddColumn("Запись");history:AddColumn("Автор"):SetFixedWidth(140)
  noteEntry=vgui.Create("DTextEntry",parent);noteEntry:SetPos(530,490);noteEntry:SetSize(700,32);noteEntry:SetPlaceholderText("Основание, заметка или описание решения")
  local note=btn(parent,"ДОБАВИТЬ ЗАПИСЬ",C.blue);note:SetPos(530,536);note:SetSize(160,40);note.DoClick=function()sendAction("note",noteEntry:GetValue())end
  local praise=btn(parent,"БЛАГОДАРНОСТЬ",C.green);praise:SetPos(700,536);praise:SetSize(160,40);praise.DoClick=function()sendAction("commendation",noteEntry:GetValue())end
  local reprimand=btn(parent,"ВЗЫСКАНИЕ",C.red);reprimand:SetPos(870,536);reprimand:SetSize(150,40);reprimand.DoClick=function()sendAction("reprimand",noteEntry:GetValue())end
  local probation=vgui.Create("DNumberWang",parent);probation:SetPos(1030,536);probation:SetSize(70,40);probation:SetMin(0);probation:SetMax(365);probation:SetValue(14);local probBtn=btn(parent,"ИСПЫТАТЕЛЬНЫЙ СРОК",C.gold);probBtn:SetPos(1110,536);probBtn:SetSize(120,40);probBtn.DoClick=function()sendAction("probation",probation:GetValue())end
  local refresh=btn(parent,"ОБНОВИТЬ",Color(75,90,110));refresh:SetPos(1070,586);refresh:SetSize(160,34);refresh.DoClick=function()request()end
  if own~=""then facCombo:SetValue(displayFac(own).."  ["..own.."]");selectFaction(own)end
 end
 hook.Add("GRM_FactionsAdmin_BuildTabs","GRM_FactionPersonnel_Tab",function(tabs)if not IsValid(tabs)then return end;local p=vgui.Create("DPanel");p:SetPaintBackground(false);tabs:AddSheet("Кадровые дела",p,"icon16/vcard.png");timer.Simple(0,function()if IsValid(p)then build(p)end end)end)
 net.Receive(NDATA,function()local d=net.ReadTable()or{};if not d.ok then notification.AddLegacy(d.message or"Ошибка",NOTIFY_ERROR,5)return end;if d.kind=="list"then if d.faction~=selectedFaction or not IsValid(members)then return end;members:Clear();local f=FactionsData and FactionsData[d.faction];for _,r in ipairs(d.rows or{})do local live=f and f.Members and f.Members[r.key];local name=live and live._rpName or r.key;local state=r.archived and"АРХИВ"or(r.status=="probation"and"ИСПЫТАНИЕ"or"ДЕЙСТВУЕТ");local line=members:AddLine(name,r.role or"",displayDept(d.faction,r.department or""),state);line.CharacterKey=r.key end;summary:SetText("Выберите кадровое дело слева")return end;if d.faction~=selectedFaction or d.key~=selectedKey then return end;local p=d.personnel or{};local status=p.status=="probation"and("ИСПЫТАТЕЛЬНЫЙ СРОК до "..os.date("%d.%m.%Y",p.probationUntil or 0))or(p.status=="dismissed"and"УВОЛЕН"or"ДЕЙСТВУЮЩИЙ СОТРУДНИК");summary:SetText((d.archived and"АРХИВ • "or"")..d.key.."\n"..d.role.." • "..displayDept(d.faction,d.department).."\n"..status.." • принят "..os.date("%d.%m.%Y",p.joinedAt or 0));history:Clear();for i=#(p.history or{}),1,-1 do local r=p.history[i];history:AddLine(os.date("%d.%m.%Y %H:%M",r.time or 0),r.type or"",r.text or"",r.actorName or"")end;if IsValid(noteEntry)then noteEntry:SetText("")end end)
 hook.Add("GRM_FactionUIRefreshed","GRM_FactionPersonnel_RosterRefresh",function(data)if IsValid(panel)then refreshFactionChoices(data);if selectedFaction then requestList()end end end)
end
print("[GRM Faction Personnel] v"..P.Version.." loaded")
