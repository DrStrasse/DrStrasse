-- Стенд своей базы GRM NET OS (sv_grm_osdb.lua, формат GRMDB/1):
-- CRUD, сериализация массивом (без числовых ключей), сигнатура, read-back,
-- backup + карантин при порче.
SERVER, CLIENT = true, false

-- GMod API mock (минимальный).
local files = {}
file = {
  IsDir = function() return true end,
  CreateDir = function() end,
  Exists = function(p, _) return files[p] ~= nil end,
  Read = function(p, _) return files[p] end,
  Write = function(p, s) files[p] = s end,
}
timer = { Create = function() end }
os.time = os.time or function() return 1700000000 end

local function loadmod(path)
  local chunk, err = loadfile(path)
  if not chunk then return nil, err end
  local ok, rerr = pcall(chunk)
  if not ok then return nil, rerr end
  return true
end

local pass, fail = 0, 0
local function ok(v, n) if v then pass = pass + 1; print("  ok  " .. n) else fail = fail + 1; print("  FAIL " .. n) end end

local ok1, e1 = loadmod("lua/autorun/sh_grm_osformat.lua")
ok(ok1, "osformat loads: " .. tostring(e1))
local ok2, e2 = loadmod("lua/autorun/server/sv_grm_osdb.lua")
ok(ok2, "osdb loads: " .. tostring(e2))
local DB = GRM.OSDB
ok(DB ~= nil, "GRM.OSDB exposed")

local st = DB.Open("testdb")
ok(st ~= nil and DB.Count(st) == 0, "open empty store")

-- CRUD.
local r1 = DB.Upsert(st, "doc_001", { name = "Приказ", type = "doc", body = "строка\nс=переводом" })
ok(r1 ~= nil and DB.Count(st) == 1, "upsert insert")
DB.Upsert(st, "doc_001", { body = "изменено" })
ok(DB.Get(st, "doc_001").body == "изменено", "upsert update keeps id, no duplicate")
DB.Upsert(st, "img_002", { name = "Фоторобот", type = "image", grm = "GRMFACE/1\n..." })
ok(DB.Count(st) == 2, "two records")

-- Сохранение и read-back.
local saved = DB.Save(st)
ok(saved == true, "save ok")
local raw = files[st.path]
ok(raw ~= nil and raw:match("^GRMDB/1\n"), "file written as GRMDB/1")
ok(raw:match("\nsig=[0-9a-f]+$") ~= nil, "sig present")
ok(DB.Save(st) == true, "save unchanged idempotent (no rewrite loop)")

-- Перезагрузка из файла (имитация рестарта).
local st2 = DB.Open("testdb")
ok(st2 == st, "same name reuses store (singleton)")
local st3 = { name = "testdb", path = st.path, records = {}, order = {}, dirty = false, lastWrite = "" }
local l = DB.Load(st3)
ok(l == true and DB.Count(st3) == 2, "reload from disk restores 2 records")
ok(DB.Get(st3, "doc_001").body == "изменено", "record value round-trips through disk")
ok(DB.Get(st3, "doc_001").name == "Приказ", "field order deterministic on reload")
ok(DB.Get(st3, "img_002").grm == "GRMFACE/1\n...", "multiline value round-trips")

-- Порча: битая сигнатура -> карантин + восстановление из backup.
files[st.path .. ".backup"] = raw -- эмулируем предыдущий сейв
local corrupt = raw:gsub("name=Приказ", "name=ВЗЛОМ", 1)
files[st.path] = corrupt
local st4 = { name = "testdb", path = st.path, records = {}, order = {}, dirty = false, lastWrite = "" }
local l4 = DB.Load(st4)
ok(l4 == true and DB.Count(st4) == 2, "corrupt main restored from backup")
ok(DB.Get(st4, "doc_001").name == "Приказ", "backup restored original value")
local quarantined = false
for p in pairs(files) do if p:find("_corrupt_") then quarantined = true end end
ok(quarantined, "corrupt file quarantined")

-- Удаление.
ok(DB.Delete(st, "img_002") == true and DB.Count(st) == 1, "delete removes record")
ok(DB.Delete(st, "nope") == false, "delete missing returns false")
DB.Save(st)
local st5 = { name = "testdb", path = st.path, records = {}, order = {}, dirty = false, lastWrite = "" }
DB.Load(st5)
ok(DB.Count(st5) == 1 and DB.Get(st5, "img_002") == nil, "deleted record not resurrected")

-- Записи хранятся МАССИВОМ (не карта с числовыми ключами).
ok(type(DB.All(st5)) == "table" and #DB.All(st5) == 1 and DB.All(st5)[1].id == "doc_001", "records are an ordered array (no numeric keys)")

print(("OSDB: %d/%d failures=%d"):format(pass, pass + fail, fail))
if fail > 0 then os.exit(1) end
