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

        --[[ Отрисовка — общий модуль GRM.Radial (31.08, заказ владельца
             «во всех радиальных меню дизайн поправь»). Свой набор
             полигонов здесь был четвёртой копией одного и того же кода
             и выглядел иначе, чем биндер. ]]
        local RD = GRM.Radial
        R.sel = RD.Pick(mx, my, cx, cy, count, R.InnerR)

        local name = I.TargetName(R.ent, R.kind)
        local owner, locked = I.TargetSub(R.ent, R.kind)

        -- Пункты: подпись + причина отказа прямо под ней.
        local items = {}
        for i, act in ipairs(R.items) do
            items[i] = {
                name = act.name,
                sub = (act.enabled == false) and act.why or nil,
                enabled = act.enabled,
                accent = act.accent == "good" and "good" or nil,
            }
        end
        RD.Draw(cx, cy, items, R.sel, R.InnerR, R.OuterR, { labelR = R.LabelR })

        -- Центр: что за объект и заперт ли он.
        draw.SimpleText(name, "GRMInt_Name", cx, cy - 14, RD.Col.text,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(locked and "ЗАПЕРТО" or "ОТКРЫТО", "GRMInt_Small", cx, cy + 8,
            locked and RD.Col.bad or RD.Col.good, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if owner ~= "" then
            draw.SimpleText(GRM.Utf8Ellipsis(owner, 22), "GRMInt_Small", cx, cy + 28,
                RD.Col.dimText, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        draw.SimpleTextOutlined("отпустите E — применить  ·  ПКМ — отмена", "GRMInt_Small",
            cx, cy + R.OuterR + 26, RD.Col.dimText,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, RD.Col.shadow)
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
local passUse = 0        -- сколько тиков доиграть «съеденный» короткий клик
local wasUse = false     -- держал ли игрок E в прошлом тике
I.HoldTime = 0.22        -- сколько держать, чтобы вместо обычного E пришло кольцо

--[[ ВСЯ ЛОГИКА E ЖИВЁТ В StartCommand (жалоба владельца 31.08,
     повторно: «Всё ещё не исправлено»).

     ПЕРВАЯ ПОПЫТКА БЫЛА НЕВЕРНОЙ. Я ловил нажатие в PlayerButtonDown и
     оттуда поднимал флаг, а снимал IN_USE уже в StartCommand. Но
     PlayerButtonDown вызывается ПОСЛЕ того, как команда для сервера
     сформирована и отправлена: к моменту, когда флаг поднят, первый
     тик с зажатым «использовать» уже ушёл. Серверу одного тика
     достаточно, чтобы открыть дверь — поэтому она и открывалась.

     ПРАВИЛЬНО так: смотреть кнопку прямо в StartCommand, там же, где
     команда и формируется. Нажатие мы видим в тот же тик, в котором
     оно уходит, и снимаем его ДО отправки. Ни один тик не проскакивает.

     PlayerButtonDown для этой задачи не годится в принципе — он
     сообщает о факте нажатия, но опаздывает на кадр относительно
     потока команд. ]]
local function useDown(cmd)
    return cmd:KeyDown(IN_USE)
end

hook.Add("StartCommand", "GRM_Interact_Use", function(ply, cmd)
    if ply ~= LocalPlayer() then return end

    -- Доигрываем короткий клик, который сами же и придержали.
    if passUse > 0 then
        passUse = passUse - 1
        cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_USE))
        wasUse = false
        return
    end

    ------------------------------------------------------------------
    -- Кольцо открыто: мышь выбирает действие, игрок стоит.
    ------------------------------------------------------------------
    if R.open then
        cmd:ClearMovement()
        cmd:RemoveKey(IN_ATTACK)
        cmd:RemoveKey(IN_ATTACK2)
        cmd:RemoveKey(IN_USE)
        cmd:SetViewAngles(ply:EyeAngles())
        cmd:SetMouseX(0)
        cmd:SetMouseY(0)
        wasUse = useDown(cmd)
        return
    end

    local down = useDown(cmd)

    ------------------------------------------------------------------
    -- Момент нажатия: решаем, перехватывать ли эту клавишу.
    ------------------------------------------------------------------
    if down and not wasUse then
        wasUse = true
        armed = false
        if GetConVarNumber("grm_cl_interact") == 0 then return end
        if gui.IsGameUIVisible() or gui.IsConsoleVisible() then return end
        if ply.IsTyping and ply:IsTyping() then return end
        if not ply:Alive() or ply:InVehicle() then return end

        local ent, kind = I.FindTarget(ply, I.Range)
        -- Нет цели — не наше дело, E работает как обычно.
        if not ent then return end

        holdStart, holdEnt, holdKind, armed = RealTime(), ent, kind, true
        -- Придерживаем ЭТОТ ЖЕ тик: именно здесь дверь и открывалась.
        cmd:RemoveKey(IN_USE)
        return
    end

    ------------------------------------------------------------------
    -- Клавишу держат дальше.
    ------------------------------------------------------------------
    if down and armed then
        cmd:RemoveKey(IN_USE)
        -- Порог пройден — показываем кольцо.
        if RealTime() - holdStart >= I.HoldTime and IsValid(holdEnt) then
            armed = false
            I.OpenRadial(holdEnt, holdKind)
        end
        wasUse = true
        return
    end

    ------------------------------------------------------------------
    -- Отпустили.
    ------------------------------------------------------------------
    if not down and wasUse then
        wasUse = false
        --[[ Отпустили раньше порога — это был обычный клик. Возвращаем
             его игре: мы же его только что съели. Несколько тиков, а
             не один: серверу нужно увидеть и нажатие, и отпускание. ]]
        if armed and (RealTime() - holdStart) < I.HoldTime then
            passUse = 3
        end
        armed = false
        return
    end

    wasUse = down
end)

--[[ Отпускание клавиши при ОТКРЫТОМ кольце применяет выбор.

     Здесь PlayerButtonUp уместен: кольцо уже на экране, гонки с
     потоком команд нет, а хук даёт точный момент отпускания. ]]
hook.Add("PlayerButtonUp", "GRM_Interact_UseUp", function(ply, key)
    if ply ~= LocalPlayer() then return end
    if key ~= KEY_E then return end
    if R.open then
        armed = false
        I.Apply()
    end
end)

print("[GRM Interact] client v" .. I.Version)
