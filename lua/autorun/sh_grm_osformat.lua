--[[
  GRM OS Format — СВОИ ЯЗЫКИ GRM NET OS.

  Чистые (без GMod-зависимостей) языки/форматы, общие для сервера и клиента:

    * FNV-1a 32 — контрольная сумма (свой код, без util.CRC; работает и вне игры)
    * GRMFILE/1 — контейнер файла ОС: версия, тип, метаданные, payload, сигнатура
    * GRMML      — GRM Markup Language: собственный язык разметки документов ОС
      (заголовки #/##/###, списки, цитаты, разделитель [hr], вставки [img: путь]
      и [grface: fileID], инлайн **жирный** и *курсив*)

  Записи/контейнеры — строковый формат `key=value` с экранированием значений,
  в конце строка `sig=<hex>` с контрольной суммой всего тела (как GRMFACE/1).
  Это сознательный отказ от HTML/DHTML и от голого JSON с числовыми ключами.
]]
GRM = GRM or {}
GRM.OSFormat = GRM.OSFormat or {}
local F = GRM.OSFormat
F.Version = "1.0.0"

-- ── FNV-1a 32 (детерминированная, без util.CRC) ────────────────────────
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

function F.Checksum(s)
  local h = 2166136261
  for i = 1, #tostring(s or "") do
    h = bxor32(h, tostring(s):byte(i))
    h = (h * 16777619) % 4294967296
  end
  return h
end

local HEXC = "0123456789abcdef"
function F.ToHex(n)
  local s = ""
  n = math.floor(tonumber(n) or 0) % 4294967296
  for _ = 1, 8 do s = HEXC:sub(n % 16 + 1, n % 16 + 1) .. s; n = math.floor(n / 16) end
  return s
end

function F.FromHex(s)
  local n = 0
  for i = 1, #tostring(s or "") do
    local d = tonumber(tostring(s):sub(i, i), 16)
    if not d then return nil end
    n = n * 16 + d
  end
  return n % 4294967296
end

-- ── Экранирование значений в key=value строках ─────────────────────────
function F.Escape(s)
  s = tostring(s or "")
  return s:gsub("%%", "%%25"):gsub("\r", "%%0D"):gsub("\n", "%%0A"):gsub("=", "%%3D")
end

function F.Unescape(s)
  s = tostring(s or "")
  return (s:gsub("%%0D", "\r"):gsub("%%0A", "\n"):gsub("%%3D", "="):gsub("%%25", "%%"))
end

-- Разбить текст на строки (без пустого хвоста).
function F.Lines(text)
  local out = {}
  for ln in tostring(text or ""):gmatch("[^\r\n]+") do out[#out + 1] = ln end
  return out
end

-- Проверка сигнатуры: body + "\nsig=<hex>".
function F.VerifySig(body, sigLine)
  local sig = sigLine and sigLine:match("^sig=([0-9a-fA-F]+)$") or nil
  if not sig then return nil, "нет контрольной суммы" end
  local want = F.FromHex(sig)
  if not want then return nil, "битая контрольная сумма" end
  if F.Checksum(body) ~= want then return nil, "контрольная сумма не совпала (данные повреждены)" end
  return true
end

-- ── GRMFILE/1 — контейнер файла ОС ──────────────────────────────────────
-- meta = {name, type=text|doc|image|grface, created} ; payload — любые данные.
function F.FileEncode(meta, payload)
  meta = meta or {}
  local lines = {
    "GRMFILE/1",
    "name=" .. F.Escape(meta.name or ""),
    "type=" .. F.Escape(meta.type or "text"),
    "created=" .. tostring(meta.created or os.time()),
    "data=" .. F.Escape(payload or ""),
  }
  local body = table.concat(lines, "\n")
  return body .. "\nsig=" .. F.ToHex(F.Checksum(body))
end

function F.FileDecode(text)
  if type(text) ~= "string" or text == "" then return nil, nil, "пустой документ" end
  local lines = F.Lines(text)
  if #lines < 5 then return nil, nil, "слишком короткий контейнер" end
  local magic, ver = lines[1]:match("^(%a+)/(%d+)$")
  if magic ~= "GRMFILE" then return nil, nil, "не GRMFILE" end
  if tonumber(ver) ~= 1 then return nil, nil, "неподдерживаемая версия " .. tostring(ver) end
  local body = table.concat(lines, "\n", 1, #lines - 1)
  local ok, err = F.VerifySig(body, lines[#lines])
  if not ok then return nil, nil, err end
  local f = {}
  for i = 2, #lines - 1 do
    local k, v = lines[i]:match("^([%w_]+)=(.*)$")
    if k then f[k] = v end
  end
  local meta = { name = F.Unescape(f.name or ""), type = F.Unescape(f.type or "text"), created = tonumber(f.created) or 0 }
  local payload = F.Unescape(f.data or "")
  return meta, payload
end

-- ── GRMML — GRM Markup Language (язык разметки документов ОС) ──────────
-- Parse возвращает массив блоков:
--   {kind="h1"|"h2"|"h3"|"para"|"bullet"|"quote"|"hr"|"img"|"grface", ...}
-- Inline возвращает массив токенов {kind="text"|"bold"|"italic"|"img"|"grface", ...}
F.Markup = F.Markup or {}

function F.Markup.Parse(text)
  local lines = F.Lines(text)
  local blocks = {}
  local para
  local function flushPara()
    if para then blocks[#blocks + 1] = { kind = "para", text = table.concat(para, " ") }; para = nil end
  end
  for _, ln in ipairs(lines) do
    local t = ln:match("^%s*(.-)%s*$")
    if t == "" then
      flushPara()
    else
      local h3 = t:match("^###%s+(.+)$")
      local h2 = t:match("^##%s+(.+)$")
      local h1 = t:match("^#%s+(.+)$")
      local bullet = t:match("^%-%s+(.+)$")
      local quote = t:match("^>%s*(.+)$")
      local img = t:match("^%[img:%s*([^%]]+)%]$")
      local grface = t:match("^%[grface:%s*([^%]]+)%]$")
      if h3 then flushPara(); blocks[#blocks + 1] = { kind = "h3", text = h3 }
      elseif h2 then flushPara(); blocks[#blocks + 1] = { kind = "h2", text = h2 }
      elseif h1 then flushPara(); blocks[#blocks + 1] = { kind = "h1", text = h1 }
      elseif bullet then flushPara(); blocks[#blocks + 1] = { kind = "bullet", text = bullet }
      elseif quote then flushPara(); blocks[#blocks + 1] = { kind = "quote", text = quote }
      elseif img then flushPara(); blocks[#blocks + 1] = { kind = "img", path = img }
      elseif grface then flushPara(); blocks[#blocks + 1] = { kind = "grface", ref = grface }
      elseif t == "[hr]" then flushPara(); blocks[#blocks + 1] = { kind = "hr" }
      else para = para or {}; para[#para + 1] = t
      end
    end
  end
  flushPara()
  return blocks
end

function F.Markup.Inline(text)
  text = tostring(text or "")
  local out = {}
  local pos, n = 1, #text
  while pos <= n do
    local b = text:find("**", pos, true)
    local i = text:find("*", pos, true)
    if b and b == i then i = nil end -- `**` — это жирный, не курсив
    local im = text:find("[img:", pos, true)
    local gf = text:find("[grface:", pos, true)
    local cands = {}
    if b then cands[#cands + 1] = { p = b, t = "bold" } end
    if i then cands[#cands + 1] = { p = i, t = "italic" } end
    if im then cands[#cands + 1] = { p = im, t = "img" } end
    if gf then cands[#cands + 1] = { p = gf, t = "grface" } end
    table.sort(cands, function(a, b2) return a.p < b2.p end)
    local c = cands[1]
    if not c then
      out[#out + 1] = { kind = "text", text = text:sub(pos) }
      break
    end
    if c.p > pos then out[#out + 1] = { kind = "text", text = text:sub(pos, c.p - 1) } end
    if c.t == "bold" then
      local e = text:find("**", c.p + 2, true)
      if e then out[#out + 1] = { kind = "bold", text = text:sub(c.p + 2, e - 1) }; pos = e + 2
      else out[#out + 1] = { kind = "text", text = "**" }; pos = c.p + 2 end
    elseif c.t == "italic" then
      local e = text:find("*", c.p + 1, true)
      if e then out[#out + 1] = { kind = "italic", text = text:sub(c.p + 1, e - 1) }; pos = e + 1
      else out[#out + 1] = { kind = "text", text = "*" }; pos = c.p + 1 end
    elseif c.t == "img" then
      local e = text:find("]", c.p, true)
      if e then
        local path = text:sub(c.p + 5, e - 1):match("^%s*(.-)%s*$")
        out[#out + 1] = { kind = "img", path = path }; pos = e + 1
      else out[#out + 1] = { kind = "text", text = text:sub(c.p) }; break end
    elseif c.t == "grface" then
      local e = text:find("]", c.p, true)
      if e then
        local ref = text:sub(c.p + 8, e - 1):match("^%s*(.-)%s*$")
        out[#out + 1] = { kind = "grface", ref = ref }; pos = e + 1
      else out[#out + 1] = { kind = "text", text = text:sub(c.p) }; break end
    end
  end
  return out
end

print("[GRM OSFormat] v" .. F.Version .. " loaded (GRMFILE/1 + GRMML + FNV-1a)")
