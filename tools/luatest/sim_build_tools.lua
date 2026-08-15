-- Контракт кастомных GRM-инструментов и жёсткой блокировки stock stools.
local function read(path)local f=assert(io.open(path,"rb"));local s=f:read("*a");f:close();return s end
local pass,fail=0,0
local function ok(v,n)if v then pass=pass+1 print("  OK   "..n)else fail=fail+1 print("  FAIL "..n)end end
local q=read("lua/autorun/sh_grm_qmenu.lua")
local catalog=q:match("QM%.ToolCatalog%s*=%s*(%b{})") or q
local core=read("lua/autorun/sh_grm_build_tools.lua")
local ids={"grm_camera","grm_light","grm_lamp","grm_material","grm_colour"}
for _,id in ipairs(ids)do
 local path="lua/weapons/gmod_tool/stools/"..id..".lua"
 local s=read(path)
 ok(s:find('TOOL.Category = "GRM"',1,true)~=nil,id..": категория GRM")
 ok(q:find('{ id = "'..id..'"',1,true)~=nil,id..": присутствует в Q-каталоге")
 ok(q:find(id.." = {",1,true)~=nil,id..": ручная схема Q-меню")
 ok(s:find("BuildTools.CanEdit",1,true)~=nil,id..": проверка владения")
end
for _,id in ipairs({"camera","light","lamp","material","colour","color"})do
 ok(core:find(id.." = true",1,true)~=nil,"stock "..id.." в жёстком запрете")
end
ok(q:find("QM.DisabledStockTools[tool] == true",1,true)~=nil,"сервер проверяет hard deny до admin bypass")
ok(not catalog:find('{ id = "camera"',1,true),"stock camera убран из каталога")
ok(not catalog:find('{ id = "light"',1,true),"stock light убран из каталога")
ok(not catalog:find('{ id = "lamp"',1,true),"stock lamp убран из каталога")
ok(not catalog:find('{ id = "material"',1,true),"stock material убран из каталога")
ok(not catalog:find('{ id = "colour"',1,true),"stock colour убран из каталога")
ok(core:find('PermData.Extract["gmod_light"]',1,true)~=nil,"перм-данные источника света")
ok(core:find('PermData.Extract["gmod_lamp"]',1,true)~=nil,"перм-данные лампы")
ok(core:find('RegisterClass("gmod_cameraprop"',1,true)~=nil,"камеру можно закрепить")
print(("BUILD TOOLS: %d/%d failures=%d"):format(pass,pass+fail,fail))
os.exit(fail>0 and 1 or 0)
