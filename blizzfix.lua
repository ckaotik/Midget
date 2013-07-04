local _, ns = ...

local tip = CreateFrame("GameTooltip")
tip:SetOwner(WorldFrame, "ANCHOR_NONE")

for i=1,30 do
	local left, right = tip:CreateFontString(), tip:CreateFontString()
	left:SetFontObject(GameFontNormal)
	right:SetFontObject(GameFontNormal)
	tip:AddFontStrings(left, right)
end
