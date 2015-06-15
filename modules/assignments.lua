local addonName, addon, _ = ...
local plugin = addon:NewModule('Assignments', 'AceConsole-3.0', 'AceEvent-3.0', 'AceComm-3.0', 'AceTimer-3.0')

-- GLOBALS: _G,
-- GLOBALS:
-- GLOBALS: hooksecurefunc

local LibSerializer = LibStub('AceSerializer-3.0', true)
local LibCompress   = LibStub('LibCompress', true)
-- local libCE = LibCompress:GetAddonEncodeTable()
if not LibSerializer or not LibCompress then return end

local DEFAULT_VERSION = {'VERSION', 'v1.6.0', 20150310061316, true}

function plugin:OnEnable()
	if not addon.db.profile.listenForAssignments then return end

	-- RegisterAddonMessagePrefix(comPrefix)
	self:RegisterComm('AnAss1')
end

function plugin:OnDisable()
	self:UnregisterComm('AnAss1')
end

function plugin:OnCommReceived(prefix, message, channel, sender)
	-- TODO: also return when sender is player
	if prefix ~= 'AnAss1' then return end

	-- data is serialized, compressed and encoded
	local data = message
	-- data = libCE:Decode(data)
	data = LibCompress:Decompress(data)
	if not data then return end
	local success
	success, data = LibSerializer:Deserialize(data)
	if not success then return end

	local messageType = data[1]
	if messageType == 'VER_QUERY' then
		-- send reply
		self:SendMessage(DEFAULT_VERSION)
	elseif messageType == 'REQUEST_PAGE' then
		return
	elseif messageType == 'REQUEST_DISPLAY' then
		-- local id, updated, updateID = unpack(data, 2)
		return
	elseif messageType == 'VERSION' then
		-- local version, timestamp, validRaid = unpack(data, 2)
		return
	elseif messageType == 'PAGE' then
		local id, updated, name, contents, updateID = unpack(data, 2)
	elseif messageType == 'DISPLAY' then
		local id, updated, updateID = unpack(data, 2)
		--[[ if not pages[id] or pages[id].version ~= updated then
			self:SendRequestPage(id, sender)
		end --]]
	end

	-- FOO = data; SlashCmdList.SPEW('FOO')
	print('Received message from AngryAssignments:', messageType, unpack(data, 2, 4))
end
