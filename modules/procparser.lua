local _, ns = ...
-- GLOBALS: _G, ITEM_SPELL_TRIGGER_ONEQUIP, LARGE_NUMBER_SEPERATOR, gmatch, tonumber, ipairs
local lower = string.lower

local CHANCE = GetLocale() == "deDE" and "Chance" or "chance"
function ns:ParseProcBonus(tooltip)
	if not tooltip then return end

	local tooltipName = tooltip:GetName()
	for i = 2, tooltip:NumLines() do
		local line = _G[tooltipName .. "TextLeft" .. i]
		local text = line:GetText()
		if text and text:match("^"..ITEM_SPELL_TRIGGER_ONEQUIP) and text:find(CHANCE) then
			local condition, stat, duration, cooldown = ns.ParseProcBonusText(text)
			return condition, stat, duration, cooldown
		end
	end
end

local baseStats = {
	"ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_PARRY_RATING_SHORT", "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_EXPERTISE_RATING_SHORT", "ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_PVP_POWER_SHORT", "ITEM_MOD_DODGE_RATING_SHORT", "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_RESILIENCE_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_MASTERY_RATING_SHORT"
}

local DUR_SECONDS = INT_SPELL_DURATION_SEC:gsub("%%d", "%%d+")
local DUR_MINUTES = INT_SPELL_DURATION_MIN:gsub("%%d", "%%d+")
local DUR_COOLDOWN = ITEM_COOLDOWN_TOTAL:gsub("%%s", "%%s+")

local CMP_ATTACK1 = ATTACK_COLON:gsub(":", ""):lower()
local CMP_ATTACK2 = DAMAGE:lower()
local CMP_HEAL1 = SHOW_COMBAT_HEALING:lower()
local CMP_HEAL2 = HEALS:lower()
local CMP_HEAL3 = HEALER:lower()
local CMP_HEAL4 = ACTION_SPELL_HEAL:lower()

local CMP_SPELL = SPELLS:lower()
local CMP_MELEE = MELEE:lower()
local CMP_RANGE = RANGED:lower()

function ns.ParseProcBonusText(text)
	local isHeal, isMelee, isRanged, isCaster

	text = lower(text)
	if text:find(CMP_SPELL) then
		if text:find(CMP_HEAL1) or text:find(CMP_HEAL2) or text:find(CMP_HEAL3) then
			isHeal = true
		end
		if text:find(CMP_ATTACK1) or text:find(CMP_ATTACK2) then
			isCaster = true
		end

		if not isHeal and not isCaster then
			isHeal = true
			isCaster = true
		end
	end
	if text:find(CMP_ATTACK1) or text:find(CMP_ATTACK2) then
		if text:find(CMP_MELEE) then
			isMelee = true
		end
		if text:find(CMP_RANGE) then
			isRanged = true
		end

		if not isRanged and not isMelee and not isCaster and not isHeal then
			isMelee = true
			isRanged = true
			isCaster = true
		end
	end

	local bonus, amount, duration
	if isHeal or isCaster or isMelee or isRanged then
		for _, stat in ipairs(baseStats) do
			if text:find(lower(_G[stat])) then
				bonus =  bonus and bonus..", "..stat or stat
			end
		end
	end
	for statAmount in gmatch(text, "um ([0-9"..LARGE_NUMBER_SEPERATOR.."]+)") do
		amount = statAmount:gsub("%"..LARGE_NUMBER_SEPERATOR, "")
		amount = tonumber(amount)
		break
	end
	for seconds in gmatch(text, lower(DUR_SECONDS)) do
		duration = seconds:match("(%d+)")
		duration = tonumber(duration)
		break
	end

	return isHeal, isCaster, isMelee, isRanged, bonus, amount, duration
end
-- /spew Midget:ParseProcBonus(GameTooltip)
-- or Spew(...)
