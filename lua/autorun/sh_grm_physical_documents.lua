--[[--------------------------------------------------------------------
    GRM Physical Documents v1.0.0 (Код 103)
    Физические копии документов в инвентаре: до 6 экземпляров каждого
    типа, просмотр владельца, дроп/подбор моделью бланка.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Documents = GRM.Documents or {}
local DOC = GRM.Documents
DOC.PhysicalVersion = "1.0.0"
DOC.MaxPhysicalCopies = 6

local NET_VIEW = "GRM_Doc_ReceiveView"

DOC.PhysicalDefs = {
    passport = { item="passport", registry="passports", template="passport", name="Паспорт гражданина", icon="icon16/book.png" },
    badge = { item="badge", registry="badges", template="badge", name="Служебное удостоверение", icon="icon16/shield.png" },
    military = { item="military_ticket", registry="military", template="military", name="Военный билет", icon="icon16/book_open.png" },
    license = { item="driver_license", registry="licenses", template="license", name="Водительское удостоверение", icon="icon16/car.png" },
    milLicense = { item="military_license", registry="milLicenses", template="militaryLicense", name="Удостоверение военного водителя ВАИ", icon="icon16/car.png" },
    weaponLicense = { item="weapon_license", registry="weaponLicenses", template="weaponLicense", name="Лицензия на оружие", icon="icon16/gun.png" },
    businessLicense = { item="business_license", registry="businessLicenses", template="businessLicense", name="Лицензия на ведение бизнеса", icon="icon16/briefcase.png" },
}

local ALIASES = {
    civilian_license="license", weapon_license="weaponLicense", business_license="businessLicense",
    license_mil="milLicense", military_license="milLicense",
}

function DOC.CanonicalPhysicalType(docType)
    docType=tostring(docType or "")
    return ALIASES[docType] or docType
end

local function keyOf(ply)
    if GRM.Identity and GRM.Identity.CharacterKey then return GRM.Identity.CharacterKey(ply) end
    return IsValid(ply) and (ply:SteamID64()..":char1") or ""
end

function DOC.PhysicalRecord(ownerKey,docType)
    docType=DOC.CanonicalPhysicalType(docType)
    local def=DOC.PhysicalDefs[docType]
    if not def or not istable(DOC.Registry) then return nil,nil,nil end
    local bucket=DOC.Registry[def.registry]
    local rec=istable(bucket) and bucket[tostring(ownerKey or "")] or nil
    return istable(rec) and rec or nil,def,docType
end

local function templateFor(def,rec)
    if def.template=="badge" then return (DOC.Templates and DOC.Templates.factions and DOC.Templates.factions[tostring(rec.faction or "")]) or {} end
    return (DOC.Templates and DOC.Templates[def.template]) or {}
end

local function registerItems()
    local INV=GRM.Inventory
    if not (INV and INV.RegisterItem and INV.RegisterUseHandler) then return false end
    for docType,def in pairs(DOC.PhysicalDefs) do
        INV.RegisterItem(def.item,{
            type="item",name=def.name,desc="Физический государственный бланк. Можно использовать, передать или выбросить на землю.",
            icon=def.icon,maxStack=1,weight=0.1,model="models/props_lab/clipboard.mdl",useFunc="doc_physical_view",
        })
    end
    local function usePhysical(ply,slotIdx,slot)
        local data=istable(slot and slot.data) and slot.data or {}
        local item=tostring(slot and slot.id or "")
        local typ=data.docType
        if not typ then for id,def in pairs(DOC.PhysicalDefs) do if def.item==item then typ=id break end end end
        typ=DOC.CanonicalPhysicalType(typ)
        local owner=tostring(data.ownerKey or keyOf(ply))
        local rec,def=DOC.PhysicalRecord(owner,typ)
        if not rec then if GRM.Notify then GRM.Notify(ply,"Запись документа отсутствует в государственном реестре.",255,130,110) end return false end
        net.Start(NET_VIEW)
            net.WriteString(typ)
            net.WriteTable(rec)
            net.WriteTable(templateFor(def,rec))
            net.WriteBool(false)
            net.WriteString("")
        net.Send(ply)
        return true
    end
    INV.RegisterUseHandler("doc_physical_view",usePhysical)
    -- Старые предметы до миграции имели отдельные useFunc и не содержали data.
    for _,handler in ipairs({"doc_passport_view","doc_badge_view","doc_military_view","doc_license_view","doc_mil_license_view"}) do INV.RegisterUseHandler(handler,usePhysical) end
    return true
end
DOC.RegisterPhysicalItems=registerItems

if SERVER then
    local function copyCount(ply,docType,ownerKey)
        local INV=GRM.Inventory
        local inv=INV and INV.GetPlayerInv and INV.GetPlayerInv(ply)
        if not inv then return 0 end
        local def=DOC.PhysicalDefs[DOC.CanonicalPhysicalType(docType)]
        if not def then return 0 end
        local n=0
        for _,slot in pairs(inv.slots or {}) do
            if istable(slot) and slot.id==def.item then
                local data=istable(slot.data) and slot.data or {}
                local slotOwner=tostring(data.ownerKey or keyOf(ply))
                if slotOwner==ownerKey then n=n+(tonumber(slot.count) or 1) end
            end
        end
        return n
    end
    DOC.CountPhysicalCopies=copyCount

    function DOC.GivePhysicalCopy(target,docType,ownerKey,issuer)
        if not IsValid(target) or not target:IsPlayer() then return false,"Получатель должен находиться в игре" end
        docType=DOC.CanonicalPhysicalType(docType); ownerKey=tostring(ownerKey or keyOf(target))
        local rec,def=DOC.PhysicalRecord(ownerKey,docType)
        if not rec and ownerKey==keyOf(target) and docType=="passport" and DOC.EnsurePassport then DOC.EnsurePassport(target); rec,def=DOC.PhysicalRecord(ownerKey,docType) end
        if not rec and ownerKey==keyOf(target) and docType=="badge" and DOC.EnsureBadge then DOC.EnsureBadge(target); rec,def=DOC.PhysicalRecord(ownerKey,docType) end
        if not rec or not def then return false,"Документ не найден в государственном реестре" end
        local count=copyCount(target,docType,ownerKey)
        if count>=DOC.MaxPhysicalCopies then return false,"Лимит физических копий этого документа: "..DOC.MaxPhysicalCopies end
        if not (GRM.Inventory and GRM.Inventory.AddItem) then return false,"Инвентарь не загружен" end
        local copyID="doc_"..os.time().."_"..math.random(100000,999999)
        local left=GRM.Inventory.AddItem(target,def.item,1,{docType=docType,ownerKey=ownerKey,number=tostring(rec.number or rec.series or ""),copyID=copyID,issuedAt=os.time(),issuedBy=IsValid(issuer) and issuer:Nick() or "Система"})
        if left~=0 then return false,"В инвентаре нет свободного места" end
        if GRM.Notify then GRM.Notify(target,"Получен физический бланк: "..def.name.." (копия "..tostring(count+1).."/"..DOC.MaxPhysicalCopies..")",100,220,140) end
        hook.Run("GRM_DocumentPhysicalIssued",target,docType,ownerKey,copyID,issuer)
        return true,copyID
    end

    local function findOnlineByKey(ownerKey)
        for _,p in ipairs(player.GetAll()) do if keyOf(p)==ownerKey then return p end end
    end

    local function handleCopyCommand(ply,text)
        local raw=string.Trim(tostring(text or "")); local low=string.lower(raw)
        if low~="/doccopy" and string.sub(low,1,9)~="/doccopy " then return false end
        local arg=string.Trim(string.sub(raw,9)); if arg=="" then ply:ChatPrint("[Документы] /doccopy passport|badge|military|license|milLicense|weaponLicense|businessLicense") return true end
        local ok,msg=DOC.GivePhysicalCopy(ply,arg,keyOf(ply),ply)
        if not ok and GRM.Notify then GRM.Notify(ply,msg,255,140,110) end
        return true
    end
    hook.Add("PlayerSayTransform","GRM_PhysicalDocs_Transform",function(ply,data) if istable(data) and isstring(data[1]) and handleCopyCommand(ply,data[1]) then data[1]="" data.SkipPlayerSay=true end end)
    hook.Add("PlayerSay","GRM_PhysicalDocs_Chat",function(ply,text) if handleCopyCommand(ply,text) then return "" end end)

    registerItems(); timer.Simple(2,registerItems); timer.Simple(6,registerItems)
end

if CLIENT then
    registerItems()
    timer.Simple(2,registerItems)
end

print("[GRM Physical Documents] v"..DOC.PhysicalVersion.." loaded")
