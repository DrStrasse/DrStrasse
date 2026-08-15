--[[
  GRM OS Editor — модуль текстового редактора GRM NET OS (язык GRMML).

  Вынесен из cl_grm_electronics.lua. Принимает контекст и рисует страницу
  редактора: панель инструментов (шаблоны GRMML), поле текста, название,
  сохранение, предпросмотр через GRM.OSDoc и переход к файлам.
]]
if not CLIENT then return end

GRM = GRM or {}
GRM.OSEditor = GRM.OSEditor or {}
local ED = GRM.OSEditor
ED.Version = "1.0.0"

function ED.Open(ctx)
  if not ctx or not IsValid(ctx.body) then return end
  local C = ctx.C
  local body = ctx.body
  local ui = ctx.ui
  local send = ctx.send
  body:Clear()

  ui.textLabel(body, "ТЕКСТОВЫЙ РЕДАКТОР", 18, 10, 300, 28, "GRMNet_Title", C.text)

  local toolbar = vgui.Create("DPanel", body)
  toolbar:SetPos(18, 42); toolbar:SetSize(794, 36)
  toolbar.Paint = function(_, w, h)
    draw.RoundedBox(6, 0, 0, w, h, Color(15, 24, 38))
    surface.SetDrawColor(Color(40, 55, 75)); surface.DrawLine(0, h - 1, w, h - 1)
  end

  local area = ui.entry(body, "Начните вводить текст...", 18, 84, 794, 500, true)
  local docName = ui.entry(body, "Название документа", 18, 594, 400, 30)

  local tbBtns = {
    { "B", "Жирный", function() local t = area:GetText(); area:SetText(t .. "**жирный**") end },
    { "I", "Курсив", function() local t = area:GetText(); area:SetText(t .. "*курсив*") end },
    { "H", "# Заголовок", function() local t = area:GetText(); area:SetText(t .. "\n# Заголовок\n") end },
    { "•", "Список", function() local t = area:GetText(); area:SetText(t .. "\n- пункт") end },
    { "▤", "[img:]", function() local t = area:GetText(); area:SetText(t .. "\n[img: grm_computer/images/xxx.jpg]") end },
    { "☰", "Шаблон", function() area:SetText("ДОКУМЕНТ\n═══════════\n\nДата: " .. os.date("%d.%m.%Y") .. "\nАвтор: " .. tostring(ctx.user()) .. "\n\n---\n\n") end },
    { "✕", "Очистить", function() area:SetText("") end },
  }
  for i, tb in ipairs(tbBtns) do
    local bx = 4 + (i - 1) * 113
    local b = vgui.Create("DButton", toolbar)
    b:SetPos(bx, 4); b:SetSize(107, 28); b:SetText("")
    b.DoClick = function() surface.PlaySound("buttons/button15.wav"); tb[3]() end
    b.Paint = function(self, w, h)
      local c = self:IsDown() and Color(20, 32, 50) or (self:IsHovered() and C.hover or C.card)
      draw.RoundedBox(5, 0, 0, w, h, c)
      draw.SimpleText(tb[1], "GRMNet_Body", 8, h / 2, C.blue, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
      draw.SimpleText(tb[2], "GRMNet_Small", 30, h / 2, C.text, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
  end

  local selectedDocID = ""
  ui.btn(body, "Сохранить", 430, 594, 120, 30, C.green, function()
    send("file_save", function()
      net.WriteString(selectedDocID)
      net.WriteString(docName:GetText())
      net.WriteString(area:GetText())
      net.WriteString("doc")
    end)
  end)
  ui.btn(body, "Файлы", 560, 594, 120, 30, C.blue, function() send("files") end)
  ui.btn(body, "ПРЕДПРОСМОТР", 688, 594, 124, 30, C.purple, function()
    if GRM.OSDoc and GRM.OSDoc.OpenViewer then
      GRM.OSDoc.OpenViewer((docName:GetText() ~= "" and docName:GetText()) or "Документ", area:GetText(), { resolver = ctx.resolver })
    else
      notification.AddLegacy("Модуль GRMML не загружен", NOTIFY_ERROR, 3)
    end
  end)

  local statusBar = vgui.Create("DPanel", body)
  statusBar:SetPos(18, 630); statusBar:SetSize(794, 14)
  statusBar.Paint = function(_, w, h)
    draw.RoundedBox(3, 0, 0, w, h, Color(14, 22, 38))
    local text = area:GetText() or ""
    local chars = #text
    local lines = select(2, string.gsub(text, "\n", "")) + 1
    draw.SimpleText("Символов: " .. chars .. "  |  Строк: " .. lines .. "  |  GRMML: # заголовок · **жирный** · *курсив* · [img:] · [grface:]", "GRMNet_Tiny", 8, h / 2, C.dim, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
  end

  -- Поля для net-обработчика file_open (заполняются при открытии файла из списка).
  body._editorArea = area
  body._editorName = docName
end

print("[GRM OSEditor] v" .. ED.Version .. " loaded (text editor module)")
