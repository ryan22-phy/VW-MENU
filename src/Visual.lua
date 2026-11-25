--// Visual (ESP, Highlights, Name Tags) System for authorized test environments.
--// Provides advanced ESP functionality with performance optimization and extensive features.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Visual = {}
Visual.__index = Visual

--// Embedded Skeleton Bone Tags --//
local EMBEDDED_TAGS = {
	["HEAD"] = { "Head", CFrame.new(0, 1, 0) },
	["TORSO"] = { "UpperTorso", CFrame.new(0, 0, 0) },
	["LEFT_ARM"] = { "LeftUpperArm", CFrame.new(-1.5, 0.5, 0) },
	["RIGHT_ARM"] = { "RightUpperArm", CFrame.new(1.5, 0.5, 0) },
	["LEFT_LEG"] = { "LeftUpperLeg", CFrame.new(0, -1.5, 0) },
	["RIGHT_LEG"] = { "RightUpperLeg", CFrame.new(0, -1.5, 0) },
	["PELVIS"] = { "LowerTorso", CFrame.new(0, 0.5, 0) },
}

--// Color Palette --//
Visual.COLOR_PALETTE = {
	FRIEND = Color3.fromRGB(66, 173, 255),    -- #42ADFF
	ENEMY = Color3.fromRGB(255, 77, 90),      -- #FF4D5A
	TEAM = Color3.fromRGB(100, 200, 100),      -- Green
	OPPOSING = Color3.fromRGB(255, 100, 100),  -- Red
	NEUTRAL = Color3.fromRGB(180, 180, 200),   -- Gray
}

local function getPlayerColor(self, player)
	if not player then return Color3.new(1, 1, 1) end

	if self._TeamColors then
		local playerTeam = player.Team
		local localTeam = Players.LocalPlayer and Players.LocalPlayer.Team

		if playerTeam and localTeam and playerTeam == localTeam then
			return Visual.COLOR_PALETTE.FRIEND
		elseif playerTeam or localTeam then
			-- Different teams
			return Visual.COLOR_PALETTE.OPPOSING
		else
			-- No teams defined, use friend/enemy based on distance/default
			if (player.Position - Players.LocalPlayer.Position).Magnitude < 200 then
				return Visual.COLOR_PALETTE.FRIEND
			end
			return Visual.COLOR_PALETTE.ENEMY
		end
	end

	-- Default: friend if local player, else enemy
	if player == Players.LocalPlayer then
		return Visual.COLOR_PALETTE.FRIEND
	end
	return Visual.COLOR_PALETTE.ENEMY
end

local function getHighlightTransparency(self)
	return self._HighlightTransparency or 0.65
end

--// Visual Constructor --//
function Visual.new(cleanup, context)
	local self = setmetatable({
		_Cleanup = cleanup,
		_Context = context or {},
		_ESPEnabled = false,
		_HighlightsEnabled = false,
		_NamesEnabled = false,
		_DistanceEnabled = false,
		_HealthEnabled = false,
		_BoxEnabled = false,
		_SkeletonEnabled = false,
		_TracersEnabled = false,
		_ChamsEnabled = false,
		_SkeletonBonesEnabled = false,
		_NameReveal = false,
		_TeamColors = true,
		_HighlightTransparency = 0.65,
		_FriendColor = Color3.fromRGB(66, 173, 255),
		_EnemyColor = Color3.fromRGB(255, 77, 90),
		_Root = workspace.WorldPosition or workspace.Baseplate,
		_EspUpdateThread = nil,
		_LastEspTick = 0,
		_PlayerLastPositions = {}, -- For prediction / smoothing
		_VisiblePlayerCache = {}, -- Cache for performance
		_ESPObjects = {}, -- Storage for ESP objects
	}, Visual)

	-- Cleanup on module destroy
	cleanup:Add(function()
		self:Destroy()
	end)

	return self
end

function Visual:SetPlayers(playersService)
	self.Players = playersService or Players
end

--// ESP Toggle System --//
function Visual:ToggleESP(enabled)
	self._ESPEnabled = enabled == true
	if enabled then
		self:_startESPUpdate()
	else
		self:_stopESPUpdate()
		self:_cleanupESP()
	end
end

function Visual:_startESPUpdate()
	if self._EspUpdateThread then return end

	self._EspUpdateThread = RunService.RenderStepped:Connect(function(_, dt)
		if self._ESPEnabled then
			self:_updateESP(dt)
		end
	end)
end

function Visual:_stopESPUpdate()
	if self._EspUpdateThread then
		self._EspUpdateThread:Disconnect()
		self._EspUpdateThread = nil
	end
end

--// Core ESP Update Loop --//
function Visual:_updateESP(dt)
	if not self._ESPEnabled then return end

	local localPlayer = Players.LocalPlayer
	if not localPlayer then return end

	local localPos = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not localPos then return end

	-- Performance: limit update frequency to every 50ms for smoother performance
	local currentTick = tick()
	if currentTick - self._LastEspTick < 0.05 then return end
	self._LastEspTick = currentTick

	-- Build list of currently visible players with humanoids
	local visiblePlayers = {}
	for _, player in pairs(self.Players:GetPlayers()) do
		if player ~= localPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
			table.insert(visiblePlayers, player)
		end
	end

	-- Create/update ESP for visible players
	for _, player in ipairs(visiblePlayers) do
		self:_createESPForPlayer(player)
	end

	-- Clean up ESP for players who are no longer visible (left or died)
	local keysToRemove = {}
	for key, espData in pairs(self._ESPObjects) do
		if espData.Player and not table.find(visiblePlayers, espData.Player) then
			table.insert(keysToRemove, key)
		end
	end
	for _, key in ipairs(keysToRemove) do
		self:_removeESPForPlayer(self._ESPObjects[key].Player)
		self._ESPObjects[key] = nil
	end
end

--// Create ESP for Player --//
function Visual:_createESPForPlayer(player)
	-- Cache character references for performance
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local key = player.UserId
	if self._ESPObjects[key] then
		-- Update existing ESP data instead of recreating
		self:_updateESPObjects(player, root, key)
		return
	end

	local espData = {
		Player = player,
		Highlights = {},
		NameTag = nil,
		DistanceLabel = nil,
		HealthLabel = nil,
		BoxAdornment = nil,
		Tracer = nil,
		Skeleton = {},
		Chams = {},
	}

	-- Create highlights if enabled
	if self._HighlightsEnabled then
		self:_createHighlightForPlayer(player, root, espData)
	end

	-- Create name tag if enabled
	if self._NamesEnabled then
		self:_createNameTagForPlayer(player, root, espData)
	end

	-- Create distance label if enabled
	if self._DistanceEnabled then
		self:_createDistanceLabelForPlayer(player, root, espData)
	end

	-- Create health label if enabled
	if self._HealthEnabled then
		self:_createHealthLabelForPlayer(player, root, espData)
	end

	-- Create box ESP if enabled
	if self._BoxEnabled then
		self:_createBoxESPForPlayer(player, root, espData)
	end

	-- Create skeleton if enabled
	if self._SkeletonEnabled then
		self:_createSkeletonForPlayer(player, root, espData)
	end

	-- Create tracers if enabled
	if self._TracersEnabled then
		self:_createTracerForPlayer(player, root, espData)
	end

	-- Create chams if enabled
	if self._ChamsEnabled then
		self:_createChamsForPlayer(player, root, espData)
	end

	self._ESPObjects[key] = espData
end

--// Update existing ESP objects (performance optimization) --//
function Visual:_updateESPObjects(player, root, key)
	-- If we already have data, just update what's needed
	if self._ESPObjects[key] then
		-- Will be fully updated on next cycle
	end
end

--// Create Highlight for Player --//
function Visual:_createHighlightForPlayer(player, root, espData)
	local highlight = Instance.new("Highlight")
	highlight.Name = "VWMenu_Highlight"
	highlight.FillColor = getPlayerColor(self, player)
	highlight.FillTransparency = getHighlightTransparency(self)
	highlight.OutlineColor = Color3.new(0, 0, 0)
	highlight.OutlineTransparency = 0.0
	highlight.Adornee = root
	highlight.Parent = root.Parent
	espData.Highlights[1] = highlight
end

--// Create Name Tag for Player --//
function Visual:_createNameTagForPlayer(player, root, espData)
	local nameLabel = Instance.new("BillboardGui")
	nameLabel.Name = "VWMenu_NameTag"
	nameLabel.Adornee = root
	nameLabel.Size = UDim2.new(0, 120, 0, 40)
	nameLabel.StudsOffset = Vector3.new(0, 2.5, 0)
	nameLabel.AlwaysOnTop = true
	nameLabel.BackgroundTransparency = 1
	nameLabel.FillDirection = Enum.FillDirection.Vertical

	local nameText = Instance.new("TextLabel")
	nameText.Name = "NameText"
	nameText.Size = UDim2.new(1, 0, 1, 0)
	nameText.BackgroundTransparency = 1
	nameText.Text = player.Name
	nameText.Font = Enum.Font.GothamBold
	nameText.TextSize = 13
	nameText.TextColor3 = getPlayerColor(self, player)
	nameText.TextStrokeTransparency = 0.3
	nameText.TextTruncate = Enum.TextTruncate.AtEnd
	nameText.Parent = nameLabel

	nameLabel.Parent = workspace
	espData.NameTag = nameLabel
end

--// Create Distance Label for Player --//
function Visual:_createDistanceLabelForPlayer(player, root, espData)
	local distLabel = Instance.new("BillboardGui")
	distLabel.Name = "VWMenu_Distance"
	distLabel.Adornee = root
	distLabel.Size = UDim2.new(0, 90, 0, 25)
	distLabel.StudsOffset = Vector3.new(0, 3.5, 0)
	distLabel.AlwaysOnTop = true
	distLabel.BackgroundTransparency = 1
	distLabel.FillDirection = Enum.FillDirection.Vertical

	local distText = Instance.new("TextLabel")
	distText.Size = UDim2.new(1, 0, 1, 0)
	distText.BackgroundTransparency = 1
	distText.Font = Enum.Font.Gotham
	distText.TextSize = 12
	distText.TextColor3 = Color3.new(1, 1, 1)
	distText.TextStrokeTransparency = 0.3
	distText.Parent = distLabel

	distLabel.Parent = workspace
	espData.DistanceLabel = distLabel
end

--// Create Health Label for Player --//
function Visual:_createHealthLabelForPlayer(player, root, espData)
	local healthLabel = Instance.new("BillboardGui")
	healthLabel.Name = "VWMenu_Health"
	healthLabel.Adornee = player.Character and player.Character:FindFirstChild("Humanoid")
	healthLabel.Size = UDim2.new(0, 120, 0, 25)
	healthLabel.StudsOffset = Vector3.new(0, 2, 0)
	healthLabel.AlwaysOnTop = true
	healthLabel.BackgroundTransparency = 1
	healthLabel.FillDirection = Enum.FillDirection.Vertical

	local healthText = Instance.new("TextLabel")
	healthText.Size = UDim2.new(1, 0, 1, 0)
	healthText.BackgroundTransparency = 1
	healthText.Font = Enum.Font.Gotham
	healthText.TextSize = 12
	healthText.TextColor3 = Color3.new(0, 1, 0)
	healthText.TextStrokeTransparency = 0.3
	healthText.Parent = healthLabel

	healthLabel.Parent = workspace
	espData.HealthLabel = healthLabel
end

--// Create Box ESP for Player --//
function Visual:_createBoxESPForPlayer(player, root, espData)
	local box = Instance.new("BoxHandleAdornment")
	box.Name = "VWMenu_BoxESP"
	box.Adornee = root
	box.Size = root.Size or Vector3.new(2, 6, 1)
	box.AlwaysOnTop = true
	box.CFrame = root.CFrame
	box.FillColor = getPlayerColor(self, player)
	box.FillTransparency = getHighlightTransparency(self)
	box.Outline = true
	box.OutlineColor = Color3.new(0, 0, 0)
	box.Parent = workspace

	espData.BoxAdornment = box
end

--// Create Skeleton for Player --//
function Visual:_createSkeletonForPlayer(player, root, espData)
	-- Skeleton uses Adornees on character parts
	local character = player.Character
	if not character then return end

	for boneName, boneData in pairs(EMBEDDED_TAGS) do
		local partName = boneData[1]
		local offsetCFrame = boneData[2]

		local part = character:FindFirstChild(partName)
		if part then
			local adornee = Instance.new("BoxHandleAdornment")
			adornee.Name = "VWMenu_Skeleton_" .. boneName
			adornee.Adornee = part
			adornee.Size = Vector3.new(1, 1, 1) -- Tiny, just for tag reference
			adornee.AlwaysOnTop = true
			adornee.CFrame = part.CFrame * offsetCFrame
			adornee.FillColor = getPlayerColor(self, player)
			adornee.FillTransparency = getHighlightTransparency(self) - 0.1
			adornee.Outline = true
			adornee.OutlineColor = Color3.new(0, 0, 0)
			adornee.ZIndex = 10 -- Render on top
			adornee.Parent = workspace

			table.insert(espData.Skeleton, {
				Part = part,
				Adornment = adornee,
				BoneName = boneName,
			})
		end
	end
end

--// Create Tracer for Player --//
function Visual:_createTracerForPlayer(player, root, espData)
	local localPlayer = Players.LocalPlayer
	if not localPlayer then return end

	local localRoot = localPlayer.Character and localPlayer.Character:FindFirstChild("HumanoidRootPart")
	if not localRoot then return end

	-- Create line from local player to target
	local tracer = Instance.new("Part")
	tracer.Name = "VWMenu_Tracer"
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = getPlayerColor(self, player)
	tracer.Transparency = getHighlightTransparency(self)
	tracer.Size = Vector3.new(0.2, 0, 0.2)
	tracer.Parent = workspace

	-- Set to local player position initially
	if localRoot then
		tracer.CFrame = CFrame.new(localRoot.Position, root.Position)
	end

	tracer.CanCollide = false

	espData.Tracer = tracer
end

--// Create Chams for Player --//
function Visual:_createChamsForPlayer(player, root, espData)
	local chams = Instance.new("Highlight")
	chams.Name = "VWMenu_Chams"
	chams.Adornee = root
	chams.FillColor = getPlayerColor(self, player)
	chams.FillTransparency = getHighlightTransparency(self) * 0.5
	chams.OutlineColor = Color3.new(0, 0, 0)
	chams.OutlineTransparency = 0.0
	chams.Parent = root.Parent -- Parent to character, not root specifically

	espData.Chams = chams
end

--// Remove ESP for Player --//
function Visual:_removeESPForPlayer(player)
	local key = player.UserId
	local espData = self._ESPObjects[key]
	if not espData then return end

	-- Destroy highlights
	for _, h in ipairs(espData.Highlights or {}) do
		if h and h.Parent then h:Destroy() end
	end
	if espData.Highlights then table.clear(espData.Highlights) end

	-- Destroy name tag
	if espData.NameTag and espData.NameTag.Parent then
		espData.NameTag:Destroy()
	end
	espData.NameTag = nil

	-- Destroy distance label
	if espData.DistanceLabel and espData.DistanceLabel.Parent then
		espData.DistanceLabel:Destroy()
	end
	espData.DistanceLabel = nil

	-- Destroy health label
	if espData.HealthLabel and espData.HealthLabel.Parent then
		espData.HealthLabel:Destroy()
	end
	espData.HealthLabel = nil

	-- Destroy box adornment
	if espData.BoxAdornment and espData.BoxAdornment.Parent then
		espData.BoxAdornment:Destroy()
	end
	espData.BoxAdornment = nil

	-- Destroy skeleton adornments
	if espData.Skeleton then
		for _, skeletonPart in ipairs(espData.Skeleton) do
			if skeletonPart.Adornment and skeletonPart.Adornment.Parent then
				skeletonPart.Adornment:Destroy()
			end
		end
		table.clear(espData.Skeleton)
	end

	-- Destroy tracer
	if espData.Tracer and espData.Tracer.Parent then
		espData.Tracer:Destroy()
	end
	espData.Tracer = nil

	-- Destroy chams
	if espData.Chams and espData.Chams.Parent then
		espData.Chams:Destroy()
	end
	espData.Chams = nil

	self._ESPObjects[key] = nil
end

--// Full ESP Cleanup --//
function Visual:_cleanupESP()
	for key, espData in pairs(self._ESPObjects) do
		self:_removeESPForPlayer(espData.Player)
	end
	self._ESPObjects = {}
end

--// Highlights Toggle --//
function Visual:ToggleHighlights(enabled)
	self._HighlightsEnabled = enabled == true
	self:_cleanupESP()
	self:_startESPUpdate()
end

--// Names Toggle --//
function Visual:ToggleNames(enabled)
	self._NamesEnabled = enabled == true
	self:_cleanupESP()
	self:_startESPUpdate()
end

--// Distance Toggle --//
function Visual:ToggleDistance(enabled)
	self._DistanceEnabled = enabled == true
	self:_cleanupESP()
	self:_startESPUpdate()
end

--// Health Toggle --//
function Visual:ToggleHealth(enabled)
	self._HealthEnabled = enabled == true
	self:_cleanupESP()
	self:_startESPUpdate()
end

--// Box ESP Toggle --//
function Visual:ToggleBoxESP(enabled)
	self._BoxEnabled = enabled == true
	self:_cleanupESP()
	self:_startESPUpdate()
end

--// Skeleton Toggle --//
function Visual:ToggleSkeleton(enabled)
	self._SkeletonEnabled = enabled == true
	self:_cleanupESP()
	self:_startESPUpdate()
end

--// Tracers Toggle --//
function Visual:ToggleTracers(enabled)
	self._TracersEnabled = enabled == true
	self:_cleanupESP()
	self:_startESPUpdate()
end

--// Chams Toggle --//
function Visual:ToggleChams(enabled)
	self._ChamsEnabled = enabled == true
	self:_cleanupESP()
	self:_startESPUpdate()
end

--// Skeleton ESP Toggle --//
function Visual:ToggleSkeletonESP(enabled)
	self._SkeletonEnabled = enabled == true
	self:_cleanupESP()
	self:_startESPUpdate()
end

--// Skeleton Bones Toggle --//
function Visual:ToggleSkeletonBones(enabled)
	self._SkeletonBonesEnabled = enabled == true
	self:_cleanupESP()
	self:_startESPUpdate()
end

--// Name Reveal Toggle --//
function Visual:ToggleNameReveal(enabled)
	self._NameReveal = enabled == true
	-- Name reveal functionality placeholder
	-- In a full implementation, this would show player names without distance limit
end

--// Team Colors Toggle --//
function Visual:ToggleTeamColors(enabled)
	self._TeamColors = enabled == true
	-- Refresh ESP to apply team colors
	self:_cleanupESP()
	self:_startESPUpdate()
end

--// Apply Preset --//
function Visual:ApplyPreset(presetName)
	if not presetName then
		warn("[Visual] No preset name specified")
		return
	end

	if presetName == "Default" then
		self._HighlightsEnabled = true
		self._NamesEnabled = false
		self._DistanceEnabled = false
		self._HealthEnabled = false
	elseif presetName == "Neon" then
		self._HighlightsEnabled = true
		self._NamesEnabled = true
		self._DistanceEnabled = true
		self._HealthEnabled = false
		self._BoxEnabled = true
		self._TracersEnabled = true
	elseif presetName == "Blood" then
		self._HighlightsEnabled = true
		self._NamesEnabled = true
		self._HealthEnabled = true
		self._ChamsEnabled = true
		self._TracersEnabled = false
	elseif presetName == "Ghost" then
		self._HighlightsEnabled = true
		self._NamesEnabled = true
		self._DistanceEnabled = true
		self._ChamsEnabled = true
		self._BoxEnabled = true
		self._SkeletonEnabled = true
	else -- "None"
		self._HighlightsEnabled = false
		self._NamesEnabled = false
		self._DistanceEnabled = false
		self._HealthEnabled = false
		self._BoxEnabled = false
		self._TracersEnabled = false
		self._ChamsEnabled = false
		self._SkeletonEnabled = false
	end

	self:_cleanupESP()
	self:_startESPUpdate()
end

--// Utility Methods --//
function Visual:SetTeamColors(enabled)
	self._TeamColors = enabled == true
end

function Visual:SetHighlightTransparency(value)
	if value >= 0 and value <= 1 then
		self._HighlightTransparency = value
		-- Update existing highlights
		for _, espData in pairs(self._ESPObjects) do
			for _, highlight in ipairs(espData.Highlights or {}) do
				if highlight and highlight.Parent then
					highlight.FillTransparency = value
				end
			end
		end
	end
end

function Visual:SetFriendColor(hexColor)
	local success, color = pcall(function()
		return self:_hexToColor3(hexColor)
	end)
	if success then
		self._FriendColor = color
		-- Update friend highlights
		for _, espData in pairs(self._ESPObjects) do
			for _, highlight in ipairs(espData.Highlights or {}) do
				if highlight and highlight.Parent then
					-- Color logic based on team check
					local player = espData.Player
					if player == Players.LocalPlayer then
						highlight.FillColor = color
					end
				end
			end
		end
	end
end

function Visual:SetEnemyColor(hexColor)
	local success, color = pcall(function()
		return self:_hexToColor3(hexColor)
	end)
	if success then
		self._EnemyColor = color
		-- Update enemy highlights
		for _, espData in pairs(self._ESPObjects) do
			for _, highlight in ipairs(espData.Highlights or {}) do
				if highlight and highlight.Parent then
					local player = espData.Player
					if player ~= Players.LocalPlayer and player.Team then
						highlight.FillColor = color
					end
				end
			end
		end
	end
end

function Visual:_hexToColor3(hex)
	if type(hex) ~= "string" then return Color3.new(1, 1, 1) end
	hex = hex:gsub("^#", "")
	if #hex ~= 6 then return Color3.new(1, 1, 1) end
	local r = tonumber("0x" .. hex:sub(1, 2)) / 255
	local g = tonumber("0x" .. hex:sub(3, 4)) / 255
	local b = tonumber("0x" .. hex:sub(5, 6)) / 255
	return Color3.new(r, g, b)
end

--// Debug/Getter Methods --//
function Visual:GetESPCount()
	local count = 0
	for _ in pairs(self._ESPObjects) do count = count + 1 end
	return count
end

function Visual:IsESPEnabled()
	return self._ESPEnabled
end

function Visual:IsHighlightEnabled()
	return self._HighlightsEnabled
end

function Visual:IsNamesEnabled()
	return self._NamesEnabled
end

function Visual:IsDistanceEnabled()
	return self._DistanceEnabled
end

function Visual:IsHealthEnabled()
	return self._HealthEnabled
end

function Visual:IsBoxESPEnabled()
	return self._BoxEnabled
end

function Visual:IsSkeletonEnabled()
	return self._SkeletonEnabled
end

function Visual:IsTracersEnabled()
	return self._TracersEnabled
end

function Visual:IsChamsEnabled()
	return self._ChamsEnabled
end

function Visual:IsSkeletonBonesEnabled()
	return self._SkeletonBonesEnabled
end

--// Cleanup --//
function Visual:Destroy()
	self:_stopESPUpdate()
	self:_cleanupESP()

	self._ESPObjects = {}
	self._HighlightsEnabled = false
	self._NamesEnabled = false
	self._DistanceEnabled = false
	self._HealthEnabled = false
	self._BoxEnabled = false
	self._SkeletonEnabled = false
	self._TracersEnabled = false
	self._ChamsEnabled = false
	self._SkeletonBonesEnabled = false
end

return Visual