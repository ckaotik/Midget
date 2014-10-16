local addonName, addon, _ = ...
local plugin = addon:NewModule('BattlePets', 'AceEvent-3.0')

-- GLOBALS: _G, UIParent, MidgetDB, PetBattleFrame, C_PetJournal, C_PetBattles, GameTooltip, ITEM_QUALITY_COLORS, PET_TYPE_SUFFIX, ADD_ANOTHER, GREEN_FONT_COLOR_CODE, YELLOW_FONT_COLOR_CODE, GRAY_FONT_COLOR, NORMAL_FONT_COLOR, UIDROPDOWNMENU_INIT_MENU, StaticPopupDialogs, StaticPopup_Show, UnitPopupMenus, UnitPopupShown, UnitIsBattlePet
-- GLOBALS: CreateFrame, PlaySound, IsShiftKeyDown, IsControlKeyDown, IsModifiedClick, PetJournal_UpdatePetLoadOut, IsAddOnLoaded, ChatEdit_GetActiveWindow
-- GLOBALS: math, string, table, ipairs, pairs, next, hooksecurefunc, type, wipe, select, coroutine, strjoin, unpack, print

local MAX_PET_LEVEL = 25
local MAX_ACTIVE_PETS = 3
local strongTypes, weakTypes = {}, {}

local scanner, timer = nil, 0
local updateFrame = CreateFrame('Frame')
      updateFrame:Hide()
updateFrame:SetScript('OnUpdate', function(self, elapsed)
	timer = timer + elapsed
	if timer > 2 then
		timer = 0
		if not scanner or not coroutine.resume(scanner) then
			self:SetScript('OnUpdate', nil)
			self:Hide()
		end
	end
end)

StaticPopupDialogs['MIDGET_PETTEAM_DELETE'] = {
	text = 'Are you sure you want to delete team %d?',
	button1 = _G.OKAY,
	button2 = _G.CANCEL,
	OnAccept = function(self, teamIndex)
		plugin.DeleteTeam(teamIndex)
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	showAlert = true,
	preferredIndex = 3,
}
StaticPopupDialogs['MIDGET_PETTEAM_RENAME'] = {
	text = 'Enter a name for team %d.',
	button1 = _G.OKAY,
	button2 = _G.CANCEL,
	OnShow = function(self, teamIndex)
		local team = MidgetDB.petBattleTeams[teamIndex]
		self.editBox:SetText(team.name or '')
		self.editBox:SetFocus()
	end,
	OnAccept = function(self, teamIndex)
		local name = self.editBox:GetText()
		if name and name ~= '' then
			MidgetDB.petBattleTeams[teamIndex].name = (name and name ~= '') and name or nil
			plugin.UpdateTabs()
		end
		self:Hide()
	end,
	EditBoxOnEnterPressed = function(self)
		StaticPopupDialogs['MIDGET_PETTEAM_RENAME'].OnAccept(self:GetParent(), self:GetParent().data)
	end,
	EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
	hasEditBox = true,
}


local function CheckPets()
	local missingPets, scanSlot = {}, 1
	for teamIndex, team in ipairs(MidgetDB.petBattleTeams) do
		for slotIndex = 1, MAX_ACTIVE_PETS do
			local pet = team[slotIndex]
			if pet and pet.petID and not (C_PetJournal.GetPetInfoByPetID(pet.petID)) then
				missingPets[pet.petID] = { team = teamIndex, slot = slotIndex, unpack(pet) }
			end
		end
	end
	if not next(missingPets) then return end

	local scanSlotPetID, _, _, _, isLocked = C_PetJournal.GetPetLoadOutInfo(scanSlot)
	if isLocked then
		print('Can\'t scan pet IDs because slot is locked')
		return
	end

	local abilityIDs, abilityLevels = {}, {}
	for index = 1, C_PetJournal.GetNumPets() do
		local petID, id, owned, _, level, _, revoked, _, _, _, _, _, _, _, canBattle = C_PetJournal.GetPetInfoByIndex(index)
		if owned and not revoked and canBattle then
			wipe(abilityIDs); wipe(abilityLevels)
			C_PetJournal.GetPetAbilityList(id, abilityIDs, abilityLevels)

			for _, data in pairs(missingPets) do
				local invalid = false
				for j = 1, 3 do
					local low, lowLevel   = abilityIDs[j], abilityLevels[j]
					local high, highLevel = abilityIDs[j+3], abilityLevels[j+3]
					if data[j] and data[j] ~= low and (level < highLevel or data[j] ~= high) then
						invalid = true
						break
					end
				end
				if not invalid then
					C_PetJournal.SetPetLoadOutInfo(scanSlot, petID, true)
					PetJournal_UpdatePetLoadOut()

					updateFrame:Show()
					coroutine.yield(scanner)

					local petID, ability1, ability2, ability3 = C_PetJournal.GetPetLoadOutInfo(scanSlot)
					local _, _, _, _, _, _, _, name = C_PetJournal.GetPetInfoByPetID(petID)
					print(YELLOW_FONT_COLOR_CODE..name, '|rwith skills', ability1, ability2, ability3)

					for oldPetID, data in pairs(missingPets) do
						local skill1, skill2, skill3 = unpack(data)
						-- print('looking for', skill1, skill2, skill3)
						if skill1 == ability1 and skill2 == ability2 and skill3 == ability3 then
							print(GREEN_FONT_COLOR_CODE, 'Matched!|r', data.team..'/'..data.slot, 'with skills', skill1, skill2, skill3)
							MidgetDB.petBattleTeams[data.team][data.slot].petID = petID

							wipe(missingPets[oldPetID])
							missingPets[oldPetID] = nil
						end
					end
				end
			end
		end
	end

	-- restore previous pet
	C_PetJournal.SetPetLoadOutInfo(scanSlot, scanSlotPetID, true)
	coroutine.yield(scanner)

	for oldPetID, data in pairs(missingPets) do
		local link = 'http://www.wowhead.com/petspecies?filter=cr=15:15:15;crs=0:0:0;crv=' .. strjoin(':', unpack(data))
		print('Your pet '..data.slot..' in team '..data.team..' could not be found. Please check '..link)
	end

	plugin.UpdateTabs()
end

StaticPopupDialogs['MIDGET_PETTEAM_SCAN'] = {
	text = 'It seems some of your pet IDs have changed. Should I try to fix them?|nThis will take some time.',
	button1 = _G.OKAY,
	button2 = _G.CANCEL,
	OnAccept = function()
		scanner = coroutine.create(CheckPets)
		coroutine.resume(scanner)
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local function OnClick(tab, btn)
	PlaySound("igCharacterInfoTab")

	if not tab.teamIndex then
		plugin.AddTeam()
		plugin.UpdateTabs()
	elseif IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() then
		plugin.DumpTeam(tab.teamIndex)
	elseif IsShiftKeyDown() and btn == 'RightButton' then
		StaticPopup_Show('MIDGET_PETTEAM_RENAME', tab.teamIndex, nil, tab.teamIndex)
	elseif IsControlKeyDown() and btn == 'RightButton' then
		StaticPopup_Show('MIDGET_PETTEAM_DELETE', tab.teamIndex, nil, tab.teamIndex)
		-- plugin.DeleteTeam(tab.teamIndex)
	elseif tab.teamIndex == MidgetDB.petBattleTeams.selected then
		-- refresh active team
		plugin.SaveTeam(tab.teamIndex)
		plugin.UpdateTabs()
	else
		plugin.LoadTeam(tab.teamIndex)
		plugin.UpdateTabs()
	end
end
local function GetTab(index, noCreate)
	local tab = _G["PetJournalTab"..index]
	if not tab and not noCreate then
		tab = CreateFrame("CheckButton", "$parentTab"..index, _G["PetJournal"], "SpellBookSkillLineTabTemplate", index)
		if index == 1 then
			tab:SetPoint("TOPLEFT", "$parent", "TOPRIGHT", 0, -36)
		else
			tab:SetPoint("TOPLEFT", "$parentTab"..(index-1), "BOTTOMLEFT", 0, -22)
		end

		tab:RegisterForClicks("AnyUp")
		tab:SetScript("OnEnter", addon.ShowTooltip)
		tab:SetScript("OnLeave", addon.HideTooltip)
		tab:SetScript("OnClick", OnClick)
	end
	return tab
end

local petTypeNone = '|TInterface\\COMMON\\Indicator-Gray:0|t'
-- local petTypeNone = '|TInterface\\COMMON\\ReputationStar:14:14:0:1:32:32:0:16:0:16|t'
-- local petTypeNone = '|TInterface\\COMMON\\friendship-heart:0:0:1:-2|t'
local function GetPetTypeIcon(i)
	if not i or not PET_TYPE_SUFFIX[i] then return petTypeNone end
	return '|TInterface\\PetBattles\\PetIcon-'..PET_TYPE_SUFFIX[i]..':14:14:0:0:128:256:63:102:129:168|t'
end
local function GetPetTypeStrength(petType, seperator)
	if not petType or not strongTypes[petType] then return petTypeNone end
	seperator = seperator or ''

	local strenths = strongTypes[petType]
	local string
	for i, otherType in ipairs(strenths) do
		string = (string and string..seperator or '') .. GetPetTypeIcon(otherType)
	end
	return string or petTypeNone
end
local function GetPetTypeWeakness(petType, seperator)
	if not petType or not strongTypes[petType] then return petTypeNone end
	seperator = seperator or ''

	local weaknesses = weakTypes[petType]
	local string
	for i, otherType in ipairs(weaknesses) do
		string = (string and string..seperator or '') .. GetPetTypeIcon(otherType)
	end
	return string or petTypeNone
end

local function SetTeamTooltip(tab, tooltip)
	if not tab.teamIndex then return end
	local team = MidgetDB.petBattleTeams[tab.teamIndex]
	local weaknesses = ''

	tooltip:AddDoubleLine(team.name or "Team "..tab.teamIndex, '|TInterface\\PetBattles\\BattleBar-AbilityBadge-Weak:20|t ')
	for i, member in ipairs(team) do
		local petID = member.petID
		local speciesID, customName, level, xp, maxXp, displayID, isFavorite, name, icon, petType = C_PetJournal.GetPetInfoByPetID(petID)
		local _, _, _, _, quality = C_PetJournal.GetPetStats(petID)

		-- ability effectiveness, w/o non-attack-moves
		local ability1 = member[1]
			  ability1 = ability1 and not select(8, C_PetBattles.GetAbilityInfoByID(ability1))
			  					  and select(3, C_PetJournal.GetPetAbilityInfo(ability1)) or nil
		local ability2 = member[2]
			  ability2 = ability2 and not select(8, C_PetBattles.GetAbilityInfoByID(ability2))
			  					  and select(3, C_PetJournal.GetPetAbilityInfo(ability2)) or nil
		local ability3 = member[3]
			  ability3 = ability3 and not select(8, C_PetBattles.GetAbilityInfoByID(ability3))
			  					  and select(3, C_PetJournal.GetPetAbilityInfo(ability3)) or nil

		tooltip:AddDoubleLine(
			string.format("%3$d %1$s %5$s%2$s|r%4$s",
				GetPetTypeIcon(petType),
				customName or name or '',
				level or 0,
				level and level < MAX_PET_LEVEL and ' ('..math.floor(xp/maxXp*100)..'%)' or '',
				ITEM_QUALITY_COLORS[(quality or 1) - 1].hex
			),
			string.format("|TInterface\\PetBattles\\BattleBar-AbilityBadge-Strong:20|t %1$s%2$s%3$s",
				GetPetTypeStrength(ability1),
				GetPetTypeStrength(ability2),
				GetPetTypeStrength(ability3)
			)
		)

		weaknesses = weaknesses .. GetPetTypeWeakness(petType)
	end

	tooltip:AddLine(nil)
	tooltip:AddDoubleLine('SHIFT+Left: link|r', 'SHIFT+Right: rename|r',
		GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b,
		GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	tooltip:AddDoubleLine(' ', 'CTRL+Right: delete|r', nil, nil, nil, GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)

	local right = _G[tooltip:GetName() .. 'TextRight1']
	right:SetFontObject('GameTooltipText')
	right:SetText(right:GetText() .. weaknesses)
end

function plugin.AddTeam()
	table.insert(MidgetDB.petBattleTeams, {})
	local index = #MidgetDB.petBattleTeams
	plugin.SaveTeam(index)
	plugin.LoadTeam(index)
end
function plugin.SaveTeam(index, name)
	index = index or MidgetDB.petBattleTeams.selected
	if not index then return end

	local team = MidgetDB.petBattleTeams[index]
		  team.name = (name and name ~= '') and name or nil
	-- ipairs: clear old pets but keep other team attributes
	for i, member in ipairs(team) do
		wipe(team[i])
		team[i].petID = nil
	end
	for i = 1, MAX_ACTIVE_PETS do
		if not team[i] then team[i] = {} end
		team[i].petID, team[i][1], team[i][2], team[i][3] = C_PetJournal.GetPetLoadOutInfo(i)
	end
end
function plugin.DeleteTeam(index)
	if MidgetDB.petBattleTeams[index] then
		table.remove(MidgetDB.petBattleTeams, index)
		plugin.LoadTeam(#MidgetDB.petBattleTeams)
	end
end
function plugin.LoadTeam(index)
	local team = MidgetDB.petBattleTeams[index]
	for i = 1, MAX_ACTIVE_PETS do
		if team[i] and team[i].petID then
			local petID = team[i].petID
			local ability1, ability2, ability3 = team[i][1], team[i][2], team[i][3]

			C_PetJournal.SetPetLoadOutInfo(i, petID, true) -- add true to mark that it's us modifying stuff
			C_PetJournal.SetAbility(i, 1, ability1)
			C_PetJournal.SetAbility(i, 2, ability2)
			C_PetJournal.SetAbility(i, 3, ability3)
		else
			-- make slot empty
			-- FIXME: C_PetJournal.SetPetLoadOutInfo(i, 0) used to work but doesn't any more
		end
	end
	MidgetDB.petBattleTeams.selected = index
	PetJournal_UpdatePetLoadOut()
end
function plugin.DumpTeam(index)
	local output = ''
	local team = MidgetDB.petBattleTeams[index]
	for i = 1, MAX_ACTIVE_PETS do
		if team[i] and team[i].petID then
			output = output .. C_PetJournal.GetBattlePetLink(team[i].petID)
		end
	end
	-- output = (team.name or 'Team '..index) .. ' ' .. output
	ChatEdit_GetActiveWindow():Insert(output)
end

function plugin.UpdateTabs()
	local selected = MidgetDB.petBattleTeams.selected
	for index, team in ipairs(MidgetDB.petBattleTeams) do
		local speciesID, _, _, _, _, _, _, _, icon = C_PetJournal.GetPetInfoByPetID(team[1].petID)
		local tab = GetTab(index)
		      tab:SetChecked(index == selected)
		      tab:GetNormalTexture():SetTexture(icon)
		      tab:Show()

		tab.teamIndex = index
		tab.tiptext = SetTeamTooltip
		if not speciesID and not scanner then
			StaticPopup_Show('MIDGET_PETTEAM_SCAN')
		end
	end

	local numTeams = #MidgetDB.petBattleTeams + 1
	local tab = GetTab(numTeams)
	tab:SetChecked(nil)
	tab:GetNormalTexture():SetTexture("Interface\\GuildBankFrame\\UI-GuildBankFrame-NewTab") -- "Interface\\PaperDollInfoFrame\\Character-Plus"
	tab:Show()

	tab.teamIndex = nil
	tab.tooltip = GREEN_FONT_COLOR_CODE..ADD_ANOTHER

	numTeams = numTeams + 1
	while GetTab(numTeams, true) do
		GetTab(numTeams, true):Hide()
		numTeams = numTeams + 1
	end
end

function plugin.Update()
	if not _G['PetJournal']:IsVisible() then return end
	plugin.SaveTeam()
	plugin.UpdateTabs()
end


-- ================================================
--  move pet battle frame down a little
-- ================================================
local function MovePetBatteFrame()
	local offset = MidgetDB.PetBattleFrameOffset
	if not MidgetDB.movePetBattleFrame or offset == 0 then return end
	PetBattleFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, offset)
end

-- ================================================
-- add show in journal entry to unit dropdowns
-- ================================================
local function CustomizeDropDowns()
	local dropDown = UIDROPDOWNMENU_INIT_MENU
	local which = dropDown.which
	if which then
		for index, value in ipairs(UnitPopupMenus[which]) do
			if value == "PET_SHOW_IN_JOURNAL" and not (dropDown.unit and UnitIsBattlePet(dropDown.unit)) then
				UnitPopupShown[1][index] = 0
				break
			end
		end
	end
end

-- ================================================
--  loading ...
-- ================================================
local function InitializePetJournal(event, arg1)
	if arg1 ~= 'Blizzard_PetJournal' then return end

	if not MidgetDB.petBattleTeams then MidgetDB.petBattleTeams = {} end
	for teamIndex, team in ipairs(MidgetDB.petBattleTeams) do
		for memberIndex = 1, MAX_ACTIVE_PETS do
			local petID = team[memberIndex].petID
			if petID:find('^0x') then
				-- convert petid to WoD format
				team[memberIndex].petID = 'BattlePet-0-'..petID:sub(-12)
			end
		end
	end

	hooksecurefunc('PetJournal_UpdatePetLoadOut', plugin.Update)

	for i = 1, C_PetJournal.GetNumPetTypes() do
		if not strongTypes[i] then strongTypes[i] = {} end
		if not   weakTypes[i] then   weakTypes[i] = {} end

		for j = 1, C_PetJournal.GetNumPetTypes() do
			local modifier = C_PetBattles.GetAttackModifier(i, j)
			if modifier > 1 then
				table.insert(strongTypes[i], j)
			elseif modifier < 1 then
				table.insert(weakTypes[i], j)
			end
		end
	end

	plugin:UnregisterEvent('ADDON_LOADED')
end

function plugin:OnEnable()
	MovePetBatteFrame()
	-- hooksecurefunc("UnitPopup_HideButtons", CustomizeDropDowns)
	-- table.insert(UnitPopupMenus["TARGET"], #UnitPopupMenus["TARGET"], "PET_SHOW_IN_JOURNAL")

	if IsAddOnLoaded('Blizzard_PetJournal') then
		InitializePetJournal()
	else
		self:RegisterEvent('ADDON_LOADED', InitializePetJournal)
	end
end
