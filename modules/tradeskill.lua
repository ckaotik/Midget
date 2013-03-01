local _, ns = ...
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
		  tradeskill = ns.GetTradeSkill(tradeskill)
	local recipe = GetTradeSkillItemLink(id)
		  recipe = tonumber(select(3, string.find(recipe or "", "-*:(%d+)[:|].*")) or "")
	if not recipe then return end

	local setName = "TradeskillLevels"..(tradeskill and "."..tradeskill or "")
	if LPT and LPT.sets[setName] then
		for item, value, set in LPT:IterateSet(setName) do
			if item == recipe or item == -1 * recipe then
				local newText = ( GetTradeSkillInfo(id) ) .. "\n" .. ns.GetTradeSkillColoredString(string.split("/", value))
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

	button:SetScript("OnEnter", ns.ShowTooltip)
	button:SetScript("OnLeave", ns.HideTooltip)

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
				reagent = ns.GetItemID(reagent)

				if reagent then
					if LPT and LPT:ItemInSet(reagent, "Tradeskill.Mat.BySource.Vendor") then
						reagentPrice = 4 * (select(11, GetItemInfo(reagent)) or 0)
					else
						reagentPrice = GetAuctionBuyout(reagent) or 0 -- [TODO] what about BoP things?
					end
					reagentPrice = reagentPrice * amount
					craftPrice = craftPrice + reagentPrice
				end

				reagentIndex = reagentIndex + 1
			end

			craftedItem = GetTradeSkillItemLink(skillIndex)
			craftedValue = craftedItem and GetAuctionBuyout(craftedItem) or 0

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
	if recipeLink then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetHyperlink(recipeLink)

		local result = GetTradeSkillItemLink(ID)
		if Atr_ShowTipWithPricing then
			GameTooltip:AddLine(" ")
			Atr_ShowTipWithPricing(GameTooltip, result, 1)
		elseif IsAddOnLoaded("Auctional") then
			Auctional.ShowSimpleTooltipData(GameTooltip, result)
		end

		GameTooltip:Show()

		if MidgetDB.tradeskillCraftedTooltip then
			local resultToolTip = _G["MidgetTradeSkillResultTooltip"]
			if not resultToolTip then
				resultToolTip = CreateFrame("GameTooltip", "MidgetTradeSkillResultTooltip", GameTooltip, "ShoppingTooltipTemplate")
			end
			resultToolTip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
			resultToolTip:SetHyperlink(GetTradeSkillItemLink(ID))
			resultToolTip:Show()
		end

		if not self.touched then
			self:HookScript("OnClick", function(self)
				if IsModifiedClick("DRESSUP") then
					DressUpItemLink(GetTradeSkillItemLink(ID))
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
function ns.GetTradeSkill(skill)
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
function ns.GetTradeSkillColoredString(orange, yellow, green, gray)
	return string.format("|cffFF8040%s|r/|cffFFFF00%s|r/|cff40BF40%s|r/|cff808080%s|r", orange or "", yellow or "", green or "", gray or "")
end

-- events
ns.RegisterEvent("TRADE_SKILL_SHOW", function()
	hooksecurefunc("TradeSkillFrame_Update", AddTradeSkillReagentCosts)
	hooksecurefunc("TradeSkillFrame_SetSelection", AddTradeSkillLevels)
	hooksecurefunc("TradeSkillFrameButton_OnEnter", AddTradeSkillHoverLink)
	hooksecurefunc("TradeSkillFrameButton_OnLeave", ns.HideTooltip)

	AddTradeSkillReagentCosts()
	ns.UnregisterEvent("TRADE_SKILL_SHOW", "tradeskill")
end, "tradeskill")
