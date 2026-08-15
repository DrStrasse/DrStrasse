--[[
  GRM OS Document — модуль рендера документов на СВОЁМ языке GRMML.

  GRM.OSDoc рисует текст, размеченный языком GRMML (см. sh_grm_osformat.lua):
    # / ## / ### — заголовки
    - пункт        — списки
    > цитата
    [hr]           — разделитель
    [img: путь]    — изображение из data/
    [grface: id]   — фоторобот (GRMFACE) по fileID
    **жирный** и *курсив* — инлайн

  Рендер делится на чистое ядро (Layout — раскладка блоков в строки, тестируемо
  в LuaJIT) и GLua-обвязку (Paint / Viewer). Зависимости только от GRM.OSFormat
  (с фолбэком) и опционально GRM.Photorobot (для [grface:]).
]]
if not CLIENT then return end

GRM = GRM or {}
GRM.OSDoc = GRM.OSDoc or {}
local OD = GRM.OSDoc
OD.Version = "1.0.0"

local ColorCtor = Color or function(r, g, b, a) return { r = r or 255, g = g or 255, b = b or 255, a = a or 255 } end

-- Шрифты (создаём, только если движок умеет).
if surface and surface.CreateFont then
  surface.CreateFont("GRMDoc_H1", { font = "Roboto", size = 22, weight = 800, extended = true })
  surface.CreateFont("GRMDoc_H2", { font = "Roboto", size = 18, weight = 700, extended = true })
  surface.CreateFont("GRMDoc_H3", { font = "Roboto", size = 15, weight = 700, extended = true })
  surface.CreateFont("GRMDoc_Body", { font = "Roboto", size = 13, weight = 500, extended = true })
  surface.CreateFont("GRMDoc_Quote", { font = "Roboto", size = 13, weight = 400, extended = true })
end

local FONT = { h1 = "GRMDoc_H1", h2 = "GRMDoc_H2", h3 = "GRMDoc_H3", para = "GRMDoc_Body", bullet = "GRMDoc_Body", quote = "GRMDoc_Quote" }

OD.DefaultColors = {
  bg = ColorCtor(17, 24, 38, 245),
  h1 = ColorCtor(240, 245, 252, 255),
  h2 = ColorCtor(220, 230, 245, 255),
  h3 = ColorCtor(200, 215, 235, 255),
  text = ColorCtor(235, 240, 248, 255),
  quote = ColorCtor(150, 165, 185, 255),
  bullet = ColorCtor(220, 230, 245, 255),
  rule = ColorCtor(90, 100, 120, 255),
  dim = ColorCtor(150, 165, 185, 255),
}

-- ── Чистое ядро (тестируется в LuaJIT) ─────────────────────────────────
local function measure(text, font)
  surface.SetFont(font)
  local w, h = surface.GetTextSize(text)
  w = tonumber(w) or (#text * 8)
  h = tonumber(h) or 14
  return w, h
end

-- Перенос текста по словам (для draw.SimpleText, который сам не переносит).
function OD.Wrap(text, maxW, font)
  font = font or "GRMDoc_Body"
  maxW = math.max(8, maxW or 200)
  local words = {}
  for w in (tostring(text or "") .. " "):gmatch("(%S+)%s") do words[#words + 1] = w end
  local lines, cur = {}, ""
  for _, w in ipairs(words) do
    local trial = cur == "" and w or cur .. " " .. w
    if measure(trial, font) > maxW and cur ~= "" then
      lines[#lines + 1] = cur
      cur = w
    else
      cur = trial
    end
  end
  if cur ~= "" then lines[#lines + 1] = cur end
  return lines
end

local function parseBlocks(text)
  if GRM.OSFormat and GRM.OSFormat.Markup then return GRM.OSFormat.Markup.Parse(text or "") end
  return { { kind = "para", text = text or "" } }
end

local function colorFor(kind, O)
  if kind == "h1" then return O.h1
  elseif kind == "h2" then return O.h2
  elseif kind == "h3" then return O.h3
  elseif kind == "quote" then return O.quote
  elseif kind == "bullet" then return O.bullet end
  return O.text
end

-- Раскладка блоков GRMML в строки. Возвращает rows, totalHeight.
function OD.Layout(text, maxW, opts)
  opts = opts or {}
  local O = opts.colors or OD.DefaultColors
  local top = opts.top or 8
  local left = opts.left or 8
  local rows = {}
  local y = top
  local blocks = parseBlocks(text)
  for _, b in ipairs(blocks) do
    local kind = b.kind
    if kind == "hr" then
      rows[#rows + 1] = { kind = "rule", y = y, h = 1 }
      y = y + 12
    elseif kind == "img" or kind == "grface" then
      local boxH = kind == "grface" and 260 or 160
      local boxW = math.min(maxW, kind == "grface" and 200 or 360)
      rows[#rows + 1] = { kind = kind, ref = b.path or b.ref, x = left, y = y, w = boxW, h = boxH }
      y = y + boxH + 8
    else
      local font = FONT[kind] or "GRMDoc_Body"
      local color = colorFor(kind, O)
      local prefix = kind == "bullet" and "•  " or ""
      local indent = (kind == "bullet" and 14) or (kind == "quote" and 12) or 0
      local avail = math.max(24, maxW - indent - left)
      local lines = OD.Wrap(prefix .. (b.text or ""), avail, font)
      for _, ln in ipairs(lines) do
        local _, lh = measure(ln, font)
        rows[#rows + 1] = { kind = "text", text = ln, font = font, color = color, x = left + indent, y = y, h = lh + 2 }
        y = y + lh + 2
      end
      y = y + (kind == "h1" and 6 or kind == "h2" and 4 or 2)
    end
  end
  return rows, y
end

-- ── GLua-обвязка ────────────────────────────────────────────────────────
local function paintRows(panel, w, h, rows, resolver, O)
  O = O or OD.DefaultColors
  draw.RoundedBox(0, 0, 0, w, h, O.bg)
  for _, r in ipairs(rows) do
    if r.kind == "text" then
      draw.SimpleText(r.text, r.font, r.x, r.y, r.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    elseif r.kind == "rule" then
      surface.SetDrawColor(O.rule.r, O.rule.g, O.rule.b, O.rule.a)
      surface.DrawRect(8, r.y, w - 16, r.h)
    elseif r.kind == "img" then
      local mat = resolver and resolver("img", r.ref)
      draw.RoundedBox(4, r.x, r.y, r.w, r.h, ColorCtor(0, 0, 0, 60))
      if mat then
        surface.SetMaterial(mat)
        surface.SetDrawColor(255, 255, 255, 255)
        surface.DrawTexturedRect(r.x + 4, r.y + 4, r.w - 8, r.h - 8)
      else
        draw.SimpleText("[изображение: " .. tostring(r.ref) .. "]", "GRMDoc_Body", r.x + 8, r.y + 8, O.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
      end
    elseif r.kind == "grface" then
      local st = resolver and resolver("grface", r.ref)
      draw.RoundedBox(4, r.x, r.y, r.w, r.h, ColorCtor(0, 0, 0, 60))
      if st and GRM.Photorobot and GRM.Photorobot.Render then
        GRM.Photorobot.Render(st, r.w, r.h, { caption = "" })
      else
        draw.SimpleText("[фоторобот: " .. tostring(r.ref) .. "]", "GRMDoc_Body", r.x + 8, r.y + 8, O.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
      end
    end
  end
end

function OD.Paint(panel, w, h, rows, resolver, colors)
  paintRows(panel, w, h, rows, resolver, colors)
end

-- Холст фиксированной ширины с кешированной раскладкой.
function OD.MakeCanvas(parent, x, y, w, text, opts)
  opts = opts or {}
  local rows, totalH = OD.Layout(text, w - (opts.left or 8), opts)
  local c = vgui.Create("DPanel", parent)
  c:SetPos(x or 0, y or 0)
  c:SetSize(w, math.max(totalH, 40))
  c.Paint = function(_, pw, ph) paintRows(c, pw, ph, rows, opts.resolver, opts.colors) end
  return c, rows
end

-- Вставка просмотра в существующую панель (скролл + холст).
function OD.Embed(parent, x, y, w, h, text, opts)
  opts = opts or {}
  local scroll = vgui.Create("DScrollPanel", parent)
  scroll:SetPos(x or 0, y or 0)
  scroll:SetSize(w, h)
  local canvas = OD.MakeCanvas(scroll, 0, 0, w - 8, text, opts)
  scroll:AddItem(canvas)
  return scroll, canvas
end

-- Отдельное окно-просмотрщик документа.
function OD.OpenViewer(title, text, opts)
  opts = opts or {}
  local w = math.min(opts.w or 560, ScrW() - 40)
  local h = math.min(opts.h or 640, ScrH() - 40)
  local f = vgui.Create("DFrame")
  f:SetTitle("")
  f:SetSize(w, h)
  f:Center()
  f:MakePopup()
  f.Paint = function(_, pw, ph)
    draw.RoundedBox(10, 0, 0, pw, ph, OD.DefaultColors.bg)
    draw.RoundedBoxEx(10, 0, 0, pw, 48, ColorCtor(15, 25, 40, 255), true, true, false, false)
    draw.SimpleText(title or "Документ", "GRMNet_Title", 18, 24, ColorCtor(240, 245, 252, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    if opts.owner then
      draw.SimpleText("Автор: " .. tostring(opts.owner), "GRMNet_Small", pw - 16, 24, OD.DefaultColors.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
    end
  end
  OD.Embed(f, 12, 58, w - 24, h - 70, text, opts)
  return f
end

print("[GRM OSDoc] v" .. OD.Version .. " loaded (GRMML renderer)")
