-- GRM Faction Roster v1.0 — /members и /leaders
if SERVER then AddCSLuaFile() end
GRM=GRM or{};GRM.FactionRoster=GRM.FactionRoster or{};local R=GRM.FactionRoster
local function key(p)return GRM.Identity and GRM.Identity.CharacterKey and GRM.Identity.CharacterKey(p)or p:SteamID64()end
local function resolve(k)return GRM.Identity and GRM.Identity.ResolveCharacter and GRM.Identity.ResolveCharacter(k)or nil end
local function nameOf(k,rec)local p=resolve(k);if IsValid(p)then local n=p:GetNWString("GRM_RPName","");return n~=""and n or p:Nick()end;local a,s=tostring(k):match("^(.-):(char[1-3])$");local c=a and GRM.Char and GRM.Char.Data and GRM.Char.Data[a];c=c and c.slots and c.slots[s];return c and c.name or rec and(rec.Name or rec.name)or tostring(k)end
local function factionOf(p)for n,f in pairs(Factions or{})do if GRM.Identity and GRM.Identity.FactionMember and GRM.Identity.FactionMember(f,p)then return n,f end end end
local function duty(k,p)local saved=GRM.FactionDuty and GRM.FactionDuty.State and GRM.FactionDuty.State[k];if IsValid(p)then return GRM.FactionDuty and GRM.FactionDuty.IsOnDuty and GRM.FactionDuty.IsOnDuty(p)and"НА СЛУЖБЕ"or"ВНЕ СЛУЖБЫ"end;return saved==false and"ВЫХОДНОЙ"or"НЕ В СЕТИ"end
function R.PrintMembers(ply,fname)
 local own,f=factionOf(ply);fname=string.Trim(tostring(fname or""));if fname==""then fname,f=own,f end;if not f then f=Factions and Factions[fname]end
 if not f or(fname~=own and not ply:IsSuperAdmin())then ply:ChatPrint("[Состав] Нет доступа или фракция не найдена.")return end
 ply:ChatPrint("=== СОСТАВ: "..fname.." ===")
 local rows={};for k,r in pairs(f.Members or{})do rows[#rows+1]={k=k,r=r,p=resolve(k)}end;table.sort(rows,function(a,b)return nameOf(a.k,a.r)<nameOf(b.k,b.r)end)
 for _,v in ipairs(rows)do local loc=IsValid(v.p)and string.format("%.0f %.0f %.0f",v.p:GetPos().x,v.p:GetPos().y,v.p:GetPos().z)or"—";ply:ChatPrint(('%s • %s • %s • %s • %s'):format(nameOf(v.k,v.r),tostring(v.r.Role or"Участник"),tostring(v.r.Department or"—"),duty(v.k,v.p),loc))end
 ply:ChatPrint("Всего: "..#rows)
end
function R.PrintLeaders(ply)
 ply:ChatPrint("=== ЛИДЕРЫ ФРАКЦИЙ ===")
 local names={};for n in pairs(Factions or{})do names[#names+1]=n end;table.sort(names)
 for _,n in ipairs(names)do local f=Factions[n];local k=tostring(f.Leader or"");local p=k~=""and resolve(k)or nil;ply:ChatPrint(('%s — %s [%s]'):format(n,k~=""and nameOf(k,f.Members and f.Members[k])or"НЕ НАЗНАЧЕН",IsValid(p)and"В СЕТИ"or"НЕ В СЕТИ"))end
end
if SERVER then
 local function cmd(p,t)local raw=string.Trim(tostring(t or""));local low=string.lower(raw);if low=="/members"or low=="/состав"or low:sub(1,9)=="/members "then R.PrintMembers(p,string.Trim(raw:sub(9)));return true elseif low=="/leaders"or low=="/лидеры"then R.PrintLeaders(p);return true end return false end
 hook.Add("PlayerSayTransform","GRM_Roster_Transform",function(p,d)if istable(d)and isstring(d[1])and cmd(p,d[1])then d[1]="";d.SkipPlayerSay=true end end)
 hook.Add("PlayerSay","GRM_Roster_Chat",function(p,t)if cmd(p,t)then return""end end)
 timer.Create("GRM_Roster_LiveSync",10,0,function()if isfunction(broadcastFactionData)then broadcastFactionData()end end)
end
