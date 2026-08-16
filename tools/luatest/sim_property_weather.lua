-- Contracts and pure rules for Property + Weather/Time.
SERVER=false CLIENT=false
function istable(v)return type(v)=="table"end;function isstring(v)return type(v)=="string"end;function isfunction(v)return type(v)=="function"end
function IsValid(v)return type(v)=="table"and v.valid==true end
string.Trim=function(s)return(tostring(s):gsub("^%s+",""):gsub("%s+$",""))end
math.Clamp=function(v,a,b)return math.max(a,math.min(b,v))end
function GetGlobalFloat(_,d)return d end
GRM={Identity={CharacterKey=function(p)return p.key end}}
local fail,n=0,0;local function ok(c,s)n=n+1;if c then print("  ok  "..s)else fail=fail+1;print("  FAIL "..s)end end
dofile("lua/autorun/sh_grm_property.lua");dofile("lua/autorun/sh_grm_weather.lua")
local r=GRM.Property.Normalize({id="x",name="Квартира",type="apartment",ownerType="character",ownerKey="1:char2",employees={{key="2:char1"}},guests={},tempKeys={{key="3:char3",expires=os.time()+60}}})
local owner={valid=true,key="1:char2"};function owner:IsSuperAdmin()return false end
local employee={valid=true,key="2:char1"};function employee:IsSuperAdmin()return false end
local temp={valid=true,key="3:char3"};function temp:IsSuperAdmin()return false end
ok(GRM.Property.HasAccess(owner,r),"owner CharacterKey has access")
ok(GRM.Property.HasAccess(employee,r),"employee key has access")
ok(GRM.Property.HasAccess(temp,r),"temporary unexpired key has access")
ok(not GRM.Property.HasAccess({valid=false},r),"invalid actor denied")
ok(GRM.Property.Types.restricted=="Закрытая территория"and GRM.Property.Types.government~=nil,"all strategic property types")
r.zone={mins={x=0,y=0,z=0},maxs={x=100,y=100,z=100}}
ok(GRM.Property.IsInside(r,{x=50,y=50,z=50})and not GRM.Property.IsInside(r,{x=150,y=50,z=50}),"property zone bounds")
ok(GRM.Weather.FormatTime(7*60+5)=="07:05","clock formatting")
ok(GRM.Weather.Period(19*60)=="Вечер"and GRM.Weather.Period(2*60)=="Ночь","day periods")
ok(GRM.Weather.SunFactor(12*60)>.99 and GRM.Weather.SunFactor(1*60)==0,"sun curve")
local function read(p)local f=assert(io.open(p,"rb"));local s=f:read("*a");f:close();return s end
local prop=read("lua/autorun/sh_grm_property.lua");local weather=read("lua/autorun/sh_grm_weather.lua");local doors=read("lua/autorun/sh_grm_doors.lua")
ok(prop:find("GRM.Persistence.SaveJSON",1,true)and prop:find("GRM_DoorAccessOverride",1,true),"safe persistence and door integration")
ok(prop:find("PlayerSayTransform",1,true)and prop:find("istable(t)and t[1]",1,true)and weather:find("istable(t)and t[1]",1,true),"EasyChat datapack commands")
ok(prop:find("wanted.civil.edit",1,true)and prop:find("property_warrant",1,true),"warrant entry")
ok(prop:find("GRM_PropertyBreach",1,true)and prop:find("cameraIDs",1,true),"alarm and CCTV metadata integration")
ok(weather:find("SetupWorldFog",1,true)and weather:find('ents.Create("env_skypaint")',1,true),"fog and dynamic sky")
ok(weather:find("RenderScreenspaceEffects",1,true)and weather:find("GRM_Weather_Clock",1,true),"evening/night grading and HUD clock")
ok(weather:find("SetSunNormal",1,true)and weather:find("GRM_Weather_SunMotion",1,true),"sun position follows server time")
ok(weather:find("engine.LightStyle",1,true)and weather:find('sun < .03 and "d"',1,true),"midnight dims world lighting")
ok(weather:find("local SKYPAINT",1,true)and weather:find("timePreset",1,true)and weather:find("blendPreset",1,true),"SkyPaint presets interpolate by time")
ok(weather:find("FadeBias=.1",1,true)and weather:find("HDRScale=.19",1,true)and weather:find("SunSize=0",1,true),"night preset removes sun and darkens sky")
ok(weather:find("storm_night",1,true)and weather:find('weather=="rain"and .62',1,true),"weather blends storm palettes over day/night")
ok(weather:find("ParticleEmitter",1,true)and weather:find("SetStartLength",1,true)and not weather:find("GRM_Weather_Precip",1,true),"world-space rain replaces screen-line overlay")
ok(weather:find("rain_loop.wav",1,true)and weather:find("storm_loop.wav",1,true)and weather:find("EnableLooping",1,true),"looping rain and storm sound beds")
ok(weather:find("ambient_day.wav",1,true)and weather:find("ambient_evening.wav",1,true)and weather:find("ambient_night.wav",1,true),"musical ambience by day period")
ok(weather:find("isOutside",1,true)and weather:find("shelter",1,true)and weather:find("thunder1.wav",1,true),"outdoor shelter attenuation and thunder")
ok(weather:find('RegisterClass("grm_clock"',1,true)and weather:find("AddExtract",1,true),"physical clocks persist with title")
ok(doors:find("actor.propertyHas",1,true)and doors:find("GRM_DoorAccessOverride",1,true),"Doors Core property adapter")
print(("PROPERTY/WEATHER: %d checks, failures=%d"):format(n,fail));os.exit(fail==0 and 0 or 1)
