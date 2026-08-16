AddCSLuaFile("shared.lua");AddCSLuaFile("cl_init.lua");include("shared.lua")
function ENT:Initialize()self:SetModel("models/props_c17/clock01.mdl");self:PhysicsInit(SOLID_VPHYSICS);self:SetMoveType(MOVETYPE_VPHYSICS);self:SetSolid(SOLID_VPHYSICS);self:SetUseType(SIMPLE_USE);if self:GetClockName()==""then self:SetClockName("ГОРОДСКОЕ ВРЕМЯ")end;local ph=self:GetPhysicsObject();if IsValid(ph)then ph:Wake()end end
function ENT:Use(p)if IsValid(p)and p:IsPlayer()then p:ChatPrint("[Время] "..(GRM.Weather and GRM.Weather.FormatTime()or"--:--").." • "..(GRM.Weather and GRM.Weather.Period()or""))end end
hook.Add("GRM_PermAdded","GRM_Clock_Perm",function(e)if IsValid(e)and e:GetClass()=="grm_clock"then local ph=e:GetPhysicsObject();if IsValid(ph)then ph:EnableMotion(false)end end end)
