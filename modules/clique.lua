if not IsAddOnLoaded('Clique') then return end

local function GetBindings(characterKey)
	local account, realm, character = strsplit('.', characterKey)
	local profileKey = character .. ' - ' .. realm
	local bindings = Clique.db.profiles[profileKey] and Clique.db.profiles[profileKey].bindings
	return bindings or {}
end

local function GetCliqueBindings(info)
	local text = ''
	for index, binding in pairs(Clique.bindings) do
		local matches = true
		local keys = binding.key
		for _, modifier in pairs(info.arg) do
			-- modifier is not part of this binding
			if not keys:find(modifier .. '%-') then
				matches = false
				break
			end
			keys = keys:gsub(modifier .. '%-', '')
		end
		-- this binding uses more modifiers than we've requested
		if keys:find('%-') then matches = false end

		if matches then
			local icon  = Clique:GetBindingIcon(binding)
			local label = binding.type == 'spell' and binding.spell or Clique:GetBindingActionText(binding.type, binding)
			local keys  = Clique:GetBindingKeyComboText(binding)
			-- local key = Clique:GetBindingKey(binding)

			if not binding.sets then
				-- nothing
			elseif binding.sets.enemy then
				label = _G.RED_FONT_COLOR_CODE .. label .. '|r'
			elseif binding.sets.friend then
				label = _G.GREEN_FONT_COLOR_CODE .. label .. '|r'
			elseif binding.sets.global then
				label = _G.BATTLENET_FONT_COLOR_CODE .. label .. '|r'
			end

			text = (text ~= '' and (text .. '\n') or '') .. ('|T%s:16|t %s, %s'):format(icon or '', label, keys)
		end
	end
	return text
end

local function CliqueOpenConfiguration(self, args)
	-- remove placeholder configuration panel
	for i, panel in ipairs(_G.INTERFACEOPTIONS_ADDONCATEGORIES) do
		if panel == self then
			tremove(INTERFACEOPTIONS_ADDONCATEGORIES, i)
			break
		end
	end
	self:SetScript('OnShow', nil)
	self:Hide()

	-- initialize panel
	LibStub('AceConfig-3.0'):RegisterOptionsTable('CliqueBindings', {
		type = 'group',
		name = 'Bindings',
		args = {
			headerUnmodified = { type = 'header', name = 'Unmodified', order = 0 },
			bindingsUnmodified = {
				type = 'description',
				fontSize = 'medium',
				name = GetCliqueBindings,
				arg  = {},
				order = 10,
			},
			headerShift = { type = 'header', name = 'Shift', order = 20 },
			bindingsShift = {
				type = 'description',
				fontSize = 'medium',
				name = GetCliqueBindings,
				arg  = {'SHIFT'},
				order = 30,
			},
			headerCtrl = { type = 'header', name = 'Control', order = 40 },
			bindingsCtrl = {
				type = 'description',
				fontSize = 'medium',
				name = GetCliqueBindings,
				arg  = {'CTRL'},
				order = 50,
			},
			headerAlt = { type = 'header', name = 'Alt', order = 60 },
			bindingsAlt = {
				type = 'description',
				fontSize = 'medium',
				name = GetCliqueBindings,
				arg  = {'ALT'},
				order = 70,
			},
			headerShiftControl = { type = 'header', name = 'Shift+Control', order = 80 },
			bindingsShiftControl = {
				type = 'description',
				fontSize = 'medium',
				name = GetCliqueBindings,
				arg  = {'SHIFT', 'CTRL'},
				order = 90,
			},
			headerShiftAlt = { type = 'header', name = 'Shift+Alt', order = 100 },
			bindingsShiftAlt = {
				type = 'description',
				fontSize = 'medium',
				name = GetCliqueBindings,
				arg  = {'SHIFT', 'ALT'},
				order = 110,
			},
			headerCtrlAlt = { type = 'header', name = 'Alt+Control', order = 120 },
			bindingsCtrlAlt = {
				type = 'description',
				fontSize = 'medium',
				name = GetCliqueBindings,
				arg  = {'CTRL', 'ALT'},
				order = 130,
			},
			headerShiftAltCtrl = { type = 'header', name = 'Shift+Alt+Control', order = 140 },
			bindingsShiftAltCtrl = {
				type = 'description',
				fontSize = 'medium',
				name = GetCliqueBindings,
				arg  = {'CTRL', 'ALT', 'SHIFT'},
				order = 150,
			},
		},
	})
	local panel = LibStub('AceConfigDialog-3.0'):AddToBlizOptions('CliqueBindings', 'Bindings', 'Clique')
	InterfaceOptionsFrame_OpenToCategory(panel)
end

-- create a fake configuration panel
local panel = CreateFrame('Frame')
	  panel.name = 'Bindings'
	  panel.parent = 'Clique'
	  panel:Hide()
	  panel:SetScript('OnShow', CliqueOpenConfiguration)
InterfaceOptions_AddCategory(panel)
