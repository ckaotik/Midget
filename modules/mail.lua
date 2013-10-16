local addonName, ns, _ = ...

-- GLOBALS: ITEM_QUALITY_COLORS, FROM_ALL_SOURCES, ATTACHMENTS_MAX, GetAuctionBuyout, GameTooltip
-- GLOBALS: GetCoinTextureString, GetInboxItemLink, GetInboxItem, GetItemInfo
-- GLOBALS: strsplit, string, select, hooksecurefunc

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

					value = GetAuctionBuyout and GetAuctionBuyout(link) or select(11, GetItemInfo(link)) or 0
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

local function initialize(frame, event, arg1)
	if arg1 == addonName then
		hooksecurefunc("InboxFrameItem_OnEnter", ShowAttachmentInfo)

		ns.RegisterEvent('MAIL_INBOX_UPDATE', function()
			wipe(items)
		end, 'mail_update')

		ns.UnregisterEvent('ADDON_LOADED', 'mail')
	end
end
ns.RegisterEvent('ADDON_LOADED', initialize, 'mail')
