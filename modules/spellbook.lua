local addonName, addon, _ = ...
local plugin = addon:NewModule('Spellbook', 'AceEvent-3.0')

-- GLOBALS: _G, CliqueDB3, MAX_SPELLS, SEARCH, BOOKTYPE_SPELL, SPELLBOOK_PAGENUMBERS, SPELLS_PER_PAGE, NUM_ACTIONBAR_PAGES, NUM_ACTIONBAR_BUTTONS, UIFrameFlash, UIFrameFlashStop, EditBox_ClearFocus, SpellBookFrame, SpellBookFrames, SpellBookPage1, SpellBookPage2
-- GLOBALS: IsAddOnLoaded, IsAltKeyDown, CreateFrame, PlaySound, ToggleSpellBook, FindSpellBookSlotBySpellID, SpellBookTabFlashFrame, SpellBookFrame_Update, SpellBook_GetCurrentPage, SpellBook_GetAutoCastShine, AutoCastShine_AutoCastStart, GetNumSpellTabs, GetSpellInfo, GetSpellTabInfo, GetSpellBookItemInfo, GetSpellBookItemName, GetSpellDescription, GetSpellLink, IsSpellKnown, IsPassiveSpell, GetUnitName, GetRealmName, GetMacroBody, GetFlyoutInfo, GetFlyoutSlotInfo, GetActionInfo, GetShapeshiftFormInfo, GetNumShapeshiftForms, SecureCmdOptionParse
-- GLOBALS: hooksecurefunc, string, math, select, ipairs, tonumber, wipe, type

-- local Spellbook = LibStub('LibSpellbook-1.0')
-- for id, name in LibSpellbook:IterateSpells(BOOKTYPE_SPELL) do

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
	addon:Print(msg)
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
		addon:Print("All spells are bound! Well done.")
	end
end
plugin.ScanSpells = function()
	ScanActionButtons()
	ScanSpellBook()
end

-- ================================================
-- SpellBookSearch
-- ================================================
local CustomSearch = LibStub('CustomSearch-1.0')
local ItemSearch   = LibStub('LibItemSearch-1.2')
local filters = {
	tooltip = {
		tags      = ItemSearch.Filters.tooltip.tags,
		onlyTags  = ItemSearch.Filters.tooltip.onlyTags,
		canSearch = ItemSearch.Filters.tooltip.canSearch,
		match     = function(self, hyperlink, operator, search)
			return ItemSearch.Filters.tooltip.match(self, hyperlink, operator, search)
		end
	},
	name = {
		tags      = {'n', 'name', 'title', 'text'},
		canSearch = function(self, operator, search) return not operator and search end,
		match     = function(self, text, operator, search)
			local spellID, name = text:match('spell:(%d+).-%[(.-)%]')
			      spellID = tonumber(spellID)
			local description = GetSpellDescription(spellID)
			if name then
				return CustomSearch:Find(search, name, description, tostring(spellID))
			end
		end
	},
}
local function SearchInSpell(index, searchString)
	if not index or not searchString then return end
	local spellLink, tradeLink = GetSpellLink(index, _G.BOOKTYPE_SPELL)
	return CustomSearch:Matches(spellLink, searchString, filters)
end

local LibFlash = LibStub("LibFlash")
local flasher = nil
function plugin.SearchInSpellBook()
	if not flasher then
		flasher = LibFlash:New(SpellBookTabFlashFrame)
	end

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

		local flashFrame = _G["SpellBookSkillLineTab"..tab.."Flash"]
		if matchInTab and flashFrame and searchString and searchString ~= "" then
			flashFrame:Show()
		elseif flashFrame then
			flashFrame:Hide()
		end
	end

	if anyMatch then
		SpellBookTabFlashFrame:Show()
		flasher:FadeIn(0.5, 0, 1)
	else
		SpellBookTabFlashFrame:Hide()
		flasher:Stop()
	end
end

function plugin:OnEnable()
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

	local scanButton = CreateFrame("Button", "$parentScanButton", SpellBookFrame, "UIPanelButtonTemplate");
	scanButton:SetText("Scan")
	scanButton:SetPoint("LEFT", "$parentTutorialButton", "RIGHT", -20, 2)
	scanButton:SetScript("OnClick", plugin.ScanSpells)

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
			plugin.SearchInSpellBook()
		end
	end)
	searchbox.clearFunc = function(self)
		plugin.SearchInSpellBook()
	end

	hooksecurefunc("SpellBookFrame_Update", function()
		if (SpellBookFrame.customBookType or SpellBookFrame.bookType) == BOOKTYPE_SPELL then
			searchbox:Show()
			scanButton:Show()
			plugin.SearchInSpellBook()
		else
			searchbox:Hide()
			scanButton:Hide()
		end
	end)
end
