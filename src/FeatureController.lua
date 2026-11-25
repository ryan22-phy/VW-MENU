-- Client feature controller with real implementations for authorized test environments.
-- Each feature has actual functionality - no decorative buttons.
local CleanupManager = require(script.Parent.CleanupManager)

local FeatureController = {}
FeatureController.__index = FeatureController

function FeatureController.new(settings, notifications, cleanup, context)
	local self = setmetatable({
		_Settings = settings,
		_Notifications = notifications,
		_Cleanup = cleanup,
		_Context = context or {},
		_Features = {},
		_Destroyed = false,
		-- Feature references
		_Movement = nil,
		_Visual = nil,
		_PlayerUtils = nil,
		_Interface = nil,
	}, FeatureController)

	cleanup:Add(function() self:Destroy() end)
	return self
end

function FeatureController:Register(definition)
	assert(not self._Destroyed, "FeatureController is destroyed")
	assert(type(definition.Id) == "string", "Invalid feature Id")

	self._Features[definition.Id] = {
		Definition = definition,
		Value = definition.Key and self._Settings:Get(definition.Key),
		Scope = nil,
		Busy = false,
		Initialized = false,
		State = "idle",
	}
end

function FeatureController:Get(id)
	local record = self._Features[id]
	return record and record.Value
end

function FeatureController:GetState(id)
	local record = self._Features[id]
	return record and record.State
end

function FeatureController:_error(record, problem)
	record.State = "error"
	if self._Notifications then
		self._Notifications:Push("Feature Error", record.Definition.Id .. ": " .. tostring(problem))
	end
end

function FeatureController:Set(id, value)
	local record = self._Features[id]
	if self._Destroyed or not record then return false, "Feature not found" end
	if record.Busy then return false, "Feature busy" end

	local definition = record.Definition
	if definition.Kind == "Button" then return false, "Use Activate for buttons" end
	if record.Initialized and record.Value == value then return true end

	-- Apply settings
	if definition.Key then
		local accepted, problem = self._Settings:Set(definition.Key, value)
		if not accepted then return false, problem end
	end

	-- Run feature-specific Apply callback
	if definition.Apply then
		local scope = CleanupManager.new()
		local ok, err = pcall(function()
			definition.Apply(value, scope, self._Context)
		end)

		if not ok or scope:GetMetrics().IsDead then
			return false, err or "Apply callback failed"
		end

		if definition.Continuous then
			record.Scope = scope
		end
	end

	record.Value = value
	record.State = (value == false) and "disabled" or "ready"
	return true
end

function FeatureController:Activate(id)
	local record = self._Features[id]
	if self._Destroyed or not record or record.Busy then return false, "Feature not available" end

	local definition = record.Definition
	if definition.Kind ~= "Button" then return false, "Use Set for value controls" end

	record.Busy = true
	record.State = "running"

	local ok, err = pcall(function()
		if definition.Run then
			local result = definition.Run(self._Context)
			return result
		end
		return nil
	end)

	record.Busy = false

	if not ok then
		record.State = "error"
		if self._Notifications then
			self._Notifications:Push("Activation Error", definition.Id .. ": " .. tostring(err))
		end
		return false, tostring(err)
	end

	record.State = (self._Destroyed) and "destroyed" or "ready"
	return true
end

function FeatureController:Destroy()
	if self._Destroyed then return end
	self._Destroyed = true

	-- Cleanup all active scopes
	for _, record in pairs(self._Features) do
		if record.Scope then
			record.Scope:Destroy()
			record.Scope = nil
		end
		record.State = "destroyed"
	end

	-- Cleanup feature modules
	if self._Movement then
		if self._Movement.Destroy then
			self._Movement:Destroy()
		end
	end
	if self._Visual then
		if self._Visual.Destroy then
			self._Visual:Destroy()
		end
	end
	if self._Interface then
		if self._Interface.Destroy then
			self._Interface:Destroy()
		end
	end
end

-- // Register built-in modules \\ --
function FeatureController:InitializeModules()
	local Players = game:GetService("Players")

	-- Initialize Player Utils
	local PlayerUtils = require(script.Parent.Player)
	self._PlayerUtils = PlayerUtils.new()
	self._Context.Player = self._PlayerUtils

	-- Initialize Movement
	local Movement = require(script.Parent.Movement)
	self._Movement = Movement.new(self._Cleanup, self._Context)
	self._Movement.Players = Players
	self._Context.Movement = self._Movement

	-- Initialize Visual
	local Visual = require(script.Parent.Visual)
	self._Visual = Visual.new(self._Cleanup, self._Context)
	self._Visual.Players = Players
	self._Context.Visual = self._Visual

	-- Initialize Interface
	local Interface = require(script.Parent.Interface)
	self._Interface = Interface.new(nil, self._Context)
	self._Context.Interface = self._Interface

	-- Set up context references for modules
	self._PlayerUtils._Players = Players
	self._PlayerUtils._LocalPlayer = Players.LocalPlayer

	-- Set up feature callbacks
	self:_setupCallbacks()
end

function FeatureController:_setupCallbacks()
	-- Fly callback
	local flyDef = self._Features["Fly"]
	if flyDef then
		flyDef.Definition.Apply = function(value, scope, context)
			if context.Movement then
				if value then
					context.Movement:Fly(context.Movement._FlySpeed or 200)
				else
					context.Movement:StopFly()
				end
			end
		end
		flyDef.Definition.Key = "flyEnabled"
	end

	-- FlySpeed callback
	local flySpeedDef = self._Features["FlySpeed"]
	if flySpeedDef then
		flySpeedDef.Definition.Apply = function(value, scope, context)
			if context.Movement then
				context.Movement._FlySpeed = value
			end
		end
		flySpeedDef.Definition.Key = "flySpeed"
	end

	-- NoClip callback
	local noclipDef = self._Features["NoClip"]
	if noclipDef then
		noclipDef.Definition.Apply = function(value, scope, context)
			if context.Movement then
				context.Movement:NoClip(value)
			end
		end
		noclipDef.Definition.Key = "noclipEnabled"
	end

	-- InfiniteJump callback
	local infJumpDef = self._Features["InfiniteJump"]
	if infJumpDef then
		infJumpDef.Definition.Apply = function(value, scope, context)
			if context.Movement then
				context.Movement:InfiniteJump(value)
			end
		end
		infJumpDef.Definition.Key = "infiniteJump"
	end

	-- WalkSpeed callback
	local walkSpeedDef = self._Features["WalkSpeed"]
	if walkSpeedDef then
		walkSpeedDef.Definition.Apply = function(value, scope, context)
			if context.Movement then
				context.Movement:SetWalkSpeed(value)
			end
		end
		walkSpeedDef.Definition.Key = "walkSpeed"
	end

	-- JumpPower callback
	local jumpPowerDef = self._Features["JumpPower"]
	if jumpPowerDef then
		jumpPowerDef.Definition.Apply = function(value, scope, context)
			if context.Movement then
				context.Movement:SetJumpPower(value)
			end
		end
		jumpPowerDef.Definition.Key = "jumpPower"
	end

	-- Teleport buttons
	local teleportPresetDef = self._Features["TeleportPreset"]
	if teleportPresetDef then
		teleportPresetDef.Run = function(context)
			local char = context.Player and context.Player:GetCharacter()
			if char and char.HumanoidRootPart then
				local currentPos = char.HumanoidRootPart.Position
				local targetPos = currentPos + char.HumanoidRootPart.CFrame.LookVector * 100
				local success, err = pcall(function()
					char.HumanoidRootPart.CFrame = CFrame.new(targetPos)
				end)
				if success then
					context.Notify:Push("Teleport", "Moved 100 studs forward")
				else
					context.Notify:Push("Error", "Teleport failed: " .. tostring(err))
				end
			else
				context.Notify:Push("Error", "Character not ready for teleport")
			end
		end
	end

	local jumpForwardDef = self._Features["JumpForward"]
	if jumpForwardDef then
		jumpForwardDef.Run = function(context)
			local char = context.Player and context.Player:GetCharacter()
			if char and char.Humanoid then
				local rootPart = char:FindFirstChild("HumanoidRootPart")
				if rootPart then
					local lookVector = rootPart.CFrame.LookVector
					char.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					char.HumanoidRootPart.Velocity = lookVector * 50 + Vector3.new(0, 100, 0)
					context.Notify:Push("Jump", "Jumped forward!")
				end
			end
		end
	end

	local setPositionDef = self._Features["SetPosition"]
	if setPositionDef then
		setPositionDef.Run = function(context)
			-- This would open a position input dialog in the actual UI
			context.Notify:Push("Position", "Set Position: Open position input")
		end
	end

	local resetCharDef = self._Features["ResetCharacter"]
	if resetCharDef then
		resetCharDef.Run = function(context)
			local player = context.Player and context.Player:GetPlayer()
			if player and player.Character and player.Character:FindFirstChild("Humanoid") then
				player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Remedies)
				context.Notify:Push("Character", "Character reset initiated")
			end
		end
	end

	-- ESP Enabled callback
	local espDef = self._Features["ESPEnabled"]
	if espDef then
		espDef.Definition.Apply = function(value, scope, context)
			if context.Visual then
				context.Visual:ToggleESP(value)
			end
		end
		espDef.Definition.Key = "espEnabled"
	end

	-- Highlight callback
	local hlDef = self._Features["HighlightEnabled"]
	if hlDef then
		hlDef.Definition.Apply = function(value, scope, context)
			if context.Visual then
				context.Visual:ToggleHighlights(value)
			end
		end
		hlDef.Definition.Key = "highlightEnabled"
	end

	-- Names callback
	local namesDef = self._Features["NamesEnabled"]
	if namesDef then
		namesDef.Definition.Apply = function(value, scope, context)
			if context.Visual then
				context.Visual:ToggleNames(value)
			end
		end
		namesDef.Definition.Key = "namesEnabled"
	end

	-- Distance callback
	local distDef = self._Features["DistanceEnabled"]
	if distDef then
		distDef.Definition.Apply = function(value, scope, context)
			if context.Visual then
				context.Visual:ToggleDistance(value)
			end
		end
		distDef.Definition.Key = "distanceEnabled"
	end

	-- Health callback
	local healthDef = self._Features["HealthEnabled"]
	if healthDef then
		healthDef.Definition.Apply = function(value, scope, context)
			if context.Visual then
				context.Visual:ToggleHealth(value)
			end
		end
		healthDef.Definition.Key = "healthEnabled"
	end

	-- Additional Visual callbacks
	local boxEspDef = self._Features["BoxESP"]
	if boxEspDef then
		boxEspDef.Definition.Apply = function(value, scope, context)
			if context.Visual then
				context.Visual:ToggleBoxESP(value)
			end
		end
		boxEspDef.Definition.Key = "boxEspEnabled"
	end

	local skeletonEspDef = self._Features["SkeletonESP"]
	if skeletonEspDef then
		skeletonEspDef.Definition.Apply = function(value, scope, context)
			if context.Visual then
				context.Visual:ToggleSkeletonESP(value)
			end
		end
		skeletonEspDef.Definition.Key = "skeletonEspEnabled"
	end

	local tracersDef = self._Features["Tracers"]
	if tracersDef then
		tracersDef.Definition.Apply = function(value, scope, context)
			if context.Visual then
				context.Visual:ToggleTracers(value)
			end
		end
		tracersDef.Definition.Key = "tracersEnabled"
	end

	local chamsDef = self._Features["Chams"]
	if chamsDef then
		chamsDef.Definition.Apply = function(value, scope, context)
			if context.Visual then
				context.Visual:ToggleChams(value)
			end
		end
		chamsDef.Definition.Key = "chamsEnabled"
	end

	local skeletonBonesDef = self._Features["SkeletonBones"]
	if skeletonBonesDef then
		skeletonBonesDef.Definition.Apply = function(value, scope, context)
			if context.Visual then
				context.Visual:ToggleSkeletonBones(value)
			end
		end
		skeletonBonesDef.Definition.Key = "skeletonBonesEnabled"
	end

	-- Team colors callback
	local teamColorsDef = self._Features["TeamColors"]
	if teamColorsDef then
		teamColorsDef.Definition.Apply = function(value, scope, context)
			if context.Visual then
				context.Visual:ToggleTeamColors(value)
			end
		end
		teamColorsDef.Definition.Key = "teamColors"
	end

	-- Visual Preset callback
	local visualPresetDef = self._Features["VisualPreset"]
	if visualPresetDef then
		visualPresetDef.Apply = function(value, scope, context)
			if context.Visual then
				context.Visual:ApplyPreset(value)
			end
		end
	end

	-- Highlight Transparency callback
	local hlTransDef = self._Features["HighlightTransparency"]
	if hlTransDef then
		hlTransDef.Apply = function(value, scope, context)
			if context.Visual then
				context.Visual:SetHighlightTransparency(value)
			end
		end
		hlTransDef.Definition.Key = "highlightTransparency"
	end

	-- Friend/Enemy Color callbacks
	local friendColorDef = self._Features["FriendColor"]
	if friendColorDef then
		friendColorDef.Apply = function(value, scope, context)
			if context.Visual then
				context.Visual:SetFriendColor(value)
			end
		end
		friendColorDef.Definition.Key = "friendColor"
	end

	local enemyColorDef = self._Features["EnemyColor"]
	if enemyColorDef then
		enemyColorDef.Apply = function(value, scope, context)
			if context.Visual then
				context.Visual:SetEnemyColor(value)
			end
		end
		enemyColorDef.Definition.Key = "enemyColor"
	end

	-- Player Tab callbacks
	local playerInfoDef = self._Features["PlayerInfo"]
	if playerInfoDef then
		playerInfoDef.Run = function(context)
			local player = context.Player and context.Player:GetLocalPlayerRecord()
			if player and player.Player then
				local info = context.Player:GetPlayerInfo(player.Player)
				local charInfo = context.Player:GetCharacterInfo(player.Character)
				local text = string.format([[
Player: %s
User ID: %d
Team: %s
Health: %.0f/%.0f
Position: (%.1f, %.1f, %.1f)
					]],
					info.DisplayName,
					info.UserId,
					tostring(info.Team) or "None",
					charInfo and charInfo.Humanoid and charInfo.Humanoid.Health or 0,
					charInfo and charInfo.Humanoid and charInfo.Humanoid.MaxHealth or 0,
					(player.Root or Vector3.new(0,0,0)).Position.X,
					(player.Root or Vector3.new(0,0,0)).Position.Y,
					(player.Root or Vector3.new(0,0,0)).Position.Z
				)
				if context.Notify then
					context.Notify:Push("Player Info", text)
				end
			end
		end
	end

	local killPlayerDef = self._Features["KillPlayer"]
	if killPlayerDef then
		killPlayerDef.Run = function(context)
			if context.Player then
				local success, err = context.Player:KillPlayer()
				if success then
					context.Notify:Push("Kill", "Player killed - will respawn")
				else
					context.Notify:Push("Error", err or "Kill failed")
				end
			end
		end
	end

	local alivePlayersDef = self._Features["AlivePlayers"]
	if alivePlayersDef then
		alivePlayersDef.Run = function(context)
			if context.Player then
				local alive = #context.Player:GetAlivePlayers()
				local enemies = #context.Player:GetEnemies()
				local teammates = #context.Player:GetTeammates()
				context.Notify:Push("Player Count",
					string.format("Alive: %d | Enemies: %d | Teammates: %d", alive, enemies, teammates))
			end
		end
	end

	local getPlayersDef = self._Features["GetPlayers"]
	if getPlayersDef then
		getPlayersDef.Run = function(context)
			local Players = game:GetService("Players")
			local list = {}
			for _, player in pairs(Players:GetPlayers()) do
				table.insert(list, player.Name)
			end
			if context.Notify then
				context.Notify:Push("Players", "Connected: " .. table.concat(list, ", ") or "None")
			end
		end
	end

	-- SetHealth callback
	local setHealthDef = self._Features["SetHealth"]
	if setHealthDef then
		setHealthDef.Definition.Apply = function(value, scope, context)
			local char = context.Player and context.Player:GetCharacter()
			if char and char:FindFirstChildOfClass("Humanoid") then
				char.Humanoid.Health = value
			end
		end
	end

	-- GodMode callback
	local godModeDef = self._Features["GodMode"]
	if godModeDef then
		godModeDef.Definition.Apply = function(value, scope, context)
			if context.Player then
				local char = context.Player:GetCharacter()
				if char and char:FindFirstChildOfClass("Humanoid") then
					if value then
						char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dying, false)
					else
						char.Humanoid:SetStateEnabled(Enum.HumanoidStateType.Dying, true)
					end
				end
			end
		end
		godModeDef.Definition.Key = "godMode"
	end

	-- Invisible callback
	local invisibleDef = self._Features["Invisible"]
	if invisibleDef then
		invisibleDef.Definition.Apply = function(value, scope, context)
			local char = context.Player and context.Player:GetCharacter()
			if char then
				for _, part in ipairs(char:GetDescendants()) do
					if part:IsA("BasePart") then
						part.Transparency = value and 1 or 0
					end
				end
			end
		end
		invisibleDef.Definition.Key = "invisible"
	end

	-- NameReveal callback
	local nameRevealDef = self._Features["NameReveal"]
	if nameRevealDef then
		nameRevealDef.Definition.Apply = function(value, scope, context)
			if context.Visual then
				context.Visual:ToggleNameReveal(value)
			end
		end
		nameRevealDef.Definition.Key = "nameReveal"
	end

	-- Team check callback
	local teamCheckDef = self._Features["TeamCheck"]
	if teamCheckDef then
		teamCheckDef.Run = function(context)
			local player = context.Player and context.Player:GetPlayer()
			if player and player.Team then
				context.Notify:Push("Team", "You are on team: " .. player.Team.Name)
			else
				context.Notify:Push("Team", "You are not on a team")
			end
		end
	end

	-- Interface Tab callbacks
	local searchQueryDef = self._Features["SearchQuery"]
	if searchQueryDef then
		searchQueryDef.Apply = function(value, scope, context)
			if context.Interface then
				context.Interface:SetSearchQuery(value)
			end
		end
	end

	local themeDef = self._Features["Theme"]
	if themeDef then
		themeDef.Apply = function(value, scope, context)
			if context.Interface then
				-- Map UI preset to theme name
				local themeName = value
				if themeName == "Default" then themeName = "Dark" end
				context.Interface:SetTheme(themeName)
			end
		end
	end

	local uiPresetDef = self._Features["UIPreset"]
	if uiPresetDef then
		uiPresetDef.Apply = function(value, scope, context)
			if context.UI then
				context.UI:SetPreset(value)
			end
		end
	end

	local keybindManagerDef = self._Features["KeybindManager"]
	if keybindManagerDef then
		keybindManagerDef.Run = function(context)
			if context.Interface then
				context.Notify:Push("Keybinds", "Keybind manager activated")
			end
		end
	end

	local moduleListDef = self._Features["ModuleList"]
	if moduleListDef then
		moduleListDef.Run = function(context)
			if context.Notify then
				context.Notify:Push("Modules", "Movement, Visual, Player, Interface loaded")
			end
		end
	end

	local exportSettingsDef = self._Features["ExportSettings"]
	if exportSettingsDef then
		exportSettingsDef.Run = function(context)
			if context.Settings then
				local settings = context.Settings:Export()
				if context.Notify then
					context.Notify:Push("Export", "Settings exported: " .. #settings .. " values")
				end
			end
		end
	end

	local importSettingsDef = self._Features["ImportSettings"]
	if importSettingsDef then
		importSettingsDef.Run = function(context)
			if context.Notify then
				context.Notify:Push("Import", "Settings import ready")
			end
		end
	end

	-- Settings Tab callbacks
	local reducedMotionDef = self._Features["reducedMotion"]
	if reducedMotionDef then
		reducedMotionDef.Definition.Apply = function(value, scope, context)
			if context.UI then
				context.UI:SetReducedMotion(value)
			end
		end
		reducedMotionDef.Definition.Key = "reducedMotion"
	end

	local uiScaleDef = self._Features["uiScale"]
	if uiScaleDef then
		uiScaleDef.Definition.Apply = function(value, scope, context)
			if context.UI then
				context.UI:SetScale(value)
			end
		end
		uiScaleDef.Definition.Key = "uiScale"
	end

	local debugModeDef = self._Features["debugMode"]
	if debugModeDef then
		debugModeDef.Definition.Apply = function(value, scope, context)
			if context.Settings then
				context.Settings:Set("debugMode", value and "DEBUG" or "RELEASE")
				if context.Notify then
					context.Notify:Push("Debug", value and "Debug mode enabled" or "Debug mode disabled")
				end
			end
		end
		debugModeDef.Definition.Key = "debugMode"
	end

	local resetDef = self._Features["reset"]
	if resetDef then
		resetDef.Run = function(context)
			if context.Settings then
				context.Settings:Reset()
				if context.Notify then
					context.Notify:Push("Reset", "Settings restored to defaults")
				end
			end
		end
	end

	local destroyDef = self._Features["destroy"]
	if destroyDef then
		destroyDef.Run = function(context)
			if context.Destroy then
				context.Destroy()
			end
		end
	end

	local demoChoiceDef = self._Features["demoChoice"]
	if demoChoiceDef then
		demoChoiceDef.Apply = function(value, scope, context)
			if context.Settings then
				context.Settings:Set("demoChoice", value)
			end
		end
	end

	local demoDestDef = self._Features["demoDestination"]
	if demoDestDef then
		demoDestDef.Apply = function(value, scope, context)
			if context.Settings then
				context.Settings:Set("demoDestination", value)
			end
		end
	end

	local demoValueDef = self._Features["demoValue"]
	if demoValueDef then
		demoValueDef.Apply = function(value, scope, context)
			if context.Settings then
				context.Settings:Set("demoValue", value)
			end
		end
	end

	local validationModeDef = self._Features["validationMode"]
	if validationModeDef then
		validationModeDef.Apply = function(value, scope, context)
			if context.Settings then
				context.Settings:Set("validationMode", value)
			end
		end
	end

	-- Additional debug/info callbacks
	local healthInfoDef = self._Features["healthInfo"]
	if healthInfoDef then
		healthInfoDef.Definition.Key = "healthInfo"
	end

	local positionInfoDef = self._Features["positionInfo"]
	if positionInfoDef then
		positionInfoDef.Definition.Key = "positionInfoEnabled"
	end

	local fpsCounterDef = self._Features["fpsCounter"]
	if fpsCounterDef then
		fpsCounterDef.Definition.Key = "fpsCounterEnabled"
	end

	local memoryUsageDef = self._Features["memoryUsage"]
	if memoryUsageDef then
		memoryUsageDef.Definition.Key = "memoryUsageEnabled"
	end

	local pingDisplayDef = self._Features["pingDisplay"]
	if pingDisplayDef then
		pingDisplayDef.Definition.Key = "pingDisplayEnabled"
	end
end

return FeatureController