-- Contracts for the repository-wide event-driven performance pass.
local function read(p)local f=assert(io.open(p,"rb"));local s=f:read("*a");f:close();return s end
local perf=read("lua/autorun/sh_06_grm_performance.lua");local vendor=read("lua/entities/grm_vendor/cl_init.lua");local ore=read("lua/entities/grm_ore_buyer/cl_init.lua");local factoryUI=read("lua/autorun/client/cl_grm_factory_fullcycle.lua");local logisticsUI=read("lua/autorun/client/cl_grm_faction_logistics.lua");local broadcast=read("lua/autorun/sh_grm_broadcast.lua");local fire=read("lua/autorun/sh_grm_fire_truck.lua");local slide=read("lua/autorun/sh_grm_sliding_door.lua");local aug=read("lua/autorun/client/cl_grm_augmentations.lua");local custom=read("lua/autorun/client/cl_grm_customization.lua");local movement=read("lua/autorun/sh_grm_movement.lua");local f4=read("lua/autorun/sh_grm_f4menu.lua");local tickets=read("lua/autorun/sh_grm_tickets.lua");local cctv=read("lua/autorun/client/cl_grm_cctv.lua");local shop=read("lua/autorun/sh_grm_shop_integration.lua");local mobile=read("lua/autorun/sh_grm_mobile.lua");local quests=read("lua/autorun/sh_grm_quests.lua");local factory=read("lua/autorun/server/sv_grm_factory_fullcycle.lua");local economy=read("lua/autorun/sh_grm_economy.lua");local dutyTool=read("lua/weapons/gmod_tool/stools/grm_duty_npc.lua");local dutyNPC=read("lua/entities/grm_duty_npc/init.lua");local dutyShared=read("lua/entities/grm_duty_npc/shared.lua");local questTool=read("lua/weapons/gmod_tool/stools/grm_quest_tool.lua");local trunk=read("lua/autorun/sh_grm_trunk.lua");local incass=read("lua/autorun/sh_grm_incassation.lua");local cuffsWeight=read("lua/autorun/server/sv_grm_encumbrance.lua");local customization=read("lua/autorun/sh_grm_customization.lua");local emergency=read("lua/autorun/sh_grm_911.lua");local arrest=read("lua/autorun/sh_grm_arrest.lua")
local fail,n=0,0;local function ok(v,msg)n=n+1;if v then print("  ok  "..msg)else fail=fail+1;print("  FAIL "..msg)end end
ok(perf:find("function P.Entities",1,true)and perf:find("GRM_Perf_EntityCreated",1,true)and perf:find("GRM_Perf_EntityRemoved",1,true),"shared entity cache is event-driven")
ok(perf:find("if not b.dirty then return b.array",1,true),"entity arrays are reused until an event invalidates cache")
ok(perf:find("function P.NWString",1,true)and perf:find("function P.NWInt",1,true),"change-only NW helpers exist")
-- 19.08: вывески торгашей и скупщика переехали из HUDPaint (перебор ВСЕХ
-- сущностей каждый кадр) в отрисовку самого энтити — только когда NPC в кадре.
-- 21.08: рисование ушло в общий слой GRM.Sign и в прозрачный проход
-- (ENT:DrawTranslucent), иначе RENDERGROUP_BOTH рисовал вывеску дважды.
ok(vendor:find("GRM.Sign.Draw",1,true)and ore:find("GRM.Sign.Draw",1,true)
    and vendor:find("function ENT:DrawTranslucent",1,true)and ore:find("function ENT:DrawTranslucent",1,true)
    and not vendor:find('hook.Add("HUDPaint"',1,true)and not ore:find('hook.Add("HUDPaint"',1,true),
    "vendor world labels draw per-entity instead of scanning every frame")
ok(factoryUI:find('GRM.Perf.Entities("grm_fc_scrap_bin")',1,true)and logisticsUI:find('GRM.Perf.Entities("grm_logistics_crate")',1,true),"factory/logistics render labels use registries")
ok(broadcast:find('GRM.Perf.Entities("grm_broadcast_mic")',1,true),"broadcast watcher uses microphone registry")
ok(fire:find('GRM.Perf.Entities("grm_fire_pump")',1,true)and fire:find("GRM_FireTruck_RenderRegistry",1,true)and not fire:find('for _, veh in ipairs(ents.GetAll())',1,true),"fire truck server/client use pump and NW registries")
ok(slide:find("if moving then ent.Sliding_Progress",1,true),"idle sliding doors do not receive physical moves every frame")
ok(aug:find("if not timer.Exists(timerName)then timer.Create",1,true)and aug:find('augment.regen.client',1,true),"augmentation regeneration does not recreate timer every frame")
ok(custom:find('custom.flashlight",.25',1,true)and movement:find('movement.breath.client",.1',1,true),"simple client guards are frequency-capped")
ok(f4:find('f4.keypoll",.05',1,true)and tickets:find('tickets.f2poll",.05',1,true),"fallback key polls are capped at 20 Hz")
ok(cctv:find('cctv.hudhooks",.5',1,true)and shop:find('shop.leader.patch",.5',1,true),"expensive hook-table/patch checks are throttled")
ok(mobile:find("local keyRepeatDelta",1,true)and not mobile:find("pairs({[KEY_UP]",1,true),"mobile key loop creates no table each frame")
ok(quests:find("local changed,changedPlayers=false,{}",1,true),"quest objective persistence is batched per tick")
ok(factory:find('GRM.Perf.Entities("grm_fc_scrap_bin")',1,true)and factory:find('scheduleFactorySave("scrap refill batch")',1,true),"factory refill scans registry and schedules one save batch")
ok(economy:find("v:GetStateBudget()~=budget",1,true),"vault mirrors skip unchanged network writes")
ok(trunk:find("GRM_Trunk_LidRegistry",1,true)and not trunk:find('for _, veh in ipairs(ents.FindByClass("*"))',1,true),"trunk render uses open-lid event registry")
ok(incass:find("GRM_Incass_RunRegistry",1,true)and incass:find('GRM.Perf.Entities("grm_bank_terminal")',1,true),"incassation render uses NW vehicle registry")
ok(emergency:find('GRM.Perf.Entities("prop_ragdoll")',1,true)and arrest:find('GRM.Perf.Entities("grm_arrest_camera")',1,true),"911/arrest render hooks use entity registries")
ok(cuffsWeight:find('timer.Remove("GRM_Weight_InstallInventory")',1,true)and customization:find('timer.Remove("GRM_Custom_RegisterIntegrations")',1,true),"dependency installers stop after successful registration")
ok(custom:find("C.ActiveRenderPlayers",1,true)and custom:find("C.ValidModelCache",1,true)and custom:find("entry.boneName",1,true),"accessories cache active players, model validation and bone lookup")
ok(not custom:find("entry.ent:SetupBones()",1,true)and not custom:find("ipairs(player.GetAll())",1,true),"accessory fallback avoids redundant model bones and all-player frame scan")
ok(dutyTool:find("GRM_DutyToolFactionsUpdated",1,true)and not dutyTool:find("timer.Create",1,true)and not dutyNPC:find("function ENT:Think",1,true)and dutyShared:find('ENT.Type = "anim"',1,true),"duty terminal is event-updated base_anim without AI/watchdog Think")
ok(questTool:find("local preview=",1,true)and questTool:find("rebuildPreview",1,true)and questTool:find("preview.nextBuild=CurTime()+.5",1,true),"quest placement preview caches converted geometry")
print(("PERFORMANCE V2: %d/%d failures=%d"):format(n-fail,n,fail));os.exit(fail==0 and 0 or 1)
