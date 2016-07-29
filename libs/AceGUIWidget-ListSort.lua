local data = {
	'lorem',
	'ipsum',
	'dolor',
	'foo',
	'bar',
	'1337',
	'x',
}

local function FOO()
	local numRows, padding, dropIndicator = 6, 4, nil
	local function CreateRow(identifier, parent)
		local button = CreateFrame('Button', '$parentButton'..identifier, parent, nil, identifier)
		      button:SetHeight(20)

		button:SetNormalTexture('Interface\\CURSOR\\UI-Cursor-Move')
		local tex = button:GetNormalTexture()
		      tex:SetSize(16, 16)
		      tex:ClearAllPoints()
		      tex:SetPoint('LEFT', 2, 0)
		button:SetHighlightTexture('Interface\\Buttons\\UI-PlusButton-Hilight', 'ADD')
		local tex = button:GetHighlightTexture()
		      tex:SetSize(16, 16)
		      tex:ClearAllPoints()
		      tex:SetPoint('LEFT', 3, 0)

		button:SetHighlightFontObject('GameFontHighlightLeft')
		button:SetDisabledFontObject('GameFontHighlightLeft')
		button:SetNormalFontObject('GameFontNormalLeft')

		local label = button:CreateFontString(nil, nil, 'GameFontNormalLeft')
		      label:SetPoint('TOPLEFT', 26, 0)
		      label:SetPoint('BOTTOMRIGHT')
		      label:SetJustifyH('LEFT')
		button:SetFontString(label)

		return button
	end

	local function Update(self)
		local offset = FauxScrollFrame_GetOffset(self)
		for i, button in ipairs(self) do
			local index = i + offset
			-- TODO: allow assoc data tables and create sorttable
			local label = self.data[index]
			if label then
				button:SetText(label)
				button:SetAlpha((dropIndicator.index == index) and 0.5 or 1)
				button:Show()
			else
				button:Hide()
			end
			button.index = index
		end
		-- alwaysShowScrollBar: true, so we're not hiding with <= #self rows
		FauxScrollFrame_Update(self, #data, #self, self[1]:GetHeight(), nil, nil, nil, nil, nil, nil, true)
	end
	local function UpdateDragging(self, elapsed)
		local parent, frameAbove = self:GetParent()
		local rowHeight = self:GetHeight()
		for index, button in ipairs(parent) do
			if button:IsMouseOver(0, 0, rowHeight/2, 0) then
				frameAbove = button
				break
			end
		end
		dropIndicator:StopMovingOrSizing()
		dropIndicator:SetPoint('LEFT', frameAbove or parent[#parent], frameAbove and 'TOPLEFT' or 'BOTTOMLEFT')
	end
	local function OnDragStart(self, btn)
		self:SetAlpha(0.5)

		if not dropIndicator:IsClampedToScreen() then
			-- first time dragging, do some setup
			local screenWidth, screenHeight   = GetScreenWidth(), GetScreenHeight()
			local left, bottom, width, height = self:GetParent():GetRect()
			dropIndicator:SetClampedToScreen(true)
			dropIndicator:SetClampRectInsets(-left-padding, screenWidth-left-width+padding, screenHeight-bottom-height, -bottom)
		end
		dropIndicator:SetAllPoints(self)
		dropIndicator:SetText(self:GetText())
		dropIndicator.index = self.index
		dropIndicator:Show()
		dropIndicator:StartMoving() -- attach dropIndicator to mouse
		dropIndicator:SetScript('OnUpdate', UpdateDragging)
	end
	local function OnDragStop(self)
		local _, anchor, position = dropIndicator:GetPoint()
		local oldIndex, anchorIndex = dropIndicator.index, anchor.index
		local newIndex = position == 'TOPLEFT' and anchorIndex or (anchorIndex + 1)

		local listFrame = self:GetParent()
		table.insert(listFrame.data, newIndex, listFrame.data[oldIndex])
		table.remove(listFrame.data, newIndex > oldIndex and oldIndex or (oldIndex + 1))
		Update(listFrame)

		self:SetAlpha(1)
		dropIndicator.index = nil
		dropIndicator:SetScript('OnUpdate', nil)
		dropIndicator:StopMovingOrSizing()
		dropIndicator:Hide()
		dropIndicator:SetUserPlaced(false)
	end

	local backdrop = {
		bgFile   = 'Interface\\Tooltips\\UI-Tooltip-Background',
		edgeFile = 'Interface\\Tooltips\\UI-Tooltip-Border', edgeSize = 16,
		insets   = { left = 4, right = 3, top = 4, bottom = 3 }
	}
	local listFrame = CreateFrame('ScrollFrame', 'SampleScrollFrame', UIParent, 'FauxScrollFrameTemplate')
	      listFrame:SetBackdrop(backdrop)
	      listFrame:SetBackdropColor(0, 0, 0, 0.5)
	      listFrame:SetBackdropBorderColor(1, 1, 1, 1)
	listFrame.scrollBarHideable = true
	listFrame:SetScript('OnVerticalScroll', function(scrollFrame, offset)
		local rowHeight = scrollFrame[1]:GetHeight()
		FauxScrollFrame_OnVerticalScroll(scrollFrame, offset, rowHeight, Update)
	end)

	listFrame:SetPoint('CENTER', 100, 50)   -- *
	listFrame:SetSize(300, 130)             -- *
	listFrame.data = data                   -- *
	-- TODO: what happens to drag constraints when the frame containing listFrame gets moved?

	local label = listFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormalSmall')
	      label:SetPoint('TOPLEFT',  listFrame, 'TOPLEFT', 4, 10)
	      label:SetPoint('TOPRIGHT', listFrame, 'TOPRIGHT', -4, 10)
	      label:SetJustifyH('LEFT')
	      label:SetHeight(10)

	-- drag & drop
	dropIndicator = CreateRow('Dummy', listFrame)
	dropIndicator:SetMovable(true)
	dropIndicator:Hide()

	local rowHeight
	for index = 1, numRows do
		local button = CreateRow(index, listFrame)
		table.insert(listFrame, button)

		button:RegisterForDrag('LeftButton')
		button:SetScript('OnDragStart', OnDragStart)
		button:SetScript('OnDragStop',  OnDragStop)

		if index == 1 then rowHeight = button:GetHeight() end
		button:SetPoint('TOPLEFT', listFrame, 'TOPLEFT', padding, -padding - (index-1)*rowHeight)
		button:SetPoint('RIGHT', listFrame, 'RIGHT', -padding, 0)
	end
	FauxScrollFrame_OnVerticalScroll(listFrame, 0, rowHeight, Update)
end

if true then return end

local AceGUI = LibStub('AceGUI-3.0')
local widgetType = 'ListSort'
local widgetVersion = 1

--[[-----------------------------------------------------------------------------
Support functions
-------------------------------------------------------------------------------]]
local function Layout(self)
	--[[ self:SetHeight(self.numlines * 14 + (self.disablebutton and 19 or 41) + self.labelHeight)

	if self.labelHeight == 0 then
		self.scrollBar:SetPoint("TOP", self.frame, "TOP", 0, -23)
	else
		self.scrollBar:SetPoint("TOP", self.label, "BOTTOM", 0, -19)
	end

	if self.disablebutton then
		self.scrollBar:SetPoint("BOTTOM", self.frame, "BOTTOM", 0, 21)
		self.scrollBG:SetPoint("BOTTOMLEFT", 0, 4)
	else
		self.scrollBar:SetPoint("BOTTOM", self.button, "TOP", 0, 18)
		self.scrollBG:SetPoint("BOTTOMLEFT", self.button, "TOPLEFT")
	end --]]
end

--[[-----------------------------------------------------------------------------
Scripts
-------------------------------------------------------------------------------]]
local function OnEnter(self)                                                     -- ScrollFrame
	self = self.obj
	if not self.entered then
		self.entered = true
		self:Fire("OnEnter")
	end
end

local function OnLeave(self)                                                     -- ScrollFrame
	self = self.obj
	if self.entered then
		self.entered = nil
		self:Fire("OnLeave")
	end
end

local function OnVerticalScroll(self, offset)                                    -- ScrollFrame
	local rowHeight = self[1]:GetHeight()
	FauxScrollFrame_OnVerticalScroll(self, offset, rowHeight, Update)
end

--[[ local function OnSizeChanged(self, width, height)                                -- ScrollFrame
	self.obj.editBox:SetWidth(width)
end --]]

--[[-----------------------------------------------------------------------------
Methods
-------------------------------------------------------------------------------]]
local methods = {
	["OnAcquire"] = function(self)
		self.editBox:SetText("")
		self:SetDisabled(false)
		self:SetWidth(200)
		self:DisableButton(false)
		self:SetNumLines()
		self.entered = nil
		self:SetMaxLetters(0)
	end,

	["OnRelease"] = function(self)
		self:ClearFocus()
	end,

	["SetDisabled"] = function(self, disabled)
		local editBox = self.editBox
		if disabled then
			editBox:ClearFocus()
			editBox:EnableMouse(false)
			editBox:SetTextColor(0.5, 0.5, 0.5)
			self.label:SetTextColor(0.5, 0.5, 0.5)
			self.scrollFrame:EnableMouse(false)
			self.button:Disable()
		else
			editBox:EnableMouse(true)
			editBox:SetTextColor(1, 1, 1)
			self.label:SetTextColor(1, 0.82, 0)
			self.scrollFrame:EnableMouse(true)
		end
	end,

	["SetLabel"] = function(self, text)
		if text and text ~= "" then
			self.label:SetText(text)
			if self.labelHeight ~= 10 then
				self.labelHeight = 10
				self.label:Show()
			end
		elseif self.labelHeight ~= 0 then
			self.labelHeight = 0
			self.label:Hide()
		end
		Layout(self)
	end,

	["SetNumLines"] = function(self, value)
		if not value or value < 4 then
			value = 4
		end
		self.numlines = value
		Layout(self)
	end,
}

--[[-----------------------------------------------------------------------------
Constructor
-------------------------------------------------------------------------------]]
local backdrop = {
	bgFile   = [[Interface\Tooltips\UI-Tooltip-Background]],
	edgeFile = [[Interface\Tooltips\UI-Tooltip-Border]], edgeSize = 16,
	insets   = { left = 4, right = 3, top = 4, bottom = 3 }
}

local function Constructor()
	local frame = CreateFrame("Frame", nil, UIParent)
	      frame:Hide()

	local widgetNum = AceGUI:GetNextWidgetNum(widgetType)

	local label = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	      label:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -4)
	      label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -4)
	      label:SetJustifyH("LEFT")
	      label:SetText(ACCEPT)
	      label:SetHeight(10)

	local scrollFrame = CreateFrame("ScrollFrame", ("%s%dScrollFrame"):format(widgetType, widgetNum), frame, "UIPanelScrollFrameTemplate")
	scrollFrame:SetPoint("TOPLEFT", scrollBG, "TOPLEFT", 5, -6)
	scrollFrame:SetPoint("BOTTOMRIGHT", scrollBG, "BOTTOMRIGHT", -4, 4)
	scrollFrame:SetScript("OnEnter", OnEnter)
	scrollFrame:SetScript("OnLeave", OnLeave)
	scrollFrame:SetScript("OnMouseUp", OnMouseUp)
	-- scrollFrame:SetScript("OnSizeChanged", OnSizeChanged)
	scrollFrame:SetScript("OnVerticalScroll", OnVerticalScroll)


	--[[ local scrollBar = _G[scrollFrame:GetName() .. "ScrollBar"]
	      scrollBar:ClearAllPoints()
	      scrollBar:SetPoint("TOP", label, "BOTTOM", 0, -19)
	      scrollBar:SetPoint("BOTTOM", button, "TOP", 0, 18)
	      scrollBar:SetPoint("RIGHT", frame, "RIGHT") --]]

	--[[ local scrollBG = CreateFrame("Frame", nil, frame)
	      scrollBG:SetBackdrop(backdrop)
	      scrollBG:SetBackdropColor(0, 0, 0)
	      scrollBG:SetBackdropBorderColor(0.4, 0.4, 0.4)
	scrollBG:SetPoint("TOPRIGHT", scrollBar, "TOPLEFT", 0, 19)
	scrollBG:SetPoint("BOTTOMLEFT", button, "TOPLEFT") --]]

	local widget = {
		type        = widgetType,
		frame       = frame,

		label       = label,
		labelHeight = 10,
		numlines    = 6,
		-- scrollBar   = scrollBar,
		-- scrollBG    = scrollBG,
		scrollFrame = scrollFrame,
	}
	for method, func in pairs(methods) do
		widget[method] = func
	end
	button.obj, editBox.obj, scrollFrame.obj = widget, widget, widget

	return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(widgetType, Constructor, widgetVersion)









if true then return end
--[[

do
	local widgetType = 'ListSort'
	local widgetVersion = 1

	local contentFrameCache = {}
	local function ReturnSelf(self)
		self:ClearAllPoints()
		self:Hide()
		self.check:Hide()
		table.insert(contentFrameCache, self)
	end

	local function ContentOnClick(this, button)
		local self = this.obj
		self:Fire("OnValueChanged", this.text:GetText())
		if self.dropdown then
			self.dropdown = AGSMW:ReturnDropDownFrame(self.dropdown)
		end
	end

	local function GetContentLine()
		local frame
		if next(contentFrameCache) then
			frame = table.remove(contentFrameCache)
		else
			frame = CreateFrame("Button", nil, UIParent)
				--frame:SetWidth(200)
				frame:SetHeight(18)
				frame:SetHighlightTexture([=[Interface\QuestFrame\UI-QuestTitleHighlight]=], "ADD")
				frame:SetScript("OnClick", ContentOnClick)
			local check = frame:CreateTexture("OVERLAY")
				check:SetWidth(16)
				check:SetHeight(16)
				check:SetPoint("LEFT",frame,"LEFT",1,-1)
				check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
				check:Hide()
			frame.check = check
			local bar = frame:CreateTexture("ARTWORK")
				bar:SetHeight(16)
				bar:SetPoint("LEFT",check,"RIGHT",1,0)
				bar:SetPoint("RIGHT",frame,"RIGHT",-1,0)
			frame.bar = bar
			local text = frame:CreateFontString(nil,"OVERLAY","GameFontWhite")

				local font, size = text:GetFont()
				text:SetFont(font,size,"OUTLINE")

				text:SetPoint("LEFT", check, "RIGHT", 3, 0)
				text:SetPoint("RIGHT", frame, "RIGHT", -2, 0)
				text:SetJustifyH("LEFT")
				text:SetText("Test Test Test Test Test Test Test")
			frame.text = text
			frame.ReturnSelf = ReturnSelf
		end
		frame:Show()
		return frame
	end

	local function OnAcquire(self)
		self:SetHeight(44)
		self:SetWidth(200)
	end
	local function OnRelease(self)
		self:SetText("")
		self:SetLabel("")
		self:SetDisabled(false)

		self.value = nil
		self.list = nil
		self.open = nil
		self.hasClose = nil

		self.frame:ClearAllPoints()
		self.frame:Hide()
	end

	local function GetValue(self)
		return self.value
	end
	local function SetValue(self, value) -- Set the value to an item in the List.
		if self.list then
			self:SetText(value or "")
		end
		self.value = value
	end

	local function SetList(self, list) -- Set the list of values for the dropdown (key => value pairs)
		self.list = list or Media:HashTable("statusbar")
	end

	local function SetText(self, text) -- Set the text displayed in the box.
		self.frame.text:SetText(text or "")
		local statusbar = self.list[text] ~= text and self.list[text] or Media:Fetch('statusbar',text)
		self.bar:SetTexture(statusbar)
	end

	local function SetLabel(self, text) -- Set the text for the label.
		self.frame.label:SetText(text or "")
	end

	local function AddItem(self, key, value) -- Add an item to the list.
		self.list = self.list or {}
		self.list[key] = value
	end
	local SetItemValue = AddItem -- Set the value of a item in the list. <<same as adding a new item>>

	-- Toggle multi-selecting. <<Dummy function to stay inline with the dropdown API>>
	local function SetMultiselect(self, flag) end
	-- Query the multi-select flag. <<Dummy function to stay inline with the dropdown API>>
	local function GetMultiselect() return false end
	-- Disable one item in the list. <<Dummy function to stay inline with the dropdown API>>
	local function SetItemDisabled(self, key) end

	local function SetDisabled(self, disabled) -- Disable the widget.
		self.disabled = disabled
		if disabled then
			self.frame:Disable()
		else
			self.frame:Enable()
		end
	end

	local function textSort(a,b)
		return string.upper(a) < string.upper(b)
	end

	local sortedlist = {}
	local function ToggleDrop(this)
		local self = this.obj
		if self.dropdown then
			self.dropdown = AGSMW:ReturnDropDownFrame(self.dropdown)
			AceGUI:ClearFocus()
		else
			AceGUI:SetFocus(self)
			self.dropdown = AGSMW:GetDropDownFrame()
			local width = self.frame:GetWidth()
			self.dropdown:SetPoint("TOPLEFT", self.frame, "BOTTOMLEFT")
			self.dropdown:SetPoint("TOPRIGHT", self.frame, "BOTTOMRIGHT", width < 160 and (160 - width) or 0, 0)
			for k, v in pairs(self.list) do
				sortedlist[#sortedlist+1] = k
			end
			table.sort(sortedlist, textSort)
			for i, k in ipairs(sortedlist) do
				local f = GetContentLine()
				f.text:SetText(k)
				--print(k)
				if k == self.value then
					f.check:Show()
				end

				local statusbar = self.list[k] ~= k and self.list[k] or Media:Fetch('statusbar',k)
				f.bar:SetTexture(statusbar)
				f.obj = self
				f.dropdown = self.dropdown
				self.dropdown:AddFrame(f)
			end
			wipe(sortedlist)
		end
	end

	local function ClearFocus(self)
		if self.dropdown then
			self.dropdown = AGSMW:ReturnDropDownFrame(self.dropdown)
		end
	end

	local function OnHide(this)
		local self = this.obj
		if self.dropdown then
			self.dropdown = AGSMW:ReturnDropDownFrame(self.dropdown)
		end
	end

	local function OnEnter(self) self.obj:Fire('OnEnter') end
	local function OnLeave(self) self.obj:Fire('OnLeave') end

	local function Constructor()
		local frame = AGSMW:GetBaseFrame()
		local self = {}

		self.type = widgetType
		self.frame = frame
		frame.obj = self
		frame.dropButton.obj = self
		frame.dropButton:SetScript('OnEnter', OnEnter)
		frame.dropButton:SetScript('OnLeave', OnLeave)
		frame.dropButton:SetScript('OnClick', ToggleDrop)
		frame:SetScript('OnHide', OnHide)

		local bar = frame:CreateTexture(nil, "OVERLAY")
			bar:SetPoint("TOPLEFT", frame,"TOPLEFT",6,-25)
			bar:SetPoint("BOTTOMRIGHT", frame,"BOTTOMRIGHT", -21, 5)
			bar:SetAlpha(0.5)
		self.bar = bar

		self.alignoffset = 31

		self.OnRelease = OnRelease
		self.OnAcquire = OnAcquire
		self.ClearFocus = ClearFocus
		self.SetText = SetText
		self.SetValue = SetValue
		self.GetValue = GetValue
		self.SetList = SetList
		self.SetLabel = SetLabel
		self.SetDisabled = SetDisabled
		self.AddItem = AddItem
		self.SetMultiselect = SetMultiselect
		self.GetMultiselect = GetMultiselect
		self.SetItemValue = SetItemValue
		self.SetItemDisabled = SetItemDisabled
		self.ToggleDrop = ToggleDrop

		AceGUI:RegisterAsWidget(self)
		return self
	end

	AceGUI:RegisterWidgetType(widgetType, Constructor, widgetVersion)
end
--]]
