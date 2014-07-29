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
	LSM:Register("border", "Double", "Interface\\Addons\\Midget\\media\\double_border.tga")
	LSM:Register("border", "Single Gray", "Interface\\Addons\\Midget\\media\\grayborder.tga")
	LSM:Register("font", "Accidental Presidency", "Interface\\Addons\\Midget\\media\\AccidentalPresidency.ttf")
	LSM:Register("font", "Andika Compact", "Interface\\Addons\\Midget\\media\\Andika-Compact.ttf")
	LSM:Register("font", "Andika", "Interface\\Addons\\Midget\\media\\Andika.ttf")
	LSM:Register("font", "Avant Garde", "Interface\\Addons\\Midget\\media\\AvantGarde.ttf")
	LSM:Register("font", "Cibreo", "Interface\\Addons\\Midget\\media\\Cibreo.ttf")
	LSM:Register("font", "Express", "Interface\\Addons\\Midget\\media\\express.ttf")
	LSM:Register("font", "Futura Medium", "Interface\\Addons\\Midget\\media\\FuturaMedium.ttf")
	LSM:Register("font", "Paralucent", "Interface\\Addons\\Midget\\media\\Paralucent.ttf")
	LSM:Register("statusbar", "Smooth", "Interface\\Addons\\Midget\\media\\Smooth.tga")
	LSM:Register("statusbar", "TukTex", "Interface\\Addons\\Midget\\media\\TukTexture.tga")
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
		hooksecurefunc("CreateFrame", function(objectType, name, parent, template)
			if objectType ~= 'GameTooltip' then return end
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

-- ================================================
--  BigWigs customization
-- ================================================
local function SetupBigWigs()
	if not IsAddOnLoaded("BigWigs_Plugins") then
		ns.RegisterEvent("ADDON_LOADED", function(self, event, addon)
			if addon == "BigWigs_Plugins" then
				ns.UnregisterEvent("ADDON_LOADED", "bigwigs_fancypull")
				SetupBigWigs()
			end
		end, "bigwigs_fancypull")

		return
	end

	-- Fancy BigWigs pull timer, like those in challenge modes
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

	-- Custom BigWigs bar style
	local bars = BigWigs:GetPlugin("Bars", true)
	if bars then
		local inset = 0
		local backdropBorder = {
			bgFile = "Interface\\Buttons\\WHITE8X8",
			edgeFile = "Interface\\Buttons\\WHITE8X8",
			-- edgeFile = LSM:Fetch('border', 'Single Gray'),
			tile = false, tileSize = 0, edgeSize = 1,
			insets = {left = inset, right = inset, top = inset, bottom = inset}
		}

		local conf = bars.db.profile
		bars:RegisterBarStyle('ckaotik', {
			apiVersion = 1,
			version = 1,
			GetSpacing = function(bar) return 20 end,
			ApplyStyle = function(bar)
				if conf.icon then
					local icon = bar.candyBarIconFrame
					local iconTexture = icon.icon
					bar:Set("bigwigs:restoreicon", iconTexture)
					bar:SetIcon(nil)

					icon:SetTexture(iconTexture)
					icon:ClearAllPoints()
					icon:SetPoint('BOTTOMRIGHT', bar, 'BOTTOMLEFT', -4, 0)
					icon:SetSize(18, 18)
					icon:Show()

					local iconBd = bar.candyBarIconFrameBackdrop
					iconBd:SetBackdrop(backdropBorder)
					iconBd:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
					iconBd:SetBackdropBorderColor(0, 0, 0, 1)

					iconBd:ClearAllPoints()
					iconBd:SetPoint('TOPLEFT', icon, 'TOPLEFT', -1, 1)
					iconBd:SetPoint('BOTTOMRIGHT', icon, 'BOTTOMRIGHT', 1, -1)
					iconBd:Show()
				end

				bar:SetTexture(LSM:Fetch('statusbar', conf.texture))
				bar:SetHeight(4)

				local duration = bar.candyBarDuration
				if conf.time then
					duration:SetJustifyH('RIGHT')
					duration:ClearAllPoints()
					duration:SetPoint('BOTTOMRIGHT', bar, 'TOPRIGHT', 0, 2)
				end

				local label = bar.candyBarLabel
				label:SetJustifyH(conf.align)
				label:ClearAllPoints()
				label:SetPoint('BOTTOMLEFT', bar, 'TOPLEFT', 0, 2)
				if conf.time then
					label:SetPoint('BOTTOMRIGHT', duration, 'BOTTOMLEFT', -2, 0)
				else
					label:SetPoint('BOTTOMRIGHT', bar, 'TOPRIGHT', -2, 2)
				end

				local bd = bar.candyBarBackdrop
				bd:ClearAllPoints()
				bd:SetPoint('TOPLEFT', -1, 1)
				bd:SetPoint('BOTTOMRIGHT', 1, -1)
				bd:SetBackdrop(backdropBorder)
				bd:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
				bd:SetBackdropBorderColor(0, 0, 0, 1)
				bd:Show()
			end,
			BarStopped = function(bar)
				bar:SetHeight(14)
				bar.candyBarBackdrop:Hide()

				local tex = bar:Get("bigwigs:restoreicon")
				if tex then
					local icon = bar.candyBarIconFrame
					icon:ClearAllPoints()
					icon:SetPoint("TOPLEFT")
					icon:SetPoint("BOTTOMLEFT")
					bar:SetIcon(tex)

					bar.candyBarIconFrameBackdrop:Hide()
				end

				bar.candyBarDuration:ClearAllPoints()
				bar.candyBarDuration:SetPoint("RIGHT", bar.candyBarBar, "RIGHT", -2, 0)

				bar.candyBarLabel:ClearAllPoints()
				bar.candyBarLabel:SetPoint("LEFT", bar.candyBarBar, "LEFT", 2, 0)
				bar.candyBarLabel:SetPoint("RIGHT", bar.candyBarBar, "RIGHT", -2, 0)
			end,
			GetStyleName = function() return 'ckaotik' end,
		})
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

-- ================================================
ns.RegisterEvent('ADDON_LOADED', function(self, event, arg1)
	if arg1 ~= addonName then return end

	CreateCorkButton()
	AddUndressButtons()
	FixModelLighting()
	FixMenuBarHeight()
	ShortenLFRNames()
	AddTipTacStyles()
	OutgoingWhisperColor()
	InterfaceOptionsScrolling()
	AddMoreSharedMedia()
	HideUnusableCompareTips()
	SetupBigWigs()
	ExtendLibItemSearch()

	-- SLASH_ROLECHECK1 = "/rolecheck"
	-- SlashCmdList.ROLECHECK = InitiateRolePoll

	-- move the options panel!
	InterfaceOptionsFrame:SetMovable(true)
	InterfaceOptionsFrame:CreateTitleRegion():SetAllPoints(InterfaceOptionsFrameHeaderText)

	ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", AddLootIcons)
	hooksecurefunc('StaticPopup_Show', AutoAcceptPopup)

	ns.UnregisterEvent('ADDON_LOADED', 'init_functions')
end, 'init_functions')
