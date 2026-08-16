--[[ GRM Real Time v1.0.0 — authoritative wall clock only; no weather/lighting. ]]
if SERVER then AddCSLuaFile() end
GRM=GRM or{};GRM.Time=GRM.Time or{};local T=GRM.Time
T.Version="1.0.0";T.DefaultOffsetMinutes=180
function T.FormatOffset(timestamp,offsetMinutes)
 local shifted=(tonumber(timestamp)or os.time())+(tonumber(offsetMinutes)or T.DefaultOffsetMinutes)*60
 local row=os.date("!*t",shifted);return string.format("%02d:%02d:%02d",row.hour,row.min,row.sec)
end
function T.GetString()return GetGlobalString and GetGlobalString("GRM_RealTime","--:--:--")or"--:--:--"end
if SERVER then
 local offset=CreateConVar("grm_time_utc_offset_minutes",tostring(T.DefaultOffsetMinutes),bit.bor(FCVAR_ARCHIVE,FCVAR_REPLICATED),"GRM wall-clock UTC offset in minutes")
 local function sync()SetGlobalString("GRM_RealTime",T.FormatOffset(os.time(),math.Clamp(offset:GetInt(),-720,840)));SetGlobalInt("GRM_RealTimeEpoch",os.time())end
 sync();timer.Create("GRM_RealTime_Sync",1,0,sync)
 local function tell(p)if IsValid(p)then p:ChatPrint("[Время] "..T.FormatOffset(os.time(),math.Clamp(offset:GetInt(),-720,840)))end end
 concommand.Add("grm_time",tell)
 hook.Add("PlayerSay","GRM_RealTime_Chat",function(p,text)local s=string.lower(string.Trim(tostring(text or"")));if s=="/time"or s=="/время"then tell(p)return""end end)
 hook.Add("PlayerSayTransform","GRM_RealTime_EasyChat",function(p,text,pack)pack=istable(text)and text or pack;local raw=istable(text)and text[1]or text;local s=string.lower(string.Trim(tostring(raw or"")));if s~="/time"and s~="/время"then return end;tell(p);if istable(pack)then pack.SkipPlayerSay=true;pack[1]=""end end)
 print("[GRM Time] real clock v"..T.Version.." loaded, UTC offset "..offset:GetInt().." min")
end
