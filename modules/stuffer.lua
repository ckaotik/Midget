local _, ns, _ = ...
local addonName, addon, _ = 'Stuffer', {}
_G[addonName] = LibStub('AceAddon-3.0'):NewAddon(addon, addonName)

-- local LPT = LibStub('LibPeriodicTable-3.1', true)
-- local ItemSearch = LibStub('LibItemSearch-1.2')
-- if not ItemSearch:Matches(link, what) then end

-- /script Stuffer:Run(nil, 0) -- scan backback
-- /script table.insert(Stuffer.db.profile.criteria, 'itemID')

local KEY_DELIMITER = '^'
local SCOPE_GUILDBANK, SCOPE_VOIDSTORAGE, SCOPE_INVENTORY = 1, 2, 3
local scopes = {
	-- this assigns 'SCOPE_VOIDSTORAGE' = 3
	SCOPE_INVENTORY = SCOPE_INVENTORY,
	[SCOPE_INVENTORY] = {
		GetLink = function(container, slot) return GetContainerItemLink(container, slot) end,
		GetNumSlots = GetContainerNumSlots,
	},
	SCOPE_GUILDBANK = SCOPE_GUILDBANK,
	[SCOPE_GUILDBANK] = {
		GetLink = function(tab, slot) return GetGuildBankItemLink(tab, slot) end,
		GetNumSlots = function(tab) return tab <= GetNumGuildBankTabs() and _G.MAX_GUILDBANK_SLOTS_PER_TAB or 0 end,
	},
	SCOPE_VOIDSTORAGE = SCOPE_VOIDSTORAGE,
	[SCOPE_VOIDSTORAGE] = {
		-- GetVoidItemHyperlinkString
		GetLink = function(_, slot)
			local itemID = GetVoidItemInfo(slot)
			return itemID and select(2, GetItemInfo(itemID)) or nil
		end,
		-- VOID_STORAGE_MAX defined in Blizzard_VoidStorageUI.lua
		GetNumSlots = function(tab) return tab == 1 and 80 or 0 end,
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
	self:AddCriteria('itemID', function(itemLink, scope, container, slot) return ns.GetItemID(itemLink) end)
	self:AddCriteria('container', function(itemLink, scope, container, slot) return container end)
	self:AddCriteria('slot', function(itemLink, scope, container, slot) return slot end)

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
	wipe(aParts); string.gsub(aKey, '([^'..KEY_DELIMITER..']*)'..KEY_DELIMITER..'?', ExplodeA)
	wipe(bParts); string.gsub(bKey, '([^'..KEY_DELIMITER..']*)'..KEY_DELIMITER..'?', ExplodeB)
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
	assert(..., 'Missing container argument.')
	wipe(items)
	scope = scope or SCOPE_INVENTORY
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
	addon:ApplySort(items)
end

function addon:GenerateSortKey(scope, container, slot)
	if addon:IsSlotIgnored(scope, container, slot) then return end
	local itemLink = scopes[scope or SCOPE_INVENTORY].GetLink(container, slot)
	local itemID   = ns.GetItemID(itemLink)
	if addon:IsItemIgnored(itemID) then return end

	local key
	for identifier, criteriaFunc in addon:IterateCriteria(scope) do
		key = (key and key..KEY_DELIMITER or '') .. (criteriaFunc(itemLink, scope, container, slot) or '')
	end
	-- add our id last, even when already used in criteria
	key = (key and key..KEY_DELIMITER or '') .. scope..KEY_DELIMITER..container..KEY_DELIMITER..slot
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
			-- this way we can easily skip non-available criterias
			if addon.criteria[identifier] then
				index = i
				criteriaFunc = addon.criteria[identifier]
				break
			end
		end
		return identifier, criteriaFunc
	end
end

-- returns filter function, call with either index or identifier
function addon:GetCriteria(identifier)
	if type(identifier) == 'number' then identifier = addon.db.profile.criteria[identifier] end
	return addon.criteria[identifier]
end

-- addon:AddCriteria('myCriteria', function(itemLink, scope, container, slot) return true end)
function addon:AddCriteria(identifier, criteriaFunc, silent)
	assert(identifier and type(identifier) == 'string' and criteriaFunc and type(criteriaFunc) == 'function',
		'Usage: '..addonName..':AddCriteria("identifier", criteriaFunc)')
	if not silent then
		assert(not addon.criteria[identifier], 'A criteria named "'..identifier..'" does already exist.')
	end
	addon.criteria[identifier] = criteriaFunc
end

local function MoveItem(...)
	-- TODO: move x items from a:b to c:d
end
function addon:ApplySort(sortedItems)
	-- TODO: validate, then iterate sortedItems and trigger MoveItem
end
