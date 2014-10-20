local addonName, addon, _ = ...
local plugin = addon:NewModule('UnitTooltip', 'AceEvent-3.0')

-- GLOBALS: _G, UnitIsPlayer, UnitLevel, UnitGUID, CanInspect, GetInspectSpecialization, GetSpecializationInfoByID, GetInventoryItemLink, GetItemInfo, NotifyInspect, string
-- TODO: fix heirloom item levels
local LibItemUpgrade = LibStub("LibItemUpgradeInfo-1.0")

-- keys and values are weak and may be garbage collected
local unitCache = setmetatable({}, {
	__mode = "kv",
})

local unitTooltip, unitID = nil, nil
local function INSPECT_READY(event, guid)
	if not unitID or not UnitExists(unitID) or UnitGUID(unitID) ~= guid then
		unitCache[guid] = nil
		return
	end

	local specID = GetInspectSpecialization(unitID)
	local _, name, _, icon, _, role, _ = GetSpecializationInfoByID(specID)
	local level = UnitLevel(unitID)

	local itemLevels, mainHandLevel, isIncomplete = 0, nil, nil
	local numSlots = _G.INVSLOT_LAST_EQUIPPED - 3 -- tabard, ranged, body don't provide iLvl
	for slot = _G.INVSLOT_FIRST_EQUIPPED, _G.INVSLOT_LAST_EQUIPPED do
		if slot ~= _G.INVSLOT_TABARD and slot ~= _G.INVSLOT_BODY and slot ~= _G.INVSLOT_RANGED then
			local itemLink = GetInventoryItemLink(unitID, slot)
			-- local itemQuality = GetInventoryItemQuality(unitID, slot)
			local itemLevel
			if itemLink then
				itemLevel = LibItemUpgrade:GetUpgradedItemLevel(itemLink)
			elseif GetInventoryItemID(unitID, slot) then
				isIncomplete = true
			end
			itemLevels = itemLevels + (itemLevel or 0)

			-- apply main hand level if two hand and offhand empty
			if slot == _G.INVSLOT_MAINHAND and itemLink then
				local _, _, _, _, _, class, subclass, _, equipSlot = GetItemInfo(itemLink)
				if equipSlot == 'INVTYPE_2HWEAPON' or equipSlot == 'INVTYPE_RANGEDRIGHT' then
					mainHandLevel = itemLevel or 0
				end
			elseif slot == _G.INVSLOT_OFFHAND and not itemLink and mainHandLevel then
				-- itemLevels = itemLevels + mainHandLevel
				numSlots = numSlots - 1 -- blizzard calculates it this way presumably
				mainHandLevel = nil
			end
		end
	end

	local talentString = role and string.format('%s|T%s:0|t %s', _G['INLINE_'.. role ..'_ICON'], icon, name)
	local levelString = (not isIncomplete and itemLevels > 0) and string.format('%d |T%s:0|t', itemLevels/numSlots, 'Interface\\GROUPFRAME\\UI-GROUP-MAINTANKICON')

	-- store data and display
	if not unitCache[guid] then unitCache[guid] = {} end
	if talentString then unitCache[guid].talents = talentString end
	if levelString  then unitCache[guid].levels  = levelString  end

	if isIncomplete then
		-- request update. we could probably wait for GET_ITEM_INFO_RECEIVED instead to avoid using precious requests
		NotifyInspect(unitID)
	elseif unitTooltip and not unitTooltip.talentsAdded then
		-- add gathered data to tooltip
		unitTooltip:AddDoubleLine(talentString or '', levelString or '')
		unitTooltip.talentsAdded = true
		unitTooltip:Show()
	end
end

local function TooltipUnitInfo(tooltip)
	local _, unit = tooltip:GetUnit()
	if not unit or not UnitIsPlayer(unit) then return end

	-- move faction text up one line
	local faction = _G[tooltip:GetName()..'TextLeft4']
	local factionText = faction and faction:GetText()
	if faction and factionText and factionText ~= '' then
		local factionColor = (select(2, UnitFactionGroup(unit))) == 'Horde' and RED_FONT_COLOR_CODE or BATTLENET_FONT_COLOR_CODE
		local newFaction = _G[tooltip:GetName()..'TextRight3']
		      newFaction:SetText(factionColor .. faction:GetText() .. '|r')
		      newFaction:Show()
		faction:SetText(nil)
	end

	-- add talent and equipment info
	if UnitLevel(unit) >= 10 and not tooltip.talentsAdded then
		local guid = UnitGUID(unit)
		if unitCache[guid] and (unitCache[guid].talents or unitCache[guid].levels) then
			-- show in tooltip
			tooltip:AddDoubleLine(unitCache[guid].talents or '', unitCache[guid].levels or '')
			tooltip.talentsAdded = true
			tooltip:Show()
			if unitCache[guid].talents and unitCache[guid].levels then
				return
			end
		end

		if (UnitInParty(unit) or UnitInRaid(unit) or IsShiftKeyDown())
			and CanInspect(unit) and (not _G.InspectFrame or not _G.InspectFrame:IsShown()) then
			unitTooltip = tooltip
			unitID = unit
			NotifyInspect(unit)
		end
	end
end

-- display item specs
local itemSpecs = {}
local function TooltipItemInfo(self)
	local specs
	local _, itemLink = self:GetItem()
	if not itemLink then return end

	wipe(itemSpecs)
	GetItemSpecInfo(itemLink, itemSpecs)
	-- TODO: only show own specializations GetNumSpecializations()
	if #itemSpecs > 4 then return end
	for i, specID in ipairs(itemSpecs) do
		local _, _, _, icon, _, role, class = GetSpecializationInfoByID(specID)
		specs = (specs and specs..' ' or '') .. '|T'..icon..':0|t'
	end
	if not specs then return end

	local text = _G[self:GetName()..'TextRight'..(self:GetName():find('^ShoppingTooltip') and 2 or 1)]
	      text:SetText(specs)
	      text:Show()
end

function plugin:OnEnable()
	self:RegisterEvent('INSPECT_READY', INSPECT_READY)

	-- unit info
	GameTooltip:HookScript('OnTooltipSetUnit', TooltipUnitInfo)
	GameTooltip:HookScript('OnTooltipCleared', function(self)
		self.talentsAdded = nil
		unitID = nil
		unitTooltip = nil
	end)

	-- item info
	GameTooltip:HookScript('OnTooltipSetItem', TooltipItemInfo)
	ItemRefTooltip:HookScript('OnTooltipSetItem', TooltipItemInfo)
	if ShoppingTooltip1 then ShoppingTooltip1:HookScript('OnTooltipSetItem', TooltipItemInfo) end
	if ShoppingTooltip2 then ShoppingTooltip2:HookScript('OnTooltipSetItem', TooltipItemInfo) end

	-- tooltip position
	hooksecurefunc('GameTooltip_SetDefaultAnchor', function(self, parent)
		self:SetPoint('BOTTOMRIGHT', 'UIParent', 'BOTTOMRIGHT', -72, 152)
	end)

	GameTooltip:HookScript('OnTooltipSetUnit', function(self)
		local _, unit = GameTooltip:GetUnit()
		local r, g, b
		if UnitIsPlayer(unit) and UnitHealth(unit) > 0 and not UnitIsDeadOrGhost(unit) then
			local _, class = UnitClass(unit)
			local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
			self.statusBar:SetStatusBarColor(color.r, color.g, color.b)
		end
	end)
end























-- "tooltip filter" as a name?
local tooltips = addon:NewModule('Tooltips', 'AceEvent-3.0')
local defaults = {
	profile = {
		border = 'Interface\\Addons\\Midget\\media\\glow',
		borderSize = 4,
		borderInset = 4,
		borderColor = {0, 0, 0},
		backgroundColor = {0, 0, 0},
		item = {
			-- reforgeColor = {1, 0.5, 1},
			enchantColor = {0, 0.8, 1},
			primaryStatsColor = {1, 1, 1},
			secondaryStatsColor = {0, 1, 0},
			hideLines = {
				-- durability, equipment sets, item level, item upgrades, socketing info, purchase/return info, vendor price, raid difficulty/warforged, created by, reforged, binding/soulbound, unique, set name, set items list, set bonuses, requirements, transmogrification
			},
		},
	},
}

-- hiding tooltip lines in plain sight
local hiddenLines, emptyTable = {}, {}
local function HideLine(lineNum, hide, left, right)
	local offset = hide and 3 or -3 -- = 2px margin + 1px height
	local point, relativeTo, relativePoint, xOffset, yOffset = left:GetPoint()
	      left:SetPoint(point, relativeTo, relativePoint, xOffset, yOffset + offset)
	local point, relativeTo, relativePoint, xOffset, yOffset = right:GetPoint()
          right:SetPoint(point, relativeTo, relativePoint, xOffset, yOffset + offset)

	local tooltip = left:GetParent()
	if hide or tooltip.addHeight then
		tooltip.addHeight = (tooltip.addHeight or 0) - offset
		tooltip:Show()
	end
	hiddenLines[tooltip][lineNum] = hide or nil
end
local function ShowHideTooltipLine(lineFontString, text)
	local tooltip = lineFontString:GetParent()
	local tipName = tooltip:GetName()
	local lineNum = lineFontString:GetName():match('^'..tipName..'Text.-(%d+)$')
	local left, right = _G[tipName..'TextLeft'..lineNum], _G[tipName..'TextRight'..lineNum]

	-- make sure both sides are empty when hiding
	local hide = not text or text == '' or nil
	local otherText = (lineFontString == left and right or left):GetText()
	if (hide and otherText and otherText ~= '') 		-- other side still displays text
		or (hide == hiddenLines[tooltip][lineNum]) then -- state remains unchanged
		return
	end
	HideLine(lineNum, hide, left, right)
end

local function TooltipOnUpdate(self, elapsed)
	if self.newHeight and abs(self:GetHeight() - self.newHeight) > 0.1 then
		self:SetHeight(self.newHeight)
	end
end
local function TooltipOnShow(self)
	self.newHeight = self.addHeight and (self:GetHeight() + self.addHeight) or nil
	TooltipOnUpdate(self, 0) -- to fix static tooltips, e.g. ItemRefTooltip
end
local function TooltipOnClear(self)
	local tipName = self:GetName()
	self.addHeight, self.newHeight = nil, nil
	-- fix line anchors
	for lineNum in pairs(hiddenLines[self] or emptyTable) do
		local left, right = _G[tipName..'TextLeft'..lineNum], _G[tipName..'TextRight'..lineNum]
		HideLine(lineNum, false, left, right)
	end
end

-- sets hooks to completely hide empty lines
local function RegisterTooltipLine(tooltip, lineNum)
	local tipName = type(tooltip) == 'string' and tooltip or tooltip:GetName()
	local left, right = _G[tipName..'TextLeft'..lineNum], _G[tipName..'TextRight'..lineNum]
	if left and not left.canHide then
		hooksecurefunc(left,  'SetText', ShowHideTooltipLine)
		hooksecurefunc(right, 'SetText', ShowHideTooltipLine)
		left.canHide = true
	end
	return (left or right) and true or nil
end

function tooltips:RegisterTooltip()
	local tipName, lineNum = self:GetName(), 1
	while RegisterTooltipLine(tipName, lineNum) do
		lineNum = lineNum + 1
	end
	if self.isRegistered then return end
	hiddenLines[self] = {}
	-- self:HookScript('OnShow', TooltipOnShow)
	hooksecurefunc(self, 'Show', TooltipOnShow)
	self:HookScript('OnUpdate', TooltipOnUpdate)
	self:HookScript('OnTooltipCleared', TooltipOnClear)
	self.isRegistered = true
end

-- --------------------------------------------------------
--  Addon Setup
-- --------------------------------------------------------
function tooltips:OnInitialize()
	-- nothing yet
end

function tooltips:OnEnable()
	print('tooltips name:', self:GetName())
	self.db = addon.db:RegisterNamespace('Tooltips', defaults)

	-- don't add spacing for closing 'x'
	ItemRefTooltip:SetPadding(0)

	-- allow to completely hide empty lines
	-- note: if you still want to add empty lines that use up space, set the text to ' '(space)
	local function OnTooltipAddLine(self) RegisterTooltipLine(self:GetName(), self:NumLines()) end
	local tooltips = { 'GameTooltip', 'ItemRefTooltip', 'ShoppingTooltip1', 'ShoppingTooltip2' }
	for _, tipName in pairs(tooltips) do
		local tooltip = _G[tipName]
		if tooltip then
			-- we need to hook into every situation when a line (i.e. font string) is created...
			-- OnTooltipSet*: Achievement, EquipmentSet, Quest, Spell, Item, Unit
			tooltip:HookScript('OnTooltipSetItem', self.RegisterTooltip)
			self.RegisterTooltip(tooltip)
		end
	end

	-- GameTooltipTexture1:GetTexture() = 'Interface\\ItemSocketingFrame\\UI-EmptySocket-Red'

	LibStub('AceConfig-3.0'):RegisterOptionsTable(self:GetName(), {
		type = 'group',
		args = {
			main = LibStub('LibOptionsGenerate-1.0'):GetOptionsTable(addonName..'.db.children.Tooltips.profile', types),
		},
	})
	LibStub('AceConfigDialog-3.0'):AddToBlizOptions(self:GetName(), 'Tooltips', addonName, 'main')
end





--[[
	local statusBarMargin, statusBarBorderWidth = 0, 0 -- 1, 1
	-- local border, borderSize, borderInset = 'Interface\\Addons\\Midget\\media\\glow', 4, 4
	-- local border, borderSize, borderInset = 'Interface\\Addons\\Midget\\media\\double_border', 16, nil
	-- local border, borderSize, borderInset = 'Interface\\Addons\\Midget\\media\\grayborder', 16, nil
	local backgroundColor = _G.TOOLTIP_DEFAULT_BACKGROUND_COLOR
	local borderColor     = _G.TOOLTIP_DEFAULT_COLOR

	-- default colors
	-- TOOLTIP_DEFAULT_COLOR.r = 0
	-- TOOLTIP_DEFAULT_COLOR.g = 0
	-- TOOLTIP_DEFAULT_COLOR.b = 0
	-- TOOLTIP_DEFAULT_BACKGROUND_COLOR.r = 0
	-- TOOLTIP_DEFAULT_BACKGROUND_COLOR.g = 0
	-- TOOLTIP_DEFAULT_BACKGROUND_COLOR.b = 0

	-- default backdrop
	local backdrop = GameTooltip:GetBackdrop()
	      backdrop.edgeFile      = border or backdrop.edgeFile
	      backdrop.edgeSize      = borderSize or backdrop.edgeSize
	      backdrop.insets.left   = borderInset or backdrop.insets.left
	      backdrop.insets.right  = borderInset or backdrop.insets.right
	      backdrop.insets.top    = borderInset or backdrop.insets.top
	      backdrop.insets.bottom = borderInset or backdrop.insets.bottom
	GameTooltip:SetBackdrop(backdrop)
	-- GameTooltip:SetBackdropColor(backgroundColor.r, backgroundColor.g, backgroundColor.b)
	-- GameTooltip:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b)
	-- local tooltips = { GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3, WorldMapTooltip, EventTraceTooltip, FrameStackTooltip }
	-- for _, tooltip in pairs(tooltips) do
	-- 	-- apply changed settings to existing tooltips
	-- 	tooltip:SetBackdrop(backdrop)
	-- end

	-- tooltip position
	hooksecurefunc('GameTooltip_SetDefaultAnchor', function(self, parent)
		self:SetPoint('BOTTOMRIGHT', 'UIParent', 'BOTTOMRIGHT', -72, 152)
	end)

	hooksecurefunc('GameTooltip_OnHide', function(self)
		-- self:SetBackdropColor(backgroundColor.r, backgroundColor.g, backgroundColor.b)
		-- self:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b)
	end)

	-- default statusbar
	local statusBarInset = (borderInset or 5) + (statusBarMargin or 0)
	local statusBar = GameTooltipStatusBar
	      statusBar:SetPoint('BOTTOMLEFT', statusBarInset, statusBarInset)
	      statusBar:SetPoint('BOTTOMRIGHT', -statusBarInset, statusBarInset)
	      statusBar:SetStatusBarTexture('Interface\\Addons\\Midget\\media\\TukTexture')
	GameTooltip.statusBar = statusBar
	local bg = GameTooltip.statusBar:CreateTexture(nil, 'BACKGROUND', nil, -8)
	      bg:SetPoint('TOPLEFT', -statusBarBorderWidth, statusBarBorderWidth)
	      bg:SetPoint('BOTTOMRIGHT', statusBarBorderWidth, -statusBarBorderWidth)
	      bg:SetTexture(1, 1, 1)
	      bg:SetVertexColor(0, 0, 0, 0.7)
	GameTooltip.statusBar.bg = bg

	hooksecurefunc(getmetatable(_G['GameTooltip']).__index, 'Show', function(self)
		-- self:SetBackdropColor(backgroundColor.r,backgroundColor.g,backgroundColor.b)
		if not self:GetItem() and not self:GetUnit() then
			-- self:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b)
		end
		--if self.addHeight then
		--	self.newHeight = self:GetHeight() + self.addHeight
		--end
	end)

	-- unit specifics
	-- hooksecurefunc(getmetatable(GameTooltip).__index, 'SetUnit', function(self, unit)
	-- 	print('unit set', unit)
	-- end)
	GameTooltip:HookScript('OnTooltipSetUnit', function(self)
		local _, unit = self:GetUnit()
		local r, g, b
		if UnitIsPlayer(unit) and UnitHealth(unit) > 0 and not UnitIsDeadOrGhost(unit) then
			local _, class = UnitClass(unit)
			local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
			r, g, b = color.r, color.g, color.b
		elseif unit then
			-- FIXME: sometimes, targettargettarget has no unit?
			r, g, b = GameTooltip_UnitColor(unit)
		end
		if r then
			_G[self:GetName()..'TextLeft1']:SetTextColor(r, g, b)
			self.statusBar:SetStatusBarColor(r, g, b)
			-- self:SetBackdropBorderColor(r, g, b)
		end
	end)
--]]
