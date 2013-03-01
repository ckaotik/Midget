local addonName, ns, _ = ...
-- GLOBALS: _G, CliqueDB3, MAX_SPELLS, SEARCH, BOOKTYPE_SPELL, SPELLBOOK_PAGENUMBERS, SPELLS_PER_PAGE, UIFrameFlash, UIFrameFlashStop, EditBox_ClearFocus, SpellBookFrame
-- GLOBALS: IsAddOnLoaded, IsAltKeyDown, CreateFrame, PlaySound, ToggleSpellBook, FindSpellBookSlotBySpellID, SpellBookTabFlashFrame, SpellBookFrame_Update, SpellBook_GetCurrentPage, SpellBook_GetAutoCastShine, AutoCastShine_AutoCastStart, GetNumSpellTabs, GetSpellTabInfo, GetSpellBookItemInfo, GetSpellBookItemName, GetSpellDescription, GetSpellLink, IsSpellKnown, IsPassiveSpell, GetUnitName, GetRealmName, GetMacroBody, GetFlyoutInfo, GetFlyoutSlotInfo, GetActionInfo, GetShapeshiftFormInfo, GetNumShapeshiftForms
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
-- Shinies!
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

ns.RegisterEvent("ADDON_LOADED", function()
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
		if commandType and relevantMacroCommands[commandType] then
			command = command:gsub("(%[[^%]]*%])", "") 		-- cleanup [conditions]
			command = command:gsub("(reset=[^ ]*)", "") 	-- cleanup for /castsequence

			for j, spell in ipairs({ string.split(";", command) }) do
				spell = GetSpellID(spell)
				if spell then
					usedSpells[ tonumber(spell) ] = true
				end
			end
			for j, spell in ipairs({ string.split(",", command) }) do
				spell = GetSpellID(spell)
				if spell then
					usedSpells[ tonumber(spell) ] = true
				end
			end
		elseif commandType and commandType == "startattack" then
			usedSpells[ AUTOATTACK ] = true
		end
	end
end

local function ScanActionButtons()
	local actionType, action, subType, spellID
	local macro, commandType, command, overlayedSpell
	local numActionButtons = (NUM_ACTIONBAR_PAGES + 4) * NUM_ACTIONBAR_BUTTONS -- regular + 2 right + 2 bottom bars

	usedSpells = wipe(usedSpells)
	for i, spellID in ipairs(ignoredSpells) do
		usedSpells[spellID] = true
	end

	for slot = 1, numActionButtons do
		actionType, action, subType, spellID = GetActionInfo(slot)
		-- companion, equipmentset, flyout, item, macro, spell

		if actionType == "spell" then
			usedSpells[action] = true

			overlayedSpell = select(9, GetSpellInfo(action))
			if overlayedSpell and overlayedSpell ~= 0 then
				_, action = GetSpellBookItemInfo(overlayedSpell, BOOKTYPE_SPELL)
				if action then
					usedSpells[action] = true
				end
			end
		elseif actionType == "flyout" then
			usedSpells[ -1*action ] = true
		elseif actionType == "macro" and action > 0 then
			macro = GetMacroBody(action)
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
			spell = GetSpellBookItemName(index, BOOKTYPE_SPELL)
			spell = GetSpellLink(spell) or GetSpellLink(actionID)
			spellID = GetSpellID(spell)
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

		local flashFrame = _G["SpellBookSkillLineTab"..tab.."Flash"]
		if matchInTab and flashFrame and searchString and searchString ~= "" then
			SpellBookFrame.flashTabs = 1
			flashFrame:Show()
		elseif flashFrame then
			flashFrame:Hide()
		end
	end

	if anyMatch then
		UIFrameFlash(SpellBookTabFlashFrame, 0.5, 0.5, 30, nil)
	else
		UIFrameFlashStop(SpellBookTabFlashFrame)
	end
end

ns.RegisterEvent("ADDON_LOADED", function(frame, event, arg1)
	if arg1 ~= addonName then return end

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

	hooksecurefunc("SpellBookFrame_Update", ns.SearchInSpellBook)

	local scanButton = CreateFrame("Button", "$parentScanButton", SpellBookFrame, "UIPanelButtonTemplate");
	scanButton:SetText("Scan")
	scanButton:SetPoint("LEFT", "$parentTutorialButton", "RIGHT", -20, 2)
	scanButton:SetScript("OnClick", ns.ScanSpells)

	ns.UnregisterEvent("ADDON_LOADED", "searchSpellBook")
end, "searchSpellBook")
