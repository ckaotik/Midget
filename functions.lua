local addonName, ns, _ = ...

-- GLOBALS: _G, UIParent, LibStub, TipTac, MidgetDB, CorkFrame, MainMenuBar, InterfaceOptionsFrameAddOnsList, SLASH_ROLECHECK1, CHAT_CONFIG_CHAT_LEFT, WHISPER, CURRENTLY_EQUIPPED, TIMER_TYPE_CHALLENGE_MODE, SlashCmdList, UnitPopupMenus, UIDROPDOWNMENU_INIT_MENU, StaticPopupDialogs, GameTooltip, ItemRefTooltip, ItemRefShoppingTooltip1, ItemRefShoppingTooltip2, ItemRefShoppingTooltip3, ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3
-- GLOBALS: GameTooltip, PlaySound, GetScreenHeight, ToggleChatMessageGroup, PetBattleFrame, GetLocale, IsListeningForMessageType, CreateFrame, IsAddOnLoaded, ScrollFrameTemplate_OnMouseWheel, InitiateRolePoll, GetItemIcon, ChatFrame_AddMessageEventFilter, IsShiftKeyDown, UnitPopupShown, StaticPopup_Hide, UnitIsBattlePet, TimerTracker, TimerTracker_OnEvent, BigWigsLoader
-- GLOBALS: table, string, math, hooksecurefunc, type, ipairs, pairs

-- ================================================
-- Shared Media insertions
-- ================================================
local LSM = LibStub("LibSharedMedia-3.0", true)
local function AddMoreSharedMedia()
	if not MidgetDB.moreSharedMedia or not LSM then return end
	LSM:Register("border", "Glow", "Interface\\Addons\\Midget\\media\\glow.tga")
	LSM:Register("font", "Paralucent", "Interface\\Addons\\Midget\\media\\Paralucent.ttf")
	LSM:Register("font", "Andika", "Interface\\Addons\\Midget\\media\\Andika.ttf")
	LSM:Register("font", "Andika Compact", "Interface\\Addons\\Midget\\media\\Andika-Compact.ttf")
	LSM:Register("font", "Cibreo", "Interface\\Addons\\Midget\\media\\Cibreo.ttf")
	LSM:Register("font", "Futura Medium", "Interface\\Addons\\Midget\\media\\FuturaMedium.ttf")
	LSM:Register("font", "Avant Garde", "Interface\\Addons\\Midget\\media\\AvantGarde.ttf")
	LSM:Register("font", "Accidental Presidency", "Interface\\Addons\\Midget\\media\\AccidentalPresidency.ttf")
	LSM:Register("statusbar", "TukTex", "Interface\\Addons\\Midget\\media\\TukTexture.tga")
	LSM:Register("statusbar", "Smooth", "Interface\\Addons\\Midget\\media\\Smooth.tga")
end

-- ================================================
--  Interface Options Scrolling
-- ================================================
local function InterfaceOptionsScrolling()
	if not MidgetDB.InterfaceOptionsScrolling then return end

	local f
	for i = 1, 31 do
		f = _G["InterfaceOptionsFrameAddOnsButton"..i]
		f:EnableMouseWheel()
		f:SetScript("OnMouseWheel", function(self, val)
			ScrollFrameTemplate_OnMouseWheel(InterfaceOptionsFrameAddOnsList, val)
		end)
	end
end

-- ================================================
--  Tooltip item/spell/achievement ids
-- ================================================
local function AddTooltipID(tooltip, hyperlink)
	if not hyperlink then -- OnTooltipSetItem
		_, hyperlink = tooltip:GetItem()
	end
	if not hyperlink then -- OnTooltipSetSpell
		_, _, hyperlink = tooltip:GetSpell()
		hyperlink = hyperlink and 'spell:'..hyperlink
	end
	if not hyperlink then return end
	local linkType, id, data = hyperlink:match("(%l+):([^:]*):?([^\124]*)")

	--[[ local search
	if linkType == 'item' then
		-- search = ITEM_LEVEL
		search = ITEM_UPGRADE_TOOLTIP_FORMAT
	end
	search = search and search:gsub('%%d', '(%%d+)'):gsub('%%s', '(%%s+)') --]]

	local left, right = tooltip:GetName() .. 'TextLeft', tooltip:GetName() .. 'TextRight'
	local added
	for i = 1, tooltip:NumLines() do
		local text = _G[left..i] and _G[left..i]:GetText()
		if not text or text == CURRENTLY_EQUIPPED then
			-- nothing
		elseif not added then
			local lineRight = _G[right..i]
			lineRight:SetText(id)
			lineRight:SetTextColor(0.55, 0.55, 0.55, 0.5)
			lineRight:Show()
			added = true
		end
	end
end

-- ================================================
--  Cork
-- ================================================
local function CreateCorkButton()
	if not MidgetDB.CorkButton or not IsAddOnLoaded("Cork") then return end

	local buffButton = _G["CorkFrame"]

	buffButton.texture = buffButton:CreateTexture(buffButton:GetName().."Icon")
	buffButton.texture:SetTexture("Interface\\Icons\\Achievement_BG_winSOA")
	buffButton.texture:SetAllPoints()
	buffButton.dragHandle = buffButton:CreateTitleRegion()
	buffButton.dragHandle:SetPoint("TOPLEFT", buffButton)
	buffButton.dragHandle:SetPoint("BOTTOMRIGHT", buffButton, "TOPRIGHT", 0, -6)

	buffButton:SetWidth(37); buffButton:SetHeight(37)
	buffButton:SetPoint("CENTER")
	buffButton:SetMovable(true)

	-- LibButtonFacade support
	local LBF = LibStub("LibButtonFacade", true)
	if LBF then
		LBF:Group("Cork"):Skin()
		LBF:Group("Cork"):AddButton(buffButton)
	end
	hooksecurefunc("CameraZoomIn", function() CorkFrame:Click() end)
	hooksecurefunc("CameraZoomOut", function() CorkFrame:Click() end)
end

-- ================================================
-- 	Whisper (outgoing) Color
-- ================================================
local function OutgoingWhisperColor()
	if not MidgetDB.outgoingWhisperColor then return end
	local list = CHAT_CONFIG_CHAT_LEFT
	for i = #list, 1, -1 do
		if list[i].type == "WHISPER" then
			list[i+1] = {
				text = WHISPER .. (GetLocale() == "deDE" and " (ausgehend)" or " (outgoing)"),
				type = "WHISPER_INFORM",
				checked = function() return IsListeningForMessageType("WHISPER") end,
				func = function(self, checked) ToggleChatMessageGroup(checked, "WHISPER") end,
			}
			break
		else
			list[i+1] = list[i]
		end
	end
end

-- ================================================
-- Raid Finder texts are too long!
-- ================================================
local function ShortenLFRNames()
	if not MidgetDB.shortenLFRNames then return end
	hooksecurefunc("LFGRewardsFrame_UpdateFrame", function(frame, raidID, background)
		local title = frame.title:GetText()
		if string.len(title) > 25 then
			frame.title:SetText(string.gsub(title, "%s?(.[\128-\191]*)%S+%s", "%1. "))
		end
	end)
end

-- ================================================
-- Chat link icons
-- ================================================
local function AddLootIcons(self, event, message, ...)
	local function Icon(link)
		local texture = GetItemIcon(link)
		return "\124T" .. texture .. ":" .. 12 .. "\124t" .. link
	end
	message = message:gsub("(\124c%x+\124Hitem:.-\124h\124r)", Icon)
	return false, message, ...
end

-- ================================================
-- add show in journal entry to unit dropdowns
-- ================================================
local function CustomizeDropDowns()
	local dropDown = UIDROPDOWNMENU_INIT_MENU
	local which = dropDown.which
	if which then
		for index, value in ipairs(UnitPopupMenus[which]) do
			if value == "PET_SHOW_IN_JOURNAL" and not (dropDown.unit and UnitIsBattlePet(dropDown.unit)) then
				UnitPopupShown[1][index] = 0
				break
			end
		end
	end
end

-- ================================================
--  move pet battle frame down a little
-- ================================================
local function MovePetBatteFrame(offset)
	if not MidgetDB.movePetBattleFrame then return end
	PetBattleFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, offset)
end

-- ================================================
-- ValidateFramePosition with no menu bar
-- ================================================
local function FixMenuBarHeight()
	if not MidgetDB.menuBarHeight then return end
	hooksecurefunc("ValidateFramePosition", function(frame, offscreenPadding, returnOffscreen)
		if not offscreenPadding then
			if math.abs(frame:GetBottom() - MainMenuBar:GetHeight()) < 1 then
				local newAnchorY = frame:GetHeight() - GetScreenHeight()
				frame:SetPoint("TOPLEFT", nil, "TOPLEFT", frame:GetLeft(), newAnchorY)
				-- ValidateFramePosition(frame, -1*MainMenuBar:GetHeight(), returnOffscreen)
			end
		end
	end)
end

-- ================================================
-- Apply TipTac styling to other frames as well
-- ================================================
local function AddTipTacStyles()
	if not MidgetDB.TipTacStyles then return end
	if IsAddOnLoaded("TipTac") then
		-- "Corkboard", "ReagentMaker_tooltipRecipe", "FloatingBattlePetTooltip", "BattlePetTooltip",
		hooksecurefunc("CreateFrame", function(type, name, parent, template)
			-- if template == "GameTooltipTemplate" then
			if name == "ReagentMaker_tooltipRecipe" then
				TipTac:AddModifiedTip(_G[name])
			end
		end)
	end
end

-- ================================================
-- Hide unusable item comparison
-- ================================================
local function HideUnusableCompareTips()
	if not MidgetDB.hideUnusableCompareTips then return end
	local function HookCompareItems(shoppingtip)
		local old = shoppingtip.SetHyperlinkCompareItem
		shoppingtip.SetHyperlinkCompareItem = function(self, link, level, shift, main, ...)
			main = nil
			return old(self, link, level, shift, main, ...)
		end
	end

	HookCompareItems(ShoppingTooltip1)
	HookCompareItems(ShoppingTooltip2)
	HookCompareItems(ShoppingTooltip3)
	HookCompareItems(ItemRefShoppingTooltip1)
	HookCompareItems(ItemRefShoppingTooltip2)
	HookCompareItems(ItemRefShoppingTooltip3)
end

-- ================================================
-- Add further info to lfg tooltips
-- ================================================
local function AddLFREntryInfo(button, index)
	local name, level, areaName, className, comment, partyMembers, status, class, encountersTotal, encountersComplete, isIneligible, isLeader, isTank, isHealer, isDamage, bossKills, specID, isGroupLeader, armor, spellDamage, plusHealing, CritMelee, CritRanged, critSpell, mp5, mp5Combat, attackPower, agility, maxHealth, maxMana, gearRating, avgILevel, defenseRating, dodgeRating, BlockRating, ParryRating, HasteRating, expertise = SearchLFGGetResults(index)

	if button.type == 'individual' then
		if isDamage and spellDamage > attackPower then
			-- caster dps shown in green, otherwise regular (red)
			button.damageIcon:SetTexture('Interface\\LFGFRAME\\LFGRole_Green')
		end

		if level == 90 then
			button.level:SetFormattedText('%d', avgILevel)
		end
		button.tankCount:SetText('')
		button.healerCount:SetText('')
		button.damageCount:SetText('')
	else
		if level == 90 then
			local _, _, _, _, _, partyMembers = SearchLFGGetResults(button.index)
			local numTanks, numHeals, numDPS = isTank and 1 or 0, isHealer and 1 or 0, isDamage and 1 or 0
			local itemLevels = avgILevel
			for i = 1, partyMembers do
				local name, level, relationship, className, areaName, comment, isLeader, isTank, isHealer, isDamage, bossKills, specID, isGroupLeader, _, _, _, _, _, _, _, _, _, _, _, _, _, avgILevel = SearchLFGGetPartyResults(button.index, i)
				numTanks = numTanks + (isTank   and 1 or 0)
				numHeals = numHeals + (isHealer and 1 or 0)
				numDPS   = numDPS   + (isDamage and 1 or 0)
				itemLevels = (itemLevels or 0) + (avgILevel or 0)
			end

			button.level:SetFormattedText('%d', itemLevels/(partyMembers+1))
			button.tankCount:SetText(numTanks)
			button.healerCount:SetText(numHeals)
			button.damageCount:SetText(numDPS)
		end
	end
end

local function ShowLFREntryTooltip(button)
	if button.type ~= 'individual' then return end

	local _, _, _, _, _, partyMembers = SearchLFGGetResults(button.index)
	local numTanks, numHeals, numDPS, itemLevels
	for i = 1, partyMembers do
		local name, level, relationship, className, areaName, comment, isLeader, isTank, isHealer, isDamage, bossKills, specID, isGroupLeader, _, _, _, _, _, _, _, _, _, _, _, _, _, avgILevel = SearchLFGGetPartyResults(button.index, i)
		numTanks = (numTanks or 0) + (isTank   and 1 or 0)
		numHeals = (numHeals or 0) + (isHealer and 1 or 0)
		numDPS   = (numDPS   or 0) + (isDamage and 1 or 0)
		itemLevels = (itemLevels or 0) + avgILevel
	end
end

-- ================================================
-- Undress button on models!
-- ================================================
function ns.AddUndressButton(frame)
	local undressButton = CreateFrame("Button", "$parentUndressButton", frame.controlFrame, "ModelControlButtonTemplate")
	undressButton:SetPoint("LEFT", "$parentRotateResetButton", "RIGHT", 0, 0)
	undressButton:RegisterForClicks("AnyUp")
	undressButton:SetScript("OnClick", function(self)
		self:GetParent():GetParent():Undress()
		PlaySound("igInventoryRotateCharacter");
	end)

	undressButton.tooltip = "Undress"
	undressButton.tooltipText = "Click to completely undress this character!"

	frame.controlFrame:SetWidth(frame.controlFrame:GetWidth() + undressButton:GetWidth())
	frame.controlFrame.undressButton = undressButton
end


local function AddUndressButtons()
	if not MidgetDB.undressButton then return end
	-- these models are create before we can hook
	for _, name in pairs({"DressUpModel", "SideDressUpModel"}) do
		if not _G[name.."ControlFrameUndressButton"] then
			ns.AddUndressButton(_G[name])
		end
	end
	hooksecurefunc('Model_OnLoad', function(self)
		if self.controlFrame and not self.controlFrame.undressButton then
			ns.AddUndressButton(self)
		end
	end)
end
local function FixModelLighting()
	if not MidgetDB.modelLighting then return end
	for _, name in pairs({"DressUpModel", "CharacterModelFrame", "SideDressUpModel", "InspectModelFrame"}) do
		local frame = _G[name]
		if frame then
			frame:SetLight(1, 0, 1, 1, -1, 1)
			frame:SetFacing(0)
			if name == "SideDressUpModel" then
				frame:SetModelScale(2)
				frame:SetPosition(0, 0.1, -0.5)
			end
		end
	end
end

-- ================================================
-- Accept popups on SHIFT
-- ================================================
local openPopup
local function AutoAcceptPopup(which, arg1, arg2, data)
	if type(which) == 'table' then
		data  = which.data
		which = which.which
	end
	local info = StaticPopupDialogs[which]

	if info and which ~= 'DEATH' and MidgetDB.SHIFTAcceptPopups and IsShiftKeyDown() then
		if info.OnAccept then
			info.OnAccept(nil, data)
		end
		StaticPopup_Hide(which, data)
	end
end
--[[ local function AutoAcceptPopup(self)
	local popup = self or openPopup
	if not MidgetDB.SHIFTAcceptPopups or type(popup) ~= "table" then return end
	if IsShiftKeyDown() and popup.which ~= "DEATH" then
		if popup.which == "GOSSIP_CONFIRM" and not popup.data then
			-- delay
			openPopup = popup
		else
			StaticPopup_OnClick(popup, 1)
			openPopup = nil
		end
	end
end --]]

-- ================================================
--  Fancy BigWigs pull timer, like those in challenge modes
-- ================================================
local function InitBigWigsFancyPullTimer()
	if not IsAddOnLoaded("BigWigs_Plugins") then
		ns.RegisterEvent("ADDON_LOADED", function(self, event, addon)
			if addon == "BigWigs_Plugins" then
				ns.UnregisterEvent("ADDON_LOADED", "bigwigs_fancypull")
				InitBigWigsFancyPullTimer()
			end
		end, "bigwigs_fancypull")

		return
	end

	local L = LibStub("AceLocale-3.0"):GetLocale("Big Wigs: Plugins")
	BigWigsLoader:RegisterMessage("BigWigs_StartBar", function(_, plugin, _, text, timeLeft)
		if text == ('Pull' or L['Pull']) then
			TimerTracker_OnEvent(TimerTracker, "START_TIMER", TIMER_TYPE_CHALLENGE_MODE, timeLeft, timeLeft)
		end
	end)
	BigWigsLoader:RegisterMessage("BigWigs_StopBar", function(event, plugin, text)
		if text == ('Pull' or L['Pull']) then
			TimerTracker_OnEvent(TimerTracker, "PLAYER_ENTERING_WORLD")
		end
	end)
end

-- ================================================
ns.RegisterEvent('ADDON_LOADED', function(self, event, arg1)
	if arg1 ~= addonName then return end

	CreateCorkButton()
	MovePetBatteFrame(MidgetDB.PetBattleFrameOffset)
	AddUndressButtons()
	FixModelLighting()
	FixMenuBarHeight()
	ShortenLFRNames()
	AddTipTacStyles()
	OutgoingWhisperColor()
	InterfaceOptionsScrolling()
	AddMoreSharedMedia()
	HideUnusableCompareTips()
	InitBigWigsFancyPullTimer()

	hooksecurefunc('LFRBrowseFrameListButton_SetData', AddLFREntryInfo)
	for i = 1, 19 do
		local button = _G['LFRBrowseFrameListButton'..i]
		-- button:HookScript('OnEnter', ShowLFREntryTooltip)
		local tankCount = button:CreateFontString(nil, nil, 'GameFontHighlight')
		      tankCount:SetAllPoints(button.tankIcon)
		button.tankCount = tankCount
		local healerCount = button:CreateFontString(nil, nil, 'GameFontHighlight')
		      healerCount:SetAllPoints(button.healerIcon)
		button.healerCount = healerCount
		local damageCount = button:CreateFontString(nil, nil, 'GameFontHighlight')
		      damageCount:SetAllPoints(button.damageIcon)
		button.damageCount = damageCount
	end

	-- SLASH_ROLECHECK1 = "/rolecheck"
	-- SlashCmdList.ROLECHECK = InitiateRolePoll

	ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", AddLootIcons)

	-- hooksecurefunc('SelectGossipOption', AutoAcceptPopup)
	hooksecurefunc('StaticPopup_Show', AutoAcceptPopup)
	-- for i=1,4 do _G["StaticPopup"..i]:HookScript("OnShow", AutoAcceptPopup) end

	--[[ for _, tooltip in pairs({ GameTooltip, ItemRefTooltip,
		ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3,
		ItemRefShoppingTooltip1, ItemRefShoppingTooltip2, ItemRefShoppingTooltip3 }) do

		hooksecurefunc(tooltip, "SetHyperlink", AddTooltipID)
		tooltip:HookScript("OnTooltipSetItem",  AddTooltipID)
		tooltip:HookScript("OnTooltipSetSpell", AddTooltipID)
	end --]]

	-- add "Show in pet journal" dropdown entry
	-- hooksecurefunc("UnitPopup_HideButtons", CustomizeDropDowns)
	-- table.insert(UnitPopupMenus["TARGET"], #UnitPopupMenus["TARGET"], "PET_SHOW_IN_JOURNAL")

	ns.UnregisterEvent('ADDON_LOADED', 'init_functions')
end, 'init_functions')
