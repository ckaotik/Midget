local addonName, addon, _ = ...
local plugin = addon:NewModule('EncounterJournal', 'AceEvent-3.0')

-- GLOBALS: _G, EncounterJournal
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
	arrow:SetSize(14, 14)

	return arrow
end

-- ================================================
--  loot wishlist
-- ================================================
local function ManageLootRoles(self, btn)
	local bossButton = self:GetParent()
	if not addon.db.char.LFRLootSpecs then addon.db.char.LFRLootSpecs = {} end

	if btn == 'RightButton' then
		-- remove specialization preference
		addon.db.char.LFRLootSpecs[ bossButton.encounterID ] = nil
	else
		-- switch to next specialization
		-- TODO: save prefs per difficulty?
		-- spec: local index of spec in player's spec choices
		local spec = addon.db.char.LFRLootSpecs[ bossButton.encounterID ] or 0 -- [ EJ_GetDifficulty() ]
		spec = spec + 1
		spec = GetSpecializationInfo(spec) and spec or 1
		addon.db.char.LFRLootSpecs[ bossButton.encounterID ] = spec
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

	local lootSpec = addon.db.char.LFRLootSpecs and addon.db.char.LFRLootSpecs[ bossButton.encounterID ] or nil
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
	-- EJ_SelectInstance(instanceID)
	EncounterJournal_DisplayInstance(instanceID)

	local encounterIndex, encounterID, encounterName = 1, nil, nil
	while true do
		encounterName, _, encounterID = EJ_GetEncounterInfoByIndex(encounterIndex, instanceID)
		if not encounterName then
			print('could not find encounter', encounterIndex, 'of', instanceID, '(', id, name, ")")
			return
		elseif encounterName == name then
			break
		end
		encounterIndex = encounterIndex + 1
	end

	local currentLoot = GetLootSpecialization()
	local currentSpec = GetSpecializationInfo(GetSpecialization())
	local specPreference = addon.db.char.LFRLootSpecs and addon.db.char.LFRLootSpecs[ encounterID ] or 0
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

local function initialize()
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

	-- easily cycle through instances
	CreateArrow( 1, "BOTTOMRIGHT", "$parentInstanceTitle", "RIGHT", 30, 1)
	CreateArrow(-1, "TOPRIGHT",    "$parentInstanceTitle", "RIGHT", 30, -1)

	-- don't like tooltips triggering EVERYWHERE
	local scrollFrame = EncounterJournal.encounter.info.lootScroll
	local lootButtons = scrollFrame.buttons
	for _, button in pairs(lootButtons) do
		button:SetHitRectInsets(0, 276, 0, 0)
	end

	local itemSpecs = {}
	hooksecurefunc("EncounterJournal_LootUpdate", function()
		local classID, specID = EJ_GetLootFilter()
		local scrollFrame = EncounterJournal.encounter.info.lootScroll
		local offset = HybridScrollFrame_GetOffset(scrollFrame)

		local numLoot = EJ_GetNumLoot()
		for i = 1, #scrollFrame.buttons do
			local button = scrollFrame.buttons[i]
			local index = offset + i
			if index <= numLoot then
				if not button.specs then
					button.specs = button:CreateFontString(nil, nil, 'GameFontBlack')
					button.specs:SetPoint('BOTTOMLEFT', button.slot, 'BOTTOMRIGHT')
				end

				local _, _, _, _, _, link = EJ_GetLootInfoByIndex(index)
				local lootSpecs

				if specID == 0 then
					wipe(itemSpecs)
					itemSpecs = GetItemSpecInfo(link, itemSpecs)
					if #itemSpecs < GetNumSpecializationsForClassID(classID) then
						for _, itemSpecID in ipairs(itemSpecs) do
							local _, _, _, icon = GetSpecializationInfoByID(itemSpecID)
							lootSpecs = (lootSpecs and lootSpecs..'|n' or '') .. '|T'..icon..':0|t'
						end
					end
				end
				button.specs:SetText(lootSpecs)
			end
		end
	end)

	plugin:RegisterEvent('ENCOUNTER_START', CheckUpdateLootSpec)
	-- plugin:RegisterEvent('ENCOUNTER_END', CheckUpdateLootSpec)

	plugin:UnregisterEvent('ADDON_LOADED')
end

function plugin:OnEnable()
	if IsAddOnLoaded('Blizzard_EncounterJournal') then
		initialize()
		UpdateBossButtons()
	else
		plugin:RegisterEvent('ADDON_LOADED', function(event, arg1)
			if arg1 == 'Blizzard_EncounterJournal' then
				print('init triggered by Blizzard_EncounterJournal loading')
				initialize()
			end
		end)
	end
end
