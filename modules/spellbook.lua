local addonName, ns, _ = ...
-- GLOBALS: _G, CliqueDB3, MAX_SPELLS, SEARCH, BOOKTYPE_SPELL, SPELLBOOK_PAGENUMBERS, SPELLS_PER_PAGE, NUM_ACTIONBAR_PAGES, NUM_ACTIONBAR_BUTTONS, UIFrameFlash, UIFrameFlashStop, EditBox_ClearFocus, SpellBookFrame, SpellBookFrames, SpellBookPage1, SpellBookPage2
-- GLOBALS: IsAddOnLoaded, IsAltKeyDown, CreateFrame, PlaySound, ToggleSpellBook, FindSpellBookSlotBySpellID, SpellBookTabFlashFrame, SpellBookFrame_Update, SpellBook_GetCurrentPage, SpellBook_GetAutoCastShine, AutoCastShine_AutoCastStart, GetNumSpellTabs, GetSpellInfo, GetSpellTabInfo, GetSpellBookItemInfo, GetSpellBookItemName, GetSpellDescription, GetSpellLink, IsSpellKnown, IsPassiveSpell, GetUnitName, GetRealmName, GetMacroBody, GetFlyoutInfo, GetFlyoutSlotInfo, GetActionInfo, GetShapeshiftFormInfo, GetNumShapeshiftForms, SecureCmdOptionParse
-- GLOBALS: hooksecurefunc, string, math, select, ipairs, tonumber, wipe, type

local function GetSpellButtonByID(index)
	-- recalculate proper button offset, as counting is column-wise but display is per row
	index = index == 0 and 12 or (index - 6) * 2
	if index <= 0 then
		index = index + (2*6 - 1)
	end
	return _G["SpellButton"..index]
end

-- ================================================
-- Alt-CLick for Shinies!
-- ================================================
local function ShineSlot(index)
	local slot = GetSpellButtonByID(index)
		  slot:SetChecked(true)
	if not slot.shine then
		slot.shine = SpellBook_GetAutoCastShine()
		slot.shine:Show()
		slot.shine:SetParent(slot)
		slot.shine:SetPoint("CENTER", slot, "CENTER")
	end
	AutoCastShine_AutoCastStart(slot.shine)
end

ns.RegisterEvent("ADDON_LOADED", function(self, event, arg1)
	if arg1 ~= addonName then return end
	hooksecurefunc("SetItemRef", function(link)
		if not IsAltKeyDown() then return end

		local spellID = link:match("^spell:([^:]+)")
		spellID = spellID and tonumber(spellID)
		if spellID and spellID > 0 then
			local spellBookIndex = FindSpellBookSlotBySpellID(spellID)
			if not spellBookIndex then return end

			local tab = 1
			local _, _, offset, tabMaxIndex = GetSpellTabInfo(tab)
			while tabMaxIndex > 0 and spellBookIndex > tabMaxIndex+offset do
				tab = tab + 1
				_, _, offset, tabMaxIndex = GetSpellTabInfo(tab)
			end

			SpellBookFrame.selectedSkillLine = tab
			SPELLBOOK_PAGENUMBERS[ tab ] = math.ceil((spellBookIndex - offset) / SPELLS_PER_PAGE)
			SpellBookFrame_Update()
			if not SpellBookFrame:IsVisible() then
				ToggleSpellBook(BOOKTYPE_SPELL)
			end
			ShineSlot((spellBookIndex - offset) % SPELLS_PER_PAGE)

			-- PickupSpell
			-- if ( IsModifiedClick("PICKUPACTION") ) then
			--	PickupSpellBookItem(spellBookIndex, BOOKTYPE_SPELL)
		end
	end)
	ns.UnregisterEvent("ADDON_LOADED", "openSpellBook")
end, "openSpellBook")

-- ================================================
-- SpellSearch
-- ================================================
local usedSpells = {}
local AUTOATTACK = 6603
local relevantMacroCommands = {
	["cast"] = true,
	["use"] = true,
	["castsequence"] = true,
	["castrandom"] = true,
}
local ignoredSpells = { 125439, 5225, 83958 }

local function GetSpellID(spellName)
	if not spellName then
		return
	elseif type(spellName) == "number" then
		return spellName
	else
		spellName = string.trim(spellName)
		spellName = GetSpellLink(spellName) or spellName
		spellName = spellName and spellName:match("Hspell:(%d+)")
		return spellName and tonumber(spellName) or nil
	end
end
local function ParseMacroSpells(macro)
	local command, commandType
	for i, action in ipairs({ string.split("\n", macro) }) do
		commandType, command = string.match(action, "/([^%s]+)%s*(.*)")
		if commandType == 'startattack' then
			usedSpells[AUTOATTACK] = true
		elseif relevantMacroCommands[commandType] then
			-- remove conditions that do not contain [spec]
			command = command:gsub('(%b[])', function(conditions)
				local condition = conditions:match('(n?o?spec:[^%],]+)')
				return condition and '['..condition..']' or ''
			end)
			command = command:gsub('^reset=.- ', ' ') -- remove castsequence conditions

			local splitChar = ';'
			if commandType == 'castsequence' or commandType == 'castrandom' then
				splitChar = ','
			end

			for snippet in command:gmatch('[^'..splitChar..']+') do
				local spell = SecureCmdOptionParse(snippet)
				      spell = spell and spell:gsub('^!([^ ])', ' %1') -- fix !ToggleSpell
				local spellID = GetSpellID(spell)
				if spellID then
					usedSpells[ tonumber(spellID) ] = spell
				end
			end
		end
	end
end

local function ScanActionButtons()
	local actionType, action, spellID
	local numActionButtons = (NUM_ACTIONBAR_PAGES + 4) * NUM_ACTIONBAR_BUTTONS -- regular + 2 right + 2 bottom bars

	usedSpells = wipe(usedSpells)
	for i, spellID in ipairs(ignoredSpells) do
		usedSpells[spellID] = true
	end

	for slot = 1, numActionButtons do
		actionType, action, _, spellID = GetActionInfo(slot)
		-- companion, equipmentset, flyout, item, macro, spell

		if actionType == "spell" then
			usedSpells[action] = true
		elseif actionType == "flyout" then
			usedSpells[ -1*action ] = true
		elseif actionType == "macro" and action > 0 then
			local macro = GetMacroBody(action)
			ParseMacroSpells(macro)
		end
	end

	for slot = 1, GetNumShapeshiftForms() do
		_, spellID = GetShapeshiftFormInfo(slot)
		spellID = GetSpellID(spellID)
		if spellID then
			usedSpells[ tonumber(spellID) ] = true
		end
	end

	if IsAddOnLoaded("Clique") then
		local db = CliqueDB3 and CliqueDB3.profiles and CliqueDB3.profiles[ GetUnitName("player") .. " - " .. GetRealmName("player") ]
			  db = db and db.bindings or {}
		for i, binding in ipairs(db) do
			if binding.type == "spell" then
				spellID = GetSpellID(binding.spell)
				if spellID then
					usedSpells[ tonumber(spellID) ] = true
				end
			elseif binding.type == "macro" then
				ParseMacroSpells(binding.macrotext)
			end
		end
	end

	-- [TODO] scan macaroon and whatever else there might be
end

local function NotifyUnusedSpell(spellID, ...)
	local link = GetSpellLink(spellID)
	local msg = string.format("Unused spell detected: %s", link or spellID)
	ns.Print(msg)
end

local function ScanSpellBook()
	local numSpells = 0
	for i = 1, 2 do -- only consider general + spec spells, ignore pets and the likes
		numSpells = numSpells + (select(4, GetSpellTabInfo(i)) or 0)
		-- GetNumSpellTabs() -- [TODO] improve, if I'm bored enough
		-- name, texture, offset, num, isGuild, spec = GetSpellTabInfo(i) -- spec == 0 => my spec
	end
	if numSpells == 0 then numSpells = MAX_SPELLS end

	local skillType, spellID, actionID, flyoutSize, flyoutKnown, size, known, spell, hasMissing
	for index = 1, numSpells do
		skillType, actionID = GetSpellBookItemInfo(index, BOOKTYPE_SPELL)
		if not skillType then break end

		if skillType == "SPELL" and actionID then
			-- horrible procedure to handle transforming spells, e.g. talented or multi-stance
			spell = GetSpellBookItemName(index, BOOKTYPE_SPELL)   -- gets overlayed spell name
			spell = GetSpellInfo(spell) or GetSpellInfo(actionID) -- gets the spell base name
			spellID = GetSpellID(spell) -- can now get overlayed spell info
			-- print('spellbook', index, spell, spellID, actionID, ';', IsSpellKnown(actionID), IsSpellKnown(spellID))
			if IsSpellKnown(actionID) and not IsPassiveSpell(actionID) and not usedSpells[spellID] and not usedSpells[actionID] then
				hasMissing = true
				NotifyUnusedSpell(spellID)
			end

		elseif skillType == "FLYOUT" and actionID then
			_, _, size, flyoutKnown = GetFlyoutInfo(actionID)
			if not usedSpells[ -1*actionID ] then
				for k = 1, (flyoutKnown and size or 0) do
					spellID, _, known = GetFlyoutSlotInfo(actionID, k)
					if known and spellID and not IsPassiveSpell(spellID) and not usedSpells[spellID] then
						hasMissing = true
						NotifyUnusedSpell(spellID)
					end
				end
			end
		end
	end
	if not hasMissing then
		ns.Print("All spells are bound! Well done.")
	end
end
ns.ScanSpells = function()
	ScanActionButtons()
	ScanSpellBook()
end

-- ================================================
-- SpellBookSearch
-- ================================================
local ItemSearch = LibStub('LibItemSearch-1.0')
local simpleSearch = ItemSearch:GetTypedSearch('text')
if not simpleSearch then
	ItemSearch:RegisterTypedSearch{
		id = 'text',
		canSearch = function(self, _, search)
			return search
		end,
		findItem = function(self, text, _, search)
			return text:lower():find(search)
		end,
	}
	simpleSearch = ItemSearch:GetTypedSearch('text')
end

local function SearchInSpell(index, searchString)
	if not index then return end
	searchString = searchString or ""

	local _, spellID 	= GetSpellBookItemInfo(index, BOOKTYPE_SPELL)
	local name, subText = GetSpellBookItemName(index, BOOKTYPE_SPELL)
	local description 	= GetSpellDescription(spellID)

	return (name and ItemSearch:UseTypedSearch(simpleSearch, name, nil, searchString))
		or (subText and ItemSearch:UseTypedSearch(simpleSearch, subText, nil, searchString))
		or (description and ItemSearch:UseTypedSearch(simpleSearch, description, nil, searchString))
end

function ns.SearchInSpellBook()
	local searchString = SpellBookFrame.searchString or ""
	local offset, numSpells, isMatch, matchInTab, page

	local anyMatch = false
	for tab = 1, GetNumSpellTabs() do
		_, _, offset, numSpells = GetSpellTabInfo(tab)
		page = SpellBook_GetCurrentPage() or 1

		matchInTab = false
		if numSpells > 0 then
			for i = 1, numSpells do
				isMatch 	= SearchInSpell(i + offset, searchString)
				matchInTab 	= matchInTab or isMatch
				anyMatch 	= anyMatch or isMatch

				if SpellBookFrame.selectedSkillLine == tab
					and i > (page - 1)*SPELLS_PER_PAGE and i <= page*SPELLS_PER_PAGE then
					-- fade/unfade buttons
					local spellButton = GetSpellButtonByID(i - (page - 1)*SPELLS_PER_PAGE)
					spellButton:SetAlpha(isMatch and 1 or .3)
				end
			end
		end

		--[[local flashFrame = _G["SpellBookSkillLineTab"..tab.."Flash"]
		if matchInTab and flashFrame and searchString and searchString ~= "" then
			SpellBookFrame.flashTabs = 1
			flashFrame:Show()
		elseif flashFrame then
			flashFrame:Hide()
		end--]]
	end

	--[[ if anyMatch then
		UIFrameFlash(SpellBookTabFlashFrame, 0.5, 0.5, 30, nil)
	else
		UIFrameFlashStop(SpellBookTabFlashFrame)
	end --]]
end

ns.RegisterEvent("ADDON_LOADED", function(frame, event, arg1)
	if arg1 ~= addonName then return end
	local scanButton = CreateFrame("Button", "$parentScanButton", SpellBookFrame, "UIPanelButtonTemplate");
	scanButton:SetText("Scan")
	scanButton:SetPoint("LEFT", "$parentTutorialButton", "RIGHT", -20, 2)
	scanButton:SetScript("OnClick", ns.ScanSpells)

	local searchbox = CreateFrame("EditBox", "$parentSearchBox", SpellBookFrame, "SearchBoxTemplate")
	searchbox:SetPoint("TOPRIGHT", SpellBookFrame, "TOPRIGHT", -20, -1)
	searchbox:SetSize(120, 20)
	searchbox:SetText(SEARCH)
	searchbox:SetScript("OnEnterPressed", EditBox_ClearFocus)
	searchbox:SetScript("OnEscapePressed", function(self)
		self:SetText(SEARCH)
		PlaySound("igMainMenuOptionCheckBoxOn")
		EditBox_ClearFocus(self)
	end)
	searchbox:SetScript("OnTextChanged", function(self)
		local text = self:GetText()
		local oldText = SpellBookFrame.searchString

		if text == "" or text == SEARCH then
			SpellBookFrame.searchString = nil
		else
			SpellBookFrame.searchString = string.lower(text)
		end

		if oldText ~= SpellBookFrame.searchString then
			ns.SearchInSpellBook()
		end
	end)
	searchbox.clearFunc = function(self)
		ns.SearchInSpellBook()
	end

	hooksecurefunc("SpellBookFrame_Update", function()
		if (SpellBookFrame.customBookType or SpellBookFrame.bookType) == BOOKTYPE_SPELL then
			searchbox:Show()
			scanButton:Show()
			ns.SearchInSpellBook()
		else
			searchbox:Hide()
			scanButton:Hide()
		end
	end)

	ns.UnregisterEvent("ADDON_LOADED", "searchSpellBook")
end, "searchSpellBook")

-- ================================================
-- Manage action bar setups
-- ================================================
--[[
LibStub('LibKeyBound-1.0').Binder:GetBindings(MultiBarBottomLeftButton6) => "SHIFT-6, SHIFT-G"

hasAction = HasAction(slotID)
autocastAllowed, autocastEnabled = GetActionAutocast(slotID)
TogglePetAutocast(petSlotID) -- NUM_PET_ACTION_SLOTS
PickupPetAction(petSlotID)
PickupSpell(spellID)
PickupMacro(index|name)
PickupAction(slotID) -- puts onto cursor
PlaceAction(slotID) -- takes from cursor
--]
local function UpdateActionBarProfilesTab()
	local panel = _G['ActionBarProfiles']
	SpellBookPage1:SetDesaturated(false)
	SpellBookPage2:SetDesaturated(false)

	for row = 1, 10 do
		for col = 1, NUM_ACTIONBAR_BUTTONS do
			ActionButton_Update( _G['ActionBarProfilesBar'..row..'Button'..col] )
		end
	end
end
local function InitActionBarProfiles()
	-- create a content panel
	local frame = CreateFrame('Frame', 'ActionBarProfiles', SpellBookFrame)
	frame:SetPoint('TOPLEFT')
	frame:SetPoint('BOTTOMRIGHT')
	table.insert(SpellBookFrames, frame:GetName())

	local explain = frame:CreateFontString('$parentInfo', "ARTWORK", "GameFontNormal")
	explain:SetPoint('TOPLEFT', 100, -46)
	explain:SetWidth(360)
	explain:SetWordWrap(true)
	explain:SetJustifyH('LEFT')
	explain:SetJustifyV('TOP')
	explain:SetText([=[Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.]=])

	local button
	for row = 1, 10 do
		for col = 1, NUM_ACTIONBAR_BUTTONS do
			button = CreateFrame('CheckButton', '$parentBar'..row..'Button'..col, frame, 'ActionButtonTemplate')
			button:SetScale(0.85)
			button.action = (row-1)*12 + col

			if col == 1 then
				if row == 1 then
					button:SetPoint('TOPLEFT', '$parentInfo', 'BOTTOMLEFT', 0, -10)
				else
					button:SetPoint('TOPLEFT', '$parentBar'..(row-1)..'Button1', 'BOTTOMLEFT', 0, -4)
				end
			else
				button:SetPoint('LEFT', '$parentBar'..row..'Button'..(col-1), 'RIGHT', 2, 0)
			end
		end
	end

	local save = CreateFrame("Button", "$parentSaveButton", frame, "UIPanelButtonTemplate")
	save:SetText("Save")
	save:SetPoint('BOTTOMLEFT', 30, 22)
	save:SetScript('OnClick', function(self, btn)
		ns.Print('Saving current action bars', 'TODO')
	end)
	local load = CreateFrame("Button", "$parentLoadButton", frame, "UIPanelButtonTemplate")
	load:SetText("Load")
	load:SetPoint('BOTTOMLEFT', save, 'TOPLEFT', 0, 4)
	load:SetScript('OnClick', function(self, btn)
		ns.Print('Loading displayed action bar settings', 'TODO')
	end)

	-- create a tab to trigger display of our panel
	local numTabs = 1
	while _G['SpellBookFrameTabButton'..numTabs] do
		numTabs = numTabs + 1
	end
	local tabButton = CreateFrame('Button', 'SpellBookFrameTabButton'..numTabs, SpellBookFrame, 'SpellBookFrameTabButtonTemplate')
	tabButton:SetID(numTabs)
	tabButton:SetText('Bars')
	tabButton:Show()
	tabButton:SetScript('OnClick', function(self, btn)
		SpellBookFrame.bookType = self.customBookType
		SpellBookFrame.customBookType = self.customBookType
		SpellBookFrameTabButton_OnClick(self)
	end)
	tabButton.binding = ''
	tabButton.bookType = BOOKTYPE_SPELL
	-- we need a custom type as we can't interact with SpellBookInfo
	tabButton.customBookType = 'actionbars'
	tabButton.titleText = 'Action Bars'
	tabButton.updateFunc = UpdateActionBarProfilesTab
	tabButton.showFrames = { 'ActionBarProfiles' }
end

local function HookSpellBookFrame_Update()
	local numTabs = 0
	while _G['SpellBookFrameTabButton'..(numTabs+1)] do
		numTabs = numTabs + 1
	end

	-- repositioning to fill gaps
	local tabIndex, lastTabIndex = 1, 1
	while _G['SpellBookFrameTabButton'..tabIndex] do
		local tab = _G['SpellBookFrameTabButton'..tabIndex]
		if tab:IsShown() then
			if tabIndex > 1 then
				tab:SetPoint('LEFT', _G['SpellBookFrameTabButton'..lastTabIndex], 'RIGHT', -15, 0)
			end
			lastTabIndex = tabIndex
		end
		tabIndex = tabIndex + 1
	end

	-- update spellbook metadata
	local tab = SpellBookFrame.currentTab
	if SpellBookFrame.customBookType then
		SpellBookFrame.bookType = SpellBookFrame.customBookType or SpellBookFrame.bookType
		SpellBookFrame.customBookType = nil
		for i=1,numTabs do
			tab = _G['SpellBookFrameTabButton'..i]
			if (tab.customBookType or tab.bookType) == SpellBookFrame.bookType then
				SpellBookFrame.currentTab = tab
				break
			end
		end
	end

	-- display correct panel
	if tab.showFrames then
		for i, frame in ipairs(SpellBookFrames) do
			local found = false
			for j,frame2 in ipairs(tab.showFrames) do
				if frame == frame2 then
					_G[frame]:Show()
					found = true
					break
				end
			end
			if not found then
				_G[frame]:Hide()
			end
		end
	end

	-- activate correct tab
	for i=1, numTabs do
		local spellTab = _G["SpellBookFrameTabButton"..i]
		if (spellTab.customBookType or spellTab.bookType) == SpellBookFrame.bookType then
			PanelTemplates_SelectTab(spellTab)
		else
			PanelTemplates_DeselectTab(spellTab)
		end
		PanelTemplates_TabResize(spellTab, 0, nil, 40)
	end

	-- update panel if it's custom
	if tab.titleText 	then SpellBookFrameTitleText:SetText(tab.titleText) end
	if tab.bgFileL 		then SpellBookPage1:SetTexture(tab.bgFileL) end
	if tab.bgFileR 		then SpellBookPage2:SetTexture(tab.bgFileR) end
	if tab.updateFunc 	then tab.updateFunc() end
end

ns.RegisterEvent("ADDON_LOADED", function(frame, event, arg1)
	if arg1 ~= addonName then return end
	InitActionBarProfiles()
	hooksecurefunc('SpellBookFrame_Update', HookSpellBookFrame_Update)

	ns.UnregisterEvent("ADDON_LOADED", "actionbarprofiles")
end, "actionbarprofiles")
--]]
