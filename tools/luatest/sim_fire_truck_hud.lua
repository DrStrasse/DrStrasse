--[[ Контракт строки пожарной машины внизу экрана (заказ владельца 21.08:
     «показывает воду и пену, хотя мы далеко от машины»).
     Проверяем по исходнику: строка привязана к близости или посадке,
     а не к вечной NW-ссылке «моя машина».
     Запуск: ./.luabuild/lj/src/luajit tools/luatest/sim_fire_truck_hud.lua ]]
local pass, fail = 0, 0
local function ok(v, n, extra)
    if v then pass = pass + 1 print("  ok   " .. n)
    else fail = fail + 1 print("  FAIL " .. n .. "  " .. tostring(extra or "")) end
end
local f = assert(io.open("lua/autorun/sh_grm_fire_truck.lua", "rb"))
local src = f:read("*a") f:close()
local function has(n) return src:find(n, 1, true) ~= nil end

print("\n=== СТРОКА ПОЖАРКИ ===")
ok(has('CreateClientConVar("grm_fire_hud_dist"'), "дальность показа настраивается конваром")
ok(has("local seated = false"), "посадка в машину учитывается отдельно")
ok(has("if not seated then"), "для стоящего рядом действует проверка расстояния")
ok(has("ply:GetPos():Distance(veh:GetPos()) <= maxDist"), "считается реальная дистанция до машины")
ok(has("holdingFireGear(ply)"), "со стволом или рукавом в руках строка тоже видна")
ok(has("math.Clamp(hudDist:GetInt(), 80, 4000)"), "дальность зажата в разумных пределах")
ok(not has([[local veh = ply:GetNWEntity("GRM_FireMyTruck")
        if not IsValid(veh) or not veh:GetNWBool("GRM_FireTruck", false) then
            local seat = ply:GetVehicle()]]),
    "старая ветка «есть ссылка — рисуем всегда» убрана")

print(("\nFIRE TRUCK HUD: %d/%d, провалов: %d"):format(pass, pass + fail, fail))
if fail > 0 then os.exit(1) end
