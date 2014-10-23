local addonName, addon, _ = ...
local plugin = addon:NewModule('BigWigs', 'AceEvent-3.0')

-- GLOBALS: LibStub, BigWigs, BigWigsLoader, C_Timer, TimerTracker, TimerTracker_OnEvent
local LSM = LibStub('LibSharedMedia-3.0', true)

-- HACK: registering ADDON_LOADED within OnEnable does not work, so we register 1s later
local function AddBigWigsCallback()
	plugin:RegisterEvent('ADDON_LOADED', function(event, arg1, ...)
		if arg1 == 'BigWigs_Plugins' then
			plugin:UnregisterEvent(event)
			plugin:OnEnable()
		end
	end)
end

function plugin:OnEnable()
	if not IsAddOnLoaded('BigWigs_Plugins') then
		C_Timer.After(1, AddBigWigsCallback)
		return
	end

	-- Fancy BigWigs pull timer, like those in challenge modes
	local L = LibStub('AceLocale-3.0'):GetLocale('Big Wigs: Plugins')
	BigWigsLoader:RegisterMessage('BigWigs_StartBar', function(_, plugin, _, text, timeLeft)
		if text == ('Pull' or L['Pull']) then
			TimerTracker_OnEvent(TimerTracker, 'START_TIMER', TIMER_TYPE_CHALLENGE_MODE, timeLeft, timeLeft)
		end
	end)
	BigWigsLoader:RegisterMessage('BigWigs_StopBar', function(event, plugin, text)
		if text == ('Pull' or L['Pull']) then
			TimerTracker_OnEvent(TimerTracker, 'PLAYER_ENTERING_WORLD')
		end
	end)

	-- Custom BigWigs bar style
	local bars = BigWigs:GetPlugin('Bars', true)
	if bars then
		local inset = 0
		local backdropBorder = {
			bgFile = 'Interface\\Buttons\\WHITE8X8',
			edgeFile = 'Interface\\Buttons\\WHITE8X8',
			-- edgeFile = LSM:Fetch('border', 'Single Gray'),
			tile = false, tileSize = 0, edgeSize = 1,
			insets = {left = inset, right = inset, top = inset, bottom = inset}
		}

		local conf = bars.db.profile
		bars:RegisterBarStyle('ckaotik', {
			apiVersion = 1,
			version = 1,
			GetSpacing = function(bar) return 20 end,
			ApplyStyle = function(bar)
				if conf.icon then
					local icon = bar.candyBarIconFrame
					local iconTexture = icon.icon
					bar:Set('bigwigs:restoreicon', iconTexture)
					bar:SetIcon(nil)

					icon:SetTexture(iconTexture)
					icon:ClearAllPoints()
					icon:SetPoint('BOTTOMRIGHT', bar, 'BOTTOMLEFT', -4, 0)
					icon:SetSize(18, 18)
					icon:Show()

					local iconBd = bar.candyBarIconFrameBackdrop
					iconBd:SetBackdrop(backdropBorder)
					iconBd:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
					iconBd:SetBackdropBorderColor(0, 0, 0, 1)

					iconBd:ClearAllPoints()
					iconBd:SetPoint('TOPLEFT', icon, 'TOPLEFT', -1, 1)
					iconBd:SetPoint('BOTTOMRIGHT', icon, 'BOTTOMRIGHT', 1, -1)
					iconBd:Show()
				end

				bar:SetTexture(LSM:Fetch('statusbar', conf.texture))
				bar:SetHeight(4)

				local duration = bar.candyBarDuration
				if conf.time then
					duration:SetJustifyH('RIGHT')
					duration:ClearAllPoints()
					duration:SetPoint('BOTTOMRIGHT', bar, 'TOPRIGHT', 0, 2)
				end

				local label = bar.candyBarLabel
				label:SetJustifyH(conf.align)
				label:ClearAllPoints()
				label:SetPoint('BOTTOMLEFT', bar, 'TOPLEFT', 0, 2)
				if conf.time then
					label:SetPoint('BOTTOMRIGHT', duration, 'BOTTOMLEFT', -2, 0)
				else
					label:SetPoint('BOTTOMRIGHT', bar, 'TOPRIGHT', -2, 2)
				end

				local bd = bar.candyBarBackdrop
				bd:ClearAllPoints()
				bd:SetPoint('TOPLEFT', -1, 1)
				bd:SetPoint('BOTTOMRIGHT', 1, -1)
				bd:SetBackdrop(backdropBorder)
				bd:SetBackdropColor(0.1, 0.1, 0.1, 0.5)
				bd:SetBackdropBorderColor(0, 0, 0, 1)
				bd:Show()
			end,
			BarStopped = function(bar)
				bar:SetHeight(14)
				bar.candyBarBackdrop:Hide()

				local tex = bar:Get('bigwigs:restoreicon')
				if tex then
					local icon = bar.candyBarIconFrame
					icon:ClearAllPoints()
					icon:SetPoint('TOPLEFT')
					icon:SetPoint('BOTTOMLEFT')
					bar:SetIcon(tex)

					bar.candyBarIconFrameBackdrop:Hide()
				end

				bar.candyBarDuration:ClearAllPoints()
				bar.candyBarDuration:SetPoint('RIGHT', bar.candyBarBar, 'RIGHT', -2, 0)

				bar.candyBarLabel:ClearAllPoints()
				bar.candyBarLabel:SetPoint('LEFT', bar.candyBarBar, 'LEFT', 2, 0)
				bar.candyBarLabel:SetPoint('RIGHT', bar.candyBarBar, 'RIGHT', -2, 0)
			end,
			GetStyleName = function() return 'ckaotik' end,
		})
	end
end
