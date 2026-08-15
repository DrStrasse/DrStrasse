-- Стенд своих языков GRM NET OS (sh_grm_osformat.lua):
-- FNV-1a, GRMFILE/1 (контейнер файла), GRMML (язык разметки).
local function read(p) local f = assert(io.open(p, "rb")); local s = f:read("*a"); f:close(); return s end
local src = read("lua/autorun/sh_grm_osformat.lua")
local pass, fail = 0, 0
local function ok(v, n) if v then pass = pass + 1; print("  ok  " .. n) else fail = fail + 1; print("  FAIL " .. n) end end

local chunk, err = loadfile("lua/autorun/sh_grm_osformat.lua")
ok(chunk ~= nil, "osformat parses: " .. tostring(err))
if not chunk then os.exit(1) end
local ran, rerr = pcall(chunk)
ok(ran, "osformat executes: " .. tostring(rerr))
local F = GRM.OSFormat
ok(F ~= nil, "GRM.OSFormat exposed")
ok(F.Version == "1.0.0", "version 1.0.0")

-- FNV-1a: известные векторы.
ok(F.ToHex(F.Checksum("")) == "811c9dc5", "FNV-1a('') == 811c9dc5")
ok(F.ToHex(F.Checksum("a")) == "e40c292c", "FNV-1a('a') == e40c292c")
ok(F.ToHex(F.Checksum("GRMFACE/1")) == F.ToHex(F.Checksum("GRMFACE/1")), "checksum deterministic")
ok(F.FromHex("e40c292c") == F.Checksum("a"), "FromHex round-trips")

-- Escape/Unescape.
local e = F.Escape("a=b\nc%d\r")
ok(e:find("%%3D") and e:find("%%0A") and e:find("%%25") and e:find("%%0D"), "escape encodes = \\n % \\r")
ok(F.Unescape(e) == "a=b\nc%d\r", "unescape round-trips")

-- GRMFILE round-trip.
local meta = { name = "Заметка/1", type = "doc", created = 1234567890 }
local txt = F.FileEncode(meta, "первая строка\nвторая=строка")
ok(txt:match("^GRMFILE/1\n"), "GRMFILE magic + version")
ok(txt:match("\nsig=[0-9a-f]+$"), "GRMFILE sig present")
local m2, p2 = F.FileDecode(txt)
ok(m2 ~= nil, "GRMFILE decode ok")
ok(m2 and m2.name == "Заметка/1" and m2.type == "doc" and m2.created == 1234567890, "GRMFILE meta round-trips")
ok(p2 == "первая строка\nвторая=строка", "GRMFILE payload round-trips (multiline + =)")
local m3, p3 = F.FileDecode(txt:gsub("type=doc", "type=txt", 1))
ok(m3 == nil and p3 == nil, "GRMFILE tamper rejected")
ok(F.FileDecode("") == nil and F.FileDecode("HELLO/1\n...") == nil, "GRMFILE garbage rejected")

-- GRMML blocks.
local blocks = F.Markup.Parse("# Заголовок\n## Под\n### Ещё\n- пункт\n> цитата\n[hr]\n[img: grm_computer/images/x.jpg]\n[grface: file_abc]\nобычный параграф здесь\nвторая строка\n")
local kinds = {}
for _, b in ipairs(blocks) do kinds[#kinds + 1] = b.kind end
ok(kinds[1] == "h1" and blocks[1].text == "Заголовок", "GRMML h1")
ok(kinds[2] == "h2" and kinds[3] == "h3", "GRMML h2/h3")
ok(kinds[4] == "bullet" and blocks[4].text == "пункт", "GRMML bullet")
ok(kinds[5] == "quote" and blocks[5].text == "цитата", "GRMML quote")
ok(kinds[6] == "hr", "GRMML hr")
ok(kinds[7] == "img" and blocks[7].path == "grm_computer/images/x.jpg", "GRMML img path")
ok(kinds[8] == "grface" and blocks[8].ref == "file_abc", "GRMML grface ref")
ok(kinds[9] == "para" and blocks[9].text == "обычный параграф здесь вторая строка", "GRMML para joins lines")

-- GRMML inline.
local inline = F.Markup.Inline("обычный **жирный** и *курсив* и [img: a.jpg] и [grface: f1]")
local tok = {}
for _, t in ipairs(inline) do tok[#tok + 1] = t.kind .. ":" .. tostring(t.text or t.path or t.ref) end
ok(tok[1] == "text:обычный ", "inline text")
ok(tok[2] == "bold:жирный", "inline bold")
ok(tok[3] == "text: и ", "inline text between")
ok(tok[4] == "italic:курсив", "inline italic")
local hasImg, hasGrf = false, false
for _, t in ipairs(inline) do if t.kind == "img" and t.path == "a.jpg" then hasImg = true end if t.kind == "grface" and t.ref == "f1" then hasGrf = true end end
ok(hasImg, "inline img")
ok(hasGrf, "inline grface")
ok(F.Markup.Inline("") ~= nil and #F.Markup.Inline("") == 0, "inline empty -> no tokens")

print(("OSFORMAT: %d/%d failures=%d"):format(pass, pass + fail, fail))
if fail > 0 then os.exit(1) end
