local addonName, ns, _ = ...
-- GLOBALS: _G, ERR_SPELL_UNLEARNED_S, ERR_LEARN_ABILITY_S, ERR_LEARN_SPELL_S, ERR_SPELL_UNLEARNED_S, ERR_LEARN_PASSIVE_S, ClassTrainerFrame, ClassTrainerTrainButton
-- GLOBALS: CreateFrame, IsPassiveSpell, GetSpellInfo, GetSpellLink, BuyTrainerService, GetTrainerServiceInfo, GetTrainerServiceCost, GetNumTrainerServices, MoneyFrame_Update, GetMoney, StaticPopup_Show, ChatFrame_AddMessageEventFilter, ChatFrame_RemoveMessageEventFilter
-- GLOBALS: string, table, wipe, ipairs, type, select, hooksecurefunc

-- ================================================
-- Train All button for professions
-- ================================================
local trainAllCost = 0
StaticPopupDialogs["MIDGET_TRAINALL"] = {
	text = "Training all available skills costs", -- COSTS_LABEL
	button1 = _G["OKAY"],
	button2 = _G["CANCEL"],
	hasMoneyFrame = true,
	OnShow = function(self)
		MoneyFrame_Update(self.moneyFrame, trainAllCost)
	end,
	OnAccept = function(self)
		for i=1, GetNumTrainerServices() do
			if select(3, GetTrainerServiceInfo(i)) == "available" then
				BuyTrainerService(i)
			end
		end
	end,
	EditBoxOnEscapePressed = function(self)
		self:GetParent():GetParent().button2:Click()
	end,
	EditBoxOnEnterPressed = function(self)
		self:GetParent():GetParent().button1:Click()
	end,
	timeout = 0,
	whileDead = true,
	enterClicksFirstButton = true,
	hideOnEscape = true,
	preferredIndex = 3,
}
local function AddTrainAllButton()
	local button = _G["MidgetTrainAllButton"]
	if not button then
		button = CreateFrame("Button", "MidgetTrainAllButton", ClassTrainerFrame, "MagicButtonTemplate")
		button:SetPoint("TOPRIGHT", ClassTrainerTrainButton, "TOPLEFT")
		button:SetText("Train all")
		button:SetScript("OnClick", function(self, btn)
			StaticPopup_Show("MIDGET_TRAINALL")
		end)
	end

	local hasLearnable, cost = false, 0
	for i=1, GetNumTrainerServices() do
		if select(3, GetTrainerServiceInfo(i)) == "available" then
			hasLearnable = true
			cost = cost + GetTrainerServiceCost(i)
		end
	end
	trainAllCost = cost
	if hasLearnable and cost <= GetMoney() then
		_G["MidgetTrainAllButton"]:Enable()
	else
		_G["MidgetTrainAllButton"]:Disable()
	end
end

ns.RegisterEvent("TRAINER_UPDATE", function()
	AddTrainAllButton()
	ns.UnregisterEvent("TRAINER_UPDATE", "learnall")
end, "learnall")

-- ================================================
-- Shinies!
-- ================================================
local function ShineSlot(index)
	-- recalculate proper button offset, as counting is column-wise but display is per row
	index = index == 0 and 12 or (index - 6) * 2
	if index <= 0 then
		index = index + (2*6 - 1)
	end
	slot = _G["SpellButton"..index]
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
-- SpamMerger for respec learned/unlearned spells
-- ================================================
local UNLEARNED = string.gsub(ERR_SPELL_UNLEARNED_S, "%%s", "(.-)")
local LEARNED = string.gsub(ERR_LEARN_ABILITY_S, "%%s", "(.-)")
local LEARNED_SPELL = string.gsub(ERR_LEARN_SPELL_S, "%%s", "(.-)")
local LEARNED_PASSIVE = string.gsub(ERR_LEARN_PASSIVE_S, "%%s", "(.-)")
local respecUnlearned, respecLearned = {}, {}

local function RespecSpamChatFilter(chatFrame, event, message, ...)
	local spell = message:match(UNLEARNED)
	if spell then
		table.insert(respecUnlearned, spell)
	end

	if spell or message:match(LEARNED) or message:match(LEARNED_SPELL) or message:match(LEARNED_PASSIVE) then
		return true
	else
		return false
	end
end

local function SortSpellTable(a, b)
	local nameA, nameB, passiveA, passiveB
	if type(a) == "number" and type(b) == "number" then
		nameA = GetSpellInfo(a)
		nameB = GetSpellInfo(b)

	else
		nameA = a:match("%[(.-)%]")
		nameB = b:match("%[(.-)%]")
	end
	passiveA = IsPassiveSpell(nameA) or 0
	passiveB = IsPassiveSpell(nameB) or 0


	if passiveA == passiveB then
		return nameA < nameB
	else
		return passiveA < passiveB
	end
end

local function PrintRespecChanges()
	table.sort(respecUnlearned, SortSpellTable)
	table.sort(respecLearned, SortSpellTable)
	for i, spellID in ipairs(respecLearned) do
		respecLearned[i] = GetSpellLink(spellID)
	end
	for i = #respecLearned, 1, -1 do
		for j = #respecUnlearned, 1, -1 do
			if respecUnlearned[j] == respecLearned[i] then
				table.remove(respecUnlearned, j)
				table.remove(respecLearned, i)
			end
		end
	end

	if #respecUnlearned > 0 then
		local unlearned = string.format(ERR_SPELL_UNLEARNED_S, table.concat(respecUnlearned, ', '))
		ChatFrame_DisplaySystemMessageInPrimary(unlearned)
	end
	if #respecLearned > 0 then
		local learned = string.format(ERR_LEARN_ABILITY_S, table.concat(respecLearned, ', '))
		ChatFrame_DisplaySystemMessageInPrimary(learned)
	end

	if MidgetDB.autoCheckSpells then
		ns.ScanSpells()
	end
end

ns.RegisterEvent("ADDON_LOADED", function(frame, event, arg1)
	if arg1 ~= addonName then return end

	hooksecurefunc("SetActiveSpecGroup", function(newSpec)
		wipe(respecUnlearned)
		wipe(respecLearned)
		ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", RespecSpamChatFilter)

		ns.RegisterEvent("LEARNED_SPELL_IN_TAB", function(frame, event, arg1)
			table.insert(respecLearned, arg1)
		end, "respecLearned")

		ns.RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function()
			PrintRespecChanges()
			ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", RespecSpamChatFilter)

			ns.UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED", "respec")
			ns.UnregisterEvent("LEARNED_SPELL_IN_TAB", "respecLearned")
		end, "respec")
	end)

	ns.UnregisterEvent("ADDON_LOADED", "respecInit")
end, "respecInit")

-- ================================================
-- SpellSearch
-- ================================================
local function GetSpellID(spellName)
	if type(spellName) == "number" then
		return spellName
	else
		spell = string.trim(spell)
		spell = GetSpellLink(spell)
		return spell and spell:match("Hspell:(%d+)") or nil
	end
end
local function ParseMacroSpells(macro)
	for i, action in ipairs({ string.split("\n", macro) }) do
		commandType, command = string.match(action, "/([^%s]+)%s*(.*)")
		if commandType and relevantMacroCommands[commandType] then
			command = command:gsub("(%[[^%]]*%]", "")
			for j, spell in ipairs({ string.split(";", command) }) do
				spell = GetSpellID(spell)
				if spell then
					usedSpells[ tonumber(spell) ] = true
				end
			end
		end
	end
end
local numActionButtons = (NUM_ACTIONBAR_PAGES + 4) * NUM_ACTIONBAR_BUTTONS -- regular + 2 right + 2 bottom bars
local relevantMacroCommands = {
	["cast"] = true,
	["use"] = true,
	["castsequence"] = true,
	["castrandom"] = true,
}
local usedSpells = {}
local function ScanActionButtons()
	usedSpells = wipe(usedSpells)

	local actionType, action, subType, spellID
	local macro, commandType, command
	for slot = 1, numActionButtons do
		actionType, action, subType, spellID = GetActionInfo(slot)
		-- companion, equipmentset, flyout, item, macro, spell

		if actionType == "spell" then
			usedSpells[action] = true
		elseif actionType == "flyout" then
			usedSpells[ -1*action ] = true
		elseif actionType == "macro" and action > 0 then
			macro = GetMacroBody(action)
			ParseMacroSpells(macro)
		end
	end

	if IsAddOnLoaded("Clique") then
		local db = CliqueDB3.profiles and CliqueDB3.profiles[ GetUnitName("player") .. " - " .. GetRealmName("player") ]
			  db = db and db.bindings or {}
		for i, binding in ipairs(db) do
			if binding.type == spell then
				spell = GetSpellID(binding.spell)
				if spell then
					usedSpells[ tonumber(spell) ] = true
				end
			elseif binding.type == "macro" then
				ParseMacroSpells(binding.macrotext)
			end
		end
	end

	-- [TODO] scan macaroon and whatever else there might be
end

local function NotifyUnusedSpell(spellID)
	local link = GetSpellLink(spellID)
	local msg = string.format("Unused spell detected: %s", link)
	ns.Print(msg)
end

local function ScanSpellBook()
	local numSpells = 0
	for i=1, 2 do -- only consider general + spec spells, ignore pets and the likes
		numSpells = numSpells + (select(4, GetSpellTabInfo(i)) or 0)
	end
	if numSpells == 0 then numSpells = MAX_SPELLS end

	local skillType, spellID, actionID, flyoutSize, flyoutKnown, size, known
	for index = 1, numSpells do
		skillType, actionID = GetSpellBookItemInfo(index, BOOKTYPE_SPELL)
		if not skillType then break end

		if skillType == "SPELL" and actionID and IsSpellKnown(actionID)
			and not usedSpells[actionID] and not IsPassiveSpell(actionID) then
			NotifyUnusedSpell(actionID)

		elseif skillType == "FLYOUT" then
			_, _, size, flyoutKnown = GetFlyoutInfo(actionID)
			if actionID and not usedSpells[ -1*actionID ] then
				for k = 1, (flyoutKnown and size or 0) do
					spellID, _, known = GetFlyoutSlotInfo(actionID, k)
					if known and spellID
						and not usedSpells[spellID] and not IsPassiveSpell(spellID) then
						NotifyUnusedSpell(spellID)
					end
				end
			end
		end
	end
end
ns.ScanSpells = function()
	ScanActionButtons()
	ScanSpellBook()
end
