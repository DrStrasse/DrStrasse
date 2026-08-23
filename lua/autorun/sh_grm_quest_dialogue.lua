--[[--------------------------------------------------------------------
    GRM Quest Dialogue v1.0 — серверный разговор у NPC.

    Паттерн Talksmith (SYSTEMS 2): клиент шлёт индекс ответа,
    сервер проверяет условия, выполняет действие, отдаёт следующую реплику.
    Флаги персонажа живут отдельно от прогресса квеста.
----------------------------------------------------------------------]]
if SERVER then AddCSLuaFile() end

GRM = GRM or {}
GRM.Quests = GRM.Quests or {}
local Q = GRM.Quests
Q.Flags = Q.Flags or {}

local NET_NODE = "GRM_Quest_DlgNode"
local NET_PICK = "GRM_Quest_DlgPick"

local function trim(s, n)
    s = string.Trim(tostring(s or ""))
    if GRM.Utf8Sub then return GRM.Utf8Sub(s, n or 160) end
    return string.sub(s, 1, n or 160)
end

local function charKey(ply)
    if Q.CharacterKey then return Q.CharacterKey(ply) end
    if GRM.Identity and GRM.Identity.CharacterKey then return GRM.Identity.CharacterKey(ply) end
    return tostring(ply:SteamID64()) .. ":char1"
end

function Q.GetFlag(plyOrKey, name)
    local key = IsValid(plyOrKey) and charKey(plyOrKey) or tostring(plyOrKey or "")
    name = string.lower(trim(name, 64))
    if key == "" or name == "" then return false end
    local bag = Q.Flags[key]
    return istable(bag) and bag[name] == true
end

function Q.SetFlag(plyOrKey, name, on)
    local key = IsValid(plyOrKey) and charKey(plyOrKey) or tostring(plyOrKey or "")
    name = string.lower(trim(name, 64))
    if key == "" or name == "" then return false end
    Q.Flags[key] = Q.Flags[key] or {}
    if on then Q.Flags[key][name] = true else Q.Flags[key][name] = nil end
    if SERVER and Q.SaveFlags then Q.SaveFlags() end
    return true
end

--- cond: "" | "flag:x" | "!flag:x" | "item:id" | "money:N" | "fac:Name" | "done:quest" | "active:quest"
function Q.EvalCondition(ply, cond)
    cond = string.Trim(tostring(cond or ""))
    if cond == "" then return true end
    local kind, rest = cond:match("^(!?[%w_]+):(.+)$")
    if not kind then return true end
    rest = string.Trim(rest)
    if kind == "flag" then return Q.GetFlag(ply, rest) end
    if kind == "!flag" then return not Q.GetFlag(ply, rest) end
    if kind == "item" then
        local n = GRM.Inventory and GRM.Inventory.CountItem and tonumber(GRM.Inventory.CountItem(ply, rest)) or 0
        return n > 0
    end
    if kind == "money" then
        local need = math.max(0, tonumber(rest) or 0)
        local have = (GRM.GetBalance and GRM.GetBalance(ply) or 0)
            + ((GRM.Economy and GRM.Economy.BankBalance) and GRM.Economy.BankBalance(ply) or 0)
        return have >= need
    end
    if kind == "fac" then
        return string.lower(ply:GetNWString("GRM_Faction", "") or "") == string.lower(rest)
    end
    if kind == "done" or kind == "active" then
        local p = Q.GetProgress and Q.GetProgress(ply, rest)
        if kind == "done" then return istable(p) and p.status == "completed" end
        return istable(p) and p.status == "active"
    end
    return true
end

if SERVER then
    util.AddNetworkString(NET_NODE)
    util.AddNetworkString(NET_PICK)

    Q.FlagFile = (Q.DataDir or "grm_quests") .. "/flags.json"

    function Q.SaveFlags()
        if not Q.DataDir then return false end
        if not file.IsDir(Q.DataDir, "DATA") then file.CreateDir(Q.DataDir) end
        local recs = {}
        for key, flags in pairs(Q.Flags) do
            if istable(flags) and next(flags) then recs[#recs + 1] = { key = key, flags = flags } end
        end
        local ok, raw = pcall(util.TableToJSON, { version = 1, records = recs }, true)
        if not (ok and isstring(raw)) then return false end
        file.Write(Q.FlagFile, raw)
        return true
    end

    function Q.LoadFlags()
        Q.Flags = {}
        if not file.Exists(Q.FlagFile, "DATA") then return true end
        local ok, t = pcall(util.JSONToTable, file.Read(Q.FlagFile, "DATA") or "", false, true)
        if not (ok and istable(t)) then return false end
        for _, rec in ipairs(t.records or {}) do
            if istable(rec) and isstring(rec.key) then Q.Flags[rec.key] = istable(rec.flags) and rec.flags or {} end
        end
        return true
    end

    local function nodesOf(def, phase)
        if not def then return {} end
        local dlg = def.dialogue or {}
        local pack = dlg[phase] or {}
        if isstring(pack) then
            if pack == "" then return {} end
            return { { id = phase .. "_1", speaker = "", text = pack, next = "", choices = {} } }
        end
        return istable(pack.nodes) and pack.nodes or pack
    end

    local function findNode(nodes, idOrIndex)
        if tonumber(idOrIndex) then
            return nodes[tonumber(idOrIndex)], tonumber(idOrIndex)
        end
        local want = tostring(idOrIndex or "")
        for i, n in ipairs(nodes) do
            if tostring(n.id or i) == want then return n, i end
        end
        return nodes[1], 1
    end

    local function visibleChoices(ply, node)
        local out = {}
        for i, ch in ipairs(istable(node.choices) and node.choices or {}) do
            if Q.EvalCondition(ply, ch.cond) then
                out[#out + 1] = {
                    i = i, text = trim(ch.text, 160),
                    action = trim(ch.action, 24),
                }
            end
        end
        return out
    end

    local function sendNode(ply, npcName, questID, phase, node, index, nodes)
        local choices = visibleChoices(ply, node)
        net.Start(NET_NODE)
            net.WriteString(tostring(npcName or ""))
            net.WriteString(tostring(questID or ""))
            net.WriteString(tostring(phase or "offer"))
            net.WriteUInt(index or 1, 8)
            net.WriteUInt(#nodes, 8)
            net.WriteString(trim(node.speaker, 80))
            net.WriteString(trim(node.text, 1200))
            net.WriteUInt(#choices, 4)
            for _, ch in ipairs(choices) do
                net.WriteUInt(ch.i, 8)
                net.WriteString(ch.text)
            end
        net.Send(ply)
    end

    function Q.BeginDialogue(ply, npc, questID, phase)
        if not (IsValid(ply) and IsValid(npc)) then return false end
        local def = Q.Definitions and Q.Definitions[tostring(questID or "")]
        local nodes = nodesOf(def, phase)
        if #nodes == 0 then return false end
        ply.GRMQuestDlg = {
            npc = npc, npcID = npc.GetQuestNPCID and npc:GetQuestNPCID() or "",
            npcName = npc.GetQuestNPCName and npc:GetQuestNPCName() or "NPC",
            questID = tostring(questID), phase = phase or "offer",
        }
        sendNode(ply, ply.GRMQuestDlg.npcName, questID, phase, nodes[1], 1, nodes)
        return true
    end

    local function runAction(ply, def, action, arg)
        action = string.lower(trim(action, 24))
        arg = trim(arg, 96)
        if action == "" or action == "continue" then return "ok" end
        if action == "close" then return "close" end
        if action == "accept" then
            if def then
                local ok, why = Q.Start(ply, def.id)
                if not ok then
                    if GRM.Notify then GRM.Notify(ply, tostring(why), 255, 140, 100) end
                    return "stay"
                end
            end
            return "close"
        end
        if action == "set_flag" and arg ~= "" then Q.SetFlag(ply, arg, true) return "ok" end
        if action == "clear_flag" and arg ~= "" then Q.SetFlag(ply, arg, false) return "ok" end
        if action == "give_money" then
            local n = math.Clamp(math.floor(tonumber(arg) or 0), 0, 1000000)
            if n > 0 and GRM.GiveMoney then GRM.GiveMoney(ply, n, "Диалог NPC") end
            return "ok"
        end
        if action == "give_item" and arg ~= "" then
            if GRM.Inventory and GRM.Inventory.AddItem then GRM.Inventory.AddItem(ply, arg, 1) end
            return "ok"
        end
        if action == "emit" and arg ~= "" then
            if Q.Event then Q.Event(ply, arg, "", 1) end
            return "ok"
        end
        return "ok"
    end

    net.Receive(NET_PICK, function(_, ply)
        if not IsValid(ply) then return end
        ply.GRMQuestDlgNext = ply.GRMQuestDlgNext or 0
        if CurTime() < ply.GRMQuestDlgNext then return end
        ply.GRMQuestDlgNext = CurTime() + 0.2
        local sess = ply.GRMQuestDlg
        if not istable(sess) or not IsValid(sess.npc) then return end
        if ply:GetPos():DistToSqr(sess.npc:GetPos()) > 220 * 220 then
            ply.GRMQuestDlg = nil
            return
        end
        local nodeIndex = net.ReadUInt(8)
        local choiceIndex = net.ReadUInt(8)
        local def = Q.Definitions and Q.Definitions[sess.questID]
        local nodes = nodesOf(def, sess.phase)
        local node = nodes[nodeIndex]
        if not node then return end

        local ch
        if choiceIndex == 0 then
            ch = { next = node.next, action = "", actionArg = "" }
        else
            ch = (node.choices or {})[choiceIndex]
            if not istable(ch) or not Q.EvalCondition(ply, ch.cond) then return end
        end

        local result = runAction(ply, def, ch.action, ch.actionArg)
        if result == "close" then
            ply.GRMQuestDlg = nil
            net.Start(NET_NODE)
                net.WriteString("")
                net.WriteString("")
                net.WriteString("")
                net.WriteUInt(0, 8)
                net.WriteUInt(0, 8)
                net.WriteString("")
                net.WriteString("")
                net.WriteUInt(0, 4)
            net.Send(ply)
            return
        end
        if result == "stay" then
            sendNode(ply, sess.npcName, sess.questID, sess.phase, node, nodeIndex, nodes)
            return
        end

        local nextID = tostring(ch.next or "")
        local nxt, ni
        if nextID ~= "" then nxt, ni = findNode(nodes, nextID)
        else ni = nodeIndex + 1; nxt = nodes[ni] end
        if not nxt then
            ply.GRMQuestDlg = nil
            net.Start(NET_NODE)
                net.WriteString("") net.WriteString("") net.WriteString("")
                net.WriteUInt(0, 8) net.WriteUInt(0, 8)
                net.WriteString("") net.WriteString("") net.WriteUInt(0, 4)
            net.Send(ply)
            return
        end
        sendNode(ply, sess.npcName, sess.questID, sess.phase, nxt, ni, nodes)
    end)

    hook.Add("InitPostEntity", "GRM_Quest_LoadFlags", function()
        timer.Simple(0.5, function() if Q.LoadFlags then Q.LoadFlags() end end)
    end)
    hook.Add("ShutDown", "GRM_Quest_SaveFlags", function() if Q.SaveFlags then Q.SaveFlags() end end)
end

if CLIENT then
    local dlg
    local function closeDlg()
        if IsValid(dlg) then dlg:Remove() end
        dlg = nil
    end

    net.Receive(NET_NODE, function()
        local npcName = net.ReadString()
        local questID = net.ReadString()
        local phase = net.ReadString()
        local index = net.ReadUInt(8)
        local total = net.ReadUInt(8)
        local speaker = net.ReadString()
        local text = net.ReadString()
        local nch = net.ReadUInt(4)
        local choices = {}
        for i = 1, nch do
            choices[#choices + 1] = { i = net.ReadUInt(8), text = net.ReadString() }
        end
        if total == 0 or text == "" and npcName == "" then closeDlg() return end

        if not IsValid(dlg) then
            dlg = vgui.Create("DFrame")
            dlg:SetSize(math.min(760, ScrW() - 40), math.min(560, ScrH() - 40))
            dlg:Center() dlg:SetTitle("") dlg:ShowCloseButton(true) dlg:MakePopup()
            dlg.Paint = function(_, w, h)
                draw.RoundedBox(10, 0, 0, w, h, Color(9, 14, 23, 248))
                draw.RoundedBoxEx(10, 0, 0, w, 48, Color(16, 25, 39), true, true, false, false)
                draw.SimpleText("ДИАЛОГ · " .. tostring(dlg._npc or ""), "DermaLarge", 18, 24, Color(238, 244, 252), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
            end
            dlg.OnClose = closeDlg
        end
        dlg._npc = npcName
        if IsValid(dlg._body) then dlg._body:Remove() end
        local body = vgui.Create("DPanel", dlg)
        body:Dock(FILL) body:DockMargin(16, 52, 16, 16)
        body.Paint = function(_, w, h) draw.RoundedBox(10, 0, 0, w, h, Color(19, 28, 42, 248)) end
        dlg._body = body
        local who = vgui.Create("DLabel", body)
        who:SetPos(18, 14) who:SetSize(680, 26) who:SetFont("DermaLarge")
        who:SetTextColor(Color(242, 190, 75)) who:SetText(speaker ~= "" and speaker or npcName)
        local tx = vgui.Create("DLabel", body)
        tx:SetPos(18, 50) tx:SetSize(680, 160) tx:SetWrap(true) tx:SetFont("DermaDefaultBold")
        tx:SetTextColor(Color(238, 244, 252)) tx:SetText(text)

        local function pick(ci)
            net.Start(NET_PICK) net.WriteUInt(index, 8) net.WriteUInt(ci, 8) net.SendToServer()
        end
        local y = 230
        if #choices > 0 then
            for _, ch in ipairs(choices) do
                local b = vgui.Create("DButton", body)
                b:SetPos(18, y) b:SetSize(680, 36) b:SetText(ch.text)
                b:SetFont("DermaDefaultBold") b:SetTextColor(color_white)
                b.Paint = function(s, w, h)
                    draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(65, 145, 240) or Color(28, 39, 57))
                end
                b.DoClick = function() pick(ch.i) end
                y = y + 42
            end
        else
            local b = vgui.Create("DButton", body)
            b:SetPos(18, y) b:SetSize(680, 40)
            b:SetText(index < total and "Продолжить" or "Завершить разговор")
            b:SetFont("DermaDefaultBold") b:SetTextColor(color_white)
            b.Paint = function(s, w, h)
                draw.RoundedBox(6, 0, 0, w, h, s:IsHovered() and Color(65, 145, 240) or Color(40, 70, 110))
            end
            b.DoClick = function() pick(0) end
        end
    end)
end

print("[GRM Quest Dialogue] loaded")
