local _, ns = ...
-- features stolen from Clash, still missing: Notes

-- GLOBALS: _G, EncounterJournal
-- GLOBALS: EncounterJournal_DisplayInstance, EncounterJournal_Refresh, EncounterJournal_ClearDetails, EJ_GetEncounterInfo, EJ_GetEncounterInfoByIndex, NavBar_ClearTrailingButtons, NavBar_AddButton, EJNAV_RefreshEncounter

-- ================================================
--  Favourites
-- ================================================
--[[ local function FaveMouseIn(self)
	self.favourite:Show()
end
local function FaveMouseOut(self)
	if not MidgetDB.faves[self.itemID] then
		self.favourite:Hide()
	end
end
local function FaveClick(self, btn)
	local itemID = self:GetParent().itemID
	MidgetDB.faves[itemID] = not MidgetDB.faves[itemID]
end
local function UpdateLootIcon()
	if not MidgetDB.faves then MidgetDB.faves = {} end

	local buttons = EncounterJournal.encounter.info.lootScroll.buttons
	for i, button in ipairs(buttons) do
		if not button.touched then
			local icon = CreateFrame("Button", nil, button)
			icon:SetNormalTexture("Interface\\CHARACTERFRAME\\UI-Player-PlayTimeTired") -- "Interface\\COMMON\\Indicator-Green")
			icon:GetNormalTexture():SetVertexColor(200/255, 210/255, 255/255) -- 218/255, 255/255, 200/255
			icon:SetPoint("BOTTOMLEFT", 2, 2)
			icon:SetSize(14, 14)
			icon:SetScript("OnClick", FaveClick)

			button.favourite = icon
			button:HookScript("OnEnter", FaveMouseIn)
			button:HookScript("OnLeave", FaveMouseOut)
			FaveMouseOut(button)
			button.touched = true
		end
	end
end
hooksecurefunc("EncounterJournal_LootUpdate", UpdateLootIcon) --]]

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
	local arrow = CreateFrame("Button", nil, EncounterJournal.encounter)
	arrow:SetScript("OnClick", ArrowClicked)

	arrow:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight")
	arrow:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-"..(direction == 1 and "Next" or "Prev").."Page-Up")
	arrow:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-"..(direction == 1 and "Next" or "Prev").."Page-Down")
	arrow:SetPoint(...)

	arrow:SetSize(20, 20)
	arrow.direction = direction

	return arrow
end
local buttonLeft, buttonRight
EncounterJournal:HookScript("OnShow", function()
	if not buttonLeft then
		buttonLeft = CreateArrow(-1, "TOPLEFT", "$parent", "TOPLEFT", 20, -10)
		buttonRight = CreateArrow(1, "TOPLEFT", buttonLeft, "TOPRIGHT", 0, 0)
	end
end)

-- ================================================
--  Show boss buttons when browsing loot
-- ================================================
local function MoveToLeft()
	local scroll = EncounterJournal.encounter.info.detailsScroll
	scroll:ClearAllPoints()
	scroll:SetPoint("TOPLEFT", EncounterJournal.encounter, "TOPLEFT", 30, -45)

	local scrollBar = scroll.ScrollBar
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("BOTTOMLEFT", -22, 17)
	scrollBar:SetPoint("TOPLEFT", -22, -17)
end
local function MoveToRight()
	local scroll = EncounterJournal.encounter.info.detailsScroll
	scroll:ClearAllPoints()
	scroll:SetPoint("BOTTOMRIGHT", "$parent", "BOTTOMRIGHT", -5, 1)

	local scrollBar = scroll.ScrollBar
	scrollBar:ClearAllPoints()
	scrollBar:SetPoint("BOTTOMRIGHT", 0, 17)
	scrollBar:SetPoint("TOPRIGHT", 0, -17)
end

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

local selectedEncounter, selectedDifficulty = nil, nil
local function UpdateBossButtons()
	if EncounterJournal.encounter.info.tab ~= 2 then return end
	selectedEncounter = nil

	EncounterJournal_ClearDetails()

	EncounterJournal.encounter.instance:Hide()
	EncounterJournal.encounter.model:Hide()
	EncounterJournal.encounter.info.dungeonBG:Hide()
	EncounterJournal.encounter.info.detailsScroll:Show()

	local bossIndex, bossButton = 1, nil
	local name, description, bossID, _, link = EJ_GetEncounterInfoByIndex(bossIndex)
	while bossID do -- buttons should already exist from Blizzard's code!
		bossButton = _G["EncounterJournalBossButton"..bossIndex]
		UpdateBossLootRoles(bossButton)
		if bossButton.encounterID == EncounterJournal.encounterID then
			selectedEncounter = bossButton.encounterID
			selectedDifficulty = EJ_GetDifficulty()
			bossButton:LockHighlight()
		else
			bossButton:UnlockHighlight()
		end
		bossButton:Show()
		bossIndex = bossIndex + 1
		name, description, bossID, _, link = EJ_GetEncounterInfoByIndex(bossIndex)
	end
end

local function TabClicked(self, button)
	local tabType = self:GetID()
	if tabType == 1 then -- info
		MoveToRight()
		EncounterJournal_Refresh()
	else -- loot
		MoveToLeft()
		UpdateBossButtons()

		local creatureIndex = 1
		local creatureButton = EncounterJournal.encounter["creatureButton"..creatureIndex]
		while creatureButton do
			creatureButton:Hide()
			creatureIndex = creatureIndex + 1
			creatureButton = EncounterJournal.encounter["creatureButton"..creatureIndex]
		end
	end
end

-- events / hooks
EncounterJournal.encounter.info.lootTab:HookScript("OnClick", TabClicked)
EncounterJournal.encounter.info.bossTab:HookScript("OnClick", TabClicked)
hooksecurefunc("EncounterJournal_DisplayEncounter", function(encounterID, noButton)
	if EncounterJournal.encounter.info.tab == 2 then
		-- TODO: selectedDifficulty == EJ_GetDifficulty() creates bug when re-selecting current difficulty
		if selectedEncounter and selectedDifficulty and selectedDifficulty == EJ_GetDifficulty() then
			-- fix navigation bar: remove 2 buttons
			NavBar_ClearTrailingButtons(EncounterJournal.navBar.navList, EncounterJournal.navBar.freeButtons,
				EncounterJournal.navBar.navList[ #(EncounterJournal.navBar.navList)-2 ])

			if selectedEncounter == EncounterJournal.encounterID then
				-- unselect this boss
				EncounterJournal_DisplayInstance(EncounterJournal.instanceID, true)
			elseif not noButton then
				-- now add the new encounter navbutton
				local buttonData = {
					name = EJ_GetEncounterInfo(EncounterJournal.encounterID),
					OnClick = EJNAV_RefreshEncounter,
				}
				NavBar_AddButton(EncounterJournal.navBar, buttonData)
			end
		end
	end
	UpdateBossButtons()
end)
hooksecurefunc("EncounterJournal_DisplayInstance", function(instanceID, noButton)
	-- remove highlights
	local bossIndex = 1
	local bossButton = _G["EncounterJournalBossButton"..bossIndex]
	while bossButton do
		bossButton:UnlockHighlight()
		bossIndex = bossIndex + 1
		bossButton = _G["EncounterJournalBossButton"..bossIndex]
	end
	UpdateBossButtons()
end)
