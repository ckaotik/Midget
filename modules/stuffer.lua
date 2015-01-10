local _, ns, _ = ...
local addonName, addon, _ = 'Stuffer', {}
_G[addonName] = LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceEvent-3.0')

-- GLOBALS: _G, LibStub
-- GLOBALS: ClearCursor, GetItemInfo, GetContainerItemInfo, GetContainerItemLink, PickupContainerItem, GetGuildBankItemInfo, GetGuildBankItemLink, SplitContainerItem, PickupGuildBankItem, SplitGuildBankItem, GetNumGuildBankTabs, GetVoidItemInfo, ClickVoidStorageSlot
-- GLOBALS: assert, type, wipe, select, ipairs, tonumber, table, string
local strsplit, strjoin = strsplit, strjoin

--[[ Feature Wishlist
	- assign items to bags
	- arrange in patterns
--]]

-- local LPT = LibStub('LibPeriodicTable-3.1', true)
-- local ItemSearch = LibStub('LibItemSearch-1.2')
-- if not ItemSearch:Matches(link, what) then end

-- /script Stuffer:Run(nil, 0) -- scan backback
-- /script table.insert(Stuffer.db.profile.criteria, 'itemID')

-- TODO: remove these delimiters from criteria data
local KEY_DELIMITER, META_DELIMITER = '^', '`'
local SCOPE_GUILDBANK, SCOPE_VOIDSTORAGE, SCOPE_INVENTORY = 1, 2, 3
local scopes = {
	-- this assigns 'SCOPE_VOIDSTORAGE' = 3
	-- SCOPE_INVENTORY = SCOPE_INVENTORY,
	[SCOPE_INVENTORY] = {
		GetNumSlots  = GetContainerNumSlots,
		GetLink      = function(container, slot) return GetContainerItemLink(container, slot) end,
		GetCount     = function(container, slot) return select(2, GetContainerItemInfo(container, slot)) end,
		IsSlotLocked = function(container, slot) return select(3, GetContainerItemInfo(container, slot)) end,
		PickupSlot   = function(container, slot, amount)
			if amount and amount > 0 then
				SplitContainerItem(container, slot, amount)
			else
				PickupContainerItem(container, slot)
			end
		end,
	},
	-- SCOPE_GUILDBANK = SCOPE_GUILDBANK,
	[SCOPE_GUILDBANK] = {
		GetNumSlots  = function(tab) return tab <= GetNumGuildBankTabs() and _G.MAX_GUILDBANK_SLOTS_PER_TAB or 0 end,
		GetLink      = function(tab, slot) return GetGuildBankItemLink(tab, slot) end,
		GetCount     = function(tab, slot) return select(2, GetGuildBankItemInfo(tab, slot)) end,
		IsSlotLocked = function(tab, slot) return select(3, GetGuildBankItemInfo(tab, slot)) end,
		PickupSlot   = function(tab, slot, amount)
			if amount and amount > 0 then
				SplitGuildBankItem(tab, slot, amount)
			else
				PickupGuildBankItem(tab, slot)
			end
		end,
	},
	-- SCOPE_VOIDSTORAGE = SCOPE_VOIDSTORAGE,
	[SCOPE_VOIDSTORAGE] = {
		-- VOID_STORAGE_MAX defined as local in Blizzard_VoidStorageUI.lua
		GetNumSlots  = function(tab) return tab == 1 or tab == 2 and 80 or 0 end,
		-- GetVoidItemHyperlinkString
		GetLink = function(_, slot)
			local itemID = GetVoidItemInfo(slot)
			return itemID and select(2, GetItemInfo(itemID)) or nil
		end,
		GetCount     = function(container, slot) return (GetVoidItemInfo(slot)) and 1 or 0 end,
		IsSlotLocked = function(_, slot) return select(3, GetVoidItemInfo(slot)) end,
		PickupSlot   = function(_, slot, amount)
			-- note: void storage can't ever contain stackable items
			ClickVoidStorageSlot(slot)
		end,
	},
}

function addon:OnInitialize()
	self.criteria = {}
end

function addon:OnEnable()
	local defaults = {
		profile = {
			ignoreSlot = { ['*'] = false, },
			ignoreItem = { ['*'] = false, },
			-- TODO: maybe we should split these by scope?
			criteria = {},
			emptyFirst = false,
		},
	}
	self.db = LibStub('AceDB-3.0'):New(addonName..'DB', defaults, true)

	self:AddCriteria('itemID',    function(itemLink, scope, container, slot) return select(2, ns.GetLinkData(itemLink)) end)
	-- self:AddCriteria('container', function(itemLink, scope, container, slot) return container end)
	-- self:AddCriteria('slot',      function(itemLink, scope, container, slot) return slot end)

	-- static item info
	self:AddCriteria('name', function(itemLink, scope, container, slot) return (select(1, GetItemInfo(itemLink))) end)
	self:AddCriteria('quality', function(itemLink, scope, container, slot) return (select(3, GetItemInfo(itemLink))) end)
	self:AddCriteria('ilevel', function(itemLink, scope, container, slot) return (select(4, GetItemInfo(itemLink))) end)
	self:AddCriteria('level', function(itemLink, scope, container, slot) return (select(5, GetItemInfo(itemLink))) end)
	-- self:AddCriteria('class', function(itemLink, scope, container, slot) return (select(6, GetItemInfo(itemLink))) end)
	-- self:AddCriteria('subclass', function(itemLink, scope, container, slot) return (select(7, GetItemInfo(itemLink))) end)
	self:AddCriteria('maxstack', function(itemLink, scope, container, slot) return (select(8, GetItemInfo(itemLink))) end)
	self:AddCriteria('slot', function(itemLink, scope, container, slot) return (select(9, GetItemInfo(itemLink))) end)
	self:AddCriteria('value', function(itemLink, scope, container, slot) return (select(11, GetItemInfo(itemLink))) or 0 end)

	-- scope specific item data
	self:AddCriteria('stack', function(itemLink, scope, container, slot) return scopes[scope].GetCount(container, slot) end)

	--[[ local frame = CreateFrame('Frame', addonName..'Frame', UIParent, "ButtonFrameTemplate")
	      frame:EnableMouse(true)
	      frame:SetFrameLevel(17)
	      frame:Hide()
	self.frame = frame

	SetPortraitToTexture(addonName..'FramePortrait', 'Interface\\Icons\\TRADE_ARCHAEOLOGY_CHESTOFTINYGLASSANIMALS')
	frame.TitleText:SetText(addonName) -- ..' '..GetAddOnMetadata(addonName, 'Version')) --]]

	--[[ frame:SetWidth(563)
	frame:SetAttribute('UIPanelLayout-defined', true)
	frame:SetAttribute('UIPanelLayout-enabled', true)
	frame:SetAttribute('UIPanelLayout-whileDead', true)
	frame:SetAttribute('UIPanelLayout-area', 'left')
	frame:SetAttribute('UIPanelLayout-pushable', 5)
	frame:SetAttribute('UIPanelLayout-width', 563+20) --]]

	--[[ tinsert(UISpecialFrames, addonName..'Frame')
	UIPanelWindows[addonName..'Frame'] = {
		area = "left",
		pushable = 1,
		whileDead = true,
	}

	-- setup ldb launcher
	self.ldb = LibStub:GetLibrary('LibDataBroker-1.1'):NewDataObject(addonName, {
		type  = 'launcher',
		icon  = 'Interface\\Icons\\TRADE_ARCHAEOLOGY_CHESTOFTINYGLASSANIMALS',
		label = addonName,

		OnClick = function(button, btn, up)
			if btn == 'RightButton' then
				-- open config
				-- InterfaceOptionsFrame_OpenToCategory(Viewda.options)
			else
				ToggleFrame(addon.frame)
			end
		end,
	})

	-- setup dropdown
	local function Select(self)
		local dropdown = UIDROPDOWNMENU_OPEN_MENU
		UIDropDownMenu_SetSelectedValue(dropdown, self.value) -- also sets the text
		UIDropDownMenu_SetText(dropdown, 'Add Criteria')
	end

	local dropdown = CreateFrame('Frame', addonName..'DropdownFrame', self.frame, 'UIDropDownMenuTemplate')
	      dropdown:SetPoint('TOPLEFT', 20, -60)
	      dropdown.displayMode = 'MENU'
	UIDropDownMenu_SetText(dropdown, 'Add Criteria')

	local sampleOptions = {'Equipment', 'Consumable', 'Rarity', 'Uniqueness'}
	dropdown.initialize = function(self, level)
		local selected  = UIDropDownMenu_GetSelectedValue(self)
		local info      = UIDropDownMenu_CreateInfo()

		-- common attributes
		info.func     = Select
		info.isNotRadio = true
		info.keepShownOnClick = true
		info.isTitle  = nil
		info.disabled = nil

		for _, value in ipairs(sampleOptions) do
			info.text = value
			info.value = value
			info.checked = (value == selected)
			info.hasArrow = false

			UIDropDownMenu_AddButton(info, level)
		end
	end --]]
end

-- note: may also be used to ignore entirce scopes/containers
function addon:IsSlotIgnored(scope, container, slot)
	return self.db.profile.ignoreSlot[strjoin(KEY_DELIMITER, scope or SCOPE_INVENTORY, container or 0, slot or 0)]
end
function addon:IsItemIgnored(itemID)
	return self.db.profile.ignoreItem[itemID]
end

local items = {}
local aParts, bParts = {}, {}
local function ExplodeA(part) table.insert(aParts, part) end
local function ExplodeB(part) table.insert(bParts, part) end
local function ItemSort(aKey, bKey)
	local aData, aMeta = strsplit(META_DELIMITER, aKey, 2)
	local bData, bMeta = strsplit(META_DELIMITER, bKey, 2)
	-- empty slots have no data
	if aData == '' and bData == '' then return aMeta < bMeta
	elseif aData == '' then return addon.db.profile.emptyFirst
	elseif bData == '' then return not addon.db.profile.emptyFirst
	end
	-- all generated keys use the same number of parts (each part represents a criteria)
	wipe(aParts); string.gsub(aData, '([^'..KEY_DELIMITER..']*)'..KEY_DELIMITER..'?', ExplodeA)
	wipe(bParts); string.gsub(bData, '([^'..KEY_DELIMITER..']*)'..KEY_DELIMITER..'?', ExplodeB)
	for i = 1, #aParts do
		local aValue, bValue = tonumber(aParts[i]) or aParts[i], tonumber(bParts[i]) or bParts[i]
		if aValue ~= bValue then
			return aValue < bValue
		end
	end
end
--[[ local function ItemSortReverse(aKey, bKey)
	local sorted = ItemSort(aKey, bKey)
	return (sorted == aKey) and bKey or aKey
end --]]

function addon:Run(scope, ...)
	scope = scope or SCOPE_INVENTORY
	assert(..., 'Missing container argument.')

	wipe(items)
	local index, container = 1, select(1, ...)
	while container do
		local numSlots = scopes[scope or SCOPE_INVENTORY].GetNumSlots(container)
		for slot = 1, numSlots do
			local sortKey = addon:GenerateSortKey(scope, container, slot)
			if sortKey then table.insert(items, sortKey) end
		end
		index = index + 1
		container = select(index, ...)
	end

	table.sort(items, ItemSort)
	addon:ApplySort(items, scope, ...)
end

function addon:GenerateSortKey(scope, container, slot)
	local itemLink  = scopes[scope or SCOPE_INVENTORY].GetLink(container, slot)
	local _, itemID = ns.GetLinkData(itemLink)
	if addon:IsSlotIgnored(scope, container, slot) or addon:IsItemIgnored(itemID) then return end

	local key
	if itemLink then
		for identifier, criteriaFunc in addon:IterateCriteria(scope) do
			key = (key and key..KEY_DELIMITER or '') .. (criteriaFunc(itemLink, scope, container, slot) or '')
		end
	end
	-- add our id last, even when already used in criteria
	key = (key or '') .. META_DELIMITER .. scope..META_DELIMITER..container..META_DELIMITER..slot
	return key
end

-- note: argument currently unused
function addon:IterateCriteria(scope)
	local index = 0
	return function()
		index = index + 1

		local identifier, criteriaFunc, label
		for i = index, #(addon.db.profile.criteria) do
			identifier = addon.db.profile.criteria[i]
			-- this way we can easily skip non-available criteria
			if addon.criteria[identifier] then
				index = i
				criteriaFunc = addon.criteria[identifier].func
				label = addon.criteria[identifier].label
				break
			else
				identifier = nil
			end
		end
		return identifier, criteriaFunc, label
	end
end

-- returns filter function, call with either index or identifier
function addon:GetCriteria(identifier)
	if type(identifier) == 'number' then identifier = addon.db.profile.criteria[identifier] end
	local criteria = addon.criteria[identifier]
	return identifier, criteria.label, criteria.func
end

-- addon:AddCriteria('myCriteria', function(itemLink, scope, container, slot) return 'aValueToSortBy' end)
function addon:AddCriteria(identifier, criteriaFunc, label, silent)
	assert(identifier and type(identifier) == 'string' and criteriaFunc and type(criteriaFunc) == 'function',
		'Usage: '..addonName..':AddCriteria("identifier", criteriaFunc[, label[, silent]])')
	if not silent then
		assert(not addon.criteria[identifier], 'A criteria named "'..identifier..'" does already exist.')
	end
	addon.criteria[identifier] = {
		label = label or identifier,
		func = criteriaFunc,
	}
end

-- allows the user to manually order for specific attributes, e.g. "itemID = 1234"
function addon:AddFilter(criteriaIdentifier, value, operator)
	local identifier = strjoin(' ', criteriaIdentifier, operator or '=', value)
	addon:AddCriteria(identifier, function(...)
		local _, _, func = addon:GetCriteria(criteriaIdentifier)
		local criteriaValue = func(...)

		local result
		if not operator or operator == '=' then
			result = criteriaValue == value
		elseif operator == '<' then
			result = criteriaValue < value
		elseif operator == '>' then
			result = criteriaValue > value
		elseif operator == '<=' then
			result = criteriaValue <= value
		elseif operator == '>=' then
			result = criteriaValue >= value
		elseif operator == '!=' or operator == '~=' then
			result = criteriaValue ~= value
		end
		return result and 1 or 0
	end)
end

local function MoveItem(fromScope, fromContainer, fromSlot, toScope, toContainer, toSlot, amount)
	if not (fromContainer and fromSlot and toContainer and toSlot) then return nil end

	local fromHandler = scopes[fromScope or SCOPE_INVENTORY]
	local toHandler   = scopes[toScope or SCOPE_INVENTORY]

	if not fromHandler.IsSlotLocked(fromContainer, fromSlot) and not toHandler.IsSlotLocked(toContainer, toSlot) then
		-- print('Moving item from', fromContainer..'.'..fromSlot, 'to', toContainer..'.'..toSlot)
		ClearCursor()
		fromHandler.PickupSlot(fromContainer, fromSlot, amount)
		toHandler.PickupSlot(toContainer, toSlot)
		ClearCursor()

		return true
	else
		-- print('Slot(s) locked', fromContainer..'.'..fromSlot, toContainer..'.'..toSlot)
	end
end

local sorting = { containers = {} }
function addon:ApplySort(sortedItems, scope, ...)
	-- store sort parameters
	if sortedItems and scope and ... then
		-- not checking if sorting is already set, this way we can override last instruction
		sorting.items = sortedItems
		sorting.scope = scope
		wipe(sorting.containers)
		for i = 1, select('#', ...) do
			local container = select(i, ...)
			table.insert(sorting.containers, container)
		end
	end
	-- use what's in our sorting table
	sortedItems, scope = sorting.items, sorting.scope

	local isDone = true
	local listIndex = 1
	for index, container in ipairs(sorting.containers) do
		for slot = 1, scopes[scope].GetNumSlots(container) do
			local wantedItem = sortedItems[listIndex]
			if not wantedItem then break end -- TODO: really?

			local itemLink  = scopes[scope].GetLink(container, slot)
			local _, itemID = ns.GetLinkData(itemLink)
			if not addon:IsSlotIgnored(scope, container, slot) and not addon:IsItemIgnored(itemID) then
				local currentItem = addon:GenerateSortKey(scope, container, slot)
				local currentData = strsplit(META_DELIMITER, currentItem)
				local wantedData, fromScope, fromContainer, fromSlot = strsplit(META_DELIMITER, wantedItem)

				if currentData ~= wantedData then
					-- move the item that's supposed to be here into this slot
					-- print('wanted item', wantedItem, 'current item', currentItem)
					local success = MoveItem(tonumber(fromScope), tonumber(fromContainer), tonumber(fromSlot), scope, container, slot)
					if success then
						-- update location information since items were swapped
						sortedItems[listIndex] = strjoin(META_DELIMITER, wantedData, scope, container, slot)
						for index, item in ipairs(sortedItems) do
							if item == currentItem then -- TODO: what happens when slot is empty?
								sortedItems[index] = strjoin(META_DELIMITER, currentData, fromScope, fromContainer, fromSlot)
								break
							end
						end
					else
						isDone = false
					end
				end
				listIndex = listIndex + 1
			end
		end
	end

	-- print('iteration done. ----------------')
	if isDone then
		sorting.items = nil
		sorting.scope = nil
		wipe(sorting.containers)
		addon:UnregisterEvent('BAG_UPDATE_DELAYED')
		print('|cff49DEB1'..addonName..'|r Completed moving items')
	else
		addon:RegisterEvent('BAG_UPDATE_DELAYED', addon.ApplySort)
	end
end

-- /script Stuffer:Run(nil, 0)
-- /script Stuffer:Run(nil, 0,1,2,3,4)
-- FOO = items
-- SlashCmdList['SPEW']('FOO')










local function OpenConfiguration(self, args)
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
	LibStub('LibDualSpec-1.0'):EnhanceDatabase(addon.db, addonName)
	LibStub('AceConfig-3.0'):RegisterOptionsTable(addonName, {
		type = 'group',
		args = {
			general  = LibStub('LibOptionsGenerate-1.0'):GetOptionsTable(addon.db),
			profiles = LibStub('AceDBOptions-3.0'):GetOptionsTable(addon.db)
		},
	})
	local AceConfigDialog = LibStub('AceConfigDialog-3.0')
	AceConfigDialog:AddToBlizOptions(addonName, nil, nil, 'general')
	AceConfigDialog:AddToBlizOptions(addonName, 'Profiles', addonName, 'profiles')

	OpenConfiguration = function(panel, args)
		InterfaceOptionsFrame_OpenToCategory(addonName)
	end
	OpenConfiguration(self, args)
end

-- create a fake configuration panel
local panel = CreateFrame('Frame')
      panel.name = addonName
      panel:Hide()
      panel:SetScript('OnShow', OpenConfiguration)
InterfaceOptions_AddCategory(panel)

-- use slash command to toggle config
local slashName = addonName:upper()
_G['SLASH_'..slashName..'1'] = '/'..addonName
_G.SlashCmdList[slashName] = function(args) OpenConfiguration(panel, args) end
