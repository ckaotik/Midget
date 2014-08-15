local MAJOR, MINOR = 'LibOptionsGenerate-1.0', 2
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end

-- GLOBALS: _G, type, pairs, wipe, strsplit

local SharedMedia     = LibStub("LibSharedMedia-3.0", true)
local AceConfig       = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
if not AceConfig or not AceConfigDialog then return end

local function GetVariableFromPath(path)
	local variable
	local parts = { strsplit('.', path) }
	for index, part in ipairs(parts) do
		if index == 1 then variable = _G[part]
		else variable = variable[part] end
		if not variable then return end
	end
	return variable
end

local function GetSetting(info)
	local component = info.options.args[ info[1] ]
	local db = GetVariableFromPath(component.descStyle or info[1])

	local data = db
	for i = 2, #info do
		data = data[ info[i] ]
	end
	return data
end

local function SetSetting(info, value)
	local component = info.options.args[ info[1] ]
	local db = GetVariableFromPath(component.descStyle or info[1])

	local data = db
	for i = 2, #info - 1 do
		data = data[ info[i] ]
	end
	data[ info[#info] ] = value
end

local function GetMediaKey(mediaType, value)
	local keyList = SharedMedia:List(mediaType)
	for _, key in pairs(keyList) do
		if SharedMedia:Fetch(mediaType, key) == value then
			return key
		end
	end
end

local function GetTableFromList(dataString, seperator)
	return { strsplit(seperator, dataString) }
end
local function GetListFromTable(dataTable, seperator)
	local output = ''
	for _, value in pairs(dataTable) do
		output = (output ~= '' and output..seperator or '') .. value
	end
	return output
end

local function Widget(key, option)
	local key, widget = key:lower(), nil
	if key == 'justifyh' then
		widget = {
			type = "select",
			name = "Horiz. Justification",
			values = {["LEFT"] = "LEFT", ["CENTER"] = "CENTER", ["RIGHT"] = "RIGHT"},
		}
	elseif key == 'justifyv' then
		widget = {
			type = "select",
			name = "Vert. Justification",
			values = {["TOP"] = "TOP", ["MIDDLE"] = "MIDDLE", ["BOTTOM"] = "BOTTOM"},
		}
	elseif key == 'fontsize' then
		widget = {
			type = "range",
			name = "Font Size",
			step = 1,
			min = 5,
			max = 24, -- Blizz won't go any larger
		}
	elseif key == 'font' and SharedMedia then
		widget = {
			type = 'select',
			dialogControl = 'LSM30_Font',
			name = 'Font Family',

			values = SharedMedia:HashTable('font'),
			get = function(info) return GetMediaKey('font', GetSetting(info)) end,
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
	if type(key) ~= 'string' --[[or type(option) == 'table'--]] then return end
	-- if key == 'profileKeys' then return end

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
			if subkey ~= '*' and subkey ~= '**' then
				data.args[subkey] = ParseOption(subkey, value)
			end
		end
		return data
	end
end

local emptyTable = {}
function lib:GenerateOptions(optionsTable)
	optionsTable.get = optionsTable.get or GetSetting
	optionsTable.set = optionsTable.set or SetSetting

	for groupKey, group in pairs(optionsTable.args) do
		wipe(optionsTable.args[groupKey].args)
		local gVar = GetVariableFromPath(group.descStyle or groupKey)
		for key, value in pairs(gVar or emptyTable) do
			local parsedOption = ParseOption(key, value)
			if parsedOption and parsedOption.type and parsedOption.type == 'group' then
				parsedOption.inline = false
			end
			optionsTable.args[groupKey].args[key] = parsedOption
		end
	end
	return optionsTable
end

function lib:GetOptionsTable(variables, getFunc, setFunc)
	local optionsTable = {
		name = 'Options',
		type = 'group',
		args = {},
	}

	for key, value in pairs(variables) do
		optionsTable.args[key] = ParseOption(key, value)
	end

	return optionsTable
end
