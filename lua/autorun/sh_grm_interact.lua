--[[--------------------------------------------------------------------
    GRM Interact — интерактивное взаимодействие с дверями и транспортом.

    ЗАКАЗ ВЛАДЕЛЬЦА (31.08): «при подходе к двери у персонажа появлялась
    точка маленькая, и подсказка нажмите Е для взаимодействия, возникает
    возле двери опять же круговое интерактивное живое меню с функцией
    открыть/закрыть и т.д., тоже самое касается двери машины. Можно
    конечно и свеп сохранить… нужно соблюсти стилистику проекта, и при
    этом чтобы текст не был чёрным».

    ЧТО БЫЛО. Управление замками жило только в SWEP «Дверные ключи»:
    надо достать оружие, прицелиться, помнить, что ЛКМ запирает, а ПКМ
    отпирает. У транспорта — свой SWEP со своими правилами. Никакой
    подсказки при подходе не было.

    ЧТО ЗДЕСЬ. Общая точка взаимодействия: подошёл — видишь точку и
    подсказку, зажал E — кольцевое меню с действиями именно для этого
    объекта. SWEP'ы никуда не делись, они работают параллельно.

    ПОЧЕМУ ОБЩИЙ МОДУЛЬ, А НЕ ДВА. Двери и транспорт отличаются только
    набором действий и проверкой прав. Всё остальное — поиск цели,
    подсказка, кольцо, сетевой обмен — одинаково. Два отдельных модуля
    означали бы две копии одного кода и, как это уже бывало в проекте,
    починку только одной из них.

    БЕЗОПАСНОСТЬ. Клиент присылает только «объект + id действия».
    Сервер сам находит цель, сам проверяет дистанцию и права —
    существующими функциями GRM.Doors / VehicleKeys, ничего не
    дублируя. Подделать пакет и открыть чужую дверь нельзя.
----------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Interact = GRM.Interact or {}
local I = GRM.Interact
I.Version = "1.0.0"

I.Range = 130            -- дистанция взаимодействия, юниты
I.HintRange = 150        -- на какой дистанции показывать точку и подсказку

local NET_ACT = "GRM_Interact_Act"

-----------------------------------------------------------------------
-- ОБЩЕЕ: определение цели и список действий.
-- Живёт в shared, чтобы клиент рисовал ровно то, что разрешит сервер.
-----------------------------------------------------------------------

--[[ Что перед игроком: дверь, транспорт или ничего.

     Возвращает сущность и вид ("door" / "vehicle"). Отдельной
     функцией: её зовут и клиент (для подсказки), и сервер (для
     проверки) — расхождение здесь означало бы «вижу меню, но действие
     не проходит». ]]
function I.FindTarget(ply, range)
    if not IsValid(ply) then return nil end
    range = range or I.Range

    local tr = util.TraceLine({
        start = ply:GetShootPos(),
        endpos = ply:GetShootPos() + ply:GetAimVector() * range,
        filter = ply,
        mask = MASK_SHOT,
    })
    local ent = tr.Entity
    if not IsValid(ent) then return nil end

    local D = GRM.Doors
    if D and D.IsDoor then
        if D.IsDoor(ent) then return ent, "door" end
        -- Дверная ручка/косяк бывает отдельным энтити на родителе.
        local parent = ent:GetParent()
        if IsValid(parent) and D.IsDoor(parent) then return parent, "door" end
    end

    --[[ Модуль ключей ТС живёт в глобальной таблице VK, а не в
         GRM.VehicleKeys: так он объявлен в sh_vehicle_keys.lua. ]]
    local V = _G.VK
    if V and V.IsVehicle and V.IsVehicle(ent) then return ent, "vehicle" end
    -- Сиденья и части машины: у них родитель — сам транспорт.
    local vp = ent:GetParent()
    if IsValid(vp) and V and V.IsVehicle and V.IsVehicle(vp) then return vp, "vehicle" end

    return nil
end

--[[ Действия для цели. Один список на клиента и сервер: клиент рисует
     его в кольце, сервер по нему же проверяет, что пришло.

     Каждое действие: id, подпись, и признак «доступно ли сейчас».
     Недоступные не прячем, а показываем приглушёнными — иначе игрок не
     понимает, чего ему не хватает. ]]
function I.Actions(ply, ent, kind)
    local out = {}
    if not IsValid(ply) or not IsValid(ent) then return out end

    if kind == "door" then
        local D = GRM.Doors
        if not D then return out end
        local locked = D.IsDoorLocked and D.IsDoorLocked(ent) or false

        --[[ Право на замок спрашиваем у ядра дверей. Своей проверки
             здесь нет намеренно: правила категорий, совладельцев и
             ордеров живут там, и вторая их копия неизбежно разойдётся
             с первой. ]]
        local canLock, lockWhy = true, nil
        if D.CanToggleLock then
            canLock, lockWhy = D.CanToggleLock(ply, ent, not locked)
        end

        out[#out + 1] = {
            id = locked and "door_unlock" or "door_lock",
            name = locked and "Отпереть" or "Запереть",
            enabled = canLock ~= false,
            why = lockWhy,
            accent = locked and "good" or "warn",
        }
        out[#out + 1] = { id = "door_knock", name = "Постучать", enabled = true }
        out[#out + 1] = { id = "door_menu", name = "Управление", enabled = true }
        return out
    end

    if kind == "vehicle" then
        local V = _G.VK
        if not V then return out end
        --[[ Состояние замка читаем из NW2: сервер синхронизирует его
             именно так (VK.SyncVehicle), и на клиенте поле ent.VK_Locked
             пустое — там оно только серверное. ]]
        local locked = ent:GetNW2Bool("VK_Locked", false)
        if SERVER then locked = ent.VK_Locked == true end
        local can = V.CanInteract and V.CanInteract(ent, ply, false) or false

        out[#out + 1] = {
            id = locked and "veh_unlock" or "veh_lock",
            name = locked and "Отпереть" or "Запереть",
            enabled = can,
            why = not can and "Нет ключа или доступа" or nil,
            accent = locked and "good" or "warn",
        }
        out[#out + 1] = {
            id = "veh_doors", name = "Открыть двери", enabled = can,
            why = not can and "Нет ключа или доступа" or nil,
        }
        out[#out + 1] = {
            id = "veh_trunk", name = "Багажник", enabled = can,
            why = not can and "Нет ключа или доступа" or nil,
        }
        return out
    end

    return out
end

-- Название цели для шапки кольца.
function I.TargetName(ent, kind)
    if not IsValid(ent) then return "" end
    if kind == "door" then
        local t = ent:GetNWString("GRM_DoorTitle", "")
        if t ~= "" then return t end
        return "Дверь"
    end
    if kind == "vehicle" then
        local V = _G.VK
        if V and V.GetVehicleDisplayName then
            local n = V.GetVehicleDisplayName(ent)
            if n and n ~= "" then return n end
        end
        return "Транспорт"
    end
    return ""
end

-- Подпись под названием: владелец и состояние замка.
function I.TargetSub(ent, kind)
    if not IsValid(ent) then return "", false end
    if kind == "door" then
        local locked = ent:GetNWBool("GRM_DoorLocked", false)
        local owner = ent:GetNWString("GRM_DoorOwner", "")
        return owner, locked
    end
    if kind == "vehicle" then
        -- NW2: см. VK.SyncVehicle. Имя поля владельца — VK_OwnerNick.
        local locked = ent:GetNW2Bool("VK_Locked", false)
        local owner = ent:GetNW2String("VK_OwnerNick", "")
        local fac = ent:GetNW2String("VK_FactionName", "")
        if owner == "" and fac ~= "" then owner = fac end
        return owner, locked
    end
    return "", false
end

-----------------------------------------------------------------------
if SERVER then
-----------------------------------------------------------------------
util.AddNetworkString(NET_ACT)

local function notify(ply, msg, r, g, b)
    if GRM.Notify then GRM.Notify(ply, msg, r or 255, g or 255, b or 255) end
end

--[[ Выполнение действия.

     Клиент присылает ТОЛЬКО сущность и id действия. Сервер заново
     находит цель, меряет дистанцию и спрашивает права у профильного
     модуля. Иначе поддельный пакет открывал бы любую дверь на карте. ]]
local function runAction(ply, ent, id)
    if not IsValid(ply) or not IsValid(ent) then return end

    -- Дистанция: меряем от глаз до ближайшей точки объекта, а не до
    -- его центра — у длинных ворот центр далеко, и честный игрок
    -- получал бы отказ.
    local near = ent:NearestPoint(ply:GetShootPos())
    if ply:GetShootPos():DistToSqr(near) > (I.Range * 1.35) ^ 2 then
        notify(ply, "Слишком далеко", 255, 160, 90)
        return
    end
    if not ply:Alive() then return end

    local kind
    if GRM.Doors and GRM.Doors.IsDoor and GRM.Doors.IsDoor(ent) then kind = "door"
    elseif _G.VK and _G.VK.IsVehicle and _G.VK.IsVehicle(ent) then kind = "vehicle" end
    if not kind then return end

    --[[ Действие обязано быть в списке, который СЕРВЕР считает
         допустимым для этой цели. Клиент мог прислать «veh_lock» для
         двери или действие, которое ему недоступно. ]]
    local allowed
    for _, a in ipairs(I.Actions(ply, ent, kind)) do
        if a.id == id then allowed = a break end
    end
    if not allowed then return end
    if allowed.enabled == false then
        ply:EmitSound("buttons/button10.wav", 65, 100, 0.7)
        notify(ply, tostring(allowed.why or "Недоступно"), 255, 100, 100)
        return
    end

    local D, V = GRM.Doors, _G.VK

    if id == "door_lock" or id == "door_unlock" then
        local want = (id == "door_lock")
        local okRun, _, forced = D.LockDoor(ent, want)
        if okRun == false then
            notify(ply, "Замок не поддаётся.", 255, 100, 100)
            return
        end
        if forced then
            ply:EmitSound("buttons/button10.wav", 65, 100, 0.7)
            notify(ply, "Эта дверь всегда заперта.", 255, 180, 90)
            return
        end
        ply:EmitSound(want and "doors/door_latch1.wav" or "doors/door_latch3.wav", 65, 100)
        notify(ply, want and "Дверь заперта." or "Дверь отперта.", 120, 220, 140)
        return
    end

    if id == "door_knock" then
        --[[ Стук слышат вокруг двери, а не только владелец: это
             отыгрышное действие, его смысл в том, чтобы человек за
             дверью услышал. ]]
        ent:EmitSound("physics/wood/wood_crate_impact_hard2.wav", 75, 100)
        notify(ply, "Вы постучали.", 200, 210, 225)
        return
    end

    if id == "door_menu" then
        if D.OpenDoorMenu then D.OpenDoorMenu(ply) end
        return
    end

    if id == "veh_lock" or id == "veh_unlock" then
        if V.ToggleLock then V.ToggleLock(ply, ent) end
        return
    end

    if id == "veh_doors" then
        if V.ToggleDoors then
            V.ToggleDoors(ent)
            notify(ply, "Двери транспорта переключены.", 120, 220, 140)
        end
        return
    end

    if id == "veh_trunk" then
        --[[ Багажник — отдельная система, и доступ она проверяет сама
             (та же точка входа, что у C-меню). Свою проверку прав тут
             не пишем: разошлась бы с той. Модуля нет в сборке —
             честно говорим, а не молчим: молчание игрок читает как
             «кнопка сломана». ]]
        if GRM.Trunk and GRM.Trunk.RequestToggle then
            GRM.Trunk.RequestToggle(ply)
        else
            notify(ply, "Модуль багажника не загружен.", 255, 180, 90)
        end
        return
    end
end

net.Receive(NET_ACT, function(len, ply)
    --[[ Ограничитель: кольцо открывается часто, но действия — редко.
         Без него скриптом можно было бы щёлкать замком десятки раз в
         секунду и спамить звуком на всю улицу. ]]
    if GRM.Net and GRM.Net.Guard then
        if not GRM.Net.Guard(ply, "interact.act",
            { rate = 0.3, burst = 4, maxBits = 256 }, { bits = len }) then
            return
        end
    end
    local ent = net.ReadEntity()
    local id = string.sub(tostring(net.ReadString() or ""), 1, 32)
    runAction(ply, ent, id)
end)

print("[GRM Interact] server v" .. I.Version)
return
end

-----------------------------------------------------------------------
-- CLIENT
-----------------------------------------------------------------------
CreateClientConVar("grm_cl_interact", "1", true, false,
    "Показывать точку и подсказку взаимодействия у дверей и транспорта")

surface.CreateFont("GRMInt_Name", { font = "Roboto", size = 19, weight = 700, extended = true })
surface.CreateFont("GRMInt_Hint", { font = "Roboto", size = 15, weight = 600, extended = true })
surface.CreateFont("GRMInt_Small", { font = "Roboto", size = 13, weight = 500, extended = true })
surface.CreateFont("GRMInt_Ring", { font = "Roboto", size = 17, weight = 600, extended = true })

--[[ ПАЛИТРА — та же, что у остальных окон GRM (тёмный фон, светлый
     текст).

     Владелец 31.08 отдельно предупредил: «чтобы текст не был чёрным
     как иногда вы выдаёте, что фон меню тёмный, текст чёрный и ничего
     нечитабельно». Поэтому здесь НЕТ ни одного тёмного цвета текста, а
     все надписи поверх мира рисуются с чёрной обводкой — на светлой
     стене белый текст без неё тоже теряется. ]]
local C = {
    bg      = Color(16, 20, 28, 238),
    ring    = Color(10, 13, 19, 205),
    sector  = Color(62, 132, 220, 110),
    card    = Color(33, 41, 55, 245),
    text    = Color(236, 242, 250),
    dim     = Color(158, 172, 190),
    gold    = Color(245, 195, 65),
    good    = Color(104, 214, 138),
    warn    = Color(240, 170, 90),
    bad     = Color(226, 96, 92),
    shadow  = Color(0, 0, 0, 225),
}

local R = {
    open = false,
    items = {},
    sel = nil,
    ent = nil,
    kind = nil,
}
I.Radial = R
R.InnerR = 92
R.OuterR = 230
R.LabelR = 162

local hover = { ent = nil, kind = nil, alpha = 0 }

--[[ Выбор пункта по УГЛУ от центра — как в меню соц.анимаций: вести
     мышь в сторону быстрее, чем попадать в мелкую цель. Внутри
     мёртвой зоны выбора нет: это способ закрыть кольцо, ничего не
     сделав. ]]
function R.Pick(mx, my, cx, cy, count)
    if count <= 0 then return nil end
    local dx, dy = mx - cx, my - cy
    if math.sqrt(dx * dx + dy * dy) < R.InnerR then return nil end
    -- Экранный Y растёт вниз, поэтому -dy: иначе кольцо зеркальное.
    local ang = math.deg(math.atan2(dx, -dy))
    if ang < 0 then ang = ang + 360 end
    local step = 360 / count
    local idx = math.floor((ang + step * 0.5) / step) + 1
    if idx > count then idx = idx - count end
    return idx
end

function R.SlotPos(i, count, cx, cy, radius)
    local a = math.rad((i - 1) * (360 / count) - 90)
    return cx + math.cos(a) * radius, cy + math.sin(a) * radius
end

function I.CloseRadial()
    R.open = false
    R.items, R.sel, R.ent, R.kind = {}, nil, nil, nil
    if IsValid(R.panel) then R.panel:Remove() end
    R.panel = nil
    gui.EnableScreenClicker(false)
end

function I.OpenRadial(ent, kind)
    if IsValid(R.panel) then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not IsValid(ent) then return end

    R.items = I.Actions(ply, ent, kind)
    if #R.items == 0 then return end
    R.ent, R.kind, R.sel = ent, kind, nil

    local f = vgui.Create("DPanel")
    R.panel = f
    R.open = true
    f:SetSize(ScrW(), ScrH())
    f:SetPos(0, 0)
    f:SetPaintBackground(false)
    f:MakePopup()
    -- Клавиатуру не забираем: иначе не придёт отпускание E и кольцо
    -- зависнет (ровно этим болел инвентарь).
    f:SetKeyboardInputEnabled(false)
    gui.EnableScreenClicker(true)
    f.OnRemove = function() R.open = false R.panel = nil end

    f.Paint = function(_, w, h)
        local cx, cy = w * 0.5, h * 0.5
        local mx, my = gui.MousePos()
        local count = #R.items
        R.sel = R.Pick(mx, my, cx, cy, count)

        -- Затемняем ТОЛЬКО круг под меню: мир должно быть видно.
        surface.SetDrawColor(C.ring)
        draw.NoTexture()
        local poly = {}
        for i = 0, 64 do
            local a = math.rad(i / 64 * 360)
            poly[#poly + 1] = { x = cx + math.cos(a) * R.OuterR, y = cy + math.sin(a) * R.OuterR }
        end
        surface.DrawPoly(poly)

        -- Подсветка сектора: КОЛЬЦЕВАЯ, чтобы не заливать центр.
        if R.sel then
            local full = 360 / count
            local step = math.min(full, 120)
            local from = (R.sel - 1) * full - 90 - step * 0.5
            local ring = {}
            for i = 0, 20 do
                local a = math.rad(from + step * (i / 20))
                ring[#ring + 1] = { x = cx + math.cos(a) * R.OuterR, y = cy + math.sin(a) * R.OuterR }
            end
            for i = 20, 0, -1 do
                local a = math.rad(from + step * (i / 20))
                ring[#ring + 1] = { x = cx + math.cos(a) * R.InnerR, y = cy + math.sin(a) * R.InnerR }
            end
            surface.SetDrawColor(C.sector)
            draw.NoTexture()
            surface.DrawPoly(ring)
        end

        -- Центр: что это за объект и заперт ли он.
        local name = I.TargetName(R.ent, R.kind)
        local owner, locked = I.TargetSub(R.ent, R.kind)
        draw.SimpleText(name, "GRMInt_Name", cx, cy - 16, C.text,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(locked and "ЗАПЕРТО" or "ОТКРЫТО", "GRMInt_Small", cx, cy + 6,
            locked and C.bad or C.good, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if owner ~= "" then
            draw.SimpleText(owner, "GRMInt_Small", cx, cy + 26, C.dim,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Пункты по кольцу.
        for i, act in ipairs(R.items) do
            local lx, ly = R.SlotPos(i, count, cx, cy, R.LabelR)
            local on = (R.sel == i)
            local col = C.text
            if act.enabled == false then col = Color(150, 120, 120)
            elseif on then col = Color(255, 255, 255)
            elseif act.accent == "good" then col = C.good
            elseif act.accent == "warn" then col = C.warn end
            draw.SimpleTextOutlined(act.name, "GRMInt_Ring", lx, ly, col,
                TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, C.shadow)
            -- Почему пункт недоступен — видно сразу, без гадания.
            if act.enabled == false and on and act.why then
                draw.SimpleTextOutlined(act.why, "GRMInt_Small", cx, cy + R.OuterR + 18,
                    C.bad, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, C.shadow)
            end
        end

        draw.SimpleTextOutlined("отпустите E — применить  ·  ПКМ — отмена", "GRMInt_Small",
            cx, cy + R.OuterR + 40, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, C.shadow)
    end

    f.OnMousePressed = function(_, key)
        if key == MOUSE_RIGHT then I.CloseRadial() return end
        if key == MOUSE_LEFT then I.Apply() end
    end
end

function I.Apply()
    local act = R.sel and R.items[R.sel]
    local ent = R.ent
    I.CloseRadial()
    if not act or not IsValid(ent) then return end
    if act.enabled == false then
        surface.PlaySound("buttons/button10.wav")
        return
    end
    surface.PlaySound("common/wpn_select.wav")
    net.Start(NET_ACT)
        net.WriteEntity(ent)
        net.WriteString(act.id)
    net.SendToServer()
end

-----------------------------------------------------------------------
-- Точка и подсказка при подходе.
-----------------------------------------------------------------------
hook.Add("HUDPaint", "GRM_Interact_Hint", function()
    if R.open then return end
    if GetConVarNumber("grm_cl_interact") == 0 then return end
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:Alive() then return end
    if ply:InVehicle() then return end

    --[[ Общий трейс из глаз через GRM.Perf: один на кадр на все
         HUD-модули. Свой GetEyeTrace здесь означал бы ещё 60 трейсов
         в секунду поверх существующих. ]]
    local ent, kind = I.FindTarget(ply, I.HintRange)

    -- Плавное появление: моргающая подсказка раздражает сильнее, чем
    -- её отсутствие.
    local want = (ent ~= nil) and 1 or 0
    hover.alpha = math.Approach(hover.alpha, want, FrameTime() * 6)
    if ent then hover.ent, hover.kind = ent, kind end
    if hover.alpha <= 0.01 then return end

    local target = hover.ent
    if not IsValid(target) then return end

    local a = math.floor(hover.alpha * 255)
    local cx, cy = ScrW() * 0.5, ScrH() * 0.5

    -- Маленькая точка в центре экрана.
    surface.SetDrawColor(236, 242, 250, a)
    draw.NoTexture()
    local dot = {}
    for i = 0, 12 do
        local ang = math.rad(i / 12 * 360)
        dot[#dot + 1] = { x = cx + math.cos(ang) * 3, y = cy + math.sin(ang) * 3 }
    end
    surface.DrawPoly(dot)

    local name = I.TargetName(target, hover.kind)
    local _, locked = I.TargetSub(target, hover.kind)

    --[[ Текст СВЕТЛЫЙ и с обводкой. Тёмный текст на тёмной плашке —
         именно та беда, на которую жаловался владелец; а поверх мира
         даже светлый текст без обводки теряется на светлой стене. ]]
    draw.SimpleTextOutlined(name, "GRMInt_Hint", cx, cy + 22,
        Color(236, 242, 250, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, a))
    draw.SimpleTextOutlined(locked and "заперто" or "открыто", "GRMInt_Small", cx, cy + 40,
        locked and Color(226, 96, 92, a) or Color(104, 214, 138, a),
        TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, a))
    draw.SimpleTextOutlined("Удерживайте E — действия", "GRMInt_Small", cx, cy + 60,
        Color(158, 172, 190, a), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, a))
end)

-----------------------------------------------------------------------
-- Клавиша E: удержание открывает кольцо, отпускание применяет.
-----------------------------------------------------------------------
local holdStart, holdEnt, holdKind, armed = 0, nil, nil, false
I.HoldTime = 0.22        -- сколько держать, чтобы вместо обычного E пришло кольцо

hook.Add("PlayerButtonDown", "GRM_Interact_Use", function(ply, key)
    if ply ~= LocalPlayer() then return end
    if key ~= KEY_E then return end
    if GetConVarNumber("grm_cl_interact") == 0 then return end
    if gui.IsGameUIVisible() or gui.IsConsoleVisible() then return end
    if IsValid(ply) and ply.IsTyping and ply:IsTyping() then return end
    if R.open then return end

    local ent, kind = I.FindTarget(ply, I.Range)
    if not ent then return end
    holdStart, holdEnt, holdKind, armed = RealTime(), ent, kind, true
end)

--[[ Кольцо появляется по УДЕРЖАНИЮ, а короткое нажатие остаётся
     обычным E.

     Иначе мы сломали бы всю привычную игру: E открывает двери, садит в
     машину, поднимает предметы. Порог небольшой — за 0.22 с обычное
     нажатие успевает отработать, а осознанное удержание чувствуется
     мгновенным. ]]
hook.Add("Think", "GRM_Interact_Hold", function()
    if not armed or R.open then return end
    if RealTime() - holdStart < I.HoldTime then return end
    if not IsValid(holdEnt) then armed = false return end
    -- Клавишу всё ещё держат?
    if not input.IsKeyDown(KEY_E) then armed = false return end
    armed = false
    I.OpenRadial(holdEnt, holdKind)
end)

hook.Add("PlayerButtonUp", "GRM_Interact_UseUp", function(ply, key)
    if ply ~= LocalPlayer() then return end
    if key ~= KEY_E then return end
    armed = false
    if R.open then I.Apply() end
end)

--[[ Пока кольцо открыто, мышь не должна крутить игрока: курсором в нём
     выбирают действие. Та же беда была у радиального меню анимаций. ]]
hook.Add("StartCommand", "GRM_Interact_Freeze", function(ply, cmd)
    if not R.open then return end
    if ply ~= LocalPlayer() then return end
    cmd:ClearMovement()
    cmd:RemoveKey(IN_ATTACK)
    cmd:RemoveKey(IN_ATTACK2)
    --[[ E тоже снимаем: пока выбираем действие в кольце, обычное
         «использовать» срабатывать не должно — иначе дверь откроется
         сама ещё до выбора пункта. ]]
    cmd:RemoveKey(IN_USE)
    cmd:SetViewAngles(ply:EyeAngles())
    cmd:SetMouseX(0)
    cmd:SetMouseY(0)
end)

print("[GRM Interact] client v" .. I.Version)
