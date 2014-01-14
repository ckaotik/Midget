local addonName, ns, _ = ...

-- GLOBALS: _G, GREEN_FONT_COLOR_CODE, RED_FONT_COLOR_CODE, GRAY_FONT_COLOR_CODE
-- GLOBALS: GetAchievementInfo, GetAchievementCategory, GetCategoryInfo, GetAchievementNumCriteria, GetAchievementCriteriaInfo, UnitGUID
-- GLOBALS: bit, strsplit, string

local function AddCriteriaInfo(fontString, achievementID, criteriaIndex, alignRight)
	local _, _, selfCompleted, quantity, requiredQuantity, _, _, _, quantityString = GetAchievementCriteriaInfo(achievementID, criteriaIndex)

	local progress
	local text = '%s'
	if not selfCompleted and requiredQuantity and requiredQuantity > 1 then
		progress = quantityString:gsub(' ', '')
		text = text .. ' '..GRAY_FONT_COLOR_CODE..'(%s)|r'
	end

	local indicator = (selfCompleted and GREEN_FONT_COLOR_CODE or RED_FONT_COLOR_CODE) .. '*|r'
	if alignRight then
		text = text .. ' ' .. indicator
	else
		text = indicator .. ' ' .. text
	end
	fontString:SetFormattedText(text, fontString:GetText(), progress)

	return selfCompleted, quantity, requiredQuantity
end

local playerGUID
local function TooltipAchievementExtras(tooltip, hyperlink)
	local linkType, linkID, linkData = ns.GetLinkData(hyperlink)
	if linkType ~= 'achievement' then return end

	local tooltipName, tooltipLines = tooltip:GetName(), tooltip:NumLines()
	local _, title, _, _, month, day, year, _, _, _, _, _, wasEarnedByMe, earnedBy = GetAchievementInfo(linkID)
	local guid, completed, _, _, _, crit1, crit2, crit3, crit4 = strsplit(':', linkData)
	-- local criteriaCompleted = bit.band(crit1, 2^(criteriaIndex - 1)) > 0
	-- numCompleted = numCompleted + (criteriaCompleted and 1 or 0)

	-- category this achievement belongs to
	local categoryID = GetAchievementCategory(linkID)
	local category, parent = GetCategoryInfo(categoryID)
	local categoryString = category
	while parent > 0 do
		category, parent = GetCategoryInfo(parent)
		categoryString = categoryString .. ' - ' .. category
	end
	_G[tooltipName..'TextLeft2']:SetFormattedText('<%s>', categoryString)

	if not playerGUID then playerGUID = UnitGUID('player') end
	local isPlayer = guid == playerGUID:sub(3)
	local numCriteria, numSelfCompleted = GetAchievementNumCriteria(linkID), 0
	if not isPlayer and not earnedBy then
		-- show our own achievement progress comparison
		local lineNum, critNum = 6, 0
		while critNum < numCriteria and lineNum <= tooltipLines do
			local left, right = _G[tooltipName..'TextLeft'..lineNum], _G[tooltipName..'TextRight'..lineNum]

			local leftText = left and left:GetText()
			if leftText and leftText:trim() ~= '' then
				critNum = critNum + 1
				local selfCompleted = AddCriteriaInfo(left, linkID, critNum)
				if selfCompleted then
					numSelfCompleted = numSelfCompleted + (selfCompleted and 1 or 0)
				end
			end

			local rightText = right and right:GetText()
			if rightText and rightText:trim() ~= '' and right:IsShown()  and critNum < numCriteria then
				critNum = critNum + 1
				local selfCompleted = AddCriteriaInfo(right, linkID, critNum, true)
				if selfCompleted then
					numSelfCompleted = numSelfCompleted + (selfCompleted and 1 or 0)
				end
			end

			-- this line is full, continue with next line
			lineNum = lineNum + 1
		end
	elseif not earnedBy then
		for criteriaIndex = 1, numCriteria do
			local _, _, selfCompleted = GetAchievementCriteriaInfo(linkID, criteriaIndex)
			numSelfCompleted = (numSelfCompleted or 0) + (selfCompleted and 1 or 0)
		end
	end

	if earnedBy then
		-- we have completed this achievement
		_G[tooltipName..'TextLeft1']:SetFormattedText('%s (%s%s)',
			title, wasEarnedByMe and '' or (earnedBy..' '), string.format(_G.SHORTDATE, day, month, year))
	else -- if not isPlayer then
		-- we are still working on this achievement
		_G[tooltipName..'TextLeft1']:SetFormattedText('%s (%s/%s)',
			title, numSelfCompleted, numCriteria)
	end
end
hooksecurefunc(GameTooltip, 'SetHyperlink', TooltipAchievementExtras)
