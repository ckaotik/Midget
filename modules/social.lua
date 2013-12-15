local addonName, ns, _ = ...

-- GLOBALS: _G, LibStub, RED_FONT_COLOR_CODE, BATTLENET_FONT_COLOR_CODE, RAID_CLASS_COLORS, CHAT_FLAG_AFK, CHAT_FLAG_DND, BNET_CLIENT_WOW, REMOTE_CHAT, HIGHLIGHT_FONT_COLOR_CODE, GREEN_FONT_COLOR_CODE, NORMAL_FONT_COLOR, FriendsFrame
-- GLOBALS: FillLocalizedClassList, BNGetNumFriends, BNGetFriendInfo, BNGetNumFriendToons, BNGetFriendToonInfo, BNGetFriendIndex, BNGetNumFriendInvites, GetQuestDifficultyColor, GetGuildInfo, GetGuildRosterMOTD, CanEditPublicNote, CanEditOfficerNote, SetGuildRosterSelection, SortGuildRoster, GetNumFriends, GetFriendInfo, GetNumGuildMembers, GetGuildRosterInfo, UnitFactionGroup, UnitInParty, UnitPlayerOrPetInRaid, SetItemRef, StaticPopup_Show, InviteUnit, IsAltKeyDown, IsControlKeyDown, ToggleFriendsFrame, ToggleGuildFrame
-- GLOBALS: pairs, ipairs, tonumber, strsplit, select

local LDB     = LibStub('LibDataBroker-1.1')
local LibQTip = LibStub('LibQTip-1.0')

local playerFaction = UnitFactionGroup("player")
local playerRealm = GetRealmName()
local colorFormat = '|cff%02x%02x%02x%s|r'
local classColors = {}
local icons = {
	-- see BNet_GetClientTexture(client)
	[BNET_CLIENT_WOW]  = '|TInterface\\FriendsFrame\\BattleNet-WoWIcon:0|t',
	[BNET_CLIENT_SC2]  = '|TInterface\\FriendsFrame\\BattleNet-SC2Icon:0|t',
	[BNET_CLIENT_D3]   = '|TInterface\\FriendsFrame\\BattleNet-D3Icon:0|t',
	[BNET_CLIENT_WTCG] = '|TInterface\\FriendsFrame\\BattleNet-WTCGIcon:0|t',
	['NONE']           = '|TInterface\\FriendsFrame\\BattleNet-BattleNetIcon:0|t',
	[CHAT_FLAG_AFK]    = '|TInterface\\FriendsFrame\\StatusIcon-Away:0|t',
	[CHAT_FLAG_DND]    = '|TInterface\\FriendsFrame\\StatusIcon-DnD:0|t',
	['REMOTE']         = '|TInterface\\ChatFrame\\UI-ChatIcon-ArmoryChat:0|t',
	['BROADCAST']      = '|TInterface\\FriendsFrame\\BroadcastIcon:0|t',
	['NOTE']           = '|TInterface\\FriendsFrame\\UI-FriendsFrame-Note:0|t',
	['CONTACT']        = '|TInterface\\FriendsFrame\\UI-Toast-FriendOnlineIcon:0|t',
}

local function OnLDBEnter() end
local function SortGuildList(self, sortType, btn, up)
	SortGuildRoster(sortType)
	OnLDBEnter()
end

local function OnCharacterClick(self, character, btn, up)
	local contactType, contactInfo = strsplit(":", character)
	if IsAltKeyDown() then
		-- invite
		if contactType == 'bnet' then
			-- contactInfo contains presenceID
			local friendIndex = BNGetFriendIndex(contactInfo)
			contactInfo = nil

			local toonName, realmName, faction, client
			for toonIndex = 1, BNGetNumFriendToons(friendIndex) do
				_, toonName, client, realmName, _, faction = BNGetFriendToonInfo(friendIndex, toonIndex)
				if client == BNET_CLIENT_WOW and faction == playerFaction then
					contactInfo = toonName .. '-' .. realmName
					break
				end
			end
		end
		if contactInfo and contactInfo ~= '' then
			InviteUnit(contactInfo)
		end
	elseif IsControlKeyDown() then
		-- edit notes
		if contactType == 'guild' then
			for index = 1, select(3, GetNumGuildMembers()) do
				local name = GetGuildRosterInfo(index)
				if name == contactInfo then
					SetGuildRosterSelection(index)
					break
				end
			end
			if btn == 'RightButton' and CanEditOfficerNote() then
				StaticPopup_Show("SET_GUILDOFFICERNOTE")
			elseif CanEditPublicNote() then
				StaticPopup_Show("SET_GUILDPLAYERNOTE")
			end
		elseif contactType == 'friend' then
			for index = 1, select(2, GetNumFriends()) do
				local name = GetFriendInfo(index)
				if name == contactInfo then
					FriendsFrame.NotesID = index
					break
				end
			end
			StaticPopup_Show("SET_FRIENDNOTE", GetFriendInfo(FriendsFrame.NotesID))
		elseif contactType == 'bnet' then
			FriendsFrame.NotesID = contactInfo
			StaticPopup_Show("SET_BNFRIENDNOTE")
		end
	else
		-- whisper and /who
		local prefix = 'player:'
		if contactType == 'bnet' then
			local friendIndex = BNGetFriendIndex(contactInfo)
			local presenceID, presenceName = BNGetFriendInfo(friendIndex)
			contactInfo = presenceName..":"..presenceID
			prefix = 'BN'..prefix
		end
		SetItemRef(prefix..contactInfo, '|H'..prefix..contactInfo..'|h['..contactInfo..']|h', 'LeftButton')
	end
end

local tooltip
function OnLDBEnter(self)
	local numColumns = 6
	if LibQTip:IsAcquired(addonName..'Social') then
		tooltip:Clear()
	else
		tooltip = LibQTip:Acquire(addonName..'Social', numColumns) --, "RIGHT", "RIGHT", "LEFT", "LEFT", "CENTER", "CENTER", "RIGHT")
		tooltip:SmartAnchorTo(self)
		tooltip:SetAutoHideDelay(0.25, self)
		-- tooltip:Clear()
		tooltip:GetFont():SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
	end

	local lineNum
	lineNum = tooltip:AddHeader()
			  tooltip:SetCell(lineNum, 1, addonName .. 'Social', 'CENTER', numColumns)
	tooltip:AddSeparator(2)

	-- battle.net friends
	local _, numBNetOnline = BNGetNumFriends()
	for friendIndex = 1, numBNetOnline do
		local presenceID, presenceName, _, _, _, _, _, _, _, isAFK, isDND, broadcastText, noteText = BNGetFriendInfo(friendIndex)
		local status = isAFK and icons[CHAT_FLAG_AFK] or isDND and icons[CHAT_FLAG_DND] or ''
		--[[-- TODO: config to show/hide battleTag info
		local presenceID, presenceName, battleTag, isBTag, toonName, toonID, client, isOnline, lastOnline, isAFK, isDND, messageText, noteText, isRIDFriend, broadcastTime, canSoR = BNGetFriendInfo(friendIndex)

		local clientIcon = BNet_GetClientEmbeddedTexture(client, 0)
		lineNum = tooltip:AddLine(status, clientIcon, presenceName, messageText, '', noteText)
		          tooltip:SetCell(lineNum, 4, messageText, 'LEFT', 2)
		          tooltip:SetLineScript(lineNum, "OnMouseUp", OnCharacterClick, ("bnet:%s"):format(presenceID))
		--]]

		local numToons = 1 -- TODO: FIXME: won't work :( BNGetNumFriendToons(friendIndex)
		for toonIndex = 1, numToons do
			local _, toonName, client, realmName, _, faction, race, class, _, zoneName, level, gameText = BNGetFriendToonInfo(friendIndex, toonIndex)
			local levelColor = GetQuestDifficultyColor(tonumber(level or '') or 0)
			      level = level and colorFormat:format(levelColor.r*255, levelColor.g*255, levelColor.b*255, level) or nil
			local classColor = classColors[class]
			local infoText = broadcastText and broadcastText ~= '' and icons['BROADCAST']..broadcastText
				or noteText and noteText ~= '' and icons['NOTE']..noteText
				or icons['CONTACT']..presenceName

			if gameText and gameText ~= '' then
				zoneName, realmName = strsplit('-', gameText)
				zoneName, realmName = zoneName and zoneName:trim(), realmName and realmName:trim()
			end

			lineNum = tooltip:AddLine(
				status,
				icons[client],		-- WoW: level
				classColor and colorFormat:format(classColor.r*255, classColor.g*255, classColor.b*255, toonName) or toonName,
				realmName or '',	-- WoW: realm
				zoneName or '',		-- WoW: zone
				infoText
			)

			if client == BNET_CLIENT_WOW then
				realmName = ((faction == 'Horde' and RED_FONT_COLOR_CODE) or (faction == 'Alliance' and BATTLENET_FONT_COLOR_CODE) or '')
					.. realmName .. '|r'
				tooltip:SetCell(lineNum, 2, level)
				tooltip:SetCell(lineNum, 4, realmName)
				tooltip:SetCell(lineNum, 5, zoneName)
			end

			if realmName == playerRealm and faction == playerFaction then
				tooltip:SetLineScript(lineNum, "OnMouseUp", OnCharacterClick, ("friend:%s"):format(toonName))
			else
				tooltip:SetLineScript(lineNum, "OnMouseUp", OnCharacterClick, ("bnet:%s"):format(presenceID))
			end
		end
	end

	-- regular friends
	local _, numFriendsOnline = GetNumFriends()
	for index = 1, numFriendsOnline do
		if index == 1 and numBNetOnline > 0 then
			tooltip:AddLine(' ')
			-- tooltip:AddSeparator(2)
		end
		local name, level, class, area, connected, status, note, RAF = GetFriendInfo(index)

		local status     = icons[status] or ''
		local levelColor = GetQuestDifficultyColor(level)
		local classColor = classColors[class]
		local inMyGroup  = UnitInParty(name) or UnitPlayerOrPetInRaid(name)

		lineNum = tooltip:AddLine(
			(inMyGroup and '|TInterface\\Buttons\\UI-CheckBox-Check:0|t ' or '') .. status,
			colorFormat:format(levelColor.r*255, levelColor.g*255, levelColor.b*255, level),
			colorFormat:format(classColor.r*255, classColor.g*255, classColor.b*255, name),
			'',
			area,
			note
		)
	end

	-- guild roster
	local guildName = GetGuildInfo("player")
	if guildName then
		local guildMOTD = GetGuildRosterMOTD()
		      guildMOTD = guildMOTD and guildMOTD:gsub("(%s%s+)", "\n")

		if numFriendsOnline then
			lineNum = tooltip:AddLine(' ')
			-- tooltip:AddSeparator(2)
		end
		lineNum = tooltip:AddHeader()
		          tooltip:SetCell(lineNum, 1, guildName or '', 'LEFT', numColumns)
		lineNum = tooltip:AddLine()
		          tooltip:SetCell(lineNum, 1, guildMOTD or '', 'LEFT', numColumns)
		lineNum = tooltip:AddLine(' ')

		lineNum = tooltip:AddLine('', _G.ITEM_LEVEL_ABBR, _G.NAMES_LABEL, _G.RANK, _G.ZONE, _G.LABEL_NOTE)

		-- also available: class, wideName, online, weeklyxp, totalxp, arenarating, bgrating, achievement
		tooltip:SetCellScript(lineNum, 2, 'OnMouseUp', SortGuildList, 'level')
		tooltip:SetCellScript(lineNum, 3, 'OnMouseUp', SortGuildList, 'name')
		tooltip:SetCellScript(lineNum, 4, 'OnMouseUp', SortGuildList, 'rank')
		tooltip:SetCellScript(lineNum, 5, 'OnMouseUp', SortGuildList, 'zone')
		tooltip:SetCellScript(lineNum, 6, 'OnMouseUp', SortGuildList, 'note')
		tooltip:AddSeparator(2)

		local numGuildMembers = GetNumGuildMembers()
		for index = 1, numGuildMembers do
			local fullName, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, achievementPoints, achievementRank, isMobile, canSoR, _ = GetGuildRosterInfo(index)
			local name = strsplit("-", fullName)

			if online or isMobile then
				isMobile = isMobile and not online
				status = status == 1 and CHAT_FLAG_AFK or status == 2 and CHAT_FLAG_DND or ''
				status = icons[status] or (isMobile and icons['REMOTE']) or ''
				zone = isMobile and REMOTE_CHAT or zone
				local levelColor = GetQuestDifficultyColor(level)
				local classColor = RAID_CLASS_COLORS[classFileName]
				local inMyGroup  = UnitInParty(name) or UnitPlayerOrPetInRaid(name) -- TODO: check if this still works with "char-realm"

				note        = note and note ~= '' and (HIGHLIGHT_FONT_COLOR_CODE .. note .. '|r') or ''
				officernote = officernote and officernote ~= '' and (GREEN_FONT_COLOR_CODE .. officernote .. '|r') or nil
				local noteText = note .. (officernote and ' '..officernote or '')

				lineNum = tooltip:AddLine(
					(inMyGroup and '|TInterface\\Buttons\\UI-CheckBox-Check:0|t ' or '') .. status,
					colorFormat:format(levelColor.r*255, levelColor.g*255, levelColor.b*255, level),
					colorFormat:format(classColor.r*255, classColor.g*255, classColor.b*255, name),
					rank,
					zone,
					noteText
				)
				tooltip:SetLineScript(lineNum, "OnMouseUp", OnCharacterClick, ("guild:%s"):format(fullName))
			end
		end
	end

	tooltip:Show()
	-- tooltip:UpdateScrolling(maxHeight)
end

local function OnLDBClick(self, btn, up)
	if btn == 'RightButton' then
		-- TODO: config
	else
		local _, numFriendsOnline = GetNumFriends()
		local _, _, numGuildMembers = GetNumGuildMembers()

		if numGuildMembers > 0 or numFriendsOnline == 0 then
			ToggleGuildFrame()
		else
			ToggleFriendsFrame(1)
		end
	end
end

local function OnLDBUpdate(self, event)
	local ldb = LDB:GetDataObjectByName(addonName..'Social')
	-- print('OnLDBUpdate', self, event, ldb)
	if ldb then
		local text = ''

		local numFriends, numFriendsOnline = GetNumFriends()
		local numBNFriends, numBNFriendsOnline = BNGetNumFriends()
		local numInvites = BNGetNumFriendInvites()
		numFriends = numFriends + numBNFriends
		numFriendsOnline = numFriendsOnline + numBNFriendsOnline

		if numFriends > 0 or numInvites > 0 then
			text = text .. BATTLENET_FONT_COLOR_CODE
				.. numFriendsOnline .. (numInvites > 0 and '+'..numInvites or '')
				.. '/' .. numFriends .. '|r'
		end

		local numGuildMembers, numOnline, numOnlineAndMobile = GetNumGuildMembers()
		if numGuildMembers and numGuildMembers > 0 then
			-- show guild info
			text = (text ~= '' and text..' ' or '') .. GREEN_FONT_COLOR_CODE
				.. numOnline .. (numOnlineAndMobile > numOnline and '+'..(numOnlineAndMobile - numOnline) or '')
				.. '/' .. numGuildMembers .. '|r'
		end

		ldb.text = text
	end

	-- update tooltip, if shown
	if LibQTip:IsAcquired(addonName..'Social') then
		OnLDBEnter(self)
	end
end

local function initialize(frame, event, arg1)
	if arg1 == addonName then
		local plugin = LDB:NewDataObject(addonName.."Social", {
			type	= 'data source',
			icon    = 'Interface\\FriendsFrame\\UI-Toast-FriendOnlineIcon',
			label	= _G.SOCIAL_LABEL,
			text 	= _G.SOCIAL_LABEL,

			OnClick = OnLDBClick,
			OnEnter = OnLDBEnter,
			OnLeave = function() end,	-- needed for e.g. NinjaPanel
		})

		local classes = {}
		FillLocalizedClassList(classes, false) -- male names
		for class, localizedName in pairs(classes) do
			classColors[localizedName] = RAID_CLASS_COLORS[class]
		end
		--[[ FillLocalizedClassList(classes, true) -- female names
		for class, localizedName in pairs(classes) do
			classColors[localizedName] = RAID_CLASS_COLORS[class]
		end --]]

		for _, event in ipairs({'GUILD_ROSTER_UPDATE', 'FRIENDLIST_UPDATE', -- 'IGNORELIST_UPDATE', 'MUTELIST_UPDATE',
			'BN_CONNECTED', 'BN_DISCONNECTED', 'BN_FRIEND_LIST_SIZE_CHANGED',
			'BN_FRIEND_TOON_ONLINE', 'BN_FRIEND_TOON_OFFLINE', 'BN_FRIEND_ACCOUNT_ONLINE', 'BN_FRIEND_ACCOUNT_OFFLINE',
			'BATTLETAG_INVITE_SHOW', 'BN_FRIEND_INVITE_LIST_INITIALIZED', 'BN_FRIEND_INVITE_ADDED', 'BN_FRIEND_INVITE_REMOVED'}) do
			ns.RegisterEvent(event, OnLDBUpdate, 'social_'..event)
		end

		ns.UnregisterEvent('ADDON_LOADED', 'social')
	end
end
ns.RegisterEvent('ADDON_LOADED', initialize, 'social')

ns.RegisterEvent('NEUTRAL_FACTION_SELECT_RESULT', function()
	playerFaction = UnitFactionGroup("player")
end, 'playerfaction')
