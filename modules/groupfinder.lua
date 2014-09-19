local addonName, addon, _ = ...
local plugin = addon:NewModule('GroupFinder', 'AceEvent-3.0')

-- GLOBALS: _G, hooksecurefunc
-- GLOBALS: SearchLFGGetResults, SearchLFGGetPartyResults

local playerRealm = GetRealmName()

-- ================================================
-- Add further info to lfg tooltips
-- ================================================
local function AddLFREntryInfo(button, index)
	local name, level, areaName, className, comment, partyMembers, status, class, encountersTotal, encountersComplete, isIneligible, isLeader, isTank, isHealer, isDamage, bossKills, specID, isGroupLeader, armor, spellDamage, plusHealing, CritMelee, CritRanged, critSpell, mp5, mp5Combat, attackPower, agility, maxHealth, maxMana, gearRating, avgILevel, defenseRating, dodgeRating, BlockRating, ParryRating, HasteRating, expertise = SearchLFGGetResults(index)

	local unitName, unitRealm = strsplit('-', name)
	button.name:SetText(unitName)
	button.class:SetText(_G.NORMAL_FONT_COLOR_CODE .. (unitRealm or playerRealm) .. '|r')

	if button.type == 'individual' then
		local color = _G.RAID_CLASS_COLORS[class] or _G.NORMAL_FONT_COLOR
		button.name:SetTextColor(color.r, color.g, color.b)
		if isDamage and spellDamage > attackPower then
			-- caster dps shown in green, otherwise regular (red)
			button.damageIcon:SetTexture('Interface\\LFGFRAME\\LFGRole_Green')
		end

		if level == 90 then
			button.level:SetFormattedText('%d', avgILevel)
		end
		button.tankCount:SetText('')
		button.healerCount:SetText('')
		button.damageCount:SetText('')
	else
		local color = _G.NORMAL_FONT_COLOR
		button.name:SetTextColor(color.r, color.g, color.b)
		if level == 90 then
			local _, _, _, _, _, partyMembers = SearchLFGGetResults(button.index)
			local numTanks, numHeals, numDPS = isTank and 1 or 0, isHealer and 1 or 0, isDamage and 1 or 0
			local itemLevels = avgILevel
			for i = 1, partyMembers do
				local name, level, relationship, className, areaName, comment, isLeader, isTank, isHealer, isDamage, bossKills, specID, isGroupLeader, _, _, _, _, _, _, _, _, _, _, _, _, _, avgILevel = SearchLFGGetPartyResults(button.index, i)
				numTanks = numTanks + (isTank   and 1 or 0)
				numHeals = numHeals + (isHealer and 1 or 0)
				numDPS   = numDPS   + (isDamage and 1 or 0)
				itemLevels = (itemLevels or 0) + (avgILevel or 0)
			end

			button.level:SetFormattedText('%d', itemLevels/(partyMembers+1))
			button.tankCount:SetText(numTanks)
			button.healerCount:SetText(numHeals)
			button.damageCount:SetText(numDPS)
		end
	end
end

function plugin:OnEnable()
	hooksecurefunc('LFRBrowseFrameListButton_SetData', AddLFREntryInfo)
	local i, button = 1, _G['LFRBrowseFrameListButton1']
	while button do
		local tankCount = button:CreateFontString(nil, nil, 'GameFontHighlight')
		      tankCount:SetAllPoints(button.tankIcon)
		button.tankCount = tankCount
		local healerCount = button:CreateFontString(nil, nil, 'GameFontHighlight')
		      healerCount:SetAllPoints(button.healerIcon)
		button.healerCount = healerCount
		local damageCount = button:CreateFontString(nil, nil, 'GameFontHighlight')
		      damageCount:SetAllPoints(button.damageIcon)
		button.damageCount = damageCount

		i = i + 1
		button = _G['LFRBrowseFrameListButton'..i]
	end

	--[[ plugin:RegisterEvent('UPDATE_LFG_LIST', function()
		local sortOrder = {3, 6, 5, 4, 1} -- class, dps, heal, tank, group
		for _, index in ipairs(sortOrder) do
			_G['LFRBrowseFrameColumnHeader'..index]:Click()
		end
		plugin:UnregisterEvent('UPDATE_LFG_LIST')
	end) --]]
end
