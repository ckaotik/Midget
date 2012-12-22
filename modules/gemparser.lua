local _, ns = ...
local LibDeformat = LibStub("LibDeformat-3.0")

-- ================================================
-- TopFit Gem Exporter
-- ================================================

local function deformat(text, pattern)
	if string.find(pattern, "|4") then
		if LibDeformat.Deformat(text, pattern:gsub("|4(.-):(.-);", "%2")) then
			return LibDeformat.Deformat(text, pattern:gsub("|4(.-):(.-);", "%2"))
		else
			return LibDeformat.Deformat(text, pattern:gsub("|4(.-):(.-);", "%1"))
		end
	end
	return LibDeformat.Deformat(text, pattern)
end
local gems = select(8, GetAuctionItemClasses())
local gemTypesLocal = { GetAuctionItemSubClasses(8) }
local gemTypes = {
	[gemTypesLocal[1]] = '{"RED"}',
	[gemTypesLocal[2]] = '{"BLUE"}',
	[gemTypesLocal[3]] = '{"YELLOW"}',
	[gemTypesLocal[4]] = '{"RED", "BLUE"}',
	[gemTypesLocal[5]] = '{"BLUE", "YELLOW"}',
	[gemTypesLocal[6]] = '{"RED", "YELLOW"}',
	[gemTypesLocal[7]] = '{"META"}',
	-- [gemTypesLocal[8]] = '{}',
	[gemTypesLocal[9]] = '{"RED", "BLUE", "YELLOW"}',
	[gemTypesLocal[10]] = '{"COGWHEEL"}'
}
local tooltipStats = {
	["gearLevel"] = SOCKETING_ITEM_MIN_LEVEL_I,
	["unique"] = ITEM_LIMIT_CATEGORY_MULTIPLE,
	["bop"] = ITEM_BIND_ON_PICKUP,
	["skill"] = ITEM_MIN_SKILL,
	["metaCountG"] = ENCHANT_CONDITION_REQUIRES..ENCHANT_CONDITION_MORE_VALUE,
	["metaCountL"] = ENCHANT_CONDITION_REQUIRES..ENCHANT_CONDITION_LESS_VALUE,
	["metaCountEQ"] = ENCHANT_CONDITION_REQUIRES..ENCHANT_CONDITION_EQUAL_VALUE,
	["metaCountNEQ"] = ENCHANT_CONDITION_REQUIRES..ENCHANT_CONDITION_NOT_EQUAL_VALUE,
	["metaEQ"] = ENCHANT_CONDITION_REQUIRES..ENCHANT_CONDITION_EQUAL_COMPARE,
	["metaG"] = ENCHANT_CONDITION_REQUIRES..ENCHANT_CONDITION_MORE_COMPARE,
	["metaGEQ"] = ENCHANT_CONDITION_REQUIRES..ENCHANT_CONDITION_MORE_EQUAL_COMPARE,
	["metaNEQ"] = ENCHANT_CONDITION_REQUIRES..ENCHANT_CONDITION_NOT_EQUAL_COMPARE,
}
local baseStats = {
	-- red
	"ITEM_MOD_STRENGTH_SHORT", "ITEM_MOD_AGILITY_SHORT", "ITEM_MOD_PARRY_RATING_SHORT", "ITEM_MOD_INTELLECT_SHORT", "ITEM_MOD_EXPERTISE_RATING_SHORT",
	-- blue
	"ITEM_MOD_STAMINA_SHORT", "ITEM_MOD_SPIRIT_SHORT", "ITEM_MOD_HIT_RATING_SHORT", "ITEM_MOD_PVP_POWER_SHORT",
	-- yellow
	"ITEM_MOD_DODGE_RATING_SHORT", "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_RESILIENCE_RATING_SHORT", "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_MASTERY_RATING_SHORT"
}
local allowedTTLines = {GEM_TEXT_BLUE, GEM_TEXT_COGWHEEL, GEM_TEXT_GREEN, GEM_TEXT_HYDRAULIC, GEM_TEXT_META, GEM_TEXT_ORANGE, GEM_TEXT_PRISMATIC, GEM_TEXT_PURPLE, GEM_TEXT_RED, GEM_TEXT_YELLOW}

ns.gemData = {}
-- later, order by level asc, colors asc
local function ParseGemData(tooltip, itemLink, gemType)
	if not (tooltip and itemLink and gemType) then return end

	local itemID = ns.GetItemID(itemLink)
	local _, _, quality, level = GetItemInfo(itemLink)

	for _, gemData in ipairs(ns.gemData) do
		if gemData.itemID == itemID then
			return
		end
	end

	local text, statValue, data, evaluated, parts
	local numLines = tooltip:NumLines()

	data = {
		colors = gemTypes[gemType],
		stats = {},
		gearLevel = nil,
		level = level,
		itemID = itemID,
		quality = quality,
		name = ( select(1, GetItemInfo(itemLink)) ),
		misc = ""
	}

	for i = 2, numLines do -- skip item title line
		text = _G[tooltip:GetName() .. "TextLeft"..i]
		text = text and text:GetText() or ""

		text = strtrim(text)
		text = string.gsub(text, "|c........", "")
		text = string.gsub(text, "|r", "")

		evaluated = nil

		parts = string.explode(text, "\n")
		for _, subText in pairs(parts) do
			subText = strtrim(subText)

			for label, stat in pairs(tooltipStats) do
				stat = strtrim(stat)

				statValue = (subText == stat) and stat or deformat(subText, stat)
				if statValue then
					evaluated = true
					data[label] = (data[label] and data[label].."; " or "") .. strjoin(" ", deformat(subText, stat))
					break
				end
			end
		end
		if not evaluated then
			if string.find(text, "+") then -- actual stat
				parts = string.explode(text, ENCHANT_CONDITION_AND)
				for i, stat in ipairs(parts) do
					stat = strtrim(stat)
					evaluated = nil
					-- does this part match any known stat?
					for _, statGlobal in pairs(baseStats) do
						statValue = deformat(stat, "+%d ".._G[statGlobal])
						if statValue then
							evaluated = true
							data.stats[statGlobal] = statValue
						end
					end
					if not evaluated and i ~= 1 then
						data.misc = data.misc .. "; " .. stat
						evaluated = true
					end
				end
			else -- something unrecognized
				local compareText = string.sub(text, 2, -2)
				if not tContains(allowedTTLines, text) and not tContains(allowedTTLines, compareText)
					and not (string.sub(text, 1, 1) == '"' and string.sub(text, -1, -1) == '"') then
					data.misc = data.misc .. "; " .. text
				end
			end
		end
	end
	table.insert(ns.gemData, data)
	ns.Print(itemLink.." successfully scanned.")
end
function ns.ExportGemData()
	table.sort(ns.gemData, function(a,b)
		if a.level == b.level then
			if a.quality == b.quality then
				if a.colors == b.colors then
					return a.name < b.name
				else
					if a.color and b.color then
						return a.color < b.color
					else
						return a.color
					end
				end
			else
				return a.quality < b.quality
			end
		else
			return a.level < b.level
		end
	end)

	local stub = [[    [%d] = {         -- %s
        colors = %s,
        stats = {
%s        }
        -- required item level: %s%s
    },
]]

    local msg, stats, temp, misc = ""
    local unique, bop, skill

    for _, data in ipairs(ns.gemData) do
    	stats = ""
    	for statGlobal, statValue in pairs(data.stats) do
    		stats = stats .. string.format([[            ["%s"] = %d,
]], statGlobal, statValue)
    	end

    	if stats ~= "" then
	    	temp = string.explode(data.misc, "; ")
	    	misc = ""
	    	for _, note in pairs(temp) do
	    		if note ~= "" then
	    			misc = misc .. string.format("\n"..[[        -- %s]], note)
	    		end
	    	end

	    	for _, value in pairs({"unique", "bop", "skill",
	    		"metaCountG", "metaCountL", "metaCountEQ", "metaCountNEQ", "metaEQ", "metaG", "metaGEQ", "metaNEQ"}) do
	    		if data[value] then
	    			if data[value] == "" then
	    				data[value] = "true"
	    			end
	    			misc = misc .. string.format("\n"..[[        -- %s: %s]], value, data[value])
	    		end
	    	end

	    	msg = msg .. string.format(stub, data.itemID, data.name, data.colors, stats, data.gearLevel or 0, misc)
	    end
    end

	BCMCopyFrame:Show()
	BCMCopyBox:SetText(msg)
	BCMCopyBox:HighlightText(0)
end

GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
	if not MidgetDB.scanGems then return end

	local name, link = tooltip:GetItem()
	if not (name and link) then return end

	local _, _, _, _, _, itemClass, itemSubClass = GetItemInfo(link)
	if itemClass == gems and itemSubClass ~= gemTypesLocal[8] then
		ParseGemData(tooltip, link, itemSubClass)
	end
end)
