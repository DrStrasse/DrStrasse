--[[--------------------------------------------------------------------
    GRM Stove Slots v1.0.0 — конфорки плиты и притягивание посуды.

    ЗАКАЗ ВЛАДЕЛЬЦА (28.08):

      «models/hunter/blocks/cube025x025x025.mdl — над плитой, вернее на
       плите нужно четыре кубика, которые будут точками для установки
       на варочную плиту кастрюли или иной тары. Нужно чтобы тара
       ставилась на плиту, притягивалась сразу.»

    ЧТО БЫЛО. Плита работала «сама по себе»: рецепт выбирался в окне,
    посуда в мире была ни при чём. Поставить котёл на плиту было можно,
    но он просто стоял рядом физическим пропом — и падал от первого
    толчка.

    ЧТО ЭТО ДАЁТ.
      • Четыре КОНФОРКИ — кубики на варочной поверхности. Видно, куда
        ставить, и сразу понятно, сколько мест свободно.
      • ПРИТЯГИВАНИЕ: поднёс тару к плите, отпустил — она сама встаёт на
        ближайшую свободную конфорку, ровно и без физики. Не нужно
        целиться физганом.
      • Снял с конфорки — место освободилось.

    ПОЧЕМУ КУБИКИ КЛИЕНТСКИЕ. Конфорка это разметка, а не предмет: её
    нельзя взять, сломать или своровать. Держать ради этого четыре
    серверные entity на каждую плиту — лишняя нагрузка и лишние объекты
    в физике. Рисуем ClientsideModel, а занятость передаём одним числом.

    ЗАНЯТОСТЬ — БИТОВАЯ МАСКА. Четыре слота это 4 бита в одном Int
    вместо четырёх NetworkVar: меньше полей и меньше сетевого трафика.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.StoveSlots = GRM.StoveSlots or {}
local SS = GRM.StoveSlots

SS.Version = "1.0.0"

--- Модель конфорки, заказанная владельцем.
SS.CubeModel = "models/hunter/blocks/cube025x025x025.mdl"

--[[ Смещения четырёх конфорок в ЛОКАЛЬНЫХ координатах плиты, в долях
     её габарита. Доли, а не юниты: у разных моделей плит разный размер,
     и жёсткие числа развалились бы на первой же нестандартной модели.

     ПОЧЕМУ 0.24, А НЕ 0.42 (правка 28.08 по скриншоту владельца).
     OBB плиты описывает её ЦЕЛИКОМ — вместе с дверцами, ручками и
     нижней тумбой, которая шире варочной поверхности. Поэтому 0.42 от
     центра выносило кубики за край столешницы: они висели по углам в
     воздухе, а не на горелках.

     Настоящие конфорки у furniturestove001a стоят заметно ближе к
     середине, примерно на четверти габарита. ]]
SS.SlotOffsets = {
    { x = -0.24, y = -0.24 },
    { x = -0.24, y =  0.24 },
    { x =  0.24, y = -0.24 },
    { x =  0.24, y =  0.24 },
}

--- Насколько приподнять кубик над варочной поверхностью.
SS.CubeLift = 1

--[[ Масштаб кубика. 0.55 оказалось великовато — кубики перекрывали
     сами горелки и торчали за плиту. 0.34 сажает их ровно в круг
     конфорки: метка видна, но не закрывает то, что размечает. ]]
SS.CubeScale = 0.34

--- Радиус, в котором отпущенная тара притягивается к плите.
SS.SnapRange = 90

--- Что считается «тарой».
SS.Cookware = {
    grm_brew_kettle = { label = "котёл", lift = 2 },
}

--[[ Обычные пропы-ёмкости: их тоже логично ставить на плиту, но список
     держим отдельно — это не наши entity, и полагаться на их поведение
     нельзя. ]]
SS.CookwareModels = {
    ["models/props_c17/metalPot001a.mdl"] = { label = "кастрюля", lift = 0 },
    ["models/props_c17/metalPot002a.mdl"] = { label = "кастрюля", lift = 0 },
    ["models/props_junk/metalbucket01a.mdl"] = { label = "ведро", lift = 0 },
    ["models/props_junk/garbage_metalcan002a.mdl"] = { label = "бак", lift = 0 },
}

function SS.IsStove(ent)
    return IsValid(ent) and ent:GetClass() == "grm_food_stove"
end

--- Является ли entity тарой, которую можно поставить на плиту.
function SS.CookwareInfo(ent)
    if not IsValid(ent) then return nil end
    local byClass = SS.Cookware[ent:GetClass()]
    if byClass then return byClass end
    local mdl = string.lower(tostring(ent:GetModel() or ""))
    for path, info in pairs(SS.CookwareModels) do
        if string.lower(path) == mdl then return info end
    end
    return nil
end

--[[ Мировая позиция конфорки по её номеру. Считается одинаково на
     сервере и клиенте — иначе кубик рисовался бы не там, куда реально
     встаёт посуда. ]]
function SS.SlotPos(stove, index)
    if not IsValid(stove) then return nil end
    local off = SS.SlotOffsets[index]
    if not off then return nil end

    local mins, maxs = stove:OBBMins(), stove:OBBMaxs()
    if not (mins and maxs) then return nil end

    local sx = (maxs.x - mins.x)
    local sy = (maxs.y - mins.y)
    local local_ = Vector(
        (mins.x + maxs.x) * 0.5 + sx * off.x,
        (mins.y + maxs.y) * 0.5 + sy * off.y,
        maxs.z + SS.CubeLift)
    return stove:LocalToWorld(local_)
end

--- Занят ли слот (маска — Int с четырьмя битами).
function SS.SlotTaken(mask, index)
    mask = tonumber(mask) or 0
    return bit.band(mask, bit.lshift(1, index - 1)) ~= 0
end

function SS.SetSlotBit(mask, index, taken)
    mask = tonumber(mask) or 0
    local b = bit.lshift(1, index - 1)
    if taken then return bit.bor(mask, b) end
    return bit.band(mask, bit.bnot(b))
end

-----------------------------------------------------------------------
-- СЕРВЕР
-----------------------------------------------------------------------
if SERVER then

    --- Кто стоит на конфорках этой плиты: [stove] = { [index] = ent }
    SS.Occupied = SS.Occupied or {}

    local function maskOf(stove)
        local m = 0
        for i, ent in pairs(SS.Occupied[stove] or {}) do
            if IsValid(ent) then m = SS.SetSlotBit(m, i, true) end
        end
        return m
    end

    --- Обновить сетевое поле занятости (его читает клиент для подсветки).
    function SS.SyncMask(stove)
        if not IsValid(stove) then return end
        if stove.SetStoveSlots then stove:SetStoveSlots(maskOf(stove)) end
    end

    --- Первый свободный слот, ближайший к точке.
    function SS.FreeSlot(stove, nearPos)
        if not IsValid(stove) then return nil end
        local taken = SS.Occupied[stove] or {}
        local best, bestDist
        for i = 1, #SS.SlotOffsets do
            if not IsValid(taken[i]) then
                local pos = SS.SlotPos(stove, i)
                if pos then
                    local d = nearPos and pos:DistToSqr(nearPos) or i
                    if not bestDist or d < bestDist then best, bestDist = i, d end
                end
            end
        end
        return best
    end

    --- Снять тару с конфорки (она уехала, сломалась или её забрали).
    function SS.Release(ent)
        if not IsValid(ent) then return end
        local stove = ent.GRMStoveHost
        ent.GRMStoveHost, ent.GRMStoveSlot = nil, nil
        if not IsValid(stove) then return end
        local list = SS.Occupied[stove]
        if not list then return end
        for i, e in pairs(list) do
            if e == ent then list[i] = nil end
        end
        SS.SyncMask(stove)
    end

    --[[ Поставить тару на конфорку.

         Физику отключаем и замораживаем: посуда на плите не должна
         съезжать от толчка или взрыва. Родителем НЕ делаем — иначе
         игрок не сможет её снять физганом, а плиту начнёт таскать
         вместе с содержимым. ]]
    function SS.Snap(ent, stove, index)
        if not (IsValid(ent) and IsValid(stove)) then return false end
        local info = SS.CookwareInfo(ent)
        if not info then return false end

        index = index or SS.FreeSlot(stove, ent:GetPos())
        if not index then return false end

        local pos = SS.SlotPos(stove, index)
        if not pos then return false end

        -- Уже стояла где-то — освобождаем прежнее место.
        SS.Release(ent)

        --[[ Ставим НА конфорку: половину высоты предмета вверх, чтобы он
             не утонул в плите и не парил над ней. ]]
        local mins = ent:OBBMins()
        local lift = (mins and -mins.z or 0) + (tonumber(info.lift) or 0)
        ent:SetPos(pos + Vector(0, 0, lift))
        ent:SetAngles(Angle(0, stove:GetAngles().y, 0))

        local phys = ent:GetPhysicsObject()
        if IsValid(phys) then
            phys:EnableMotion(false)
            phys:Sleep()
        end

        SS.Occupied[stove] = SS.Occupied[stove] or {}
        SS.Occupied[stove][index] = ent
        ent.GRMStoveHost, ent.GRMStoveSlot = stove, index
        SS.SyncMask(stove)

        ent:EmitSound("physics/metal/metal_canister_impact_soft" .. math.random(1, 3) .. ".wav", 60, 105)
        hook.Run("GRM_StoveCookwarePlaced", stove, ent, index)
        return true, index
    end

    --- Ближайшая плита к точке.
    function SS.NearestStove(pos, radius)
        radius = tonumber(radius) or SS.SnapRange
        local list = (GRM.Perf and GRM.Perf.Entities)
            and GRM.Perf.Entities("grm_food_stove") or ents.FindByClass("grm_food_stove")
        local best, bestDist
        for _, e in ipairs(list or {}) do
            if IsValid(e) then
                local d = e:GetPos():DistToSqr(pos)
                if d <= radius * radius and (not bestDist or d < bestDist) then
                    best, bestDist = e, d
                end
            end
        end
        return best
    end

    --[[ Отпустили физганом — пробуем поставить на плиту. Именно здесь,
         а не в Think предмета: ловим ровно момент, когда игрок закончил
         действие, и не тратим кадры на постоянную проверку. ]]
    hook.Add("PhysgunDrop", "GRM_StoveSlots_Drop", function(ply, ent)
        if not SS.CookwareInfo(ent) then return end
        -- Сняли с плиты и унесли — освобождаем слот.
        if IsValid(ent.GRMStoveHost) then
            local host = ent.GRMStoveHost
            if ent:GetPos():DistToSqr(host:GetPos()) > (SS.SnapRange * 1.6) ^ 2 then
                SS.Release(ent)
                local phys = ent:GetPhysicsObject()
                if IsValid(phys) then phys:EnableMotion(true) phys:Wake() end
            end
        end
        local stove = SS.NearestStove(ent:GetPos(), SS.SnapRange)
        if not IsValid(stove) then return end
        local okSnap = SS.Snap(ent, stove)
        if okSnap and IsValid(ply) and GRM.Notify then
            local info = SS.CookwareInfo(ent)
            GRM.Notify(ply, "На плиту поставлено: " .. tostring(info and info.label or "тара"),
                140, 220, 160)
        end
    end)

    -- Тара уничтожена — слот обязан освободиться.
    hook.Add("EntityRemoved", "GRM_StoveSlots_Removed", function(ent)
        if IsValid(ent) and ent.GRMStoveHost then SS.Release(ent) end
        if SS.IsStove(ent) then SS.Occupied[ent] = nil end
    end)

    --- Сколько тары стоит на плите (для рецептов и подсказок).
    function SS.CountOn(stove)
        local n = 0
        for _, e in pairs(SS.Occupied[stove] or {}) do
            if IsValid(e) then n = n + 1 end
        end
        return n
    end

    concommand.Add("grm_stove_slots", function(ply)
        if not IsValid(ply) then return end
        local stove = SS.NearestStove(ply:GetPos(), 400)
        if not IsValid(stove) then
            ply:PrintMessage(HUD_PRINTTALK, "[Плита] Рядом нет плиты.")
            return
        end
        ply:PrintMessage(HUD_PRINTTALK, "[Плита] занято конфорок: "
            .. SS.CountOn(stove) .. " из " .. #SS.SlotOffsets)
        for i = 1, #SS.SlotOffsets do
            local e = (SS.Occupied[stove] or {})[i]
            ply:PrintMessage(HUD_PRINTTALK, ("  %d — %s"):format(i,
                IsValid(e) and tostring((SS.CookwareInfo(e) or {}).label or e:GetClass()) or "свободна"))
        end
    end)

    if GRM.Modules and GRM.Modules.Register then
        GRM.Modules.Register("stove_slots", {
            label = "Конфорки плиты",
            version = SS.Version,
        })
    end
end

-----------------------------------------------------------------------
-- КЛИЕНТ: кубики-конфорки
-----------------------------------------------------------------------
if CLIENT then
    --- Дальше этого расстояния конфорки не рисуем: бережём кадр.
    SS.DrawDistance = 400

    local COL_FREE  = Color(120, 200, 255)
    local COL_TAKEN = Color(255, 170, 80)
    local COL_COOK  = Color(255, 110, 60)

    --[[ Кубики создаём один раз на плиту и держим на ней же. Пересоздавать
         каждый кадр нельзя: ClientsideModel это выделение памяти. ]]
    local function ensureCubes(stove)
        if istable(stove.GRMSlotCubes) then return stove.GRMSlotCubes end
        local out = {}
        for i = 1, #SS.SlotOffsets do
            local m = ClientsideModel(SS.CubeModel, RENDERGROUP_TRANSLUCENT)
            if IsValid(m) then
                m:SetNoDraw(true)
                m:SetModelScale(SS.CubeScale, 0)
                out[i] = m
            end
        end
        stove.GRMSlotCubes = out
        return out
    end

    hook.Add("PostDrawTranslucentRenderables", "GRM_StoveSlots_Draw", function(depth, sky)
        if depth or sky then return end
        local lp = LocalPlayer()
        if not IsValid(lp) then return end

        local list = (GRM.Perf and GRM.Perf.Entities)
            and GRM.Perf.Entities("grm_food_stove") or ents.FindByClass("grm_food_stove")
        local eye = EyePos()

        for _, stove in ipairs(list or {}) do
            if IsValid(stove) and eye:DistToSqr(stove:GetPos()) <= SS.DrawDistance ^ 2 then
                local cubes = ensureCubes(stove)
                local mask = stove.GetStoveSlots and stove:GetStoveSlots() or 0
                local cooking = stove.GetStoveState and stove:GetStoveState() == 1

                for i = 1, #SS.SlotOffsets do
                    local cube = cubes[i]
                    local pos = SS.SlotPos(stove, i)
                    if IsValid(cube) and pos then
                        local taken = SS.SlotTaken(mask, i)
                        --[[ Занятая конфорка под готовкой светится
                             «горячим» цветом: сразу видно, что работает. ]]
                        local col = taken and (cooking and COL_COOK or COL_TAKEN) or COL_FREE
                        cube:SetPos(pos)
                        cube:SetAngles(Angle(0, stove:GetAngles().y, 0))
                        render.SetColorModulation(col.r / 255, col.g / 255, col.b / 255)
                        render.SetBlend(taken and 0.85 or 0.45)
                        cube:DrawModel()
                        render.SetBlend(1)
                        render.SetColorModulation(1, 1, 1)
                    end
                end
            end
        end
    end)

    -- Плита удалена — убираем её кубики, иначе останутся висеть в мире.
    hook.Add("EntityRemoved", "GRM_StoveSlots_Cleanup", function(ent)
        if not istable(ent.GRMSlotCubes) then return end
        for _, m in pairs(ent.GRMSlotCubes) do
            if IsValid(m) then m:Remove() end
        end
        ent.GRMSlotCubes = nil
    end)
end
