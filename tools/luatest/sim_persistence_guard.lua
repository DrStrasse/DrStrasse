-- Functional test for early boot persistence source selection.
SERVER=true;CLIENT=false
function AddCSLuaFile()end
function isstring(v)return type(v)=="string"end
function istable(v)return type(v)=="table"end
function isfunction(v)return type(v)=="function"end
function IsValid()return false end
string.Trim=string.Trim or function(s)return(tostring(s):gsub("^%s+",""):gsub("%s+$",""))end
table.Count=table.Count or function(t)local n=0 for _ in pairs(t or{})do n=n+1 end return n end
game={GetMap=function()return"gm_test"end}
local mem,objects,nextObject={}, {}, 0
local function enc(t)nextObject=nextObject+1;local id="J"..tostring(nextObject);objects[id]=t;return id end
util={JSONToTable=function(raw)return objects[raw]end,TableToJSON=function(t)return enc(t)end}
file={Exists=function(p)return mem[p]~=nil end,Read=function(p)return mem[p]end,Write=function(p,v)if tostring(p):sub(-7)==".backup"and mem[p]==nil then return end;mem[p]=v end,IsDir=function()return true end,CreateDir=function()end}
concommand={Add=function()end}
GRM={}
-- Boot has rich primary; current data will be replaced after guard loads.
mem["grm_inventories.json"]=enc({alice={slots={[1]={id="x"}}}})
mem["grm_documents.json"]=enc({})
mem["grm_documents_backup.json"]=enc({passports={a={name="A"},b={name="B"}}})
dofile("lua/autorun/sh_01_grm_persistence_guard.lua")
local P=GRM.PersistenceGuard
local pass,fail=0,0;local function ok(v,n)if v then pass=pass+1 print("  OK   "..n)else fail=fail+1 print("  FAIL "..n)end end
-- A late bad loader overwrote primary with an empty valid object: boot wins.
mem["grm_inventories.json"]=enc({})
local inv,src=P.ReadBest("grm_inventories.json",{"grm_inventories_backup.json"},"test inventory")
ok(istable(inv)and inv.alice~=nil,"boot snapshot beats later empty overwrite")
ok(src=="grm_inventories.json@boot","source explicitly reports @boot")
-- More complete valid backup wins over primary.
local docs,dsrc=P.ReadBest("grm_documents.json",{"grm_documents_backup.json"},"test docs")
ok(istable(docs)and table.Count(docs.passports)==2,"most complete backup selected")
ok(dsrc=="grm_documents_backup.json","backup source reported")
mem["authoritative.json"]=enc({keep=true});mem["authoritative.json.backup"]=enc({keep=true,old=true,older=true})
local auth,asrc=P.ReadBest("authoritative.json",{"authoritative.json.backup"},"authoritative")
ok(auth.keep==true and auth.old==nil and asrc=="authoritative.json","nonempty primary remains authoritative over richer stale backup")
-- Invalid existing files do not silently become a healthy empty table.
mem["broken.json"]="BROKEN";mem["broken.json.backup"]="ALSO_BROKEN"
local bad,_,_,meta=P.ReadBest("broken.json",{"broken.json.backup"},"broken")
ok(bad==nil and meta.hadAny==true and #meta.invalid==2,"invalid primary/backup is load-blocking")

-- Explicit superadmin Save is a recovery transaction: raw files are archived first.
ok(P.AllowBlockedWrite("broken.json","broken.json.backup","outside") == false,"blocked write remains denied outside manual save")
P.BeginManualSave("test repair")
local repairOK=P.AllowBlockedWrite("broken.json","broken.json.backup","broken test")
P.EndManualSave()
local recoveryCount=0
for path,rawValue in pairs(mem)do if tostring(path):find("grm_recovery/",1,true)and(rawValue=="BROKEN"or rawValue=="ALSO_BROKEN")then recoveryCount=recoveryCount+1 end end
ok(repairOK==true and recoveryCount>=2,"manual save archives corrupt primary+backup and permits repair")
-- Materialization writes identical validated raw to both mirrors.
local raw=enc({x=1});ok(P.Materialize("p.json","b.json",raw,"mirror"),"materialize succeeds")
ok(mem["p.json"]==raw and mem["b.json"]==raw,"primary and backup identical")
local legacyRaw=enc({legacy=true})
ok(P.Materialize("legacy.json","legacy.json.backup",legacyRaw,"legacy extension"),"legacy .json.backup request materializes through canonical name")
ok(mem["legacy_backup.json"]==legacyRaw and mem["legacy.json.backup"]==nil,"canonical _backup.json bypasses GMod extension restriction")
mem["legacy.json"]="BROKEN_PRIMARY"
local legacyRecovered,legacySource=P.ReadBest("legacy.json",{"legacy.json.backup"},"canonical fallback")
ok(legacyRecovered and legacyRecovered.legacy==true and legacySource=="legacy_backup.json","ReadBest automatically discovers canonical backup")
local function readSource(path)local f=assert(io.open(path,"rb"));local s=f:read("*a");f:close();return s end
local hub=readSource("lua/autorun/server/sv_grm_persistence_hub.lua")
local phone=readSource("lua/autorun/server/sv_grm_phone.lua")
local logistics=readSource("lua/autorun/server/sv_grm_logistics.lua")
local inventory=readSource("lua/autorun/sh_grm_inventory.lua")
local electronics=readSource("lua/autorun/sh_grm_electronics.lua")
ok(hub:find('invoke("Perm", "SaveAll"',1,true)and not hub:find('perm = { save = function() return isfunction(GRM_SaveEntities)',1,true),"Persistence Hub perm no longer calls mining saver")
local parseAt=phone:find("guard.ReadBest",1,true)or 999999;local removeAt=phone:find("Только карта заменяется картой",1,true)or 0
ok(parseAt<removeAt,"phone parses primary/backup before removing live entities")
ok(logistics:find("live entities preserved",1,true)and logistics:find("L.LoadBlocked",1,true),"logistics preserves live entities and blocks empty shutdown save")
ok(inventory:find("inventoryLoadBlocked",1,true)and inventory:find("INV_BACKUP_FILE",1,true),"inventory autosave blocked after failed load")
ok(electronics:find("DBLoadBlocked",1,true)and electronics:find("MapLoadBlocked",1,true),"electronics DB/map fail closed")
local guardSrc=readSource("lua/autorun/sh_01_grm_persistence_guard.lua")
ok(guardSrc:find('"grm_food/vending_" .. map',1,true) and guardSrc:find('"grm_factory_fullcycle/weapon_lockers.json"',1,true),
   "guard snapshots food vending and all factory support databases")
ok(guardSrc:find('"grm_logistics/access.json"',1,true) and guardSrc:find('"grm_saves/" .. map',1,true)
   and guardSrc:find('"grm_saves/grm_orespawns_" .. map',1,true)
   and guardSrc:find('"grm_roomtap/temporary_equipment.json"',1,true),
   "guard snapshots logistics, mining, ore points and RoomTap support databases")
print(("PERSIST GUARD: %d/%d failures=%d"):format(pass,pass+fail,fail))
os.exit(fail>0 and 1 or 0)
