ENT.Type="anim";ENT.Base="base_gmodentity";ENT.PrintName="Распечатанный документ";ENT.Category="GRM — Electronics";ENT.Spawnable=false
function ENT:SetupDataTables()self:NetworkVar("String",0,"DocumentTitle");self:NetworkVar("String",1,"DocumentContent");self:NetworkVar("String",2,"DocumentOwner");self:NetworkVar("String",3,"DocumentImage");self:NetworkVar("String",4,"DocumentCategory")end
