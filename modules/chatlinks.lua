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
local function OnHyperlinkEnter(self, linkData, link, acceptModifiers)
	local linkType = addon.GetLinkData(link)
	if not linkType or not linkTypes[linkType] then return end
	if IsModifiedClick() and not acceptModifiers then return end

	local tipName = linkTypes[linkType] == true and 'ItemRefTooltip' or linkTypes[linkType]
	local tooltip = _G[tipName]
	ChatFrame_OnHyperlinkShow(self, linkData, link, 'LeftButton')

	tooltip:ClearAllPoints()
	GameTooltip:SetOwner(self, 'CURSOR')
	tooltip:SetPoint(GameTooltip:GetPoint())
	hoverTip = link
end
local function OnHyperlinkLeave(self, linkData, link)
	local linkType = addon.GetLinkData(link)
	if not hoverTip or hoverTip ~= link or not linkType or not linkTypes[linkType] then return end
	local tipName = linkTypes[linkType] == true and 'ItemRefTooltip' or linkTypes[linkType]
	_G[tipName]:Hide()
end
local function OnHyperlinkClick(self, linkData, link, btn)
	-- do not close popups that were intentionally shown
	if hoverTip and hoverTip == link then
		-- OnEnter (=> custom handler will toggle on) > OnClick (=> default handler will toggle off) > show again
		OnHyperlinkEnter(self, linkData, link, true)
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
local function AddIconPrefix(link)
	local texture = GetItemIcon(link)
	return "\124T" .. texture .. ":" .. 12 .. "\124t" .. link
end

local function LootIcons(self, event, message, ...)
	if not addon.db.profile.chatLinkIcons then return end
	message = message:gsub("(\124c%x+\124Hitem:.-\124h\124r)", AddIconPrefix)
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

	-- ItemRef comparison tooltips
	ItemRefTooltip:HookScript('OnUpdate', function(tooltip)
		if IsModifiedClick('COMPAREITEMS') or GetCVar('alwaysCompareItems') then
			if not tooltip.comparing then
				GameTooltip_ShowCompareItem(tooltip, 1)
			end
			tooltip.comparing = true
		else
			tooltip.comparing = false
		end
	end)

	hooksecurefunc('ChatFrame_OnHyperlinkShow', function(chatFrame, link, text, btn)
		local linkType, linkID, linkData = addon.GetLinkData(link)
		if linkType == 'achievement' and IsModifiedClick('DRESSUP') then
			-- directly open achievement in UI
			-- LoadAddOn('Blizzard_AchievementUI')
			ShowUIPanel(AchievementFrame)
			AchievementFrame_SelectAchievement(linkID)
		end
	end)
end

function plugin:OnDisable()
	ChatFrame_RemoveMessageEventFilter('CHAT_MSG_LOOT', LootIcons)
end
