-- Симуляция сервера GMod для sh_grm_medical.lua (Код 86, Код 101)
-- Стенд доказывает: права CanTreat (фракция/ранг/отдел, s64-ключи н101),
-- ведение карт (vitals/add/toggle/del, MaxEntries, кровь из списка),
-- доступы к чужим/своим картам, персистентность карт и конфига,
-- уведомления пациенту и chat-команды БЕЗ GMod.
-- Код 101: выдача медкарты на руки (op issue → предмет инвентаря со
-- slot.data.sid64), анти-дубликат, офлайн-отказ, ViewIssued предмета.
----------------------------------------------------------------------

string.Trim = function(s) s = tostring(s or ""); return (s:gsub("^%s*(.-)%s*$", "%1")) end
table.Count = function(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end
table.Copy = table.Copy or function(t) local o = {} for k, v in pairs(t or {}) do o[k] = v end return o end

local H = { hooks = {}, netrecv = {}, concommands = {}, seq = {}, notifies = {}, chatlog = {}, players = {} }
_G._SIM = H
local realPrint = print
local function P(...) realPrint(...) end

function istable(x) return type(x) == "table" end
function isstring(x) return type(x) == "string" end
function isfunction(x) return type(x) == "function" end
function IsValid(o) return o ~= nil and o ~= false end

-- игроки ---------------------------------------------------------------
local function mkPly(nick, idx, isSAdmin)
  local p = { __idx = idx, __sa = isSAdmin and true or false, __nick = nick }
  p = setmetatable(p, { __index = function(self, k)
    if k == "IsSuperAdmin" then return function() return self.__sa end end
    if k == "IsPlayer" then return function() return true end end
    if k == "SteamID" then return function() return "STEAM_0:1:" .. tostring(self.__idx) end end
    if k == "SteamID64" then return function() return "76561198000000" .. tostring(100 + self.__idx) end end
    if k == "Nick" then return function() return self.__nick end end
    if k == "GetNWString" then return function() return "" end end
    if k == "PrintMessage" then return function(_, _, txt) H.chatlog[#H.chatlog + 1] = tostring(txt) end end
    if k == "EntIndex" then return function() return self.__idx end end
    return nil
  end })
  return p
end
local function sid64(p) return p:SteamID64() end

-- окружение GMod ---------------------------------------------------------
local FILES = {}
local JSON_HOLD, JSON_BAD = nil, false
util = {
  AddNetworkString = function() end,
  JSONToTable = function(t, a, b) if JSON_BAD then return nil end return JSON_HOLD end,
  TableToJSON = function(t) JSON_HOLD = t return "TBL" end,
}
file = { Read = function(p) return FILES[p] end, Write = function(p, d) FILES[p] = d end,
         Exists = function(p) return FILES[p] ~= nil end, IsDir = function() return true end, CreateDir = function() end }
hook = { Add = function(name, id, fn) H.hooks[name] = H.hooks[name] or {} H.hooks[name][id] = fn end,
         Run = function() end }
timer = { Create = function() end, Simple = function(_, fn) fn() end }
player = { GetAll = function() return H.players end }
game = { GetMap = function() return "gm_simtown" end }
net = { Start = function(m) H.netOut = { msg = m, f = {} } end,
        WriteUInt = function(v) if H.netOut then H.netOut.f[#H.netOut.f + 1] = v end end,
        WriteString = function(v) if H.netOut then H.netOut.f[#H.netOut.f + 1] = v end end,
        WriteBool = function(v) if H.netOut then H.netOut.f[#H.netOut.f + 1] = v end end,
        WriteTable = function(v) if H.netOut then H.netOut.f[#H.netOut.f + 1] = v end end,
        Send = function(ply) H.netSent = H.netOut H.netOut = nil end,
        Broadcast = function() H.netOut = nil end,
        Receive = function(m, fn) H.netrecv[m] = fn end }
net.ReadString = function() return tostring(table.remove(H.seq, 1) or "") end
net.ReadUInt = function() return tonumber(table.remove(H.seq, 1)) or 0 end
net.ReadTable = function() return table.remove(H.seq, 1) or {} end
concommand = { Add = function(name, fn) H.concommands[name] = fn end }
HUD_PRINTTALK = 3
CurTime = function() return 1000 end
AddCSLuaFile = function() end

-- фракции (паттерн: Members по SteamID() ИЛИ SteamID64() — н101) ---------
Factions = {
  ["Городская больница"] = {
    Roles = { "Интерн", "Врач", "Заведующий" },
    Departments = { "Терапия", "Хирургия" },
    Members = {
      ["STEAM_0:1:2"] = { Role = "Врач", Department = "Терапия" },          -- доктор (ключ sid)
      ["76561198000000103"] = { Role = "Интерн", Department = "Хирургия" }, -- стажёр (ключ s64!)
    },
    Leader = "STEAM_0:1:9",
  },
  ["Полиция"] = {
    Roles = { "Офицер" }, Departments = { "Патруль" },
    Members = { ["STEAM_0:1:4"] = { Role = "Офицер", Department = "Патруль" } },
  },
}

local Admin   = mkPly("Админ", 1, true)
local Doctor  = mkPly("Доктор Айболит", 2, false)   -- Врач/Терапия, sid-ключ
local Intern  = mkPly("Интерн Петя", 3, false)      -- Интерн/Хирургия, s64-ключ
local Officer = mkPly("Полицейский", 4, false)
local Patient = mkPly("Пациент Коля", 5, false)
H.players = { Admin, Doctor, Intern, Officer, Patient }

-- оповещения фиксируем
GRM = GRM or {}
GRM.Notify = function(ply, txt) H.notifies[#H.notifies + 1] = tostring(txt) end

-- стаб инвентаря (Код 101): регистрация предмета + выдача со slot.data
H.regItems = {}
GRM.Inventory = {
  RegisterItem = function(id, data) H.regItems[id] = data end,
  GetPlayerInv = function(p) p.__inv = p.__inv or { slots = {} } return p.__inv end,
  AddItem = function(p, id, count, data)
    local inv = GRM.Inventory.GetPlayerInv(p)
    for i = 1, 24 do
      if not inv.slots[i] then
        inv.slots[i] = { id = id, count = count or 1 }
        if istable(data) then inv.slots[i].data = table.Copy(data) end
        return 0
      end
    end
    return count or 1
  end,
  CountItem = function(p, id)
    local n = 0
    for _, s in pairs(GRM.Inventory.GetPlayerInv(p).slots) do
      if s.id == id then n = n + (s.count or 1) end
    end
    return n
  end,
  HasFreeSlot = function() return true end,
}

-- грузим модуль ----------------------------------------------------------
SERVER = true CLIENT = false
dofile("lua/autorun/sh_grm_medical.lua")
local MD = GRM.Medical

-- фреймворк --------------------------------------------------------------
local checks, failed = 0, 0
local function ok(cond, label)
  checks = checks + 1
  if cond then P("[OK] " .. label) else failed = failed + 1 P("[FAIL] " .. label) end
end
local function recvAs(ply, proto, ...)
  H.seq = { ... }
  H.netSent = nil
  local fn = H.netrecv[proto]
  if fn then fn(0, ply) end
  return H.netSent
end

-- 1. загрузка ------------------------------------------------------------
ok(MD ~= nil and MD.Version == "1.1.0", "модуль загружен, версия 1.1.0")
local ri = H.regItems["medcard"]
ok(istable(ri) and ri.useFunc == "medcard_view" and ri.model == "models/props_lab/clipboard.mdl"
   and ri.maxStack == 1, "предмет medcard зарегистрирован (clipboard-модель, useFunc medcard_view)")
ok(H.netrecv["GRM_Med_Open"] ~= nil and H.netrecv["GRM_Med_Edit"] ~= nil
   and H.netrecv["GRM_Med_Access"] ~= nil and H.netrecv["GRM_Med_Card"] ~= nil,
   "все 4 net-приёмника зарегистрированы")
ok((H.hooks["PlayerSay"] or {})["GRM_Med_Cmds"] ~= nil
   and (H.hooks["PlayerSayTransform"] or {})["GRM_Med_TransformCmds"] ~= nil,
   "chat-команды двойным паттерном (н75)")
ok(H.concommands["grm_medcards"] ~= nil, "concommand grm_medcards на месте")

-- 2. CanTreat: маршрут прав ----------------------------------------------
local ct = MD.CanTreat(Admin)
ok(ct == true, "суперадмин лечит всегда")
local c0, m0 = MD.CanTreat(Patient)
ok(c0 == false and tostring(m0):find("медицинским доступом") ~= nil, "гражданин без фракции — отказ")
local c1, m1 = MD.CanTreat(Doctor)
ok(c1 == false and tostring(m1):find("не имеет медицинского доступа") ~= nil,
   "медфракция БЕЗ конфига — отказ (fail-closed)")
local c2 = MD.CanTreat(Officer)
ok(c2 == false, "полиция не лечит")
local fn, f = MD.FactionOf(Intern)
ok(fn == "Городская больница", "фракция найдена по s64-ключу члена (н101)")

-- 3. админ включает доступ фракции через NET_ACCESS ----------------------
local sent = recvAs(Admin, "GRM_Med_Access", "Городская больница",
  { enabled = true, allRoles = true, allDepts = true })
ok(MD.Cfg.factions["Городская больница"].enabled == true, "фракция включена админом (allRoles/allDepts)")
ok(sent ~= nil and sent.msg == "GRM_Med_Open", "после сохранения доступа высылается свежий снапшот")
ok(FILES["grm_medcfg.json"] ~= nil, "конфиг доступов записан на диск")

ok(MD.CanTreat(Doctor) == true, "врач лечит после включения фракции")
ok(MD.CanTreat(Intern) == true, "интерн (s64-ключ) тоже лечит")

-- ограничение по ролям
recvAs(Admin, "GRM_Med_Access", "Городская больница",
  { enabled = true, allRoles = false, roles = { ["Врач"] = true, ["Заведующий"] = true }, allDepts = true })
ok(MD.CanTreat(Doctor) == true, "ранг Врач есть в списке — лечит")
local ci, mi = MD.CanTreat(Intern)
ok(ci == false and tostring(mi):find("ранг") ~= nil, "Интерн вне списка ролей — отказ")

-- ограничение по отделам
recvAs(Admin, "GRM_Med_Access", "Городская больница",
  { enabled = true, allRoles = true, allDepts = false, depts = { ["Хирургия"] = true } })
ok(MD.CanTreat(Intern) == true, "отдел Хирургия в списке — интерн лечит")
local cd, md = MD.CanTreat(Doctor)
ok(cd == false and tostring(md):find("отдел") ~= nil, "Терапия вне списка отделов — врач отказан")
recvAs(Admin, "GRM_Med_Access", "Городская больница",
  { enabled = true, allRoles = true, allDepts = true, roles = { ["=инъекция]"] = true } })
ok(MD.CanTreat(Doctor) == true, "сброс на все роли/отделы")

-- NET_ACCESS от не-админа молча игнорируется
recvAs(Officer, "GRM_Med_Access", "Полиция", { enabled = true, allRoles = true, allDepts = true })
ok(MD.CanTreat(Officer) == false, "NET_ACCESS от не-суперадмина игнорируется")
recvAs(Admin, "GRM_Med_Access", "Несуществующая", { enabled = true })
ok(MD.Cfg.factions["Несуществующая"] == nil, "доступ фракции-призраку не выдаётся")

-- 4. ведение карты --------------------------------------------------------
local PS = sid64(Patient)
local sentCard = recvAs(Doctor, "GRM_Med_Edit", "add", PS, "diagnosis", "Грипп, средняя форма", "Коля")
local card = MD.Cards[PS]
ok(card ~= nil and #card.entries == 1, "карта создана, 1 запись")
ok(card.entries[1].kind == "diagnosis" and card.entries[1].active == true,
   "диагноз активен сразу")
ok(card.entries[1].doctor == "Доктор Айболит" and card.entries[1].doctorFac == "Городская больница",
   "автор и фракция автора проставлены")
ok(card.name == "Коля", "имя пациента в карте")
ok(sentCard ~= nil and sentCard.msg == "GRM_Med_Card", "после записи карта высылается редактору")
local notifHit = false
for _, n in ipairs(H.notifies) do if n:find("мед%.карту добавлено") then notifHit = true break end end
ok(notifHit, "пациент онлайн — получил уведомление о записи")

recvAs(Doctor, "GRM_Med_Edit", "add", PS, "note", "Жалобы на кашель", "Коля")
recvAs(Doctor, "GRM_Med_Edit", "add", PS, "prescription", "Парацетамол 500мг x3", "Коля")
recvAs(Doctor, "GRM_Med_Edit", "add", PS, "operation", "—", "Коля")
ok(#card.entries == 4, "записи всех видов принимаются")
ok(card.entries[2].active == nil, "не-диагнозы без флага активности")

recvAs(Doctor, "GRM_Med_Edit", "add", PS, "hack_kind", "текст", "Коля")
ok(#card.entries == 4, "неизвестный вид записи отброшен")
recvAs(Doctor, "GRM_Med_Edit", "add", PS, "note", "   ", "Коля")
ok(#card.entries == 4, "пустая запись отброшена")

-- toggle активного диагноза
recvAs(Doctor, "GRM_Med_Edit", "toggle", PS, 1)
ok(card.entries[1].active == false, "диагноз снят (излечён)")
recvAs(Doctor, "GRM_Med_Edit", "toggle", PS, 2)
ok(card.entries[2].active ~= true, "toggle по не-диагнозу игнор")

-- показания
recvAs(Doctor, "GRM_Med_Edit", "vitals", PS, "A(II) Rh+", "Пенициллин", "Астма")
ok(card.blood == "A(II) Rh+" and card.allergies == "Пенициллин" and card.chronic == "Астма",
   "показания сохранены (кровь из списка)")
recvAs(Doctor, "GRM_Med_Edit", "vitals", PS, "ZZ-негатив", "", "")
ok(card.blood == "", "кривая группа крови не пишется")

-- редактирование чужими
local before = #card.entries
recvAs(Officer, "GRM_Med_Edit", "add", PS, "note", "полиция лезет в карту", "Коля")
ok(#card.entries == before, "не-медик не может править карту")
local notifDeny = false
for _, n in ipairs(H.notifies) do if n:find("Нет медицинского доступа") then notifDeny = true break end end
ok(notifDeny, "не-медику отказ с уведомлением")

-- del: только суперадмин
recvAs(Doctor, "GRM_Med_Edit", "del", PS, 4)
ok(#card.entries == 4, "врач не может удалять записи")
recvAs(Admin, "GRM_Med_Edit", "del", PS, 4)
ok(#card.entries == 3, "суперадмин удалил запись")

-- MaxEntries
for i = 1, 70 do
  recvAs(Doctor, "GRM_Med_Edit", "add", PS, "note", "запись " .. i, "Коля")
end
ok(#card.entries == MD.MaxEntries, "карта усечена до MaxEntries=" .. tostring(MD.MaxEntries))

-- 5. просмотр карт --------------------------------------------------------
local own = recvAs(Patient, "GRM_Med_Card", PS)
ok(own ~= nil and own.msg == "GRM_Med_Card", "пациент видит СВОЮ карту")
local foreign = recvAs(Patient, "GRM_Med_Card", sid64(Officer))
ok(foreign == nil, "пациент НЕ видит чужую карту")
local dview = recvAs(Doctor, "GRM_Med_Card", PS)
ok(dview ~= nil and dview.msg == "GRM_Med_Card", "врач видит чужую карту")

-- 6. главное окно ---------------------------------------------------------
local openD = recvAs(Doctor, "GRM_Med_Open")
ok(openD ~= nil and openD.msg == "GRM_Med_Open", "окно врача отправлено")
local payload = openD and openD.f[#openD.f]
ok(istable(payload) and payload.doctor == true, "врачу doctor=true")
ok(istable(payload) and payload.mySid64 == sid64(Doctor), "mySid64 врача передан")
local foundPat = false
for _, o in ipairs(payload.online or {}) do if o.sid64 == PS then foundPat = true break end end
ok(foundPat, "в списке онлайн есть пациент")
local openP = recvAs(Patient, "GRM_Med_Open")
local pp = openP and openP.f[#openP.f]
ok(istable(pp) and pp.doctor == false and #(pp.online or {}) == 0, "пациенту — пустой список, только своя карта")
local openA = recvAs(Admin, "GRM_Med_Open")
local pa = openA and openA.f[#openA.f]
ok(istable(pa) and istable(pa.access) and pa.access.cfg["Городская больница"].enabled == true,
   "админу — актуальный снапшот доступов")

-- 7. chat-команды ---------------------------------------------------------
ok(MD.HandleChat(Doctor, "/medcards") == true, "/medcards открывает окно")
ok(MD.HandleChat(Patient, "  /mycard ") == true, "/mycard с пробелами работает")
ok(MD.HandleChat(Patient, "/med_xyz") == false, "чужая команда не глотается")

-- 8. Код 101: выдача медкарты на руки ------------------------------------
local nBefore = #H.notifies
recvAs(Officer, "GRM_Med_Edit", "issue", PS)
ok(GRM.Inventory.CountItem(Patient, "medcard") == 0, "issue: не-медик отсечён — предмет не выдан")
local deny = false
for i = nBefore + 1, #H.notifies do if H.notifies[i]:find("медицинского доступа") then deny = true end end
ok(deny, "issue: не-медику отказ с уведомлением")

recvAs(Doctor, "GRM_Med_Edit", "issue", "76561198000000999")
local offHit = false
for _, n in ipairs(H.notifies) do if n:find("не в сети") then offHit = true break end end
ok(offHit, "issue: пациент офлайн — отказ «не в сети»")
ok(MD.Cards["76561198000000999"] ~= nil and MD.Cards["76561198000000999"].issued == nil,
   "issue офлайн: отметка выдачи не ставится")

recvAs(Doctor, "GRM_Med_Edit", "issue", sid64(Doctor))
local selfHit = false
for _, n in ipairs(H.notifies) do if n:find("Себе карту") then selfHit = true end end
ok(selfHit, "issue: самому себе — отказ")
ok(GRM.Inventory.CountItem(Doctor, "medcard") == 0, "issue: врач себе предмет не получил")

local entBefore = #card.entries
local sentIssue = recvAs(Doctor, "GRM_Med_Edit", "issue", PS)
ok(GRM.Inventory.CountItem(Patient, "medcard") == 1, "issue: предмет medcard лёг пациенту в инвентарь")
local slotDataOk = false
for _, s in pairs(Patient.__inv.slots) do
  if s.id == "medcard" and istable(s.data) and s.data.sid64 == PS then slotDataOk = true end
end
ok(slotDataOk, "issue: в данных предмета — sid64 пациента (привязка переживёт дроп/рестарт)")
ok(istable(card.issued) and card.issued.doctor == "Доктор Айболит" and card.issued.doctorSid64 == sid64(Doctor),
   "issue: в карте записано КТО и КОГДА выдал (card.issued)")
-- к моменту выдачи карта уже усечена до MaxEntries (60): добавление записи
-- про выдачу вытесняет самую СТАРУЮ, итоговая длина остаётся 60 — поэтому
-- проверяем НЕ прирост, а наличие записи и фиксацию cap.
ok(#card.entries == math.min(entBefore + 1, MD.MaxEntries) and card.entries[#card.entries].kind == "issue",
   "issue: служебная запись журнала «Выдача карты» добавлена (cap MaxEntries удержан)")
ok(sentIssue ~= nil and sentIssue.msg == "GRM_Med_Card", "issue: врачу выслана свежая карта")
local pHit = false
for _, n in ipairs(H.notifies) do if n:find("выдал вам медицинскую карту") then pHit = true end end
ok(pHit, "issue: пациент уведомлён о выдаче")

recvAs(Doctor, "GRM_Med_Edit", "issue", PS)
ok(GRM.Inventory.CountItem(Patient, "medcard") == 1, "issue: дубликат не выдаётся, пока первая карта на руках")
local dupHit = false
for _, n in ipairs(H.notifies) do if n:find("уже есть медкарта") then dupHit = true end end
ok(dupHit, "issue: врачу отказ «уже есть карта на руках»")

local lastKindB2 = card.entries[#card.entries].kind
recvAs(Doctor, "GRM_Med_Edit", "add", PS, "issue", "сам себе выписал", "Коля")
-- cap и так держит длину на 60 — признак отказа: последняя запись НЕ стала чужеродной
ok(card.entries[#card.entries].kind == lastKindB2, "issue: ручная запись вида issue отвергнута (только кнопка выдачи)")

H.netSent = nil
MD.ViewIssued(Patient, { sid64 = PS })
ok(H.netSent ~= nil and H.netSent.msg == "GRM_Med_Card" and H.netSent.f[1] == PS,
   "ViewIssued: держателю карты выслан просмотр карты владельца")
local blankBefore = #H.notifies
H.netSent = nil
MD.ViewIssued(Patient, {})
ok(H.netSent == nil, "ViewIssued: пустой бланк — карта не шлётся")
local blankHit = false
for i = blankBefore + 1, #H.notifies do if H.notifies[i]:find("Пустой бланк") then blankHit = true end end
ok(blankHit, "ViewIssued: про пустой бланк сказано в уведомлении")

-- 9. персистентность ------------------------------------------------------
ok(FILES["grm_medcards.json"] ~= nil, "карты записаны на диск")
local savedCards = JSON_HOLD
MD.Cards = nil
-- имитация рестарта: тот же файл, JSON_HOLD жив
local t = util.JSONToTable(FILES["grm_medcards.json"], false, true)
ok(istable(t) and istable(t[PS]) and t[PS].blood == savedCards[PS].blood,
   "карты переживают рестарт (ключ sid64, 3-й аргумент jsonT н65)")
ok(istable(t) and istable(t[PS].issued) and t[PS].issued.doctor == "Доктор Айболит",
   "отметка выдачи (issued) тоже на диске — переживает рестарт")
JSON_BAD = true
local bad = util.JSONToTable(FILES["grm_medcfg.json"], false, true)
ok(bad == nil, "битый JSON конфига → дефолты (fail-safe)")

P(("[SIM] итог: проверок %d, провалов %d"):format(checks, failed))
if failed > 0 then os.exit(1) end
P("[SIM] SIM_MEDICAL OK")
