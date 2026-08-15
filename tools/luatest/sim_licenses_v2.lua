-- Регрессионный контракт лицензий v2.1: срок/баллы/приостановка/терминал.
local function read(path)local f=assert(io.open(path,"rb"));local s=f:read("*a");f:close();return s end
local s=read("lua/autorun/sh_grm_documents.lua")
local doc=read("lua/entities/grm_doc_computer/init.lua")
local traffic=read("lua/entities/grm_comp_traffic/init.lua")
local pass,fail=0,0
local function ok(v,n)if v then pass=pass+1 print("  OK   "..n)else fail=fail+1 print("  FAIL "..n)end end
ok(s:find("function DOC.NormalizeLicenseRecord",1,true)~=nil,"единая миграция лицензии")
ok(s:find("LICENSE_CIV_SEC",1,true)~=nil and s:find("LICENSE_MIL_SEC",1,true)~=nil,"сроки задаются сервером")
ok(s:find("DOC.NormalizeLicenseRecord(data, false, os.time(), true)",1,true)~=nil,"гражданская выдача нормализуется сервером")
ok(s:find("DOC.NormalizeLicenseRecord(data, true, os.time(), true)",1,true)~=nil,"военная выдача нормализуется сервером")
ok(s:find('status, suspended, points = validLicenseStatus(military), 0, 0',1,true)~=nil,"приостановка автоматически завершается")
ok(s:find("math.Clamp((tonumber(target.points)",1,true)~=nil,"баллы ограничены maxPoints")
ok(s:find('hook.Add("GRM_LicenseAddPoints"',1,true)~=nil,"интеграционный хук баллов")
ok(s:find("DOC.CanCheckLicenses(ply)",1,true)~=nil,"чужая проверка ограничена правами")
ok(s:find("local function validDocTerminal",1,true)~=nil and s:find("260 * 260",1,true)~=nil,"действия привязаны к близкому терминалу")
ok(s:find("function DOC.RegistryForOnline",1,true)~=nil,"сетевой реестр ограничен онлайн-срезом")
ok(doc:find("return false\nend\n\nfunction ENT:Use",1,true)~=nil,"компьютер документов fail-closed")
ok(doc:find("ply.GRM_DocComputerEnt = self",1,true)~=nil,"компьютер привязывает сессию")
ok(traffic:find("ply.GRM_DocComputerEnt = self",1,true)~=nil,"терминал ГАИ привязывает сессию")
ok(s:find("Баллы нарушений:",1,true)~=nil,"баллы отображаются в документе")
print(("LICENSES V2: %d/%d failures=%d"):format(pass,pass+fail,fail))
os.exit(fail>0 and 1 or 0)
