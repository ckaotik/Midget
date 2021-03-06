local addonName, addon, _ = ...
_G[addonName] = LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceEvent-3.0')

-- GLOBALS: _G, LibStub
-- GLOBALS: C_PetJournal, GameTooltip, CreateFrame, GetItemInfo
-- GLOBALS: table, string, math, strsplit, type, tonumber, pairs, assert, tostring, tostringall

local defaults = {
	profile = {
		CorkButton = false,
		TipTacStyles = true,
		moreSharedMedia = true,
		menuBarHeight = true,
		chatHoverTooltips = true,
		chatLinkIcons = true,
		autoCheckSpells = true,
		undressButton = true,
		modelLighting = true,
		shortenLFRNames = true,
		outgoingWhisperColor = true,
		InterfaceOptionsScrolling = true,
		InterfaceOptionsDragging = true,
		SHIFTAcceptPopups = true,
		hideUnusableCompareTips = true,
		showRaidBuffIndicators = true,
		listenForAssignments = true,
		deleteEmptyPostmasterMails = false,
		restoreLootSpecAfterCombat = false,
		easySurvey = true,
	},
	char = {
		trackBattlePetTeams = true,
		trackProfessionSkills = true,
		trackProfession = {},
		LFRLootSpecs = {},
	}
}

function addon:OnEnable()
	self.db = LibStub('AceDB-3.0'):New(addonName..'DB', defaults, true)
end

-- --------------------------------------------------------
--  LoadWith
-- --------------------------------------------------------
local loadWith = {}
function addon:LoadWith(otherAddon, handler, remove)
	if remove then
		if loadWith[otherAddon] then
			for index, callback in pairs(loadWith[otherAddon]) do
				if callback == handler then
					loadWith[otherAddon][index] = nil
					if not next(loadWith[otherAddon]) then
						loadWith[otherAddon] = nil
					end
					if not next(loadWith) then
						self:UnregisterEvent('ADDON_LOADED')
					end
					return true
				end
			end
		end
		return
	end

	if IsAddOnLoaded(otherAddon) then
		-- addon is available, directly run handler code
		return handler(self, nil, otherAddon)
	else
		if loadWith[otherAddon] then
			for _, callback in pairs(loadWith[otherAddon]) do
				if callback == handler then
					return
				end
			end
		end
		-- handler is not yet registered
		if not loadWith[otherAddon] then loadWith[otherAddon] = {} end
		tinsert(loadWith[otherAddon], handler)
		self:RegisterEvent('ADDON_LOADED')
	end
end
function addon:ADDON_LOADED(event, arg1)
	if loadWith[arg1] then
		for key, callback in pairs(loadWith[arg1]) do
			if callback(self, event, arg1) then
				-- handler succeeded, remove from task list
				loadWith[arg1][key] = nil
				if not next(loadWith[arg1]) then
					loadWith[arg1] = nil
				end
			end
		end
	end
	if not next(loadWith) then
		self:UnregisterEvent('ADDON_LOADED')
	end
end
addon:RegisterEvent('ADDON_LOADED')

-- --------------------------------------------------------
-- Little Helpers
-- --------------------------------------------------------
function addon:Print(text, ...)
	if ... and text:find("%%") then
		text = string.format(text, ...)
	elseif ... then
		text = string.join(", ", tostringall(text, ...))
	end
	_G.DEFAULT_CHAT_FRAME:AddMessage("|cff22CCDDMidget|r "..text)
end

-- convenient and smart tooltip handling
function addon.ShowTooltip(self, anchor)
	if not self.tiptext and not self.link then return end
	if anchor and type(anchor) == 'table' then
		GameTooltip:SetOwner(anchor, "ANCHOR_RIGHT")
	else
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
	end
	GameTooltip:ClearLines()

	if self.link then
		GameTooltip:SetHyperlink(self.link)
	elseif type(self.tiptext) == "string" and self.tiptext ~= "" then
		GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
		local lineIndex = 2
		while self['tiptext'..lineIndex] do
			if self['tiptext'..lineIndex..'Right'] then
				GameTooltip:AddDoubleLine(self['tiptext'..lineIndex], self['tiptext'..lineIndex..'Right'], 1, 1, 1, 1, 1, 1)
			else
				GameTooltip:AddLine(self['tiptext'..lineIndex], 1, 1, 1, nil, true)
			end
			lineIndex = lineIndex + 1
		end
	elseif type(self.tiptext) == "function" then
		self.tiptext(self, GameTooltip)
	end
	GameTooltip:Show()
end
function addon.HideTooltip() GameTooltip:Hide() end

function addon.GetLinkData(link)
	if not link or type(link) ~= "string" then return end
	local linkType, id, data = link:match("(%l+):([^:\124]*):?([^\124]*)")
	return linkType, tonumber(id), data
end

local BATTLEPET = AUCTION_CATEGORY_BATTLE_PETS
-- this is a wrapper for battle pets, so you can use them like you would regular items
function addon.GetItemInfo(link)
	if not link or type(link) ~= "string" then return end
	local linkType, itemID, data = addon.GetLinkData(link)

	if linkType == "battlepet" then
		local name, texture, subClass, companionID = C_PetJournal.GetPetInfoBySpeciesID( itemID )
		local level, quality, health, attack, speed = strsplit(':', data or '')

		-- including some static values for battle pets
		return name, string.trim(link), tonumber(quality), tonumber(level), 0, BATTLEPET, tonumber(subClass), 1, "", texture, nil, companionID, tonumber(health), tonumber(attack), tonumber(speed)
	elseif linkType == "item" then
		return GetItemInfo( itemID )
	end
end

-- counts table entries. for numerically indexed tables, use #table
function addon.Count(table)
	if not table then return 0 end
	local i = 0
	for _, _ in pairs(table) do
		i = i + 1
	end
	return i
end
