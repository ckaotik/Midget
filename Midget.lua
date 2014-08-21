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

	-- IN DEVELOPMENT: AceGUIWidget-ListSort
	--[[
	local backdrop = {
		bgFile   = 'Interface\\Tooltips\\UI-Tooltip-Background',
		edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border', edgeSize = 16,
		insets   = { left = 4, right = 3, top = 4, bottom = 3 }
	}
	local function Update(self)
		local offset = FauxScrollFrame_GetOffset(self)
		for i, button in ipairs(self) do
			if not button:IsDragging() then
				local index = i + offset
				button:SetText('Label '..index)
			end
		end
		local needsScrollBar = FauxScrollFrame_Update(self, 10, #self, self[1]:GetHeight())
	end
	local rowHeight, padding = 20, 4
	local listFrame = CreateFrame('ScrollFrame', 'SampleScrollFrame', UIParent, 'FauxScrollFrameTemplate')
	      listFrame:SetBackdrop(backdrop)
	      listFrame:SetBackdropColor(0, 0, 0, 0.5)
	      listFrame:SetBackdropBorderColor(1, 1, 1, 1)
	listFrame.scrollBarHideable = true
	listFrame:SetScript('OnVerticalScroll', function(scrollFrame, offset)
		FauxScrollFrame_OnVerticalScroll(scrollFrame, offset, rowHeight, Update)
	end)

	listFrame:SetPoint('CENTER') -- *
	listFrame:SetSize(300, 130) -- *

	-- drag & drop
	local dropIndicator = listFrame:CreateTexture()
	      dropIndicator:SetTexture(1, 0, 0, 0.5)
	      dropIndicator:SetSize(listFrame:GetWidth() - 2*padding, 2)
	      dropIndicator:Hide()
	local function UpdateDragging(self, elapsed)
		-- local parent = self:GetParent()
		local frameBelow = GetMouseFocus()

		local myCenter    = (self:GetTop() - self:GetBottom()) / 2
		local theirCenter = (frameBelow:GetTop() - frameBelow:GetBottom()) / 2
		if myCenter >= theirCenter then
			dropIndicator:SetPoint('LEFT', frameBelow, 'TOPLEFT')
			dropIndicator:Show()
		else
			dropIndicator:SetPoint('LEFT', frameBelow, 'BOTTOMLEFT')
			dropIndicator:Show()
		end
	end
	local function OnDragStart(self, btn)
		self:StartMoving()
		self:SetScript('OnUpdate', UpdateDragging)
		self:SetAlpha(0.5)
		-- self:SetBackdrop(backdrop)
	end
	local function OnDragStop(self)
		-- self:SetBackdrop(nil)
		self:SetAlpha(1)
		self:SetScript('OnUpdate', nil)
		self:StopMovingOrSizing()

		self:SetUserPlaced(false)
		dropIndicator:Hide()
	end

	local label = listFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	      label:SetPoint('TOPLEFT',  listFrame, 'TOPLEFT', 4, 10)
	      label:SetPoint('TOPRIGHT', listFrame, 'TOPRIGHT', -4, 10)
	      label:SetJustifyH('LEFT')
	      label:SetHeight(10)
	label:SetText('Setting Title') -- *

	local screenWidth, screenHeight = GetScreenWidth(), GetScreenHeight()
	local left, right, top, bottom  = listFrame:GetLeft(), listFrame:GetRight(), listFrame:GetTop(), listFrame:GetBottom()
	      left, right, top, bottom  = -left -padding, screenWidth - right + padding, screenHeight - top + padding, -bottom -padding

	for index = 1, 6 do
		local button = CreateFrame('Button', '$parentButton'..index, listFrame, nil, index)
		table.insert(listFrame, button)

		button:SetPoint('TOPLEFT', listFrame, 'TOPLEFT', padding, -padding - (index-1)*rowHeight)
		button:SetPoint('RIGHT', listFrame, 'RIGHT', -padding, 0)
		button:SetHeight(rowHeight)

		button:SetClampedToScreen(true)
		button:SetClampRectInsets(left, right, top, bottom)
		button:SetBackdropColor(0, 0, 0, 0.2)
		button:SetBackdropBorderColor(1, 0, 0, 0.6)

		button:SetScript('OnEnter', addon.ShowTooltip)
		button:SetScript('OnLeave', addon.HideTooltip)

		button:SetNormalTexture('Interface\\CURSOR\\UI-Cursor-Move')
		local tex = button:GetNormalTexture()
		      tex:SetSize(16, 16)
		      tex:ClearAllPoints()
		      tex:SetPoint('LEFT', 2, 0)
		button:SetHighlightTexture('Interface\\Buttons\\UI-PlusButton-Hilight', 'ADD')
		local tex = button:GetHighlightTexture()
		      tex:SetSize(16, 16)
		      tex:ClearAllPoints()
		      tex:SetPoint('LEFT', 3, 0)

		button:SetHighlightFontObject('GameFontHighlightLeft')
		button:SetDisabledFontObject('GameFontHighlightLeft')
		button:SetNormalFontObject('GameFontNormalLeft')

		local label = button:CreateFontString(nil, nil, 'GameFontNormalLeft')
		      label:SetPoint('LEFT', 26, 0)
		      label:SetHeight(rowHeight)
		      label:SetJustifyH('LEFT')
		button:SetFontString(label)

		button:SetMovable(true)
		button:RegisterForDrag('LeftButton')
		button:SetScript('OnDragStart', OnDragStart)
		button:SetScript('OnDragStop',  OnDragStop)
	end
	FauxScrollFrame_OnVerticalScroll(listFrame, 0, rowHeight, Update)
	--]]
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

function addon.ShowTooltip(self)
	if self.hyperlink then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(self.hyperlink)
	elseif self.tiptext then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
	end
end
function addon.HideTooltip()
	GameTooltip:Hide()
end

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
