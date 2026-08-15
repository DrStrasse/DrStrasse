-- Контракт вкладки «Экономика» в /factions: информационный режим.
local function read(path)local f=assert(io.open(path,"rb"));local s=f:read("*a");f:close();return s end
local src=read("lua/autorun/sh_faction_fixes.lua")
local econ=read("lua/autorun/sh_grm_economy.lua")
local feco=read("lua/autorun/sh_grm_feco_admin.lua")
local pass,fail=0,0
local function ok(v,n)if v then pass=pass+1 print("  ok  "..n)else fail=fail+1 print("  FAIL "..n)end end
ok(src:find("local function OpenEconomyPanel",1,true)~=nil,"информационная панель определена")
ok(src:find("чистый информационный режим",1,true)~=nil,"режим явно информационный")
ok(src:find("GRM.StateBudgetGet",1,true)~=nil,"госбюджет читается через API")
ok(src:find("GRM.FactionBudgetGet",1,true)~=nil,"бюджет фракции читается через API")
ok(src:find("GRM.Economy.TaxRateGet",1,true)~=nil,"налог читается через API")
ok(src:find('tabs:AddSheet("Экономика", OpenEconomyPanel(tabs)',1,true)~=nil,"вкладка добавляется в factions")
ok(not src:find('net.Start("GRM_Eco_AdminOpen")',1,true),"вкладка не запрашивает административный дамп")
ok(src:find("Управление налогами, финансовыми перечислениями",1,true)~=nil,"управление направлено в терминалы")
ok(not feco:find("GRM_FecoAdmin_Tab",1,true),"старый модуль не дублирует вкладку")
ok(econ:find("function GRM.Economy.BuildAdminContent",1,true)~=nil,"полная админ-панель экономики сохранена отдельно")
print(("FACTIONS ECON TAB: %d/%d failures=%d"):format(pass,pass+fail,fail))
os.exit(fail>0 and 1 or 0)
