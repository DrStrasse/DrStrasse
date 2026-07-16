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

local function ensure() if not file.Exists(DIR,"DATA") then file.CreateDir(DIR) end if not file.Exists(MAPDIR,"DATA") then file.CreateDir(MAPDIR) end end
local function read(path, fallback) local raw=file.Exists(path,"DATA") and file.Read(path,"DATA") or ""; local ok,t=pcall(util.JSONToTable,raw); return ok and istable(t) and t or table.Copy(fallback or {}) end
local function write(path,t) ensure(); file.Write(path,util.TableToJSON(t or {},true)) end
local function vec(v) return {x=v.x,y=v.y,z=v.z} end
local function ang(a) return {p=a.p,y=a.y,r=a.r} end
local function V(t) return Vector(tonumber(t and(t.x or t[1]))or 0,tonumber(t and(t.y or t[2]))or 0,tonumber(t and(t.z or t[3]))or 0) end
local function A(t) return Angle(tonumber(t and(t.p or t[1]))or 0,tonumber(t and(t.y or t[2]))or 0,tonumber(t and(t.r or t[3]))or 0) end
local function id(prefix) return prefix.."_"..os.time().."_"..math.random(100000,999999) end
local function sid(p) return IsValid(p) and p:SteamID64() or "" end
local function notify(p,ok,msg) if not IsValid(p) then return end net.Start(NET.result) net.WriteBool(ok) net.WriteString(msg or "") net.Send(p) end
local function refreshWeight(p)
    if GRM and GRM.Encumbrance and GRM.Encumbrance.Refresh then GRM.Encumbrance.Refresh(p) end
end

L.Access = read(ACCESSFILE,{ factions={}, vehicles=C.Vehicles })
L.Access.factions = L.Access.factions or {}; L.Access.vehicles = L.Access.vehicles or C.Vehicles
L.InventoryCrates = read(CRATEFILE,{})

local function saveAccess() write(ACCESSFILE,L.Access) end
local function saveCrates() write(CRATEFILE,L.InventoryCrates) end

local function factionOf(p)
    if not IsValid(p) or not istable(Factions) then return nil,nil end
    for name,f in pairs(Factions) do
        if istable(f) and istable(f.Members) then
            local m=f.Members[p:SteamID()] or f.Members[p:SteamID64()]
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
    -- ownerSteam сохраняется в ItemData, чтобы выброшенный token можно было
    -- превратить обратно в настоящий грузовой ящик на земле.
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
    -- Старые сохранения могли иметь пустую таблицу capacity. Заполняем
    -- все отсутствующие категории значениями из конфига.
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

local function used(t) local n=0 for _,v in pairs(t or {}) do n=n+(tonumber(v)or 0) end return n end
local function category(kind,id) if kind=="weapon" then return "weapons" end if kind=="ammo" then return "ammo" end if id=="item_repair_kit" then return "repair" end if id=="item_healthkit" or id=="item_battery" then return "medical" end return "materials" end

local function addStock(data,kind,item,n)
    local cat=category(kind,item); local target=kind=="weapon" and data.stock.weapons or data.stock.items
    local cap=tonumber(data.capacity[cat]) or 0; local current=used(kind=="weapon" and data.stock.weapons or data.stock.items)
    if current+n>cap then return false end
    target[item]=(tonumber(target[item])or 0)+n; return true
end

local function takeStock(data,kind,item,n) local target=kind=="weapon" and data.stock.weapons or data.stock.items; if (tonumber(target[item])or 0)<n then return false end target[item]=target[item]-n if target[item]<=0 then target[item]=nil end return true end

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
        -- Маркер не блокирует игроков/машины, но остаётся доступным по E.
        e:SetSolid(SOLID_BBOX)
        e:SetMoveType(MOVETYPE_NONE)
        e:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
        e:SetCollisionBounds(Vector(-42,-42,0),Vector(42,42,90))
        setLoadingVisual(e, false) -- пока рейс не прибыл, маркер полностью прозрачен
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

-- simfphys/LVS often put a player into a child driver seat. The spawned
-- vehicle itself has another entity class, while Vehicle Dealer stores the
-- original configured classname in VD_Class. Check both values.
local function truckConfig(ent)
    if not IsValid(ent) then return nil end
    return L.Access.vehicles[ent.VD_Class or ""] or L.Access.vehicles[ent:GetClass()]
end

local function resolveTruck(p)
    if not IsValid(p) or not p:InVehicle() then return nil end
    local seat=p:GetVehicle()
    local e=seat
    local seen={}

    -- Standard vehicles and parent chains.
    for _=1,8 do
        if not IsValid(e) or seen[e] then break end
        seen[e]=true
        if truckConfig(e) then return e end
        local nw=e:GetNWEntity("Vehicle")
        if IsValid(nw) and truckConfig(nw) then return nw end
        e=e:GetParent()
    end

    -- simfphys/LVS fallback: locate the real vehicle by its driver seat.
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

-- Cargo is also mirrored in Lua fields. This avoids accidental NetworkVar
-- slot desync on freshly created empty crates.
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
    -- Стандартный оружейный ящик — строго 2 пистолета + 5 автоматов.
    -- РПГ, дробовики и прочее оружие в эту матовозную норму не входят.
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

    -- Сразу выдаём пустой ящик в руки. Физика удаляется полностью,
    -- поэтому модель не дёргается, не вращается и не болтается у ног.
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
    -- Уничтожаем physics object до SetParent: это исключает вращение,
    -- физическую вибрацию и рассинхрон ящика при анимации игрока.
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

-- GRM Inventory выбрасывает предмет как grm_item_drop. Перехватываем
-- token logistics_crate и заменяем его настоящим физическим ящиком.
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

-- E во время переноски — явная кнопка/действие загрузки ящика.
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
    local reward=0; for _,c in ipairs(route.cargo) do reward=reward+(C.RewardPerCrate[c.kind]or 0) end
    if IsValid(route.driver) and GRM and GRM.GiveMoney then GRM.GiveMoney(route.driver,reward); notify(route.driver,true,"Доставка завершена. Награда: "..reward.." GRM") end
    global("Груз доставлен на склад фракции "..wh:GetFactionName())
    L.Routes[route.truck:EntIndex()]=nil; if IsValid(route.driver) then net.Start(NET.routeSync); net.WriteBool(false); net.Send(route.driver) end
end

-- Точка погрузки — служебный маркер. Её нельзя таскать physgun'ом,
-- удалять remover/toolgun'ом или менять через property menu.
local function isLoadingMarker(ent)
    return IsValid(ent) and ent:GetClass()=="grm_logistics_loading"
end

-- R во время переноски ставит ящик на землю перед игроком.
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
            setLoadingVisual(r.loading, true) -- активация: красный маркер 50% прозрачности
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
    local payload={
        stock=armory.stock,
        supply=supply and supply.stock or {weapons={},items={}},
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
    notify(p,true,"Предмет выдан со склада")
end

local function armoryRequest(p,e,kind,item,amount)
    if not canUse(p,e) or (e:GetFactionMode() and not memberOf(p,e:GetFactionName())) then return end
    local a=armoryData(e); local wh
    -- Приоритет у явной связи, установленной superadmin через сканирование.
    if a.warehouseID then
        for _,x in ipairs(ents.FindByClass("grm_logistics_warehouse")) do
            if x:GetLogisticsID()==a.warehouseID then wh=x break end
        end
    end
    -- Обратная совместимость для уже настроенных шкафов по faction/network.
    if not IsValid(wh) then
        for _,x in ipairs(ents.FindByClass("grm_logistics_warehouse")) do
            if x:GetFactionName()==e:GetFactionName() and x:GetNetworkID()==e:GetNetworkID() then wh=x break end
        end
    end
    if not IsValid(wh) then notify(p,false,"Связанный склад не найден") return end
    local w=warehouseData(wh); amount=math.max(1,math.floor(tonumber(amount)or 1)); if not takeStock(w,kind,item,amount) then notify(p,false,"На центральном складе нет нужного груза") return end
    if not addStock(a,kind,item,amount) then addStock(w,kind,item,amount); notify(p,false,"В шкафу недостаточно места") return end
    notify(p,true,"Снабжение перемещено в шкаф")
end

local function armoryTake(p,e,kind,item,amount)
    if not canUse(p,e) or (e:GetFactionMode() and not memberOf(p,e:GetFactionName())) then return end
    local a=armoryData(e); amount=math.max(1,math.floor(tonumber(amount)or 1)); if not takeStock(a,kind,item,amount) then notify(p,false,"Нет предмета в шкафу") return end
    if kind=="weapon" then if p:HasWeapon(item) then addStock(a,kind,item,amount); notify(p,false,"У вас уже есть это оружие") return end; p:Give(item); refreshWeight(p)
    else local ok,err=add(p,item,amount); if not ok then addStock(a,kind,item,amount); notify(p,false,err) return end end
    notify(p,true,"Предмет выдан")
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

concommand.Add("grm_logistics_start",function(p) local truck=resolveTruck(p); if not truck then notify(p,false,"Сядьте водителем в разрешённую матовозку") return end if not canLogistics(p) then notify(p,false,"Нет доступа к логистике") return end openRouteMenu(p,truck) end)
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

hook.Add("PlayerSay","GRML_ChatCommands",function(p,text)
 local c=string.lower(string.Trim(text or ""))
 if c=="/logistics_start" or c=="!logistics_start" then local truck=resolveTruck(p);if not truck then notify(p,false,"Сядьте водителем в разрешённую матовозку") elseif not canLogistics(p) then notify(p,false,"Нет доступа к логистике") else openRouteMenu(p,truck) end; return "" end
 if c=="/logistics_crates" or c=="!logistics_crates" then openCrateInv(p); return "" end
 if (c=="/logistics_admin" or c=="!logistics_admin") and p:IsSuperAdmin() then local factions={};for name in pairs(Factions or{})do factions[#factions+1]=name end;table.sort(factions);net.Start(NET.admin);net.WriteTable({factions=factions,access=L.Access.factions,vehicles=L.Access.vehicles});net.Send(p);return "" end
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
hook.Add("ShutDown","GRML_Save",function() saveCrates(); saveAccess() end)

print("[GRM Logistics] server loaded")
