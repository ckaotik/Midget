local addonName, ns, _ = ...

-- GLOBALS: _G, UnitIsPlayer, UnitLevel, UnitGUID, CanInspect, GetInspectSpecialization, GetSpecializationInfoByID, GetInventoryItemLink, GetItemInfo, NotifyInspect, string
local LibItemUpgrade = LibStub("LibItemUpgradeInfo-1.0")

-- keys and values are weak and may be garbage collected
local unitCache = setmetatable({}, {
	__mode = "kv",
})

local unitTooltip, unitID = nil, nil
local function INSPECT_READY(self, event, guid)
	if not unitID or not UnitExists(unitID) then return end
	local specID = GetInspectSpecialization(unitID)
	local _, name, _, icon, _, role, _ = GetSpecializationInfoByID(specID)

	local itemLevels, mainHandLevel, isIncomplete = 0, nil, nil
	local numSlots = _G.INVSLOT_LAST_EQUIPPED - 3 -- tabard, ranged, body don't provide iLvl
	for slot = _G.INVSLOT_FIRST_EQUIPPED, _G.INVSLOT_LAST_EQUIPPED do
		if slot ~= _G.INVSLOT_TABARD and slot ~= _G.INVSLOT_BODY and slot ~= _G.INVSLOT_RANGED then
			local itemLink = GetInventoryItemLink(unitID, slot)
			if not itemLink and GetInventoryItemID(unitID, slot) then
				isIncomplete = true
			end
			local itemLevel = itemLink and LibItemUpgrade:GetUpgradedItemLevel(itemLink)
			itemLevels = itemLevels + (itemLevel or 0)

			-- apply main hand level if two hand and offhand empty
			if slot == _G.INVSLOT_MAINHAND and itemLink then
				local _, _, _, _, _, class, subclass, _, equipSlot = GetItemInfo(itemLink)
				if equipSlot == 'INVTYPE_2HWEAPON' then -- and not IsDualWielding() then
					mainHandLevel = itemLevel
				end
			elseif slot == _G.INVSLOT_OFFHAND and not itemLink and mainHandLevel then
				itemLevels = itemLevels + mainHandLevel
				mainHandLevel = nil
			end
		end
	end

	local talentString = role and string.format('%s|T%s:0|t %s', _G['INLINE_'..role..'_ICON'], icon, name)
	local levelString = (not isIncomplete and itemLevels > 0) and string.format('%d |T%s:0|t', itemLevels/numSlots, 'Interface\\GROUPFRAME\\UI-GROUP-MAINTANKICON')

	if not unitCache[guid] then unitCache[guid] = {} end
	if talentString then unitCache[guid].talents = talentString end
	if levelString  then unitCache[guid].levels  = levelString  end

	if isIncomplete then
		-- request update. we could probably wait for GET_ITEM_INFO_RECEIVED instead to avoid using precious requests
		NotifyInspect(unitID)
	elseif unitTooltip and not unitTooltip.talentsAdded and UnitGUID(unitID) == guid then
		-- add gathered data to tooltip
		unitTooltip:AddDoubleLine(talentString or '', levelString or '')
		unitTooltip.talentsAdded = true
		unitTooltip:Show()
	end
end
ns.RegisterEvent('INSPECT_READY', INSPECT_READY, 'unit_inspect')

-- when talents or equipment change, have the tooltip/cache update!
local function UNIT_INVENTORY_CHANGED(...)
	print(...)
	-- unitCache[guid].numRequests = nil
end
-- ns.RegisterEvent('UNIT_INVENTORY_CHANGED', UNIT_INVENTORY_CHANGED, 'unit_inventory')

local function TooltipUnitInfo(tooltip)
	local _, unit = tooltip:GetUnit()
	if not unit or not UnitIsPlayer(unit) or UnitLevel(unit) < 10 or tooltip.talentsAdded then return end

	local guid = UnitGUID(unit)
	if unitCache[guid] and unitCache[guid].talents then
		-- show in tooltip
		tooltip:AddDoubleLine(unitCache[guid].talents or '', unitCache[guid].levels or '')
		tooltip.talentsAdded = true
		tooltip:Show()
	elseif CanInspect(unit) and (not _G.InspectFrame or not _G.InspectFrame:IsShown()) then
		unitTooltip = tooltip
		unitID = unit
		NotifyInspect(unit)
	end
end
GameTooltip:HookScript('OnTooltipSetUnit', TooltipUnitInfo)
GameTooltip:HookScript('OnTooltipCleared', function(self) self.talentsAdded = nil end)
