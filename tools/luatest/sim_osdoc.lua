-- Стенд рендера GRMML (cl_grm_osdoc.lua): чистое ядро Layout/Wrap.
CLIENT, SERVER = true, false
Color = function(r, g, b, a) return { r = r or 255, g = g or 255, b = b or 255, a = a or 255 } end
surface = {
  CreateFont = function() end,
  SetFont = function() end,
  GetTextSize = function(t) return #t * 8, 14 end,
  SetDrawColor = function() end, DrawRect = function() end, DrawLine = function() end,
  SetMaterial = function() end, DrawTexturedRect = function() end,
}
draw = { RoundedBox = function() end, SimpleText = function() end, NoTexture = function() end }
vgui = {}
ScrW = function() return 1280 end
ScrH = function() return 800 end

local ok1, e1 = loadfile("lua/autorun/sh_grm_osformat.lua")
local ok2, e2 = loadfile("lua/autorun/client/cl_grm_osdoc.lua")
local pass, fail = 0, 0
local function ok(v, n) if v then pass = pass + 1; print("  ok  " .. n) else fail = fail + 1; print("  FAIL " .. n) end end
ok(ok1 ~= nil, "osformat parses: " .. tostring(e1))
ok(ok2 ~= nil, "osdoc parses: " .. tostring(e2))
assert(ok1 and ok2)
local r1, e3 = pcall(ok1); ok(r1, "osformat executes: " .. tostring(e3))
local r2, e4 = pcall(ok2); ok(r2, "osdoc executes: " .. tostring(e4))
local OD = GRM.OSDoc
ok(OD ~= nil and OD.Version == "1.0.0", "GRM.OSDoc exposed")

-- Wrap.
local lines = OD.Wrap("это очень длинная строка которую надо перенести по словам", 80, "GRMDoc_Body")
ok(#lines > 1, "Wrap splits long text (" .. #lines .. " lines)")

-- Layout: блоки GRMML → строки.
local doc = "# Приказ\n## Пункт 1\n### Детали\n- первое\n- второе\n> цитата\n[hr]\n[img: grm_computer/images/x.jpg]\n[grface: file_abc]\nобычный текст здесь\n"
local rows, totalH = OD.Layout(doc, 500, {})
ok(#rows > 0 and totalH > 40, "Layout produces rows and height")
local kinds = {}
for _, r in ipairs(rows) do if not kinds[r.kind] then kinds[r.kind] = 0 end; kinds[r.kind] = kinds[r.kind] + 1 end
ok(kinds.text > 0, "text rows present")
ok(kinds.rule == 1, "hr rule present")
ok(kinds.img == 1, "img box present")
ok(kinds.grface == 1, "grface box present")

-- Определённость: одинаковая раскладка для одинакового текста.
local rows2, h2 = OD.Layout(doc, 500, {})
ok(#rows2 == #rows and h2 == totalH, "layout deterministic")

-- Заголовки идут раньше контента (h1 первый текст).
local firstText
for _, r in ipairs(rows) do if r.kind == "text" then firstText = r.text; break end end
ok(firstText == "Приказ", "h1 renders first: " .. tostring(firstText))

print(("OSDOC: %d/%d failures=%d"):format(pass, pass + fail, fail))
if fail > 0 then os.exit(1) end
