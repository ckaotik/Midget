local addonName, addon, _ = ...
local plugin = addon:NewModule('Reforge', 'AceEvent-3.0')

-- GLOBALS: _G, ReforgingFrame
-- GLOBALS: GetReforgeItemInfo, ReforgingFrame_GetStatRow, GetInventoryItemLink, GetItemStats, GetItemIcon, PickupInventoryItem, SetReforgeFromCursorItem
-- GLOBALS: hooksecurefunc, strsplit, wipe

-- ================================================
-- Reforging info
-- ================================================
local LibReforging = LibStub('LibReforgingInfo-1.0')
local LibItemUpgrade = LibStub('LibItemUpgradeInfo-1.0')
local reforgeInfoPattern = '%3d '.._G.GREEN_FONT_COLOR_CODE..'%s|r '.._G.RED_FONT_COLOR_CODE..'%s|r'
local upgradeStatExp, itemStats = 1.00936754973658, {}
local reforgeStatNames = {
	'ITEM_MOD_SPIRIT_SHORT',
	'ITEM_MOD_DODGE_RATING_SHORT',
	'ITEM_MOD_PARRY_RATING_SHORT',
	'ITEM_MOD_HIT_RATING_SHORT',
	'ITEM_MOD_CRIT_RATING_SHORT',
	'ITEM_MOD_HASTE_RATING_SHORT',
	'ITEM_MOD_EXPERTISE_RATING_SHORT',
	'ITEM_MOD_MASTERY_RATING_SHORT'
}

local function SetItemForReforge(self)
	if not GetReforgeItemInfo() then
		PickupInventoryItem(self.slotID)
		SetReforgeFromCursorItem()
	end
end

local reforgeHooked
local function DisplayReforgingFrameInfo()
	if not reforgeHooked then
		-- we need this hook since default UI reacts to events later than we do and overwrites us
		hooksecurefunc('HideStats', DisplayReforgingFrameInfo)
		reforgeHooked = true
	end
	if GetReforgeItemInfo() then
		for index = 1, _G.REFORGE_MAX_STATS_SHOWN do
			local left, right = ReforgingFrame_GetStatRow(index)
			if left.Icon then left.Icon:Hide() end
			left.hyperlink = nil
			if right.Icon then right.Icon:Hide() end
			right.hyperlink = nil
		end
		ReforgingFrame.RestoreMessage:SetText(_G.REFORGE_RESTORE_MESSAGE)
		ReforgingFrame.RestoreMessage:SetTextColor(0, 0, 0, 1)
		return
	end

	ReforgingFrame.MissingDescription:Hide()
	ReforgingFrame.RestoreMessage:SetText("This view shows you a list of all your equipped items and their reforges. Added stats are colored green, removed stats are colored red. Click any line to reforge that item.")
	ReforgingFrame.RestoreMessage:SetTextColor(1, 0.82, 0, 1)
	ReforgingFrame.RestoreMessage:Show()

	for index = 1, _G.REFORGE_MAX_STATS_SHOWN do
		local left, right = ReforgingFrame_GetStatRow(index, true)
		for column = 1, 2 do
			local line, slotID = left, index
			if column == 2 then
				line = right
				slotID = index + _G.REFORGE_MAX_STATS_SHOWN
			end
			if slotID >= _G.INVSLOT_BODY then slotID = slotID + 1 end

			local itemLink = GetInventoryItemLink('player', slotID)
			local reforge = itemLink and LibReforging:GetReforgeID(itemLink)
			if reforge then
				local oldStat, newStat     = LibReforging:GetReforgedStatShortNames(reforge)
				local oldStatID, newStatID = LibReforging:GetReforgedStatIDs(reforge)

				wipe(itemStats)
				local stats       = GetItemStats(itemLink, itemStats)
				local itemUpgrade = LibItemUpgrade:GetItemLevelUpgrade( LibItemUpgrade:GetUpgradeID(itemLink) )
				local statValue   = 0.4 * stats[ reforgeStatNames[oldStatID] ] * (upgradeStatExp ^ itemUpgrade)

				line.Text:SetFormattedText(reforgeInfoPattern, statValue, (strsplit(' ', newStat)), (strsplit(' ', oldStat)))
			else
				if line.Icon then line.Icon:Hide() end
				line.Text:SetText('')
			end

			if not line.Icon then
				line.Icon = line:CreateTexture()
				line.Icon:SetAllPoints(line.Button)
				line:HookScript('OnEnter', addon.ShowTooltip)
				line.slotID = slotID
				line:HookScript('OnClick', SetItemForReforge)
			end
			line.hyperlink = itemLink
			line.Icon:Show()
			line.Icon:SetTexture( GetItemIcon(itemLink) )
			line.Button:Hide()

			line:Enable()
			line:Show()
		end
	end
end

function plugin:OnEnable()
	self:RegisterEvent('UNIT_INVENTORY_CHANGED', function(event, unit)
		if unit == 'player' and ReforgingFrame and ReforgingFrame:IsShown() then
			DisplayReforgingFrameInfo()
		end
	end)
	self:RegisterEvent('FORGE_MASTER_OPENED',   DisplayReforgingFrameInfo)
	self:RegisterEvent('FORGE_MASTER_SET_ITEM', DisplayReforgingFrameInfo)
end
