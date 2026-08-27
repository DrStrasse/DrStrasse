--[[--------------------------------------------------------------------
    GRM Spawn Pick v1.0.0 — выбор точки входа в мир.

    ЗАЧЕМ. Раньше после выбора персонажа игрока просто ставили на
    фракционную точку (или на общую, если фракции нет). Дом не давал
    ничего, кроме расходов, а вернуться туда, где вышел, было нельзя.

    ЧТО ЭТО. Экран после подтверждения персонажа: тёмный фон, по центру
    крупные квадратные слоты со значками и подписями:

              ВЫБЕРИТЕ ТОЧКУ ВХОДА
        [ ФРАКЦИЯ ]  [ ДОМ ]  [ ГДЕ ВЫШЕЛ ]

    ТРИ ИСТОЧНИКА:
      faction — GetSpawnPointForPlayer: должность → подотдел → отдел →
                звание → организация (порядок уже задан осями v5);
      home    — жильё из GRM.Property, где игрок владелец или жилец;
      last    — место, где игрок вышел из игры в прошлый раз.

    ПРАВИЛА, КОТОРЫЕ ДЕЛАЮТ ЭТО ЧЕСТНЫМ:
      • один доступный вариант — экран не показывается вовсе;
      • точка выхода не сохраняется после смерти, в аресте и в лимбе:
        иначе это телепорт в тюрьму;
      • опечатанное жильё и просроченная аренда убирают вариант «Дом»;
      • вне службы фракционная точка недоступна.

    ДАННЫЕ: data/grm_spawnpick.json — ключ CharacterKey.
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.SpawnPick = GRM.SpawnPick or {}
local SP = GRM.SpawnPick

SP.Version = "1.0.0"
SP.File = "grm_spawnpick.json"
SP.Data = SP.Data or {}      -- [CharacterKey] = { pos, ang, at, map }

SP.NET = {
    OPEN = "GRM_SpawnPick_Open",
    PICK = "GRM_SpawnPick_Pick",
}

--- Сколько живёт запомненная точка выхода (сутки).
SP.LastLifetime = 86400

-----------------------------------------------------------------------
-- ОБЩАЯ ЧАСТЬ
-----------------------------------------------------------------------

SP.Kinds = {
    { id = "faction", title = "ФРАКЦИЯ", icon = "icon16/shield.png" },
    { id = "home",    title = "ДОМ",     icon = "icon16/house.png" },
    { id = "last",    title = "ГДЕ ВЫШЕЛ", icon = "icon16/flag_blue.png" },
}

local function charKey(ply)
    if GRM.Identity and GRM.Identity.CharacterKey then
        return tostring(GRM.Identity.CharacterKey(ply) or "")
    end
    if GRM.Char and GRM.Char.GetActiveKey then
        return tostring(GRM.Char.GetActiveKey(ply) or "")
    end
    return IsValid(ply) and (ply:SteamID64() .. ":char1") or ""
end
SP.CharKey = charKey

-----------------------------------------------------------------------
-- СЕРВЕР
-----------------------------------------------------------------------
if SERVER then
    util.AddNetworkString(SP.NET.OPEN)
    util.AddNetworkString(SP.NET.PICK)

    local function jsonT(txt)
        local ok, t = pcall(util.JSONToTable, txt, false, true)
        return (ok and istable(t)) and t or nil
    end

    function SP.Load()
        SP.Data = {}
        if not file.Exists(SP.File, "DATA") then return end
        local t = jsonT(file.Read(SP.File, "DATA") or "")
        if istable(t) then SP.Data = t end
    end

    function SP.Save(reason)
        local function write()
            local ok, txt = pcall(util.TableToJSON, SP.Data or {}, true)
            if ok and txt then file.Write(SP.File, txt)
            else ErrorNoHalt("[GRM SpawnPick] не удалось сохранить (" .. tostring(reason) .. ")\n") end
        end
        if GRM.Perf and GRM.Perf.Coalesce then GRM.Perf.Coalesce("grm_spawnpick_save", 1, write)
        else write() end
    end

    SP.Load()

    -----------------------------------------------------------------
    -- ИСТОЧНИК 1: ФРАКЦИЯ
    -----------------------------------------------------------------
    function SP.FactionPoint(ply)
        if not IsValid(ply) then return nil end
        -- Вне службы сотрудник не появляется в штабе.
        if ply:GetNWBool("GRM_FactionOffDuty", false) then return nil end
        local faction = ply:GetNWString("GRM_Faction", "")
        if faction == "" then return nil end
        if not _G.GetSpawnPointForPlayer then return nil end
        local pos, ang = _G.GetSpawnPointForPlayer(ply)
        if not pos then return nil end

        local label = faction
        if GRM.Factions and GRM.Factions.DisplayName then
            label = GRM.Factions.DisplayName(faction)
        end
        --[[ Подпись уточняем по подразделению: игрок должен понимать,
             куда именно его поставят — в штаб или в свой отдел. ]]
        local dept = ply:GetNWString("GRM_DepartmentDisplay", "")
        if dept ~= "" then label = label .. " · " .. dept end
        return { pos = pos, ang = ang, label = label }
    end

    -----------------------------------------------------------------
    -- ИСТОЧНИК 2: ДОМ
    -----------------------------------------------------------------
    --[[ Жильё игрока из GRM.Property. Берём объект, где он владелец или
         вписан жильцом, с живой арендой и не опечатанный. ]]
    function SP.HomePoint(ply)
        if not IsValid(ply) then return nil end
        local P = GRM.Property
        if not (P and istable(P.Records)) then return nil end
        local key = charKey(ply)
        if key == "" then return nil end

        for _, rec in pairs(P.Records) do
            local r = P.Normalize and P.Normalize(rec) or rec
            if istable(r) and istable(r.zone) then
                local isHome = r.type == "apartment"
                local mine = (r.ownerType == "character" and r.ownerKey == key)
                if not mine and P.HasAccess then
                    -- Жилец с ключом тоже вправе появляться дома.
                    mine = P.HasAccess(ply, r) == true and r.ownerType ~= "none"
                end
                -- Опечатанный объект и просроченная аренда домом не считаются.
                local sealed = r.sealed == true
                local rentDead = r.tenure == "rent" and (tonumber(r.rentUntil) or 0) > 0
                    and (tonumber(r.rentUntil) or 0) < os.time()
                if isHome and mine and not sealed and not rentDead then
                    local mins, maxs = r.zone.mins, r.zone.maxs
                    if mins and maxs then
                        local center = Vector(
                            (mins.x + maxs.x) * 0.5,
                            (mins.y + maxs.y) * 0.5,
                            mins.z + 8)
                        return { pos = center, ang = Angle(0, 0, 0),
                            label = r.name ~= "" and r.name or "Ваше жильё" }
                    end
                end
            end
        end
        return nil
    end

    -----------------------------------------------------------------
    -- ИСТОЧНИК 3: ГДЕ ВЫШЕЛ
    -----------------------------------------------------------------
    --[[ Запоминать позицию можно не всегда: мёртвый, арестованный или
         сидящий в лимбе игрок не должен «сохранять» это состояние. ]]
    function SP.CanRemember(ply)
        if not IsValid(ply) then return false end
        if ply.GRMCharLimbo then return false end
        if ply.Alive and not ply:Alive() then return false end
        if ply:GetNWBool("GRM_Arrested", false) then return false end
        if ply:GetNWBool("GRM_CharacterPending", false) then return false end
        if ply:InVehicle() then return false end
        return true
    end

    function SP.Remember(ply)
        if not SP.CanRemember(ply) then return end
        local key = charKey(ply)
        if key == "" then return end
        local pos, ang = ply:GetPos(), ply:EyeAngles()
        SP.Data[key] = {
            pos = { x = pos.x, y = pos.y, z = pos.z },
            ang = { y = ang.y or 0 },
            at = os.time(),
            map = string.lower(game.GetMap() or ""),
        }
        SP.Save("remember")
    end

    --[[ Не даём вернуться в чужое закрытое помещение: игрок мог выйти
         в чужом доме или на закрытой территории, и точка выхода стала бы
         способом попасть туда в обход дверей. ]]
    function SP.PointAllowed(ply, pos)
        local P = GRM.Property
        if not (P and istable(P.Records) and P.IsInside) then return true end
        for _, rec in pairs(P.Records) do
            local r = P.Normalize and P.Normalize(rec) or rec
            if istable(r) and istable(r.zone) and P.IsInside(r, pos) then
                if r.sealed == true then return false end
                if r.ownerType ~= "none" and P.HasAccess and not P.HasAccess(ply, r) then
                    return false
                end
            end
        end
        return true
    end

    function SP.LastPoint(ply)
        local key = charKey(ply)
        local rec = key ~= "" and SP.Data[key]
        if not istable(rec) or not istable(rec.pos) then return nil end
        -- Точка с другой карты бессмысленна.
        if tostring(rec.map or "") ~= string.lower(game.GetMap() or "") then return nil end
        if (os.time() - (tonumber(rec.at) or 0)) > SP.LastLifetime then return nil end
        local pos = Vector(rec.pos.x or 0, rec.pos.y or 0, rec.pos.z or 0)
        if not SP.PointAllowed(ply, pos) then return nil end
        return {
            pos = pos,
            ang = Angle(0, (rec.ang and rec.ang.y) or 0, 0),
            label = "Последнее место",
        }
    end

    -----------------------------------------------------------------
    -- ВАРИАНТЫ И ВЫДАЧА
    -----------------------------------------------------------------
    function SP.Options(ply)
        local out = {}
        local faction = SP.FactionPoint(ply)
        if faction then out[#out + 1] = { id = "faction", title = "ФРАКЦИЯ", label = faction.label } end
        local home = SP.HomePoint(ply)
        if home then out[#out + 1] = { id = "home", title = "ДОМ", label = home.label } end
        local last = SP.LastPoint(ply)
        if last then out[#out + 1] = { id = "last", title = "ГДЕ ВЫШЕЛ", label = last.label } end
        return out
    end

    function SP.Resolve(ply, kind)
        kind = tostring(kind or "")
        if kind == "faction" then return SP.FactionPoint(ply) end
        if kind == "home" then return SP.HomePoint(ply) end
        if kind == "last" then return SP.LastPoint(ply) end
        return nil
    end

    --- Поставить игрока на выбранную точку.
    function SP.Apply(ply, kind)
        local point = SP.Resolve(ply, kind)
        if not point then return false end
        ply:SetPos(point.pos)
        if point.ang then ply:SetEyeAngles(Angle(0, point.ang.y or 0, 0)) end
        ply.GRMSpawnPickDone = true
        hook.Run("GRM_SpawnPicked", ply, kind, point.pos)
        return true
    end

    --[[ Показать экран выбора. Возвращает true, если экран действительно
         нужен: при одном варианте выбирать нечего, ставим сразу. ]]
    function SP.Offer(ply)
        if not IsValid(ply) then return false end
        local options = SP.Options(ply)
        if #options == 0 then return false end
        if #options == 1 then
            SP.Apply(ply, options[1].id)
            return false
        end
        ply.GRMSpawnPickPending = true
        net.Start(SP.NET.OPEN)
            net.WriteTable(options)
        net.Send(ply)
        return true
    end

    net.Receive(SP.NET.PICK, function(_, ply)
        if not IsValid(ply) then return end
        if not ply.GRMSpawnPickPending then return end
        local kind = net.ReadString()
        -- Выбрать можно только реально доступный вариант.
        local allowed = false
        for _, opt in ipairs(SP.Options(ply)) do
            if opt.id == kind then allowed = true break end
        end
        if not allowed then return end
        ply.GRMSpawnPickPending = nil
        SP.Apply(ply, kind)
    end)

    -----------------------------------------------------------------
    -- ВСТРАИВАНИЕ В ЖИЗНЕННЫЙ ЦИКЛ
    -----------------------------------------------------------------
    --[[ Персонаж подтверждён и поставлен на точку — предлагаем выбор.
         Хук поднимает модуль персонажей после выхода из лимба. ]]
    hook.Add("GRM_CharacterConfirmed", "GRM_SpawnPick_Offer", function(ply)
        timer.Simple(0.2, function()
            if IsValid(ply) then SP.Offer(ply) end
        end)
    end)

    -- Запоминаем место выхода.
    hook.Add("PlayerDisconnected", "GRM_SpawnPick_Remember", function(ply)
        SP.Remember(ply)
    end)
    -- И при смене персонажа: у каждого своё место.
    hook.Add("GRM_CharacterChanged", "GRM_SpawnPick_RememberSwap", function(ply, oldKey)
        if not (IsValid(ply) and isstring(oldKey) and oldKey ~= "") then return end
        if not SP.CanRemember(ply) then return end
        local pos, ang = ply:GetPos(), ply:EyeAngles()
        SP.Data[oldKey] = {
            pos = { x = pos.x, y = pos.y, z = pos.z },
            ang = { y = ang.y or 0 },
            at = os.time(),
            map = string.lower(game.GetMap() or ""),
        }
        SP.Save("swap")
    end)

    hook.Add("ShutDown", "GRM_SpawnPick_SaveAll", function()
        for _, ply in ipairs(player.GetAll()) do SP.Remember(ply) end
    end)

    --- Диагностика: grm_spawnpick
    concommand.Add("grm_spawnpick", function(ply)
        if not IsValid(ply) then return end
        local options = SP.Options(ply)
        ply:PrintMessage(HUD_PRINTTALK, "[Точка входа] доступно вариантов: " .. #options)
        for _, opt in ipairs(options) do
            ply:PrintMessage(HUD_PRINTTALK, "  " .. opt.title .. " — " .. tostring(opt.label))
        end
    end)

    if GRM.Modules and GRM.Modules.Register then
        GRM.Modules.Register("spawnpick", {
            label = "Точки входа",
            version = SP.Version,
            Status = function() return "запомнено мест: " .. tostring(table.Count(SP.Data or {})) end,
            Depends = { "factions" },
        })
    end
end

-----------------------------------------------------------------------
-- КЛИЕНТ
-----------------------------------------------------------------------
if CLIENT then
    surface.CreateFont("GRMSpawn_Title", { font = "Roboto", size = 30, weight = 800, extended = true, antialias = true })
    surface.CreateFont("GRMSpawn_Slot",  { font = "Roboto", size = 18, weight = 700, extended = true, antialias = true })
    surface.CreateFont("GRMSpawn_Sub",   { font = "Roboto", size = 13, weight = 500, extended = true, antialias = true })

    local C = {
        text   = Color(238, 243, 250),
        dim    = Color(150, 163, 180),
        gold   = Color(245, 198, 70),
        slot   = Color(26, 33, 45, 250),
        slotH  = Color(38, 50, 68, 250),
        border = Color(60, 74, 96),
    }

    local frame

    local function openPick(options)
        if IsValid(frame) then frame:Remove() end

        local f = vgui.Create("DFrame")
        frame = f
        f:SetSize(ScrW(), ScrH())
        f:SetPos(0, 0)
        f:MakePopup()
        f:SetTitle("")
        f:ShowCloseButton(false)
        f:SetDraggable(false)
        -- Экран обязательный: закрыть его нельзя, пока точка не выбрана.
        f.OnKeyCodePressed = function(_, key) if key == KEY_ESCAPE then return true end end
        f.Paint = function(_, w, h)
            -- Тёмный фон, как просил владелец.
            draw.RoundedBox(0, 0, 0, w, h, Color(6, 8, 13, 245))
            draw.SimpleText("ВЫБЕРИТЕ ТОЧКУ ВХОДА", "GRMSpawn_Title", w / 2, h / 2 - 170,
                C.gold, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText("Откуда ваш персонаж начнёт эту смену", "GRMSpawn_Sub",
                w / 2, h / 2 - 138, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        -- Крупные квадратные слоты по центру.
        local size, gap = 190, 26
        local total = #options * size + (#options - 1) * gap
        local startX = ScrW() / 2 - total / 2
        local y = ScrH() / 2 - size / 2 + 10

        for i, opt in ipairs(options) do
            local x = startX + (i - 1) * (size + gap)
            local btn = vgui.Create("DButton", f)
            btn:SetText("")
            btn:SetPos(x, y)
            btn:SetSize(size, size)

            local mat
            for _, kind in ipairs(GRM.SpawnPick.Kinds) do
                if kind.id == opt.id then mat = Material(kind.icon, "smooth") break end
            end

            btn.Paint = function(self, w, h)
                local hovered = self:IsHovered()
                draw.RoundedBox(10, 0, 0, w, h, hovered and C.slotH or C.slot)
                surface.SetDrawColor(hovered and C.gold or C.border)
                surface.DrawOutlinedRect(0, 0, w, h, hovered and 2 or 1)
                if mat then
                    surface.SetMaterial(mat)
                    surface.SetDrawColor(hovered and C.gold or C.text)
                    surface.DrawTexturedRect(w / 2 - 24, 42, 48, 48)
                end
                draw.SimpleText(opt.title, "GRMSpawn_Slot", w / 2, h - 62,
                    hovered and C.gold or C.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
                -- Подпись поясняет, куда именно поставят.
                draw.SimpleText(tostring(opt.label or ""), "GRMSpawn_Sub", w / 2, h - 36,
                    C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end

            btn.DoClick = function()
                surface.PlaySound("buttons/button14.wav")
                net.Start(GRM.SpawnPick.NET.PICK)
                    net.WriteString(opt.id)
                net.SendToServer()
                f:Remove()
            end
        end
    end

    net.Receive(GRM.SpawnPick.NET.OPEN, function()
        local options = net.ReadTable() or {}
        if #options == 0 then return end
        openPick(options)
    end)
end
