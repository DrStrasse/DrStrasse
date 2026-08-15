-- Стенд модуля фоторобота GRM.Photorobot (cl_grm_photorobot.lua):
-- свой формат GRMFACE (сериализация/разбор/контрольная сумма), правила отрисовки
-- (слои, роли палитры, детерминированный рендер), захват RT и контракты
-- интеграции с OS + сервером (op photorobot_save).
local function read(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end
local photo = read("lua/autorun/client/cl_grm_photorobot.lua")
local core = read("lua/autorun/sh_grm_electronics.lua")
local client = read("lua/autorun/client/cl_grm_electronics.lua")
local pass, fail = 0, 0
local function has(s, n) return s:find(n, 1, true) ~= nil end
local function ok(v, n) if v then pass = pass + 1; print("  ok  " .. n) else fail = fail + 1; print("  FAIL " .. n) end end

-- ── Контракты (строки) ─────────────────────────────────────────────────
ok(has(photo, "GRM.Photorobot") and has(photo, 'PR.FormatMagic = "GRMFACE"') and has(photo, "PR.FormatVersion = 1"), "module declares own versioned GRMFACE format")
ok(has(photo, "function PR.Serialize") and has(photo, "function PR.Deserialize") and has(photo, "function PR.Checksum"), "format round-trip + checksum API")
ok(has(photo, "function PR.Render") and has(photo, "function PR.Capture") and has(photo, "function PR.Normalize"), "renderer / RT capture / normalize API")
ok(has(photo, "PR.Parts") and has(photo, "PR.SlotOrder") and has(photo, "PR.SlotLabels"), "data-driven layered part library with slot order")
ok(has(photo, "face = {") and has(photo, "eyes = {") and has(photo, "nose = {") and has(photo, "hair = {") and has(photo, "extras = {"), "face/eyes/nose/hair/extras part sets present")
ok(has(photo, "PR.SkinTones") and has(photo, "PR.HairColors") and has(photo, "PR.EyeColors"), "skin/hair/eye palettes")
ok(has(photo, "sepia") and has(photo, "vintage") and has(photo, "grain") and has(photo, "highcontrast"), "effects: sepia vintage grain highcontrast")
ok(has(photo, "PR.Seed") and has(photo, "PR.Rng"), "deterministic noise (same face prints identically)")
ok(has(photo, "render.Capture") and has(photo, "render.PushRenderTarget") and has(photo, "GetRenderTarget"), "RT capture present (capture before PopRenderTarget)")
ok(has(photo, "Подозр. 1") and has(photo, "presets"), "preset suspect templates")
ok(has(client, "GRM.Photorobot") and has(client, "photoPage") and has(client, "photoCtx"), "OS delegates photorobot app to the module via context")
ok(has(core, 'op=="photorobot_save"') and has(core, 'category="photorobot"') and has(core, 'grm=grm') and has(core, 'desc=desc'), "server stores photorobot with GRMF data (grm/desc/category)")
ok(has(core, "grm=f.grm") and has(core, "desc=f.desc") and has(core, "imagePath=f.imagePath"), "files list/open expose GRMF for re-edit")
ok(has(core, 'AddCSLuaFile("autorun/client/cl_grm_photorobot.lua")'), "photorobot module shipped to clients")

-- ── Рантайм движка (мок GMod client API) ───────────────────────────────
CLIENT, SERVER = true, false
math.Clamp = function(v, a, b) return math.max(a, math.min(b, v)) end
Color = function(r, g, b, a) return { r = r or 255, g = g or 255, b = b or 255, a = a or 255 } end
local ops = 0
draw = { RoundedBox = function() ops = ops + 1 end, SimpleText = function() end, NoTexture = function() end }
surface = { SetDrawColor = function() end, DrawRect = function() ops = ops + 1 end, DrawLine = function() end, SetDrawLineWidth = function() end, DrawPoly = function() end, DrawTexturedRect = function() end, DrawOutlinedRect = function() end, SetMaterial = function() end }
vgui = {}
GetRenderTarget = function(n, w, h) return { n = n, w = w, h = h } end
render = { PushRenderTarget = function() end, PopRenderTarget = function() end, Clear = function() end, Capture = function(o) return "JPEG:" .. o.w .. "x" .. o.h end }
cam = { Start2D = function() end, End2D = function() end }
local chunk, err = loadfile("lua/autorun/client/cl_grm_photorobot.lua")
ok(chunk ~= nil, "module parses: " .. tostring(err))
if not chunk then os.exit(1) end
local ran, rerr = pcall(chunk)
ok(ran, "module executes: " .. tostring(rerr))
local PR = GRM and GRM.Photorobot
ok(PR ~= nil, "GRM.Photorobot exposed")

local st = PR.NewState()
st.face, st.hair, st.eyes, st.skin, st.effect = 4, 6, 3, 5, 3
local txt = PR.Serialize(st, { name = "Тест/Шапка", desc = "особые=приметы\nстрока2", author = "petrov" })
ok(txt:match("^GRMFACE/1\n") ~= nil, "GRMFACE magic + version header")
ok(txt:match("\nsig=[0-9a-f]+$") ~= nil, "checksum present")
local st2, meta = PR.Deserialize(txt)
ok(st2 ~= nil, "deserialize ok")
ok(st2 and st2.face == 4 and st2.hair == 6 and st2.eyes == 3 and st2.skin == 5 and st2.effect == 3, "state round-trips")
ok(meta and meta.name == "Тест/Шапка" and meta.desc == "особые=приметы\nстрока2" and meta.author == "petrov", "meta round-trips (escapes)")

local bad = txt:gsub("face=4", "face=5", 1)
local bs, be = PR.Deserialize(bad)
ok(bs == nil and be ~= nil, "tampered checksum rejected: " .. tostring(be))
local _, ve = PR.Deserialize("HELLO/9\nface=1\nsig=00000000")
ok(ve ~= nil, "bad magic rejected")
local _, nv = PR.Deserialize("GRMFACE/2\nface=1\nsig=00000000")
ok(nv ~= nil, "unsupported version rejected")
ok(PR.Deserialize("") == nil and PR.Deserialize("garbage") == nil, "empty/garbage rejected")

local ns = PR.Normalize({ face = 999, hair = 0, skin = 99, effect = -5 })
ok(ns.face == #PR.Parts.face and ns.hair == 1 and ns.skin == #PR.SkinTones and ns.effect == 1, "Normalize clamps indices")

local allok = true
for _, slot in ipairs(PR.SlotOrder) do
  local set = PR.Parts[slot]
  if #set < 1 then allok = false end
  for _, p in ipairs(set) do
    for _, L in ipairs(p.layers or {}) do
      if L.type ~= "roundrect" and L.type ~= "rect" and L.type ~= "line" and L.type ~= "circle" and L.type ~= "poly" then allok = false end
    end
  end
end
ok(allok, "part library valid (slots >=1 part, prim types valid)")

local need = { "skin", "skinShade", "skinDark", "skinLight", "hair", "hairShade", "eye", "eyeWhite", "pupil", "brow", "lip", "lipDark", "mouth", "scar", "mole", "beard", "stubble", "glasses", "jewelry" }
local pal = PR.Palette(st2)
local allroles = true
for _, k in ipairs(need) do if not pal[k] then allroles = false end end
ok(allroles, "palette resolves all roles")

ops = 0
PR.Render(st2, 400, 520)
local c1 = ops
ops = 0
PR.Render(st2, 400, 520)
local c2 = ops
ok(c1 > 20, "render draws primitives (" .. c1 .. ")")
ok(c1 == c2, "render deterministic (same prim count)")

local cap = PR.Capture(st2, 400, 520, 82)
ok(cap == "JPEG:400x520", "capture uses RT and returns JPEG bytes")

print(("PHOTOROBOT: %d/%d failures=%d"):format(pass, pass + fail, fail))
if fail > 0 then os.exit(1) end
