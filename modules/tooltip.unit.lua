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

--[[
	local border, borderSize, borderInset = 'Interface\\Addons\\Midget\\media\\glow', 4, 4
	-- local border, borderSize, borderInset = 'Interface\\Addons\\Midget\\media\\double_border', 16, nil
	-- local border, borderSize, borderInset = 'Interface\\Addons\\Midget\\media\\grayborder', 16, nil

	-- default colors
	-- TOOLTIP_DEFAULT_COLOR.r = 0 -- border color
	-- TOOLTIP_DEFAULT_COLOR.g = 0
	-- TOOLTIP_DEFAULT_COLOR.b = 0
	-- TOOLTIP_DEFAULT_BACKGROUND_COLOR.r = 0 -- border background color
	-- TOOLTIP_DEFAULT_BACKGROUND_COLOR.g = 0
	-- TOOLTIP_DEFAULT_BACKGROUND_COLOR.b = 0

	-- default backdrop
	local backdrop = GameTooltip:GetBackdrop()
	      backdrop.edgeFile = border or 'Interface\\Addons\\Midget\\media\\glow'
	      backdrop.edgeSize = borderSize
	      backdrop.insets.left   = borderInset or backdrop.insets.left
	      backdrop.insets.right  = borderInset or backdrop.insets.right
	      backdrop.insets.top    = borderInset or backdrop.insets.top
	      backdrop.insets.bottom = borderInset or backdrop.insets.bottom
	GameTooltip:SetBackdrop(backdrop)
	-- GameTooltip:SetBackdropColor(TOOLTIP_DEFAULT_BACKGROUND_COLOR.r, TOOLTIP_DEFAULT_BACKGROUND_COLOR.g, TOOLTIP_DEFAULT_BACKGROUND_COLOR.b)
	-- GameTooltip:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
	-- local tooltips = { GameTooltip, ItemRefTooltip, ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3, WorldMapTooltip, EventTraceTooltip, FrameStackTooltip }
	-- for _, tooltip in pairs(tooltips) do
	-- 	tooltip:SetBackdrop(backdrop)
	-- end

	-- tooltip position
	hooksecurefunc('GameTooltip_SetDefaultAnchor', function(self, parent)
		self:SetPoint('BOTTOMRIGHT', 'UIParent', 'BOTTOMRIGHT', -72, 152)
	end)

	-- default statusbar
	local statusBar = GameTooltipStatusBar
	      statusBar:SetPoint('BOTTOMLEFT', 5, 5)
	      statusBar:SetPoint('BOTTOMRIGHT', -5, 5)
	      statusBar:SetStatusBarTexture('Interface\\Addons\\Midget\\media\\TukTexture')
	GameTooltip.statusBar = statusBar
	local bg = GameTooltip.statusBar:CreateTexture(nil, 'BACKGROUND', nil, -8)
	      bg:SetPoint('TOPLEFT', -1, 1)
	      bg:SetPoint('BOTTOMRIGHT', 1, -1)
	      bg:SetTexture(1, 1, 1)
	      bg:SetVertexColor(0, 0, 0, 0.7)
	GameTooltip.statusBar.bg = bg

	hooksecurefunc(getmetatable(_G['GameTooltip']).__index, 'Show', function(self)
		self:SetBackdropColor(
			TOOLTIP_DEFAULT_BACKGROUND_COLOR.r,
			TOOLTIP_DEFAULT_BACKGROUND_COLOR.g,
			TOOLTIP_DEFAULT_BACKGROUND_COLOR.b
		)
		if not self:GetItem() and not self:GetUnit() then
			self:SetBackdropBorderColor(TOOLTIP_DEFAULT_COLOR.r, TOOLTIP_DEFAULT_COLOR.g, TOOLTIP_DEFAULT_COLOR.b)
		end
		--if self.addHeight then
		--	self.newHeight = self:GetHeight() + self.addHeight
		--end
	end)

	-- unit specifics
	hooksecurefunc(getmetatable(GameTooltip).__index, 'SetUnit', function(self, unit)
		print('unit set', unit)
	end)
	GameTooltip:HookScript('OnTooltipSetUnit', function(self)
		if self:IsUnit('mouseover') then
			-- _G[self:GetName().."TextLeft1"]:SetTextColor(GameTooltip_UnitColor("mouseover"))
			-- print('tooltip is mouseover', _G[self:GetName()..'TextLeft1']:GetTextColor())
		end

		local _, unit = GameTooltip:GetUnit()
		local r, g, b
		if UnitIsPlayer(unit) and UnitHealth(unit) > 0 and not UnitIsDeadOrGhost(unit) then
			local _, class = UnitClass(unit)
			local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
			r, g, b = color.r, color.g, color.b
			self.statusBar:SetStatusBarColor(r, g, b)
			self:SetBackdropBorderColor(r, g, b)
		else
			r, g, b = GameTooltip_UnitColor(unit)
		end
		_G[self:GetName()..'TextLeft1']:SetTextColor(r, g, b)
		self.statusBar:SetStatusBarColor(r, g, b)
		self:SetBackdropBorderColor(r, g, b)
		GameTooltip:SetBackdropColor(0, 0, 0)
	end)
--]]
