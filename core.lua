local addonName, ns, _ = ...

-- GLOBALS: _G, LibStub, Midget, MidgetDB, MidgetLocalDB, TipTac, UIParent, CorkFrame, MainMenuBar, InterfaceOptionsFrameAddOnsList, SLASH_ROLECHECK1, DEFAULT_CHAT_FRAME, CHAT_CONFIG_CHAT_LEFT, WHISPER, SlashCmdList, UnitPopupMenus, UIDROPDOWNMENU_INIT_MENU, StaticPopupDialogs, STATICPOPUP_NUMDIALOGS
-- GLOBALS: GameTooltip, PlaySound, GetScreenHeight, ToggleChatMessageGroup, PetBattleFrame, GetLocale, IsListeningForMessageType, CreateFrame, IsAddOnLoaded, ScrollFrameTemplate_OnMouseWheel, hooksecurefunc, InitiateRolePoll, GetItemIcon, ChatFrame_AddMessageEventFilter, IsShiftKeyDown, UnitPopupShown, StaticPopup_Hide, UnitIsBattlePet
-- GLOBALS: table, string, math

local split, find, gmatch, lower, join, gsub, length, tonumber, tostringall, format = string.split, string.find, string.gmatch, string.lower, string.join, string.gsub, string.len, tonumber, tostringall, string.format
local abs = math.abs
local assert, type, pairs, ipairs, select, print = assert, type, pairs, ipairs, select, print

-- settings -- TODO: put into ns. so modules can have settings, too
local globalDefaults = {
	tradeskillCosts = false,
	tradeskillLevels = true,
	tradeskillTooltips = true,
	tradeskillCraftedTooltip = false,

	CorkButton = false,
	TipTacStyles = true,
	moreSharedMedia = true,

	movePetBattleFrame = true,
	PetBattleFrameOffset = -16,
	menuBarHeight = true,

	autoCheckSpells = true,
	autocompleteAlts = true,

	undressButton = true,
	modelLighting = true,
	shortenLFRNames = true,
	outgoingWhisperColor = true,
	InterfaceOptionsScrolling = true,
	SHIFTAcceptPopups = true,

	scanGems = false,
}
local localDefaults = {
	trackBattlePetTeams = true,
	trackProfessionSkills = true,
	trackProfession = {},
}

local function UpdateDatabase()
	-- keep database up to date, i.e. remove artifacts + add new options
	if MidgetDB == nil then
		MidgetDB = globalDefaults
	else
		--[[for key,value in pairs(MidgetDB) do
			if globalDefaults[key] == nil then MidgetDB[key] = nil end
		end--]]
		for key,value in pairs(globalDefaults) do
			if MidgetDB[key] == nil then MidgetDB[key] = value end
		end
	end

	if MidgetLocalDB == nil then
		MidgetLocalDB = localDefaults
	else
		--[[for key,value in pairs(MidgetLocalDB) do
			if localDefaults[key] == nil then MidgetLocalDB[key] = nil end
		end--]]
		for key,value in pairs(localDefaults) do
			if MidgetLocalDB[key] == nil then MidgetLocalDB[key] = value end
		end
	end
end

function ns:GetName() return addonName end

local frame, eventHooks = CreateFrame("Frame", "MidgetEventHandler"), {}
local function eventHandler(frame, event, arg1, ...)
	if event == 'ADDON_LOADED' and arg1 == addonName then
		-- make sure we always init before any other module
		ns.Initialize()
		if not eventHooks[event] or ns.Count(eventHooks[event]) < 1 then
			frame:UnregisterEvent(event)
		end
	end

	if eventHooks[event] then
		for id, listener in pairs(eventHooks[event]) do
			listener(frame, event, arg1, ...)
		end
	end
end
frame:SetScript("OnEvent", eventHandler)
frame:RegisterEvent("ADDON_LOADED")

function ns.RegisterEvent(event, callback, id, silentFail)
	assert(callback and event and id, format("Usage: RegisterEvent(event, callback, id[, silentFail])"))
	if not eventHooks[event] then
		eventHooks[event] = {}
		frame:RegisterEvent(event)
	end
	assert(silentFail or not eventHooks[event][id], format("Event %s already registered by id %s.", event, id))

	eventHooks[event][id] = callback
end
function ns.UnregisterEvent(event, id)
	if not eventHooks[event] or not eventHooks[event][id] then return end
	eventHooks[event][id] = nil
	if ns.Count(eventHooks[event]) < 1 then
		eventHooks[event] = nil
		frame:UnregisterEvent(event)
	end
end

-- ================================================
-- Little Helpers
-- ================================================
function ns.Print(text, ...)
	if ... and text:find("%%") then
		text = format(text, ...)
		elseif ... then
		text = join(", ", tostringall(...))
	end
	DEFAULT_CHAT_FRAME:AddMessage("|cff22CCDDMidget|r "..text)
end

function ns.Debug(...)
  if true then
	ns.Print("! "..join(", ", tostringall(...)))
  end
end

function ns.ShowTooltip(self)
	if self.tiptext then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.tiptext, nil, nil, nil, nil, true)
	end
end
function ns.HideTooltip()
	GameTooltip:Hide()
end
function ns.GetItemID(itemLink)
	if not itemLink or type(itemLink) ~= "string" then return end
	local itemID = gsub(itemLink, ".-Hitem:([0-9]*):.*", "%1")
	return tonumber(itemID)
end
function string.explode(str, seperator, plain, useTable)
	assert(type(seperator) == "string" and seperator ~= "", "Invalid seperator (need string of length >= 1)")
	local t, pos, nexti = useTable or {}, 1, 1
	while true do
		local st, sp = str:find(seperator, pos, plain)
		if not st then break end -- No more seperators found
		if pos ~= st then
			t[nexti] = str:sub(pos, st - 1) -- Attach chars left of current divider
			nexti = nexti + 1
		end
		pos = sp + 1 -- Jump past current divider
	end
	t[nexti] = str:sub(pos) -- Attach chars right of last divider
	return t
end
-- counts table entries. for numerically indexed tables, use #table
function ns.Count(table)
	if not table then return 0 end
	local i = 0
	for _, _ in pairs(table) do
		i = i + 1
	end
	return i
end

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
-- Interface Options Scrolling
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
		if length(title) > 25 then
			frame.title:SetText(gsub(title, "%s?(.[\128-\191]*)%S+%s", "%1. "))
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
			if abs(frame:GetBottom() - MainMenuBar:GetHeight()) < 1 then
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
local function AutoAcceptPopup(self)
	popup = self or openPopup
	if not MidgetDB.SHIFTAcceptPopups or not popup then return end
	if IsShiftKeyDown() then
		if popup.which == "GOSSIP_CONFIRM" and not popup.data then
			-- delay
			openPopup = popup
		else
			StaticPopup_OnClick(popup, 1)
			openPopup = nil
		end
	end
end

-- ================================================
function ns.Initialize()
	UpdateDatabase()

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

	SLASH_ROLECHECK1 = "/rolecheck"
	SlashCmdList.ROLECHECK = InitiateRolePoll

	ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", AddLootIcons)

	hooksecurefunc('SelectGossipOption', AutoAcceptPopup)
	hooksecurefunc('StaticPopup_OnShow', AutoAcceptPopup)
	-- for i=1,4 do _G["StaticPopup"..i]:HookScript("OnShow", AutoAcceptPopup) end

	-- add "Show in pet journal" dropdown entry
	hooksecurefunc("UnitPopup_HideButtons", CustomizeDropDowns)
	table.insert(UnitPopupMenus["TARGET"], #UnitPopupMenus["TARGET"], "PET_SHOW_IN_JOURNAL")

	-- expose us to the world
	Midget = ns
end
