local _, ns, _ = ...
local addonName, addon, _ = 'Stuffer', {}
_G[addonName] = LibStub('AceAddon-3.0'):NewAddon(addon, addonName, 'AceEvent-3.0')

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
		GetLink      = function(container, slot) return GetContainerItemLink(container, slot) end,
		GetNumSlots  = GetContainerNumSlots,
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
		GetLink      = function(tab, slot) return GetGuildBankItemLink(tab, slot) end,
		GetNumSlots  = function(tab) return tab <= GetNumGuildBankTabs() and _G.MAX_GUILDBANK_SLOTS_PER_TAB or 0 end,
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
		-- GetVoidItemHyperlinkString
		GetLink = function(_, slot)
			local itemID = GetVoidItemInfo(slot)
			return itemID and select(2, GetItemInfo(itemID)) or nil
		end,
		-- VOID_STORAGE_MAX defined as local in Blizzard_VoidStorageUI.lua
		GetNumSlots  = function(tab) return tab == 1 and 80 or 0 end,
		IsSlotLocked = function(_, slot) return select(3, GetVoidItemInfo(slot)) end,
		PickupSlot   = function(_, slot, amount)
			-- note: void storage can't ever contain stackable items
			ClickVoidStorageSlot(slot)
		end,
	},
}

function addon:OnInitialize()
	local defaults = {
		profile = {
			ignoreSlot = { ['*'] = false, },
			ignoreItem = { ['*'] = false, },
			-- TODO: maybe we should split these by scope?
			criteria = {},
		},
	}
	self.db = LibStub('AceDB-3.0'):New(addonName..'DB', defaults, true)
	self.criteria = {}
end

function addon:OnEnable()
	self:AddCriteria('itemID',    function(itemLink, scope, container, slot) return ns.GetItemID(itemLink) end)
	-- self:AddCriteria('container', function(itemLink, scope, container, slot) return container end)
	-- self:AddCriteria('slot',      function(itemLink, scope, container, slot) return slot end)

	--[[ local frame = CreateFrame('Frame', addonName..'Frame', UIParent, "ButtonFrameTemplate")
	      frame:EnableMouse()
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
	local aData = strsplit(META_DELIMITER, aKey, 2)
	wipe(aParts); string.gsub(aData, '([^'..KEY_DELIMITER..']*)'..KEY_DELIMITER..'?', ExplodeA)
	local bData = strsplit(META_DELIMITER, bKey, 2)
	wipe(bParts); string.gsub(bData, '([^'..KEY_DELIMITER..']*)'..KEY_DELIMITER..'?', ExplodeB)
	-- all generated keys use the same number of parts (each part represents a criteria)
	for i = 1, #aParts do
		local aValue, bValue = tonumber(aParts[i]) or aParts[i], tonumber(bParts[i]) or bParts[i]
		if aValue ~= bValue then
			-- TODO: allow descending order, too!
			return aValue < bValue
		end
	end
end

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
	-- FOO = items
	-- SlashCmdList['SPEW']('FOO')
	addon:ApplySort(items, scope, ...)
end

function addon:GenerateSortKey(scope, container, slot)
	local itemLink = scopes[scope or SCOPE_INVENTORY].GetLink(container, slot)
	local itemID   = ns.GetItemID(itemLink)
	if not itemLink or addon:IsSlotIgnored(scope, container, slot) or addon:IsItemIgnored(itemID) then return end

	local key
	for identifier, criteriaFunc in addon:IterateCriteria(scope) do
		key = (key and key..KEY_DELIMITER or '') .. (criteriaFunc(itemLink, scope, container, slot) or '')
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

		local identifier, criteriaFunc
		for i = index, #(addon.db.profile.criteria) do
			identifier = addon.db.profile.criteria[i]
			-- this way we can easily skip non-available criteria
			if addon.criteria[identifier] then
				index = i
				criteriaFunc = addon.criteria[identifier].func
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
		elseif operator == '!=' then
			result = criteriaValue ~= value
		end
		return result and 1 or 0
	end)
end

local function MoveItem(fromContainer, fromSlot, toContainer, toSlot, amount)
	if not (fromContainer and fromSlot and toContainer and toSlot) then return nil end

	-- TODO: get correct scope
	local scope = SCOPE_INVENTORY
	local handler = scopes[scope]

	if not handler.IsSlotLocked(fromContainer, fromSlot) and not handler.IsSlotLocked(toContainer, toSlot) then
		print('Moving item from', fromContainer..'.'..fromSlot, 'to', toContainer..'.'..toSlot)
		ClearCursor()
		handler.PickupSlot(fromContainer, fromSlot, amount)
		handler.PickupSlot(toContainer, toSlot)
		ClearCursor()

		return true
	else
		-- print('Slot(s) locked', fromContainer..'.'..fromSlot, toContainer..'.'..toSlot)
	end
end

-- matches returns foo, bar from a.b.c.foo.bar
-- local container_slot = '([^'..KEY_DELIMITER..']*)'..KEY_DELIMITER..'([^'..KEY_DELIMITER..']*)$'
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

			local itemLink = scopes[scope].GetLink(container, slot)
			local itemID   = ns.GetItemID(itemLink)
			if not addon:IsSlotIgnored(scope, container, slot) and not addon:IsItemIgnored(itemID) then
				local currentItem = addon:GenerateSortKey(scope, container, slot)
				local currentData = strsplit(META_DELIMITER, currentItem)
				local wantedData, _, fromContainer, fromSlot = strsplit(META_DELIMITER, wantedItem)

				if currentData ~= wantedData then
					-- move the item that's supposed to be here into this slot
					print('wanted item', wantedItem, 'current item', currentItem)
					local success = MoveItem(tonumber(fromContainer), tonumber(fromSlot), container, slot)
					if not success then isDone = false end
				end
				listIndex = listIndex + 1
			end
		end
	end

	print('iteration done. ----------------')
	if isDone then
		sorting.items = nil
		sorting.scope = nil
		wipe(sorting.containers)
		addon:UnregisterEvent('BAG_UPDATE_DELAYED')
	else
		addon:RegisterEvent('BAG_UPDATE_DELAYED', addon.ApplySort)
	end
end

--[[ /script Stuffer:Run(nil, 0)
--]]
