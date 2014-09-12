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

function plugin:OnEnable()
	self:RegisterEvent('INSPECT_READY', INSPECT_READY)
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
GameTooltip:HookScript('OnTooltipSetUnit', TooltipUnitInfo)
GameTooltip:HookScript('OnTooltipCleared', function(self)
	self.talentsAdded = nil
	unitID = nil
	unitTooltip = nil
end)

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
GameTooltip:HookScript('OnTooltipSetItem', TooltipItemInfo)
ItemRefTooltip:HookScript('OnTooltipSetItem', TooltipItemInfo)
ShoppingTooltip1:HookScript('OnTooltipSetItem', TooltipItemInfo)
ShoppingTooltip2:HookScript('OnTooltipSetItem', TooltipItemInfo)
ShoppingTooltip3:HookScript('OnTooltipSetItem', TooltipItemInfo)
