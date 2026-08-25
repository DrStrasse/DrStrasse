
------------------------------------------------------------------
-- КЛИЕНТСКИЙ РЕДАКТОР ПРАВИЛ БОДИГРУПП
------------------------------------------------------------------
local FB = FB or GRM.FactionBodygroups
if CLIENT and FB then
    local function combo(parent, items, get, onsel)
        local cb = vgui.Create("DComboBox", parent)
        cb:SetValue("—")
        cb.OnSelect = function(_, _, v) if onsel then onsel(v) end end
        for _, it in ipairs(items or {}) do cb:AddChoice(it, it, it == get) end
        return cb
    end

    net.Receive(FB.NetOpen, function()
        if IsValid(FB._editor) then FB._editor:Remove() end
        local f = vgui.Create("DFrame")
        FB._editor = f
        f:SetSize(720, 560) f:Center() f:MakePopup() f:SetTitle("")
        f:ShowCloseButton(false)
        f.Paint = function(_, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(16, 20, 30, 250))
            draw.SimpleText("Ограничения бодигрупп по фракциям/ролям", "DermaLarge", 14, 12, Color(240, 200, 90))
        end
        local close = vgui.Create("DButton", f) close:SetPos(680, 8) close:SetSize(30, 26) close:SetText("X")
        close.DoClick = function() f:Close() end

        local function lab(parent, txt, x, y)
            local l = vgui.Create("DLabel", parent); l:SetPos(x, y); l:SetText(txt); l:SizeToContents()
            l:SetTextColor(Color(210, 215, 225)); return l
        end

        -- Поля выбора фракции / роли / модели / индекса группы
        local facE = vgui.Create("DTextEntry", f) facE:SetPos(14, 50) facE:SetSize(220, 26)
        facE:SetPlaceholderText("ключ фракции (например police)")
        local roleE = vgui.Create("DTextEntry", f) roleE:SetPos(242, 50) roleE:SetSize(150, 26)
        roleE:SetPlaceholderText("роль (all = все)") roleE:SetValue("all")
        local mdlE = vgui.Create("DTextEntry", f) mdlE:SetPos(400, 50) mdlE:SetSize(306, 26)
        mdlE:SetPlaceholderText("*  —  любая модель, либо путь модели")

        local scroll = vgui.Create("DScrollPanel", f)
        scroll:SetPos(14, 110) scroll:SetSize(692, 380)

        local saveBtn = vgui.Create("DButton", f) saveBtn:SetPos(14, 508) saveBtn:SetSize(200, 36)
        saveBtn:SetText("Сохранить все") saveBtn:SetTextColor(color_white)
        saveBtn.Paint = function(s,w,h) draw.RoundedBox(6,0,0,w,h,s:IsHovered() and Color(60,160,90) or Color(40,120,70)) end

        local function curKey()
            return (facE:GetValue() or "") .. "|" .. (roleE:GetValue() or "all") .. "|" .. string.lower(mdlE:GetValue() or "*")
        end

        local function rebuild()
            scroll:Clear()
            local k = curKey()
            local groups = FB.Rules[k] or {}
            local rowY = 0
            for gi = 0, 31 do
                local r = groups[gi]
                if r then
                    local p = vgui.Create("DPanel", scroll)
                    p:Dock(TOP) p:SetTall(34) p:DockMargin(0,0,0,4)
                    p.Paint = function(_,w,h) draw.RoundedBox(6,0,0,w,h,Color(28,34,46)) end
                    local lock = vgui.Create("DCheckBoxLabel", p)
                    lock:SetPos(10, 7) lock:SetText("Заблокировать") lock:SetTextColor(color_white)
                    lock:SetValue(r.lock == true)
                    lock.OnChange = function(_, v) r.lock = v end
                    local forceL = lab(p, "Принудительно:", 180, 9)
                    local force = vgui.Create("DNumberWang", p)
                    force:SetPos(300, 6) force:SetSize(80, 22) force:SetMin(0) force:SetMax(31)
                    force:SetValue(tonumber(r.force) or 0)
                    force.OnValueChanged = function(_, v) r.force = math.floor(v) end
                    local del = vgui.Create("DButton", p) del:SetPos(620, 5) del:SetSize(60, 24)
                    del:SetText("Убрать") del:SetTextColor(color_white)
                    del.Paint = function(s,w,h) draw.RoundedBox(4,0,0,w,h, s:IsHovered() and Color(170,60,60) or Color(120,50,50)) end
                    del.DoClick = function() FB.Rules[k][gi] = nil rebuild() end
                end
            end
            local add = vgui.Create("DButton", scroll)
            add:Dock(TOP) add:SetTall(32) add:SetText("+ Добавить правило для группы")
            add:SetTextColor(color_white)
            add.Paint = function(s,w,h) draw.RoundedBox(6,0,0,w,h, s:IsHovered() and Color(50,90,150) or Color(40,60,110)) end
            add.DoClick = function()
                Derma_StringRequest("Индекс группы", "Числовой индекс бодигруппы (0..31)", "", function(txt)
                    local gi = tonumber(txt) if not gi then return end
                    FB.Rules[k] = FB.Rules[k] or {}
                    FB.Rules[k][gi] = { lock = true }
                    rebuild()
                end)
            end
        end

        for _, e in ipairs({ facE, roleE, mdlE }) do e.OnChange = rebuild end
        facE.OnEnter = rebuild; roleE.OnEnter = rebuild; mdlE.OnEnter = rebuild

        saveBtn.DoClick = function()
            net.Start(FB.NetSave) net.WriteTable(FB.Rules or {}) net.SendToServer()
            surface.PlaySound("buttons/button15.wav")
        end

        rebuild()
    end)
end
