--[[ GRM Quest Ecosystem v1.0.0 — authoritative quests, NPCs, objectives and persistence ]]
if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("autorun/client/cl_grm_quests.lua")
end

GRM = GRM or {}
GRM.Quests = GRM.Quests or {}
local Q = GRM.Quests
Q.Version = "1.4.0"
Q.Definitions = Q.Definitions or {}
Q.Progress = Q.Progress or {}
Q.NPCs = Q.NPCs or {}
Q.EventTypes = {
    generic="Событие", mining="Добыча руды", factory_produce="Производство",
    inventory_gain="Получение предмета", visit="Посещение", talk="Разговор",
}

local function trim(value, limit)
    value = string.Trim(tostring(value or ""))
    return string.sub(value, 1, limit or 128)
end
local function characterKey(ply)
    if GRM.Identity and GRM.Identity.CharacterKey then return GRM.Identity.CharacterKey(ply) end
    if GRM.Char and GRM.Char.GetActiveKey then return GRM.Char.GetActiveKey(ply) end
    return tostring(ply:SteamID64()) .. ":char1"
end
Q.CharacterKey = characterKey

if SERVER then
    util.AddNetworkString("GRM_Quest_OpenNPC")
    util.AddNetworkString("GRM_Quest_PlayerOp")
    util.AddNetworkString("GRM_Quest_Sync")
    util.AddNetworkString("GRM_Quest_Notice")
    util.AddNetworkString("GRM_Quest_Cutscene")
    util.AddNetworkString("GRM_Quest_CutscenePreview")
    util.AddNetworkString("GRM_Quest_CutsceneStop")
    util.AddNetworkString("GRM_Quest_AdminOpen")
    util.AddNetworkString("GRM_Quest_AdminOp")
    util.AddNetworkString("GRM_Quest_Journal")

    Q.DataDir = "grm_quests"
    Q.DefFile = Q.DataDir .. "/" .. string.lower(game.GetMap() or "unknown") .. ".json"
    Q.ProgressFile = Q.DataDir .. "/progress.json"

    local function ensureDir() if not file.IsDir(Q.DataDir, "DATA") then file.CreateDir(Q.DataDir) end end
    local function readJSON(path)
        if not file.Exists(path, "DATA") then return nil end
        local ok, parsed = pcall(util.JSONToTable, file.Read(path, "DATA") or "", false, true)
        return ok and istable(parsed) and parsed or nil
    end
    local function writeJSON(path, value)
        ensureDir()
        local ok, raw = pcall(util.TableToJSON, value, true)
        if not ok or not isstring(raw) or raw == "" then return false end
        local old = file.Exists(path, "DATA") and file.Read(path, "DATA") or nil
        if isstring(old) and old ~= "" then file.Write(path .. ".backup", old) end
        file.Write(path, raw)
        if file.Read(path, "DATA") ~= raw then return false end
        return istable(readJSON(path))
    end

    local function vectorData(value)
        if isvector(value) then return {x=value.x,y=value.y,z=value.z} end
        value = istable(value) and value or {}
        return {x=tonumber(value.x) or 0,y=tonumber(value.y) or 0,z=tonumber(value.z) or 0}
    end
    local function angleData(value)
        if isangle(value) then return {p=value.p,y=value.y,r=value.r} end
        value = istable(value) and value or {}
        return {p=tonumber(value.p) or 0,y=tonumber(value.y) or 0,r=tonumber(value.r) or 0}
    end
    local function vec(value) value=istable(value) and value or {};return Vector(tonumber(value.x)or 0,tonumber(value.y)or 0,tonumber(value.z)or 0) end
    local function ang(value) value=istable(value) and value or {};return Angle(tonumber(value.p)or 0,tonumber(value.y)or 0,tonumber(value.r)or 0) end

    local STEP_TYPES = {visit=true,event=true,talk=true,item=true}
    local function normalizeStep(step, index)
        step = istable(step) and step or {}
        local kind = trim(step.type, 24)
        if not STEP_TYPES[kind] then kind = "event" end
        local out = {
            type=kind,title=trim(step.title ~= "" and step.title or ("Этап "..index),100),
            description=trim(step.description,300),count=math.Clamp(math.floor(tonumber(step.count)or 1),1,100000),
            event=trim(step.event,64),target=trim(step.target,96),npc=trim(step.npc,64),item=trim(step.item,96),
            consume=step.consume==true,radius=math.Clamp(tonumber(step.radius)or 120,24,10000),
        }
        if step.min and step.max then out.min=vectorData(step.min);out.max=vectorData(step.max)
        elseif step.pos then out.pos=vectorData(step.pos) end
        return out
    end
    local function normalizeCutscene(nodes)
        local out={}
        for index,node in ipairs(istable(nodes)and nodes or {})do
            if #out>=32 then break end
            local transition=node.transition=="cut"and"cut"or(node.transition=="move"and"move"or(index==1 and"cut"or"move"))
            out[#out+1]={id=trim(node.id and node.id~=""and node.id or("camera_"..index),64),next=trim(node.next,64),transition=transition,moveDuration=math.Clamp(tonumber(node.moveDuration)or 1,.05,30),pos=vectorData(node.pos),ang=angleData(node.ang),fov=math.Clamp(tonumber(node.fov)or 75,20,120),duration=math.Clamp(tonumber(node.duration)or 3,.25,30),caption=trim(node.caption,300),sound=trim(node.sound,160),image=trim(node.image,160)}
        end
        return out
    end
    local function normalizeDialoguePhase(value, phase)
        if isstring(value) then
            if value==""then return{}end
            return{{id=phase.."_1",speaker="",text=trim(value,1200),next="",choices={}}}
        end
        local source=istable(value)and(value.nodes or value)or{};local out={}
        for i,node in ipairs(source)do if#out>=64 then break end;node=istable(node)and node or{};local choices={};for _,choice in ipairs(istable(node.choices)and node.choices or{})do if#choices<8 then choices[#choices+1]={text=trim(choice.text,160),next=trim(choice.next,64),action=trim(choice.action,24)}end end;out[#out+1]={id=trim(node.id and node.id~=""and node.id or(phase.."_"..i),64),speaker=trim(node.speaker,80),text=trim(node.text,1200),next=trim(node.next,64),choices=choices}end
        return out
    end
    local function normalizeDialogue(value)
        value=istable(value)and value or{}
        return{offer=normalizeDialoguePhase(value.offer,"offer"),active=normalizeDialoguePhase(value.active,"active"),complete=normalizeDialoguePhase(value.complete,"complete")}
    end
    local function normalizeNotification(value, defaultText, defaultBanner)
        value=istable(value)and value or{}
        return{enabled=value.enabled~=false,text=trim(value.text and value.text~=""and value.text or defaultText,300),sound=trim(value.sound,160),duration=math.Clamp(tonumber(value.duration)or 4,1,15),banner=value.banner==true or(defaultBanner==true and value.banner~=false)}
    end
    local function normalizeAchievement(value,questID,title,summary)
        value=istable(value)and value or{};local enabled=value.enabled==true;local id=string.lower(trim(value.id,64)):gsub("[^%w_%-%:]","_");if id==""then id="quest_"..questID end
        return{enabled=enabled,id=id,name=trim(value.name and value.name~=""and value.name or title,100),description=trim(value.description and value.description~=""and value.description or summary,300),reward=math.Clamp(math.floor(tonumber(value.reward)or 0),0,100000000),hidden=value.hidden==true}
    end
    function Q.NormalizeDefinition(raw)
        raw=istable(raw)and raw or {}
        local id=string.lower(trim(raw.id,64)):gsub("[^%w_%-%:]","_")
        if id=="" then return nil,"ID обязателен"end
        local steps={};for i,step in ipairs(istable(raw.steps)and raw.steps or {})do if #steps<64 then steps[#steps+1]=normalizeStep(step,i)end end
        local draft=raw.draft==true or #steps==0
        local rewards={money=math.Clamp(math.floor(tonumber(raw.rewards and raw.rewards.money)or 0),0,100000000),items={}}
        for itemID,count in pairs(istable(raw.rewards and raw.rewards.items)and raw.rewards.items or {})do rewards.items[trim(itemID,96)]=math.Clamp(math.floor(tonumber(count)or 1),1,10000)end
        local prerequisites={};for _,v in ipairs(istable(raw.prerequisites)and raw.prerequisites or {})do prerequisites[#prerequisites+1]=trim(v,64)end
        local title,summary=trim(raw.title,100),trim(raw.summary,400);local notifications=istable(raw.notifications)and raw.notifications or{}
        return {id=id,title=title,draft=draft,summary=summary,category=trim(raw.category,48),npc=trim(raw.npc,64),repeatable=raw.repeatable==true,autoStart=raw.autoStart==true,enabled=raw.enabled~=false,prerequisites=prerequisites,steps=steps,rewards=rewards,achievement=normalizeAchievement(raw.achievement,id,title,summary),notifications={start=normalizeNotification(notifications.start,"Получен квест: {title}",false),step=normalizeNotification(notifications.step,"Этап выполнен: {step}",false),complete=normalizeNotification(notifications.complete,"Квест завершён: {title}",true)},dialogue=normalizeDialogue(raw.dialogue),cutscene={accept=normalizeCutscene(raw.cutscene and raw.cutscene.accept),complete=normalizeCutscene(raw.cutscene and raw.cutscene.complete)}}
    end

    function Q.SaveDefinitions()
        local records={};for _,def in pairs(Q.Definitions)do records[#records+1]=def end;table.sort(records,function(a,b)return a.id<b.id end)
        local npcs={};for _,ent in ipairs(ents.FindByClass("grm_quest_npc"))do if IsValid(ent)then npcs[#npcs+1]={id=ent:GetQuestNPCID(),name=ent:GetQuestNPCName(),model=ent:GetModel(),pos=vectorData(ent:GetPos()),ang=angleData(ent:GetAngles())}end end
        return writeJSON(Q.DefFile,{version=1,map=game.GetMap(),quests=records,npcs=npcs})
    end
    function Q.SaveProgress()
        local records={};for key,quests in pairs(Q.Progress)do records[#records+1]={key=key,quests=quests}end
        return writeJSON(Q.ProgressFile,{version=1,records=records})
    end
    function Q.LoadData()
        Q.Definitions={};local defs=readJSON(Q.DefFile)or {}
        for _,raw in pairs(defs.quests or {})do local def=Q.NormalizeDefinition(raw);if def then Q.Definitions[def.id]=def end end
        Q.Progress={};local progress=readJSON(Q.ProgressFile)or {}
        for _,record in pairs(progress.records or {})do if istable(record)and isstring(record.key)then Q.Progress[record.key]=istable(record.quests)and record.quests or {}end end
        Q._NPCRecords=istable(defs.npcs)and defs.npcs or {}
        return true
    end
    Q.LoadData()
    function Q.RegisterAchievements()
        if not(GRM.Ach and GRM.Ach.Register)then return 0 end;local count=0
        for _,def in pairs(Q.Definitions)do local a=def.achievement;if a and a.enabled then GRM.Ach.Register({id=a.id,name=a.name,desc=a.description,metric="quest:"..def.id,goal=1,reward=a.reward,hidden=a.hidden,questID=def.id});count=count+1 end end
        return count
    end
    timer.Create("GRM_Quest_AchievementBridge",1,0,function()if GRM.Ach and GRM.Ach.Register then Q.RegisterAchievements();timer.Remove("GRM_Quest_AchievementBridge")end end)

    local function progressFor(ply)
        local key=characterKey(ply);Q.Progress[key]=Q.Progress[key]or {};return Q.Progress[key],key
    end
    function Q.GetProgress(ply,questID)local all=progressFor(ply);return all[tostring(questID or "")]end
    local sync
    function Q.ResetProgress(questID,targetKey)
        questID=trim(questID,64);targetKey=targetKey and tostring(targetKey)or nil;local removed,removedKeys=0,{}
        if targetKey and targetKey~=""and targetKey~="*"then local quests=Q.Progress[targetKey];if quests and quests[questID]then quests[questID]=nil;removed=1;removedKeys[1]=targetKey end
        else for key,quests in pairs(Q.Progress)do if quests[questID]then quests[questID]=nil;removed=removed+1;removedKeys[#removedKeys+1]=key end end end
        local achievement=Q.Definitions[questID]and Q.Definitions[questID].achievement;if achievement and achievement.enabled and GRM.Ach and GRM.Ach.ResetUnlock then for _,key in ipairs(removedKeys)do GRM.Ach.ResetUnlock(key,achievement.id,true)end;if GRM.Ach.SaveNow then GRM.Ach.SaveNow("quest progress reset")end end
        Q.SaveProgress();for _,online in ipairs(player.GetAll())do if IsValid(online)and(not targetKey or targetKey=="*"or characterKey(online)==targetKey)then sync(online)end end
        hook.Run("GRM_QuestProgressReset",questID,targetKey,removed);return removed
    end
    local function canStart(ply,def)
        if not def or not def.enabled then return false,"Квест отключён"end
        if def.draft or #(def.steps or{})==0 then return false,"Квест пока является черновиком"end
        local all=progressFor(ply);local old=all[def.id]
        if old and old.status=="active"then return false,"Квест уже выполняется"end
        if old and old.status=="completed"and not def.repeatable then return false,"Квест уже завершён"end
        for _,id in ipairs(def.prerequisites or {})do if not all[id]or all[id].status~="completed"then return false,"Не выполнено условие: "..id end end
        return true
    end
    sync=function(ply)
        if not IsValid(ply)then return end
        local all=progressFor(ply);local defs={};for id,p in pairs(all)do local d=Q.Definitions[id];if d then defs[#defs+1]={definition=d,progress=p}end end
        net.Start("GRM_Quest_Sync")net.WriteTable(defs)net.Send(ply)
    end
    Q.Sync=sync
    local function notice(ply,ok,text,opts)opts=istable(opts)and opts or{};net.Start("GRM_Quest_Notice")net.WriteBool(ok)net.WriteString(trim(text,300))net.WriteString(trim(opts.sound,160))net.WriteFloat(math.Clamp(tonumber(opts.duration)or 4,1,15))net.WriteBool(opts.banner==true)net.WriteString(trim(opts.heading,80))net.Send(ply)end
    local function questNotice(ply,kind,def,step)
        local cfg=def.notifications and def.notifications[kind];if cfg and cfg.enabled==false then return end;cfg=cfg or{};local text=tostring(cfg.text or"");text=text:gsub("{title}",tostring(def.title or"")):gsub("{step}",tostring(step and step.title or"")):gsub("{count}",tostring(step and step.count or""));notice(ply,true,text,{sound=cfg.sound,duration=cfg.duration,banner=cfg.banner,heading=({start="НОВОЕ ЗАДАНИЕ",step="ЭТАП ВЫПОЛНЕН",complete="ЗАДАНИЕ ЗАВЕРШЕНО"})[kind]})
    end
    local function startCutscenePVS(ply,nodes)
        if not IsValid(ply)then return end;local duration=0;for _,node in ipairs(nodes or{})do duration=duration+math.Clamp(tonumber(node.duration)or 3,.05,30)+(node.transition=="move"and math.Clamp(tonumber(node.moveDuration)or 1,.05,30)or 0)end
        ply.GRMQuestCutscenePVS={nodes=table.Copy(nodes or{}),expires=CurTime()+duration+8}
    end
    local function cutscene(ply,nodes)if not IsValid(ply)or#(nodes or {})==0 then return end;startCutscenePVS(ply,nodes);net.Start("GRM_Quest_Cutscene")net.WriteTable(nodes)net.Send(ply)end

    net.Receive("GRM_Quest_CutscenePreview",function(_,ply)
        if not IsValid(ply)or not ply:IsSuperAdmin()then return end;local nodes=normalizeCutscene(net.ReadTable()or{});if#nodes>0 then startCutscenePVS(ply,nodes)end
    end)
    net.Receive("GRM_Quest_CutsceneStop",function(_,ply)if IsValid(ply)then ply.GRMQuestCutscenePVS=nil end end)
    hook.Add("SetupPlayerVisibility","GRM_Quest_CutscenePVS",function(ply)
        local state=IsValid(ply)and ply.GRMQuestCutscenePVS;if not state then return end;if CurTime()>(state.expires or 0)then ply.GRMQuestCutscenePVS=nil return end
        for i,node in ipairs(state.nodes or{})do if i>32 then break end;if node.pos then AddOriginToPVS(vec(node.pos))end end
    end)
    hook.Add("PlayerDeath","GRM_Quest_CutscenePVSDeath",function(ply)ply.GRMQuestCutscenePVS=nil end)
    hook.Add("PlayerDisconnected","GRM_Quest_CutscenePVSLeave",function(ply)ply.GRMQuestCutscenePVS=nil end)

    local function itemCount(ply,itemID)
        if GRM.Inventory and GRM.Inventory.CountItem then return tonumber(GRM.Inventory.CountItem(ply,itemID))or 0 end
        return 0
    end
    local function reward(ply,def)
        local r=def.rewards or {};if(r.money or 0)>0 and GRM.GiveMoney then GRM.GiveMoney(ply,r.money,"Квест: "..def.title)end
        for itemID,count in pairs(r.items or {})do if GRM.Inventory and GRM.Inventory.AddItem then GRM.Inventory.AddItem(ply,itemID,count)end end
    end
    local function unlockQuestAchievement(ply,def)
        local a=def.achievement;if not(a and a.enabled and GRM.Ach and GRM.Ach.Register and GRM.Ach.Unlock and GRM.Ach.RecOf)then return end
        GRM.Ach.Register({id=a.id,name=a.name,desc=a.description,metric="quest:"..def.id,goal=1,reward=a.reward,hidden=a.hidden,questID=def.id});GRM.Ach.Unlock(ply,GRM.Ach.Defs[a.id],GRM.Ach.RecOf(ply))
    end
    local function finishQuest(ply,def,p)
        p.status="completed";p.completedAt=os.time();reward(ply,def);unlockQuestAchievement(ply,def);questNotice(ply,"complete",def);cutscene(ply,def.cutscene.complete);hook.Run("GRM_QuestCompleted",ply,def.id);Q.SaveProgress();sync(ply)
    end
    local function checkCurrent(ply,def,p)
        local step=def.steps[p.step or 1];if not step then finishQuest(ply,def,p)return end
        if step.type=="item"then p.count=itemCount(ply,step.item);if p.count>=step.count then if step.consume and GRM.Inventory and GRM.Inventory.RemoveItem then GRM.Inventory.RemoveItem(ply,step.item,step.count)end;p.step=p.step+1;p.count=0;questNotice(ply,"step",def,step);checkCurrent(ply,def,p)end end
    end
    function Q.Start(ply,questID)
        local def=Q.Definitions[tostring(questID or "")];local ok,why=canStart(ply,def);if not ok then return false,why end
        local all=progressFor(ply);all[def.id]={status="active",step=1,count=0,startedAt=os.time()};questNotice(ply,"start",def);cutscene(ply,def.cutscene.accept);checkCurrent(ply,def,all[def.id]);Q.SaveProgress();sync(ply);hook.Run("GRM_QuestStarted",ply,def.id);return true
    end
    function Q.Event(ply,eventName,target,amount,meta)
        if not IsValid(ply)then return end;eventName=trim(eventName,64);target=trim(target,96);amount=math.max(1,math.floor(tonumber(amount)or 1));local all=progressFor(ply)
        for id,p in pairs(all)do local def=Q.Definitions[id];if def and def.enabled and not def.draft and p.status=="active"then local step=def.steps[p.step or 1];local match=step and step.type=="event"and step.event==eventName and(step.target==""or step.target==target);if match then p.count=math.min(step.count,(tonumber(p.count)or 0)+amount);if p.count>=step.count then p.step=p.step+1;p.count=0;questNotice(ply,"step",def,step);checkCurrent(ply,def,p)end end end end
        Q.SaveProgress();sync(ply)
    end
    function Q.Talk(ply,npcID)
        local all=progressFor(ply);for id,p in pairs(all)do local def=Q.Definitions[id];local step=def and def.steps[p.step or 1];if def and def.enabled and not def.draft and p.status=="active"and step and step.type=="talk"and step.npc==npcID then p.step=p.step+1;p.count=0;questNotice(ply,"step",def,step);checkCurrent(ply,def,p)end end;Q.SaveProgress();sync(ply)
    end

    local function inZone(pos,step)
        if step.min and step.max then local mn,mx=vec(step.min),vec(step.max);return pos.x>=math.min(mn.x,mx.x)and pos.x<=math.max(mn.x,mx.x)and pos.y>=math.min(mn.y,mx.y)and pos.y<=math.max(mn.y,mx.y)and pos.z>=math.min(mn.z,mx.z)and pos.z<=math.max(mn.z,mx.z)end
        return step.pos and pos:DistToSqr(vec(step.pos))<=step.radius*step.radius
    end
    timer.Create("GRM_Quest_Objectives",1,0,function()
        local changed,changedPlayers=false,{}
        for _,ply in ipairs(player.GetAll())do if IsValid(ply)and ply:Alive()then local all=progressFor(ply);for id,p in pairs(all)do local def=Q.Definitions[id];local step=def and def.steps[p.step or 1]
            if def and def.enabled and not def.draft and p.status=="active"and step then
                if step.type=="visit"and inZone(ply:GetPos(),step)then p.step=p.step+1;p.count=0;questNotice(ply,"step",def,step);checkCurrent(ply,def,p);changed=true;changedPlayers[ply]=true
                elseif step.type=="item"then local before=p.count;checkCurrent(ply,def,p);if before~=p.count then changed=true;changedPlayers[ply]=true end end
            end
        end end end
        if changed then Q.SaveProgress();for ply in pairs(changedPlayers)do if IsValid(ply)then sync(ply)end end end
    end)

    function Q.OpenNPC(ply,npc)
        if not IsValid(ply)or not IsValid(npc)or ply:GetPos():DistToSqr(npc:GetPos())>220*220 then return end
        local npcID=npc:GetQuestNPCID();Q.Talk(ply,npcID);local rows={};local all=progressFor(ply)
        for _,def in pairs(Q.Definitions)do if def.npc==npcID and def.enabled and not def.draft then local p=all[def.id];local available=canStart(ply,def);rows[#rows+1]={definition=def,progress=p,available=available==true}end end
        table.sort(rows,function(a,b)return a.definition.title<b.definition.title end)
        net.Start("GRM_Quest_OpenNPC")net.WriteEntity(npc)net.WriteString(npc:GetQuestNPCName())net.WriteTable(rows)net.Send(ply)
    end

    net.Receive("GRM_Quest_PlayerOp",function(_,ply)
        if not IsValid(ply)then return end;ply.GRMQuestNext=ply.GRMQuestNext or 0;if CurTime()<ply.GRMQuestNext then return end;ply.GRMQuestNext=CurTime()+.2
        local op=net.ReadString();local id=net.ReadString()
        if op=="accept"then local ok,why=Q.Start(ply,id);if not ok then notice(ply,false,why)end
        elseif op=="restart"then local def=Q.Definitions[id];local all=progressFor(ply);if not def or not def.repeatable then notice(ply,false,"Квест нельзя повторять")elseif not all[id]or all[id].status~="completed"then notice(ply,false,"Сначала завершите квест")else all[id]=nil;local ok,why=Q.Start(ply,id);if not ok then notice(ply,false,why)end end
        elseif op=="abandon"then local all=progressFor(ply);if all[id]and all[id].status=="active"then all[id]=nil;Q.SaveProgress();sync(ply);notice(ply,true,"Квест отменён")end end
    end)

    function Q.AdminData()local defs={};for _,d in pairs(Q.Definitions)do defs[#defs+1]=d end;table.sort(defs,function(a,b)return tostring(a.title or a.id)<tostring(b.title or b.id)end);local online={};for _,p in ipairs(player.GetAll())do if IsValid(p)then online[#online+1]={name=p:Nick(),key=characterKey(p)}end end;return{definitions=defs,eventTypes=Q.EventTypes,npcs=Q._NPCRecords or {},onlinePlayers=online}end
    local function adminOpen(ply)if not IsValid(ply)or not ply:IsSuperAdmin()then return end;net.Start("GRM_Quest_AdminOpen")net.WriteTable(Q.AdminData())net.Send(ply)end
    Q.OpenAdmin=adminOpen
    concommand.Add("grm_quests_admin",adminOpen)
    hook.Add("PlayerSayTransform","GRM_Quest_AdminChat",function(ply,pack)if not istable(pack)then return end;local cmd=string.lower(trim(pack[1],64));if cmd=="/grm_quests_admin"or cmd=="!grm_quests_admin"then adminOpen(ply);pack[1]="";pack.SkipPlayerSay=true end end)
    local function openJournal(ply)if not IsValid(ply)then return end;sync(ply);net.Start("GRM_Quest_Journal")net.Send(ply)end
    concommand.Add("grm_quests",openJournal)
    hook.Add("PlayerSayTransform","GRM_Quest_JournalChat",function(ply,pack)if not istable(pack)then return end;local cmd=string.lower(trim(pack[1],64));if cmd=="/quests"or cmd=="!quests"or cmd=="/квесты"then openJournal(ply);pack[1]="";pack.SkipPlayerSay=true end end)
    net.Receive("GRM_Quest_AdminOp",function(_,ply)
        if not IsValid(ply)or not ply:IsSuperAdmin()then return end;local op=net.ReadString()
        if op=="save"then local def,why=Q.NormalizeDefinition(net.ReadTable());if not def then notice(ply,false,why)return end;Q.Definitions[def.id]=def;Q.SaveDefinitions();Q.RegisterAchievements();adminOpen(ply);notice(ply,true,"Квест сохранён: "..def.id)
        elseif op=="reset_progress"then local id=trim(net.ReadString(),64);local target=trim(net.ReadString(),96);if target=="@self"then target=characterKey(ply)elseif target~="*"and target:match("^%d+$")then target=target..":char1"end;local count=Q.ResetProgress(id,target);notice(ply,true,"Сброшен прогресс: "..count.." записей")
        elseif op=="delete"then local id=trim(net.ReadString(),64);local old=Q.Definitions[id];if old and old.achievement and GRM.Ach and GRM.Ach.Unregister then GRM.Ach.Unregister(old.achievement.id)end;Q.Definitions[id]=nil;Q.SaveDefinitions();adminOpen(ply);notice(ply,true,"Квест удалён")
        elseif op=="request"then adminOpen(ply)end
    end)

    function Q.SpawnNPC(id,name,model,pos,angles)
        local ent=ents.Create("grm_quest_npc");if not IsValid(ent)then return nil end;ent:SetPos(pos);ent:SetAngles(angles);ent:SetQuestNPCID(trim(id,64));ent:SetQuestNPCName(trim(name,80));if util.IsValidModel(model)then ent:SetModel(model)end;ent:Spawn();ent:Activate();Q.SaveDefinitions();return ent
    end
    function Q.SaveAll()local a=Q.SaveDefinitions();local b=Q.SaveProgress();return a and b,"квесты и прогресс сохранены"end
    function Q.LoadAll()
        Q.LoadData();for _,ent in ipairs(ents.FindByClass("grm_quest_npc"))do if IsValid(ent)then ent:Remove()end end
        for _,r in ipairs(Q._NPCRecords or {})do Q.SpawnNPC(r.id,r.name,r.model,vec(r.pos),ang(r.ang))end
        return true,"квесты, прогресс и NPC загружены"
    end
    function Q.SetVisitZone(questID,stepIndex,first,second)
        local def=Q.Definitions[questID];local step=def and def.steps[math.floor(tonumber(stepIndex)or 0)];if not step then return false,"Квест или этап не найден"end;step.type="visit";step.min=vectorData(first);step.max=vectorData(second);Q.SaveDefinitions();return true
    end
    function Q.AddCutsceneNode(questID,phase,ply)
        local def=Q.Definitions[questID];if not def then return false,"Квест не найден"end;phase=phase=="complete"and"complete"or"accept";def.cutscene[phase]=def.cutscene[phase]or {};local index=#def.cutscene[phase]+1;local id="camera_"..index;if index>1 and tostring(def.cutscene[phase][index-1].next or"")==""then def.cutscene[phase][index-1].next=id end;def.cutscene[phase][index]={id=id,next="",transition=index==1 and"cut"or"move",moveDuration=1,pos=vectorData(ply:EyePos()),ang=angleData(ply:EyeAngles()),fov=75,duration=3,caption="",sound="",image=""};Q.SaveDefinitions();return true
    end

    hook.Add("GRM_CharacterChanged","GRM_Quest_CharacterSync",function(ply)timer.Simple(1,function()if IsValid(ply)then sync(ply)end end)end)
    hook.Add("PlayerInitialSpawn","GRM_Quest_Join",function(ply)timer.Simple(3,function()if not IsValid(ply)then return end;for _,def in pairs(Q.Definitions)do if def.autoStart and not def.draft then Q.Start(ply,def.id)end end;sync(ply)end)end)
    hook.Add("ShutDown","GRM_Quest_Save",function()Q.SaveDefinitions();Q.SaveProgress()end)
    hook.Add("PostCleanupMap","GRM_Quest_NPCRestore",function()timer.Simple(1,function()for _,r in ipairs(Q._NPCRecords or {})do Q.SpawnNPC(r.id,r.name,r.model,vec(r.pos),ang(r.ang))end end)end)
    hook.Add("InitPostEntity","GRM_Quest_NPCLoad",function()timer.Simple(2,function()for _,r in ipairs(Q._NPCRecords or {})do Q.SpawnNPC(r.id,r.name,r.model,vec(r.pos),ang(r.ang))end end)end)

    -- Integrations: modules may also call GRM.Quests.Event directly.
    hook.Add("GRM_QuestEvent","GRM_Quest_GenericEvent",function(ply,eventName,target,amount,meta)Q.Event(ply,eventName,target,amount,meta)end)
    print("[GRM Quests] server v"..Q.Version.." loaded")
end
