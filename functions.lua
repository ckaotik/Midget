local addonName, addon, _ = ...
local plugin = addon:NewModule('Functions', 'AceEvent-3.0')

-- GLOBALS: _G, UIParent, LibStub, TipTac, MidgetDB, CorkFrame, MainMenuBar, InterfaceOptionsFrame, InterfaceOptionsFrameAddOnsList, SLASH_ROLECHECK1, CHAT_CONFIG_CHAT_LEFT, WHISPER, CURRENTLY_EQUIPPED, TIMER_TYPE_CHALLENGE_MODE, SlashCmdList, UnitPopupMenus, UIDROPDOWNMENU_INIT_MENU, StaticPopupDialogs, GameTooltip, ItemRefTooltip, ItemRefShoppingTooltip1, ItemRefShoppingTooltip2, ItemRefShoppingTooltip3, ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3
-- GLOBALS: GameTooltip, PlaySound, GetScreenHeight, ToggleChatMessageGroup, PetBattleFrame, GetLocale, IsListeningForMessageType, CreateFrame, IsAddOnLoaded, ScrollFrameTemplate_OnMouseWheel, InitiateRolePoll, GetItemIcon, ChatFrame_AddMessageEventFilter, IsShiftKeyDown, UnitPopupShown, StaticPopup_Hide, UnitIsBattlePet, TimerTracker, TimerTracker_OnEvent, BigWigsLoader
-- GLOBALS: table, string, math, hooksecurefunc, type, ipairs, pairs

-- ================================================
--  Interface Options Frame
-- ================================================
local function InterfaceOptionsScrolling()
	if not addon.db.profile.InterfaceOptionsScrolling then return end

	local f
	for i = 1, 31 do
		f = _G["InterfaceOptionsFrameAddOnsButton"..i]
		f:EnableMouseWheel(true)
		f:SetScript("OnMouseWheel", function(self, val)
			ScrollFrameTemplate_OnMouseWheel(InterfaceOptionsFrameAddOnsList, val)
		end)
	end
end

-- ================================================
-- 	Whisper (outgoing) Color
-- ================================================
local function OutgoingWhisperColor()
	if not addon.db.profile.outgoingWhisperColor then return end
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
	if not addon.db.profile.shortenLFRNames then return end
	hooksecurefunc("LFGRewardsFrame_UpdateFrame", function(frame, raidID, background)
		local title = frame.title:GetText()
		if string.len(title) > 25 then
			frame.title:SetText(string.gsub(title, "%s?(.[\128-\191]*)%S+%s", "%1. "))
		end
	end)
end

-- ================================================
-- ValidateFramePosition with no menu bar
-- ================================================
local function FixMenuBarHeight()
	if not addon.db.profile.menuBarHeight then return end
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
	if not addon.db.profile.TipTacStyles or not IsAddOnLoaded("TipTac") then return end
	-- "Corkboard", "ReagentMaker_tooltipRecipe", "FloatingBattlePetTooltip", "BattlePetTooltip",
	hooksecurefunc("CreateFrame", function(objectType, name, parent, template)
		if objectType ~= 'GameTooltip' then return end
		if name == "ReagentMaker_tooltipRecipe" then
			TipTac:AddModifiedTip(_G[name])
		end
	end)
end

-- ================================================
-- Hide unusable item comparison
-- ================================================
local function HideUnusableCompareTips()
	if not addon.db.profile.hideUnusableCompareTips then return end
	local function HookCompareItems(shoppingtip)
		if not shoppingtip then return end
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

local function EasySurvey()
	if not addon.db.profile.easySurvey then return end
	-- based on GoFish! easy fishing mode
	local button = CreateFrame('Button', 'MidgetEasySurvey', UIParent, 'SecureActionButtonTemplate')
	      button:SetAttribute('type', 'spell')
	      button:SetAttribute('spell', (GetSpellInfo(80451)))
	button:EnableMouse(true)
	button:RegisterForClicks('RightButtonUp')
	button:SetScript('PostClick', ClearOverrideBindings)
	button:Hide()

	local lastClickTime = 0
	WorldFrame:HookScript('OnMouseDown', function(self, btn, down)
		if btn ~= 'RightButton' or not CanScanResearchSite() or InCombatLockdown() or GetNumLootItems() > 0 then
			return
		end
		local clickTime = GetTime() -- need ms precision, time() only provides s
		local clickDiff = clickTime - lastClickTime
		lastClickTime = clickTime

		if clickDiff > 0.05 and clickDiff < 0.25 then
			if IsMouselooking() then MouselookStop() end
			SetOverrideBindingClick(button, true, 'BUTTON2', 'MidgetEasySurvey')
		end
	end)
end

-- ================================================
-- Loot Won counts
-- ================================================
local function LootWonCounts(self, itemLink, quantity, rollType, roll, specID, isCurrency, showFactionBG, lootSource)
	if not isCurrency and quantity and quantity > 1 then
		if not self.Count then
			self.Count = self:CreateFontString(nil, nil, 'NumberFontNormal')
			self.Count:SetSize(52-2, 52-2)
			self.Count:SetPoint('LEFT', 23+1, -2-1)
			self.Count:SetJustifyH('RIGHT')
			self.Count:SetJustifyV('BOTTOM')
		end
		self.Count:SetText(quantity)
	elseif self.Count then
		self.Count:SetText()
	end
end

-- ================================================
-- Merchant Alternative Currency Counts
-- ================================================
local function MerchantAltCurrencyCounts()
	local function MerchantFrame_ShowHyperlinkTooltip(self)
		if self.currencyID ~= 0 then return end
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
		GameTooltip:SetHyperlink(self.link)
	end
	for i = 1, MAX_MERCHANT_CURRENCIES do
		local tokenButton = _G['MerchantToken'..i]
		if not tokenButton then
			tokenButton = CreateFrame('Button', 'MerchantToken'..i, MerchantFrame, 'BackpackTokenTemplate')
			-- token display order is: 6 5 4 | 3 2 1
			if i == 1 then
				tokenButton:SetPoint('BOTTOMRIGHT', -16, 8)
			elseif i == 4 then
				tokenButton:SetPoint('BOTTOMLEFT', 89, 8)
			else
				tokenButton:SetPoint('RIGHT', _G['MerchantToken'..i-1], 'LEFT', 0, 0)
			end
			tokenButton:SetScript('OnEnter', MerchantFrame_ShowCurrencyTooltip)
		end
		tokenButton:HookScript('OnEnter', MerchantFrame_ShowHyperlinkTooltip)
	end

	local merchantCurrencies = {}
	-- collect items used as currency
	MerchantFrame:HookScript('OnShow', function(self)
		wipe(merchantCurrencies)
		for i = 1, GetMerchantNumItems() do
			local _, itemTexture, itemPrice, _, _, _, extendedCost = GetMerchantItemInfo(i)
			if extendedCost then
				for j = 1, GetMerchantItemCostInfo(i) do
					local _, _, link = GetMerchantItemCostItem(i, j)
					if not tContains(merchantCurrencies, link) then
						tinsert(merchantCurrencies, link)
					end
				end
			end
		end
		table.sort(merchantCurrencies)
	end)

	-- display currency counts
	hooksecurefunc('MerchantFrame_UpdateCurrencies', function()
		local index = 1
		for i = 1, MAX_MERCHANT_CURRENCIES do
			local tokenButton = _G['MerchantToken'..i]
			if tokenButton and not tokenButton:IsShown() then
				local link = merchantCurrencies[index]
				if not link then break end
				index = index + 1

				local count = GetItemCount(link)
				tokenButton.icon:SetTexture(GetItemIcon(link))
				tokenButton.count:SetText(count <= 99999 and count or '*')
				tokenButton.currencyID = 0
				tokenButton.link = link
				tokenButton:Show()
			end
		end

		if #merchantCurrencies > 0 then
			MerchantFrame:RegisterEvent('CURRENCY_DISPLAY_UPDATE')
			MerchantExtraCurrencyInset:Show()
			MerchantExtraCurrencyBg:Show()
			if #merchantCurrencies > 3 then
				MerchantMoneyFrame:Hide()
			else
				MerchantMoneyFrame:SetPoint('BOTTOMRIGHT', -169, 8)
				MerchantMoneyFrame:Show()
			end
		end
	end)
end

-- ================================================
-- Undress button on models!
-- ================================================
function plugin.AddUndressButton(frame)
	local undressButton = CreateFrame("Button", "$parentUndressButton", frame.controlFrame, "ModelControlButtonTemplate")
	undressButton:SetPoint("LEFT", "$parentRotateResetButton", "RIGHT", 0, 0)
	undressButton:RegisterForClicks("AnyUp")
	undressButton:SetScript("OnClick", function(self)
		self:GetParent():GetParent():Undress()
		PlaySound(SOUNDKIT.IG_INVENTORY_ROTATE_CHARACTER)
	end)

	undressButton.tooltip = "Undress"
	undressButton.tooltipText = "Completely undress the character model"

	frame.controlFrame:SetWidth(frame.controlFrame:GetWidth() + undressButton:GetWidth())
	frame.controlFrame.undressButton = undressButton
end


local function AddUndressButtons()
	if not addon.db.profile.undressButton then return end
	-- these models are create before we can hook
	for _, name in pairs({"DressUpModel", "SideDressUpModel"}) do
		if not _G[name.."ControlFrameUndressButton"] then
			plugin.AddUndressButton(_G[name])
		end
	end
	hooksecurefunc('Model_OnLoad', function(self)
		if self.controlFrame and not self.controlFrame.undressButton then
			plugin.AddUndressButton(self)
		end
	end)
end

-- ================================================
-- Accept popups on SHIFT
-- ================================================
local openPopup
local function AutoAcceptPopup(which, arg1, arg2, data)
	-- TODO: this fails when popups are triggered by SHIFT+anything
	if not addon.db.profile.SHIFTAcceptPopups then return end
	if type(which) == 'table' then
		data  = which.data
		which = which.which
	end
	local info = StaticPopupDialogs[which]

	if info and which ~= 'DEATH' and IsShiftKeyDown() then
		if info.OnAccept then
			info.OnAccept(nil, data)
		end
		StaticPopup_Hide(which, data)
	end
end

-- ================================================
-- Tooltip Item Specs
-- ================================================
local itemSpecs = {}
local function TooltipItemInfo(self)
	local specs
	local _, itemLink = self:GetItem()
	if not itemLink then return end

	--[[ -- indicate expansion level for reagents
	for i = 1, self:NumLines() do
		local left = _G[self:GetName()..'TextLeft'..i]
		if left:GetText() == _G.PROFESSIONS_USED_IN_COOKING then
			local itemLevel = select(4, GetItemInfo(itemLink))
			if not itemLevel then break end
			local expansion
			for index, maxLevel in pairs(_G.MAX_PLAYER_LEVEL_TABLE) do
				if itemLevel <= maxLevel and (not expansion or index <= expansion) then
					expansion = index
				end
			end
			local expansionName = expansion and EJ_GetTierInfo(expansion + 1)
			if expansionName then
				left:SetFormattedText('%s (%s)', _G.PROFESSIONS_USED_IN_COOKING, expansionName:gsub('(%w)%w*%s*', '%1'))
			end
			break
		end
	end --]]

	wipe(itemSpecs)
	GetItemSpecInfo(itemLink, itemSpecs)
	-- TODO: only show own specializations GetNumSpecializations()
	if #itemSpecs > 4 then return end
	for i, specID in ipairs(itemSpecs) do
		local _, _, _, icon, _, role, class = GetSpecializationInfoByID(specID)
		specs = (specs and specs..' ' or '') .. '|T'..icon..':0|t'
	end
	if not specs then return end

	local text = _G[self:GetName()..'TextRight'..(self:GetName():find('^ShoppingTooltip') and 2 or 1)]
	      text:SetText(specs)
	      text:Show()
end

-- ================================================
--  Extend LibItemSearch
-- ================================================
local function ExtendLibItemSearch()
	local Search = LibStub('CustomSearch-1.0', true)
	local ItemSearch = LibStub('LibItemSearch-1.2', true)
	if not ItemSearch or not Search then return end

	local itemSpecs = {}
	ItemSearch.Filters.spec = {
		tags = {'s', 'spec', 'specialization'},

		canSearch = function(self, _, search)
			return search
		end,

		match = function(self, link, operator, search)
			wipe(itemSpecs)
			GetItemSpecInfo(link, itemSpecs)
			for i, specID in ipairs(itemSpecs) do
				local specID, name, description, icon, bgTex, role, class = GetSpecializationInfoByID(specID)
				if Search:Find(search, name, class, role, tostring(specID)) then return true end
			end
		end
	}
end

local function CalendarIconFlash()
	-- hide for events too far in the future
	-- GameTimeFrame.pendingCalendarInvites = 1337
	-- show for guild events
	-- local numInvites = CalendarGetNumPendingInvites()
	-- local numGuildEvents = CalendarGetNumGuildEvents()
	--[[
	GameTimeCalendarInvitesTexture:Show()
	GameTimeCalendarInvitesGlow:Show()
	GameTimeFrame.flashInvite = true
	-- self.pendingCalendarInvites = 1337 --]]
end

-- ================================================
-- Display addon memory usage on tracking button.
-- ================================================
local function AddOnMemoryUsage()
	local addonMemoryUsage, addonOrder = {}, {}
	local function SortByMemoryUsage(a, b) return addonMemoryUsage[a] > addonMemoryUsage[b] end
	local function FormatMemory(value) return value > 999 and format('%.1f MB', value / 1024) or format('%.1f KB', value) end

	MiniMapTrackingButton:HookScript('OnEnter', function(self)
		GameTooltip:SetOwner(self, 'ANCHOR_BOTTOMLEFT', 0, self:GetHeight())

		local addonUsage = 0
		wipe(addonMemoryUsage)
		wipe(addonOrder)

		UpdateAddOnMemoryUsage()
		for index = 1, GetNumAddOns() do
			if IsAddOnLoaded(index) then
				local usage, folderName = GetAddOnMemoryUsage(index), GetAddOnInfo(index)
				addonMemoryUsage[folderName] = usage
				table.insert(addonOrder, folderName)
				addonUsage = addonUsage + usage
			end
		end

		GameTooltip:AddLine('Memory Usage')
		GameTooltip:AddDoubleLine('User Addons:', FormatMemory(addonUsage))
		GameTooltip:AddDoubleLine('Blizzard:', FormatMemory(gcinfo() - addonUsage))
		GameTooltip:AddLine(' ')

		table.sort(addonOrder, SortByMemoryUsage)
		for _, folderName in pairs(addonOrder) do
			local usage  = addonMemoryUsage[folderName] or 0
			local author = GetAddOnMetadata(folderName, 'author') or _G.UNKNOWN
			local title  = GetAddOnMetadata(folderName, 'title') or folderName
			local label  = ('%s %s%s'):format(title, _G.GRAY_FONT_COLOR_CODE, author:match('%w+'))
			GameTooltip:AddDoubleLine(_G.HIGHLIGHT_FONT_COLOR_CODE .. label, FormatMemory(usage))
		end
		GameTooltip:Show()
	end)
	MiniMapTrackingButton:HookScript('OnLeave', function(self)
		GameTooltip:SetClampedToScreen(true)
		GameTooltip:Hide()
	end)
	MiniMapTrackingButton:RegisterForClicks('AnyUp')
	MiniMapTrackingButton:HookScript('OnClick', function(self, btn)
		if btn == 'RightButton' then
			CloseDropDownMenus()
			local memoryUsage = collectgarbage('count')
			collectgarbage('collect')
			print('Collected garbage:', FormatMemory(memoryUsage - collectgarbage('count')))
		end
		GameTooltip:Hide()
	end)
	MiniMapTrackingButton:EnableMouseWheel()
	MiniMapTrackingButton:SetScript('OnMouseWheel', function(self, direction)
		GameTooltip:SetClampedToScreen(false)
		local from, anchor, to, x, y = GameTooltip:GetPoint()
		local diff = IsShiftKeyDown() and 30 or 15
		if direction < 0 then
			GameTooltip:SetPoint(from, anchor, to, x, y + diff)
		else
			GameTooltip:SetPoint(from, anchor, to, x, y - diff)
		end
	end)
end

-- ================================================
-- Add available counter summary to garrison ui.
-- ================================================
local function GarrisonThreatCounterSummary(frame)
	local threatCounters = CreateFrame('Frame', nil, frame.FollowerTab, 'GarrisonThreatCountersFrameTemplate')

	local tooltipText = '%d |4follower:followers; for |cffffffff%s|r.'
	GarrisonThreatCountersFrame_OnLoad(threatCounters, frame.followerTypeID, tooltipText)

	-- Override icons and labels.
	local counters = C_Garrison.GetFollowerAbilityCountersForMechanicTypes(frame.followerTypeID)
	local mechanics = C_Garrison.GetAllEncounterThreats(frame.followerTypeID)
	table.sort(mechanics, function(m1, m2) return strcmputf8i(m1.name, m2.name) > 0; end)

	local buttons = {}
	for index, info in pairs(mechanics) do
		local button = threatCounters.ThreatsList[index]
		if info.id <= 10 then
			-- Ignore basic garrison threats.
			button:Hide()
		elseif info.icon == 1357797 then
		-- elseif counters[info.id] then
			-- Replace specialization threats with counters
			local counter = counters[info.id]
			button.name = counter.name
			button.Icon:SetTexture(counter.icon)
			button:SetPoint('RIGHT', buttons[#buttons], 'LEFT', -14, 0)
			table.insert(buttons, button)
		else
			-- Use the rest as-is.
			button:SetPoint('RIGHT', buttons[#buttons], 'LEFT', -14, 0)
			table.insert(buttons, button)
		end
	end
	-- minions: C_Garrison.GetClassSpecCategoryInfo(frame.followerTypeID)
	buttons[1]:SetPoint('TOPRIGHT', 0, 7)
	wipe(threatCounters.ThreatsList)
	threatCounters.ThreatsList = buttons
	threatCounters:SetPoint('TOPRIGHT', -12, 30)
	threatCounters:Show()
end

-- ================================================
function plugin:OnEnable()
	CalendarIconFlash()
	AddUndressButtons()
	FixMenuBarHeight()
	ShortenLFRNames()
	AddTipTacStyles()
	OutgoingWhisperColor()
	InterfaceOptionsScrolling()
	HideUnusableCompareTips()
	ExtendLibItemSearch()
	EasySurvey()
	MerchantAltCurrencyCounts()
	AddOnMemoryUsage()

	hooksecurefunc('LootWonAlertFrame_SetUp', LootWonCounts)

	for _, tipName in pairs({'GameTooltip', 'ItemRefTooltip', 'ShoppingTooltip1', 'ShoppingTooltip2'}) do
		local tooltip = _G[tipName]
		if tooltip then
			tooltip:HookScript('OnTooltipSetItem', TooltipItemInfo)
		end
	end

	local unitNames = setmetatable({}, { __index = function(t, unit)
		local name = unit and UnitName(unit)
		if not name then return end
		local _, class = UnitClass(unit)
		if not class then return format("Cast by %s", name) end
		local color = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
		if not color then return format("Cast by %s", name) end
		return format("Cast by |cff%02x%02x%02x%s|r", color.r * 255, color.g * 255, color.b * 255, name)
	end })
	hooksecurefunc(GameTooltip, 'SetUnitAura', function(self, unit, index, filter)
		local name, _, _, _, _, _, _, caster, _, _, spellID = UnitAura(unit, index, filter)
		if caster and unitNames[caster] then
			self:AddLine(unitNames[caster])
			self:Show()
		end
	end)

	-- don't add spacing for closing 'x'
	ItemRefTooltip:SetPadding(0, 0)

	-- SLASH_ROLECHECK1 = "/rolecheck"
	-- SlashCmdList.ROLECHECK = InitiateRolePoll

	-- Guild News: Allow hyperlink interaction.
	addon:LoadWith('Blizzard_Communities', function()
		local NEWS_GUILD_ACHIEVEMENT, NEWS_PLAYER_ACHIEVEMENT, NEWS_DUNGEON_ENCOUNTER = 0, 1, 2
		local NEWS_ITEM_LOOTED, NEWS_ITEM_CRAFTED, NEWS_ITEM_PURCHASED = 3, 4, 5

		hooksecurefunc('CommunitiesGuildNewsButton_OnClick', function(self, btn)
			if btn ~= 'LeftButton' or not IsModifiedClick() then return end

			if self.newsType == NEWS_ITEM_LOOTED or self.newsType == NEWS_ITEM_CRAFTED or self.newsType == NEWS_ITEM_PURCHASED then
				local _, _, _, _, itemLink = GetGuildNewsInfo(self.index)
				HandleModifiedItemClick(itemLink)
			elseif self.newsType == NEWS_GUILD_ACHIEVEMENT or self.newsType == NEWS_PLAYER_ACHIEVEMENT then
				local _, _, _, _, _, achievementID = GetGuildNewsInfo(self.index)
				HandleModifiedItemClick(GetAchievementLink(achievementID))
			elseif self.newsType == NEWS_DUNGEON_ENCOUNTER then
				local _, _, _, _, encounterName, encounterID, instanceMapID, displayID = GetGuildNewsInfo(self.index)
			end
		end)
	end)

	addon:LoadWith('Blizzard_GarrisonUI', function()
		local missionFrames = {}
		hooksecurefunc(GarrisonMission, 'OnShowMainFrame', function (self)
			if missionFrames[self] == nil then
				-- Ensure we only initialize once.
				missionFrames[self] = self.followerTypeID

				GarrisonThreatCounterSummary(self)
			end
		end)
	end)

	addon:LoadWith('Bazooka', function()
		-- GLOBALS: Bazooka
		-- Move when other top-anchored elements are moved.
		hooksecurefunc('UIParent_UpdateTopFramePositions', function()
			local _, _, _, _, newYOffset = _G.BuffFrame:GetPoint()
			for i, bar in pairs(Bazooka.bars) do
				local point, anchor, otherPoint, x, y = bar.frame:GetPoint()
				if otherPoint:find('TOP') then
					bar.frame:SetPoint(point, anchor, otherPoint, x, bar.db.y + newYOffset + 12)
				end
			end
		end)
	end)

	addon:LoadWith('Dominos_Cast', function()
		local plugin = LibStub('AceAddon-3.0'):GetAddon('Dominos'):GetModule('CastBar')
		local frame = plugin.frame
		local targetCast = frame:New('ctarget', 'target')
	end)

	addon:LoadWith('Squeenix', function()
		-- GLOBALS: SqueenixDB2
		local db = SqueenixDB2

		-- Move when other top-anchored elements are moved.
		local _, _, _, origX, origY = _G.Minimap:GetPoint()
		hooksecurefunc('UIParent_UpdateTopFramePositions', function()
			local _, _, _, _, newYOffset = _G.BuffFrame:GetPoint()

			local point, anchor, otherPoint, x, y = _G.MinimapCluster:GetPoint()
			if point == 'TOPRIGHT' then
				_G.MinimapCluster:SetPoint(point, anchor, otherPoint, x, newYOffset)
			end

			local point, anchor, otherPoint, x, y = _G.Minimap:GetPoint()
			local zoneTextHeight = _G.MinimapZoneTextButton:IsVisible() and _G.MinimapZoneTextButton:GetHeight() + 5 or 0
			if point == 'CENTER' then
				_G.Minimap:SetPoint('CENTER', db.anchorframe or 'MinimapCluster', db.anchor or 'TOP', db.x or 9, (db.y or -92) + newYOffset + zoneTextHeight)
			end
		end)
	end)
end
