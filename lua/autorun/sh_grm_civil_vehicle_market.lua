--[[ GRM Civil Vehicle Market v1.0.0
     Личный рынок транспорта: отдельный от GRM.Fleet контур.
     Оплата наличными/счётом, покупка кладёт машину в личный гараж. ]]
if SERVER then AddCSLuaFile() end
GRM = GRM or {}
GRM.CivilVehicles = GRM.CivilVehicles or {}
local CV = GRM.CivilVehicles
CV.Version = "1.0.0"
CV.Net = { OPEN="GRM_CivilVehicle_Open", SYNC="GRM_CivilVehicle_Sync", ACT="GRM_CivilVehicle_Act" }
CV.Data = CV.Data or { entries = {} }
local FILE = "grm_vehicle_market/civil.json"

local function trim(v,n) return string.sub(string.Trim(tostring(v or "")),1,n or 96) end
local function key(ply) return GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(ply) or (IsValid(ply) and ply:SteamID64()..":char1" or "") end
local function isAdmin(ply) return IsValid(ply) and ply:IsSuperAdmin() end
function CV.List()
 local out={} for id,e in pairs(CV.Data.entries or {}) do if istable(e)then e.id=id out[#out+1]=e end end
 table.sort(out,function(a,b)return tostring(a.name)<tostring(b.name)end)return out
end

if SERVER then
 for _,n in pairs(CV.Net)do util.AddNetworkString(n)end
 local function ensure()if not file.IsDir("grm_vehicle_market","DATA")then file.CreateDir("grm_vehicle_market")end end
 function CV.Save()
  ensure();local rows={}for _,e in ipairs(CV.List())do rows[#rows+1]=e end
  local ok,raw=pcall(util.TableToJSON,{version=1,entries=rows},true);if not ok or not isstring(raw)then return false end
  file.Write(FILE,raw)return (file.Read(FILE,"DATA")or"")~=""
 end
 function CV.Load()
  CV.Data.entries={};local raw=file.Read(FILE,"DATA")or"";local ok,t=pcall(util.JSONToTable,raw,false,true)
  for _,e in ipairs(ok and istable(t)and t.entries or{})do if istable(e)and trim(e.id)~=""then CV.Data.entries[trim(e.id)]=e end end
 end
 local function allowed(ply,e)
  if not istable(e) then return false,"Позиция рынка не найдена" end
  if isAdmin(ply)then return true end
  local fac=ply:GetNWString("GRM_Faction","")
  if istable(e.factions)and #e.factions>0 then for _,f in ipairs(e.factions)do if tostring(f)==fac then return true end end return false,"Эта позиция не предназначена для вашей организации"end
  return true
 end
 local function snapshot(ply)
  local list={};for _,e in ipairs(CV.List())do local ok,why=allowed(ply,e);list[#list+1]={id=e.id,class=e.class,name=e.name,model=e.model,price=e.price,category=e.category,allowed=ok,reason=why or""}end
  local garages=(GRM.Garage and GRM.Garage.ChoicesFor)and GRM.Garage.ChoicesFor(ply,nil)or{}
  return {entries=list,garages=garages,admin=isAdmin(ply)}
 end
 function CV.Push(ply)
  local d=snapshot(ply);net.Start(CV.Net.SYNC)net.WriteTable(d)net.Send(ply)
 end
 function CV.Open(ply)net.Start(CV.Net.OPEN)net.Send(ply)CV.Push(ply)end
 local function pay(ply,amount,method)
  if method=="bank"then
   if not(GRM.Economy and GRM.Economy.BankBalance and GRM.Economy.BankTake)then return false,"Банк недоступен"end
   if GRM.Economy.BankBalance(ply)<amount then return false,"На счёте недостаточно средств"end
   return GRM.Economy.BankTake(ply,amount,"Покупка гражданского транспорта")~=false
  end
  if not(GRM.HasMoney and GRM.TakeMoney)or not GRM.HasMoney(ply,amount)then return false,"Недостаточно наличных"end
  GRM.TakeMoney(ply,amount,"Покупка гражданского транспорта")return true
 end
 net.Receive(CV.Net.ACT,function(_,ply)
  if not IsValid(ply)then return end
  local op=net.ReadString();local d=net.ReadTable()or{}
  if op=="refresh"then CV.Push(ply)return end
  if op=="buy"then
   local e=CV.Data.entries[tostring(d.id or"")];local ok,why=allowed(ply,e)
   if not e or not ok then return end
   local garage=GRM.Garage and GRM.Garage.ValidateChoice and GRM.Garage.ValidateChoice(ply,d.garageID)
   if not garage then return end
   local price=math.max(0,math.floor(tonumber(e.price)or 0));local paid,msg=pay(ply,price,tostring(d.payment))
   if not paid then if GRM.Notify then GRM.Notify(ply,msg or"Оплата не прошла",255,100,100)end return end
   local VD=GRM.VehicleDealer;local rec,err=VD and VD.CreatePersonalRecord and VD.CreatePersonalRecord(ply,{class=e.class,name=e.name,model=e.model,price=price,marketID=e.id},garage.id)
   if not rec then
    if tostring(d.payment)=="bank"and GRM.Economy and GRM.Economy.BankGive then GRM.Economy.BankGive(ply,price,"Откат покупки транспорта")elseif GRM.GiveMoney then GRM.GiveMoney(ply,price,"Откат покупки транспорта")end
    if GRM.Notify then GRM.Notify(ply,err or"Не удалось оформить транспорт",255,100,100)end return
   end
   if GRM.Notify then GRM.Notify(ply,"Транспорт оформлен и поставлен в личный гараж",90,220,140)end
   CV.Push(ply)return
  end
  if op=="add"and isAdmin(ply)then
   local class=trim(d.class);if class==""then return end
   local info=GRM.VehicleDealer and GRM.VehicleDealer.VehicleInfo and GRM.VehicleDealer.VehicleInfo(class)or{}
   local id="cv_"..os.time().."_"..math.random(100,999);CV.Data.entries[id]={id=id,class=class,name=trim(d.name~=""and d.name or info.name),model=tostring(info.model or""),price=math.max(0,math.floor(tonumber(d.price)or 0)),category=trim(d.category,48),factions=istable(d.factions)and d.factions or{}}
   CV.Save()CV.Push(ply)
  end
 end)
 hook.Add("InitPostEntity","GRM_CivilVehicle_Load",function()
  CV.Load()
  if GRM.Vendor and GRM.Vendor.RegisterType then GRM.Vendor.RegisterType("vehicle_market","Гражданский транспортный рынок","models/gman_high.mdl",{}) end
 end)
 hook.Add("PlayerSay","GRM_CivilVehicle_Chat",function(ply,text)if string.lower(string.Trim(text or""))=="/transport_market"then CV.Open(ply)return""end end)
 concommand.Add("grm_civil_market",function(ply)if IsValid(ply)then CV.Open(ply)end end)
 concommand.Add("grm_civil_market_add",function(ply,_,args)
  if IsValid(ply)and not isAdmin(ply)then return end
  local class=trim(args[1]);local price=math.max(0,math.floor(tonumber(args[2])or 0));if class==""then return end
  local info=GRM.VehicleDealer and GRM.VehicleDealer.VehicleInfo and GRM.VehicleDealer.VehicleInfo(class)or{}
  local id="cv_"..os.time().."_"..math.random(100,999);CV.Data.entries[id]={id=id,class=class,name=trim(table.concat(args," ",3)~=""and table.concat(args," ",3)or info.name),model=tostring(info.model or""),price=price,category="Гражданский транспорт",factions={}}
  CV.Save();if IsValid(ply)then CV.Push(ply)end
 end)
end

if CLIENT then
 local state={entries={},garages={}}
 local function act(op,d)net.Start(CV.Net.ACT)net.WriteString(op)net.WriteTable(d or{})net.SendToServer()end
 local function open()
  if IsValid(CV.Frame)then CV.Frame:Remove()end
  local f=vgui.Create("DFrame");CV.Frame=f;f:SetSize(math.Clamp(ScrW()*.78,980,1500),math.Clamp(ScrH()*.78,680,980));f:Center();f:SetTitle("ГРАЖДАНСКИЙ РЫНОК ТРАНСПОРТА");f:MakePopup()
  local scroll=vgui.Create("DScrollPanel",f);scroll:Dock(FILL);scroll:DockMargin(10,34,10,10)
  local garage="";local combo=vgui.Create("DComboBox",f);combo:Dock(TOP);combo:DockMargin(10,34,10,4);combo:SetValue("Гараж для покупки")
  for _,g in ipairs(state.garages)do combo:AddChoice(g.name,g.id,g.suggested)if g.suggested then garage=g.id end end
  combo.OnSelect=function(_,_,_,v)garage=tostring(v or"")end
  for _,e in ipairs(state.entries)do
   local row=vgui.Create("DPanel",scroll);row:Dock(TOP);row:SetTall(126);row:DockMargin(0,0,4,7)
   row.Paint=function(_,w,h)draw.RoundedBox(6,0,0,w,h,Color(16,25,38,245));draw.SimpleText(e.name,"DermaLarge",150,16,color_white);draw.SimpleText(e.class.." · "..tostring(e.category or"Транспорт"),"DermaDefault",150,49,Color(150,170,190));draw.SimpleText(GRM.Format and GRM.Format(e.price)or tostring(e.price),"DermaLarge",w-18,20,Color(245,195,65),TEXT_ALIGN_RIGHT)end
   local m=vgui.Create("DModelPanel",row);m:SetPos(8,8);m:SetSize(130,110);if util.IsValidModel(e.model or"")then m:SetModel(e.model)end
   for i,pay in ipairs({{"НАЛИЧНЫМИ","cash"},{"СО СЧЁТА","bank"}})do local b=vgui.Create("DButton",row);b:SetText(pay[1]);b:SetSize(130,28);b:SetPos(row:GetWide()-140,70+(i-1)*32);b:DockMargin(0,0,0,0);b:SetEnabled(e.allowed);b.DoClick=function()if garage==""then notification.AddLegacy("Выберите гараж",NOTIFY_ERROR,3)return end;act("buy",{id=e.id,garageID=garage,payment=pay[2]})end end
  end
 end
 net.Receive(CV.Net.SYNC,function()state=net.ReadTable()or state;if IsValid(CV.Frame)then open()end end)
 net.Receive(CV.Net.OPEN,open)
end
