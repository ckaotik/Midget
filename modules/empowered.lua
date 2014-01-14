local addonName, ns, _ = ...

-- GLOBALS: _G, MidgetDB, LibStub, HIGHLIGHT_FONT_COLOR_CODE, RED_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, UIParent
-- GLOBALS: GetSpellInfo, UnitAura, UnitClass, IsPlayerSpell, CreateFrame, UnitSpellHaste, UnitDebuff, GetSpellBonusDamage, UnitAttackPower, UnitAttackSpeed
-- GLOBALS: unpack, select, pairs, type, wipe
local LibMasque = LibStub('Masque', true)
local Movable = LibStub('LibMovable-1.0')

local auras = {
	[GetSpellInfo( 57934)] = 1.15, -- Tricks of the Trade + 15%
	[GetSpellInfo(102560)] = 1.25, -- Incarnation (Balance)
	[GetSpellInfo(118977)] = 1.60, -- Fearless + 60%
	[GetSpellInfo(138002)] = 1.40, -- Fluidity +40%
	[GetSpellInfo(140741)] = 2.00, -- Primal Nutriment +100% +10% per stack
	[GetSpellInfo(144364)] = 1.15, -- Power of the Titans

	[GetSpellInfo(124974)] = 1.12, -- Druid: Nature's Vigil
	[GetSpellInfo( 12042)] = 1.20, -- Mage:  Arcane Power
}

local playerClass = nil
local spellsOrder = {}

local spells = {
	-- spellID = { GetBasePowerFunc, RequiredSpec }
	DRUID = {
		[  8921] = {function(spellID) return GetSpellBonusDamage(7) end, 1}, -- Moonfire
		[ 93402] = {function(spellID) return GetSpellBonusDamage(4) end, 1}, -- Sunfire
		[ 33745] = {function(spellID) return UnitAttackPower('player') end, 3}, --
		[ 77758] = {function(spellID) return UnitAttackPower('player') end, 3}, --
	},
	WARLOCK = {
		[   172] = {function(spellID) return GetSpellBonusDamage(6) end, nil}, -- Corruption
		[   980] = {function(spellID) return GetSpellBonusDamage(6) end, nil}, -- Agony
		[ 30108] = {function(spellID) return GetSpellBonusDamage(6) end, nil}, -- Unstable Affliction
		-- [  1490] = {1, GetSpellBonusDamage, 6}, -- Curse of the Elements
		-- [ 93068] = {1, GetSpellBonusDamage, 6}, -- Poison
		-- [ 47960] = {1, GetSpellBonusDamage, 6}, -- Shadowflame
		-- [108366] = {1, GetSpellBonusDamage, 6}, -- Soulleech
		-- [108416] = {1, GetSpellBonusDamage, 6}, -- Pact of Sacrifice
		-- [ 80240] = {1, GetSpellBonusDamage, 3}, -- Havoc
		-- [117896] = {1, GetSpellBonusDamage, 3}, -- Backdraft
		-- 6229, 145075, 146043, 145164
	},
	MAGE = {
		[114923] = {function(spellID) return GetSpellBonusDamage(7) end, nil}, -- Nether Tempest
	},
}
local handlers = {
	DRUID = {
		[1] = function(spellID) -- Balance
			local celestialAlignment = GetSpellInfo(112071)
			local bonus = select(15, UnitAura('player', celestialAlignment))
			if bonus then
				return 1 + bonus/100
			end

			local lunarEclipse = GetSpellInfo(48518)
			bonus = select(15, UnitAura('player', lunarEclipse))
			if bonus then
				return (spells.DRUID[spellID][3] == 7) and (1 + bonus/100) or 1
			end
			local solarEclipse = GetSpellInfo(48517)
			bonus = select(15, UnitAura('player', solarEclipse))
			if bonus then
				return (spells.DRUID[spellID][3] == 4) and (1 + bonus/100) or 1
			end
			return 1
		end
	},
}

local function GetClassModifier(spellID)
	local modifier
	if not handlers[playerClass] then
		modifier = 1
	elseif type(handlers[playerClass]) == 'table' then
		local currentSpec = GetSpecialization()
		modifier = handlers[playerClass][currentSpec] and handlers[playerClass][currentSpec](spellID) or 1
	else
		modifier = handlers[playerClass](spellID)
	end
	return modifier or 1
end
local function GetDamageModifier(spellID)
	local dmgModifier = 1
	-- handle generic aura modifiers
	for spellName, modifier in pairs(auras) do
		local name, _, _, _, _, _, _, _, _, _, _, _, _, _, bonus, bonus2, bonus3 = UnitAura('player', spellName)
		if bonus then
			dmgModifier = dmgModifier * (1 + bonus/100)
		elseif type(modifier) == 'number' then
			dmgModifier = dmgModifier * modifier
		end
	end

	-- handle class/spec specific modifiers
	dmgModifier = dmgModifier * GetClassModifier(spellID)

	-- accomodate for haste (just basic, not checking for clipped ticks etc!)
	local haste = UnitSpellHaste('player')
	      haste = 1 + haste/100
	dmgModifier = dmgModifier * haste

	return dmgModifier
end

local state = {}
local function UpdateSpellButton(spellID, duration, expires, count)
	local frame = _G[addonName..'DoTTracker']
	local button = frame[spellID]

	local relative
	if not state[spellID] or not state[spellID].active or state[spellID].active == 0 then
		relative = 0
	else
		relative = state[spellID].calculated / state[spellID].active
	end

	if count and count > 1 then
		button.count:SetText(count)
	elseif count then
		button.count:SetText('')
	end

	local color = HIGHLIGHT_FONT_COLOR_CODE
	if     relative > 0 and relative < 1 then   color = RED_FONT_COLOR_CODE
	elseif relative > 0 and relative > 1.1 then color = GREEN_FONT_COLOR_CODE
	end
	button.power:SetFormattedText('%s%d|r', color, relative*100)

	if expires and duration then
		button.cooldown:SetCooldown(expires - duration, duration)
		if duration == 0 then
			button.power:SetText('')
		end
	end
end

local function UpdateAppliedDots(self, event, unit)
	if unit ~= 'target' then return end
	for _, spellID in ipairs(spellsOrder) do
		local spellName = GetSpellInfo(spellID)
		local _, _, _, count, _, duration, expires = UnitDebuff('target', spellName, nil, 'PLAYER')
		UpdateSpellButton(spellID, duration or 0, expires or 0, count or 1)
	end
end

local function StoreValues(self, event, caster, spellName, _, _, spellID)
	if caster ~= 'player' or not spells[playerClass][spellID] then return end
	-- TODO: store per GUID
	if not state[spellID] then state[spellID] = {} end
	state[spellID].active = state[spellID].calculated or 0

	UpdateSpellButton(spellID)
end
local function PruneStoredValues(self, event)
	-- TODO
	if true then return end
	for guid, data in pairs(state) do
		wipe(data)
		state[guid] = nil
	end
end
local function UpdateValues(self, event, unit)
	if unit and unit ~= 'player' then return end
	for _, spellID in ipairs(spellsOrder) do
		local value = spells[playerClass][spellID][1](spellID)
		      value = value * GetDamageModifier(spellID)

		if not state[spellID] then state[spellID] = {} end
		state[spellID].calculated = value

		UpdateSpellButton(spellID)
	end
end

local function Initialize(self, event, addon)
	if addon ~= addonName then return end
	_, playerClass = UnitClass('player')
	if not spells[playerClass] then
		ns.UnregisterEvent('ADDON_LOADED', 'empowered')
		return
	end

	local frame = CreateFrame('Frame', addonName..'DoTTracker', UIParent)
	      frame:SetPoint('CENTER')
	      frame:SetSize(1, 1)

	local index = 1
	for spellID, info in pairs(spells[playerClass]) do
		local spellName, _, icon = GetSpellInfo(spellID)
		local button = CreateFrame('Button', '$parentButton'..index, frame, 'CompactAuraTemplate', spellID)
		      button:SetSize(30, 30)
		      button:EnableMouse(false)
		      button:EnableMouseWheel(false)

		button.icon:SetTexture(icon)
		button.cooldown:SetCooldown(0, 1)
		-- button.cooldown:SetReverse(true)

		local power = button:CreateFontString(nil, 'OVERLAY', 'NumberFontNormalSmall')
		      power:SetPoint('TOP', '$parent', 'BOTTOM', 0, -4)
		button.power = power

		if LibMasque then
			LibMasque:Group(addonName, 'DoT Tracker'):AddButton(button, {
				Icon     = button.icon,
				Cooldown = button.cooldown,
				Count    = button.count,
				Border   = button.overlay,
			})
		end

		if index == 1 then
			button:SetPoint('TOPLEFT')
		else
			button:SetPoint('LEFT', '$parentButton'..(index - 1), 'RIGHT', 2, 0)
		end

		frame[spellID] = button
		index = index + 1
	end

	if not MidgetDB.empowered then MidgetDB.empowered = {} end
	if not MidgetDB.empowered.position then MidgetDB.empowered.position = {} end
	Movable.RegisterMovable(addonName, frame, MidgetDB.empowered.position)

	ns.RegisterEvent('UNIT_SPELLCAST_SUCCEEDED', StoreValues, 'dmg_apply')
	ns.RegisterEvent('SPELLS_CHANGED', function(self, event)
		local numButtons = 0
		local frame = _G[addonName..'DoTTracker']

		wipe(spellsOrder)
		for spellID, info in pairs(spells[playerClass]) do
			local button = frame[spellID]
			-- TODO: fix to handle multiple specs interested in single dot
			if IsPlayerSpell(spellID) and (not info[2] or GetSpecialization() == info[2]) then
				table.insert(spellsOrder, spellID)
				button:SetSize(30, 30)
				button:Show()
				numButtons = numButtons + 1
			else
				button:SetSize(0.0000001, 0.0000001)
				button:Hide()
			end
		end
		table.sort(spellsOrder)
		if numButtons == 0 then
			frame:SetSize(30, 30)
		else
			frame:SetSize(numButtons*30 + (numButtons-1)*2, 30)
		end
		UpdateValues()
	end, 'dot_visibility')
	ns.RegisterEvent('UNIT_AURA', UpdateAppliedDots, 'dot_tracker')
	ns.RegisterEvent('UNIT_SPELL_HASTE', UpdateValues, 'dot_haste')
	ns.RegisterEvent('PLAYER_DAMAGE_DONE_MODS', UpdateValues, 'dmg_mods')
	ns.RegisterEvent('PLAYER_REGEN_ENABLED', PruneStoredValues, 'dmg_mods_prune')

	--[[
	["SPELL_AURA_APPLIED"] = 1,
	["SPELL_AURA_REMOVED"] = 1,
	["SPELL_AURA_REFRESH"] = 1,
	["SPELL_AURA_APPLIED_DOSE"] = 1,
	--]]

	ns.UnregisterEvent('ADDON_LOADED', 'empowered')
end

ns.RegisterEvent('ADDON_LOADED', Initialize, 'empowered')

--[[
GetSpellBonusHealing()
power, posBuff, negBuff = UnitAttackPower("player")

melee:
	min, max, minOH, maxOH, physPlus, physNeg, modifier = UnitDamage("player")
	19742.634765625, 30469.759765625, 9871.1748046875, 15234.736328125, 0, 0, 1.1000000238419
ranged:
	speed, min, max, physPlus, physNeg, modifier = UnitRangedDamage("player")
--]]
