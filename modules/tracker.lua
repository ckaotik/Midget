local _, ns = ...
-- GLOBALS: MidgetLocalDB, CreateFrame, hooksecurefunc, UIDropDownMenu_AddButton, math, select
-- GLOBALS: WatchFrame, WatchFrameHeaderDropDown, WatchFrame_AddObjectiveHandler, WatchFrame_Update, WatchFrame_SetLine, WATCHFRAME_QUEST_OFFSET, WATCHFRAME_TYPE_OFFSET, WATCHFRAME_INITIAL_OFFSET, WATCHFRAMELINES_FONTSPACING
-- GLOBALS: TRADESKILLS, TRADESKILL_RANK, GetProfessions, GetProfessionInfo, C_PetJournal, BATTLE_PET_SOURCE_5, ITEM_QUALITY_COLORS
local DASH_NONE, DASH_SHOW, DASH_HIDE, DASH_ICON = 0, 1, 2, 3

-- ================================================
-- Skill progress tracker
-- ================================================
local MAX_SKILL = PROFESSION_RANKS[ #PROFESSION_RANKS ][1]
local WATCHFRAME_SKILLLINES = {}
local skillLineIndex = 1

local function WatchFrame_GetSkillLine()
	local line = WATCHFRAME_SKILLLINES[skillLineIndex]
	if not line then
		WATCHFRAME_SKILLLINES[skillLineIndex] = WatchFrame.lineCache:GetFrame()
		line = WATCHFRAME_SKILLLINES[skillLineIndex]
	end
	if not line.icon then
		line.icon = line:CreateTexture('$parentIcon')
		line.icon:SetSize(16, 16)
		line.icon:SetPoint("TOPLEFT", 0, -1)
	end

	line:Reset()
	skillLineIndex = skillLineIndex + 1

	return line
end
local function WatchFrame_ReleaseUnusedSkillLines()
	local line
	for i = skillLineIndex, #WATCHFRAME_SKILLLINES do
		line = WATCHFRAME_SKILLLINES[i]
		if line.progress then
			line.progress:SetValue(0)
			line.progress:Hide()
		end
		line.dash:SetWidth(0)
		line.icon:Hide()
		line:Hide()
		line.frameCache:ReleaseFrame(line)
		WATCHFRAME_SKILLLINES[i] = nil
	end
end
local function DisplaySkillTracker(lineFrame, nextAnchor, maxHeight, frameWidth)
	skillLineIndex = 1 -- reset count or we get everything dozens of times!
	if #(MidgetLocalDB.trackProfession) == 0 then
		WatchFrame_ReleaseUnusedSkillLines()
		return nextAnchor, 0, 0, 0
	end

	local line, previousLine
	local profession, skillName, texture, current, max, progress
	for i = 1, select('#', GetProfessions()) do
		profession = select(i, GetProfessions())
		if profession and MidgetLocalDB.trackProfession[i] then
			skillName, texture, current, max = GetProfessionInfo(profession)
			if current < math.max(max, MAX_SKILL) then
				if skillLineIndex == 1 then
					-- header
					line = WatchFrame_GetSkillLine()
					WatchFrame_SetLine(line, previousLine, -WATCHFRAME_QUEST_OFFSET, true, TRADESKILLS, DASH_NONE)
					if not previousLine then
						line:SetPoint("RIGHT", lineFrame, "RIGHT", 0, 0)
						line:SetPoint("LEFT", lineFrame, "LEFT", 0, 0)
						if nextAnchor then
							line:SetPoint("TOP", nextAnchor, "BOTTOM", 0, -WATCHFRAME_TYPE_OFFSET)
						else
							line:SetPoint("TOP", lineFrame, "TOP", 0, -WATCHFRAME_INITIAL_OFFSET)
						end
					end
					line:Show()
					previousLine = line
				end

				-- progress data
				line = WatchFrame_GetSkillLine()
				WatchFrame_SetLine(line, previousLine, WATCHFRAMELINES_FONTSPACING-3, false, "", DASH_ICON)

				line.icon:SetTexture(texture)
				line.icon:Show()

				if not line.progress then
					line.progress = CreateFrame("StatusBar", "$parentProgressBar", line, "AchievementProgressBarTemplate")
					line.progress:SetPoint("LEFT", line.text, "LEFT", 2, 0)
					line.progress:SetPoint("RIGHT", line.text, "RIGHT")
				end
				line.progress:Show()
				line.progress:SetMinMaxValues(0, max)
				line.progress:SetValue(current)
				line.progress.text:SetFormattedText(TRADESKILL_RANK, current, max)

				if current == max then
					line.progress:SetStatusBarColor(.6, 0, 0, 1)
				elseif current >= max - 25 and max < MAX_SKILL then
					line.progress:SetStatusBarColor(.6, .6, 0, 1)
				else
					line.progress:SetStatusBarColor(0, .6, 0, 1)
				end

				line:Show()
				previousLine = line
			end
		end
	end
	WatchFrame_ReleaseUnusedSkillLines()
	-- nextAnchor, maxLineWidth, numObjectives, numPopUps
	return previousLine or nextAnchor, 0, previousLine and 1 or 0, 0
end

-- ================================================
-- Current battle team tracker
-- ================================================
local MAX_PET_LEVEL, MAX_ACTIVE_PETS = 25, 3
local WATCHFRAME_TEAMLINES = {}
local teamLineIndex = 1

local function WatchFrame_GetTeamLine()
	local line = WATCHFRAME_TEAMLINES[teamLineIndex]
	if not line then
		WATCHFRAME_TEAMLINES[teamLineIndex] = WatchFrame.lineCache:GetFrame()
		line = WATCHFRAME_TEAMLINES[teamLineIndex]
	end
	if not line.icon then
		line.icon = line:CreateTexture('$parentIcon')
		line.icon:SetSize(16, 16)
		line.icon:SetPoint("TOPLEFT", 0, -1)
	end
	line:Reset()
	teamLineIndex = teamLineIndex + 1
	return line
end
local function WatchFrame_ReleaseUnusedTeamLines()
	local line
	for i = teamLineIndex, #WATCHFRAME_TEAMLINES do
		line = WATCHFRAME_TEAMLINES[i]
		if line.xp then line.xp:SetValue(0) end
		if line.progress then
			line.progress:SetValue(0)
			line.progress:Hide()
		end
		if line.level then line.level:SetText("") end
		line.dash:SetWidth(0)
		line.icon:Hide()
		line:Hide()
		line.frameCache:ReleaseFrame(line)
		WATCHFRAME_TEAMLINES[i] = nil
	end
end
local function DisplayTeamTracker(lineFrame, nextAnchor, maxHeight, frameWidth)
	teamLineIndex = 1 -- reset count or we get everything dozens of times!
	if not MidgetLocalDB.trackBattlePetTeams then
		WatchFrame_ReleaseUnusedTeamLines()
		return nextAnchor, 0, 0, 0
	end

	local line, previousLine
	local petID, customName, level, xp, maxXp, petName, texture, petType, health, maxHealth, rarity
	for i = 1, MAX_ACTIVE_PETS do
		petID = C_PetJournal.GetPetLoadOutInfo(i)
		if petID then
			_, customName, level, xp, maxXp, _, _, petName, texture, petType = C_PetJournal.GetPetInfoByPetID(petID)
			health, maxHealth, _, _, rarity = C_PetJournal.GetPetStats(petID)

			if teamLineIndex == 1 then
				-- header
				line = WatchFrame_GetTeamLine()
				WatchFrame_SetLine(line, previousLine, -WATCHFRAME_QUEST_OFFSET, true,
					BATTLE_PET_SOURCE_5, DASH_NONE, true)

				--[[ TODO: add button to heal pets
				if ( item and (not isComplete or showItemWhenComplete) ) then
		          watchItemIndex = watchItemIndex + 1;
		          itemButton = _G["WatchFrameItem"..watchItemIndex];
		          if ( not itemButton ) then
		            WATCHFRAME_NUM_ITEMS = watchItemIndex;
		            itemButton = CreateFrame("BUTTON", "WatchFrameItem" .. watchItemIndex, lineFrame, "WatchFrameItemButtonTemplate");
		          end
		          itemButton:Show();
		          itemButton:ClearAllPoints();
		          itemButton:SetID(questIndex);
		          SetItemButtonTexture(itemButton, item);
		          SetItemButtonCount(itemButton, charges);
		          itemButton.charges = charges;
		          WatchFrameItem_UpdateCooldown(itemButton);
		          itemButton.rangeTimer = -1;
		          itemButton:SetPoint("TOPRIGHT", questTitle, "TOPRIGHT", 10, -2);
		        end
				--]]

				if not previousLine then
					line:SetPoint("RIGHT", lineFrame, "RIGHT", 0, 0)
					line:SetPoint("LEFT", lineFrame, "LEFT", 0, 0)
					if nextAnchor then
						line:SetPoint("TOP", nextAnchor, "BOTTOM", 0, -WATCHFRAME_TYPE_OFFSET)
					else
						line:SetPoint("TOP", lineFrame, "TOP", 0, -WATCHFRAME_INITIAL_OFFSET)
					end
				end
				line:Show()
				previousLine = line
			end

			-- battle pet data
			line = WatchFrame_GetTeamLine()
			WatchFrame_SetLine(line, previousLine, WATCHFRAMELINES_FONTSPACING-3, false, "", DASH_ICON)

			line.icon:SetTexture(texture)
			line.icon:Show()

			if not line.progress then
				line.progress = CreateFrame("StatusBar", "$parentProgressBar", line, "AchievementProgressBarTemplate")
				line.progress:SetPoint("LEFT", line.text, "LEFT", 2, 0)
				line.progress:SetPoint("RIGHT", line.text, "RIGHT")
			end
			line.progress:Show()
			if not line.xp then
				line.xp = CreateFrame("StatusBar", "$parentXPBar", line)
				line.xp:SetPoint("BOTTOMLEFT", line.progress, "BOTTOMLEFT")--, 2, 1)
				line.xp:SetPoint("BOTTOMRIGHT", line.progress, "BOTTOMRIGHT")--, -2, 1)
				line.xp:SetHeight(4)
				line.xp:SetStatusBarTexture("Interface\\RAIDFRAME\\Raid-Bar-Resource-Fill")
				line.xp:SetStatusBarColor(.45, .45, 1, 1) -- 0, .8, .8
				-- make this bar appear below progress' border but above its texture!
				line.xp:GetStatusBarTexture():SetDrawLayer("BORDER", 1)
			end
			if not line.level then
				line.level = line:CreateFontString(nil, "ARTWORK", "GameFontHighlightExtraSmall")
				local font, fontSize, fontStyle = line.level:GetFont()
				line.level:SetFont(font, fontSize, "OUTLINE")
				line.level:SetPoint("TOPLEFT", line.icon, "TOPLEFT", -2, 0)
				line.level:SetPoint("BOTTOMRIGHT", line.icon, "BOTTOMRIGHT", 3, 0)
				line.level:SetJustifyH("RIGHT")
				line.level:SetJustifyV("BOTTOM")
			end
			line.progress:SetMinMaxValues(0, maxHealth)
			line.progress:SetValue(health)
			line.progress.text:SetText(customName or petName)
			line.xp:SetMinMaxValues(0, maxXp)
			line.level:SetVertexColor(ITEM_QUALITY_COLORS[rarity-1].r, ITEM_QUALITY_COLORS[rarity-1].g, ITEM_QUALITY_COLORS[rarity-1].b, 1)
			if level < MAX_PET_LEVEL then
				line.xp:SetValue(xp)
				line.level:SetText(level)
			else
				line.xp:SetValue(0)
				line.level:SetText("")
			end

			line:Show()
			previousLine = line
		end
	end
	WatchFrame_ReleaseUnusedTeamLines()
	-- nextAnchor, maxLineWidth, numObjectives, numPopUps
	return previousLine or nextAnchor, 0, previousLine and 1 or 0, 0
end

local function updateHandler(frame, event, ...)
	if event ~= "UNIT_SPELLCAST_SUCCEEDED" or select(5, ...) == 127841 then -- revive pet
		WatchFrame_Update()
	end
end

local function CreateSkillTrackingCheckboxes()
	local function OnClick(self, btn)
		MidgetLocalDB.trackProfession[ self:GetID() ] = not MidgetLocalDB.trackProfession[ self:GetID() ]
		WatchFrame_Update()
	end

	for i, tradeskill in pairs({'PrimaryProfession1', 'PrimaryProfession2', 'SecondaryProfession1', 'SecondaryProfession2', 'SecondaryProfession3', 'SecondaryProfession4'}) do
		local button = CreateFrame('CheckButton', '$parentTrackSkill', _G[tradeskill], 'UICheckButtonTemplate')
		button:SetSize(18, 18)
		button:SetID(i)
		button:SetPoint('RIGHT', '$parentProfessionName', 'LEFT', -2, 0)
		button:SetChecked(MidgetLocalDB.trackProfession[i] or false)
		button:SetScript('OnClick', OnClick)
	end
end

ns.RegisterEvent("ADDON_LOADED", function()
	WatchFrame_AddObjectiveHandler(DisplayTeamTracker)
	WatchFrame_AddObjectiveHandler(DisplaySkillTracker)

	CreateSkillTrackingCheckboxes()
	ns.RegisterEvent("CHAT_MSG_SKILL", updateHandler, "tracker_updateSkills")

	ns.RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", updateHandler, "tracker_updateBattlePetsRevive")
	ns.RegisterEvent("PET_JOURNAL_LIST_UPDATE", updateHandler, "tracker_updateBattlePetsList")

	hooksecurefunc(C_PetJournal, "SetPetLoadOutInfo", function(index, petID, source)
		WatchFrame_Update()
	end)
	hooksecurefunc(WatchFrameHeaderDropDown, "initialize", function()
		UIDropDownMenu_AddButton {
			text = BATTLE_PET_SOURCE_5,
			checked = MidgetLocalDB.trackBattlePetTeams,
			isNotRadio = true,
			func = function()
				MidgetLocalDB.trackBattlePetTeams = not MidgetLocalDB.trackBattlePetTeams
				WatchFrame_Update()
			end
		}
	end)

	ns.UnregisterEvent("ADDON_LOADED", "tracker")
end, "tracker")
