-- sim_equipment_persistence.lua — runtime шахты: equipment + OreSpawner points.
local pass,fail=0,0
local function ok(v,n)if v then pass=pass+1 print("  ok  "..n)else fail=fail+1 print("  FAIL "..n)end end
SERVER,CLIENT=true,false
function AddCSLuaFile()end
function isstring(v)return type(v)=="string"end
function istable(v)return type(v)=="table"end
function isnumber(v)return type(v)=="number"end
function isfunction(v)return type(v)=="function"end
function IsValid(v)return type(v)=="table"and v.__valid~=false end
function ErrorNoHalt(...)print(...)end
function CurTime()return 100 end
function Color(r,g,b,a)return{r=r,g=g,b=b,a=a}end
string.Trim=string.Trim or function(s)return tostring(s or""):match("^%s*(.-)%s*$")end

local VMT={}
VMT.__index=VMT
function VMT:DistToSqr(b)local x,y,z=self.x-b.x,self.y-b.y,self.z-b.z;return x*x+y*y+z*z end
function VMT:Distance(b)return math.sqrt(self:DistToSqr(b))end
function VMT.__add(a,b)return Vector(a.x+b.x,a.y+b.y,a.z+b.z)end
function VMT.__mul(a,b)if type(a)=="number"then a,b=b,a end;return Vector(a.x*b,a.y*b,a.z*b)end
function Vector(x,y,z)return setmetatable({x=x or 0,y=y or 0,z=z or 0},VMT)end
function Angle(p,y,r)return{p=p or 0,y=y or 0,r=r or 0}end

game={GetMap=function()return"gm_equipment"end}
local mem, blobs, blobN={}, {}, 0
local function copy(v)local o;if type(v)~="table"then return v end;o={};for k,x in pairs(v)do o[k]=copy(x)end;return o end
file={Exists=function(p)return mem[p]~=nil end,Read=function(p)return mem[p]end,Write=function(p,v)mem[p]=v end,CreateDir=function()end,IsDir=function()return true end}
util={}
function util.TableToJSON(t)blobN=blobN+1;local k="JSON"..blobN;blobs[k]=copy(t);return k end
function util.JSONToTable(raw)return blobs[raw]and copy(blobs[raw])or nil end

local H={hooks={},timers={}}
hook={Add=function(n,id,fn)H.hooks[n]=H.hooks[n]or{};H.hooks[n][id]=fn end,Run=function()end}
timer={Create=function(n,d,r,fn)H.timers[n]=fn end,Remove=function(n)H.timers[n]=nil end,Simple=function(_,fn)fn()end}
concommand={Add=function()end}

local world={};local nextID=0
local function phys(owner)
 return{__valid=true,motion=false,IsMotionEnabled=function(s)return s.motion end,EnableMotion=function(s,v)s.motion=v end,Sleep=function()end,Wake=function()end}
end
local function makeEnt(class)
 nextID=nextID+1
 local e={__valid=true,__class=class,__idx=nextID,pos=Vector(),ang=Angle(),model=class=="grm_ore_node"and"models/props/cs_militia/militiarock05.mdl"or"models/Kleiner.mdl"}
 function e:GetClass()return self.__class end;function e:EntIndex()return self.__idx end
 function e:GetPos()return self.pos end;function e:SetPos(v)self.pos=v end;function e:GetAngles()return self.ang end;function e:SetAngles(a)self.ang=a end
 function e:GetModel()return self.model end;function e:SetModel(m)self.model=m end
 function e:GetPhysicsObject()self.ph=self.ph or phys(self);return self.ph end
 function e:Spawn()self.spawned=true end;function e:Activate()self.active=true end
 function e:Remove()self.__valid=false end
 function e:SetOreType(t)self.OreType=t end
 return e
end
ents={}
function ents.Create(class)local e=makeEnt(class);world[#world+1]=e;return e end
function ents.FindByClass(class)local o={};for _,e in ipairs(world)do if IsValid(e)and e.__class==class then o[#o+1]=e end end;return o end
function ents.FindInSphere(pos,r)local o={};for _,e in ipairs(world)do if IsValid(e)and e.pos:DistToSqr(pos)<=r*r then o[#o+1]=e end end;return o end
function ents.GetAll()local o={};for _,e in ipairs(world)do if IsValid(e)then o[#o+1]=e end end;return o end
GRM={PropProtect={MarkServerEntity=function(e)e.serverOwned=true end}}
dofile("lua/autorun/sh_01_grm_persistence_guard.lua")

-- OreSpawner first: MiningPersistence can distinguish automatic nodes by API.
dofile("lua/autorun/server/sv_grm_ore_spawner.lua")
local OS=GRM.OreSpawner
ok(OS and OS.SavePoints and OS.LoadPoints and OS.Refill,"OreSpawner persistence API loaded")
SpawnPoints={{pos=Vector(100,0,0),ang=Angle(0,90,0)}}
local pOK=OS.SavePoints()
ok(pOK==true and mem["grm_saves/grm_orespawns_gm_equipment.json"]~=nil,"ore spawn point primary saved")
OS.Refill()
local auto=ents.FindByClass("grm_ore_node")[1]
ok(IsValid(auto)and auto.GRMOreSpawned==true,"automatic ore node tagged")

-- Manual equipment must be serialized separately from automatic node.
local manual=ents.Create("grm_ore_node");manual:SetPos(Vector(500,0,0));manual:SetOreType("gold");manual:Spawn()
local buyer=ents.Create("grm_ore_buyer");buyer:SetPos(Vector(700,0,0));buyer:Spawn()
dofile("lua/autorun/server/sv_grm_mining_saver.lua")
local MP=GRM.MiningPersistence
ok(MP and MP.SaveAll and MP.LoadAll,"MiningPersistence full API loaded")
local saveOK,saveDetail=MP.SaveAll(nil)
ok(saveOK==true,"mining SaveAll succeeds: "..tostring(saveDetail))
local saved=util.JSONToTable(mem["grm_saves/gm_equipment.json"])
ok(istable(saved)and#saved==2,"only manual node + buyer saved (auto node excluded)")
local sawGold=false;for _,r in ipairs(saved or{})do if r.class=="grm_ore_node"and r.oreType=="gold"then sawGold=true end end
ok(sawGold,"manual ore type persisted")

manual:Remove();buyer:Remove()
local loadOK,loadDetail=MP.LoadAll(nil)
ok(loadOK==true,"mining LoadAll succeeds: "..tostring(loadDetail))
ok(#ents.FindByClass("grm_ore_node")==2 and #ents.FindByClass("grm_ore_buyer")==1,"auto node + manual node + buyer restored without collision")
local againOK=MP.LoadAll(nil)
ok(againOK==true and #ents.FindByClass("grm_ore_node")==2 and #ents.FindByClass("grm_ore_buyer")==1,"repeat load idempotent by UID/position")

-- Corrupt both entity mirrors: live world must survive and SAVE must block.
mem["grm_saves/gm_equipment.json"]="BROKEN";mem["grm_saves/gm_equipment.json.backup"]="BROKEN_TOO";mem["grm_saves/gm_equipment_backup.json"]="BROKEN_CANONICAL"
local before=#ents.GetAll();local badOK=MP.LoadAll(nil)
ok(badOK==false and #ents.GetAll()==before,"corrupt mining JSON preserves all live entities")
local blocked=MP.SaveEntities(nil)
ok(blocked==false,"save blocked after corrupt primary+backup")
local guard=GRM.PersistenceGuard;guard.BeginManualSave("equipment repair")
local repaired,repairDetail=MP.SaveAll(nil)
guard.EndManualSave()
ok(repaired==true,"explicit manual SaveAll archives corruption and repairs from live state: "..tostring(repairDetail))

print(("EQUIPMENT PERSISTENCE: %d/%d failures=%d"):format(pass,pass+fail,fail))
if fail>0 then os.exit(1)end
