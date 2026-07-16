AddCSLuaFile("entities/grm_bank_terminal/shared.lua")
AddCSLuaFile("entities/grm_bank_terminal/cl_init.lua")
include("entities/grm_bank_terminal/shared.lua")

function ENT:Initialize()
    local model = "models/props_c17/consolebox01a.mdl"
    if GRM and GRM.Economy and GRM.Economy.Config and GRM.Economy.Config.BankTerminalModel then
        model = GRM.Economy.Config.BankTerminalModel
    end
    self:SetModel(model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    if self:GetTerminalName() == "" then self:SetTerminalName("Банк GRM") end

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake(); phys:EnableMotion(false) end
end

function ENT:Use(ply)
    if GRM and GRM.Economy and GRM.Economy.OpenBankTerminal then
        GRM.Economy.OpenBankTerminal(ply, self)
    end
end
