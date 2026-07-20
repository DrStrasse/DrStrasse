--[[--------------------------------------------------------------------
    GRM FFD Link v1.0.0 (Код 108, заказ владельца)
    РУЧНАЯ связь «контроллер → исчезающие двери»:
      контроллер = grm_keypad или grm_scanner, дверь = любой проп с
      isFadingDoor (инструмент FFD Fading Door).

    До Кода 108 кейпад/сканер открывали ВСЕ FFD-двери в радиусе 250 —
    нельзя было сказать «этот кейпад открывает ровно эту дверь».
    Теперь связи задаются вручную инструментом FFD Link
    (stools/ffd_link.lua): ЛКМ по контроллеру — выбор, ЛКМ по двери —
    связать/отвязать. Правила поведения:
      * связей нет        → старое поведение: все FFD-двери в 250;
      * связи есть        → открываются ТОЛЬКО привязанные двери;
      * привязанная дверь удалена → запись само-вычищается (prune),
        а если связей не осталось — снова радиус-фолбэк.

    Хранение: ent.FFDLink_Doors = { {class,x,y,z}, ... } на контроллере.
    Координаты округлены до 0.1 — перебор при resolve сферой 15 юнитов
    (переживает JSON-переупаковку позиций в перм-базе).
    Персистентность: кейпад/сканер складывают links в rec.data перм-базы
    (Extract/Apply в init.lua энтити), плюс duplicator-модификатор
    FFD_LinkList — связи копируются вместе с дубликатом.
    Клиенту на контроллере лежат NW «FFDLinkN» (число связей) и
    «FFDLinkIdx» (EntIndex'ы разрешённых дверей — подсветка стула).
----------------------------------------------------------------------]]

if SERVER then
    AddCSLuaFile()
end

GRM = GRM or {}
GRM.FFDLink = GRM.FFDLink or {}
GRM._ffdLinkVer = "1.0.0"

-- какие энтити могут быть контроллерами связи
local CONTROLLERS = {
    grm_keypad  = true,
    grm_scanner = true,
}

-- shared: контроллер ли это (работает и на клиенте — по классу)
function GRM.FFDLink.IsController(ent)
    if not IsValid(ent) then return false end
    return CONTROLLERS[tostring(ent:GetClass() or "")] == true
end

-- ============================================================
-- SERVER: хранилище, mutate, resolve
-- ============================================================
if SERVER then
    local MAX_LINKS  = 32   -- защита от раздувания одного контроллера
    local FIND_RANGE = 15   -- грубая сфера выборки при разрешении записи
    local ACCEPT     = 1.2  -- юнитов: допуск совпадения позиции (только
                            -- JSON/физический микроджиттер!). Шире нельзя:
                            -- у стены часто стоит ВТОРАЯ дверь в паре юнитов —
                            -- принимать её за удалённую ломануло бы prune
                            -- и «перемкнуло» бы связь на чужую дверь
                            -- (находка 125, стенд-кейс sim_ffdtools №108).

    -- округление до 0.1: позиции переживают JSON-переупаковку перм-базы
    local function r1(v) return math.floor((tonumber(v) or 0) * 10 + 0.5) / 10 end

    -- записанная дверь -> живая энтити (класс + позиция в допуске ACCEPT)
    local function resolveEntry(e)
        if not istable(e) or not isstring(e.class) then return nil end
        local center = Vector(tonumber(e.x) or 0, tonumber(e.y) or 0, tonumber(e.z) or 0)
        local best, bestD = nil, ACCEPT * ACCEPT
        for _, ent in ipairs(ents.FindInSphere(center, FIND_RANGE)) do
            if IsValid(ent) and tostring(ent:GetClass() or "") == e.class then
                local d = ent:GetPos():DistToSqr(center)
                if d <= bestD then best, bestD = ent, d end
            end
        end
        return best
    end
    GRM.FFDLink._resolveEntry = resolveEntry -- для стула/тестов

    -- NW-зеркало для клиента (число + EntIndex'ы разрешённых дверей)
    function GRM.FFDLink.RefreshNW(ctrl)
        if not IsValid(ctrl) then return end
        local idxs = {}
        local n = 0
        for _, e in ipairs(ctrl.FFDLink_Doors or {}) do
            n = n + 1
            local ent = resolveEntry(e)
            if ent then idxs[#idxs + 1] = tostring(ent:EntIndex()) end
        end
        ctrl:SetNWInt("FFDLinkN", n)
        ctrl:SetNWString("FFDLinkIdx", table.concat(idxs, ","))
    end

    -- сериализуемая копия (для перм-базы и дубликатора)
    function GRM.FFDLink.ExportData(ctrl)
        local out = {}
        if not IsValid(ctrl) then return out end
        for _, e in ipairs(ctrl.FFDLink_Doors or {}) do
            if istable(e) and isstring(e.class) then
                out[#out + 1] = {
                    class = e.class,
                    x = tonumber(e.x) or 0,
                    y = tonumber(e.y) or 0,
                    z = tonumber(e.z) or 0,
                }
            end
        end
        return out
    end

    -- обратная развёртка (перм-Apply / дубликат)
    function GRM.FFDLink.ImportData(ctrl, links)
        if not IsValid(ctrl) then return end
        local out = {}
        if istable(links) then
            for _, e in ipairs(links) do
                if istable(e) and isstring(e.class) and e.class ~= "" and #out < MAX_LINKS then
                    out[#out + 1] = {
                        class = e.class,
                        x = tonumber(e.x) or 0,
                        y = tonumber(e.y) or 0,
                        z = tonumber(e.z) or 0,
                    }
                end
            end
        end
        ctrl.FFDLink_Doors = out
        GRM.FFDLink.RefreshNW(ctrl)
    end

    -- дубликатор: связи едут вместе с контроллером
    local function dupeStore(ctrl)
        if not (duplicator and duplicator.StoreEntityModifier) then return end
        pcall(function()
            if #(ctrl.FFDLink_Doors or {}) > 0 then
                duplicator.StoreEntityModifier(ctrl, "FFD_LinkList", { links = GRM.FFDLink.ExportData(ctrl) })
            elseif duplicator.ClearEntityModifier then
                duplicator.ClearEntityModifier(ctrl, "FFD_LinkList")
            end
        end)
    end
    if duplicator and duplicator.RegisterEntityModifier then
        duplicator.RegisterEntityModifier("FFD_LinkList", function(ply, ent, data)
            if istable(data) and istable(data.links) then
                GRM.FFDLink.ImportData(ent, data.links)
            end
        end)
    end

    function GRM.FFDLink.Count(ctrl)
        return (IsValid(ctrl) and istable(ctrl.FFDLink_Doors)) and #ctrl.FFDLink_Doors or 0
    end

    -- индекс записи этой двери в списке контроллера (или nil)
    function GRM.FFDLink.FindIndex(ctrl, door)
        if not (IsValid(ctrl) and IsValid(door)) then return nil end
        local class = tostring(door:GetClass() or "")
        local p = door:GetPos()
        local x, y, z = r1(p.x), r1(p.y), r1(p.z)
        for i, e in ipairs(ctrl.FFDLink_Doors or {}) do
            if e.class == class and e.x == x and e.y == y and e.z == z then
                return i
            end
        end
        return nil
    end

    function GRM.FFDLink.Add(ctrl, door)
        if not (GRM.FFDLink.IsController(ctrl) and IsValid(door)) then return false end
        ctrl.FFDLink_Doors = istable(ctrl.FFDLink_Doors) and ctrl.FFDLink_Doors or {}
        if #ctrl.FFDLink_Doors >= MAX_LINKS then return false end
        if GRM.FFDLink.FindIndex(ctrl, door) then return false end
        local class = tostring(door:GetClass() or "")
        if class == "" then return false end
        local p = door:GetPos()
        ctrl.FFDLink_Doors[#ctrl.FFDLink_Doors + 1] = { class = class, x = r1(p.x), y = r1(p.y), z = r1(p.z) }
        GRM.FFDLink.RefreshNW(ctrl)
        dupeStore(ctrl)
        return true
    end

    function GRM.FFDLink.Remove(ctrl, door)
        local i = GRM.FFDLink.FindIndex(ctrl, door)
        if not i then return false end
        table.remove(ctrl.FFDLink_Doors, i)
        GRM.FFDLink.RefreshNW(ctrl)
        dupeStore(ctrl)
        return true
    end

    -- переключатель: true — связь появилась, false — снята, nil — ошибка
    function GRM.FFDLink.Toggle(ctrl, door)
        if not (GRM.FFDLink.IsController(ctrl) and IsValid(door)) then return nil end
        if GRM.FFDLink.Add(ctrl, door) then return true end
        if GRM.FFDLink.Remove(ctrl, door) then return false end
        return nil -- лимит MAX_LINKS и странные классы
    end

    -- снять ВСЕ связи контроллера; возврат — сколько снято
    function GRM.FFDLink.Clear(ctrl)
        if not GRM.FFDLink.IsController(ctrl) then return 0 end
        local n = GRM.FFDLink.Count(ctrl)
        ctrl.FFDLink_Doors = {}
        GRM.FFDLink.RefreshNW(ctrl)
        dupeStore(ctrl)
        return n
    end

    -- убрать ЭТУ дверь из всех контроллеров карты; возврат — число затронутых
    function GRM.FFDLink.RemoveFromAll(door)
        if not IsValid(door) then return 0 end
        local touched = 0
        for class, _ in pairs(CONTROLLERS) do
            for _, ctrl in ipairs(ents.FindByClass(class)) do
                if IsValid(ctrl) and GRM.FFDLink.FindIndex(ctrl, door) then
                    GRM.FFDLink.Remove(ctrl, door)
                    touched = touched + 1
                end
            end
        end
        return touched
    end

    -- живые двери контроллера (без дублей энтити).
    -- prune=true вычищает записи, уже не разрешающиеся в энтити
    -- (дверь удалили/перенесли): список сам себя лечит.
    function GRM.FFDLink.Resolve(ctrl, prune)
        local doors, keep, changed = {}, {}, false
        for _, e in ipairs(ctrl.FFDLink_Doors or {}) do
            local ent = resolveEntry(e)
            if ent then
                keep[#keep + 1] = e
                local dup = false
                for _, d in ipairs(doors) do if d == ent then dup = true break end end
                if not dup then doors[#doors + 1] = ent end
            else
                changed = true
            end
        end
        if prune and changed then
            ctrl.FFDLink_Doors = keep
            GRM.FFDLink.RefreshNW(ctrl)
            dupeStore(ctrl)
        end
        return doors
    end

    -- открыть/закрыть привязанные двери; возврат: сколько сработало, список.
    -- Вызывающий код БЕРЁТ список и сам гасит те же двери по таймеру —
    -- как кейпад до этого гасил захваченный nearProps.
    function GRM.FFDLink.Fade(ctrl, activate)
        local doors = GRM.FFDLink.Resolve(ctrl, true)
        local n = 0
        for _, d in ipairs(doors) do
            if IsValid(d) and d.isFadingDoor then
                if activate and d.FadeActivate then
                    d:FadeActivate()
                    n = n + 1
                elseif not activate and d.FadeDeactivate then
                    d:FadeDeactivate()
                    n = n + 1
                end
            end
        end
        return n, doors
    end

    print("[GRM FFD Link] v" .. GRM._ffdLinkVer .. ": ручные связи контроллер↔дверь готовы")
end

-- ============================================================
-- CLIENT: NW-зеркало для стула FFD Link (количество + подсветка)
-- ============================================================
if CLIENT then
    function GRM.FFDLink.LinkedCount(ctrl)
        if not IsValid(ctrl) then return 0 end
        return tonumber(ctrl:GetNWInt("FFDLinkN", 0)) or 0
    end

    -- сет EntIndex'ей дверей, разрешённых этим контроллером
    function GRM.FFDLink.LinkedIndexSet(ctrl)
        local set = {}
        if not IsValid(ctrl) then return set end
        local s = tostring(ctrl:GetNWString("FFDLinkIdx", "") or "")
        for tok in string.gmatch(s, "([^,]+)") do
            local i = tonumber(tok)
            if i then set[i] = true end
        end
        return set
    end
end
