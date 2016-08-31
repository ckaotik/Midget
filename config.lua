local addonName, addon, _ = ...
local AceConfigDialog = LibStub('AceConfigDialog-3.0')

local function GetConfigurationVariables()
	local types = {
		petBattleTeams = '*none*',
		LFRLootSpecs = '*none*',
	}

	local locale = {}

	-- variable, typeMappings, L, includeNamespaces, callback
	return addon.db, types, locale, true, nil
end

local function InitializeConfiguration(self, args)
	local AceConfig = LibStub('AceConfig-3.0')

	LibStub('LibDualSpec-1.0'):EnhanceDatabase(addon.db, addonName)

	-- Initialize main panel.
	local optionsTable = LibStub('LibOptionsGenerate-1.0'):GetOptionsTable(GetConfigurationVariables())
	      optionsTable.name = addonName
	if AddConfigurationExtras then AddConfigurationExtras(optionsTable) end
	AceConfig:RegisterOptionsTable(addonName, optionsTable)


	-- Add panels for submodules.
	local AceConfigRegistry = LibStub('AceConfigRegistry-3.0')
	for name, subModule in addon:IterateModules() do
		if AceConfigRegistry.tables[subModule.name] then
			AceConfigDialog:AddToBlizOptions(subModule.name, name, addonName)
		end
	end

	if addon.db.defaults and addon.db.defaults.profile and next(addon.db.defaults.profile) then
		-- Add panel for profile settings.
		local profileOptions = LibStub('AceDBOptions-3.0'):GetOptionsTable(addon.db)
		profileOptions.name = addonName .. ' - ' .. profileOptions.name
		AceConfig:RegisterOptionsTable(addonName..'_profiles', profileOptions)
		AceConfigDialog:AddToBlizOptions(addonName..'_profiles', 'Profiles', addonName)
	end

	-- Restore original OnShow handler.
	self:SetScript('OnShow', self.origOnShow)
	self.origOnShow = nil

	InterfaceAddOnsList_Update()
	InterfaceOptionsList_DisplayPanel(self)
end

-- Create a placeholder configuration panel.
local panel = AceConfigDialog:AddToBlizOptions(addonName)
panel.origOnShow = panel:GetScript('OnShow')
panel:SetScript('OnShow', InitializeConfiguration)

-- use slash command to toggle config
_G['SLASH_'..addonName..'1'] = '/'..addonName
_G.SlashCmdList[addonName] = function(args) InterfaceOptionsFrame_OpenToCategory(addonName) end
