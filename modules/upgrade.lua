local addonName, addon, _ = ...
local plugin = addon:NewModule('Upgrade', 'AceEvent-3.0')

-- GLOBALS: _G, ItemUpgradeFrame, GRAY_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, YELLOW_FONT_COLOR_CODE, RED_FONT_COLOR_CODE
-- GLOBALS: ItemUpgradeFrame_GetStatRow, GetInventoryItemLink, GetItemUpgradeItemInfo
-- GLOBALS: hooksecurefunc, strsplit, wipe

-- ================================================
-- Reforging info
-- ================================================
local LibItemUpgrade = LibStub('LibItemUpgradeInfo-1.0')
local numRows, upgradesHooked = 8 -- _G.ITEM_UPGRADE_MAX_STATS_SHOWN

local slotNames = {_G['HEADSLOT'], _G['NECKSLOT'], _G['SHOULDERSLOT'], _G['SHIRTSLOT'], _G['CHESTSLOT'], _G['WAISTSLOT'], _G['LEGSSLOT'], _G['FEETSLOT'], _G['WRISTSLOT'], _G['HANDSSLOT'], _G['FINGER0SLOT'], _G['FINGER1SLOT'], _G['TRINKET0SLOT'], _G['TRINKET1SLOT'], _G['BACKSLOT'], _G['MAINHANDSLOT'], _G['SECONDARYHANDSLOT'], _G['RANGEDSLOT'], _G['TABARDSLOT'] }
local slotByInvType = {
	['INVTYPE_HEAD'] = 1,
	['INVTYPE_NECK'] = 2,
	['INVTYPE_SHOULDER'] = 3,
	['INVTYPE_BODY'] = 4,
	['INVTYPE_CHEST'] = 5,
	['INVTYPE_ROBE'] = 5,
	['INVTYPE_WAIST'] = 6,
	['INVTYPE_LEGS'] = 7,
	['INVTYPE_FEET'] = 8,
	['INVTYPE_WRIST'] = 9,
	['INVTYPE_HAND'] = 10,
	['INVTYPE_FINGER'] = 11,
	['INVTYPE_TRINKET'] = 13,
	['INVTYPE_CLOAK'] = 15,
	['INVTYPE_WEAPON'] = 16,
	['INVTYPE_SHIELD'] = 17,
	['INVTYPE_2HWEAPON'] = 16,
	['INVTYPE_WEAPONMAINHAND'] = 16,
	['INVTYPE_RANGED'] = 16,
	['INVTYPE_RANGEDRIGHT'] = 16,
	['INVTYPE_WEAPONOFFHAND'] = 17,
	['INVTYPE_HOLDABLE'] = 17,
	['INVTYPE_TABARD'] = 19,
}

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
			left.link = nil
			if right.Icon then right.Icon:Hide() end
			right.link = nil
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
				if not currentUpgrade and not maxUpgrade then
					currentUpgrade, maxUpgrade = 0, 0
				end

				local itemLevel = GetDetailedItemLevelInfo(itemLink) or 0

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

				local _, _, quality, _, _, _, _, _, equipSlot = GetItemInfo(itemLink)
				local r, g, b, qColor = GetItemQualityColor(quality)

				if line.ItemIncText then
					line.ItemIncText:SetText('')
				end

				line.ItemLevelText:SetText('|c'..qColor..itemLevel..'|r')
				line.ItemText:SetFormattedText('%s%d/%d %s', color, currentUpgrade, maxUpgrade, slotNames[slotByInvType[equipSlot]])
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
				line:HookScript('OnEnter', addon.ShowTooltip)
				line:HookScript('OnLeave', addon.HideTooltip)
				line.slotID = slotID
				line:HookScript('OnMouseUp', SetItemForUpgrade)
			end
			line.link = itemLink
			line.Icon:Show()
			line.Icon:SetTexture( GetItemIcon(itemLink) )
			line:Show()
		end
	end
end

function plugin:OnEnable()
	self:RegisterEvent('UNIT_INVENTORY_CHANGED', function(event, unit)
		if unit == 'player' and ItemUpgradeFrame and ItemUpgradeFrame:IsShown() then
			DisplayItemUpgradeInfo()
		end
	end)
	self:RegisterEvent('ITEM_UPGRADE_MASTER_OPENED', DisplayItemUpgradeInfo)
	self:RegisterEvent('ITEM_UPGRADE_MASTER_SET_ITEM', DisplayItemUpgradeInfo)
end

