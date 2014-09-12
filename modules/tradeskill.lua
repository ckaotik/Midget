local addonName, addon, _ = ...
local plugin = addon:NewModule('Tradeskill', 'AceEvent-3.0')
local LPT = LibStub("LibPeriodicTable-3.1", true)

-- GLOBALS: _G, Auctional, MidgetDB, GameTooltip, CURRENT_TRADESKILL, TRADE_SKILLS_DISPLAYED, Atr_ShowTipWithPricing, TradeSkillListScrollFrame, TradeSkillSkillName, TradeSkillFilterBar
-- GLOBALS: IsAddOnLoaded, CreateFrame, GetCoinTextureString, GetItemInfo, IsModifiedClick, GetSpellInfo, GetProfessionInfo, GetTradeSkill, GetTradeSkillInfo, GetTradeSkillItemLink, GetAuctionBuyout, GetTradeSkillRecipeLink, GetTradeSkillReagentInfo, GetTradeSkillReagentItemLink, FauxScrollFrame_GetOffset, DressUpItemLink
-- GLOBALS: string, pairs, type, select, hooksecurefunc, tonumber, floor

-- ================================================
--  SkillFrame adjustments
-- ================================================
local function AddTradeSkillLevels(id)
	if not MidgetDB.tradeskillLevels then return end

	local tradeskill = CURRENT_TRADESKILL
		  tradeskill = plugin.GetTradeSkill(tradeskill)
	local recipe = GetTradeSkillItemLink(id)
		  recipe = tonumber(select(3, string.find(recipe or "", "-*:(%d+)[:|].*")) or "")
	if not recipe then return end

	local setName = "TradeskillLevels"..(tradeskill and "."..tradeskill or "")
	if LPT and LPT.sets[setName] then
		for item, value, set in LPT:IterateSet(setName) do
			if item == recipe or item == -1 * recipe then
				local newText = ( GetTradeSkillInfo(id) ) .. "\n" .. plugin.GetTradeSkillColoredString(string.split("/", value))
				TradeSkillSkillName:SetText(newText)
				break
			end
		end
	end
end

local function AddTradeSkillInfoIcon(line)
	local button = CreateFrame("Button", "$parentInfoIcon", line)
	button:SetSize(12, 12)
	button:SetNormalTexture("Interface\\COMMON\\Indicator-Gray")
	button:SetPoint("TOPLEFT", 0, -2)
	button:Hide()

	button:SetScript("OnEnter", addon.ShowTooltip)
	button:SetScript("OnLeave", addon.HideTooltip)

	line.infoIcon = button
	return button
end

local function AddTradeSkillReagentCosts()
	if not MidgetDB.tradeskillCosts then return end

	local skillIndex, reagentIndex, reagent, amount, name, lineIndex, skillType
	local craftedItem, craftedValue, infoIcon, difference
	local reagentPrice, craftPrice

	local hasFilterBar = TradeSkillFilterBar:IsShown()
	local displayedSkills = hasFilterBar and (TRADE_SKILLS_DISPLAYED - 1) or TRADE_SKILLS_DISPLAYED
	local offset = FauxScrollFrame_GetOffset(TradeSkillListScrollFrame)
	for line = 1, displayedSkills do
		skillIndex = line + offset
		lineIndex = line + (hasFilterBar and 1 or 0)

		_, skillType = GetTradeSkillInfo(skillIndex)
		infoIcon = _G["TradeSkillSkill"..lineIndex.."InfoIcon"]
		if not skillType or (skillType ~= "optimal" and skillType ~= "medium" and skillType ~= "easy") then
			if infoIcon then infoIcon:Hide() end
		else
			reagentIndex, craftPrice = 1, 0
			infoIcon = infoIcon or AddTradeSkillInfoIcon(_G["TradeSkillSkill"..lineIndex])

			while GetTradeSkillReagentItemLink(skillIndex, reagentIndex) do
				_, _, amount = GetTradeSkillReagentInfo(skillIndex, reagentIndex)
				reagent = GetTradeSkillReagentItemLink(skillIndex, reagentIndex)
				reagent = addon.GetItemID(reagent)

				if reagent then
					if LPT and LPT:ItemInSet(reagent, "Tradeskill.Mat.BySource.Vendor") then
						reagentPrice = 4 * (select(11, GetItemInfo(reagent)) or 0)
					else
						reagentPrice = GetAuctionBuyout and GetAuctionBuyout(reagent) or 0 -- [TODO] what about BoP things?
					end
					reagentPrice = reagentPrice * amount
					craftPrice = craftPrice + reagentPrice
				end

				reagentIndex = reagentIndex + 1
			end

			craftedItem = GetTradeSkillItemLink(skillIndex)
			craftedValue = craftedItem and GetAuctionBuyout and GetAuctionBuyout(craftedItem) or 0

			if craftPrice > 0 and craftedValue > 0 then
				infoIcon.tiptext = COSTS_LABEL.." "..GetCoinTextureString(craftPrice) .. "\n"
					..SELL_PRICE..": "..GetCoinTextureString(craftedValue)

				difference = craftedValue - craftPrice
				if difference > 0 then
					infoIcon.tiptext = infoIcon.tiptext .. "\n"..string.format(LOOT_ROLL_YOU_WON, GetCoinTextureString(difference))
					if craftPrice > 0 and difference / craftPrice > 0.2 and difference > 500000 then
						infoIcon:SetNormalTexture("Interface\\COMMON\\Indicator-Green")
					else
						infoIcon:SetNormalTexture("Interface\\COMMON\\Indicator-Yellow")
					end
				else
					infoIcon:SetNormalTexture("Interface\\COMMON\\Indicator-Red")
				end
				infoIcon:Show()
			else
				infoIcon:Hide()
			end

			--[[ if craftPrice > 0 then
				name = _G["TradeSkillSkill"..lineIndex]:GetText()
				if name then
					_G["TradeSkillSkill"..lineIndex]:SetText(name .. " "..GetCoinTextureString(floor(craftPrice/1000)*1000))
				end
			end --]]
		end
	end
end

local function AddTradeSkillHoverLink(self)
	if not MidgetDB.tradeskillTooltips then return end

	local ID = self:GetID()
	local recipeLink = ID and GetTradeSkillRecipeLink(ID)
	local result = GetTradeSkillItemLink(ID)

	if result and recipeLink then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

		if IsEquippableItem(result) and (IsModifiedClick("COMPAREITEMS") or (GetCVarBool("alwaysCompareItems") and not GameTooltip:IsEquippedItem())) then
			GameTooltip:SetHyperlink(result)
			GameTooltip_ShowCompareItem(GameTooltip, 1)
		end
		GameTooltip:SetHyperlink(recipeLink)

		if Atr_ShowTipWithPricing then
			GameTooltip:AddLine(" ")
			Atr_ShowTipWithPricing(GameTooltip, result, 1)
		elseif IsAddOnLoaded("Auctional") then
			Auctional.ShowSimpleTooltipData(GameTooltip, result)
		end
		if IsAddOnLoaded("TopFit") and TopFit.TooltipAddCompareLines then
			TopFit.TooltipAddCompareLines(GameTooltip, result)
		end
		GameTooltip:Show()

		if not self.touched then
			self:HookScript("OnClick", function(self)
				if IsModifiedClick("DRESSUP") then
					DressUpItemLink(result)
				end
			end)
			self.touched = true
		end
	end
end

-- utility functions
local tradeSkills = {
	[2259] 	= "Alchemy",
	[2018] 	= "Blacksmithing",
	[7411] 	= "Enchanting",
	[4036] 	= "Engineering",
	[13614] = "Herbalism",		-- actually 2366 but this has the correct skill name
	[45357] = "Inscription",
	[25229] = "Jewelcrafting",
	[2108] 	= "Leatherworking",
	[2575] 	= "Mining",
	[8613] 	= "Skinning",
	[3908] 	= "Tailoring",

	[78670]	= "Archaeology",
	[2550] 	= "Cooking",
	[3273] 	= "First Aid",
	[7620] 	= "Fishing",
}
local skillColors = {
	[1] = "|cffFF8040",		-- orange
	[2] = "|cffFFFF00",		-- yellow
	[3] = "|cff40BF40",		-- green
	[4] = "|cff808080", 	-- gray
}
function plugin.GetTradeSkill(skill)
	if not skill then return end
	if type(skill) == "number" then
		skill = GetProfessionInfo(skill)
	end
	for spellID, skillName in pairs(tradeSkills) do
		if ( GetSpellInfo(spellID) ) == skill then
			return skillName
		end
	end
	return nil
end
function plugin.GetTradeSkillColoredString(orange, yellow, green, gray)
	return string.format("|cffFF8040%s|r/|cffFFFF00%s|r/|cff40BF40%s|r/|cff808080%s|r", orange or "", yellow or "", green or "", gray or "")
end

-- Wide TradeSkills
-- ------------------------------------------------------
-- functions needed to add our own search
local ItemSearch = LibStub('LibItemSearch-1.2')
local function UpdateTradeSkillSearch(self, isUserInput)
	local text = self:GetText()
	self:GetParent().search = (text ~= '' and text ~= _G.SEARCH) and text or nil
	TradeSkillFrame_Update()
end
local function UpdateTradeSkillRow(button, index, selected, isGuild)
	local skillName, skillType, numAvailable, isExpanded, serviceType, numSkillUps, indentLevel, showProgressBar, currentRank, maxRank, startingRank = GetTradeSkillInfo(index)

	local color       = TradeSkillTypeColor[skillType]
	local prefix      = _G.ENABLE_COLORBLIND_MODE == '1' and TradeSkillTypePrefix[skillType] or ' '
	local indentDelta = indentLevel > 0 and 20 or 0
	local textWidth   = _G.TRADE_SKILL_TEXT_WIDTH - indentDelta
	local usedWidth   = 0

	local skillUps, rankBar = button.skillup, button.SubSkillRankBar
	if skillType == 'header' or skillType == 'subheader' then
		-- headers / rank bar
		if showProgressBar then
			TradeSkilSubSkillRank_Set(rankBar, skillName, currentRank, startingRank, maxRank)
			textWidth = textWidth - _G.SUB_SKILL_BAR_WIDTH
			rankBar:Show()
		end
		button.text:SetWidth(textWidth)
		button.count:SetText('')
		button:SetText(skillName)
		button:SetNormalTexture('Interface\\Buttons\\' .. (isExpanded and 'UI-MinusButton-Up' or 'UI-PlusButton-Up'))
		button:GetHighlightTexture():SetTexture('Interface\\Buttons\\UI-PlusButton-Hilight')
		button:UnlockHighlight()
		button.isHighlighted = false
	else
		-- multiskill
		if numSkillUps > 1 and skillType == 'optimal' then
			usedWidth = _G.TRADE_SKILL_SKILLUP_TEXT_WIDTH
			skillUps.countText:SetText(numSkillUps)
			skillUps:Show()
		else
			skillUps:Hide()
		end

		-- guild color override
		if isGuild then color = TradeSkillTypeColor['easy'] end

		button:SetNormalTexture('')
		button:GetHighlightTexture():SetTexture('')
		button:SetText(prefix .. skillName)

		if numAvailable > 0 then
			button.count:SetText('['..numAvailable..']')
			local nameWidth, countWidth = button.text:GetStringWidth(), button.count:GetStringWidth()
			if (nameWidth + 2 + countWidth) > (textWidth - usedWidth) then
				textWidth = textWidth - 2 - countWidth - usedWidth
			else
				textWidth = 0
			end
		else
			button.count:SetText('')
			textWidth = textWidth - usedWidth
		end
		button.text:SetWidth(textWidth)

		-- Place the highlight and lock the highlight state
		if index == selected then
			TradeSkillHighlightFrame:SetPoint('TOPLEFT', button, 'TOPLEFT', 0, 0)
			TradeSkillHighlightFrame:Show()
			button:LockHighlight()
			button.isHighlighted = true

			-- Set the max makeable items for the create all button
			_G.TradeSkillFrame.numAvailable = math.abs(numAvailable)
		else
			button:UnlockHighlight()
			button.isHighlighted = false
		end
	end

	-- color
	button:SetNormalFontObject(color.font)
	button.font = color.font
	if button.isHighlighted then color = _G.HIGHLIGHT_FONT_COLOR end
	button.text:SetVertexColor(color.r, color.g, color.b)
	button.count:SetVertexColor(color.r, color.g, color.b)
	skillUps.countText:SetVertexColor(color.r, color.g, color.b)
	skillUps.icon:SetVertexColor(color.r, color.g, color.b)
	button.r, button.g, button.b = color.r, color.g, color.b

	-- indent
	button:GetNormalTexture():SetPoint('LEFT', 3 + indentDelta, 0)
	button:GetDisabledTexture():SetPoint('LEFT', 3 + indentDelta, 0)
	button:GetHighlightTexture():SetPoint('LEFT', 3 + indentDelta, 0)

	return skillType == 'header' or skillType == 'subheader', isExpanded
end
-- FIXME: allow to keep headers intact
local function UpdateTradeSkillList()
	local searchText = _G.TradeSkillFrame.search
	if not searchText or searchText == _G.SEARCH then return end

	local offset    = FauxScrollFrame_GetOffset(_G.TradeSkillListScrollFrame)
	local isGuild   = IsTradeSkillGuild()
	local selected  = GetTradeSkillSelectionIndex()
	local numHeaders, notExpanded = 0, 0

	local buttonIndex, numItems = _G.TradeSkillFilterBar:IsShown() and 2 or 1, 0
	-- for i = buttonIndex, _G.TRADE_SKILLS_DISPLAYED do
	for i = 1, GetNumTradeSkills() do
		local index = i + offset
		local button = _G['TradeSkillSkill'..buttonIndex]
		if not button then break end

		local skillName, skillType, numAvailable, isExpanded, serviceType, numSkillUps, indentLevel, showProgressBar, currentRank, maxRank, startingRank = GetTradeSkillInfo(index)

		local matchesSearch = false -- local link = GetTradeSkillRecipeLink(index)
		if skillName and skillType ~= 'header' and skillType ~= 'subheader' then
			matchesSearch = ItemSearch:Matches(GetTradeSkillItemLink(index), searchText)
			local reagentIndex = 0
			while not matchesSearch do
				reagentIndex = reagentIndex + 1
				local reagentLink = GetTradeSkillReagentItemLink(index, reagentIndex)
				if not reagentLink then break end
				matchesSearch = ItemSearch:Matches(reagentLink, searchText)
			end
		end

		if matchesSearch then
			local header, expanded = UpdateTradeSkillRow(button, index, selected, isGuild)
			numHeaders  = numHeaders + (header and 1 or 0)
			notExpanded = notExpanded + (expanded and 0 or 1)

			button:SetID(index)
			button:Show()
			buttonIndex = buttonIndex + 1
			numItems = numItems + 1
		else
			button:Hide()
			button:UnlockHighlight()
			button.isHighlighted = false
		end
	end
	FauxScrollFrame_Update(_G.TradeSkillListScrollFrame, numItems, _G.TRADE_SKILLS_DISPLAYED, _G.TRADE_SKILL_HEIGHT, nil, nil, nil, _G.TradeSkillHighlightFrame, 293, 316, true)
	local button = _G['TradeSkillSkill'..buttonIndex]
	while button do
		button:Hide()
		button:UnlockHighlight()
		button.isHighlighted = false
		buttonIndex = buttonIndex + 1
		button = _G['TradeSkillSkill'..buttonIndex]
	end

	-- Set the expand/collapse all button texture
	local collapseAll = _G.TradeSkillCollapseAllButton
	if notExpanded ~= numHeaders then
		collapseAll.collapsed = nil
		collapseAll:SetNormalTexture('Interface\\Buttons\\UI-MinusButton-Up')
	else
		collapseAll.collapsed = 1
		collapseAll:SetNormalTexture('Interface\\Buttons\\UI-PlusButton-Up')
	end
end

local function UpdateScrollFrameWidth(self)
	local scrollFrame = self:GetParent()
	local skillName, _, reqText, _, headerLeft, _, description, _ = scrollFrame:GetScrollChild():GetRegions()
	if self:IsShown() then
		scrollFrame:SetPoint('BOTTOMRIGHT', -32, 28)
		headerLeft:SetTexCoord(0, 0.5, 0, 1)
	else
		scrollFrame:SetPoint('BOTTOMRIGHT', -5, 28)
		headerLeft:SetTexCoord(0, 0.6, 0, 1)
	end
	local newWidth = scrollFrame:GetWidth()
	scrollFrame:GetScrollChild():SetWidth(newWidth)
	scrollFrame:UpdateScrollChildRect()

	-- text don't stretch properly without fixed width
	description:SetWidth(newWidth - 5)
	  skillName:SetWidth(newWidth - 50)
	    reqText:SetWidth(newWidth - 5)
end

local function OnTradeSkillFrame_SetSelection(index)
	local scrollFrame = _G.TradeSkillDetailScrollFrame
	      scrollFrame:SetVerticalScroll(0)
	local skillName, reqLabel, reqText, cooldown, headerLeft, headerRight, description, reagentLabel = scrollFrame:GetScrollChild():GetRegions()

	if description:GetText() == ' ' then description:SetText(nil) end
	if not cooldown:GetText() then cooldown:SetHeight(-10) end

	-- add a section for required items
	reqLabel:SetTextColor(reagentLabel:GetTextColor())
	reqLabel:SetShadowColor(reagentLabel:GetShadowColor())
	cooldown:SetPoint('TOPLEFT', description, 'BOTTOMLEFT', 0, -10)
	reqLabel:SetPoint('TOPLEFT', cooldown, 'BOTTOMLEFT', 0, -10)
	reqText:SetPoint('TOPLEFT', reqLabel, 'BOTTOMLEFT', 0, 0)
	reagentLabel:SetPoint('TOPLEFT', reqText, 'BOTTOMLEFT', 0, -10)
end

local function InitializeTradeSkillFrame()
	local frame = _G.TradeSkillFrame
	      frame:SetSize(540, 468)

	-- recipe list area
	local list = _G.TradeSkillListScrollFrame
	      list:ClearAllPoints()
	      list:SetPoint('TOPLEFT', 0, -83)
	      list:SetPoint('BOTTOMRIGHT', '$parent', 'BOTTOMLEFT', 300, 28)

	-- create additional rows since scroll frame area grew
	local numRows = math.floor((frame:GetHeight() - 83 - 28) / _G.TRADE_SKILL_HEIGHT)
	for index = TRADE_SKILLS_DISPLAYED+1, numRows do
		local row = CreateFrame('Button', 'TradeSkillSkill'..index, frame, 'TradeSkillSkillButtonTemplate')
		      row:SetPoint('TOPLEFT', _G['TradeSkillSkill'..(index-1)], 'BOTTOMLEFT')
		      row.skillup:Hide()
		      row.SubSkillRankBar:Hide()
		      row:SetNormalTexture('')
		_G['TradeSkillSkill'..index..'Highlight']:SetTexture('')
	end
	_G.TRADE_SKILLS_DISPLAYED = numRows

	-- detail/reagent panel
	local details = _G.TradeSkillDetailScrollFrame
	      details:ClearAllPoints()
	      details:SetPoint('TOPLEFT', list, 'TOPRIGHT', 28, 0)
	      details:SetPoint('BOTTOMRIGHT', -5, 28)
	details.ScrollBar:HookScript('OnShow', UpdateScrollFrameWidth)
	details.ScrollBar:HookScript('OnHide', UpdateScrollFrameWidth)

	-- hide top-bottom separator
	local sepLeft, sepRight = select(21, frame:GetRegions())
	sepLeft:Hide(); sepRight:Hide()

	-- move bottom action buttons
	_G.TradeSkillCreateAllButton:SetPoint('BOTTOMLEFT', 'TradeSkillCreateButton', 'BOTTOMLEFT', -167, 0)

	-- stretching the scroll bars
	for _, scrollFrame in pairs({list, details}) do
		local topScrollBar, bottomScrollBar = scrollFrame:GetRegions()
		local middleScrollBar = scrollFrame:CreateTexture(scrollFrame:GetName()..'Middle', 'BACKGROUND')
		      middleScrollBar:SetTexture('Interface\\PaperDollInfoFrame\\UI-Character-ScrollBar')
		      middleScrollBar:SetTexCoord(0, 0.46875, 0.03125, 0.9609375)
		      middleScrollBar:SetPoint('TOPLEFT', topScrollBar, 'TOPLEFT', 1, 0)
		      middleScrollBar:SetPoint('BOTTOMRIGHT', bottomScrollBar, 'TOPRIGHT', 0, 0)
	end

	-- sidebar/craft details changes
	local background = details:CreateTexture(nil, 'BACKGROUND')
	      background:SetTexture('Interface\\ACHIEVEMENTFRAME\\UI-ACHIEVEMENT-PARCHMENT')
	      background:SetTexCoord(0.5, 1, 0, 1)
	      background:SetAllPoints()


	local skillName, reqLabel, reqText, cooldown, headerLeft, headerRight, description, reagentLabel = details:GetScrollChild():GetRegions()
	headerRight:ClearAllPoints()
	headerRight:SetPoint('TOPRIGHT', 20-5, 3-5)
	headerLeft:SetPoint('BOTTOMRIGHT', headerRight, 'BOTTOMLEFT')
	headerLeft:SetTexCoord(0, 0.6, 0, 1)
	for _, region in pairs({headerLeft, _G.TradeSkillSkillIcon, skillName}) do
		local point, relativeTo, relativePoint, xOffset, yOffset = region:GetPoint()
		region:SetPoint(point, relativeTo, relativePoint, xOffset + 2, yOffset - 5)
	end

	local sideBarWidth = details:GetWidth()
	skillName:SetNonSpaceWrap(true)
	skillName:SetWidth(sideBarWidth - 50)
	description:SetNonSpaceWrap(true)
	description:SetWidth(sideBarWidth - 5)
	description:SetPoint('TOPLEFT', 5, -55)
	reqText:SetWidth(sideBarWidth - 5)

	-- move reagents below one another and widen buttons
	for index = 1, _G.MAX_TRADE_SKILL_REAGENTS do
		local button = _G['TradeSkillReagent'..index]
		local nameFrame = _G['TradeSkillReagent'..index..'NameFrame']
		      nameFrame:SetPoint('RIGHT', 3, 0)
		local itemName = button.name
		      itemName:SetPoint('LEFT', '$parentNameFrame', 'LEFT', 20, 0)
		      itemName:SetPoint('RIGHT', '$parentNameFrame', 'RIGHT', -5, 0)
		if index ~= 1 then
			button:ClearAllPoints()
			button:SetPoint('TOPLEFT', _G['TradeSkillReagent'..(index-1)], 'BOTTOMLEFT', 0, -2)
		end
		local _, _, _, _, yOffset = button:GetPoint()
		button:SetPoint('TOPRIGHT', 0+5, yOffset)
	end

	-- more powerful search engine using LibItemSearch
	local searchBox = _G.TradeSkillFrameSearchBox
	      searchBox.searchIcon = _G.TradeSkillFrameSearchBoxSearchIcon
	      searchBox:SetScript('OnTextChanged', UpdateTradeSkillSearch)
	      searchBox:SetScript('OnEditFocusLost',   _G.SearchBoxTemplate_OnEditFocusLost)
	      searchBox:SetScript('OnEditFocusGained', _G.SerachBoxTemplate_OnEditFocusGained)
	--      searchBox:SetScript('OnEnter', addon.ShowTooltip)
	--      searchBox:SetScript('OnLeave', addon.HideTooltip)
	--      searchBox.tiptext = 'Search in recipe, item or reagent names or in item descriptions.\nitem level ± 2: "~123"\nitem level range: "123 - 456"'

	-- add missing clear search button
	local clearButton = CreateFrame('Button', '$parentClearButton', searchBox)
	      clearButton:SetSize(17, 17)
	      clearButton:SetPoint('RIGHT', -3, 0)
	      clearButton:Hide()
	clearButton:SetScript('OnEnter', function(self) self.texture:SetAlpha(1) end)
	clearButton:SetScript('OnLeave', function(self) self.texture:SetAlpha(0.5) end)
	clearButton:SetScript('OnClick', function(self, btn, up)
		PlaySound('igMainMenuOptionCheckBoxOn')
		local editBox = self:GetParent()
		      editBox:SetText('')
		      editBox:ClearFocus()
		if editBox.clearFunc then editBox.clearFunc(editBox) end
		if not editBox:HasFocus() then editBox:GetScript('OnEditFocusLost')(editBox) end
	end)
	local clearIcon = clearButton:CreateTexture(nil, 'OVERLAY')
	      clearIcon:SetTexture('Interface\\FriendsFrame\\ClearBroadcastIcon')
	      clearIcon:SetAllPoints()
	      clearIcon:SetAlpha(0.5)
	clearButton.texture = clearIcon
	searchBox.clearButton = clearButton

	-- add quick filters
	local hasMaterials = CreateFrame('CheckButton', '$parentHasMaterials', frame, 'UICheckButtonTemplate')
	      hasMaterials:SetPoint('LEFT', 'TradeSkillLinkButton', 'RIGHT', 10, 0)
	      hasMaterials:SetSize(24, 24)
	local hasMatLabel = hasMaterials:CreateFontString(nil, nil, 'GameFontNormal')
	      hasMatLabel:SetPoint('LEFT', hasMaterials, 'RIGHT', 2, 0)
	      hasMatLabel:SetText(_G.CRAFT_IS_MAKEABLE)
	      hasMaterials:SetHitRectInsets(-5, -10 - hasMatLabel:GetStringWidth(), -2, -2)
	hooksecurefunc('TradeSkillOnlyShowMakeable', function(enable) hasMaterials:SetChecked(enable) end)
	hasMaterials:SetScript('OnClick', function(self, btn, up)
		local enable = self:GetChecked()
		TradeSkillFrame.filterTbl.hasMaterials = enable
		TradeSkillOnlyShowMakeable(enable)
		TradeSkillUpdateFilterBar()
	end)
	local hasSkillUp = CreateFrame('CheckButton', '$parentHasSkillUp', frame, 'UICheckButtonTemplate')
	      hasSkillUp:SetPoint('TOPLEFT', '$parentHasMaterials', 'BOTTOMLEFT', 0, -2)
	      hasSkillUp:SetSize(24, 24)
	local hasSkillLabel = hasSkillUp:CreateFontString(nil, nil, 'GameFontNormal')
	      hasSkillLabel:SetPoint('LEFT', hasSkillUp, 'RIGHT', 2, 0)
	      hasSkillLabel:SetText(_G.TRADESKILL_FILTER_HAS_SKILL_UP)
	      hasSkillUp:SetHitRectInsets(-5, -10 - hasSkillLabel:GetStringWidth(), -2, -2)
	hooksecurefunc('TradeSkillOnlyShowSkillUps', function(enable) hasSkillUp:SetChecked(enable) end)
	hasSkillUp:SetScript('OnClick', function(self, btn, up)
		local enable = self:GetChecked()
		TradeSkillFrame.filterTbl.hasSkillUp  = enable
		TradeSkillOnlyShowSkillUps(enable)
		TradeSkillUpdateFilterBar()
	end)
	frame.hasMaterials, frame.hasSkillUp = hasMaterials, hasSkillUp
	hooksecurefunc('TradeSkillUpdateFilterBar', function(subName, slotName, ignore)
		if ignore then return end
		-- don't list "hasMaterials" or "hasSkillUp" in the filter bar
		local hasMaterials, hasSkillUp = TradeSkillFrame.filterTbl.hasMaterials, TradeSkillFrame.filterTbl.hasSkillUp
		TradeSkillFrame.filterTbl.hasMaterials = false
		TradeSkillFrame.filterTbl.hasSkillUp   = false
		TradeSkillUpdateFilterBar(subName, slotName, true)
		TradeSkillFrame.filterTbl.hasMaterials = hasMaterials
		TradeSkillFrame.filterTbl.hasSkillUp   = hasSkillUp
	end)
end

function plugin:TRADE_SKILL_SHOW()
	InitializeTradeSkillFrame()
	hooksecurefunc('TradeSkillFrame_Update', UpdateTradeSkillList)
	hooksecurefunc('TradeSkillFrame_SetSelection', OnTradeSkillFrame_SetSelection)
	self:UnregisterEvent('TRADE_SKILL_SHOW')
end

-- ------------------------------------------------------
-- Experimental Stuff
-- ------------------------------------------------------
local tradeSkillFilters = {}
local function SaveFilters()
	local displayedTradeskill = CURRENT_TRADESKILL
	local filters = tradeSkillFilters[displayedTradeskill]
	if not tradeSkillFilters[displayedTradeskill] then
		tradeSkillFilters[displayedTradeskill] = {}
		filters = tradeSkillFilters[displayedTradeskill]
	else
		wipe(filters)
	end

	filters.selected 	 = GetTradeSkillSelectionIndex()
	filters.name 		 = GetTradeSkillItemNameFilter()
	filters.levelMin,
	filters.levelMax 	 = GetTradeSkillItemLevelFilter()
	filters.hasMaterials = TradeSkillFrame.filterTbl.hasMaterials
	filters.hasSkillUp 	 = TradeSkillFrame.filterTbl.hasSkillUp

	if not GetTradeSkillInvSlotFilter(0) then
		if not filters.slots then filters.slots = {} end
		for i = 1, select('#', GetTradeSkillInvSlots()) do
			filters.slots[i] = GetTradeSkillInvSlotFilter(i)
		end
	end

	if not GetTradeSkillCategoryFilter(0) then
		if not filters.subClasses then filters.subClasses = {} end
		for i = 1, select('#', GetTradeSkillSubClasses()) do
			filters.subClasses[i] = GetTradeSkillCategoryFilter(i)
		end
	end
end

local function RestoreFilters()
	local displayedTradeskill = CURRENT_TRADESKILL
	local filters = tradeSkillFilters[displayedTradeskill]
	if not displayedTradeskill or not filters then return end

	SetTradeSkillItemNameFilter(filters.name)
	SetTradeSkillItemLevelFilter(filters.levelMin or 0, filters.levelMax or 0)
	TradeSkillOnlyShowMakeable(filters.hasMaterials)
	TradeSkillOnlyShowSkillUps(filters.hasSkillUp)

	if filters.slots and #filters.slots > 0 then
		SetTradeSkillInvSlotFilter(0, 1, 1)
		for index, enabled in pairs(filters.slots) do
			SetTradeSkillInvSlotFilter(index, enabled)
		end
	end
	if filters.subClasses and #filters.subClasses > 0 then
		SetTradeSkillCategoryFilter(0, 1, 1)
		for index, enabled in pairs(filters.subClasses) do
			SetTradeSkillCategoryFilter(index, enabled)
		end
	end

	TradeSkillUpdateFilterBar()
	SelectTradeSkill(filters.selected)
	-- TradeSkillFrame_Update()
end

local function RemoveActiveFilters()
	ExpandTradeSkillSubClass(0) -- TODO: isn't currently saved/restored
	SetTradeSkillItemLevelFilter(0, 0)
    SetTradeSkillItemNameFilter(nil)
    TradeSkillSetFilter(-1, -1)
    -- TradeSkillFrame_Update()
end

local function ScanTradeSkill()
	-- TODO: maybe even allow reagent crafting for linked skills, assuming we have the skill, too
	if IsTradeSkillLinked() then return end

	SaveFilters()
	RemoveActiveFilters()
	for index = 1, GetNumTradeSkills() do
		local skillName, skillType = GetTradeSkillInfo(index)
		if skillName and not skillType:find('header') then
			local minYield, maxYield = GetTradeSkillNumMade(index)
			local crafted = GetTradeSkillItemLink(index)
			local craftedID = crafted:match('enchant:(%d+)')
				  craftedID = craftedID and -1*craftedID or 1*crafted:match('item:(%d+)')
			local craftSpellID = GetTradeSkillRecipeLink(index)
				  craftSpellID = 1*craftSpellID:match('enchant:(%d+)')

			if not MidgetDB.craftables[craftedID] then MidgetDB.craftables[craftedID] = {} end
			local craftedTable = MidgetDB.craftables[craftedID]
			if not craftedTable[craftSpellID] then
				craftedTable[craftSpellID] = {}
			else
				wipe(craftedTable[craftSpellID])
			end
			local dataTable = craftedTable[craftSpellID]

			dataTable[1], dataTable[2] = minYield, maxYield
			for i = 1, GetTradeSkillNumReagents(index) do
				local _, _, reagentCount = GetTradeSkillReagentInfo(index, i)
				local reagentID = GetTradeSkillReagentItemLink(index, i)
					  reagentID = reagentID and 1*reagentID:match('item:(%d+)')
				if reagentID and reagentCount > 0 then
					tinsert(dataTable, reagentID)
					tinsert(dataTable, reagentCount)
				end
			end
			-- print('new entry', skillName, unpack(MidgetDB.craftables[craftedID][craftSpellID]))
		end
	end
	RestoreFilters()
end

function plugin.ScanTradeSkills()
	-- Archaeology / Fishing have no recipes
	for _, buttonName in ipairs({ 'PrimaryProfession1SpellButtonBottom', 'PrimaryProfession2SpellButtonBottom',
						'SecondaryProfession3SpellButtonRight', 'SecondaryProfession4SpellButtonRight' }) do
		local button = _G[buttonName]
		local profession = button:GetParent()
		-- herbalism / skinning have no recipes
		if profession.skillLine and profession.skillLine ~= 182 and profession.skillLine ~= 393 then
			SpellButton_OnClick(button, 'LeftButton')
			-- addon:Print('Scanning profession %s', profession.skillName)
			ScanTradeSkill()
			CloseTradeSkill()
		end
	end
end

-- http://www.wowpedia.org/TradeSkillLink string.byte, bit
function plugin.IsTradeSkillKnown(craftSpellID)
	-- local professionLink = GetTradeSkillListLink()
	-- if not professionLink then return end
	-- local unitGUID, tradeSpellID, currentRank, maxRank, recipeList = professionLink:match("\124Htrade:([^:]+):([^:]+):([^:]+):([^:]+):([^:\124]+)")

	return IsUsableSpell(craftSpellID)
end

local function ScanForReagents(index)
	for i = 1, GetTradeSkillNumReagents(index) do
		local _, _, reagentCount, playerReagentCount = GetTradeSkillReagentInfo(index, i)
		local link = GetTradeSkillReagentItemLink(index, i)

		local linkType, id = link and link:match("\124H([^:]+):([^:]+)")
					    id = id and tonumber(id, 10)
		if id and MidgetDB.craftables[id] and playerReagentCount < reagentCount then
			for spellID, data in pairs(MidgetDB.craftables[id]) do
				local spellLink, tradeLink = GetSpellLink(spellID)
				if plugin.IsTradeSkillKnown(spellID) then
					-- print('could create', link, spellLink, tradeLink)
				else
					-- print(link, 'is craftable via', spellLink, tradeLink, "but you don't know/don't have materials")
				end
			end
		end
	end
end

-- IsUsableSpell(craftSpellID) as far as reagents are available
-- /cast <profession name>
-- /run for i=1,GetNumTradeSkills() do if GetTradeSkillInfo(i)==<crafted item> then DoTradeSkill(i, <num>); CloseTradeSkill(); break end end

local commonCraftables = {
	-- [craftedItemID] = { [craftSpellID] = {minYield, maxYield, reagent1, required1[, reagent2, required2[, ...] ] } }

	-- Lesser to Greater Essence
	[10939] = { [13361] = {1, 1, 10938, 3} }, -- Magic
	[11082] = { [13497] = {1, 1, 10998, 3} }, -- Astral
	[11135] = { [13632] = {1, 1, 11134, 3} }, -- Mystic
	[11175] = { [13739] = {1, 1, 11174, 3} }, -- Nether
	[16203] = { [20039] = {1, 1, 16202, 3} }, -- Eternal
	[22446] = { [32977] = {1, 1, 22447, 3} }, -- Planar
	[34055] = { [44123] = {1, 1, 34056, 3} }, -- Cosmic
	[52719] = { [74186] = {1, 1, 52718, 3} }, -- Celestial

	-- Greater to Lesser Essence
	[10938] = { [13362] = {3, 3, 10939, 1} }, -- Magic
	[10998] = { [13498] = {3, 3, 11082, 1} }, -- Astral
	[11134] = { [13633] = {3, 3, 11135, 1} }, -- Mystic
	[11174] = { [13740] = {3, 3, 11175, 1} }, -- Nether
	[16202] = { [20040] = {3, 3, 16203, 1} }, -- Eternal
	[22447] = { [32978] = {3, 3, 22446, 1} }, -- Planar
	[34056] = { [44122] = {3, 3, 34055, 1} }, -- Cosmic
	[52718] = { [74187] = {3, 3, 52719, 1} }, -- Celestial

	[52721] = { [74188] = {1, 1, 52720, 3} }, -- Heavenly Shard
	[34052] = { [61755] = {1, 1, 34053, 3} }, -- Dream Shard

	[33568] = { [59926] = {1, 1, 33567, 5} }, -- Borean Leather
	[52976] = { [74493] = {1, 1, 52977, 5} }, -- Savage Leather

	-- Motes to Primal Elementals
	[22451] = { [28100] = {1, 1, 22572, 10} }, -- Air
	[22452] = { [28101] = {1, 1, 22573, 10} }, -- Earth
	[21884] = { [28102] = {1, 1, 22574, 10} }, -- Fire
	[21886] = { [28106] = {1, 1, 22575, 10} }, -- Life
	[22457] = { [28105] = {1, 1, 22576, 10} }, -- Mana
	[22456] = { [28104] = {1, 1, 22577, 10} }, -- Shadow
	[21885] = { [28103] = {1, 1, 22578, 10} }, -- Water

	-- Crystallized to Eternal Elementals
	[35623] = { [49234] = {1, 1, 37700, 10} }, -- Air
	[35624] = { [49248] = {1, 1, 37701, 10} }, -- Earth
	[36860] = { [49244] = {1, 1, 37702, 10} }, -- Fire
	[35625] = { [49247] = {1, 1, 37704, 10} }, -- Life
	[35627] = { [49246] = {1, 1, 37703, 10} }, -- Shadow
	[35622] = { [49245] = {1, 1, 37705, 10} }, -- Water

	-- Eternal to Crystallized Elementals
	[37700] = { [56045] = {10, 10, 35623, 1} }, -- Air
	[37701] = { [56041] = {10, 10, 35624, 1} }, -- Earth
	[37702] = { [56042] = {10, 10, 36860, 1} }, -- Fire
	[37704] = { [56043] = {10, 10, 35625, 1} }, -- Life
	[37703] = { [56044] = {10, 10, 35627, 1} }, -- Shadow
	[37705] = { [56040] = {10, 10, 35622, 1} }, -- Water

	[76061] = { [129352] = {1, 1, 89112, 10} }, -- Spirit of Harmony
	[76734] = { [131776] = {1, 1, 90407, 10} }, -- Serpent's Eye
}

function plugin:OnEnable()
	hooksecurefunc("TradeSkillFrame_Update", AddTradeSkillReagentCosts)
	hooksecurefunc("TradeSkillFrame_SetSelection", AddTradeSkillLevels)
	hooksecurefunc("TradeSkillFrameButton_OnEnter", AddTradeSkillHoverLink)
	hooksecurefunc("TradeSkillFrameButton_OnLeave", addon.HideTooltip)
	self:RegisterEvent('TRADE_SKILL_SHOW')

	hooksecurefunc("TradeSkillFrame_SetSelection", ScanForReagents)

	if not MidgetDB.craftables then MidgetDB.craftables = {} end
	for crafted, crafts in pairs(commonCraftables) do
		if not MidgetDB.craftables[crafted] then
			MidgetDB.craftables[crafted] = {}
		end
		for craftSpell, data in pairs(crafts) do
			MidgetDB.craftables[crafted][craftSpell] = data
		end
	end

	if MidgetDB.autoScanProfessions then
		-- load spellbook or we'll fail
		ToggleSpellBook(BOOKTYPE_PROFESSION)
		ToggleSpellBook(BOOKTYPE_PROFESSION)

		local fullscreenTrigger = CreateFrame('Button', nil, nil, 'SecureActionButtonTemplate')
		fullscreenTrigger:RegisterForClicks('AnyUp')
		fullscreenTrigger:SetAllPoints()
		fullscreenTrigger:SetAttribute('type', 'scanTradeSkills')
		fullscreenTrigger:SetAttribute('_scanTradeSkills', function()
			plugin.ScanTradeSkills()
			UnregisterStateDriver(fullscreenTrigger, 'visibility')
			fullscreenTrigger:Hide()
		end)
		RegisterStateDriver(fullscreenTrigger, 'visibility', '[combat] hide; show')
	else
		hooksecurefunc('TradeSkillFrame_Show', ScanTradeSkill)
	end
end
