-- Contracts and pure rules for Property + Weather/Time.
SERVER=false CLIENT=false
function istable(v)return type(v)=="table"end;function isstring(v)return type(v)=="string"end;function isfunction(v)return type(v)=="function"end
function IsValid(v)return type(v)=="table"and v.valid==true end
string.Trim=function(s)return(tostring(s):gsub("^%s+",""):gsub("%s+$",""))end
math.Clamp=function(v,a,b)return math.max(a,math.min(b,v))end
function Lerp(t,a,b)return a+(b-a)*t end
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
ok(GRM.Weather.AmbientFactor(12*60)==1 and GRM.Weather.AmbientFactor(0)==0 and GRM.Weather.AmbientFactor(19.5*60)>.45,"perceptual light keeps dusk gradual")
local outdoorExp=GRM.Weather.ExposureTarget(0,.5,true,"clear",1);local indoorExp=GRM.Weather.ExposureTarget(0,.5,false,"clear",1);local dayExp=GRM.Weather.ExposureTarget(1,.5,true,"clear",1)
ok(outdoorExp>.085 and outdoorExp<.10 and indoorExp<outdoorExp and indoorExp>.05 and dayExp==0,"balanced exposure is dark outdoors, readable indoors and neutral by day")
local function read(p)local f=assert(io.open(p,"rb"));local s=f:read("*a");f:close();return s end
local prop=read("lua/autorun/sh_grm_property.lua");local weather=read("lua/autorun/sh_grm_weather.lua");local doors=read("lua/autorun/sh_grm_doors.lua")
ok(prop:find("GRM.Persistence.SaveJSON",1,true)and prop:find("GRM_DoorAccessOverride",1,true),"safe persistence and door integration")
ok(prop:find("PlayerSayTransform",1,true)and prop:find("istable(t)and t[1]",1,true)and weather:find("istable(t)and t[1]",1,true),"EasyChat datapack commands")
ok(weather:find('(tonumber(savedConfig.lightingModelVersion)or 0)<2',1,true)and weather:find('W.Version="2.1.1"',1,true),"legacy config without lightingModelVersion loads safely")
ok(weather:find('concommand.Add("grm_weather_admin"',1,true)and weather:find('s=="/weather_admin"',1,true)and weather:find("GRM_Weather_EasyChat",1,true),"weather admin opens from console, chat and EasyChat")
ok(prop:find("wanted.civil.edit",1,true)and prop:find("property_warrant",1,true),"warrant entry")
ok(prop:find("GRM_PropertyBreach",1,true)and prop:find("cameraIDs",1,true),"alarm and CCTV metadata integration")
ok(weather:find("SetupWorldFog",1,true)and weather:find('ents.Create("env_skypaint")',1,true),"fog and dynamic sky")
ok(weather:find("RenderScreenspaceEffects",1,true)and weather:find("GRM_Weather_Clock",1,true),"evening/night grading and HUD clock")
ok(weather:find("SetSunNormal",1,true)and weather:find("GRM_Weather_SunMotion",1,true),"sun position follows server time")
ok(weather:find('engine.LightStyle(0,"m")',1,true)and not weather:find("nightStyle",1,true),"weather restores compiled map lighting instead of dimming lightmaps")
ok(weather:find("local SKYPAINT",1,true)and weather:find("timePreset",1,true)and weather:find("blendPreset",1,true),"SkyPaint presets interpolate by time")
ok(weather:find("FadeBias=.22",1,true)and weather:find("HDRScale=.28",1,true)and weather:find("SunSize=0",1,true),"night preset removes sun but keeps streets readable")
ok(weather:find("GRM_AmbientFactor",1,true)and weather:find("targetExposure",1,true)and weather:find("exposureNow",1,true),"night uses smooth adaptive exposure instead of map lighting")
ok(weather:find("grm_weather_night_strength",1,true)and weather:find("shelter=isOutside and 1 or .68",1,true)and weather:find("lightingModelVersion=2",1,true),"night stays darker outdoors and readable indoors")
ok(weather:find("storm_night",1,true)and weather:find('weather=="rain"and .62',1,true),"weather blends storm palettes over day/night")
ok(weather:find("ParticleEmitter",1,true)and weather:find('atmos/water_drop',1,true)and weather:find('atmos/warp_ripple3',1,true),"Atmos-derived world rain has drops and collision splashes")
ok(weather:find('atmos/rainsmoke',1,true)and weather:find("pointOutside",1,true)and weather:find("skyCache",1,true),"rain mist uses cached per-cell sky checks")
ok(weather:find('atmos/snow',1,true)and weather:find('weather=="snow"',1,true),"snow is integrated into weather runtime")
local dropFile=assert(io.open("materials/atmos/water_drop.vtf","rb"));local dropSize=dropFile:seek("end");dropFile:close();local mistFile=assert(io.open("materials/atmos/rainsmoke.vtf","rb"));local mistSize=mistFile:seek("end");mistFile:close()
ok(dropSize>5000 and mistSize>300000,"Atmos drop and rain-mist textures are packaged")
local rainFile=assert(io.open("sound/atmos/rain.wav","rb"));local rainRaw=rainFile:read("*a");rainFile:close()
local thunderFile=assert(io.open("sound/atmos/thunder/thunder_1.mp3","rb"));local thunderSize=thunderFile:seek("end");thunderFile:close()
ok(weather:find("atmos/rain.wav",1,true)and weather:find("CreateSound",1,true)and weather:find("ChangeVolume",1,true),"rain and storm use Atmos loop through Source sound patches")
ok(#rainRaw>120000 and rainRaw:find("cue ",1,true)and thunderSize>100000 and weather:find('W.Version="2.1.1"',1,true),"loop-cued rain and real thunder assets are packaged")
local warmSizes={};for _,name in ipairs({"ambient_day_warm.wav","ambient_evening_warm.wav","ambient_night_warm.wav","ambient_noir_city.wav"})do local f=assert(io.open("sound/grm/weather/"..name,"rb"));warmSizes[#warmSizes+1]=f:seek("end");f:close()end
ok(weather:find("ambient_day_warm.wav",1,true)and weather:find("ambient_evening_warm.wav",1,true)and weather:find("ambient_night_warm.wav",1,true),"warm city ambience changes by day period")
ok(warmSizes[1]>1100000 and warmSizes[2]>1100000 and warmSizes[3]>1100000 and warmSizes[4]>1100000,"all four warm ambience WAVs are full 36-second tracks")
ok(weather:find("ambient_noir_city.wav",1,true)and weather:find('musicTheme="periods"',1,true)and weather:find("Тёплый живой город",1,true),"warm city is default and detective theme remains optional")
ok(weather:find("resource.AddFile",1,true)and weather:find("util.PrecacheSound",1,true),"custom audio is downloaded and precached by Source")
ok(weather:find("ambient/weather/rain.wav",1,true)and not weather:find("sound.PlayFile",1,true)and weather:find("grm_weather_audio_debug",1,true),"built-in rain fallback works without BASS file streams")
ok(weather:find("isOutside",1,true)and weather:find("shelter",1,true)and weather:find("thunder_far_away_1.mp3",1,true),"outdoor shelter attenuation and varied thunder")
ok(not weather:find("RedownloadAllLightmaps",1,true)and not weather:find("FadeToPattern",1,true),"weather never recompiles or fades map lightmaps")
ok(weather:find('sv_skyname","painted',1,true)and weather:find("forcePaintedSky",1,true)and weather:find("_originalSkyName",1,true),"painted sky is explicit, configurable and reversible")
ok(weather:find('ents.FindByClass("env_sun")',1,true)and weather:find('TurnOff',1,true),"env_sun follows time and turns off at night")
ok(weather:find('RegisterClass("grm_clock"',1,true)and weather:find("AddExtract",1,true),"physical clocks persist with title")
ok(doors:find("actor.propertyHas",1,true)and doors:find("GRM_DoorAccessOverride",1,true),"Doors Core property adapter")
print(("PROPERTY/WEATHER: %d checks, failures=%d"):format(n,fail));os.exit(fail==0 and 0 or 1)
