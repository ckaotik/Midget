local addonName, ns, _ = ...

-- GLOBALS: _G, ItemUpgradeFrame, GRAY_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, YELLOW_FONT_COLOR_CODE, RED_FONT_COLOR_CODE
-- GLOBALS: ItemUpgradeFrame_GetStatRow, GetInventoryItemLink, GetItemUpgradeItemInfo
-- GLOBALS: hooksecurefunc, strsplit, wipe

-- ================================================
-- Reforging info
-- ================================================
local LibItemUpgrade = LibStub('LibItemUpgradeInfo-1.0')
local numRows, upgradesHooked = 8 -- _G.ITEM_UPGRADE_MAX_STATS_SHOWN

local function SetItemForUpgrade(self)
	if not GetItemUpgradeItemInfo() then
		PickupInventoryItem(self.slotID)
		SetItemUpgradeFromCursorItem()
	end
end

local function DisplayItemUpgradeInfo()
	if not upgradesHooked then
		-- we need this hook since default UI reacts to events later than we do and overwrites us
		hooksecurefunc('ItemUpgradeFrame_Update', DisplayItemUpgradeInfo)
		upgradesHooked = true
	end
	if GetItemUpgradeItemInfo() then
		for index = 1, numRows do
			local left, right = ItemUpgradeFrame_GetStatRow(index)
			if left.Icon then left.Icon:Hide() end
			if right.Icon then right.Icon:Hide() end
		end
		return
	end

	ItemUpgradeFrame.MissingDescription:Hide()

	for index = 1, numRows do
		local left, right = ItemUpgradeFrame_GetStatRow(index, true)
		for column = 1, 2 do
			local line, slotID = left, index
			if column == 2 then
				line = right
				slotID = index + numRows
			end
			if slotID >= _G.INVSLOT_BODY then slotID = slotID + 1 end

			local itemLink = GetInventoryItemLink('player', slotID)
			if itemLink then
				local currentUpgrade, maxUpgrade, ilevelUpgrade = LibItemUpgrade:GetItemUpgradeInfo(itemLink)
				local itemLevel = LibItemUpgrade:GetUpgradedItemLevel(itemLink) or 0

				local color = ''
				if currentUpgrade == maxUpgrade then
					if currentUpgrade == 0 then
						color = GRAY_FONT_COLOR_CODE
					else
						color = GREEN_FONT_COLOR_CODE
					end
				elseif currentUpgrade == 0 then
					color = RED_FONT_COLOR_CODE
				else
					color = YELLOW_FONT_COLOR_CODE
				end

				if line.ItemIncText then
					line.ItemIncText:SetText('')
				end
				line.ItemLevelText:SetFormattedText("%s%d/%d|r", color, currentUpgrade, maxUpgrade)
				line.ItemText:SetText(itemLink)
			else
				if line.Icon then line.Icon:Hide() end
				line.ItemLevelText:SetText('')
				line.ItemText:SetText('')
			end

			if not line.slotID then
				line.Icon = line:CreateTexture()
				line.Icon:SetPoint('RIGHT', line.ItemLevelText, 'LEFT', 15, 0)
				line.Icon:SetSize(15, 15)
				line:EnableMouse(true)
				line:HookScript('OnEnter', ns.ShowTooltip)
				line:HookScript('OnLeave', ns.HideTooltip)
				line.slotID = slotID
				line:HookScript('OnMouseUp', SetItemForUpgrade)
			end
			line.hyperlink = itemLink
			line.Icon:Show()
			line.Icon:SetTexture( GetItemIcon(itemLink) )
			line:Show()
		end
	end
end

ns.RegisterEvent('UNIT_INVENTORY_CHANGED', function(self, event, unit)
	if unit == 'player' and ItemUpgradeFrame and ItemUpgradeFrame:IsShown() then
		DisplayItemUpgradeInfo()
	end
end, 'upgrade_update')
ns.RegisterEvent('ITEM_UPGRADE_MASTER_OPENED', DisplayItemUpgradeInfo, 'upgrade_open')
ns.RegisterEvent('ITEM_UPGRADE_MASTER_SET_ITEM', DisplayItemUpgradeInfo, 'upgrade_item')
