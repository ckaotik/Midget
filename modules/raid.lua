local addonName, addon, _ = ...
local plugin = addon:NewModule('RaidTracker', 'AceEvent-3.0')

-- GLOBALS: _G,
-- GLOBALS:
-- GLOBALS: hooksecurefunc

function plugin:OnEnable()
	self:RegisterEvent('ENCOUNTER_END')
	self:RegisterEvent('ENCOUNTER_START')
end

function plugin:OnDisable()
	self:UnregisterEvent('ENCOUNTER_END')
	self:UnregisterEvent('ENCOUNTER_START')
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
