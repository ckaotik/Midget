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
	if not MidgetLocalDB.LFRLootRoles then MidgetLocalDB.LFRLootRoles = {} end

	if btn == 'RightButton' then
		MidgetLocalDB.LFRLootRoles[bossButton.encounterID] = nil
	else
		local role = MidgetLocalDB.LFRLootRoles[bossButton.encounterID]
		if not role or role == "DAMAGER" then role = "TANK"
		elseif role == "TANK" then role = "HEALER"
		elseif role == "HEALER" then role = "DAMAGER"
		end
		MidgetLocalDB.LFRLootRoles[bossButton.encounterID] = role
	end
end
local function UpdateBossLootRoles(bossButton)
	if not bossButton then return end
	if not bossButton.roleButton then
		local button = CreateFrame("Button", nil, bossButton)
			  button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
			  button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
			  button:SetScript("OnClick", function(self, btn)
			  	ManageLootRoles(self, btn)
			  	UpdateBossLootRoles(self:GetParent())
			  end)
			  button:SetPoint("TOPRIGHT", -4, -6)
			  button:SetSize(16, 16)
		bossButton.roleButton = button
	end
	local roleButton = bossButton.roleButton

	local lootRole = MidgetLocalDB.LFRLootRoles and MidgetLocalDB.LFRLootRoles[bossButton.encounterID] or nil
	if lootRole then
		-- roleButton:SetNormalTexture("Interface\\GroupFrame\\UI-Group-"..lootRole.."Icon")
		roleButton:SetNormalTexture("Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES")
      	roleButton:GetNormalTexture():SetTexCoord(GetTexCoordsForRoleSmallCircle(lootRole))
		roleButton:SetAlpha(1)
	else
		roleButton:SetNormalTexture("Interface\\Vehicles\\UI-Vehicles-Raid-Icon")
		roleButton:GetNormalTexture():SetTexCoord(0, 1, 0, 1)
		roleButton:SetAlpha(0.5)
	end
end

local selectedDifficulty = nil
local function UpdateBossButtons()
	local bossIndex, bossButton = 1, nil
	local name, description, bossID, _, link = EJ_GetEncounterInfoByIndex(bossIndex)
	while bossID do -- buttons should already exist from Blizzard's code!
		bossButton = _G["EncounterJournalBossButton"..bossIndex]
		UpdateBossLootRoles(bossButton)

		bossIndex = bossIndex + 1
		name, description, bossID, _, link = EJ_GetEncounterInfoByIndex(bossIndex)
	end
end

-- events / hooks
hooksecurefunc("EncounterJournal_DisplayInstance", UpdateBossButtons)
hooksecurefunc("EncounterJournal_DisplayEncounter", function(encounterID, noButton)
	if selectedEncounter and selectedEncounter == EncounterJournal.encounterID then
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
end)
