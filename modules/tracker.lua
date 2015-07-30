local addonName, addon, _ = ...
local plugin = addon:NewModule('Tracker', 'AceEvent-3.0')

OBJECTIVE_TRACKER_UPDATE_MODULE_PROFESSION = 0x2000
local TRACKER = ObjectiveTracker_GetModuleInfoTable()
TRACKER.updateReasonModule = OBJECTIVE_TRACKER_UPDATE_MODULE_PROFESSION
TRACKER.usedBlocks = {}
plugin.tracker = TRACKER

function TRACKER:OnBlockHeaderClick(block, mouseButton)
	if true then
		print('OnBlockHeaderClick', block.id, mouseButton)
		return
	end
	if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() then
		ChatEdit_InsertLink(achievementLink)
	elseif mouseButton ~= 'RightButton' then
		CloseDropDownMenus()
		if IsModifiedClick("QUESTWATCHTOGGLE") then
		AchievementObjectiveTracker_UntrackAchievement(_, block.id)
		elseif not AchievementFrame:IsShown() then
			AchievementFrame_ToggleAchievementFrame()
			AchievementFrame_SelectAchievement(block.id)
		else
			if AchievementFrameAchievements.selection ~= block.id then
				AchievementFrame_SelectAchievement(block.id)
			else
				AchievementFrame_ToggleAchievementFrame()
			end
		end
	else
		ObjectiveTracker_ToggleDropDown(block, AchievementObjectiveTracker_OnOpenDropDown)
	end
end

local professions, expansionMaxRank, expansionMaxName = {}, unpack(PROFESSION_RANKS[#PROFESSION_RANKS])
function TRACKER:Update()
	local prof1, prof2, archaeology, fishing, cooking, firstAid = GetProfessions()
	professions[1] = prof1 or 0 		professions[2] = prof2 or 0
	professions[3] = archaeology or 0	professions[4] = fishing or 0
	professions[5] = cooking or 0 		professions[6] = firstAid or 0

	TRACKER:BeginLayout()
	for index, profession in ipairs(professions) do
		local name, icon, rank, maxRank, numSpells, spelloffset, skillLine, rankModifier, specializationIndex, specializationOffset = GetProfessionInfo(profession)
		if profession > 0 and addon.db.char.trackProfession[index] then
			local block = self:GetBlock(profession)
			self:SetBlockHeader(block, ('|T%s:0|t %s'):format(icon, name))

			local isMaxSkill = rank >= expansionMaxRank and rank == maxRank
			local skill = isMaxSkill and expansionMaxName or ('%d/%d'):format(rank, maxRank)
			local line = self:AddObjective(block, profession, skill, nil, nil, true)
			if not isMaxSkill then
				-- cause line to move up
				local lineSpacing = block.module.lineSpacing
				block.module.lineSpacing = -16
				-- abusing timer bar for progress
				local timerBar = self:AddTimerBar(block, line, maxRank, nil)
				timerBar:SetScript('OnUpdate', nil)
				timerBar.Bar:SetMinMaxValues(0, maxRank)
				timerBar.Bar:SetValue(rank)
				block.module.lineSpacing = lineSpacing
			else
				self:FreeProgressBar(block, line)
			end

			-- add to tracker
			block:SetHeight(block.height)
			if ObjectiveTracker_AddBlock(block) then
				block:Show()
				TRACKER:FreeUnusedLines(block)
			else -- we've run out of space
				block.used = false
				break
			end
		end
	end
	TRACKER:EndLayout()
end

function plugin:OnEnable()
	hooksecurefunc('ObjectiveTracker_Initialize', function(frame)
		table.insert(frame.MODULES, TRACKER)
		frame.BlocksFrame.ProfessionHeader = CreateFrame('Frame', nil, frame.BlocksFrame, 'ObjectiveTrackerHeaderTemplate')
		TRACKER:SetHeader(frame.BlocksFrame.ProfessionHeader, _G.TRADE_SKILLS, 0)

		self:RegisterEvent('SKILL_LINES_CHANGED', function()
			ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_MODULE_PROFESSION)
		end)
		ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_MODULE_PROFESSION)
	end)
end
