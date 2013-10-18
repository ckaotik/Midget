local addonName, ns, _ = ...

-- GLOBALS: ITEM_QUALITY_COLORS, FROM_ALL_SOURCES, ATTACHMENTS_MAX, ATTACHMENTS_MAX_SEND, NUM_BAG_SLOTS, GetAuctionBuyout, GameTooltip, SendMailFrame
-- GLOBALS: GetCoinTextureString, GetInboxItemLink, GetInboxItem, GetItemInfo, IsAltKeyDown, ClearCursor, CursorHasItem, PickupContainerItem, GetSendMailItemLink, GetContainerNumSlots, GetContainerItemInfo, GetContainerItemLink, ClickSendMailItemButton, Click
-- GLOBALS: strsplit, string, select, hooksecurefunc, ipairs, wipe, table

local function SortItems(a, b)
	return a.name < b.name
end

local items = {}
local function ShowAttachmentInfo(self)
	if self.hasItem and self.itemCount > 1 then
		local totalValue = 0
		local link, name, itemTexture, count, quality

		-- don't own the tooltip, or previous data lines get cleared
		-- GameTooltip:SetOwner(self)

		-- don't recalc for every frame
		if items.index ~= self.index then
			wipe(items)
			items.index = self.index

			-- gather and group data
			for attachmentIndex = 1, ATTACHMENTS_MAX do
				link = GetInboxItemLink(self.index, attachmentIndex)
				name, itemTexture, count, quality = GetInboxItem(self.index, attachmentIndex)

				if name then
					if not quality or quality == -1 then
						local linkType, id, data = link:match("(%l+):([^:]*):?([^\124]*)")
						if linkType == 'battlepet' then
							_, quality = strsplit(':', data or '')
							quality = quality + 1
						else
							_, _, quality = GetItemInfo(link)
						end
					end

					local value = GetAuctionBuyout and GetAuctionBuyout(link) or select(11, GetItemInfo(link)) or 0
					totalValue = totalValue + value

					local key = string.format('|T%s:0|t %s%s|r', itemTexture, ITEM_QUALITY_COLORS[quality].hex, name)
					local index = items[key]
					if index then
						items[index].count = items[index].count + count
					else
						table.insert(items, {label = key, count = count, name = name})
						items[key] = #items
					end
				end
			end
			table.sort(items, SortItems)
		end

		-- add data to tooltip
		for _, data in ipairs(items) do
			GameTooltip:AddDoubleLine(data.label, data.count)
		end

		-- GameTooltip:AddDoubleLine(FROM_ALL_SOURCES, GetCoinTextureString(totalValue))
		GameTooltip:Show()
	end
end

local function AttachSimilarItems(itemLink, thisItemOnly)
	local linkType, linkID, linkData = ns.GetLinkData(itemLink)
	local bagItemLink, bagItemLocked, bagLinkType, bagLinkID, bagLinkData
	local shouldAttach

	local numAttachments = 0
	for attachmentSlot = 1, ATTACHMENTS_MAX_SEND do
		if GetSendMailItemLink(attachmentSlot) then
			numAttachments = numAttachments + 1
		end
	end

	-- TODO: multiple "passes" for priority/likelyness
	for container = 0, NUM_BAG_SLOTS do
		for slot = 1, GetContainerNumSlots(container) or 0 do
			if numAttachments >= ATTACHMENTS_MAX_SEND then
				ns.Print('This mail has the maximum number of attachments.')
				if false then -- TODO: autoSendWhenFull and strlen(SendMailNameEditBox:GetText()) > 0
					Click("SendMailButton")
					-- wait for MAIL_SEND_SUCCESS event
					--[[-- TODO: override Blizzard code:
					SendMailFrame_Reset();
				    PlaySound("igAbiliityPageTurn");
				    -- If open mail frame is open then switch the mail frame back to the inbox
				    if ( SendMailFrame.sendMode == "reply" ) then
				      MailFrameTab_OnClick(nil, 1);
				    end
					--]]
				else
					break
				end
			end

			_, _, bagItemLocked, _, _, _, bagItemLink = GetContainerItemInfo(container, slot)
			bagLinkType, bagLinkID, bagLinkData = ns.GetLinkData(bagItemLink)

			if thisItemOnly then
				shouldAttach = not bagItemLocked and (bagLinkType == linkType) and (bagLinkID == linkID)
			else
				shouldAttach = false
				--[[ Postal's Express Mailing
				or (pass == 0 and itemq == 2 and tq == 2 and itemes and tes) -- green boe gear
				or (pass == 1 and tid == itemid) -- identical items
				or (pass == 2 and tsc == itemsc) -- same subtype
				or (pass == 3 and tc == itemc)   -- same type
				or (pass == 4 and tq == itemq)   -- same quality
				--]]
			end

			if shouldAttach then
				ClearCursor()
				PickupContainerItem(container, slot)
				ClickSendMailItemButton()

				local _, _, success = GetContainerItemInfo(container, slot)
				if success then
					numAttachments = numAttachments + 1
				else
					ns.Print('Could not attach item', bagItemLink, 'from bag', container, ', slot', slot)
					ClearCursor()
				end
			end
		end
	end
end

local function initialize(frame, event, arg1)
	if arg1 == addonName then
		hooksecurefunc("InboxFrameItem_OnEnter", ShowAttachmentInfo)
		hooksecurefunc("ContainerFrameItemButton_OnModifiedClick", function(self, btn)
			if IsAltKeyDown() and SendMailFrame:IsVisible() and not CursorHasItem() then
				local itemLink = GetContainerItemLink(self:GetParent():GetID(), self:GetID())
				AttachSimilarItems(itemLink, btn == 'RightButton')
			end
		end)

		ns.RegisterEvent('MAIL_INBOX_UPDATE', function()
			wipe(items)
		end, 'mail_update')

		ns.UnregisterEvent('ADDON_LOADED', 'mail')
	end
end
ns.RegisterEvent('ADDON_LOADED', initialize, 'mail')
