--[[
  GRM Photorobot v2.0.0 — модуль поддержки фотографий.
  Полная переработка фоторобота Кода 59: вынесен из cl_grm_electronics.lua
  в отдельный модуль со СВОИМИ правилами отрисовки (слои, роли палитры,
  примитивы) и СВОИМ форматом файла (GRMFACE) вместо «сырого» JPEG.

  Что здесь:
    * PR.Parts        — библиотека частей лица (данные, а не клоузы draw-кода)
    * PR.Palette      — палитра ролей (skin/hair/eye/...) с производными цветами
    * PR.Render       — рендерер: слои → 2D, детерминированный шум, эффекты, рамка
    * PR.Capture      — off-screen RT → JPEG (захват ДО PopRenderTarget — баг v1)
    * PR.Serialize / Deserialize — формат GRMFACE/1 с контрольной суммой FNV-1a
    * PR.Gallery / Editor / Viewer — UI, принимающий контекст от OS (cl_grm_electronics)
  Формат GRMFACE: текстовый, версионированный, самопроверяемый. Позволяет
  переоткрыть/доредактировать фоторобот и перепечатать его 1:1.
]]
if not CLIENT then return end

GRM = GRM or {}
GRM.Photorobot = GRM.Photorobot or {}
local PR = GRM.Photorobot
PR.Version = "2.0.0"

local ColorCtor = Color or function(r, g, b, a)
  return { r = r or 255, g = g or 255, b = b or 255, a = a or 255 }
end
local clamp = function(v, a, b) if v < a then return a elseif v > b then return b else return v end end
local iClamp = function(v, a, b) v = tonumber(v) or a; return math.floor(clamp(math.floor(v), a, b)) end

-- ── Дизайн-пространство ────────────────────────────────────────────────
PR.DesignW, PR.DesignH = 200, 260          -- «холст» фоторобота в условных единицах
PR.CenterX, PR.CenterY = 100, 115          -- центр головы в этом пространстве

-- ── Палитра (роли) ──────────────────────────────────────────────────────
PR.SkinTones = {
  { name = "Светлая",        c = { r = 245, g = 215, b = 190 } },
  { name = "Европейская",    c = { r = 230, g = 195, b = 165 } },
  { name = "Загорелая",      c = { r = 210, g = 175, b = 140 } },
  { name = "Смуглая",        c = { r = 185, g = 150, b = 115 } },
  { name = "Тёмная",         c = { r = 155, g = 120, b = 85 } },
  { name = "Карибская",      c = { r = 120, g = 85, b = 60 } },
  { name = "Тёмно-коричневая", c = { r = 85, g = 60, b = 40 } },
}
PR.HairColors = {
  { name = "Каштановый", c = { r = 60, g = 40, b = 25 } },
  { name = "Чёрный",     c = { r = 40, g = 25, b = 15 } },
  { name = "Русый",      c = { r = 160, g = 130, b = 60 } },
  { name = "Рыжий",      c = { r = 190, g = 80, b = 25 } },
  { name = "Седой",      c = { r = 140, g = 140, b = 140 } },
  { name = "Иссиня-чёрный", c = { r = 25, g = 25, b = 25 } },
  { name = "Каштаново-красный", c = { r = 180, g = 50, b = 30 } },
}
PR.EyeColors = {
  { name = "Голубые",  c = { r = 60, g = 90, b = 140 } },
  { name = "Зелёные",  c = { r = 50, g = 120, b = 60 } },
  { name = "Карие",    c = { r = 120, g = 80, b = 40 } },
  { name = "Тёмные",   c = { r = 40, g = 40, b = 40 } },
  { name = "Серо-голубые", c = { r = 80, g = 130, b = 150 } },
}
PR.Effects = { "normal", "bw", "sepia", "vintage", "grain", "highcontrast" }
PR.EffectNames = { "Обычный", "Ч/Б", "Сепия", "Винтаж", "Зерно", "Контраст" }

local function shade(c, n) return { r = clamp(c.r + n, 0, 255), g = clamp(c.g + n, 0, 255), b = clamp(c.b + n, 0, 255), a = c.a or 255 } end
local function tint(c, n)  return { r = clamp(c.r + n, 0, 255), g = clamp(c.g + n, 0, 255), b = clamp(c.b + n, 0, 255), a = c.a or 255 } end

-- Разрешение роли в конкретный цвет для заданного состояния.
function PR.Palette(state)
  local skin = (PR.SkinTones[state.skin] and PR.SkinTones[state.skin].c) or PR.SkinTones[2].c
  local hair = (PR.HairColors[state.haircol] and PR.HairColors[state.haircol].c) or PR.HairColors[1].c
  local eye  = (PR.EyeColors[state.eyecol] and PR.EyeColors[state.eyecol].c) or PR.EyeColors[1].c
  return {
    skin      = skin,
    skinShade = shade(skin, -22),
    skinDark  = shade(skin, -44),
    skinLight = tint(skin, 18),
    hair      = hair,
    hairShade = shade(hair, -32),
    eye       = eye,
    eyeWhite  = { r = 255, g = 255, b = 255, a = 255 },
    pupil     = { r = 18, g = 18, b = 18, a = 255 },
    brow      = shade(hair, -12),
    lip       = { r = 185, g = 75, b = 75, a = 255 },
    lipDark   = { r = 140, g = 50, b = 50, a = 255 },
    mouth     = { r = 40, g = 20, b = 20, a = 255 },
    scar      = { r = 180, g = 80, b = 80, a = 255 },
    mole      = { r = 60, g = 40, b = 30, a = 255 },
    beard     = { r = 70, g = 50, b = 35, a = 200 },
    stubble   = { r = 80, g = 60, b = 40, a = 150 },
    glasses   = { r = 40, g = 40, b = 50, a = 255 },
    jewelry   = { r = 200, g = 180, b = 50, a = 255 },
    outline   = { r = 90, g = 60, b = 45, a = 90 },
  }
end

-- ── Библиотека частей лица (правила отрисовки) ──────────────────────────
-- Каждая часть — слои примитивов. Координаты ОТНОСИТЕЛЬНО центра головы
-- (0,0 = центр). type: roundrect | rect | line | circle | poly.
-- role — имя слота палитры; fixed — явный цвет {r,g,b,a}.
local function line(x1, y1, x2, y2, role, width)
  return { type = "line", x1 = x1, y1 = y1, x2 = x2, y2 = y2, role = role, width = width or 2 }
end

-- Дуга брови, аппроксимированная сегментами (детерминированно, без math.random).
local function arcLayers(x0, x1, y, arc, role, segs, width)
  segs = segs or 6
  local out = {}
  for i = 0, segs - 1 do
    local t0, t1 = i / segs, (i + 1) / segs
    out[#out + 1] = line(x0 + (x1 - x0) * t0, y - arc * math.sin(math.pi * t0),
                         x0 + (x1 - x0) * t1, y - arc * math.sin(math.pi * t1), role, width)
  end
  return out
end

PR.Parts = {
  face = {
    { id = "oval",  name = "Овальное",   layers = { { type = "roundrect", x = -55, y = -70, w = 110, h = 150, rx = 90, role = "skin" }, { type = "roundrect", x = -34, y = 42, w = 68, h = 34, rx = 34, role = "skinShade", alpha = 46 } } },
    { id = "square",name = "Квадратное", layers = { { type = "roundrect", x = -58, y = -68, w = 116, h = 148, rx = 20, role = "skin" } } },
    { id = "round", name = "Круглое",    layers = { { type = "roundrect", x = -60, y = -60, w = 120, h = 130, rx = 75, role = "skin" } } },
    { id = "long",  name = "Длинное",    layers = { { type = "roundrect", x = -48, y = -75, w = 96, h = 160, rx = 55, role = "skin" } } },
    { id = "thin",  name = "Худое",      layers = { { type = "roundrect", x = -42, y = -68, w = 84, h = 146, rx = 45, role = "skin" } } },
    { id = "wide",  name = "Широкое",    layers = { { type = "roundrect", x = -65, y = -60, w = 130, h = 135, rx = 60, role = "skin" } } },
  },
  chin = {
    { id = "none",    name = "Обычный",  layers = {} },
    { id = "strong",  name = "Волевой",  layers = { { type = "roundrect", x = -40, y = 55, w = 80, h = 20, rx = 4, role = "skinShade" } } },
    { id = "double",  name = "Двойной",  layers = { { type = "roundrect", x = -35, y = 60, w = 70, h = 25, rx = 30, role = "skinShade" } } },
    { id = "pointy",  name = "Острый",   layers = { { type = "roundrect", x = -8, y = 65, w = 16, h = 15, rx = 4, role = "skinShade" } } },
  },
  eyes = {
    { id = "normal", name = "Обычные", layers = {
      { type = "roundrect", x = -35, y = -20, w = 28, h = 16, rx = 10, role = "eyeWhite" },
      { type = "roundrect", x = 7, y = -20, w = 28, h = 16, rx = 10, role = "eyeWhite" },
      { type = "circle", x = -21, y = -12, r = 5, role = "eye" },
      { type = "circle", x = 21, y = -12, r = 5, role = "eye" },
      { type = "circle", x = -19, y = -14, r = 2.4, role = "pupil" },
      { type = "circle", x = 23, y = -14, r = 2.4, role = "pupil" },
      { type = "circle", x = -22.5, y = -15, r = 1.1, fixed = { r = 255, g = 255, b = 255, a = 210 } },
      { type = "circle", x = 21.5, y = -15, r = 1.1, fixed = { r = 255, g = 255, b = 255, a = 210 } },
    } },
    { id = "narrow", name = "Узкие", layers = {
      { type = "roundrect", x = -35, y = -16, w = 30, h = 10, rx = 6, role = "eyeWhite" },
      { type = "roundrect", x = 5, y = -16, w = 30, h = 10, rx = 6, role = "eyeWhite" },
      { type = "circle", x = -20, y = -11, r = 4, role = "eye" },
      { type = "circle", x = 20, y = -11, r = 4, role = "eye" },
      { type = "circle", x = -19, y = -11, r = 1.9, role = "pupil" },
      { type = "circle", x = 21, y = -11, r = 1.9, role = "pupil" },
    } },
    { id = "big", name = "Большие", layers = {
      { type = "roundrect", x = -38, y = -24, w = 34, h = 24, rx = 14, role = "eyeWhite" },
      { type = "roundrect", x = 4, y = -24, w = 34, h = 24, rx = 14, role = "eyeWhite" },
      { type = "circle", x = -22, y = -12, r = 7, role = "eye" },
      { type = "circle", x = 22, y = -12, r = 7, role = "eye" },
      { type = "circle", x = -20, y = -14, r = 3.2, role = "pupil" },
      { type = "circle", x = 24, y = -14, r = 3.2, role = "pupil" },
      { type = "circle", x = -23.5, y = -15.5, r = 1.4, fixed = { r = 255, g = 255, b = 255, a = 220 } },
      { type = "circle", x = 22.5, y = -15.5, r = 1.4, fixed = { r = 255, g = 255, b = 255, a = 220 } },
    } },
    { id = "sad", name = "Грустные", layers = {
      { type = "roundrect", x = -35, y = -18, w = 28, h = 14, rx = 10, role = "eyeWhite" },
      { type = "roundrect", x = 7, y = -18, w = 28, h = 14, rx = 10, role = "eyeWhite" },
      line(-36, -22, -8, -16, "brow"), line(8, -16, 36, -22, "brow"),
      { type = "circle", x = -21, y = -11, r = 4.5, role = "eye" },
      { type = "circle", x = 21, y = -11, r = 4.5, role = "eye" },
      { type = "circle", x = -20, y = -11, r = 2.1, role = "pupil" },
      { type = "circle", x = 22, y = -11, r = 2.1, role = "pupil" },
    } },
    { id = "angry", name = "Злые", layers = {
      { type = "roundrect", x = -34, y = -18, w = 28, h = 14, rx = 8, role = "eyeWhite" },
      { type = "roundrect", x = 6, y = -18, w = 28, h = 14, rx = 8, role = "eyeWhite" },
      line(-36, -14, -8, -22, "brow"), line(8, -22, 36, -14, "brow"),
      { type = "circle", x = -20, y = -11, r = 4.4, fixed = { r = 180, g = 60, b = 55, a = 255 } },
      { type = "circle", x = 20, y = -11, r = 4.4, fixed = { r = 180, g = 60, b = 55, a = 255 } },
      { type = "circle", x = -19, y = -11, r = 2, role = "pupil" },
      { type = "circle", x = 21, y = -11, r = 2, role = "pupil" },
    } },
    { id = "small", name = "Маленькие", layers = {
      { type = "roundrect", x = -30, y = -16, w = 18, h = 10, rx = 6, role = "eyeWhite" },
      { type = "roundrect", x = 12, y = -16, w = 18, h = 10, rx = 6, role = "eyeWhite" },
      { type = "circle", x = -21, y = -11, r = 3.6, role = "eye" },
      { type = "circle", x = 21, y = -11, r = 3.6, role = "eye" },
      { type = "circle", x = -20.5, y = -11, r = 1.7, role = "pupil" },
      { type = "circle", x = 21.5, y = -11, r = 1.7, role = "pupil" },
    } },
  },
  brows = {
    { id = "normal", name = "Обычные", layers = { line(-38, -30, -8, -32, "brow"), line(8, -32, 38, -30, "brow") } },
    { id = "thick",  name = "Густые",  layers = { { type = "roundrect", x = -40, y = -34, w = 34, h = 8, rx = 3, role = "brow" }, { type = "roundrect", x = 6, y = -34, w = 34, h = 8, rx = 3, role = "brow" } } },
    { id = "thin",   name = "Тонкие",  layers = { line(-36, -30, -8, -31, "brow", 1), line(8, -31, 36, -30, "brow", 1) } },
    { id = "angry",  name = "Злые",    layers = { line(-38, -26, -8, -34, "brow", 2), line(8, -34, 38, -26, "brow", 2) } },
    { id = "arched", name = "Дугой",   layers = (function() local l = arcLayers(-38, -8, -32, 6, "brow", 6); for _, v in ipairs(arcLayers(8, 38, -32, 6, "brow", 6)) do l[#l + 1] = v end; return l end)() },
  },
  nose = {
    { id = "straight", name = "Прямой",    layers = { line(0, -8, -6, 18, "skinDark", 1.5), line(-6, 18, 6, 18, "skinDark", 1.5), line(6, 18, 0, -8, "skinDark", 1.5) } },
    { id = "wide",     name = "Широкий",   layers = { { type = "roundrect", x = -12, y = -4, w = 24, h = 24, rx = 6, role = "skinShade" } } },
    { id = "long",     name = "Длинный",   layers = { { type = "poly", pts = { { x = 0, y = -12 }, { x = -8, y = 24 }, { x = 8, y = 24 } }, role = "skinDark" } } },
    { id = "button",   name = "Кнопкой",   layers = { { type = "roundrect", x = -8, y = 4, w = 16, h = 14, rx = 8, role = "skinShade" } } },
    { id = "bump",     name = "Горбинкой", layers = { { type = "poly", pts = { { x = 0, y = -10 }, { x = 6, y = 4 }, { x = -4, y = 20 }, { x = 6, y = 20 } }, role = "skinDark" } } },
  },
  mouth = {
    { id = "straight", name = "Прямой",   layers = { line(-20, 35, 20, 35, "lipDark") } },
    { id = "smile",    name = "Улыбка",   layers = { { type = "roundrect", x = -18, y = 28, w = 36, h = 14, rx = 12, role = "lipDark" }, line(-16, 35, 16, 35, "lip", 1) } },
    { id = "open",     name = "Открытый", layers = { { type = "roundrect", x = -14, y = 30, w = 28, h = 16, rx = 10, role = "mouth" }, { type = "poly", pts = { { x = -12, y = 36 }, { x = -6, y = 41 }, { x = 6, y = 41 }, { x = 12, y = 36 }, { x = 6, y = 33 }, { x = -6, y = 33 } }, role = "mouth" } } },
    { id = "thin",     name = "Тонкий",   layers = { line(-16, 35, 16, 35, "lipDark", 1) } },
    { id = "full",     name = "Полный",   layers = { { type = "roundrect", x = -16, y = 30, w = 32, h = 12, rx = 8, role = "lip" } } },
    { id = "crooked",  name = "Кривой",   layers = { line(-18, 33, 0, 36, "lipDark"), line(0, 36, 18, 32, "lipDark") } },
  },
  hair = {
    { id = "short", name = "Короткая", layers = {
      { type = "roundrect", x = -58, y = -78, w = 116, h = 50, rx = 40, role = "hair" },
      { type = "roundrect", x = -60, y = -55, w = 10, h = 30, rx = 4, role = "hair" },
      { type = "roundrect", x = 50, y = -55, w = 10, h = 30, rx = 4, role = "hair" },
    } },
    { id = "swept", name = "Зачёс назад", layers = (function()
      local l = { { type = "roundrect", x = -55, y = -80, w = 110, h = 35, rx = 30, role = "hair" } }
      for i = 0, 6 do l[#l + 1] = line(-50 + i * 16, -82, -48 + i * 16, -50, "hairShade", 2) end
      return l
    end)() },
    { id = "long", name = "Длинная", layers = {
      { type = "roundrect", x = -62, y = -78, w = 124, h = 130, rx = 10, role = "hair" },
      { type = "roundrect", x = -50, y = -60, w = 100, h = 110, rx = 80, role = "skin" },
    } },
    { id = "bald", name = "Лысый", layers = {} },
    { id = "buzz", name = "Ёжик", layers = (function()
      local l = {}
      for i = 0, 8 do l[#l + 1] = { type = "roundrect", x = -48 + i * 12, y = -80, w = 6, h = 18, rx = 2, role = "hair" } end
      return l
    end)() },
    { id = "curls", name = "Кудри", layers = (function()
      local l = {}
      for i = 0, 7 do for j = 0, 2 do l[#l + 1] = { type = "circle", x = -52 + i * 15, y = -82 + j * 12, r = 7, role = "hair" } end end
      return l
    end)() },
    { id = "part", name = "Пробор", layers = {
      { type = "roundrect", x = -58, y = -76, w = 54, h = 45, rx = 6, role = "hair" },
      { type = "roundrect", x = 4, y = -76, w = 54, h = 45, rx = 6, role = "hair" },
    } },
    { id = "tail", name = "Хвост", layers = {
      { type = "roundrect", x = -55, y = -76, w = 110, h = 35, rx = 35, role = "hair" },
      { type = "roundrect", x = 40, y = -60, w = 16, h = 60, rx = 8, role = "hair" },
    } },
  },
  extras = {
    { id = "none",   name = "Нет",       layers = {} },
    { id = "scar",   name = "Шрам",      layers = { line(-25, -10, 15, 30, "scar"), line(-23, -10, 17, 30, "scar") } },
    { id = "mole",   name = "Родинка",   layers = { { type = "circle", x = 22, y = 5, r = 3, role = "mole" } } },
    { id = "beard",  name = "Борода",    layers = { { type = "roundrect", x = -38, y = 25, w = 76, h = 50, rx = 20, role = "beard" } } },
    { id = "stubble", name = "Щетина",   layers = (function()
      local l = {}
      for i = 0, 12 do for j = 0, 4 do l[#l + 1] = { type = "rect", x = -35 + i * 6, y = 28 + j * 6, w = 2, h = 2, role = "stubble" } end end
      return l
    end)() },
    { id = "glasses", name = "Очки",     layers = {
      line(-40, -16, -6, -16, "glasses", 1.5), line(6, -16, 40, -16, "glasses", 1.5),
      line(-40, -24, -40, -8, "glasses", 1.5), line(-6, -24, -6, -8, "glasses", 1.5),
      line(6, -24, 6, -8, "glasses", 1.5), line(40, -24, 40, -8, "glasses", 1.5),
      line(-40, -20, -50, -24, "glasses", 1.5), line(40, -20, 50, -24, "glasses", 1.5),
    } },
    { id = "mustache", name = "Усы",     layers = { { type = "roundrect", x = -20, y = 22, w = 40, h = 8, rx = 4, role = "beard" } } },
    { id = "earring", name = "Серёжка",  layers = { { type = "circle", x = -55, y = -5, r = 3, role = "jewelry" } } },
  },
}

-- Порядок отрисовки слотов (от заднего к переднему).
PR.SlotOrder = { "face", "chin", "eyes", "brows", "nose", "mouth", "hair", "extras" }
PR.SlotLabels = {
  face = "Лицо", chin = "Подбородок", eyes = "Глаза", brows = "Брови",
  nose = "Нос", mouth = "Рот", hair = "Причёска", extras = "Приметы",
}

-- ── Состояние ───────────────────────────────────────────────────────────
function PR.NewState()
  return { face = 1, chin = 1, eyes = 1, brows = 1, nose = 1, mouth = 1, hair = 1, extras = 1, skin = 2, haircol = 1, eyecol = 1, effect = 1 }
end

-- Приводит любые (в т.ч. битые/старые) значения к валидным индексам.
function PR.Normalize(state)
  state = state or {}
  local o = {}
  for _, k in ipairs(PR.SlotOrder) do o[k] = iClamp(state[k], 1, #PR.Parts[k]) end
  o.skin = iClamp(state.skin, 1, #PR.SkinTones)
  o.haircol = iClamp(state.haircol, 1, #PR.HairColors)
  o.eyecol = iClamp(state.eyecol, 1, #PR.EyeColors)
  o.effect = iClamp(state.effect, 1, #PR.Effects)
  return o
end

-- ── Формат GRMFACE ──────────────────────────────────────────────────────
PR.FormatMagic = "GRMFACE"
PR.FormatVersion = 1

local bitlib = bit
local function bxor32(a, b)
  if bitlib and bitlib.bxor then return bitlib.bxor(a, b) end
  local r, p = 0, 1
  for _ = 0, 31 do
    if (a % 2) ~= (b % 2) then r = r + p end
    a = math.floor(a / 2); b = math.floor(b / 2); p = p * 2
  end
  return r
end

-- FNV-1a 32 бита (детерминированная, без util.CRC — работает и вне игры).
function PR.Checksum(s)
  local h = 2166136261
  for i = 1, #s do
    h = bxor32(h, s:byte(i))
    h = (h * 16777619) % 4294967296
  end
  return h
end

local HEXC = "0123456789abcdef"
local function tohex(n)
  local s = ""
  for _ = 1, 8 do s = HEXC:sub(n % 16 + 1, n % 16 + 1) .. s; n = math.floor(n / 16) end
  return s
end
local function fromhex(s)
  local n = 0
  for i = 1, #s do
    local d = tonumber(s:sub(i, i), 16)
    if not d then return nil end
    n = n * 16 + d
  end
  return n
end

local function encode(s)
  s = tostring(s or "")
  return s:gsub("%%", "%%25"):gsub("\r", "%%0D"):gsub("\n", "%%0A"):gsub("=", "%%3D")
end
local function decode(s)
  s = tostring(s or "")
  return (s:gsub("%%0D", "\r"):gsub("%%0A", "\n"):gsub("%%3D", "="):gsub("%%25", "%%"))
end

-- Сериализация состояния в самопроверяемый текст. meta = {name, desc, author}.
function PR.Serialize(state, meta)
  state = PR.Normalize(state)
  meta = meta or {}
  local lines = {
    PR.FormatMagic .. "/" .. PR.FormatVersion,
    "name=" .. encode(meta.name or ""),
    "desc=" .. encode(meta.desc or ""),
    "author=" .. encode(meta.author or ""),
  }
  for _, k in ipairs(PR.SlotOrder) do lines[#lines + 1] = k .. "=" .. state[k] end
  lines[#lines + 1] = "skin=" .. state.skin
  lines[#lines + 1] = "haircol=" .. state.haircol
  lines[#lines + 1] = "eyecol=" .. state.eyecol
  lines[#lines + 1] = "effect=" .. state.effect
  local body = table.concat(lines, "\n")
  return body .. "\nsig=" .. tohex(PR.Checksum(body))
end

-- Разбор GRMFACE-текста. Возвращает state, meta или nil, ошибка.
function PR.Deserialize(text)
  if type(text) ~= "string" or text == "" then return nil, "пустой документ" end
  local lines = {}
  for ln in text:gmatch("[^\r\n]+") do lines[#lines + 1] = ln end
  if #lines < 2 then return nil, "слишком короткий документ" end
  local magic, ver = lines[1]:match("^(%a+)/(%d+)$")
  if magic ~= PR.FormatMagic then return nil, "не GRMFACE" end
  if tonumber(ver) ~= PR.FormatVersion then return nil, "неподдерживаемая версия " .. tostring(ver) end

  local last = lines[#lines]
  local sigline = last:match("^sig=([0-9a-fA-F]+)$")
  if not sigline then return nil, "нет контрольной суммы" end
  local want = fromhex(sigline)
  if not want then return nil, "битая контрольная сумма" end

  local body = table.concat(lines, "\n", 1, #lines - 1)
  if PR.Checksum(body) ~= want then return nil, "контрольная сумма не совпала (документ повреждён)" end

  local f = {}
  for i = 2, #lines - 1 do
    local k, v = lines[i]:match("^([%w_]+)=(.*)$")
    if k then f[k] = v end
  end
  local state = PR.Normalize({
    face = tonumber(f.face), chin = tonumber(f.chin), eyes = tonumber(f.eyes),
    brows = tonumber(f.brows), nose = tonumber(f.nose), mouth = tonumber(f.mouth),
    hair = tonumber(f.hair), extras = tonumber(f.extras),
    skin = tonumber(f.skin), haircol = tonumber(f.haircol), eyecol = tonumber(f.eyecol),
    effect = tonumber(f.effect),
  })
  local meta = { name = decode(f.name or ""), desc = decode(f.desc or ""), author = decode(f.author or "") }
  return state, meta
end

-- ── Детерминированный шум (одно и то же лицо печатается одинаково) ──────
function PR.Seed(state)
  local n = state.face
  for _, k in ipairs({ "hair", "eyes", "brows", "nose", "mouth", "chin", "extras" }) do n = (n * 31 + state[k]) % 2147483647 end
  n = (n * 31 + state.skin * 7 + state.haircol * 11 + state.eyecol * 13 + state.effect * 17) % 2147483647
  return n
end

function PR.Rng(seed)
  local s = ((seed or 1) % 2147483647) + 1
  return function()
    s = (s * 48271) % 2147483647
    return s / 2147483647
  end
end

-- ── Рендерер ────────────────────────────────────────────────────────────
local function circle(x, y, r, c, a, segs)
  segs = segs or 26
  surface.SetDrawColor(c.r, c.g, c.b, a)
  draw.NoTexture()
  local pts = {}
  for i = 0, segs do
    local ang = i / segs * math.pi * 2
    pts[#pts + 1] = { x = x + math.cos(ang) * r, y = y + math.sin(ang) * r }
  end
  surface.DrawPoly(pts)
end

-- Рисует фоторобот на текущей 2D-поверхности. opts.caption / opts.sub.
function PR.Render(state, w, h, opts)
  state = PR.Normalize(state)
  opts = opts or {}
  local scale = math.min(w / PR.DesignW, h / PR.DesignH)
  local ox = (w - PR.DesignW * scale) / 2
  local oy = (h - PR.DesignH * scale) / 2
  local X = function(x) return ox + (PR.CenterX + x) * scale end
  local Y = function(y) return oy + (PR.CenterY + y) * scale end
  local S = function(v) return v * scale end

  local pal = PR.Palette(state)
  local rng = PR.Rng(PR.Seed(state))

  local function drawLayer(L)
    local c = L.fixed or pal[L.role] or { r = 0, g = 0, b = 0, a = 255 }
    local a = (L.alpha ~= nil) and L.alpha or (c.a or 255)
    local t = L.type
    if t == "roundrect" then
      draw.RoundedBox(S(L.rx or 0), X(L.x), Y(L.y), S(L.w), S(L.h), ColorCtor(c.r, c.g, c.b, a))
    elseif t == "rect" then
      surface.SetDrawColor(c.r, c.g, c.b, a)
      surface.DrawRect(X(L.x), Y(L.y), S(L.w), S(L.h))
    elseif t == "line" then
      surface.SetDrawColor(c.r, c.g, c.b, a)
      surface.SetDrawLineWidth(S(L.width or 1))
      surface.DrawLine(X(L.x1), Y(L.y1), X(L.x2), Y(L.y2))
      surface.SetDrawLineWidth(1)
    elseif t == "circle" then
      circle(X(L.x), Y(L.y), S(L.r), c, a)
    elseif t == "poly" then
      local pts = {}
      for _, p in ipairs(L.pts) do pts[#pts + 1] = { x = X(p.x), y = Y(p.y) } end
      surface.SetDrawColor(c.r, c.g, c.b, a)
      draw.NoTexture()
      surface.DrawPoly(pts)
    end
  end

  -- Бумага + зерно (детерминированное).
  draw.RoundedBox(6, 0, 0, w, h, ColorCtor(235, 225, 210, 255))
  for _ = 1, 40 do draw.RoundedBox(1, rng() * w, rng() * h, 1 + rng() * 3, 1 + rng() * 2, ColorCtor(200, 190, 175, 40)) end

  -- Уши и шея (не выбираются — всегда от тона кожи).
  draw.RoundedBox(S(12), X(-68), Y(-15), S(14), S(30), ColorCtor(pal.skin.r, pal.skin.g, pal.skin.b, 255))
  draw.RoundedBox(S(12), X(54), Y(-15), S(14), S(30), ColorCtor(pal.skin.r, pal.skin.g, pal.skin.b, 255))
  draw.RoundedBox(S(4), X(-18), Y(70), S(36), S(40), ColorCtor(pal.skin.r, pal.skin.g, pal.skin.b, 255))

  -- Слоты по порядку.
  for _, slot in ipairs(PR.SlotOrder) do
    local part = PR.Parts[slot][state[slot]] or PR.Parts[slot][1]
    for _, L in ipairs(part.layers or {}) do drawLayer(L) end
  end

  -- Эффект.
  local eff = PR.Effects[state.effect] or "normal"
  if eff == "bw" then
    draw.RoundedBox(0, 0, 0, w, h, ColorCtor(0, 0, 0, 120)); draw.RoundedBox(0, 0, 0, w, h, ColorCtor(255, 255, 255, 40))
  elseif eff == "sepia" then
    draw.RoundedBox(0, 0, 0, w, h, ColorCtor(112, 66, 20, 70))
  elseif eff == "vintage" then
    draw.RoundedBox(0, 0, 0, w, h, ColorCtor(90, 60, 30, 80))
    for _ = 1, 20 do surface.SetDrawColor(0, 0, 0, 10 + math.floor(rng() * 20)); surface.DrawLine(rng() * w, 0, rng() * w, h) end
  elseif eff == "grain" then
    for _ = 1, 200 do draw.RoundedBox(1, rng() * w, rng() * h, 1, 1, ColorCtor(0, 0, 0, 20 + math.floor(rng() * 40))) end
  elseif eff == "highcontrast" then
    draw.RoundedBox(0, 0, 0, w, h, ColorCtor(0, 0, 0, 50))
  end

  -- Виньетка.
  for i = 1, 12 do
    local a = i * 6
    draw.RoundedBox(0, 0, 0, w, i, ColorCtor(0, 0, 0, a))
    draw.RoundedBox(0, 0, h - i, w, i, ColorCtor(0, 0, 0, a))
    draw.RoundedBox(0, 0, 0, i, h, ColorCtor(0, 0, 0, a))
    draw.RoundedBox(0, w - i, 0, i, h, ColorCtor(0, 0, 0, a))
  end

  -- Подпись/штамп.
  draw.RoundedBox(4, 0, h - 26, w, 26, ColorCtor(0, 0, 0, 100))
  draw.SimpleText(opts.caption or ("GRM ФОТОРОБОТ · " .. os.date("%d.%m.%Y %H:%M")), "GRMNet_Small", w / 2, h - 13, ColorCtor(220, 220, 220, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- Захват в JPEG через off-screen RT. Захват идёт ДО PopRenderTarget (в v1 был после).
function PR.Capture(state, w, h, quality)
  w = w or 400; h = h or 520; quality = quality or 82
  local rt = GetRenderTarget("GRM_PhotoRobot_RT", w, h)
  render.PushRenderTarget(rt)
  render.Clear(235, 225, 210, 255)
  cam.Start2D()
  PR.Render(state, w, h)
  cam.End2D()
  local data = render.Capture({ format = "jpeg", quality = quality, x = 0, y = 0, w = w, h = h })
  render.PopRenderTarget()
  return data
end

-- ── Интеграция с OS ─────────────────────────────────────────────────────
PR._active = false
PR._view = nil           -- "gallery" | "editor"
PR._ctx = nil
PR._pendingPrint = nil
PR._expectOpen = false

-- Контекст от cl_grm_electronics.lua:
--   body (DPanel), send(op, writer), ent, user(), files(), setFiles(f),
--   topology(), deviceID(), C (цвета), ui = {frame,btn,entry,textLabel,darkList,addLine}
function PR.Open(ctx)
  PR._ctx = ctx
  PR._active = true
  PR._pendingPrint = nil
  PR._expectOpen = false
  ctx.send("files")
  PR.Gallery(ctx)
end

function PR.Close()
  PR._active = false
  PR._view = nil
  PR._ctx = nil
  PR._pendingPrint = nil
  PR._expectOpen = false
end

-- Обработчик результата: перехватывает files/file, если фоторобот активен.
function PR.HandleResult(payload)
  if not PR._active then return false end
  if payload.files then
    if PR._ctx and PR._ctx.setFiles then PR._ctx.setFiles(payload.files) end
    if PR._pendingPrint then
      local newest = nil
      for _, r in ipairs(payload.files or {}) do
        if r.category == "photorobot" and (not newest or (r.updated or 0) > (newest.updated or 0)) then newest = r end
      end
      if newest and PR._ctx then
        local pp = PR._pendingPrint
        PR._ctx.send("print", function()
          net.WriteString(newest.id)
          net.WriteString(pp.printerID or "")
          net.WriteString(pp.paper or "A4")
          net.WriteString(pp.orient or "portrait")
          net.WriteUInt(pp.copies or 1, 4)
          net.WriteString(pp.quality or "normal")
        end)
      end
      PR._pendingPrint = nil
    end
    if PR._view == "gallery" then PR.Gallery(PR._ctx) end
    return true
  end
  if payload.file then
    if PR._expectOpen then
      PR._expectOpen = false
      PR.OpenFile(payload.file)
    end
    return true
  end
  return false
end

-- Открытие сохранённого фоторобота (GRMF) в редакторе.
function PR.OpenFile(file)
  local ctx = PR._ctx
  if not ctx then return end
  if not file or type(file.grm) ~= "string" or file.grm == "" then
    notification.AddLegacy("В этом файле нет данных фоторобота (GRMF)", NOTIFY_ERROR, 4)
    return
  end
  local state, meta = PR.Deserialize(file.grm)
  if not state then
    notification.AddLegacy("Фоторобот повреждён: " .. tostring(meta), NOTIFY_ERROR, 4)
    return
  end
  PR.Editor(ctx, { state = state, fileID = file.id, name = meta.name or file.name, desc = meta.desc or file.desc or "" })
end

-- ── Просмотр файла ──────────────────────────────────────────────────────
local function viewFrame(ctx, file, state)
  local C = ctx.C
  local f = ctx.ui.frame("ФОТОРОБОТ · " .. tostring(file.name or "Портрет"), 520, 700)
  local imgPanel = vgui.Create("DPanel", f)
  imgPanel:SetPos(20, 60)
  imgPanel:SetSize(480, 480)
  if state then
    imgPanel.Paint = function(_, w, h) PR.Render(state, w, h, { caption = "GRM ФОТОРОБОТ · " .. os.date("%d.%m.%Y") }) end
  else
    imgPanel.Paint = function(_, w, h)
      draw.RoundedBox(8, 0, 0, w, h, C.panel)
      draw.SimpleText("Нет изображения", "GRMNet_Head", w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    if file.imagePath and file.Exists ~= nil then
      -- изображение покажем через DImage Material (надёжнее file://)
      if file.Exists(file.imagePath, "DATA") then
        local img = vgui.Create("DImage", imgPanel)
        img:SetPos(20, 20); img:SetSize(440, 440)
        img:SetImage("../data/" .. file.imagePath)
      end
    end
  end
  local desc = vgui.Create("DLabel", f)
  desc:SetPos(20, 550); desc:SetSize(480, 90)
  desc:SetFont("GRMNet_Body"); desc:SetTextColor(C.text); desc:SetWrap(true)
  desc:SetText((file.desc and file.desc ~= "" and file.desc) or "Без описания")
  local owner = vgui.Create("DLabel", f)
  owner:SetPos(20, 650); owner:SetSize(480, 22)
  owner:SetFont("GRMNet_Small"); owner:SetTextColor(C.dim)
  owner:SetText("Автор: " .. tostring(file.owner or "—") .. " · " .. os.date("%d.%m.%Y", file.updated or os.time()))
  return f
end

-- ── Галерея ─────────────────────────────────────────────────────────────
function PR.Gallery(ctx)
  PR._view = "gallery"
  local C = ctx.C
  local body = ctx.body
  body:Clear()
  local ui = ctx.ui
  ui.textLabel(body, "ФОТОРОБОТ 2.0", 18, 10, 220, 28, "GRMNet_Title", C.text)
  ui.textLabel(body, "Галерея фотороботов и фотографий · формат GRMFACE", 18, 38, 560, 20, "GRMNet_Small", C.dim)

  local list = ui.darkList(body, 18, 70, 500, 440, { { "Название", 185 }, { "Дата", 80 }, { "КБ", 45 }, { "Тип", 85 }, { "Владелец", 85 } })

  local function typeName(cat)
    if cat == "photorobot" then return "Фоторобот"
    elseif cat == "photo" then return "Фото"
    elseif cat == "photo_print" then return "Печать"
    elseif cat == "drawing" then return "Рисунок"
    elseif cat == "import" then return "Импорт" end
    return "Фото"
  end

  local function loadGallery()
    list:Clear()
    for _, r in ipairs(ctx.files() or {}) do
      local cat = r.category or ""
      if cat == "photorobot" or cat == "photo" or cat == "photo_print" or cat == "drawing" or cat == "import" then
        local line = ui.addLine(list, r.name, os.date("%d.%m", r.updated), math.ceil((r.size or 0) / 1024), typeName(cat), r.owner)
        line._file = r
      end
    end
  end

  local selected = nil
  list.OnRowSelected = function(_, _, line) selected = line._file end

  -- Правая панель: превью + действия.
  local right = vgui.Create("DPanel", body)
  right:SetPos(530, 70); right:SetSize(286, 440)
  right.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, C.panel) end

  -- Живое превью выбранного файла.
  local preview = vgui.Create("DPanel", right)
  preview:SetPos(6, 6); preview:SetSize(274, 150)
  local previewState = nil
  local previewImage = nil
  preview.Paint = function(_, w, h)
    draw.RoundedBox(6, 0, 0, w, h, C.card)
    if previewState then
      local s = math.min(w / PR.DesignW, h / PR.DesignH)
      PR.Render(previewState, w, h, { caption = "" })
    elseif previewImage then
      draw.SimpleText("Фото (JPEG)", "GRMNet_Small", w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    else
      draw.SimpleText("Выберите файл для превью", "GRMNet_Small", w / 2, h / 2, C.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
  end

  local function refreshPreview()
    previewState = nil; previewImage = nil
    if selected then
      if type(selected.grm) == "string" and selected.grm ~= "" then
        local st = PR.Deserialize(selected.grm)
        if st then previewState = st end
      elseif selected.imagePath then
        previewImage = selected.imagePath
      end
    end
  end

  local oldSelect = list.OnRowSelected
  list.OnRowSelected = function(_, _, line)
    selected = line._file
    refreshPreview()
  end

  local by = 164
  ui.btn(right, "НОВЫЙ ФОТОРОБОТ", 6, by, 274, 30, C.blue, function() PR.Editor(ctx, { state = PR.NewState() }) end)
  by = by + 36
  ui.btn(right, "ИЗМЕНИТЬ (GRMF)", 6, by, 132, 30, C.green, function()
    if not selected then notification.AddLegacy("Выберите файл", NOTIFY_ERROR, 3) return end
    if not (type(selected.grm) == "string" and selected.grm ~= "") then notification.AddLegacy("Это не фоторобот GRMF (нет данных для правки)", NOTIFY_ERROR, 3) return end
    PR._expectOpen = true
    ctx.send("file_open", function() net.WriteString(selected.id) end)
  end)
  ui.btn(right, "ПРОСМОТР", 146, by, 134, 30, C.card, function()
    if not selected then notification.AddLegacy("Выберите файл", NOTIFY_ERROR, 3) return end
    local st = (type(selected.grm) == "string" and selected.grm ~= "") and PR.Deserialize(selected.grm) or nil
    viewFrame(ctx, selected, st)
  end)
  by = by + 36
  ui.btn(right, "УДАЛИТЬ", 6, by, 274, 30, C.red, function()
    if not selected then notification.AddLegacy("Выберите файл", NOTIFY_ERROR, 3) return end
    ctx.send("file_delete", function() net.WriteString(selected.id) end)
    timer.Simple(0.5, function() if PR._ctx == ctx and PR._view == "gallery" then loadGallery(); refreshPreview() end end)
  end)
  by = by + 40

  -- Печать.
  local printerCombo = vgui.Create("DComboBox", right)
  printerCombo:SetPos(6, by); printerCombo:SetSize(274, 26)
  printerCombo.PrinterID = ""
  for _, d in ipairs((ctx.topology() or {}).devices or {}) do
    if d.kind == "printer" and d.online then printerCombo:AddChoice("🖨 " .. d.name, d.id) end
  end
  printerCombo.OnSelect = function(_, _, _, id) printerCombo.PrinterID = id end
  by = by + 30
  local paperCombo = vgui.Create("DComboBox", right)
  paperCombo:SetPos(6, by); paperCombo:SetSize(132, 24)
  paperCombo:AddChoice("A4", "A4"); paperCombo:AddChoice("A5", "A5"); paperCombo:ChooseOptionID(1)
  local orientCombo = vgui.Create("DComboBox", right)
  orientCombo:SetPos(148, by); orientCombo:SetSize(132, 24)
  orientCombo:AddChoice("Книжная", "portrait"); orientCombo:AddChoice("Альбом", "landscape"); orientCombo:ChooseOptionID(1)
  by = by + 28
  local copiesWang = vgui.Create("DNumberWang", right)
  copiesWang:SetPos(6, by); copiesWang:SetSize(132, 24)
  copiesWang:SetMin(1); copiesWang:SetMax(5); copiesWang:SetValue(1)
  ui.btn(right, "🖨 ПЕЧАТЬ", 148, by, 132, 24, C.yellow, function()
    if not selected then notification.AddLegacy("Выберите файл", NOTIFY_ERROR, 3) return end
    if printerCombo.PrinterID == "" then notification.AddLegacy("Выберите принтер", NOTIFY_ERROR, 3) return end
    local _, pd = paperCombo:GetSelected(); local _, od = orientCombo:GetSelected()
    ctx.send("print", function()
      net.WriteString(selected.id)
      net.WriteString(printerCombo.PrinterID)
      net.WriteString(pd or "A4")
      net.WriteString(od or "portrait")
      net.WriteUInt(copiesWang:GetValue(), 4)
      net.WriteString("normal")
    end)
  end)
  by = by + 34

  -- Импорт.
  ui.textLabel(right, "Импорт из grm_import/:", 6, by, 274, 18, "GRMNet_Small", C.dim)
  by = by + 20
  local importList = vgui.Create("DComboBox", right)
  importList:SetPos(6, by); importList:SetSize(274, 24)
  importList:SetText("Поиск файлов...")
  local function refreshImport()
    if not IsValid(importList) then return end
    importList:Clear()
    for _, pat in ipairs({ "*.jpg", "*.png" }) do
      local files = file.Find("grm_import/" .. pat, "DATA") or {}
      for _, fn in ipairs(files) do importList:AddChoice(fn, "grm_import/" .. fn) end
    end
    if importList:GetOptionText(1) == nil then importList:SetText("Нет файлов в grm_import/") end
  end
  timer.Simple(0.1, refreshImport)
  local importSelected = ""
  importList.OnSelect = function(_, _, txt, data) importSelected = data or txt end
  by = by + 28
  ui.btn(right, "📥 ИМПОРТИРОВАТЬ", 6, by, 274, 24, C.purple, function()
    if importSelected == "" then notification.AddLegacy("Выберите файл импорта", NOTIFY_ERROR, 3) return end
    if not file.Exists(importSelected, "DATA") then notification.AddLegacy("Файл не найден", NOTIFY_ERROR, 3) return end
    local data = file.Read(importSelected, "DATA")
    if not data or #data == 0 then notification.AddLegacy("Пустой файл", NOTIFY_ERROR, 3) return end
    if #data > 200 * 1024 then notification.AddLegacy("Файл >200Кб, сожмите", NOTIFY_ERROR, 4) return end
    local nm = string.GetFileFromFilename(importSelected)
    ctx.send("image_save", function()
      net.WriteString("Импорт_" .. nm)
      net.WriteString("import")
      net.WriteUInt(#data, 24)
      net.WriteData(data, #data)
    end)
  end)

  local info = vgui.Create("DPanel", body)
  info:SetPos(530, 520); info:SetSize(286, 90)
  info.Paint = function(_, w, h)
    draw.RoundedBox(8, 0, 0, w, h, C.panel)
    draw.SimpleText("ИНФО", "GRMNet_Small", w / 2, 14, C.dim, TEXT_ALIGN_CENTER)
    if selected then
      draw.SimpleText(tostring(selected.name), "GRMNet_Body", 20, 32, C.text)
      draw.SimpleText("Владелец: " .. tostring(selected.owner), "GRMNet_Small", 20, 52, C.dim)
      draw.SimpleText("Формат: " .. ((type(selected.grm) == "string" and selected.grm ~= "") and "GRMFACE" or "JPEG"), "GRMNet_Small", 20, 70, C.dim)
    else
      draw.SimpleText("Выберите файл", "GRMNet_Small", w / 2, 50, C.dim, TEXT_ALIGN_CENTER)
    end
  end

  local stats = vgui.Create("DPanel", body)
  stats:SetPos(18, 520); stats:SetSize(500, 22)
  stats.Paint = function(_, w, h)
    draw.RoundedBox(4, 0, 0, w, h, C.panel)
    local cnt, grmf = 0, 0
    for _, r in ipairs(ctx.files() or {}) do
      local cat = r.category or ""
      if cat == "photorobot" or cat == "photo" or cat == "photo_print" or cat == "drawing" or cat == "import" then
        cnt = cnt + 1
        if type(r.grm) == "string" and r.grm ~= "" then grmf = grmf + 1 end
      end
    end
    draw.SimpleText("Фото/рисунков: " .. cnt .. " · GRMFACE: " .. grmf, "GRMNet_Small", 12, 11, C.dim)
  end

  loadGallery()
end

-- ── Редактор ────────────────────────────────────────────────────────────
function PR.Editor(ctx, opts)
  PR._view = "editor"
  opts = opts or {}
  local C = ctx.C
  local body = ctx.body
  body:Clear()
  local ui = ctx.ui

  local state = PR.Normalize(opts.state or PR.NewState())
  local fileID = opts.fileID or ""

  ui.textLabel(body, "РЕДАКТОР ФОТОРОБОТА 2.0", 18, 10, 340, 28, "GRMNet_Title", C.text)
  ui.textLabel(body, "GRM Face Sketch · формат GRMFACE/1 · слои и палитра", 18, 38, 560, 20, "GRMNet_Small", C.dim)
  ui.btn(body, "◄ К ГАЛЕРЕЕ", 650, 10, 164, 28, C.card, function() PR.Gallery(ctx) end)

  -- Холст.
  local canvas = vgui.Create("DPanel", body)
  canvas:SetPos(18, 64); canvas:SetSize(400, 520)
  canvas.Paint = function(_, w, h) PR.Render(state, w, h) end

  -- Панель управления.
  local ctrl = vgui.Create("DPanel", body)
  ctrl:SetPos(434, 64); ctrl:SetSize(378, 520)
  ctrl.Paint = function(_, w, h) draw.RoundedBox(8, 0, 0, w, h, C.panel) end

  local cy = 12
  for _, slot in ipairs(PR.SlotOrder) do
    local max = #PR.Parts[slot]
    ui.textLabel(ctrl, PR.SlotLabels[slot] .. ":", 14, cy, 80, 18, "GRMNet_Small", C.dim)
    local lbl = vgui.Create("DLabel", ctrl)
    lbl:SetPos(100, cy); lbl:SetSize(170, 18)
    lbl:SetFont("GRMNet_Small"); lbl:SetTextColor(C.text)
    local function updateLabel()
      local p = PR.Parts[slot][state[slot]] or PR.Parts[slot][1]
      lbl:SetText((p.name or "?") .. " (" .. state[slot] .. "/" .. max .. ")")
    end
    updateLabel()
    local prevBtn = vgui.Create("DButton", ctrl)
    prevBtn:SetPos(280, cy); prevBtn:SetSize(36, 18); prevBtn:SetText("◄"); prevBtn:SetFont("GRMNet_Small"); prevBtn:SetTextColor(C.text)
    prevBtn.Paint = function(self, w, h) draw.RoundedBox(3, 0, 0, w, h, self:IsHovered() and C.hover or C.card) end
    prevBtn.DoClick = function() state[slot] = state[slot] - 1; if state[slot] < 1 then state[slot] = max end; updateLabel() end
    local nextBtn = vgui.Create("DButton", ctrl)
    nextBtn:SetPos(320, cy); nextBtn:SetSize(36, 18); nextBtn:SetText("►"); nextBtn:SetFont("GRMNet_Small"); nextBtn:SetTextColor(C.text)
    nextBtn.Paint = function(self, w, h) draw.RoundedBox(3, 0, 0, w, h, self:IsHovered() and C.hover or C.card) end
    nextBtn.DoClick = function() state[slot] = state[slot] + 1; if state[slot] > max then state[slot] = 1 end; updateLabel() end
    cy = cy + 24
  end
  cy = cy + 6

  local function swatches(label, list, key, startX)
    ui.textLabel(ctrl, label, 14, cy, 66, 18, "GRMNet_Small", C.dim)
    for i, tone in ipairs(list) do
      local bx = startX + (i - 1) * 24
      local sw = vgui.Create("DButton", ctrl)
      sw:SetPos(bx, cy); sw:SetSize(20, 16); sw:SetText("")
      sw.Paint = function(_, w, h)
        local c = tone.c
        draw.RoundedBox(4, 0, 0, w, h, ColorCtor(c.r, c.g, c.b, 255))
        if state[key] == i then surface.SetDrawColor(255, 255, 255); surface.DrawOutlinedRect(0, 0, w, h, 2) end
      end
      sw.DoClick = function() state[key] = i end
    end
    cy = cy + 24
  end
  swatches("Кожа:", PR.SkinTones, "skin", 90)
  swatches("Волосы:", PR.HairColors, "haircol", 90)
  swatches("Глаза:", PR.EyeColors, "eyecol", 90)

  -- Эффект.
  ui.textLabel(ctrl, "Эффект:", 14, cy, 66, 18, "GRMNet_Small", C.dim)
  local effLbl = vgui.Create("DLabel", ctrl)
  effLbl:SetPos(84, cy); effLbl:SetSize(170, 18)
  effLbl:SetFont("GRMNet_Small"); effLbl:SetTextColor(C.text)
  effLbl:SetText(PR.EffectNames[state.effect] or "Обычный")
  local effPrev = vgui.Create("DButton", ctrl)
  effPrev:SetPos(260, cy); effPrev:SetSize(36, 18); effPrev:SetText("◄"); effPrev:SetFont("GRMNet_Small"); effPrev:SetTextColor(C.text)
  effPrev.Paint = function(self, w, h) draw.RoundedBox(3, 0, 0, w, h, self:IsHovered() and C.hover or C.card) end
  effPrev.DoClick = function() state.effect = state.effect - 1; if state.effect < 1 then state.effect = #PR.EffectNames end; effLbl:SetText(PR.EffectNames[state.effect]) end
  local effNext = vgui.Create("DButton", ctrl)
  effNext:SetPos(304, cy); effNext:SetSize(36, 18); effNext:SetText("►"); effNext:SetFont("GRMNet_Small"); effNext:SetTextColor(C.text)
  effNext.Paint = function(self, w, h) draw.RoundedBox(3, 0, 0, w, h, self:IsHovered() and C.hover or C.card) end
  effNext.DoClick = function() state.effect = state.effect + 1; if state.effect > #PR.EffectNames then state.effect = 1 end; effLbl:SetText(PR.EffectNames[state.effect]) end
  cy = cy + 28

  -- Название + описание.
  ui.textLabel(ctrl, "Название:", 14, cy, 66, 18, "GRMNet_Small", C.dim)
  local nameEntry = ui.entry(ctrl, "Фоторобот_...", 84, cy - 2, 280, 24, false)
  nameEntry:SetText(opts.name or ("Фоторобот_" .. os.date("%d%m_%H%M")))
  cy = cy + 28
  ui.textLabel(ctrl, "Описание:", 14, cy, 66, 18, "GRMNet_Small", C.dim)
  local descEntry = ui.entry(ctrl, "Особые приметы...", 84, cy, 280, 40, true)
  descEntry:SetText(opts.desc or "")
  cy = cy + 48

  -- Печать (принтер + копии).
  ui.textLabel(ctrl, "Принтер:", 14, cy, 66, 18, "GRMNet_Small", C.dim)
  local printerCombo = vgui.Create("DComboBox", ctrl)
  printerCombo:SetPos(84, cy); printerCombo:SetSize(176, 22)
  printerCombo.PrinterID = ""
  for _, d in ipairs((ctx.topology() or {}).devices or {}) do
    if d.kind == "printer" and d.online then printerCombo:AddChoice("🖨 " .. d.name, d.id) end
  end
  printerCombo.OnSelect = function(_, _, _, id) printerCombo.PrinterID = id end
  local copiesW = vgui.Create("DNumberWang", ctrl)
  copiesW:SetPos(270, cy); copiesW:SetSize(50, 22)
  copiesW:SetMin(1); copiesW:SetMax(5); copiesW:SetValue(1)
  cy = cy + 28

  local function capture()
    local data = PR.Capture(state, 400, 520, 82)
    if not data or #data == 0 then
      local x, y = canvas:LocalToScreen(0, 0)
      data = render.Capture({ format = "jpeg", quality = 82, x = x, y = y, w = 400, h = 520 })
    end
    return data
  end

  ui.btn(ctrl, "💾 СОХРАНИТЬ", 14, cy, 110, 28, C.green, function()
    local data = capture()
    if not data or #data == 0 then notification.AddLegacy("Ошибка захвата", NOTIFY_ERROR, 3) return end
    if #data > 200 * 1024 then notification.AddLegacy("Картинка >200Кб, упростите", NOTIFY_ERROR, 3) return end
    local nm = nameEntry:GetText()
    local grm = PR.Serialize(state, { name = nm, desc = descEntry:GetText(), author = ctx.user() })
    ctx.send("photorobot_save", function()
      net.WriteString(nm)
      net.WriteString(descEntry:GetText())
      net.WriteString(grm)
      net.WriteUInt(#data, 24)
      net.WriteData(data, #data)
    end)
  end)
  ui.btn(ctrl, "🖨 ПЕЧАТЬ", 132, cy, 110, 28, C.yellow, function()
    if printerCombo.PrinterID == "" then notification.AddLegacy("Выберите принтер", NOTIFY_ERROR, 3) return end
    local data = capture()
    if not data or #data == 0 then notification.AddLegacy("Ошибка захвата", NOTIFY_ERROR, 3) return end
    if #data > 200 * 1024 then notification.AddLegacy("Картинка >200Кб", NOTIFY_ERROR, 3) return end
    PR._pendingPrint = { printerID = printerCombo.PrinterID, paper = "A4", orient = "portrait", copies = copiesW:GetValue(), quality = "normal" }
    local nm = "Печать_" .. os.date("%d%m_%H%M")
    local grm = PR.Serialize(state, { name = nm, desc = descEntry:GetText(), author = ctx.user() })
    ctx.send("photorobot_save", function()
      net.WriteString(nm)
      net.WriteString(descEntry:GetText())
      net.WriteString(grm)
      net.WriteUInt(#data, 24)
      net.WriteData(data, #data)
    end)
  end)
  ui.btn(ctrl, "📧 РАССЫЛКА", 250, cy, 110, 28, C.purple, function()
    local mf = ctx.ui.frame("РАССЫЛКА ФОТОРОБОТА", 420, 300)
    local toEntry = ui.entry(mf, "Кому", 18, 60, 384, 28)
    local bodyEntry = ui.entry(mf, "Текст", 18, 100, 384, 120, true)
    bodyEntry:SetText("Фоторобот " .. os.date("%d.%m.%Y") .. "\n" .. descEntry:GetText())
    ui.btn(mf, "ОТПРАВИТЬ", 18, 230, 384, 36, C.blue, function()
      ctx.send("mail_send", function()
        net.WriteString(toEntry:GetText())
        net.WriteString("Фоторобот")
        net.WriteString(bodyEntry:GetText())
      end)
      mf:Close()
    end)
  end)
  cy = cy + 36

  ui.textLabel(ctrl, "Шаблоны:", 14, cy, 80, 18, "GRMNet_Small", C.dim)
  cy = cy + 20
  local presets = {
    { name = "Подозр. 1", data = { face = 1, hair = 1, eyes = 1, brows = 2, nose = 1, mouth = 1, chin = 1, extras = 1 } },
    { name = "Подозр. 2", data = { face = 2, hair = 4, eyes = 3, brows = 4, nose = 3, mouth = 4, chin = 2, extras = 4 } },
    { name = "Подозр. 3", data = { face = 3, hair = 6, eyes = 5, brows = 1, nose = 2, mouth = 2, chin = 1, extras = 6 } },
    { name = "Подозр. 4", data = { face = 5, hair = 2, eyes = 2, brows = 3, nose = 5, mouth = 6, chin = 3, extras = 1 } },
  }
  for i, preset in ipairs(presets) do
    local bx = 14 + ((i - 1) % 2) * 182
    local by2 = cy + math.floor((i - 1) / 2) * 28
    ui.btn(ctrl, preset.name, bx, by2, 176, 24, C.card, function()
      for k, v in pairs(preset.data) do state[k] = v end
      state.effect = math.max(1, math.min(#PR.Effects, 1 + ((state.face + state.hair) % 3)))
    end)
  end
end

print("[GRM Photorobot] module v" .. PR.Version .. " loaded (GRMFACE/" .. PR.FormatVersion .. ")")
