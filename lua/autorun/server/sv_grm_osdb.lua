--[[
  GRM OS Database — СВОЯ БАЗА GRM NET OS (формат GRMDB/1).

  Хранилище записей в СВОЁМ текстовом формате (не JSON): версия, записи
  МАССИВОМ (не карта с числовыми ключами — урок находки 65), контрольная
  сумма FNV-1a всего тела (GRM.OSFormat), read-back после записи,
  backup на каждую запись и карантин битого файла.

  Сервер пишет; модуль чистый (без GMod-вызовов внутри логики), чтобы
  гоняться в LuaJIT-стенде `tools/luatest/sim_osdb.lua`.

  Формат файла:
    GRMDB/1
    db=<имя базы>
    ---R
    id=<id>
    <field>=<значение>
    ...
    ---R
    id=<id2>
    ...
    sig=<hex fnv-1a всего тела>
]]
if SERVER then
  GRM = GRM or {}
  GRM.OSDB = GRM.OSDB or {}
  local DB = GRM.OSDB
  DB.Version = "1.0.0"

  local OSF = GRM.OSFormat
  local function checksum(s) return OSF and OSF.Checksum(s) or 0 end
  local function esc(s) return OSF and OSF.Escape(s) or tostring(s or "") end
  local function unesc(s) return OSF and OSF.Unescape(s) or tostring(s or "") end
  local function lines(text)
    local out = {}
    for ln in tostring(text or ""):gmatch("[^\r\n]+") do out[#out + 1] = ln end
    return out
  end
  local function now() return os.time() end

  local STORES = {} -- path -> store

  local function newStore(name)
    local path = "grm_os/" .. tostring(name) .. ".grmdb"
    return { name = name, path = path, records = {}, order = {}, dirty = false, lastWrite = "" }
  end

  -- ── Сериализация ──────────────────────────────────────────────────────
  function DB.Encode(st)
    local body = { "GRMDB/1", "db=" .. esc(st.name or "") }
    for _, r in ipairs(st.order) do
      body[#body + 1] = "---R"
      local keys = {}
      for k in pairs(r) do if k ~= "id" then keys[#keys + 1] = k end end
      table.sort(keys)
      body[#body + 1] = "id=" .. esc(tostring(r.id or ""))
      for _, k in ipairs(keys) do
        body[#body + 1] = k .. "=" .. esc(tostring(r[k]))
      end
    end
    local text = table.concat(body, "\n")
    return text .. "\nsig=" .. (OSF and OSF.ToHex(checksum(text)) or "")
  end

  -- ── Разбор ────────────────────────────────────────────────────────────
  function DB.Decode(st, raw)
    local ls = lines(raw)
    if #ls < 2 then return nil, "слишком короткий файл" end
    local magic, ver = ls[1]:match("^(%a+)/(%d+)$")
    if magic ~= "GRMDB" then return nil, "не GRMDB" end
    if tonumber(ver) ~= 1 then return nil, "неподдерживаемая версия " .. tostring(ver) end
    local body = table.concat(ls, "\n", 1, #ls - 1)
    if OSF then
      local ok, err = OSF.VerifySig(body, ls[#ls])
      if not ok then return nil, err end
    end
    local order = {}
    local cur
    for i = 2, #ls - 1 do
      local ln = ls[i]
      if ln == "---R" then
        cur = {}
        order[#order + 1] = cur
      elseif cur then
        local k, v = ln:match("^([%w_]+)=(.*)$")
        if k then cur[k] = unesc(v) end
      end
    end
    local records = {}
    for _, r in ipairs(order) do if r.id and r.id ~= "" then records[r.id] = r end end
    st.records, st.order = records, order
    return true
  end

  function DB.Quarantine(st, raw, err)
    local nm = tostring(st.path or "db"):gsub("[^%w_.-]", "_")
    local q = "grm_os/" .. nm .. "_corrupt_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
    if file.Write then file.Write(q, raw or "") end
  end

  function DB.Load(st)
    st.records, st.order = {}, {}
    local raw = (file.Exists and file.Exists(st.path, "DATA") and file.Read(st.path, "DATA")) or nil
    if not raw or raw == "" then return false end
    local ok, err = DB.Decode(st, raw)
    if ok then
      st.dirty = false
      st.lastWrite = raw
      return true
    end
    DB.Quarantine(st, raw, err)
    local bk = (file.Exists and file.Exists(st.path .. ".backup", "DATA") and file.Read(st.path .. ".backup", "DATA")) or nil
    if bk and bk ~= "" then
      local ok2 = DB.Decode(st, bk)
      if ok2 then st.dirty = true; st.lastWrite = bk; return true end
    end
    return false
  end

  function DB.Save(st)
    local raw = DB.Encode(st)
    if raw == st.lastWrite then return true end
    if file.CreateDir then file.CreateDir("grm_os") end
    local old = (file.Exists and file.Exists(st.path, "DATA") and file.Read(st.path, "DATA")) or nil
    if old and old ~= "" then file.Write(st.path .. ".backup", old) end
    file.Write(st.path, raw)
    if file.Read and (file.Read(st.path, "DATA") or "") ~= raw then return false end -- read-back
    st.lastWrite = raw
    st.dirty = false
    return true
  end

  -- ── CRUD (записи — массивом в памяти, доступ по строковому id) ────────
  function DB.Upsert(st, id, fields)
    id = tostring(id)
    local r = st.records[id]
    if not r then
      r = { id = id }
      st.records[id] = r
      st.order[#st.order + 1] = r
    end
    local changed = false
    for k, v in pairs(fields or {}) do
      if k ~= "id" and k ~= "updated" then
        if r[k] ~= v then r[k] = v; changed = true end
      end
    end
    if not r.updated or changed then r.updated = now() end -- не трогаем updated при повторном upsert
    st.dirty = true
    return r
  end

  function DB.Get(st, id) return st.records[tostring(id)] end

  function DB.Delete(st, id)
    id = tostring(id)
    local r = st.records[id]
    if not r then return false end
    st.records[id] = nil
    for i, x in ipairs(st.order) do
      if x == r then table.remove(st.order, i); break end
    end
    st.dirty = true
    return true
  end

  function DB.Count(st) return #st.order end
  function DB.All(st) return st.order end

  -- ── Открытие/управление сторами ───────────────────────────────────────
  function DB.Open(name)
    local st = newStore(name)
    if STORES[st.path] then return STORES[st.path] end
    STORES[st.path] = st
    DB.Load(st)
    return st
  end

  function DB.CloseAll()
    for _, st in pairs(STORES) do if st.dirty then DB.Save(st) end end
  end

  -- Автосброс по dirty-флагу (в игре; в стенде timer замочен).
  if timer and timer.Create then
    timer.Create("GRM_OSDB_Flush", 5, 0, function()
      for _, st in pairs(STORES) do if st.dirty then DB.Save(st) end end
    end)
  end

  print("[GRM OSDB] server v" .. DB.Version .. " loaded (GRMDB/1)")
end
