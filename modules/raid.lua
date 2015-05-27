local addonName, addon, _ = ...
local plugin = addon:NewModule('RaidTracker', 'AceEvent-3.0')

-- GLOBALS: _G,
-- GLOBALS:
-- GLOBALS: hooksecurefunc

local function OnEnterRaidBuff(self)
	GameTooltip:SetOwner(self)
	local index = self:GetID()
	local spellName, _, _, _, _, spellID = GetRaidBuffTrayAuraInfo(index)
	if spellID then
		GameTooltip:SetUnitConsolidatedBuff('player', index)
	else
		local effect = _G['RAID_BUFF_'..index]:gsub('-\n', '')
		GameTooltip:AddLine(string.format(_G.ITEM_MISSING, effect), 1, 0, 0, true)
	end
	GameTooltip:Show()
end
function plugin:OnEnable()
	if not addon.db.profile.showRaidBuffIndicators then return end

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
	local enabled = addon.db.profile.showRaidBuffIndicators
	for index = 1, _G.NUM_LE_RAID_BUFF_TYPES do
		local name, rank, texture, duration, expiration, spellID, slot = GetRaidBuffTrayAuraInfo(index)
		local icon = self.indicators[index].icon
		if not name or not enabled then
			icon:Hide()
		else
			local _, _, _, _, _, _, _, caster = UnitBuff('player', name)
			local class = caster and select(2, UnitClass(caster))
			local color = class and RAID_CLASS_COLORS[class] or _G.NORMAL_FONT_COLOR
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
