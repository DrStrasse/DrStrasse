if CLIENT then return end

AddCSLuaFile("autorun/sh_grm_logistics_config.lua")
AddCSLuaFile("autorun/sh_grm_logistics_entities.lua")
AddCSLuaFile("autorun/client/cl_grm_faction_logistics.lua")
include("autorun/sh_grm_logistics_config.lua")
include("autorun/sh_grm_logistics_entities.lua")

GRM = GRM or {}
GRM.Logistics = GRM.Logistics or {}
local L, C = GRM.Logistics, GRM.Logistics.Config

local NET = {
    result="GRML_Result", routeMenu="GRML_RouteMenu", routeSync="GRML_RouteSync",
    loading="GRML_LoadingUI", crate="GRML_CrateUI", crateInv="GRML_CrateInventory",
    warehouse="GRML_WarehouseUI", armory="GRML_ArmoryUI", admin="GRML_AdminUI", action="GRML_Action",
}
for _, n in pairs(NET) do util.AddNetworkString(n) end

local DIR, MAPDIR = "grm_logistics", "grm_logistics/maps"
local MAPFILE = MAPDIR .. "/" .. string.lower(game.GetMap() or "unknown") .. ".json"
local ACCESSFILE, CRATEFILE = DIR .. "/access.json", DIR .. "/inventory_crates.json"

L.Access, L.Warehouses, L.Armories, L.Routes, L.InventoryCrates = L.Access or {}, L.Warehouses or {}, L.Armories or {}, {}, L.InventoryCrates or {}

local EQUIP = { grm_logistics_loading=true, grm_logistics_warehouse=true, grm_logistics_armory=true }

local function jsonT(txt)
    local ok, t = pcall(util.JSONToTable, txt, false, true)
    return (ok and istable(t)) and t or nil
end

local function ensure() if not file.Exists(DIR,"DATA") then file.CreateDir(DIR) end if not file.Exists(MAPDIR,"DATA") then file.CreateDir(MAPDIR) end end
local function read(path, fallback) local raw=file.Exists(path,"DATA") and file.Read(path,"DATA") or ""; local t=jsonT(raw); return t and t or table.Copy(fallback or {}) end
local function write(path,t) ensure(); file.Write(path,util.TableToJSON(t or {},true)) end
local function vec(v) return {x=v.x,y=v.y,z=v.z} end
local function ang(a) return {p=a.p,y=a.y,r=a.r} end
local function V(t) return Vector(tonumber(t and(t.x or t[1]))or 0,tonumber(t and(t.y or t[2]))or 0,tonumber(t and(t.z or t[3]))or 0) end
local function A(t) return Angle(tonumber(t and(t.p or t[1]))or 0,tonumber(t and(t.y or t[2]))or 0,tonumber(t and(t.r or t[3]))or 0) end
local function id(prefix) return prefix.."_"..os.time().."_"..math.random(100000,999999) end
local function sid(p)
    if not IsValid(p) then return "" end
    if GRM.Identity and GRM.Identity.CharacterKey then return GRM.Identity.CharacterKey(p) end
    return p:SteamID64() or ""
end
local function notify(p,ok,msg) if not IsValid(p) then return end net.Start(NET.result) net.WriteBool(ok) net.WriteString(msg or "") net.Send(p) end
local function refreshWeight(p)
    if GRM and GRM.Encumbrance and GRM.Encumbrance.Refresh then GRM.Encumbrance.Refresh(p) end
end

L.Access = read(ACCESSFILE,{ factions={}, vehicles=C.Vehicles })
L.Access.factions = L.Access.factions or {}; L.Access.vehicles = L.Access.vehicles or C.Vehicles
L.InventoryCrates = read(CRATEFILE,{})

local function saveAccess() write(ACCESSFILE,L.Access) end
local function saveCrates() write(CRATEFILE,L.InventoryCrates) end

-- Код 90: автосейв карты-точек дебаунсом 1с. Склад/оружейная меняют сток
-- через addStock/takeStock без немедленной записи — до ShutDown сток жил
-- только в памяти; краш/смена карты между кликом и шатдауном = сток терялся.
-- Серия депозитов перезапускает таймер, диск не дёргается.
local function saveSoon()
    timer.Create("GRM_Logistics_SaveSoon",1,1,function()
        if L.SaveMap then L.SaveMap(nil) end
    end)
end

local function factionOf(p)
    if not IsValid(p) or not istable(Factions) then return nil,nil end
    for name,f in pairs(Factions) do
        if istable(f) and istable(f.Members) then
            local m = GRM.Identity.FactionMember(f, p)
            if m then return name,m end
        end
    end
end

local function canLogistics(p)
    if IsValid(p) and p:IsSuperAdmin() then return true end
    local f=factionOf(p); return f and L.Access.factions[f]==true or false
end

local function memberOf(p,fname) local f=factionOf(p); return f==fname or (IsValid(p) and p:IsSuperAdmin()) end
local function canUse(p,e) return IsValid(p) and IsValid(e) and p:GetPos():DistToSqr(e:GetPos())<=(C.UseDistance or 190)^2 end
local function invReady() return GRM and GRM.Inventory and GRM.Inventory.GetPlayerInv and GRM.Inventory.AddItem and GRM.Inventory.RemoveItem end
local function count(p,item) return invReady() and (GRM.Inventory.CountItem(p,item) or 0) or 0 end
local function add(p,item,n) if not invReady() then return false,"Инвентарь не загружен" end local left=GRM.Inventory.AddItem(p,item,n); return not (tonumber(left) or 0)>0, "Нет места в инвентаре" end
local function remove(p,item,n) if count(p,item)<n then return false,"Недостаточно предметов" end local r=GRM.Inventory.RemoveItem(p,item,n); return r~=false,"Ошибка списания" end

-- cargo token can be kept inside standard GRM inventory with data={crateID=...}
local function addCrateToken(p,crateID)
    if not invReady() then return false end
    local inv=GRM.Inventory.GetPlayerInv(p); local empty
    for i=1,GRM.Inventory.Config.MaxSlots do if not inv.slots[i] or not inv.slots[i].id then empty=i break end end
    if not empty then return false end
    inv.slots[empty]={id="logistics_crate",count=1,data={crateID=crateID,ownerSteam=sid(p)}}
    GRM.Inventory.SyncSlot(p,empty); return true
end

local function removeCrateToken(p,crateID)
    local inv=GRM.Inventory.GetPlayerInv(p)
    for i,s in pairs(inv.slots or {}) do if s and s.id=="logistics_crate" and s.data and s.data.crateID==crateID then inv.slots[i]=nil GRM.Inventory.SyncSlot(p,i) return true end end
    return false
end

-- shared data containers
local function normalizeStoreData(x)
    x.stock=x.stock or {}
    x.stock.weapons=x.stock.weapons or {}
    x.stock.items=x.stock.items or {}
    x.capacity=x.capacity or {}
    for key,value in pairs(C.Capacity or {}) do
        if x.capacity[key]==nil then x.capacity[key]=value end
    end
    return x
end

local function warehouseData(e)
    local x=normalizeStoreData(L.Warehouses[e:GetLogisticsID()] or {stock={},capacity={}})
    L.Warehouses[e:GetLogisticsID()]=x
    return x
end

local function armoryData(e)
    local x=normalizeStoreData(L.Armories[e:GetLogisticsID()] or {stock={},capacity={}})
    x.mode=x.mode or "faction"
    L.Armories[e:GetLogisticsID()]=x
    return x
end

-- Публичные API для PERM-DATA (Код 112)
function L.GetWarehouseData(e) return warehouseData(e) end
function L.GetArmoryData(e) return armoryData(e) end
function L.RestoreWarehouseData(e, data)
    if not (istable(data) and IsValid(e)) then return end
    local lid = e:GetLogisticsID()
    if lid == "" then return end
    L.Warehouses[lid] = normalizeStoreData(data)
end
function L.RestoreArmoryData(e, data)
    if not (istable(data) and IsValid(e)) then return end
    local lid = e:GetLogisticsID()
    if lid == "" then return end
    L.Armories[lid] = normalizeStoreData(data)
end

local function used(t) local n=0 for _,v in pairs(t or {}) do n=n+(tonumber(v)or 0) end return n end
local function category(kind,id) if kind=="weapon" then return "weapons" end if kind=="ammo" then return "ammo" end if id=="item_repair_kit" then return "repair" end if id=="item_healthkit" or id=="item_battery" then return "medical" end return "materials" end

local function addStock(data,kind,item,n)
    local cat=category(kind,item); local target=kind=="weapon" and data.stock.weapons or data.stock.items
    local cap=tonumber(data.capacity[cat]) or 0; local current=used(target)
    if current+n>cap then return false end
    target[item]=(tonumber(target[item])or 0)+n; saveSoon(); return true
end

local function takeStock(data,kind,item,n)
    local target=kind=="weapon" and data.stock.weapons or data.stock.items
    if (tonumber(target[item])or 0)<n then return false end
    target[item]=target[item]-n
    if target[item]<=0 then target[item]=nil end
    saveSoon() -- Код 90
    return true
end

local function setLoadingVisual(point, active)
    if not IsValid(point) then return end
    point:SetRenderMode(RENDERMODE_TRANSCOLOR)
    point:SetMaterial("models/debug/debugwhite")
    point:SetColor(Color(255, 0, 0, active and 127 or 0))
    point:SetNWBool("GRML_LoadingActive", active == true)
end

function L.InitializeEntity(e)
    local kind=e.LogisticsKind
    local model=kind=="warehouse" and C.WarehouseModel or kind=="armory" and C.ArmoryModel or kind=="crate" and C.CrateModel or C.LoadingPointModel
    e:SetModel(model)

    if kind=="warehouse" then
        e:SetSolid(SOLID_BBOX); e:SetMoveType(MOVETYPE_NONE); e:SetCollisionGroup(COLLISION_GROUP_NPC); e:SetAutomaticFrameAdvance(true)
        local seq=e:SelectWeightedSequence(ACT_IDLE)
        if seq and seq>=0 then e:ResetSequence(seq); e:SetPlaybackRate(1); e:SetCycle(0) end
    elseif kind=="loading" then
        e:SetSolid(SOLID_BBOX)
        e:SetMoveType(MOVETYPE_NONE)
        e:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
        e:SetCollisionBounds(Vector(-42,-42,0),Vector(42,42,90))
        setLoadingVisual(e, false)
    else e:PhysicsInit(SOLID_VPHYSICS); e:SetMoveType(MOVETYPE_VPHYSICS); e:SetSolid(SOLID_VPHYSICS) end

    e:SetUseType(SIMPLE_USE)
    if e:GetLogisticsID()=="" then e:SetLogisticsID(id(kind)) end
    if kind=="loading" and e:GetPointName()=="" then e:SetPointName("Точка погрузки") end
    if kind=="warehouse" then e:SetCapacity(C.Capacity.weapons or 80); warehouseData(e) end
    if kind=="armory" then e:SetCapacity(C.Capacity.weapons or 80); e:SetFactionMode(true); armoryData(e) end

    local p=e:GetPhysicsObject(); if IsValid(p) then p:Wake() end
end

local function listLoading() local out={} for _,e in ipairs(ents.FindByClass("grm_logistics_loading")) do out[#out+1]={id=e:GetLogisticsID(),name=e:GetPointName(),ent=e} end return out end
local function listWarehouses() local out={} for _,e in ipairs(ents.FindByClass("grm_logistics_warehouse")) do out[#out+1]={id=e:GetLogisticsID(),name=e:GetPointName()~="" and e:GetPointName() or e:GetFactionName(),faction=e:GetFactionName(),ent=e} end return out end

local function truckConfig(ent)
    if not IsValid(ent) then return nil end
    -- матчимся по всем известным ключам: дилерский VD_Class, класс энтити
    -- (LVS / собственные), spawnlist-имя simfphys (VehicleName поле)
    return L.Access.vehicles[ent.VD_Class or ""]
        or L.Access.vehicles[ent:GetClass()]
        or L.Access.vehicles[isstring(ent.VehicleName) and ent.VehicleName or ""]
end

-- список ключей, по которым сущность МОГЛА бы быть матовозкой — для диагностики
local function truckKeys(ent)
    if not IsValid(ent) then return "нет сущности" end
    return "class=" .. tostring(ent:GetClass())
        .. " | VD_Class=" .. tostring(ent.VD_Class or "нет")
        .. " | VehicleName=" .. tostring(isstring(ent.VehicleName) and ent.VehicleName or "нет")
end

local function resolveTruck(p)
    if not IsValid(p) or not p:InVehicle() then return nil end
    local seat=p:GetVehicle()
    local e=seat
    local seen={}

    for _=1,8 do
        if not IsValid(e) or seen[e] then break end
        seen[e]=true
        if truckConfig(e) then return e end
        local nw=e:GetNWEntity("Vehicle")
        if IsValid(nw) and truckConfig(nw) then return nw end
        e=e:GetParent()
    end

    for _,candidate in ipairs(ents.GetAll()) do
        if truckConfig(candidate) then
            local driverSeat
            if isfunction(candidate.GetDriverSeat) then
                local ok,result=pcall(candidate.GetDriverSeat,candidate)
                if ok then driverSeat=result end
            end
            if driverSeat==seat then return candidate end
            if IsValid(driverSeat) and driverSeat:GetDriver()==p then return candidate end
            if isfunction(candidate.GetDriver) then
                local ok,driver=pcall(candidate.GetDriver,candidate)
                if ok and driver==p then return candidate end
            end
        end
    end
end

local function syncRoute(route)
    if not IsValid(route.driver) then return end
    local target=route.phase=="to_loading" and route.loading or route.destination
    local weaponCrates=0
    for _,cargo in ipairs(route.cargo or {}) do if cargo.kind=="weapon" then weaponCrates=weaponCrates+1 end end
    net.Start(NET.routeSync); net.WriteBool(target~=nil); net.WriteString(route.phase); net.WriteEntity(IsValid(target) and target or NULL); net.WriteString(route.name or ""); net.WriteUInt(weaponCrates,8); net.WriteUInt(route.minimumWeaponCrates or 0,8); net.Send(route.driver)
end

local function global(msg) for _,p in ipairs(player.GetAll()) do p:ChatPrint("[Логистика] "..msg) end end

local function openRouteMenu(p,truck)
    local loads,wh={},{}
    for _,x in ipairs(listLoading()) do loads[#loads+1]={id=x.id,name=x.name} end
    for _,x in ipairs(listWarehouses()) do wh[#wh+1]={id=x.id,name=x.name,faction=x.faction} end
    net.Start(NET.routeMenu); net.WriteEntity(truck); net.WriteTable(loads); net.WriteTable(wh); net.Send(p)
end

local function findByID(class,idv) for _,e in ipairs(ents.FindByClass(class)) do if e:GetLogisticsID()==idv then return e end end end

local function startRoute(p,truck,loadID,warehouseID)
    if not canLogistics(p) then notify(p,false,"У вашей фракции нет доступа к логистике") return end
    if resolveTruck(p)~=truck then notify(p,false,"Вы должны быть водителем разрешённой матовозки") return end
    local loading=findByID("grm_logistics_loading",loadID); local wh=findByID("grm_logistics_warehouse",warehouseID)
    if not IsValid(loading) or not IsValid(wh) then notify(p,false,"Точка или склад не найдены") return end
    local cfg=truckConfig(truck) or {}; local key=truck:EntIndex()
    if L.Routes[key] then notify(p,false,"Эта матовозка уже в рейсе") return end
    local minCrates=tonumber(C.MinimumWeaponCrates)or 10
    L.Routes[key]={truck=truck,driver=p,loading=loading,destination=wh,phase="to_loading",cargo={},capacity=math.max(tonumber(cfg.capacity)or C.DefaultTruckCapacity,minCrates),minimumWeaponCrates=minCrates,name=wh:GetFactionName()}
    syncRoute(L.Routes[key]); notify(p,true,"Рейс начат. Следуйте к точке погрузки: "..loading:GetPointName())
end

local function openLoading(p,e)
    local route
    for _,r in pairs(L.Routes) do if r.phase=="loading" and r.loading==e then route=r break end end
    if not route or not canLogistics(p) then notify(p,false,"Сейчас здесь нет активной погрузки вашей логистики") return end
    local weapons={}; for _,w in ipairs(p:GetWeapons()) do if IsValid(w) and w:GetClass()~="weapon_fists" then weapons[#weapons+1]={class=w:GetClass(),name=w:GetPrintName()or w:GetClass()} end end
    local inv={}; if invReady() then for _,s in pairs(GRM.Inventory.GetPlayerInv(p).slots or {}) do local d=GRM.Inventory.GetItemDef(s.id); if d and (d.type=="ammo" or d.type=="item") then inv[#inv+1]={id=s.id,name=d.name or s.id,count=s.count or 1,type=d.type} end end end
    net.Start(NET.loading); net.WriteEntity(e); net.WriteTable({weapons=weapons,items=inv,truck=route.truck,cargo=#route.cargo,capacity=route.capacity}); net.Send(p)
end

local function setCrateCargo(e, kind, item, amount)
    kind, item, amount = tostring(kind or ""), tostring(item or ""), math.max(0, tonumber(amount) or 0)
    e.GRML_CargoKind, e.GRML_CargoID, e.GRML_CargoAmount = kind, item, amount
    e:SetCargoKind(kind)
    e:SetCargoID(item)
    e:SetCargoAmount(amount)
end

local function crateCargo(e)
    return e.GRML_CargoKind or "", e.GRML_CargoID or "", e.GRML_CargoAmount or 0
end

local function weaponCategory(class)
    local lower=string.lower(tostring(class or ""))
    for _,pattern in ipairs((C.WeaponCrate and C.WeaponCrate.PistolPatterns) or {}) do
        if string.find(lower,pattern,1,true) then return "pistol" end
    end
    for _,pattern in ipairs((C.WeaponCrate and C.WeaponCrate.AutomaticPatterns) or {}) do
        if string.find(lower,pattern,1,true) then return "automatic" end
    end
    return "other"
end

local function weaponCrateSummary(crate)
    local contents=crate.GRML_WeaponContents or {}
    local total,pistols,automatics=0,0,0
    for class,amount in pairs(contents) do
        total=total+(tonumber(amount)or 0)
        local cat=weaponCategory(class)
        if cat=="pistol" then pistols=pistols+(tonumber(amount)or 0) end
        if cat=="automatic" then automatics=automatics+(tonumber(amount)or 0) end
    end
    return total,pistols,automatics,contents
end

local function addWeaponToCrate(crate,class)
    crate.GRML_WeaponContents=crate.GRML_WeaponContents or {}
    local total,pistols,automatics=weaponCrateSummary(crate)
    local rules=C.WeaponCrate or {}
    local category=weaponCategory(class)
    if category=="other" then
        return false,"В этот ящик можно грузить только пистолеты и автоматы"
    end
    if category=="pistol" and pistols >= (rules.MaxPistols or 2) then
        return false,"Лимит пистолетов в ящике: " .. tostring(rules.MaxPistols or 2)
    end
    if category=="automatic" and automatics >= (rules.MaxAutomatics or 5) then
        return false,"Лимит автоматов в ящике: " .. tostring(rules.MaxAutomatics or 5)
    end
    if total >= (rules.MaxWeapons or 7) then
        return false,"Ящик уже заполнен"
    end
    crate.GRML_WeaponContents[class]=(crate.GRML_WeaponContents[class] or 0)+1
    total=total+1
    setCrateCargo(crate,"weapon","weapon_bundle",total)
    return true
end

local function spawnCrate(pos,kind,item,amount)
    local e=ents.Create("grm_logistics_crate"); if not IsValid(e) then return end
    e:SetPos(pos+Vector(math.random(-25,25),math.random(-25,25),35)); e:Spawn(); e:Activate(); setCrateCargo(e,kind,item,amount); return e
end

local function packCrate(p,point,kind,item,amount)
    if not canUse(p,point) then return end
    local active=false; for _,r in pairs(L.Routes) do if r.phase=="loading" and r.loading==point then active=true break end end
    if not active then notify(p,false,"Погрузка сейчас не активна") return end
    amount=math.Clamp(math.floor(tonumber(amount)or 1),1,120)

    if kind=="weapon" then
        local w=p:GetWeapon(item)
        if not IsValid(w) then notify(p,false,"У вас нет выбранного оружия") return end
        local crate=spawnCrate(point:GetPos(),"weapon","weapon_bundle",0)
        crate.GRML_WeaponContents={}
        local ok,err=addWeaponToCrate(crate,item)
        if not ok then crate:Remove(); notify(p,false,err); return end
        p:StripWeapon(item)
        refreshWeight(p)
        notify(p,true,"Оружейный ящик создан. Добавьте ещё оружие через E на ящике.")
        return
    end

    local d=GRM.Inventory.GetItemDef(item)
    if not d or (kind=="ammo" and d.type~="ammo") or (kind=="material" and d.type~="item") then
        notify(p,false,"Неверный тип груза")
        return
    end
    local ok,err=remove(p,item,amount)
    if not ok then notify(p,false,err) return end
    spawnCrate(point:GetPos(),kind,item,amount)
    notify(p,true,"Грузовой ящик подготовлен")
end

local function openCrate(p,e)
    if not canUse(p,e) then return end
    local kind,item,amount=crateCargo(e)
    local total,pistols,automatics,contents=weaponCrateSummary(e)
    net.Start(NET.crate); net.WriteEntity(e); net.WriteTable({kind=kind,id=item,amount=amount,weapons=contents,total=total,pistols=pistols,automatics=automatics}); net.Send(p)
end

local function packActiveWeaponIntoCrate(p,e)
    if not canUse(p,e) then return end
    local oldKind=crateCargo(e)
    if oldKind ~= "" and oldKind ~= "weapon" then
        notify(p,false,"Этот ящик уже содержит другой тип груза")
        return
    end
    local weapon=p:GetActiveWeapon()
    if not IsValid(weapon) or weapon:GetClass()=="weapon_fists" then
        notify(p,false,"Возьмите в руки оружие, которое хотите упаковать")
        return
    end
    local class=weapon:GetClass()
    if oldKind=="" then
        e.GRML_WeaponContents={}
    end
    local ok,err=addWeaponToCrate(e,class)
    if not ok then notify(p,false,err) return end
    p:StripWeapon(class)
    refreshWeight(p)
    local total,pistols,automatics=weaponCrateSummary(e)
    notify(p,true,string.format("Оружие добавлено: %d/7 | пистолеты %d/2 | автоматы %d/5",total,pistols,automatics))
end

local function createEmptyCrate(p,point)
    if not canUse(p,point) then return end
    local active=false
    for _,r in pairs(L.Routes) do if r.phase=="loading" and r.loading==point then active=true break end end
    if not active then notify(p,false,"Погрузка сейчас не активна") return end

    local crate=spawnCrate(point:GetPos(),"","",0)
    if not IsValid(crate) then notify(p,false,"Не удалось создать ящик") return end

    crate:PhysicsDestroy()
    crate:SetSolid(SOLID_NONE)
    crate.GRMCarrier=p
    p.GRMCarriedCrate=crate
    p:SetNWBool("GRML_Carrying",true)
    crate:SetParent(p)
    crate:SetLocalPos(C.CarryOffset)
    crate:SetLocalAngles(C.CarryAngle)
    crate:SetMoveType(MOVETYPE_NONE)
    crate:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    notify(p,true,"Пустой ящик выдан в руки. R — поставить на землю.")
end

local function carryCrate(p,e)
    if not canUse(p,e) or IsValid(p.GRMCarriedCrate) then return end
    e:PhysicsDestroy()
    e:SetSolid(SOLID_NONE)
    e.GRMCarrier=p
    p.GRMCarriedCrate=e
    p:SetNWBool("GRML_Carrying",true)
    e:SetParent(p)
    e:SetLocalPos(C.CarryOffset)
    e:SetLocalAngles(C.CarryAngle)
    e:SetMoveType(MOVETYPE_NONE)
    e:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    notify(p,true,"Ящик в руках. R — поставить на землю")
end

local function storeCrate(p,e)
    if not canUse(p,e) then return end
    local crateID=id("crate"); L.InventoryCrates[sid(p)]=L.InventoryCrates[sid(p)] or {}; local kind,item,amount=crateCargo(e); local _,_,_,weapons=weaponCrateSummary(e); L.InventoryCrates[sid(p)][crateID]={kind=kind,id=item,amount=amount,weapons=weapons}
    if not addCrateToken(p,crateID) then L.InventoryCrates[sid(p)][crateID]=nil; notify(p,false,"Нет свободного слота инвентаря") return end
    e:Remove(); saveCrates(); notify(p,true,"Ящик убран в инвентарь")
end

local function openCrateInv(p)
    net.Start(NET.crateInv); net.WriteTable(L.InventoryCrates[sid(p)] or {}); net.Send(p)
end

local function extractCrate(p,crateID)
    local rec=L.InventoryCrates[sid(p)] and L.InventoryCrates[sid(p)][crateID]; if not rec then return end
    if not removeCrateToken(p,crateID) then notify(p,false,"Ящик не найден в инвентаре") return end
    L.InventoryCrates[sid(p)][crateID]=nil
    local crate=spawnCrate(p:GetPos()+p:GetForward()*50,rec.kind,rec.id,rec.amount)
    if IsValid(crate) and rec.weapons then crate.GRML_WeaponContents=rec.weapons end
    saveCrates()
end

local function findInventoryCrateRecord(ownerSteam,crateID)
    if ownerSteam and L.InventoryCrates[ownerSteam] and L.InventoryCrates[ownerSteam][crateID] then
        return ownerSteam,L.InventoryCrates[ownerSteam][crateID]
    end
    for steam,records in pairs(L.InventoryCrates) do
        if records[crateID] then return steam,records[crateID] end
    end
end

hook.Add("OnEntityCreated","GRML_DroppedInventoryCrate",function(ent)
    timer.Simple(0.15,function()
        if not IsValid(ent) or ent:GetClass()~="grm_item_drop" then return end
        if ent.ItemID~="logistics_crate" then return end
        local itemData=ent.ItemData or {}
        local crateID=itemData.crateID
        if not crateID then return end
        local owner,record=findInventoryCrateRecord(itemData.ownerSteam,crateID)
        if not record then return end
        local pos,angle=ent:GetPos(),ent:GetAngles()
        local crate=spawnCrate(pos,record.kind,record.id,record.amount)
        if IsValid(crate) then
            crate:SetAngles(angle)
            if record.weapons then crate.GRML_WeaponContents=record.weapons end
        end
        L.InventoryCrates[owner][crateID]=nil
        saveCrates()
        ent:Remove()
    end)
end)

local function registerCrateTokenItem(attempt)
    if not GRM or not GRM.Inventory or not GRM.Inventory.ItemDefs then
        attempt=(attempt or 0)+1
        if attempt<60 then timer.Simple(0.5,function()registerCrateTokenItem(attempt)end) end
        return
    end
    GRM.Inventory.ItemDefs.logistics_crate=GRM.Inventory.ItemDefs.logistics_crate or {
        type="item",name="Грузовой ящик",desc="Ящик логистики. Выбросьте его из инвентаря, чтобы поставить на землю.",icon="icon16/box.png",maxStack=1,weight=8,
    }
end
timer.Simple(0.5,registerCrateTokenItem)

local function loadCarried(route,crate)
    local kind,item,amount=crateCargo(crate)
    if kind=="" or item=="" or amount<=0 then
        if IsValid(crate.GRMCarrier) then notify(crate.GRMCarrier,false,"Сначала заполните ящик грузом") end
        return
    end
    local cargo={kind=kind,id=item,amount=amount}
    if kind=="weapon" then
        local total,pistols,automatics,contents=weaponCrateSummary(crate)
        local rules=C.WeaponCrate or {}
        if pistols<(rules.MinPistols or 2) or automatics<(rules.MinAutomatics or 5) then
            if IsValid(crate.GRMCarrier) then
                notify(crate.GRMCarrier,false,string.format("Оружейный ящик не заполнен: нужно %d пистолета и %d автоматов (сейчас %d/%d)",rules.MinPistols or 2,rules.MinAutomatics or 5,pistols,automatics))
            end
            return
        end
        cargo.amount=total
        cargo.weapons=contents
    end
    local p=crate.GRMCarrier
    crate:SetParent(NULL)
    if IsValid(p) then p.GRMCarriedCrate=nil; p:SetNWBool("GRML_Carrying",false) end
    route.cargo[#route.cargo+1]=cargo
    crate:Remove()
    local weaponCrates=0
    for _,c in ipairs(route.cargo) do if c.kind=="weapon" then weaponCrates=weaponCrates+1 end end
    if route.phase=="loading" and weaponCrates>=route.minimumWeaponCrates then
        route.phase="to_destination"
        setLoadingVisual(route.loading,false)
        syncRoute(route)
        global("Матовозка загружена и направляется на склад "..route.destination:GetFactionName())
    elseif IsValid(p) then
        notify(p,true,string.format("Ящик загружен. Оружейных ящиков: %d/%d",weaponCrates,route.minimumWeaponCrates))
        syncRoute(route)
    end
end

local function tryLoadCarriedCrate(p, crate)
    if not IsValid(crate) or crate.GRMCarrier~=p then return false end
    for _,route in pairs(L.Routes) do
        if route.phase=="loading" and IsValid(route.truck) then
            local truckCfg=truckConfig(route.truck) or {}
            local rear=route.truck:LocalToWorld(truckCfg.rearOffset or C.TruckRearOffset)
            if p:GetPos():DistToSqr(rear)<=C.LoadRadius^2 then
                loadCarried(route,crate)
                return true
            end
        end
    end
    notify(p,false,"Подойдите к задней зоне активной матовозки для загрузки")
    return false
end

hook.Add("KeyPress","GRML_LoadCarriedCrateUse",function(ply,key)
    if key==IN_USE and IsValid(ply.GRMCarriedCrate) then
        tryLoadCarriedCrate(ply,ply.GRMCarriedCrate)
        return true
    end
end)

local function deliver(route)
    local wh=route.destination; local data=warehouseData(wh); local accepted=true
    for _,c in ipairs(route.cargo) do
        if c.kind=="weapon" and c.weapons then
            for class,amount in pairs(c.weapons) do
                if not addStock(data,"weapon",class,amount) then accepted=false break end
            end
        elseif not addStock(data,c.kind,c.id,c.amount) then
            accepted=false
        end
        if not accepted then break end
    end
    if not accepted then notify(route.driver,false,"На складе недостаточно места для груза") return end
    L.SaveMap(nil) -- Авто-сохранение изменений склада на карту
    local reward=0; for _,c in ipairs(route.cargo) do reward=reward+(C.RewardPerCrate[c.kind]or 0) end
    if IsValid(route.driver) and GRM and GRM.GiveMoney then GRM.GiveMoney(route.driver,reward); notify(route.driver,true,"Доставка завершена. Награда: "..reward.." GRM") end
    global("Груз доставлен на склад фракции "..wh:GetFactionName())
    L.Routes[route.truck:EntIndex()]=nil; if IsValid(route.driver) then net.Start(NET.routeSync); net.WriteBool(false); net.Send(route.driver) end
end

local function isLoadingMarker(ent)
    return IsValid(ent) and ent:GetClass()=="grm_logistics_loading"
end

hook.Add("KeyPress","GRML_DropCarriedCrate",function(ply,key)
    if key~=IN_RELOAD then return end
    local crate=ply.GRMCarriedCrate
    if not IsValid(crate) or crate.GRMCarrier~=ply then return end
    crate:SetParent(NULL)
    crate.GRMCarrier=nil
    ply.GRMCarriedCrate=nil
    ply:SetNWBool("GRML_Carrying",false)
    crate:SetPos(ply:GetPos()+ply:GetForward()*48+Vector(0,0,12))
    crate:SetAngles(Angle(0,ply:EyeAngles().y,0))
    crate:SetSolid(SOLID_VPHYSICS)
    crate:PhysicsInit(SOLID_VPHYSICS)
    crate:SetMoveType(MOVETYPE_VPHYSICS)
    local phys=crate:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
    notify(ply,true,"Ящик поставлен на землю")
end)

hook.Add("PhysgunPickup","GRML_ProtectLoadingMarker",function(ply,ent)
    if isLoadingMarker(ent) then return false end
end)

hook.Add("CanTool","GRML_ProtectLoadingMarkerTool",function(ply,trace,tool)
    if trace and isLoadingMarker(trace.Entity) then return false end
end)

hook.Add("CanProperty","GRML_ProtectLoadingMarkerProperty",function(ply,property,ent)
    if isLoadingMarker(ent) then return false end
end)

timer.Create("GRML_RouteThink",0.4,0,function()
    for key,r in pairs(L.Routes) do
        if not IsValid(r.truck) then
            setLoadingVisual(r.loading, false)
            L.Routes[key]=nil
        elseif r.phase=="to_loading" and r.truck:GetPos():DistToSqr(r.loading:GetPos())<=C.CheckpointRadius^2 then
            r.phase="loading"
            setLoadingVisual(r.loading, true)
            syncRoute(r)
            global("Матовозка прибыла на погрузку: "..r.loading:GetPointName())
        elseif r.phase=="loading" then
            local truckCfg=truckConfig(r.truck) or {}
            local rear=r.truck:LocalToWorld(truckCfg.rearOffset or C.TruckRearOffset)
            for _,p in ipairs(player.GetAll()) do local crate=p.GRMCarriedCrate; if IsValid(crate) and crate.GRMCarrier==p and p:GetPos():DistToSqr(rear)<=C.LoadRadius^2 and #r.cargo<r.capacity then loadCarried(r,crate) break end end
        elseif r.phase=="to_destination" and r.truck:GetPos():DistToSqr(r.destination:GetPos())<=C.CheckpointRadius^2 then deliver(r) end
    end
end)

local function openWarehouse(p,e)
    if not canUse(p,e) or not memberOf(p,e:GetFactionName()) then notify(p,false,"Нет доступа к складу фракции") return end
    local payload=table.Copy(warehouseData(e))
    payload.admin=p:IsSuperAdmin()
    payload.faction=e:GetFactionName()
    payload.network=e:GetNetworkID()
    payload.armories={}
    payload.factions={}
    if payload.admin then
        for name in pairs(Factions or {}) do payload.factions[#payload.factions+1]=name end
        table.sort(payload.factions)
        for _,armory in ipairs(ents.FindByClass("grm_logistics_armory")) do
            if IsValid(armory) then
                local ad=armoryData(armory)
                payload.armories[#payload.armories+1]={
                    id=armory:GetLogisticsID(),
                    faction=armory:GetFactionName(),
                    network=armory:GetNetworkID(),
                    linked=ad.warehouseID==e:GetLogisticsID(),
                    pos=armory:GetPos(),
                }
            end
        end
    end
    net.Start(NET.warehouse); net.WriteEntity(e); net.WriteTable(payload); net.Send(p)
end

local function openArmory(p,e)
    if not canUse(p,e) or (e:GetFactionMode() and not memberOf(p,e:GetFactionName())) then notify(p,false,"Нет доступа к оружейному шкафу") return end
    local armory = armoryData(e)
    local supply = nil
    for _,x in ipairs(ents.FindByClass("grm_logistics_warehouse")) do
        if armory.warehouseID and x:GetLogisticsID()==armory.warehouseID then
            supply=warehouseData(x)
            break
        elseif not armory.warehouseID and x:GetFactionName()==e:GetFactionName() and x:GetNetworkID()==e:GetNetworkID() then
            supply=warehouseData(x)
        end
    end

    local myWeapons = {}
    for _,w in ipairs(p:GetWeapons()) do
        if IsValid(w) and w:GetClass()~="weapon_fists" and w:GetClass()~="grm_handcuffs" and w:GetClass()~="grm_cuffed" and w:GetClass()~="vehicle_keys_swep" and w:GetClass()~="ds_key_swep" then
            myWeapons[#myWeapons+1] = { class = w:GetClass(), name = w:GetPrintName() or w:GetClass() }
        end
    end

    local myItems = {}
    if invReady() then
        for _,s in pairs(GRM.Inventory.GetPlayerInv(p).slots or {}) do
            local d = GRM.Inventory.GetItemDef(s.id)
            if d and (d.type=="ammo" or d.type=="item") then
                myItems[#myItems+1] = { id = s.id, name = d.name or s.id, count = s.count or 1, type = d.type }
            end
        end
    end

    local payload={
        stock=armory.stock,
        supply=supply and supply.stock or {weapons={},items={}},
        myWeapons=myWeapons,
        myItems=myItems,
        admin=p:IsSuperAdmin(),
        faction=e:GetFactionName(),
        network=e:GetNetworkID(),
        mode=e:GetFactionMode(),
        warehouseID=armory.warehouseID or "",
        warehouses={},
        factions={},
    }
    if payload.admin then
        for name in pairs(Factions or {}) do payload.factions[#payload.factions+1]=name end
        table.sort(payload.factions)
        for _,warehouse in ipairs(ents.FindByClass("grm_logistics_warehouse")) do
            payload.warehouses[#payload.warehouses+1]={
                id=warehouse:GetLogisticsID(),
                faction=warehouse:GetFactionName(),
                network=warehouse:GetNetworkID(),
                linked=armory.warehouseID==warehouse:GetLogisticsID(),
            }
        end
    end
    net.Start(NET.armory); net.WriteEntity(e); net.WriteTable(payload); net.Send(p)
end

local function warehouseTake(p,e,kind,item,amount)
    if not canUse(p,e) or not memberOf(p,e:GetFactionName()) then return end
    local d=warehouseData(e); amount=math.max(1,math.floor(tonumber(amount)or 1)); if not takeStock(d,kind,item,amount) then notify(p,false,"Нет предмета на складе") return end
    if kind=="weapon" then if p:HasWeapon(item) then addStock(d,kind,item,amount); notify(p,false,"У вас уже есть оружие") return end; p:Give(item); refreshWeight(p)
    else local ok,err=add(p,item,amount); if not ok then addStock(d,kind,item,amount); notify(p,false,err) return end end
    L.SaveMap(nil) -- Сохраняем изменённые запасы на диск
    notify(p,true,"Предмет выдан со склада")
end

local function armoryRequest(p,e,kind,item,amount)
    if not canUse(p,e) or (e:GetFactionMode() and not memberOf(p,e:GetFactionName())) then return end
    local a=armoryData(e); local wh
    if a.warehouseID then
        for _,x in ipairs(ents.FindByClass("grm_logistics_warehouse")) do
            if x:GetLogisticsID()==a.warehouseID then wh=x break end
        end
    end
    if not IsValid(wh) then
        for _,x in ipairs(ents.FindByClass("grm_logistics_warehouse")) do
            if x:GetFactionName()==e:GetFactionName() and x:GetNetworkID()==e:GetNetworkID() then wh=x break end
        end
    end
    if not IsValid(wh) then notify(p,false,"Связанный склад не найден") return end
    local w=warehouseData(wh); amount=math.max(1,math.floor(tonumber(amount)or 1)); if not takeStock(w,kind,item,amount) then notify(p,false,"На центральном складе нет нужного груза") return end
    if not addStock(a,kind,item,amount) then addStock(w,kind,item,amount); notify(p,false,"В шкафу недостаточно места") return end
    L.SaveMap(nil) -- Сохраняем изменённые запасы шкафа и склада на диск
    notify(p,true,"Снабжение перемещено в шкаф")
end

local function armoryTake(p,e,kind,item,amount)
    if not canUse(p,e) or (e:GetFactionMode() and not memberOf(p,e:GetFactionName())) then return end
    local a=armoryData(e); amount=math.max(1,math.floor(tonumber(amount)or 1)); if not takeStock(a,kind,item,amount) then notify(p,false,"Нет предмета в шкафу") return end
    if kind=="weapon" then if p:HasWeapon(item) then addStock(a,kind,item,amount); notify(p,false,"У вас уже есть это оружие") return end; p:Give(item); refreshWeight(p)
    else local ok,err=add(p,item,amount); if not ok then addStock(a,kind,item,amount); notify(p,false,err) return end end
    L.SaveMap(nil) -- Сохраняем изменённые запасы шкафа на диск
    notify(p,true,"Предмет выдан")
end

local function armoryDepositActive(p,e)
    if not canUse(p,e) or (e:GetFactionMode() and not memberOf(p,e:GetFactionName())) then return end
    local w=p:GetActiveWeapon()
    if not IsValid(w) or w:GetClass()=="weapon_fists" then
        notify(p,false,"Возьмите в руки оружие, которое хотите положить в шкаф")
        return
    end
    local class=w:GetClass()
    if class=="grm_handcuffs" or class=="grm_cuffed" or class=="vehicle_keys_swep" or class=="ds_key_swep" then
        notify(p,false,"Служебный предмет нельзя положить в шкаф")
        return
    end
    local a=armoryData(e)
    if not addStock(a,"weapon",class,1) then
        notify(p,false,"В шкафу нет места для оружия")
        return
    end
    p:StripWeapon(class)
    refreshWeight(p)
    L.SaveMap(nil) -- Персистентное сохранение!
    notify(p,true,"Оружие положено в шкаф!")
    openArmory(p,e)
end

local function armoryDepositItem(p,e,kind,item,amount)
    if not canUse(p,e) or (e:GetFactionMode() and not memberOf(p,e:GetFactionName())) then return end
    local a=armoryData(e)
    amount=math.max(1,math.floor(tonumber(amount)or 1))
    if kind=="weapon" then
        local w=p:GetWeapon(item)
        if not IsValid(w) then notify(p,false,"У вас нет этого оружия") return end
        if not addStock(a,"weapon",item,1) then notify(p,false,"В шкафу нет места") return end
        p:StripWeapon(item)
        refreshWeight(p)
    else
        local ok,err=remove(p,item,amount)
        if not ok then notify(p,false,err) return end
        if not addStock(a,kind,item,amount) then
            add(p,item,amount)
            notify(p,false,"В шкафу нет места")
            return
        end
    end
    L.SaveMap(nil) -- Персистентное сохранение!
    notify(p,true,"Предмет положен в оружейный шкаф!")
    openArmory(p,e)
end

function L.UseEntity(p,e)
    local k=e.LogisticsKind
    if k=="loading" then openLoading(p,e) elseif k=="crate" then openCrate(p,e) elseif k=="warehouse" then openWarehouse(p,e) elseif k=="armory" then openArmory(p,e) end
end

-- actions
net.Receive(NET.action,function(_,p)
    local act=net.ReadString(); local e=net.ReadEntity()
    if act=="start_route" then startRoute(p,e,net.ReadString(),net.ReadString())
    elseif act=="pack" then packCrate(p,e,net.ReadString(),net.ReadString(),net.ReadUInt(8))
    elseif act=="loading_empty_crate" then createEmptyCrate(p,e)
    elseif act=="crate_pack_active" then packActiveWeaponIntoCrate(p,e)
    elseif act=="crate_carry" then carryCrate(p,e)
    elseif act=="crate_store" then storeCrate(p,e)
    elseif act=="crate_extract" then extractCrate(p,net.ReadString())
    elseif act=="crate_list" then openCrateInv(p)
    elseif act=="warehouse_take" then warehouseTake(p,e,net.ReadString(),net.ReadString(),net.ReadUInt(12))
    elseif act=="warehouse_scan" and IsValid(p) and p:IsSuperAdmin() and IsValid(e) and e.LogisticsKind=="warehouse" then
        openWarehouse(p,e)
    elseif act=="warehouse_link" and IsValid(p) and p:IsSuperAdmin() and IsValid(e) and e.LogisticsKind=="warehouse" then
        local armoryID=net.ReadString()
        local armory=findByID("grm_logistics_armory",armoryID)
        if not IsValid(armory) then notify(p,false,"Оружейный шкаф не найден") return end
        armory:SetFactionName(e:GetFactionName())
        armory:SetNetworkID(e:GetNetworkID())
        armoryData(armory).warehouseID=e:GetLogisticsID()
        L.SaveMap(nil)
        notify(p,true,"Шкаф связан со складом")
        openWarehouse(p,e)
    elseif act=="armory_request" then armoryRequest(p,e,net.ReadString(),net.ReadString(),net.ReadUInt(12))
    elseif act=="armory_take" then armoryTake(p,e,net.ReadString(),net.ReadString(),net.ReadUInt(12))
    elseif act=="armory_deposit_active" then armoryDepositActive(p,e)
    elseif act=="armory_deposit" then armoryDepositItem(p,e,net.ReadString(),net.ReadString(),net.ReadUInt(12))
    elseif act=="admin_open" and IsValid(p) and p:IsSuperAdmin() then local factions={};for name in pairs(Factions or{})do factions[#factions+1]=name end;table.sort(factions);net.Start(NET.admin);net.WriteTable({factions=factions,access=L.Access.factions,vehicles=L.Access.vehicles});net.Send(p)
    elseif act=="admin_access" and IsValid(p) and p:IsSuperAdmin() then L.Access.factions[net.ReadString()]=net.ReadBool(); saveAccess()
    elseif act=="admin_truck" and IsValid(p) and p:IsSuperAdmin() then local cls=net.ReadString(); L.Access.vehicles[cls]={capacity=net.ReadUInt(8),rearOffset=C.TruckRearOffset}; saveAccess()
    elseif act=="admin_warehouse" and IsValid(p) and p:IsSuperAdmin() then e:SetFactionName(net.ReadString()); e:SetNetworkID(net.ReadString()); local d=warehouseData(e); d.capacity=net.ReadTable() or d.capacity; L.SaveMap(nil)
    elseif act=="admin_armory" and IsValid(p) and p:IsSuperAdmin() then
        e:SetFactionName(net.ReadString()); e:SetNetworkID(net.ReadString()); e:SetFactionMode(net.ReadBool()); local d=armoryData(e); d.capacity=net.ReadTable() or d.capacity; L.SaveMap(nil); notify(p,true,"Настройки оружейного шкафа сохранены")
    elseif act=="armory_link" and IsValid(p) and p:IsSuperAdmin() and IsValid(e) and e.LogisticsKind=="armory" then
        local warehouseID=net.ReadString(); local warehouse=findByID("grm_logistics_warehouse",warehouseID)
        if not IsValid(warehouse) then notify(p,false,"Склад не найден") return end
        e:SetFactionName(warehouse:GetFactionName()); e:SetNetworkID(warehouse:GetNetworkID()); e:SetFactionMode(true)
        armoryData(e).warehouseID=warehouse:GetLogisticsID(); L.SaveMap(nil); notify(p,true,"Оружейный шкаф связан со складом")
    elseif act=="admin_loading" and IsValid(p) and p:IsSuperAdmin() then e:SetPointName(net.ReadString()); L.SaveMap(nil)
    elseif act=="refresh" then L.UseEntity(p,e) end
end)

concommand.Add("grm_logistics_start",function(p)
    local truck=resolveTruck(p)
    if not truck then
        local cur = IsValid(p) and p:InVehicle() and p:GetVehicle() or nil
        local hint = IsValid(cur) and (" Текущая сущность: " .. truckKeys(cur)) or ""
        notify(p,false,"Сядьте водителем в разрешённую матовозку." .. hint .. " (добавить: /logistics_admin или grm_logistics_addtruck)")
        return
    end
    if not canLogistics(p) then
        local f = factionOf(p)
        notify(p,false,f and ("Фракция «" .. f .. "» не имеет доступа к логистике (выдать: /logistics_admin)") or "Вы не во фракции с доступом к логистике")
        return
    end
    openRouteMenu(p,truck)
end)
concommand.Add("grm_logistics_crates",function(p) if IsValid(p) then openCrateInv(p) end end)
concommand.Add("grm_logistics_save",function(p) L.SaveMap(p) end)
concommand.Add("grm_logistics_load",function(p) L.LoadMap(p) end)

local function place(p,class,setup)
    if not IsValid(p) or not p:IsSuperAdmin() then return end
    local tr=util.TraceLine({start=p:EyePos(),endpos=p:EyePos()+p:GetAimVector()*300,filter=p,mask=MASK_ALL})
    local e=ents.Create(class); if not IsValid(e) then return end; e:SetPos(tr.HitPos+tr.HitNormal*5); e:SetAngles(Angle(0,p:EyeAngles().y+180,0)); e:Spawn(); e:Activate(); if setup then setup(e) end; L.SaveMap(nil); notify(p,true,"Логистическая entity установлена")
end

concommand.Add("grm_logistics_place_loading",function(p,_,a) place(p,"grm_logistics_loading",function(e)e:SetPointName(table.concat(a," ")~="" and table.concat(a," ")or"Точка погрузки")end) end)
concommand.Add("grm_logistics_place_warehouse",function(p,_,a) place(p,"grm_logistics_warehouse",function(e)e:SetFactionName(a[1]or"");e:SetNetworkID(a[2]or"MAIN")end) end)
concommand.Add("grm_logistics_place_armory",function(p,_,a) place(p,"grm_logistics_armory",function(e)e:SetFactionName(a[1]or"");e:SetNetworkID(a[2]or"MAIN");e:SetFactionMode(true)end) end)
concommand.Add("grm_logistics_access",function(p,_,a) if not IsValid(p) or not p:IsSuperAdmin() then return end; local faction=table.concat(a," "); if faction=="" then notify(p,false,"Использование: grm_logistics_access <фракция> <0/1>") return end; local enabled=tonumber(a[#a])~=0; if #a>1 then faction=table.concat(a," ",1,#a-1) end; L.Access.factions[faction]=enabled; saveAccess(); notify(p,true,"Доступ логистики: "..faction.." = "..tostring(enabled)) end)
concommand.Add("grm_logistics_addtruck",function(p,_,a) if not IsValid(p) or not p:IsSuperAdmin() then return end; local class=a[1];if not class then return end;L.Access.vehicles[class]={capacity=tonumber(a[2])or C.DefaultTruckCapacity,rearOffset=C.TruckRearOffset};saveAccess();notify(p,true,"Транспорт логистики добавлен")end)
concommand.Add("grm_logistics_admin",function(p) if not IsValid(p) or not p:IsSuperAdmin() then return end; local factions={}; for name in pairs(Factions or {}) do factions[#factions+1]=name end; table.sort(factions); net.Start(NET.admin);net.WriteTable({factions=factions,access=L.Access.factions,vehicles=L.Access.vehicles});net.Send(p) end)

-- единый обработчик команд логистики (вызывается из PlayerSayTransform
-- и из PlayerSay — защита от проглатывания чат-системами, паттерн н75)
local function chatStart(p)
    local truck=resolveTruck(p)
    if not truck then
        local cur = IsValid(p) and p:InVehicle() and p:GetVehicle() or nil
        local hint = IsValid(cur) and (" Текущая сущность: " .. truckKeys(cur)) or ""
        notify(p,false,"Сядьте водителем в разрешённую матовозку." .. hint .. " (добавить: /logistics_admin или grm_logistics_addtruck)")
        return
    end
    if not canLogistics(p) then
        local f = factionOf(p)
        notify(p,false,f and ("Фракция «" .. f .. "» не имеет доступа к логистике (выдать: /logistics_admin)") or "Вы не во фракции с доступом к логистике")
        return
    end
    openRouteMenu(p,truck)
end
function L.HandleChat(p,text)
 local c=string.lower(string.Trim(text or ""))
 if c=="/logistics_start" or c=="!logistics_start" then chatStart(p); return true end
 if c=="/logistics_crates" or c=="!logistics_crates" then openCrateInv(p); return true end
 if (c=="/logistics_admin" or c=="!logistics_admin") and p:IsSuperAdmin() then local factions={};for name in pairs(Factions or{})do factions[#factions+1]=name end;table.sort(factions);net.Start(NET.admin);net.WriteTable({factions=factions,access=L.Access.factions,vehicles=L.Access.vehicles});net.Send(p);return true end
 return false
end
hook.Add("PlayerSayTransform","GRML_TransformCmds",function(p,datapack)
    if not istable(datapack) then return end
    local msg = datapack[1]
    if not isstring(msg) then return end
    if L.HandleChat and L.HandleChat(p, msg) then
        datapack[1] = ""
        datapack.SkipPlayerSay = true
    end
end)
hook.Add("PlayerSay","GRML_ChatCommands",function(p,text)
 if L.HandleChat and L.HandleChat(p,text) then return "" end
end)

-- диагностика (суперадмин): фракция, доступ, распознавание матовозки
concommand.Add("grm_logistics_debug",function(p)
    if not IsValid(p) or not p:IsSuperAdmin() then return end
    local f = factionOf(p)
    print("[GRM Logistics][DEBUG] игрок " .. p:Nick() .. ": фракция=" .. tostring(f) ..
        ", доступ=" .. tostring(f and L.Access.factions[f] == true) ..
        ", canLogistics=" .. tostring(canLogistics(p)))
    local acc = {}
    for k, v in pairs(L.Access.factions or {}) do if v then acc[#acc + 1] = k end end
    print("[GRM Logistics][DEBUG] доступные фракции: " .. table.concat(acc, ", "))
    local cur = p:InVehicle() and p:GetVehicle() or nil
    print("[GRM Logistics][DEBUG] в машине: " .. tostring(IsValid(cur)) ..
        (IsValid(cur) and (" | " .. truckKeys(cur)) or ""))
    print("[GRM Logistics][DEBUG] resolveTruck=" .. tostring(resolveTruck(p)))
    local tks = {}
    for k in pairs(L.Access.vehicles or {}) do tks[#tks + 1] = k end
    table.sort(tks)
    print("[GRM Logistics][DEBUG] ключи транспорта доступа: " .. table.concat(tks, ", "))
    notify(p, true, "Диагностика логистики — см. консоль сервера")
end)

-- map persistence
local function record(e) local r={class=e:GetClass(),id=e:GetLogisticsID(),pos=vec(e:GetPos()),ang=ang(e:GetAngles()),faction=e:GetFactionName(),network=e:GetNetworkID(),name=e:GetPointName(),mode=e:GetFactionMode()}; if e.LogisticsKind=="warehouse" then r.data=warehouseData(e) elseif e.LogisticsKind=="armory" then r.data=armoryData(e) end return r end

function L.SaveMap(p)
    if IsValid(p) and not p:IsSuperAdmin() then notify(p,false,"Только superadmin") return 0 end
    ensure(); local list={}; for cls in pairs(EQUIP) do for _,e in ipairs(ents.FindByClass(cls)) do list[#list+1]=record(e) end end; write(MAPFILE,list); if IsValid(p) then notify(p,true,"Сохранено логистики: "..#list) end; return #list
end

function L.LoadMap(p)
    if IsValid(p) and not p:IsSuperAdmin() then return 0 end; local list=read(MAPFILE,{}); for cls in pairs(EQUIP) do for _,e in ipairs(ents.FindByClass(cls)) do e:Remove() end end
    L.Warehouses={}; L.Armories={}; local n=0
    for _,r in ipairs(list) do if EQUIP[r.class] then local e=ents.Create(r.class); if IsValid(e) then e:SetPos(V(r.pos)); e:SetAngles(A(r.ang)); e:Spawn(); e:Activate(); e:SetLogisticsID(r.id or id("log")); e:SetFactionName(r.faction or ""); e:SetNetworkID(r.network or ""); e:SetPointName(r.name or ""); e:SetFactionMode(r.mode~=false); if e.LogisticsKind=="warehouse" then L.Warehouses[e:GetLogisticsID()]=r.data or {stock={weapons={},items={}},capacity=table.Copy(C.Capacity)} elseif e.LogisticsKind=="armory" then L.Armories[e:GetLogisticsID()]=r.data or {stock={weapons={},items={}},capacity=table.Copy(C.Capacity)} end; local ph=e:GetPhysicsObject(); if IsValid(ph) then ph:EnableMotion(false) end; n=n+1 end end end; return n
end

hook.Add("InitPostEntity","GRML_Load",function() timer.Simple(5,function() L.LoadMap(nil) end) end)
-- Код 90: кнопка cleanup в spawnmenu раньше стирала точки до рестарта карты —
-- как в Alarm/CCTV, воскрешаем из того же сейва.
hook.Add("PostCleanupMap","GRML_Reload",function() timer.Simple(1,function() L.LoadMap(nil) end) end)
hook.Add("ShutDown","GRML_Save",function()
    saveCrates()
    saveAccess()
    L.SaveMap(nil) -- Защита при рестарте: гарантированное сохранение всех оружейных шкафов
end)

print("[GRM Logistics] server v1.2.1 — автосейв стока + воскрешение после cleanup (Код 90)")
