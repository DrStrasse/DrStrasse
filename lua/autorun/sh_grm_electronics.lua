--[[ GRM Electronics & Network Ecosystem v2.0.0 — OS 2.0 RT photorobot + universal print ]]
if SERVER then AddCSLuaFile();AddCSLuaFile("autorun/client/cl_grm_electronics.lua")end
GRM=GRM or{};GRM.Electronics=GRM.Electronics or{};local E=GRM.Electronics
E.Version="2.0.0";E.Devices=E.Devices or{};E.Configs=E.Configs or{};E.Links=E.Links or{};E.Accounts=E.Accounts or{};E.Files=E.Files or{};E.Sessions=E.Sessions or{};E.Mailbox=E.Mailbox or{}
-- v1.5.1 (находка 155): автосейв по dirty-флагу — раньше карта и база писались
-- только при ShutDown/явных операциях, и любое падение/килл процесса в окне
-- между изменениями теряло устройства, файлы и почту (класс саги валюты,
-- находки 46-63). Теперь: любая мутация ставит Dirty*, флаш раз в 5с пишет
-- оба файла; ShutDown-сейв сохранён как страховка. Плюс LoadMap чистит
-- мёртвые записи E.Devices перед восстановлением.
E.DirtyMap=false;E.DirtyDB=false
E.Kinds={router="Wi-Fi роутер",computer="Компьютер",printer="Сетевой принтер",socket="Сетевая розетка",plug="Кабельный штекер"}
local function trim(v,n)return string.sub(string.Trim(tostring(v or"")),1,n or 128)end
local function count(t)local n=0;for _ in pairs(t or{})do n=n+1 end;return n end
local function charKey(p)if GRM.Identity and GRM.Identity.CharacterKey then return GRM.Identity.CharacterKey(p)end;return tostring(p:SteamID64())..":char1"end
local function vecT(v)return{x=v.x,y=v.y,z=v.z}end;local function angT(a)return{p=a.p,y=a.y,r=a.r}end
local function vec(t)t=istable(t)and t or{};return Vector(tonumber(t.x)or 0,tonumber(t.y)or 0,tonumber(t.z)or 0)end
local function ang(t)t=istable(t)and t or{};return Angle(tonumber(t.p)or 0,tonumber(t.y)or 0,tonumber(t.r)or 0)end
function E.DeviceByID(id)for _,d in pairs(E.Devices)do if IsValid(d)and d:GetDeviceID()==id then return d end end end
function E.RegisterDevice(ent)if not IsValid(ent)then return end;if ent:GetDeviceID()==""then ent:SetDeviceID("net_"..util.CRC(game.GetMap()..":"..ent:EntIndex()..":"..SysTime()))end;E.Devices[ent:EntIndex()]=ent;E.Configs[ent:GetDeviceID()]=E.Configs[ent:GetDeviceID()]or{range=900,ssid="GRM-NET",passwordHash="",allowFaction=true,allowArrest=false,allowFines=false,allowCCTV=false,allowRoomTap=false,faction="",osType="civilian"};E.DirtyMap=true end
function E.UnregisterDevice(ent)if IsValid(ent)then E.Devices[ent:EntIndex()]=nil;E.DirtyMap=true end end
function E.IsLinked(a,b)for _,l in pairs(E.Links)do if(l.a==a and l.b==b)or(l.a==b and l.b==a)then return true end end return false end
function E.NetworkRouter(ent)
 if not IsValid(ent)or not ent:GetDeviceActive()then return nil end;if ent:GetDeviceKind()=="router"then return ent end
 local id=ent:GetDeviceID();local visited={[id]=true};local queue={id};while#queue>0 do local cur=table.remove(queue,1);for _,l in pairs(E.Links)do local other=l.a==cur and l.b or(l.b==cur and l.a or nil);if other and not visited[other]then visited[other]=true;local d=E.DeviceByID(other);if IsValid(d)and d:GetDeviceActive()then if d:GetDeviceKind()=="router"then return d end;queue[#queue+1]=other end end end end
 local own=E.Configs[id]or{};if own.connectedRouter then local d=E.DeviceByID(own.connectedRouter);local cfg=IsValid(d)and E.Configs[d:GetDeviceID()]or{};if IsValid(d)and d:GetDeviceActive()and ent:GetPos():DistToSqr(d:GetPos())<=(tonumber(cfg.range)or 900)^2 and own.wifiAuthorized==true then return d end end
 for _,d in pairs(E.Devices)do if IsValid(d)and d:GetDeviceKind()=="router"and d:GetDeviceActive()then local cfg=E.Configs[d:GetDeviceID()]or{};if(cfg.passwordHash or"")==""and(ent:GetNetworkID()==""or ent:GetNetworkID()==d:GetNetworkID())and ent:GetPos():DistToSqr(d:GetPos())<=(tonumber(cfg.range)or 900)^2 then return d end end end
end
function E.IsOnline(ent)local r=E.NetworkRouter(ent);return IsValid(r),r end

if SERVER then
 for _,n in ipairs({"GRM_Net_Open","GRM_Net_Action","GRM_Net_Result","GRM_Net_Topology","GRM_Net_AdminOpen","GRM_Net_AdminSave","GRM_Net_AdminData","GRM_Net_AdminAction","GRM_Net_Document","GRM_Net_MailInbox","GRM_Net_MailSend","GRM_Net_PrintJob"})do util.AddNetworkString(n)end
 E.Dir="grm_electronics";E.MapFile=E.Dir.."/"..string.lower(game.GetMap()or"unknown")..".json";E.DBFile=E.Dir.."/database.json"
 local function ensure()if not file.IsDir(E.Dir,"DATA")then file.CreateDir(E.Dir)end end
 local function read(path,label)
  local guard=GRM.PersistenceGuard;local data,source,raw,meta
  if guard and guard.ReadBest then data,source,raw,meta=guard.ReadBest(path,{path..".backup"},label or path)
  else local txt=file.Exists(path,"DATA")and(file.Read(path,"DATA")or"")or"";local ok,t=pcall(util.JSONToTable,txt,false,true);if ok and istable(t)then data,source,raw=t,path,txt end;meta={hadAny=txt~=""}end
  if istable(data)then if guard and guard.Materialize and raw then guard.Materialize(path,path..".backup",raw,label or path)end;return data,source end
  if not(meta and meta.hadAny)then return{},"new"end
  return nil,nil
 end
 local function write(path,data,label)ensure();local guard=GRM.PersistenceGuard;if guard and guard.WriteMirrored then return guard.WriteMirrored(path,path..".backup",data,label or path)end;local ok,raw=pcall(util.TableToJSON,data,true);if not ok or not isstring(raw)then return false end;file.Write(path,raw);file.Write(path..".backup",raw);return file.Read(path,"DATA")==raw end
 local function hash(password,salt)local raw=tostring(password)..":"..tostring(salt);return util.SHA256 and util.SHA256(raw)or util.CRC(raw)end
 local function cleanUser(v)return string.lower(trim(v,32)):gsub("[^%w_%-%.]","")end
 local function session(ply)local s=E.Sessions[ply];if s and s.expires>CurTime()then return s end end
 function E.IsNetworkAdmin(ply)local s=IsValid(ply)and session(ply);return IsValid(ply)and(ply:IsSuperAdmin()or(s and s.role=="root"))end
 local function result(ply,ok,msg,data)net.Start("GRM_Net_Result")net.WriteBool(ok)net.WriteString(trim(msg,300))net.WriteTable(data or{})net.Send(ply)end

 -- File storage is per-device: E.Files[deviceID] = {[fileID] = fileRecord}
 local function filesFor(ply,deviceID)
  local s=session(ply);if not s or not deviceID then return{}end;local store=E.Files[deviceID]or{};local out={}
  for _,f in pairs(store)do if f.owner==s.username or f.shared==true or(f.sharedWith and f.sharedWith[s.username])then out[#out+1]={id=f.id,name=f.name,owner=f.owner,size=#tostring(f.content or""),updated=f.updated,category=f.category or"doc"}end end
  table.sort(out,function(a,b)return a.name<b.name end);return out
 end

 function E.SaveDB()
  if E.DBLoadBlocked then print("[GRM Electronics][!] DB SAVE ОТКЛОНЁН после ошибки primary/backup")return false end
  local accounts={};for _,r in pairs(E.Accounts)do accounts[#accounts+1]=r end
  local allFiles={};for devID,store in pairs(E.Files)do local arr={};for _,r in pairs(store)do arr[#arr+1]=r end;allFiles[devID]=arr end
  local mailbox={};for _,r in pairs(E.Mailbox)do mailbox[#mailbox+1]=r end
  local ok=write(E.DBFile,{version=2,accounts=accounts,files=allFiles,mailbox=mailbox},"electronics DB");if ok then E.DirtyDB=false end;return ok
 end
 function E.EnsureAdminTelecom()
  local username="admintelecom";local salt="GRM_ADMIN_TELECOM_V1";local account=E.Accounts[username]or{};account.username=username;account.displayName="AdminTelecom";account.salt=salt;account.passwordHash=hash("AdminTelecom",salt);account.ownerKey="SYSTEM";account.faction="";account.role="root";account.created=account.created or os.time();E.Accounts[username]=account;return account
 end
 function E.LoadDB()
  local d,source=read(E.DBFile,"electronics DB");if not istable(d)then E.DBLoadBlocked=true;print("[GRM Electronics][!] DB LOAD BLOCKED: primary/backup invalid; memory preserved")return false end
  E.DBLoadBlocked=false;E.Accounts={};for _,r in pairs(d.accounts or{})do if r.username then E.Accounts[r.username]=r end end
  E.Files={};local rawFiles=d.files or{}
  -- v2 format: files is {deviceID: [fileArray]}
  if istable(rawFiles)then for devID,arr in pairs(rawFiles)do if isstring(devID)and istable(arr)then E.Files[devID]={};for _,r in ipairs(arr)do if r.id then E.Files[devID][r.id]=r end end end end end
  E.Mailbox={};for _,r in ipairs(d.mailbox or{})do if r.id then E.Mailbox[r.id]=r end end
  E.EnsureAdminTelecom();if source=="new"then E.SaveDB()end;print("[GRM Electronics] DB LOAD source="..tostring(source).." accounts="..count(E.Accounts));return true
 end
 local function createCable(link)
  if not constraint or not constraint.Rope then return end;local a,b=E.DeviceByID(link.a),E.DeviceByID(link.b);if not IsValid(a)or not IsValid(b)then return end;local length=a:WorldSpaceCenter():Distance(b:WorldSpaceCenter());local rope=constraint.Rope(a,b,0,0,a:WorldToLocal(a:WorldSpaceCenter()),b:WorldToLocal(b:WorldSpaceCenter()),length,0,0,3,"cable/cable2",false);link.rope=rope
 end
 function E.SaveMap()
  if E.MapLoadBlocked then print("[GRM Electronics][!] MAP SAVE ОТКЛОНЁН после ошибки primary/backup")return false end
  local devices={};for _,d in pairs(E.Devices)do if IsValid(d)then devices[#devices+1]={class=d:GetClass(),id=d:GetDeviceID(),name=d:GetDisplayName(),network=d:GetNetworkID(),ownerKey=d:GetOwnerKey(),ownerName=d:GetOwnerName(),active=d:GetDeviceActive(),model=d:GetModel(),pos=vecT(d:GetPos()),ang=angT(d:GetAngles()),config=E.Configs[d:GetDeviceID()]or{}}end end
  local links={};for _,l in pairs(E.Links)do links[#links+1]={id=l.id,a=l.a,b=l.b}end;local ok=write(E.MapFile,{version=1,devices=devices,links=links},"electronics map");if ok then E.DirtyMap=false end;return ok
 end
 function E.LoadMap()
  local d,source=read(E.MapFile,"electronics map");if not istable(d)then E.MapLoadBlocked=true;print("[GRM Electronics][!] MAP LOAD BLOCKED: primary/backup invalid; live devices preserved")return false end
  E.MapLoadBlocked=false
  -- v1.5.1: вычистить мёртвые записи реестра (после cleanup/удаления), чтобы
  -- DeviceByID не находил невалидные объекты и антидубль работал честно.
  for k,dev in pairs(E.Devices)do if not IsValid(dev)then E.Devices[k]=nil end end
  for _,oldLink in pairs(E.Links)do if IsValid(oldLink.rope)then oldLink.rope:Remove()end end
  E.Links={};for _,l in pairs(d.links or{})do if l.a and l.b then E.Links[l.id or util.CRC(l.a..l.b)]={id=l.id or util.CRC(l.a..l.b),a=l.a,b=l.b}end end
  for _,r in pairs(d.devices or{})do if scripted_ents.GetStored(r.class or"")then local existing=E.DeviceByID(r.id);if not IsValid(existing)then existing=ents.Create(r.class);if IsValid(existing)then existing:SetPos(vec(r.pos));existing:SetAngles(ang(r.ang));existing:SetDeviceID(r.id or"");if util.IsValidModel(r.model or"")then existing:SetModel(r.model)end;existing:Spawn();existing:Activate()end end;if IsValid(existing)then existing:SetDisplayName(r.name or E.Kinds[existing:GetDeviceKind()]or"Устройство");existing:SetNetworkID(r.network or"");existing:SetOwnerKey(r.ownerKey or"");existing:SetOwnerName(r.ownerName or"");existing:SetDeviceActive(r.active~=false);E.Configs[existing:GetDeviceID()]=istable(r.config)and r.config or{};E.RegisterDevice(existing)end end end
  for _,link in pairs(E.Links)do createCable(link)end;E.DirtyMap=false;E.PushTopology();print("[GRM Electronics] MAP LOAD source="..tostring(source).." devices="..count(E.Devices));return true
 end
 function E.HandleDeviceRemoved(ent)
  if E.SuppressRemovalPersistence then return end;local id=ent.GetDeviceID and ent:GetDeviceID()or"";if id==""then return end
  if E.UnlinkDevice then E.UnlinkDevice(id)else for key,l in pairs(E.Links)do if l.a==id or l.b==id then E.Links[key]=nil end end end;E.Configs[id]=nil;E.Files[id]=nil;E.DirtyMap=true;E.DirtyDB=true
  timer.Simple(0,function()if not E.SuppressRemovalPersistence then E.SaveMap();E.SaveDB();E.PushTopology()end end)
 end
 function E.SaveAll()
  local mapOK=E.SaveMap();local dbOK=E.SaveDB();local ok=mapOK==true and dbOK==true
  return ok,("электроника: карта=%s, база=%s"):format(tostring(mapOK),tostring(dbOK))
 end
 function E.LoadAll()
  local dbOK=E.LoadDB();if not dbOK then return false,"база электроники повреждена; живые устройства не перезагружены"end
  local mapOK=E.LoadMap();return mapOK==true,("электроника: карта=%s, база=%s"):format(tostring(mapOK),tostring(dbOK))
 end
 function E.PushTopology(target)local rows={};for _,d in pairs(E.Devices)do if IsValid(d)then rows[#rows+1]={ent=d,id=d:GetDeviceID(),kind=d:GetDeviceKind(),name=d:GetDisplayName(),network=d:GetNetworkID(),online=E.IsOnline(d)}end end;local links={};for _,l in pairs(E.Links)do links[#links+1]=l end;net.Start("GRM_Net_Topology")net.WriteTable({devices=rows,links=links})if IsValid(target)then net.Send(target)else net.Broadcast()end end
 local function canConfigure(ply,ent)return IsValid(ply)and IsValid(ent)and E.IsNetworkAdmin(ply)end
 function E.Claim(ent,ply)if ent:GetOwnerKey()==""and IsValid(ply)then ent:SetOwnerKey(charKey(ply));ent:SetOwnerName(ply:Nick())end end
function E.OpenDevice(ply,ent)
 if not IsValid(ply)or not IsValid(ent)or ply:GetPos():DistToSqr(ent:GetPos())>250*250 then return end;E.Claim(ent,ply);local online,router=E.IsOnline(ent);local cfg=IsValid(router)and E.Configs[router:GetDeviceID()]or{}
 local devCfg=E.Configs[ent:GetDeviceID()]or{}
 net.Start("GRM_Net_Open")net.WriteEntity(ent)net.WriteTable({kind=ent:GetDeviceKind(),name=ent:GetDisplayName(),deviceID=ent:GetDeviceID(),online=online,network=IsValid(router)and router:GetNetworkID()or"",owner=ent:GetOwnerName(),logged=session(ply)and(session(ply).displayName or session(ply).username)or"",role=session(ply)and session(ply).role or"",canConfigure=canConfigure(ply,ent),integrations=cfg,osType=devCfg.osType or"civilian"})net.Send(ply)
end
 local function moduleData(ply,module,cfg)
  local root=E.IsNetworkAdmin(ply);local required=trim(cfg.faction,64);if required~=""and not root then local actual=GRM.Arrest and GRM.Arrest.FactionOf and GRM.Arrest.FactionOf(ply)or"";if actual~=required then return nil end end
  if module=="faction"and(cfg.allowFaction or root) then local fac=GRM.Arrest and GRM.Arrest.FactionOf and GRM.Arrest.FactionOf(ply)or"";return{title="Фракционная сеть",rows={{name=ply:Nick(),faction=fac}}}
  elseif module=="arrest"and(cfg.allowArrest or root) then local rows={};for _,p in ipairs(player.GetAll())do if p:GetNWBool("GRM_Arrested",false)then rows[#rows+1]={name=p:Nick(),group=p:GetNWString("GRM_ArrestGroupName","")}end end;return{title="Аресты",rows=rows}
  elseif module=="fines"and(cfg.allowFines or root) then local rows={};for _,p in ipairs(player.GetAll())do rows[#rows+1]={name=p:Nick(),wanted=GRM.Wanted and GRM.Wanted.GetLevel and GRM.Wanted.GetLevel(p)or 0}end;return{title="Розыск и штрафы",rows=rows}
  elseif module=="cctv"and(cfg.allowCCTV or root) then local rows={};for _,d in pairs(GRM.CCTV and GRM.CCTV.Devices or{})do if IsValid(d)then rows[#rows+1]={name=d.GetLabel and d:GetLabel()or d:GetClass(),network=d.GetNetworkID and d:GetNetworkID()or""}end end;return{title="CCTV",rows=rows}
  elseif module=="roomtap"and(cfg.allowRoomTap or root) then return{title="Прослушка",rows={{status=GRM.RoomTap and"Модуль подключён"or"Модуль недоступен"}}}end
  return nil
 end
 net.Receive("GRM_Net_Action",function(_,ply)
  if not IsValid(ply)then return end;ply.GRMNetNext=ply.GRMNetNext or 0;if CurTime()<ply.GRMNetNext then return end;ply.GRMNetNext=CurTime()+.15;local ent=net.ReadEntity();local op=net.ReadString();if not IsValid(ent)or ply:GetPos():DistToSqr(ent:GetPos())>300*300 then return end;local kind=ent:GetDeviceKind();if op~="admin"and op~="connect"and kind~="computer"then return end;if(op=="register"or op=="login")and not E.IsOnline(ent)then result(ply,false,"Компьютер не подключён к сети")return end
  if op=="register"then local user=cleanUser(net.ReadString());local password=net.ReadString();if#user<3 or#password<5 then result(ply,false,"Логин от 3, пароль от 5 символов")return end;if E.Accounts[user]then result(ply,false,"Логин занят")return end;local salt=util.CRC(user..SysTime()..math.random());E.Accounts[user]={username=user,salt=salt,passwordHash=hash(password,salt),ownerKey=charKey(ply),faction="",role="user",created=os.time()};E.SaveDB();result(ply,true,"Аккаунт создан")
  elseif op=="login"then local user=cleanUser(net.ReadString());local password=net.ReadString();local a=E.Accounts[user];if not a or a.passwordHash~=hash(password,a.salt)then result(ply,false,"Неверный логин или пароль")return end;E.Sessions[ply]={username=user,displayName=a.displayName or user,role=a.role or"user",expires=CurTime()+3600,device=ent:GetDeviceID()};result(ply,true,"Вход выполнен",{username=user,role=a.role or"user",files=filesFor(ply,ent:GetDeviceID())});timer.Simple(0,function()if IsValid(ply)and IsValid(ent)then E.OpenDevice(ply,ent)end end)
  elseif op=="logout"then E.Sessions[ply]=nil;result(ply,true,"Выход выполнен")
  elseif op=="admin"then if E.IsNetworkAdmin(ply)then E.OpenAdmin(ply,ent)end
  elseif op=="control_center"then if E.IsNetworkAdmin(ply)then E.OpenControlCenter(ply)end
  elseif op=="connect"then local ssid=trim(net.ReadString(),48);local password=trim(net.ReadString(),64);local found;for _,router in pairs(E.Devices)do if IsValid(router)and router:GetDeviceKind()=="router"and router:GetDeviceActive()and router:GetNetworkID()==ssid then local cfg=E.Configs[router:GetDeviceID()]or{};if ent:GetPos():DistToSqr(router:GetPos())<=(tonumber(cfg.range)or 900)^2 then found=router;break end end end;if not IsValid(found)then result(ply,false,"Сеть не найдена")return end;local cfg=E.Configs[found:GetDeviceID()]or{};if(cfg.passwordHash or"")~=""and cfg.passwordHash~=hash(password,found:GetDeviceID())then result(ply,false,"Неверный пароль Wi-Fi")return end;local own=E.Configs[ent:GetDeviceID()]or{};own.connectedRouter=found:GetDeviceID();own.wifiAuthorized=true;E.Configs[ent:GetDeviceID()]=own;ent:SetNetworkID(ssid);E.SaveMap();result(ply,true,"Подключено к "..ssid);E.OpenDevice(ply,ent)
  else local s=session(ply);if not s then result(ply,false,"Сначала войдите")return end
   -- Check if session is for this specific device
   if s.device~=ent:GetDeviceID()then result(ply,false,"Сессия для другого устройства. Войдите заново.")return end
   local online,router=E.IsOnline(ent);if not online then result(ply,false,"Нет подключения к сети")return end;local cfg=E.Configs[router:GetDeviceID()]or{};local devID=ent:GetDeviceID()
   if op=="files"then result(ply,true,"Файлы",{files=filesFor(ply,devID),deviceID=devID})
   elseif op=="file_open"then local id=trim(net.ReadString(),64);local store=E.Files[devID]or{};local f=store[id];if not f or(f.owner~=s.username and not f.shared and not(f.sharedWith and f.sharedWith[s.username]))then result(ply,false,"Нет доступа")else result(ply,true,"Файл",{file={id=f.id,name=f.name,content=f.content,owner=f.owner,category=f.category or"doc"}})end
   elseif op=="image_save"then
    local name=trim(net.ReadString(),96); local category=trim(net.ReadString(),24); local bytes=math.min(net.ReadUInt(24),4*1024*1024); local image=net.ReadData(bytes) or ""
    if #image==0 then result(ply,false,"Пустое изображение") return end
    if #image>200*1024 then result(ply,false,"Изображение >200Кб, сожмите качество") return end
    -- JPEG header 0xFF 0xD8 or PNG 0x89 0x50
    local header=image:sub(1,2)
    local isJpeg=header==string.char(0xFF,0xD8)
    local isPng=image:sub(1,4)==string.char(0x89,0x50,0x4E,0x47)
    if not isJpeg and not isPng then
     -- allow if category drawing (json) - skip check, but for photo require image
     if category=="photo" or category=="photo_print" or category=="import" then
      result(ply,false,"Неизвестный формат изображения (только JPG/PNG)") return
     end
    end
    file.CreateDir("grm_computer/images"); 
    local ext = isPng and ".png" or ".jpg"
    local imageName="grm_computer/images/"..util.CRC(s.username..devID..SysTime()..math.random())..ext; 
    file.Write(imageName,image)
    -- thumb 128x128 not generated server-side, client will use same file as thumb placeholder
    E.Files[devID]=E.Files[devID] or {}; 
    local id="file_"..util.CRC(s.username..devID..SysTime()..math.random()); 
    local src = (category=="import" and "import" or category=="photo" and "photorobot" or category=="photo_print" and "photorobot_print" or category)
    E.Files[devID][id]={id=id,owner=s.username,created=os.time(),updated=os.time(),sharedWith={},name=name,category=category,content="[ИЗОБРАЖЕНИЕ: "..imageName.."]",imagePath=imageName,imageBytes=#image,source=src}; 
    E.SaveDB(); result(ply,true,"Изображение сохранено ("..math.ceil(#image/1024).."Кб)",{files=filesFor(ply,devID),deviceID=devID,imagePath=imageName})
   elseif op=="file_save"then local id=trim(net.ReadString(),64);local name=trim(net.ReadString(),96);local content=string.sub(net.ReadString()or"",1,65536);local category=trim(net.ReadString(),24);if category==""then category="doc"end;E.Files[devID]=E.Files[devID]or{};local store=E.Files[devID];local f=id~=""and store[id]or nil;if f and f.owner~=s.username then result(ply,false,"Нет прав")return end;if not f then id="file_"..util.CRC(s.username..devID..SysTime()..math.random());f={id=id,owner=s.username,created=os.time(),sharedWith={}};store[id]=f end;f.name=name~=""and name or"Документ";f.content=content;f.category=category;f.updated=os.time();E.SaveDB();result(ply,true,"Файл сохранён",{files=filesFor(ply,devID),deviceID=devID})
   elseif op=="file_share"then local id=trim(net.ReadString(),64);local user=cleanUser(net.ReadString());local store=E.Files[devID]or{};local f=store[id];if not f or f.owner~=s.username or not E.Accounts[user]then result(ply,false,"Не удалось передать файл")else f.sharedWith=f.sharedWith or{};f.sharedWith[user]=true;E.SaveDB();result(ply,true,"Файл передан: "..user)end
   elseif op=="file_delete"then local id=trim(net.ReadString(),64);local store=E.Files[devID]or{};local f=store[id];if f and f.owner==s.username then store[id]=nil;E.SaveDB();result(ply,true,"Файл удалён",{files=filesFor(ply,devID),deviceID=devID})else result(ply,false,"Нет прав")end
   elseif op=="print"then
    local id=trim(net.ReadString(),64);local printerID=trim(net.ReadString(),64);local paperSize=trim(net.ReadString(),16);local orientation=trim(net.ReadString(),16);local copies=math.Clamp(tonumber(net.ReadUInt(4))or 1,1,5);local quality=trim(net.ReadString(),16)
    local store=E.Files[devID]or{};local f=store[id];local printer=E.DeviceByID(printerID)
    if not f or not IsValid(printer)or printer:GetDeviceKind()~="printer"or not E.IsOnline(printer)then result(ply,false,"Принтер недоступен")return end
    if ply:GetPos():DistToSqr(printer:GetPos())>350*350 then result(ply,false,"Принтер слишком далеко")return end
    local imgFile=f.content and f.content:match("%[ИЗОБРАЖЕНИЕ: ([^%]]+)%]")or f.imagePath or nil
    local category=f.category or"doc"
    -- allow all image categories: photo, photo_print, drawing, import, doc with image
    for i=1,copies do
     timer.Simple((i-1)*0.6,function()
      if not IsValid(printer)then return end
      local doc=ents.Create("grm_net_document");if not IsValid(doc)then return end
      doc:SetPos(printer:GetPos()+printer:GetUp()*24+printer:GetForward()*20);doc:SetAngles(printer:GetAngles());doc:SetDocumentTitle(f.name);doc.DocumentContentServer=f.content;doc:SetDocumentContent(string.sub(f.content or"",1,500));doc:SetDocumentOwner(s.username);doc:SetDocumentCategory(category)
      if imgFile and imgFile~="" then doc:SetDocumentImage(imgFile) end
      doc:Spawn();doc:Activate()
      if i==1 then printer:EmitSound("ambient/machines/combine_terminal_idle4.wav",60,120)end
     end)
    end
    result(ply,true,"Печать: "..copies.." коп. на "..printer:GetDisplayName())
   elseif op=="module"then local module=trim(net.ReadString(),24);local data=moduleData(ply,module,cfg);if data then result(ply,true,data.title,{module=data})else result(ply,false,"Модуль запрещён настройками сети")end
   elseif op=="inbox"then
    local msgs={};for _,m in pairs(E.Mailbox)do if m.to==s.username then msgs[#msgs+1]={id=m.id,from=m.from,subject=m.subject,date=m.date,read=m.read}end end;table.sort(msgs,function(a,b)return(a.date or 0)>(b.date or 0)end);result(ply,true,"Входящие",{inbox=msgs})
   elseif op=="mail_open"then local id=trim(net.ReadString(),64);local m=E.Mailbox[id];if m and m.to==s.username then m.read=true;E.SaveDB();result(ply,true,"Письмо",{mail={id=m.id,from=m.from,subject=m.subject,body=m.body,date=m.date}})else result(ply,false,"Письмо не найдено")end
   elseif op=="mail_send"then
    local to=cleanUser(net.ReadString());local subject=trim(net.ReadString(),120);local body=string.sub(net.ReadString()or"",1,8192);if not E.Accounts[to]then result(ply,false,"Получатель не найден")return end
    local id="msg_"..util.CRC(s.username..to..SysTime()..math.random());E.Mailbox[id]={id=id,from=s.username,to=to,subject=subject~=""and subject or"Без темы",body=body,date=os.time(),read=false};E.SaveDB();result(ply,true,"Письмо отправлено")
   elseif op=="mail_delete"then local id=trim(net.ReadString(),64);local m=E.Mailbox[id];if m and m.to==s.username then E.Mailbox[id]=nil;E.SaveDB();result(ply,true,"Письмо удалено")else result(ply,false,"Нет прав")end
   end
  end
 end)
 net.Receive("GRM_Net_AdminSave",function(_,ply)if not IsValid(ply)or not E.IsNetworkAdmin(ply)then return end;local ent=net.ReadEntity();local data=net.ReadTable()or{};if not IsValid(ent)then return end;ent:SetDisplayName(trim(data.name,80));ent:SetNetworkID(trim(data.network,48));ent:SetDeviceActive(data.active~=false);local cfg=E.Configs[ent:GetDeviceID()]or{};cfg.range=math.Clamp(tonumber(data.range)or 900,100,5000);cfg.allowFaction=data.allowFaction==true;cfg.allowArrest=data.allowArrest==true;cfg.allowFines=data.allowFines==true;cfg.allowCCTV=data.allowCCTV==true;cfg.allowRoomTap=data.allowRoomTap==true;cfg.faction=trim(data.faction,64);cfg.osType=data.osType or cfg.osType or"civilian";if data.clearPassword==true then cfg.passwordHash=""elseif trim(data.password,64)~=""then cfg.passwordHash=hash(trim(data.password,64),ent:GetDeviceID())end;E.Configs[ent:GetDeviceID()]=cfg;E.SaveMap();E.PushTopology();result(ply,true,"Настройки сети сохранены")end)
 function E.OpenAdmin(ply,ent)if not IsValid(ply)or not E.IsNetworkAdmin(ply)or not IsValid(ent)then return end;net.Start("GRM_Net_AdminOpen")net.WriteEntity(ent)net.WriteTable(E.Configs[ent:GetDeviceID()]or{})net.Send(ply)end
 function E.AdminPayload()
  local devices={};for _,d in pairs(E.Devices)do if IsValid(d)then local online,router=E.IsOnline(d);devices[#devices+1]={id=d:GetDeviceID(),name=d:GetDisplayName(),kind=d:GetDeviceKind(),network=d:GetNetworkID(),owner=d:GetOwnerName(),active=d:GetDeviceActive(),online=online,router=IsValid(router)and router:GetDisplayName()or"",ent=d}end end;table.sort(devices,function(a,b)return a.name<b.name end)
  local links={};for _,l in pairs(E.Links)do links[#links+1]={id=l.id,a=l.a,b=l.b}end;local fileCount=0;for _,store in pairs(E.Files)do fileCount=fileCount+count(store)end;return{devices=devices,links=links,accounts=count(E.Accounts),files=fileCount}
 end
 function E.OpenControlCenter(ply)if not IsValid(ply)or not E.IsNetworkAdmin(ply)then return end;net.Start("GRM_Net_AdminData")net.WriteTable(E.AdminPayload())net.Send(ply)end
 concommand.Add("grm_network_admin",E.OpenControlCenter)
 hook.Add("PlayerSayTransform","GRM_Net_AdminChat",function(ply,pack)if not istable(pack)then return end;local cmd=string.lower(trim(pack[1],64));if cmd=="/grm_network_admin"or cmd=="!grm_network_admin"then E.OpenControlCenter(ply);pack[1]="";pack.SkipPlayerSay=true end end)
 net.Receive("GRM_Net_AdminAction",function(_,ply)if not IsValid(ply)or not E.IsNetworkAdmin(ply)then return end;local op,id=net.ReadString(),net.ReadString();local ent=E.DeviceByID(id);if op=="refresh"then E.OpenControlCenter(ply)return end;if not IsValid(ent)then result(ply,false,"Устройство не найдено")return end;if op=="configure"then E.OpenAdmin(ply,ent)return elseif op=="toggle"then ent:SetDeviceActive(not ent:GetDeviceActive())elseif op=="unlink"then E.UnlinkDevice(ent)elseif op=="delete"then E.UnlinkDevice(ent);E.Configs[id]=nil;E.Files[id]=nil;ent:Remove()end;E.SaveMap();E.PushTopology();E.OpenControlCenter(ply)end)
 function E.SpawnDevice(kind,model,pos,angles,ply)local classes={router="grm_net_router",computer="grm_net_computer",printer="grm_net_printer",socket="grm_net_socket",plug="grm_net_plug"};local e=ents.Create(classes[kind]or"");if not IsValid(e)then return end;e:SetPos(pos);e:SetAngles(angles);if util.IsValidModel(model or"")then e:SetModel(model)end;e:Spawn();e:Activate();E.Claim(e,ply);E.SaveMap();E.PushTopology();return e end
 function E.RemoveLink(id)local l=E.Links[tostring(id or"")];if not l then return false end;if IsValid(l.rope)then l.rope:Remove()end;E.Links[tostring(id)]=nil;E.SaveMap();E.PushTopology();return true end
 function E.Link(a,b)if not IsValid(a)or not IsValid(b)or a==b or E.IsLinked(a:GetDeviceID(),b:GetDeviceID())then return false end;local id="link_"..util.CRC(a:GetDeviceID()..":"..b:GetDeviceID());E.Links[id]={id=id,a=a:GetDeviceID(),b=b:GetDeviceID()};createCable(E.Links[id]);E.SaveMap();E.PushTopology();return true,id end
 function E.UnlinkDevice(ent)local id=isstring(ent)and ent or(IsValid(ent)and ent:GetDeviceID());if not id or id==""then return 0 end;local n=0;for k,l in pairs(E.Links)do if l.a==id or l.b==id then if IsValid(l.rope)then l.rope:Remove()end;E.Links[k]=nil;n=n+1 end end;E.SaveMap();E.PushTopology();return n end
 -- 3D2D Textscreen integration
 util.AddNetworkString("GRM_CreateTextScreen")
 net.Receive("GRM_CreateTextScreen",function(len,ply)
  if not IsValid(ply)then return end
  local text=net.ReadString()
  local pos=net.ReadVector()
  -- Check if 3D2D Textscreen addon is installed
  if not scripted_ents.GetStored("textscreen")then
   -- Fallback: create a simple prop with text
   local ent=ents.Create("prop_physics")
   if IsValid(ent)then
    ent:SetModel("models/hunter/plates/plate1x1.mdl")
    ent:SetPos(pos)
    ent:Spawn()
    ent:SetNWString("GRM_TextScreen_Text",text)
    ent:SetNWString("GRM_TextScreen_Owner",ply:Nick())
   end
   return
  end
  -- Create 3D2D textscreen entity
  local screen=ents.Create("textscreen")
  if IsValid(screen)then
   screen:SetPos(pos)
   screen:SetAngles(Angle(0,ply:EyeAngles().y,0))
   screen:Spawn()
   -- Set text lines (3D2D textscreen format)
   for i=1,5 do
    screen:SetNetworkedString("Text"..i,"")
    screen:SetNetworkedInt("Color"..i.."R",255)
    screen:SetNetworkedInt("Color"..i.."G",255)
    screen:SetNetworkedInt("Color"..i.."B",255)
    screen:SetNetworkedInt("Alpha"..i,255)
    screen:SetNetworkedInt("Size"..i,20)
    screen:SetNetworkedString("Font"..i,"coolvetica")
   end
   -- Parse text into lines
   local lines=string.Explode("\n",text)
   for i,line in ipairs(lines)do
    if i<=5 then
     screen:SetNetworkedString("Text"..i,string.sub(line,1,50))
    end
   end
  end
 end)
 -- Admin broadcast mail
 net.Receive("GRM_Net_MailSend",function(_,ply)if not IsValid(ply)or not E.IsNetworkAdmin(ply)then return end;local subject=trim(net.ReadString(),120);local bodyText=string.sub(net.ReadString()or"",1,8192);local from=E.Sessions[ply]and E.Sessions[ply].username or ply:Nick();for user,_ in pairs(E.Accounts)do if user~=from then local id="msg_"..util.CRC(from..user..SysTime()..math.random());E.Mailbox[id]={id=id,from=from,to=user,subject="[РАССЫЛКА] "..(subject~=""and subject or"Уведомление"),body=bodyText,date=os.time(),read=false}end end;E.SaveDB();result(ply,true,"Рассылка отправлена всем пользователям")end)
 hook.Add("PlayerDisconnected","GRM_Net_SessionClose",function(p)E.Sessions[p]=nil end);hook.Add("InitPostEntity","GRM_Net_Load",function()timer.Simple(2,function()E.LoadDB();E.LoadMap()end)end);hook.Add("PreCleanupMap","GRM_Net_CleanupGuard",function()E.SuppressRemovalPersistence=true end);hook.Add("PostCleanupMap","GRM_Net_Reload",function()timer.Simple(1,function()E.SuppressRemovalPersistence=false;E.LoadMap()end)end);hook.Add("ShutDown","GRM_Net_Save",function()E.SuppressRemovalPersistence=true;E.SaveAll()end)
 timer.Create("GRM_Net_TopologyTick",5,0,function()E.PushTopology()end)
 -- v1.5.1: автосейв по dirty — любые изменения (устройство/кабель/файл/почта/
 -- конфиг) попадают на диск не позже чем через 5 секунд, даже без ShutDown.
 timer.Create("GRM_Net_AutoSave",5,0,function()if E.DirtyMap or E.DirtyDB then E.SaveAll()end end)
 print("[GRM Electronics] server v"..E.Version.." loaded")
end
