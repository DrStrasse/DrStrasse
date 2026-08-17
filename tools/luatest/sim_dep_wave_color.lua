-- /dep и /d должны отображаться единым бордово-тёмно-красным сегментом.
local f=assert(io.open("lua/autorun/sh_factions.lua","rb"));local s=f:read("*a");f:close()
local fail=0;local function ok(c,n)if c then print("  ok  "..n)else fail=fail+1 print("  FAIL "..n)end end
local block=s:match('net%.Receive%(NET_DEP_MSG, function%(%)'..'(.-)'..'end%)') or ""
ok(block:find('net.ReadUInt(8) net.ReadUInt(8) net.ReadUInt(8)',1,true)~=nil,"старый RGB читается для совместимости протокола")
ok(block:find('Color(170, 45, 60)',1,true)~=nil,"волна принудительно бордово-тёмно-красная")
ok(block:find('"[Волна] " .. tostring(msg or "")',1,true)~=nil,"префикс и сообщение объединены в один сегмент")
ok(block:find('Color(r, g, b)',1,true)==nil,"цвет фракции не применяется")
ok(s:find('lower:find("^/dep%s+")',1,true)~=nil and s:find('lower:find("^/d%s+")',1,true)~=nil and s:find('net.Start(NET_DEP)',1,true)~=nil,"/dep и /d используют исправленный NET_DEP")
print(("DEP WAVE COLOR: 5 checks, failures=%d"):format(fail));os.exit(fail==0 and 0 or 1)
