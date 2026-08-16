-- Регрессия: конфигурация работ v3 + базовый цикл тяжёлого ранения 911.
string.Trim=function(s)return tostring(s or ""):match("^%s*(.-)%s*$")end
function istable(v)return type(v)=="table"end function isstring(v)return type(v)=="string"end function isfunction(v)return type(v)=="function"end
function IsValid(v)return type(v)=="table" and v._invalid~=true end
local VM={}; VM.__index=VM
function VM:Distance(o)local x,y,z=self.x-o.x,self.y-o.y,self.z-o.z return math.sqrt(x*x+y*y+z*z)end
function VM:DistToSqr(o)local x,y,z=self.x-o.x,self.y-o.y,self.z-o.z return x*x+y*y+z*z end
function Vector(x,y,z)return setmetatable({x=x or 0,y=y or 0,z=z or 0},VM)end
vector_origin=Vector(0,0,0)
local H={hooks={},timers={},net={},files={},state=10000}
util={AddNetworkString=function()end,JSONToTable=function(raw)return raw~="" and {version=1} or nil end,TableToJSON=function()return "{ok:true}" end}
file={IsDir=function()return true end,CreateDir=function()end,Read=function(p)return H.files[p]end,Write=function(p,v)H.files[p]=v end}
game={GetMap=function()return "gm_test"end,GetWorld=function()return {}end}
hook={Add=function(n,id,fn)H.hooks[n]=H.hooks[n]or{} H.hooks[n][id]=fn end,Run=function()end}
timer={Create=function(n,d,r,fn)H.timers[n]={fn=fn,d=d}end,Remove=function(n)H.timers[n]=nil end,Adjust=function(n,d,r,fn)H.timers[n]={fn=fn,d=d}end,Simple=function(_,fn)fn()end}
net={Receive=function(n,fn)H.net[n]=fn end,Start=function()end,WriteTable=function()end,WriteString=function()end,WriteUInt=function()end,WriteBool=function()end,WriteVector=function()end,WriteEntity=function()end,Send=function()end}
concommand={Add=function()end}
AddCSLuaFile=function()end
player={GetAll=function()return H.players or{}end}
ents={Create=function()return nil end}
function CurTime()return 100 end
SERVER=true CLIENT=false
GRM={Identity={CharacterKey=function(p)return p._key end},Notify=function()end,Economy={StateBudgetGet=function()return H.state end,StateBudgetAdd=function(v)H.state=H.state+v return H.state end},MedicalFull={IsMedic=function(p)return p._medic==true end}}
Factions={}

dofile("lua/autorun/sh_grm_jobs_config.lua")
local JB=GRM.Jobs
local fails=0
local function check(n,c)if c then print("[SIM] OK: "..n)else fails=fails+1 print("[SIM] FAIL: "..n)end end
check("конфиг работ поднялся",JB and JB.ConfigVersion=="1.0.0")
JB.WorkPoints={{id="1",type="taxi_pickup",name="Вокзал",pos={x=10,y=20,z=30}},{id="2",type="taxi_dropoff",name="Больница",pos={x=100,y=200,z=30}}}
local a=JB.GetRoutePoints("taxi_pickup")
check("типизированная точка такси",#a==1 and a[1]:GetPos().x==10 and a[1]:GetNWString("GRM_JobZoneName","")=="Вокзал")
JB.WorkConfig.taxiVehicles={"simfphys_taxi"}
local veh={GetClass=function()return"simfphys_taxi"end,GetNWString=function(_,_,d)return d end,GetDriver=function(self)return self._driver end}
local driver={_key="1:char1",InVehicle=function()return true end,GetVehicle=function()return veh end}; veh._driver=driver
check("разрешённая машина такси",JB.IsWorkVehicleAllowed(driver,"taxi"))
veh.GetClass=function()return"prop_vehicle_jeep"end
check("чужая машина такси запрещена",not JB.IsWorkVehicleAllowed(driver,"taxi"))
JB.WorkConfig.fundFromState=true
local ok,res=JB.ReserveSystemReward({_key="2:char1",Nick=function()return"Водитель"end},"taxi",700)
check("резерв из казны",ok and res==700 and H.state==9300)
JB.RefundSystemReward(700,"тест")
check("возврат резерва",H.state==10000)

local function person(name,key,medic)
 local p={_name=name,_key=key,_medic=medic,_nw={},_hp=50,_pos=Vector(0,0,0),_frozen=false}
 function p:IsPlayer()return true end function p:IsSuperAdmin()return false end function p:Alive()return true end function p:GetClass()return "player" end
 function p:SteamID64()return self._key:match("^([^:]+)")end function p:Nick()return self._name end function p:GetNWString(_,d)return d end
 function p:GetNWBool(k,d)local v=self._nw[k]if v==nil then return d end return v end function p:SetNWBool(k,v)self._nw[k]=v end
 function p:GetNWInt(k,d)local v=self._nw[k]if v==nil then return d end return v end function p:SetNWInt(k,v)self._nw[k]=v end
 function p:GetPos()return self._pos end function p:SetHealth(v)self._hp=v end function p:Health()return self._hp end function p:GetMaxHealth()return 100 end
 function p:ExitVehicle()end function p:Freeze(v)self._frozen=v end function p:EntIndex()return self._medic and 2 or 1 end function p:ChatPrint()end
 return p
end
local victim=person("Пациент","100:char1",false); local medic=person("Врач","200:char1",true); H.players={victim,medic}
dofile("lua/autorun/sh_grm_911.lua")
local EM=GRM.Emergency
local dmg={GetDamage=function()return 75 end,GetDamageType=function()return 2 end,GetAttacker=function()return medic end,GetInflictor=function()return medic end,SetDamage=function(_,v)H.damage=v end}
local damageHook=H.hooks.EntityTakeDamage.GRM_911_Damage
damageHook(victim,dmg)
check("летальный урон переводит в тяжёлое состояние",victim:GetNWBool("GRM_911_Downed") and victim:Health()==1 and H.damage==0)
check("автовызов 911 создан",#EM.Calls>=1 and EM.Calls[#EM.Calls].patientName=="Пациент")
local sOk=EM.Stabilize(medic,victim)
check("стабилизация продлевает жизнь",sOk and victim:GetNWBool("GRM_911_Stable"))
local rOk=EM.Revive(medic,victim)
check("медик реанимирует",rOk and not victim:GetNWBool("GRM_911_Downed") and victim:Health()==EM.Config.reviveHealth and not victim._frozen)
print("[SIM] === "..(fails==0 and "ВСЕ ПРОВЕРКИ ПРОШЛИ" or ("ПРОВАЛОВ: "..fails)).." ===")
os.exit(fails==0 and 0 or 1)
