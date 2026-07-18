--[[--------------------------------------------------------------------
    GRM Identity Core v1.1.0 (Код 72) — Персонажи, RP-имена, регистрация
    v1.1.0: ширина меню удвоена (до 1880 px, адаптивно под экран).
    Ядро + точки расширения (патчи-провайдеры):

      - При КАЖДОМ входе игрок встречает меню персонажа:
        нет персонажа → создание (RP-имя + внешность с живым превью);
        есть персонаж → продолжить / изменить имя / изменить внешность.
      - RP-имя хранится на сервере (grm_characters.json) и рассылается
        клиентам (NWString GRM_RPName). Команда /name Имя Фамилия.
      - Внешность (модель/skin/bodygroups) валидируется против списков
        фракционной системы (DefaultModels → фракция/роль/отдел) и
        применяется через FactionsExt ApplyModelSettings — аппарат
        строгого удержания внешности (ModelCheck) конфликтов не даёт.
      - PROVIDER API (патчи): GRM.Char.RegisterProvider(id, def) —
        меню персонажа собирается из провайдеров; фракционный гардероб
        уже встроен как провайдер "faction". Любой будущий модуль
        (гардероб-энтити, работы, лицензии) добавляет свои секции без
        правок ядра.
      - Синхронизация со спавн-поинтами: при первичной регистрации члена
        фракции игрок переносится на фракционную точку (GetSpawnPointForPlayer).
    Данные: data/grm_characters.json  (ключи sid64 — чтение ТОЛЬКО jsonT c
    третьим аргументом, урок находки 65).
----------------------------------------------------------------------]]

if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Char = GRM.Char or {}
local CH = GRM.Char

CH.Version    = "1.1.0"
CH.NameMin    = 3     -- минимальная длина RP-имени
CH.NameMax    = 48
CH.DataFile   = "grm_characters.json"

local NET_OPEN    = "GRM_Char_Open"
local NET_SAVE    = "GRM_Char_Save"
local NET_REQUEST = "GRM_Char_Request"

-- ------------------------------------------------------------
-- SHARED: валидация имени и нормализация внешности
-- ------------------------------------------------------------
function CH.ValidateName(raw)
    local s = string.Trim(tostring(raw or ""))
    s = string.gsub(s, "%s+", " ")
    if #s < CH.NameMin then return nil, "Имя короче " .. CH.NameMin .. " символов" end
    if #s > CH.NameMax then s = string.sub(s, 1, CH.NameMax) end
    return s
end

function CH.GetName(plyOrSid64)
    if IsValid(plyOrSid64) and plyOrSid64:IsPlayer() then
        return plyOrSid64:GetNWString("GRM_RPName", "")
    end
    return ""
end

-- ------------------------------------------------------------
-- Провайдер-патчи (shared-регистрация, исполнение на сервере)
-- def = { Order=100, Title=function(ply).., Outfits=function(ply) -> {entry,...} }
-- entry = { path=..., skin=0, bodygroups={} }
-- ------------------------------------------------------------
CH.Providers = CH.Providers or {}
function CH.RegisterProvider(id, def)
    if not isstring(id) or not istable(def) then return end
    if not isfunction(def.Outfits) then return end
    CH.Providers[id] = def
    table.sort(CH.ProvidersSort or {}, function() end) -- no-op guard
end

-- ============================================================
-- СЕРВЕР
-- ============================================================
if SERVER then
    util.AddNetworkString(NET_OPEN)
    util.AddNetworkString(NET_SAVE)
    util.AddNetworkString(NET_REQUEST)

    local function jsonT(txt)
        local ok, t = pcall(util.JSONToTable, txt, false, true)
        return (ok and istable(t)) and t or nil
    end

    local function loadChars()
        CH.Data = CH.Data or {}
        if not file.Exists(CH.DataFile, "DATA") then return CH.Data end
        local t = jsonT(file.Read(CH.DataFile, "DATA") or "")
        if istable(t) then CH.Data = t end
        return CH.Data
    end

    local function saveChars(reason)
        local ok, txt = pcall(util.TableToJSON, CH.Data or {}, true)
        if ok and txt then
            file.Write(CH.DataFile, txt)
            local back = readbackCheck()
            if not back then
                ErrorNoHalt("[GRM Char] SAVE FAIL (" .. tostring(reason) .. ")\n")
            end
        end
    end
    function readbackCheck()
        local t = file.Read(CH.DataFile, "DATA")
        return t ~= nil and #t > 2
    end

    loadChars()

    local function sid64(ply) return IsValid(ply) and ply:SteamID64() or "" end

    function CH.Get(ply)
        return (CH.Data or {})[sid64(ply)]
    end

    function CH.SetName(ply, name)
        name = CH.ValidateName(name)
        if not name then return false, "Некорректное имя" end
        CH.Data[sid64(ply)] = istable(CH.Data[sid64(ply)]) and CH.Data[sid64(ply)] or {}
        CH.Data[sid64(ply)].name = name
        CH.Data[sid64(ply)].updated = os.time()
        ply:SetNWString("GRM_RPName", name)
        saveChars("setname")
        return true
    end

    local function isAllowedModel(ply, path)
        if _G.IsModelAllowedForPlayer then
            return _G.IsModelAllowedForPlayer(ply, path)
        end
        return true
    end

    function CH.ApplyAppearance(ply, entry)
        if not IsValid(ply) or not istable(entry) or not isstring(entry.path) then return false end
        if not isAllowedModel(ply, entry.path) then return false, "Модель не разрешена вашей фракцией/ролью" end

        if _G.ApplyModelSettings then
            _G.ApplyModelSettings(ply, { path = entry.path, skin = tonumber(entry.skin) or 0, bodygroups = entry.bodygroups or {} })
        else
            ply:SetModel(entry.path)
            ply:SetSkin(tonumber(entry.skin) or 0)
            local count = ply:GetNumBodyGroups() or 0
            for i = 0, count - 1 do ply:SetBodygroup(i, 0) end
            for g, v in pairs(entry.bodygroups or {}) do
                ply:SetBodygroup(tonumber(g) or 0, tonumber(v) or 0)
            end
        end
        -- синхронизация со строгим удержанием FactionsExt: эта запись побеждает в ModelCheck
        ply.FactionsExt_DesiredModelData = { path = entry.path, skin = tonumber(entry.skin) or 0, bodygroups = table.Copy(entry.bodygroups or {}) }

        CH.Data[sid64(ply)] = istable(CH.Data[sid64(ply)]) and CH.Data[sid64(ply)] or {}
        CH.Data[sid64(ply)].model = entry.path
        CH.Data[sid64(ply)].skin = tonumber(entry.skin) or 0
        CH.Data[sid64(ply)].bodygroups = table.Copy(entry.bodygroups or {})
        CH.Data[sid64(ply)].updated = os.time()
        saveChars("appearance")
        return true
    end

    -- провайдеры по умолчанию -----------------------------------
    CH.RegisterProvider("civilian", {
        Order = 10,
        Title = function(ply) return "Гражданская внешность" end,
        Outfits = function(ply)
            local out = {}
            if istable(DefaultModels) then
                for _, e in ipairs(DefaultModels) do
                    if istable(e) and isstring(e.path) then out[#out + 1] = { path = e.path, skin = tonumber(e.skin) or 0, bodygroups = table.Copy(istable(e.bodygroups) and e.bodygroups or {}) } end
                end
            end
            return out
        end,
    })

    CH.RegisterProvider("faction", {
        Order = 20,
        Title = function(ply)
            if not istable(Factions) then return "Фракция" end
            local sid, s64 = ply:SteamID(), ply:SteamID64()
            for n, f in pairs(Factions) do
                if istable(f) and istable(f.Members) and (f.Members[sid] or f.Members[s64]) then
                    local m = f.Members[sid] or f.Members[s64]
                    return "Фракция: " .. n .. (m.Role and (" — " .. tostring(m.Role)) or "")
                end
            end
            return nil -- скрыть секцию для гражданских
        end,
        Outfits = function(ply)
            if _G.GetModelsForPlayer then
                local hasFaction = false
                if istable(Factions) then
                    local sid, s64 = ply:SteamID(), ply:SteamID64()
                    for _, f in pairs(Factions) do
                        if istable(f) and istable(f.Members) and (f.Members[sid] or f.Members[s64]) then hasFaction = true break end
                    end
                end
                if not hasFaction then return {} end
                local out = {}
                for _, e in ipairs(_G.GetModelsForPlayer(ply) or {}) do
                    if istable(e) and isstring(e.path) then out[#out + 1] = { path = e.path, skin = tonumber(e.skin) or 0, bodygroups = table.Copy(istable(e.bodygroups) and e.bodygroups or {}) } end
                end
                return out
            end
            return {}
        end,
    })

    -- полезная нагрузка меню ------------------------------------
    -- opts: { wardrobe=bool, title=str, allowCivilian/allowFaction/
    --         allowSkin/allowBodygroups = bool|nil, ent=Entity }
    function CH.BuildPayload(ply, opts)
        opts = istable(opts) and opts or {}
        local sections = {}
        local ids = {}
        for id in pairs(CH.Providers) do ids[#ids + 1] = id end
        table.sort(ids, function(a, b)
            local oa = tonumber(CH.Providers[a].Order) or 100
            local ob = tonumber(CH.Providers[b].Order) or 100
            if oa == ob then return a < b end
            return oa < ob
        end)
        for _, id in ipairs(ids) do
            if opts.wardrobe and id == "civilian" and opts.allowCivilian == false then continue end
            if opts.wardrobe and id == "faction" and opts.allowFaction == false then continue end
            local def = CH.Providers[id]
            local okT, title = pcall(def.Title or function() return id end, ply)
            if okT and title then
                local okO, outfits = pcall(def.Outfits, ply)
                if okO and istable(outfits) and #outfits > 0 then
                    sections[#sections + 1] = { id = id, title = tostring(title), outfits = outfits }
                end
            end
        end
        return {
            char = CH.Get(ply),
            sections = sections,
            nameMin = CH.NameMin, nameMax = CH.NameMax,
            wardrobe = opts.wardrobe == true or nil,
            wardrobeTitle = opts.title,
            wardrobeEnt = IsValid(opts.ent) and opts.ent:EntIndex() or nil,
            allowSkin = opts.allowSkin, allowBodygroups = opts.allowBodygroups,
            isAdmin = ply:IsSuperAdmin() or nil,
        }
    end

    local function sendMenu(ply)
        if not IsValid(ply) then return end
        net.Start(NET_OPEN)
            net.WriteTable(CH.BuildPayload(ply))
        net.Send(ply)
    end
    CH.OpenMenu = sendMenu

    -- вход: меню при КАЖДОМ заходе -------------------------------
    hook.Add("PlayerInitialSpawn", "GRM_Char_OnJoin", function(ply)
        timer.Simple(1.5, function() if IsValid(ply) then sendMenu(ply) end end)
        timer.Simple(2.2, function()
            if not IsValid(ply) then return end
            local c = CH.Get(ply)
            ply:SetNWString("GRM_RPName", istable(c) and tostring(c.name or "") or "")
            -- мягкое восстановление внешности персонажа (фракционная система может перекрыть позже — это ок)
            if istable(c) and isstring(c.model) and c.model ~= "" then
                CH.ApplyAppearance(ply, { path = c.model, skin = c.skin, bodygroups = c.bodygroups })
            end
        end)
    end)

    net.Receive(NET_REQUEST, function(_, ply) sendMenu(ply) end)

    net.Receive(NET_SAVE, function(_, ply)
        if not IsValid(ply) then return end
        local d = net.ReadTable() or {}
        local wasNew = CH.Get(ply) == nil

        if d.name ~= nil then
            local ok, err = CH.SetName(ply, d.name)
            if not ok then
                if GRM.Notify then GRM.Notify(ply, tostring(err), 255, 100, 100) end
            end
        end

        if isstring(d.model) and d.model ~= "" then
            local bg = {}
            for g, v in pairs(d.bodygroups or {}) do
                local gi, vi = tonumber(g), tonumber(v)
                if gi and vi and vi ~= 0 then bg[gi] = vi end
            end
            local ok, err = CH.ApplyAppearance(ply, { path = d.model, skin = tonumber(d.skin) or 0, bodygroups = bg })
            if not ok and GRM.Notify then GRM.Notify(ply, tostring(err or "Не удалось применить внешность"), 255, 100, 100) end
            if ok and GRM.Notify then GRM.Notify(ply, "Внешность персонажа сохранена.", 100, 220, 100) end
        end

        -- первичная регистрация: синхронизируем с фракционным спавном
        if wasNew and CH.Get(ply) ~= nil and _G.GetSpawnPointForPlayer then
            local pos, ang = _G.GetSpawnPointForPlayer(ply)
            if pos then
                ply:SetPos(pos)
                if ang then ply:SetEyeAngles(ang) end
            end
        end

        timer.Simple(0.35, function() if IsValid(ply) then sendMenu(ply) end end)
    end)

    -- команда /name Имя Фамилия ----------------------------------
    hook.Add("PlayerSay", "GRM_Char_NameCmd", function(ply, text)
        local t = string.Trim(text or "")
        local low = string.lower(t)
        if string.sub(low, 1, 6) == "/name " or string.sub(low, 1, 6) == "!name " then
            local ok, resOrErr = CH.SetName(ply, string.sub(t, 7))
            if ok then
                ply:PrintMessage(HUD_PRINTTALK, "[Персонаж] Игровое имя установлено: " .. tostring(CH.GetName(ply)))
            else
                ply:PrintMessage(HUD_PRINTTALK, "[Персонаж] " .. tostring(resOrErr))
            end
            return ""
        end
        if low == "/name" or low == "!name" then
            ply:PrintMessage(HUD_PRINTTALK, "[Персонаж] Ваше игровое имя: " .. (CH.GetName(ply) ~= "" and CH.GetName(ply) or "(не задано — откройте F4 → Персонаж)"))
            return ""
        end
    end)

    -- автосохранение уже не нужно (каждый Save пишет сразу), но подстрахуемся на выключении
    hook.Add("ShutDown", "GRM_Char_Save", function() saveChars("shutdown") end)

    print("[GRM Char] Ядро персонажей v" .. CH.Version .. " загружено (сервер)")
end

-- ============================================================
-- КЛИЕНТ
-- ============================================================
if CLIENT then
    surface.CreateFont("GRMChar_Title",  { font = "Roboto", size = 20, weight = 800, extended = true })
    surface.CreateFont("GRMChar_Sub",    { font = "Roboto", size = 15, weight = 600, extended = true })
    surface.CreateFont("GRMChar_Normal", { font = "Roboto", size = 13, weight = 500, extended = true })

    local C = {
        bg    = Color(20, 24, 32, 252),
        head  = Color(28, 34, 46, 255),
        panel = Color(32, 38, 50, 245),
        panel2= Color(26, 32, 42, 245),
        acc   = Color(70, 150, 240),
        green = Color(60, 190, 110),
        red   = Color(220, 75, 70),
        yellow= Color(230, 180, 60),
        text  = Color(240, 245, 250),
        dim   = Color(160, 170, 185),
    }

    local function mkBtn(p, txt, col)
        local b = vgui.Create("DButton", p)
        b:SetText(txt) b:SetFont("GRMChar_Sub") b:SetTextColor(color_white)
        b.Paint = function(self, pw, ph)
            local cc = col or C.acc
            if not self:IsEnabled() then cc = Color(60, 65, 75)
            elseif self:IsHovered() then cc = Color(math.min(255, cc.r + 25), math.min(255, cc.g + 25), math.min(255, cc.b + 25)) end
            draw.RoundedBox(6, 0, 0, pw, ph, cc)
        end
        return b
    end

    -----------------------------------------------------------
    -- Главное меню персонажа
    -----------------------------------------------------------
    local function openCharMenu(payload)
        payload = istable(payload) and payload or {}
        local char = istable(payload.char) and payload.char or nil
        local sections = istable(payload.sections) and payload.sections or {}

        -- состояние редактора (черновик)
        local draft = {
            name = char and tostring(char.name or "") or "",
            model = char and tostring(char.model or "") or "",
            skin = char and tonumber(char.skin) or 0,
            bodygroups = char and table.Copy(char.bodygroups or {}) or {},
        }
        if draft.model == "" and sections[1] and sections[1].outfits and sections[1].outfits[1] then
            draft.model = sections[1].outfits[1].path
            draft.skin = tonumber(sections[1].outfits[1].skin) or 0
            draft.bodygroups = table.Copy(sections[1].outfits[1].bodygroups or {})
        end

        if IsValid(CH._frame) then CH._frame:Remove() end
        local f = vgui.Create("DFrame")
        CH._frame = f
        f:SetTitle("")
        -- меню в два раза шире прежнего (940 → 1880), но не шире экрана
        local fw = math.min(1880, ScrW() - 16)
        local fh = math.min(620, ScrH() - 40)
        local leftW = math.floor(fw * 0.52)
        f:SetSize(fw, fh)
        f:Center()
        f:MakePopup()
        f:ShowCloseButton(false)
        f.Paint = function(_, pw, ph)
            draw.RoundedBox(8, 0, 0, pw, ph, C.bg)
            draw.RoundedBoxEx(8, 0, 0, pw, 44, C.head, true, true, false, false)
            local ttl = payload.wardrobe and tostring(payload.wardrobeTitle or "Гардероб")
                or (char and "Меню персонажа" or "Создание персонажа")
            draw.SimpleText(ttl, "GRMChar_Title", 16, 22, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            draw.SimpleText("GRM Identity v" .. CH.Version, "GRMChar_Normal", pw - 16, 22, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end

        local function canClose() return char ~= nil or payload.wardrobe == true end

        local x = vgui.Create("DButton", f)
        x:SetText("X") x:SetFont("GRMChar_Title") x:SetTextColor(color_white)
        x:SetPos(fw - 44, 8) x:SetSize(32, 28)
        x.DoClick = function()
            if canClose() then f:Close() else surface.PlaySound("buttons/button10.wav") end
        end
        x.Paint = function(self, pw, ph) draw.RoundedBox(4, 0, 0, pw, ph, self:IsHovered() and C.red or Color(45, 52, 68)) end

        -- админская кнопка настройки гардероба
        if payload.wardrobe and payload.isAdmin and payload.wardrobeEnt then
            local bCfg = mkBtn(f, "⚙ Настройка гардероба", C.yellow)
            bCfg:SetTextColor(Color(30, 28, 20))
            bCfg:SetPos(fw - 320, 8) bCfg:SetSize(220, 28)
            bCfg.DoClick = function()
                net.Start("GRM_Wardrobe_CfgReq")
                    net.WriteUInt(tonumber(payload.wardrobeEnt) or 0, 16)
                net.SendToServer()
                f:Close()
            end
        end

        -- ЛЕВАЯ КОЛОНКА: имя + провайдеры (список внешностей)
        local left = vgui.Create("DPanel", f)
        left:Dock(LEFT) left:DockMargin(10, 54, 4, 10) left:SetWide(leftW)
        left:SetPaintBackground(false)

        local nameBox = vgui.Create("DPanel", left)
        nameBox:Dock(TOP) nameBox:SetTall(86) nameBox:DockMargin(0, 0, 0, 6)
        nameBox.Paint = function(_, pw, ph)
            draw.RoundedBox(6, 0, 0, pw, ph, C.panel)
            draw.SimpleText("Игровое имя (RP Name)", "GRMChar_Sub", 10, 14, C.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        end
        local nameEntry = vgui.Create("DTextEntry", nameBox)
        nameEntry:SetPos(10, 30) nameEntry:SetSize(math.min(560, leftW - 30), 30)
        nameEntry:SetFont("GRMChar_Sub")
        nameEntry:SetPlaceholderText("Имя Фамилия")
        nameEntry:SetText(draft.name)
        nameEntry:SetUpdateOnType(true)
        nameEntry.OnChange = function() draft.name = nameEntry:GetValue() end
        local nameHint = vgui.Create("DLabel", nameBox)
        nameHint:SetPos(10, 62) nameHint:SetSize(leftW - 20, 20) nameHint:SetFont("GRMChar_Normal") nameHint:SetTextColor(C.dim)
        local function updHint()
            local n = CH.ValidateName(draft.name)
            nameHint:SetText(n and ("OK: «" .. n .. "»") or ("Имя: мин. " .. (payload.nameMin or 3) .. " символа"))
            nameHint:SetTextColor(n and C.green or C.red)
        end
        updHint() nameEntry.OnChange = function() draft.name = nameEntry:GetValue() updHint() end

        -- ПРАВАЯ КОЛОНКА: превью + настройка модели
        local right = vgui.Create("DPanel", f)
        right:Dock(FILL) right:DockMargin(4, 54, 10, 10)
        right:SetPaintBackground(false)

        local preview = vgui.Create("DAdjustableModelPanel", right)
        preview:Dock(FILL) preview:DockMargin(0, 0, 0, 6)
        preview:SetFOV(40)

        local function refreshPreview()
            if not IsValid(preview) then return end
            if draft.model == "" then return end
            preview:SetModel(draft.model)
            local ent = preview:GetEntity()
            if IsValid(ent) then
                ent:SetSkin(math.Clamp(tonumber(draft.skin) or 0, 0, 64))
                for i = 0, (ent:GetNumBodyGroups() or 1) - 1 do ent:SetBodygroup(i, 0) end
                for g, v in pairs(draft.bodygroups or {}) do
                    ent:SetBodygroup(tonumber(g) or 0, tonumber(v) or 0)
                end
            end
        end
        refreshPreview()

        local sets = vgui.Create("DPanel", right)
        sets:Dock(BOTTOM) sets:SetTall(132) sets:SetPaintBackground(false)

        local skinLbl = vgui.Create("DLabel", sets)
        skinLbl:Dock(TOP) skinLbl:SetTall(18) skinLbl:SetFont("GRMChar_Sub") skinLbl:SetTextColor(C.text)
        skinLbl:SetText("Скин")

        local skinSlider = vgui.Create("DNumSlider", sets)
        skinSlider:Dock(TOP) skinSlider:SetTall(26)
        skinSlider:SetMin(0) skinSlider:SetDecimals(0)
        skinSlider:SetValue(draft.skin)
        skinSlider.OnValueChanged = function(_, val)
            draft.skin = math.floor(tonumber(val) or 0)
            local ent = IsValid(preview) and preview:GetEntity()
            if IsValid(ent) then ent:SetSkin(draft.skin) end
        end
        -- гардероб может отключать настройку скинов
        if payload.allowSkin == false then
            skinLbl:SetVisible(false) skinSlider:SetVisible(false)
            sets:SetTall(88)
        end
        -- и настройку бодигрупп
        if payload.allowBodygroups == false then
            sets:SetTall(payload.allowSkin == false and 4 or 60)
        end
        local function refreshSkinMax()
            local ent = IsValid(preview) and preview:GetEntity()
            local mx = IsValid(ent) and (ent:SkinCount() - 1) or 0
            skinSlider:SetMax(mx)
            if draft.skin > mx then draft.skin = mx skinSlider:SetValue(mx) end
            skinLbl:SetText("Скин (макс: " .. mx .. ")")
        end
        refreshSkinMax()

        -- bodygroups
        local bgScroll = vgui.Create("DScrollPanel", sets)
        bgScroll:Dock(FILL) bgScroll:DockMargin(0, 4, 0, 0)
        if payload.allowBodygroups == false then bgScroll:SetVisible(false) end

        local function rebuildBodygroups()
            bgScroll:Clear()
            local ent = IsValid(preview) and preview:GetEntity()
            if not IsValid(ent) then return end
            local n = ent:GetNumBodyGroups() or 0
            for i = 0, n - 1 do
                local count = ent:GetBodygroupCount(i) or 1
                if count > 1 then
                    local row = vgui.Create("DPanel", bgScroll)
                    row:Dock(TOP) row:SetTall(24) row:DockMargin(0, 0, 0, 2)
                    row.Paint = function(_, pw, ph) draw.RoundedBox(4, 0, 0, pw, ph, C.panel2) end
                    local gname = ent:GetBodygroupName(i) or ("Группа " .. i)
                    local cur = tonumber(draft.bodygroups[i]) or 0

                    local bL = mkBtn(row, "◀", C.acc) bL:Dock(LEFT) bL:SetWide(30) bL:DockMargin(2, 2, 0, 2)
                    local bR = mkBtn(row, "▶", C.acc) bR:Dock(RIGHT) bR:SetWide(30) bR:DockMargin(0, 2, 2, 2)
                    local valLbl = vgui.Create("DLabel", row)
                    valLbl:Dock(FILL) valLbl:DockMargin(6, 0, 6, 0)
                    valLbl:SetFont("GRMChar_Normal") valLbl:SetTextColor(C.text)
                    local function upd()
                        local v = tonumber(draft.bodygroups[i]) or 0
                        valLbl:SetText(gname .. ":  " .. v .. " / " .. (count - 1))
                        valLbl:SizeToContentsX() valLbl:SetWide(190)
                        ent:SetBodygroup(i, v)
                    end
                    bL.DoClick = function()
                        local v = tonumber(draft.bodygroups[i]) or 0
                        v = (v - 1) % count
                        draft.bodygroups[i] = v
                        if v == 0 then draft.bodygroups[i] = nil end
                        upd()
                    end
                    bR.DoClick = function()
                        local v = tonumber(draft.bodygroups[i]) or 0
                        v = (v + 1) % count
                        draft.bodygroups[i] = v
                        if v == 0 then draft.bodygroups[i] = nil end
                        upd()
                    end
                    upd()
                end
            end
            if bgScroll:GetCanvas():GetTall() <= 2 then
                local none = vgui.Create("DLabel", bgScroll)
                none:Dock(TOP) none:SetText("У этой модели нет бодигрупп для настройки.")
                none:SetFont("GRMChar_Normal") none:SetTextColor(C.dim)
            end
        end
        rebuildBodygroups()

        local function selectModel(entry)
            draft.model = entry.path
            draft.skin = tonumber(entry.skin) or 0
            draft.bodygroups = table.Copy(entry.bodygroups or {})
            refreshPreview()
            refreshSkinMax()
            skinSlider:SetValue(draft.skin)
            rebuildBodygroups()
        end

        -- секции провайдеров (вкладками)
        local sheet = vgui.Create("DPropertySheet", left)
        sheet:Dock(FILL)
        for _, sec in ipairs(sections) do
            local sc = vgui.Create("DScrollPanel")
            sc:DockMargin(2, 2, 2, 2)
            for _, entry in ipairs(sec.outfits or {}) do
                local row = vgui.Create("DPanel", sc)
                row:Dock(TOP) row:SetTall(58) row:DockMargin(0, 0, 0, 4)
                local isSel = (entry.path == draft.model)
                row.Paint = function(_, pw, ph)
                    draw.RoundedBox(6, 0, 0, pw, ph, (entry.path == draft.model) and Color(44, 66, 96) or C.panel)
                end

                local icon = vgui.Create("SpawnIcon", row)
                icon:Dock(LEFT) icon:SetWide(54) icon:DockMargin(3, 3, 0, 3)
                icon:SetModel(entry.path, tonumber(entry.skin) or 0)
                icon:SetTooltip(false)
                icon:SetMouseInputEnabled(false)

                local bn = mkBtn(row, string.GetFileFromFilename(entry.path) or entry.path, C.panel)
                bn:Dock(FILL) bn:DockMargin(0, 3, 3, 3)
                bn:SetFont("GRMChar_Normal") bn:SetTextColor(C.text)
                bn.Paint = function(self, pw, ph)
                    local cc = (entry.path == draft.model) and Color(44, 66, 96) or C.panel2
                    if self:IsHovered() then cc = Color(cc.r + 14, cc.g + 14, cc.b + 14) end
                    draw.RoundedBox(5, 0, 0, pw, ph, cc)
                end
                bn:SetText(tostring(entry.path))
                bn.DoClick = function()
                    selectModel(entry)
                    surface.PlaySound("buttons/button15.wav")
                end
            end
            sheet:AddSheet(sec.title or sec.id, sc, "icon16/user.png")
        end

        -- НИЗ: действия
        local bot = vgui.Create("DPanel", f)
        bot:Dock(BOTTOM) bot:SetTall(50) bot:DockMargin(10, 0, 10, 10)
        bot:SetPaintBackground(false)

        local bContinue = mkBtn(bot, char and "Продолжить" or "", C.acc)
        bContinue:Dock(RIGHT) bContinue:SetWide(150) bContinue:DockMargin(8, 6, 0, 6)
        bContinue:SetVisible(char ~= nil)
        bContinue.DoClick = function() f:Close() end

        local bSave = mkBtn(bot, char and "Сохранить изменения" or "Создать персонажа", C.green)
        bSave:Dock(RIGHT) bSave:SetWide(230) bSave:DockMargin(8, 6, 0, 6)
        bSave.DoClick = function()
            local nm = CH.ValidateName(draft.name)
            if not nm then
                Derma_Message("Укажите игровое имя (мин. " .. (payload.nameMin or 3) .. " символа).", "Персонаж", "Ок")
                return
            end
            net.Start(NET_SAVE)
                net.WriteTable({ name = draft.name, model = draft.model, skin = draft.skin, bodygroups = draft.bodygroups })
            net.SendToServer()
            timer.Simple(0.5, function() if IsValid(f) then f:Close() end end)
        end

        if not char then
            -- акцент: без имени создать нельзя
            bSave:SetText("Создать персонажа (обязательно)")
        end
    end

    net.Receive(NET_OPEN, function()
        openCharMenu(net.ReadTable() or {})
    end)

    -- точка входа гардероба (grm_wardrobe, Код 73)
    CH._openFromWardrobe = openCharMenu

    function CH.OpenMenu()
        net.Start(NET_REQUEST) net.SendToServer()
    end
    concommand.Add("grm_character", CH.OpenMenu)

    hook.Add("PlayerSayTransform", "GRM_Char_ChatCl", function(ply, text)
        if ply ~= LocalPlayer() then return end
        local msg = string.lower(string.Trim(text and (istable(text) and text[1] or text) or ""))
        if msg == "/char" or msg == "/chars" or msg == "!char" then
            CH.OpenMenu()
            if istable(text) then text[1] = "" end
            return true
        end
    end)

    print("[GRM Char] Ядро персонажей v" .. CH.Version .. " загружено (клиент)")
end
