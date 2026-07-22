--[[--------------------------------------------------------------------
    grm_food_stove — cl_init.lua (клиент плиты, Код 110)
    3D2D-табличка над плитой: состояние, блюдо, остаток секунд, лоток.
    Окно — cl_grm_food_kitchen.lua по [E].
----------------------------------------------------------------------]]

include("shared.lua")

surface.CreateFont("GRMStove_T", { font = "Roboto", size = 30, weight = 800, extended = true })
surface.CreateFont("GRMStove_S", { font = "Roboto", size = 22, weight = 600, extended = true })

function ENT:Draw()
    self:DrawModel()
    if not GRM or not GRM.FoodKitchen then return end
    local lp = LocalPlayer()
    if not IsValid(lp) then return end
    if self:GetPos():DistToSqr(lp:GetPos()) > 350 * 350 then return end

    local ang = self:GetAngles()
    local maxs = self:OBBMaxs()
    local pos = self:GetPos() + ang:Up() * ((maxs and maxs.z or 40) + 14)
    local state = self:GetStoveState()
    local lines
    if state == 1 then
        local rec = GRM.FoodKitchen.Recipe(self:GetStoveRecipe())
        local left = math.max(0, (self:GetStoveFinish() or 0) - os.time())
        lines = {
            { txt = "ПЛИТА", col = Color(255, 210, 120) },
            { txt = "«" .. tostring(rec and rec.name or "…") .. "» — " .. tostring(left) .. " сек", col = Color(255, 240, 200) },
        }
    else
        local n = self:GetStoveReady() or 0
        lines = {
            { txt = "ПЛИТА", col = Color(255, 210, 120) },
            { txt = n > 0 and ("Готово блюд: " .. tostring(n) .. " — [E]") or "Свободна — [E]", col = n > 0 and Color(140, 255, 170) or Color(200, 210, 225) },
        }
    end

    cam.Start3D2D(pos, Angle(0, lp:EyeAngles().y - 90, 90), 0.06)
        local w = 360
        draw.RoundedBox(8, -w / 2, -20, w, 24 + #lines * 30 - 4, Color(12, 16, 22, 215))
        surface.SetDrawColor(255, 180, 90, 170)
        surface.DrawOutlinedRect(-w / 2, -20, w, 24 + #lines * 30 - 4, 1)
        for i, ln in ipairs(lines) do
            draw.SimpleText(ln.txt, i == 1 and "GRMStove_T" or "GRMStove_S", 0, -20 + i * 30 - 20, ln.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    cam.End3D2D()
end
