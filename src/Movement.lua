--// Movement Utilities Module - Advanced Flight, Physics, and Character Control
--// For authorized test environments only
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local HttpService = game:GetService("HttpService")

local Movement = {}
Movement.__index = Movement

--// Configuration Constants \\--
local FLY_CONFIG = {
	ACCELERATION = 64,
	MAX_SPEED = 200,
	DECELERATION = 128,
	SPEED_MULTIPLIER = 1,
}

local DEFAULT_SPEEDS = {
	WALK = 16,
	JUMP = 50,
	FLY = 200,
}

--// Flight State \\--
Movement._FlySpeed = 200
Movement._FlyActive = false
Movement._FlyBodyVelocity = nil
Movement._FlyBodyGyro = nil
Movement._FlyCF = nil
Movement._FlyAccelerating = false
Movement._LastFlyUpdate = 0

--// NoClip State \\--
Movement._NoClipEnabled = false
Movement._OriginalCanCollide = {}

--// Infinite Jump State \\--
Movement._InfiniteJumpEnabled = false
Movement._JumpConnection = nil
Movement._JumpRequestConnection = nil
Movement._JumpRequestAlt = nil

--// Character Tracking \\--
Movement._Character = nil
Movement._Humanoid = nil
Movement._RootPart = nil
Movement._AncestryChangedConn = nil

--// Movement Presets \\--
Movement.PRESETS = {
	Default = { WalkSpeed = 16, JumpPower = 50, FlySpeed = 200 },
	Sprint = { WalkSpeed = 32, JumpPower = 50, FlySpeed = 300 },
	Ninja = { WalkSpeed = 24, JumpPower = 75, FlySpeed = 150 },
	Tank = { WalkSpeed = 12, JumpPower = 50, FlySpeed = 100 },
	Flier = { WalkSpeed = 16, JumpPower = 50, FlySpeed = 400 },
}

function Movement.new(cleanup, context)
	local self = setmetatable({
		_Cleanup = cleanup,
		_Context = context or {},
		_Enabled = false,
		_Camera = workspace.CurrentCamera,
		_FlyDirection = Vector3.new(),
		_MovementPreset = "Default",
	}, Movement)

	-- Setup character tracking
	self:_setupCharacterListener()

	-- Setup cleanup
	cleanup:Add(function()
		self:Destroy()
	end)

	return self
end

function Movement:SetPlayers(playersService)
	self.Players = playersService or game:GetService("Players")
end

--// Character Management \\--
function Movement:_setupCharacterListener()
	if not self.Players or not self.Players.LocalPlayer then return end

	-- Clear existing state
	self:_cleanupCharacter()

	local function onCharacterAdded(char)
		self._Character = char
		self._Humanoid = char:FindFirstChildWhichIsA("Humanoid")
		self._RootPart = char:FindFirstChild("HumanoidRootPart")

		-- Reset fly state on respawn
		if self._FlyActive then
			task.spawn(function()
				self:Fly(self._FlySpeed)
			end)
		end

		-- Reset character values
		if self._Humanoid then
			self._Humanoid.WalkSpeed = self._Humanoid.WalkSpeed
			self._Humanoid.JumpPower = self._Humanoid.JumpPower
		end
	end

	self.Players.LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

	-- If character already exists
	if self.Players.LocalPlayer.Character then
		onCharacterAdded(self.Players.LocalPlayer.Character)
	end
end

function Movement:_cleanupCharacter()
	if self._AncestryChangedConn then
		self._AncestryChangedConn:Disconnect()
		self._AncestryChangedConn = nil
	end

	self._Character = nil
	self._Humanoid = nil
	self._RootPart = nil
end

--// Advanced Flight System \\--
function Movement:Fly(speed, preset)
	if not self._Character or not self._RootPart then return end

	-- Stop existing flight
	if self._FlyActive then
		self:StopFly()
	end

	-- Set fly speed
	speed = speed or self._FlySpeed or FLY_CONFIG.MAX_SPEED
	self._FlySpeed = speed

	-- Apply preset if specified
	if preset and type(preset) == "string" and Movement.PRESETS[preset] then
		self._MovementPreset = preset
		self:_ApplyPreset(preset)
	end

	self._FlyActive = true
	self._LastFlyUpdate = tick()

	-- Create BodyMovers with proper configuration
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Name = "VWMenu_FlyVelocity"
	bodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bodyVelocity.Velocity = Vector3.new(0, 0, 0)
	bodyVelocity.P = 1250
	bodyVelocity.Parent = self._RootPart
	self._FlyBodyVelocity = bodyVelocity

	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.Name = "VWMenu_FlyGyro"
	bodyGyro.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	bodyGyro.CFrame = self._RootPart.CFrame
	bodyGyro.P = 3000
	bodyGyro.D = 250
	bodyGyro.Parent = self._RootPart
	self._FlyBodyGyro = bodyGyro

	-- Store initial CF for orientation reset
	self._FlyCF = self._RootPart.CFrame

	self._Enabled = true

	-- Start flight update loop
	self:_startFlyUpdate()
end

function Movement:_startFlyUpdate()
	if self._FlyActive and not self._FlyConnection then
		self._FlyConnection = RunService.Heartbeat:Connect(function(ct)
			self:_updateFly(ct)
		end)
	elseif not self._FlyActive and self._FlyConnection then
		self._FlyConnection:Disconnect()
		self._FlyConnection = nil
	end
end

function Movement:_updateFly(ct)
	if not self._FlyActive or not self._RootPart or not self._Camera then return end

	-- Throttle update rate for performance
	if ct - self._LastFlyUpdate < 0.016 then return end -- ~60 FPS
	self._LastFlyUpdate = ct

	local camera = self._Camera
	local lookVector = camera.CFrame.LookVector
	local rightVector = camera.CFrame.RightVector

	-- Get input with acceleration/deceleration
	local moveDirection = Vector3.new(0, 0, 0)

	if UserInputService:IsKeyDown(Enum.KeyCode.W) then
		moveDirection = moveDirection + lookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then
		moveDirection = moveDirection - lookVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then
		moveDirection = moveDirection - rightVector
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then
		moveDirection = moveDirection + rightVector
	end

	-- Vertical movement
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
		moveDirection = moveDirection + Vector3.new(0, 1, 0)
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
		moveDirection = moveDirection - Vector3.new(0, 1, 0)
	end

	-- Apply gravity when not moving vertically
	if moveDirection.Magnitude > 0 then
		-- Normalize and apply speed
		moveDirection = moveDirection.Unit
		local velocity = moveDirection * self._FlySpeed
		self._FlyBodyVelocity.Velocity = velocity
	else
		-- Gradually decelerate
		local currentVel = self._FlyBodyVelocity.Velocity
		local deceleration = currentVel * (1 - math.clamp(FLY_CONFIG.DECELERATION * ct, 0, 1))
		self._FlyBodyVelocity.Velocity = deceleration
	end
end

function Movement:StopFly()
	if not self._FlyActive then return end

	self._FlyActive = false

	-- Clean up BodyMovers
	if self._FlyBodyVelocity then
		self._FlyBodyVelocity:Destroy()
		self._FlyBodyVelocity = nil
	end

	if self._FlyBodyGyro then
		self._FlyBodyGyro:Destroy()
		self._FlyBodyGyro = nil
	end

	-- Clean up connection
	if self._FlyConnection then
		self._FlyConnection:Disconnect()
		self._FlyConnection = nil
	end

	self._FlyCF = nil
	self._Enabled = false
end

--// NoClip System \\--
function Movement:NoClip(enabled)
	if not self._Character then return end

	self._NoClipEnabled = enabled == true

	for _, part in ipairs(self._Character:GetDescendants()) do
		if part:IsA("BasePart") then
			if enabled then
				-- Store original CanCollide
				self._OriginalCanCollide[part] = part.CanCollide
				part.CanCollide = false
				part.Anchored = false
			else
				-- Restore original CanCollide
				if self._OriginalCanCollide[part] ~= nil then
					part.CanCollide = self._OriginalCanCollide[part]
					self._OriginalCanCollide[part] = nil
				else
					part.CanCollide = true
				end
				part.Anchored = false
			end
		end
	end
end

--// Infinite Jump System \\--
function Movement:InfiniteJump(enabled)
	if not self._Humanoid then return end

	self._InfiniteJumpEnabled = enabled == true

	-- Disconnect existing connections
	if self._JumpConnection then
		self._JumpConnection:Disconnect()
		self._JumpConnection = nil
	end

	if self._JumpRequestConnection then
		self._JumpRequestConnection:Disconnect()
		self._JumpRequestConnection = nil
	end

	if self._JumpRequestAlt then
		self._JumpRequestAlt:Disconnect()
		self._JumpRequestAlt = nil
	end

	if self._InfiniteJumpEnabled then
		-- Handle jump cooldown
		self._JumpConnection = self._Humanoid.Jumping:Connect(function(active)
			if active then
				-- Force reset for next jump
				self._Humanoid.Jump = false
			end
		end)

		-- Handle JumpRequest for alternative input
		self._JumpRequestConnection = UserInputService.JumpRequest:Connect(function()
			if self._InfiniteJumpEnabled then
				self._Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)

		self._JumpRequestAlt = UserInputService.JumpRequest:Connect(function()
			if self._InfiniteJumpEnabled and self._Humanoid then
				self._Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
			end
		end)
	end
end

--// Movement Presets \\--
function Movement:ApplyPreset(presetName)
	if not Movement.PRESETS[presetName] then
		warn("[Movement] Unknown preset: " .. tostring(presetName))
		return false
	end

	local preset = Movement.PRESETS[presetName]

	-- Apply settings
	if self._Humanoid then
		self._Humanoid.WalkSpeed = preset.WalkSpeed
		self._Humanoid.JumpPower = preset.JumpPower
	end

	self._FlySpeed = preset.FlySpeed
	self._MovementPreset = presetName

	return true
end

function Movement:GetPreset()
	return self._MovementPreset
end

--// Walk Speed Control \\--
function Movement:SetWalkSpeed(value)
	if not self._Humanoid then return false end
	self._Humanoid.WalkSpeed = value or DEFAULT_SPEEDS.WALK
	return true
end

function Movement:GetWalkSpeed(): number
	if not self._Humanoid then return DEFAULT_SPEEDS.WALK end
	return self._Humanoid.WalkSpeed
end

--// Jump Power Control \\--
function Movement:SetJumpPower(value)
	if not self._Humanoid then return false end
	self._Humanoid.JumpPower = value or DEFAULT_SPEEDS.JUMP
	return true
end

function Movement:GetJumpPower(): number
	if not self._Humanoid then return DEFAULT_SPEEDS.JUMP end
	return self._Humanoid.JumpPower
end

--// Advanced Teleport System \\--
function Movement:Teleport(position)
	if not self._Character or not self._RootPart then
		return false, "Character not ready"
	end

	position = position or self._RootPart.Position

	-- Validate position is in workspace
	local success, err = pcall(function()
		self._RootPart.CFrame = CFrame.new(position)
	end)

	if success then
		return true
	else
		return false, tostring(err)
	end
end

function Movement:TeleportForward(distance)
	if not self._RootPart then return false, "RootPart not found" end

	distance = distance or 100
	local lookVector = (self._Camera and self._Camera.CFrame.LookVector) or Vector3.new(0, 0, -1)
	local targetPos = self._RootPart.Position + lookVector * distance

	return self:Teleport(targetPos)
end

function Movement:TeleportToPosition(position, anchorToGround)
	if not self._Character then return false, "Character not ready" end

	anchorToGround = anchorToGround or true

	local success, err = pcall(function()
		if anchorToGround then
			-- Raycast down to find ground
			local raycastParams = RaycastParams.new()
			raycastParams.FilterDescendantsInstances = {self._Character}
			raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

			local result = workspace:Raycast(position, Vector3.new(0, -100, 0), raycastParams)
			if result and result.Instance then
				position = result.Position + Vector3.new(0, 3, 0)
			end
		end

		if self._RootPart then
			self._RootPart.CFrame = CFrame.new(position)
		end
	end)

	if success then
		return true
	else
		return false, tostring(err)
	end
end

--// Character Reset \\--
function Movement:ResetCharacter()
	local player = self.Players and self.Players.LocalPlayer
	if not player then return false, "Player not found" end

	if player.Character and player.Character:FindFirstChild("Humanoid") then
		player.Character.Humanoid:ChangeState(Enum.HumanoidStateType.Remedies)
		return true
	end
	return false, "Character not found"
end

--// Status Queries \\--
function Movement:IsFlying()
	return self._FlyActive
end

function Movement:IsNoClip()
	return self._NoClipEnabled
end

function Movement:IsInfiniteJump()
	return self._InfiniteJumpEnabled
end

function Movement:IsEnabled()
	return self._Enabled
end

function Movement:Toggle()
	if self._FlyActive then
		self:StopFly()
	else
		self:Fly(self._FlySpeed)
	end
end

--// Advanced Controls \\--
function Movement:SetFlightSpeed(speed)
	self._FlySpeed = speed or 200
	if self._FlyActive and self._FlyBodyVelocity then
		-- Speed will be applied on next update
	end
end

function Movement:GetFlightSpeed()
	return self._FlySpeed
end

function Movement:ResetToSpawn()
	local player = self.Players and self.Players.LocalPlayer
	if not player then return false, "Player not found" end

	local spawnLocation = player:FindFirstChild("SpawnLocation") or player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if spawnLocation then
		self:Teleport(spawnLocation.Position)
		return true
	end
	return false, "No spawn location found"
end

--// Cleanup \\--
function Movement:Destroy()
	-- Stop flying
	if self._FlyActive then
		self:StopFly()
	end

	-- Disable NoClip
	if self._NoClipEnabled then
		self:NoClip(false)
	end

	-- Disconnect infinite jump listeners
	if self._JumpConnection then
		self._JumpConnection:Disconnect()
		self._JumpConnection = nil
	end

	if self._JumpRequestConnection then
		self._JumpRequestConnection:Disconnect()
		self._JumpRequestConnection = nil
	end

	if self._JumpRequestAlt then
		self._JumpRequestAlt:Disconnect()
		self._JumpRequestAlt = nil
	end

	-- Reset character state
	if self._Humanoid then
		pcall(function()
			self._Humanoid.WalkSpeed = DEFAULT_SPEEDS.WALK
			self._Humanoid.JumpPower = DEFAULT_SPEEDS.JUMP
		end)
	end

	self._Enabled = false
	self._OriginalCanCollide = {}
end

return Movement