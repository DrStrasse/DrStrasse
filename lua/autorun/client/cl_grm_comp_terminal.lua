--[[--------------------------------------------------------------------
    GRM Comp Terminal — клиентская часть общих ответов терминалов
    Полиции Порядка и Полевой жандармерии.

    Раньше терминалы работали «вслепую»: команда уходила на сервер и
    никакого подтверждения не приходило (Д5). Теперь сервер отвечает
    результатом, а реестр обновляется без переоткрытия окна.
----------------------------------------------------------------------]]

if SERVER then return end

net.Receive("GRM_CompTerminal_Result", function()
    local ok  = net.ReadBool()
    local msg = net.ReadString()
    if msg == "" then return end

    notification.AddLegacy(msg, ok and NOTIFY_GENERIC or NOTIFY_ERROR, 5)
    surface.PlaySound(ok and "buttons/button14.wav" or "buttons/button10.wav")

    -- Успешное действие меняет реестр — просим свежий срез.
    if ok and IsValid(GRM_CompTerminal_ActiveFrame) then
        net.Start("GRM_CompTerminal_Act")
            net.WriteString("refresh")
            net.WriteString(GRM_CompTerminal_ActiveJur or "civil")
            net.WriteString("")
            net.WriteString("")
            net.WriteUInt(0, 32)
            net.WriteString("")
        net.SendToServer()
    end
end)

net.Receive("GRM_CompTerminal_Fines", function()
    local wanted = net.ReadTable() or {}
    local fines  = net.ReadTable() or {}

    local frame = GRM_CompTerminal_ActiveFrame
    if not IsValid(frame) then return end

    if isfunction(frame._fillFines) then frame._fillFines(fines) end
    if isfunction(frame._fillWanted) then frame._fillWanted(wanted) end
end)
