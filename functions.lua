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

local function InterfaceOptionsDragging()
	if not addon.db.profile.InterfaceOptionsDragging then return end
	InterfaceOptionsFrame:SetMovable(true)
	InterfaceOptionsFrame:CreateTitleRegion():SetAllPoints(InterfaceOptionsFrameHeader)
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
--  Cork
-- ================================================
local function CreateCorkButton()
	if not addon.db.profile.CorkButton or not IsAddOnLoaded("Cork") then return end

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

-- ================================================
-- Undress button on models!
-- ================================================
function plugin.AddUndressButton(frame)
	local undressButton = CreateFrame("Button", "$parentUndressButton", frame.controlFrame, "ModelControlButtonTemplate")
	undressButton:SetPoint("LEFT", "$parentRotateResetButton", "RIGHT", 0, 0)
	undressButton:RegisterForClicks("AnyUp")
	undressButton:SetScript("OnClick", function(self)
		self:GetParent():GetParent():Undress()
		PlaySound("igInventoryRotateCharacter");
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
local function FixModelLighting()
	if not addon.db.profile.modelLighting then return end
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
	-- show for guild events
	--[[
	GameTimeCalendarInvitesTexture:Show()
	GameTimeCalendarInvitesGlow:Show()
	GameTimeFrame.flashInvite = true
	-- self.pendingCalendarInvites = 1337 --]]
end

-- ================================================
function plugin:OnEnable()
	CalendarIconFlash()
	CreateCorkButton()
	AddUndressButtons()
	FixModelLighting()
	FixMenuBarHeight()
	ShortenLFRNames()
	AddTipTacStyles()
	OutgoingWhisperColor()
	InterfaceOptionsScrolling()
	InterfaceOptionsDragging()
	HideUnusableCompareTips()
	ExtendLibItemSearch()

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
	GameTooltip:HookScript('OnEnter', function(self)
		local name, _, _, _, _, _, _, caster, _, _, spellID = UnitAura('player', self:GetID(), self.filter)
	end)
	hooksecurefunc(GameTooltip, 'SetUnitAura', function(self, unit, index, filter)
		local name, _, _, _, _, _, _, caster, _, _, spellID = UnitAura(unit, index, filter)
		if caster and unitNames[caster] then
			self:AddLine(unitNames[caster])
			self:Show()
		end
	end)

	-- SLASH_ROLECHECK1 = "/rolecheck"
	-- SlashCmdList.ROLECHECK = InitiateRolePoll

	-- don't add spacing for closing 'x'
	ItemRefTooltip:SetPadding(0)

	-- allow closing map with 'ESC'
	tinsert(UISpecialFrames, 'WorldMapFrame')
	-- allow opening other panels while map is open
	WorldMapFrame:SetAttribute('UIPanelLayout-area', 'left')

	-- FIXME: doesn't work when triggered by SHIFT+Click
	hooksecurefunc('StaticPopup_Show', AutoAcceptPopup)

	-- guild news tab: allow hyperlink interaction
	addon:LoadWith('Blizzard_GuildUI', function()
		local NEWS_GUILD_ACHIEVEMENT, NEWS_PLAYER_ACHIEVEMENT, NEWS_DUNGEON_ENCOUNTER = 0, 1, 2
		local NEWS_ITEM_LOOTED, NEWS_ITEM_CRAFTED, NEWS_ITEM_PURCHASED = 3, 4, 5
		hooksecurefunc('GuildNewsButton_OnClick', function(self, btn)
			if btn ~= 'LeftButton' or not IsModifiedClick() then return end
			if self.newsType == NEWS_ITEM_LOOTED or self.newsType == NEWS_ITEM_CRAFTED or self.newsType == NEWS_ITEM_PURCHASED then
				local _, _, _, _, itemLink = GetGuildNewsInfo(self.index)
				HandleModifiedItemClick(itemLink)
			elseif self.newsType == NEWS_GUILD_ACHIEVEMENT or self.newsType == NEWS_PLAYER_ACHIEVEMENT then
				local _, _, _, _, _, achievementID = GetGuildNewsInfo(self.index)
				HandleModifiedItemClick(GetAchievementLink(achievementID))
			elseif self.newsType == NEWS_DUNGEON_ENCOUNTER then
				local _, _, _, _, encounterName, encounterID, instanceMapID, displayID = GetGuildNewsInfo(self.index)
				-- GetGuildNewsInfo(34) => false, false, 2, "Entropie", "Die Eisernen Jungfern", 1695, 1205, 53876, 4, 18, 2, 15, 0
			end
		end)
	end)

	-- addon memory usage on tracking button
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
