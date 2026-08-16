--[[ GRM Weather & Time v1.0.0: authoritative clock, day/night, fog and sky. ]]
if SERVER then AddCSLuaFile()end
GRM=GRM or{};GRM.Weather=GRM.Weather or{};local W=GRM.Weather
W.Version="2.0.0";W.Types={clear={name="Ясно",fog=.08},cloudy={name="Облачно",fog=.22},fog={name="Туман",fog=.72},rain={name="Дождь",fog=.38},storm={name="Гроза",fog=.55},snow={name="Снег",fog=.32}}
W.Config=W.Config or{dayLengthMinutes=90,randomWeather=true,weatherMinMinutes=12,weatherMaxMinutes=28,startHour=8,hudClock=true,soundVolume=.48,musicVolume=.18,musicEnabled=true,musicTheme="periods",nightDarkness=.3,snowEnabled=true,forcePaintedSky=true,atmosAssetVersion=1}
local OPEN="GRM_Weather_Admin";local SAVE="GRM_Weather_Save"
if GRM.Access and GRM.Access.Register then GRM.Access.Register("weather.manage",{label="Погода и время: управление",scope="account"})end
function W.CanAdmin(p)return IsValid(p)and(p:IsSuperAdmin()or(GRM.Access and GRM.Access.Can and GRM.Access.Can(p,"weather.manage")==true))end
function W.TimeMinutes()return GetGlobalFloat("GRM_TimeMinutes",W.Config.startHour*60)%1440 end
function W.FormatTime(minutes)minutes=math.floor(tonumber(minutes)or W.TimeMinutes())%1440;return string.format("%02d:%02d",math.floor(minutes/60),minutes%60)end
function W.Period(minutes)local h=(tonumber(minutes)or W.TimeMinutes())/60;if h<5 then return"Ночь"elseif h<8 then return"Утро"elseif h<18 then return"День"elseif h<22 then return"Вечер"else return"Ночь"end end
function W.SunFactor(minutes)local h=(tonumber(minutes)or W.TimeMinutes())/60;local x=math.sin(((h-6)/12)*math.pi);return math.Clamp(x,0,1)end
if SERVER then
 util.AddNetworkString(OPEN);util.AddNetworkString(SAVE);local FILE="grm_weather/config.json"
 local AUDIO_RESOURCES={
  "sound/grm/weather/ambient_day_warm.wav","sound/grm/weather/ambient_evening_warm.wav","sound/grm/weather/ambient_night_warm.wav","sound/grm/weather/ambient_noir_city.wav",
  "sound/atmos/rain.wav","sound/atmos/thunder/thunder_1.mp3","sound/atmos/thunder/thunder_2.mp3","sound/atmos/thunder/thunder_3.mp3","sound/atmos/thunder/thunder_far_away_1.mp3","sound/atmos/thunder/thunder_far_away_2.mp3",
 }
 for _,path in ipairs(AUDIO_RESOURCES)do resource.AddFile(path);util.PrecacheSound(path:gsub("^sound/",""))end
 local MATERIAL_RESOURCES={"materials/atmos/water_drop.vmt","materials/atmos/water_drop.vtf","materials/atmos/rainsmoke.vmt","materials/atmos/rainsmoke.vtf","materials/atmos/warp_ripple3.vmt","materials/atmos/warp_ripple3_normal.vtf","materials/atmos/snow.vmt","materials/atmos/snow.vtf"}
 for _,path in ipairs(MATERIAL_RESOURCES)do resource.AddFile(path)end
 local function load()
  local d=GRM.Persistence.LoadJSON(FILE,{version=1,config=W.Config,state={time=W.Config.startHour*60,weather="clear"}});local oldAssets=not(istable(d.config)and tonumber(d.config.atmosAssetVersion))
  if istable(d.config)then for k,v in pairs(d.config)do W.Config[k]=v end end
  if oldAssets then W.Config.soundVolume=.48;W.Config.atmosAssetVersion=1 end
  W._time=tonumber(d.state and d.state.time)or W.Config.startHour*60;W._weather=W.Types[d.state and d.state.weather]and d.state.weather or"clear"
 end
 local function save()return GRM.Persistence.SaveJSON(FILE,{version=1,config=W.Config,state={time=W._time,weather=W._weather}},{version=1})end
 load();W._originalSkyName=(GetConVar("sv_skyname")and GetConVar("sv_skyname"):GetString())or"";SetGlobalFloat("GRM_TimeMinutes",W._time);SetGlobalString("GRM_Weather",W._weather);if GRM.Perm and GRM.Perm.RegisterClass then GRM.Perm.RegisterClass("grm_clock",true)end;if GRM.PermData and GRM.PermData.AddExtract then GRM.PermData.AddExtract("grm_clock",function(e)return{clockName=e:GetClockName()}end);GRM.PermData.AddApply("grm_clock",function(e,d)if d.clockName then e:SetClockName(string.Trim(tostring(d.clockName)):sub(1,64))end end)end
 local function skyPaint()local e=ents.FindByClass("env_skypaint")[1];if not IsValid(e)then e=ents.Create("env_skypaint");if IsValid(e)then e:SetPos(Vector(0,0,0));e:Spawn()end end;return e end
 local SKYPAINT={
  dawn={TopColor=Vector(.2,.5,1),BottomColor=Vector(.46,.65,.49),FadeBias=1,HDRScale=.26,StarScale=1.84,StarFade=0,StarSpeed=.02,DuskScale=1,DuskIntensity=1,DuskColor=Vector(1,.2,0),SunColor=Vector(.2,.1,0),SunSize=2},
  day={TopColor=Vector(.2,.49,1),BottomColor=Vector(.8,1,1),FadeBias=1,HDRScale=.26,StarScale=1.84,StarFade=1.5,StarSpeed=.02,DuskScale=1,DuskIntensity=1,DuskColor=Vector(1,.2,0),SunColor=Vector(.83,.45,.11),SunSize=.34},
  dusk={TopColor=Vector(.24,.15,.08),BottomColor=Vector(.4,.07,0),FadeBias=1,HDRScale=.36,StarScale=1.5,StarFade=5,StarSpeed=.01,DuskScale=1,DuskIntensity=1.94,DuskColor=Vector(.69,.22,.02),SunColor=Vector(.9,.3,0),SunSize=.44},
  night={TopColor=Vector(.012,.02,.055),BottomColor=Vector(.09,.12,.21),FadeBias=.22,HDRScale=.28,StarScale=1.65,StarFade=5,StarSpeed=.01,DuskScale=0,DuskIntensity=0,DuskColor=Vector(.15,.18,.3),SunColor=Vector(.08,.11,.2),SunSize=0},
  storm={TopColor=Vector(.22,.22,.22),BottomColor=Vector(.08,.09,.12),FadeBias=1,HDRScale=.30,StarScale=2,StarFade=5,StarSpeed=.04,DuskScale=0,DuskIntensity=0,DuskColor=Vector(.23,.23,.23),SunColor=Vector(.3,.3,.34),SunSize=.1},
  storm_night={TopColor=Vector(.008,.012,.025),BottomColor=Vector(.035,.045,.08),FadeBias=.65,HDRScale=.25,StarScale=1.8,StarFade=5,StarSpeed=.04,DuskScale=0,DuskIntensity=0,DuskColor=Vector(.08,.09,.13),SunColor=Vector(.05,.06,.1),SunSize=0},
 }
 local SKY_KEYS={{0,"night"},{4.5,"night"},{6,"dawn"},{9,"day"},{16.5,"day"},{19,"dusk"},{22,"night"},{24,"night"}}
 local VECTOR_FIELDS={TopColor=true,BottomColor=true,DuskColor=true,SunColor=true}
 local function blendPreset(a,b,t)
  local out={};for key,value in pairs(a)do if VECTOR_FIELDS[key]then out[key]=LerpVector(t,value,b[key])else out[key]=Lerp(t,value,b[key])end end;return out
 end
 local function timePreset(hour)
  hour=hour%24
  for i=1,#SKY_KEYS-1 do local a,b=SKY_KEYS[i],SKY_KEYS[i+1];if hour>=a[1]and hour<=b[1]then local span=math.max(.001,b[1]-a[1]);return blendPreset(SKYPAINT[a[2]],SKYPAINT[b[2]],math.Clamp((hour-a[1])/span,0,1))end end
  return SKYPAINT.night
 end
 local restoredLightStyle=false
 local function restoreWorldLight()
  -- Never dim compiled lightmaps: changing style 0 broke maps and required
  -- artificial lamps. Night is now sky + client grading only.
  if not restoredLightStyle and engine and engine.LightStyle then engine.LightStyle(0,"m");restoredLightStyle=true end
 end
 local function applySky()
  local e=skyPaint();if not IsValid(e)or not isfunction(e.SetTopColor)then return end
  local hour=W._time/60;local sun=W.SunFactor(W._time);local preset=timePreset(hour);local weather=W._weather
  local weatherBlend=weather=="storm"and 1 or weather=="rain"and .62 or weather=="cloudy"and .38 or weather=="fog"and .18 or 0
  if weatherBlend>0 then local storm=sun<.15 and SKYPAINT.storm_night or SKYPAINT.storm;preset=blendPreset(preset,storm,weatherBlend)end
  local elevation=math.sin(math.rad((hour-6)*15));local azimuth=(hour/24)*360+90;local sunNormal=Angle(-elevation*78,azimuth,0):Forward()
  if isfunction(e.SetSunNormal)then e:SetSunNormal(sunNormal)end
  local envSun=ents.FindByClass("env_sun")[1]
  if IsValid(envSun)then envSun:SetKeyValue("sun_dir",tostring(sunNormal));envSun:Fire(sun<.015 and"TurnOff"or"TurnOn","",0)end
  e:SetTopColor(preset.TopColor);e:SetBottomColor(preset.BottomColor)
  if isfunction(e.SetFadeBias)then e:SetFadeBias(preset.FadeBias)end
  if isfunction(e.SetHDRScale)then e:SetHDRScale(preset.HDRScale)end
  e:SetStarScale(preset.StarScale);e:SetStarFade(preset.StarFade);e:SetStarSpeed(preset.StarSpeed)
  e:SetDuskScale(preset.DuskScale);e:SetDuskIntensity(preset.DuskIntensity);e:SetDuskColor(preset.DuskColor)
  e:SetSunColor(preset.SunColor);e:SetSunSize(preset.SunSize)
  restoreWorldLight()
 end
 local function sync()SetGlobalFloat("GRM_TimeMinutes",W._time);SetGlobalString("GRM_Weather",W._weather);SetGlobalFloat("GRM_SunFactor",W.SunFactor(W._time));SetGlobalBool("GRM_WeatherHUD",W.Config.hudClock~=false);SetGlobalFloat("GRM_WeatherSoundVolume",math.Clamp(tonumber(W.Config.soundVolume)or.48,0,1));SetGlobalFloat("GRM_WeatherMusicVolume",math.Clamp(tonumber(W.Config.musicVolume)or.18,0,1));SetGlobalBool("GRM_WeatherMusic",W.Config.musicEnabled~=false);SetGlobalString("GRM_WeatherMusicTheme",W.Config.musicTheme=="noir"and"noir"or"periods");SetGlobalFloat("GRM_NightDarkness",math.Clamp(tonumber(W.Config.nightDarkness)or.3,.2,.85))end
 local function nextWeather()if not W.Config.randomWeather then return end;local ids={"clear","clear","cloudy","fog","rain","storm"};if W.Config.snowEnabled~=false then ids[#ids+1]="snow"end;W._weather=ids[math.random(#ids)];W._weatherUntil=CurTime()+math.random(W.Config.weatherMinMinutes*60,W.Config.weatherMaxMinutes*60);sync();save();if GRM.Audit then GRM.Audit.Write("weather","weather.change",nil,{}, {weather=W._weather})end end
 W._weatherUntil=CurTime()+math.random(W.Config.weatherMinMinutes*60,W.Config.weatherMaxMinutes*60)
 local function ensurePaintedSky()local cv=GetConVar("sv_skyname");if not cv then return end;if W.Config.forcePaintedSky~=false then if cv:GetString()~="painted"then RunConsoleCommand("sv_skyname","painted")end elseif W._originalSkyName~=""and cv:GetString()=="painted"then RunConsoleCommand("sv_skyname",W._originalSkyName)end end
 timer.Create("GRM_Weather_Clock",1,0,function()W._time=(W._time+1440/math.max(600,(tonumber(W.Config.dayLengthMinutes)or 90)*60))%1440;if CurTime()>=W._weatherUntil then nextWeather()end;sync()end);timer.Create("GRM_Weather_SunMotion",5,0,applySky);timer.Simple(1,applySky);timer.Create("GRM_Weather_Autosave",120,0,save)
 hook.Add("InitPostEntity","GRM_Weather_Sky",function()ensurePaintedSky();timer.Simple(2,applySky)end);hook.Add("PostCleanupMap","GRM_Weather_SkyCleanup",function()timer.Simple(1,function()ensurePaintedSky();applySky()end)end);hook.Add("ShutDown","GRM_Weather_Save",save)
 local function adminData(p)if not W.CanAdmin(p)then return end;net.Start(OPEN);net.WriteTable(W.Config);net.WriteFloat(W._time);net.WriteString(W._weather);net.Send(p)end
 net.Receive(SAVE,function(bits,p)if not W.CanAdmin(p)then return end;if GRM.Net and not GRM.Net.Guard(p,"weather.admin.save",{rate=.5,burst=2,maxBits=65536},{bits=bits})then return end;local d=net.ReadTable()or{};W.Config.dayLengthMinutes=math.Clamp(tonumber(d.dayLengthMinutes)or 90,10,1440);W.Config.randomWeather=d.randomWeather~=false;W.Config.weatherMinMinutes=math.Clamp(math.floor(tonumber(d.weatherMinMinutes)or 12),2,240);W.Config.weatherMaxMinutes=math.Clamp(math.floor(tonumber(d.weatherMaxMinutes)or 28),W.Config.weatherMinMinutes,480);W.Config.hudClock=d.hudClock~=false;W.Config.soundVolume=math.Clamp(tonumber(d.soundVolume)or.48,0,1);W.Config.musicVolume=math.Clamp(tonumber(d.musicVolume)or.18,0,1);W.Config.musicEnabled=d.musicEnabled~=false;W.Config.musicTheme=d.musicTheme=="noir"and"noir"or"periods";W.Config.nightDarkness=math.Clamp(tonumber(d.nightDarkness)or.3,.2,.85);W.Config.snowEnabled=d.snowEnabled~=false;W.Config.forcePaintedSky=d.forcePaintedSky~=false;local hour=tonumber(d.hour);if hour then W._time=(hour%24)*60 end;if W.Types[d.weather]then W._weather=d.weather;W._weatherUntil=CurTime()+W.Config.weatherMaxMinutes*60 end;save();sync();ensurePaintedSky();applySky();if GRM.Audit then GRM.Audit.Write("weather","admin.save",p,{},d)end;adminData(p)end)
 concommand.Add("grm_weather_admin",adminData);concommand.Add("grm_time",function(p)if IsValid(p)then p:ChatPrint("[Время] "..W.FormatTime(W._time).." • "..W.Period(W._time).." • "..W.Types[W._weather].name)end end)
 hook.Add("PlayerSay","GRM_Weather_Chat",function(p,t)local s=string.lower(string.Trim(t or""));if s=="/time"or s=="/время"or s=="/weather"or s=="/погода"then p:ChatPrint("[Время] "..W.FormatTime(W._time).." • "..W.Period(W._time).." • "..W.Types[W._weather].name);return""elseif s=="/weather_admin"and W.CanAdmin(p)then adminData(p);return""end end)
 hook.Add("PlayerSayTransform","GRM_Weather_EasyChat",function(p,t,d)d=istable(t)and t or d;local raw=istable(t)and t[1]or t;local s=string.lower(string.Trim(raw or""));if s~="/time"and s~="/время"and s~="/weather"and s~="/погода"and s~="/weather_admin"then return end;if s=="/weather_admin"then if W.CanAdmin(p)then adminData(p)end else p:ChatPrint("[Время] "..W.FormatTime(W._time).." • "..W.Period(W._time).." • "..W.Types[W._weather].name)end;d.SkipPlayerSay=true;d[1]=""end)
 print("[GRM Weather] v"..W.Version.." server loaded")
end
if CLIENT then
    surface.CreateFont("GRMClock", { font="Roboto", size=22, weight=800, extended=true })
    surface.CreateFont("GRMWeather", { font="Roboto", size=14, weight=500, extended=true })

    local cvAudio = CreateClientConVar("grm_weather_audio", "1", true, false, "Weather sounds")
    local cvMusic = CreateClientConVar("grm_weather_music", "1", true, false, "Weather ambient music")
    local smoothFog, outside = 0, false
    local nextOutsideCheck, nextThunder, lightning = 0, 0, 0

    local function isOutside()
        local ply = LocalPlayer()
        if not IsValid(ply) then return false end
        local start = ply:EyePos()
        local tr = util.TraceLine({ start=start, endpos=start + Vector(0,0,12000), mask=MASK_SOLID_BRUSHONLY, filter=ply })
        return tr.HitSky or not tr.Hit
    end

    hook.Add("SetupWorldFog", "GRM_Weather_Fog", function()
        local typ = W.Types[GetGlobalString("GRM_Weather", "clear")] or W.Types.clear
        smoothFog = Lerp(FrameTime() * .4, smoothFog, typ.fog)
        if smoothFog < .02 then return end
        local sun = GetGlobalFloat("GRM_SunFactor", 1)
        render.FogMode(MATERIAL_FOG_LINEAR)
        render.FogStart(250 * (1 - smoothFog))
        render.FogEnd(Lerp(smoothFog, 12000, 900))
        render.FogMaxDensity(math.Clamp(smoothFog, 0, .92))
        render.FogColor(50 + 80 * sun, 58 + 90 * sun, 70 + 105 * sun)
        return true
    end)

    hook.Add("SetupSkyboxFog", "GRM_Weather_SkyFog", function(scale)
        local typ = W.Types[GetGlobalString("GRM_Weather", "clear")] or W.Types.clear
        local sun = GetGlobalFloat("GRM_SunFactor", 1)
        render.FogMode(MATERIAL_FOG_LINEAR)
        render.FogStart(0)
        render.FogEnd(8000 * scale)
        render.FogMaxDensity(math.Clamp(typ.fog * .8, 0, .85))
        render.FogColor(45 + 85 * sun, 55 + 95 * sun, 75 + 100 * sun)
        return true
    end)

    hook.Add("RenderScreenspaceEffects", "GRM_Weather_Light", function()
        local sun = GetGlobalFloat("GRM_SunFactor", 1)
        local weather = GetGlobalString("GRM_Weather", "clear")
        local dark = 1 - sun
        local nightDarkness=math.Clamp(GetGlobalFloat("GRM_NightDarkness",.3),.2,.85)
        local brightnessLoss=Lerp(nightDarkness,.012,.060)
        local colorLoss=Lerp(nightDarkness,.08,.25)
        DrawColorModify({
            ["$pp_colour_addr"]=0, ["$pp_colour_addg"]=0, ["$pp_colour_addb"]=dark*.014,
            ["$pp_colour_brightness"]=-dark*brightnessLoss,
            ["$pp_colour_contrast"]=1+dark*.025,
            ["$pp_colour_colour"]=1-dark*colorLoss-(weather=="storm" and .08 or 0),
            ["$pp_colour_mulr"]=0, ["$pp_colour_mulg"]=0, ["$pp_colour_mulb"]=0,
        })
    end)

    -- Atmos-inspired world precipitation, adapted to GRM lifecycle.
    -- It checks sky per cached grid cell, so rain remains visible outside a
    -- window without tracing every particle every frame.
    local cvWeather=CreateClientConVar("grm_weather_effects","1",true,false,"World precipitation")
    local cvSplashes=CreateClientConVar("grm_weather_splashes","1",true,false,"Rain splashes")
    local emitter3D,emitter2D,nextDrop=nil,nil,0
    local skyCache={}
    local function pointOutside(pos)
        local key=math.floor(pos.x/256)..":"..math.floor(pos.y/256)..":"..math.floor(pos.z/256)
        local cached=skyCache[key];local now=RealTime()
        if cached and cached.untilTime>now then return cached.value end
        local tr=util.TraceLine({start=pos+Vector(0,0,6),endpos=pos+Vector(0,0,12000),mask=MASK_SOLID_BRUSHONLY})
        local value=not tr.StartSolid and(tr.HitSky or not tr.Hit)
        skyCache[key]={value=value,untilTime=now+1};return value
    end
    local function ensureEmitters(pos)
        emitter3D=emitter3D or ParticleEmitter(pos,true);emitter2D=emitter2D or ParticleEmitter(pos,false)
        if emitter3D then emitter3D:SetPos(pos)end;if emitter2D then emitter2D:SetPos(pos)end
        return emitter3D~=nil and emitter2D~=nil
    end
    local function rainSplash(pos,norm)
        if not cvSplashes:GetBool()or not emitter2D or norm.z<.35 or math.random(1,7)~=1 then return end
        local p=emitter2D:Add("atmos/warp_ripple3",pos+norm*.5);if not p then return end
        p:SetDieTime(.45);p:SetStartAlpha(135);p:SetEndAlpha(0);p:SetStartSize(3);p:SetEndSize(9);p:SetColor(210,225,240)
    end
    local function emitRain(storm)
        local ply=LocalPlayer();if not IsValid(ply)or not cvWeather:GetBool()then return end
        local center=ply:GetPos();if not ensureEmitters(center)then return end
        local wanted=storm and 15 or 9;local made=0;local attempts=0
        local wind=storm and Vector(-150,65,0)or Vector(-65,20,0)
        while made<wanted and attempts<wanted*3 do
            attempts=attempts+1
            local pos=center+Vector(math.Rand(-900,900),math.Rand(-900,900),math.Rand(260,720))
            if pointOutside(pos)then
                local p=emitter3D:Add("atmos/water_drop",pos)
                if p then
                    p:SetVelocity(Vector(0,0,storm and -1500 or -1100)+wind);p:SetDieTime(2);p:SetStartAlpha(storm and 220 or 180);p:SetEndAlpha(45);p:SetStartSize(storm and 3.2 or 2.5);p:SetEndSize(2);p:SetColor(215,230,245);p:SetCollide(true);p:SetBounce(0)
                    p:SetCollideCallback(function(part,hit,norm)rainSplash(hit,norm);part:SetDieTime(0)end);made=made+1
                end
                if emitter2D and math.random()<.18 then
                    local mist=emitter2D:Add("atmos/rainsmoke",pos)
                    if mist then mist:SetVelocity(Vector(0,0,-650)+wind*.3);mist:SetDieTime(1.3);mist:SetStartAlpha(storm and 8 or 4);mist:SetEndAlpha(0);mist:SetStartSize(90);mist:SetEndSize(145);mist:SetColor(135,145,170);mist:SetCollide(true);mist:SetCollideCallback(function(part)part:SetDieTime(0)end)end
                end
            end
        end
    end
    local function emitSnow()
        local ply=LocalPlayer();if not IsValid(ply)or not cvWeather:GetBool()then return end
        local center=ply:GetPos();if not ensureEmitters(center)then return end
        for _=1,7 do
            local pos=center+Vector(math.Rand(-850,850),math.Rand(-850,850),math.Rand(220,620))
            if pointOutside(pos)then local p=emitter2D:Add("atmos/snow",pos);if p then p:SetVelocity(Vector(math.Rand(10,35),math.Rand(5,28),math.Rand(-95,-65)));p:SetRoll(math.Rand(-180,180));p:SetDieTime(6);p:SetStartAlpha(190);p:SetEndAlpha(80);p:SetStartSize(math.Rand(1,2.2));p:SetEndSize(.8);p:SetColor(245,248,255);p:SetCollide(true);p:SetCollideCallback(function(part)part:SetDieTime(0)end)end end
        end
    end

    -- Source-engine sound patches are used instead of BASS file streams.
    -- They resolve mounted addon/download content and can fall back to built-in
    -- rain even when a client has not downloaded GRM WAV files yet.
    local audioDefs = {
        rain={path="atmos/rain.wav",fallback="ambient/weather/rain.wav",looped=true},
        storm={path="atmos/rain.wav",fallback="ambient/weather/rain.wav",looped=true},
        day={path="grm/weather/ambient_day_warm.wav",duration=36},
        evening={path="grm/weather/ambient_evening_warm.wav",duration=36},
        night={path="grm/weather/ambient_night_warm.wav",duration=36},
        noir={path="grm/weather/ambient_noir_city.wav",duration=36},
    }
    local patches, currentVolumes, startedAt, selectedWave, warned = {}, {}, {}, {}, {}
    local function ensurePatch(id)
        if patches[id] then return patches[id] end
        local def=audioDefs[id];if not def then return nil end
        local customExists=file.Exists("sound/"..def.path,"GAME")
        local wave=customExists and def.path or def.fallback
        if not wave then
            if not warned[id]then warned[id]=true;ErrorNoHalt("[GRM Weather] optional music missing: sound/"..def.path.."\n")end
            return nil
        end
        local name="GRM.Weather.Source."..id
        sound.Add({name=name,channel=CHAN_AUTO,volume=1,soundlevel=0,pitch=100,sound=wave})
        local ply=LocalPlayer();if not IsValid(ply)then return nil end
        local patch=CreateSound(ply,name)
        if not patch then return nil end
        patches[id]=patch;selectedWave[id]=wave;currentVolumes[id]=0;startedAt[id]=RealTime()
        patch:PlayEx(0,100)
        return patch
    end
    concommand.Add("grm_weather_audio_debug",function()
        print("[GRM Weather] Source audio diagnostics")
        for id,def in pairs(audioDefs)do print(id,"custom="..tostring(file.Exists("sound/"..def.path,"GAME")),"wave="..tostring(selectedWave[id]or def.fallback or"none"),"patch="..tostring(patches[id]~=nil),"playing="..tostring(patches[id]and patches[id]:IsPlaying()or false))end
    end)
    local thunderSounds={"atmos/thunder/thunder_1.mp3","atmos/thunder/thunder_2.mp3","atmos/thunder/thunder_3.mp3","atmos/thunder/thunder_far_away_1.mp3","atmos/thunder/thunder_far_away_2.mp3"}
    local activeThunder={}
    local function playThunder()
        for i=#activeThunder,1,-1 do if not activeThunder[i]:IsPlaying()then table.remove(activeThunder,i)end end
        if not cvAudio:GetBool()then return end;local ply=LocalPlayer();if not IsValid(ply)then return end
        local patch=CreateSound(ply,thunderSounds[math.random(#thunderSounds)]);if not patch then return end
        local volume=outside and .85 or(util.IsSkyboxVisibleFromPoint(ply:EyePos())and .38 or .16);patch:PlayEx(volume,math.random(92,103));activeThunder[#activeThunder+1]=patch
    end

    local function musicPeriod()
        local hour = W.TimeMinutes() / 60
        if hour >= 7 and hour < 18 then return "day" end
        if hour >= 18 and hour < 22 then return "evening" end
        return "night"
    end

    local function setAudioTargets()
        local enabled = cvAudio:GetBool()
        local musicEnabled = cvMusic:GetBool() and GetGlobalBool("GRM_WeatherMusic", true)
        local weather = GetGlobalString("GRM_Weather", "clear")
        local weatherVolume = GetGlobalFloat("GRM_WeatherSoundVolume", .48)
        local musicVolume = GetGlobalFloat("GRM_WeatherMusicVolume", .18)
        local period = musicPeriod()
        local theme = GetGlobalString("GRM_WeatherMusicTheme", "periods")
        local targets = { rain=0, storm=0, day=0, evening=0, night=0, noir=0 }
        if enabled then
            local ply=LocalPlayer();local skyVisible=IsValid(ply)and util.IsSkyboxVisibleFromPoint(ply:EyePos())
            local shelter=outside and 1 or skyVisible and .18 or .035
            if weather == "rain" then targets.rain = weatherVolume * shelter end
            if weather == "storm" then targets.storm = weatherVolume * shelter end
        end
        if musicEnabled then
            local track = theme == "periods" and period or "noir"
            targets[track] = musicVolume * (weather == "storm" and .45 or weather == "rain" and .7 or 1)
        end
        W._nextAudioMix=W._nextAudioMix or 0;if RealTime()<W._nextAudioMix then return end;W._nextAudioMix=RealTime()+.2
        for id,target in pairs(targets)do
            local patch=ensurePatch(id)
            if patch then
                currentVolumes[id]=Lerp(.18,currentVolumes[id]or 0,target)
                local def=audioDefs[id]
                if not patch:IsPlaying()or(not def.looped and selectedWave[id]==def.path and RealTime()-(startedAt[id]or 0)>=def.duration-.08)then
                    patch:Stop();patch:PlayEx(currentVolumes[id],100);startedAt[id]=RealTime()
                else patch:ChangeVolume(math.Clamp(currentVolumes[id],0,1),.22)end
            end
        end
    end

    hook.Add("Think", "GRM_Weather_Runtime", function()
        local now = RealTime()
        if now >= nextOutsideCheck then outside = isOutside(); nextOutsideCheck = now + .45 end
        local weather = GetGlobalString("GRM_Weather", "clear")
        if (weather=="rain"or weather=="storm")and now>=nextDrop then nextDrop=now+(weather=="storm"and .035 or .055);emitRain(weather=="storm")
        elseif weather=="snow"and now>=nextDrop then nextDrop=now+.08;emitSnow()end
        if weather=="storm"and now>=nextThunder then nextThunder=now+math.Rand(15,60);lightning=now+.16;playThunder()end
        setAudioTargets()
    end)

    hook.Add("HUDPaint", "GRM_Weather_Lightning", function()
        if lightning > RealTime() then
            surface.SetDrawColor(220, 230, 255, 70)
            surface.DrawRect(0, 0, ScrW(), ScrH())
        end
    end)

    hook.Add("HUDPaint", "GRM_Weather_Clock", function()
        if not GetGlobalBool("GRM_WeatherHUD", true) then return end
        local weather = GetGlobalString("GRM_Weather", "clear")
        local name = (W.Types[weather] or W.Types.clear).name
        local x = ScrW() - 34
        draw.SimpleText(W.FormatTime(), "GRMClock", x, 30, Color(240,243,248), TEXT_ALIGN_RIGHT)
        draw.SimpleText(W.Period().." • "..name, "GRMWeather", x, 52, Color(170,180,195), TEXT_ALIGN_RIGHT)
    end)

    hook.Add("ShutDown", "GRM_Weather_AudioStop", function()
        for _,patch in pairs(patches)do if patch then patch:Stop()end end;for _,patch in ipairs(activeThunder)do if patch then patch:Stop()end end
        if emitter3D then emitter3D:Finish();emitter3D=nil end;if emitter2D then emitter2D:Finish();emitter2D=nil end
    end)

    net.Receive(OPEN, function()
        local cfg, tm, weather = net.ReadTable() or {}, net.ReadFloat(), net.ReadString()
        if IsValid(W._frame) then W._frame:Remove() end
        local f=vgui.Create("DFrame"); W._frame=f; f:SetSize(760,820); f:Center(); f:MakePopup(); f:SetTitle("Погода, время и атмосфера GRM")
        if GRM.UI then GRM.UI.Track("weather.admin",f) end
        local y=44
        local function slider(name,min,max,val,decimals)
            local s=vgui.Create("DNumSlider",f);s:SetPos(18,y);s:SetSize(724,42);s:SetText(name);s:SetMin(min);s:SetMax(max);s:SetDecimals(decimals or 0);s:SetValue(val);y=y+46;return s
        end
        local day=slider("Длительность суток, реальные минуты",10,1440,cfg.dayLengthMinutes)
        local hour=slider("Текущее время, час",0,23,tm/60)
        local nightDarkness=slider("Глубина ночного тона (не меняет освещение карты)",.2,.85,cfg.nightDarkness or .3,2)
        local weatherBox=vgui.Create("DComboBox",f);weatherBox:SetPos(18,y);weatherBox:SetSize(724,36)
        for id,row in pairs(W.Types) do weatherBox:AddChoice(row.name,id,id==weather) end;y=y+46
        local random=vgui.Create("DCheckBoxLabel",f);random:SetPos(18,y);random:SetText("Случайная смена погоды");random:SetValue(cfg.randomWeather and 1 or 0);random:SizeToContents();y=y+30
        local snow=vgui.Create("DCheckBoxLabel",f);snow:SetPos(18,y);snow:SetText("Разрешить снег в случайном цикле");snow:SetValue(cfg.snowEnabled~=false and 1 or 0);snow:SizeToContents();y=y+30
        local painted=vgui.Create("DCheckBoxLabel",f);painted:SetPos(18,y);painted:SetText("Использовать painted sky (рекомендуется для смены неба)");painted:SetValue(cfg.forcePaintedSky~=false and 1 or 0);painted:SizeToContents();y=y+34
        local mn=slider("Минимальная длительность погоды, мин",2,240,cfg.weatherMinMinutes)
        local mx=slider("Максимальная длительность погоды, мин",2,480,cfg.weatherMaxMinutes)
        local soundVolume=slider("Громкость дождя и грозы",0,1,cfg.soundVolume or .48,2)
        local musicVolume=slider("Громкость музыкального эмбиента",0,1,cfg.musicVolume or .18,2)
        local theme=vgui.Create("DComboBox",f);theme:SetPos(18,y);theme:SetSize(724,36);theme:AddChoice("Тёплый живой город — день / вечер / ночь","periods",cfg.musicTheme~="noir");theme:AddChoice("Городской детектив — спокойное движение","noir",cfg.musicTheme=="noir");y=y+46
        local music=vgui.Create("DCheckBoxLabel",f);music:SetPos(18,y);music:SetText("Музыкальный эмбиент");music:SetValue(cfg.musicEnabled~=false and 1 or 0);music:SizeToContents();y=y+30
        local hud=vgui.Create("DCheckBoxLabel",f);hud:SetPos(18,y);hud:SetText("Показывать часы и погоду на HUD");hud:SetValue(cfg.hudClock~=false and 1 or 0);hud:SizeToContents()
        local b=vgui.Create("DButton",f);b:SetPos(18,755);b:SetSize(724,44);b:SetText("СОХРАНИТЬ И ПРИМЕНИТЬ")
        b.DoClick=function()
            local _,wid=weatherBox:GetSelected()
            local _,themeID=theme:GetSelected();net.Start(SAVE);net.WriteTable({dayLengthMinutes=day:GetValue(),hour=hour:GetValue(),weather=wid or weather,randomWeather=random:GetChecked(),weatherMinMinutes=mn:GetValue(),weatherMaxMinutes=mx:GetValue(),hudClock=hud:GetChecked(),soundVolume=soundVolume:GetValue(),musicVolume=musicVolume:GetValue(),musicEnabled=music:GetChecked(),musicTheme=themeID or"periods",nightDarkness=nightDarkness:GetValue(),snowEnabled=snow:GetChecked(),forcePaintedSky=painted:GetChecked()});net.SendToServer()
        end
    end)
end
