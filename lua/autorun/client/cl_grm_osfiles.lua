--[[
  GRM OS Files — модуль файл-менеджера GRM NET OS.

  Вынесен из cl_grm_electronics.lua. Принимает контекст (body/send/files/
  topology/ui/resolver) и рисует страницу файлов: список, открытие, передача,
  удаление через список, печать на сетевом принтере и предпросмотр GRMML.
]]
if not CLIENT then return end

GRM = GRM or {}
GRM.OSFiles = GRM.OSFiles or {}
local F = GRM.OSFiles
F.Version = "1.0.0"

function F.Open(ctx, files)
  if not ctx or not IsValid(ctx.body) then return end
  local C = ctx.C
  local body = ctx.body
  local ui = ctx.ui
  local send = ctx.send
  local filesList = files or ctx.files() or {}
  ctx.setFiles(filesList)
  body:Clear()

  -- Шапка.
  local headBar = vgui.Create("DPanel", body)
  headBar:SetPos(0, 0)
  headBar:SetSize(830, 44)
  headBar.Paint = function(_, w, h)
    draw.RoundedBoxEx(9, 0, 0, w, h, Color(14, 22, 38), true, true, false, false)
    surface.SetMaterial(Material("icon16/folder.png"))
    surface.SetDrawColor(C.blue)
    surface.DrawTexturedRect(16, 10, 24, 24)
    draw.SimpleText("ФАЙЛОВЫЙ МЕНЕДЖЕР", "GRMNet_Head", 48, 22, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(tostring(ctx.deviceID()):sub(1, 24), "GRMNet_Small", w - 16, 22, C.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
  end

  local list = ui.darkList(body, 14, 52, 310, 500, { { "Файл", 160 }, { "Владелец", 85 }, { "КБ", 42 } })
  for _, r in ipairs(filesList) do
    local line = ui.addLine(list, r.name, r.owner, math.ceil((r.size or 0) / 1024))
    line._file = r
  end

  local name = ui.entry(body, "Название документа", 340, 52, 340, 34)
  local content = ui.entry(body, "Текст файла", 340, 96, 470, 260, true)
  local selectedID = ""

  ui.btn(body, "ПРЕДПРОСМОТР", 690, 52, 120, 34, C.purple, function()
    if GRM.OSDoc and GRM.OSDoc.OpenViewer then
      GRM.OSDoc.OpenViewer((name:GetText() ~= "" and name:GetText()) or "Документ", content:GetText(), { resolver = ctx.resolver, owner = ctx.user() })
    else
      notification.AddLegacy("Модуль GRMML не загружен", NOTIFY_ERROR, 3)
    end
  end)

  list.OnRowSelected = function(_, _, line)
    selectedID = line._file.id
    send("file_open", function() net.WriteString(selectedID) end)
  end

  -- Передача.
  local share = ui.entry(body, "Логин получателя", 340, 418, 240, 34)
  ui.btn(body, "Передать", 590, 418, 160, 34, C.blue, function()
    send("file_share", function() net.WriteString(selectedID); net.WriteString(share:GetText()) end)
  end)

  -- Печать.
  local printPanel = vgui.Create("DPanel", body)
  printPanel:SetPos(340, 464)
  printPanel:SetSize(470, 166)
  printPanel.Paint = function(_, w, h)
    draw.RoundedBox(8, 0, 0, w, h, Color(14, 22, 38))
    surface.SetMaterial(Material("icon16/printer.png"))
    surface.SetDrawColor(C.yellow)
    surface.DrawTexturedRect(14, 12, 22, 22)
    draw.SimpleText("ПЕЧАТЬ ДОКУМЕНТА", "GRMNet_Head", 44, 22, C.yellow, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
  end
  local printer = vgui.Create("DComboBox", printPanel)
  printer:SetPos(14, 44); printer:SetSize(220, 30); printer.PrinterID = ""
  for _, d in ipairs((ctx.topology() or {}).devices or {}) do
    if d.kind == "printer" and d.online then printer:AddChoice("🖨 " .. d.name, d.id) end
  end
  printer.OnSelect = function(_, _, _, id) printer.PrinterID = id end
  local paper = vgui.Create("DComboBox", printPanel)
  paper:SetPos(244, 44); paper:SetSize(100, 30)
  paper:AddChoice("A4", "A4"); paper:AddChoice("A5", "A5"); paper:AddChoice("Letter", "Letter"); paper:ChooseOptionID(1)
  local orient = vgui.Create("DComboBox", printPanel)
  orient:SetPos(354, 44); orient:SetSize(100, 30)
  orient:AddChoice("Книжная", "portrait"); orient:AddChoice("Альбом.", "landscape"); orient:ChooseOptionID(1)
  local copies = vgui.Create("DNumberWang", printPanel)
  copies:SetPos(76, 82); copies:SetSize(50, 28); copies:SetMin(1); copies:SetMax(10); copies:SetValue(1)
  local quality = vgui.Create("DComboBox", printPanel)
  quality:SetPos(140, 82); quality:SetSize(120, 28)
  quality:AddChoice("Черновик", "draft"); quality:AddChoice("Обычное", "normal"); quality:AddChoice("Высокое", "high"); quality:ChooseOptionID(2)
  ui.btn(printPanel, "ПЕЧАТАТЬ", 300, 82, 156, 28, C.yellow, function()
    send("print", function()
      net.WriteString(selectedID)
      net.WriteString(printer.PrinterID)
      local _, pd = paper:GetSelected(); net.WriteString(pd or "A4")
      local _, od = orient:GetSelected(); net.WriteString(od or "portrait")
      net.WriteUInt(copies:GetValue(), 4)
      local _, qd = quality:GetSelected(); net.WriteString(qd or "normal")
    end)
  end)
  local preview = vgui.Create("DPanel", printPanel)
  preview:SetPos(300, 116); preview:SetSize(156, 42)
  preview.Paint = function(_, w, h)
    draw.RoundedBox(4, 0, 0, w, h, Color(240, 240, 230))
    local _, pd = paper:GetSelected()
    local landscape = orient:GetText() == "Альбом."
    if landscape then
      draw.RoundedBox(2, 8, 4, w - 16, h - 8, Color(255, 255, 255))
      for i = 1, 4 do surface.SetDrawColor(200, 200, 200); surface.DrawLine(14, 8 + i * 7, w - 14, 8 + i * 7) end
    else
      draw.RoundedBox(2, w / 2 - 20, 4, 40, h - 8, Color(255, 255, 255))
      for i = 1, 4 do surface.SetDrawColor(200, 200, 200); surface.DrawLine(w / 2 - 16, 8 + i * 7, w / 2 + 16, 8 + i * 7) end
    end
    draw.SimpleText(pd or "A4", "GRMNet_Tiny", w / 2, h - 4, Color(120, 120, 120), TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM)
  end

  -- Поля для net-обработчика file_open (как в старом filesPage).
  body._fileName = name
  body._fileContent = content
end

print("[GRM OSFiles] v" .. F.Version .. " loaded (file manager module)")
