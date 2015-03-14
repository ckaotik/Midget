local addonName, addon, _ = ...
local plugin = addon:NewModule('GroupFinder', 'AceEvent-3.0')

-- GLOBALS: _G,
-- GLOBALS:
-- GLOBALS: hooksecurefunc

function plugin:OnEnable()
	local function LFGCategoryButtonOnDoubleClick(self)
		LFGListFrame.CategorySelection.FindGroupButton:Click()
	end
	hooksecurefunc('LFGListCategorySelection_UpdateCategoryButtons', function(self)
		for _, button in pairs(LFGListFrame.CategorySelection.CategoryButtons) do
			if not button.midgetDone then
				button:HookScript('OnDoubleClick', LFGCategoryButtonOnDoubleClick)
				button.midgetDone = true
			end
		end
	end)

	-- local categories = C_LFGList.GetAvailableCategories() => {1(Quests), 2(Dungeons), 3(Schlachtzüge), 4(Arenen), 5(Szenarien), 6(Custom), 7(Arenageplänkel), 8(Schlachtfelder), 9(Gewertete Schlachtfelder), 10(Ashran)}
	-- local name, separateRecommended, autoChoose, preferCurrentArea = C_LFGList.GetCategoryInfo(3) => "Schlachtz\195\188ge", true, false, false
	-- local groups = C_LFGList.GetAvailableActivityGroups(3) => {14, 15, 16, 17, 72, 73, 74, 75, 76, 77, 78, 79, 1, 83, 82, 81, 80}
	-- local name, groupOrder = C_LFGList.GetActivityGroupInfo(79) => "Drachenseele", 0
	-- => matches encounter journal
	-- local defeated = C_LFGList.GetSearchResultEncounterInfo(groupID) => {"Erzfresser", "Gruul", "Hans"}

	-- LE_LFG_LIST_FILTER_RECOMMENDED: 1, LE_LFG_LIST_FILTER_NOT_RECOMMENDED: 2, LE_LFG_LIST_FILTER_PVE: 4, LE_LFG_LIST_FILTER_PVP: 8
	-- C_LFGList.Search(categoryID, "query"[, filter[, preferredFilters])
	-- LFGListFrame.SearchPanel: categoryID, applications, searchFailed, filters, preferredFilters, totalResults, results = {index = resultID}
	-- local resultID, activityID, title, comment, voiceChat, iLvl, age, numBNetFriends, numCharFriends, numGuildMates, isDelisted, leaderFullName, numMembers, unknownBool = C_LFGList.GetSearchResultInfo(resultID)

	-- local activities = C_LFGList.GetAvailableActivities([categoryID][, groupID][, filters]) => {37, 38}
	-- C_LFGList.GetActivityInfo(37) => "Hochfels (Normal)", "Normal", 3, 14, 630, 5, 100, 30, 1, 0
	-- C_LFGList.GetActivityInfo(38) => "Hochfels (Heroisch)", "Heroisch", 3, 14, 645, 5, 100, 30, 1, 0
	-- fullName, shortName, categoryID, groupID, itemLevel, filters, minLevel, maxPlayers, displayType = C_LFGList.GetActivityInfo(activityID)

	-- self:RegisterEvent('ENCOUNTER_END')
	-- self:RegisterEvent('ENCOUNTER_START')
end

function plugin:OnDisable()
	-- self:UnregisterEvent('ENCOUNTER_END')
	-- self:UnregisterEvent('ENCOUNTER_START')
end

-- http://wowprogramming.com/docs/events/ENCOUNTER_START
function plugin:ENCOUNTER_START(event, encounterID, encounterName, difficulty, raidSize)
	-- print('Encounter', encounterName, '('..encounterID..')', 'started')
end

-- http://wowprogramming.com/docs/events/ENCOUNTER_END
function plugin:ENCOUNTER_END(event, encounterID, encounterName, difficulty, raidSize, endStatus)
	-- print('Encounter', encounterName, '('..encounterID..')', endStatus == 1 and 'completed' or 'wiped')
end
