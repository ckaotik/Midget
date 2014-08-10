local addonName, ns, _ = ...
local plugin = {}
-- local ns.battlepets = plugin

-- GLOBALS: _G, UIParent, MidgetDB, PetBattleFrame, C_PetJournal, C_PetBattles, GameTooltip, ITEM_QUALITY_COLORS, PET_TYPE_SUFFIX, ADD_ANOTHER, GREEN_FONT_COLOR_CODE, YELLOW_FONT_COLOR_CODE, GRAY_FONT_COLOR, NORMAL_FONT_COLOR, UIDROPDOWNMENU_INIT_MENU, UnitPopupMenus, UnitPopupShown, UnitIsBattlePet
-- GLOBALS: CreateFrame, PlaySound, IsShiftKeyDown, IsModifiedClick, PetJournal_UpdatePetLoadOut, IsAddOnLoaded, ChatEdit_GetActiveWindow
-- GLOBALS: math, string, table, ipairs, hooksecurefunc, type, wipe, select, coroutine, strjoin, unpack, print

local MAX_PET_LEVEL = 25
local MAX_ACTIVE_PETS = 3
local strongTypes, weakTypes = {}, {}

local scanner
local updateFrame = CreateFrame('Frame')
      updateFrame:Hide()
local timer = 0
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
	return C_PetJournal.GetBattlePetLink(petID)
	--[[ local _, maxHealth, power, speed, quality = C_PetJournal.GetPetStats(petID)
	local speciesID, customName, level, _, _, _, _, name, icon, petType = C_PetJournal.GetPetInfoByPetID(petID)
	-- name = name:len() > 10 and name:gsub("%s?(.[\128-\191]*)%S+%s", "%1·") or name

	local petLink = ("%1$s|Hbattlepet:%2$s:%3$s:%4$s:%5$s:%6$s:%7$s:%8$s|h[%9$s]|h|r"):format(ITEM_QUALITY_COLORS[quality - 1].hex, speciesID, level, quality-1, maxHealth, power, speed, petID, name)
	return petLink--]]
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
			output = output .. C_PetJournal.GetBattlePetLink(team[i].petID) -- GetPetLink(team[i].petID)
		end
	end
	-- output = (team.name or 'Team '..index) .. ' ' .. output
	ChatEdit_GetActiveWindow():Insert(output)
end

local battlepets = LibStub('AceAddon-3.0'):NewAddon(addonName..'BattlePets', 'AceEvent-3.0')
local scanSlot = 1
local function CompareSlotPet(scanSlot)
	local petID, ability1, ability2, ability3 = C_PetJournal.GetPetLoadOutInfo(scanSlot)
	local _, _, _, _, _, _, _, name = C_PetJournal.GetPetInfoByPetID(petID)
	print(YELLOW_FONT_COLOR_CODE..name, '|rwith skills', ability1, ability2, ability3)

	for teamIndex, team in ipairs(MidgetDB.petBattleTeams) do
		local teamDesc = teamIndex
		for slotIndex = 1, MAX_ACTIVE_PETS do
			local pet = team[slotIndex]
			if pet and pet.petID and not (C_PetJournal.GetPetInfoByPetID(pet.petID)) then
				local skill1, skill2, skill3 = unpack(pet)
				teamDesc = teamDesc .. ' / ' .. strjoin(' ', skill1, skill2, skill3)
				if ability1 == skill1 and ability2 == skill2 and ability3 == skill3 then
					-- note: this will not work correctly when using multiple pets with the same skill set
					-- since we don't have level or quality info to compare
					print(GREEN_FONT_COLOR_CODE, 'Matched!|r', teamIndex, slotIndex, 'with skills', skill1, skill2, skill3)
					pet.petID = petID
				end
			end
		end
		-- print('comparing against', teamDesc)
	end
end

-- TODO: we could also scan the other way around: find missing petIDs and scan journal for pets that may learn those skills. Then, set that pet and check if we were correct
local function CheckPetIDs()
	local scanSlotPetID, _, _, _, isLocked = C_PetJournal.GetPetLoadOutInfo(scanSlot)
	if isLocked then
		print('Can\'t scan pet IDs because slot is locked')
		return
	end

	for index = 1, C_PetJournal.GetNumPets() do
		local petID, _, owned, _, _, _, revoked, name, _, _, _, _, _, _, canBattle = C_PetJournal.GetPetInfoByIndex(index)
		if owned and not revoked and canBattle then
			-- /script C_PetJournal.SetPetLoadOutInfo(2, "0x000000000308B99D", true)
			C_PetJournal.SetPetLoadOutInfo(scanSlot, petID, true)
			PetJournal_UpdatePetLoadOut()

			updateFrame:Show()
			coroutine.yield(scanner)

			local scanSlotPetID = C_PetJournal.GetPetLoadOutInfo(scanSlot)
			CompareSlotPet(scanSlot)
		end
	end
	-- restore previous pet
	C_PetJournal.SetPetLoadOutInfo(scanSlot, scanSlotPetID, true)
end

StaticPopupDialogs['MIDGET_PETID_SCAN'] = {
  text = 'It seems some of your pet IDs are outdated. Would you like me to try and fix them?|nThis will take quite some time.',
  button1 = _G.OKAY,
  button2 = _G.CANCEL,
  OnAccept = function()
    scanner = coroutine.create(CheckPetIDs)
	coroutine.resume(scanner)
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  preferredIndex = 3,
}

function plugin.UpdateTabs()
	local selected = MidgetDB.petBattleTeams.selected
	for index, team in ipairs(MidgetDB.petBattleTeams) do
		local speciesID, _, _, _, _, _, _, _, icon = C_PetJournal.GetPetInfoByPetID(team[1].petID)
		local tab = GetTab(index)
		tab:SetChecked(index == selected)
		tab:GetNormalTexture():SetTexture(icon)
		tab:Show()

		tab.teamIndex = index
		tab.tooltip = SetTeamTooltip
		if not speciesID then
			StaticPopup_Show('MIDGET_PETID_SCAN')
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

local function initialize(frame, event, arg1)
	if (arg1 == addonName or arg1 == 'Blizzard_PetJournal') and IsAddOnLoaded('Blizzard_PetJournal') then
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
ns.RegisterEvent('ADDON_LOADED', function(self, event, arg1)
	if arg1 ~= addonName then return end

	MovePetBatteFrame()
	-- hooksecurefunc("UnitPopup_HideButtons", CustomizeDropDowns)
	-- table.insert(UnitPopupMenus["TARGET"], #UnitPopupMenus["TARGET"], "PET_SHOW_IN_JOURNAL")

	ns.UnregisterEvent('ADDON_LOADED', 'init_battlepet')
end, 'init_battlepet')
