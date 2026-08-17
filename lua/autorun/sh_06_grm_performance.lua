-- GRM shared performance helpers: event-driven entity registries and change-only NW writes.
if SERVER then AddCSLuaFile()end
GRM=GRM or{};GRM.Perf=GRM.Perf or{};local P=GRM.Perf
P.Version="1.0.0";P._classes=P._classes or{};P._throttle=P._throttle or{}
function P.Throttle(key,interval,now)now=tonumber(now)or CurTime();local at=tonumber(P._throttle[key])or 0;if at>now then return false end;P._throttle[key]=now+math.max(0,tonumber(interval)or 0);return true end
local function bucket(class)
 class=tostring(class or"");if class==""then return nil end;local b=P._classes[class];if b then return b end;b={set=setmetatable({},{__mode="k"}),array={},dirty=true};P._classes[class]=b
 for _,ent in ipairs(ents.FindByClass(class))do if IsValid(ent)then b.set[ent]=true end end;return b
end
function P.WatchClass(class)return bucket(class)~=nil end
function P.Entities(class)
 local b=bucket(class);if not b then return{}end;if not b.dirty then return b.array end;local out={};for ent in pairs(b.set)do if IsValid(ent)then out[#out+1]=ent else b.set[ent]=nil end end;b.array=out;b.dirty=false;return out
end
function P.ForEach(class,fn)if not isfunction(fn)then return 0 end;local n=0;local b=bucket(class);if not b then return n end;for ent in pairs(b.set)do if IsValid(ent)then n=n+1;fn(ent)else b.set[ent]=nil end end;return n end
hook.Add("OnEntityCreated","GRM_Perf_EntityCreated",function(ent)timer.Simple(0,function()if not IsValid(ent)then return end;local b=P._classes[ent:GetClass()];if b then b.set[ent]=true;b.dirty=true end end)end)
hook.Add("EntityRemoved","GRM_Perf_EntityRemoved",function(ent)local b=P._classes[ent:GetClass()];if b then b.set[ent]=nil;b.dirty=true end end)
function P.NWString(ent,key,value,default)value=tostring(value or"");if ent:GetNWString(key,default or"")~=value then ent:SetNWString(key,value)return true end;return false end
function P.NWInt(ent,key,value,default)value=math.floor(tonumber(value)or 0);if ent:GetNWInt(key,default or-2147483648)~=value then ent:SetNWInt(key,value)return true end;return false end
function P.NWBool(ent,key,value,default)value=value==true;if ent:GetNWBool(key,default==true)~=value then ent:SetNWBool(key,value)return true end;return false end
function P.NWFloat(ent,key,value,epsilon)value=tonumber(value)or 0;if math.abs(ent:GetNWFloat(key,-1e30)-value)>(tonumber(epsilon)or.001)then ent:SetNWFloat(key,value)return true end;return false end
print("[GRM Perf] event registries + change-only NW loaded")
