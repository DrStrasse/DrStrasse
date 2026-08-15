include("shared.lua")

function ENT:Draw()
 self:DrawModel()
end

function ENT:Initialize()
 self._nextUse=0
end

function ENT:Use(act,called,type,value)
 if CurTime()<self._nextUse then return end
 self._nextUse=CurTime()+0.5
 
 local title=self:GetDocumentTitle()or"Документ"
 local content=self:GetDocumentContent()or""
 local owner=self:GetDocumentOwner()or"Неизвестно"
 local imgFile=self:GetDocumentImage()or""
 local category=self:GetDocumentCategory()or"doc"
 
 -- Create document viewer frame
 local f=vgui.Create("DFrame")
 f:SetTitle("")
 f:SetSize(500,600)
 f:Center()
 f:MakePopup()
 f.Paint=function(_,w,h)
  draw.RoundedBox(10,0,0,w,h,Color(20,30,45,245))
  draw.RoundedBoxEx(10,0,0,w,50,Color(15,25,40),true,true,false,false)
  draw.SimpleText(title,"DermaLarge",18,25,Color(240,245,252),TEXT_ALIGN_LEFT,TEXT_ALIGN_CENTER)
 end
 
 -- Check if this is a photo document with image
 if imgFile~=""and(category=="photo"or category=="photo_print"or category=="photorobot")then
  -- Photo document - show image
  local imgPanel=vgui.Create("DPanel",f)
  imgPanel:SetPos(20,60)
  imgPanel:SetSize(460,460)
  imgPanel.Paint=function(_,w,h)
   draw.RoundedBox(8,0,0,w,h,Color(235,225,210))
  end
  
  -- Load image using HTML panel
  local html=vgui.Create("DHTML",imgPanel)
  html:SetPos(10,10)
  html:SetSize(440,440)
  local imgPath="data/"..imgFile
  html:SetHTML([[<html><body style="margin:0;padding:0;background:#ebe1d2;display:flex;align-items:center;justify-content:center;height:100%;"><img src="file://]]..imgPath..[[" style="max-width:100%;max-height:100%;border:2px solid #888;box-shadow:0 4px 8px rgba(0,0,0,0.3);"></body></html>]])
  
  -- Description below image
  local descLabel=vgui.Create("DLabel",f)
  descLabel:SetPos(20,530)
  descLabel:SetSize(460,40)
  descLabel:SetFont("DermaDefault")
  descLabel:SetTextColor(Color(150,165,185))
  descLabel:SetWrap(true)
  -- Extract description (remove image reference)
  local desc=content:gsub("%[ИЗОБРАЖЕНИЕ: [^%]]+%]",""):gsub("ФОТОРОБОТ[^\n]*\n",""):gsub("Эффект:[^\n]*\n",""):gsub("^%s+","")
  descLabel:SetText(desc)
  
  -- Owner label
  local ownerLabel=vgui.Create("DLabel",f)
  ownerLabel:SetPos(20,575)
  ownerLabel:SetSize(460,20)
  ownerLabel:SetFont("DermaDefault")
  ownerLabel:SetTextColor(Color(120,130,150))
  ownerLabel:SetText("Автор: "..owner)
 else
  -- Text document: render via GRMML (свой язык). Fallback — сырой текст.
  if GRM.OSDoc and GRM.OSDoc.OpenViewer then
   f:Close()
   GRM.OSDoc.OpenViewer("ДОКУМЕНТ · "..title, content, { owner = owner })
  else
   local textEntry=vgui.Create("DTextEntry",f)
   textEntry:SetPos(20,60)
   textEntry:SetSize(460,480)
   textEntry:SetMultiline(true)
   textEntry:SetEditable(false)
   textEntry:SetText(content)
   textEntry:SetFont("DermaDefault")
   
   local ownerLabel=vgui.Create("DLabel",f)
   ownerLabel:SetPos(20,550)
   ownerLabel:SetSize(460,20)
   ownerLabel:SetFont("DermaDefault")
   ownerLabel:SetTextColor(Color(120,130,150))
   ownerLabel:SetText("Автор: "..owner)
  end
 end
end
