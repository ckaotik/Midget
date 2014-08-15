local addonName, addon, _ = ...
local plugin = addon:NewModule('EncounterJournal', 'AceEvent-3.0')

-- GLOBALS: _G, EncounterJournal, MidgetLocalDB
-- GLOBALS: CreateFrame, UnitName, IsAddOnLoaded, EncounterJournal_DisplayInstance, EJ_GetCurrentInstance, EJ_GetDifficulty, EJ_GetEncounterInfo, EJ_GetCreatureInfo, EJ_GetEncounterInfoByIndex, EJ_GetInstanceByIndex, EJ_InstanceIsRaid, NavBar_Reset, GetInstanceInfo, GetTexCoordsForRoleSmallCircle, GetLootSpecialization, SetLootSpecialization, GetSpecialization, GetSpecializationInfo, GetSpecializationInfoByID
-- GLOBALS: pairs, hooksecurefunc

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

-- we store the last started encounter, so if the player makes manual changes after a pull, we don't revert
local lastEncounter
local function CheckUpdateLootSpec(event, id, name, difficulty, groupSize)
	-- print('starting encounter', id, name, difficulty, groupSize, 'last was', lastEncounter)
	if lastEncounter and lastEncounter == id then return end
	lastEncounter = id

	local instanceID = EJ_GetCurrentInstance()
	if not instanceID then return end
	EncounterJournal_DisplayInstance(instanceID)

	local encounterIndex, encounterID, encounterName = 1, nil, nil
	while true do
		encounterName, _, encounterID = EJ_GetEncounterInfoByIndex(encounterIndex, instanceID)
		if not encounterName then
			print('could not find encounter', encounterIndex, 'of', instanceID, '(', id, name, ")\n",
				EJ_GetEncounterInfoByIndex(encounterIndex, instanceID))
			return
		elseif encounterName == name then
			break
		end
		encounterIndex = encounterIndex + 1
	end

	local currentLoot = GetLootSpecialization()
	local currentSpec = GetSpecializationInfo(GetSpecialization())
	local specPreference = MidgetLocalDB.LFRLootSpecs and MidgetLocalDB.LFRLootSpecs[ encounterID ] or 0
		  specPreference = GetSpecializationInfo(specPreference)

	-- don't change if we have no preference set
	if not specPreference or currentLoot == specPreference or (currentLoot == 0 and currentSpec == specPreference) then
		addon:Print('Correct loot specialization is already selected')
	else
		local _, specName, _, specIcon = GetSpecializationInfoByID(specPreference)
		addon:Print('Changing loot spec to |T%1$s:0|t%2$s', specIcon, specName)
		SetLootSpecialization(specPreference)
	end
end

local function initialize(event, arg1)
	if (arg1 == addonName or arg1 == 'Blizzard_EncounterJournal') and IsAddOnLoaded('Blizzard_EncounterJournal') then
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

		local initArrows = nil
		EncounterJournal:HookScript("OnShow", function()
			if initArrows then return end
			CreateArrow( 1, "BOTTOMRIGHT", "$parentInstanceTitle", "LEFT", 0,  1)
			CreateArrow(-1, "TOPRIGHT",    "$parentInstanceTitle", "LEFT", 0, -1)
			initArrows = true
		end)

		local initTooltips = nil
		hooksecurefunc("EncounterJournal_LootUpdate", function()
			if initTooltips then return end
			-- don't like tooltips triggering EVERYWHERE
			local lootButtons = EncounterJournal.encounter.info.lootScroll.buttons
			for _, button in pairs(lootButtons) do
				button:SetHitRectInsets(0, 276, 0, 0)
			end
			initTooltips = true
		end)

		plugin:RegisterEvent('ENCOUNTER_START', CheckUpdateLootSpec)
		-- plugin:RegisterEvent('ENCOUNTER_END', CheckUpdateLootSpec)

		plugin:UnregisterEvent('ADDON_LOADED')
	end
end

function plugin:OnEnable()
	plugin:RegisterEvent('ADDON_LOADED', initialize)
end
