local addonName, addon, _ = ...
local plugin = addon:NewModule('HoverTips', 'AceEvent-3.0')

-- GLOBALS: _G,
-- GLOBALS:
-- GLOBALS: hooksecurefunc

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
	if not addon.db.profile.chatHoverTooltips or chatFrame.hoverTipsEnabled then return end
	chatFrame:HookScript('OnHyperlinkClick', OnHyperlinkClick)
	chatFrame:HookScript('OnHyperlinkEnter', OnHyperlinkEnter)
	chatFrame:HookScript('OnHyperlinkLeave', OnHyperlinkLeave)
	chatFrame.hoverTipsEnabled = true
end

-- ----------------------------------------------------

local function LootIcons(self, event, message, ...)
	if not addon.db.profile.chatLinkIcons then return end
	local function Icon(link)
		local texture = GetItemIcon(link)
		return "\124T" .. texture .. ":" .. 12 .. "\124t" .. link
	end
	message = message:gsub("(\124c%x+\124Hitem:.-\124h\124r)", Icon)
	return false, message, ...
end

-- ----------------------------------------------------

function plugin:OnEnable()
	-- item icons
	ChatFrame_AddMessageEventFilter('CHAT_MSG_LOOT', LootIcons)

	-- hover tooltips
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

function plugin:OnDisable()
	ChatFrame_RemoveMessageEventFilter('CHAT_MSG_LOOT', LootIcons)
end
