local addonName, addon, _ = ...
local plugin = addon:NewModule('Bagnon', 'AceEvent-3.0')

-- GLOBALS: _G,
-- GLOBALS:
-- GLOBALS: hooksecurefunc

local InitReagentBankSwitcher
function plugin:OnEnable()
	addon:LoadWith('Bagnon', InitReagentBankSwitcher)
end

function plugin:OnDisable()
	addon:LoadWith('Bagnon', InitReagentBankSwitcher, true)
end

-- --------------------------------------------------------
--  Reagents/Bank Toggle
-- --------------------------------------------------------
InitReagentBankSwitcher = function(self, event, otherAddon)

local L = LibStub('AceLocale-3.0'):GetLocale('Bagnon')
local ReagentsToggle = Bagnon:NewClass('ReagentsToggle', 'Button')

local SIZE = 20
local NORMAL_TEXTURE_SIZE = 64 * (SIZE/36)


--[[ Constructor ]]--

function ReagentsToggle:New(parent)
	local b = self:Bind(CreateFrame('Button', nil, parent))
	b:SetWidth(SIZE)
	b:SetHeight(SIZE)
	b:RegisterForClicks('anyUp')

	local nt = b:CreateTexture()
	nt:SetTexture([[Interface\Buttons\UI-Quickslot2]])
	nt:SetWidth(NORMAL_TEXTURE_SIZE)
	nt:SetHeight(NORMAL_TEXTURE_SIZE)
	nt:SetPoint('CENTER', 0, -1)
	b:SetNormalTexture(nt)

	local pt = b:CreateTexture()
	pt:SetTexture([[Interface\Buttons\UI-Quickslot-Depress]])
	pt:SetAllPoints(b)
	b:SetPushedTexture(pt)

	local ht = b:CreateTexture()
	ht:SetTexture([[Interface\Buttons\ButtonHilight-Square]])
	ht:SetAllPoints(b)
	b:SetHighlightTexture(ht)

	local icon = b:CreateTexture()
	icon:SetAllPoints(b)
	icon:SetTexture('Interface\\Icons\\Achievement_GuildPerk_BountifulBags')
	b.icon = icon

	b:SetScript('OnClick', b.OnClick)
	b:SetScript('OnEnter', b.OnEnter)
	b:SetScript('OnLeave', b.OnLeave)

	-- update state: unlocked, displayed
	b:RegisterMessage('BAG_TOGGLED', 'Update')
	b:RegisterEvent('REAGENTBANK_PURCHASED', 'Update')
	b:Update()

	return b
end

function ReagentsToggle:Update(...)
	if IsReagentBankUnlocked() then
		self.icon:SetVertexColor(1, 1, 1)
	else
		self.icon:SetVertexColor(1, .1, .1)
	end

	if Bagnon:IsBagShown(self:GetFrame(), REAGENTBANK_CONTAINER) then
		self.icon:SetTexture('Interface\\Buttons\\Button-Backpack-Up')
		self.tooltip = 'Show Bank'
	else
		self.icon:SetTexture('Interface\\Icons\\Achievement_GuildPerk_BountifulBags')
		self.tooltip = 'Show Reagent Bank'
	end
end

--[[ Interaction ]]--

function ReagentsToggle:OnClick()
	local hidden = self:GetProfile().hiddenBags
	local show, hide = REAGENTBANK_CONTAINER, BANK_CONTAINER
	if self:GetSettings().exclusiveReagent and not hidden[REAGENTBANK_CONTAINER] then
		show = BANK_CONTAINER
		hide = REAGENTBANK_CONTAINER
	end
	hidden[show] = false
	hidden[hide] = true

	self:SendMessage('BAG_TOGGLED', show)
end

function ReagentsToggle:OnEnter()
	if self:GetRight() > (GetScreenWidth() / 2) then
		GameTooltip:SetOwner(self, 'ANCHOR_LEFT')
	else
		GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
	end

	GameTooltip:SetText(self.tooltip)
end

function ReagentsToggle:OnLeave()
	if GameTooltip:IsOwned(self) then
		GameTooltip:Hide()
	end
end

--[[ Frame integration ]]--

function Bagnon.Frame:CreateReagentsToggle()
	local f = Bagnon.ReagentsToggle:New(self)
	self.reagentsToggle = f
	return f
end

function Bagnon.Frame:PlaceReagentsToggle()
	if self:HasReagentsToggle() then
		local toggle = self.reagentsToggle or self:CreateReagentsToggle()
		toggle:ClearAllPoints()
		toggle:SetPoint('TOPRIGHT', self, 'TOPRIGHT', -32, -8)
		toggle:Show()

		return toggle:GetWidth(), toggle:GetHeight()
	elseif self.reagentsToggle then
		self.reagentsToggle:Hide()
	end
	return 0,0
end

function Bagnon.Frame:HasReagentsToggle()
	return GetAddOnEnableState(UnitName('player'), 'Bagnon_Config') >= 2 and self:GetSettings().exclusiveReagent
end

-- button display
hooksecurefunc(Bagnon.Frame, 'PlaceSearchFrame', function(self)
	local frame = self.searchFrame
	if self:HasReagentsToggle() then
		frame:SetPoint('RIGHT', self.reagentsToggle, 'LEFT', -2, 0)
	else
		if self:HasOptionsToggle() then
			frame:SetPoint('RIGHT', self.optionsToggle, 'LEFT', -2, 0)
		else
			frame:SetPoint('RIGHT', self.closeButton, 'LEFT', -2, 0)
		end
	end
end)
hooksecurefunc(Bagnon.Frame, 'PlaceTitleFrame', function(self)
	local frame = self.titleFrame
	if self:HasReagentsToggle() then
		frame:SetPoint('RIGHT', self.reagentsToggle, 'LEFT', -4, 0)
	else
		if self:HasOptionsToggle() then
			frame:SetPoint('RIGHT', self.optionsToggle, 'LEFT', -4, 0)
		else
			frame:SetPoint('RIGHT', self.closeButton, 'LEFT', -4, 0)
		end
	end
end)
hooksecurefunc(Bagnon.Frame, 'Layout', function(self)
	if not self:IsVisible() or self.frameID ~= 'bank' then return end

	local width = self.width + self:PlaceReagentsToggle()

	self.width = max(width, 156)
	self:UpdateSize()
end)

end -- end: Reagens/Bank Toggle
