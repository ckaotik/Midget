local addonName, ns, _ = ...
-- GLOBALS: _G, MidgetDB, ERR_SPELL_UNLEARNED_S, ERR_LEARN_ABILITY_S, ERR_LEARN_SPELL_S, ERR_LEARN_PASSIVE_S, ClassTrainerFrame, ClassTrainerTrainButton
-- GLOBALS: CreateFrame, IsPassiveSpell, GetSpellInfo, GetSpellLink, BuyTrainerService, GetTrainerServiceInfo, GetTrainerServiceCost, GetNumTrainerServices, MoneyFrame_Update, GetMoney, StaticPopup_Show, ChatFrame_AddMessageEventFilter, ChatFrame_RemoveMessageEventFilter, ChatFrame_DisplaySystemMessageInPrimary
-- GLOBALS: string, table, wipe, ipairs, type, select, hooksecurefunc

-- ================================================
-- Train All button for professions
-- ================================================
local trainAllCost = 0
StaticPopupDialogs["MIDGET_TRAINALL"] = {
	text = COSTS_LABEL,
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
	-- ns.UnregisterEvent("TRAINER_UPDATE", "learnall")
end, "learnall")

-- ================================================
-- SpamMerger for respec learned/unlearned spells
-- ================================================
local UNLEARNED = string.gsub(ERR_SPELL_UNLEARNED_S, "%%s", "(.+)")
local LEARNED = string.gsub(ERR_LEARN_ABILITY_S, "%%s", "(.+)")
local LEARNED_SPELL = string.gsub(ERR_LEARN_SPELL_S, "%%s", "(.+)")
local LEARNED_PASSIVE = string.gsub(ERR_LEARN_PASSIVE_S, "%%s", "(.+)")
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
		nameA = a:match("%[(.-)%]") or a
		nameB = b:match("%[(.-)%]") or b
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
		end, "respecLearned", true)

		ns.RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function()
			PrintRespecChanges()
			ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", RespecSpamChatFilter)

			ns.UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED", "respecCancelled")
			ns.UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED", "respec")
			ns.UnregisterEvent("LEARNED_SPELL_IN_TAB", "respecLearned")
		end, "respec")

		ns.RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", function(...)
			local spell = select(5, ...)
			if spell ~= 63645 and spell ~= 63644 then return end
			ChatFrame_RemoveMessageEventFilter("CHAT_MSG_SYSTEM", RespecSpamChatFilter)

			ns.UnregisterEvent("UNIT_SPELLCAST_INTERRUPTED", "respecCancelled")
			ns.UnregisterEvent("PLAYER_SPECIALIZATION_CHANGED", "respec")
			ns.UnregisterEvent("LEARNED_SPELL_IN_TAB", "respecLearned")
		end, "respecCancelled")
	end)

	ns.UnregisterEvent("ADDON_LOADED", "respecInit")
end, "respecInit")
