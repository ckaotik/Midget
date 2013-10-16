local addonName, ns, _ = ...
local plugin = {}
-- local ns.battlepets = plugin

-- GLOBALS: _G, MidgetDB, C_PetJournal, C_PetBattles, GameTooltip, ITEM_QUALITY_COLORS, PET_TYPE_SUFFIX, ADD_ANOTHER, GREEN_FONT_COLOR_CODE, GRAY_FONT_COLOR_CODE, NORMAL_FONT_COLOR, CreateFrame, PlaySound, IsShiftKeyDown, PetJournal_UpdatePetLoadOut
-- GLOBALS: math, string, table, ipairs, hooksecurefunc, type, wipe, select

--[[
	local function GetBattlePetOwnedStatus(speciesID) -- , level, quality)
		if not speciesID then return end

		local maxLevel, maxLevelRarity
		local maxRarity, maxRarityLevel
		for index = 1, C_PetJournal.GetNumPets() do
			local petID, petSpecies, owned, _, level = C_PetJournal.GetPetInfoByIndex(index)

			if owned and petSpecies == speciesID then
				local _, _, _, _, rarity = C_PetJournal.GetPetStats(petID)
				rarity = rarity - 1

				if not maxRarity or rarity > maxRarity then
					maxRarity = rarity
					maxRarityLevel = level
				end
				if not maxLevel or level > maxLevel then
					maxLevel = level
					maxLevelRarity = rarity
				end
			end
		end

		local rarityInfo = maxRarity and string.format('%s%d|r', ITEM_QUALITY_COLORS[maxRarity].hex, maxRarityLevel)
		local levelInfo  = maxLevel and string.format('%s%d|r', ITEM_QUALITY_COLORS[maxLevelRarity].hex, maxLevel)

		local owned = C_PetJournal.GetOwnedBattlePetString(speciesID)
		if not owned then return end

		-- comparing to ITEM_PET_KNOWN
		-- local current, max 	= owned:match('%((%d+)/(%d+)%)')
		-- local collected 	= owned:gsub('%((%d+)/(%d+)%)', '')

		local newInfo = string.format('%s|r: %s', owned, rarityInfo)
		-- don't show twice if identical
		if not (maxLevel == maxRarityLevel and maxRarity == maxLevelRarity) then
			newInfo = newInfo .. ', ' .. levelInfo
		end

		return newInfo
	end

	local function UpdateBattlePetTooltip(speciesID, level, quality)
		local newInfo = GetBattlePetOwnedStatus(speciesID, level, quality)
		if not newInfo then return end
		if BattlePetTooltip:IsVisible() then
			BattlePetTooltip.Owned:SetText(newInfo)
		end
		if FloatingBattlePetTooltip:IsVisible() then
			FloatingBattlePetTooltip.Owned:SetText(newInfo)
		end
	end

	local function UpdateEnemyBattlePetUnitTooltip(self, petOwner, petIndex)
		if self.CollectedText:IsVisible() then
			local speciesID = C_PetBattles.GetPetSpeciesID(petOwner, petIndex)
			local level = C_PetBattles.GetLevel(petOwner, petIndex)
			local quality = C_PetBattles.GetBreedQuality(petOwner, petIndex)
			local newInfo = GetBattlePetOwnedStatus(speciesID, level, quality)
			if not newInfo then return end

			self.CollectedText:SetText(newInfo)
			self.CollectedText:Show()
		end
	end

	local function UpdateBattlePetUnitTooltip(self)
		local _, unit = self:GetUnit()

		if unit then
			if UnitIsWildBattlePet(unit) then
				local speciesID = UnitBattlePetSpeciesID(unit)
				local level = UnitLevel(unit)
				local newInfo = GetBattlePetOwnedStatus(speciesID, level, -1)
				if not newInfo then return end
				local owned = C_PetJournal.GetOwnedBattlePetString(speciesID):gsub('|c........', '')

				for line = 1, self:NumLines() do
					local lineText = _G['GameTooltipTextLeft'..line]:GetText()
					if lineText == owned then
						_G['GameTooltipTextLeft'..line]:SetText(newInfo)
					end
				end
			end
		end
	end
--]]

local MAX_PET_LEVEL = 25
local MAX_ACTIVE_PETS = 3
local strongTypes, weakTypes = {}, {}

local function OnLeave(tab) GameTooltip:Hide() end
local function OnEnter(tab)
	GameTooltip:SetOwner(tab, "ANCHOR_RIGHT")
	GameTooltip:ClearLines()

	if tab.tooltip then
		if type(tab.tooltip) == 'string' and tab.tooltip ~= "" then
			GameTooltip:AddLine(tab.tooltip, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
		elseif type(tab.tooltip) == 'function' then
			tab.tooltip(tab, GameTooltip)
		end
		GameTooltip:Show()
	end
end
local function OnClick(tab, btn)
	PlaySound("igCharacterInfoTab")

	if not tab.teamIndex then
		plugin.AddTeam()
	elseif IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() then
		plugin.DumpTeam(tab.teamIndex)
	elseif IsShiftKeyDown() and btn == 'RightButton' then
		plugin.DeleteTeam(tab.teamIndex)
	elseif tab.teamIndex == MidgetDB.petBattleTeams.selected then
		-- refresh active team
		plugin.SaveTeam(tab.teamIndex)
	else
		plugin.LoadTeam(tab.teamIndex)
	end
	plugin.UpdateTabs()
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
		tab:SetScript("OnEnter", OnEnter)
		tab:SetScript("OnLeave", OnLeave)
		tab:SetScript("OnClick", OnClick)
	end
	return tab
end

local petTypeNone = '|TInterface\\Common\\ReputationStar:14:14:0:1:32:32:0:16:0:16|t'
-- local petTypeNone = '|TInterface\\COMMON\\friendship-heart:0:0:1:-2|t'
local function GetPetTypeIcon(i)
	if not i or not PET_TYPE_SUFFIX[i] then return petTypeNone end
	return '|TInterface\\PetBattles\\PetIcon-'..PET_TYPE_SUFFIX[i]..':14:14:0:0:128:256:63:102:129:168|t'
end

local abilities, abilityLevels = {}, {}
local function GetPetLink(petID)
	local _, maxHealth, power, speed, quality = C_PetJournal.GetPetStats(petID)
	local speciesID, customName, level, _, _, _, _, name, icon, petType = C_PetJournal.GetPetInfoByPetID(petID)
	-- name = name:len() > 10 and name:gsub("%s?(.[\128-\191]*)%S+%s", "%1·") or name

	local petLink = ("%1$s|Hbattlepet:%2$s:%3$s:%4$s:%5$s:%6$s:%7$s:%8$s|h[%9$s]|h|r"):format(ITEM_QUALITY_COLORS[quality - 1].hex, speciesID, level, quality-1, maxHealth, power, speed, petID, name)
	return petLink
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
				customName or name,
				level,
				level < MAX_PET_LEVEL and ' ('..math.floor(xp/maxXp*100)..'%)' or '',
				ITEM_QUALITY_COLORS[quality - 1].hex
			),
			string.format("|TInterface\\PetBattles\\BattleBar-AbilityBadge-Strong:20|t %1$s%2$s%3$s",
				GetPetTypeStrength(ability1),
				GetPetTypeStrength(ability2),
				GetPetTypeStrength(ability3)
			)
		)

		weaknesses = weaknesses .. GetPetTypeWeakness(petType)
	end

	-- tooltip:AddLine('Hier könnte Ihre Werbung stehen!', nil, nil, nil, true)
	tooltip:AddLine(nil)
	tooltip:AddLine('SHIFT Left-click to link|r', GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)
	tooltip:AddLine('SHIFT Right-click to delete|r', GRAY_FONT_COLOR.r, GRAY_FONT_COLOR.g, GRAY_FONT_COLOR.b)

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
		  team.name = name
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

			C_PetJournal.SetPetLoadOutInfo(i, petID, true) -- add marker that it's us modifying stuff
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
			output = output .. GetPetLink(team[i].petID)
		end
	end
	-- output = (team.name or 'Team '..index) .. ' ' .. output
	ChatEdit_GetActiveWindow():Insert(output)
end

function plugin.UpdateTabs()
	local selected = MidgetDB.petBattleTeams.selected
	for index, team in ipairs(MidgetDB.petBattleTeams) do
		local _, _, _, _, _, _, _, _, icon = C_PetJournal.GetPetInfoByPetID(team[1].petID)
		local tab = GetTab(index)
		tab:SetChecked(index == selected)
		tab:GetNormalTexture():SetTexture(icon)
		tab:Show()

		tab.teamIndex = index
		tab.tooltip = SetTeamTooltip
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

local function initialize(frame, event, arg1)
	if (arg1 == addonName or arg1 == 'Blizzard_PetJournal') and IsAddOnLoaded('Blizzard_PetJournal') then
		--[[
			hooksecurefunc('BattlePetToolTip_Show', UpdateBattlePetTooltip)
			hooksecurefunc('FloatingBattlePet_Show', UpdateBattlePetTooltip)
			hooksecurefunc('PetBattleUnitTooltip_UpdateForUnit', UpdateEnemyBattlePetUnitTooltip)
			GameTooltip:HookScript('OnTooltipSetUnit', UpdateBattlePetUnitTooltip)
		--]]

		if not MidgetDB.petBattleTeams then MidgetDB.petBattleTeams = {} end
		hooksecurefunc("PetJournal_UpdatePetLoadOut", plugin.Update)

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

		ns.UnregisterEvent('ADDON_LOADED', 'battlepet')
	end
end
ns.RegisterEvent('ADDON_LOADED', initialize, 'battlepet')

