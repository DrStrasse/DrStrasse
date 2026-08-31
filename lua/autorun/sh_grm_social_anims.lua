--[[ Соц.анимации: костные позы, радиальное меню, бинд F4, C-меню. ]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Social = GRM.Social or {}
local S = GRM.Social
S.Version = "1.2.0"
S.CatList = S.CatList or { { id = "general", name = "Общее" } }

-- Поза трубки: не в радиальном меню, ставит модуль телефона.
-- Локальное крепление к ValveBiped.Bip01_R_Hand (не мир, FollowBone).
S.PhoneHold = {
    pos = Vector(2.85, 1.15, 0.22),
    ang = Angle(12, 98, 88),
    scale = 1,
}
S.PhonePose = {
    id = "phone",
    bones = {
        ["ValveBiped.Bip01_R_UpperArm"] = Angle(22, -38, 22),
        ["ValveBiped.Bip01_R_Forearm"]  = Angle(-6, -52, 18),
        ["ValveBiped.Bip01_R_Hand"]     = Angle(-18, -6, 28),
        ["ValveBiped.Bip01_Head1"]      = Angle(4, -18, -10),
        ["ValveBiped.Bip01_Neck1"]      = Angle(0, -8, 0),
    },
}

S.List = {
    {
        id = "hands",
        name = "Руки вверх",
        cat = "general",
        hold = true,
        walk = true,
        bones = {
            ["ValveBiped.Bip01_R_UpperArm"] = Angle(-16, -28, -64),
            ["ValveBiped.Bip01_R_Forearm"]  = Angle(8, -22, 4),
            ["ValveBiped.Bip01_R_Hand"]     = Angle(0, 6, 8),
            ["ValveBiped.Bip01_L_UpperArm"] = Angle(16, -28, 64),
            ["ValveBiped.Bip01_L_Forearm"]  = Angle(-8, -22, -4),
            ["ValveBiped.Bip01_L_Hand"]     = Angle(0, 6, -8),
        },
    },
    {
        id = "back",
        name = "Руки за спиной",
        cat = "general",
        hold = true,
        walk = true,
        bones = {
            ["ValveBiped.Bip01_R_UpperArm"] = Angle(-8, -12, -88),
            ["ValveBiped.Bip01_R_Forearm"]  = Angle(6, -28, 8),
            ["ValveBiped.Bip01_R_Hand"]     = Angle(0, 4, 12),
            ["ValveBiped.Bip01_L_UpperArm"] = Angle(8, -12, 88),
            ["ValveBiped.Bip01_L_Forearm"]  = Angle(-6, -28, -8),
            ["ValveBiped.Bip01_L_Hand"]     = Angle(0, 4, -12),
        },
    },
    {
        id = "kneel",
        name = "Руки вверх, на коленях",
        cat = "general",
        hold = true,
        crouch = true,
        walk = false,
        bones = {
            ["ValveBiped.Bip01_R_UpperArm"] = Angle(-16, -28, -64),
            ["ValveBiped.Bip01_R_Forearm"]  = Angle(8, -22, 4),
            ["ValveBiped.Bip01_R_Hand"]     = Angle(0, 6, 8),
            ["ValveBiped.Bip01_L_UpperArm"] = Angle(16, -28, 64),
            ["ValveBiped.Bip01_L_Forearm"]  = Angle(-8, -22, -4),
            ["ValveBiped.Bip01_L_Hand"]     = Angle(0, 6, -8),
        },
    },
    --[[ ВСТРОЕННЫЙ ПРИМЕР ПОКАДРОВОЙ АНИМАЦИИ.

         Раньше весь список был статичными позами, и проверить механику
         кадров было не на чем: свежий сервер без сохранённого каталога
         показывал только позы. Здесь рука поднимается и качается из
         стороны в сторону — четыре кадра, цикл.

         hold = false: разовая. Отмахал и опустил руку сам, без
         необходимости лезть в меню и снимать позу вручную. ]]
    {
        id = "wave",
        name = "Приветствие",
        cat = "general",
        hold = false,
        walk = true,
        --[[ НЕ цикл. Зацикленная анимация никогда не снимется сама
             (в S.Play авто-снятие пропускает loop), и «поздоровавшийся»
             игрок махал бы рукой до ручной отмены. Здесь рука
             поднимается, дважды качается и ВОЗВРАЩАЕТСЯ последним
             пустым кадром — после него запись снимается таймером. ]]
        loop = false,
        speed = 1,
        frames = {
            {
                dur = 0.22,
                bones = {
                    ["ValveBiped.Bip01_R_UpperArm"] = { p = -6, yaw = -18, r = -30 },
                    ["ValveBiped.Bip01_R_Forearm"]  = { p = 4, yaw = -34, r = 6 },
                    ["ValveBiped.Bip01_R_Hand"]     = { p = 0, yaw = 4, r = 4 },
                },
            },
            {
                dur = 0.3,
                bones = {
                    ["ValveBiped.Bip01_R_UpperArm"] = { p = -14, yaw = -26, r = -66 },
                    ["ValveBiped.Bip01_R_Forearm"]  = { p = 6, yaw = -46, r = 10 },
                    ["ValveBiped.Bip01_R_Hand"]     = { p = 0, yaw = 8, r = 22 },
                    ["ValveBiped.Bip01_Head1"]      = { p = 0, yaw = -4, r = -6 },
                },
            },
            {
                dur = 0.3,
                bones = {
                    ["ValveBiped.Bip01_R_UpperArm"] = { p = -14, yaw = -26, r = -66 },
                    ["ValveBiped.Bip01_R_Forearm"]  = { p = 6, yaw = -46, r = 10 },
                    ["ValveBiped.Bip01_R_Hand"]     = { p = 0, yaw = 8, r = -24 },
                    ["ValveBiped.Bip01_Head1"]      = { p = 0, yaw = -4, r = -6 },
                },
            },
            {
                dur = 0.3,
                bones = {
                    ["ValveBiped.Bip01_R_UpperArm"] = { p = -14, yaw = -26, r = -66 },
                    ["ValveBiped.Bip01_R_Forearm"]  = { p = 6, yaw = -46, r = 10 },
                    ["ValveBiped.Bip01_R_Hand"]     = { p = 0, yaw = 8, r = 22 },
                    ["ValveBiped.Bip01_Head1"]      = { p = 0, yaw = -4, r = -6 },
                },
            },
            -- Возврат: пустой кадр = все кости в исходное положение.
            { dur = 0.28, bones = {} },
        },
    },
    {
        id = "point",
        name = "Указать вперёд",
        cat = "general",
        hold = false,
        walk = true,
        loop = false,
        frames = {
            {
                dur = 0.25,
                bones = {
                    ["ValveBiped.Bip01_R_UpperArm"] = { p = 10, yaw = -14, r = -8 },
                    ["ValveBiped.Bip01_R_Forearm"]  = { p = 0, yaw = -30, r = 0 },
                },
            },
            {
                dur = 0.9,
                bones = {
                    ["ValveBiped.Bip01_R_UpperArm"] = { p = 34, yaw = -46, r = -6 },
                    ["ValveBiped.Bip01_R_Forearm"]  = { p = -4, yaw = -12, r = 4 },
                    ["ValveBiped.Bip01_R_Hand"]     = { p = 0, yaw = 0, r = 10 },
                },
            },
        },
    },
    {
        id = "docs",
        name = "Рассматривать документы",
        cat = "docs",
        hold = true,
        walk = true,
        prop = "models/props_lab/clipboard.mdl",
        bones = {
            ["ValveBiped.Bip01_R_UpperArm"] = Angle(28, -42, 18),
            ["ValveBiped.Bip01_R_Forearm"]  = Angle(-4, -62, 16),
            ["ValveBiped.Bip01_R_Hand"]     = Angle(-6, -18, 36),
            ["ValveBiped.Bip01_L_UpperArm"] = Angle(-16, -28, -18),
            ["ValveBiped.Bip01_L_Forearm"]  = Angle(8, -48, -10),
            ["ValveBiped.Bip01_L_Hand"]     = Angle(8, 8, -16),
            ["ValveBiped.Bip01_Head1"]      = Angle(2, -16, -8),
            ["ValveBiped.Bip01_Neck1"]      = Angle(0, -8, 0),
        },
    },
}

function S.ByID(id)
    id = tostring(id or "")
    for i = 1, #S.List do
        if S.List[i].id == id then return S.List[i] end
    end
    for i = 1, #(S.Catalog or {}) do
        if S.Catalog[i].id == id then return S.Catalog[i] end
    end
end

local ALL_BONES = {}
local function markBones(t)
    for name in pairs(t or {}) do ALL_BONES[name] = true end
end
function S.MarkAllBones()
    ALL_BONES = {}
    for i = 1, #S.List do
        markBones(S.List[i].bones)
        --[[ Кости из КАДРОВ тоже обязаны попасть в список сброса: иначе
             кость, которую двигает только третий кадр, останется
             вывернутой после снятия анимации. ]]
        for _, f in ipairs(S.List[i].frames or {}) do markBones(f.bones) end
    end
    markBones(S.PhonePose.bones)
end
S.MarkAllBones()

function S.BoneToAngle(rec)
    if isangle(rec) then return rec end
    if not istable(rec) then return Angle(0, 0, 0) end
    return Angle(tonumber(rec.p) or 0, tonumber(rec.yaw or rec.y) or 0, tonumber(rec.r) or 0)
end

function S.BoneToPos(rec)
    if not istable(rec) then return Vector(0, 0, 0) end
    return Vector(tonumber(rec.px or rec.x) or 0, tonumber(rec.py) or 0, tonumber(rec.pz or rec.z) or 0)
end

-----------------------------------------------------------------------
-- КЛЮЧЕВЫЕ КАДРЫ (заказ владельца 31.08).
--
-- БЫЛО. Каждая «анимация» это ОДИН набор углов костей (def.bones):
-- поза, а не движение. Руки вверх — можно, помахать рукой — нельзя.
--
-- СТАЛО. У анимации есть массив кадров:
--     def.frames = { { dur = 0.4, bones = { [кость] = {p,yaw,r,px,py,pz} } }, ... }
--     def.loop   = повторять по кругу
--     def.speed  = множитель времени
-- dur кадра — это время ПЕРЕХОДА от него к следующему, поэтому у
-- последнего кадра dur учитывается только в цикле (возврат к первому).
--
-- Старые записи (только def.bones) продолжают работать: S.Frames
-- превращает их в единственный кадр, и всё поведение прежнее. Ломать
-- сохранённый каталог сервера нельзя — там уже есть рабочие позы.
-----------------------------------------------------------------------
S.MaxFrames = 48
S.MaxBonesPerFrame = 96
S.MinDur, S.MaxDur = 0.05, 10

local function num(v, d)
    v = tonumber(v)
    if v == nil then return d or 0 end
    return v
end

-- Явный выбор вместо `a or b`: ноль в Lua истинен, но nil-проверка
-- читается однозначно и не ломается, если в поле вдруг окажется false.
local function pick(a, b)
    if a ~= nil then return a end
    return b
end

--[[ Приводит запись кости к единому виду. На входе может быть Angle
     (старый формат из кода), таблица из студии {p,yaw,r,px,py,pz} или
     таблица после JSON-обхода {p,y,r,x,z}. ]]
function S.NormBone(rec)
    if isangle and isangle(rec) then
        return { p = num(rec.p), yaw = num(rec.y), r = num(rec.r), px = 0, py = 0, pz = 0 }
    end
    if not istable(rec) then
        return { p = 0, yaw = 0, r = 0, px = 0, py = 0, pz = 0 }
    end
    return {
        p   = num(rec.p),
        yaw = num(pick(rec.yaw, rec.y)),
        r   = num(rec.r),
        px  = num(pick(rec.px, rec.x)),
        py  = num(rec.py),
        pz  = num(pick(rec.pz, rec.z)),
    }
end

--[[ Чистка кадров перед записью в каталог. Данные приходят по сети от
     админа — но и админ может прислать мусор (или клиент с правкой).
     Ограничиваем длину, число костей и длительность: иначе один кадр
     на 10000 костей раздует файл каталога и рассылку всем игрокам. ]]
function S.SanitizeFrames(frames)
    local out = {}
    if not istable(frames) then return out end
    local limit = math.min(#frames, S.MaxFrames)
    for i = 1, limit do
        local f = frames[i]
        if istable(f) then
            local bones, n = {}, 0
            for name, rec in pairs(f.bones or {}) do
                if isstring(name) and n < S.MaxBonesPerFrame then
                    n = n + 1
                    bones[string.sub(name, 1, 64)] = S.NormBone(rec)
                end
            end
            out[#out + 1] = {
                dur = math.Clamp(num(f.dur, 0.5), S.MinDur, S.MaxDur),
                bones = bones,
            }
        end
    end
    return out
end

-- Кадры анимации. Старая поза без frames — это один кадр.
function S.Frames(def)
    if not istable(def) then return {} end
    if istable(def.frames) and #def.frames > 0 then return def.frames end
    if istable(def.bones) then return { { dur = 0.5, bones = def.bones } } end
    return {}
end

function S.IsAnimated(def)
    return #S.Frames(def) > 1
end

function S.TotalTime(def)
    local fr = S.Frames(def)
    local n = #fr
    if n < 2 then return 0 end
    -- Без цикла последний кадр никуда не переходит: его dur не считаем.
    local last = n - 1
    if istable(def) and def.loop == true then last = n end
    local t = 0
    for i = 1, last do
        t = t + math.Clamp(num(fr[i].dur, 0.5), S.MinDur, S.MaxDur)
    end
    return t
end

local function wrap180(a)
    a = a % 360
    if a > 180 then a = a - 360 end
    return a
end

local function lerpNum(a, b, f) return a + (b - a) * f end

--[[ Углы смешиваем по КРАТЧАЙШЕЙ дуге: переход 170° → -170° это 20°
     через 180, а не 340° в обратную сторону. Без этого рука на стыке
     кадров делала полный оборот. ]]
local function lerpAng(a, b, f) return a + wrap180(b - a) * f end

function S.Blend(a, b, f)
    if not istable(a) then a = {} end
    if not istable(b) then b = {} end
    f = math.Clamp(num(f, 0), 0, 1)
    local names = {}
    for name in pairs(a) do names[name] = true end
    for name in pairs(b) do names[name] = true end
    local out = {}
    for name in pairs(names) do
        local x, y = S.NormBone(a[name]), S.NormBone(b[name])
        out[name] = {
            p   = lerpAng(x.p, y.p, f),
            yaw = lerpAng(x.yaw, y.yaw, f),
            r   = lerpAng(x.r, y.r, f),
            px  = lerpNum(x.px, y.px, f),
            py  = lerpNum(x.py, y.py, f),
            pz  = lerpNum(x.pz, y.pz, f),
        }
    end
    return out
end

--[[ Состояние скелета на момент времени t (секунды с начала показа). ]]
function S.Sample(def, t)
    local fr = S.Frames(def)
    local n = #fr
    if n == 0 then return {} end
    if n == 1 then return fr[1].bones or {} end
    local speed = math.Clamp(num(istable(def) and def.speed or 1, 1), 0.1, 4)
    t = num(t, 0) * speed
    if t < 0 then t = 0 end
    local total = S.TotalTime(def)
    if total <= 0 then return fr[1].bones or {} end
    local loop = istable(def) and def.loop == true
    if loop then
        t = t % total
    elseif t >= total then
        -- Не циклическая анимация замирает на последнем кадре.
        return fr[n].bones or {}
    end
    for i = 1, n do
        local d = math.Clamp(num(fr[i].dur, 0.5), S.MinDur, S.MaxDur)
        if t < d or i == n then
            local j = i + 1
            if j > n then j = 1 end
            return S.Blend(fr[i].bones, fr[j].bones, t / d)
        end
        t = t - d
    end
    return fr[n].bones or {}
end

function S.CatName(id)
    id = tostring(id or "general")
    for i = 1, #(S.CatList or {}) do
        if S.CatList[i].id == id then return S.CatList[i].name or id end
    end
    if id == "docs" then return "Документы" end
    if id == "general" then return "Общее" end
    return id
end

function S.Categories()
    local seen, out = {}, {}
    for i = 1, #(S.CatList or {}) do
        local c = S.CatList[i]
        if istable(c) and c.id and not seen[c.id] then
            seen[c.id] = true
            out[#out + 1] = { id = c.id, name = c.name or c.id }
        end
    end
    for i = 1, #(S.List or {}) do
        local id = tostring(S.List[i].cat or "general")
        if id ~= "" and not seen[id] then
            seen[id] = true
            out[#out + 1] = { id = id, name = S.CatName(id) }
        end
    end
    if #out == 0 then out[1] = { id = "general", name = "Общее" } end
    return out
end

function S.InCat(cat)
    cat = tostring(cat or "general")
    local out = {}
    for i = 1, #(S.List or {}) do
        local p = S.List[i]
        if tostring(p.cat or "general") == cat then out[#out + 1] = p end
    end
    if #out == 0 and cat == "general" then
        for i = 1, #(S.List or {}) do out[#out + 1] = S.List[i] end
    end
    return out
end

function S.ApplyCatalog(list, cats)
    if istable(list) and list.poses then
        cats = list.cats or cats
        list = list.poses
    end
    if istable(cats) then S.CatList = cats end
    if not istable(list) then return end
    S.Catalog = list
    local out = {}
    for i = 1, #list do
        local p = list[i]
        if istable(p) and p.players ~= false and p.id then
            p.cat = tostring(p.cat or "general")
            out[#out + 1] = p
        end
    end
    if #out > 0 then S.List = out end
    S.MarkAllBones()
end

if SERVER then
    util.AddNetworkString("GRM_Soc_Set")

    local function busy(ply)
        if not IsValid(ply) or not ply:Alive() then return "недоступно" end
        if ply:InVehicle() then return "в транспорте" end
        if ply:GetNWBool("GRM_Cuffed") then return "наручники" end
        if ply:GetNWBool("GRM_Arrested") then return "арест" end
        if ply:GetNWBool("GRM_Prone") then return "лёжа" end
        if ply:GetNWBool("GRM_911_Downed") then return "ранен" end
        return nil
    end

    function S.Stop(ply)
        if not IsValid(ply) then return end
        ply:SetNWString("GRM_SocAnim", "")
        ply:SetNWBool("GRM_SocCrouch", false)
        ply:SetNWFloat("GRM_SocStart", 0)
    end

    function S.Play(ply, id)
        local why = busy(ply)
        if why then
            if GRM.Notify then GRM.Notify(ply, "Анимация: " .. why, 255, 160, 90) end
            return false
        end
        if id == "" or id == "off" or id == "stop" then
            S.Stop(ply)
            return true
        end
        local def = S.ByID(id)
        if not def then return false end
        if ply:GetNWString("GRM_SocAnim", "") == def.id then
            S.Stop(ply)
            return true
        end
        ply:SetNWString("GRM_SocAnim", def.id)
        ply:SetNWBool("GRM_SocCrouch", def.crouch == true)
        --[[ МОМЕНТ ЗАПУСКА. Кадры проигрываются от него, и время едино
             для всех: свой клиент и чужие видят один и тот же кадр.
             Без общей точки отсчёта каждый зритель начинал бы анимацию
             с момента, когда К НЕМУ приехал сетевой флаг. ]]
        ply:SetNWFloat("GRM_SocStart", CurTime())

        --[[ Разовая анимация (не цикл, не «держать») сама снимается,
             когда доиграла. Иначе игрок навсегда застревал бы в
             последнем кадре приветствия. ]]
        local total = S.TotalTime(def)
        if total > 0 and def.loop ~= true and def.hold == false then
            local id2 = def.id
            timer.Simple(total + 0.05, function()
                if IsValid(ply) and ply:GetNWString("GRM_SocAnim", "") == id2 then
                    S.Stop(ply)
                end
            end)
        end
        return true
    end

    net.Receive("GRM_Soc_Set", function(_, ply)
        if not IsValid(ply) then return end
        if GRM.Perf and GRM.Perf.Throttle and not GRM.Perf.Throttle("soc." .. ply:EntIndex(), 0.15) then return end
        local id = string.sub(tostring(net.ReadString() or ""), 1, 32)
        S.Play(ply, id)
    end)

    hook.Add("PlayerDeath", "GRM_Soc_Death", S.Stop)
    hook.Add("PlayerSilentDeath", "GRM_Soc_Death2", S.Stop)
    hook.Add("PlayerEnteredVehicle", "GRM_Soc_Veh", function(ply) S.Stop(ply) end)
    hook.Add("PlayerSpawn", "GRM_Soc_Spawn", S.Stop)

    --[[ ЗАМОРОЗКА ПОЗЫ (жалоба владельца 28.08: «применение заморозки
         позы ничего не даёт, игрок двигается как и двигался»).

         Галочка «Заморозить при проигрывании» в студии сохранялась в
         каталог (поле freeze), доезжала до клиента и даже читалась при
         загрузке позы в редакторе. Но ЗДЕСЬ, в модуле воспроизведения,
         слово freeze не встречалось ни разу: флаг просто некому было
         применить. Поза вставала, а игрок продолжал бегать.

         Замораживаем ДВИЖЕНИЕ, но НЕ камеру — так и было обещано в
         подсказке к галочке: «можно крутить камерой». Поэтому чистим
         только перемещение и прыжок, а угол обзора не трогаем.

         Через StartCommand, а не ply:Freeze(): Freeze намертво запирает
         игрока средствами движка, и любой чужой код, снявший его
         (админ-действия, респавн, транспорт), навсегда рассинхронил бы
         состояние. Здесь же ограничение живёт ровно столько, сколько
         активна поза, и снимается само. ]]
    function S.IsFrozen(ply)
        if not IsValid(ply) then return false end
        local id = ply:GetNWString("GRM_SocAnim", "")
        if id == "" then return false end
        local def = S.ByID(id)
        return istable(def) and (def.freeze == true or def.nomove == true)
    end

    hook.Add("StartCommand", "GRM_Soc_Hold", function(ply, cmd)
        if not IsValid(ply) then return end
        if ply:GetNWString("GRM_SocAnim", "") == "" then return end
        local def = S.ByID(ply:GetNWString("GRM_SocAnim", ""))
        if not def then return end
        if def.crouch then
            cmd:SetButtons(bit.bor(cmd:GetButtons(), IN_DUCK))
            cmd:RemoveKey(IN_JUMP)
            if not def.walk then cmd:ClearMovement() end
        end
        --[[ Заморозка сильнее настройки «Ходьба»: если поза помечена
             как замораживающая, идти нельзя независимо от def.walk. ]]
        if def.freeze == true or def.nomove == true then
            cmd:ClearMovement()
            cmd:RemoveKey(IN_JUMP)
            cmd:RemoveKey(IN_SPEED)
            cmd:RemoveKey(IN_FORWARD)
            cmd:RemoveKey(IN_BACK)
            cmd:RemoveKey(IN_MOVELEFT)
            cmd:RemoveKey(IN_MOVERIGHT)
        end
        cmd:RemoveKey(IN_ATTACK)
        cmd:RemoveKey(IN_ATTACK2)
    end)

    --[[ StartCommand отсекает ввод игрока, но не внешний толчок: взрыв,
         машина или другой игрок всё равно сдвинут «замороженного».
         Гасим остаточную скорость — иначе поза уезжает по инерции.

         Задача в планировщике с приоритетом normal и условием: пока
         никто не позирует, она не стоит ничего. ]]
    local function freezeTick()
        local list = (GRM.Perf and GRM.Perf.Players) and GRM.Perf.Players() or player.GetAll()
        for i = 1, #list do
            local ply = list[i]
            if IsValid(ply) and S.IsFrozen(ply) then
                local vel = ply:GetVelocity()
                -- По вертикали не мешаем: иначе игрок зависнет в воздухе.
                if vel:Length2D() > 1 then
                    ply:SetVelocity(Vector(-vel.x, -vel.y, 0))
                end
            end
        end
    end

    local function anyPosing()
        local list = (GRM.Perf and GRM.Perf.Players) and GRM.Perf.Players() or player.GetAll()
        for i = 1, #list do
            local ply = list[i]
            if IsValid(ply) and ply:GetNWString("GRM_SocAnim", "") ~= "" then return true end
        end
        return false
    end

    if GRM.Sched then
        GRM.Sched.Every("social.freeze", 0.2, freezeTick,
            { prio = "normal", when = anyPosing })
    else
        timer.Create("GRM_Soc_Freeze", 0.2, 0, function()
            if anyPosing() then freezeTick() end
        end)
    end

    hook.Add("CalcMainActivity", "GRM_Soc_Act", function(ply, vel)
        if not IsValid(ply) then return end
        if ply:GetNWString("GRM_SocAnim", "") == "" then return end
        local def = S.ByID(ply:GetNWString("GRM_SocAnim", ""))
        if not def or not def.crouch then return end
        local moving = vel and vel:Length2D() > 8
        return moving and ACT_HL2MP_WALK_CROUCH or ACT_HL2MP_IDLE_CROUCH, -1
    end)

    hook.Add("PlayerSay", "GRM_Soc_Chat", function(ply, text)
        local t = string.lower(string.Trim(tostring(text or "")))
        if t == "/anim" or t == "/аним" or t == "/анимации" or t == "/social" then
            if GRM.Notify then GRM.Notify(ply, "Соц.анимации: клавиша из F4 → Настройки. Позы также в /binder как шаг АНИМ.", 180, 210, 240) end
            return ""
        end
        if t == "/animstop" or t == "/стоппоза" then
            S.Stop(ply)
            return ""
        end
    end)

    print("[GRM Social] server v" .. S.Version)
    return
end

-----------------------------------------------------------------------
-- CLIENT
-----------------------------------------------------------------------
CreateClientConVar("grm_cl_social_key", "18", true, false, "Клавиша меню соц.анимаций (KEY_*)")

surface.CreateFont("GRMSoc_Head", { font = "Roboto", size = 16, weight = 700, extended = true })
surface.CreateFont("GRMSoc_Body", { font = "Roboto", size = 14, weight = 500, extended = true })
surface.CreateFont("GRMSoc_Sm", { font = "Roboto", size = 12, weight = 400, extended = true })

local applied = {}
local clips = {}

local function resetBones(ply)
    if not IsValid(ply) then return end
    for name in pairs(ALL_BONES) do
        local b = ply:LookupBone(name)
        if b then
            ply:ManipulateBoneAngles(b, Angle(0, 0, 0))
            ply:ManipulateBonePosition(b, Vector(0, 0, 0))
        end
    end
    if ply.InvalidateBoneCache then ply:InvalidateBoneCache() end
    applied[ply] = nil
    if frozen and frozen[ply] then
        frozen[ply] = nil
        if IsValid(ply) and ply.Freeze then ply:Freeze(false) end
        ply._grmSocFrozen = nil
    end
    hook.Run("GRM_SocPoseCleared", ply)
end

--[[ Применение НАБОРА КОСТЕЙ (уже посчитанного кадра). Отдельно от
     выбора кадра: тем же кодом пользуется и предпросмотр в студии. ]]
function S.ApplyBones(ply, bones)
    if not IsValid(ply) or not istable(bones) then return end
    for name, rec in pairs(bones) do
        local b = ply:LookupBone(name)
        if b then
            ply:ManipulateBoneAngles(b, S.BoneToAngle(rec))
            local pos = S.BoneToPos(rec)
            if pos:LengthSqr() > 0.0001 then
                ply:ManipulateBonePosition(b, pos)
            else
                -- Кадр без сдвига обязан ОБНУЛИТЬ сдвиг предыдущего,
                -- иначе кость «уползает» и остаётся смещённой.
                ply:ManipulateBonePosition(b, Vector(0, 0, 0))
            end
        end
    end
end

local function applyPose(ply, def)
    if not IsValid(ply) or not def then return end
    if applied[ply] ~= def.id then resetBones(ply) end
    applied[ply] = def.id

    if not S.IsAnimated(def) then
        S.ApplyBones(ply, S.Frames(def)[1] and S.Frames(def)[1].bones or def.bones)
        return
    end
    --[[ Анимация: кадр считаем от общего для всех момента запуска.
         CurTime, а не RealTime: сетевое время у всех клиентов общее,
         значит зрители видят игрока в том же кадре, что и он сам. ]]
    local started = ply:GetNWFloat("GRM_SocStart", 0)
    if started <= 0 then started = CurTime() end
    S.ApplyBones(ply, S.Sample(def, CurTime() - started))
end

local function killClip(ply)
    local rec = clips[ply]
    local m = istable(rec) and rec.ent or rec
    if IsValid(m) then
        if m.SetParent then pcall(m.SetParent, m, NULL) end
        m:Remove()
    end
    clips[ply] = nil
end

--[[ Кто прямо сейчас проигрывает МНОГОКАДРОВУЮ анимацию.

     Разделение на два темпа сделано намеренно. Опрос сетевых
     переменных всех игроков — не бесплатная операция, поэтому он
     остаётся на прежних 0.12 с. Но поза из кадров при 8 обновлениях в
     секунду выглядит рывками, поэтому найденных «анимированных»
     докручиваем каждый кадр. Пока никто не анимируется, таблица пуста
     и цикл ничего не стоит. ]]
local animating = {}

hook.Add("Think", "GRM_Soc_Apply", function()
    -- Плавность: тем, кто уже в анимации, пересчитываем кадр каждый тик.
    for ply, def in pairs(animating) do
        if IsValid(ply) and ply:GetNWString("GRM_SocAnim", "") == def.id then
            applyPose(ply, def)
        else
            animating[ply] = nil
        end
    end

    if GRM.Perf and GRM.Perf.Throttle and not GRM.Perf.Throttle("soc.apply", 0.12) then return end
    local list = (GRM.Perf and GRM.Perf.Players and GRM.Perf.Players()) or player.GetAll()
    for i = 1, #list do
        local ply = list[i]
        if not IsValid(ply) then continue end
        local id = ply:GetNWString("GRM_SocAnim", "")
        local phoneMdl = ply:GetNWString("GRM_MobHold", "")
        if id == "" and phoneMdl == "" then
            if applied[ply] then resetBones(ply) end
            if clips[ply] then killClip(ply) end
            animating[ply] = nil
        elseif phoneMdl ~= "" then
            animating[ply] = nil
            applyPose(ply, S.PhonePose)
        else
            local def = S.ByID(id)
            if def then
                applyPose(ply, def)
                animating[ply] = S.IsAnimated(def) and def or nil
            end
        end
    end
end)

hook.Add("EntityRemoved", "GRM_Soc_EntGone", function(ent)
    -- Утечка: без этой строки таблица анимируемых держала бы ссылку на
    -- удалённого игрока вечно.
    animating[ent] = nil
    if applied[ent] then resetBones(ent) end
    if clips[ent] then killClip(ent) end
end)

local function wantProp(ply)
    local phoneMdl = ply:GetNWString("GRM_MobHold", "")
    if phoneMdl ~= "" then return phoneMdl, "phone" end
    if ply:GetNWString("GRM_SocAnim", "") == "docs" then
        return "models/props_lab/clipboard.mdl", "docs"
    end
end

hook.Add("PostPlayerDraw", "GRM_Soc_ClipFixed", function(ply)
    if not IsValid(ply) then return end
    local mdl, kind = wantProp(ply)
    if not mdl then
        if clips[ply] then killClip(ply) end
        return
    end
    local rec = clips[ply]
    local m = istable(rec) and rec.ent or rec
    if not IsValid(m) or (istable(rec) and rec.mdl ~= mdl) then
        if IsValid(m) then m:Remove() end
        m = ClientsideModel(mdl)
        if not IsValid(m) then return end
        m:SetModelScale(kind == "phone" and ((S.PhoneHold and S.PhoneHold.scale) or 1) or 0.82, 0)
        clips[ply] = { ent = m, mdl = mdl, bone = nil }
    end
    local bone = ply:LookupBone("ValveBiped.Bip01_R_Hand")
    if not bone then return end
    rec = clips[ply]
    if kind == "phone" then
        m:SetNoDraw(false)
        if rec.bone ~= bone or m:GetParent() ~= ply then
            m:FollowBone(ply, bone)
            rec.bone = bone
        end
        local hold = S.PhoneHold or { pos = Vector(2.85, 1.15, 0.22), ang = Angle(12, 98, 88) }
        m:SetLocalPos(hold.pos)
        m:SetLocalAngles(hold.ang)
        return
    end
    m:SetNoDraw(true)
    if m.SetParent then m:SetParent(NULL) end
    rec.bone = nil
    local mtx = ply.GetBoneMatrix and ply:GetBoneMatrix(bone)
    local pos, ang
    if mtx then pos, ang = mtx:GetTranslation(), mtx:GetAngles()
    else pos, ang = ply:GetBonePosition(bone) end
    if not pos or not ang then return end
    ang:RotateAroundAxis(ang:Forward(), 95)
    ang:RotateAroundAxis(ang:Right(), 8)
    ang:RotateAroundAxis(ang:Up(), 4)
    pos = pos + ang:Forward() * 5.8 + ang:Right() * 0.2 + ang:Up() * 0.8
    m:SetPos(pos)
    m:SetAngles(ang)
    m:DrawModel()
end)

hook.Add("CalcMainActivity", "GRM_Soc_Act", function(ply, vel)
    if not IsValid(ply) then return end
    if ply:GetNWString("GRM_SocAnim", "") == "" then return end
    local def = S.ByID(ply:GetNWString("GRM_SocAnim", ""))
    if not def then return end
    if def.crouch then
        local moving = vel and vel:Length2D() > 8
        return moving and ACT_HL2MP_WALK_CROUCH or ACT_HL2MP_IDLE_CROUCH, -1
    end
end)

local function sendPlay(id)
    net.Start("GRM_Soc_Set")
    net.WriteString(tostring(id or "stop"))
    net.SendToServer()
end

S.Request = sendPlay
S.Open = S.Open
S.RadialOpen = false
S._menuCat = "general"

local function inputBusy()
    if gui.IsGameUIVisible() or gui.IsConsoleVisible() then return true end
    local lp = LocalPlayer()
    if IsValid(lp) and lp.IsTyping and lp:IsTyping() then return true end
    return false
end

local function keyNum()
    return math.Clamp(math.floor(GetConVarNumber("grm_cl_social_key") or 18), 0, 159)
end

function S.CloseMenu()
    S.RadialOpen = false
    if IsValid(S._menu) then S._menu:Remove() end
    S._menu = nil
    gui.EnableScreenClicker(false)
end

-----------------------------------------------------------------------
-- МЕНЮ ВЫБОРА АНИМАЦИЙ (переделано 31.08 по заказу владельца).
--
-- Было: серая сетка одинаковых кнопок с текстом — по названию не
-- понять, что именно произойдёт. Стало: слева рельс категорий,
-- в центре карточки, справа ЖИВОЙ предпросмотр на своей модели —
-- та же функция S.Sample, что крутит анимацию в игре, поэтому
-- показывается ровно то, что увидят окружающие.
-----------------------------------------------------------------------
surface.CreateFont("GRMSoc_Title", { font = "Roboto", size = 22, weight = 800, extended = true })
surface.CreateFont("GRMSoc_Card", { font = "Roboto", size = 15, weight = 600, extended = true })

local MC = {
    bg     = Color(16, 20, 28, 250),
    head   = Color(12, 15, 22, 255),
    panel  = Color(24, 30, 41, 255),
    card   = Color(33, 41, 55),
    cardHl = Color(52, 118, 200),
    cardOn = Color(46, 130, 88),
    line   = Color(46, 56, 72),
    text   = Color(234, 240, 248),
    dim    = Color(146, 162, 180),
    gold   = Color(245, 195, 65),
}

function S.CloseMenu()
    S.RadialOpen = false
    if IsValid(S._menu) then S._menu:Remove() end
    S._menu = nil
    gui.EnableScreenClicker(false)
end

--[[ Предпросмотр. Модель игрока крутится в DModelPanel, кости ей
     ставит S.Sample — общий код воспроизведения. Если однажды логика
     смешивания кадров поменяется, предпросмотр поедет вместе с игрой,
     а не разойдётся с ней. ]]
local function buildPreview(parent, getDef)
    local mdl = vgui.Create("DModelPanel", parent)
    mdl:SetFOV(38)
    mdl:SetAnimated(true)
    local lp = LocalPlayer()
    mdl:SetModel(IsValid(lp) and lp:GetModel() or "models/player/kleiner.mdl")
    mdl:SetCamPos(Vector(62, 26, 62))
    mdl:SetLookAt(Vector(0, 0, 38))
    mdl.start = RealTime()
    mdl.lastID = nil
    function mdl:LayoutEntity(ent)
        if not IsValid(ent) then return end
        local def = getDef()
        if not def then
            -- Нет выбора — просто вращаем модель, чтобы панель не была мёртвой.
            ent:SetAngles(Angle(0, RealTime() * 30 % 360, 0))
            return
        end
        if self.lastID ~= def.id then
            self.lastID = def.id
            self.start = RealTime()
            -- Смена анимации: старые манипуляции надо снять, иначе
            -- кости прошлой позы останутся висеть поверх новой.
            for i = 0, (ent:GetBoneCount() or 1) - 1 do
                ent:ManipulateBoneAngles(i, Angle(0, 0, 0))
                ent:ManipulateBonePosition(i, Vector(0, 0, 0))
            end
        end
        ent:SetAngles(Angle(0, 35, 0))
        local bones = S.Sample(def, RealTime() - (self.start or RealTime()))
        for name, rec in pairs(bones or {}) do
            local b = ent:LookupBone(name)
            if b then
                ent:ManipulateBoneAngles(b, S.BoneToAngle(rec))
                ent:ManipulateBonePosition(b, S.BoneToPos(rec))
            end
        end
    end
    return mdl
end

function S.OpenMenu()
    if IsValid(S._menu) then
        S._menu:SetVisible(true)
        S._menu:MakePopup()
        S._menu:MoveToFront()
        return
    end
    local cats = isfunction(S.Categories) and S.Categories() or { { id = "general", name = "Общее" } }
    local have
    for i = 1, #cats do if cats[i].id == S._menuCat then have = true break end end
    if not have then S._menuCat = cats[1] and cats[1].id or "general" end

    local W, H = 880, 540
    local f = vgui.Create("DFrame")
    S._menu = f
    S.RadialOpen = true
    S._sel = nil
    f:SetTitle("")
    f:SetSize(W, H)
    f:Center()
    f:MakePopup()
    f:ShowCloseButton(false)
    f:SetKeyboardInputEnabled(false)
    f.Paint = function(_, w, h)
        draw.RoundedBox(10, 0, 0, w, h, MC.bg)
        draw.RoundedBox(10, 0, 0, w, 54, MC.head)
        draw.RoundedBox(0, 0, 53, w, 1, MC.line)
        draw.SimpleText("СОЦИАЛЬНЫЕ АНИМАЦИИ", "GRMSoc_Title", 20, 27, MC.gold, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        local cur = LocalPlayer():GetNWString("GRM_SocAnim", "")
        local mine = S.ByID(cur)
        if mine then
            draw.SimpleText("активна: " .. (mine.name or cur), "GRMSoc_Body", w - 56, 27,
                Color(96, 208, 128), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end
    f.OnRemove = function() S.RadialOpen = false S._menu = nil end

    local x = vgui.Create("DButton", f)
    x:SetPos(W - 42, 13) x:SetSize(28, 28) x:SetText("✕")
    x:SetFont("GRMSoc_Head")
    x:SetTextColor(MC.text)
    x.Paint = function(s, w, h)
        draw.RoundedBox(5, 0, 0, w, h, s:IsHovered() and Color(178, 62, 58) or Color(38, 46, 60))
    end
    x.DoClick = function() S.CloseMenu() end

    -- Рельс категорий слева: вертикальный список читается лучше, чем
    -- горизонтальная лента, и не обрезает длинные названия.
    local rail = vgui.Create("DScrollPanel", f)
    rail:SetPos(12, 64) rail:SetSize(186, H - 76)

    local grid = vgui.Create("DScrollPanel", f)
    grid:SetPos(206, 64)
    grid:SetSize(392, H - 130)

    local side = vgui.Create("DPanel", f)
    side:SetPos(606, 64) side:SetSize(262, H - 76)
    side.Paint = function(_, w, h)
        draw.RoundedBox(8, 0, 0, w, h, MC.panel)
        local def = S._sel and S.ByID(S._sel)
        draw.SimpleText(def and (def.name or def.id) or "Выберите анимацию", "GRMSoc_Card",
            w / 2, h - 96, MC.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if def then
            local n = #S.Frames(def)
            local info = n > 1 and (n .. " кадров · " .. string.format("%.1f с", S.TotalTime(def))) or "статичная поза"
            if def.loop then info = info .. " · цикл" end
            draw.SimpleText(info, "GRMSoc_Sm", w / 2, h - 76, MC.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    end

    local preview = buildPreview(side, function()
        return S._sel and S.ByID(S._sel) or nil
    end)
    preview:SetPos(6, 8)
    preview:SetSize(250, side:GetTall() - 116)

    local function sendAndClose(id)
        if surface and surface.PlaySound then surface.PlaySound("common/wpn_select.wav") end
        sendPlay(id)
        S.CloseMenu()
    end

    local playB = vgui.Create("DButton", side)
    playB:SetPos(10, side:GetTall() - 62) playB:SetSize(242, 32) playB:SetText("")
    playB.Paint = function(s, w, h)
        local on = S._sel ~= nil
        local c = on and (s:IsHovered() and Color(64, 168, 112) or MC.cardOn) or Color(40, 48, 62)
        draw.RoundedBox(6, 0, 0, w, h, c)
        draw.SimpleText(on and "ВКЛЮЧИТЬ" or "НИЧЕГО НЕ ВЫБРАНО", "GRMSoc_Card", w / 2, h / 2,
            on and MC.text or MC.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    playB.DoClick = function()
        if not S._sel then return end
        sendAndClose(S._sel)
    end

    local function fill()
        grid:Clear()
        local items = (isfunction(S.InCat) and S.InCat(S._menuCat)) or (S.List or {})
        local bw, bh, gap = 188, 44, 8
        for i, def in ipairs(items) do
            local r = math.floor((i - 1) / 2)
            local c = (i - 1) % 2
            local b = vgui.Create("DButton", grid)
            b:SetPos(c * (bw + gap), r * (bh + gap))
            b:SetSize(bw, bh)
            b:SetText("")
            b.Paint = function(s, w, h)
                local active = LocalPlayer():GetNWString("GRM_SocAnim", "") == def.id
                local bg = MC.card
                if active then bg = MC.cardOn
                elseif S._sel == def.id then bg = MC.cardHl
                elseif s:IsHovered() then bg = Color(44, 54, 72) end
                draw.RoundedBox(6, 0, 0, w, h, bg)
                draw.SimpleText(def.name or def.id, "GRMSoc_Card", 12, h / 2 - 8,
                    MC.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                -- Значок отличает движение от статичной позы.
                local n = #S.Frames(def)
                draw.SimpleText(n > 1 and ("▶ анимация · " .. n .. " кадр." ) or "поза",
                    "GRMSoc_Sm", 12, h / 2 + 10, MC.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            -- Один клик — предпросмотр, двойной — включить. Раньше
            -- любой клик сразу применял позу вслепую.
            b.DoClick = function() S._sel = def.id end
            b.DoDoubleClick = function() sendAndClose(def.id) end
        end
        if #items == 0 then
            local empty = vgui.Create("DLabel", grid)
            empty:SetPos(8, 8) empty:SetSize(360, 24)
            empty:SetText("В этой категории пусто. Админ добавляет в /animstudio.")
            empty:SetTextColor(MC.dim)
        end
    end

    for _, cat in ipairs(cats) do
        local b = vgui.Create("DButton", rail)
        b:Dock(TOP) b:SetTall(34) b:DockMargin(0, 0, 0, 4) b:SetText("")
        b.Paint = function(s, w, h)
            local on = S._menuCat == cat.id
            draw.RoundedBox(6, 0, 0, w, h, on and MC.cardHl or (s:IsHovered() and Color(42, 52, 68) or MC.card))
            draw.SimpleText(cat.name or cat.id, "GRMSoc_Body", 12, h / 2, MC.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        b.DoClick = function() S._menuCat = cat.id S._sel = nil fill() end
    end
    fill()

    local stop = vgui.Create("DButton", f)
    stop:SetPos(206, H - 60) stop:SetSize(190, 32) stop:SetText("")
    stop.Paint = function(s, w, h)
        draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(184, 82, 72) or Color(142, 62, 56))
        draw.SimpleText("СНЯТЬ АНИМАЦИЮ", "GRMSoc_Card", w / 2, h / 2, MC.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    stop.DoClick = function() sendPlay("stop") S.CloseMenu() end

    local hint = vgui.Create("DLabel", f)
    hint:SetPos(406, H - 54) hint:SetSize(200, 22)
    hint:SetText("клик — просмотр, 2×клик — включить")
    hint:SetFont("GRMSoc_Sm")
    hint:SetTextColor(MC.dim)
    if surface and surface.PlaySound then surface.PlaySound("common/wpn_hudon.wav") end
end

function S.OpenRadial() S.OpenMenu() end
function S.CloseRadial() S.CloseMenu() end

S._keyLock = 0
hook.Add("PlayerButtonDown", "GRM_Soc_Key", function(ply, key)
    if ply ~= LocalPlayer() then return end
    if IsValid(S._menu) and (key == MOUSE_RIGHT or key == KEY_ESCAPE) then
        S.CloseMenu()
        return
    end
    if key ~= keyNum() or key <= 0 then return end
    if inputBusy() then return end
    local now = CurTime()
    if now < (S._keyLock or 0) then return end
    S._keyLock = now + 0.35
    -- Удержание не закрывает: повтор клавиши при hold давал мерцание.
    if IsValid(S._menu) then return end
    S.OpenMenu()
end)

hook.Add("StartCommand", "GRM_Soc_MenuFreeze", function(ply, cmd)
    if not IsValid(S._menu) then return end
    if ply ~= LocalPlayer() then return end
    cmd:ClearMovement()
    cmd:RemoveKey(IN_ATTACK)
    cmd:RemoveKey(IN_ATTACK2)
end)

function S.OpenPicker()
    S.OpenMenu()
end

function S.OpenFromContext()
    S.OpenMenu()
end

function S._OpenFromContextLegacy()
    S.OpenMenu()
end

concommand.Add("grm_social", function(_, _, args)
    local a = string.lower(tostring(args[1] or ""))
    if a == "" or a == "menu" then S.OpenFromContext() return end
    sendPlay(a)
end)
concommand.Add("grm_social_stop", function() sendPlay("stop") end)

-- Вкладку «Анимации» не добавляем: в F4 только бинд в «Настройки».

print("[GRM Social] client v" .. S.Version)
