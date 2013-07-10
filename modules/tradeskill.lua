local addonName, ns, _ = ...
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

	filters.name = GetTradeSkillItemNameFilter()
	filters.levelMin, filters.levelMax = GetTradeSkillItemLevelFilter()
	filters.hasMaterials = TradeSkillFrame.filterTbl.hasMaterials
	filters.hasSkillUp = TradeSkillFrame.filterTbl.hasSkillUp

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

function ns.ScanTradeSkills()
	-- Archaeology / Fishing have no recipes
	for _, buttonName in ipairs({ 'PrimaryProfession1SpellButtonBottom', 'PrimaryProfession2SpellButtonBottom',
						'SecondaryProfession3SpellButtonRight', 'SecondaryProfession4SpellButtonRight' }) do
		local button = _G[buttonName]
		local profession = button:GetParent()
		-- herbalism / skinning have no recipes
		if profession.skillLine and profession.skillLine ~= 182 and profession.skillLine ~= 393 then
			SpellButton_OnClick(button, 'LeftButton')
			--[[ while not TradeSkillFrame:IsVisible() or CURRENT_TRADESKILL ~= profession.skillName do
				print('waiting for', profession.skillName, CURRENT_TRADESKILL)
				coroutine.yield()
			end --]]
			ns.Print('Scanning profession %s', profession.skillName)
			ScanTradeSkill()
			CloseTradeSkill()
		end
	end
end

-- IsUsableSpell(craftSpellID)
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
}

-- events
local scanRoutine
ns.RegisterEvent("TRADE_SKILL_SHOW", function()
	if scanRoutine and coroutine.status(scanRoutine) ~= 'dead' then
		coroutine.resume(scanRoutine)
	else
		scanRoutine = nil
		ns.UnregisterEvent("TRADE_SKILL_SHOW", "tradeskill_update")
	end
end, "tradeskill_update")

ns.RegisterEvent('ADDON_LOADED', function(self, event, arg1)
	if arg1 == addonName then
		hooksecurefunc("TradeSkillFrame_Update", AddTradeSkillReagentCosts)
		hooksecurefunc("TradeSkillFrame_SetSelection", AddTradeSkillLevels)
		hooksecurefunc("TradeSkillFrameButton_OnEnter", AddTradeSkillHoverLink)
		hooksecurefunc("TradeSkillFrameButton_OnLeave", ns.HideTooltip)

		-- TODO: compare to Cork's list of combinables
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
				ns.ScanTradeSkills()
				fullscreenTrigger:Hide()
			end)
		else
			hooksecurefunc('TradeSkillFrame_Show', ScanTradeSkill)
		end

		ns.UnregisterEvent('ADDON_LOADED', 'trandeskill_init')
	end
end, 'trandeskill_init')
