--[[ GRM Jobs v5: live garbage topology, route reconciliation and dump unloading. ]]
if SERVER then AddCSLuaFile()end
GRM=GRM or{};GRM.Jobs=GRM.Jobs or{};local JB=GRM.Jobs
JB.V5Version="1.0.0";JB.GarbageBindings=JB.GarbageBindings or{};JB.GarbageTrucks=JB.GarbageTrucks or setmetatable({},{__mode="k"})
local NREQ="GRM_JobsV5_StateReq";local NDATA="GRM_JobsV5_StateData"
local function posOf(rec)return Vector(tonumber(rec.pos and rec.pos.x)or 0,tonumber(rec.pos and rec.pos.y)or 0,tonumber(rec.pos and rec.pos.z)or 0)end
local function rootVehicle(ent)
 if not IsValid(ent)then return ent end;local parent=ent.GetParent and ent:GetParent()or nil;if IsValid(parent)then ent=parent end
 for _,name in ipairs({"BaseVehicle","Vehicle","SimfphysVehicle"})do local base=ent.GetNWEntity and ent:GetNWEntity(name);if IsValid(base)then return base end end;return ent
end
if SERVER then
 util.AddNetworkString(NREQ);util.AddNetworkString(NDATA)
 local function notify(p,msg,ok)if not IsValid(p)then return end;if GRM.Notify then GRM.Notify(p,msg,ok==false and 255 or 100,ok==false and 125 or 220,ok==false and 95 or 145)else p:ChatPrint("[Мусоровоз] "..msg)end end
 local function audit(action,actor,target,details)if GRM.Audit and GRM.Audit.Write then GRM.Audit.Write("jobs",action,actor,target or{},details or{})end end
 local function pointMap()
  local all,garbage,dumps={},{},{};for _,rec in ipairs(JB.WorkPoints or{})do all[rec.id]=rec;if rec.type=="garbage"then garbage[#garbage+1]=rec elseif rec.type=="dump"then dumps[#dumps+1]=rec end end;return all,garbage,dumps
 end
 function JB.MarkGarbageTruck(veh,ply,j)
  veh=rootVehicle(veh);if not IsValid(veh)then return end;JB.GarbageTrucks[veh]=true;veh:SetNWInt("GRM_GarbageCapacity",tonumber(JB.WorkConfig and JB.WorkConfig.garbageCapacity)or 8);veh:SetNWString("GRM_GarbageState","collecting");if IsValid(ply)then veh:SetNWString("GRM_GarbageDriver",ply:GetNWString("GRM_RPName",ply:Nick()))end
 end
 local function binState(bin)local now=CurTime();if(tonumber(bin._grmGarbageSearchingUntil)or 0)>now then return"searching"end;return bin:GetReadyAt()>now and"cooldown"or"ready"end
 local function bindTopology()
  local all,points,dumps=pointMap();local bins=ents.FindByClass("grm_garbage_bin");local claimed,bindings={},{};local radius=tonumber(JB.WorkConfig and JB.WorkConfig.garbageBindRadius)or 500
  for _,bin in ipairs(bins)do if IsValid(bin)then bin:SetNWString("GRM_GarbagePointID","");bin:SetNWString("GRM_GarbagePointName","");bin:SetNWString("GRM_GarbageState","unbound")end end
  for _,rec in ipairs(points)do local rp=posOf(rec);local best,bestD=nil,radius*radius;for _,bin in ipairs(bins)do if IsValid(bin)and not claimed[bin]then local d=rp:DistToSqr(bin:GetPos());if d<bestD then best,bestD=bin,d end end end;if IsValid(best)then claimed[best]=true;bindings[rec.id]=best;rec._grmGarbageBin=best;best:SetNWString("GRM_GarbagePointID",rec.id);best:SetNWString("GRM_GarbagePointName",rec.name);best:SetNWString("GRM_GarbageState",binState(best))else rec._grmGarbageBin=nil end end
  for _,bin in ipairs(bins)do if IsValid(bin)and claimed[bin]then bin:SetNWString("GRM_GarbageState",binState(bin))end end
  JB.GarbageBindings=bindings;JB.GarbageTopology={all=all,points=points,dumps=dumps,bins=bins,updated=CurTime()};return all,points,dumps
 end
 local function nearestUnused(points,want,used)
  local wp=want and Vector(tonumber(want.x)or 0,tonumber(want.y)or 0,tonumber(want.z)or 0)or nil;local best,bestD=nil,math.huge
  for _,rec in ipairs(points)do if JB.GarbageBindings[rec.id]and not used[rec.id]then local d=wp and wp:DistToSqr(posOf(rec))or 0;if d<bestD then best,bestD=rec,d end end end;return best
 end
 local function reconcileActive(all,points,dumps)
  local changed=false
  for _,j in pairs(JB.Active or{})do if istable(j)and j.tplId=="garbage"then
   j.points=istable(j.points)and j.points or{};j.pointNames=istable(j.pointNames)and j.pointNames or{}
   local ids=istable(j.garbagePointIDs)and j.garbagePointIDs or{};local collectCount=math.max(0,#j.points-1)
   if#ids==0 then local inferred={};for i=1,collectCount do local rec=nearestUnused(points,j.points[i],inferred);ids[i]=rec and rec.id or"";if rec then inferred[rec.id]=true end end;j.garbagePointIDs=ids;changed=true end
   local used={};j.routeState="ready"
   for i=1,collectCount do local id=ids[i];local rec=all[id];if not(rec and JB.GarbageBindings[id])then rec=nearestUnused(points,(j.points or{})[i],used);ids[i]=rec and rec.id or"";changed=true end;if rec and JB.GarbageBindings[rec.id]then used[rec.id]=true;j.points[i]={x=rec.pos.x,y=rec.pos.y,z=rec.pos.z};j.pointNames[i]=rec.name else j.routeState="missing_bin"end end
   local dump=all[j.garbageDumpID];if not(dump and dump.type=="dump")then dump=dumps[1];j.garbageDumpID=dump and dump.id or"";changed=true end
   if dump then local n=#j.points;j.points[n]={x=dump.pos.x,y=dump.pos.y,z=dump.pos.z};j.pointNames[n]=dump.name else j.routeState="missing_dump"end
   local parts={j.routeState,tostring(j.garbageDumpID or"")};for i,id in ipairs(ids)do local p=j.points[i]or{};parts[#parts+1]=tostring(id)..":"..math.floor(tonumber(p.x)or 0)..":"..math.floor(tonumber(p.y)or 0)..":"..math.floor(tonumber(p.z)or 0)end;local sig=table.concat(parts,"|");if j._garbageTopologySignature~=sig then j._garbageTopologySignature=sig;j._garbageTopologyChanged=true;changed=true end
  end end
  return changed
 end
 function JB.RefreshGarbageTopology(reason)
  if JB._garbageRefreshing then return JB.GarbageTopology end;JB._garbageRefreshing=true;local all,points,dumps=bindTopology();local changed=reconcileActive(all,points,dumps);JB._garbageRefreshing=false
  if changed then if JB.SaveActive then JB.SaveActive("garbage topology "..tostring(reason or"refresh"))end;for _,ply in ipairs(player.GetAll())do local j=JB.GetActiveJob and JB.GetActiveJob(ply);if j and j._garbageTopologyChanged then j._garbageTopologyChanged=nil;if JB.PushTracker then JB.PushTracker(ply)end;if JB.PushMyState then JB.PushMyState(ply)end end end end
  return JB.GarbageTopology
 end
 local oldRoute=JB.GetRoutePoints
 function JB.GetRoutePoints(kind)
  if kind~="garbage"then return oldRoute and oldRoute(kind)end;JB.RefreshGarbageTopology("route request");local source=oldRoute and oldRoute(kind)or{};local out={};for _,obj in ipairs(source or{})do local rec=obj._grmJobPoint;if rec and JB.GarbageBindings[rec.id]then out[#out+1]=obj end end;return#out>0 and out or nil
 end
 local oldSearch=JB.SearchGarbageBin
 function JB.SearchGarbageBin(ply,bin)
  if not(IsValid(ply)and IsValid(bin))then return end;JB.RefreshGarbageTopology("bin use");local j=JB.GetActiveJob and JB.GetActiveJob(ply);if not(istable(j)and j.tplId=="garbage")then notify(ply,"Сначала возьмите работу мусоровоза.",false)return end
  local idx=tonumber(j.pointIndex)or 1;if idx>=#(j.points or{})then notify(ply,"Сейчас нужно ехать на свалку.",false)return end;local id=istable(j.garbagePointIDs)and j.garbagePointIDs[idx]or"";if id==""or JB.GarbageBindings[id]~=bin then notify(ply,"Эта мусорка не связана с текущей точкой маршрута.",false)return end
  if oldSearch then return oldSearch(ply,bin)end
 end
 function JB.TickGarbageDump(ply,j,seat,goal,rad)
  if j.routeState=="missing_dump"then if(j._garbageConfigHintAt or 0)<CurTime()then j._garbageConfigHintAt=CurTime()+10;notify(ply,"Свалка не настроена. Сообщите администрации.",false)end return end
  local veh=rootVehicle(seat);if not IsValid(veh)then j.garbageUnloadAt=nil return end;JB.MarkGarbageTruck(veh,ply,j);local load=tonumber(veh.GRM_GarbageLoad)or veh:GetNWInt("GRM_GarbageLoad",0);if load<=0 then j.garbageUnloadAt=nil;veh:SetNWString("GRM_GarbageState","empty");return end
  local inside=veh:GetPos():DistToSqr(goal)<rad*rad;local driver=not veh.GetDriver or not IsValid(veh:GetDriver())or veh:GetDriver()==ply;local stopped=not veh.GetVelocity or veh:GetVelocity():Length2D()<80
  if not inside or not driver or not stopped then if j.garbageUnloadAt then notify(ply,"Выгрузка прервана: остановите мусоровоз в зоне свалки.",false)end;j.garbageUnloadAt=nil;veh:SetNWString("GRM_GarbageState","to_dump");return end
  local duration=tonumber(JB.WorkConfig and JB.WorkConfig.garbageUnloadTime)or 4;if not j.garbageUnloadAt then j.garbageUnloadAt=CurTime()+duration;veh:SetNWString("GRM_GarbageState","unloading");veh:SetNWFloat("GRM_GarbageUnloadAt",j.garbageUnloadAt);notify(ply,"Выгрузка началась. Не двигайтесь "..duration.." сек.",true);JB.PushMyState(ply);return end
  if CurTime()<j.garbageUnloadAt then return end;j.garbageDelivered=load;j.garbageUnloadAt=nil;veh.GRM_GarbageLoad=0;veh:SetNWInt("GRM_GarbageLoad",0);veh:SetNWString("GRM_GarbageState","empty");veh:SetNWFloat("GRM_GarbageUnloadAt",0);audit("garbage.unload",ply,{vehicle=veh:EntIndex(),dumpID=j.garbageDumpID},{load=load});notify(ply,"Мусор выгружен: "..load..". Маршрут завершён.",true);JB.Complete(ply)
 end
 function JB.GarbageStateSnapshot()
  JB.RefreshGarbageTopology("state");local t=JB.GarbageTopology or{};local rows={};for _,rec in ipairs(t.points or{})do local bin=JB.GarbageBindings[rec.id];rows[#rows+1]={kind="collection",id=rec.id,name=rec.name,bound=IsValid(bin),bin=IsValid(bin)and bin:EntIndex()or 0,state=IsValid(bin)and bin:GetNWString("GRM_GarbageState","ready")or"missing",readyIn=IsValid(bin)and math.max(0,math.ceil(bin:GetReadyAt()-CurTime()))or 0,distance=IsValid(bin)and math.floor(posOf(rec):Distance(bin:GetPos()))or 0}end;for _,rec in ipairs(t.dumps or{})do rows[#rows+1]={kind="dump",id=rec.id,name=rec.name,bound=true,state="ready"}end
  local trucks={};for veh in pairs(JB.GarbageTrucks)do if IsValid(veh)then trucks[#trucks+1]={ent=veh:EntIndex(),load=tonumber(veh.GRM_GarbageLoad)or veh:GetNWInt("GRM_GarbageLoad",0),capacity=veh:GetNWInt("GRM_GarbageCapacity",tonumber(JB.WorkConfig and JB.WorkConfig.garbageCapacity)or 8),state=veh:GetNWString("GRM_GarbageState","idle"),driver=veh:GetNWString("GRM_GarbageDriver","")}else JB.GarbageTrucks[veh]=nil end end
  return{updated=os.time(),rows=rows,trucks=trucks,summary={points=#(t.points or{}),bound=table.Count(JB.GarbageBindings),bins=#(t.bins or{}),dumps=#(t.dumps or{})}}
 end
 net.Receive(NREQ,function(bits,ply)if not(IsValid(ply)and ply:IsSuperAdmin())then return end;if GRM.Net and not GRM.Net.Guard(ply,"jobs.garbage.state",{rate=.5,burst=3,maxBits=64},{bits=bits})then return end;net.Start(NDATA);net.WriteTable(JB.GarbageStateSnapshot());net.Send(ply)end)
 timer.Create("GRM_Garbage_Topology",2,0,function()JB.RefreshGarbageTopology("auto")end)
 hook.Add("InitPostEntity","GRM_Garbage_TopologyInit",function()timer.Simple(2,function()JB.RefreshGarbageTopology("map init")end)end)
 hook.Add("PostCleanupMap","GRM_Garbage_TopologyCleanup",function()timer.Simple(1,function()JB.RefreshGarbageTopology("cleanup")end)end)
 hook.Add("OnEntityCreated","GRM_Garbage_TopologyCreate",function(e)timer.Simple(.2,function()if IsValid(e)and e:GetClass()=="grm_garbage_bin"then JB.RefreshGarbageTopology("bin created")end end)end)
 hook.Add("EntityRemoved","GRM_Garbage_TopologyRemove",function(e)if e:GetClass()=="grm_garbage_bin"then timer.Simple(0,function()JB.RefreshGarbageTopology("bin removed")end)end end)
else
 surface.CreateFont("GRMGarbageTitle",{font="Roboto",size=23,weight=900,extended=true});surface.CreateFont("GRMGarbageText",{font="Roboto",size=15,weight=600,extended=true})
 local stateNames={ready="готова",searching="идёт сбор",cooldown="восстановление",unbound="не связана",collecting="сбор",to_dump="к свалке",unloading="выгрузка",empty="пусто",idle="ожидание"}
 local frame,rowsPanel,lastData
 local function request()net.Start(NREQ);net.SendToServer()end
 local function rebuild(data)
  lastData=data;if not IsValid(rowsPanel)then return end;rowsPanel:Clear();local s=data.summary or{};local head=vgui.Create("DPanel",rowsPanel);head:Dock(TOP);head:SetTall(58);head:DockMargin(0,0,0,8);head.Paint=function(_,w,h)draw.RoundedBox(7,0,0,w,h,Color(20,34,48));draw.SimpleText(("ТОЧКИ %d • СВЯЗАНО %d • МУСОРКИ %d • СВАЛКИ %d"):format(s.points or 0,s.bound or 0,s.bins or 0,s.dumps or 0),"GRMGarbageTitle",16,h/2,color_white,TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)end
  for _,r in ipairs(data.rows or{})do local p=vgui.Create("DPanel",rowsPanel);p:Dock(TOP);p:SetTall(62);p:DockMargin(0,0,0,6);p.Paint=function(_,w,h)local good=r.bound and r.state~="missing";draw.RoundedBox(6,0,0,w,h,Color(24,36,51));draw.RoundedBox(2,0,0,5,h,good and Color(65,205,135)or Color(235,85,85));draw.SimpleText((r.kind=="dump"and"СВАЛКА • "or"СБОР • ")..tostring(r.name),"GRMGarbageText",16,19,color_white);local state=r.kind=="dump"and"готова к выгрузке"or(r.bound and((r.state=="cooldown")and("восстановление "..r.readyIn.." сек")or(r.state=="searching"and("идёт сбор • мусорка #"..r.bin)or("мусорка #"..r.bin.." • готова • связь "..r.distance.." юн")))or"НЕТ СВЯЗАННОЙ МУСОРКИ");draw.SimpleText(state,"GRMGarbageText",16,43,good and Color(145,220,175)or Color(245,130,130))end end
  for _,r in ipairs(data.trucks or{})do local p=vgui.Create("DPanel",rowsPanel);p:Dock(TOP);p:SetTall(54);p:DockMargin(0,4,0,4);p.Paint=function(_,w,h)draw.RoundedBox(6,0,0,w,h,Color(37,42,58));draw.SimpleText(("МУСОРОВОЗ #%d • %d/%d • %s • %s"):format(r.ent or 0,r.load or 0,r.capacity or 0,stateNames[r.state]or r.state or"ожидание",r.driver or""),"GRMGarbageText",16,h/2,Color(235,205,115),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)end end
 end
 function JB.OpenGarbageState()
  if IsValid(frame)then frame:MakePopup();request();return end;frame=vgui.Create("DFrame");frame:SetSize(math.min(1000,ScrW()-80),math.min(760,ScrH()-80));frame:Center();frame:MakePopup();frame:SetTitle("МУСОРОВОЗ • ЖИВАЯ СХЕМА И СОСТОЯНИЕ");frame:SetDeleteOnClose(true);if GRM.UI then GRM.UI.Track("jobs.garbage.state",frame)end;rowsPanel=vgui.Create("DScrollPanel",frame);rowsPanel:Dock(FILL);rowsPanel:DockMargin(12,10,12,12);frame.OnRemove=function()frame=nil;rowsPanel=nil end;request()
 end
 concommand.Add("grm_garbage_status",JB.OpenGarbageState);net.Receive(NDATA,function()local data=net.ReadTable()or{};if not IsValid(frame)then JB.OpenGarbageState()end;rebuild(data)end)
 timer.Create("GRM_Garbage_StateRefresh",3,0,function()if IsValid(frame)then request()end end)
 hook.Add("HUDPaint","GRM_Garbage_TruckState",function()local p=LocalPlayer();if not(IsValid(p)and p:InVehicle())then return end;local v=rootVehicle(p:GetVehicle());if not IsValid(v)then return end;local cap=v:GetNWInt("GRM_GarbageCapacity",0);if cap<=0 then return end;local load=v:GetNWInt("GRM_GarbageLoad",0);draw.RoundedBox(7,ScrW()-270,ScrH()-145,250,54,Color(12,20,30,225));draw.SimpleText("МУСОРОВОЗ  "..load.."/"..cap,"GRMGarbageText",ScrW()-250,ScrH()-125,Color(235,210,120));local state=v:GetNWString("GRM_GarbageState","collecting");draw.SimpleText(stateNames[state]or state,"DermaDefault",ScrW()-250,ScrH()-106,Color(170,195,215))end)
end
print("[GRM Jobs v5] garbage topology + dump state loaded")
