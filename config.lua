local addonName, ns, _ = ...
-- GLOBALS: _G, type, pairs, wipe

local SharedMedia = LibStub("LibSharedMedia-3.0", true)
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
if not AceConfig or not AceConfigDialog then return end

local function GetSetting(info)
	local db = _G[ info[1] ]
	local data = db
	for i = 2, #info do
		data = data[ info[i] ]
	end
	return data
end

local function SetSetting(info, value)
	local db = _G[ info[1] ]
	local data = db
	for i = 2, #info - 1 do
		data = data[ info[i] ]
	end
	data[ info[#info] ] = value
end

local optionsTable = {
	type = 'group',
	args = {
		['MidgetLocalDB'] = {
			type = 'group',
			inline = true,
			name = 'Individual Settings',
			order = 1,
			args = {},
		},
		['MidgetDB'] = {
			type = 'group',
			inline = true,
			name = 'Shared Settings',
			order = 2,
			args = {},
		},
	},
	get = GetSetting,
	set = SetSetting,
}

function ns:LSM_GetMediaKey(mediaType, value)
	local keyList = SharedMedia:List(mediaType)
	for _, key in pairs(keyList) do
		if SharedMedia:Fetch(mediaType, key) == value then
			return key
		end
	end
end

local function GetListFromTable(dataTable, seperator)
	local output = ''
	for _, value in pairs(dataTable) do
		output = (output ~= '' and output..seperator or '') .. value
	end
	return output
end

local function GetTableFromList(dataString, seperator)
	return { strsplit(seperator, dataString) }
end

local function Widget(key, option)
	local key, widget = key:lower(), nil
	if key == 'justifyh' then
		widget = {
			type = "select",
			name = "Text Justification",

			values = {["LEFT"] = "LEFT", ["CENTER"] = "CENTER", ["RIGHT"] = "RIGHT"},
		}
	elseif key == 'fontsize' then
		widget = {
			type = "range",
			name = "Font Size",
			step = 1,
			min = 5,
			max = 24,
		}
	elseif key == 'font' and SharedMedia then
		widget = {
			type = 'select',
			dialogControl = 'LSM30_Font',
			name = 'Font Family',

			values = SharedMedia:HashTable('font'),
			get = function(info) return ns:LSM_GetMediaKey('font', GetSetting(info)) end,
			set = function(info, value)
				SetSetting(info, SharedMedia:Fetch('font', value))
			end,
		}
	elseif key == 'fontstyle' then
		widget = {
			type = "select",
			name = "Font Style",

			values = {["NONE"] = "NONE", ["OUTLINE"] = "OUTLINE", ["THICKOUTLINE"] = "THICKOUTLINE", ["MONOCHROME"] = "MONOCHROME"},
		}
	elseif key:find('list$') then
		widget = {
			type = 'input',
			multiline = true,
			usage = "Insert one entry per line",

			get = function(info) return GetListFromTable(GetSetting(info, "\n")) end,
			set = function(info, value)
				SetSetting(info, GetTableFromList(value, "\n"))
			end,
		}
	elseif type(option) == 'string' then
		widget = {
			type = "input",
		}
	end

	return widget
end

local function ParseOption(key, option)
	-- in Midget, we don't like nested tables
	if type(key) ~= 'string' or type(option) == 'table' then return end
	local widget = Widget(key, option)
	if widget then
		widget.name = widget.name or key
		return widget
	elseif type(option) == 'boolean' then
		return {
			type = 'toggle',
			name = key,
			-- desc = '',
		}
	elseif type(option) == 'number' then
		return {
			type = 'range',
			name = key,
			-- desc = '',
			min = -200,
			max = 200,
			bigStep = 10,
		}
	elseif type(option) == 'table' then
		local data = {
			type 	= 'group',
			inline 	= true,
			name 	= key,
			args 	= {},
		}

		for subkey, value in pairs(option) do
			data.args[subkey] = ParseOption(subkey, value)
		end
		return data
	end
end

local function GenerateOptions()
	for namespace, _ in pairs(optionsTable.args) do
		wipe(optionsTable.args[namespace].args)
		for key, value in pairs(_G[namespace]) do
			local parsedOption = ParseOption(key, value)
			if parsedOption and parsedOption.type and parsedOption.type == 'group' then
				parsedOption.inline = false
			end
			optionsTable.args[namespace].args[key] = parsedOption
		end
	end
	return optionsTable
end

AceConfig:RegisterOptionsTable(addonName, GenerateOptions)
AceConfigDialog:AddToBlizOptions(addonName)
