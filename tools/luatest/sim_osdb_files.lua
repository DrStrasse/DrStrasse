-- Интеграция: файлы GRM NET OS пишутся в свою базу GRMDB (sv_grm_osdb.lua)
-- через sh_grm_electronics.lua; JSON остаётся легаси-зеркалом.
SERVER, CLIENT = true, false

-- GMod API mock (как в sim_electronics_runtime.lua).
function AddCSLuaFile() end
function isstring(v) return type(v) == "string" end
function istable(v) return type(v) == "table" end
function IsValid(v) return type(v) == "table" and v.valid ~= false end
function string.Trim(s) return tostring(s):match("^%s*(.-)%s*$") end
math.Clamp = function(v, a, b) return math.max(a, math.min(b, v)) end
table.Copy = function(t) local o = {}; for k, v in pairs(t or {}) do o[k] = type(v) == "table" and table.Copy(v) or v end; return o end
local V = {}; V.__index = V
function Vector(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V) end
function V:DistToSqr(o) local x, y, z = self.x - o.x, self.y - o.y, self.z - o.z; return x * x + y * y + z * z end
function Angle(p, y, r) return { p = p or 0, y = y or 0, r = r or 0 } end
local TT = 100
function CurTime() return TT end
function SysTime() return TT end
game = { GetMap = function() return "gm_test" end }
local files = {}
file = { IsDir = function() return true end, CreateDir = function() end, Exists = function(p) return files[p] ~= nil end, Read = function(p) return files[p] end, Write = function(p, s) files[p] = s end }
local json = {}
util = { AddNetworkString = function() end, CRC = function(s) return tostring(#s) .. "x" end, SHA256 = function(s) return "H" .. s end, TableToJSON = function(t) local k = "J" .. (#json + 1); json[k] = table.Copy(t); return k end, JSONToTable = function(s) return table.Copy(json[s]) end, IsValidModel = function() return true end }
net = { Receive = function() end, Start = function() end, WriteBool = function() end, WriteString = function() end, WriteTable = function() end, WriteUInt = function() end, WriteData = function() end, WriteEntity = function() end, Send = function() end, Broadcast = function() end }
hook = { Add = function() end, Run = function() end }
timer = { Create = function() end, Simple = function() end }
concommand = { Add = function() end }
scripted_ents = { GetStored = function() return true end }
player = { GetAll = function() return {} end }
ents = { FindByClass = function() return {} end, Create = function() return { valid = false } end }
constraint = {}
GRM = { Identity = { CharacterKey = function() return "765:char1" end } }

local function loadmod(path)
  local chunk, err = loadfile(path)
  if not chunk then return nil, err end
  local ok, rerr = pcall(chunk)
  if not ok then return nil, rerr end
  return true
end

local pass, fail = 0, 0
local function ok(v, n) if v then pass = pass + 1; print("  ok  " .. n) else fail = fail + 1; print("  FAIL " .. n) end end

local a1, ea = loadmod("lua/autorun/sh_grm_osformat.lua")
local a2, eb = loadmod("lua/autorun/server/sv_grm_osdb.lua")
local a3, ec = loadmod("lua/autorun/sh_grm_electronics.lua")
ok(a1 == true and a2 == true and a3 == true, "modules load: " .. tostring(ea or eb or ec))
local E = GRM.Electronics
ok(E ~= nil and GRM.OSDB ~= nil and GRM.OSFormat ~= nil, "GRM.Electronics + OSDB + OSFormat present")

E.LoadDB()
ok(E.EnsureAdminTelecom ~= nil, "electronics bootstraps")

-- Создаём файл и сохраняем — должен попасть в GRMDB.
E.Files["pc"] = {
  file_x = { id = "file_x", name = "Приказ", owner = "admintelecom", category = "doc", content = "# Приказ\n- пункт 1\n", imagePath = "", desc = "", grm = "", created = os.time(), updated = os.time(), sharedWith = {} },
}
local saved = E.SaveDB()
ok(saved == true, "SaveDB ok")
local grmdb = files["grm_os/netfiles.grmdb"]
ok(grmdb ~= nil and grmdb:match("^GRMDB/1\n"), "files written to own GRMDB")
ok(grmdb:find("name=Приказ", 1, true) ~= nil, "file name persisted in GRMDB")
ok(grmdb:find("category=doc", 1, true) ~= nil and grmdb:find("dev=pc", 1, true) ~= nil, "category + device persisted in GRMDB")
ok(grmdb:find("content=", 1, true) ~= nil, "content persisted (GRMML source)")

-- JSON остаётся легаси-зеркалом (accounts/mailbox).
local legacy = files[E.DBFile]
ok(legacy ~= nil, "legacy JSON mirror still written")

-- Имитация перезагрузки: JSON-зеркало пустое, GRMDB авторитетен.
E.Files = {}
files[E.DBFile] = nil -- «рестарт» без легаси-зеркала
E.LoadDB()
ok(E.Files["pc"] and E.Files["pc"]["file_x"] ~= nil, "files restored from GRMDB after reload")
local f = E.Files["pc"]["file_x"]
ok(f.name == "Приказ" and f.category == "doc" and f.content == "# Приказ\n- пункт 1\n", "file fields round-trip through GRMDB")
ok(f.sharedWith and type(f.sharedWith) == "table", "sharedWith reconstructed")

print(("OSDB_FILES: %d/%d failures=%d"):format(pass, pass + fail, fail))
if fail > 0 then os.exit(1) end
