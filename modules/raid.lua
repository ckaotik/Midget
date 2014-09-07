local addonName, addon, _ = ...
local plugin = addon:NewModule('RaidTracker', 'AceEvent-3.0')

-- GLOBALS: _G,
-- GLOBALS:
-- GLOBALS: hooksecurefunc

local raidBuffColors = {
	-- _G.RAID_BUFF_1 stat multiplier
	[  1126] = _G.RAID_CLASS_COLORS['DRUID'], -- Mark of the Wild
	[ 20217] = _G.RAID_CLASS_COLORS['PALADIN'], -- Blessing of Kings
	[115921] = _G.RAID_CLASS_COLORS['MONK'], -- Legacy of the Emperor
	[ 90363] = _G.RAID_CLASS_COLORS['HUNTER'], -- Embrace of the Shale Spider
	-- _G.RAID_BUFF_2 stamina
	[   469] = _G.RAID_CLASS_COLORS['WARRIOR'], -- Commanding Shout
	[ 21562] = _G.RAID_CLASS_COLORS['PRIEST'], -- Power Word: Fortitude
	[ 90364] = _G.RAID_CLASS_COLORS['HUNTER'], -- Qiraji Fortitude
	[109773] = _G.RAID_CLASS_COLORS['WARLOCK'], -- Dark Intent
	[ 86507] = {r = 1, g = 1, b = 1, a = 1}, -- Runescroll of Fortitude II [Inscription]
	[ 69377] = {r = 1, g = 1, b = 1, a = 1}, -- Runescroll of Fortitude I [Inscription]
	-- _G.RAID_BUFF_3 -- attack power
	[  6673] = _G.RAID_CLASS_COLORS['WARRIOR'], -- Batte Shout
	[ 19506] = _G.RAID_CLASS_COLORS['HUNTER'], -- Trueshot Aura
	[ 57330] = _G.RAID_CLASS_COLORS['DEATHKNIGHT'], -- Horn of Winter
	-- _G.RAID_BUFF_4 attack speed
	[ 30809] = _G.RAID_CLASS_COLORS['SHAMAN'], -- Unleashed Rage
	[ 55610] = _G.RAID_CLASS_COLORS['DEATHKNIGHT'], -- Unholy Aura
	[113742] = _G.RAID_CLASS_COLORS['ROGUE'], -- Swiftblade's Cunning
	[128432] = _G.RAID_CLASS_COLORS['HUNTER'], -- Cackling Howl
	[128433] = _G.RAID_CLASS_COLORS['HUNTER'], -- Serpent's Swiftness
	-- _G.RAID_BUFF_5 spell power
	[  1459] = _G.RAID_CLASS_COLORS['MAGE'], -- Arcane Brilliance
	[ 61316] = _G.RAID_CLASS_COLORS['MAGE'], -- Dalaran Brilliance
	[ 77747] = _G.RAID_CLASS_COLORS['SHAMAN'], -- Burning Wrath
	-- [109773] = _G.RAID_CLASS_COLORS['WARLOCK'], -- Dark Intent
	[126309] = _G.RAID_CLASS_COLORS['HUNTER'], -- Still Water
	-- _G.RAID_BUFF_6 spell haste
	[ 15473] = _G.RAID_CLASS_COLORS['PRIEST'], -- Shadowform
	[ 24907] = _G.RAID_CLASS_COLORS['DRUID'], -- Moonkin Aura
	[ 51470] = _G.RAID_CLASS_COLORS['SHAMAN'], -- Elemental Oath
	[ 49868] = _G.RAID_CLASS_COLORS['HUNTER'], -- Mind Quickening
	[135678] = _G.RAID_CLASS_COLORS['HUNTER'], -- Energizing Spores
	-- _G.RAID_BUFF_7 critical strike chance
	-- [  1459] = _G.RAID_CLASS_COLORS['MAGE'], -- Arcane Brilliance
	[ 17007] = _G.RAID_CLASS_COLORS['DRUID'], -- Leader of the Pack
	[ 24604] = _G.RAID_CLASS_COLORS['HUNTER'], -- Furious Howl
	-- [ 61316] = _G.RAID_CLASS_COLORS['MAGE'], -- Dalaran Brilliance
	[ 90309] = _G.RAID_CLASS_COLORS['HUNTER'], -- Terrifying Roar
	[ 97229] = _G.RAID_CLASS_COLORS['HUNTER'], -- Bellowing Roar
	[116781] = _G.RAID_CLASS_COLORS['MONK'], -- Legacy of the White Tiger
	-- [126309] = _G.RAID_CLASS_COLORS['HUNTER'], -- Still Water
	[126373] = _G.RAID_CLASS_COLORS['HUNTER'], -- Fearless Roar
	-- _G.RAID_BUFF_8 mastery
	[ 19740] = _G.RAID_CLASS_COLORS['PALADIN'], -- Blessing of Might
	[116956] = _G.RAID_CLASS_COLORS['SHAMAN'], -- Grace of Air
	[ 93435] = _G.RAID_CLASS_COLORS['HUNTER'], -- Roar of Courage
	[128997] = _G.RAID_CLASS_COLORS['HUNTER'], -- Spirit Beast Blessing
}

local function OnEnterRaidBuff(self)
	GameTooltip:SetOwner(self)
	local index = self:GetID()
	local _, _, _, _, _, spellID = GetRaidBuffTrayAuraInfo(index)
	local effect = _G['RAID_BUFF_'..index]:gsub('-\n', '')
	if spellID then
		GameTooltip:SetUnitConsolidatedBuff('player', index)
		GameTooltip:AddLine(string.format(_G.ITEM_SPELL_EFFECT, effect), 1, 1, 1, true)
	else
		GameTooltip:AddLine(string.format(_G.ITEM_MISSING, effect), 1, 0, 0, true)
	end
	GameTooltip:Show()
end
function plugin:OnEnable()
	self.indicators = {}
	for index = 1, _G.NUM_LE_RAID_BUFF_TYPES do
		local indicator = CreateFrame('Frame', nil, UIParent, nil, index)
		      indicator:SetSize(10, 10)
		local icon = indicator:CreateTexture()
		      icon:SetAllPoints()
		      icon:SetTexture(1, 1, 1, 1)
		      icon:Hide()
		indicator.icon = icon

		if index == 1 then
			indicator:SetPoint('TOPLEFT', _G.Minimap, 'TOPRIGHT', 4, -40)
		else
			indicator:SetPoint('TOPLEFT', self.indicators[index-1], 'BOTTOMLEFT', 0, -1)
		end
		self.indicators[index] = indicator

		indicator:SetScript('OnEnter', OnEnterRaidBuff)
		indicator:SetScript('OnLeave', GameTooltip_Hide)
	end

	self:RegisterEvent('ENCOUNTER_END')
	self:RegisterEvent('ENCOUNTER_START')
	self:RegisterEvent('UNIT_AURA')
	self:UNIT_AURA('UNIT_AURA', 'player')

	local button = CreateFrame('Button', '$parentOtherRaids', GroupFinderFrame, 'UIPanelButtonTemplate')
	      button:SetText(_G.LOOKING_FOR_RAID)
	      button:SetPoint('BOTTOMLEFT', 36, 16)
	      button:SetSize(150, 20)
	button:SetScript('OnClick', function(self, btn, up)
		ToggleFrame(RaidBrowserFrame)
	end)
end

function plugin:OnDisable()
	self:UnregisterEvent('ENCOUNTER_END')
	self:UnregisterEvent('ENCOUNTER_START')
	self:UnregisterEvent('UNIT_AURA')

	for index, indicator in ipairs(self.indicators) do
		indicator.icon:Hide()
	end
end

function plugin:UNIT_AURA(event, unit)
	if unit ~= 'player' then return end
	local enabled = MidgetDB.showRaidBuffIndicators
	for index = 1, _G.NUM_LE_RAID_BUFF_TYPES do
		local name, rank, texture, duration, expiration, spellID, slot = GetRaidBuffTrayAuraInfo(index)
		local icon = self.indicators[index].icon
		if not name or not enabled then
			icon:Hide()
		else
			local color = raidBuffColors[spellID] or _G.NORMAL_FONT_COLOR
			icon:SetVertexColor(color.r, color.g, color.b, color.a)
			icon:Show()
		end
	end
end

-- http://wowprogramming.com/docs/events/ENCOUNTER_START
function plugin:ENCOUNTER_START(event, encounterID, encounterName, difficulty, raidSize)
	print('Encounter', encounterName, '('..encounterID..')', 'started')
end

-- http://wowprogramming.com/docs/events/ENCOUNTER_END
function plugin:ENCOUNTER_END(event, encounterID, encounterName, difficulty, raidSize, endStatus)
	print('Encounter', encounterName, '('..encounterID..')', endStatus == 1 and 'completed' or 'wiped')
end

if true then return end

-- ================================================
-- Utility for OpenRaid.eu
-- ================================================
-- import string: CharName-RealmName*RaidID,RaidTitle,Day,Month,Year,Hours,Minutes;BTag#BtagNo-CharName-RealmName,<...>
-- export string: PlayerName*RaidID,RaidTitle-Day-Month-Year-Hours-Minutes;Name,NumStars,Commment;<...>
--  Name: Btag? CharName? Full char name?
--  NumStars: 1-5 or 3
--  Comment: comment text or "None"

--[[
	OR_db.Raids[playerName][raidID] = { raidTitle, day, month, year, hours, minutes, players }
	OR_db.Raids[playerName][raidID][7] = 'Battletag#0001-Character-Realm,Battletag#0002-Character-Realm,...'
--]]

local function UpdateAttendee(index)
	-- body
end
local function UpdateExportString()
	local playerName = GetFullUnitName('player') -- Pname
end
--[[
local function RatesToString()
	StaticPopupDialogs["OpenRaidConfirm"].OnHide = nil;
	local G = OpenRaidGetDropdowntext(OpenRaidFrameRateRaid)
	if G == "Raid" then
		OpenRaidAddMessageToErrorQueue( { L["Select raid"], } );
		return
	end
	OpenRaidFrameRateRaid:SetText("Raid")
	local String = (OR_db.String[Pname] or (Pname)) --Does it still exist or is it a fresh one?
	for i=1, OpenRaidFrameRate.Boxes do
		local S = OpenRaidFrame["RateFrameFontString" .. i].text;
		OR_db.Rate[G][S] = OR_db.Rate[G][S] or {};
		local Text = _G["RateFrameEditbox" .. i]:GetText();
		if Text and Text ~= "" then
			OR_db.Rate[G][S][2] = Text;
		else
			OR_db.Rate[G][S][2] = "None";
		end
	end
	local T = OR_db.Raids[Pname][G];
	if not strfind(String, G) then --Is this event rated already?
		String = String .. "*" .. G .. "-".. T[2] .. "-" .. T[3] .. "-" .. T[4] .. "-" .. T[5] .. "-" .. T[6];
		for k,v in pairs(OR_db.Rate[G]) do
			if k ~= "Name" then
				String = String  .. ";" .. k .. "," .. v[1] or 3 .. "," .. v[2] --Adds: ";NamePerson,1-5Rating,(Commment or None)" to string
			end
		end
		OR_db.String[Pname] = String;
		OpenRaidAddMessageToErrorQueue( { L["Visit OpenRaid.org/addon"], function(self)
		end, true, function(self)
			self.editBox:SetText(OR_db.String[Pname])
			self.editBox:HighlightText();
		end, } )
		for k,v in pairs(OR_db.Rate) do
			local N = OR_db.Rate[k].Name;
			OR_db.Rate[k] = {};
			OR_db.Rate[k].Name = N;
		end
		OpenRaidTabs(OpenRaidFrame, "None");
	else
		OpenRaidConfirmHandle(L["Already rated"], function()
			local P = { strfind(String, G) }
			local E = strfind(String, "*", P[1] + 1) or (strlen(String) + 1)
			local ReplaceString = G .. "-".. T[2] .. "-" .. T[3] .. "-" .. T[4] .. "-" .. T[5] .. "-" .. T[6];
			for k,v in pairs(OR_db.Rate[G]) do
				if k ~= "Name" then
					ReplaceString = ReplaceString  .. ";" .. k .. "," .. v[1] .. "," .. v[2] --Adds: ";NamePerson,1-5Rating,(Commment or None)" to string
				end
			end
			local s = gsub(OR_db.String[Pname], "%-", "%^") --workaround for gsub() and "-" not working properly
			s = gsub(s, string.sub(s, P[1], E), ReplaceString)
			OR_db.String[Pname] = gsub(s, "%^", "%-")
			OpenRaidAddMessageToErrorQueue( { L["Visit OpenRaid.org/addon"], function(self)
			end, true, function(self)
				self.editBox:SetText(OR_db.String[Pname])
				self.editBox:HighlightText();
			end, } )
		end)
	end
end
--]]
