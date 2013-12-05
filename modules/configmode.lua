local addonName, ns, _ = ...


if not CONFIGMODE_CALLBACKS then
	CONFIGMODE_CALLBACKS = {}
end

if IsAddOnLoaded("Dominos") then -- Dominos_Config
	CONFIGMODE_CALLBACKS["Dominos"] = function(action)
		Dominos:ToggleLockedFrames()
	end
end

if IsAddOnLoaded("BigWigs") then -- BigWigs_Options
	-- options:BigWigs_StartConfigureMode(nil, true) / options:BigWigs_StopConfigureMode()
end

--[[
local chatWindowWasLocked = {}
CONFIGMODE_CALLBACKS["Blizzard - Chat Windows"] = function(action)
	if action == "ON" then
		wipe(chatWindowWasLocked)
		for index = 1, NUM_CHAT_WINDOWS do
			local shown, locked, docked = select(7, GetChatWindowInfo(index))
			if shown and not docked and locked then
				chatWindowWasLocked[index] = true
				SetChatWindowLocked(index, false)
			end
		end
	elseif action == "OFF" then
		for index in pairs(chatWindowWasLocked) do
			SetChatWindowLocked(index, true)
		end
	end
end

local watchFrameWasLocked
CONFIGMODE_CALLBACKS["Blizzard - Watch Frame"] = function(action)
	if action == "ON" then
		watchFrameWasLocked = WatchFrame.locked
		if watchFrameWasLocked then
			WatchFrame_Unlock(WatchFrame)
		end
	elseif action == "OFF" and watchFrameWasLocked then
		WatchFrame_Lock(WatchFrame)
		watchFrameWasLocked = nil
	end
end
--]]
