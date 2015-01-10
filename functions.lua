local addonName, addon, _ = ...
local plugin = addon:NewModule('Functions', 'AceEvent-3.0')

-- GLOBALS: _G, UIParent, LibStub, TipTac, MidgetDB, CorkFrame, MainMenuBar, InterfaceOptionsFrameAddOnsList, SLASH_ROLECHECK1, CHAT_CONFIG_CHAT_LEFT, WHISPER, CURRENTLY_EQUIPPED, TIMER_TYPE_CHALLENGE_MODE, SlashCmdList, UnitPopupMenus, UIDROPDOWNMENU_INIT_MENU, StaticPopupDialogs, GameTooltip, ItemRefTooltip, ItemRefShoppingTooltip1, ItemRefShoppingTooltip2, ItemRefShoppingTooltip3, ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3
-- GLOBALS: GameTooltip, PlaySound, GetScreenHeight, ToggleChatMessageGroup, PetBattleFrame, GetLocale, IsListeningForMessageType, CreateFrame, IsAddOnLoaded, ScrollFrameTemplate_OnMouseWheel, InitiateRolePoll, GetItemIcon, ChatFrame_AddMessageEventFilter, IsShiftKeyDown, UnitPopupShown, StaticPopup_Hide, UnitIsBattlePet, TimerTracker, TimerTracker_OnEvent, BigWigsLoader
-- GLOBALS: table, string, math, hooksecurefunc, type, ipairs, pairs

-- ================================================
-- Shared Media insertions
-- ================================================
local LSM = LibStub("LibSharedMedia-3.0", true)
local function AddMoreSharedMedia()
	if not addon.db.profile.moreSharedMedia or not LSM then return end
	local path = 'Interface\\Addons\\Midget\\media\\'
	LSM:Register("border", "Glow", 			path .. "border\\glow.tga")
	LSM:Register("border", "Inner Glow", 	path .. "border\\inner_glow.tga")
	LSM:Register("border", "Double", 		path .. "border\\double_border.tga")
	LSM:Register("border", "2px", 			path .. "border\\2px.tga")
	LSM:Register("border", "Diablo", 		path .. "border\\diablo.tga")
	LSM:Register("statusbar", "Smooth", 	path .. "statusbar\\Smooth.tga")
	LSM:Register("statusbar", "TukTex", 	path .. "statusbar\\TukTexture.tga")
	LSM:Register("statusbar", "Solid", 		path .. "statusbar\\solid.tga")
	LSM:Register("font", "Andika Compact", 	path .. "Andika-font\\Compact.ttf")
	LSM:Register("font", "Andika", 			path .. "font\\Andika.ttf")
	LSM:Register("font", "Avant Garde", 	path .. "font\\AvantGarde.ttf")
	LSM:Register("font", "Cibreo", 			path .. "font\\Cibreo.ttf")
	LSM:Register("font", "DejaWeb", 		path .. "font\\DejaWeb.ttf")
	LSM:Register("font", "Express", 		path .. "font\\express.ttf")
	LSM:Register("font", "Futura Medium", 	path .. "font\\FuturaMedium.ttf")
	LSM:Register("font", "Paralucent", 		path .. "font\\Paralucent.ttf")
	LSM:Register("font", "Calibri", 		path .. "font\\Calibri.ttf")
	LSM:Register("font", "Calibri Bold", 	path .. "font\\CalibriBold.ttf")
	LSM:Register("font", "Calibri Italic", 	path .. "font\\CalibriItalic.ttf")
	LSM:Register("font", "Calibri Bold Italic", path .. "font\\CalibriBoldItalic.ttf")
	LSM:Register("font", "Accidental Presidency", path .. "font\\AccidentalPresidency.ttf")
end

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
-- Chat link icons
-- ================================================
local function AddLootIcons(self, event, message, ...)
	if not addon.db.profile.chatLinkIcons then return end
	local function Icon(link)
		local texture = GetItemIcon(link)
		return "\124T" .. texture .. ":" .. 12 .. "\124t" .. link
	end
	message = message:gsub("(\124c%x+\124Hitem:.-\124h\124r)", Icon)
	return false, message, ...
end

local function AddChatLinkHoverTooltips()
	if not addon.db.profile.chatHoverTooltips then return end
	local hoverTip = nil
	-- see link types here: http://www.townlong-yak.com/framexml/19033/ItemRef.lua#162
	local linkTypes = {
		item = true, spell = true, enchant = true, talent = true, glyph = true, achievement = true, unit = true, quest = true, instancelock = true, trade = false, -- GameTooltip / ItemRefTooltip
		battlepet           = 'FloatingBattlePetTooltip',
		battlePetAbil       = 'FloatingPetBattleAbilityTooltip',
		garrfollower        = 'FloatingGarrisonFollowerTooltip',
		garrfollowerability = 'FloatingGarrisonFollowerAbilityTooltip',
		garrmission         = 'FloatingGarrisonMissionTooltip',
	}
	local function OnHyperlinkEnter(self, linkData, link)
		if IsModifiedClick() then return end
		local linkType = linkData:match('^([^:]+)')
		if not linkType or not linkTypes[linkType] then return end
		local tooltip = linkTypes[linkType] == true and 'ItemRefTooltip' or linkTypes[linkType]
		-- show special frames only with modifiers
		ChatFrame_OnHyperlinkShow(self, linkData, link, 'LeftButton')
		_G[tooltip]:ClearAllPoints()
		GameTooltip:SetOwner(self, 'CURSOR')
		_G[tooltip]:SetPoint(GameTooltip:GetPoint())
		hoverTip = link
	end
	local function OnHyperlinkLeave(self, linkData, link)
		local linkType = linkData:match('^([^:]+)')
		if not hoverTip or hoverTip ~= link or not linkType or not linkTypes[linkType] then return end
		local tooltip = linkTypes[linkType] == true and 'ItemRefTooltip' or linkTypes[linkType]
		_G[tooltip]:Hide()
	end
	local function OnHyperlinkClick(self, linkData, link, btn)
		-- do not close popups that were intentionally shown
		if hoverTip and hoverTip == link then
			-- OnEnter (=> toggle on) > OnClick (=> toggle off) > OnEnter (=> toggle on)
			OnHyperlinkEnter(self, linkData, link)
			hoverTip = nil
		end
	end

	local function InitChatHoverTips(chatFrame)
		if chatFrame.hoverTipsEnabled then return end
		chatFrame:HookScript('OnHyperlinkClick', OnHyperlinkClick)
		chatFrame:HookScript('OnHyperlinkEnter', OnHyperlinkEnter)
		chatFrame:HookScript('OnHyperlinkLeave', OnHyperlinkLeave)
		chatFrame.hoverTipsEnabled = true
	end
	for i = 1, _G.NUM_CHAT_WINDOWS do
		InitChatHoverTips(_G['ChatFrame'..i])
	end
	-- hooksecurefunc('FloatingChatFrame_Update', function(index) InitChatHoverTips(_G['ChatFrame'..index]) end)
	hooksecurefunc('FCF_OpenTemporaryWindow', function(chatType)
		for _, frameName in pairs(_G.CHAT_FRAMES) do
			InitChatHoverTips(_G[frameName])
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
	undressButton.tooltipText = "Click to completely undress this character!"

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

-- apply basic Masque styles to LibSpellWidget frames
local function AddMasque()
	local LibMasque       = LibStub('Masque', true)
	local LibSpellWidget  = LibStub('LibSpellWidget-1.0', true)
	local LibPlayerSpells = LibStub('LibPlayerSpells-1.0', true)
	if not LibMasque or not LibSpellWidget then return end

	local COOLDOWN, IMPORTANT = LibPlayerSpells.constants.COOLDOWN, LibPlayerSpells.constants.IMPORTANT
	local SURVIVAL, BURST = LibPlayerSpells.constants.SURVIVAL, LibPlayerSpells.constants.BURST
	local MANA_REGEN, POWER_REGEN = LibPlayerSpells.constants.MANA_REGEN, LibPlayerSpells.constants.POWER_REGEN

	hooksecurefunc(LibSpellWidget.proto, 'SetSpell', function(self, spell)
		if not spell then return end

		if LibPlayerSpells then
			local flags = LibPlayerSpells:GetSpellInfo(spell)
			if not flags then
				self.Border:Hide()
			elseif bit.band(flags, BURST) > 0 then
				self.Border:SetVertexColor(0, 1, 0, 1)
				self.Border:Show()
			elseif bit.band(flags, SURVIVAL) > 0 then
				self.Border:SetVertexColor(1, 0, 0, 1)
				self.Border:Show()
			elseif bit.band(flags, MANA_REGEN) > 0 or bit.band(flags, POWER_REGEN) > 0 then
				self.Border:SetVertexColor(0, 0, 1, 1)
				self.Border:Show()
			elseif bit.band(flags, COOLDOWN) > 0 or bit.band(flags, IMPORTANT) > 0 then
				self.Border:SetVertexColor(.5, 0, .5, 1)
				self.Border:Show()
			else
				self.Border:Hide()
			end
		end

		LibMasque:Group('LibSpellWidget'):ReSkin()
	end)
	LibSpellWidget.proto.SetNormalTexture = function(self) end
	LibSpellWidget.proto.GetNormalTexture = function(self) return self.Normal end

	local Create = LibSpellWidget.Create
	function LibSpellWidget:Create()
		-- create widget as usual
		local widget = Create(self)

		local border = widget:CreateTexture(nil, 'OVERLAY')
		      border:SetTexture('Interface\\Buttons\\UI-ActionButton-Border')
		      border:SetAllPoints()
		      border:Hide()
		widget.Border = border

		local normal = widget:CreateTexture(nil, 'BACKGROUND')
		      normal:SetTexture('Interface\\Buttons\\UI-Quickslot2')
		      normal:SetAllPoints()
		widget.Normal = normal

		-- now apply Masque to it
		LibMasque:Group('LibSpellWidget'):AddButton(widget, {
			Icon         = widget.Icon,
			Cooldown     = widget.Cooldown,
			Count        = widget.Count,
			Normal       = widget.Normal,
			Border       = widget.Border,

			-- don't try to find these textures
			Pushed       = false,
			Disabled     = false,
			Checked      = false,
			FloatingBG   = false,
			Flash        = false,
			AutoCastable = false,
			Highlight    = false,
			HotKey       = false,
			Name         = false,
		    Duration     = false,
			AutoCast     = false,
		})

		return widget
	end
end

local function CalendarIconFlash()
	-- minimap calendar flashing:
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
	AddMoreSharedMedia()
	HideUnusableCompareTips()
	ExtendLibItemSearch()
	AddMasque()

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

	ChatFrame_AddMessageEventFilter('CHAT_MSG_LOOT', AddLootIcons)
	AddChatLinkHoverTooltips()

	-- FIXME: doesn't work when triggered by SHIFT+Click
	hooksecurefunc('StaticPopup_Show', AutoAcceptPopup)
end
