--[[--------------------------------------------------------------------
    GRM Heist — клиент ивента «Ограбление» (находка 179e)
    • Огромный баннер вверху экрана: «НАЧАТ ИВЕНТ: ОГРАБЛЕНИЕ» и итоги;
    • обратный отсчёт до конца ивента (50 минут);
    • музыка music/hl2_song20_submix0.mp3 на время ивента.
----------------------------------------------------------------------]]
if not CLIENT then return end

surface.CreateFont("GRMHeist_Banner", { font = "Roboto", size = 64, weight = 1000, extended = true })
surface.CreateFont("GRMHeist_Sub", { font = "Roboto", size = 22, weight = 700, extended = true })
surface.CreateFont("GRMHeist_Timer", { font = "Roboto", size = 26, weight = 900, extended = true })

GRM = GRM or {}
GRM.Heist = GRM.Heist or {}
local Heist = GRM.Heist

Heist.Banner = nil      -- { text, sub, until }
Heist.EventEndsAt = 0   -- реальное время конца (для отсчёта)
Heist.Music = nil

local function stopMusic()
    if IsValid(Heist.Music) then
        Heist.Music:Stop()
        Heist.Music = nil
    end
end

local function startMusic()
    stopMusic()
    -- Находка 179m: музыка ивента — music/hl2_song20_submix0.mp3
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    local path = "music/hl2_song20_submix0.mp3"
    if util and util.PrecacheSound then
        pcall(util.PrecacheSound, path)
    end
    local snd = CreateSound(lp, path)
    if IsValid(snd) then
        snd:EnableLooping(true)
        snd:Play()
        Heist.Music = snd
    end
end

net.Receive("GRM_Heist_Event", function()
    local state = net.ReadString()
    local title = net.ReadString()
    local subtitle = net.ReadString()
    local music = net.ReadBool()
    local endsAt = net.ReadFloat()

    if state == "start" then
        Heist.Banner = { text = title, sub = subtitle, ["until"] = CurTime() + 10 }
        Heist.EventEndsAt = endsAt
        if music then startMusic() end
        surface.PlaySound("buttons/button15.wav")
    elseif state == "end" then
        Heist.Banner = { text = title, sub = subtitle, ["until"] = CurTime() + 12 }
        Heist.EventEndsAt = 0
        stopMusic()
    end
end)

hook.Add("HUDPaint", "GRM_Heist_HUD", function()
    local lp = LocalPlayer()
    if not IsValid(lp) then return end

    -- баннер (огромная надпись вверху экрана)
    local b = Heist.Banner
    if b and b["until"] > CurTime() then
        local alpha = 255
        if b["until"] - CurTime() < 1.5 then alpha = math.floor(255 * (b["until"] - CurTime()) / 1.5) end
        local col = Color(255, 120, 80, alpha)
        draw.SimpleText(b.text, "GRMHeist_Banner", ScrW() / 2, ScrH() * 0.14, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if b.sub and b.sub ~= "" then
            draw.SimpleText(b.sub, "GRMHeist_Sub", ScrW() / 2, ScrH() * 0.14 + 52, Color(245, 240, 220, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        -- подложка для читаемости
        draw.RoundedBox(4, ScrW()/2 - 420, ScrH() * 0.14 - 40, 840, 120, Color(10, 12, 18, 120))
    end

    -- отсчёт во время ивента (персистентный, пока активен)
    if Heist.EventEndsAt > 0 and CurTime() < Heist.EventEndsAt then
        local left = math.max(0, math.floor(Heist.EventEndsAt - CurTime()))
        local mm, ss = math.floor(left / 60), left % 60
        local txt = ("ОГРАБЛЕНИЕ  •  %02d:%02d"):format(mm, ss)
        draw.RoundedBox(6, ScrW()/2 - 130, 8, 260, 34, Color(20, 10, 10, 210))
        draw.SimpleText(txt, "GRMHeist_Timer", ScrW()/2, 25, Color(255, 150, 90), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
end)
