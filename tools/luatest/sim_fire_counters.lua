-- Functional arithmetic test for GRM fire pump resources and HUD synchronization.
SERVER=true;CLIENT=false
function AddCSLuaFile()end
function include()end
function isstring(v)return type(v)=="string"end
function istable(v)return type(v)=="table"end
function isfunction(v)return type(v)=="function"end
function IsValid(v)return type(v)=="table"and v.__valid~=false end
math.Clamp=math.Clamp or function(v,a,b)return math.max(a,math.min(b,v))end
function Color(r,g,b,a)return{r=r,g=g,b=b,a=a}end
function Vector(x,y,z)return{x=x or 0,y=y or 0,z=z or 0}end
SOLID_BBOX=1;MOVETYPE_NONE=0;COLLISION_GROUP_WEAPON=1;SIMPLE_USE=1;RENDERMODE_TRANSALPHA=1
hook={Run=function()end};ents={FindInSphere=function()return{}end,FindByClass=function()return{}end}
local now=100;function CurTime()return now end
GRM={FireAddon={HoseCfg={MaxLength=2200,TruckSlots=4},SafeModel=function()return"pump.mdl"end,Models={pump={}},HoseCountOn=function()return 2 end}}
ENT={}
dofile("addons/grm_fire/lua/entities/grm_fire_pump/init.lua")
local function host()
 local h={__valid=true,nw={},nwb={}}
 function h:SetNWInt(k,v)self.nw[k]=v end;function h:GetNWInt(k,d)return self.nw[k]or d end
 function h:SetNWString(k,v)self.nw[k]=v end;function h:SetNWBool(k,v)self.nwb[k]=v end
 return h
end
local function pump()
 local p={__valid=true,v={},_host=host()};setmetatable(p,{__index=ENT})
 local names={"PumpOn","Filling","HydrantFeed","Tank","TankMax","MaxHose","HosesOut","HosesMax","Foam","FoamMax","Powder","PowderMax","Agent","HostVehicle"}
 local bools={PumpOn=true,Filling=true,HydrantFeed=true}
 for _,n in ipairs(names)do local name=n;p["Get"..name]=function(s)if name=="HostVehicle"then return s._host end;local v=s.v[name];if v~=nil then return v end;if name=="Agent"then return""end;if bools[name]then return false end;return 0 end;p["Set"..name]=function(s,v)if name=="HostVehicle"then s._host=v else s.v[name]=v end end end
 function p:SetModel()end;function p:SetSolid()end;function p:SetCollisionBounds()end;function p:SetMoveType()end;function p:SetCollisionGroup()end;function p:SetUseType()end;function p:DrawShadow()end;function p:SetNotSolid()end;function p:SetRenderMode()end;function p:SetColor()end
 function p:GetPhysicsObject()return{__valid=true,Wake=function()end,EnableMotion=function()end}end
 function p:GetParent()return nil end;function p:GetNWBool()return false end;function p:NextThink()end;function p:EmitSound()end
 function p:FindLinkedHydrant()return self._hyd end;function p:FindLinkedCabinet()return self._cab end
 p:Initialize();p:SyncHost();return p
end
local pass,fail=0,0;local function ok(v,n)if v then pass=pass+1 print("  OK   "..n)else fail=fail+1 print("  FAIL "..n)end end
local p=pump();local h=p._host
ok(p:GetTank()==4000 and p:GetFoam()==500 and p:GetPowder()==250,"new pump starts with full bounded tanks")
p:SetPumpOn(true);p:SetAgent("water");ok(p:Consume(8,"water")and p:GetTank()==3992,"water pulse consumes exactly 8")
ok(h.nw.GRM_FireTank==3992 and h.nw.GRM_FireTankMax==4000,"water HUD mirror updates immediately")
p:SetAgent("foam");ok(p:Consume(4,"foam")and p:GetFoam()==496,"foam pulse consumes exactly 4")
ok(h.nw.GRM_FireFoam==496 and h.nw.GRM_FireFoamMax==500,"foam HUD mirror updates immediately")
p:SetAgent("powder");ok(p:Consume(2,"powder")and p:GetPowder()==248,"powder pulse consumes exactly 2")
ok(h.nw.GRM_FirePowder==248 and h.nw.GRM_FirePowderMax==250,"powder HUD mirror updates immediately")
p:SetTank(100);p:SetHydrantFeed(true);p._hyd={__valid=true};ok(p:Consume(8,"water")and p:GetTank()==100,"valid direct hydrant feed does not consume vehicle water")
p._hyd=nil;p:SetHydrantFeed(true);ok(p:Consume(8,"water")and p:GetTank()==92 and not p:GetHydrantFeed(),"invalid direct-feed flag clears and tank is consumed")
p:SetPowder(1);p:SetPumpOn(true);ok(not p:Consume(2,"powder")and p:GetPowder()==0 and not p:GetPumpOn(),"insufficient resource empties tank, rejects pulse and stops pump")
p:SetFoam(4);p:SetPumpOn(true);ok(p:Consume(4,"foam")and p:GetFoam()==0 and not p:GetPumpOn(),"last exact pulse is allowed then stops pump")
p:SetTank(3990);ok(p:FillAgent("water",40)==4000,"water fill clamps at max")
p:SetFoam(490);ok(p:FillAgent("foam",20)==500,"foam fill clamps at max")
p:SetPowder(245);ok(p:FillAgent("powder",20)==250,"powder fill clamps at max")
p:SetFilling(true);ok(p:DrainAgent("foam",99999)==0 and not p:GetFilling() and h.nw.GRM_FireFoam==0,"drain reaches zero, stops fill and syncs HUD")
p:SetTank(3900);p:SetAgent("water");p:SetFilling(true);p._hyd={__valid=true};p:Think();ok(p:GetTank()==3940 and h.nw.GRM_FireTank==3940,"Think fills water by 40 and mirrors it")
p:SetTank(3990);p:SetFilling(true);p:Think();ok(p:GetTank()==4000 and not p:GetFilling(),"filling auto-stops at full tank")
ok(p:GetHosesOut()==2 and h.nw.GRM_FireHosesOut==2 and h.nw.GRM_FireHoses==4,"hose counters synchronize to pump and vehicle")
local swep=assert(io.open("addons/grm_fire/lua/weapons/weapon_grm_hose.lua","rb")):read("*a")
ok(not swep:find("local dmg = (GRM.FireAddon.HoseCfg",1,true),"agent-specific extinguish damage is not overwritten")
local hose=assert(io.open("addons/grm_fire/lua/entities/grm_fire_hose/init.lua","rb")):read("*a")
ok(hose:find('if cls == "grm_fire_pump" then',1,true)and hose:find("return have > 0, ent",1,true),"pump is a pressure graph boundary")
print(("FIRE COUNTERS: %d/%d failures=%d"):format(pass,pass+fail,fail));os.exit(fail>0 and 1 or 0)
