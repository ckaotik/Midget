local addonName, addon, _ = ...
local plugin = addon:NewModule('UnitTooltip', 'AceEvent-3.0')

-- GLOBALS: _G, LibStub, RED_FONT_COLOR, GameTooltip, hooksecurefunc
-- GLOBALS: UnitIsPlayer, UnitLevel, UnitGUID, CanInspect, GetInspectSpecialization, GetSpecializationInfoByID, GetInventoryItemLink, GetItemInfo, NotifyInspect, UnitInParty, UnitInRaid

local LibItemUpgrade = LibStub('LibItemUpgradeInfo-1.0')

-- keys and values are weak and may be garbage collected
local unitCache = setmetatable({}, {
	__mode = 'kv',
})

local function TooltipUnitInfo(tooltip)
	local _, unit = tooltip:GetUnit()
	if not unit then
		-- TODO: try GetMouseFocus().unit
	end
	if not unit then return end

	-- move faction text up one line
	--[[
	local factionGroup, faction = UnitFactionGroup(unit)
	local faction = _G[tooltip:GetName()..'TextLeft4']
	local factionText = faction and faction:GetText()
	if faction and factionText and factionText ~= '' then
		local factionColor = (select(2, UnitFactionGroup(unit))) == 'Horde' and RED_FONT_COLOR_CODE or BATTLENET_FONT_COLOR_CODE
		local newFaction = _G[tooltip:GetName()..'TextRight3']
		      newFaction:SetText(factionColor .. faction:GetText() .. '|r')
		      newFaction:Show()
		faction:SetText(nil)
	end --]]

	local guid = UnitGUID(unit)
	local data = unitCache[guid]

	-- add talent and equipment info
	if UnitIsPlayer(unit) and UnitLevel(unit) >= 10 and data then
		-- TODO: notify when raid role does not match spec role
		-- local role, isLeader = UnitGroupRolesAssigned(unit), UnitIsGroupLeader(unit)

		local _, specName, _, specIcon, _, role, _ = GetSpecializationInfoByID(data.spec or 0)
		local left   = role and ('%s|T%s:0|t %s'):format(_G['INLINE_'.. role ..'_ICON'], specIcon, specName) or ''
		local ilevel = data.ilevel
		local right  = (ilevel and ilevel > 0) and ('%d |T%s:0|t'):format(ilevel, 'Interface\\GROUPFRAME\\UI-GROUP-MAINTANKICON') or ''

		if not data.complete then
			right = _G.RED_FONT_COLOR_CODE .. right .. '|r'
		end

		if tooltip.talents then
			-- reuse existing line
			_G[tooltip:GetName()..'TextLeft'..tooltip.talents]:SetText(left)
			_G[tooltip:GetName()..'TextRight'..tooltip.talents]:SetText(right)
		else
			tooltip:AddDoubleLine(left, right)
			tooltip.talents = tooltip:NumLines()
		end
		tooltip:Show()
	end
	if (not data or not data.complete) and (not _G.InspectFrame or not _G.InspectFrame:IsShown())
		and CanInspect(unit) and (UnitInParty(unit) or UnitInRaid(unit) or IsShiftKeyDown()) then
		-- TODO: use item data received event instead of new inspect when not data.complete
		NotifyInspect(unit)
	end

	-- color health bar by class
	if UnitIsPlayer(unit) and UnitHealth(unit) > 0 and not UnitIsDeadOrGhost(unit) then
		local _, class = UnitClass(unit)
		local color = (_G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS)[class]
		local statusBar = _G[tooltip:GetName()..'StatusBar']
		if statusBar then
			statusBar:SetStatusBarColor(color.r, color.g, color.b)
		end
	end
	-- r, g, b = GameTooltip_UnitColor(unit)
	-- _G[tooltip:GetName()..'TextLeft1']:SetTextColor(r, g, b)
end

function plugin:INSPECT_READY(event, guid)
	local className, class, _, _, gender, unitName, realm = GetPlayerInfoByGUID(guid)
	-- this is not a player
	if not className or not unitCache[guid] then return end

	local unit = unitCache[guid].unit
	-- unit has changed since request, unit and guid do not match
	if UnitGUID(unit) ~= guid then return end

	if unit then
		-- get unit specialization
		local specID = GetInspectSpecialization(unit)
		unitCache[guid].spec = specID ~= 0 and specID or unitCache[guid].spec

		-- TODO: fix heirloom item levels
		-- get unit average item level
		local itemLevels, mainHandLevel, complete = 0, nil, true
		local numSlots = _G.INVSLOT_LAST_EQUIPPED - 3 -- tabard, ranged, body don't provide iLvl
		for slot = _G.INVSLOT_FIRST_EQUIPPED, _G.INVSLOT_LAST_EQUIPPED do
			if slot ~= _G.INVSLOT_TABARD and slot ~= _G.INVSLOT_BODY and slot ~= _G.INVSLOT_RANGED then
				local itemID   = GetInventoryItemID(unit, slot)
				local itemLink = GetInventoryItemLink(unit, slot)
				if itemID and not itemLink then
					-- item data is not available
					complete = false
					itemLink = 'item:'..itemID
				end

				local itemLevel = itemLink and LibItemUpgrade:GetUpgradedItemLevel(itemLink) or 0
				itemLevels = itemLevels + itemLevel

				-- apply main hand level if two hand and offhand empty
				if slot == _G.INVSLOT_MAINHAND and itemLink then
					local _, _, _, _, _, class, subclass, _, equipSlot = GetItemInfo(itemLink)
					if equipSlot == 'INVTYPE_2HWEAPON' or equipSlot == 'INVTYPE_RANGEDRIGHT' then
						mainHandLevel = itemLevel
					end
				elseif slot == _G.INVSLOT_OFFHAND and not itemLink and mainHandLevel then
					-- blizzard supposedly calculates it this way
					numSlots = numSlots - 1
					mainHandLevel = nil
				end
			end
		end
		unitCache[guid].ilevel = itemLevels/numSlots or unitCache[guid].ilevel
		unitCache[guid].complete = complete
	end

	-- update tooltip
	TooltipUnitInfo(GameTooltip)
end

function plugin:PLAYER_SPECIALIZATION_CHANGED()
	wipe(unitCache)
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
	-- tooltip position
	hooksecurefunc('GameTooltip_SetDefaultAnchor', function(self, parent)
		self:SetPoint('BOTTOMRIGHT', 'UIParent', 'BOTTOMRIGHT', -72, 152)
	end)

	-- item info
	for _, tipName in pairs({'GameTooltip', 'ItemRefTooltip', 'ShoppingTooltip1', 'ShoppingTooltip2'}) do
		local tooltip = _G[tipName]
		if tooltip then
			tooltip:HookScript('OnTooltipSetItem', TooltipItemInfo)
		end
	end

	-- unit info
	self:RegisterEvent('INSPECT_READY')
	self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
	GameTooltip:HookScript('OnTooltipSetUnit', TooltipUnitInfo)
	GameTooltip:HookScript('OnTooltipCleared', function(self)
		self.talents = nil
	end)

	hooksecurefunc('NotifyInspect', function(unit)
		if not UnitIsPlayer(unit) then return end
		local guid = UnitGUID(unit)
		if not unitCache[guid] then unitCache[guid] = {} end
		unitCache[guid].unit = unit
	end)
end




















-- for now since tooltip height calc is weird
if true then return end

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
	-- hooksecurefunc(getmetatable(GameTooltip).__index, 'SetItemByID', print)
end

function tooltips:OnEnable()
	local moduleName = self:GetName()
	self.db = addon.db:RegisterNamespace(moduleName, defaults)

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
			main = LibStub('LibOptionsGenerate-1.0'):GetOptionsTable(self.db, types),
		},
	})
	LibStub('AceConfigDialog-3.0'):AddToBlizOptions(self:GetName(), moduleName, addonName, 'main')
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
		-- self:SetBackdropColor(backgroundColor.r, backgroundColor.g, backgroundColor.b)
		if not self:GetItem() and not self:GetUnit() then
			-- self:SetBackdropBorderColor(borderColor.r, borderColor.g, borderColor.b)
		end
		--if self.addHeight then
		--	self.newHeight = self:GetHeight() + self.addHeight
		--end
	end)
--]]
