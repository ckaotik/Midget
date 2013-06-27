local _, ns = ...

-- TODOs:
-- change Blizzard's "Collected (1/3)" to highest rarity color
-- show collected info on items that learn pets
-- show 'better pet!' indicator in battle
-- track pet locations on map

--[[
local function GetBattlePetOwnedStatus(speciesID) -- , level, quality)
	if not speciesID then return end

	local maxLevel, maxLevelRarity
	local maxRarity, maxRarityLevel
	for index = 1, C_PetJournal.GetNumPets() do
		local petID, petSpecies, owned, _, level = C_PetJournal.GetPetInfoByIndex(index)

		if owned and petSpecies == speciesID then
			local _, _, _, _, rarity = C_PetJournal.GetPetStats(petID)
			rarity = rarity - 1

			if not maxRarity or rarity > maxRarity then
				maxRarity = rarity
				maxRarityLevel = level
			end
			if not maxLevel or level > maxLevel then
				maxLevel = level
				maxLevelRarity = rarity
			end
		end
	end

	local rarityInfo = maxRarity and string.format('%s%d|r', ITEM_QUALITY_COLORS[maxRarity].hex, maxRarityLevel)
	local levelInfo  = maxLevel and string.format('%s%d|r', ITEM_QUALITY_COLORS[maxLevelRarity].hex, maxLevel)

	local owned = C_PetJournal.GetOwnedBattlePetString(speciesID)
	if not owned then return end

	-- comparing to ITEM_PET_KNOWN
	-- local current, max 	= owned:match('%((%d+)/(%d+)%)')
	-- local collected 	= owned:gsub('%((%d+)/(%d+)%)', '')

	local newInfo = string.format('%s|r: %s', owned, rarityInfo)
	-- don't show twice if identical
	if not (maxLevel == maxRarityLevel and maxRarity == maxLevelRarity) then
		newInfo = newInfo .. ', ' .. levelInfo
	end

	return newInfo
end

local function UpdateBattlePetTooltip(speciesID, level, quality)
	local newInfo = GetBattlePetOwnedStatus(speciesID, level, quality)
	if not newInfo then return end
	if BattlePetTooltip:IsVisible() then
		BattlePetTooltip.Owned:SetText(newInfo)
	end
	if FloatingBattlePetTooltip:IsVisible() then
		FloatingBattlePetTooltip.Owned:SetText(newInfo)
	end
end

local function UpdateEnemyBattlePetUnitTooltip(self, petOwner, petIndex)
	if self.CollectedText:IsVisible() then
		local speciesID = C_PetBattles.GetPetSpeciesID(petOwner, petIndex)
		local level = C_PetBattles.GetLevel(petOwner, petIndex)
		local quality = C_PetBattles.GetBreedQuality(petOwner, petIndex)
		local newInfo = GetBattlePetOwnedStatus(speciesID, level, quality)
		if not newInfo then return end

		self.CollectedText:SetText(newInfo)
		self.CollectedText:Show()
	end
end

local function UpdateBattlePetUnitTooltip(self)
	local _, unit = self:GetUnit()

	if unit then
		if UnitIsWildBattlePet(unit) then
			local speciesID = UnitBattlePetSpeciesID(unit)
			local level = UnitLevel(unit)
			local newInfo = GetBattlePetOwnedStatus(speciesID, level, -1)
			if not newInfo then return end
			local owned = C_PetJournal.GetOwnedBattlePetString(speciesID):gsub('|c........', '')

			for line = 1, self:NumLines() do
				local lineText = _G['GameTooltipTextLeft'..line]:GetText()
				if lineText == owned then
					_G['GameTooltipTextLeft'..line]:SetText(newInfo)
				end
			end
		end
	end
end

local function initialize(frame, event, arg1)
	if arg1 == addonName then
		hooksecurefunc('BattlePetToolTip_Show', UpdateBattlePetTooltip)
		hooksecurefunc('FloatingBattlePet_Show', UpdateBattlePetTooltip)
		hooksecurefunc('PetBattleUnitTooltip_UpdateForUnit', UpdateEnemyBattlePetUnitTooltip)
		GameTooltip:HookScript('OnTooltipSetUnit', UpdateBattlePetUnitTooltip)

		ns.UnregisterEvent('ADDON_LOADED', 'battlepet')
	end
end
ns.RegisterEvent('ADDON_LOADED', initialize, 'battlepet')
--]]
