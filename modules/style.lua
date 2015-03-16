local addonName, addon, _ = ...
local plugin = addon:NewModule('Style', 'AceEvent-3.0')

-- GLOBALS: _G,
-- GLOBALS:
-- GLOBALS: hooksecurefunc

local function AddSharedMedia(LSM)
	local path = 'Interface\\Addons\\Midget\\media\\'
	LSM:Register("border", "Glow", 			path .. "border\\glow.tga")
	LSM:Register("border", "Inner Glow", 	path .. "border\\inner_glow.tga")
	LSM:Register("border", "Double", 		path .. "border\\double_border.tga")
	LSM:Register("border", "2px", 			path .. "border\\2px.tga")
	LSM:Register("border", "Diablo", 		path .. "border\\diablo.tga")
	LSM:Register("statusbar", "Smooth", 	path .. "statusbar\\Smooth.tga")
	LSM:Register("statusbar", "TukTex", 	path .. "statusbar\\TukTexture.tga")
	LSM:Register("statusbar", "Solid", 		path .. "statusbar\\solid.tga")
	LSM:Register("font", "Andika Compact", 	path .. "Andika-font\\Compact.ttf")
	LSM:Register("font", "Andika", 			path .. "font\\Andika.ttf")
	LSM:Register("font", "Avant Garde", 	path .. "font\\AvantGarde.ttf")
	LSM:Register("font", "Cibreo", 			path .. "font\\Cibreo.ttf")
	LSM:Register("font", "DejaWeb", 		path .. "font\\DejaWeb.ttf")
	LSM:Register("font", "Express", 		path .. "font\\express.ttf")
	LSM:Register("font", "Futura Medium", 	path .. "font\\FuturaMedium.ttf")
	LSM:Register("font", "Paralucent", 		path .. "font\\Paralucent.ttf")
	LSM:Register("font", "Calibri", 		path .. "font\\Calibri.ttf")
	LSM:Register("font", "Calibri Bold", 	path .. "font\\CalibriBold.ttf")
	LSM:Register("font", "Calibri Italic", 	path .. "font\\CalibriItalic.ttf")
	LSM:Register("font", "Calibri Bold Italic", path .. "font\\CalibriBoldItalic.ttf")
	LSM:Register("font", "Accidental Presidency", path .. "font\\AccidentalPresidency.ttf")
end

-- ----------------------------------------------------

local LibMasque       = LibStub('Masque', true)
local LibSpellWidget  = LibStub('LibSpellWidget-1.0', true)
local LibPlayerSpells = LibStub('LibPlayerSpells-1.0', true)

local function UpdateSpellWidget(self, spell)
	if not spell or not self.hasMasque then return end
	if LibPlayerSpells then
		local flags = LibPlayerSpells:GetSpellInfo(spell)
		if not flags then
			self.Border:Hide()
		elseif bit.band(flags, LibPlayerSpells.constants.BURST) > 0 then
			self.Border:SetVertexColor(0, 1, 0, 1)
			self.Border:Show()
		elseif bit.band(flags, LibPlayerSpells.constants.SURVIVAL) > 0 then
			self.Border:SetVertexColor(1, 0, 0, 1)
			self.Border:Show()
		elseif bit.band(flags, LibPlayerSpells.constants.MANA_REGEN) > 0 or bit.band(flags, LibPlayerSpells.constants.POWER_REGEN) > 0 then
			self.Border:SetVertexColor(0, 0, 1, 1)
			self.Border:Show()
		elseif bit.band(flags, LibPlayerSpells.constants.COOLDOWN) > 0 or bit.band(flags, LibPlayerSpells.constants.IMPORTANT) > 0 then
			self.Border:SetVertexColor(.5, 0, .5, 1)
			self.Border:Show()
		else
			self.Border:Hide()
		end
	end
	LibMasque:Group('LibSpellWidget'):ReSkin()
end

local function CreateSpellWidget(self, widget)
	local border = widget:CreateTexture(nil, 'OVERLAY')
	      border:SetTexture('Interface\\Buttons\\UI-ActionButton-Border')
	      border:SetAllPoints()
	      border:Hide()
	widget.Border = border

	local normal = widget:CreateTexture(nil, 'BACKGROUND')
	      normal:SetTexture('Interface\\Buttons\\UI-Quickslot2')
	      normal:SetAllPoints()
	widget.Normal = normal

	-- now apply Masque to it
	LibMasque:Group('LibSpellWidget'):AddButton(widget, {
		Icon         = widget.Icon,
		Cooldown     = widget.Cooldown,
		Count        = widget.Count,
		Normal       = widget.Normal,
		Border       = widget.Border,

		-- don't try to find these textures
		Pushed       = false,
		Disabled     = false,
		Checked      = false,
		FloatingBG   = false,
		Flash        = false,
		AutoCastable = false,
		Highlight    = false,
		HotKey       = false,
		Name         = false,
		Duration     = false,
		AutoCast     = false,
	})
	widget.hasMasque = true
end

function plugin:OnEnable()
	local LSM = LibStub('LibSharedMedia-3.0', true)
	if LSM and addon.db.profile.moreSharedMedia then
		AddSharedMedia(LSM)
	end

	if LibMasque and LibSpellWidget then
		-- API needed for Masque to work properly
		LibSpellWidget.proto.SetNormalTexture = function(self) end
		LibSpellWidget.proto.GetNormalTexture = function(self) return self.Normal end
		hooksecurefunc(LibSpellWidget.proto, 'SetSpell', UpdateSpellWidget)

		local Create = LibSpellWidget.Create
		function LibSpellWidget:Create()
			-- create widget as usual
			local widget = Create(self)
			CreateSpellWidget(self, widget)

			return widget
		end
	end
end

function plugin:OnDisable()
end
