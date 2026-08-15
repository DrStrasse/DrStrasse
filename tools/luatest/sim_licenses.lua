-- Стенд лицензий: оружие + бизнес (sh_grm_documents.lua).
-- Грузит СЕРВЕРНУЮ часть с моком GMod API и проверяет категории, права выдачи
-- и логику действительности (HasValidWeaponLicense / HasValidBusinessLicense).
SERVER, CLIENT = true, false

-- ── GMod API mock ─────────────────────────────────────────────────────
function AddCSLuaFile() end
function isstring(v) return type(v) == "string" end
function istable(v) return type(v) == "table" end
function isfunction(v) return type(v) == "function" end
function IsValid(v) return v ~= nil and (not istable(v) or rawget(v, "__valid") ~= false) end
function isentity(v) return istable(v) and rawget(v, "__ent") == true end
math.Clamp = math.Clamp or function(v, a, b) if v < a then return a elseif v > b then return b else return v end end
function string.Trim(s) return tostring(s):match("^%s*(.-)%s*$") end
function string.Explode(sep, s) local out, cur = {}, ""; for i = 1, #tostring(s) do local c = tostring(s):sub(i, i); if c == sep then out[#out + 1] = cur; cur = "" else cur = cur .. c end end; out[#out + 1] = cur; return out end
function string.Split(s, sep) return string.Explode(sep, s) end
function string.StartWith(s, p) return tostring(s):sub(1, #p) == p end
function string.Left(s, n) return tostring(s):sub(1, n) end
function string.Right(s, n) return tostring(s):sub(-n) end
function table.Count(t) local n = 0; for _ in pairs(t or {}) do n = n + 1 end; return n end
function table.Copy(t) local o = {}; for k, v in pairs(t or {}) do o[k] = (type(v) == "table") and table.Copy(v) or v end; return o end
function table.HasValue(t, v) for _, x in pairs(t or {}) do if x == v then return true end end; return false end
function Color(r, g, b, a) return { r = r or 255, g = g or 255, b = b or 255, a = a or 255 } end
function CurTime() return os.clock() end
function SysTime() return os.clock() end
local jsonMem = {}
function util2() end
util = {
    AddNetworkString = function() end,
    NetworkStringToID = function() return 1 end,
    JSONToTable = function(txt, _a, _b) return jsonMem[txt] end,
    TableToJSON = function(t, _p) local k = "J" .. tostring(#jsonMem + 1); jsonMem[k] = t; return k end,
    CRC = function(s) return tostring(#s) end,
    SHA256 = function(s) return "H" .. s end,
}
local files = {}
file = {
    IsDir = function() return true end,
    CreateDir = function() end,
    Exists = function(p) return files[p] ~= nil end,
    Read = function(p) return files[p] end,
    Write = function(p, s) files[p] = s end,
}
function SetGlobalString() end
function SetGlobalInt() end
function GetGlobalString() return "" end
net = { Start = function() end, WriteString = function() end, WriteTable = function() end, WriteBool = function() end, WriteEntity = function() end, WriteInt = function() end, WriteUInt = function() end, WriteData = function() end, Send = function() end, Broadcast = function() end, Receive = function() end }
hook = { Add = function() end, Run = function() end }
timer = { Simple = function() end, Create = function() end }
concommand = { Add = function() end }
player = { GetAll = function() return {} end }
ents = { Create = function() return nil end, FindByClass = function() return {} end }
scripted_ents = { GetStored = function() return nil end }
game = { GetMap = function() return "gm_test" end }

GRM = { Identity = { CharacterKey = function(p) return (p and p.sid64 and (p.sid64 .. ":char1")) or "0:char1" end }, Notify = function() end }

-- ── Загрузка серверной части ───────────────────────────────────────────
local chunk, err = loadfile("lua/autorun/sh_grm_documents.lua")
local pass, fail = 0, 0
local function ok(v, n) if v then pass = pass + 1; print("  ok  " .. n) else fail = fail + 1; print("  FAIL " .. n) end end
ok(chunk ~= nil, "documents parses: " .. tostring(err))
if not chunk then os.exit(1) end
local ran, rerr = pcall(chunk)
ok(ran, "documents server loads: " .. tostring(rerr))
local DOC = GRM.Documents
ok(DOC ~= nil, "GRM.Documents exposed")

-- Категории/виды сформированы.
ok(#(DOC.WeaponCategories or {}) >= 4, "weapon categories defined (" .. tostring(#(DOC.WeaponCategories or {})) .. ")")
ok(#(DOC.BusinessTypes or {}) >= 5, "business types defined (" .. tostring(#(DOC.BusinessTypes or {})) .. ")")
local wIds = {}
for _, c in ipairs(DOC.WeaponCategories or {}) do wIds[c.id] = true end
ok(wIds.smooth and wIds.rifled and wIds.short, "weapon category ids smooth/rifled/short present")
local bIds = {}
for _, c in ipairs(DOC.BusinessTypes or {}) do bIds[c.id] = true end
ok(bIds.retail and bIds.logistics and bIds.factory and bIds.food, "business type ids present")

-- Шаблоны и доступ по умолчанию.
ok(istable(DOC.Templates.weaponLicense) and DOC.Templates.weaponLicense.docTitle == "ЛИЦЕНЗИЯ НА ОРУЖИЕ", "weapon license template")
ok(istable(DOC.Templates.businessLicense) and DOC.Templates.businessLicense.docTitle == "ЛИЦЕНЗИЯ НА ВЕДЕНИЕ БИЗНЕСА", "business license template")
ok(DOC.Templates.access.weaponLicenses and DOC.Templates.access.weaponLicenses["OrdnungPolizei"] == true, "weapon licenses issue default: OrdnungPolizei")
ok(DOC.Templates.access.businessLicenses and DOC.Templates.access.businessLicenses["Department of Labour and Social Protection"] == true, "business licenses issue default: labour dept")

-- Реестр имеет новые секции.
ok(DOC.Registry.weaponLicenses ~= nil and DOC.Registry.businessLicenses ~= nil, "registry has weapon/business sections")

-- Права выдачи.
local super = { IsSuperAdmin = function() return true end, GetNWString = function() return "" end }
local cop = { IsSuperAdmin = function() return false end, GetNWString = function(_, k, d) if k == "GRM_Faction" then return "OrdnungPolizei" end return d end }
local labour = { IsSuperAdmin = function() return false end, GetNWString = function(_, k, d) if k == "GRM_Faction" then return "Department of Labour and Social Protection" end return d end }
local civ = { IsSuperAdmin = function() return false end, GetNWString = function() return "" end }
ok(DOC.CanIssueWeaponLicenses(super) == true, "superadmin can issue weapon licenses")
ok(DOC.CanIssueWeaponLicenses(cop) == true, "OrdnungPolizei can issue weapon licenses")
ok(DOC.CanIssueWeaponLicenses(civ) == false, "civilian cannot issue weapon licenses")
ok(DOC.CanIssueBusinessLicenses(labour) == true, "labour dept can issue business licenses")
ok(DOC.CanIssueBusinessLicenses(cop) == false, "police cannot issue business licenses")

-- Логика действительности (лицензия на оружие).
local now = os.time()
local key = "123:char1"
DOC.Registry.weaponLicenses[key] = { number = "ЛО-1", categories = { smooth = true, short = true }, status = "Действительна", expiry = now + 3600 * 24 * 30 }
local v1, s1 = DOC.HasValidWeaponLicense(key)
ok(v1 == true, "valid weapon license passes")
local v2, s2 = DOC.HasValidWeaponLicense(key, "rifled")
ok(v2 == false and s2 == "Нет категории rifled", "missing category rejected: " .. tostring(s2))
local v3, s3 = DOC.HasValidWeaponLicense(key, "short")
ok(v3 == true, "present category passes")
local v4, s4 = DOC.HasValidWeaponLicense("nobody:char1")
ok(v4 == false and s4 == "Нет лицензии", "no license rejected")

DOC.Registry.weaponLicenses[key].expiry = now - 100
local v5, s5 = DOC.HasValidWeaponLicense(key)
ok(v5 == false and s5 == "Срок истёк", "expired weapon license rejected")
DOC.Registry.weaponLicenses[key].expiry = now + 3600 * 24 * 30
DOC.Registry.weaponLicenses[key].status = "Приостановлена"
DOC.Registry.weaponLicenses[key].suspendedUntil = now + 3600
local v6, s6 = DOC.HasValidWeaponLicense(key)
ok(v6 == false and s6:find("Приостановлена") ~= nil, "suspended weapon license rejected")

-- Логика действительности (лицензия на бизнес).
DOC.Registry.businessLicenses[key] = { number = "БЛ-1", businessType = "retail", status = "Действительна", expiry = now + 3600 * 24 * 365 }
local b1, b2 = DOC.HasValidBusinessLicense(key)
ok(b1 == true, "valid business license passes")
local b3, b4 = DOC.HasValidBusinessLicense(key, "factory")
ok(b3 == false and b4 == "Не тот вид деятельности", "wrong business type rejected")
DOC.Registry.businessLicenses[key].status = "Отозвана"
local b5, b6 = DOC.HasValidBusinessLicense(key)
ok(b5 == false and b6 == "Отозвана", "revoked business license rejected")

print(("LICENSES: %d/%d failures=%d"):format(pass, pass + fail, fail))
if fail > 0 then os.exit(1) end
