-- GRM Quest Ecosystem v1.0.0 — modern player/admin UI, tracker and cutscenes
if not CLIENT then return end
GRM=GRM or {};GRM.Quests=GRM.Quests or {};local Q=GRM.Quests
Q.ClientRows=Q.ClientRows or {};Q.Cutscene=Q.Cutscene or{active=false}

surface.CreateFont("GRMQ_Title",{font="Roboto",size=26,weight=800,extended=true})
surface.CreateFont("GRMQ_Head",{font="Roboto",size=19,weight=700,extended=true})
surface.CreateFont("GRMQ_Body",{font="Roboto",size=15,weight=500,extended=true})
surface.CreateFont("GRMQ_Small",{font="Roboto",size=12,weight=400,extended=true})
local C={bg=Color(9,14,23,248),panel=Color(19,28,42,248),card=Color(28,39,57,250),hover=Color(39,55,78),blue=Color(65,145,240),green=Color(70,205,125),red=Color(220,75,80),yellow=Color(242,190,75),text=Color(238,244,252),dim=Color(145,160,180)}
local function frame(title,w,h)
 local f=vgui.Create("DFrame");f:SetSize(math.min(w,ScrW()-40),math.min(h,ScrH()-40));f:Center();f:SetTitle("");f:ShowCloseButton(true);f:MakePopup();f.Paint=function(_,pw,ph)draw.RoundedBox(10,0,0,pw,ph,C.bg);draw.RoundedBoxEx(10,0,0,pw,48,Color(16,25,39),true,true,false,false);draw.SimpleText(title,"GRMQ_Title",18,24,C.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)end;return f
end
local function button(parent,text,x,y,w,h,color,fn)
 local b=vgui.Create("DButton",parent);b:SetPos(x,y);b:SetSize(w,h);b:SetText("");b.DoClick=function(self)surface.PlaySound("buttons/button15.wav");if fn then fn(self)end end
 b.Paint=function(self,pw,ph)local base=color or Color(48,64,86);local col=self:IsDown()and Color(math.max(0,base.r-22),math.max(0,base.g-22),math.max(0,base.b-22))or(self:IsHovered()and Color(math.min(255,base.r+22),math.min(255,base.g+22),math.min(255,base.b+22))or base);draw.RoundedBox(8,0,0,pw,ph,col);surface.SetDrawColor(self:IsHovered()and Color(155,205,255,210)or Color(85,110,145,170));surface.DrawOutlinedRect(0,0,pw,ph,1);draw.SimpleText(text,"GRMQ_Body",pw/2,ph/2+(self:IsDown()and 1 or 0),C.text,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)end;return b
end
local function label(parent,text,x,y,w,h,font,color)
 local l=vgui.Create("DLabel",parent);l:SetPos(x,y);l:SetSize(w,h);l:SetText(text or "");l:SetFont(font or"GRMQ_Body");l:SetTextColor(color or C.text);l:SetWrap(true);return l
end
local function objectiveText(def,p)
 local step=def and def.steps and def.steps[tonumber(p and p.step)or 1];if not step then return"Завершение..."end
 local suffix="";if step.type=="event"or step.type=="item"then suffix=("  %d/%d"):format(tonumber(p.count)or 0,tonumber(step.count)or 1)end
 return tostring(step.title or"Этап")..suffix
end
local function playerOp(op,id)net.Start("GRM_Quest_PlayerOp")net.WriteString(op)net.WriteString(id or "")net.SendToServer()end

net.Receive("GRM_Quest_Sync",function()Q.ClientRows=net.ReadTable()or {}end)
net.Receive("GRM_Quest_Notice",function()local ok=net.ReadBool();local msg=net.ReadString();local sound=net.ReadString();local duration=net.ReadFloat();local banner=net.ReadBool();local heading=net.ReadString();surface.PlaySound(sound~=""and sound or(ok and"buttons/button14.wav"or"buttons/button10.wav"));if notification then notification.AddLegacy(msg,ok and NOTIFY_GENERIC or NOTIFY_ERROR,duration)end;if banner then Q.NoticeToast={text=msg,heading=heading,untilAt=CurTime()+duration,started=CurTime()}end end)
hook.Add("HUDPaint","GRM_Quest_CompletionNotice",function()local t=Q.NoticeToast;if not t then return end;if CurTime()>t.untilAt then Q.NoticeToast=nil return end;local fade=math.Clamp(math.min((CurTime()-t.started)*4,(t.untilAt-CurTime())*3),0,1);local w=math.min(620,ScrW()-60);local x=ScrW()/2-w/2;local y=105;draw.RoundedBox(12,x,y,w,78,Color(10,18,30,math.floor(235*fade)));surface.SetDrawColor(242,190,75,math.floor(255*fade));surface.DrawOutlinedRect(x,y,w,78,2);draw.SimpleText(t.heading~=""and t.heading or"УВЕДОМЛЕНИЕ","GRMQ_Small",ScrW()/2,y+16,Color(242,190,75,math.floor(255*fade)),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER);draw.SimpleText(t.text,"GRMQ_Head",ScrW()/2,y+48,Color(245,248,252,math.floor(255*fade)),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)end)

local function dialogueNodes(value)
 if isstring(value)then return value~=""and{{id="legacy",text=value,choices={}}}or{}end
 return istable(value)and(value.nodes or value)or{}
end
local function playDialogue(npcName,nodes,onAction)
 nodes=dialogueNodes(nodes);if#nodes==0 then if onAction then onAction("finish")end return end
 if IsValid(Q.TalkFrame)then Q.TalkFrame:Remove()end
 local f=vgui.Create("DFrame");Q.TalkFrame=f
 f:SetSize(math.min(720,ScrW()-80),math.min(420,ScrH()-80));f:SetPos(40,ScrH()-f:GetTall()-48)
 f:SetTitle("");f:ShowCloseButton(false);f:MakePopup();f:SetDraggable(false)
 f.Paint=function(_,w,h)
  draw.RoundedBox(10,0,0,w,h,Color(12,16,24,236))
  surface.SetDrawColor(70,110,150,80);surface.DrawOutlinedRect(0,0,w,h,1)
 end
 local byID={};for i,n in ipairs(nodes)do byID[tostring(n.id or i)]=i end;local index=1
 local function show(i)
  index=math.Clamp(tonumber(i)or 1,1,#nodes);local n=nodes[index];f:Clear()
  local close=vgui.Create("DButton",f);close:SetSize(28,24);close:SetPos(f:GetWide()-36,10);close:SetText("")
  close.Paint=function(s,w,h)draw.RoundedBox(4,0,0,w,h,s:IsHovered()and C.red or Color(40,48,60));draw.SimpleText("X","GRMQ_Body",w/2,h/2,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)end
  close.DoClick=function()f:Close()end
  label(f,tostring(n.speaker~=""and n.speaker or npcName),20,14,f:GetWide()-70,26,"GRMQ_Head",C.yellow)
  local wrap=vgui.Create("DLabel",f);wrap:SetPos(20,46);wrap:SetSize(f:GetWide()-40,110);wrap:SetWrap(true);wrap:SetFont("GRMQ_Body");wrap:SetTextColor(C.text);wrap:SetText(tostring(n.text or""))
  local choices=istable(n.choices)and n.choices or{}
  local function advance(nextID,action)
   if action and action~=""and onAction then onAction(action)end
   if action=="close"or action=="accept"then f:Close();return end
   local ni=byID[tostring(nextID or"")]or(index+1)
   if ni>#nodes then if onAction then onAction("finish")end;f:Close()else show(ni)end
  end
  local y=168
  local function opt(num,text,fn)
   local b=vgui.Create("DButton",f);b:SetPos(20,y);b:SetSize(f:GetWide()-40,42);b:SetText("")
   b.Paint=function(s,w,h)
    draw.RoundedBox(6,0,0,w,h,s:IsHovered()and Color(36,52,74)or Color(22,30,44))
    draw.SimpleText(tostring(num),"GRMQ_Head",16,h/2,C.blue,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
    draw.SimpleText(text,"GRMQ_Body",42,h/2,C.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
   end
   b.DoClick=function()surface.PlaySound("buttons/button15.wav");fn()end
   y=y+48
  end
  if#choices>0 then
   for ci,ch in ipairs(choices)do opt(ci,ch.text~=""and ch.text or("Ответ "..ci),function()advance(ch.next,ch.action)end)end
  else
   opt(1,index<#nodes and"Продолжить"or"Завершить разговор",function()advance(n.next,"")end)
  end
  label(f,"Esc — выйти",20,f:GetTall()-28,200,18,"GRMQ_Small",C.dim)
 end
 show(1)
end
Q._previewDialogue=playDialogue

local function openNPC()
 local npc=net.ReadEntity();local npcName=net.ReadString();local rows=net.ReadTable()or {};local f=frame(npcName,760,600)
 label(f,"ЗАДАНИЯ И ДИАЛОГИ",20,58,300,24,"GRMQ_Small",C.yellow)
 local scroll=vgui.Create("DScrollPanel",f);scroll:SetPos(18,86);scroll:SetSize(300,490)
 local detail=vgui.Create("DPanel",f);detail:SetPos(330,58);detail:SetSize(412,518);detail.Paint=function(_,w,h)draw.RoundedBox(9,0,0,w,h,C.panel)end
 local function show(row)
  detail:Clear();local d,p=row.definition,row.progress
  label(detail,d.title,18,18,376,34,"GRMQ_Head")
  label(detail,d.category~=""and d.category or"КВЕСТ",18,50,376,18,"GRMQ_Small",C.yellow)
  label(detail,d.summary,18,78,376,100,"GRMQ_Body",C.dim)
  local state=not p and"Доступно"or(p.status=="completed"and"Завершено"or objectiveText(d,p));label(detail,state,18,185,376,48,"GRMQ_Head",p and p.status=="completed"and C.green or C.text)
  local dialogue=not p and d.dialogue.offer or(p.status=="active"and d.dialogue.active or d.dialogue.complete);local nodes=dialogueNodes(dialogue);local preview=nodes[1]and nodes[1].text or"Мне есть что тебе предложить.";label(detail,preview,18,245,376,105,"GRMQ_Body",C.text)
  if#nodes>0 then button(detail,"▶  Начать диалог ("..#nodes.." реплик)",18,382,376,42,C.violet or C.blue,function()playerOp("dialogue",d.id);f:Close()end)end
  if not p and row.available then button(detail,"Принять задание",18,446,180,46,C.blue,function()playerOp("accept",d.id);f:Close()end)
  elseif p and p.status=="active"then button(detail,"Отказаться",18,446,180,46,C.red,function()playerOp("abandon",d.id);f:Close()end)
  elseif p and p.status=="completed"and d.repeatable then button(detail,"Начать квест заново",18,446,180,46,C.green,function()playerOp("restart",d.id);f:Close()end)end
  button(detail,"Закрыть",214,446,180,46,C.card,function()f:Close()end)
 end
 for i,row in ipairs(rows)do local d,p=row.definition,row.progress;local b=button(scroll,d.title,0,(i-1)*76,280,66,p and p.status=="completed"and Color(35,75,55)or C.card,function()show(row)end);b.Paint=function(self,w,h)draw.RoundedBox(8,0,0,w,h,self:IsHovered()and C.hover or(p and p.status=="completed"and Color(31,70,52)or C.card));draw.SimpleText(d.title,"GRMQ_Body",12,13,C.text);draw.SimpleText(not p and"Новое задание"or(p.status=="active"and objectiveText(d,p)or"Завершено"),"GRMQ_Small",12,42,p and p.status=="completed"and C.green or C.dim)end end
 if rows[1]then show(rows[1])else label(detail,"У этого персонажа пока нет заданий.",20,30,370,60,"GRMQ_Head",C.dim)end
end
net.Receive("GRM_Quest_OpenNPC",openNPC)

local function openJournal()
 local f=frame("ЖУРНАЛ ЗАДАНИЙ",860,620);local rows=Q.ClientRows or{};local list=vgui.Create("DScrollPanel",f);list:SetPos(18,62);list:SetSize(350,536);local detail=vgui.Create("DPanel",f);detail:SetPos(382,62);detail:SetSize(460,536);detail.Paint=function(_,w,h)draw.RoundedBox(9,0,0,w,h,C.panel)end
 local function show(row)local d,p=row.definition,row.progress;detail:Clear();label(detail,d.title,18,18,424,38,"GRMQ_Head");label(detail,d.summary,18,68,424,110,"GRMQ_Body",C.dim);label(detail,p.status=="completed"and"ЗАВЕРШЕНО"or objectiveText(d,p),18,190,424,62,"GRMQ_Head",p.status=="completed"and C.green or C.yellow);local y=265;for i,step in ipairs(d.steps or{})do local done=i<(p.step or 1)or p.status=="completed";draw.RoundedBox(6,18,y,424,38,done and Color(32,72,53)or C.card);draw.SimpleText((done and"✓  "or"○  ")..step.title,"GRMQ_Body",30,y+19,done and C.green or C.text,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER);y=y+44;if y>450 then break end end;if p.status=="active"then button(detail,"Отказаться от задания",18,478,210,40,C.red,function()playerOp("abandon",d.id);f:Close()end)elseif p.status=="completed"and d.repeatable then button(detail,"Начать заново",18,478,210,40,C.green,function()playerOp("restart",d.id);f:Close()end)end end
 local shown=0;for _,row in ipairs(rows)do if row.progress then shown=shown+1;local idx=shown;local d,p=row.definition,row.progress;local b=button(list,d.title,0,(idx-1)*72,330,62,C.card,function()show(row)end);b.Paint=function(self,w,h)draw.RoundedBox(8,0,0,w,h,self:IsHovered()and C.hover or C.card);draw.SimpleText(d.title,"GRMQ_Body",12,16,C.text);draw.SimpleText(p.status=="completed"and"Завершено"or objectiveText(d,p),"GRMQ_Small",12,43,p.status=="completed"and C.green or C.dim)end;if shown==1 then show(row)end end end
 if shown==0 then label(detail,"Активных и завершённых заданий пока нет. Поговорите с персонажами в мире.",24,30,412,100,"GRMQ_Head",C.dim)end
end
net.Receive("GRM_Quest_Journal",openJournal)
concommand.Add("grm_quests",openJournal)

hook.Add("HUDPaint","GRM_Quest_Tracker",function()
 if Q.Cutscene.active or(GRM.CCTV and GRM.CCTV.IsViewing and GRM.CCTV.IsViewing())then return end
 local active={};for _,row in ipairs(Q.ClientRows or {})do if row.progress and row.progress.status=="active"then active[#active+1]=row end end
 if#active==0 then return end;local w=320;local x=ScrW()-w-22;local y=90;draw.RoundedBox(9,x,y,w,36+#active*52,Color(10,16,25,220));draw.SimpleText("ЗАДАНИЯ","GRMQ_Head",x+14,y+18,C.yellow,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 for i,row in ipairs(active)do local yy=y+32+(i-1)*52;draw.RoundedBox(6,x+9,yy,w-18,45,C.card);draw.SimpleText(row.definition.title,"GRMQ_Body",x+18,yy+12,C.text);draw.SimpleText(objectiveText(row.definition,row.progress),"GRMQ_Small",x+18,yy+31,C.dim)
  local step=row.definition.steps and row.definition.steps[row.progress.step or 1];if step and step.type=="visit"then local target;if step.pos then target=Vector(step.pos.x,step.pos.y,step.pos.z)elseif step.min and step.max then target=Vector((step.min.x+step.max.x)/2,(step.min.y+step.max.y)/2,(step.min.z+step.max.z)/2)end;if target then local screen=target:ToScreen();local dist=math.floor(LocalPlayer():GetPos():Distance(target)/52.49);local mx=math.Clamp(screen.x,36,ScrW()-36);local my=math.Clamp(screen.y,70,ScrH()-70);draw.RoundedBox(16,mx-70,my-18,140,36,Color(14,24,38,225));draw.SimpleText("◆ "..tostring(step.title),"GRMQ_Small",mx,my-5,C.yellow,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER);draw.SimpleText(dist.." м","GRMQ_Small",mx,my+10,C.text,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)end end
 end
end)

-- Cutscene nodes use server-sanitized transforms and local packaged media only.
local function stopCutscene()local restore=Q.Cutscene and Q.Cutscene.restoreFrame;if Q.Cutscene and Q.Cutscene.active then net.Start("GRM_Quest_CutsceneStop");net.SendToServer()end;Q.Cutscene={active=false};gui.EnableScreenClicker(false);if IsValid(restore)then restore:SetVisible(true);restore:MakePopup()end end
local function linkedCutsceneNodes(nodes)
 local source=table.Copy(nodes or{});local byID={};for i,node in ipairs(source)do byID[tostring(node.id or"")]=i end
 local ordered,seen,index={}, {},1
 while source[index]and not seen[index]and#ordered<32 do seen[index]=true;local node=source[index];ordered[#ordered+1]=node;local linked=byID[tostring(node.next or"")];index=linked or(index+1)end
 return ordered
end
local function nodeTransform(node)return Vector(node.pos.x,node.pos.y,node.pos.z),Angle(node.ang.p,node.ang.y,node.ang.r),tonumber(node.fov)or 75 end
local function startCutscene(nodes,adminPreview)
 nodes=linkedCutsceneNodes(nodes);if#nodes==0 then notification.AddLegacy("В этой фазе нет точек кат-сцены",NOTIFY_HINT,3)return end
 if adminPreview then net.Start("GRM_Quest_CutscenePreview");net.WriteTable(nodes);net.SendToServer()end
 local firstPos,firstAng,firstFov=nodeTransform(nodes[1])
 -- Первая точка — явная стартовая камера. Никакого полёта от тела игрока.
 Q.Cutscene={active=true,nodes=nodes,index=1,phase="hold",phaseStart=CurTime(),currentPos=firstPos,currentAng=firstAng,currentFov=firstFov,fromPos=firstPos,fromAng=firstAng,fromFov=firstFov,soundNode=0}
end
net.Receive("GRM_Quest_Cutscene",function()startCutscene(net.ReadTable()or{},false)end)
hook.Add("CalcView","GRM_Quest_CutsceneView",function(ply,pos,angles,fov)
 local s=Q.Cutscene;if not s.active then return end;local node=s.nodes[s.index];if not node then stopCutscene()return end
 local targetPos,targetAng,targetFov=nodeTransform(node);local origin,viewAng,viewFov=targetPos,targetAng,targetFov
 if s.phase=="move"then
  local moveDuration=math.max(.05,tonumber(node.moveDuration)or 1);local t=math.Clamp((CurTime()-s.phaseStart)/moveDuration,0,1);local eased=math.ease.InOutSine(t);origin=LerpVector(eased,s.fromPos,targetPos);viewAng=LerpAngle(eased,s.fromAng,targetAng);viewFov=Lerp(eased,s.fromFov or targetFov,targetFov)
  if t>=1 then s.phase="hold";s.phaseStart=CurTime();s.currentPos=targetPos;s.currentAng=targetAng;s.currentFov=targetFov end
 else
  if s.soundNode~=s.index then s.soundNode=s.index;if node.sound and node.sound~=""then surface.PlaySound(node.sound)end end
  if CurTime()-s.phaseStart>=math.max(.05,tonumber(node.duration)or 3)then
   local oldPos,oldAng,oldFov=targetPos,targetAng,targetFov;s.index=s.index+1;local nextNode=s.nodes[s.index]
   if not nextNode then stopCutscene()return end
   s.fromPos=oldPos;s.fromAng=oldAng;s.fromFov=oldFov;s.phaseStart=CurTime();s.phase=nextNode.transition=="move"and"move"or"hold";s.soundNode=0
   if s.phase=="move"then origin,viewAng,viewFov=oldPos,oldAng,oldFov else origin,viewAng,viewFov=nodeTransform(nextNode)end
  end
 end
 return{origin=origin,angles=viewAng,fov=viewFov,znear=2,zfar=32768,drawviewer=false,drawmonitors=true}
end)
hook.Add("HUDPaint","GRM_Quest_CutsceneHUD",function()local s=Q.Cutscene;if not s.active then return end;local n=s.nodes[s.index]or {};draw.RoundedBox(0,0,0,ScrW(),62,Color(0,0,0,235));draw.RoundedBox(0,0,ScrH()-82,ScrW(),82,Color(0,0,0,235));if n.image and n.image~=""then local m=Q._cutsceneMats;if not m then m={}Q._cutsceneMats=m end;local mat=m[n.image];if not mat then mat=Material(n.image,"smooth")m[n.image]=mat end;surface.SetMaterial(mat);surface.SetDrawColor(255,255,255,220);surface.DrawTexturedRect(ScrW()/2-80,70,160,90)end;draw.SimpleText(n.caption or "","GRMQ_Head",ScrW()/2,ScrH()-42,C.text,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER);draw.SimpleText("ПРОБЕЛ — пропустить","GRMQ_Small",ScrW()-18,ScrH()-18,C.dim,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)end)
hook.Add("PlayerButtonDown","GRM_Quest_CutsceneSkip",function(ply,key)if ply==LocalPlayer()and Q.Cutscene.active and key==KEY_SPACE then stopCutscene()end end)
hook.Add("CreateMove","GRM_Quest_CutsceneLock",function(cmd)if Q.Cutscene.active then cmd:ClearMovement();cmd:ClearButtons()end end)
hook.Add("PlayerDeath","GRM_Quest_CutsceneDeath",function(ply)if ply==LocalPlayer()then stopCutscene()end end)

-- Quest Studio v1.1: visual constructors, no raw JSON required.
local function darkList(parent,x,y,w,h,columns)
 local l=vgui.Create("DListView",parent);l:SetPos(x,y);l:SetSize(w,h);l:SetMultiSelect(false);l.Paint=function(_,pw,ph)draw.RoundedBox(7,0,0,pw,ph,Color(12,19,30))end
 for _,c in ipairs(columns)do local header=l:AddColumn(c[1]);header:SetFixedWidth(c[2]or 100)end;return l
end
local function addDarkLine(list,...)
 local line=list:AddLine(...);for _,column in ipairs(line.Columns or{})do if column.SetTextColor then column:SetTextColor(C.text)end end
 line.Paint=function(self,w,h)local selected=self:IsSelected();draw.RoundedBox(4,1,1,w-2,h-2,selected and C.blue or(self:IsHovered()and C.hover or Color(20,30,45)));for _,column in ipairs(self.Columns or{})do if column.SetTextColor then column:SetTextColor(selected and color_white or C.text)end end end
 return line
end
local function textEntry(parent,title,x,y,w,h,multi)
 label(parent,title,x,y,w,18,"GRMQ_Small",C.dim);local e=vgui.Create("DTextEntry",parent);e:SetPos(x,y+19);e:SetSize(w,h or 28);e:SetMultiline(multi==true);return e
end
local function numberEntry(parent,title,x,y,w,min,max)
 label(parent,title,x,y,w,18,"GRMQ_Small",C.dim);local e=vgui.Create("DNumberWang",parent);e:SetPos(x,y+19);e:SetSize(w,28);e:SetMin(min or 0);e:SetMax(max or 100000);return e
end
local function comboEntry(parent,title,x,y,w,choices)
 label(parent,title,x,y,w,18,"GRMQ_Small",C.dim);local e=vgui.Create("DComboBox",parent);e:SetPos(x,y+19);e:SetSize(w,28);for _,v in ipairs(choices)do e:AddChoice(v[1],v[2])end;e.ValueID=choices[1]and choices[1][2];e.OnSelect=function(_,_,_,data)e.ValueID=data end;return e
end
local function splitCSV(value)local out={};for part in tostring(value or""):gmatch("[^,]+")do part=string.Trim(part);if part~=""then out[#out+1]=part end end;return out end
local function adminStudio(data)
 if IsValid(Q.AdminFrame)then Q.AdminFrame:Remove()end
 local f=frame("GRM QUEST STUDIO · ВИЗУАЛЬНЫЙ КОНСТРУКТОР",1220,780);Q.AdminFrame=f
 local definitions=data.definitions or{};Q.AdminDefinitions=definitions;local work=nil
 local rebuildStages,rebuildRewards,rebuildNodes,rebuildCams,saveWork
 local statusText,statusColor="Выберите квест или создайте новый",C.dim
 local function setStatus(text,color)statusText=tostring(text or"");statusColor=color or C.dim end
 local questList=darkList(f,16,62,300,640,{{"ID",88},{"Квест",155},{"Этапов",52}})
 local tabs=vgui.Create("DPropertySheet",f);tabs:SetPos(328,58);tabs:SetSize(874,646)
 local function panelTab(name,icon)local p=vgui.Create("DPanel",tabs);p.Paint=function(_,w,h)draw.RoundedBox(9,0,0,w,h,C.panel)end;tabs:AddSheet(name,p,icon);return p end
 local general=panelTab("Основное","icon16/book.png")
 local stages=panelTab("Этапы","icon16/flag_blue.png")
 local rewards=panelTab("Награды/ачивка","icon16/money.png")
 local notifications=panelTab("Уведомления","icon16/comment.png")
 local dialogues=panelTab("Диалоги","icon16/comments.png")
 local cinema=panelTab("Кат-сцены","icon16/film.png")

 local g={}
 g.id=textEntry(general,"Уникальный ID",18,18,360);g.title=textEntry(general,"Название квеста",18,76,520);g.category=textEntry(general,"Категория",18,134,250);g.npc=textEntry(general,"ID квестового NPC",286,134,252);g.summary=textEntry(general,"Описание для игрока",18,192,814,80,true);g.prereq=textEntry(general,"Предыдущие квесты через запятую",18,302,520)
 g.flags={};for i,v in ipairs({{"enabled","Квест включён"},{"repeatable","Можно повторять"},{"autoStart","Автостарт новичку"}})do local c=vgui.Create("DCheckBoxLabel",general);c:SetPos(18+(i-1)*220,368);c:SetText(v[2]);c:SetTextColor(C.text);c:SizeToContents();g.flags[v[1]]=c end
 label(general,"БЫСТРЫЙ СТАРТ",18,414,400,22,"GRMQ_Head",C.yellow)
 button(general,"ЛОР + проводник + завод",18,446,250,42,C.blue,function()if not work then return end;work.steps={{type="talk",npc=work.npc~=""and work.npc or"guide",title="Поговорить с проводником",count=1},{type="visit",title="Дойти до завода",pos={x=0,y=0,z=0},radius=180,count=1}};if rebuildStages then rebuildStages()end;if tabs.SwitchToName then tabs:SwitchToName("Этапы")end;setStatus("Шаблон этапов создан — настройте зону завода",C.green);notification.AddLegacy("Шаблон добавлен. Откройте «Этапы» и задайте зону тулом.",NOTIFY_HINT,5)end)
 button(general,"10 руды → 10 видеокарт",280,446,260,42,C.green,function()if not work then return end;work.steps={{type="event",event="mining",target="",count=10,title="Добыть руду 10 раз"},{type="event",event="factory_produce",target="gpu_basic",count=10,title="Произвести 10 видеокарт"}};if rebuildStages then rebuildStages()end;if tabs.SwitchToName then tabs:SwitchToName("Этапы")end;setStatus("Производственная цепочка создана",C.green);notification.AddLegacy("Производственная цепочка добавлена",NOTIFY_GENERIC,4)end)
 button(general,"Подготовить тул для NPC",552,446,250,42,Color(58,82,112),function()if not work then setStatus("Сначала выберите квест",C.red)return end;RunConsoleCommand("grm_quest_tool_mode","npc");RunConsoleCommand("grm_quest_tool_npc_id",g.npc:GetText());RunConsoleCommand("grm_quest_tool_npc_name",g.title:GetText());RunConsoleCommand("gmod_tool","grm_quest_tool");f:Close();notification.AddLegacy("Тул готов: наведитесь на землю и нажмите ЛКМ",NOTIFY_HINT,7)end)
 label(general,"СБРОС ПРОГРЕССА / ПОВТОРНЫЙ ЗАПУСК",18,505,500,22,"GRMQ_Head",C.yellow)
 local resetChoices={{"Мой персонаж","@self"},{"Все персонажи","*"}};for _,p in ipairs(data.onlinePlayers or{})do resetChoices[#resetChoices+1]={p.name.." · "..p.key,p.key}end;g.resetTarget=comboEntry(general,"Чей прогресс сбросить",18,534,420,resetChoices)
 button(general,"Сбросить засчёт",454,553,180,38,C.red,function()if not work then setStatus("Выберите квест",C.red)return end;local target=g.resetTarget.ValueID or"@self";local function send()net.Start("GRM_Quest_AdminOp");net.WriteString("reset_progress");net.WriteString(work.id or"");net.WriteString(target);net.SendToServer();setStatus("Запрошен сброс прогресса",C.yellow)end;if target=="*"then Derma_Query("Сбросить этот квест у ВСЕХ персонажей?","Подтверждение","Сбросить",send,"Отмена")else send()end end)
 label(general,"После сброса квест снова доступен у NPC. Для самостоятельного повтора игроком включите чекбокс «Можно повторять».",18,594,814,28,"GRMQ_Small",C.dim)

 -- Stage constructor
 local stageList=darkList(stages,12,44,300,500,{{"#",32},{"Тип",74},{"Название",190}});label(stages,"ПОСЛЕДОВАТЕЛЬНОСТЬ ЭТАПОВ",12,14,300,22,"GRMQ_Head",C.yellow)
 local sf={};sf.type=comboEntry(stages,"Тип этапа",328,18,220,{{"Посетить место","visit"},{"Поговорить с NPC","talk"},{"Событие/счётчик","event"},{"Иметь предмет","item"}});sf.title=textEntry(stages,"Название для игрока",566,18,278);sf.desc=textEntry(stages,"Пояснение",328,76,516,54,true);sf.event=textEntry(stages,"Событие",328,158,160);sf.target=textEntry(stages,"Цель события",500,158,172);sf.npc=textEntry(stages,"ID NPC",684,158,160);sf.item=textEntry(stages,"ID предмета",328,216,220);sf.count=numberEntry(stages,"Количество",560,216,120,1,100000);sf.radius=numberEntry(stages,"Радиус точки",692,216,152,24,10000);sf.consume=vgui.Create("DCheckBoxLabel",stages);sf.consume:SetPos(328,278);sf.consume:SetText("Изъять предметы при выполнении");sf.consume:SetTextColor(C.text);sf.consume:SizeToContents()
 local selectedStage=0
 rebuildStages=function()stageList:Clear();for i,s in ipairs(work and work.steps or{})do local line=addDarkLine(stageList,i,s.type,s.title);line._index=i end end
 local function loadStage(i)local s=work and work.steps[i];if not s then return end;selectedStage=i;sf.type:SetValue(({visit="Посетить место",talk="Поговорить с NPC",event="Событие/счётчик",item="Иметь предмет"})[s.type]or s.type);sf.type.ValueID=s.type;sf.title:SetText(s.title or"");sf.desc:SetText(s.description or"");sf.event:SetText(s.event or"");sf.target:SetText(s.target or"");sf.npc:SetText(s.npc or"");sf.item:SetText(s.item or"");sf.count:SetValue(s.count or 1);sf.radius:SetValue(s.radius or 120);sf.consume:SetValue(s.consume and 1 or 0)end
 stageList.OnRowSelected=function(_,_,line)loadStage(line._index)end
 local function applyStage()if not work or selectedStage<1 then return end;local old=work.steps[selectedStage]or{};work.steps[selectedStage]={type=sf.type.ValueID or"event",title=sf.title:GetText(),description=sf.desc:GetText(),event=sf.event:GetText(),target=sf.target:GetText(),npc=sf.npc:GetText(),item=sf.item:GetText(),count=sf.count:GetValue(),radius=sf.radius:GetValue(),consume=sf.consume:GetChecked(),pos=old.pos,min=old.min,max=old.max};rebuildStages();loadStage(selectedStage)end
 button(stages,"+ Новый этап",328,326,160,38,C.blue,function()if not work then return end;work.steps=work.steps or{};work.steps[#work.steps+1]={type="event",title="Новый этап",event="generic",target="",count=1};rebuildStages();loadStage(#work.steps)end)
 button(stages,"Применить",500,326,130,38,C.green,applyStage)
 button(stages,"Удалить",642,326,100,38,C.red,function()if work and selectedStage>0 then table.remove(work.steps,selectedStage);selectedStage=0;rebuildStages()end end)
 button(stages,"↑",754,326,42,38,C.card,function()if work and selectedStage>1 then work.steps[selectedStage],work.steps[selectedStage-1]=work.steps[selectedStage-1],work.steps[selectedStage];selectedStage=selectedStage-1;rebuildStages();loadStage(selectedStage)end end)
 button(stages,"↓",802,326,42,38,C.card,function()if work and selectedStage<#work.steps then work.steps[selectedStage],work.steps[selectedStage+1]=work.steps[selectedStage+1],work.steps[selectedStage];selectedStage=selectedStage+1;rebuildStages();loadStage(selectedStage)end end)
 button(stages,"Настроить зону этим тулом",328,382,250,42,C.yellow,function()if not work or selectedStage<1 then setStatus("Выберите этап visit",C.red)return end;applyStage();if not saveWork(true)then return end;RunConsoleCommand("grm_quest_tool_mode","zone");RunConsoleCommand("grm_quest_tool_quest_id",work.id);RunConsoleCommand("grm_quest_tool_step",selectedStage);RunConsoleCommand("gmod_tool","grm_quest_tool");notification.AddLegacy("Тул готов: ЛКМ — первый угол, ПКМ — второй",NOTIFY_HINT,7)end)
 label(stages,"event: mining / factory_produce / inventory_gain / любое событие API. Пустая цель принимает любой предмет или тип руды.",328,448,516,72,"GRMQ_Body",C.dim)

 -- Rewards and custom achievement
 local rw={};rw.money=numberEntry(rewards,"Денежная награда за квест",18,18,220,0,100000000);rw.itemID=textEntry(rewards,"ID предмета",18,76,280);rw.itemCount=numberEntry(rewards,"Количество",312,76,130,1,10000);rw.list=darkList(rewards,18,140,560,180,{{"Item ID",360},{"Количество",150}});local rewardItems={}
 rebuildRewards=function()rw.list:Clear();for id,count in pairs(rewardItems)do local line=addDarkLine(rw.list,id,count);line._id=id end end
 button(rewards,"Добавить / изменить",458,95,190,36,C.green,function()local id=string.Trim(rw.itemID:GetText());if id~=""then rewardItems[id]=math.max(1,rw.itemCount:GetValue());rebuildRewards()end end);button(rewards,"Удалить выбранное",660,95,170,36,C.red,function()local i=rw.list:GetSelectedLine();local l=i and rw.list:GetLine(i);if IsValid(l)then rewardItems[l._id]=nil;rebuildRewards()end end)
 label(rewards,"КАСТОМНАЯ АЧИВКА ЗА ЗАВЕРШЕНИЕ",18,338,500,24,"GRMQ_Head",C.yellow);rw.achEnabled=vgui.Create("DCheckBoxLabel",rewards);rw.achEnabled:SetPos(18,370);rw.achEnabled:SetText("Выдать ачивку");rw.achEnabled:SetTextColor(C.text);rw.achEnabled:SizeToContents();rw.achHidden=vgui.Create("DCheckBoxLabel",rewards);rw.achHidden:SetPos(180,370);rw.achHidden:SetText("Скрытая до получения");rw.achHidden:SetTextColor(C.text);rw.achHidden:SizeToContents()
 rw.achID=textEntry(rewards,"ID ачивки",18,400,210);rw.achName=textEntry(rewards,"Название",240,400,310);rw.achReward=numberEntry(rewards,"Награда ачивки",562,400,170,0,100000000);rw.achDesc=textEntry(rewards,"Описание достижения",18,458,714,58,true)
 label(rewards,"Ачивка регистрируется в общей GRM-системе и появляется во вкладке достижений F4. Её награда выдаётся отдельно от награды квеста.",18,548,814,42,"GRMQ_Small",C.dim)
 -- Configurable quest notifications
 local nt={};local function notificationEditor(key,title,y)
  local box=vgui.Create("DPanel",notifications);box:SetPos(14,y);box:SetSize(828,166);box.Paint=function(_,w,h)draw.RoundedBox(8,0,0,w,h,Color(15,24,37));surface.SetDrawColor(55,78,105);surface.DrawOutlinedRect(0,0,w,h,1)end;label(box,title,14,10,320,22,"GRMQ_Head",C.yellow);local cfg={};cfg.enabled=vgui.Create("DCheckBoxLabel",box);cfg.enabled:SetPos(630,13);cfg.enabled:SetText("Показывать");cfg.enabled:SetTextColor(C.text);cfg.enabled:SizeToContents();cfg.banner=vgui.Create("DCheckBoxLabel",box);cfg.banner:SetPos(720,13);cfg.banner:SetText("Баннер");cfg.banner:SetTextColor(C.text);cfg.banner:SizeToContents();cfg.text=textEntry(box,"Текст ({title}, {step}, {count})",14,42,500);cfg.sound=textEntry(box,"Звук",526,42,286);cfg.duration=numberEntry(box,"Длительность",14,100,130,1,15);nt[key]=cfg
 end
 notificationEditor("start","ПРИНЯТИЕ КВЕСТА",12);notificationEditor("step","ЗАВЕРШЕНИЕ ЭТАПА",188);notificationEditor("complete","ЗАВЕРШЕНИЕ КВЕСТА",364)
 label(notifications,"Пример звука: buttons/button14.wav. Баннер выводит крупное GRM-уведомление в верхней части экрана.",18,548,810,32,"GRMQ_Small",C.dim)

 -- Dialogue graph constructor
 local dlgPhase=comboEntry(dialogues,"Фаза разговора",12,10,210,{{"До принятия","offer"},{"Во время квеста","active"},{"После завершения","complete"}});local dlgList=darkList(dialogues,12,70,270,475,{{"#",32},{"ID",80},{"Реплика",150}});local dn={};dn.id=textEntry(dialogues,"ID узла",296,10,180);dn.speaker=textEntry(dialogues,"Говорящий",488,10,190);dn.text=textEntry(dialogues,"Текст реплики",296,68,548,92,true);dn.next=textEntry(dialogues,"Следующий ID (пусто = следующий)",296,190,260)
 local choiceList=darkList(dialogues,296,265,548,150,{{"Ответ игрока",300},{"Следующий ID",120},{"Действие",100}});local chText=textEntry(dialogues,"Текст ответа",296,400,200);local chNext=textEntry(dialogues,"Следующий ID",508,400,100);local chAction=comboEntry(dialogues,"Действие",620,400,224,{{"Продолжить",""},{"Принять квест","accept"},{"Закрыть","close"},{"Флаг +","set_flag"},{"Флаг −","clear_flag"},{"Деньги","give_money"},{"Предмет","give_item"},{"Событие","emit"}});local chCond=textEntry(dialogues,"Условие flag:x / !flag:x / item:id / money:N / fac:Имя / done:id",296,458,270);local chArg=textEntry(dialogues,"Аргумент действия",578,458,266)
 local selectedNode,selectedChoice=0,0;local currentChoices={}
 local function phaseNodes()if not work then return{}end;work.dialogue=work.dialogue or{offer={},active={},complete={}};local phase=dlgPhase.ValueID or"offer";work.dialogue[phase]=dialogueNodes(work.dialogue[phase]);return work.dialogue[phase]end
 local function rebuildChoices()choiceList:Clear();for i,ch in ipairs(currentChoices)do local line=addDarkLine(choiceList,ch.text,ch.next,(ch.action or"")..((ch.cond and ch.cond~="")and(" ["..ch.cond.."]")or""));line._index=i end end
 rebuildNodes=function()dlgList:Clear();for i,n in ipairs(phaseNodes())do local line=addDarkLine(dlgList,i,n.id,string.sub(n.text or"",1,42));line._index=i end end
 local function loadNode(i)local n=phaseNodes()[i];if not n then return end;selectedNode=i;dn.id:SetText(n.id or"");dn.speaker:SetText(n.speaker or"");dn.text:SetText(n.text or"");dn.next:SetText(n.next or"");currentChoices=table.Copy(n.choices or{});selectedChoice=0;rebuildChoices()end
 dlgPhase.OnSelect=function(_,_,_,data)dlgPhase.ValueID=data;selectedNode=0;rebuildNodes()end;dlgList.OnRowSelected=function(_,_,line)loadNode(line._index)end;choiceList.OnRowSelected=function(_,_,line)local ch=currentChoices[line._index];if ch then selectedChoice=line._index;chText:SetText(ch.text or"");chNext:SetText(ch.next or"");chCond:SetText(ch.cond or"");chArg:SetText(ch.actionArg or"");chAction.ValueID=ch.action or"";local names={accept="Принять квест",close="Закрыть",set_flag="Флаг +",clear_flag="Флаг −",give_money="Деньги",give_item="Предмет",emit="Событие"};chAction:SetValue(names[ch.action]or"Продолжить")end end
 local function applyNode()local nodes=phaseNodes();if selectedNode<1 then return end;nodes[selectedNode]={id=dn.id:GetText(),speaker=dn.speaker:GetText(),text=dn.text:GetText(),next=dn.next:GetText(),choices=table.Copy(currentChoices)};rebuildNodes();loadNode(selectedNode)end
 button(dialogues,"+ Реплика",296,236,110,32,C.blue,function()local nodes=phaseNodes();nodes[#nodes+1]={id=(dlgPhase.ValueID or"offer").."_"..(#nodes+1),speaker=g.npc:GetText(),text="Новая реплика",next="",choices={}};rebuildNodes();loadNode(#nodes)end);button(dialogues,"Применить",414,236,100,32,C.green,applyNode);button(dialogues,"Удалить",522,236,90,32,C.red,function()local nodes=phaseNodes();if selectedNode>0 then table.remove(nodes,selectedNode);selectedNode=0;rebuildNodes()end end);button(dialogues,"↑",620,236,38,32,C.card,function()local n=phaseNodes();if selectedNode>1 then n[selectedNode],n[selectedNode-1]=n[selectedNode-1],n[selectedNode];selectedNode=selectedNode-1;rebuildNodes();loadNode(selectedNode)end end);button(dialogues,"↓",664,236,38,32,C.card,function()local n=phaseNodes();if selectedNode<#n then n[selectedNode],n[selectedNode+1]=n[selectedNode+1],n[selectedNode];selectedNode=selectedNode+1;rebuildNodes();loadNode(selectedNode)end end);button(dialogues,"▶ Тест диалога",712,236,132,32,C.yellow,function()applyNode();playDialogue(g.npc:GetText(),phaseNodes())end)
 button(dialogues,"Холст графа",12,548,270,36,Color(58,82,112),function()if not work then return end;if Q.OpenGraphStudio then Q.OpenGraphStudio({definitions={work}})end end)
 button(dialogues,"+ Ответ",296,518,100,30,C.blue,function()currentChoices[#currentChoices+1]={text=chText:GetText(),next=chNext:GetText(),action=chAction.ValueID or"",actionArg=chArg:GetText(),cond=chCond:GetText()};rebuildChoices()end);button(dialogues,"Изменить",404,518,100,30,C.green,function()if selectedChoice>0 then currentChoices[selectedChoice]={text=chText:GetText(),next=chNext:GetText(),action=chAction.ValueID or"",actionArg=chArg:GetText(),cond=chCond:GetText()};rebuildChoices()end end);button(dialogues,"Удалить",512,518,90,30,C.red,function()if selectedChoice>0 then table.remove(currentChoices,selectedChoice);selectedChoice=0;rebuildChoices()end end)
 label(dialogues,"Узлы идут сверху вниз. «Следующий ID» создаёт переход. Ответы игрока могут вести в разные узлы, принять квест или закрыть разговор.",296,535,548,58,"GRMQ_Body",C.dim)

 -- Cutscene visual timeline
 local csPhase=comboEntry(cinema,"Фаза показа",12,10,210,{{"При принятии","accept"},{"При завершении","complete"}});local csList=darkList(cinema,12,70,290,480,{{"#",32},{"ID",88},{"Связь",70},{"Титр",95}});local cn={};cn.id=textEntry(cinema,"ID камеры",318,10,160);cn.next=textEntry(cinema,"Следующая камера",490,10,170);cn.transition=comboEntry(cinema,"Переход к этой точке",672,10,172,{{"Мгновенно","cut"},{"Плавный пролёт","move"}});cn.duration=numberEntry(cinema,"Показ точки, сек",318,68,150,.05,30);cn.moveDuration=numberEntry(cinema,"Время пролёта, сек",480,68,160,.05,30);cn.fov=numberEntry(cinema,"FOV",652,68,100,20,120);cn.caption=textEntry(cinema,"Титр / субтитр",318,126,526,60,true);cn.sound=textEntry(cinema,"Путь к звуку",318,214,526);cn.image=textEntry(cinema,"Материал изображения",318,272,526);local selectedCam=0
 local function phaseCams()if not work then return{}end;work.cutscene=work.cutscene or{accept={},complete={}};local phase=csPhase.ValueID or"accept";work.cutscene[phase]=work.cutscene[phase]or{};return work.cutscene[phase]end
 local function relinkCams()local nodes=phaseCams();for i,node in ipairs(nodes)do node.next=nodes[i+1]and tostring(nodes[i+1].id or("camera_"..(i+1)))or"";if i==1 then node.transition="cut"end end end
 local function nextCameraID()local used={};for _,node in ipairs(phaseCams())do used[tostring(node.id or"")]=true end;local i=1;while used["camera_"..i]do i=i+1 end;return"camera_"..i end
 rebuildCams=function()csList:Clear();for i,n in ipairs(phaseCams())do local relation=i==1 and"СТАРТ"or(n.transition=="move"and"ПРОЛЁТ"or"СКЛЕЙКА");local line=addDarkLine(csList,i,n.id or("camera_"..i),relation,string.sub(n.caption or"",1,24));line._index=i end end
 local function loadCam(i)local n=phaseCams()[i];if not n then return end;selectedCam=i;cn.id:SetText(n.id or("camera_"..i));cn.next:SetText(n.next or"");cn.transition.ValueID=n.transition or(i==1 and"cut"or"move");cn.transition:SetValue(cn.transition.ValueID=="move"and"Плавный пролёт"or"Мгновенно");cn.duration:SetValue(n.duration or 3);cn.moveDuration:SetValue(n.moveDuration or 1);cn.fov:SetValue(n.fov or 75);cn.caption:SetText(n.caption or"");cn.sound:SetText(n.sound or"");cn.image:SetText(n.image or"")end
 csPhase.OnSelect=function(_,_,_,data)csPhase.ValueID=data;selectedCam=0;rebuildCams()end;csList.OnRowSelected=function(_,_,line)loadCam(line._index)end
 local function applyCam()local n=phaseCams()[selectedCam];if not n then return end;n.id=cn.id:GetText();n.next=cn.next:GetText();n.transition=selectedCam==1 and"cut"or(cn.transition.ValueID or"cut");n.duration=cn.duration:GetValue();n.moveDuration=cn.moveDuration:GetValue();n.fov=cn.fov:GetValue();n.caption=cn.caption:GetText();n.sound=cn.sound:GetText();n.image=cn.image:GetText();rebuildCams();loadCam(selectedCam)end
 button(cinema,"+ Точка из текущего взгляда",318,330,224,38,C.blue,function()local nodes=phaseCams();local index=#nodes+1;local n={id=nextCameraID(),next="",transition=index==1 and"cut"or"move",moveDuration=1,pos={x=EyePos().x,y=EyePos().y,z=EyePos().z},ang={p=EyeAngles().p,y=EyeAngles().y,r=EyeAngles().r},duration=3,fov=75,caption="",sound="",image=""};if nodes[index-1]and tostring(nodes[index-1].next or"")==""then nodes[index-1].next=n.id end;nodes[index]=n;rebuildCams();loadCam(index)end);button(cinema,"Применить",554,330,108,38,C.green,applyCam);button(cinema,"Удалить",674,330,82,38,C.red,function()local n=phaseCams();if selectedCam>0 then local removed=n[selectedCam];table.remove(n,selectedCam);relinkCams();selectedCam=0;rebuildCams()end end);button(cinema,"↑",768,330,36,38,C.card,function()local n=phaseCams();if selectedCam>1 then n[selectedCam],n[selectedCam-1]=n[selectedCam-1],n[selectedCam];relinkCams();selectedCam=selectedCam-1;rebuildCams();loadCam(selectedCam)end end);button(cinema,"↓",808,330,36,38,C.card,function()local n=phaseCams();if selectedCam<#n then n[selectedCam],n[selectedCam+1]=n[selectedCam+1],n[selectedCam];relinkCams();selectedCam=selectedCam+1;rebuildCams();loadCam(selectedCam)end end)
 button(cinema,"Сделать стартовой",318,382,170,40,C.yellow,function()local n=phaseCams();if selectedCam>1 then local node=table.remove(n,selectedCam);table.insert(n,1,node);relinkCams();selectedCam=1;rebuildCams();loadCam(1)end end);button(cinema,"▶ Эта точка",500,382,140,40,C.yellow,function()applyCam();local n=phaseCams()[selectedCam];if n then f:SetVisible(false);startCutscene({n},true);Q.Cutscene.restoreFrame=f end end);button(cinema,"▶ Вся связка",652,382,140,40,C.green,function()applyCam();local nodes=phaseCams();if#nodes==0 then notification.AddLegacy("Нет точек для проверки",NOTIFY_HINT,3)return end;f:SetVisible(false);startCutscene(nodes,true);Q.Cutscene.restoreFrame=f end)
 button(cinema,"Добавлять точки тулом",318,434,210,40,Color(58,82,112),function()if not work then setStatus("Выберите квест",C.red)return end;if not saveWork(true)then return end;RunConsoleCommand("grm_quest_tool_mode","cutscene");RunConsoleCommand("grm_quest_tool_quest_id",work.id);RunConsoleCommand("grm_quest_tool_phase",csPhase.ValueID or"accept");RunConsoleCommand("gmod_tool","grm_quest_tool");notification.AddLegacy("Первая точка станет стартом. Следующие автоматически связываются.",NOTIFY_HINT,7)end)
 label(cinema,"Камера №1 — старт: сцена мгновенно начинается в ней. Для остальных выберите склейку или плавный пролёт. «Следующая камера» связывает точки по ID; пустое поле использует следующую строку.",318,492,526,88,"GRMQ_Body",C.dim)

 local function syncGeneral()if not work then return end;work.id=g.id:GetText();work.title=g.title:GetText();work.category=g.category:GetText();work.npc=g.npc:GetText();work.summary=g.summary:GetText();work.prerequisites=splitCSV(g.prereq:GetText());for k,c in pairs(g.flags)do work[k]=c:GetChecked()end;work.rewards=work.rewards or{};work.rewards.money=rw.money:GetValue();work.rewards.items=table.Copy(rewardItems);work.achievement={enabled=rw.achEnabled:GetChecked(),hidden=rw.achHidden:GetChecked(),id=rw.achID:GetText(),name=rw.achName:GetText(),description=rw.achDesc:GetText(),reward=rw.achReward:GetValue()};work.notifications={};for key,cfg in pairs(nt)do work.notifications[key]={enabled=cfg.enabled:GetChecked(),banner=cfg.banner:GetChecked(),text=cfg.text:GetText(),sound=cfg.sound:GetText(),duration=cfg.duration:GetValue()}end;if selectedStage>0 then applyStage()end;if selectedNode>0 then applyNode()end;if selectedCam>0 then applyCam()end end
 saveWork=function(closeAfter)
  if not work then setStatus("Сначала выберите или создайте квест",C.red)return false end;syncGeneral();if string.Trim(work.id or"")==""then setStatus("Укажите уникальный ID квеста",C.red)return false end;if string.Trim(work.title or"")==""then setStatus("Укажите название квеста",C.red)return false end;work.draft=#(work.steps or{})==0
  setStatus(work.draft and"Сохранение черновика без этапов..."or"Сохранение на сервере...",work.draft and C.yellow or C.green);net.Start("GRM_Quest_AdminOp");net.WriteString("save");net.WriteTable(work);net.SendToServer();if closeAfter then timer.Simple(.08,function()if IsValid(f)then f:Close()end end)end;return true
 end
 local function loadDef(def)work=table.Copy(def);work.steps=work.steps or{};work.rewards=work.rewards or{money=0,items={}};work.dialogue=work.dialogue or{offer={},active={},complete={}};work.cutscene=work.cutscene or{accept={},complete={}};g.id:SetText(work.id or"");g.title:SetText(work.title or"");g.category:SetText(work.category or"");g.npc:SetText(work.npc or"");g.summary:SetText(work.summary or"");g.prereq:SetText(table.concat(work.prerequisites or{},", "));for k,c in pairs(g.flags)do c:SetValue(work[k]and 1 or 0)end;rw.money:SetValue(work.rewards.money or 0);rewardItems=table.Copy(work.rewards.items or{});work.achievement=work.achievement or{};rw.achEnabled:SetValue(work.achievement.enabled and 1 or 0);rw.achHidden:SetValue(work.achievement.hidden and 1 or 0);rw.achID:SetText(work.achievement.id or("quest_"..tostring(work.id)));rw.achName:SetText(work.achievement.name or work.title or"");rw.achDesc:SetText(work.achievement.description or work.summary or"");rw.achReward:SetValue(work.achievement.reward or 0);work.notifications=work.notifications or{};for key,cfg in pairs(nt)do local value=work.notifications[key]or{};cfg.enabled:SetValue(value.enabled~=false and 1 or 0);cfg.banner:SetValue(value.banner==true and 1 or 0);cfg.text:SetText(value.text or(({start="Получен квест: {title}",step="Этап выполнен: {step}",complete="Квест завершён: {title}"})[key]));cfg.sound:SetText(value.sound or"");cfg.duration:SetValue(value.duration or 4)end;selectedStage=0;selectedNode=0;selectedCam=0;rebuildStages();rebuildRewards();rebuildNodes();rebuildCams();setStatus((work.draft and"Черновик: "or"Редактируется: ")..tostring(work.id).." · этапов: "..#work.steps,work.draft and C.yellow or C.green)end
 local function rebuildQuestList()questList:Clear();for _,d in ipairs(definitions)do local line=addDarkLine(questList,d.id,(d.draft and"[ЧЕРНОВИК] "or"")..d.title,#(d.steps or{}));line._def=d end end
 questList.OnRowSelected=function(_,_,line)loadDef(line._def)end;rebuildQuestList()
 button(f,"Новый квест",16,714,130,42,C.blue,function()local draft={draft=true,id="quest_"..os.time(),title="Новый квест",category="История",npc="guide",summary="",enabled=true,repeatable=false,autoStart=false,steps={},rewards={money=0,items={}},prerequisites={},dialogue={offer={},active={},complete={}},cutscene={accept={},complete={}}};loadDef(draft);local line=addDarkLine(questList,draft.id,"[НОВЫЙ] "..draft.title,0);line._def=draft;questList:SelectItem(line);setStatus("Черновик появился в списке. Заполните этапы и нажмите «Сохранить».",C.yellow)end)
 button(f,"Сохранить",154,714,110,42,C.green,function()saveWork(false)end)
 button(f,"Удалить",272,714,90,42,C.red,function()if not work then setStatus("Выберите квест",C.red)return end;Derma_Query("Удалить квест «"..tostring(work.title).."»?","GRM Quest Studio","Удалить",function()net.Start("GRM_Quest_AdminOp");net.WriteString("delete");net.WriteString(work.id or"");net.SendToServer();setStatus("Удаление...",C.yellow)end,"Отмена")end)
 local status=label(f,"",378,714,800,42,"GRMQ_Body",C.dim);status.Think=function(self)self:SetText(statusText);self:SetTextColor(statusColor)end
 if definitions[1]then loadDef(definitions[1])end
end
net.Receive("GRM_Quest_AdminOpen",function()adminStudio(net.ReadTable()or {})end)
concommand.Add("grm_quests_admin",function()net.Start("GRM_Quest_AdminOp")net.WriteString("request")net.SendToServer()end)
print("[GRM Quests] client v1.4.0 loaded")
