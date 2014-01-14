local addonName, ns, _ = ...

-- GLOBALS: UnitIsPlayer, UnitLevel, UnitGUID, CanInspect, IsInspectFrameOpen, NotifyInspect

local unitCache = setmetatable({}, {
	__mode = "kv",
	--[[ __index = function(self, guid)
		self[guid] = {
			-- spec = 0,
			-- ilevel = 0,
		}
		return self[guid]
	end, --]]
})
local function TooltipUnitExtras(tooltip, ...)
	local unitName, unit = tooltip:GetUnit()

	if not unit or not UnitIsPlayer(unit) or UnitLevel(unit) < 10 then return end
	local guid = UnitGUID(unit)

	if unitCache[guid] then
		-- show in tooltip
	elseif CanInspect(unit) and not IsInspectFrameOpen() then
		-- self:RegisterEvent("INSPECT_READY")
		-- self:RegisterEvent("UNIT_INVENTORY_CHANGED")
		NotifyInspect(unit)
	end

	-- GetInspectSpecialization()
	-- GetSpecializationInfoByID(spec)
	-- local link = GetInventoryItemLink("unit", slot)
end
-- GameTooltip:HookScript('OnTooltipSetUnit', TooltipUnitExtras)
