local addonName, ns, _ = ...

-- GLOBALS: _G, hooksecurefunc
-- GLOBALS: SearchLFGGetResults, SearchLFGGetPartyResults

-- ================================================
-- Add further info to lfg tooltips
-- ================================================
local function AddLFREntryInfo(button, index)
	local name, level, areaName, className, comment, partyMembers, status, class, encountersTotal, encountersComplete, isIneligible, isLeader, isTank, isHealer, isDamage, bossKills, specID, isGroupLeader, armor, spellDamage, plusHealing, CritMelee, CritRanged, critSpell, mp5, mp5Combat, attackPower, agility, maxHealth, maxMana, gearRating, avgILevel, defenseRating, dodgeRating, BlockRating, ParryRating, HasteRating, expertise = SearchLFGGetResults(index)

	if button.type == 'individual' then
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

ns.RegisterEvent('ADDON_LOADED', function(self, event, arg1)
	if arg1 ~= addonName then return end

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

	ns.UnregisterEvent('ADDON_LOADED', 'init_groupfinder')
end, 'init_groupfinder')
