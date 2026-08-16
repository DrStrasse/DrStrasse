--[[ GRM Weather & Time v1.0.0: authoritative clock, day/night, fog and sky. ]]
if SERVER then AddCSLuaFile()end
GRM=GRM or{};GRM.Weather=GRM.Weather or{};local W=GRM.Weather
W.Version="1.1.1";W.Types={clear={name="Ясно",fog=.08},cloudy={name="Облачно",fog=.22},fog={name="Туман",fog=.72},rain={name="Дождь",fog=.38},storm={name="Гроза",fog=.55}}
W.Config=W.Config or{dayLengthMinutes=90,randomWeather=true,weatherMinMinutes=12,weatherMaxMinutes=28,startHour=8,hudClock=true,soundVolume=.65,musicVolume=.18,musicEnabled=true,musicTheme="noir",nightDarkness=.4}
local OPEN="GRM_Weather_Admin";local SAVE="GRM_Weather_Save"
if GRM.Access and GRM.Access.Register then GRM.Access.Register("weather.manage",{label="Погода и время: управление",scope="account"})end
function W.CanAdmin(p)return IsValid(p)and(p:IsSuperAdmin()or(GRM.Access and GRM.Access.Can and GRM.Access.Can(p,"weather.manage")==true))end
function W.TimeMinutes()return GetGlobalFloat("GRM_TimeMinutes",W.Config.startHour*60)%1440 end
function W.FormatTime(minutes)minutes=math.floor(tonumber(minutes)or W.TimeMinutes())%1440;return string.format("%02d:%02d",math.floor(minutes/60),minutes%60)end
function W.Period(minutes)local h=(tonumber(minutes)or W.TimeMinutes())/60;if h<5 then return"Ночь"elseif h<8 then return"Утро"elseif h<18 then return"День"elseif h<22 then return"Вечер"else return"Ночь"end end
function W.SunFactor(minutes)local h=(tonumber(minutes)or W.TimeMinutes())/60;local x=math.sin(((h-6)/12)*math.pi);return math.Clamp(x,0,1)end
if SERVER then
 util.AddNetworkString(OPEN);util.AddNetworkString(SAVE);local FILE="grm_weather/config.json"
 local AUDIO_RESOURCES={"ambient_day.wav","ambient_evening.wav","ambient_night.wav","ambient_noir.wav","rain_loop.wav","storm_loop.wav"}
 for _,name in ipairs(AUDIO_RESOURCES)do resource.AddFile("sound/grm/weather/"..name)end
 local function load()local d=GRM.Persistence.LoadJSON(FILE,{version=1,config=W.Config,state={time=W.Config.startHour*60,weather="clear"}});if istable(d.config)then for k,v in pairs(d.config)do W.Config[k]=v end end;W._time=tonumber(d.state and d.state.time)or W.Config.startHour*60;W._weather=W.Types[d.state and d.state.weather]and d.state.weather or"clear"end
 local function save()return GRM.Persistence.SaveJSON(FILE,{version=1,config=W.Config,state={time=W._time,weather=W._weather}},{version=1})end
 load();SetGlobalFloat("GRM_TimeMinutes",W._time);SetGlobalString("GRM_Weather",W._weather);if GRM.Perm and GRM.Perm.RegisterClass then GRM.Perm.RegisterClass("grm_clock",true)end;if GRM.PermData and GRM.PermData.AddExtract then GRM.PermData.AddExtract("grm_clock",function(e)return{clockName=e:GetClockName()}end);GRM.PermData.AddApply("grm_clock",function(e,d)if d.clockName then e:SetClockName(string.Trim(tostring(d.clockName)):sub(1,64))end end)end
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
 local lastLightStyle
 local function applyWorldLight(sun)
  if not (engine and engine.LightStyle) then return end
  local darkness=math.Clamp(tonumber(W.Config.nightDarkness)or.4,.2,.85);local nightStyle=darkness>=.68 and"f"or darkness>=.48 and"g"or darkness>=.3 and"h"or"i";local style=sun<.03 and nightStyle or sun<.12 and"h"or sun<.30 and"j"or sun<.60 and"l"or"m"
  if style ~= lastLightStyle then engine.LightStyle(0, style); lastLightStyle = style end
 end
 local function applySky()
  local e=skyPaint();if not IsValid(e)or not isfunction(e.SetTopColor)then return end
  local hour=W._time/60;local sun=W.SunFactor(W._time);local preset=timePreset(hour);local weather=W._weather
  local weatherBlend=weather=="storm"and 1 or weather=="rain"and .62 or weather=="cloudy"and .38 or weather=="fog"and .18 or 0
  if weatherBlend>0 then local storm=sun<.15 and SKYPAINT.storm_night or SKYPAINT.storm;preset=blendPreset(preset,storm,weatherBlend)end
  local elevation=math.sin(math.rad((hour-6)*15));local azimuth=(hour/24)*360+90
  if isfunction(e.SetSunNormal)then e:SetSunNormal(Angle(-elevation*78,azimuth,0):Forward())end
  e:SetTopColor(preset.TopColor);e:SetBottomColor(preset.BottomColor)
  if isfunction(e.SetFadeBias)then e:SetFadeBias(preset.FadeBias)end
  if isfunction(e.SetHDRScale)then e:SetHDRScale(preset.HDRScale)end
  e:SetStarScale(preset.StarScale);e:SetStarFade(preset.StarFade);e:SetStarSpeed(preset.StarSpeed)
  e:SetDuskScale(preset.DuskScale);e:SetDuskIntensity(preset.DuskIntensity);e:SetDuskColor(preset.DuskColor)
  e:SetSunColor(preset.SunColor);e:SetSunSize(preset.SunSize)
  applyWorldLight(sun)
 end
 local function sync()SetGlobalFloat("GRM_TimeMinutes",W._time);SetGlobalString("GRM_Weather",W._weather);SetGlobalFloat("GRM_SunFactor",W.SunFactor(W._time));SetGlobalBool("GRM_WeatherHUD",W.Config.hudClock~=false);SetGlobalFloat("GRM_WeatherSoundVolume",math.Clamp(tonumber(W.Config.soundVolume)or.65,0,1));SetGlobalFloat("GRM_WeatherMusicVolume",math.Clamp(tonumber(W.Config.musicVolume)or.18,0,1));SetGlobalBool("GRM_WeatherMusic",W.Config.musicEnabled~=false);SetGlobalString("GRM_WeatherMusicTheme",W.Config.musicTheme=="periods"and"periods"or"noir");SetGlobalFloat("GRM_NightDarkness",math.Clamp(tonumber(W.Config.nightDarkness)or.4,.2,.85))end
 local function nextWeather()if not W.Config.randomWeather then return end;local ids={"clear","clear","cloudy","fog","rain","storm"};W._weather=ids[math.random(#ids)];W._weatherUntil=CurTime()+math.random(W.Config.weatherMinMinutes*60,W.Config.weatherMaxMinutes*60);sync();save();if GRM.Audit then GRM.Audit.Write("weather","weather.change",nil,{}, {weather=W._weather})end end
 W._weatherUntil=CurTime()+math.random(W.Config.weatherMinMinutes*60,W.Config.weatherMaxMinutes*60)
 timer.Create("GRM_Weather_Clock",1,0,function()W._time=(W._time+1440/math.max(600,(tonumber(W.Config.dayLengthMinutes)or 90)*60))%1440;if CurTime()>=W._weatherUntil then nextWeather()end;sync()end);timer.Create("GRM_Weather_SunMotion",5,0,applySky);timer.Simple(1,applySky);timer.Create("GRM_Weather_Autosave",120,0,save)
 hook.Add("InitPostEntity","GRM_Weather_Sky",function()timer.Simple(2,applySky)end);hook.Add("ShutDown","GRM_Weather_Save",save)
 local function adminData(p)if not W.CanAdmin(p)then return end;net.Start(OPEN);net.WriteTable(W.Config);net.WriteFloat(W._time);net.WriteString(W._weather);net.Send(p)end
 net.Receive(SAVE,function(bits,p)if not W.CanAdmin(p)then return end;if GRM.Net and not GRM.Net.Guard(p,"weather.admin.save",{rate=.5,burst=2,maxBits=65536},{bits=bits})then return end;local d=net.ReadTable()or{};W.Config.dayLengthMinutes=math.Clamp(tonumber(d.dayLengthMinutes)or 90,10,1440);W.Config.randomWeather=d.randomWeather~=false;W.Config.weatherMinMinutes=math.Clamp(math.floor(tonumber(d.weatherMinMinutes)or 12),2,240);W.Config.weatherMaxMinutes=math.Clamp(math.floor(tonumber(d.weatherMaxMinutes)or 28),W.Config.weatherMinMinutes,480);W.Config.hudClock=d.hudClock~=false;W.Config.soundVolume=math.Clamp(tonumber(d.soundVolume)or.65,0,1);W.Config.musicVolume=math.Clamp(tonumber(d.musicVolume)or.18,0,1);W.Config.musicEnabled=d.musicEnabled~=false;W.Config.musicTheme=d.musicTheme=="periods"and"periods"or"noir";W.Config.nightDarkness=math.Clamp(tonumber(d.nightDarkness)or.4,.2,.85);local hour=tonumber(d.hour);if hour then W._time=(hour%24)*60 end;if W.Types[d.weather]then W._weather=d.weather;W._weatherUntil=CurTime()+W.Config.weatherMaxMinutes*60 end;save();sync();applySky();if GRM.Audit then GRM.Audit.Write("weather","admin.save",p,{},d)end;adminData(p)end)
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
        local nightDarkness=math.Clamp(GetGlobalFloat("GRM_NightDarkness",.4),.2,.85)
        local brightnessLoss=Lerp(nightDarkness,.035,.11)
        local colorLoss=Lerp(nightDarkness,.16,.36)
        DrawColorModify({
            ["$pp_colour_addr"]=0, ["$pp_colour_addg"]=0, ["$pp_colour_addb"]=dark*.008,
            ["$pp_colour_brightness"]=-dark*brightnessLoss,
            ["$pp_colour_contrast"]=1+dark*.025,
            ["$pp_colour_colour"]=1-dark*colorLoss-(weather=="storm" and .08 or 0),
            ["$pp_colour_mulr"]=0, ["$pp_colour_mulg"]=0, ["$pp_colour_mulb"]=0,
        })
    end)

    -- World-space precipitation. No screen-space diagonal overlay: drops exist
    -- around the player, move with wind and are only emitted under open sky.
    local emitter, nextDrop = nil, 0
    local rainMat = "effects/spark"
    local function emitRain(storm)
        local ply = LocalPlayer()
        if not IsValid(ply) then return end
        emitter = emitter or ParticleEmitter(ply:GetPos(), false)
        if not emitter then return end
        emitter:SetPos(ply:GetPos())
        local count = storm and 13 or 8
        local wind = storm and Vector(-180, 70, 0) or Vector(-80, 25, 0)
        for _=1,count do
            local origin = ply:GetPos() + Vector(math.Rand(-900,900), math.Rand(-900,900), math.Rand(450,950))
            local particle = emitter:Add(rainMat, origin)
            if particle then
                particle:SetVelocity(Vector(0,0,storm and -2100 or -1650) + wind)
                particle:SetDieTime(storm and .72 or .9)
                particle:SetStartAlpha(storm and 150 or 105)
                particle:SetEndAlpha(10)
                particle:SetStartSize(storm and .7 or .45)
                particle:SetEndSize(.15)
                if particle.SetStartLength then particle:SetStartLength(storm and 75 or 55) end
                if particle.SetEndLength then particle:SetEndLength(storm and 38 or 25) end
                particle:SetColor(180, 205, 225)
                particle:SetGravity(Vector(0,0,-500))
                particle:SetAirResistance(2)
                particle:SetCollide(true)
                particle:SetBounce(.02)
            end
        end
    end

    -- Original GRM audio: separate weather beds and musical day periods.
    local audioFiles = {
        rain="sound/grm/weather/rain_loop.wav",
        storm="sound/grm/weather/storm_loop.wav",
        day="sound/grm/weather/ambient_day.wav",
        evening="sound/grm/weather/ambient_evening.wav",
        night="sound/grm/weather/ambient_night.wav",
        noir="sound/grm/weather/ambient_noir.wav",
    }
    local channels, loading, currentVolumes, retryAt, warned = {}, {}, {}, {}, {}
    local function loadChannel(id)
        if IsValid(channels[id]) or loading[id] or (retryAt[id] or 0) > RealTime() then return end
        channels[id] = nil
        local path = audioFiles[id]
        if not file.Exists(path, "GAME") then
            retryAt[id] = RealTime() + 30
            if not warned[id] then
                warned[id] = true
                ErrorNoHalt("[GRM Weather] audio file missing: "..path..". Reconnect after server content download.\n")
            end
            return
        end
        loading[id] = true
        sound.PlayFile(path, "noplay noblock", function(channel, errCode, errName)
            loading[id] = nil
            if not IsValid(channel) then
                retryAt[id] = RealTime() + 30
                if not warned[id] then
                    warned[id] = true
                    ErrorNoHalt("[GRM Weather] audio "..id.." failed: "..tostring(errCode).." "..tostring(errName).."\n")
                end
                return
            end
            warned[id], retryAt[id] = nil, nil
            channels[id] = channel
            currentVolumes[id] = 0
            channel:EnableLooping(true)
            channel:SetVolume(0)
            channel:Play()
        end)
    end
    for id in pairs(audioFiles) do loadChannel(id) end
    concommand.Add("grm_weather_audio_debug",function()
        print("[GRM Weather] audio diagnostics")
        for id,path in pairs(audioFiles)do print(id,path,"exists="..tostring(file.Exists(path,"GAME")),"channel="..tostring(IsValid(channels[id])))end
    end)

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
        local weatherVolume = GetGlobalFloat("GRM_WeatherSoundVolume", .65)
        local musicVolume = GetGlobalFloat("GRM_WeatherMusicVolume", .18)
        local period = musicPeriod()
        local theme = GetGlobalString("GRM_WeatherMusicTheme", "noir")
        local targets = { rain=0, storm=0, day=0, evening=0, night=0, noir=0 }
        if enabled then
            local shelter = outside and 1 or .12
            if weather == "rain" then targets.rain = weatherVolume * shelter end
            if weather == "storm" then targets.storm = weatherVolume * shelter end
        end
        if musicEnabled then
            local track = theme == "periods" and period or "noir"
            targets[track] = musicVolume * (weather == "storm" and .45 or weather == "rain" and .7 or 1)
        end
        for id, target in pairs(targets) do
            loadChannel(id)
            local ch = channels[id]
            if IsValid(ch) then
                currentVolumes[id] = Lerp(FrameTime() * .35, currentVolumes[id] or 0, target)
                ch:SetVolume(math.Clamp(currentVolumes[id], 0, 1))
            end
        end
    end

    hook.Add("Think", "GRM_Weather_Runtime", function()
        local now = RealTime()
        if now >= nextOutsideCheck then outside = isOutside(); nextOutsideCheck = now + .45 end
        local weather = GetGlobalString("GRM_Weather", "clear")
        if outside and (weather == "rain" or weather == "storm") and now >= nextDrop then
            nextDrop = now + (weather == "storm" and .025 or .04)
            emitRain(weather == "storm")
        end
        if weather == "storm" and now >= nextThunder then
            nextThunder = now + math.Rand(12, 32)
            lightning = now + .16
            if cvAudio:GetBool() then surface.PlaySound("ambient/atmosphere/thunder1.wav") end
        end
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
        for _, channel in pairs(channels) do if IsValid(channel) then channel:Stop() end end
        if emitter then emitter:Finish(); emitter=nil end
    end)

    net.Receive(OPEN, function()
        local cfg, tm, weather = net.ReadTable() or {}, net.ReadFloat(), net.ReadString()
        if IsValid(W._frame) then W._frame:Remove() end
        local f=vgui.Create("DFrame"); W._frame=f; f:SetSize(760,720); f:Center(); f:MakePopup(); f:SetTitle("Погода, время и атмосфера GRM")
        if GRM.UI then GRM.UI.Track("weather.admin",f) end
        local y=44
        local function slider(name,min,max,val,decimals)
            local s=vgui.Create("DNumSlider",f);s:SetPos(18,y);s:SetSize(724,42);s:SetText(name);s:SetMin(min);s:SetMax(max);s:SetDecimals(decimals or 0);s:SetValue(val);y=y+46;return s
        end
        local day=slider("Длительность суток, реальные минуты",10,1440,cfg.dayLengthMinutes)
        local hour=slider("Текущее время, час",0,23,tm/60)
        local nightDarkness=slider("Темнота ночи (0.2 светлее — 0.85 темнее)",.2,.85,cfg.nightDarkness or .4,2)
        local weatherBox=vgui.Create("DComboBox",f);weatherBox:SetPos(18,y);weatherBox:SetSize(724,36)
        for id,row in pairs(W.Types) do weatherBox:AddChoice(row.name,id,id==weather) end;y=y+46
        local random=vgui.Create("DCheckBoxLabel",f);random:SetPos(18,y);random:SetText("Случайная смена погоды");random:SetValue(cfg.randomWeather and 1 or 0);random:SizeToContents();y=y+34
        local mn=slider("Минимальная длительность погоды, мин",2,240,cfg.weatherMinMinutes)
        local mx=slider("Максимальная длительность погоды, мин",2,480,cfg.weatherMaxMinutes)
        local soundVolume=slider("Громкость дождя и грозы",0,1,cfg.soundVolume or .65,2)
        local musicVolume=slider("Громкость музыкального эмбиента",0,1,cfg.musicVolume or .18,2)
        local theme=vgui.Create("DComboBox",f);theme:SetPos(18,y);theme:SetSize(724,36);theme:AddChoice("Нуарный детектив — неспешное движение","noir",cfg.musicTheme~="periods");theme:AddChoice("Разные эмбиенты по времени суток","periods",cfg.musicTheme=="periods");y=y+46
        local music=vgui.Create("DCheckBoxLabel",f);music:SetPos(18,y);music:SetText("Музыкальный эмбиент");music:SetValue(cfg.musicEnabled~=false and 1 or 0);music:SizeToContents();y=y+30
        local hud=vgui.Create("DCheckBoxLabel",f);hud:SetPos(18,y);hud:SetText("Показывать часы и погоду на HUD");hud:SetValue(cfg.hudClock~=false and 1 or 0);hud:SizeToContents()
        local b=vgui.Create("DButton",f);b:SetPos(18,655);b:SetSize(724,44);b:SetText("СОХРАНИТЬ И ПРИМЕНИТЬ")
        b.DoClick=function()
            local _,wid=weatherBox:GetSelected()
            local _,themeID=theme:GetSelected();net.Start(SAVE);net.WriteTable({dayLengthMinutes=day:GetValue(),hour=hour:GetValue(),weather=wid or weather,randomWeather=random:GetChecked(),weatherMinMinutes=mn:GetValue(),weatherMaxMinutes=mx:GetValue(),hudClock=hud:GetChecked(),soundVolume=soundVolume:GetValue(),musicVolume=musicVolume:GetValue(),musicEnabled=music:GetChecked(),musicTheme=themeID or"noir",nightDarkness=nightDarkness:GetValue()});net.SendToServer()
        end
    end)
end
