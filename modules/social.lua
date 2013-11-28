local addonName, ns, _ = ...

-- GLOBALS: _G, LibStub, RED_FONT_COLOR_CODE, BATTLENET_FONT_COLOR_CODE, RAID_CLASS_COLORS, CHAT_FLAG_AFK, CHAT_FLAG_DND
-- GLOBALS: BNGetNumFriends, BNGetFriendInfo, BNGetNumFriendToons, BNGetFriendToonInfo, GetQuestDifficultyColor, GetNumFriends, GetFriendInfo, GetNumGuildMembers, GetGuildRosterInfo

local LDB     = LibStub('LibDataBroker-1.1')
local LibQTip = LibStub('LibQTip-1.0')

local playerFaction = UnitFactionGroup("player")
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
}

local function OnCharacterClick(self, character, btn, up)
	local contactType, contactInfo, contactDetail = strsplit(":", character)
	-- local i_type, toon_name, full_name, presence_id = string.split(":", info)
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
		--[[ if i_type == "guild" and CanEditPublicNote() then
			SetGuildRosterSelection(guild_name_to_index(toon_name))
			StaticPopup_Show("SET_GUILDPLAYERNOTE")
			return
		end
		if i_type == "guild" and btn == "RightButton" and CanEditOfficerNote() then
			SetGuildRosterSelection(guild_name_to_index(toon_name))
			StaticPopup_Show("SET_GUILDOFFICERNOTE")
		end

		if i_type == "friends" then
			FriendsFrame.NotesID = player_name_to_index(toon_name)
				StaticPopup_Show("SET_FRIENDNOTE", GetFriendInfo(FriendsFrame.NotesID))
				return
		end

		if i_type == "realid" then
			FriendsFrame.NotesID = presence_id
			StaticPopup_Show("SET_BNFRIENDNOTE", full_name)
			return
		end --]]
	else
		-- whisper and /who
		local prefix = 'player:'
		if contactType == 'bnet' then
			local friendIndex = BNGetFriendIndex(contactInfo)
			local presenceID, presenceName = BNGetFriendInfo(friendIndex)
			contactInfo = presenceName
			prefix = 'BN'..prefix
		end
		SetItemRef(prefix..contactInfo, '|H'..prefix..contactInfo..'|h['..contactInfo..']|h', 'LeftButton')
	end
end

local function OnLDBEnter(self)
	local tooltip = LibQTip:Acquire(addonName, 8) --, "RIGHT", "RIGHT", "LEFT", "LEFT", "CENTER", "CENTER", "RIGHT")
	      tooltip:Clear()
	-- tooltip:GetFont():SetTextColor(NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)

	local lineNum
	lineNum = tooltip:AddHeader()
			  tooltip:SetCell(lineNum, 1, addonName .. 'Social', 'CENTER', 8)
	tooltip:AddSeparator(2)

	-- battle.net friends
	local _, numBNetOnline = BNGetNumFriends()
	for friendIndex = 1, numBNetOnline do
		local presenceID, presenceName, battleTag, isBTag, toonName, toonID, client, isOnline, lastOnline, isAFK, isDND, messageText, noteText, isRIDFriend, broadcastTime, canSoR = BNGetFriendInfo(friendIndex)

		local status = isAFK and icons[CHAT_FLAG_AFK] or isDND and icons[CHAT_FLAG_DND] or ''
		local clientIcon = BNet_GetClientEmbeddedTexture(client, 0)
		lineNum = tooltip:AddLine(status, presenceName, clientIcon, battleTag, noteText, messageText)

		local numToons = BNGetNumFriendToons(friendIndex)
		for toonIndex = 1, numToons do
			local _, toonName, client, realmName, _, faction, race, class, _, zoneName, level, gameText, broadcastText, broadcastTime, _, _ = BNGetFriendToonInfo(friendIndex, toonIndex)
			-- true, "Jiera", "WoW", "Die Aldor", 1618, "Alliance", "Nachtelf", "J\195\164ger", "", "Shado-Pan-Kloster", "90", "Shado-Pan-Kloster - Die Aldor", "", 0, true, 31

			local levelColor = GetQuestDifficultyColor(tonumber(level or '') or 0)
			local classColor = classColors[class]

			lineNum = tooltip:AddLine(
				status,
				colorFormat:format(levelColor.r*255, levelColor.g*255, levelColor.b*255, level),
				colorFormat:format(classColor.r*255, classColor.g*255, classColor.b*255, toonName),
				zoneName,
				(faction == 'Horde' and RED_FONT_COLOR_CODE or faction == 'Alliance' and BATTLENET_FONT_COLOR_CODE or '') .. realmName .. '|r',
				gameText,
				broadcastText
			)
			tooltip:SetLineScript(lineNum, "OnMouseUp", OnCharacterClick, ("bnet:%s:s"):format(presenceID, toonIndex))
		end

		-- SetCellScript(lineNum, colNum, script, func, arg)
		-- tooltip:SetCellScript(line, 1, "OnMouseUp", SetRealIDSort, "LEVEL")

		-- lineNum = tooltip:AddLine(text, cacheData.count, BG.FormatMoney(cacheData.value), BG_GlobalDB.showSource and source or nil)
		--           tooltip:SetLineScript(lineNum, "OnMouseDown", BG.OnClick, location)
	end

	tooltip:AddSeparator(2)

	-- regular friends
	local _, numFriendsOnline = GetNumFriends()
	for index = 1, numFriendsOnline do
		local name, level, class, area, connected, status, note, RAF = GetFriendInfo(index)

		local status     = icons[status] or ''
		local levelColor = GetQuestDifficultyColor(level)
		local classColor = classColors[class]
		local inMyGroup  = UnitInParty(name) or UnitPlayerOrPetInRaid(name)

		lineNum = tooltip:AddLine(
			status,
			inMyGroup and '|TInterface\\Buttons\\UI-CheckBox-Check:0|t' or '',
			colorFormat:format(levelColor.r*255, levelColor.g*255, levelColor.b*255, level),
			colorFormat:format(classColor.r*255, classColor.g*255, classColor.b*255, name),
			area,
			connected,
			note
		)
	end

	-- guild roster
	local guildName = GetGuildInfo("player")
	if guildName then
		local guildMOTD = GetGuildRosterMOTD()
		      guildMOTD = guildMOTD and guildMOTD:gsub("(%s%s+)", "\n")
		lineNum = tooltip:AddHeader()
		                tooltip:SetCell(lineNum, 1, guildName or '', 'LEFT', 8)
		lineNum = tooltip:AddLine()
		                tooltip:SetCell(lineNum, 1, guildMOTD or '', 'LEFT', 8)
		tooltip:AddSeparator(2)

		lineNum = tooltip:AddLine('Level', '', 'Name', 'Rank', 'Zone', 'Note', '')
		          tooltip:SetCell(lineNum, 1, 'Level', 'LEFT', 2)
		          tooltip:SetCell(lineNum, 6, 'Note', 'LEFT', 2)
		tooltip:AddSeparator(2)

		local _, numOnline, numOnlineAndMobile = GetNumGuildMembers()
		for index = 1, numOnlineAndMobile do
			local name, rank, rankIndex, level, class, zone, note, officernote, online, status, classFileName, achievementPoints, achievementRank, isMobile, canSoR, _ = GetGuildRosterInfo(index)
			-- "Vadun", "Veteranen", 6, 87, "Magier", "Auge des Sturms", "Thorsten", "", 1, 0, "MAGE", 4665, 33, false, false, 7

			local status     = icons[status] or (isMobile and icons['REMOTE']) or ''
			local levelColor = GetQuestDifficultyColor(level)
			local classColor = RAID_CLASS_COLORS[classFileName]
			local inMyGroup  = UnitInParty(name) or UnitPlayerOrPetInRaid(name)

			lineNum = tooltip:AddLine(
				status .. (inMyGroup and '|TInterface\\Buttons\\UI-CheckBox-Check:0|t' or ''),
				colorFormat:format(levelColor.r*255, levelColor.g*255, levelColor.b*255, level),
				colorFormat:format(classColor.r*255, classColor.g*255, classColor.b*255, name),
				rank,
				zone,
				note,
				officernote
			)
			tooltip:SetLineScript(lineNum, "OnMouseUp", OnCharacterClick, ("guild:%s"):format(name))
		end
	end

	-- Use smart anchoring code to anchor the tooltip to our LDB frame
	tooltip:SmartAnchorTo(self)
	tooltip:SetAutoHideDelay(0.25, self)
	tooltip:Show()
	-- tooltip:UpdateScrolling(maxHeight)
end

local function OnLDBClick(self, btn, up)
	-- body
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

		ns.UnregisterEvent('ADDON_LOADED', 'social')
	end
end
ns.RegisterEvent('ADDON_LOADED', initialize, 'social')

ns.RegisterEvent('NEUTRAL_FACTION_SELECT_RESULT', function()
	playerFaction = UnitFactionGroup("player")
end, 'playerfaction')
