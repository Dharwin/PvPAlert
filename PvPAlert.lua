-----------------------------------------------------------------------------------------------
-- Client Lua Script for PvPAlert
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------
 
require "Window"
require "Unit"
 
-----------------------------------------------------------------------------------------------
-- PvPAlert Module Definition
-----------------------------------------------------------------------------------------------
local PvPAlert = {} 
 
-----------------------------------------------------------------------------------------------
-- Constants
-----------------------------------------------------------------------------------------------
-- e.g. local kiExampleVariableMax = 999
 
-----------------------------------------------------------------------------------------------
-- Initialization
-----------------------------------------------------------------------------------------------
function PvPAlert:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

    -- initialize variables here
	self.knownUnits = {}
	self.ALERT_SPELLS = {}
	self.preloadedUnits = {}

    return o
end

function PvPAlert:Init()
	local bHasConfigureFunction = false
	local strConfigureButtonText = ""
	local tDependencies = {
		-- "UnitOrPackageName",
	}
    Apollo.RegisterAddon(self, bHasConfigureFunction, strConfigureButtonText, tDependencies)
end
 

-----------------------------------------------------------------------------------------------
-- PvPAlert OnLoad
-----------------------------------------------------------------------------------------------
function PvPAlert:OnLoad()
	Apollo.RegisterEventHandler("UnitCreated", "OnPreloadUnitCreated", self)
	
    -- load our form file
	self.xmlDoc = XmlDoc.CreateFromFile("PvPAlert.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

function PvPAlert:OnPreloadUnitCreated(unit)
	self.preloadedUnits[unit:GetId()] = unit
end

-----------------------------------------------------------------------------------------------
-- PvPAlert OnDocLoaded
-----------------------------------------------------------------------------------------------
function PvPAlert:OnDocLoaded()
	Apollo.RemoveEventHandler("UnitCreated", self)

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "PvPAlertForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end

		
		Apollo.RegisterEventHandler("UnitCreated", "OnUnitCreated", self)
		Apollo.RegisterEventHandler("UnitDestroyed", "OnUnitDestroyed", self)
		Apollo.RegisterEventHandler("NextFrame", "OnUpdate", self)
		
		self:RegisterAlertSpell("Picking Up Moodie Mask")
		self:RegisterAlertSpell("Detaching Moodie Mask")
		self:RegisterAlertSpell("Activating Control Point")
				
	    self.wndMain:Show(false, true)

		-- if the xmlDoc is no longer needed, you should set it to nil
		-- self.xmlDoc = nil
		
		-- Register handlers for events, slash commands and timer, etc.
		-- e.g. Apollo.RegisterEventHandler("KeyDown", "OnKeyDown", self)
		Apollo.RegisterSlashCommand("pvpalert", "OnPvPAlertOn", self)
		
		-- Check player faction. We only alert on the opposing faction.
		self.playerFaction = GameLib:GetPlayerUnit():GetFaction()
		
		-- Create trackers for any existing preloaded units.
		for unitId, unit in pairs(self.preloadedUnits) do
			self:OnUnitCreated(unit)
		end
		
		self.preloadedUnits = nil

	end
end

-----------------------------------------------------------------------------------------------
-- PvPAlert Functions
-----------------------------------------------------------------------------------------------
-- Define general functions here

-- on SlashCommand "/pvpalert"
function PvPAlert:OnPvPAlertOn()
	self.wndMain:Invoke() -- show the window
end

-- OnUnitCreated - start tracking this unit.
function PvPAlert:OnUnitCreated(newUnit)
	if not newUnit then return end
	
	if newUnit:IsACharacter() == false then return end

	-- TODO: Check unit is a player, and we are in a pvp BG
	local unitId = newUnit:GetId()
	
	-- Check if we already know about this unit.
	local fromMap = self.knownUnits[unitId]
	if fromMap ~= nil then return end
	
	-- Unit is new.
	self.knownUnits[unitId] = self:CreateUnitTracker(newUnit)
	
	-- Print("Created unit with id" .. unitId)
end

-- OnUnitDestroyed- stop tracking this unit.
function PvPAlert:OnUnitDestroyed(unit)
	if not unit then return end

	local unitId = unit:GetId()
	
	-- Remove the unit.
	local tracker = self.knownUnits[unitId]
	if tracker ~= nil then
		tracker.icon:SetNowhere()
		tracker.icon:Show(false)
		tracker.icon:Destroy()
		tracker.icon = nil
		self.knownUnits[unitId] = nil
	end
		
	-- Print("Destroyed unit with id" .. unitId)
end

function PvPAlert:CreateUnitTracker(unit)
	local iconForm = Apollo.LoadForm(self.xmlDoc, "AlertOverhead", "InWorldHudStratum", self)
	
	if unit:IsMounted() then
		iconForm:SetUnit(unit:GetUnitMount(), 1)
	else
		iconForm:SetUnit(unit, 1)
    end
	
	iconForm:Show(true)

	local tracker = {
		unit = unit,
		isAlerted = false,
		icon = iconForm
	}
	
	return tracker;
end

-- OnUpdate- check all units.
function PvPAlert:OnUpdate()

	for unitId, tracker in pairs(self.knownUnits) do
		--Print("Checking unit with id" .. unitId)
		local unit = tracker.unit
		
		local isNewAlert = false
		
		if tracker.isAlerted then
			-- Unit is alerted. Verify they still should be.
			if self:ShouldAlertUnit(unit) == false then
				-- Stop tracking unit
				tracker.isAlerted = false
			end
		else
			-- Unit is not alerted, see if they should be.
			if self:ShouldAlertUnit(unit) then
				tracker.isAlerted = true
				isNewAlert = true
			end
		end
		
		-- Conditionally show the icon
		tracker.icon:Show(GameLib.GetUnitScreenPosition(unit).bOnScreen and tracker.isAlerted)
		if isNewAlert then
			-- TODO: Play a sound
			Sound.Play(209)
		end
	end
end

function PvPAlert:ShouldAlertUnit(unit)
	--if unit == GameLib:GetTargetUnit() then return true end
	
	if self.playerFaction == unit:GetFaction() then return false end
	
	if unit:IsCasting() then
		-- Print("Unit is casting " .. unit:GetCastName())
		if self:ShouldAlertSpell(unit:GetCastName()) then
			-- Print("Unit with id " .. unit:GetId() .. " is casting " .. unit:GetCastName())
			return true			
		end
	end
	
	return false
end

function PvPAlert:RegisterAlertSpell(name)
	if not name then return end
	self.ALERT_SPELLS[name] = true
end

function PvPAlert:RemoveAlertSpell(name)
	if not name then return end
	self.ALERT_SPELLS[name] = nil
end

function PvPAlert:ShouldAlertSpell(name)
	if not name then return false end
	return self.ALERT_SPELLS[name] ~= nil
end

-----------------------------------------------------------------------------------------------
-- PvPAlertForm Functions
-----------------------------------------------------------------------------------------------
-- when the OK button is clicked
function PvPAlert:OnOK()
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function PvPAlert:OnCancel()
	self.wndMain:Close() -- hide the window
end


-----------------------------------------------------------------------------------------------
-- PvPAlert Instance
-----------------------------------------------------------------------------------------------
local PvPAlertInst = PvPAlert:new()
PvPAlertInst:Init()
