local _, ns = ...

-- GLOBALS: _G, EncounterJournal, MidgetLocalDB
-- GLOBALS: EncounterJournal_DisplayInstance, EJ_GetEncounterInfo, EJ_GetEncounterInfoByIndex, EJ_GetInstanceByIndex, EJ_InstanceIsRaid, NavBar_Reset, CreateFrame, GetTexCoordsForRoleSmallCircle

-- ================================================
--  Quickly browse multiple instances
-- ================================================
local function ArrowClicked(self, button)
	if not EncounterJournal.instanceID then return end

	local isRaid = EJ_InstanceIsRaid()
	local index, maxIndex = 1, 0
	local currentInstanceID = EJ_GetInstanceByIndex(1, isRaid)
	while currentInstanceID do
		maxIndex = maxIndex + 1
		if currentInstanceID == EncounterJournal.instanceID then
			index = maxIndex
		end
		currentInstanceID = EJ_GetInstanceByIndex(maxIndex+1, isRaid)
	end

	local index = (index + self.direction) % maxIndex
	if index == 0 then index = maxIndex end

	NavBar_Reset(EncounterJournal.navBar)
	currentInstanceID = EJ_GetInstanceByIndex(index, isRaid)
	EncounterJournal_DisplayInstance(currentInstanceID)
end

local function CreateArrow(direction, ...)
	local arrow = CreateFrame("Button", nil, EncounterJournal.encounter.info)
	arrow.direction = direction
	arrow:SetScript("OnClick", ArrowClicked)

	arrow:SetNormalTexture("Interface\\Buttons\\Arrow-"..(direction == 1 and "Up" or "Down").."-Up")
	arrow:SetPushedTexture("Interface\\Buttons\\Arrow-"..(direction == 1 and "Up" or "Down").."-Down")
	arrow:SetDisabledTexture("Interface\\Buttons\\Arrow-"..(direction == 1 and "Up" or "Down").."-Disabled")
	-- arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")

	arrow:SetPoint(...)
	arrow:SetSize(10, 10)

	return arrow
end
local buttonDown, buttonUp
EncounterJournal:HookScript("OnShow", function()
	if not buttonDown then
		buttonUp   = CreateArrow( 1, "BOTTOMRIGHT", "$parentInstanceTitle", "LEFT", 0,  1)
		buttonDown = CreateArrow(-1, "TOPRIGHT",    "$parentInstanceTitle", "LEFT", 0, -1)
	end
end)

-- ================================================
--  loot wishlist
-- ================================================
local function ManageLootRoles(self, btn)
	local bossButton = self:GetParent()
	if not MidgetLocalDB.LFRLootSpecs then MidgetLocalDB.LFRLootSpecs = {} end

	if btn == 'RightButton' then
		-- remove specialization preference
		MidgetLocalDB.LFRLootSpecs[ bossButton.encounterID ] = nil
	else
		-- switch to next specialization
		-- TODO: save prefs per difficulty?
		-- spec: local index of spec in player's spec choices
		local spec = MidgetLocalDB.LFRLootSpecs[ bossButton.encounterID ] or 0 -- [ EJ_GetDifficulty() ]
		spec = spec + 1
		spec = GetSpecializationInfo(spec) and spec or 1
		MidgetLocalDB.LFRLootSpecs[ bossButton.encounterID ] = spec
	end
end
local function UpdateLootSpecIcon(bossButton)
	if not bossButton then return end
	if not bossButton.roleButton then
		local button = CreateFrame("Button", "$parentLootSpec", bossButton)
		button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
		button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		button:SetScript("OnClick", function(self, btn)
			ManageLootRoles(self, btn)
			UpdateLootSpecIcon(self:GetParent())
		end)
		button:SetPoint("TOPRIGHT", -4, -6)
		button:SetSize(16, 16)

		bossButton.roleButton = button
	end
	local roleButton = bossButton.roleButton

	local lootSpec = MidgetLocalDB.LFRLootSpecs and MidgetLocalDB.LFRLootSpecs[ bossButton.encounterID ] or nil
	if lootSpec then
		local specID, _, _, icon = GetSpecializationInfo(lootSpec)
		roleButton:SetNormalTexture(icon)
		roleButton:SetAlpha(1)
	else
		roleButton:SetNormalTexture("Interface\\Vehicles\\UI-Vehicles-Raid-Icon")
		roleButton:GetNormalTexture():SetTexCoord(0, 1, 0, 1)
		roleButton:SetAlpha(0.5)
	end
end

local function UpdateBossButtons()
	local bossIndex, bossButton = 1, nil
	local name, description, bossID, _, link = EJ_GetEncounterInfoByIndex(bossIndex)
	while bossID do -- buttons should already exist from Blizzard's code!
		bossButton = _G["EncounterJournalBossButton"..bossIndex]
		UpdateLootSpecIcon(bossButton)

		bossIndex = bossIndex + 1
		name, description, bossID, _, link = EJ_GetEncounterInfoByIndex(bossIndex)
	end
end

local function CheckUpdateLootSpec()
	-- print('encounter started/changed/finished', UnitName('target'), UnitName('boss1'), UnitName('boss2'), UnitName('boss3'), UnitName('boss4'))

	local instanceID = EJ_GetCurrentInstance()
	local _, _, difficultyID = GetInstanceInfo() -- EJ_GetDifficulty()

	-- instanceID only works if EJ is loaded, but if it isn't it's set to current instance, anyway
	local encounterIndex = 1
	local encounter, _, encounterID = EJ_GetEncounterInfoByIndex(encounterIndex, instanceID)
	local targetName, bossName = UnitName('target'), nil
	local matched = false
	while encounterID do
		local creatureIndex = 1
		local _, creature = EJ_GetCreatureInfo(creatureIndex, encounterID)
		while creature do
			if targetName and targetName == creature then
				-- print('target is boss', creature)
				matched = true
			else
				for i=1,10 do
					bossName = UnitName('boss'..i)
					if bossName and bossName == creature then
						-- print('boss', i, 'is boss', creature)
						matched = true
						break
					end
				end
			end
			-- don't need to check other creatures in this encounter
			if matched then break end

			creatureIndex = creatureIndex + 1
			_, creature = EJ_GetCreatureInfo(creatureIndex, encounterID)
		end

		if matched then
			if not lastEncounter or lastEncounter ~= encounterID then
				lastEncounter = encounterID
				break
			else
				return
			end
		end
		encounterIndex = encounterIndex + 1
		encounter, _, encounterID = EJ_GetEncounterInfoByIndex(encounterIndex, instanceID)
	end

	if matched then
		local currentLoot = GetLootSpecialization()
		local currentSpec = GetSpecializationInfo(GetSpecialization())
		local specPreference = MidgetLocalDB.LFRLootSpecs and MidgetLocalDB.LFRLootSpecs[ encounterID ] or 0
			  specPreference = GetSpecializationInfo(specPreference)
		-- don't change if we have no preference set
		if specPreference and (currentLoot == 0 and currentSpec ~= specPreference or currentLoot ~= specPreference) then
			ns.Print('Changing loot spec to %s (%d)', GetSpecializationInfoByID(specPreference), specPreference)
			SetLootSpecialization(specPreference)
		else
			-- ns.Print('already in correct spec')
		end
	end

	--[[
	/run local d=MidgetLocalDB.LFRLootSpecs; for eID,x in pairs(MidgetLocalDB.LFRLootRoles) do if x == "TANK" then d[eID] = 3 elseif x == "DAMAGER" then d[eID] = 1 else d[eID] = 4 end end
	/run MidgetLocalDB.LFRLootRoles = nil
	--]]

	-- ns.UnregisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", "encounter_start")
end

-- events / hooks
local selectedEncounter, selectedDifficulty
hooksecurefunc("EncounterJournal_DisplayInstance", UpdateBossButtons)
hooksecurefunc("EncounterJournal_DisplayEncounter", function(encounterID, noButton)
	if selectedEncounter and selectedEncounter == EncounterJournal.encounterID
		and (not selectedDifficulty or selectedDifficulty == EJ_GetDifficulty()) then
		-- unselect this boss without changing scroll position in boss list
		NavBar_Reset(EncounterJournal.navBar)
		selectedEncounter = nil

		local leftScroll = EncounterJournal.encounter.info.bossesScroll.ScrollBar
		local bossListScrollValue = leftScroll:GetValue()
		EncounterJournal_DisplayInstance(EncounterJournal.instanceID)
		leftScroll:SetValue(bossListScrollValue)
	else
		selectedEncounter = encounterID
	end
	selectedDifficulty = EJ_GetDifficulty()
end)

local lastEncounter = nil
ns.RegisterEvent("PLAYER_REGEN_ENABLED", function() lastEncounter = nil end, "encounter_end")
ns.RegisterEvent("INSTANCE_ENCOUNTER_ENGAGE_UNIT", CheckUpdateLootSpec, "encounter_start")
if BigWigsLoader then
	BigWigsLoader:RegisterMessage("BigWigs_OnBossEngage", function( ... )
		print('bigwigs boss enabled', ...)
		CheckUpdateLootSpec()
	end)
end
