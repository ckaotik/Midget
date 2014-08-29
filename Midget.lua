local addonName, addon, _ = ...
_G[addonName] = LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceEvent-3.0')

-- GLOBALS: _G, Midget, MidgetDB, MidgetLocalDB, DEFAULT_CHAT_FRAME, C_PetJournal
-- GLOBALS: GameTooltip, CreateFrame, GetItemInfo
-- GLOBALS: table, string, math, strsplit, type, tonumber, pairs, assert, tostring, tostringall

-- settings -- TODO: put into ns. so modules can have settings, too
local globalDefaults = {
	tradeskillCosts = false,
	tradeskillLevels = true,
	tradeskillTooltips = true,

	CorkButton = false,
	TipTacStyles = true,
	moreSharedMedia = true,

	movePetBattleFrame = true,
	PetBattleFrameOffset = -16,
	menuBarHeight = true,

	autoCheckSpells = true,
	autoScanProfessions = false,

	undressButton = true,
	modelLighting = true,
	shortenLFRNames = true,
	outgoingWhisperColor = true,
	InterfaceOptionsScrolling = true,
	SHIFTAcceptPopups = true,
	hideUnusableCompareTips = true,

	scanGems = false,
}
local localDefaults = {
	trackBattlePetTeams = true,
	trackProfessionSkills = true,
	trackProfession = {},
}

local function UpdateDatabase()
	-- keep database up to date, i.e. remove artifacts + add new options
	if MidgetDB == nil then
		MidgetDB = globalDefaults
	else
		--[[for key,value in pairs(MidgetDB) do
			if globalDefaults[key] == nil then MidgetDB[key] = nil end
		end--]]
		for key,value in pairs(globalDefaults) do
			if MidgetDB[key] == nil then MidgetDB[key] = value end
		end
	end

	if MidgetLocalDB == nil then
		MidgetLocalDB = localDefaults
	else
		--[[for key,value in pairs(MidgetLocalDB) do
			if localDefaults[key] == nil then MidgetLocalDB[key] = nil end
		end--]]
		for key,value in pairs(localDefaults) do
			if MidgetLocalDB[key] == nil then MidgetLocalDB[key] = value end
		end
	end
end

function addon:OnInitialize()
	UpdateDatabase()
end

function addon:OnEnable()
	local function GetSetting(info)
		local data = info[1] == 'main' and MidgetDB or MidgetLocalDB
		for i = 2, #info do data = data[ info[i] ] end
		return data
	end
	local function SetSetting(info, value)
		local data = info[1] == 'main' and MidgetDB or MidgetLocalDB
		for i = 2, #info - 1 do data = data[ info[i] ] end
		data[ info[#info] ] = value
	end

	local OptionsGenerate = LibStub('LibOptionsGenerate-1.0')
	LibStub('AceConfig-3.0'):RegisterOptionsTable(addonName, {
		type = 'group',
		inline = true,
		args = {
			main      = OptionsGenerate:GetOptionsTable(MidgetDB),
			character = OptionsGenerate:GetOptionsTable(MidgetLocalDB),
		},
		get = GetSetting,
		set = SetSetting,
	})

	local AceConfigDialog = LibStub('AceConfigDialog-3.0')
	      AceConfigDialog:AddToBlizOptions(addonName, addonName, nil, 'main')
end

-- ================================================
-- Little Helpers
-- ================================================
function addon:Print(text, ...)
	if ... and text:find("%%") then
		text = string.format(text, ...)
	elseif ... then
		text = string.join(", ", tostringall(text, ...))
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff22CCDDMidget|r "..text)
end

function addon:Debug(...)
  if true then
	addon.Print("! "..string.join(", ", tostringall(...)))
  end
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
			GameTooltip:AddLine(self['tiptext'..lineIndex], 1, 1, 1, nil, true)
			lineIndex = lineIndex + 1
		end
	elseif type(self.tiptext) == "function" then
		self.tiptext(self, GameTooltip)
	end
	GameTooltip:Show()
end
function addon.HideTooltip() GameTooltip:Hide() end

function addon.GetItemID(itemLink)
	if not itemLink or type(itemLink) ~= "string" then return end
	local itemID = string.gsub(itemLink, ".-Hitem:([0-9]*):.*", "%1")
	return tonumber(itemID)
end

function addon.GetLinkData(link)
	if not link or type(link) ~= "string" then return end
	local linkType, id, data = link:match("(%l+):([^:\124]*):?([^\124]*)")
	return linkType, tonumber(id), data
end

local BATTLEPET = select(11, GetAuctionItemClasses())
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
