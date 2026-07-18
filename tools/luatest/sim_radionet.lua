-- Симуляция сервера GMod для sh_grm_radionet.lua (Код 85)
-- Стенд доказывает: топологию сети, покрытие/качество, цепочки связи,
-- маршрутизацию голоса (эфир/громкая связь/мегафон), «радио-искажение»,
-- автоперсистентность и доступ к chat-командам БЕЗ GMod.
----------------------------------------------------------------------

string.Trim = function(s) s = tostring(s or ""); return (s:gsub("^%s*(.-)%s*$", "%1")) end
table.Count = function(t) local n = 0 for _ in pairs(t or {}) do n = n + 1 end return n end

local H = { hooks = {}, timers = {}, netlog = {}, concommands = {}, chatlog = {} }
_G._SIM = H
local realPrint = print
local function P(...) realPrint(...) end

function istable(x) return type(x) == "table" end
function isstring(x) return type(x) == "string" end
function IsValid(o) return o ~= nil and o ~= false and not o.__removed end

-- вектора --------------------------------------------------------------
local VMT = {}
VMT.__index = function(self, k)
  if k == "DistToSqr" then return function(s, o) local dx,dy,dz = s.x-o.x, s.y-o.y, s.z-o.z return dx*dx+dy*dy+dz*dz end end
  if k == "Angle" then return function() return { p = 0, y = 0, r = 0 } end end
  return nil
end
VMT.__add = function(a, b) return V(a.x + (b.x or 0), a.y + (b.y or 0), a.z + (b.z or 0)) end
VMT.__sub = function(a, b) return V(a.x - (b.x or 0), a.y - (b.y or 0), a.z - (b.z or 0)) end
VMT.__mul = function(a, b)
  if type(a) == "number" then return V(a * b.x, a * b.y, a * b.z) end
  return V(a.x * b, a.y * b, a.z * b)
end
function V(x, y, z) return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, VMT) end
Vector = V
Angle = function(p, y, r) return { p = p or 0, y = y or 0, r = r or 0 } end

-- реестр энтити ---------------------------------------------------------
local REG = { byClass = {}, byIdx = {}, nextIdx = 1 }
local function mkEnt(class, x, y, z)
  local e = { __class = class, __pos = V(x, y, z), __nw = {}, __idx = REG.nextIdx, __ang = Angle(0,0,0), __snd = {} }
  REG.nextIdx = REG.nextIdx + 1
  local mt
  mt = { __index = function(self, k)
    if k == "GetPos" then return function() return self.__pos end end
    if k == "SetPos" then return function(_, p) self.__pos = p end end
    if k == "GetAngles" then return function() return self.__ang end end
    if k == "SetAngles" then return function(_, a) self.__ang = a end end
    if k == "GetClass" then return function() return self.__class end end
    if k == "EntIndex" then return function() return self.__idx end end
    local nwget = k:match("^GetNW(%w+)$")
    if nwget then return function(_, key, def) local v = self.__nw[key] if v == nil then return def end return v end end
    local nwset = k:match("^SetNW(%w+)$")
    if nwset then return function(_, key, val) self.__nw[key] = val end end
    if k == "EmitSound" then return function(_, s) self.__snd[#self.__snd + 1] = s end end
    if k == "Spawn" then return function() end end
    if k == "Activate" then return function() end end
    if k == "GetPhysicsObject" then return function() return { EnableMotion = function() end } end end
    if k == "Remove" then return function() self.__removed = true
      local list = REG.byClass[self.__class] or {}
      for i, x in ipairs(list) do if x == self then table.remove(list, i) break end end
      REG.byIdx[self.__idx] = nil end end
    return nil
  end }
  e = setmetatable(e, mt)
  REG.byClass[class] = REG.byClass[class] or {}
  table.insert(REG.byClass[class], e)
  REG.byIdx[e.__idx] = e
  return e
end

ents = { FindByClass = function(c) return REG.byClass[c] or {} end,
         Create = function(c) return mkEnt(c, 0, 0, 0) end }
Entity = function(i) return REG.byIdx[i] end

-- игроки -----------------------------------------------------------------
local function mkPly(id, x, isSAdmin)
  local p = { __pos = V(x, 0, 0), __idx = id, __sa = isSAdmin and true or false }
  p = setmetatable(p, { __index = function(self, k)
    if k == "GetPos" then return function() return self.__pos end end
    if k == "SetPos" then return function(_, v) self.__pos = v end end
    if k == "EntIndex" then return function() return self.__idx end end
    if k == "IsSuperAdmin" then return function() return self.__sa end end
    if k == "SteamID" then return function() return "STEAM_0:1:" .. tostring(self.__idx) end end
    if k == "SteamID64" then return function() return "76561198000000" .. tostring(100 + self.__idx) end end
    if k == "PrintMessage" then return function(_, _, txt) H.chatlog[#H.chatlog + 1] = tostring(txt) end end
    if k == "GetShootPos" then return function() return self.__pos end end
    if k == "GetAimVector" then return function() return V(1, 0, 0) end end
    if k == "Nick" then return function() return "Игрок" .. tostring(self.__idx) end end
    return nil
  end })
  return p
end

-- окружение GMod ---------------------------------------------------------
local FILES = {}
local JSON_HOLD = nil
util = {
  AddNetworkString = function() end,
  JSONToTable = function(t, a, b) return JSON_HOLD end,
  TableToJSON = function(t) JSON_HOLD = t return "TBL" end,
  TraceLine = function(td) return H.trace end,
}
file = { Read = function(p) return FILES[p] end, Write = function(p, d) FILES[p] = d end,
         Exists = function(p) return FILES[p] ~= nil end, IsDir = function() return true end, CreateDir = function() end }
hook = { Add = function(name, id, fn) H.hooks[name] = H.hooks[name] or {} H.hooks[name][id] = fn end,
         Run = function() end }
timer = { Create = function(name, d, r, fn) H.timers[name] = fn end,
          Simple = function(_, fn) fn() end }
player = { GetAll = function() return H.players or {} end }
game = { GetMap = function() return "gm_simtown" end }
net = { Start = function(m) H.netlog.cur = { msg = m, f = {} } end,
        WriteUInt = function(v) H.netlog.cur.f[#H.netlog.cur.f + 1] = v end,
        WriteString = function(v) H.netlog.cur.f[#H.netlog.cur.f + 1] = v end,
        WriteBool = function(v) H.netlog.cur.f[#H.netlog.cur.f + 1] = v and "T" or "F" end,
        Broadcast = function() H.netlog[#H.netlog + 1] = H.netlog.cur H.netlog.cur = nil end,
        Send = function() H.netlog.cur = nil end,
        Receive = function() end }
concommand = { Add = function() end }
HUD_PRINTTALK = 3
TT = 0
CurTime = function() return TT end
AddCSLuaFile = function() end

-- грузим модуль ----------------------------------------------------------
SERVER = true CLIENT = false
dofile("lua/autorun/sh_grm_radionet.lua")
local RN = GRM.RadioNet
RN.Recompute()

-- фреймворк ---------------------------------------------------------------
local checks, failed = 0, 0
local function ok(cond, name)
  checks = checks + 1
  if cond then P("  ok " .. tostring(checks) .. ". " .. name)
  else failed = failed + 1 P("  FAIL " .. tostring(checks) .. ". " .. name) end
end
local function approx(a, b, eps) return math.abs(a - b) < (eps or 0.01) end

P("== 1. Пустой мир: сети нет ==")
ok(#RN._coverage == 0, "кругов покрытия нет")
ok(RN.QualityAt(V(0, 0, 0)) == 0, "качество в точке = 0")
ok(not RN.CoveredAt(V(0, 0, 0)), "покрытия нет")

P("== 2. Одна активная стойка = слабый репитер ==")
local rack = mkEnt("grm_server_rack", 0, 0, 0)
rack:SetNWBool("GRM_RN_On", true)
RN.Recompute()
ok(#RN._activeRacks == 1, "1 активная стойка")
ok(#RN._coverage == 1, "1 круг покрытия (стойка)")
ok(RN.QualityAt(V(0, 0, 0)) == 1, "в центре качество 1.0")
ok(approx(RN.QualityAt(V(1000, 0, 0)), 1 - (1000 - 660) / 540, 0.01), "на 1000 юн качество ~0.37")
ok(RN.CoveredAt(V(1000, 0, 0)), "1000 юн — покрыто")
ok(not RN.CoveredAt(V(1200, 0, 0)), "на краю (1200) — не покрыто")

P("== 3. Антенна без стойки рядом — мертва ==")
local ant = mkEnt("grm_antenna", 3000, 0, 0)
RN.Recompute()
ok(RN._antsTotal == 1 and RN._antsLinked == 0, "антенна есть, связи нет")
ok(RN.QualityAt(V(3000, 0, 0)) == 0, "вокруг глухой антенны сигнала нет")

P("== 4. Стойка №2 активирует антенну — усиление ==")
local rack2 = mkEnt("grm_server_rack", 3500, 0, 0)
rack2:SetNWBool("GRM_RN_On", true)
RN.Recompute()
ok(RN._antsLinked == 1, "антенна связана")
ok(RN.CoveredAt(V(5500, 0, 0)), "зона усиления покрыта (5500)")
ok(approx(RN.QualityAt(V(5500, 0, 0)), 1 - (2500 - 1760) / 1440, 0.01), "качество 5500 ~0.49")
ok(not RN.CoveredAt(V(6000, 0, 0)), "у самого края (6000) — уже не берёт")

P("== 5. Стойка выключена → антенна глохнет ==")
rack2:SetNWBool("GRM_RN_On", false)
RN.Recompute()
ok(RN._antsLinked == 0, "связь антенны пропала")
ok(not RN.CoveredAt(V(5500, 0, 0)), "усиленная зона обесточена")
rack2:SetNWBool("GRM_RN_On", true)
RN.Recompute()

P("== 6. Цепочка микрофон → передатчик → стойка ==")
local st = mkEnt("grm_radio_station", 500, 0, 0)       -- рядом со стойкой
local mic = mkEnt("grm_broadcast_mic", 900, 0, 0)      -- рядом с передатчиком
RN.Recompute()
ok(RN.MicLink(mic) == 2, "микрофон в сети через передатчик")
local micFar = mkEnt("grm_broadcast_mic", 9000, 0, 0)
ok(RN.MicLink(micFar) == 0, "голый микрофон — link 0")
rack:SetNWBool("GRM_RN_On", false)
RN.Recompute()
ok(RN.MicLink(mic) == 1, "стойка погашена → передатчик вне сети (link 1)")
rack:SetNWBool("GRM_RN_On", true)
RN.Recompute()
ok(RN.MicLink(mic) == 2, "стойка вернулась → link 2")

P("== 7. Громкоговорители: активность от сети ==")
local spk1 = mkEnt("grm_loudspeaker", 600, 0, 0)   -- у стойки
local spk2 = mkEnt("grm_loudspeaker", 5500, 0, 0)  -- в зоне антенны
local spk3 = mkEnt("grm_loudspeaker", 20000, 0, 0) -- в глуши
RN.Recompute()
ok(RN.SpeakerActive(spk1), "громкоговоритель у стойки — в сети")
ok(RN.SpeakerActive(spk2), "громкоговоритель в покрытии антенны — в сети")
ok(not RN.SpeakerActive(spk3), "громкоговоритель в глуши — мёртв")

P("== 8. Гейт ручной рации ==")
local sA = mkPly(101, 0, false)       -- в покрытии стойки
local sB = mkPly(102, 5500, false)    -- в покрытии антенны (далеко!)
local sC = mkPly(103, 20000, false)   -- глушь
local sD = mkPly(104, 20800, false)   -- глушь, 800 юн от sC
H.players = { sA, sB, sC, sD }
ok(RN.RadioPairOK(sA, sB), "оба в сети на разных концах — частота ловится")
ok(not RN.RadioPairOK(sA, sC), "второй в глуши — связи нет")
ok(RN.RadioPairOK(sC, sD), "оба в глуши, но в 800 юн — прямая дальность")

P("== 9. Маршрут голоса: радиоэфир ==")
local speaker = mkPly(201, 900, false)
speaker._grmBCMic = mic
mic.BCLive = true mic.BCSpeaker = speaker
mic:SetNWBool("GRM_BC_PA", false)
local radio = mkEnt("grm_radio", 5000, 0, 0)
radio:SetNWBool("GRM_BC_On", true)
radio:SetNWInt("GRM_BC_Mic", mic:EntIndex())
local lst1 = mkPly(202, 5100, false)  -- у приёмника (в покрытии антенны)
local lst2 = mkPly(203, 100000, false) -- приёмников рядом нет
local lst3 = mkPly(204, 1100, false)   -- рядом с ведущим (200 юн)
H.players = { sA, sB, sC, sD, speaker, lst1, lst2, lst3 }
RN.Recompute()
TT = 0
local c1, h1 = RN.VoiceRoute(lst1, speaker)
ok(c1 == true and h1 == false, "у приёмника в покрытии — эфир слышно (не 3D)")
local c2 = RN.VoiceRoute(lst2, speaker)
ok(c2 == false, "в глуши без приёмника — заглушён")
local c3 = RN.VoiceRoute(lst3, speaker)
ok(c3 == nil, "рядом с ведущим — решает локальный голос (nil)")
radio:SetPos(V(50000, 0, 0))
radio:SetNWBool("GRM_BC_On", true)
local c4 = RN.VoiceRoute(lst1, speaker)
ok(c4 == false, "приёмник уехал из покрытия → слушатель глух")
radio:SetPos(V(5000, 0, 0))

P("== 10. Маршрут: микрофон вне сети не душит локальный голос ==")
speaker._grmBCMic = micFar
micFar.BCLive = true micFar.BCSpeaker = speaker
micFar:SetNWBool("GRM_BC_PA", false)
local c5 = RN.VoiceRoute(lst2, speaker)
ok(c5 == nil, "микрофон голый — VoiceRoute не вмешивается (nil)")

P("== 11. Маршрут: ГРОМКАЯ СВЯЗЬ через громкоговорители ==")
speaker._grmBCMic = mic
mic:SetNWBool("GRM_BC_PA", true)
local lstPA = mkPly(205, 1500, false) -- 500 юн от громкоговорителя(1000)…
H.players = { speaker, lstPA, lst2 }
local spk4 = mkEnt("grm_loudspeaker", 1000, 0, 0)  -- в покрытии стойки
RN.Recompute()
RN.PAQuality = 1 -- детерминизм стенда (нет выпадений)
local c6, h6 = RN.VoiceRoute(lstPA, speaker)
ok(c6 == true and h6 == false, "рядом с сетевым громкоговорителем — голос усилен (не 3D)")
ok(speaker._rnTxSeen ~= nil and speaker._rnFx == "pa", "штамп передачи «pa» выставлен")
spk4:SetPos(V(50000, 0, 0))
local c7 = RN.VoiceRoute(lstPA, speaker)
ok(c7 == false, "громкоговорителей в сети нет — громкая связь заглохла")
spk4:Remove()

P("== 12. Маршрут: мегафон ==")
local ms = mkPly(206, 0, false)
ms._rnMegaOn = true
local mNear = mkPly(207, 1500, false)
local mFar = mkPly(208, 2000, false)
local savedQ = RN.MegaQuality
RN.MegaQuality = 1 -- детерминизм: без выпадений
local c8, h8 = RN.VoiceRoute(mNear, ms)
ok(c8 == true and h8 == false, "мегафон: 1500 юн — слышно усиленно")
local c9 = RN.VoiceRoute(mFar, ms)
ok(c9 == nil, "мегафон: 2000 юн — вне досягаемости (nil)")
ms._rnMegaOn = false
local c10 = RN.VoiceRoute(mNear, ms)
ok(c10 == nil, "мегафон выключен — обычный голос")
RN.MegaQuality = savedQ

P("== 13. «Радио-искажение»: выпадения детерминированы и ∝ качеству ==")
local drops, total = 0, 200
for s = 1, total do
  TT = s * 0.2
  if RN.Drop(77, 0.5) then drops = drops + 1 end
end
ok(drops >= 60 and drops <= 140, "q=0.5 → выпадений " .. drops .. "/200 (≈50%)")
TT = 42.0
local d1 = RN.Drop(5, 0.6)
local d2 = RN.Drop(5, 0.6)
ok(d1 == d2, "тот же срез времени — то же решение")
ok(RN.Drop(5, 1.0) == false, "q=1.0 — никогда не рвёт")
ok(RN.Drop(5, 0) == true, "q=0 — всегда обрыв")

P("== 14. FX-рассылка: щелчки/треск ==")
TT = 100
speaker._rnTxSeen = TT speaker._rnFx = "radio"
H.netlog = {}
H.players = { speaker }
H.timers["GRM_RN_FxWatch"]()
ok(#H.netlog >= 1 and H.netlog[1].msg == "GRM_RN_FX" and H.netlog[1].f[3] == "T", "старт передачи → net GRM_RN_FX (on)")
TT = 103
H.netlog = {}
H.timers["GRM_RN_FxWatch"]()
ok(#H.netlog >= 1 and H.netlog[1].f[3] == "F", "замолчал → net GRM_RN_FX (off)")

P("== 15. Чат-команды и доступ ==")
local admin = mkPly(300, 0, true)
local user = mkPly(301, 0, false)
H.players = { admin, user }
H.trace = { Hit = true, HitPos = V(2400, 0, 0), HitNormal = V(0, 0, 1), Entity = nil }
local n0 = #REG.byClass["grm_server_rack"]
ok(RN.HandleChat(user, "/rack_add") == true and #REG.byClass["grm_server_rack"] == n0, "обычный игрок не ставит стойки (команда поглощена, энтити нет)")
ok(RN.HandleChat(admin, "/rack_add") == true and #REG.byClass["grm_server_rack"] == n0 + 1, "суперадмин поставил стойку (/rack_add)")
ok(RN.HandleChat(user, "/rn_status") == true, "/rn_status у игрока — поглощён")
ok(RN.HandleChat(admin, "/rn_status") == true, "/rn_status у суперадмина — поглощён")
local foundStatus = false
for _, m in ipairs(H.chatlog) do if m:find("диагностика") then foundStatus = true break end end
ok(foundStatus, "диагностика напечатана в чат")
ok(RN.HandleChat(admin, "/rn_unknown") == false, "чужие команды не трогаем")

P("== 16. Автоперсистентность (рестарт-эквивалент) ==")
local cnt0 = table.Count(RN.Persist or {})
ok(cnt0 >= 1, "записи персиста живут (" .. tostring(cnt0) .. ")")
local racksBefore = #REG.byClass["grm_server_rack"]
H.hooks["InitPostEntity"]["GRM_RN_Restore"]()
ok(#REG.byClass["grm_server_rack"] == racksBefore, "антидубль: при работающих стойках восстановление ничего не создало")
-- сносим именно ПЕРСИСТНУЮ стойку (поставленную /rack_add на 2400)
local persistedRack = nil
for _, e in ipairs(REG.byClass["grm_server_rack"]) do
  if e:GetPos().x == 2400 then persistedRack = e break end
end
ok(persistedRack ~= nil, "персистная стойка найдена в мире")
persistedRack:Remove()
H.hooks["InitPostEntity"]["GRM_RN_Restore"]()
ok(#REG.byClass["grm_server_rack"] == racksBefore, "после потери стойки восстановление её вернуло")
local restoredRack = nil
for _, e in ipairs(REG.byClass["grm_server_rack"]) do
  if e:GetPos().x == 2400 and e:GetNWBool("GRM_RN_On", false) then restoredRack = e break end
end
ok(restoredRack ~= nil, "воскрешенная стойка стоит на старом месте и включена")

P("== 17. NW-зеркала для 3D2D ==")
RN.Recompute()
ok(mic:GetNWInt("GRM_RN_Link", -9) == 2, "микрофон: NW link = 2")
ok(st:GetNWBool("GRM_RN_Online", false) == true, "передатчик: NW online")
ok(ant:GetNWBool("GRM_RN_Linked", false) == true, "антенна: NW linked")

P("")
P("ИТОГ: " .. tostring(checks) .. " проверок, провалов: " .. tostring(failed))
if failed > 0 then os.exit(1) end
P("SIM_RADIONET OK")
