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
	LSM:Register("border", "Glow", "Interface\\Addons\\Midget\\media\\glow.tga")
	LSM:Register("border", "Double", "Interface\\Addons\\Midget\\media\\double_border.tga")
	LSM:Register("border", "Single Gray", "Interface\\Addons\\Midget\\media\\grayborder.tga")
	LSM:Register("statusbar", "Smooth", "Interface\\Addons\\Midget\\media\\Smooth.tga")
	LSM:Register("statusbar", "TukTex", "Interface\\Addons\\Midget\\media\\TukTexture.tga")
	LSM:Register("font", "Accidental Presidency", "Interface\\Addons\\Midget\\media\\AccidentalPresidency.ttf")
	LSM:Register("font", "Andika Compact", "Interface\\Addons\\Midget\\media\\Andika-Compact.ttf")
	LSM:Register("font", "Andika", "Interface\\Addons\\Midget\\media\\Andika.ttf")
	LSM:Register("font", "Avant Garde", "Interface\\Addons\\Midget\\media\\AvantGarde.ttf")
	LSM:Register("font", "Cibreo", "Interface\\Addons\\Midget\\media\\Cibreo.ttf")
	LSM:Register("font", "DejaWeb", "Interface\\Addons\\Midget\\media\\DejaWeb.ttf")
	LSM:Register("font", "Express", "Interface\\Addons\\Midget\\media\\express.ttf")
	LSM:Register("font", "Futura Medium", "Interface\\Addons\\Midget\\media\\FuturaMedium.ttf")
	LSM:Register("font", "Paralucent", "Interface\\Addons\\Midget\\media\\Paralucent.ttf")
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
	-- see link types here: http://www.townlong-yak.com/framexml/19033/ItemRef.lua#162
	local gameTips = {item = true, spell = true, trade = true, enchant = true, talent = true, glyph = true, achievement = true, unit = true, quest = true, instancelock = true}
	local function OnHyperlinkEnter(self, linkData, link)
		local linkType = linkData:match('^([^:]+)')
		if not linkType then return end

		-- this makes sure all tooltips are anchored here
		GameTooltip:SetOwner(self, 'CURSOR') -- 'ANCHOR_RIGHT')

		if gameTips[linkType] then
			GameTooltip:SetHyperlink(link)
			if linkType == 'item' and GetCVarBool('alwaysCompareItems') and not self:IsEquippedItem() then
				GameTooltip_ShowCompareItem(GameTooltip)
			end
		elseif linkType == 'battlePetAbil' then
			local _, abilityID, maxHealth, power, speed = strsplit(':', linkData)
			         abilityID, maxHealth, power, speed = tonumber(abilityID), tonumber(maxHealth), tonumber(power), tonumber(speed)
			FloatingPetBattleAbility_Show(abilityID, maxHealth, power, speed)
			FloatingPetBattleAbilityTooltip:SetPoint(GameTooltip:GetPoint())
			FloatingPetBattleAbilityTooltip.chatTip = true
		elseif linkType == 'battlepet' then
			local name = string.gsub(string.gsub(link, '^(.*)%[', ''), '%](.*)$', '')
			local _, speciesID, level, breedQuality, maxHealth, power, speed = strsplit(':', linkData)
			         speciesID, level, breedQuality, maxHealth, power, speed = tonumber(speciesID), tonumber(level), tonumber(breedQuality), tonumber(maxHealth), tonumber(power), tonumber(speed)
			BattlePetToolTip_Show(speciesID, level, breedQuality, maxHealth, power, speed, name)
		else
			-- SetItemRef(linkData, link, 'LeftButton', self)
		end
	end
	local function OnHyperlinkLeave()
		GameTooltip:Hide()
		BattlePetTooltip:Hide()
		if FloatingPetBattleAbilityTooltip.chatTip then
			FloatingPetBattleAbilityTooltip.chatTip = nil
			FloatingPetBattleAbilityTooltip:Hide()
		end
	end

	local function InitChatHoverTips(chatFrame)
		if chatFrame.hoverTipsEnabled then return end
		chatFrame:SetScript('OnHyperlinkEnter', OnHyperlinkEnter)
		chatFrame:SetScript('OnHyperlinkLeave', OnHyperlinkLeave)
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

local function InitItemButtonLevels()
	local LibItemUpgrade = LibStub('LibItemUpgradeInfo-1.0')
	-- TODO: use different color scale
	local buttons, colors = {}, { -- 0.55,0.55,0.55 -- gray
		{1 ,0, 0}, 			-- red 			-- worst item
		{1, 0.7, 0}, 		-- orange
		{1, 1, 0}, 			-- yellow
		{0, 1, 0}, 			-- green
		{0, 1, 1}, 			-- lightblue
		{0.2, 0.2, 1}, 		-- blue 		-- base color
		{0, 0.5, 1},		-- darkblue
		{0.7, 0, 1},		-- purple
		{1, 0, 1}, 			-- pink
		{0.9, 0.8, 0.5}, 	-- heirloom
		{1, 1, 1}, 			-- white 		-- best item
	}
	local baseColorIndex, stepSize = math.ceil(#colors/2), 8
	local function GetItemLevelColor(itemLevel)
		local total, equipped = GetAverageItemLevel()
		local levelDiff = math.floor((itemLevel - equipped)/stepSize)
		local color     = colors[baseColorIndex + levelDiff]
			or (levelDiff < 0 and colors[1])
			or (levelDiff > 0 and colors[#colors])
		return unpack(color or colors[baseColorIndex])
	end

	local getItemLink = {
		[PaperDollItemSlotButton_OnEnter]  = function(self)
			return GetInventoryItemLink('player', self:GetID())
		end,
		[ContainerFrameItemButton_OnEnter] = function(self)
			return GetContainerItemLink(self:GetParent():GetID(), self:GetID())
		end,
		[BankFrameItemButton_OnEnter] = function(self)
			return GetInventoryItemLink('player', self:GetInventorySlot())
		end,
	}

	local function HideButtonLevel(self)
		local button = (self.icon or self.Icon) and self or self:GetParent()
		if button and button.itemLevel then
			button.itemLevel:SetText('')
		end
	end

	local function UpdateButtonLevel(self, texture)
		local button = (self.icon or self.Icon) and self or self:GetParent()
		if not button then return end
		if not texture or texture == '' or button.noItemLevel then
			HideButtonLevel(button)
			return
		end

		if not button.itemLevel then
			local iLevel = button:CreateFontString(nil, 'OVERLAY', 'NumberFontNormalSmall')
			      iLevel:SetPoint('TOPLEFT', -2, 1)
			button.itemLevel = iLevel
		end
		button.itemLevel:SetText('')

		local itemLink = button.link or button.hyperLink or button.hyperlink or button.itemlink or button.itemLink
			or (button.item and type(button.item) == 'string' and button.item)
			or (button.hasItem and type(button.hasItem) == 'string' and button.hasItem)
		if not itemLink and button.GetItem then
			itemLink = button:GetItem()
		elseif not itemLink and button.UpdateTooltip then
			-- tooltip scan as last resort
			local itemLinkFunc = getItemLink[button.UpdateTooltip]
			if itemLinkFunc then
				itemLink = itemLinkFunc(button)
			elseif not GameTooltip:IsShown() then
				button:UpdateTooltip()
				_, itemLink = GameTooltip:GetItem()
				GameTooltip:Hide()
			end
		end

		if itemLink then
			local _, _, quality, itemLevel, _, _, _, _, equipSlot = GetItemInfo(itemLink)
			if itemLevel and itemLevel > 1 and equipSlot ~= '' and equipSlot ~= 'INVTYPE_BAG' then
				-- local r, g, b = GetItemQualityColor(quality)
				itemLevel = LibItemUpgrade:GetUpgradedItemLevel(itemLink) or itemLevel
				button.itemLevel:SetText(itemLevel)
				button.itemLevel:SetTextColor(GetItemLevelColor(itemLevel))
			end
		end
	end

	function UpdateButtonLevels()
		for _, button in pairs(buttons) do
			UpdateButtonLevel(button, true)
		end
	end
	plugin:RegisterEvent('PLAYER_AVG_ITEM_LEVEL_UPDATE', UpdateButtonLevels)

	hooksecurefunc('SetItemButtonTexture', UpdateButtonLevel)
	hooksecurefunc('BankFrameItemButton_Update', function(self) UpdateButtonLevel(self, true) end)
	hooksecurefunc('EquipmentFlyout_DisplayButton', UpdateButtonLevel)
	hooksecurefunc('EquipmentFlyout_DisplaySpecialButton', HideButtonLevel)

	local function AddButton(button)
		local icon = button and (button.icon or button.Icon)
		if not button or not icon then return end
		if button.SetTexture then hooksecurefunc(button, 'SetTexture', UpdateButtonLevel) end
		if icon.SetTexture   then hooksecurefunc(icon,   'SetTexture', UpdateButtonLevel) end
		hooksecurefunc(button, 'Hide', HideButtonLevel)
		hooksecurefunc(icon,   'Hide', HideButtonLevel)
		table.insert(buttons, button)
	end

	hooksecurefunc('CreateFrame', function(frameType, name, parent, templates, id)
		if frameType:lower() == 'button' and templates and templates:lower():find('itembutton') then
			if not name then return end
			if parent and type(parent) == 'table' then
				name = name:gsub('$parent', parent:GetName() or '')
			end
			AddButton(_G[name])
		end
	end)

	-- HACK: registering ADDON_LOADED within OnEnable does not work, so we register 1s later
	local function AddVoidStorageCallback()
		if not IsAddOnLoaded('Blizzard_VoidStorageUI') then
			plugin:RegisterEvent('ADDON_LOADED', function(event, arg1, ...)
				if arg1 == 'Blizzard_VoidStorageUI' then
					plugin:UnregisterEvent(event)
					AddVoidStorageCallback()
				end
			end)
			return
		end
		-- now, void storage is definitely loaded
		AddButton(_G.VoidStorageStorageButton1)
		getItemLink[VoidStorageItemButton_OnEnter] = function(self)
			if not self.hasItem then return end
			local itemID = GetVoidItemInfo(VoidStorageFrame.page, self.slot)
			local itemLink = itemID and select(2, GetItemInfo(itemID))
			return itemLink or itemID
		end
		hooksecurefunc('VoidStorageFrame_Update', UpdateButtonLevels)
	end
	C_Timer.After(1, AddVoidStorageCallback)
end

local function InitGarrisonChanges()
	local plugin = addon:NewModule('Garrison', 'AceEvent-3.0')

	local abilities = {
		ability = {},
		trait = {},
	}
	local function ScanFollowerAbilities()
		wipe(abilities.ability)
		wipe(abilities.trait)
		for index, follower in pairs(C_Garrison.GetFollowers()) do
			if follower.isCollected then
				local color = _G.ITEM_QUALITY_COLORS[follower.quality]
				local label = ('%1$d %2$s%3$s|r'):format(follower.level, RGBTableToColorCode(color), follower.name)

				for abilityIndex, ability in pairs(C_Garrison.GetFollowerAbilities(follower.followerID)) do
					local dataTable = abilities[ability.isTrait and 'trait' or 'ability']
					for _, threat in pairs(ability.counters) do -- '|T%1$s:0|t %2$s'
						local threatLabel = ('%s|%s|%s'):format(threat.icon, threat.name, threat.description)
						if not dataTable[threatLabel] then dataTable[threatLabel] = {} end
						table.insert(dataTable[threatLabel], label)
						table.sort(dataTable[threatLabel])
					end
				end
			end
		end
		return abilities
	end

	local function UpdateFollowerTabs(frame)
		ScanFollowerAbilities()
		local index = 1
		for threat, abilities in pairs(abilities.ability) do
			local tab = frame[index]
			if not tab then
				tab = CreateFrame('CheckButton', nil, frame, 'SpellBookSkillLineTabTemplate', index)
				tab:SetPoint('TOPLEFT', frame, 'TOPRIGHT', 0, 16 - 44*index)
				tab:RegisterForClicks() -- unregister all
				tab:Show()
				local count = tab:CreateFontString(nil, nil, 'NumberFontNormal')
				count:SetPoint('BOTTOMRIGHT', -2, 2)
				tab.count = count
				frame[index] = tab
			end
			local icon, name, description = strsplit('|', threat)
			local followers = table.concat(abilities, '|n')
			tab:SetNormalTexture(icon)
			tab.tooltip = ('|T%1$s:0|t%2$s|n|n%4$s'):format(icon, name, description, followers)
			tab.count:SetText(#abilities)
			index = index + 1
		end
	end
	-- display known abilities when recruiting new followers
	plugin:RegisterEvent('GARRISON_RECRUITMENT_NPC_OPENED', function() UpdateFollowerTabs(GarrisonRecruiterFrame) end)
	plugin:RegisterEvent('GARRISON_MISSION_NPC_OPENED', function() UpdateFollowerTabs(GarrisonMissionFrame) end)

	-- HACK: registering ADDON_LOADED within OnEnable does not work, so we register 1s later
	local function GarrisonLoadedCallback()
		plugin:RegisterEvent('ADDON_LOADED', function(event, arg1, ...)
			if arg1 == 'Blizzard_GarrisonUI' then
				plugin:UnregisterEvent(event)
				plugin:OnEnable()
			end
		end)
	end
	function plugin:OnEnable()
		if not IsAddOnLoaded('Blizzard_GarrisonUI') then
			C_Timer.After(1, GarrisonLoadedCallback)
			return
		end
		-- allow to immediately click the reward chest
		hooksecurefunc('GarrisonMissionComplete_Initialize', function(missionList, index)
			local self = GarrisonMissionFrame.MissionComplete
			self.BonusRewards.ChestModel.Lock:Hide()
			self.BonusRewards.ChestModel:SetAnimation(0, 0)
			self.BonusRewards.ChestModel.ClickFrame:Show()
			self.Stage.EncountersFrame:Hide()
		end)
	end
end

local function CalendarIconFlash()
	-- minimap calendar flashing:
	--[[ GameTimeCalendarInvitesTexture:Show()
	GameTimeCalendarInvitesGlow:Show()
	GameTimeFrame.flashInvite = true
	self.pendingCalendarInvites = 1337 --]]
end

-- ================================================
function plugin:OnEnable()
	InitItemButtonLevels()
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
	InitGarrisonChanges()

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
